# 메인 서장 「이겸의 수상한 편지」(main_p1) — 첫 15분의 연출·판정(재기획 3단계). 데이터: main_p1_data.gd
#   카메라 시간(첫15 §05, 대화 v1.1 §4): OP00 0–2 암전 · 2–5 담 와이드 · 5–9 책상 쪽 · 9 조작(0.6초 블렌드) / 조사 CAM_OBJECT 0.35 진입·복귀 /
#   편지 0.4 / OP01 재기획 OP-04: 0–2 길목 와이드 · 2–4.5 리프레이밍 · 4.5–8.5 「설화록」 · 8.5–9.5 사라짐(조작은 막지 않는다).
#   이야기 인물 대화는 2단계 대화 구도(CAM_TALK_2 0.55 / 복귀 0.45 — story_director·talk_frame)를 그대로 쓴다.
#   튜토리얼은 실제 행동으로만 끝난다(scripts/story/onboarding.gd CORE + 이 사건의 once 호출).
# 시험·기록: FIRST15 줄(로그) — control(새 게임 → 조작 반환 초) · step · title · waypoint.
extends RefCounted

const D := preload("res://story/main_p1/main_p1_data.gd")
const Docs := preload("res://scripts/story/documents.gd")
const Progress := preload("res://scripts/region/progress.gd")
const TitleMenu := preload("res://scripts/story/title_menu.gd")

const ROOM := ["ledger", "shoes", "brush"]
const KNOCK_AFTER := 6.0       # 첫 조사 뒤 문 두드림까지(조작 중 — 한가한 시간만 센다)
const KNOCK_NEAR := 40.0       # 거처에서 이보다 멀면 돌아올 때까지 미룬다
const OBJ_IN := 0.35           # CAM_OBJECT 진입·복귀(첫15 P00-A)
const LETTER_IN := 0.4         # 편지 조사(첫15 P01-A)
const TITLE_OUT_M := 4.0       # 거처 밖 4m(첫15 OP01)

var d
var S:
	get: return d.S
var control_t := -1.0          # 시험 기록: 새 게임 → 조작 반환(초) — D7
var op00_skipped := false
var title_running := false
var title_t := []              # 시험 기록: 제목 연출 단계별 시각
var steps_log: Array = []      # 시험 기록: [단계, 시각]
var _knock_t := -1.0

func _init(director) -> void:
	d = director

func flag(k: String, v = true) -> void:
	S.flags[k] = v; d.runner.log_line("flag", [k, v]); d.mark_dirty()

func f(k: String) -> bool: return S.is_flag(k)

func _now() -> float: return Time.get_ticks_msec() / 1000.0

func _log(step: String) -> void:
	steps_log.append([step, snappedf(_now(), 0.01)])
	printerr("FIRST15 step %s t=%.2f" % [step, _now()])

func room_seen() -> int:
	var n := 0
	for k in ROOM:
		if S.has_clue(k): n += 1
	return n

# ---------------------------------------------------------------------------
# 들머리 — 새 게임(OP00) / 옛 저장 합류(JOIN)
# ---------------------------------------------------------------------------
# 다른 사건을 이미 지난 저장(오누이·춘향 진행이 있음)은 새 게임이 아니다 — 여는 장면 없이 합류(추가 지시 2)
func is_joiner() -> bool:
	for id in Progress.data().cases:
		if String(id) != "main_p1" and not (Progress.case_state(String(id)) as Dictionary).is_empty(): return true
	return bool(Progress.get_var("CASE_NAMWON_COMPLETE", false))

func open() -> void:
	if is_joiner(): await join(); return
	await op00()

# 건너뛸 수 있는 기다림(Esc·Space·Enter — onboarding.skip). 건너뛰었으면 true
func _sw(sec: float) -> bool:
	var ob = d.onboard
	if ob == null: await d.wait(sec); return false
	if d.ui.auto and not d.ui.auto_real: sec = minf(sec, 0.05)
	var t := 0.0
	while t < sec:
		if ob.skip: return true
		await d.get_tree().process_frame
		t += d.get_process_delta_time() / maxf(Engine.time_scale, 0.01)
	return ob.skip

func _cam(spec, sec: float) -> void:
	d.camera(spec)
	d.main.rig.glide(sec)

func _mid(a: String, b: String) -> Array:
	var p: Vector2 = d.anchor(a); var q: Vector2 = d.anchor(b)
	return [(p.x + q.x) * 0.5, (p.y + q.y) * 0.5]

# OP00 — 검은 화면 → 담 와이드 → 책상 쪽으로 낮게 → 등 뒤 기본 시점. 9초에 조작(D7 12초 안). 건너뛰면 0.25초 페이드 뒤 필드
func op00() -> void:
	var ob = d.onboard
	var t0 := _now()
	if ob != null: ob.skippable = true; ob.skip = false
	S.phase = "home"; d.on_phase()
	d.set_hour(9.5); d.set_weather("clear")
	d.teleport_to("home_start", "up")
	d.give("ITM_TOOL_009", 1, true); d.give(D.COIN, 12, true)
	flag("START_AT_IEGYEOM_HOME")
	d.ui._fade.color.a = 1.0
	d.cutscene(true)
	_cam({ "focus": "home_wide", "distance": 24.0, "pitch": 30.0, "fov": 34.0 }, 0.01)
	d.main.rig.update(0, d.main.player_pos, d.main.player.facing, null, true)
	d.main.player.play("idle", true)
	d.sfx("laugh_far", "street")   # 골목 생활 소리(0–2초 암전)
	_log("op00_black")
	var skipped := await _sw(2.0)
	if not skipped:
		d.ui.fade(false, 0.6)
		_log("op00_wide")
		d.ui.caption("이겸  “본 것은 본 대로. 들은 것은 누가 말했는지.”", 3.0)   # 첫15 OP00 이겸 VO
		skipped = await _sw(3.0)
	if not skipped:
		_log("op00_push")
		_cam({ "focus": _mid("home_start", "desk"), "distance": 8.5, "pitch": 34.0, "fov": 34.0 }, 4.0)   # 인물-책상 가운데(기록책이 아니라)
		await _sw(0.6)
		if not ob.skip: d.ui.caption("나그네  “스승님은 어디로 가신 걸까.”", 3.0)
		skipped = await _sw(3.4)
	if skipped:
		op00_skipped = true
		await d.ui.fade(true, 0.08)
		d.camera(null)
		d.main.rig.update(0, d.main.player_pos, d.main.player.facing, null, true)
		d.ui.caption("", 0.01)
		d.ui.fade(false, 0.25)   # 건너뛰면 0.25초 페이드 뒤 필드(첫15 OP00)
	else:
		d.camera(null)
		d.main.rig.glide(0.6)    # 9–9.6초 등 뒤 기본 시점으로 0.6초 블렌드 — 그동안에도 걸을 수 있다
	d.cutscene(false)
	if ob != null: ob.skippable = false; ob.skip = false
	flag("OP00_DONE")
	var base: float = float(TitleMenu.new_game_t0) / 1000.0 if TitleMenu.new_game_t0 > 0 else t0
	control_t = _now() - base
	printerr("FIRST15 control %.2f s (op00 %.2f s, skipped=%s)" % [control_t, _now() - t0, op00_skipped])
	_log("op00_control")
	Progress.checkpoint("새 게임")   # 첫 조작권 반환 즉시 체크포인트(첫15 OP00)
	d.ui.caption("이겸의 방을 살펴보자", 3.0)   # 목표 문구 3초(첫15 OP00) — 뒤로는 기록책 '아직 모르는 것'에 남는다

# 옛 저장 합류(오누이를 지난 저장이 처음 이 사건을 만남) — 여는 장면 없이 지금 자리에서. 거처가 지도에 있다
func join() -> void:
	S.phase = "home"; d.on_phase()
	d.give("ITM_TOOL_009", 1, true)
	flag("JOINED"); flag("OP00_DONE")
	d.sfx("journal_stamp")
	d.ui.toast("새 사건 — 「%s」" % d.data.case.record_title, "journal")
	await d.ui.caption("남원 읍내 이겸의 거처에 들러 보자.", 3.0)   # 신규 문구(합류)
	_log("join")

# ---------------------------------------------------------------------------
# P00-A 방 물건 · 문 두드림 · P00-B 짧은 기억
# ---------------------------------------------------------------------------
const ROOM_TEXT := {
	"ledger": ["밥값 장부", ["“국 두 그릇. 제자 몫은 내가 냄… 아니다, 둘 다 내가 냄.”"], "글씨는 늘 이렇게 고치셨지."],
	"shoes": ["다시 기운 신발", ["뒤축을 또 기웠다."], "걷는 데 문제없다더니, 다시 기우셨네."],
	"brush": ["말려 둔 붓", ["창가에 붓 셋을 말려 두었다. 하나는 끝이 갈라졌다."], "새 붓을 사 드려도 이것만 쓰셨지."],   # 붓 — 신규 대사
}

func inspect_room(kind: String) -> void:
	var t: Array = ROOM_TEXT[kind]
	_cam({ "focus": kind, "distance": 6.5, "pitch": 50.0 }, OBJ_IN)
	await d.wait(OBJ_IN)
	d.sfx("page_turn" if kind == "ledger" else "brush_rustle")
	await d.ui.examine(String(t[0]), t[1], "clue")
	await d.ui.say("나그네", [String(t[2])])
	d.learn_clue(kind)
	_cam(null, OBJ_IN)
	var n := room_seen()
	_log("inspect_" + kind)
	if n == 1:
		flag("P00_ITEM_SEEN")
		if d.onboard != null: d.onboard.on_first_record()   # R 기록책 — 기록 한 장을 얻었을 때만(첫15 P00-A)
		if not f("KNOCKED"): _knock_t = KNOCK_AFTER
	if n == ROOM.size() and not f("FLASHBACK_SEEN"):
		await d.wait(OBJ_IN)
		await flashback()

# P00-B — 회상 첫 컷 2.0 · 이겸 손동작 3.0 · 필드 0.5(9초 이하, 건너뛰기). 색감만 옅게. 방문자 도착 조건은 바뀌지 않는다
func flashback() -> void:
	flag("FLASHBACK_SEEN")
	_log("flashback")
	var ob = d.onboard
	if ob != null: ob.skippable = true; ob.skip = false
	d.cutscene(true)
	var post = d.main.get("post")
	if post != null: post.past = 0.45
	var dp: Vector2 = d.anchor("desk")
	d.spawn_actor("yigyeom_past", "yigyeom", [dp.x + 0.15, dp.y + 0.75], "up", "이겸", "")
	_cam({ "focus": _mid("home_start", "desk"), "distance": 7.5, "pitch": 36.0 }, 0.5)
	var sk := await _sw(2.0)
	if not sk:
		d.ui.caption("이겸  “기억은 틀릴 수 있다. 그러니 틀린 자리를 다시 찾을 수 있게 적어라.”", 3.2)
		d.face_actor("yigyeom_past", "down", null)
		sk = await _sw(3.0)
	if not sk:
		d.ui.caption("나그네  “그러니까 장부를 몇 번씩 고쳐 쓰시는군요.”", 2.4)
		sk = await _sw(2.4)
	d.despawn_actor("yigyeom_past")
	if post != null: post.past = 0.0
	_cam(null, 0.5)
	d.cutscene(false)
	if ob != null: ob.skippable = false; ob.skip = false
	if not f("KNOCKED"): _knock_t = 0.5   # 끝나면 문 쪽 소리 1회(첫15 P00-B)

func knock() -> void:
	if f("KNOCKED"): return
	flag("KNOCKED")
	_log("knock")
	d.sfx("knock", "yard_front")
	d.ui.caption("마당에서 문 두드리는 소리. “거기 계십니까? 이겸 어른 댁 맞소?”", 3.0)   # 메인 대본 P00-A
	d.mark_dirty()

# ---------------------------------------------------------------------------
# P01-A 문턱의 봉투 · P01-B 견주기
# ---------------------------------------------------------------------------
func read_letter() -> void:
	_cam({ "focus": "threshold", "distance": 6.0, "pitch": 54.0 }, LETTER_IN)
	await d.wait(LETTER_IN)
	d.sfx("page_turn")
	await d.ui.examine("편지", ["앞면에 스승의 이름. 늘 쓰던 날짜도 표시도 없다. 밀봉은 평범한 풀이다.",
		"“나는 며칠 떠나 신선의 가르침을 구하겠노라. 걱정하지 말고 기다려라.", "이 산의 일은 모두 내 뜻이니 남에게 책임을 묻지 말라. — 이겸”"], "item")
	flag("LETTER_RECEIVED")   # 대화를 넘겨도 편지는 남는다(첫15 P01-A)
	d.give(D.LETTER, 1)
	d.learn_clue("letter")
	_cam(null, LETTER_IN)
	_log("letter")
	await d.ui.caption("서안의 옛 기록과 견주어 보자.", 2.6)   # 신규 문구(목표)

func compare_letter() -> void:
	_cam({ "focus": "desk", "distance": 5.5, "pitch": 58.0 }, OBJ_IN)
	await d.wait(OBJ_IN)
	_log("compare_open")
	var r: Dictionary = await Docs.open(d, { "docs": ["old_record", "letter"], "title": "옛 기록과 편지",
		"note": "날짜·방향·목격자를 적던 분인데.", "hint_after": 60.0, "hint_text": "날짜와 목적을 먼저 대조해 보자." })
	_cam(null, OBJ_IN)
	var pairs := 0
	for c in ["cmp_date", "cmp_way", "cmp_blame"]:
		if S.has_clue(c): pairs += 1
	_log("compare_close_%d" % pairs)
	if pairs < 2:
		await d.ui.caption("아직 두 군데를 다 견주지 못했다. 서안에서 다시 이어 볼 수 있다.", 2.6)   # 신규 문구 — ESC로 닫아도 이어 한다
		return
	flag("LETTER_COMPARE_2")
	await d.runner.exec([{ "choice": "", "options": [
		{ "label": "글씨가 비슷해도 내용이 다르다.", "do": [] },
		{ "label": "대신 쓴 이가 있나?", "do": [] },
		{ "label": "확인은 필요해.", "do": [] }] }], d.runner.gen)
	await d.ui.say("나그네", ["직접 확인해야 한다."])   # 메인 대본 P01-B '모두 직접 확인해야 한다로 귀결'
	d.learn_clue("suspicious")   # 추정(△) — 확정 위조로 기록하지 않는다
	flag("LETTER_SUSPICIOUS")
	S.phase = "town"; d.on_phase()
	if f("FLASHBACK_SEEN"): d.ui.caption("이겸  “틀린 자리를 다시 찾을 수 있지.”", 2.2)   # 메인 대본 P01-B 연출
	await d.wait(0.2)
	if d.onboard != null: d.onboard.step({ "discover": "solip_jumak" })
	Progress.checkpoint("편지를 의심했다")
	_log("suspicious")
	await d.ui.caption("솔잎 주막을 찾아가자 — 광한루 앞 나루 길가.", 3.0)   # 신규 문구(목표)

# ---------------------------------------------------------------------------
# OP01 거처 밖 4m — 「설화록」(재기획 OP-04 시간, 첫15 시점·조작 유지). 이야기 줄(runner)이 아니라 따로 돈다 — 이동을 막지 않는다
# ---------------------------------------------------------------------------
func _outside_home() -> bool:
	var p := Vector2(d.main.player_pos.x, d.main.player_pos.z)
	var front: Vector2 = d.anchor("yard_front")
	if d.world.interior_at(p.x, p.y) != null: return false
	var in_yard := absf(p.x - D.HX) < 4.2 and p.y < front.y and p.y > D.HZ - 3.5
	return not in_yard and p.distance_to(front) >= TITLE_OUT_M

func title_walk() -> void:
	title_running = true
	flag("TITLE_IN_WORLD_SEEN")   # 한 번만(첫15 OP01 — 영상 반복 방지)
	var ob = d.onboard
	if ob != null: ob.skippable = true; ob.skip = false
	d.hush_hints = true   # 제목 동안 조작 안내는 멈춘다(이동 잠금은 없다)
	var t0 := _now()
	title_t = [["start", 0.0]]
	_log("title_start")
	_cam({ "pitch": 50.0, "distance": 30.0, "fov": 34.0 }, 2.0)   # 0–2.0 길목 와이드(카메라 상승)
	d.ui.caption("나그네  “사라진 길을 따라가야겠다.”", 2.4)        # 선택형 독백
	var sk := await _sw(2.0)
	if not sk:
		title_t.append(["reframe", _now() - t0])
		_cam({ "pitch": 44.0, "distance": 40.0, "fov": 36.0 }, 2.5)   # 2.0–4.5 성벽·거리 리프레이밍
		sk = await _sw(2.5)
	if not sk:
		title_t.append(["title_in", _now() - t0])
		d.ui.title_card("설화록", 5.0, 133, 0.8, 1.0)   # 4.5–8.5 등장(4초) · 8.5–9.5 사라짐(1초)
		sk = await _sw(4.0)
	if not sk:
		title_t.append(["title_out", _now() - t0])
		_cam(null, 1.0)                                  # 8.5–9.5 카메라만 돌아온다
		sk = await _sw(1.0)
	if sk:
		d.ui.title_card_stop()
		_cam(null, 0.4)
	title_t.append(["end", _now() - t0])
	d.hush_hints = false
	if ob != null: ob.skippable = false; ob.skip = false
	title_running = false
	printerr("FIRST15 title %s skipped=%s" % [JSON.stringify(title_t), sk])
	_log("title_end")

# ---------------------------------------------------------------------------
# P02 솔잎 주막 · 지도 목적지
# ---------------------------------------------------------------------------
func tavern_ledger() -> void:
	_cam({ "focus": "solip_ledger", "distance": 6.0, "pitch": 46.0 }, OBJ_IN)
	await d.wait(OBJ_IN)
	d.sfx("page_turn")
	await d.ui.examine("숙박 장부", ["묵은 숙박 장부. 며칠 전 줄에 ‘이겸 — 하룻밤’.", "국값 줄을 고쳐 쓴 글씨가 스승의 것이다."], "clue")   # 신규 문구(첫15 '확인된 숙박 사실')
	d.learn_clue("tv_last")
	_cam(null, OBJ_IN)
	await tavern_clue()

# 장부 또는 손님 증언 — 지도 목적지 후보 '여원재 방면'(첫15 P02-B · KNOWN_NOT_VISITED)
func tavern_clue() -> void:
	if f("TAVERN_CLUE"): return
	flag("TAVERN_CLUE")
	_log("tavern_clue")
	if d.onboard != null:
		d.onboard.step({ "discover": "yeowon" })   # 지도에 '여원재 방면'(들음) → M 지도 안내(실제로 열어야 끝)
		d.onboard.on_waypoint_lead()               # → 목적지 설정 안내(실제로 정해야 끝)
	Progress.checkpoint("행선지를 들었다")
	await d.ui.caption("지도에 ‘여원재 방면’이 적혔다.", 2.4)   # 신규 문구

# 지도에서 목적지를 정했다(region_map → story_director.on_waypoint). 미방문이면 경로 안내만 — 순간이동하지 않는다
func on_waypoint(w: Dictionary) -> void:
	var key := String(w.get("key", ""))
	_log("waypoint_" + key)
	printerr("FIRST15 waypoint %s" % JSON.stringify(w))
	if key.ends_with("mp_yeowon") and not f("WAYPOINT_SET"):
		flag("WAYPOINT_SET"); flag("WAYPOINT_SELECTED")
		if d.onboard != null: d.onboard.observe("여원재", "확인된 것은 이겸의 마지막 숙박. 고갯길 소문은 아직 전해 들은 말.")   # 첫15 P02-C 기록
		d.ui.toast("목적지를 표시했다. 직접 가거나 역마를 이용할 수 있다.", "info")   # 첫15 P02-C 시스템 문구
		S.phase = "road"; d.on_phase()
		Progress.checkpoint("목적지를 정했다")
		d.save()

# 북문 밖 행상 → 오누이(D1). 이 대화가 끝난 뒤 사건을 바꾼다(지금 줄이 다 끝난 프레임 끝)
func enter_onui() -> void:
	_log("enter_onui")
	d.save()
	d.switch_case.call_deferred("namwon", { "event": "N0000" })

# ---------------------------------------------------------------------------
# 프레임(story_director._update_ambient) · 음악 · 이어 하기
# ---------------------------------------------------------------------------
func ambient(dt: float) -> void:
	var busy: bool = d.runner.busy or d.ui.modal or d.talking or d._cut or d.ui.journal_open
	if _knock_t >= 0.0 and not busy:
		var far := Vector2(d.main.player_pos.x, d.main.player_pos.z).distance_to(d.anchor("home_center")) > KNOCK_NEAR
		if not far: _knock_t -= dt
		if _knock_t <= 0.0:
			_knock_t = -1.0
			knock()
	if f("LETTER_SUSPICIOUS") and not f("TITLE_IN_WORLD_SEEN") and not title_running and not busy and _outside_home():
		title_walk()
	if f("TAVERN_CLUE") and not f("M_OPEN_SEEN"):
		var m = d.main.get("_map")
		if m != null and m.visible:
			flag("M_OPEN_SEEN"); flag("MAP_FIRST_OPEN"); _log("map_open")

func music_wanted() -> String:
	if S.phase == "start" or not f("OP00_DONE"): return ""
	var h: float = d.main.hour
	return "bgm_day_calm" if h >= 5.5 and h < 18.0 else ""

func on_load() -> void:
	# 여는 장면·제목·짧은 기억 도중 저장 — 본 것으로 넘긴다(다시 돌지 않는다)
	if S.phase != "start" and not f("OP00_DONE"):
		S.flags["OP00_DONE"] = true
	if f("P00_ITEM_SEEN") and not f("KNOCKED"): _knock_t = 1.0   # 첫 조사 뒤 문 두드림 전 저장 — 곧 두드린다
	if f("LETTER_SUSPICIOUS") and S.phase == "home": S.phase = "town"
	if f("WAYPOINT_SET") and S.phase != "done": S.phase = "road"
