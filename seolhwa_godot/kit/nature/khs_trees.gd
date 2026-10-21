# 사실 나무(trees-khs) 자산 — 곰솔 5종(국가유산청 스캔, 공공누리 1유형 · 출처 "국가유산청") + 참나무 stand-in 4종(ambientCG CC0 잎·껍질).
#   자산: assets/trees/(tools/trees_khs/build.sh가 짓는다) · 셰이더: shaders/tree_*.gdshader
#   쓰는 곳: kit/nature/scatter.gd(숲 흩뿌리기 — 임포스터 MultiMesh), scripts/region/tree_lod.gd(가까운 나무 LOD0/LOD1 MultiMesh), kit/nature/pine.gd(배치한 소나무)
#   층(layer) = 변형 번호 = 임포스터 배열 층 = 아래 NAMES 순서(assets/trees/meta.json과 같다)
extends RefCounted

const DIR := "res://assets/trees/"
const NAMES := ["gomsol_A_natural", "gomsol_B_umbrella", "gomsol_C_tall_layered", "gomsol_D_windswept", "gomsol_E_young",
	"oak_sangsuri_a", "oak_sangsuri_b", "oak_singal", "oak_broad"]
const FAMILY := ["pine", "pine", "pine", "pine", "pine", "oak", "oak", "oak", "oak"]
const L_A := 0
const L_B := 1
const L_C := 2
const L_D := 3
const L_E := 4
const L_SANG_A := 5
const L_SANG_B := 6
const L_SINGAL := 7
const L_BROAD := 8

# 거리 띠(m, 카메라 → 밑동 수평 거리): LOD0 < r0, LOD1 < r1, 그 너머 임포스터. 점무늬로 섞는 폭 f0·f1
static var r0 := 18.0
static var r1 := 42.0
static var f0 := 3.0
static var f1 := 8.0
static var rs := 42.0     # 그림자 드리우는 나무(LOD1 그림자 전용) 거리
static var _base := Vector3(18.0, 42.0, 42.0)   # 높음 값(--treelod=r0,r1,rs로 바꾼다) — 낮음은 이 0.62배

static var _ok = null
static var _mtx := Mutex.new()
static var heights := PackedFloat32Array()
static var _mats := {}       # "fam_part_band" → ShaderMaterial
static var _meshes := {}     # "layer:lod:band" → ArrayMesh
static var imp_mesh: ArrayMesh
static var imp_mat: ShaderMaterial
static var imp_shadow_mesh: ArrayMesh    # 가까운 나무 그림자 전용: 해를 향해 선 임포스터(사각 2삼각형 — LOD1 그림자 2천 삼각형 대신)
static var imp_shadow_mat: ShaderMaterial

static func available() -> bool:
	if _ok == null:
		_ok = FileAccess.file_exists(DIR + "meta.json") and ResourceLoader.exists(DIR + "impostor.tres") and not OS.get_cmdline_user_args().has("--oldtrees")
	return _ok

# 메인 스레드에서 한 번(scatter.warm이 부른다): 재질·임포스터 메시를 만든다
static func init() -> void:
	if not available() or imp_mesh != null: return
	var meta = JSON.parse_string(FileAccess.get_file_as_string(DIR + "meta.json"))
	heights.resize(NAMES.size())
	for v in meta.variants:
		var i := NAMES.find(String(v.name))
		if i >= 0: heights[i] = float(v.height)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--treelod="):
			var p := a.substr(10).split(",")
			_base.x = float(p[0]); if p.size() > 1: _base.y = float(p[1])
			if p.size() > 2: _base.z = float(p[2])
	r0 = _base.x; r1 = _base.y; rs = _base.z
	_build_mats()
	imp_mat = load(DIR + "impostor.tres")
	imp_mat.set_shader_parameter("lod_band", Vector4(r1 - f1, r1, 1e6, 1e6))
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
	_apply_bands()

static func set_low(low: bool) -> void:
	# 화면 품질 낮음: 가까운 벌을 줄인다
	var k := 0.62 if low else 1.0
	r0 = _base.x * k; r1 = _base.y * k; rs = _base.z * k
	if imp_mesh != null: _apply_bands()

static func _band(b: String) -> Vector4:
	match b:
		"l0": return Vector4(-1, -1, r0 - f0, r0)
		"l1": return Vector4(r0 - f0, r0, r1 - f1, r1)
		"sh": return Vector4(-1, -1, rs - 4.0, rs)
	return Vector4(-1, -1, 1e6, 1e6)   # st: 배치한 나무(보이는 거리는 노드가 정한다)

static func _build_mats() -> void:
	for fam in ["pine", "oak"]:
		for part in ["bark", "leaf"]:
			var base: ShaderMaterial = load(DIR + "%s_%s.tres" % [fam, part])
			for b in ["l0", "l1", "sh", "st"]:
				var m: ShaderMaterial = base.duplicate()
				m.set_shader_parameter("lod_band", _band(b))
				_mats["%s_%s_%s" % [fam, part, b]] = m
	_apply_bands()

static func _apply_bands() -> void:
	for k in _mats:
		var b: String = String(k).get_slice("_", 2)
		(_mats[k] as ShaderMaterial).set_shader_parameter("lod_band", _band(b))
	if imp_mat != null: imp_mat.set_shader_parameter("lod_band", Vector4(r1 - f1, r1, 1e6, 1e6))
	if imp_shadow_mat != null: imp_shadow_mat.set_shader_parameter("lod_band", Vector4(-1, -1, rs - 4.0, rs))

static func mats() -> Array:
	var out := _mats.values()
	if imp_mat != null: out.append(imp_mat)
	if imp_shadow_mat != null: out.append(imp_shadow_mat)
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
	var fam: String = FAMILY[layer]
	m.surface_set_material(0, _mats["%s_bark_%s" % [fam, band]])
	m.surface_set_material(1, _mats["%s_leaf_%s" % [fam, band]])
	_mtx.lock(); _meshes[key] = m; _mtx.unlock()
	return m

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
