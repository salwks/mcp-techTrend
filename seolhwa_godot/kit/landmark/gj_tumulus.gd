# 신라 왕릉·대형 고분 봉분(封墳, 대릉원 일대·노서리·노동리 고분군) — 적석목곽분 위에 흙을 덮은 둥근 봉분. 1870년에도 지금처럼
# 풀 덮인 둥근 둔덕이었고 둘레 호석·상석은 없거나 묻혀 있었다고 봄(가설). 표형분(瓢形墳, 쌍분: 황남대총처럼 둘이 이어진 조롱박 모양)은
# twin=true. 봉분 위·비탈에 작은 소나무·떨기나무가 몇 그루 자라던 모습(옛 사진 기억, 가설)은 trees로.
# 원점 = 바닥 중심. flatten:false로 지형에 바로 놓이므로 밑동을 0.5m(sink) 땅속으로 내려 비탈에서도 뜨지 않게 했다.
# 오를 수 없게 충돌 원(반지름 0.85·radius). params: seed, radius(20), height(8), twin(false), trees(0), sink(0.5)
extends RefCounted

const Co = preload("res://kit/landmark/_common.gd")

const GRASS_TOP := 0x98a660
const GRASS_MID := 0x84944f
const GRASS_RING := 0x63703e   # 밑동 둘레 조금 어두운 띠(그늘·습기)
const SOIL := 0x6c6448

# 봉분 높이 단면: s 0(가운데)..1(가장자리). 꼭대기는 둥글고 밑으로 갈수록 완만하게 퍼짐
static func profile(s: float) -> float:
	if s >= 1.0: return 0.0
	# 밑동이 절벽처럼 서지 않게 가장자리 기울기를 유한하게(지수 > 1) + 어깨를 조금 부풀림
	return pow(1.0 - s * s, 1.15) * (1.0 + 0.4 * s * s)

# 여러 원형 둔덕(centers: [Vector4(cx, cz, R, H)])의 합집합 높이(가장 높은 값). 바닥은 -sink
static func height_at(centers: Array, x: float, z: float, sink: float) -> float:
	var y := -sink
	for c in centers:
		var cc: Vector4 = c
		var s := Vector2(x - cc.x, z - cc.y).length() / cc.z
		if s < 1.0: y = maxf(y, (cc.w + sink) * profile(s) - sink)
	return y

# p0에서 dir 방향으로 둔덕 합집합 가장자리까지의 거리(p0은 모든 원 안에 있어야 함)
static func edge_dist(centers: Array, p0: Vector2, dir: Vector2) -> float:
	var best := 0.0
	for c in centers:
		var cc: Vector4 = c
		var m := p0 - Vector2(cc.x, cc.y)
		var bq := m.dot(dir); var cq := m.dot(m) - cc.z * cc.z
		var disc := bq * bq - cq
		if disc > 0.0: best = maxf(best, -bq + sqrt(disc))
	return best

# 매끈한 풀 둔덕 메시(극좌표 격자). seg 둘레 조각, rings 고리 수, rough 높이 들쭉날쭉(m)
static func dome_geo(rng: Kit.Rng, centers: Array, p0: Vector2, seg: int, rings: int, sink: float, rough := 0.18, cols := [GRASS_TOP, GRASS_MID, GRASS_RING, SOIL]) -> Kit.Geo:
	var g := Kit.Geo.new()
	var sd := rng.next() * 50.0
	var grid := []
	var hmax := 0.0
	for c in centers: hmax = maxf(hmax, (c as Vector4).w)
	for i in seg:
		var a := TAU * i / seg
		var dir := Vector2(cos(a), sin(a))
		var L := edge_dist(centers, p0, dir) * (1.0 + (Kit.vnoise(cos(a) * 2.0 + sd, sin(a) * 2.0) - 0.5) * 0.06)
		var row := []
		for k in rings + 1:
			# 가장자리 쪽 고리를 촘촘히(밑동 곡선이 매끈하게)
			var t := 1.0 - pow(1.0 - float(k) / rings, 1.35)
			var p := p0 + dir * L * t
			var y := height_at(centers, p.x, p.y, sink)
			if k == rings: y = -sink
			elif k > 0: y += (Kit.vnoise(p.x * 0.15 + sd, p.y * 0.15) - 0.5) * rough * 2.0 * minf(1.0, (y + sink) / 1.5)
			row.append(Vector3(p.x, y, p.y))
		grid.append(row)
	var top := Kit.hex(cols[0]); var mid := Kit.hex(cols[1]); var ring := Kit.hex(cols[2]); var soil := Kit.hex(cols[3])
	for i in seg:
		var j := (i + 1) % seg
		for k in rings:
			var a: Vector3 = grid[i][k]; var b: Vector3 = grid[j][k]; var c: Vector3 = grid[j][k + 1]; var d: Vector3 = grid[i][k + 1]
			var base := g.size()
			var n := ((a + b + c + d) / 4 - Vector3(p0.x, -sink - hmax, p0.y)).normalized()
			if k == 0:
				Co.Roof.tri_facing(g, a, c, d, n)
			else:
				Co.Roof.quad_facing(g, a, b, c, d, n)
			var jit := (rng.next() - 0.5) * 0.018
			for q in range(base, g.size()):
				var y := g.pos[q].y
				var hk := clampf((y + sink) / maxf(hmax + sink, 0.1), 0.0, 1.0)
				var cc: Color = mid.lerp(top, smoothstep(0.35, 1.0, hk))
				cc = ring.lerp(cc, smoothstep(0.03, 0.2, hk))
				if y < 0.05: cc = soil.lerp(ring, clampf((y + sink) / maxf(sink, 0.05), 0.0, 1.0))
				g.col[q] = Color(cc.r + jit, cc.g + jit, cc.b + jit * 0.8)
	return g

# 봉분 비탈의 작은 소나무(값싼 원뿔 + 줄기). (x, y, z) 밑동
static func pine(b, rng: Kit.Rng, x: float, y: float, z: float, h: float) -> void:
	b.add("bark", Co.pnt(Kit.limb(Vector3(x, y - 0.3, z), Vector3(x + rng.between(-0.3, 0.3), y + h * 0.55, z + rng.between(-0.3, 0.3)), 0.14, 0.08, 4), [0x7a5038, 0x5a3c2a]), 0.012)
	var c := Kit.lump(1.0, 0, rng, 0.25, 1.0)
	Kit.xf(c, x, y + h * 0.68, z, 0, rng.next() * TAU, 0, h * 0.34, h * 0.26, h * 0.34)
	b.add("needle", Co.pnt(c, [0x5f7a44, 0x3c5232], 0.06, rng), 0.025)

static func build(params: Dictionary) -> Dictionary:
	var rng := Kit.Rng.new(int(params.get("seed", 1)))
	var R: float = float(params.get("radius", 20.0))
	var H: float = float(params.get("height", 8.0))
	var twin: bool = bool(params.get("twin", false))
	var ntree: int = int(params.get("trees", 0))
	var sink: float = float(params.get("sink", 0.5))
	var b := Kit.Batch.new()
	var centers := []
	var off := 0.0
	if twin:
		# 표형분: 남·북 두 봉분을 x로 잇댐(황남대총은 남분이 조금 더 큼 → 왼쪽(-x)을 크게, 가설)
		off = R * 0.72
		centers.append(Vector4(-off, 0.0, R, H))
		centers.append(Vector4(off, 0.0, R * 0.93, H * 0.94))
	else:
		centers.append(Vector4(0.0, 0.0, R, H))
	var seg := 40 if twin else 28
	var rings := 8
	b.add("organic", dome_geo(rng, centers, Vector2.ZERO, seg, rings, sink, 0.12 + R * 0.006), 0.05)
	# 비탈의 작은 나무
	for i in ntree:
		var c: Vector4 = centers[i % centers.size()]
		var a := rng.next() * TAU
		var s := rng.between(0.55, 0.85)
		var x := c.x + cos(a) * c.z * s; var z := c.y + sin(a) * c.z * s
		pine(b, rng, x, height_at(centers, x, z, sink), z, rng.between(2.2, 3.6))
	var cols := []
	for c in centers:
		var cc: Vector4 = c
		cols.append({ type = "circle", x = cc.x, z = cc.y, r = cc.z * 0.85 })
	var foot := Vector2(2.0 * R + 2.0 * off, 2.0 * R)
	return {
		node = b.build("봉분"), colliders = cols, lights = [], occluder = H > 4.0, footprint = foot,
		anchors = { front = Vector3(0, 0, R + 2.0), top = Vector3(-off, H, 0) },
	}
