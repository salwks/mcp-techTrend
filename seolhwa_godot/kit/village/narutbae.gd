# 나룻배 — 평저(平底) 나룻배: 납작한 바닥, 벌어진 뱃전, 들린 이물·고물, 가로 멍에, 삿대.
# 원점 = 물 면(y=0) 배 가운데, 이물이 -z(북), 고물이 +z. 가로질러 나르려면 배치에서 ry로 돌린다.
# params: seed, len(6.4), w(1.7), pole(true)
extends RefCounted
const C := preload("res://kit/village/_common.gd")

static func build(params: Dictionary) -> Dictionary:
	var m := C.M.new(int(params.get("seed", 1)))
	var L: float = params.get("len", 6.4); var Wd: float = params.get("w", 1.7)
	var R := m.rng
	# 단면 역(station): z, 바닥 반폭, 뱃전 반폭, 바닥 y, 뱃전 y
	var st := []
	var N := 7
	for i in N:
		var t := float(i) / (N - 1) * 2 - 1   # -1(이물)..1(고물)
		var e := absf(t)
		var bw := Wd * 0.36 * (1 - 0.55 * pow(e, 2.5))
		var gw := Wd * 0.5 * (1 - 0.35 * pow(e, 2.5))
		var by := -0.28 + 0.3 * pow(e, 3) + (0.12 * pow(e, 3) if t < 0 else 0.0)
		var gy := 0.32 + 0.22 * pow(e, 3) + (0.15 * pow(e, 3) if t < 0 else 0.0)
		st.append([t * L / 2, bw, gw, by, gy])
	var outer := Kit.Geo.new(); var inner := Kit.Geo.new()
	var ti := 0.05
	for i in N - 1:
		var A: Array = st[i]; var B: Array = st[i + 1]
		var pa := [Vector3(-A[2], A[4], A[0]), Vector3(-A[1], A[3], A[0]), Vector3(A[1], A[3], A[0]), Vector3(A[2], A[4], A[0])]
		var pb := [Vector3(-B[2], B[4], B[0]), Vector3(-B[1], B[3], B[0]), Vector3(B[1], B[3], B[0]), Vector3(B[2], B[4], B[0])]
		for k in 3:
			outer.quad(pa[k], pb[k], pb[k + 1], pa[k + 1])
			var ia: Vector3 = pa[k] * Vector3(1 - ti, 1, 1) + Vector3(0, ti, 0); var ib: Vector3 = pb[k] * Vector3(1 - ti, 1, 1) + Vector3(0, ti, 0)
			var ic: Vector3 = pb[k + 1] * Vector3(1 - ti, 1, 1) + Vector3(0, ti, 0); var id: Vector3 = pa[k + 1] * Vector3(1 - ti, 1, 1) + Vector3(0, ti, 0)
			inner.quad(ia, id, ic, ib)
	# 이물·고물 막판
	for e in [0, N - 1]:
		var S: Array = st[e]
		var q := [Vector3(-S[2], S[4], S[0]), Vector3(-S[1], S[3], S[0]), Vector3(S[1], S[3], S[0]), Vector3(S[2], S[4], S[0])]
		if e == 0: outer.quad(q[0], q[3], q[2], q[1])
		else: outer.quad(q[0], q[1], q[2], q[3])
	m.add("p", "wood", C.P(outer, 0x7a5c3e, 0x4d3826, 0.05, R), 0.03)
	m.add("p", "wood", C.P(inner, 0x9a7852, 0x7a5c3e, 0.04, R), 0)
	# 뱃전 띠(가로 멍에·널 위 판자)
	for i in [1, 3, 5]:
		var S: Array = st[i]
		m.add("p", "wood", C.PA(Kit.box(S[2] * 2 + 0.06, 0.06, 0.18, 0, S[4] - 0.05, S[0]), C.WOOD), 0.01)
	m.add("p", "wood", C.PA(Kit.box(Wd * 0.6, 0.04, L * 0.35, 0, st[3][3] + 0.1, 0), C.WOOD_L, 0.04, R), 0)
	if params.get("pole", true):
		m.add("p", "wood", C.P(Kit.xf(Kit.cyl(0.035, 0.035, 4.2, 5), Wd * 0.25, 0.42, 0.3, PI / 2 - 0.08, 0.12, 0), 0x9a8466), 0.008)
	m.box_c(-Wd / 2, Wd / 2, -L / 2, L / 2)
	m.anchor("boatman", Vector3(0, st[5][3] + 0.1, st[5][0])); m.anchor("passenger", Vector3(0, st[3][3] + 0.14, 0))
	m.anchor("bow", Vector3(0, 0.3, -L / 2 - 0.4))
	return m.result("나룻배", Vector2(Wd + 0.2, L + 0.2), false)
