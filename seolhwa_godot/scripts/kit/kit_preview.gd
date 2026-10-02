# 모델 미리보기 — 에이전트가 만든 키트를 게임과 같은 조명·후처리로 찍는다.
#   godot --path seolhwa_godot res://scenes/kit_preview.tscn -- --kit=res://kit/village/choga.gd --params='{"w":6}' \
#         --shot=shots/kit_choga.png [--time=10] [--pitch=38] [--dist=16] [--yaw=0] [--ground=1] [--fit=1]
# 키트 스크립트는 static func build(params: Dictionary) -> Dictionary 를 가져야 한다(docs/REGION_CONTRACTS.md §4).
# --kit 대신 --scene=res://... 로 Node3D를 돌려주는 static func make() 스크립트도 찍을 수 있다.
extends Node

var args := {}
var vp: SubViewport
var cam: Camera3D
var post: PostEffect

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var size := Vector2i(int(args.get("w", "1600")), int(args.get("h", "1200")))
	vp = SubViewport.new()
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.size = size
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var view := TextureRect.new()
	view.texture = vp.get_texture()
	view.set_anchors_preset(Control.PRESET_FULL_RECT)
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(view)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new(); we.environment = env
	vp.add_child(we)
	var sky_mat := ShaderMaterial.new(); sky_mat.shader = load("res://shaders/sky_backdrop.gdshader")
	var sky := MeshInstance3D.new(); var qm := QuadMesh.new(); qm.size = Vector2(2, 2); sky.mesh = qm
	sky.material_override = sky_mat; sky.custom_aabb = AABB(Vector3(-1e5, -1e5, -1e5), Vector3(2e5, 2e5, 2e5))
	sky.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	vp.add_child(sky)

	var hour := float(args.get("time", "10"))
	var s := TimeOfDay.sample(hour)
	var dir := TimeOfDay.light_direction(hour, s.dayMix)
	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 120.0
	sun.shadow_bias = 0.04; sun.shadow_normal_bias = 1.2
	sun.light_color = Color(s.sun.x, s.sun.y, s.sun.z).linear_to_srgb()
	sun.light_energy = s.sunI
	sun.basis = Basis.looking_at(-dir, Vector3.UP)
	vp.add_child(sun)
	for k in ["hemi_sky", "hemi_ground"]: RenderingServer.global_shader_parameter_set(k, s.hemiS if k == "hemi_sky" else s.hemiG)
	RenderingServer.global_shader_parameter_set("hemi_i", s.hemiI)
	RenderingServer.global_shader_parameter_set("fog_color", s.fog)
	RenderingServer.global_shader_parameter_set("fog_density", 0.0 if args.has("nofog") else s.dens)
	RenderingServer.global_shader_parameter_set("glow_k", TimeOfDay.night_factor(hour) * 1.1)
	for kname in ["u_top", "u_hor", "u_low", "u_fog", "u_glow"]:
		sky_mat.set_shader_parameter(kname, s[{ u_top = "skyTop", u_hor = "skyHor", u_low = "low", u_fog = "fog", u_glow = "glow" }[kname]])
	sky_mat.set_shader_parameter("u_glow_i", s.glowI); sky_mat.set_shader_parameter("u_night", s.night)

	cam = Camera3D.new(); cam.near = 0.3; cam.far = 2000.0; cam.fov = float(args.get("fov", "30"))
	post = PostEffect.new()
	post.paper_ratio = 2.0
	post.lum_mult = 2.0 if RenderingServer.get_current_rendering_method() == "mobile" else 1.0
	post.paper_image = Image.load_from_file(ProjectSettings.globalize_path("res://data/paper.png")) if FileAccess.file_exists("res://data/paper.png") else null
	post.state = s
	if args.has("nopost"): post.enabled = false
	var comp := Compositor.new(); comp.compositor_effects = [post]; cam.compositor = comp
	vp.add_child(cam)

	if args.get("ground", "1") == "1":
		var b := Kit.Batch.new()
		b.add("flat", Kit.paint(Kit.plane(400, 400), Kit.hex(0x9aa86a)), 0.0)
		var g := b.build("ground"); vp.add_child(g)

	var target: Node3D = null
	var info := {}
	if args.has("kit"):
		var params: Dictionary = JSON.parse_string(args.get("params", "{}"))
		info = load(args.kit).build(params)
		target = info.node
	elif args.has("scene"):
		target = load(args.scene).make()
	if target: vp.add_child(target)
	_frame_camera(target)
	_shoot.call_deferred(info)

func _frame_camera(target: Node3D) -> void:
	var center := Vector3.ZERO; var radius := 5.0
	if target and args.get("fit", "1") == "1":
		var box := AABB(); var first := true
		for mi in target.find_children("*", "MeshInstance3D", true, false):
			var b: AABB = mi.global_transform * mi.get_aabb()
			box = b if first else box.merge(b); first = false
		if not first:
			center = box.get_center(); radius = maxf(box.size.length() * 0.5, 1.0)
	var pitch := deg_to_rad(float(args.get("pitch", "38")))
	var yaw := deg_to_rad(float(args.get("yaw", "0")))
	var dist := float(args.get("dist", str(radius / tan(deg_to_rad(cam.fov * 0.5)) * 1.1)))
	var off := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * dist
	cam.position = center + off
	cam.look_at(center, Vector3.UP)
	post.focus_y = 0.5

func _shoot(info: Dictionary) -> void:
	for i in 12: await RenderingServer.frame_post_draw
	var path: String = args.get("shot", "shots/kit_preview.png")
	if not path.is_absolute_path(): path = ProjectSettings.globalize_path("res://").path_join(path)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	vp.get_texture().get_image().save_png(path)
	var tris := 0
	if info.has("node"):
		for mi in (info.node as Node3D).find_children("*", "MeshInstance3D", true, false):
			var m: Mesh = mi.mesh
			for s in m.get_surface_count(): tris += m.surface_get_array_len(s) / 3
	print("PREVIEW ", path, " tris=", tris, " colliders=", info.get("colliders", []).size(), " lights=", info.get("lights", []).size())
	if not args.has("stay"): get_tree().quit()
