# 조사 대상 데이터 도우미(보강서 §18·§29) — 사건 데이터(story/<사건>/<사건>_data.gd)가 objects()를 넘기기 전에 부른다.
#   "use": [{ "item": 물건 id, "when": 조건식(그 물건이 여기서 뜻을 가질 때), "line": "나무껍질에 기름을 바를 수 있다.", "do": [단계…] }]
#     → 그 물건을 가졌고 조건이 맞을 때만 단계 끝에 "이곳에 사용할 수 있는 물건이 있다." + 물건 고르기를 붙인다.
#       효과 설명은 하지 않는다("참기름은 …에 강력한 …" 금지) — line은 할 수 있는 동작만 한 줄로.
#   §29 필드(있으면 쓰고, 없으면 기본값): interact_id(= id) · event_id · when(VISIBLE_CONDITION) · radius(INTERACT_RANGE) ·
#     prompt_type(INSPECT | TALK | USE) · highlight(tutorial_high | normal | low | none — scripts/story/onboarding.gd 먹점) ·
#     first_hint(bool) · journal_entry(단서 id) · map_discovery(map_places id — 조사하면 지도에 적힌다) · state_change(설명 문자열)
extends RefCounted

const USE_PROMPT := "이곳에 사용할 수 있는 물건이 있다."

static func expand(objects: Array, items: Dictionary) -> Array:
	for o in objects:
		if not (o is Dictionary): continue
		if o.has("map_discovery") and String(o.map_discovery) != "":
			o["steps"] = o.get("steps", []) + [{ "discover": String(o.map_discovery) }]
		if not o.has("use"): continue
		var opts := []
		var any := []
		for u in o.use:
			var c := "has('%s')" % String(u.item)
			if u.has("when"): c += " and (%s)" % String(u.when)
			any.append("(%s)" % c)
			var dd: Array = []
			if String(u.get("line", "")) != "": dd.append({ "caption": String(u.line), "sec": 2.0 })
			dd.append_array(u.get("do", []))
			opts.append({ "label": String(items.get(String(u.item), u.item)), "when": c, "do": dd, "end": true })
		opts.append({ "label": "그만둔다", "end": true })
		o["steps"] = o.get("steps", []) + [{ "if": " or ".join(any), "then": [
			{ "onboard": "ITEM_USE" }, { "choice": USE_PROMPT, "options": opts }] }]
	return objects
