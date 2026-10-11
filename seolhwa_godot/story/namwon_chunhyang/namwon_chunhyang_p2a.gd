# 사건 「남원의 약속」 PART II-A — 새 사또(ACT 6~12 첫 밤): 남원 재방문 → 변학도 행차(6A) → 아전이 알아봄·임시 잡역 → 문서·기생 부르기·사령 줄(일) →
# 기생 점고(8A) → 명령서 → 월매 집 → 수청(8A → 춘향 높이 10A) → 곤장(얼굴·손·월매·기둥 컷, 소리만) → 투옥(옥문 SEALED) → 첫 밤 월매의 밥(§30) · 옥 대화(§31).
# II-B(술·쌀·상소, 몽룡 귀환 이후)는 여기 없다.
# 공통 도움(대사·플래그·카메라 등)도 여기 둔다 — 사건 스크립트(namwon_chunhyang_case.gd, PART I)가 이 파일을 잇는다.
#
# 원칙(시나리오 §1·§2·ACT 7 "선택의 목적은 첫 태도"): 플레이어는 관아가 부리는 외지인 — 톱니 하나다. 춘향의 운명을 바꾸지 않는다.
#   사이사이 조작을 쥔다: 일(문서 나르기 · 기생 부르기 · 사령 줄에 서기 · 춘향 데려오기 · 옥까지 데려가기) · 자유 걷기 · 고을 사람의 말(엿들음).
#   권력 장면(점고 · 첫 수청)은 플레이어가 사령 줄에 선 채 조작을 쥐고 본다(8A, 줄을 벗어나면 선임이 "제자리!"). 결정적 순간(두 번째 요구·곤장·팔·옥문)만 컷.
# 조작 비율(사용자 목표 ≥70%): ctl_tick() — 실제 시간(벽시계)으로 재회 첫 프레임부터 옥문이 닫힐 때까지(그리고 §30·§31 끝까지 따로) 조작 가능한 시간을 잰다.
extends RefCounted

const P2 := preload("res://story/namwon_chunhyang/namwon_chunhyang_p2a_data.gd")
const Progress := preload("res://scripts/region/progress.gd")

var d      # story_director
var S:
	get: return d.S

func _init(director) -> void:
	d = director

# ---------------------------------------------------------------------------
# 공통 도움
# ---------------------------------------------------------------------------
func R(steps: Array) -> void:
	await d.runner.exec(steps, d.runner.gen)

func flag(k: String, v = true) -> void:
	S.flags[k] = v; d.runner.log_line("flag", [k, v]); d.mark_dirty()

func unflag(k: String) -> void:
	S.flags.erase(k); d.mark_dirty()

func f(k: String) -> bool: return S.is_flag(k)

func say(who: String, lines) -> void:
	await d.ui.say(who, lines if lines is Array else [lines])

func beat(id: String) -> void:
	flag("beat_" + id)

# 대본 시험 화면 검토(--storyshots): 컷의 그 순간을 찍는다(시험이 아니면 아무것도 안 함)
func _cut(nm: String) -> void:
	if d.test != null and d.test.has_method("cut"): await d.test.cut(nm)

func _shot(c: Dictionary) -> void:
	var w = d.world
	var p := Vector3(float(c.pos[0]), w.height_at(float(c.pos[0]), float(c.pos[2])) + float(c.pos[1]), float(c.pos[2]))
	var l := Vector3(float(c.look[0]), w.height_at(float(c.look[0]), float(c.look[2])) + float(c.look[1]), float(c.look[2]))
	d.main.rig.focus = null; d.main.rig.override = null
	d.main.rig.shot = { pos = p, look = l, fov = float(c.fov) }
	if d.main.has_method("set_occ_script"): d.main.set_occ_script({ "focus": l, "r": 0.0, "near": 0.0 })
	if d.main.has_method("set_cine_sharp"): d.main.set_cine_sharp(true)

func _cam_end() -> void:
	d.main.rig.shot = null
	d.camera(null)
	if d.main.has_method("set_occ_script"): d.main.set_occ_script(null)
	if d.main.has_method("set_cine_sharp"): d.main.set_cine_sharp(false)

func _talk_cam(a, b) -> void:
	var tc: Dictionary = d.talk_camera_base()
	if tc.is_empty(): return
	var p: Vector2 = (d.anchor(a) + d.anchor(b)) * 0.5
	tc = tc.duplicate(); tc.focus = [p.x, p.y]
	d.camera(tc)

func _place(id: String, at, facing := "") -> void:
	d.place_actor(id, at, null, facing)

func _pp() -> Vector2:
	return Vector2(d.main.player_pos.x, d.main.player_pos.z)

func _apos(id: String) -> Vector2:
	var a = d.actors.get(id)
	return Vector2(a.pos.x, a.pos.z) if a != null else Vector2.INF

# 엿듣는 한 줄(조작을 막지 않는 자막) — 권력 장면을 사령 줄에서 볼 때. 읽는 시간만큼 둔다
func line(who: String, text: String) -> void:
	var sec := 1.5 + text.length() * 0.075
	await d.ui.caption(("%s  “%s”" % [who, text]) if who != "" else text, sec)

# ---------------------------------------------------------------------------
# PART II 열림(결정 §4)
# ---------------------------------------------------------------------------
const V_PART1 := "CASE_NAMWON_CHUNHYANG_PART1_COMPLETE"
const V_LEFT := "CASE_NAMWON_CHUNHYANG_LEFT_AFTER_PART1"

func part2_open() -> bool:
	var v := func(k: String) -> bool: return bool(S.vars.get(k, Progress.get_var(k, false)))
	return v.call(V_PART1) and v.call(V_LEFT) and (v.call("CASE_GANGNEUNG_COMPLETE") or v.call("CASE_GYEONGJU_COMPLETE") or v.call("CASE_HWANGJU_COMPLETE"))

# 남원에 다시 들어왔을 때(불러오기 = 공간에 들어옴) 조건이 맞으면 조용히 PART II를 세운다 — 컷신 없음. 단오 차림·군중은 단계로 이미 없다(F-11)
func p2_enter() -> void:
	if f("p2_started") or S.phase != "farewell" or not f("part1_done") or not part2_open(): return
	flag("p2_started")
	for k in ["chun_on", "farewell_scene_done"]: S.flags.erase(k)
	S.phase = "arrival"; d.runner.log_line("phase", S.phase)
	d.set_hour(10.0)
	d.on_phase()
	d.journal_note("남원에 다시 왔다. 단오 때와 공기가 다르다")
	d.ui.toast("「%s」 — 남원에 다시 왔다" % "남원의 약속", "journal")
	d.mark_dirty()

# ---------------------------------------------------------------------------
# 조작 비율(실제 시간) — 재회 첫 프레임 ~ 옥문 닫힘(window "to_jail"), ~ II-A 끝(window "to_end")
# ---------------------------------------------------------------------------
var ctl := { "to_jail": { "ctl": 0.0, "all": 0.0 }, "to_end": { "ctl": 0.0, "all": 0.0 }, "marks": [] }
var _ctl_us := -1

func controllable() -> bool:
	if d.blocks_move(): return false
	var fd = d.ui.get("_fade")
	if fd != null and float(fd.color.a) > 0.5: return false
	return true

func ctl_tick() -> void:
	var now := Time.get_ticks_usec()
	var dt := 0.0 if _ctl_us < 0 else (now - _ctl_us) / 1000000.0
	_ctl_us = now
	if not f("p2_started") or dt <= 0.0 or dt > 0.5: return   # 멈춤(창 뒤로 감 등)은 세지 않는다
	var c := controllable()
	for w in ["to_jail", "to_end"]:
		if w == "to_jail" and f("jailed"): continue
		if w == "to_end" and f("p2a_done"): continue
		ctl[w].all += dt
		if c: ctl[w].ctl += dt

func ctl_ratio(w := "to_jail") -> float:
	return ctl[w].ctl / maxf(0.001, ctl[w].all)

func _mark(nm: String) -> void:
	ctl.marks.append([nm, snappedf(ctl.to_end.all, 0.1), snappedf(ctl.to_end.ctl, 0.1)])

# ---------------------------------------------------------------------------
# 차일 규칙(사용자 결정 1): 공식 권력 8A(점고·수청·출두)에서는 FURLED, 평소 잔치 놀이와 낮은·가까운 틀에서는 SPREAD.
#   컷이 바뀔 때만 바꾼다(cut_to) — 플레이어 눈앞에서 말아 올리는 움직임은 없다. II-A에는 차일이 서지 않는다(feast·reveal 단계에만) — 규칙만 준비.
# ---------------------------------------------------------------------------
const CHAIL_FURLED_FRAMES := ["8A_jeomgo", "8A_sucheong", "8A_chuldu"]
var chail_set := ""   # 시험: 마지막으로 cut_to가 정한 상태

static func chail_state_for(frame: String) -> String:
	return "FURLED" if CHAIL_FURLED_FRAMES.has(frame) else "SPREAD"

func cut_to(frame: String) -> void:
	var pl = d.main.get("placement")
	var on := false
	if pl != null:
		var e = pl.gated.get("ti_chail")
		on = e != null and not bool(e.get("off", false))
	if on:
		var want := chail_state_for(frame)
		if d.main.world.props.get_state("ti_chail/cloth") != want: d.main.world.set_prop_state("ti_chail/cloth", want)
		chail_set = want
	var sharp := frame != "none"   # 권력 틀·10A는 화면 전체를 또렷이(평소 놀이 피사계 흐림 끔)
	if d.main.has_method("set_cine_sharp"): d.main.set_cine_sharp(sharp)
	match frame:
		"8A_jeomgo", "8A_sucheong", "8A_gonjang", "8A_chuldu": d.camera(P2.CAM_8A)
		"10A": d.camera(P2.CAM_10A)
		"none": d.camera(null)

# ---------------------------------------------------------------------------
# 매 프레임(story_director._update_ambient → case ambient)
# ---------------------------------------------------------------------------
var _drum_t2 := 2.0
var _leash_t := 0.0
var leash_at := Vector2.INF
var leash_pulls := 0
var _refuse_t := 0.0

func p2_ambient(dt: float) -> void:
	ctl_tick()
	if not f("p2_started"): return
	if S.phase == "arrival" and not f("proc_in"):
		_drum_t2 -= dt
		if _drum_t2 <= 0.0:
			_drum_t2 = 7.5
			d.sfx("drum_far", _proc_lead_pos() if f("proc_on") else Vector2(-3228.0, 318.0))
	if f("proc_on") and not f("proc_in"): _proc_step(dt)
	_leash(dt)
	_follow(dt)
	_rope_sync()
	# 싫다고 한 뒤 — 몇 걸음 떠나거나 조금 지나면 포졸이 장정들과 함께 막아선다(결국 들어간다)
	if f("labour_refused") and not f("rounded_up") and not d.runner.busy:
		_refuse_t += dt
		if _pp().distance_to(d.anchor("ch_gwana_front")) > 12.0 or _refuse_t > 9.0:
			d.runner.run([{ "event": "C0702" }])
	# 지나쳤을 때(§30) — 멀어지면 향단이 바구니를 받아 옥 담 뒤로(음식은 결국 들어간다)
	if f("passed_food") and not f("food_in") and not d.runner.busy and _pp().distance_to(d.anchor("ch_prison_food")) > 13.0:
		d.runner.run([{ "call": "food_other_way" }])

# 사령 줄 자리(줄 끝): 벗어나면 선임이 부른다 — 끌어다 놓는다(조작은 그대로)
func _leash(dt: float) -> void:
	_leash_t = maxf(0.0, _leash_t - dt)
	if not f("leash_on") or leash_at == Vector2.INF: return
	var pp := _pp()
	var v := pp - leash_at
	if v.length() <= 1.6: return
	var q := leash_at + v.normalized() * 1.5
	d.set_player_pos(Vector3(q.x, d.world.height_at(q.x, q.y), q.y))
	leash_pulls += 1
	if _leash_t <= 0.0:
		_leash_t = 3.5
		d.ui.toast("선임 사령 — “거기 외지인, 제자리!”", "info")

# 데려가는 동안 춘향이 뒤따른다(제 걸음으로 — 앞서 달려가도 그녀를 기다려야 한다)
func _follow(dt: float) -> void:
	var who := ""
	var spd := 2.0
	if f("escorting"): who = "chunhyang"
	elif f("escort_jail"): who = "chunhyang"; spd = 1.0   # 곤장 뒤 — 절뚝인다
	if who == "" or not d.actors.has(who): return
	if d.runner.busy and not d.free_move: return
	var a: Dictionary = d.actors[who]
	var pp := _pp()
	var cp := Vector2(a.pos.x, a.pos.z)
	var v := pp - cp
	var l := v.length()
	a.scripted = true
	if l > 1.9:
		var step := minf(spd * fast_mul * dt, l - 1.9)
		cp += v / l * step
		a.pos = Vector3(cp.x, d.world.height_at(cp.x, cp.y), cp.y)
		a.facing = "right" if absf(v.x) > absf(v.y) * 1.05 and v.x > 0 else ("left" if absf(v.x) > absf(v.y) * 1.05 else ("down" if v.y > 0 else "up"))
		if a.anim != "walk": a.anim = "walk"; a.ch.play("walk")
	elif a.anim != "idle":
		a.anim = "idle"; a.ch.play("idle", true)

func chun_close() -> bool:
	return d.actors.has("chunhyang") and _apos("chunhyang").distance_to(_pp()) < 4.5

# ---------------------------------------------------------------------------
# ACT 6 §19 — 변학도 행차(CAMERA 6A): 앞 포졸 · 가운데 가마 · 뒤 짐, 군중은 양옆. 행차는 남문 안에서 북으로 → 네거리 → 동쪽 관아로
# ---------------------------------------------------------------------------
var proc_s := 0.0
const PROC_SPEED := 1.7
var fast_mul := 1.0   # 대본 시험(빠름)만 행차·뒤따르기를 빨리 — 실제 놀이·조작 비율 측정은 1

func _proc_path() -> Array:
	return P2.PROC_PATH.map(func(q): return Vector2(q[0], q[1]))

static func _along(path: Array, s: float) -> Array:   # [자리, 방향]
	var acc := 0.0
	for i in path.size() - 1:
		var a: Vector2 = path[i]; var b: Vector2 = path[i + 1]
		var l := a.distance_to(b)
		if s <= acc + l or i == path.size() - 2:
			var t := clampf((s - acc) / maxf(l, 0.001), 0.0, 1.0)
			return [a.lerp(b, t), (b - a).normalized()]
		acc += l
	return [path[0], Vector2(0, -1)]

func _path_len() -> float:
	var p := _proc_path(); var acc := 0.0
	for i in p.size() - 1: acc += p[i].distance_to(p[i + 1])
	return acc

func _proc_lead_pos() -> Vector2:
	return _along(_proc_path(), proc_s)[0]

func _proc_place() -> void:
	var path := _proc_path()
	var gp := Vector2.ZERO; var gdir := Vector2(0, -1); var gok := false
	var sh = d.main.rig.shot
	var rev: bool = sh != null and (sh.look - sh.pos).z > 0.0
	for m in P2.PROC_MEMBERS:
		var s: float = proc_s - float(m.back)
		var r: Array = _along(path, maxf(s, 0.0) if s >= 0.0 else 0.0)
		var p: Vector2 = r[0]; var dir: Vector2 = r[1]
		if s < 0.0: p = path[0] - (path[1] - path[0]).normalized() * (-s)
		var side := Vector2(-dir.y, dir.x)
		var q := p + side * float(m.side)
		if String(m.id) == "p_gama":
			gp = q; gdir = dir; gok = true; continue
		var a = d.actors.get(String(m.id))
		if a == null: continue
		a.scripted = true
		a.pos = Vector3(q.x, d.world.height_at(q.x, q.y), q.y)
		a.facing = "right" if absf(dir.x) > absf(dir.y) * 1.05 and dir.x > 0 else ("left" if absf(dir.x) > absf(dir.y) * 1.05 else ("down" if dir.y > 0 else "up"))
		if rev and a.facing in ["up", "down"]: a.facing = "down" if a.facing == "up" else "up"   # 6A는 남쪽을 보는 각본 시점 — 다가오는 행렬의 앞모습
	if gok and d.props.has("p_gama") and d.props.p_gama.node != null:
		var n: Node3D = d.props.p_gama.node
		n.global_transform = Transform3D(Basis(Vector3.UP, atan2(gdir.x, gdir.y)), Vector3(gp.x, d.world.height_at(gp.x, gp.y), gp.y))
	# 가마가 곁을 지나면 길가 사람은 고개를 숙인다(공용 자세 bow) — 지나가면 다시 선다
	for id in P2.ONLOOKERS:
		var a = d.actors.get(id)
		if a == null or not a.shown: continue
		var near: bool = gok and Vector2(a.pos.x, a.pos.z).distance_to(gp) < 7.0
		var want := "bow" if near else String(a.spec.get("anim", "idle"))
		if a.anim != want: d.anim_actor(id, want)

func _proc_step(dt: float) -> void:
	proc_s += PROC_SPEED * fast_mul * dt
	_proc_place()
	var tail: float = 0.0
	for m in P2.PROC_MEMBERS: tail = maxf(tail, float(m.back))
	if proc_s - tail > _path_len():
		flag("proc_in")
		for m in P2.PROC_MEMBERS:
			if d.actors.has(String(m.id)): d.actors[String(m.id)].scripted = false
		for id in P2.ONLOOKERS:
			if d.actors.has(id): d.anim_actor(id, "idle")
		d.mark_dirty()

func procession() -> void:
	_mark("C0601")
	beat("byeon_arrives")
	d.cutscene(true)
	await d.ui.fade(true, 0.6)
	proc_s = P2.PROC_START_S
	flag("proc_on")
	d.mark_dirty(); d._refresh()
	for m in P2.PROC_MEMBERS:
		if d.actors.has(String(m.id)): d.anim_actor(String(m.id), "walk")
	d.teleport_to("ch_proc_watch", "left")
	_proc_place()
	_shot(P2.CAM_6A)
	await d.wait(0.4)
	await d.ui.fade(false, 0.7)
	d.sfx("drum_far", _proc_lead_pos())
	await d.ui.caption("북소리. 사람들이 길 가장자리로 비켜선다.", 2.4)
	await d.ui.caption("길가 사내  “새 사또래.”", 1.8)
	await _cut("03_6A_procession")
	await d.ui.caption("옆 아낙  “변학도.”", 1.8)
	d.learn_clue("new_magistrate")
	await d.wait(0.6)
	_cam_end()
	flag("proc_seen")
	d.cutscene(false)
	d.ui.toast("행차가 관아 쪽으로 간다", "info")

# ---------------------------------------------------------------------------
# ACT 7 §20 — 아전이 알아본다 · 임시 잡역(맡는다 / 싫다 — 첫 태도만 기억)
# ---------------------------------------------------------------------------
func recognition() -> void:
	_mark("C0701")
	flag("recog_done")
	d.cutscene(true)
	_place("ajeon", "ch_ajeon", "down")
	d.face_actor("player", null, "ajeon")
	_talk_cam("ajeon", "player")
	await say("아전", "당신.")
	await say("나그네", "나 말이오?")
	await say("아전", "전에 고개 범 일 때 포수하고 있던 사람 맞지?")
	await _cut("04_ajeon_recognition")
	await R([{ "choice": "", "options": [
		{ "label": "맞소.", "id": "yes", "do": [{ "flag": "recog2_yes" }, { "say": "아전", "lines": ["그럴 줄 알았지. 얼굴이 낯익더라니."] }] },
		{ "label": "아니오.", "id": "no", "do": [{ "flag": "recog2_no" }, { "say": "아전", "lines": ["아니긴. 그때 포수 곁에 붙어 다니던 걸 내가 봤소."] }] },
		{ "label": "무슨 일이오?", "id": "what", "do": [{ "flag": "recog2_what" }, { "say": "아전", "lines": ["급하긴. 일 얘기부터 하지."] }] }] }])
	await say("아전", ["사람 손이 모자라오. 새 사또 오신 첫날이라.", "하루만 도와주면 품삯은 주지."])
	await say("나그네", "무슨 일인데.")
	await say("아전", "문서 나르고, 사람 데려오는 일.")
	await R([{ "choice": "", "options": [
		{ "label": "(맡는다) 하루라면 하겠소.", "id": "take", "do": [{ "flag": "labour_accepted" }] },
		{ "label": "(싫다고 한다) 다른 사람 찾아보시오.", "id": "refuse", "do": [{ "flag": "labour_refused" }] }] }])
	if f("labour_accepted"):
		await say("아전", ["됐소. 이거 허리에 차시오.", "관아 드나들 때 보여 주면 되오."])
		d.give(P2.TALLY)
		await labour_begin()
	else:
		await say("아전", "그럼 됐소.")
		d.camera(null)
		d.cutscene(false)
		_refuse_t = 0.0

# 싫다고 한 뒤 — 포졸이 고을 장정 몇과 함께 플레이어를 막는다
func roundup() -> void:
	_mark("C0702")
	flag("rounded_up")
	d.cutscene(true)
	var pp := _pp()
	var fwd: Vector2 = (pp - d.anchor("ch_gwana_front"))
	fwd = fwd.normalized() if fwd.length() > 0.5 else Vector2(-1, 0)
	var side := Vector2(-fwd.y, fwd.x)
	flag("roundup_on")
	d.mark_dirty(); d._refresh()
	var a: Vector2 = pp + fwd * 2.2
	_place("roundup_pojol", [a.x, a.y], "")
	_place("roundup_m1", [a.x + side.x * 1.3, a.y + side.y * 1.3], "")
	_place("roundup_m2", [a.x - side.x * 1.4 + fwd.x * 0.6, a.y - side.y * 1.4 + fwd.y * 0.6], "")
	for id in ["roundup_pojol", "roundup_m1", "roundup_m2"]: d.face_actor(id, null, "player")
	d.face_actor("player", null, "roundup_pojol")
	_talk_cam("roundup_pojol", "player")
	await say("포졸", ["거기 서시오.", "관아에서 장정들 잠깐 쓰신다."])
	await say("끌려온 농군", "추수도 덜 끝났는데 이게 무슨…")
	await say("포졸", "말 많다. 따라와.")
	await _cut("04b_roundup")
	await d.ui.fade(true, 0.8)
	unflag("roundup_on")
	d.teleport_to("ch_ajeon_player", "up")
	_place("ajeon", "ch_ajeon", "down")
	_talk_cam("ajeon", "player")
	await d.wait(0.3)
	await d.ui.fade(false, 0.7)
	await say("아전", ["결국 왔구려.", "이거 허리에 차시오. 일이 끝나면 돌려주고."])
	d.give(P2.TALLY)
	await labour_begin()

# 일의 시작 — 단계 office(사령·이방·변학도·형틀이 선다). 첫 일: 문서 묶음을 이방에게
func labour_begin() -> void:
	flag("labour_started")
	S.phase = "office"; d.runner.log_line("phase", S.phase); d.on_phase()
	stage_office()
	d.learn_clue("labour")
	await say("아전", ["첫 일. 이 문서 묶음을 이방께 갖다 드리시오.", "안마당 단 옆에 계시오."])
	d.give(P2.DOCS)
	d.journal_note("관아 아전에게 하루 잡역을 맡았다(목패)" if f("labour_accepted") else "관아 포졸에게 끌려가 잡역을 맡았다(목패)")
	d.camera(null)
	d.cutscene(false)
	d.ui.toast("이방에게 문서를 — 관아 안마당", "info")

# office 단계의 자리(불러오기 뒤에도): 변학도 교의(대청 dy 1.05) · 기생은 부르기 전 바깥마당, 부른 뒤 단 앞 줄
func stage_office() -> void:
	if d.actors.has("byeon"):
		# 대청 마루 = 안마당 땅 + 1.05(보계·교의와 같은 높이). 동헌 밑 지형은 기단만큼 솟아 있어 그 자리 땅 기준으로 더하면 1m 떠오른다(촬영)
		var seat: Vector2 = d.anchor("ch_byeon_seat")
		var court: Vector2 = d.anchor("ch_dais")
		var dy: float = d.world.height_at(court.x, court.y + 1.6) + 1.05 - d.world.height_at(seat.x, seat.y)
		d.place_actor("byeon", "ch_byeon_seat", dy, "down")
		d.anim_actor("byeon", "sit")
	for i in P2.GISAENG.size():
		var id: String = P2.GISAENG[i]
		if not d.actors.has(id): continue
		if f("gisaeng_called"): d.place_actor(id, "ch_gisaeng_%d" % (i + 1), null, "up")
		else: d.place_actor(id, "ch_gisaeng_wait_%d" % i, null, "down")
	if d.actors.has("ajeon"): d.place_actor("ajeon", "ch_ajeon_office", null, "down")

# 일 1 — 이방(문서) → 일 2 바깥마당 기생을 안으로 → 일 3 사령 줄 끝에 선다
func docs_to_ibang() -> void:
	_mark("C0704")
	await say("나그네", "아전이 보낸 문서요.")
	d.take(P2.DOCS)
	await say("이방", ["거기 두고.", "바깥마당에 기생들이 와 있을 거요. 안으로 들라 하시오.", "당신은 그다음 서쪽 사령 줄 끝에 서 있고."])
	flag("docs_delivered")
	d.ui.toast("바깥마당의 기생들에게", "info")

func call_gisaeng() -> void:
	_mark("C0705")
	await say("나그네", "안으로 드시오. 이방이 부르오.")
	await say("기생", "…예.")
	flag("gisaeng_called")
	for i in P2.GISAENG.size():
		var id: String = P2.GISAENG[i]
		if d.actors.has(id): d.move_actor(id, ["ch_court_gate_in", "ch_gisaeng_%d" % (i + 1)], 1.8, "walk", "idle")
	d.ui.toast("서쪽 사령 줄 끝에 선다", "info")

# 일 3 — 사령 줄 끝에 선다(트리거). 기생이 다 들어오면 점고(8A). 그동안 조작은 그대로 — 줄을 벗어나면 "제자리!"
func take_line() -> void:
	_mark("take_line")
	flag("in_line")
	leash_at = d.anchor("ch_player_saryeong")
	flag("leash_on")
	d.free_move = true
	d.ui.caption("선임 사령  “거기 서. 부르기 전엔 움직이지 마.”", 2.6)
	# 기생이 줄에 다 설 때까지(시험·실제 모두 걸음으로 — 최대 30초). 그동안 플레이어는 줄에서 기다린다(조작 그대로)
	var t := 0.0
	while t < 30.0:
		var all_in := true
		for id in P2.GISAENG:
			if d.actors.has(id) and not (d.actors[id].path as Array).is_empty(): all_in = false
		if all_in: break
		await d.wait(0.25); t += 0.25
	for id in P2.GISAENG:
		if d.actors.has(id): d.face_actor(id, "up", null)
	await d.wait(1.0)
	await roll_call()

# ACT 8 §21·§22 — 기생 점고(공식 8A, 차일 규칙 FURLED). 이방이 이름을 부르고 "데려와."까지 — 플레이어는 줄에 선 채 본다
func roll_call() -> void:
	_mark("C0801")
	beat("roll_call")
	cut_to("8A_jeomgo")
	await d.wait(0.6)
	await line("", "이방이 명부를 펴 든다.")
	var names := ["월선이", "채봉이", "명옥이", "난향이"]
	for i in names.size():
		await line("이방", names[i] + ".")
		var gid: String = P2.GISAENG[i]
		d.anim_actor(gid, "bow")
		await line(["월선", "채봉", "명옥", "난향"][i], "예.")
		d.anim_actor(gid, "idle")
	await _cut("06_8A_jeomgo")
	await line("변학도", "그게 다냐?")
	await line("이방", "예.")
	await d.wait(0.8)
	await line("이방", "…월매라는 퇴기가 하나 있고…")
	await line("변학도", "퇴기?")
	await line("이방", "그 딸이 있습니다. 성춘향이라 합니다.")
	await line("변학도", "왜 안 왔느냐?")
	await line("이방", "관기 명부에는…")
	await line("변학도", "데려와.")
	d.learn_clue("roll_call")
	d.learn_clue("bring_her")
	flag("jeomgo_done")
	d.free_move = false
	await summons()

# ACT 9 §23 — 아전이 종이를 준다(컷)
func summons() -> void:
	_mark("C0901")
	d.cutscene(true)
	unflag("leash_on")
	cut_to("none")
	_place("ajeon", "ch_ajeon_line", "left")
	d.face_actor("player", null, "ajeon")
	_talk_cam("ajeon", "player")
	await say("아전", "월매 집 알지?")
	await say("나그네", "압니다.")
	await say("아전", "이거 주고 딸 데리고 와.")
	d.give(P2.SUMMONS)
	await R([{ "examine": "관아 명령서", "text": ["“퇴기 월매의 딸 성춘향을 관아로 데려올 것.”", "이방의 수결이 찍혀 있다."], "kind": "item" }])
	flag("summons_given")
	d.learn_clue("summons_paper")
	d.camera(null)
	d.cutscene(false)
	d.ui.toast("월매 집으로 — 남문 밖, 광한루 동쪽", "info")

# ACT 9 §24 — 월매 집(월매가 알아봄 · 전할 말 셋 · 춘향이 스스로 간다)
func summons_wolmae() -> void:
	_mark("C0902")
	d.cutscene(true)
	flag("wolmae_on")
	d.mark_dirty(); d._refresh()
	_place("wolmae", "ch_wolmae_at_gate", "down")
	d.teleport_to("ch_player_gate", "up")
	d.camera({ "focus": [-3213.0, 459.4], "pitch": 30.0, "distance": 11.5, "fov": 38.0 })
	d.sfx("knock", "ch_wolmae_gate")
	await d.wait(0.6)
	if f("vow_witness"): await say("월매", "…길손 양반?")
	else: await say("월매", "누구시오?")
	await d.ui.caption("종이를 내밀었다. 월매가 읽는다. 얼굴이 굳는다.", 2.4)
	if f("vow_witness"): await say("월매", ["그때 그 도련님은 가고…", "이번엔 사또 심부름으로 왔소?"])
	else: await say("월매", "사또 심부름으로 왔소?")
	await _cut("07_wolmae_summons")
	await R([{ "choice": "", "options": [
		{ "label": "관아에서 나오라 합니다.", "id": "plain", "do": [{ "flag": "summons_plain" }, { "say": "월매", "lines": ["나오라면 나가야지. 관아 말인데."] }] },
		{ "label": "좋은 일로 부르는 것 같지 않습니다.", "id": "warn", "do": [{ "flag": "warned_wolmae" }, { "say": "월매", "lines": ["…알고 있소. 첫날부터 기생 점고를 했다지."] }] },
		{ "label": "성춘향을 데려오라 했습니다.", "id": "words", "do": [{ "flag": "summons_words" }, { "say": "월매", "lines": ["데려오라. 그렇게 적혀 있소?"] }] }] }])
	flag("chun_on")
	d.mark_dirty(); d._refresh()
	_place("chunhyang", "ch_chun_yard", "down")
	await d.move_actor("chunhyang", ["ch_chun_gate"], 1.2, "walk", "idle")
	d.face_actor("chunhyang", null, "wolmae")
	await say("춘향", "제가 가겠습니다.")
	d.face_actor("wolmae", null, "chunhyang")
	await say("월매", "안 돼.")
	await say("춘향", "안 가면 더 많은 사람이 올 겁니다.")
	await d.ui.caption("월매가 문설주를 잡은 채 말이 없다.", 2.2)
	d.face_actor("chunhyang", null, "player")
	await say("춘향", "가요. 앞서 가세요.")
	d.take(P2.SUMMONS)
	d.learn_clue("chun_decides")
	flag("wolmae_summoned")
	flag("escorting")
	unflag("wolmae_on")
	d.place_actor("wolmae", "home")
	d.camera(null)
	d.cutscene(false)
	d.ui.toast("춘향을 관아 안마당으로 — 춘향은 제 걸음으로 따라온다", "info")

# ACT 10 §25 — 수청(첫 요구는 8A — 플레이어는 사령 줄에서 조작을 쥔 채 본다) · §26 두 번째 요구(처음으로 춘향 높이로 내려온 10A — 컷)
var probe_sucheong := {}
func sucheong() -> void:
	_mark("C1001")
	beat("sucheong_demand")
	d.cutscene(true)
	await d.ui.fade(true, 0.5)
	unflag("escorting")
	_place("chunhyang", "ch_chunhyang_center", "up")
	d.anim_actor("chunhyang", "idle")
	d.teleport_to("ch_player_saryeong", "right")
	leash_at = d.anchor("ch_player_saryeong")
	flag("leash_on")
	cut_to("8A_sucheong")
	await d.wait(0.3)
	await d.ui.fade(false, 0.6)
	d.cutscene(false)
	d.free_move = true
	await line("변학도", "네가 춘향이냐?")
	await line("춘향", "그렇습니다.")
	await line("변학도", "가까이 오너라.")
	await line("", "춘향은 그대로 서 있다.")
	await line("변학도", "내 수청을 들어라.")
	await _cut("08_8A_sucheong")
	await line("춘향", "못 합니다.")
	await line("", "마당이 조용해진다.")
	await line("변학도", "못 한다?")
	await line("춘향", "이미 정한 사람이 있습니다.")
	await line("변학도", "여기가 네 사랑놀음 듣는 곳인 줄 아느냐?")
	await line("춘향", "정한 뜻을 바꿀 수는 없습니다.")
	probe_sucheong["first_pitch"] = float((d.main.rig.override if d.main.rig.override != null else {}).get("pitch", -1.0))
	probe_sucheong["first_ctl"] = controllable()
	flag("sucheong1_done")
	d.learn_clue("sucheong")
	beat("refusal")
	# 두 번째 요구 — 컷. 카메라가 처음으로 춘향 쪽 높이로 내려온다
	d.free_move = false
	unflag("leash_on")
	d.cutscene(true)
	await say("변학도", "다시 묻겠다.")
	cut_to("10A")
	await d.wait(0.5)
	probe_sucheong["second_pitch"] = float((d.main.rig.override if d.main.rig.override != null else {}).get("pitch", -1.0))
	await say("변학도", "수청 들어라.")
	await _cut("09_10A_second_demand")
	await say("춘향", "싫습니다.")
	await d.wait(0.6)
	await say("변학도", "곤장을 쳐라.")
	flag("sucheong2_done")
	await gonjang()

# ACT 11 §27·§28 — 줄 잡아(잡는다 / 느슨하게 / 놓는다). 어느 경우든 춘향은 맞는다. 정면 타격 없음 — 얼굴·손·월매·기둥, 소리와 숨만, BGM 없음
var strikes := 0
func _hit() -> void:
	strikes += 1
	S.world["strikes"] = strikes
	flag("struck")
	d.sfx("gonjang_hit", "ch_hyeongteul")
	d.shake(0.02, 0.15)
	await d.wait(0.5)
	d.sfx("breath_pain", "ch_hyeongteul")

func gonjang() -> void:
	_mark("C1101")
	beat("gonjang")
	d.hush(0.6)
	await d.ui.fade(true, 0.5)
	cut_to("8A_gonjang")
	_place("chunhyang", "ch_chun_bound", "up")
	d.anim_actor("chunhyang", "kneel")
	_place("saryeong_w2", "ch_bind_w", "right")
	_place("saryeong_e2", "ch_bind_e", "left")
	_place("saryeong_senior", "ch_senior_order", "left")
	_place("wolmae", "ch_wolmae_gate_watch", "up")
	d.teleport_to("ch_player_rope", "right")
	await d.wait(0.3)
	await d.ui.fade(false, 0.5)
	await say("선임 사령", "거기 외지인.")
	await say("선임 사령", "줄 잡아.")
	await R([{ "choice": "", "options": [
		{ "label": "(포승 한쪽을 잡는다)", "id": "obey", "do": [{ "flag": "restraint_obeyed" }] },
		{ "label": "(느슨하게 잡는다)", "id": "loose", "do": [{ "flag": "restraint_loose" }] },
		{ "label": "(줄을 놓는다)", "id": "refuse", "do": [{ "flag": "restraint_refused" }] }] }])
	if not f("restraint_refused"): flag("rope_on")   # 포승 소품(놓으면 사령이 넘겨받은 뒤에)
	if f("restraint_obeyed"):
		await d.ui.caption("포승 한쪽을 잡았다.", 1.8)
		d.face_actor("chunhyang", null, "player")
		await d.ui.caption("춘향이 나를 한번 본다. 아무 말도 하지 않는다.", 2.6)
		d.face_actor("chunhyang", "up", null)
	elif f("restraint_loose"):
		await say("선임 사령", "똑바로 잡아!")
		_place("saryeong_w3", "ch_rope_help", "right")
		await d.ui.caption("다른 사령이 와서 줄을 함께 쥔다.", 2.0)
	else:
		await say("선임 사령", "비켜!")
		d.teleport_to("ch_player_aside", "right")
		_place("saryeong_w3", "ch_player_rope", "right")
		flag("rope_on")
		await d.ui.caption("다른 사령이 줄을 넘겨받는다.", 2.0)
	# 네 컷 — 첫째 춘향 얼굴, 둘째 플레이어 손, 셋째 월매, 넷째 관아 기둥(소리만)
	d.cutscene(true)
	var face: Vector2 = d.anchor("chunhyang")
	d.face_actor("chunhyang", "down", null)   # 그림은 방향으로 고른다 — 북쪽 카메라에 얼굴이 보이게
	_shot({ pos = [face.x + 0.9, 1.1, face.y - 1.7], look = [face.x, 0.7, face.y], fov = 32.0 })   # 앞(북)에서 — 얼굴
	await d.wait(0.5)
	await _hit()
	await _cut("10a_gonjang_face")
	await d.wait(0.8)
	var pp := _pp()
	d.face_actor("chunhyang", "up", null)
	d.face_actor("player", "right", null)
	# 손 컷은 줄을 쥔 손을 찍는다 — 놓았으면 그 자리(ch_player_rope)에서 넘겨받은 사령의 손(같은 틀 · 내 흰 옷 대신 검은 사령 옷)
	if f("restraint_refused") and d.actors.has("saryeong_w3"):
		var hp: Vector2 = _apos("saryeong_w3")
		_shot({ pos = [hp.x - 1.7, 1.2, hp.y - 2.1], look = [hp.x + 0.1, 0.9, hp.y], fov = 30.0 })
	else:
		_shot({ pos = [pp.x - 1.7, 1.2, pp.y - 2.1], look = [pp.x + 0.1, 0.9, pp.y], fov = 30.0 })   # 플레이어 손(안마당 북서에서 가슴 높이 — 내삼문 담 밖으로 나가지 않게)
	await d.wait(0.5)
	await _hit()
	await _cut("10b_gonjang_hand")
	await d.wait(0.8)
	var wm: Vector2 = d.anchor("wolmae")
	d.face_actor("wolmae", "down", null)
	_shot({ pos = [wm.x + 0.4, 1.45, wm.y - 3.2], look = [wm.x, 1.3, wm.y], fov = 30.0 })   # 안마당에서 열린 내삼문 쪽 — 문간의 월매
	await d.wait(0.5)
	await _hit()
	await _cut("10c_gonjang_wolmae")
	await d.wait(0.8)
	_shot(P2.CAM_PILLAR)
	await d.wait(0.5)
	await _hit()
	await _cut("10d_gonjang_pillar")
	await d.wait(1.0)
	_cam_end()
	cut_to("8A_gonjang")
	await say("변학도", "하겠느냐?")
	await _cut("10e_wide_rope")
	await say("춘향", "못 합니다.")
	await _hit()
	await d.wait(0.6)
	await say("변학도", "하겠느냐?")
	await d.wait(0.8)
	await say("춘향", "…못 합니다.")
	await _hit()
	d.learn_clue("gonjang")
	await imprison()

# 포승 소품(§27) — 선택(restraint_*)을 줄 모양으로: 잡는다 짧고 팽팽 · 느슨하게 조금 처짐 · 놓는다 넘겨받은 사령이 쥠(플레이어 쪽 없음).
#   손 동작·줄 물리 없음: 쥔 사람 손 높이 → 꿇은 춘향 등 뒤 손목을 잇는 처진 곡선(관 하나). 굵기는 카메라 거리에 비례(가까운 손 컷·먼 8A 둘 다 읽히게)
var rope_mesh: MeshInstance3D = null
var rope_info := {}   # 지금 그린 줄 { state, holder, sag, len } — 시험이 본다

func rope_state() -> String:
	for k in P2.ROPE_FLAG:
		if f(k): return String(P2.ROPE_FLAG[k])
	return ""

func _rope_sync() -> void:
	var st := rope_state() if f("rope_on") else ""
	if st == "" or not d.actors.has("chunhyang"):
		if rope_mesh != null: rope_mesh.visible = false
		rope_info = {}
		return
	var spec: Dictionary = P2.ROPE[st]
	var hid := String(spec.holder)
	var hp: Vector3 = d.main.player_pos if hid == "player" else (d.actors[hid].pos if d.actors.has(hid) else Vector3.INF)
	if hp == Vector3.INF: return
	var cp: Vector3 = d.actors.chunhyang.pos
	var flat := Vector3(cp.x - hp.x, 0.0, cp.z - hp.z)
	if flat.length() < 0.3: return
	var dir := flat.normalized()
	var a := hp + Vector3(0, P2.ROPE_HAND_H, 0) + dir * 0.22      # 쥔 손(몸 앞)
	var b := cp + Vector3(0, P2.ROPE_TIE_H, 0) - dir * 0.08       # 춘향 등 뒤 손목
	var cam: Camera3D = d.main.cam
	var r := 0.012
	if cam != null: r = clampf(cam.global_position.distance_to((a + b) * 0.5) * 0.0019, 0.016, 0.06)
	if rope_mesh == null:
		rope_mesh = MeshInstance3D.new(); rope_mesh.name = "chunhyang_rope"
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(P2.ROPE_COLOR); m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED   # 인물 그림처럼 평면 색 — 그늘에서도 붉게 읽힌다
		rope_mesh.material_override = m
		rope_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		d._props_root.add_child(rope_mesh)
	rope_mesh.visible = true
	rope_mesh.mesh = _rope_tube(a, b, float(spec.sag), r)
	rope_info = { "state": st, "holder": hid, "sag": float(spec.sag), "len": a.distance_to(b), "r": r, "a": a, "b": b }

static func _rope_tube(a: Vector3, b: Vector3, sag: float, r: float) -> ArrayMesh:
	const N := 14; const SIDES := 6
	var pts := []
	for i in N + 1:
		var t := float(i) / N
		pts.append(a.lerp(b, t) - Vector3(0, sag * 4.0 * t * (1.0 - t), 0))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := []
	for i in pts.size():
		var tng: Vector3 = (pts[mini(i + 1, N)] - pts[maxi(i - 1, 0)]).normalized()
		var side := tng.cross(Vector3.UP).normalized()
		var up := side.cross(tng).normalized()
		var ring := []
		for k in SIDES:
			var ang := TAU * k / SIDES
			ring.append([pts[i] + (side * cos(ang) + up * sin(ang)) * r, side * cos(ang) + up * sin(ang)])
		rings.append(ring)
	for i in N:
		for k in SIDES:
			var k2 := (k + 1) % SIDES
			for q in [rings[i][k], rings[i + 1][k], rings[i + 1][k2], rings[i][k], rings[i + 1][k2], rings[i][k2]]:
				st.set_normal(q[1]); st.add_vertex(q[0])
	return st.commit()

# ACT 11 §29 — 옥에 가둬라. 춘향은 혼자 일어나려 한다 — 팔을 내민다 / 기다린다(팔을 잡으면 말이 없다). 플레이어가 옥까지 데려간다(조작)
func imprison() -> void:
	_mark("C1102")
	await say("변학도", "옥에 가둬라.")
	await say("선임 사령", "일어나.")
	var c: Vector2 = d.anchor("chunhyang")
	cut_to("none")
	d.camera({ "focus": [c.x - 1.2, c.y + 0.6], "pitch": 24.0, "distance": 8.0, "fov": 34.0 })
	if not f("restraint_refused"): d.teleport_to([c.x - 1.1, c.y + 0.5], "right")
	else: d.teleport_to([c.x - 1.4, c.y + 0.7], "right")
	await d.ui.caption("춘향이 혼자 일어나려 한다. 잘 되지 않는다.", 2.4)
	await _cut("11_arm_choice")
	await R([{ "choice": "", "options": [
		{ "label": "(팔을 내민다)", "id": "arm", "do": [{ "flag": "arm_offered" }] },
		{ "label": "(그대로 기다린다)", "id": "wait", "do": [{ "flag": "arm_waited" }] }] }])
	if f("arm_offered"):
		d.face_actor("chunhyang", null, "player")
		await d.wait(0.9)
		d.anim_actor("chunhyang", "idle")
		await d.ui.caption("춘향이 나를 한번 보고, 팔을 잡고 일어선다.", 2.4)
	else:
		await d.wait(1.2)
		d.anim_actor("chunhyang", "idle")
		await d.ui.caption("춘향이 형틀을 짚고 겨우 일어선다.", 2.2)
	unflag("rope_on")   # 일어선 뒤 포승을 거둔다(줄 소품은 팔 고르기 틀까지)
	for id in ["saryeong_w2", "saryeong_e2", "saryeong_w3", "saryeong_senior"]:
		if d.actors.has(id): d.place_actor(id, "home")
	d.place_actor("wolmae", "home")
	await say("선임 사령", "외지인, 옥까지 데려가. 바깥마당 서쪽이다.")
	flag("escort_jail")
	d.camera(null)
	d.cutscene(false)
	d.ui.toast("옥으로 — 춘향은 절뚝이며 따라온다", "info")

# 옥문(트리거): 문이 열리고, 춘향이 들어가고, 닫힌다(SEALED). 단계 jail
var probe_jail := {}
func jail_door() -> void:
	_mark("C1103")
	beat("jail")
	d.cutscene(true)
	unflag("escort_jail")
	d.teleport_to("ch_jail_escort_p", "left")
	_shot(P2.CAM_JAIL_DOOR)
	d.main.world.set_prop_state("ti_jail/gate", "OPEN")
	_place("saryeong_senior", "ch_jail_keeper", "left")
	_place("chunhyang", [-3169.7, 229.6], "left")   # 옥문 문간
	await d.wait(0.6)
	await _cut("12_jail_door_entering")
	d.move_actor("chunhyang", ["ch_jail_gate_in2"], 0.8, "walk", "idle")
	while not (d.actors.chunhyang.path as Array).is_empty(): await d.wait(0.1)
	unflag("chun_on")
	d.mark_dirty(); d._refresh()
	d.main.world.set_prop_state("ti_jail/gate", "SEALED")
	d.main.world.set_prop_state("ti_jail/cell", "SEALED")
	d.sfx("gate_shut", "ch_jail_gate")
	await _cut("12b_jail_door_closed")
	probe_jail = { gate = d.main.world.props.get_state("ti_jail/gate"), cell = d.main.world.props.get_state("ti_jail/cell"), ratio = ctl_ratio("to_jail") }
	flag("jailed")
	_mark("jailed")
	d.learn_clue("jailed")
	await d.wait(1.2)
	# 저녁 — 잡역이 끝났다(목패는 내일 돌려준다)
	await d.ui.fade(true, 1.0)
	_cam_end()
	S.phase = "jail"; d.runner.log_line("phase", S.phase); d.on_phase()
	d.set_hour(19.4)
	d.teleport_to("ch_dismiss_player", "up")
	_place("ajeon", "ch_ajeon_office", "down")
	d.face_actor("player", null, "ajeon")
	_talk_cam("ajeon", "player")
	await d.wait(0.4)
	await d.ui.fade(false, 1.0)
	await say("아전", ["오늘 일은 끝났소.", "목패는 내일 아침 이방께 돌려드리고 품삯 받아 가시오."])
	flag("dismissed")
	d.journal_note("춘향이 곤장을 맞고 옥에 갇혔다. 목패는 아직 내 허리에 있다")
	d.camera(null)
	d.cutscene(false)
	_place("wolmae", "ch_prison_food", "right")
	d.ui.toast("관아 밖으로 — 외삼문", "info")

# ACT 12 §30 — 첫날 밤: 월매가 밥을 들고 포졸과 실랑이. 목패를 가진 플레이어가 고른다(어느 경우든 밥은 들어간다)
func prison_food() -> void:
	_mark("C1201")
	flag("food_scene")
	d.cutscene(true)
	_place("wolmae", "ch_prison_food", "right")
	d.face_actor("pojol_gate", null, "wolmae")
	var mid: Vector2 = (d.anchor("ch_prison_food") + d.anchor("ch_gate_guard")) * 0.5
	d.camera({ "focus": [mid.x, mid.y], "pitch": 30.0, "distance": 11.0, "fov": 38.0 })
	await say("포졸", "안 된다니까.")
	await say("월매", "밥도 못 먹게 할 셈이오?")
	await say("포졸", "사또 분부요. 아무도 못 들이오.")
	await _cut("13_jail_night_food")
	d.face_actor("wolmae", null, "player")
	if f("vow_witness"): await say("월매", "…길손 양반.")
	d.learn_clue("food_refused")
	await R([{ "choice": "", "options": [
		{ "label": "내가 가져다주겠소.", "id": "bring", "do": [{ "flag": "brought_prison_food" }] },
		{ "label": "(포졸을 설득한다) 밥 한 그릇이오. 굶겨 죽이라는 분부는 아니잖소.", "id": "persuade", "do": [{ "flag": "persuaded_guard" }] },
		{ "label": "(지나간다)", "id": "pass", "do": [{ "flag": "passed_food" }] }] }])
	if f("brought_prison_food"):
		await d.ui.caption("목패를 보였다.", 1.4)
		await say("포졸", ["…관아 일 하는 사람이오?", "그럼 얼른 놓고 나오시오. 말은 짧게."])
		await say("월매", "…부탁하오.")
		d.give(P2.FOOD)
		d.main.world.set_prop_state("ti_jail/gate", "OPEN")
		d.camera(null)
		d.cutscene(false)
		d.ui.toast("옥사 나무살 앞으로", "info")
	elif f("persuaded_guard"):
		await say("포졸", ["…내가 들고 가겠소.", "당신들은 여기 있으시오."])
		d.move_actor("pojol_gate", ["ch_oesammun_in", "ch_jail_gate"], 1.6, "walk", "idle")
		await d.ui.caption("포졸이 바구니를 받아 들고 옥 쪽으로 간다.", 2.4)
		flag("food_in")
		await say("월매", "…고맙소.")
		d.camera(null)
		d.cutscene(false)
		end_p2a()
	else:
		await d.ui.caption("그냥 지나쳤다.", 1.4)
		d.camera(null)
		d.cutscene(false)

func food_other_way() -> void:
	flag("food_in")
	await d.ui.caption("뒤돌아보니 향단이 월매의 바구니를 받아 옥 담 뒤쪽으로 돌아간다.", 3.0)
	end_p2a()

# ACT 12 §31 — 옥 대화(CAMERA 12A: 나무살이 전경, 춘향은 안, 플레이어는 밖)
func jail_talk() -> void:
	_mark("C1202")
	d.cutscene(true)
	d.teleport_to("ch_jail_talk_p", "left")   # 살 앞 곁 — 12A 전경을 가리지 않게
	_shot(P2.CAM_12A)
	await d.wait(0.5)
	await say("춘향", "어머니가 보냈습니까?")
	await say("나그네", "그렇소.")
	await _cut("14_12A_jail_talk")
	await d.wait(1.0)
	await R([{ "choice": "", "options": [
		{ "label": "몽룡이 돌아올 겁니다.", "id": "return", "do": [{ "flag": "jail_talk_return" },
			{ "say": "춘향", "lines": ["그건 그 사람이 할 일이에요.", "제가 버티는 건 제 일이고요."] }] },
		{ "label": "왜 그렇게까지 합니까?", "id": "why", "do": [{ "flag": "jail_talk_why" },
			{ "say": "춘향", "lines": ["사또가 시킨다고 한 번 바꾸면…"] }, { "wait": 1.0 },
			{ "say": "춘향", "lines": ["다음엔 더 쉽게 바꾸게 될 테니까요."] }] },
		{ "label": "(아무 말 없이 밥을 둔다)", "id": "silent", "do": [{ "flag": "jail_talk_silent" }, { "say": "춘향", "lines": ["고맙습니다."] }] }] }])
	d.take(P2.FOOD)
	flag("food_in")
	flag("jail_talked")
	d.learn_clue("jail_talk")
	await d.wait(0.6)
	await d.ui.fade(true, 0.8)
	_cam_end()
	d.teleport_to("ch_jail_leave", "down")
	d.main.world.set_prop_state("ti_jail/gate", "SEALED")
	await d.wait(0.3)
	await d.ui.fade(false, 0.8)
	d.cutscene(false)
	end_p2a()

# II-A 끝 — 첫 밤. 여기서 멈춘다(술·쌀·상소와 몽룡의 귀환은 II-B)
func end_p2a() -> void:
	if f("p2a_done"): return
	flag("p2a_done")
	_mark("p2a_done")
	d.journal_note("옥의 첫 밤. 밥은 들어갔다")
	d.sfx("journal_stamp")
	d.ui.toast("「남원의 약속」 — 옥의 첫 밤", "journal")
	printerr("CTL to_jail=%.3f (%.0f/%.0fs) to_end=%.3f (%.0f/%.0fs) marks=%s" % [ctl_ratio("to_jail"), ctl.to_jail.ctl, ctl.to_jail.all,
		ctl_ratio("to_end"), ctl.to_end.ctl, ctl.to_end.all, JSON.stringify(ctl.marks)])

# 먼 길 막음(fast_travel.lock_why): 관아 일 도중 · 옥의 첫 밤이 끝나기 전. 걷기는 막지 않는다
func p2_travel_lock() -> String:
	if S.phase == "office" or (S.phase == "arrival" and f("labour_refused") and not f("rounded_up")):
		return "관아 잡역을 맡은 몸이다 — 지금은 멀리 갈 수 없다"
	if S.phase == "jail" and not f("p2a_done"):
		return "관아 목패를 아직 지니고 있다 — 오늘 밤은 남원을 떠날 수 없다"
	return ""

# 불러오기 — 장면 도중 저장이면 가까운 안전지점으로
func p2_on_load() -> void:
	d.free_move = false
	for k in ["leash_on", "roundup_on", "wolmae_on", "rope_on"]: S.flags.erase(k)
	if S.phase == "arrival" and f("proc_seen") and not f("proc_in"): S.flags["proc_in"] = true
	if S.phase == "arrival" and f("proc_on") and not f("proc_seen"): S.flags.erase("proc_on")
	if S.phase == "office":
		stage_office()
		# 줄에 섰지만 점고가 끝나지 않음 → 다시 줄로
		if f("in_line") and not f("jeomgo_done"): S.flags.erase("in_line"); S.flags.erase("_trig_c0703_line")
		# 수청·곤장 도중 → 데려가는 중으로(안마당에 닿으면 다시)
		if f("wolmae_summoned") and not f("jailed"):
			for k in ["sucheong1_done", "sucheong2_done", "restraint_obeyed", "restraint_loose", "restraint_refused", "arm_offered", "arm_waited", "escort_jail", "_trig_c1001_court", "_trig_c1103_jail"]:
				S.flags.erase(k)
			S.flags["escorting"] = true; S.flags["chun_on"] = true
			d.place_actor("chunhyang", "player")
	if S.phase == "jail":
		d.main.world.set_prop_state("ti_jail/gate", "SEALED")
		d.main.world.set_prop_state("ti_jail/cell", "SEALED")
		if f("dismissed") and not f("food_scene"): d.place_actor("wolmae", "ch_prison_food", null, "right")
		if f("brought_prison_food") and not f("jail_talked"):
			d.main.world.set_prop_state("ti_jail/gate", "OPEN")
			if not S.has(P2.FOOD): d.give(P2.FOOD, 1, true)
	if f("summons_given") and not f("wolmae_summoned") and not S.has(P2.SUMMONS): d.give(P2.SUMMONS, 1, true)
	if f("labour_started") and not f("docs_delivered") and not S.has(P2.DOCS): d.give(P2.DOCS, 1, true)

# 기록책 문단(II-A)
func p2_summary() -> Array:
	var p := []
	if not f("p2_started"): return p
	p.append("다른 고을을 돌고 남원에 다시 왔다. 단오 때와 달리 길에 장식이 없고, 관아 둘레에 곡식 가마니와 볏단이 쌓였다.")
	if f("proc_seen"): p.append("새 사또 변학도의 행차가 들어왔다. 사람들이 길 가장자리로 비켜서 고개를 숙였다.")
	if f("recog_done"):
		if f("labour_accepted"): p.append("관아 아전이 범 일 때의 나를 알아보고 하루 잡역을 맡겼다. 맡았다.")
		elif f("rounded_up"): p.append("관아 아전이 범 일 때의 나를 알아보고 잡역을 맡기려 했다. 싫다고 했지만 포졸이 고을 장정들과 함께 나를 끌고 갔다.")
	if f("docs_delivered"): p.append("문서를 이방에게 날랐고, 바깥마당의 기생들을 안으로 들였다. 서쪽 사령 줄 끝에 섰다.")
	if f("jeomgo_done"): p.append("기생 점고. 이방이 퇴기 월매의 딸 성춘향을 말하자 변학도가 “데려와.” 했다.")
	if f("wolmae_summoned"):
		var how := "관아에서 나오라 한다고 전했다." if f("summons_plain") else ("좋은 일로 부르는 것 같지 않다고 먼저 말했다." if f("warned_wolmae") else "성춘향을 데려오라 했다고 아전의 말만 전했다.")
		p.append("명령서를 들고 월매 집에 갔다. " + how + " 춘향이 스스로 “제가 가겠습니다.” 했다.")
	if f("sucheong2_done"): p.append("변학도가 두 번 수청을 요구했다. 춘향은 “이미 정한 사람이 있습니다.” 하고 두 번 다 거절했다.")
	if f("struck"):
		var r := "포승 한쪽을 잡았다." if f("restraint_obeyed") else ("느슨하게 잡았다가 다른 사령이 거들었다." if f("restraint_loose") else "줄을 놓았다. 다른 사령이 넘겨받았다.")
		p.append("곤장. 선임 사령이 줄을 잡으라 했다. 나는 " + r + " 춘향은 맞았다. 끝까지 “못 합니다.” 했다.")
	if f("jailed"):
		p.append(("일어서려는 춘향에게 팔을 내밀었다. 춘향은 말없이 잡았다. " if f("arm_offered") else "춘향은 혼자 형틀을 짚고 일어섰다. ") + "옥까지 데려갔고, 옥문이 닫혔다.")
	if f("food_scene"):
		if f("brought_prison_food"): p.append("밤, 월매가 밥을 들고 와 포졸에게 막혔다. 목패를 보이고 내가 들고 들어갔다.")
		elif f("persuaded_guard"): p.append("밤, 월매가 밥을 들고 와 포졸에게 막혔다. 포졸을 설득해 그가 들고 들어갔다.")
		elif f("passed_food"): p.append("밤, 월매가 밥을 들고 와 포졸에게 막혔다. 지나쳤다. 밥은 향단이 다른 길로 넣었다.")
	if f("jail_talked"):
		if f("jail_talk_return"): p.append("몽룡이 돌아올 거라고 하자 춘향은 그건 그 사람이 할 일이고, 버티는 건 제 일이라고 했다.")
		elif f("jail_talk_why"): p.append("왜 그렇게까지 하느냐고 묻자 춘향은 한 번 바꾸면 다음엔 더 쉽게 바꾸게 된다고 했다.")
		else: p.append("아무 말 없이 밥을 두었다. 춘향이 “고맙습니다.” 했다.")
	return p
