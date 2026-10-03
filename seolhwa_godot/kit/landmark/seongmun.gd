# 읍성 성문 — 홍예문을 낸 육축(석축) + 그 위 문루(단층 팔작, 3×2칸) + (선택) 반원 옹성.
# 남원읍성 4문: 남 완월루(翫月樓)·북 공신루(拱宸樓)·서 망미루(望美樓)·동 향일루(向日樓) (위키백과 '남원읍성').
# 성벽 모듈과 같은 규칙: 로컬 x축이 성벽 방향, 바깥 +z, 원점 = 문 가운데 바닥(성벽 두께 중심).
# 문루 층수(단층)·옹성 모양(반원)·열린 쪽은 가설. params: seed, name("완월루"), width(16), radius(11),
#   open: 옹성 열린 쪽 "east"(로컬 +x) | "west"(로컬 −x) | "front"(정면 가운데) | "none"(옹성 없음). 예전 이름 open_side, ongseong=false도 받는다
extends RefCounted

const Co = preload("res://kit/landmark/_common.gd")
const S = preload("res://kit/landmark/_seong.gd")
const Roof = preload("res://kit/landmark/_roof.gd")
const Hub = preload("res://kit/landmark/_hub.gd")

# 홍예 여러 개(광화문 3홍예)를 낸 육축 2D: 문 중심 xs, 문 너비 aw
static func arches_poly(w: float, h: float, xs: Array, aw: float, sp: float, y0 := -S.SINK, n := 10) -> PackedVector2Array:
	var p := PackedVector2Array()
	var r := aw / 2
	p.append(Vector2(-w / 2, y0))
	for cx in xs:
		var c: float = cx
		p.append(Vector2(c - r, y0)); p.append(Vector2(c - r, sp))
		for i in range(1, n):
			var a := PI - PI * i / n
			p.append(Vector2(c + cos(a) * r, sp + sin(a) * r))
		p.append(Vector2(c + r, sp)); p.append(Vector2(c + r, y0))
	p.append(Vector2(w / 2, y0))
	p.append(Vector2(w / 2, h)); p.append(Vector2(-w / 2, h))
	return p

static func build(params: Dictionary) -> Dictionary:
	var rng := Kit.Rng.new(int(params.get("seed", 1)))
	var Wg: float = float(params.get("width", 16.0))
	var dep: float = float(params.get("depth", S.T + 1.0))
	var Hg: float = float(params.get("height", S.H + 1.0))
	var aw: float = float(params.get("aw", 3.8)); var sp: float = float(params.get("spring", 2.5))
	var xs: Array = params.get("arch_x", [0.0])
	var lu: int = int(params.get("lu", 1))
	var b := Kit.Batch.new(); var roof := Kit.Batch.new()
	# 육축(홍예 구멍)
	var g := Co.extrude_xy(arches_poly(Wg, Hg, xs, aw, sp), dep)
	b.add("stone", Co.pnt(g, Co.SEONG, 0.03, rng), 0.035)
	# 면석(앞·뒤, 아치 양옆)
	for zf in [dep / 2, -dep / 2]:
		var out := Vector2(0, signf(zf))
		var r := aw / 2
		var segs := []
		var x0 := -Wg / 2
		for cxa in xs:
			segs.append([x0, float(cxa) - r - 0.05]); x0 = float(cxa) + r + 0.05
		segs.append([x0, Wg / 2])
		for sg in segs:
			var a := Vector2(sg[0], zf) if zf > 0 else Vector2(sg[1], zf)
			var c := Vector2(sg[1], zf) if zf > 0 else Vector2(sg[0], zf)
			S.stone_face(b, rng, a, c, 0.0, Hg - 0.1, out, 0.0)
			# 홍예 위(문 사이) 면석
		for cxa in xs:
			S.stone_face(b, rng, Vector2(float(cxa) - r, zf) if zf > 0 else Vector2(float(cxa) + r, zf), Vector2(float(cxa) + r, zf) if zf > 0 else Vector2(float(cxa) - r, zf), sp + r + 0.5, Hg - 0.1, out, 0.0)
			_ring(b, rng, aw, sp, zf, signf(zf), float(cxa))
	# 통로 바닥 박석 + 문짝(열림)
	for cxa in xs:
		b.add("stone", Co.pnt(Kit.box(aw - 0.1, 0.06, dep, float(cxa), 0.03, 0), [0xa8a194, 0x958e81], 0.04, rng), 0.0)
		Co.board_doors(b, float(cxa), 0.0, aw - 0.2, sp + aw * 0.24, 0.4, params.get("doors", "open") == "open", [0x6e4a32, 0x553826])
	# 육축 위 여장(바깥 가장자리)
	S.parapet(b, rng, Vector2(-Wg / 2, dep / 2 - S.PARA_T / 2), Vector2(Wg / 2, dep / 2 - S.PARA_T / 2), Hg, Vector2(0, 1))
	# 성상 박석
	b.add("stone", Co.pnt(Kit.box(Wg - 0.2, 0.05, dep - 0.8, 0, Hg + 0.02, -0.3), [0xaaa294], 0.03, rng), 0.0)
	# 문루: 기본 3×2칸 단층 팔작, 사방 트임 + 계자난간. lu=2면 중층(차양 + 위층 판벽), lu=0이면 문루 없음(숙정문)
	var lbays: Array = params.get("lu_bays", [3.6, 4.2, 3.6])
	var ldep: float = float(params.get("lu_depth", 4.4))
	var fr := []
	for i in lbays.size(): fr.append("none")
	var lo := {
		bays = lbays, depth = ldep, dbays = 2, F = Hg + 0.15, H = float(params.get("lu_H", 3.3)), fronts = fr,
		enclose = false, back = "none", base = false, floor = true, roof = str(params.get("lu_roof", "paljak")), ox = 1.6 + ldep * 0.05, oz = 1.5 + ldep * 0.05, rise = 2.2 * ldep / 4.4, lift = 0.65,
		bracket = str(params.get("bracket", "ikgong")), col_r = 0.19 if ldep < 6 else 0.26, cz = -0.5, roof_nx = 24, roof_nz = 14,
	}
	var info := {}
	if lu == 2:
		var uf := []
		for i in lbays.size(): uf.append("board")
		lo.up_fronts = uf; lo.up_H = float(params.get("lu_H", 3.3)) * 0.8; lo.skirt_rise = 1.5; lo.up_roof = lo.roof
		lo.rise = float(params.get("lu_rise", 2.6 * ldep / 4.4)); lo.up_rise = lo.rise
		info = Hub.jungcheung(b, roof, lo, rng)
	elif lu == 1:
		info = Co.hall(b, roof, lo, rng)
	else:
		# 문루 없음: 육축 위 사방 여장만(뒤·옆)
		S.parapet(b, rng, Vector2(Wg / 2, -dep / 2 + S.PARA_T / 2), Vector2(-Wg / 2, -dep / 2 + S.PARA_T / 2), Hg, Vector2(0, -1))
		info = { F = Hg, top = Hg, W = 0.0, z1 = 0.0, z0 = 0.0 }
	var F: float = info.F
	var W: float = info.W
	if lu > 0:
		var rails := []
		for zz in [info.z1, info.z0]:
			rails.append(Kit.box(W, 0.07, 0.07, 0, F + 0.75, zz)); rails.append(Kit.box(W, 0.05, 0.05, 0, F + 0.3, zz))
		for sx in [-1, 1]:
			rails.append(Kit.box(0.07, 0.07, ldep, sx * W / 2, F + 0.75, -0.5)); rails.append(Kit.box(0.05, 0.05, ldep, sx * W / 2, F + 0.3, -0.5))
		b.add("wood", Co.pnt(Kit.merge(rails), Co.WOOD), 0.012)
		b.add("wood", Co.pnt(Kit.box(W + 0.2, 0.14, ldep + 0.2, 0, F - 0.05, -0.5), Co.WOOD_L, 0.03, rng), 0.015)
		# 현판(중층이면 위층에)
		var py: float = (info.up.top - 0.35) if lu == 2 else (info.top - 0.35)
		var pz: float = (info.up.z1 + 0.25) if lu == 2 else (info.z1 + 0.25)
		b.add("wood", Co.pnt(Kit.box(1.9, 0.62 if lu == 1 else 1.4, 0.08, 0, py if lu == 1 else py - 0.4, pz), [0x3a2c22, 0x2c2018]), 0.012)
		b.add("flat", Co.pnt(Kit.box(1.5 if lu == 1 else 0.5, 0.34 if lu == 1 else 1.1, 0.04, 0, py if lu == 1 else py - 0.4, pz + 0.05), [0xe8dcb8]), 0.0)
	else:
		# 현판(육축 홍예 위 돌 판)
		b.add("stone", Co.pnt(Kit.box(1.8, 0.6, 0.06, 0, sp + aw / 2 + 0.75, dep / 2 + 0.03), [0xd0c9b8, 0xb2ab9b]), 0.012)
	var cols := []
	var cx0 := -Wg / 2
	for cxa in xs:
		cols.append({ type = "box", minX = cx0, maxX = float(cxa) - aw / 2, minZ = -dep / 2, maxZ = dep / 2 }); cx0 = float(cxa) + aw / 2
	cols.append({ type = "box", minX = cx0, maxX = Wg / 2, minZ = -dep / 2, maxZ = dep / 2 })
	var fz := dep / 2 + 3.0
	var anchors := { inside = Vector3(0, 0, -dep / 2 - 3.0), passage = Vector3(0, 0, 0), top = Vector3(0, Hg, -0.5), outside = Vector3(0, 0, dep / 2 + 3.0) }
	var lights := [{ x = float(xs[0]) - aw / 2 - 0.6, y = 2.2, z = dep / 2 + 0.3, kind = "torch" }, { x = float(xs[-1]) + aw / 2 + 0.6, y = 2.2, z = dep / 2 + 0.3, kind = "torch" }]
	var foot := Vector2(Wg, dep)
	# 옹성(반원)
	var open: String = str(params.get("open", params.get("open_side", "east")))
	var tt := 3.2
	if not params.get("ongseong", true): open = "none"
	if open != "none":
		var R: float = float(params.get("radius", 11.0))
		var zo := dep / 2 - 0.5
		var east: bool = open == "east"
		var front: bool = open == "front"
		var n := 12
		for i in n:
			var a0 := PI * i / n; var a1 := PI * (i + 1) / n
			var mid := (a0 + a1) / 2
			# 열린 쪽: east면 θ 0 근처(＋x), west면 π 근처
			if front:
				if absf(mid - PI / 2) < 0.3: continue
			elif east and mid < 0.75: continue
			elif not east and mid > PI - 0.75: continue
			var p0 := Vector2(cos(a0) * R, zo + sin(a0) * R); var p1 := Vector2(cos(a1) * R, zo + sin(a1) * R)
			var ext := (p1 - p0).normalized() * 0.12
			p0 -= ext; p1 += ext
			var out := Vector2(cos(mid), sin(mid))
			# 몸체는 a→b 방향 기준 바깥 out
			S.body(b, rng, p0, p1, out, tt, S.H - 0.3, 0.25)
			var f0 := p0 + out * (tt / 2); var f1 := p1 + out * (tt / 2)
			# stone_face는 바깥을 볼 때 a→b가 왼→오른쪽이어야 하므로 방향 맞춤
			S.stone_face(b, rng, f1, f0, 0.0, S.H - 0.3, out, 0.25) if out.cross(f1 - f0) > 0 else S.stone_face(b, rng, f0, f1, 0.0, S.H - 0.3, out, 0.25)
			var q0 := p0 + out * (tt / 2 - S.PARA_T / 2); var q1 := p1 + out * (tt / 2 - S.PARA_T / 2)
			S.parapet(b, rng, q0, q1, S.H - 0.3, out)
			var m := (p0 + p1) / 2
			cols.append({ type = "circle", x = m.x, z = m.y, r = tt / 2 + 0.6 })
		fz = zo + R + 3.0
		var ox := (R + 3.0) if east else -(R + 3.0)
		anchors.outside = Vector3(0, 0, zo + R + 3.0) if front else Vector3(ox * 0.85, 0, zo + 1.5)
		anchors.ongseong_yard = Vector3(0, 0, zo + R * 0.5)
		foot = Vector2(maxf(Wg, 2 * R + tt), dep / 2 + zo + R + tt)
	var node := Co.node2("성문_" + str(params.get("name", "완월루")), b, roof)
	return { node = node, colliders = cols, lights = lights, occluder = true, footprint = foot, anchors = anchors }

# 홍예석 띠(문 중심 x 이동판)
static func _ring(b, rng: Kit.Rng, aw: float, sp: float, z: float, nz: float, cx: float) -> void:
	var r := aw / 2
	var g := []
	var n := 11
	for i in n:
		var a := PI * (i + 0.5) / n
		var rr := r + 0.32
		var st := Kit.box(0.42, 0.62, 0.08)
		Kit.xf(st, cx + cos(a) * rr, sp + sin(a) * rr, z + nz * 0.04, 0, 0, a - PI / 2)
		g.append(st)
	b.add("stone", Co.pnt(Kit.merge(g), [0xd0c9b8, 0xb2ab9b], 0.05, rng), 0.012)
