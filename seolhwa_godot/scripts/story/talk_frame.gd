# 대화 구도(재기획 2단계 — 대화 카메라 v1.1 CAM_TALK_2 §4·§5, 결정 D5·D9) — 말을 거는 그 순간 한 번만 계산한다(프레임마다 아님).
#   플레이어와 상대가 화면에서 겹치지 않고(서로 가리지 않음), 상대가 건물·나무에 가리지 않는 구도를 고른다.
#
#   쓰는 것(새 카메라 체계 없음):
#     · 플레이어 한 걸음 — 지금 자리에서 상대 곁(옆 1.3~1.9m)으로 0.2~0.5초 걷는다. 카메라와 상대 사이에 서지 않게(첫 기준).
#     · 카메라 옆 돌기 — 배·말이 쓰는 yaw 경로(CameraRig.talk_yaw) ±25°·±35°(이야기 인물만 — D5, C27: 고을 사람은 카메라를 움직이지 않는다).
#     · 배경 가림 — region_main의 각본 가림 기준점(occ_script)을 두 사람 사이로 옮겨 그 둘레 지붕·나무를 점무늬로 비운다(대화 동안만).
#     · 거리 — 위 둘로도 상대가 가리면 마지막으로 거리를 0.8배까지 당긴다.
#   D9 순서: 겹침이 없는 후보 가운데 ① 가림 없는 옆 돌기 → ② 가림은 점무늬로(필요한 곳만) → ③ 거리. 겹침은 걸음으로 푼다.
#   1인칭(C68)에서는 부르지 않는다 — 1인칭은 말하는 이 쪽으로 돌아보기 그대로.
#
#   화면 겹침: 두 그림(카메라를 보고 선 판 — sprite_char)을 후보 카메라로 투영한 사각형의 겹친 넓이 / 작은 쪽 넓이.
#   그림 너비 = 키 × 0.58(플레이어 삿갓) · × 0.46(상대). 0이어야 통과(그림 너비 10%씩 넓혀 잰다 — 맞닿지 않게).
extends RefCounted

const YAWS := [0.0, 25.0, -25.0, 35.0, -35.0]   # 도(°). 대화 v1.1 §5 '25~40도 틀어'
const W_PLAYER := 0.58
const W_NPC := 0.46
const STAND_R := [1.6, 1.35, 1.9]
const STAND_STEP_DEG := 20.0
const MAX_MOVE := 2.6        # 한 걸음이라 부를 만한 거리 위로는 옮기지 않는다
const WALK_SPEED := 2.6      # m/s — 걷기(region_main WALK)와 비슷하게
const OCC_PTS := [0.25, 0.6, 0.95]   # 키에 대한 비율 — 발목·허리·머리

var d          # story_director
var main

func _init(director) -> void:
	d = director
	main = d.main

# npc: 상대 발 위치, npc_h: 상대 키, story: 이야기 인물(카메라 이동 가능), tc: 대화 카메라 값(pitch·distance·fov) — 고을 사람은 {}(지금 카메라)
# 돌려줌: { stand: Vector2|null(옮길 자리), yaw(라디안), pitch, distance, fov, focus: Vector2, overlap, occ_npc, occ_player, phase, why }
func plan(npc: Vector3, npc_h: float, story: bool, tc: Dictionary) -> Dictionary:
	var rig = main.rig
	var P := Vector2(main.player_pos.x, main.player_pos.z)
	var N := Vector2(npc.x, npc.z)
	var ph: float = float(main.player.height)
	var pitch: float = float(tc.get("pitch", rig.cur.pitch))
	var dist: float = float(tc.get("distance", rig.cur.distance))
	var fov: float = float(tc.get("fov", rig.cur.fov))
	var yaws: Array = YAWS if story else [rad_to_deg(rig.yaw)]
	var occs := _near_occluders(N, 45.0)
	var cands: Array = []
	for s in _stands(P, N):
		for yd in yaws:
			var y := deg_to_rad(float(yd))
			var focus: Vector2 = (s.p + N) * 0.5 if story else s.p
			var cam := _cam_pos(focus, y, pitch, dist)
			var look := Vector3(focus.x, main.world.height_at(focus.x, focus.y) + 0.9, focus.y)
			var ov := _overlap(cam, look, y, s.p, ph, N, npc_h)
			var on := _occ_count(cam, N, npc_h, occs)
			var op := _occ_count(cam, s.p, ph, occs)
			cands.append({ stand = s.p, move = s.move, yaw = y, yd = float(yd), focus = focus, overlap = ov, occ_npc = on, occ_player = op,
				behind = s.behind, cost = s.move * 1.2 + absf(float(yd)) / 35.0 * 0.8 + s.behind * 0.6 + op * 0.4 })
	var clear := cands.filter(func(c): return c.overlap <= 0.0)
	var pick = null
	var phase := ""
	if not clear.is_empty():
		var no_occ := clear.filter(func(c): return c.occ_npc == 0)
		if not no_occ.is_empty():
			pick = _min_cost(no_occ); phase = "side" if absf(pick.yd) > 0.1 else ("step" if pick.move > 0.05 else "none")
		else:
			for c in clear: c.cost += c.occ_npc * 0.5
			pick = _min_cost(clear); phase = "fade"
	else:
		cands.sort_custom(func(a, b): return a.overlap < b.overlap or (a.overlap == b.overlap and a.cost < b.cost))
		pick = cands[0]; phase = "fade"
	var out_dist := dist
	# ③ 거리: 점무늬로 비우는 데도 상대가 가리면(이야기 인물만) 거리를 당겨 다시 본다
	if story and pick.occ_npc > 0:
		for k in [0.9, 0.8]:
			var cam2 := _cam_pos(pick.focus, pick.yaw, pitch, dist * k)
			if _occ_count(cam2, N, npc_h, occs) < pick.occ_npc:
				out_dist = dist * k; phase += "+dist"; break
	return { stand = pick.stand if pick.move > 0.05 else null, move = pick.move, yaw = pick.yaw if story else rig.yaw,
		pitch = pitch, distance = out_dist, fov = fov, focus = pick.focus, overlap = pick.overlap,
		occ_npc = pick.occ_npc, occ_player = pick.occ_player, phase = phase, n = cands.size() }

func _min_cost(arr: Array) -> Dictionary:
	var best: Dictionary = arr[0]
	for c in arr:
		if c.cost < best.cost: best = c
	return best

# 설 자리 후보: 지금 자리(움직임 0) + 상대 둘레(반지름 1.35~1.9m, 20°마다) 가운데 걸어서 닿고 상대를 지나치지 않는 곳
func _stands(P: Vector2, N: Vector2) -> Array:
	var out := [{ p = P, move = 0.0, behind = _behind(P, N) }]
	var w = main.world
	var r: float = float(main.player.radius)
	var in0 = w.interior_at(P.x, P.y)
	for rr in STAND_R:
		var a := 0.0
		while a < 360.0:
			var s := N + Vector2.from_angle(deg_to_rad(a)) * float(rr)
			a += STAND_STEP_DEG
			var mv := P.distance_to(s)
			if mv > MAX_MOVE or mv < 0.1: continue
			if w.interior_at(s.x, s.y) != in0: continue
			if Geometry2D.get_closest_point_to_segment(N, P, s).distance_to(N) < 0.75: continue   # 상대를 뚫고 지나가지 않게
			if absf(w.height_at(s.x, s.y) - w.height_at(N.x, N.y)) > 0.6: continue
			if not _walkable(P, s, r): continue
			out.append({ p = s, move = mv, behind = _behind(s, N) })
	return out

# 상대보다 카메라에서 먼 쪽(뒤)에 서면 1(기본 시점 남→북 기준 — 플레이어는 앞·옆이 낫다)
func _behind(s: Vector2, N: Vector2) -> float:
	return 1.0 if s.y < N.y - 0.4 else 0.0

func _walkable(a: Vector2, b: Vector2, r: float) -> bool:
	var w = main.world
	var n := maxi(1, ceili(a.distance_to(b) / 0.2))
	var prev := a
	for i in range(1, n + 1):
		var q := a.lerp(b, float(i) / n)
		if not w._step_ok(prev.x, prev.y, q.x, q.y, r, Callable()): return false
		prev = q
	return true

func _cam_pos(focus: Vector2, yaw: float, pitch: float, dist: float) -> Vector3:
	var pr := deg_to_rad(pitch)
	var t := Vector3(focus.x, main.world.height_at(focus.x, focus.y) + 0.9, focus.y)
	return t + Vector3(sin(yaw) * cos(pr) * dist, sin(pr) * dist, cos(yaw) * cos(pr) * dist)

# 그림 사각형(화면 기울기 공간) — 판은 카메라 yaw 쪽을 본다(sprite_char.update_char)
func _rect(xf: Transform3D, yaw: float, feet: Vector3, h: float, wk: float) -> Rect2:
	var right := Vector3(cos(yaw), 0, -sin(yaw)) * (h * wk * 0.5)
	var inv := xf.affine_inverse()
	var lo := Vector2(INF, INF); var hi := Vector2(-INF, -INF)
	for c in [feet - right, feet + right, feet - right + Vector3(0, h, 0), feet + right + Vector3(0, h, 0)]:
		var v: Vector3 = inv * c
		var z := minf(v.z, -0.01)
		var s := Vector2(v.x / -z, v.y / -z)
		lo = lo.min(s); hi = hi.max(s)
	return Rect2(lo, hi - lo)

func _overlap(cam: Vector3, look: Vector3, yaw: float, sp: Vector2, ph: float, N: Vector2, nh: float) -> float:
	var xf := Transform3D(Basis.looking_at(look - cam, Vector3.UP), cam)
	var w = main.world
	var a := _rect(xf, yaw, Vector3(sp.x, w.height_at(sp.x, sp.y), sp.y), ph, W_PLAYER)
	var b := _rect(xf, yaw, Vector3(N.x, w.height_at(N.x, N.y), N.y), nh, W_NPC)
	a = a.grow(a.size.x * 0.1); b = b.grow(b.size.x * 0.1)   # 맞닿지 않게 그림 너비 10% 틈
	var i := a.intersection(b)
	if i.size.x <= 0.0 or i.size.y <= 0.0: return 0.0
	return i.get_area() / maxf(minf(a.get_area(), b.get_area()), 1e-6)

func _near_occluders(N: Vector2, r: float) -> Array:
	var out := []
	for occ in main.world.occluders:
		var b: AABB = occ.aabb
		var cx := clampf(N.x, b.position.x, b.end.x); var cz := clampf(N.y, b.position.z, b.end.z)
		if N.distance_squared_to(Vector2(cx, cz)) < r * r and occ.node.visible and occ.node.is_inside_tree(): out.append(occ)
	return out

# 카메라 → 사람 몸(발목·허리·머리) 선분을 가리는 가림 물체(지붕·나무) 수(0~3)
func _occ_count(cam: Vector3, at: Vector2, h: float, occs: Array) -> int:
	var n := 0
	var g: float = main.world.height_at(at.x, at.y)
	for k in OCC_PTS:
		var p := Vector3(at.x, g + h * float(k), at.y)
		var dv := p - cam
		var end := cam + dv.normalized() * (dv.length() - 0.4)
		for occ in occs:
			if main._seg_box(cam, end, occ.aabb) and main._seg_hits_mesh(occ, cam, end):
				n += 1; break
	return n

# 대화 동안 가림 기준점: 두 사람 머리 사이, 반지름 = 반 거리 + 1.4(둘 다 덮게). region_main.set_occ_script와 같은 꼴
static func occ_spec(a: Vector3, ah: float, b: Vector3, bh: float) -> Dictionary:
	var ha := a + Vector3(0, ah * 0.8, 0)
	var hb := b + Vector3(0, bh * 0.8, 0)
	return { focus = (ha + hb) * 0.5, r = maxf(2.4, ha.distance_to(hb) * 0.5 + 1.4), talk = true }
