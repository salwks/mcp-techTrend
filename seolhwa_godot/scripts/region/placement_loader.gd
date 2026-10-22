# LOADER_READY
# 배치 불러오기(계약서 §8) — region_data/JL_NAMWON_UNBONG/placement_*.json(과 --placedir 폴더)을 모두 읽어
# 키트를 build()하고(같은 kit+params는 한 번만, 작업 스레드 여러 개로) RegionWorld.add_static으로 놓는다.
# 정적 물체는 RegionWorld가 타일 스트리밍에 맞춰 붙였다 뗀다.
#
#   항목: { id, kit:"village/house_compound", params:{seed…}, x, z, ry(라디안), y(null=지형), flatten, clear_veg(기본 true), yard(기본 true: 마당 흙),
#           footprint:[w,d](선택 — 없으면 build() 결과), group }
#   - 배치형(읍성·관아·실상사·향교): 키트에 static layout(params)가 있으면 그걸로, 없으면 build() 결과 pieces로 조각마다 놓는다.
#     조각 { kit, params, x, z, ry, y?(선택, 부모 높이 기준) }는 부모 기준 로컬 좌표.
#   - flatten: footprint(+2m 여유, 회전 반영) 안을 평평하게, 가장자리 5m에 걸쳐 원래 땅으로(높이맵 텍스처·CPU height_at 둘 다).
#   - clear_veg: footprint(+1m, flatten이면 고른 터 전체) 안 식생을 비운다(식생 흩뿌리기 결과에서 거름 / scatter가 exclude 인자를 받으면 넘김).
#   - state: 프롭 상태(prop_states.gd) — 문자열이면 주 상태, 사전이면 그룹별 {"main":"BURNT","hatch":"OPEN"}. 배치형 조각은 조각 state
#     또는 부모 항목의 "states": {조각 tag: 상태}. dy: 지형(터 고르기 뒤) 위로 더 올림(m) — 건물 마루 위 소품.
#   - walk(걷기 면): build() 결과의 walk 배열(§8 형식) — 없으면 돌다리·섶다리·징검다리는 params로 만든다.
#     건물 걷기 면(floor = true: 기단 윗면·댓돌·툇마루·방바닥·계단 — 키트의 M.walk_floor)도 같은 길로 들어가 height_at이 발을 바닥에 세운다.
#     다리 y가 null이면 둑 높이(다리 양 끝 지형 평균), 징검다리·나루배·빨래터는 가까운 하천 수면.
#   - when(F-11, 조건부 배치): 이야기 조건식(ph·f·w·v·active·fn) — 파일 머리 "case"(또는 항목 "case")의 사건 상태로 본다(placement_gate.gd).
#     조건이 거짓이면 장면에서 떼고 충돌체를 뺀다(지은 노드는 남겨 두었다가 참이 되면 다시 붙인다). 조건은 사건·변수가 바뀔 때만 다시 본다.
#     when 항목은 땅을 바꾸지 않는다 — 터 고르기·마당 흙 없음. 거짓이면 기본 세계에 흔적이 없다(규칙 잠금): 식생 비우기(clear_veg)도 조건부 —
#     참인 동안만 그 자리 식생 인스턴스를 숨기고 충돌체를 끈다(world.add_veg_cond·set_veg_cond — 지우거나 다시 짓지 않고 숨김/되살림).
#     늘 있는 시설(옥 등)에는 when을 달지 않는다 — 사건 때만 바뀌는 차림(단오 색천·씨름판·추수 물자·잔치 차일)에만.
#   - placeholder {kit, params}: 키트가 그 kind를 아직 못 지으면(키트 static has_kind(kind)가 false거나 키트가 없으면) 대신 지을 기존 키트.
#   파일의 "crowds"(EventCrowd, C60)는 읽어 crowds에 모아 두기만 한다 — 세우는 것은 scripts/story/event_crowd.gd.
extends RefCounted

const KitCache := preload("res://scripts/region/kit_cache.gd")
const Jobs := preload("res://scripts/region/jobs.gd")
const PlacementGate := preload("res://scripts/region/placement_gate.gd")

const FLAT_MARGIN := 2.0
var _terrace_roads := []   # [점들, 폭] — 길 터 고르기
const FLAT_EDGE := 5.0
const VEG_MARGIN := 1.0
const TAG := "placement"
const WATER_KITS := ["village/jingeom", "village/narutbae", "village/ppallaeteo"]
const BOAT_KITS := ["village/narutbae", "route/dotbae"]
const BRIDGE_KITS := ["village/stone_bridge", "village/seop_bridge"]
const YARD_COMPOSITES := ["house_compound", "gwana", "hyanggyo", "silsangsa", "jumak", "bldg/compound", "bldg/lot"]

var world   # RegionWorld
var dirs: Array = []
var parallel := true
var stats := {}
var gate = PlacementGate.new()   # when 조건(F-11) — region_main이 gate.main을 건다
var crowds: Array = []           # 파일들의 crowds 선언(+ case · _file)
var gated := {}                  # 놓인 조건부 항목 id → 정적 물체 항목(시험·촬영이 본다)
var _scripts := {}
var _mtimes := {}

func _init(w, extra_dirs: Array = []) -> void:
	world = w
	dirs = [w.data_dir]
	for d in extra_dirs:
		dirs.append(d if d.ends_with("/") else d + "/")

func files() -> Array:
	var out := []
	for d in dirs:
		var da := DirAccess.open(d)
		if da == null: continue
		for f in da.get_files():
			if f.begins_with("placement_") and f.ends_with(".json"): out.append(d + f)
	out.sort()
	return out

# 파일이 바뀌었나(추가·삭제·수정 시각)
func changed() -> bool:
	var now := {}
	for f in files(): now[f] = FileAccess.get_modified_time(f)
	return now != _mtimes

func _script(kit: String) -> Script:
	if _scripts.has(kit): return _scripts[kit]
	var path := "res://kit/%s.gd" % kit
	var s: Script = null
	if FileAccess.file_exists(path):
		s = load(path)
		if s != null and not s.can_instantiate(): s = null
	if s == null: push_warning("배치: 키트 없음/오류 " + path)
	_scripts[kit] = s
	return s

static func _has(s: Script, fn: String) -> bool:
	if s == null: return false
	for m in s.get_script_method_list():
		if m.name == fn: return true
	return false

static func _key(kit: String, params: Dictionary) -> String:
	return kit + "|" + JSON.stringify(params, "", true)

# 모두 다시: 이전 배치·터 고르기·식생 비우기·걷기 면을 지우고 처음부터
func reload() -> void:
	stop()
	if world.get("props") != null: world.props.clear_nodes()
	world.remove_tagged(TAG)
	world.reset_edits()
	gate.clear()
	gated.clear()
	load_all()

func load_all() -> void:
	var t0 := Time.get_ticks_msec()
	_mtimes = {}
	_dress_excl = []
	var raw := []
	crowds = []
	# supersede(town-organic): 파일 머리 "supersede": [id…] — 다른 파일의 그 id 항목을 빼고 이 파일 것으로 갈음한다(고을 구역 다시 짜기).
	#   원본 배치(namwon.py 생성물)를 고치지 않아 생성기를 다시 돌려도·되돌려도(이 파일을 지우면 끝) 충돌이 없다.
	var sup := {}
	var fdata := []
	_terrace_roads = []
	for f in files():
		_mtimes[f] = FileAccess.get_modified_time(f)
		var d = JSON.parse_string(FileAccess.get_file_as_string(f))
		fdata.append([f, d])
		if d is Dictionary:
			for s in d.get("supersede", []): sup[String(s)] = true
	for fd in fdata:
		var f: String = fd[0]
		var d = fd[1]
		if not (d is Dictionary) or not d.has("items"):
			push_warning("배치 파일 형식 오류: " + f); continue
		var fcase := String(d.get("case", ""))
		_dress_note_file(f, d)
		for it in d.items:
			if not (it is Dictionary and it.has("kit")): continue
			if not sup.is_empty() and sup.has(String(it.get("id", ""))) and not (d.get("supersede", []) as Array).has(it.get("id", "")): continue
			var item: Dictionary = it
			if f.get_file().begins_with("placement_story_"):
				item = item.duplicate(); item["_story_file"] = true
			if item.has("when") and not item.has("case"):
				item = item.duplicate(); item["case"] = fcase
			raw.append(_resolve_placeholder(item))
		if world.has_method("terrace_road"):
			for al in d.get("alleys", []):
				if al is Dictionary and bool(al.get("terrace", false)): _terrace_roads.append([al.get("points", []), float(al.get("width_m", 3.0))])
		for c in d.get("crowds", []):
			if not (c is Dictionary) or not c.has("id"): continue
			var cc: Dictionary = c.duplicate(true)
			if not cc.has("case"): cc["case"] = fcase
			if not cc.has("_anchors"): cc["_anchors"] = d.get("anchors", {})   # 구경(watch) 앵커 이름 → 자리
			cc["_file"] = f
			crowds.append(cc)
	# 옛 키트 실제 크기: 이야기 배치 자리(사람·소품)는 비킨다
	var story_pts := []
	for fd in fdata:
		if String(fd[0]).get_file().begins_with("placement_story_") and fd[1] is Dictionary:
			for it in fd[1].get("items", []): story_pts.append(Vector2(float(it.get("x", 0.0)), float(it.get("z", 0.0))))
	_plan_scale(raw, story_pts)
	var gated := 0
	for it in raw:
		if _when_of(it) != "": gated += 1
	stats = { files = _mtimes.size(), items = raw.size(), placed = 0, builds = 0, builds_now = 0, flatten = 0, walks = 0, missing = 0, yards = 0, gated = gated }
	if raw.is_empty():
		world.commit_terrain()
		return
	_load_catalogs()
	# 1) 배치형 풀기(layout이 있으면 짓지 않고 조각 목록만)
	var place := []
	var composite := []  # 부모(배치형): 터 고르기·식생 비우기만
	for it in raw:
		var s := _script(String(it.kit))
		if s == null: stats.missing += 1; continue
		var rec := _rec(it)
		if _has(s, "layout"):
			var ps: Array = s.layout(rec.params)
			if rec.fp == Vector2.ZERO and _has(s, "footprint"): rec.fp = world.to_v2(s.footprint(rec.params))
			if rec.fp == Vector2.ZERO: rec.fp = _catalog_fp(rec.kit, rec.params)
			_fp_from_pieces(rec, ps)
			composite.append(rec)
			for p in ps: place.append(_piece(rec, p))
		else:
			place.append(rec)
	# 2) footprint: 항목 → 키트 catalog.json → 모르면(또는 layout 없는 배치형이면) 지금 짓는다. 나머지는 타일이 가까워질 때 백그라운드로
	var round := 0
	while round < 3:
		round += 1
		var todo := {}
		for r in place:
			if r.fp == Vector2.ZERO: r.fp = _catalog_fp(r.kit, r.params)
			# 못(build 결과 water)처럼 땅을 파야 하는 키트도 지금 짓는다
			if r.fp == Vector2.ZERO and _has(_script(r.kit), "footprint"): r.fp = world.to_v2(_script(r.kit).footprint(r.params))
			# 다리(walk)·못(water)처럼 시작 때 알아야 하는 키트도 지금 짓는다
			var need_now: bool = r.fp == Vector2.ZERO or (_catalog_composite(r.kit) and not r.get("is_piece", false)) \
				or _has(_script(r.kit), "outline") or r.kit in BRIDGE_KITS or r.kit in WATER_KITS
			if r.kit.begins_with("nature/") and r.fp == Vector2.ZERO: r.fp = Vector2(4, 4); need_now = false
			var k := _key(r.kit, r.params)
			if need_now and not _cache.has(k): todo[k] = r
		if todo.is_empty(): break
		_build_all(todo, _cache)
		stats.builds_now += todo.size()
		var next := []
		for r in place:
			var info = _cache.get(_key(r.kit, r.params))
			if info is Dictionary and info.has("pieces") and not (info.pieces as Array).is_empty() and not r.get("is_piece", false):
				if r.fp == Vector2.ZERO: _fp_from_pieces(r, info.pieces)
				composite.append(r)
				for p in info.pieces: next.append(_piece(r, p))
			else:
				if info is Dictionary and r.fp == Vector2.ZERO: r.fp = world.to_v2(info.get("footprint", Vector2.ZERO))
				next.append(r)
		place = next
	# 3) 터 고르기(배치형 부모 먼저, 그다음 낱개) · 식생 비우기 · 마당 흙
	for r in composite + place:
		var fp: Vector2 = r.fp
		if fp == Vector2.ZERO: continue
		var c := Vector2(r.x, r.z)
		if r.flatten and not r.get("is_piece", false):
			var yt: float = r.y if r.y != null else NAN
			# 비탈 필지(고을 짜임): 앞 길 높이에 맞춰 고른다 — flat_at 점들의 땅 높이 평균
			var fa: Array = r.get("flat_at", [])
			if r.y == null and fa.size() > 0:
				var sy := 0.0
				for q in fa: sy += world.data_height(float(q[0]), float(q[1]))
				yt = sy / fa.size()
			r.flat_y = world.flatten_rect(c, r.ry, fp * 0.5 + Vector2(FLAT_MARGIN, FLAT_MARGIN), yt, FLAT_EDGE)
			stats.flatten += 1
		if r.clear_veg:
			var m: float = (FLAT_MARGIN + world.lcell) if r.flatten and not r.get("is_piece", false) else VEG_MARGIN
			if r.when != "" and world.has_method("add_veg_cond"):
				# 조건부(F-11 규칙 잠금): 거짓이면 기본 세계에 흔적이 없다 — 식생은 그대로 두고, 참인 동안만 그 자리 식생을 숨긴다(지우지 않음)
				var vk := "veg:%s:%d" % [String(r.id), stats.get("veg_cond", 0)]
				stats.veg_cond = int(stats.get("veg_cond", 0)) + 1
				world.add_veg_cond(vk, c, r.ry, fp * 0.5 + Vector2(m, m))
				var wv = world
				gate.add(vk, r.when, r.case, func(on: bool) -> void: wv.set_veg_cond(vk, on))
			else: world.add_veg_exclusion(c, r.ry, fp * 0.5 + Vector2(m, m))
		if r.when != "": continue   # 조건부 항목: 마당 흙을 칠하지 않는다(늘 남는 땅 변화가 되므로)
		if composite.has(r):
			# 집 묶음·관아·향교·절은 담 안 마당 전체가 흙
			for kk in YARD_COMPOSITES:
				if r.kit.ends_with(kk):
					world.paint_yard(c, r.ry, fp * 0.5 - Vector2(1.5, 1.5)); stats.yards += 1; break
		elif r.get("yard", true) and _yard_kit(r):   # 항목 "yard": false면 제 마당 흙을 칠하지 않는다(도성 안 소품 — 둘레 집 마당이 이미 칠함)
			world.paint_yard(c, r.ry, fp * 0.5)
			stats.yards += 1
	# 길 터 고르기(town-organic): 배치 alleys 중 terrace 표가 있는 길(고을 짜임이 비탈에서 낸 길)
	for fd in _terrace_roads: stats.road_terrace = int(stats.get("road_terrace", 0)) + world.terrace_road(fd[0], float(fd[1]))
	# 못 파기: build 결과 water {y, outline}(로컬) — 터 고르기 뒤 높이 기준
	for r in place:
		var info = _cache.get(_key(r.kit, r.params))
		if info is Dictionary and info.get("water") is Dictionary and info.water.has("outline"):
			var y0 := _y_for(r, {})
			var ol = info.water.outline
			var pv: PackedVector2Array = ol if ol is PackedVector2Array else PackedVector2Array(ol)
			world.carve_water(Transform3D(Basis(Vector3.UP, r.ry), Vector3(r.x, y0, r.z)), pv, float(info.water.get("y", 0.0)))
			stats.ponds = stats.get("ponds", 0) + 1
	if world.has_method("dress_building") and dress_ground: _paint_dress(composite, place)
	world.commit_terrain()
	# 4) 높이·변환·걷기 면(다리는 params로 — 짓기 전에도 걸을 수 있게)을 정하고 타일별 대기열에 넣는다
	for r in place:
		var y := _y_for(r, {})
		r.xf = Transform3D(Basis(Vector3.UP, r.ry), Vector3(r.x, y, r.z))
		r.walk_done = false
		var ws := _walks_for(r, _cache.get(_key(r.kit, r.params), {}))
		if not ws.is_empty():
			for w in ws:
				if r.when != "" and bool(w.get("floor", false)): continue
				world.add_walk(r.xf, w); stats.walks += 1
			r.walk_done = true
		var t: Vector2i = world.tile_of(r.x, r.z)
		if not _pending.has(t): _pending[t] = []
		_pending[t].append(r)
	if dress_props: _plan_dress(place)
	world.tile_listener = request_tile
	for t in world.tiles: request_tile(t)
	stats.ms = Time.get_ticks_msec() - t0
	if world.get("decals") != null: world.decals.reload_data()   # 데칼은 터 고르기 뒤 높이로
	print("PLANSCALE scaled=%d capped=%d" % [plan_scaled, plan_capped])
	print("PLACEMENT files=%d items=%d pieces=%d built_now=%d flatten=%d yards=%d walks=%d missing=%d gated=%d crowds=%d ms=%d (나머지는 타일이 가까워질 때 백그라운드로 짓는다)" % [stats.files, stats.items, place.size(), stats.builds_now, stats.flatten, stats.yards, stats.walks, stats.missing, stats.gated, crowds.size(), stats.ms])
	print("DRESS buildings=%d props_planned=%d excl=%d" % [stats.get("dress_buildings", 0), stats.get("dress_planned", 0), _dress_excl.size()])

# ---------------------------------------------------------------------------
# 지연 짓기: 타일이 생기면(중경 포함) 그 타일 항목의 키트를 작업 스레드에서 짓고, 메인 스레드는 프레임당 조금씩 놓는다
# ---------------------------------------------------------------------------
var _cache := {}       # kit+params → build() 결과
var _pending := {}     # 타일 → [rec]
var _requested := []   # 짓기를 기다리는 타일(가까운 순)
var _jobs := {}        # 타일 → { id, holders }
var _inflight := {}    # 짓는 중인 키
var _place_q := []
var _used := {}
var _packed := {}   # 키 → PackedScene(두 번째부터 instantiate)
const MAX_BUILD_JOBS := 2
const PLACE_PER_FRAME := 8
const LOADING_PLACE_US := 90000

func request_tile(t: Vector2i) -> void:
	if _pending.has(t) and not _requested.has(t) and not _jobs.has(t): _requested.append(t)

# 반경 r 타일 안에 아직 짓거나 놓을 것이 있나(시작 화면)
func busy_near(c: Vector2i, r: int) -> bool:
	for t in _requested:
		if maxi(absi(t.x - c.x), absi(t.y - c.y)) <= r: return true
	for t in _jobs:
		if maxi(absi(t.x - c.x), absi(t.y - c.y)) <= r: return true
	for q in _place_q:
		var t: Vector2i = world.tile_of(q.x, q.z)
		if maxi(absi(t.x - c.x), absi(t.y - c.y)) <= r: return true
	return false

func pending_count() -> int:
	var n := _place_q.size()
	for t in _pending: n += _pending[t].size()
	return n

func busy() -> bool:
	return not _requested.is_empty() or not _jobs.is_empty() or not _place_q.is_empty()

func update() -> void:
	# 끝난 짓기 → 캐시
	for t in _jobs.keys():
		var j: Dictionary = _jobs[t]
		if not Jobs.group_done(j.id): continue
		Jobs.group_wait(j.id)
		for h in j.holders:
			_cache[h.key] = h.info if h.info is Dictionary else {}
			_inflight.erase(h.key)
			stats.builds += 1
		_jobs.erase(t)
		if not _requested.has(t): _requested.push_front(t)
	# 기다리는 타일: 키가 다 있으면 놓기 대기열로, 없으면 짓기 시작
	if not _requested.is_empty():
		var c: Vector2i = world.tile_of(world._center.x * world.TILE + 1.0, world._center.y * world.TILE + 1.0)
		_requested.sort_custom(func(a, b): return maxi(absi(a.x - c.x), absi(a.y - c.y)) < maxi(absi(b.x - c.x), absi(b.y - c.y)))
	var i := 0
	while i < _requested.size():
		var t: Vector2i = _requested[i]
		if _jobs.has(t): i += 1; continue
		var todo := {}
		var waiting := false
		for r in _pending.get(t, []):
			var k := _key(r.kit, r.params)
			if _cache.has(k): continue
			if _inflight.has(k): waiting = true; continue
			if _script(r.kit) != null: todo[k] = r
		if todo.is_empty() and not waiting:
			for r in _pending.get(t, []): _place_q.append(r)
			_pending.erase(t)
			_requested.remove_at(i)
			continue
		if not todo.is_empty() and _jobs.size() < (MAX_BUILD_JOBS * 3 if world.loading else MAX_BUILD_JOBS):
			var holders := []
			for k in todo:
				holders.append({ key = k, kit = todo[k].kit, s = _script(todo[k].kit), params = todo[k].params, info = null })
				_inflight[k] = true
			var job := func(n: int) -> void:
				if _cancel: return   # 끝내기·넘어가기: 아직 시작 안 한 짓기는 건너뛴다
				var h: Dictionary = holders[n]
				h.info = KitCache.build(h.kit, h.s, h.params)
			var id := Jobs.add_group(job, holders.size(), mini(holders.size(), 4), "kit build")
			_jobs[t] = { id = id, holders = holders }
			_requested.remove_at(i)
			continue
		i += 1
	# 놓기(프레임당 몇 개)
	# 불러오기 화면 동안은 시간 예산(프레임당 약 90ms)으로 많이 놓는다 — 화면이 가려져 있어 프레임이 느려도 된다
	var n := 0
	var t_end := Time.get_ticks_usec() + LOADING_PLACE_US
	while not _place_q.is_empty() and (n < PLACE_PER_FRAME or (world.loading and Time.get_ticks_usec() < t_end)):
		_place_one(_place_q.pop_front())
		n += 1

func _place_one(r: Dictionary) -> void:
	var k := _key(r.kit, r.params)
	var info = _cache.get(k)
	if not (info is Dictionary) or info.get("node") == null: return
	if r.get("dress", false) and not _dress_ok(r): stats.dress_skipped = int(stats.get("dress_skipped", 0)) + 1; return
	if not _used.has(k): KitCache.save_if_needed(info)
	var node: Node3D
	# 같은 키트를 여러 번 놓을 때: Node.duplicate()는 느리다(한양 5천 개에 2.5s) → 처음 쓸 때 PackedScene으로 싸 두고 instantiate
	if not _used.has(k):
		_used[k] = true
		var ps := PackedScene.new()
		KitCache._own(info.node, info.node)
		if ps.pack(info.node) == OK: _packed[k] = ps
		node = info.node
	else:
		var ps: PackedScene = _packed.get(k)
		node = ps.instantiate() if ps != null else info.node.duplicate()
	node.name = String(r.id) if r.id != "" else node.name
	var entry = world.add_static(node, r.xf, info, TAG)
	if world.get("props") != null and entry is Dictionary: world.props.register(String(r.id), node, entry, info, r.get("state"))
	if r.when != "" and entry is Dictionary:
		# 조건부(F-11): 지금 값으로 곧바로 켜고 끈다(같은 프레임 — 꺼진 항목이 한 프레임도 그려지지 않는다)
		var e: Dictionary = entry
		gated[String(r.id)] = e
		var wd = world
		gate.add(String(r.id), r.when, r.case, func(on: bool) -> void: wd.set_static_enabled(e, on))
	if not r.walk_done:
		for w in _walks_for(r, info):
			if r.when != "" and bool(w.get("floor", false)): continue   # 조건부 항목의 건물 걷기 면은 두지 않는다(꺼져도 바닥이 남지 않게)
			world.add_walk(r.xf, w); stats.walks += 1
	if info.get("water") is Dictionary and not _has(_script(r.kit), "outline"):
		push_warning("배치: %s는 water가 있지만 늦게 지어져 땅을 파지 못했다(키트에 static outline()을 두거나 footprint 없이 두면 시작 때 짓는다)" % r.kit)
	stats.placed += 1

# 진행 중 짓기가 모두 끝났나(끝내기 전 기다리기용 — 메인 스레드를 막지 않고 프레임을 돌리며 확인)
var _cancel := false
func cancel_jobs() -> void:
	_cancel = true

func jobs_idle() -> bool:
	for t in _jobs:
		if not Jobs.group_done(_jobs[t].id): return false
	return true

# 진행 중 짓기를 기다리고 대기열을 비운다(다시 읽기·끝내기 전)
# 주의: 키트 짓기는 작업 스레드에서 렌더 서버와 동기화하는 호출을 할 수 있어, 진행 중인 짓기를 메인 스레드에서 막고 기다리면
# 서로 기다리다 멈춘다(끝내기 exit=124). 끝내기·넘어가기는 region_main._drain_jobs()로 jobs_idle()이 될 때까지 프레임을 돌린 뒤 부른다.
func stop() -> void:
	for t in _jobs: Jobs.group_wait(_jobs[t].id)
	_jobs.clear(); _inflight.clear(); _requested.clear(); _pending.clear(); _place_q.clear()
	for k in _cache:
		var info = _cache[k]
		if info is Dictionary and info.get("node") != null and not _used.has(k) and is_instance_valid(info.node) and not info.node.is_inside_tree():
			info.node.free()
	_cache.clear(); _used.clear(); _packed.clear()
	_cancel = false

# 마당 흙을 칠할 키트: 건물·소품(담장·성벽·다리·나무 제외)
# ---- 땅 꾸밈 칠하기(visual-pass — region_world.dbytes, 지형 셰이더 town_layer) ----
# 지붕 있는 건물: 처마 선 부호 거리(낙숫물 줄·처마 밑 그늘·기단 때) · 장터: 짚·배추 잎 · 물가: 진흙·웅덩이 · 관아·궁궐·향교 담 안: 박석
const DRESS_NOT_BUILDING := ["wall", "seong_", "pond", "tap", "seok", "rock", "gyo", "dan", "maaebul", "tumulus", "cheomseongdae", "dolhareubang",
	"jangsangot", "giringgul", "eulmildae", "bansong", "madang", "naru", "cheoyongam", "gimnyeongsagul", "samseonghyeol", "dangganjiju",
	"todam", "fence", "village_square", "stone_terrace", "house_compound", "jangseung", "sotdae", "torch_post", "teotbat", "yard_props",
	"props", "firewood", "jige", "haystack", "jangdok", "well", "jingeom", "bridge", "narutbae", "ppallaeteo", "cairn", "jwapan", "saripmun", "ijeongpyo", "myo", "sinmok", "dotbae", "waterfall", "tteotmok", "jounseon", "nature/", "story/", "scenario/"]
const DRESS_PAVED := ["landmark/gwana", "landmark/hyanggyo", "landmark/hyeon_gwana", "landmark/gn_gwana", "landmark/gn_imyeonggwan", "landmark/hh_bongung",
	"landmark/jj_mokgwana", "landmark/hy_gyeongbokgung", "landmark/hy_changdeokgung", "landmark/gj_bulguksa"]
const DRESS_MARKET := ["market_shop", "jwapan", "hy_sijeon"]
const DRESS_WET := { "village/well": 5.0, "village/ppallaeteo": 6.0, "village/narutbae": 7.0, "village/jingeom": 4.0 }

# ---- 생활 소품 저절로 놓기(visual-pass 1단계) ----
# 집(지붕 있는 키트)마다 뒤·옆·앞 모서리 처마 밖 0.5~1m에 2~4개. 앞 가운데(문·댓돌 쪽 +z)·길(가장자리 1.6m)·이야기 배치·조건부 배치·역참 둘레는 비운다.
# 놓는 순간(그 타일 정적 물체가 놓인 뒤) 둘레가 막혔는지(world.blocked)와 바깥으로 지나갈 틈(1.3m)을 다시 본다 — 길·문·댓돌·앉을 자리를 막지 않게.
# 같은 kit+params 몇 벌만 쓴다(키트 캐시·PackedScene 재사용). --nodress로 끔(비교).
var dress_props := true
var dress_ground := true   # 땅 꾸밈 칠하기(--noground로 끔)
var _dress_excl := []   # [Vector2 자리, 반지름]
var chimneys := []      # 굴뚝 연기 자리(Vector3 — ambient_fx): 사람 사는 초가·주막·너와·굴피·귀틀집의 반쯤
const CHIMNEY_KITS := ["village/choga", "village/choga_low", "village/jumak", "village/neowa_house", "village/gulpi_house", "village/guitul_house"]
const DRESS_SETS := {
	common = [
		{ kit = "village/props", params = { kind = "dok", n = 3, seed = 9101 }, r = 0.8, d = 1.0 },
		{ kit = "village/props", params = { kind = "dok", n = 2, seed = 9102 }, r = 0.65, d = 0.9 },
		{ kit = "village/props", params = { kind = "soguri", fill = "grain", seed = 9103 }, r = 0.42, d = 0.8 },
		{ kit = "village/props", params = { kind = "soguri", fill = "veg", seed = 9104 }, r = 0.42, d = 0.8 },
		{ kit = "village/props", params = { kind = "byeotdan", seed = 9105 }, r = 0.85, d = 1.4 },
		{ kit = "village/firewood", params = { seed = 9106, len = 1.6, rows = 3 }, r = 0.9, d = 1.0, wall = true },
		{ kit = "village/jige", params = { seed = 9107, load = "wood" }, r = 0.45, d = 1.0 },
		{ kit = "village/props", params = { kind = "jeolgu", seed = 9108 }, r = 0.35, d = 0.7 },
		{ kit = "village/dress_props", params = { kind = "tools", seed = 9109 }, r = 0.65, d = 0.6, wall = true },
		{ kit = "village/dress_props", params = { kind = "laundry", seed = 9110 }, r = 1.6, d = 0.7, wall = true, side = false },
		{ kit = "village/dress_props", params = { kind = "flowers", seed = 9111 }, r = 0.8, d = 0.9, wall = true },
		{ kit = "village/dress_props", params = { kind = "gochu", seed = 9112 }, r = 0.95, d = 1.3, rare = true },
	],
	shop = [
		{ kit = "village/props", params = { kind = "dok", n = 3, seed = 9101 }, r = 0.8, d = 1.0 },
		{ kit = "village/props", params = { kind = "soguri", fill = "veg", seed = 9104 }, r = 0.42, d = 0.8 },
		{ kit = "village/props", params = { kind = "byeotdan", seed = 9105 }, r = 0.85, d = 1.4 },
		{ kit = "village/jige", params = { seed = 9107, load = "basket" }, r = 0.45, d = 1.0 },
	],
	barn = [
		{ kit = "village/props", params = { kind = "byeotdan", seed = 9105 }, r = 0.85, d = 1.4 },
		{ kit = "village/jige", params = { seed = 9107, load = "wood" }, r = 0.45, d = 1.0 },
		{ kit = "village/firewood", params = { seed = 9106, len = 1.6, rows = 3 }, r = 0.9, d = 1.0, wall = true },
	],
}
const DRESS_HOUSES := ["choga", "giwa", "jumak", "neowa_house", "gulpi_house", "guitul_house", "mulbang_a", "didil_bang_a", "dwitgan", "oeyanggan", "culture/"]

func _dress_note_file(f: String, d: Dictionary) -> void:
	var story := f.get_file().begins_with("placement_story_") or f.get_file().begins_with("placement_scenario")
	var station := f.get_file().begins_with("placement_stations")
	if not (story or station):
		return
	for it in d.get("items", []):
		if not (it is Dictionary) or not it.has("x") or not it.has("z"): continue
		var fp: Vector2 = world.to_v2(it.get("footprint", Vector2(4, 4)))
		_dress_excl.append([Vector2(float(it.x), float(it.z)), fp.length() * 0.5 + (12.0 if station else 4.0)])
	var an = d.get("anchors", {})
	if an is Dictionary:
		for k in an:
			var v = an[k]
			if v is Array and v.size() >= 2: _dress_excl.append([Vector2(float(v[0]), float(v[1])), 3.0])
			elif v is Dictionary and v.has("x"): _dress_excl.append([Vector2(float(v.x), float(v.get("z", 0.0))), 3.0])

func _dress_excluded(p: Vector2) -> bool:
	for e in _dress_excl:
		if p.distance_squared_to(e[0]) < e[1] * e[1]: return true
	return false

func _plan_dress(place: Array) -> void:
	var n := 0
	chimneys = []
	for r in place:
		if r.when != "" or r.fp == Vector2.ZERO or r.get("dress", false): continue
		if r.kit in CHIMNEY_KITS and str(r.params.get("chimney", true)) != "false" and str(r.params.get("interior", false)) != "true" \
				and absi(hash(String(r.id) + "smoke")) % 2 == 0 and not _dress_excluded(Vector2(r.x, r.z)):
			# 초가 굴뚝: 오른쪽(+x) 벽 끝 바깥, 뒤쪽 — 키트 choga.gd(W/2 + 0.55, 꼭대기 1.25, −zf + 0.4)를 footprint로 어림
			var lc := Vector2(r.fp.x * 0.5 - 0.6, -r.fp.y * 0.5 + 1.5)
			var cc := cos(r.ry); var ss := sin(r.ry)
			var w := Vector2(r.x, r.z) + Vector2(lc.x * cc + lc.y * ss, -lc.x * ss + lc.y * cc)
			chimneys.append(Vector3(w.x, (r.xf as Transform3D).origin.y + 1.35, w.y))
		var kit: String = r.kit
		var set_name := ""
		if kit.contains("market_shop"): set_name = "shop"
		elif kit.contains("heotgan"): set_name = "barn"
		else:
			for h in DRESS_HOUSES:
				if kit.contains(h): set_name = "common"; break
		if set_name == "": continue
		if str(r.params.get("interior", false)) == "true": continue   # 들어가는 외딴집(이야기 무대 — 이겸 거처 등)은 손대지 않는다
		var c := Vector2(r.x, r.z)
		if _dress_excluded(c): continue
		var hsh := absi(hash(String(r.id) + kit + str(snappedf(r.x, 0.1)))) 
		var want := 2 + (hsh % 3)   # 2~4개
		if set_name == "shop": want = 1 + (hsh % 2)
		var lst: Array = DRESS_SETS[set_name]
		var half: Vector2 = r.fp * 0.5
		var ca := cos(r.ry); var sa := sin(r.ry)
		var used := []
		for q in want * 3:
			if used.size() >= want: break
			var h2 := absi(hash(hsh + q * 7919))
			var spec: Dictionary = lst[h2 % lst.size()]
			if spec.get("rare", false) and (h2 >> 5) % 4 != 0: continue
			var dup := false
			for u in used:
				if u.kit == spec.kit and u.params == spec.params: dup = true
			if dup: continue
			# 면: 0 뒤(−z) · 1 왼쪽(−x) · 2 오른쪽(+x) · 3·4 앞 모서리(처마 끝 바깥 — 가운데 문·댓돌 쪽은 비운다). 3인칭 카메라는 남쪽에서 보므로
			#   대개 남향인 집의 앞 모서리·옆이 화면에 든다. 벽에 기대는 소품은 앞 모서리에 두지 않는다
			var face: int = [0, 1, 2, 1, 2, 3, 4, 3, 4][(h2 >> 3) % 9]
			if spec.get("wall", false) and face >= 3: face -= 2
			if not spec.get("side", true): face = 0
			var t := (float((h2 >> 7) % 1000) / 1000.0 - 0.5)
			var dep: float = spec.d * 0.5 + 0.55
			var lp: Vector2; var lry := 0.0
			match face:
				0: lp = Vector2(t * maxf(half.x * 2.0 - 2.4, 0.0), -half.y - dep); lry = PI
				1: lp = Vector2(-half.x - dep, -half.y * (0.15 + 0.6 * (t + 0.5))); lry = -PI / 2
				2: lp = Vector2(half.x + dep, -half.y * (0.15 + 0.6 * (t + 0.5))); lry = PI / 2
				_:
					if half.x < 2.6: continue   # 좁은 집은 앞 모서리가 문 곁이다
					lp = Vector2((-1.0 if face == 3 else 1.0) * (half.x - float(spec.r) * 0.6 - 0.2), half.y + dep * 0.8); lry = 0.0
			# 로컬 → 월드(Basis(UP, ry)): x' = x·cos + z·sin, z' = −x·sin + z·cos
			var wp := c + Vector2(lp.x * ca + lp.y * sa, -lp.x * sa + lp.y * ca)
			var out := Vector2(sin(r.ry + lry), cos(r.ry + lry))   # 벽에서 바깥쪽(소품 앞 +z가 마당 쪽)
			if not spec.get("wall", false): lry += (float((h2 >> 11) % 100) / 100.0 - 0.5) * 0.8
			var ok := true
			for u in used:
				if wp.distance_to(u.p) < float(u.r) + float(spec.r) + 0.3: ok = false
			if not ok or _dress_excluded(wp): continue
			if world.has_method("road_distance") and world.road_distance(wp.x, wp.y) < float(spec.r) + 1.6: continue
			var rec := { id = "dress_%s_%d" % [String(r.id) if r.id != "" else str(hsh), used.size()], kit = spec.kit, params = spec.params,
				x = wp.x, z = wp.y, ry = r.ry + lry, y = null, flatten = false, clear_veg = false, fp = Vector2(spec.r * 2.0, spec.d), flat_y = NAN,
				yard = false, state = null, states = {}, dy = 0.0, when = "", case = "", dress = true, dress_r = float(spec.r), dress_out = out, walk_done = true }
			rec.xf = Transform3D(Basis(Vector3.UP, rec.ry), Vector3(wp.x, _y_for(rec, {}), wp.y))
			used.append({ kit = spec.kit, params = spec.params, p = wp, r = spec.r })
			var tt: Vector2i = world.tile_of(wp.x, wp.y)
			if not _pending.has(tt): _pending[tt] = []
			_pending[tt].append(rec)
			n += 1
	stats.dress_planned = n

# 놓기 직전: 그 자리와 바깥쪽 지나갈 틈이 비었나(그 타일의 정적 물체·식생 충돌체가 이미 들어온 뒤)
func _dress_ok(r: Dictionary) -> bool:
	if not world.has_method("blocked"): return true
	var rr: float = r.dress_r
	if world.blocked(r.x, r.z, rr * 0.8): return false
	var o: Vector2 = r.dress_out
	var p2 := Vector2(r.x, r.z) + o * (rr + 1.0)
	if world.blocked(p2.x, p2.y, 0.45): return false
	if world.has_method("walk_at") and world.walk_at(r.x, r.z, false) != null: return false   # 기단·마루·다리 걷기 면 위에는 두지 않는다
	return true

static func dress_is_building(kit: String) -> bool:
	if not (kit.begins_with("village/") or kit.begins_with("landmark/") or kit.begins_with("culture/") or kit.begins_with("route/") or kit.begins_with("bldg/")): return false
	for w in DRESS_NOT_BUILDING:
		if kit.contains(w): return false
	return true

func _paint_dress(composite: Array, place: Array) -> void:
	var nb := 0
	for r in place:
		if r.when != "": continue   # 조건부 항목은 땅을 바꾸지 않는다(규칙 잠금)
		var c := Vector2(r.x, r.z)
		var fp: Vector2 = r.fp
		if fp != Vector2.ZERO and dress_is_building(r.kit) and not _catalog_composite(r.kit):
			world.dress_building(c, r.ry, fp * 0.5); nb += 1
		for m in DRESS_MARKET:
			if r.kit.contains(m): world.dress_disc(1, c, 7.0 + fp.length() * 0.3); break
		if DRESS_WET.has(r.kit): world.dress_disc(2, c, DRESS_WET[r.kit])
	for r in composite:
		if r.when != "" or r.fp == Vector2.ZERO: continue
		if r.kit in DRESS_PAVED: world.dress_paved(Vector2(r.x, r.z), r.ry, r.fp * 0.5 - Vector2(1.5, 1.5))
	stats.dress_buildings = nb

static func _yard_kit(r: Dictionary) -> bool:
	var k: String = r.kit
	if k.begins_with("nature/"): return false
	# 담 조각(wall_run·fence·todam)은 조각 자리가 (0,0)이고 점이 params에 있어 footprint가 맞지 않는다 → 제외
	if r.get("is_piece", false) and float(r.get("lx", 1.0)) == 0.0 and float(r.get("lz", 1.0)) == 0.0: return false
	for w in ["wall", "fence", "todam", "seong_", "bridge", "jingeom", "narutbae", "ppallaeteo", "pond", "ojakgyo", "jangseung", "sotdae", "torch_post", "maaebul"]:
		if k.contains(w): return false
	return true

# ---- 키트 카탈로그(kit/<칸>/catalog.json)의 footprint ----
var _cat := {}
func _load_catalogs() -> void:
	if not _cat.is_empty(): return
	for d in ["village", "landmark", "nature", "route", "scenario"]:
		var path := "res://kit/%s/catalog.json" % d
		if not FileAccess.file_exists(path): continue
		var c = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not (c is Dictionary) or not (c.get("models") is Array): continue
		for m in c.models:
			if not (m is Dictionary) or not m.has("name"): continue
			_cat["%s/%s" % [d, m.name]] = m

func _catalog_composite(kit: String) -> bool:
	var m = _cat.get(kit)
	return m is Dictionary and bool(m.get("composite", false))

func _catalog_fp(kit: String, params: Dictionary) -> Vector2:
	var m = _cat.get(kit)
	if not (m is Dictionary): return Vector2.ZERO
	# params가 맞는 변형(시드 말고 다른 값이 모두 같은 것)이 있으면 그 footprint
	for v in m.get("variants", []):
		if not (v is Dictionary) or not (v.get("params") is Dictionary) or not v.has("footprint"): continue
		var ok := true
		var any := false
		for key in v.params:
			if key == "seed": continue
			any = true
			if not params.has(key) or str(params[key]) != str(v.params[key]): ok = false; break
		if ok and any: return world.to_v2(v.footprint)
	return world.to_v2(m.get("footprint", Vector2.ZERO))

func _rec(it: Dictionary) -> Dictionary:
	return { id = String(it.get("id", "")), kit = String(it.kit), params = it.get("params", {}) if it.get("params") is Dictionary else {},
		x = float(it.get("x", 0.0)), z = float(it.get("z", 0.0)), ry = float(it.get("ry", 0.0)),
		y = (float(it.y) if it.get("y") != null else null), flatten = bool(it.get("flatten", false)) and _when_of(it) == "",
		clear_veg = bool(it.get("clear_veg", true)), fp = world.to_v2(it.get("footprint", Vector2.ZERO)), flat_y = NAN,
		yard = bool(it.get("yard", true)), state = it.get("state"), states = it.get("states", {}) if it.get("states") is Dictionary else {},
		dy = float(it.get("dy", 0.0)), when = _when_of(it), case = String(it.get("case", "")), flat_at = it.get("flat_at", []) }

static func _when_of(it: Dictionary) -> String:
	var w := PlacementGate._norm(it.get("when"))
	return "" if w == "true" else w

# placeholder: 키트가 그 kind를 아직 못 지으면 대신 지을 기존 키트(초안 차림 — 키트 static has_kind(kind))
func _resolve_placeholder(it: Dictionary) -> Dictionary:
	if not (it.get("placeholder") is Dictionary): return it
	var path := "res://kit/%s.gd" % String(it.kit)
	var ok := FileAccess.file_exists(path)
	if ok:
		var s := _script(String(it.kit))
		if s == null: ok = false
		elif _has(s, "has_kind"):
			var P: Dictionary = it.get("params", {}) if it.get("params") is Dictionary else {}
			ok = bool(s.has_kind(String(P.get("kind", ""))))
	if ok: return it
	var o := it.duplicate()
	o.kit = String(it.placeholder.get("kit", it.kit))
	o.params = it.placeholder.get("params", {})
	return o

# 배치형 footprint가 없으면 조각 자리로 어림(+8m)
func _fp_from_pieces(rec: Dictionary, ps: Array) -> void:
	if rec.fp != Vector2.ZERO or ps.is_empty(): return
	var m := Vector2.ZERO
	for p in ps: m = Vector2(maxf(m.x, absf(float(p.get("x", 0.0)))), maxf(m.y, absf(float(p.get("z", 0.0)))))
	rec.fp = (m + Vector2(8, 8)) * 2.0

# 조각: 부모 기준 로컬 → 월드
func _piece(parent: Dictionary, p: Dictionary) -> Dictionary:
	var b := Basis(Vector3.UP, parent.ry)
	var w: Vector3 = b * Vector3(float(p.get("x", 0.0)), 0, float(p.get("z", 0.0)))
	var r := { id = "%s/%s" % [parent.id, String(p.get("tag", p.get("kit", "piece")))], kit = String(p.kit),
		params = p.get("params", {}) if p.get("params") is Dictionary else {},
		x = parent.x + w.x, z = parent.z + w.z, ry = parent.ry + float(p.get("ry", 0.0)), y = null,
		flatten = false, clear_veg = false, fp = Vector2.ZERO, flat_y = NAN, is_piece = true, parent = parent, py = p.get("y"), yard = parent.get("yard", true),
		lx = float(p.get("x", 0.0)), lz = float(p.get("z", 0.0)),
		state = p.get("state", (parent.get("states", {}) as Dictionary).get(String(p.get("tag", "")))), dy = float(p.get("dy", 0.0)),
		when = String(parent.get("when", "")), case = String(parent.get("case", "")) }
	return r

func _y_for(r: Dictionary, info: Dictionary) -> float:
	return _y_base(r, info) + float(r.get("dy", 0.0))

func _y_base(r: Dictionary, info: Dictionary) -> float:
	# 배(나룻배)는 손으로 적은 y보다 찾은 물 면(하천·호수·바다·큰 강 — RegionWorld.river_surface_at)을 따른다
	if r.kit in BOAT_KITS and not r.get("is_piece", false):
		var bs: float = world.river_surface_at(r.x, r.z, 40.0)
		if not is_nan(bs): return bs
	if r.y != null: return r.y
	if r.get("is_piece", false) and r.py != null:
		var par: Dictionary = r.parent
		var base: float = par.y if par.y != null else (par.flat_y if not is_nan(par.flat_y) else world.ground_at(par.x, par.z))
		return base + float(r.py)
	if r.kit in BRIDGE_KITS:
		# 둑 높이: 다리 양 끝 바깥 1m 지형 평균
		var L := float(r.params.get("len", 9.6 if r.kit.ends_with("stone_bridge") else 10.0))
		var b := Basis(Vector3.UP, r.ry)
		var a: Vector3 = b * Vector3(0, 0, L * 0.5 + 1.0)
		return (world.ground_at(r.x + a.x, r.z + a.z) + world.ground_at(r.x - a.x, r.z - a.z)) * 0.5
	if r.kit in WATER_KITS:
		var ws: float = world.river_surface_at(r.x, r.z, 40.0)
		if not is_nan(ws): return ws
	if not is_nan(r.flat_y): return r.flat_y
	return world.ground_at(r.x, r.z)

# 걷기 면: 키트가 walk를 주면 그대로, 아니면 아는 다리 키트는 params로 만든다
func _walks_for(r: Dictionary, info: Dictionary) -> Array:
	var w = info.get("walk")
	if w is Array: return w
	if w is Dictionary: return [w]
	var P: Dictionary = r.params
	match r.kit:
		"village/stone_bridge":
			var L := float(P.get("len", 9.6)); var hw := float(P.get("hw", 1.3)); var ar := float(P.get("arch", 0.55))
			var zs := []; var ys := []
			for i in 13:
				var z := -L / 2 + L * i / 12.0
				var t := z / (L / 2)
				zs.append(z); ys.append(0.1 + ar * (1 - t * t))
			return [{ minX = -hw + 0.2, maxX = hw - 0.2, minZ = -L / 2 - 0.3, maxZ = L / 2 + 0.3, z = zs, y = ys }]
		"village/seop_bridge":
			var L := float(P.get("len", 10.0)); var hw := float(P.get("hw", 0.8))
			var zs := []; var ys := []
			for i in 21:
				var z := -L / 2 + L * i / 20.0
				var t := absf(z) / (L / 2)
				zs.append(z); ys.append(0.05 + 0.55 * (1.0 - smoothstep(0.7, 1.0, t)) + 0.12)
			return [{ minX = -hw + 0.1, maxX = hw - 0.1, minZ = -L / 2 - 0.3, maxZ = L / 2 + 0.3, z = zs, y = ys }]
		"village/jingeom":
			var L := float(P.get("len", 6.0))
			return [{ minX = -0.55, maxX = 0.55, minZ = -L / 2 - 0.6, maxZ = L / 2 + 0.6, z = [-L / 2 - 0.6, L / 2 + 0.6], y = [0.15, 0.15] }]
	return []

# 서로 다른 kit+params를 작업 스레드 여러 개로 짓는다(Kit 캐시는 Mutex로 보호됨). --serialbuild면 한 줄로
func _build_all(todo: Dictionary, cache: Dictionary) -> void:
	var keys := todo.keys()
	var holders := []
	for k in keys:
		holders.append({ kit = todo[k].kit, s = _script(todo[k].kit), params = todo[k].params, info = null })
	var job := func(i: int) -> void:
		var h: Dictionary = holders[i]
		h.info = KitCache.build(h.kit, h.s, h.params)
	if parallel and keys.size() > 1:
		var gid := Jobs.add_group(job, keys.size(), -1, "kit build")
		Jobs.group_wait(gid)
	else:
		for i in keys.size(): job.call(i)
	for i in keys.size():
		cache[keys[i]] = holders[i].info if holders[i].info is Dictionary else {}
		stats.builds += 1

# ---- 옛 키트 실제 크기(town-organic 2단계) ----
# 빌더 건물(×1.16~1.22, 인물 2.0m)에 맞춰 옛 village/* 집을 키운다: 평면(w·d)과 벽 높이(wall_h)만 — 바닥·기단 높이는 그대로(계단 한 걸음 0.32m를 지킨다).
#   이웃 항목·이야기 자리·길과 새로 겹치면 겹치지 않을 만큼만(1.0~목표 배율). 큰 건물(landmark/*)과 고을 짜임(bldg/*)은 건드리지 않는다.
#   --noplanscale로 끈다(비교).
const PLAN_K := { "village/choga": 1.2, "village/giwa": 1.22, "village/jumak": 1.2, "village/market_shop": 1.2, "village/neowa_house": 1.16, "village/gulpi_house": 1.16,
	"village/heotgan": 1.16, "village/oeyanggan": 1.16, "village/mulbang_a": 1.16, "village/didil_bang_a": 1.16, "village/house_compound": 1.2 }
const PLAN_DEF := { "village/choga": [6.0, 4.0, 1.85], "village/giwa": [9.0, 5.4, 2.3], "village/jumak": [7.2, 4.4, 1.85], "village/market_shop": [6.0, 3.0, 0.0],
	"village/neowa_house": [6.4, 4.2, 1.85], "village/gulpi_house": [6.0, 4.0, 1.85], "village/heotgan": [4.0, 2.8, 0.0], "village/oeyanggan": [3.6, 3.0, 0.0],
	"village/mulbang_a": [3.6, 4.4, 0.0], "village/didil_bang_a": [4.0, 3.0, 0.0] }
var plan_scaled := 0
var plan_capped := 0
var plan_items := []   # [가운데, ry, 반폭(키우기 전), k] — 이야기 자리 옮기기(plan_remap)

# 이야기 자리(앵커) 옮기기: 키운 집 둘레(반폭×k + 6m) 안 점은 집 가운데를 기준으로 같은 배율로 — 대문·마당 자리가 커진 집을 따라간다
func plan_remap(p: Vector2) -> Vector2:
	var best = null; var bd := INF
	for e in plan_items:
		var c: Vector2 = e[0]; var ry: float = e[1]; var h: Vector2 = e[2]; var k: float = e[3]
		var d := p - c
		var lx := d.x * cos(ry) - d.y * sin(ry); var lz := d.x * sin(ry) + d.y * cos(ry)
		if absf(lx) <= h.x * k + 6.0 and absf(lz) <= h.y * k + 6.0 and d.length() < bd: bd = d.length(); best = e
	if best == null: return p
	return (best[0] as Vector2) + (p - (best[0] as Vector2)) * float(best[3])

static func _prect(c: Vector2, half: Vector2, ry: float) -> Array:
	var out := []
	for q in [Vector2(-half.x, -half.y), Vector2(half.x, -half.y), Vector2(half.x, half.y), Vector2(-half.x, half.y)]:
		out.append(c + Vector2(q.x * cos(ry) + q.y * sin(ry), -q.x * sin(ry) + q.y * cos(ry)))
	return out

static func _poly_overlap(A: Array, B: Array) -> bool:
	# 볼록 사각 둘: 분리축 검사
	for P in [A, B]:
		for i in P.size():
			var e: Vector2 = (P[(i + 1) % P.size()] as Vector2) - P[i]
			var n := Vector2(-e.y, e.x)
			var a0 := INF; var a1 := -INF; var b0 := INF; var b1 := -INF
			for q in A: var t: float = n.dot(q); a0 = minf(a0, t); a1 = maxf(a1, t)
			for q in B: var t2: float = n.dot(q); b0 = minf(b0, t2); b1 = maxf(b1, t2)
			if a1 <= b0 or b1 <= a0: return false
	return true

func _plan_half(it: Dictionary) -> Vector2:
	var fp = it.get("footprint")
	if fp is Array: return Vector2(float(fp[0]), float(fp[1])) * 0.5
	var df = PLAN_DEF.get(String(it.kit))
	var p: Dictionary = it.get("params", {})
	if df is Array: return Vector2(float(p.get("w", df[0])) + 2.0, float(p.get("d", df[1])) + 2.4) * 0.5
	return Vector2(1.5, 1.5)

func _plan_scale(raw: Array, story_pts: Array) -> void:
	plan_scaled = 0; plan_capped = 0; plan_items = []
	if world == null or world.get("region") == null: return
	var args := {}
	for a in OS.get_cmdline_user_args(): args[a.trim_prefix("--").split("=")[0]] = true
	if args.has("noplanscale"): return
	# 격자(30m)에 항목 사각
	var grid := {}
	var rects := []
	for i in raw.size():
		var it: Dictionary = raw[i]
		var c := Vector2(float(it.get("x", 0.0)), float(it.get("z", 0.0)))
		var h := _plan_half(it)
		var kk0 := String(it.kit)
		var solid := kk0.begins_with("landmark/") or kk0.begins_with("bldg/") or PLAN_K.has(kk0) or kk0 in ["village/todam", "village/wall_run", "village/stone_wall", "village/daemun", "village/jwapan", "village/well", "village/jeongja", "village/seonghwangdang"]
		if h.length() < 0.8 or not solid: rects.append(null); continue   # 마당 소품·짚가리·텃밭은 비키지 않는다(집이 커지면 옮겨 놓을 것들)
		var rc := _prect(c, h, float(it.get("ry", 0.0)))
		rects.append(rc)
		var g := Vector2i(floori(c.x / 30.0), floori(c.y / 30.0))
		if not grid.has(g): grid[g] = []
		grid[g].append(i)
	var roads: Array = world.region.get("roads", []) if world.region.get("roads") is Array else []
	var road_lines := []
	for rd in roads:
		var pts := PackedVector2Array()
		for q in rd.get("points", []): pts.append(Vector2(float(q[0]), float(q[1])))
		if pts.size() >= 2: road_lines.append([pts, float(rd.get("width_m", 3.0)) * 0.5])
	var road_hit := func(rc: Array) -> bool:
		var cc := (rc[0] as Vector2).lerp(rc[2], 0.5)
		for rl in road_lines:
			var pts: PackedVector2Array = rl[0]
			for j in pts.size() - 1:
				var a := pts[j]; var b := pts[j + 1]
				if Geometry2D.get_closest_point_to_segment(cc, a, b).distance_to(cc) > 40.0: continue
				for q in rc + [cc]:
					if Geometry2D.get_closest_point_to_segment(q, a, b).distance_to(q) < float(rl[1]): return true
				# 길이 사각 안을 지나는 경우
				if Geometry2D.is_point_in_polygon(Geometry2D.get_closest_point_to_segment(cc, a, b), PackedVector2Array(rc)): return true
		return false
	for i in raw.size():
		var it: Dictionary = raw[i]
		var kit := String(it.kit)
		if not PLAN_K.has(kit) or rects[i] == null: continue
		if String(it.get("id", "")).begins_with("org") or it.has("plan_k") or bool(it.get("_story_file", false)): continue   # 이야기 배치 묶음(집 + 마당 소품 + 연출 동선)은 그대로
		var target: float = PLAN_K[kit]
		if kit == "village/house_compound": target = { small = 1.16, medium = 1.2, large = 1.22 }.get(String((it.get("params", {}) as Dictionary).get("size", "small")), 1.2)
		var c := Vector2(float(it.get("x", 0.0)), float(it.get("z", 0.0)))
		var ry := float(it.get("ry", 0.0))
		var h0 := _plan_half(it)
		var orig: Array = rects[i]
		var g0 := Vector2i(floori(c.x / 30.0), floori(c.y / 30.0))
		var neigh := []
		for dz in range(-1, 2):
			for dx in range(-1, 2):
				for j in grid.get(g0 + Vector2i(dx, dz), []):
					if j != i and rects[j] != null and not _poly_overlap(orig, rects[j]): neigh.append(j)
		var road0: bool = road_hit.call(orig)
		var k := 1.0
		for kk in [target, 1.0 + (target - 1.0) * 0.75, 1.0 + (target - 1.0) * 0.5, 1.0 + (target - 1.0) * 0.25]:
			# 바깥 담·처마 끝까지 같은 비로 커진다고 보고 검사(평면만 키우므로 바닥 사각만)
			var rc := _prect(c, h0 * float(kk), ry)
			var ok := true
			for j in neigh:
				if _poly_overlap(rc, rects[j]): ok = false; break
			if ok:
				for sp in story_pts:
					if (sp as Vector2).distance_to(c) < h0.length() * float(kk) + 1.0 and Geometry2D.is_point_in_polygon(sp, PackedVector2Array(_prect(c, h0 * float(kk) + Vector2(0.8, 0.8), ry))) and not Geometry2D.is_point_in_polygon(sp, PackedVector2Array(_prect(c, h0 + Vector2(0.8, 0.8), ry))): ok = false; break
			if ok and not road0 and road_hit.call(rc): ok = false
			if ok: k = float(kk); break
		if OS.has_environment("PLAN_DBG") and String(it.get("id", "")) == OS.get_environment("PLAN_DBG"): print("PLANDBG %s k=%.3f road0=%s neigh=%d h0=%s" % [it.id, k, road0, neigh.size(), str(h0)])
		if k <= 1.001: plan_capped += 1; continue
		if k < target - 0.001: plan_capped += 1
		var it2: Dictionary = it.duplicate(true)
		var p: Dictionary = it2.get("params", {})
		if kit == "village/house_compound":
			p.k = snappedf(k, 0.001)
		else:
			var df: Array = PLAN_DEF[kit]
			p.w = snappedf(float(p.get("w", df[0])) * k, 0.01); p.d = snappedf(float(p.get("d", df[1])) * k, 0.01)
			if float(df[2]) > 0.0: p.wall_h = snappedf(float(p.get("wall_h", df[2])) * k, 0.01)
		it2.params = p
		if it2.get("footprint") is Array: it2.footprint = [snappedf(float(it2.footprint[0]) * k, 0.01), snappedf(float(it2.footprint[1]) * k, 0.01)]
		it2.plan_k = snappedf(k, 0.001)
		plan_items.append([c, ry, h0, k])
		rects[i] = _prect(c, h0 * k, ry)
		raw[i] = it2
		plan_scaled += 1
