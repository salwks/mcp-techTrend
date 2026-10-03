# 보신각(普信閣, 종각) — 운종가 네거리의 종루. 임진왜란 뒤 여러 번 고쳐 짓고, 1869년(고종 6) 화재 뒤 다시 지음 → 1870년에 새 종각.
# 19세기 말 사진의 단층 팔작(정면 3칸·측면 2칸 가설 — 지금 2층 누각은 1979년). 기둥 사이 아래 홍살, 가운데 큰 종(약 3m, 1468년 주조 종).
# 1895년 '보신각' 현판 이전이라 이름은 종각. params: seed
extends RefCounted

const Co = preload("res://kit/landmark/_common.gd")
const Hub = preload("res://kit/landmark/_hub.gd")

static func build(params: Dictionary) -> Dictionary:
	var rng := Kit.Rng.new(int(params.get("seed", 1)))
	var b := Kit.Batch.new(); var r := Kit.Batch.new()
	var info := Co.hall(b, r, { bays = [3.6, 4.4, 3.6], depth = 7.6, dbays = 2, F = 0.8, H = 4.6, fronts = ["hongsal", "none", "hongsal"], back = "hongsal", sides = "hongsal",
		floor = true, roof = "paljak", ox = 2.0, oz = 1.9, rise = 3.6, lift = 0.8, bracket = "dapo", col_r = 0.26, steps = [0.0], step_w = 2.4, roof_nx = 20, roof_nz = 14 }, rng)
	# 종(종각 들보에 매단 범종)
	var top: float = info.top
	var bell := []
	bell.append(Kit.cyl(0.95, 1.2, 2.4, 14, 0, top - 1.8, 0))
	bell.append(Kit.cyl(0.6, 0.95, 0.4, 14, 0, top - 0.4, 0))
	bell.append(Kit.box(0.3, 0.5, 0.3, 0, top - 0.0, 0))
	b.add("flat", Co.pnt(Kit.merge(bell), [0x5a6a5e, 0x3a463e], 0.03, rng), 0.02)
	b.add("wood", Co.pnt(Kit.box(info.W, 0.35, 0.35, 0, top + 0.1, 0), Co.WOOD, 0.03, rng), 0.012)
	# 당목(종 치는 통나무)
	b.add("wood", Co.pnt(Kit.xf(Kit.cyl(0.18, 0.18, 2.6, 6), 2.4, top - 1.6, 0, 0, 0, PI / 2), Co.WOOD_L, 0.03, rng), 0.012)
	Hub.plaque(b, 0, top - 0.45, 3.8 + 0.3, 1.8, 0.6)
	var W: float = info.W
	return {
		node = Co.node2("종각", b, r), colliders = [{ type = "box", minX = -W / 2 - 0.7, maxX = W / 2 + 0.7, minZ = -4.5, maxZ = 4.6 }],
		lights = [{ x = 0.0, y = top - 0.4, z = 4.2, kind = "lantern" }], occluder = true, footprint = Vector2(W + 2.0, 10.0),
		anchors = { bell = Vector3(0, 0.8, 0), front = Vector3(0, 0, 6.5) },
	}
