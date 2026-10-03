# 궁궐 문(목조 문, 석축 없음) — 돈화문(정면 5칸 중층 우진각)·흥례문·근정문(3칸 중층 우진각)·진선문·인정문(3칸 단층) 같은 궁궐 안팎 문.
# 칸마다 판문(가운데 열림), 낮은 돌 기단 + 앞 계단(가운데 어도). 칸 폭·높이는 사진 비례 가설.
# params: seed, name, bays([3.6,4.4,3.6]), depth(5.6), stories(1|2), roof("ujin"|"paljak"), H(3.8)
extends RefCounted

const Co = preload("res://kit/landmark/_common.gd")
const Hub = preload("res://kit/landmark/_hub.gd")

static func build(params: Dictionary) -> Dictionary:
	var rng := Kit.Rng.new(int(params.get("seed", 1)))
	var bays: Array = params.get("bays", [3.6, 4.4, 3.6])
	var D: float = float(params.get("depth", 5.6))
	var st: int = int(params.get("stories", 2))
	var H: float = float(params.get("H", 3.8))
	var b := Kit.Batch.new(); var r := Kit.Batch.new()
	var fr := []
	var mid := bays.size() / 2
	for i in bays.size(): fr.append("gate" if i == mid else ("gate_closed" if bays.size() <= 3 or absf(i - mid) == 1 else "board"))
	var o := { bays = bays, depth = D, dbays = 2, F = 0.6, H = H, fronts = fr, back = "none", sides = "board", floor = false,
		roof = str(params.get("roof", "ujin")), ox = 1.9, oz = 1.8, rise = D * 0.5 + 0.8, lift = 0.75, bracket = "dapo", col_r = 0.25,
		steps = [0.0], step_w = float(bays[mid]) - 0.6, roof_nx = 22, roof_nz = 14, base_margin = 0.9 }
	var info := {}
	if st == 2:
		var uf := []
		for i in bays.size(): uf.append("board")
		o.up_fronts = uf; o.up_H = H * 0.72; o.skirt_rise = 1.6; o.up_roof = o.roof; o.up_rise = o.rise; o.up_enclose = true
		info = Hub.jungcheung(b, r, o, rng)
	else:
		info = Co.hall(b, r, o, rng)
	var W: float = info.W
	var ptop: float = (info.up.top as float) if st == 2 else (info.top as float)
	Hub.plaque(b, 0, ptop - 0.45, D / 2 + 0.3, 2.4, 0.8)
	var cols := [{ type = "box", minX = -W / 2 - 0.4, maxX = -float(bays[mid]) / 2, minZ = -D / 2, maxZ = D / 2 }, { type = "box", minX = float(bays[mid]) / 2, maxX = W / 2 + 0.4, minZ = -D / 2, maxZ = D / 2 }]
	return {
		node = Co.node2("궁문_" + str(params.get("name", "")), b, r), colliders = cols,
		lights = [{ x = -float(bays[mid]) / 2 - 0.5, y = 2.2, z = D / 2 + 0.4, kind = "lantern" }, { x = float(bays[mid]) / 2 + 0.5, y = 2.2, z = D / 2 + 0.4, kind = "lantern" }],
		occluder = true, footprint = Vector2(W + 2.0, D + 3.0), anchors = { outside = Vector3(0, 0, D / 2 + 3.0), inside = Vector3(0, 0, -D / 2 - 3.0) },
	}
