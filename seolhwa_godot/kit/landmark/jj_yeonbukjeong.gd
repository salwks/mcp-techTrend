# 조천 연북정(朝天 戀北亭, 제주 조천진) — 조천진성(현무암 막쌓기 진성, 1590년 무렵 쌓고 1599 중수) 안 높은 돌 대지 위의 정자.
# 정면 3칸·측면 2칸 팔작, 사방 트임(1590 '쌍벽정' → 1599 '연북정'으로 고침). 1870년 모습은 지금과 비슷했다고 봄(가설).
# 진성은 둥글고 들쭉날쭉한 현무암 성담(높이 약 2.5m)이 약 16×12m를 두르고 안을 흙으로 채워 대지를 이룸(실제 둘레·높이는 가설).
# 남쪽(+z) 가운데 돌계단으로 오른다. 정자는 대지 위 가운데, 정면 +z. 걷기 면(walk): 계단 경사 + 대지 위(높이 H).
# params: seed, height(2.5)
extends RefCounted

const Co = preload("res://kit/landmark/_common.gd")
const Hub = preload("res://kit/landmark/_hub.gd")

static func outline(rng: Kit.Rng, hw: float, hd: float, n: int) -> Array:
	# 둥근 네모(초타원)에 들쭉날쭉한 반지름 — 바깥 성담 꺾은선(위에서 볼 때 반시계)
	var pts := []
	for i in n:
		var a := TAU * i / n
		var c := cos(a); var s := sin(a)
		var e := 3.2
		var x := signf(c) * pow(absf(c), 2.0 / e) * hw
		var z := signf(s) * pow(absf(s), 2.0 / e) * hd
		var k := 1.0 + rng.between(-0.04, 0.04)
		pts.append(Vector2(x * k, z * k))
	return pts

static func build(params: Dictionary) -> Dictionary:
	var rng := Kit.Rng.new(int(params.get("seed", 1)))
	var H: float = float(params.get("height", 2.5))
	var b := Kit.Batch.new(); var r := Kit.Batch.new()
	var hw := 8.0; var hd := 6.0
	var pts := outline(rng, hw, hd, 14)
	var sw := 1.4                       # 계단 반폭
	# 바깥 성담: 계단 자리(남 가운데)는 끊음. basalt_loop의 gap = [x, z, 반폭]
	var wcols := Hub.basalt_loop(b, rng, pts, [[0.0, hd, sw + 0.1]], H, 0.9)
	# 안 채움(흙 대지): 성담 안쪽 몸 + 위 면(풀·흙)
	var inner := PackedVector2Array()
	for p in pts: inner.append((p as Vector2) * 0.94)
	var fill := Kit.Geo.new()
	var n := inner.size()
	for i in n:
		var p0 := inner[i]; var p1 := inner[(i + 1) % n]
		var mid := (p0 + p1) / 2
		Co.Roof.quad_facing(fill, Vector3(p0.x, -0.3, p0.y), Vector3(p1.x, -0.3, p1.y), Vector3(p1.x, H - 0.05, p1.y), Vector3(p0.x, H - 0.05, p0.y), Vector3(mid.x, 0, mid.y))
	var idx := Geometry2D.triangulate_polygon(inner)
	for k in range(0, idx.size(), 3):
		var A := inner[idx[k]]; var B := inner[idx[k + 1]]; var C := inner[idx[k + 2]]
		Co.Roof.tri_facing(fill, Vector3(A.x, H - 0.05, A.y), Vector3(B.x, H - 0.05, B.y), Vector3(C.x, H - 0.05, C.y), Vector3.UP)
	b.add("stone", Co.pnt(fill, [0x8a8460, 0x3a3733], 0.04, rng), 0.0)
	# 성담 위 갓돌(납작한 현무암 판, 들쭉날쭉)
	var caps := []
	for i in pts.size():
		var a: Vector2 = pts[i]; var c: Vector2 = pts[(i + 1) % pts.size()]
		var L := a.distance_to(c); var dir := (c - a) / L
		var t := 0.0
		while t < L:
			var w := rng.between(0.7, 1.1)
			var m := a + dir * (t + w / 2)
			if not (absf(m.x) < sw + 0.3 and m.y > 0.0):
				var s := Kit.box(minf(w, L - t) - 0.04, 0.22, 1.0)
				Kit.xf(s, m.x, H + 0.08, m.y, rng.between(-0.05, 0.05), -atan2(dir.y, dir.x), rng.between(-0.05, 0.05))
				caps.append(s)
			t += w
	b.add("stone", Co.pnt(Kit.merge(caps), Hub.BASALT_L, 0.1, rng), 0.012)
	# 남쪽 돌계단: 성담 밖으로 나온 계단 + 양옆 막돌 볼
	var ns := maxi(6, roundi(H / 0.25))
	var run := 0.38
	var sz0 := hd - 0.6                  # 계단 윗단(대지 가장자리)
	var sg := []
	for k in ns:
		var hh := H * (k + 1) / ns
		var zf := sz0 + (ns - k) * run
		sg.append(Kit.box(sw * 2 - 0.1, hh, run + 0.02, 0, hh / 2, zf - run / 2))
	b.add("stone", Co.pnt(Kit.merge(sg), Hub.BASALT_L, 0.08, rng), 0.012)
	var cheek := []
	for s in [-1.0, 1.0]:
		var L := ns * run + 0.6
		var cz := sz0 + L / 2 - 0.3
		var cg := Kit.box(0.5, H + 0.15, L)
		# 볼 윗면이 계단 경사 따라 낮아지도록 앞쪽을 깎음(앞 끝 높이 0.4)
		for i in cg.pos.size():
			var p := cg.pos[i]
			if p.y > 0.0:
				var t := clampf((p.z + L / 2) / L, 0.0, 1.0)
				cg.pos[i] = Vector3(p.x, lerpf((H + 0.15) / 2, 0.4 - (H + 0.15) / 2, t), p.z)
		Kit.xf(cg, s * (sw + 0.15), (H + 0.15) / 2, cz)
		cheek.append(cg)
	b.add("stone", Co.pnt(Kit.merge(cheek), Hub.BASALT, 0.1, rng), 0.015)
	# 정자: 대지 위(높이 H) 가운데, 정면 3칸·측면 2칸 팔작, 사방 트임(난간 없음), 낮은 돌 기단
	var pb := Kit.Batch.new(); var pr := Kit.Batch.new()
	var info := Hub.pavilion(pb, pr, { bays = [2.6, 3.0, 2.6], depth = 4.6, dbays = 2, F = 0.6, H = 2.9, roof = "paljak", ox = 1.4, oz = 1.4,
		rise = 2.2, lift = 0.6, bracket = "ikgong", col_r = 0.17, under = "none", plinth = true, rail = false, stair = false,
		overhang = 0.0, roof_nx = 16, roof_nz = 12, col_color = [0x8a6a50, 0x6a5040], band = [0x6e7a6c, 0x58625a] }, rng)
	Hub.plaque(pb, 0, info.top - 0.35, 2.3 + 0.18, 1.5, 0.5)
	var root := Node3D.new(); root.name = "연북정"
	root.add_child(b.build("조천진성"))
	var pn := Co.node2("정자", pb, pr)
	pn.position = Vector3(0, H, -0.6)
	root.add_child(pn)
	# 충돌: 성담 조각(계단 틈 제외) + 정자 기둥 둘레는 열어 둠(마루에 올라설 수 있게)
	var cols := wcols.duplicate()
	for s in [-1.0, 1.0]:
		cols.append({ type = "box", minX = s * (sw + 0.15) - 0.3, maxX = s * (sw + 0.15) + 0.3, minZ = sz0, maxZ = sz0 + ns * run + 0.3 })
	var walk := [
		{ minX = -sw + 0.05, maxX = sw - 0.05, minZ = sz0 - 0.2, maxZ = sz0 + ns * run + 0.4, z = [sz0 - 0.2, sz0, sz0 + ns * run + 0.4], y = [H, H, 0.0] },
		{ minX = -hw * 0.9, maxX = hw * 0.9, minZ = -hd * 0.9, maxZ = sz0 - 0.2, z = [-hd * 0.9, sz0 - 0.2], y = [H, H] },
	]
	return {
		node = root, colliders = cols, lights = [{ x = 0.0, y = H + 3.0, z = 1.8, kind = "lantern" }], occluder = true,
		footprint = Vector2(18.0, 14.0 + 2.0), walk = walk, top_y = H,
		anchors = { stair_foot = Vector3(0, 0, sz0 + ns * run + 1.0), top = Vector3(0, H, 3.2), pavilion = Vector3(0, H + 0.6, -0.6) },
	}
