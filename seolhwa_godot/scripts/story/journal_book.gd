# 기록책 쪽 만들기(보강서 §6·§12·§15·§21·§22·§24) — story_ui.journal_show(pages)에 넘길 자료.
#   1 여행 기록: 이겸의 원칙 세 줄, 찾는 사람 — 이겸(마지막 확인 장소 · 현재 행방), 이겸의 흔적(MAIN_MASTER_TRACE 등 공통 변수에서)
#   2 사건 기록: 지금 공간의 사건(자세히) + 다른 사건(제목·진행). 숫자 체크리스트를 쓰지 않는다 — 단서 글이 뜻으로 자란다.
#       현재까지 확인한 것(◆확인 · ◇들음 — 발언자 · △추정) / <규칙 칸> / 관찰 / 아직 모르는 것 / 확인한 장소 / 사용 가능한 관련 물건 / 할 수 있는 일
#   3 여행 방법: 이동·살펴보기·대화·기록책·지도·물건·싸움(튜토리얼을 놓친 사람을 위해 — 자동으로 열지 않는다)
# 사건 데이터에서 읽는 것(모두 있으면 쓰고 없으면 건너뛴다 — 어느 사건이나 같은 틀):
#   clues.<id>  { title, text, kind: fact|heard|guess(기본 fact), by: "주모"(heard면 발언자 — 반드시), by_if: [[조건식, 발언자], …],
#                 text_if: [[조건식, 글], …](맞는 마지막 글로 자란다) }
#   rules.<id>  { …같은 필드, kind 기본 guess }
#   journal     { unknowns: [{ text, until: 조건식(참이 되면 지운다), when }], places: [{ name, when }], items: [{ id, when }],
#                 solutions_when: 조건식(이게 참이 되기 전엔 '할 수 있을 것 같은 일'을 쓰지 않는다 — 무엇과 맞설지 미리 알려 주지 않게) }
#   case_fn     summary() → [문단], solutions() → [{title, available, text, hint}] ("???" 제목은 쓰지 않는다 — 해결법 수를 알려 주지 않는다)
#   S.flags._obs [{ about, text }] — 관찰(director.observe / 명령 { "observe": 글, "about": 대상 })
extends RefCounted

const Progress := preload("res://scripts/region/progress.gd")
const GameSettings := preload("res://scripts/story/game_settings.gd")

const PRINCIPLE := ["본 것은 본 대로.", "들은 것은 누가 말했는지.", "모르는 것은 모른다고."]
const CASE_TITLES := { namwon = "산길의 실종", hanyang = "비어 있는 책방", gangneung = "고개에 남은 종소리", hwangju = "빈 배의 값", pyongyang = "강을 판 사내" }
const PLACE_KO := { HANYANG = "한양", GANGNEUNG = "강릉", GYEONGJU = "경주", HWANGJU = "황주", PYEONGYANG = "평양", PYONGYANG = "평양",
	HAMHUNG = "함흥", HAMHEUNG = "함흥", JEJU = "제주" }
# 흔적 한 줄(어디서 어떻게 알았나) — 없는 토큰은 이름만
const TRACE_LINE := {
	HANYANG = { tag = "heard", by = "남원 노인", text = "“전에도 그런 책 들고 다니던 양반이 있었소. 한양 간다고 했지.”" },
	GANGNEUNG = { tag = "fact", text = "국사성황사 옛 제의 기록 뒷장에 선생의 필체 — “사람이 훔친 것과 사람이 아닌 것이 남긴 흔적을 섞지 말 것.”" },
	PYONGYANG = { tag = "fact", text = "평양 감영 서리가 간직한 종이 한 장, 선생의 필체 — “글보다 고쳐 쓴 자리를 먼저 보라. 거짓말은 새 문장을 만들지만, 손은 옛 흔적을 다 지우지 못한다.”" },
	HAMHUNG = { tag = "fact", text = "북청길 함관령 옛 역참. 제 기록을 한 장씩 태워 언 역졸을 살리고 계셨다. “그 책 아직 갖고 있었구나.”" },
}
static var last_page := 0

static func build(d, page := -1) -> Dictionary:
	var pages := [_travel(d), _cases(d), _help(d)]
	var p := last_page if page < 0 else page
	return { pages = pages, page = clampi(p, 0, pages.size() - 1) }

static func _vars(d) -> Dictionary:
	var v: Dictionary = Progress.vars().duplicate()
	if d != null and d.S != null: v.merge(d.S.vars, true)
	return v

# ---- 1 여행 기록 ----
static func _travel(d) -> Dictionary:
	var v := _vars(d)
	var b := [{ t = "title", text = "여행 기록" }]
	for l in PRINCIPLE: b.append({ t = "quote", text = l, size = 20 })
	b.append({ t = "head", text = "찾는 사람 — 이겸" })
	var trace: Array = Array(String(v.get("MAIN_MASTER_TRACE", "")).split(",", false)).map(func(x): return String(x).strip_edges().to_upper())
	var last := "남원"
	if not trace.is_empty(): last = String(PLACE_KO.get(trace[-1], trace[-1]))
	b.append({ t = "para", text = "마지막 확인 장소: " + last })
	b.append({ t = "para", text = "현재 행방: " + ("찾았다 — 함흥 북청길 함관령 옛 역참" if bool(v.get("MAIN_MASTER_FOUND", false)) else "모름") })
	# 함흥(S6010) 뒤: 다음에 찾을 사람 — 곽칠성(제주)
	if bool(v.get("MAIN_MASTER_FOUND", false)) and bool(v.get("MAIN_PAST_EVENT_KNOWN", false)) and not bool(v.get("MAIN_GWAK_FOUND", false)):
		b.append({ t = "head", text = "다음에 찾을 사람 — 곽칠성" })
		b.append({ t = "entry", tag = "heard", by = "이겸", title = "제주", text = "열두 해 전 서강 창고 사건의 증인. 죄를 쓰고 제주로 귀양 갔다. “내가 가야 했는데 못 갔다.”" })
		b.append({ t = "para", text = "제주 가는 배는 해남 관두포에서 뜬다. 남해 뱃길은 남원 남쪽 끝에서 시작한다." })
	b.append({ t = "head", text = "이겸의 흔적" })
	b.append({ t = "entry", tag = "fact", title = "남원", text = "기록책 마지막 장 — “남원에서 확인할 것이…” 문장은 거기서 끊겼다." })
	for tk in trace:
		var info: Dictionary = TRACE_LINE.get(tk, { tag = "fact", text = "" })
		b.append({ t = "entry", tag = info.tag, by = String(info.get("by", "")), title = String(PLACE_KO.get(tk, tk)), text = String(info.text) })
		if tk == "HANYANG" and bool(v.get("ACT2_OPEN", false)):
			b.append({ t = "entry", tag = "fact", title = "강릉 · 경주 · 황주", text = "광통교 난간의 종이 세 장. 선생의 필체다. 뒷면엔 다른 글씨 — “쫓아올 테면 제대로 보고 오시오.”" })
	if bool(v.get("MAIN_WOOCHI_KNOWN", false)):
		b.append({ t = "entry", tag = "heard", by = "한양 포졸", title = "‘우치’", text = "지붕을 타고 달아난 사내를 그렇게 불렀다." })
	return { id = "travel", tab = "여행 기록", blocks = b }

# ---- 2 사건 기록 ----
static func _cases(d) -> Dictionary:
	var b := [{ t = "title", text = "사건 기록" }]
	var cur := ""
	if d != null and d.S != null and d.case_fn != null and _started(d):
		cur = String(d.case_id)
		b.append_array(_case_detail(d))
	for id in Progress.data().cases:
		if String(id) == cur: continue
		var st: Dictionary = Progress.case_state(String(id))
		var fl: Dictionary = st.get("flags", {})
		if String(st.get("phase", "start")) == "start" and not bool(fl.get("case_started", false)): continue
		b.append({ t = "case", title = _case_title(String(id)), status = "해결" if String(st.get("phase", "")) == "done" else "진행 중" })
	if b.size() == 1: b.append({ t = "para", text = "아직 기록된 사건 없음", soft = true })
	return { id = "case", tab = "사건 기록", blocks = b }

static func _started(d) -> bool:
	var S = d.S
	return bool(S.flags.get("case_started", false)) or S.phase in ["done", "morning", "night"] or (S.phase != "start" and not S.clues.is_empty())

static func _case_title(id: String) -> String:
	if CASE_TITLES.has(id): return CASE_TITLES[id]
	var p := "res://story/%s/%s_data.gd" % [id, id]
	if FileAccess.file_exists(p):
		var dd = load(p).data()
		if dd is Dictionary: return String(dd.get("case", {}).get("record_title", id))
	return id

static func _case_detail(d) -> Array:
	var S = d.S
	var data: Dictionary = d.data
	var cs: Dictionary = data.get("case", {})
	var legacy: Dictionary = d.case_fn.journal() if d.case_fn.has_method("journal") else {}
	var lc: Dictionary = (legacy.get("cases", [{}]) as Array)[0] if not (legacy.get("cases", []) as Array).is_empty() else {}
	var solved: bool = String(lc.get("status", "")) == "solved" or S.phase == "done"
	var b := [{ t = "case", title = String(cs.get("record_title", lc.get("title", d.case_id))), status = "해결" if solved else "진행 중" }]
	if d.case_fn.has_method("summary"):
		for p in d.case_fn.summary(): b.append({ t = "para", text = String(p) })
	# 현재까지 확인한 것
	var got := []
	for id in S.clues: got.append(_entry(d, data.get("clues", {}).get(id, { "title": id }), "fact"))
	if not got.is_empty():
		b.append({ t = "head", text = "현재까지 확인한 것" })
		b.append_array(got)
	if not S.rules.is_empty():
		b.append({ t = "head", text = String(cs.get("rule_label", lc.get("rules_title", "범의 버릇"))) })
		for id in S.rules: b.append(_entry(d, data.get("rules", {}).get(id, { "title": id }), "guess"))
	var obs: Array = S.flags.get("_obs", [])
	if not obs.is_empty():
		b.append({ t = "head", text = "관찰" })
		for o in obs: b.append({ t = "entry", tag = "fact", title = String(o.get("about", "")), text = String(o.get("text", "")) })
	var jd: Dictionary = data.get("journal", {})
	var detailed := GameSettings.help() == "detailed"
	if not solved:
		var unk := []
		for u in jd.get("unknowns", []):
			if not d.runner.cond(u.get("when", true)): continue
			if u.has("until") and d.runner.cond(u.until): continue
			unk.append({ t = "para", text = "· " + String(u.text), size = 22 if detailed else 21 })
		var ob = d.get("onboard")
		if ob != null and String(ob.stall_line) != "": unk.push_front({ t = "entry", tag = "guess", title = String(ob.stall_line), text = "", strong = true })
		if not unk.is_empty():
			b.append({ t = "head", text = "아직 모르는 것" })
			b.append_array(unk)
	var places := []
	for pl in jd.get("places", []):
		if d.runner.cond(pl.get("when", true)): places.append(String(pl.name))
	if not places.is_empty():
		b.append({ t = "head", text = "확인한 장소" })
		b.append({ t = "para", text = " · ".join(places) })
	var items := []
	for it in jd.get("items", []):
		if d.S.has(String(it.id)) and d.runner.cond(it.get("when", true)): items.append(d.item_label(String(it.id)))
	if not items.is_empty() and not solved:
		b.append({ t = "head", text = "사용 가능한 관련 물건" })
		b.append({ t = "para", text = " · ".join(items) })
	if d.case_fn.has_method("solutions") and d.runner.cond(jd.get("solutions_when", true)):
		var sol := []
		for s in d.case_fn.solutions():
			if String(s.get("title", "???")) == "???": continue
			if bool(s.get("available", false)):
				sol.append({ t = "entry", tag = "guess", title = String(s.title), text = String(s.get("text", "")) })
			elif String(s.get("hint", "")) != "":
				sol.append({ t = "entry", tag = "guess", title = "", text = String(s.hint) })
		if not sol.is_empty() and not solved:
			b.append({ t = "head", text = "할 수 있을 것 같은 일" })
			b.append_array(sol)
	var notes: Array = lc.get("notes", S.notes)
	if not notes.is_empty():
		b.append({ t = "head", text = "적어 둔 것" })
		for n in notes: b.append({ t = "para", text = "— " + String(n), soft = true, size = 18 })
	return b

# 단서·규칙 한 줄: 꼬리표 + 자라는 글(text_if의 맞는 마지막)
static func _entry(d, c: Dictionary, dflt_kind: String) -> Dictionary:
	var text := String(c.get("text", ""))
	for ti in c.get("text_if", []):
		if d.runner.cond(ti[0]): text = String(ti[1])
	var by := String(c.get("by", ""))
	for bi in c.get("by_if", []):
		if d.runner.cond(bi[0]): by = String(bi[1])
	return { t = "entry", tag = String(c.get("kind", dflt_kind)), by = by, title = String(c.get("title", "")), text = text }

# ---- 3 여행 방법(§24) ----
static func _help(d) -> Dictionary:
	var v := _vars(d)
	var b := [{ t = "title", text = "여행 방법" }]
	var rows := [
		["이동", "WASD 걷기 · Shift를 누르고 있으면 달린다."],
		["살펴보기", "조사할 수 있는 것 가까이 가면 작은 먹점이 보이고, 손 닿는 거리에서 ‘E 살펴보기’가 뜬다. 멀리 있는 것은 표시하지 않는다."],
		["대화", "사람에게 다가가 E. 엿들리는 말은 그냥 지나가도 들린다. 사람마다 말이 다를 수 있다."],
		["기록책", "R. 여행 기록(이겸을 찾는 길)과 사건 기록. ◆ 확인 — 직접 본 것 · ◇ 들음 — 누가 말했는지 · △ 추정 — 짐작."],
		["지도", "M 고을 지도 · 지도 안에서 Tab으로 권역 · 전국 지도. 가 보았거나 정확히 들은 곳만 이름이 적힌다. H 역마(지나온 길 끝에서)."],
		["물건", "물건은 쓸 수 있는 자리에서만 ‘이곳에 사용할 수 있는 물건이 있다’가 뜬다. 무엇이 될지는 해 보아야 안다."],
		["싸움", "J 베기(길게: 모아 베기) · K 구르기(회피) · L 막기(누르고 있기) · I 활(누르고 있다 떼기) · U 떡 던지기. 상대가 몸을 낮추거나 멈추는 때를 본다."],
	]
	if int(v.get("ITEM_TALISMAN_SLOT", 0)) > 0: rows.append(["호신물", "Q 지니기 · 풀기."])
	rows.append(["멈춤 · 설정", "Esc — 계속 · 설정(상호작용 안내 · 조사 도움) · 여행 방법."])
	for r in rows:
		b.append({ t = "head", text = String(r[0]) })
		b.append({ t = "para", text = String(r[1]) })
	return { id = "help", tab = "여행 방법", blocks = b }
