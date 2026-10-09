# 처음 하는 사람 안내 규칙(scripts/story/onboarding.gd) 시험 — 헤드리스, 가짜 이야기 총괄로 안내 줄만 돌린다.
#   godot --headless --path . -s res://tests/onboarding/onboarding_rule_test.gd
#   A 핵심 안내는 시간이 다 돼도 SEEN이 아니고 계속 보인다 → 행동(seen_now·until)하면 SEEN
#   B 정보 안내는 제 시간 다 보이면 SEEN, 대화창이 뜬 동안은 감추고 그 시간은 세지 않는다
#   C 정보 안내가 다 보이기 전에 장면이 닫히면 MIN_SHOWN초 넘게 보였을 때만 SEEN
#   D 핵심 안내는 기다리는 안내에 자리를 내줬다가(SEEN 아님) 다시 뜬다
#   E 저장 → 다시 불러오기(이어 하기) 뒤에도 기다리던 핵심 안내가 다시 뜨고, 행동하면 SEEN이 저장된다
#   F hold()는 CORE 밖 key도 행동까지 남긴다 · 안내 끔이면 아무것도 안 뜬다
#   G 남원 v3.2 §4: 이동은 실제로 5m 넘게 걸어야(순간이동 제외), 달리기는 실제로 2초 넘게 달려야 끝 · 이동이 끝나면 달리기 안내
#   저장은 따로(user://st_onboard_rule.json, 끝나면 지운다). 끝 줄: ONBOARDRULE PASS n / ONBOARDRULE FAIL n
extends SceneTree

const Progress := preload("res://scripts/region/progress.gd")
const GameSettings := preload("res://scripts/story/game_settings.gd")
const Onboarding := preload("res://scripts/story/onboarding.gd")
const SAVE := "user://st_onboard_rule.json"

class FakeUI extends RefCounted:
	var modal := false
	var journal_open := false
	var on_journal_page: Callable = Callable()
	var text := ""
	func hint(t: String) -> void: text = t
	func hint_clear() -> void: text = ""

class FakeDirector extends RefCounted:
	var ui := FakeUI.new()
	var runner = null
	var combat_view = null
	var free_move := false
	var _cut := false
	var log_story := false

var n := 0
var fails := 0
var _made: Array = []

func ok(c: bool, what: String) -> void:
	n += 1
	if c: print("  ok  ", what)
	else:
		fails += 1
		print("  FAIL ", what)

func _fresh() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	Progress.use_path(SAVE)
	Progress.reset_all()

func _make():
	var d := FakeDirector.new()
	var ob = Onboarding.new(d)
	ob._ready()   # 나무에 올리지 않는다(_process는 region 장면을 본다) — 안내 줄만 손으로 돌린다
	_made.append(ob)
	return ob

func _run_for(ob, sec: float, step := 0.1) -> void:
	var t := 0.0
	while t < sec - 0.0001:
		ob._update_hints(step)
		t += step

func _pending() -> Dictionary:
	var p = Progress.onboard(Onboarding.PENDING, {})
	return p if p is Dictionary else {}

func _initialize() -> void:
	GameSettings.test_override = { guide = "early", help = "normal" }
	_fresh()
	_test_a()
	_fresh()
	_test_b()
	_fresh()
	_test_c()
	_fresh()
	_test_d()
	_fresh()
	_test_e()
	_fresh()
	_test_f()
	_fresh()
	_test_g()
	GameSettings.test_override = {}
	for o in _made: o.free()
	_made.clear()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	Progress.use_path("")
	print("ONBOARDRULE %s %d" % ["PASS" if fails == 0 else "FAIL", n if fails == 0 else fails])
	quit(0 if fails == 0 else 1)

# A 핵심 안내: 시간으로 끝나지 않는다
func _test_a() -> void:
	var ob = _make()
	ok(Onboarding.is_core("MOVE") and Onboarding.is_core("TALK") and Onboarding.is_core("JOURNAL") and Onboarding.is_core("MAP"), "MOVE·TALK·JOURNAL·MAP은 핵심")
	ob.once("TALK", "사람에게 다가가 E — 말을 건다", Callable(), 1.0)
	_run_for(ob, 0.2)
	ok(ob.d.ui.text.contains("말을 건다"), "핵심 안내가 뜬다")
	_run_for(ob, 10.0)
	ok(not ob.is_seen("TALK"), "제 시간(1초)의 10배가 지나도 SEEN 아님")
	ok(ob.hint_key() == "TALK" and ob.d.ui.text.contains("말을 건다"), "그대로 보인다")
	ok(_pending().has("TALK"), "기다리는 핵심 안내로 남는다(ONBOARD_PENDING)")
	ob.seen_now("TALK")   # 실제로 말을 걸었다(on_interact)
	ok(ob.is_seen("TALK") and ob.hint_key() == "" and ob.d.ui.text == "", "행동하면 SEEN, 안내가 사라진다")
	ok(not _pending().has("TALK"), "기다림 목록에서 빠진다")
	# until 조건으로 끝나는 핵심 안내(이동)
	var moved := [false]
	ob.once("MOVE", "W A S D   이동", func(): return moved[0], 1.0)
	_run_for(ob, 5.0)
	ok(not ob.is_seen("MOVE") and ob.hint_key() == "MOVE", "이동 안내도 시간으로 끝나지 않는다")
	moved[0] = true
	_run_for(ob, 0.1)
	ok(ob.is_seen("MOVE") and ob.hint_key() == "", "움직이면(until) SEEN")
	ok(bool(Progress.data().onboard.get("ONBOARD_MOVE_SEEN", false)), "SEEN이 저장 데이터에")
	# 대화창이 떠도 핵심 안내는 SEEN이 되지 않고, 닫히면 다시 보인다
	ob.once("JOURNAL", "R   기록책", Callable(), 1.0)
	_run_for(ob, 0.3)
	ob.d.ui.modal = true
	_run_for(ob, 3.0)
	ok(ob.d.ui.text == "" and not ob.is_seen("JOURNAL"), "대화 중엔 감춤(SEEN 아님)")
	ob.d.ui.modal = false
	_run_for(ob, 0.1)
	ok(ob.d.ui.text.contains("기록책"), "대화가 끝나면 다시 보인다")

# B 정보 안내: 제 시간 보이면 SEEN(감춘 시간은 세지 않는다)
func _test_b() -> void:
	var ob = _make()
	ok(not Onboarding.is_core("RIDE"), "RIDE는 정보 안내")
	ob.once("RIDE", "말이 큰길을 따라 저절로 간다", Callable(), 2.0)
	_run_for(ob, 0.5)
	ob.d.ui.modal = true
	_run_for(ob, 5.0)
	ok(not ob.is_seen("RIDE") and ob.d.ui.text == "", "대화 중엔 감추고 시간을 세지 않는다")
	ob.d.ui.modal = false
	_run_for(ob, 1.0)
	ok(not ob.is_seen("RIDE") and ob.d.ui.text.contains("말이"), "다시 보인다(1.5초 보임 < 2초)")
	_run_for(ob, 0.7)
	ok(ob.is_seen("RIDE") and ob.d.ui.text == "", "제 시간 다 보이면 SEEN")
	ok(not _pending().has("RIDE"), "정보 안내는 기다림 목록에 남지 않는다")

# C 정보 안내가 끊김: MIN_SHOWN 넘게 보였을 때만 SEEN
func _test_c() -> void:
	var ob = _make()
	ob.once("KNOT", "감응 매듭", Callable(), 9.0)
	_run_for(ob, 1.0)
	ob._exit_tree()   # 장면이 닫힘
	ok(not ob.is_seen("KNOT"), "%.1f초 미만 보이고 끊기면 SEEN 아님" % Onboarding.MIN_SHOWN)
	var ob2 = _make()
	ob2.once("KNOT", "감응 매듭", Callable(), 9.0)
	_run_for(ob2, Onboarding.MIN_SHOWN + 0.5)
	ob2._exit_tree()
	ok(ob2.is_seen("KNOT"), "%.1f초 넘게 보였으면 SEEN" % Onboarding.MIN_SHOWN)

# D 핵심 안내는 기다리는 안내에 자리를 내준다(SEEN 아님) → 다시 뜬다
func _test_d() -> void:
	var ob = _make()
	ob.once("JOURNAL", "R   기록책", Callable(), 1.0)
	_run_for(ob, 0.3)
	ob.once("KNOT", "감응 매듭", Callable(), 1.0)
	_run_for(ob, 0.5)
	ok(ob.hint_key() == "JOURNAL", "제 시간 전에는 핵심 안내가 그대로")
	_run_for(ob, 0.6)
	ok(ob.hint_key() == "KNOT" and not ob.is_seen("JOURNAL"), "제 시간 뒤 기다리던 안내에 자리를 내줌(JOURNAL SEEN 아님)")
	_run_for(ob, 1.5)
	ok(ob.is_seen("KNOT") and ob.hint_key() == "JOURNAL", "정보 안내가 끝나면 핵심 안내가 다시 뜬다")
	_run_for(ob, 20.0)
	ok(ob.hint_key() == "JOURNAL" and not ob.is_seen("JOURNAL"), "기다리는 것이 없으면 계속 남는다")

# E 저장·이어 하기
func _test_e() -> void:
	var ob = _make()
	ob.once("JOURNAL", "R   기록책", func(): return ob.d.ui.journal_open, 10.0)
	_run_for(ob, 12.0)
	ok(not ob.is_seen("JOURNAL"), "저장 전: JOURNAL 아직")
	Progress.save()
	Progress.use_path(SAVE)   # 읽어 둔 것을 버리고 파일에서 다시(이어 하기)
	ok(_pending().has("JOURNAL") and not bool(Progress.onboard("ONBOARD_JOURNAL_SEEN", false)), "저장 파일: 기다림 JOURNAL, SEEN 아님")
	var ob2 = _make()
	_run_for(ob2, 0.2)
	ok(ob2.hint_key() == "JOURNAL" and ob2.d.ui.text.contains("기록책"), "이어 하기 뒤 기다리던 핵심 안내가 다시 뜬다")
	_run_for(ob2, 30.0)
	ok(not ob2.is_seen("JOURNAL"), "이어 한 뒤에도 시간으로 끝나지 않는다")
	ob2.d.ui.journal_open = true   # 기록책을 연다
	_run_for(ob2, 0.1)
	ok(ob2.is_seen("JOURNAL"), "기록책을 열면 SEEN")
	Progress.use_path(SAVE)
	ok(bool(Progress.onboard("ONBOARD_JOURNAL_SEEN", false)) and not _pending().has("JOURNAL"), "SEEN이 저장 파일에 남고 기다림에서 빠짐")
	var ob3 = _make()
	_run_for(ob3, 0.5)
	ok(ob3.hint_key() == "" and ob3.d.ui.text == "", "그다음 이어 하기에는 다시 안 뜬다")
	# 정보 안내는 보이자마자 SEEN으로 저장되지 않는다(예전 동작: 보이면 바로 SEEN)
	ob3.once("RIDE", "말", Callable(), 9.0)
	_run_for(ob3, 0.5)
	Progress.save()
	Progress.use_path(SAVE)
	ok(not bool(Progress.onboard("ONBOARD_RIDE_SEEN", false)), "막 뜬 정보 안내는 SEEN으로 저장되지 않는다")

# F hold · 안내 끔
func _test_f() -> void:
	var ob = _make()
	ob.hold("STATION", "H   역마", Callable(), 1.0)
	_run_for(ob, 10.0)
	ok(ob.hint_key() == "STATION" and not ob.is_seen("STATION") and _pending().has("STATION"), "hold(): CORE 밖 key도 행동까지 남는다")
	ob.seen_now("STATION")
	ok(ob.is_seen("STATION") and ob.hint_key() == "", "hold() 안내도 행동하면 SEEN")
	ob.once("INFO_X", "정보", Callable(), 1.0)
	ob.seen_now("INFO_X")
	_run_for(ob, 0.5)
	ok(ob.hint_key() == "", "줄에서 기다리던 안내도 seen_now로 거둔다")
	GameSettings.test_override = { guide = "off", help = "normal" }
	var ob2 = _make()
	ob2.once("MAP", "M   지도", Callable(), 1.0)
	_run_for(ob2, 1.0)
	ok(ob2.hint_key() == "" and not _pending().has("MAP"), "안내 끔이면 뜨지 않는다")
	GameSettings.test_override = { guide = "early", help = "normal" }

# G 이동·달리기(track_move — onboarding._update_move가 프레임마다 부른다)
func _test_g() -> void:
	var ob = _make()
	for i in 4: ob.track_move(1.0, false, 0.1)
	ok(not ob.is_seen("MOVE"), "4m 걸어서는 이동 안내가 안 끝난다")
	ob.track_move(6.0, false, 0.1)
	ok(not ob.is_seen("MOVE") and is_equal_approx(ob.moved_m, 4.0), "순간이동(한 번에 6m)은 세지 않는다")
	ob.track_move(1.2, false, 0.1)
	ok(ob.is_seen("MOVE"), "5m 넘게 걸으면 이동 안내가 끝난다")
	_run_for(ob, 0.2)
	ok(ob.hint_key() == "RUN" and Onboarding.is_core("RUN"), "이어서 달리기 안내(핵심)")
	for i in 8: ob.track_move(1.0, false, 0.5)
	ok(not ob.is_seen("RUN"), "걷기만 4초 — 달리기 안내는 남는다")
	_run_for(ob, 20.0)
	ok(not ob.is_seen("RUN") and ob.hint_key() == "RUN", "시간이 지나도 달리기 안내는 남는다")
	for i in 3: ob.track_move(2.0, true, 0.5)
	ok(not ob.is_seen("RUN"), "1.5초 달려서는 아직")
	ob.track_move(2.0, true, 0.5)
	ok(ob.is_seen("RUN") and ob.hint_key() == "", "2초 달리면 달리기 안내가 끝난다")
