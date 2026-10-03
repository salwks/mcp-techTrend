# 육조(六曹) 관청 모듈 — 광화문 앞 육조거리 양옆에 늘어선 관청(이조·호조·예조·병조·형조·공조 + 의정부·한성부 등) 한 곳.
# 거리에 면한 긴 행랑(벽 + 작은 창) 가운데 솟을대문 → 마당 → 정청(정면 5칸 팔작). 「육조앞」 옛 사진·『한양도』 비례 가설.
# 정면(대문) +z = 거리 쪽. 배치 때 거리 동쪽 관청은 ry=+90°, 서쪽은 −90°. params: seed, name("예조"), width(36), depth(30)
extends RefCounted

const Co = preload("res://kit/landmark/_common.gd")
const Hub = preload("res://kit/landmark/_hub.gd")
const Roof = preload("res://kit/landmark/_roof.gd")

static func build(params: Dictionary) -> Dictionary:
	var rng := Kit.Rng.new(int(params.get("seed", 1)))
	var W: float = float(params.get("width", 36.0)); var Dp: float = float(params.get("depth", 30.0))
	var b := Kit.Batch.new(); var r := Kit.Batch.new()
	var hd := 4.4
	var zf := Dp / 2 - hd / 2
	# 거리 행랑(대문 양옆): 칸 3.0
	var gw := 3.6
	var side_n := maxi(2, roundi((W / 2 - gw / 2) / 3.0))
	var side_w := (W / 2 - gw / 2) / side_n
	for s in [-1, 1]:
		Hub.haenglang(b, r, rng, side_n, side_w, hd, "window", s * (gw / 2 + side_w * side_n / 2), zf, 2.6, 0.4, { roof_nx = side_n * 2 })
	# 솟을대문(가운데 칸 지붕 높게)
	var gi := Co.hall(b, r, { bays = [gw], depth = hd, dbays = 1, F = 0.4, H = 3.4, fronts = ["gate"], back = "none", sides = "none", floor = false,
		roof = "matbae", ox = 0.7, oz = 1.3, rise = 2.0, lift = 0.3, bracket = "none", col_r = 0.18, cz = zf, steps = [0.0], step_w = 2.4, roof_nx = 6, roof_nz = 8,
		col_color = Co.WOOD, band = Co.WOOD }, rng)
	Hub.plaque(b, 0, 3.3, zf + hd / 2 + 0.25, 1.6, 0.5)
	# 정청
	var hi := Co.hall(b, r, { bays = [3.0, 3.2, 3.4, 3.2, 3.0], depth = 8.0, dbays = 2, F = 0.9, H = 3.2, fronts = ["window", "open", "open", "open", "window"],
		roof = "paljak", ox = 1.6, oz = 1.5, rise = 3.0, lift = 0.65, bracket = "ikgong", col_r = 0.2, cz = -Dp / 2 + 7.0, steps = [0.0], step_w = 2.2, roof_nx = 18, roof_nz = 12 }, rng)
	# 옆·뒤 담
	var cols := []
	for e in [[Vector2(-W / 2, zf - hd / 2), Vector2(-W / 2, -Dp / 2)], [Vector2(W / 2, zf - hd / 2), Vector2(W / 2, -Dp / 2)], [Vector2(-W / 2, -Dp / 2), Vector2(W / 2, -Dp / 2)]]:
		var a: Vector2 = e[0]; var c: Vector2 = e[1]
		Co.tile_wall(b, a.x, a.y, c.x, c.y, 2.2, rng)
		cols.append(Co.wall_collider(a.x, a.y, c.x, c.y, 0.6))
	cols.append({ type = "box", minX = -W / 2, maxX = -gw / 2, minZ = zf - hd / 2, maxZ = zf + hd / 2 })
	cols.append({ type = "box", minX = gw / 2, maxX = W / 2, minZ = zf - hd / 2, maxZ = zf + hd / 2 })
	cols.append({ type = "box", minX = -9.0, maxX = 9.0, minZ = -Dp / 2 + 2.2, maxZ = -Dp / 2 + 11.8 })
	return {
		node = Co.node2("관청_" + str(params.get("name", "예조")), b, r), colliders = cols,
		lights = [{ x = -gw / 2 - 0.4, y = 2.0, z = zf + hd / 2 + 0.3, kind = "lantern" }, { x = gw / 2 + 0.4, y = 2.0, z = zf + hd / 2 + 0.3, kind = "lantern" }], occluder = true,
		footprint = Vector2(W, Dp), anchors = { gate = Vector3(0, 0, Dp / 2 + 1.5), yard = Vector3(0, 0, 0.0), hall = Vector3(0, 0.9, -Dp / 2 + 9.0) },
	}
