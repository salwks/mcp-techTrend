# 현무암 돌담(제주 밭담·집담·올레담) — 검은 구멍 돌을 메지 없이 한 줄로 얹어 쌓아 틈이 숭숭. 두 점 또는 꺾은선(points).
# 고증: 제주 돌담은 '외담'(한 겹)이 많고 바람이 틈으로 빠진다. 높이 1.2~1.6m. 위가 울퉁불퉁한 덩이 줄.
# params: seed, ax,az,bx,bz (없으면 len(5) x축) 또는 points([[x,z],…]), closed(false), h(1.35), lite(true: 위 덩이 줄 + 앞면 듬성)
# 삼각형: lite 약 70/m, full 약 140/m
extends RefCounted
const C := preload("res://kit/village/_common.gd")
const CC := preload("res://kit/culture/_cc.gd")
const SW := preload("res://kit/village/stone_wall.gd")

static func build(params: Dictionary) -> Dictionary:
	var m := C.M.new(int(params.get("seed", 1)))
	var pts := []
	if params.has("points"):
		for q in params.points: pts.append(Vector2(float(q[0]), float(q[1])))
		if params.get("closed", false): pts.append(pts[0])
	else:
		var L: float = params.get("len", 5.0)
		pts = [Vector2(params.get("ax", -L / 2), params.get("az", 0.0)), Vector2(params.get("bx", L / 2), params.get("bz", 0.0))]
	var mn := Vector2(INF, INF); var mx := -mn
	for i in pts.size() - 1:
		draw(m, pts[i].x, pts[i].y, pts[i + 1].x, pts[i + 1].y, params.get("h", 1.35), bool(params.get("lite", true)))
	for p in pts: mn = mn.min(p); mx = mx.max(p)
	return m.result("현무암돌담", Vector2(mx.x - mn.x + 0.8, mx.y - mn.y + 0.8), true)

static func draw(m: C.M, ax: float, az: float, bx: float, bz: float, h := 1.35, lite := true) -> void:
	var len := Vector2(bx - ax, bz - az).length()
	if len < 0.05: return
	var R := m.rng
	var old := m.xform
	m.xform = old * C.seg_xform(ax, az, bx, bz)
	m.add("p", "stone", C.PA(Kit.box(len, h - 0.2, 0.38, 0, (h - 0.2) / 2, 0), CC.BASALT, 0.06, R), 0.03)
	var sg := []
	var nt := maxi(2, roundi(len / 0.5))
	for i in nt:
		var lg := Kit.lump(R.between(0.24, 0.32), 0, R, 0.4, 0.75)
		sg.append(C.PA(Kit.xf(lg, -len / 2 + (i + 0.5) * len / nt, h - 0.12 + R.between(-0.06, 0.06), R.between(-0.05, 0.05), 0, R.next() * 3, 0), CC.BASALT_L, 0.1, R))
	var rows := 1 if lite else 2
	for side in ([1] if lite else [1, -1]):
		for row in rows + 1:
			var nf := maxi(1, roundi(len / 0.7))
			for i in nf:
				if R.next() < 0.45: continue
				var lg := Kit.lump(R.between(0.2, 0.27), 0, R, 0.4, 0.8)
				sg.append(C.PA(Kit.xf(lg, -len / 2 + (i + R.between(0.2, 0.8)) * len / nf, 0.3 + row * 0.45, side * 0.18, 0, R.next() * 3, 0, 1.1, 1, 0.6), CC.BASALT_L, 0.1, R))
	m.add("p", "stone", Kit.merge(sg), 0.0)
	m.xform = old
	SW.add_line_collider(m, ax, az, bx, bz, 0.3)
