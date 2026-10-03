# 장산곶 바위 — 황해도 장연 장산곶 끝 바닷가 벼랑(「장산곶 매」 설화, 인당수 바다를 바라보는 곶). 물가로 솟은 큰 바위 벼랑 + 앞 갯바위 + 벼랑 위 해송,
# 꼭대기에 매가 앉는 자리(anchors.hawk). 크기는 게임용 가설(폭 24m·높이 12m). 밑은 물속까지(sink 1.5). 정면 +z = 바다 쪽. params: seed
extends RefCounted

const Co = preload("res://kit/landmark/_common.gd")
const Hub = preload("res://kit/landmark/_hub.gd")

static func build(params: Dictionary) -> Dictionary:
	var rng := Kit.Rng.new(int(params.get("seed", 1)))
	var b := Kit.Batch.new()
	var c := [0xa29c90, 0x5e5a52]
	Hub.rock(b, rng, 0, -3.0, 9.0, 8.0, 6.0, c, 2, 0.4, 0.2)
	Hub.rock(b, rng, -6.5, -1.0, 5.0, 6.0, 4.5, c, 1, 0.45, 1.0)
	Hub.rock(b, rng, 6.0, -1.5, 5.5, 5.0, 4.6, c, 1, 0.45, 2.0)
	Hub.rock(b, rng, 2.0, 1.5, 3.0, 3.2, 2.6, c, 1, 0.5, 0.7)
	for k in 8:
		var a := rng.between(-0.2, PI + 0.2)
		Hub.rock(b, rng, cos(a) * rng.between(9.0, 13.0), 2.0 + sin(a) * rng.between(2.0, 5.0), rng.between(0.8, 1.8), rng.between(0.5, 1.4), rng.between(0.8, 1.6), c, 0, 0.4, a)
	# 벼랑 위 해송 둘
	for p in [Vector3(-2.0, 11.0, -3.5), Vector3(3.5, 10.0, -4.5)]:
		b.add("bark", Co.pnt(Kit.limb(p - Vector3(0, 1.0, 0), p + Vector3(1.2, 1.4, 0.3), 0.22, 0.12, 5), [0x6a4a34, 0x4e3628]), 0.015)
		var g := Kit.lump(1.4, 1, rng, 0.3, 0.45); Kit.xf(g, p.x + 1.6, p.y + 1.8, p.z + 0.3)
		b.add("needle", Kit.paint(g, Kit.hex(0x5f7a42), Kit.hex(0x3a5030), 0.08, rng), 0.03)
	return {
		node = b.build("장산곶바위"), colliders = [{ type = "circle", x = 0.0, z = -2.0, r = 10.0 }], lights = [], occluder = true,
		footprint = Vector2(28.0, 18.0), anchors = { hawk = Vector3(0.5, 11.5, -3.0), shore = Vector3(0, 0, 9.0) }, sink = 1.5,
	}
