# 가까운 풀잎(material-lighting 2차) — 사실 쪽(--look=real)에서만. look.gd가 하나 만든다.
#   카메라가 보는 자리(플레이어 · 1인칭이면 눈앞) 둘레 R m 격자에 풀 포기(잎 6장)를 MultiMesh로 깔고, 자리·높이·풀 덮임은
#   셰이더(shaders/grass.gdshader)가 땅 셰이더와 같은 식으로 정한다 — CPU는 노드를 격자 간격 단위로 옮기고 지형 재질 값을 베낄 뿐.
#   화면 품질 낮음: 반경·밀도를 줄인다. 실내 공간·배 위에서는 끈다.
extends MultiMeshInstance3D

const BLADES := 6
var main
var spacing := 0.33
var radius := 24.0
var _mat: ShaderMaterial
var _copy_t := 0
const PARAMS := ["hmap", "lumap", "h_meta", "h_range", "h_size", "lu_meta", "lu_size", "detail_amp", "paint_tex", "dress_tex", "dress_on",
	"farm_tex", "farm_meta", "farm_size", "farm_on", "noise_tex", "urban_ground"]

# 성능 풀이: 두 벌 — 안쪽(초점에서 정사각 INNER m 안)은 촘촘히, 바깥 고리는 1.42배 성기게(포기 퍼짐을 그만큼 넓혀 덮임은 같다).
#   바깥 고리는 카메라에서 멀어 포기 하나하나가 읽히지 않는다 · --grass1 예전 한 벌
const INNER := 12.0
const OUTER_K := 1.42
var _mats: Array = []
var _outer: MultiMeshInstance3D = null
var _sp_out := 0.0

func setup(m) -> void:
	main = m
	name = "Grass"
	var low: bool = main.gfx_low()
	spacing = 0.42 if low else 0.33
	radius = 14.0 if low else 22.0
	if main.args.has("grassr"): radius = float(main.args.grassr)
	var two: bool = not main.args.has("grass1") and radius > INNER + 4.0
	var mesh := _clump_mesh()
	_mat = _new_mat(spacing, 0.0, 1.0)
	var half_in: float = INNER + spacing if two else radius
	if two: _mat.set_shader_parameter("cut", INNER)
	multimesh = _grid(mesh, spacing, half_in, 0.0)
	material_override = _mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	custom_aabb = AABB(Vector3(-radius - 2.0, -2000.0, -radius - 2.0), Vector3(radius * 2.0 + 4.0, 4000.0, radius * 2.0 + 4.0))
	var n_all := multimesh.instance_count
	if two:
		_sp_out = spacing * OUTER_K
		var om := _new_mat(_sp_out, INNER, OUTER_K)
		_outer = MultiMeshInstance3D.new()
		_outer.name = "GrassOuter"
		_outer.multimesh = _grid(mesh, _sp_out, radius, INNER - _sp_out)
		_outer.material_override = om
		_outer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_outer.custom_aabb = custom_aabb
		_outer.top_level = true
		add_child(_outer)
		n_all += _outer.multimesh.instance_count
	print("GRASS instances=%d spacing=%.2f radius=%.0f rings=%d" % [n_all, spacing, radius, 2 if two else 1])

func _new_mat(sp: float, inner: float, wide: float) -> ShaderMaterial:
	var mt := ShaderMaterial.new()
	mt.shader = load("res://shaders/grass.gdshader")
	mt.set_shader_parameter("spacing", sp)
	mt.set_shader_parameter("radius", radius)
	mt.set_shader_parameter("inner", inner)
	mt.set_shader_parameter("wide", wide)
	_mats.append(mt)
	return mt

# 격자 포기: 반 너비 half 안, 정사각 skip 안(바깥 고리의 구멍)은 뺀다
func _grid(mesh: Mesh, sp: float, half: float, skip: float) -> MultiMesh:
	var n := int(ceil(half * 2.0 / sp))
	var h := (n - 1) * 0.5
	var pts := []
	for j in n:
		for i in n:
			var x := (i - h) * sp; var z := (j - h) * sp
			if skip > 0.0 and absf(x) < skip and absf(z) < skip: continue
			pts.append(Vector3(x, 0.0, z))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = pts.size()
	for k in pts.size(): mm.set_instance_transform(k, Transform3D(Basis(), pts[k]))
	return mm

# 포기 하나: 잎 BLADES장, 잎마다 3단(뿌리·가운데·끝 한 점). VERTEX.xz = 퍼짐(m, 포기 크기 1일 때), y = 높이 비율, UV.y = 잎 위 자리, COLOR.r = 잎 난수
func _clump_mesh() -> ArrayMesh:
	var rng := RandomNumberGenerator.new(); rng.seed = 7
	var v := PackedVector3Array(); var uv := PackedVector2Array(); var col := PackedColorArray(); var idx := PackedInt32Array()
	for k in BLADES:
		var a := TAU * k / BLADES + rng.randf_range(-0.5, 0.5)
		var d := Vector2(cos(a), sin(a)); var side := Vector2(-d.y, d.x)
		var lean := rng.randf_range(0.08, 0.26)
		var hk := rng.randf_range(0.6, 1.0)
		var w := rng.randf_range(0.012, 0.02)
		var r := rng.randf()
		var base := v.size()
		var off := d * rng.randf_range(0.0, 0.07)
		for t: float in [0.0, 0.45, 0.8]:
			var c: Vector2 = off + d * lean * pow(t, 1.5)
			var ww: float = w * (1.0 - t * 0.85)
			for s: float in [-1.0, 1.0]:
				var q: Vector2 = c + side * ww * s
				v.append(Vector3(q.x, t * hk, q.y)); uv.append(Vector2(s, t)); col.append(Color(r, 0, 0))
		var tip := off + d * lean
		v.append(Vector3(tip.x, hk, tip.y)); uv.append(Vector2(0, 1)); col.append(Color(r, 0, 0))
		for q in [[0, 1, 3], [0, 3, 2], [2, 3, 5], [2, 5, 4], [4, 5, 6]]:
			idx.append(base + q[0]); idx.append(base + q[1]); idx.append(base + q[2])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v; arr[Mesh.ARRAY_TEX_UV] = uv; arr[Mesh.ARRAY_COLOR] = col; arr[Mesh.ARRAY_INDEX] = idx
	var normals := PackedVector3Array(); normals.resize(v.size()); normals.fill(Vector3.UP)
	arr[Mesh.ARRAY_NORMAL] = normals
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return am

func _process(_dt: float) -> void:
	if main == null or main.world == null: return
	var w = main.world
	var off: bool = w.indoor != null or w.mat_near == null or main.rig.sailing
	visible = not off
	if off: return
	_copy_t -= 1
	if _copy_t <= 0:
		_copy_t = 20
		for p in PARAMS:
			var val = w.mat_near.get_shader_parameter(p)
			for mt in _mats:
				if val != null and mt.get_shader_parameter(p) != val: mt.set_shader_parameter(p, val)
	var f: Vector3 = main.player_pos
	if main.fp_view(): f = main.cam.global_position - main.cam.global_transform.basis.z * radius * 0.55
	for mt in _mats: mt.set_shader_parameter("focus", f)
	global_position = Vector3(roundf(f.x / spacing) * spacing, 0.0, roundf(f.z / spacing) * spacing)
	if _outer != null: _outer.global_position = Vector3(roundf(f.x / _sp_out) * _sp_out, 0.0, roundf(f.z / _sp_out) * _sp_out)
