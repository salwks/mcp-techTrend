# 솟을삼문 — 관아·객사·향교 정문. 3칸(가운데 칸이 넓고 지붕이 한 단 높은 솟을지붕), 맞배, 판문(가운데 열림).
# 관아 외삼문·내삼문 모두 이 형식이 흔하다(조선 후기 현존 관아·향교). kind="outer"는 조금 크고 위에 홍살.
# 남원 관아 외삼문이 누문(2층)이었는지 확인 못 함 → 단층 솟을삼문으로 둔 것은 가설.
# params: seed, kind("outer"|"inner"), name(현판, 기본 없음)
extends RefCounted

const Co = preload("res://kit/landmark/_common.gd")
const Roof = preload("res://kit/landmark/_roof.gd")

static func build(params: Dictionary) -> Dictionary:
	var rng := Kit.Rng.new(int(params.get("seed", 1)))
	var outer: bool = params.get("kind", "outer") == "outer"
	var sw := 2.7 if outer else 2.4
	var cw := 3.4 if outer else 3.0
	var D := 3.0 if outer else 2.6
	var H := 3.5 if outer else 3.1
	var b := Kit.Batch.new(); var roof := Kit.Batch.new()
	var info := Co.hall(b, roof, {
		bays = [sw, cw, sw], depth = D, dbays = 1, F = 0.45, H = H, fronts = ["gate_closed", "gate", "gate_closed"],
		enclose = false, back = "none", floor = false, roof = "none", bracket = "ikgong", col_r = 0.17, base_margin = 0.5,
		steps = [0.0], step_w = cw - 0.4,
	}, rng)
	# 지붕 셋(맞배): 가운데 솟음
	var top: float = info.top
	Roof.add(roof, { type = "matbae", hw = cw / 2 + 0.9, hd = D / 2 + 1.25, eave = top + 1.05, rise = 1.7, lift = 0.35, thick = 0.22, nx = 10, nz = 10,
		gable_x = cw / 2 + 0.05, gable_d = D / 2, gable_y = top + 0.3 }, 0.0, 0.0)
	for s in [-1, 1]:
		var x: float = s * (cw / 2 + sw / 2 + 0.05)
		Roof.add(roof, { type = "matbae", hw = sw / 2 + 0.75, hd = D / 2 + 1.1, eave = top + 0.5, rise = 1.4, lift = 0.3, thick = 0.2, nx = 8, nz = 10 }, x, 0.0)
	# 가운데 솟은 칸 위 홍살(외삼문) / 벽
	if outer:
		Co.hongsal(b, -cw / 2 + 0.2, cw / 2 - 0.2, top + 0.35, top + 1.0, D / 2)
	else:
		b.add("mud", Co.pnt(Kit.box(cw, 0.7, 0.18, 0, top + 0.65, 0), Co.PLASTER), 0.015)
	var nm: String = str(params.get("name", ""))
	if nm != "":
		b.add("wood", Co.pnt(Kit.box(1.4, 0.5, 0.08, 0, top + 0.7, D / 2 + 0.2), [0x3a2c22, 0x2c2018]), 0.012)
	var W: float = info.W
	var node := Co.node2("삼문", b, roof)
	return {
		node = node,
		colliders = [{ type = "box", minX = -W / 2 - 0.3, maxX = -cw / 2, minZ = -D / 2 - 0.3, maxZ = D / 2 + 0.3 },
			{ type = "box", minX = cw / 2, maxX = W / 2 + 0.3, minZ = -D / 2 - 0.3, maxZ = D / 2 + 0.3 }],
		lights = [{ x = -cw / 2 - 0.3, y = 2.4, z = D / 2 + 0.4, kind = "lantern" }, { x = cw / 2 + 0.3, y = 2.4, z = D / 2 + 0.4, kind = "lantern" }],
		occluder = true,
		footprint = Vector2(W + 2.0, D + 2.6),
		anchors = { gate = Vector3(0, 0, 0), outside = Vector3(0, 0, D / 2 + 2.5), inside = Vector3(0, 0, -D / 2 - 2.0), wall_left = Vector3(-W / 2 - 0.4, 0, 0), wall_right = Vector3(W / 2 + 0.4, 0, 0) },
	}
