# 오죽헌(烏竹軒, 보물) — 율곡 이이가 태어난 별당. 15세기 말~16세기 초 건물(1870년에도 같은 건물). 정면 3칸·측면 2칸 팔작, 겹처마 익공,
# 서쪽 1칸 온돌방(몽룡실)·동쪽 2칸 대청. 뒤뜰 검은 대나무(오죽). 문성사(1975)·율곡기념관은 1870년에 없으므로 뺌. 강릉 반가 본채는 kit-culture 몫.
# 칸 폭·기단 높이는 사진 비례 가설. params: seed, bamboo(true)
extends RefCounted

const Co = preload("res://kit/landmark/_common.gd")
const Hub = preload("res://kit/landmark/_hub.gd")

static func build(params: Dictionary) -> Dictionary:
	var rng := Kit.Rng.new(int(params.get("seed", 1)))
	var b := Kit.Batch.new(); var r := Kit.Batch.new()
	var info := Co.hall(b, r, { bays = [2.7, 2.9, 2.9], depth = 5.4, dbays = 2, F = 1.1, H = 2.7, fronts = ["door", "open", "open"],
		roof = "paljak", ox = 1.5, oz = 1.4, rise = 2.4, lift = 0.6, bracket = "ikgong", col_r = 0.16, col_color = Co.WOOD, band = Co.WOOD,
		steps = [1.45], step_w = 1.6, roof_nx = 16, roof_nz = 12 }, rng)
	Hub.plaque(b, 1.45, info.top - 0.35, 2.7 + 0.25, 1.4, 0.48)
	var cols := [{ type = "box", minX = -5.0, maxX = 5.0, minZ = -3.6, maxZ = 3.6 }]
	if params.get("bamboo", true):
		# 뒤뜰 오죽 덤불(검은 줄기 + 잎 덩이)
		var st := []
		for k in 40:
			var x := rng.between(-6.0, 6.0); var z := rng.between(-7.5, -4.6)
			var h := rng.between(3.0, 5.0)
			st.append(Kit.cyl(0.03, 0.04, h, 4, x, h / 2, z, 0, 0, 0, false))
		b.add("flat", Co.pnt(Kit.merge(st), [0x2e2a26, 0x1e1b18]), 0.0)
		for k in 7:
			var g := Kit.lump(1.0, 1, rng, 0.3, 0.8); Kit.xf(g, -5.4 + k * 1.8, 3.8 + rng.next() * 0.6, -6.0 + rng.between(-0.6, 0.6), 0, 0, 0, 1.3, 1.0, 1.0)
			b.add("leaf", Kit.paint(g, Kit.hex(0x6f8a4a), Kit.hex(0x3e5a32), 0.08, rng), 0.02)
		cols.append({ type = "box", minX = -6.3, maxX = 6.3, minZ = -7.8, maxZ = -4.4 })
	return {
		node = Co.node2("오죽헌", b, r), colliders = cols, lights = [{ x = -2.9, y = 2.2, z = 2.8, kind = "window" }], occluder = true,
		footprint = Vector2(13.0, 16.0), anchors = { daecheong = Vector3(1.45, 1.1, 0.5), mongryongsil = Vector3(-2.9, 1.1, 0.0), yard = Vector3(0, 0, 6.0) },
		interior = { minX = -4.25, maxX = 4.25, minZ = -2.7, maxZ = 2.7, floor_y = 1.1, camera = { pitch = 50, distance = 15 }, hide = [] },
	}
