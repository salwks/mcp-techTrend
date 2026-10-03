# 분황사 모전석탑(芬皇寺 模塼石塔, 신라 선덕여왕 3년 634) — 안산암을 벽돌처럼 잘라 쌓은 탑. 지금 3층(높이 약 9.3m)만 남음.
# 1870년 상태(가설): 1915년 일제 수리 전이라 위층이 더 무너져 있었고, 꼭대기는 무너진 돌 더미에 풀이 났다고 봄.
# 낮은 막돌 단(한 변 약 13m) 네 귀에 돌사자 넷, 1층 네 면 가운데 감실 문(돌 문틀), 남문 양옆 인왕상 둘(실제로는 네 문 모두 둘씩 —
# 여기서는 남문만, 요청대로). 층마다 처마는 벽돌탑처럼 층급(내쌓기)으로 내밀고 위는 계단식으로 들임.
# 치수는 사진 비례 근사(가설). params: seed
extends RefCounted

const Co = preload("res://kit/landmark/_common.gd")

const BRICK := [0x6e6a64, 0x56534e]     # 짙은 회색 안산암 '벽돌'
const BRICK_D := [0x5c5954, 0x494642]
const GRANITE := [0xb8b0a0, 0x8e8778]   # 문틀·인왕상·사자(화강암)
const PLAT := [0x9c9484, 0x77705f]      # 단(막돌)

# 벽돌 켜(높이 hh)를 0.3m 남짓한 띠로 쌓은 네모 몸체: 띠마다 색을 번갈아 줄눈처럼 보이게
static func courses(list_a: Array, list_b: Array, w: float, y0: float, hh: float, course := 0.32) -> void:
	var n := maxi(1, roundi(hh / course))
	var ch := hh / n
	for k in n:
		var bx := Kit.box(w - (0.02 if k % 2 == 1 else 0.0), ch - 0.015, w - (0.02 if k % 2 == 1 else 0.0), 0, y0 + ch * (k + 0.5), 0)
		(list_a if k % 2 == 0 else list_b).append(bx)

# 층급(내쌓기): w0에서 한 켜마다 dw씩 넓어지거나(+) 좁아지며(−) n켜. 반환 위 y
static func steps(list_a: Array, list_b: Array, w0: float, y0: float, n: int, dw: float, ch := 0.16) -> float:
	var y := y0
	for k in n:
		var w := w0 + dw * (k + 1)
		(list_a if k % 2 == 0 else list_b).append(Kit.box(w, ch, w, 0, y + ch / 2, 0))
		y += ch
	return y

# 돌사자(웅크려 앉음, 단순 덩이)
static func lion(b, rng: Kit.Rng, x: float, y: float, z: float, ry: float) -> void:
	var g := []
	g.append(Kit.box(0.7, 0.25, 1.1, 0, 0.125, 0))                      # 받침
	var body := Kit.lump(1.0, 0, rng, 0.12, 1.0); Kit.xf(body, 0, 0.6, -0.1, 0, 0, 0, 0.32, 0.38, 0.48); g.append(body)
	var head := Kit.lump(1.0, 0, rng, 0.1, 1.0); Kit.xf(head, 0, 1.0, 0.25, 0, 0, 0, 0.27, 0.27, 0.25); g.append(head)
	g.append(Kit.box(0.14, 0.4, 0.14, -0.15, 0.45, 0.3)); g.append(Kit.box(0.14, 0.4, 0.14, 0.15, 0.45, 0.3))  # 앞발
	var gg := Kit.merge(g)
	Kit.xf(gg, x, y, z, 0, ry)
	b.add("stone", Co.pnt(gg, GRANITE, 0.05, rng), 0.02)

# 인왕상(금강역사, 문 옆 돋을새김 판돌을 덩이로 단순화): 판돌 + 몸 + 머리 + 쳐든 팔
static func inwang(b, rng: Kit.Rng, x: float, y: float, z: float, side: float) -> void:
	var g := []
	g.append(Kit.box(0.85, 2.0, 0.22, x, y + 1.0, z - 0.05))                   # 판돌
	g.append(Kit.box(0.48, 0.95, 0.24, x, y + 0.85, z + 0.12))                 # 몸통(치마)
	g.append(Kit.box(0.42, 0.5, 0.22, x, y + 1.5, z + 0.14))                   # 가슴
	var hd := Kit.lump(1.0, 0, rng, 0.08, 1.0); Kit.xf(hd, x, y + 1.9, z + 0.16, 0, 0, 0, 0.15, 0.19, 0.14); g.append(hd)
	g.append(Kit.xf(Kit.box(0.13, 0.55, 0.14), x + side * 0.3, y + 1.75, z + 0.16, 0, 0, side * 0.5))  # 쳐든 팔(바깥쪽)
	g.append(Kit.xf(Kit.box(0.13, 0.5, 0.14), x - side * 0.27, y + 1.25, z + 0.18, 0, 0, -side * 0.2))
	b.add("stone", Co.pnt(Kit.merge(g), GRANITE, 0.05, rng), 0.018)

static func build(params: Dictionary) -> Dictionary:
	var rng := Kit.Rng.new(int(params.get("seed", 1)))
	var b := Kit.Batch.new()
	# 단: 막돌 쌓은 낮은 네모 단(한 변 13m, 높이 0.9m) + 위에 판석
	var P := 13.0; var ph := 0.9
	b.add("stone", Co.pnt(Kit.box(P, ph + 0.4, P, 0, (ph - 0.4) / 2, 0), PLAT, 0.05, rng), 0.03)
	# 단 옆면 막돌 줄(먹선 없이)
	var fs := []
	for side in 4:
		var ang := PI / 2 * side
		var n := 11
		for row in 2:
			for i in n:
				var x := -P / 2 + (i + 0.5 + (0.35 if row == 1 else 0.0)) * P / n
				if absf(x) > P / 2 - 0.4: continue
				var q := Co.vplane(P / n - 0.1, 0.36, x, 0.22 + row * 0.42, P / 2 + 0.015)
				Kit.xf(q, 0, 0, 0, 0, ang)
				fs.append(q)
	b.add("stone", Co.pnt(Kit.merge(fs), [0xaaa292, 0x8a8372], 0.07, rng), 0.0)
	b.add("stone", Co.pnt(Kit.box(P - 0.6, 0.06, P - 0.6, 0, ph + 0.02, 0), [0xa69e8e, 0x968e7e], 0.04, rng), 0.0)
	# 남쪽 돌계단(단 가운데)
	var st := []
	for k in 3:
		st.append(Kit.box(2.4, ph * (k + 1) / 3.0, 0.4, 0, ph * (k + 1) / 6.0, P / 2 + 0.2 + (2 - k) * 0.4))
	b.add("stone", Co.pnt(Kit.merge(st), PLAT, 0.05, rng), 0.015)
	# 탑: 1층(넓고 높음) + 처마 / 2층 / 3층 (높이 합 약 9.3m를 노림)
	var A := []; var Bc := []
	var y := ph
	# 탑 기단(낮은 화강암 띠 — 지금 기단은 1915 수리 때 정비, 가설)
	b.add("stone", Co.pnt(Kit.box(7.6, 0.35, 7.6, 0, y + 0.175, 0), GRANITE, 0.05, rng), 0.025)
	y += 0.35
	var stories := [[6.6, 2.9, 6, 7], [5.6, 1.25, 4, 6], [4.8, 1.0, 4, 7]]   # [몸 너비, 몸 높이, 아래 내쌓기 켜, 위 들임 켜]
	var door_y := y
	var w1: float = stories[0][0]
	for i in stories.size():
		var w: float = stories[i][0]; var hh: float = stories[i][1]
		courses(A, Bc, w, y, hh)
		y += hh
		# 처마 아래 내쌓기(바깥으로 켜마다 0.14m) → 위 들임(켜마다 0.2m 들어감)
		var n0: int = stories[i][2]; var n1: int = stories[i][3]
		y = steps(A, Bc, w, y, n0, 0.14, 0.13)
		var ew := w + 0.14 * n0
		y = steps(A, Bc, ew, y, n1, -0.24 if i < 2 else -0.3, 0.13)
	b.add("stone", Co.pnt(Kit.merge(A), BRICK, 0.07, rng), 0.025)
	b.add("stone", Co.pnt(Kit.merge(Bc), BRICK_D, 0.07, rng), 0.0)
	# 꼭대기: 무너진 돌 더미 + 풀(1870 가설)
	var topw := 4.8 + 0.14 * 4 - 0.3 * 7
	for k in 5:
		var rr := Kit.lump(rng.between(0.35, 0.6), 0, rng, 0.3, 0.6)
		Kit.xf(rr, rng.between(-topw * 0.35, topw * 0.35), y + 0.15, rng.between(-topw * 0.35, topw * 0.35))
		b.add("rock", Co.pnt(rr, BRICK, 0.08, rng), 0.02)
	var tuft := Kit.lump(1.0, 0, rng, 0.3, 1.0); Kit.xf(tuft, 0.3, y + 0.25, -0.2, 0, 0, 0, topw * 0.35, 0.35, topw * 0.3)
	b.add("leaf", Co.pnt(tuft, [0x7f9150, 0x5e6e3c], 0.06, rng), 0.02)
	var top_y := y + 0.5
	# 1층 네 면 감실 문: 화강암 문틀(문설주 + 인방 + 문지방) + 어두운 감실
	var dw := 1.0; var dh := 1.5
	var hw1 := w1 / 2
	var frames := []; var holes := []
	for side in 4:
		var ang := PI / 2 * side
		var parts := []
		parts.append(Kit.box(0.28, dh + 0.3, 0.3, -dw / 2 - 0.14, door_y + (dh + 0.3) / 2, hw1 + 0.05))
		parts.append(Kit.box(0.28, dh + 0.3, 0.3, dw / 2 + 0.14, door_y + (dh + 0.3) / 2, hw1 + 0.05))
		parts.append(Kit.box(dw + 0.9, 0.3, 0.32, 0, door_y + dh + 0.3 + 0.15, hw1 + 0.06))
		parts.append(Kit.box(dw + 0.56, 0.18, 0.4, 0, door_y + 0.09, hw1 + 0.1))
		var g := Kit.merge(parts); Kit.xf(g, 0, 0, 0, 0, ang); frames.append(g)
		var h := Co.vplane(dw, dh + 0.12, 0, door_y + 0.18 + (dh + 0.12) / 2, hw1 + 0.02); Kit.xf(h, 0, 0, 0, 0, ang); holes.append(h)
	b.add("stone", Co.pnt(Kit.merge(frames), GRANITE, 0.04, rng), 0.018)
	b.add("flat", Co.pnt(Kit.merge(holes), [0x221e1b, 0x14110f]), 0.0)
	# 남문 양옆 인왕상
	for s in [-1.0, 1.0]:
		inwang(b, rng, s * (dw / 2 + 0.95), door_y, hw1 + 0.2, s)
	# 단 네 귀 돌사자(바깥 대각선을 봄)
	var lc := P / 2 - 0.9
	lion(b, rng, lc, ph, lc, PI / 4)
	lion(b, rng, -lc, ph, lc, -PI / 4)
	lion(b, rng, lc, ph, -lc, 3 * PI / 4)
	lion(b, rng, -lc, ph, -lc, -3 * PI / 4)
	var hb := 7.6 / 2 + 0.3
	return {
		node = b.build("분황사모전석탑"),
		colliders = [{ type = "box", minX = -hb, maxX = hb, minZ = -hb, maxZ = hb },
			{ type = "circle", x = lc, z = lc, r = 0.6 }, { type = "circle", x = -lc, z = lc, r = 0.6 },
			{ type = "circle", x = lc, z = -lc, r = 0.6 }, { type = "circle", x = -lc, z = -lc, r = 0.6 }],
		lights = [], occluder = true, footprint = Vector2(14.0, 14.0),
		anchors = { front = Vector3(0, ph, hw1 + 1.6), stair_foot = Vector3(0, 0, P / 2 + 1.8), south_door = Vector3(0, door_y, hw1 + 0.3) },
		height = top_y,
	}
