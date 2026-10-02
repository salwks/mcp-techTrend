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
# 비교용 끄기: --nofog --nopost --notilt --nobloom --noshadow --nomsaa --nolamps --nochars --noworld --noocc --nofar --nowater
extends Node

const RegionWorld := preload("res://scripts/region/region_world.gd")
const PlacementLoader := preload("res://scripts/region/placement_loader.gd")

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
var placement  # PlacementLoader
var _loading := true      # 시작 불러오기 화면(플레이어 둘레 반경 2타일 건물·식생이 다 붙을 때까지)
var _load_ui: CanvasLayer
var _load_label: Label
var _load_t0 := 0
var _fill: OmniLight3D     # 실내 보조광(지붕을 숨긴 실내가 벽 그림자로 거의 검게 나오는 것을 막는다)
var _fill_k := 0.0
var _reload_t := 0.0

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	_setup_input()
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
	if args.has("warp"):
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
	if args.has("tour"): _run_tour.call_deferred(args.tour)
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
		run = [KEY_SHIFT], time_step = [KEY_T], toggle_post = [KEY_P], reload_place = [KEY_F5],
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
	world.load_region(args.get("data", ""))
	world.use_cutaway = args.has("cutaway")
	# 배치(§8): placement_*.json → 키트 → add_static (+ --placedir=폴더1;폴더2 추가 폴더)
	placement = PlacementLoader.new(world, args.get("placedir", "").split(";", false) if args.has("placedir") else [])
	placement.parallel = not args.has("serialbuild")
	if not args.has("noplace"): placement.load_all()
	if placement.stats.get("placed", 0) > 0 and not args.has("markers"): world.remove_tagged("marker")
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
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}
void fragment() {
	float r = length(UV - 0.5) * 2.0;
	float g = exp(-r * r * 4.0) * (1.0 - smoothstep(0.8, 1.0, r));
	ALBEDO = color * g * k * 2.0;
}
"""

# 권역에서는 타일이 붙고 떨어질 때마다 등불 목록이 바뀐다 → 발광 판을 맞춰 만들고 지운다
func _sync_glows() -> void:
	if _lights_seen == world.lights_version: return
	_lights_seen = world.lights_version
	var have := {}
	var keep := []
	for g in lamp_glows:
		if world.lights.has(g.light):
			keep.append(g); have[g.light] = true
		else:
			g.mesh.queue_free()
	lamp_glows = keep
	for l in world.lights:
		if have.has(l): continue
		var kd: Dictionary = LAMP_KINDS.get(l.kind, LAMP_KINDS.lantern)
		var mi := MeshInstance3D.new()
		var q := QuadMesh.new(); q.size = Vector2.ONE * kd.size * 2.0
		mi.mesh = q
		var m := ShaderMaterial.new(); m.shader = _glow_shader
		var c := Color.hex((int(kd.glow) << 8) | 0xff).srgb_to_linear()
		m.set_shader_parameter("color", Vector3(c.r, c.g, c.b))
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = Vector3(l.x, l.y, l.z)
		scene_vp.add_child(mi)
		lamp_glows.append({ mesh = mi, mat = m, light = l, kind = kd, seed = randf() * 100.0 })

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
	var s := TimeOfDay.sample(hour)
	_state = s
	var dir := TimeOfDay.light_direction(hour, s.dayMix)
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
	world.update_scatter_lod(player_pos, true)
	post.state = s

static func _srgb(v: Vector3) -> Color:
	return Color(v.x, v.y, v.z).linear_to_srgb()

# ---- 밤 등불: 가까운 6개만 실제 빛, 나머지는 발광 판 ----
func _update_lamps(t: float) -> void:
	_sync_glows()
	var f := TimeOfDay.lamp_factor(hour)
	for g in lamp_glows:
		var fl: float = 1.0 + g.kind.flick * (sin(t * 13.0 + g.seed) * 0.6 + sin(t * 7.3 + g.seed * 2.0) * 0.4)
		g.mat.set_shader_parameter("k", f * fl)
		g.mesh.visible = f > 0.001
	if f <= 0.001:
		for o in lamp_slots: o.light_energy = 0.0
		return
	var near: Array = world.lights.duplicate()
	near.sort_custom(func(a, b): return Vector2(a.x - player_pos.x, a.z - player_pos.z).length_squared() < Vector2(b.x - player_pos.x, b.z - player_pos.z).length_squared())
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
		if args.has("openmap") and not _loading and not _map.visible and not _map_opened: _map.toggle(); _map_opened = true
		_map.update(player_pos, player.facing)
	var dt := minf(0.05, delta)
	clock += dt
	if Input.is_action_just_pressed("time_step"):
		hour = fmod(floor(hour / 6.0) * 6.0 + 6.0, 24.0); _apply_time()
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
	if _loading or (_map and _map.visible): mv = Vector2.ZERO # 지도가 열려 있으면 멈춤
	var speed := RUN if Input.is_action_pressed("run") else WALK
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
	placement.update()
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
	title.add_theme_font_size_override("font_size", 72); title.add_theme_color_override("font_color", Color("#2b2622"))
	title.set_anchors_preset(Control.PRESET_CENTER); title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(-200, -90); title.size = Vector2(400, 100)
	bg.add_child(title)
	_load_label = Label.new(); _load_label.add_theme_color_override("font_color", Color("#5a5048"))
	_load_label.set_anchors_preset(Control.PRESET_CENTER); _load_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_load_label.position = Vector2(-200, 30); _load_label.size = Vector2(400, 40)
	bg.add_child(_load_label)
	add_child(_load_ui)

func _update_loading() -> void:
	if not _loading: return
	var c: Vector2i = world.tile_of(player_pos.x, player_pos.z)
	var near_busy: bool = world.stats.jobs > 0 or placement.busy_near(c, 2)
	var left: int = placement.pending_count()
	_load_label.text = "산천을 그리는 중…  식생 %d타일 · 건물 %d 남음" % [world.stats.jobs, left]
	if not near_busy and Time.get_ticks_msec() - _load_t0 > 300:
		_loading = false
		world.loading = false
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
	player_pos.y = world.height_at(player_pos.x, player_pos.z)

func _quit() -> void:
	placement.stop()
	world.shutdown()
	get_tree().quit()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and world != null:
		if placement != null: placement.stop()
		world.shutdown()

static func _abs(p: String) -> String:
	return p if p.is_absolute_path() else ProjectSettings.globalize_path("res://").path_join(p)
