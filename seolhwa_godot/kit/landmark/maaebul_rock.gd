# 여원치 마애불(남원 여원치 마애여래좌상, 전북 유형문화재 1998) — 남원→운봉 여원치 고개 마루 길가 암벽에 새긴 고려시대 좌상.
# 높이 약 2.5m·어깨너비 1.09m, 뺨이 통통한 얼굴, 음각 이목구비, 통견 대의에 U자 띠주름(검색 근거).
# 이성계 황산대첩 때 도움을 준 여인(도고) 전설과 이어져 '여상'이라고도 한다. 앞에 보호각 흔적(돌기둥 2)·기와 조각이 남았다는데
# 1870년 당시 보호각이 서 있었는지는 알 수 없어 기본은 보호각 없음(pillars=true면 돌기둥 둘만). 마애비 명문(1901)은 1870 이후라 제외.
# 바위 덩이·불상 비례는 가설. 정면(새긴 면) +z. params: seed, pillars(false), offering(true: 앞 제단돌·촛불)
extends RefCounted

const Co = preload("res://kit/landmark/_common.gd")

static func build(params: Dictionary) -> Dictionary:
	var rng := Kit.Rng.new(int(params.get("seed", 1)))
	var b := Kit.Batch.new()
	# 큰 바위: 울퉁불퉁한 덩이를 키우고 앞면을 평평하게 깎음(새긴 면 z = fz)
	var rock := Kit.lump(1.0, 2, rng, 0.22, 1.0)
	Kit.xf(rock, 0, 2.2, -1.0, 0, 0, 0, 3.6, 2.9, 2.2)
	var fz := 0.55
	for i in rock.pos.size():
		var p := rock.pos[i]
		if p.z > fz:
			var k := clampf((p.y - 0.2) / 4.0, 0.0, 1.0)
			# 위쪽은 살짝 앞으로 기운 면, 가장자리는 둥글게 남김
			if absf(p.x) < 2.6 and p.y > 0.0 and p.y < 4.6:
				rock.pos[i] = Vector3(p.x, p.y, fz + k * 0.15)
		if p.y < -0.6: rock.pos[i].y = -0.6
	b.add("rock", Co.pnt(rock, [0xc8c2b4, 0x8c867a], 0.08, rng), 0.04)
	# 주변 작은 바위
	for k in 4:
		var a := rng.between(-0.6, 3.8)
		var g := Kit.lump(rng.between(0.5, 1.0), 1, rng, 0.3, 0.7)
		Kit.xf(g, cos(a) * 3.8, 0.25, -1.0 + sin(a) * 2.6 - 0.3, 0, rng.next() * 3.0)
		b.add("rock", Co.pnt(g, [0xbab3a5, 0x857f73], 0.08, rng), 0.03)
	# 부조 불상(좌상): 새긴 면에서 살짝 도드라짐. 무릎(가로 타원) / 몸(통견) / 머리 / 육계 / 두광(음각 고리)
	var z0 := fz + 0.1
	var rel := []
	var knees := Kit.lump(1.0, 1, rng, 0.05, 1.0); Kit.xf(knees, 0, 0.75, z0, 0, 0, 0, 1.35, 0.42, 0.22); rel.append(knees)
	var body := Kit.lump(1.0, 1, rng, 0.04, 1.0); Kit.xf(body, 0, 1.45, z0, 0, 0, 0, 0.58, 0.72, 0.2); rel.append(body)
	var head := Kit.lump(1.0, 1, rng, 0.03, 1.0); Kit.xf(head, 0, 2.28, z0 + 0.04, 0, 0, 0, 0.3, 0.36, 0.2); rel.append(head)
	var ush := Kit.lump(1.0, 0, rng, 0.03, 1.0); Kit.xf(ush, 0, 2.66, z0, 0, 0, 0, 0.16, 0.14, 0.12); rel.append(ush)
	b.add("stone", Co.pnt(Kit.merge(rel), [0xd2ccbe, 0xb0aa9c], 0.04, rng), 0.025)
	# 음각선: 두광 고리, U자 띠주름, 눈·입
	var ink := []
	var cy := 2.3
	for i in 20:
		var a0 := TAU * i / 20; var a1 := TAU * (i + 1) / 20
		var r := 0.6
		var pa := Vector3(sin(a0) * r, cy + cos(a0) * r, 0); var pb := Vector3(sin(a1) * r, cy + cos(a1) * r, 0)
		if pa.y < cy - 0.25 and pb.y < cy - 0.25: continue
		var q := Kit.limb(pa, pb, 0.025, 0.025, 3); Kit.xf(q, 0, 0, fz + 0.16); ink.append(q)
	for j in 3:
		var rr := 0.25 + j * 0.13
		for i in 6:
			var a0 := PI * (0.2 + 0.6 * i / 6.0); var a1 := PI * (0.2 + 0.6 * (i + 1) / 6.0)
			var pa := Vector3(cos(a0) * rr, 1.55 - sin(a0) * rr * 0.8, 0); var pb := Vector3(cos(a1) * rr, 1.55 - sin(a1) * rr * 0.8, 0)
			var q := Kit.limb(pa, pb, 0.018, 0.018, 3); Kit.xf(q, 0, 0, z0 + 0.19); ink.append(q)
	for sx in [-1, 1]:
		var q := Kit.limb(Vector3(sx * 0.16, 2.32, 0), Vector3(sx * 0.05, 2.3, 0), 0.015, 0.015, 3); Kit.xf(q, 0, 0, z0 + 0.235); ink.append(q)
	var m := Kit.limb(Vector3(-0.06, 2.12, 0), Vector3(0.06, 2.12, 0), 0.014, 0.014, 3); Kit.xf(m, 0, 0, z0 + 0.235); ink.append(m)
	b.add("flat", Co.pnt(Kit.merge(ink), [0x4a443c]), 0.0)
	var cols := [{ type = "circle", x = 0.0, z = -1.0, r = 3.4 }]
	var lights := []
	if params.get("offering", true):
		b.add("stone", Co.pnt(Kit.box(1.2, 0.4, 0.6, 0, 0.2, fz + 1.2), [0xb0aa9c, 0x8a8478], 0.05, rng), 0.02)
		b.add("flat", Co.pnt(Kit.cyl(0.04, 0.045, 0.16, 6, 0.3, 0.48, fz + 1.2), [0xefe6d0]), 0.006)
		b.add("glow", Co.pnt(Kit.cone(0.03, 0.09, 6, 0.3, 0.61, fz + 1.2), [0xffd27a, 0xff9a3a]), 0.0)
		lights.append({ x = 0.3, y = 0.65, z = fz + 1.2, kind = "shrine" })
		cols.append({ type = "box", minX = -0.6, maxX = 0.6, minZ = fz + 0.9, maxZ = fz + 1.5 })
	if params.get("pillars", false):
		for sx in [-1, 1]:
			b.add("stone", Co.pnt(Kit.box(0.32, 2.4, 0.32, sx * 2.0, 1.2, fz + 2.2), [0xb5afa2, 0x8e897f], 0.05, rng), 0.02)
			cols.append({ type = "circle", x = sx * 2.0, z = fz + 2.2, r = 0.3 })
	return {
		node = b.build("여원치마애불"), colliders = cols, lights = lights, occluder = true,
		footprint = Vector2(8.0, 6.5), anchors = { worship = Vector3(0, 0, fz + 2.6), face = Vector3(0, 1.5, fz) },
	}
