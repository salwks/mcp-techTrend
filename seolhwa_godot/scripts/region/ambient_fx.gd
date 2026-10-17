# 바깥 기운(visual-pass 4단계, 2026-10-17) — 가벼운 GPU 알갱이와 반짝이 몇 가지. 한지·먹 결: 성기고 무르고 옅게(번들거리지 않게).
#   ① 볕 먼지(낮 맑음, 플레이어 둘레) ② 달릴 때 발밑 흙먼지(흙길·마당) ③ 굴뚝 연기(사람 사는 집 — 아침·저녁 밥때 짙고 낮엔 옅게, 밤엔 거의 없음)
#   ④ 바람에 날리는 잎(바람 세기·방향을 따름) ⑤ 물 반짝임(내·나루 물 위, 낮) ⑥ 반딧불(해 질 녘~밤, 물가, 맑음·흐림)
# 끄기: --nofx. 설정 '화면 품질' 낮음이면 알갱이 수를 반으로, 볕 먼지·반딧불은 끈다. 실내·배·말 위·1인칭 컷에서도 그대로 돈다(실내는 끈다).
# 성능: 알갱이 합 ≈ 600 이하, 그리기 6~10번. 굴뚝은 가까운 4채만(연기 알갱이 풀을 옮겨 단다).
extends Node3D

const SMOKE_N := 4
const SPARKLE_N := 56

var main      # region_main
var world
var weather
var low := false
var _motes: GPUParticles3D
var _dust: GPUParticles3D
var _leaves: GPUParticles3D
var _flies: GPUParticles3D
var _smoke := []          # GPUParticles3D 풀
var _smoke_at := []       # 각 풀이 달린 굴뚝 자리
var _chimneys := []       # Vector3(배치 로더가 준 굴뚝 자리)
var _spark: MultiMeshInstance3D
var _spark_pts := []      # 물 위 반짝이 자리
var _spark_t := 0.0
var _scan_t := 0.0
var _smoke_scan := 0.0
var _water_c := Vector3(INF, 0, INF)
var stats := { smoke = 0, sparkle = 0, flies = false }

const PART_CODE := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 tint : source_color = vec4(1.0);
uniform float shape = 0.0;   // 0 둥근 점 · 1 잎(긴 둥근꼴) · 2 연기(잡음 덩이)
uniform float glow = 0.0;    // 반딧불: 빛(톤매핑 전 밝게)
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
global uniform vec3 fog_color;
global uniform float fog_density;
varying float v_seed;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	float a = INSTANCE_CUSTOM.x * 6.2832 + TIME * (shape > 0.5 && shape < 1.5 ? 2.0 * (INSTANCE_CUSTOM.y - 0.5) : 0.0);
	VERTEX.xy = mat2(vec2(cos(a), sin(a)), vec2(-sin(a), cos(a))) * VERTEX.xy;
	v_seed = INSTANCE_CUSTOM.y;
}
void fragment() {
	vec2 q = UV - 0.5;
	float m;
	if (shape < 0.5) m = 1.0 - smoothstep(0.15, 0.5, length(q));
	else if (shape < 1.5) m = 1.0 - smoothstep(0.38, 0.5, length(q * vec2(1.0, 2.4)));
	else {
		float n = texture(noise_tex, UV * 0.6 + vec2(v_seed * 3.1, TIME * 0.02)).r;
		m = (1.0 - smoothstep(0.05, 0.5, length(q))) * mix(0.35, 1.0, smoothstep(0.3, 0.7, n));
	}
	float fd = -VERTEX.z;
	float fog_f = 1.0 - exp(-fog_density * fog_density * fd * fd);
	vec3 c = tint.rgb * COLOR.rgb;
	if (shape > 0.5 && shape < 1.5) c = mix(c, vec3(0.45, 0.55, 0.22), step(0.6, v_seed)) * (0.85 + 0.3 * fract(v_seed * 7.7));   // 잎: 누런 잎·푸른 잎 섞기
	ALBEDO = mix(c * (1.0 + glow * 4.0), fog_color, fog_f * (1.0 - glow));
	ALPHA = clamp(tint.a * COLOR.a * m, 0.0, 1.0);
}
"""

const SPARK_CODE := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform float k = 1.0;   // 낮 세기(해 높이·구름)
varying float v_h;
void vertex() { v_h = fract(sin(float(INSTANCE_ID) * 12.9898) * 43758.5453); }
void fragment() {
	float h = v_h;
	float tw = pow(max(sin(TIME * (1.3 + h * 1.7) + h * 40.0), 0.0), 3.0);
	vec2 q = UV - 0.5;
	float m = (1.0 - smoothstep(0.0, 0.5, abs(q.x) * 2.0)) * (1.0 - smoothstep(0.0, 0.5, abs(q.y)));
	ALBEDO = vec3(1.0, 0.97, 0.88) * m * tw * k * 0.9;
}
"""

var _dbg := OS.has_environment("FXDEBUG")
var _part_shader: Shader
var _noise: Texture2D

func setup(m) -> void:
	main = m; world = m.world; weather = m.weather
	name = "ambient_fx"
	_part_shader = Shader.new(); _part_shader.code = PART_CODE
	_noise = world._noise_texture()
	_motes = _make(90, 9.0, _proc_box(Vector3(14, 3.5, 12), Vector3(0, 0.05, 0), Vector3(0.12, 0.08, 0.12), 0.06, 0.12), _mat(Color(1.0, 0.95, 0.8, 0.45), 0, 0.15), Vector2(0.12, 0.12))
	_dust = _make(28, 1.1, _proc_dust(), _mat(Color(0.74, 0.64, 0.48, 0.32), 2), Vector2(0.9, 0.9))
	_dust.emitting = false
	_leaves = _make(26, 7.0, _proc_box(Vector3(16, 4, 14), Vector3(0, -0.6, 0), Vector3(0.6, 0.3, 0.6), 0.9, 1.0), _mat(Color(0.82, 0.62, 0.28, 0.9), 1), Vector2(0.24, 0.24))
	_flies = _make(26, 4.0, _proc_box(Vector3(9, 1.2, 9), Vector3(0, 0.1, 0), Vector3(0.25, 0.15, 0.25), 0.5, 0.8), _mat(Color(0.85, 1.0, 0.55, 0.9), 0, 1.0), Vector2(0.07, 0.07))
	_flies.emitting = false
	for i in SMOKE_N:
		var s := _make(14, 7.0, _proc_smoke(), _mat(Color(0.78, 0.77, 0.74, 0.42), 2), Vector2(1.8, 1.8))
		s.emitting = false
		_smoke.append(s); _smoke_at.append(Vector3(INF, 0, INF))
	# 물 반짝이: 가로로 긴 작은 빛 획(MultiMesh)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var q := QuadMesh.new(); q.size = Vector2(0.55, 0.18)
	mm.mesh = q
	mm.instance_count = SPARKLE_N
	mm.visible_instance_count = 0
	_spark = MultiMeshInstance3D.new(); _spark.multimesh = mm
	_spark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var sm := ShaderMaterial.new(); var sh := Shader.new(); sh.code = SPARK_CODE; sm.shader = sh
	_spark.material_override = sm
	_spark.custom_aabb = AABB(Vector3(-1e4, -1e3, -1e4), Vector3(2e4, 2e3, 2e4))
	add_child(_spark)

func set_chimneys(pts: Array) -> void:
	_chimneys = pts

func _mat(c: Color, shape: int, glow := 0.0) -> ShaderMaterial:
	var m := ShaderMaterial.new(); m.shader = _part_shader
	m.set_shader_parameter("tint", c); m.set_shader_parameter("shape", float(shape)); m.set_shader_parameter("glow", glow)
	if _noise != null: m.set_shader_parameter("noise_tex", _noise)
	return m

func _ramp(a_in := 0.2, a_out := 0.7) -> GradientTexture1D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, a_in, a_out, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0.8), Color(1, 1, 1, 0)])
	var t := GradientTexture1D.new(); t.gradient = g
	return t

func _proc_box(ext: Vector3, grav: Vector3, vel: Vector3, s0: float, s1: float) -> ParticleProcessMaterial:
	var p := ParticleProcessMaterial.new()
	p.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	p.emission_box_extents = ext
	p.direction = Vector3(1, 0.2, 0.3); p.spread = 180.0
	p.initial_velocity_min = vel.length() * 0.3; p.initial_velocity_max = vel.length()
	p.gravity = grav
	p.turbulence_enabled = true; p.turbulence_noise_strength = 0.6; p.turbulence_noise_scale = 3.0; p.turbulence_influence_min = 0.05; p.turbulence_influence_max = 0.15
	p.scale_min = s0; p.scale_max = s1
	p.color_ramp = _ramp(0.15, 0.75)
	return p

func _proc_dust() -> ParticleProcessMaterial:
	var p := ParticleProcessMaterial.new()
	p.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE; p.emission_sphere_radius = 0.18
	p.direction = Vector3(0, 1, 0); p.spread = 70.0
	p.initial_velocity_min = 0.3; p.initial_velocity_max = 0.8
	p.gravity = Vector3(0, -0.4, 0)
	p.damping_min = 1.5; p.damping_max = 2.5
	p.scale_min = 0.45; p.scale_max = 1.0
	var sc := Curve.new(); sc.add_point(Vector2(0, 0.4)); sc.add_point(Vector2(1, 1.3))
	var st := CurveTexture.new(); st.curve = sc; p.scale_curve = st
	p.color_ramp = _ramp(0.1, 0.4)
	return p

func _proc_smoke() -> ParticleProcessMaterial:
	var p := ParticleProcessMaterial.new()
	p.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE; p.emission_sphere_radius = 0.12
	p.direction = Vector3(0, 1, 0); p.spread = 12.0
	p.initial_velocity_min = 0.45; p.initial_velocity_max = 0.7
	p.gravity = Vector3(0.25, 0.12, 0.05)
	p.damping_min = 0.1; p.damping_max = 0.2
	p.scale_min = 0.6; p.scale_max = 0.9
	var sc := Curve.new(); sc.add_point(Vector2(0, 0.4)); sc.add_point(Vector2(1, 2.6))
	var st := CurveTexture.new(); st.curve = sc; p.scale_curve = st
	p.angle_min = 0.0; p.angle_max = 360.0
	p.color_ramp = _ramp(0.15, 0.55)
	return p

func _make(n: int, life: float, pm: ParticleProcessMaterial, mat: ShaderMaterial, size: Vector2) -> GPUParticles3D:
	var g := GPUParticles3D.new()
	g.amount = maxi(4, n / 2 if low else n)
	g.lifetime = life
	g.process_material = pm
	g.local_coords = false
	g.preprocess = life * 0.5
	g.fixed_fps = 30   # 알갱이 계산은 초당 30번(프레임마다 할 만큼 빠르지 않다)
	g.interpolate = true
	g.visibility_aabb = AABB(Vector3(-40, -10, -40), Vector3(80, 30, 80))
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var q := QuadMesh.new(); q.size = size; q.material = mat
	g.draw_pass_1 = q
	add_child(g)
	return g

# 매 프레임(region_main): 플레이어 자리·시각·날씨·실내 여부
func update(dt: float, player: Vector3, hour: float, running: bool, indoor: bool) -> void:
	var h := fposmod(hour, 24.0)
	var kind: String = weather.kind if weather != null else "clear"
	var cur: Dictionary = weather.cur if weather != null else { cloud = 0.0, rain = 0.0, snowfall = 0.0, wind = 0.1 }
	var wet: bool = float(cur.get("rain", 0.0)) > 0.15 or float(cur.get("snowfall", 0.0)) > 0.15
	var day := smoothstep(6.0, 8.0, h) * (1.0 - smoothstep(17.0, 18.5, h))
	var sunny := day * (1.0 - float(cur.get("cloud", 0.0)))
	var out := not indoor
	# ① 볕 먼지
	_motes.global_position = player + Vector3(0, 2.0, 0)
	_motes.emitting = out and not low and sunny > 0.4 and not wet
	# ② 발밑 흙먼지: 달리고, 흙길·마당이고, 젖지 않았을 때
	_dust.global_position = player + Vector3(0, 0.12, 0)
	var dirt: bool = world.has_method("road_distance") and world.road_distance(player.x, player.z) < 0.6
	if not dirt and world.get("pbytes") != null: dirt = _yard_dirt(player)
	_dust.emitting = out and running and dirt and not wet and float(weather.snow if weather != null else 0.0) < 0.3
	# ④ 날리는 잎: 바람 따라(맑음 바람 0.1에도 조금, 강풍엔 많이)
	var wind := float(cur.get("wind", 0.1))
	var wd: Vector2 = weather.get("_wind_dir") if weather != null and weather.get("_wind_dir") != null else Vector2(1, 0.3)
	var lp := _leaves.process_material as ParticleProcessMaterial
	lp.gravity = Vector3(wd.x * (0.4 + 3.0 * wind), -0.55, wd.y * (0.4 + 3.0 * wind))
	_leaves.global_position = player + Vector3(-wd.x * 4.0, 5.0, -wd.y * 4.0)
	_leaves.emitting = out and float(cur.get("snowfall", 0.0)) < 0.2 and float(cur.get("rain", 0.0)) < 0.5
	_leaves.amount_ratio = clampf(0.35 + wind * 1.5, 0.0, 1.0)
	# ③ 굴뚝 연기: 가까운 굴뚝 4개에 풀을 옮겨 단다(1초마다)
	var smoke_k := _smoke_k(h) * (0.5 if wet else 1.0)
	_smoke_scan -= dt
	if _smoke_scan <= 0.0:
		_smoke_scan = 1.0
		_assign_smoke(player)
	var sp: ParticleProcessMaterial = null
	stats.smoke = 0
	for i in SMOKE_N:
		var s: GPUParticles3D = _smoke[i]
		var on: bool = out and smoke_k > 0.05 and _smoke_at[i].x < INF
		s.emitting = on
		if on:
			s.amount_ratio = smoke_k
			stats.smoke += 1
		sp = s.process_material
		sp.gravity = Vector3(wd.x * (0.15 + 1.6 * wind), 0.12, wd.y * (0.15 + 1.6 * wind))
	# ⑤ 물 반짝이 · ⑥ 반딧불: 물 자리를 2초마다 둘러 찾는다
	_scan_t -= dt
	if _scan_t <= 0.0:
		_scan_t = 2.0
		_scan_water(player)
	var sk := sunny * (0.5 + 0.5 * (1.0 - float(cur.get("cloud", 0.0))))
	(_spark.material_override as ShaderMaterial).set_shader_parameter("k", sk)
	_spark.visible = out and sk > 0.05 and not _spark_pts.is_empty()
	var dusk := (smoothstep(18.8, 19.6, h) * (1.0 - smoothstep(23.0, 23.9, h))) if h > 12.0 else (1.0 - smoothstep(3.5, 4.5, h))
	var flies_on: bool = out and not low and dusk > 0.3 and _water_c.x < INF and not wet and kind in ["clear", "cloudy"] and float(weather.snow if weather != null else 0.0) < 0.1
	_flies.emitting = flies_on
	stats.flies = flies_on
	if flies_on: _flies.global_position = _water_c + Vector3(0, 0.8, 0)
	if _dbg and Engine.get_process_frames() % 60 == 0:
		print("FXDBG smoke=%d chim=%d spark=%d water=%s motes=%s leaves=%s flies=%s smoke_k=%.2f" % [stats.smoke, _chimneys.size(), stats.sparkle, str(_water_c), _motes.emitting, _leaves.emitting, flies_on, smoke_k])

func _smoke_k(h: float) -> float:
	# 밥때(아침 5.5~9 · 저녁 16.5~20)는 짙고 낮(11~13 점심)은 옅게, 밤(21~5)은 없다
	var morning := smoothstep(5.3, 6.3, h) * (1.0 - smoothstep(8.5, 9.5, h))
	var noon := smoothstep(10.8, 11.5, h) * (1.0 - smoothstep(12.8, 13.5, h)) * 0.45
	var eve := smoothstep(16.3, 17.2, h) * (1.0 - smoothstep(19.8, 21.0, h))
	return clampf(maxf(maxf(morning, noon), eve), 0.0, 1.0)

func _yard_dirt(p: Vector3) -> bool:
	var i := clampi(roundi((p.x - world.hx0) / world.hstep), 0, world.hnx - 1)
	var j := clampi(roundi((p.z - world.hz0) / world.hstep), 0, world.hnz - 1)
	return world.pbytes[(j * world.hnx + i) * 4 + 2] < 24   # 마당 흙(B = 거리·16 < 1.5m)

func _assign_smoke(player: Vector3) -> void:
	var near := []
	for c in _chimneys:
		var d := Vector2(c.x - player.x, c.z - player.z).length_squared()
		if d < 70.0 * 70.0: near.append([d, c])
	near.sort_custom(func(a, b): return a[0] < b[0])
	for i in SMOKE_N:
		var want: Vector3 = near[i][1] if i < near.size() else Vector3(INF, 0, INF)
		if want != _smoke_at[i]:
			_smoke_at[i] = want
			if want.x < INF:
				(_smoke[i] as GPUParticles3D).global_position = want
				(_smoke[i] as GPUParticles3D).restart()

func _scan_water(player: Vector3) -> void:
	if not world.has_method("_in_river"):
		return
	# 둘레 34m 안 고리 몇 겹을 성기게 보고 물 칸을 모은다(작은 내·나루·못)
	var pts := []
	var best := INF; var bc := Vector3(INF, 0, INF)
	for ring: float in [6.0, 11.0, 16.0, 22.0, 28.0, 34.0]:
		var n := int(ring * 1.2)
		for k in n:
			var a := TAU * (float(k) + 0.37 * ring) / n
			var x: float = player.x + cos(a) * ring; var z: float = player.z + sin(a) * ring
			if not world._in_river(x, z, 0.0): continue
			var y: float = world.river_surface_at(x, z, 30.0)
			if is_nan(y): y = world.ground_at(x, z) + 0.15
			pts.append(Vector3(x, y + 0.12, z))
			if ring < best: best = ring; bc = Vector3(x, y, z)
	_water_c = bc
	# 반짝이: 물 칸 둘레에 흩뿌린다
	var mm: MultiMesh = _spark.multimesh
	var cnt := 0
	if not pts.is_empty():
		var rng := RandomNumberGenerator.new(); rng.seed = hash(Vector2i(floori(player.x / 8.0), floori(player.z / 8.0)))
		for i in SPARKLE_N if not low else SPARKLE_N / 2:
			var b: Vector3 = pts[rng.randi() % pts.size()]
			var p := b + Vector3(rng.randf_range(-2.5, 2.5), 0.0, rng.randf_range(-2.5, 2.5))
			if not world._in_river(p.x, p.z, 0.0): continue
			mm.set_instance_transform(cnt, Transform3D(Basis(Vector3.UP, rng.randf_range(-0.3, 0.3)) * Basis(Vector3.RIGHT, -PI / 2).scaled(Vector3.ONE * rng.randf_range(0.6, 1.3)), p))
			cnt += 1
	mm.visible_instance_count = cnt
	_spark_pts = pts
	stats.sparkle = cnt
