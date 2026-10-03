# 장독대(돌 단 + 옹기 항아리 세 줄) — 웹 buildings.js jangdok() 이식.
# params: seed, w(3.2), d(2.2), n(줄별 항아리 수 [3,2,2] — 줄 1~3개)
# 성능: 웹(옹기 13개·12각)은 소품 예산을 크게 넘어 8각·옹기 7개·뚜껑 먹선 생략(약 1,100 — 소품 묶음 예외).
extends RefCounted
const C := preload("res://kit/village/_common.gd")

static func build(params: Dictionary) -> Dictionary:
	var m := C.M.new(int(params.get("seed", 1)))
	var w: float = params.get("w", 3.2); var d: float = params.get("d", 2.2)
	draw(m, params)
	return m.result("장독대", Vector2(w, d), false)

static func jar(m: C.M, part: String, x: float, y: float, z: float, rr: float, hh: float) -> void:
	var pts := []
	for q in [[0, 0], [0.62, 0], [1, 0.42], [0.86, 0.8], [0.58, 0.95], [0, 1.0]]: pts.append(Vector2(q[0] * rr, q[1] * hh))
	m.add(part, "onggi", C.PA(Kit.xf(C.lathe(pts, 8), x, y, z), C.ONGGI, 0.05, m.rng), 0.02)
	m.add(part, "onggi", C.P(Kit.cyl(rr * 0.6, rr * 0.66, 0.07, 8, x, y + hh + 0.02, z), 0x6a4630, 0x553826), 0)

static func draw(m: C.M, o: Dictionary) -> void:
	var w: float = o.get("w", 3.2); var d: float = o.get("d", 2.2); var R := m.rng
	m.add("p", "stone", C.P(Kit.box(w, 0.4, d, 0, 0.15, 0), 0xb0aa9e, 0x827d73, 0.06, R), 0.025)
	for i in 5:
		m.add("p", "stone", C.P(Kit.xf(Kit.lump(0.24, 0, R, 0.3, 0.7), -w / 2 + w * i / 4.0, 0.2, d / 2 + 0.02), 0xbbb5a8, 0x8e897f, 0.05, R), 0)
	var ns: Array = o.get("n", [3, 2, 2])
	var rows := [[-d / 2 + 0.5, 0.42, 0.95], [0.05, 0.36, 0.78], [d / 2 - 0.45, 0.26, 0.55]]
	for k in mini(3, ns.size()):   # 줄 수가 3보다 적어도 된다(영남 작은집 [2, 1])
		var n: int = ns[k]
		for i in n:
			var x: float = -w / 2 + 0.25 + (w - 0.5) * ((i + 0.5) / n) + (m.r() - 0.5) * 0.1
			jar(m, "p", x, 0.35, rows[k][0], rows[k][1] * (0.85 + m.r() * 0.25), rows[k][2] * (0.85 + m.r() * 0.25))
	m.box_c(-w / 2, w / 2, -d / 2, d / 2)
