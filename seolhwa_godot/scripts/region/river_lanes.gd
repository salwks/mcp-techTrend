# 강 뱃길(route.json river_lanes · river_traffic) — 한강·남한강, 대동강 수운 노정(tools/region/river_routes.py).
# 제주 바다 뱃길(region_world ferry_auto)과 같은 방식을 꺾은선으로 넓힌 것:
#   - 뱃길(포구 선창 → 다음 포구 선창) 꺾은선. 걷기 면은 양 끝 선창 잔교 위(뭍 쪽 선창 길이 + 2m ~ 선창 끝 +0.5m)만 깐다 —
#     물 위로 걸어 나가지 않는다. 배는 사공이 저어 간다(scripts/region/boat_ride.gd — 선창 끝에서 E로 오르면 다음 포구 선창까지).
#     포구에서 내려 포구를 지나 다음 선창 배에 오르면 이어 간다. 끝 선창에서 타면 되돌아간다. 여울(slow)에서는 느려진다.
#   - 돛배 한 척이 뱃길마다 묶여 있다(boat_ride가 옮긴다).
#   - river_traffic: 뗏목·세곡선·장삿배가 물길을 따라 오르내린다(그림만, 충돌 없음).
# region_main: setup(world) → BoatRide.setup → 매 프레임 update(dt, player)(떠가는 배). auto(player)는 예전 꼴의 읽기 전용(지금 타는 배).
extends RefCounted

const HW := 1.9            # 뱃길 반폭(region_world FERRY_HW와 같음)
const DECK := 0.32         # 물 면 위 갑판 높이(region_world FERRY_DECK와 같음)
const SEG := 14.0          # 걷기 면 마디 길이(m)
const SAIL_SPEED := 7.5

var world
var lanes: Array = []      # [{id, name, from_name, to_name, pts, cum, len, boat, half, s, sail, last, speed, slow, bb, t0}]
var traffic: Array = []    # [{node, pts, cum, len, s, speed}]
var speed_override := 0.0  # --sailspeed(시험)
var _hud := ""

func setup(w) -> void:
	world = w
	if is_nan(w.sea_y): return
	var region: Dictionary = w.region
	for L in region.get("river_lanes", []):
		var raw := _pts(L.get("points", []))
		# 선창 쪽 첫·끝 마디는 원래 선의 첫·끝 16m 그대로(선창과 한 줄 — 늘린 걷기 면이 선창 위에 오게), 가운데는 SEG 간격
		var pts := PackedVector2Array()
		if raw.size() >= 2:
			var rc := _cum(raw); var RL := rc[rc.size() - 1]
			pts.append(raw[0])
			var m := maxi(1, ceili((RL - 32.0) / SEG))
			for k in m + 1: pts.append(_at(raw, rc, 16.0 + (RL - 32.0) * k / m))
			pts.append(raw[raw.size() - 1])
		if pts.size() < 2: continue
		var cum := _cum(pts)
		var pier: Array = L.get("pier", [4.0, 4.0])
		# 걷기 면: 양 끝 선창 잔교만(뭍 쪽 선창 길이 + 2m ~ 선창 끝 + 0.5m). 물 위 뱃길은 걷지 않는다(배를 탄다)
		for e in 2:
			var tip := pts[0] if e == 0 else pts[pts.size() - 1]
			var nx := pts[1] if e == 0 else pts[pts.size() - 2]
			var d := (nx - tip).normalized()   # 물 쪽
			var back := float(pier[e]) + 2.0
			var mid := tip + d * (0.5 - back) * 0.5
			var l := back + 0.5
			var xf := Transform3D(Basis(Vector3.UP, atan2(d.x, d.y)), Vector3(mid.x, w.sea_y, mid.y))
			w.add_walk(xf, { minX = -HW, maxX = HW, minZ = -l * 0.5, maxZ = l * 0.5, z = [-l * 0.5, l * 0.5], y = [DECK, DECK] })
		var lo := Vector2(INF, INF); var hi := Vector2(-INF, -INF)
		for p in pts: lo = lo.min(p); hi = hi.max(p)
		var f := { id = String(L.get("id", "")), name = String(L.get("name", "뱃길")), from_name = String(L.get("from_name", "")), to_name = String(L.get("to_name", "")),
			pts = pts, cum = cum, len = cum[cum.size() - 1], boat = null, half = 5.0, s = 0.0, sail = 0, last = 1, t0 = 0.0, pier = pier,
			kit = String(L.get("boat_kit", "route/dotbae")),
			speed = float(L.get("speed", SAIL_SPEED)), slow = L.get("slow", []), bb = Rect2(lo - Vector2(8, 8), hi - lo + Vector2(16, 16)) }
		var bp: Dictionary = L.get("boat_params", {}) if L.get("boat_params") is Dictionary else {}
		var node := _kit(String(L.get("boat_kit", "route/dotbae")), bp, hash(f.id) & 0xffff)
		if node != null:
			node.name = "뱃길배_" + f.id
			w.water_root.add_child(node)
			f.boat = node
			f.blen = float(bp.get("len", 6.4 if f.kit.contains("narutbae") else 9.0))
			f.half = f.blen * 0.5 + 0.4
		lanes.append(f)
		_place(f, f.half, 0.0, 1)
	for T in region.get("river_traffic", []):
		var pts := _resample(_pts(T.get("points", [])), 8.0)
		if pts.size() < 2: continue
		var node := _kit(String(T.get("kit", "route/dotbae")), T.get("params", {}) if T.get("params") is Dictionary else {}, 77)
		if node == null: continue
		node.name = "떠가는배_" + String(T.get("id", ""))
		w.water_root.add_child(node)
		var cum := _cum(pts)
		traffic.append({ node = node, pts = pts, cum = cum, len = cum[cum.size() - 1], s = float(T.get("phase", 0.0)) * cum[cum.size() - 1],
			speed = float(T.get("speed", 2.0)), ph = randf() * TAU })
	if not lanes.is_empty():
		print("RIVER lanes=%s traffic=%d" % [lanes.map(func(f): return "%s(%.0fm)" % [f.id, f.len]), traffic.size()])

# 예전 API(읽기 전용): 지금 강 뱃길 배를 타고 있으면 {dir, speed, name, start, to, id}, 아니면 {} — 배는 boat_ride.gd가 몬다
var boat_ride = null
func auto(_player: Vector3) -> Dictionary:
	return boat_ride.legacy("lane") if boat_ride != null else {}

func take_hud() -> String:
	var h := _hud; _hud = ""; return h

func update(dt: float, _player: Vector3) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	for tr in traffic:
		tr.s = fposmod(float(tr.s) + float(tr.speed) * dt, float(tr.len))
		var p := _at(tr.pts, tr.cum, tr.s)
		var h := _tan_pts(tr.pts, tr.cum, tr.s, tr.len) * signf(float(tr.speed))
		var bs := Basis(Vector3.UP, atan2(h.x, h.y)) * Basis(Vector3(0, 0, 1), sin(t * 0.8 + float(tr.ph)) * 0.025)
		tr.node.transform = Transform3D(bs, Vector3(p.x, world.sea_y + 0.02 + sin(t * 1.1 + float(tr.ph)) * 0.05, p.y))

func _place(f: Dictionary, s: float, lat: float, dir: int) -> void:
	f.s = clampf(s, f.half, maxf(f.half, f.len - f.half))
	if f.boat == null: return
	var t := _tangent(f, f.s)
	var p: Vector2 = _at(f.pts, f.cum, f.s) + Vector2(-t.y, t.x) * clampf(lat, -0.6, 0.6)
	var h: Vector2 = t * float(dir if dir != 0 else 1)
	var tm := Time.get_ticks_msec() / 1000.0
	var bs := Basis(Vector3.UP, atan2(h.x, h.y)) * Basis(Vector3(0, 0, 1), sin(tm * 0.7) * 0.02)
	f.boat.transform = Transform3D(bs, Vector3(p.x, world.sea_y + 0.02 + sin(tm * 1.0) * 0.03, p.y))

# 꺾은선 위 가장 가까운 자리: {s(길이), lat(왼쪽 +)}
func _project(f: Dictionary, p: Vector2) -> Dictionary:
	var pts: PackedVector2Array = f.pts; var cum: PackedFloat32Array = f.cum
	var best := INF; var bs := 0.0; var bl := 0.0
	for i in pts.size() - 1:
		var a := pts[i]; var ab := pts[i + 1] - a
		var l2 := ab.length_squared()
		if l2 < 1e-6: continue
		var tt := (p - a).dot(ab) / l2
		# 양 끝 마디는 밖으로도 늘려 잰다(선창 쪽 s < 0, s > len)
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

func _tangent(f: Dictionary, s: float) -> Vector2:
	return _tan_pts(f.pts, f.cum, s, f.len)

static func _tan_pts(pts: PackedVector2Array, cum: PackedFloat32Array, s: float, L: float) -> Vector2:
	var a := _at(pts, cum, clampf(s - 5.0, 0.0, L)); var b := _at(pts, cum, clampf(s + 5.0, 0.0, L))
	var d := b - a
	if d.length() < 0.01: d = pts[pts.size() - 1] - pts[0]
	return d.normalized()

static func _at(pts: PackedVector2Array, cum: PackedFloat32Array, s: float) -> Vector2:
	if s <= 0.0: return pts[0]
	var n := pts.size()
	if s >= cum[n - 1]: return pts[n - 1]
	var i := cum.bsearch(s) - 1
	i = clampi(i, 0, n - 2)
	var l := cum[i + 1] - cum[i]
	return pts[i].lerp(pts[i + 1], (s - cum[i]) / maxf(l, 1e-6))

static func _pts(a: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in a: out.append(Vector2(float(p[0]), float(p[1])))
	return out

static func _cum(pts: PackedVector2Array) -> PackedFloat32Array:
	var cum := PackedFloat32Array([0.0])
	for i in range(1, pts.size()): cum.append(cum[i - 1] + pts[i].distance_to(pts[i - 1]))
	return cum

static func _resample(pts: PackedVector2Array, step: float) -> PackedVector2Array:
	if pts.size() < 2: return pts
	var cum := _cum(pts)
	var L := cum[cum.size() - 1]
	var n := maxi(1, ceili(L / step))
	var out := PackedVector2Array()
	for k in n + 1: out.append(_at(pts, cum, L * k / n))
	return out

static func _kit(path: String, params: Dictionary, seed: int) -> Node3D:
	var p := "res://kit/%s.gd" % path
	if not FileAccess.file_exists(p): return null
	var scr = load(p)
	if not (scr is GDScript) or not scr.can_instantiate(): return null
	var pr := params.duplicate(); pr["seed"] = int(pr.get("seed", seed))
	var info = scr.build(pr)
	if info is Dictionary and info.get("node") is Node3D: return info.node
	return null
