# 돌담(막돌 허튼층쌓기 + 갓돌) — 웹 buildings.js stoneWall() 이식. 두 점 (ax,az)→(bx,bz) 사이.
# params: seed, ax,az,bx,bz (없으면 len(4.5) 길이로 x축, 원점 중심), h(1.3)
# 삼각형: 약 230/m (막돌 하나하나가 덩이라서). 긴 담은 여러 토막으로 놓기.
extends RefCounted
const C := preload("res://kit/village/_common.gd")

static func build(params: Dictionary) -> Dictionary:
	var m := C.M.new(int(params.get("seed", 1)))
	var L: float = params.get("len", 4.5)
	var ax: float = params.get("ax", -L / 2); var az: float = params.get("az", 0.0)
	var bx: float = params.get("bx", L / 2); var bz: float = params.get("bz", 0.0)
	var h: float = params.get("h", 1.3)
	draw(m, ax, az, bx, bz, h)
	return m.result("돌담", Vector2(absf(bx - ax) + 0.6, absf(bz - az) + 0.6), true)

# 담 토막 하나 그리기 + 충돌체 등록
static func draw(m: C.M, ax: float, az: float, bx: float, bz: float, h := 1.3) -> float:
	var len := Vector2(bx - ax, bz - az).length()
	var R := m.rng
	var old := m.xform
	m.xform = old * C.seg_xform(ax, az, bx, bz)
	m.add("p", "stone", C.P(Kit.box(len, h, 0.55, 0, h / 2 - 0.05, 0), 0xa39a86, 0x857c6a, 0.05, R), 0.03)
	var n := maxi(2, roundi(len / 0.5))
	for row in 2:
		for i in n:
			var x := -len / 2 + (i + 0.5 + (row % 2) * 0.4) * (len / n) - 0.1
			if x > len / 2 - 0.15: continue
			var g := Kit.lump(0.22 + m.r() * 0.08, 0, R, 0.35, 0.7)
			var y := 0.3 + row * 0.5 * (h / 1.3) + (m.r() - 0.5) * 0.06
			Kit.xf(g, x, y, 0.26, 0, m.r() * 3, 0, 1.15, 1.2, 0.55)
			m.add("p", "stone", C.P(g, 0xbdb6a6, 0x8f887a, 0.08, R), 0.02)
	var nt := maxi(2, roundi(len / 0.7))
	for i in nt:
		var g := Kit.lump(0.38, 0, R, 0.3, 0.5)
		Kit.xf(g, -len / 2 + (i + 0.5) * (len / nt), h + 0.02, 0, 0, m.r() * 3, 0)
		m.add("p", "stone", C.P(g, 0xb3ac9c, 0x90897b, 0.08, R), 0.02)
	m.xform = old
	add_line_collider(m, ax, az, bx, bz, 0.3)
	return len

# 축에 맞으면 상자, 비스듬하면 원 줄
static func add_line_collider(m: C.M, ax: float, az: float, bx: float, bz: float, r: float) -> void:
	if absf(az - bz) < 0.01 or absf(ax - bx) < 0.01:
		m.box_c(minf(ax, bx) - r, maxf(ax, bx) + r, minf(az, bz) - r, maxf(az, bz) + r)
	else:
		var len := Vector2(bx - ax, bz - az).length()
		var n := maxi(2, ceili(len / (r * 1.6)) + 1)
		for i in n:
			var t := float(i) / (n - 1)
			m.circle(lerpf(ax, bx, t), lerpf(az, bz, t), r)
