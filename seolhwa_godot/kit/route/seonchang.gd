# 선창(船艙) — 강 포구의 나무 잔교: 물속에 박은 말뚝 두 줄 + 가로 멍에 + 널 깐 바닥(물 면 위 0.32 — 엔진 뱃길 갑판 높이와 같음)
# + 배 매는 말뚝·밧줄 + 끝에 섬(곡식 가마니) 몇. 명세 §25(선착장)·§26(포구: 싣고 내리는 곳).
# 원점 = 잔교 가운데 물 면(y=0), 잔교는 로컬 z 방향(뭍 −z → 물 +z). 걷는 면은 엔진(river_lanes.gd)이 깐다 — 키트는 그림만.
# params: seed, len(12.0), w(2.4), sacks(true)
extends RefCounted
const C := preload("res://kit/village/_common.gd")

static func build(params: Dictionary) -> Dictionary:
	var m := C.M.new(int(params.get("seed", 1)))
	var L: float = float(params.get("len", 12.0)); var Wd: float = float(params.get("w", 2.4))
	var R := m.rng
	var hl := L / 2; var hw := Wd / 2; var deck := 0.32
	# 말뚝(물속까지) — 2줄
	var n := maxi(3, int(L / 2.4) + 1)
	for i in n:
		var z := -hl + 0.3 + (L - 0.6) * i / float(n - 1)
		for s in [-1, 1]:
			m.add("p", "wood", C.P(Kit.cyl(0.11, 0.13, 2.6, 6, s * (hw - 0.1), deck - 1.2 + R.between(-0.05, 0.08), z), 0x5e4630, 0x3a2a1c, 0.05, R), 0.012)
		# 가로 멍에
		m.add("p", "wood", C.PA(Kit.box(Wd + 0.2, 0.12, 0.16, 0, deck - 0.1, z), C.WOOD), 0.012)
	# 널 바닥(조금씩 어긋난 판)
	var nb := int(L / 0.42)
	for i in nb:
		var z := -hl + (i + 0.5) * L / nb
		var sh := R.between(-0.06, 0.06)
		m.add("p", "wood", C.P(Kit.box(Wd + R.between(-0.1, 0.1), 0.06, L / nb - 0.04, sh, deck - 0.02, z), 0xa48660, 0x86694a, 0.06, R), 0.008)
	# 배 매는 말뚝(끝 두 개) + 감은 밧줄
	for s in [-1, 1]:
		m.add("p", "wood", C.P(Kit.cyl(0.09, 0.1, 1.0, 6, s * (hw - 0.15), deck + 0.45, hl - 0.25), 0x6e5238, 0x4e3a28, 0.04, R), 0.01)
		m.add("p", "cloth", C.P(Kit.cyl(0.13, 0.13, 0.12, 8, s * (hw - 0.15), deck + 0.6, hl - 0.25), 0xb8a47c, 0x8a7656, 0.04, R), 0)
	if bool(params.get("sacks", true)):
		for i in 3:
			m.add("p", "thatch", C.P(Kit.xf(Kit.cyl(0.25, 0.25, 0.68, 7), -hw * 0.45, deck + 0.25 + (0.42 if i == 2 else 0.0), -hl + 1.2 + (0.5 if i == 2 else i * 0.55), 0, 0, PI / 2),
				0xcdb582, 0xa08a5e, 0.05, R), 0.008)
	m.anchor("tip", Vector3(0, deck, hl)); m.anchor("root", Vector3(0, deck, -hl))
	return m.result("선창", Vector2(Wd + 0.4, L), false)
