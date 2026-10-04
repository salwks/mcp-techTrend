# 이야기 명령 실행기 — 사건 데이터(story/<사건>/*_data.gd)의 단계 목록을 차례로 실행한다(비동기).
# 단계는 Dictionary 하나에 명령 키 하나: { "say": "주모", "lines": [...] } 처럼. 조건은 Godot Expression 문자열로,
# 이 실행기의 함수들(f·k·c·has·n·ph·v·out·seen·talked·fn)을 부를 수 있다. 예: "f('case_started') and not k('K_FOOD')"
#
# 명령: say · caption · toast · examine · choice(loop, options[{label, when, disabled_when, hint, do, end}]) · if(then/else) ·
#   flag · unflag · clue · rule · give · take · var · phase · outcome · wait · teleport · move · face · anim · place · show ·
#   spawn · despawn · camera · fade · letterbox · cutscene · time · weather · world · journal · combat(store) · call · event ·
#   shake · save · ending · log · spirit·sound·talisman·dread(잔영 체계 — scripts/story/spirits.gd) · chase(추격 — scripts/story/chase.gd, 결과 store: "end" | "lost") · drift(물살 표식 — scripts/story/drift.gd)
extends RefCounted

var d          # story_director
var S          # story_state
var case_fn    # 사건 GDScript(story/<사건>/<사건>_case.gd) 인스턴스 — call·fn이 부른다
var busy_count := 0
var gen := 0
var last := {}           # combat 결과 등(store 이름 → 값), 마지막 선택 id
var trace: Array = []
var _exprs := {}

func _init(director, state) -> void:
	d = director
	S = state

var busy: bool:
	get: return busy_count > 0

func log_line(kind: String, data) -> void:
	trace.append([kind, data])
	if trace.size() > 4000: trace = trace.slice(1000)
	if d.log_story: printerr("STORY %s %s" % [kind, data if data is String else JSON.stringify(data)])

# ---- 조건식 ----
func cond(e) -> bool:
	if e == null: return true
	if e is bool: return e
	var s := String(e).strip_edges()
	if s == "": return true
	var ex: Expression = _exprs.get(s)
	if ex == null:
		ex = Expression.new()
		var err := ex.parse(s)
		if err != OK:
			push_warning("이야기 조건식 오류: %s — %s" % [s, ex.get_error_text()]); return false
		_exprs[s] = ex
	var r = ex.execute([], self, false)
	if ex.has_execute_failed():
		push_warning("이야기 조건식 실행 실패: " + s); return false
	return bool(r)

# Expression에서 부르는 짧은 이름들
func f(k: String) -> bool: return S.is_flag(k)
func k(id: String) -> bool: return S.knows(id)
func c(id: String) -> bool: return S.has_clue(id)
func has(item: String, nn := 1) -> bool: return S.has(item, nn)
func n(item: String) -> int: return S.count(item)
func ph(p: String) -> bool: return S.phase == p
func v(name: String): return S.vars.get(name)
func out(o: String) -> bool: return String(S.vars.get(d.outcome_var(), "")) == o
func seen(id: String) -> bool: return S.seen.has(id)
func talked(id: String) -> int: return int(S.talked.get(id, 0))
func w(key: String) -> bool: return bool(S.world.get(key, false))
func fn(name: String, a = null):
	if case_fn == null or not case_fn.has_method(name): return null
	return case_fn.call(name) if a == null else case_fn.call(name, a)
func r(name: String): return last.get(name)
# 잔영·호신물(scripts/story/spirits.gd): tal(호신물 id, ''=아무거나) 지녔나 · zone(경계 id) 안인가 · night() · spv(잔영 id) 보이나
func tal(id := "") -> bool: return d.spirits != null and d.spirits.equipped(id)
func zone(id: String) -> bool: return d.spirits != null and d.spirits.in_zone(id)
func night() -> bool: return d.spirits != null and d.spirits.is_night()
func spv(id: String) -> bool: return d.spirits != null and d.spirits.spirit_visible(id)

# ---- 실행 ----
func run(steps: Array) -> void:
	var g := gen
	busy_count += 1
	await exec(steps, g)
	if g != gen: return
	busy_count = maxi(0, busy_count - 1)
	if busy_count == 0: d.on_story_idle()

func aborted(g: int) -> bool: return g != gen

func exec(steps: Array, g: int) -> void:
	for st in steps:
		if aborted(g): return
		if not (st is Dictionary): continue
		if st.has("when") and not cond(st.when): continue
		await step(st, g)

func step(st: Dictionary, g: int) -> void:
	var ui = d.ui
	if st.has("say"):
		var lines = st.get("lines", st.get("line", []))
		await ui.say(String(st.say), lines)
	elif st.has("caption"):
		await ui.caption(String(st.caption), float(st.get("sec", 2.4)))
	elif st.has("toast"):
		ui.toast(String(st.toast), String(st.get("kind", "info")))
	elif st.has("examine"):
		await ui.examine(String(st.examine), st.get("text", ""), String(st.get("kind", "clue")))
	elif st.has("choice"):
		await _choice(st, g)
	elif st.has("if"):
		if cond(st["if"]): await exec(st.get("then", []), g)
		else: await exec(st.get("else", []), g)
	elif st.has("flag"):
		S.flags[String(st.flag)] = st.get("value", true)
		log_line("flag", [st.flag, st.get("value", true)])
		d.mark_dirty()
	elif st.has("unflag"):
		S.flags.erase(String(st.unflag)); d.mark_dirty()
	elif st.has("clue"):
		d.learn_clue(String(st.clue), bool(st.get("quiet", false)))
	elif st.has("rule"):
		d.learn_rule(String(st.rule), bool(st.get("quiet", false)))
	elif st.has("give"):
		d.give(String(st.give), int(st.get("n", 1)), bool(st.get("quiet", false)))
	elif st.has("take"):
		d.take(String(st.take), int(st.get("n", 1)))
	elif st.has("var"):
		S.vars[String(st["var"])] = st.get("value")
		log_line("var", [st["var"], st.get("value")])
		d.mark_dirty()
	elif st.has("phase"):
		S.phase = String(st.phase); log_line("phase", S.phase); d.on_phase()
	elif st.has("outcome"):
		S.vars[d.outcome_var()] = String(st.outcome); log_line("outcome", st.outcome); d.mark_dirty()
	elif st.has("wait"):
		await d.wait(float(st.wait))
	elif st.has("teleport"):
		d.teleport_to(st.teleport, String(st.get("face", "")))
	elif st.has("move"):
		await d.move_actor(String(st.move), st.get("to", []), float(st.get("speed", 1.6)), String(st.get("anim", "walk")), String(st.get("end", "idle")))
	elif st.has("face"):
		d.face_actor(String(st.face), st.get("dir", ""), st.get("to"))
	elif st.has("anim"):
		d.anim_actor(String(st.anim), String(st.get("name", "idle")), bool(st.get("restart", true)))
	elif st.has("place"):
		d.place_actor(String(st.place), st.get("at"), st.get("y"), String(st.get("facing", "")))
	elif st.has("show"):
		d.show_actor(String(st.show), bool(st.get("value", true)))
	elif st.has("spawn"):
		d.spawn_actor(String(st.spawn), String(st.get("kind", "villager_m")), st.get("at"), String(st.get("facing", "down")), String(st.get("name", "")), String(st.get("variant", "")))
	elif st.has("despawn"):
		d.despawn_actor(String(st.despawn))
	elif st.has("camera"):
		d.camera(st.camera)
	elif st.has("fade"):
		await ui.fade(String(st.fade) == "out", float(st.get("sec", 0.7)))
	elif st.has("letterbox"):
		ui.letterbox(bool(st.letterbox))
	elif st.has("cutscene"):
		d.cutscene(bool(st.cutscene))
	elif st.has("time"):
		d.set_hour(float(st.time))
	elif st.has("weather"):
		d.set_weather(String(st.weather))
	elif st.has("world"):
		d.world_state(String(st.world), st.get("value", true))
	elif st.has("journal"):
		d.journal_note(String(st.journal))
	elif st.has("combat"):
		var res: String = await d.combat(String(st.combat), st)
		last[String(st.get("store", "res"))] = res
		log_line("combat", res)
	elif st.has("call"):
		if case_fn != null and case_fn.has_method(String(st.call)):
			var args: Array = st.get("args", [])
			var res = await case_fn.callv(String(st.call), args)
			if st.has("store"): last[String(st.store)] = res
		else: push_warning("이야기: 없는 함수 " + String(st.call))
	elif st.has("event"):
		await run_event(String(st.event), g)
	elif st.has("chase"):
		var cres: String = await load("res://scripts/story/chase.gd").run(d, String(st.chase), int(st.get("from", -1)))
		last[String(st.get("store", "chase"))] = cres
	elif st.has("drift"):   # 떠내려가는 표식(scripts/story/drift.gd) — 결과(닿은 갯가 id 배열) store
		var dres: Array = await load("res://scripts/story/drift.gd").run(d, st)
		last[String(st.get("store", "drift"))] = dres
	elif st.has("spirit") or st.has("sound") or st.has("talisman") or st.has("dread"):
		if d.spirits != null: await d.spirits.step(st)
	elif st.has("endcombat"):
		d.end_combat()
	elif st.has("shake"):
		d.shake(float(st.shake), float(st.get("sec", 0.4)))
	elif st.has("save"):
		d.save()
	elif st.has("ending"):
		await d.show_ending()
	elif st.has("log"):
		log_line("log", st.log)
	# 안내·지도·관찰(scripts/story/onboarding.gd): { "discover": map_places id } 지도에 적기(들음) · { "observe": 글, "about": 대상 } 기록책 관찰 ·
	#   { "onboard": "ITEM_USE" } 처음 한 번 안내 표시를 본 것으로
	elif st.has("discover") or st.has("observe") or st.has("onboard"):
		var ob = d.get("onboard")
		if ob != null: ob.step(st)

func run_event(id: String, g: int) -> void:
	var ev: Dictionary = d.events.get(id, {})
	if ev.is_empty():
		push_warning("이야기: 없는 사건 장면 " + id); return
	if not bool(ev.get("SOURCE_VERIFIED", true)): return   # §44: 확인 안 된 사건은 빌드에서 뺀다
	S.seen[id] = true
	log_line("event", id)
	d.on_event(id, ev)
	await exec(ev.get("steps", []), g)

# options: [{ label, id, when, disabled_when, hint, do: [...], end: bool }]
# loop: true면 끝(end) 선택지나 고를 것이 없을 때까지 다시 묻는다(이야기 주제 고르기)
func _choice(st: Dictionary, g: int) -> void:
	var loop := bool(st.get("loop", false))
	var guard := 0
	while guard < 30:
		guard += 1
		var shown := []
		var opts := []
		for o in st.get("options", []):
			if o.has("when") and not cond(o.when): continue
			shown.append(o)
			var dis: bool = o.has("disabled_when") and cond(o.disabled_when)
			opts.append({ label = String(o.label), disabled = dis, hint = String(o.get("hint", "")) })
		if shown.is_empty(): return
		var only_end := true
		for o in shown:
			if not o.get("end", false): only_end = false
		if loop and only_end and guard > 1: return
		var i: int = await d.ui.choice(String(st.choice), opts)
		if aborted(g): return
		var o: Dictionary = shown[maxi(0, i)]
		last.choice = String(o.get("id", o.label))
		await exec(o.get("do", []), g)
		if not loop or o.get("end", false): return
