# 강릉대도호부 칠사당(七事堂) — 부사가 칠사(농사·호구·교육·병무·세금·재판·풍속)를 보던 동헌 성격 건물. 1867년(고종 4) 화재 뒤 다시 지어 1870년에 새 건물.
# 정면 7칸 一자 팔작 + 서쪽 끝 2칸은 바닥을 높인 누마루(계자난간). 칸 폭·높이는 사진 비례 가설. params: seed
extends RefCounted

const Co = preload("res://kit/landmark/_common.gd")
const Hub = preload("res://kit/landmark/_hub.gd")
const Roof = preload("res://kit/landmark/_roof.gd")

static func build(params: Dictionary) -> Dictionary:
	var rng := Kit.Rng.new(int(params.get("seed", 1)))
	var b := Kit.Batch.new(); var r := Kit.Batch.new()
	var bw := 2.7
	var D := 6.4
	# 본채 5칸(온돌·대청)
	var info := Co.hall(b, r, { bays = [bw, bw, bw, bw, bw], depth = D, dbays = 2, F = 0.8, H = 2.8, fronts = ["door", "open", "open", "door", "window"],
		roof = "paljak", ox = 1.5, oz = 1.4, rise = 2.6, lift = 0.6, bracket = "ikgong", col_r = 0.17, cx = 1.35, steps = [-1.35, 2.7], roof_nx = 22, roof_nz = 12 }, rng)
	# 서쪽 누마루 2칸(바닥 1.6m, 계자난간, 사방 트임) — 본채 지붕보다 조금 낮은 팔작
	var px: float = 1.35 - info.W / 2 - bw
	var pi := Hub.pavilion(b, r, { bays = [bw, bw], depth = D, dbays = 2, F = 1.5, H = 2.2, roof = "paljak", ox = 1.2, oz = 1.4, rise = 2.1, lift = 0.6,
		bracket = "ikgong", col_r = 0.16, cx = px, cz = 0.0, under = "wood", plinth = true, stair = false, rail_gaps = [["E", 0.0, 3.4]], overhang = 0.4, roof_nx = 12, roof_nz = 12 }, rng)
	Hub.plaque(b, 1.35, info.top - 0.4, D / 2 + 0.25, 2.0, 0.65)
	var x0: float = px - bw - 0.8; var x1: float = 1.35 + info.W / 2 + 0.8
	var n := Co.node2("칠사당", b, r)
	return {
		node = n, colliders = [{ type = "box", minX = x0, maxX = x1, minZ = -D / 2 - 0.8, maxZ = D / 2 + 0.8 }],
		lights = [{ x = 3.0, y = 2.0, z = D / 2 + 0.1, kind = "window" }, { x = px, y = 3.6, z = D / 2, kind = "lantern" }], occluder = true,
		footprint = Vector2(x1 - x0, D + 3.4), anchors = { daecheong = Vector3(0, 0.8, 1.0), numaru = Vector3(px, 1.7, 0), yard = Vector3(0, 0, D / 2 + 6.0) },
		interior = { minX = 1.35 - info.W / 2, maxX = 1.35 + info.W / 2, minZ = -D / 2, maxZ = D / 2, floor_y = 0.8, camera = { pitch = 50, distance = 16 }, hide = [n.get_node("roof")] },
	}
