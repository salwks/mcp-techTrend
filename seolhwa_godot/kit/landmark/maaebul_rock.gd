# 여원치 마애불상(남원 이백면 양가리 여원치 고개 암벽, 고려 전기, 화강암, 높이 3.2m — 디지털남원문화대전 「여원치마애불상」).
# 확정(문헌): 넓적한 얼굴·옆으로 긴 눈·넓은 콧망울·짧은 인중·꾹 다문 각진 입 / 오른쪽 머리·얼굴 일부와 오른손 절단 /
#   왼팔은 어깨에서 내려와 가슴에 대고(왼손은 팔굽 아래 결실) / 가슴 아래 U자 옷주름 / 머리 뒤 희미한 광배 /
#   배 아래로 갈수록 조각선이 흐려 하체는 알 수 없음. 앞에 보호각 흔적 돌기둥 2·기와편(한국민족문화대백과 요약).
# 가설: 바위 덩이 크기·모양, 부조 두께, 1870년 보호각 유무(기본 없음, pillars=true면 돌기둥 둘). 마애비 명문은 넣지 않음.
# 정면(새긴 면) +z. params: seed, pillars(false), offering(true: 앞 제단돌·촛불)
extends RefCounted

const Co = preload("res://kit/landmark/_common.gd")

static func build(params: Dictionary) -> Dictionary:
	var rng := Kit.Rng.new(int(params.get("seed", 1)))
	var b := Kit.Batch.new()
	# 큰 바위 덩이(뒤) + 앞의 평평한 암벽 판(새긴 면 z = fz)
	var rock := Kit.lump(1.0, 2, rng, 0.2, 1.0)
	Kit.xf(rock, 0, 2.3, -2.3, 0, 0, 0, 4.2, 3.0, 2.2)
	for i in rock.pos.size():
		if rock.pos[i].y < -0.6: rock.pos[i].y = -0.6
	b.add("rock", Co.pnt(rock, [0xc8c2b4, 0x8c867a], 0.08, rng), 0.04)
	var fz := 0.35
	var face := PackedVector2Array()
	var nf := 16
	for i in nf:
		var t := TAU * i / nf
		var rx := 3.0 + Kit.vnoise(i * 1.7, 3.1) * 0.6
		var ry := 2.9 + Kit.vnoise(i * 1.9, 7.3) * 0.5
		face.append(Vector2(sin(t) * rx, maxf(-0.5, 2.4 + cos(t) * ry)))
	var fg := Co.extrude_xy(face, 1.4, fz - 0.7)
	b.add("stone", Co.pnt(fg, [0xbcb6a8, 0x948e81], 0.03, rng), 0.04)
	# 주변 작은 바위
	for k in 4:
		var a := rng.between(-0.6, 3.8)
		var g := Kit.lump(rng.between(0.5, 1.0), 1, rng, 0.3, 0.7)
		Kit.xf(g, cos(a) * 4.2, 0.25, -1.0 + sin(a) * 2.4 - 0.2, 0, rng.next() * 3.0)
		b.add("rock", Co.pnt(g, [0xbab3a5, 0x857f73], 0.08, rng), 0.03)
	# 부조(얕게 도드라짐, 위는 또렷 아래로 갈수록 흐려짐): 전체 높이 3.2m(광배 포함)
	var z0 := fz
	var rel := []
	var hy := 2.55   # 얼굴 중심 높이
	# 넓적한 얼굴(가로가 넓은 타원) — 오른쪽(관람자 왼쪽, −x) 일부 떨어져 나감: 왼쪽 반만 온전, 오른쪽은 깎인 면
	var head := Kit.lump(1.0, 1, rng, 0.03, 1.0); Kit.xf(head, 0.04, hy, z0, 0, 0, 0, 0.47, 0.5, 0.17)
	for i in head.pos.size():
		if head.pos[i].x < -0.12: head.pos[i].z = minf(head.pos[i].z, z0 + 0.03)
	rel.append(head)
	var ush := Kit.lump(1.0, 0, rng, 0.03, 1.0); Kit.xf(ush, 0.06, hy + 0.5, z0, 0, 0, 0, 0.2, 0.16, 0.09); rel.append(ush)
	# 어깨·가슴(넓은 어깨, 통견)
	var body := Kit.lump(1.0, 1, rng, 0.04, 1.0); Kit.xf(body, 0, 1.6, z0, 0, 0, 0, 0.82, 0.78, 0.15); rel.append(body)
	# 왼팔(관람자 오른쪽, +x): 어깨에서 내려와 가슴에 댐 — 팔굽 아래 결실
	rel.append(Kit.limb(Vector3(0.68, 2.0, z0 + 0.08), Vector3(0.6, 1.35, z0 + 0.1), 0.15, 0.14, 5))
	rel.append(Kit.limb(Vector3(0.6, 1.35, z0 + 0.1), Vector3(0.25, 1.6, z0 + 0.12), 0.13, 0.11, 5))
	# 오른팔은 어깨선만(오른손 절단)
	rel.append(Kit.limb(Vector3(-0.68, 2.0, z0 + 0.06), Vector3(-0.66, 1.5, z0 + 0.06), 0.14, 0.13, 5))
	# 하체: 아주 얕게(흐려짐) — 무릎 너비
	var knees := Kit.lump(1.0, 1, rng, 0.06, 1.0); Kit.xf(knees, 0, 0.75, z0 - 0.02, 0, 0, 0, 1.25, 0.4, 0.07); rel.append(knees)
	b.add("stone", Co.pnt(Kit.merge(rel), [0xd8d2c4, 0xb4aea0], 0.04, rng), 0.02)
	# 음각선: 희미한 두광(머리 뒤 큰 고리, 끊긴 데 있음) / 신광 윤곽 / U자 띠주름 / 이목구비
	var ink := []
	for i in 22:
		if i % 4 == 3: continue
		var a0 := TAU * i / 22; var a1 := TAU * (i + 1) / 22
		var pa := Vector3(sin(a0) * 0.78, hy + 0.1 + cos(a0) * 0.72, 0); var pb := Vector3(sin(a1) * 0.78, hy + 0.1 + cos(a1) * 0.72, 0)
		if pa.y < hy - 0.45 and pb.y < hy - 0.45: continue
		var q := Kit.limb(pa, pb, 0.022, 0.022, 3); Kit.xf(q, 0, 0, z0 + 0.012); ink.append(q)
	for i in 12:
		var a0 := PI * (0.12 + 0.76 * i / 12.0); var a1 := PI * (0.12 + 0.76 * (i + 1) / 12.0)
		var pa := Vector3(cos(a0) * 1.25, 1.9 + sin(a0) * 1.3 - 1.3, 0); var pb := Vector3(cos(a1) * 1.25, 1.9 + sin(a1) * 1.3 - 1.3, 0)
		pa.y = 1.9 - (1.0 - sin(a0)) * 0.0 + (sin(a0) - 0.5) * 1.6; pb.y = 1.9 + (sin(a1) - 0.5) * 1.6
		var q := Kit.limb(pa, pb, 0.018, 0.018, 3); Kit.xf(q, 0, 0, z0 + 0.012); ink.append(q)
	for j in 4:
		var rr := 0.2 + j * 0.12
		for i in 6:
			var a0 := PI * (0.18 + 0.64 * i / 6.0); var a1 := PI * (0.18 + 0.64 * (i + 1) / 6.0)
			var pa := Vector3(cos(a0) * rr, 1.62 - sin(a0) * rr * 0.75, 0); var pb := Vector3(cos(a1) * rr, 1.62 - sin(a1) * rr * 0.75, 0)
			var q := Kit.limb(pa, pb, 0.017, 0.017, 3); Kit.xf(q, 0, 0, z0 + 0.155); ink.append(q)
	# 눈(옆으로 길게) — 왼눈만 온전, 오른눈은 깨진 자리라 짧게
	ink.append(Kit.xf(Kit.limb(Vector3(0.08, hy + 0.06, 0), Vector3(0.3, hy + 0.08, 0), 0.016, 0.016, 3), 0, 0, z0 + 0.165))
	ink.append(Kit.xf(Kit.limb(Vector3(-0.07, hy + 0.08, 0), Vector3(-0.14, hy + 0.07, 0), 0.016, 0.016, 3), 0, 0, z0 + 0.16))
	# 넓은 콧망울, 짧은 인중, 꾹 다문 각진 입
	ink.append(Kit.xf(Kit.limb(Vector3(-0.06, hy - 0.1, 0), Vector3(0.12, hy - 0.1, 0), 0.018, 0.018, 3), 0, 0, z0 + 0.168))
	ink.append(Kit.xf(Kit.limb(Vector3(-0.06, hy - 0.2, 0), Vector3(0.14, hy - 0.2, 0), 0.016, 0.016, 3), 0, 0, z0 + 0.165))
	# 깨진 자리(오른쪽 머리·얼굴): 짙은 얼룩 판
	var scar := Co.vplane(0.22, 0.5, -0.24, hy + 0.08, z0 + 0.035)
	b.add("flat", Co.pnt(Kit.merge(ink), [0x4a443c]), 0.0)
	b.add("flat", Co.pnt(scar, [0xa8a294, 0x968f82], 0.06, rng), 0.0)
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
		footprint = Vector2(9.0, 6.5), anchors = { worship = Vector3(0, 0, fz + 2.6), face = Vector3(0, 2.5, fz) },
	}
