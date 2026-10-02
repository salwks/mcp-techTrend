# 설화록 Godot 이식(G0) — 진입점. 웹 src/main.js + fx/index.js의 1단계 범위:
# 고정 시점 카메라, 마을, 프레임 캐릭터, 시간대 조명·하늘·안개, 밤 등불, 가림 처리, 실내, 후처리.
#
# 명령줄(-- 뒤에): --time=14 --warp=x,z --shot=out.png --frames=60 --quit --scale=2 --refset=dir
extends Node

const WALK := 2.2
const RUN := 4.6
const FADED := 0.28
const LAMP_KINDS := {
	lantern = { color = 0xffa855, glow = 0xffb866, intensity = 22.0, distance = 9.0, size = 0.8, flick = 0.07 },
	torch = { color = 0xff8a3c, glow = 0xff9a48, intensity = 22.0, distance = 10.0, size = 1.0, flick = 0.16 },
	shrine = { color = 0xff9060, glow = 0xffa868, intensity = 14.0, distance = 7.0, size = 0.42, flick = 0.12 },
	window = { color = 0xffc27a, glow = 0xffcf8a, intensity = 8.0, distance = 7.0, size = 1.15, flick = 0.02 },
}
const REFSET := [
	["village_day", 0.0, 6.0, 10.0], ["village_dusk", 0.0, 6.0, 18.3], ["village_night", 0.0, 6.0, 22.0],
	["bridge_day", 0.0, -14.0, 10.0], ["pass_day", 8.0, -70.0, 10.0],
	["behind_house", -9.0, -8.5, 10.0], ["interior", -22.0, -32.0, 10.0],
]

var args := {}
var post: PostEffect
var scene_vp: SubViewport
var world: World
var cam: Camera3D
var rig: CameraRig
var sun: DirectionalLight3D
var env: Environment
var sky_mat: ShaderMaterial
var player: SpriteChar
var player_pos := Vector3.ZERO
var npcs := []  # { char, pos, home, wander, goal, wait, data }
var lamp_slots := []
var lamp_glows := []
var hour := 10.0
var time_flow := false
var clock := 0.0
var focus_y := 0.45
var fog_on := true
var _occ_frame := 0
var _hidden_interior := []
var _state: Dictionary
var _bench_left := 0.0
var _bench_frames := 0
var _bench_time := 0.0
var _bench_worst := 0.0

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	_setup_input()
	var scale := float(args.get("scale", DisplayServer.screen_get_scale()))
	var win := get_window().size
	scene_vp = SubViewport.new()
	scene_vp.own_world_3d = true
	scene_vp.msaa_3d = Viewport.MSAA_4X
	scene_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	scene_vp.size = Vector2i(int(win.x * scale), int(win.y * scale))
	add_child(scene_vp)
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
	_build_scene()
	if args.has("nomsaa"): scene_vp.msaa_3d = Viewport.MSAA_DISABLED
	if args.has("noshadow"): sun.shadow_enabled = false
	if args.has("nolamps"):
		for o in lamp_slots: o.visible = false
	if args.has("nochars"):
		player.visible = false
		for n in npcs: n.char.visible = false
	if args.has("noworld"): world.visible = false
	if args.has("noocc"): world.occluders.clear()
	if args.has("notilt"): post.tilt = false
	if args.has("nobloom"): post.bloom = false
	if args.has("nopost"): post.enabled = false
	if args.has("time"): hour = float(args.time)
	if args.has("warp"):
		var p: PackedStringArray = args.warp.split(",")
		teleport(float(p[0]), float(p[1]))
	_apply_time()
	rig.update(0, player_pos, player.facing, null, true)
	if args.has("bench"):
		_bench_left = float(args.bench)
		Engine.max_fps = 0
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	if args.has("refset"): _run_refset.call_deferred(args.refset)
	elif args.has("shot"): _run_shot.call_deferred(args.shot, int(args.get("frames", "30")))

func _setup_input() -> void:
	var keys := {
		move_up = [KEY_W, KEY_UP], move_down = [KEY_S, KEY_DOWN], move_left = [KEY_A, KEY_LEFT], move_right = [KEY_D, KEY_RIGHT],
		run = [KEY_SHIFT], time_step = [KEY_T], toggle_post = [KEY_P],
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
	sun.directional_shadow_max_distance = 60.0
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.2
	sun.shadow_blur = 1.5
	root.add_child(sun)

	cam = Camera3D.new()
	cam.near = 0.5; cam.far = 600.0; cam.fov = 30.0
	var comp := Compositor.new()
	comp.compositor_effects = [post]
	cam.compositor = comp
	root.add_child(cam)
	cam.current = true

	world = World.new()
	root.add_child(world)
	world.load_all()
	rig = CameraRig.new(cam, world)

	for i in 6:
		var o := OmniLight3D.new()
		o.omni_attenuation = 2.0
		o.light_energy = 0.0
		o.shadow_enabled = false
		root.add_child(o)
		lamp_slots.append(o)
	_build_lamp_glows(root)

	SpriteChar.load_bank("player", "frames.json")
	SpriteChar.load_bank("elder", "frames_npc.json")
	player = SpriteChar.new("player")
	player.facing = "up"
	root.add_child(player)
	teleport(world.spawn.x, world.spawn.y)
	for n in world.npcs:
		if n.kind == "tiger": continue  # 1단계: 호랑이는 고갯마루 대기(이야기 모듈이 숨김) — G0 2차에서 이식
		var c := SpriteChar.new(n.kind)
		c.facing = n.facing
		root.add_child(c)
		var p := Vector3(n.x, world.height_at(n.x, n.z), n.z)
		c.position = p
		npcs.append({ char = c, pos = p, home = Vector2(n.x, n.z), wander = float(n.wander) if n.wander else 0.0, goal = null, wait = 1.0 + randf() * 3.0, data = n })

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

func _build_lamp_glows(root: Node) -> void:
	var sh := Shader.new(); sh.code = GLOW_CODE
	for l in world.lights:
		var kd: Dictionary = LAMP_KINDS.get(l.kind, LAMP_KINDS.lantern)
		var mi := MeshInstance3D.new()
		var q := QuadMesh.new(); q.size = Vector2.ONE * kd.size * 2.0
		mi.mesh = q
		var m := ShaderMaterial.new(); m.shader = sh
		var c := Color.hex((int(kd.glow) << 8) | 0xff).srgb_to_linear()
		m.set_shader_parameter("color", Vector3(c.r, c.g, c.b))
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = Vector3(l.x, l.y, l.z)
		root.add_child(mi)
		lamp_glows.append({ mesh = mi, mat = m, light = l, kind = kd, seed = randf() * 100.0 })

func teleport(x: float, z: float) -> void:
	var p := _nearest_free(x, z, player.radius)
	player_pos = Vector3(p.x, world.height_at(p.x, p.y), p.y)
	player.position = player_pos

func _nearest_free(x: float, z: float, r: float) -> Vector2:
	var rad := 0.0
	while rad < 12.0:
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
	post.state = s

static func _srgb(v: Vector3) -> Color:
	return Color(v.x, v.y, v.z).linear_to_srgb()

# ---- 밤 등불: 가까운 6개만 실제 빛, 나머지는 발광 판 ----
func _update_lamps(t: float) -> void:
	var f := TimeOfDay.lamp_factor(hour)
	for g in lamp_glows:
		var fl: float = 1.0 + g.kind.flick * (sin(t * 13.0 + g.seed) * 0.6 + sin(t * 7.3 + g.seed * 2.0) * 0.4)
		g.mat.set_shader_parameter("k", f * fl)
		g.mesh.visible = f > 0.001
	if f <= 0.001:
		for o in lamp_slots: o.light_energy = 0.0
		return
	var near := world.lights.duplicate()
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

# ---- 가림 처리(웹 core/occlusion.js): 카메라→플레이어 선분에 걸린 큰 물체를 반투명하게 ----
func _update_occlusion(dt: float, interior) -> void:
	var want: Array = interior.hide if interior != null else []
	for o in _hidden_interior:
		if not want.has(o): o.visible = true
	for o in want: o.visible = false
	_hidden_interior = want.duplicate()
	_occ_frame = (_occ_frame + 1) % 3
	if _occ_frame == 0:
		for occ in world.occluders: occ.target = 1.0
		if interior == null:
			var c := cam.global_position
			for occ in world.occluders:
				if not occ.node.visible: continue
				var box: AABB = occ.aabb
				for h in [0.35, player.height * 0.6, player.height]:
					var p := player_pos + Vector3(0, h, 0)
					var d := p - c
					var end := c + d.normalized() * (d.length() - 0.4)
					if _seg_box(c, end, box) and _seg_hits_mesh(occ, c, end):
						occ.target = FADED; break
	var k := 1.0 - exp(-dt * 8.0)
	for occ in world.occluders:
		if absf(occ.alpha - occ.target) < 0.002: continue
		occ.alpha += (occ.target - occ.alpha) * k
		if absf(occ.alpha - occ.target) < 0.01: occ.alpha = occ.target
		world.set_occluder_alpha(occ, occ.alpha)

static func _seg_box(a: Vector3, b: Vector3, box: AABB) -> bool:
	return box.intersects_segment(a, b) != null or box.has_point(a)

# 메시 단위 AABB로 한 번 더 걸러 낸다(나무 줄기 옆을 지나는 시선 등)
static func _seg_hits_mesh(occ: Dictionary, a: Vector3, b: Vector3) -> bool:
	for mi in occ.meshes:
		var bb: AABB = mi.global_transform * mi.get_aabb()
		if bb.intersects_segment(a, b) != null: return true
	return false

# ---- 루프 ----
func _process(delta: float) -> void:
	var dt := minf(0.05, delta)
	clock += dt
	if Input.is_action_just_pressed("time_step"):
		hour = fmod(floor(hour / 6.0) * 6.0 + 6.0, 24.0); _apply_time()
	if Input.is_action_just_pressed("toggle_post"):
		post.tilt = not post.tilt; post.paper = post.tilt
	if time_flow:
		hour = fmod(hour + dt * 0.1, 24.0); _apply_time()
	var mv := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if _bench_left > 0.0:
		mv = Vector2(sin(clock * 0.35), -cos(clock * 0.23)).normalized()
		_bench_left -= delta
		_bench_frames += 1; _bench_time += delta
		if _bench_time > 2.0: _bench_worst = maxf(_bench_worst, delta)
		if _bench_left <= 0.0:
			print("BENCH avg_fps=%.1f worst_ms=%.1f frames=%d render=%s" % [_bench_frames / _bench_time, _bench_worst * 1000.0, _bench_frames, scene_vp.size])
			get_tree().quit()
	if mv.length() > 0.0:
		var speed := RUN if Input.is_action_pressed("run") else WALK
		var r := player.radius
		var others := npcs
		var extra := func(tx: float, tz: float) -> bool:
			for n in others:
				var d := Vector2(n.pos.x - tx, n.pos.z - tz).length()
				if d < r + n.char.radius - 0.05 and d < Vector2(n.pos.x - player_pos.x, n.pos.z - player_pos.z).length(): return true
			return false
		var np = world.move_circle(player_pos, mv.x * speed * dt, mv.y * speed * dt, r, extra)
		player.facing = facing_from(mv.x, mv.y, player.facing)
		if np != null:
			player_pos = Vector3(np.x, world.height_at(np.x, np.z), np.z)
			player.set_anim("run" if Input.is_action_pressed("run") else "walk")
		else:
			player.set_anim("idle")
	else:
		player.set_anim("idle")
	player.position = player_pos
	_update_npcs(dt)
	var interior = world.interior_at(player_pos.x, player_pos.z)
	rig.update(dt, player_pos, player.facing, interior)
	_update_occlusion(dt, interior)
	world.update(dt, clock)
	_update_lamps(clock)
	sky_mat.set_shader_parameter("u_time", clock)
	player.update_char(dt, cam)
	for n in npcs: n.char.update_char(dt, cam)
	# 틸트시프트 초점 띠 = 플레이어 몸 중앙의 화면 Y(아래가 0)
	var sp := cam.unproject_position(player_pos + Vector3(0, 0.8, 0))
	var y := clampf(1.0 - sp.y / float(scene_vp.size.y), 0.15, 0.85)
	focus_y += (y - focus_y) * minf(1.0, dt * 6.0)
	post.focus_y = focus_y

func _update_npcs(dt: float) -> void:
	for n in npcs:
		var c: SpriteChar = n.char
		var near := Vector2(n.pos.x - player_pos.x, n.pos.z - player_pos.z).length() < 2.4
		if near:
			c.facing = facing_from(player_pos.x - n.pos.x, player_pos.z - n.pos.z, c.facing)
			c.set_anim("idle"); continue
		if n.wander <= 0.0:
			c.set_anim("idle"); continue
		if n.goal == null:
			n.wait -= dt
			c.set_anim("idle")
			if n.wait <= 0.0:
				var a := randf() * TAU; var d: float = randf() * n.wander
				n.goal = { x = n.home.x + cos(a) * d, z = n.home.y + sin(a) * d, t = 6.0 }
			continue
		var dx: float = n.goal.x - n.pos.x; var dz: float = n.goal.z - n.pos.z
		var len := Vector2(dx, dz).length()
		n.goal.t -= dt
		if len < 0.15 or n.goal.t <= 0.0:
			n.goal = null; n.wait = 2.0 + randf() * 4.0; continue
		var np = world.move_circle(n.pos, dx / len * 1.1 * dt, dz / len * 1.1 * dt, c.radius)
		c.facing = facing_from(dx, dz, c.facing)
		if np == null:
			n.goal = null; n.wait = 1.0 + randf() * 2.0; c.set_anim("idle"); continue
		n.pos = Vector3(np.x, world.height_at(np.x, np.z), np.z)
		c.position = n.pos
		c.set_anim("walk")

# ---- 자동 스크린샷 ----
func _wait_frames(n: int) -> void:
	for i in n: await RenderingServer.frame_post_draw

func _save(path: String) -> void:
	var img := scene_vp.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	img.save_png(path)
	print("SHOT ", path, " ", img.get_size(), " fps=", Engine.get_frames_per_second())
	if args.has("debugocc"):
		for o in world.occluders:
			if o.alpha < 0.999 or o.target < 1.0: print("   occ ", o.node.name, " ", world.data.origNames.get(String(o.node.name), "?"), " a=%.3f t=%.2f" % [o.alpha, o.target])

func _shot_at(x: float, z: float, h: float) -> void:
	hour = h
	teleport(x, z)
	_apply_time()
	await _wait_frames(40)
	rig.update(0, player_pos, player.facing, world.interior_at(player_pos.x, player_pos.z), true)
	await _wait_frames(4)

func _run_shot(path: String, frames: int) -> void:
	await _wait_frames(frames)
	_save(_abs(path))
	if args.has("quit"): get_tree().quit()

func _run_refset(dir: String) -> void:
	await _wait_frames(10)
	for r in REFSET:
		await _shot_at(r[1], r[2], r[3])
		_save(_abs(dir).path_join("godot_%s.png" % r[0]))
	get_tree().quit()

static func _abs(p: String) -> String:
	return p if p.is_absolute_path() else ProjectSettings.globalize_path("res://").path_join(p)
