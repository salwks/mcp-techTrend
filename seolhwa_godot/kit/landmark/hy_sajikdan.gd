# 한양 사직단(社稷壇) — 1395년 설치. 동쪽 사단(社壇)·서쪽 직단(稷壇) 두 네모 단(각 변 약 7.65m·높이 약 0.9m, 사방 3단 계단) +
# 안쪽 낮은 담(유 壝, 사방 홍살문 넷) + 바깥 담(주원). 1870년에 제향 중. 정문은 북쪽 신문이지만 카메라를 위해 남(+z) 홍살문을 앞으로 둠(남원 사직단과 같은 원칙).
# 담 크기는 압축(실제 유 약 33m 안팎 → 34m, 주원 약 56m, 가설). 단은 sajikdan.altar() 재사용. params: seed
extends RefCounted

const Co = preload("res://kit/landmark/_common.gd")
const SJ = preload("res://kit/landmark/sajikdan.gd")

static func build(params: Dictionary) -> Dictionary:
	var rng := Kit.Rng.new(int(params.get("seed", 1)))
	var b := Kit.Batch.new()
	SJ.altar(b, rng, 6.2, 0.0, 7.65, 0.9)
	SJ.altar(b, rng, -6.2, 0.0, 7.65, 0.9)
	var cols := [{ type = "box", minX = 1.9, maxX = 10.5, minZ = -4.3, maxZ = 4.3 }, { type = "box", minX = -10.5, maxX = -1.9, minZ = -4.3, maxZ = 4.3 }]
	var hi := 17.0; var ho := 28.0
	cols.append_array(Co.low_wall_loop(b, [Vector2(-hi, -hi), Vector2(hi, -hi), Vector2(hi, hi), Vector2(-hi, hi)], [[0.0, hi, 2.2], [0.0, -hi, 2.2], [hi, 0.0, 2.2], [-hi, 0.0, 2.2]], 1.2, rng, 0.5))
	Co.hongsal_gate(b, 0.0, hi, 3.8, 5.0)
	Co.hongsal_gate(b, 0.0, -hi, 3.8, 5.0)
	cols.append_array(Co.low_wall_loop(b, [Vector2(-ho, -ho), Vector2(ho, -ho), Vector2(ho, ho), Vector2(-ho, ho)], [[0.0, ho, 2.6], [0.0, -ho, 2.6]], 2.2, rng, 0.6))
	Co.hongsal_gate(b, 0.0, ho, 4.4, 5.8)
	var root := b.build("사직단")
	# 동·서 홍살문(옆으로 돌린 것)
	for s in [-1, 1]:
		var sb := Kit.Batch.new()
		Co.hongsal_gate(sb, 0.0, 0.0, 3.8, 5.0)
		var n: Node3D = sb.build("홍살문")
		n.position = Vector3(s * hi, 0, 0); n.rotation.y = PI / 2
		root.add_child(n)
	return {
		node = root, colliders = cols, lights = [], occluder = false, footprint = Vector2(ho * 2 + 1, ho * 2 + 1),
		anchors = { sadan = Vector3(6.2, 0.9, 0), jikdan = Vector3(-6.2, 0.9, 0), gate = Vector3(0, 0, ho), outside = Vector3(0, 0, ho + 3.0) },
	}
