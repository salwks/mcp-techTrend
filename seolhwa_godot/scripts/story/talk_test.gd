# 고을 사람 말 걸기 시험(region_main --talktest=<거점>,<거점>… — tools/run_story_tests.sh talk:*). 헤드리스로 돈다.
#   1 '앞' 상태(새 저장): 거점마다 가까운 고을 사람 곁으로 가서 E 대상이 되는지 보고 말을 건다(ambient_talk.talk).
#     같은 사람에게 곧장 한 번 더 — '아까 말했잖소'거나 다른 줄이어야 한다.
#   2 이야기 인물 「…」(사건이 있는 공간): 고을 사람과 같은 그림을 쓰는 인물에 테두리 빛, 새 말이 있는 인물 곁에서 표시가 뜨고,
#     안내 '끔'이면 사라지고, 말을 들으면 사라지고, 결말 상태를 얹은 뒤 새 말이 생기면 다시 뜬다.
#   3 '뒤' 상태: --talkfixture(story/*/test_*.json 저장)의 공통 변수 + --talkvars를 얹고 다시 말을 건다.
#     --talkexpect=var  결말에 따라 달라지는 소문(rumors_data의 var)이 고을 사람 입에서 나오고 기록책에 '들음 — <말한 사람>'
#     --talkexpect=need need 조건이 붙은 소문은 '앞'에서는 안 나오고 '뒤'에서는 나온다
#   늘: 말한 줄이 고루 다르다(서로 다른 줄 비율), 결말이 난 뒤 '아직' 칸 반응이 나오지 않는다, 말 건 사람 수 ≥ --talkmin(기본 8).
#   통과하면 "TALKTEST PASS", 아니면 "TALKTEST FAIL <까닭>".
extends RefCounted

const Progress := preload("res://scripts/region/progress.gd")
const Rumors := preload("res://story/rumors_data.gd")
const Data := preload("res://story/ambient_talk_data.gd")
const GameSettings := preload("res://scripts/story/game_settings.gd")

var main
var d
var _fails: Array = []
var _talks: Array = []       # { phase, key, kind, src, speaker, lines, rumor, var }
var _talked := {}            # 칸 키 → true
var _target_ok := 0
var _target_try := 0
var _phase := "pre"

func _init(m) -> void:
	main = m

func _fail(why: String) -> void:
	_fails.append(why)
	print("TALKTEST check FAIL ", why)

func _ok(cond: bool, why: String) -> void:
	if cond: print("TALKTEST check ok ", why)
	else: _fail(why)

func _wait_load() -> void:
	await main._wait_frames(10)
	var n := 0
	while main._loading and n < 6000:
		await main._wait_frames(1); n += 1
	n = 0
	while (main.world.stats.jobs > 0 or main.placement.busy()) and n < 900:
		await main._wait_frames(1); n += 1

func run(spec: String) -> void:
	Engine.max_fps = 0
	GameSettings.test_override = { guide = "early", help = "normal" }
	Progress.data().heard = []
	await _wait_load()
	d = main.story
	var npc = main.npcs_amb
	if d == null or npc == null:
		_finish("이야기 또는 주변 인물 없음"); return
	d.ui.auto = true
	for r in Rumors.for_space(String(d.space_id), main.world.region): d._rumor_seen[String(r.id)] = true   # 엿듣기는 끄고 말 걸기만 본다
	print("TALKTEST start space=%s case=%s lines_in_data=%d" % [d.space_id, d.case_id, Data.count_lines()])
	var places: Array = Array(spec.split(",", false))
	var per := maxi(3, int(ceil(float(main.args.get("talkmin", "8")) / maxf(1.0, places.size()))) + 1)
	# 1 앞
	for sid in places: await _round(String(sid), per)
	# 2 이야기 인물 표시
	var marker_actor := ""
	if d.case_id != "" and d.S != null: marker_actor = await _markers_before()
	# 3 뒤
	_apply_post()
	_phase = "post"
	if marker_actor != "": await _markers_after(marker_actor)
	for sid in places: await _round(String(sid), per, true)
	_checks()
	_finish("")

# ---- 거점 둘레 사람들에게 말 걸기 ----
func _round(sid: String, n: int, gossip_first := false) -> void:
	var c = _settle(sid)
	if c == null:
		_fail("거점 없음 " + sid); return
	main.teleport(c.x, c.y)
	await main._wait_frames(5)
	var npc = main.npcs_amb
	var t := 0
	while t < 900:
		if _pick(c, false) >= 0: break
		await main._wait_frames(2); t += 2
	var done := 0
	var tries := 0
	while done < n and tries < n * 3:
		tries += 1
		var key := _pick(c, gossip_first)
		if key < 0:
			await main._wait_frames(20); continue
		var ag: Dictionary = npc.agents[key]
		var ap := Vector2(ag.pos.x, ag.pos.z)
		var off := Vector2(0.9, 0.0).rotated(float(key % 8) * PI / 4.0)
		main.teleport(ap.x + off.x, ap.y + off.y)
		await main._wait_frames(14)   # 다음 훑기(0.4초)까지 — 가까운 사람 목록이 새로 든다
		if not npc.agents.has(key): continue
		# E 대상이 되는가(배·말 안내가 있으면 비켜 주니 셈하지 않는다)
		if String(main.boats.prompt) == "" and String(main.horse_ride.prompt) == "":
			_target_try += 1
			var tg = d._target
			if tg != null and String(tg.kind) == "ambient": _target_ok += 1
		await d.ambient.talk(key)
		_log_talk(sid)
		_talked[key] = true
		done += 1
		# 첫 사람에게는 곧장 한 번 더
		if done == 1 and npc.agents.has(key):
			var first: Dictionary = d.ambient.last.duplicate()
			await main._wait_frames(3)
			await d.ambient.talk(key)
			var again: Dictionary = d.ambient.last
			_log_talk(sid)
			_ok(String(again.src) == "repeat" or " / ".join(again.lines) != " / ".join(first.lines), "같은 사람 다시 — %s" % again.src)
		await main._wait_frames(4)
	print("TALKTEST round %s %s talked=%d" % [_phase, sid, done])

func _settle(sid: String) -> Variant:
	for s in main.world.region.get("settlements", []):
		if String(s.get("id", "")) == sid: return Vector2(float(s.x), float(s.z))
	return null

# 거점 70m 안 아직 말 안 건 사람(가까운 순, gossip_first면 소문 옮기는 사람 먼저)
func _pick(c: Vector2, gossip_first: bool) -> int:
	var npc = main.npcs_amb
	var best := -1; var bd := INF
	var pp := Vector2(main.player_pos.x, main.player_pos.z)
	for key in npc.agents:
		var ag: Dictionary = npc.agents[key]
		if ag.animal or ag.mode == "gull" or _talked.has(key): continue
		var p := Vector2(ag.pos.x, ag.pos.z)
		if p.distance_to(c) > 90.0: continue
		var dd := p.distance_to(pp)
		if gossip_first and not Data.GOSSIP.has(String(ag.kind)): dd += 500.0
		if dd < bd: bd = dd; best = key
	return best

func _log_talk(sid: String) -> void:
	var l: Dictionary = d.ambient.last.duplicate(true)
	l.phase = _phase; l.place = sid
	_talks.append(l)

# ---- '뒤' 상태 얹기(저장 파일의 공통 변수 + --talkvars) ----
func _apply_post() -> void:
	var vars := {}
	if main.args.has("talkfixture"):
		var j = JSON.parse_string(FileAccess.get_file_as_string(String(main.args.talkfixture)))
		if j is Dictionary: vars = j.get("vars", {}).duplicate(true)
	for kv in String(main.args.get("talkvars", "")).split(",", false):
		var p := kv.split("=", true, 1)
		if p.size() < 2: continue
		var v: Variant = p[1]
		if p[1] == "true": v = true
		elif p[1] == "false": v = false
		vars[p[0]] = v
	for k in vars:
		Progress.set_var(k, vars[k])
		if d.S != null: d.S.vars[k] = vars[k]
	d.ambient._recent.clear()
	if d.S != null: d.mark_dirty()
	print("TALKTEST post vars=%d %s" % [vars.size(), vars.keys().filter(func(k): return String(k).begins_with("CASE_") or String(k).ends_with("_OPEN"))])

# ---- 이야기 인물 「…」 ----
# 조건이 참이 될 때까지(최대 sec초) — 무거운 기계에서도 표시 갱신(0.4초 주기)을 기다린다
func _wait_until(f: Callable, sec := 3.0) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < sec * 1000.0:
		if f.call(): return true
		await main._wait_frames(1)
	return f.call()

func _wait_sec(sec: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < sec * 1000.0: await main._wait_frames(1)

func _say_only(a: Dictionary) -> bool:
	for t in a.spec.get("talk", []):
		if not d.runner.cond(t.get("when", true)): continue
		for st in t.get("steps", []):
			for k in st:
				if not ["say", "lines", "when"].has(k): return false
		return true
	return false

func _markers_before() -> String:
	# 테두리 빛: 고을 사람과 같은 그림을 쓰는 이야기 인물
	var generic := 0; var lit := 0
	for id in d.actors:
		var a: Dictionary = d.actors[id]
		if d.GENERIC_KINDS.has(String(a.ch.kind)):
			generic += 1
			if a.ch.accent != null: lit += 1
	_ok(generic == 0 or lit == generic, "흔한 그림 이야기 인물 테두리 빛 %d/%d" % [lit, generic])
	await _wait_sec(0.6)
	var pend := []
	for id in d.actors:
		if d.talk_pending(id): pend.append(id)
	_ok(not pend.is_empty(), "새 말 있는 이야기 인물 %s" % [pend])
	# 말만 하는(선택·사건 없는) 인물, 되도록 결말에 따라 말이 바뀌는 인물
	var pick := ""
	for id in pend:
		var a: Dictionary = d.actors[id]
		if not a.shown or not _say_only(a): continue
		var outcome_dep := false
		for t in a.spec.get("talk", []):
			var w := str(t.get("when", ""))
			if w.contains("OUTCOME") or w.contains("out("): outcome_dep = true
		if pick == "" or outcome_dep: pick = id
		if outcome_dep: break
	if pick == "":
		print("TALKTEST note 말만 하는 이야기 인물이 없어 표시 시험을 건너뜀"); return ""
	var a: Dictionary = d.actors[pick]
	d.teleport_to(Vector2(a.pos.x + 2.0, a.pos.z + 1.5))
	await _wait_until(func(): return d.onboard.talk_marked.has(pick))
	if not d.onboard.talk_marked.has(pick):
		var wp := Vector3(a.pos.x, main.world.height_at(a.pos.x, a.pos.z) + 2.55, a.pos.z)
		print("TALKTEST dbg vis=%s pend=%s d=%.1f frustum=%s busy=%s modal=%s cut=%s marked=%s" % [a.ch.visible, d.talk_pending(pick),
			Vector2(main.player_pos.x - a.pos.x, main.player_pos.z - a.pos.z).length(), main.cam.is_position_in_frustum(wp),
			d.runner.busy, d.ui.modal, d._cut, d.onboard.talk_marked])
	_ok(d.onboard.talk_marked.has(pick), "「…」 뜸 — %s(%s)" % [a.name, pick])
	GameSettings.test_override.guide = "off"
	await _wait_until(func(): return not d.onboard.talk_marked.has(pick))
	_ok(not d.onboard.talk_marked.has(pick), "안내 끔 — 「…」 없음")
	GameSettings.test_override.guide = "minimal"
	await _wait_until(func(): return d.onboard.talk_marked.has(pick))
	_ok(d.onboard.talk_marked.has(pick), "안내 최소 — 작게 뜸")
	GameSettings.test_override.guide = "early"
	var t := 0
	while d.runner.busy and t < 600:
		await main._wait_frames(1); t += 1
	await d.interact(pick)
	print("TALKTEST talked %s=%d seen=%s" % [pick, int(d.S.talked.get(pick, 0)), d.S.seen.get("_talk", {}).get(pick, [])])
	await _wait_until(func(): return not d.onboard.talk_marked.has(pick))
	_ok(not d.talk_pending(pick) and not d.onboard.talk_marked.has(pick), "들은 뒤 「…」 사라짐 — %s" % pick)
	return pick

func _markers_after(id: String) -> void:
	await _wait_sec(0.6)
	var dep := false
	for t in d.actors[id].spec.get("talk", []):
		var w := str(t.get("when", ""))
		if w.contains("OUTCOME") or w.contains("out("): dep = true
	if dep: _ok(d.talk_pending(id), "결말 뒤 새 말 — 「…」 다시(%s)" % id)
	else: print("TALKTEST note %s는 결말에 따라 말이 바뀌지 않음" % id)

# ---- 판정 ----
func _checks() -> void:
	var n := _talks.size()
	var uniq := {}
	for t in _talks: uniq[" / ".join(t.lines)] = true
	var people := _talked.size()
	_ok(people >= int(main.args.get("talkmin", "8")), "말 건 사람 %d명(대화 %d번)" % [people, n])
	_ok(n > 0 and float(uniq.size()) / n >= 0.6 and uniq.size() >= mini(n, 8), "줄이 고루 다름 %d/%d" % [uniq.size(), n])
	_ok(_target_try == 0 or float(_target_ok) / _target_try >= 0.6, "E 대상 %d/%d" % [_target_ok, _target_try])
	var srcs := {}
	for t in _talks: srcs[String(t.src)] = int(srcs.get(String(t.src), 0)) + 1
	print("TALKTEST sources ", srcs)
	# 결말이 난 뒤에는 '아직' 칸 반응이 나오지 않는다
	var vars: Dictionary = Progress.vars()
	for o in Data.OUTCOME:
		if not (o.space as Array).has(String(d.space_id)): continue
		if str(vars.get(String(o.var), "")) == "": continue
		var pre := []
		for key in ["lines", "lines_hage"]:
			for e in o.get(key, {}).get("", []): pre.append(" / ".join(e) if e is Array else String(e))
		for t in _talks:
			if t.phase == "post" and pre.has(" / ".join(t.lines)): _fail("결말 뒤에 '아직' 반응: " + " / ".join(t.lines))
	var expect := String(main.args.get("talkexpect", ""))
	var heard: Array = Progress.heard()
	var jd: Dictionary = d.journal_data()
	var travel_blocks: Array = []   # 기록책 어느 쪽에 있든('사람의 말' 쪽이 따로 생겨도) 들음 항목을 찾는다
	for pg in jd.pages: travel_blocks.append_array(pg.get("blocks", []))
	var rumor_talks := _talks.filter(func(t): return t.src == "rumor")
	for t in rumor_talks:
		var found := false
		for b in travel_blocks:
			if String(b.get("t", "")) == "entry" and String(b.get("tag", "")) == "heard" and String(b.get("by", "")) == String(t.speaker) \
					and String(b.get("text", "")).contains(String(t.rumor_line)): found = true
		_ok(found, "기록책 '◇ 들음 — %s' %s" % [t.speaker, t.rumor_line])
	_ok(heard.size() >= rumor_talks.size(), "들은 소문 %d개 저장" % heard.size())
	if expect == "var":
		var post_var := rumor_talks.filter(func(t): return t.phase == "post" and String(t.get("rvar", "")) != "")
		var pre_var := rumor_talks.filter(func(t): return t.phase == "pre" and String(t.get("rvar", "")) != "")
		_ok(not post_var.is_empty(), "결말 소문이 고을 사람 입에서 %s" % [post_var.map(func(t): return "%s: %s" % [t.speaker, t.rumor_line])])
		_ok(pre_var.is_empty(), "결말 전엔 결말 소문 없음")
	elif expect == "need":
		var needed := {}
		for r in Rumors.RUMORS:
			if String(r.space) == String(d.space_id) and r.has("need"): needed[String(r.id)] = true
		var pre_n := rumor_talks.filter(func(t): return t.phase == "pre" and needed.has(String(t.rumor)))
		var post_n := rumor_talks.filter(func(t): return t.phase == "post" and needed.has(String(t.rumor)))
		_ok(pre_n.is_empty(), "need 소문은 조건 전엔 없음")
		_ok(not post_n.is_empty(), "need 소문이 조건 뒤에 %s" % [post_n.map(func(t): return "%s: %s" % [t.speaker, t.rumor_line])])

func _finish(why: String) -> void:
	if why != "": _fails.append(why)
	for t in _talks: print("TALKTEST line %s %s %s [%s] %s" % [t.phase, t.place, t.src, t.speaker, " / ".join(t.lines)])
	if _fails.is_empty(): print("TALKTEST PASS talks=%d people=%d" % [_talks.size(), _talked.size()])
	else: print("TALKTEST FAIL ", "; ".join(_fails))
	main._quit()
