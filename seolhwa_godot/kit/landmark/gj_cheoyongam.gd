# 처용암(處容巖) — 울산 개운포(외황강 하구) 바다 가운데 작은 바위섬. 『삼국유사』 처용랑 망해사조: 헌강왕 행차 때 동해 용이 일곱 아들을 데리고
# 나타난 곳, 처용이 바다에서 올라온 바위. 실제 길이 약 30m 남짓의 낮은 갯바위섬 → 게임용 18×11m, 물 위 높이 4.5m(가설).
# 밑은 물속(y −1.5)까지 내려 둠. 지형 엔진이 물(landuse 5) 위에 놓는다. params: seed, size(1.0)
extends RefCounted

const Co = preload("res://kit/landmark/_common.gd")
const Hub = preload("res://kit/landmark/_hub.gd")

static func build(params: Dictionary) -> Dictionary:
	var rng := Kit.Rng.new(int(params.get("seed", 1)))
	var s: float = float(params.get("size", 1.0))
	var b := Kit.Batch.new()
	var dark := [0x8a8478, 0x4e4a44]
	# 갯바위 덩이 여럿(높낮이 다르게, 결 거칠게)
	Hub.rock(b, rng, 0, 0, 5.0 * s, 3.0 * s, 3.6 * s, dark, 1, 0.45, 0.4)
	Hub.rock(b, rng, -2.6 * s, -1.0 * s, 3.0 * s, 3.4 * s, 2.6 * s, dark, 1, 0.5, 1.3)
	Hub.rock(b, rng, 3.4 * s, 0.6 * s, 3.4 * s, 2.0 * s, 2.8 * s, dark, 1, 0.45, 2.2)
	Hub.rock(b, rng, -6.0 * s, 1.8 * s, 2.6 * s, 1.4 * s, 2.2 * s, dark, 1, 0.45, 0.9)
	Hub.rock(b, rng, 6.8 * s, 2.4 * s, 2.0 * s, 1.0 * s, 1.8 * s, dark, 1, 0.45, 2.9)
	for k in 7:
		var a := rng.between(0, TAU)
		Hub.rock(b, rng, cos(a) * 8.5 * s, sin(a) * 5.0 * s, rng.between(0.6, 1.3), rng.between(0.3, 0.7), rng.between(0.6, 1.2), dark, 0, 0.4, a)
	# 물때 띠(밑동 짙은 바다 이끼) — 얇은 고리
	var ring := Kit.cyl(7.2 * s, 7.6 * s, 0.5, 14, 0, 0.1, 0); Kit.xf(ring, 0, 0, 0, 0, 0, 0, 1.0, 1.0, 0.62)
	b.add("rock", Co.pnt(ring, [0x4a4a3e, 0x34342c], 0.06, rng), 0.0)
	# 바위 위 작은 해송·풀 덩이
	var t := Kit.lump(1.0, 1, rng, 0.25, 0.7); Kit.xf(t, -2.4 * s, 4.7 * s, -1.0 * s)
	b.add("needle", Kit.paint(t, Kit.hex(0x5f7a42), Kit.hex(0x3a5030), 0.08, rng), 0.03)
	b.add("bark", Co.pnt(Kit.limb(Vector3(-2.5 * s, 3.9 * s, -1.0 * s), Vector3(-2.3 * s, 4.6 * s, -1.0 * s), 0.12, 0.08, 4), [0x6a4a34]), 0.01)
	return {
		node = b.build("처용암"), colliders = [{ type = "circle", x = 0.0, z = 0.0, r = 7.0 * s }], lights = [], occluder = true,
		footprint = Vector2(20.0 * s, 13.0 * s), anchors = { top = Vector3(0, 4.4 * s, 0), shore_view = Vector3(0, 0, 14.0 * s) }, sink = 1.5,
	}
