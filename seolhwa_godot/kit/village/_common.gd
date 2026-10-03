# kit-village 공용 도구 — 웹 buildings.js의 도우미(곡선 기와지붕, 구멍 벽, 창호)와
# three.js 기본 도형 중 Kit에 없는 것(Sphere, Lathe, Torus, 세운 Plane, Extrude)을 옮김.
# 쓰는 법:  const C := preload("res://kit/village/_common.gd")
#   var m := C.M.new(seed)               # 여러 부분(part)을 가진 모델 조립기
#   m.add("body", "mud", C.P(Kit.box(...), C.MUD))   # 웹 add(part, key, geo, outline)와 같다
#   m.xform = Transform3D(...)           # 이후 add·충돌체·조명에 적용(집 묶음 등 조합용)
#   return m.result("이름")
extends RefCounted

# 웹 buildings.js 색 (sRGB 16진)
const WOOD := [0x6b5038, 0x4d3826]
const WOOD_L := [0x9a7852, 0x7a5c3e]
const MUD := [0xd2b98c, 0xa88c62]
const STONE := [0xa19b8f, 0x77726a]
const PLASTER := [0xece4cf, 0xd8ccb0]
const DANCHEONG_R := [0x8a3e2e, 0x6a2e22]
const DOOR := [0x5a4432, 0x3f2f22]
const ROOF_DARK := 0x3d3f42
const THATCH := [0xe0cc98, 0xa18a5e]
const THATCH_LIP := [0xa69064, 0x7d6a48]
const STRAW := [0xdcc78e, 0x9d8656]
const ONGGI := [0x6e4a33, 0x3e281c]
const CLOTH_W := 0xe8e2d2

static var _fr := Kit.Rng.new(4242)

# 웹 paint(g, top, bottom, jitter, rnd) — 색은 0xRRGGBB 정수 또는 [top, bottom] 배열
static func P(g: Kit.Geo, top, bot = -1, jit := 0.05, rng: Kit.Rng = null) -> Kit.Geo:
	var t: int; var b: int
	if top is Array:
		t = top[0]; b = top[1]
		if bot is float: jit = bot
		elif bot is Kit.Rng: rng = bot
	else:
		t = top; b = top if (bot == null or int(bot) < 0) else int(bot)
	return Kit.paint(g, Kit.hex(t), Kit.hex(b), jit, rng if rng else _fr)

# 배열 색 + jitter + rng 순서로 쓰는 짧은 형태
static func PA(g: Kit.Geo, cols: Array, jit := 0.05, rng: Kit.Rng = null) -> Kit.Geo:
	return Kit.paint(g, Kit.hex(cols[0]), Kit.hex(cols[1]), jit, rng if rng else _fr)

# ---------------------------------------------------------------------------
# 모델 조립기: part별 Batch, 변환, 충돌체·조명·앵커 모음
# ---------------------------------------------------------------------------
class M:
	var parts := {}            # part 이름 → Kit.Batch
	var order := []
	var rng: Kit.Rng
	var xform := Transform3D.IDENTITY
	var colliders := []
	var lights := []
	var anchors := {}
	var merge_parts := true    # true면 모든 part를 'all' 하나로(내부가 없는 모델)
	var prefix := ""           # 앵커 이름 앞에 붙임(집 묶음에서 건물별 구분)

	func _init(seed := 1, merged := true) -> void:
		rng = Kit.Rng.new(seed)
		merge_parts = merged

	func r() -> float: return rng.next()
	func between(a: float, b: float) -> float: return rng.between(a, b)

	func add(part: String, key: String, g: Kit.Geo, outline := 0.03) -> void:
		if g.size() == 0: return
		if xform != Transform3D.IDENTITY: Kit.apply(g, xform)
		var p := "all" if merge_parts else part
		if not parts.has(p):
			parts[p] = Kit.Batch.new(); order.append(p)
		parts[p].add(key, g, outline)

	# 부분 조립을 (x,y,z, ry)에 놓기: old := m.push(...); 그리기; m.pop(old)
	func push(x: float, y: float, z: float, ry := 0.0) -> Transform3D:
		var old := xform
		xform = old * Transform3D(Basis(Vector3.UP, ry), Vector3(x, y, z))
		return old

	func pop(old: Transform3D) -> void:
		xform = old

	# --- 충돌체·조명·앵커(현재 xform 적용) ---
	func box_c(minX: float, maxX: float, minZ: float, maxZ: float) -> void:
		var a := xform * Vector3(minX, 0, minZ); var b := xform * Vector3(maxX, 0, maxZ)
		var c := xform * Vector3(minX, 0, maxZ); var d := xform * Vector3(maxX, 0, minZ)
		colliders.append({ type = "box", minX = minf(minf(a.x, b.x), minf(c.x, d.x)), maxX = maxf(maxf(a.x, b.x), maxf(c.x, d.x)),
			minZ = minf(minf(a.z, b.z), minf(c.z, d.z)), maxZ = maxf(maxf(a.z, b.z), maxf(c.z, d.z)) })

	func circle(x: float, z: float, rr: float) -> void:
		var p := xform * Vector3(x, 0, z)
		colliders.append({ type = "circle", x = p.x, z = p.z, r = rr })

	func light(x: float, y: float, z: float, kind: String) -> void:
		var p := xform * Vector3(x, y, z)
		lights.append({ x = p.x, y = p.y, z = p.z, kind = kind })

	func anchor(name: String, v: Vector3) -> void:
		anchors[prefix + name] = xform * v

	func tris() -> int:
		var n := 0
		for p in parts: n += parts[p].tris
		return n

	# part별 자식 노드를 가진 Node3D
	func build_node(name: String) -> Node3D:
		var root := Node3D.new()
		root.name = name
		for p in order:
			var b: Kit.Batch = parts[p]
			if b.is_empty(): continue
			var n := b.build(p, p != "interior")
			if merge_parts:
				# 자식 MeshInstance3D만 옮겨 단계 하나 줄임
				var mi: Node = n.get_child(0)
				n.remove_child(mi); mi.name = "mesh"; root.add_child(mi); n.free()
			else:
				root.add_child(n)
		return root

	func result(name: String, footprint: Vector2, occluder := true) -> Dictionary:
		var node := build_node(name)
		return { node = node, colliders = colliders, lights = lights, occluder = occluder, footprint = footprint, anchors = anchors }

	func part_node(node: Node3D, p: String) -> Node3D:
		return node.get_node_or_null(p)

# ---------------------------------------------------------------------------
# three.js 도형 이식
# ---------------------------------------------------------------------------
# SphereGeometry(r, ws, hs, phiStart, phiLength, thetaStart, thetaLength)
static func sphere(r: float, ws := 8, hs := 6, phi_s := 0.0, phi_l := TAU, th_s := 0.0, th_l := PI) -> Kit.Geo:
	var g := Kit.Geo.new()
	var th_e := minf(th_s + th_l, PI)
	var grid := []; var uvs := []
	for iy in hs + 1:
		var v := float(iy) / hs
		var uoff := 0.0
		if iy == 0 and th_s == 0.0: uoff = 0.5 / ws
		elif iy == hs and th_e == PI: uoff = -0.5 / ws
		var row := []; var urow := []
		for ix in ws + 1:
			var u := float(ix) / ws
			var ph := phi_s + u * phi_l; var th := th_s + v * th_l
			row.append(Vector3(-r * cos(ph) * sin(th), r * cos(th), r * sin(ph) * sin(th)))
			urow.append(Vector2(u + uoff, 1.0 - v))
		grid.append(row); uvs.append(urow)
	for iy in hs:
		for ix in ws:
			var a: Vector3 = grid[iy][ix + 1]; var b: Vector3 = grid[iy][ix]; var c: Vector3 = grid[iy + 1][ix]; var d: Vector3 = grid[iy + 1][ix + 1]
			var ua: Vector2 = uvs[iy][ix + 1]; var ub: Vector2 = uvs[iy][ix]; var uc: Vector2 = uvs[iy + 1][ix]; var ud: Vector2 = uvs[iy + 1][ix + 1]
			if iy != 0 or th_s > 0.0: g.tri(a, b, d, ua, ub, ud)
			if iy != hs - 1 or th_e < PI: g.tri(b, c, d, ub, uc, ud)
	return g

# LatheGeometry(points[(x,y)], segments)
static func lathe(pts: Array, seg := 12) -> Kit.Geo:
	var g := Kit.Geo.new()
	var n := pts.size()
	for i in seg:
		var p0 := TAU * i / seg; var p1 := TAU * (i + 1) / seg
		for j in n - 1:
			var A: Vector2 = pts[j]; var B: Vector2 = pts[j + 1]
			var a := Vector3(A.x * sin(p0), A.y, A.x * cos(p0)); var b := Vector3(A.x * sin(p1), A.y, A.x * cos(p1))
			var c := Vector3(B.x * sin(p1), B.y, B.x * cos(p1)); var d := Vector3(B.x * sin(p0), B.y, B.x * cos(p0))
			var u0 := float(i) / seg; var u1 := float(i + 1) / seg
			var v0 := float(j) / (n - 1); var v1 := float(j + 1) / (n - 1)
			g.tri(a, b, d, Vector2(u0, v0), Vector2(u1, v0), Vector2(u0, v1))
			g.tri(c, d, b, Vector2(u1, v1), Vector2(u0, v1), Vector2(u1, v0))
	# 퇴화 삼각형 제거(축 위 점)
	return _clean(g)

static func _clean(g: Kit.Geo) -> Kit.Geo:
	var o := Kit.Geo.new()
	for i in range(0, g.pos.size(), 3):
		if (g.pos[i + 1] - g.pos[i]).cross(g.pos[i + 2] - g.pos[i]).length_squared() < 1e-12: continue
		for k in 3:
			o.pos.append(g.pos[i + k]); o.uv.append(g.uv[i + k]); o.col.append(g.col[i + k])
	return o

# TorusGeometry(R, tube, radialSeg, tubularSeg) — xy 평면에 놓인 고리(눕히려면 rx=PI/2)
static func torus(R: float, tube: float, rs := 4, ts := 16) -> Kit.Geo:
	var g := Kit.Geo.new()
	var V := []; var U := []
	for j in rs + 1:
		for i in ts + 1:
			var u := float(i) / ts * TAU; var v := float(j) / rs * TAU
			V.append(Vector3((R + tube * cos(v)) * cos(u), (R + tube * cos(v)) * sin(u), tube * sin(v)))
			U.append(Vector2(float(i) / ts, float(j) / rs))
	for j in range(1, rs + 1):
		for i in range(1, ts + 1):
			var a := (ts + 1) * j + i - 1; var b := (ts + 1) * (j - 1) + i - 1; var c := (ts + 1) * (j - 1) + i; var d := (ts + 1) * j + i
			g.tri(V[a], V[b], V[d], U[a], U[b], U[d])
			g.tri(V[b], V[c], V[d], U[b], U[c], U[d])
	return g

# PlaneGeometry(w, h): xy 평면, +z를 봄
static func vplane(w: float, h: float, x := 0.0, y := 0.0, z := 0.0, ry := 0.0) -> Kit.Geo:
	var g := Kit.Geo.new()
	var hw := w / 2; var hh := h / 2
	g.quad(Vector3(-hw, -hh, 0), Vector3(hw, -hh, 0), Vector3(hw, hh, 0), Vector3(-hw, hh, 0))
	return Kit.xf(g, x, y, z, 0, ry)

# ExtrudeGeometry: xy 평면 다각형을 z 0..depth로 밀어냄(앞면 z=depth)
static func extrude_xy(poly: PackedVector2Array, depth: float) -> Kit.Geo:
	var g := Kit.Geo.new()
	var area := 0.0
	var n := poly.size()
	for i in n: area += poly[i].x * poly[(i + 1) % n].y - poly[(i + 1) % n].x * poly[i].y
	if area < 0.0: poly.reverse()
	var per := 0.0
	for i in n: per += poly[i].distance_to(poly[(i + 1) % n])
	var acc := 0.0
	for i in n:
		var p0 := poly[i]; var p1 := poly[(i + 1) % n]
		var u0 := acc / per; acc += p0.distance_to(p1); var u1 := acc / per
		g.quad(Vector3(p0.x, p0.y, 0), Vector3(p1.x, p1.y, 0), Vector3(p1.x, p1.y, depth), Vector3(p0.x, p0.y, depth),
			Vector2(u0, 0), Vector2(u1, 0), Vector2(u1, 1), Vector2(u0, 1))
	var idx := Geometry2D.triangulate_polygon(poly)
	var mn := poly[0]; var mx := poly[0]
	for p in poly: mn = mn.min(p); mx = mx.max(p)
	var sz := (mx - mn).max(Vector2(1e-4, 1e-4))
	for i in range(0, idx.size(), 3):
		var a := poly[idx[i]]; var b := poly[idx[i + 1]]; var c := poly[idx[i + 2]]
		if (b - a).cross(c - a) < 0.0:
			var t := b; b = c; c = t
		var ua := (a - mn) / sz; var ub := (b - mn) / sz; var uc := (c - mn) / sz
		g.tri(Vector3(a.x, a.y, depth), Vector3(b.x, b.y, depth), Vector3(c.x, c.y, depth), ua, ub, uc)
		g.tri(Vector3(a.x, a.y, 0), Vector3(c.x, c.y, 0), Vector3(b.x, b.y, 0), ua, uc, ub)
	return g

# 두 점 사이 직육면체(각재) — 지게·서까래 등
static func beam(a: Vector3, b: Vector3, w: float, h: float) -> Kit.Geo:
	var d := b - a
	var len := d.length()
	var g := Kit.box(w, h, len, 0, 0, len / 2)
	var basis := Basis.looking_at(-d.normalized(), Vector3.UP if absf(d.normalized().y) < 0.99 else Vector3.FORWARD)
	return Kit.apply(g, Transform3D(basis, a))

# ---------------------------------------------------------------------------
# 웹 buildings.js 도우미
# ---------------------------------------------------------------------------
# 곡선 기와지붕 → { roof, edge, ridge_y, ridge_half }
static func curved_roof(hw: float, hd: float, eave_y: float, rise: float, lift: float, k := 1.8, thick := 0.22, nx := 36, nz := 20) -> Dictionary:
	var H := func(x: float, z: float) -> float:
		var ex := (hw - absf(x)) * k; var ez := hd - absf(z)
		var e := maxf(0.0, minf(ex, ez))
		var s := minf(1.0, e / hd)
		var y := eave_y + rise * (0.25 * s + 0.75 * s * s)
		var lx := absf(x) / hw; var lz := absf(z) / hd
		y += lift * maxf(pow(lx, 3) * smoothstep(0.5, 1.0, lz), pow(lz, 3) * smoothstep(0.5, 1.0, lx))
		return y
	var c_top := Kit.hex(0xd9d9d4); var c_low := Kit.hex(0xb9b8b2); var c_bot := Kit.hex(0x3b2f26)
	var g := Kit.Geo.new()
	var X := func(i: int) -> float: return -hw + 2.0 * hw * i / nx
	var Z := func(j: int) -> float: return -hd + 2.0 * hd * j / nz
	for j in nz:
		for i in nx:
			var x0: float = X.call(i); var x1: float = X.call(i + 1); var z0: float = Z.call(j); var z1: float = Z.call(j + 1)
			var side := (hw - absf((x0 + x1) / 2)) * k < hd - absf((z0 + z1) / 2)
			var pts := []
			for q in [[x0, z0], [x1, z0], [x0, z1], [x1, z1]]:
				var x: float = q[0]; var z: float = q[1]
				var uv := Vector2((z - z0) / (z1 - z0), (x - x0) / (x1 - x0)) if side else Vector2((x - x0) / (x1 - x0), (z - z0) / (z1 - z0))
				pts.append([Vector3(x, H.call(x, z), z), uv])
			var a: Array = pts[0]; var b: Array = pts[1]; var c: Array = pts[2]; var d: Array = pts[3]
			var base := g.pos.size()
			g.tri(a[0], c[0], b[0], a[1], c[1], b[1])
			g.tri(b[0], c[0], d[0], b[1], c[1], d[1])
			for q in 6:
				var t := clampf((g.pos[base + q].y - eave_y) / rise, 0, 1)
				g.col[base + q] = c_low.lerp(c_top, t)
			var dn := Vector3(0, -thick, 0)
			g.tri(a[0] + dn, b[0] + dn, c[0] + dn); g.tri(b[0] + dn, d[0] + dn, c[0] + dn)
			for q in range(6, 12):
				g.uv[base + q] = Vector2(0.5, 0.5); g.col[base + q] = c_bot
	var e := Kit.Geo.new()
	var edges := []
	for i in nx:
		edges.append([X.call(i), -hd, X.call(i + 1), -hd]); edges.append([X.call(i + 1), hd, X.call(i), hd])
	for j in nz:
		edges.append([-hw, Z.call(j + 1), -hw, Z.call(j)]); edges.append([hw, Z.call(j), hw, Z.call(j + 1)])
	for ed in edges:
		var ya: float = H.call(ed[0], ed[1]); var yb: float = H.call(ed[2], ed[3])
		var p1 := Vector3(ed[0], ya, ed[1]); var p2 := Vector3(ed[2], yb, ed[3])
		var p3 := p1 - Vector3(0, thick, 0); var p4 := p2 - Vector3(0, thick, 0)
		e.tri(p1, p3, p2, Vector2(0, 1), Vector2(0, 0), Vector2(1, 1))
		e.tri(p2, p3, p4, Vector2(1, 1), Vector2(0, 0), Vector2(1, 0))
	return { roof = g, edge = e, ridge_y = eave_y + rise, ridge_half = maxf(0.0, hw - hd / k) }

# 용마루 + 치켜든 끝
static func ridge_cap(m: M, part: String, half: float, y: float, w := 0.36) -> void:
	m.add(part, "flat", P(Kit.box(half * 2, 0.3, w, 0, y + 0.08, 0), ROOF_DARK, 0x2d2e30, 0.02), 0.03)
	for s in [-1, 1]:
		m.add(part, "flat", P(Kit.xf(Kit.box(0.5, 0.26, w * 0.9), s * (half + 0.12), y + 0.22, 0, 0, 0, s * 0.55), ROOF_DARK, 0x2d2e30, 0.02), 0.03)

# 벽에 구멍: x0..x1 구간, 구멍 hx0..hx1 / hy0..hy1, 두께 t, z
static func holed_wall(m: M, part: String, x0: float, x1: float, y0: float, y1: float, hx0: float, hx1: float, hy0: float, hy1: float, z: float, t: float, col: Array, key := "mud") -> void:
	var pieces := []
	if hx0 > x0: pieces.append([x0, hx0, y0, y1])
	if x1 > hx1: pieces.append([hx1, x1, y0, y1])
	if hy0 > y0: pieces.append([hx0, hx1, y0, hy0])
	if y1 > hy1: pieces.append([hx0, hx1, hy1, y1])
	for p in pieces:
		m.add(part, key, Kit.paint(Kit.box(p[1] - p[0], p[3] - p[2], t, (p[0] + p[1]) / 2, (p[2] + p[3]) / 2, z), Kit.hex(col[0]), Kit.hex(col[1]), 0.03, m.rng), 0.02)

# 창호(한지 창살) + 문틀
static func paper_panel(m: M, part: String, cx: float, cy: float, w: float, h: float, z: float, frame := true) -> void:
	m.add(part, "paper", vplane(w, h, cx, cy, z), 0)
	if not frame: return
	var f := 0.07
	m.add(part, "wood", PA(Kit.box(w + f * 2, f, 0.12, cx, cy + h / 2 + f / 2, z), WOOD), 0.012)
	m.add(part, "wood", PA(Kit.box(w + f * 2, f, 0.12, cx, cy - h / 2 - f / 2, z), WOOD), 0.012)
	m.add(part, "wood", PA(Kit.box(f, h, 0.12, cx - w / 2 - f / 2, cy, z), WOOD), 0.012)
	m.add(part, "wood", PA(Kit.box(f, h, 0.12, cx + w / 2 + f / 2, cy, z), WOOD), 0.012)

# 옹기(웹 onggiGeo)
static func onggi(r: float, h: float, seg := 10) -> Kit.Geo:
	var pts := []
	for q in [[0, 0], [0.55, 0], [0.8, 0.18], [1, 0.48], [0.92, 0.75], [0.62, 0.92], [0.58, 1.0], [0, 1.0]]:
		pts.append(Vector2(q[0] * r, q[1] * h))
	return lathe(pts, seg)

# 작은 초가 지붕(헛간·뒷간·주막 부속 등): 박공 없이 둥근 이엉 덮개. 중심 (0, eave, 0), 반폭 X·Z, 높이 hh
static func thatch_cap(m: M, part: String, X: float, Z: float, eave: float, hh: float, ws := 12, hs := 4) -> void:
	var th := 1.12
	var Ry := hh / (1.0 - cos(th))
	var dome := sphere(1, ws, hs, 0, TAU, 0, th)
	Kit.xf(dome, 0, eave - Ry * cos(th), 0, 0, 0, 0, X / sin(th), Ry, Z / sin(th))
	m.add(part, "thatch", PA(dome, THATCH, 0.05, m.rng), 0.04)
	var lip := Kit.cyl(1, 1.02, 0.26, ws + 2, 0, eave - 0.12, 0)
	Kit.xf(lip, 0, 0, 0, 0, 0, 0, X, 1, Z)
	m.add(part, "thatch", PA(lip, THATCH_LIP, 0.04, m.rng), 0.035)

# 맞배 이엉 지붕(길쭉한 헛간·외양간용): 용마름 있는 박공형. 길이 L(x), 깊이 D(z), 처마 높이 eave, 지붕 높이 rh
static func thatch_gable(m: M, part: String, L: float, D: float, eave: float, rh: float, cols: Array = THATCH, ridge_cols: Array = [0xb39d6c, 0x8f7b52]) -> void:
	var hz := D / 2
	# 이엉 비탈: 처마에서 용마루로 둥글게 부푼 단면(3띠) — 초가 맞배의 도톰한 느낌
	var K := 3
	for s in [-1, 1]:
		var g := Kit.Geo.new()
		for k in K:
			var t0 := float(k) / K; var t1 := float(k + 1) / K
			var y0 := eave + rh * sin(t0 * PI / 2); var y1 := eave + rh * sin(t1 * PI / 2)
			var z0: float = s * hz * (1 - t0); var z1: float = s * hz * (1 - t1)
			var x0 := L / 2 - 0.2 * t0; var x1 := L / 2 - 0.2 * t1
			var a := Vector3(-x0, y0, z0); var b := Vector3(x0, y0, z0); var c := Vector3(x1, y1, z1); var d := Vector3(-x1, y1, z1)
			if s > 0: g.quad(a, b, c, d, Vector2(0, t0), Vector2(1, t0), Vector2(1, t1), Vector2(0, t1))
			else: g.quad(b, a, d, c, Vector2(1, t0), Vector2(0, t0), Vector2(0, t1), Vector2(1, t1))
		# 처마 두께
		var a0 := Vector3(-L / 2, eave, s * hz); var b0 := Vector3(L / 2, eave, s * hz); var t := Vector3(0, -0.24, 0)
		if s > 0: g.quad(a0 + t, b0 + t, b0, a0)
		else: g.quad(b0 + t, a0 + t, a0, b0)
		m.add(part, "thatch", PA(g, cols, 0.05, m.rng), 0.04)
	# 박공 끝 이엉 삼각
	for sx in [-1, 1]:
		var g2 := Kit.Geo.new()
		var x: float = sx * (L / 2 - 0.1)
		var p0 := Vector3(x, eave - 0.05, -hz + 0.1); var p1 := Vector3(x, eave - 0.05, hz - 0.1); var p2 := Vector3(x - sx * 0.05, eave + rh - 0.05, 0)
		if sx > 0: g2.tri(p0, p2, p1)
		else: g2.tri(p0, p1, p2)
		m.add(part, "mud", PA(g2, [0x8f7a55, 0x6f5d40], 0.03, m.rng), 0.02)
	m.add(part, "thatch", PA(Kit.cyl(0.15, 0.15, L - 0.1, 8, 0, eave + rh - 0.02, 0, 0, 0, PI / 2), ridge_cols), 0.03)

# 기와 맞배(작은) 지붕 — 대문·가게
static func tile_roof(m: M, part: String, hw: float, hd: float, eave: float, rise: float, nx := 10, nz := 4, lift := 0.25, k := 2.6) -> Dictionary:
	var r := curved_roof(hw, hd, eave, rise, lift, k, 0.16, nx, nz)
	m.add(part, "tile", r.roof, 0.035)
	m.add(part, "makse", r.edge, 0)
	m.add(part, "flat", P(Kit.box(r.ridge_half * 2 + 0.3, 0.16, 0.22, 0, r.ridge_y + 0.05, 0), ROOF_DARK), 0.02)
	return r

# 두 점 a→b 방향 각도·길이·변환(돌담·울타리처럼 두 점을 잇는 모델)
static func seg_xform(ax: float, az: float, bx: float, bz: float, mid := true) -> Transform3D:
	var ang := atan2(bz - az, bx - ax)
	var o := Vector3((ax + bx) / 2, 0, (az + bz) / 2) if mid else Vector3(ax, 0, az)
	return Transform3D(Basis(Vector3.UP, -ang), o)

# 헛간류 몸체: 흙바닥 단 + 기둥 + 벽(walls: "none" | "back" | "three" | "four") + 도리 + 맞배 이엉 지붕.
# 앞(+z) 기둥 칸수 bays. 반환 { eave, top }
static func shed(m: M, W: float, D: float, wallH := 2.0, walls := "three", bays := 2, roof_h := 1.0) -> Dictionary:
	var R := m.rng
	var zf := D / 2
	m.add("p", "mud", P(Kit.box(W + 0.4, 0.18, D + 0.4, 0, 0.09, 0), 0xb9a27a, 0x9a845e, 0.04, R), 0.02)
	var y0 := 0.18
	for i in bays + 1:
		var x := -W / 2 + i * W / bays
		m.add("p", "wood", PA(Kit.box(0.17, wallH, 0.17, x, y0 + wallH / 2, zf), WOOD), 0.018)
		m.add("p", "wood", PA(Kit.box(0.17, wallH, 0.17, x, y0 + wallH / 2, -zf), WOOD), 0.018)
	if walls != "none":
		m.add("p", "mud", PA(Kit.box(W, wallH, 0.14, 0, y0 + wallH / 2, -zf), MUD, 0.04, R), 0.02)
	if walls == "three" or walls == "four":
		for s in [-1, 1]: m.add("p", "mud", PA(Kit.box(0.14, wallH, D, s * W / 2, y0 + wallH / 2, 0), MUD, 0.04, R), 0.02)
	m.add("p", "wood", PA(Kit.box(W + 0.3, 0.15, 0.2, 0, y0 + wallH + 0.05, zf), WOOD), 0.018)
	m.add("p", "wood", PA(Kit.box(W + 0.3, 0.15, 0.2, 0, y0 + wallH + 0.05, -zf), WOOD), 0.018)
	var eave := y0 + wallH + 0.12
	thatch_gable(m, "p", W + 0.9, D + 1.1, eave, roof_h)
	return { eave = eave, top = y0 + wallH, y0 = y0 }

# 어두운 문간(실내 없음): 문 구멍 안쪽을 어두운 판으로
static func dark_door(m: M, x: float, y0: float, w: float, h: float, z: float) -> void:
	m.add("p", "flat", P(Kit.box(w, h, 0.03, x, y0 + h / 2, z - 0.25), 0x3a2f25, 0x241c15), 0)

# ---------------------------------------------------------------------------
# 지붕 재료(고을 성격표 §9: neowa·gulpi·eoksae·choga_low) — 위에서 내려다볼 때 서로 확실히 달라 보이게
# ---------------------------------------------------------------------------
# 사각형 a-b-c-d를 want 쪽을 보게(감김 자동)
static func qf(g: Kit.Geo, a: Vector3, b: Vector3, c: Vector3, d: Vector3, want: Vector3) -> void:
	if (b - a).cross(c - a).dot(want) < 0.0: g.quad(a, d, c, b)
	else: g.quad(a, b, c, d)

static func tf(g: Kit.Geo, a: Vector3, b: Vector3, c: Vector3, want: Vector3) -> void:
	if (b - a).cross(c - a).dot(want) < 0.0: g.tri(a, c, b)
	else: g.tri(a, b, c)

# 판 지붕(맞배, 용마루 x방향): style "neowa"(너와: 회갈색 나무판 + 누름돌) | "gulpi"(굴피: 짙은 갈색 껍질 + 누름목).
# L 길이(x), D 깊이(z, 처마 끝끼리), eave 처마 높이, rh 용마루까지 높이. bw·bd·wall_top > 0이면 박공벽 + 까치구멍.
# 판은 처마에서 위로 줄(course)마다 겹쳐 얹고, 아랫단 끝(butt)을 어둡게 해서 판 결이 위에서 줄무늬로 보인다.
static func board_roof(m: M, part: String, L: float, D: float, eave: float, rh: float, style := "neowa", bw := 0.0, bd := 0.0, wall_top := 0.0, lod := false, small := false) -> float:
	var R := m.rng
	var hz := D / 2
	var ridge := eave + rh
	var neo := style == "neowa"
	var rows: int = 2 if lod else (7 if neo else 5) - (2 if small else 0)
	var pw: float = L if lod else (0.46 if neo else 0.82)
	var th := 0.1
	var under: Array = [0x5f564c, 0x4a433b] if neo else [0x3a2a1f, 0x2e2119]
	for s in [-1.0, 1.0]:
		var out := Vector3(0, hz, s * rh).normalized()   # 비탈 바깥 법선
		var down := Vector3(0, -rh, s * hz).normalized()  # 처마 쪽(비탈 아래)
		var Pt := func(x: float, t: float) -> Vector3: return Vector3(x, eave + rh * t, s * hz * (1.0 - t))
		# 밑판(외곽 먹선 = 지붕 윤곽)
		var g := Kit.Geo.new()
		var a: Vector3 = Pt.call(-L / 2, 0.0); var b: Vector3 = Pt.call(L / 2, 0.0); var c: Vector3 = Pt.call(L / 2, 1.0); var d: Vector3 = Pt.call(-L / 2, 1.0)
		var dn := Vector3(0, -th, 0)
		qf(g, a, b, c, d, out)
		qf(g, a + dn, b + dn, b, a, down)
		qf(g, a + dn, b + dn, c + dn, d + dn, -out)
		qf(g, b + dn, c + dn, c, b, Vector3.RIGHT)
		qf(g, a + dn, d + dn, d, a, Vector3.LEFT)
		m.add(part, "flat", PA(g, under, 0.02, R), 0.045)
		# 판(줄마다 겹침)
		var tops := []; var butts := []
		for k in rows:
			var t0 := float(k) / rows - (0.035 if k > 0 else -0.0)
			var t1 := minf(1.0, float(k + 1) / rows + 0.06)
			var x := -L / 2 - (R.next() * pw * 0.5 if k % 2 == 1 else 0.0)
			while x < L / 2 - 0.02:
				var w := pw * R.between(0.8, 1.2) if not lod else L
				var xa := maxf(-L / 2, x) + (0.012 if not lod else 0.0); var xb := minf(L / 2, x + w) - (0.012 if not lod else 0.0)
				x += w
				if xb - xa < 0.08: continue
				var tb := t0 + (R.between(-0.015, 0.015) if not lod else 0.0)
				var lb := 0.075; var lt := 0.03
				var A: Vector3 = Pt.call(xa, tb) + out * lb; var B: Vector3 = Pt.call(xb, tb) + out * lb
				var Cc: Vector3 = Pt.call(xb, t1) + out * lt; var Dd: Vector3 = Pt.call(xa, t1) + out * lt
				var pg := Kit.Geo.new()
				qf(pg, A, B, Cc, Dd, out)
				var tone := R.next()
				var top_c: int; var bot_c: int
				if neo:
					top_c = 0x9b9284 if tone < 0.45 else (0x8d7a62 if tone < 0.8 else 0xa7a092)
					bot_c = 0x7c7466 if tone < 0.45 else (0x6f5e4a if tone < 0.8 else 0x878073)
				else:
					top_c = 0x5e4434 if tone < 0.5 else (0x4e3828 if tone < 0.85 else 0x6a4e3a)
					bot_c = 0x45311f if tone < 0.5 else (0x3a2a1d if tone < 0.85 else 0x50392a)
				tops.append(P(pg, top_c, bot_c, 0.03, R))
				var bg := Kit.Geo.new()
				var A0: Vector3 = Pt.call(xa, tb) + out * 0.005; var B0: Vector3 = Pt.call(xb, tb) + out * 0.005
				qf(bg, A0, B0, B, A, down)
				butts.append(P(bg, 0x3a332c if neo else 0x231810, -1, 0.02, R))
		m.add(part, "wood" if neo else "bark", Kit.merge(tops), 0.0 if lod else 0.014)
		m.add(part, "flat", Kit.merge(butts), 0)
		if lod: continue
		# 누름대·누름목(가로 장대)
		var poles: Array = [0.62] if neo else [0.2, 0.5, 0.8]
		for tp in poles:
			var pc: Vector3 = Pt.call(0.0, tp) + out * 0.15
			m.add(part, "wood", P(Kit.cyl(0.075 if neo else 0.09, 0.075 if neo else 0.09, L - 0.3, 6, pc.x, pc.y, pc.z, 0, 0, PI / 2),
				0x7a6a58 if neo else 0x8a7a64, 0x5a4c3e if neo else 0x655845, 0.04, R), 0.02)
		# 누름돌
		var stones := []
		var ns := (10 if neo else 4) / (2 if small else 1)
		for i in ns:
			var tx := -L / 2 + 0.45 + (L - 0.9) * (float(i) + R.between(0.1, 0.9)) / ns
			var tk := (R.between(0.0, rows - 1.0) if neo else R.between(0.1, 0.9))
			var tt := clampf(floorf(tk) / rows + 0.07, 0.05, 0.9) if neo else tk
			var sp: Vector3 = Pt.call(tx, tt) + out * 0.13
			var lg := Kit.lump(R.between(0.13, 0.2), 0, R, 0.3, 0.6)
			stones.append(P(Kit.xf(lg, sp.x, sp.y, sp.z, 0, R.next() * 3, 0), 0xb0aa9c, 0x7f796d, 0.06, R))
		m.add(part, "stone", Kit.merge(stones), 0.018)
	# 용마루 덮개(엎은 V 판)
	var cap := Kit.Geo.new()
	for s in [-1.0, 1.0]:
		var out := Vector3(0, hz, s * rh).normalized()
		var lo := Vector3(0, ridge - rh * 0.11, s * hz * 0.11) + out * 0.1
		var hi := Vector3(0, ridge + 0.13, 0)
		qf(cap, Vector3(-L / 2 - 0.05, lo.y, lo.z), Vector3(L / 2 + 0.05, lo.y, lo.z), Vector3(L / 2 + 0.05, hi.y, hi.z), Vector3(-L / 2 - 0.05, hi.y, hi.z), out)
	m.add(part, "wood" if neo else "bark", P(cap, 0x8a8174 if neo else 0x4a3426, 0x6e665a if neo else 0x3a291d, 0.03, R), 0.02)
	if not neo and not lod:
		m.add(part, "wood", P(Kit.cyl(0.1, 0.1, L - 0.1, 6, 0, ridge + 0.2, 0, 0, 0, PI / 2), 0x8a7a64, 0x655845, 0.04, R), 0.02)
	elif not lod:
		for i in 3:
			var lg := Kit.lump(0.17, 0, R, 0.3, 0.6)
			m.add(part, "stone", P(Kit.xf(lg, -L / 3 + i * L / 3, ridge + 0.2, 0), 0xb0aa9c, 0x7f796d, 0.06, R), 0.018)
	# 박공벽 + 까치구멍(너와집·굴피집 박공 위 연기 구멍)
	if bw > 0.0:
		for sx in [-1.0, 1.0]:
			var x: float = sx * bw / 2
			var apex := ridge - 0.25
			var gb := Kit.Geo.new()
			tf(gb, Vector3(x, wall_top, -bd / 2), Vector3(x, wall_top, bd / 2), Vector3(x, apex, 0), Vector3(sx, 0, 0))
			m.add(part, "wood", PA(gb, WOOD, 0.03, R), 0.02)
			var kh := Kit.Geo.new()
			tf(kh, Vector3(x + sx * 0.015, apex - 0.6, -0.28), Vector3(x + sx * 0.015, apex - 0.6, 0.28), Vector3(x + sx * 0.015, apex - 0.18, 0), Vector3(sx, 0, 0))
			m.add(part, "flat", P(kh, 0x1e1813), 0)
	return ridge

# 억새 지붕(맞배) 색 — 볏짚보다 희고 잿빛(고산 귀틀집)
const EOKSAE := [0xc4c3ba, 0x83837c]
const EOKSAE_RIDGE := [0x9d9b90, 0x74736b]
# 낡은 바닷가 이엉(잿빛 갈색)
const THATCH_SEA := [0xaea58f, 0x77705f]
const THATCH_SEA_LIP := [0x857d6a, 0x635c4d]
