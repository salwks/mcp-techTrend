# 담 한 줄(wall run) — 점 줄(pts)을 따라 곧게·굽게 이어지는 담 한 덩이(한 메시). 고을 짜임 생성기(organic.gd)의 담 길 규칙이 점을 정한다.
#   params: { kind: "todam_tile"|"todam_thatch"|"stone"|"fence", pts: [[x,z]…], closed(false), h, seed, open_a/open_b(끝이 건물·대문에 맞댐),
#             why: [ [이유…] ](감사용 — 짓는 데는 안 씀) }
#   흙담(todam): 마디마다 꺾인 각의 절반 기울기로 끝을 맞춰(miter) 몸·갓(기와/이엉)이 굽은 줄을 끊김 없이 따른다.
#   돌담(stone)·싸리울(fence): 마디 끝을 두께 절반 늘려 겹쳐 잇는다(막돌·싸리라 겹침이 드러나지 않음).
#   충돌: 마디마다 선 충돌체.
extends RefCounted
const C := preload("res://kit/village/_common.gd")
const TD := preload("res://kit/village/todam.gd")
const SW := preload("res://kit/village/stone_wall.gd")
const FN := preload("res://kit/village/fence.gd")

static func footprint(params: Dictionary) -> Vector2:
	var lo := Vector2(INF, INF); var hi := Vector2(-INF, -INF)
	for q in params.get("pts", []):
		lo = Vector2(minf(lo.x, float(q[0])), minf(lo.y, float(q[1]))); hi = Vector2(maxf(hi.x, float(q[0])), maxf(hi.y, float(q[1])))
	return (hi - lo) + Vector2(0.6, 0.6) if lo.x < INF else Vector2(1, 1)

# 마디 i의 a(0)/b(1) 끝 miter 기울기: 꺾인 각 φ의 tan(φ/2), 부호 = 이웃 마디가 뻗는 쪽의 로컬 z
static func _miter(P: Array, i: int, end: int, closed: bool) -> float:
	var n := P.size()
	var a: Vector2 = P[i]; var b: Vector2 = P[(i + 1) % n]
	var pt: Vector2 = a if end == 0 else b
	var dout: Vector2 = (a - b).normalized() if end == 0 else (b - a).normalized()
	var j := i - 1 if end == 0 else i + 1
	if not closed and (j < 0 or j >= n - 1): return 0.0
	j = (j + n) % n
	var oa: Vector2 = P[j]; var ob: Vector2 = P[(j + 1) % n]
	var odir: Vector2 = (oa - pt).normalized() if end == 1 else (ob - pt).normalized()
	if end == 0: odir = (oa - pt).normalized()
	else: odir = (ob - pt).normalized()
	var phi := absf(dout.angle_to(odir))
	if phi < 0.01: return 0.0
	var ang := atan2((b - a).y, (b - a).x)
	var lz := Vector2(-sin(ang), cos(ang))
	return signf(odir.dot(lz)) * tan(clampf(phi, 0.0, 2.4) / 2.0)

static func build(params: Dictionary) -> Dictionary:
	var m := C.M.new(int(params.get("seed", 1)))
	var P := []
	for q in params.get("pts", []): P.append(Vector2(float(q[0]), float(q[1])))
	var closed: bool = bool(params.get("closed", false))
	var kind: String = params.get("kind", "todam_thatch")
	var nseg := P.size() if closed else P.size() - 1
	for i in nseg:
		var a: Vector2 = P[i]; var b: Vector2 = P[(i + 1) % P.size()]
		if a.distance_to(b) < 0.05: continue
		match kind:
			"stone", "fence":
				var u := (b - a).normalized()
				var ea := 0.0 if (not closed and i == 0) else 0.22
				var eb := 0.0 if (not closed and i == nseg - 1) else 0.22
				var a2 := a - u * ea; var b2 := b + u * eb
				if kind == "stone": SW.draw(m, a2.x, a2.y, b2.x, b2.y, float(params.get("h", 1.4)), true, true)
				else: FN.draw(m, a2.x, a2.y, b2.x, b2.y, float(params.get("h", 1.15)), true)
			_:
				var oa: bool = (not closed and i == 0 and bool(params.get("open_a", false)))
				var ob: bool = (not closed and i == nseg - 1 and bool(params.get("open_b", false)))
				var ma := 0.0 if oa else _miter(P, i, 0, closed)
				var mb := 0.0 if ob else _miter(P, i, 1, closed)
				var tile: bool = kind == "todam_tile"
				TD.draw(m, a.x, a.y, b.x, b.y, float(params.get("h", 1.95 if tile else 1.7)), "tile" if tile else "thatch", 0.5 if tile else 0.4, oa, ob, ma, mb)
	return m.result("담_" + kind, footprint(params))
