# 상태 연출(불·연기·김·불티) — 프롭 상태(prop_states.gd)가 키트의 state_fx 목록으로 만든다.
# 입자는 CPUParticles3D(작은 양) + 화면을 보는 사각형 셰이더(키트처럼 안개를 받는다). 노드는 프롭 노드의 자식이라
# 타일 스트리밍(붙였다 떼기)을 그대로 따라간다.
#   spec: { type: "smoke"|"fire"|"steam"|"embers", x, y, z(키트 로컬), size(퍼짐 반지름 m, 기본 0.5), k(양 배율, 기본 1) }
extends RefCounted

static var _shader_mix: Shader
static var _shader_add: Shader
static var _quad: QuadMesh

const CODE := """shader_type spatial;
render_mode unshaded, %s, depth_draw_never, cull_disabled;
global uniform vec3 fog_color;
global uniform float fog_density;
uniform float soft = 1.0;
void vertex() {
	// 입자 화면 보기(크기 유지)
	mat4 mv = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = mv * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
}
void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float d = length(q);
	float n = 0.82 + 0.18 * sin(q.x * 7.0 + q.y * 5.0 + COLOR.r * 20.0);
	float a = smoothstep(1.0, 0.15 * soft, d) * n;
	ALBEDO = COLOR.rgb;
	ALPHA = COLOR.a * a;
	float fd = -VERTEX.z;
	FOG = vec4(fog_color, 1.0 - exp(-fog_density * fog_density * fd * fd));
}
"""

static func _mat(add: bool) -> ShaderMaterial:
	if _shader_mix == null:
		_shader_mix = Shader.new(); _shader_mix.code = CODE % "blend_mix"
		_shader_add = Shader.new(); _shader_add.code = CODE % "blend_add"
		_quad = QuadMesh.new(); _quad.size = Vector2(1, 1)
	var m := ShaderMaterial.new()
	m.shader = _shader_add if add else _shader_mix
	return m

static func _ramp(cols: Array) -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(cols.map(func(c): return c[0]))
	g.colors = PackedColorArray(cols.map(func(c): return c[1]))
	return g

static func _curve(pts: Array) -> Curve:
	var c := Curve.new()
	for p in pts: c.add_point(Vector2(p[0], p[1]))
	return c

static func make(spec: Dictionary) -> Node3D:
	var t: String = spec.get("type", "smoke")
	var k: float = float(spec.get("k", 1.0))
	var r: float = float(spec.get("size", 0.5))
	var p := CPUParticles3D.new()
	p.name = "fx_" + t
	p.position = Vector3(float(spec.get("x", 0.0)), float(spec.get("y", 0.0)), float(spec.get("z", 0.0)))
	p.mesh = null
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = r
	p.direction = Vector3.UP
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	match t:
		"fire":
			p.material_override = _mat(true)
			# 불꽃 하나의 크기는 퍼짐(size)과 따로 — scale(기본 0.7m). 퍼짐이 넓으면 그만큼 많이
			var sc: float = float(spec.get("scale", 0.7))
			p.amount = maxi(6, int(30 * k * clampf(r / 0.6, 1.0, 3.0))); p.lifetime = 0.8
			p.spread = 10.0; p.initial_velocity_min = 1.0; p.initial_velocity_max = 2.2
			p.gravity = Vector3(0.2, 0.8, 0.0)
			p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
			p.emission_box_extents = Vector3(r, 0.15, minf(r, 0.4))
			p.scale_amount_min = 0.5 * sc; p.scale_amount_max = 1.0 * sc
			p.scale_amount_curve = _curve([[0.0, 0.6], [0.25, 1.0], [1.0, 0.15]])
			p.color_ramp = _ramp([[0.0, Color(1.0, 0.8, 0.4, 0.0)], [0.12, Color(1.0, 0.55, 0.16, 0.55)], [0.6, Color(0.85, 0.24, 0.05, 0.35)], [1.0, Color(0.4, 0.1, 0.02, 0.0)]])
		"embers":
			p.material_override = _mat(true)
			p.amount = maxi(4, int(20 * k)); p.lifetime = 2.4
			p.spread = 35.0; p.initial_velocity_min = 1.0; p.initial_velocity_max = 2.4
			p.gravity = Vector3(0.6, 0.4, 0.2)
			p.scale_amount_min = 0.05; p.scale_amount_max = 0.1
			p.color_ramp = _ramp([[0.0, Color(1.0, 0.7, 0.3, 1.0)], [1.0, Color(1.0, 0.3, 0.05, 0.0)]])
		"steam":
			p.material_override = _mat(false)
			p.amount = maxi(3, int(8 * k)); p.lifetime = 2.6
			p.spread = 8.0; p.initial_velocity_min = 0.15; p.initial_velocity_max = 0.3
			p.gravity = Vector3(0.03, 0.05, 0.0)
			p.scale_amount_min = 0.12; p.scale_amount_max = 0.26
			p.scale_amount_curve = _curve([[0.0, 0.4], [1.0, 1.0]])
			p.color_ramp = _ramp([[0.0, Color(1, 1, 1, 0.0)], [0.25, Color(0.96, 0.96, 0.95, 0.28)], [1.0, Color(0.96, 0.96, 0.95, 0.0)]])
		_:   # smoke
			p.material_override = _mat(false)
			p.amount = maxi(6, int(22 * k)); p.lifetime = 7.0
			p.spread = 14.0; p.initial_velocity_min = 0.7; p.initial_velocity_max = 1.4
			p.gravity = Vector3(0.35, 0.12, 0.08)
			p.scale_amount_min = 1.4 * maxf(0.7, r); p.scale_amount_max = 2.6 * maxf(0.7, r)
			p.scale_amount_curve = _curve([[0.0, 0.35], [1.0, 1.0]])
			var dark: float = float(spec.get("dark", 0.3))
			var c := Color(0.42, 0.4, 0.38).lerp(Color(0.12, 0.11, 0.1), dark)
			p.color_ramp = _ramp([[0.0, Color(c.r, c.g, c.b, 0.0)], [0.12, Color(c.r, c.g, c.b, 0.55)], [1.0, Color(c.r * 1.3, c.g * 1.3, c.b * 1.3, 0.0)]])
	var mesh := QuadMesh.new(); mesh.size = Vector2(1, 1)
	p.mesh = mesh
	p.emitting = true
	p.preprocess = p.lifetime * 0.8   # 켜자마자 연기 기둥이 서 있게
	return p
