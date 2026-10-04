# 대본 시험(--storytest=gyeongju:A|B) — 「세 번째 등불」을 한 결말로 끝까지 몰아 본다.
#   A: 강릉까지 마친 저장(호신부를 지님) — 등성이 싸움에서 밀수꾼을 쓰러뜨리고, 우치를 끝까지 쫓는다. 셋째 불 곁 형체를 본다.
#   B: 한양만 마친 저장(호신물 없음 — 경주를 강릉보다 먼저) — 싸움에서 물러나(escaped) 밀수꾼이 달아나고, 우치를 놓친다.
#   둘 다 끝에 탁본 도구로 망부석·장승을 떠 본다. --storyshots=폴더면 장면마다 찍는다. 끝에 STORYTEST PASS/FAIL.
extends "res://scripts/story/story_test.gd"

const Progress := preload("res://scripts/region/progress.gd")

var _fps_min := 1000.0
var _fps_sum := 0.0
var _fps_n := 0
var _night_fps: Array = []
var _fight_fps: Array = []
var _bot_s := -1.0
var _chase_log_t := 0.0

static func prepare(_dir) -> void:
	var spec: String = String(_dir.main.args.get("storytest", "gyeongju:A"))
	var br := (spec.split(":")[1] if spec.contains(":") else "A").to_upper()
	var p := Progress.data()
	p.vars = { "MAIN_MASTER_TRACE": "HANYANG", "SKILL_BEAST_TRACE": true, "CASE_NAMWON_OUTCOME": "C", "CASE_NAMWON_DETAIL": "C",
		"MAIN_WOOCHI_KNOWN": true, "ACT2_OPEN": true, "CASE_HANYANG_OUTCOME": "followed", "ITEM_TALISMAN_SLOT": 0,
		"CASE_NAMWON_COMPLETE": true, "CASE_HANYANG_BOOKSHOP_COMPLETE": true, "SKILL_GUARD_SHOVE": true, "SKILL_QUICK_THROW": true }
	p.cases = {
		"namwon": { "v": 2, "phase": "done", "flags": { "case_started": true, "resolved": true }, "clues": [], "rules": [],
			"items": { "ITM_TOOL_009": 1, "ITM_WPN_001": 1, "ITM_WPN_002": 1, "ITM_AMMO_001": 12, "COIN": 7 }, "world": {}, "talked": {}, "notes": [],
			"seen": { "S0010": true }, "time": 8.0 },
		"hanyang": { "v": 2, "phase": "done", "flags": { "case_started": true }, "clues": [], "rules": [], "items": {}, "world": {}, "talked": {}, "notes": [],
			"seen": { "S1001": true, "S1005": true, "S1006": true }, "time": 12.0 },
	}
	p.routes_done = { "JL_NAMWON_UNBONG-GG_HANYANG": "2026-10-04T09:00:00", "GG_HANYANG-GS_GYEONGJU": "2026-10-04T10:00:00" }
	p.erase("rubbings")
	if br == "A":
		# 강릉(A)까지 마침: 호신물 칸 1, 호신부를 지님
		p.vars.merge({ "MAIN_MASTER_TRACE": "HANYANG,GANGNEUNG", "CASE_GANGNEUNG_OUTCOME": "A", "CASE_GANGNEUNG_DETAIL": "A",
			"CASE_GANGNEUNG_COMPLETE": true, "SKILL_EVADE_SLASH": true, "ITEM_TALISMAN_SLOT": 1,
			"TALISMANS_OWNED": ["ITM_RIT_001"], "TALISMAN_EQUIPPED": ["ITM_RIT_001"] }, true)
		p.cases["gangneung"] = { "v": 2, "phase": "done", "flags": { "case_started": true, "resolved": true }, "clues": [], "rules": [], "items": {},
			"world": {}, "talked": {}, "notes": [], "seen": { "S2008": true }, "time": 8.0 }
	Progress.save()

# 조사 대상 id와 자리 이름이 다르다: 대상의 at으로 옮긴 뒤(강릉 시험과 같다)
func go(id: String) -> void:
	await _idle()
	var p := Vector2.INF
	if d.actors.has(id): p = Vector2(d.actors[id].pos.x, d.actors[id].pos.z)
	else:
		for o in d.data.get("objects", []):
			if String(o.id) == id: p = d.anchor(o.at)
	if p == Vector2.INF: p = d.anchor(id)
	d.teleport_to(Vector2(p.x, p.y + 1.2), "up")
	await _frames(8)
	await _idle()
	d._refresh()
	var ok := false
	for t in d._targets():
		if t.id == id: ok = true
	if not ok:
		_fail("대상 없음/조건 안 맞음: " + id)
		return
	_log("interact " + id)
	d.interact(id)
	await _frames(2)
	await _idle()

func begin() -> void:
	super.begin()
	if d.main.args.has("novsync"):
		Engine.max_fps = 0
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

func _watch_fps() -> void:
	for i in 400000:
		await get_tree().create_timer(0.5, true, false, true).timeout
		if not is_inside_tree(): return
		if d.main._loading: continue
		var f := Engine.get_frames_per_second()
		if f <= 0: continue
		_fps_min = minf(_fps_min, f); _fps_sum += f; _fps_n += 1
		if d.combat_view.active: _fight_fps.append(f)
		elif d.S.phase == "night" and not d.runner.busy: _night_fps.append(f)

func _wait_until(cond: Callable, limit_frames: int, what: String) -> bool:
	var n := 0
	while not cond.call() and n < limit_frames:
		await get_tree().process_frame; n += 1
	if not cond.call(): _fail("기다림 시간 넘음: " + what); return false
	return true

func _run() -> void:
	_log("시작 branch=%s" % branch)
	_watch_fps()
	expect(bool(d.S.vars.get("ACT2_OPEN", false)), "출발 저장: 한양 S1006 세 방향 열림")
	expect((branch == "A") == d.spirits.equipped("ITM_RIT_001"), "출발 저장: 호신부 %s" % ("지님" if branch == "A" else "없음(경주 먼저)"))
	# S3001 경주 장 주막 → 치술령 아래 마을
	prefer = ["치술령 아래 마을"]
	await d.runner.run([{ "event": "S3001" }])
	prefer = []
	expect(d.S.is_flag("case_started") and d.S.has_clue("rumor_lights"), "S3001 사건 기록 · 고개의 불 셋(주모의 말)")
	await shot("s3001_village")
	await go("elder")
	expect(d.S.has_clue("missing_man"), "사라진 숯쟁이(마을 노인의 말)")
	await go("wife")
	# S3002 낮 조사 — 별것 없음
	for id in ["pass_oil", "stone_day", "spur_rag", "kiln_day"]: await go(id)
	for c in ["pass_oil", "stone_day", "spur_rag"]: expect(d.S.has_clue(c), "S3002 낮 " + c)
	expect(d.S.seen.has("S3002"), "장면 S3002")
	await shot("s3002_stone_day")
	# S3003 너럭바위에서 밤
	await go("lookout")
	expect(d.S.phase == "night" and d.S.seen.has("S3003"), "S3003 밤 — 불 셋")
	await _frames(30)
	var lit := 0
	for k in ["l1", "l2", "l3"]:
		if d.case_fn.lights.has(k) and d.case_fn.lights[k].node.visible: lit += 1
	_log("너럭바위에서 보이는 불 %d" % lit)
	expect(d.case_fn._wide, "너럭바위: 넓은 시점")
	await shot("s3003_lookout", 30)
	# 첫째 불(흔들림) — 아낙
	await _wait_until(func(): return d.actors.wife.path.is_empty(), 60 * 60, "아낙이 굽이까지 오름")
	await walk_to(Vector2(-970.0, 2803.0))
	await _frames(30); await _idle()
	expect(d.S.knows("R_SWAY"), "흔들리는 불은 사람의 걸음")
	var wa = d.actors.wife
	_log("아낙 (%.1f, %.1f) shown=%s visible=%s anim=%s 등불=%s" % [wa.pos.x, wa.pos.z, wa.shown, wa.ch.visible, wa.anim, d.case_fn.lights.l1.node.visible])
	expect(wa.shown and Vector2(wa.pos.x, wa.pos.z).distance_to(d.anchor("wife_bend")) < 3.0, "아낙이 고갯길 굽이에 등을 들고 섰다")
	await shot("s3004_wife")
	await go("wife")
	expect(d.S.is_flag("wife_met") and d.S.has_clue("light_wife"), "S3004 아낙(남편을 기다림)")
	d.ui.journal_show(d.journal_data())
	await shot("journal", 10)
	d.ui.journal_close()
	# 둘째 불(신호) — 등성이 싸움
	await walk_to(Vector2(-878.0, 2858.0))
	await _frames(10)
	await _wait_until(func(): return d.S.is_flag("smugglers_resolved"), 60 * 240, "등성이 싸움")
	await _idle()
	expect(d.S.knows("R_BLINK") and d.S.has_clue("smugglers"), "S3005 가렸다 열리는 불은 신호 — 밀수꾼")
	var fr := String(d.S.flags.get("fight_result", ""))
	_log("싸움 결과 %s caught_a=%s caught_b=%s" % [fr, d.S.is_flag("caught_a"), d.S.is_flag("caught_b")])
	if branch == "A": expect(d.S.is_flag("caught_a") or d.S.is_flag("caught_b"), "A: 밀수꾼을 붙잡음(%s)" % fr)
	else: expect(fr == "escaped" and not (d.S.is_flag("caught_a") or d.S.is_flag("caught_b")), "B: 물러남 — 밀수꾼이 달아남(%s)" % fr)
	await go("husband")
	expect(d.S.is_flag("man_rescued") and d.S.has_clue("rescued"), "숯가마 뒤 숯쟁이 구함")
	await shot("s3005_after")
	# 셋째 불 — 망부석 앞에서 기다린다
	await walk_to("stone_front")
	await _wait_until(func(): return d.S.is_flag("light3_seen"), 60 * 120, "셋째 불이 바위 앞에서 꺼짐")
	await _idle()
	expect(d.S.knows("R_STILL") and d.S.has_clue("light_none"), "S3006 흔들리지 않는 불 — 바위 앞에서 꺼짐")
	if branch == "A": expect(d.S.is_flag("figure_seen") and d.S.has_clue("figure"), "A: 호신부 — 형체가 잠깐")
	else: expect(not d.S.is_flag("figure_seen"), "B: 호신물 없음 — 형체 안 보임")
	# S3007 탁본 조각 → S3008 우치·추격
	_watch_shots_g()
	await go("stone_gap")
	await _idle()
	expect(d.S.is_flag("fragment") and d.S.has("ITM_KEY_004"), "S3007 바위 밑 탁본 조각")
	var tr := String(d.S.vars.get("MAIN_MASTER_TRACE", ""))
	expect(tr.contains("GYEONGJU"), "MAIN_MASTER_TRACE += GYEONGJU (%s)" % tr)
	expect(d.S.is_flag("woochi_done"), "S3008 우치 — 추격 끝(%s)" % d.S.flags.get("woochi_chase", ""))
	if branch == "A": expect(String(d.S.flags.get("woochi_chase", "")) == "end", "A: 끝까지 쫓음")
	else: expect(String(d.S.flags.get("woochi_chase", "")) == "lost", "B: 놓침")
	await go("bundle")
	var waited := 0
	while (d.S.phase != "done" or d.ui.modal or d.runner.busy) and waited < 20000:
		await get_tree().process_frame; waited += 1
	snapshot("end")
	await shot("after", 40)
	var o := String(d.S.vars.get("CASE_GYEONGJU_OUTCOME", ""))
	expect(o == branch, "결말 %s (얻은 값 %s, %s)" % [branch, o, d.S.vars.get("CASE_GYEONGJU_DETAIL", "")])
	expect(bool(d.S.vars.get("SKILL_RUBBING", false)) and d.S.has("ITM_TOOL_007"), "보상: 탁본 도구 · SKILL_RUBBING")
	expect(bool(d.S.vars.get("CASE_GYEONGJU_COMPLETE", false)), "CASE_GYEONGJU_COMPLETE")
	expect(bool(d.S.vars.get("SKILL_SNAP_SHOT", false)), "숙련 해금: 빠른 사격(SKILL_SNAP_SHOT)")
	for e in ["S3001", "S3002", "S3003", "S3004", "S3005", "S3006", "S3007", "S3008"]: expect(d.S.seen.has(e), "장면 " + e)
	# 지역 변화(§30)
	expect(d.props.has("p_offering") and d.props.p_offering.get("want", false), "망부석 앞 공양상")
	if branch == "A":
		expect((d.actors.bound_a.shown or d.actors.bound_b.shown), "A: 붙잡힌 밀수꾼이 마당에")
		expect(d.props.p_torch_a.get("want", false), "A: 어귀 횃대")
	else:
		expect(not d.actors.bound_a.shown and not d.actors.bound_b.shown, "B: 붙잡힌 사람 없음")
	expect(d.actors.husband.shown and d.actors.wife.shown, "숯쟁이 부부가 마을에")
	# 탁본(재사용): 망부석·장승
	await _rub_check("gj_mangbuseok", "stone_front")
	await _rub_check("gs_chisul_jangseung_01", Vector2(-1093.1, 2576.0))
	_log("vars=%s" % JSON.stringify({ o = o, detail = d.S.vars.get("CASE_GYEONGJU_DETAIL"), trace = d.S.vars.get("MAIN_MASTER_TRACE"),
		rub = d.S.vars.get("SKILL_RUBBING"), snap = d.S.vars.get("SKILL_SNAP_SHOT"), woochi = d.S.vars.get("MAIN_WOOCHI_KNOWN") }))
	_log("seen=%s" % JSON.stringify(d.S.seen.keys()))
	_log("fps min=%.0f avg=%.0f (n=%d)" % [_fps_min, _fps_sum / maxf(1.0, _fps_n), _fps_n])
	for pair in [["밤 고개", _night_fps], ["싸움", _fight_fps]]:
		var a: Array = pair[1].duplicate()
		if a.is_empty(): continue
		a.sort()
		_log("%s fps min=%d median=%d (n=%d)" % [pair[0], a[0], a[a.size() / 2], a.size()])
	Engine.time_scale = 1.0
	if _fails.is_empty(): printerr("STORYTEST PASS gyeongju:%s outcome=%s detail=%s time=%.0fs" % [branch, o, d.S.vars.get("CASE_GYEONGJU_DETAIL", ""), (Time.get_ticks_msec() - _t0) / 1000.0])
	else: printerr("STORYTEST FAIL gyeongju:%s fails=%s" % [branch, JSON.stringify(_fails)])
	d.main._quit()

# 탁본 대상 곁으로 가서 E(rubbing.gd)
func _rub_check(id: String, at) -> void:
	await _idle()
	d.teleport_to(d.anchor(at), "up")
	await _frames(20)
	var r = d._rub
	r._t = 0.0
	r.update(0.0)
	var tgt = r._target
	if tgt == null or String(tgt.id) != id:
		_fail("탁본 대상 %s 안 잡힘(%s)" % [id, "없음" if tgt == null else String(tgt.id)]); return
	await shot("rubbing_" + id, 10)
	await r.use(tgt)
	var s = Progress.data().get("rubbings", {})
	expect(s is Dictionary and s.has(id), String(tgt.title))

func _watch_shots_g() -> void:
	var w := false
	for i in 200000:
		await get_tree().process_frame
		if not w and d.actors.has("woochi") and d.actors.woochi.shown and d.ui.modal:
			w = true; await shot("s3008_woochi", 2)
		if d.ui._ending.visible and d.ui._ending.modulate.a > 0.95:
			await shot("ending", 1); return

# ---- 사람 적 봇: A는 덤벼 쓰러뜨림(달아나는 자도 쫓는다), B는 등성이에서 물러난다 ----
func combat_bot() -> Dictionary:
	var b = d.combat_view.battle
	if b.mode != "human": return super.combat_bot()
	var pl = b.player
	var out := { move = Vector2.ZERO, held = {}, run = false }
	_bot_dodge_cd -= 1.0 / 60.0
	_log_t += 1.0 / 60.0
	if b.time > 4.0 and not _combat_shot:
		_combat_shot = true
		shot("combat_spur", 2)
	if _log_t > 4.0:
		_log_t = 0.0
		_log("싸움 t=%.0f 나 hp=%.0f st=%.0f %s / %s fps=%d" % [b.time, pl.hp, pl.st, pl.state,
			JSON.stringify(b.foes.map(func(fo): return [fo.id, fo.state, roundf(fo.hp)])), Engine.get_frames_per_second()])
	if not pl.alive: return out
	if branch == "B":
		if b.time < 3.0:
			out.held = { guard = true }; return out
		var away: Vector2 = pl.pos - Vector2(b.arena.x, b.arena.z)
		if away.length() < 0.5: away = Vector2(-1, -0.3)
		out.move = Vector2(-1, -0.4).normalized() if away.x > -0.5 else away.normalized()
		out.run = true
		return out
	var tg = null; var bd := INF
	for fo in b.foes:
		if not fo.active: continue
		var dd: float = (fo.pos - pl.pos).length()
		if dd < bd: bd = dd; tg = fo
	if tg == null: return out
	var v: Vector2 = tg.pos - pl.pos
	var dist := v.length()
	var dir := v / maxf(dist, 0.001)
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

# ---- 추격 봇: A는 쫓는 길을 따라 달리고, B는 서서 놓친다 ----
func chase_bot(c, dt: float) -> void:
	if _bot_s < 0.0: _bot_s = c.prog
	_chase_log_t += dt
	if _chase_log_t > 2.0:
		_chase_log_t = 0.0
		_log("추격 seg=%d %s 앞섬 %.1f 벗어남 %.1f fps=%d" % [c.seg_i, c.segs[c.seg_i].mode, c.lead, c.off, Engine.get_frames_per_second()])
	if branch == "B" or not c.started:
		d.main.player.set_anim("idle"); return
	_bot_s = minf(_bot_s + 5.0 * dt, c.follow_total)
	var p: Vector2 = c.follow_point(_bot_s)
	var prev := Vector2(d.main.player_pos.x, d.main.player_pos.z)
	if d.world.blocked(p.x, p.y, 0.3): _log("추격 길 막힘 (%.1f, %.1f)" % [p.x, p.y])
	d.set_player_pos(Vector3(p.x, d.world.height_at(p.x, p.y), p.y))
	d.main.player.facing = d.main.facing_from(p.x - prev.x, p.y - prev.y, d.main.player.facing)
	d.main.player.set_anim("run")
