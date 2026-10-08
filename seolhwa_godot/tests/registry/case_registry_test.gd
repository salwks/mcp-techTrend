# 사건 등록부(scripts/story/case_registry.gd) 구조 시험 — 헤드리스, 저장은 따로(user://st_registry.json, 끝나면 지운다).
#   godot --headless --path . -s res://tests/registry/case_registry_test.gd
#   A 한 공간(JL_NAMWON_UNBONG)에 사건 여러 개를 올릴 수 있다(가짜 사건 reg_dummy — 이 폴더에만, 놀이 콘텐츠에는 없다)
#   B 사건마다 따로 저장 키(cases.<id>), 저장 version 2 그대로
#   C 한 사건의 완료·깃발·지우기가 다른 사건 상태를 덮지 않는다(완료 변수 CASE_<ID>_COMPLETE, 지도 표지·기록책도 사건별)
#   D 없는 사건 id는 건너뛰고 멈추지 않는다
#   E 기존 단일 사건은 예전 CASES와 같고, 남원은 새로 시작·이른 저장 이어 하기가 그대로
#   끝 줄: REGTEST PASS n / REGTEST FAIL n
extends SceneTree

const CaseRegistry := preload("res://scripts/story/case_registry.gd")
const Progress := preload("res://scripts/region/progress.gd")
const StoryState := preload("res://scripts/story/story_state.gd")
const Skills := preload("res://scripts/story/skills.gd")
const MapLeads := preload("res://scripts/region/map_leads.gd")
const JournalBook := preload("res://scripts/story/journal_book.gd")

const SAVE := "user://st_registry.json"
const NW := "JL_NAMWON_UNBONG"
const DUMMY := "reg_dummy"
const DUMMY_DIR := "res://tests/registry/reg_dummy/"
# 리팩터링 전 story_director.gd의 CASES(공간 → 사건 하나) — 등록부가 이것과 같아야 한다
const OLD_CASES := { "JL_NAMWON_UNBONG": "namwon", "GG_HANYANG": "hanyang", "GW_GANGNEUNG": "gangneung",
	"HH_HWANGJU": "hwangju", "HH_HWANGJU-JANGSANGOT": "hwangju", "GS_GYEONGJU": "gyeongju", "PA_PYEONGYANG": "pyongyang",
	"PA_PYEONGYANG-HG_HAMHEUNG": "hamhung", "HG_HAMHEUNG": "hamhung", "HG_HAMHEUNG-BUKCHEONG": "hamhung",
	"SEA_NAMHAE_JEJU": "jeju", "JJ_JEJU": "jeju" }
const OLD_MAP_IDS := ["namwon", "hanyang", "gangneung", "gyeongju", "hwangju", "pyongyang", "hamhung", "jeju"]

var n := 0
var fails := 0

func ok(c: bool, what: String) -> void:
	n += 1
	if c: print("  ok  ", what)
	else:
		fails += 1
		print("  FAIL ", what)

func _fresh() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	Progress.use_path(SAVE)
	Progress.reset_all()

func _reread() -> Dictionary:
	Progress.use_path(SAVE)   # 읽어 둔 것을 버리고 파일에서 다시
	return Progress.data()

func _init() -> void:
	CaseRegistry.clear_extra()
	_fresh()
	_test_e_registry()
	_test_a()
	_test_b_c()
	_test_d()
	_test_e_namwon()
	CaseRegistry.clear_extra()
	MapLeads._cases = null
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	Progress.use_path("")
	print("REGTEST %s %d" % ["PASS" if fails == 0 else "FAIL", n if fails == 0 else fails])
	quit(0 if fails == 0 else 1)

# E(앞): 등록부만으로 예전 공간 → 사건과 같다
func _test_e_registry() -> void:
	print("E 기존 공간 → 사건(등록부 = 예전 CASES)")
	var same := true
	for sp in OLD_CASES:
		if CaseRegistry.cases_for(sp) != [OLD_CASES[sp]]: same = false; print("    다름 ", sp, " ", CaseRegistry.cases_for(sp))
	ok(same, "공간마다 기존 사건 하나(%d 공간)" % OLD_CASES.size())
	ok(CaseRegistry.SPACE_CASES.size() == OLD_CASES.size(), "등록부에 다른 공간이 더 없다")
	ok(CaseRegistry.all_ids() == OLD_MAP_IDS, "사건 목록·차례가 예전 지도 표지 목록과 같다 %s" % [CaseRegistry.all_ids()])
	ok(CaseRegistry.cases_for("GG_HANYANG-JL_NAMWON_UNBONG").is_empty(), "사건 없는 공간(노정)은 빈 목록")

# A: 남원 공간에 두 번째 사건
func _test_a() -> void:
	print("A 한 공간에 사건 여러 개")
	CaseRegistry.register(NW, DUMMY, DUMMY_DIR)
	ok(CaseRegistry.ids_for(NW) == ["namwon", DUMMY], "JL_NAMWON_UNBONG 등록 = [namwon, reg_dummy]")
	ok(CaseRegistry.cases_for(NW) == ["namwon", DUMMY], "둘 다 파일이 있어 돌릴 수 있다")
	CaseRegistry.register(NW, DUMMY, DUMMY_DIR)
	ok(CaseRegistry.ids_for(NW).size() == 2, "같은 id를 두 번 올려도 하나")
	ok(CaseRegistry.SPACE_CASES[NW] == ["namwon"], "놀이 등록(SPACE_CASES)에는 가짜 사건이 없다")
	ok(CaseRegistry.load_data(DUMMY).get("case", {}).get("id", "") == DUMMY, "시험 폴더의 사건 데이터를 읽는다")
	ok(CaseRegistry.all_ids().has(DUMMY) and CaseRegistry.all_ids()[0] == "namwon", "전체 목록에 더해지고 남원이 먼저")

# B·C: 사건마다 따로 저장, 서로 덮지 않음
func _test_b_c() -> void:
	print("B 사건마다 따로 저장 키 / C 서로 덮지 않음")
	_fresh()
	# 고르기: 남원이 안 끝났으면 남원(가짜 사건은 CASE_NAMWON_COMPLETE를 요구)
	ok(String(CaseRegistry.choose(CaseRegistry.cases_for(NW)).id) == "namwon", "새 저장 → 남원이 선다")
	# 남원 진행 → 저장
	var s1 = StoryState.new("namwon")
	s1.phase = "explore"; s1.flags["case_started"] = true; s1.flags["nw_only"] = true; s1.clues.append("CLUE_NW")
	s1.save()
	# 남원 끝 → 완료 변수
	s1.phase = "done"
	s1.vars[Skills.complete_var({}, "namwon")] = true
	s1.vars["CASE_NAMWON_OUTCOME"] = "A"
	s1.save()
	var nw_saved: Dictionary = _reread().cases.namwon.duplicate(true)   # 파일에서 읽은 꼴(숫자는 JSON 실수)로 견준다
	# 한 번에 도는 사건은 하나 — 남원이 끝나고 요구가 맞으면 둘째 사건이 선다
	ok(String(CaseRegistry.choose(CaseRegistry.cases_for(NW)).id) == DUMMY, "남원 완료 뒤 → reg_dummy가 선다")
	var dd := CaseRegistry.load_data(DUMMY)
	var s2 = StoryState.new(DUMMY)   # 새로 읽음(남원 변수가 이미 들어 있다)
	ok(bool(s2.vars.get("CASE_NAMWON_COMPLETE", false)), "둘째 사건 상태가 남원 완료를 본다")
	s2.phase = "explore"; s2.flags["case_started"] = true; s2.flags["nw_only"] = false; s2.flags["dummy_only"] = true
	s2.save()
	var cv := Skills.complete_var(dd.get("case", {}), DUMMY)
	ok(cv == "CASE_REG_DUMMY_COMPLETE", "둘째 사건 완료 변수 이름 %s" % cv)
	ok(Skills.complete_var({}, "namwon_chunhyang") == "CASE_NAMWON_CHUNHYANG_COMPLETE", "namwon_chunhyang → CASE_NAMWON_CHUNHYANG_COMPLETE")
	ok(Skills.complete_var({}, "namwon") == "CASE_NAMWON_COMPLETE", "기존 완료 변수 이름 그대로 CASE_NAMWON_COMPLETE")
	s2.phase = "done"; s2.vars[cv] = true; s2.vars[String(dd.case.outcome_var)] = "B"
	s2.save()
	var p := _reread()
	ok(int(p.get("version", 0)) == 2, "저장 version 2")
	ok(p.cases.has("namwon") and p.cases.has(DUMMY), "cases.namwon · cases.reg_dummy 따로")
	ok(p.cases.namwon == nw_saved, "둘째 사건 저장 뒤에도 cases.namwon 그대로")
	ok(bool(p.cases.namwon.flags.get("nw_only", false)) and not p.cases.namwon.flags.has("dummy_only"), "깃발이 섞이지 않는다(남원)")
	ok(not bool(p.cases[DUMMY].flags.get("nw_only", true)) and bool(p.cases[DUMMY].flags.get("dummy_only", false)), "깃발이 섞이지 않는다(둘째)")
	ok(bool(p.vars.get("CASE_NAMWON_COMPLETE", false)) and bool(p.vars.get(cv, false)), "두 완료 변수가 같이 남는다")
	ok(String(p.vars.get("CASE_NAMWON_OUTCOME", "")) == "A" and String(p.vars.get("CASE_REG_DUMMY_OUTCOME", "")) == "B", "결말 변수도 사건마다")
	# 둘 다 끝났으면 첫 사건(남원)을 연다 — 예전처럼 끝난 남원에 들어선다
	ok(String(CaseRegistry.choose(CaseRegistry.cases_for(NW)).id) == "namwon", "둘 다 끝 → 남원(첫 사건)")
	# 지도 표지: 사건마다 따로 — 남원 표지가 줄거나 덮이지 않는다
	MapLeads._cases = null
	var by_case := {}
	for c in MapLeads.cases(): by_case[String(c.id)] = c
	ok(by_case.has("namwon") and by_case.has(DUMMY), "지도 표지 목록에 두 사건")
	ok((by_case.namwon.leads as Array).size() == (CaseRegistry.load_data("namwon").get("map_leads", []) as Array).size(), "남원 표지 수 그대로")
	var vis := MapLeads.visible(null, { DUMMY: p.cases[DUMMY] }, p.vars)
	var dummy_vis := vis.filter(func(e): return e.case == DUMMY)
	ok(dummy_vis.size() == 1 and dummy_vis[0].id == "reg_dummy_lead", "둘째 사건 표지는 그 사건 이름으로")
	# 기록책: 다른 사건을 지우거나 덮지 않는다(읽기만)
	var before: Dictionary = Progress.data().cases.duplicate(true)
	var jc: Dictionary = JournalBook._cases(null)
	var titles := []
	for b in jc.blocks:
		if String(b.get("t", "")) == "case": titles.append(String(b.title))
	ok(titles.has("산길의 실종") and titles.has("시험용 둘째 사건"), "기록책 사건 기록에 두 사건 %s" % [titles])
	JournalBook._observe(null); JournalBook._items(null)
	ok(Progress.data().cases == before, "기록책을 만들어도 저장된 사건 상태 그대로")
	# 둘째 사건 새로 시작(reset_vars 없음) — 남원 변수·상태를 지우지 않는다
	s2.clear_saved(dd.get("case", {}).get("reset_vars", null))
	p = _reread()
	ok(not p.cases.has(DUMMY) and p.cases.has("namwon"), "둘째 사건만 지워짐")
	ok(bool(p.vars.get("CASE_NAMWON_COMPLETE", false)) and String(p.vars.get("CASE_NAMWON_OUTCOME", "")) == "A", "남원 완료·결말 변수는 남는다")
	# 남원 새로 시작은 예전처럼 남원 변수만 되돌린다
	var s3 = StoryState.new("namwon")
	s3.clear_saved(CaseRegistry.load_data("namwon").get("case", {}).get("reset_vars", null))
	p = _reread()
	ok(not p.cases.has("namwon") and not bool(p.vars.get("CASE_NAMWON_COMPLETE", true)), "남원 새로 시작 → 남원 상태·완료 되돌림")
	ok(bool(p.vars.get(cv, false)), "남원 새로 시작이 둘째 사건 완료 변수를 지우지 않는다")

# D: 없는 사건 id
func _test_d() -> void:
	print("D 없는 사건 id")
	CaseRegistry.register(NW, "namwon_chunhyang")
	CaseRegistry.register("NO_SUCH_SPACE", "no_such_case")
	ok(CaseRegistry.ids_for(NW).has("namwon_chunhyang"), "등록은 된다(아직 파일 없음)")
	ok(not CaseRegistry.cases_for(NW).has("namwon_chunhyang"), "파일이 없으면 돌릴 목록에서 빠진다")
	ok(CaseRegistry.cases_for("NO_SUCH_SPACE").is_empty(), "없는 공간·없는 사건 → 빈 목록")
	ok(CaseRegistry.load_data("no_such_case").is_empty(), "없는 사건 데이터 → {}")
	ok(not CaseRegistry.all_ids().has("no_such_case") and not CaseRegistry.all_ids().has("namwon_chunhyang"), "전체 목록에도 없다")
	var r := CaseRegistry.choose(["no_such_case"])
	ok(String(r.id) == "", "없는 사건만 후보 → 고르지 않음(소문만)")
	ok(JournalBook._case_title("no_such_case") == "no_such_case", "기록책 제목은 id 그대로")
	var st = StoryState.new("no_such_case")
	ok(not st.load_saved(), "없는 사건 상태 읽기 → 빈 상태")
	MapLeads._cases = null
	ok(MapLeads.cases().size() == CaseRegistry.all_ids().size(), "지도 표지가 없는 사건을 건너뛴다")

# E(뒤): 남원 단일 사건 — 새로 시작 · 이른 저장 이어 하기
func _test_e_namwon() -> void:
	print("E 남원 새로 시작 · 이어 하기")
	CaseRegistry.clear_extra()
	MapLeads._cases = null
	_fresh()
	var r := CaseRegistry.choose(CaseRegistry.cases_for(NW))
	ok(String(r.id) == "namwon" and String(r.data.get("case", {}).get("id", "")) == "namwon", "새 게임 → 남원, 남원 데이터")
	var s = StoryState.new("namwon")
	ok(not s.load_saved() and s.phase == "start", "새 게임 남원 상태 start")
	# 이른 옛 저장(continue:namwon-early와 같은 것)
	var j = JSON.parse_string(FileAccess.get_file_as_string("res://story/namwon/test_early_save.json"))
	var f := FileAccess.open(SAVE, FileAccess.WRITE)
	f.store_string(JSON.stringify(j, " ")); f.close()
	var p := _reread()
	ok(p.cases.has("namwon") and int(p.version) == 2, "옛 저장 cases.namwon 그대로 읽힘(version 2)")
	r = CaseRegistry.choose(CaseRegistry.cases_for(NW))
	ok(String(r.id) == "namwon", "옛 저장 → 남원")
	var s2 = StoryState.new("namwon")
	ok(s2.load_saved() and s2.phase == String(j.cases.namwon.phase) and s2.is_flag("INTRO_NAMWON_TITLE_DONE"), "옛 저장 남원 상태 이어짐(phase %s)" % s2.phase)
