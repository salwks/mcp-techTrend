# 대본 시험(--storytest=hwangju:A|B|C) — 「빈 배의 값」을 한 결말로 끝까지 몰아 본다. 두 공간에 걸친다:
#   ① HH_HWANGJU(도화동 S4001·S4002) → 사건이 노정 포털로 넘긴다(장면 다시 열기) → ② HH_HWANGJU-JANGSANGOT(S4003~S4008)
#   → ③ 끝나면 다시 황주로 넘어가 지역 변화(노인 집의 연이·정화수)와 소문을 본다.
#   장면을 넘어가도 이어지도록 진행 단계·실패 목록·시작 시각을 Engine 메타("hwangju_storytest")에 둔다.
#   godot --path seolhwa_godot res://scenes/region.tscn -- --region=HH_HWANGJU --storytest=hwangju:A
#   A: 경주를 먼저 끝낸 저장(SKILL_RUBBING) — 탁본·곶 끝 찌까지, 증거를 들이밀어 중개인을 붙잡는다.
#   B: 강릉을 먼저 끝낸 저장 — 탁본 없이(닳은 새김) 구조, 연이부터 돌보고 중개인을 놓친다.
#   C: 한양만 끝낸 저장 — 밧줄 없이 섬에 갔다가 큰 바람(18시)에 쫓겨 오고, 바람이 지난 아침엔 늦다.
#   PROBE: 지금 공간의 앵커 높이·바다 여부와 물살(drift.simulate)만 찍는다(--region=HH_HWANGJU-JANGSANGOT도).
extends "res://scripts/story/story_test.gd"

const Progress := preload("res://scripts/region/progress.gd")
const Drift := preload("res://scripts/story/drift.gd")
const Rumors := preload("res://story/rumors_data.gd")
const D := preload("res://story/hwangju/hwangju_data.gd")
const FIXTURE := "res://story/hwangju/test_post_hanyang.json"
const META := "hwangju_storytest"

var _fps_min := 1000.0
var _fps_sum := 0.0
var _fps_n := 0

static func prepare(dir) -> void:
	var j = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	if not (j is Dictionary): push_error("시험 출발 저장을 읽지 못함: " + FIXTURE); return
	var br := String(dir.main.args.get("storytest", "hwangju:A")).get_slice(":", 1).to_upper()
	var p := Progress.data()
	p.vars = j.get("vars", {}).duplicate(true)
	p.cases = j.get("cases", {}).duplicate(true)
	p.routes_done = j.get("routes_done", {}).duplicate(true)
	p.erase("rubbings")   # 앞 시험의 탁본 기록(경주 모듈 progress.rubbings)을 지운다
	match br:
		"A":   # 경주를 먼저 — 탁본 숙련(경주 사건이 세우는 값만 흉내)
			p.vars.SKILL_RUBBING = true; p.vars.CASE_GYEONGJU_OUTCOME = "A"; p.vars.CASE_GYEONGJU_COMPLETE = true
		"B":   # 강릉을 먼저
			p.vars.CASE_GANGNEUNG_OUTCOME = "B"; p.vars.CASE_GANGNEUNG_COMPLETE = true; p.vars.ITEM_TALISMAN_SLOT = 1
			p.vars.MAIN_MASTER_TRACE = "HANYANG,GANGNEUNG"
	Progress.save()
	Engine.remove_meta(META)

func _log(s: String) -> void:
	printerr("STORYTEST [%s] %6.1fs %s" % [branch, (Time.get_ticks_msec() - _t0) / 1000.0, s])

func _meta_save(stage: String) -> void:
	Engine.set_meta(META, { stage = stage, t0 = _t0, fails = _fails, fps = [_fps_min, _fps_sum, _fps_n] })

func go(id: String) -> void:
	await _idle()
	var p := Vector2.INF
	if d.actors.has(id): p = Vector2(d.actors[id].pos.x, d.actors[id].pos.z)
	else:
		for o in d.data.get("objects", []):
			if String(o.id) == id: p = d.anchor(o.at)
	if p == Vector2.INF: p = d.anchor(id)
	d.teleport_to(Vector2(p.x, p.y + 1.0), "up")
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

func _fps_tick() -> void:
	var f := Engine.get_frames_per_second()
	if f <= 0: return
	_fps_min = minf(_fps_min, f); _fps_sum += f; _fps_n += 1

func _watch_fps() -> void:
	for i in 400000:
		await get_tree().create_timer(0.5, true, false, true).timeout
		if not is_inside_tree(): return
		if d.main._loading or d.runner.busy: continue
		_fps_tick()

func _run() -> void:
	var m = Engine.get_meta(META) if Engine.has_meta(META) else null
	if m is Dictionary:
		_t0 = int(m.t0); _fails = m.fails
		if m.has("fps"): _fps_min = float(m.fps[0]); _fps_sum = float(m.fps[1]); _fps_n = int(m.fps[2])
	_log("시작 branch=%s space=%s stage=%s" % [branch, d.space_id, m.stage if m is Dictionary else "-"])
	_watch_fps()
	if branch == "PROBE": await _probe(); return
	if not (m is Dictionary): await _stage_hwangju()
	elif m.stage == "route": await _stage_route()
	elif m.stage == "back": await _stage_back()

# ---------------------------------------------------------------------------
# ① 황주 도화동
# ---------------------------------------------------------------------------
func _stage_hwangju() -> void:
	expect(d.case_id == "hwangju" and d.space_id == D.RJ, "황주 사건이 섰다(ACT2_OPEN)")
	await _until(func(): return not d.main._loading, 60.0, "불러오기")
	# 노정(R04) 남쪽 끝 포털 자리에서 도착한 것처럼 — 먼 도착 → 도화동 어귀
	d.teleport_to([417.0, 2270.0], "up")
	await _frames(10)
	await d.runner.run([{ "event": "S4001" }])
	expect(d.S.is_flag("case_started") and d.S.has_clue("daughter_left"), "S4001 사건 기록 — 배를 탄 딸")
	expect(Vector2(d.main.player_pos.x, d.main.player_pos.z).distance_to(d.anchor("old_yard")) < 30.0, "먼 도착 → 도화동")
	await shot("s4001_old_man")
	await go("coins")
	await go("neigh_a")
	expect(d.S.has_clue("coins") and d.S.has_clue("sacrifice_talk"), "엽전 서른 냥 · 동네의 말")
	_meta_save("route")
	prefer = ["그 셈이", "장산곶으로 간다"]
	await go("broker")
	# 여기서 장면이 넘어간다(go_jangsan → main._travel). 넘어가지 않았으면 실패
	await _wait_leave("장산곶으로 넘어가지 않음")

# ---------------------------------------------------------------------------
# ② 장산곶
# ---------------------------------------------------------------------------
func _stage_route() -> void:
	expect(d.space_id == D.RT and d.case_id == "hwangju", "장산곶 노정 — 같은 사건이 이어짐")
	expect(d.S.is_flag("to_jangsan") and d.S.seen.has("S4002") and d.S.has_clue("broker_words"), "S4002 중개인의 말(들음)이 이어짐")
	await _until(func(): return not d.main._loading, 60.0, "불러오기")
	prefer = ["곧장"]
	await _until(func(): return d.S.is_flag("jangsan_arrived") and not d.runner.busy and not d.ui.modal, 90.0, "S4003 장산곶 도착")
	prefer = []
	expect(d.S.phase == "sea" and d.S.seen.has("S4003"), "S4003 장산곶 — 시계가 돈다 (%.1f시)" % d.main.hour)
	await shot("s4003_jangsan", 40)
	await go("wreck")
	await go("chest")
	expect(d.S.has_clue("wreck") and d.S.has_clue("receipt"), "부서진 장삿배 · 선주의 셈 쪽지")
	await go("sea_look")
	await _rite()
	if branch == "A": expect(d.S.has_clue("rite_rubbing") and d.S.is_flag("rubbed"), "S4005 탁본 — 짚 인형")
	else: expect(d.S.has_clue("rite_worn") and not d.S.has_clue("rite_rubbing"), "S4005 탁본 없음 — 닳은 새김(추가 단서 없음)")
	deny = ["밧줄"] if branch == "C" else []
	await go("fisher_a")
	deny = []
	expect(d.S.count(D.FLOATS) == 4, "그물 찌 넷")
	expect(d.S.has(D.ROPE) == (branch != "C"), "밧줄 %s" % ("없음" if branch == "C" else "있음"))
	await go("throw")
	var res: Array = d.S.flags.get("drift_last_offering", [])
	_log("물살 결과 %s" % [res])
	expect(res.count("bay_beach") == 2 and res.count("islet_cove") == 1, "S4004 찌 셋 — 둘 모래톱, 하나 바위섬")
	expect(d.S.knows("R_CURRENT_ISLET"), "제물 바위 앞 물은 바위섬 뒤로 돈다")
	if branch == "A":
		await go("cape_throw")
		expect(d.S.knows("R_PLACE_DIFFERS"), "곶 끝 찌는 먼바다로")
	await go("floats_beach")
	await shot("s4004_beach", 30)
	expect(d.S.knows("R_SEA_RETURNS") and d.S.knows("R_NO_PRICE"), "바다는 돌려보낸다 · 값을 치른 배도 부서졌다")
	# 뱃길: 뱃사공 설득 전에는 닫혀 있다
	await _board()
	await _frames(30); await _idle()
	expect(Vector2(d.main.player_pos.x, d.main.player_pos.z).distance_to(d.anchor("pier_land")) < 6.0, "설득 전 뱃길 닫힘 — 선창으로 되돌림")
	prefer = ["제물 바위 앞에 던진", "바위섬으로"]
	await go("boatman")
	prefer = []
	expect(d.S.is_flag("boat_ok"), "S4006 뱃사공 — 배를 대 준다")
	expect(d.S.is_flag("on_islet") and Vector2(d.main.player_pos.x, d.main.player_pos.z).distance_to(d.anchor("islet_cove")) < 6.0, "뱃사공이 바위섬에 대 줌")
	# 바위섬에서 걸어서 배에 오르면 되돌린다(배는 뱃사공이 몬다)
	await _board_islet()
	await go("islet_floats")
	expect(d.S.has_clue("islet_cove"), "바위섬 갯구멍 — 흘러든 찌")
	await shot("s4006_islet", 30)
	if branch == "C":
		await go("daughter")
		expect(d.S.is_flag("tried_no_rope") and not d.S.is_flag("rescued"), "밧줄 없이는 꺼내지 못함")
		# 시간이 흘러 큰 바람
		d.set_hour(17.97)
		await _until(func(): return d.S.is_flag("storm") and not d.runner.busy and not d.ui.modal, 60.0, "18시 큰 바람")
		expect(d.main.weather.is_forced() and d.main.weather.kind == "storm", "weather.force(storm)")
		expect(Vector2(d.main.player_pos.x, d.main.player_pos.z).distance_to(d.anchor("pier_land")) < 8.0, "큰 바람 — 섬에서 선창으로 쫓겨 옴")
		await shot("s4006_storm", 30)
		await _board()
		await _frames(30); await _idle()
		expect(Vector2(d.main.player_pos.x, d.main.player_pos.z).distance_to(d.anchor("pier_land")) < 6.0, "큰 바람 동안 뱃길 닫힘")
		prefer = ["기다린다"]
		await go("fisher_a")
		prefer = []
		expect(d.S.is_flag("storm_passed") and d.main.hour < 7.0, "바람이 지난 아침")
		await _sail_to_islet()
		await go("islet_empty")
	else:
		prefer = ["붙잡아"] if branch == "A" else ["연이부터"]
		deny = [] if branch == "A" else ["붙잡아"]
		await go("daughter")
		prefer = []; deny = []
	await _until(func(): return d.S.phase == "done" and not d.runner.busy and not d.ui.modal, 120.0, "결말·S4008·결말 카드")
	snapshot("end")
	await shot("after", 40)
	var o := String(d.S.vars.get("CASE_HWANGJU_OUTCOME", ""))
	expect(o == branch, "결말 %s (얻은 값 %s / %s)" % [branch, o, d.S.vars.get("CASE_HWANGJU_DETAIL", "")])
	expect(bool(d.S.vars.get("CASE_HWANGJU_COMPLETE", false)), "CASE_HWANGJU_COMPLETE")
	expect(bool(d.S.vars.get("MAIN_GWAK_NAME_KNOWN", false)), "S4008 MAIN_GWAK_NAME_KNOWN")
	expect(int(d.S.vars.get("MAIN_PARK_MARK_COUNT", 0)) == 3, "S4008 MAIN_PARK_MARK_COUNT 2 → 3")
	expect(String(d.S.vars.get("MAIN_MASTER_TRACE", "")).contains("HWANGJU"), "MAIN_MASTER_TRACE += HWANGJU (%s)" % d.S.vars.get("MAIN_MASTER_TRACE"))
	for e in ["S4001", "S4002", "S4003", "S4004", "S4005", "S4006", "S4007", "S4008"]: expect(d.S.seen.has(e), "장면 " + e)
	match branch:
		"A":
			expect(d.S.is_flag("broker_caught"), "A: 중개인 붙잡힘")
			expect(d.props.has("p_straw") and d.props.p_straw.get("want", false), "A+탁본: 짚배(옛 방식)")
		"B": expect(d.S.is_flag("broker_gone") and not d.S.is_flag("broker_caught"), "B: 중개인 도주")
		"C": expect(d.S.is_flag("rescue_failed") and d.props.p_ribbon.get("want", false), "C: 구조 실패 — 바위틈의 댕기")
	expect(d.actors.daughter_rest.shown == (branch != "C"), "어부 집 앞 연이 %s" % ("없음" if branch == "C" else "있음"))
	d.ui.journal_show(d.journal_data())
	await shot("journal", 10)
	d.ui.journal_close()
	_fps_tick()
	_log("vars=%s" % JSON.stringify({ o = o, detail = d.S.vars.get("CASE_HWANGJU_DETAIL"), gwak = d.S.vars.get("MAIN_GWAK_NAME_KNOWN"),
		park = d.S.vars.get("MAIN_PARK_MARK_COUNT"), trace = d.S.vars.get("MAIN_MASTER_TRACE"), hour = snappedf(d.main.hour, 0.1) }))
	_log("seen=%s" % JSON.stringify(d.S.seen.keys()))
	# ③ 황주로 돌아가 지역 변화를 본다
	_meta_save("back")
	d.case_fn.go_hwangju()
	await _wait_leave("황주로 넘어가지 않음")

# 공간 넘어가기 — 장면이 다시 열리면 이 노드는 사라지고 새 장면의 시험이 메타에서 이어 간다
func _wait_leave(what: String) -> void:
	for i in 600:
		if d.main._leaving: break
		await get_tree().process_frame
	if not d.main._leaving:
		_fail(what); _finish(); return
	for i in 100000:
		if not is_inside_tree(): return
		await get_tree().process_frame

# 선창 끝 배에 오른다(뱃길 걷기 면 위로) — 열려 있으면 저절로 섬까지 간다
func _board_islet() -> void:
	await _idle()
	var p: Vector2 = Vector2(502.5, -184.0)
	d.main.player_pos = Vector3(p.x, d.world.sea_y + 0.32, p.y)
	d.main.player.position = d.main.player_pos
	await _frames(30); await _idle()
	expect(Vector2(d.main.player_pos.x, d.main.player_pos.z).distance_to(d.anchor("islet_cove")) < 3.0, "바위섬 쪽 배 — 혼자 못 띄움(갯가로 되돌림)")

func _board() -> void:
	await _idle()
	d.teleport_to("pier_land", "right")
	await _frames(6)
	var p: Vector2 = d.anchor("lane_start") + Vector2(2.5, -1.8)
	d.main.player_pos = Vector3(p.x, d.world.sea_y + 0.32, p.y)
	d.main.player.position = d.main.player_pos
	await _frames(3)

# 뱃사공에게 말을 걸어 바위섬으로(사건 동안 배는 뱃사공이 몬다)
func _sail_to_islet() -> void:
	prefer = ["바위섬으로"]
	await go("boatman")
	prefer = []
	expect(d.S.is_flag("on_islet") and Vector2(d.main.player_pos.x, d.main.player_pos.z).distance_to(d.anchor("islet_cove")) < 6.0, "뱃사공이 바위섬에 대 줌")

# 옛 제의 바위: 탁본 모듈(경주)이 있으면 그 '탁본을 뜬다'를 쓰고, 없으면 사건의 조사 대상
func _rite() -> void:
	var rub = d.get("_rub")
	if rub != null and bool(d.S.vars.get("SKILL_RUBBING", false)):
		d.teleport_to(d.anchor("rite_rock") + Vector2(0, 1.2), "up")
		await _frames(30)
		if rub._target == null or String(rub._target.id) != "hj_rite":
			_fail("탁본 대상 없음(hj_rite)"); return
		_log("rubbing hj_rite (경주 모듈)")
		await rub.use(rub._target)
		await _frames(10); await _idle()
	else:
		await go("rite")

# ---------------------------------------------------------------------------
# ③ 다시 황주 — 지역 변화
# ---------------------------------------------------------------------------
func _stage_back() -> void:
	expect(d.space_id == D.RJ and d.S.phase == "done", "황주로 돌아옴 — 사건 끝난 상태")
	await _until(func(): return not d.main._loading, 60.0, "불러오기")
	d.teleport_to("old_out", "up")
	await _frames(30)
	d._refresh()
	var o := String(d.S.vars.get("CASE_HWANGJU_OUTCOME", ""))
	expect(d.actors.daughter_hj.shown == (o != "C"), "노인 집의 연이 %s" % ("없음" if o == "C" else "있음"))
	if o == "C": expect(d.props.has("p_bowl") and d.props.p_bowl.get("want", false), "C: 대문 밖 정화수 한 그릇")
	await shot("back_dohwa", 40)
	var line := ""
	for r in Rumors.for_space(D.RJ, d.world.region):
		if String(r.id) == "HJ_DOHWA": line = Rumors.pick(r, Progress.vars(), d.S.vars)
	_log("소문 HJ_DOHWA: " + line)
	expect(line != "" and line != "장산곶에서 바다가 사람 이름을 부른다더군.", "결말에 따라 바뀐 도화동 소문")
	await go("old_man")
	_finish()

func _finish() -> void:
	Engine.remove_meta(META)
	Engine.time_scale = 1.0
	_log("fps min=%.0f avg=%.0f (n=%d)" % [_fps_min, _fps_sum / maxf(1.0, _fps_n), _fps_n])
	if _fails.is_empty(): printerr("STORYTEST PASS hwangju:%s outcome=%s detail=%s time=%.0fs" % [branch, d.S.vars.get("CASE_HWANGJU_OUTCOME", ""), d.S.vars.get("CASE_HWANGJU_DETAIL", ""), (Time.get_ticks_msec() - _t0) / 1000.0])
	else: printerr("STORYTEST FAIL hwangju:%s fails=%s" % [branch, JSON.stringify(_fails)])
	d.main._quit()

# ---------------------------------------------------------------------------
# PROBE — 앵커 높이·바다 여부, 물살 모의
# ---------------------------------------------------------------------------
func _probe() -> void:
	await _until(func(): return not d.main._loading, 60.0, "불러오기")
	var w = d.world
	var keys: Array = d.data.anchors.keys()
	keys.sort()
	for k in keys:
		var p: Vector2 = d.anchor(k)
		d.teleport_to(p)
		await _frames(4)
		var bl = w.blocked(p.x, p.y, 0.3)
		_log("ANCHOR %-16s (%.1f, %.1f) h=%.2f ground=%.2f blocked=%s → 섬 자리 (%.1f, %.1f)" % [k, p.x, p.y, w.height_at(p.x, p.y),
			w.ground_at(p.x, p.y) if w.has_method("ground_at") else NAN, bl, d.main.player_pos.x, d.main.player_pos.z])
	if d.space_id == D.RT:
		var sea := func(q: Vector2) -> bool: return w.ground_at(q.x, q.y) < w.sea_y + 0.1
		for fid in d.data.currents:
			var f: Dictionary = Drift.prepare_field(d, d.data.currents[fid].duplicate(true))
			for i in 5:
				var r: Dictionary = Drift.simulate(f, d.anchor("throw_pt" if fid == "offering" else "cape_pt") + Vector2(i - 2, 0) * 0.9, i * 1.3, sea)
				_log("DRIFT %s #%d → %s t=%.0fs aground=%s end=(%.1f, %.1f)" % [fid, i, r.shore, r.t, r.get("aground", false), r.p.x, r.p.y])
	_finish()
