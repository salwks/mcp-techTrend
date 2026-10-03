# LOADER_READY
# 배치 불러오기(계약서 §8) — region_data/JL_NAMWON_UNBONG/placement_*.json(과 --placedir 폴더)을 모두 읽어
# 키트를 build()하고(같은 kit+params는 한 번만, 작업 스레드 여러 개로) RegionWorld.add_static으로 놓는다.
# 정적 물체는 RegionWorld가 타일 스트리밍에 맞춰 붙였다 뗀다.
#
#   항목: { id, kit:"village/house_compound", params:{seed…}, x, z, ry(라디안), y(null=지형), flatten, clear_veg(기본 true),
#           footprint:[w,d](선택 — 없으면 build() 결과), group }
#   - 배치형(읍성·관아·실상사·향교): 키트에 static layout(params)가 있으면 그걸로, 없으면 build() 결과 pieces로 조각마다 놓는다.
#     조각 { kit, params, x, z, ry, y?(선택, 부모 높이 기준) }는 부모 기준 로컬 좌표.
#   - flatten: footprint(+2m 여유, 회전 반영) 안을 평평하게, 가장자리 5m에 걸쳐 원래 땅으로(높이맵 텍스처·CPU height_at 둘 다).
#   - clear_veg: footprint(+1m, flatten이면 고른 터 전체) 안 식생을 비운다(식생 흩뿌리기 결과에서 거름 / scatter가 exclude 인자를 받으면 넘김).
#   - walk(걷기 면): build() 결과의 walk 배열(§8 형식) — 없으면 돌다리·섶다리·징검다리는 params로 만든다.
#     다리 y가 null이면 둑 높이(다리 양 끝 지형 평균), 징검다리·나루배·빨래터는 가까운 하천 수면.
extends RefCounted

const KitCache := preload("res://scripts/region/kit_cache.gd")

const FLAT_MARGIN := 2.0
const FLAT_EDGE := 5.0
const VEG_MARGIN := 1.0
const TAG := "placement"
const WATER_KITS := ["village/jingeom", "village/narutbae", "village/ppallaeteo"]
const BOAT_KITS := ["village/narutbae"]
const BRIDGE_KITS := ["village/stone_bridge", "village/seop_bridge"]
const YARD_COMPOSITES := ["house_compound", "gwana", "hyanggyo", "silsangsa", "jumak"]

var world   # RegionWorld
var dirs: Array = []
var parallel := true
var stats := {}
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
	world.remove_tagged(TAG)
	world.reset_edits()
	load_all()

func load_all() -> void:
	var t0 := Time.get_ticks_msec()
	_mtimes = {}
	var raw := []
	for f in files():
		_mtimes[f] = FileAccess.get_modified_time(f)
		var d = JSON.parse_string(FileAccess.get_file_as_string(f))
		if not (d is Dictionary) or not d.has("items"):
			push_warning("배치 파일 형식 오류: " + f); continue
		for it in d.items:
			if it is Dictionary and it.has("kit"): raw.append(it)
	stats = { files = _mtimes.size(), items = raw.size(), placed = 0, builds = 0, builds_now = 0, flatten = 0, walks = 0, missing = 0, yards = 0 }
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
			r.flat_y = world.flatten_rect(c, r.ry, fp * 0.5 + Vector2(FLAT_MARGIN, FLAT_MARGIN), yt, FLAT_EDGE)
			stats.flatten += 1
		if r.clear_veg:
			var m: float = (FLAT_MARGIN + world.lcell) if r.flatten and not r.get("is_piece", false) else VEG_MARGIN
			world.add_veg_exclusion(c, r.ry, fp * 0.5 + Vector2(m, m))
		if composite.has(r):
			# 집 묶음·관아·향교·절은 담 안 마당 전체가 흙
			for kk in YARD_COMPOSITES:
				if r.kit.ends_with(kk):
					world.paint_yard(c, r.ry, fp * 0.5 - Vector2(1.5, 1.5)); stats.yards += 1; break
		elif _yard_kit(r):
			world.paint_yard(c, r.ry, fp * 0.5)
			stats.yards += 1
	# 못 파기: build 결과 water {y, outline}(로컬) — 터 고르기 뒤 높이 기준
	for r in place:
		var info = _cache.get(_key(r.kit, r.params))
		if info is Dictionary and info.get("water") is Dictionary and info.water.has("outline"):
			var y0 := _y_for(r, {})
			var ol = info.water.outline
			var pv: PackedVector2Array = ol if ol is PackedVector2Array else PackedVector2Array(ol)
			world.carve_water(Transform3D(Basis(Vector3.UP, r.ry), Vector3(r.x, y0, r.z)), pv, float(info.water.get("y", 0.0)))
			stats.ponds = stats.get("ponds", 0) + 1
	world.commit_terrain()
	# 4) 높이·변환·걷기 면(다리는 params로 — 짓기 전에도 걸을 수 있게)을 정하고 타일별 대기열에 넣는다
	for r in place:
		var y := _y_for(r, {})
		r.xf = Transform3D(Basis(Vector3.UP, r.ry), Vector3(r.x, y, r.z))
		r.walk_done = false
		var ws := _walks_for(r, _cache.get(_key(r.kit, r.params), {}))
		if not ws.is_empty():
			for w in ws: world.add_walk(r.xf, w); stats.walks += 1
			r.walk_done = true
		var t: Vector2i = world.tile_of(r.x, r.z)
		if not _pending.has(t): _pending[t] = []
		_pending[t].append(r)
	world.tile_listener = request_tile
	for t in world.tiles: request_tile(t)
	stats.ms = Time.get_ticks_msec() - t0
	print("PLACEMENT files=%d items=%d pieces=%d built_now=%d flatten=%d yards=%d walks=%d missing=%d ms=%d (나머지는 타일이 가까워질 때 백그라운드로 짓는다)" % [stats.files, stats.items, place.size(), stats.builds_now, stats.flatten, stats.yards, stats.walks, stats.missing, stats.ms])

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
		if not WorkerThreadPool.is_group_task_completed(j.id): continue
		WorkerThreadPool.wait_for_group_task_completion(j.id)
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
				var h: Dictionary = holders[n]
				h.info = KitCache.build(h.kit, h.s, h.params)
			var id := WorkerThreadPool.add_group_task(job, holders.size(), mini(holders.size(), 4), true, "kit build")
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
	world.add_static(node, r.xf, info, TAG)
	if not r.walk_done:
		for w in _walks_for(r, info): world.add_walk(r.xf, w); stats.walks += 1
	if info.get("water") is Dictionary and not _has(_script(r.kit), "outline"):
		push_warning("배치: %s는 water가 있지만 늦게 지어져 땅을 파지 못했다(키트에 static outline()을 두거나 footprint 없이 두면 시작 때 짓는다)" % r.kit)
	stats.placed += 1

# 진행 중 짓기를 기다리고 대기열을 비운다(다시 읽기·끝내기 전)
func stop() -> void:
	for t in _jobs: WorkerThreadPool.wait_for_group_task_completion(_jobs[t].id)
	_jobs.clear(); _inflight.clear(); _requested.clear(); _pending.clear(); _place_q.clear()
	for k in _cache:
		var info = _cache[k]
		if info is Dictionary and info.get("node") != null and not _used.has(k) and is_instance_valid(info.node) and not info.node.is_inside_tree():
			info.node.free()
	_cache.clear(); _used.clear(); _packed.clear()

# 마당 흙을 칠할 키트: 건물·소품(담장·성벽·다리·나무 제외)
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
	for d in ["village", "landmark", "nature"]:
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
		y = (float(it.y) if it.get("y") != null else null), flatten = bool(it.get("flatten", false)),
		clear_veg = bool(it.get("clear_veg", true)), fp = world.to_v2(it.get("footprint", Vector2.ZERO)), flat_y = NAN }

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
		flatten = false, clear_veg = false, fp = Vector2.ZERO, flat_y = NAN, is_piece = true, parent = parent, py = p.get("y"),
		lx = float(p.get("x", 0.0)), lz = float(p.get("z", 0.0)) }
	return r

func _y_for(r: Dictionary, info: Dictionary) -> float:
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
		var gid := WorkerThreadPool.add_group_task(job, keys.size(), -1, true, "kit build")
		WorkerThreadPool.wait_for_group_task_completion(gid)
	else:
		for i in keys.size(): job.call(i)
	for i in keys.size():
		cache[keys[i]] = holders[i].info if holders[i].info is Dictionary else {}
		stats.builds += 1
