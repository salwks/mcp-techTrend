# 이야기 총괄 — 권역 장면(region_main) 위에서 사건 하나를 돌린다(웹 src/story/index.js + 코어 연결 대응).
#   - 사건 데이터(story/<사건>/<사건>_data.gd: 사건 장면 §44 필드 + 단계 목록, 인물·조사 대상·자리·싸움터·소품)와
#     사건 GDScript(story/<사건>/<사건>_case.gd: 기록책·결말·복잡한 연출)를 읽는다.
#   - 상태(story_state) 저장·불러오기(progress.gd), 명령 실행(story_runner), UI(story_ui), 전투(combat_view)
#   - 조사 안내: 가장 가까운 이야기 대상(인물·물건)을 E로. R: 사건 기록. 컷신·대화 중에는 플레이어 조작을 막는다.
#   - 소품: 조건(when)이 참일 때만 보이는 키트·데칼(단서·지역 변화). 인물: 조건·국면(phase)별 자리.
#   - 소문(story/rumors_data.gd): 결말(§7 CASE_*_OUTCOME)에 따라 달라지는 주변 대화 — 권역·노정 어디서나. 엿들은 소문도 기록책 '들음'.
#   - 고을 사람 말 걸기(scripts/story/ambient_talk.gd): 이야기 대상이 없을 때 가까운 주변 인물에게 E — 사건 없는 공간에서도.
#   - 이야기 인물 말 표시: 새로 할 말이 있는 인물(talk 항목 조건이 맞고 그 줄을 아직 안 들음 — talk_pending)은 머리 위 「…」(onboarding).
#     흔한 바탕 그림(마을 사람 등)을 쓰는 이야기 인물은 테두리에 옅은 붉은 먹빛(accent)을 더해 고을 사람과 섞이지 않게.
#   - 비우기 구역(제작 규칙 C63): 행차·출두·관아 행사·상여 길 한가운데에서 고을 사람(npc_ambient)을 잠시 비운다 —
#     데이터 "ambient_exclude": [{ id, path|rect, width, when }](when이 서면 비우고 지면 풂) · 코드 ambient_exclude(id, 구역, 폭) / ambient_release(id).
# region_main은 create_for()로 만들고 매 프레임 update(dt), blocks_move(), drives_player(), shake_offset()만 부른다.
extends Node

const StoryUI := preload("res://scripts/story/story_ui.gd")
const StoryState := preload("res://scripts/story/story_state.gd")
const StoryRunner := preload("res://scripts/story/story_runner.gd")
const CombatView := preload("res://scripts/combat/combat_view.gd")
const Progress := preload("res://scripts/region/progress.gd")
const Rumors := preload("res://story/rumors_data.gd")
const Skills := preload("res://scripts/story/skills.gd")
const Sound := preload("res://scripts/audio/sound.gd")   # 공용 소리(scripts/audio/sound.gd)
# 공간 → 사건(여럿일 수 있음): scripts/story/case_registry.gd(예전 CASES). 여기서는 그중 지금 돌릴 사건 하나(case_id)를 StoryRunner에 잇는다.
# 한 사건이 여러 공간(권역 + 노정)에 걸치면 같은 사건 id를 준다(진행은 하나). 데이터 항목의 "space"로 공간을 가른다(_filter_space)
const CaseRegistry := preload("res://scripts/story/case_registry.gd")
const KIND_FALLBACK := { story_girl = "child_girl", story_boy = "child_boy", ricecake_mother = "villager_f", farmwife = "villager_f",
	peddler = "villager_m", merchant = "villager_m", traveler = "villager_m", scholar = "elder",
	woochi = "villager_m", chaekkwae = "merchant", pojol = "official",
	wolsim = "shaman", thief = "villager_m", spirit_m = "elder",
	blind_elder = "elder", broker = "merchant", daughter = "villager_f", fisher = "boatman",
	smuggler = "villager_m", smuggler_b = "villager_m", lantern_wife = "villager_f", charcoal_man = "villager_m", spirit_f = "spirit_m",
	py_merchant_a = "merchant", py_merchant_b = "peddler", py_swindler = "smuggler", py_swindler_b = "smuggler_b", py_clerk = "official",
	yigyeom = "elder", courier = "villager_m", courier_b = "villager_m", courier_c = "villager_m", raider = "smuggler", raider_b = "smuggler_b",
	gwak = "elder", simbang = "shaman", jj_child = "child_girl", jj_man = "villager_m", jj_woman = "villager_f", jj_snake = "dog", jj_shade = "spirit_m",
	chunhyang = "villager_f", hyangdan = "villager_f", wolmae = "innkeeper", mongryong = "scholar", bangja = "villager_m",
	chunhyang_prison = "chunhyang", mongryong_beggar = "mongryong", byeon = "official", gisaeng = "villager_f", gisaeng_b = "gisaeng", gisaeng_c = "gisaeng" }
const BANK_FILES := ["frames_story.json", "frames_story_hanyang.json", "frames_gangneung.json", "frames_story_hwangju.json", "frames_gyeongju.json", "frames_pyongyang.json", "frames_story_hamhung.json", "frames_jeju.json", "frames_story_namwon_chunhyang.json", "frames_story_chunhyang_part2.json", "frames_npc.json", "frames_amb.json"]

var main                # region_main
var ui
var S
var runner
var combat_view
var case_fn
var data := {}
var events := {}
var case_id := ""
var space_id := ""
var log_story := false
var log_combat := false
var test = null          # story_test(--storytest)
var actors := {}         # id → { spec, ch, pos, facing, scripted, shown, path, speed, end_anim, y_abs, name }
var props := {}          # id → { spec, node, shown, decal_ids }
var _props_root: Node3D
var _dirty := true
var _cut := false
var _target = null
var _trig_t := 0.0
var _started := false
var _rumor_seen := {}
var _rumor_t := 0.0
var _night_roar_t := 0.0
var _bank_src := {}
var passive := false     # --bench·--tour·--shot 등 시험 실행: 여는 장면·순간이동 없이 인물·소품만
var free_move := false   # 추격(scripts/story/chase.gd) 동안: 이야기가 돌고 있어도 플레이어가 움직인다
var title = null         # 시작 메뉴(scripts/story/title_menu.gd) — 열려 있는 동안 이야기를 멈춘다
var _where_t := 0.0
var _resumed := false
var onboard = null             # scripts/story/onboarding.gd
var _skills_msgs: Array = []   # 사건이 끝나 새로 익힌 행동(결말 카드 뒤 한 줄씩)
var _vign = null               # 길가 장면(scripts/story/vignettes.gd — v2.2 R0104 등, 사건 기록 없음)
var _rub = null                # 탁본(scripts/story/rubbing.gd — SKILL_RUBBING, 어느 공간에서나)
var ambient = null             # 고을 사람 말 걸기(scripts/story/ambient_talk.gd)
var keeper = null              # 역참 마부·길목 깃발 대화 — 역마 입구(scripts/region/station_keeper.gd)
const TalkFrame := preload("res://scripts/story/talk_frame.gd")
const TALK_IN := 0.55          # 대화 구도로 옮기는 시간(대화 카메라 v1.1 §4 CAM_TALK_2)
const TALK_OUT := 0.45         # 대화 끝 평소 시점으로 돌아오는 시간
const NPC_TURN_DELAY := 0.2    # 상대가 플레이어 쪽으로 도는 늦춤(§5)
var hush_hints := false        # 걸으며 보는 제목(main_p1 OP01) 동안 안내 줄을 감춘다 — 이동은 막지 않는다
var doc_hook: Callable = Callable()   # 시험: 문서 비교 화면이 열리면 부른다(documents.gd — test.doc_exam이 없을 때)
var talking := false           # 말 걸기 접근(한 걸음·구도)부터 대화 끝까지 — 그동안 E·이동을 받지 않는다(중복 E 막기)
var _step_face := ""          # 한 걸음이 정한 플레이어 그림 쪽(대본이 바꿨는지 보려고)
var _stepping := false         # 플레이어 한 걸음(걷기 그림을 idle로 되돌리지 않게)
var _tf = null                 # scripts/story/talk_frame.gd
var _plain_turned := false     # 고을 사람 대화가 카메라를 옆으로 돌렸나(talk_plain_end가 되돌린다)
var _talk_occ = null           # 대화 동안 건 가림 기준점(region_main.occ_script) — 내가 건 것만 푼다
var last_frame := {}           # 마지막 대화 구도(시험·촬영 로그)
var talk_cam := {}             # 지금 이야기 인물 대화 카메라(CameraRig.talk_spec — 공통 TALK·사건·인물 덮어쓰기). 대화가 끝나면 비운다
var _music_t := 0.0
var _music_cur := "?"          # 지금 튼 음악 id(사건 case_fn.music_wanted — 없으면 "")
var _excl_on := {}             # 비우기 구역 id → 구역(지금 켜진 것 — 데이터 when·코드 둘 다)
# 고을 사람(주변 인물)과 같은 바탕 그림 — 이걸 쓰는 이야기 인물에는 테두리 빛을 더한다
const GENERIC_KINDS := ["villager_m", "villager_f", "elder", "child_boy", "child_girl", "hunter", "innkeeper", "miller", "woodcutter",
	"scholar", "merchant", "peddler", "official", "monk", "bosal", "boatman", "haenyeo", "farmer", "farmwife", "herder", "raincape", "traveler", "shaman"]
const ACCENT := Color("#e6b48c")   # 한지빛 테두리 대신 옅은 주홍 한지(아주 약하게)

# 사건 완료(v2.2 레벨 없음): CASE_<키>_COMPLETE를 세우고 숙련 해금표(skills.gd)를 훑는다
func _case_complete() -> Array:
	S.vars[Skills.complete_var(data.get("case", {}), case_id)] = true
	var got := Skills.unlock(S.vars)
	if not got.is_empty(): runner.log_line("skills", got)
	return got
var spirits = null       # 잔영·소리·경계·호신물(scripts/story/spirits.gd) — 사건마다
var sensing = null       # 감응 매듭·흔적의 결(scripts/story/sensing.gd) — 사건마다(매듭을 지닐 때만 그린다)

static func create_for(m) -> Node:
	var rid := String(m.world.region.get("region_id", ""))
	var d = load("res://scripts/story/story_director.gd").new()
	d.main = m
	d.space_id = rid
	m.add_child(d)
	d._setup()
	return d

# ---- region_main이 부르는 것 ----
func blocks_move() -> bool:
	return (talking and not free_move) or (runner != null and runner.busy and not free_move) or (ui != null and (ui.modal or ui.journal_open)) or _cut or (title != null and title.active)

func drives_player() -> bool:
	return combat_view != null and combat_view.active

# 먼 길 막음(fast_travel.lock_why가 묻는다): 사건이 정한 알림 글, 없으면 "" — 걷기는 막지 않는다
func travel_lock() -> String:
	if case_fn != null and S != null and case_fn.has_method("travel_lock"): return String(case_fn.travel_lock())
	return ""

# 이 공간을 떠난다(region_main._travel — 걷기 포털·역마·지도 모두): 사건이 알고 싶으면 case_fn.on_leave(갈 곳 id). 사건 상태는 저장한다
func on_leave_space(target: String) -> void:
	if case_fn == null or S == null or not _started: return
	cut_fog_end()
	if case_fn.has_method("on_leave"): case_fn.on_leave(target)
	save()

# 이 프레임 플레이어 이동을 이야기가 쥐고 있나(전투 중이거나 대화·컷신으로 막힘)
func owns_player() -> bool:
	return drives_player() or blocks_move()

func shake_offset() -> Vector3:
	return combat_view.shake_offset if combat_view != null else Vector3.ZERO

# combat_view가 쓰는 것
var world:
	get: return main.world
var player:
	get: return main.player
var player_pos:
	get: return main.player_pos
var cam:
	get: return main.cam
var rig:
	get: return main.rig
func scene_root() -> Node: return main.scene_vp
func set_player_pos(p: Vector3) -> void:
	main.player_pos = p
	main.player.position = p

# ---------------------------------------------------------------------------
# 준비
# ---------------------------------------------------------------------------
func _setup() -> void:
	name = "story"
	var args: Dictionary = main.args
	log_story = args.has("storylog") or args.has("storytest")
	log_combat = log_story
	Sound.verbose = log_story   # 시험 로그에 SOUND 줄
	if args.has("savefile"): Progress.use_path(String(args.savefile))
	elif args.has("storytest"): Progress.use_path("user://storytest_progress.json")
	_setup_input()
	ui = StoryUI.new()
	add_child(ui)
	ui.on_say = on_say
	ui.log_lines = log_story
	onboard = load("res://scripts/story/onboarding.gd").new(self)   # 처음 하는 사람 안내·먹점·Esc 메뉴(사건 없는 공간에서도)
	add_child(onboard)
	ambient = load("res://scripts/story/ambient_talk.gd").new(self)
	keeper = load("res://scripts/region/station_keeper.gd").new(self)
	add_child(load("res://scripts/story/save_keeper.gd").new(self))
	add_child(load("res://scripts/ui/waypoint_hud.gd").new(self))   # 지도 목적지 방위 줄(재기획 3단계 최소판)   # 저장이 보이게: 자동 기록 도장·주막 쉬기·저장 칸(Esc)
	_props_root = Node3D.new(); _props_root.name = "story_props"
	main.scene_vp.add_child(_props_root)
	# 이 공간에 올린 사건들(파일이 있는 것만). 대본 시험은 이름 앞부분(namwon:A → namwon)이 이 공간 사건이면 그것만 본다
	var cands: Array = CaseRegistry.cases_for(space_id)
	var prefer := String(args.get("storytest", "")).get_slice(":", 0)
	if cands.has(prefer): cands = [prefer]
	elif args.has("case") and cands.has(String(args.case)): cands = [String(args.case)]   # 시험·촬영: 이 공간에서 이 사건만(재기획 3단계 — 새 게임 기본이 메인 서장이 된 뒤 오누이 기준 시험)
	if cands.is_empty():
		_maybe_title()
		return   # 소문만(노정·다른 권역)
	case_id = String(cands[0])
	var test_path := CaseRegistry.test_path(case_id)
	# 대본 시험이 앞 사건 저장을 꾸민다 — 시험 도중 다른 공간으로 넘어온 장면(같은 사건의 노정 등)이면 꾸미지 않고 이어 간다
	var arrived: bool = not main._pending.is_empty() and not bool(main._pending.get("newgame", false))
	if args.has("storytest") and FileAccess.file_exists(test_path):
		var ts: Script = load(test_path)
		if ts == null or not ts.can_instantiate():   # 시험 스크립트 해석 오류 — 시간 초과까지 멈춰 있지 말고 바로 FAIL
			print("STORYTEST FAIL %s 시험 스크립트를 불러오지 못함(%s)" % [String(args.storytest), test_path])
			main._quit.call_deferred(); return
		if not arrived: ts.prepare(self)
	# 앞 사건이 끝나야 서는 사건(case.requires {변수: 값}) — 아니면 소문만. 쉼표 목록 값(MAIN_MASTER_TRACE "HANYANG,GANGNEUNG")은 들어 있으면 맞음
	# 후보가 여럿이면 요구가 맞고 아직 안 끝난 첫 사건(case_registry.choose). 하나뿐이면 예전과 같다
	var pick: Dictionary = CaseRegistry.choose(cands)
	case_id = String(pick.id)
	if case_id == "":
		if String(pick.why_id) != "": printerr("STORY case=%s 아직 아님(%s)" % [pick.why_id, pick.why_key])
		else: printerr("STORY 사건 데이터를 읽지 못함 — 소문만(%s)" % ", ".join(cands))
		data = {}; events = {}
		_maybe_title()
		return
	combat_view = CombatView.new()
	combat_view.name = "combat"
	main.scene_vp.add_child(combat_view)
	combat_view.setup(self)
	SpriteChar.merge_bank("frames_story_skills.json", ["player"])   # v2.2 숙련 동작(shove·quick_throw, 작다) — 없으면 그냥 지나간다
	var fresh: bool = (args.has("newgame") or args.has("storytest")) and not arrived
	if not _setup_case(case_id, pick.data, fresh):
		_maybe_title()
		return
	printerr("STORY pick case=%s rule=%d" % [case_id, int(pick.get("rule", 0))])
	passive = not args.has("storytest") and (args.has("bench") or args.has("tour") or args.has("shot") or args.has("portaltest") or args.has("walkroute") or args.has("talktest") or args.has("preptest") or args.has("prepshot") or args.has("p2preptest") or args.has("p2prepshot"))
	if args.has("storytest"):
		test = load(test_path if FileAccess.file_exists(test_path) else "res://scripts/story/story_test.gd").new(self, String(args.storytest))
		add_child(test)
	_maybe_title()
	printerr("STORY ready case=%s phase=%s actors=%d props=%d events=%d" % [case_id, S.phase, actors.size(), data.get("props", []).size(), events.size()])

# 사건 하나를 세운다(처음 · switch_case). fresh: 새로 시작(그 사건 저장을 비움) · 아니면 저장에서 읽는다. 스크립트를 못 읽으면 false(소문만)
func _setup_case(id: String, dd: Dictionary, fresh: bool) -> bool:
	var cscript = load(CaseRegistry.case_path(id))
	if cscript == null or not cscript.can_instantiate():   # 사건 스크립트 해석 오류 — 게임은 소문만으로 이어 간다
		printerr("STORY case=%s 사건 스크립트를 불러오지 못함 — 소문만" % id)
		case_id = ""; data = {}; events = {}
		return false
	case_id = id
	data = dd
	_filter_space()
	events = data.get("events", {})
	S = StoryState.new(case_id)
	runner = StoryRunner.new(self, S)
	case_fn = cscript.new(self)
	runner.case_fn = case_fn
	if fresh: S.clear_saved(data.get("case", {}).get("reset_vars", null))
	elif S.load_saved():
		printerr("STORY loaded case=%s phase=%s flags=%d clues=%d" % [case_id, S.phase, S.flags.size(), S.clues.size()])
	for a in data.get("actors", []): _make_actor(a)
	spirits = load("res://scripts/story/spirits.gd").new()
	add_child(spirits)
	spirits.setup(self)
	sensing = load("res://scripts/story/sensing.gd").new()
	add_child(sensing)
	sensing.setup(self)
	_dirty = true
	return true

# 지금 사건을 내린다(저장한 뒤 인물·소품·잔영·감응·비우기 구역을 거둔다). 전투·대화 도중에는 부르지 않는다(switch_case가 막는다)
func _teardown_case(keep_save := true) -> void:
	# keep_save=false(새 게임): 방금 비운 저장에 내리는 사건 상태를 다시 쓰지 않는다(쓰면 메인 서장이 옛 저장 합류로 오인)
	if keep_save and S != null and (test == null or main.args.has("storysave")): S.save()
	if runner != null: runner.gen += 1; runner.busy_count = 0
	for id in actors.keys():
		var a: Dictionary = actors[id]
		if a.ch != null and is_instance_valid(a.ch): a.ch.queue_free()
	actors.clear()
	for id in props.keys():
		var rec: Dictionary = props[id]
		_prop_cols(rec, false)
		if rec.node != null and is_instance_valid(rec.node): rec.node.queue_free()
		if rec.get("decals", []) is Array and not (rec.decals as Array).is_empty(): _decal_prop(rec, false, Vector2.ZERO)
	props.clear()
	for zid in _excl_on.keys(): ambient_release(zid)
	if spirits != null and is_instance_valid(spirits): spirits.queue_free()
	if sensing != null and is_instance_valid(sensing): sensing.queue_free()
	spirits = null; sensing = null
	camera(null)
	cutscene(false)
	_talk_occ_end()
	talking = false
	_target = null
	ui.prompt("")
	_music_cur = "?"
	_rumor_seen = {}

# 같은 공간에서 도는 사건을 바꾼다(장면을 다시 열지 않는다 — 재기획 3단계):
#   새 게임(title_menu) · 메인 서장 → 오누이 들머리(행상) · 오누이 끝 → 메인 합류(yield_when_done) · 시험의 저장 재개.
#   opts: fresh(그 사건을 새로 — 저장을 비움) · nosave(내리는 사건을 저장하지 않음 — 새 게임) · event(세운 뒤 곧바로 돌릴 장면 id) · reload(같은 사건이어도 저장에서 다시 읽기)
#   대화·전투·컷 도중이면 하지 않고 false.
signal case_switched(id: String)
func switch_case(id: String, opts := {}) -> bool:
	if combat_view != null and combat_view.active: return false
	if id == case_id and not bool(opts.get("reload", false)) and not bool(opts.get("fresh", false)): return false
	var dd := CaseRegistry.load_data(id)
	if dd.is_empty(): return false
	var from := case_id
	_teardown_case(not bool(opts.get("nosave", false)))
	if not _setup_case(id, dd, bool(opts.get("fresh", false))): return false
	_started = false   # 다음 프레임 update()가 _apply_world → 첫 장면(start_event)·이어 하기 판정
	_keep_hour = not bool(opts.get("fresh", false))
	_switch_event = String(opts.get("event", ""))
	_yield_t = 0.0
	if main.get("placement") != null: main.placement.gate.mark()
	printerr("STORY switch %s → %s phase=%s fresh=%s event=%s" % [from, id, S.phase, bool(opts.get("fresh", false)), _switch_event])
	case_switched.emit(id)
	return true
var _switch_event := ""
var _keep_hour := false
var _yield_t := 0.0
var _test_begun := false

# 끝난 독립 사건이 메인에 자리를 내준다(case.yield_when_done — 오누이): 끝(phase done)이고 한가한 채 YIELD_SEC 지나면 다시 고른다(추가 지시 2)
const YIELD_SEC := 4.0
func _update_yield(dt: float) -> void:
	if S == null or S.phase != "done" or not bool(data.get("case", {}).get("yield_when_done", false)): _yield_t = 0.0; return
	if runner.busy or talking or ui.modal or ui.journal_open or _cut or (combat_view != null and combat_view.active) or test != null: _yield_t = 0.0; return
	_yield_t += dt
	if _yield_t < YIELD_SEC: return
	_yield_t = 0.0
	S.save()
	if rechoose(): printerr("STORY yield %s 끝 — 메인으로 합류" % "done")

# 이 공간의 사건을 다시 고른다(case_registry.choose) — 다른 사건이 나오면 바꾼다
func rechoose() -> bool:
	var pick: Dictionary = CaseRegistry.choose(CaseRegistry.cases_for(space_id))
	var nid := String(pick.id)
	if nid == "" or nid == case_id: return false
	return switch_case(nid)

# 여러 공간에 걸친 사건: 항목에 "space"(공간 id 하나 또는 배열)가 있으면 그 공간에서만 쓴다
func _filter_space() -> void:
	for key in ["actors", "objects", "triggers", "props", "spirits", "rubbings", "map_places"]:
		if not (data.get(key) is Array): continue
		data[key] = data[key].filter(func(e): return not (e is Dictionary and e.has("space")) or \
			(e.space is Array and e.space.has(space_id)) or String(e.space) == space_id)

func _setup_input() -> void:
	for act in { interact = KEY_E, journal = KEY_R }:
		if not InputMap.has_action(act): InputMap.add_action(act)
	var ev := InputEventKey.new(); ev.physical_keycode = KEY_E
	if InputMap.action_get_events("interact").is_empty(): InputMap.action_add_event("interact", ev)
	var ev2 := InputEventKey.new(); ev2.physical_keycode = KEY_R
	if InputMap.action_get_events("journal").is_empty(): InputMap.action_add_event("journal", ev2)

# ---------------------------------------------------------------------------
# 프레임
# ---------------------------------------------------------------------------
func update(dt: float) -> void:
	if main._loading: return
	if title != null and title.active: return
	if not _resumed:
		_resumed = true
		if main._pending.has("resume_at"): teleport_to(main._pending.resume_at)   # 이어 하기로 다른 공간에서 넘어옴
	_save_where(dt)
	if _vign == null: _vign = load("res://scripts/story/vignettes.gd").new(self)
	_vign.update(dt)
	# 대본 시험: 싸움은 프레임마다 고정 걸음(시험 봇도 1/60초 걸음으로 판단한다) — 기계 부하·프레임 흔들림에 결과가 바뀌지 않게
	if combat_view != null: combat_view.update(Engine.time_scale / 60.0 if test != null and combat_view.active else dt)
	if _rub == null:
		_rub = load("res://scripts/story/rubbing.gd").new(); add_child(_rub); _rub.setup(self)
	_update_music(dt)
	if case_id == "":
		_update_rumors(dt)
		_rub.update(dt)
		if talking or ui.modal or ui.journal_open or ambient.busy or keeper.busy:
			ui.prompt(""); _target = null
		else: _update_target()
		return
	if not _started:
		_started = true
		_apply_world()
		var cs: Dictionary = data.get("case", {})
		var arrive_ok: bool = main._pending.is_empty() or bool(cs.get("start_on_arrival", false)) or bool(main._pending.get("newgame", false))
		if _switch_event != "":   # switch_case가 정한 첫 장면(오누이 북쪽 들머리 N0000 등) — 시작 장면 대신
			var ev := _switch_event
			_switch_event = ""
			runner.run([{ "event": ev }])
		elif S.phase == "start" and arrive_ok and not passive:
			var se = cs.get("start_event", "S0001")
			if se is Dictionary: se = se.get(space_id, "")   # 공간마다 다른 첫 장면("" = 그 공간에서는 시작하지 않음)
			if String(se) == "": S.phase = "start"
			elif test == null or test.get("run_start_event") == true: runner.run([{ "event": String(se) }])
		elif S.phase == "start":
			S.phase = "explore"
		if test != null and test.has_method("begin") and not _test_begun:
			_test_begun = true
			test.begin()
	_update_yield(dt)
	if blocks_move() and not drives_player() and not _stepping and main.player.anim in ["walk", "run"]: main.player.set_anim("idle")
	_update_actors(dt)
	if _dirty: _refresh()
	_update_props()
	_update_rumors(dt)
	_update_ambient(dt)
	if spirits != null: spirits.update(dt)
	if sensing != null: sensing.update(dt)
	if talking or runner.busy or ui.modal or combat_view.active or ambient.busy or keeper.busy:
		ui.prompt("")
		_target = null
		return
	# 첫 E가 가끔 버려지던 까닭(새 게임 직후 주모): E 대상이 먼저 잡히고 같은 자리의 트리거(전경 늦은 트리거 s0001_vista_late)는
	# 0.2초 간격 검사에서 한두 프레임 늦게 이야기를 시작했다 — 그 사이 누른 E는 runner.busy에 막혀 버려졌다.
	# 그래서 (1) 트리거가 이야기를 시작한 프레임에는 대상을 내놓지 않고 (2) 대상이 새로 잡히는 프레임에는 그 자리 트리거를 먼저 본다.
	_trig_t -= dt
	if _trig_t <= 0.0:
		_trig_t = 0.2
		_check_triggers()
		if runner.busy:
			ui.prompt(""); _target = null
			return
	var had: bool = _target != null
	_update_target()
	if _target != null and not had and _trig_t < 0.2:
		_trig_t = 0.2
		_check_triggers()
		if runner.busy:
			ui.prompt(""); _target = null
			return
	_rub.update(dt)

var e_frame := -1   # 곁 대상(이야기 인물·고을 사람·마부·깃발)이 E를 가져간 프레임
func _unhandled_input(ev: InputEvent) -> void:
	if main._loading or (title != null and title.active): return
	if not (ev is InputEventKey and ev.pressed and not ev.echo): return
	if ev.is_action("interact") and _target != null: e_frame = Engine.get_process_frames()   # 이 E는 곁 대상의 것 — 배·말이 같은 프레임 E를 쓰지 않게(region_main)
	# 기록책(여행 기록·사건 기록·여행 방법)은 사건이 없는 노정에서도 연다
	if ev.is_action("journal") and not ui.modal and not (combat_view != null and combat_view.active) and (case_id == "" or _started):
		ui.journal_toggle(journal_data())
		get_viewport().set_input_as_handled()
		return
	# 고을 사람 말 걸기(사건이 없는 공간에서도)
	if talking: return
	if ev.is_action("interact") and _target != null and String(_target.kind) == "ambient" and not ui.busy_input() \
			and not (runner != null and runner.busy) and not (combat_view != null and combat_view.active):
		get_viewport().set_input_as_handled()
		_fp_face_target(_target)
		ambient.talk(int(_target.key))
		return
	# 역참 마부·길목 깃발(사건이 없는 공간에서도) — 역마는 여기서만 고른다
	if ev.is_action("interact") and _target != null and String(_target.kind) in ["keeper", "flag"] and not ui.busy_input() \
			and not (runner != null and runner.busy) and not (combat_view != null and combat_view.active):
		get_viewport().set_input_as_handled()
		_fp_face_target(_target)
		keeper.talk(_target)
		return
	if case_id == "" or not _started: return
	if ev.is_action("interact") and _target != null and not ui.busy_input() and not runner.busy and not combat_view.active:
		get_viewport().set_input_as_handled()
		interact(_target.id)

# 1인칭: 말 걸 곁 대상(고을 사람·마부·깃발)의 머리 쪽으로 시선을 돌린다
func _fp_face_target(t) -> void:
	if t == null or not bool(main.get("fp_active")): return
	var p: Vector2 = t.p
	main.fp_look_at(Vector3(p.x, world.height_at(p.x, p.y) + 1.45, p.y))

# 지도에서 목적지를 정했다(region_map.waypoint_pinned) — 안내(WAYPOINT)를 끝내고 사건에 알린다. 세계 방위 줄은 waypoint_hud가 저장을 읽는다
func on_waypoint(w: Dictionary) -> void:
	if runner != null: runner.log_line("waypoint", w)
	if onboard != null: onboard.on_waypoint_set(w)
	if case_fn != null and case_fn.has_method("on_waypoint"): case_fn.on_waypoint(w)

func journal_data() -> Dictionary:
	return load("res://scripts/story/journal_book.gd").build(self)

func on_story_idle() -> void:
	_dirty = true
	if _cut: cutscene(false)
	S.time = main.hour
	save()

func on_event(id: String, ev: Dictionary) -> void:
	if log_story: printerr("EVENT %s 「%s」 %s" % [id, ev.get("RECORD_TITLE", ""), ev.get("TRIGGER", "")])

func on_phase() -> void:
	if S.phase == "done": _skills_msgs.append_array(_case_complete())
	for id in actors:
		var a: Dictionary = actors[id]
		if not a.scripted: _place_home(a)
	_dirty = true

func mark_dirty() -> void: _dirty = true

func save() -> void:
	if not _cut: cut_fog_end()   # 컷 밖 저장: 컷 안개를 남기지 않는다(날씨는 저장 파일에 없다 — 컷 도중 저장해도 불러오면 원래 안개. 끝내기는 _exit_tree)
	if S == null or (test != null and not main.args.has("storysave")): return
	S.save()
	_save_where(INF)

# 이어 하기 자리(progress.gd where): 어느 공간 어디에 있었나 — 10초마다·저장할 때
func _save_where(dt: float) -> void:
	_where_t -= dt
	if _where_t > 0.0 or test != null or passive or main._loading: return
	_where_t = 10.0
	var w = main.world
	var wp: Vector2 = main.where_outside() if main.has_method("where_outside") else Vector2(main.player_pos.x, main.player_pos.z)   # 실내 공간 안이면 그 입구 밖
	Progress.set_where({ space = space_id, kind = "route" if w.is_route else "region", x = snappedf(wp.x, 0.1),
		z = snappedf(wp.y, 0.1), hour = snappedf(main.hour, 0.1) })

# 시작 메뉴(새 게임 / 이어 하기): 그냥 실행했을 때만(시험·넘어온 장면·--newgame·--continue·--notitle 아님)
func _maybe_title() -> void:
	var args: Dictionary = main.args
	for k in ["storytest", "bench", "tour", "shot", "portaltest", "walkroute", "newgame", "continue", "notitle", "refset", "warp", "talktest"]:
		if args.has(k): return
	if not main._pending.is_empty(): return
	title = load("res://scripts/story/title_menu.gd").new(self)
	add_child(title)

# 시험(--titletest=newcap): 새 게임부터 step초마다 화면을 찍는다 — 오프닝 연속 캡처. 끝나면 게임을 닫는다
func newgame_capture(dir: String, secs: float, step: float, fine_step := 0.0, fine_secs := 0.0) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var t0 := Time.get_ticks_msec()
	printerr("NEWCAP t0_ms=%d" % t0)
	var n := 0
	while float(Time.get_ticks_msec() - t0) / 1000.0 < secs:
		var fine := fine_step > 0.0 and float(Time.get_ticks_msec() - t0) / 1000.0 < fine_secs
		await get_tree().create_timer(fine_step if fine else step).timeout
		var t := float(Time.get_ticks_msec() - t0) / 1000.0
		get_viewport().get_texture().get_image().save_jpg(dir.path_join("%02d_t%05.2f.jpg" % [n, t]), 0.8)
		n += 1
	printerr("NEWCAP %d frames → %s" % [n, dir])
	main._quit()

func outcome_var() -> String:
	return String(data.get("case", {}).get("outcome_var", "CASE_%s_OUTCOME" % case_id.to_upper()))   # 남원은 데이터에 CASE_NAMWON_OUTCOME

func wait(sec: float) -> void:
	if ui.auto and not ui.auto_real: sec = minf(sec, 0.05)
	await get_tree().create_timer(sec, true, false, true).timeout

# ---------------------------------------------------------------------------
# 상태 바꾸기(알림 포함)
# ---------------------------------------------------------------------------
func learn_clue(id: String, quiet := false) -> void:
	if S.has_clue(id): return
	S.clues.append(id)
	runner.log_line("clue", id)
	var c: Dictionary = data.get("clues", {}).get(id, {})
	if not quiet and not c.is_empty(): ui.toast("단서 — " + String(c.title), "clue")
	_dirty = true
	if case_fn.has_method("on_clue"): case_fn.on_clue(id)

func learn_rule(id: String, quiet := false) -> void:
	if S.knows(id): return
	S.rules.append(id)
	runner.log_line("rule", id)
	var c: Dictionary = data.get("rules", {}).get(id, {})
	if not quiet and not c.is_empty(): ui.toast("%s — %s" % [String(data.get("case", {}).get("rule_label", "범의 버릇")), String(c.title)], "rule")
	_dirty = true

func item_label(id: String) -> String:
	return String(data.get("items", {}).get(id, id))

func give(id: String, nn := 1, quiet := false) -> void:
	S.items[id] = S.count(id) + nn
	runner.log_line("give", [id, nn])
	if not quiet: ui.toast(("%s %d개를 얻었다" % [item_label(id), nn]) if nn > 1 else ("%s을(를) 얻었다" % item_label(id)), "item")
	_sync_items()
	_dirty = true

func take(id: String, nn := 1) -> void:
	S.items[id] = maxi(0, S.count(id) - nn)
	if S.items[id] == 0: S.items.erase(id)
	runner.log_line("take", [id, nn])
	_sync_items()
	_dirty = true

func _sync_items() -> void:
	var list := []
	var hidden: Array = data.get("hidden_items", [])
	for id in S.items:
		if S.items[id] > 0 and not hidden.has(id): list.append({ label = item_label(id), count = S.items[id] })
	ui.items(list)

func journal_note(t: String) -> void:
	S.notes.append(t)
	ui.toast("기록 — " + t, "journal")

func world_state(k: String, v) -> void:
	S.world[k] = v
	runner.log_line("world", [k, v])
	_dirty = true

func set_hour(h: float) -> void:
	main.hour = fposmod(h, 24.0)
	main._apply_time()
	S.time = main.hour

func set_weather(k: String) -> void:
	var wthr = main.weather
	if wthr == null: return
	if k == "" or k == "release":
		if wthr.has_method("release"): wthr.release(2.0)
	elif wthr.has_method("force"): wthr.force(k, -1.0, 0.0)
	else: wthr.forced = k; wthr.kind = k

func cutscene(on: bool) -> void:
	_cut = on
	ui.letterbox(on)
	if not on: cut_fog_end()   # 컷이 어떻게 끝나든(건너뛰기 포함) 컷 안개는 원래대로

# 컷 동안만 안개를 옅게(남원 아침과 같은 weather.force + fogm). 지금 날씨 종류는 그대로 두고 안개 배율만 덮는다.
# 원래 날씨·안개는 cut_fog_end()에서 그대로(전환 없이) 돌아온다 — cutscene(false) · 공간을 떠날 때 · 저장 · 장면을 내릴 때(끝내기·불러오기)
var _cut_wx := {}
var cut_fog_from := {}   # 시험: 마지막 컷 안개가 담아 둔 원래 날씨
func cut_fog(fogm: float) -> void:
	var w = main.weather
	if w == null or not w.has_method("snapshot"): return
	if _cut_wx.is_empty(): _cut_wx = w.snapshot(); cut_fog_from = _cut_wx
	var k: String = w.script_kind if w.script_kind != "" else w.kind
	w.force(k, -1.0, 0.0, { "fogm": fogm })
	if main.has_method("_apply_atmo"): main._apply_atmo()

func cut_fog_end() -> void:
	if _cut_wx.is_empty(): return
	var w = main.weather
	if w != null and is_instance_valid(w):
		w.restore(_cut_wx)
		if main.has_method("_apply_atmo") and w.is_inside_tree(): main._apply_atmo()
	_cut_wx = {}

func cut_fog_on() -> bool:
	return not _cut_wx.is_empty()

func _exit_tree() -> void:
	cut_fog_end()
	for id in _excl_on.keys(): ambient_release(id)

# 소리(scripts/audio/sound.gd): 연출이 소리 낼 순간마다 부른다. sfx_cue 신호도 그대로 낸다(다른 것이 붙어 들을 수 있게).
#   sfx(id) — 자리 없이 · sfx(id, at) — at: 자리 이름(anchors·인물 id·"player") · Vector2(x,z) · Vector3 → 그 자리에서 3D로
#   남원: knock · footstep_heavy · flour_rustle · basket_roll · tiger_growl · axe_hit · rope_creak · rope_snap · fall_impact · wind · breath_gasp · brush_rustle
#   bgm(id, 페이드) — ""이면 멈춤 · duck(db, 초) 잠시 음악 낮춤 · hush(초) 갑자기 고요(음악·환경음)
#   명령으로도: { "sfx": id, "at": 자리 } · { "bgm": id, "fade": 초 } · { "duck": db, "sec": 초 } · { "hush": 초 }(story_runner)
signal sfx_cue(id: String)
func sfx(id: String, at = null) -> void:
	sfx_cue.emit(id)
	if at == null: Sound.play(id)
	else: Sound.play_at(id, audio_pos(at), main.scene_vp)

func audio_pos(at) -> Vector3:
	if at is Vector3: return at
	var p := anchor(at)
	return Vector3(p.x, world.height_at(p.x, p.y) + 1.0, p.y)

func bgm(id: String, fade := 1.5) -> void:
	Sound.music(id, fade)

func duck(db := -10.0, sec := 1.5) -> void:
	Sound.duck(db, sec)

func hush(sec := 1.5, sfx_too := false) -> void:
	Sound.hush(sec, 0.12, 1.2, sfx_too)

# 화면 흔들림 설정(놀이 설정 cam_shake)이 꺼져 있나 — 꺼져 있으면 큰 충격은 암전으로 대신한다
func shake_enabled() -> bool:
	return load("res://scripts/story/game_settings.gd").get_v("cam_shake") != "off"

func shake(p: float, sec: float) -> void:
	if combat_view != null: combat_view.shake(p, sec * 1000.0)

# 카메라 값. talk(대화 구도 — _talk_camera·talk_camera_base) · lead(추격 앞보기 — chase.gd) 표시가 붙은 값은 저작 컷이 아니다:
#   1인칭(main.fp_active)에서는 넣지 않고 시선만 대화 쪽으로 돌린다(C68). 다른 값(사건 d.camera)은 1인칭에서도 저작대로 — region_main이 컷으로 보여 준다.
func camera(spec) -> void:
	var rig = main.rig
	if spec == null or (spec is Dictionary and spec.is_empty()):
		rig.override = null; rig.focus = null; rig.talk_o = null; rig.talk_f = null; rig.talk_yaw = null; return
	var soft := bool(spec.get("talk", false)) or bool(spec.get("lead", false))
	if not bool(spec.get("talk", false)): rig.talk_yaw = null   # 저작 연출·추격 앞보기는 대화 옆 돌기를 쓰지 않는다
	if soft and bool(main.get("fp_active")):
		if bool(spec.get("talk", false)) and spec.get("focus") != null:
			var fp := anchor(spec.focus)
			main.fp_look_at(Vector3(fp.x, world.height_at(fp.x, fp.y) + 1.45, fp.y))
		rig.override = null; rig.focus = null; rig.talk_o = null; rig.talk_f = null
		return
	if spec.has("focus"):
		if spec.focus == null: main.rig.focus = null
		else:
			var p := anchor(spec.focus)
			main.rig.focus = { x = p.x, z = p.y }
	var o := {}
	for kk in ["pitch", "distance", "fov"]:
		if spec.has(kk): o[kk] = float(spec[kk])
	main.rig.override = o if not o.is_empty() else null
	rig.talk_o = rig.override if soft else null
	rig.talk_f = rig.focus if soft else null

# ---------------------------------------------------------------------------
# 자리
# ---------------------------------------------------------------------------
func anchor(at) -> Vector2:
	if at is Vector2: return at
	if at is Array and at.size() >= 2: return Vector2(float(at[0]), float(at[1]))
	if at is Dictionary:
		if at.has("x"): return Vector2(float(at.x), float(at.z))
		return anchor(at.get(S.phase, at.get("default", [0, 0])))
	var s := String(at)
	if s == "player": return Vector2(main.player_pos.x, main.player_pos.z)
	if actors.has(s): return Vector2(actors[s].pos.x, actors[s].pos.z)
	var an: Dictionary = data.get("anchors", {})
	if an.has(s): return anchor(an[s])
	push_warning("이야기: 모르는 자리 " + s)
	return Vector2(main.player_pos.x, main.player_pos.z)

func teleport_to(at, face := "") -> void:
	var p := anchor(at)
	main.teleport(p.x, p.y)
	if face != "": main.player.facing = face
	if face != "" and bool(main.get("fp_active")): main.fp_face_dir(face)   # 1인칭: 순간이동은 컷 — 바라보는 쪽도 바로
	main.rig.update(0, main.player_pos, main.player.facing, null, true)

func arena(id: String) -> Dictionary:
	var a: Dictionary = data.get("arenas", {}).get(id, {}).duplicate(true)
	if a.is_empty(): return {}
	var c := anchor(a.get("at", [0, 0]))
	a.id = id; a.x = c.x; a.z = c.y
	if a.has("player_start"): a.player_start = anchor(a.player_start)
	if a.has("tiger_start"): a.tiger_start = anchor(a.tiger_start)
	if a.has("tiger_offset"): a.tiger_start = c + anchor(a.tiger_offset)   # 플레이어 자리 기준 싸움터(첫 조우)
	return a

# ---------------------------------------------------------------------------
# 인물
# ---------------------------------------------------------------------------
func _ensure_bank(kind: String) -> String:
	if SpriteChar._banks.has(kind): return kind
	if _bank_src.is_empty():
		for jf in BANK_FILES:
			var path: String = "res://data/" + jf
			if not FileAccess.file_exists(path): continue
			var all = JSON.parse_string(FileAccess.get_file_as_string(path))
			if all is Dictionary:
				for k in all:
					if not _bank_src.has(k): _bank_src[k] = all[k]
	if _bank_src.has(kind):
		var pages := []
		for p in _bank_src[kind].pages:
			var img := Image.load_from_file(ProjectSettings.globalize_path("res://data/" + p))
			if img == null or img.is_empty(): continue
			img.generate_mipmaps()
			pages.append(ImageTexture.create_from_image(img))
		SpriteChar._banks[kind] = { pages = pages, clips = _bank_src[kind].clips }
		return kind
	if preload("res://scripts/char_bank.gd").ensure(kind): return kind   # 인물 빌더 인물(data/chars/*.json — 프리셋 p_jumo 등, 권역 사람 id)
	if KIND_FALLBACK.has(kind): return _ensure_bank(KIND_FALLBACK[kind])
	return "villager_m" if kind != "villager_m" else ""

func _make_actor(spec: Dictionary) -> Dictionary:
	var kind := _ensure_bank(String(spec.get("kind", "villager_m")))
	var ch := SpriteChar.new(kind)
	main.scene_vp.add_child(ch)
	ch.set_silhouette(false)
	ch._sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	if spec.has("variant"): ch.variant = String(spec.variant)
	if GENERIC_KINDS.has(kind) and spec.get("accent", true) != false: ch.set_accent(ACCENT)   # 고을 사람과 같은 그림이면 테두리 빛
	var a := { id = String(spec.id), spec = spec, ch = ch, pos = Vector3.ZERO, facing = "down", scripted = false,
		shown = false, path = [], speed = 1.6, end_anim = "idle", y_abs = NAN, name = String(spec.get("name", "")), anim = "idle" }
	actors[a.id] = a
	_place_home(a)
	ch.visible = false
	return a

func _place_home(a: Dictionary) -> void:
	var at = a.spec.get("at")
	if at == null: return
	# 제자리는 이름 붙은 자리(anchors)를 먼저 본다 — 자리 이름이 인물 id와 같으면(주모 "jumo" 등) anchor()가 인물 자신의
	# 아직 안 정한 자리(0,0)를 돌려줘 세상 한가운데에 서 버렸다
	if at is Dictionary and not at.has("x"): at = at.get(S.phase, at.get("default", [0, 0]))
	if at is String and data.get("anchors", {}).has(at): at = data.anchors[at]
	var p := anchor(at)
	a.pos = Vector3(p.x, world.height_at(p.x, p.y), p.y)
	a.y_abs = NAN
	var fc = a.spec.get("facing", "down")
	if fc is Dictionary: fc = fc.get(S.phase, fc.get("default", "down"))
	a.facing = String(fc)
	var an = a.spec.get("anim", "idle")
	if an is Dictionary: an = an.get(S.phase, an.get("default", "idle"))
	a.anim = String(an)
	a.ch.play(a.anim, true)

func actor(id: String):
	return actors.get(id)

func spawn_actor(id: String, kind: String, at, facing: String, nm: String, variant: String) -> void:
	if actors.has(id): despawn_actor(id)
	var a := _make_actor({ id = id, kind = kind, at = at if at != null else "player", facing = facing, name = nm, variant = variant, spawned = true })
	a.scripted = true
	a.shown = true
	a.ch.visible = true
	_dirty = true

func despawn_actor(id: String) -> void:
	var a = actors.get(id)
	if a == null: return
	if a.spec.get("spawned", false):
		a.ch.queue_free(); actors.erase(id)
	else:
		a.scripted = true; a.shown = false; a.ch.visible = false; a.spec["_hidden"] = true
	_dirty = true

func show_actor(id: String, on: bool) -> void:
	var a = actors.get(id)
	if a == null: return
	a.spec.erase("_hidden")
	if not on: a.spec["_hidden"] = true
	a.scripted = true
	_dirty = true

func place_actor(id: String, at, y = null, facing := "") -> void:
	var a = actors.get(id)
	if a == null: return
	a.scripted = true
	a.spec.erase("_hidden")
	if at is String and at == "home":
		a.scripted = false; _place_home(a); _dirty = true; return
	var p := anchor(at)
	a.pos = Vector3(p.x, world.height_at(p.x, p.y), p.y)
	a.y_abs = (a.pos.y + float(y)) if y != null else NAN
	a.path = []
	if facing != "": a.facing = facing
	_dirty = true

func face_actor(id: String, dir, to, side_k := 1.05) -> void:
	var a = actors.get(id) if id != "player" else null
	var d := String(dir) if dir != null else ""
	if to != null:
		var p := anchor(to)
		var from := Vector2(main.player_pos.x, main.player_pos.z) if id == "player" else Vector2(a.pos.x, a.pos.z)
		d = dir_of(p - from, side_k)
	if d == "": return
	if id == "player":
		main.player.facing = d
		if to != null and bool(main.get("fp_active")): main.fp_look_at(fp_head(to))   # 1인칭: 플레이어가 돌아보는 쪽으로 시선을 천천히
	elif a != null: a.facing = d

# 바라보는 쪽 이름(그림 front/back/side): 카메라 yaw(대화 옆 돌기면 그 목표 yaw) 기준 — yaw 0이면 예전과 같다(남→북 고정)
#   side_k: 옆모습으로 치는 문턱(|x| > |z|·k). 대화 마주보기는 0.7 — 비스듬히 마주 서도 서로 옆모습으로 본다
func dir_of(v: Vector2, side_k := 1.05) -> String:
	var rig = main.rig
	var y: float = float(rig.talk_yaw) if rig.talk_yaw != null else float(rig.yaw)
	if absf(y) > 0.01: v = v.rotated(y)
	return "right" if absf(v.x) > absf(v.y) * side_k and v.x > 0 else ("left" if absf(v.x) > absf(v.y) * side_k else ("down" if v.y > 0 else "up"))

# 1인칭 시선 겨냥점: 이야기 인물이면 머리(발 + 1.45m), 자리면 그 땅 위 1.45m(사람 눈높이 — 고개를 거의 들지 않는다)
func fp_head(at) -> Vector3:
	var s := String(at) if at is String else ""
	if s != "" and actors.has(s):
		var ap: Vector3 = actors[s].pos
		return ap + Vector3(0, 1.45, 0)
	var p := anchor(at)
	return Vector3(p.x, world.height_at(p.x, p.y) + 1.45, p.y)

# 대사 하나가 뜰 때(story_runner say): 1인칭이면 말하는 이야기 인물(이름 또는 id, 14m 안 가장 가까운)을 바라본다 — 나그네(플레이어) 대사는 그대로
func on_say(speaker: String) -> void:
	if onboard != null: onboard.on_line()   # 대화 안내(TALK)는 첫 줄이 보일 때 끝난다
	if not bool(main.get("fp_active")) or speaker == "": return
	var pp := Vector2(main.player_pos.x, main.player_pos.z)
	var best := ""; var bd := 14.0
	for id in actors:
		var a: Dictionary = actors[id]
		if String(id) != speaker and String(a.get("name", "")) != speaker: continue
		if not bool(a.get("shown", true)): continue
		var dd := pp.distance_to(Vector2(a.pos.x, a.pos.z))
		if dd < bd and dd > 0.3: bd = dd; best = String(id)
	if best != "": main.fp_look_at(fp_head(best))

func anim_actor(id: String, nm: String, restart := true) -> void:
	if id == "player":
		main.player.play(nm, restart); return
	var a = actors.get(id)
	if a == null: return
	a.anim = nm
	a.ch.play(nm, restart)

# 자세 바꾸기(제자리, 같은 사람): 출두 반전처럼 서 있던·앉아 있던 이야기 인물을 bow·kneel 등으로.
#   filter: 인물 id 배열 · "ch_saryeong_*" 같은 glob 문자열 · 인물 데이터의 "tags"에 든 이름. 노드(SpriteChar)는 그대로 두고 동작만 바꾼다.
#   돌려주는 값: 바뀐 인물 id 목록(시험이 같은 노드인지 본다). EventCrowd.set_pose와 짝.
func set_pose(filter, pose: String) -> Array:
	var out := []
	for id in actors:
		if not _actor_match(id, actors[id], filter): continue
		var a: Dictionary = actors[id]
		a.anim = pose
		a.end_anim = pose
		a.scripted = true   # 단계가 바뀌어도 제자리 자세(spec.anim)로 되돌리지 않는다
		if a.ch != null: a.ch.play(pose, true)
		out.append(id)
	return out

static func _actor_match(id: String, a: Dictionary, filter) -> bool:
	if filter is Array: return filter.has(id)
	var f := String(filter)
	if f == "" or f == "*": return true
	if id.matchn(f): return true
	return (a.get("spec", {}) as Dictionary).get("tags", []).has(f)

# 경로를 따라 걷게 하고 다 걸으면 돌아온다
func move_actor(id: String, to, speed: float, anim_nm: String, end_anim: String) -> void:
	var a = actors.get(id)
	if a == null: return
	var pts := []
	if to is Array and to.size() > 0 and not (to[0] is float or to[0] is int): pts = to
	else: pts = [to]
	a.scripted = true
	a.path = pts.map(func(q): return anchor(q))
	a.speed = speed if (not ui.auto or ui.auto_real) else speed * 8.0   # 시험은 빨리 — 화면 검토(auto_real)는 실제 걸음
	a.end_anim = end_anim
	a.anim = anim_nm
	a.ch.play(anim_nm)
	var g: int = runner.gen
	var guard := 0
	while not a.path.is_empty() and guard < 2000 and g == runner.gen:
		await get_tree().process_frame
		guard += 1
	if not a.path.is_empty(): a.path = []

func _update_actors(dt: float) -> void:
	var pp: Vector3 = main.player_pos
	for id in actors:
		var a: Dictionary = actors[id]
		var ch: SpriteChar = a.ch
		if not a.path.is_empty():
			var tgt: Vector2 = a.path[0]
			var v := tgt - Vector2(a.pos.x, a.pos.z)
			var l := v.length()
			var step: float = a.speed * dt
			if l <= step:
				a.pos = Vector3(tgt.x, world.height_at(tgt.x, tgt.y), tgt.y)
				a.path.pop_front()
				if a.path.is_empty():
					a.anim = a.end_anim; ch.play(a.end_anim, true)
			else:
				var q := Vector2(a.pos.x, a.pos.z) + v / l * step
				a.pos = Vector3(q.x, world.height_at(q.x, q.y), q.y)
			if l > 0.01:
				a.facing = "right" if absf(v.x) > absf(v.y) * 1.05 and v.x > 0 else ("left" if absf(v.x) > absf(v.y) * 1.05 else ("down" if v.y > 0 else "up"))
		if not a.shown: continue
		var d := Vector2(a.pos.x - pp.x, a.pos.z - pp.z).length()
		var near := d < 140.0
		if ch.visible != near: ch.visible = near
		if not near: continue
		ch.position = Vector3(a.pos.x, a.y_abs if not is_nan(a.y_abs) else world.height_at(a.pos.x, a.pos.z), a.pos.z)
		ch.facing = a.facing
		ch.update_char(dt, main.cam)

# ---------------------------------------------------------------------------
# 조건 다시 보기(인물 보이기·소품)
# ---------------------------------------------------------------------------
func _refresh() -> void:
	_dirty = false
	if main.get("placement") != null: main.placement.gate.mark()   # 배치·군중 when(F-11)도 다시 본다
	for id in actors:
		var a: Dictionary = actors[id]
		var on: bool = not a.spec.get("_hidden", false) and runner.cond(a.spec.get("when", true))
		if a.spec.get("spawned", false): on = not a.spec.get("_hidden", false)
		if on != a.shown:
			a.shown = on
			if not on: a.ch.visible = false
	for p in data.get("props", []):
		var id := String(p.id)
		if not props.has(id): props[id] = { spec = p, node = null, shown = false, decals = [] }
		var rec: Dictionary = props[id]
		rec.want = runner.cond(p.get("when", true))
	for z in data.get("ambient_exclude", []):
		var zid := String(z.id)
		var on: bool = runner.cond(z.get("when", true))
		if on and not _excl_on.has(zid): ambient_exclude(zid, z)
		elif not on and _excl_on.has(zid) and not bool(_excl_on[zid].get("_manual", false)): ambient_release(zid)
	_sync_items()

# ---------------------------------------------------------------------------
# 비우기 구역(제작 규칙 C63) — 사건 행렬·행사가 지나는 길 한가운데에서 고을 사람(npc_ambient)을 잠시 비운다.
#   zone: { path: [자리…], width } · { rect: [x0, z0, x1, z1] } · 자리 배열(꺾인 길 — 폭은 width) · Rect2 · [x0, z0, x1, z1]
#   자리는 앵커 이름·인물 id·[x, z] 모두 된다. 행렬 AI·길찾기·비켜서기는 없다 — 풀면 보통 스트리밍이 다시 채운다.
# ---------------------------------------------------------------------------
func ambient_exclude(id: String, zone, width := 4.0) -> void:
	var z := ambient_zone(zone, width)
	if z.is_empty(): return
	if not (zone is Dictionary and zone.has("id")): z["_manual"] = true   # 코드로 켠 것 — 데이터 when이 끄지 않는다
	_excl_on[id] = z
	var amb = main.get("npcs_amb")
	if amb != null: amb.exclude(id, z)
	if runner != null: runner.log_line("ambient_exclude", [id])

func ambient_release(id: String) -> void:
	if not _excl_on.has(id): return
	_excl_on.erase(id)
	var amb = main.get("npcs_amb")
	if amb != null: amb.release(id)
	if runner != null: runner.log_line("ambient_release", [id])

func ambient_zone(zone, width := 4.0) -> Dictionary:
	if zone is Rect2: return { "rect": [zone.position.x, zone.position.y, zone.end.x, zone.end.y] }
	if zone is Dictionary:
		if zone.has("rect"): return { "rect": zone.rect }
		if zone.has("path"): return { "path": _zone_pts(zone.path), "width": float(zone.get("width", width)) }
		return {}
	if zone is Array:
		if zone.size() == 4 and zone.all(func(q): return q is float or q is int): return { "rect": zone }
		return { "path": _zone_pts(zone), "width": width }
	return {}

func _zone_pts(pts: Array) -> Array:
	var out := []
	for q in pts:
		var v := anchor(q)
		out.append([v.x, v.y])
	return out

func ambient_zones() -> Dictionary: return _excl_on

func _update_props() -> void:
	var pp := Vector2(main.player_pos.x, main.player_pos.z)
	for id in props:
		var rec: Dictionary = props[id]
		var want: bool = rec.get("want", false)
		if want == rec.shown and (rec.node != null or not want or rec.spec.has("decal") or rec.spec.has("trail")): continue
		var p: Dictionary = rec.spec
		var at := anchor(p.get("at", [0, 0])) if p.has("at") else Vector2.ZERO
		if want and p.has("kit") and rec.node == null:
			if p.has("at") and pp.distance_to(at) > 260.0: continue
			rec.node = _build_prop(p, at)
		if p.has("decal") or p.has("trail"): _decal_prop(rec, want, at)
		if rec.node != null: rec.node.visible = want
		_prop_cols(rec, want)
		rec.shown = want

func _build_prop(p: Dictionary, at: Vector2) -> Node3D:
	var path := "res://kit/%s.gd" % String(p.kit)
	if not FileAccess.file_exists(path): push_warning("이야기 소품 키트 없음: " + path); return null
	var info: Dictionary = load(path).build(p.get("params", {}))
	var n: Node3D = info.node
	_props_root.add_child(n)
	var y: float = _prop_ground(at) + float(p.get("dy", 0.0))
	if p.has("y"): y = float(p.y)
	if bool(info.get("block", false)) and not (info.get("colliders", []) as Array).is_empty(): n.set_meta("cols", info.colliders)   # 서안 등(키트 block) — _prop_cols가 보일 때만 세운다
	n.global_transform = Transform3D(Basis(Vector3.UP, float(p.get("ry", 0.0))), Vector3(at.x, y, at.y))
	for l in info.get("lights", []):
		var o := OmniLight3D.new()
		o.light_color = Color("#ff9a4a"); o.omni_range = 7.0; o.light_energy = 3.0; o.shadow_enabled = false
		o.position = Vector3(l.x, l.y, l.z)
		n.add_child(o)
	return n

# 소품 dy의 바닥: 건물 걷기 면(기단·마루·방바닥)을 뺀 높이 — dy는 땅(터 고르기 뒤) 기준으로 맞춰 왔다(방 안 서안 dy 0.4 = 기단 F)
func _prop_ground(at: Vector2) -> float:
	return world.height_base_at(at.x, at.y) if world.has_method("height_base_at") else world.height_at(at.x, at.y)

# 이야기 소품의 충돌체(키트 colliders): 보이는 동안만 world 동적 충돌체로 — 서안·소반을 뚫고 걷지 않게
func _prop_cols(rec: Dictionary, on: bool) -> void:
	if not world.has_method("add_dynamic_collider"): return
	var have: Array = rec.get("cols", [])
	if on and have.is_empty() and rec.node != null and is_instance_valid(rec.node) and rec.node.has_meta("cols"):
		for c in rec.node.get_meta("cols"): have.append(world.add_dynamic_collider(c, rec.node.global_transform))
		rec.cols = have
	elif not on and not have.is_empty():
		for wc in have: world.remove_dynamic_collider(wc)
		rec.cols = []

# 데칼(world.decals — 사건용 세계 API가 있으면). 없으면 그냥 건너뛴다(키트 소품에 작은 모양이 따로 있다)
func _decal_prop(rec: Dictionary, want: bool, at: Vector2) -> void:
	var dc = world.get("decals")
	if dc == null: return
	if not want:
		for i in rec.decals: dc.remove(i)
		rec.decals = []
		return
	if not rec.decals.is_empty(): return
	var p: Dictionary = rec.spec
	if p.has("decal"):
		var sp: Dictionary = p.decal.duplicate()
		sp.id = "story_" + String(p.id); sp.x = at.x; sp.z = at.y; sp.group = "story"
		if sp.has("dy"):
			sp.y = _prop_ground(at) + float(sp.dy); sp.erase("dy")
		rec.decals = [dc.add(sp)]
	else:
		var tr: Dictionary = p.trail
		var pts := []
		for q in tr.points:
			var v := anchor(q)
			pts.append([v.x, v.y])
		var opts := tr.duplicate(); opts.erase("points"); opts.erase("kind"); opts.group = "story"
		rec.decals = dc.trail("story_" + String(p.id), String(tr.kind), pts, opts)

func _apply_world() -> void:
	if _keep_hour:   # 같은 공간에서 사건만 바꿨다(switch_case) — 세상 시각은 그대로 이어 간다(저장된 그 사건의 옛 시각으로 되돌리지 않는다)
		_keep_hour = false
		S.time = main.hour
		set_hour(main.hour)
	else:
		set_hour(S.time if S.phase != "start" else float(data.get("case", {}).get("start_hour", 10.0)))
	if case_fn.has_method("on_load"): case_fn.on_load()
	if S.phase == "done": _case_complete()   # 이 체계 전에 끝낸 저장도 해금(조용히)
	_dirty = true

# ---------------------------------------------------------------------------
# 조사·대화·자리 트리거
# ---------------------------------------------------------------------------
func _targets() -> Array:
	var out := []
	for id in actors:
		var a: Dictionary = actors[id]
		if not a.shown or not a.ch.visible or a.spec.get("talk") == null: continue
		var talk: Array = a.spec.talk
		var any := false
		for t in talk:
			if runner.cond(t.get("when", true)): any = true; break
		if not any: continue
		out.append({ id = id, kind = "actor", p = Vector2(a.pos.x, a.pos.z), r = float(a.spec.get("radius", 2.2)),
			label = "%s · %s" % [a.name, a.spec.get("verb", "대화")] })
	for o in data.get("objects", []):
		if not runner.cond(o.get("when", true)): continue
		var lab = o.get("label", "")
		if o.has("label_if") and runner.cond(o.label_if[0]): lab = o.label_if[1]
		out.append({ id = String(o.id), kind = "object", p = anchor(o.at), r = float(o.get("radius", 2.0)), label = String(lab), spec = o })
	return out

# 1인칭(region_main.fp_active)이면 닿는 거리(r) 안에서 바라보는 쪽에 있는 것을 먼저: 거리 × (1.6 − 0.6·cos(시선과 이루는 각))
#   — 바로 앞은 거리 그대로, 옆은 1.6배, 뒤는 2.2배로 친다. 닿는 거리·우선순위(C01: 이야기 대상 → 곁 사람)는 그대로.
func _look_score(pp: Vector2, p: Vector2) -> float:
	var d := pp.distance_to(p)
	if not bool(main.get("fp_active")) or d < 0.05: return d
	var c: float = (main.fp_look_dir() as Vector2).dot((p - pp) / d)
	return d * (1.6 - 0.6 * c)

func _update_target() -> void:
	var pp := Vector2(main.player_pos.x, main.player_pos.z)
	var best = null; var bd := INF
	if case_id != "" and _started:
		for t in _targets():
			var d: float = pp.distance_to(t.p)
			var sc := _look_score(pp, t.p)
			if d < t.r and sc < bd: bd = sc; best = t
	# 이야기 대상이 먼저. 없으면 고을 사람·역참 마부·길목 깃발 가운데 가장 가까운 것(넓은 구역이 곁 사람 E를 가로채지 않게)
	if best == null:
		var cands := []
		if ambient != null: cands.append(ambient.target(pp))
		if keeper != null: cands.append(keeper.target(pp))
		for c in cands:
			if c == null: continue
			var dc: float = _look_score(pp, c.p)
			if dc < bd: bd = dc; best = c
	_target = best
	ui.prompt(best.label if best != null else "")

func interact(id: String) -> void:
	if runner.busy or talking: return
	talking = true
	var steps := []
	if actors.has(id):
		var a: Dictionary = actors[id]
		_talk_seen_now(a)
		S.talked[id] = int(S.talked.get(id, 0)) + 1
		for t in a.spec.get("talk", []):
			if runner.cond(t.get("when", true)):
				steps = t.get("steps", []); break
	else:
		for o in data.get("objects", []):
			if String(o.id) == id:
				if not runner.cond(o.get("when", true)): talking = false; return
				steps = o.get("steps", [])
				if bool(main.get("fp_active")):   # 1인칭 살펴보기: 물건 쪽(땅 위 0.6m)으로 고개를 숙여 본다
					var op := anchor(o.at)
					main.fp_look_at(Vector3(op.x, world.height_at(op.x, op.y) + float(o.get("look_y", 0.6)), op.y))
				break
	runner.log_line("interact", id)
	if onboard != null: onboard.on_interact("actor" if actors.has(id) else "object")
	_target = null
	ui.prompt("")
	var tc = CameraRig.talk_spec(data.get("case", {}), actors[id].spec) if actors.has(id) else null
	var cam_on: bool = tc is Dictionary and not steps.is_empty()
	if actors.has(id): _talk_approach(id, tc if cam_on else null, not steps.is_empty())
	await runner.run(steps)
	if cam_on and not talk_cam.is_empty(): _talk_camera_end()
	_talk_occ_end()
	_plain_turn_end()
	talking = false
	if onboard != null: onboard._pend_t = 0.0   # 「…」 바로 다시 본다

# 말 걸기 접근(재기획 2단계 — 대화 카메라 v1.1 §5·§6, D5·D9): 3인칭이면 구도를 한 번 계산해(talk_frame.gd)
#   ① 플레이어가 겹치면 상대 곁으로 한 걸음 ② 이야기 인물이면 카메라 옆 돌기·거리(0.55초 미끄러짐) ③ 두 사람 둘레 가림 점무늬
#   ④ 플레이어는 상대를, 상대는 0.2초 늦게 플레이어를 본다. 1인칭(C68)은 예전 그대로(돌아보기, 대화 구도 없음).
func _talk_approach(id: String, tc, has_steps: bool) -> void:
	var a: Dictionary = actors[id]
	if bool(main.get("fp_active")) or not has_steps:
		face_actor(id, null, "player")
		face_actor("player", null, id)
		if tc != null: _talk_camera(id, tc)
		return
	if _tf == null: _tf = TalkFrame.new(self)
	var nh: float = float(a.ch.height) if a.ch != null else 2.0
	var pl: Dictionary = _tf.plan(a.pos, nh, tc != null, tc if tc != null else {}, true)
	last_frame = pl.duplicate(); last_frame.id = id
	_log_frame(id, pl)
	if tc != null: _talk_camera(id, tc, pl)
	else: _plain_turn_begin(pl)   # 대화 카메라를 끈 인물(talk_camera false): 겹침을 못 풀 때만 옆 돌기
	var stand_p: Vector2 = pl.stand if pl.stand != null else Vector2(main.player_pos.x, main.player_pos.z)
	_talk_occ_begin(Vector3(stand_p.x, world.height_at(stand_p.x, stand_p.y), stand_p.y), float(main.player.height), a.pos, nh)
	# 장면(대본)은 곧바로 시작한다 — 카메라 미끄러짐(0.55초)·한 걸음·상대 돌아봄은 첫 대사와 함께 흐른다(대본이 늦게 서면 사건 흐름·시험이 어긋난다).
	#   첫 상자는 0.18초에 걸쳐 흐려지며 들어오므로 구도가 서는 동안 갑자기 덮지 않는다.
	if pl.stand == null: face_actor("player", null, id, 0.7)
	_approach_tail(id, pl)

# 접근 뒷부분(기다리지 않는다): 한 걸음 → 상대를 봄, 0.2초 뒤 상대가 플레이어를 봄
#   대본이 그사이 누구를 돌려 세우면(face 단계) 그것이 이긴다 — 내가 본 뒤로 바뀌지 않았을 때만 돌린다
func _approach_tail(id: String, pl: Dictionary) -> void:
	var t0 := Time.get_ticks_msec()
	var npc_f0: String = String(actors[id].facing)
	if pl.stand != null:
		var ok := await _step_player(pl.stand, clampf(float(pl.move) / TalkFrame.WALK_SPEED, 0.2, 0.6))
		if ok and actors.has(id) and main.player.facing == _step_face: face_actor("player", null, id, 0.7)
	var el := (Time.get_ticks_msec() - t0) / 1000.0
	if el < NPC_TURN_DELAY: await wait(NPC_TURN_DELAY - el)
	if actors.has(id) and not _cut and String(actors[id].facing) == npc_f0: face_actor(id, null, "player", 0.7)

# 고을 사람·역참 마부 말 걸기(D5·C27 — 카메라는 평소 그대로가 먼저): 겹치면 한 걸음, 두 사람 둘레 가림 점무늬.
#   한 걸음으로도 겹침을 못 풀 때만(좁은 장터 가게 앞 등) 카메라를 옆으로 돌린다(D5 '인물 가림은 절대 없게', D9 첫 수단) — 0.55초, 끝나면 0.45초 복귀.
#   돌려줌: 구도(talk_frame.plan) — 부른 쪽이 상대를 플레이어 쪽으로 돌릴 때 face_toward_player()로 쓴다. 끝나면 talk_plain_end()
func talk_plain_begin(p: Vector2, h := 2.0) -> Dictionary:
	talking = true
	if bool(main.get("fp_active")):
		face_actor("player", null, p); return {}
	if _tf == null: _tf = TalkFrame.new(self)
	var npc := Vector3(p.x, world.height_at(p.x, p.y), p.y)
	var pl: Dictionary = _tf.plan(npc, h, false, {}, true)
	last_frame = pl.duplicate(); last_frame.id = "plain"
	_log_frame("plain", pl)
	var t0 := Time.get_ticks_msec()
	_plain_turn_begin(pl)
	var stand_p: Vector2 = pl.stand if pl.stand != null else Vector2(main.player_pos.x, main.player_pos.z)
	_talk_occ_begin(Vector3(stand_p.x, world.height_at(stand_p.x, stand_p.y), stand_p.y), float(main.player.height), npc, h)
	if pl.stand != null: await _step_player(pl.stand, clampf(float(pl.move) / TalkFrame.WALK_SPEED, 0.2, 0.6))
	face_actor("player", null, p, 0.7)
	var el := (Time.get_ticks_msec() - t0) / 1000.0
	if _plain_turned and el < TALK_IN: await wait(TALK_IN - el)
	return pl

func talk_plain_end() -> void:
	_talk_occ_end()
	_plain_turn_end()
	talking = false

func _plain_turn_begin(pl: Dictionary) -> void:
	_plain_turned = bool(pl.get("turned", false)) and main.rig.shot == null
	if _plain_turned:
		main.rig.talk_yaw = float(pl.yaw)
		main.rig.glide(TALK_IN, null, true)

func _plain_turn_end() -> void:
	if not _plain_turned: return
	_plain_turned = false
	main.rig.talk_yaw = null
	if not bool(main.get("fp_active")) and main.rig.shot == null and not main.rig.gliding():
		main.rig.glide(TALK_OUT, null, true)

# 상대(고을 사람·마부)가 플레이어를 볼 때의 그림 쪽 — 대화 옆 돌기 yaw 기준(돌지 않았으면 예전과 같다)
func face_toward_player(from: Vector2) -> String:
	return dir_of(Vector2(main.player_pos.x, main.player_pos.z) - from, 0.7)

func _log_frame(id: String, pl: Dictionary) -> void:
	if not (log_story or main.args.has("talkshot") or main.args.has("talktest") or main.args.has("viewtest")): return
	print("TALKFRAME id=%s phase=%s yaw=%.0f dist=%.1f move=%.2f stand=%s overlap=%.2f raw=%.2f occ_npc=%d occ_player=%d cands=%d ms=%.1f rel=%s rej=%s" % [id, pl.phase,
		rad_to_deg(float(pl.yaw)), float(pl.distance), float(pl.move), pl.stand, float(pl.overlap), float(pl.get("overlap_raw", 0.0)), int(pl.occ_npc), int(pl.occ_player), int(pl.n), float(pl.get("ms", 0.0)), pl.get("rel", Vector2.ZERO), pl.get("rej", {})])

# 플레이어 한 걸음(걷기 그림, 직선 — talk_frame이 막힘 없는 길만 고른다). 시험 자동 진행은 바로 옮긴다
# 돌려줌: 끝까지 걸었나(사건 연출이 그사이 플레이어를 옮기면 그만둔다 — false)
func _step_player(to: Vector2, dur: float) -> bool:
	var from := Vector2(main.player_pos.x, main.player_pos.z)
	if ui.auto and not ui.auto_real:
		set_player_pos(Vector3(to.x, world.height_at(to.x, to.y), to.y)); _step_face = main.player.facing; return true
	_stepping = true
	main.player.facing = dir_of(to - from)
	_step_face = main.player.facing
	main.player.set_anim("walk")
	var t := 0.0
	var last := from
	var ok := true
	while t < dur:
		await get_tree().process_frame
		if not is_inside_tree(): return false
		if Vector2(main.player_pos.x, main.player_pos.z).distance_to(last) > 0.05: ok = false; break   # 누가 옮겼다
		t += get_process_delta_time()
		var q := from.lerp(to, smoothstep(0.0, 1.0, clampf(t / dur, 0.0, 1.0)))
		set_player_pos(Vector3(q.x, world.height_at(q.x, q.y), q.y))
		last = q
	if main.player.anim == "walk": main.player.set_anim("idle")
	_stepping = false
	return ok

func _talk_occ_begin(pp: Vector3, ph: float, npc: Vector3, nh: float) -> void:
	if main.occ_script != null: return   # 사건이 건 각본 가림이 먼저
	_talk_occ = TalkFrame.occ_spec(pp, ph, npc, nh)
	main.set_occ_script(_talk_occ)

func _talk_occ_end() -> void:
	if _talk_occ != null and is_same(main.occ_script, _talk_occ): main.set_occ_script(null)
	_talk_occ = null

# 이야기 인물 대화 카메라(공통 — 제작 규칙 v1.0 결정 4, 남원 v3.2 §8 CAMERA 1A에서 승격): 이야기 인물에게 직접 말을 걸 때만
#   (고을 사람·마부·깃발은 이 길을 지나지 않는다). 값은 CameraRig.talk_spec: 공통 TALK 38/13.5/38 → case.talk_camera → actor.talk_camera,
#   false면 평소 카메라. 플레이어와 인물 사이를 겨냥하고 대화 동안 음악을 조금 낮춘다.
#   대화 안에서 연출이 카메라를 바꾸면(컷신) 그쪽이 이긴다 — 끝날 때 평소 시점으로
func _talk_camera(id: String, tc: Dictionary, pl := {}) -> void:
	var a: Dictionary = actors[id]
	var mid := (Vector2(main.player_pos.x, main.player_pos.z) + Vector2(a.pos.x, a.pos.z)) * 0.5
	if pl.has("focus"): mid = pl.focus
	talk_cam = tc.duplicate()
	talk_cam.focus = [mid.x, mid.y]
	talk_cam.talk = true
	if pl.has("distance"): talk_cam.distance = float(pl.distance)
	camera(talk_cam)
	if not pl.is_empty() and not bool(main.get("fp_active")):
		main.rig.talk_yaw = float(pl.yaw)
		main.rig.glide(TALK_IN, null, true)   # 0.55초 smoothstep — 겨냥점·pitch·거리·fov·yaw를 함께
	Sound.music_level(0.5, 0.6)

# 사건 단위 대화 카메라 값(인물 덮어쓰기 없이) — 사건 연출이 대화 구도를 다시 쓸 때(남원 마부·아이들·포수·이웃 아낙·노인). 꺼졌으면 {}
func talk_camera_base() -> Dictionary:
	var tc = CameraRig.talk_spec(data.get("case", {}))
	if tc is Dictionary: tc.talk = true   # 대화 구도 표시(1인칭은 쓰지 않는다 — camera())
	return tc if tc is Dictionary else {}

func _talk_camera_end() -> void:
	talk_cam = {}
	var turned: bool = main.rig.talk_yaw != null or absf(float(main.rig.yaw)) > 0.001
	camera(null)
	# 평소 시점으로 0.45초(대화 v1.1 §4) — 평소 시점은 플레이어 자리·구역으로 정해지므로 그것이 곧 '이전 시점'이다.
	#   사건 연출이 미끄러짐·각본 시점을 쥐고 있으면 그쪽에 맡긴다
	if not bool(main.get("fp_active")) and main.rig.shot == null and not main.rig.gliding():
		main.rig.glide(TALK_OUT, null, turned)
	Sound.music_level(1.0, 1.0)

func _check_triggers() -> void:
	var pp := Vector2(main.player_pos.x, main.player_pos.z)
	for t in data.get("triggers", []):
		var id := String(t.id)
		if t.get("once", true) and S.flags.has("_trig_" + id): continue
		if t.has("at") and pp.distance_to(anchor(t.at)) > float(t.get("radius", 8.0)): continue
		if not runner.cond(t.get("when", true)): continue
		if t.get("once", true): S.flags["_trig_" + id] = true
		runner.log_line("trigger", id)
		if t.has("ambient"):
			_overhear(t.ambient)   # 지나가며 엿듣는 주변대화 — 조작을 막지 않는다
			return
		var steps: Array = t.get("steps", [])
		if t.has("event"): steps = [{ "event": t.event }]
		runner.run(steps)
		return

# ---------------------------------------------------------------------------
# 전투·결말
# ---------------------------------------------------------------------------
func combat(arena_id: String, st: Dictionary) -> String:
	var a := arena(arena_id)
	if a.is_empty():
		push_warning("이야기: 없는 싸움터 " + arena_id); return "win"
	var opts := { mods = st.get("mods", {}).duplicate(), allow_flee = st.get("allow_flee", true), place_player = st.get("place_player", false) }
	if case_fn.has_method("combat_mods"): opts.mods = case_fn.combat_mods(arena_id, opts.mods)
	if st.has("retreat_at"): opts.retreat_at = st.retreat_at
	if a.has("focus"): opts.focus = anchor(a.focus)
	if a.has("retreat_to"): opts.retreat_to = anchor(a.retreat_to)
	if st.has("seed"): opts.seed = st.seed
	elif test != null: opts.seed = int(main.args.get("combatseed", "1870"))   # 대본 시험은 정해진 난수(--combatseed로 바꿈)
	if test != null: combat_view.bot = test.combat_bot
	ui.prompt("")
	combat_view.start(a, opts)
	# 떡 던지기는 가진 떡으로(최대 3개) — 던진 만큼 소지품에서 뺀다
	var tteok_id := String(data.get("combat_bait_item", "ITM_LIFE_001"))
	var bait0 := mini(3, S.count(tteok_id))
	combat_view.battle.player.bait = bait0
	combat_view.battle.player.skills = { guard_shove = bool(S.vars.get("SKILL_GUARD_SHOVE", false)) or main.args.has("allskills"),
		quick_throw = bool(S.vars.get("SKILL_QUICK_THROW", false)) or main.args.has("allskills") }   # --allskills: 시험용
	var res: String = await combat_view.finished
	var used: int = bait0 - int(combat_view.battle.player.bait)
	if used > 0: take(tteok_id, used)
	return res

func _overhear(lines: Array) -> void:
	for l in lines:
		await ui.caption("%s  “%s”" % [String(l[0]), String(l[1])], 2.2)

func end_combat() -> void:
	if combat_view != null: combat_view.reset()

func show_ending() -> void:
	var d: Dictionary = case_fn.ending_data() if case_fn.has_method("ending_data") else {}
	await ui.ending(d)
	for n in _skills_msgs: await ui.caption("새 행동을 익혔다 — " + String(n), 2.4)
	_skills_msgs.clear()

# ---------------------------------------------------------------------------
# 지역 변화(밤 울음소리 등)와 소문
# ---------------------------------------------------------------------------
# 음악(scripts/audio/sound.gd): 사건이 원하는 곡(case_fn.music_wanted — 없거나 사건이 없는 공간이면 "")을 1초마다 보고 바뀔 때만 튼다·멈춘다
func _update_music(dt: float) -> void:
	_music_t -= dt
	if _music_t > 0.0: return
	_music_t = 1.0
	var want := ""
	if case_fn != null and S != null and _started and case_fn.has_method("music_wanted"): want = String(case_fn.music_wanted())
	if want == _music_cur: return
	if _music_cur == "?" and want == "":
		_music_cur = ""; Sound.music_stop(1.5); return
	_music_cur = want
	if want == "": Sound.music_stop(2.5)
	else: Sound.music(want, 4.0)   # 천천히 들어온다(조용히)

func _update_ambient(dt: float) -> void:
	if case_fn != null and case_fn.has_method("ambient"): case_fn.ambient(dt)

func _update_rumors(dt: float) -> void:
	_rumor_t -= dt
	if _rumor_t > 0.0 or (runner != null and runner.busy) or ui.modal: return
	_rumor_t = 0.5
	var pp := Vector2(main.player_pos.x, main.player_pos.z)
	var outcome_vals := Progress.vars()
	for r in Rumors.for_space(space_id, world.region):
		var id := String(r.id)
		if _rumor_seen.has(id): continue
		if pp.distance_to(r.p) > float(r.get("radius", 26.0)): continue
		var line: String = Rumors.pick(r, outcome_vals, S.vars if S != null else {})
		if line == "": continue
		_rumor_seen[id] = true
		printerr("RUMOR %s [%s] %s" % [id, r.get("speaker", ""), line])
		Progress.add_heard({ id = id, space = space_id, by = String(r.get("speaker", "")), text = line, place = "" })   # 엿들은 말도 '들음'(사실 아님)
		ui.caption("%s  “%s”" % [String(r.get("speaker", "")), line], 4.0)
		return

# ---------------------------------------------------------------------------
# 새로 할 말이 있는 이야기 인물(머리 위 「…」 — onboarding._update_talk_marks)
#   지금 고를 talk 항목(조건이 맞는 첫 항목)의 '서명'을 아직 안 들었으면 참. 서명 = 항목 번호 + 조건부 대사·if 결과 + 고를 수 있는 물음.
#   이미 말을 나눈 사람의 '늘(true)' 대사만 있는 항목(되풀이 잡담)과, 고를 물음이 다 떨어진 항목은 새 말이 아니다.
#   들은 서명은 S.seen._talk { 인물: [서명] } — 이 표시는 '할 말이 있다'일 뿐, 거짓말·정답을 뜻하지 않는다.
# ---------------------------------------------------------------------------
const SAY_KEYS := ["say", "lines", "when"]

func talk_sig(a: Dictionary) -> String:
	var talk = a.spec.get("talk")
	if not (talk is Array) or S == null: return ""
	var idx := -1
	for i in talk.size():
		if runner.cond(talk[i].get("when", true)): idx = i; break
	if idx < 0: return ""
	var ent: Dictionary = talk[idx]
	var steps: Array = ent.get("steps", [])
	var parts := [str(idx)]
	var say_only := true
	var has_choice := false
	var open_opts := 0
	for st in steps:
		if not (st is Dictionary): continue
		for k in st:
			if not SAY_KEYS.has(k): say_only = false
		if st.has("say") and st.has("when"): parts.append("s%d" % int(runner.cond(st.when)))
		if st.has("if"): parts.append("i%d" % int(runner.cond(st.get("if"))))
		if st.has("choice"):
			has_choice = true
			for o in st.get("options", []):
				if o.get("end", false): continue
				if o.has("when") and not runner.cond(o.when): continue
				open_opts += 1
				parts.append(String(o.get("label", "")))
	var w = ent.get("when", true)
	var always: bool = w is bool or String(w).strip_edges() == "true"
	if say_only and always and int(S.talked.get(String(a.id), 0)) > 0: return ""   # 되풀이 잡담
	if has_choice and open_opts == 0:
		var other := false
		for st in steps:
			if st is Dictionary and not st.has("choice") and not st.has("say"): other = true
		if not other: return ""   # 물을 것을 다 물었다
	return "|".join(parts)

func talk_pending(id: String) -> bool:
	var a = actors.get(id)
	if a == null or not a.shown or a.spec.get("talk") == null: return false
	var sig := talk_sig(a)
	if sig == "": return false
	var seen: Dictionary = S.seen.get("_talk", {})
	return not (seen.get(id, []) as Array).has(sig)

func _talk_seen_now(a: Dictionary) -> void:
	var sig := talk_sig(a)
	if sig == "": return
	var seen: Dictionary = S.seen.get("_talk", {})
	var l: Array = seen.get(String(a.id), [])
	if not l.has(sig): l.append(sig)
	seen[String(a.id)] = l
	S.seen["_talk"] = seen
