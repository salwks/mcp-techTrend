# Activity/Problem 최소 계약(게임플레이 구조 1차 — seolhwa/docs/production/SEOLHWAROK_GAMEPLAY_ARCHITECTURE_FINAL_v1.0.md §9).
#   사건 데이터의 "problems"를 이미 있는 이야기 명령(flag·clue·examine·choice·if)과 조사 대상(objects)·자리 트리거(triggers)로 바꿔 넣는다.
#   새 화면·새 모드·새 저장 칸이 없다. 상태는 그 사건 namespace(cases.<id>.flags)에만 남는다. 이 파일에는 사건 id가 없다.
#
# 데이터(사건 <id>_data.gd data()의 "problems": { 문제 id: 문제 }):
#   문제 { title, when?(조건식 — 모든 활동에 AND), activities: [활동…], fail_forward?: { ff id: 자리 }, result?: { flags: [..], do: [단계..] } }
#   활동 type 넷만:
#     inspect  직접 보거나(kind "seen" — at: 앵커, E 살펴보기 대상이 생긴다) 누구에게 듣는다(kind "heard" — actor: 인물 id, by: 말한 사람 —
#              그 인물 talk에 { "activity": "문제.활동" } 한 줄을 넣는다). text(카드 글, seen만) · record{title,text}(기록책) · required(기본 true) · do
#     compare / connect  needs: [활동 id…]가 다 끝나면 곧바로(같은 흐름 안에서) — text · record{title,text,kind guess(기본)|fact} · flags · do
#     decide   needs 또는 after(n — from 목록 중 n개, from 기본: 앞에 적힌 inspect) · prompt · options[{ id, label, when?, flags?, record?, do?, fail_forward? }]
#              · at?/radius?(저장했다 불러온 뒤 다시 묻는 자리 — 없으면 어디서나)
#   fail_forward 자리 { at, radius?, label, text(잘못 짚은 자리), extra{ text, record }(추가 흔적), do? } — 그 갈래를 고른 뒤에만 보인다.
#   result { flags, do } — 문제가 풀릴 때 한 번(결정이 났을 때 · fail_forward 자리를 보았을 때 · 결정이 없으면 required가 다 끝났을 때).
# 상태(사건 flags): pb.<문제>.<활동> = true · pb.<문제>.decision = 고른 id · pb.<문제>.ff.<자리> = true · pb.<문제>.done = true.
# 조건식(story_runner): pa('문제','활동') · pd('문제') · pn('문제','a,b') · pdone('문제').
# 기록(clues): pb_<문제>_<활동>(seen → fact · heard → heard+by · compare/connect → guess|fact) · 결정 기록 pb_<문제>_<활동>_<갈래>(guess) · 추가 흔적 pb_<문제>_ff_<자리>(fact).
# 지키는 것: 한 번 끝난 활동은 다시 돌지 않는다(첫 단계가 깃발) · 문제 단계에 event·phase·outcome·ending 금지(FIXED_BEAT·결말은 문제와 무관).
extends RefCounted

const TYPES := ["inspect", "compare", "connect", "decide"]
const DERIVED := ["compare", "connect", "decide"]
const KINDS := ["seen", "heard"]
const FORBIDDEN_STEPS := ["event", "phase", "outcome", "ending"]   # 문제는 이야기 등뼈(FIXED_BEAT·국면·결말)를 움직이지 않는다
const PREFIX := "pb."

static func key(pid: String, aid: String) -> String: return PREFIX + pid + "." + aid
static func decision_key(pid: String) -> String: return PREFIX + pid + ".decision"
static func done_key(pid: String) -> String: return PREFIX + pid + ".done"
static func ff_key(pid: String, ff: String) -> String: return PREFIX + pid + ".ff." + ff
static func clue_id(pid: String, aid: String) -> String: return "pb_%s_%s" % [pid, aid]

# ---- 상태 읽기(story_runner 조건식이 부른다 — flags는 사건 namespace) ----
static func done(flags: Dictionary, pid: String, aid: String) -> bool: return bool(flags.get(key(pid, aid), false))
static func decision(flags: Dictionary, pid: String) -> String: return String(flags.get(decision_key(pid), ""))
static func solved(flags: Dictionary, pid: String) -> bool: return bool(flags.get(done_key(pid), false))
static func count(flags: Dictionary, pid: String, ids: String) -> int:
	var n := 0
	for a in ids.split(",", false):
		if done(flags, pid, String(a).strip_edges()): n += 1
	return n

# ---- 데이터 → 이야기 명령 ----
# 사건 데이터를 받아 objects·triggers·clues·activity_steps를 더해 돌려준다(같은 사전 — 두 번 불러도 한 번만).
static func expand(data: Dictionary) -> Dictionary:
	var probs = data.get("problems")
	if not (probs is Dictionary) or probs.is_empty() or data.get("_problems_expanded", false): return data
	data["_problems_expanded"] = true
	var objects: Array = data.get("objects", [])
	var triggers: Array = data.get("triggers", [])
	var clues: Dictionary = data.get("clues", {})
	var steps_of: Dictionary = data.get("activity_steps", {})
	for pid in probs:
		var p: Dictionary = probs[pid]
		var pw := String(p.get("when", "")).strip_edges()
		var acts: Array = p.get("activities", [])
		for a in acts:
			var aid := String(a.get("id", ""))
			var rec = a.get("record")
			if rec is Dictionary: clues[clue_id(pid, aid)] = _clue(rec, a)
			if String(a.get("type", "")) == "decide":
				for o in a.get("options", []):
					if o.get("record") is Dictionary: clues[clue_id(pid, aid) + "_" + String(o.id)] = _clue(o.record, { "type": "decide" })
		var ffs: Dictionary = p.get("fail_forward", {})
		for ff in ffs:
			var ex = ffs[ff].get("extra", {})
			if ex is Dictionary and ex.get("record") is Dictionary: clues["pb_%s_ff_%s" % [pid, ff]] = _clue(ex.record, { "kind": "seen" })
		for a in acts:
			var aid := String(a.get("id", ""))
			var typ := String(a.get("type", ""))
			steps_of[pid + "." + aid] = _body(pid, p, a)
			if typ == "inspect" and String(a.get("kind", "seen")) == "seen" and a.has("at"):
				objects.append({ "id": "pb_%s_%s" % [pid, aid], "at": a.at, "label": String(a.get("label", "살펴보기")), "radius": float(a.get("radius", 2.0)),
					"when": _and([pw, String(a.get("when", "")), "not pa('%s','%s')" % [pid, aid]]),
					"prompt_type": "INSPECT", "highlight": String(a.get("highlight", "normal")),
					"mark_r": float(a.get("mark_r", 5.0)), "mark_a": float(a.get("mark_a", 0.6)),
					"steps": [{ "activity": pid + "." + aid }], "problem": pid })
			elif typ == "decide":
				# 불러온 뒤(또는 결정 전에 흐름이 끊겼을 때) 다시 묻는 자리 — 바로 앞 활동이 끝날 때는 같은 흐름 안에서 묻는다
				var t := { "id": "pb_%s_%s" % [pid, aid], "once": false, "radius": float(a.get("radius", 30.0)),
					"when": _and([pw, String(a.get("when", "")), _ready(pid, p, a), "pd('%s') == ''" % pid]),
					"steps": [{ "activity": pid + "." + aid }], "problem": pid }
				if a.has("at"): t["at"] = a.at
				else: t["radius"] = 1.0e9; t["at"] = [0.0, 0.0]
				triggers.append(t)
		for ff in ffs:
			var z: Dictionary = ffs[ff]
			var opt := _ff_option(p, ff)
			objects.append({ "id": "pb_%s_ff_%s" % [pid, ff], "at": z.at, "label": String(z.get("label", "살펴보기")), "radius": float(z.get("radius", 2.4)),
				"when": _and([pw, "pd('%s') == '%s'" % [pid, opt], "not f('%s')" % ff_key(pid, ff)]),
				"prompt_type": "INSPECT", "highlight": "normal", "mark_r": float(z.get("mark_r", 6.0)), "mark_a": float(z.get("mark_a", 0.7)),
				"steps": _ff_body(pid, p, ff, z), "problem": pid })
	data["objects"] = objects
	data["triggers"] = triggers
	data["clues"] = clues
	data["activity_steps"] = steps_of
	return data

static func _clue(rec: Dictionary, a: Dictionary) -> Dictionary:
	var typ := String(a.get("type", "inspect"))
	var kind := "fact"
	if typ in DERIVED: kind = String(rec.get("kind", "guess"))
	elif String(a.get("kind", "seen")) == "heard": kind = "heard"
	var c := { "title": String(rec.get("title", "")), "text": String(rec.get("text", "")), "kind": kind }
	if kind == "heard": c["by"] = String(a.get("by", rec.get("by", "")))
	if rec.has("text_if"): c["text_if"] = rec.text_if
	return c

static func _and(parts: Array) -> String:
	var out := []
	for s in parts:
		if String(s).strip_edges() != "": out.append("(%s)" % String(s))
	return " and ".join(out) if not out.is_empty() else "true"

# 파생 활동(compare·connect·decide)이 열리는 조건
static func _ready(pid: String, p: Dictionary, a: Dictionary) -> String:
	if a.has("needs"):
		return _and((a.needs as Array).map(func(x): return "pa('%s','%s')" % [pid, String(x)]))
	var n := int(a.get("after", 0))
	return "pn('%s','%s') >= %d" % [pid, ",".join(_from(p, a)), n] if n > 0 else "true"

# after가 세는 활동: from(있으면) — 없으면 그 결정보다 앞에 적힌 inspect
static func _from(p: Dictionary, a: Dictionary) -> Array:
	if a.has("from"): return (a.from as Array).map(func(x): return String(x))
	var out := []
	for b in p.get("activities", []):
		if b == a: break
		if String(b.get("type", "")) == "inspect": out.append(String(b.id))
	return out

static func _ff_option(p: Dictionary, ff: String) -> String:
	for a in p.get("activities", []):
		for o in a.get("options", []):
			if String(o.get("fail_forward", "")) == ff: return String(o.id)
	return ""

static func _flag_steps(flags) -> Array:
	var out := []
	for fl in (flags if flags is Array else []): out.append({ "flag": String(fl) })
	return out

# 문제가 풀린다(한 번) — result의 깃발과 단계
static func _resolve(pid: String, p: Dictionary) -> Array:
	var r: Dictionary = p.get("result", {})
	return [{ "if": "not pdone('%s')" % pid, "then": [{ "flag": done_key(pid) }] + _flag_steps(r.get("flags", [])) + r.get("do", []) }]

# 활동이 끝난 뒤: 이제 열린 파생 활동을 같은 흐름 안에서 · 결정 없는 문제는 required가 다 끝나면 풀린다
static func _advance(pid: String, p: Dictionary, after_aid: String) -> Array:
	var out := []
	var has_decide := false
	var req := []
	for b in p.get("activities", []):
		var bid := String(b.id)
		var typ := String(b.get("type", ""))
		if typ == "decide": has_decide = true
		if typ != "decide" and bool(b.get("required", true)): req.append("pa('%s','%s')" % [pid, bid])
		if typ in DERIVED and bid != after_aid:
			var w := _and([String(p.get("when", "")), String(b.get("when", "")), _ready(pid, p, b),
				("pd('%s') == ''" % pid) if typ == "decide" else "not pa('%s','%s')" % [pid, bid]])
			out.append({ "if": w, "then": [{ "activity": pid + "." + bid }] })
	if not has_decide and not req.is_empty():
		out.append({ "if": _and(req), "then": _resolve(pid, p) })
	return out

static func _body(pid: String, p: Dictionary, a: Dictionary) -> Array:
	var aid := String(a.id)
	var typ := String(a.get("type", ""))
	var inner := []
	if typ == "decide":
		var opts := []
		for o in a.get("options", []):
			var dd: Array = [{ "flag": decision_key(pid), "value": String(o.id) }, { "flag": key(pid, aid) }] + _flag_steps(o.get("flags", []))
			if o.get("record") is Dictionary: dd.append({ "clue": clue_id(pid, aid) + "_" + String(o.id) })
			dd.append_array(o.get("do", []))
			if String(o.get("fail_forward", "")) == "": dd.append_array(_resolve(pid, p))
			var oo := { "label": String(o.label), "id": String(o.id), "do": dd }
			if o.has("when"): oo["when"] = o.when
			opts.append(oo)
		return [{ "if": "pd('%s') == ''" % pid, "then": [{ "choice": String(a.get("prompt", "")), "options": opts }] }]
	inner.append({ "flag": key(pid, aid) })
	var rec = a.get("record")
	var title := String(rec.get("title", "")) if rec is Dictionary else ""
	var shows_card := typ in DERIVED or String(a.get("kind", "seen")) == "seen"
	if shows_card and a.has("text"): inner.append({ "examine": title, "text": a.text, "kind": "clue" })
	if rec is Dictionary: inner.append({ "clue": clue_id(pid, aid) })
	inner.append_array(_flag_steps(a.get("flags", [])))
	inner.append_array(a.get("do", []))
	inner.append_array(_advance(pid, p, aid))
	return [{ "if": "not pa('%s','%s')" % [pid, aid], "then": inner }]

# fail_forward 자리: 잘못 짚은 자리(짧게) → 추가 흔적 → 문제가 풀리고 본 흐름으로
static func _ff_body(pid: String, p: Dictionary, ff: String, z: Dictionary) -> Array:
	var inner: Array = [{ "flag": ff_key(pid, ff) }]
	if z.has("text"): inner.append({ "examine": String(z.get("title", "")), "text": z.text, "kind": "clue" })
	var ex: Dictionary = z.get("extra", {})
	if ex.has("text"): inner.append({ "examine": String(ex.get("record", {}).get("title", "")), "text": ex.text, "kind": "clue" })
	if ex.get("record") is Dictionary: inner.append({ "clue": "pb_%s_ff_%s" % [pid, ff] })
	inner.append_array(z.get("do", []))
	inner.append_array(_resolve(pid, p))
	return [{ "if": "not f('%s')" % ff_key(pid, ff), "then": inner }]

# ---------------------------------------------------------------------------
# 검사(tools/story/validate_problems.gd · tests/activity/activity_test.gd) — 실패 문구 목록
# ---------------------------------------------------------------------------
static func validate(data: Dictionary) -> Array:
	var errs: Array = []
	var probs = data.get("problems")
	if probs == null: return errs
	if not (probs is Dictionary): return ["problems가 사전이 아님"]
	var anchors: Dictionary = data.get("anchors", {})
	var actor_ids := {}
	for ac in data.get("actors", []):
		if ac is Dictionary: actor_ids[String(ac.get("id", ""))] = true
	var refs := {}
	_collect_refs(data.get("actors", []), refs)
	_collect_refs(data.get("events", {}), refs)
	for o in data.get("objects", []):
		if not String(o.get("id", "")).begins_with("pb_"): _collect_refs(o, refs)
	for t in data.get("triggers", []):
		if not String(t.get("id", "")).begins_with("pb_"): _collect_refs(t, refs)
	var all_acts := {}
	for pid in probs:
		var p = probs[pid]
		var w := "문제 %s" % pid
		if not (p is Dictionary): errs.append(w + ": 사전이 아님"); continue
		if String(pid).contains(".") or String(pid).contains(","): errs.append(w + ": id에 . , 금지")
		var acts = p.get("activities")
		if not (acts is Array) or acts.is_empty(): errs.append(w + ": activities 없음"); continue
		var ids := {}
		var ffs: Dictionary = p.get("fail_forward", {}) if p.get("fail_forward", {}) is Dictionary else {}
		var ff_used := {}
		var n_decide := 0
		for a in acts:
			if not (a is Dictionary) or String(a.get("id", "")) == "": errs.append(w + ": id 없는 활동"); continue
			var aid := String(a.id)
			var wa := "%s.%s" % [pid, aid]
			if ids.has(aid): errs.append(wa + ": 활동 id 겹침")
			ids[aid] = a
			all_acts[pid + "." + aid] = a
			var typ := String(a.get("type", ""))
			if not TYPES.has(typ): errs.append(wa + ": 모르는 type '%s'(inspect·compare·connect·decide만)" % typ); continue
			_check_steps(a.get("do", []), wa, errs)
			match typ:
				"inspect":
					var kind := String(a.get("kind", "seen"))
					if not KINDS.has(kind): errs.append(wa + ": kind는 seen·heard")
					if not (a.get("record") is Dictionary) or String(a.record.get("title", "")) == "": errs.append(wa + ": record.title 없음")
					if kind == "seen":
						if not a.has("at"): errs.append(wa + ": seen인데 at(앵커) 없음")
						elif not _anchor_ok(a.at, anchors): errs.append(wa + ": 없는 앵커 '%s'" % str(a.at))
						if not a.has("text"): errs.append(wa + ": seen인데 text(카드 글) 없음")
					else:
						if String(a.get("by", "")) == "": errs.append(wa + ": heard인데 by(말한 사람) 없음")
						if not a.has("actor") or not actor_ids.has(String(a.actor)): errs.append(wa + ": 없는 인물 '%s'" % String(a.get("actor", "")))
						elif not refs.has(pid + "." + aid): errs.append(wa + ": 인물 talk 어디에도 { activity: '%s.%s' }가 없음" % [pid, aid])
				"compare", "connect":
					if not (a.get("needs") is Array) or a.needs.size() < 2: errs.append(wa + ": needs(둘 이상) 없음")
					if not (a.get("record") is Dictionary) and a.get("flags", []).is_empty(): errs.append(wa + ": record도 flags도 없음")
				"decide":
					n_decide += 1
					if String(a.get("prompt", "")) == "": errs.append(wa + ": prompt 없음")
					var opts = a.get("options", [])
					if not (opts is Array) or opts.size() < 2: errs.append(wa + ": options 둘 이상 필요")
					else:
						var oids := {}
						for o in opts:
							if String(o.get("id", "")) == "" or String(o.get("label", "")) == "": errs.append(wa + ": 갈래 id·label 없음"); continue
							if oids.has(String(o.id)): errs.append(wa + ": 갈래 id 겹침 " + String(o.id))
							oids[String(o.id)] = true
							_check_steps(o.get("do", []), wa + "/" + String(o.id), errs)
							var ffid := String(o.get("fail_forward", ""))
							if ffid != "":
								if not ffs.has(ffid): errs.append(wa + ": 없는 fail_forward '%s'" % ffid)
								ff_used[ffid] = true
					if a.has("at") and not _anchor_ok(a.at, anchors): errs.append(wa + ": 없는 앵커 '%s'" % str(a.at))
					if not a.has("needs") and int(a.get("after", 0)) > 0:
						var fr := _from(p, a)
						if int(a.after) > fr.size(): errs.append(wa + ": after %d > 셀 수 있는 관찰 %d" % [int(a.after), fr.size()])
		# needs·from이 같은 문제의 활동을 가리키나(앞에서 다 모은 뒤)
		for a in acts:
			if not (a is Dictionary): continue
			for x in (a.get("needs", []) as Array) + (a.get("from", []) as Array):
				if not ids.has(String(x)): errs.append("%s.%s: needs/from에 없는 활동 '%s'" % [pid, a.get("id", ""), x])
		if n_decide > 1: errs.append(w + ": decide는 문제마다 하나")
		for ff in ffs:
			var z = ffs[ff]
			if not (z is Dictionary) or not z.has("at") or not _anchor_ok(z.at, anchors): errs.append("%s ff %s: 없는 앵커" % [w, ff])
			elif not (z.get("extra", {}).get("record") is Dictionary): errs.append("%s ff %s: extra.record(추가 흔적) 없음" % [w, ff])
			if not ff_used.has(ff): errs.append("%s ff %s: 어느 갈래도 가리키지 않음" % [w, ff])
			_check_steps(z.get("do", []) if z is Dictionary else [], "%s ff %s" % [w, ff], errs)
		var res = p.get("result", {})
		if not (res is Dictionary): errs.append(w + ": result가 사전이 아님")
		else:
			for fl in res.get("flags", []):
				if String(fl).begins_with(PREFIX): errs.append(w + ": result 깃발은 사건 깃발 이름으로(pb. 접두사 금지)")
			_check_steps(res.get("do", []), w + " result", errs)
	# 데이터 어디서든 { activity: "문제.활동" }이 있는 활동을 가리키나
	for r in refs:
		if not all_acts.has(r): errs.append("없는 활동을 부름: { activity: '%s' }" % r)
	return errs

static func _anchor_ok(at, anchors: Dictionary) -> bool:
	if at is Array: return at.size() >= 2
	return anchors.has(String(at))

static func _check_steps(steps, where: String, errs: Array) -> void:
	var found := {}
	_find_keys(steps, found)
	for k in FORBIDDEN_STEPS:
		if found.has(k): errs.append("%s: 문제 단계에 '%s' 금지(FIXED_BEAT·국면·결말은 문제와 무관)" % [where, k])

static func _find_keys(v, out: Dictionary) -> void:
	if v is Dictionary:
		for k in v:
			out[String(k)] = true
			_find_keys(v[k], out)
	elif v is Array:
		for x in v: _find_keys(x, out)

static func _collect_refs(v, out: Dictionary) -> void:
	if v is Dictionary:
		if v.has("activity"): out[String(v.activity)] = true
		for k in v: _collect_refs(v[k], out)
	elif v is Array:
		for x in v: _collect_refs(x, out)
