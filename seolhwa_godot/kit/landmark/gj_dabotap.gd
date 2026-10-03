# 불국사 다보탑(多寶塔) — 통일신라 751년 무렵, 높이 약 10.3m. 네모 기단(사방 계단 10단) + 네 모서리 기둥·가운데 기둥 위 네모 옥개 +
# 2층 네모 난간 → 8각 난간 → 대나무 마디 기둥(죽절)·연꽃 받침 → 8각 옥개 + 상륜(노반·앙화·보륜·보개).
# 기단 계단 위 돌사자: 본래 넷(일제강점기에 셋이 사라짐) → 1870년 기준 넷(가설). 부재 치수는 높이에 맞춘 비례 가설. params: seed, lions(4)
extends RefCounted

const Co = preload("res://kit/landmark/_common.gd")
const St = preload("res://kit/landmark/_stone.gd")

static func build(params: Dictionary) -> Dictionary:
	var rng := Kit.Rng.new(int(params.get("seed", 1)))
	var b := Kit.Batch.new()
	var P := []
	var y := 0.0
	# 기단 + 사방 계단
	P.append(Kit.box(4.6, 1.15, 4.6, 0, 0.575, 0)); y = 1.15
	P.append(Kit.box(4.8, 0.14, 4.8, 0, y + 0.07, 0)); y += 0.14
	for d in [Vector2(0, 1), Vector2(0, -1), Vector2(1, 0), Vector2(-1, 0)]:
		for k in 6:
			var sh := y * (k + 1) / 6.0
			var off := 2.4 + (5 - k) * 0.22 + 0.11
			P.append(Kit.box(1.2 if d.x == 0 else 0.22, sh, 0.22 if d.x == 0 else 1.2, d.x * off, sh / 2, d.y * off))
	# 1층: 네 귀 기둥 + 가운데 기둥(네모) + 받침
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			P.append(Kit.box(0.42, 1.5, 0.42, sx * 1.35, y + 0.75, sz * 1.35))
	P.append(Kit.box(0.7, 1.5, 0.7, 0, y + 0.75, 0))
	y += 1.5
	P.append(Kit.box(3.3, 0.2, 3.3, 0, y + 0.1, 0)); y += 0.2
	var og := St.okgae4(4.0, 0.16, 0.35, 2.8, 0.06); Kit.xf(og, 0, y, 0); P.append(og); y += 0.5
	# 2층 네모 난간
	var rail := []
	for s in [-1, 1]:
		rail.append(Kit.box(2.8, 0.08, 0.08, 0, y + 0.55, s * 1.4)); rail.append(Kit.box(0.08, 0.08, 2.8, s * 1.4, y + 0.55, 0))
		for k in 5:
			var t := -1.4 + k * 0.7
			rail.append(Kit.box(0.1, 0.6, 0.1, t, y + 0.3, s * 1.4)); rail.append(Kit.box(0.1, 0.6, 0.1, s * 1.4, y + 0.3, t))
	P.append(Kit.box(1.9, 0.9, 1.9, 0, y + 0.45, 0)); y += 0.9
	P.append(St.oct(1.25, 1.25, 0.14, y)); y += 0.14
	# 8각 난간 + 죽절 기둥 8 + 8각 몸
	for i in 8:
		var a := TAU * i / 8 + PI / 8
		rail.append(Kit.cyl(0.07, 0.07, 0.7, 5, cos(a) * 1.1, y + 0.35, sin(a) * 1.1))
		var c := Kit.cyl(0.09, 0.1, 1.1, 6, cos(a) * 0.62, y + 0.55, sin(a) * 0.62)
		P.append(c)
		for k in 3: P.append(Kit.cyl(0.12, 0.12, 0.06, 6, cos(a) * 0.62, y + 0.25 + k * 0.32, sin(a) * 0.62))
	rail.append(Kit.xf(Kit.cyl(1.12, 1.12, 0.08, 8, 0, y + 0.68, 0), 0, 0, 0, 0, PI / 8))
	P.append(St.oct(0.45, 0.45, 1.1, y)); y += 1.1
	# 연꽃 받침
	P.append(St.oct(0.95, 0.55, 0.32, y)); y += 0.32
	# 8각 몸 + 8기둥
	for i in 8:
		var a := TAU * i / 8 + PI / 8
		P.append(Kit.cyl(0.07, 0.07, 0.9, 5, cos(a) * 0.7, y + 0.45, sin(a) * 0.7))
	P.append(St.oct(0.4, 0.4, 0.9, y)); y += 0.9
	# 8각 옥개
	var ok := Kit.cyl(0.35, 1.45, 0.45, 8, 0, y + 0.225, 0, 0, PI / 8, 0); P.append(ok); y += 0.45
	b.add("stone", Co.pnt(Kit.merge(P), [0xc0b9a8, 0x8f8878], 0.06, rng), 0.03)
	b.add("stone", Co.pnt(Kit.merge(rail), [0xb2ab9a, 0x948d7d], 0.04, rng), 0.012)
	# 상륜
	var sr := []
	sr.append(St.oct(0.32, 0.32, 0.3, y)); y += 0.3
	sr.append(Kit.cyl(0.28, 0.2, 0.22, 8, 0, y + 0.11, 0)); y += 0.22
	sr.append(Kit.cyl(0.05, 0.05, 1.2, 6, 0, y + 0.6, 0))
	for k in 4: sr.append(Kit.cyl(0.2 - k * 0.02, 0.2 - k * 0.02, 0.08, 8, 0, y + 0.1 + k * 0.2, 0))
	y += 0.9
	sr.append(Kit.cyl(0.08, 0.36, 0.14, 8, 0, y + 0.07, 0)); y += 0.2
	var bj := Kit.icosphere(0.1, 0); Kit.xf(bj, 0, y + 0.15, 0); sr.append(bj); y += 0.3
	b.add("flat", Co.pnt(Kit.merge(sr), [0x8a877e, 0x6c6961], 0.03, rng), 0.015)
	# 돌사자(계단 위 네 귀 쪽, 앉은 모습 간략)
	var nl: int = int(params.get("lions", 4))
	var spots := [Vector2(1.7, 1.7), Vector2(-1.7, 1.7), Vector2(1.7, -1.7), Vector2(-1.7, -1.7)]
	for i in mini(nl, 4):
		var p: Vector2 = spots[i]
		var lg := []
		lg.append(Kit.box(0.42, 0.3, 0.6, p.x, 1.44, p.y))
		var hd := Kit.lump(0.2, 0, rng, 0.1, 1.0); Kit.xf(hd, p.x, 1.72, p.y + 0.22 * signf(p.y)); lg.append(hd)
		b.add("stone", Co.pnt(Kit.merge(lg), [0xb5ae9e, 0x8a8474], 0.05, rng), 0.015)
	return {
		node = b.build("다보탑"), colliders = [{ type = "box", minX = -2.5, maxX = 2.5, minZ = -2.5, maxZ = 2.5 }], lights = [], occluder = false,
		footprint = Vector2(6.0, 6.0), anchors = { front = Vector3(0, 0, 4.2) }, height = y,
	}
