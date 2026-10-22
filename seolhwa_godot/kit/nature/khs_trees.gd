# 사실 나무(trees-khs) 자산 — 곰솔 5종(국가유산청 스캔, 공공누리 1유형 · 출처 "국가유산청") + 참나무 stand-in 4종(ambientCG CC0 잎·껍질).
#   자산: assets/trees/(tools/trees_khs/build.sh가 짓는다) · 셰이더: shaders/tree_*.gdshader
#   쓰는 곳: kit/nature/scatter.gd(숲 흩뿌리기 — 임포스터 MultiMesh), scripts/region/tree_lod.gd(가까운 나무 LOD0/LOD1 MultiMesh), kit/nature/pine.gd(배치한 소나무)
#   층(layer) = 변형 번호 = 임포스터 배열 층 = 아래 NAMES 순서(assets/trees/meta.json과 같다)
extends RefCounted

const DIR := "res://assets/trees/"
const NAMES := ["gomsol_A_natural", "gomsol_B_umbrella", "gomsol_C_tall_layered", "gomsol_D_windswept", "gomsol_E_young",
	"oak_sangsuri_a", "oak_sangsuri_b", "oak_singal", "oak_broad",
	"willow_a", "willow_b", "persimmon", "chestnut", "zelkova_dangsan", "shrub_oak", "shrub_twig"]
const LEAF_FAM := ["pine", "pine", "pine", "pine", "pine", "oak", "oak", "oak", "oak", "broad2", "broad2", "broad2", "broad2", "broad2", "oak", "broad2"]
const BARK_FAM := ["pine", "pine", "pine", "pine", "pine", "oak", "oak", "oak", "oak", "oak", "oak", "oak", "oak", "oak", "oak", "oak"]
const L_A := 0
const L_B := 1
const L_C := 2
const L_D := 3
const L_E := 4
const L_SANG_A := 5
const L_SANG_B := 6
const L_SINGAL := 7
const L_BROAD := 8
const L_WILLOW_A := 9
const L_WILLOW_B := 10
const L_PERSIMMON := 11
const L_CHESTNUT := 12
const L_ZELKOVA := 13
const L_SHRUB_OAK := 14
const L_SHRUB_TWIG := 15

# 가까운 나무 벌(m, 카메라 → 밑동 수평 거리) — tree_lod.gd가 나무마다 정한다(가까운 순 + 삼각형 예산), 바뀔 때는 시간으로 섞는다(lod_fade 초)
#   LOD0 < r0, LOD1 < r1, 임포스터(tree_lod가 그림) < rh, 그 너머는 흩뿌리기 임포스터 묶음. 그림자: 가까운 순 cap_sh그루(해를 향한 임포스터)
static var r0 := 16.0
static var r1 := 38.0
static var rh := 46.0
static var rs := 40.0
static var budget0 := 140000
static var budget1 := 420000
static var cap_sh := 90
static var lod_fade := 0.35
static var _base := Vector3(14.0, 26.0, 36.0)   # 높음 값(--treelod=r0,r1,rs) — 낮음은 0.62배
static var tris0 := PackedInt32Array()
static var tris1 := PackedInt32Array()

static var _ok = null
static var _mtx := Mutex.new()
static var heights := PackedFloat32Array()
static var _mats := {}       # "fam_part_band" → ShaderMaterial
static var _meshes := {}     # "layer:lod:band" → ArrayMesh
static var imp_mesh: ArrayMesh            # 흩뿌리기 묶음(먼 나무): rh 안은 숨긴다
static var imp_mat: ShaderMaterial
static var imp_near_mesh: ArrayMesh       # tree_lod가 그리는 가까운 임포스터(rh 안)
static var imp_near_mat: ShaderMaterial
static var imp_shadow_mesh: ArrayMesh     # 가까운 나무 그림자 전용: 해를 향해 선 임포스터
static var imp_shadow_mat: ShaderMaterial
static var imp_far_mesh: ArrayMesh        # 먼 숲 층(근경 밖 타일 — region_world far forest)
static var imp_far_mat: ShaderMaterial

static func available() -> bool:
	if _ok == null:
		_ok = FileAccess.file_exists(DIR + "meta.json") and ResourceLoader.exists(DIR + "impostor.tres") and not OS.get_cmdline_user_args().has("--oldtrees")
	return _ok

# 메인 스레드에서 한 번(scatter.warm이 부른다): 재질·임포스터 메시를 만든다
static func init() -> void:
	_mtx.lock()
	var done := not available() or imp_mesh != null
	_mtx.unlock()
	if done: return
	var meta = JSON.parse_string(FileAccess.get_file_as_string(DIR + "meta.json"))
	heights.resize(NAMES.size())
	tris0.resize(NAMES.size()); tris1.resize(NAMES.size())
	for v in meta.variants:
		var i := NAMES.find(String(v.name))
		if i >= 0:
			heights[i] = float(v.height); tris0[i] = int(v.get("tris0", 8000)); tris1[i] = int(v.get("tris1", 2000))
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--treelod="):
			var p := a.substr(10).split(",")
			_base.x = float(p[0]); if p.size() > 1: _base.y = float(p[1])
			if p.size() > 2: _base.z = float(p[2])
	set_low(false)
	_build_mats()
	imp_mat = load(DIR + "impostor.tres")
	# 임포스터 사각(x -0.5~0.5, y 0~1) — 화면 밖 거르기는 가장 큰 나무 틀로(셰이더가 층마다 크기를 정한다)
	var v := PackedVector3Array([Vector3(-0.5, 0, 0), Vector3(0.5, 0, 0), Vector3(0.5, 1, 0), Vector3(-0.5, 1, 0)])
	var uv := PackedVector2Array([Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)])
	var n := PackedVector3Array([Vector3.BACK, Vector3.BACK, Vector3.BACK, Vector3.BACK])
	var arr := []; arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v; arr[Mesh.ARRAY_TEX_UV] = uv; arr[Mesh.ARRAY_NORMAL] = n; arr[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	imp_mesh = ArrayMesh.new()
	imp_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	imp_mesh.surface_set_material(0, imp_mat)
	imp_mesh.custom_aabb = AABB(Vector3(-12, -1, -12), Vector3(24, 27, 24))
	imp_mesh.set_meta("khs", true)
	imp_shadow_mat = imp_mat.duplicate()
	imp_shadow_mat.set_shader_parameter("imp_tilt", 0.0)
	imp_shadow_mesh = imp_mesh.duplicate()
	imp_shadow_mesh.surface_set_material(0, imp_shadow_mat)
	imp_near_mat = imp_mat.duplicate()
	imp_near_mesh = imp_mesh.duplicate()
	imp_near_mesh.surface_set_material(0, imp_near_mat)
	imp_far_mat = imp_mat.duplicate()
	imp_far_mat.set_shader_parameter("imp_fade", Vector2(1150.0, 1300.0))
	imp_far_mesh = imp_mesh.duplicate()
	imp_far_mesh.surface_set_material(0, imp_far_mat)
	_apply_bands()

static func set_low(low: bool) -> void:
	# 화면 품질 낮음: 가까운 벌·예산을 줄인다
	var k := 0.62 if low else 1.0
	r0 = _base.x * k; r1 = _base.y * k; rs = _base.z * k; rh = r1 + 8.0
	budget0 = 40000 if low else 90000
	budget1 = 110000 if low else 200000
	cap_sh = 30 if low else 60
	if imp_mesh != null: _apply_bands()

static func _build_mats() -> void:
	for fam in ["pine", "oak", "broad2"]:
		for part in ["bark", "leaf"]:
			var path := DIR + "%s_%s.tres" % [fam, part]
			if not ResourceLoader.exists(path): continue
			var base: ShaderMaterial = load(path)
			for b in ["mm", "st"]:
				var m: ShaderMaterial = base.duplicate()
				m.set_shader_parameter("lod_band", Vector4(-1, -1, 1e6, 1e6))
				_mats["%s_%s_%s" % [fam, part, b]] = m

# 띠: 흩뿌리기 임포스터는 rh 안을 숨기고(tree_lod 몫), tree_lod 임포스터는 rh 밖을 숨긴다 — 같은 거리 식이라 정확히 갈린다(둘 다 같은 그림)
static func _apply_bands() -> void:
	if imp_mat != null: imp_mat.set_shader_parameter("lod_band", Vector4(rh, rh + 0.01, 1e6, 1e6))
	if imp_near_mat != null: imp_near_mat.set_shader_parameter("lod_band", Vector4(-1, -1, rh, rh + 0.01))
	if imp_shadow_mat != null: imp_shadow_mat.set_shader_parameter("lod_band", Vector4(-1, -1, 1e6, 1e6))

static func mats() -> Array:
	var out := _mats.values()
	for m in [imp_mat, imp_shadow_mat, imp_near_mat, imp_far_mat]:
		if m != null: out.append(m)
	return out

# 메시(층, lod 0|1, 띠) — 띠마다 재질이 달라 메시를 따로 둔다(MultiMesh는 메시 표면 재질을 쓴다)
static func mesh(layer: int, lod: int, band: String) -> ArrayMesh:
	var key := "%d:%d:%s" % [layer, lod, band]
	_mtx.lock()
	var hit = _meshes.get(key)
	_mtx.unlock()
	if hit != null: return hit
	var src: ArrayMesh = load(DIR + "%s_lod%d.res" % [NAMES[layer], lod])
	var m: ArrayMesh = src.duplicate()
	m.surface_set_material(0, _mats["%s_bark_%s" % [BARK_FAM[layer], band]])
	m.surface_set_material(1, _mats["%s_leaf_%s" % [LEAF_FAM[layer], band]])
	_mtx.lock(); _meshes[key] = m; _mtx.unlock()
	return m

# 배치한 나무(키트 build — pine·big_tree·persimmon): LOD0(32m) → LOD1(먼 끝 600m), 그림자는 LOD1. 충돌 원은 부르는 쪽이 넘긴다(예전과 같게)
static func build_static(layer: int, h: float, ry: float, name: String, colliders: Array) -> Dictionary:
	init()
	var k := h / height(layer)
	var root := Node3D.new()
	root.name = name
	var xf := Transform3D(Basis(Vector3.UP, ry).scaled(Vector3(k, k, k)), Vector3.ZERO)
	for i in 3:
		var mi := MeshInstance3D.new()
		mi.name = ["lod0", "shadow", "lod1"][i]
		mi.mesh = mesh(layer, 0 if i == 0 else 1, "st")
		mi.transform = xf
		match i:
			0:
				mi.visibility_range_end = 32.0
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			1:
				mi.visibility_range_end = 80.0
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
			2:
				mi.visibility_range_begin = 32.0
				mi.visibility_range_end = 600.0
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
	var ext := 6.0 * k
	return { node = root, mesh = (root.get_child(2) as MeshInstance3D).mesh, colliders = colliders, lights = [], occluder = false,
		footprint = Vector2(ext * 2, ext * 2), anchors = {}, tris = 0, height = h }

static func height(layer: int) -> float:
	return heights[layer] if layer < heights.size() and heights[layer] > 0.0 else 12.0

# 자리 해시(0~1) — 흩뿌리기 난수를 쓰지 않고 변형·키를 고른다(충돌체·배치 순서를 그대로 두려고)
static func h01(x: float, z: float, salt := 0.0) -> float:
	var s := sin(x * 12.9898 + z * 78.233 + salt * 37.719) * 43758.5453
	return s - floorf(s)

# 소나무 변형 고르기 — 능선: 우산형·바람맞이, 비탈: 층층·자연형, 숲 가: 어린나무, 바닷가: 해송(바람맞이)만
static func pick_pine(x: float, z: float, ridge: bool, edge: bool, coast: bool, slope: float) -> int:
	var u := h01(x, z, 1.0)
	if coast: return L_D if u < 0.7 else L_A
	if ridge: return L_B if u < 0.6 else (L_A if u < 0.88 else L_E)
	if edge: return L_E if u < 0.45 else (L_A if u < 0.8 else L_B)
	if slope > 0.7: return L_C if u < 0.45 else (L_A if u < 0.88 else L_E)
	return L_C if u < 0.42 else (L_A if u < 0.85 else L_E)
