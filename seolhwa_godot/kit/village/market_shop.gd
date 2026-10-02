# 장터 가게(가가·가겟집) — 3칸 트인 초가 맞배 헛집 + 거적 차양 + 판매대 + 물건.
# 고증: 조선 후기 장시(5일장)의 상설 점포는 드물고 '가가(假家)'라 부른 허술한 초가 임시 가게가 장터 가에 섰다.
#   읍내(남원) 장터에는 객주·여각이 낀 상설 가게도 있었다(가설: 남원 읍내장 규모로 추정).
# params: seed, w(6), d(3), goods:"onggi"|"cloth"|"grain"|"straw"|"fish"|"mixed"
extends RefCounted
const C := preload("res://kit/village/_common.gd")
const PR := preload("res://kit/village/props.gd")
const J := preload("res://kit/village/jangdok.gd")

static func build(params: Dictionary) -> Dictionary:
	var m := C.M.new(int(params.get("seed", 1)))
	var W: float = params.get("w", 6.0); var D: float = params.get("d", 3.0)
	draw(m, W, D, params.get("goods", "mixed"))
	return m.result("장터가게", Vector2(W + 1.0, D + 3.4))

static func draw(m: C.M, W: float, D: float, kind: String) -> void:
	var R := m.rng
	var zf := D / 2; var hgt := 2.2
	m.add("p", "mud", C.P(Kit.box(W + 0.4, 0.2, D + 0.4, 0, 0.1, 0), 0xb9a27a, 0x9a845e, 0.04, R), 0.02)
	for i in 4:
		var x := -W / 2 + i * W / 3
		m.add("p", "wood", C.PA(Kit.box(0.18, hgt, 0.18, x, hgt / 2 + 0.2, zf), C.WOOD), 0.02)
		m.add("p", "wood", C.PA(Kit.box(0.18, hgt, 0.18, x, hgt / 2 + 0.2, -zf), C.WOOD), 0.02)
	m.add("p", "mud", C.PA(Kit.box(W, hgt, 0.14, 0, hgt / 2 + 0.2, -zf), C.MUD, 0.04, R), 0.02)
	for s in [-1, 1]: m.add("p", "mud", C.PA(Kit.box(0.14, hgt, D, s * W / 2, hgt / 2 + 0.2, 0), C.MUD, 0.04, R), 0.02)
	m.add("p", "wood", C.PA(Kit.box(W + 0.3, 0.16, 0.2, 0, hgt + 0.25, zf), C.WOOD), 0.02)
	C.thatch_gable(m, "p", W + 1.0, D + 1.2, hgt + 0.3, 1.0)
	# 거적 차양: 처마 앞에서 장대 둘까지 비스듬히
	var az := zf + 1.0; var ay := 2.0
	var g := Kit.Geo.new()
	var a := Vector3(-W / 2 + 0.2, hgt + 0.15, zf + 0.5); var b := Vector3(W / 2 - 0.2, hgt + 0.15, zf + 0.5)
	var c := Vector3(W / 2 - 0.2, ay, az); var d := Vector3(-W / 2 + 0.2, ay, az)
	g.quad(d, c, b, a)
	g.quad(a, b, c + Vector3(0, -0.04, 0), d + Vector3(0, -0.04, 0))
	m.add("p", "thatch", C.P(g, 0xcbb47e, 0xa8905e, 0.04, R), 0.02)
	for s in [-1, 1]: m.add("p", "wood", C.P(Kit.cyl(0.04, 0.05, ay, 5, s * (W / 2 - 0.25), ay / 2, az), 0x7a5c3e), 0.01)
	# 판매대: 돌 받침 위 널
	# 판매대는 차양 앞(길 쪽)으로 내어 놓아 위에서도 물건이 보이게
	var cz := az + 0.55
	m.add("p", "wood", C.PA(Kit.box(W - 0.6, 0.08, 0.9, 0, 0.7, cz), C.WOOD_L, 0.04, R), 0.015)
	for s in [-1, 0, 1]: m.add("p", "stone", C.PA(Kit.box(0.3, 0.5, 0.6, s * (W / 2 - 0.7), 0.25, cz), C.STONE), 0)
	goods(m, kind, W - 0.8, 0.74, cz)
	# 안쪽 선반에 독 몇 개
	for i in 2: J.jar(m, "p", -W / 4 + i * W / 2, 0.2, -zf + 0.5, 0.32, 0.7)
	m.box_c(-W / 2 - 0.2, W / 2 + 0.2, -zf - 0.2, zf + 0.2)
	m.box_c(-W / 2 + 0.3, W / 2 - 0.3, cz - 0.45, cz + 0.45)
	for s in [-1, 1]: m.circle(s * (W / 2 - 0.25), az, 0.15)
	m.light(0, ay + 0.1, az - 0.3, "lantern")
	m.anchor("seller", Vector3(0, 0, az - 0.5))
	m.anchor("buyer", Vector3(0, 0, cz + 1.0))

# 물건 늘어놓기: 폭 w, 높이 y, 중심 z
static func goods(m: C.M, kind: String, w: float, y: float, z: float) -> void:
	var R := m.rng
	var kinds := ["onggi", "cloth", "grain", "straw", "fish"]
	var n := maxi(3, int(w / 0.5))
	for i in n:
		var k: String = kind if kind != "mixed" else kinds[(i / 2) % kinds.size()]
		var x := -w / 2 + (i + 0.5) * w / n
		match k:
			"onggi":
				var rr := 0.16 + m.r() * 0.06
				J.jar(m, "p", x, y, z + (m.r() - 0.5) * 0.3, rr, rr * 1.9)
			"cloth":
				var cols := [0xece6d4, 0x3f5f7a, 0xb59a5e, 0x8a3e3a, 0xd8d0bc]
				var cc: int = cols[int(m.r() * cols.size())]
				m.add("p", "cloth", C.P(Kit.cyl(0.11, 0.11, 0.7, 6, x, y + 0.11, z, PI / 2, 0, 0), cc, cc, 0.02, R), 0.01)
			"grain":
				var old := m.push(x, y, z)
				PR.soguri(m, ["grain", "red", "veg"][i % 3])
				m.pop(old)
			"straw":
				# 짚신·짚 꾸러미
				m.add("p", "thatch", C.PA(Kit.xf(Kit.box(0.14, 0.06, 0.32), x - 0.08, y + 0.04, z, 0, 0.2, 0), C.STRAW, 0.05, R), 0.006)
				m.add("p", "thatch", C.PA(Kit.xf(Kit.box(0.14, 0.06, 0.32), x + 0.1, y + 0.04, z + 0.05, 0, -0.1, 0), C.STRAW, 0.05, R), 0.006)
			"fish":
				# 굴비 두름: 새끼줄에 엮은 마른 생선
				for j in 3:
					m.add("p", "flat", C.P(Kit.xf(Kit.box(0.08, 0.03, 0.4), x - 0.12 + j * 0.12, y + 0.03, z, 0, 0.1 * (j - 1), 0), 0xc9b48a, 0x9a8460), 0.006)
