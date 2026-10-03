# 북청 사자놀음 마당 표지 — 함경도 북청 정월 대보름 사자놀음(마을마다 사자를 앞세워 집집을 돌고 마당에서 놂, 조선 후기 성행). 놀이 마당(다진 흙 + 테두리 돌) +
# 대보름 등 장대(종이 등 줄) + 사자탈 놓는 틀(큰 사자 머리, 털 — 회색·흰색 거친 털) + 북. 모두 가설(정해진 시설 없음 → 게임 표지). params: seed
extends RefCounted

const Co = preload("res://kit/landmark/_common.gd")

static func build(params: Dictionary) -> Dictionary:
	var rng := Kit.Rng.new(int(params.get("seed", 1)))
	var b := Kit.Batch.new()
	var R := 7.0
	b.add("mud", Co.pnt(Kit.cyl(R, R, 0.05, 20, 0, 0.025, 0), [0xb8a684, 0xa08e6a], 0.05, rng), 0.0)
	var st := []
	for i in 26:
		var a := TAU * i / 26
		var g := Kit.lump(rng.between(0.22, 0.35), 0, rng, 0.25, 0.7); Kit.xf(g, cos(a) * R, 0.1, sin(a) * R); st.append(g)
	b.add("rock", Co.pnt(Kit.merge(st), [0xb0aa9c, 0x8a8478], 0.08, rng), 0.015)
	# 등 장대(뒤) + 종이 등 줄
	var px := -4.0; var pz := -5.0
	b.add("wood", Co.pnt(Kit.cyl(0.09, 0.12, 8.0, 6, px, 4.0, pz), [0x6a5038], 0.03, rng), 0.012)
	var lamps := []
	for k in 6:
		var t := float(k) / 5.0
		var p := Vector3(px + t * 7.0, 7.6 - t * 5.4, pz + t * 1.5)
		lamps.append(Kit.xf(Kit.cyl(0.18, 0.18, 0.4, 8), p.x, p.y - 0.25, p.z))
	b.add("lamp", Co.pnt(Kit.merge(lamps), [0xf2e2b8, 0xe0c890]), 0.012)
	b.add("flat", Co.pnt(Kit.limb(Vector3(px, 7.6, pz), Vector3(px + 7.0, 2.2, pz + 1.5), 0.015, 0.015, 3), [0x3a3028]), 0.0)
	# 사자탈 틀 + 사자 머리(털 덩이, 큰 눈, 붉은 입)
	var sx := 3.0; var sz := -3.5
	b.add("wood", Co.pnt(Kit.merge([Kit.box(0.12, 1.4, 0.12, sx - 0.6, 0.7, sz), Kit.box(0.12, 1.4, 0.12, sx + 0.6, 0.7, sz), Kit.box(1.4, 0.12, 0.12, sx, 1.35, sz)]), Co.WOOD, 0.03, rng), 0.012)
	var head := Kit.lump(0.75, 1, rng, 0.25, 0.9); Kit.xf(head, sx, 1.95, sz)
	b.add("organic", Kit.paint(head, Kit.hex(0xd8d4c8), Kit.hex(0x8a8478), 0.12, rng), 0.03)
	var mane := Kit.lump(1.0, 1, rng, 0.4, 0.5); Kit.xf(mane, sx, 1.3, sz - 0.6, 0, 0, 0, 1.0, 0.9, 1.0)
	b.add("organic", Kit.paint(mane, Kit.hex(0xc8c2b4), Kit.hex(0x6e695f), 0.14, rng), 0.03)
	var f := []
	for s in [-1, 1]: f.append(Kit.xf(Kit.icosphere(0.13, 0), sx + s * 0.28, 2.15, sz + 0.62))
	b.add("flat", Co.pnt(Kit.merge(f), [0xf0ead8]), 0.01)
	b.add("flat", Co.pnt(Kit.box(0.6, 0.18, 0.2, sx, 1.7, sz + 0.66), [0xa3503a]), 0.01)
	# 북(마당가)
	b.add("flat", Co.pnt(Kit.xf(Kit.cyl(0.45, 0.45, 0.5, 12), -3.0, 0.85, 3.5, PI / 2, 0, 0), [0xa3503a, 0x7a3a2a]), 0.015)
	b.add("wood", Co.pnt(Kit.merge([Kit.box(0.08, 0.6, 0.08, -3.3, 0.3, 3.5), Kit.box(0.08, 0.6, 0.08, -2.7, 0.3, 3.5)]), Co.WOOD), 0.01)
	return {
		node = b.build("북청사자마당"), colliders = [{ type = "circle", x = px, z = pz, r = 0.3 }, { type = "box", minX = sx - 0.9, maxX = sx + 0.9, minZ = sz - 1.4, maxZ = sz + 0.8 }],
		lights = [{ x = px + 3.5, y = 5.0, z = pz + 0.7, kind = "lantern" }], occluder = false, footprint = Vector2(R * 2 + 1, R * 2 + 1),
		anchors = { center = Vector3(0, 0, 0), lion = Vector3(sx, 0, sz + 1.6), drum = Vector3(-3.0, 0, 4.6) },
	}
