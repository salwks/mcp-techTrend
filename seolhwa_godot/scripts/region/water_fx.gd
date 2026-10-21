# 물(water pass, 2026-10-17): 물결(파도)·반사의 공용 자리.
#
# - 물결: 네 갈래 사인 물결의 합(shaders/water_common.gdshaderinc w_wave와 **같은 식**). 바다는 큰 너울, 강·못은 잔물결.
#   셰이더와 배(boat_ride·river_lanes·region_world 나룻배)가 같은 시각(water_t)·같은 바람 방향으로 읽어 배가 물결을 탄다.
# - 반사: 설정 '화면 품질' 높음이면 평면 반사 — 플레이어(또는 카메라 초점) 가까운 물면 높이를 거울면으로, 카메라를 그 면에 비춘
#   반사 카메라가 장면을 1/2 해상도 SubViewport(장면 뷰포트와 같은 world_3d)에 그린다. 물 셰이더는 반사 카메라의 투영 행렬
#   (water_refl_m)로 자기 자리를 투영해 그 그림을 읽고, 물결 법선만큼 흔든다. 가까이에 물이 없거나 낮음이면 그리지 않고
#   (UPDATE_DISABLED) 물은 하늘빛 반사(water_sky_*)만 쓴다.
# - 물 메시는 WATER_LAYER에만 둔다 — 반사 카메라가 물 자신을 그리지 않게.
extends Node

const WATER_LAYER := 1 << 18       # 19번 층(플레이어 그림은 20번 — region_main.PLAYER_LAYER)
const SMALL_LAYER := 1 << 16       # 17번 층: 작은 정적 물체(region_world._mark_small) — 반사에 그리지 않는다
const FAR_LAYER := 1 << 17         # 18번 층: 원경(먹빛 능선 고리) — 3인칭 반사에는 그리지 않는다(물에 비칠 자리가 화면에 없다)
const REFL_DIV := 2                # 반사 그림 = 장면 해상도 / 2 (3인칭)
const REFL_DIV_FP := 3             # 1인칭: / 3 — 1인칭은 장면이 무거워(먼 경치) 반사 그림을 더 작게
const REFL_EVERY := 2              # 반사 그림은 2프레임에 한 번(--reflrate=1 매 프레임)
const REFL_FAR := 200.0            # 1인칭(먼 물까지 보임 — 그 너머는 안개·하늘빛)
const REFL_FAR_TOWN := 140.0       # 3인칭 비스듬한 시점: 물은 카메라 둘레 수십 m만 보이므로 반사도 가까운 것만
const SEARCH_R := 70.0             # 이 안에 물이 있어야 반사를 그린다

# 물결 네 갈래(셰이더 WV_*와 같아야 한다): 바람 방향 기준 각(rad), 파장(m), 상대 높이, 위상
const WV_ANG := [0.35, -0.6, 1.25, 0.05]
const WV_LEN := [21.0, 12.5, 7.3, 4.1]
const WV_AMP := [1.0, 0.55, 0.32, 0.18]
const WV_PH := [0.0, 1.7, 4.1, 2.6]
# 물 종류별 (높이 m, 파장 배율)
const SEA := Vector2(0.20, 1.0)
const RIVER := Vector2(0.022, 0.22)
const POND := Vector2(0.012, 0.16)
const BIG_RIVER := Vector2(0.035, 0.35)   # 큰 강 물면(region_sea_body wave_a·wave_ls — region_world가 넣는 값)

const GLOBALS := {
	water_t = [RenderingServer.GLOBAL_VAR_TYPE_FLOAT, 0.0],
	water_k = [RenderingServer.GLOBAL_VAR_TYPE_FLOAT, 1.0],            # 바람 세기 → 물결 배율
	water_wind = [RenderingServer.GLOBAL_VAR_TYPE_VEC2, Vector2(1, 0)],  # 바람 방향(xz 단위 벡터)
	water_rain = [RenderingServer.GLOBAL_VAR_TYPE_FLOAT, 0.0],          # 빗방울 동그라미
	water_refl_on = [RenderingServer.GLOBAL_VAR_TYPE_FLOAT, 0.0],
	water_refl_y = [RenderingServer.GLOBAL_VAR_TYPE_FLOAT, 0.0],
	water_refl_m = [RenderingServer.GLOBAL_VAR_TYPE_MAT4, Projection.IDENTITY],
	water_sky_top = [RenderingServer.GLOBAL_VAR_TYPE_VEC3, Vector3(0.35, 0.5, 0.65)],
	water_sky_hor = [RenderingServer.GLOBAL_VAR_TYPE_VEC3, Vector3(0.6, 0.66, 0.7)],
	water_ink = [RenderingServer.GLOBAL_VAR_TYPE_FLOAT, 0.0],           # 물가 먹선(사용자 결정 전 — 기본 끔, --waterink로 켬)
}

static var _globals_ok := false
static var _nrm: ImageTexture
static var t_now := 0.0
static var k_now := 1.0
static var wind_now := Vector2(1, 0)

# 셰이더가 쓰는 전역 uniform을 등록한다(project.godot를 건드리지 않게 — 편집기가 덮어쓰지 않도록 실행 중에).
# 물 셰이더를 load하기 전에 불러야 한다(region_world._make_materials·Kit 물 재질).
static func ensure_globals() -> void:
	if _globals_ok: return
	_globals_ok = true
	for n in GLOBALS: RenderingServer.global_shader_parameter_add(n, GLOBALS[n][0], GLOBALS[n][1])

# 잔물결 법선 지도(RGB 법선, A 높이) — 이음매 없는 잡음에서 한 번 만든다
static func normal_tex() -> ImageTexture:
	if _nrm != null: return _nrm
	var fn := FastNoiseLite.new()
	fn.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	fn.seed = 4242
	fn.frequency = 1.0 / 32.0
	fn.fractal_type = FastNoiseLite.FRACTAL_FBM
	fn.fractal_octaves = 3
	fn.fractal_gain = 0.45
	var h := fn.get_seamless_image(256, 256, false, false, 0.15, true)
	h.convert(Image.FORMAT_RGBA8)
	var n: Image = h.duplicate()
	n.bump_map_to_normal_map(14.0)
	var hd := h.get_data(); var nd := n.get_data()
	for i in range(0, nd.size(), 4): nd[i + 3] = hd[i]
	var img := Image.create_from_data(256, 256, false, Image.FORMAT_RGBA8, nd)
	img.generate_mipmaps()
	_nrm = ImageTexture.create_from_image(img)
	return _nrm

static func now() -> float:
	return fmod(Time.get_ticks_msec() / 1000.0, 3600.0)

# 물결 높이와 기울기 Vector3(h, dh/dx, dh/dz). kind = SEA/RIVER/POND (셰이더 w_wave와 같은 식)
static func wave(x: float, z: float, kind: Vector2, t := NAN) -> Vector3:
	if is_nan(t): t = t_now
	var amp := kind.x * (k_now if kind == SEA else lerpf(1.0, k_now, 0.5))
	var r := Vector3.ZERO
	var wa := atan2(wind_now.y, wind_now.x)
	for i in 4:
		var L: float = WV_LEN[i] * kind.y
		var k := TAU / L
		var w := sqrt(9.81 * k)
		var ang: float = WV_ANG[i] + wa
		var d := Vector2(cos(ang), sin(ang))
		var ph: float = (d.x * x + d.y * z) * k - w * t + WV_PH[i]
		var a: float = WV_AMP[i] * amp
		r.x += a * sin(ph)
		var c := a * k * cos(ph)
		r.y += c * d.x; r.z += c * d.y
	return r

# 배 자세: 자리(p)·뱃머리 방향 기준 Basis(yaw 포함)를 받아 물결 높이·기울기를 얹은 Transform3D. depth(물 깊이 m)가 얕으면 줄인다
static func boat_xf(bs: Basis, p: Vector2, y0: float, kind: Vector2, depth := 10.0) -> Transform3D:
	var att := lerpf(0.35, 1.0, smoothstep(0.0, 4.0, depth)) if kind == SEA else 1.0
	var w := wave(p.x, p.y, kind) * att
	# 배 길이만큼 평균낸 기울기 — 짧은 물결에 배가 떨지 않게(큰 너울만 탄다)
	var w2 := wave(p.x + 2.0, p.y + 1.0, kind) * att
	var sx := (w.y + w2.y) * 0.5; var sz := (w.z + w2.z) * 0.5
	var up := Vector3(-sx * 0.6, 1.0, -sz * 0.6).normalized()
	var tilt := Basis(Quaternion(Vector3.UP, up))
	return Transform3D(tilt * bs, Vector3(p.x, y0 + w.x * 0.7, p.y))

# ---------------------------------------------------------------------------
var main
var world
var vp: SubViewport
var rcam: Camera3D
var mats: Array = []          # 반사 그림·법선 지도를 받을 물 재질
var planar := true            # 화면 품질 높음
var on := false
var plane_y := 0.0
var _scan_t := 0.0
var _skip := 0
var _last_z := Vector3.BACK
var _have_plane := false
var stats := { on = false, y = 0.0, size = Vector2i.ZERO }

func setup(m) -> void:
	main = m
	world = m.world
	process_priority = 1000   # 카메라(region_main._process)가 움직인 뒤
	ensure_globals()
	planar = not m.gfx_low() and not m.args.has("nowaterrefl")
	RenderingServer.global_shader_parameter_set("water_ink", 1.0 if m.args.has("waterink") else 0.0)
	vp = SubViewport.new()
	vp.name = "water_reflection"
	vp.own_world_3d = false          # 장면 뷰포트(scene_vp)의 world_3d를 그대로(자식이라 찾아 쓴다)
	vp.msaa_3d = Viewport.MSAA_DISABLED
	vp.positional_shadow_atlas_size = 0
	vp.mesh_lod_threshold = 6.0
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	vp.size = Vector2i(64, 36)
	m.scene_vp.add_child(vp)
	rcam = Camera3D.new()
	rcam.keep_aspect = Camera3D.KEEP_HEIGHT
	rcam.near = 0.3
	if world.has_method("set_far_layers"): world.set_far_layers(FAR_LAYER)
	elif world.far_node != null: world.far_node.layers = FAR_LAYER
	vp.add_child(rcam)
	rcam.current = true
	collect_materials()
	if m.args.has("bench") or m.args.has("watergpu"):   # GPU 시간(장면·반사 뷰포트) — fps가 화면 동기에 묶여도 비용을 읽게
		RenderingServer.viewport_set_measure_render_time(m.scene_vp.get_viewport_rid(), true)
		RenderingServer.viewport_set_measure_render_time(vp.get_viewport_rid(), true)
		_gpu = { n = 0, scene = 0.0, refl = 0.0, t = 0.0 }

func collect_materials() -> void:
	mats.clear()
	for mm in [world.mat_water, world._mat_dry] + world.surface_mats:
		if mm != null and not mats.has(mm): mats.append(mm)
	mats.append(Kit.material("water_refl"))
	var tex := vp.get_texture()
	for mm in mats:
		mm.set_shader_parameter("wnrm_tex", normal_tex())
		mm.set_shader_parameter("water_refl_tex", tex)

func _process(_dt: float) -> void:
	if main == null or main.cam == null: return
	t_now = now()
	var wk := 1.0
	var rain := 0.0
	var wd := Vector2(1, 0.3).normalized()
	var we = main.weather
	if we != null:
		wk = 0.75 + 1.4 * float(we.cur.get("wind", 0.1))
		rain = float(we.cur.get("rain", 0.0))
		if "_wind_dir" in we: wd = we._wind_dir
	k_now = wk; wind_now = wd
	RenderingServer.global_shader_parameter_set("water_t", t_now)
	RenderingServer.global_shader_parameter_set("water_k", wk)
	RenderingServer.global_shader_parameter_set("water_wind", wd)
	RenderingServer.global_shader_parameter_set("water_rain", rain if not main.world.indoor else 0.0)
	var st: Dictionary = main._state
	if not st.is_empty():
		RenderingServer.global_shader_parameter_set("water_sky_top", st.skyTop)
		RenderingServer.global_shader_parameter_set("water_sky_hor", (st.skyHor as Vector3).lerp(st.fog, 0.15))
	_update_patch()
	_update_reflection()
	_test_hooks()
	if not _gpu.is_empty() and not main._loading:
		_gpu.t += get_process_delta_time()
		if _gpu.t > 3.0:
			var a := RenderingServer.viewport_get_measured_render_time_gpu(main.scene_vp.get_viewport_rid())
			var b := RenderingServer.viewport_get_measured_render_time_gpu(vp.get_viewport_rid()) if on else 0.0
			_gpu.n += 1; _gpu.scene += a; _gpu.refl += b
			_gpu_sc.append(a + b)
			if _gpu.n % 300 == 0:
				var srt := _gpu_sc.duplicate(); srt.sort()
				print("WATERGPU n=%d scene_ms=%.2f refl_ms=%.2f total_p99_ms=%.2f refl=%s" % [_gpu.n, _gpu.scene / _gpu.n, _gpu.refl / _gpu.n, srt[int(srt.size() * 0.99)], on])

var _gpu := {}
var _gpu_sc := PackedFloat32Array()

# 촬영 보조: --fpyaw=도[,숙임도] 1인칭 바라보는 쪽 고정, --watershots=n 0.3초 간격 n장(물결 움직임)
var _shot_wait := 90
var _shot_i := 0
var _shot_t := 0.0
var _dbg_done := false
func _test_hooks() -> void:
	var a: Dictionary = main.args
	if a.has("waterdebug") and on and not _dbg_done and Engine.get_process_frames() > 200:
		_dbg_done = true
		for n in main.scene_vp.find_children("*", "GeometryInstance3D", true, false):
			var gi := n as GeometryInstance3D
			if (gi.layers & rcam.cull_mask) == 0 or not gi.is_visible_in_tree(): continue
			var ms := [gi.material_override]
			if gi is MeshInstance3D and gi.mesh != null:
				for si in gi.mesh.get_surface_count(): ms.append(gi.mesh.surface_get_material(si)); ms.append(gi.get_surface_override_material(si))
			for mm in ms:
				if mm != null and mats.has(mm): print("WATERDBG drawn-in-refl ", gi.get_path(), " layers=", gi.layers)
		print("WATERDBG rcam=", rcam.global_transform, " cam=", main.cam.global_transform)
		# 반사 카메라 절두체 안 삼각형 대략(무리별)
		for cm: Camera3D in [rcam, main.cam]:
			var planes: Array = cm.get_frustum()
			var grp := {}
			for n in main.scene_vp.find_children("*", "GeometryInstance3D", true, false):
				var gi := n as GeometryInstance3D
				if (gi.layers & cm.cull_mask) == 0 or not gi.is_visible_in_tree(): continue
				var bb := gi.global_transform * gi.get_aabb()
				var inside := true
				for pl: Plane in planes:
					var c := bb.get_center(); var e := bb.size * 0.5
					var r := absf(pl.normal.x) * e.x + absf(pl.normal.y) * e.y + absf(pl.normal.z) * e.z
					if pl.distance_to(c) > r: inside = false; break
				if not inside: continue
				var tri := 0
				if gi is MeshInstance3D and gi.mesh is ArrayMesh:
					for si in gi.mesh.get_surface_count():
						var il: int = gi.mesh.surface_get_array_index_len(si)
						tri += (il if il > 0 else gi.mesh.surface_get_array_len(si)) / 3
				elif gi is MultiMeshInstance3D and gi.multimesh != null and gi.multimesh.mesh is ArrayMesh:
					var mm2: Mesh = gi.multimesh.mesh
					for si in mm2.get_surface_count():
						var il: int = mm2.surface_get_array_index_len(si)
						tri += (il if il > 0 else mm2.surface_get_array_len(si)) / 3 * gi.multimesh.visible_instance_count if gi.multimesh.visible_instance_count >= 0 else gi.multimesh.instance_count
				var path := str(gi.get_path()).split("/")
				var key := "/".join(path.slice(4, 6)) if path.size() > 6 else str(gi.get_path())
				if not grp.has(key): grp[key] = [0, 0]
				grp[key][0] += 1; grp[key][1] += tri
			var keys := grp.keys(); keys.sort_custom(func(x, y): return grp[x][1] > grp[y][1])
			print("WATERDBG cam=", cm.name, " far=", cm.far)
			for k in keys.slice(0, 12): print("WATERDBG   ", k, " n=", grp[k][0], " tris=", grp[k][1])
	if a.has("fpyaw") and main.fp_view():
		var v: PackedStringArray = String(a.fpyaw).split(",")
		main.fp_yaw = deg_to_rad(float(v[0]))
		if v.size() > 1: main.fp_pitch = deg_to_rad(float(v[1]))
	if not a.has("watershots") or main._loading: return
	if _shot_wait > 0: _shot_wait -= 1; return
	_shot_t -= get_process_delta_time()
	if _shot_t > 0.0: return
	_shot_t = 0.3
	var dir := String(a.get("shotdir", "shots/water"))
	if not dir.is_absolute_path(): dir = ProjectSettings.globalize_path("res://").path_join(dir)
	DirAccess.make_dir_recursive_absolute(dir)
	var img: Image = main.scene_vp.get_texture().get_image()
	img.save_png(dir.path_join("water_seq_%d.png" % _shot_i))
	print("WATERSHOT %d t=%.2f refl=%s y=%.2f" % [_shot_i, t_now, str(on), plane_y])
	_shot_i += 1
	if _shot_i >= int(a.watershots): main._quit()

# 바다 물결 판(region_world.sea_patch): 카메라 초점을 따라 격자 간격으로 끊어 옮긴다(꼭짓점이 미끄러지지 않게)
func _update_patch() -> void:
	var p: MeshInstance3D = world.sea_patch
	if p == null: return
	var f: Vector3 = main.cam.global_position - main.cam.global_transform.basis.z * 60.0
	if main.fp_view(): f = main.cam.global_position - main.cam.global_transform.basis.z * 90.0
	var s: float = world.SEA_PATCH_STEP
	var c := Vector3(snappedf(f.x, s * 4.0), world.sea_y, snappedf(f.z, s * 4.0))
	p.position = c
	var hv := Vector4(c.x, c.z, world.SEA_PATCH_HALF, 0.0)
	p.material_override.set_shader_parameter("wave_patch", hv)
	world.sea_far_mat.set_shader_parameter("hole", hv)

# 거울면 높이: 둘레 25m 안에 못이 있으면 못, 아니면 가까운 하천·바다·호수(region_world.river_surface_at)
func _plane_near(pos: Vector3) -> float:
	var pp := Vector2(pos.x, pos.z)
	var best := 25.0; var py := NAN
	for pd in world._ponds:
		var bb: Rect2 = pd.bb
		var d := maxf(0.0, maxf(bb.position.x - pp.x, pp.x - bb.end.x)) + maxf(0.0, maxf(bb.position.y - pp.y, pp.y - bb.end.y))
		if d < best: best = d; py = float(pd.y)
	if not is_nan(py): return py
	return world.river_surface_at(pos.x, pos.z, SEARCH_R)

func _update_reflection() -> void:
	var cam: Camera3D = main.cam
	var want: bool = planar and not main._loading and world.indoor == null and main._fg_max_fps < 0
	_scan_t -= get_process_delta_time()
	if want and _scan_t <= 0.0:
		_scan_t = 0.25
		var focus: Vector3 = main.player_pos
		var y := _plane_near(focus)
		_have_plane = not is_nan(y)
		if _have_plane: plane_y = y
	want = want and _have_plane and cam.global_position.y > plane_y + 0.2
	if want != on:
		on = want
		vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		_skip = 0
		RenderingServer.global_shader_parameter_set("water_refl_on", 1.0 if on else 0.0)
		print("WATER refl=%s plane_y=%.2f planar=%s" % [on, plane_y, planar])
	stats.on = on; stats.y = plane_y
	if not on: return
	# 반사는 REFL_EVERY 프레임에 한 번 그린다(그 사이 프레임은 지난 그림과 그때의 행렬을 그대로 — 한 프레임 늦을 뿐 자리는 맞다).
	# 1인칭에서 고개를 빨리 돌릴 때(초당 60° 넘게)는 매 프레임
	var turn := rad_to_deg(cam.global_transform.basis.z.angle_to(_last_z)) / maxf(get_process_delta_time(), 1e-3)
	_last_z = cam.global_transform.basis.z
	var every := int(main.args.get("reflrate", str(REFL_EVERY)))
	_skip += 1
	if _skip < every and turn < 60.0:
		vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return
	_skip = 0
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var want_size: Vector2i = main.scene_vp.size / int(main.args.get("refldiv", str(REFL_DIV_FP if main.fp_view() else REFL_DIV)))
	if vp.size != want_size: vp.size = want_size
	stats.size = vp.size
	# 거울 카메라: 자리와 바라보는 쪽을 물면(y = plane_y)에 비춘다. 위쪽은 세계 위(반사 그림을 투영 행렬로 읽으므로 뒤집힘은 상관없다)
	var xf := cam.global_transform
	var o := xf.origin; o.y = 2.0 * plane_y - o.y
	var f := -xf.basis.z; f.y = -f.y
	var upv := Vector3.UP if absf(f.y) < 0.98 else Vector3(xf.basis.y.x, -xf.basis.y.y, xf.basis.y.z)
	rcam.global_transform = Transform3D(Basis.looking_at(f, upv), o)
	rcam.fov = cam.fov * 1.12   # 물결로 흔들어 읽는 몫만큼 넓게
	var fp: bool = main.fp_view()
	rcam.far = float(main.args.get("reflfar", str(REFL_FAR if fp else REFL_FAR_TOWN)))
	rcam.cull_mask = cam.cull_mask & ~WATER_LAYER & ~SMALL_LAYER & (~0 if fp else ~FAR_LAYER)
	var m := rcam.get_camera_projection() * Projection(rcam.global_transform.affine_inverse())
	RenderingServer.global_shader_parameter_set("water_refl_y", plane_y)
	RenderingServer.global_shader_parameter_set("water_refl_m", m)
