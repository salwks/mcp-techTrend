# 내아(內衙) — 수령 가족 살림채. ㄱ자 기와집: 몸채 정면 5칸(방·방·대청 2칸·방) + 왼쪽(서쪽)에서 앞으로 꺾인 부엌·찬간 날개 3칸.
# 남원 내아는 남아 있지 않다 → 현존 내아(고창·무장 등)와 반가 안채 평면을 따른 가설.
# params: seed, wing(true)
extends RefCounted

const Co = preload("res://kit/landmark/_common.gd")

static func build(params: Dictionary) -> Dictionary:
	var rng := Kit.Rng.new(int(params.get("seed", 1)))
	var root := Node3D.new(); root.name = "내아"
	var body := Kit.Batch.new(); var roof := Kit.Batch.new()
	var bw := 2.5
	var info := Co.hall(body, roof, {
		bays = [bw, bw, bw, bw, bw], depth = 5.4, dbays = 2, F = 0.7, H = 2.6, fronts = ["window", "door", "open", "open", "door"],
		roof = "paljak", ox = 1.6, oz = 1.5, rise = 2.5, bracket = "none", col_r = 0.15, col_color = Co.WOOD, band = Co.WOOD,
		steps = [bw * 0.5], roof_nx = 24, roof_nz = 14,
	}, rng)
	body.add("wood", Co.pnt(Kit.box(info.W - 0.2, 0.08, 0.7, 0, info.F - 0.02, 2.7 + 0.35), Co.WOOD_L, 0.03, rng), 0.015)
	var main := Co.node2("몸채", body, roof)
	root.add_child(main)
	var W: float = info.W
	var cols := [{ type = "box", minX = -W / 2 - 0.75, maxX = W / 2 + 0.75, minZ = -3.45, maxZ = 3.3 }]
	var foot := Vector2(info.roof_hw * 2, info.roof_hd * 2)
	var hide := [main.get_node("roof")]
	if params.get("wing", true):
		# 날개: 정면이 동쪽(+x)을 보게. 로컬 +z → 월드 +x (ry=+90°)
		var wb := Kit.Batch.new(); var wr := Kit.Batch.new()
		var wi := Co.hall(wb, wr, {
			bays = [2.4, 2.4, 2.4], depth = 4.4, dbays = 1, F = 0.45, H = 2.4, fronts = ["board", "open", "window"],
			roof = "paljak", ox = 1.4, oz = 1.3, rise = 2.0, bracket = "none", col_r = 0.14, col_color = Co.WOOD, band = Co.WOOD,
			steps = [], roof_nx = 18, roof_nz = 12, side_window = false,
		}, rng)
		var wn := Co.node2("날개", wb, wr)
		var wx := -W / 2 + 2.2
		var wz := 2.7 + 7.2 / 2 + 0.6
		wn.transform = Transform3D(Basis(Vector3.UP, PI / 2), Vector3(wx, 0, wz))
		root.add_child(wn)
		cols.append({ type = "box", minX = wx - 2.9, maxX = wx + 2.9, minZ = wz - 4.3, maxZ = wz + 4.3 })
		foot = Vector2(foot.x, foot.y + 7.0)
		hide.append(wn.get_node("roof"))
	return {
		node = root, colliders = cols,
		lights = [{ x = -W / 2 + bw * 1.5, y = info.F + 1.3, z = 2.8, kind = "window" }, { x = W / 2 - bw * 0.5, y = info.F + 1.3, z = 2.8, kind = "window" }],
		occluder = true, footprint = foot,
		anchors = { daecheong = Vector3(bw * 0.5, info.F, 0.3), yard = Vector3(bw, 0, 6.5), kitchen = Vector3(-W / 2 + 2.2 + 2.6, 0, 6.3) },
		interior = { minX = -W / 2, maxX = W / 2, minZ = -2.7, maxZ = 2.7, floor_y = info.F, camera = { pitch = 50, distance = 14 }, hide = hide },
	}
