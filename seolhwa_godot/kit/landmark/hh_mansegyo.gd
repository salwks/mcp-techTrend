# 만세교(萬歲橋) — 함흥 성천강을 건너는 긴 나무다리(조선 후기 길이 약 1km라 전함, 큰물에 자주 쓸려 고쳐 놓음). 나무 말뚝 교각(가로보) 위 널 상판 + 낮은 난간.
# 게임 압축 길이 기본 120m(params.length), 너비 4m, 상판 높이 2.4m(가설). 로컬 z가 건너는 방향, 원점 = 다리 가운데 물 바닥 높이. §8 walk 포함.
# params: seed, length(120), width(4.0), deck(2.4), span(5.0)
extends RefCounted

const Co = preload("res://kit/landmark/_common.gd")

static func build(params: Dictionary) -> Dictionary:
	var rng := Kit.Rng.new(int(params.get("seed", 1)))
	var L: float = float(params.get("length", 120.0)); var Wd: float = float(params.get("width", 4.0)); var Y: float = float(params.get("deck", 2.4)); var sp: float = float(params.get("span", 5.0))
	var b := Kit.Batch.new()
	var n := maxi(2, roundi(L / sp))
	var piles := []; var caps := []; var deck := []; var rails := []
	for i in n + 1:
		var z := -L / 2 + L * i / n
		var y := Y - 0.18
		for k in 3:
			var x := -Wd / 2 + 0.3 + (Wd - 0.6) * k / 2
			piles.append(Kit.cyl(0.14, 0.17, y + 1.2, 5, x + rng.between(-0.08, 0.08), (y - 1.2) / 2, z, rng.between(-0.04, 0.04), 0, rng.between(-0.04, 0.04), false))
		piles.append(Kit.xf(Kit.box(Wd + 0.6, 0.12, 0.12), 0, Y * 0.45, z, 0, 0, 0.35))   # 가새
		caps.append(Kit.box(Wd + 0.8, 0.25, 0.3, 0, y - 0.12, z))
		for s in [-1, 1]: rails.append(Kit.box(0.1, 0.9, 0.1, s * (Wd / 2 - 0.05), Y + 0.45, z))
	b.add("wood", Co.pnt(Kit.merge(piles), [0x5e4836, 0x3e2e22], 0.05, rng), 0.012)
	b.add("wood", Co.pnt(Kit.merge(caps), [0x6a5038, 0x4e3a2a], 0.04, rng), 0.012)
	# 널 상판: 칸마다 판 한 장(색 얼룩)
	for i in n:
		var za := -L / 2 + L * i / n; var zb := -L / 2 + L * (i + 1) / n
		deck.append(Co.pnt(Kit.box(Wd, 0.12, zb - za - 0.04, 0, Y - 0.06, (za + zb) / 2), [0x8a7458, 0x6e5a44], 0.06, rng))
		for s in [-1, 1]: rails.append(Kit.box(0.08, 0.08, zb - za, s * (Wd / 2 - 0.05), Y + 0.85, (za + zb) / 2))
	b.add("wood", Kit.merge(deck), 0.012)
	b.add("wood", Co.pnt(Kit.merge(rails), [0x7a5c40, 0x5a4430], 0.04, rng), 0.0)
	var zs := [-L / 2 - 1.0]; var ys := [0.1]
	zs.append(-L / 2); ys.append(Y)
	zs.append(L / 2); ys.append(Y)
	zs.append(L / 2 + 1.0); ys.append(0.1)
	return {
		node = b.build("만세교"),
		colliders = [{ type = "box", minX = -Wd / 2 - 0.2, maxX = -Wd / 2 + 0.1, minZ = -L / 2, maxZ = L / 2 }, { type = "box", minX = Wd / 2 - 0.1, maxX = Wd / 2 + 0.2, minZ = -L / 2, maxZ = L / 2 }],
		lights = [], occluder = false, footprint = Vector2(Wd + 1.0, L + 2.0),
		anchors = { north_end = Vector3(0, Y, -L / 2), south_end = Vector3(0, Y, L / 2), middle = Vector3(0, Y, 0) },
		walk = [{ minX = -Wd / 2 + 0.2, maxX = Wd / 2 - 0.2, minZ = -L / 2 - 1.0, maxZ = L / 2 + 1.0, z = zs, y = ys }],
	}
