# 대본 시험(--storytest=pyongyang:A|B|C) — 「강을 판 사내」를 한 결말로 끝까지 몰아 본다(ACT 2를 다 끝낸 저장, test_post_act2.json).
#   godot --path seolhwa_godot res://scenes/region.tscn -- --region=PA_PYEONGYANG --storytest=pyongyang:A
#   A: 짐승 흔적 읽기가 있는 저장 — 문서를 견주고, 종이 마당에서 사기꾼을 붙잡고(싸움), 감정으로 덧쓴 먹·겹친 도장을 짚는다.
#      한양 통행문서도 감정한다. 끝에 큰 짐승 흘리기(SKILL_BEAST_SIDESTEP)가 풀린다.
#   B: 짐승 흔적 읽기·통행문서 없는 저장 — 사기꾼을 보내 준다(달아남). 숙련은 풀리지 않는다. 낮에 부벽루에 가서 달을 기다린다.
#   C: 싸우다 물러난다(escaped → 달아남). 감정 전(감정법 없이)에는 고친 자리가 짚이지 않는지, 감정 첫 번째엔 하나도 못 짚고
#      서리의 힌트를 들은 뒤 다시 짚는지 본다(고친 날짜·바꾼 종이).
#   PROBE: 앵커 높이·막힘만 찍는다. --storyshots=폴더면 장면마다 찍는다(창이 있을 때). 끝에 STORYTEST PASS/FAIL.
extends "res://scripts/story/story_test.gd"

const Progress := preload("res://scripts/region/progress.gd")
const Rumors := preload("res://story/rumors_data.gd")
const Discovery := preload("res://scripts/region/discovery.gd")
const D := preload("res://story/pyongyang/pyongyang_data.gd")
const Docs := preload("res://scripts/story/documents.gd")
const FIXTURE := "res://story/pyongyang/test_post_act2.json"

var _fps_min := 1000.0
var _fps_sum := 0.0
var _fps_n := 0
var _doc_n := {}
var _bow_hold := 0.0

static func prepare(dir) -> void:
	var j = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	if not (j is Dictionary): push_error("시험 출발 저장을 읽지 못함: " + FIXTURE); return
	var br := String(dir.main.args.get("storytest", "pyongyang:A")).get_slice(":", 1).to_upper()
	var p := Progress.data()
	p.vars = j.get("vars", {}).duplicate(true)
	p.cases = j.get("cases", {}).duplicate(true)
	p.routes_done = j.get("routes_done", {}).duplicate(true)
	p["onboard"] = {}   # 처음 한 번 안내(문서 감정 DOC_EXAM·DOC_SKILL)를 다시 본다
	if br == "B":
		p.vars.SKILL_BEAST_TRACE = false
		p.cases.hanyang.items = {}
	Progress.save()

func _log(s: String) -> void:
	printerr("STORYTEST [%s] %6.1fs %s" % [branch, (Time.get_ticks_msec() - _t0) / 1000.0, s])

func go(id: String) -> void:
	await _idle()
	var p := Vector2.INF
	if d.actors.has(id): p = Vector2(d.actors[id].pos.x, d.actors[id].pos.z)
	else:
		for o in d.data.get("objects", []):
			if String(o.id) == id: p = d.anchor(o.at)
	if p == Vector2.INF: p = d.anchor(id)
	d.teleport_to(Vector2(p.x, p.y + 0.6), "up")
	await _frames(8)
	await _idle()
	d._refresh()
	var ok := false
	for t in d._targets():
		if t.id == id: ok = true
	if not ok:
		_fail("대상 없음/조건 안 맞음: " + id + " (자리 %.1f,%.1f 플레이어 %.1f,%.1f)" % [p.x, p.y, d.main.player_pos.x, d.main.player_pos.z])
		return
	_log("interact " + id)
	d.interact(id)
	await _frames(2)
	await _idle()

func _until(cond: Callable, limit_s: float, what: String) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(limit_s * 1000.0):
		if cond.call(): return true
		await get_tree().process_frame
	_fail("시간 초과: " + what)
	return false

func _watch_fps() -> void:
	for i in 400000:
		await get_tree().create_timer(0.5, true, false, true).timeout
		if not is_inside_tree(): return
		if d.main._loading or d.runner.busy: continue
		var f := Engine.get_frames_per_second()
		if f > 0: _fps_min = minf(_fps_min, f); _fps_sum += f; _fps_n += 1

func found(key: String) -> bool:
	return Docs.found_list(d.S).has(key)

# ---------------------------------------------------------------------------
# 문서 화면(scripts/story/documents.gd)을 시험이 짚는다 — 사람처럼 그 자리를 짚는 것과 같은 길(exam.mark)
# ---------------------------------------------------------------------------
func doc_exam(ex) -> void:
	await _frames(3)
	var key := ",".join(ex.ids)
	var nk: String = key + ("+감정" if ex.skill else "")   # 감정법을 익힌 뒤 몇 번째로 연 것인가
	_doc_n[nk] = int(_doc_n.get(nk, 0)) + 1
	var n: int = _doc_n[nk]
	_log("문서 화면 %s #%d skill=%s" % [key, n, ex.skill])
	await shot("doc_%s%s_%d" % [key.replace(",", "_"), "_skill" if ex.skill else "", n], 6)
	match key:
		"deed_a,deed_b":
			if not ex.skill:
				# 눈으로: 종이·먹·도장. 감정법이 없으면 고친 날짜 자리를 짚어도 고친 날짜로는 짚이지 않는다
				ex.mark_at("deed_a", Vector2(0.302, 0.5))
				ex.mark_at("deed_b", Vector2(0.05, 0.95))
				for s in [["deed_a", "a_ink"], ["deed_b", "b_ink"], ["deed_a", "a_seal"], ["deed_b", "b_seal"]]: ex.mark_spot(s[0], s[1])
				ex.mark_at("deed_a", Vector2(0.95, 0.95))
				expect(not found("deed_a/a_date") and not found("deed_a/a_over") and not found("deed_b/b_patch"), "감정법 없이는 고친 자리가 짚이지 않음")
			elif branch == "C" and n == 1:
				ex.mark_at("deed_a", Vector2(0.9, 0.95))   # 아무것도 아닌 데만
			elif branch == "C":
				ex.mark_spot("deed_a", "a_date"); ex.mark_spot("deed_b", "b_patch")
			else:
				ex.mark_spot("deed_a", "a_over"); ex.mark_spot("deed_b", "b_seal2")
		"grain_ledger":
			ex.mark_spot("grain_ledger", "ledger_park"); ex.mark_spot("grain_ledger", "ledger_qty")
		"pass_doc":
			ex.mark_spot("pass_doc", "pass_order")
	await _frames(2)
	_log("짚은 것 %s" % [ex.found_now])
	ex.close()

# ---------------------------------------------------------------------------
func _run() -> void:
	_log("시작 branch=%s space=%s" % [branch, d.space_id])
	_watch_fps()
	await _until(func(): return not d.main._loading, 90.0, "불러오기")
	if branch == "PROBE": await _probe(); return
	expect(d.case_id == "pyongyang" and d.space_id == D.RG, "평양 사건이 섰다(ACT3_OPEN)")
	# S5001 — 중화길 남쪽 끝(노정 포털)에서 온 것처럼: 먼 도착 → 대동문 앞 나루
	d.teleport_to([778.0, 2000.0], "up")
	await _frames(10)
	await d.runner.run([{ "event": "S5001" }])
	expect(d.S.is_flag("case_started") and d.S.has_clue("two_deeds") and d.S.has_clue("woochi_blamed"), "S5001 나루 다툼 — 두 문서(확인) · 우치 짓이라는 말(들음)")
	expect(Vector2(d.main.player_pos.x, d.main.player_pos.z).distance_to(d.anchor("boatman_spot")) < 30.0, "먼 도착 → 대동문 앞 나루")
	await shot("s5001_naru", 30)
	# S5002 문서 비교
	prefer = ["나란히"]
	await go("merchant_a")
	prefer = []
	expect(d.S.seen.has("S5002"), "S5002 문서 비교 화면")
	for c in ["cmp_paper", "cmp_ink", "cmp_seal"]: expect(d.S.has_clue(c), "비교 단서 " + c)
	expect(d.S.knows("R_NOT_SAME"), "두 문서는 한 손에서 나오지 않았다(추정)")
	var doc_kind: String = String(d.data.clues.cmp_ink.get("kind", ""))
	expect(doc_kind == "fact", "문서에서 본 것은 확인(◆)으로 기록")
	# S5003 판 사내를 쫓는다
	await go("merchant_a")
	await go("merchant_b")
	expect(d.S.has_clue("seller_a") and d.S.has_clue("seller_b") and d.S.knows("R_TWO_SELLERS"), "판 사내는 둘(들음 둘 → 추정)")
	await go("boatman")
	expect(d.S.has_clue("together"), "사공 — 둘이 주막에서")
	await go("jumo")
	expect(d.S.is_flag("hideout_known") and Discovery.is_known(D.RG, "place:py_paper_yard"), "주모 — 강창 뒤 종이 마당(지도에 들음)")
	prefer = ["비켜"] if branch == "B" else ["붙잡는다"]
	await go("paper_line")
	prefer = []
	await _until(func(): return d.S.is_flag("swindlers_resolved") and not d.runner.busy and not d.combat_view.active, 240.0, "S5003 종이 마당")
	await _idle()
	var fr := String(d.S.flags.get("fight_result", ""))
	_log("싸움 %s caught_a=%s caught_b=%s fled=%s" % [fr, d.S.is_flag("caught_a"), d.S.is_flag("caught_b"), d.S.is_flag("fled")])
	match branch:
		"A": expect(d.case_fn.caught_any() and d.S.has_clue("confession"), "A: 사기꾼을 붙잡음 — 우치 이름을 빌렸을 뿐(%s)" % fr)
		"B": expect(fr == "" and d.S.is_flag("fled") and d.S.has_clue("fled"), "B: 길을 비켜 줌 — 달아남")
		"C": expect(fr == "escaped" and d.S.is_flag("fled") and not d.case_fn.caught_any(), "C: 싸우다 물러남 — 달아남(%s)" % fr)
	await shot("s5003_yard", 30)
	# S5004 — 포졸이 달려온다(나루 근처)
	prefer = ["기록 창고로 간다"]
	await _until(func(): return d.S.is_flag("alarm") and not d.runner.busy and not d.ui.modal, 60.0, "S5004 포졸")
	await _until(func(): return d.S.is_flag("store_seen") and not d.runner.busy and not d.ui.modal, 60.0, "기록 창고 도착")
	prefer = []
	expect(d.world.get_prop_state("py_sc_girokgo/window") == "BROKEN", "뒤 살창 BROKEN(prop 상태)")
	await go("store_window")
	expect(d.S.has_clue("window"), "뒤 살창 · 발자국")
	await shot("s5004_window", 30)
	prefer = ["앞문을"]
	await go("clerk")
	prefer = []
	expect(d.S.is_flag("store_open") and d.world.get_prop_state("py_sc_girokgo/door") == "OPEN", "서리가 앞문을 열어 줌")
	await go("store_rack")
	expect(d.S.has_clue("rack_gap") and d.S.knows("R_OTHER_AIM") and d.S.is_flag("bu_known"), "빈 시렁(북관) · 다른 목적 · 부벽루 쪽지")
	await go("store_chest")
	expect(d.S.has_clue("ledger_seen") and d.S.has_clue("ledger_park") and d.S.has_clue("ledger_qty"), "곡물 운송 대장 — 朴 표식 · 석 수는 맞음")
	expect(int(d.S.vars.get("MAIN_PARK_MARK_COUNT", 0)) == 5, "MAIN_PARK_MARK_COUNT 4 → 5 (%s)" % d.S.vars.get("MAIN_PARK_MARK_COUNT"))
	await go("store_chest")   # 다시 봐도 표식 수는 그대로
	expect(int(d.S.vars.get("MAIN_PARK_MARK_COUNT", 0)) == 5, "다시 봐도 朴 표식 수 그대로")
	await shot("s5004_inside", 30)
	# S5005 부벽루 — 낮이면 달을 기다린다
	d.set_hour(14.0)
	d.mark_dirty()
	await _frames(4)
	prefer = ["달 뜨기를"]
	await go("bu_wait")
	prefer = []
	expect(d.main.hour >= 20.0 and d.case_fn.night_now(), "부벽루 — 달 뜨기를 기다림 (%.1f시)" % d.main.hour)
	await _frames(10)
	d._refresh()
	expect(d.actors.woochi.shown, "밤 — 우치가 난간에")
	await shot("s5005_lamp", 30)
	prefer = ["날이 밝으면"]
	await go("woochi")
	prefer = []
	expect(d.S.is_flag("woochi_met") and d.S.has(D.HAM_DOC) and d.S.has_clue("woochi_words"), "S5005 부벽루 대면 — 함흥 문서")
	expect(d.main.hour >= 7.5 and d.main.hour < 9.0, "날이 밝아 기록 창고로 (%.1f시)" % d.main.hour)
	# S5006 문서 감정
	await go("clerk")
	expect(bool(d.S.vars.get("SKILL_DOCUMENT_CHECK", false)) and d.S.has_clue("master_note"), "S5006 문서 감정 · 이겸의 옛 종이")
	if branch == "C":
		expect(not d.S.is_flag("proven") and int(d.S.flags.get("exam_tries", 0)) == 1, "C: 첫 감정에선 고친 자리를 못 짚음 → 서리의 말")
		await go("desk_deeds")
	await _until(func(): return d.S.phase == "done" and not d.runner.busy and not d.ui.modal, 120.0, "결말·결말 카드")
	if branch == "A":
		await go("desk_pass")
		expect(d.S.has_clue("pass_forged"), "A: 한양 통행문서도 감정 — 도장보다 글이 나중")
	elif branch == "B":
		d._refresh()
		var pass_ok := false
		for t in d._targets():
			if t.id == "desk_pass": pass_ok = true
		expect(not pass_ok, "통행문서가 없으면 감정 대상도 없음")
	snapshot("end")
	var o := String(d.S.vars.get("CASE_PYONGYANG_OUTCOME", ""))
	var want := "B" if branch != "A" else "A"
	expect(o == want, "결말 %s (얻은 값 %s / %s)" % [want, o, d.S.vars.get("CASE_PYONGYANG_DETAIL", "")])
	expect(bool(d.S.vars.get("CASE_PYONGYANG_COMPLETE", false)), "CASE_PYONGYANG_COMPLETE")
	expect(bool(d.S.vars.get("ACT4_OPEN", false)) and Discovery.told_regions().has("HG_HAMHEUNG"), "ACT4_OPEN — 함흥 권역이 지도에(들음)")
	expect(String(d.S.vars.get("MAIN_MASTER_TRACE", "")).contains("PYONGYANG"), "MAIN_MASTER_TRACE += PYONGYANG (%s)" % d.S.vars.get("MAIN_MASTER_TRACE"))
	expect(bool(d.S.vars.get("SKILL_BEAST_SIDESTEP", false)) == (branch != "B"), "큰 짐승 흘리기 %s(SKILL_BEAST_TRACE %s)" % ["풀림" if branch != "B" else "안 풀림", branch != "B"])
	expect(d.case_fn.skill_found() >= 2, "고친 자리 둘 이상 감정(%d)" % d.case_fn.skill_found())
	for e in ["S5001", "S5002", "S5003", "S5004", "S5005", "S5006"]: expect(d.S.seen.has(e), "장면 " + e)
	expect(d.world.get_prop_state("py_sc_girokgo/window") == "SEALED", "결말 뒤 살창 고침")
	# 지역 변화 — 나루
	d.teleport_to("boatman_spot", "up")
	await _frames(20)
	d._refresh()
	expect(d.props.has("p_notice") and d.props.p_notice.get("want", false), "나루에 감영 방")
	expect(d.actors.merchant_b.shown == (want == "A"), "윤 상인 %s" % ("뗏목을 기다림" if want == "A" else "떠남"))
	expect(d.actors.sw_gate.shown == (want == "A"), "감영 정문 앞 묶인 사내 %s" % ("있음" if want == "A" else "없음"))
	await shot("after_naru", 40)
	var line := ""
	for r in Rumors.for_space(D.RG, d.world.region):
		if String(r.id) == "PY_NARU": line = Rumors.pick(r, Progress.vars(), d.S.vars)
	_log("소문 PY_NARU: " + line)
	expect(line != "" and line != "대동강을 판 사내가 있대.", "결말에 따라 바뀐 나루 소문")
	await go("boatman")
	d.ui.journal_show(d.journal_data())
	await shot("journal", 10)
	d.ui.journal_close()
	_log("vars=%s" % JSON.stringify({ o = o, detail = d.S.vars.get("CASE_PYONGYANG_DETAIL"), park = d.S.vars.get("MAIN_PARK_MARK_COUNT"),
		trace = d.S.vars.get("MAIN_MASTER_TRACE"), doc = d.S.vars.get("SKILL_DOCUMENT_CHECK"), side = d.S.vars.get("SKILL_BEAST_SIDESTEP"),
		act4 = d.S.vars.get("ACT4_OPEN"), found = Docs.found_list(d.S) }))
	_finish()

func _finish() -> void:
	Engine.time_scale = 1.0
	_log("fps min=%.0f avg=%.0f (n=%d)" % [_fps_min, _fps_sum / maxf(1.0, _fps_n), _fps_n])
	if _fails.is_empty(): printerr("STORYTEST PASS pyongyang:%s outcome=%s detail=%s time=%.0fs" % [branch, d.S.vars.get("CASE_PYONGYANG_OUTCOME", ""), d.S.vars.get("CASE_PYONGYANG_DETAIL", ""), (Time.get_ticks_msec() - _t0) / 1000.0])
	else: printerr("STORYTEST FAIL pyongyang:%s fails=%s" % [branch, JSON.stringify(_fails)])
	d.main._quit()

# ---------------------------------------------------------------------------
# PROBE — 앵커 높이·막힘
# ---------------------------------------------------------------------------
func _probe() -> void:
	var w = d.world
	if d.main.args.has("probegrid"):   # --probegrid=x0,z0,x1,z1,step — 높이·막힘 격자(. 열림, # 막힘, 숫자 = 땅보다 높은 마루 m)
		var g: PackedStringArray = String(d.main.args.probegrid).split(",")
		var x0 := float(g[0]); var z0 := float(g[1]); var x1 := float(g[2]); var z1 := float(g[3]); var st := float(g[4])
		var z := z0
		while z <= z1:
			var row := ""
			var x := x0
			while x <= x1:
				var fl: float = w.height_at(x, z) - w.ground_at(x, z)
				row += "#" if w.blocked(x, z, 0.3) else ("." if fl < 0.3 else str(mini(9, int(round(fl)))))
				x += st
			_log("GRID z=%7.1f %s" % [z, row])
			z += st
		_finish(); return
	var keys: Array = d.data.anchors.keys()
	keys.sort()
	for k in keys:
		var p: Vector2 = d.anchor(k)
		d.teleport_to(p)
		await _frames(4)
		_log("ANCHOR %-16s (%.1f, %.1f) h=%.2f ground=%.2f blocked=%s → 선 자리 (%.1f, %.1f)" % [k, p.x, p.y, w.height_at(p.x, p.y),
			w.ground_at(p.x, p.y) if w.has_method("ground_at") else NAN, w.blocked(p.x, p.y, 0.3), d.main.player_pos.x, d.main.player_pos.z])
	_finish()

# ---- 사람 적 봇: A는 덤벼 쓰러뜨림(달아나는 자는 활로), C는 버티다 싸움터 밖으로 물러난다 ----
func combat_bot() -> Dictionary:
	var b = d.combat_view.battle
	if b.mode != "human": return super.combat_bot()
	var pl = b.player
	var out := { move = Vector2.ZERO, held = {}, run = false }
	_bot_dodge_cd -= 1.0 / 60.0
	_log_t += 1.0 / 60.0
	if b.time > 4.0 and not _combat_shot:
		_combat_shot = true
		shot("combat_yard", 2)
	if _log_t > 4.0:
		_log_t = 0.0
		_log("싸움 t=%.0f 나 hp=%.0f st=%.0f %s / %s" % [b.time, pl.hp, pl.st, pl.state, JSON.stringify(b.foes.map(func(fo): return [fo.id, fo.state, roundf(fo.hp)]))])
	if not pl.alive: return out
	if branch == "C":
		if b.time < 3.0:
			out.held = { guard = true }; return out
		var away: Vector2 = pl.pos - Vector2(b.arena.x, b.arena.z)
		if away.length() < 0.5: away = Vector2(1, -0.6)
		out.move = away.normalized(); out.run = true
		return out
	var ac := Vector2(b.arena.x, b.arena.z); var lim: float = float(b.arena.radius) - 1.2
	var tg = null; var bd := INF
	for fo in b.foes:
		if not fo.active: continue
		var fl: bool = fo.state == "flee"
		if (fo.pos - ac).length() > lim + (14.0 if fl else 1.0): continue
		var dd: float = (fo.pos - pl.pos).length() - (100.0 if fl else 0.0)
		if dd < bd: bd = dd; tg = fo
	if tg == null: return out
	var v: Vector2 = tg.pos - pl.pos
	var dist := v.length()
	var dir := v / maxf(dist, 0.001)
	if tg.state == "flee" and int(pl.arrows) > 0 and dist > 2.0 and dist < 20.0:
		if _bow_hold < 0.95:
			_bow_hold += 1.0 / 60.0
			out.move = dir * 0.2; out.held = { bow = true }
			return out
		_bow_hold = 0.0
		return out
	_bow_hold = 0.0
	if (pl.pos + dir * 0.5 - ac).length() > lim:
		var r: Vector2 = (pl.pos - ac).normalized()
		dir = (dir - r * maxf(0.0, dir.dot(r))).normalized()
	for fo in b.foes:
		if fo.state == "wind" and (fo.pos - pl.pos).length() < 3.4 and fo.t > 0.2:
			if _bot_dodge_cd <= 0.0 and pl.st >= 25.0:
				_bot_dodge_cd = 0.8
				var dv: Vector2 = (fo.pos - pl.pos).normalized()
				out.move = Vector2(-dv.y, dv.x); out.held = { dodge = true }
				return out
			out.held = { guard = true }; return out
	if dist > 1.5:
		out.move = dir; out.run = dist > 2.5
		return out
	_bot_tap += 1
	out.held = { attack = (_bot_tap % 6) < 2 }
	out.move = dir * 0.15
	return out
