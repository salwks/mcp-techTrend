# 계림(鷄林) 비각 — 김알지 탄생 설화의 숲. 숲은 kit/nature가 맡고, 여기는 1803년(순조 3) 세운 「계림김씨시조탄강유허비」와
# 그 비각(정면·측면 1칸, 사방 홍살, 팔작) + 숲 어귀 작은 표지석. 비각 치수는 가설. params: seed, marker(true)
extends RefCounted

const Co = preload("res://kit/landmark/_common.gd")
const Hub = preload("res://kit/landmark/_hub.gd")

static func build(params: Dictionary) -> Dictionary:
	var rng := Kit.Rng.new(int(params.get("seed", 1)))
	var b := Kit.Batch.new(); var r := Kit.Batch.new()
	var info := Co.hall(b, r, { bays = [3.0], depth = 3.0, dbays = 1, F = 0.45, H = 2.8, fronts = ["hongsal"], back = "hongsal", sides = "hongsal",
		roof = "paljak", ox = 1.0, oz = 1.0, rise = 1.7, lift = 0.5, bracket = "ikgong", col_r = 0.15, steps = [0.0], step_w = 1.2, roof_nx = 14, roof_nz = 12, floor = false }, rng)
	Hub.stele(b, rng, 0.0, 0.0, 1.9, 0.68, false)
	var cols := [{ type = "box", minX = -2.3, maxX = 2.3, minZ = -2.3, maxZ = 2.3 }]
	var anchors := { front = Vector3(0, 0, 3.4) }
	if params.get("marker", true):
		# 숲 어귀 표지석(자연석에 '鷄林' 새김 자리)
		var g := Hub.rock(b, rng, 4.2, 3.2, 0.9, 1.1, 0.6, [0xbab3a4, 0x8a8478], 1, 0.12, 0.3)
		var face := Co.vplane(0.45, 0.6, 0, 0.55, 0.0)
		Kit.xf(face, 4.2 + sin(0.3) * 0.32, 0, 3.2 + cos(0.3) * 0.32, 0, 0.3)
		b.add("flat", Co.pnt(face, [0x6e695f]), 0.0)
		cols.append({ type = "circle", x = 4.2, z = 3.2, r = 0.7 })
		anchors.marker = Vector3(4.2, 0, 4.4)
	return { node = Co.node2("계림비각", b, r), colliders = cols, lights = [], occluder = false, footprint = Vector2(10.0, 7.0), anchors = anchors }
