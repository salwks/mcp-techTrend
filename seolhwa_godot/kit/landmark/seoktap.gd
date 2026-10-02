# 실상사 동·서 삼층석탑(통일신라 9세기, 높이 약 8.4m) — 이중 기단 + 3층 탑신·옥개석(층급받침 4단) + 상륜부가 거의 온전히 남은 드문 예
# (불국사 석가탑 상륜 복원의 본보기, 검색 근거). 부재 치수는 높이 8.4m에 맞춘 비례 가설.
# params: seed, height(8.4), weather(0..1 이끼·얼룩 정도)
extends RefCounted

const Co = preload("res://kit/landmark/_common.gd")
const St = preload("res://kit/landmark/_stone.gd")

static func build(params: Dictionary) -> Dictionary:
	var rng := Kit.Rng.new(int(params.get("seed", 1)))
	var s: float = float(params.get("height", 8.4)) / 8.4
	var b := Kit.Batch.new()
	var parts := []
	var y := 0.0
	# 하층 기단 + 갑석
	parts.append(Kit.box(3.4 * s, 0.85 * s, 3.4 * s, 0, y + 0.425 * s, 0)); y += 0.85 * s
	parts.append(Kit.box(3.55 * s, 0.16 * s, 3.55 * s, 0, y + 0.08 * s, 0)); y += 0.16 * s
	parts.append(Kit.box(2.7 * s, 0.1 * s, 2.7 * s, 0, y + 0.05 * s, 0)); y += 0.1 * s
	# 상층 기단 + 갑석
	parts.append(Kit.box(2.5 * s, 1.25 * s, 2.5 * s, 0, y + 0.625 * s, 0)); y += 1.25 * s
	parts.append(Kit.box(2.75 * s, 0.17 * s, 2.75 * s, 0, y + 0.085 * s, 0)); y += 0.17 * s
	parts.append(Kit.box(1.6 * s, 0.1 * s, 1.6 * s, 0, y + 0.05 * s, 0)); y += 0.1 * s
	var bodies := [[1.3, 1.25], [1.05, 0.62], [0.92, 0.55]]
	var roofs := [[2.3, 0.5], [2.0, 0.45], [1.8, 0.42]]
	var pillars := []
	for i in 3:
		var bw: float = bodies[i][0] * s; var bh: float = bodies[i][1] * s
		parts.append(Kit.box(bw, bh, bw, 0, y + bh / 2, 0))
		# 우주(모서리 기둥 새김) 대신 얕은 띠
		for sx in [-1, 1]:
			pillars.append(Kit.box(0.1 * s, bh, 0.03, sx * (bw / 2 - 0.07 * s), y + bh / 2, bw / 2 + 0.01))
		y += bh
		# 층급받침 4단
		var rw: float = roofs[i][0] * s
		for k in 4:
			var w := bw + (rw - bw) * (k + 1) / 5.0
			parts.append(Kit.box(w, 0.06 * s, w, 0, y + 0.03 * s, 0)); y += 0.06 * s
		var og := St.okgae4(rw, 0.1 * s, roofs[i][1] * s - 0.1 * s, bodies[mini(i + 1, 2)][0] * s * 0.9, 0.12 * s)
		Kit.xf(og, 0, y, 0)
		parts.append(og)
		y += roofs[i][1] * s
	b.add("stone", Co.pnt(Kit.merge(parts), [0xb8b2a4, 0x8d877a], 0.06, rng), 0.03)
	b.add("stone", Co.pnt(Kit.merge(pillars), [0xa8a294], 0.02, rng), 0.0)
	# 상륜부: 노반·복발·앙화·보륜5·보개·수연·용차·보주 (청동이 아니라 돌, 짙은 회색)
	var sr := []
	sr.append(Kit.box(0.6 * s, 0.28 * s, 0.6 * s, 0, y + 0.14 * s, 0)); y += 0.28 * s
	sr.append(Kit.cyl(0.24 * s, 0.3 * s, 0.24 * s, 8, 0, y + 0.12 * s, 0)); y += 0.24 * s
	sr.append(Kit.cyl(0.34 * s, 0.18 * s, 0.22 * s, 8, 0, y + 0.11 * s, 0)); y += 0.22 * s
	sr.append(Kit.cyl(0.05 * s, 0.05 * s, 1.6 * s, 6, 0, y + 0.8 * s, 0))
	for k in 5:
		sr.append(Kit.cyl(0.24 * s - k * 0.012, 0.24 * s - k * 0.012, 0.09 * s, 8, 0, y + 0.08 * s + k * 0.17 * s, 0))
	y += 0.9 * s
	sr.append(Kit.cyl(0.08 * s, 0.32 * s, 0.14 * s, 8, 0, y + 0.07 * s, 0)); y += 0.2 * s
	sr.append(Kit.cyl(0.2 * s, 0.06 * s, 0.25 * s, 8, 0, y + 0.12 * s, 0)); y += 0.3 * s
	var bj := Kit.icosphere(0.1 * s, 0); Kit.xf(bj, 0, y + 0.18 * s, 0); sr.append(bj)
	var bj2 := Kit.icosphere(0.08 * s, 0); Kit.xf(bj2, 0, y + 0.38 * s, 0); sr.append(bj2)
	y += 0.48 * s
	b.add("flat", Co.pnt(Kit.merge(sr), [0x8a877e, 0x6c6961], 0.03, rng), 0.015)
	return {
		node = b.build("삼층석탑"),
		colliders = [{ type = "box", minX = -1.8 * s, maxX = 1.8 * s, minZ = -1.8 * s, maxZ = 1.8 * s }],
		lights = [], occluder = false, footprint = Vector2(3.6 * s, 3.6 * s),
		anchors = { front = Vector3(0, 0, 2.8 * s) }, height = y,
	}
