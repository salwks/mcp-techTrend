# 사건 분류(EVENT_CLASS) 검사 — 시나리오 v2.4.1 §1.11·§44(헤드리스).
#   godot --headless --path . -s res://tools/story/validate_event_class.gd
#   story/<사건>/<사건>_data.gd의 사건 머리(case)와 모든 사건 장면(events), 생활·소문·길가 장면 데이터(AMBIENT)를 본다.
#   v3 §3.2: 사건 머리에 FIXED_BEATS가 있으면 { id, text } 목록인지, id가 겹치지 않는지도 본다.
#   실패: 분류가 없거나 세 값(MAIN_FRAME/FOLKLORE_EVENT/AMBIENT) 밖 · MAIN_FRAME이 Fxx/Axx를 SOURCE_ID로 · MAIN_FRAME_ORIGIN_NOTE 없음 ·
#         FOLKLORE_EVENT의 SOURCE_ID/SOURCE_VERIFIED 없음 · AMBIENT에 출처 · 앵커 id/모드가 틀림 · 사건 장면 분류가 사건 머리와 다름.
#   끝 줄: EVENTCLASS PASS n / EVENTCLASS FAIL n
extends SceneTree

const EventClass := preload("res://scripts/story/event_class.gd")
const CaseRegistry := preload("res://scripts/story/case_registry.gd")
var CASES: Array = CaseRegistry.all_ids()   # 등록부(scripts/story/case_registry.gd)에 오른 사건 — 예전 고정 목록과 같은 여덟
const AMBIENT_FILES := {
	"res://story/ambient_talk_data.gd": "",
	"res://story/rumors_data.gd": "RUMORS",
	"res://story/vignettes_data.gd": "VIGNETTES",
}

var fails := 0
var n := 0

func _fail(where: String, msg: String) -> void:
	fails += 1
	print("FAIL %s: %s" % [where, msg])

func _init() -> void:
	# 검사기 자체가 막아야 할 것을 막는지
	if EventClass.check({ "EVENT_CLASS": "MAIN_FRAME", "SOURCE_ID": "A09", "MAIN_FRAME_ORIGIN_NOTE": "x" }).is_empty(): _fail("self", "MAIN_FRAME+A09가 통과함")
	if EventClass.check({ "EVENT_CLASS": "LOCAL" }).is_empty(): _fail("self", "제4의 분류가 통과함")
	if EventClass.in_build({ "EVENT_CLASS": "FOLKLORE_EVENT", "SOURCE_ID": "F24", "SOURCE_VERIFIED": false }): _fail("self", "SOURCE_VERIFIED=false가 빌드에 듦")
	for c in CASES:
		var path := CaseRegistry.data_path(c)
		var scr = load(path)
		if scr == null: _fail(c, "데이터 못 읽음 " + path); continue
		var data: Dictionary = scr.data()
		var head: Dictionary = data.get("case", {})
		var cls := String(head.get("EVENT_CLASS", ""))
		var sid := String(head.get("SOURCE_ID", ""))
		n += 1
		if not EventClass.CLASSES.has(cls): _fail(c + " case", "EVENT_CLASS '%s'" % cls)
		elif cls == "AMBIENT": _fail(c + " case", "주 사건이 AMBIENT")
		if cls == "MAIN_FRAME" and (EventClass.is_folk_id(sid) or not sid.begins_with("MAIN_FRAME_")): _fail(c + " case", "MAIN_FRAME SOURCE_ID '%s'" % sid)
		if cls == "FOLKLORE_EVENT" and sid == "": _fail(c + " case", "FOLKLORE_EVENT SOURCE_ID 없음")
		# v3 §3.2 판본 기준(있으면): FIXED_BEATS는 { id, text } 목록, id는 겹치지 않는다
		if head.has("FIXED_BEATS"):
			var fb = head.FIXED_BEATS
			var ids := {}
			if not (fb is Array) or fb.is_empty(): _fail(c + " case", "FIXED_BEATS가 비었거나 목록이 아님")
			else:
				for b in fb:
					if not (b is Dictionary) or String(b.get("id", "")) == "" or String(b.get("text", "")) == "": _fail(c + " case", "FIXED_BEATS 항목 %s" % str(b)); continue
					if ids.has(b.id): _fail(c + " case", "FIXED_BEATS id 겹침 " + String(b.id))
					ids[b.id] = true
				print("CASE %s FIXED_BEATS %d" % [c, fb.size()])
		var evs: Dictionary = data.get("events", {})
		var warned := {}
		if evs.is_empty(): _fail(c, "사건 장면 없음")
		for id in evs:
			n += 1
			var ev: Dictionary = evs[id]
			var warn := []
			for e in EventClass.check(ev, warn): _fail("%s %s" % [c, id], e)
			for w in warn:
				if not warned.has(w): warned[w] = true; print("WARN %s %s…: %s" % [c, id, w])
			if String(ev.get("EVENT_CLASS", "")) != cls: _fail("%s %s" % [c, id], "분류 '%s' ≠ 사건 머리 '%s'" % [ev.get("EVENT_CLASS", ""), cls])
			if String(ev.get("SOURCE_ID", "")) != sid: _fail("%s %s" % [c, id], "SOURCE_ID '%s' ≠ 사건 머리 '%s'" % [ev.get("SOURCE_ID", ""), sid])
		print("CASE %s %s %s 장면 %d" % [c, cls, sid, evs.size()])
	for path in AMBIENT_FILES:
		var scr = load(path)
		n += 1
		if scr == null: _fail(path, "못 읽음"); continue
		var consts: Dictionary = scr.get_script_constant_map()
		if String(consts.get("EVENT_CLASS", "")) != "AMBIENT": _fail(path, "const EVENT_CLASS := \"AMBIENT\" 없음")
		var list_name: String = AMBIENT_FILES[path]
		if list_name == "": continue
		for e in consts.get(list_name, []):
			n += 1
			var where := "%s %s" % [path.get_file(), e.get("id", "?")]
			if e.has("EVENT_CLASS") and String(e.EVENT_CLASS) != "AMBIENT": _fail(where, "EVENT_CLASS '%s'" % e.EVENT_CLASS)
			if e.has("SOURCE_ID"): _fail(where, "AMBIENT에 SOURCE_ID")
	print("EVENTCLASS %s checked=%d fails=%d" % ["PASS" if fails == 0 else "FAIL", n, fails])
	quit(0 if fails == 0 else 1)
