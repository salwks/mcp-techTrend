# 석굴암(石窟庵, 토함산, 신라 751~774) — 1870년 무렵: 화강암 돔 석굴 위에 흙을 덮은 둔덕이 산비탈에 반쯤 묻혀 있고,
# 앞쪽(전실) 지붕은 없이 돌벽만 드러난 허물어진 모습, 입구는 어둡게 열려 있었다고 봄(1907년 '재발견'·1913 일제 해체 수리 전, 가설).
# 앞마당은 거친 막돌을 깐 작은 터 + 앞 축대, 한쪽에 3칸 초가 암자(수광전 자리의 작은 요사 — 이름·위치는 가설).
# 정면(굴 입구)은 +z. 실제 굴은 동해(동쪽)를 보므로 배치 때 ry = +90°(+z → +x=동)로 돌려 놓는다. 뒤(-z)는 산비탈로 이어지게 둔덕을
# 길게 늘였고 밑동은 sink만큼 묻었다(flatten:false 권장, 앞마당만 평평하면 됨).
# params: seed, hut(true), sink(0.6)
extends RefCounted

const Co = preload("res://kit/landmark/_common.gd")
const Hub = preload("res://kit/landmark/_hub.gd")
const Tum = preload("res://kit/landmark/gj_tumulus.gd")
const Choga = preload("res://kit/village/choga.gd")

const GRANITE := [0xb0a998, 0x857e70]
const GRANITE_D := [0x8e877a, 0x6a645a]

static func build(params: Dictionary) -> Dictionary:
	var rng := Kit.Rng.new(int(params.get("seed", 1)))
	var sink: float = float(params.get("sink", 0.6))
	var b := Kit.Batch.new()
	# 흙 둔덕: 석굴 위 둥근 봉긋함(z −4.6, 앞 끝이 정면 벽 안에 들도록) + 뒤로 조금 더 높은 산비탈 덩이(z −7)
	var centers := [Vector4(0.0, -4.6, 7.2, 5.4), Vector4(0.3, -7.0, 6.5, 6.0)]
	var mound := Tum.dome_geo(rng, centers, Vector2(0, -5.5), 30, 7, sink, 0.3, [0x8e9a58, 0x7a874a, 0x6a6a40, 0x6e6448])
	b.add("organic", mound, 0.05)
	# 무너진 흙(비탈에 드러난 흙·돌 몇 군데)
	for k in 7:
		var a := rng.next() * TAU
		var rr := rng.between(4.5, 6.5)
		var x := cos(a) * rr; var z := -4.6 + sin(a) * rr
		if z > -1.0 and absf(x) < 5.0: x = signf(x + 0.01) * 5.5
		var g := Kit.lump(rng.between(0.6, 1.2), 0, rng, 0.3, 0.5)
		Kit.xf(g, x, Tum.height_at(centers, x, z, sink) - 0.1, z)
		b.add("rock", Co.pnt(g, Hub.EARTH, 0.08, rng), 0.02)
	# 앞 돌벽(전실 자리, 지붕 없음): 입구 둘레 화강암 면 + 양옆 날개벽(앞으로 꺾임)
	var fz := 2.0                       # 입구 면 z
	var ow := 2.6; var oh := 3.0         # 입구 너비·높이(홍예 위 반원 포함)
	var walls := []
	# 정면 벽: 입구 양옆 덩이 + 위 인방(홍예 대신 반원 구멍은 어두운 판으로)
	var fwall := PackedVector2Array()
	var nn := 8
	fwall.append(Vector2(-4.2, -sink)); fwall.append(Vector2(4.2, -sink)); fwall.append(Vector2(4.2, 4.2)); fwall.append(Vector2(3.0, 4.6))
	fwall.append(Vector2(-3.0, 4.6)); fwall.append(Vector2(-4.2, 4.2))
	var face := Co.extrude_xy(fwall, 1.6, fz)
	b.add("stone", Co.pnt(face, GRANITE, 0.05, rng), 0.03)
	# 면석 줄(먹선 없이) — 막돌을 고르게 쌓은 느낌
	var fs := []
	for row in 6:
		var yy := 0.35 + row * 0.7
		var n := 6
		for i in n:
			var x := -4.0 + (i + 0.5 + (0.4 if row % 2 == 1 else 0.0)) * 8.0 / n
			if absf(x) > 3.9: continue
			if absf(x) < ow / 2 + 0.55 and yy < oh + 0.4: continue
			fs.append(Co.vplane(8.0 / n - 0.12, 0.6, x, yy, fz + 0.815))
	b.add("stone", Co.pnt(Kit.merge(fs), [0xa8a190, 0x8c8576], 0.07, rng), 0.0)
	# 입구 돌 문틀(설주 + 둥근 머리 판) + 어두운 구멍
	var fr := []
	fr.append(Kit.box(0.45, oh - ow / 2 + 0.1, 0.5, -ow / 2 - 0.22, (oh - ow / 2 + 0.1) / 2, fz + 0.85))
	fr.append(Kit.box(0.45, oh - ow / 2 + 0.1, 0.5, ow / 2 + 0.22, (oh - ow / 2 + 0.1) / 2, fz + 0.85))
	for i in nn:
		var a0 := PI * i / nn; var a1 := PI * (i + 1) / nn
		var am := (a0 + a1) / 2
		var rr := ow / 2 + 0.22
		var seg := Kit.box(rr * (a1 - a0) + 0.06, 0.45, 0.5)
		Kit.xf(seg, cos(am) * rr, oh - ow / 2 + sin(am) * rr, fz + 0.85, 0, 0, am + PI / 2)
		fr.append(seg)
	b.add("stone", Co.pnt(Kit.merge(fr), [0xc0b9a8, 0x989182], 0.04, rng), 0.02)
	var hole := Kit.Geo.new()
	var c0 := Vector3(0, oh - ow / 2, fz + 0.83)
	for i in nn:
		var a0 := PI * i / nn; var a1 := PI * (i + 1) / nn
		Co.Roof.tri_facing(hole, c0, c0 + Vector3(cos(a0), sin(a0), 0) * ow / 2, c0 + Vector3(cos(a1), sin(a1), 0) * ow / 2, Vector3(0, 0, 1))
	Co.Roof.quad_facing(hole, Vector3(-ow / 2, 0.02, fz + 0.83), Vector3(ow / 2, 0.02, fz + 0.83), Vector3(ow / 2, oh - ow / 2, fz + 0.83), Vector3(-ow / 2, oh - ow / 2, fz + 0.83), Vector3(0, 0, 1))
	b.add("flat", Co.pnt(hole, [0x1a1714, 0x0c0a09]), 0.0)
	# 양옆 날개벽(전실 돌벽, 지붕 없이 허물어짐 — 높이 들쭉날쭉)
	for s in [-1.0, 1.0]:
		var L := 3.6
		var ang: float = s * 0.32
		for k in 4:
			var hh := 2.8 - k * 0.45 + rng.between(-0.25, 0.2)
			var t := (k + 0.5) / 4.0
			var px: float = s * (4.0 + sin(absf(ang)) * L * t); var pz := fz + 0.8 + cos(ang) * L * t
			var bk := Kit.box(0.95, hh, 0.9 * L / 4.0 + 0.05)
			Kit.xf(bk, px, hh / 2 - 0.2, pz, rng.between(-0.04, 0.04), ang, rng.between(-0.04, 0.04))
			walls.append(bk)
	b.add("stone", Co.pnt(Kit.merge(walls), GRANITE_D, 0.07, rng), 0.025)
	# 무너진 돌 몇 개(벽 위·발치)
	for k in 6:
		var s: float = -1.0 if k % 2 == 0 else 1.0
		var g := Kit.box(rng.between(0.5, 0.9), rng.between(0.35, 0.5), rng.between(0.4, 0.7))
		Kit.xf(g, s * rng.between(2.6, 5.2), 0.15, fz + rng.between(1.4, 4.8), rng.between(-0.3, 0.3), rng.next() * PI, rng.between(-0.3, 0.3))
		b.add("stone", Co.pnt(g, GRANITE_D, 0.06, rng), 0.015)
	# 정면 벽 위로 흘러내린 흙·풀(허물어진 느낌)
	for k in 4:
		var g := Kit.lump(1.0, 1, rng, 0.25, 1.0)
		Kit.xf(g, -3.0 + k * 2.0 + rng.between(-0.3, 0.3), 4.35, fz - 0.4, 0, rng.next(), 0, rng.between(1.2, 1.7), 0.4, 1.3)
		b.add("organic", Co.pnt(g, [0x8e9a58, 0x6e7444], 0.05, rng), 0.03)
	# 앞마당: 거친 막돌 바닥(9 × 6) + 앞 축대(낮은 돌 단)
	var cz := fz + 0.8 + 3.4
	b.add("stone", Co.pnt(Kit.box(10.0, 0.25, 6.8, 0, -0.05, cz), [0x9c9584, 0x857e6e], 0.06, rng), 0.02)
	var ps := []
	for k in 22:
		var g := Kit.box(rng.between(0.6, 1.2), 0.1, rng.between(0.5, 1.0))
		Kit.xf(g, rng.between(-4.4, 4.4), 0.1, cz + rng.between(-3.0, 3.0), 0, rng.next() * PI)
		ps.append(g)
	b.add("stone", Co.pnt(Kit.merge(ps), [0xaaa392, 0x8e8878], 0.08, rng), 0.0)
	var front_z := cz + 3.4
	var ts := []
	var x := -5.0
	while x < 5.0:
		var w := rng.between(0.7, 1.2)
		var g := Kit.box(minf(w, 5.0 - x) - 0.05, rng.between(0.55, 0.75), 0.6)
		Kit.xf(g, x + w / 2, 0.0, front_z, 0, rng.between(-0.08, 0.08))
		ts.append(g)
		x += w
	b.add("stone", Co.pnt(Kit.merge(ts), GRANITE_D, 0.08, rng), 0.012)
	var anchors := { cave = Vector3(0, 0, fz + 1.4), yard = Vector3(0, 0, cz), front = Vector3(0, 0, front_z + 1.5) }
	var cols := [
		{ type = "box", minX = -4.4, maxX = 4.4, minZ = -6.0, maxZ = fz + 0.8 },   # 정면 벽 + 둔덕(오를 수 없음)
		{ type = "circle", x = 0.0, z = -4.6, r = 6.2 }, { type = "circle", x = 0.3, z = -7.0, r = 5.6 },
		{ type = "box", minX = -6.0, maxX = -4.2, minZ = fz + 0.8, maxZ = fz + 4.2 },
		{ type = "box", minX = 4.2, maxX = 6.0, minZ = fz + 0.8, maxZ = fz + 4.2 },
	]
	var root := Node3D.new(); root.name = "석굴암"
	root.add_child(b.build("석굴"))
	if params.get("hut", true):
		# 3칸 초가 암자: 앞마당 오른쪽(+x), 마당을 보도록 −90° 돌림(정면이 −x)
		var hut: Dictionary = Choga.build({ seed = int(params.get("seed", 1)) + 7, w = 5.4, d = 3.4, chimney = true })
		var hn: Node3D = hut.node
		var hp := Vector3(8.6, 0, cz + 0.4)
		hn.position = hp
		hn.rotation.y = -PI / 2
		root.add_child(hn)
		cols.append({ type = "box", minX = hp.x - 2.2, maxX = hp.x + 2.2, minZ = hp.z - 3.2, maxZ = hp.z + 3.2 })
		anchors.hut = hp + Vector3(-3.0, 0, 0)
	return {
		node = root, colliders = cols, lights = [{ x = 0.0, y = 1.4, z = fz + 1.0, kind = "shrine" }], occluder = true,
		footprint = Vector2(23.0, 24.0), anchors = anchors,
	}
