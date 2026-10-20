# 건물 빌더 가구·살림(실내) — 방 쓰임(role)·신분(cls)에 따라 벽을 따라 늘어놓는다.
# 모든 함수는 (m, part, x, y, z, ry) — 바닥 위 자리(y = 바닥 높이), ry = 앞(+z 로컬)이 방 안쪽을 보게.
# 반닫이 · 이불장(농) · 이불 더미 · 병풍 · 서안 · 연상 · 등잔 · 소반 · 문갑 · 사방탁자 · 시렁 · 독 · 뒤주 · 보료 · 목침 · 부뚜막+솥 · 살강 · 물독
extends RefCounted
const C := preload("res://kit/village/_common.gd")
const A := preload("res://kit/bldg/_atlas.gd")

const WOOD_D := [0x5c3c26, 0x43291a]
const WOOD_M := [0x7a5234, 0x5e3e26]
const BRASS := 0xc9a348
const IBUL := [0xa8483a, 0x3f5f7a, 0xe2d8bf, 0xc9a34a, 0x6a7a4a, 0xd8a0a0]

static func _at(m: C.M, x: float, y: float, z: float, ry: float) -> Transform3D:
	return m.push(x, y, z, ry)

# 반닫이: 앞판 위 반이 열리는 궤 + 놋쇠 장석. 위에 이불(선택)
static func bandaji(m: C.M, part: String, x: float, y: float, z: float, ry: float, ibul := 0) -> void:
	var o := _at(m, x, y, z, ry)
	m.add(part, "wood", C.PA(Kit.box(1.0, 0.68, 0.48, 0, 0.36, 0), WOOD_D, 0.03, m.rng), 0.015)
	m.add(part, "flat", C.P(Kit.box(1.04, 0.04, 0.5, 0, 0.72, 0), 0x3e2717), 0.01)
	for dx in [-0.32, 0.0, 0.32]: m.add(part, "flat", C.P(Kit.box(0.1, 0.12, 0.02, dx, 0.5, 0.245), BRASS), 0)
	m.add(part, "flat", C.P(Kit.box(0.94, 0.02, 0.02, 0, 0.4, 0.245), BRASS), 0)
	for i in ibul:
		var c: int = IBUL[(i + int(m.r() * 3)) % IBUL.size()]
		m.add(part, "cloth", C.P(Kit.box(0.9 - i * 0.03, 0.11, 0.46, 0, 0.8 + i * 0.11, 0), c, c, 0.03), 0)
	m.box_c(-0.52, 0.52, -0.26, 0.26)
	m.pop(o)

# 이불장(2층 농): 문짝 두 칸 + 장석, 위에 개켜 둔 이불
static func ibuljang(m: C.M, part: String, x: float, y: float, z: float, ry: float) -> void:
	var o := _at(m, x, y, z, ry)
	for k in 2:
		m.add(part, "wood", C.PA(Kit.box(1.1, 0.62, 0.5, 0, 0.33 + k * 0.64, 0), WOOD_M, 0.03, m.rng), 0.015)
		for dx in [-0.27, 0.27]:
			m.add(part, "flat", C.P(Kit.box(0.46, 0.46, 0.02, dx, 0.33 + k * 0.64, 0.255), 0x6a4630, 0x5a3a26), 0)
			m.add(part, "flat", C.P(Kit.box(0.06, 0.08, 0.02, dx + (0.17 if dx < 0 else -0.17), 0.33 + k * 0.64, 0.268), BRASS), 0)
	m.add(part, "wood", C.PA(Kit.box(1.16, 0.06, 0.54, 0, 1.31, 0), WOOD_D), 0.01)
	for i in 3:
		var c: int = IBUL[(i * 2 + int(m.r() * 4)) % IBUL.size()]
		m.add(part, "cloth", C.P(Kit.box(1.0, 0.12, 0.46, 0, 1.4 + i * 0.12, 0), c, c, 0.03), 0)
	m.box_c(-0.58, 0.58, -0.27, 0.27)
	m.pop(o)

# 이불 더미(바닥에 개켜 쌓음)
static func ibul_pile(m: C.M, part: String, x: float, y: float, z: float, ry: float, n := 3) -> void:
	var o := _at(m, x, y, z, ry)
	for i in n:
		var c: int = IBUL[(i + int(m.r() * 6)) % IBUL.size()]
		m.add(part, "cloth", C.P(Kit.box(0.95 - i * 0.04, 0.13, 0.6, 0, 0.07 + i * 0.13, 0), c, c, 0.03), 0)
	m.pop(o)

# 병풍: 여덟 폭 지그재그(그림 폭은 흰 바탕 + 먹빛 줄)
static func byeongpung(m: C.M, part: String, x: float, y: float, z: float, ry: float, panels := 6, h := 1.35) -> void:
	var o := _at(m, x, y, z, ry)
	var pw := 0.42
	for i in panels:
		var px := (i - (panels - 1) / 2.0) * pw * 0.96
		var a := 0.22 if i % 2 == 0 else -0.22
		m.add(part, "flat", C.P(Kit.xf(Kit.box(pw, h, 0.03), px, h / 2 + 0.02, 0.0, 0, a, 0), 0xefe8d6, 0xe0d6be, 0.02), 0)
		m.add(part, "flat", C.P(Kit.xf(Kit.box(pw * 0.7, h * 0.55, 0.042), px, h * 0.55, 0.0, 0, a, 0), 0xd2c8ae, 0xb8ae96, 0.04), 0)
		m.add(part, "flat", C.P(Kit.xf(Kit.box(pw + 0.02, 0.05, 0.04), px, h + 0.03, 0, 0, a, 0), 0x3e2717), 0)
	m.pop(o)

# 서안(글 읽는 낮은 책상) + 책 몇 권 + 연상(벼루 상자)
static func seoan(m: C.M, part: String, x: float, y: float, z: float, ry: float) -> void:
	var o := _at(m, x, y, z, ry)
	m.add(part, "wood", C.PA(Kit.box(0.96, 0.04, 0.42, 0, 0.36, 0), WOOD_M, 0.02), 0.012)
	for sx in [-1, 1]:
		m.add(part, "wood", C.PA(Kit.box(0.04, 0.34, 0.38, sx * 0.44, 0.17, 0), WOOD_D), 0)
		m.add(part, "wood", C.PA(Kit.box(0.08, 0.06, 0.44, sx * 0.47, 0.41, 0), WOOD_D), 0)
	for i in 2: m.add(part, "flat", C.P(Kit.box(0.24, 0.025, 0.32, -0.2 + i * 0.03, 0.39 + i * 0.026, 0), 0xc9b98e, 0xa89870), 0)
	m.add(part, "flat", C.P(Kit.box(0.2, 0.08, 0.28, 0.28, 0.42, 0), 0x2c2420), 0)
	m.box_c(-0.5, 0.5, -0.22, 0.22)
	m.pop(o)

# 등잔(나무 등잔대 + 종지 + 불빛)
static func deungjan(m: C.M, part: String, x: float, y: float, z: float, lit := true) -> void:
	m.add(part, "wood", C.P(Kit.cyl(0.13, 0.16, 0.05, 8, x, y + 0.03, z), 0x5a3f2a), 0.01)
	m.add(part, "wood", C.P(Kit.cyl(0.025, 0.03, 0.6, 6, x, y + 0.33, z), 0x5a3f2a), 0)
	m.add(part, "flat", C.P(Kit.cyl(0.08, 0.05, 0.04, 8, x, y + 0.64, z), 0xe0d6be, 0xbfb49a), 0)
	if lit: m.add(part, "glow", C.P(Kit.cone(0.025, 0.08, 6, x, y + 0.7, z), 0xffd27a, 0xff9a3a), 0)
	m.circle(x, z, 0.16)

# 소반 + 그릇(사발·종지)
static func soban(m: C.M, part: String, x: float, y: float, z: float, bowls := 3, round_ := true) -> void:
	var r := 0.3 + m.r() * 0.08
	if round_: m.add(part, "wood", C.P(Kit.cyl(r, r, 0.04, 12, x, y + 0.27, z), 0x7a5234, 0x6a4428), 0.012)
	else: m.add(part, "wood", C.P(Kit.box(r * 1.9, 0.04, r * 1.4, x, y + 0.27, z), 0x7a5234, 0x6a4428), 0.012)
	m.add(part, "wood", C.P(Kit.cyl(r * 0.8, r * 0.75, 0.22, 8, x, y + 0.13, z, 0, 0, 0, false), 0x5c3c26, 0x43291a), 0)
	for i in bowls:
		var a := TAU * i / maxf(bowls, 1) + m.r()
		var bx := x + cos(a) * r * 0.5; var bz := z + sin(a) * r * 0.5
		m.add(part, "flat", C.P(Kit.cyl(0.07, 0.045, 0.06, 8, bx, y + 0.32, bz), 0xe8e2d2, 0xc8c0ac), 0)
	m.circle(x, z, r + 0.05)

# 문갑(낮고 긴 장) + 위 작은 소품
static func mungap(m: C.M, part: String, x: float, y: float, z: float, ry: float) -> void:
	var o := _at(m, x, y, z, ry)
	m.add(part, "wood", C.PA(Kit.box(1.5, 0.42, 0.34, 0, 0.22, 0), WOOD_M, 0.03, m.rng), 0.012)
	for i in 4:
		m.add(part, "flat", C.P(Kit.box(0.32, 0.3, 0.02, -0.54 + i * 0.36, 0.22, 0.17), 0x6a4630, 0x5a3a26), 0)
		m.add(part, "flat", C.P(Kit.box(0.04, 0.04, 0.02, -0.54 + i * 0.36, 0.22, 0.182), BRASS), 0)
	m.add(part, "onggi", C.P(Kit.cyl(0.06, 0.08, 0.18, 8, 0.5, 0.52, 0), 0x7a8a8a, 0x5a6a6a), 0)
	m.box_c(-0.76, 0.76, -0.18, 0.18)
	m.pop(o)

# 사방탁자(트인 선반 + 책·그릇)
static func sabang(m: C.M, part: String, x: float, y: float, z: float, ry: float) -> void:
	var o := _at(m, x, y, z, ry)
	for sx in [-1, 1]:
		for sz in [-1, 1]: m.add(part, "wood", C.PA(Kit.box(0.04, 1.3, 0.04, sx * 0.24, 0.65, sz * 0.18), WOOD_D), 0)
	for k in 4:
		m.add(part, "wood", C.PA(Kit.box(0.52, 0.03, 0.4, 0, 0.12 + k * 0.38, 0), WOOD_M), 0)
		if k > 0 and k < 3: m.add(part, "flat", C.P(Kit.box(0.3, 0.12, 0.26, -0.05, 0.2 + k * 0.38, 0), 0xc9b98e, 0x9a8a68), 0)
	m.box_c(-0.28, 0.28, -0.22, 0.22)
	m.pop(o)

# 시렁(벽에 건 장대 두 개) + 바구니·고리짝
static func sireong(m: C.M, part: String, x: float, y: float, z: float, ry: float, L := 1.6) -> void:
	var o := _at(m, x, y, z, ry)
	for k in 2: m.add(part, "wood", C.P(Kit.cyl(0.03, 0.03, L, 5, 0, 1.55, 0.06 + k * 0.22, 0, 0, PI / 2), 0x7a6040, 0x5a4630), 0)
	for i in 3:
		var px := -L / 2 + 0.3 + i * (L - 0.6) / 2.0
		if m.r() < 0.5: m.add(part, "thatch", C.PA(Kit.box(0.34, 0.2, 0.28, px, 1.68, 0.17), C.STRAW, 0.05), 0)
		else: m.add(part, "wood", C.P(Kit.box(0.36, 0.18, 0.26, px, 1.67, 0.17), 0x8a6a48, 0x6a5038), 0)
	m.pop(o)

# 뒤주(쌀 궤, 대청)
static func dwiju(m: C.M, part: String, x: float, y: float, z: float, ry: float) -> void:
	var o := _at(m, x, y, z, ry)
	m.add(part, "wood", C.PA(Kit.box(0.8, 0.7, 0.6, 0, 0.45, 0), WOOD_M, 0.03, m.rng), 0.014)
	for sx in [-1, 1]:
		for sz in [-1, 1]: m.add(part, "wood", C.PA(Kit.box(0.07, 0.12, 0.07, sx * 0.36, 0.06, sz * 0.26), WOOD_D), 0)
	m.add(part, "flat", C.P(Kit.box(0.3, 0.06, 0.02, 0, 0.62, 0.305), BRASS), 0)
	m.box_c(-0.42, 0.42, -0.32, 0.32)
	m.pop(o)

# 보료(두꺼운 요) + 안석(등받이)
static func boryo(m: C.M, part: String, x: float, y: float, z: float, ry: float) -> void:
	var o := _at(m, x, y, z, ry)
	m.add(part, "cloth", C.P(Kit.box(1.4, 0.08, 0.8, 0, 0.04, 0), 0x8a3e3a, 0x6e302c, 0.02), 0)
	m.add(part, "cloth", C.P(Kit.box(1.2, 0.36, 0.16, 0, 0.24, -0.34), 0x3f5f7a, 0x2e4658, 0.02), 0)
	m.pop(o)

# 목침 · 방석(봉놋방)
static func mokchim(m: C.M, part: String, x: float, y: float, z: float, n := 4) -> void:
	for i in n: m.add(part, "wood", C.P(Kit.box(0.24, 0.1, 0.12, x + i * 0.4, y + 0.05, z + (m.r() - 0.5) * 0.1), 0x8a6a48, 0x6a5038), 0)

static func bangseok(m: C.M, part: String, x: float, y: float, z: float) -> void:
	m.add(part, "cloth", C.P(Kit.box(0.55, 0.05, 0.55, x, y + 0.025, z), 0x8a3e3a, 0x6e302c, 0.03), 0)

# 독 · 항아리
static func dok(m: C.M, part: String, x: float, y: float, z: float, s := 1.0) -> void:
	var g := C.onggi(0.26 * s, 0.62 * s, 10)
	m.add(part, "onggi", C.PA(Kit.xf(g, x, y, z), C.ONGGI, 0.04, m.rng), 0.01)
	m.add(part, "onggi", C.P(Kit.cyl(0.17 * s, 0.2 * s, 0.05, 10, x, y + 0.64 * s, z), 0x5a3a28), 0)
	m.circle(x, z, 0.27 * s)

# 부엌 부뚜막: 길이 L(x), 깊이 0.8, 높이 0.62 — 앞(+z 로컬)에 아궁이, 위에 솥 n개
static func buttumak(m: C.M, part: String, x: float, y: float, z: float, ry: float, L := 2.0, n := 2, fire := false) -> void:
	var o := _at(m, x, y, z, ry)
	m.add(part, "mud", C.PA(Kit.box(L, 0.585, 0.8, 0, 0.2925, 0), [0xb59a72, 0x8a7254], 0.04, m.rng), 0.02)
	m.add(part, "mud", C.P(Kit.box(L + 0.04, 0.05, 0.84, 0, 0.62, 0), 0x9a8462, 0x7a6648), 0.01)
	for i in n:
		var px := -L / 2 + L * (i + 0.5) / n
		var pot := C.sphere(0.3, 10, 4, 0, TAU, PI / 2, PI / 2)
		m.add(part, "smooth", C.P(Kit.xf(pot, px, 0.68, 0), 0x3a3633, 0x23201e), 0)
		m.add(part, "flat", C.P(Kit.cyl(0.36, 0.36, 0.03, 10, px, 0.68, 0), 0x2d2a28), 0)
		m.add(part, "wood", C.P(Kit.cyl(0.24, 0.3, 0.08, 10, px, 0.74, 0), 0x3a3430, 0x2a2522), 0)
		m.add(part, "flat", C.P(Kit.box(0.34, 0.3, 0.04, px, 0.2, 0.41), 0x1e1814), 0)   # 아궁이
		if fire: m.add(part, "glow", C.P(Kit.xf(Kit.lump(0.08, 0, m.rng, 0.3, 0.6), px, 0.1, 0.4), 0xffb84a, 0xff6a20), 0)
	m.box_c(-L / 2, L / 2, -0.4, 0.4)
	m.pop(o)

# 살강(그릇 시렁): 두 단 + 사발·대접
static func salgang(m: C.M, part: String, x: float, y: float, z: float, ry: float, L := 1.4) -> void:
	var o := _at(m, x, y, z, ry)
	for k in 2:
		m.add(part, "wood", C.PA(Kit.box(L, 0.04, 0.32, 0, 1.0 + k * 0.42, 0.16), C.WOOD_L), 0)
		var nb := int(L / 0.2)
		for i in nb:
			m.add(part, "flat", C.P(Kit.cyl(0.08, 0.05, 0.07, 8, -L / 2 + 0.1 + i * 0.2, 1.06 + k * 0.42, 0.16), 0xe8e2d2, 0xc8c0ac), 0)
	for sx in [-1, 1]: m.add(part, "wood", C.PA(Kit.box(0.04, 0.6, 0.04, sx * L / 2, 1.2, 0.3), C.WOOD), 0)
	m.pop(o)

# 사당 제상 + 감실(신주 장)
static func jesang(m: C.M, part: String, x: float, y: float, z: float, ry: float) -> void:
	var o := _at(m, x, y, z, ry)
	m.add(part, "wood", C.PA(Kit.box(1.2, 1.1, 0.55, 0, 0.95, -0.35), [0x6a3a28, 0x4a2a1c]), 0.012)
	m.add(part, "flat", C.P(Kit.box(0.9, 0.7, 0.02, 0, 1.0, -0.07), 0xe8dcc0, 0xc8bca0), 0)
	m.add(part, "wood", C.PA(Kit.box(1.1, 0.05, 0.6, 0, 0.5, 0.35), WOOD_M), 0.012)
	for sx in [-1, 1]: m.add(part, "wood", C.PA(Kit.box(0.05, 0.48, 0.05, sx * 0.5, 0.24, 0.35), WOOD_D), 0)
	m.add(part, "flat", C.P(Kit.cyl(0.08, 0.06, 0.12, 8, 0, 0.6, 0.35), 0x6a6458), 0)
	m.box_c(-0.62, 0.62, -0.62, 0.65)
	m.pop(o)

# 불상 대좌(대웅전) — 간단한 금빛 좌상 덩이
static func buddha(m: C.M, part: String, x: float, y: float, z: float) -> void:
	m.add(part, "wood", C.P(Kit.box(1.8, 0.9, 1.4, x, y + 0.45, z), 0x8a3e2e, 0x6a2e22), 0.015)
	m.add(part, "flat", C.P(Kit.cyl(0.62, 0.7, 0.3, 10, x, y + 1.05, z), 0xc9a348, 0x9a7a30), 0.012)
	m.add(part, "flat", C.P(Kit.xf(C.sphere(0.48, 10, 6), x, y + 1.55, z, 0, 0, 0, 1, 1.15, 0.85), 0xd8b450, 0xa88a38), 0.012)
	m.add(part, "flat", C.P(Kit.xf(C.sphere(0.24, 8, 6), x, y + 2.25, z), 0xd8b450, 0xa88a38), 0.01)
	m.box_c(x - 0.95, x + 0.95, z - 0.75, z + 0.75)

# 관아 교의(의자) + 탁자
static func gyoui(m: C.M, part: String, x: float, y: float, z: float, ry: float) -> void:
	var o := _at(m, x, y, z, ry)
	m.add(part, "wood", C.PA(Kit.box(0.62, 0.06, 0.5, 0, 0.48, 0), [0x6a3a28, 0x4a2a1c]), 0.01)
	m.add(part, "wood", C.PA(Kit.box(0.62, 0.62, 0.05, 0, 0.82, -0.23), [0x6a3a28, 0x4a2a1c]), 0.01)
	for sx in [-1, 1]:
		for sz in [-1, 1]: m.add(part, "wood", C.PA(Kit.box(0.05, 0.48, 0.05, sx * 0.27, 0.24, sz * 0.2), WOOD_D), 0)
	m.add(part, "wood", C.PA(Kit.box(1.1, 0.06, 0.6, 0, 0.72, 0.75), [0x6a3a28, 0x4a2a1c]), 0.01)
	for sx in [-1, 1]: m.add(part, "wood", C.PA(Kit.box(0.06, 0.7, 0.5, sx * 0.5, 0.35, 0.75), WOOD_D), 0)
	m.box_c(-0.6, 0.6, -0.3, 1.1)
	m.pop(o)
