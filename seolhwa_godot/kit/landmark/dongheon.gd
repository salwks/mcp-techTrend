# 동헌(東軒) — 수령 집무 건물. 정면 7칸(가운데 3칸 대청 + 좌우 온돌방), 측면 3칸, 팔작지붕, 높은 돌 기단.
# 남원 동헌은 남아 있지 않다 → 규모·평면은 현존 조선 후기 동헌(무장·고창·김제 동헌 등) 평균을 따른 가설.
# params: seed, bays(정면 칸 수 5|7, 기본 7), bay(칸 폭 m, 기본 2.8), depth(기본 7.2), hyeonpan(현판 bool)
extends RefCounted

const Co = preload("res://kit/landmark/_common.gd")

static func build(params: Dictionary) -> Dictionary:
	var rng := Kit.Rng.new(int(params.get("seed", 1)))
	var n: int = int(params.get("bays", 7))
	var bw: float = float(params.get("bay", 2.8))
	var D: float = float(params.get("depth", 7.2))
	var bays := []; var fronts := []
	var mid := n / 2
	for i in n:
		bays.append(bw * (1.12 if i == mid else 1.0))
		var d := absi(i - mid)
		fronts.append("open" if d <= 1 else ("door" if d == 2 else "window"))
	var body := Kit.Batch.new(); var roof := Kit.Batch.new()
	var info := Co.hall(body, roof, {
		bays = bays, depth = D, dbays = 3, F = 1.05, H = 3.3, fronts = fronts, roof = "paljak",
		ox = 1.9, oz = 1.7, rise = 3.3, lift = 0.7, bracket = "ikgong", col_r = 0.2, steps = [0.0], step_w = 2.6,
		roof_nx = 30, roof_nz = 16,
	}, rng)
	# 툇마루(앞 퇴) 겸 대청 앞 마루 확장
	body.add("wood", Co.pnt(Kit.box(info.W - 0.2, 0.1, 0.9, 0, info.F - 0.02, D / 2 + 0.45), Co.WOOD_L, 0.03, rng), 0.015)
	# 현판(처마 밑, 가운데)
	if params.get("hyeonpan", true):
		body.add("wood", Co.pnt(Kit.box(2.2, 0.75, 0.08, 0, info.top + 0.0 - 0.45, D / 2 + 0.25), [0x3a2c22, 0x2c2018]), 0.012)
		body.add("flat", Co.pnt(Kit.box(1.7, 0.4, 0.04, 0, info.top - 0.45, D / 2 + 0.3), [0xe8dcb8]), 0.0)
	var node := Co.node2("동헌", body, roof)
	var W: float = info.W
	var bx: float = info.base[0] / 2; var bz: float = info.base[1] / 2
	return {
		node = node,
		colliders = [{ type = "box", minX = -bx, maxX = bx, minZ = -bz, maxZ = bz - 0.2 }],
		lights = [{ x = -W / 2 + bw * 1.5, y = info.F + 1.3, z = D / 2 + 0.1, kind = "window" }, { x = W / 2 - bw * 1.5, y = info.F + 1.3, z = D / 2 + 0.1, kind = "window" },
			{ x = 0.0, y = info.top - 0.2, z = D / 2 + 0.6, kind = "lantern" }],
		occluder = true,
		footprint = Vector2(info.roof_hw * 2, info.roof_hd * 2),
		anchors = { daecheong = Vector3(0, info.F, 0.5), maru_front = Vector3(0, info.F, D / 2 + 0.6), steps = Vector3(0, 0, bz + 1.2), yard = Vector3(0, 0, bz + 5.0) },
		interior = { minX = -W / 2, maxX = W / 2, minZ = -D / 2, maxZ = D / 2, floor_y = info.F, camera = { pitch = 50, distance = 15 }, hide = [node.get_node("roof")] },
	}
