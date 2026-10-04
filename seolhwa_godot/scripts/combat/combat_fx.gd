# 전투 효과(웹 fx/combat.js 대응) — 먹물 번짐 타격(hit·heavyHit), 막기 불꽃(block), 흙먼지(dust), 칼·앞발 궤적(slash),
# 포효 고리(roar), 바닥 예고(lane: 덮치기 경로, fan: 앞발 부채꼴), 공격 범위(ring). 바닥 표시는 지형 높이를 따라 깐다.
# spawn(type, x, z, opts) → 핸들(Dictionary). remove(h)로 지운다. 모두 셰이더로 그린다(텍스처 없음).
extends Node3D

var height_at: Callable      # (x, z) → y
var _live: Array = []
static var _shaders := {}

const INK := Color("#1a1512")
const RED := Color("#8e2c20")
const PAPER := Color("#f3ead6")

const GROUND_CODE := """shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;
uniform vec4 col : source_color = vec4(0.55, 0.17, 0.12, 1.0);
uniform vec4 edge_col : source_color = vec4(0.1, 0.08, 0.07, 1.0);
uniform float progress = 0.0;
uniform float alpha = 1.0;
uniform int mode = 0;   // 0 예고(lane/fan) 1 범위 고리 2 포효 고리 3 칼 궤적
uniform float seed = 0.0;
float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vn(vec2 p) { vec2 i = floor(p), f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), f.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), f.x), f.y); }
void fragment() {
	vec2 uv = UV;
	float n = vn(uv * vec2(14.0, 7.0) + seed) * 0.6 + vn(uv * vec2(40.0, 20.0) + seed * 3.0) * 0.4;
	float a = 0.0; vec3 c = col.rgb;
	if (mode == 0) {
		float e = min(min(uv.y, 1.0 - uv.y), 1.0 - uv.x);
		float rim = 1.0 - smoothstep(0.02, 0.07 + 0.04 * n, e);
		float fill = step(uv.x, progress) * (0.28 + 0.2 * n);
		a = max(rim * 0.85, fill) * (0.7 + 0.3 * n);
		c = mix(col.rgb, edge_col.rgb, rim * 0.5);
	} else if (mode == 1) {
		float e = abs(uv.x - 0.5) * 2.0;
		a = (1.0 - smoothstep(0.4, 1.0, e)) * 0.6 * (0.6 + 0.4 * n);
	} else if (mode == 2) {
		float e = abs(uv.x - 0.5) * 2.0;
		a = (1.0 - smoothstep(0.2 + 0.3 * n, 1.0, e)) * 0.8;
		c = mix(edge_col.rgb, col.rgb, n);
	} else {
		// 칼 궤적: 바깥쪽이 진하고 안쪽으로 번지며, 휘두른 쪽(v ≤ progress)만 보인다
		float sweep = 1.0 - smoothstep(progress - 0.25, progress, uv.y);
		float rad = smoothstep(0.0, 0.75, uv.x) * (1.0 - smoothstep(0.92, 1.0, uv.x));
		a = sweep * rad * (0.55 + 0.45 * n);
		float ink = smoothstep(0.8, 0.97, uv.x);
		c = mix(col.rgb, edge_col.rgb, ink);
	}
	ALBEDO = c;
	ALPHA = clamp(a * alpha, 0.0, 1.0);
}
"""

const SPLASH_CODE := """shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;
uniform vec4 col : source_color = vec4(0.1, 0.08, 0.07, 1.0);
uniform float age = 0.0;
uniform float seed = 0.0;
uniform int kind = 0;   // 0 먹물 번짐 1 큰 번짐 2 불꽃 3 흙먼지
float h11(float x) { return fract(sin(x * 91.3458) * 47453.5453); }
float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vn(vec2 p) { vec2 i = floor(p), f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), f.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), f.x), f.y); }
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0, 0, 0), vec4(0, length(MODEL_MATRIX[1].xyz), 0, 0), vec4(0, 0, 1, 0), vec4(0, 0, 0, 1));
}
void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	float ang = atan(p.y, p.x);
	float a = 0.0;
	if (kind == 2) {
		float star = pow(abs(cos(ang * 4.0 + seed)), 12.0) * (1.0 - age) + 0.25;
		a = (1.0 - smoothstep(star * 0.4, star * 0.95, r)) * (1.0 - age);
	} else if (kind == 3) {
		float n = vn(p * 3.0 + seed + age * 2.0);
		a = (1.0 - smoothstep(0.3 + 0.4 * age, 0.9, r + 0.25 * n)) * 0.45 * (1.0 - age);
	} else {
		float grow = 0.35 + 0.65 * (1.0 - pow(1.0 - min(age * 3.0, 1.0), 3.0));
		float edge = 0.42 + 0.22 * vn(vec2(ang * 2.2 + seed, seed)) + 0.14 * vn(vec2(ang * 7.0, seed * 2.0));
		float body = 1.0 - smoothstep(edge * grow - 0.04, edge * grow, r);
		// 튄 방울: 각도마다 바깥 작은 점
		float drops = 0.0;
		for (int i = 0; i < 7; i++) {
			float fi = float(i);
			float da = h11(seed + fi) * 6.2832;
			float dr = (0.55 + 0.4 * h11(seed * 2.0 + fi)) * grow;
			vec2 c = vec2(cos(da), sin(da)) * dr;
			drops = max(drops, 1.0 - smoothstep(0.03, 0.07 + 0.04 * h11(fi + seed * 3.0), length(p - c)));
		}
		if (kind == 1) {
			float streak = pow(abs(cos(ang * 3.0 + seed)), 30.0) * (1.0 - smoothstep(0.2, 1.0, r));
			body = max(body, streak * grow);
		}
		float fade = 1.0 - smoothstep(0.55, 1.0, age);
		float grain = 0.75 + 0.25 * vn(p * 9.0 + seed);
		a = max(body, drops) * fade * grain;
	}
	ALBEDO = col.rgb;
	ALPHA = clamp(a, 0.0, 1.0);
}
"""

static func _shader(name: String, code: String) -> Shader:
	if not _shaders.has(name):
		var s := Shader.new(); s.code = code; _shaders[name] = s
	return _shaders[name]

func _h(x: float, z: float) -> float:
	return height_at.call(x, z) if height_at.is_valid() else 0.0

func spawn(type: String, x: float, z: float, o: Dictionary = {}) -> Dictionary:
	var h := {}
	match type:
		"hit", "heavyHit", "block", "dust":
			h = _splash(type, x, z, o)
		"lane":
			var d: Vector2 = o.get("dir", Vector2(0, 1))
			h = _ground_lane(x, z, d, float(o.get("length", 8.0)), float(o.get("width", 1.7)), RED)
			h.dur = float(o.get("duration", 0.8)); h.fill = true; h.hold = true
		"fan":
			var d: Vector2 = o.get("dir", Vector2(0, 1))
			h = _ground_fan(x, z, d, float(o.get("radius", 3.0)), deg_to_rad(float(o.get("arc", 110.0))), 0.0, 0.05, RED, 0)
			h.dur = float(o.get("duration", 0.4)); h.fill = true; h.hold = true
		"ring":
			h = _ground_fan(x, z, Vector2(0, 1), float(o.get("radius", 2.0)) + 0.08, TAU, float(o.get("radius", 2.0)) - 0.08, 0.05, PAPER, 1)
			h.dur = float(o.get("duration", 0.5))
		"roar":
			var rr := float(o.get("radius", 4.0))
			h = _ground_fan(x, z, Vector2(0, 1), 1.0, TAU, 0.75, 0.08, Color("#5a4a3a"), 2, true)
			h.dur = 0.65; h.grow = rr
		"slash":
			var d: Vector2 = o.get("dir", Vector2(0, 1))
			var tiger: bool = o.get("tiger", false)
			var c := Color("#f6efe0") if not tiger else Color("#c9452f")
			h = _ground_fan(x, z, d, float(o.get("radius", 2.0)), deg_to_rad(float(o.get("arc", 110.0))), float(o.get("radius", 2.0)) * 0.35,
				float(o.get("height", 0.9)), c, 3, false, bool(o.get("flip", false)))
			h.dur = 0.22 if not o.get("heavy", false) else 0.3; h.sweep = true
		_:
			return {}
	h.type = type; h.age = 0.0
	_live.append(h)
	return h

func remove(h) -> void:
	if not (h is Dictionary) or h.is_empty(): return
	if h.has("node") and is_instance_valid(h.node): h.node.queue_free()
	_live.erase(h)

func clear() -> void:
	for h in _live:
		if is_instance_valid(h.node): h.node.queue_free()
	_live.clear()

func update(dt: float) -> void:
	var i := _live.size() - 1
	while i >= 0:
		var h: Dictionary = _live[i]
		h.age += dt
		var u: float = h.age / maxf(0.001, h.dur)
		var m: ShaderMaterial = h.mat
		if h.get("splash", false):
			m.set_shader_parameter("age", minf(u, 1.0))
			var s: float = h.size * (1.0 + 0.25 * minf(u, 1.0))
			h.node.scale = Vector3(s, s, 1)
		elif h.get("fill", false):
			m.set_shader_parameter("progress", minf(u, 1.0))
		elif h.get("sweep", false):
			m.set_shader_parameter("progress", minf(u * 2.4, 1.25))
			m.set_shader_parameter("alpha", 1.0 - smoothstep(0.55, 1.0, u))
		elif h.has("grow"):
			var s: float = lerpf(0.4, float(h.grow), 1.0 - pow(1.0 - minf(u, 1.0), 2.0))
			h.node.scale = Vector3(s, 1, s)
			m.set_shader_parameter("alpha", 1.0 - u)
		else:
			m.set_shader_parameter("alpha", 1.0 - smoothstep(0.6, 1.0, u))
		# 예고는 주인이 지울 때까지(최대 dur + 0.3초) 남긴다
		var life: float = h.dur + (0.3 if h.get("hold", false) else 0.0)
		if h.age >= life:
			if is_instance_valid(h.node): h.node.queue_free()
			_live.remove_at(i)
		i -= 1

# ---- 그리기 ----
func _splash(type: String, x: float, z: float, o: Dictionary) -> Dictionary:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new(); q.size = Vector2.ONE
	mi.mesh = q
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := ShaderMaterial.new(); m.shader = _shader("splash", SPLASH_CODE)
	m.render_priority = 2
	var kind := 0; var size := 1.3; var dur := 0.45; var col := INK; var lift := 1.0
	match type:
		"heavyHit": kind = 1; size = 2.0; dur = 0.55
		"block": kind = 2; size = 1.1; dur = 0.22; col = Color("#fff1c0")
		"dust": kind = 3; size = 1.4; dur = 0.55; col = Color("#8a7458"); lift = 0.35
	size *= float(o.get("scale", 1.0))
	m.set_shader_parameter("col", col)
	m.set_shader_parameter("kind", kind)
	m.set_shader_parameter("seed", randf() * 100.0)
	mi.material_override = m
	add_child(mi)
	mi.global_position = Vector3(x, _h(x, z) + lift * (1.0 if type != "dust" else float(o.get("scale", 1.0))), z)
	mi.scale = Vector3(size, size, 1)
	return { node = mi, mat = m, dur = dur, splash = true, size = size }

func _material(mode: int, col: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new(); m.shader = _shader("ground", GROUND_CODE)
	m.set_shader_parameter("col", col)
	m.set_shader_parameter("mode", mode)
	m.set_shader_parameter("seed", randf() * 50.0)
	m.render_priority = 1
	return m

func _finish_mesh(v: PackedVector3Array, uv: PackedVector2Array, idx: PackedInt32Array, m: ShaderMaterial, origin: Vector3) -> Dictionary:
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v; arr[Mesh.ARRAY_TEX_UV] = uv; arr[Mesh.ARRAY_INDEX] = idx
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mi := MeshInstance3D.new()
	mi.mesh = am
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.global_position = origin
	return { node = mi, mat = m }

# 덮치기 경로: 길이 방향 u, 폭 방향 v
func _ground_lane(x: float, z: float, d: Vector2, length: float, width: float, col: Color) -> Dictionary:
	var nl := maxi(4, int(length / 0.5)); var nw := 3
	var side := Vector2(-d.y, d.x)
	var o := Vector3(x, 0, z)
	var v := PackedVector3Array(); var uv := PackedVector2Array(); var idx := PackedInt32Array()
	for i in nl + 1:
		for j in nw + 1:
			var u := float(i) / nl; var w := float(j) / nw
			var p := Vector2(x, z) + d * (u * length) + side * ((w - 0.5) * width)
			v.append(Vector3(p.x - x, _h(p.x, p.y) + 0.06, p.y - z)); uv.append(Vector2(u, w))
	for i in nl:
		for j in nw:
			var a := i * (nw + 1) + j
			idx.append_array([a, a + nw + 1, a + 1, a + 1, a + nw + 1, a + nw + 2])
	return _finish_mesh(v, uv, idx, _material(0, col), o)

# 부채꼴/고리: u = 반지름 방향(r0→r), v = 각 방향. local=true면 원점 기준 단위 크기(커지는 고리)
func _ground_fan(x: float, z: float, d: Vector2, r: float, arc: float, r0: float, lift: float, col: Color, mode: int, local := false, flip := false) -> Dictionary:
	var na := maxi(6, int(arc / 0.12)); var nr := 4
	var a0 := atan2(d.y, d.x) - arc * 0.5
	var v := PackedVector3Array(); var uv := PackedVector2Array(); var idx := PackedInt32Array()
	var base_y := _h(x, z)
	for i in na + 1:
		for j in nr + 1:
			var t := float(i) / na; var s := float(j) / nr
			var ang := a0 + arc * t
			var rr := lerpf(r0, r, s)
			var p := Vector2(cos(ang), sin(ang)) * rr
			var y := lift
			if not local: y += _h(x + p.x, z + p.y) - base_y
			v.append(Vector3(p.x, y, p.y)); uv.append(Vector2(s, (1.0 - t) if flip else t))
	for i in na:
		for j in nr:
			var a := i * (nr + 1) + j
			idx.append_array([a, a + nr + 1, a + 1, a + 1, a + nr + 1, a + nr + 2])
	var m := _material(mode, col)
	if mode == 3: m.set_shader_parameter("edge_col", INK)
	return _finish_mesh(v, uv, idx, m, Vector3(x, base_y, z))

# ---- 화살·떡 메시(먹선 느낌의 간단한 모양) ----
static func make_arrow_mesh() -> Node3D:
	var root := Node3D.new()
	var mat := StandardMaterial3D.new(); mat.albedo_color = Color("#3a2c22"); mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var shaft := MeshInstance3D.new()
	var bm := BoxMesh.new(); bm.size = Vector3(0.035, 0.035, 0.85); shaft.mesh = bm; shaft.material_override = mat
	root.add_child(shaft)
	var head := MeshInstance3D.new()
	var pm := PrismMesh.new(); pm.size = Vector3(0.09, 0.14, 0.02); head.mesh = pm; head.material_override = mat
	head.rotation = Vector3(PI / 2, 0, 0); head.position = Vector3(0, 0, 0.47)
	root.add_child(head)
	var fl := MeshInstance3D.new()
	var fm := BoxMesh.new(); fm.size = Vector3(0.1, 0.01, 0.16); fl.mesh = fm
	var wm := StandardMaterial3D.new(); wm.albedo_color = Color("#efe6d2"); wm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fl.material_override = wm; fl.position = Vector3(0, 0, -0.38)
	root.add_child(fl)
	return root

static func make_bait_mesh() -> Node3D:
	var root := Node3D.new()
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new(); cm.top_radius = 0.09; cm.bottom_radius = 0.1; cm.height = 0.07; cm.radial_segments = 10
	mi.mesh = cm
	var mat := StandardMaterial3D.new(); mat.albedo_color = Color("#f2ece0"); mat.roughness = 1.0
	mi.material_override = mat
	root.add_child(mi)
	return root
