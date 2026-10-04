# xz 평면 판정 도구(웹 combat/hitbox.js 이식) — 원·부채꼴·선분. 위치는 Vector2(x, z).
extends RefCounted

const MAX_SLOPE := 1.1

# 부채꼴(원점 o, 방향 d 단위벡터, 반지름 r, 전체 각 arc_deg) vs 원(p, pr)
static func fan_hit(o: Vector2, d: Vector2, r: float, arc_deg: float, p: Vector2, pr: float) -> bool:
	var v := p - o
	var l := v.length()
	if l > r + pr: return false
	if l <= pr: return true
	var c := clampf(v.dot(d) / l, -1.0, 1.0)
	var ang := acos(c)
	var pad := asin(minf(1.0, pr / l))
	return ang <= deg_to_rad(arc_deg) * 0.5 + pad

static func seg_dist2(a: Vector2, b: Vector2, p: Vector2) -> float:
	var e := b - a
	var l2 := e.length_squared()
	var t := clampf((p - a).dot(e) / l2, 0.0, 1.0) if l2 > 1e-9 else 0.0
	return (a + e * t - p).length_squared()

static func segment_hit(a: Vector2, b: Vector2, half_w: float, p: Vector2, pr: float) -> bool:
	var rr := half_w + pr
	return seg_dist2(a, b, p) < rr * rr

static func closest_on_seg(a: Vector2, b: Vector2, p: Vector2) -> Vector2:
	var e := b - a
	var l2 := e.length_squared()
	var t := clampf((p - a).dot(e) / l2, 0.0, 1.0) if l2 > 1e-9 else 0.0
	return a + e * t

static func angle_between(a: Vector2, b: Vector2) -> float:
	return rad_to_deg(acos(clampf(a.dot(b), -1.0, 1.0)))

# 방향을 최대 max_rad만큼 목표 쪽으로 돌린 단위벡터
static func turn_toward(h: Vector2, t: Vector2, max_rad: float) -> Vector2:
	var a := atan2(h.y, h.x); var b := atan2(t.y, t.x)
	var d := wrapf(b - a, -PI, PI)
	var s := clampf(d, -max_rad, max_rad)
	return Vector2(cos(a + s), sin(a + s))

# 8방향 → 4방향 그림 방향
static func facing4(dx: float, dz: float, prev: String, side_bias := 1.15) -> String:
	if dx == 0.0 and dz == 0.0: return prev
	if absf(dx) > absf(dz) * side_bias: return "right" if dx > 0.0 else "left"
	return "down" if dz > 0.0 else "up"

static func _step_ok(env, f: Vector2, t: Vector2, r: float) -> bool:
	if env.blocked(t.x, t.y, r): return false
	var d := maxf((t - f).length(), 1e-6)
	return (env.height_at(t.x, t.y) - env.height_at(f.x, f.y)) / d <= MAX_SLOPE

# 충돌·경사를 고려한 이동. body.pos(Vector2)를 바꾸고 움직였으면 true
static func move_body(env, body, d: Vector2, r: float) -> bool:
	if d == Vector2.ZERO: return false
	var p: Vector2 = body.pos
	if env.blocked(p.x, p.y, r) and not env.blocked(p.x + d.x * 4.0, p.y + d.y * 4.0, r * 0.5):
		body.pos = p + d; return true
	var t := p + d
	if _step_ok(env, p, t, r): body.pos = t; return true
	if d.x != 0.0 and _step_ok(env, p, Vector2(t.x, p.y), r): body.pos = Vector2(t.x, p.y); return true
	if d.y != 0.0 and _step_ok(env, p, Vector2(p.x, t.y), r): body.pos = Vector2(p.x, t.y); return true
	return false

static func nearest_free(env, p: Vector2, r: float) -> Vector2:
	var rad := 0.0
	while rad < 6.0:
		var n := 1 if rad == 0.0 else ceili(rad * 8.0)
		for i in n:
			var a := float(i) / n * TAU
			var q := p + Vector2(cos(a), sin(a)) * rad
			if not env.blocked(q.x, q.y, r): return q
		rad += 0.35
	return p
