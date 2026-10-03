# 대표 도시 랜드마크 공용(경주·강릉·제주·한양·황주·평양·함흥): 누정(pavilion)·난간·중층 차양 지붕(skirt)·중층 건물(jungcheung)·
# 월대(돌난간)·행랑(긴 줄)·비석·바위 덩이·굴 입구·현판. _common.gd의 hall()을 그대로 쓴다.
extends RefCounted

const Co = preload("res://kit/landmark/_common.gd")
const Roof = preload("res://kit/landmark/_roof.gd")

const BASALT := [0x5a5650, 0x3a3733]       # 제주 현무암
const BASALT_L := [0x6e6a62, 0x4a4640]
const EARTH := [0x9a8a64, 0x7a6c4c]        # 토성 흙
const GRASS := [0x8a9a5a, 0x6a7a42]
const FADED_R := [0x8a6a58, 0x6e5446]       # 퇴락한 단청(붉은 기둥이 바램)
const FADED_G := [0x7a8478, 0x5e665c]

# 현판(검은 판 + 흰 글씨 자리)
static func plaque(b, x: float, y: float, z: float, w := 2.2, h := 0.75) -> void:
	b.add("wood", Co.pnt(Kit.box(w, h, 0.1, x, y, z), [0x3a2c22, 0x2c2018]), 0.012)
	b.add("flat", Co.pnt(Kit.box(w * 0.8, h * 0.55, 0.04, x, y, z + 0.06), [0xe8dcb8]), 0.0)

# 계자난간: 사각 둘레(hw, hd), 높이 y(마루 면), gaps = [[변 "S"|"N"|"E"|"W", 중심 오프셋, 반폭]]
static func railing(b, hw: float, hd: float, y: float, cx := 0.0, cz := 0.0, gaps := [], cols := Co.DAN_R) -> void:
	var rg := []
	var edges := { S = [Vector2(-hw, hd), Vector2(hw, hd)], N = [Vector2(hw, -hd), Vector2(-hw, -hd)], E = [Vector2(hw, hd), Vector2(hw, -hd)], W = [Vector2(-hw, -hd), Vector2(-hw, hd)] }
	for k in edges:
		var a: Vector2 = edges[k][0]; var c: Vector2 = edges[k][1]
		var L := a.distance_to(c); var dir := (c - a) / L
		var spans := [[0.0, L]]
		for g in gaps:
			if g[0] != k: continue
			var t0: float = L / 2 + float(g[1]) - float(g[2]); var t1: float = L / 2 + float(g[1]) + float(g[2])
			var ns := []
			for sp in spans:
				if t1 <= sp[0] or t0 >= sp[1]: ns.append(sp); continue
				if t0 > sp[0]: ns.append([sp[0], t0])
				if t1 < sp[1]: ns.append([t1, sp[1]])
			spans = ns
		for sp in spans:
			var p0: Vector2 = a + dir * float(sp[0]); var p1: Vector2 = a + dir * float(sp[1])
			var m := (p0 + p1) / 2; var l := p0.distance_to(p1)
			if l < 0.2: continue
			var ax := absf(dir.x) > 0.5
			var sx := l if ax else 0.08; var sz := 0.08 if ax else l
			rg.append(Kit.box(sx, 0.08, sz, cx + m.x, y + 0.85, cz + m.y))
			rg.append(Kit.box(sx if ax else 0.12, 0.12, 0.12 if ax else sz, cx + m.x, y + 0.1, cz + m.y))
			rg.append(Kit.box(sx, 0.05, sz, cx + m.x, y + 0.45, cz + m.y))
			var n := maxi(1, roundi(l / 0.9))
			for i in n + 1:
				var p := p0.lerp(p1, float(i) / n)
				rg.append(Kit.box(0.07, 0.75, 0.07, cx + p.x, y + 0.47, cz + p.y))
	b.add("wood", Co.pnt(Kit.merge(rg), cols, 0.0), 0.012)

# 돌난간(월대·다리): a→b 선 위 높이 y, 기둥 간격 step
static func stone_rail(b, rng: Kit.Rng, a: Vector2, c: Vector2, y: float, step := 2.2, hgt := 0.8) -> void:
	var L := a.distance_to(c)
	if L < 0.3: return
	var n := maxi(1, roundi(L / step))
	var g := []
	for i in n + 1:
		var p := a.lerp(c, float(i) / n)
		g.append(Kit.box(0.2, hgt + 0.15, 0.2, p.x, y + (hgt + 0.15) / 2, p.y))
	var ang := atan2(c.y - a.y, c.x - a.x)
	var m := (a + c) / 2
	g.append(Kit.xf(Kit.box(L, 0.12, 0.14), m.x, y + hgt - 0.05, m.y, 0, -ang))
	g.append(Kit.xf(Kit.box(L, 0.3, 0.1), m.x, y + 0.2, m.y, 0, -ang))
	b.add("stone", Co.pnt(Kit.merge(g), [0xc8c2b4, 0xa49e90], 0.04, rng), 0.012)

# 누정(누각·정자): 장초석+누하주 위 마루(F) + 사방 트인 칸 + 계자난간 + 지붕. o: hall() 옵션 + under("stone"|"wood"|"none"), rail(true), stair(true)
static func pavilion(b, r, o: Dictionary, rng: Kit.Rng) -> Dictionary:
	var bays: Array = o.bays
	var D: float = o.depth
	var dbays: int = o.get("dbays", 2)
	var F: float = o.get("F", 2.4)
	var fronts := []
	for i in bays.size(): fronts.append("none")
	var ho := o.duplicate()
	ho.fronts = fronts; ho.enclose = false; ho.back = "none"; ho.base = false; ho.floor = false; ho.F = F
	var info := Co.hall(b, r, ho, rng)
	var W: float = info.W
	var cx: float = o.get("cx", 0.0); var cz: float = o.get("cz", 0.0)
	# 낮은 기단
	if o.get("plinth", true):
		b.add("stone", Co.pnt(Kit.box(W + 2.0, 0.4, D + 2.0, cx, 0.15, cz), [0xaaa498, 0x7b766c], 0.05, rng), 0.03)
	# 누하주
	var under: String = o.get("under", "wood")
	if F > 0.9 and under != "none":
		var colx := [cx - W / 2]
		for w in bays: colx.append(colx[-1] + w)
		var stones := []; var posts := []
		var sh: float = minf(1.1, F * 0.45) if under == "wood" else F - 0.2
		for x in colx:
			for j in dbays + 1:
				var z: float = cz - D / 2 + D * j / dbays
				stones.append(Kit.cyl(0.26, 0.32, sh, 8 if under == "wood" else 4, x, 0.35 + sh / 2 - 0.15, z, 0, 0 if under == "wood" else PI / 4, 0, false))
				if under == "wood":
					posts.append(Kit.cyl(0.22, 0.23, F - sh - 0.2, 6, x, sh + 0.2 + (F - sh - 0.2) / 2, z, 0, 0, 0, false))
		b.add("stone", Co.pnt(Kit.merge(stones), Co.STONE_L, 0.05, rng), 0.02)
		if not posts.is_empty(): b.add("flat", Co.pnt(Kit.merge(posts), o.get("col_color", Co.DAN_R), 0.0), 0.02)
	var ov: float = o.get("overhang", 0.6)
	b.add("wood", Co.pnt(Kit.box(W + ov * 2, 0.22, D + ov * 2, cx, F - 0.11, cz), Co.WOOD_L, 0.03, rng), 0.02)
	if F > 0.9:
		b.add("flat", Co.pnt(Kit.box(W + ov * 2 + 0.1, 0.16, D + ov * 2 + 0.1, cx, F - 0.28, cz), o.get("band", Co.DAN_G), 0.0), 0.012)
	if o.get("rail", true) and F > 0.9:
		railing(b, W / 2 + ov - 0.05, D / 2 + ov - 0.05, F, cx, cz, o.get("rail_gaps", [["N", 0.0, 0.8]]), o.get("rail_color", Co.DAN_R))
	if o.get("stair", true) and F > 0.9:
		# 뒤(북) 가운데 나무 계단
		var n := maxi(3, roundi(F / 0.25))
		var sg := []
		for k in n:
			var yy := F * (k + 1) / n
			sg.append(Kit.box(1.4, 0.08, 0.32, cx, yy - 0.04, cz - D / 2 - ov - (n - 1 - k) * 0.3 - 0.15))
		sg.append(Kit.xf(Kit.box(0.1, 0.2, n * 0.3 + 0.4), cx - 0.72, F / 2, cz - D / 2 - ov - n * 0.15, atan2(F, n * 0.3), 0, 0))
		sg.append(Kit.xf(Kit.box(0.1, 0.2, n * 0.3 + 0.4), cx + 0.72, F / 2, cz - D / 2 - ov - n * 0.15, atan2(F, n * 0.3), 0, 0))
		b.add("wood", Co.pnt(Kit.merge(sg), Co.WOOD, 0.03, rng), 0.012)
	info.F = F
	return info

# 차양 지붕(중층 건물의 아래 지붕 띠): 안 사각(hwi,hdi, 높이 yi)에서 바깥 사각(hwo,hdo, 높이 yo)으로 처지는 고리. 귀가 lift만큼 들림
static func skirt(r, hwi: float, hdi: float, yi: float, hwo: float, hdo: float, yo: float, lift := 0.5, cx := 0.0, cz := 0.0, n := 10, sag := 0.25, thick := 0.22) -> void:
	var g := Kit.Geo.new(); var u := Kit.Geo.new(); var e := Kit.Geo.new()
	var c_top := Kit.hex(Roof.C_TOP); var c_low := Kit.hex(Roof.C_LOW); var c_bot := Kit.hex(Roof.C_BOT)
	var outer := func(t: float, side: int) -> Vector3:
		# side 0:S 1:E 2:N 3:W, t 0..1 반시계(위에서 볼 때) 순서
		var p: Vector2
		match side:
			0: p = Vector2(lerpf(-hwo, hwo, t), hdo)
			1: p = Vector2(hwo, lerpf(hdo, -hdo, t))
			2: p = Vector2(lerpf(hwo, -hwo, t), -hdo)
			_: p = Vector2(-hwo, lerpf(-hdo, hdo, t))
		var lx := absf(p.x) / hwo; var lz := absf(p.y) / hdo
		var y := yo + lift * maxf(pow(lx, 3) * Roof.smoothstep(0.6, 1.0, lz), pow(lz, 3) * Roof.smoothstep(0.6, 1.0, lx))
		return Vector3(cx + p.x, y, cz + p.y)
	var inner := func(t: float, side: int) -> Vector3:
		var p: Vector2
		match side:
			0: p = Vector2(lerpf(-hwi, hwi, t), hdi)
			1: p = Vector2(hwi, lerpf(hdi, -hdi, t))
			2: p = Vector2(lerpf(hwi, -hwi, t), -hdi)
			_: p = Vector2(-hwi, lerpf(-hdi, hdi, t))
		return Vector3(cx + p.x, yi, cz + p.y)
	var dirs := [Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(-1, 0, 0)]
	for side in 4:
		var nn := Vector3(dirs[side]) + Vector3(0, 1.5, 0)
		for i in n:
			var t0 := float(i) / n; var t1 := float(i + 1) / n
			var o0: Vector3 = outer.call(t0, side); var o1: Vector3 = outer.call(t1, side)
			var i0: Vector3 = inner.call(t0, side); var i1: Vector3 = inner.call(t1, side)
			var m0 := (o0 + i0) / 2 - Vector3(0, sag, 0); var m1 := (o1 + i1) / 2 - Vector3(0, sag, 0)
			var base := g.size()
			Roof.quad_facing(g, o0, o1, m1, m0, nn, Vector2(t0 * 4, 0), Vector2(t1 * 4, 0), Vector2(t1 * 4, 0.5), Vector2(t0 * 4, 0.5))
			Roof.quad_facing(g, m0, m1, i1, i0, nn, Vector2(t0 * 4, 0.5), Vector2(t1 * 4, 0.5), Vector2(t1 * 4, 1), Vector2(t0 * 4, 1))
			for q in range(base, g.size()): g.col[q] = c_low.lerp(c_top, clampf((g.pos[q].y - yo) / maxf(yi - yo, 0.1), 0, 1))
			var dn := Vector3(0, -thick, 0)
			var bb := u.size()
			Roof.quad_facing(u, o0 + dn, o1 + dn, i1 + dn, i0 + dn, Vector3(0, -1, 0))
			for q in range(bb, u.size()): u.col[q] = c_bot
			Roof.quad_facing(e, o0 + dn, o1 + dn, o1, o0, dirs[side])
	r.add("tile", g, 0.05)
	r.add("flat", u, 0.0)
	r.add("makse", e, 0.0)
	# 귀 추녀마루
	var rid := []
	for side in 4:
		var oc: Vector3 = outer.call(0.0, side); var ic: Vector3 = inner.call(0.0, side)
		var m := (oc + ic) / 2 - Vector3(0, sag * 0.6, 0)
		rid.append(Kit.limb(ic + Vector3(0, 0.1, 0), m + Vector3(0, 0.12, 0), 0.13, 0.12, 4))
		rid.append(Kit.limb(m + Vector3(0, 0.12, 0), oc + Vector3(0, 0.14, 0), 0.12, 0.1, 4))
	r.add("flat", Kit.paint(Kit.merge(rid), Kit.hex(Roof.RIDGE[0]), Kit.hex(Roof.RIDGE[1]), 0.02), 0.0)

# 중층 건물(근정전·인정전·숭례문 문루 등): 아래층 hall(지붕 없음) + 차양 + 위층 hall(지붕).
# o: hall 옵션(아래층) + up_inset(위층이 안으로 들어간 칸 수, 0이면 같은 평면), up_H(위층 기둥 높이), up_roof("paljak"|"ujin"), up_fronts
static func jungcheung(b, r, o: Dictionary, rng: Kit.Rng) -> Dictionary:
	var lo := o.duplicate()
	lo.roof = "none"
	var li := Co.hall(b, r, lo, rng)
	var bays: Array = o.bays
	var inset: int = o.get("up_inset", 0)
	var ix: int = o.get("up_inset_x", inset); var iz: int = o.get("up_inset_z", inset)
	var ub := bays.slice(ix, bays.size() - ix)
	var D: float = o.depth
	var dbays: int = o.get("dbays", 2)
	var ud: float = D - 2.0 * iz * (D / dbays) if iz > 0 else D
	var cx: float = o.get("cx", 0.0); var cz: float = o.get("cz", 0.0)
	var W: float = li.W
	var UW := 0.0
	for w in ub: UW += w
	var yo: float = li.eave
	var yi: float = li.top + o.get("skirt_rise", 1.6)
	var ox: float = o.get("ox", 1.7); var oz: float = o.get("oz", 1.55)
	skirt(r, UW / 2 + 0.15, ud / 2 + 0.15, yi, W / 2 + ox, D / 2 + oz, yo, o.get("lift", 0.6) * 0.8, cx, cz, 10, 0.2)
	var uo := o.duplicate()
	uo.bays = ub; uo.depth = ud; uo.dbays = maxi(1, dbays - 2 * iz)
	uo.F = yi - 0.25; uo.H = o.get("up_H", o.get("H", 3.0) * 0.75); uo.base = false; uo.floor = false
	uo.fronts = o.get("up_fronts", []); uo.roof = o.get("up_roof", "paljak")
	uo.enclose = o.get("up_enclose", true); uo.back = "wall" if uo.enclose else "none"; uo.sides = uo.back
	uo.side_window = false
	uo.rise = o.get("up_rise", 0.62 * (ud / 2 + oz))
	var ui := Co.hall(b, r, uo, rng)
	li.ridge_y = ui.ridge_y; li.up = ui; li.up_F = uo.F
	return li

# 월대(궁궐·종묘 앞 돌 단): 너비 w, 깊이 d, 높이 h, 앞 계단(가운데 + 양옆), 돌난간(rail)
static func woldae(b, rng: Kit.Rng, w: float, d: float, h: float, cx := 0.0, cz := 0.0, rail := true, steps := [-3.0, 0.0, 3.0]) -> void:
	Co.platform(b, w, d, h, rng, cz, steps, 2.2, cx)
	b.add("stone", Co.pnt(Kit.box(w - 0.4, 0.06, d - 0.4, cx, h + 0.02, cz), [0xc2bcae, 0xa8a294], 0.05, rng), 0.0)
	if rail:
		var hw := w / 2 - 0.15; var hd := d / 2 - 0.15
		var gx := []
		for s in steps: gx.append(float(s))
		gx.sort()
		# 앞 변: 계단 자리마다 끊음
		var x := -hw
		for s in gx:
			stone_rail(b, rng, Vector2(cx + x, cz + hd), Vector2(cx + s - 1.3, cz + hd), h)
			x = s + 1.3
		stone_rail(b, rng, Vector2(cx + x, cz + hd), Vector2(cx + hw, cz + hd), h)
		stone_rail(b, rng, Vector2(cx - hw, cz + hd), Vector2(cx - hw, cz - hd), h)
		stone_rail(b, rng, Vector2(cx + hw, cz + hd), Vector2(cx + hw, cz - hd), h)

# 비석: 받침(귀부 간략 or 네모 대석) + 비신 + 머릿돌. x,z 중심, 비신 높이 h
static func stele(b, rng: Kit.Rng, x: float, z: float, h := 1.8, w := 0.7, turtle := false, ry := 0.0) -> void:
	var g := []
	if turtle:
		var tb := Kit.lump(1.0, 1, rng, 0.08, 1.0); Kit.xf(tb, 0, 0.35, 0, 0, 0, 0, 0.9, 0.42, 1.3); g.append(tb)
		g.append(Kit.xf(Kit.lump(1.0, 0, rng, 0.05, 1.0), 0, 0.45, 1.25, 0, 0, 0, 0.32, 0.26, 0.35))
	else:
		g.append(Kit.box(w * 1.7, 0.45, w * 1.1, 0, 0.22, 0))
	var by := 0.7 if turtle else 0.45
	g.append(Kit.box(w, h, w * 0.3, 0, by + h / 2, 0))
	var cap := Kit.box(w * 1.3, 0.38, w * 0.55, 0, by + h + 0.19, 0)
	g.append(cap)
	g.append(Kit.xf(Kit.box(w * 1.1, 0.16, w * 0.4), 0, by + h + 0.45, 0))
	var gg := Kit.merge(g)
	Kit.xf(gg, x, 0, z, 0, ry)
	b.add("stone", Co.pnt(gg, [0xb8b2a4, 0x8d877a], 0.05, rng), 0.02)
	var face := Co.vplane(w * 0.55, h * 0.75, 0, by + h * 0.52, w * 0.15 + 0.012)
	Kit.xf(face, x, 0, z, 0, ry)
	b.add("flat", Co.pnt(face, [0x8a857a]), 0.0)

# 바위 덩이(여러 lump): 중심 x,z, 크기 sx,sy,sz
static func rock(b, rng: Kit.Rng, x: float, z: float, sx: float, sy: float, sz: float, cols := [0xb8b2a4, 0x7e786c], detail := 1, rough := 0.28, ry := 0.0) -> Kit.Geo:
	var g := Kit.lump(1.0, detail, rng, rough, 1.0)
	Kit.xf(g, x, sy * 0.45, z, 0, ry, 0, sx, sy, sz)
	for i in g.pos.size():
		if g.pos[i].y < -0.4: g.pos[i].y = -0.4
	b.add("rock", Co.pnt(g, cols, 0.08, rng), 0.04)
	return g

# 굴 입구: 바위 둔덕에 어두운 아치 구멍(폭 w, 높이 h)이 +z를 봄. 반환 입구 중심 z
static func cave_mouth(b, rng: Kit.Rng, w: float, h: float, cols := [0xa8a294, 0x6e695f], mound := Vector3(10, 5, 8)) -> float:
	var m := Kit.lump(1.0, 2, rng, 0.22, 1.0)
	Kit.xf(m, 0, mound.y * 0.35, -mound.z * 0.55, 0, 0, 0, mound.x * 0.5, mound.y, mound.z * 0.5)
	for i in m.pos.size():
		if m.pos[i].y < -0.3: m.pos[i].y = -0.3
	b.add("rock", Co.pnt(m, cols, 0.08, rng), 0.04)
	# 입구 앞 깎인 면(바위 판) + 어두운 아치
	var fz: float = 0.6
	var poly := PackedVector2Array()
	var nn := 10
	for i in nn + 1:
		var a := PI * i / nn
		poly.append(Vector2(cos(a) * w * 1.25, h * 0.55 + sin(a) * h * 0.85))
	poly.append(Vector2(-w * 1.25, -0.3)); poly.append(Vector2(w * 1.25, -0.3))
	var face := Co.extrude_xy(poly, 2.4, fz - 1.2)
	b.add("rock", Co.pnt(face, cols, 0.06, rng), 0.03)
	var hole := Kit.Geo.new()
	var pts := []
	for i in nn + 1:
		var a := PI * i / nn
		pts.append(Vector3(cos(a) * w / 2, h * 0.6 + sin(a) * h * 0.4, fz + 0.02))
	var c0 := Vector3(0, h * 0.35, fz + 0.02)
	for i in nn:
		Roof.tri_facing(hole, c0, pts[i], pts[i + 1], Vector3(0, 0, 1))
	Roof.quad_facing(hole, Vector3(-w / 2, 0.02, fz + 0.02), Vector3(w / 2, 0.02, fz + 0.02), Vector3(w / 2, h * 0.6, fz + 0.02), Vector3(-w / 2, h * 0.6, fz + 0.02), Vector3(0, 0, 1))
	b.add("flat", Co.pnt(hole, [0x1e1a17, 0x0e0c0a]), 0.0)
	# 입구 바닥 흙·돌 부스러기
	for k in 5:
		var gg := Kit.lump(rng.between(0.2, 0.45), 0, rng, 0.3, 0.7)
		Kit.xf(gg, rng.between(-w, w), 0.1, fz + rng.between(0.4, 1.6))
		b.add("rock", Co.pnt(gg, cols, 0.08, rng), 0.02)
	return fz

# 긴 줄 행랑(시전·육조 행랑·궁궐 행각): n칸 × bay, 깊이 d, 맞배. fronts 종류 하나(kind)로 채움
static func haenglang(b, r, rng: Kit.Rng, n: int, bay: float, d: float, kind := "door", cx := 0.0, cz := 0.0, H := 2.6, F := 0.5, opts := {}) -> Dictionary:
	var bays := []; var fr := []
	for i in n:
		bays.append(bay)
		fr.append(kind if not (opts.has("gate_at") and i == int(opts.gate_at)) else "gate")
	var o := { bays = bays, depth = d, dbays = 1, F = F, H = H, fronts = fr, roof = "matbae", ox = 0.6, oz = 1.1, rise = d * 0.42 + 0.5,
		lift = 0.25, bracket = "none", col_r = 0.14, cx = cx, cz = cz, roof_nx = maxi(6, n * 2), roof_nz = 6, side_window = false,
		col_color = opts.get("col_color", Co.WOOD), band = opts.get("band", [0x6b5a44, 0x5a4a36]), steps = [], base_margin = 0.35 }
	for k in opts: o[k] = opts[k]
	return Co.hall(b, r, o, rng)

# 기본값 + params 합치기(감싸기 모델용)
static func merged(defaults: Dictionary, params: Dictionary) -> Dictionary:
	var p := defaults.duplicate(true)
	for k in params: p[k] = params[k]
	return p

# 배치형 마무리: pieces → assemble + footprint
static func composite(name: String, pieces: Array, foot: Vector2, occluder := true) -> Dictionary:
	var r := Co.assemble(name, pieces)
	r.occluder = occluder
	r.footprint = foot
	r.pieces = pieces
	return r

# 제주 현무암 돌담(막쌓기, 틈 보이게): a→c, 높이 h, 두께 th. 반환 충돌 상자
static func basalt_wall(b, rng: Kit.Rng, a: Vector2, c: Vector2, h := 1.6, th := 0.6) -> Dictionary:
	var L := a.distance_to(c)
	var dir := (c - a) / maxf(L, 0.01)
	var ang := atan2(dir.y, dir.x)
	# 속 채움(어두운 몸, 먹선) + 겉 돌(먹선 없이, 들쭉날쭉)
	var m := (a + c) / 2
	b.add("stone", Co.pnt(Kit.xf(Kit.box(L, h * 0.96, th * 0.7), m.x, h * 0.48, m.y, 0, -ang), [0x2e2b28]), 0.02)
	var g := []
	var rows := maxi(2, roundi(h / 0.55))
	for rr in rows:
		var y0 := h * rr / rows
		var x := -rng.next() * 0.4
		while x < L:
			var w := rng.between(0.6, 1.1)
			var hh := h / rows * rng.between(0.85, 1.12)
			var ww := minf(w, L - x) - 0.06
			if ww > 0.15:
				var s := Kit.box(ww, hh, th * rng.between(0.85, 1.0))
				Kit.xf(s, 0, 0, 0, rng.between(-0.12, 0.12), rng.between(-0.08, 0.08), rng.between(-0.1, 0.1))
				var p := a + dir * maxf(0.0, x + w / 2)
				Kit.xf(s, p.x, y0 + hh / 2, p.y, 0, -ang)
				g.append(s)
			x += w
	b.add("stone", Co.pnt(Kit.merge(g), BASALT, 0.14, rng), 0.0)
	return Co.wall_collider(a.x, a.y, c.x, c.y, th + 0.1)

static func basalt_loop(b, rng: Kit.Rng, pts: Array, gaps: Array, h := 1.6, th := 0.6) -> Array:
	var cols := []
	var n := pts.size()
	for i in n:
		var a: Vector2 = pts[i]; var c: Vector2 = pts[(i + 1) % n]
		var L := a.distance_to(c); var dir := (c - a) / L
		var cuts := []
		for gp in gaps:
			var q := Vector2(gp[0], gp[1]); var t := (q - a).dot(dir)
			if absf((q - a).cross(dir)) < 1.0 and t > 0 and t < L: cuts.append([t - float(gp[2]), t + float(gp[2])])
		var s0 := 0.0
		for cu in cuts:
			if cu[0] - s0 > 0.3: cols.append(basalt_wall(b, rng, a + dir * s0, a + dir * float(cu[0]), h, th))
			s0 = cu[1]
		if L - s0 > 0.3: cols.append(basalt_wall(b, rng, a + dir * s0, c, h, th))
	return cols
