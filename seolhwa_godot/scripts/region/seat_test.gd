# 앉은 고을 사람 시험(region_main --seattest=<거점>,… — tools/run_story_tests.sh seat:*). 헤드리스로 돈다.
#   거점마다(장터) 그 둘레로 가서:
#   1 좌판·가가·시전 장꾼 자리에 사람이 있다(≥ --seatmin, 기본 3) — 앉은(sit·sit_talk·sit_work·sit_seat) 사람이 서서 파는 사람보다 많다
#   2 앉은 사람은 빌더 사람이고 그 동작 그림이 있다 · 3초 동안 자리를 떠나지 않는다 · 땅 아래로 꺼지지 않는다
#   3 이야기 인물이 그 자리에 오면(가짜 story_ref.actors) 앉은 사람은 놓이고 다시 생기지 않는다 · 사건 군중 자리(가짜 crowd_ref)도 같다 · 치우면 다시 앉는다
#   4 말 걸기(hold): 땅에 앉은 사람은 앉은 채 sit_talk, 풀면(unhold) 하던 자세로
#   5 주막 평상 손님·툇마루 노인·나무 그늘처럼 장꾼 아닌 앉은 자리도 고을에 있다(--seatkinds, 기본 guest,maru)
#   통과하면 "SEATTEST PASS n", 아니면 "SEATTEST FAIL <까닭>".
extends RefCounted

const SIT := ["sit", "sit_talk", "sit_work", "sit_seat", "squat"]
const NA := preload("res://scripts/region/npc_ambient.gd")
const CharBank := preload("res://scripts/char_bank.gd")
var main
var _fails: Array = []
var _n := 0

func _init(m) -> void:
	main = m

func _ok(c: bool, why: String) -> void:
	_n += 1
	if c: print("SEATTEST check ok ", why)
	else:
		_fails.append(why); print("SEATTEST check FAIL ", why)

func _wait_load() -> void:
	await main._wait_frames(10)
	var n := 0
	while main._loading and n < 6000:
		await main._wait_frames(1); n += 1
	n = 0
	while (main.world.stats.jobs > 0 or main.placement.busy()) and n < 900:
		await main._wait_frames(1); n += 1

func _settle(sid: String):
	for s in main.world.region.get("settlements", []):
		if String(s.get("id", "")) == sid: return Vector2(float(s.x), float(s.z))
	return null

func _seated(npc, c: Vector2, r: float, kinds: Array) -> Array:
	var out := []
	for key in npc.agents:
		var ag: Dictionary = npc.agents[key]
		if ag.mode != "seat": continue
		var site: Dictionary = npc.sites[key / NA.SLOTS]
		if not kinds.is_empty() and not (String(NA.SEAT_KIT[site.seat.key].kind) in kinds): continue
		if Vector2(ag.pos.x, ag.pos.z).distance_to(c) <= r: out.append(key)
	return out

func run(spec: String) -> void:
	Engine.max_fps = 0
	await _wait_load()
	var npc = main.npcs_amb
	if npc == null or npc._bset == "":
		_finish("주변 인물 또는 빌더 묶음 없음(data/chars — tools/chars_bake.html?set=amb_all)"); return
	var places: Array = Array(spec.split(",", false))
	var want := int(main.args.get("seatmin", "3"))
	for sid in places:
		var c = _settle(String(sid))
		if c == null: _ok(false, "거점 없음 " + String(sid)); continue
		main.teleport(c.x, c.y)
		var t := 0
		while t < 600 and _seated(npc, c, 70.0, ["vendor"]).size() < want:
			await main._wait_frames(5); t += 5
		await main._wait_frames(30)
		var vend: Array = _seated(npc, c, 70.0, ["vendor"])
		var sitting := 0; var standing := 0; var bad := []
		for key in vend:
			var ag: Dictionary = npc.agents[key]
			if String(ag.anim) in SIT: sitting += 1
			else: standing += 1
			if not (CharBank.has(String(ag.ch.kind))): bad.append("빌더 아님 " + String(ag.ch.kind))
			elif ag.get("sit", "") != "stand" and not ag.ch.has_anim(String(ag.anims[0])): bad.append("동작 없음 %s %s" % [ag.ch.kind, ag.anims[0]])
			if ag.pos.y < main.world.height_at(ag.pos.x, ag.pos.z) - 0.05: bad.append("땅 아래 %s" % key)
		_ok(vend.size() >= want, "%s 장꾼 %d명(≥%d)" % [sid, vend.size(), want])
		_ok(sitting > standing, "%s 앉은 장꾼 %d > 선 장꾼 %d" % [sid, sitting, standing])
		_ok(bad.is_empty(), "%s 장꾼 그림·높이 %s" % [sid, bad])
		# 자리를 떠나지 않는다
		var p0 := {}
		for key in vend: p0[key] = npc.agents[key].pos
		await main._wait_frames(180)
		var moved := 0
		for key in p0:
			if npc.agents.has(key) and (npc.agents[key].pos as Vector3).distance_to(p0[key]) > 0.05: moved += 1
		_ok(moved == 0, "%s 앉은 사람 3초 그대로(움직임 %d)" % [sid, moved])
		vend = _seated(npc, c, 40.0, ["vendor"])   # 지금 있는 사람으로(먼 사람은 그사이 놓였을 수 있다)
		if vend.size() < 2: _ok(false, "%s 장꾼 둘 없음" % sid); continue
		# 이야기 인물·군중이 차지한 자리는 비킨다
		var k1: int = vend[0]; var k2: int = vend[1]
		var p1 := Vector2(npc.agents[k1].pos.x, npc.agents[k1].pos.z)
		var p2 := Vector2(npc.agents[k2].pos.x, npc.agents[k2].pos.z)
		var old_s = npc.story_ref; var old_c = npc.crowd_ref
		npc.story_ref = { actors = { seat_test = { shown = true, pos = Vector3(p1.x, 0.0, p1.y) } } }
		npc.crowd_ref = { crowds = { seat_test = { on = true, members = [{ home = p2 }] } } }
		await main._wait_frames(150)
		var near1 := 0; var near2 := 0
		for key in npc.agents:
			var ag: Dictionary = npc.agents[key]
			if ag.mode != "seat": continue
			var q := Vector2(ag.pos.x, ag.pos.z)
			if q.distance_to(p1) < 1.4: near1 += 1
			if q.distance_to(p2) < 1.2: near2 += 1
		_ok(near1 == 0, "%s 이야기 인물 자리 비움" % sid)
		_ok(near2 == 0, "%s 사건 군중 자리 비움" % sid)
		npc.story_ref = old_s; npc.crowd_ref = old_c
		# 말 걸기: 앉은 채로
		var t2 := 0
		var k3 := -1
		while t2 < 300 and k3 < 0:
			for key in _seated(npc, c, 70.0, ["vendor"]):
				if npc.agents[key].get("sit", "") == "ground": k3 = key; break
			if k3 < 0: await main._wait_frames(5); t2 += 5
		if k3 >= 0:
			npc.hold(k3, main.player_pos)   # 말 거는 동안은 놓이지 않는다
			await main._wait_frames(10)
			_ok(npc.agents.has(k3) and String(npc.agents[k3].ch.anim) == "sit_talk", "%s 말 걸면 앉은 채 sit_talk" % sid)
			var ch = npc.agents[k3].ch if npc.agents.has(k3) else null
			npc.unhold(k3)
			await main._wait_frames(4)
			_ok(ch != null and String(ch.anim) in SIT, "%s 풀면 앉은 자세(%s)" % [sid, ch.anim if ch != null else "-"])
		else: _ok(false, "%s 땅에 앉은 장꾼 없음" % sid)
	# 장꾼 아닌 앉은 자리(권역 전체 자리 표)
	var kinds := {}
	for s in npc.sites:
		if s.mode == "seat": kinds[String(NA.SEAT_KIT[s.seat.key].kind)] = int(kinds.get(String(NA.SEAT_KIT[s.seat.key].kind), 0)) + 1
	print("SEATTEST seat sites ", kinds)
	for k in String(main.args.get("seatkinds", "guest,maru")).split(",", false):
		_ok(int(kinds.get(k, 0)) > 0, "앉는 자리 %s 있음(%d)" % [k, int(kinds.get(k, 0))])
	if main.args.has("seatshots"): await _shots(String(main.args.seatshots), places)
	_finish("")

# --seatshots=<폴더>: 장터 전경 + 앉는 자리 종류마다 한 장(창 모드에서만 그림이 있다)
func _shots(dir: String, places: Array) -> void:
	var npc = main.npcs_amb
	var tag := String(main.world.region.get("region_id", "r")).substr(0, 2).to_lower()
	for sid in places:
		var c = _settle(String(sid))
		if c == null: continue
		main.teleport(c.x, c.y)
		await main._wait_frames(90)
		main._save(main._abs(dir.path_join("%s_%s.png" % [tag, sid])))
	var c0 = _settle(String(places[0])) if not places.is_empty() else Vector2.ZERO
	for kind in ["guest", "maru", "rest", "platform", "pavilion", "boatman", "petition"]:
		var cand := []
		for i in npc.sites.size():
			var s: Dictionary = npc.sites[i]
			if s.mode == "seat" and String(NA.SEAT_KIT[s.seat.key].kind) == kind: cand.append(i)
		cand.sort_custom(func(a, b): return (npc.sites[a].p as Vector2).distance_to(c0) < (npc.sites[b].p as Vector2).distance_to(c0))
		var done := false
		for si in cand.slice(0, 12):
			var sp: Vector2 = npc.sites[si].p
			main.teleport(sp.x + 3.5, sp.y + 2.5)
			await main._wait_frames(120)
			var hit := false
			for key in npc.agents:
				if key / NA.SLOTS == si: hit = true; break
			if not hit: continue
			main._save(main._abs(dir.path_join("%s_seat_%s.png" % [tag, kind])))
			done = true; break
		print("SEATTEST shot %s %s" % [kind, "ok" if done else "없음"])

func _finish(why: String) -> void:
	if why != "": _fails.append(why)
	print("SEATTEST %s %s" % ["PASS" if _fails.is_empty() else "FAIL", str(_n) if _fails.is_empty() else str(_fails)])
	main._quit()
