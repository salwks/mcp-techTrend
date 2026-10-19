# 회색 상자 M605 시험 봇(--gbbot=read | brute) — 사람 대신 퍼즐을 푼다. 헤드리스로 돈다(tools/run_story_tests.sh gb:m605-*).
#   read  : 기록을 열고 '읽는다'(글자 수 ÷ READ_CPS + THINK 초를 실제로 기다림), 글에 적힌 특징 낱말로 차례를 추론해 한 번에 묻는다.
#   brute : 기록을 열지 않는다. 여섯 차례를 정해진 순서로 찍는다. 정답이 1~6번째에 오는 여섯 판을 돌려 분포를 잰다(판마다 퍼즐을 처음부터).
#   모든 봇은 걷기(WALK m/s)·고르기(PICK초)를 실제 시간으로 기다린다 — 이겸의 기운 모으기 시간은 게임이 실제로 건다.
#   결과: 판마다 'GBM605 METRIC {json}', 끝에 'GBTEST PASS mode=… time_mean=… confirms_mean=…'(또는 FAIL).
extends Node

const D := preload("res://graybox/m605/gb_m605_data.gd")
const WALK := 3.2       # 걷는 속도 모형(m/s)
const READ_CPS := 10.0  # 읽는 속도 모형(글자/초 — 한국어 묵독 보통 속도 언저리)
const THINK := 12.0     # 두 기록을 견주어 차례를 세우는 시간 모형(초)
const PICK := 1.5       # 선택 창 하나를 고르는 시간(초)

var d
var mode := "read"
var c
var _want := 0
var results: Array = []

func _init(director, m: String) -> void:
	d = director
	mode = m
	name = "gb_bot"

func _ready() -> void:
	_run.call_deferred()

func _real(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout

func _run() -> void:
	d.ui.auto = true
	d.ui.auto_choice = func(_p, _labels): return _want
	var guard := 0
	while (d.case_fn == null or d.case_fn.t0 < 0.0 or d.runner.busy) and guard < 1200:
		await _real(0.1); guard += 1
	c = d.case_fn
	c.bot_mode = mode
	if mode == "shots":
		await _shots()
		d.main._quit()
		return
	if mode == "read":
		await _round_read()
	else:
		var perms := _perms()
		var ans: Array = c.correct_order()
		var rest := perms.filter(func(p): return p != ans)
		for r in 6:   # 정답이 r+1번째에 오는 찍기 순서
			var seq := rest.duplicate()
			seq.insert(r, ans)
			if r > 0: c.reset_puzzle()
			await _round_brute(seq)
	_report()

func _go(anchor: String) -> void:
	var p: Vector2 = d.anchor(anchor)
	var pp := Vector2(d.main.player_pos.x, d.main.player_pos.z)
	await _real(pp.distance_to(p) / WALK)
	d.teleport_to(anchor)

func _act(id: String, want := 0) -> void:
	_want = want
	await _real(PICK)
	d.interact(id)
	await _real(0.05)
	var guard := 0
	while (d.talking or d.runner.busy) and guard < 6000:
		await _real(0.05); guard += 1

func _assign(o: Array) -> void:
	for i in 3:
		var g: String = o[i]
		if c.assign_of.has(g) and int(c.assign_of[g]) == i: continue
		await _go("g_" + g)
		await _act("o_" + g, i)

func _ask() -> bool:
	await _go("knock")
	await _act("o_knock", 0)
	return d.S.is_flag("GB_CONFIRMED")

func _erase() -> void:
	var g := String(d.S.vars.get("GB_LAST", ""))
	await _go("g_" + g)
	Input.action_press("interact")
	_want = 0
	d.interact("o_erase_" + g)
	await _real(0.05)
	var guard := 0
	while (d.talking or d.runner.busy) and guard < 6000:
		if c.finished: Input.action_release("interact")
		await _real(0.05); guard += 1
	Input.action_release("interact")

# ---- 읽는 봇: 보이는 글만 쓴다 ----
func _round_read() -> void:
	await _go("record")
	await _act("o_record")
	var chars := 0
	for r in D.inside_records(): chars += String(r.text).length() + String(r.title).length()
	for n in D.outside_notes(): chars += String(n.text).length() + String(n.title).length()
	var read_s := float(chars) / READ_CPS + THINK
	printerr("GBBOT read chars=%d model_read=%.1fs" % [chars, read_s])
	await _real(read_s)
	var o := infer()
	printerr("GBBOT read infer=%s" % "-".join(o))
	await _assign(o)
	var ok := await _ask()
	var guard := 0
	while not ok and guard < 6:   # 추론이 틀렸으면(있어서는 안 됨) 기록 줄을 보고 다시 — 여기서는 찍기로 대신한다
		guard += 1
		for p in _perms():
			await _assign(p)
			ok = await _ask()
			if ok: break
	await _erase()
	results.append(_last_metric())

# 글에서 특징 낱말 → 홈, 기록의 '…지나고 나서야 / …밟고 나면' 줄에서 앞뒤 → 차례, 아이 말 '마지막 돌' → 셋째가 마지막(자리만 쓴다)
func infer() -> Array:
	var kw := { "root": ["뿌리"], "step": ["돌턱", "넙적돌"], "moss": ["이끼", "미끄러", "기우", "기울"] }
	var feat_of := {}
	for n in D.outside_notes():
		if String(n.g) == "": continue
		for f in kw:
			for w in kw[f]:
				if String(n.text).contains(w): feat_of[f] = String(n.g)
	var before := []   # [앞 특징, 뒤 특징]
	for r in D.inside_records():
		var t := String(r.text)
		if not (t.contains("나서야") or t.contains("나면")): continue
		var hits := []
		for f in kw:
			var at := -1
			for w in kw[f]:
				var i := t.find(w)
				if i >= 0 and (at < 0 or i < at): at = i
			if at >= 0: hits.append([at, f])
		hits.sort_custom(func(a, b): return a[0] < b[0])
		for i in hits.size() - 1: before.append([hits[i][1], hits[i + 1][1]])
	# 위상 정렬(셋)
	var feats := ["root", "step", "moss"]
	var order := []
	while not feats.is_empty():
		for f in feats:
			var has_pre := false
			for b in before:
				if b[1] == f and feats.has(b[0]): has_pre = true
			if not has_pre:
				order.append(f); feats.erase(f); break
	return order.map(func(f): return String(feat_of.get(f, "")))

# ---- 찍는 봇 ----
func _round_brute(seq: Array) -> void:
	for o in seq:
		await _assign(o)
		if await _ask(): break
	await _erase()
	results.append(_last_metric())

func _perms() -> Array:
	var ids: Array = D.ORDER_IDS
	var out := []
	for a in ids:
		for b in ids:
			for cc in ids:
				if a != b and b != cc and a != cc: out.append([a, b, cc])
	return out

func _last_metric() -> Dictionary:
	return { time = c.t_done, confirms = c.confirms.size(), mistakes = c.mistakes, pause = snappedf(c.pause_total, 0.1) }

func _report() -> void:
	var n := results.size()
	var ok := n > 0
	var st := 0.0; var sc := 0.0; var tmin := INF; var tmax := 0.0
	for r in results:
		if float(r.time) < 0.0: ok = false
		st += float(r.time); sc += float(r.confirms)
		tmin = minf(tmin, float(r.time)); tmax = maxf(tmax, float(r.time))
	var line := "mode=%s rounds=%d time_mean=%.1f time_min=%.1f time_max=%.1f confirms_mean=%.2f per_round=%s" % [mode, n, st / maxf(1, n), tmin, tmax, sc / maxf(1, n), JSON.stringify(results)]
	print("GBTEST %s %s" % ["PASS" if ok else "FAIL", line])
	printerr("GBTEST %s %s" % ["PASS" if ok else "FAIL", line])
	d.main._quit()

# ---- 화면 찍기(창 필요): --gbbot=shots — shots/gb_m605/ 에 경기장·기록·차례 정하기·확인(틀림·맞음)·지우기 ----
func _snap(nm: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var dir := ProjectSettings.globalize_path("res://shots/gb_m605")
	DirAccess.make_dir_recursive_absolute(dir)
	get_viewport().get_texture().get_image().save_png(dir.path_join(nm + ".png"))
	printerr("GBSHOT " + nm)

func _shots() -> void:
	await _real(4.0)
	await _snap("01_arena")
	d.ui.auto_hold = 3.0
	d.teleport_to("record")
	_want = 0
	d.interact("o_record")
	await _real(1.6); await _snap("02_record_inside")
	await _real(3.0); await _snap("03_record_outside")
	await _idle()
	d.ui.auto_hold = 2.5
	d.teleport_to("g_C1"); _want = 0
	d.interact("o_C1")
	await _real(1.4); await _snap("04_assign_choice")
	await _idle()
	d.ui.auto_hold = 0.03
	for p in [["C2", 1], ["C3", 2]]:
		d.teleport_to("g_" + String(p[0])); await _act("o_" + String(p[0]), int(p[1]))
	d.teleport_to("start"); await _real(1.0); await _snap("05_assigned_wrong_order")
	d.ui.auto_hold = 2.6
	d.teleport_to("knock"); _want = 0
	d.interact("o_knock")
	await _real(1.4); await _snap("06_confirm_choice")
	await _real(5.0); await _snap("07_confirm_pause")
	while d.ui._waiting != "say": await _real(0.1)
	await _real(7.4); await _snap("08_wrong_record_line")
	await _idle()
	d.ui.auto_hold = 0.03
	await _assign(c.correct_order())
	d.ui.auto_hold = 2.6
	d.teleport_to("knock"); _want = 0
	d.interact("o_knock")
	while d.ui._waiting != "say": await _real(0.1)
	await _real(0.6); await _snap("09_confirm_right")
	await _idle()
	var g := String(d.S.vars.get("GB_LAST", ""))
	d.teleport_to("g_" + g)
	await _real(0.6)
	Input.action_press("interact")
	d.interact("o_erase_" + g)
	await _real(1.3); await _snap("10_erase_hold")
	while not c.finished and d.ui._waiting != "say": await _real(0.1)
	Input.action_release("interact")
	await _real(0.3); await _snap("11_erased")
	await _idle()
	Input.action_release("interact")

func _idle() -> void:
	await _real(0.05)
	var guard := 0
	while (d.talking or d.runner.busy) and guard < 6000:
		await _real(0.05); guard += 1
