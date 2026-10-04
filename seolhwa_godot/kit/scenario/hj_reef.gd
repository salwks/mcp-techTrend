# 암초(여) — 물 위로 조금 드러난 갯바위 무리 + 둘레 흰 물거품 띠. 장산곶 앞 바위섬 둘레(S4006 '암초 뒤 작은 섬').
# 원점 = 바다 물 면(y = 0). 바다 위라 충돌체는 없다(엔진이 바다를 막는다 — 뱃길은 암초 사이로 낸다).
# params: seed, n(바위 수, 기본 3), r(퍼짐 반지름 m, 기본 3)
extends RefCounted
const SC := preload("res://kit/scenario/_sc.gd")
const Hub := preload("res://kit/landmark/_hub.gd")

static func build(params: Dictionary) -> Dictionary:
	var s := SC.S.new(int(params.get("seed", 1)))
	var R := s.rng
	var n := int(params.get("n", 3)); var rr := float(params.get("r", 3.0))
	var foam := []
	for k in n:
		var a := R.next() * TAU; var d := R.next() * rr
		var x := cos(a) * d; var z := sin(a) * d
		var sx := R.between(0.6, 1.6); var sy := R.between(0.3, 1.2)
		Hub.rock(s.p("rock"), R, x, z, sx, sy, sx * R.between(0.7, 1.2), [0x6e6a62, 0x3e3a36], 0, 0.45, a)
		# 물거품 띠(납작한 고리)
		var ring := Kit.Geo.new()
		var seg := 10
		for i in seg:
			var a0 := TAU * i / seg; var a1 := TAU * (i + 1) / seg
			var r0 := sx * 1.05; var r1 := sx * 1.45
			ring.quad(Vector3(x + cos(a0) * r1, 0.03, z + sin(a0) * r1), Vector3(x + cos(a0) * r0, 0.03, z + sin(a0) * r0),
				Vector3(x + cos(a1) * r0, 0.03, z + sin(a1) * r0), Vector3(x + cos(a1) * r1, 0.03, z + sin(a1) * r1))
		foam.append(ring)
	s.add("rock", "flat", SC.pa(Kit.merge(foam), [0xe8ecea, 0xd8dedc], 0.04), 0.0)
	return s.result("암초", Vector2(rr * 2 + 2, rr * 2 + 2), false)
