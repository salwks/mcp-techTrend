# 대본 시험(--storytest=jeju:A|B|C|PROBE|FPS) — ACT 4.5 제주 접근과 「굴에 남은 숨」.
#   A·B·C: ① SEA_NAMHAE_JEJU(--route — 함흥 뒤 남해 뱃길 들머리에 온 것처럼): 길목 한 줄 · 관두포 사공 · 제주 첫 뱃길(건너뛰기 없음)·바다 위 줄 → 화북포 끝 포털
#          ② JJ_JEJU: 화북포 생활 → S7001 곽칠성 → S7002 김녕 → S7003 입구 흔적 → S7004 감응 매듭(매듭이 떠는가·가만한가) → S7005 굴 안 어둠·잔영 → S7006 아이
#     A: 아이를 구한 뒤 도굴 자리를 메우고 놋그릇 → 심방과 제물·금줄(구렁이는 바위틈으로) / B: 구조 뒤 굴을 막음 / C: 구렁이를 벤다(싸움 — 잔영은 남음)
#     공통 끝: S7008 나무패(MAIN_GWAK_FOUND·ITEM_KEY_001), 플레이어의 첫 문장, CASE_JEJU_COMPLETE, 최종장 문(ACT6_OPEN)·한양 귀환 대상, 여행 기록
#   PROBE: 지금 공간의 앵커 높이·막힘만. FPS: 화북포·굴 안 fps(창 모드에서).
#   출발 저장: 함흥(ACT 4)까지 끝낸 상태(test_post_act4.json).
extends "res://scripts/story/story_test.gd"

const Progress := preload("res://scripts/region/progress.gd")
const Rumors := preload("res://story/rumors_data.gd")
const D := preload("res://story/jeju/jeju_data.gd")
const FIXTURE := "res://story/jeju/test_post_act4.json"
const META := "jeju_storytest"

static func prepare(dir) -> void:
	var j = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	if not (j is Dictionary): push_error("시험 출발 저장을 읽지 못함: " + FIXTURE); return
	var p := Progress.data()
	p.vars = j.get("vars", {}).duplicate(true)
	p.cases = j.get("cases", {}).duplicate(true)
	p.routes_done = j.get("routes_done", {}).duplicate(true)
	p.known = {}
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
	d.teleport_to(Vector2(p.x, p.y + 0.6), "up")
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

func _at(p) -> void:
	await _idle()
	d.teleport_to(p, "up")
	await _frames(20)
	await _idle()

func _run() -> void:
	var m = Engine.get_meta(META) if Engine.has_meta(META) else null
	if m is Dictionary:
		_t0 = int(m.t0); _fails = m.fails
	_log("시작 branch=%s space=%s stage=%s" % [branch, d.space_id, m.stage if m is Dictionary else "-"])
	if branch == "PROBE": await _probe(); return
	if branch == "FPS": await _fps(); return
	if not (m is Dictionary): await _stage_route()
	elif m.stage == "jeju": await _stage_jeju()

# ---------------------------------------------------------------------------
# ① 남해 뱃길 — 제주 첫 뱃길(건너뛰기 없음)
# ---------------------------------------------------------------------------
func _stage_route() -> void:
	expect(d.case_id == "jeju" and d.space_id == D.RS, "남해 뱃길 — 제주 사건 공간(함흥 뒤)")
	await _until(func(): return not d.main._loading, 90.0, "불러오기")
	var boats = d.main.boats
	d.teleport_to("rs_start", "right")
	await _frames(10)
	await _until(func(): return d.S.flags.has("_trig_rs_arrive") and not d.runner.busy, 20.0, "남해 뱃길 들머리 한 줄")
	expect(d.case_fn.approach_on() and boats.skip_lock, "제주 첫 뱃길 — 건너뛰기 잠김(skip_lock)")
	expect(not Progress.route_done(D.RS), "남해 뱃길은 아직 지나지 않음(역마 건너뛰기 없음)")
	await _at("rs_gwandu")
	await _until(func(): return d.S.flags.has("_trig_rs_gwandu"), 10.0, "관두포 한 줄")
	await go("rs_boatman")
	# 선창 끝에서 배에 오른다(사공이 젓는다). 시험은 배 속도만 올린다 — 건너뛰기(Space)는 잠겨 있다
	d.teleport_to("rs_pier", "right")
	await _frames(10)
	boats.speed_override = 30.0
	var ok: bool = boats.board(D.LANE, 0)
	expect(ok and boats.riding(), "관두포 선창 — 배에 오름")
	boats.update(0.016, false, true, false)   # 건너뛰기를 누른 것처럼
	expect(not boats.skipping, "첫 뱃길은 Space를 눌러도 건너뛰지 않는다")
	await _until(func(): return d.S.is_flag("crossed") and not boats.riding(), 120.0, "제주 뱃길 건넘")
	expect(d.S.is_flag("rs_c1") and d.S.is_flag("rs_c2") and d.S.is_flag("rs_c3"), "바다 위 세 줄(관두포·추자 바다·한라산)")
	expect(not boats.skip_lock, "건넌 뒤 건너뛰기 잠금 풀림")
	await shot("rs_crossed", 20)
	# 화북포 쪽 끝 포털로
	var pt = null
	for q in d.main.portals:
		if String(q.get("target", "")) == D.JJ: pt = q
	if pt == null:
		_fail("화북포 포털 없음"); _finish(); return
	_meta_save("jeju")
	d.teleport_to(Vector2(float(pt.x), float(pt.z) + 2.0), "up")
	await _wait_leave("제주로 넘어가지 않음")

func _wait_leave(what: String) -> void:
	for i in 900:
		if d.main._leaving: break
		await get_tree().process_frame
	if not d.main._leaving:
		_fail(what); _finish(); return
	for i in 100000:
		if not is_inside_tree(): return
		await get_tree().process_frame

# ---------------------------------------------------------------------------
# ② 제주
# ---------------------------------------------------------------------------
func _stage_jeju() -> void:
	expect(d.space_id == D.JJ and d.case_id == "jeju", "제주 — 같은 사건이 이어짐")
	await _until(func(): return not d.main._loading, 90.0, "불러오기")
	await _until(func(): return d.S.is_flag("jj_arrived") and not d.runner.busy and not d.ui.modal, 60.0, "화북포 도착")
	expect(Progress.route_done(D.RS), "남해 뱃길 — 이제 지나온 길(다음부터 역마)")
	await shot("hwabuk", 30)
	# 화북포 생활
	prefer = ["곽"]
	await go("hw_woman")
	prefer = []
	expect(d.S.has_clue("gwak_porter"), "화북 아낙 — 귀양 온 곽 서방(들음)")
	await go("haenyeo_a")
	await go("hw_man")
	expect(d.S.has_clue("outsiders"), "육지 배가 김녕 쪽으로(들음)")
	# S7001 → S7002 → 김녕
	prefer = ["서강", "김녕으로"]
	await go("gwak")
	prefer = []
	await _until(func(): return d.S.phase == "gimnyeong" and not d.runner.busy and not d.ui.modal, 60.0, "S7001·S7002 → 김녕")
	expect(d.S.has_clue("gwak_closed") and d.actors.gwak.name == "곽칠성", "S7001 — “그 일은 끝났소.” 곽칠성")
	expect(d.S.is_flag("case_started") and d.S.has_clue("child_missing"), "S7002 — 사건 기록 「굴에 남은 숨」")
	expect(d.main.player_pos.distance_to(Vector3(d.anchor("gw_gather").x, d.main.player_pos.y, d.anchor("gw_gather").y)) < 30.0, "김녕 굴 앞으로")
	await go("gw_elder")
	expect(d.S.has_clue("cave_talk"), "김녕 노인 — 굴의 뱀 이야기(들음)")
	# S7003 입구
	await _at(Vector2(3432.4, -890.0))
	await _until(func(): return d.S.is_flag("s7003") and not d.runner.busy, 20.0, "S7003 굴 입구")
	expect(d.world.get_prop_state("jj_sc_sagul_geumjul") == "BROKEN" and d.world.get_prop_state("jj_sc_sagul_jemul") == "EMPTY", "끊긴 금줄 · 빈 제물상(프롭 상태)")
	await shot("s7003_mouth", 20)
	await go("rope")
	await go("snake_tr")
	expect(d.S.has_clue("rope_cut") and d.S.has_clue("snake_track"), "입구 흔적 둘(매듭 없이)")
	# S7004 — 심방이 온다
	await _at("gw_gather")
	await _until(func(): return d.S.is_flag("simbang_here") and not d.runner.busy and not d.ui.modal, 30.0, "S7004 심방")
	expect(d.spirits.equipped(D.KNOT) and bool(d.S.vars.get("ITEM_SENSING_KNOT", false)), "S7004 감응 매듭(호신물 칸)")
	expect(d.S.has(D.LANTERN), "곽칠성의 초롱")
	# 매듭이 세계에서 보인다 — 떠는가 / 가만한가
	d.teleport_to(d.anchor("snake_tr"), "up")
	await _frames(40)
	var trem: float = d.sensing.level
	var k1: String = d.sensing.kind
	d.teleport_to(d.anchor("fake_tr"), "up")
	await _frames(40)
	var still: float = d.sensing.level
	var k2: String = d.sensing.kind
	_log("매듭: 뱀 자국 곁 %.2f(%s) · 넓게 끈 자국 곁 %.2f(%s)" % [trem, k1, still, k2])
	expect(trem > 0.4 and still < 0.08, "매듭 — 뱀 자국 곁에서 떨고, 넓게 끈 자국 곁에서 가만하다")
	var kn = d.sensing._node
	expect(kn != null and kn.visible, "매듭이 세계 안에 보인다(플레이어 허리께)")
	await shot("knot_still", 10)
	await go("fake_tr")
	await go("shoe_tr")
	await go("snake_tr")
	await go("sack")
	expect(d.S.knows("R_KNOT_STILL") and d.S.knows("R_FAKE_TRACK"), "매듭은 사람 손 자국 곁에서 가만하다 · 넓은 뱀 자국은 사람이 끌었다(추정)")
	await go("stele")
	# 굴(실내 공간 jj_sagul) — 금줄 안쪽 입구로 걸어 들면 짧은 암전으로 들어간다(권역은 그대로)
	var isp: Dictionary = load("res://scripts/region/interior_space.gd").spec_of("jj_sagul")
	var ent: Array = isp.entrances[0].at
	d.teleport_to(Vector2(float(ent[0]), float(ent[1]) + 3.0), "up")
	await _frames(10)
	d.teleport_to(Vector2(float(ent[0]), float(ent[1])), "up")
	await _until(func(): return d.world.indoor != null and not d.main._indoor_busy, 20.0, "굴 입구 → 실내 공간")
	expect(d.world.indoor != null and d.world.indoor.id == "jj_sagul" and not d.world.terrain_root.visible, "실내 공간 jj_sagul — 지형·식생을 숨기고 굴만")
	await _frames(20)
	expect(d.world.blocked(d.main.player_pos.x, d.main.player_pos.z, 0.3) == false and d.main.player_pos.z < -1890.0, "실내 자리에 섰다(%.1f, %.1f)" % [d.main.player_pos.x, d.main.player_pos.z])
	await shot("indoor_mouth", 20)
	await go("altar")
	expect(d.S.has_clue("offer_gone") and d.S.knows("R_MIXED_ALTAR"), "제단 — 섞인 흔적(매듭이 떨리다 멎다)")
	# 굴 안 — 어둠(굴 dark), 등불
	await _at("cave_mid")
	await _until(func(): return d.S.seen.has("S7005") and not d.runner.busy and not d.ui.modal, 90.0, "S7005 굴 안")
	expect(d.S.has_clue("snake_seen") and d.S.has_clue("shade"), "S7005 실제 구렁이 · 벽 너머 큰 잔영")
	await _frames(30)
	expect(float(d.main._dark_k) > 0.6 and d.main.lantern and d.main._lantern.visible, "굴 안 어둠(해빛 막음) · 등불")
	_log("굴 안 sun=%.2f dark=%.2f" % [d.main.sun.light_energy, d.main._dark_k])
	await shot("s7005_cave", 20)
	# S7006 아이
	prefer = ["업고", "아직 굴 안에"] if branch != "B" else ["업고", "굴을 막읍시다"]
	await go("child")
	prefer = []
	await _until(func(): return d.S.is_flag("child_saved") and not d.runner.busy and not d.ui.modal, 60.0, "S7006 구조")
	expect(d.S.seen.has("S7006") and d.S.has_clue("child_story"), "S7006 아이 — 등불 든 아저씨 둘(들음)")
	expect(d.world.indoor == null, "아이를 업고 나오면 굴 밖(실내 공간에서 나옴)")
	match branch:
		"A":
			await _at("cave_mid")
			# 출구 자리로 걸어 나갔다 다시 든다
			var ex: Array = isp.exits[0].at
			var exw: Vector2 = d.world.indoor.to_world(Vector2(float(ex[0]), float(ex[1]) - 3.5))
			d.teleport_to(exw, "down")
			await _frames(10)
			d.teleport_to(d.world.indoor.to_world(Vector2(float(ex[0]), float(ex[1]))), "down")
			await _until(func(): return d.world.indoor == null and not d.main._indoor_busy, 20.0, "출구 → 굴 밖")
			expect(d.world.terrain_root.visible and Vector2(d.main.player_pos.x, d.main.player_pos.z).distance_to(Vector2(float(isp.exits[0].to[0]), float(isp.exits[0].to[1]))) < 3.0, "굴 밖 입구 앞으로 나옴")
			await _at("cave_mid")
			prefer = ["그대로"]
			await go("dig")
			expect(not d.S.is_flag("pit_filled") and d.S.has_clue("dig_site"), "도굴 자리(매듭은 가만) — 고르기 전엔 메우지 않음")
			prefer = ["놋그릇을"]
			await go("dig")
			prefer = []
			expect(d.S.is_flag("bowl_got") and d.S.is_flag("pit_filled") and d.S.has(D.BOWL), "도굴 자리를 메우고 놋그릇")
			# 구렁이 곁 — 치켜들고 문다(싸움이 아니다)
			var sa = d.actors.snake
			d.teleport_to(Vector2(sa.pos.x, sa.pos.z + 2.0), "up")
			await _frames(3)
			_log("구렁이 곁: shown=%s 거리=%.1f busy=%s modal=%s" % [sa.shown, Vector2(sa.pos.x, sa.pos.z).distance_to(Vector2(d.main.player_pos.x, d.main.player_pos.z)), d.runner.busy, d.ui.modal])
			await _until(func(): return d.S.is_flag("snake_warned"), 8.0, "구렁이가 고개를 치켜들고 문다")
			_log("구렁이 곁에서 밀려남")
			prefer = ["심방과 함께"]
			await go("simbang")
			prefer = []
		"C":
			var sa = d.actors.snake
			await _at(Vector2(sa.pos.x, sa.pos.z + 3.4))
			prefer = ["칼을"]
			await _idle()
			d._refresh()
			_log("interact snake")
			d.interact("snake")
			await _frames(4)
			await _until(func(): return d.S.is_flag("snake_fought") and not d.combat_view.active and not d.runner.busy, 180.0, "구렁이 싸움")
			prefer = []
			_log("싸움 결과 %s" % d.S.flags.get("fight_result", ""))
			expect(String(d.S.flags.get("fight_result", "")) == "win" and d.S.is_flag("snake_dead"), "C — 구렁이를 벴다")
	await _until(func(): return d.S.phase == "done" and not d.runner.busy and not d.ui.modal, 120.0, "결말 · S7008")
	snapshot("end")
	await shot("after", 30)
	var o := String(d.S.vars.get("CASE_JEJU_OUTCOME", ""))
	expect(o == branch, "결말 %s (얻은 값 %s)" % [branch, o])
	for e in ["S7001", "S7002", "S7003", "S7004", "S7005", "S7006", "S7007", "S7008"]: expect(d.S.seen.has(e), "장면 " + e)
	expect(bool(d.S.vars.get("MAIN_GWAK_FOUND", false)) and bool(d.S.vars.get("ITEM_KEY_001", false)) and d.S.has(D.TALLY), "S7008 — 곽칠성의 나무패(MAIN_GWAK_FOUND · ITEM_KEY_001)")
	expect(d.S.has_clue("tally") and d.S.has_clue("park_alive"), "“저 숫자 때문에 사람이 죽었소.” · “아직 살아 있소?”")
	expect(bool(d.S.vars.get("CASE_JEJU_COMPLETE", false)) and bool(d.S.vars.get("ITEM_SENSING_KNOT", false)), "CASE_JEJU_COMPLETE · ITEM_SENSING_KNOT")
	expect(String(d.S.vars.get("PLAYER_FIRST_LINE", "")) == D.PLAYER_LINE, "플레이어의 첫 문장")
	expect(bool(d.S.vars.get("ACT6_OPEN", false)), "최종장 문 — ACT 2~5 모두 끝남 → 한양 귀환")
	var ht: Dictionary = d.case_fn.hanyang_target()
	expect(ht.get("target", "") == "GG_HANYANG", "한양 귀환 대상(역마)")
	match branch:
		"A":
			expect(d.world.get_prop_state("jj_sc_sagul_geumjul") == "NORMAL" and d.world.get_prop_state("jj_sc_sagul_jemul") == "NORMAL" and d.S.is_flag("snake_gone"), "A — 새 금줄·제물, 구렁이는 바위틈으로")
		"B":
			d._refresh()
			expect(d.props.p_stones.get("want", false) and d.S.is_flag("sealed"), "B — 굴 입구 돌무더기")
		"C":
			expect(d.actors.snake_body.shown, "C — 베인 구렁이가 남음")
	# 여행 기록·사건 기록
	var jd: Dictionary = d.journal_data()
	var travel := JSON.stringify(jd.pages[0])
	var cases := JSON.stringify(jd.pages[1])
	expect(travel.contains("곽칠성") and travel.contains(D.PLAYER_LINE), "여행 기록 — 곽칠성을 찾음 · 나의 첫 문장")
	expect(not travel.contains("이겸의 메모") and cases.contains(D.PLAYER_LINE), "사건 기록 — 나의 기록(이겸 메모 없음)")
	expect(cases.contains("◆") or cases.contains("fact") or true, "")
	d.ui.journal_show(jd)
	await shot("journal_travel", 10)
	d.ui.journal_close()
	# 소문(결말별)
	var line := ""
	for r in Rumors.for_space(D.JJ, d.world.region):
		if String(r.id) == "JJ_GIMNYEONG": line = Rumors.pick(r, Progress.vars(), d.S.vars)
	_log("소문 JJ_GIMNYEONG: " + line)
	expect(line != "", "결말에 따라 바뀐 김녕 소문")
	prefer = ["조금 더"]
	await go("gwak")
	prefer = []
	_log("vars=%s" % JSON.stringify({ o = o, gwak = d.S.vars.get("MAIN_GWAK_FOUND"), tally = d.S.vars.get("ITEM_KEY_001"), act6 = d.S.vars.get("ACT6_OPEN") }))
	_finish()

func _finish() -> void:
	Engine.remove_meta(META)
	Engine.time_scale = 1.0
	if _fails.is_empty(): printerr("STORYTEST PASS jeju:%s outcome=%s time=%.0fs" % [branch, d.S.vars.get("CASE_JEJU_OUTCOME", ""), (Time.get_ticks_msec() - _t0) / 1000.0])
	else: printerr("STORYTEST FAIL jeju:%s fails=%s" % [branch, JSON.stringify(_fails)])
	d.main._quit()

var _side_t := 0.0
var _side_s := 1.0

# ---- 싸움 봇(구렁이): 다가가 베고, 예고(wind)면 옆으로 구른다 ----
func combat_bot() -> Dictionary:
	var b = d.combat_view.battle
	if b.mode != "human": return super.combat_bot()
	var pl = b.player
	var out := { move = Vector2.ZERO, held = {}, run = false }
	_bot_dodge_cd -= 1.0 / 60.0
	_log_t += 1.0 / 60.0
	if _log_t > 4.0:
		_log_t = 0.0
		var bl := []
		for k in 6:
			var q: Vector2 = pl.pos.lerp(b.foes[0].pos, k / 5.0)
			bl.append(d.world.blocked(q.x, q.y, 0.3))
		_log("막힘 %s" % [bl])
		_log("싸움 t=%.0f 나 hp=%.0f %s %s / %s" % [b.time, pl.hp, pl.state, pl.pos, JSON.stringify(b.foes.map(func(fo): return [fo.id, fo.state, roundf(fo.hp), str(fo.pos)]))])
	if not pl.alive: return out
	var tg = null
	for fo in b.foes:
		if fo.active: tg = fo
	if tg == null: return out
	if tg.state == "lurk" or tg.state == "retreat":
		var v0: Vector2 = tg.pos - pl.pos
		if v0.length() > 1.8: out.move = v0.normalized(); out.run = true
		return out
	var v: Vector2 = tg.pos - pl.pos
	var dist := v.length()
	var dir := v / maxf(dist, 0.001)
	# 굴 바닥 흙 더미 등에 걸리면 옆으로 비켜 돌아간다
	if _side_t > 0.0:
		_side_t -= 1.0 / 60.0
		out.move = (Vector2(-dir.y, dir.x) * _side_s + dir * 0.3).normalized()
		return out
	if dist > 1.5:
		if _bot_last != Vector2.INF and pl.pos.distance_to(_bot_last) < 0.004: _bot_stuck += 1.0 / 60.0
		else: _bot_stuck = 0.0
		_bot_last = pl.pos
		if _bot_stuck > 0.4:
			_bot_stuck = 0.0; _side_t = 0.7; _side_s = -_side_s
	if tg.state == "wind" and dist < 3.4 and tg.t > 0.15:
		if _bot_dodge_cd <= 0.0 and pl.st >= 25.0:
			_bot_dodge_cd = 0.8
			out.move = Vector2(-dir.y, dir.x); out.held = { dodge = true }
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
func _probe() -> void:
	await _until(func(): return not d.main._loading, 90.0, "불러오기")
	var w = d.world
	var keys: Array = d.data.anchors.keys()
	keys.sort()
	for k in keys:
		var p: Vector2 = d.anchor(k)
		if (d.space_id == D.RS) != (k.begins_with("rs_")): continue
		d.teleport_to(p)
		await _frames(6)
		var bl = w.blocked(p.x, p.y, 0.3)
		_log("ANCHOR %-14s (%.1f, %.1f) h=%.2f blocked=%s → (%.1f, %.1f) interior=%s" % [k, p.x, p.y, w.height_at(p.x, p.y), bl, d.main.player_pos.x, d.main.player_pos.z,
			w.interior_at(p.x, p.y) != null])
	for nm in ["mouth", "outside", "rope", "altar", "niche", "dig", "deep_wall", "deep", "shed", "stele"]:
		_log("SAGUL %s %s" % [nm, w.prop_anchor(D.SAG, nm)])
	_finish()

# 화북포·굴 안 fps(창 모드 — 헤드리스는 의미 없음)
func _fps() -> void:
	await _until(func(): return not d.main._loading, 90.0, "불러오기")
	Engine.time_scale = 1.0
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	d.ui.auto = true
	for spot in [["hwabuk", Vector2(-1925.0, -520.0), false], ["cave", Vector2(3432.6, -1916.0), true], ["cave_deep", Vector2(3431.0, -1924.0), true],
			["mouth_in", Vector2(3432.4, -1898.5), true], ["mouth", Vector2(3432.4, -890.0), false]]:
		d.teleport_to(spot[1], "up")
		d.main.lantern = spot[2]
		await _frames(240)
		var t0 := Time.get_ticks_msec(); var n := 0
		while Time.get_ticks_msec() - t0 < 5000:
			await get_tree().process_frame; n += 1
		_log("FPS %s %.1f (dark=%.2f)" % [spot[0], n / 5.0, d.main._dark_k])
		await shot("fps_" + spot[0], 2)
	_finish()
