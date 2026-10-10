# 고을 사람 말 걸기 — 주변 인물(scripts/region/npc_ambient.gd)에게도 E로 말을 건다(이야기 인물이 먼저).
#   story_director가 만들어 쥔다(사건이 없는 공간에서도). 대상 찾기는 npc_ambient가 0.4초마다 고른 '가까운 사람' 몇 명만 본다
#   (가만히 있을 때 프레임당 비용 없음 — 그 몇 명 거리만 잰다). 배 안내가 떠 있으면 비켜 준다(말 안내는 비키지 않는다 — 곁 사람이 먼저).
#   말 걸면: 그 사람이 멈추고 플레이어 쪽을 보고, 1~3줄(짧은 한 줄은 자막) 말한 뒤 하던 일로 돌아간다. 고르는 줄은 없다.
#   줄 고르기(story/ambient_talk_data.gd): a 소문(rumors_data — 공간·결말·need) → 기록책 '들음 — <말한 사람>' ·
#     b 자리·일·고을·날씨·시간 잡담 + c 사건 결말 반응 · d 손사래. 같은 사람에게 25초 안에 다시 걸면 '아까 말했잖소' 또는 다른 줄.
extends RefCounted

const Data := preload("res://story/ambient_talk_data.gd")
const Rumors := preload("res://story/rumors_data.gd")
const Progress := preload("res://scripts/region/progress.gd")

const REACH := 1.9          # 말 걸 수 있는 거리(m) — 이야기 인물(2.2)보다 조금 짧게
const AGAIN_SEC := 25.0     # 이 안에 다시 걸면 '아까 말했잖소'
const RUMOR_NEAR := 180.0   # 소문 자리에서 이만큼 안의 사람이 그 소문을 안다(반경×4와 큰 쪽)
const RECENT := 48          # 최근에 한 말(누가 했든) — 금세 되풀이하지 않게

var d                       # story_director
var busy := false
var last := {}              # 마지막 대화(시험): { key, kind, speaker, lines, src, rumor, var }
var log_lines := false
var _mem := {}              # 칸 키 → { n, t, said: [] }
var _recent: Array = []
var _rng := RandomNumberGenerator.new()
var _rumors = null
var _gen := 0

func _init(director) -> void:
	d = director
	_rng.seed = Time.get_ticks_usec()
	log_lines = d.log_story or d.main.args.has("talktest")

func _npc():
	return d.main.get("npcs_amb")

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

# ---- 대상 ----
# 가장 가까운 말 걸 수 있는 고을 사람(없으면 null). 나루 배 안내·큰길 말 안내보다 곁 사람이 먼저(배를 탄 동안·말 위에서는 없음)
func target(pp: Vector2) -> Variant:
	if busy: return null
	var npc = _npc()
	if npc == null: return null
	var m = d.main
	if m.boats != null and m.boats.riding(): return null   # 배 안내(나루 E)는 곁 사람 말 걸기를 막지 않는다 — 가까운 사람이 먼저(region_main은 대상이 있으면 배 E를 주지 않는다)
	# 큰길 말 타기 안내(넓은 구역)는 곁 사람 말 걸기를 막지 않는다 — 가까운 사람이 먼저(region_main은 대상이 있으면 말 E를 주지 않는다)
	if m.horse_ride != null and m.horse_ride.busy(): return null
	if m.world.indoor != null: return null
	var key: int = npc.nearest_talkable(pp, REACH)
	if key < 0: return null
	var inf: Dictionary = npc.info(key)
	return { id = "amb:%d" % key, kind = "ambient", key = key, p = inf.p, r = REACH, label = "%s · 말 걸기" % speaker_of(inf) }

func speaker_of(inf: Dictionary) -> String:
	var k := String(inf.kind)
	var over: Dictionary = Data.SPEAKER_REGION.get(String(d.space_id), {})
	if over.has(k): return String(over[k])
	if String(inf.get("cls", "")) == "market" and Data.MARKET_SPEAKER.has(k): return String(Data.MARKET_SPEAKER[k])
	return String(Data.SPEAKER.get(k, "마을 사람"))

# ---- 말 걸기 ----
func talk(key: int) -> void:
	var npc = _npc()
	if busy or npc == null or not npc.agents.has(key): return
	busy = true
	_gen += 1
	var gen := _gen
	var inf: Dictionary = npc.info(key)
	npc.hold(key, d.main.player_pos)
	d.face_actor("player", null, inf.p)
	d.ui.prompt("")
	d._target = null
	if d.onboard != null: d.onboard.on_interact("actor")
	var r := pick(key, inf)
	var speaker := speaker_of(inf)
	r.speaker = speaker
	r.key = key; r.kind = inf.kind
	last = r
	if log_lines: printerr("AMBTALK key=%d kind=%s mode=%s src=%s [%s] %s" % [key, inf.kind, inf.mode, r.src, speaker, " / ".join(r.lines)])
	if r.src == "rumor": _record(r, speaker, inf)
	var lines: Array = r.lines
	if lines.size() == 1 and String(lines[0]).length() <= 16 and r.src != "rumor":
		d.ui.caption("%s  “%s”" % [speaker, lines[0]], 2.4)   # 아주 짧은 말은 자막으로(조작을 막지 않는다)
		busy = false
		await d.wait(2.2)
	else:
		await d.ui.say(speaker, lines)
		busy = false
	if is_instance_valid(npc) and (gen == _gen or int(last.get("key", -1)) != key): npc.unhold(key)   # 그사이 같은 사람과 또 말하면 그쪽이 놓는다

# 기록책 '사람의 말'(◇ 들음 — 말한 사람). 사실로 올리지 않는다
func _record(r: Dictionary, speaker: String, inf: Dictionary) -> void:
	var line := String(r.rumor_line)
	if Progress.add_heard({ id = String(r.rumor), space = String(d.space_id), by = speaker, text = line, place = String(inf.get("place", "")) }):
		d.ui.toast("기록 — 들음 · " + speaker, "journal")
		if log_lines: printerr("AMBTALK heard by=%s id=%s" % [speaker, r.rumor])

# ---- 줄 고르기 ----
func _vars() -> Dictionary:
	var v: Dictionary = Progress.vars().duplicate()
	if d.S != null: v.merge(d.S.vars, true)
	return v

func _cond() -> Dictionary:
	var m = d.main
	var c := { night = false, morning = false, evening = false, rain = false, snow = false, fog = false, wind = false, zone = "" }
	var h: float = m.hour
	c.night = TimeOfDay.night_factor(h) > 0.5
	c.morning = h >= 5.0 and h < 9.0
	c.evening = h >= 17.0 and h < 20.0
	var w = m.weather
	if w != null:
		c.rain = float(w.cur.rain) > 0.4
		c.snow = float(w.cur.snowfall) > 0.4
		c.fog = float(w.cur.fogm) > 2.0
		c.wind = float(w.cur.wind) > 0.7
		c.zone = String(w.zone)
	return c

func _one(arr: Array) -> Variant:
	return arr[_rng.randi() % arr.size()] if not arr.is_empty() else null

static func _as_lines(e) -> Array:
	return e.duplicate() if e is Array else [String(e)]

static func _key_of(e) -> String:
	return " / ".join(e) if e is Array else String(e)

func pick(key: int, inf: Dictionary) -> Dictionary:
	var kind := String(inf.kind)
	var reg := Data.register(kind)
	var now := _now()
	var mem: Dictionary = _mem.get(key, {})
	if mem.get("kind", kind) != kind: mem = {}
	if mem.is_empty(): mem = { n = 0, t = -1e9, said = [], kind = kind }
	_mem[key] = mem
	var again: bool = mem.n > 0 and now - float(mem.t) < AGAIN_SEC
	mem.n = int(mem.n) + 1 if again else 1
	mem.t = now
	# 아까 말했잖소(같은 사람에게 금세 다시) — 세 번째부터는 늘
	if again and (mem.n >= 3 or _rng.randf() < 0.5):
		return { src = "repeat", lines = [String(_one(Data.REPEAT.get(reg, Data.REPEAT.hao)))] }
	var cond := _cond()
	var vars := _vars()
	# 일하는 중 — 짧게 손사래
	if _rng.randf() < float(Data.BUSY_MODE.get(String(inf.mode), 0.0)):
		return { src = "brush", lines = [String(_one(Data.BRUSH.get(reg, Data.BRUSH.hao)))] }
	# a 소문
	if Data.GOSSIP.has(kind):
		var rr := _rumor(inf, vars)
		if not rr.is_empty():
			var lines := [String(rr.line)]
			if _rng.randf() < 0.35 and Data.RUMOR_LEAD.has(reg if reg == "hage" else "hao"):
				lines.push_front(String(_one(Data.RUMOR_LEAD[reg if reg == "hage" else "hao"])))
			_remember(mem, rr.line)
			return { src = "rumor", lines = lines, rumor = rr.id, rumor_line = rr.line, rvar = rr.rvar }
	# b·c 잡담 + 결말 반응(무게로 섞는다 — 아직 안 들은 결말 반응은 무겁게)
	var pool: Array = []   # [줄, 무게, 출처]
	_collect(pool, inf, reg, cond, vars)
	var cand: Array = []
	var total := 0.0
	for e in pool:
		var k := _key_of(e[0])
		if _recent.has(k) or (mem.said as Array).has(k): continue
		cand.append(e); total += float(e[1])
	if cand.is_empty():
		return { src = "brush", lines = [String(_one(Data.BRUSH.get(reg, Data.BRUSH.hao)))] }
	var x := _rng.randf() * total
	var got: Array = cand[cand.size() - 1]
	for e in cand:
		x -= float(e[1])
		if x <= 0.0: got = e; break
	_remember(mem, _key_of(got[0]))
	return { src = String(got[2]), lines = _as_lines(got[0]) }

func _remember(mem: Dictionary, k: String) -> void:
	(mem.said as Array).append(k)
	_recent.append(k)
	while _recent.size() > RECENT: _recent.pop_front()

func _add(pool: Array, groups: Dictionary, cond: Dictionary, w_any: float, w_cond: float, src: String) -> void:
	for g in groups:
		var w := 0.0
		if g == "any": w = w_any
		elif cond.get(g, false): w = w_cond
		if w <= 0.0: continue
		for e in groups[g]: pool.append([e, w, src])

func _collect(pool: Array, inf: Dictionary, reg: String, cond: Dictionary, vars: Dictionary) -> void:
	var kind := String(inf.kind)
	var space := String(d.space_id)
	var hao := reg == "hao"
	# 밤에는 밤 줄을 더 무겁게
	var wc := 3.0
	_add(pool, Data.KIND.get(kind, {}), cond, 1.0, wc, "small")
	if hao:
		_add(pool, Data.MODE.get(String(inf.mode), {}), cond, 1.4, wc, "small")
		var arch := String(inf.get("cls", "")) if String(inf.get("cls", "")) == "market" else String(inf.get("arch", ""))
		_add(pool, Data.ARCH.get(arch, {}), cond, 0.9, wc, "small")
		_add(pool, Data.ZONE.get(String(cond.zone), {}), cond, 0.5, 2.5, "small")
		_add(pool, Data.WEATHER, cond, 0.0, 2.0, "small")
	var rg: Dictionary = Data.REGION.get(space, {})
	if hao: _add(pool, { any = rg.get("any", []) }, cond, 1.0, 0.0, "small")
	elif rg.has(reg): _add(pool, { any = rg[reg] }, cond, 1.2, 0.0, "small")
	var sid := String(inf.get("settle", ""))
	if hao and sid != "" and rg.has("at_" + sid): _add(pool, { any = rg["at_" + sid] }, cond, 2.5, 0.0, "small")
	# c 결말 반응 — 그 값 칸(+ "*" 어느 결말이든)만. 결말이 났으면 무겁게
	for o in Data.OUTCOME:
		if not (o.space as Array).has(space): continue
		var lines_by: Dictionary = o.get("lines" if hao else "lines_" + reg, {})
		if lines_by.is_empty(): continue
		var val := str(vars.get(String(o.var), ""))
		var w := 2.5 if val != "" else 1.2
		for e in lines_by.get(val, []): pool.append([e, w, "outcome"])
		if val != "":
			for e in lines_by.get("*", []): pool.append([e, w, "outcome"])

# 이 사람이 아는 소문(아직 기록책에 없는 줄) — 결말에 따라 달라지는 소문이 먼저
func _rumor(inf: Dictionary, vars: Dictionary) -> Dictionary:
	if _rumors == null: _rumors = Rumors.for_space(String(d.space_id), d.world.region)
	var p: Vector2 = inf.p
	var best := {}
	var best_score := -INF
	for r in _rumors:
		# 결말이 난 소문은 그 공간 어디서나 돈다(가까운 쪽이 먼저), 나머지는 소문 자리 둘레에서만
		var by_outcome: bool = r.has("var") and str(vars.get(String(r.var), "")) != ""
		var reach := INF if by_outcome else maxf(float(r.get("radius", 26.0)) * 4.0, RUMOR_NEAR)
		var dist: float = p.distance_to(r.p)
		if dist > reach: continue
		var line: String = Rumors.pick(r, vars, vars)
		if line == "" or Progress.heard_has(line): continue
		var score := (1000.0 if by_outcome else 0.0) - dist
		if score > best_score:
			best_score = score
			best = { id = String(r.id), line = line, rvar = String(r.get("var", "")) if by_outcome else "" }
	if best.is_empty(): return {}
	# 결말 소문은 늘, 나머지는 반쯤
	if best.rvar == "" and _rng.randf() > 0.6: return {}
	return best
