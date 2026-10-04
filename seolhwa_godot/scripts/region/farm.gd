# 논·밭 필지 엔진 — tools/region/parcels.py가 만든 parcels.bin·farm.png를 읽어 근경 타일마다 진짜 지형을 짓는다(docs/reports/parcels.md).
#   논: 평평한 바닥(땅보다 0.3m 아래) + 논물(하늘 반사) + 논두렁(폭 0.4m·높이 0.26m, 풀) + 다랑이 계단(위 필지의 둑 비탈 또는 막돌 석축)
#       + 벼 줄(필지 긴 축, 상태: 물 댄 모·자라는 벼·익은 벼·그루터기) + 물꼬(둑 끊김, 계단이면 떨어지는 물)
#   밭: 땅을 따르는 이랑·고랑(필지 축) + 이랑 위 작물 + 밭둑 / 제주는 현무암 돌담
#   구획 바깥 변: 둑 윗면에서 바깥 1.6m 땅까지 비탈(테두리)
# 지형 셰이더는 필지 안 땅을 내린다(farm.png 부호 거리) → 필지 메시가 보이는 땅. 걷기 높이(height)도 같은 모양.
# region_world가 부른다: setup(load_region), tile_lod/refocus(타일), update(매 프레임), exclude(배치 자리), commit(배치 뒤), height(ground_at).
extends RefCounted

const PngRaw := preload("res://scripts/region/png_raw.gd")
const TILE := 256
const CHUNK := 64.0
const BH := 0.26            # 논두렁 높이(바닥 위)
const WATER_D := 0.09       # 논물 깊이
const RIM := 1.6            # 구획 바깥 테두리 비탈 폭
const ROW_SP := 0.8         # 벼 줄 간격
const HILL_SP := 0.7        # 벼 포기 간격(줄 방향)
const RIDGE_P := 1.0        # 이랑 간격
const DETAIL_FAR := 150.0   # 이 너머 묶음은 벼·이랑·작물을 그리지 않는다(바닥·둑·물만)
const E_BOUND := 0
const E_SAME := 1
const E_UPPER := 2
const E_LOWER := 3
const STRIDE := 12

var world
var ok := false
var P: PackedFloat32Array     # 필지 n×12 (parcels.py 설명)
var V: PackedFloat32Array     # 꼭짓점 nv×3 (x, z, 이웃)
var I: PackedFloat32Array     # 물꼬 ni×4
var n := 0
var chunks := {}              # Vector2i(ci, cj) → Vector2i(시작, 개수)
var bb: PackedFloat32Array    # n×4
var removed: PackedByteArray  # 배치 자리에 걸려 뺀 필지
var fb: PackedByteArray       # farm.png 바이트(2m)
var _fb_orig: PackedByteArray
var fx0 := 0.0; var fz0 := 0.0; var fcell := 2.0; var fw := 0; var fh := 0
var tex: ImageTexture
var _tex_dirty := false
var ver := 0
var ready := true
var _changed := false         # 배치 제외가 바뀌었다 → commit()에서 다시 짓기
var season := -1              # --farmseason: 0 봄(물 댄 모) 1 여름 2 가을(익은 벼) 3 겨울(그루터기)
var _polys := {}
var _inlets := {}             # Vector2i(8m 칸) → [물꼬 번호]
var root: Node3D
var mat_ground: ShaderMaterial
var mat_water: ShaderMaterial
var mat_spout: ShaderMaterial
var rice_mesh := []           # [상태] → [4포기 메시, 2포기 메시]
var crop_mesh := []           # [작물] → 메시(null = 묵정)
var tiles := {}               # Vector2i → { want, have, job, hold, nodes, ver }
var _orphans := []            # 버린 타일의 진행 중 작업
var _attach := []             # [타일, 결과] 메인 스레드에서 노드로
var stats := { parcels = 0, removed = 0, built = 0, ms = 0.0, tris = 0 }
var max_jobs := 2

# ---------------------------------------------------------------------------
# 불러오기
# ---------------------------------------------------------------------------
func setup(w, dir: String) -> bool:
	world = w
	var bin := dir + "parcels.bin"
	if not FileAccess.file_exists(bin) or not FileAccess.file_exists(dir + "farm.png"): return false
	if OS.get_cmdline_user_args().has("--nofarm"): return false
	var t0 := Time.get_ticks_msec()
	var f := FileAccess.open(bin, FileAccess.READ)
	if f.get_buffer(4).get_string_from_ascii() != "PRCL": return false
	var _v := f.get_32(); n = f.get_32(); var nv := f.get_32(); var ni := f.get_32(); var nc := f.get_32()
	P = f.get_buffer(n * STRIDE * 4).to_float32_array()
	V = f.get_buffer(nv * 12).to_float32_array()
	I = f.get_buffer(ni * 16).to_float32_array()
	var C := f.get_buffer(nc * 16).to_int32_array()
	for k in nc: chunks[Vector2i(C[k * 4], C[k * 4 + 1])] = Vector2i(C[k * 4 + 2], C[k * 4 + 3])
	bb.resize(n * 4)
	for k in n:
		var vs := int(P[k * STRIDE + 9]); var vc := int(P[k * STRIDE + 10])
		var lo := Vector2(INF, INF); var hi := Vector2(-INF, -INF)
		for q in range(vs, vs + vc):
			var x := V[q * 3]; var z := V[q * 3 + 1]
			lo.x = minf(lo.x, x); lo.y = minf(lo.y, z); hi.x = maxf(hi.x, x); hi.y = maxf(hi.y, z)
		bb[k * 4] = lo.x; bb[k * 4 + 1] = lo.y; bb[k * 4 + 2] = hi.x; bb[k * 4 + 3] = hi.y
	removed.resize(n)
	for q in ni:
		var c := Vector2i(floori(I[q * 4] / 8.0), floori(I[q * 4 + 1] / 8.0))
		if not _inlets.has(c): _inlets[c] = []
		_inlets[c].append(q)
	var meta = JSON.parse_string(FileAccess.get_file_as_string(dir + "parcels.json")) if FileAccess.file_exists(dir + "parcels.json") else {}
	var fm: Dictionary = meta.get("farm_png", {}) if meta is Dictionary else {}
	var d := PngRaw.load_gray(ProjectSettings.globalize_path(dir + "farm.png"))
	fb = d.bytes; fw = d.w; fh = d.h
	_fb_orig = fb.duplicate()
	fx0 = float(fm.get("x0", world.hx0)); fz0 = float(fm.get("z0", world.hz0)); fcell = float(fm.get("cell", world.hstep))
	tex = ImageTexture.create_from_image(Image.create_from_data(fw, fh, false, Image.FORMAT_R8, fb))
	for m in [world.mat_near]:
		m.set_shader_parameter("farm_tex", tex)
		m.set_shader_parameter("farm_meta", Vector4(fx0, fz0, 1.0 / fcell, 0.0))
		m.set_shader_parameter("farm_size", Vector2(fw, fh))
		m.set_shader_parameter("farm_on", 1.0)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--farmseason="):
			season = ["spring", "summer", "autumn", "winter"].find(a.trim_prefix("--farmseason="))
	_make_materials()
	_make_models()
	root = Node3D.new(); root.name = "farm"
	world.add_child(root)
	ok = true
	stats.parcels = n
	print("FARM parcels=%d verts=%d inlets=%d chunks=%d season=%d load_ms=%d" % [n, nv, ni, nc, season, Time.get_ticks_msec() - t0])
	return true

func _make_materials() -> void:
	var noise = world.mat_near.get_shader_parameter("noise_tex")
	mat_ground = ShaderMaterial.new(); mat_ground.shader = load("res://shaders/region_farm.gdshader")
	mat_ground.set_shader_parameter("ground_tex", Kit.texture("ground"))
	mat_ground.set_shader_parameter("ramp_tex", Materials.ramp_texture())
	mat_ground.set_shader_parameter("noise_tex", noise)
	mat_water = ShaderMaterial.new(); mat_water.shader = load("res://shaders/region_paddy_water.gdshader")
	mat_water.set_shader_parameter("water_tex", Kit.texture("water"))
	mat_water.set_shader_parameter("noise_tex", noise)
	mat_spout = world.mat_water   # 하천 물 재질(UV.x 흐름) — 다랑이 물꼬에서 떨어지는 물
	world._water_mats.append(mat_ground); world._water_mats.append(mat_water)

const C_ := preload("res://kit/nature/_common.gd")
# 벼 줄 조각(포기 4개·2개, x 방향 HILL_SP 간격, 바닥 y=0) — 상태별
func _make_models() -> void:
	var specs := [
		{ h = 0.32, r = 0.035, n = 3, top = "#a6c95c", bot = "#5b7a30" },   # 물 댄 모(어린 모)
		{ h = 0.66, r = 0.05, n = 5, top = "#9fc257", bot = "#4f6d2c" },    # 자라는 벼
		{ h = 0.78, r = 0.06, n = 7, top = "#e3c766", bot = "#8f8a3c" },    # 익은 벼(누런 이삭)
		{ h = 0.22, r = 0.05, n = 6, top = "#e2cc92", bot = "#9a8458" },    # 그루터기
	]
	for s in specs.size():
		var sp: Dictionary = specs[s]
		var pair := []
		for hills in [4, 2]:
			var r := Kit.Rng.new(31 + s * 7 + hills)
			var b := Kit.Batch.new()
			for i in hills:
				var x: float = (i - (hills - 1) * 0.5) * HILL_SP + (r.next() - 0.5) * 0.08
				var zc := (r.next() - 0.5) * 0.06
				# 포기 = 잎 여러 장(가는 원뿔)을 밖으로 벌려 꽂은 다발
				for q in int(sp.n):
					var hh: float = sp.h * (0.8 + r.next() * 0.35)
					var g := C_.cone(sp.r, hh, 3, true)
					var lean: float = 0.18 + r.next() * 0.3 if s != 3 else 0.08
					var yaw: float = TAU * (q + r.next() * 0.5) / sp.n
					Kit.xf(g, 0, hh * 0.5, 0)
					Kit.xf(g, x, 0.0, zc, lean, yaw, 0.0)
					b.add("flat", Kit.paint(g, C_.c(sp.top), C_.c(sp.bot), 0.06, r), 0.0)
				if s == 2:
					for q in 2:
						# 익은 벼: 고개 숙인 이삭
						var e := C_.cone(0.06, 0.3, 3, true)
						Kit.xf(e, 0, 0.15, 0)
						Kit.xf(e, x, sp.h * 0.85, zc, PI * 0.6, r.next() * TAU, 0.0)
						b.add("flat", Kit.paint(e, C_.c("#f0d57c"), C_.c("#c9a94e"), 0.04, r), 0.0)
			pair.append(b.mesh())
		rice_mesh.append(pair)
	var Crop = load("res://kit/nature/crop.gd")
	for kind in ["bean", "millet", "barley", "cabbage", "pepper"]:
		var info: Dictionary = Crop.build({ kind = kind, len = 2.4, n = 4, ridge = false, seed = kind.hash() % 1000 })
		crop_mesh.append(info.mesh)
		(info.node as Node).free()
	crop_mesh.append(null)

# ---------------------------------------------------------------------------
# 조회
# ---------------------------------------------------------------------------
func sdf_at(x: float, z: float) -> float:
	var fx := clampf((x - fx0) / fcell, 0.0, fw - 1.001); var fz := clampf((z - fz0) / fcell, 0.0, fh - 1.001)
	var i := int(fx); var j := int(fz); var tx := fx - i; var tz := fz - j
	var k := j * fw + i
	var v := lerpf(lerpf(fb[k], fb[k + 1], tx), lerpf(fb[k + fw], fb[k + fw + 1], tx), tz)
	return (v - 128.0) / 16.0

func _poly(k: int) -> PackedVector2Array:
	var p = _polys.get(k)
	if p != null: return p
	var out := poly_of(k)
	_polys[k] = out
	return out

func poly_of(k: int) -> PackedVector2Array:
	var vs := int(P[k * STRIDE + 9]); var vc := int(P[k * STRIDE + 10])
	var out := PackedVector2Array(); out.resize(vc)
	for q in vc: out[q] = Vector2(V[(vs + q) * 3], V[(vs + q) * 3 + 1])
	return out

func find(x: float, z: float) -> int:
	var ci := floori(x / CHUNK); var cj := floori(z / CHUNK)
	var pt := Vector2(x, z)
	for dj in range(-1, 2):
		for di in range(-1, 2):
			var r = chunks.get(Vector2i(ci + di, cj + dj))
			if r == null: continue
			for k in range(r.x, r.x + r.y):
				if removed[k] != 0: continue
				if x < bb[k * 4] or z < bb[k * 4 + 1] or x > bb[k * 4 + 2] or z > bb[k * 4 + 3]: continue
				if Geometry2D.is_point_in_polygon(pt, _poly(k)): return k
	return -1

# 걷는 높이(필지 밖이면 NAN)
func height(x: float, z: float) -> float:
	if not ok or sdf_at(x, z) > 0.6: return NAN
	var k := find(x, z)
	if k < 0: return NAN
	var fl := P[k * STRIDE + 2]
	var vc := int(P[k * STRIDE + 10]); var vs := int(P[k * STRIDE + 9])
	var pt := Vector2(x, z)
	var terr := int(P[k * STRIDE + 3]) == 1 and int(P[k * STRIDE + 8]) & 4 != 0
	if int(P[k * STRIDE + 3]) == 0 or terr:
		var h := fl + (0.08 if terr else WATER_D - 0.03)
		for e in vc:
			var ei := edge_info(k, e)
			if ei.w <= 0.0: continue
			var a := Vector2(V[(vs + e) * 3], V[(vs + e) * 3 + 1]); var b := Vector2(V[(vs + (e + 1) % vc) * 3], V[(vs + (e + 1) % vc) * 3 + 1])
			var d := pt.distance_to(Geometry2D.get_closest_point_to_segment(pt, a, b))
			if d < ei.w: h = maxf(h, ei.y if d <= ei.z else lerpf(ei.y, fl, (d - ei.z) / (ei.w - ei.z)))
		return h
	var base: float = world.data_height(x, z)
	var hb := base + 0.08
	var wall := int(P[k * STRIDE + 8]) & 2 != 0
	for e in vc:
		var a := Vector2(V[(vs + e) * 3], V[(vs + e) * 3 + 1]); var b := Vector2(V[(vs + (e + 1) % vc) * 3], V[(vs + (e + 1) % vc) * 3 + 1])
		var d := pt.distance_to(Geometry2D.get_closest_point_to_segment(pt, a, b))
		if d < 0.35: hb = maxf(hb, base + (0.95 if wall else 0.12))
	return hb

# 변 e(꼭짓점 e → e+1)의 종류: Vector4(종류, 둑 윗면 높이, 윗면 폭, 발치 폭)
func edge_info(k: int, e: int) -> Vector4:
	var vs := int(P[k * STRIDE + 9])
	var nb := int(V[(vs + e) * 3 + 2])
	var fl := P[k * STRIDE + 2]
	var kind := int(P[k * STRIDE + 3])
	var other := nb >= 0 and removed[nb] == 0 and int(P[nb * STRIDE + 3]) == kind
	var terr := kind == 1 and int(P[k * STRIDE + 8]) & 4 != 0
	if kind == 1 and not terr:
		return Vector4(E_SAME, 0.0, 0.2, 0.2) if other else Vector4(E_BOUND, 0.0, 0.35, 0.35)
	var bh := BH if kind == 0 else 0.12
	if not other: return Vector4(E_BOUND, fl + bh, 0.38, 0.72 if kind == 0 else 0.5)
	var nf := P[nb * STRIDE + 2]
	if absf(nf - fl) <= 0.15: return Vector4(E_SAME, maxf(fl, nf) + bh, 0.2, 0.48 if kind == 0 else 0.35)
	if fl > nf: return Vector4(E_UPPER, fl + bh, 0.38, 0.72 if kind == 0 else 0.5)
	return Vector4(E_LOWER, fl, 0.0, 0.0)

func state_of(k: int) -> int:
	if season >= 0:
		if int(P[k * STRIDE + 3]) == 0:
			var h := absf(sin(float(k) * 12.9898))
			match season:
				0: return 0
				1: return 1 if h > 0.15 else 0
				2: return 2 if h > 0.1 else 1
				3: return 3
		return 0
	return int(P[k * STRIDE + 5])

func crop_of(k: int) -> int:
	var c := int(P[k * STRIDE + 6])
	if season == 3: return 5 if c != 2 else 2      # 겨울: 보리만, 나머지 묵정
	if season == 0 and c != 2: return [0, 1, 5][k % 3]
	return c

# ---------------------------------------------------------------------------
# 배치 제외·확정
# ---------------------------------------------------------------------------
func exclude(c: Vector2, ry: float, half: Vector2) -> void:
	if not ok: return
	var ca := cos(ry); var sa := sin(ry)
	var rect := PackedVector2Array()
	for s in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var l: Vector2 = s * half
		# 로컬 → 월드(region_world._to_local의 역)
		rect.append(c + Vector2(l.x * ca + l.y * sa, -l.x * sa + l.y * ca))
	var R := half.length()
	var ci0 := floori((c.x - R) / CHUNK) - 1; var ci1 := floori((c.x + R) / CHUNK) + 1
	var cj0 := floori((c.y - R) / CHUNK) - 1; var cj1 := floori((c.y + R) / CHUNK) + 1
	for cj in range(cj0, cj1 + 1):
		for ci in range(ci0, ci1 + 1):
			var r = chunks.get(Vector2i(ci, cj))
			if r == null: continue
			for k in range(r.x, r.x + r.y):
				if removed[k] != 0: continue
				if c.x + R < bb[k * 4] or c.y + R < bb[k * 4 + 1] or c.x - R > bb[k * 4 + 2] or c.y - R > bb[k * 4 + 3]: continue
				if Geometry2D.intersect_polygons(rect, _poly(k)).is_empty(): continue
				removed[k] = 1
				stats.removed += 1
				_changed = true
				_unsink(k)

# 뺀 필지 자리 땅은 내리지 않는다(부호 거리를 바깥 +1m로)
func _unsink(k: int) -> void:
	var poly := _poly(k)
	var i0 := clampi(floori((bb[k * 4] - fx0) / fcell), 0, fw - 1); var i1 := clampi(ceili((bb[k * 4 + 2] - fx0) / fcell), 0, fw - 1)
	var j0 := clampi(floori((bb[k * 4 + 1] - fz0) / fcell), 0, fh - 1); var j1 := clampi(ceili((bb[k * 4 + 3] - fz0) / fcell), 0, fh - 1)
	for j in range(j0, j1 + 1):
		for i in range(i0, i1 + 1):
			if Geometry2D.is_point_in_polygon(Vector2(fx0 + i * fcell, fz0 + j * fcell), poly): fb[j * fw + i] = 144
	_tex_dirty = true

func reset_excl() -> void:
	if not ok: return
	removed.fill(0)
	fb = _fb_orig.duplicate()
	stats.removed = 0
	_tex_dirty = true
	_changed = true

func commit() -> void:
	if not ok: return
	if _tex_dirty:
		_tex_dirty = false
		tex.update(Image.create_from_data(fw, fh, false, Image.FORMAT_R8, fb))
	if not _changed: return
	_changed = false
	print("FARM commit removed=%d (배치 자리에 걸린 필지)" % stats.removed)
	ver += 1
	for t in tiles.keys(): tiles[t].have = -1

# ---------------------------------------------------------------------------
# 타일 스트리밍
# ---------------------------------------------------------------------------
func tile_lod(t: Vector2i, lod: int) -> void:
	if not ok: return
	if lod == 0:
		if not tiles.has(t): tiles[t] = { want = 1, have = -1, job = -1, hold = null, nodes = [], ver = -1 }
	elif tiles.has(t):
		var st: Dictionary = tiles[t]
		if st.job >= 0: _orphans.append(st.job)
		_free_nodes(st)
		tiles.erase(t)

func refocus(c: Vector2i) -> void:
	if not ok: return
	for t in tiles:
		tiles[t].want = 2 if maxi(absi(t.x - c.x), absi(t.y - c.y)) <= 1 else 1

func _free_nodes(st: Dictionary) -> void:
	for nd in st.nodes:
		if is_instance_valid(nd): nd.queue_free()
	st.nodes = []

func busy_near(c: Vector2i, r: int) -> bool:
	if not ok or not ready: return false
	for t in tiles:
		if maxi(absi(t.x - c.x), absi(t.y - c.y)) > r: continue
		var st: Dictionary = tiles[t]
		if st.have != st.want or st.job >= 0: return true
	for it in _attach:
		var t: Vector2i = it[0]
		if maxi(absi(t.x - c.x), absi(t.y - c.y)) <= r: return true
	return false

func pending() -> int:
	if not ok or not ready: return 0
	var m := 0
	for t in tiles:
		if tiles[t].have != tiles[t].want or tiles[t].job >= 0: m += 1
	return m + _attach.size()

func update(player: Vector3) -> void:
	if not ok: return
	for q in range(_orphans.size() - 1, -1, -1):
		if WorkerThreadPool.is_task_completed(_orphans[q]):
			WorkerThreadPool.wait_for_task_completion(_orphans[q]); _orphans.remove_at(q)
	if not ready: return
	var center: Vector2i = world.tile_of(player.x, player.z)
	var running := 0
	for t in tiles:
		var st: Dictionary = tiles[t]
		if st.job >= 0:
			if WorkerThreadPool.is_task_completed(st.job):
				WorkerThreadPool.wait_for_task_completion(st.job)
				st.job = -1
				var hold: Dictionary = st.hold; st.hold = null
				if hold.ver == ver: _attach.append([t, hold])
			else: running += 1
	# 짓기 시작(가까운 타일부터)
	var cand := []
	for t in tiles:
		var st: Dictionary = tiles[t]
		if st.job < 0 and (st.have != st.want or st.ver != ver) and not _attach_has(t): cand.append(t)
	cand.sort_custom(func(a, b): return maxi(absi(a.x - center.x), absi(a.y - center.y)) < maxi(absi(b.x - center.x), absi(b.y - center.y)))
	for t in cand:
		if running >= (6 if world.loading else max_jobs): break
		var st: Dictionary = tiles[t]
		var hold := { tile = t, detail = st.want, ver = ver }
		st.hold = hold
		st.job = WorkerThreadPool.add_task(_build_tile.bind(t, hold), false, "farm")
		running += 1
	# 메인 스레드: 결과 → 노드(프레임당 묶음 몇 개)
	var budget := 64 if world.loading else 6
	while not _attach.is_empty() and budget > 0:
		var it: Array = _attach[0]
		var t: Vector2i = it[0]; var hold: Dictionary = it[1]
		if not tiles.has(t) or hold.ver != ver:
			_attach.pop_front(); continue
		var st: Dictionary = tiles[t]
		var chs: Array = hold.chunks
		if not hold.has("i"):
			hold.i = 0; hold.new_nodes = []
		while hold.i < chs.size() and budget > 0:
			hold.new_nodes.append_array(_make_nodes(chs[hold.i]))
			hold.i += 1; budget -= 1
		if hold.i >= chs.size():
			_free_nodes(st)
			for nd in hold.new_nodes: root.add_child(nd)
			st.nodes = hold.new_nodes
			st.have = hold.detail; st.ver = hold.ver
			stats.built += 1
			_attach.pop_front()

func _attach_has(t: Vector2i) -> bool:
	for it in _attach:
		if it[0] == t: return true
	return false

func shutdown() -> void:
	for t in tiles:
		if tiles[t].job >= 0: WorkerThreadPool.wait_for_task_completion(tiles[t].job); tiles[t].job = -1
	for j in _orphans: WorkerThreadPool.wait_for_task_completion(j)
	_orphans.clear()

# ---------------------------------------------------------------------------
# 메시 짓기(작업 스레드) — 결과는 배열만, 노드는 메인 스레드에서
# ---------------------------------------------------------------------------
class Mb:
	var v := PackedVector3Array()
	var nn := PackedVector3Array()
	var c := PackedColorArray()
	var idx := PackedInt32Array()
	func quad(a: Vector3, b: Vector3, cc: Vector3, d: Vector3, col: Color, up := Vector3.ZERO) -> void:
		var nrm := (cc - a).cross(b - d)
		if nrm.length_squared() < 1e-12: return
		nrm = nrm.normalized()
		if up != Vector3.ZERO and nrm.dot(up) < 0.0: nrm = -nrm
		var o := v.size()
		v.append(a); v.append(b); v.append(cc); v.append(d)
		for q in 4: nn.append(nrm); c.append(col)
		# Godot 앞면 = 법선 쪽에서 볼 때 시계 방향
		if (b - a).cross(cc - a).dot(nrm) > 0.0:
			idx.append_array([o, o + 2, o + 1, o, o + 3, o + 2])
		else:
			idx.append_array([o, o + 1, o + 2, o, o + 2, o + 3])
	func tri(a: Vector3, b: Vector3, cc: Vector3, col: Color, up := Vector3.UP) -> void:
		var nrm := (b - a).cross(cc - a)
		if nrm.length_squared() < 1e-12: return
		nrm = nrm.normalized()
		var o := v.size()
		v.append(a); v.append(b); v.append(cc)
		if nrm.dot(up) < 0.0: nrm = -nrm
		for q in 3: nn.append(nrm); c.append(col)
		if (b - a).cross(cc - a).dot(nrm) > 0.0: idx.append_array([o, o + 2, o + 1])
		else: idx.append_array([o, o + 1, o + 2])
	# 평면 다각형(삼각분할) — 높이는 hf(x,z)
	func poly(pts: PackedVector2Array, hf: Callable, col: Color) -> void:
		var t := Geometry2D.triangulate_polygon(pts)
		if t.is_empty(): return
		var o := v.size()
		for p in pts:
			v.append(Vector3(p.x, hf.call(p.x, p.y), p.y)); nn.append(Vector3.UP); c.append(col)
		for q in range(0, t.size(), 3):
			var a := v[o + t[q]]; var b := v[o + t[q + 1]]; var cc := v[o + t[q + 2]]
			if (b - a).cross(cc - a).y > 0.0: idx.append_array([o + t[q], o + t[q + 2], o + t[q + 1]])
			else: idx.append_array([o + t[q], o + t[q + 1], o + t[q + 2]])
	func arrays() -> Array:
		var arr := []; arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = v; arr[Mesh.ARRAY_NORMAL] = nn; arr[Mesh.ARRAY_COLOR] = c; arr[Mesh.ARRAY_INDEX] = idx
		return arr

# 색(sRGB) + 무늬(a)
const COL_BUND := Color(0.64, 0.67, 0.43, 0.0)
const COL_BUND2 := Color(0.55, 0.60, 0.37, 0.0)
const COL_RIM := Color(0.60, 0.645, 0.41, 0.0)
const COL_BUND_DRY := Color(0.70, 0.66, 0.42, 0.0)      # 가을: 마른 풀 둑
const COL_BUND_WINTER := Color(0.66, 0.58, 0.42, 0.0)   # 겨울: 누렇게 마른 둑
const COL_BANK := Color(0.60, 0.52, 0.36, 0.0)
const COL_STONE := Color(0.6, 0.57, 0.5, 0.5)
const COL_BASALT := Color(0.2, 0.2, 0.2, 1.0)
const COL_MUD := [Color(0.36, 0.31, 0.22, 0.0), Color(0.34, 0.31, 0.21, 0.0), Color(0.50, 0.43, 0.30, 0.0), Color(0.60, 0.52, 0.37, 0.0)]
const COL_SOIL := Color(0.64, 0.53, 0.36, 0.0)
const COL_SOIL_D := Color(0.50, 0.41, 0.28, 0.0)
const COL_FALLOW := Color(0.62, 0.58, 0.40, 0.0)

func _terrain(x: float, z: float) -> float:
	return world.terrain_at(x, z)

static func _miter(v: Vector2, np: Vector2, nn: Vector2, wp: float, wn: float) -> Vector2:
	var det := np.x * nn.y - np.y * nn.x
	if absf(det) < 0.08: return v + nn * wn if wn > 0.0 else v + np * wp
	var off := Vector2((wp * nn.y - np.y * wn) / det, (np.x * wn - nn.x * wp) / det)
	var lim := maxf(wp, wn) * 3.0 + 0.01
	if off.length() > lim: off = off.normalized() * lim
	return v + off

func _inlets_on(a: Vector2, b: Vector2) -> Array:
	var out := []
	var lo := Vector2(minf(a.x, b.x), minf(a.y, b.y)); var hi := Vector2(maxf(a.x, b.x), maxf(a.y, b.y))
	for cj in range(floori(lo.y / 8.0), floori(hi.y / 8.0) + 1):
		for ci in range(floori(lo.x / 8.0), floori(hi.x / 8.0) + 1):
			for q in _inlets.get(Vector2i(ci, cj), []):
				var p := Vector2(I[q * 4], I[q * 4 + 1])
				var cp := Geometry2D.get_closest_point_to_segment(p, a, b)
				if cp.distance_to(p) < 0.12:
					var s := (cp - a).length() / maxf(a.distance_to(b), 1e-6)
					if s > 0.08 and s < 0.92: out.append([s, q])
	return out

func _build_tile(t: Vector2i, hold: Dictionary) -> void:
	var t0 := Time.get_ticks_usec()
	var out := []
	var nchunk := int(TILE / CHUNK)
	for cj in nchunk:
		for ci in nchunk:
			var key := Vector2i(t.x * nchunk + ci, t.y * nchunk + cj)
			var r = chunks.get(key)
			if r == null: continue
			var ch := { ground = Mb.new(), water = Mb.new(), ridge = Mb.new(), spout = [], rice = {}, crops = {}, rect = Rect2(key.x * CHUNK, key.y * CHUNK, CHUNK, CHUNK), detail = hold.detail }
			for k in range(r.x, r.x + r.y):
				if removed[k] != 0: continue
				if int(P[k * STRIDE + 3]) == 0: _paddy(k, ch)
				else: _field(k, ch)
			# 노드 원점 = 칸 가운데(가시 거리·정밀도) → 좌표를 그만큼 옮긴다
			var o := Vector3((key.x + 0.5) * CHUNK, 0.0, (key.y + 0.5) * CHUNK)
			ch.o = o
			for mb in [ch.ground, ch.water, ch.ridge]:
				var vv: PackedVector3Array = mb.v
				for q in vv.size(): vv[q] -= o
				mb.v = vv
			for d in [ch.rice, ch.crops]:
				for key2 in d:
					var buf: PackedFloat32Array = d[key2]
					for q in range(0, buf.size(), 12):
						buf[q + 3] -= o.x; buf[q + 11] -= o.z
					d[key2] = buf
			out.append(ch)
	hold.chunks = out
	hold.us = Time.get_ticks_usec() - t0

func _paddy(k: int, ch: Dictionary, dry := false) -> void:
	var G: Mb = ch.ground
	var poly := poly_of(k)
	var nv := poly.size()
	var fl := P[k * STRIDE + 2]
	var st := state_of(k) if not dry else 3
	var crop := crop_of(k) if dry else 0
	var stone := int(P[k * STRIDE + 8]) & 1 != 0
	var E := []; var N := []
	for e in nv:
		E.append(edge_info(k, e))
		var d := (poly[(e + 1) % nv] - poly[e]).normalized()
		N.append(Vector2(-d.y, d.x))    # 안쪽
	# 바닥·물
	var fcol: Color = COL_MUD[st] if not dry else (COL_FALLOW if crop == 5 else COL_SOIL_D)
	G.poly(poly, func(_x, _z): return fl, fcol)
	if st <= 1 and not dry:
		var W: Mb = ch.water
		var wc := Color(0.15 if st == 0 else 0.6, 0.55 if st == 0 else 0.25, fmod(absf(sin(float(k) * 78.233)) * 43.7, 1.0))
		W.poly(poly, func(_x, _z): return fl + WATER_D, wc)
	# 둑 안쪽 점(윗면·발치) — 꼭짓점마다 두 이웃 변의 폭으로 맞춘 모서리
	var top := PackedVector2Array(); var foot := PackedVector2Array(); top.resize(nv); foot.resize(nv)
	for i in nv:
		var ep: Vector4 = E[(i - 1 + nv) % nv]; var en: Vector4 = E[i]
		top[i] = _miter(poly[i], N[(i - 1 + nv) % nv], N[i], ep.z, en.z)
		foot[i] = _miter(poly[i], N[(i - 1 + nv) % nv], N[i], ep.w, en.w)
	var outs := []   # 꼭짓점별 바깥 아래 점(테두리·둑 비탈 모서리 메우기): [이전 변 끝, 다음 변 시작]
	outs.resize(nv)
	for i in nv: outs[i] = [null, null]
	for e in nv:
		var ei: Vector4 = E[e]
		var cls := int(ei.x)
		var j := (e + 1) % nv
		var a := poly[e]; var b := poly[j]
		if cls == E_LOWER: continue
		var T := ei.y
		var out_n: Vector2 = -N[e]
		var cb1: Color = COL_BUND if st <= 1 or dry else (COL_BUND_DRY if st == 2 else COL_BUND_WINTER)
		var cb2: Color = COL_BUND2 if st <= 1 or dry else cb1.darkened(0.12)
		# 물꼬(같은 높이 둑 끊김 / 계단이면 위 필지 둑을 끊고 물이 떨어짐)
		var cuts := [[0.0, 1.0]]
		if cls == E_SAME or cls == E_UPPER:
			var L := a.distance_to(b)
			for it in _inlets_on(a, b):
				var s: float = it[0]; var hw := 0.28 / L
				cuts = [[0.0, s - hw], [s + hw, 1.0]]
				if cls == E_UPPER and st <= 1:
					var m := a.lerp(b, s); var q: int = it[1]
					ch.spout.append([m, out_n, T - 0.12, I[q * 4 + 3] + WATER_D])
				break
		for cu in cuts:
			var s0: float = cu[0]; var s1: float = cu[1]
			var oa := a.lerp(b, s0); var ob := a.lerp(b, s1)
			var ta: Vector2 = top[e] if s0 <= 0.0 else oa + N[e] * ei.z
			var tb: Vector2 = top[j] if s1 >= 1.0 else ob + N[e] * ei.z
			var fa: Vector2 = foot[e] if s0 <= 0.0 else oa + N[e] * ei.w
			var fb_: Vector2 = foot[j] if s1 >= 1.0 else ob + N[e] * ei.w
			G.quad(Vector3(oa.x, T, oa.y), Vector3(ob.x, T, ob.y), Vector3(tb.x, T, tb.y), Vector3(ta.x, T, ta.y), cb1, Vector3.UP)
			G.quad(Vector3(ta.x, T, ta.y), Vector3(tb.x, T, tb.y), Vector3(fb_.x, fl, fb_.y), Vector3(fa.x, fl, fa.y), cb2, Vector3.UP)
			# 물꼬 쪽 끝 막기(둑 단면)
			if s0 > 0.0: G.quad(Vector3(oa.x, T, oa.y), Vector3(ta.x, T, ta.y), Vector3(fa.x, fl, fa.y), Vector3(oa.x, fl, oa.y), COL_BANK)
			if s1 < 1.0: G.quad(Vector3(ob.x, T, ob.y), Vector3(tb.x, T, tb.y), Vector3(fb_.x, fl, fb_.y), Vector3(ob.x, fl, ob.y), COL_BANK)
		if cls == E_UPPER:
			# 둑 비탈·석축: 둑 윗면 바깥 끝에서 아래 논 물 밑까지, 흙은 조금 눕히고 돌은 거의 곧게
			var nbk := int(V[(int(P[k * STRIDE + 9]) + e) * 3 + 2])
			var low := P[nbk * STRIDE + 2] - 0.12
			var drop := T - low
			var bat := drop * (0.12 if stone else 0.35)
			# 아래 끝은 변 양쪽으로 조금 넓혀(사다리꼴) 모서리 틈을 덮는다
			var dd := (b - a).normalized() * 0.4
			var ba := a + out_n * bat - dd; var bbv := b + out_n * bat + dd
			G.quad(Vector3(a.x, T, a.y), Vector3(b.x, T, b.y), Vector3(bbv.x, low, bbv.y), Vector3(ba.x, low, ba.y), COL_STONE if stone else COL_BANK, Vector3(out_n.x, 0.0, out_n.y))
			outs[e][1] = Vector3(ba.x, low, ba.y); outs[j][0] = Vector3(bbv.x, low, bbv.y)
		elif cls == E_BOUND and int(V[(int(P[k * STRIDE + 9]) + e) * 3 + 2]) == -2:
			_ditch(ch, a, b, out_n, T, fl)
			var o0 := a + out_n * (DITCH_W + RIM); var o1 := b + out_n * (DITCH_W + RIM)
			outs[e][1] = Vector3(o0.x, _terrain(o0.x, o0.y) - 0.05, o0.y); outs[j][0] = Vector3(o1.x, _terrain(o1.x, o1.y) - 0.05, o1.y)
		elif cls == E_BOUND:
			# 테두리: 둑 윗면 바깥 끝 → 바깥 RIM m 땅(−5cm)으로, 2m 간격
			var L := a.distance_to(b)
			var m := maxi(1, ceili(L / 2.0))
			var prev_i := Vector3(a.x, T, a.y)
			var po := a + out_n * RIM
			var prev_o := Vector3(po.x, _terrain(po.x, po.y) - 0.05, po.y)
			outs[e][1] = prev_o
			for q in range(1, m + 1):
				var p := a.lerp(b, float(q) / m)
				var o := p + out_n * RIM
				var ci := Vector3(p.x, T, p.y); var co := Vector3(o.x, _terrain(o.x, o.y) - 0.05, o.y)
				G.quad(prev_i, ci, co, prev_o, COL_RIM, Vector3.UP)
				prev_i = ci; prev_o = co
			outs[j][0] = prev_o
	# 모서리 메우기(볼록 모서리에서 두 변의 바깥 면 사이 쐐기)
	for i in nv:
		var o0 = outs[i][0]; var o1 = outs[i][1]
		if o0 == null or o1 == null: continue
		var ep: Vector4 = E[(i - 1 + nv) % nv]; var en: Vector4 = E[i]
		var tp := Vector3(poly[i].x, maxf(ep.y, en.y), poly[i].y)
		G.tri(tp, o0, o1, COL_RIM if int(en.x) == E_BOUND else (COL_STONE if stone else COL_BANK), Vector3.UP)
	# 벼(계단밭이면 이랑·작물)
	if ch.detail >= 2 and not dry:
		_rows(k, poly, 0.95, ROW_SP, func(a: Vector2, b: Vector2, ang: float): _rice_row(ch, a, b, ang, fl, st))
	elif ch.detail >= 2 and crop != 5:
		_rows(k, poly, 0.6, RIDGE_P, func(a: Vector2, b: Vector2, ang: float): _ridge(ch, a, b, ang, crop, fl + 0.04))

# 길 따라 도랑(논 구획 바깥 변, parcels.py 이웃 -2): 둑 바깥 → 도랑 바닥(논바닥 −0.3m)·물 → 바깥 둑 → 테두리
const DITCH_W := 0.8
func _ditch(ch: Dictionary, a: Vector2, b: Vector2, on: Vector2, T: float, fl: float) -> void:
	var G: Mb = ch.ground; var W: Mb = ch.water
	var L := a.distance_to(b)
	var m := maxi(1, ceili(L / 2.0))
	var bot := fl - 0.32; var wy := fl - 0.16
	var prev := []
	for q in m + 1:
		var p := a.lerp(b, float(q) / m)
		var ob := p + on * DITCH_W; var orr := p + on * (DITCH_W + RIM)
		var top_o := maxf(_terrain(ob.x, ob.y), wy + 0.12)
		var cur := [Vector3(p.x, T, p.y), (p + on * 0.14), (p + on * (DITCH_W - 0.14)), Vector3(ob.x, top_o, ob.y), Vector3(orr.x, _terrain(orr.x, orr.y) - 0.05, orr.y)]
		cur[1] = Vector3(cur[1].x, bot, cur[1].y); cur[2] = Vector3(cur[2].x, bot, cur[2].y)
		if q > 0:
			G.quad(prev[0], cur[0], cur[1], prev[1], COL_BANK, Vector3(on.x, 1.0, on.y))
			G.quad(prev[1], cur[1], cur[2], prev[2], COL_MUD[0], Vector3.UP)
			G.quad(prev[2], cur[2], cur[3], prev[3], COL_BANK, Vector3(-on.x, 1.0, -on.y))
			G.quad(prev[3], cur[3], cur[4], prev[4], COL_RIM, Vector3.UP)
			var w0: Vector2 = a.lerp(b, float(q - 1) / m); var w1: Vector2 = p
			var wa := w0 + on * 0.06; var wb := w1 + on * 0.06; var wc := w1 + on * (DITCH_W - 0.06); var wd := w0 + on * (DITCH_W - 0.06)
			W.quad(Vector3(wa.x, wy, wa.y), Vector3(wb.x, wy, wb.y), Vector3(wc.x, wy, wc.y), Vector3(wd.x, wy, wd.y), Color(0.3, 0.35, 0.5), Vector3.UP)
		if q == 0 or q == m:
			# 끝 막기(도랑 단면)
			var dirv := (b - a).normalized() * (-1.0 if q == 0 else 1.0)
			G.quad(cur[0], cur[3], Vector3(cur[3].x, bot, cur[3].z), Vector3(cur[0].x, bot, cur[0].z), COL_BANK, Vector3(-dirv.x, 0.0, -dirv.y))
		prev = cur

# 필지 축(P.ang) 방향 줄: inset만큼 안쪽 다각형 안에서 간격 sp로 → fn(시작, 끝, 각)
func _rows(k: int, poly: PackedVector2Array, inset: float, sp: float, fn: Callable) -> void:
	var ins := Geometry2D.offset_polygon(poly, -inset)
	if ins.is_empty(): return
	var ang := P[k * STRIDE + 7]
	var T := Vector2(cos(ang), sin(ang)); var Nn := Vector2(-T.y, T.x)
	var c := Vector2(P[k * STRIDE], P[k * STRIDE + 1])
	var vmin := INF; var vmax := -INF; var tmin := INF; var tmax := -INF
	for p in poly:
		var d := p - c
		vmin = minf(vmin, d.dot(Nn)); vmax = maxf(vmax, d.dot(Nn)); tmin = minf(tmin, d.dot(T)); tmax = maxf(tmax, d.dot(T))
	var v := vmin + fmod(absf(vmin), sp) + sp * 0.5
	while v < vmax:
		var a := c + T * (tmin - 1.0) + Nn * v; var b := c + T * (tmax + 1.0) + Nn * v
		for poly2 in ins:
			for seg in Geometry2D.intersect_polyline_with_polygon(PackedVector2Array([a, b]), poly2):
				if seg.size() >= 2: fn.call(seg[0], seg[seg.size() - 1], ang)
		v += sp

func _xf_buf(buf: PackedFloat32Array, o: Vector3, ang: float, s: float) -> void:
	# 로컬 x → (cos ang, 0, sin ang): y축 −ang 회전
	var ca := cos(-ang) * s; var sa := sin(-ang) * s
	# Basis(UP, θ): x열 (cos, 0, −sin), z열 (sin, 0, cos) — 행 우선 3×4로
	buf.append_array([ca, 0.0, sa, o.x, 0.0, s, 0.0, o.y, -sa, 0.0, ca, o.z])

func _rice_row(ch: Dictionary, a: Vector2, b: Vector2, ang: float, fl: float, st: int) -> void:
	var L := a.distance_to(b)
	var d := (b - a) / maxf(L, 1e-6)
	var seg4 := HILL_SP * 4.0
	var s := 0.0
	var h := (a.x * 0.37 + a.y * 0.91)
	while s + HILL_SP * 2.0 <= L:
		var use4 := s + seg4 <= L
		var len := seg4 if use4 else HILL_SP * 2.0
		var m := a + d * (s + len * 0.5)
		var key := Vector2i(st, 0 if use4 else 1)
		if not ch.rice.has(key): ch.rice[key] = PackedFloat32Array()
		h = fmod(h * 7.13 + 0.61, 1.0)
		_xf_buf(ch.rice[key], Vector3(m.x, fl - 0.02, m.y), ang + (h - 0.5) * 0.06, 0.92 + h * 0.16)
		s += len

func _field(k: int, ch: Dictionary) -> void:
	if int(P[k * STRIDE + 8]) & 4 != 0:
		_paddy(k, ch, true); return
	var G: Mb = ch.ground
	var poly := poly_of(k)
	var nv := poly.size()
	var wall := int(P[k * STRIDE + 8]) & 2 != 0
	var crop := crop_of(k)
	var E := []; var N := []
	for e in nv:
		E.append(edge_info(k, e))
		var d := (poly[(e + 1) % nv] - poly[e]).normalized()
		N.append(Vector2(-d.y, d.x))
	var hf := func(x, z): return world.data_height(x, z) - 0.04
	# 바닥(땅 따라 4m 칸으로 잘라 삼각분할)
	var lo := Vector2(bb[k * 4], bb[k * 4 + 1]); var hi := Vector2(bb[k * 4 + 2], bb[k * 4 + 3])
	var col := COL_FALLOW if crop == 5 else COL_SOIL_D
	var gx := floorf(lo.x / 4.0) * 4.0
	while gx < hi.x:
		var gz := floorf(lo.y / 4.0) * 4.0
		while gz < hi.y:
			var sq := PackedVector2Array([Vector2(gx, gz), Vector2(gx + 4, gz), Vector2(gx + 4, gz + 4), Vector2(gx, gz + 4)])
			for piece in Geometry2D.intersect_polygons(sq, poly):
				G.poly(piece, hf, col)
			gz += 4.0
		gx += 4.0
	# 밭둑(풀) 또는 돌담
	var inner := PackedVector2Array(); inner.resize(nv)
	for i in nv:
		var ep: Vector4 = E[(i - 1 + nv) % nv]; var en: Vector4 = E[i]
		inner[i] = _miter(poly[i], N[(i - 1 + nv) % nv], N[i], ep.z, en.z)
	for e in nv:
		var ei: Vector4 = E[e]
		var j := (e + 1) % nv
		var a := poly[e]; var b := poly[j]
		var L := a.distance_to(b)
		var m := maxi(1, ceili(L / 3.0))
		var out_n: Vector2 = -N[e]
		var bound := int(ei.x) == E_BOUND
		if wall and (bound or k < int(V[(int(P[k * STRIDE + 9]) + e) * 3 + 2])):
			_wall(G, a, b, N[e], bound, k * 31 + e)
		for q in m:
			var s0 := float(q) / m; var s1 := float(q + 1) / m
			var p0 := a.lerp(b, s0); var p1 := a.lerp(b, s1)
			var i0 := inner[e].lerp(inner[j], s0); var i1 := inner[e].lerp(inner[j], s1)
			var h0: float = world.data_height(p0.x, p0.y); var h1: float = world.data_height(p1.x, p1.y)
			var g0: float = world.data_height(i0.x, i0.y); var g1: float = world.data_height(i1.x, i1.y)
			var bh := 0.12 if not bound else 0.14
			G.quad(Vector3(p0.x, h0 + bh, p0.y), Vector3(p1.x, h1 + bh, p1.y), Vector3(i1.x, g1 + bh * 0.8, i1.y), Vector3(i0.x, g0 + bh * 0.8, i0.y), COL_BUND, Vector3.UP)
			G.quad(Vector3(i0.x, g0 + bh * 0.8, i0.y), Vector3(i1.x, g1 + bh * 0.8, i1.y), Vector3(i1.x, g1 - 0.05, i1.y), Vector3(i0.x, g0 - 0.05, i0.y), COL_BUND2, Vector3.UP)
			if bound:
				var o0 := p0 + out_n * RIM; var o1 := p1 + out_n * RIM
				G.quad(Vector3(p0.x, h0 + bh, p0.y), Vector3(p1.x, h1 + bh, p1.y), Vector3(o1.x, _terrain(o1.x, o1.y) - 0.05, o1.y), Vector3(o0.x, _terrain(o0.x, o0.y) - 0.05, o0.y), COL_RIM, Vector3.UP)
	# 테두리 볼록 모서리 메우기
	for i in nv:
		var ep: Vector4 = E[(i - 1 + nv) % nv]; var en: Vector4 = E[i]
		if int(ep.x) != E_BOUND or int(en.x) != E_BOUND: continue
		var o0: Vector2 = poly[i] - N[(i - 1 + nv) % nv] * RIM; var o1: Vector2 = poly[i] - N[i] * RIM
		var hp: float = world.data_height(poly[i].x, poly[i].y) + 0.14
		G.tri(Vector3(poly[i].x, hp, poly[i].y), Vector3(o0.x, _terrain(o0.x, o0.y) - 0.05, o0.y), Vector3(o1.x, _terrain(o1.x, o1.y) - 0.05, o1.y), COL_RIM)
	# 이랑·작물
	if ch.detail >= 2 and crop != 5:
		_rows(k, poly, 0.55, RIDGE_P, func(a: Vector2, b: Vector2, ang: float): _ridge(ch, a, b, ang, crop))

const RIDGE_H := 0.17
func _ridge(ch: Dictionary, a: Vector2, b: Vector2, ang: float, crop: int, flat := NAN) -> void:
	var R: Mb = ch.ridge
	var L := a.distance_to(b)
	if L < 1.0: return
	var d := (b - a) / L
	var nrm := Vector2(-d.y, d.x)
	var m := maxi(1, ceili(L / 3.0))
	var hw := RIDGE_P * 0.5; var tw := RIDGE_P * 0.17
	var prev := []
	for q in m + 1:
		var p := a + d * (L * q / m)
		var base: float = world.data_height(p.x, p.y) if is_nan(flat) else flat
		var pts := [p - nrm * hw, p - nrm * tw, p + nrm * tw, p + nrm * hw]
		var ys := [base - 0.05, base + RIDGE_H, base + RIDGE_H, base - 0.05]
		var cur := []
		for w in 4: cur.append(Vector3(pts[w].x, ys[w], pts[w].y))
		if q == 0 or q == m:
			# 끝 막기
			R.quad(cur[0], cur[1], cur[2], cur[3], COL_SOIL_D, Vector3(d.x, 0, d.y) * (1.0 if q == m else -1.0))
		if q > 0:
			R.quad(prev[0], prev[1], cur[1], cur[0], COL_SOIL_D, Vector3.UP)
			R.quad(prev[1], prev[2], cur[2], cur[1], COL_SOIL, Vector3.UP)
			R.quad(prev[2], prev[3], cur[3], cur[2], COL_SOIL_D, Vector3.UP)
		prev = cur
	# 작물: 이랑 위 2.4m마다
	var s := 0.6
	while s + 1.2 <= L:
		var mp := a + d * (s + 1.2)
		if not ch.crops.has(crop): ch.crops[crop] = PackedFloat32Array()
		_xf_buf(ch.crops[crop], Vector3(mp.x, (world.data_height(mp.x, mp.y) if is_nan(flat) else flat) + RIDGE_H - 0.03, mp.y), ang, 1.0)
		s += 2.4

# 제주 밭담: 현무암 막돌, 높이 0.8~1.1m 들쭉날쭉, 변 가운데(바깥 변은 안쪽으로 0.35m)
func _wall(G: Mb, a: Vector2, b: Vector2, nin: Vector2, bound: bool, seed: int) -> void:
	var c0 := a + nin * (0.35 if bound else 0.0); var c1 := b + nin * (0.35 if bound else 0.0)
	var L := c0.distance_to(c1)
	var m := maxi(1, ceili(L / 0.9))
	var hw := 0.3; var tw := 0.22
	var h := float(seed % 97) / 97.0
	var pv := []
	for q in m + 1:
		var p := c0.lerp(c1, float(q) / m)
		var g: float = world.data_height(p.x, p.y)
		h = fmod(h * 9.17 + 0.37, 1.0)
		var top := g + 0.8 + h * 0.3
		var cur := [Vector3(p.x - nin.x * hw, g - 0.1, p.y - nin.y * hw), Vector3(p.x - nin.x * tw, top, p.y - nin.y * tw),
			Vector3(p.x + nin.x * tw, top, p.y + nin.y * tw), Vector3(p.x + nin.x * hw, g - 0.1, p.y + nin.y * hw)]
		if q > 0:
			G.quad(pv[0], pv[1], cur[1], cur[0], COL_BASALT, Vector3(-nin.x, 0, -nin.y))
			G.quad(pv[1], pv[2], cur[2], cur[1], COL_BASALT, Vector3.UP)
			G.quad(pv[2], pv[3], cur[3], cur[2], COL_BASALT, Vector3(nin.x, 0, nin.y))
		pv = cur

# ---------------------------------------------------------------------------
# 노드(메인 스레드)
# ---------------------------------------------------------------------------
func _mesh_node(mb: Mb, mat: Material, nm: String, cast: bool) -> MeshInstance3D:
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mb.arrays())
	am.surface_set_material(0, mat)
	var mi := MeshInstance3D.new()
	mi.mesh = am; mi.name = nm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	stats.tris += mb.idx.size() / 3
	return mi

func _mm_node(mesh: Mesh, buf: PackedFloat32Array, nm: String) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = buf.size() / 12
	mm.buffer = buf
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm; mi.name = nm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = DETAIL_FAR
	mi.visibility_range_end_margin = 10.0
	return mi

func _make_nodes(ch: Dictionary) -> Array:
	var out := _make_nodes0(ch)
	for nd in out:
		if nd.name != "farm_spout": nd.position = ch.o
	return out

func _make_nodes0(ch: Dictionary) -> Array:
	var out := []
	if (ch.ground as Mb).idx.size() > 0: out.append(_mesh_node(ch.ground, mat_ground, "farm_ground", true))
	if (ch.water as Mb).idx.size() > 0: out.append(_mesh_node(ch.water, mat_water, "farm_water", false))
	if (ch.ridge as Mb).idx.size() > 0:
		var r := _mesh_node(ch.ridge, mat_ground, "farm_ridge", true)
		r.visibility_range_end = DETAIL_FAR; r.visibility_range_end_margin = 10.0
		out.append(r)
	for key in ch.rice:
		out.append(_mm_node(rice_mesh[key.x][key.y], ch.rice[key], "farm_rice"))
	for c in ch.crops:
		if crop_mesh[c] != null: out.append(_mm_node(crop_mesh[c], ch.crops[c], "farm_crop"))
	if not ch.spout.is_empty():
		var sp := Mb.new()
		var uv := PackedVector2Array()
		for s in ch.spout:
			var m: Vector2 = s[0]; var on: Vector2 = s[1]; var y0: float = s[2]; var y1: float = s[3]
			var tg := Vector2(-on.y, on.x) * 0.16
			var a := m + tg + on * 0.03; var b := m - tg + on * 0.03
			var bo := m + on * 0.25
			sp.quad(Vector3(a.x, y0, a.y), Vector3(b.x, y0, b.y), Vector3(bo.x - tg.x, y1, bo.y - tg.y), Vector3(bo.x + tg.x, y1, bo.y + tg.y), Color(1.0, 0.0, 0.01), Vector3(on.x, 0.3, on.y))
			uv.append_array([Vector2(0, 0), Vector2(0, 1), Vector2(0.4, 1), Vector2(0.4, 0)])
		var arr := sp.arrays(); arr[Mesh.ARRAY_TEX_UV] = uv
		var am := ArrayMesh.new(); am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr); am.surface_set_material(0, mat_spout)
		var mi := MeshInstance3D.new(); mi.mesh = am; mi.name = "farm_spout"
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visibility_range_end = DETAIL_FAR
		out.append(mi)
	return out
