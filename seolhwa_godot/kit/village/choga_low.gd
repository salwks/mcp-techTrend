# 낮은 해안 초가 — 바닷바람에 날리지 않게 지붕을 낮고 둥글게 하고 새끼 그물로 얽어 처마 끝에 돌을 매단 집(해안·섬용 미리).
# 고증: 남해안·제주는 새(띠)·볏짚 이엉을 굵은 새끼로 바둑판처럼 얽어 묶었다(제주 '집줄', 남해 '그물 이엉'). 돌을 매다는 방식은
#   지역마다 달라 "가설"로 단순화(처마 끝 줄마다 돌 하나).
# 위에서 볼 때: 잿빛 낡은 이엉 + 어두운 격자 줄 + 처마 둘레 돌 점 — 노란 둥근 초가와 구별, 지붕이 낮고 납작.
# params: seed, w(6.0), d(4.0), plan(""|"il"), grid(7: 그물 줄 수), lod(0|1)
extends RefCounted
const C := preload("res://kit/village/_common.gd")
const CH := preload("res://kit/village/choga.gd")

static func build(params: Dictionary) -> Dictionary:
	var m := C.M.new(int(params.get("seed", 1)))
	var o := params.duplicate()
	o.w = float(params.get("w", 6.0)); o.d = float(params.get("d", 4.0))
	o.roof = "none"; o.wall_h = 1.6; o.F = 0.3
	if o.get("plan", "") == "giyeok": o.plan = ""
	var info := CH.draw(m, o)
	var W: float = info.W; var D: float = info.D
	var zc := 0.25 if o.get("plan", "") == "il" else 0.0
	low_roof(m, W / 2 + 0.95, D / 2 + 1.0 + zc, info.top + 0.1, 0.85, zc, int(params.get("grid", 7)), int(params.get("lod", 0)) == 1)
	return m.result("낮은초가", Vector2(W + 2.0, D + 2.2))

# 낮은 둥근 이엉 + 새끼 그물 + 처마 돌. X·Z 반폭, eave 처마 높이, Hh 지붕 높이, zc 중심 z
static func low_roof(m: C.M, X: float, Z: float, eave: float, Hh: float, zc: float, n: int, lod := false) -> void:
	var R := m.rng
	var th := 1.0
	var Ry := Hh / (1 - cos(th)); var Rx := X / sin(th); var Rz := Z / sin(th); var cy := eave - Ry * cos(th)
	var dome := C.sphere(1, 12 if lod else 15, 3 if lod else 5, 0, TAU, 0, th)
	Kit.xf(dome, 0, cy, zc, 0, 0, 0, Rx, Ry, Rz)
	m.add("roof", "thatch", C.PA(dome, C.THATCH_SEA, 0.05, R), 0.05)
	var lip := Kit.cyl(1, 1.02, 0.26, 12 if lod else 18)
	Kit.xf(lip, 0, eave - 0.12, zc, 0, 0, 0, X, 1, Z)
	m.add("roof", "thatch", C.PA(lip, C.THATCH_SEA_LIP, 0.04, R), 0.035)
	var H := func(x: float, z: float) -> float: return cy + Ry * sqrt(maxf(0.0, 1.0 - pow(x / Rx, 2) - pow((z - zc) / Rz, 2))) + 0.035
	var rope := Kit.Geo.new()
	var stones := []
	var w := 0.045
	var nx := n + 2; var nz := n
	var seg := 6 if lod else 10
	# x방향 줄(앞뒤로 늘어선 줄)
	for j in nz:
		var zz := zc + Z * (-1.0 + 2.0 * (j + 0.5) / nz) * 0.96
		var xm := X * sqrt(maxf(0.0, 1.0 - pow((zz - zc) / Z, 2))) + 0.02
		for i in seg:
			var xa := -xm + 2 * xm * i / seg; var xb := -xm + 2 * xm * (i + 1) / seg
			C.qf(rope, Vector3(xa, H.call(xa, zz - w), zz - w), Vector3(xb, H.call(xb, zz - w), zz - w), Vector3(xb, H.call(xb, zz + w), zz + w), Vector3(xa, H.call(xa, zz + w), zz + w), Vector3.UP)
		for s in [-1.0, 1.0]: stones.append(Vector3(s * (xm + 0.06), eave - 0.32, zz))
	# z방향 줄
	for i in nx:
		var xx := X * (-1.0 + 2.0 * (i + 0.5) / nx) * 0.96
		var zm := Z * sqrt(maxf(0.0, 1.0 - pow(xx / X, 2))) + 0.02
		for k in seg:
			var za := zc - zm + 2 * zm * k / seg; var zb := zc - zm + 2 * zm * (k + 1) / seg
			C.qf(rope, Vector3(xx - w, H.call(xx - w, za) + 0.01, za), Vector3(xx + w, H.call(xx + w, za) + 0.01, za), Vector3(xx + w, H.call(xx + w, zb) + 0.01, zb), Vector3(xx - w, H.call(xx - w, zb) + 0.01, zb), Vector3.UP)
		for s in [-1.0, 1.0]: stones.append(Vector3(xx, eave - 0.32, zc + s * (zm + 0.06)))
	m.add("roof", "flat", C.P(rope, 0x5e4e38, 0x4a3d2c, 0.03, R), 0)
	if lod: return
	var sg := []
	for p in stones:
		var lg := Kit.lump(R.between(0.11, 0.15), 0, R, 0.3, 0.9)
		sg.append(C.P(Kit.xf(lg, p.x, p.y, p.z, 0, R.next() * 3, 0), 0x9c968a, 0x6f6a60, 0.06, R))
	m.add("roof", "stone", Kit.merge(sg), 0.015)
