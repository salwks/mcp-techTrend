# 땅 꾸밈 생활 소품(visual-pass 2026-10-17) — 배치 로더가 집 뒤·옆에 저절로 놓는다(placement_loader._plan_dress). params.kind로 고른다.
#   laundry 빨랫줄(바지랑대 둘 + 줄 + 흰 빨래·무명 몇 폭) / tools 벽에 기댄 연장(가래·삽·대빗자루·도리깨) /
#   flowers 마당 꽃(봉숭아·맨드라미 — 붉은 빛 몇 점) / gochu 멍석에 넌 고추(붉은 빛 — 늦여름·가을 마당)
# 모두 작은 소품 예산(≤ 600 삼각형). 앞(+z)은 마당 쪽, 뒤(−z)가 벽 쪽.
extends RefCounted
const C := preload("res://kit/village/_common.gd")

const KINDS := ["laundry", "tools", "flowers", "gochu"]

static func build(params: Dictionary) -> Dictionary:
	var m := C.M.new(int(params.get("seed", 1)))
	var kind: String = params.get("kind", "laundry")
	var fp := Vector2(1, 1)
	match kind:
		"laundry": laundry(m); fp = Vector2(3.4, 0.7)
		"tools": tools(m); fp = Vector2(1.4, 0.6)
		"flowers": flowers(m); fp = Vector2(1.6, 0.9)
		"gochu": gochu(m); fp = Vector2(1.9, 1.3)
	return m.result("꾸밈_" + kind, fp, false)

# 빨랫줄: 바지랑대 둘(위 갈래) + 처진 줄(마디 넷) + 빨래 세 폭
static func laundry(m: C.M) -> void:
	var R := m.rng
	var L := 3.0
	var h := 1.75
	for s in [-1, 1]:
		m.add("p", "wood", C.P(Kit.cyl(0.03, 0.04, h, 5, s * L / 2, h / 2, 0, 0, 0, s * 0.04), 0x8a6a48, 0x5e442e), 0.01)
	var pts := []
	for i in 5:
		var t := float(i) / 4.0
		pts.append(Vector3(-L / 2 + t * L, h - 0.05 - sin(t * PI) * 0.16, 0))
	for i in 4:
		var a: Vector3 = pts[i]; var b: Vector3 = pts[i + 1]
		var mid := (a + b) * 0.5; var d := b - a
		m.add("p", "flat", C.P(Kit.cyl(0.008, 0.008, d.length(), 3, mid.x, mid.y, mid.z, 0, 0, -PI / 2 + atan2(d.y, d.x)), 0x3a3028), 0)
	var cols := [[0xf2ede0, 0xd9d0bb], [0xe9e2cf, 0xcfc4ab], [0xb9c4c8, 0x8e9aa0], [0xf2ede0, 0xd9d0bb]]
	var x := -L / 2 + 0.35
	for i in 3 + int(m.r() * 2.0):
		var w := 0.35 + m.r() * 0.35
		var hh := 0.45 + m.r() * 0.35
		if x + w > L / 2 - 0.2: break
		var t := (x + w / 2 + L / 2) / L
		var y := h - 0.05 - sin(t * PI) * 0.16
		var g := C.vplane(w, hh, 0, 0, 0)
		Kit.xf(g, x + w / 2, y - hh / 2, 0.01, (m.r() - 0.5) * 0.08, 0, (m.r() - 0.5) * 0.05)
		m.add("p", "cloth", C.PA(g, cols[i % cols.size()], 0.03, R), 0.008)
		x += w + 0.12 + m.r() * 0.2
	m.circle(-L / 2, 0, 0.12); m.circle(L / 2, 0, 0.12)

# 벽에 기댄 연장: 뒤(−z)로 기울인 자루 몇 + 머리
static func tools(m: C.M) -> void:
	var lean := 0.22
	# 가래(넓은 날)
	m.add("p", "wood", C.P(Kit.cyl(0.025, 0.025, 1.5, 5, -0.45, 0.75, -0.12, -lean, 0, 0.05), 0x9a7852, 0x6b5038), 0.008)
	m.add("p", "wood", C.P(Kit.xf(Kit.box(0.28, 0.32, 0.03), -0.45, 0.17, 0.05, -lean, 0, 0), 0x7a5c3e, 0x5e442e), 0.01)
	# 삽(쇠날)
	m.add("p", "wood", C.P(Kit.cyl(0.022, 0.022, 1.3, 5, -0.05, 0.68, -0.14, -lean, 0, -0.04), 0x9a7852, 0x6b5038), 0.008)
	m.add("p", "smooth", C.P(Kit.xf(Kit.box(0.2, 0.26, 0.02), -0.05, 0.13, 0.03, -lean, 0, 0), 0x55524e, 0x3a3836), 0.01)
	# 대빗자루(싸리)
	m.add("p", "wood", C.P(Kit.cyl(0.02, 0.02, 1.25, 5, 0.38, 0.75, -0.14, -lean, 0, 0.06), 0xb59a62, 0x8a7348), 0.008)
	m.add("p", "thatch", C.P(Kit.xf(Kit.cone(0.16, 0.5, 7), 0.38, 0.2, 0.0, PI - lean, 0, 0), 0xb8a070, 0x8a7348, 0.06, m.rng), 0.012)
	m.box_c(-0.65, 0.6, -0.3, 0.2)

# 마당 꽃: 봉숭아(분홍·붉은)·맨드라미(짙은 붉은 볏) 포기 몇 — 잎 덩이 + 꽃 점
static func flowers(m: C.M) -> void:
	var R := m.rng
	var reds := [[0xc0384a, 0x8a2433], [0xd65a7a, 0xa63a58], [0xa8202c, 0x701820], [0xe08a9a, 0xb86070]]
	for i in 5:
		var x := -0.6 + i * 0.3 + (m.r() - 0.5) * 0.1
		var z := (m.r() - 0.5) * 0.4
		var hh := 0.3 + m.r() * 0.25
		m.add("p", "organic", C.P(Kit.xf(Kit.lump(0.16 + m.r() * 0.06, 0, R, 0.35, 1.2), x, hh * 0.5, z), 0x5f7a3c, 0x3e5428, 0.06, R), 0.01)
		var col: Array = reds[int(m.r() * reds.size()) % reds.size()]
		for k in 2 + int(m.r() * 2.0):
			m.add("p", "flat", C.PA(Kit.xf(Kit.lump(0.05 + m.r() * 0.03, 0, R, 0.3), x + (m.r() - 0.5) * 0.22, hh + m.r() * 0.08, z + (m.r() - 0.5) * 0.2), col, 0.05, R), 0)
	# 돌 테두리 몇
	for i in 6: m.add("p", "stone", C.PA(Kit.xf(Kit.lump(0.08, 0, R, 0.3, 0.6), -0.75 + i * 0.3, 0.03, 0.38), C.STONE), 0)

# 멍석에 넌 고추: 짚 멍석 + 붉은 고추 무더기(작은 덩이 여럿)
static func gochu(m: C.M) -> void:
	var R := m.rng
	m.add("p", "thatch", C.P(Kit.box(1.7, 0.03, 1.1, 0, 0.015, 0), 0xc8b07a, 0xb09868), 0.008)
	for i in 26:
		var x := (m.r() - 0.5) * 1.45; var z := (m.r() - 0.5) * 0.9
		var g := Kit.cyl(0.018, 0.026, 0.1, 4, x, 0.045, z, PI / 2, m.r() * TAU, 0)
		m.add("p", "flat", C.P(g, 0xb83226, 0x7e2018), 0)
	m.add("p", "thatch", C.P(Kit.cyl(0.11, 0.11, 1.1, 8, 0.95, 0.11, 0, PI / 2, PI / 2, 0), 0xb09868, 0x8a7348), 0.01)
