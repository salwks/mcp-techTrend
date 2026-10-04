# 상태 있는 프롭(PROP_MASTER §2·§3·§4 P0 + 시나리오에 쓰는 몇) — params.kind로 고르고, 배치 항목 state(또는 world.set_prop_state)로 모양이 바뀐다.
# 소품 예산 ≤ 800삼각형(상태 부분 합쳐서). 원점 = 바닥 중심, 정면 +z.
#
# kind(PROP id) : 상태들(첫 번째가 기본)
#   agungi(HOME_001 아궁이·솥)      NORMAL 식은 솥 / USED 불 땜(불·김) / EMPTY 솥 없음·재 / BROKEN 솥 엎어짐
#   bapsang(HOME_002 밥상)           NORMAL 차린 상 / USED 먹다 만 상 / EMPTY 빈 그릇 / FALLEN 엎어진 상
#   jangdok(HOME_003 장독 셋)        NORMAL 뚜껑 덮음 / OPEN 뚜껑 열림 / BROKEN 하나 깨짐
#   muldongi(HOME_004 물동이)        NORMAL / FALLEN 넘어짐(물 쏟음) / BROKEN 깨짐
#   mun(HOME_007 문·빗장)            SEALED 닫힘·빗장 / OPEN 열림 / BROKEN 부서짐(한 짝 떨어짐)
#   deungjan(HOME_009 등잔)          NORMAL 꺼짐 / USED 켜짐(불빛) / FALLEN 넘어짐(기름 쏟음)
#   jusang(TAV_001 주막 상차림)      NORMAL 술·안주 / USED 먹다 만 / EMPTY 빈 그릇
#   pyeongsang(TAV_002 평상)         NORMAL / BROKEN 다리 부러짐 / MOVED
#   chaeksang(OFF_001 책상·문갑)     NORMAL 정돈 / MOVED 흐트러짐(종이 흩어짐) / OPEN 문갑 열림
#   munseoham(OFF_001 문서함·궤)     SEALED 잠김 / OPEN 열림(문서) / EMPTY 열림·빈 / BURNT 그을림 / MOVED 엎어짐
#   jangbu(OFF_002 장부·문서 더미)    NORMAL 쌓임 / MOVED 흩어짐·찢김 / BURNT 탄 재·반쯤 탄 장부 / WET 젖음
#   meoktong(OFF_003 먹통·벼루·붓)    NORMAL / FALLEN 넘어짐·먹물 쏟음
#   chaekjang(OFF_006 책장)          NORMAL 가득 / EMPTY 빠진 칸 / FALLEN 책 쏟아짐
#   chaekdeomi(OFF_006 책더미)       NORMAL 쌓임 / FALLEN 무너짐
#   chatjan(OFF_007 찻잔·주전자)      NORMAL 식음 / USED 따뜻함(김)
#   kkeun(끈 — 묶인 끈)              NORMAL 기둥에 묶인 끈 / BROKEN 끊어진 끈
#   gamani(MKT_004 곡물가마니)        NORMAL 쌓임 / BROKEN 터짐(곡식 쏟음) / BURNT 그을림
#   gireumtong(기름통 — 최종장 화재)  NORMAL / MOVED 치움 / EMPTY 쓰러져 빔
#   jipsin(ROAD_003 짚신)            NORMAL 새것 한 켤레 / USED 낡음 / MOVED 한 짝만 버려짐
#   geumjul(RIT_002 금줄)            NORMAL 두 말뚝에 걸림 / BROKEN 끊어짐
#   jemul(RIT_001 제물상)            NORMAL 제물 / EMPTY 사라진 제물 / BROKEN 엎어짐
#   byeokjido(벽 지도)               NORMAL / BURNT 반쯤 탐 / MOVED 찢겨 떨어짐   (벽에 붙는 판 — 원점 = 벽 앞 바닥, 판은 −z 벽)
#   hwaro(HOME_010 화로)             NORMAL 재 / USED 종이를 태우는 불(불·연기)
# params: seed, kind, indoor(건물 안 — 눈·젖음 안 받음), (pyeongsang) w, d / (jangbu) n / (chaekjang) w
extends RefCounted
const SC := preload("res://kit/scenario/_sc.gd")
const C := preload("res://kit/village/_common.gd")
const J := preload("res://kit/village/jangdok.gd")

const BOWL := [0xe8e2d2, 0xc8c0ac]
const BRASS := [0xc9a24a, 0x8a6a2a]
const FOOD := [[0xf2ede0, 0xd8d0bc], [0x8a9a52, 0x6a7a3e], [0xb0503a, 0x8a3a2a], [0xc8a060, 0xa88040]]

static func build(params: Dictionary) -> Dictionary:
	var s := SC.S.new(int(params.get("seed", 1)))
	s.all_indoor = bool(params.get("indoor", false))   # 건물 안에 놓는 소품: 눈·젖음을 받지 않게
	var kind: String = params.get("kind", "bapsang")
	var fp := Vector2(1, 1)
	match kind:
		"agungi": fp = agungi(s)
		"bapsang": fp = bapsang(s)
		"jangdok": fp = jangdok(s)
		"muldongi": fp = muldongi(s)
		"mun": fp = mun(s)
		"deungjan": fp = deungjan(s)
		"jusang": fp = jusang(s)
		"pyeongsang": fp = pyeongsang(s, float(params.get("w", 2.0)), float(params.get("d", 1.3)))
		"chaeksang": fp = chaeksang(s)
		"munseoham": fp = munseoham(s)
		"jangbu": fp = jangbu(s, int(params.get("n", 6)))
		"meoktong": fp = meoktong(s)
		"chaekjang": fp = chaekjang(s, float(params.get("w", 1.6)))
		"chaekdeomi": fp = chaekdeomi(s)
		"chatjan": fp = chatjan(s)
		"kkeun": fp = kkeun(s)
		"gamani": fp = gamani(s)
		"gireumtong": fp = gireumtong(s)
		"jipsin": fp = jipsin(s)
		"geumjul": fp = geumjul(s, float(params.get("w", 3.0)))
		"jemul": fp = jemul(s)
		"byeokjido": fp = byeokjido(s)
		"hwaro": fp = hwaro(s)
		_: push_warning("scenario/props: 모르는 kind " + kind)
	return s.result("prop_" + kind, fp, false)

# ---- 공통 조각 ----
static func bowl(p, x: float, y: float, z: float, r := 0.07, fill = null) -> void:
	p.add("smooth", SC.pa(Kit.cyl(r, r * 0.65, r * 0.8, 8, x, y + r * 0.4, z, 0, 0, 0, false), BOWL), 0.006)
	if fill != null: p.add("organic", SC.pa(Kit.cyl(r * 0.9, r * 0.9, 0.01, 8, x, y + r * 0.75, z), fill), 0.0)

static func cup(p, x: float, y: float, z: float) -> void:
	p.add("smooth", SC.pa(Kit.cyl(0.035, 0.028, 0.05, 7, x, y + 0.025, z), BOWL), 0.004)

static func small_table(p, w: float, d: float, h: float, cols := [0x8a5a34, 0x6a4428]) -> void:
	p.add("wood", SC.pa(Kit.box(w, 0.04, d, 0, h, 0), cols), 0.012)
	p.add("wood", SC.pa(Kit.box(w - 0.04, 0.06, d - 0.04, 0, h - 0.05, 0), cols), 0.0)
	for q in [[-1, -1], [1, -1], [-1, 1], [1, 1]]:
		p.add("wood", SC.pa(Kit.box(0.04, h - 0.06, 0.04, q[0] * (w / 2 - 0.06), (h - 0.06) / 2, q[1] * (d / 2 - 0.06)), cols), 0.0)

static func paper_sheet(p, x: float, y: float, z: float, ry := 0.0, w := 0.26, d := 0.36, col := SC.PAPER) -> void:
	p.add("flat", SC.pa(Kit.xf(Kit.box(w, 0.006, d), x, y, z, 0, ry, 0), col, 0.03), 0.0)

static func book(p, x: float, y: float, z: float, ry := 0.0, col := 0x8a6a40) -> void:
	p.add("flat", C.P(Kit.xf(Kit.box(0.2, 0.025, 0.3), x, y + 0.0125, z, 0, ry, 0), col, col - 0x101010 if col > 0x101010 else col), 0.004)

# ---- 집 ----
static func agungi(s: SC.S) -> Vector2:
	var p := s.p("p")
	var R := s.rng
	# 부뚜막(흙) + 아궁이 구멍
	p.add("mud", SC.pa(Kit.box(1.3, 0.6, 0.9, 0, 0.3, 0), [0xb59a72, 0x8a7254], 0.05, R), 0.02)
	p.add("flat", C.P(Kit.box(0.4, 0.3, 0.04, 0, 0.18, 0.46), 0x1e1814), 0.0)
	var pot := C.sphere(0.36, 10, 4, 0, TAU, PI / 2, PI / 2)
	var normal := s.st("main", ["NORMAL", "USED"], "NORMAL")
	normal.add("smooth", C.P(Kit.xf(pot.copy(), 0, 0.62, 0), 0x3a3633, 0x23201e), 0.0)
	normal.add("flat", C.P(Kit.cyl(0.42, 0.42, 0.03, 10, 0, 0.62, 0), 0x2d2a28), 0.01)
	normal.add("wood", C.P(Kit.cyl(0.27, 0.35, 0.1, 10, 0, 0.68, 0), 0x3a3430, 0x2a2522), 0.01)
	var used := s.st("main", "USED")
	used.add("glow", C.P(Kit.xf(Kit.lump(0.1, 0, R, 0.3, 0.6), 0, 0.08, 0.44), 0xffb84a, 0xff6a20), 0.0)
	s.fx("main", "USED", { type = "fire", x = 0.0, y = 0.08, z = 0.5, size = 0.12, k = 0.35, light = true })
	s.fx("main", "USED", { type = "steam", x = 0.0, y = 0.78, z = 0.0, size = 0.15 })
	var empty := s.st("main", "EMPTY")
	empty.add("flat", C.P(Kit.cyl(0.34, 0.34, 0.02, 10, 0, 0.6, 0), 0x1a1614), 0.0)
	empty.add("organic", C.P(Kit.xf(Kit.lump(0.16, 0, R, 0.3, 0.3), 0.05, 0.03, 0.62), 0x8a8580, 0x5a5652), 0.0)
	var broken := s.st("main", "BROKEN")
	broken.add("flat", C.P(Kit.cyl(0.34, 0.34, 0.02, 10, 0, 0.6, 0), 0x1a1614), 0.0)
	broken.add("smooth", C.P(Kit.xf(pot.copy(), 0.95, 0.3, 0.2, 0, 0, 1.9), 0x3a3633, 0x23201e), 0.0)
	broken.add("wood", C.P(Kit.xf(Kit.cyl(0.27, 0.35, 0.08, 10), -0.8, 0.04, 0.5, 0.2, 0, 0.1), 0x3a3430), 0.008)
	s.box_c(-0.65, 0.65, -0.45, 0.45)
	s.anchor("fire", Vector3(0, 0, 0.9))
	return Vector2(1.4, 1.0)

static func bapsang(s: SC.S) -> Vector2:
	var tbl := s.st("main", ["NORMAL", "USED", "EMPTY"], "NORMAL")
	small_table(tbl, 0.7, 0.5, 0.3)
	var n := s.st("main", "NORMAL")
	var u := s.st("main", "USED")
	var e := s.st("main", "EMPTY")
	var spots := [[-0.2, -0.1], [0.0, -0.12], [0.2, -0.1], [-0.12, 0.1], [0.14, 0.1]]
	for i in spots.size():
		var q: Array = spots[i]
		bowl(n, q[0], 0.32, q[1], 0.065, FOOD[i % FOOD.size()])
		bowl(e, q[0], 0.32, q[1], 0.065)
		if i % 2 == 0: bowl(u, q[0], 0.32, q[1], 0.065, FOOD[i % FOOD.size()])
		else: bowl(u, q[0], 0.32, q[1], 0.065)
	u.add("flat", C.P(Kit.xf(Kit.box(0.2, 0.01, 0.02), 0.1, 0.33, 0.18, 0, 0.4, 0), 0xc9a24a), 0.0)
	var f := s.st("main", "FALLEN")
	var t2 := Kit.box(0.7, 0.04, 0.5, 0, 0, 0)
	f.add("wood", SC.pa(Kit.xf(t2, 0.1, 0.25, -0.05, 1.3, 0.2, 0), [0x8a5a34, 0x6a4428]), 0.012)
	for k in 3: bowl(f, -0.3 + k * 0.28, 0.0, 0.25 + 0.05 * k, 0.065)
	f.add("organic", SC.pa(Kit.box(0.5, 0.01, 0.3, -0.05, 0.005, 0.3), FOOD[0], 0.05), 0.0)
	s.box_c(-0.35, 0.35, -0.25, 0.25)
	s.anchor("seat", Vector3(0, 0, 0.6))
	return Vector2(0.8, 0.6)

static func jangdok(s: SC.S) -> Vector2:
	var p := s.p("p")
	var sizes := [[-0.35, -0.05, 0.3], [0.3, -0.1, 0.26], [0.0, 0.32, 0.2]]
	var nm := s.st("main", ["NORMAL", "OPEN"], "NORMAL")
	for i in sizes.size():
		var q: Array = sizes[i]
		var x: float = q[0]; var z: float = q[1]; var r: float = q[2]
		var h := r * 2.1
		_jar(nm if i == 0 else p, x, z, r, h)
		var lid := Kit.cyl(r * 0.62, r * 0.7, 0.06, 9, x, h + 0.02, z)
		if i == 0:
			s.st("main", "NORMAL").add("onggi", SC.pa(lid, SC.C.ONGGI), 0.006)
			s.st("main", "OPEN").add("onggi", SC.pa(Kit.xf(lid.copy(), r * 0.9, -h + 0.04, 0.15, 0, 0, 0.4), SC.C.ONGGI), 0.006)
		elif i == 1:
			s.st("main", ["NORMAL", "BROKEN"]).add("onggi", SC.pa(lid, SC.C.ONGGI), 0.006)
			s.st("main", "OPEN").add("onggi", SC.pa(Kit.xf(lid.copy(), 0.25, -h + 0.04, 0.35, 0, 0, -0.3), SC.C.ONGGI), 0.006)
		else:
			p.add("onggi", SC.pa(lid, SC.C.ONGGI), 0.006)
	# 깨진 독: 아래 반 + 조각들 + 쏟은 장
	var b := s.st("main", "BROKEN")
	b.add("onggi", SC.pa(Kit.cyl(0.3, 0.22, 0.25, 9, -0.35, 0.125, -0.05, 0, 0, 0, false), SC.C.ONGGI, 0.05), 0.008)
	for k in 6:
		var a := k * 1.1
		b.add("onggi", SC.pa(Kit.xf(Kit.box(0.14, 0.03, 0.1), -0.35 + cos(a) * 0.45, 0.02, -0.05 + sin(a) * 0.4, 0.3, a, 0.2), SC.C.ONGGI), 0.0)
	b.add("organic", C.P(Kit.box(0.7, 0.01, 0.5, -0.4, 0.006, 0.05), 0x4a2e1e, 0x3a2216), 0.0)
	s.circle(0, 0, 0.55)
	return Vector2(1.2, 1.0)

static func _jar(p, x: float, z: float, r: float, h: float) -> void:
	var pts := []
	for q in [[0, 0], [r * 0.7, 0], [r, h * 0.45], [r * 0.95, h * 0.7], [r * 0.6, h * 0.95], [r * 0.62, h], [0, h]]: pts.append(Vector2(q[0], q[1]))
	var g := C.lathe(pts, 10)
	Kit.xf(g, x, 0, z)
	p.add("onggi", SC.pa(g, SC.C.ONGGI, 0.05), 0.012)

static func muldongi(s: SC.S) -> Vector2:
	var pts := []
	for q in [[0, 0], [0.12, 0], [0.2, 0.15], [0.19, 0.27], [0.12, 0.36], [0.14, 0.4], [0, 0.4]]: pts.append(Vector2(q[0], q[1]))
	var jar := C.lathe(pts, 10)
	s.st("main", "NORMAL", "NORMAL").add("onggi", SC.pa(jar.copy(), [0x8a5a3a, 0x5a3a26], 0.04), 0.008)
	var f := s.st("main", "FALLEN")
	f.add("onggi", SC.pa(Kit.xf(jar.copy(), 0.0, 0.2, 0.0, PI / 2, 0.4, 0), [0x8a5a3a, 0x5a3a26], 0.04), 0.008)
	f.add("water", Kit.plane(0.9, 0.6, 0.3, 0.008, 0.3), 0.0)
	var b := s.st("main", "BROKEN")
	b.add("onggi", SC.pa(Kit.cyl(0.15, 0.12, 0.12, 9, 0, 0.06, 0, 0, 0, 0, false), [0x8a5a3a, 0x5a3a26]), 0.006)
	for k in 5: b.add("onggi", SC.pa(Kit.xf(Kit.box(0.1, 0.02, 0.08), cos(k * 1.3) * 0.3, 0.012, sin(k * 1.3) * 0.25, 0.2, k, 0), [0x8a5a3a, 0x5a3a26]), 0.0)
	s.circle(0, 0, 0.22)
	return Vector2(0.6, 0.6)

static func mun(s: SC.S) -> Vector2:
	var p := s.p("p")
	var w := 1.2; var h := 1.8
	p.add("wood", SC.pa(Kit.merge([Kit.box(0.12, h + 0.15, 0.14, -w / 2 - 0.06, (h + 0.15) / 2, 0), Kit.box(0.12, h + 0.15, 0.14, w / 2 + 0.06, (h + 0.15) / 2, 0), Kit.box(w + 0.36, 0.12, 0.16, 0, h + 0.1, 0)]), SC.WOOD), 0.015)
	var leaf := func(open_a: float, sgn: int) -> Kit.Geo:
		var g := Kit.box(w / 2 - 0.02, h - 0.05, 0.05, -sgn * (w / 4), 0, 0)
		return Kit.apply(g, Transform3D(Basis(Vector3.UP, open_a * sgn), Vector3(sgn * w / 2, h / 2 + 0.02, 0)))
	var sealed := s.st("main", "SEALED", "SEALED")
	for sg in [-1, 1]: sealed.add("wood", SC.pa(leaf.call(0.0, sg), [0x6a5240, 0x4e3c2e]), 0.01)
	sealed.add("wood", SC.pa(Kit.box(w + 0.1, 0.08, 0.06, 0, h * 0.5, 0.06), [0x4a3828, 0x3a2c20]), 0.0)
	var op := s.st("main", "OPEN")
	for sg in [-1, 1]: op.add("wood", SC.pa(leaf.call(-1.35, sg), [0x6a5240, 0x4e3c2e]), 0.01)
	op.add("wood", SC.pa(Kit.xf(Kit.box(w + 0.1, 0.08, 0.06), 0.9, 0.04, 0.6, 0, 0.5, 0), [0x4a3828]), 0.0)
	var br := s.st("main", "BROKEN")
	br.add("wood", SC.pa(leaf.call(-0.4, -1), [0x6a5240, 0x4e3c2e]), 0.01)
	br.add("wood", SC.pa(Kit.xf(Kit.box(w / 2 - 0.02, h - 0.05, 0.05), 0.4, 0.05, 0.9, PI / 2, 0.3, 0), [0x6a5240, 0x4e3c2e]), 0.01)
	for k in 3: br.add("wood", SC.pa(Kit.xf(Kit.box(0.04, 0.5, 0.04), 0.2 * k - 0.1, 0.02, 0.5 + 0.1 * k, PI / 2, k, 0), [0x6a5240]), 0.0)
	s.box_c(-w / 2 - 0.15, -w / 2 + 0.05, -0.1, 0.1)
	s.box_c(w / 2 - 0.05, w / 2 + 0.15, -0.1, 0.1)
	s.scol("main", "SEALED", { type = "box", minX = -w / 2, maxX = w / 2, minZ = -0.08, maxZ = 0.08 })
	s.anchor("front", Vector3(0, 0, 0.8)); s.anchor("back", Vector3(0, 0, -0.8))
	return Vector2(w + 0.4, 0.4)

static func deungjan(s: SC.S) -> Vector2:
	var stand := func(p, x, z, ry):
		p.add("wood", SC.pa(Kit.xf(Kit.cyl(0.13, 0.16, 0.04, 8), x, 0.02, z), [0x5a3f2a, 0x4a3220]), 0.008)
		p.add("wood", SC.pa(Kit.xf(Kit.cyl(0.02, 0.025, 0.55, 6), x, 0.3, z), [0x5a3f2a]), 0.006)
		p.add("smooth", SC.pa(Kit.xf(Kit.cyl(0.08, 0.05, 0.04, 8), x, 0.58, z), [0xe0d6be, 0xbfb49a]), 0.006)
	var up := s.st("main", ["NORMAL", "USED"], "NORMAL")
	stand.call(up, 0.0, 0.0, 0.0)
	s.st("main", "USED").add("glow", C.P(Kit.cone(0.025, 0.09, 6, 0, 0.65, 0), 0xffd27a, 0xff9a3a), 0.0)
	s.fx("main", "USED", { type = "light", x = 0.0, y = 0.75, z = 0.0, kind = "lantern" })
	var f := s.st("main", "FALLEN")
	var g := Kit.Geo.new()
	f.add("wood", SC.pa(Kit.xf(Kit.cyl(0.02, 0.025, 0.55, 6), 0.0, 0.03, 0.25, PI / 2, 0.6, 0), [0x5a3f2a]), 0.006)
	f.add("wood", SC.pa(Kit.xf(Kit.cyl(0.13, 0.16, 0.04, 8), 0.0, 0.02, 0.0), [0x5a3f2a, 0x4a3220]), 0.008)
	f.add("smooth", SC.pa(Kit.xf(Kit.cyl(0.08, 0.05, 0.04, 8), 0.2, 0.03, 0.5, 0, 0, 1.6), [0xe0d6be, 0xbfb49a]), 0.006)
	f.add("flat", C.P(Kit.box(0.35, 0.004, 0.25, 0.25, 0.004, 0.62), 0x3a3022), 0.0)
	s.circle(0, 0, 0.16)
	return Vector2(0.4, 0.4)

static func jusang(s: SC.S) -> Vector2:
	var t := s.p("p")
	small_table(t, 0.8, 0.55, 0.32, [0x7a4e2e, 0x5e3c22])
	var n := s.st("main", "NORMAL", "NORMAL")
	var u := s.st("main", "USED")
	var e := s.st("main", "EMPTY")
	# 술병 + 잔 둘 + 안주 접시
	var bottle := func(p, x, z, up := true):
		var pts := []
		for q in [[0, 0], [0.06, 0], [0.075, 0.08], [0.05, 0.15], [0.02, 0.19], [0.025, 0.22], [0, 0.22]]: pts.append(Vector2(q[0], q[1]))
		var g := C.lathe(pts, 8)
		if up: Kit.xf(g, x, 0.34, z)
		else: Kit.xf(g, x, 0.4, z, PI / 2, 0.5, 0)
		p.add("smooth", SC.pa(g, [0xdcd6c4, 0xb8b0a0]), 0.006)
	bottle.call(n, -0.22, -0.08); cup(n, 0.0, 0.34, 0.12); cup(n, 0.2, 0.34, 0.1); bowl(n, 0.15, 0.34, -0.1, 0.08, FOOD[2])
	bottle.call(u, -0.22, -0.08, false); cup(u, 0.05, 0.34, 0.1); bowl(u, 0.15, 0.34, -0.1, 0.08, FOOD[3])
	bowl(e, 0.15, 0.34, -0.1, 0.08); cup(e, 0.0, 0.34, 0.12)
	s.box_c(-0.4, 0.4, -0.28, 0.28)
	return Vector2(0.9, 0.7)

static func pyeongsang(s: SC.S, w: float, d: float) -> Vector2:
	var h := 0.45
	var n := s.st("main", ["NORMAL", "MOVED"], "NORMAL")
	n.add("wood", SC.pa(Kit.box(w, 0.08, d, 0, h, 0), SC.WOOD_L, 0.04), 0.02)
	for q in [[-1, -1], [1, -1], [-1, 1], [1, 1]]:
		n.add("wood", SC.pa(Kit.box(0.09, h, 0.09, q[0] * (w / 2 - 0.1), h / 2, q[1] * (d / 2 - 0.1)), SC.WOOD), 0.01)
	var b := s.st("main", "BROKEN")
	var top := Kit.box(w, 0.08, d, 0, 0, 0)
	b.add("wood", SC.pa(Kit.xf(top, 0, h * 0.55, 0, 0, 0, 0.42), SC.WOOD_L, 0.04), 0.02)
	for q in [[1, -1], [1, 1]]:
		b.add("wood", SC.pa(Kit.box(0.09, h, 0.09, q[0] * (w / 2 - 0.1), h / 2, q[1] * (d / 2 - 0.1)), SC.WOOD), 0.01)
	b.add("wood", SC.pa(Kit.xf(Kit.box(0.09, h, 0.09), -w / 2 - 0.2, 0.05, 0.4, PI / 2, 0.4, 0), SC.WOOD), 0.01)
	s.extra.move = Vector3(1.2, 0, 0.5)
	s.box_c(-w / 2, w / 2, -d / 2, d / 2)
	s.anchor("seat", Vector3(0, h + 0.04, 0))
	return Vector2(w, d)

# ---- 관아·책방 ----
static func chaeksang(s: SC.S) -> Vector2:
	var p := s.p("p")
	# 서안(낮은 책상) + 문갑
	var w := 0.95; var d := 0.45; var h := 0.32
	p.add("wood", SC.pa(Kit.box(w, 0.04, d, 0, h, 0), [0x6a4428, 0x4a2e1c]), 0.012)
	for sx in [-1, 1]:
		p.add("wood", SC.pa(Kit.box(0.05, h, d - 0.04, sx * (w / 2 - 0.05), h / 2, 0), [0x6a4428, 0x4a2e1c]), 0.006)
		p.add("wood", SC.pa(Kit.xf(Kit.box(0.04, 0.06, 0.1), sx * (w / 2 + 0.01), h + 0.03, 0, 0, 0, 0.3 * sx), [0x6a4428]), 0.0)
	# 문갑(옆 상자)
	p.add("wood", SC.pa(Kit.box(0.5, 0.4, 0.32, -0.85, 0.2, -0.05), [0x7a4e2e, 0x5a381e]), 0.012)
	var closed := s.st("main", ["NORMAL", "MOVED"], "NORMAL")
	closed.add("flat", SC.pa(Kit.box(0.42, 0.14, 0.02, -0.85, 0.28, 0.115), [0x5a381e]), 0.0)
	closed.add("flat", SC.pa(Kit.box(0.06, 0.04, 0.02, -0.85, 0.28, 0.13), BRASS), 0.0)
	var n := s.st("main", "NORMAL")
	paper_sheet(n, -0.15, h + 0.025, 0.0, 0.05)
	book(n, 0.25, h + 0.02, -0.05, 0.1, 0x3f5f7a)
	n.add("wood", SC.pa(Kit.xf(Kit.cyl(0.008, 0.008, 0.22, 4), 0.05, h + 0.03, 0.12, 0, 0, PI / 2), [0x3a2a1e]), 0.0)
	var mv := s.st("main", "MOVED")
	for k in 7:
		paper_sheet(mv, s.between(-0.9, 0.9), 0.012 + k * 0.001, s.between(0.2, 0.9), s.r() * 3.0)
	paper_sheet(mv, 0.1, h + 0.025, 0.05, 0.6)
	book(mv, 0.6, 0.0, 0.5, 0.8, 0x3f5f7a)
	var op := s.st("main", "OPEN")
	op.add("flat", SC.pa(Kit.box(0.42, 0.04, 0.3, -0.85, 0.27, 0.22), [0x5a381e]), 0.0)
	for k in 3: paper_sheet(op, -0.85 + (k - 1) * 0.1, 0.4 + k * 0.004, -0.05, 0.1 * k, 0.2, 0.28)
	s.box_c(-1.1, w / 2, -d / 2, d / 2)
	s.anchor("seat", Vector3(0, 0, 0.55))
	return Vector2(2.1, 0.6)

static func munseoham(s: SC.S) -> Vector2:
	var w := 0.9; var d := 0.5; var h := 0.5
	var body_cols := [0x6a4428, 0x4a2e1c]
	var shut := s.st("main", ["SEALED", "OPEN", "EMPTY", "BURNT"], "SEALED")
	shut.add("wood", SC.pa(Kit.box(w, h, d, 0, h / 2, 0), body_cols, 0.03), 0.012)
	# 장식 쇠(모서리) + 자물쇠
	var metal := []
	for sx in [-1, 1]: metal.append(Kit.box(0.08, h - 0.04, 0.02, sx * (w / 2 - 0.04), h / 2, d / 2 + 0.01))
	shut.add("flat", SC.pa(Kit.merge(metal), [0x3a3633, 0x2a2826]), 0.0)
	var sealed := s.st("main", "SEALED")
	sealed.add("wood", SC.pa(Kit.box(w + 0.02, 0.05, d + 0.02, 0, h + 0.025, 0), body_cols), 0.01)
	sealed.add("flat", SC.pa(Kit.box(0.08, 0.1, 0.03, 0, h - 0.05, d / 2 + 0.02), BRASS), 0.004)
	var lid := Kit.box(w + 0.02, 0.05, d + 0.02, 0, 0, d / 2)
	var lid_xf := Transform3D(Basis(Vector3.RIGHT, -1.9), Vector3(0, h + 0.02, -d / 2))
	var op := s.st("main", ["OPEN", "EMPTY"])
	op.add("wood", SC.pa(Kit.apply(lid.copy(), lid_xf), body_cols), 0.01)
	op.add("flat", C.P(Kit.box(w - 0.06, 0.02, d - 0.06, 0, h - 0.02, 0), 0x1e1814), 0.0)
	var docs := s.st("main", "OPEN")
	for k in 4: docs.add("flat", SC.pa(Kit.xf(Kit.box(0.26, 0.04, 0.34), -0.28 + k * 0.18, h - 0.02, 0, 0.1, 0.1 * k, 0), SC.PAPER), 0.0)
	var burnt := s.st("main", "BURNT")
	burnt.add("organic", SC.pa(Kit.box(w + 0.02, 0.06, d + 0.02, 0, h + 0.03, 0), SC.CHAR, 0.08), 0.0)
	var mv := s.st("main", "MOVED")
	mv.add("wood", SC.pa(Kit.xf(Kit.box(w, h, d), 0.1, d / 2, 0.15, PI / 2 + 0.1, 0.3, 0), body_cols, 0.03), 0.012)
	for k in 5: paper_sheet(mv, s.between(-0.5, 0.7), 0.01 + k * 0.001, s.between(0.4, 1.0), s.r() * 3.0)
	s.extra.move = Vector3(0.8, 0, 0.3)
	s.box_c(-w / 2, w / 2, -d / 2, d / 2)
	s.anchor("front", Vector3(0, 0, d / 2 + 0.5))
	return Vector2(w + 0.1, d + 0.1)

static func jangbu(s: SC.S, n: int) -> Vector2:
	var cols := [[0xd8c9a0, 0xb8a880], [0xc8b48a, 0xa89470], [0x8a6a40, 0x6a4a28]]
	var pile := s.st("main", ["NORMAL", "WET"], "NORMAL")
	for i in n:
		var q: Array = cols[i % cols.size()]
		pile.add("flat", SC.pa(Kit.xf(Kit.box(0.24, 0.04, 0.32), (s.r() - 0.5) * 0.03, 0.02 + i * 0.042, (s.r() - 0.5) * 0.03, 0, (s.r() - 0.5) * 0.15, 0), q, 0.03), 0.004)
	s.st("main", "WET").add("water", Kit.plane(0.6, 0.5, 0.05, 0.006, 0.08), 0.0)
	var mv := s.st("main", "MOVED")
	for i in n + 3:
		var q: Array = cols[i % cols.size()]
		var a := s.r() * TAU; var rr := s.r() * 0.6
		mv.add("flat", SC.pa(Kit.xf(Kit.box(0.24 * (0.5 if i % 3 == 0 else 1.0), 0.006, 0.32), cos(a) * rr, 0.004 + i * 0.001, sin(a) * rr, 0, s.r() * 3.0, 0), q, 0.03), 0.0)
	var bt := s.st("main", "BURNT")
	bt.add("organic", SC.pa(Kit.xf(Kit.lump(0.3, 1, s.rng, 0.3, 0.25), 0, 0.02, 0), [0x3a3633, 0x1a1816], 0.06), 0.0)
	for i in 3:
		bt.add("flat", SC.pa(Kit.xf(Kit.box(0.2, 0.01, 0.16), (i - 1) * 0.22, 0.03, 0.18, 0, i, 0), [0x8a7a5a, 0x2a2420], 0.05), 0.0)
	return Vector2(0.5, 0.5)

static func meoktong(s: SC.S) -> Vector2:
	var p := s.p("p")
	# 벼루(돌) + 붓걸이
	p.add("stone", SC.pa(Kit.box(0.16, 0.03, 0.24, 0.0, 0.015, 0.0), [0x3a3836, 0x2a2826]), 0.004)
	p.add("flat", C.P(Kit.box(0.1, 0.005, 0.08, 0.0, 0.032, -0.06), 0x0a0a0c), 0.0)
	var up := s.st("main", "NORMAL", "NORMAL")
	up.add("smooth", SC.pa(Kit.cyl(0.05, 0.055, 0.08, 8, 0.15, 0.04, 0.0), [0x3a3633, 0x23201e]), 0.004)
	up.add("wood", SC.pa(Kit.xf(Kit.cyl(0.006, 0.006, 0.2, 4), -0.13, 0.01, 0.02, 0, 0.2, PI / 2), [0x8a6a40]), 0.0)
	up.add("flat", SC.pa(Kit.box(0.02, 0.06, 0.012, 0.0, 0.03, -0.1), [0x1a1816]), 0.0)
	var f := s.st("main", "FALLEN")
	f.add("smooth", SC.pa(Kit.xf(Kit.cyl(0.05, 0.055, 0.08, 8), 0.22, 0.05, 0.08, PI / 2, 0.8, 0), [0x3a3633, 0x23201e]), 0.004)
	f.add("flat", C.P(Kit.xf(Kit.box(0.42, 0.004, 0.3), 0.3, 0.004, 0.22, 0, 0.5, 0), 0x08080a), 0.0)
	f.add("wood", SC.pa(Kit.xf(Kit.cyl(0.006, 0.006, 0.2, 4), 0.4, 0.008, -0.1, 0, 1.2, PI / 2), [0x8a6a40]), 0.0)
	return Vector2(0.4, 0.3)

static func chaekjang(s: SC.S, w: float) -> Vector2:
	var p := s.p("p")
	var h := 1.7; var d := 0.38
	var frame := []
	for sx in [-1, 1]: frame.append(Kit.box(0.05, h, d, sx * (w / 2 - 0.025), h / 2, 0))
	frame.append(Kit.box(w, h, 0.02, 0, h / 2, -d / 2 + 0.01))
	for k in 5: frame.append(Kit.box(w, 0.035, d, 0, 0.05 + k * (h - 0.05) / 4, 0))
	p.add("wood", SC.pa(Kit.merge(frame), [0x6a4428, 0x4a2e1c], 0.03), 0.015)
	var cols := [0x8a6a40, 0x3f5f7a, 0x6a3a2a, 0xd8c9a0, 0x5a6a48, 0xa88a58]
	var full := []; var gaps := []; var fall := []
	for k in 4:
		var y := 0.07 + k * (h - 0.05) / 4
		var x := -w / 2 + 0.07
		var i := 0
		while x < w / 2 - 0.14:
			var bw := s.between(0.07, 0.11); var bh := s.between(0.26, 0.34)
			var col: int = cols[(k * 7 + i) % cols.size()]
			var g := Kit.paint(Kit.box(bw, bh, d * 0.75, x + bw / 2, y + bh / 2, 0.02), Kit.hex(col), Kit.hex(col), 0.03)
			full.append(g.copy())
			if (i + k) % 3 != 0: gaps.append(g.copy())
			if k >= 2: fall.append(g.copy())
			x += bw + 0.006; i += 1
	# 쏟아진 책(바닥)
	for i in 9:
		var col: int = cols[i % cols.size()]
		fall.append(Kit.paint(Kit.xf(Kit.box(0.2, 0.03, 0.28), s.between(-w / 2, w / 2), 0.02 + (i % 3) * 0.03, s.between(0.25, 0.8), 0, s.r() * 3.0, 0), Kit.hex(col), Kit.hex(col), 0.03))
	s.st("main", "NORMAL", "NORMAL").add("flat", Kit.merge(full), 0.0)
	s.st("main", "EMPTY").add("flat", Kit.merge(gaps), 0.0)
	s.st("main", "FALLEN").add("flat", Kit.merge(fall), 0.0)
	s.box_c(-w / 2, w / 2, -d / 2, d / 2)
	return Vector2(w, d)

static func chaekdeomi(s: SC.S) -> Vector2:
	var cols := [0x8a6a40, 0x3f5f7a, 0x6a3a2a, 0xd8c9a0, 0xa88a58]
	var n := s.st("main", "NORMAL", "NORMAL")
	var f := s.st("main", "FALLEN")
	for st in 2:
		for i in 7 - st * 2:
			var col: int = cols[(i + st) % cols.size()]
			n.add("flat", C.P(Kit.xf(Kit.box(0.22, 0.035, 0.3), st * 0.28 - 0.14 + (s.r() - 0.5) * 0.03, 0.018 + i * 0.037, (s.r() - 0.5) * 0.03, 0, (s.r() - 0.5) * 0.25, 0), col, col), 0.004)
			f.add("flat", C.P(Kit.xf(Kit.box(0.22, 0.035, 0.3), s.between(-0.5, 0.5), 0.018 + (i % 2) * 0.035, s.between(-0.3, 0.4), 0, s.r() * 3.0, 0), col, col), 0.004)
	return Vector2(0.6, 0.4)

static func chatjan(s: SC.S) -> Vector2:
	var p := s.p("p")
	# 소반 위 다관(주전자) + 찻잔 둘
	p.add("wood", SC.pa(Kit.cyl(0.2, 0.2, 0.03, 10, 0, 0.015, 0), [0x6a4428, 0x4a2e1c]), 0.006)
	var pts := []
	for q in [[0, 0], [0.07, 0], [0.09, 0.05], [0.07, 0.1], [0.025, 0.12], [0.03, 0.14], [0, 0.14]]: pts.append(Vector2(q[0], q[1]))
	var pot := C.lathe(pts, 8)
	Kit.xf(pot, -0.06, 0.03, -0.04)
	p.add("smooth", SC.pa(pot, [0x8a9a8a, 0x5e6e60]), 0.005)
	p.add("smooth", SC.pa(Kit.xf(Kit.cyl(0.008, 0.012, 0.08, 4), 0.04, 0.1, -0.04, 0, 0, -0.9), [0x7a8a7a]), 0.0)
	cup(p, 0.09, 0.03, 0.07); cup(p, -0.04, 0.03, 0.1)
	p.add("organic", SC.pa(Kit.cyl(0.03, 0.03, 0.005, 7, 0.09, 0.08, 0.07), [0x9a8040]), 0.0)
	s.st("main", ["NORMAL", "USED"], "NORMAL")
	s.fx("main", "USED", { type = "steam", x = 0.09, y = 0.1, z = 0.07, size = 0.03, k = 0.6 })
	s.fx("main", "USED", { type = "steam", x = -0.04, y = 0.2, z = -0.04, size = 0.04, k = 0.5 })
	return Vector2(0.4, 0.4)

static func kkeun(s: SC.S) -> Vector2:
	var p := s.p("p")
	# 기둥(말뚝) + 감긴 끈
	p.add("wood", SC.pa(Kit.cyl(0.07, 0.08, 1.2, 6, 0, 0.6, 0), SC.WOOD), 0.012)
	var rope := [0xc8b07a, 0x9d8656]
	var n := s.st("main", "NORMAL", "NORMAL")
	for k in 3: n.add("thatch", SC.pa(Kit.cyl(0.085, 0.085, 0.03, 8, 0, 0.5 + k * 0.04, 0), rope), 0.0)
	n.add("thatch", SC.pa(Kit.limb(Vector3(0.08, 0.55, 0), Vector3(0.5, 0.05, 0.35), 0.015, 0.015, 4), rope), 0.0)
	n.add("thatch", SC.pa(Kit.limb(Vector3(0.5, 0.05, 0.35), Vector3(0.9, 0.02, 0.2), 0.015, 0.015, 4), rope), 0.0)
	var b := s.st("main", "BROKEN")
	b.add("thatch", SC.pa(Kit.cyl(0.085, 0.085, 0.03, 8, 0, 0.5, 0), rope), 0.0)
	b.add("thatch", SC.pa(Kit.limb(Vector3(0.08, 0.5, 0), Vector3(0.18, 0.25, 0.08), 0.015, 0.01, 4), rope), 0.0)
	b.add("thatch", SC.pa(Kit.limb(Vector3(0.6, 0.015, 0.3), Vector3(0.95, 0.015, 0.1), 0.015, 0.015, 4), rope), 0.0)
	b.add("thatch", SC.pa(Kit.limb(Vector3(0.45, 0.015, 0.45), Vector3(0.62, 0.015, 0.28), 0.015, 0.008, 4), rope), 0.0)
	s.circle(0, 0, 0.12)
	s.anchor("knot", Vector3(0.0, 0.5, 0.0))
	return Vector2(1.0, 0.6)

# ---- 장터·창고 ----
static func gamani(s: SC.S) -> Vector2:
	var sack := func(p, x: float, y: float, z: float, ry: float, cols: Array) -> void:
		var g := Kit.lump(0.32, 1, s.rng, 0.12, 0.5)
		Kit.xf(g, x, y + 0.16, z, 0, ry, 0, 1.25, 1.0, 0.85)
		p.add("thatch", SC.pa(g, cols, 0.05), 0.012)
	var straw := [0xc8b07a, 0x9d8656]
	var burnt := [0x4a3e30, 0x221c16]
	var spots := [[-0.42, 0, -0.1], [0.42, 0, -0.1], [0.0, 0, 0.32], [-0.2, 0.3, -0.05], [0.24, 0.3, 0.0]]
	var n := s.st("main", ["NORMAL", "BROKEN"], "NORMAL")
	var bt := s.st("main", "BURNT")
	for i in spots.size():
		var q: Array = spots[i]
		if i == 2: continue
		sack.call(n, q[0], q[1], q[2], i * 0.4, straw)
		sack.call(bt, q[0], q[1] * 0.7, q[2], i * 0.4, burnt)
	sack.call(s.st("main", "NORMAL"), 0.0, 0.0, 0.32, 0.8, straw)
	var br := s.st("main", "BROKEN")
	var g := Kit.lump(0.3, 1, s.rng, 0.2, 0.3)
	Kit.xf(g, 0.05, 0.06, 0.4, 0, 0.8, 0, 1.3, 1.0, 0.8)
	br.add("thatch", SC.pa(g, straw), 0.01)
	br.add("organic", SC.pa(Kit.xf(Kit.lump(0.4, 1, s.rng, 0.3, 0.15), 0.2, 0.0, 0.75, 0, 0, 0, 1.4, 1, 1), [0xd8c080, 0xb89a50], 0.06), 0.0)
	bt.add("organic", SC.pa(Kit.box(1.4, 0.01, 1.0, 0, 0.006, 0.2), [0x2a2420, 0x1a1614], 0.06), 0.0)
	s.box_c(-0.75, 0.75, -0.4, 0.55)
	return Vector2(1.6, 1.1)

static func gireumtong(s: SC.S) -> Vector2:
	var pts := []
	for q in [[0, 0], [0.2, 0], [0.26, 0.2], [0.24, 0.42], [0.12, 0.55], [0.13, 0.6], [0, 0.6]]: pts.append(Vector2(q[0], q[1]))
	var jar := C.lathe(pts, 10)
	var cols := [0x5a3a26, 0x3a2416]
	var n := s.st("main", ["NORMAL", "MOVED"], "NORMAL")
	n.add("onggi", SC.pa(jar.copy(), cols, 0.04), 0.01)
	n.add("wood", SC.pa(Kit.cyl(0.11, 0.11, 0.04, 8, 0, 0.62, 0), [0x6a4428]), 0.004)
	n.add("onggi", SC.pa(Kit.xf(jar.copy(), 0.5, 0, 0.1, 0, 0, 0, 0.8), cols, 0.04), 0.01)
	n.add("flat", C.P(Kit.box(0.5, 0.004, 0.4, 0.2, 0.004, 0.25), 0x2a2218), 0.0)
	var e := s.st("main", "EMPTY")
	e.add("onggi", SC.pa(Kit.xf(jar.copy(), 0.0, 0.25, 0.0, PI / 2, 0.6, 0), cols, 0.04), 0.01)
	e.add("onggi", SC.pa(Kit.xf(jar.copy(), 0.6, 0.2, 0.2, PI / 2, -0.4, 0, 0.8), cols, 0.04), 0.01)
	e.add("flat", C.P(Kit.box(1.2, 0.004, 0.8, 0.3, 0.004, 0.5), 0x1e1812), 0.0)
	s.extra.move = Vector3(-2.2, 0, 1.0)
	s.circle(0.2, 0, 0.45)
	s.anchor("grab", Vector3(0, 0, 0.6))
	return Vector2(1.0, 0.7)

static func jipsin(s: SC.S) -> Vector2:
	var shoe := func(p, x: float, z: float, ry: float, cols: Array, tilt := 0.0) -> void:
		var g := Kit.lump(0.13, 0, s.rng, 0.1, 0.3)
		Kit.xf(g, x, 0.03, z, tilt, ry, 0, 0.45, 1.0, 1.0)
		p.add("thatch", SC.pa(g, cols, 0.05), 0.006)
	var new_c := [0xdcc78e, 0xb89e60]; var old_c := [0x9a8a64, 0x6e6046]
	var n := s.st("main", "NORMAL", "NORMAL")
	shoe.call(n, -0.07, 0, 0.05, new_c); shoe.call(n, 0.07, 0, -0.05, new_c)
	var u := s.st("main", "USED")
	shoe.call(u, -0.07, 0, 0.2, old_c); shoe.call(u, 0.1, 0.05, -0.4, old_c)
	shoe.call(s.st("main", "MOVED"), 0.0, 0.0, 1.1, old_c, 0.5)
	return Vector2(0.3, 0.3)

# ---- 제의 ----
static func geumjul(s: SC.S, w: float) -> Vector2:
	var p := s.p("p")
	for sx in [-1, 1]: p.add("wood", SC.pa(Kit.cyl(0.05, 0.06, 1.3, 6, sx * w / 2, 0.65, 0), SC.WOOD), 0.012)
	var rope := [0xc8b07a, 0x9d8656]
	var n := s.st("main", "NORMAL", "NORMAL")
	var b := s.st("main", "BROKEN")
	var seg := 8
	for i in seg:
		var x0 := -w / 2 + w * i / seg; var x1 := -w / 2 + w * (i + 1) / seg
		var y0 := 1.15 - 0.18 * sin(PI * i / seg); var y1 := 1.15 - 0.18 * sin(PI * (i + 1) / seg)
		n.add("thatch", SC.pa(Kit.limb(Vector3(x0, y0, 0), Vector3(x1, y1, 0), 0.02, 0.02, 4), rope), 0.0)
		# 금줄 사이 흰 종이(한지 오리)
		if i % 2 == 1: n.add("flat", SC.pa(Kit.box(0.08, 0.2, 0.01, (x0 + x1) / 2, (y0 + y1) / 2 - 0.12, 0), SC.PAPER), 0.0)
	# 끊긴 줄: 양쪽 말뚝에서 늘어짐 + 바닥에 떨어진 종이
	for sx in [-1, 1]:
		b.add("thatch", SC.pa(Kit.limb(Vector3(sx * w / 2, 1.15, 0), Vector3(sx * w * 0.3, 0.55, 0.05), 0.02, 0.02, 4), rope), 0.0)
		b.add("thatch", SC.pa(Kit.limb(Vector3(sx * w * 0.3, 0.55, 0.05), Vector3(sx * w * 0.18, 0.02, 0.2), 0.02, 0.015, 4), rope), 0.0)
	for k in 3: b.add("flat", SC.pa(Kit.xf(Kit.box(0.08, 0.005, 0.2), (k - 1) * 0.35, 0.006, 0.3 + k * 0.1, 0, k, 0), SC.PAPER), 0.0)
	for sx in [-1, 1]: s.circle(sx * w / 2, 0, 0.1)
	return Vector2(w + 0.3, 0.4)

static func jemul(s: SC.S) -> Vector2:
	var t := s.st("main", ["NORMAL", "EMPTY"], "NORMAL")
	small_table(t, 0.8, 0.45, 0.35, [0x7a4e2e, 0x5e3c22])
	var n := s.st("main", "NORMAL")
	bowl(n, -0.22, 0.37, 0, 0.08, [0xf2ede0, 0xd8d0bc])
	n.add("organic", SC.pa(Kit.xf(C.sphere(0.06, 8, 5), 0.0, 0.43, 0.0), [0xc84a2a, 0x9a3a1e]), 0.004)
	n.add("organic", SC.pa(Kit.xf(C.sphere(0.055, 8, 5), 0.08, 0.42, 0.06), [0xd8a040, 0xa87a2a]), 0.004)
	n.add("smooth", SC.pa(Kit.cyl(0.04, 0.035, 0.1, 7, 0.24, 0.42, 0.0), BOWL), 0.004)
	n.add("organic", SC.pa(Kit.xf(Kit.box(0.2, 0.04, 0.08), 0.0, 0.39, -0.12), [0xe8dcc0]), 0.0)
	var e := s.st("main", "EMPTY")
	bowl(e, -0.22, 0.37, 0, 0.08)
	e.add("smooth", SC.pa(Kit.xf(Kit.cyl(0.04, 0.035, 0.1, 7), 0.3, 0.02, 0.3, PI / 2, 0.4, 0), BOWL), 0.004)
	var b := s.st("main", "BROKEN")
	b.add("wood", SC.pa(Kit.xf(Kit.box(0.8, 0.04, 0.45), 0.0, 0.2, 0.0, 1.4, 0.3, 0), [0x7a4e2e, 0x5e3c22]), 0.01)
	for k in 4: b.add("organic", SC.pa(Kit.xf(C.sphere(0.05, 6, 4), (k - 1.5) * 0.25, 0.04, 0.4 + (k % 2) * 0.15), [0xc84a2a, 0x9a3a1e]), 0.0)
	s.box_c(-0.4, 0.4, -0.22, 0.22)
	return Vector2(0.9, 0.6)

# 벽 지도: 벽(−z)에 붙인 큰 종이 판. 원점은 벽 앞 바닥(키트 로컬 z=0), 판 면은 z = −0.02
static func byeokjido(s: SC.S) -> Vector2:
	var p := s.p("p")
	var w := 1.4; var h := 1.0; var y0 := 0.9
	var n := s.st("main", "NORMAL", "NORMAL")
	n.add("flat", SC.pa(Kit.box(w, h, 0.01, 0, y0 + h / 2, -0.02), [0xe8dcb8, 0xd4c49a], 0.03), 0.0)
	# 지도 선(산줄기·길·물) — 먹선
	var lines := []
	var R := s.rng
	for k in 9:
		var x0 := R.between(-w * 0.45, w * 0.45); var yy := R.between(y0 + 0.1, y0 + h - 0.1)
		lines.append(Kit.xf(Kit.box(R.between(0.15, 0.5), 0.012, 0.004), x0, yy, -0.012, 0, 0, R.between(-0.8, 0.8)))
	n.add("flat", C.P(Kit.merge(lines), 0x2b2622), 0.0)
	for k in 4: n.add("flat", C.P(Kit.cyl(0.025, 0.025, 0.005, 6, R.between(-0.5, 0.5), R.between(y0 + 0.2, y0 + 0.8), -0.012, PI / 2, 0, 0), 0xa8483a), 0.0)
	var bt := s.st("main", "BURNT")
	bt.add("flat", SC.pa(Kit.box(w * 0.55, h * 0.7, 0.01, -w * 0.2, y0 + h * 0.6, -0.02), [0xd8c89a, 0xb8a47a], 0.03), 0.0)
	bt.add("flat", SC.pa(Kit.box(w * 0.6, h * 0.25, 0.012, -w * 0.15, y0 + h * 0.2, -0.018), SC.CHAR, 0.05), 0.0)
	bt.add("flat", C.P(Kit.box(w * 0.9, h * 0.9, 0.004, 0.0, y0 + h / 2, -0.025), 0x3a2c22), 0.0)
	var mv := s.st("main", "MOVED")
	mv.add("flat", SC.pa(Kit.box(w * 0.4, h * 0.3, 0.01, -w * 0.3, y0 + h * 0.8, -0.02), [0xe8dcb8, 0xd4c49a], 0.03), 0.0)
	mv.add("flat", SC.pa(Kit.xf(Kit.box(w * 0.8, 0.01, h * 0.8), 0.1, 0.01, 0.5, 0, 0.3, 0), [0xe8dcb8, 0xd4c49a], 0.03), 0.0)
	s.anchor("look", Vector3(0, 0, 0.8))
	return Vector2(w, 0.2)

static func hwaro(s: SC.S) -> Vector2:
	var p := s.p("p")
	# 무쇠·질그릇 화로(다리 셋)
	p.add("onggi", SC.pa(Kit.cyl(0.26, 0.2, 0.22, 10, 0, 0.2, 0, 0, 0, 0, false), [0x4a3a2e, 0x2a2018], 0.04), 0.008)
	for k in 3: p.add("onggi", SC.pa(Kit.cyl(0.03, 0.03, 0.1, 5, cos(k * TAU / 3) * 0.16, 0.05, sin(k * TAU / 3) * 0.16), [0x2a2018]), 0.0)
	var n := s.st("main", ["NORMAL", "USED"], "NORMAL")
	n.add("organic", SC.pa(Kit.cyl(0.24, 0.24, 0.02, 10, 0, 0.28, 0), [0x8a8580, 0x5a5652], 0.06), 0.0)
	var u := s.st("main", "USED")
	for k in 4: u.add("flat", SC.pa(Kit.xf(Kit.box(0.18, 0.006, 0.24), cos(k) * 0.08, 0.3 + k * 0.006, sin(k) * 0.08, 0.3, k * 0.8, 0), [0xd8c89a, 0x2a2420], 0.05), 0.0)
	u.add("glow", C.P(Kit.xf(Kit.lump(0.12, 0, s.rng, 0.3, 0.4), 0, 0.3, 0), 0xffb84a, 0xff6a20), 0.0)
	s.fx("main", "USED", { type = "fire", x = 0.0, y = 0.3, z = 0.0, size = 0.12, k = 0.4 })
	s.fx("main", "USED", { type = "smoke", x = 0.0, y = 0.6, z = 0.0, size = 0.15, k = 0.3, dark = 0.1 })
	s.circle(0, 0, 0.28)
	return Vector2(0.6, 0.6)
