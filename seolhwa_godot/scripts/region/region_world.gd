# 권역 월드(지형 엔진) — 계약서 docs/REGION_CONTRACTS.md §6.
# 기존 World(scripts/world.gd)를 이어받아 같은 필드·함수(height_at, blocked, move_circle, interior_at, camera_zones,
# interiors, occluders, lights, npcs, spawn, update)를 그대로 쓰게 하고, landuse_at · focus · add_static을 더한다.
#
# 지형 표현
#   - 데이터: region.json + height.png(16비트) + landuse.png(8비트 인덱스). 경로는 data_dir 하나로 바꾼다.
#   - 타일 256m. 플레이어 타일 기준 체비셰프 반경 2 = 근경(1m 격자 + 아주 약한 잡음), 3~4 = 중경(4m 격자),
#     그 너머 = 원경(권역 전체 32m 격자, 먹빛 능선 셰이더, 근·중경 사각형은 구멍).
#   - 메시는 "평평한 정수 격자" 하나를 모든 타일이 같이 쓰고, 정점 셰이더가 높이맵 텍스처로 세운다
#     (shaders/region_common.gdshaderinc). 같은 식을 CPU(height_at)도 계산하므로 발이 땅에 붙고,
#     이웃 타일은 같은 월드 좌표의 같은 높이를 쓰므로 이음매가 없다. 근·중경 경계 틈은 치마(skirt)로 가린다.
#     → 타일을 붙이는 데 CPU 메시 굽기가 필요 없어 로딩 중 프레임 정지가 없다.
#   - 백그라운드(WorkerThreadPool): 시작 때 하천 물 메시·원경, 걷는 동안 타일별 식생(kit/nature/scatter.gd).
extends "res://scripts/world.gd"

const PngRaw := preload("res://scripts/region/png_raw.gd")

const TILE := 256
const NEAR_R := 2        # 근경 반경(타일)
const MID_R := 4         # 중경 반경(타일)
const KEEP := 1          # 근경에서 벗어나도 이만큼은 유지(경계에서 왔다 갔다 할 때 다시 짓지 않게)
const MID_STEP := 4
const CHUNK := 64        # 근경 메시 조각(화면 밖 조각은 그리지 않게)
const FAR_STEP := 32
const SKIRT := 6.0
const GRID := 32.0       # 충돌체 격자 칸(m)
const MAX_JOBS := 2
const SCATTER_PATH := "res://kit/nature/scatter.gd"
const DEFAULT_DIRS := ["res://region_data/JL_NAMWON_UNBONG/", "res://shots/region/tmp_data/"]
# shaders/region_common.gdshaderinc의 LU_DETAIL과 같아야 한다
const LU_DETAIL := [1.0, 0.8, 0.12, 0.45, 0.35, 0.0, 0.35, 1.5, 0.3, 1.0]
const M32 := 0xffffffff

var data_dir := ""
var region := {}
var block_water := true
var markers := true
var use_scatter := true
var split_scatter := true   # 식생 묶음을 SUB m로 다시 나누기(시험용으로 끌 수 있음 --nosplit)

# 높이(부모의 hx0, hz0, hstep, hnx, hnz를 그대로 쓴다)
var hbytes: PackedByteArray
var hbpp := 2
var hy0 := 0.0
var hscale := 0.0
# 토지이용
var lbytes: PackedByteArray
var lx0 := 0.0; var lz0 := 0.0; var lcell := 2.0; var lw := 0; var lh := 0

var tile_min := Vector2i.ZERO
var tile_max := Vector2i.ZERO
var tiles := {}             # Vector2i → { lod, mi, scatter_nodes, scatter_lod, scatter_job }
var mat_near: ShaderMaterial
var mat_mid: ShaderMaterial
var mat_far: ShaderMaterial
var mat_water: ShaderMaterial
var mesh_near: ArrayMesh
var mesh_mid: ArrayMesh
var far_node: MeshInstance3D
var terrain_root: Node3D
var water_root: Node3D
var statics_root: Node3D
var scatter_root: Node3D
var height_tex: ImageTexture
var landuse_tex: ImageTexture
var lights_version := 0
var stats := { near = 0, mid = 0, jobs = 0, scatter_done = 0, statics = 0 }

var _center := Vector2i(1 << 20, 1 << 20)
var _pool := []
var _statics := {}          # Vector2i → [ entry ]  entry = { node, colliders, lights, occ, interior, attached, big }
var _static_grid := {}      # Vector2i(칸) → [collider]
var _scatter_grid := {}     # 타일 → { 칸 → [collider] }
var _scatter_script: Script = null
var _queue := []            # 식생 대기 타일
var _attach_q := []         # [타일, 묶음, 세대] 붙이기 대기
var _gen := 0
const ATTACH_PER_FRAME := 24
var _crossings := []
var _river_grid := {}
var lod0_dist := 32.0       # 이 거리(플레이어→묶음 사각형) 안의 식생 묶음은 lod 0
var scatter_far := 220.0    # 이 너머 식생은 안개 속이라 그리지 않는다(region_main이 안개 농도로 정한다)
var _lod_dirty := false
var _lod_frame := 0
var _tall := {}             # 타일 → { 8m 칸 → [[MultiMesh, 번호, Transform3D, 수관 반지름]] } (가림 처리용 큰 식생)
var _cut := {}              # [타일, MultiMesh id, 번호] → { mm, i, xf, k(0..1 보이는 정도), want }
const CUT_CELL := 8.0
const SHADOW_MIN_H := 0.9  # 이보다 낮은 식생(풀·꽃·잔돌)은 그림자를 그리지 않는다
const SUB := 64.0           # 식생 묶음을 다시 나눌 칸(m)       # 칸 → [{seg:{a,b,r}}]

# ---------------------------------------------------------------------------
# 불러오기
# ---------------------------------------------------------------------------
static func find_data_dir(pref := "") -> String:
	if pref != "":
		return pref if pref.ends_with("/") else pref + "/"
	for d in DEFAULT_DIRS:
		if FileAccess.file_exists(d + "region.json") and FileAccess.file_exists(d + "height.png"): return d
	return ""

func load_region(dir := "") -> void:
	data_dir = find_data_dir(dir)
	if data_dir == "":
		push_error("권역 데이터가 없다: region_data/JL_NAMWON_UNBONG 또는 shots/region/tmp_data (scripts/region/tools/make_tmp_region.py)")
		return
	var t0 := Time.get_ticks_msec()
	region = JSON.parse_string(FileAccess.get_file_as_string(data_dir + "region.json"))
	var hm: Dictionary = region.height
	var hd := PngRaw.load_gray(ProjectSettings.globalize_path(data_dir + hm.file))
	hbytes = hd.bytes; hbpp = hd.bpp
	hnx = hd.w; hnz = hd.h
	hx0 = float(hm.x0); hz0 = float(hm.z0); hstep = float(hm.cell)
	hy0 = float(hm.y_min)
	hscale = (float(hm.y_max) - hy0) / (65535.0 if hbpp == 2 else 255.0 * 256.0)
	var lm: Dictionary = region.get("landuse", {})
	var lpath: String = data_dir + lm.get("file", "landuse.png")
	if FileAccess.file_exists(lpath):
		var ld := PngRaw.load_gray(ProjectSettings.globalize_path(lpath))
		lbytes = ld.bytes; lw = ld.w; lh = ld.h
	else:
		# 토지이용이 아직 없으면 전부 풀밭(1)으로
		push_warning("landuse.png 없음 — 전부 풀밭으로: " + lpath)
		lw = hnx; lh = hnz
		lbytes = PackedByteArray(); lbytes.resize(lw * lh); lbytes.fill(1)
	lx0 = float(lm.get("x0", hx0)); lz0 = float(lm.get("z0", hz0))
	lcell = float(lm.get("cell", hstep * float(hnx - 1) / maxf(1.0, lw - 1)))
	var sp: Dictionary = region.get("spawn", { x = 0.0, z = 0.0 })
	spawn = Vector2(float(sp.x), float(sp.z))
	camera_zones = region.get("camera_zones", [])
	for c in region.get("crossings", []): _crossings.append(Vector2(float(c.x), float(c.z)))
	tile_min = Vector2i(floori(hx0 / TILE), floori(hz0 / TILE))
	tile_max = Vector2i(floori((hx0 + (hnx - 1) * hstep) / TILE), floori((hz0 + (hnz - 1) * hstep) / TILE))
	_make_textures()
	_make_materials()
	terrain_root = Node3D.new(); terrain_root.name = "terrain"; add_child(terrain_root)
	water_root = Node3D.new(); water_root.name = "water"; add_child(water_root)
	statics_root = Node3D.new(); statics_root.name = "statics"; add_child(statics_root)
	scatter_root = Node3D.new(); scatter_root.name = "scatter"; add_child(scatter_root)
	mesh_near = _grid_mesh(CHUNK, 1)
	mesh_mid = _grid_mesh(TILE / MID_STEP, MID_STEP)
	_build_far()
	_build_rivers()
	if use_scatter and FileAccess.file_exists(SCATTER_PATH):
		var scr = load(SCATTER_PATH)
		# 다른 에이전트가 만드는 중이라 문법 오류일 수 있다 → 쓸 수 있을 때만
		var ok: bool = scr is GDScript and scr.can_instantiate()
		if ok:
			ok = false
			for m in scr.get_script_method_list():
				if m.name == "scatter": ok = true
		if ok:
			_scatter_script = scr
			# 모델 메시·재질을 메인 스레드에서 미리 만든다(작업 스레드에서 처음 만들면 느리고 위험)
			for m in scr.get_script_method_list():
				if m.name == "warm":
					var tw := Time.get_ticks_msec()
					scr.warm(0); scr.warm(1)
					print("REGION scatter warm ms=", Time.get_ticks_msec() - tw)
		else: push_warning("kit/nature/scatter.gd를 쓸 수 없어 식생을 건너뛴다")
	if markers: _place_markers()
	print("REGION data=%s %dx%d cell=%.1f tiles=%s..%s scatter=%s load_ms=%d" % [data_dir, hnx, hnz, hstep, tile_min, tile_max, _scatter_script != null, Time.get_ticks_msec() - t0])

func _make_textures() -> void:
	var himg := Image.create_from_data(hnx, hnz, false, Image.FORMAT_RG8 if hbpp == 2 else Image.FORMAT_R8, hbytes)
	height_tex = ImageTexture.create_from_image(himg)
	var limg := Image.create_from_data(lw, lh, false, Image.FORMAT_R8, lbytes)
	landuse_tex = ImageTexture.create_from_image(limg)

func _common_params(m: ShaderMaterial) -> void:
	m.set_shader_parameter("hmap", height_tex)
	m.set_shader_parameter("lumap", landuse_tex)
	m.set_shader_parameter("h_meta", Vector4(hx0, hz0, 1.0 / hstep, 0.0))
	m.set_shader_parameter("h_range", Vector2(hy0, hscale))
	m.set_shader_parameter("h_size", Vector2i(hnx, hnz))
	m.set_shader_parameter("lu_meta", Vector4(lx0, lz0, 1.0 / lcell, 0.0))
	m.set_shader_parameter("lu_size", Vector2i(lw, lh))

func _make_materials() -> void:
	var sh: Shader = load("res://shaders/region_terrain.gdshader")
	var ground: Texture2D = Kit.texture("ground")
	mat_near = ShaderMaterial.new(); mat_near.shader = sh
	_common_params(mat_near)
	mat_near.set_shader_parameter("ground_tex", ground)
	mat_near.set_shader_parameter("ramp_tex", Materials.ramp_texture())
	mat_near.set_shader_parameter("grid_step", 1.0)
	mat_near.set_shader_parameter("noise_tex", _noise_texture())
	mat_near.set_shader_parameter("skirt", SKIRT)
	mat_mid = mat_near.duplicate()
	mat_mid.set_shader_parameter("grid_step", float(MID_STEP))
	mat_mid.set_shader_parameter("detail_amp", 0.0)
	mat_mid.set_shader_parameter("skirt", SKIRT * 2.0)
	mat_far = ShaderMaterial.new(); mat_far.shader = load("res://shaders/region_far.gdshader")
	_common_params(mat_far)
	mat_far.set_shader_parameter("grid_step", float(FAR_STEP))
	mat_water = ShaderMaterial.new(); mat_water.shader = load("res://shaders/region_water.gdshader")
	mat_water.set_shader_parameter("water_tex", Kit.texture("water"))
	mat_water.set_shader_parameter("ramp_tex", Materials.ramp_texture())

static func _noise_texture() -> ImageTexture:
	var fn := FastNoiseLite.new()
	fn.noise_type = FastNoiseLite.TYPE_VALUE_CUBIC
	fn.seed = 1870
	fn.frequency = 1.0 / 32.0
	fn.fractal_type = FastNoiseLite.FRACTAL_FBM
	fn.fractal_octaves = 3
	var img := fn.get_seamless_image(256, 256, false, false, 0.1, true)
	img.convert(Image.FORMAT_L8)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

# 지형 재질 전부에 같은 값 넣기(시간대·안개 기준 높이 등 — region_main이 부른다)
func set_terrain_param(name: String, v: Variant) -> void:
	for m in [mat_near, mat_mid, mat_water]:
		if m: m.set_shader_parameter(name, v)

func set_far_param(name: String, v: Variant) -> void:
	if mat_far: mat_far.set_shader_parameter(name, v)

# ---------------------------------------------------------------------------
# 높이·토지이용 (셰이더와 같은 식)
# ---------------------------------------------------------------------------
func _hraw(i: int, j: int) -> float:
	i = clampi(i, 0, hnx - 1); j = clampi(j, 0, hnz - 1)
	var k := j * hnx + i
	if hbpp == 2: return hy0 + float(hbytes[k * 2] * 256 + hbytes[k * 2 + 1]) * hscale
	return hy0 + float(hbytes[k] * 256) * hscale

# 데이터 높이(쌍선형, 잡음 없음)
func data_height(x: float, z: float) -> float:
	var fx := clampf((x - hx0) / hstep, 0.0, hnx - 1.001)
	var fz := clampf((z - hz0) / hstep, 0.0, hnz - 1.001)
	var i := int(fx); var j := int(fz)
	var tx := fx - i; var tz := fz - j
	return lerpf(lerpf(_hraw(i, j), _hraw(i + 1, j), tx), lerpf(_hraw(i, j + 1), _hraw(i + 1, j + 1), tx), tz)

func _lu(i: int, j: int) -> int:
	return lbytes[clampi(j, 0, lh - 1) * lw + clampi(i, 0, lw - 1)]

func landuse_at(x: float, z: float) -> int:
	return _lu(roundi((x - lx0) / lcell), roundi((z - lz0) / lcell))

static func _hash(ix: int, iz: int) -> float:
	var h := ((ix & M32) * 374761393 + (iz & M32) * 668265263) & M32
	h = ((h ^ (h >> 13)) * 1274126177) & M32
	h = h ^ (h >> 16)
	return float(h) / 4294967295.0

static func _vnoise(x: float, z: float) -> float:
	var fx := floorf(x); var fz := floorf(z)
	var ix := int(fx); var iz := int(fz)
	var u := x - fx; var v := z - fz
	u = u * u * (3.0 - 2.0 * u); v = v * v * (3.0 - 2.0 * v)
	return lerpf(lerpf(_hash(ix, iz), _hash(ix + 1, iz), u), lerpf(_hash(ix, iz + 1), _hash(ix + 1, iz + 1), u), v)

func _detail_mask(x: float, z: float) -> float:
	var fx := clampf((x - lx0) / lcell, 0.0, lw - 1.001)
	var fz := clampf((z - lz0) / lcell, 0.0, lh - 1.001)
	var i := int(fx); var j := int(fz)
	var tx := fx - i; var tz := fz - j
	return lerpf(lerpf(LU_DETAIL[_lu(i, j)], LU_DETAIL[_lu(i + 1, j)], tx), lerpf(LU_DETAIL[_lu(i, j + 1)], LU_DETAIL[_lu(i + 1, j + 1)], tx), tz)

static func _detail(x: float, z: float) -> float:
	return (_vnoise(x * 0.14, z * 0.14) - 0.5) * 0.36 + (_vnoise(x * 0.45 + 31.0, z * 0.45 + 17.0) - 0.5) * 0.10

# 근경 격자점(정수 m)의 높이 = 셰이더 r_height()
func lattice_height(x: float, z: float) -> float:
	return data_height(x, z) + _detail(x, z) * _detail_mask(x, z)

# 식생 흩뿌리기용 빠른 높이(약 3µs): 격자 삼각형 보간 대신 그 자리에서 바로 데이터+잡음 — height_at과 차이 2cm 안팎
func height_fast(x: float, z: float) -> float:
	var fx := clampf((x - hx0) / hstep, 0.0, hnx - 1.001)
	var fz := clampf((z - hz0) / hstep, 0.0, hnz - 1.001)
	var i := int(fx); var j := int(fz)
	var tx := fx - i; var tz := fz - j
	var k := j * hnx + i
	var h: float
	if hbpp == 2:
		var a := hbytes[k * 2] * 256 + hbytes[k * 2 + 1]; var b := hbytes[k * 2 + 2] * 256 + hbytes[k * 2 + 3]
		var k2 := k + hnx
		var c := hbytes[k2 * 2] * 256 + hbytes[k2 * 2 + 1]; var d := hbytes[k2 * 2 + 2] * 256 + hbytes[k2 * 2 + 3]
		h = hy0 + lerpf(lerpf(a, b, tx), lerpf(c, d, tx), tz) * hscale
	else:
		h = data_height(x, z)
	var m: float = LU_DETAIL[landuse_at(x, z)]
	if m == 0.0: return h
	return h + _detail(x, z) * m

# 렌더 면과 같은 삼각형 보간(대각선 (i+1,j)–(i,j+1), _grid_mesh와 같음)
func height_at(x: float, z: float) -> float:
	var fx := floorf(x); var fz := floorf(z)
	var tx := x - fx; var tz := z - fz
	var b := lattice_height(fx + 1.0, fz); var c := lattice_height(fx, fz + 1.0)
	if tx + tz <= 1.0:
		var a := lattice_height(fx, fz)
		return a + (b - a) * tx + (c - a) * tz
	var d := lattice_height(fx + 1.0, fz + 1.0)
	return d + (c - d) * (1.0 - tx) + (b - d) * (1.0 - tz)

# ---------------------------------------------------------------------------
# 메시
# ---------------------------------------------------------------------------
# n×n 칸, 간격 step의 평평한 격자(+ 가장자리 치마: y=-1로 표시, 셰이더가 내린다)
static func _grid_mesh(n: int, step: int) -> ArrayMesh:
	var v := PackedVector3Array()
	var idx := PackedInt32Array()
	var row := n + 1
	v.resize(row * row)
	for j in row:
		for i in row:
			v[j * row + i] = Vector3(i * step, 0, j * step)
	idx.resize(n * n * 6)
	var k := 0
	for j in n:
		for i in n:
			var a := j * row + i; var b := a + 1; var c := a + row; var d := c + 1
			idx[k] = a; idx[k + 1] = b; idx[k + 2] = c
			idx[k + 3] = b; idx[k + 4] = d; idx[k + 5] = c
			k += 6
	# 치마: 네 변을 따라 아래로 내린 띠(양면)
	var edges := []
	for i in row: edges.append([Vector2i(i, 0), 0])
	for i in row: edges.append([Vector2i(i, n), 1])
	for j in row: edges.append([Vector2i(0, j), 2])
	for j in row: edges.append([Vector2i(n, j), 3])
	for side in 4:
		var top := []; var bot := []
		for e in edges:
			if e[1] != side: continue
			var g: Vector2i = e[0]
			top.append(g.y * row + g.x)
			bot.append(v.size())
			v.append(Vector3(g.x * step, -1, g.y * step))
		for q in top.size() - 1:
			var a: int = top[q]; var b: int = top[q + 1]; var c: int = bot[q]; var d: int = bot[q + 1]
			idx.append_array(PackedInt32Array([a, b, c, b, d, c, a, c, b, b, c, d]))
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	var nrm := PackedVector3Array(); nrm.resize(v.size()); nrm.fill(Vector3.UP)
	arr[Mesh.ARRAY_NORMAL] = nrm
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m

func _build_far() -> void:
	var x0 := floorf(hx0 / FAR_STEP) * FAR_STEP; var z0 := floorf(hz0 / FAR_STEP) * FAR_STEP
	var nx := int(ceil((hx0 + (hnx - 1) * hstep - x0) / FAR_STEP)); var nz := int(ceil((hz0 + (hnz - 1) * hstep - z0) / FAR_STEP))
	var v := PackedVector3Array(); var idx := PackedInt32Array()
	for j in nz + 1:
		for i in nx + 1:
			v.append(Vector3(i * FAR_STEP, 0, j * FAR_STEP))
	for j in nz:
		for i in nx:
			var a := j * (nx + 1) + i; var b := a + 1; var c := a + nx + 1; var d := c + 1
			idx.append_array(PackedInt32Array([a, b, c, b, d, c]))
	var arr := []; arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v; arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new(); m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	far_node = MeshInstance3D.new(); far_node.name = "far"
	far_node.mesh = m
	far_node.material_override = mat_far
	far_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	far_node.position = Vector3(x0, 0, z0)
	far_node.custom_aabb = AABB(Vector3(0, hy0 - 10, 0), Vector3(nx * FAR_STEP, hscale * 65535.0 + 20, nz * FAR_STEP))
	add_child(far_node)

# ---------------------------------------------------------------------------
# 하천 물: region.json.rivers의 수면 높이·폭으로 띠 메시(약 250m씩 잘라 화면 밖은 그리지 않게)
# ---------------------------------------------------------------------------
func _build_rivers() -> void:
	for r in region.get("rivers", []):
		var pts := []
		for p in r.points: pts.append(Vector3(float(p[0]), float(p[2]) if p.size() > 2 else data_height(p[0], p[1]), float(p[1])))
		if pts.size() < 2: continue
		var w := maxf(float(r.get("width_m", 6.0)), 5.2)  # terrain-data: 물 메시 폭 = max(width_m, 5.2)
		# 걷기 막기용 선분 격자: 중심선에서 폭의 80% 안쪽이고 땅이 수면보다 낮으면 물 속
		for k in pts.size() - 1:
			var sg := { a = Vector2(pts[k].x, pts[k].z), b = Vector2(pts[k + 1].x, pts[k + 1].z), r = w * 0.8, ya = pts[k].y, yb = pts[k + 1].y }
			_grid_insert(_river_grid, { type = "box", minX = minf(sg.a.x, sg.b.x) - sg.r, maxX = maxf(sg.a.x, sg.b.x) + sg.r,
				minZ = minf(sg.a.y, sg.b.y) - sg.r, maxZ = maxf(sg.a.y, sg.b.y) + sg.r, seg = sg })
		pts = _resample(pts, 3.0)
		var hw := w * 0.5 * 1.18 + 0.6
		var chunk := 84
		var s := 0
		while s < pts.size() - 1:
			var e := mini(s + chunk, pts.size() - 1)
			water_root.add_child(_river_chunk(pts, s, e, hw, w, String(r.get("id", "river"))))
			s = e

static func _chaikin(p: Array) -> Array:
	var o := [p[0]]
	for i in p.size() - 1:
		var a: Vector3 = p[i]; var b: Vector3 = p[i + 1]
		o.append(a.lerp(b, 0.25)); o.append(a.lerp(b, 0.75))
	o.append(p[p.size() - 1])
	return o

static func _resample(p: Array, step: float) -> Array:
	var o := [p[0]]
	var acc := 0.0
	for i in p.size() - 1:
		var a: Vector3 = p[i]; var b: Vector3 = p[i + 1]
		var l := Vector2(b.x - a.x, b.z - a.z).length()
		var t := step - acc
		while t <= l:
			o.append(a.lerp(b, t / l)); t += step
		acc = l - (t - step)
	o.append(p[p.size() - 1])
	return o

func _river_chunk(pts: Array, s: int, e: int, hw: float, w: float, name: String) -> MeshInstance3D:
	var v := PackedVector3Array(); var uv := PackedVector2Array(); var col := PackedColorArray(); var nrm := PackedVector3Array()
	var idx := PackedInt32Array()
	var dist := 0.0
	for i in range(0, s): dist += Vector2(pts[i + 1].x - pts[i].x, pts[i + 1].z - pts[i].z).length()
	for i in range(s, e + 1):
		var p: Vector3 = pts[i]
		var a: Vector3 = pts[maxi(i - 1, 0)]; var b: Vector3 = pts[mini(i + 1, pts.size() - 1)]
		var t := Vector2(b.x - a.x, b.z - a.z).normalized()
		var n := Vector2(-t.y, t.x)
		# 여울/소: 수면 기울기(하류로 떨어지는 정도)
		var a2: Vector3 = pts[maxi(i - 4, 0)]; var b2: Vector3 = pts[mini(i + 4, pts.size() - 1)]
		var run := maxf(1.0, Vector2(b2.x - a2.x, b2.z - a2.z).length())
		var slope := (a2.y - b2.y) / run
		var rapid := smoothstep(0.006, 0.03, slope)
		var pool := (1.0 - smoothstep(0.0, 0.004, slope)) * clampf(0.4 + _vnoise(dist * 0.01, 3.0), 0.0, 1.0)
		var c := Color(rapid, pool, w / 40.0)
		for k in 2:
			var sgn := -1.0 if k == 0 else 1.0
			v.append(Vector3(p.x + n.x * hw * sgn, p.y, p.z + n.y * hw * sgn))
			uv.append(Vector2(dist / 7.0, float(k)))
			col.append(c); nrm.append(Vector3.UP)
		if i < e:
			var q := (i - s) * 2
			idx.append_array(PackedInt32Array([q, q + 2, q + 1, q + 1, q + 2, q + 3]))
			dist += Vector2(pts[i + 1].x - p.x, pts[i + 1].z - p.z).length()
	var arr := []; arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v; arr[Mesh.ARRAY_TEX_UV] = uv; arr[Mesh.ARRAY_COLOR] = col; arr[Mesh.ARRAY_NORMAL] = nrm
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new(); m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mi := MeshInstance3D.new(); mi.name = name
	mi.mesh = m; mi.material_override = mat_water
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = TILE * (MID_R + 0.5)  # 원경(먹빛 능선) 위에는 물을 그리지 않는다
	return mi

# ---------------------------------------------------------------------------
# 타일 스트리밍
# ---------------------------------------------------------------------------
func _tile_ok(t: Vector2i) -> bool:
	return t.x >= tile_min.x and t.x <= tile_max.x and t.y >= tile_min.y and t.y <= tile_max.y

static func _ring(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))

func tile_of(x: float, z: float) -> Vector2i:
	return Vector2i(floori(x / TILE), floori(z / TILE))

# 스트리밍 중심 갱신(플레이어 위치). 타일이 바뀔 때만 일한다.
func focus(pos: Vector3) -> void:
	var c := tile_of(pos.x, pos.z)
	if c == _center: return
	_center = c
	if OS.get_cmdline_user_args().has("--trace"): print("  RETILE f=%d center=%s" % [Engine.get_process_frames(), c])
	var want := {}
	for dz in range(-MID_R, MID_R + 1):
		for dx in range(-MID_R, MID_R + 1):
			var t := c + Vector2i(dx, dz)
			if not _tile_ok(t): continue
			var ring := maxi(absi(dx), absi(dz))
			var lod := 0 if ring <= NEAR_R else 1
			# 이미 근경인 타일은 한 칸 더 멀어질 때까지 근경 유지
			if lod == 1 and tiles.has(t) and tiles[t].lod == 0 and ring <= NEAR_R + KEEP: lod = 0
			want[t] = lod
	for t in tiles.keys():
		if not want.has(t): _drop_tile(t)
	for t in want: _set_tile(t, want[t])
	var lo := Vector2i(maxi(c.x - MID_R, tile_min.x), maxi(c.y - MID_R, tile_min.y))
	var hi := Vector2i(mini(c.x + MID_R, tile_max.x), mini(c.y + MID_R, tile_max.y))
	mat_far.set_shader_parameter("hole", Vector4(lo.x * TILE, lo.y * TILE, (hi.x + 1) * TILE, (hi.y + 1) * TILE))
	# 식생 대기열: 가까운 타일부터
	_queue_scatter()
	stats.near = 0; stats.mid = 0
	for t in tiles:
		if tiles[t].lod == 0: stats.near += 1
		else: stats.mid += 1

func _set_tile(t: Vector2i, lod: int) -> void:
	var st: Dictionary
	if tiles.has(t):
		st = tiles[t]
		if st.lod == lod: return
	else:
		var node: Node3D = _pool.pop_back() if not _pool.is_empty() else _new_tile_node()
		node.position = Vector3(t.x * TILE, 0, t.y * TILE)
		node.name = "tile_%d_%d" % [t.x, t.y]
		# 칸(64m)마다 높이 범위 → 화면 밖 칸은 그리지 않는다(고정 시점이라 근경 대부분이 걸러진다)
		var all := Vector2(INF, -INF)
		var n := TILE / CHUNK
		for cj in n:
			for ci in n:
				var yr := _chunk_y(t.x * TILE + ci * CHUNK, t.y * TILE + cj * CHUNK)
				all = Vector2(minf(all.x, yr.x), maxf(all.y, yr.y))
				var mi: MeshInstance3D = node.get_child(1 + cj * n + ci)
				mi.custom_aabb = AABB(Vector3(-1, yr.x - SKIRT - 2.0, -1), Vector3(CHUNK + 2, yr.y - yr.x + SKIRT + 4.0, CHUNK + 2))
		node.get_child(0).custom_aabb = AABB(Vector3(-1, all.x - SKIRT * 2.0 - 2.0, -1), Vector3(TILE + 2, all.y - all.x + SKIRT * 2.0 + 4.0, TILE + 2))
		terrain_root.add_child(node)
		_gen += 1
		st = { lod = -1, node = node, scatter_nodes = [], scatter_job = -1, scatter_hold = null, has0 = false, has1 = false, gen = _gen }
		tiles[t] = st
	st.lod = lod
	var kids: Array = st.node.get_children()
	kids[0].visible = lod != 0
	for i in range(1, kids.size()): kids[i].visible = lod == 0
	if lod != 0: _unscatter(t)
	_attach_statics(t, lod)

func _new_tile_node() -> Node3D:
	var node := Node3D.new()
	var mid := MeshInstance3D.new()
	mid.mesh = mesh_mid; mid.material_override = mat_mid
	mid.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(mid)
	var n := TILE / CHUNK
	for cj in n:
		for ci in n:
			var mi := MeshInstance3D.new()
			mi.mesh = mesh_near; mi.material_override = mat_near
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.position = Vector3(ci * CHUNK, 0, cj * CHUNK)
			node.add_child(mi)
	return node

# 64m 칸의 데이터 높이 범위(16m 간격 표본 + 여유)
func _chunk_y(x0: float, z0: float) -> Vector2:
	var lo := INF; var hi := -INF
	var i0 := floori((x0 - hx0) / hstep); var j0 := floori((z0 - hz0) / hstep)
	var n := int(CHUNK / hstep)
	var st := maxi(1, int(16.0 / hstep))
	for j in range(j0 - st, j0 + n + st + 1, st):
		for i in range(i0 - st, i0 + n + st + 1, st):
			var h := _hraw(i, j)
			lo = minf(lo, h); hi = maxf(hi, h)
	return Vector2(lo - 8.0, hi + 8.0)

func _drop_tile(t: Vector2i) -> void:
	var st: Dictionary = tiles[t]
	_unscatter(t)
	_attach_statics(t, 2)
	terrain_root.remove_child(st.node)
	_pool.append(st.node)
	tiles.erase(t)

# ---- 식생(kit/nature/scatter.gd) — 백그라운드 ----
func _unscatter(t: Vector2i) -> void:
	_queue.erase(t)
	var st: Dictionary = tiles[t]
	for e in st.scatter_nodes:
		if e.node != null: e.node.queue_free()
	st.scatter_nodes = []
	st.has0 = false; st.has1 = false
	_gen += 1
	st.gen = _gen
	_scatter_grid.erase(t)
	_tall.erase(t)
	for k in _cut.keys():
		if k[0] == t: _cut.erase(k)
	# 진행 중 작업은 끝나면 버린다(_poll_jobs)

# 작업 스레드: 같은 타일을 lod 0(가까운 묶음용)과 lod 1(먼 묶음용) 두 벌로 흩뿌린다.
# 묶음마다 차지하는 xz 사각형을 미리 계산해 두고, 메인 스레드는 거리만 보고 어느 벌을 보일지 고른다(_update_scatter_lod).
# 작업 스레드에서는 렌더링 서버를 거의 건드리지 않는다: 원본 MultiMesh 버퍼를 묶음마다 한 번만 읽어
# SUB m 칸으로 나눈 "자료"만 만들고, MultiMesh·노드 생성은 메인 스레드가 프레임마다 조금씩 한다(_poll_jobs).
# (작업 스레드에서 MultiMesh를 수백 개 만들거나 버퍼를 여러 번 읽으면 렌더 스레드와 엉켜 프레임이 100ms 넘게 튄다)
static func _scatter_job(scr: Script, rect: Rect2, ha: Callable, la: Callable, seed: int, lods: Array, split: bool, hold: Dictionary) -> void:
	var out := []
	var cols = null
	var tall := {}
	var temps := []
	for lod in lods:
		var res: Dictionary = scr.scatter(rect, ha, la, seed, lod)
		if lod == 0 or cols == null:
			cols = res.get("colliders", [])
		for n0 in res.get("nodes", []):
			if not (n0 is MultiMeshInstance3D) or n0.multimesh == null or n0.multimesh.transform_format != MultiMesh.TRANSFORM_3D:
				out.append({ node = n0, lod = lod, rect = Rect2(n0.position.x, n0.position.z, 0, 0) if n0 is Node3D else Rect2() })
				continue
			temps.append(n0)
			var mm: MultiMesh = n0.multimesh
			var buf: PackedFloat32Array = mm.buffer
			var stride := 12 + (4 if mm.use_colors else 0) + (4 if mm.use_custom_data else 0)
			var base: Transform3D = n0.transform
			var ab := mm.mesh.get_aabb() if mm.mesh else AABB()
			var is_tall := ab.size.y >= 2.5
			var cr := maxf(ab.size.x, ab.size.z) * 0.5
			var cast: bool = n0.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF and lod == 0 and ab.size.y >= SHADOW_MIN_H
			var groups := {}
			for i in mm.instance_count:
				var o := i * stride
				if o + stride > buf.size(): break
				var w := base * Vector3(buf[o + 3], buf[o + 7], buf[o + 11])
				var k := Vector2i(floori(w.x / SUB), floori(w.z / SUB)) if split else Vector2i.ZERO
				if not groups.has(k): groups[k] = { buf = PackedFloat32Array(), lo = Vector2(INF, INF), hi = Vector2(-INF, -INF), n = 0 }
				var g: Dictionary = groups[k]
				g.buf.append_array(buf.slice(o, o + stride))
				g.lo = Vector2(minf(g.lo.x, w.x), minf(g.lo.y, w.z)); g.hi = Vector2(maxf(g.hi.x, w.x), maxf(g.hi.y, w.z))
				g.n += 1
			for k in groups:
				var g: Dictionary = groups[k]
				var e := { xf = base, mat = n0.material_override, mesh = mm.mesh, colors = mm.use_colors, custom = mm.use_custom_data, buf = g.buf, count = g.n,
					lod = lod, rect = Rect2(g.lo, g.hi - g.lo), cast = cast, mm = null, node = null }
				out.append(e)
				if is_tall and lod == 0:
					for i in int(g.n):
						var o: int = i * stride
						var bx := Vector3(g.buf[o], g.buf[o + 4], g.buf[o + 8]); var by := Vector3(g.buf[o + 1], g.buf[o + 5], g.buf[o + 9]); var bz := Vector3(g.buf[o + 2], g.buf[o + 6], g.buf[o + 10])
						var xf := Transform3D(Basis(bx, by, bz), Vector3(g.buf[o + 3], g.buf[o + 7], g.buf[o + 11]))
						var w := base * xf.origin
						var ck := Vector2i(floori(w.x / CUT_CELL), floori(w.z / CUT_CELL))
						if not tall.has(ck): tall[ck] = []
						tall[ck].append([e, i, xf, cr * bx.length(), Vector2(w.x, w.z)])
	hold.entries = out
	hold.colliders = cols
	hold.lods = lods
	hold.tall = tall
	hold.temps = temps

# 메인 스레드: 자료 → MultiMeshInstance3D
static func _make_node(e: Dictionary) -> Node3D:
	if e.node != null: return e.node
	var m := MultiMesh.new()
	m.transform_format = MultiMesh.TRANSFORM_3D
	m.use_colors = e.colors; m.use_custom_data = e.custom
	m.mesh = e.mesh
	m.instance_count = e.count
	m.buffer = e.buf
	var c := MultiMeshInstance3D.new()
	c.transform = e.xf
	c.material_override = e.mat
	c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if e.cast else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	c.multimesh = m
	e.mm = m
	e.node = c
	e.buf = PackedFloat32Array()
	return c

func _scatter_need(t: Vector2i) -> Array:
	var st: Dictionary = tiles[t]
	var need := []
	if _ring(t, _center) <= 1 and not st.has0: need.append(0)
	if not st.has1: need.append(1)
	return need

func _queue_scatter() -> void:
	if _scatter_script == null: return
	for t in tiles:
		var st: Dictionary = tiles[t]
		if st.lod != 0 or st.scatter_job >= 0 or _queue.has(t): continue
		if not _scatter_need(t).is_empty(): _queue.append(t)
	_queue.sort_custom(func(a, b): return _ring(a, _center) < _ring(b, _center))

func _start_jobs() -> void:
	var running := 0
	for t in tiles:
		if tiles[t].scatter_job >= 0: running += 1
	while running < MAX_JOBS and not _queue.is_empty():
		var t: Vector2i = _queue.pop_front()
		if not tiles.has(t) or tiles[t].lod != 0: continue
		var need := _scatter_need(t)
		if need.is_empty(): continue
		var hold := { tile = t }
		var rect := Rect2(t.x * TILE, t.y * TILE, TILE, TILE)
		var seed := String(region.get("region_id", "region")).hash() & 0x7fffffff  # 권역 시드(타일 구분은 scatter가 rect로)
		var ha := Callable(self, "height_fast"); var la := Callable(self, "landuse_at")
		tiles[t].scatter_job = WorkerThreadPool.add_task(_scatter_job.bind(_scatter_script, rect, ha, la, seed, need, split_scatter, hold), false, "scatter")
		tiles[t].scatter_hold = hold
		running += 1
	stats.jobs = running + _queue.size() + (1 if not _attach_q.is_empty() else 0)

func _poll_jobs() -> void:
	# 붙이기는 프레임당 ATTACH_PER_FRAME 묶음까지(한 번에 수백 개를 붙이면 프레임이 튄다)
	var n := 0
	while not _attach_q.is_empty() and n < ATTACH_PER_FRAME:
		var it: Array = _attach_q.pop_front()
		var t: Vector2i = it[0]; var e: Dictionary = it[1]
		if not tiles.has(t) or tiles[t].lod != 0 or tiles[t].gen != it[2]:
			if e.node != null and not e.node.is_inside_tree(): e.node.free()
			continue
		_make_node(e)
		e.node.visible = false
		e.shown = false
		scatter_root.add_child(e.node)
		tiles[t].scatter_nodes.append(e)
		n += 1
		_lod_dirty = true
	for t in tiles:
		var st: Dictionary = tiles[t]
		if st.scatter_job < 0 or not WorkerThreadPool.is_task_completed(st.scatter_job): continue
		WorkerThreadPool.wait_for_task_completion(st.scatter_job)
		st.scatter_job = -1
		var hold: Dictionary = st.scatter_hold
		st.scatter_hold = null
		var entries: Array = hold.get("entries", [])
		for tn in hold.get("temps", []): tn.free()  # 원본 묶음 노드(자료만 빼 썼다)
		if st.lod != 0:
			for e in entries:
				if e.node != null: e.node.free()
			continue
		var lods: Array = hold.get("lods", [])
		if lods.has(0):
			st.has0 = true
			_tall[t] = hold.get("tall", {})
		if lods.has(1): st.has1 = true
		if lods.has(0) or not _scatter_grid.has(t):
			var g := {}
			for c in hold.get("colliders", []): _grid_insert(g, c)
			_scatter_grid[t] = g
		for e in entries: _attach_q.append([t, e, st.gen])
		stats.scatter_done += 1
		if OS.get_cmdline_user_args().has("--trace"): print("  JOB f=%d tile=%s lods=%s nodes=%d" % [Engine.get_process_frames(), t, lods, entries.size()])
	_start_jobs()

# 식생 묶음 고르기: 플레이어에서 lod0_dist 안은 자세한 벌, scatter_far 안은 거친 벌, 그 너머(안개 속)는 그리지 않는다
func update_scatter_lod(player: Vector3, force := false) -> void:
	_lod_frame += 1
	if not force and not _lod_dirty and _lod_frame % 6 != 0: return
	_lod_dirty = false
	var p := Vector2(player.x, player.z)
	for t in tiles:
		for e in tiles[t].scatter_nodes:
			var r: Rect2 = e.rect
			var d := Vector2(maxf(maxf(r.position.x - p.x, 0.0), p.x - r.end.x), maxf(maxf(r.position.y - p.y, 0.0), p.y - r.end.y)).length()
			var on: bool = (d < lod0_dist) if e.lod == 0 else (d >= lod0_dist and d < scatter_far)
			if on != e.shown:
				e.shown = on
				e.node.visible = on

# ---------------------------------------------------------------------------
# 정적 물체(키트 build() 결과)
# ---------------------------------------------------------------------------
# node: 키트 node(원점 = 바닥 중심), world_xform: 놓을 자리, info: build()가 돌려준 사전(colliders/lights/occluder/interior…)
func add_static(node: Node3D, world_xform: Transform3D, info: Dictionary = {}) -> void:
	node.transform = world_xform
	var cols := []
	for c in info.get("colliders", []):
		var wc := _xf_collider(c, world_xform)
		cols.append(wc)
		_grid_insert(_static_grid, wc)
		colliders.append(wc)
	var ls := []
	for l in info.get("lights", []):
		var p := world_xform * Vector3(float(l.x), float(l.y), float(l.z))
		ls.append({ x = p.x, y = p.y, z = p.z, kind = l.get("kind", "lantern") })
	var occ = null
	if info.get("occluder", false):
		var meshes := []
		for m in node.find_children("*", "MeshInstance3D", true, false):
			for s in m.mesh.get_surface_count():
				if m.get_surface_override_material(s) == null and m.mesh.surface_get_material(s) is ShaderMaterial:
					m.set_surface_override_material(s, m.mesh.surface_get_material(s))
			meshes.append(m)
		if not meshes.is_empty():
			occ = { node = node, aabb = AABB(), meshes = meshes, alpha = 1.0, target = 1.0, faded = false }
	var interior = null
	if info.has("interior"):
		var it: Dictionary = info.interior.duplicate()
		var b := _xf_box(it, world_xform)
		it.merge(b, true)
		interior = it
	var fp: Vector2 = info.get("footprint", Vector2.ZERO)
	var t := tile_of(world_xform.origin.x, world_xform.origin.z)
	var e := { node = node, colliders = cols, lights = ls, occ = occ, interior = interior, attached = false, big = fp.length() > 40.0 }
	if not _statics.has(t): _statics[t] = []
	_statics[t].append(e)
	stats.statics += 1
	if tiles.has(t): _attach_one(e, tiles[t].lod)

func _attach_statics(t: Vector2i, lod: int) -> void:
	for e in _statics.get(t, []): _attach_one(e, lod)

# lod 0: 근경(전부), 1: 중경(큰 것만), 2: 없음
func _attach_one(e: Dictionary, lod: int) -> void:
	var on: bool = lod == 0 or (lod == 1 and e.big)
	if on == e.attached: return
	e.attached = on
	if on:
		statics_root.add_child(e.node)
		lights.append_array(e.lights)
		if e.occ != null:
			var box := AABB(); var first := true
			for m in e.occ.meshes:
				var bb: AABB = m.global_transform * m.get_aabb()
				box = bb if first else box.merge(bb); first = false
			e.occ.aabb = box
			occluders.append(e.occ)
		if e.interior != null: interiors.append(e.interior)
	else:
		if e.occ != null:
			if e.occ.alpha < 1.0:
				e.occ.alpha = 1.0; e.occ.target = 1.0
				set_occluder_alpha(e.occ, 1.0)
			occluders.erase(e.occ)
		for l in e.lights: lights.erase(l)
		if e.interior != null: interiors.erase(e.interior)
		statics_root.remove_child(e.node)
	lights_version += 1

static func _xf_collider(c: Dictionary, xf: Transform3D) -> Dictionary:
	if c.get("type", "circle") == "circle":
		var p := xf * Vector3(float(c.x), 0, float(c.z))
		return { type = "circle", x = p.x, z = p.z, r = float(c.r) * xf.basis.get_scale().x }
	var b := _xf_box(c, xf)
	b.type = "box"
	return b

static func _xf_box(b: Dictionary, xf: Transform3D) -> Dictionary:
	var mnx := INF; var mxx := -INF; var mnz := INF; var mxz := -INF
	for cx in [float(b.minX), float(b.maxX)]:
		for cz in [float(b.minZ), float(b.maxZ)]:
			var p := xf * Vector3(cx, 0, cz)
			mnx = minf(mnx, p.x); mxx = maxf(mxx, p.x); mnz = minf(mnz, p.z); mxz = maxf(mxz, p.z)
	return { minX = mnx, maxX = mxx, minZ = mnz, maxZ = mxz }

static func _grid_insert(g: Dictionary, c: Dictionary) -> void:
	var lo: Vector2; var hi: Vector2
	if c.get("type", "circle") == "circle":
		lo = Vector2(c.x - c.r, c.z - c.r); hi = Vector2(c.x + c.r, c.z + c.r)
	else:
		lo = Vector2(c.minX, c.minZ); hi = Vector2(c.maxX, c.maxZ)
	for j in range(floori(lo.y / GRID), floori(hi.y / GRID) + 1):
		for i in range(floori(lo.x / GRID), floori(hi.x / GRID) + 1):
			var k := Vector2i(i, j)
			if not g.has(k): g[k] = []
			g[k].append(c)

# ---------------------------------------------------------------------------
# 충돌(부모 move_circle이 이걸 부른다)
# ---------------------------------------------------------------------------
static func _hit(c: Dictionary, x: float, z: float, r: float) -> bool:
	if c.type == "circle":
		var dx: float = x - c.x; var dz: float = z - c.z; var rr: float = r + c.r
		return dx * dx + dz * dz < rr * rr
	var nx := clampf(x, c.minX, c.maxX); var nz := clampf(z, c.minZ, c.maxZ)
	var dx := x - nx; var dz := z - nz
	return dx * dx + dz * dz < r * r

func blocked(x: float, z: float, r: float) -> bool:
	if x < hx0 + 2.0 or z < hz0 + 2.0 or x > hx0 + (hnx - 1) * hstep - 2.0 or z > hz0 + (hnz - 1) * hstep - 2.0: return true
	if block_water and _in_river(x, z, r) and not _near_crossing(x, z): return true
	var ci := floori(x / GRID); var cj := floori(z / GRID)
	var t := tile_of(x, z)
	var sg = _scatter_grid.get(t)
	for j in range(cj - 1, cj + 2):
		for i in range(ci - 1, ci + 2):
			var k := Vector2i(i, j)
			for c in _static_grid.get(k, []):
				if _hit(c, x, z, r): return true
			if sg != null:
				for c in sg.get(k, []):
					if _hit(c, x, z, r): return true
	# 타일 경계 근처면 옆 타일 식생도
	var lx := x - t.x * TILE; var lz := z - t.y * TILE
	if lx < GRID or lz < GRID or lx > TILE - GRID or lz > TILE - GRID:
		for dt in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1)]:
			var g2 = _scatter_grid.get(t + dt)
			if g2 == null: continue
			for j in range(cj - 1, cj + 2):
				for i in range(ci - 1, ci + 2):
					for c in g2.get(Vector2i(i, j), []):
						if _hit(c, x, z, r): return true
	return false

func _in_river(x: float, z: float, r: float) -> bool:
	if landuse_at(x, z) == 5: return true
	var p := Vector2(x, z)
	for c in _river_grid.get(Vector2i(floori(x / GRID), floori(z / GRID)), []):
		var sg: Dictionary = c.seg
		var ab: Vector2 = sg.b - sg.a
		var t := clampf((p - sg.a).dot(ab) / maxf(ab.length_squared(), 1e-6), 0.0, 1.0)
		if p.distance_to(sg.a + ab * t) < sg.r:
			# 물가: 땅이 수면보다 낮으면 물 속
			if height_at(x, z) < lerpf(sg.ya, sg.yb, t) + 0.05: return true
	return false

# 나루·여울·다리 근처는 물에 들어갈 수 있다(다리 상판은 아직 없음 — kit-village 다리가 놓이면 높이를 넘겨받아야 한다)
func _near_crossing(x: float, z: float) -> bool:
	for c in _crossings:
		if absf(c.x - x) < 14.0 and absf(c.y - z) < 14.0: return true
	return false

func interior_at(x: float, z: float) -> Variant:
	for it in interiors:
		if in_box(it, x, z): return it
	return null

# 트리에 붙어 있지 않은 것(풀에 넣은 타일, 떼어 둔 정적 물체)은 직접 지운다
# 끝내기 전에(작업 스레드 풀이 살아 있을 때) 부른다: 대기열 비우고 진행 중 식생 작업을 기다린다.
# (트리가 지워지는 도중에 기다리면 macOS 종료 경로에서 풀이 이미 멈춰 영원히 기다릴 수 있다)
func shutdown() -> void:
	_queue.clear()
	for t in tiles:
		if tiles[t].scatter_job >= 0:
			WorkerThreadPool.wait_for_task_completion(tiles[t].scatter_job)
			tiles[t].scatter_job = -1
			var hold = tiles[t].scatter_hold
			tiles[t].scatter_hold = null
			if hold != null:
				for tn in hold.get("temps", []): tn.free()
				for e in hold.get("entries", []):
					if e.node != null and not e.node.is_inside_tree(): e.node.free()
	for it in _attach_q:
		if it[1].node != null and not it[1].node.is_inside_tree(): it[1].node.free()
	_attach_q.clear()

# 트리에 붙어 있지 않은 것(풀에 넣은 타일, 떼어 둔 정적 물체)은 직접 지운다
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		for n in _pool: n.free()
		_pool.clear()
		for t in _statics:
			for e in _statics[t]:
				if not e.attached and is_instance_valid(e.node): e.node.free()

func update(_dt: float, _time: float) -> void:
	_poll_jobs()

# ---------------------------------------------------------------------------
# 식생 가림 처리: 카메라와 플레이어 사이의 키 큰 식생(나무·대숲)을 잠시 줄여 숨긴다.
# 식생은 MultiMesh라 기존 occluders(물체 반투명)로는 못 하므로 인스턴스 단위로 처리한다.
# ---------------------------------------------------------------------------
func update_cutaway(dt: float, player: Vector3, cam: Vector3) -> void:
	for k in _cut: _cut[k].want = 1.0
	var lo := Vector2(minf(player.x, cam.x) - 6.0, player.z - 1.0)
	var hi := Vector2(maxf(player.x, cam.x) + 6.0, cam.z + 2.0)
	var pc := Vector2(player.x, player.z); var cc := Vector2(cam.x, cam.z)
	for j in range(floori(lo.y / CUT_CELL), floori(hi.y / CUT_CELL) + 1):
		for i in range(floori(lo.x / CUT_CELL), floori(hi.x / CUT_CELL) + 1):
			var cell := Vector2i(i, j)
			var t := tile_of(i * CUT_CELL + 1.0, j * CUT_CELL + 1.0)
			var g = _tall.get(t)
			if g == null: continue
			for e in g.get(cell, []):
				var p: Vector2 = e[4]
				# 카메라→플레이어 선분(xz)까지 거리가 수관 반지름+여유보다 가까우면
				var ab := pc - cc
				var tt := clampf((p - cc).dot(ab) / maxf(ab.length_squared(), 1e-4), 0.0, 1.05)
				if p.distance_to(cc + ab * tt) > e[3] + 0.9: continue
				if p.y < player.z - 0.6: continue
				var ent: Dictionary = e[0]
				if ent.mm == null: continue  # 아직 안 붙음
				var key := [t, ent.mm.get_instance_id(), e[1]]
				if not _cut.has(key): _cut[key] = { mm = ent.mm, i = e[1], xf = e[2], k = 1.0, want = 0.0 }
				else: _cut[key].want = 0.0
	var a := 1.0 - exp(-dt * 10.0)
	for key in _cut.keys():
		var c: Dictionary = _cut[key]
		var nk: float = c.k + (c.want - c.k) * a
		if absf(nk - c.want) < 0.02: nk = c.want
		if nk != c.k:
			c.k = nk
			var xf: Transform3D = c.xf
			var s := maxf(nk, 0.001)
			c.mm.set_instance_transform(c.i, Transform3D(xf.basis.scaled_local(Vector3(s, s, s)), xf.origin))
		if c.k >= 1.0 and c.want >= 1.0: _cut.erase(key)

# ---------------------------------------------------------------------------
# 임시 표지: 마을·랜드마크·고개 자리에 장승 같은 기둥(위치 확인용, 키트 배치는 이번 범위 밖)
# ---------------------------------------------------------------------------
func _place_markers() -> void:
	var items := []
	for s in region.get("settlements", []): items.append([s, Kit.hex(0x8a5a3c)])
	for s in region.get("landmarks", []): items.append([s, Kit.hex(0xa04a36)])
	for s in region.get("passes", []): items.append([s, Kit.hex(0x5a6a7a)])
	for it in items:
		var s: Dictionary = it[0]
		var x := float(s.x); var z := float(s.z)
		var r := Kit.Rng.new(hash(s.get("id", s.name)))
		var b := Kit.Batch.new()
		b.add("wood", Kit.paint(Kit.cyl(0.22, 0.26, 2.6, 7, 0, 1.3, 0), it[1], Kit.hex(0x5a3a28), 0.04, r))
		b.add("wood", Kit.paint(Kit.cyl(0.3, 0.24, 0.7, 7, 0, 2.9, 0), Kit.hex(0xd8c8a8), Kit.hex(0xb0a080), 0.03, r))
		b.add("flat", Kit.paint(Kit.box(0.5, 0.08, 0.06, 0, 2.95, 0.29), Kit.hex(0x2b2622)), 0.0)
		var node := b.build("표지_" + String(s.get("name", "")))
		var lab := Label3D.new()
		lab.text = String(s.get("name", ""))
		lab.font_size = 64; lab.pixel_size = 0.01
		lab.position = Vector3(0, 3.9, 0)
		lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lab.modulate = Color(0.12, 0.1, 0.09); lab.outline_modulate = Color(0.95, 0.92, 0.85); lab.outline_size = 12
		node.add_child(lab)
		var y := height_at(x, z)
		add_static(node, Transform3D(Basis(), Vector3(x, y, z)), { colliders = [{ type = "circle", x = 0.0, z = 0.0, r = 0.3 }], footprint = Vector2(1, 1) })
