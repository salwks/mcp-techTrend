# 읍성 성문 — 홍예문을 낸 육축(석축) + 그 위 문루(단층 팔작, 3×2칸) + (선택) 반원 옹성.
# 남원읍성 4문: 남 완월루(翫月樓)·북 공신루(拱宸樓)·서 망미루(望美樓)·동 향일루(向日樓) (위키백과 '남원읍성').
# 성벽 모듈과 같은 규칙: 로컬 x축이 성벽 방향, 바깥 +z, 원점 = 문 가운데 바닥(성벽 두께 중심).
# 문루 층수(단층)·옹성 모양(반원)·열린 쪽은 가설. params: seed, name("완월루"), width(16), radius(11),
#   open: 옹성 열린 쪽 "east"(로컬 +x) | "west"(로컬 −x) | "front"(정면 가운데) | "none"(옹성 없음). 예전 이름 open_side, ongseong=false도 받는다
extends RefCounted

const Co = preload("res://kit/landmark/_common.gd")
const S = preload("res://kit/landmark/_seong.gd")
const Roof = preload("res://kit/landmark/_roof.gd")

static func build(params: Dictionary) -> Dictionary:
	var rng := Kit.Rng.new(int(params.get("seed", 1)))
	var Wg: float = float(params.get("width", 16.0))
	var dep: float = S.T + 1.0
	var Hg: float = S.H + 1.0
	var aw := 3.8; var sp := 2.5
	var b := Kit.Batch.new(); var roof := Kit.Batch.new()
	# 육축(홍예 구멍)
	var g := Co.extrude_xy(S.arch_poly(Wg, Hg, aw, sp), dep)
	b.add("stone", Co.pnt(g, Co.SEONG, 0.03, rng), 0.035)
	# 면석(앞·뒤, 아치 양옆)
	for zf in [dep / 2, -dep / 2]:
		var out := Vector2(0, signf(zf))
		var r := aw / 2
		var segs := [[-Wg / 2, -r - 0.05], [r + 0.05, Wg / 2]]
		for sg in segs:
			var a := Vector2(sg[0], zf) if zf > 0 else Vector2(sg[1], zf)
			var c := Vector2(sg[1], zf) if zf > 0 else Vector2(sg[0], zf)
			S.stone_face(b, rng, a, c, 0.0, Hg - 0.1, out, 0.0)
		S.arch_ring(b, rng, aw, sp, zf, signf(zf))
	# 통로 바닥 박석 + 문짝(열림)
	b.add("stone", Co.pnt(Kit.box(aw - 0.1, 0.06, dep, 0, 0.03, 0), [0xa8a194, 0x958e81], 0.04, rng), 0.0)
	Co.board_doors(b, 0.0, 0.0, aw - 0.2, sp + 0.9, 0.4, true, [0x6e4a32, 0x553826])
	# 육축 위 여장(바깥 가장자리)
	S.parapet(b, rng, Vector2(-Wg / 2, dep / 2 - S.PARA_T / 2), Vector2(Wg / 2, dep / 2 - S.PARA_T / 2), Hg, Vector2(0, 1))
	# 성상 박석
	b.add("stone", Co.pnt(Kit.box(Wg - 0.2, 0.05, dep - 0.8, 0, Hg + 0.02, -0.3), [0xaaa294], 0.03, rng), 0.0)
	# 문루: 3×2칸 단층 팔작, 사방 트임 + 계자난간
	var info := Co.hall(b, roof, {
		bays = [3.6, 4.2, 3.6], depth = 4.4, dbays = 2, F = Hg + 0.15, H = 3.3, fronts = ["none", "none", "none"],
		enclose = false, back = "none", base = false, floor = true, roof = "paljak", ox = 1.6, oz = 1.5, rise = 2.2, lift = 0.65,
		bracket = "ikgong", col_r = 0.19, cz = -0.5, roof_nx = 24, roof_nz = 14,
	}, rng)
	var F: float = info.F
	var rails := []
	var W: float = info.W
	for zz in [info.z1, info.z0]:
		rails.append(Kit.box(W, 0.07, 0.07, 0, F + 0.75, zz)); rails.append(Kit.box(W, 0.05, 0.05, 0, F + 0.3, zz))
	for sx in [-1, 1]:
		rails.append(Kit.box(0.07, 0.07, 4.4, sx * W / 2, F + 0.75, -0.5)); rails.append(Kit.box(0.05, 0.05, 4.4, sx * W / 2, F + 0.3, -0.5))
	b.add("wood", Co.pnt(Kit.merge(rails), Co.WOOD), 0.012)
	b.add("wood", Co.pnt(Kit.box(W + 0.2, 0.14, 4.6, 0, F - 0.05, -0.5), Co.WOOD_L, 0.03, rng), 0.015)
	# 현판
	b.add("wood", Co.pnt(Kit.box(1.9, 0.62, 0.08, 0, info.top - 0.35, info.z1 + 0.25), [0x3a2c22, 0x2c2018]), 0.012)
	b.add("flat", Co.pnt(Kit.box(1.5, 0.34, 0.04, 0, info.top - 0.35, info.z1 + 0.3), [0xe8dcb8]), 0.0)
	var cols := [
		{ type = "box", minX = -Wg / 2, maxX = -aw / 2, minZ = -dep / 2, maxZ = dep / 2 },
		{ type = "box", minX = aw / 2, maxX = Wg / 2, minZ = -dep / 2, maxZ = dep / 2 },
	]
	var fz := dep / 2 + 3.0
	var anchors := { inside = Vector3(0, 0, -dep / 2 - 3.0), passage = Vector3(0, 0, 0), top = Vector3(0, Hg, -0.5), outside = Vector3(0, 0, dep / 2 + 3.0) }
	var lights := [{ x = -aw / 2 - 0.6, y = 2.2, z = dep / 2 + 0.3, kind = "torch" }, { x = aw / 2 + 0.6, y = 2.2, z = dep / 2 + 0.3, kind = "torch" }]
	var foot := Vector2(Wg, dep)
	# 옹성(반원)
	var open: String = str(params.get("open", params.get("open_side", "east")))
	if not params.get("ongseong", true): open = "none"
	if open != "none":
		var R: float = float(params.get("radius", 11.0))
		var tt := 3.2
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
