# 배 타기 — 나루 건너기(region_world.ferries: 한강·대동강 나루, 제주 바다 뱃길)와 강 뱃길(river_lanes.lanes: 한강·대동강 수운,
# 장산곶 바위섬 뱃길)을 한 방식으로 탄다. 플레이어는 배를 몰지 않는다 — 사공이 젓고 배가 저절로 간다.
#   - 나루·선창 끝(뭍 쪽 내릴 자리) BOARD_R 안에서 E: 배에 오른다(나루: 건너간다). 이야기 gate가 거절하면 HUD로 사유만.
#   - 탄 동안 플레이어 입력은 막힌다(지도 M·기록책 R은 그대로). 플레이어는 갑판에 앉고(frames_boat.json sit — 없으면 대기),
#     사공(boatman_row: row 노 젓기 / pole 삿대 — 없으면 ambient boatman 대기)이 고물에 서서 젓는다.
#   - 떠남(0.9초) → 뱃길을 따라 가속·감속 → 닿음(0.5초) → 건너편 내릴 자리에 내려선다. Space(또는 E 누르고 있기): 건너뛰기(빨리 감기).
#   - 물 위 걷기 면은 없다(뱃길이 길). 강 뱃길 선창 잔교 위만 걷기 면(river_lanes)이 남는다. 배는 걷기 충돌을 보지 않는다.
#   - 옛 방식 호환: 플레이어가 (스크립트로) 뱃길 물 위에 놓이면 가까운 끝에서 저절로 탄다. 타는 중 이야기가 플레이어를 다른 데로
#     옮기면(teleport) 그 자리에서 내린 것으로 친다(배는 떠난 선창으로 돌아가 묶인다).
# API (region_main.boats):
#   board(id, from_end := -1, scripted := false) -> bool   id = crossings id(나루) 또는 river_lanes id.
#       from_end 0=처음 끝, 1=끝 끝, -1=플레이어 쪽. 플레이어를 그 끝 배에 앉히고 떠난다(어디 있든).
#       scripted: 이야기 컷신 안에서 태울 때 — 이야기가 플레이어를 쥐고 있어도 멈추지 않고 gate도 보지 않는다.
#       이야기에서: if main.boats.board("rt_jangsan_islet_lane", 0, true): await main.boats.arrived
#   riding() -> bool · ride_id() -> String · cancel() · route(id) -> Dictionary
#   gate: Callable(id: String, dir: int) -> String   "" = 탐, 아니면 거절 사유(HUD)
#   signal boarded(id, dir) · signal arrived(id, place_name) · signal left(id)   (left: 도착 전에 내림 — 취소·이야기 teleport)
#   region_world.ferry_auto(p) · river_lanes.auto(p)은 예전 꼴({dir, speed, name, start, to})로 지금 타는 배를 돌려준다(읽기만).
extends RefCounted

signal boarded(id: String, dir: int)
signal arrived(id: String, place_name: String)
signal left(id: String)

const BOARD_R := 5.0
const FERRY_SPEED := 5.5
const SKIP_MULT := 8.0
const SKIP_MAX := 40.0
const T_BOARD := 0.9
const T_DOCK := 0.5

var main
var world
var lanes
var routes: Array = []
var ride := {}            # {r, dir, s0, s1, v, t, phase, seat}
var gate = null           # Callable 또는 null
var speed_override := 0.0
var prompt := ""          # 지금 띄울 안내(없으면 "")
var near = null           # {r, end} — 플레이어가 내릴 자리 곁이면
var skipping := false
var _man_kind := ""
var _side := 1.0
var _side_t := 0.0
var _hud := ""
var _legacy_start := false

func setup(m) -> void:
	main = m; world = m.world; lanes = m.lanes
	SpriteChar.merge_bank("frames_boat.json")
	if SpriteChar._banks.has("boatman_row"): _man_kind = "boatman_row"
	else:
		if FileAccess.file_exists("res://data/frames_amb.json"): SpriteChar.load_bank("boatman", "frames_amb.json")
		if SpriteChar._banks.has("boatman"): _man_kind = "boatman"
	for f in world.ferries:
		var kit := String(f.get("kit", "village/narutbae"))
		var pts := PackedVector2Array([f.a, f.b])
		_add({ id = String(f.id), name = String(f.name), kind = "ferry", sea = bool(f.get("sea", false)), pts = pts, boat = f.boat, kit = kit,
			blen = 6.4 if kit.contains("narutbae") else 9.0, speed = 9.0 if f.get("sea", false) else FERRY_SPEED, slow = [],
			names = [String(f.name), String(f.name)], pier = [0.0, 0.0], src = f })
	if lanes != null:
		for f in lanes.lanes:
			var kit := String(f.get("kit", "route/dotbae"))
			_add({ id = String(f.id), name = String(f.name), kind = "lane", sea = not world.sea_is_river, pts = f.pts, boat = f.boat, kit = kit,
				blen = float(f.get("blen", 6.4 if kit.contains("narutbae") else 9.0)), speed = float(f.speed), slow = f.slow,
				names = [String(f.from_name), String(f.to_name)], pier = f.get("pier", [4.0, 4.0]), src = f })
	world.boat_ride = self
	if lanes != null: lanes.boat_ride = self
	if not routes.is_empty():
		print("BOATS %s man=%s" % [routes.map(func(r): return "%s(%s %.0fm)" % [r.id, r.kind, r.len]), _man_kind])

func _add(r: Dictionary) -> void:
	r.cum = _cum(r.pts); r.len = r.cum[r.cum.size() - 1]
	if r.len < 4.0: return
	# 나루: 데이터 끝점이 둑 안쪽(뭍)까지 들어가 있으면 물이 시작하는 곳까지 줄인다(배가 뭍 위로 가지 않게)
	if r.kind == "ferry":
		var sa := -1.0; var sb := -1.0
		var s := 0.0
		while s <= r.len:
			var q := _at(r.pts, r.cum, s)
			if world.ground_at(q.x, q.y) < world.sea_y - 0.15:
				if sa < 0.0: sa = s
				sb = s
			s += 1.0
		if sa >= 0.0 and sb - sa > 8.0:
			var a2 := _at(r.pts, r.cum, maxf(0.0, sa - 1.0)); var b2 := _at(r.pts, r.cum, minf(r.len, sb + 1.0))
			if sa > 2.0 or sb < r.len - 2.0: print("BOATS %s 뱃길을 물까지 줄임 %.0f~%.0f / %.0fm" % [r.id, sa, sb, r.len])
			r.pts = PackedVector2Array([a2, b2]); r.cum = _cum(r.pts); r.len = r.cum[1]
	# 뱃길 가운데 뭍(섬·모래톱)을 지나면: 나루는 물길로 돌아가는 길을 찾는다(_water_path), 강 뱃길은 데이터 점검용 경고만
	var dry := _dry_count(r)
	if dry > 0 and r.kind == "ferry":
		var o0: Vector2 = (r.pts[0] - r.pts[1]).normalized()
		var wp := _water_path(r.pts[0], r.pts[r.pts.size() - 1])
		if wp.size() >= 2:
			r.out_fix = [o0, -o0]
			r.pts = wp; r.cum = _cum(wp); r.len = r.cum[r.cum.size() - 1]
			var d2 := _dry_count(r)
			print("BOATS %s 뭍 %d곳 → 물길로 돌아감 %d점 %.0fm(남은 뭍 %d)" % [r.id, dry, wp.size(), r.len, d2])
			dry = d2
	if dry > 0: print("BOATS warn %s 뱃길 위 뭍 %d곳(4m 간격) — 배는 그대로 지나간다(걷기 충돌 없음)" % [r.id, dry])
	r.narut = String(r.kit).contains("narutbae")
	r.half = minf(r.blen * 0.5 + 0.4, r.len * 0.5)
	# 배 앞쪽(이물) 기준 좌표: 플레이어 자리·사공 자리(고물), 갑판 높이(키트마다)
	if r.narut:
		r.deck = 0.02; r.seat = 0.1; r.stern = -(r.blen * 0.5 * 0.67); r.man_y = -0.09
	else:
		r.deck = 0.36; r.seat = r.blen * 0.24; r.stern = -(r.blen * 0.5 * 0.86); r.man_y = 0.33
	r.motion = "row" if (r.sea or not r.narut) else "pole"
	# 끝마다 바깥(뭍 쪽) 방향과 내릴 자리
	var n: int = r.pts.size()
	var o0: Vector2 = (r.pts[0] - r.pts[1]).normalized(); var o1: Vector2 = (r.pts[n - 1] - r.pts[n - 2]).normalized()
	r.out = r.get("out_fix", [o0, o1])
	r.land = [_land(r, 0), _land(r, 1)]
	r.s = r.half; r.hdir = 1
	var lo := Vector2(INF, INF); var hi := Vector2(-INF, -INF)
	for p in r.pts: lo = lo.min(p); hi = hi.max(p)
	r.bb = Rect2(lo - Vector2(30, 30), hi - lo + Vector2(60, 60))
	r.man = null
	routes.append(r)
	_place(r, 0.0)

# 내릴 자리: 강 뱃길은 선창 잔교 위(끝에서 뭍 쪽 1~2m — 잔교 걷기 면), 나루는 뭍(물 면 위 땅)이 나올 때까지 바깥으로
func _land(r: Dictionary, e: int) -> Vector2:
	var end: Vector2 = r.pts[0] if e == 0 else r.pts[r.pts.size() - 1]
	var o: Vector2 = r.out[e]
	if r.kind == "lane":
		return end + o * clampf(float(r.pier[e]) * 0.5 + 0.5, 1.0, 2.0)
	for k in 40:
		var p := end + o * (1.0 + k)
		if world.ground_at(p.x, p.y) > world.sea_y + 0.08 and not world.blocked(p.x, p.y, 0.4): return p + o * 1.0
	return end + o * 3.0

func route(id: String) -> Dictionary:
	for r in routes:
		if r.id == id: return r
	return {}

func riding() -> bool: return not ride.is_empty()
func ride_id() -> String: return String(ride.r.id) if riding() else ""

# 지금 타는 배(예전 ferry_auto·lanes.auto 꼴). kind: "ferry"·"lane"·""(아무거나)
func legacy(kind: String) -> Dictionary:
	if not riding() or (kind != "" and ride.r.kind != kind): return {}
	var r: Dictionary = ride.r
	var h := _tangent(r, ride.s) * float(ride.dir)
	var st := _legacy_start; _legacy_start = false
	return { dir = h, speed = float(ride.v), name = String(r.name), start = st, id = String(r.id),
		to = (String(r.names[1]) if ride.dir > 0 else String(r.names[0])) if r.kind == "lane" else ("b" if ride.dir > 0 else "a") }

func take_hud() -> String:
	var h := _hud; _hud = ""; return h

# ---- 타기 ----
func board(id: String, from_end := -1, scripted := false) -> bool:
	if riding(): return false
	var r := route(id)
	if r.is_empty(): return false
	var pp := Vector2(main.player_pos.x, main.player_pos.z)
	var e := from_end
	if e < 0: e = 0 if pp.distance_to(r.land[0]) <= pp.distance_to(r.land[1]) else 1
	var dir := 1 if e == 0 else -1
	if not scripted and gate is Callable and (gate as Callable).is_valid():
		var why = (gate as Callable).call(id, dir)
		if why is String and why != "":
			_hud = why; return false
	var s0: float = r.half if dir > 0 else r.len - r.half
	var s1: float = r.len - r.half if dir > 0 else r.half
	r.s = s0; r.hdir = dir
	ride = { r = r, dir = dir, s = s0, s1 = s1, v = 0.0, t = 0.0, phase = "board", seat = Vector3.INF, t0 = Time.get_ticks_msec() / 1000.0, scripted = scripted }
	_legacy_start = true
	_side_t = 0.0
	_ensure_man(r)
	main.player.set_anim("sit" if main.player.has_anim("sit") else "idle")
	_seat()
	_hud = "%s — %s" % ["배에 올랐다" if r.kind == "lane" else "나룻배에 올랐다", String(r.name)]
	print("SAIL start %s dir=%d s=%.0f/%.0f" % [r.id, dir, s0, r.len])
	boarded.emit(id, dir)
	return true

func cancel() -> void:
	if not riding(): return
	var r: Dictionary = ride.r
	print("SAIL leave %s t=%.1fs" % [r.id, Time.get_ticks_msec() / 1000.0 - float(ride.t0)])
	# 배는 떠난 선창으로 돌아가 묶인다
	r.s = r.half if ride.dir > 0 else r.len - r.half
	ride = {}
	_place(r, 0.0)
	if main.player.anim == "sit": main.player.set_anim("idle")
	left.emit(String(r.id))

# 플레이어가 (스크립트로) 뱃길 물 위에 놓였으면 그 배를 탄다 — 옛 방식(물 위로 걸어 오르면 auto) 호환
func _legacy_onboard(pp: Vector2) -> bool:
	if world.ground_at(pp.x, pp.y) >= world.sea_y + 0.1: return false
	for r in routes:
		if not r.bb.has_point(pp): continue
		var pr := _project(r, pp)
		if absf(pr.lat) < 2.4 and pr.s > 0.8 and pr.s < r.len - 0.8:
			return board(r.id, 0 if pr.s < r.len * 0.5 else 1)
	return false

# 매 프레임(region_main, 입력 처리 앞). want_board: 이번 프레임 E를 눌렀나. paused: 이야기가 플레이어를 쥐고 있음
func update(dt: float, want_board: bool, skip_held: bool, paused: bool) -> void:
	var pp := Vector2(main.player_pos.x, main.player_pos.z)
	skipping = false
	if riding():
		if ride.seat != Vector3.INF and main.player_pos.distance_to(ride.seat) > 3.0:
			cancel()   # 이야기가 옮겼다(teleport)
		elif not paused or ride.scripted:
			_advance(dt, skip_held)
	if not riding():
		pp = Vector2(main.player_pos.x, main.player_pos.z)   # 방금 내렸으면 내린 자리
		prompt = ""
		near = null
		if not paused and _legacy_onboard(pp): pass
		else:
			var bd := BOARD_R
			for r in routes:
				if not r.bb.has_point(pp): continue
				for e in 2:
					var d: float = pp.distance_to(r.land[e])
					if d < bd: bd = d; near = { r = r, end = e }
			if near != null:
				var r: Dictionary = near.r
				var to: String = String(r.names[1] if near.end == 0 else r.names[0])
				prompt = ("건너간다 — %s" % String(r.name)) if r.kind == "ferry" else ("배에 오른다 — %s까지" % to)
				if want_board and not paused: board(String(r.id), int(near.end))
	_idle_boats(dt, pp)

func _advance(dt: float, skip_held: bool) -> void:
	var r: Dictionary = ride.r
	ride.t += dt
	var mult := 1.0
	if skip_held:
		skipping = true
		mult = SKIP_MULT
	match String(ride.phase):
		"board":
			if ride.t >= T_BOARD / mult: ride.phase = "sail"; ride.t = 0.0
		"sail":
			var top: float = speed_override if speed_override > 0.0 else float(r.speed)
			for sl in r.slow:
				if ride.s >= float(sl[0]) and ride.s <= float(sl[1]): top *= float(sl[2])
			var remain: float = absf(float(ride.s1) - float(ride.s))
			var want := top * clampf(remain / 14.0, 0.18, 1.0)
			if skip_held: want = minf(want * mult, maxf(SKIP_MAX, top))
			# 노를 저어 서서히 붙는다(가속 2.5초)
			ride.v = move_toward(float(ride.v), want, maxf(top / 2.5, 4.0 if skip_held else 0.0) * dt * (mult if skip_held else 1.0))
			ride.s = float(ride.s) + float(ride.dir) * float(ride.v) * dt
			if (ride.dir > 0 and ride.s >= ride.s1 - 0.05) or (ride.dir < 0 and ride.s <= ride.s1 + 0.05):
				ride.s = ride.s1; ride.phase = "dock"; ride.t = 0.0; ride.v = 0.0
		"dock":
			if ride.t >= T_DOCK / mult:
				_arrive(); return
	r.s = ride.s
	_place(r, dt)
	_seat()

func _arrive() -> void:
	var r: Dictionary = ride.r
	var e := 1 if ride.dir > 0 else 0
	var dt := Time.get_ticks_msec() / 1000.0 - float(ride.t0)
	print("SAIL arrive %s t=%.1fs" % [r.id, dt])
	ride = {}
	var lp: Vector2 = r.land[e]
	main.player_pos = Vector3(lp.x, world.height_at(lp.x, lp.y), lp.y)
	main.player.position = main.player_pos
	main.player.set_anim("idle")
	var o: Vector2 = r.out[e]
	main.player.facing = main.facing_cam(o.x, o.y, main.player.facing) if main.has_method("facing_cam") else main.player.facing
	var place := String(r.names[e])
	if r.kind == "lane":
		var more := false
		for q in routes:
			if not is_same(q, r) and q.kind == "lane" and String(q.names[0]) == place: more = true
		_hud = ("%s에 닿았다 — 내려서 포구를 지나 다음 배에 오른다" % place) if more else ("%s에 닿았다" % place)
	else:
		_hud = "건너편에 닿았다 — %s" % String(r.name)
	arrived.emit(String(r.id), place)

# 플레이어·사공을 배 위 자리에
func _seat() -> void:
	var r: Dictionary = ride.r
	var xf: Transform3D = r.boat.transform if r.boat != null else Transform3D(Basis(), Vector3(0, world.sea_y, 0))
	var h := _tangent(r, r.s) * float(r.hdir)
	var c := _at(r.pts, r.cum, r.s)
	var p := c + h * float(r.seat)
	var y: float = xf.origin.y + float(r.deck)
	main.player_pos = Vector3(p.x, y, p.y)
	main.player.position = main.player_pos
	main.player.facing = main.facing_cam(h.x, h.y, main.player.facing) if main.has_method("facing_cam") else main.player.facing
	ride.seat = main.player_pos

func heading() -> Vector2:
	if not riding(): return Vector2.ZERO
	return _tangent(ride.r, ride.s) * float(ride.dir)

# 카메라가 볼 쪽(뱃길 왼쪽 +1 / 오른쪽 −1): 더 높은 기슭(능선) 쪽. 2초마다, 차이가 클 때만 바꾼다
func view_side(dt: float) -> float:
	if not riding(): return _side
	_side_t -= dt
	if _side_t > 0.0: return _side
	_side_t = 2.0
	var r: Dictionary = ride.r
	var h := heading()
	var n := Vector2(-h.y, h.x)
	var c := _at(r.pts, r.cum, ride.s) + h * 60.0
	var sc := [0.0, 0.0]
	for i in 2:
		var sg := 1.0 if i == 0 else -1.0
		for d in [70.0, 140.0, 240.0]:
			var q: Vector2 = c + n * sg * d
			sc[i] += maxf(world.height_at(q.x, q.y) - world.sea_y, 0.0)
	var want := 1.0 if sc[0] >= sc[1] else -1.0
	if want != _side and absf(sc[0] - sc[1]) > 6.0: _side = want
	return _side

# ---- 배 놓기 ----
func _place(r: Dictionary, _dt: float) -> void:
	var s: float = clampf(r.s, r.half, maxf(r.half, r.len - r.half))
	r.s = s
	var t := _tangent(r, s)
	var h: Vector2 = t * float(r.hdir)
	var p := _at(r.pts, r.cum, s)
	var tm := Time.get_ticks_msec() / 1000.0
	var ph := float(hash(r.id) & 255) * 0.05
	var bs := Basis(Vector3.UP, atan2(h.x, h.y) + (PI if r.narut else 0.0))
	var bob := 0.0
	if r.sea:
		bs = bs * Basis(Vector3(0, 0, 1), sin(tm * 0.9 + ph) * 0.035) * Basis(Vector3(1, 0, 0), sin(tm * 0.63 + 1.0 + ph) * 0.02)
		bob = sin(tm * 1.1 + ph) * 0.06
	else:
		bs = bs * Basis(Vector3(0, 0, 1), sin(tm * 0.7 + ph) * 0.015)
		bob = sin(tm * 1.0 + ph) * 0.025
	var xf := Transform3D(bs, Vector3(p.x, world.sea_y + 0.02 + bob, p.y))
	if r.boat != null: r.boat.transform = xf
	if r.man != null:
		var m: Vector2 = p + h * float(r.stern)
		r.man.position = Vector3(m.x, xf.origin.y + float(r.man_y), m.y)
		r.man.facing = main.facing_cam(h.x, h.y, r.man.facing) if main.has_method("facing_cam") else r.man.facing
		var moving: bool = riding() and is_same(ride.r, r) and String(ride.phase) != "board"
		var anim := String(r.motion) if moving and r.man.has_anim(String(r.motion)) else "idle"
		r.man.set_anim(anim)
		r.man.anim_speed = clampf(float(ride.v) / maxf(1.0, float(r.speed)), 0.6, 2.5) if moving else 1.0

func _ensure_man(r: Dictionary) -> void:
	if r.man != null or _man_kind == "": return
	var m := SpriteChar.new(_man_kind)
	m.name = "사공_" + String(r.id)
	main.scene_vp.add_child(m)
	r.man = m

# 묶여 있는 배(플레이어 250m 안): 물결에 흔들리고, 사공이 고물에 서 있다. 플레이어가 한쪽 끝 80m 안에 오는데 배가
# 반대편 멀리(150m 넘게) 있으면 사공이 저어 온 셈으로 그 끝에 옮겨 둔다(보이지 않는 거리에서만).
func _idle_boats(dt: float, pp: Vector2) -> void:
	for r in routes:
		var on: bool = riding() and is_same(ride.r, r)
		var inside: bool = r.bb.grow(220.0).has_point(pp)
		if not inside:
			if r.man != null: r.man.visible = false
			continue
		if not on:
			for e in 2:
				var se: float = r.half if e == 0 else r.len - r.half
				if pp.distance_to(r.land[e]) < 80.0 and absf(float(r.s) - se) > 150.0:
					r.s = se; r.hdir = 1 if e == 0 else -1
			_ensure_man(r)
			_place(r, dt)
		if r.man != null:
			r.man.visible = true
			r.man.update_char(dt, main.cam)

func _dry_count(r: Dictionary) -> int:
	var dry := 0; var ss := 6.0
	while ss < r.len - 6.0:
		var q := _at(r.pts, r.cum, ss)
		if world.ground_at(q.x, q.y) > world.sea_y - 0.05: dry += 1
		ss += 4.0
	return dry

# 물 칸(4m)만 지나는 길(AStarGrid2D, 물가 3칸 안은 무겁게) → 시선이 트이는 점만 남김 → 6m 간격. 못 찾으면 빈 배열
func _water_path(a: Vector2, b: Vector2) -> PackedVector2Array:
	var C := 4.0
	var lo := a.min(b) - Vector2(320, 320); var hi := a.max(b) + Vector2(320, 320)
	var w := int((hi.x - lo.x) / C) + 1; var h := int((hi.y - lo.y) / C) + 1
	var wet := PackedByteArray(); wet.resize(w * h)
	for j in h:
		for i in w:
			var q := lo + Vector2(i, j) * C
			wet[j * w + i] = 1 if world.ground_at(q.x, q.y) < world.sea_y - 0.25 else 0
	# 뭍에서 떨어진 칸 수(최대 4) — BFS
	var dist := PackedInt32Array(); dist.resize(w * h); dist.fill(99)
	var front: Array = []
	for k in w * h:
		if wet[k] == 0: dist[k] = 0; front.append(k)
	for step in 4:
		var nxt: Array = []
		for k in front:
			var i: int = k % w; var j: int = k / w
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var ii: int = i + d.x; var jj: int = j + d.y
				if ii < 0 or jj < 0 or ii >= w or jj >= h: continue
				var kk := jj * w + ii
				if dist[kk] > step + 1: dist[kk] = step + 1; nxt.append(kk)
		front = nxt
	var g := AStarGrid2D.new()
	g.region = Rect2i(0, 0, w, h); g.cell_size = Vector2(1, 1)
	g.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	g.update()
	for j in h:
		for i in w:
			var k := j * w + i
			if wet[k] == 0: g.set_point_solid(Vector2i(i, j), true)
			elif dist[k] < 4: g.set_point_weight_scale(Vector2i(i, j), 1.0 + (4 - dist[k]) * 2.5)
	var ca := _wet_cell(a, lo, C, w, h, wet); var cb := _wet_cell(b, lo, C, w, h, wet)
	if ca.x < 0 or cb.x < 0: return PackedVector2Array()
	var path := g.get_id_path(ca, cb)
	if path.is_empty(): return PackedVector2Array()
	var raw := PackedVector2Array([a])
	for c in path: raw.append(lo + Vector2(c) * C)
	raw.append(b)
	# 시선 줄이기: 물가 2칸 넘게 떨어진 칸만 지나면 곧게
	var out := PackedVector2Array([raw[0]])
	var i0 := 0
	while i0 < raw.size() - 1:
		var j := raw.size() - 1
		while j > i0 + 1 and not _clear(raw[i0], raw[j], lo, C, w, h, dist): j -= 1
		out.append(raw[j]); i0 = j
	return out

func _wet_cell(p: Vector2, lo: Vector2, C: float, w: int, h: int, wet: PackedByteArray) -> Vector2i:
	var c := Vector2i(roundi((p.x - lo.x) / C), roundi((p.y - lo.y) / C))
	for rad in 12:
		for dj in range(-rad, rad + 1):
			for di in range(-rad, rad + 1):
				var i := c.x + di; var j := c.y + dj
				if i >= 0 and j >= 0 and i < w and j < h and wet[j * w + i] == 1: return Vector2i(i, j)
	return Vector2i(-1, -1)

func _clear(p: Vector2, q: Vector2, lo: Vector2, C: float, w: int, h: int, dist: PackedInt32Array) -> bool:
	var n := int(p.distance_to(q) / 2.0) + 1
	for k in range(1, n):
		var x := p.lerp(q, float(k) / n)
		var i := roundi((x.x - lo.x) / C); var j := roundi((x.y - lo.y) / C)
		if i < 0 or j < 0 or i >= w or j >= h: return false
		# 양 끝 20m(물가 출발·닿기)는 물이기만 하면 된다
		var need := 1 if (x.distance_to(p) < 20.0 and k < 10) or x.distance_to(q) < 20.0 else 2
		if dist[j * w + i] < need: return false
	return true

# ---- 꺾은선 ----
func _project(r: Dictionary, p: Vector2) -> Dictionary:
	var pts: PackedVector2Array = r.pts; var cum: PackedFloat32Array = r.cum
	var best := INF; var bs := 0.0; var bl := 0.0
	for i in pts.size() - 1:
		var a := pts[i]; var ab := pts[i + 1] - a
		var l2 := ab.length_squared()
		if l2 < 1e-6: continue
		var tt := (p - a).dot(ab) / l2
		var tc := clampf(tt, 0.0 if i > 0 else -INF, 1.0 if i < pts.size() - 2 else INF)
		var q := a + ab * tc
		var dd := p.distance_squared_to(q)
		if dd < best:
			best = dd
			var l := sqrt(l2)
			bs = cum[i] + tc * l
			var dn := ab / l
			bl = (p - q).dot(Vector2(-dn.y, dn.x))
	return { s = bs, lat = bl }

func _tangent(r: Dictionary, s: float) -> Vector2:
	var L: float = r.len
	var a := _at(r.pts, r.cum, clampf(s - 5.0, 0.0, L)); var b := _at(r.pts, r.cum, clampf(s + 5.0, 0.0, L))
	var d := b - a
	if d.length() < 0.01: d = r.pts[r.pts.size() - 1] - r.pts[0]
	return d.normalized()

static func _at(pts: PackedVector2Array, cum: PackedFloat32Array, s: float) -> Vector2:
	if s <= 0.0: return pts[0]
	var n := pts.size()
	if s >= cum[n - 1]: return pts[n - 1]
	var i := clampi(cum.bsearch(s) - 1, 0, n - 2)
	var l := cum[i + 1] - cum[i]
	return pts[i].lerp(pts[i + 1], (s - cum[i]) / maxf(l, 1e-6))

static func _cum(pts: PackedVector2Array) -> PackedFloat32Array:
	var cum := PackedFloat32Array([0.0])
	for i in range(1, pts.size()): cum.append(cum[i - 1] + pts[i].distance_to(pts[i - 1]))
	return cum
