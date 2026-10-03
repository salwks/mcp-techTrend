# 김녕사굴(金寧蛇窟) 입구 — 제주 구좌 김녕리 용암동굴. 큰 뱀에게 처녀를 바치던 굴, 1515년 판관 서련이 뱀을 죽였다는 설화(김녕사굴 설화).
# 입구는 땅이 꺼진 낮고 넓은 굴 아가리(현무암), 둘레 덩굴·풀. 1870년에도 자연 동굴 그대로. 입구 크기는 게임용 가설(폭 5m·높이 3m).
# 서련 판관 사적비(1702년 세움 — 김녕굴 앞)는 stele=true로. params: seed, stele(true)
extends RefCounted

const Co = preload("res://kit/landmark/_common.gd")
const Hub = preload("res://kit/landmark/_hub.gd")

static func build(params: Dictionary) -> Dictionary:
	var rng := Kit.Rng.new(int(params.get("seed", 1)))
	var b := Kit.Batch.new()
	var fz := Hub.cave_mouth(b, rng, 5.0, 3.0, [0x6a665e, 0x3a3733], Vector3(16, 3.6, 10))
	# 입구 앞 꺼진 바닥(어두운 흙) + 현무암 덩이
	b.add("mud", Co.pnt(Kit.box(6.0, 0.05, 3.0, 0, 0.02, fz + 1.4), [0x4a4238, 0x3a332c], 0.05, rng), 0.0)
	for k in 8:
		var a := rng.between(-0.3, PI + 0.3)
		Hub.rock(b, rng, cos(a) * rng.between(4.0, 7.5), fz + 0.6 + sin(a) * rng.between(0.5, 2.0) - 1.0, rng.between(0.5, 1.1), rng.between(0.3, 0.7), rng.between(0.5, 1.0), Hub.BASALT, 0, 0.35, a)
	# 덩굴·풀 덩이(위)
	for k in 6:
		var g := Kit.lump(rng.between(0.6, 1.1), 1, rng, 0.3, 0.6); Kit.xf(g, rng.between(-6, 6), 3.2 + rng.next() * 0.8, rng.between(-4, -1))
		b.add("leaf", Kit.paint(g, Kit.hex(0x6f8a4a), Kit.hex(0x3e5a32), 0.08, rng), 0.02)
	var anchors := { mouth = Vector3(0, 0, fz + 1.0), inside = Vector3(0, 0, fz - 2.0), outside = Vector3(0, 0, fz + 5.0) }
	var cols := [{ type = "box", minX = -8.0, maxX = -2.6, minZ = -5.0, maxZ = fz }, { type = "box", minX = 2.6, maxX = 8.0, minZ = -5.0, maxZ = fz }]
	if params.get("stele", true):
		Hub.stele(b, rng, 5.5, fz + 4.0, 1.4, 0.55, false, -0.3)
		cols.append({ type = "circle", x = 5.5, z = fz + 4.0, r = 0.6 })
		anchors.stele = Vector3(5.5, 0, fz + 5.2)
	return { node = b.build("김녕사굴"), colliders = cols, lights = [], occluder = true, footprint = Vector2(17.0, 14.0), anchors = anchors }
