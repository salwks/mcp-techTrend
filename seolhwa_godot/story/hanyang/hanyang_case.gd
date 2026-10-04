# 사건 「비어 있는 책방」 — 데이터로 쓰기 번거로운 연출(도착·책방 상태·사내 등장·추격과 다시 쫓기·책쾌 구조·허브 열기)과 기록책·결말 카드.
# 데이터(hanyang_data.gd)의 { "call": "이름" }과 조건식 fn('이름')이 이 함수들을 부른다.
extends RefCounted

const D := preload("res://story/hanyang/hanyang_data.gd")
const Chase := preload("res://scripts/story/chase.gd")
const Progress := preload("res://scripts/region/progress.gd")
const CASE_TITLE := "비어 있는 책방"
const SHOP_CLUES := ["ink", "string", "window", "torn", "tea"]
const MAX_RETRY := 2
const FAR_ARRIVAL := 600.0     # 숭례문에서 이보다 먼 곳(노정 끝 노들 남쪽)에 닿으면 나루를 건너 숭례문 앞까지

var d      # story_director
var S:
	get: return d.S

func _init(director) -> void:
	d = director

func R(steps: Array) -> void:
	await d.runner.exec(steps, d.runner.gen)

func flag(k: String, v = true) -> void:
	S.flags[k] = v; d.runner.log_line("flag", [k, v]); d.mark_dirty()

func f(k: String) -> bool: return S.is_flag(k)

# ---------------------------------------------------------------------------
# 판정
# ---------------------------------------------------------------------------
func shop_clues() -> int:
	var n := 0
	for c in SHOP_CLUES:
		if S.has_clue(c): n += 1
	return n

# ACT 2 세 사건이 모두 끝났나(§14·ACT 3 잠금)
# v2.3.1: 완료 판정은 CASE_*_COMPLETE(강릉·경주·황주). 그 체계 전 저장은 결말 변수로도 본다. 순서는 상관없다
func act2_all_done() -> bool:
	for k in ["GANGNEUNG", "GYEONGJU", "HWANGJU"]:
		var v = S.vars.get("CASE_%s_COMPLETE" % k, Progress.get_var("CASE_%s_COMPLETE" % k, false))
		var o := String(S.vars.get("CASE_%s_OUTCOME" % k, Progress.get_var("CASE_%s_OUTCOME" % k, "")))
		if not bool(v) and o == "": return false
	return true

# §14: 종이 뭉치 포장지의 박규상 객주 납품 표식 — 표식이 있다고 범죄 증거는 아니다(본 횟수만 +1)
func park_wrap() -> void:
	if f("park_wrap"): return
	flag("park_wrap")
	S.vars["MAIN_PARK_MARK_COUNT"] = int(S.vars.get("MAIN_PARK_MARK_COUNT", 0)) + 1
	d.runner.log_line("var", ["MAIN_PARK_MARK_COUNT", S.vars.MAIN_PARK_MARK_COUNT])

# v2.2: 납품표를 처음 봤을 때 — 박규상 표식 +1, 이름을 앎
func park_slip() -> void:
	if f("park_slip"): return
	flag("park_slip")
	S.vars["MAIN_PARK_MARK_COUNT"] = int(S.vars.get("MAIN_PARK_MARK_COUNT", 0)) + 1
	S.vars["MAIN_PARK_NAME_KNOWN"] = true
	d.runner.log_line("var", ["MAIN_PARK_MARK_COUNT", S.vars.MAIN_PARK_MARK_COUNT])

func check_shop() -> void:
	if shop_clues() >= 3 and S.has_clue("window") and not f("shop_read"):
		flag("shop_read")
		d.ui.toast("뒤창 밖 발자국이 피맛골 쪽으로 나 있다.", "info")

# ---------------------------------------------------------------------------
# 세계 상태(책방·창고 프롭, 발자국 데칼) — 불러올 때마다 국면에 맞춰 다시 건다
# ---------------------------------------------------------------------------
func prop(key: String, state: String) -> void:
	var w = d.world
	if w.has_method("set_prop_state"): w.set_prop_state(key, state)

func _decals(group: String, on: bool) -> void:
	var dc = d.world.get("decals")
	if dc != null: dc.set_group_visible(group, on)

func shop_state() -> void:
	var hub: bool = S.phase == "done"
	prop("hy_sc_chaekbang/window", "SEALED" if hub else "OPEN")
	prop("hy_sc_chaekbang_meoktong", "NORMAL" if hub else "FALLEN")
	prop("hy_sc_chaekbang_kkeun", "NORMAL" if hub else "BROKEN")
	prop("hy_sc_chaekbang_papers", "NORMAL" if hub else "MOVED")
	prop("hy_sc_chaekbang_desk", "NORMAL" if hub else "MOVED")
	prop("hy_sc_chaekbang_books", "NORMAL" if hub else "FALLEN")
	prop("hy_sc_chaekbang_tea", "USED")   # 허브: 책쾌가 다시 차를 끓인다(지역 변화)
	prop("hy_sc_chaekbang_lamp", "NORMAL")
	prop("hy_sc_bin_changgo_kkeun", "BROKEN" if f("freed") else "NORMAL")
	_decals("s1003_tracks", S.has_clue("window") and not hub)

func show_tracks() -> void:
	_decals("s1003_tracks", true)

func on_load() -> void:
	shop_state()
	# 추격 도중 저장은 추격 앞(책방을 나서기 전)으로 되돌린다
	if f("woochi_seen") and not f("chase_done") and not f("chase_lost"):
		S.flags.erase("woochi_seen")
		S.flags.erase("_trig_s1003_start")

# ---------------------------------------------------------------------------
# S1001 도착 — 노들 남쪽 노정 끝에 닿았으면 나루를 건너 숭례문 앞까지(이동 대체가 아니라 '건너온 길'의 마무리)
# ---------------------------------------------------------------------------
func arrive() -> void:
	var pp := Vector2(d.main.player_pos.x, d.main.player_pos.z)
	var far := pp.distance_to(d.anchor("gate")) > FAR_ARRIVAL
	d.cutscene(true)
	if far:
		await d.ui.fade(true, 0.6)
		d.teleport_to("gate_front", "up")
		await d.wait(0.3)
		await d.ui.fade(false, 0.8)
		await d.ui.caption("노들 나루를 건너 숭례문 앞에 섰다.", 2.2)
	d.camera({ "focus": "gate_view", "distance": 70.0, "pitch": 24.0 })
	d.main.rig.update(0, d.main.player_pos, d.main.player.facing, null, true)
	await d.wait(2.6)
	d.camera(null)
	await d.wait(0.6)
	d.cutscene(false)
	flag("arrived")

# ---------------------------------------------------------------------------
# S1003 사내 등장 → 추격(놓치면 §29: 다시 쫓거나 발자국을 따라간다 — 어느 쪽이든 이야기는 이어진다)
# ---------------------------------------------------------------------------
func woochi_appears() -> void:
	flag("woochi_seen")
	d.place_actor("woochi", "lane_mouth", null, "left")
	d.anim_actor("woochi", "idle")
	d.cutscene(true)
	d.camera({ "focus": [-232.0, -930.0], "distance": 22.0, "pitch": 34.0 })
	await d.wait(0.5)
	await d.ui.caption("피맛골 어귀. 가벼운 차림의 사내가 이쪽을 보고 있다.", 2.4)
	d.anim_actor("woochi", "crouch")
	await d.wait(0.6)
	d.learn_clue("figure")
	d.camera(null)
	d.cutscene(false)

func run_chase() -> void:
	var cp := -1
	var tries := 0
	while true:
		var res: String = await Chase.run(d, "s1003", cp)
		d.runner.last["chase"] = res
		if res == "end":
			flag("chase_done")
			flag("chase_followed")
			d.learn_clue("rooftop")
			await d.ui.caption("다리 건너 인파 속으로 사내가 사라졌다.", 2.2)
			await d.ui.caption("포졸  “또 우치 그놈이로군! 지붕을 제 마당처럼 다녀.”", 2.6)
			d.learn_clue("name")
			S.vars["CASE_HANYANG_OUTCOME"] = "followed"
			break
		tries += 1
		await d.ui.caption("놓쳤다.", 1.4)
		var opts := []
		if tries <= MAX_RETRY: opts.append({ label = "다시 쫓는다 (마지막으로 본 길목에서)" })
		opts.append({ label = "발자국을 따라간다" })
		var i: int = await d.ui.choice("", opts)
		if tries <= MAX_RETRY and i == 0:
			cp = int(S.flags.get("_chase_s1003_cp", 0))
			await d.ui.fade(true, 0.5)
			d.place_actor("woochi", "lane_mouth")   # 추격 모듈이 길목에 다시 세운다
			await d.wait(0.2)
			d.ui.fade(false, 0.5)
			continue
		flag("chase_lost")
		S.vars["CASE_HANYANG_OUTCOME"] = "lost"
		d.learn_clue("rooftop", true)
		d.ui.toast("젖은 발자국이 개천 쪽으로 나 있다.", "info")
		d.journal_note("사내를 놓쳤다. 발자국을 따라간다")
		break
	d.mark_dirty()

func chase_pojol() -> void:
	d.ui.caption("포졸  “어이, 거기 서!”", 1.6)

# ---------------------------------------------------------------------------
# S1005 빈 창고 → 책쾌
# ---------------------------------------------------------------------------
func open_warehouse() -> void:
	flag("gate_open")
	await d.ui.examine("빈 창고", ["빗장을 벗기자 문짝이 삐걱 열린다.", "어둑한 안쪽, 기둥에 사람이 묶여 있다."], "clue")
	d.place_actor("chaekkwae", "bound", null, "down")
	d.anim_actor("chaekkwae", "tied")

func free_chaekkwae() -> void:
	flag("freed")
	prop("hy_sc_bin_changgo_kkeun", "BROKEN")
	d.anim_actor("chaekkwae", "sit")
	await d.wait(0.6)

# ---------------------------------------------------------------------------
# S1006 허브 열기 — 소문(rumors_data HY_*), 세 노정, ACT 3 잠금
# ---------------------------------------------------------------------------
func open_hub() -> void:
	d.cutscene(true)
	await d.ui.fade(true, 0.7)
	S.phase = "done"
	d.on_phase()
	shop_state()
	d.place_actor("chaekkwae", "counter", null, "down")
	d.anim_actor("chaekkwae", "sit")
	d.teleport_to([-252.0, -931.8], "up")
	d.camera({ "focus": "shop", "distance": 16.0, "pitch": 36.0 })
	await d.wait(0.3)
	await d.ui.fade(false, 0.7)
	await d.ui.caption("책방에 다시 차 끓는 냄새가 돈다.", 2.2)
	S.vars["ACT2_OPEN"] = true
	S.vars["ACT2_ROUTES"] = ["GG_HANYANG-GW_GANGNEUNG", "GG_HANYANG-GS_GYEONGJU", "GG_HANYANG-HH_HWANGJU"]
	if String(S.vars.get("CASE_HANYANG_OUTCOME", "")) == "": S.vars["CASE_HANYANG_OUTCOME"] = "followed"
	d.runner.log_line("var", ["ACT2_OPEN", true])
	d.ui.toast("새 길 — 강릉 · 경주 · 황주 (어디부터 가도 된다)", "journal")
	d.journal_note("세 갈래 — 강릉 · 경주 · 황주")
	d.camera(null)
	d.cutscene(false)
	d.journal_note("사건 종결 — 「%s」" % CASE_TITLE)
	await d.show_ending()
	d.save()

# ---------------------------------------------------------------------------
# 지역: 순찰
# ---------------------------------------------------------------------------
func ambient(dt: float) -> void:
	Chase.patrol(d, dt)

# ---------------------------------------------------------------------------
# 사건 기록(R)·결말 카드
# ---------------------------------------------------------------------------
func summary() -> Array:
	var p := []
	p.append("남원의 노인이 말했다. 기록책을 든 양반이 한양으로 갔다고. 이겸 선생의 쪽지: 종루 뒤 피맛골, 책쾌.")
	if f("in_shop"):
		p.append("책방 문은 열려 있었고 사람은 없었다.")
		var bits := []
		for c in [["ink", "넘어간 먹통"], ["string", "끊어진 끈"], ["window", "열린 뒤창"], ["torn", "찢긴 장부"], ["tea", "아직 따뜻한 차"]]:
			if S.has_clue(c[0]): bits.append(c[1])
		if not bits.is_empty(): p.append(", ".join(bits) + ".")
	if f("woochi_seen"): p.append("피맛골 어귀의 사내가 달아났다. 담을 타고 지붕을 건넜다.")
	if f("chase_followed"): p.append("광통교까지 쫓았다. 사내는 다리 건너 인파 속으로 사라졌다.")
	elif f("chase_lost"): p.append("사내를 놓쳤다. 젖은 발자국이 개천 둑을 따라 광통교로 이어졌다.")
	if S.has_clue("papers"): p.append("다리 난간에 종이 세 장 — 강릉 · 경주 · 황주. 이겸 선생의 필체. 뒷면: “쫓아올 테면 제대로 보고 오시오.”")
	if f("freed"): p.append("책쾌는 책방 옆 빈 창고에 묶여 있었다. 다친 데는 없다. “그 사람도 옛 기록을 찾았소.”")
	if S.phase == "done":
		p.append("세 갈래 길이 열렸다. 강릉 · 경주 · 황주 — 어디부터 가도 된다. 세 곳을 다 돌아야 다음 길이 보일 것이다.")
		var left := []
		for k in [["CASE_GANGNEUNG_OUTCOME", "강릉"], ["CASE_GYEONGJU_OUTCOME", "경주"], ["CASE_HWANGJU_OUTCOME", "황주"]]:
			if String(S.vars.get(k[0], "")) == "": left.append(k[1])
		if not left.is_empty(): p.append("남은 곳: " + " · ".join(left))
	return p

func journal() -> Dictionary:
	if not f("case_started"):
		return { "cases": [], "empty": "기록책에 새로 적힌 곳: 한양." }
	var clues := []
	for id in S.clues:
		var c: Dictionary = d.data.clues.get(id, { "title": id, "text": "" })
		clues.append({ "title": c.title, "text": c.text })
	return { "cases": [{ "id": "hanyang", "title": CASE_TITLE, "status": "solved" if S.phase == "done" else "active",
		"summary": summary(), "clues": clues, "rules": [], "solutions": [], "notes": S.notes }] }

func ending_data() -> Dictionary:
	var lost := String(S.vars.get("CASE_HANYANG_OUTCOME", "")) == "lost"
	return {
		"case_title": CASE_TITLE,
		"title": "지붕 위의 사내",
		"outcome": "lost" if lost else "followed",
		"paragraphs": [
			"책쾌의 책방은 비어 있었다. 뒤창 밖 발자국을 따라 피맛골과 개천을 지나 광통교까지." if not lost
				else "책쾌의 책방은 비어 있었다. 지붕을 타는 사내를 놓쳤지만, 젖은 발자국이 광통교까지 이어졌다.",
			"사람들은 그를 ‘우치’라 부른다. 그가 남긴 종이 세 장에는 이겸 선생의 글씨로 강릉 · 경주 · 황주.",
			"책쾌는 빈 창고에 묶여 있었고, 다치지 않았다. 이겸 선생도 옛 기록을 찾고 있었다고 한다.",
		],
		"record": "단서 %d개. 기록책에 새로 적힌 곳 — 강릉 · 경주 · 황주." % S.clues.size(),
	}
