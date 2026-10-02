# 남원읍성 배치 도우미 — 평지 방형 석성(실제 둘레 약 2.5km, 높이 약 4m)을 권역 압축(K=0.30)에 맞춰 한 변 side m로 줄여
# 성벽·모서리·치·성문(옹성) 모듈로 조립한다. 원점 = 성 한가운데 바닥, 남쪽(+z)이 남문(완월루).
# 실제 한 변 ≈ 2.5km/4 ≈ 625m → ×0.30 ≈ 190m. 그래서 기본 side = 190.
# layout(params) → 조각 목록 [{kit, params, x, z, ry}]: 지형 엔진이 조각마다 add_static 하면 성벽마다 가림·타일 스트리밍이 따로 된다.
# build(params) → 전체를 한 Node3D로(미리보기·작은 맵용).
# params: seed, side(190), chi_per_side(2), seg_max(24), gates({S:"완월루",N:"공신루",W:"망미루",E:"향일루"}), ongseong(true)
extends RefCounted

const S = preload("res://kit/landmark/_seong.gd")

const GATES := { S = "완월루", N = "공신루", W = "망미루", E = "향일루" }
const GATE_W := 16.0

# 변별 회전: 로컬 바깥 +z가 그 변의 바깥을 보게
const SIDE_RY := { S = 0.0, E = PI / 2, N = PI, W = -PI / 2 }

static func layout(params: Dictionary) -> Array:
	var side: float = float(params.get("side", 190.0))
	var nchi: int = int(params.get("chi_per_side", 2))
	var seg_max: float = float(params.get("seg_max", 24.0))
	var seed: int = int(params.get("seed", 1))
	var gates: Dictionary = params.get("gates", GATES)
	var ong: bool = params.get("ongseong", true)
	var h := side / 2
	var t := S.T
	var out := []
	var k := 0
	for sd in ["S", "E", "N", "W"]:
		var ry: float = SIDE_RY[sd]
		var bs := Basis(Vector3.UP, ry)
		# 변의 로컬 좌표: u ∈ [-h, h] (로컬 x), 벽 중심선 z = h - t/2 (로컬 +z 바깥)
		var zc := h - t / 2
		var put := func(kit: String, p: Dictionary, u: float, zl: float, extra_ry := 0.0) -> void:
			var w := bs * Vector3(u, 0, zl)
			out.append({ kit = "landmark/" + kit, params = p, x = w.x, z = w.z, ry = wrapf(ry + extra_ry, -PI, PI), side = sd })
		# 모서리(각 변의 +u 끝 = 반시계 다음 변과 만나는 귀). 로컬 바깥 +x,+z 인 모서리 모듈 → 이 변 기준 +u 끝
		put.call("seong_corner", { seed = seed + k }, h - t / 2, zc); k += 1
		# 성문(가운데)
		var gname: String = gates.get(sd, "")
		var g0 := -h + t; var g1 := h - t
		var spans := []
		if gname != "":
			put.call("seongmun", { seed = seed + k, name = gname, width = GATE_W, ongseong = ong, open_side = "east" if sd in ["S", "N"] else "west" }, 0.0, zc); k += 1
			spans = [[g0, -GATE_W / 2], [GATE_W / 2, g1]]
		else:
			spans = [[g0, g1]]
		# 성벽 구간
		for sp in spans:
			var L: float = sp[1] - sp[0]
			var n := maxi(1, ceili(L / seg_max))
			for i in n:
				var a: float = sp[0] + L * i / n; var c: float = sp[0] + L * (i + 1) / n
				put.call("seong_wall", { seed = seed + k, length = c - a + 0.05 }, (a + c) / 2, zc); k += 1
		# 치: 문과 모서리 사이 가운데
		for i in nchi:
			var u := -h + side * (i + 0.5) / nchi
			if absf(u) < GATE_W: u = signf(u if u != 0 else 1.0) * (GATE_W / 2 + (h - GATE_W / 2) / 2)
			put.call("seong_chi", { seed = seed + k }, u, h); k += 1
	return out

static func build(params: Dictionary) -> Dictionary:
	var side: float = float(params.get("side", 190.0))
	var root := Node3D.new(); root.name = "남원읍성"
	var colliders := []; var lights := []; var anchors := {}
	var pieces := layout(params)
	var cache := {}
	for p in pieces:
		var path: String = "res://kit/" + p.kit + ".gd"
		if not cache.has(path): cache[path] = load(path)
		var info: Dictionary = cache[path].build(p.params)
		var n: Node3D = info.node
		var xf := Transform3D(Basis(Vector3.UP, p.ry), Vector3(p.x, 0, p.z))
		n.transform = xf
		n.name = "%s_%s_%d" % [p.side, p.kit.get_file(), root.get_child_count()]
		root.add_child(n)
		for c in info.colliders:
			if c.type == "circle":
				var w: Vector3 = xf * Vector3(c.x, 0, c.z)
				colliders.append({ type = "circle", x = w.x, z = w.z, r = c.r })
			else:
				var a: Vector3 = xf * Vector3(c.minX, 0, c.minZ); var b2: Vector3 = xf * Vector3(c.maxX, 0, c.maxZ)
				colliders.append({ type = "box", minX = minf(a.x, b2.x), maxX = maxf(a.x, b2.x), minZ = minf(a.z, b2.z), maxZ = maxf(a.z, b2.z) })
		for l in info.lights:
			var w2: Vector3 = xf * Vector3(l.x, l.y, l.z)
			lights.append({ x = w2.x, y = w2.y, z = w2.z, kind = l.kind })
		if p.kit.ends_with("seongmun"):
			for an in info.anchors:
				anchors["gate_%s_%s" % [p.side, an]] = xf * (info.anchors[an] as Vector3)
	anchors.center = Vector3.ZERO
	return {
		node = root, colliders = colliders, lights = lights, occluder = true,
		footprint = Vector2(side + 30, side + 30), anchors = anchors, pieces = pieces,
	}
