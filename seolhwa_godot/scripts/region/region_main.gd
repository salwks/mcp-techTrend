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
#   --sailspeed=25    배 속도를 바꿔 시험(강 뱃길 기본 route.json speed 7.5m/s, 나루 5.5, 바다 9)
#   --ridetest[=id] [--rideend=0|1] [--rideskip]  불러오기가 끝나면 그 배(없으면 첫 배)의 내릴 자리로 가 배를 타고 건너며
#                     풍경 시점을 --shotdir(기본 shots/region/boat)에 찍고, 닿으면 끝낸다(배 타기 boat_ride.gd)
#   --ridetest=<거점>:<거점>  자동 기승 시험(scripts/region/ride_test.gd): 앞 거점 어귀에서 말에 올라 뒤 거점까지 가며 멈춤·감속·하차 자리를 본다
#                     (예: --region=JL_NAMWON_UNBONG --ridetest=namwon_eup:unbong_eup, --route=… --ridetest=end_from:end_to). 콜론이 없으면 배 시험
#   --ridefixture=res://…json  시험 출발 저장(vars·cases·routes_done)을 --savefile에 깐다   --ridevars=K=V,K=V  공통 변수 더하기
#   --ridespeed=16    말 최고 속도 바꾸기   --ridelog  자동 기승 로그   --fasttravel=<공간>/<거점>  역마(거점 빠른 이동) 시험
#   --talktest=<거점>,<거점>…  고을 사람 말 걸기 시험(scripts/story/talk_test.gd): 거점마다 사람에게 말을 걸고, --talkfixture 저장(결말)을
#                     얹은 뒤 다시 — 소문·결말 반응·'들음' 기록·이야기 인물 「…」 표시를 본다(--talkvars=K=V,… --talkexpect=var|need --talkmin=8)
#   --portaltest[=n]  불러오기가 끝나면 포털로 걸어가 n번 공간을 넘어가며 도착 화면을 --shotdir(기본 shots/region/travel)에 찍는다
#   --nowallproxy     region.json walls 대신 벽(키트가 없는 성벽 구간) 끄기
#   --kitcache=user://폴더/  키트 디스크 캐시 폴더(기본 user://kit_cache/)   --nokitcache  캐시 끄기
# 비교용 끄기: --nofog --nopost --nodof(=--notilt, 깊이 흐림) --nobloom --noshadow --nomsaa --nolamps --nochars --noworld --noocc --nofar --nowater
extends Node

const RegionWorld := preload("res://scripts/region/region_world.gd")
const PlacementLoader := preload("res://scripts/region/placement_loader.gd")
const Travel := preload("res://scripts/region/travel.gd")
const Weather := preload("res://scripts/region/weather.gd")
const NpcAmbient := preload("res://scripts/region/npc_ambient.gd")
const Progress := preload("res://scripts/region/progress.gd")
const DevTravel := preload("res://scripts/region/dev_travel.gd")
const RiverLanes := preload("res://scripts/region/river_lanes.gd")
const BoatRide := preload("res://scripts/region/boat_ride.gd")
const InteriorSpace := preload("res://scripts/region/interior_space.gd")
const StoryDirector := preload("res://scripts/story/story_director.gd")
const HorseRide := preload("res://scripts/region/horse_ride.gd")
const FastTravel := preload("res://scripts/region/fast_travel.gd")
const StoryUI := preload("res://scripts/story/story_ui.gd")
const RideTest := preload("res://scripts/region/ride_test.gd")
const GameSettings := preload("res://scripts/story/game_settings.gd")
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
# 어두운 실내(interior.dark — 김녕사굴 등 굴): 해·하늘빛을 줄인다. lantern(이야기가 켬 — 등불을 지님)이면 플레이어 곁에 등불빛
var lantern := false
var _dark_k := 0.0
var _dark_on := false
var _lantern: OmniLight3D
var _reload_t := 0.0
var weather    # Weather
var npcs_amb    # NpcAmbient(주변 인물·짐승) — --nonpc로 끔
var crowd = null  # EventCrowd(scripts/story/event_crowd.gd — 사건 때만 늘어나는 군중, C60). --nochars면 없음
# 실내 공간(scripts/region/interior_space.gd, region_data/interiors/<id>/interior.json): 굴·지하 같은 큰 실내를 따로 세운 공간.
#   enter_interior(id, entrance_id) · exit_interior(exit_id) — 권역을 다시 읽지 않고 지형·식생을 숨긴 채 실내 키트만 세운다(짧은 암전).
signal indoor_changed(id: String)   # 들어가면 실내 id, 나오면 ""
var indoor_gate = null              # Callable(id) -> String: ""면 들어감, 아니면 거절 사유(HUD) — 이야기가 건다
var _sky_quad: MeshInstance3D
var _indoor_specs: Array = []
var _indoor_armed := {}
var _indoor_busy := false
var _base_state: Dictionary
var _base_dir := Vector3.UP
var _pending := {}        # 다른 공간에서 넘어왔으면 그 예약(Travel)
var _data_dir := ""
var portals := []         # Travel.portals_for
var _portal_armed := {}
var _leaving := false
var _draining := false   # 끝내기·넘어가기 전: 작업 스레드가 끝나길 프레임을 돌리며 기다리는 중(_process는 쉰다)
var _quitting := false
var _hud: Label
var _hud_t := 0.0
var _ptest := {}          # --portaltest 진행 상태
var _route_entry := ""    # 노정에 들어온 끝 포털 id — 다른 끝 포털로 나가면 그 노정을 '지나옴'(Progress)
var _fast_hint := ""      # 역마 안내를 띄운 포털 id
var lanes = null          # RiverLanes(강 뱃길 route.json river_lanes) — 없으면 null
var boats = null          # BoatRide(나루·강 뱃길·바다 뱃길 배 타기 — 사공이 젓는다)
var _boat_prompt: Label
var _scatter_base := 220.0
const SAIL_SCATTER := 150.0   # 배 위 낮은 시점: 먼 기슭 식생(거친 벌)은 이 거리까지만 — 낮은 시점은 멀리까지 보여 fps가 떨어진다
var _e_hold := 0.0
var _dead_done := false   # 막다른 노정 끝에 닿아 '지나옴'을 기록했나
var story = null          # 이야기(scripts/story/story_director.gd): 사건·소문·전투. --nostory로 끔
var horse_ride = null     # 자동 기승(scripts/region/horse_ride.gd) — 큰길을 말이 저절로 간다
var fast_ui = null        # 역마 창 — 알게 된 거점 빠른 이동(scripts/region/fast_travel.gd: 역참 마부·깃발 대화, 지나온 노정 포털 곁 H)
var _ride_test = null

func _ready() -> void:
	if Progress.SaveGuard.blocked() != "":   # 저장 지킴: 게임 인자를 '--' 없이 넘긴 실행 · 모래상자 실패 → 놀이 저장으로 넘어가지 않고 끝낸다
		printerr("SAVEGUARD 실행 중단 — ", Progress.SaveGuard.blocked())
		get_tree().quit(3); return
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	# 저장 지킴(save_guard.gd): --savefile은 이야기 유무와 상관없이 가장 먼저(--nostory 촬영이 사용자 저장에 쓰던 구멍).
	#   시험·도구 실행이면 모든 저장 경로가 모래상자로 간다
	if args.has("savefile"): Progress.use_path(String(args.savefile))
	if Progress.SaveGuard.sandboxed(): print("SAVEGUARD sandbox=%s why=%s progress=%s" % [Progress.SaveGuard.root(), Progress.SaveGuard.why(), Progress.slot_path(0)])
	_setup_input()
	get_tree().set_auto_accept_quit(false)   # 창 닫기 → _quit()(작업 스레드를 기다린 뒤 끝낸다)
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
	fit_window(get_window())
	_fit_viewport()
	if not get_tree().root.has_node("WindowKeys"):
		var wk: Node = load("res://scripts/ui/window_keys.gd").new(); wk.name = "WindowKeys"
		get_tree().root.add_child.call_deferred(wk)   # F11 · Alt+Enter 전체 화면(맨 뒤 자식 — 입력을 먼저 받는다). 공간을 넘어가도(장면 다시 열기) 하나만
	get_window().size_changed.connect(_fit_viewport)
	post = PostEffect.new()
	post.paper_ratio = scene_vp.size.y / 768.0
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
	if args.has("ridefixture") or args.has("ridevars") or args.has("ridedone") or args.has("ridefresh"): RideTest.apply_fixture(args)   # 시험 출발 저장(이야기보다 먼저)
	if args.has("continuefixture"): load("res://scripts/story/continue_test.gd").apply_fixture(args)   # 이어 하기 시험 저장(이야기보다 먼저)
	if not args.has("nostory"): story = StoryDirector.create_for(self)
	if not args.has("nochars"):
		crowd = load("res://scripts/story/event_crowd.gd").new()
		scene_vp.add_child(crowd)
		crowd.setup(self)
	if args.has("nomsaa"): scene_vp.msaa_3d = Viewport.MSAA_DISABLED
	if args.has("noshadow"): sun.shadow_enabled = false
	if args.has("nolamps"):
		for o in lamp_slots: o.visible = false
	if args.has("nochars"): player.visible = false
	if args.has("noworld"): world.visible = false
	if args.has("nofar"): world.far_node.visible = false
	if args.has("nowater"): world.water_root.visible = false
	if args.has("noocc"): world.occluders.clear()
	if args.has("notilt") or args.has("nodof"): post.dof = false   # --nodof(새 이름) · --notilt(옛 이름) 깊이 흐림 끄기
	if args.has("nobloom"): post.bloom = false
	if args.has("nopost"): post.enabled = false
	if args.has("time"): hour = float(args.time)
	if args.has("view"): first_person = String(args.view) == "first"; _view_set = String(args.view)   # --view=first 1인칭으로 시작(촬영·시험)
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
	_fp_mouse = load("res://scripts/region/fp_mouse.gd").new(self); add_child(_fp_mouse)   # 1인칭 마우스 잡기·놓기
	add_child(load("res://scripts/region/travel_overlay.gd").new(self))   # 이동 건너뛰기 단추 · 개발 '전국 이동 열림' 표시
	if args.has("devtravel"): DevTravel.set_on(true)
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
	elif args.has("ridetest") and String(args.ridetest).contains(":"):
		_ride_test = RideTest.new(self); _ride_test.run.call_deferred(String(args.ridetest))
	elif args.has("fasttravel"):
		_ride_test = RideTest.new(self); _ride_test.run_fast.call_deferred(String(args.fasttravel))
	elif args.has("seattest"):   # 앉은 고을 사람(장꾼·평상·툇마루) — scripts/region/seat_test.gd
		_ride_test = load("res://scripts/region/seat_test.gd").new(self); _ride_test.run.call_deferred(String(args.seattest))
	elif args.has("talktest"):
		_ride_test = load("res://scripts/story/talk_test.gd").new(self); _ride_test.run.call_deferred(String(args.talktest))
	elif args.has("continuetest"):
		_ride_test = load("res://scripts/story/continue_test.gd").new(self); _ride_test.run.call_deferred(String(args.continuetest))
	elif args.has("p2preptest") or args.has("p2prepshot"):   # 춘향 PART II 준비(공용 자세·차림·잔치 짜임·set_pose·PART II 소품) — scripts/story/part2_prep_test.gd
		_ride_test = load("res://scripts/story/part2_prep_test.gd").new(self); _ride_test.run.call_deferred()
	elif args.has("preptest") or args.has("prepshot"):   # 춘향 준비(F-11·옥·수수밭·EventCrowd) 시험·촬영 — scripts/story/prep_test.gd
		_ride_test = load("res://scripts/story/prep_test.gd").new(self); _ride_test.run.call_deferred()
	elif args.has("viewtest"):   # 1인칭 시점(0 키) 시험 — scripts/region/view_test.gd
		_ride_test = load("res://scripts/region/view_test.gd").new(self); _ride_test.run.call_deferred()
	elif args.has("fpshots"):   # 1인칭 v2 화면(창 필요, 시험 저장으로만) — scripts/region/fp_shots.gd
		_ride_test = load("res://scripts/region/fp_shots.gd").new(self); _ride_test.run.call_deferred(String(args.fpshots))
	elif args.has("buildshots"):   # 건물 바닥·계단·초가 처마 모서리 점검 촬영 — scripts/region/building_shots.gd
		_ride_test = load("res://scripts/region/building_shots.gd").new(self); _ride_test.run.call_deferred(String(args.buildshots))
	elif args.has("talkshot"):
		_ride_test = load("res://scripts/story/talk_shot.gd").new(self); _ride_test.run.call_deferred(String(args.talkshot))
	elif args.has("ridetest"): _ride_test_boat.call_deferred(String(args.ridetest))
	elif args.has("tour"): _run_tour.call_deferred(args.tour)
	elif args.has("shot"): _run_shot.call_deferred(args.shot, int(args.get("frames", "30")))

const MAX_RENDER_EDGE := 3840
# 3D 장면 화소 한도(2026-10-13 16:9): 창 화소 × 화면 배율(레티나 2)이 이보다 많으면 줄여 그린다(창으로 늘려 보인다).
#   예전 1024×768 창은 2048×1536(315만 화소)으로 그렸다 — 16:9 큰 창·전체 화면에서도 GPU 몫이 그 언저리(약 370만)를 넘지 않게.
const MAX_RENDER_PIXELS := 2560 * 1440

func _fit_viewport() -> void:
	var win := get_window().size
	var k := minf(_render_scale, float(MAX_RENDER_EDGE) / maxf(1.0, maxf(win.x, win.y)))
	if not args.has("scale"): k = minf(k, sqrt(float(MAX_RENDER_PIXELS) / maxf(1.0, float(win.x) * float(win.y))))   # --scale=N을 주면 그대로(비교 촬영)
	var s := Vector2i(maxi(1, roundi(win.x * k)), maxi(1, roundi(win.y * k)))
	if scene_vp.size != s: scene_vp.size = s
	if post != null: post.paper_ratio = s.y / 768.0   # 한지 결 크기는 장면 높이에 비례(예전 1536 높이에서 2)

# 창: 기준 1920×1080(16:9) — 그냥 실행하면(사용자 인자 없음, 또는 --fitwindow) 화면(작업 영역)의 88% 안에 드는 가장 큰 16:9로 열고 가운데에 둔다.
#   크기는 마음대로 바꿀 수 있고(캔버스가 같이 늘고 준다), F11 · Alt+Enter로 전체 화면을 켜고 끈다.
static var _window_fitted := false
static func fit_window(win: Window) -> void:
	if _window_fitted: return   # 처음 한 번만(공간을 넘어가 장면을 다시 열 때 사용자가 바꾼 크기를 되돌리지 않는다)
	_window_fitted = true
	if DisplayServer.get_name() == "headless":
		win.size = Vector2i(1920, 1080)   # 헤드리스 시험: 창이 정사각에 가깝게 잡혀(보이는 크기 1920×1920) — 기준 16:9로 놓고 잰다
		return
	# 엔진 인자(--resolution 등)는 스크립트가 볼 수 없다 — 사용자 인자(-- 뒤)가 있으면(시험·촬영) 창 크기를 건드리지 않는다
	if not OS.get_cmdline_user_args().is_empty() and not "--fitwindow" in OS.get_cmdline_user_args(): return
	if win.mode != Window.MODE_WINDOWED: return
	var scr := DisplayServer.window_get_current_screen()
	var ur := DisplayServer.screen_get_usable_rect(scr)
	var h := mini(int(ur.size.y * 0.88), int(ur.size.x * 0.88 * 9.0 / 16.0))
	var sz := Vector2i(roundi(h * 16.0 / 9.0), h)
	win.size = sz
	win.position = ur.position + (ur.size - sz) / 2

func _setup_input() -> void:
	var keys := {
		move_up = [KEY_W, KEY_UP], move_down = [KEY_S, KEY_DOWN], move_left = [KEY_A, KEY_LEFT], move_right = [KEY_D, KEY_RIGHT],
		run = [KEY_SHIFT], time_step = [KEY_T], toggle_post = [KEY_P], reload_place = [KEY_F5], weather_step = [KEY_F6], fast_travel = [KEY_H],
		interact = [KEY_E], boat_skip = [KEY_SPACE], view_toggle = [KEY_0, KEY_KP_0],
	}
	for act in keys:
		if not InputMap.has_action(act): InputMap.add_action(act)
		if act == "interact" and not InputMap.action_get_events(act).is_empty(): continue
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
	_sky_quad = sky_quad
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
	cam.keep_aspect = Camera3D.KEEP_HEIGHT   # 16:9(2026-10-13): fov는 세로 시야 — 4:3 때 짠 구도(세로)가 그대로, 넓어진 만큼 옆이 더 보인다(공식 장면 다시 짜지 않음)
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
	placement.gate.main = self   # when 조건(F-11)이 이야기·시간을 본다
	if not args.has("noplace"): placement.load_all()
	if placement.stats.get("placed", 0) > 0 and not args.has("markers"): world.remove_tagged("marker")
	if not args.has("nowallproxy"): world.build_wall_proxies(placement)   # region.json walls 중 키트가 안 덮은 구간만
	portals = Travel.portals_for(world.region, world.is_route)
	_place_portals()
	if world.is_route: _route_entry = _nearest_portal(world.spawn)
	if world.region.get("river_lanes") is Array:   # 강 뱃길: 꺾은선 뱃길·떠가는 배(--sailspeed=m/s 시험용 배 속도)
		lanes = RiverLanes.new(); lanes.setup(world)
		if args.has("sailspeed"): lanes.speed_override = float(args.sailspeed)
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
	_lantern = OmniLight3D.new()
	_lantern.light_color = Color("#ffb468"); _lantern.omni_range = 9.5; _lantern.omni_attenuation = 1.4
	_lantern.shadow_enabled = false; _lantern.light_energy = 0.0; _lantern.visible = false
	root.add_child(_lantern)

	SpriteChar.load_bank("player", "frames.json")
	player = SpriteChar.new("player")
	player.facing = "up"
	root.add_child(player)
	player.set_layers(PLAYER_LAYER)   # 1인칭에서 카메라가 이 층만 빼고 그린다(그림자는 해가 그대로 드리운다)
	if not args.has("nonpc") and not args.has("nochars"):
		npcs_amb = NpcAmbient.new(); root.add_child(npcs_amb); npcs_amb.setup(world, weather, cam, placement)
		npcs_amb.story_ref = story; npcs_amb.crowd_ref = crowd   # 앉은 고을 사람은 이야기 인물·군중 자리를 비킨다
	boats = BoatRide.new(); boats.setup(self)
	if args.has("sailspeed"): boats.speed_override = float(args.sailspeed)
	boats.arrived.connect(_on_boat_arrived)
	horse_ride = HorseRide.new(); horse_ride.setup(self)
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
	# 실내 공간 자리면 들어가고(암전 없이), 실내에서 바깥 자리를 가리키면 나온다 — 이야기·시험 teleport가 그대로 통한다
	if world.indoor != null and not world.indoor.bounds.has_point(Vector2(x, z)): _exit_now()
	elif world.indoor == null:
		for sp in _indoor_list():
			if InteriorSpace.contains(sp, Vector2(x, z)): _enter_now(sp); break
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

# 어두운 실내: 해·하늘빛을 줄이고(굴 지붕을 숨겨도 햇빛이 들지 않게) 등불을 켠다. 나오면 시간대 값으로 되돌린다
func _apply_dark() -> void:
	if _dark_k <= 0.002 and not _dark_on:
		if _lantern.visible: _lantern.visible = false
		return
	_dark_on = _dark_k > 0.002
	if not _state.is_empty():
		sun.light_energy = float(_state.sunI) * maxf(0.0, 1.0 - 1.1 * _dark_k)   # 굴 안엔 해가 들지 않는다(숨긴 지붕 그림자 사이 햇빛 띠도 없앤다)
		RenderingServer.global_shader_parameter_set("hemi_i", float(_state.hemiI) * (1.0 - 0.88 * _dark_k))
		if world.indoor != null: RenderingServer.global_shader_parameter_set("fog_density", 0.0)
	var on := lantern and _dark_k > 0.02
	_lantern.visible = on
	if on:
		var fl := 1.0 + 0.06 * sin(clock * 11.0) + 0.04 * sin(clock * 23.0)
		_lantern.light_energy = 3.4 * _dark_k * fl
		_lantern.position = player_pos + Vector3(0.35, 1.3, 0.25)

# ---- 실내 공간 ----
func _indoor_list() -> Array:
	if _indoor_specs.is_empty(): _indoor_specs = InteriorSpace.for_space(String(world.region.get("region_id", world.region.get("route_id", ""))))
	return _indoor_specs

func _enter_now(sp: Dictionary) -> void:
	var t0 := Time.get_ticks_usec()
	world.enter_indoor(sp)
	_sky_quad.visible = false
	if npcs_amb != null: npcs_amb.visible = false
	_apply_atmo()
	print("INDOOR enter %s ms=%.1f" % [sp.get("id", ""), (Time.get_ticks_usec() - t0) / 1000.0])
	indoor_changed.emit(String(sp.get("id", "")))

func _exit_now() -> void:
	var iid: String = world.indoor.id
	var t0 := Time.get_ticks_usec()
	world.exit_indoor()
	_sky_quad.visible = true
	if npcs_amb != null: npcs_amb.visible = true
	_apply_atmo()
	print("INDOOR exit %s ms=%.1f" % [iid, (Time.get_ticks_usec() - t0) / 1000.0])
	indoor_changed.emit("")

# 걸어서 입구(권역)·출구(실내) 자리에 들면 짧은 암전으로 넘어간다. 이야기가 플레이어를 쥐고 있으면 기다린다
func _check_indoor() -> void:
	if _indoor_busy or (story != null and story.owns_player()): return
	var pp := Vector2(player_pos.x, player_pos.z)
	if world.indoor == null:
		for sp in _indoor_list():
			for e in sp.get("entrances", []):
				var key := "%s/%s" % [sp.id, e.id]
				var d := pp.distance_to(Vector2(float(e.at[0]), float(e.at[1])))
				if d > float(e.get("radius", 1.5)) + 1.5: _indoor_armed[key] = true
				if d < float(e.get("radius", 1.5)) and _indoor_armed.get(key, true):
					_indoor_armed[key] = false
					enter_interior(String(sp.id), String(e.id))
					return
	else:
		for x in world.indoor.spec.get("exits", []):
			var key := "%s/x/%s" % [world.indoor.id, x.id]
			var d: float = pp.distance_to(world.indoor.to_world(Vector2(float(x.at[0]), float(x.at[1]))))
			if d > float(x.get("radius", 1.3)) + 1.5: _indoor_armed[key] = true
			if d < float(x.get("radius", 1.3)) and _indoor_armed.get(key, false):
				exit_interior(String(x.id))
				return

func _indoor_fade(on: bool) -> void:
	if story != null and story.get("ui") != null:
		await story.ui.fade(on, 0.35)
	else:
		await _wait_frames(1)

func enter_interior(iid: String, entrance_id := "") -> bool:
	var sp := InteriorSpace.spec_of(iid)
	if sp.is_empty() or _indoor_busy: return false
	if indoor_gate is Callable and (indoor_gate as Callable).is_valid():
		var why = (indoor_gate as Callable).call(iid)
		if why is String and why != "":
			_show_hud(why); return false
	var e: Dictionary = {}
	for x in sp.get("entrances", []):
		if entrance_id == "" or String(x.id) == entrance_id: e = x; break
	_indoor_busy = true
	await _indoor_fade(true)
	_enter_now(sp)
	var sp_l: Array = e.get("spawn", [0, 0])
	var w: Vector2 = world.indoor.to_world(Vector2(float(sp_l[0]), float(sp_l[1])))
	player_pos = Vector3(w.x, world.height_at(w.x, w.y), w.y)
	player.position = player_pos
	if e.has("face"): player.facing = String(e.face)
	rig.update(0, player_pos, player.facing, world.interior_at(w.x, w.y), true)
	for x in sp.get("exits", []): _indoor_armed["%s/x/%s" % [iid, x.id]] = false
	await _indoor_fade(false)
	_indoor_busy = false
	return true

func exit_interior(exit_id := "") -> void:
	if world.indoor == null or _indoor_busy: return
	var x: Dictionary = {}
	for q in world.indoor.spec.get("exits", []):
		if exit_id == "" or String(q.id) == exit_id: x = q; break
	_indoor_busy = true
	await _indoor_fade(true)
	var iid: String = world.indoor.id
	_exit_now()
	var to: Array = x.get("to", [player_pos.x, player_pos.z])
	teleport(float(to[0]), float(to[1]))
	if x.has("face"): player.facing = String(x.face)
	rig.update(0, player_pos, player.facing, world.interior_at(player_pos.x, player_pos.z), true)
	for sp in _indoor_list():
		if String(sp.id) == iid:
			for e in sp.get("entrances", []): _indoor_armed["%s/%s" % [iid, e.id]] = false
	await _indoor_fade(false)
	_indoor_busy = false

# 이어 하기 자리: 실내 공간 안이면 그 첫 출구의 바깥 자리
func where_outside() -> Vector2:
	if world.indoor == null: return Vector2(player_pos.x, player_pos.z)
	var xs: Array = world.indoor.spec.get("exits", [])
	if xs.is_empty(): return Vector2(player_pos.x, player_pos.z)
	return Vector2(float(xs[0].to[0]), float(xs[0].to[1]))

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
	_scatter_base = world.scatter_far
	if rig != null and (rig.sailing or rig.riding): world.scatter_far = minf(_scatter_base, SAIL_SCATTER)
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
# 각본 가림(이야기 컷신 한 장면 — 남원 동아줄): 가림 점무늬·식생 걷어 내기의 기준점을 플레이어 대신 focus(줄을 타는 오누이·범)로,
# 반지름을 r로. 그동안 물체 반투명(occluders)은 쓰지 않는다 — 반투명 잎은 깊이를 써서 뒤의 인물 그림을 가린다. 점무늬는 픽셀을 버려 가리지 않는다.
var occ_now := Vector2.ZERO   # 이 프레임 가림 점무늬 반지름 · 카메라 앞 비우기(시험이 본다)
var occ_script = null   # { focus: Vector3, r: float, near?: float(카메라 앞 비우기 배율, 0 = 끔) } | null
func set_occ_script(spec) -> void:
	occ_script = spec

# 하늘 그림판의 기본 달(sky_backdrop u_moon) — 1 보임 · 0 감춤. 이야기 한 장면만(남원 마지막 밤의 두 빛) 잠깐 감추고 되돌린다.
#   재질은 장면마다 새로 만들어 기본값 1로 시작한다 — 저장에는 남지 않는다(장면을 나가거나 끝내도 감춘 채 남지 않는다)
func set_moon(k: float) -> void:
	if sky_mat != null: sky_mat.set_shader_parameter("u_moon", clampf(k, 0.0, 1.0))

func moon_k() -> float:
	if sky_mat == null: return 1.0
	var v = sky_mat.get_shader_parameter("u_moon")
	return 1.0 if v == null else float(v)

# 각본 장면 동안 깊이 흐림(후처리 dof — 이 권역의 흐림 효과는 이것 하나)을 끈다. false면 평소 값으로 천천히(약 2초) 돌아온다
var cine_sharp := false
func set_cine_sharp(on: bool) -> void:
	cine_sharp = on

# 깊이 흐림 값(PostEffect.dof_*): 초점 = 카메라에서 겨냥점(플레이어 가슴·연출 겨냥점·각본 시점의 look)까지 거리.
#   걷기: 먼 흐림 0.55(멀수록 천천히 다가감) · 앞가림 0.3 · 초점 둘레 4m 또렷.
#   배·말(낮은 풍경 시점): 먼 기슭·능선이 보이게 먼 흐림 0.3 · 더 천천히. 마방 앞: 칸 안 말이 섞이지 않게 0.25.
#   1인칭: 초점 7m, 먼 흐림 0.35를 아주 천천히(거리 배율 3) — 눈앞 사람·물건은 또렷하다.
#   각본 장면(set_cine_sharp)·끔(--nodof·--notilt·P)이면 0.
const DOF_WALK := { far = 0.55, near = 0.3, scale = 1.2, margin = 4.0 }
const DOF_LOW := { far = 0.3, near = 0.15, scale = 2.5, margin = 8.0 }
const DOF_STABLE := { far = 0.25, near = 0.2, scale = 2.0, margin = 6.0 }
var _dof_fp := false
# 먼 산 대기 원근(산수화, 2026-10 v2): 150m 밖에서 600m까지 흐림 +0.2 · 옅은 안개 0.12 — 150m 안은 전과 같다(PostEffect.aerial_*)
const AERIAL_BLUR := 0.2
const AERIAL_HAZE := 0.12
const DOF_FP := { far = 0.35, near = 0.0, scale = 3.0, margin = 3.0 }
func _update_dof(dt: float) -> void:
	var look: Vector3 = rig.target
	if fp_view(): look = cam.global_position - cam.global_transform.basis.z * 7.0
	elif rig.shot != null: look = rig.shot.look
	var want_f := clampf(cam.global_position.distance_to(look), 2.0, 400.0)
	var low: bool = rig.sailing or rig.riding
	var stable: bool = not low and not fp_view() and horse_ride != null and horse_ride.life != null and horse_ride.life.stable_view(player_pos)
	var sp: Dictionary = DOF_FP if fp_view() else (DOF_LOW if low else (DOF_STABLE if stable else DOF_WALK))
	var k := minf(1.0, dt * 2.0)
	if _dof_fp != fp_view(): _dof_fp = fp_view(); k = 1.0   # 1인칭 ↔ 3인칭: 바로
	var off := cine_sharp
	var gs := GameSettings.get_v("dof") if not _view_automation() else "normal"   # 설정 '깊이 흐림' — 시험·촬영은 보통
	if gs == "off": off = true
	var mul := 0.5 if gs == "weak" else 1.0
	post.dof_far += ((0.0 if off else float(sp.far) * mul) - post.dof_far) * (1.0 if off else k)
	post.dof_near += ((0.0 if off else float(sp.near) * mul) - post.dof_near) * (1.0 if off else k)
	post.aerial_blur = 0.0 if off else AERIAL_BLUR * mul   # 먼 산 대기 원근(150m 밖만 — C67 v2)
	post.aerial_haze = 0.0 if off else AERIAL_HAZE * mul
	post.aerial_range = (cam.far - post.aerial_start) if fp_view() else 450.0   # 1인칭(먼 끝 260m): 150m~먼 끝(하늘 그림판의 먼 산)까지
	post.dof_far_scale += (float(sp.scale) - post.dof_far_scale) * k
	post.dof_margin += (float(sp.margin) - post.dof_margin) * k
	post.dof_focus += (want_f - post.dof_focus) * (1.0 if k >= 1.0 else minf(1.0, dt * 6.0))
	if absf(want_f - post.dof_focus) > 30.0: post.dof_focus = want_f   # 컷 바뀜·순간이동: 바로

func _occ_focus() -> Vector3:
	if occ_script != null: return occ_script.focus
	return player_pos + Vector3(0, player.height * 0.8, 0)

func _update_occlusion(dt: float, interior) -> void:
	var want: Array = interior.hide if interior != null and not fp_view() else []   # 1인칭: 지붕을 숨기지 않는다(안에서 올려다보면 지붕이 있어야)
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
		if interior == null and not fp_view():
			var c := cam.global_position
			for occ in _occ_near:
				if occ_script != null or not occ.node.visible or not occ.node.is_inside_tree(): continue
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

# ---- 1인칭 시점(0 키) ----
# first_person = 플레이어가 바란 시점(0 키 · 설정 '시점' · user://settings.json view), fp_active = 지금 1인칭(C68).
# 1인칭은 대화·선택지·살펴보기·문서·문제 카드·기록책·지도·역마 창·Esc·카메라 없는 각본 장면에서도 그대로다(2026-10 v2 — 대화마다 3인칭으로 바뀌던 것을 고침).
#   대화가 시작되면 말하는 이(머리) 쪽으로, 살펴보기는 물건 쪽으로 0.4초 동안 천천히 돌아본다(fp_look_at — story_director가 부른다). 대화 구도(TALK 38/13.5/38)는 쓰지 않는다.
#   저작 연출 카메라(d.camera · CameraRig.shot · glide · 사건 override/focus — rig.authored())는 컷이다: 눈높이에서 바로 그 구도로(사이에 3인칭 플레이어 시점 없음),
#   끝나면 바로 눈높이로 돌아온다(fp_cut 동안은 플레이어가 보이고 near·far는 3인칭 값).
#   3인칭으로 돌아가는 때는 셋뿐: 불러오기·떠나기 암전(loading) · 배·말(ride) · 전투(combat — 고정 시점 전제의 조준·예고 고리·구르기라 1인칭으로는 못 싸운다).
# 눈높이 FP_EYE(1.55m), 바라보는 쪽 fp_yaw(0 = 북쪽, +는 동쪽으로 돈다). 움직임은 카메라 기준: W·S(↑↓) 앞뒤 · A·D 옆걸음 · ←→ 돌기 ·
# 마우스: 커서를 잡아 숨기고 움직이면 둘러본다(위아래 ±70°, 설정 '마우스 감도'). 대화·선택·카드·창이 열리면 놓고 닫히면 다시 잡는다(scripts/region/fp_mouse.gd).
# 플레이어 그림은 PLAYER_LAYER(20번 층)만 카메라에서 뺀다 — 그림자는 남는다.
const PLAYER_LAYER := 1 << 19
const FP_EYE := 1.55
const FP_FOV := 62.0
const FP_TURN := 1.9          # ←→ 돌기(라디안/초)
const FP_MOUSE := 0.0045      # 커서가 보일 때 단추 누른 채 끌기(라디안/픽셀)
const FP_SENS := { low = 0.0016, normal = 0.0025, high = 0.0038 }   # 잡은 마우스(라디안/픽셀) — 설정 mouse_sens
const FP_PITCH := 1.2217      # 위아래 ±70°
const FP_LOOK_SEC := 0.4      # 말하는 이·물건 쪽으로 돌아보는 시간
const FP_CUT_IN := 0.6        # 눈높이 → 저작 구도(shot은 바로)
const FP_CUT_OUT := 0.5       # 저작 구도 → 눈높이(shot이었으면 바로)
const FP_FAR := 260.0         # 1인칭 카메라 먼 끝(m) — 3인칭 6000. 한양 1인칭(2048×1536): 6000 → 45fps · 420 → 62 · 250 → 82 — 안개 너머라 화면은 같다
var first_person := false
var fp_active := false
var fp_cut := false           # 1인칭 중 저작 연출 카메라가 화면을 쥔 동안
var fp_yaw := 0.0
var fp_pitch := -0.06
var fp_block := ""            # 지금 1인칭을 막은 까닭(시험·안내)
var fp_mouse_force := false   # 시험: 커서를 잡지 않고도 마우스 움직임으로 둘러보기
var _view_set := ""           # 마지막으로 본 설정 값(설정 창에서 바꾸면 따라간다)
var view_persist := true      # 시험은 끈다(사용자 settings.json에 쓰지 않게)
var _fp_turn = null           # { y0, p0, y1, p1, t, dur } — fp_look_at
var _fp_blend = null          # { from: Transform3D, fov, t, dur } — 눈높이 ↔ 저작 구도
var _fp_last_xf := Transform3D.IDENTITY
var _fp_last_fov := FP_FOV
var _fp_was_shot := false
var _fp_mouse = null          # scripts/region/fp_mouse.gd
var _near_detail := 0.0

var _auto = null
func _view_automation() -> bool:
	if _auto != null: return _auto
	_auto = false
	for k in args:
		if String(k).ends_with("test") or String(k) in ["bench", "seattest", "shot", "tour", "walkroute", "fasttravel", "talkshot", "prepshot", "p2prepshot", "storyshots", "fpshots"]: _auto = true
	return _auto

static func _yaw_of(facing: String) -> float:
	return { up = 0.0, right = PI * 0.5, down = PI, left = -PI * 0.5 }.get(facing, 0.0)

func set_first_person(on: bool, save := true) -> void:
	if on == first_person: return
	first_person = on
	if save and view_persist: GameSettings.set_v("view", "first" if on else "third")
	_view_set = "first" if on else "third"
	_update_fp_state()
	if on and not fp_active: _show_hud("지금은 3인칭 — 끝나면 1인칭으로 돌아간다 (0 되돌리기)")
	elif on: _show_hud("1인칭 — 마우스로 둘러보기 · W·S 앞뒤 · A·D 옆 · E 말 걸기 · Esc 메뉴 · 0 3인칭")
	else: _show_hud("3인칭 시점 (0 1인칭)")

func toggle_view() -> void:
	set_first_person(not first_person)

func fp_blocker() -> String:
	if _loading or _leaving: return "loading"
	if story != null and story.drives_player(): return "combat"
	if boats.riding() or horse_ride.mounted(): return "ride"   # 역마 창(FAST_TRAVEL)은 창일 뿐 — 1인칭 그대로
	return ""

func _update_fp_state() -> void:
	if not _view_automation():
		var v := GameSettings.get_v("view")
		if v != _view_set:
			_view_set = v
			first_person = v == "first"
	fp_block = fp_blocker() if first_person else ""
	var want := first_person and fp_block == ""
	if want == fp_active: return
	fp_active = want
	fp_cut = false; _fp_blend = null; _fp_turn = null
	if want:
		fp_yaw = _yaw_of(player.facing); fp_pitch = -0.06
		_fp_cam_eye(true)
		_fp_camera(0.0)
		_fp_last_xf = cam.transform; _fp_last_fov = cam.fov
	else:
		_fp_cam_eye(false)
		rig.update(0, player_pos, player.facing, world.interior_at(player_pos.x, player_pos.z), true)   # 3인칭 자리로 바로
	print("VIEW %s%s" % ["first" if want else "third", "" if want or not first_person else " (막힘: %s)" % fp_block])

# 눈높이 카메라 값(on) · 3인칭·저작 컷 값(off)
func _fp_cam_eye(on: bool) -> void:
	if on:
		cam.cull_mask &= ~PLAYER_LAYER
		cam.near = 0.1   # 벽 곁에서 벽이 잘리지 않게
		cam.far = float(args.get("fpfar", str(FP_FAR)))   # 눈높이는 지평선 너머 도시 전체가 든다 — 멀리는 하늘 그림판의 먼 산·안개가 맡는다
	else:
		cam.cull_mask |= PLAYER_LAYER
		cam.near = 0.5
		cam.far = 6000.0

# 지금 눈높이 화면인가(1인칭이고 저작 컷이 아님) — 흐림·가림·지붕·땅 잔무늬가 본다
func fp_view() -> bool:
	return fp_active and not fp_cut

func fp_look_dir() -> Vector2:
	return Vector2(sin(fp_yaw), -cos(fp_yaw))

# 1인칭 시선을 점(머리·물건) 쪽으로 sec초 동안 천천히(smoothstep). 1인칭이 아니면 아무것도 하지 않는다
func fp_look_at(p: Vector3, sec := FP_LOOK_SEC) -> void:
	if not fp_active: return
	var eye := player_pos + Vector3(0, FP_EYE, 0)
	var v := p - eye
	var h := Vector2(v.x, v.z).length()
	if h < 0.25: return
	var y1 := atan2(v.x, -v.z)
	var p1 := clampf(atan2(v.y, h), -0.9, 0.6)
	_fp_turn = { y0 = fp_yaw, p0 = fp_pitch, y1 = fp_yaw + wrapf(y1 - fp_yaw, -PI, PI), p1 = p1, t = 0.0, dur = maxf(sec, 0.01) }

# 각본 순간이동(facing) — 컷이라 바로
func fp_face_dir(facing: String) -> void:
	fp_yaw = _yaw_of(facing); fp_pitch = -0.06; _fp_turn = null

func _fp_move(dt: float) -> Vector2:
	var turn := (1.0 if Input.is_physical_key_pressed(KEY_RIGHT) else 0.0) - (1.0 if Input.is_physical_key_pressed(KEY_LEFT) else 0.0)
	if turn != 0.0: _fp_turn = null
	fp_yaw = wrapf(fp_yaw + turn * FP_TURN * dt, -PI, PI)
	var fwd := (1.0 if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP) else 0.0) \
		- (1.0 if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN) else 0.0)
	var side := (1.0 if Input.is_physical_key_pressed(KEY_D) else 0.0) - (1.0 if Input.is_physical_key_pressed(KEY_A) else 0.0)
	var f := fp_look_dir()
	var r := Vector2(-f.y, f.x)   # 오른쪽
	var v := f * fwd + r * side
	return v.normalized() if v.length() > 1.0 else v

func _fp_camera(dt: float) -> void:
	if _fp_turn != null:
		_fp_turn.t += dt
		var w := smoothstep(0.0, 1.0, clampf(_fp_turn.t / _fp_turn.dur, 0.0, 1.0))
		fp_yaw = lerpf(_fp_turn.y0, _fp_turn.y1, w)
		fp_pitch = lerpf(_fp_turn.p0, _fp_turn.p1, w)
		if _fp_turn.t >= _fp_turn.dur: _fp_turn = null; fp_yaw = wrapf(fp_yaw, -PI, PI)
	cam.transform = Transform3D(Basis.from_euler(Vector3(fp_pitch, -fp_yaw, 0.0), EULER_ORDER_YXZ), player_pos + Vector3(0, FP_EYE, 0))
	cam.fov = FP_FOV

# 1인칭 한 프레임(rig.update 뒤): 저작 컷이면 rig가 놓은 구도, 아니면 눈높이. 둘 사이는 바로 잇는다(shot은 끊어서, 나머지는 짧게 섞어서) —
#   컷 시작에 rig를 목표 구도로 바로 놓아(미끄러짐도 끝으로) 3인칭 플레이어 시점이 사이에 끼지 않게, 끝의 '플레이어로 돌아오는 미끄러짐'은 버린다.
func _fp_frame(dt: float, interior) -> void:
	var auth: bool = rig.authored()
	if auth != fp_cut:
		var hard: bool = rig.shot != null or _fp_was_shot
		fp_cut = auth
		_fp_cam_eye(not auth)
		if auth:
			rig.glide_finish()
			rig.update(0, player_pos, player.facing, interior, true)
		else:
			rig.glide_cancel()
		_fp_blend = null if hard else { from = _fp_last_xf, fov = _fp_last_fov, t = 0.0, dur = FP_CUT_IN if auth else FP_CUT_OUT }
		print("VIEW fp %s" % ("cut" if auth else "eye"))
	elif not fp_cut and rig.gliding():
		rig.glide_cancel()   # 컷 밖의 '평소 자리로 미끄러짐'(1인칭에는 평소 자리가 눈높이)
	if not fp_cut: _fp_camera(dt)
	_fp_was_shot = rig.shot != null
	if _fp_blend != null:
		_fp_blend.t += dt
		var w := smoothstep(0.0, 1.0, clampf(_fp_blend.t / _fp_blend.dur, 0.0, 1.0))
		cam.transform = (_fp_blend.from as Transform3D).interpolate_with(cam.transform, w)
		cam.fov = lerpf(_fp_blend.fov, cam.fov, w)
		if _fp_blend.t >= _fp_blend.dur: _fp_blend = null
	_fp_last_xf = cam.transform; _fp_last_fov = cam.fov

# 마우스를 잡아 둘러볼 때인가: 눈높이 화면이고 플레이어가 움직일 수 있을 때만 — 대화·선택·카드·컷·창·지도·멈춤에서는 놓는다
func fp_mouse_wanted() -> bool:
	if not fp_view() or _loading or _leaving: return false
	if story != null and (story.owns_player() or _story_talking()): return false
	if _map != null and _map.visible: return false
	if fast_ui != null and is_instance_valid(fast_ui) and fast_ui.visible: return false
	if get_tree().paused: return false
	if preload("res://scripts/hud_gate.gd").overlay_open(get_tree()): return false
	return true

func fp_sens() -> float:
	return float(FP_SENS.get(GameSettings.get_v("mouse_sens") if not _view_automation() else "normal", FP_SENS.normal))

func _fp_mouse_look(rel: Vector2, k: float) -> void:
	_fp_turn = null
	fp_yaw = wrapf(fp_yaw + rel.x * k, -PI, PI)
	fp_pitch = clampf(fp_pitch - rel.y * k, -FP_PITCH, FP_PITCH)

func _input(ev: InputEvent) -> void:
	# 잡은 마우스(커서 숨김): 단추 없이 움직이면 둘러본다 — GUI보다 먼저 받는다(화면 가운데 창 조각이 움직임을 먹지 않게)
	if ev is InputEventMouseMotion and fp_view() and (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or fp_mouse_force) and fp_mouse_wanted():
		_fp_mouse_look(ev.relative, fp_sens())
		get_viewport().set_input_as_handled()

func _unhandled_input(ev: InputEvent) -> void:
	# F9(디버그 실행만 — 에디터·godot --path .): 개발 '전국 이동 열림' 켜고 끄기(scripts/region/dev_travel.gd)
	if ev is InputEventKey and ev.pressed and not ev.echo and ev.physical_keycode == KEY_F9 and OS.is_debug_build():
		DevTravel.set_on(not DevTravel.on)
		_show_hud("개발: 전국 이동 열림" if DevTravel.on else "개발: 전국 이동 닫힘")
		if _map != null: _map._refresh_dynamic()
		get_viewport().set_input_as_handled()
		return
	# 커서가 보일 때(시험·촬영 · 창이 포커스를 잃음): 단추를 누른 채 끌어 둘러보기
	if fp_view() and ev is InputEventMouseMotion and (ev.button_mask & (MOUSE_BUTTON_MASK_LEFT | MOUSE_BUTTON_MASK_RIGHT)) != 0:
		_fp_mouse_look(ev.relative, FP_MOUSE)
		get_viewport().set_input_as_handled()

# ---- 루프 ----
var _title: CanvasLayer = null
var _map: CanvasLayer = null
var _btitles = null
var _map_opened := false

func _process(delta: float) -> void:
	if _draining: return
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
			if args.has("mapfasttest") and _pending.is_empty(): _map_fast_test.call_deferred()   # --mapfasttest: 전국 지도에서 역마 1번 고르고 확인
		_map.update(player_pos, player.facing)
	var dt := minf(0.05, delta)
	clock += dt
	if Input.is_action_just_pressed("time_step"):
		hour = fmod(floor(hour / 6.0) * 6.0 + 6.0, 24.0); _apply_time()
	if Input.is_action_just_pressed("weather_step") and weather != null and not (story != null and story.owns_player()):
		_show_hud("날씨: " + weather.cycle())
	# 배치 다시 읽기: F5, 또는 --reload면 파일이 바뀔 때마다(1초마다 확인)
	_reload_t += delta
	if Input.is_action_just_pressed("reload_place") or (args.has("reload") and _reload_t > 1.0 and placement.changed()):
		_reload_place()
	if args.has("reload") and _reload_t > 1.0: _reload_t = 0.0
	if Input.is_action_just_pressed("toggle_post"):
		post.tilt = not post.tilt; post.paper = post.tilt
	if Input.is_action_just_pressed("view_toggle") and not _loading: toggle_view()
	if time_flow:
		hour = fmod(hour + dt * 0.1, 24.0); _apply_time()
	if weather != null and weather.time_forced():   # 사건 시간 강제(weather.force_time)
		var nh: float = weather.time_step(hour, dt)
		if absf(nh - hour) > 0.002: hour = nh; _apply_time()
	_update_loading()
	var mv := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	_update_fp_state()
	if fp_active:   # 눈높이에서 플레이어가 움직일 수 있을 때만 걷기·돌기(대화·선택 중 ↑↓·W·S는 고르기, 컷 중에는 돌지 않는다)
		mv = _fp_move(dt) if fp_view() and not (story != null and story.owns_player()) else Vector2.ZERO
	if _loading or _leaving or (_map and _map.visible): mv = Vector2.ZERO # 지도가 열려 있으면 멈춤
	var speed := RUN if Input.is_action_pressed("run") else WALK
	if not _ptest.is_empty() and not _loading and not _leaving and not boats.riding() and not horse_ride.busy():
		mv = _ptest_step(delta); speed = RUN
		if not _pt_path.is_empty(): speed = float(args.get("walkspeed", "12"))
	_update_boats(dt)
	_update_horse(dt)
	if boats.riding() or horse_ride.busy(): mv = Vector2.ZERO   # 배 위·말 위: 사공이 젓고 말이 간다(입력 막음 — 지도·기록책·멈춤·내리기만)
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
	if story != null: story.update(dt)   # 이야기·전투(전투 중에는 전투가 플레이어를 옮긴다)
	placement.gate.poll()   # 배치·군중 when — 사건·변수·밤낮이 바뀐 프레임에만 다시 본다
	if story != null and story.owns_player(): pass
	elif boats.riding() or horse_ride.busy(): pass
	elif mv.length() > 0.0:
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
	horse_ride.place_rider(dt)   # 말 위면 안장 높이로
	var _t0 := Time.get_ticks_usec()
	var _ev: String = world.stats.get("event", "")
	world.focus(player_pos)
	var _t1 := Time.get_ticks_usec()
	world.set_terrain_param("mist_base", player_pos.y)
	RenderingServer.global_shader_parameter_set("fog_base", player_pos.y) # 키트·캐릭터 산안개도 발 높이 기준
	var interior = world.interior_at(player_pos.x, player_pos.z)
	world.update_camera_zone(player_pos)
	rig.update(dt, player_pos, player.facing, interior)
	if fp_active: _fp_frame(dt, interior)
	var nd := 1.0 if fp_view() and not args.has("nonear") else 0.0   # 1인칭 가까운 땅 잔무늬(region_terrain near_layer) — --nonear로 끔(비교)
	if nd != _near_detail: _near_detail = nd; world.set_terrain_param("near_detail", nd)
	if story != null: cam.position += story.shake_offset()
	# 가림 점무늬(키트 재질): 카메라→플레이어 머리 선분 둘레의 나무·건물을 점무늬로 비운다. 실내에선 끔
	RenderingServer.global_shader_parameter_set("occ_a", cam.global_position)
	RenderingServer.global_shader_parameter_set("occ_b", _occ_focus())
	var occ_r: float = 0.0 if interior != null or fp_view() or args.has("nodither") else (3.8 if world.forest_active else 2.4)  # 숲에서는 더 넓게 · 1인칭은 끔(눈이 플레이어 자리)
	if occ_script != null and interior == null: occ_r = float(occ_script.get("r", occ_r))
	RenderingServer.global_shader_parameter_set("occ_r", occ_r)
	occ_now = Vector2(occ_r, 0.0)
	# 실내 near_fade=false(굴 등 좁은 실내): 카메라 앞 가림 점무늬를 끈다 — 바닥·벽이 카메라 12m 안이라 구멍이 뚫린다
	var near_fade: bool = not args.has("nodither") and not fp_view() and not (interior != null and not bool(interior.get("near_fade", true)))
	# 단면 실내(지붕을 숨긴 집·창고): 카메라가 10~13m 위라 바깥 거리(6~12m)로 비우면 바닥·가구에 점무늬 구멍이 난다 — 카메라 바로 곁(2~4m, 잎덩이)만
	var occ_near_k: float = (0.33 if interior != null else 1.0) if near_fade else 0.0
	if occ_script != null and occ_script.has("near"): occ_near_k = float(occ_script.near)   # 각본 장면이 카메라 앞 비우기를 정한다(0 = 끔 — 문 앞 가까운 시점)
	RenderingServer.global_shader_parameter_set("occ_near", occ_near_k)
	occ_now.y = occ_near_k
	# 실내 보조광: 들어가면 서서히 켠다(밤에는 조금 더 — 호롱불 느낌)
	_fill_k += ((1.0 if interior != null else 0.0) - _fill_k) * minf(1.0, dt * 3.0)
	_fill.position = player_pos + Vector3(0, 2.4, 0.8)
	var dark_want: float = float(interior.get("dark", 0.0)) if interior != null else 0.0
	_dark_k += (dark_want - _dark_k) * minf(1.0, dt * 2.5)
	if absf(_dark_k - dark_want) < 0.002: _dark_k = dark_want
	_fill.light_energy = _fill_k * (3.0 + 4.0 * TimeOfDay.night_factor(hour)) * (1.0 - _dark_k)
	_fill.visible = _fill_k > 0.01 and _dark_k < 0.98
	_update_occlusion(dt, interior)
	if interior == null and not fp_view(): world.update_cutaway(dt, player_pos if occ_script == null else occ_script.focus, cam.global_position)
	world.update_scatter_lod(player_pos)
	var _t2 := Time.get_ticks_usec()
	world.update(dt, clock)
	if lanes != null:
		lanes.update(dt, player_pos)
		var lh: String = lanes.take_hud()
		if lh != "": _show_hud(lh)
	_check_dead_end()
	placement.update()
	if weather != null:
		weather.update(dt, player_pos, cam.global_position, interior != null)
		world.wet_level = weather.wet
		if weather.dirty and Engine.get_process_frames() % 3 == 0: _apply_atmo()
	_apply_dark()
	if not _loading and not _leaving and not boats.riding() and not horse_ride.busy() and world.indoor == null: _check_portals()
	if not _loading and not _leaving and not boats.riding() and not horse_ride.busy(): _check_indoor()
	if _hud and _hud_t > 0.0:
		_hud_t -= delta; _hud.modulate.a = clampf(_hud_t, 0.0, 1.0)
	var _t3 := Time.get_ticks_usec()
	_update_lamps(clock)
	sky_mat.set_shader_parameter("u_time", clock)
	player.update_char(dt, cam)
	if npcs_amb: npcs_amb.update(dt, player_pos, hour, _loading or _leaving)
	if crowd != null and not _loading: crowd.update(dt)
	_update_dof(dt)
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
	# 인물 그림 비용(인물 빌더 1~3단계 측정): 텍스처 VRAM 전체 · 사람 종류(그림) 수 · 화면 안 사람
	var banks := {}
	if npcs_amb != null:
		for k in npcs_amb.agents: banks[String(npcs_amb.agents[k].ch.kind)] = true
	print("BENCH texmem_mb=%.0f vmem_mb=%.0f npc_people=%d npc_on_screen=%d npc_unique_looks=%d char_pages=%s" % [
		Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0, Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
		npcs_amb.stats.people if npcs_amb != null else 0, npcs_amb.stats.on_screen if npcs_amb != null else 0, banks.size(),
		str(preload("res://scripts/char_bank.gd").stats())])
	_quit()

# ---- 자동 스크린샷 ----
# 헤드리스(더미 렌더러)는 frame_post_draw를 보내지 않는다 — 그때는 process_frame으로 센다(공간 넘기·정리 대기가 멈추지 않게)
func _wait_frames(n: int) -> void:
	var sig: Signal = get_tree().process_frame if DisplayServer.get_name() == "headless" else RenderingServer.frame_post_draw
	for i in n: await sig

func _save(path: String) -> void:
	# --winshot: 창에 실제로 보이는 화면(지명 표시 등 2D 포함)
	var img := (get_viewport() if args.has("winshot") else scene_vp).get_texture().get_image()
	if img == null:   # 헤드리스(더미 렌더러)는 그림이 없다 — 찍기만 건너뛴다
		print("SHOT skip (no image) ", path)
		return
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

# --ridetest[=id]: 배 내릴 자리로 가서 타고 건너며 풍경 시점을 찍는다(뱃길 25%·55%·85%, 닿은 뒤)
func _ride_test_boat(id: String) -> void:
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await _wait_frames(10)
	var n := 0
	while _loading and n < 3000:
		await _wait_frames(1); n += 1
	if boats.routes.is_empty():
		print("RIDETEST 배 없음"); _quit(); return
	var r: Dictionary = boats.route(id) if id != "1" else boats.routes[0]
	if r.is_empty(): r = boats.routes[0]
	var e := int(args.get("rideend", "0"))
	var lp: Vector2 = r.land[e]
	teleport(lp.x, lp.y)
	rig.update(0, player_pos, player.facing, null, true)
	await _wait_frames(30)
	n = 0
	while (world.stats.jobs > 0 or placement.busy()) and n < 600:
		await _wait_frames(1); n += 1
	var dir: String = _abs(args.get("shotdir", "shots/region/boat"))
	var tag := String(r.id)
	_save(dir.path_join("%s_0_pier.png" % tag))
	print("RIDETEST near=%s prompt=%s" % [boats.near != null, boats.prompt])
	if not boats.board(String(r.id), e):
		print("RIDETEST 못 탐"); _quit(); return
	var marks := [0.25, 0.55, 0.85]
	var mi := 0
	var t0 := Time.get_ticks_msec()
	var fr := 0; var ft := 0.0
	while boats.riding():
		await _wait_frames(1)
		fr += 1; ft += get_process_delta_time()
		if fr % 300 == 0: print("RIDETEST f=%d fps=%.0f tris=%dk draws=%d" % [fr, Engine.get_frames_per_second(), RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME) / 1000, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)])
		var prog: float = absf(float(boats.ride.s) - (r.half if e == 0 else r.len - r.half)) / maxf(1.0, r.len - 2.0 * r.half) if boats.riding() else 1.0
		if mi < marks.size() and prog >= marks[mi]:
			await _wait_frames(4)
			_save(dir.path_join("%s_%d_ride.png" % [tag, mi + 1]))
			mi += 1
		if Time.get_ticks_msec() - t0 > 400000: print("RIDETEST 시간 넘음"); break
	print("RIDETEST done %s ride_s=%.1f avg_fps=%.1f pos=%s" % [tag, (Time.get_ticks_msec() - t0) / 1000.0, fr / maxf(ft, 0.001), player_pos])
	await _wait_frames(70)
	_save(dir.path_join("%s_9_arrive.png" % tag))
	_quit()

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
	var title := preload("res://scripts/ui/title_art.gd").logo_node(false)   # 게임 제목: 붓글씨 로고(한지 바탕이라 번짐 없이)
	var sub := Label.new(); sub.text = _space_title()
	sub.add_theme_font_size_override("font_size", 38); sub.add_theme_color_override("font_color", Color("#5a5048"))
	sub.set_anchors_preset(Control.PRESET_CENTER); sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.position = Vector2(-420, -14); sub.size = Vector2(840, 50)
	title.set_anchors_preset(Control.PRESET_CENTER)
	title.position = Vector2(-325, -276); title.size = Vector2(650, 650 / 2000.0 * 758.0)
	bg.add_child(title)
	_load_label = Label.new(); _load_label.add_theme_color_override("font_color", Color("#5a5048"))
	_load_label.set_anchors_preset(Control.PRESET_CENTER); _load_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_load_label.add_theme_font_size_override("font_size", 30)
	_load_label.position = Vector2(-420, 42); _load_label.size = Vector2(840, 56)
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
	if args.has("loadshot") and Engine.get_process_frames() == 20:   # 시험: 불러오기 화면 찍기
		get_viewport().get_texture().get_image().save_png(_abs(String(args.loadshot)))
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
		if Engine.has_meta(RideTest.META): _verify_fast.call_deferred()   # 역마 시험: 넘어간 자리 확인

func _prewarm_shaders() -> void:
	var mats := []
	Kit.material("water")   # 물 재질도 메인 스레드에서 미리(키트 짓기 작업 스레드에서 처음 만들지 않게)
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
	if crowd != null: crowd.rebuild()
	if placement.stats.get("placed", 0) > 0 and not args.has("markers"): world.remove_tagged("marker")
	if not args.has("nowallproxy"): world.build_wall_proxies(placement)
	player_pos.y = world.height_at(player_pos.x, player_pos.z)

# 끝내기: 진행 중인 작업 스레드(키트 짓기·식생·인물 자리)가 끝날 때까지 프레임을 돌리며 기다린 뒤 정리한다.
# 짓기 작업이 렌더 서버와 동기화하는 호출(메시 등)을 하면 메인 스레드가 막고 기다리는 동안 서로 기다려 멈췄다(--quit exit=124).
func _quit() -> void:
	if _quitting: return
	_quitting = true
	set_moon(1.0)
	await _drain_jobs()
	if placement: placement.stop()
	if world: world.shutdown()
	if weather: weather.reset_globals()
	_release_refs()
	preload("res://scripts/region/quit_cleanup.gd").run()   # static 캐시(재질·텍스처·그림 묶음)를 서버가 내려가기 전에 비운다
	get_tree().quit()

func _drain_jobs() -> void:
	_draining = true
	if placement: placement.cancel_jobs()
	RegionWorld.cancel_all = true
	var t0 := Time.get_ticks_msec()
	var n := 0
	while Time.get_ticks_msec() - t0 < 30000:
		if (placement == null or placement.jobs_idle()) and (world == null or world.jobs_idle()) \
				and (npcs_amb == null or npcs_amb.jobs_idle()):
			break
		await get_tree().process_frame
		n += 1
	if n > 0: print("DRAIN jobs waited frames=%d ms=%d" % [n, Time.get_ticks_msec() - t0])

const BG_FPS := 10          # 창이 포커스를 잃으면(다른 앱을 보는 동안) 이만큼만 그린다 — 발열·전력
var _fg_max_fps := -1      # 포커스를 잃기 전 Engine.max_fps(-1 = 낮추지 않음)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST: _quit()   # 창 닫기도 같은 길로(auto_accept_quit 끔)
	elif what == NOTIFICATION_PREDELETE: _release_refs()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT: _bg_throttle(true)
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN: _bg_throttle(false)

# 놀이 실행에서만: 시험·촬영·벤치(모래상자 실행)는 포커스와 상관없이 제 빠르기로 돈다
func _bg_throttle(on: bool) -> void:
	if Progress.SaveGuard.sandboxed() or args.has("bench"): return
	if on:
		if _fg_max_fps < 0: _fg_max_fps = Engine.max_fps
		Engine.max_fps = BG_FPS
	elif _fg_max_fps >= 0:
		Engine.max_fps = _fg_max_fps
		_fg_max_fps = -1

# RefCounted끼리 서로 잡은 고리를 끊는다(배 타기 ↔ 강 뱃길) — 장면을 다시 열거나 끝낼 때 새지 않게
# 변수는 비우지 않는다(끝내기 뒤에도 _process가 한두 프레임 돈다) — 한쪽 고리만 끊으면 둘 다 풀린다
func _release_refs() -> void:
	if lanes != null: lanes.boat_ride = null

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
	# 가장 가까운 길(주 도로뿐 아니라 갈림길 지선도 — 노정 갈림길로 들어오면 그 갈래길 끝에 선다)
	var road := Travel.main_road(world.region)
	var bi := 0; var bd := INF
	for rr in (world.region.get("roads", []) if world.is_route else [{ points = Array(road).map(func(v): return [v.x, v.y]) }]):
		var pts := PackedVector2Array()
		for q in rr.get("points", []): pts.append(Vector2(float(q[0]), float(q[1])))
		for i in pts.size():
			var d := pts[i].distance_to(p)
			if d < bd: bd = d; bi = i; road = pts
	if road.size() >= 2:
		if bd < 60.0:
			var nb := road[mini(bi + 3, road.size() - 1)] if road[mini(bi + 3, road.size() - 1)].distance_to(c) < road[maxi(bi - 3, 0)].distance_to(c) else road[maxi(bi - 3, 0)]
			if nb.distance_to(road[bi]) > 1.0: inward = (nb - road[bi]).normalized(); p = road[bi]
	p += inward * 16.0
	teleport(p.x, p.y)
	for pt in portals: _portal_armed[pt.id] = Vector2(pt.x, pt.z).distance_to(Vector2(player_pos.x, player_pos.z)) > PORTAL_ARM
	if world.is_route: _route_entry = _nearest_portal(Vector2(player_pos.x, player_pos.z))
	if horse_ride != null: horse_ride.on_arrived(Vector2(player_pos.x, player_pos.z))
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

func _nearest_portal(p: Vector2) -> String:
	var best := ""; var bd := INF
	for pt in portals:
		var d := Vector2(pt.x, pt.z).distance_to(p)
		if d < bd: bd = d; best = String(pt.id)
	return best

# 막다른 노정(포털이 한 끝뿐): 주 도로 먼 끝(마지막 쉼터)에 닿으면 '지나옴' — 그 뒤 권역 포털에서 H로 끝까지 건너뛴다
func _check_dead_end() -> void:
	if _dead_done or not world.is_route or not bool(world.region.get("dead_end", false)): return
	var road := Travel.main_road(world.region)
	if road.size() < 2: return
	if road[road.size() - 1].distance_to(Vector2(player_pos.x, player_pos.z)) < 25.0:
		_dead_done = true
		Progress.mark_route_done(String(world.region.get("route_id", world.region.get("region_id", ""))))

func _check_portals() -> void:
	var pp := Vector2(player_pos.x, player_pos.z)
	for pt in portals:
		var d := Vector2(pt.x, pt.z).distance_to(pp)
		# 역마: 이미 지나온 노정이면 권역 쪽 포털 곁에서 H로 반대쪽 끝까지 건너뛴다
		if not world.is_route and pt.kind == "route" and d < 16.0 and Progress.route_done(String(pt.target)):
			var ft := Travel.fast_target(String(pt.target), String(world.region.get("region_id", "")))
			if not ft.is_empty():
				if _fast_hint != String(pt.id):
					_fast_hint = String(pt.id)
					_show_hud("H: %s 타고 %s까지 (지나온 길 건너뛰기)" % [String(ft.get("how", "역마")), String(ft.label)])
				# H는 역마 창(fast_travel.gd)이 이 노정 끝을 먼저 골라 연다 — 시험(--fasttest)만 바로 넘어간다
				if args.has("fasttest") and _fast_hint == String(pt.id):
					ft.id = "fast_" + String(pt.id); ft.fast = true
					ft.label = "%s (%s)" % [String(ft.label), String(ft.get("how", "역마"))]
					_travel(ft); return
		elif _fast_hint == String(pt.id) and d > 20.0: _fast_hint = ""
		if not _portal_armed.get(pt.id, true):
			if d > PORTAL_ARM and _pt_path.is_empty(): _portal_armed[pt.id] = true
			continue
		if d < PORTAL_R:
			_travel(pt); return

# 전국 지도에서 고른 역마(region_map._fast_go): 포털 곁 H와 같은 건너뛰기
func _map_fast_test() -> void:
	await _wait_frames(30)
	_map.show_mode("nation")
	var ev := InputEventKey.new(); ev.pressed = true; ev.physical_keycode = KEY_1
	Input.parse_input_event(ev)
	await _wait_frames(20)
	if args.has("shot"): _save(_abs(String(args.shot).get_basename() + "_map.png"))
	var ev2 := InputEventKey.new(); ev2.pressed = true; ev2.physical_keycode = KEY_ENTER
	Input.parse_input_event(ev2)

func map_fast_travel(ft: Dictionary) -> void:
	if _loading or _leaving or world.is_route: return
	if FastTravel.refuse(self, "map"): return
	_travel(ft)

func _travel(pt: Dictionary) -> void:
	if FastTravel.refuse(self, "portal" if not pt.get("fast", false) else "skip"):   # 이야기가 먼 길을 막았다(남원 밤) — 포털은 물러나면 다시 선다
		_portal_armed[String(pt.get("id", ""))] = false
		return
	if world.is_route and String(pt.id) != _route_entry and not pt.get("fast", false):
		Progress.mark_route_done(String(world.region.get("route_id", world.region.get("region_id", ""))))
	var dir := Travel.find_route_dir(pt.target) if pt.kind == "route" else Travel.region_dir(pt.target)
	if dir == "" or world.space_file(dir) == "":
		_show_hud("길이 아직 닦이지 않았다: " + String(pt.label))
		_portal_armed[pt.id] = false
		return
	_leaving = true
	if story != null and story.has_method("on_leave_space"): story.on_leave_space(String(pt.target))   # 사건이 떠남을 안다(춘향 LEFT_AFTER_PART1 등)
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
	lb.add_theme_font_size_override("font_size", 49); lb.add_theme_color_override("font_color", Color("#2b2622"))
	lb.set_anchors_preset(Control.PRESET_CENTER); lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lb.position = Vector2(-560, -28); lb.size = Vector2(1120, 70)
	bg.add_child(lb)
	add_child(ui)
	Travel.set_pending(nxt)
	_leave.call_deferred()

func _leave() -> void:
	await _wait_frames(2)
	await _drain_jobs()
	placement.stop()
	world.shutdown()
	weather.reset_globals()
	_release_refs()
	get_tree().reload_current_scene()

# ---- 배 타기(boat_ride.gd): 나루·선창 끝에서 E로 오르면 사공이 저어 건넨다. Space(또는 E 누르고 있기) 건너뛰기 ----
func _update_boats(dt: float) -> void:
	if _loading or _leaving or world.indoor != null:
		_boat_text(""); return
	var st = story.get("_target") if story != null else null
	# E 차례: 이야기 인물 → 고을 사람·마부·깃발 → 배. 같은 프레임 E로 곁 사람과 말을 막 시작했으면(_target이 이미 비었어도) 배는 쉰다
	var free: bool = st == null and not (_map and _map.visible) and not _story_talking()
	var want: bool = free and Input.is_action_just_pressed("interact")
	_e_hold = _e_hold + dt if Input.is_action_pressed("interact") and free else 0.0
	# 걷기 시험: 앞으로 걸을 길 점 가운데 건너편 내릴 자리 30m 안이 있으면(길이 뱃길로 이어짐) 저절로 탄다
	if not _pt_path.is_empty() and boats.near != null and not boats.riding():
		var far: Vector2 = boats.near.r.land[1 - int(boats.near.end)]
		for i in range(_pt_i, _pt_path.size() - 1):   # 마지막 점(끝 포털)은 빼고
			if _pt_path[i].distance_to(far) < 30.0: want = true; break
	var skip: bool = Input.is_action_pressed("boat_skip") or _e_hold > 0.35 or args.has("rideskip")
	boats.update(dt, want, skip, story != null and story.owns_player())
	if rig.sailing != boats.riding():
		rig.sailing = boats.riding()
		_apply_low_view()
	if rig.sailing:
		rig.sail_dir = boats.heading(); rig.sail_side = boats.view_side(dt)
		_boat_text("")   # 건너뛰기 단추·Space는 travel_overlay가 띄운다(건너뛸 수 없는 뱃길이면 없음)
	else:
		_boat_text(("E   " + boats.prompt) if boats.prompt != "" and st == null else "")
	var bh: String = boats.take_hud()
	if bh != "": _show_hud(bh)

# 이야기 쪽 말 걸기(고을 사람·역참 마부·깃발 대화)가 돌고 있나 — E가 배·말로 새지 않게
func _story_talking() -> bool:
	if story == null: return false
	return int(story.e_frame) >= Engine.get_process_frames() - 1 or (story.ambient != null and story.ambient.busy) or (story.keeper != null and story.keeper.busy) or (story.ui != null and story.ui.modal)

# 낮은 풍경 시점(배·말): 먼 식생 벌 거리·해 그림자 거리·근경 타일 반경을 줄인다(낮은 시점은 멀리까지 보여 무겁다)
func _apply_low_view() -> void:
	var low: bool = rig.sailing or rig.riding
	world.scatter_far = minf(_scatter_base, SAIL_SCATTER) if low else _scatter_base
	world.update_scatter_lod(player_pos, true)
	# 낮은 시점은 그림자 거리 안에 기슭이 넓게 들어와 그림자 그리기가 무겁다(60m → 28m: 배·사람 그림자는 그대로)
	var sd := float(args.get("shadowdist", "60"))
	sun.directional_shadow_max_distance = minf(sd, 28.0) if low else sd
	world.set_near_r(1 if low else RegionWorld.NEAR_R)

# ---- 자동 기승(horse_ride.gd)·역마(fast_travel.gd) ----
func _update_horse(dt: float) -> void:
	if _loading or _leaving:
		return
	var st = story.get("_target") if story != null else null
	var map_open: bool = _map != null and _map.visible
	var fast_open: bool = fast_ui != null and is_instance_valid(fast_ui) and fast_ui.visible
	var owned: bool = story != null and story.owns_player()
	var free: bool = not map_open and not fast_open and not owned and not boats.riding() and world.indoor == null
	var want_e: bool = free and st == null and boats.prompt == "" and not _story_talking() and Input.is_action_just_pressed("interact")
	horse_ride.update(dt, free, want_e)
	var m: bool = horse_ride.mounted()
	if rig.riding != m:
		rig.riding = m
		_apply_low_view()
	rig.ride_k = horse_ride.cam_k()
	if m:
		rig.ride_dir = horse_ride.heading()
		rig.ride_side = horse_ride.view_side(dt)
	rig.shake_y = horse_ride.bob if m else 0.0
	# 아래 가운데 안내: 배 안내가 먼저
	if not boats.riding() and boats.prompt == "":
		if m: _boat_text(horse_ride.hint)
		elif st == null: _boat_text(horse_ride.prompt)
	var hh: String = horse_ride.take_hud()
	if hh != "": _show_hud(hh)
	# H: 아무 데서나 여는 역마 창은 없앴다(2026-10 — 역마는 역참 마부·길목 깃발에게 E로, 또는 지도 M의 역참 목록에서).
	#   남은 H는 지나온 노정 포털 곁의 '지나온 길 건너뛰기'(_check_portals가 안내를 띄운 자리)뿐 — 그 밖에서 누르면 안내만.
	if free and not horse_ride.busy() and Input.is_action_just_pressed("fast_travel") and not args.has("fasttest"):
		if _fast_hint != "": open_fast_travel(_fast_hint)
		else: _show_hud("역마 — 역참 마부나 길목 깃발에게 E로 말을 건다 (지도 M에서도 역을 고른다)")

func _verify_fast() -> void:
	await _wait_frames(30)
	RideTest.verify_arrival(self)

func open_fast_travel(prefer := "") -> void:
	if fast_ui != null and is_instance_valid(fast_ui): return
	if horse_ride == null or horse_ride.busy() or _loading or _leaving: return
	if FastTravel.refuse(self, "fast_ui"): return
	fast_ui = FastTravel.new(self, prefer)
	add_child(fast_ui)

# 아래 가운데 말·배 안내 — 이야기 UI의 조사·대화 안내(story_ui.prompt)와 같은 꼴·같은 줄(키 칸 + 흰 글, FS_PROMPT 46 · 1920×1080 기준).
#   글이 키로 시작하면("E   말에 오른다 …", "Space  건너뛰기") 그 키를 칸에 넣는다. 긴 줄은 띄어쓰기에서만 고르게 끊는다(StoryUI.wrap_words).
const _PROMPT_KEY := "^(?:[A-Z]|Space|Esc|Tab|Shift)$"
var _boat_key: Label
var _boat_shown := ""
func _boat_text(t: String) -> void:
	if _boat_prompt == null:
		if t == "": return
		var UiFonts := preload("res://scripts/ui_fonts.gd")
		var row := HBoxContainer.new(); row.name = "ride_prompt"
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		var chip := PanelContainer.new(); chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("#efe6d2", 0.95); sb.border_color = Color("#2b2622", 0.9); sb.set_border_width_all(1); sb.set_corner_radius_all(3)
		sb.content_margin_left = 10; sb.content_margin_right = 10; sb.content_margin_top = 0; sb.content_margin_bottom = 1
		chip.add_theme_stylebox_override("panel", sb)
		chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_boat_key = Label.new(); _boat_key.add_theme_font_override("font", UiFonts.main())
		_boat_key.add_theme_color_override("font_color", Color("#2b2622"))
		chip.add_child(_boat_key)
		_boat_prompt = Label.new()
		_boat_prompt.add_theme_font_override("font", UiFonts.main())
		_boat_prompt.add_theme_color_override("font_color", Color("#f4ecd8"))
		_boat_prompt.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.035))
		_boat_prompt.add_theme_constant_override("outline_size", 8)
		_boat_prompt.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.35))
		_boat_prompt.add_theme_constant_override("shadow_offset_y", 3)
		_boat_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(chip); row.add_child(_boat_prompt)
		var cl := CanvasLayer.new(); cl.layer = 6; cl.add_child(row); add_child(cl)
		cl.add_to_group(preload("res://scripts/hud_gate.gd").HIDE)   # 기록책·지도·메뉴가 열리면 감춤
		get_viewport().size_changed.connect(func(): _boat_shown = "~"; _boat_text(String(_boat_prompt.get_meta("raw", ""))))
	if t == _boat_shown: return
	_boat_shown = t
	_boat_prompt.set_meta("raw", t)
	var row: HBoxContainer = _boat_prompt.get_parent()
	row.visible = t != ""
	if t == "":
		if story != null and story.get("ui") != null: story.ui.set_bottom_extra(0.0)
		return
	var vs := get_viewport().get_visible_rect().size
	var k := preload("res://scripts/ui_fonts.gd").k(vs, 0.8)
	var key := ""
	var body := t.strip_edges()
	var sp := body.find(" ")
	if sp > 0 and RegEx.create_from_string(_PROMPT_KEY).search(body.substr(0, sp)) != null:
		key = body.substr(0, sp); body = body.substr(sp).strip_edges()
	var fs := int(StoryUI.FS_PROMPT * k)
	_boat_key.get_parent().visible = key != ""
	_boat_key.text = key
	_boat_key.add_theme_font_size_override("font_size", int(StoryUI.FS_CHIP * k))
	_boat_prompt.add_theme_font_size_override("font_size", fs)
	_boat_prompt.text = StoryUI.wrap_words(_boat_prompt.get_theme_font("font"), fs, body, vs.x * 0.86 - 84 * k)
	row.add_theme_constant_override("separation", int(14 * k))
	# story_ui 안내 줄(BOTTOM_PROMPT)과 같은 자리 — 두 줄이면 위로 자란다
	row.reset_size()
	var h := row.get_combined_minimum_size().y
	var top := vs.y - StoryUI.BOTTOM_PROMPT * k
	row.position = Vector2(0, top + 73 * k - maxf(h, 73 * k))
	row.size = Vector2(vs.x, maxf(h, 73 * k))
	if story != null and story.get("ui") != null: story.ui.set_bottom_extra(maxf(0.0, h - 73 * k))   # 두 줄이면 안내 띠·자막을 그만큼 올린다

# 화면(카메라 yaw) 기준 방향 이름 — 배 위처럼 카메라가 돌았을 때 그림 방향(up=등, down=앞, left·right=옆)
func facing_cam(dx: float, dz: float, prev: String) -> String:
	if dx == 0.0 and dz == 0.0: return prev
	var r := cam.global_transform.basis.x; var f := -cam.global_transform.basis.z
	var rx := Vector2(r.x, r.z).normalized(); var fw := Vector2(f.x, f.z).normalized()
	var v := Vector2(dx, dz)
	return facing_from(v.dot(rx), -v.dot(fw), prev)

func _on_boat_arrived(_id: String, _place: String) -> void:
	_pt_stuck = 0.0; _pt_last = player_pos
	if _pt_path.is_empty(): return
	# 걷기 시험: 내린 자리에서 가장 가까운 앞쪽 길 점부터 이어 걷는다
	var pp := Vector2(player_pos.x, player_pos.z)
	var bi := _pt_i; var bd := INF
	for i in range(_pt_i, _pt_path.size()):
		var d := _pt_path[i].distance_to(pp)
		if d < bd: bd = d; bi = i
	_pt_i = bi
	_pt_walk.last = pp

func _show_hud(t: String) -> void:
	if _hud == null:
		_hud = Label.new()
		_hud.add_theme_font_override("font", preload("res://scripts/ui_fonts.gd").main())
		var hk := preload("res://scripts/ui_fonts.gd").k(get_viewport().get_visible_rect().size, 0.8)
		_hud.add_theme_font_size_override("font_size", int(41 * hk))
		_hud.add_theme_color_override("font_color", Color(1, 1, 1))
		_hud.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		_hud.add_theme_constant_override("outline_size", 7)
		_hud.position = Vector2(34, 28) * hk
		var cl := CanvasLayer.new(); cl.layer = 6; cl.add_child(_hud); add_child(cl)
		cl.add_to_group(preload("res://scripts/hud_gate.gd").HIDE)
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
			# 플레이어 둘레 가장 가까운 길 점부터(출발 포털 뒤쪽 길 끝으로 되돌아가지 않게)
			var i0 := 0; var d0 := INF
			for i in road.size():
				if road[i].distance_to(here) < d0: d0 = road[i].distance_to(here); i0 = i
			road = road.slice(i0)
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
