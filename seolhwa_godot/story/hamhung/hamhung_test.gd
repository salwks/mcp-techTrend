# 대본 시험(--storytest=hamhung:A|B|C|R05|PROBE) — 「돌아오지 않는 전갈」과 R05 노정 사건.
#   A·B·C: ① HG_HAMHEUNG(S6001) → 사건이 북청길 포털로 넘긴다 → ② HG_HAMHEUNG-BUKCHEONG(S6002~S6010) → (B만) ③ 다시 함흥(지역 변화·소문)
#     A: 막동을 찾고 싸움에 이겨 갑술을 푼다 → 셋 다(A). 남쪽 뱃길 안내(역마로 남원 남쪽 끝, 제주 뱃길은 아직 건너지 않음)를 본다.
#     B: 막동을 지나쳐 역참으로 → 막동을 놓친다(B_madong). 함흥으로 돌아가 물 한 그릇·소문을 본다.
#     C: 막동을 지나치고 싸움에서 물러난다 → 갑술도 끌려감(C).
#   R05: --route=PA_PYEONGYANG-HG_HAMHEUNG — 날씨 단계(흐림→바람→눈→고개 눈보라→눈), 네 사건, 고원 주막, 지난 뒤 보통 날씨.
#   PROBE: 지금 공간의 앵커 높이·막힘만 찍는다.
#   출발 저장: 평양(ACT 3)까지 끝낸 상태(test_post_act3.json) — 평양 사건 담당과 따로 시험하려고 CASE_PYONGYANG_COMPLETE를 미리 세운다.
extends "res://scripts/story/story_test.gd"

const Progress := preload("res://scripts/region/progress.gd")
const Rumors := preload("res://story/rumors_data.gd")
const Discovery := preload("res://scripts/region/discovery.gd")
const D := preload("res://story/hamhung/hamhung_data.gd")
const FIXTURE := "res://story/hamhung/test_post_act3.json"
const META := "hamhung_storytest"

static func prepare(dir) -> void:
	var j = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	if not (j is Dictionary): push_error("시험 출발 저장을 읽지 못함: " + FIXTURE); return
	var br := String(dir.main.args.get("storytest", "hamhung:A")).get_slice(":", 1).to_upper()
	var p := Progress.data()
	p.vars = j.get("vars", {}).duplicate(true)
	p.cases = j.get("cases", {}).duplicate(true)
	p.routes_done = j.get("routes_done", {}).duplicate(true)
	p.known = {}
	if br != "R05" and br != "PROBE":   # 평양→함흥 노정(R05)과 영흥 갈림길 뒤 경흥대로 끝을 지나 함흥에 왔다
		p.routes_done[D.RT5] = "2026-10-04T12:00:00"
		p.routes_done["GG_HANYANG-HG_HAMHEUNG"] = "2026-10-04T12:30:00"
	Progress.save()
	Engine.remove_meta(META)

func _log(s: String) -> void:
	printerr("STORYTEST [%s] %6.1fs %s" % [branch, (Time.get_ticks_msec() - _t0) / 1000.0, s])

func _meta_save(stage: String) -> void:
	Engine.set_meta(META, { stage = stage, t0 = _t0, fails = _fails })

func go(id: String) -> void:
	await _idle()
	var p := Vector2.INF
	if d.actors.has(id): p = Vector2(d.actors[id].pos.x, d.actors[id].pos.z)
	else:
		for o in d.data.get("objects", []):
			if String(o.id) == id: p = d.anchor(o.at)
	if p == Vector2.INF: p = d.anchor(id)
	d.teleport_to(Vector2(p.x, p.y + 0.8), "up")
	await _frames(8)
	await _idle()
	d._refresh()
	var ok := false
	for t in d._targets():
		if t.id == id: ok = true
	if not ok:
		_fail("대상 없음/조건 안 맞음: " + id + " (자리 %.1f,%.1f)" % [p.x, p.y])
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

func _at(p: Vector2) -> void:
	await _idle()
	d.teleport_to(p, "right")
	await _frames(20)
	await _idle()

func _run() -> void:
	var m = Engine.get_meta(META) if Engine.has_meta(META) else null
	if m is Dictionary:
		_t0 = int(m.t0); _fails = m.fails
	_log("시작 branch=%s space=%s stage=%s" % [branch, d.space_id, m.stage if m is Dictionary else "-"])
	if branch == "PROBE": await _probe(); return
	if branch == "R05": await _stage_r05(); return
	if not (m is Dictionary): await _stage_hamhung()
	elif m.stage == "route": await _stage_route()
	elif m.stage == "back": await _stage_back()

# ---------------------------------------------------------------------------
# R05 평양→함흥 노정
# ---------------------------------------------------------------------------
func _wk() -> String:
	var w = d.main.weather
	return String(w.script_kind) if w != null else ""

func _stage_r05() -> void:
	expect(d.case_id == "hamhung" and d.space_id == D.RT5, "R05 — 함흥 사건 공간(평양 사건 뒤)")
	await _until(func(): return not d.main._loading, 60.0, "불러오기")
	await _frames(10)
	expect(d.S.is_flag("r05_started") and _wk() == "cloudy", "평양 쪽 들머리 — 흐림 (%s)" % _wk())
	await _at(Vector2(-320.0, -4.0)); await _frames(30)
	expect(_wk() == "wind", "성천 지나 — 바람 (%s)" % _wk())
	await _at(Vector2(-215.0, -1.0)); await _frames(30)
	expect(_wk() == "snow", "양덕 서쪽 숲길 — 눈 (%s)" % _wk())
	await go("r05_horse")
	expect(d.S.has_clue("r05_horse") and d.S.is_flag("r05_horse_read"), "쓰러진 말 — 짐승 흔적 읽기: 범이 아니라 추위")
	prefer = ["바로 돌려"]
	await go("r05_sign")
	prefer = []
	expect(d.S.is_flag("r05_sign_fixed") and d.S.has_clue("r05_sign"), "돌아간 이정표 — 바로 세움")
	expect(_wk() == "blizzard", "신창 갈림길 — 눈보라 (%s)" % _wk())
	await _at(Vector2(D.PASS_X, 12.0)); await _frames(30)
	expect(d.S.is_flag("r05_pass") and _wk() == "blizzard", "양덕 고갯마루 — 눈보라")
	prefer = ["파 본다"]
	await go("r05_luggage")
	prefer = []
	expect(d.S.has(D.LUGGAGE), "눈에 묻힌 봇짐")
	await go("r05_tracks")
	expect(d.S.has_clue("r05_tracks") and d.S.is_flag("r05_tracks_read"), "세 갈래 발자국 — 되돌아온 두 줄")
	expect(_wk() == "snow", "고원 쪽 내리막 — 눈 (%s)" % _wk())
	await go("gowon_kim")
	expect(d.S.is_flag("r05_returned") and not d.S.has(D.LUGGAGE), "고원 주막 — 봇짐을 주인에게")
	expect(d.S.phase == "start" and not d.S.is_flag("case_started"), "퀘스트·사건 기록 없이(노정 사건)")
	await _at(Vector2(578.0, 8.0)); await _frames(30)
	expect(d.S.is_flag("r05_done") and not d.main.weather.is_forced(), "끝까지 지남 — 날씨 풀림")
	# 다시 들어온 것처럼(on_load) — 보통 날씨, 사건 물건 없음
	d.case_fn.on_load()
	d._refresh()
	var any := false
	for t in d._targets():
		if String(t.id).begins_with("r05_"): any = true
	expect(not d.main.weather.is_forced() and not any, "두 번째부터 보통 날씨 · 노정 사건 없음")
	expect(d.props.p_r05_sign_ok.get("want", false) and d.props.p_r05_horse.get("want", false), "바로 세운 이정표·쓰러진 말은 남는다")
	_finish()

# ---------------------------------------------------------------------------
# ① 함흥 동문 밖
# ---------------------------------------------------------------------------
func _stage_hamhung() -> void:
	expect(d.case_id == "hamhung" and d.space_id == D.HG, "함흥 사건이 섰다(CASE_PYONGYANG_COMPLETE)")
	await _until(func(): return not d.main._loading, 60.0, "불러오기")
	d.teleport_to([-2500.0, 1815.0], "up")   # 경흥대로 끝 포털 자리에서 도착한 것처럼
	await _frames(10)
	prefer = ["그만 가 보겠소"]
	await d.runner.run([{ "event": "S6001" }])
	prefer = []
	expect(d.S.is_flag("case_started") and d.S.has_clue("three_couriers"), "S6001 세 전갈꾼 — 사건 기록")
	expect(Vector2(d.main.player_pos.x, d.main.player_pos.z).distance_to(d.anchor("clerk_spot")) < 30.0, "먼 도착 → 동문 밖")
	await shot("s6001_gate")
	await go("town_a")
	expect(d.S.has_clue("joke"), "함흥차사 농담(들음 — 사람들)")
	_meta_save("route")
	prefer = ["북청길로"]
	await go("clerk")
	await _wait_leave("북청길로 넘어가지 않음")

# ---------------------------------------------------------------------------
# ② 북청길
# ---------------------------------------------------------------------------
func _stage_route() -> void:
	expect(d.space_id == D.RTB and d.case_id == "hamhung", "북청길 — 같은 사건이 이어짐")
	await _until(func(): return not d.main._loading, 60.0, "불러오기")
	await _until(func(): return d.S.is_flag("rtb_arrived") and not d.runner.busy and not d.ui.modal, 60.0, "북청길 도착")
	expect(_wk() in ["snow", "blizzard"], "북청길 — 눈보라 날씨 (%s)" % _wk())
	await go("pouch")
	expect(d.S.has_clue("pouch") and d.S.knows("R_SNOW_COVERS"), "S6002 길 위의 전갈 주머니 — 눈은 발자국을 덮는다")
	if branch == "A":
		prefer = ["업어서"]
		await go("madong")
		prefer = []
		expect(d.S.is_flag("madong_saved") and d.S.has_clue("madong"), "S6002 막동 구조 — 서낭당 불 곁")
		await shot("s6002_fire", 30)
	await go("pass_post")
	expect(d.S.has_clue("turned_post"), "함관령 표목 — 돌려놓음")
	# S6003 수레 — 다가가면 싸움
	await _at(Vector2(d.anchor("cart_arena").x - 13.0, d.anchor("cart_arena").y))
	await _until(func(): return d.S.is_flag("cart_fought") and not d.runner.busy and not d.ui.modal and not d.combat_view.active, 120.0, "S6003 수레 싸움")
	_log("싸움 결과 %s" % d.S.flags.get("fight_result", ""))
	if branch == "C":
		expect(String(d.S.flags.get("fight_result", "")) == "escaped" and d.S.is_flag("gapsul_taken"), "C: 물러남 — 갑술이 끌려감")
	else:
		expect(String(d.S.flags.get("fight_result", "")) == "win", "도적 둘을 물리침")
		await go("gapsul")
		expect(d.S.is_flag("gapsul_saved") and d.S.has_clue("gapsul"), "S6003 갑술을 풀었다")
	await go("cart")
	expect(d.S.knows("R_TURNED_SIGN"), "길을 돌려놓는 사람이 있다")
	# S6004 발자국 → S6005 역참
	await _at(d.anchor("tracks_start"))
	await _until(func(): return d.S.is_flag("tracks_seen") and not d.runner.busy, 30.0, "S6004 발자국")
	expect(d.S.has_clue("tracks") and d.world.get_prop_state("rt_sc_yeokcham_lamp") == "USED", "S6004 숲 발자국 · 역참 불빛")
	await _at(d.anchor("station_door"))
	await _until(func(): return d.S.is_flag("master_met") and not d.runner.busy and not d.ui.modal, 60.0, "S6005·S6006")
	expect(d.S.seen.has("S6005") and d.S.seen.has("S6006") and d.actors.yigyeom.name == "이겸", "S6005 역참 · S6006 이겸 — “그 책 아직 갖고 있었구나.”")
	expect(not d.actors.madong.shown, "역참에 든 뒤 — 골짜기의 막동 발자국은 덮였다" if branch != "A" else "막동은 서낭당 불 곁(골짜기 자리 비어 있음)")
	await shot("s6006_room", 30)
	if branch == "A":
		prefer = ["버선"]
		await go("sundol")
		prefer = []
		expect(d.S.has_clue("sundol"), "순돌 — 스승이 종이를 태워 살렸다")
	await go("yigyeom")   # 물건을 다 보기 전 — "둘러봐라."
	expect(not d.S.is_flag("asked_why"), "방을 다 보기 전에는 묻지 않는다")
	await go("ledger")
	expect(d.S.has_clue("park_ledger") and int(d.S.vars.get("MAIN_PARK_MARK_COUNT", 0)) == 6, "S6007 불탄 장부의 朴 — 표식 5 → 6")
	await go("ham")
	await go("wall_map")
	expect(d.S.has_clue("gwak_record") and d.S.has_clue("woochi_map"), "S6007 곽칠성 이름 · 우치 흔적")
	prefer = ["왜 돌아오지"]
	await go("yigyeom")
	prefer = []
	await _until(func(): return d.S.phase == "done" and not d.runner.busy and not d.ui.modal, 120.0, "S6008~S6010·결말 카드")
	snapshot("end")
	await shot("after", 40)
	var want: String = { "A": "A", "B": "B", "C": "C" }[branch]
	var o := String(d.S.vars.get("CASE_HAMHUNG_OUTCOME", ""))
	expect(o == want, "결말 %s (얻은 값 %s / %s)" % [want, o, d.S.vars.get("CASE_HAMHUNG_DETAIL", "")])
	for e in ["S6001", "S6003", "S6004", "S6005", "S6006", "S6007", "S6008", "S6009", "S6010"]: expect(d.S.seen.has(e), "장면 " + e)
	if branch == "A": expect(d.S.seen.has("S6002"), "장면 S6002")
	expect(d.S.knows("R_RESCUE_FIRST"), "기록보다 구조가 먼저인 때가 있다")
	expect(bool(d.S.vars.get("CASE_HAMHUNG_COMPLETE", false)), "CASE_HAMHUNG_COMPLETE")
	expect(bool(d.S.vars.get("SKILL_TOOL_SLOT_PLUS", false)), "숙련 해금: 보조도구 전환(SKILL_TOOL_SLOT_PLUS)")
	expect(bool(d.S.vars.get("MAIN_MASTER_FOUND", false)) and bool(d.S.vars.get("MAIN_PAST_EVENT_KNOWN", false)), "MAIN_MASTER_FOUND · MAIN_PAST_EVENT_KNOWN")
	expect(String(d.S.vars.get("MAIN_MASTER_TRACE", "")).contains("HAMHUNG"), "MAIN_MASTER_TRACE += HAMHUNG")
	expect(d.S.has(D.RECORD) and d.S.has_clue("gwak_jeju"), "S6010 곽칠성 — 제주 · 이겸의 기록")
	expect(Discovery.region_known("JJ_JEJU"), "전국 지도에 제주(들음)")
	# 여행 기록: 이겸 찾음 · 다음은 곽칠성(제주)
	var jd: Dictionary = d.journal_data()
	var travel := JSON.stringify(jd.pages[0])
	expect(travel.contains("찾았다") and travel.contains("곽칠성") and travel.contains("제주"), "여행 기록 — 이겸을 찾음, 다음 곽칠성(제주)")
	d.ui.journal_show(jd)
	await shot("journal_travel", 10)
	d.ui.journal_close()
	_log("vars=%s" % JSON.stringify({ o = o, detail = d.S.vars.get("CASE_HAMHUNG_DETAIL"), park = d.S.vars.get("MAIN_PARK_MARK_COUNT"),
		trace = d.S.vars.get("MAIN_MASTER_TRACE"), tool = d.S.vars.get("SKILL_TOOL_SLOT_PLUS") }))
	_log("seen=%s" % JSON.stringify(d.S.seen.keys()))
	# 남쪽 뱃길(§18): 역마로 남원 남쪽 끝까지는 가도 되고, 제주 뱃길은 아직 건넌 적이 없어 건너뛰지 못한다
	expect(d.case_fn.fast_south_ok(), "남쪽으로 역마(지나온 노정)")
	var st: Dictionary = d.case_fn.south_target()
	expect(st.get("target", "") == D.SOUTH_ROUTE and st.get("kind", "") == "route", "도착은 남해 뱃길 들머리(노정 시작)")
	expect(not Progress.route_done(D.SOUTH_ROUTE), "제주 뱃길 첫 건넘은 건너뛰기 없음(route_done 아님)")
	if branch == "B":
		_meta_save("back")
		d.case_fn.go_hamhung()
		await _wait_leave("함흥으로 넘어가지 않음")
		return
	_finish()

func _wait_leave(what: String) -> void:
	for i in 600:
		if d.main._leaving: break
		await get_tree().process_frame
	if not d.main._leaving:
		_fail(what); _finish(); return
	for i in 100000:
		if not is_inside_tree(): return
		await get_tree().process_frame

# ---------------------------------------------------------------------------
# ③ 다시 함흥 — 지역 변화(B: 막동을 놓쳤다)
# ---------------------------------------------------------------------------
func _stage_back() -> void:
	expect(d.space_id == D.HG and d.S.phase == "done", "함흥으로 돌아옴 — 사건 끝난 상태")
	await _until(func(): return not d.main._loading, 60.0, "불러오기")
	d.teleport_to("hg_arrive", "left")
	await _frames(30)
	d._refresh()
	expect(not d.actors.madong_hg.shown and d.actors.gapsul_hg.shown and d.actors.sundol_hg.shown, "동문 밖 — 갑술·순돌, 막동 없음")
	expect(d.props.p_hg_bowl.get("want", false), "막동 집 앞 물 한 그릇")
	await shot("back_gate", 40)
	var line := ""
	for r in Rumors.for_space(D.HG, d.world.region):
		if String(r.id) == "HG_GATE": line = Rumors.pick(r, Progress.vars(), d.S.vars)
	_log("소문 HG_GATE: " + line)
	expect(line != "" and line.contains("물"), "결말에 따라 바뀐 동문 소문")
	await go("clerk")
	_finish()

func _finish() -> void:
	Engine.remove_meta(META)
	Engine.time_scale = 1.0
	if _fails.is_empty(): printerr("STORYTEST PASS hamhung:%s outcome=%s detail=%s time=%.0fs" % [branch, d.S.vars.get("CASE_HAMHUNG_OUTCOME", ""), d.S.vars.get("CASE_HAMHUNG_DETAIL", ""), (Time.get_ticks_msec() - _t0) / 1000.0])
	else: printerr("STORYTEST FAIL hamhung:%s fails=%s" % [branch, JSON.stringify(_fails)])
	d.main._quit()

# ---- 사람 적 봇(경주 시험과 같은 꼴): A·B는 덤벼 쓰러뜨림, C는 물러난다 ----
func combat_bot() -> Dictionary:
	var b = d.combat_view.battle
	if b.mode != "human": return super.combat_bot()
	var pl = b.player
	var out := { move = Vector2.ZERO, held = {}, run = false }
	_bot_dodge_cd -= 1.0 / 60.0
	_log_t += 1.0 / 60.0
	if _log_t > 4.0:
		_log_t = 0.0
		_log("싸움 t=%.0f 나 hp=%.0f %s / %s" % [b.time, pl.hp, pl.state, JSON.stringify(b.foes.map(func(fo): return [fo.id, fo.state, roundf(fo.hp)]))])
	if not pl.alive: return out
	var ac := Vector2(b.arena.x, b.arena.z)
	if branch == "C":
		if b.time < 2.0:
			out.held = { guard = true }; return out
		var away: Vector2 = pl.pos - ac
		if away.length() < 0.5: away = Vector2(-1, 0.2)
		out.move = away.normalized(); out.run = true
		return out
	var lim: float = float(b.arena.radius) - 1.2
	var tg = null; var bd := INF
	for fo in b.foes:
		if not fo.active or fo.state == "flee": continue
		if (fo.pos - ac).length() > lim + 1.0: continue
		var dd: float = (fo.pos - pl.pos).length()
		if dd < bd: bd = dd; tg = fo
	if tg == null: return out
	var v: Vector2 = tg.pos - pl.pos
	var dist := v.length()
	var dir := v / maxf(dist, 0.001)
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

# ---------------------------------------------------------------------------
# PROBE — 앵커 높이·막힘
# ---------------------------------------------------------------------------
func _probe() -> void:
	await _until(func(): return not d.main._loading, 60.0, "불러오기")
	var w = d.world
	var keys: Array = d.data.anchors.keys()
	keys.sort()
	for k in keys:
		var p: Vector2 = d.anchor(k)
		if p.x < w.region.get("height", {}).get("x0", -1e9): pass
		d.teleport_to(p)
		await _frames(6)
		var bl = w.blocked(p.x, p.y, 0.3)
		_log("ANCHOR %-16s (%.1f, %.1f) h=%.2f blocked=%s → 선 자리 (%.1f, %.1f)" % [k, p.x, p.y, w.height_at(p.x, p.y), bl, d.main.player_pos.x, d.main.player_pos.z])
	_finish()
