# kit/landmark 공용: 색, 세운 판·구멍 벽·창호, 범용 목조 건물(hall), 기와 얹은 담장, 홍예 돌 블록.
# 웹 buildings.js giwa()의 화풍(돌 기단·붉은 기둥·초록 창방·흰 회벽·창호지·곡선 기와지붕)을 크게 키운 것.
extends RefCounted

const Roof = preload("res://kit/landmark/_roof.gd")

const WOOD := [0x6b5038, 0x4d3826]
const WOOD_L := [0x9a7852, 0x7a5c3e]
const STONE := [0xa19b8f, 0x77726a]
const STONE_L := [0xb8b2a5, 0x8e897f]
const PLASTER := [0xece4cf, 0xd8ccb0]
const DAN_R := [0x8a3e2e, 0x6a2e22]
const DAN_G := [0x557d70, 0x3f6558]
const DAN_LINE := 0xa3503a
const DARK := [0x3e3128, 0x2c231c]
const SEONG := [0xb3ab98, 0x8a8273]     # 성돌(화강암 판석)

static func c(h: int) -> Color: return Kit.hex(h)

static func pnt(g: Kit.Geo, cols: Array, jit := 0.04, rng = null) -> Kit.Geo:
	return Kit.paint(g, Kit.hex(cols[0]), Kit.hex(cols[1] if cols.size() > 1 else cols[0]), jit, rng)

# +z를 보는 세운 판(폭 w, 높이 h, 중심 cx,cy, 깊이 z). nz=-1이면 -z를 본다
static func vplane(w: float, h: float, cx: float, cy: float, z: float, nz := 1.0) -> Kit.Geo:
	var g := Kit.Geo.new()
	var a := Vector3(cx - w / 2, cy - h / 2, z); var b := Vector3(cx + w / 2, cy - h / 2, z)
	var cc := Vector3(cx + w / 2, cy + h / 2, z); var d := Vector3(cx - w / 2, cy + h / 2, z)
	if nz > 0: g.quad(a, b, cc, d)
	else: g.quad(b, a, d, cc, Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1))
	return g

# xy 평면 다각형(반시계/시계 상관없음)을 z 방향으로 깊이 dep만큼 세운 각기둥 (z0 = 중심)
static func extrude_xy(poly: PackedVector2Array, dep: float, z0 := 0.0, caps := true) -> Kit.Geo:
	var g := Kit.Geo.new()
	var n := poly.size()
	var area := 0.0
	for i in n: area += poly[i].x * poly[(i + 1) % n].y - poly[(i + 1) % n].x * poly[i].y
	var ccw := area > 0.0
	var zf := z0 + dep / 2; var zb := z0 - dep / 2
	var per := 0.0
	for i in n: per += poly[i].distance_to(poly[(i + 1) % n])
	var acc := 0.0
	for i in n:
		var p0 := poly[i]; var p1 := poly[(i + 1) % n]
		var d := p1 - p0
		var out := Vector3(d.y, -d.x, 0) if ccw else Vector3(-d.y, d.x, 0)
		var u0 := acc / per; acc += d.length(); var u1 := acc / per
		Roof.quad_facing(g, Vector3(p0.x, p0.y, zb), Vector3(p1.x, p1.y, zb), Vector3(p1.x, p1.y, zf), Vector3(p0.x, p0.y, zf), out,
			Vector2(u0, 0), Vector2(u1, 0), Vector2(u1, 1), Vector2(u0, 1))
	if caps:
		var idx := Geometry2D.triangulate_polygon(poly)
		var bb := Rect2(poly[0], Vector2.ZERO)
		for p in poly: bb = bb.expand(p)
		for i in range(0, idx.size(), 3):
			var A := poly[idx[i]]; var B := poly[idx[i + 1]]; var Cc := poly[idx[i + 2]]
			var uA := (A - bb.position) / bb.size; var uB := (B - bb.position) / bb.size; var uC := (Cc - bb.position) / bb.size
			Roof.tri_facing(g, Vector3(A.x, A.y, zf), Vector3(B.x, B.y, zf), Vector3(Cc.x, Cc.y, zf), Vector3(0, 0, 1), uA, uB, uC)
			Roof.tri_facing(g, Vector3(A.x, A.y, zb), Vector3(B.x, B.y, zb), Vector3(Cc.x, Cc.y, zb), Vector3(0, 0, -1), uA, uB, uC)
	return g

# 벽에 구멍(웹 holedWall)
static func holed_wall(b, x0: float, x1: float, y0: float, y1: float, hx0: float, hx1: float, hy0: float, hy1: float, z: float, t: float, col: Array, key := "mud", rng = null) -> void:
	var pieces := []
	if hx0 > x0: pieces.append([x0, hx0, y0, y1])
	if x1 > hx1: pieces.append([hx1, x1, y0, y1])
	if hy0 > y0: pieces.append([hx0, hx1, y0, hy0])
	if y1 > hy1: pieces.append([hx0, hx1, hy1, y1])
	for p in pieces:
		b.add(key, pnt(Kit.box(p[1] - p[0], p[3] - p[2], t, (p[0] + p[1]) / 2, (p[2] + p[3]) / 2, z), col, 0.03, rng), 0.02)

# 창호(한지 띠살) + 문틀 (웹 paperPanel)
static func paper_panel(b, cx: float, cy: float, w: float, h: float, z: float, frame := true) -> void:
	b.add("paper", vplane(w, h, cx, cy, z), 0.0)
	if not frame: return
	var f := 0.07
	var fr := Kit.merge([vplane(w + f * 2, f, cx, cy + h / 2 + f / 2, z + 0.03), vplane(w + f * 2, f, cx, cy - h / 2 - f / 2, z + 0.03),
		vplane(f, h, cx - w / 2 - f / 2, cy, z + 0.03), vplane(f, h, cx + w / 2 + f / 2, cy, z + 0.03)])
	b.add("wood", pnt(fr, WOOD), 0.0)

# 홍살(붉은 세로 살): x0..x1, y0..y1, z
static func hongsal(b, x0: float, x1: float, y0: float, y1: float, z: float, step := 0.22) -> void:
	var n := maxi(2, roundi((x1 - x0) / step))
	var g := Kit.Geo.new()
	for i in n + 1:
		var x := x0 + (x1 - x0) * i / n
		g = Kit.merge([g, Kit.box(0.06, y1 - y0, 0.06, x, (y0 + y1) / 2, z)])
	g = Kit.merge([g, Kit.box(x1 - x0 + 0.1, 0.1, 0.1, (x0 + x1) / 2, y1, z), Kit.box(x1 - x0 + 0.1, 0.1, 0.1, (x0 + x1) / 2, y0, z)])
	b.add("flat", pnt(g, DAN_R, 0.0), 0.0)

# 판문(두 짝). open이면 안쪽으로 열린 채
static func board_doors(b, cx: float, y0: float, w: float, h: float, z: float, open := false, cols := [0x7a4a34, 0x5e3828]) -> void:
	for s in [-1, 1]:
		var hw := w / 2
		if open:
			var ang: float = s * 1.25
			var g := Kit.box(hw, h, 0.08, 0, 0, 0)
			Kit.xf(g, 0, 0, 0, 0, 0)
			# 경첩(바깥 모서리) 기준으로 안쪽(-z)으로 회전
			var hx: float = cx + s * hw
			var t := Transform3D(Basis(Vector3.UP, ang), Vector3(hx, y0 + h / 2, z)) * Transform3D(Basis.IDENTITY, Vector3(-s * hw / 2, 0, 0))
			b.add("wood", pnt(Kit.apply(g, t), cols), 0.015)
		else:
			b.add("wood", pnt(Kit.box(hw - 0.02, h, 0.08, cx + s * hw / 2, y0 + h / 2, z), cols), 0.015)
			# 태극 대신 흰 띠 둘(문빗장 느낌)
			b.add("flat", pnt(Kit.box(hw - 0.1, 0.08, 0.1, cx + s * hw / 2, y0 + h * 0.3, z + 0.02), [0x3a2c22]), 0.0)

# 돌 기단(가구식/막돌 느낌) + 앞 계단
static func platform(b, w: float, d: float, h: float, rng: Kit.Rng, cz := 0.0, steps := [0.0], step_w := 1.8, cx := 0.0) -> void:
	b.add("stone", pnt(Kit.box(w, h + 0.1, d, cx, (h - 0.1) / 2, cz), [0xaaa498, 0x7b766c], 0.05, rng), 0.03)
	# 앞면 면석 줄(먹선 없이)
	var n := maxi(3, roundi(w / 1.1))
	for i in n:
		for row in maxi(1, roundi(h / 0.32)):
			var bx := cx - w / 2 + (i + 0.5 + (row % 2) * 0.35) * w / n
			if absf(bx - cx) > w / 2 - 0.25: continue
			b.add("stone", pnt(vplane(w / n - 0.07, 0.26, bx, 0.15 + row * 0.3, cz + d / 2 + 0.015), [0xb5afa2, 0x948f84], 0.06, rng), 0.0)
	var ns := maxi(1, roundi(h / 0.22))
	for sx in steps:
		for s in ns:
			var sh := h * (s + 1) / ns
			b.add("stone", pnt(Kit.box(step_w, sh, 0.36, cx + sx, sh / 2, cz + d / 2 + 0.18 + (ns - 1 - s) * 0.34), STONE_L, 0.04, rng), 0.02)

# ---------------------------------------------------------------------------
# 범용 목조 건물(hall). body/roof 두 Batch에 넣는다. 정면 +z.
# o: bays(Array 정면 칸 폭), depth(측면 길이 D), dbays(측면 칸 수), F(기단 높이), H(기둥 높이),
#    fronts(Array: "door" "window" "open" "wall" "board" "gate" "gate_closed" "hongsal" "none"), cx, cz,
#    roof(type), ox/oz(처마 내밀기), rise, lift, enclose(벽 두름 true/false), back("wall"|"none"|"hongsal"),
#    bracket("ikgong"|"dapo"|"none"), col_r, base(true), floor(true=마루 높이 F), steps, roof_nx/nz, lamp(bool)
# 반환: { W, D, F, top, eave, ridge_y, x0, x1, z0, z1, lights:[] }
# ---------------------------------------------------------------------------
static func hall(body, roofb, o: Dictionary, rng: Kit.Rng) -> Dictionary:
	var bays: Array = o.bays
	var W := 0.0
	for w in bays: W += w
	var D: float = o.depth
	var dbays: int = o.get("dbays", 2)
	var F: float = o.get("F", 0.75)
	var H: float = o.get("H", 3.0)
	var cx: float = o.get("cx", 0.0); var cz: float = o.get("cz", 0.0)
	var fronts: Array = o.get("fronts", [])
	var cr: float = o.get("col_r", 0.18)
	var top := F + H
	var zf := cz + D / 2; var zb := cz - D / 2
	var x0 := cx - W / 2
	var t := 0.2
	var info := { W = W, D = D, F = F, top = top, x0 = x0, x1 = x0 + W, z0 = zb, z1 = zf, lights = [] }
	# 기단
	if o.get("base", true):
		var m: float = o.get("base_margin", 0.75)
		var steps: Array = o.get("steps", [0.0])
		platform(body, W + m * 2, D + m * 2, F, rng, cz, steps, o.get("step_w", 1.8), cx)
		info.base = [W + m * 2, D + m * 2]
	# 기둥(앞·뒤 줄 + 옆 중간). 초석 포함
	var colx := [x0]
	for w in bays: colx.append(colx[-1] + w)
	var colpos := []
	for x in colx:
		colpos.append(Vector2(x, zf)); colpos.append(Vector2(x, zb))
	for j in range(1, dbays):
		var z := zb + D * j / dbays
		colpos.append(Vector2(x0, z)); colpos.append(Vector2(x0 + W, z))
	var colg := []
	for p in colpos:
		colg.append(Kit.cyl(cr * 0.92, cr, H, 6, p.x, F + H / 2, p.y, 0, 0, 0, false))
	body.add("flat", pnt(Kit.merge(colg), o.get("col_color", DAN_R), 0.0), 0.02)
	var cho := []
	for p in colpos: cho.append(Kit.cyl(cr * 1.5, cr * 1.7, 0.22, 6, p.x, F + 0.09, p.y, 0, 0, 0, false))
	body.add("stone", pnt(Kit.merge(cho), STONE_L, 0.04, rng), 0.0)
	# 벽: 옆·뒤
	var enclose: bool = o.get("enclose", true)
	var back: String = o.get("back", "wall" if enclose else "none")
	var wall_col: Array = o.get("wall_color", PLASTER)
	if back == "wall":
		body.add("mud", pnt(Kit.box(W, H, t, cx, F + H / 2, zb), wall_col, 0.03, rng), 0.02)
	elif back == "board":
		body.add("wood", pnt(Kit.box(W, H, t, cx, F + H / 2, zb), WOOD, 0.03, rng), 0.02)
	elif back == "hongsal":
		hongsal(body, x0 + cr, x0 + W - cr, F + 0.4, top - 0.2, zb)
	var sides: String = o.get("sides", back)
	for s in [-1, 1]:
		var sx: float = cx + s * W / 2
		if sides == "wall" or sides == "board":
			var g := Kit.box(t, H, D, sx, F + H / 2, cz)
			body.add("mud" if sides == "wall" else "wood", pnt(g, wall_col if sides == "wall" else WOOD, 0.03, rng), 0.02)
			# 옆 창 하나(정면 가까운 칸)
			if sides == "wall" and o.get("side_window", true) and D > 3.5:
				var wz := zf - D / dbays * 0.5
				var pg := vplane(0.8, 0.7, 0, 0, 0)
				Kit.xf(pg, sx + s * (t / 2 + 0.01), F + 1.4, wz, 0, s * PI / 2)
				body.add("paper", pg, 0.0)
		elif sides == "hongsal":
			var g := Kit.Geo.new()
			var n := maxi(3, roundi(D / 0.22))
			for i in n + 1:
				g = Kit.merge([g, Kit.box(0.06, H - 0.6, 0.06, sx, F + 0.4 + (H - 0.6) / 2, zb + D * i / n)])
			body.add("flat", pnt(g, DAN_R, 0.0), 0.0)
	# 마루(바닥)
	if o.get("floor", true) and F > 0.3:
		body.add("wood", pnt(Kit.box(W - 0.1, 0.08, D - 0.1, cx, F - 0.02, cz), WOOD_L, 0.03, rng), 0.0)
	# 정면 칸
	for i in bays.size():
		var bx0: float = colx[i]; var bx1: float = colx[i + 1]; var bcx := (bx0 + bx1) / 2; var bw := bx1 - bx0
		var kind: String = fronts[i] if i < fronts.size() else "wall"
		match kind:
			"door":
				var dh := minf(2.2, H - 0.5)
				holed_wall(body, bx0, bx1, F, top, bcx - bw / 2 + 0.2, bcx + bw / 2 - 0.2, F + 0.3, F + 0.3 + dh, zf, t, wall_col, "mud", rng)
				var np := 4 if bw > 2.6 else 2
				var pw := (bw - 0.4) / np
				for k in np:
					paper_panel(body, bcx - bw / 2 + 0.2 + pw * (k + 0.5), F + 0.3 + dh / 2, pw - 0.1, dh - 0.12, zf + 0.02)
				body.add("wood", pnt(Kit.box(bw, 0.3, 0.22, bcx, F + 0.15, zf), WOOD_L), 0.012)
			"window":
				holed_wall(body, bx0, bx1, F, top, bcx - 0.5, bcx + 0.5, F + 0.95, F + 1.75, zf, t, wall_col, "mud", rng)
				paper_panel(body, bcx, F + 1.35, 1.0, 0.8, zf + 0.02)
				body.add("wood", pnt(Kit.box(bw, 0.5, 0.22, bcx, F + 0.25, zf + 0.01), WOOD_L), 0.012)
			"open":
				# 대청: 안쪽 어둡게(뒷벽 판문 느낌)
				body.add("flat", pnt(Kit.box(bw, H, 0.05, bcx, F + H / 2, zb + 0.18), DARK), 0.0)
				body.add("wood", pnt(Kit.box(bw - 0.1, 0.06, D - 0.3, bcx, F + 0.03, cz), WOOD_L, 0.03, rng), 0.0)
				# 뒷벽 판문 살
				for k in 2:
					body.add("wood", pnt(Kit.box(bw * 0.4, H * 0.62, 0.04, bcx + (k - 0.5) * bw * 0.45, F + H * 0.36, zb + 0.22), [0x5a4532, 0x4a3828]), 0.0)
			"wall":
				body.add("mud", pnt(Kit.box(bw, H, t, bcx, F + H / 2, zf), wall_col, 0.03, rng), 0.02)
			"board":
				body.add("wood", pnt(Kit.box(bw, H, t, bcx, F + H / 2, zf), WOOD, 0.03, rng), 0.02)
			"hongsal":
				hongsal(body, bx0 + cr, bx1 - cr, F + 0.35, top - 0.15, zf)
			"gate", "gate_closed":
				var gh := minf(H - 0.35, 3.2)
				board_doors(body, bcx, F, bw - cr * 2, gh, zf - D * 0.0 - 0.05, kind == "gate")
				if gh < H - 0.2:
					hongsal(body, bx0 + cr, bx1 - cr, F + gh + 0.05, top - 0.12, zf)
				# 문지방
				body.add("wood", pnt(Kit.box(bw - cr * 2, 0.22, 0.24, bcx, F + 0.11, zf), WOOD), 0.012)
			"none":
				pass
	# 창방(초록) + 단청 띠 / 뒤·옆 창방
	var band: Array = o.get("band", DAN_G)
	body.add("flat", pnt(Kit.box(W + 0.5, 0.26, 0.3, cx, top + 0.13, zf), band, 0.02), 0.02)
	body.add("flat", pnt(Kit.box(W + 0.5, 0.08, 0.32, cx, top + 0.3, zf), [DAN_LINE]), 0.01)
	body.add("flat", pnt(Kit.box(W + 0.5, 0.3, 0.3, cx, top + 0.15, zb), band), 0.02)
	for s in [-1, 1]:
		body.add("flat", pnt(Kit.box(0.3, 0.3, D + 0.4, cx + s * W / 2, top + 0.15, cz), band), 0.02)
	# 공포
	var br: String = o.get("bracket", "ikgong")
	var bg := []
	if br != "none":
		for x in colx:
			bg.append(Kit.box(0.28, 0.32, 0.9, x, top + 0.38, zf + 0.25))
			bg.append(Kit.box(0.5, 0.14, 0.34, x, top + 0.6, zf + 0.12))
		if br == "dapo":
			for i in bays.size():
				var n := 2 if bays[i] > 2.6 else 1
				for k in n:
					var x: float = colx[i] + bays[i] * (k + 1) / (n + 1)
					bg.append(Kit.box(0.26, 0.3, 0.8, x, top + 0.38, zf + 0.22))
					bg.append(Kit.box(0.46, 0.14, 0.32, x, top + 0.6, zf + 0.12))
			# 평방
			bg.append(Kit.box(W + 0.4, 0.16, 0.36, cx, top + 0.5, zf))
		body.add("flat", pnt(Kit.merge(bg), band, 0.02), 0.012)
	# 지붕
	var bh := 0.75 if br == "dapo" else 0.55
	var eave := top + bh
	var rtype: String = o.get("roof", "paljak")
	var ro := {
		type = rtype, hw = W / 2 + o.get("ox", 1.7), hd = D / 2 + o.get("oz", 1.55), eave = eave,
		lift = o.get("lift", 0.6), thick = o.get("thick", 0.26), nx = o.get("roof_nx", 28), nz = o.get("roof_nz", 16),
		outline = 0.05,
	}
	ro.rise = o.get("rise", 0.62 * ro.hd)
	if o.has("k"): ro.k = o.k
	if rtype == "matbae":
		ro.gable_x = W / 2 + 0.1; ro.gable_d = D / 2 + 0.15; ro.gable_y = top + 0.3
	info.eave = eave
	info.roof_hw = ro.hw; info.roof_hd = ro.hd
	if rtype == "none":
		info.ridge_y = eave + ro.rise
		info.roof = ro
		return info
	var ri := Roof.add(roofb, ro, cx, cz)
	info.ridge_y = ri.ridge_y
	info.roof_hw = ro.hw; info.roof_hd = ro.hd
	return info

# 기와 얹은 담장(관아·사찰): (ax,az)→(bx,bz), 높이 h. 아래 막돌, 위 회벽, 꼭대기 기와(맞배 단면)
static func tile_wall(b, ax: float, az: float, bx: float, bz: float, h: float, rng: Kit.Rng, th := 0.5, stone_frac := 0.45) -> void:
	var len := Vector2(bx - ax, bz - az).length()
	if len < 0.05: return
	var ang := atan2(bz - az, bx - ax)
	var xfm := Transform3D(Basis(Vector3.UP, -ang), Vector3((ax + bx) / 2, 0, (az + bz) / 2))
	var hs := h * stone_frac
	b.add("stone", Kit.apply(pnt(Kit.box(len, hs, th, 0, hs / 2, 0), [0x9d978a, 0x7f796d], 0.05, rng), xfm), 0.025)
	b.add("mud", Kit.apply(pnt(Kit.box(len, h - hs, th * 0.86, 0, hs + (h - hs) / 2, 0), [0xe6dcc4, 0xd2c4a4], 0.03, rng), xfm), 0.02)
	# 박힌 돌 몇 개(무늬)
	var n := maxi(1, roundi(len / 1.4))
	var sg := []
	for i in n:
		var x: float = -len / 2 + (i + 0.5) * len / n + (rng.next() - 0.5) * 0.3
		for side in [-1, 1]:
			sg.append(Kit.box(0.42, 0.22, 0.04, x, hs * (0.35 + rng.next() * 0.3), side * (th / 2 + 0.01)))
	b.add("stone", Kit.apply(pnt(Kit.merge(sg), [0xbdb6a6, 0x9a9282], 0.06, rng), xfm), 0.0)
	# 기와 지붕(ㅅ자)
	var rw := th / 2 + 0.28
	var g := Kit.Geo.new()
	var yb := h; var yt := h + 0.32
	var L := len / 2 + 0.12
	var ns := maxi(1, roundi(2.0 * L / 1.1))
	for i in ns:
		var xa := -L + 2.0 * L * i / ns; var xb := -L + 2.0 * L * (i + 1) / ns
		g.quad(Vector3(xa, yb, rw), Vector3(xb, yb, rw), Vector3(xb, yt, 0), Vector3(xa, yt, 0))
		g.quad(Vector3(xb, yb, -rw), Vector3(xa, yb, -rw), Vector3(xa, yt, 0), Vector3(xb, yt, 0))
	Roof.tri_facing(g, Vector3(-L, yb, rw), Vector3(-L, yb, -rw), Vector3(-L, yt, 0), Vector3(-1, 0, 0))
	Roof.tri_facing(g, Vector3(L, yb, rw), Vector3(L, yb, -rw), Vector3(L, yt, 0), Vector3(1, 0, 0))
	Roof.quad_facing(g, Vector3(-L, yb, rw), Vector3(L, yb, rw), Vector3(L, yb, -rw), Vector3(-L, yb, -rw), Vector3(0, -1, 0))
	b.add("tile", Kit.apply(Kit.paint(g, Kit.hex(0x8f9094), Kit.hex(0x6e6f73), 0.02, rng), xfm), 0.025)
	b.add("flat", Kit.apply(pnt(Kit.box(len + 0.3, 0.14, 0.22, 0, yt + 0.03, 0), Roof.RIDGE), xfm), 0.015)

# 담장 충돌 상자(로컬)
static func wall_collider(ax: float, az: float, bx: float, bz: float, th := 0.6) -> Dictionary:
	return { type = "box", minX = minf(ax, bx) - th / 2, maxX = maxf(ax, bx) + th / 2, minZ = minf(az, bz) - th / 2, maxZ = maxf(az, bz) + th / 2 }

# 두 Batch(body, roof)를 자식으로 묶은 Node3D. 지붕은 실내 모드에서 숨길 수 있게 따로
static func node2(name: String, body, roofb) -> Node3D:
	var root := Node3D.new(); root.name = name
	if not body.is_empty():
		var n: Node3D = body.build("body"); root.add_child(n)
	if roofb != null and not roofb.is_empty():
		var r: Node3D = roofb.build("roof"); root.add_child(r)
	return root

static func tris_of(node: Node3D) -> int:
	var t := 0
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var m: Mesh = mi.mesh
		for s in m.get_surface_count(): t += m.surface_get_array_len(s) / 3
	return t

# 작은 나무(섬·절 마당용 간단 덩이) — 본격 식생은 kit/nature
static func small_tree(b, x: float, z: float, h: float, rng: Kit.Rng, kind := "leaf") -> void:
	b.add("bark", pnt(Kit.limb(Vector3(x, 0, z), Vector3(x + (rng.next() - 0.5) * 0.4, h * 0.6, z), 0.16, 0.1, 5), [0x8a5a3c, 0x6a4430]), 0.015)
	var cols := [0x7f9a52, 0x4c6a3a] if kind == "leaf" else [0x6f8a4a, 0x3e5a32]
	var g := Kit.lump(h * 0.32, 1, rng, 0.25, 0.8)
	Kit.xf(g, x, h * 0.72, z)
	b.add(kind, Kit.paint(g, Kit.hex(cols[0]), Kit.hex(cols[1]), 0.08, rng), 0.03)

# ---------------------------------------------------------------------------
# 배치 도우미: 조각 목록 [{kit:"landmark/…", params, x, z, ry, [tag]}] → 한 Node3D + 충돌·조명·앵커(부모 좌표)
# 지형 엔진은 pieces를 그대로 받아 조각마다 add_static 해도 된다.
# ---------------------------------------------------------------------------
static func assemble(name: String, pieces: Array) -> Dictionary:
	var root := Node3D.new(); root.name = name
	var colliders := []; var lights := []; var anchors := {}
	var cache := {}
	var i := 0
	for p in pieces:
		var path: String = "res://kit/" + p.kit + ".gd"
		if not cache.has(path): cache[path] = load(path)
		var info: Dictionary = cache[path].build(p.params)
		var n: Node3D = info.node
		var xf := Transform3D(Basis(Vector3.UP, float(p.get("ry", 0.0))), Vector3(p.x, float(p.get("y", 0.0)), p.z))
		n.transform = xf
		var tag: String = p.get("tag", p.kit.get_file())
		n.name = "%s_%d" % [tag, i]; i += 1
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
		if p.has("tag"):
			for an in info.get("anchors", {}):
				anchors["%s_%s" % [tag, an]] = xf * (info.anchors[an] as Vector3)
	return { node = root, colliders = colliders, lights = lights, anchors = anchors }

# 담장 조각: 꼭짓점 목록(닫힌 다각형이면 closed) + 틈(gaps: [[x,z,반폭]]) → gwana_wall 조각들(최대 seg m)
static func wall_pieces(pts: Array, closed: bool, gaps: Array, seed: int, h := 2.2, seg := 12.0) -> Array:
	var out := []
	var n := pts.size()
	var m := n if closed else n - 1
	var k := 0
	for i in m:
		var a: Vector2 = pts[i]; var b: Vector2 = pts[(i + 1) % n]
		var L := a.distance_to(b)
		var dir := (b - a) / L
		# 이 변 위의 틈을 t 구간으로
		var cuts := []
		for g in gaps:
			var gp := Vector2(g[0], g[1])
			var t := (gp - a).dot(dir)
			var off := absf((gp - a).cross(dir))
			if off < 1.0 and t > 0 and t < L: cuts.append([t - g[2], t + g[2]])
		cuts.sort_custom(func(x, y): return x[0] < y[0])
		var spans := []
		var s0 := 0.0
		for c in cuts:
			if c[0] > s0 + 0.3: spans.append([s0, c[0]])
			s0 = c[1]
		if L > s0 + 0.3: spans.append([s0, L])
		for sp in spans:
			var sl: float = sp[1] - sp[0]
			var ns := maxi(1, ceili(sl / seg))
			for j in ns:
				var t0: float = sp[0] + sl * j / ns; var t1: float = sp[0] + sl * (j + 1) / ns
				var c := a + dir * (t0 + t1) / 2
				out.append({ kit = "landmark/gwana_wall", params = { seed = seed + k, length = t1 - t0 + 0.25, height = h }, x = c.x, z = c.y, ry = -atan2(dir.y, dir.x) })
				k += 1
	return out

# 홍살문: 붉은 둥근 기둥 둘 + 위 가로대 + 살대 + 가운데 태극(삼지창 대신 간략). 로컬 x 방향 폭 w, 높이 h, 중심 (x,z)
static func hongsal_gate(b, x: float, z: float, w := 4.2, h := 5.6) -> void:
	var g := []
	for s in [-1, 1]:
		g.append(Kit.cyl(0.13, 0.15, h, 8, x + s * w / 2, h / 2, z, 0, 0, 0, false))
	g.append(Kit.box(w + 0.6, 0.18, 0.18, x, h - 0.6, z))
	g.append(Kit.box(w + 0.3, 0.14, 0.14, x, h - 1.4, z))
	var n := roundi(w / 0.3)
	for i in n + 1:
		var px := x - w / 2 + w * i / n
		g.append(Kit.box(0.06, 1.4 if i % 2 == 0 else 1.2, 0.06, px, h - 0.6 + (0.1 if i % 2 == 0 else 0.0) - 0.0, z))
	b.add("flat", pnt(Kit.merge(g), DAN_R, 0.0), 0.015)
	var tg := Kit.cyl(0.32, 0.32, 0.06, 12, x, h - 0.05, z, PI / 2, 0, 0)
	b.add("flat", pnt(tg, [0x3c5f86, 0xa3503a]), 0.01)
	for s in [-1, 1]:
		b.add("stone", pnt(Kit.box(0.5, 0.35, 0.5, x + s * w / 2, 0.17, z), STONE_L), 0.015)

# 흙담(낮은 유 壝): 기와 없는 흙돌담. 꼭짓점 목록 닫힘 + 틈
static func low_wall_loop(b, pts: Array, gaps: Array, h: float, rng: Kit.Rng, th := 0.6) -> Array:
	var cols := []
	var n := pts.size()
	for i in n:
		var a: Vector2 = pts[i]; var c: Vector2 = pts[(i + 1) % n]
		var L := a.distance_to(c); var dir := (c - a) / L
		var cuts := []
		for g in gaps:
			var gp := Vector2(g[0], g[1]); var t := (gp - a).dot(dir)
			if absf((gp - a).cross(dir)) < 1.0 and t > 0 and t < L: cuts.append([t - g[2], t + g[2]])
		var s0 := 0.0
		var spans := []
		for cu in cuts:
			spans.append([s0, cu[0]]); s0 = cu[1]
		spans.append([s0, L])
		for sp in spans:
			if sp[1] - sp[0] < 0.3: continue
			var p0: Vector2 = a + dir * float(sp[0]); var p1: Vector2 = a + dir * float(sp[1])
			tile_wall(b, p0.x, p0.y, p1.x, p1.y, h, rng, th, 0.5)
			cols.append(wall_collider(p0.x, p0.y, p1.x, p1.y, th + 0.1))
	return cols
