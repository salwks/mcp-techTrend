# 종묘 정전(正殿) — 역대 왕·왕비 신주를 모신 긴 맞배 건물. 1608년 중건 뒤 1726·1836년 증축 → 1870년에는 신실 19칸(지금과 같음).
# 정면 19칸 + 좌우 협실 각 2칸, 앞 툇칸은 기둥만(트임), 신실마다 판문. 양끝에서 앞으로 꺾인 동·서 월랑(5칸). 앞 넓은 월대(박석, 가운데 신로).
# 실측 정면 약 101m·월대 약 109×69m → 월대만 압축(100×46m, 가설). 원점 = 월대 가운데. params: seed, bays(19)
extends RefCounted

const Co = preload("res://kit/landmark/_common.gd")
const Hub = preload("res://kit/landmark/_hub.gd")

static func build(params: Dictionary) -> Dictionary:
	var rng := Kit.Rng.new(int(params.get("seed", 1)))
	var nb: int = int(params.get("bays", 19))
	var b := Kit.Batch.new(); var r := Kit.Batch.new()
	var bay := 4.2
	var W := (nb + 4) * bay
	var D := 12.0
	var wz := -10.0
	# 월대(낮음, 박석) + 신로
	var ww := W + 6.0; var wd := 46.0
	b.add("stone", Co.pnt(Kit.box(ww, 1.0, wd, 0, 0.4, 0), [0xaaa498, 0x7b766c], 0.04, rng), 0.03)
	b.add("stone", Co.pnt(Kit.box(ww - 0.6, 0.05, wd - 0.6, 0, 0.92, 0), [0xb8b2a2, 0x9a9484], 0.06, rng), 0.0)
	b.add("stone", Co.pnt(Kit.box(2.4, 0.08, wd / 2 + 6, 0, 0.96, wd / 4 - 3.0), [0xcac3b2, 0xa8a190], 0.03, rng), 0.0)
	Co.platform(b, 3.0, 0.1, 1.0, rng, wd / 2 + 0.05, [0.0], 2.6)
	var bays := []; var fr := []
	for i in nb + 4:
		bays.append(bay)
		fr.append("wall" if i < 2 or i >= nb + 2 else "board")
	var info := Co.hall(b, r, { bays = bays, depth = D, dbays = 3, F = 1.6, H = 4.6, fronts = fr, roof = "matbae", ox = 1.4, oz = 2.6, rise = 5.0, lift = 0.45,
		bracket = "ikgong", col_r = 0.3, cz = wz, steps = [], base_margin = 0.6, roof_nx = 30, roof_nz = 8, side_window = false }, rng)
	# 신실 판문 문선(칸마다 가운데 세로 줄 + 띠)
	var dl := []
	for i in nb:
		var x := -W / 2 + (i + 2.5) * bay
		dl.append(Co.vplane(0.08, 3.6, x, 1.6 + 2.0, wz + D / 2 + 0.11))
		dl.append(Co.vplane(bay - 0.6, 0.1, x, 1.6 + 1.2, wz + D / 2 + 0.11))
	b.add("flat", Co.pnt(Kit.merge(dl), [0x2e241c]), 0.0)
	# 앞 툇칸 기둥 줄(신실 앞 트인 퇴)
	var tg := []
	for i in nb + 5:
		tg.append(Kit.cyl(0.28, 0.3, 4.6, 6, -W / 2 + i * bay, 1.6 + 2.3, wz + D / 2 + 2.0, 0, 0, 0, false))
	b.add("flat", Co.pnt(Kit.merge(tg), Co.DAN_R, 0.0), 0.02)
	b.add("wood", Co.pnt(Kit.box(W, 0.2, 2.4, 0, 1.55, wz + D / 2 + 1.0), Co.WOOD_L, 0.03, rng), 0.0)
	# 동·서 월랑(앞으로 꺾인 5칸 맞배, 기둥만)
	var wings := []
	for s in [-1, 1]:
		var lb := Kit.Batch.new(); var lr := Kit.Batch.new()
		Hub.haenglang(lb, lr, rng, 5, 4.0, 7.0, "none", 0.0, 0.0, 4.0, 1.4, { back = "wall", sides = "none", col_color = Co.DAN_R, band = Co.DAN_G, bracket = "ikgong" })
		var n := Co.node2("월랑", lb, lr)
		n.rotation.y = -s * PI / 2
		n.position = Vector3(s * (W / 2 + 1.0), 0, wz + D / 2 + 12.0)
		wings.append(n)
	var root := Co.node2("종묘정전", b, r)
	for n in wings: root.add_child(n)
	return {
		node = root, colliders = [{ type = "box", minX = -W / 2 - 0.6, maxX = W / 2 + 0.6, minZ = wz - D / 2 - 0.6, maxZ = wz + D / 2 + 0.6 },
			{ type = "box", minX = -W / 2 - 5.0, maxX = -W / 2 + 2.6, minZ = wz + D / 2, maxZ = wz + D / 2 + 22.0 }, { type = "box", minX = W / 2 - 2.6, maxX = W / 2 + 5.0, minZ = wz + D / 2, maxZ = wz + D / 2 + 22.0 }],
		lights = [], occluder = true, footprint = Vector2(ww + 10.0, wd + 4.0),
		anchors = { sinro = Vector3(0, 1.0, wd / 2 - 2.0), woldae = Vector3(0, 1.0, 6.0), front = Vector3(0, 0, wd / 2 + 4.0) },
		walk = [{ minX = -ww / 2 + 0.3, maxX = ww / 2 - 0.3, minZ = -wd / 2 + 0.3, maxZ = wd / 2 + 1.5, z = [-wd / 2 + 0.3, wd / 2 - 0.3, wd / 2 + 1.5], y = [0.95, 0.95, 0.0] }],
	}
