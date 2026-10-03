# 권역 실행 장면 — scripts/main.gd를 바탕으로(복사 후 수정) 권역 지형 엔진(region_world.gd) 위에서
# 플레이어 프레임 캐릭터·고정 시점 카메라·시간대·후처리·등불이 동작한다.
#
# 명령줄(-- 뒤에): --time=14 --warp=x,z --shot=out.png --frames=60 --quit --scale=2 --bench=15
#   --tour=dir        남원읍성·광한루·여원재·운봉·황산·인월·실상사 근처 등을 차례로 찍는다
#   --data=res://…/   권역 데이터 폴더(기본: region_data/JL_NAMWON_UNBONG, 없으면 shots/region/tmp_data)
#   --benchspeed=30   --bench 자동 걷기 속도(m/s, 기본 4.6 = 달리기). 크게 하면 타일 로딩을 몰아서 시험한다
#   --cam=거리,피치[,fov]  시점 바꿔 보기(원경·이음매 점검)
#   --placedir=폴더[;폴더]  배치 파일(placement_*.json)을 더 읽을 폴더   --noplace  배치 안 읽기   --serialbuild  키트를 한 줄로 짓기
#   --reload   배치 파일이 바뀌면 다시 읽기(F5 키도 같음)   --markers  배치가 있어도 임시 표지 보이기   --cutaway  나무 줄여 숨기기(옛 가림)
#   --nomarkers       임시 표지(장승 기둥) 끄기   --noscatter  식생(kit/nature/scatter.gd) 끄기
#   --region=<id>      권역(region_data/<id>/, 기본 JL_NAMWON_UNBONG)   --route=<id>  노정(region_data/routes/<id>/route.json)
#   --routedir=폴더[;폴더]  노정을 더 찾을 폴더(시험: res://shots/region/test_route/)
#   --weather=clear|cloudy|rain|fog|snow|wind  날씨 고정(U 키: 날씨 돌리기)
#   --walkroute[=n] [--walkspeed=12]  --portaltest처럼 공간을 넘되, 노정에서는 주 도로를 끝까지 실제로 걷는다(막힘을 WALK stuck으로 남김)
#   --portaltest[=n]  불러오기가 끝나면 포털로 걸어가 n번 공간을 넘어가며 도착 화면을 --shotdir(기본 shots/region/travel)에 찍는다
#   --nowallproxy     region.json walls 대신 벽(키트가 없는 성벽 구간) 끄기
#   --kitcache=user://폴더/  키트 디스크 캐시 폴더(기본 user://kit_cache/)   --nokitcache  캐시 끄기
# 비교용 끄기: --nofog --nopost --notilt --nobloom --noshadow --nomsaa --nolamps --nochars --noworld --noocc --nofar --nowater
extends Node

const RegionWorld := preload("res://scripts/region/region_world.gd")
const PlacementLoader := preload("res://scripts/region/placement_loader.gd")
const Travel := preload("res://scripts/region/travel.gd")
const Weather := preload("res://scripts/region/weather.gd")
const PORTAL_R := 5.0      # 이 안에 들어서면 다음 공간으로
const PORTAL_ARM := 12.0   # 도착한 뒤 이만큼 떨어져야 포털이 다시 켜진다

const WALK := 2.2
const RUN := 4.6
const FADED := 0.28
const LAMP_KINDS := {
	lantern = { color = 0xffa855, glow = 0xffb866, intensity = 22.0, distance = 9.0, size = 0.8, flick = 0.07 },
	torch = { color = 0xff8a3c, glow = 0xff9a48, intensity = 22.0, distance = 10.0, size = 1.0, flick = 0.16 },
	shrine = { color = 0xff9060, glow = 0xffa868, intensity = 14.0, distance = 7.0, size = 0.42, flick = 0.12 },
	window = { color = 0xffc27a, glow = 0xffcf8a, intensity = 8.0, distance = 7.0, size = 1.15, flick = 0.02 },
}
# 이름(일부) → 찍을 시각, 표지에서 남쪽으로 물러설 거리
const TOUR := [
	["namwon_day", "남원읍성", 10.0, 9.0], ["gwanghallu_day", "광한루", 10.0, 9.0], ["yeowonjae_day", "여원재", 10.0, 9.0],
	["unbong_day", "운봉", 10.0, 9.0], ["hwangsan_day", "황산", 15.0, 9.0], ["inwol_day", "인월", 10.0, 9.0],
	["silsangsa_day", "실상사", 10.0, 9.0], ["river_day", "@river", 10.0, 0.0], ["namwon_dusk", "남원읍성", 18.3, 9.0],
	["namwon_night", "남원읍성", 22.0, 9.0], ["overview_unbong", "운봉", 10.0, 9.0, "520,30,40", "nofog"],
	["overview_jiri", "실상사", 16.0, 9.0, "700,26,40", "nofog"],
]

var args := {}
var post: PostEffect
var scene_vp: SubViewport
var world  # RegionWorld (World를 이어받음)
var cam: Camera3D
var rig: CameraRig
var sun: DirectionalLight3D
var env: Environment
var sky_mat: ShaderMaterial
var player: SpriteChar
var player_pos := Vector3.ZERO
var npcs := []
var lamp_slots := []
var lamp_glows := []
var hour := 10.0
var time_flow := false
var clock := 0.0
var focus_y := 0.45
var fog_on := true
var _occ_frame := 0
var _occ_near := []
var _occ_near_t := 0
var _occ_count := -1
var _hidden_interior := []
var _state: Dictionary
var _render_scale := 1.0
var _bench_left := 0.0
var _bench_frames := 0
var _bench_time := 0.0
var _bench_worst := 0.0
var _bench_dts := PackedFloat32Array()
var _bench_gpu := 0.0   # 프레임당 삼각형 합
var _bench_draws := 0.0
var _bench_loading := true
var _bench_load_t := 0.0
var _bench_dir := 0.0
var _bench_speed := RUN
var _bench_dist := 0.0
var _bench_start := Vector3.ZERO
var _lights_seen := -1
var _glow_shader: Shader
var _glow_mats := {}   # 종류 → [ShaderMaterial, QuadMesh]
var _glow_k := 0.0
var _glow_on := false
var _glow_at := Vector3(INF, 0, INF)
var _near_lights := []
const GLOW_R := 110.0
var placement  # PlacementLoader
var _loading := true      # 시작 불러오기 화면(플레이어 둘레 반경 2타일 건물·식생이 다 붙을 때까지)
var _load_ui: CanvasLayer
var _load_label: Label
var _load_t0 := 0
var _fill: OmniLight3D     # 실내 보조광(지붕을 숨긴 실내가 벽 그림자로 거의 검게 나오는 것을 막는다)
var _fill_k := 0.0
var _reload_t := 0.0
var weather    # Weather
var _base_state: Dictionary
var _base_dir := Vector3.UP
var _pending := {}        # 다른 공간에서 넘어왔으면 그 예약(Travel)
var _data_dir := ""
var portals := []         # Travel.portals_for
var _portal_armed := {}
var _leaving := false
var _hud: Label
var _hud_t := 0.0
var _ptest := {}          # --portaltest 진행 상태

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	_setup_input()
	if args.has("routedir"): Travel.extra_route_dirs = args.routedir.split(";", false)
	if args.has("kitcache"): PlacementLoader.KitCache.DIR = String(args.kitcache).trim_suffix("/") + "/"
	if args.has("nokitcache"): PlacementLoader.KitCache.enabled = false
	_pending = Travel.take_pending()
	_data_dir = _pick_dir()
	var scale := float(args.get("scale", DisplayServer.screen_get_scale()))
	_render_scale = scale
	scene_vp = SubViewport.new()
	scene_vp.own_world_3d = true
	scene_vp.msaa_3d = Viewport.MSAA_4X
	scene_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(scene_vp)
	_fit_viewport()
	get_window().size_changed.connect(_fit_viewport)
	post = PostEffect.new()
	post.paper_ratio = scale
	post.lum_mult = 2.0 if RenderingServer.get_current_rendering_method() == "mobile" else 1.0
	post.paper_image = Image.load_from_file(ProjectSettings.globalize_path("res://data/paper.png"))
	var view := TextureRect.new()
	view.texture = scene_vp.get_texture()
	view.set_anchors_preset(Control.PRESET_FULL_RECT)
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(view)
	_load_t0 = Time.get_ticks_msec()
	_build_scene()
	_prewarm_shaders()
	_make_load_ui()
	if args.has("nomsaa"): scene_vp.msaa_3d = Viewport.MSAA_DISABLED
	if args.has("noshadow"): sun.shadow_enabled = false
	if args.has("nolamps"):
		for o in lamp_slots: o.visible = false
	if args.has("nochars"): player.visible = false
	if args.has("noworld"): world.visible = false
	if args.has("nofar"): world.far_node.visible = false
	if args.has("nowater"): world.water_root.visible = false
	if args.has("noocc"): world.occluders.clear()
	if args.has("notilt"): post.tilt = false
	if args.has("nobloom"): post.bloom = false
	if args.has("nopost"): post.enabled = false
	if args.has("time"): hour = float(args.time)
	if args.has("nofog"): fog_on = false
	if not _pending.is_empty():
		hour = float(_pending.get("hour", hour))
		_arrive(_pending.get("at"))
	elif args.has("warp"):
		var p: PackedStringArray = args.warp.split(",")
		teleport(float(p[0]), float(p[1]))
	_apply_time()
	if args.has("cam"): # --cam=거리,피치[,fov] 시점 바꿔 보기(원경·이음매 점검용)
		var c: PackedStringArray = args.cam.split(",")
		rig.override = { distance = float(c[0]), pitch = float(c[1]) if c.size() > 1 else 38.0, fov = float(c[2]) if c.size() > 2 else 30.0 }
	rig.update(0, player_pos, player.facing, null, true)
	if args.has("bench"):
		_bench_left = float(args.bench)
		_bench_speed = float(args.get("benchspeed", str(RUN)))
		_bench_start = player_pos
		Engine.max_fps = 0
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	if args.has("portaltest") or args.has("walkroute"):
		var a0: String = args.get("walkroute", args.get("portaltest", "1"))
		_ptest = _pending.get("ptest", { left = int(a0) if a0 != "1" else 2, n = 0, walk = args.has("walkroute") })
	elif not _pending.is_empty(): pass   # 넘어온 장면에서는 투어·찍기를 다시 하지 않는다
	elif args.has("tour"): _run_tour.call_deferred(args.tour)
	elif args.has("shot"): _run_shot.call_deferred(args.shot, int(args.get("frames", "30")))

const MAX_RENDER_EDGE := 3840

func _fit_viewport() -> void:
	var win := get_window().size
	var k := minf(_render_scale, float(MAX_RENDER_EDGE) / maxf(1.0, maxf(win.x, win.y)))
	var s := Vector2i(maxi(1, roundi(win.x * k)), maxi(1, roundi(win.y * k)))
	if scene_vp.size != s: scene_vp.size = s

func _setup_input() -> void:
	var keys := {
		move_up = [KEY_W, KEY_UP], move_down = [KEY_S, KEY_DOWN], move_left = [KEY_A, KEY_LEFT], move_right = [KEY_D, KEY_RIGHT],
		run = [KEY_SHIFT], time_step = [KEY_T], toggle_post = [KEY_P], reload_place = [KEY_F5], weather_step = [KEY_U],
	}
	for act in keys:
		if not InputMap.has_action(act): InputMap.add_action(act)
		for k in keys[act]:
			var ev := InputEventKey.new(); ev.physical_keycode = k
			InputMap.action_add_event(act, ev)

func _build_scene() -> void:
	var root := scene_vp
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.BLACK
	sky_mat = ShaderMaterial.new(); sky_mat.shader = load("res://shaders/sky_backdrop.gdshader")
	var sky_quad := MeshInstance3D.new()
	var qm := QuadMesh.new(); qm.size = Vector2(2, 2)
	sky_quad.mesh = qm
	sky_quad.material_override = sky_mat
	sky_quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sky_quad.custom_aabb = AABB(Vector3(-1e5, -1e5, -1e5), Vector3(2e5, 2e5, 2e5))
	root.add_child(sky_quad)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new(); we.environment = env
	root.add_child(we)

	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = float(args.get("shadowdist", "60"))
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.2
	sun.shadow_blur = 1.5
	root.add_child(sun)

	cam = Camera3D.new()
	cam.near = 0.5; cam.far = 6000.0; cam.fov = 30.0
	var comp := Compositor.new()
	comp.compositor_effects = [post]
	cam.compositor = comp
	root.add_child(cam)
	cam.current = true

	world = RegionWorld.new()
	world.markers = args.has("markers") # 임시 위치 표지(이름표 달린 기둥)는 개발 확인용 — 기본 끔
	world.use_scatter = not args.has("noscatter")
	world.split_scatter = not args.has("nosplit")
	root.add_child(world)
	world.loading = true
	world.load_region(_data_dir)
	weather = Weather.new()
	root.add_child(weather)
	weather.setup(world, world.data_dir, String(_pending.get("weather", args.get("weather", ""))))
	if not _pending.is_empty() and _pending.has("wet"):
		weather.wet = float(_pending.wet); weather.snow = maxf(weather.snow, float(_pending.get("snow", 0.0)))
	world.use_cutaway = args.has("cutaway")
	# 배치(§8): placement_*.json → 키트 → add_static (+ --placedir=폴더1;폴더2 추가 폴더)
	placement = PlacementLoader.new(world, args.get("placedir", "").split(";", false) if args.has("placedir") else [])
	placement.parallel = not args.has("serialbuild")
	if not args.has("noplace"): placement.load_all()
	if placement.stats.get("placed", 0) > 0 and not args.has("markers"): world.remove_tagged("marker")
	if not args.has("nowallproxy"): world.build_wall_proxies(placement)   # region.json walls 중 키트가 안 덮은 구간만
	portals = Travel.portals_for(world.region, world.is_route)
	_place_portals()
	rig = CameraRig.new(cam, world)

	for i in 6:
		var o := OmniLight3D.new()
		o.omni_attenuation = 2.0
		o.light_energy = 0.0
		o.shadow_enabled = false
		root.add_child(o)
		lamp_slots.append(o)
	_glow_shader = Shader.new(); _glow_shader.code = GLOW_CODE
	_fill = OmniLight3D.new()
	_fill.light_color = Color("#ffe6c4"); _fill.omni_range = 9.0; _fill.omni_attenuation = 1.2
	_fill.shadow_enabled = false; _fill.light_energy = 0.0
	root.add_child(_fill)

	SpriteChar.load_bank("player", "frames.json")
	player = SpriteChar.new("player")
	player.facing = "up"
	root.add_child(player)
	teleport(world.spawn.x, world.spawn.y)

const GLOW_CODE := """shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
uniform vec3 color;
uniform float k = 0.0;
uniform float flick = 0.0;
varying float v_fl;
void vertex() {
	float seed = fract(sin(dot(MODEL_MATRIX[3].xz, vec2(12.9898, 78.233))) * 43758.5453) * 100.0;   // 등불마다 다른 깜빡임(자리로)
	v_fl = 1.0 + flick * (sin(TIME * 13.0 + seed) * 0.6 + sin(TIME * 7.3 + seed * 2.0) * 0.4);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}
void fragment() {
	float r = length(UV - 0.5) * 2.0;
	float g = exp(-r * r * 4.0) * (1.0 - smoothstep(0.8, 1.0, r));
	ALBEDO = color * g * k * v_fl * 2.0;
}
"""

# 권역에서는 타일이 붙고 떨어질 때마다 등불 목록이 바뀐다 → 발광 판을 맞춰 만들고 지운다
func _sync_glows() -> void:
	if _lights_seen == world.lights_version: return
	_lights_seen = world.lights_version
	# 등불이 수천 개(한양)라 목록 비교는 사전으로(전에는 has()로 N²), 재질은 종류마다 하나(깜빡임 위상은 셰이더가 자리로)
	var cur := {}
	for l in world.lights: cur[l] = true
	var have := {}
	var keep := []
	for g in lamp_glows:
		if cur.has(g.light):
			keep.append(g); have[g.light] = true
		else:
			g.mesh.queue_free()
	lamp_glows = keep
	_glow_at = Vector3(INF, 0, INF)   # 목록이 바뀌었으니 둘레를 다시 고른다
	for l in world.lights:
		if have.has(l): continue
		var kname: String = l.kind if LAMP_KINDS.has(l.kind) else "lantern"
		var kd: Dictionary = LAMP_KINDS[kname]
		if not _glow_mats.has(kname):
			var m := ShaderMaterial.new(); m.shader = _glow_shader
			var c := Color.hex((int(kd.glow) << 8) | 0xff).srgb_to_linear()
			m.set_shader_parameter("color", Vector3(c.r, c.g, c.b))
			m.set_shader_parameter("flick", float(kd.flick))
			m.set_shader_parameter("k", _glow_k)
			var q := QuadMesh.new(); q.size = Vector2.ONE * kd.size * 2.0
			_glow_mats[kname] = [m, q]
		var mi := MeshInstance3D.new()
		mi.mesh = _glow_mats[kname][1]
		mi.material_override = _glow_mats[kname][0]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = Vector3(l.x, l.y, l.z)
		mi.visible = false
		scene_vp.add_child(mi)
		lamp_glows.append({ mesh = mi, light = l, kind = kd })

func teleport(x: float, z: float) -> void:
	world.focus(Vector3(x, 0, z))
	var p := _nearest_free(x, z, player.radius)
	player_pos = Vector3(p.x, world.height_at(p.x, p.y), p.y)
	player.position = player_pos
	var _t0 := Time.get_ticks_usec()
	var _ev: String = world.stats.get("event", "")
	world.focus(player_pos)
	var _t1 := Time.get_ticks_usec()

func _nearest_free(x: float, z: float, r: float) -> Vector2:
	var rad := 0.0
	while rad < 30.0:
		var a := 0.0
		while a < TAU:
			var px := x + cos(a) * rad; var pz := z + sin(a) * rad
			if not world.blocked(px, pz, r): return Vector2(px, pz)
			if rad == 0.0: break
			a += PI / 8.0
		rad += 0.5
	return Vector2(x, z)

static func facing_from(dx: float, dz: float, prev: String) -> String:
	if dx == 0.0 and dz == 0.0: return prev
	if absf(dx) > absf(dz) * 1.15: return "right" if dx > 0.0 else "left"
	return "down" if dz > 0.0 else "up"

# ---- 시간대 ----
func _apply_time() -> void:
	_base_state = TimeOfDay.sample(hour)
	_base_dir = TimeOfDay.light_direction(hour, _base_state.dayMix)
	_apply_atmo()
	world.update_scatter_lod(player_pos, true)

# 시간대 상태 + 기후대·날씨 보정(weather.modify)을 장면에 칠한다. 날씨가 옮겨 가는 동안은 몇 프레임마다 다시 부른다
func _apply_atmo() -> void:
	var s: Dictionary = _base_state
	var dir: Vector3 = _base_dir
	if weather != null:
		var md: Array = weather.modify(_base_state, _base_dir)
		s = md[0]; dir = md[1]
		weather.dirty = false
	_state = s
	sun.light_color = _srgb(s.sun)
	sun.light_energy = s.sunI
	sun.basis = Basis.looking_at(-dir, Vector3.UP if absf(dir.y) < 0.99 else Vector3.FORWARD)
	RenderingServer.global_shader_parameter_set("hemi_sky", s.hemiS)
	RenderingServer.global_shader_parameter_set("hemi_ground", s.hemiG)
	RenderingServer.global_shader_parameter_set("hemi_i", s.hemiI)
	RenderingServer.global_shader_parameter_set("fog_color", s.fog)
	RenderingServer.global_shader_parameter_set("fog_density", s.dens if fog_on else 0.0)
	RenderingServer.global_shader_parameter_set("glow_k", TimeOfDay.night_factor(hour) * 1.1)
	sky_mat.set_shader_parameter("u_top", s.skyTop)
	sky_mat.set_shader_parameter("u_hor", s.skyHor)
	sky_mat.set_shader_parameter("u_low", s.low)
	sky_mat.set_shader_parameter("u_fog", s.fog)
	sky_mat.set_shader_parameter("u_glow", s.glow)
	sky_mat.set_shader_parameter("u_glow_i", s.glowI)
	sky_mat.set_shader_parameter("u_night", s.night)
	sky_mat.set_shader_parameter("u_sun_dir", Vector3(dir.x, 0, -0.6))
	# 원경(먹빛 능선)은 하늘 그림판의 먼 산과 같은 색 규칙
	var ink := Vector3(0.0103, 0.0131, 0.0232)
	world.set_far_param("u_hor", s.skyHor)
	world.set_far_param("u_fog", s.fog)
	world.set_far_param("u_low", s.low)
	world.set_far_param("u_glow", s.glow)
	world.set_far_param("u_glow_i", s.glowI)
	world.set_far_param("u_ink", ink)
	world.set_far_param("haze", 1.0 if fog_on else 0.0)  # --nofog면 원경 운해·안개빛도 끈다
	world.set_terrain_param("far_ink", s.skyHor.lerp(ink, 0.45))
	# 안개가 97%가 되는 거리 너머 식생은 그리지 않는다
	world.scatter_far = clampf(1.9 / maxf(float(s.dens), 0.001), 90.0, 320.0) if fog_on else 600.0
	if args.has("lod0"): world.lod0_dist = float(args.lod0)
	if args.has("scatterfar"): world.scatter_far = float(args.scatterfar)
	post.state = s

static func _srgb(v: Vector3) -> Color:
	return Color(v.x, v.y, v.z).linear_to_srgb()

# ---- 밤 등불: 가까운 6개만 실제 빛, 나머지는 발광 판 ----
func _update_lamps(t: float) -> void:
	_sync_glows()
	var f := TimeOfDay.lamp_factor(hour)
	# 발광 판: 재질(종류마다 하나)의 k만 바꾸고, 켜짐/꺼짐이 바뀔 때만 판마다 visible을 손댄다(전에는 매 프레임 판마다 — 한양 16ms)
	if absf(f - _glow_k) > 0.0005:
		var was_on := _glow_k > 0.001
		_glow_k = f
		for kn in _glow_mats: _glow_mats[kn][0].set_shader_parameter("k", f)
		if was_on != (f > 0.001): _glow_at = Vector3(INF, 0, INF)
	# 밤: 플레이어 둘레 GLOW_R 안 발광 판만 보인다(한양 수천 개 — 판마다 그리기 호출). 8m 넘게 움직였을 때만 다시 고른다
	if (f > 0.001) != _glow_on or (f > 0.001 and Vector2(player_pos.x - _glow_at.x, player_pos.z - _glow_at.z).length_squared() > 64.0):
		_glow_on = f > 0.001
		_glow_at = player_pos
		_near_lights.clear()
		for g in lamp_glows:
			var d2: float = Vector2(g.light.x - player_pos.x, g.light.z - player_pos.z).length_squared()
			g.mesh.visible = _glow_on and d2 < GLOW_R * GLOW_R
			if d2 < 60.0 * 60.0: _near_lights.append(g.light)
		_near_lights.sort_custom(func(a, b): return Vector2(a.x - player_pos.x, a.z - player_pos.z).length_squared() < Vector2(b.x - player_pos.x, b.z - player_pos.z).length_squared())
	if f <= 0.001:
		for o in lamp_slots: o.light_energy = 0.0
		return
	var near: Array = _near_lights   # 둘레 60m 안, 가까운 순(위에서 8m마다 다시 고름)
	for i in lamp_slots.size():
		var o: OmniLight3D = lamp_slots[i]
		if i >= near.size(): o.light_energy = 0.0; continue
		var l: Dictionary = near[i]
		var kd: Dictionary = LAMP_KINDS.get(l.kind, LAMP_KINDS.lantern)
		o.position = Vector3(l.x, l.y, l.z)
		o.light_color = Color.hex((int(kd.color) << 8) | 0xff)
		o.omni_range = kd.distance
		var fl: float = 1.0 + kd.flick * (sin(t * 13.0 + i) * 0.6 + sin(t * 7.3 + i * 2.0) * 0.4)
		o.light_energy = kd.intensity * f * fl

# ---- 가림 처리(main.gd와 같음) ----
func _update_occlusion(dt: float, interior) -> void:
	var want: Array = interior.hide if interior != null else []
	for o in _hidden_interior:
		if not want.has(o): o.visible = true
	for o in want: o.visible = false
	_hidden_interior = want.duplicate()
	_occ_frame = (_occ_frame + 1) % 3
	# 권역에는 가림 물체가 수천 개라, 15프레임마다 플레이어 50m 안 것만 골라 둔다(+ 아직 흐려져 있는 것)
	_occ_near_t -= 1
	if _occ_near_t <= 0 or _occ_count != world.occluders.size():
		_occ_near_t = 15; _occ_count = world.occluders.size()
		var keep := []
		for occ in _occ_near:
			if occ.alpha < 0.999 and world.occluders.has(occ): keep.append(occ)
		var pc := Vector2(player_pos.x, player_pos.z)
		for occ in world.occluders:
			var b: AABB = occ.aabb
			var cx := clampf(pc.x, b.position.x, b.end.x); var cz := clampf(pc.y, b.position.z, b.end.z)
			if pc.distance_squared_to(Vector2(cx, cz)) < 2500.0 and not keep.has(occ): keep.append(occ)
		_occ_near = keep
	if _occ_frame == 0:
		for occ in _occ_near: occ.target = 1.0
		if interior == null:
			var c := cam.global_position
			for occ in _occ_near:
				if not occ.node.visible or not occ.node.is_inside_tree(): continue
				var box: AABB = occ.aabb
				for h in [0.35, player.height * 0.6, player.height]:
					var p := player_pos + Vector3(0, h, 0)
					var d := p - c
					var end := c + d.normalized() * (d.length() - 0.4)
					if _seg_box(c, end, box) and _seg_hits_mesh(occ, c, end):
						occ.target = FADED; break
	var k := 1.0 - exp(-dt * 8.0)
	for occ in _occ_near:
		if absf(occ.alpha - occ.target) < 0.002: continue
		occ.alpha += (occ.target - occ.alpha) * k
		if absf(occ.alpha - occ.target) < 0.01: occ.alpha = occ.target
		world.set_occluder_alpha(occ, occ.alpha)

static func _seg_box(a: Vector3, b: Vector3, box: AABB) -> bool:
	return box.intersects_segment(a, b) != null or box.has_point(a)

static func _seg_hits_mesh(occ: Dictionary, a: Vector3, b: Vector3) -> bool:
	for mi in occ.meshes:
		var bb: AABB = mi.global_transform * mi.get_aabb()
		if bb.intersects_segment(a, b) != null: return true
	return false

# ---- 루프 ----
var _title: CanvasLayer = null
var _map: CanvasLayer = null
var _btitles = null
var _map_opened := false

func _process(delta: float) -> void:
	if _title == null and world and not world.region.is_empty():
		_title = preload("res://scripts/region/place_title.gd").new()
		add_child(_title)
		_title.setup(world.region)
		_map = preload("res://scripts/region/region_map.gd").new()
		add_child(_map)
		_map.setup(world, world.data_dir, placement)
		_btitles = preload("res://scripts/region/building_titles.gd").new()
		if placement: _btitles.setup(placement)
	# 불러오기 화면이 걷힌 뒤부터 지명·건물 이름을 띄운다
	if _title and not _loading: _title.update(minf(delta, 0.05), player_pos)
	if _btitles and not _loading:
		var bn: String = _btitles.update(player_pos)
		if bn != "":
			_title.show_title(bn); if args.has("logtitle"): print("BUILDING ", bn)
	if _map:
		if args.has("openmap") and not _loading and not _map.visible and not _map_opened:
			_map.toggle(); _map_opened = true
			if args.has("mapmode"): _map.show_mode(args.mapmode)   # --mapmode=all|nation (시험)
		_map.update(player_pos, player.facing)
	var dt := minf(0.05, delta)
	clock += dt
	if Input.is_action_just_pressed("time_step"):
		hour = fmod(floor(hour / 6.0) * 6.0 + 6.0, 24.0); _apply_time()
	if Input.is_action_just_pressed("weather_step") and weather != null:
		_show_hud("날씨: " + weather.cycle())
	# 배치 다시 읽기: F5, 또는 --reload면 파일이 바뀔 때마다(1초마다 확인)
	_reload_t += delta
	if Input.is_action_just_pressed("reload_place") or (args.has("reload") and _reload_t > 1.0 and placement.changed()):
		_reload_place()
	if args.has("reload") and _reload_t > 1.0: _reload_t = 0.0
	if Input.is_action_just_pressed("toggle_post"):
		post.tilt = not post.tilt; post.paper = post.tilt
	if time_flow:
		hour = fmod(hour + dt * 0.1, 24.0); _apply_time()
	_update_loading()
	var mv := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if _loading or _leaving or (_map and _map.visible): mv = Vector2.ZERO # 지도가 열려 있으면 멈춤
	var speed := RUN if Input.is_action_pressed("run") else WALK
	if not _ptest.is_empty() and not _loading and not _leaving:
		mv = _ptest_step(delta); speed = RUN
		if not _pt_path.is_empty(): speed = float(args.get("walkspeed", "12"))
	if _bench_left > 0.0 and _bench_loading and _loading:
		_bench_load_t += delta
	elif _bench_left > 0.0 and _bench_loading:
		# 처음 불러오기(시작 화면에 해당)가 끝난 뒤부터 잰다
		_bench_load_t += delta
		if (world.stats.jobs == 0 and not placement.busy() and _bench_load_t > 1.0) or _bench_load_t > 90.0:
			_bench_loading = false
			print("BENCH initial_load_s=%.1f" % _bench_load_t)
	elif _bench_left > 0.0:
		mv = Vector2(sin(_bench_dir), -cos(_bench_dir))
		speed = _bench_speed
		_bench_left -= delta
		_bench_frames += 1; _bench_time += delta
		if _bench_time > 2.0:
			_bench_gpu += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
			_bench_draws += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
			_bench_worst = maxf(_bench_worst, delta)
			_bench_dts.append(delta)
		if _bench_left <= 0.0: _bench_report()
	if mv.length() > 0.0:
		var r := player.radius
		var np = null
		# 빠른 자동 걷기는 한 번에 크게 움직이지 않도록 나눠서
		var steps := maxi(1, ceili(speed * dt / 0.5))
		var pos := player_pos
		for i in steps:
			var q = world.move_circle(pos, mv.x * speed * dt / steps, mv.y * speed * dt / steps, r)
			if q == null: break
			pos = Vector3(q.x, world.height_at(q.x, q.z), q.z)
			np = pos
		player.facing = facing_from(mv.x, mv.y, player.facing)
		if np != null:
			_bench_dist += Vector2(np.x - player_pos.x, np.z - player_pos.z).length()
			player_pos = np
			player.set_anim("run" if speed > WALK else "walk")
		else:
			player.set_anim("idle")
			if _bench_left > 0.0: _bench_dir += 1.3 + randf()  # 막히면 방향을 바꾼다
	else:
		player.set_anim("idle")
	if _bench_left > 0.0: _bench_dir += sin(clock * 0.21) * 0.004
	player.position = player_pos
	var _t0 := Time.get_ticks_usec()
	var _ev: String = world.stats.get("event", "")
	world.focus(player_pos)
	var _t1 := Time.get_ticks_usec()
	world.set_terrain_param("mist_base", player_pos.y)
	RenderingServer.global_shader_parameter_set("fog_base", player_pos.y) # 키트·캐릭터 산안개도 발 높이 기준
	var interior = world.interior_at(player_pos.x, player_pos.z)
	world.update_camera_zone(player_pos)
	rig.update(dt, player_pos, player.facing, interior)
	# 가림 점무늬(키트 재질): 카메라→플레이어 머리 선분 둘레의 나무·건물을 점무늬로 비운다. 실내에선 끔
	RenderingServer.global_shader_parameter_set("occ_a", cam.global_position)
	RenderingServer.global_shader_parameter_set("occ_b", player_pos + Vector3(0, player.height * 0.8, 0))
	var occ_r: float = 0.0 if interior != null or args.has("nodither") else (3.8 if world.forest_active else 2.4)  # 숲에서는 더 넓게
	RenderingServer.global_shader_parameter_set("occ_r", occ_r)
	RenderingServer.global_shader_parameter_set("occ_near", 0.0 if args.has("nodither") else 1.0)
	# 실내 보조광: 들어가면 서서히 켠다(밤에는 조금 더 — 호롱불 느낌)
	_fill_k += ((1.0 if interior != null else 0.0) - _fill_k) * minf(1.0, dt * 3.0)
	_fill.position = player_pos + Vector3(0, 2.4, 0.8)
	_fill.light_energy = _fill_k * (3.0 + 4.0 * TimeOfDay.night_factor(hour))
	_fill.visible = _fill_k > 0.01
	_update_occlusion(dt, interior)
	if interior == null: world.update_cutaway(dt, player_pos, cam.global_position)
	world.update_scatter_lod(player_pos)
	var _t2 := Time.get_ticks_usec()
	world.update(dt, clock)
	world.update_ferries(player_pos)
	placement.update()
	if weather != null:
		weather.update(dt, player_pos, cam.global_position, interior != null)
		world.wet_level = weather.wet
		if weather.dirty and Engine.get_process_frames() % 3 == 0: _apply_atmo()
	if not _loading and not _leaving: _check_portals()
	if _hud and _hud_t > 0.0:
		_hud_t -= delta; _hud.modulate.a = clampf(_hud_t, 0.0, 1.0)
	var _t3 := Time.get_ticks_usec()
	_update_lamps(clock)
	sky_mat.set_shader_parameter("u_time", clock)
	player.update_char(dt, cam)
	var sp := cam.unproject_position(player_pos + Vector3(0, 0.8, 0))
	var y := clampf(1.0 - sp.y / float(scene_vp.size.y), 0.15, 0.85)
	focus_y += (y - focus_y) * minf(1.0, dt * 6.0)
	post.focus_y = focus_y
	if args.has("bench") and _bench_time > 2.0 and delta > 0.03 and not _bench_loading:
		print("  SLOW f=%d %.1fms focus=%.1f update=%.1f near=%d jobs=%d done=%d" % [Engine.get_process_frames(), delta * 1000.0, (_t1 - _t0) / 1000.0, (_t3 - _t2) / 1000.0, world.stats.near, world.stats.jobs, world.stats.scatter_done])

func _bench_report() -> void:
	var a := Array(_bench_dts); a.sort()
	var p99: float = a[int(a.size() * 0.99)] if a.size() > 0 else 0.0
	var over := 0
	for d in a:
		if d > 0.0334: over += 1
	print("BENCH weather=%s wet=%.2f snow=%.2f" % [weather.kind if weather else "-", weather.wet if weather else 0.0, weather.snow if weather else 0.0])
	print("BENCH avg_fps=%.1f tris=%dk draws=%d worst_ms=%.1f p99_ms=%.1f over33=%d frames=%d render=%s speed=%.1f dist=%.0fm tiles_near=%d mid=%d scatter=%d statics=%d" % [
		_bench_frames / _bench_time, int(_bench_gpu / maxf(1.0, a.size()) / 1000.0), int(_bench_draws / maxf(1.0, a.size())), _bench_worst * 1000.0, p99 * 1000.0, over, _bench_frames, scene_vp.size, _bench_speed,
		_bench_dist, world.stats.near, world.stats.mid, world.stats.scatter_done, world.stats.statics])
	_quit()

# ---- 자동 스크린샷 ----
func _wait_frames(n: int) -> void:
	for i in n: await RenderingServer.frame_post_draw

func _save(path: String) -> void:
	# --winshot: 창에 실제로 보이는 화면(지명 표시 등 2D 포함)
	var img := (get_viewport() if args.has("winshot") else scene_vp).get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	img.save_png(path)
	print("SHOT ", path, " ", img.get_size(), " cam=%.1f/%.0f %s" % [rig.cur.distance, rig.cur.pitch, rig.zone_name], " pos=", player_pos, " lu=", world.landuse_at(player_pos.x, player_pos.z), " fps=", Engine.get_frames_per_second())

func _shot_at(x: float, z: float, h: float) -> void:
	hour = h
	teleport(x, z)
	_apply_time()
	await _wait_frames(20)
	var n := 0
	while (world.stats.jobs > 0 or placement.busy()) and n < 600:
		await _wait_frames(1); n += 1
	rig.update(0, player_pos, player.facing, world.interior_at(player_pos.x, player_pos.z), true)
	await _wait_frames(20)

# 권역 비교용 넓은 시점(--tourcam=거리,피치, 기본 34m·36°). --tourcam=game 이면 게임 시점 그대로
func _tour_camera() -> void:
	var tc: String = args.get("tourcam", "34,36")
	if tc == "game": rig.override = null; return
	var p := tc.split(",")
	rig.override = { distance = float(p[0]), pitch = float(p[1]) if p.size() > 1 else 34.0 }

func _run_shot(path: String, frames: int) -> void:
	await _wait_frames(10)
	var n := 0
	while _loading and n < 3000 and args.has("waitload"):   # --waitload: 불러오기 화면이 걷힌 뒤 찍기
		await _wait_frames(1); n += 1
	await _wait_frames(frames)
	_save(_abs(path))
	if args.has("quit"): _quit()

func _find_place(key: String) -> Variant:
	var reg: Dictionary = world.region
	if key == "@river":
		var rv: Array = reg.get("rivers", [])
		if rv.is_empty(): return null
		var pts: Array = rv[0].points
		var p: Array = pts[pts.size() / 2]
		return Vector2(float(p[0]), float(p[1]) + float(rv[0].get("width_m", 8.0)) * 0.5 + 8.0)
	for list in ["landmarks", "settlements", "passes"]:
		for s in reg.get(list, []):
			if String(s.get("name", "")).contains(key): return Vector2(float(s.x), float(s.z))
	return null

func _run_tour(dir: String) -> void:
	await _wait_frames(10)
	_tour_camera()
	for r in TOUR:
		var p = _find_place(r[1])
		if p == null:
			print("TOUR 건너뜀(자리 없음): ", r[1]); continue
		if r.size() > 4: # 높은 시점(원경·먹빛 능선 확인)
			var c: PackedStringArray = r[4].split(",")
			rig.override = { distance = float(c[0]), pitch = float(c[1]), fov = float(c[2]) }
		else: _tour_camera()
		fog_on = not args.has("nofog") and not (r.size() > 5 and r[5] == "nofog")  # 높은 시점 점검용: 안개 끄고 지형·타일 이음매 보기
		await _shot_at(p.x, p.y + r[3], r[2])
		if world.landuse_at(player_pos.x, player_pos.z) == 5: print("TOUR 물 위: ", r[1])
		_save(_abs(dir).path_join("region_%s.png" % r[0]))
	_quit()

# 가림 처리(반투명) 재질은 처음 쓰일 때 파이프라인을 만들며 프레임이 튄다 → 시작할 때 화면 밖이 아닌 곳에 몇 프레임 그려 둔다
func _make_load_ui() -> void:
	_load_ui = CanvasLayer.new(); _load_ui.layer = 10
	var bg := ColorRect.new(); bg.color = Color("#efe6d2"); bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_load_ui.add_child(bg)
	var title := Label.new(); title.text = "설화록"
	var sub := Label.new(); sub.text = _space_title()
	sub.add_theme_font_size_override("font_size", 26); sub.add_theme_color_override("font_color", Color("#5a5048"))
	sub.set_anchors_preset(Control.PRESET_CENTER); sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.position = Vector2(-300, -10); sub.size = Vector2(600, 36)
	title.add_theme_font_size_override("font_size", 72); title.add_theme_color_override("font_color", Color("#2b2622"))
	title.set_anchors_preset(Control.PRESET_CENTER); title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(-200, -90); title.size = Vector2(400, 100)
	bg.add_child(title)
	_load_label = Label.new(); _load_label.add_theme_color_override("font_color", Color("#5a5048"))
	_load_label.set_anchors_preset(Control.PRESET_CENTER); _load_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_load_label.position = Vector2(-200, 30); _load_label.size = Vector2(400, 40)
	bg.add_child(_load_label)
	bg.add_child(sub)
	add_child(_load_ui)

func _update_loading() -> void:
	if not _loading: return
	var c: Vector2i = world.tile_of(player_pos.x, player_pos.z)
	# 식생은 둘레 1타일(±256m, 안개 220m 안)만, 건물은 2타일까지 기다린다 — 나머지는 걸으면서 스트리밍과 같이 채워진다
	var near_busy: bool = world.scatter_busy_near(c, 1) or placement.busy_near(c, 2)
	var left: int = placement.pending_count()
	_load_label.text = "산천을 그리는 중…  식생 %d타일 · 건물 %d 남음" % [world.stats.jobs, left]
	# 불러오기 화면이 장면을 가리는 동안은 장면을 그리지 않는다(셰이더 미리 데우기 몇 프레임만) — 한양처럼 큰 권역에서 프레임당 수십 ms
	scene_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if Engine.get_process_frames() < 8 else SubViewport.UPDATE_DISABLED
	if not near_busy and Time.get_ticks_msec() - _load_t0 > 300:
		_loading = false
		world.loading = false
		scene_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		_load_ui.queue_free()
		player_pos.y = world.height_at(player_pos.x, player_pos.z)
		if args.has("gointerior") and not world.interiors.is_empty():  # 시험: n번째 실내 가운데로
			var it: Dictionary = world.interiors[clampi(int(args.gointerior), 0, world.interiors.size() - 1)]
			var cx: float = (it.minX + it.maxX) * 0.5; var cz: float = (it.minZ + it.maxZ) * 0.5
			player_pos = Vector3(cx, world.height_at(cx, cz), cz); player.position = player_pos
			rig.update(0, player_pos, player.facing, it, true)
			print("INTERIOR ", it.get("name", ""), " ", player_pos, " of ", world.interiors.size())
		print("LOAD ready_s=%.2f kit_cache hits=%d misses=%d" % [(Time.get_ticks_msec() - _load_t0) / 1000.0, PlacementLoader.KitCache.hits, PlacementLoader.KitCache.misses])

func _prewarm_shaders() -> void:
	var mats := []
	for k in ["atlas", "cloth"]:
		var m: ShaderMaterial = Kit.material(k)
		mats.append(m); mats.append(Materials.faded_copy(m))
	for lit in [true, false]:
		for ds in [true, false]:
			for bl in [true, false]:
				var m := ShaderMaterial.new(); m.shader = Materials.world_shader(lit, bl, ds); mats.append(m)
	var nodes := []
	var i := 0
	for m in mats:
		var mi := MeshInstance3D.new()
		var q := QuadMesh.new(); q.size = Vector2(0.05, 0.05)
		mi.mesh = q; mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		cam.add_child(mi)
		mi.position = Vector3((i % 8) * 0.06 - 0.2, (i / 8) * 0.06, -1.0)  # 카메라 바로 앞
		nodes.append(mi); i += 1
	_free_later.call_deferred(nodes, 3)

func _free_later(nodes: Array, frames: int) -> void:
	await _wait_frames(frames)
	for n in nodes: n.queue_free()

func _reload_place() -> void:
	_reload_t = 0.0
	placement.reload()
	if placement.stats.get("placed", 0) > 0 and not args.has("markers"): world.remove_tagged("marker")
	if not args.has("nowallproxy"): world.build_wall_proxies(placement)
	player_pos.y = world.height_at(player_pos.x, player_pos.z)

func _quit() -> void:
	placement.stop()
	world.shutdown()
	if weather: weather.reset_globals()
	get_tree().quit()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and world != null:
		if placement != null: placement.stop()
		world.shutdown()

static func _abs(p: String) -> String:
	return p if p.is_absolute_path() else ProjectSettings.globalize_path("res://").path_join(p)

# =====================================================================
# 여러 권역·노정(계약서 §10) — 공간 고르기, 포털, 넘어가기
# =====================================================================
func _pick_dir() -> String:
	if not _pending.is_empty(): return String(_pending.dir)
	if args.has("route"):
		var d := Travel.find_route_dir(args.route)
		if d == "": push_error("노정을 찾을 수 없다: %s (region_data/routes/ 또는 --routedir)" % args.route)
		return d
	if args.has("region"): return Travel.region_dir(args.region)
	return args.get("data", "")

func _space_title() -> String:
	if not _pending.is_empty(): return String(_pending.get("title", ""))
	return String(world.region.get("region_name", world.region.get("name", ""))) if world else ""

# 넘어온 자리: 도착 공간 좌표 at(포털 맞은편 끝). 공간 안쪽으로 16m 들어선 빈자리에 선다(바로 다시 넘어가지 않게)
func _arrive(at) -> void:
	var p: Vector2 = world.spawn
	if at is Vector2 and not is_nan(at.x): p = at
	elif at is Array and at.size() >= 2 and not is_nan(float(at[0])): p = Vector2(float(at[0]), float(at[1]))
	var c := Vector2(world.hx0 + (world.hnx - 1) * world.hstep * 0.5, world.hz0 + (world.hnz - 1) * world.hstep * 0.5)
	var inward := (c - p).normalized() if c.distance_to(p) > 1.0 else Vector2.ZERO
	# 길이 있으면 길을 따라 안쪽으로(가장 가까운 길 점에서 안쪽 이웃 점 방향)
	var road := Travel.main_road(world.region)
	if road.size() >= 2:
		var bi := 0; var bd := INF
		for i in road.size():
			var d := road[i].distance_to(p)
			if d < bd: bd = d; bi = i
		if bd < 60.0:
			var nb := road[mini(bi + 3, road.size() - 1)] if road[mini(bi + 3, road.size() - 1)].distance_to(c) < road[maxi(bi - 3, 0)].distance_to(c) else road[maxi(bi - 3, 0)]
			if nb.distance_to(road[bi]) > 1.0: inward = (nb - road[bi]).normalized(); p = road[bi]
	p += inward * 16.0
	teleport(p.x, p.y)
	for pt in portals: _portal_armed[pt.id] = Vector2(pt.x, pt.z).distance_to(Vector2(player_pos.x, player_pos.z)) > PORTAL_ARM
	print("TRAVEL arrive space=%s at=%s from=%s" % [world.region.get("region_id", "?"), player_pos, _pending.get("via", "")])

# 포털 자리: 장승 한 쌍 + 이정표 글씨(어디로 가는 길인지)
func _place_portals() -> void:
	var js = load("res://kit/village/jangseung.gd") if FileAccess.file_exists("res://kit/village/jangseung.gd") else null
	for pt in portals:
		var x: float = pt.x; var z: float = pt.z
		var y: float = world.height_at(x, z)
		var root := Node3D.new(); root.name = "portal_" + String(pt.id)
		var cols := []
		if js != null:
			for i in 2:
				var info: Dictionary = js.build({ seed = 31 + i, female = i == 1 })
				var n: Node3D = info.node
				n.position = Vector3(-2.6 if i == 0 else 2.6, 0, 0)
				root.add_child(n)
				cols.append({ type = "circle", x = n.position.x, z = 0.0, r = 0.35 })
		var lb := Label3D.new()
		lb.text = "→ " + String(pt.label)
		lb.font_size = 64; lb.pixel_size = 0.012
		lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lb.modulate = Color(1, 0.97, 0.9); lb.outline_modulate = Color(0.1, 0.08, 0.07); lb.outline_size = 14
		lb.position = Vector3(0, 3.6, 0)
		lb.no_depth_test = false
		root.add_child(lb)
		world.add_static(root, Transform3D(Basis(), Vector3(x, y, z)), { colliders = cols, footprint = Vector2(7, 2) }, "portal")
		_portal_armed[pt.id] = true
	if not portals.is_empty(): print("PORTALS ", portals.map(func(p): return "%s(%.0f,%.0f)->%s:%s" % [p.id, p.x, p.z, p.kind, p.target]))

func _check_portals() -> void:
	var pp := Vector2(player_pos.x, player_pos.z)
	for pt in portals:
		var d := Vector2(pt.x, pt.z).distance_to(pp)
		if not _portal_armed.get(pt.id, true):
			if d > PORTAL_ARM and _pt_path.is_empty(): _portal_armed[pt.id] = true
			continue
		if d < PORTAL_R:
			_travel(pt); return

func _travel(pt: Dictionary) -> void:
	var dir := Travel.find_route_dir(pt.target) if pt.kind == "route" else Travel.region_dir(pt.target)
	if dir == "" or world.space_file(dir) == "":
		_show_hud("길이 아직 닦이지 않았다: " + String(pt.label))
		_portal_armed[pt.id] = false
		return
	_leaving = true
	var at = Vector2(float(pt.tx), float(pt.tz))
	if is_nan(float(pt.tx)):
		var info := Travel.region_info(pt.target)
		at = Vector2(float(info.entry.x), float(info.entry.z)) if info.get("entry") is Dictionary else null
	var title := String(pt.label)
	var nxt := { kind = pt.kind, id = pt.target, dir = dir, at = at, hour = hour, via = world.region.get("region_id", ""), title = title + " (으)로",
		weather = weather.forced if weather else "", wet = weather.wet if weather else 0.0, snow = weather.snow if weather else 0.0 }
	if not _pt_path.is_empty():
		print("WALK done route=%s dist=%.0fm time=%.0fs stuck=%d skipped=%.0fm waypoints=%d/%d" % [world.region.get("region_id", ""), _pt_walk.dist, _pt_walk.t,
			_pt_walk.stuck, _pt_walk.skipped, _pt_i, _pt_path.size()])
	if not _ptest.is_empty():
		var pt2 := _ptest.duplicate(); pt2.left = int(_ptest.left) - 1; pt2.n = int(_ptest.n) + 1
		nxt.ptest = pt2
	print("TRAVEL leave %s -> %s %s at=%s objects=%d nodes=%d orphans=%d mem=%.0fMB" % [world.region.get("region_id", ""), pt.kind, pt.target, at,
		Performance.get_monitor(Performance.OBJECT_COUNT), Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT), Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0])
	# 짧은 불러오기 화면을 먼저 띄우고, 다음 프레임에 정리하고 장면을 다시 연다
	var ui := CanvasLayer.new(); ui.layer = 20
	var bg := ColorRect.new(); bg.color = Color("#efe6d2"); bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(bg)
	var lb := Label.new(); lb.text = title + " 가는 길…"
	lb.add_theme_font_size_override("font_size", 34); lb.add_theme_color_override("font_color", Color("#2b2622"))
	lb.set_anchors_preset(Control.PRESET_CENTER); lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lb.position = Vector2(-400, -20); lb.size = Vector2(800, 50)
	bg.add_child(lb)
	add_child(ui)
	Travel.set_pending(nxt)
	_leave.call_deferred()

func _leave() -> void:
	await _wait_frames(2)
	placement.stop()
	world.shutdown()
	weather.reset_globals()
	get_tree().reload_current_scene()

func _show_hud(t: String) -> void:
	if _hud == null:
		_hud = Label.new()
		_hud.add_theme_font_size_override("font_size", 22)
		_hud.add_theme_color_override("font_color", Color(1, 1, 1))
		_hud.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		_hud.add_theme_constant_override("outline_size", 5)
		_hud.position = Vector2(24, 20)
		var cl := CanvasLayer.new(); cl.layer = 6; cl.add_child(_hud); add_child(cl)
	_hud.text = t; _hud_t = 3.0; _hud.modulate.a = 1.0
	print("HUD ", t)

# ---- --portaltest: 불러오기가 끝나면 도착 화면을 찍고, 아직 남았으면 가장 먼 포털로 걸어간다 ----
var _pt_target = null
var _pt_shot_done := false
var _pt_stuck := 0.0
var _pt_last := Vector3.ZERO

# --walkroute[=n] (--portaltest 확장): 노정 공간에서는 순간이동 없이 주 도로(Travel.main_road)를 처음부터 끝까지 걷는다.
#   --walkspeed=12(m/s). 1.5초 넘게 막히면 "WALK stuck"을 남기고 다음 길 점으로 옮긴다. 다 걸으면 끝 포털로 들어가 다음 공간으로.
#   권역 공간에서는 예전 --portaltest처럼 가장 먼 포털로 간다.
var _pt_path := PackedVector2Array()
var _pt_i := 0
var _pt_walk := {}

func _walk_step(delta: float) -> Vector2:
	var pp := Vector2(player_pos.x, player_pos.z)
	_pt_walk.t += delta
	_pt_walk.dist += pp.distance_to(_pt_walk.last)
	_pt_walk.last = pp
	while _pt_i < _pt_path.size() - 1 and pp.distance_to(_pt_path[_pt_i]) < 3.0: _pt_i += 1
	var tp := _pt_path[_pt_i]
	if player_pos.distance_to(_pt_last) < 0.02: _pt_stuck += delta
	else: _pt_stuck = 0.0
	_pt_last = player_pos
	if _pt_stuck > 1.5:
		_pt_walk.stuck += 1
		var why := "물" if world._in_river(pp.x, pp.y, player.radius) else ("물체" if world.blocked(pp.x, pp.y, player.radius) else "경사·가장자리")
		print("WALK stuck #%d at (%.0f,%.0f) wp=%d/%d lu=%d near=%s" % [_pt_walk.stuck, pp.x, pp.y, _pt_i, _pt_path.size(), world.landuse_at(pp.x, pp.y), why])
		var ni := mini(_pt_i + 1, _pt_path.size() - 1)
		_pt_walk.skipped += pp.distance_to(_pt_path[ni])
		_pt_i = ni
		teleport(_pt_path[ni].x, _pt_path[ni].y); _pt_stuck = 0.0
		_pt_walk.last = Vector2(player_pos.x, player_pos.z)
	return (tp - pp).normalized()

func _ptest_step(delta: float) -> Vector2:
	if not _pt_shot_done:
		_pt_shot_done = true
		_ptest_shot.call_deferred()
		_pt_target = false
		return Vector2.ZERO
	if not _pt_path.is_empty(): return _walk_step(delta)
	if not (_pt_target is Dictionary): return Vector2.ZERO
	var tp := Vector2(_pt_target.x, _pt_target.z)
	var d := tp - Vector2(player_pos.x, player_pos.z)
	if player_pos.distance_to(_pt_last) < 0.02: _pt_stuck += delta
	else: _pt_stuck = 0.0
	_pt_last = player_pos
	if _pt_stuck > 0.6 or d.length() > 40.0:   # 막히거나 멀면 가까이 옮겨 놓고 다시 걷는다
		var q := tp - d.normalized() * minf(d.length() - 1.0, 14.0)
		teleport(q.x, q.y); _pt_stuck = 0.0
	return d.normalized()

func _ptest_shot() -> void:
	await _wait_frames(30)
	var dir: String = _abs(args.get("shotdir", "shots/region/travel"))
	var name := "travel_%d_%s.png" % [int(_ptest.n), String(world.region.get("region_id", "space")).to_lower()]
	_save(dir.path_join(name))
	print("PTEST n=%d space=%s portals=%d weather=%s objects=%d nodes=%d orphans=%d mem=%.0fMB" % [_ptest.n, world.region.get("region_id", ""), portals.size(), weather.label(),
		Performance.get_monitor(Performance.OBJECT_COUNT), Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT), Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0])
	if int(_ptest.left) <= 0 or portals.is_empty():
		_quit(); return
	# 도착한 곳에서 가장 먼 포털로
	var best = null; var bd := -1.0
	for pt in portals:
		var d := Vector2(pt.x, pt.z).distance_to(Vector2(player_pos.x, player_pos.z))
		if d > bd: bd = d; best = pt
	_pt_target = best
	_portal_armed[best.id] = true
	if bool(_ptest.get("walk", false)) and world.is_route:
		# 주 도로를 플레이어 쪽 끝부터, 마지막은 포털 자리
		var road := Travel.main_road(world.region)
		if road.size() >= 2:
			var here := Vector2(player_pos.x, player_pos.z)
			if here.distance_to(road[road.size() - 1]) < here.distance_to(road[0]): road.reverse()
			var path := PackedVector2Array()
			for i in road.size():
				if i == 0 or road[i].distance_to(path[path.size() - 1]) >= 6.0: path.append(road[i])
			path.append(Vector2(best.x, best.z))
			_pt_path = path; _pt_i = 0
			for pt in portals: _portal_armed[pt.id] = pt.id == best.id   # 걷는 동안 출발 끝 포털에 다시 걸리지 않게
			_pt_walk = { t = 0.0, dist = 0.0, stuck = 0, skipped = 0.0, last = here }
			print("WALK start route=%s waypoints=%d to=%s" % [world.region.get("region_id", ""), path.size(), best.id])
			return
	var tp := Vector2(best.x, best.z)
	var q := tp + (Vector2(player_pos.x, player_pos.z) - tp).normalized() * 18.0
	teleport(q.x, q.y)
