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

const FLAT_MARGIN := 2.0
const FLAT_EDGE := 5.0
const VEG_MARGIN := 1.0
const TAG := "placement"
const WATER_KITS := ["village/jingeom", "village/narutbae", "village/ppallaeteo"]
const BRIDGE_KITS := ["village/stone_bridge", "village/seop_bridge"]

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
	for m in s.get_script_method_list():
		if m.name == fn: return true
	return false

static func _key(kit: String, params: Dictionary) -> String:
	return kit + "|" + JSON.stringify(params, "", true)

# 모두 다시: 이전 배치·터 고르기·식생 비우기·걷기 면을 지우고 처음부터
func reload() -> void:
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
	stats = { files = _mtimes.size(), items = raw.size(), placed = 0, builds = 0, flatten = 0, walks = 0, missing = 0 }
	if raw.is_empty():
		world.commit_terrain()
		return
	# 1) 배치형 풀기(layout이 있으면 짓지 않고 조각 목록만)
	var place := []    # { kit, params, x, z, ry, y, flatten, clear_veg, fp, id, parent_y_rel }
	var composite := []  # 부모(배치형): 터 고르기·식생 비우기만
	for it in raw:
		var kit: String = it.kit
		var s := _script(kit)
		if s == null: stats.missing += 1; continue
		var rec := _rec(it)
		if _has(s, "layout"):
			var ps: Array = s.layout(rec.params)
			_fp_from_pieces(rec, ps)
			composite.append(rec)
			for p in ps: place.append(_piece(rec, p))
		else:
			place.append(rec)
	# 2) 짓기(같은 kit+params는 한 번) — 결과에 pieces가 있으면 그것도 풀어 한 번 더
	var cache := {}
	var round := 0
	while round < 3:
		round += 1
		var todo := {}
		for r in place:
			var k := _key(r.kit, r.params)
			if not cache.has(k) and _script(r.kit) != null: todo[k] = r
		if todo.is_empty(): break
		_build_all(todo, cache)
		var next := []
		var expanded := false
		for r in place:
			var info = cache.get(_key(r.kit, r.params))
			if info is Dictionary and info.has("pieces") and not (info.pieces as Array).is_empty() and not r.get("is_piece", false):
				if r.fp == Vector2.ZERO: _fp_from_pieces(r, info.pieces)
				composite.append(r)
				for p in info.pieces: next.append(_piece(r, p))
				expanded = true
			else:
				next.append(r)
		place = next
		if not expanded: break
	# 3) 터 고르기(배치형 부모 먼저, 그다음 낱개) · 식생 비우기
	for r in composite + place:
		var info = cache.get(_key(r.kit, r.params), {})
		var fp: Vector2 = r.fp if r.fp != Vector2.ZERO else world.to_v2(info.get("footprint", Vector2.ZERO) if info is Dictionary else Vector2.ZERO)
		r.fp = fp
		if fp == Vector2.ZERO: continue
		var c := Vector2(r.x, r.z)
		if r.flatten and not r.get("is_piece", false):
			var yt: float = r.y if r.y != null else NAN
			r.flat_y = world.flatten_rect(c, r.ry, fp * 0.5 + Vector2(FLAT_MARGIN, FLAT_MARGIN), yt, FLAT_EDGE)
			stats.flatten += 1
		if r.clear_veg:
			# 고른 터(마당으로 칠해지는 곳: +2m 여유 + 토지이용 한 칸)까지는 식생도 비운다
			var m: float = (FLAT_MARGIN + world.lcell) if r.flatten and not r.get("is_piece", false) else VEG_MARGIN
			world.add_veg_exclusion(c, r.ry, fp * 0.5 + Vector2(m, m))
	world.commit_terrain()
	# 4) 놓기
	var used := {}
	for r in place:
		var k := _key(r.kit, r.params)
		var info = cache.get(k)
		if not (info is Dictionary) or info.get("node") == null: continue
		var node: Node3D = info.node.duplicate() if used.has(k) else info.node
		used[k] = true
		var y := _y_for(r, info)
		var xf := Transform3D(Basis(Vector3.UP, r.ry), Vector3(r.x, y, r.z))
		node.name = String(r.id) if r.id != "" else node.name
		world.add_static(node, xf, info, TAG)
		for w in _walks_for(r, info): world.add_walk(xf, w); stats.walks += 1
		stats.placed += 1
	# 쓰이지 않은 원본 노드(배치형 build 결과 등)
	for k in cache:
		var info = cache[k]
		if info is Dictionary and info.get("node") != null and not used.has(k) and not info.node.is_inside_tree():
			info.node.free()
	stats.ms = Time.get_ticks_msec() - t0
	print("PLACEMENT files=%d items=%d placed=%d builds=%d flatten=%d walks=%d missing=%d ms=%d" % [stats.files, stats.items, stats.placed, stats.builds, stats.flatten, stats.walks, stats.missing, stats.ms])

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
		flatten = false, clear_veg = false, fp = Vector2.ZERO, flat_y = NAN, is_piece = true, parent = parent, py = p.get("y") }
	return r

func _y_for(r: Dictionary, info: Dictionary) -> float:
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
		holders.append({ s = _script(todo[k].kit), params = todo[k].params, info = null })
	var job := func(i: int) -> void:
		var h: Dictionary = holders[i]
		h.info = h.s.build(h.params)
	if parallel and keys.size() > 1:
		var gid := WorkerThreadPool.add_group_task(job, keys.size(), -1, true, "kit build")
		WorkerThreadPool.wait_for_group_task_completion(gid)
	else:
		for i in keys.size(): job.call(i)
	for i in keys.size():
		cache[keys[i]] = holders[i].info if holders[i].info is Dictionary else {}
		stats.builds += 1
