# 회색 상자 M605 사건 스크립트 — 임시 상자·글자, 기록 읽기·차례 정하기·두드려 묻기·E 길게 지우기, 측정(GBM605 줄).
#   이야기 명령(story_runner)·조사 안내(E)·기록책(R)·선택 창(story_ui.choice)·조사 카드(story_ui.examine)를 그대로 쓴다. 새 체계 없음.
#   측정: 조작을 넘겨받은 때부터(t0) 기록을 연 때·확인(두드림)마다 시각/차례/결과·기다린 시간·지우기 끝 — 'GBM605 METRIC {json}' 한 줄.
extends RefCounted

const D := preload("res://graybox/m605/gb_m605_data.gd")
const UiFonts := preload("res://scripts/ui_fonts.gd")
const FEAT_TXT := { "step": "앞에 낮은 넙적돌(돌턱)", "moss": "젖은 이끼 · 바깥으로 기운 돌", "root": "높은 자리 · 굵은 뿌리가 감음" }

var d
var S:
	get: return d.S

var assign_of := {}        # 홈 id → 0/1/2(첫째·둘째·셋째)
var energy := D.ENERGY_MAX
var mistakes := 0
var confirms: Array = []   # [{ t, order:[홈…], ok, pause, hint }]
var t0 := -1.0
var t_read := -1.0
var t_done := -1.0
var reads := 0
var assigns := 0
var pause_total := 0.0
var erase_t := 0.0
var round_no := 1
var finished := false      # 시험 봇이 기다린다
var bot_mode := ""         # 봇이 돌리면 'read' · 'brute'(METRIC 줄에 남긴다)

var _root: Node3D
var _labels := {}          # 홈 id → Label3D(차례 글)
var _energy_l: Label3D
var _stroke := {}          # 홈 id → 숯 획 MeshInstance3D

func _init(director) -> void:
	d = director

func now() -> float: return Time.get_ticks_msec() / 1000.0
func el() -> float: return snappedf(now() - t0, 0.01) if t0 >= 0.0 else 0.0
func flag(k: String, v = true) -> void:
	S.flags[k] = v; d.runner.log_line("flag", [k, v]); d.mark_dirty()

func on_load() -> void:
	_build()

# ---------------------------------------------------------------------------
# 회색 상자(임시 모양 — 최종 그림 아님)
# ---------------------------------------------------------------------------
func _y(x: float, z: float) -> float: return d.world.height_at(x, z)

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	m.roughness = 1.0
	return m

func _box(parent: Node3D, size: Vector3, pos: Vector3, c: Color, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new(); bm.size = size
	mi.mesh = bm
	mi.material_override = _mat(c)
	mi.position = pos
	mi.rotation_degrees = rot
	parent.add_child(mi)
	return mi

func _cyl(parent: Node3D, r: float, h: float, pos: Vector3, c: Color, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new(); cm.top_radius = r; cm.bottom_radius = r * 1.3; cm.height = h
	mi.mesh = cm
	mi.material_override = _mat(c)
	mi.position = pos
	mi.rotation_degrees = rot
	parent.add_child(mi)
	return mi

func _label(parent: Node3D, text: String, pos: Vector3, size := 44, col := Color("#1d1a17")) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = UiFonts.main()
	l.font_size = size
	l.pixel_size = 0.006
	l.modulate = col
	l.outline_size = 10
	l.outline_modulate = Color("#f3ead6")
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.position = pos
	parent.add_child(l)
	return l

func _w(ax: float, az: float, up := 0.0) -> Vector3:
	var x := D.OX + ax; var z := D.OZ + az
	return Vector3(x, _y(x, z) + up, z)

func _build() -> void:
	if _root != null: return
	_root = Node3D.new(); _root.name = "graybox_m605"
	d.scene_root().add_child(_root)
	var stone := Color("#8d8a84"); var dark := Color("#2a2724")
	# 비탈(뒤판) — 경계 C 자리
	_box(_root, Vector3(15.0, 0.12, 3.0), _w(0.0, -7.4, 0.3), Color("#9a8a6e"), Vector3(-14, 0, 0))
	_label(_root, "경계 C — 비탈 가장자리 (회색 상자 시험 M605)", _w(0.0, -9.2, 3.6), 40, Color("#5a3a2a"))
	for g in D.ORDER_IDS:
		var G: Dictionary = D.GROOVES[g]
		var lift := float(G.lift)
		var gp := Vector3(float(G.x), 0.0, float(G.z))
		var base := _w(gp.x, gp.z, 0.0)
		var tilt := Vector3(0, 0, -12.0) if G.feat == "moss" else Vector3.ZERO
		if lift > 0.0: _box(_root, Vector3(2.2, lift, 2.0), base + Vector3(0, lift * 0.5, 0), Color("#6f6656"))   # 높은 자리(둔덕)
		var st := _box(_root, Vector3(1.3, 1.7, 0.7), base + Vector3(0, lift + 0.85, 0), stone, tilt)
		_box(st, Vector3(0.12, 1.2, 0.05), Vector3(0, 0.05, 0.36), dark)               # 홈(같은 무늬)
		_stroke[g] = _box(st, Vector3(0.42, 0.06, 0.04), Vector3(0, 0.15, 0.38), Color("#0c0b0a"), Vector3(0, 0, 18))   # 숯 획(아이 가슴 높이)
		_box(st, Vector3(0.3, 0.025, 0.04), Vector3(0.25, -0.35, 0.38), Color("#f4f1e8"))   # 분필 점검선
		match String(G.feat):
			"step": _box(_root, Vector3(1.1, 0.22, 0.7), base + Vector3(0, 0.11, 0.85), Color("#9b9890"))
			"moss":
				_box(_root, Vector3(1.6, 0.04, 1.2), base + Vector3(0.1, 0.02, 0.6), Color("#4f6b35"))
			"root":
				_cyl(_root, 0.13, 2.4, base + Vector3(0.75, lift + 0.7, 0.1), Color("#5b3b22"), Vector3(0, 0, 25))
				_cyl(_root, 0.11, 1.6, base + Vector3(1.0, lift * 0.5, 0.5), Color("#5b3b22"), Vector3(70, 0, 0))
		var feat_txt: String = FEAT_TXT[String(G.feat)]
		_label(_root, "%s\n%s\n숯 획 · 분필 점검선" % [G.name, feat_txt], base + Vector3(0, lift + 2.7, 0), 40)
		_labels[g] = _label(_root, "", base + Vector3(0, lift + 2.0, 0.3), 44, Color("#8a2a20"))
	# C 경계석(두드림 자리)
	_box(_root, Vector3(1.6, 1.1, 1.0), _w(0.0, -2.6, 0.55), Color("#77736c"))
	_label(_root, "C 경계석 — 두드림", _w(0.0, -2.6, 1.6), 40)
	_energy_l = _label(_root, "", _w(0.0, -2.6, 2.15), 40, Color("#5a3a2a"))
	# 기록지 묶음 · 다시 하기
	_box(_root, Vector3(0.7, 0.18, 0.5), _w(-3.6, 1.3, 0.5), Color("#e8dcbc"))
	_box(_root, Vector3(0.9, 0.42, 0.7), _w(-3.6, 1.3, 0.21), Color("#6b5a44"))
	_label(_root, "기록지 묶음\n(우치가 틈에서 들고 나옴)", _w(-3.6, 1.3, 1.4), 36)
	_box(_root, Vector3(0.5, 0.5, 0.5), _w(4.4, 2.0, 0.25), Color("#b0aaa0"))
	_label(_root, "(시험) 다시 하기", _w(4.4, 2.0, 0.95), 32, Color("#555"))
	_refresh_labels()

func _refresh_labels() -> void:
	for g in _labels:
		var l: Label3D = _labels[g]
		l.text = ("내가 정한 차례: " + D.RANK_LABEL[int(assign_of[g])]) if assign_of.has(g) else ""
	if _energy_l != null:
		var dots := ""
		for i in D.ENERGY_MAX: dots += "●" if i < energy else "○"
		_energy_l.text = "이겸 기력 " + dots

# ---------------------------------------------------------------------------
# 흐름
# ---------------------------------------------------------------------------
func begin() -> void:
	_build()
	d.teleport_to("start", "up")
	d.main.rig.override = { distance = 24.0, pitch = 50.0, fov = 30.0 }   # 회색 상자: 세 홈·경계석·기록이 한 화면에
	await d.ui.caption("7일 07:00 — A·B를 바로놓았다. 우치가 얇은 틈에서 기록지 묶음을 들고 나왔다.", 3.0)
	await d.ui.say("우치", ["그 양반, 이런 데서도 꼬박꼬박 적어 두었군.", "나는 순서를 읽을 수는 있어도 밖의 돌과는 짝을 못 맞추겠어."])
	d.ui.toast("기록을 읽고(E) · 세 홈에 차례를 정하고(E) · C 경계석에서 두드려 묻는다 · R 기록책", "info")
	S.phase = "explore"
	t0 = now()
	_log("start", {})

func read_record() -> void:
	reads += 1
	if t_read < 0.0: t_read = el()
	_log("read", { n = reads })
	var inside := []
	for r in D.inside_records(): inside.append("· %s\n%s" % [r.title, r.text])
	var outside := []
	for n in D.outside_notes(): outside.append("· %s\n%s" % [n.title, n.text])
	await d.ui.examine("안쪽 — 이겸의 기록지(◇ 스승님이 적은 것)", "\n\n".join(inside), "clue")
	await d.ui.examine("밖 — 내 탁본 노트(◆ M504에서 직접 봄)", "\n\n".join(outside), "clue")
	for r in D.inside_records(): d.learn_clue(r.id, true)
	for n in D.outside_notes(): d.learn_clue(n.id, true)
	if not S.is_flag("GB_READ"):
		flag("GB_READ")
		d.ui.toast("기록책(R)에 안쪽 기록과 탁본 노트를 적었다", "clue")

func assign(g: String) -> void:
	var G: Dictionary = D.GROOVES[g]
	var cur: String = ("지금: " + D.RANK_LABEL[int(assign_of[g])]) if assign_of.has(g) else "아직 정하지 않음"
	var opts := []
	for i in 3:
		var who := ""
		for o in assign_of:
			if o != g and int(assign_of[o]) == i: who = "  (지금 %s — 서로 바꾼다)" % D.GROOVES[o].name
		opts.append({ label = "안쪽 기록의 %s 자리%s" % [D.RANK_LABEL[i], who] })
	opts.append({ label = "비워 두기" })
	opts.append({ label = "그대로 둔다" })
	var i: int = await d.ui.choice("%s 홈 — 이겸이 걸은 차례에서 몇 번째인가? (%s)" % [G.name, cur], opts)
	if i == 4: return
	assigns += 1
	if i == 3: assign_of.erase(g)
	else:
		for o in assign_of.keys():
			if o != g and int(assign_of[o]) == i:
				if assign_of.has(g): assign_of[o] = assign_of[g]
				else: assign_of.erase(o)
		assign_of[g] = i
	_log("assign", { g = g, rank = (i if i < 3 else -1), order = order() })
	_refresh_labels()

# 지금 정한 차례(첫째·둘째·셋째 홈 id) — 빈 자리는 ""
func order() -> Array:
	var o := ["", "", ""]
	for g in assign_of: o[int(assign_of[g])] = g
	return o

func knock_confirm() -> void:
	var o := order()
	if o.has(""):
		await d.ui.say("", ["세 홈에 첫째·둘째·셋째를 다 정해야 차례대로 두드릴 수 있다."])
		return
	var desc := " → ".join(o.map(func(g): return D.GROOVES[g].name))
	var i: int = await d.ui.choice("정한 차례: %s\n이 차례대로 세 홈을 한 번씩 두드려 이겸에게 묻는다(두 번 = 맞다 / 한 번 = 아니다)." % desc,
		[{ label = "두드려 묻는다" }, { label = "아직 — 기록을 더 본다" }])
	if i != 0: return
	var n := confirms.size() + 1
	var pause := D.PAUSE_BASE + D.PAUSE_STEP * float(n - 1)
	_log("knock", { n = n, order = o })
	d.runner.log_line("log", "knock %s" % desc)
	for g in o:
		d.ui.toast("똑 — %s" % D.GROOVES[g].name, "info")
		await _real(0.6)
	# 이겸이 기운을 모은다(실제 시간 — 건너뛸 수 없다). 확인할수록 길어진다
	var t_p := now()
	var left := pause
	while left > 0.0:
		d.ui.caption("…안쪽이 조용하다. 이겸이 숨을 고른다 (%d초)" % ceili(left), 1.1)
		await _real(minf(1.0, left))
		left -= 1.0
	pause_total += now() - t_p
	energy = maxi(1, energy - 1)
	_refresh_labels()
	var ok: bool = o == correct_order()
	var gap := 0.8 + 0.35 * float(n)   # 피로: 두드림 사이가 길어진다
	var hint := ""
	if ok:
		d.ui.caption("쿵.", gap); await _real(gap)
		d.ui.caption("…………쿵.", gap); await _real(gap)
		confirms.append({ t = el(), order = o, ok = true, pause = pause })
		flag("GB_CONFIRMED")
		S.vars["GB_LAST"] = o[2]
		d.learn_clue("gb_right")
		_log("confirm", { n = n, ok = true, order = o })
		await d.ui.say("", ["느린 두 번. 맞다.", "셋째 자리 — %s가 아이의 '마지막 돌'이다. 그 홈의 숯 획을 지운다." % D.GROOVES[o[2]].name])
	else:
		mistakes += 1
		d.ui.caption("…………쿵.", gap + 0.6); await _real(gap + 0.6)
		hint = wrong_hint(o)
		confirms.append({ t = el(), order = o, ok = false, pause = pause, hint = hint })
		d.learn_clue("gb_wrong")
		_log("confirm", { n = n, ok = false, order = o, hint = hint })
		var r: Dictionary = _record(hint)
		var lines := ["한 번. 아니다.", "기록지를 다시 펼친다 — 「%s」" % r.title, String(r.text)]
		if energy <= 2: lines.append("(두드림 사이가 눈에 띄게 길어졌다. 스승님이 많이 지치셨다.)")
		await d.ui.say("", lines)

# 이 차례가 어긋나는 기록 한 줄(첫 어긋남) — 기록 단서 id
func wrong_hint(o: Array) -> String:
	var pos := {}
	for i in 3: pos[String(D.GROOVES[o[i]].feat)] = i
	for rel in D.RELATIONS:
		if int(pos[rel[0]]) > int(pos[rel[1]]): return String(rel[2])
	return "in_child"

func _record(id: String) -> Dictionary:
	for r in D.inside_records():
		if String(r.id) == id: return r
	return { title = "", text = "" }

func correct_order() -> Array:
	var out := []
	for f in D.TRUE_FEATS:
		for g in D.GROOVES:
			if String(D.GROOVES[g].feat) == f: out.append(g)
	return out

# 마지막 숯 획 지우기 — E를 누르고 있는 동안 문지른다(ERASE_HOLD초). 떼면 잠깐은 남고 오래 떼면 줄어든다
func erase(g: String) -> void:
	var t_s := now()
	d.ui.caption("E를 누르고 있으면 %s의 숯 획을 문지른다" % D.GROOVES[g].name, 2.0)
	erase_t = 0.0
	var idle := 0.0
	while erase_t < D.ERASE_HOLD:
		await _real(0.05)
		if Input.is_action_pressed("interact"):
			erase_t += 0.05; idle = 0.0
		else:
			idle += 0.05
			if idle > D.ERASE_GRACE: erase_t = maxf(0.0, erase_t - 0.1)
		var k := clampf(erase_t / D.ERASE_HOLD, 0.0, 1.0)
		var bar := ""
		for i in 10: bar += "■" if float(i) < k * 10.0 else "□"
		if _labels.has(g): (_labels[g] as Label3D).text = "숯 획 문지르는 중 %s\n(E 누르고 있기)" % bar
		if _stroke.has(g):
			var mi: MeshInstance3D = _stroke[g]
			mi.scale = Vector3(maxf(0.02, 1.0 - k), 1.0, 1.0)
	if _labels.has(g): (_labels[g] as Label3D).text = "숯 획을 지웠다"
	if _stroke.has(g):
		var mi2: MeshInstance3D = _stroke[g]
		mi2.visible = false
	flag("GB_DONE")
	t_done = el()
	var exit := "소나무 앞 넓은 출구" if mistakes == 0 else ("비탈 아래 좁은 출구" if mistakes <= 2 else "더 좁은 경계 — 우치가 한 번 더 줄을 받침")
	_log("erase", { g = g, hold = snappedf(now() - t_s, 0.01) })
	await d.ui.caption("…느린 두 번. 뒤에 붙어 있던 길이 서서히 제자리로 펴진다.", 2.6)
	await d.ui.say("", ["(기록지 여백) " + D.MARGIN, "이 획이었어.", "(시험 결과) 확인 %d번 · 틀림 %d번 · 걸린 시간 %.0f초 → %s" % [confirms.size(), mistakes, t_done, exit]])
	_metric(exit)
	finished = true

func reset_choice() -> void:
	var i: int = await d.ui.choice("(시험) 퍼즐을 처음부터 다시 할까? 시간·확인 수·기력이 처음으로 돌아간다.", [{ label = "다시 한다" }, { label = "그만" }])
	if i == 0: reset_puzzle()

func reset_puzzle() -> void:
	assign_of.clear(); energy = D.ENERGY_MAX; mistakes = 0; confirms.clear()
	t_read = -1.0; t_done = -1.0; reads = 0; assigns = 0; pause_total = 0.0
	finished = false
	round_no += 1
	for k in ["GB_READ", "GB_CONFIRMED", "GB_DONE"]: S.flags.erase(k)
	S.vars.erase("GB_LAST")
	for g in _stroke:
		var mi: MeshInstance3D = _stroke[g]
		mi.visible = true; mi.scale = Vector3.ONE
	d.mark_dirty()
	_refresh_labels()
	t0 = now()
	_log("start", { round = round_no })

func _real(sec: float) -> void:
	await d.get_tree().create_timer(sec, true, false, true).timeout

func _log(kind: String, x: Dictionary) -> void:
	x.t = el(); x.round = round_no
	printerr("GBM605 %s %s" % [kind, JSON.stringify(x)])

func _metric(exit: String) -> void:
	var m := { mode = bot_mode if bot_mode != "" else "human", round = round_no, time = t_done, confirms = confirms.size(), mistakes = mistakes,
		pause_total = snappedf(pause_total, 0.1), first_read = t_read, reads = reads, assigns = assigns, exit = exit,
		tries = confirms.map(func(c): return { t = c.t, order = "-".join(c.order), ok = c.ok, hint = c.get("hint", "") }) }
	printerr("GBM605 METRIC " + JSON.stringify(m))
	print("GBM605 METRIC " + JSON.stringify(m))

# 기록책(R) 머리 — 지금 상태 한두 줄
func summary() -> Array:
	var o := order()
	var s := " → ".join(o.map(func(g): return D.GROOVES[g].name if g != "" else "?"))
	return ["회색 상자 시험 M605. 정한 차례: %s · 확인 %d번 · 이겸 기력 %d/%d" % [s, confirms.size(), energy, D.ENERGY_MAX]]
