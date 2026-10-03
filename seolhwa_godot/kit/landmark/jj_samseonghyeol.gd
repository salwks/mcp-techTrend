# 삼성혈(三姓穴) — 탐라 시조 고·양·부 세 신인이 솟아났다는 땅 구멍 셋(品자 배치), 둘레를 낮게 판 잔디 마당과 돌담. 1526년 목사 이수동이 담을 두르고
# 홍문·제단을 세움, 1698년 삼성사(사당) 건립 기록 → 1870년에 담·홍살문·작은 사당이 있었다(사당 규모·위치는 가설). 구멍 지름·깊이는 실물 비례 근사.
# params: seed, shrine(true)
extends RefCounted

const Co = preload("res://kit/landmark/_common.gd")
const Hub = preload("res://kit/landmark/_hub.gd")

static func hole(b, rng: Kit.Rng, x: float, z: float, r: float) -> void:
	# 움푹한 구덩이: 가장자리 흙 고리 + 어두운 바닥 원판(조금 내려감)
	var n := 12
	var g := Kit.Geo.new()
	for i in n:
		var a0 := TAU * i / n; var a1 := TAU * (i + 1) / n
		var o0 := Vector3(x + cos(a0) * (r + 0.5), 0.08, z + sin(a0) * (r + 0.5)); var o1 := Vector3(x + cos(a1) * (r + 0.5), 0.08, z + sin(a1) * (r + 0.5))
		var i0 := Vector3(x + cos(a0) * r, -0.35, z + sin(a0) * r); var i1 := Vector3(x + cos(a1) * r, -0.35, z + sin(a1) * r)
		Co.Roof.quad_facing(g, o0, o1, i1, i0, Vector3(0, 1, 0))
		Co.Roof.tri_facing(g, Vector3(x, -0.5, z), i0, i1, Vector3.UP)
	var base := 0
	b.add("mud", Kit.paint(g, Kit.hex(0x6a5a44), Kit.hex(0x2a221a), 0.04, rng), 0.0)

static func build(params: Dictionary) -> Dictionary:
	var rng := Kit.Rng.new(int(params.get("seed", 1)))
	var b := Kit.Batch.new(); var r := Kit.Batch.new()
	# 잔디 마당(낮게 판 원형 터)
	var lawn := Kit.cyl(7.0, 7.4, 0.06, 18, 0, 0.03, -1.0)
	b.add("organic", Co.pnt(lawn, [0x7f9a52, 0x6a8442], 0.04, rng), 0.0)
	# 구멍 셋(品자): 위 하나(고), 아래 둘(양·부)
	hole(b, rng, 0.0, -3.0, 0.75)
	hole(b, rng, -2.2, 0.4, 0.6)
	hole(b, rng, 2.2, 0.4, 0.6)
	# 낮은 돌 테두리(원)
	var ring := []
	for i in 22:
		var a := TAU * i / 22
		var st := Kit.box(1.0, 0.35, 0.45); Kit.xf(st, cos(a) * 7.3, 0.17, -1.0 + sin(a) * 7.3, 0, -a + PI / 2)
		ring.append(st)
	b.add("stone", Co.pnt(Kit.merge(ring), Hub.BASALT_L, 0.08, rng), 0.015)
	# 둘레 현무암 담(앞 홍살문 틈) + 홍살문
	var cols := Hub.basalt_loop(b, rng, [Vector2(-12, -12), Vector2(12, -12), Vector2(12, 11), Vector2(-12, 11)], [[0.0, 11.0, 2.4]], 1.5)
	Co.hongsal_gate(b, 0.0, 11.0, 4.0, 5.2)
	var anchors := { holes = Vector3(0, 0, -1.0), gate = Vector3(0, 0, 11.0), outside = Vector3(0, 0, 14.0) }
	if params.get("shrine", true):
		Co.hall(b, r, { bays = [2.4, 2.8, 2.4], depth = 4.0, dbays = 1, F = 0.5, H = 2.5, fronts = ["wall", "door", "wall"], roof = "matbae", ox = 0.8, oz = 1.1,
			rise = 1.8, lift = 0.3, bracket = "ikgong", col_r = 0.15, cx = 7.4, cz = -9.0, steps = [0.0], step_w = 1.4, roof_nx = 10, roof_nz = 8, side_window = false, wall_color = [0xd8d0bc, 0xc2b8a0] }, rng)
		cols.append({ type = "box", minX = 2.6, maxX = 11.6, minZ = -11.7, maxZ = -6.3 })
		anchors.samseongsa = Vector3(7.4, 0, -6.0)
	return { node = Co.node2("삼성혈", b, r), colliders = cols, lights = [{ x = 7.4, y = 1.4, z = -6.9, kind = "shrine" }], occluder = false, footprint = Vector2(25.0, 24.0), anchors = anchors }
