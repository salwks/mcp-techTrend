# 공통 승격 1차 시험(제작 규칙 v1.0 결정 4·5·6, F-1) — 헤드리스, 저장은 따로(user://st_commonize.json, 끝나면 지운다).
#   godot --headless --path . -s res://tests/commonize/commonize_test.gd
#   A 대화 카메라 우선순위: 공통 TALK → case.talk_camera → actor.talk_camera, false면 평소 카메라(CameraRig.talk_spec)
#   B 고을 막음: 남원 첫 사건 막음이 사건 선언(namwon_data case.travel_gate)으로 그대로 · 가짜 사건(선언 있음)은 막고 · 선언 없는 사건은 안 막음
#   C 길목 깃발: land 노정·권역만 깃발, river·sea 노정은 없음(물 노정 깃발 6개 빠짐) · 그 거점의 fast는 그대로 · 깃발 충돌체 없음
#   끝 줄: COMMONTEST PASS n / COMMONTEST FAIL n
extends SceneTree

const CaseRegistry := preload("res://scripts/story/case_registry.gd")
const Progress := preload("res://scripts/region/progress.gd")
const FT := preload("res://scripts/region/fast_travel.gd")
const Waymarks := preload("res://scripts/region/waymarks.gd")
const Waymark := preload("res://kit/station/waymark.gd")
const RideNet := preload("res://scripts/region/ride_net.gd")

const SAVE := "user://st_commonize.json"
const NW := "JL_NAMWON_UNBONG"
const NOTICE := "남원 일이 아직 끝나지 않았다 — 고을을 떠날 수 없다"
const WATER_FLAGS := { "RIVER_HANGANG": ["rt_mapo", "rt_mokgye", "rt_chungju"], "RIVER_DAEDONGGANG": ["rt_daedongmun", "rt_gyeomipo"], "SEA_NAMHAE_JEJU": ["rt_deokjin"] }

var n := 0
var fails := 0

func ok(c: bool, what: String) -> void:
	n += 1
	if c: print("  ok  ", what)
	else:
		fails += 1
		print("  FAIL ", what)

func _init() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	Progress.use_path(SAVE)
	Progress.reset_all()
	_talk_camera()
	_gate()
	_waymarks()
	CaseRegistry.clear_extra()
	FT.clear_gate_cache()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	Progress.use_path("")
	print("COMMONTEST %s %d" % ["PASS" if fails == 0 else "FAIL", n if fails == 0 else fails])
	quit(0 if fails == 0 else 1)

func _same(a, b: Dictionary) -> bool:
	if not (a is Dictionary): return false
	for k in ["pitch", "distance", "fov"]:
		if absf(float(a.get(k, -1.0)) - float(b[k])) > 0.001: return false
	return true

# ---- A ----
func _talk_camera() -> void:
	print("A 대화 카메라")
	var T: Dictionary = CameraRig.TALK
	ok(_same(T, { pitch = 38.0, distance = 13.5, fov = 38.0 }), "공통 TALK = 38/13.5/38")
	ok(_same(CameraRig.talk_spec({}, {}), T), "기본: 사건·인물 값이 없으면 공통 TALK")
	ok(_same(CameraRig.talk_spec({ "talk_camera": { "distance": 17.0 } }, {}), { pitch = 38.0, distance = 17.0, fov = 38.0 }), "사건 덮어쓰기(거리만)")
	ok(_same(CameraRig.talk_spec({ "talk_camera": { "distance": 17.0 } }, { "talk_camera": { "pitch": 30.0, "fov": 34.0 } }), { pitch = 30.0, distance = 17.0, fov = 34.0 }),
		"인물 덮어쓰기가 사건 위에")
	ok(CameraRig.talk_spec({ "talk_camera": false }, {}) == null, "사건 false → 평소 카메라")
	ok(CameraRig.talk_spec({}, { "talk_camera": false }) == null, "인물 false → 평소 카메라")
	ok(CameraRig.talk_spec({ "talk_camera": { "distance": 17.0 } }, { "talk_camera": false }) == null, "사건 값이 있어도 인물 false면 끔")
	ok(_same(CameraRig.talk_spec({ "talk_camera": false }, { "talk_camera": { "fov": 40.0 } }), { pitch = 38.0, distance = 13.5, fov = 40.0 }), "사건 false여도 인물 값이 있으면 켬(공통 위에)")
	ok(_same(CameraRig.talk_spec({ "talk_camera": false }, { "talk_camera": true }), T), "인물 true → 공통 TALK")
	# 남원: 사건 머리 값(38/13.5/38)이 그대로 — 이 사건 대화·연출 구도가 예전과 같다
	var nw := CaseRegistry.load_data("namwon")
	ok(_same(CameraRig.talk_spec(nw.case, {}), { pitch = 38.0, distance = 13.5, fov = 38.0 }), "남원 대화 카메라 그대로 38/13.5/38")
	var off := 0
	for a in nw.get("actors", []):
		if a is Dictionary and a.has("talk_camera"): off += 1
	ok(off == 0, "남원 인물별 덮어쓰기 없음(예전과 같은 값)")
	# 다른 일곱 사건: 이제 공통 TALK(사건 값이 없다)
	for id in ["hanyang", "gangneung", "gyeongju", "hwangju", "pyongyang", "hamhung", "jeju"]:
		var h: Dictionary = CaseRegistry.load_data(id).get("case", {})
		ok(_same(CameraRig.talk_spec(h, {}), T) or h.has("talk_camera"), "%s: 공통 TALK(또는 사건이 정한 값)" % id)

# ---- B ----
func _gate() -> void:
	print("B 고을 막음(사건 선언)")
	var nwd: Dictionary = CaseRegistry.load_data("namwon").case
	ok(nwd.get("travel_gate") is Dictionary and String(nwd.travel_gate.get("leave_space_until", "")) == "CASE_NAMWON_COMPLETE", "남원 사건 머리에 travel_gate 선언")
	ok(not (FT as Script).get_script_constant_map().has("FIRST_SPACE"), "fast_travel에 FIRST_SPACE 하드코딩 없음")
	FT.clear_gate_cache()
	Progress.reset_all()
	ok(FT.gate_for(NW) == NOTICE, "남원 첫 사건 전: 막힘 「%s」" % FT.gate_for(NW))
	ok(FT.gate_for(NW, "namwon", "explore") == NOTICE, "남원 사건이 도는 중(explore): 막힘")
	ok(FT.gate_for(NW, "namwon", "done") == "", "지금 도는 남원 사건 phase done: 풀림")
	Progress.data().cases["namwon"] = { "phase": "done" }
	ok(FT.gate_for(NW) == "", "저장된 남원 phase done: 풀림")
	Progress.data().cases.erase("namwon")
	Progress.set_var("CASE_NAMWON_COMPLETE", true)
	ok(FT.gate_for(NW) == "", "CASE_NAMWON_COMPLETE: 풀림")
	Progress.set_var("CASE_NAMWON_COMPLETE", false)
	for sp in ["GG_HANYANG", "JJ_JEJU", "SEA_NAMHAE_JEJU", "JL_NAMWON_UNBONG-GG_HANYANG"]:
		ok(FT.gate_for(sp) == "", "%s: 남원이 안 끝나도 이 공간은 막지 않는다(예전과 같음)" % sp)
	# 가짜 사건: 선언이 있으면 같은 장치로 막는다
	CaseRegistry.register("TEST_GATE_SPACE", "gate_dummy", "res://tests/commonize/gate_dummy/")
	CaseRegistry.register("TEST_FREE_SPACE", "reg_dummy", "res://tests/registry/reg_dummy/")
	FT.clear_gate_cache()
	ok(FT.gate_for("TEST_GATE_SPACE") == "시험 — 아직 떠날 수 없다", "가짜 사건(선언 있음): 막힘")
	ok(FT.gate_for("TEST_GATE_SPACE", "gate_dummy", "done") == "", "가짜 사건 phase done: 풀림")
	Progress.set_var("CASE_GATE_DUMMY_COMPLETE", true)
	ok(FT.gate_for("TEST_GATE_SPACE") == "", "가짜 사건 풀림 변수: 풀림")
	ok(FT.gate_for("TEST_FREE_SPACE") == "", "선언 없는 사건(reg_dummy): 막지 않는다")
	ok(FT.gate_for("TEST_GATE_SPACE_NONE") == "", "사건 없는 공간: 막지 않는다")
	CaseRegistry.clear_extra()
	FT.clear_gate_cache()

# ---- C ----
func _waymarks() -> void:
	print("C 길목 깃발")
	var total := 0
	for sp in RideNet.all_spaces():
		var k := Waymarks.route_kind(sp)
		var fl := Waymarks.flags_in(sp)
		total += fl.size()
		if k in ["river", "sea"]: ok(fl.is_empty(), "%s(%s): 깃발 없음" % [sp, k])
	ok(Waymarks.route_kind("RIVER_HANGANG") == "river" and Waymarks.route_kind("RIVER_DAEDONGGANG") == "river" and Waymarks.route_kind("SEA_NAMHAE_JEJU") == "sea",
		"노정 종류: 한강·대동강 river · 남해~제주 sea")
	ok(Waymarks.route_kind("JL_NAMWON_UNBONG-GG_HANYANG") == "land" and Waymarks.route_kind("HH_HWANGJU-PA_PYEONGYANG") == "land", "육로 노정 land")
	ok(Waymarks.route_kind(NW) == "" and Waymarks.space_has_flags(NW), "권역은 노정 아님 — 깃발 그대로")
	ok(Waymarks.flags_in("JL_NAMWON_UNBONG-GG_HANYANG").size() == 5 and Waymarks.flags_in(NW).size() == 13, "land 노정(남원–한양 5)·권역(남원 13) 깃발 그대로")
	ok(total == 96, "깃발 102 → 96(물 노정 6 빠짐) — 지금 %d" % total)
	for sp in WATER_FLAGS:
		var nodes := {}
		for nd in RideNet.read(sp).get("nodes", []): nodes[String(nd.id)] = nd
		for id in WATER_FLAGS[sp]:
			var nd: Dictionary = nodes.get(id, {})
			ok(bool(nd.get("fast", false)) and not Waymarks.is_flag(nd, sp) and Waymarks.is_flag(nd),
				"%s/%s: 깃발 아님 · fast 거점 그대로(역마 창·지도로 간다)" % [sp, id])
	# 결정 6: 깃발 충돌체 없음
	var w := Waymark.node({ seed = 1, known = true })
	ok(_colliders(w) == 0, "깃발 키트에 충돌체 없음")
	w.free()

func _colliders(nd: Node) -> int:
	var c := 1 if (nd is CollisionObject3D or nd is CollisionShape3D) else 0
	for ch in nd.get_children(): c += _colliders(ch)
	return c
