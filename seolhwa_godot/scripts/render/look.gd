# 사실 재질·빛 운전(material-lighting) — region_main이 하나 만든다. 전역 셰이더 값·해 그림자·노출(눈 적응)·후처리 모드를 맞춘다.
#   --look=ink   예전 붓 바림(툰·먹선·한지) 그대로        --look=real(기본)
#   --nopom      시차 매핑 끄기(비교)   --nograss 가까운 풀잎 끄기   --shadowsplits=1|2|4   --noexpo 노출 적응 끄기
# 화면 품질(설정 gfx): 높음 = 시차 매핑 · 그림자 4단(PSSM) · 1인칭 그림자 100m / 낮음 = 시차 없음 · 2단 · 60m
extends Node

const Pbr := preload("res://scripts/render/pbr.gd")

var main
var real := true
var low := false
var exposure := 1.0
const EXPO_BASE := 1.08
# 해:하늘빛 비(2차 — 맑은 낮 실제는 5:1 남짓). 예전(1:1 배율)은 그늘이 볕의 40%라 그림자·볼륨이 납작했다
const SUN_K := 1.55     # 낮 해 직접광 배율(사실 재질 · 논밭)
const AMB_K := 0.8     # 낮 하늘빛 배율
const FOG_K := 0.6      # 안개 농도 배율 — 마을 거리(20~60m)에 덮이던 뿌연 막을 걷는다(먼 산 대기 원근은 남는다)
var exposure_target := 1.0
var _shelter_tex: Texture2D = null
var _fp_shadow := false
var _cloud := 0.0
var _hidden_shadow := {}
# 성능 풀이 — 구역별 그림자·반사(산 = 고을·마을·장시·역·절에서 350m 넘게 떨어진 곳): 산에서는 그림자 판 2048(그림자 드리우는 것이 나무·바위뿐)
#   물 반사 1/3 해상도·3프레임에 한 번. 화면 품질 낮음은 어디서나 그림자 판 2048. --nozone 끔 · --shadowsize=n 고정
var zone_mtn := false
var _zone_t := 0.0
var _zone_pts := PackedVector2Array()
var _atlas := 0   # 실내 잘라 보기로 숨긴 지붕: 그림자만 드리우게 바꾼 메시 → 원래 cast_shadow

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
		if not main.args.has("nograss"):   # 가까운 풀잎(scripts/render/grass.gd) — --nograss 비교
			var g = load("res://scripts/render/grass.gd").new()
			main.scene_vp.add_child(g); g.setup(main)
	if low and not main.args.has("shadowsize"): _set_atlas(2048)
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
	sun.shadow_bias = 0.02   # 2차: 물체 발밑 그림자가 떠 보이지 않게(0.03·1.0 → 0.02·0.6)
	sun.shadow_normal_bias = 0.6

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
	# 해:하늘빛 비 — 낮은 해를 세게·하늘빛을 줄여 볕과 그늘의 차이를 키운다. 밤·새벽은 덜(달빛이 거칠지 않게)
	#   비·눈 날: 흐린 하늘이 고르게 밝다 — 해 배율을 내리고 하늘빛을 올린다(해가 빠진 만큼)
	var day := clampf(float(s.get("dayMix", 1.0)), 0.0, 1.0)
	RenderingServer.global_shader_parameter_set("sun_k", lerpf(1.2, SUN_K, day) * (1.0 - 0.3 * _cloud))
	RenderingServer.global_shader_parameter_set("amb_k", lerpf(0.85, AMB_K, day) * (1.0 + 0.6 * _cloud))
	if main.fog_on: RenderingServer.global_shader_parameter_set("fog_density", float(s.dens) * lerpf(FOG_K, 1.0, _cloud))

func _set_atlas(n: int) -> void:
	if n == _atlas: return
	_atlas = n
	RenderingServer.directional_shadow_atlas_set_size(n, true)

func _update_zone(dt: float) -> void:
	_zone_t -= dt
	if _zone_t > 0.0: return
	_zone_t = 1.0
	if main.args.has("nozone"): return
	if _zone_pts.is_empty():
		for st in main.world.region.get("settlements", []):
			if String(st.get("kind", st.get("type", ""))) in ["주막", "성황당"]: continue
			if st.has("x") and st.has("z"): _zone_pts.append(Vector2(float(st.x), float(st.z)))
		if _zone_pts.is_empty(): return
	var p := Vector2(main.player_pos.x, main.player_pos.z)
	var best := INF
	for q in _zone_pts: best = minf(best, p.distance_squared_to(q))
	best = sqrt(best)
	var m := best > (320.0 if zone_mtn else 380.0)   # 되돌림 여유 60m(경계에서 깜빡이지 않게)
	if m == zone_mtn and _atlas != 0: return
	zone_mtn = m
	if main.water_fx != null and "zone_mtn" in main.water_fx: main.water_fx.zone_mtn = m
	if not main.args.has("shadowsize"): _set_atlas(2048 if (low or m) else 4096)
	print("ZONE mtn=%s d=%.0f atlas=%d" % [m, best, _atlas])

func _process(dt: float) -> void:
	if main == null or main.world == null: return
	_update_zone(dt)
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
	exposure_target = EXPO_BASE * (1.0 + 0.8 * night) * (1.0 + 0.7 * inside * (1.0 - night)) * (1.0 + 0.2 * _cloud)
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
