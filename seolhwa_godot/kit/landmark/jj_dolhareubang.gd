# 돌하르방(우석목·벅수머리) — 제주목·정의현·대정현 성문 앞에 둘씩 세운 현무암 석상. 1754년(영조 30) 김몽규 목사 때 세웠다는 기록(『탐라지』 계열) → 1870년에 성문 앞에 있었다.
# 제주목 것은 높이 약 1.8m: 벙거지 모양 모자, 툭 튀어나온 왕눈, 큰 코, 다문 입, 두 손을 배에 얹음(한 손이 위). 정면 +z.
# params: seed, height(1.8), hand("right"|"left": 위에 얹은 손)
extends RefCounted

const Co = preload("res://kit/landmark/_common.gd")
const Hub = preload("res://kit/landmark/_hub.gd")

static func build(params: Dictionary) -> Dictionary:
	var rng := Kit.Rng.new(int(params.get("seed", 1)))
	var s: float = float(params.get("height", 1.8)) / 1.8
	var up := 1.0 if str(params.get("hand", "right")) == "right" else -1.0
	var b := Kit.Batch.new()
	var g := []
	# 받침돌
	g.append(Kit.cyl(0.42 * s, 0.48 * s, 0.25 * s, 8, 0, 0.12 * s, 0))
	# 몸(아래 넓은 원통)
	g.append(Kit.cyl(0.3 * s, 0.36 * s, 0.85 * s, 9, 0, 0.25 * s + 0.425 * s, 0))
	# 머리(길쭉)
	var hd := Kit.lump(1.0, 1, rng, 0.04, 1.0); Kit.xf(hd, 0, 1.32 * s, 0.02 * s, 0, 0, 0, 0.27 * s, 0.32 * s, 0.25 * s); g.append(hd)
	# 모자(챙 + 둥근 꼭대기)
	g.append(Kit.cyl(0.3 * s, 0.31 * s, 0.07 * s, 10, 0, 1.6 * s, 0))
	var cap := Kit.lump(1.0, 1, rng, 0.03, 1.0); Kit.xf(cap, 0, 1.68 * s, 0, 0, 0, 0, 0.22 * s, 0.16 * s, 0.22 * s); g.append(cap)
	b.add("stone", Co.pnt(Kit.merge(g), Hub.BASALT_L, 0.1, rng), 0.025)
	# 얼굴: 왕눈 둘, 큰 코, 입, 손 둘(배 위 위아래)
	var f := []
	for sx in [-1, 1]:
		var e := Kit.icosphere(0.065 * s, 0); Kit.xf(e, sx * 0.1 * s, 1.38 * s, 0.24 * s); f.append(e)
	var nose := Kit.lump(1.0, 0, rng, 0.05, 1.0); Kit.xf(nose, 0, 1.27 * s, 0.25 * s, 0, 0, 0, 0.06 * s, 0.1 * s, 0.07 * s); f.append(nose)
	f.append(Kit.box(0.14 * s, 0.025 * s, 0.03 * s, 0, 1.15 * s, 0.24 * s))
	f.append(Kit.xf(Kit.box(0.34 * s, 0.09 * s, 0.08 * s), up * 0.03 * s, 0.85 * s, 0.31 * s, 0, 0, up * 0.15))
	f.append(Kit.xf(Kit.box(0.32 * s, 0.09 * s, 0.08 * s), -up * 0.03 * s, 0.68 * s, 0.33 * s, 0, 0, -up * 0.12))
	b.add("stone", Co.pnt(Kit.merge(f), Hub.BASALT, 0.08, rng), 0.012)
	return {
		node = b.build("돌하르방"), colliders = [{ type = "circle", x = 0.0, z = 0.0, r = 0.5 * s }], lights = [], occluder = false,
		footprint = Vector2(1.0 * s, 1.0 * s), anchors = { front = Vector3(0, 0, 1.2 * s) },
	}
