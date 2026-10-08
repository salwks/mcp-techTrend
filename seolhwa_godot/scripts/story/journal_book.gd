# 기록책 갈피 만들기(보강서 §6·§12·§15·§21·§22·§24) — story_ui.journal_show(자료)에 넘긴다. 그리는 것은 scripts/story/journal_view.gd(세로쓰기 선장본).
# 자료: { pages: [갈피 …], page: 펼칠 갈피 번호 }. 갈피 = { id, tab, blocks, front? }.
#   pages 차례(시험이 번호로 읽는다 — 0 여행 기록, 1 사건 기록은 그대로 둔다):
#     0 travel  여행 기록: 찾는 사람 — 이겸(마지막 확인 장소 · 현재 행방), 다음에 찾을 사람, 이겸의 흔적
#     1 case    사건 기록: 지금 공간의 사건(자세히) + 다른 사건(제목·진행). 숫자 체크리스트를 쓰지 않는다 — 단서 글이 뜻으로 자란다.
#               현재까지 확인한 것(◆확인 · ◇들음 — 발언자 · △추정) / <규칙 칸> / 관찰 / 아직 모르는 것 / 확인한 장소 / 관련 물건 / 할 수 있는 일
#     2 observe 관찰: 사건마다 직접 본 것(S.flags._obs — 저장된 다른 사건 것도)
#     3 people  사람의 말: 길에서 들은 소문(progress heard — ◇ 들음 — 말한 사람, 사실로 올리지 않는다)
#     4 items   물건·문서: 지닌 물건 · 짚어 본 문서(documents.gd _doc_found)
#     5 teach   스승의 가르침: 이겸의 세 원칙(세로로 크게) + 길에서 다시 만난 선생의 글(S0010·S2008·S3007·S4008·S5006·S6008, 얻은 것만) + 나의 첫 문장(S7008, 따로 한 쪽)
#     6 help    여행 방법(튜토리얼을 놓친 사람을 위해 — 자동으로 열지 않는다)
#     7 master  옛 기록(front — 책 맨 앞): 이겸이 앞서 적은 사건 둘. 어떻게 적는지 보여 주는 본보기(원작 제목은 쓰지 않는다).
#   build(d, page): page는 갈피 id 또는 번호. 번호는 예전 3쪽 차례(0 여행 · 1 사건 · 2 여행 방법)로 읽는다. section(자료, id) = 그 갈피.
# 사건 데이터에서 읽는 것(모두 있으면 쓰고 없으면 건너뛴다 — 어느 사건이나 같은 틀):
#   clues.<id>  { title, text, kind: fact|heard|guess(기본 fact), by: "주모"(heard면 발언자 — 반드시), by_if: [[조건식, 발언자], …],
#                 text_if: [[조건식, 글], …](맞는 마지막 글로 자란다) }
#   rules.<id>  { …같은 필드, kind 기본 guess }
#   journal     { unknowns: [{ text, until: 조건식(참이 되면 지운다), when }], places: [{ name, when }], items: [{ id, when }],
#                 solutions_when: 조건식(이게 참이 되기 전엔 '할 수 있을 것 같은 일'을 쓰지 않는다 — 무엇과 맞설지 미리 알려 주지 않게) }
#   case_fn     summary() → [문단], solutions() → [{title, available, text, hint}] ("???" 제목은 쓰지 않는다 — 해결법 수를 알려 주지 않는다)
#   S.flags._obs [{ about, text }] — 관찰(director.observe / 명령 { "observe": 글, "about": 대상 })
# 블록: title(sub) · head · para(soft, size, indent) · quote(scale, indent, seal) · entry(tag, by, title, text, strong, note) · case(title, status) · gap · page(쪽 바꿈)
extends RefCounted

const Progress := preload("res://scripts/region/progress.gd")
const GameSettings := preload("res://scripts/story/game_settings.gd")
const CaseRegistry := preload("res://scripts/story/case_registry.gd")

const PRINCIPLE := ["본 것은 본 대로.", "들은 것은 누가 말했는지.", "모르는 것은 모른다고."]
const CASE_TITLES := { namwon = "산길의 실종", hanyang = "비어 있는 책방", gangneung = "고개에 남은 종소리", hwangju = "빈 배의 값", pyongyang = "강을 판 사내", jeju = "굴에 남은 숨" }
const PLACE_KO := { HANYANG = "한양", GANGNEUNG = "강릉", GYEONGJU = "경주", HWANGJU = "황주", PYEONGYANG = "평양", PYONGYANG = "평양",
	HAMHUNG = "함흥", HAMHEUNG = "함흥", JEJU = "제주" }
const ORDER := ["travel", "case", "observe", "people", "items", "teach", "help", "master"]
const LEGACY := ["travel", "case", "help"]
# 흔적 한 줄(어디서 어떻게 알았나) — 없는 토큰은 이름만
const TRACE_LINE := {
	HANYANG = { tag = "heard", by = "남원 노인", text = "“전에도 그런 책 들고 다니던 양반이 있었소. 한양 간다고 했지.”" },
	GANGNEUNG = { tag = "fact", text = "국사성황사 옛 제의 기록 뒷장에 선생의 필체 — “사람이 훔친 것과 사람이 아닌 것이 남긴 흔적을 섞지 말 것.”" },
	PYONGYANG = { tag = "fact", text = "평양 감영 서리가 간직한 종이 한 장, 선생의 필체 — “글보다 고쳐 쓴 자리를 먼저 보라. 거짓말은 새 문장을 만들지만, 손은 옛 흔적을 다 지우지 못한다.”" },
	HAMHUNG = { tag = "fact", text = "북청길 함관령 옛 역참. 제 기록을 한 장씩 태워 언 역졸을 살리고 계셨다. “그 책 아직 갖고 있었구나.”" },
}
# 길에서 다시 만난 선생의 글(시나리오 v2.3.1) — 얻은 것만 '스승의 가르침'에 더한다. need: 흔적 토큰(MAIN_MASTER_TRACE) · var: 공통 변수
const LESSONS := [
	{ id = "S0010", place = "남원", need = "HANYANG", lines = ["발자국은 한 번 남지만, 사람 말은 걸을수록 달라진다."], how = "기록책 가장자리의 오래된 한 줄" },
	{ id = "S2008", place = "강릉", need = "GANGNEUNG", lines = ["사람이 훔친 것과 사람이 아닌 것이 남긴 흔적을 섞지 말 것.", "원인이 둘이면, 해결도 하나일 필요는 없다."], how = "옛 제의 기록 뒷장" },
	{ id = "S3007", place = "경주", need = "GYEONGJU", lines = ["남겨진 흔적과 방금 생긴 흔적을 한데 묶지 말 것.", "오래됐다는 이유로 진짜인 것도, 새것이라는 이유로 거짓인 것도 아니다."], how = "바위 밑 탁본 조각" },
	{ id = "S4008", place = "황주", vr = "MAIN_GWAK_NAME_KNOWN", lines = ["말이 바다를 설명하지 못하면, 물건이 돌아오는 방향부터 본다."], how = "중개인의 운송장 뒷면" },
	{ id = "S5006", place = "평양", need = "PYONGYANG", vr = "SKILL_DOCUMENT_CHECK", lines = ["글보다 고쳐 쓴 자리를 먼저 보라. 거짓말은 새 문장을 만들지만, 손은 옛 흔적을 다 지우지 못한다."], how = "감영 서리가 간직한 종이" },
	{ id = "S6008", place = "함흥", vr = "MAIN_MASTER_FOUND", lines = ["그때는 기록을 남기겠다고 산 사람을 너무 늦게 봤다."], how = "함관령 옛 역참, 선생의 입으로", heard = "이겸" },
]
static var last_page := 0

static func build(d, page = -1) -> Dictionary:
	var pages := [_travel(d), _cases(d), _observe(d), _people(d), _items(d), _teach(d), _help(d), _master()]
	var p := last_page
	if page is String: p = maxi(0, ORDER.find(page))
	elif int(page) >= 0: p = ORDER.find(LEGACY[clampi(int(page), 0, LEGACY.size() - 1)])
	return { pages = pages, page = clampi(p, 0, pages.size() - 1) }

# 갈피 하나(id) — 없으면 빈 갈피
static func section(jd: Dictionary, id: String) -> Dictionary:
	for pg in jd.get("pages", []):
		if String(pg.get("id", "")) == id: return pg
	return { id = id, tab = "", blocks = [] }

static func _gwak_met(d) -> bool:
	if d != null and d.S != null and String(d.case_id) == "jeju": return bool(d.S.flags.get("gwak_met", false))
	return bool(Progress.case_state("jeju").get("flags", {}).get("gwak_met", false))

static func _vars(d) -> Dictionary:
	var v: Dictionary = Progress.vars().duplicate()
	if d != null and d.S != null: v.merge(d.S.vars, true)
	return v

static func _trace(v: Dictionary) -> Array:
	return Array(String(v.get("MAIN_MASTER_TRACE", "")).split(",", false)).map(func(x): return String(x).strip_edges().to_upper())

static func _empty(b: Array, text: String) -> void:
	if b.size() <= 1: b.append({ t = "para", text = text, soft = true })

# ---- 0 여행 기록 ----
static func _travel(d) -> Dictionary:
	var v := _vars(d)
	var b := [{ t = "title", text = "여행 기록", sub = "이겸을 찾는 길" }]
	b.append({ t = "head", text = "찾는 사람 — 이겸" })
	var trace := _trace(v)
	var last := "남원"
	if not trace.is_empty(): last = String(PLACE_KO.get(trace[-1], trace[-1]))
	b.append({ t = "para", text = "마지막 확인 장소: " + last })
	b.append({ t = "para", text = "현재 행방: " + ("찾았다 — 함흥 북청길 함관령 옛 역참" if bool(v.get("MAIN_MASTER_FOUND", false)) else "모름") })
	# 함흥(S6010) 뒤: 다음에 찾을 사람 — 곽칠성(제주)
	if bool(v.get("MAIN_MASTER_FOUND", false)) and bool(v.get("MAIN_PAST_EVENT_KNOWN", false)) and not bool(v.get("MAIN_GWAK_FOUND", false)):
		b.append({ t = "head", text = "다음에 찾을 사람 — 곽칠성" })
		b.append({ t = "entry", tag = "heard", by = "이겸", title = "제주", text = "열두 해 전 서강 창고 사건의 증인. 죄를 쓰고 제주로 귀양 갔다. “내가 가야 했는데 못 갔다.”" })
		if bool(v.get("MAIN_GWAK_NAME_KNOWN", false)) and _gwak_met(d):
			b.append({ t = "entry", tag = "heard", by = "곽칠성", title = "제주 화북포", text = "포구에서 짐을 지는 늙은이. 서강 창고 일을 묻자 “그 일은 끝났소.”" })
		else:
			b.append({ t = "para", text = "제주 가는 배는 해남 관두포에서 뜬다. 남해 뱃길은 남원 남쪽 끝에서 시작한다." })
	# 제주(S7008) 뒤: 곽칠성을 찾음 — 강복의 곡물 수량패
	if bool(v.get("MAIN_GWAK_FOUND", false)):
		b.append({ t = "head", text = "찾은 사람 — 곽칠성" })
		b.append({ t = "entry", tag = "fact", title = "제주 김녕", text = "사건 뒤 그가 먼저 찾아와 강복의 곡물 수량패를 내놓았다. “저 숫자 때문에 사람이 죽었소.” 박규상의 이름에 — “아직 살아 있소?”" })
		if bool(v.get("ACT6_OPEN", false)):
			b.append({ t = "para", text = "다음 — 한양. 서강 옛 창고와 칠패." })
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

# ---- 1 사건 기록 ----
static func _cases(d) -> Dictionary:
	var b := [{ t = "title", text = "사건 기록" }]
	var cur := ""
	if d != null and d.S != null and d.case_fn != null and _started(d):
		cur = String(d.case_id)
		b.append_array(_case_detail(d))
	var others := []
	for id in Progress.data().cases:
		if String(id) == cur: continue
		var st: Dictionary = Progress.case_state(String(id))
		var fl: Dictionary = st.get("flags", {})
		if String(st.get("phase", "start")) == "start" and not bool(fl.get("case_started", false)): continue
		others.append({ t = "case", title = _case_title(String(id)), status = "해결" if String(st.get("phase", "")) == "done" else "진행 중" })
	if not others.is_empty():
		if cur != "": b.append({ t = "head", text = "다른 사건" })
		b.append_array(others)
	if b.size() == 1: b.append({ t = "para", text = "아직 기록된 사건 없음", soft = true })
	return { id = "case", tab = "사건 기록", blocks = b }

static func _started(d) -> bool:
	var S = d.S
	return bool(S.flags.get("case_started", false)) or S.phase in ["done", "morning", "night"] or (S.phase != "start" and not S.clues.is_empty())

static func _case_title(id: String) -> String:
	if CASE_TITLES.has(id): return CASE_TITLES[id]
	var dd = _case_data(id)
	if dd is Dictionary: return String(dd.get("case", {}).get("record_title", id))
	return id

static func _case_data(id: String):
	var dd := CaseRegistry.load_data(id)   # 파일이 없거나 못 읽으면 null(제목은 id 그대로)
	return dd if not dd.is_empty() else null

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

# ---- 2 관찰 ----
static func _observe(d) -> Dictionary:
	var b := [{ t = "title", text = "관찰", sub = "내 눈으로 본 것만" }]
	var cur := ""
	if d != null and d.S != null and String(d.case_id) != "":
		cur = String(d.case_id)
		var obs: Array = d.S.flags.get("_obs", [])
		if not obs.is_empty():
			b.append({ t = "case", title = _case_title(cur) })
			for o in obs: b.append({ t = "entry", tag = "fact", title = String(o.get("about", "")), text = String(o.get("text", "")) })
	for id in Progress.data().cases:
		if String(id) == cur: continue
		var obs: Array = Progress.case_state(String(id)).get("flags", {}).get("_obs", [])
		if obs.is_empty(): continue
		b.append({ t = "case", title = _case_title(String(id)) })
		for o in obs: b.append({ t = "entry", tag = "fact", title = String(o.get("about", "")), text = String(o.get("text", "")) })
	_empty(b, "아직 적은 관찰이 없다. 싸움이나 조사에서 직접 본 움직임이 여기 남는다.")
	return { id = "observe", tab = "관찰", blocks = b }

# ---- 3 사람의 말(보강서 §21-4 — 발언자와 함께, 사실로 올리지 않는다): 최근 것부터 ----
static func _people(d) -> Dictionary:
	var b := [{ t = "title", text = "사람의 말", sub = "들은 대로 — 누가 말했는지" }]
	var heard: Array = Progress.heard()
	for i in range(heard.size() - 1, -1, -1):
		var h: Dictionary = heard[i]
		b.append({ t = "entry", tag = "heard", by = String(h.get("by", "")), title = String(h.get("place", "")), text = "“%s”" % String(h.get("text", "")) })
	_empty(b, "아직 적은 말이 없다. 고을 사람에게 말을 걸거나 엿들은 말이 여기 남는다 — 사실이 아니라 들은 것으로.")
	return { id = "people", tab = "사람의 말", blocks = b }

# ---- 4 물건·문서 ----
static func _items(d) -> Dictionary:
	var b := [{ t = "title", text = "물건 · 문서" }]
	var cur := ""
	if d != null and d.S != null and String(d.case_id) != "":
		cur = String(d.case_id)
		_items_of(b, _case_title(cur), d.S.items, d.data, d.S.flags.get("_doc_found", {}))
	for id in Progress.data().cases:
		if String(id) == cur: continue
		var st: Dictionary = Progress.case_state(String(id))
		var its: Dictionary = st.get("items", {}) if st.get("items") is Dictionary else {}
		var df = st.get("flags", {}).get("_doc_found", {})
		if its.is_empty() and (not (df is Dictionary) or df.is_empty()): continue
		var dd = _case_data(String(id))
		_items_of(b, _case_title(String(id)), its, dd if dd is Dictionary else {}, df)
	_empty(b, "아직 지닌 물건이 없다.")
	return { id = "items", tab = "물건·문서", blocks = b }

static func _items_of(b: Array, title: String, items: Dictionary, data: Dictionary, docs) -> void:
	var hidden: Array = data.get("hidden_items", [])
	var names := []
	for id in items:
		if hidden.has(id) or int(items[id]) <= 0: continue
		var lb = data.get("items", {}).get(id, id)
		if lb is Dictionary: lb = lb.get("label", id)
		names.append(String(lb) + (" %d" % int(items[id]) if int(items[id]) > 1 else ""))
	var doc_lines := []
	if docs is Dictionary:
		var defs: Dictionary = data.get("documents", {})
		var seen := {}
		for key in docs:
			var doc := String(key).get_slice("/", 0)
			if seen.has(doc): continue
			seen[doc] = true
			doc_lines.append(String(defs.get(doc, {}).get("title", doc)))
	if names.is_empty() and doc_lines.is_empty(): return
	b.append({ t = "case", title = title })
	if not names.is_empty(): b.append({ t = "entry", tag = "fact", title = "지닌 것", text = " · ".join(names) })
	for dl in doc_lines: b.append({ t = "entry", tag = "fact", title = "살펴본 문서", text = dl })

# ---- 5 스승의 가르침 ----
static func _teach(d) -> Dictionary:
	var v := _vars(d)
	var trace := _trace(v)
	var b := [{ t = "title", text = "스승의 가르침", sub = "선생이 늘 하던 말" }]
	for i in PRINCIPLE.size():
		b.append({ t = "gap" })
		b.append({ t = "quote", text = PRINCIPLE[i], scale = 1.5, indent = 2.0 })
	b.append({ t = "gap" })
	b.append({ t = "para", text = "뜻은 길 위에서 알게 된다.", soft = true, indent = 6.0 })
	var got := []
	for l in LESSONS:
		var ok := false
		if l.has("need"): ok = trace.has(String(l.need))
		if l.has("vr"): ok = ok or bool(v.get(String(l.vr), false))
		if ok: got.append(l)
	if not got.is_empty():
		b.append({ t = "page" })
		b.append({ t = "head", text = "길에서 다시 만난 선생의 글" })
		for l in got:
			var tag := "heard" if l.has("heard") else "fact"
			for j in l.lines.size():
				# 두주: 첫 줄에 고을 이름(들은 말이면 + 말한 이)
				var note: String = (String(l.place) + (" · " + String(l.heard) if l.has("heard") else "")) if j == 0 else ""
				b.append({ t = "entry", tag = tag, note = note, title = "", text = "“%s”" % String(l.lines[j]) })
			b.append({ t = "para", text = "— " + String(l.how), soft = true, indent = 4.0, size = 18 })
	if String(v.get("PLAYER_FIRST_LINE", "")) != "":
		b.append({ t = "page" })
		b.append({ t = "head", text = "나의 기록" })
		b.append({ t = "gap" })
		b.append({ t = "quote", text = String(v.PLAYER_FIRST_LINE), scale = 1.4, indent = 2.0, seal = true })
		b.append({ t = "gap" })
		b.append({ t = "para", text = "선생의 글이 아니라 내 글씨로 적은 첫 문장 — 제주 김녕에서.", soft = true, indent = 4.0 })
	return { id = "teach", tab = "스승의 가르침", blocks = b }

# ---- 6 여행 방법(§24) ----
static func _help(d) -> Dictionary:
	var v := _vars(d)
	var b := [{ t = "title", text = "여행 방법" }]
	var rows := [
		["이동", "WASD 걷기 · Shift를 누르고 있으면 달린다."],
		["살펴보기", "조사할 수 있는 것 가까이 가면 작은 먹점이 보이고, 손 닿는 거리에서 ‘E 살펴보기’가 뜬다. 멀리 있는 것은 표시하지 않는다."],
		["대화", "사람에게 다가가 E. 고을 사람 누구에게나 말을 걸 수 있다. 머리 위 「…」는 새로 할 말이 있는 사람이다. 엿들리는 말은 그냥 지나가도 들린다. 사람마다 말이 다를 수 있다 — 들은 소문은 기록책에 '들음'으로 남는다."],
		["기록책", "R. 세로로 쓴 옛 책 — 오른쪽 줄부터 읽고, ← A로 다음 쪽, → D로 앞 쪽. 위의 갈피(숫자)로 바로 간다. 테 위 작은 글씨: ◆ 확인 — 직접 본 것 · ◇ 들음 — 누가 말했는지 · △ 추정 — 짐작."],
		["지도", "M 고을 지도 · 지도 안에서 Tab으로 권역 · 전국 지도. 가 보았거나 정확히 들은 곳만 이름이 적힌다."],
		["말 · 배 · 역마", "주막 · 역 · 마을 어귀 · 큰길 갈림에서 E로 말에 오르면 큰길을 따라 저절로 간다(Space 멈춤 · E 내리기 · 갈림길 A/D). 나루 · 선창에서는 E로 배에 오른다. H 역마 — 가 본 거점으로 곧장 간다(처음 가는 길은 건너뛸 수 없다)."],
		["물건", "물건은 쓸 수 있는 자리에서만 ‘이곳에 사용할 수 있는 물건이 있다’가 뜬다. 무엇이 될지는 해 보아야 안다."],
		["싸움", "J 베기(길게: 모아 베기) · K 구르기(회피) · L 막기(누르고 있기) · I 활(누르고 있다 떼기) · U 떡 던지기. 상대가 몸을 낮추거나 멈추는 때를 본다."],
		["저장", "고을에 들어설 때 · 사건이 나아갈 때 · 길 떠나기 전에 저절로 적힌다(구석에 ‘기록을 남겼다’). Esc — 저장 · 불러오기에서 세 칸에 따로 남긴다. 주막 안팎에서 F — 쉬며 기록을 정리한다(저장하고 쉬어 간다)."],
	]
	if int(v.get("ITEM_TALISMAN_SLOT", 0)) > 0: rows.append(["호신물", "Q 지니기 · 풀기."])
	rows.append(["멈춤 · 설정", "Esc — 계속 · 저장 · 불러오기 · 설정(상호작용 안내 · 조사 도움) · 여행 방법."])
	for r in rows:
		b.append({ t = "head", text = String(r[0]) })
		b.append({ t = "para", text = String(r[1]) })
	return { id = "help", tab = "여행 방법", blocks = b }

# ---- 7 옛 기록(이겸이 앞서 적은 본보기 — 원작 제목 없이 본 대로 · 들은 대로 · 짐작) ----
#   바닷목의 시월 바람(강화·김포 사이 물목 전승) · 고원의 못과 바위(태백 못 전승) — 게임 사건에 쓰지 않은 것
static func _master() -> Dictionary:
	var b := [{ t = "title", text = "옛 기록", sub = "선생 이겸이 앞서 적은 장" }]
	b.append({ t = "head", text = "일러두기" })
	b.append({ t = "para", text = "이 책은 선생이 들고 다니던 것이다. 앞의 몇 장은 선생의 글씨, 그 뒤로는 내가 이어 적는다." })
	b.append({ t = "entry", tag = "fact", title = "확인", text = "내 눈으로 본 것. 본 대로만 적는다." })
	b.append({ t = "entry", tag = "heard", by = "말한 이", title = "들음", text = "남에게 들은 것. 누가 말했는지 함께 적고, 사실로 올리지 않는다." })
	b.append({ t = "entry", tag = "guess", title = "추정", text = "내 짐작. 틀릴 수 있음을 잊지 않으려 따로 적는다." })
	b.append({ t = "para", text = "끝에는 모르는 것을 모른다고 적는다.", soft = true })
	# 본보기 하나 — 바닷목의 시월 바람
	b.append({ t = "page" })
	b.append({ t = "case", title = "시월 스무날의 바람", status = "기사년 시월" })
	b.append({ t = "para", text = "강화와 김포 사이 좁은 바닷목. 나루에서 사흘 묵었다.", soft = true })
	b.append({ t = "entry", tag = "fact", title = "나루", text = "스무날 아침부터 찬바람이 거셌다. 나루의 배가 한 척도 뜨지 않았다. 다른 날엔 바람이 더 세어도 떴다." })
	b.append({ t = "entry", tag = "heard", by = "늙은 사공", title = "", text = "“이날은 억울하게 죽은 뱃사공의 날이라 바람이 운다. 배를 띄우면 안 된다.”" })
	b.append({ t = "entry", tag = "heard", by = "주막 주인", title = "", text = "“옛적 피난 가던 임금이 물목이 막힌 줄 알고 사공을 베었다지. 사공이 띄운 바가지를 따라가니 길이 열렸다 하오.”" })
	b.append({ t = "entry", tag = "fact", title = "건너편 언덕", text = "작은 무덤 하나. 새 짚과 식은 재 — 그날 아침 누가 제를 지냈다." })
	b.append({ t = "entry", tag = "guess", title = "물목", text = "물길이 좁고 굽어 처음 오는 사람 눈에는 막다른 곳으로 보인다. 사공을 의심한 까닭이 거기 있었을지 모른다." })
	b.append({ t = "para", text = "끝에 적음 — 바람이 왜 그날 부는지는 모른다. 그날 사람들이 배를 띄우지 않는 것만은 본 대로 적는다.", soft = true })
	# 본보기 둘 — 고원의 못과 바위
	b.append({ t = "page" })
	b.append({ t = "case", title = "못가의 바위", status = "무진년 칠월" })
	b.append({ t = "para", text = "태백 고원의 마을. 큰 강이 처음 솟는 못이 있다.", soft = true })
	b.append({ t = "entry", tag = "fact", title = "못", text = "땅에서 물이 솟아 셋으로 넘친다. 한여름인데 물이 차다. 사흘 내내 물이 줄지 않았다." })
	b.append({ t = "entry", tag = "heard", by = "마을 노파", title = "", text = "“옛날 여기 인색한 부잣집이 있었소. 시주 온 스님에게 쌀 대신 쇠똥을 퍼 주었지.”" })
	b.append({ t = "entry", tag = "heard", by = "마을 노파", title = "", text = "“며느리가 몰래 쌀을 드렸는데, 스님이 따라오되 뒤를 돌아보지 말라 했소. 벼락 치는 소리에 돌아보았고.”" })
	b.append({ t = "entry", tag = "fact", title = "고갯길 옆", text = "아이를 업은 여인처럼 보이는 바위. 앞에 누가 놓은 쌀 한 줌." })
	b.append({ t = "entry", tag = "guess", title = "", text = "바위 모양을 보고 이야기가 붙었는지, 이야기가 먼저였는지는 가릴 수 없다." })
	b.append({ t = "para", text = "끝에 적음 — 못 밑에 집이 잠겼다는 말은 확인하지 못했다. 물이 깊고 차서 들어가지 않았다. 모르는 것은 모른다고 둔다.", soft = true })
	return { id = "master", tab = "옛 기록", blocks = b, front = true }
