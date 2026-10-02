# 읍성 성곽 공용: 돌 성벽 몸체(안팎 판석 협축, 바깥 약간 퇴물림), 면석 줄, 여장(성가퀴) + 총안, 홍예.
# 남원읍성: 평지 방형 석성, 판상할석 협축, 높이 약 4m (위키백과/사적 지정 설명). 여장 1,016개(기록).
extends RefCounted

const Co = preload("res://kit/landmark/_common.gd")
const Roof = preload("res://kit/landmark/_roof.gd")

const H := 4.0        # 성벽 높이(바깥 지면~성상로)
const T := 4.6        # 성벽 윗너비(가설)
const SINK := 1.2     # 기울어진 땅을 위해 땅속으로 더 내린 깊이
const PARA_H := 1.35  # 여장 높이
const PARA_T := 0.65
const PARA_L := 3.2   # 여장 한 타(垛) 길이
const GAP := 0.32     # 타구(여장 사이 틈)

# 면석 줄: a→b 선분(xz), y0..y1, 바깥 방향 out(xz 단위), 퇴물림 bat(m, 아래가 더 나옴)
static func stone_face(b, rng: Kit.Rng, a: Vector2, bp: Vector2, y0: float, y1: float, out: Vector2, bat := 0.0, row_h := 0.55) -> void:
	var len := a.distance_to(bp)
	var dir := (bp - a) / len
	var g := Kit.Geo.new()
	var rows := maxi(1, roundi((y1 - y0) / row_h))
	var o3 := Vector3(out.x, 0, out.y)
	var cols := []
	for r in rows:
		var ya := y0 + (y1 - y0) * r / rows; var yb := y0 + (y1 - y0) * (r + 1) / rows - 0.05
		var off := 0.03 + bat * (1.0 - (ya - y0) / maxf(y1 - y0, 0.01))
		var off2 := 0.03 + bat * (1.0 - (yb - y0) / maxf(y1 - y0, 0.01))
		var x := rng.next() * 0.6
		var first := true
		while x < len - 0.05:
			var w: float = rng.between(0.8, 1.7) * (1.0 if rows < 12 else 1.0)
			var xa := 0.0 if first else x
			var xb := minf(len, x + w)
			first = false
			var pa := a + dir * (xa + 0.03); var pb := a + dir * (xb - 0.03)
			var A := Vector3(pa.x, ya, pa.y) + o3 * off; var B := Vector3(pb.x, ya, pb.y) + o3 * off
			var Cc := Vector3(pb.x, yb, pb.y) + o3 * off2; var Dd := Vector3(pa.x, yb, pa.y) + o3 * off2
			var base := g.size()
			Roof.quad_facing(g, A, B, Cc, Dd, o3 + Vector3(0, 0.0, 0))
			var tone := rng.between(-0.05, 0.05)
			var top := Kit.hex(0xbdb8aa); var bot := Kit.hex(0x8f8a7e)
			for q in range(base, g.size()):
				var t := clampf((g.pos[q].y - y0) / maxf(y1 - y0, 0.01), 0, 1)
				var cc := bot.lerp(top, t)
				g.col[q] = Color(cc.r + tone, cc.g + tone, cc.b + tone * 0.8)
			x = xb
	b.add("stone", g, 0.0)

# 성벽 몸체 상자(퇴물림): 길이 방향 a→b, 바깥 out, 윗너비 t, 높이 h. 바깥 면만 아래로 bat만큼 더 나옴
static func body(b, rng: Kit.Rng, a: Vector2, bp: Vector2, out: Vector2, t: float, h: float, bat := 0.35, cols := Co.SEONG) -> void:
	var dir := (bp - a).normalized()
	var o3 := Vector3(out.x, 0, out.y)
	var i3 := -o3
	var A := Vector3(a.x, 0, a.y); var B := Vector3(bp.x, 0, bp.y)
	var y0 := -SINK
	# 바깥 아래/위, 안 아래/위
	var ob0 := A + o3 * (t / 2 + bat); var ob1 := B + o3 * (t / 2 + bat)
	var ot0 := A + o3 * (t / 2); var ot1 := B + o3 * (t / 2)
	var ib0 := A + i3 * (t / 2 + 0.1); var ib1 := B + i3 * (t / 2 + 0.1)
	var it0 := A + i3 * (t / 2); var it1 := B + i3 * (t / 2)
	var up := Vector3.UP
	var g := Kit.Geo.new()
	var yb := Vector3(0, y0, 0); var yt := Vector3(0, h, 0)
	Roof.quad_facing(g, ob0 + yb, ob1 + yb, ot1 + yt, ot0 + yt, o3)       # 바깥
	Roof.quad_facing(g, ib1 + yb, ib0 + yb, it0 + yt, it1 + yt, i3)       # 안
	Roof.quad_facing(g, ot0 + yt, ot1 + yt, it1 + yt, it0 + yt, up)       # 위(성상로)
	var d3 := Vector3(dir.x, 0, dir.y)
	Roof.quad_facing(g, ob0 + yb, ot0 + yt, it0 + yt, ib0 + yb, -d3)      # 끝
	Roof.quad_facing(g, ob1 + yb, ot1 + yt, it1 + yt, ib1 + yb, d3)
	b.add("stone", Co.pnt(g, cols, 0.03, rng), 0.035)
	# 성상로 흙 다짐(위 면 살짝 흙빛)
	var w := Kit.Geo.new()
	var e := 0.25
	Roof.quad_facing(w, ot0 + yt + i3 * e + Vector3(0, 0.02, 0), ot1 + yt + i3 * e + Vector3(0, 0.02, 0), it1 + yt + o3 * 0.15 + Vector3(0, 0.02, 0), it0 + yt + o3 * 0.15 + Vector3(0, 0.02, 0), up)
	b.add("mud", Co.pnt(w, [0xa59a82, 0xa59a82], 0.03, rng), 0.0)

# 여장: a→b 선 위(y), 바깥 out. 타 사이 타구, 타마다 총안 3(원총안 1·근총안 2), 덮개돌
static func parapet(b, rng: Kit.Rng, a: Vector2, bp: Vector2, y: float, out: Vector2, skip_ends := false) -> void:
	var len := a.distance_to(bp)
	var dir := (bp - a) / len
	var n := maxi(1, roundi(len / (PARA_L + GAP)))
	var seg := len / n
	var body_g := []; var cap_g := []; var holes := Kit.Geo.new()
	var ang := atan2(dir.y, dir.x)
	var o3 := Vector3(out.x, 0, out.y)
	for i in n:
		var l := seg - GAP
		var c := a + dir * (seg * (i + 0.5))
		var g := Kit.box(l, PARA_H, PARA_T, 0, 0, 0)
		var xfm := Transform3D(Basis(Vector3.UP, -ang), Vector3(c.x, y + PARA_H / 2, c.y))
		# 바깥 out과 박스 로컬 +z 맞추기: 로컬 +z는 회전 후 (−sin(−ang)...) → 방향 확인해 뒤집기
		var lz := xfm.basis * Vector3(0, 0, 1)
		if lz.dot(o3) < 0: xfm.basis = xfm.basis * Basis(Vector3.UP, PI)
		body_g.append(Kit.apply(g, xfm))
		cap_g.append(Kit.apply(Kit.box(l + 0.12, 0.14, PARA_T + 0.16, 0, PARA_H / 2 + 0.07, 0), xfm))
		# 총안: 바깥 면에 어두운 네모(가운데 근총안 한 개는 아래로 기울어 낮게)
		for k in 3:
			var hx := (k - 1) * l * 0.3
			var hy := -0.05 if k != 1 else -0.35
			var q := Co.vplane(0.2, 0.2, hx, hy, PARA_T / 2 + 0.012)
			holes = Kit.merge([holes, Kit.apply(q, xfm)])
	b.add("stone", Co.pnt(Kit.merge(body_g), [0xbab2a0, 0xa39b8a], 0.04, rng), 0.03)
	b.add("stone", Co.pnt(Kit.merge(cap_g), [0x9a9488, 0x847e72], 0.03, rng), 0.02)
	b.add("flat", Co.pnt(holes, [0x2c2520]), 0.0)

# 성벽 한 구간(로컬: x축 방향, 바깥 +z, 중심 원점) — 몸체 + 안팎 면석 + 바깥 여장
static func wall_run(b, rng: Kit.Rng, x0: float, x1: float, z := 0.0, h := H, t := T, para := true) -> void:
	var a := Vector2(x0, z); var bp := Vector2(x1, z)
	body(b, rng, a, bp, Vector2(0, 1), t, h)
	stone_face(b, rng, Vector2(x0, z + t / 2), Vector2(x1, z + t / 2), 0.0, h, Vector2(0, 1), 0.35)
	stone_face(b, rng, Vector2(x1, z - t / 2), Vector2(x0, z - t / 2), 0.0, h, Vector2(0, -1), 0.1)
	if para:
		parapet(b, rng, Vector2(x0, z + t / 2 - PARA_T / 2), Vector2(x1, z + t / 2 - PARA_T / 2), h, Vector2(0, 1))

# 홍예 문 구멍이 난 육축 모양 2D(xy): 너비 w, 높이 h, 문 너비 aw, 홍예 시작 높이 sp
static func arch_poly(w: float, h: float, aw: float, sp: float, y0 := -SINK, n := 10) -> PackedVector2Array:
	var p := PackedVector2Array()
	var r := aw / 2
	p.append(Vector2(-w / 2, y0)); p.append(Vector2(-r, y0)); p.append(Vector2(-r, sp))
	for i in range(1, n):
		var a := PI - PI * i / n
		p.append(Vector2(cos(a) * r, sp + sin(a) * r))
	p.append(Vector2(r, sp)); p.append(Vector2(r, y0)); p.append(Vector2(w / 2, y0))
	p.append(Vector2(w / 2, h)); p.append(Vector2(-w / 2, h))
	return p

# 홍예석(아치 둘레 돌) 띠: 바깥 면 z
static func arch_ring(b, rng: Kit.Rng, aw: float, sp: float, z: float, nz := 1.0, n := 11) -> void:
	var r := aw / 2
	var g := []
	for i in n:
		var a := PI * (i + 0.5) / n
		var rr := r + 0.32
		var stone := Kit.box(0.42, 0.62, 0.08)
		Kit.xf(stone, cos(a) * rr, sp + sin(a) * rr, z + nz * 0.04, 0, 0, a - PI / 2)
		g.append(stone)
	b.add("stone", Co.pnt(Kit.merge(g), [0xd0c9b8, 0xb2ab9b], 0.05, rng), 0.012)
