# 역참 마방의 살아 있는 것 — 칸마다 구유에 머리를 박고 여물을 먹는 말, 마당에서 풀 뜯고 거니는 말, 가로대에 매여 기다리는 안장 얹은 말,
# 그리고 마부(마부가 짚가리에서 건초를 안아 구유에 붓고, 기다리는 말을 솔질하고, 말 타려는 손님에게 말을 끌어 온다).
#   마방(kit/station/mabang.gd)·문 앞(kit/station/hitch.gd)은 정적 배치(placement_stations.json). 여기서는 플레이어가 가까이(150m) 오면 그림을 만들고
#   멀어지면(200m) 지운다 — 역 하나에 그림 9~11장.
#   그림: data/frames_stable.json(tools/export_stable_frames.js — stable_bay·chestnut·grey·pony, mabu) + 탈 말 ride_horse(기다리는 말).
#   그림 파일이 없으면(다른 맥에서 아직 안 구움) 탈 말·주변 말·마을 사람 그림으로 대신한다.
# horse_ride가 부른다: setup(main) · update(dt) · near(pp) · lend(st)(마부가 기다리는 말을 끌고 나옴) · lead(st, 말 자리, 걷나) · release(st)
extends RefCounted

const Stations := preload("res://scripts/region/stations.gd")
const Mabang := preload("res://kit/station/mabang.gd")
const Hitch := preload("res://kit/station/hitch.gd")
const C := preload("res://kit/village/_common.gd")

const NEAR := 150.0
const FAR := 200.0
const WALK := 1.35          # 마부 걸음(m/s)
const PAD_WALK := 0.9       # 마당 말 걸음
const FLOOR := 0.3          # 마구간 바닥(기단) 높이

var main
var world
var list: Array = []
var live := {}              # 역 id → 살아 있는 것들
var root: Node3D
var coats: Array = []
var pony_coats: Array = []
var groom_kind := ""
var wait_kind := ""
var _chk := 0.0
var _hay_proto: Node3D = null
var stats := { spawned = 0 }

func setup(m) -> void:
	main = m; world = m.world
	var sid := String(world.region.get("route_id", world.region.get("region_id", "")))
	list = Stations.in_space(sid)
	if list.is_empty(): return
	var want := ["mabu"]
	var any_pony := false; var any_horse := false
	for s in list:
		if bool(s.get("pony", false)): any_pony = true
		else: any_horse = true
	if any_pony: want.append("stable_pony")
	if any_horse: want.append_array(["stable_bay", "stable_chestnut", "stable_grey"])
	SpriteChar.merge_bank("frames_stable.json", want)
	for k in ["stable_bay", "stable_chestnut", "stable_grey"]:
		if SpriteChar._banks.has(k): coats.append(k)
	if SpriteChar._banks.has("stable_pony"): pony_coats.append("stable_pony")
	if coats.is_empty():   # 그림이 없으면 탈 말·주변 말로
		if SpriteChar._banks.has("ride_horse"): coats.append("ride_horse")
		elif FileAccess.file_exists("res://data/frames_amb.json"):
			SpriteChar.load_bank("horse", "frames_amb.json")
			if SpriteChar._banks.has("horse"): coats.append("horse")
	if pony_coats.is_empty(): pony_coats = coats
	groom_kind = "mabu" if SpriteChar._banks.has("mabu") else ("villager_m" if SpriteChar._banks.has("villager_m") else "player")
	if groom_kind == "villager_m" and not SpriteChar._banks.has("villager_m") and FileAccess.file_exists("res://data/frames_npc.json"):
		SpriteChar.load_bank("villager_m", "frames_npc.json")
	wait_kind = "ride_horse" if SpriteChar._banks.has("ride_horse") else (coats[0] if not coats.is_empty() else "")
	root = Node3D.new(); root.name = "station_life"
	main.scene_vp.add_child(root)
	print("STATION life space=%s stations=%d coats=%s pony=%s groom=%s" % [sid, list.size(), coats, pony_coats, groom_kind])

func enabled() -> bool: return not list.is_empty() and root != null

# 이 자리(문 앞 25m 안)의 역 — 말 타기는 마부가 끌어 온다
func near(pp: Vector2, r := 25.0) -> Dictionary:
	for s in list:
		if pp.distance_to(Vector2(float(s.yard[0]), float(s.yard[1]))) < r: return s
	return {}

# 플레이어가 칸 말을 볼 만큼 마방 앞에 있나 — region_main이 화면 위쪽 틸트시프트 흐림을 줄인다
# (칸 말은 화면 위쪽 흐림 띠에 걸려 뒷벽과 섞이며 반투명처럼 보였다 — 가림 점무늬(--nodither)와는 무관, --notilt로 확인)
func stable_view(pp: Vector3, r := 22.0) -> bool:
	for id in live:
		var L: Dictionary = live[id]
		for h in L.stalls:
			if Vector2(h.p.x - pp.x, h.p.z - pp.z).length() < r: return true
	return false

# ---------------------------------------------------------------- 매 프레임
func update(dt: float) -> void:
	if not enabled(): return
	_chk -= dt
	if _chk <= 0.0:
		_chk = 0.5
		var pp := Vector2(main.player_pos.x, main.player_pos.z)
		for s in list:
			var c := Vector2(float(s.pos[0]), float(s.pos[1]))
			var d := pp.distance_to(c)
			if d < NEAR and not live.has(s.id) and not main._loading: _spawn(s)
			elif d > FAR and live.has(s.id): _despawn(String(s.id))
	for id in live: _tick(live[id], dt)

func _y(p: Vector3, lift := 0.0) -> Vector3:
	return Vector3(p.x, world.height_at(p.x, p.z) + lift, p.z)

func _face(ch: SpriteChar, dir: Vector2) -> void:
	ch.facing = main.facing_cam(dir.x, dir.y, ch.facing)

# ---------------------------------------------------------------- 만들기
func _spawn(s: Dictionary) -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = hash(String(s.id))
	var pony := bool(s.get("pony", false))
	var cs: Array = pony_coats if pony else coats
	if cs.is_empty(): return
	var params := { hub = bool(s.get("hub", false)), style = String(s.get("style", "honam")) }
	var P: Dictionary = Mabang.plan(params)
	var HP: Dictionary = Hitch.plan({})
	var L := { st = s, P = P, HP = HP, stalls = [], pads = [], node = Node3D.new(), lent = false, lent_t = 0.0, rng = rng }
	L.node.name = "st_" + String(s.id)
	root.add_child(L.node)
	var ry := float(s.get("ry", 0.0))
	var front := Vector2(sin(ry), cos(ry))     # 마구간 정면(로컬 +z)
	# 칸 말: 한 칸은 비워 둔다(나간 역마)
	var n: int = P.stalls.size()
	var empty := rng.randi_range(0, n - 1)
	for i in n:
		if i == empty: continue
		var ch := _char(cs[rng.randi_range(0, cs.size() - 1)], L.node)
		var p: Vector3 = Stations.to_world(s, P.stalls[i])
		ch.position = _y(p, FLOOR)
		_face(ch, front)
		# 3/4 앞모습(tools/export_stable_frames.js drawQ3): 머리 왼쪽(eat·idle)·오른쪽(eatR·idleR)을 칸마다 번갈아 — 줄지은 말이 한 도장처럼 보이지 않게
		var right: bool = (i % 2 == 1) != (rng.randf() < 0.2)
		var suf := "R" if right and ch.has_anim("eatR") else ""
		var a := "eat" if rng.randf() < 0.7 else "idle"
		ch.set_anim(a + suf); ch.anim_time = rng.randf() * 3.0; ch.t = rng.randf() * 5.0
		L.stalls.append({ ch = ch, p = p, t = rng.randf_range(3.0, 9.0), suf = suf })
	# 마당 말(조랑말은 셋)
	var np := 3 if pony else 2
	for i in np:
		var ch := _char(cs[rng.randi_range(0, cs.size() - 1)], L.node)
		var p: Vector3 = Stations.to_world(s, P.pads[i % P.pads.size()])
		ch.position = _y(p)
		_face(ch, Vector2(-1 if i % 2 == 0 else 1, 0))
		ch.set_anim("graze" if ch.has_anim("graze") else "idle"); ch.t = rng.randf() * 4.0
		L.pads.append({ ch = ch, mode = "graze", t = rng.randf_range(5.0, 12.0), to = p })
	# 기다리는 말(안장)
	if wait_kind != "":
		var w := _char(wait_kind, L.node)
		w.position = _y(Stations.hitch_world(s, HP.wait))
		_face(w, Vector2(-1, 0))
		w.set_anim("idle")
		L.wait = w
	# 마부
	var g := _char(groom_kind, L.node)
	g.position = _y(Stations.hitch_world(s, HP.brush))
	_face(g, Vector2(1, 0))
	L.groom = { ch = g, path = [], task = "", t = 0.0, queue = [], hay = _hay_node(L.node), led = false }
	L.groom.hay.visible = false
	_next_task(L)
	# 현판·깃발 글씨
	_labels(L)
	live[String(s.id)] = L
	stats.spawned = int(stats.spawned) + 1
	print("STATION spawn %s stalls=%d pads=%d" % [s.id, L.stalls.size(), L.pads.size()])

func _char(kind: String, parent: Node) -> SpriteChar:
	var ch := SpriteChar.new(kind)
	parent.add_child(ch)
	ch.set_silhouette(false)   # 구유·울타리 뒤로 가린 다리가 푸른 그림자(가려진 인물 표시)로 비치지 않게
	return ch

func _hay_node(parent: Node) -> Node3D:
	var m := C.M.new(3)
	var rng := Kit.Rng.new(5)
	m.add("p", "thatch", C.PA(Kit.xf(Kit.lump(0.28, 0, rng, 0.3, 0.55), 0, 0, 0, 0, 0, 0, 1.5, 1, 0.8), C.STRAW, 0.06, rng), 0.02)
	m.add("p", "thatch", C.PA(Kit.xf(Kit.cyl(0.1, 0.16, 0.7, 6), 0.15, 0.05, 0.05, 0, 0.4, 1.3), C.STRAW, 0.05, rng), 0.01)
	var nd := m.build_node("건초")
	parent.add_child(nd)
	return nd

func _labels(L: Dictionary) -> void:
	var s: Dictionary = L.st
	var f := Stations.font()
	var HP: Dictionary = L.HP
	var sg := Label3D.new()
	sg.text = String(s.get("sign", "驛"))
	sg.font = f
	sg.font_size = 96
	sg.pixel_size = 0.0034 if sg.text.length() > 3 else 0.0042
	sg.modulate = Color("#efe2c0")
	sg.outline_size = 0
	sg.double_sided = false
	sg.position = _y(Stations.hitch_world(s, HP.sign), float(HP.sign.y)) + Vector3(0, 0, 0.03)
	L.node.add_child(sg)
	var hub := bool(s.get("hub", false))
	var H := 6.8 if hub else 6.0
	var fl := Label3D.new()
	fl.text = "驛" if not bool(s.get("pony", false)) else "馬"
	fl.font = f
	fl.font_size = 128
	fl.pixel_size = 0.0068
	fl.modulate = Color("#8a2a20")
	fl.outline_size = 0
	var fp: Vector3 = HP.flag
	var at: Vector3 = Stations.hitch_world(s, Vector3(fp.x - 0.6 + 0.75, 0, fp.z))
	fl.position = Vector3(at.x, world.height_at(at.x, at.z) + H - 1.38, at.z + 0.16)   # 깃발 앞(깃발 조각이 앞뒤로 0.08 굽음)
	L.node.add_child(fl)
	var fl2 := fl.duplicate() as Label3D
	fl2.rotation.y = PI; fl2.position.z -= 0.32
	L.node.add_child(fl2)

func _despawn(id: String) -> void:
	var L: Dictionary = live[id]
	L.node.queue_free()
	live.erase(id)

# ---------------------------------------------------------------- 움직임
func _tick(L: Dictionary, dt: float) -> void:
	var cam: Camera3D = main.cam
	var rng: RandomNumberGenerator = L.rng
	for h in L.stalls:
		h.t -= dt
		if h.t <= 0.0:
			h.t = rng.randf_range(3.0, 10.0)
			h.ch.set_anim(("eat" if rng.randf() < 0.65 else "idle") + String(h.suf))
		h.ch.position = _y(h.p, FLOOR)
		h.ch.update_char(dt, cam)
	var s: Dictionary = L.st
	var P: Dictionary = L.P
	for h in L.pads:
		h.t -= dt
		match String(h.mode):
			"graze", "idle":
				if h.t <= 0.0:
					# 마당 안 다른 자리로 천천히
					var a: Vector3 = P.pad_min; var b: Vector3 = P.pad_max
					var loc := Vector3(rng.randf_range(a.x + 1.2, b.x - 1.2), 0, rng.randf_range(a.z + 1.2, b.z - 1.2))
					h.to = Stations.to_world(s, loc)
					h.mode = "walk"; h.ch.set_anim("walk")
			"walk":
				var p: Vector3 = h.ch.position
				var d := Vector2(h.to.x - p.x, h.to.z - p.z)
				if d.length() < 0.2:
					h.mode = "graze" if rng.randf() < 0.7 else "idle"
					h.t = rng.randf_range(6.0, 16.0)
					h.ch.set_anim("graze" if h.mode == "graze" and h.ch.has_anim("graze") else "idle")
				else:
					var step := d.normalized() * minf(PAD_WALK * dt, d.length())
					h.ch.position = Vector3(p.x + step.x, 0, p.z + step.y)
					_face(h.ch, d)
		h.ch.position = _y(h.ch.position)
		h.ch.update_char(dt, cam)
	if L.has("wait"):
		var w: SpriteChar = L.wait
		if bool(L.lent):
			# 손님이 탄 뒤: 플레이어가 멀어지면(40m) 마부가 새 말을 매어 둔다
			L.lent_t = float(L.lent_t) + dt
			var pp := Vector2(main.player_pos.x, main.player_pos.z)
			var horse_busy: bool = main.horse_ride != null and main.horse_ride.state == "MOUNTING"
			if not horse_busy and float(L.lent_t) > 6.0 and pp.distance_to(Vector2(w.position.x, w.position.z)) > 40.0:
				L.lent = false; w.visible = true
		w.visible = not bool(L.lent)
		w.position = _y(Stations.hitch_world(s, L.HP.wait))
		if w.visible: w.update_char(dt, cam)
	_tick_groom(L, dt)

func _next_task(L: Dictionary) -> void:
	var G: Dictionary = L.groom
	var rng: RandomNumberGenerator = L.rng
	if (G.queue as Array).is_empty(): G.queue = ["brush", "feed", "feed", "rest", "brush", "feed", "rest"]
	var task: String = G.queue.pop_front()
	var s: Dictionary = L.st
	var P: Dictionary = L.P
	var dest: Vector3
	match task:
		"brush": dest = Stations.hitch_world(s, L.HP.brush)
		"feed": dest = Stations.to_world(s, P.hay)
		_: dest = Stations.to_world(s, P.yard_in + Vector3(rng.randf_range(-2.0, 2.0), 0, rng.randf_range(-1.0, 1.0)))
	G.task = task
	G.stage = "go"
	G.path = _route(L, G.ch.position, dest)
	G.ch.set_anim("walk")

# 두 점 사이 길: 마방 터 안 ↔ 문 앞(바깥)이면 마방 문(터 가장자리)과 마당 가운데를 거친다
func _route(L: Dictionary, a: Vector3, b: Vector3) -> Array:
	var s: Dictionary = L.st
	var ina := _in_lot(s, a); var inb := _in_lot(s, b)
	if ina == inb: return [b]
	var gate := _gate(L)
	var yard_in: Vector3 = Stations.to_world(s, L.P.yard_in)
	return [yard_in, gate, b] if ina else [gate, yard_in, b]

func _in_lot(s: Dictionary, p: Vector3) -> bool:
	var ry := float(s.get("ry", 0.0))
	var dx := p.x - float(s.pos[0]); var dz := p.z - float(s.pos[1])
	var lx := dx * cos(ry) - dz * sin(ry); var lz := dx * sin(ry) + dz * cos(ry)
	return absf(lx) < Mabang.W / 2 and absf(lz) < Mabang.D / 2

# 마방 터 가장자리에서 문 앞(가로대)에 가장 가까운 자리(바깥 1.5m)
func _gate(L: Dictionary) -> Vector3:
	var s: Dictionary = L.st
	var ry := float(s.get("ry", 0.0))
	var h := Stations.hitch_world(s, Vector3.ZERO)
	var dx := h.x - float(s.pos[0]); var dz := h.z - float(s.pos[1])
	var lx := dx * cos(ry) - dz * sin(ry); var lz := dx * sin(ry) + dz * cos(ry)
	var hw := Mabang.W / 2 + 1.5; var hd := Mabang.D / 2 + 1.5
	if absf(lx) / hw > absf(lz) / hd: lx = signf(lx) * hw; lz = clampf(lz, -hd + 3.0, hd - 3.0)
	else: lz = signf(lz) * hd; lx = clampf(lx, -hw + 3.0, hw - 3.0)
	return Stations.to_world(s, Vector3(lx, 0, lz))

func _tick_groom(L: Dictionary, dt: float) -> void:
	var G: Dictionary = L.groom
	var ch: SpriteChar = G.ch
	var cam: Camera3D = main.cam
	var rng: RandomNumberGenerator = L.rng
	var s: Dictionary = L.st
	if bool(G.led):
		ch.position = _y(ch.position)
		ch.update_char(dt, cam)
		_carry(G, cam)
		return
	if not (G.path as Array).is_empty():
		var to: Vector3 = G.path[0]
		var p := ch.position
		var d := Vector2(to.x - p.x, to.z - p.z)
		if d.length() < 0.15:
			G.path.pop_front()
		else:
			var step := d.normalized() * minf(WALK * dt, d.length())
			ch.position = Vector3(p.x + step.x, 0, p.z + step.y)
			_face(ch, d)
			ch.set_anim("walk")
		ch.position = _y(ch.position)
		ch.update_char(dt, cam)
		_carry(G, cam)
		if (G.path as Array).is_empty(): _arrive_task(L)
		return
	G.t = float(G.t) - dt
	if float(G.t) <= 0.0: _arrive_done(L)
	ch.position = _y(ch.position)
	ch.update_char(dt, cam)
	_carry(G, cam)

# 걸어 닿았을 때: 일 시작
func _arrive_task(L: Dictionary) -> void:
	var G: Dictionary = L.groom
	var ch: SpriteChar = G.ch
	var rng: RandomNumberGenerator = L.rng
	match String(G.task):
		"brush":
			if bool(L.lent): G.t = 0.5; ch.set_anim("idle"); return
			_face(ch, Vector2(1, 0))
			ch.set_anim("brush" if ch.has_anim("brush") else "idle")
			G.t = rng.randf_range(6.0, 9.0)
		"feed":
			if String(G.stage) == "go":
				ch.set_anim("idle"); G.t = 1.2; G.stage = "pick"
			else:
				_face(ch, Vector2(-1, 0))
				ch.set_anim("feed" if ch.has_anim("feed") else "idle")
				G.t = 3.2
		_:
			ch.set_anim("idle"); G.t = rng.randf_range(3.0, 6.0)

# 일을 마쳤을 때: 다음 단계·다음 일
func _arrive_done(L: Dictionary) -> void:
	var G: Dictionary = L.groom
	var s: Dictionary = L.st
	if String(G.task) == "feed":
		if String(G.stage) == "pick":
			# 건초를 안고 구유 앞(빈 칸이 아닌 칸)으로
			G.hay.visible = true
			G.stage = "carry"
			var i: int = L.rng.randi_range(0, L.P.feed.size() - 1)
			G.path = _route(L, G.ch.position, Stations.to_world(s, L.P.feed[i]))
			G.ch.set_anim("walk")
			return
		if String(G.stage) == "carry":
			G.hay.visible = false
			# 그 칸 말이 먹기 시작
			for h in L.stalls:
				if Vector2(h.p.x, h.p.z).distance_to(Vector2(G.ch.position.x, G.ch.position.z)) < 2.2:
					h.ch.set_anim("eat" + String(h.suf)); h.t = 8.0
	_next_task(L)

func _carry(G: Dictionary, cam: Camera3D) -> void:
	var hay: Node3D = G.hay
	if not hay.visible: return
	var p: Vector3 = G.ch.position
	var tc := cam.global_position - p; tc.y = 0.0
	tc = tc.normalized() if tc.length() > 0.01 else Vector3.BACK
	hay.position = p + Vector3(0, 1.0, 0) + tc * 0.3

# ---------------------------------------------------------------- 말 타기(horse_ride)
# 마부가 기다리는 말을 끌고 나온다: 반환 기다리는 말 자리(없으면 Vector3.INF)
func lend(s: Dictionary) -> Vector3:
	if not live.has(String(s.id)): _spawn(s)
	if not live.has(String(s.id)): return Vector3.INF
	var L: Dictionary = live[String(s.id)]
	L.lent = true; L.lent_t = 0.0
	if L.has("wait"): L.wait.visible = false
	var G: Dictionary = L.groom
	G.led = true; G.path = []; G.hay.visible = false
	return Stations.hitch_world(s, L.HP.wait)

# 끄는 동안 매 프레임: 마부는 말 머리 곁(카메라 쪽)에서 같이 걷는다
func lead(s: Dictionary, horse_pos: Vector3, dir: Vector2, walking: bool) -> void:
	if not live.has(String(s.id)): return
	var G: Dictionary = live[String(s.id)].groom
	var h := dir.normalized() if dir.length() > 0.01 else Vector2(-1, 0)
	var side := Vector2(-h.y, h.x)
	var tc := Vector2(main.cam.global_position.x - horse_pos.x, main.cam.global_position.z - horse_pos.z)
	if side.dot(tc) < 0.0: side = -side
	var q := Vector2(horse_pos.x, horse_pos.z) + h * 1.3 + side * 0.9
	G.ch.position = Vector3(q.x, 0, q.y)
	_face(G.ch, h if walking else -side)
	G.ch.set_anim("walk" if walking else "idle")

# 손님이 올라탔다: 마부는 문 앞으로 돌아가 일을 잇는다
func release(s: Dictionary) -> void:
	if not live.has(String(s.id)): return
	var L: Dictionary = live[String(s.id)]
	var G: Dictionary = L.groom
	G.led = false
	G.queue = ["rest", "feed", "brush"]
	_next_task(L)
