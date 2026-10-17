# 사건 단서·상태 소품(「산길의 실종」 등) — 이야기 총괄(story_director)이 조건이 맞을 때만 세운다. 원점 = 바닥 중심, 앞 = +z(카메라 쪽).
# PROP_MASTER: PRP_COM_002(발자국·핏자국) PRP_COM_003(찢어진 천) PRP_COM_004(발톱 긁힘) PRP_COM_007(밀가루 면)
#   PRP_MKT_003(광주리) PRP_RIT_001(서낭당 제물상) PRP_HOME_007(문틈 흰 앞발) 등. 땅 자국은 세계 API 데칼이 있으면 그쪽이 더 곱게 깐다.
# params: kind, seed, length(자국 길이), n(개수), r(나무 줄기 반지름), h(높이)
#   tteok 떨어진 떡(+킁킁 파헤친 흙) · skirt 덤불에 걸린 치맛자락 · blood 길가 돌의 마른 핏자국 · tracks 큰 짐승 발자국(+끊기는 짚신 자국)
#   basket 엎어진 빈 광주리와 수건 · flour 찢긴 밀가루 자루와 흰 발자국 · claw 나무줄기 높은 발톱 긁힘 · oil 밑동에 바른 참기름(번들거림)
#   white_paw 문틈 아래 흰 앞발 · hairy_paw 문틈으로 들어온 털 난 앞발(발톱 끝만 밝다) · oil_jars 기름집 참기름 병 · cake_trail 오솔길에 놓은 떡 · feast 잔칫상 · offering 서낭당 떡 공양
#   bones 영역 어귀 뼈·타다 만 횃불 · jeogori 떨어진 저고리 · torch_fire 횃대 불(빛) · sandal 길가에 닳은 짚신 한 짝(도입부 첫 조사, 단서 아님)
#   seoan 이겸의 서안(낮은 책상 — 펼친 기록책·벼루·붓, 재기획 3단계 첫 15분) · ledger 한 장짜리 밥값 장부(접힌 종이·붓 자국)
#   brush 창가에 말려 둔 붓(붓걸이·갈라진 붓끝) · ledger_hang 주막 기둥에 걸린 묵은 숙박 장부(끈으로 묶은 책)
#   paper_dry 말리는 기록지(서장 프롤로그) — n장(1~6)을 멍석 위에 비스듬히 펼친 한지(먹줄), bound=true면 실로 맨 덮인 기록책 한 권
#   fall_traces 남원 §65 아침 수수밭 — 꺾인 수숫대 · 붉은 흔적 · 뜯긴 털 · 깊게 눌린 발자국(시신은 없다)
extends RefCounted
const C := preload("res://kit/village/_common.gd")

const TTEOK := [0xf2ece0, 0xd8cfbd]
const DIRT := [0x6b5640, 0x4e3e2c]
const INDIGO := [0x3d5878, 0x2a3e58]
const BLOOD := [0x5a1410, 0x3a0c08]
const PAW := [0x3e3024, 0x2a2018]
const WHITE := [0xf4f1ea, 0xd9d4c8]
const STRAW := [0xc9a868, 0x9d8656]

static func build(params: Dictionary) -> Dictionary:
	var m := C.M.new(int(params.get("seed", 7)))
	var kind := String(params.get("kind", "tteok"))
	var fp := Vector2(1.5, 1.5)
	match kind:
		"tteok": _tteok(m)
		"skirt": _skirt(m)
		"blood": _blood(m)
		"tracks": fp = _tracks(m, float(params.get("length", 4.0)), bool(params.get("shoes", true)))
		"basket": _basket(m)
		"flour": fp = _flour(m, float(params.get("length", 5.0)))
		"claw": _claw(m, float(params.get("r", 0.45)), float(params.get("h", 3.2)))
		"oil": _oil(m, float(params.get("r", 0.45)))
		"white_paw": _white_paw(m)
		"hairy_paw": _hairy_paw(m)
		"oil_jars": _oil_jars(m)
		"cake_trail": fp = _cake_trail(m, int(params.get("n", 5)), float(params.get("length", 8.0)))
		"feast": fp = _feast(m)
		"offering": _offering(m)
		"bones": _bones(m)
		"jeogori": _jeogori(m)
		"torch_fire": _torch_fire(m)
		"sandal": _sandal(m)
		"fall_traces": fp = _fall_traces(m)
		"seoan": fp = _seoan(m)
		"ledger": _ledger(m)
		"brush": _brush(m)
		"ledger_hang": _ledger_hang(m)
		"paper_dry":
			fp = _paper_dry(m, int(params.get("n", 4)), bool(params.get("bound", false)))
			if bool(params.get("dew", false)): _paper_dew(m)   # 프롤로그 비교 시험(임시) E5
		"ink_dry": _ink_dry(m)   # 프롤로그 비교 시험(임시) E5
	var res := m.result("단서_" + kind, fp, false)
	if kind == "seoan": res.block = true   # 이야기 소품이 충돌체를 세우는 것은 block이 있을 때만(story_director._prop_cols)
	return res

static func _disc(rx: float, rz: float, h: float, x: float, y: float, z: float, ry := 0.0, seg := 10) -> Kit.Geo:
	return Kit.xf(Kit.cyl(1.0, 1.0, h, seg), x, y, z, 0, ry, 0, rx, 1, rz)

static func _tteok(m: C.M) -> void:
	var R := m.rng
	m.add("p", "flat", C.PA(_disc(0.55, 0.4, 0.02, 0, 0.01, 0, 0.4, 12), DIRT, 0.08, R), 0)       # 파헤친 흙
	for i in 4: m.add("p", "organic", C.PA(Kit.xf(Kit.lump(0.07, 0, R, 0.4, 0.5), (m.r() - 0.5) * 0.8, 0.03, (m.r() - 0.5) * 0.6), DIRT), 0)
	m.add("p", "smooth", C.PA(Kit.xf(Kit.cyl(0.11, 0.12, 0.07, 10), 0.05, 0.05, 0.02, 0.15, 0.3, 0.1), TTEOK), 0.01)

static func _skirt(m: C.M) -> void:
	var R := m.rng
	m.add("p", "leaf", C.P(Kit.xf(Kit.lump(0.55, 1, R, 0.35, 0.75), 0, 0.4, 0), 0x6e7a46, 0x4a5530, 0.08, R), 0.02)
	for i in 3:
		var g := Kit.box(0.14, 0.55 - i * 0.1, 0.015)
		Kit.xf(g, -0.2 + i * 0.16, 0.42, 0.42, 0.2, 0.2 * i, 0.15 * (i - 1))
		m.add("p", "cloth", C.PA(g, INDIGO, 0.05, R), 0.006)

static func _blood(m: C.M) -> void:
	var R := m.rng
	m.add("p", "rock", C.PA(Kit.xf(Kit.lump(0.35, 1, R, 0.3, 0.6), 0.2, 0.12, -0.1), C.STONE, 0.06, R), 0.02)
	m.add("p", "flat", C.PA(_disc(0.45, 0.3, 0.012, -0.15, 0.008, 0.15, 0.6, 9), BLOOD, 0.1, R), 0)
	m.add("p", "flat", C.PA(_disc(0.12, 0.08, 0.012, 0.35, 0.008, 0.45, 0.2, 7), BLOOD, 0.1, R), 0)
	m.add("p", "flat", C.PA(_disc(0.16, 0.1, 0.02, 0.15, 0.3, 0.12, 1.0, 7), BLOOD, 0.1, R), 0)   # 돌 위 얼룩
	# 한쪽으로 쓸려 누운 풀
	for i in 6:
		var g := Kit.box(0.03, 0.02, 0.4)
		Kit.xf(g, -0.5 + m.r() * 0.3, 0.02, -0.3 + i * 0.12, 0, -0.8, 0)
		m.add("p", "flat", C.P(g, 0x8a8a52, 0x6a6a3e), 0)

# 큰 발자국(앞쪽 -z로 걸어간 줄) + 짚신 자국은 중간에서 끊긴다
static func _paw(m: C.M, x: float, z: float, s: float, col: Array, ry := 0.0) -> void:
	m.add("p", "flat", C.PA(_disc(0.1 * s, 0.09 * s, 0.01, x, 0.012, z, ry, 8), col), 0)
	for k in 4:
		var a := -0.9 + k * 0.6 + ry
		m.add("p", "flat", C.PA(_disc(0.035 * s, 0.04 * s, 0.01, x + sin(a) * 0.15 * s, 0.012, z - cos(a) * 0.15 * s, 0.0, 6), col), 0)

static func _tracks(m: C.M, length: float, shoes: bool) -> Vector2:
	var n := int(length / 0.7)
	for i in n:
		var z := length * 0.5 - i * 0.7
		_paw(m, (0.18 if i % 2 == 0 else -0.18), z, 1.4, PAW)
		if shoes and i < n / 2:
			m.add("p", "flat", C.PA(_disc(0.05, 0.12, 0.01, (0.65 if i % 2 == 0 else 0.48), 0.012, z + 0.2, 0.05, 8), DIRT), 0)
	return Vector2(1.6, length + 0.6)

static func _basket(m: C.M) -> void:
	var R := m.rng
	var g := C.sphere(0.36, 12, 4, 0, TAU, 0, PI / 2)
	Kit.xf(g, 0, 0.0, 0, PI, 0, 0, 1, 0.55, 1)
	Kit.xf(g, 0.05, 0.2, 0, 0.35, 0.4, 0.15)
	m.add("p", "thatch", C.PA(g, STRAW, 0.06, R), 0.012)
	m.add("p", "thatch", C.PA(Kit.xf(C.torus(0.36, 0.025, 4, 16), 0.0, 0.16, 0.12, 1.2, 0.4, 0.15), STRAW), 0.006)
	# 머리에 받치던 수건
	m.add("p", "cloth", C.PA(Kit.xf(Kit.box(0.5, 0.02, 0.32), -0.55, 0.02, 0.3, 0, 0.6, 0.05), WHITE, 0.04, R), 0.005)

static func _flour(m: C.M, length: float) -> Vector2:
	var R := m.rng
	m.add("p", "cloth", C.P(Kit.xf(Kit.lump(0.42, 1, R, 0.2, 0.8), 0, 0.3, 0, 0, 0, 0.5), 0xd8ccb0, 0xb6a888, 0.05, R), 0.02)   # 자루
	m.add("p", "flat", C.PA(Kit.xf(Kit.box(0.3, 0.02, 0.06), 0.25, 0.42, 0.3, 0.3, 0.4, 0.8), [0x2a2018, 0x2a2018]), 0)          # 갈라진 틈
	m.add("p", "smooth", C.PA(_disc(0.85, 0.6, 0.04, 0.3, 0.02, 0.5, 0.3, 12), WHITE, 0.03, R), 0)                                   # 쏟아진 가루
	var n := int(length / 0.75)
	for i in n:
		_paw(m, 0.6 + (0.15 if i % 2 == 0 else -0.15) - i * 0.05, 0.5 - 0.8 - i * 0.75, 1.3, WHITE, -0.3)
	return Vector2(2.2, length + 1.5)

static func _claw(m: C.M, r: float, h: float) -> void:
	for i in 4:
		var g := Kit.box(0.03, 0.75, 0.02)
		Kit.xf(g, -0.12 + i * 0.08, h - 0.4 - i * 0.04, r + 0.01, 0, 0, 0.12)
		m.add("p", "flat", C.P(g, 0xd9c8a6, 0xb7a17a), 0)
	for i in 3:
		var g := Kit.box(0.03, 0.4, 0.02)
		Kit.xf(g, -0.06 + i * 0.08, 0.95, r + 0.01, 0, 0, -0.5)
		m.add("p", "flat", C.P(g, 0xc8b690, 0xa8956e), 0)   # 매끈한 옹이 자리에서 미끄러진 자국

static func _oil(m: C.M, r: float) -> void:
	var g := Kit.cyl(r + 0.03, r + 0.06, 1.4, 12, 0, 0.7, 0, 0, 0, 0, false)
	m.add("p", "smooth", C.P(g, 0x6a4a1e, 0x3e2a10, 0.02), 0)
	m.add("p", "glow", C.P(Kit.xf(Kit.box(0.05, 1.1, 0.01), 0.1, 0.75, r + 0.07), 0xf0d27a, 0xc8a24a), 0)   # 번들거리는 빛줄

static func _white_paw(m: C.M) -> void:
	m.add("p", "smooth", C.PA(Kit.xf(Kit.lump(0.13, 1, m.rng, 0.2, 0.45), 0, 0.05, 0.1), WHITE), 0.008)
	for k in 4:
		m.add("p", "smooth", C.PA(Kit.xf(Kit.lump(0.04, 0, m.rng, 0.2, 0.8), -0.09 + k * 0.06, 0.04, 0.24), WHITE), 0.004)
	m.add("p", "flat", C.PA(_disc(0.3, 0.2, 0.01, 0, 0.005, 0.15, 0.0, 9), WHITE, 0.05), 0)   # 문간에 떨어진 가루

# 남원 v3.2 §38 CAMERA 7C — 문틈으로 들어온 앞발 일부(털·발톱). 얼굴·몸은 없다
const FUR := [0x6a4a2a, 0x3a2614]
static func _hairy_paw(m: C.M) -> void:
	var R := m.rng
	m.add("p", "smooth", C.PA(Kit.xf(Kit.lump(0.15, 1, R, 0.3, 0.42), 0, 0.06, 0.06), FUR, 0.12, R), 0.01)
	m.add("p", "smooth", C.PA(Kit.xf(Kit.cyl(0.12, 0.14, 0.34, 8), 0, 0.09, -0.16, PI * 0.5, 0, 0), FUR, 0.12, R), 0.01)   # 문틈 쪽 팔목
	for k in 4:
		var x := -0.105 + k * 0.07
		m.add("p", "smooth", C.PA(Kit.xf(Kit.lump(0.045, 0, R, 0.25, 0.8), x, 0.045, 0.2), FUR, 0.1, R), 0.005)
		m.add("p", "smooth", C.P(Kit.xf(Kit.cone(0.014, 0.07, 5), x, 0.04, 0.26, PI * 0.5, 0, 0), 0xe0d8c6, 0xa8a090), 0)   # 발톱
	for i in 18:   # 거친 털 뭉치
		var a := R.next() * TAU
		var g := Kit.cone(0.02, 0.07 + R.next() * 0.05, 4)
		Kit.xf(g, cos(a) * 0.12, 0.1 + R.next() * 0.05, -0.2 + R.next() * 0.38, 0.9 * sin(a), 0, -0.9 * cos(a))
		m.add("p", "smooth", C.PA(g, FUR, 0.15, R), 0)

static func _oil_jars(m: C.M) -> void:
	m.add("p", "wood", C.PA(Kit.box(0.9, 0.5, 0.45, 0, 0.25, 0), C.WOOD_L), 0.012)
	for i in 3:
		var x := -0.28 + i * 0.28
		m.add("p", "onggi", C.P(Kit.xf(C.lathe([Vector2(0, 0), Vector2(0.08, 0), Vector2(0.1, 0.12), Vector2(0.04, 0.26), Vector2(0.035, 0.32), Vector2(0, 0.32)], 8), x, 0.5, 0.0), 0x7a5a2e, 0x4a3218), 0.008)
	m.circle(0, 0, 0.5)

static func _cake_trail(m: C.M, n: int, length: float) -> Vector2:
	for i in n:
		var x := -length * 0.5 + length * i / maxf(1.0, n - 1)
		m.add("p", "smooth", C.PA(Kit.xf(Kit.cyl(0.1, 0.11, 0.07, 10), x, 0.04, sin(i * 1.7) * 0.4, 0.1, i, 0), TTEOK), 0.008)
	return Vector2(length + 1.0, 1.4)

static func _feast(m: C.M) -> Vector2:
	var R := m.rng
	m.add("p", "thatch", C.PA(Kit.box(4.2, 0.03, 2.2, 0, 0.015, 0), STRAW, 0.05, R), 0)    # 멍석
	m.add("p", "wood", C.PA(Kit.box(2.6, 0.08, 0.7, 0, 0.36, 0), C.WOOD_L), 0.012)          # 잔칫상
	for s in [-1, 1]:
		for t in [-1, 1]: m.add("p", "wood", C.PA(Kit.box(0.08, 0.32, 0.08, s * 1.15, 0.16, t * 0.26), C.WOOD), 0)
	for i in 7:
		var x := -1.1 + i * 0.37
		m.add("p", "onggi", C.P(Kit.cyl(0.11, 0.07, 0.08, 8, x, 0.44, (0.12 if i % 2 == 0 else -0.12)), 0xe8e0cc, 0xb8ae98), 0.006)
		m.add("p", "smooth", C.PA(Kit.cyl(0.08, 0.09, 0.05, 8, x, 0.5, (0.12 if i % 2 == 0 else -0.12)), TTEOK), 0)
	m.add("p", "onggi", C.PA(Kit.xf(C.onggi(0.3, 0.6, 10), -1.8, 0, 0.6), C.ONGGI), 0.012)   # 술독
	# 깃대와 흰 천(잔치 표시)
	m.add("p", "wood", C.PA(Kit.cyl(0.04, 0.05, 3.2, 6, 1.9, 1.6, -0.8), C.WOOD), 0.01)
	m.add("p", "cloth", C.P(Kit.box(0.6, 1.4, 0.02, 2.2, 2.4, -0.8), 0xf2ede2, 0xd8d0c0), 0.006)
	m.box_c(-1.4, 1.4, -0.45, 0.45)
	return Vector2(4.6, 2.6)

static func _offering(m: C.M) -> void:
	m.add("p", "wood", C.PA(Kit.box(0.7, 0.25, 0.42, 0, 0.125, 0), C.WOOD_L), 0.01)
	m.add("p", "onggi", C.P(Kit.cyl(0.24, 0.16, 0.06, 10, 0, 0.28, 0), 0xe6dccb, 0xb8ae98), 0.006)
	for i in 5:
		var a := i * 1.25
		m.add("p", "smooth", C.PA(Kit.cyl(0.07, 0.08, 0.05, 8, cos(a) * 0.11, 0.33 + (0.04 if i == 4 else 0.0), sin(a) * 0.08), TTEOK), 0)

static func _bones(m: C.M) -> void:
	var R := m.rng
	for i in 6:
		var g := Kit.cyl(0.03, 0.035, 0.35 + m.r() * 0.3, 5)
		Kit.xf(g, (m.r() - 0.5) * 1.6, 0.04, (m.r() - 0.5) * 1.2, PI / 2, m.r() * 3.0, 0)
		m.add("p", "smooth", C.PA(g, [0xe6dfcc, 0xc8bfa8]), 0.006)
	m.add("p", "smooth", C.PA(Kit.xf(Kit.lump(0.12, 0, R, 0.3, 0.8), 0.5, 0.08, 0.3), [0xe6dfcc, 0xc8bfa8]), 0.006)
	# 타다 만 횃불
	m.add("p", "wood", C.P(Kit.xf(Kit.cyl(0.035, 0.04, 0.9, 6), -0.4, 0.05, 0.5, PI / 2, 0.7, 0), 0x5a4432, 0x3f2f22), 0.008)
	m.add("p", "flat", C.P(Kit.xf(Kit.cyl(0.06, 0.05, 0.16, 6), -0.06, 0.06, 0.78, PI / 2, 0.7, 0), 0x1a1612), 0)

static func _jeogori(m: C.M) -> void:
	var R := m.rng
	m.add("p", "cloth", C.P(Kit.xf(Kit.box(0.75, 0.04, 0.5), 0, 0.03, 0, 0.05, 0.4, 0.03), 0xe6d6a6, 0xc8b88a, 0.05, R), 0.006)
	m.add("p", "cloth", C.P(Kit.xf(Kit.box(0.45, 0.03, 0.18), 0.45, 0.03, 0.2, 0, 1.0, 0), 0xe6d6a6, 0xc8b88a, 0.05, R), 0.004)
	m.add("p", "cloth", C.P(Kit.xf(Kit.box(0.12, 0.035, 0.3), -0.1, 0.05, 0.05, 0, 0.4, 0), 0xa8443c, 0x7a2e28), 0)   # 고름

static func _torch_fire(m: C.M) -> void:
	m.add("p", "glow", C.P(Kit.cone(0.16, 0.45, 6, 0, 2.3, 0), 0xffd27a, 0xff6a20), 0)
	m.light(0, 2.3, 0, "torch")

# 길가에 버려진 닳은 짚신 한 짝(S0000 — 사건 단서 아님)
static func _sandal(m: C.M) -> void:
	var R := m.rng
	m.add("p", "flat", C.PA(_disc(0.32, 0.22, 0.012, 0.0, 0.006, 0.0, 0.3, 9), DIRT, 0.08, R), 0)   # 눌린 흙
	m.add("p", "organic", C.PA(Kit.xf(Kit.box(0.11, 0.025, 0.27), 0.0, 0.02, 0.0, 0.0, 0.5, 0.06), STRAW, 0.1, R), 0.004)   # 바닥
	for i in 3:   # 앞코·옆 날개 새끼
		var g := Kit.box(0.02, 0.05, 0.12 - i * 0.02)
		Kit.xf(g, -0.05 + i * 0.05, 0.05, -0.06 + i * 0.03, 0.2, 0.5 + (i - 1) * 0.5, 0)
		m.add("p", "organic", C.PA(g, STRAW, 0.12, R), 0.003)
	m.add("p", "organic", C.PA(Kit.xf(Kit.cyl(0.012, 0.012, 0.24, 5), 0.07, 0.03, 0.06, 1.4, 0.3, 0.0), STRAW, 0.1, R), 0.002)   # 풀린 끈

# 남원 v3.2 §65 — 범이 떨어진 자리(아침): 한쪽으로 꺾여 누운 붉은 수숫대 · 붉게 번진 흙 · 뜯긴 털 뭉치 · 깊게 눌린 큰 발자국. 몸은 없다
const STALK_RED := [0xa83228, 0x641810]
static func _fall_traces(m: C.M) -> Vector2:
	var R := m.rng
	for i in 9:   # 꺾인 수숫대 — 밑동에서 꺾여 바깥으로 눕는다
		var a := -0.9 + i * 0.22 + (R.next() - 0.5) * 0.2
		var bx := cos(a) * 0.5 + (R.next() - 0.5) * 0.3
		var bz := sin(a) * 0.4 + (R.next() - 0.5) * 0.3
		var base := Vector3(bx, 0.0, bz)
		var knee := base + Vector3(0, 0.25 + R.next() * 0.2, 0)
		var tip := knee + Vector3(cos(a) * 1.4, 0.08, sin(a) * 1.4)
		m.add("p", "organic", C.PA(Kit.limb(base, knee, 0.03, 0.026, 5), STALK_RED, 0.08, R), 0.0)
		m.add("p", "organic", C.PA(Kit.limb(knee, tip, 0.026, 0.018, 5), STALK_RED, 0.08, R), 0.0)
	m.add("p", "flat", C.PA(_disc(0.9, 0.7, 0.012, 0.1, 0.01, 0.0, 0.4, 12), BLOOD, 0.1, R), 0)   # 붉게 번진 흙
	m.add("p", "flat", C.PA(_disc(0.35, 0.22, 0.012, 1.0, 0.012, 0.4, 1.1, 9), BLOOD, 0.1, R), 0)
	for k in 3:   # 뜯긴 털 뭉치
		var c := Vector3(-0.6 + k * 0.7, 0.04, -0.5 + R.next() * 0.9)
		m.add("p", "smooth", C.PA(Kit.xf(Kit.lump(0.07, 0, R, 0.4, 0.5), c.x, c.y, c.z), FUR, 0.15, R), 0.0)
		for i in 7:
			var a2 := R.next() * TAU
			var g := Kit.cone(0.018, 0.08 + R.next() * 0.05, 4)
			Kit.xf(g, c.x + cos(a2) * 0.05, c.y + 0.02, c.z + sin(a2) * 0.05, 1.2 * sin(a2), 0, -1.2 * cos(a2))
			m.add("p", "smooth", C.PA(g, FUR, 0.15, R), 0)
	for i in 4:   # 깊게 눌린 큰 발자국(어둡고 크다)
		_paw(m, -1.3 + i * 0.35, 0.9 - i * 0.18, 1.9, [0x2a2016, 0x1a140c], 0.6)
	return Vector2(3.4, 2.6)

# ---------------------------------------------------------------------------
# 재기획 3단계(첫 15분) — 이겸의 거처·솔잎 주막 소품
# ---------------------------------------------------------------------------
const PAPER := [0xefe6cf, 0xd8ccb0]
const INKC := [0x2b2622, 0x1a1714]
# 낮은 서안(1.0×0.45) + 펼친 기록책 + 벼루·먹 + 붓 — 방 안 바닥에 앉아 쓰는 책상
static func _seoan(m: C.M) -> Vector2:
	var R := m.rng
	m.add("p", "wood", C.PA(Kit.box(1.0, 0.04, 0.45, 0, 0.30, 0), C.WOOD_L, 0.04, R), 0.01)        # 상판
	for sx in [-1, 1]:
		m.add("p", "wood", C.PA(Kit.box(0.05, 0.28, 0.4, sx * 0.44, 0.14, 0), C.WOOD, 0.04, R), 0.01)   # 다리판
	m.add("p", "wood", C.PA(Kit.box(1.04, 0.03, 0.06, 0, 0.33, -0.2), C.WOOD, 0.03, R), 0.005)     # 뒤 턱
	# 펼친 기록책(두 쪽, 세로 먹줄)
	for sx in [-1, 1]:
		m.add("p", "flat", C.PA(Kit.xf(Kit.box(0.26, 0.012, 0.34), sx * 0.14, 0.33, 0.02, 0, sx * 0.04, 0), PAPER, 0.03, R), 0.004)
		for i in 4:
			m.add("p", "flat", C.PA(Kit.box(0.008, 0.002, 0.26, sx * (0.06 + i * 0.05), 0.337, 0.02), INKC), 0.0)
	m.add("p", "stone", C.PA(Kit.box(0.13, 0.03, 0.2, 0.38, 0.335, 0.05), [0x3a3a3c, 0x2a2a2c], 0.04, R), 0.004)   # 벼루
	m.add("p", "flat", C.PA(Kit.box(0.025, 0.02, 0.09, 0.35, 0.36, -0.1), INKC), 0.002)                            # 먹
	m.add("p", "wood", C.PA(Kit.xf(Kit.cyl(0.008, 0.008, 0.24, 5), -0.38, 0.34, 0.08, PI / 2, 0.6, 0), [0x8a6a3a, 0x6a4a2a]), 0.002)   # 붓
	m.box_c(-0.52, 0.52, -0.24, 0.24)   # 낮은 책상 — 뚫고 걷지 않게(이야기 소품 충돌체, story_director._prop_cols)
	return Vector2(1.1, 0.6)

# 한 장짜리 밥값 장부 — 소반 위 접힌 종이(가운데 접힌 자국·먹 글씨 두 줄, 고쳐 쓴 줄)
static func _ledger(m: C.M) -> void:
	var R := m.rng
	m.add("p", "flat", C.PA(Kit.xf(Kit.box(0.2, 0.006, 0.26), 0, 0.003, 0, 0, 0.3, 0), PAPER, 0.03, R), 0.003)
	for i in 3:
		m.add("p", "flat", C.PA(Kit.xf(Kit.box(0.006, 0.002, 0.18 - i * 0.03), -0.05 + i * 0.05, 0.008, 0, 0, 0.3, 0), INKC), 0.0)
	m.add("p", "flat", C.PA(Kit.xf(Kit.box(0.05, 0.002, 0.012), 0.06, 0.008, 0.08, 0, 0.3, 0), INKC), 0.0)   # 그어 지운 자리

# 창가에 말려 둔 붓 — 붓걸이(작은 틀)에 붓 셋, 하나는 끝이 갈라졌다
static func _brush(m: C.M) -> void:
	var R := m.rng
	m.add("p", "wood", C.PA(Kit.box(0.34, 0.02, 0.08, 0, 0.0, 0), C.WOOD, 0.04, R), 0.004)
	for sx in [-1, 1]: m.add("p", "wood", C.PA(Kit.box(0.02, 0.16, 0.02, sx * 0.15, 0.08, 0), C.WOOD, 0.04, R), 0.003)
	m.add("p", "wood", C.PA(Kit.box(0.34, 0.015, 0.02, 0, 0.16, 0), C.WOOD, 0.04, R), 0.003)
	for i in 3:
		var x := -0.09 + i * 0.09
		m.add("p", "wood", C.PA(Kit.cyl(0.007, 0.007, 0.13, 5, x, 0.1, 0.0), [0x8a6a3a, 0x6a4a2a]), 0.002)
		var tip := Kit.xf(Kit.cone(0.012 if i != 1 else 0.02, 0.05, 5), x, 0.04, 0.0, PI, 0, 0)   # 붓끝(아래로)
		m.add("p", "organic", C.PA(tip, [0x3a3028, 0x22201c]), 0.0)

# 주막 기둥에 걸린 묵은 숙박 장부(끈으로 묶은 얇은 책 — 땅 위 1.1m에 걸어 둔다: 배치 dy)
static func _ledger_hang(m: C.M) -> void:
	var R := m.rng
	m.add("p", "flat", C.PA(Kit.box(0.24, 0.32, 0.03, 0, 0.0, 0), PAPER, 0.04, R), 0.004)
	m.add("p", "flat", C.PA(Kit.box(0.25, 0.04, 0.035, 0, 0.14, 0), [0x6a4430, 0x4a2e20]), 0.0)   # 묶은 끈 자리
	for i in 4: m.add("p", "flat", C.PA(Kit.box(0.006, 0.22, 0.002, -0.08 + i * 0.05, -0.03, 0.017), INKC), 0.0)
	m.add("p", "wood", C.PA(Kit.cyl(0.006, 0.006, 0.2, 4, 0, 0.26, 0.0), [0x6a4430, 0x4a2e20]), 0.0)   # 거는 끈

# 말리는 기록지(서장 프롤로그 「이겸과 제자의 어느 날」) — 멍석 위에 펼친 한지 n장(먹줄 몇 줄, 번진 자리 하나) · bound: 실로 맨 덮인 기록책 한 권
static func _paper_dry(m: C.M, n: int, bound: bool) -> Vector2:
	var R := m.rng
	if bound:
		m.add("p", "flat", C.PA(Kit.box(0.2, 0.035, 0.27, 0, 0.018, 0), [0xb89a6a, 0x9a7e52], 0.03, R), 0.004)   # 누런 표지
		m.add("p", "flat", C.PA(Kit.box(0.19, 0.03, 0.26, 0.004, 0.018, 0), PAPER, 0.02, R), 0.0)                # 속장(옆면)
		for i in 4: m.add("p", "flat", C.PA(Kit.box(0.008, 0.038, 0.006, -0.085, 0.019, -0.09 + i * 0.06), INKC), 0.0)   # 맨 실
		return Vector2(0.4, 0.4)
	n = clampi(n, 1, 6)
	for i in n:
		var cx: float = -0.62 + float(i % 3) * 0.6 + R.between(-0.05, 0.05)
		var cz: float = -0.22 + float(i / 3) * 0.48 + R.between(-0.04, 0.04)
		var a: float = R.between(-0.18, 0.18)
		m.add("p", "flat", C.PA(Kit.xf(Kit.box(0.34, 0.004, 0.44), cx, 0.003 + i * 0.0008, cz, 0, a, 0), PAPER, 0.03, R), 0.002)
		for k in 3:
			m.add("p", "flat", C.PA(Kit.xf(Kit.box(0.008, 0.002, 0.3 - k * 0.05), cx - 0.09 + k * 0.08, 0.006 + i * 0.0008, cz, 0, a, 0), INKC), 0.0)
		if i == 0: m.add("p", "flat", C.PA(Kit.xf(Kit.box(0.09, 0.002, 0.07), cx + 0.06, 0.007, cz + 0.1, 0, a, 0), [0x8a8478, 0x6a645a]), 0.0)   # 젖어 번진 자리
	return Vector2(1.9, 1.1)

# 프롤로그 비교 시험(임시 — claude/prologue-framed-trial) E5 시간의 흔적: 첫 장(n=1의 자리)에 이슬로 먹이 번진 큰 얼룩 · 서안 벼루의 마른 먹 갈라짐
static func _paper_dew(m: C.M) -> void:
	var R := m.rng
	var cx := -0.62; var cz := -0.22
	for k in 5:
		var w := R.between(0.07, 0.14); var l := R.between(0.06, 0.12)
		m.add("p", "flat", C.PA(Kit.xf(Kit.box(w, 0.002, l), cx + R.between(-0.12, 0.12), 0.0085, cz + R.between(-0.16, 0.16), 0, R.between(-0.6, 0.6), 0), [0x8d8c8e, 0x77777c]), 0.0)
	m.add("p", "flat", C.PA(Kit.xf(Kit.box(0.3, 0.001, 0.36), cx, 0.0078, cz, 0, 0.05, 0), [0xc9bfa6, 0xb8ad93], 0.03, R), 0.0)   # 젖었다 마른 누런 물자국

static func _ink_dry(m: C.M) -> void:
	m.add("p", "stone", C.PA(Kit.box(0.11, 0.004, 0.17, 0.38, 0.352, 0.05), [0x77746c, 0x5e5b55]), 0.0)   # 말라 허옇게 뜬 먹 자리
	for i in 4:
		m.add("p", "flat", C.PA(Kit.xf(Kit.box(0.004, 0.003, 0.09), 0.34 + i * 0.025, 0.355, 0.05, 0, 0.5 - i * 0.3, 0), [0x1a1714, 0x101010]), 0.0)   # 갈라진 금
