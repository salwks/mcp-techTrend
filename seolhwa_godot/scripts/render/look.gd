# 사실 재질·빛 운전(material-lighting) — region_main이 하나 만든다. 전역 셰이더 값·해 그림자·노출(눈 적응)·후처리 모드를 맞춘다.
#   --look=ink   예전 붓 바림(툰·먹선·한지) 그대로        --look=real(기본)
#   --nopom      시차 매핑 끄기(비교)   --shadowsplits=1|2|4   --noexpo 노출 적응 끄기
# 화면 품질(설정 gfx): 높음 = 시차 매핑 · 그림자 4단(PSSM) · 1인칭 그림자 100m / 낮음 = 시차 없음 · 2단 · 60m
extends Node

const Pbr := preload("res://scripts/render/pbr.gd")

var main
var real := true
var low := false
var exposure := 1.0
const EXPO_BASE := 1.1
var exposure_target := 1.0
var _shelter_tex: Texture2D = null
var _fp_shadow := false
var _cloud := 0.0
var _hidden_shadow := {}   # 실내 잘라 보기로 숨긴 지붕: 그림자만 드리우게 바꾼 메시 → 원래 cast_shadow

func setup(m) -> void:
	main = m
	name = "Look"
	real = String(main.args.get("look", "real")) != "ink"
	low = main.gfx_low()
	Pbr.ensure()
	RenderingServer.global_shader_parameter_set("look_pbr", 1.0 if real else 0.0)
	RenderingServer.global_shader_parameter_set("pbr_q", 0.0 if (low or main.args.has("nopom")) else 1.0)
	RenderingServer.global_shader_parameter_set("amb_k", 1.0)
	var post = main.post
	post.real = real
	if real:
		post.paper = false   # 한지 결·종이 비네트는 그림 같은 쪽 — 사실 쪽은 렌즈 비네트만
		_setup_sun()
	print("LOOK real=%s low=%s pom=%s splits=%d" % [real, low, not (low or main.args.has("nopom")), main.sun.directional_shadow_mode])

func _setup_sun() -> void:
	var sun: DirectionalLight3D = main.sun
	var sp := int(main.args.get("shadowsplits", "2" if low else "4"))
	sun.directional_shadow_mode = [DirectionalLight3D.SHADOW_ORTHOGONAL, DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS, DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS][clampi([1, 2, 4].find(sp), 0, 2)]
	sun.directional_shadow_split_1 = 0.08
	sun.directional_shadow_split_2 = 0.22
	sun.directional_shadow_split_3 = 0.5
	sun.directional_shadow_blend_splits = not low
	sun.directional_shadow_fade_start = 0.85
	sun.shadow_bias = 0.03
	sun.shadow_normal_bias = 1.0

# region_main._apply_atmo 끝에서: 해 방향·색을 셰이더에, 구름이 끼면 그림자가 무르고 옅어진다
func atmo(s: Dictionary, dir: Vector3) -> void:
	var sc: Vector3 = s.sun
	var e := float(s.sunI)
	RenderingServer.global_shader_parameter_set("sun_dir", dir.normalized())
	RenderingServer.global_shader_parameter_set("sun_col", sc * e)
	RenderingServer.global_shader_parameter_set("sky_top", s.skyTop)
	RenderingServer.global_shader_parameter_set("sky_hor", s.skyHor)
	if not real: return
	_cloud = float(main.weather.cur.cloud) if main.weather != null else 0.0
	var sun: DirectionalLight3D = main.sun
	sun.shadow_blur = 1.0 + _cloud * 3.5
	sun.shadow_opacity = 1.0 - 0.55 * smoothstep(0.4, 1.0, _cloud)
	# 비·눈 날: 흐린 하늘이 고르게 밝다 — 하늘빛을 조금 올린다(해가 빠진 만큼)
	RenderingServer.global_shader_parameter_set("amb_k", 1.0 + 0.35 * _cloud)

func _process(dt: float) -> void:
	if main == null or main.world == null: return
	var w = main.world
	if w.dress_tex != _shelter_tex and w.dress_tex != null:
		_shelter_tex = w.dress_tex
		RenderingServer.global_shader_parameter_set("shelter_tex", _shelter_tex)
		RenderingServer.global_shader_parameter_set("shelter_meta", Vector4(w.hx0, w.hz0, 1.0 / w.hstep, 1.0))
		RenderingServer.global_shader_parameter_set("shelter_size", Vector2(w.hnx, w.hnz))
	if not real: return
	# 1인칭: 그림자를 멀리까지(눈높이는 멀리 보인다)
	var fp: bool = main.fp_view()
	if fp != _fp_shadow:
		_fp_shadow = fp
		var sd := float(main.args.get("shadowdist", "60"))
		main.sun.directional_shadow_max_distance = (sd if low else maxf(sd, 100.0)) if fp else sd
	# 노출(눈 적응): 밤·실내(처마 안 깊이)·흐림이면 조금 열고, 1초 남짓에 걸쳐 따라간다
	var night := float(main._state.get("night", 0.0)) if main._state is Dictionary else 0.0
	var inside := 0.0
	var p: Vector3 = main.cam.global_position if fp else main.player_pos
	var sd_e := eave_sd(p.x, p.z)
	if fp or w.indoor != null or main._hidden_interior.size() > 0: inside = clampf(-sd_e / 1.6, 0.0, 1.0)
	if w.indoor != null: inside = 1.0
	# 밤 실내는 등잔이 밝혀 주므로 더 열지 않는다
	exposure_target = EXPO_BASE * (1.0 + 0.45 * night) * (1.0 + 0.7 * inside * (1.0 - night)) * (1.0 + 0.2 * _cloud)
	if main.args.has("noexpo"): exposure_target = 1.0
	exposure += (exposure_target - exposure) * minf(1.0, dt * 1.6)
	main.post.exposure = exposure

# 처마 부호 거리(m, 안쪽 음수) — region_world.dbytes R
func eave_sd(x: float, z: float) -> float:
	var w = main.world
	if w.dbytes.is_empty(): return 9.0
	var i := clampi(roundi((x - w.hx0) / w.hstep), 0, w.hnx - 1)
	var j := clampi(roundi((z - w.hz0) / w.hstep), 0, w.hnz - 1)
	return (float(w.dbytes[(j * w.hnx + i) * 4]) - 128.0) / 16.0

# 실내 잘라 보기: 숨긴 지붕·앞벽이 그림자는 그대로 드리우게(볕이 지붕을 뚫고 방을 비추지 않게)
func set_hidden(o: Node, hidden: bool) -> void:
	if not real:
		o.visible = not hidden
		return
	for mi in o.find_children("*", "GeometryInstance3D", true, false):
		if hidden:
			if not _hidden_shadow.has(mi):
				_hidden_shadow[mi] = mi.cast_shadow
				if mi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF: mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
				else: mi.visible = false
		elif _hidden_shadow.has(mi):
			if is_instance_valid(mi):
				mi.cast_shadow = _hidden_shadow[mi]
				mi.visible = true
			_hidden_shadow.erase(mi)
	if o is GeometryInstance3D:
		if hidden and not _hidden_shadow.has(o):
			_hidden_shadow[o] = o.cast_shadow; o.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		elif not hidden and _hidden_shadow.has(o):
			o.cast_shadow = _hidden_shadow[o]; _hidden_shadow.erase(o)
