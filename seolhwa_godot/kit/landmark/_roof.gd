# 곡선 기와지붕 공용 — 웹 src/world/buildings.js curvedRoof/ridgeCap 이식 + 팔작 합각·맞배 박공 추가.
# 쓰는 법: const Roof = preload("res://kit/landmark/_roof.gd")
#   var info := Roof.add(batch, {type="paljak", hw=8, hd=5, eave=4.2, rise=2.6, lift=0.6})
# type: "paljak"(팔작: 웹 기와집과 같은 곡면 + 합각 삼각벽) / "ujin"(우진각: 네 면 모두 처마) / "matbae"(맞배: 앞뒤 두 면, 박공)
extends RefCounted

const C_TOP := 0xd9d9d4
const C_LOW := 0xb9b8b2
const C_BOT := 0x3b2f26
const RIDGE := [0x3d3f42, 0x2d2e30]

static func smoothstep(a: float, b: float, x: float) -> float:
	var t := clampf((x - a) / (b - a), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)

# 앞면이 n 쪽을 보도록 감김을 맞춰 삼각형을 넣는다(반시계 = 앞면)
static func tri_facing(g, a: Vector3, b: Vector3, c: Vector3, n: Vector3, ua := Vector2(0.5, 0.5), ub := Vector2(0.5, 0.5), uc := Vector2(0.5, 0.5)) -> void:
	if (b - a).cross(c - a).dot(n) >= 0.0:
		g.tri(a, b, c, ua, ub, uc)
	else:
		g.tri(a, c, b, ua, uc, ub)

static func quad_facing(g, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3, ua := Vector2(0, 0), ub := Vector2(1, 0), uc := Vector2(1, 1), ud := Vector2(0, 1)) -> void:
	tri_facing(g, a, b, c, n, ua, ub, uc)
	tri_facing(g, a, c, d, n, ua, uc, ud)

# 지붕 면 높이 (웹 curvedRoof의 H와 같은 식, 맞배는 앞뒤 경사만)
static func height(o: Dictionary, x: float, z: float) -> float:
	var hw: float = o.hw; var hd: float = o.hd
	var lx := absf(x) / hw; var lz := absf(z) / hd
	var y: float = o.eave
	if o.get("type", "paljak") == "matbae":
		var s := clampf((hd - absf(z)) / hd, 0.0, 1.0)
		y += o.rise * (0.25 * s + 0.75 * s * s)
		y += o.lift * 0.6 * pow(lx, 4) * smoothstep(0.55, 1.0, lz)
		return y
	var k: float = o.k
	var ex := (hw - absf(x)) * k; var ez := hd - absf(z)
	var e := maxf(0.0, minf(ex, ez))
	var s2 := minf(1.0, e / hd)
	y += o.rise * (0.25 * s2 + 0.75 * s2 * s2)
	y += o.lift * maxf(pow(lx, 3) * smoothstep(0.5, 1.0, lz), pow(lz, 3) * smoothstep(0.5, 1.0, lx))
	return y

static func _side(o: Dictionary, x: float, z: float) -> bool:
	if o.get("type", "paljak") == "matbae": return false
	return (o.hw - absf(x)) * o.k < o.hd - absf(z)

# 지붕 곡면 Geo(기와 골 UV) + 처마 끝 막새 띠 Geo
static func surfaces(o: Dictionary) -> Dictionary:
	var hw: float = o.hw; var hd: float = o.hd
	var nx: int = o.get("nx", 28); var nz: int = o.get("nz", 16)
	var thick: float = o.get("thick", 0.24)
	var c_top := Kit.hex(C_TOP); var c_low := Kit.hex(C_LOW); var c_bot := Kit.hex(C_BOT)
	var g := Kit.Geo.new()
	var X := func(i: int) -> float: return -hw + 2.0 * hw * i / nx
	var Z := func(j: int) -> float: return -hd + 2.0 * hd * j / nz
	for j in nz:
		for i in nx:
			var x0: float = X.call(i); var x1: float = X.call(i + 1); var z0: float = Z.call(j); var z1: float = Z.call(j + 1)
			var side := _side(o, (x0 + x1) / 2, (z0 + z1) / 2)
			var pts := []
			for p in [[x0, z0], [x1, z0], [x0, z1], [x1, z1]]:
				var x: float = p[0]; var z: float = p[1]
				var y := height(o, x, z)
				var uv := Vector2((z - z0) / (z1 - z0), (x - x0) / (x1 - x0)) if side else Vector2((x - x0) / (x1 - x0), (z - z0) / (z1 - z0))
				pts.append([Vector3(x, y, z), uv])
			var a = pts[0]; var b = pts[1]; var c = pts[2]; var d = pts[3]
			var base := g.size()
			g.tri(a[0], c[0], b[0], a[1], c[1], b[1])
			g.tri(b[0], c[0], d[0], b[1], c[1], d[1])
			for q in range(base, g.size()):
				g.col[q] = c_low.lerp(c_top, clampf((g.pos[q].y - o.eave) / o.rise, 0.0, 1.0))
			base = g.size()
			var dn := Vector3(0, -thick, 0)
			g.tri(a[0] + dn, b[0] + dn, c[0] + dn); g.tri(b[0] + dn, d[0] + dn, c[0] + dn)
			for q in range(base, g.size()): g.col[q] = c_bot
	# 처마 끝 막새 띠(바깥을 보게)
	var e := Kit.Geo.new()
	var segs := []
	for i in nx:
		segs.append([X.call(i), -hd, X.call(i + 1), -hd, Vector3(0, 0, -1)])
		segs.append([X.call(i), hd, X.call(i + 1), hd, Vector3(0, 0, 1)])
	if o.get("type", "paljak") != "matbae":
		for j in nz:
			segs.append([-hw, Z.call(j), -hw, Z.call(j + 1), Vector3(-1, 0, 0)])
			segs.append([hw, Z.call(j), hw, Z.call(j + 1), Vector3(1, 0, 0)])
	for s in segs:
		var pa := Vector3(s[0], height(o, s[0], s[1]), s[1]); var pb := Vector3(s[2], height(o, s[2], s[3]), s[3])
		var dn := Vector3(0, -thick, 0)
		quad_facing(e, pa + dn, pb + dn, pb, pa, s[4], Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1))
	var k: float = o.get("k", 1.9)
	var ridge_half := hw if o.get("type", "paljak") == "matbae" else maxf(0.0, hw - hd / k)
	return { roof = g, edge = e, ridge_y = o.eave + o.rise, ridge_half = ridge_half }

# 용마루 + 치켜든 끝(웹 ridgeCap)
static func ridge_cap(b, half: float, y: float, w := 0.36, out := 0.03) -> void:
	b.add("flat", Kit.paint(Kit.box(half * 2, 0.3, w, 0, y + 0.08, 0), Kit.hex(RIDGE[0]), Kit.hex(RIDGE[1]), 0.02), out)
	for s in [-1, 1]:
		b.add("flat", Kit.paint(Kit.xf(Kit.box(0.5, 0.26, w * 0.9), s * (half + 0.12), y + 0.22, 0, 0, 0, s * 0.55), Kit.hex(RIDGE[0]), Kit.hex(RIDGE[1]), 0.02), out)

# 지붕 하나를 batch에 넣는다. o: type, hw, hd, eave, rise, lift, k, thick, nx, nz, outline,
#   (맞배) gable_x(벽선 x), gable_d(벽 깊이 반), gable_y(박공 아래 높이)
# 반환 { ridge_y, ridge_half }
static func add(b, o: Dictionary, x := 0.0, z := 0.0, ry := 0.0) -> Dictionary:
	var t: String = o.get("type", "paljak")
	if not o.has("k"): o.k = 1.0 if t == "ujin" else 1.9
	if not o.has("lift"): o.lift = 0.6
	if not o.has("rise"): o.rise = 0.55 * o.hd
	var s := surfaces(o)
	var outline: float = o.get("outline", 0.05)
	var parts := []   # [key, geo, outline]
	parts.append(["tile", s.roof, outline])
	parts.append(["makse", s.edge, 0.0])
	var ry_: float = s.ridge_y
	var rh: float = s.ridge_half
	if t == "paljak" and rh > 0.3:
		# 합각: 용마루 끝 조금 바깥의 세모 벽(앞 경사 단면을 따라)
		var a := minf(1.4, o.hd / o.k * 0.5)
		var gx := rh + a
		for sx in [-1, 1]:
			var g := Kit.Geo.new()
			var n := 6
			var zb: float = o.hd * 0.55
			for i in n:
				var za := -zb + 2.0 * zb * i / n; var zc := -zb + 2.0 * zb * (i + 1) / n
				var ya := height(o, rh, za) - 0.05; var yc := height(o, rh, zc) - 0.05
				var y0 := height(o, rh, zb) - 0.4
				quad_facing(g, Vector3(sx * gx, y0, za), Vector3(sx * gx, y0, zc), Vector3(sx * gx, yc, zc), Vector3(sx * gx, ya, za), Vector3(sx, 0, 0))
			parts.append(["wood", Kit.paint(g, Kit.hex(0x7a5c40), Kit.hex(0x5e4632), 0.02), 0.02])
			# 합각 아래 처마 끝 띠(박공 머리)
			parts.append(["flat", Kit.paint(Kit.box(0.08, 0.12, zb * 2.0, sx * (gx + 0.04), height(o, rh, zb) - 0.35, 0), Kit.hex(0x557d70)), 0.0])
		rh = gx
	if t == "matbae" and o.has("gable_x"):
		# 박공벽: 벽선에서 지붕 밑면까지
		var gxw: float = o.gable_x; var gd: float = o.gable_d; var gy: float = o.gable_y
		for sx in [-1, 1]:
			var g := Kit.Geo.new()
			var n := 8
			var th: float = o.get("thick", 0.24)
			for i in n:
				var za := -gd + 2.0 * gd * i / n; var zc := -gd + 2.0 * gd * (i + 1) / n
				var ya := height(o, gxw, za) - th; var yc := height(o, gxw, zc) - th
				quad_facing(g, Vector3(sx * gxw, gy, za), Vector3(sx * gxw, gy, zc), Vector3(sx * gxw, yc, zc), Vector3(sx * gxw, ya, za), Vector3(sx, 0, 0))
			parts.append(["mud", Kit.paint(g, Kit.hex(0xe2d8c0), Kit.hex(0xcfc1a0), 0.02), 0.02])
			# 박공널(지붕 끝 따라 ㅅ자 판)
			for side in [-1, 1]:
				var zz0 := 0.0; var zz1: float = side * o.hd
				var p0 := Vector3(sx * (o.hw + 0.02), height(o, o.hw, zz0) - 0.1, zz0)
				var p1 := Vector3(sx * (o.hw + 0.02), height(o, o.hw, zz1) - 0.1, zz1)
				var gb := Kit.limb(p0, p1, 0.06, 0.06, 4)
				parts.append(["wood", Kit.paint(gb, Kit.hex(0x5a4532)), 0.015])
	var xfm := Transform3D(Basis(Vector3.UP, ry), Vector3(x, 0, z))
	for p in parts:
		b.add(p[0], Kit.apply(p[1], xfm), p[2])
	# 용마루
	var w: float = o.get("ridge_w", 0.36)
	var gr := Kit.paint(Kit.box(rh * 2, 0.3, w, 0, ry_ + 0.08, 0), Kit.hex(RIDGE[0]), Kit.hex(RIDGE[1]), 0.02)
	b.add("flat", Kit.apply(gr, xfm), 0.03)
	for sx in [-1, 1]:
		var ge := Kit.paint(Kit.xf(Kit.box(0.55, 0.28, w * 0.9), sx * (rh + 0.12), ry_ + 0.24, 0, 0, 0, sx * 0.55), Kit.hex(RIDGE[0]), Kit.hex(RIDGE[1]), 0.02)
		b.add("flat", Kit.apply(ge, xfm), 0.03)
	if t != "matbae":
		# 추녀마루: 지붕 면의 귀 선(평면상 직선)을 따라 용마루 끝에서 네 귀로
		var r0: float = s.ridge_half
		var ns := 5
		for sx in [-1, 1]:
			for sz in [-1, 1]:
				var prev := Vector3.ZERO
				for i in ns + 1:
					var tt := 0.94 * i / ns
					var hx: float = r0 + (o.hw - r0) * tt; var hz: float = o.hd * tt
					var p := Vector3(sx * hx, height(o, hx, hz) + 0.1, sz * hz)
					if i == 0: p.y = ry_ + 0.08
					if i > 0:
						var gl := Kit.paint(Kit.limb(prev, p, 0.14, 0.12, 4), Kit.hex(RIDGE[0]), Kit.hex(RIDGE[1]), 0.02)
						b.add("flat", Kit.apply(gl, xfm), 0.0)
					prev = p
	return { ridge_y = ry_, ridge_half = rh }
