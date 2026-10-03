# 운종가(雲從街, 종로) 시전 행랑 — 태종 때(1412~1414) 나라가 지어 상인에게 빌려준 긴 줄 가게채. 칸마다 가게(앞 트임·덧문), 단층 맞배 기와(일부 다락), 칸 폭 약 2.4~3m.
# 육의전(비단·무명·명주·종이·모시·어물) 등. 1870년 무렵 모습은 19세기 말 사진 비례 가설. 정면(가게 앞) +z = 거리. 로컬 x 방향 bays칸.
# params: seed, bays(12), bay(2.7), depth(5.0), goods("silk"|"cloth"|"paper"|"fish"|"mixed"), signs(true: 처마 밑 가로 현판·세로 간판 — 큰길 가게 신호)
extends RefCounted

const Co = preload("res://kit/landmark/_common.gd")
const Hub = preload("res://kit/landmark/_hub.gd")

const GOODS := { silk = [0xa3503a, 0x3c5f86, 0x7a8a4a, 0xd8b04a], cloth = [0xe8e2d0, 0xd8d0b8, 0xc8bea0], paper = [0xf0ead8, 0xe0d8c0], fish = [0x8a9aa0, 0x6a7a80, 0xb0a890], mixed = [0xa3503a, 0xe8e2d0, 0x8a6a4a, 0x3c5f86, 0xd8b04a] }

static func build(params: Dictionary) -> Dictionary:
	var rng := Kit.Rng.new(int(params.get("seed", 1)))
	var n: int = int(params.get("bays", 12)); var bay: float = float(params.get("bay", 2.7)); var d: float = float(params.get("depth", 5.0))
	var b := Kit.Batch.new(); var r := Kit.Batch.new()
	var info := Hub.haenglang(b, r, rng, n, bay, d, "none", 0.0, 0.0, 2.7, 0.35, { sides = "wall", col_color = Co.WOOD, band = [0x6b5a44, 0x5a4a36], roof_nx = n * 2, ox = 0.5, oz = 1.4 })
	var W: float = info.W
	var gl: Array = GOODS.get(str(params.get("goods", "mixed")), GOODS.mixed)
	var dark := []; var shut := []; var stall := []; var goods := []
	for i in n:
		var x := -W / 2 + bay * (i + 0.5)
		dark.append(Co.vplane(bay - 0.2, 2.6, x, 0.35 + 1.3, -d / 2 + 0.2))
		var k := rng.next()
		if k < 0.25:
			shut.append(Kit.box(bay - 0.3, 2.1, 0.08, x, 0.35 + 1.05 + 0.2, d / 2 - 0.05))   # 덧문 닫힘
		else:
			# 들어 올린 덧문(처마 밑 비스듬히) + 앞 진열 평상 + 물건
			shut.append(Kit.xf(Kit.box(bay - 0.3, 0.06, 1.2), x, 2.75, d / 2 + 0.35, 0.35, 0, 0))
			stall.append(Kit.box(bay - 0.4, 0.5, 1.0, x, 0.35 + 0.25, d / 2 - 0.3))
			for m in 3:
				var c: int = gl[int(rng.next() * gl.size()) % gl.size()]
				var gg := Kit.box(0.5, 0.18 + rng.next() * 0.2, 0.6, x - bay * 0.3 + m * bay * 0.3, 0.95, d / 2 - 0.3)
				goods.append(Co.pnt(gg, [c]))
	# 간판: 칸 절반쯤에 처마 밑 가로 현판(먹빛 판 + 흰 글자 자리), 몇 칸마다 기둥 앞 세로 간판(19세기 말 종로 사진 비례 가설)
	var boards := []; var letters := []
	if bool(params.get("signs", true)):
		for i in n:
			var x := -W / 2 + bay * (i + 0.5)
			var k2 := rng.next()
			if k2 < 0.55:
				var bw := bay * (0.55 + 0.2 * rng.next())
				boards.append(Kit.box(bw, 0.46, 0.06, x, 2.42, d / 2 + 0.12))
				var nl := 2 + int(rng.next() * 2.0)
				for q in nl:
					letters.append(Kit.box(0.16, 0.22, 0.02, x + (q - (nl - 1) * 0.5) * bw / (nl + 0.6), 2.42, d / 2 + 0.16))
			elif k2 < 0.8:
				var sx := x - bay / 2 + 0.25
				boards.append(Kit.box(0.34, 1.3, 0.06, sx, 1.75, d / 2 + 0.45))
				for q in 3:
					letters.append(Kit.box(0.18, 0.2, 0.02, sx, 2.2 - q * 0.36, d / 2 + 0.49))
	if not boards.is_empty():
		b.add("flat", Co.pnt(Kit.merge(boards), [0x2a2018, 0x33261c]), 0.012)
		b.add("flat", Co.pnt(Kit.merge(letters), [0xe8dcc0, 0xd8b04a]), 0.0)
	b.add("flat", Co.pnt(Kit.merge(dark), [0x2e241c, 0x241c16]), 0.0)
	b.add("wood", Co.pnt(Kit.merge(shut), [0x7a5c3e, 0x5e4630], 0.03, rng), 0.012)
	if not stall.is_empty(): b.add("wood", Co.pnt(Kit.merge(stall), Co.WOOD_L, 0.03, rng), 0.012)
	if not goods.is_empty(): b.add("flat", Kit.merge(goods), 0.01)
	return {
		node = Co.node2("시전행랑", b, r), colliders = [{ type = "box", minX = -W / 2 - 0.3, maxX = W / 2 + 0.3, minZ = -d / 2 - 0.3, maxZ = d / 2 - 0.6 }],
		lights = [{ x = -W / 4, y = 2.4, z = d / 2 + 0.3, kind = "lantern" }, { x = W / 4, y = 2.4, z = d / 2 + 0.3, kind = "lantern" }], occluder = true,
		footprint = Vector2(W + 1.0, d + 2.0), anchors = { street = Vector3(0, 0, d / 2 + 3.0), counter_w = Vector3(-W / 4, 0, d / 2 + 0.8), counter_e = Vector3(W / 4, 0, d / 2 + 0.8) },
	}
