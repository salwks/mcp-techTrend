# 고을 돌것(settlement stonework) — 박석 마당·길, 디딤돌 줄, 석축(다듬은 돌 쌓은 단 앞면), 하마비·비석.
#   params: { kind, seed, … }
#     baksuk  박석 깔기(관아·객사 앞 마당, 대문 앞 길): w, d — 넓적한 막다듬 돌판을 엇갈려 깐다(땅 위 3~6cm). 걸어 다님(걷기 면 = 땅 + 0.04)
#     didim   디딤돌 줄(마당·텃밭 사이): len, step(0.7) — 로컬 z 방향
#     seokchuk 석축(다듬은 장대석 층쌓기 앞면, 관아·향교 단·축대): len(로컬 x), h, tiers — 원점 = 위 단 앞 가장자리, 앞(+z)으로 낙차
#     bi      하마비·비석: kind_bi("hama" | "bi"), h — 받침돌 + 비신 + (bi) 지붕돌
#   고증(참고): 관아·향교 앞 하마비(「대소인원개하마」), 관아 마당 박석, 경사지 석축은 docs/reports/settlement-rules.md §6.
extends RefCounted
const C := preload("res://kit/village/_common.gd")

const STONE := [0xb4ada0, 0x8b8579]
const STONE_D := [0x9e978a, 0x726c62]

static func footprint(params: Dictionary) -> Vector2:
	match String(params.get("kind", "baksuk")):
		"baksuk": return Vector2(float(params.get("w", 6.0)), float(params.get("d", 6.0)))
		"didim": return Vector2(1.0, float(params.get("len", 4.0)))
		"seokchuk": return Vector2(float(params.get("len", 8.0)), 1.2)
		"bi": return Vector2(1.2, 1.0)
	return Vector2(2, 2)

static func build(params: Dictionary) -> Dictionary:
	var m := C.M.new(int(params.get("seed", 1)))
	var R := m.rng
	match String(params.get("kind", "baksuk")):
		"baksuk":
			var w := float(params.get("w", 6.0)); var d := float(params.get("d", 6.0))
			var z := -d / 2
			var row := 0
			while z < d / 2 - 0.05:
				var rd: float = minf(0.45 + m.r() * 0.35, d / 2 - z)
				var x := -w / 2 + (0.0 if row % 2 == 0 else -0.3)
				while x < w / 2 - 0.05:
					var rw: float = 0.55 + m.r() * 0.6
					var x0 := maxf(x, -w / 2); var x1 := minf(x + rw, w / 2)
					if x1 - x0 > 0.12:
						var hh := 0.035 + m.r() * 0.03
						m.add("p", "stone", C.PA(Kit.box(x1 - x0 - 0.04, hh, rd - 0.04, (x0 + x1) / 2, hh / 2 - 0.005, z + rd / 2), STONE if m.r() < 0.6 else STONE_D, 0.05, R), 0.006)
					x += rw
				z += rd; row += 1
			m.walk_floor(-w / 2, w / 2, -d / 2, d / 2, 0.04)
		"didim":
			var L := float(params.get("len", 4.0)); var st := float(params.get("step", 0.7))
			var n := maxi(2, int(L / st))
			for i in n:
				var zz := -L / 2 + (i + 0.5) * L / n
				var sw := 0.45 + m.r() * 0.2
				m.add("p", "stone", C.PA(Kit.box(sw, 0.09, sw * (0.7 + m.r() * 0.3), (m.r() - 0.5) * 0.2, 0.04, zz), STONE, 0.06, R), 0.008)
				m.walk_floor(-sw / 2, sw / 2, zz - 0.2, zz + 0.2, 0.08)
		"seokchuk":
			var L := float(params.get("len", 8.0)); var h := float(params.get("h", 1.2))
			var tiers := maxi(1, int(params.get("tiers", ceili(h / 0.38))))
			var th := h / tiers
			for k in tiers:
				var y0 := -h + k * th
				var x := -L / 2 + (0.0 if k % 2 == 0 else -0.45)
				while x < L / 2 - 0.05:
					var bw := 0.9 + m.r() * 0.6
					var x0 := maxf(x, -L / 2); var x1 := minf(x + bw, L / 2)
					if x1 - x0 > 0.15:
						m.add("p", "stone", C.PA(Kit.box(x1 - x0 - 0.02, th - 0.02, 0.45, (x0 + x1) / 2, y0 + th / 2, 0.22 + (tiers - 1 - k) * 0.03), STONE if (k + int(x)) % 2 == 0 else STONE_D, 0.04, R), 0.01)
					x += bw
			m.box_c(-L / 2, L / 2, 0.0, 0.45)
		"bi":
			var hh := float(params.get("h", 1.6))
			m.add("p", "stone", C.PA(Kit.box(0.9, 0.3, 0.6, 0, 0.15, 0), STONE_D, 0.04, R), 0.01)
			m.add("p", "stone", C.PA(Kit.box(0.55, hh, 0.16, 0, 0.3 + hh / 2, 0), STONE, 0.03, R), 0.01)
			if String(params.get("kind_bi", "hama")) == "bi":
				m.add("p", "stone", C.PA(Kit.box(0.8, 0.22, 0.42, 0, 0.3 + hh + 0.11, 0), STONE_D, 0.04, R), 0.01)
			m.circle(0, 0, 0.5)
	return m.result("돌_" + String(params.get("kind", "")), footprint(params))
