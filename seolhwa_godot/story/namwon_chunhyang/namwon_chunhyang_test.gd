# 대본 시험(--storytest=namwon_chunhyang:<갈래>) — 「남원의 약속」 PART I.
#   godot --path seolhwa_godot res://scenes/region.tscn -- --region=JL_NAMWON_UNBONG --storytest=namwon_chunhyang:a
#   a     : 진입 판정(choose — 한양 책방 완료면, 재기획 D3) → C0001 단오(군중 28·차림·밝은 음악) → 오누이 뒤 남원 사람 → 1A → 부딪힘(주워 줌 · 맞소 · 같이 감) → 2A 거절 →
#           몽룡 → 저녁 월매 집 → 편지(열 수 없음) · 웃음 · 함께 걷기 → 밤 백년가약(들었습니다 → vow_witness · vow_heard) → 소식 · 5A 이별 → PART1_COMPLETE →
#           춘향에게 “기다리실 겁니까?” → PART II 없음 · 떠나면 LEFT_AFTER_PART1 · 기록책
#   b     : 다른 선택 — 지나감 · 혼자 가시오(나중에 그네 곁) · 고개 끄덕임 · 아무 말 없음
#   after : PART I 끝 + 떠남(다른 고을은 아직 — PART II 열림 조건 거짓)으로 다시 남원 — PART II는 아무것도 서지 않는다. 남원 사람 말 · 춘향 집
#   p2a · p2b · p2c · ctl : PART II-A(namwon_chunhyang_p2a_test.gd)
#   iib1 · iib2 · iib3 · iibctl : PART II-B(namwon_chunhyang_p2b_test.gd — 술·쌀·상소 ~ 광한루)
# 저장은 --savefile(run_story_tests.sh) — prepare가 남원·한양 끝 상태로 꾸민다. 결과는 STORYTEST PASS/FAIL.
# 화면 검토: --storyshots=shots/chunhyang_part1(창 모드) — 사건 함수의 _cut(이름)에서 찍는다.
extends Node

const Progress := preload("res://scripts/region/progress.gd")
const CaseRegistry := preload("res://scripts/story/case_registry.gd")
const JournalBook := preload("res://scripts/story/journal_book.gd")
const Rumors := preload("res://story/rumors_data.gd")
const P2T := preload("res://story/namwon_chunhyang/namwon_chunhyang_p2a_data.gd")

var d
var branch := "A"
var _t0 := 0
var _fails: Array = []
var prefer: Array = []
var choice_log: Array = []   # [물음, [갈래 글…]] — 시험이 갈래 말씨를 본다(II-B 본 것/들은 것)
var _n := 0

static func prepare(_dir) -> void:
	Progress.data()
	for kv in [["MAIN_MASTER_TRACE", "HANYANG"], ["SKILL_BEAST_TRACE", true], ["CASE_NAMWON_OUTCOME", "C"], ["CASE_NAMWON_DETAIL", "C"],
			["CASE_NAMWON_MORNING", "unknown"], ["CASE_NAMWON_COMPLETE", true], ["CASE_HANYANG_OUTCOME", "followed"], ["CASE_HANYANG_BOOKSHOP_COMPLETE", true],
			["ACT2_OPEN", true], ["MAIN_WOOCHI_KNOWN", true], ["SKILL_GUARD_SHOVE", true], ["SKILL_QUICK_THROW", true]]:
		Progress.set_var(kv[0], kv[1])
	Progress.data().cases["namwon"] = { "v": 2, "phase": "done", "flags": { "case_started": true, "resolved": true }, "clues": [], "rules": [],
		"items": { "ITM_TOOL_009": 1, "COIN": 7 }, "world": {}, "talked": {}, "notes": [], "seen": { "S0010": true }, "time": 8.0 }
	Progress.data().cases["hanyang"] = { "v": 2, "phase": "done", "flags": { "case_started": true }, "clues": [], "rules": [], "items": {}, "world": {},
		"talked": {}, "notes": [], "seen": { "S1006": true }, "time": 12.0 }
	Progress.save()

func _init(director, spec: String) -> void:
	d = director
	var p := spec.split(":")
	branch = (p[1] if p.size() > 1 else "a").to_upper()
	name = "story_test"

func begin() -> void:
	d.ui.auto = true
	d.ui.auto_choice = choose
	if d.main.args.has("storyshots") and DisplayServer.get_name() != "headless": d.ui.auto_real = false
	Engine.time_scale = float(d.main.args.get("storyspeed", "2.5"))
	_t0 = Time.get_ticks_msec()
	_run.call_deferred()

func _log(s: String) -> void:
	printerr("STORYTEST [%s] %6.1fs %s" % [branch, (Time.get_ticks_msec() - _t0) / 1000.0, s])

func choose(_prompt: String, labels: Array) -> int:
	choice_log.append([_prompt, labels.duplicate()])
	for want in prefer:
		for i in labels.size():
			if labels[i] != "" and String(labels[i]).contains(want): return i
	for i in labels.size():
		if labels[i] != "" and not String(labels[i]).contains("그만"): return i
	return 0

func _idle() -> void:
	var n := 0
	while (d.runner.busy or d.ui.modal) and n < 60000:
		await get_tree().process_frame
		n += 1
	await get_tree().process_frame

func _frames(n: int) -> void:
	for i in n: await get_tree().process_frame

func expect(c: bool, what: String) -> void:
	_n += 1
	if c: _log("ok " + what)
	else: _fails.append(what); _log("FAIL " + what)

# 이야기 인물·조사 대상 곁으로 가서 E
func go(id: String, dz := 1.2) -> void:
	await _idle()
	var p: Vector2 = d.anchor(id) if not d.actors.has(id) else Vector2(d.actors[id].pos.x, d.actors[id].pos.z)
	d.teleport_to(Vector2(p.x, p.y + dz), "up")
	await _frames(8)
	await _idle()
	d._refresh()
	var ok := false
	for t in d._targets():
		if t.id == id: ok = true
	if not ok:
		_fails.append("대상 없음/조건 안 맞음: " + id); _log("FAIL 대상 없음 " + id); return
	_log("interact " + id)
	d.interact(id)
	await _frames(2)
	await _idle()

func walk_to(at) -> void:
	await _idle()
	d.teleport_to(at, "up")
	await _frames(12)
	await get_tree().create_timer(0.45).timeout
	await _idle()
	await _frames(4)
	await _idle()

# 사건 함수의 _cut(이름) — 화면 검토일 때만 찍는다
func cut(nm: String) -> void:
	if p2t != null: await _probe_p2(nm)
	if p2bt != null: await p2bt.probe_cut(nm)
	if nm == "02_1A_crowd_swing": _probe_1a()
	if nm == "_1a_end":
		var w = d.main.weather
		probe_1a_end = { pos = d.main.player_pos, wx = w.snapshot() if w != null else {}, fog_on = d.cut_fog_on() }
		return
	if not d.main.args.has("storyshots") or DisplayServer.get_name() == "headless": return
	var ts := Engine.time_scale
	Engine.time_scale = 1.0
	await _frames(50)
	var dir: String = d.main._abs(String(d.main.args.storyshots))
	DirAccess.make_dir_recursive_absolute(dir)
	get_viewport().get_texture().get_image().save_png(dir.path_join("%s.png" % nm))
	_log("SHOT " + nm)
	Engine.time_scale = ts

# PART II-A 컷의 그 순간(6A 행렬 짜임 · 점고 8A·조작·줄 묶임 · 곤장 컷 수)
func _probe_p2(nm: String) -> void:
	var pr: Dictionary = p2t.probe
	if nm == "03_6A_procession":
		var shot = d.main.rig.shot
		var gz := INF
		if d.props.has("p_gama") and d.props.p_gama.node != null: gz = d.props.p_gama.node.global_position.z
		var west := 0; var east := 0
		for id in ["on_1", "on_2", "on_3", "on_4", "on_5", "on_6", "on_7", "on_8"]:
			var a = d.actors.get(id)
			if a == null or not a.shown: continue
			if a.pos.x < -3228.0: west += 1
			else: east += 1
		var amb = d.main.get("npcs_amb")
		pr["6a_amb"] = { amb = amb != null, agents = amb.agents.size() if amb != null else 0, zone_on = d.ambient_zones().has("ch_proc_road"),
			inzone = amb.count_in({ "path": P2T.PROC_PATH, "width": P2T.PROC_CLEAR_W }) if amb != null else -1 }
		pr["6a"] = { shot = shot != null, cam_h = (shot.pos.y - d.world.height_at(shot.pos.x, shot.pos.z)) if shot != null else 99.0,
			pojol_z = d.actors.proc_pojol_a.pos.z, gama_z = gz, porter_z = d.actors.proc_porter_2.pos.z, west = west, east = east,
			gama_node = gz != INF }
	elif nm == "06_8A_jeomgo":
		var o = d.main.rig.override if d.main.rig.override != null else {}
		var ctl: bool = d.case_fn.controllable()
		var nline := 0
		for i in 6:
			var a = d.actors.get("gisaeng_%d" % (i + 1))
			if a != null and Vector2(a.pos.x, a.pos.z).distance_to(d.anchor("ch_gisaeng_%d" % (i + 1))) < 0.6: nline += 1
		# 줄을 벗어나 본다 → 끌려온다
		var p0 := Vector2(d.main.player_pos.x, d.main.player_pos.z)
		var pulls0: int = d.case_fn.leash_pulls
		d.set_player_pos(Vector3(p0.x + 5.0, d.main.player_pos.y, p0.y + 3.0))
		await _frames(4)
		var back: float = Vector2(d.main.player_pos.x, d.main.player_pos.z).distance_to(d.anchor("ch_player_saryeong"))
		pr["jeomgo"] = { pitch = float(o.get("pitch", -1)), dist = float(o.get("distance", -1)), ctl = ctl, pulled = back <= 1.7 and d.case_fn.leash_pulls > pulls0, gisaeng_line = nline }
		var post: Vector2 = d.anchor("ch_player_saryeong")
		d.set_player_pos(Vector3(post.x, d.world.height_at(post.x, post.y), post.y))
		d.main.player.facing = "right"
		await _frames(2)
	elif nm.begins_with("10") and nm.contains("gonjang"):
		pr["gonjang_cuts"] = int(pr.get("gonjang_cuts", 0)) + 1
		if nm == "10b_gonjang_hand": pr["rope_10b"] = await _rope_probe()
	elif nm == "10e_wide_rope":
		pr["rope_wide"] = await _rope_probe()
	elif nm == "11_arm_choice":
		pr["rope_arm"] = await _rope_probe()

# 포승 소품 그 순간: 상태·쥔 사람·보임·화면 안(줄 가운데가 카메라 틀 안)
func _rope_probe() -> Dictionary:
	await _frames(2)
	var cf = d.case_fn
	var m: MeshInstance3D = cf.rope_mesh
	var vis: bool = m != null and m.visible and m.mesh != null
	var r: Dictionary = cf.rope_info.duplicate()
	var inframe := 0   # 줄 위 다섯 점 중 카메라 틀 안(손 쪽 끝부터)
	if vis and r.has("a"):
		for i in 5:
			var t := (i + 0.5) / 5.0
			var q: Vector3 = (r.a as Vector3).lerp(r.b, t) - Vector3(0, float(r.sag) * 4.0 * t * (1.0 - t), 0)
			if d.main.cam.is_position_in_frustum(q): inframe += 1
	r.erase("a"); r.erase("b")
	r["visible"] = vis; r["inframe"] = inframe
	return r

# 1A 컷 한가운데(자막 하나 뒤 — 군중 LOD가 여러 프레임 돈 뒤): 플레이어 자리 · 안개 · 1A 틀 안 군중
var probe_1a := {}
var probe_1a_end := {}
func _probe_1a() -> void:
	var cam: Camera3D = d.main.cam
	var cr = d.main.crowd
	var inframe := 0; var alive := 0; var dead := []; var by_cam := 0
	if cr != null and cam != null:
		var far := 60.0
		var pp: Vector3 = d.main.player_pos
		for m in cr.members("dano_market"):
			var p2: Vector2 = m.pos2
			var p3 := Vector3(p2.x, d.world.height_at(p2.x, p2.y) + 1.0, p2.y)
			if not cam.is_position_in_frustum(p3): continue
			inframe += 1
			if String(m.lod) in ["active", "reduced"] and m.ch != null and m.ch.visible:
				alive += 1
				if Vector2(p2.x - pp.x, p2.y - pp.z).length() > far: by_cam += 1   # 플레이어 거리로만 쟀으면 숨었을 사람
			else: dead.append("%s@%.0f(%s)" % [String(m.lod), Vector2(p2.x - pp.x, p2.y - pp.z).length(), String(m.get("role", ""))])
	var chs := {}
	if d.actors.has("chunhyang") and cam != null:
		var ch = d.actors.chunhyang.ch
		var cp3: Vector3 = ch.position + Vector3(0, 0.8, 0)
		chs = { vis = ch.visible, shown = d.actors.chunhyang.shown, pos = [snappedf(cp3.x, 0.1), snappedf(cp3.y, 0.1), snappedf(cp3.z, 0.1)],
			in_frame = cam.is_position_in_frustum(cp3), screen = cam.unproject_position(cp3), dist = snappedf(cam.global_position.distance_to(cp3), 0.1) }
	var w = d.main.weather
	probe_1a = { pos = d.main.player_pos, visible = d.main.player.visible, inframe = inframe, alive = alive, dead = dead,
		fogm = float(w.cur.fogm) if w != null else -1.0, fog_on = d.cut_fog_on(), stats = cr.stats.duplicate() if cr != null else {} }
	_log("1A probe " + JSON.stringify({ chunhyang = str(chs), inframe = inframe, alive = alive, by_cam = by_cam, dead = dead, fogm = probe_1a.fogm, stats = probe_1a.stats }))

# 지금 고를 talk 항목의 첫 대사(인물의 말이 맞는지)
func first_line(id: String) -> String:
	var a: Dictionary = d.actors.get(id, {})
	for t in a.get("spec", {}).get("talk", []):
		if d.runner.cond(t.get("when", true)):
			for st in t.get("steps", []):
				if st is Dictionary and st.has("say"): return String((st.get("lines", []) as Array)[0])
			return ""
	return ""

func _gated_on(id: String) -> bool:
	var e = d.main.placement.gated.get(id)
	return e != null and not bool(e.get("off", false))

func _gate_off(id: String) -> bool:
	var e = d.main.placement.gated.get(id)
	return e == null or bool(e.get("off", false))

func _done() -> void:
	Engine.time_scale = 1.0
	if _fails.is_empty(): printerr("STORYTEST PASS namwon_chunhyang:%s checks=%d time=%.0fs" % [branch, _n, (Time.get_ticks_msec() - _t0) / 1000.0])
	else: printerr("STORYTEST FAIL namwon_chunhyang:%s fails=%s" % [branch, JSON.stringify(_fails)])
	d.main._quit()

# ---------------------------------------------------------------------------
var p2t = null   # PART II-A 시험(namwon_chunhyang_p2a_test.gd)
var p2bt = null  # PART II-B 시험(namwon_chunhyang_p2b_test.gd)
func _run() -> void:
	expect(d.case_id == "namwon_chunhyang", "오누이·한양 뒤 남원 — 춘향이 도는 사건")
	if branch == "AFTER": await _run_after(); return
	if branch.begins_with("IIB"):
		p2bt = load("res://story/namwon_chunhyang/namwon_chunhyang_p2b_test.gd").new(self, branch)
		await p2bt.run(); return
	if branch.begins_with("P2") or branch == "CTL":
		p2t = load("res://story/namwon_chunhyang/namwon_chunhyang_p2a_test.gd").new(self, branch)
		await p2t.run(); return
	_entry_gate()
	await d.runner.run([{ "event": "C0001" }])
	await _frames(6); await _idle()
	expect(d.S.phase == "dano" and d.S.is_flag("case_started"), "C0001 → 단계 dano · 사건 기록")
	expect(d.case_fn.music_wanted() == "bgm_dano_bright", "밝은 단오 음악")
	# 단오 장터(화면 검토) → 단오 차림·군중(광한루 앞으로 가서)
	if branch == "A":
		await walk_to([-3262.0, 403.0])
		d.main.player.facing = "left"
		await cut("01_festive_namwon")
	await walk_to([-3236.0, 452.0])
	await _frames(20)
	var cr = d.main.crowd
	expect(cr != null and cr.is_shown("dano_market"), "단오 군중이 선다(dano)")
	expect(cr != null and cr.members("dano_market").size() == 28, "단오 군중 28명(확정)")
	expect(cr != null and not cr.is_shown("byeon_banquet"), "잔치 군중은 없다")
	expect(_gated_on("ti_streamers_ground") and _gated_on("ti_swing") and _gated_on("ti_ssireum"), "단오 차림(색천·그네·씨름판)")
	if branch == "A":
		await _aftermath_npcs()
		await walk_to([-3236.0, 452.0])
	# §4 1A
	await walk_to("ch_vista_in")
	expect(d.S.is_flag("vista_seen") and d.S.has_clue("dano"), "C0101 1A — 단오장")
	var vp: Vector3 = d.case_fn.vista_pp
	expect(not probe_1a.is_empty(), "1A 컷 한가운데를 들여다봄")
	expect(not probe_1a.is_empty() and not probe_1a_end.is_empty() and probe_1a.pos == vp and probe_1a_end.pos == vp,
		"1A 컷 앞·가운데·뒤 플레이어 자리가 똑같다(옮기지 않음) %s / %s / %s" % [vp, probe_1a.get("pos"), probe_1a_end.get("pos")])
	expect(not probe_1a.is_empty() and bool(probe_1a.visible) and d.main.player.visible, "1A 동안 플레이어를 숨기지 않는다")
	expect(not probe_1a.is_empty() and int(probe_1a.inframe) >= 10 and int(probe_1a.alive) == int(probe_1a.inframe),
		"1A 틀 안 단오 군중이 컷 동안 살아 있다(카메라 기준 LOD) %d/%d %s" % [int(probe_1a.get("alive", 0)), int(probe_1a.get("inframe", 0)), str(probe_1a.get("dead", []))])
	expect(not probe_1a.is_empty() and bool(probe_1a.fog_on) and absf(float(probe_1a.fogm) - d.case_fn.FOG_1A) < 0.01,
		"1A 컷 동안만 안개 옅게 fogm=%.2f" % float(probe_1a.get("fogm", -1.0)))
	var wx0: Dictionary = d.cut_fog_from
	var wx1: Dictionary = probe_1a_end.get("wx", {})
	expect(not wx0.is_empty() and not probe_1a_end.is_empty() and not bool(probe_1a_end.fog_on) and probe_1a_end.pos == vp
			and JSON.stringify(wx0) == JSON.stringify(wx1),
		"1A 컷이 끝나면 바로 원래 날씨·안개(강제 여부·값까지) %s → %s" % [JSON.stringify(wx0), JSON.stringify(wx1)])
	# §5~§8
	prefer = ["주워 준다", "맞소", "같이 가 주지"] if branch == "A" else ["그냥 지나간다", "혼자 가시오"]
	await walk_to([-3263.0, 433.0])
	await _idle()
	expect(d.S.is_flag("bump_done") and d.S.is_flag("met_bangja"), "C0102 방자와 부딪힘")
	expect(d.S.has_clue("swing") and d.S.has_clue("name"), "1B 그네 · 이름(방자에게 들음)")
	if branch == "A":
		expect(d.S.is_flag("fan_returned") and d.S.is_flag("recog_yes"), "부채 주워 줌 · “맞소”")
		expect(d.S.is_flag("errand_with") and d.S.is_flag("refusal_seen"), "같이 가서 2A 거절 장면")
	else:
		expect(d.S.is_flag("fan_passed") and not d.S.is_flag("recog_yes"), "그냥 지나감(알아봄 없음)")
		expect(d.S.is_flag("errand_alone") and not d.S.is_flag("refusal_seen"), "혼자 보냄 — 아직 거절 장면 전")
		await walk_to("ch_swing_land")
		expect(d.S.is_flag("refusal_seen"), "나중에 그네 곁에서 방자를 만나 거절 장면")
	expect(d.S.has_clue("refusal") and d.S.clues.has("refusal"), "춘향의 대답(들음 — 춘향)")
	expect(String(d.data.clues.refusal.kind) == "heard" and String(d.data.clues.swing.kind) == "fact", "기록: 본 것(그네)과 들은 것(대답) 구분")
	# §9 → §10
	await walk_to("ch_gwanghallu_front")
	expect(d.S.is_flag("mong_reacted") and d.S.has_clue("mong_laugh"), "C0204 몽룡 “재미있구나.”")
	expect(d.S.phase == "courtship" and d.S.is_flag("evening_call") and d.S.has("ITM_CH_JAR"), "§10 저녁 — 술병·찬합을 받아 듦")
	expect(d.main.hour >= 18.0 and d.case_fn.music_wanted() == "", "저녁엔 음악이 그친다")
	# §11·§12
	await walk_to("ch_wolmae_front")
	expect(d.S.is_flag("first_meeting_done") and d.S.has_clue("sorry") and d.S.has_clue("wolmae_word"), "C0302 월매 집 — “잘못했소.”")
	expect(not d.S.has("ITM_CH_JAR"), "술병·찬합은 내려놓음")
	# §13 며칠의 압축 — A 편지
	await go("bangja")
	expect(d.S.is_flag("letter_asked") and d.S.has("ITM_CH_LETTER"), "C0401 편지를 받음(열 수 없음)")
	await go("chunhyang", 1.0)
	expect(d.S.is_flag("letter_delivered") and not d.S.has("ITM_CH_LETTER"), "C0403 춘향에게 전함 — “고맙습니다.”")
	# C 웃음(필수 아님 — a만)
	if branch == "A":
		await walk_to([-3221.0, 466.0])
		await walk_to("ch_wolmae_front")
		expect(d.S.is_flag("laugh_heard"), "§13 C 담 너머 웃음소리")
	# B 함께 걷기
	await walk_to("ch_ojakgyo")
	expect(d.S.is_flag("walk_seen") and d.S.has_clue("walk"), "C0404 오작교 곁을 함께 걷는 두 사람(대사 없음)")
	# 밤 초대 → 기다림
	prefer = ["해 질 때까지"]
	await go("bangja")
	expect(d.S.is_flag("vow_invited") and d.case_fn.is_night(), "C0402 밤 초대 → 해 질 때까지 기다림")
	# §14 백년가약 → §15 · §16 · §17
	prefer = ["들었습니다"] if branch == "A" else ["고개를 끄덕인다"]
	await walk_to("ch_wolmae_front")
	await _idle()
	expect(d.S.is_flag("vow_done") and d.S.is_flag("vow_witness"), "C0406 백년가약 — vow_witness")
	if branch == "A": expect(d.S.is_flag("vow_heard") and not d.S.is_flag("vow_own") and not d.S.is_flag("vow_nod"), "월매에게 “들었습니다.” — vow_heard만")
	else: expect(d.S.is_flag("vow_nod") and not d.S.is_flag("vow_heard"), "말없이 고개를 끄덕임 — vow_nod만")
	expect(d.S.phase == "farewell" and d.S.has_clue("news") and d.S.has_clue("farewell"), "C0501 소식 · 오리정 곁 북쪽 길 이별")
	expect(bool(d.S.vars.get("CASE_NAMWON_CHUNHYANG_PART1_COMPLETE", false)) and d.S.is_flag("part1_done"), "PART1_COMPLETE")
	expect(not bool(d.S.vars.get("CASE_NAMWON_CHUNHYANG_LEFT_AFTER_PART1", false)), "아직 남원 안 — LEFT 아님")
	expect(not bool(d.S.vars.get("CASE_NAMWON_CHUNHYANG_COMPLETE", false)) and String(d.S.vars.get("CASE_NAMWON_CHUNHYANG_OUTCOME", "")) == "", "사건 완료·결말은 아직(PART II)")
	for k in ["dano_swing", "mong_sees", "bangja_message", "first_meeting", "vow", "farewell"]: expect(d.S.is_flag("beat_" + k), "FIXED_BEAT " + k)
	await _frames(10)
	expect(not cr.is_shown("dano_market"), "이별 뒤 단오 군중은 사라짐")
	expect(_gate_off("ti_streamers_ground") and _gate_off("ti_swing"), "단오 차림 내려감(farewell)")
	expect(d.case_fn.music_wanted() == "", "이별에는 큰 음악 없음")
	# §17 춘향에게 말 걸기
	prefer = ["기다리실 겁니까"] if branch == "A" else ["아무 말 하지"]
	await go("chunhyang", 1.4)
	if branch == "A": expect(d.S.is_flag("farewell_ask_wait"), "“기다리실 겁니까?” — “약속했으니까요.”")
	else: expect(d.S.is_flag("farewell_silent"), "아무 말 하지 않음 — “…가세요.”")
	expect(d.S.is_flag("chun_home"), "춘향은 집으로")
	_no_part2("PART I 끝")
	# 기록책
	var jd: Dictionary = d.journal_data()
	var case_pg: Dictionary = JournalBook.section(jd, "case")
	var txt := JSON.stringify(case_pg)
	expect(txt.contains("남원의 약속") and txt.contains("백년가약"), "기록책 사건 기록 — 「남원의 약속」 PART I")
	expect(txt.contains("춘향"), "기록책 — 들은 말에 말한 사람")
	if d.main.args.has("storyshots") and DisplayServer.get_name() != "headless":
		d.ui.journal_toggle(JournalBook.build(d, "case"))
		await cut("09_journal_part1")
		d.ui.journal_toggle(jd)
	# 떠남 → LEFT_AFTER_PART1
	d.on_leave_space("GG_HANYANG")
	expect(bool(d.S.vars.get("CASE_NAMWON_CHUNHYANG_LEFT_AFTER_PART1", false)) and bool(Progress.get_var("CASE_NAMWON_CHUNHYANG_LEFT_AFTER_PART1", false)), "남원을 떠나면 LEFT_AFTER_PART1")
	expect(not d.case_fn.part2_open(), "PART II 닫힘(강릉·경주·황주 아직)")
	await _done()

# 진입 판정 — 재기획 3단계(D3): 오누이 완료 요구를 뗐다. 한양 책방 완료면 춘향(메인 서장이 아직 시작 전이거나 쉬는 자리일 때 — case_registry.choose ③)
func _entry_gate() -> void:
	var cands: Array = CaseRegistry.cases_for("JL_NAMWON_UNBONG")
	expect(cands == ["main_p1", "namwon", "namwon_chunhyang"], "남원 등록부: 메인 서장 · 오누이 · 춘향(%s)" % [cands])
	var none := { "CASE_NAMWON_COMPLETE": false, "CASE_HANYANG_BOOKSHOP_COMPLETE": false }
	var only_nw := { "CASE_NAMWON_COMPLETE": true, "CASE_HANYANG_BOOKSHOP_COMPLETE": false }
	var only_hy := { "CASE_NAMWON_COMPLETE": false, "CASE_HANYANG_BOOKSHOP_COMPLETE": true }
	var both := { "CASE_NAMWON_COMPLETE": true, "CASE_HANYANG_BOOKSHOP_COMPLETE": true }
	expect(String(CaseRegistry.choose(cands, none).id) == "main_p1", "요구 없음 → 메인 서장(춘향 아님)")
	expect(String(CaseRegistry.choose(cands, only_nw).id) == "main_p1", "오누이만 끝 → 메인 서장 합류(춘향 아님)")
	expect(String(CaseRegistry.choose(cands, only_hy).id) == "namwon_chunhyang", "한양만(오누이 안 끝) → 춘향(D3 — 오누이 의존 없음)")
	expect(String(CaseRegistry.choose(cands, both).id) == "namwon_chunhyang", "둘 다 → 춘향")
	# 귀환 이유 — 다른 고을 소문(강제 없음): 한양 책방 뒤에만, PART I 뒤에는 그치는 말
	for r in Rumors.RUMORS:
		if String(r.id).begins_with("CH_DANO_"):
			expect(Rumors.pick(r, Progress.vars(), { "CASE_NAMWON_CHUNHYANG_PART1_COMPLETE": false }).contains("남원 단오장"), "소문 %s “남원 단오장이 크게 선다더라”" % r.id)
			expect(Rumors.pick(r, { "CASE_HANYANG_BOOKSHOP_COMPLETE": false }, { "CASE_HANYANG_BOOKSHOP_COMPLETE": false }) == "", "소문 %s 한양 전에는 없음" % r.id)
			expect(Rumors.pick(r, Progress.vars(), { "CASE_NAMWON_CHUNHYANG_PART1_COMPLETE": true }) == "", "소문 %s PART I 뒤에는 그침" % r.id)
	var head: Dictionary = d.data.case
	expect(head.requires.size() == 1 and head.requires.has("CASE_HANYANG_BOOKSHOP_COMPLETE"), "requires 한양 책방 하나(결정 §4 → 재기획 D3: 오누이 완료 요구를 뗌)")
	var gl := []
	for k in d.S.vars:
		if String(k).begins_with("CASE_NAMWON_CHUNHYANG_"): gl.append(k)
	for k in Progress.vars():
		if String(k).begins_with("CASE_NAMWON_CHUNHYANG_") and not gl.has(k): gl.append(k)
	gl.sort()
	expect(gl.all(func(k): return k in ["CASE_NAMWON_CHUNHYANG_COMPLETE", "CASE_NAMWON_CHUNHYANG_LEFT_AFTER_PART1", "CASE_NAMWON_CHUNHYANG_OUTCOME", "CASE_NAMWON_CHUNHYANG_PART1_COMPLETE"]), "전역 변수는 넷뿐(%s)" % [gl])

# 오누이 뒤 남원 사람(같은 CHR·그림) — 사건 뒤 말만
func _aftermath_npcs() -> void:
	for id in ["jumo", "miller", "hunter", "neighbor"]:
		expect(d.actors.has(id), "남원 사람 다시 섬 " + id)
	expect(String(d.actors.jumo.spec.chr) == "CHR_HUM_015" and String(d.actors.jumo.spec.kind) == "innkeeper", "주모 같은 CHR·그림")
	expect(first_line("jumo") == "북쪽 길은 다시 사람들이 다니오.", "주모 “북쪽 길은 다시 사람들이 다니오.”")
	expect(first_line("neighbor").contains("소식 들으면"), "이웃 아낙 — 아침의 대답(CASE_NAMWON_MORNING unknown)")
	await go("jumo", 1.0)
	expect(int(d.S.talked.get("jumo", 0)) == 1, "주모에게 말 걸기")
	await go("neighbor", 1.0)
	expect(not d.data.has("arenas") and not d.events.has("S0007"), "오누이 흐름은 옮기지 않음")

func _no_part2(when: String) -> void:
	expect(d.S.phase == "farewell", "%s: 단계 farewell에 머묾(PART II 단계 없음)" % when)
	for id in ["ti_gamani_store_a", "ti_dais", "ti_hyeongteul", "ti_chail", "ti_feast_w0", "ti_wine_cart"]:
		expect(_gate_off(id), "%s: PART II 차림 없음 %s" % [when, id])
	expect(not d.main.crowd.is_shown("byeon_banquet"), "%s: 잔치 군중 없음" % when)
	expect(not d.S.is_flag("p2_started") and d.S.phase in ["dano", "courtship", "farewell"], "%s: PART II 장면이 돌지 않음(단계 %s)" % [when, d.S.phase])
	var late := false
	for e in d.S.seen:
		if int(String(e).substr(1, 2)) >= 13: late = true
	expect(not late and not d.S.is_flag("p2b_started"), "%s: II-B 장면이 돌지 않음" % when)

# PART I 끝 + 떠남 + 강릉 완료 → 다시 남원: PART II 열림 조건은 참이어도 아무것도 서지 않는다
func _run_after() -> void:
	var S = d.S
	S.phase = "farewell"
	for k in ["case_started", "vista_seen", "bump_done", "met_bangja", "errand_choice", "errand_with", "refusal_seen", "mong_reacted", "evening_call",
			"first_meeting_done", "letter_asked", "letter_delivered", "walk_seen", "vow_invited", "vow_done", "vow_witness", "vow_own", "farewell_scene_done",
			"part1_done", "farewell_talked", "chun_home", "bangja_off", "mong_off"]:
		S.flags[k] = true
	S.vars.CASE_NAMWON_CHUNHYANG_PART1_COMPLETE = true
	S.vars.CASE_NAMWON_CHUNHYANG_LEFT_AFTER_PART1 = true
	for k in ["CASE_GANGNEUNG_COMPLETE", "CASE_GYEONGJU_COMPLETE", "CASE_HWANGJU_COMPLETE"]: S.vars[k] = false
	d.case_fn.on_load()
	d.on_phase(); d._refresh()
	await _frames(10)
	expect(not d.case_fn.part2_open(), "PART II 열림 조건 거짓(PART1 · LEFT뿐 — 강릉·경주·황주 아직)")
	await walk_to("ch_wolmae_front")
	await _frames(20)
	_no_part2("다시 남원")
	expect(not d.runner.busy and S.phase == "farewell", "도착해도 PART II 장면이 돌지 않음")
	expect(d.actors.chunhyang.shown and not d.actors.mongryong.shown and not d.actors.bangja.shown, "춘향은 집에, 몽룡·방자는 없다")
	expect(first_line("wolmae") == "그 도련님 말, 길손도 들었지요.", "월매 — PART I 뒤 말")
	await go("wolmae", 1.0)
	expect(first_line("jumo") == "북쪽 길은 다시 사람들이 다니오.", "주모 — 사건 뒤 말")
	expect(not d.main.crowd.is_shown("dano_market"), "단오 군중 없음")
	await _done()
