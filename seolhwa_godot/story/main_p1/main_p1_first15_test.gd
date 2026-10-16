# 첫 15분 흐름 시험(재기획 3단계) — 시작 메뉴 → 새 게임 → 이겸의 거처 → 방 물건 → 문 두드림 → 심부름꾼 → 봉투 → 서안 견주기 →
#   거처 밖 「설화록」 → 걸어서 솔잎 주막 → 주모 → 장부·손님 → M 지도 → [목적지 설정] 을 한 번에 이어 논다.
#   region_main --continuetest=first15(scripts/story/continue_test.gd가 시작 메뉴를 확인한 뒤 부른다 — tools/run_story_tests.sh first15:*).
#   잰다: 서장 프롤로그(새 게임 → 프롤로그 박자 INTRO_01~04 → 0.25초 dip → 방 안 조작, 뒤에 따로 여는 장면 없음 · --first15=skip이면 건너뛰기와
#     새 게임 Enter 0.5초 막이) · 짧은 기억(P00-B) 재생 없음 · 안내 하나하나가 실제 행동으로 끝나는가(시간으로 끝나지 않는가) · 대화·조사 뒤 이동 바로 복귀(0.3초) ·
#     E 겹침(닫힌 뒤 E 연타로 창 둘이 열리지 않음) · 카메라 복귀(override·focus·talk_yaw 없음) · 제목 단계 시각(재기획 OP-04) · 거처 → 주막 도보 시간 ·
#     저장 재개(편지 뒤·주막 대화 뒤·목적지 뒤 — 저장에서 사건을 다시 읽어 같은 자리) · 목적지는 정하기만(순간이동 없음) · 오누이 들머리(--first15=onui).
#   --storyshots=폴더(창 실행)면 장면마다 찍는다(shots/replan_stage3/). 끝 줄은 continue_test의 CONTTEST PASS/FAIL.
extends RefCounted

const Progress := preload("res://scripts/region/progress.gd")
const TitleMenu := preload("res://scripts/story/title_menu.gd")
const D := preload("res://story/main_p1/main_p1_data.gd")

var ct            # continue_test(_ok·_fail·_wait_until·_press_e)
var main
var d
var shots := false
var shot_dir := ""
var log: Array = []
var result := {}
var _dumps := 0

func _init(cont, m) -> void:
	ct = cont; main = m
	shots = main.args.has("storyshots") and DisplayServer.get_name() != "headless"
	if shots: shot_dir = main._abs(String(main.args.storyshots))

func _now() -> float: return Time.get_ticks_msec() / 1000.0
func _ok(c: bool, why: String) -> void: ct._ok(c, why)
func _wait(f: Callable, sec: float) -> bool: return await ct._wait_until(f, sec)
func _frames(n: int) -> void: await main._wait_frames(n)

func shot(nm: String) -> void:
	if not shots: return
	await _frames(3)
	var img: Image = main.get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(shot_dir)
	var p := shot_dir.path_join("%s.png" % nm)
	img.save_png(p)
	print("FIRST15 SHOT ", p)

func _key(kc: int) -> void:
	for down in [true, false]:
		var ev := InputEventKey.new()
		ev.physical_keycode = kc; ev.keycode = kc; ev.pressed = down
		Input.parse_input_event(ev)
		await _frames(2)

func _free() -> bool:
	return d._started and not d.blocks_move() and not d.runner.busy and not d.ui.modal and not d.talking and not d.ui.journal_open

func _cam_home() -> bool:
	var r = main.rig
	return r.override == null and r.focus == null and r.talk_yaw == null and not r.gliding()

func _teleport(at, off := Vector2.ZERO) -> void:
	var p: Vector2 = d.anchor(at) + off
	d.teleport_to(p)   # 카메라도 바로(찍을 때 옮겨 가는 도중이 찍히지 않게)
	await _frames(6)

# 대상(E)이 그것이 될 때까지 서서 E — 열렸는지는 then(콜러블)로
func _e_on(id: String, opened: Callable, why: String, sec := 6.0) -> bool:
	var near := func(): return d._target != null and String(d._target.get("id", "")) == id
	if not await _wait(near, 4.0):
		_ok(false, "%s: E 대상이 %s가 아님(지금 %s)" % [why, id, d._target.get("id", "없음") if d._target != null else "없음"]); return false
	await _wait(func(): return not d.ui.busy_input(), 2.0)   # 닫은 뒤 E 겹침 막기(0.15~0.2초) 동안은 사람이 눌러도 버린다 — 지나서 누른다
	print("FIRST15 press E target=%s busy_input=%s(cool %.2f) runner=%s talking=%s modal=%s journal=%s" % [d._target.get("id", "") if d._target != null else "-", d.ui.busy_input(), float(d.ui._cooldown), d.runner.busy, d.talking, d.ui.modal, d.ui.journal_open])
	await ct._press_e()
	var ok: bool = await _wait(opened, sec if not shots else sec * 3.0)
	if not ok:   # 한 번 더(무엇이 E를 받았는지 남긴다)
		print("FIRST15 E 실패 target=%s busy_input=%s runner=%s talking=%s" % [d._target.get("id", "") if d._target != null else "-", d.ui.busy_input(), d.runner.busy, d.talking])
	_ok(ok, why)
	return ok

# 조사·대화가 끝나면 조작이 바로 돌아오는가(0.3초) + 카메라 복귀(0.7초 안)
func _after_close(why: String) -> void:
	await _wait(func(): return not d.runner.busy and not d.ui.modal and not d.talking, 60.0)
	var t0 := _now()
	var back: bool = await _wait(_free, 0.3)
	_ok(back, "%s 뒤 이동 바로 복귀(%.2f초)" % [why, _now() - t0])
	var cam_ok: bool = await _wait(_cam_home, 1.2)
	_ok(cam_ok, "%s 뒤 카메라 복귀(override·focus·talk_yaw 없음)" % why)

# 걷기 봇: 길 점을 따라 실제 입력(이동 키 세기)으로 걷는다 — 막히면 그 자리를 알린다. 돌려줌 {t, dist, stuck}
func walk(points: Array, why: String, run := false, limit := 240.0, tol := 0.9) -> Dictionary:
	var t0 := _now()
	var dist := 0.0
	var stuck := 0
	var last := Vector2(main.player_pos.x, main.player_pos.z)
	var still := 0.0
	if run: Input.action_press("run")
	for q in points:
		var tgt: Vector2 = d.anchor(q)
		while true:
			await _frames(1)
			var p := Vector2(main.player_pos.x, main.player_pos.z)
			var v := tgt - p
			if v.length() < tol: break
			if _now() - t0 > limit: break
			if not _free():   # 길에서 이야기가 끼어들면(제목은 조작을 막지 않는다) 기다린다
				_release(); continue
			var n := v.normalized()
			_set_move(n)
			var stepd := p.distance_to(last)
			dist += stepd; last = p
			still = still + get_dt() if stepd < 0.004 else 0.0
			if still > 1.5:
				stuck += 1; still = 0.0
				print("FIRST15 walk stuck at (%.1f,%.1f) → %s" % [p.x, p.y, str(q)])
				main.teleport(p.x + n.x * 1.5, p.y + n.y * 1.5)   # 막힘을 기록하고 지나간다(판정에 넣는다)
		if _now() - t0 > limit: break
	_release()
	if run: Input.action_release("run")
	var r := { t = _now() - t0, dist = dist, stuck = stuck }
	print("FIRST15 walk %s t=%.1fs dist=%.0fm stuck=%d" % [why, r.t, r.dist, r.stuck])
	return r

func get_dt() -> float: return main.get_process_delta_time()

func _set_move(n: Vector2) -> void:
	# 기본 시점(yaw 0): 위 = −z(북). 대화 구도가 돌아간 채면 기다린다(걷기 중에는 yaw 0)
	Input.action_press("move_right", maxf(0.0, n.x)); Input.action_press("move_left", maxf(0.0, -n.x))
	Input.action_press("move_down", maxf(0.0, n.y)); Input.action_press("move_up", maxf(0.0, -n.y))
	for a in ["move_right", "move_left", "move_down", "move_up"]:
		if Input.get_action_strength(a) <= 0.001: Input.action_release(a)

func _release() -> void:
	for a in ["move_right", "move_left", "move_down", "move_up"]: Input.action_release(a)

# 고를 차례(앞이 먼저): 심부름꾼 달래기 · 견주기 결론 C(메인 대본 P01-B) · 주모 ① → ③ → '직접 본 것만…' → 고맙소(② 누구와 만났습니까는 남긴다 — 다시 말 걸면 남은 물음)
const PICK := ["숨부터 고르고.", "스승이 일부러 평소처럼 쓰지 않았나?", "마지막으로 언제 봤습니까?", "이 편지는 여기서 보내졌습니까?", "직접 본 것만 말씀해 주세요.", "고맙소."]
var picked: Array = []   # 시험 기록: 고른 줄
var choice_sets: Array = []   # 시험 기록: 뜬 선택지 묶음

func _choose(prompt: String, labels: Array) -> int:
	choice_sets.append(labels.duplicate())
	for want in PICK:
		var i := labels.find(want)
		if i >= 0: picked.append(want); return i
	for i in labels.size():
		if String(labels[i]).begins_with("지금은 가던 길") and not main.args.get("first15", "") == "onui": return i
		if String(labels[i]).begins_with("고개 너머 그 집에") and main.args.get("first15", "") == "onui": return i
	return 0

# 저장에서 사건을 다시 읽어 같은 상태인가(저장 재개 — 첫15 §08 '저장 재개')
func _resume_check(why: String, flags: Array) -> void:
	d.save()
	if main.args.has("first15dump"):   # 이어 하기 시험 저장 만들기(story/main_p1/test_main_*_save.json의 원본) — 모래상자에
		var f := FileAccess.open(Progress.SaveGuard.resolve("user://first15_dump_%d.json" % _dumps), FileAccess.WRITE)   # 모래상자 안(사용자 user://에 쓰지 않는다)
		_dumps += 1
		if f != null: f.store_string(JSON.stringify(Progress.data(), " ")); f.close()
	var pos := Vector2(main.player_pos.x, main.player_pos.z)
	var ph := String(d.S.phase)
	_ok(d.switch_case("main_p1", { "reload": true }), "%s: 저장에서 다시 읽기" % why)
	await _wait(func(): return d._started and not d.runner.busy, 10.0)
	await _frames(10)
	var miss := flags.filter(func(k): return not d.S.is_flag(String(k)))
	_ok(miss.is_empty() and String(d.S.phase) == ph, "%s: 다시 읽은 뒤 같은 국면(%s)·깃발(빠짐 %s)" % [why, d.S.phase, miss])
	_ok(Vector2(main.player_pos.x, main.player_pos.z).distance_to(pos) < 0.5, "%s: 자리 그대로(순간이동 없음)" % why)

func run() -> void:
	d = main.story
	var T0 := _now()
	d.ui.auto = true
	d.ui.auto_real = true   # 여는 장면은 실제 시간으로(D7을 잰다)
	d.ui.auto_choice = _choose
	d.doc_hook = _doc_exam
	if shots: d.ui.auto_hold = 1.4   # 찍을 때만: 선택지·카드를 찍을 만큼 띄워 둔다
	_listen()
	print("FIRST15 begin case=%s" % d.case_id)
	var t_click := _now()
	d.title._pick(0)   # 새 게임
	await _wait(func(): return d.case_id == "main_p1" and d._started, 15.0)
	_ok(d.case_id == "main_p1", "새 게임 → 메인 서장 main_p1(오누이 아님)")
	var c = d.case_fn
	var skip_mode := String(main.args.get("first15", "")) == "skip"
	if skip_mode:
		# 새 게임을 고른 키(Enter)가 곧바로 한 번 더 들어와도(0.2초) 건너뛰지 않는다 → 3초에 Esc로 건너뛴다
		await _wait(func(): return c.prologue_played, 10.0)
		await d.wait(0.2); await _key(KEY_ENTER)
		await d.wait(0.6)
		_ok(not c.op00_skipped and c.prologue_t.size() >= 1 and d._cut, "새 게임 Enter(0.2초)는 건너뛰기로 읽지 않음(처음 0.5초 막이)")
		await d.wait(2.0)
		var t_esc := _now()
		await _key(KEY_ESCAPE)
		var ok_sk: bool = await _wait(func(): return d.S.is_flag("OP00_DONE") and _free(), 3.0)
		var dt_sk := _now() - t_esc
		_ok(ok_sk and c.op00_skipped and d.S.is_flag("PROLOGUE_SKIPPED") and d.S.is_flag("PROLOGUE_SEEN"), "Esc로 프롤로그 건너뜀 → %.2f초 뒤 조작" % dt_sk)
		_ok(dt_sk <= 1.5, "건너뛰기 → 조작 1.5초 안(%.2f초)" % dt_sk)
		_ok(not d.actors.has("yigyeom_past") and c._pro_nodes.is_empty(), "건너뛰면 지난날 이겸·소품이 남지 않음")
		var post = main.get("post")
		_ok(post == null or float(post.past) == 0.0, "건너뛰면 색감도 지금으로(past 0)")
		_ok(not c.echo_ok(), "건너뛴 판은 견주기 끝 메아리(프롤로그 L3)를 띄우지 않음")
	if shots:
		await _wait(func(): return c.prologue_t.size() >= 1, 10.0)
		await d.wait(3.0); await shot("01_intro01_wide")
		await _wait(func(): return c.prologue_t.any(func(s): return s[0] == "INTRO_02"), 20.0)
		await d.wait(3.0); await shot("02_intro02_twoshot")
		await _wait(func(): return c.prologue_t.any(func(s): return s[0] == "INTRO_03"), 30.0)
		await d.wait(3.8); await shot("03_intro03_wipe")
		await _wait(func(): return c.prologue_t.any(func(s): return s[0] == "book_look"), 30.0)
		await d.wait(1.3); await shot("04_intro04_book")   # 펼친 쪽을 내려다봄 — 첫 줄 '구월 열이틀 맑음'
		await d.wait(1.0); await shot("04b_intro04_book_late")
		await _wait(func(): return c.prologue_t.any(func(s): return s[0] == "present"), 20.0)
		await d.wait(1.6); await shot("05_present_yard")
		await _wait(func(): return c.prologue_t.any(func(s): return s[0] == "last_line"), 20.0)
		await d.wait(1.0); await shot("06_room_last_line")
	var ctl: bool = await _wait(func(): return d.S.is_flag("OP00_DONE") and _free(), 90.0)
	var t_ctl := _now() - t_click
	result.control = c.control_t
	result.prologue = c.prologue_t
	print("FIRST15 prologue beats %s" % JSON.stringify(c.prologue_t))
	if not skip_mode:
		var names: Array = c.prologue_t.map(func(b): return String(b[0]))
		_ok(c.prologue_played and names == ["INTRO_01", "INTRO_02", "INTRO_03", "INTRO_04", "book_look", "fade_out", "silence", "present", "dip", "last_line", "control"],
			"프롤로그 박자 차례 %s" % [names])
		var tot: float = float(c.prologue_t[-1][1]) if c.prologue_t.size() > 0 else 0.0
		_ok(ctl and tot >= 44.0 and tot <= 58.0, "프롤로그 길이 %.1f초(약 50초 — 44~58)" % tot)
		var bl := 0.0; var fo := 0.0
		for b in c.prologue_t:
			if b[0] == "book_look": bl = float(b[1])
			if b[0] == "fade_out": fo = float(b[1])
		_ok(fo - bl >= c.line_sec(c.BOOK_FIRST) + 0.5, "기록책 펼친 쪽 내려다보기 %.2f초(첫 줄 '%s'을 읽는 시간 %.2f초 + 내려다봄)" % [fo - bl, c.BOOK_FIRST, c.line_sec(c.BOOK_FIRST)])
		_ok(String(D.documents().old_record.cols[0].text) == c.BOOK_FIRST, "프롤로그 기록책 첫 줄 = 견주기 옛 기록 첫 줄(같은 기록책)")
		_ok(not d.S.is_flag("PROLOGUE_SKIPPED") and d.S.is_flag("PROLOGUE_SEEN") and c.echo_ok(), "끝까지 봄(PROLOGUE_SEEN · 건너뛰지 않음)")
		var dip0 := 0.0; var room0 := 0.0
		for b in c.prologue_t:
			if b[0] == "dip": dip0 = float(b[1])
			if b[0] == "last_line": room0 = float(b[1])
		_ok(room0 - dip0 > 0.2 and room0 - dip0 < 0.45, "0.25초 dip으로 방 안(dip→마지막 줄 %.2f초)" % (room0 - dip0))
	_ok(ctl and c.control_t > 0.0, "새 게임 → 조작 반환 %.2f초(시험 측정 %.2f초)" % [c.control_t, t_ctl])
	_ok(c.steps_log.size() >= 2 and c.steps_log[-1][0] == "op00_control" and not c.steps_log.any(func(s): return String(s[0]).begins_with("op00_wide") or String(s[0]).begins_with("op00_push")),
		"프롤로그 뒤 따로 여는 장면 없음(옛 OP00 9초·VO 없음)")
	_ok(not d._cut and not d.actors.has("yigyeom_past"), "조작이 돌아오면 컷·지난날 이겸 없음")
	_ok(d.world.interior_at(main.player_pos.x, main.player_pos.z) != null, "시작 자리가 거처 방 안(START_AT_IEGYEOM_HOME)")
	_ok(Vector2(main.player_pos.x, main.player_pos.z).distance_to(Vector2(D.HX, D.HZ)) < 4.0, "새 거처(%.0f, %.0f) — 읍성 밖 솔숲 자락" % [D.HX, D.HZ])
	_ok(not d.onboard.is_seen("MOVE"), "이동 안내는 아직(시간으로 끝나지 않음)")
	await d.wait(0.5)
	await shot("04_control_move_hint")
	d.ui.auto_real = shots   # 그 뒤는 빠르게(찍을 때만 실제 길이)
	# --- 이동 3m(실제로 걸어야 끝) ---
	await d.wait(3.0)
	_ok(not d.onboard.is_seen("MOVE"), "3초 서 있어도 이동 안내가 끝나지 않음")
	var w0: Dictionary = await walk([D.L(-1.6, 0.4), D.L(1.6, 0.6), D.L(-0.4, 0.9)], "방 안 3m", false, 30.0, 0.35)
	await _frames(10)
	_ok(d.onboard.is_seen("MOVE"), "실제로 3m 넘게 걸으면 이동 안내 끝(moved=%.1fm)" % d.onboard.moved_m)
	# --- P00-A 장부(첫 조사) ---
	await _teleport("ledger", Vector2(0.0, 0.9))
	_ok(not d.onboard.is_seen("INSPECT"), "조사 안내는 조사 전 그대로")
	await shot("05_ledger_prompt")
	await _e_on("o_ledger", func(): return d.S.has_clue("ledger"), "E 장부 조사")
	await _after_close("장부 조사")
	_ok(d.onboard.is_seen("INSPECT"), "첫 조사로 조사 안내 끝(INSPECT)")
	_ok(d.S.is_flag("P00_ITEM_SEEN"), "P00_ITEM_SEEN")
	# --- R 기록책: 열고 닫아야 끝 ---
	_ok(not d.onboard.is_seen("JOURNAL"), "기록책 안내는 열기 전 그대로")
	await _key(KEY_R)
	await _wait(func(): return d.ui.journal_open, 3.0)
	await shot("06_journal_open")
	await _frames(10)
	_ok(not d.onboard.is_seen("JOURNAL"), "기록책을 열기만 해서는 끝나지 않음(열고 닫음)")
	await _key(KEY_R)
	await _wait(func(): return not d.ui.journal_open, 3.0)
	await _frames(10)
	_ok(d.onboard.is_seen("JOURNAL"), "기록책을 열고 닫으면 안내 끝(JOURNAL)")
	# --- 신발 · 붓 → 짧은 기억(P00-B) ---
	await _teleport("shoes", Vector2(-0.1, -0.85))
	await _e_on("o_shoes", func(): return d.S.has_clue("shoes"), "E 신발 조사")
	await _after_close("신발 조사")
	await _teleport("brush", Vector2(0.7, -0.6))
	await _e_on("o_brush", func(): return d.S.has_clue("brush"), "E 붓 조사")
	await _wait(func(): return d.S.is_flag("FLASHBACK_SEEN") and not d.runner.busy, 10.0)
	_ok(d.S.is_flag("FLASHBACK_SEEN") and not d._cut and not d.actors.has("yigyeom_past"), "셋 다 보면 깃발만(P00-B 재생 없음 — 프롤로그와 겹침)")
	_ok(d.S.has_clue("ledger") and d.S.has_clue("shoes") and d.S.has_clue("brush"), "방 물건 조사 결과·기록은 그대로")
	await _after_close("붓 조사")
	# --- 문 두드림 → 심부름꾼 ---
	var kn: bool = await _wait(func(): return d.S.is_flag("KNOCKED"), 15.0)
	_ok(kn, "첫 조사 뒤 문 두드림(KNOCKED)")
	await _frames(20)
	_ok(d.actors.messenger.shown, "심부름꾼이 마당에")
	await _teleport("messenger", Vector2(-0.6, 1.2))
	_ok(not d.onboard.is_seen("TALK"), "대화 안내는 말 걸기 전 그대로")
	await shot("08_messenger_prompt")
	var shot_talk := func(): return d.ui._dialog.visible
	await _e_on("messenger", func(): return int(d.S.talked.get("messenger", 0)) > 0, "E 심부름꾼에게 말 걸기")
	if shots:
		await _wait(shot_talk, 3.0); await d.wait(0.7); await shot("09_messenger_talk")
	await _after_close("심부름꾼 대화")
	_ok(d.onboard.is_seen("TALK"), "말을 걸고 첫 줄이 보이면 대화 안내 끝(TALK)")
	_ok(d.S.has_clue("messenger") and d.S.is_flag("TALK_SEEN"), "심부름꾼의 말(들음)")
	_ok(d.main.get("_map") != null, "지도 있음")
	# E 연타: 닫힌 직후 E를 세 번 — 같은 대화가 다시 열리거나 창이 둘 열리지 않는다(다시 열리면 줄 하나 — 정상)
	var n_talk := int(d.S.talked.get("messenger", 0))
	for i in 3: await ct._press_e()
	await _frames(20)
	var dup: bool = d.ui.modal and d.ui._choice.visible and d.ui._card.visible
	_ok(not dup, "E 연타로 창 둘이 겹쳐 열리지 않음(talked %d → %d)" % [n_talk, int(d.S.talked.get("messenger", 0))])
	await _wait(func(): return not d.runner.busy and not d.ui.modal and not d.talking, 30.0)
	# --- 문턱의 봉투 → 편지 ---
	await _teleport("threshold", Vector2(0.6, 1.0))
	await _e_on("o_envelope", func(): return d.S.is_flag("LETTER_RECEIVED"), "E 문턱의 봉투 — 편지 읽기(LETTER_RECEIVED)")
	if shots:
		await _wait(func(): return d.ui._card.visible, 3.0); await d.wait(0.6); await shot("10_letter")
	await _after_close("편지 읽기")
	_ok(d.S.has(D.LETTER), "출처 미확인 편지가 소지품에")
	_ok(_said.has("나그네|이상하네. 스승님이 이런 글을 쓰실 분인가?"), "편지 첫 읽기 — 나그네의 혼잣말(시스템이 날짜 없음을 먼저 말하지 않음)")
	_ok(not _exam_text.contains("날짜") and not _caps.has("서안의 옛 기록과 견주어 보자."), "편지 카드에 '날짜·표시 없음' 없음 · 목표 자막 '서안의 옛 기록과 견주어 보자.' 없음")
	await _resume_check("저장 재개 — 편지 읽은 뒤", ["LETTER_RECEIVED", "KNOCKED", "TALK_SEEN", "OP00_DONE"])
	# --- 서안: 옛 기록과 편지 견주기 ---
	await _teleport("desk_front")
	_doc_plan = ["first_close"]   # 첫 번째는 하나만 짚고 Esc로 덮는다(다시 이어 하기)
	await _e_on("o_desk", func(): return d.ui.modal, "E 서안 — 견주기 열기")
	await _wait(func(): return not d.runner.busy and not d.ui.modal, 30.0)
	_ok(not d.S.is_flag("LETTER_SUSPICIOUS"), "하나만 짚고 덮으면 아직 의심 전(벌점 없음 · 다시 이어 할 수 있음)")
	await _resume_check("저장 재개 — 견주기 도중", ["LETTER_RECEIVED"])
	_ok((d.S.flags.get("_doc_found", {}) as Dictionary).has("old_record/o_date"), "견주기 도중 저장 — 짚은 자리 그대로(_doc_found)")
	_doc_plan = ["nokey"]   # 날짜·방향 두 쌍만 — 열쇠 짝(모르는 것 ↔ 신선) 없이 덮는다
	await _e_on("o_desk", func(): return d.ui.modal, "E 서안 — 다시 열어 이어 하기")
	await _wait(func(): return not d.runner.busy and not d.ui.modal, 30.0)
	await _wait(func(): return d.case_fn.steps_log.any(func(s): return s[0] == "compare_nudge") and _caps.has(c.NUDGE), 4.0)
	_ok(d.S.has_clue("cmp_date") and d.S.has_clue("cmp_way") and not d.S.is_flag("LETTER_SUSPICIOUS") and not d.S.is_flag("LETTER_COMPARE_2"), "날짜·방향 두 쌍만으로는 끝나지 않음(날짜 없음·말투 차이만으로 위조 확정 없음)")
	_ok(_caps.has(c.NUDGE) and d.case_fn.steps_log.any(func(s): return s[0] == "compare_nudge"), "두 쌍이지만 열쇠 짝이 없으면 정답이 아닌 귀띔 한 줄 %s" % [_caps.slice(-3)])
	_ok(d._targets().any(func(t): return String(t.id) == "o_desk"), "귀띔 뒤 서안을 다시 열 수 있음")
	await _after_close("견주기(귀띔)")
	_doc_plan = ["key"]
	_said.clear(); _caps.clear()
	_watch_conclusion()
	await _e_on("o_desk", func(): return d.ui.modal, "E 서안 — 다시 열어 모르는 것 ↔ 신선 짚기")
	await _wait(func(): return d.S.is_flag("LETTER_SUSPICIOUS") and not d.runner.busy, 40.0)
	_ok(d.S.is_flag("LETTER_COMPARE_2") and d.S.is_flag("LETTER_SUSPICIOUS") and d.S.has_clue("cmp_unknown"), "모르는 것 ↔ 신선 쌍이 들면 LETTER_SUSPICIOUS(추정 — 위조 확정 아님)")
	var cset: Array = choice_sets.filter(func(l): return l.has("스승이 일부러 평소처럼 쓰지 않았나?"))
	_ok(not cset.is_empty() and cset[0] == ["글씨를 흉내 낸 자가 있다.", "누가 내용을 대신 써줬을지도 모른다.", "스승이 일부러 평소처럼 쓰지 않았나?"], "결론 선택 A·B·C = 메인 대본 P01-B %s" % [cset])
	var order := ["나그네|기다리라고? …누가 날 찾지 못하게 하려는 거라면?", "CHOICE", "나그네|직접 확인해야 한다."]
	if d.case_fn.echo_ok(): order.append("CAP|이겸  “틀린 자리를 다시 찾을 수 있지.”")   # 프롤로그를 건너뛴 판은 메아리 없음
	_ok(_seq.filter(func(x): return order.has(x)) == order, "견주기 뒤 차례: 의심 한 줄 → A/B/C → 직접 확인 → 이겸 메아리 %s" % [_seq])
	_ok(_said.size() == 2, "견주기 뒤 나그네 줄은 둘뿐(결론을 되풀이하지 않음) %s" % [_said])
	_ok(String(d.data.clues.suspicious.kind) == "guess", "수상한 편지는 추정(△)으로 적힘")
	await _after_close("견주기")
	_ok(String(d.S.phase) == "town", "국면 town")
	# --- 거처 → 오솔길 → 구례 길 → 장승 어귀 「설화록」(조작 그대로) → 나루 → 솔잎 주막 — 한 번에 걸어서 ---
	await _teleport("door", Vector2(0.0, 0.6))
	d.ui.auto_real = true   # 제목 단계 시각·걷는 시간을 실제 시간으로(재기획 OP-04)
	var route := ["yard", "street", [-3214.0, 708.6]] + ROUTE_GURYE + ["solip_front"]
	_title_at = Vector2.INF
	_watch_title()   # 제목이 뜬 자리를 기다리며 적는다(걷기와 함께 돈다)
	var wk: Dictionary = await walk(route, "거처 → 솔잎 주막(걷기)", false, 260.0)
	var title_at := _title_at
	result.walk = wk
	_ok(d.S.is_flag("TITLE_IN_WORLD_SEEN"), "가는 길에 제목(TITLE_IN_WORLD_SEEN)")
	var td: float = title_at.distance_to(d.anchor("title_view")) if title_at != Vector2.INF else 999.0
	_ok(td <= c.TITLE_AT_M + 1.5, "제목은 구례 길 장승 어귀에서(%.1fm)" % td)
	result.title_at = [title_at.x, title_at.y]
	await _wait(func(): return not d.case_fn.title_running, 14.0)
	d.ui.auto_real = shots
	_ok(d.case_fn.title_t.size() >= 5, "제목 단계 시각 %s" % JSON.stringify(d.case_fn.title_t))
	result.title = d.case_fn.title_t
	_ok(wk.stuck == 0, "거처 → 주막 길에 막힘 없음(stuck %d — 나루 나룻배 포함)" % wk.stuck)
	_ok(wk.t >= 100.0 and wk.t <= 180.0, "걷기 %.0f초(사용자 기준 2~3분)" % wk.t)
	_ok(d.S.is_flag("TAVERN_NEAR"), "주막 앞마당에 닿음(TAVERN_NEAR)")
	print("FIRST15 route walk %.1fs %.0fm (거처 이전 — 2~3분)" % [wk.t, wk.dist])
	await shot("12_solip_arrive")
	# --- 주모 ---
	await _teleport("solip_jumo", Vector2(-1.2, 1.3))
	_said.clear()
	_watch_jumak()
	await _e_on("solip_jumo", func(): return d.S.is_flag("TAVERN_TALK") or int(d.S.talked.get("solip_jumo", 0)) > 0, "E 주모에게 말 걸기")
	await _after_close("주모 대화")
	_ok(d.S.is_flag("TAVERN_TALK") and d.S.has_clue("tv_jumo_last") and not d.S.has_clue("tv_jumo"), "주모 첫 대화(TAVERN_TALK) · ① 마지막으로 본 때(◇)")
	var jumo_want := ["주모|이겸? 매번 묵으면 먹은 것과 쓴 것을 죄 적던 양반 말이오? 국에 파를 빼달라고 해 놓고, 나중에는 그 사정까지 기록하더니.",
		"주모|며칠 전 산에서 내려오는 장사꾼에게 뭔가 물었소. 아이 하나가 없어졌다는 소문도 캐묻고.",
		"주모|그런 편지가 여기서 넘어갔다고? 심부름꾼은 왔다 갔소. 누가 썼는지까지 내가 보지는 못했지.",
		"주모|그 편지는 글씨가 참 반듯했는데, 글을 맡긴 양반 손이 먹투성이였단 말은 못 들었소. ...아니, 내가 본 건 아니고.",
		"주모|옳지. 당신 스승이 꼭 그렇게 말하더라고."]
	_ok(_said == jumo_want, "주모 줄 = 메인 대본 P02-A(여는 말 · ① · ③ · 더듬는 말 · '직접 본 것만…' 답) %s" % [_said])
	_ok(picked.has("직접 본 것만 말씀해 주세요."), "③ 뒤 '직접 본 것만 말씀해 주세요.' 선택")
	_ok(not _said.any(func(x): return String(x).contains("직접 본 건 숙박 장부뿐") or String(x).contains("나도 들은 말이오")), "주모·손님이 제자처럼 '본/들은'을 나누는 옛 줄 없음")
	_ok(not d.S.is_flag("TAVERN_CLUE"), "주모 말만으로는 지도 등록 없음")
	await _resume_check("저장 재개 — 주막 대화 뒤", ["TAVERN_TALK", "LETTER_SUSPICIOUS", "TITLE_IN_WORLD_SEEN"])
	# --- 장부(확인) · 손님(들음) ---
	await _teleport("solip_ledger", Vector2(0.2, 1.0))
	await _e_on("o_solip_ledger", func(): return d.S.has_clue("tv_last"), "E 숙박 장부(확인된 사실)")
	await _after_close("숙박 장부")
	_ok(not d.S.is_flag("TAVERN_CLUE") and d.main.get("_map") != null, "장부 하나로는 아직 지도 등록 없음(둘 이상 — 메인 대본 P02-A)")
	_ok(String(d.data.clues.tv_last.kind) == "fact" and String(d.data.clues.tv_baekun.kind) == "heard" and String(d.data.clues.tv_guest2.kind) == "heard", "확인(◆ 장부)·들음(◇ 손님 증언) 구분")
	await _teleport("solip_guest2", Vector2(0.9, 0.9))
	_said.clear()
	await _e_on("solip_guest2", func(): return d.S.has_clue("tv_guest2"), "E 짚신 손님 — 여원재 너머(들음)")
	if shots: await shot("13d_guest2")
	await _after_close("짚신 손님 대화")
	_ok(_said == ["짚신 손님|이겸이 여원재 너머로 간다 했다."], "짚신 손님 줄 %s" % [_said])
	_ok(d.S.is_flag("TAVERN_CLUE"), "장부 + 짚신 손님 = 둘 → 지도 후보 '여원재 방면'(TAVERN_CLUE)")
	await _teleport("solip_guest", Vector2(0.9, 0.9))
	await _e_on("solip_guest", func(): return d.S.has_clue("tv_baekun"), "E 손님 — 백운 소문(선택)")
	await _after_close("손님 대화")
	_ok(not d._targets().any(func(t): return String(t.id) == "solip_guest" or String(t.id) == "solip_guest2"), "증언한 손님은 되풀이 줄 없이 장면으로(제자처럼 말하는 옛 줄 없음)")
	# --- M 지도 → 여원재 방면 → [목적지 설정] ---
	_ok(not d.onboard.is_seen("MAP") and not d.onboard.is_seen("WAYPOINT"), "지도·목적지 안내는 행동 전 그대로")
	var pos0 := Vector2(main.player_pos.x, main.player_pos.z)
	await _key(KEY_M)
	var mp = main.get("_map")
	await _wait(func(): return mp.visible, 3.0)
	await _frames(30)
	_ok(d.onboard.is_seen("MAP"), "M으로 지도를 실제로 열면 지도 안내 끝(MAP)")
	_ok(mp.mode == "all", "목적지 후보가 함께 드는 권역 지도로 열림(mode %s)" % mp.mode)
	await shot("14_map_open")
	var hit = null
	for h in mp._hits:
		if h.has("lead") and String(h.lead.get("id", "")) == "mp_yeowon": hit = h
	_ok(hit != null, "지도에 붉은 인 '여원재 방면'")
	if hit != null:
		for down in [true, false]:
			var ev := InputEventMouseButton.new()
			ev.button_index = MOUSE_BUTTON_LEFT; ev.pressed = down; ev.position = hit.p
			mp._on_input(ev)
			await _frames(2)
		await _frames(6)
		_ok(mp._wp_btn.visible, "붉은 인을 누르면 [목적지 설정] 단추")
		await shot("15_map_pin")
		_ok(not d.onboard.is_seen("WAYPOINT"), "누르기만 해서는 목적지 안내가 끝나지 않음")
		mp._wp_btn.pressed.emit()
		await _frames(10)
	var wp := Progress.waypoint()
	_ok(String(wp.get("key", "")) == "main_p1/mp_yeowon", "목적지 저장 %s" % JSON.stringify(wp))
	_ok(d.onboard.is_seen("WAYPOINT") and d.S.is_flag("WAYPOINT_SET"), "목적지를 정하면 안내 끝(WAYPOINT) · WAYPOINT_SET")
	_ok(Vector2(main.player_pos.x, main.player_pos.z).distance_to(pos0) < 0.5, "목적지만 정하고 순간이동 없음")
	await shot("16_map_waypoint")
	await _key(KEY_M)
	await _wait(func(): return not mp.visible, 3.0)
	await _frames(30)
	var hud = d.get_node_or_null("waypoint_hud")
	_ok(hud != null and String(hud.text).contains("여원재 방면"), "세계 방위 줄 「%s」" % (hud.text if hud != null else "-"))
	await shot("17_world_bearing")
	_ok(d.S.is_flag("M_OPEN_SEEN"), "M_OPEN_SEEN")
	await _resume_check("저장 재개 — 목적지 뒤", ["WAYPOINT_SET", "TAVERN_CLUE", "M_OPEN_SEEN"])
	_ok(String(d.S.phase) == "road", "국면 road(쉬는 자리)")
	var hold_core := ["MOVE", "INSPECT", "TALK", "JOURNAL", "MAP", "WAYPOINT"]
	_ok(hold_core.all(func(k): return d.onboard.is_seen(k)), "첫15 §07 안내 여섯이 모두 행동으로 끝남")
	result.total = _now() - T0
	print("FIRST15 result %s" % JSON.stringify(result))
	if String(main.args.get("first15", "")) == "onui": await _onui()

# 대사·자막 엿듣기(story_ui.log_lines를 쓰지 않고 — say·caption 앞 on_say와 _cap_text를 프레임마다 본다)
var _said: Array = []    # ["누가|줄"]
var _caps: Array = []
var _seq: Array = []     # 차례: "누가|줄" · "CHOICE" · "CAP|자막"
var _exam_text := ""
var _last_dlg := ""
var _last_cap := ""
var _choice_on := false
func _listen() -> void:
	while true:
		await _frames(1)
		var ui = d.ui
		if ui._dialog.visible and String(ui._type_full) != "" and String(ui._dlg_name.text) + "|" + String(ui._type_full) != _last_dlg:
			_last_dlg = String(ui._dlg_name.text) + "|" + String(ui._type_full)
			_said.append(_last_dlg); _seq.append(_last_dlg)
		if not ui._dialog.visible: _last_dlg = ""
		if String(ui._cap_text) != _last_cap:
			_last_cap = String(ui._cap_text)
			if _last_cap != "": _caps.append(_last_cap); _seq.append("CAP|" + _last_cap)
		if ui._card.visible: _exam_text = String(ui._card_text.text) if String(ui._card_title.text) == "편지" else _exam_text
		if ui._choice.visible != _choice_on:
			_choice_on = ui._choice.visible
			if _choice_on: _seq.append("CHOICE")

func _watch_conclusion() -> void:
	_seq.clear()
	if not shots: return
	await _wait(func(): return d.ui._dialog.visible and String(d.ui._type_full).begins_with("기다리라고"), 60.0)
	await d.wait(1.2); await shot("10e_doubt_line")
	await _wait(func(): return d.ui._choice.visible, 20.0)
	await d.wait(0.4); await shot("10f_conclusion_choice")
	await _wait(func(): return d.ui._dialog.visible and String(d.ui._type_full) == "직접 확인해야 한다.", 20.0)
	await d.wait(0.8); await shot("10g_check_myself")
	await _wait(func(): return String(d.ui._cap_text).contains("틀린 자리"), 20.0)
	await d.wait(0.6); await shot("10h_echo")

func _watch_jumak() -> void:
	if not shots: return
	await _wait(func(): return d.ui._dialog.visible and String(d.ui._type_full).begins_with("이겸? 매번"), 30.0)
	await d.wait(1.6); await shot("13_jumo_talk")
	await _wait(func(): return d.ui._choice.visible, 20.0)
	await d.wait(0.4); await shot("13a_jumo_choices")
	await _wait(func(): return d.ui._dialog.visible and String(d.ui._type_full).begins_with("그 편지는 글씨가"), 40.0)
	await d.wait(2.2); await shot("13b_jumo_letter")
	await _wait(func(): return d.ui._choice.visible, 20.0)
	await d.wait(0.4); await shot("13c_jumo_direct")
	await _wait(func(): return d.ui._dialog.visible and String(d.ui._type_full).begins_with("옳지"), 20.0)
	await d.wait(1.0); await shot("13c2_jumo_teacher")

var _title_at := Vector2.INF
func _watch_title() -> void:
	var n := 0
	while _title_at == Vector2.INF and n < 30000:
		await _frames(1); n += 1
		if d.case_fn.title_running or d.S.is_flag("TITLE_IN_WORLD_SEEN"): _title_at = Vector2(main.player_pos.x, main.player_pos.z)
	if shots and _title_at != Vector2.INF:
		await d.wait(5.5); await shot("11_title_jangseung")

# 거처 오솔길 끝 → 구례 길 북쪽 → 나루(걸어 건넘) → 주막 앞(길 그래프 namwon_gurye_road 점 — 이겸 거처 이전 4단계 측정과 같은 길)
const ROUTE_GURYE := [
	[-3216.2, 700.9], [-3217.0, 687.9], [-3222.0, 674.7], [-3231.0, 665.1], [-3239.4, 655.3], [-3246.5, 645.0],
	[-3251.3, 633.4], [-3251.5, 619.1], [-3246.5, 607.6], [-3239.1, 597.6], [-3236.0, 585.6], [-3235.1, 572.6],
	[-3229.4, 561.1], [-3221.3, 550.3], [-3210.3, 541.2], [-3209.4, 530.4], [-3199.5, 526.0], [-3202.6, 512.6],
	[-3209.9, 505.5], [-3215.4, 494.9], [-3215.8, 490.4]]

# 문서 비교 화면 시험(documents.gd doc_hook) — 처음엔 하나만 짚고 덮기, 다음엔 두 쌍
var _doc_plan: Array = ["full"]
func _doc_exam(ex) -> void:
	await _frames(8)
	if _doc_plan.has("first_close"):
		ex.mark_spot("old_record", "o_date")
		await _frames(4)
		ex.mark_at("letter", Vector2(0.5, 0.95))   # 아무것도 없는 자리 — "별다른 것은 짚이지 않는다"(벌점 없음)
		await _frames(4)
		_ok(String(ex._fb.text).contains("별다른 것"), "엉뚱한 자리를 짚으면 정보만(벌점 없음)")
		ex.close(); return
	if _doc_plan.has("nokey"):
		_ok(ex.note_text == "", "견주기 머리말 없음('날짜·방향·목격자를 적던 분인데.' — 답을 주는 말을 뺐다)")
		_ok(ex.hint_after == 60.0 and ex.hint_late == "날짜와 목적을 먼저 대조해 보자.", "늦은 도움말 60초 · 메인 대본 P01-B 문구")
		await shot("10b_compare_open")
		ex._idle_t = ex.hint_after - 0.05   # 60초 기다림을 줄여 본다(같은 _process 셈)
		await _wait(func(): return ex.late_hint_shown, 2.0)
		await _frames(2)
		var hp: Control = ex._root.get_node("hint_panel")
		_ok(ex.late_hint_shown and hp.visible and ex._hint.text == "날짜와 목적을 먼저 대조해 보자.", "짚은 것 없이 60초 → 늦은 도움말 한 번(정답 표시 없음)")
		await shot("10b2_compare_late_hint")
		ex.mark_spot("letter", "l_nodate")
		await _frames(4)
		ex.mark_spot("old_record", "o_way")
		await _frames(4)
		ex.mark_spot("letter", "l_days")
		await _frames(6)
		_ok(d.S.has_clue("cmp_date") and d.S.has_clue("cmp_way") and not d.S.has_clue("cmp_unknown"), "두 쌍 견주기(날짜·방향) — 열쇠 짝 아님")
		_ok(ex._open and d.ui.modal, "두 쌍을 짚어도 견주기는 저절로 닫히지 않음(자동 고르기 없음)")
		await shot("10c_compare_pairs")
		ex.close(); return
	ex.mark_spot("old_record", "o_unknown")
	await _frames(4)
	ex.mark_spot("letter", "l_sinseon")
	await _frames(6)
	_ok(d.S.has_clue("cmp_unknown"), "모르는 것 ↔ 신선 쌍(cmp_unknown)")
	await shot("10c2_compare_key")
	ex.close()

# 오누이 들머리(D1): 북문 밖 행상 → 「산길의 실종」이 선다(여는 장면 없이, 시각 그대로, 메인 저장은 그대로 쉰다)
func _onui() -> void:
	var h0: float = main.hour
	await _teleport("north_fork", Vector2(-1.2, 0.6))
	await shot("18_north_fork")
	await _e_on("peddler", func(): return d.case_id == "namwon", "E 행상 → 가 보겠다 → 오누이 사건")
	await _wait(func(): return d._started and not d.runner.busy, 15.0)
	await _frames(20)
	_ok(d.case_id == "namwon" and d.S.is_flag("case_started") and String(d.S.flags.get("route", "")) == "north", "오누이 선다(case_started · route north)")
	_ok(d.S.is_flag("INTRO_NAMWON_TITLE_DONE") and not d.S.seen.has("S0000") and not d.S.seen.has("S0001"), "여는 장면·제목 없이(S0000·S0001 안 돎)")
	_ok(absf(main.hour - h0) < 0.3, "시각 그대로(%.2f → %.2f)" % [h0, main.hour])
	var mst := Progress.case_state("main_p1")
	_ok(bool((mst.get("flags", {}) as Dictionary).get("WAYPOINT_SET", false)), "메인 서장 저장은 그대로(WAYPOINT_SET)")
	var FT = load("res://scripts/region/fast_travel.gd")
	_ok(FT.gate_for("JL_NAMWON_UNBONG", "namwon", "explore") == "", "오누이가 남원을 떠나는 길을 막지 않음(D1 — travel_gate 없음)")
	await shot("19_onui_started")
