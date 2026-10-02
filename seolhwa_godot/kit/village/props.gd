# 마을 작은 소품 묶음 — params.kind로 고른다(모두 소품 예산 ≤ 800).
#   pyeongsang 평상 / gamasot 한데부뚜막+가마솥 / yongsu 주막 용수 장대 / jeolgu 절구+공이 / maetdol 맷돌 /
#   dok 항아리 몇 개 / soguri 소쿠리(곡식·빨래) / byeotdan 볏단 더미 / scarecrow 허수아비(웹 index.js) / meongseok 멍석(곡식 널기)
# params: seed, kind, (pyeongsang) w,d / (soguri) fill:"grain"|"cloth"|"veg" / (dok) n
# 각 그리기 함수는 다른 모델(주막·장터·헛간)에서 m.push()로 불러 쓴다.
extends RefCounted
const C := preload("res://kit/village/_common.gd")
const J := preload("res://kit/village/jangdok.gd")

const KINDS := ["pyeongsang", "gamasot", "yongsu", "jeolgu", "maetdol", "dok", "soguri", "byeotdan", "scarecrow", "meongseok"]

static func build(params: Dictionary) -> Dictionary:
	var m := C.M.new(int(params.get("seed", 1)))
	var kind: String = params.get("kind", "pyeongsang")
	var fp := Vector2(1, 1)
	match kind:
		"pyeongsang":
			var w: float = params.get("w", 2.0); var d: float = params.get("d", 1.3)
			pyeongsang(m, w, d); fp = Vector2(w, d)
		"gamasot": gamasot(m); fp = Vector2(1.5, 1.4)
		"yongsu": yongsu(m, bool(params.get("cloth", true))); fp = Vector2(0.8, 0.8)
		"jeolgu": jeolgu(m); fp = Vector2(0.9, 0.9)
		"maetdol": maetdol(m); fp = Vector2(1.0, 1.0)
		"dok": dok(m, int(params.get("n", 3))); fp = Vector2(1.6, 1.0)
		"soguri": soguri(m, params.get("fill", "grain")); fp = Vector2(0.8, 0.8)
		"byeotdan": byeotdan(m); fp = Vector2(1.8, 1.4)
		"scarecrow": scarecrow(m); fp = Vector2(1.6, 0.6)
		"meongseok": meongseok(m); fp = Vector2(2.4, 1.8)
	return m.result(kind, fp, false)

# 평상: 널판 + 다리 4. 앉는 자리 앵커
static func pyeongsang(m: C.M, w := 2.0, d := 1.3, h := 0.45) -> void:
	m.add("p", "wood", C.PA(Kit.box(w, 0.08, d, 0, h, 0), C.WOOD_L, 0.04, m.rng), 0.02)
	var n := int(w / 0.25)
	for i in range(1, n): m.add("p", "flat", C.P(Kit.box(0.02, 0.005, d - 0.02, -w / 2 + i * w / n, h + 0.042, 0), 0x6e5438), 0)
	for q in [[-1, -1], [1, -1], [-1, 1], [1, 1]]:
		m.add("p", "wood", C.PA(Kit.box(0.09, h, 0.09, q[0] * (w / 2 - 0.1), h / 2, q[1] * (d / 2 - 0.1)), C.WOOD), 0.01)
	m.add("p", "wood", C.PA(Kit.box(w - 0.2, 0.06, 0.05, 0, 0.14, d / 2 - 0.1), C.WOOD), 0)
	m.box_c(-w / 2, w / 2, -d / 2, d / 2)
	m.anchor("seat", Vector3(0, h + 0.04, 0))

# 한데부뚜막: 흙·돌 아궁이 + 무쇠 가마솥 + 나무 솥뚜껑. 불 자리 = torch 조명
static func gamasot(m: C.M, fire := true) -> void:
	var R := m.rng
	m.add("p", "mud", C.P(Kit.cyl(0.62, 0.7, 0.62, 8, 0, 0.31, 0), 0xb59a72, 0x8a7254, 0.05, R), 0.025)
	m.add("p", "stone", C.P(Kit.cyl(0.66, 0.66, 0.08, 8, 0, 0.62, 0), 0xa39a86, 0x857c6a), 0.015)
	# 가마솥(반구) + 전 + 뚜껑
	var pot := C.sphere(0.48, 10, 4, 0, TAU, PI / 2, PI / 2)
	m.add("p", "smooth", C.P(Kit.xf(pot, 0, 0.72, 0), 0x3a3633, 0x23201e), 0)
	m.add("p", "flat", C.P(Kit.cyl(0.56, 0.56, 0.04, 10, 0, 0.72, 0), 0x2d2a28), 0.012)
	m.add("p", "wood", C.P(Kit.cyl(0.36, 0.46, 0.12, 10, 0, 0.8, 0), 0x3a3430, 0x2a2522), 0.012)
	m.add("p", "flat", C.P(Kit.cyl(0.07, 0.07, 0.06, 6, 0, 0.89, 0), 0x2a2522), 0)
	# 아궁이(앞 +z)
	m.add("p", "flat", C.P(Kit.box(0.42, 0.32, 0.06, 0, 0.18, 0.66), 0x1e1814), 0)
	if fire:
		m.add("p", "glow", C.P(Kit.xf(Kit.lump(0.11, 0, R, 0.3, 0.6), 0, 0.08, 0.66), 0xffb84a, 0xff6a20), 0)
		m.light(0, 0.3, 0.75, "torch")
	# 장작 두어 개
	for i in 2: m.add("p", "wood", C.P(Kit.cyl(0.05, 0.05, 0.7, 5, -0.15 + i * 0.3, 0.05, 0.9, PI / 2, 0.3 - i * 0.6, 0), 0x9a7852, 0x6b5038), 0.01)
	m.circle(0, 0, 0.7)
	m.anchor("cook", Vector3(0, 0, 1.1))

# 주막 표시 장대: 장대 끝에 용수(술 거르는 대바구니)를 거꾸로 매달고, 아래 흰 천 한 폭(가설)
static func yongsu(m: C.M, cloth := true) -> void:
	var R := m.rng
	m.add("p", "wood", C.P(Kit.cyl(0.045, 0.06, 3.6, 5, 0, 1.8, 0), 0x8a6a48, 0x5e442e), 0.012)
	m.add("p", "wood", C.P(Kit.box(0.9, 0.05, 0.05, 0.4, 3.45, 0), 0x6b5038), 0.008)
	m.add("p", "flat", C.P(Kit.cyl(0.008, 0.008, 0.3, 3, 0.75, 3.3, 0), 0x2d2520), 0)
	# 용수: 위가 좁은 원통 대바구니(거꾸로)
	m.add("p", "thatch", C.P(Kit.cyl(0.12, 0.2, 0.62, 8, 0.75, 2.85, 0), 0xc8ad6e, 0x9a8050, 0.05, R), 0.015)
	if cloth:
		var g := C.vplane(0.42, 1.1, 0.0, 0, 0)
		Kit.xf(g, 0.3, 2.2, 0.06, 0, 0, 0.04)
		m.add("p", "cloth", C.P(g, 0xf0ead8, 0xd8ccb0), 0.008)
	for i in 4: m.add("p", "stone", C.PA(Kit.xf(Kit.lump(0.14, 0, R, 0.3, 0.6), cos(i * 1.6) * 0.2, 0.05, sin(i * 1.6) * 0.2), C.STONE), 0)
	m.circle(0, 0, 0.25)
	m.light(0.75, 2.7, 0.1, "lantern")

# 절구(통나무 절구) + 공이
static func jeolgu(m: C.M) -> void:
	var pts := []
	for q in [[0, 0], [0.26, 0], [0.22, 0.25], [0.2, 0.4], [0.27, 0.62], [0.2, 0.64], [0, 0.5]]: pts.append(Vector2(q[0], q[1]))
	m.add("p", "wood", C.P(C.lathe(pts, 8), 0x8a6a48, 0x5e442e, 0.04, m.rng), 0.015)
	m.add("p", "wood", C.P(Kit.xf(Kit.cyl(0.05, 0.05, 1.3, 6), 0.32, 0.62, -0.05, 0, 0, 0.35), 0x9a7852, 0x7a5c3e), 0.01)
	m.circle(0, 0, 0.32)

# 맷돌: 아래·위 돌 + 손잡이, 함지 위
static func maetdol(m: C.M) -> void:
	m.add("p", "wood", C.P(Kit.cyl(0.48, 0.42, 0.14, 10, 0, 0.07, 0), 0x8a6a48, 0x6b5038), 0.012)
	m.add("p", "stone", C.P(Kit.cyl(0.3, 0.32, 0.12, 10, 0, 0.2, 0), 0x9d978a, 0x77726a), 0.015)
	m.add("p", "stone", C.P(Kit.cyl(0.29, 0.3, 0.12, 10, 0, 0.32, 0), 0xa8a295, 0x8a857b), 0.015)
	m.add("p", "wood", C.P(Kit.cyl(0.025, 0.025, 0.3, 5, 0.33, 0.45, 0, 0, 0, 0.0), 0x6b5038), 0.006)
	m.add("p", "wood", C.P(Kit.box(0.22, 0.04, 0.04, 0.2, 0.32, 0), 0x6b5038), 0)
	m.circle(0, 0, 0.45)

static func dok(m: C.M, n := 3) -> void:
	for i in n:
		var a := float(i) / maxi(n, 1) * TAU + 0.4
		var rr := 0.3 + m.r() * 0.1
		J.jar(m, "p", cos(a) * 0.38 * mini(n - 1, 1), 0, sin(a) * 0.3 * mini(n - 1, 1), rr, rr * 2.1)
	m.circle(0, 0, 0.6)

# 소쿠리(대바구니) + 담긴 것
static func soguri(m: C.M, fill := "grain") -> void:
	m.add("p", "thatch", C.P(Kit.cyl(0.36, 0.26, 0.16, 10, 0, 0.08, 0, 0, 0, 0, false), 0xc8ad6e, 0x9a8050), 0.012)
	var col: Array = { grain = [0xd8b860, 0xb89a48], cloth = [0xf0ead8, 0xd8d0bc], veg = [0x8a9a52, 0x6a7a3e], red = [0xb0503a, 0x8a3a2a] }.get(fill, [0xd8b860, 0xb89a48])
	m.add("p", "organic", C.PA(Kit.xf(C.sphere(0.32, 8, 3, 0, TAU, 0, PI / 2), 0, 0.1, 0, 0, 0, 0, 1, 0.35, 1), col, 0.06, m.rng), 0)

# 볏단 더미(가을걷이): 세운 볏단 몇 + 눕힌 볏단
static func byeotdan(m: C.M) -> void:
	var R := m.rng
	for i in 5:
		var x := -0.6 + i * 0.3 + (m.r() - 0.5) * 0.08
		m.add("p", "thatch", C.PA(Kit.xf(Kit.cyl(0.08, 0.15, 0.9, 6), x, 0.45, -0.25, (m.r() - 0.5) * 0.2, 0, (m.r() - 0.5) * 0.2), C.STRAW, 0.05, R), 0.012)
	for i in 3:
		m.add("p", "thatch", C.PA(Kit.xf(Kit.cyl(0.1, 0.14, 0.95, 6), -0.3 + i * 0.3, 0.12, 0.35, PI / 2, 0.15 * (i - 1), 0), C.STRAW, 0.05, R), 0.012)
	m.circle(0, 0, 0.8)

# 허수아비(웹 index.js 그대로)
static func scarecrow(m: C.M) -> void:
	m.add("p", "flat", C.P(Kit.cyl(0.04, 0.05, 1.9, 5, 0, 0.95, 0), 0x6b5038), 0.01)
	m.add("p", "flat", C.P(Kit.box(1.5, 0.06, 0.06, 0, 1.45, 0), 0x6b5038), 0.01)
	m.add("p", "flat", C.P(Kit.box(0.6, 0.7, 0.25, 0, 1.25, 0), 0x8a8472, 0x6e6858, 0.05, m.rng), 0.015)
	m.add("p", "thatch", C.P(Kit.cone(0.45, 0.35, 10, 0, 1.95, 0), 0xcdb57a, 0x9d8656), 0.015)
	m.add("p", "thatch", C.P(Kit.xf(C.sphere(0.17, 8, 6), 0, 1.72, 0), 0xd8c48f), 0.01)
	m.circle(0, 0, 0.15)

# 멍석: 짚 멍석 펴고 곡식 널기 + 말아 둔 멍석 하나
static func meongseok(m: C.M) -> void:
	m.add("p", "thatch", C.P(Kit.box(2.0, 0.03, 1.4, 0, 0.015, 0), 0xc8b07a, 0xb09868), 0.008)
	m.add("p", "organic", C.P(Kit.box(1.7, 0.02, 1.1, 0, 0.04, 0), 0xcdb46e, 0xb89e58, 0.06, m.rng), 0)
	m.add("p", "thatch", C.P(Kit.cyl(0.16, 0.16, 1.4, 8, 1.25, 0.16, 0, PI / 2, 0, 0), 0xc8b07a, 0x9d8656), 0.012)
	m.add("p", "wood", C.P(Kit.xf(Kit.box(0.5, 0.03, 0.08), 0.3, 0.06, 0.2, 0, 0.6, 0), 0x8a6a48), 0.006)
