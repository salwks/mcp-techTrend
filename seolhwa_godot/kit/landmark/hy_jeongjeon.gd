# 궁궐 정전(법전) 공용 — 2단 월대(돌난간·삼도 계단) 위 중층 팔작 건물. 근정전·인정전이 이 형식.
# params: seed, name, bays, depth, dbays, H, up_inset_x, up_inset_z, woldae([[w,d,h],…] 아래부터), plaque_w
# 반환 interior(마루 = 월대 위 기단 높이)
extends RefCounted

const Co = preload("res://kit/landmark/_common.gd")
const Hub = preload("res://kit/landmark/_hub.gd")

static func build(params: Dictionary) -> Dictionary:
	var rng := Kit.Rng.new(int(params.get("seed", 1)))
	var b := Kit.Batch.new(); var r := Kit.Batch.new()
	var bays: Array = params.get("bays", [5.0, 5.8, 6.4, 5.8, 5.0])
	var D: float = float(params.get("depth", 20.0))
	var wd: Array = params.get("woldae", [[46.0, 40.0, 1.3], [38.0, 32.0, 1.3]])
	var y := 0.0
	var cz := 0.0
	var wnodes := []
	for k in wd.size():
		var w: float = wd[k][0]; var d: float = wd[k][1]; var h: float = wd[k][2]
		var bb := Kit.Batch.new()
		Hub.woldae(bb, rng, w, d, h, 0.0, 0.0, true, [-4.0, 0.0, 4.0])
		var n: Node3D = bb.build("월대%d" % k)
		n.position = Vector3(0, y, -(float(wd[0][1]) - d) * 0.3 if k > 0 else 0.0)
		cz = n.position.z
		wnodes.append(n)
		y += h
	var fr := []
	for i in bays.size(): fr.append("door")
	var o := { bays = bays, depth = D, dbays = int(params.get("dbays", 5)), F = 0.9, H = float(params.get("H", 6.0)), fronts = fr, roof = "paljak",
		ox = 2.6, oz = 2.4, rise = D * 0.42 + 1.0, lift = 1.0, bracket = "dapo", col_r = 0.34, cz = cz, steps = [0.0], step_w = 3.0, roof_nx = 26, roof_nz = 16,
		up_inset_x = int(params.get("up_inset_x", 0)), up_inset_z = int(params.get("up_inset_z", 1)), up_H = float(params.get("H", 6.0)) * 0.55, skirt_rise = 1.8,
		up_fronts = [], up_roof = "paljak", up_rise = D * 0.36 + 1.0 }
	var info := Hub.jungcheung(b, r, o, rng)
	Hub.plaque(b, 0, (info.up.top as float) - 0.5, cz + (info.up.z1 as float) + 0.35, float(params.get("plaque_w", 3.0)), 1.0)
	var hall := Co.node2(str(params.get("name", "정전")), b, r)
	hall.position.y = y
	var root := Node3D.new(); root.name = str(params.get("name", "정전")) + "_월대"
	for n in wnodes: root.add_child(n)
	root.add_child(hall)
	var W: float = info.W
	var w0: float = wd[0][0]; var d0: float = wd[0][1]
	return {
		node = root, colliders = [{ type = "box", minX = -W / 2 - 0.8, maxX = W / 2 + 0.8, minZ = cz - D / 2 - 0.8, maxZ = cz + D / 2 + 0.8 }],
		lights = [{ x = -6.0, y = y + 1.5, z = cz + D / 2 + 0.8, kind = "lantern" }, { x = 6.0, y = y + 1.5, z = cz + D / 2 + 0.8, kind = "lantern" }], occluder = true,
		footprint = Vector2(w0 + 2.0, d0 + 4.0), anchors = { court = Vector3(0, 0, d0 / 2 + 10.0), woldae = Vector3(0, y, cz + D / 2 + 3.0), throne = Vector3(0, y + 0.9, cz - 2.0) },
		interior = { minX = -W / 2, maxX = W / 2, minZ = cz - D / 2, maxZ = cz + D / 2, floor_y = y + 0.9, camera = { pitch = 52, distance = 22 }, hide = [hall.get_node("roof")] },
		walk = [{ minX = -w0 / 2 + 0.3, maxX = w0 / 2 - 0.3, minZ = -d0 / 2 + 0.3, maxZ = d0 / 2 + 1.2, z = [-d0 / 2 + 0.3, d0 / 2 - 0.3, d0 / 2 + 1.2], y = [y, y, 0.0] }],
	}
