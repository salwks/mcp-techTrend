# 석조물 공용: 네모 옥개석(처마 귀가 살짝 들림), 팔각 받침, 연꽃 받침 느낌 띠.
extends RefCounted

const Roof = preload("res://kit/landmark/_roof.gd")

# 네모 옥개석: 밑변 너비 w, 처마 두께 rim, 지붕 높이 h, 꼭대기 너비 tw, 귀 들림 lift. 바닥 y=0
static func okgae4(w: float, rim: float, h: float, tw: float, lift: float) -> Kit.Geo:
	var g := Kit.Geo.new()
	var hw := w / 2; var ht := tw / 2
	var ring0 := []; var ring1 := []; var ring2 := []
	for i in 8:
		var a := PI / 4 * i
		# 8점: 귀(짝수 i) / 변 가운데(홀수)
		var corner := i % 2 == 0
		var cs := [Vector2(hw, hw), Vector2(0, hw), Vector2(-hw, hw), Vector2(-hw, 0), Vector2(-hw, -hw), Vector2(0, -hw), Vector2(hw, -hw), Vector2(hw, 0)]
		var p: Vector2 = cs[i]
		var up := lift if corner else 0.0
		ring0.append(Vector3(p.x, up, p.y))
		ring1.append(Vector3(p.x, rim + up * 0.8, p.y))
		var q := p / hw * ht
		ring2.append(Vector3(q.x, rim + h, q.y))
	for i in 8:
		var j := (i + 1) % 8
		var o: Vector3 = (ring0[i] + ring0[j]) / 2; o.y = 0
		Roof.quad_facing(g, ring0[i], ring0[j], ring1[j], ring1[i], o)
		var o2: Vector3 = o + Vector3(0, hw, 0)
		Roof.quad_facing(g, ring1[i], ring1[j], ring2[j], ring2[i], o2)
		Roof.tri_facing(g, Vector3(0, rim + h, 0), ring2[i], ring2[j], Vector3.UP)
		Roof.tri_facing(g, Vector3(0, 0, 0), ring0[i], ring0[j], Vector3.DOWN)
	return g

# 팔각 기둥/받침(옆면 8각): 반지름(꼭짓점) r0 아래, r1 위, 높이 h, 바닥 y0
static func oct(r0: float, r1: float, h: float, y0: float) -> Kit.Geo:
	return Kit.cyl(r1, r0, h, 8, 0, y0 + h / 2, 0, 0, PI / 8, 0)
