# 장산곶 앞 작은 바위섬 + 숨은 갯구멍(S4006 '실종자는 암초 뒤 작은 섬·해안 틈에 생존'). 배(뱃길 auto)로만 닿는다.
# 원점 = 바다 물 면(y = 0, 배치 y는 노정 sea.y), 바위 덩이 밑은 물속 −0.4m에서 잘린다. 정면 +z = 곶(카메라) 쪽.
# 서남쪽(로컬 −x, +z)에 바위기둥(갯바위 기둥)에 가려진 작은 자갈 갯가와 바위 밑 틈(비 피할 자리) — 걷기 면 walk가 갯가·틈에만 있다
# (그 밖은 바다라 엔진이 막는다). 섬 꼭대기 해송 둘, 둘레 갯바위.
# anchors: landing(배 대는 자갈 끝) · shelter(바위 틈 안 — 실종자 자리) · lookout(꼭대기, 걷지 못함 — 연출용) · cove(갯가 가운데)
# params: seed
extends RefCounted
const SC := preload("res://kit/scenario/_sc.gd")
const Hub := preload("res://kit/landmark/_hub.gd")
const Co := preload("res://kit/landmark/_common.gd")

const ROCK := [0xa29c90, 0x5e5a52]
const ROCK_D := [0x7a746a, 0x46423c]

static func build(params: Dictionary) -> Dictionary:
	var s := SC.S.new(int(params.get("seed", 1)))
	var R := s.rng
	var b := s.p("rock")
	# 섬 몸: 큰 덩이 몇(동쪽·북쪽이 높다)
	Hub.rock(b, R, 4.0, -3.0, 11.0, 9.0, 8.0, ROCK, 2, 0.35, 0.3)
	Hub.rock(b, R, 1.0, -8.0, 7.0, 7.0, 5.5, ROCK, 1, 0.4, 1.2)
	Hub.rock(b, R, 9.0, 3.0, 6.0, 5.0, 5.5, ROCK, 1, 0.4, 2.2)
	Hub.rock(b, R, 1.5, 5.0, 4.5, 3.6, 4.0, ROCK_D, 1, 0.45, 0.8)
	# 갯가 서쪽을 감싸는 낮은 바위(만 모양)
	Hub.rock(b, R, -11.8, -1.0, 3.2, 2.2, 3.0, ROCK_D, 1, 0.4, 0.4)
	Hub.rock(b, R, -11.5, 4.0, 2.4, 1.6, 2.6, ROCK_D, 1, 0.45, 1.4)
	# 바위 기둥(갯가를 곶에서 가린다)
	Hub.rock(b, R, -11.5, 12.5, 1.8, 6.5, 1.8, ROCK, 1, 0.3, 0.2)
	Hub.rock(b, R, -13.0, 14.5, 1.2, 2.0, 1.3, ROCK_D, 0, 0.4, 0.9)
	# 둘레 갯바위
	for k in 10:
		var a := R.next() * TAU
		var rr := R.between(12.0, 16.0)
		var x := cos(a) * rr * 1.1; var z := sin(a) * rr * 0.8
		if x < -4.0 and z > 1.0: continue   # 갯가 앞물길은 비운다
		Hub.rock(b, R, x, z, R.between(0.8, 1.8), R.between(0.4, 1.4), R.between(0.8, 1.6), ROCK_D, 0, 0.45, a)
	# 해송(꼭대기)
	for p in [Vector3(3.0, 8.2, -4.0), Vector3(7.5, 6.8, -1.0)]:
		s.add("rock", "bark", Co.pnt(Kit.limb(p - Vector3(0, 0.8, 0), p + Vector3(0.9, 1.2, 0.2), 0.18, 0.1, 5), [0x6a4a34, 0x4e3628]), 0.015)
		var g := Kit.lump(1.2, 1, R, 0.3, 0.45); Kit.xf(g, p.x + 1.2, p.y + 1.5, p.z + 0.2)
		s.add("rock", "needle", Kit.paint(g, Kit.hex(0x5f7a42), Kit.hex(0x3a5030), 0.08, R), 0.03)
	# 자갈 갯가: 남쪽 물가(y 0.1)에서 북쪽 틈(y 0.6)으로 오르는 판 + 자갈
	var beach := Kit.Geo.new()
	var xs := [-9.6, -3.2]
	var zs := [10.2, 6.0, 2.0]
	var ys := [0.08, 0.35, 0.6]
	for i in 2:
		beach.quad(Vector3(xs[0], ys[i], zs[i]), Vector3(xs[1], ys[i], zs[i]), Vector3(xs[1], ys[i + 1], zs[i + 1]), Vector3(xs[0], ys[i + 1], zs[i + 1]))
	s.add("cove", "rock", SC.pa(beach, [0x8a8478, 0x6a655c], 0.06, R), 0.0)
	var peb := []
	for k in 40:
		var x := R.between(-9.2, -3.6); var z := R.between(2.4, 9.8)
		var y := lerpf(0.6, 0.08, (z - 2.0) / 8.2)
		var g := Kit.lump(R.between(0.08, 0.2), 0, R, 0.3, 0.6)
		Kit.xf(g, x, y + 0.02, z)
		peb.append(Kit.paint(g, Kit.hex(0x9a9488), Kit.hex(0x6a655c), 0.06, R))
	s.add("cove", "rock", Kit.merge(peb), 0.0)
	# 바위 밑 틈(비 피할 자리): 바닥 + 덮인 바위 처마(실내처럼 덮개는 숨김)
	s.add("cove", "rock", SC.pa(Kit.box(4.2, 0.1, 4.4, -6.5, 0.6, 0.0), [0x6a655c, 0x4a4640], 0.06, R), 0.0)
	var over := Kit.lump(1.0, 1, R, 0.25, 0.5)
	Kit.xf(over, -6.5, 2.6, -0.3, 0, 0.4, 0, 3.0, 1.0, 2.6)
	s.add("overhang", "rock", SC.pa(over, ROCK_D, 0.08, R), 0.03)
	# 틈 안: 젖은 거적·꺼진 불자리·조개껍데기(살아 있던 흔적)
	s.add("cove", "thatch", SC.pa(Kit.box(1.1, 0.05, 0.7, -7.2, 0.68, -0.8), [0x8a7a58, 0x5e5240], 0.05), 0.0)
	s.add("cove", "flat", SC.pa(Kit.cyl(0.28, 0.3, 0.03, 8, -5.6, 0.67, 0.6), [0x2a2420]), 0.0)
	for k in 3: s.add("cove", "wood", SC.pa(Kit.xf(Kit.cyl(0.03, 0.03, 0.45, 4), -5.6 + (k - 1) * 0.1, 0.7, 0.6, PI / 2, k * 1.1, 0), [0x3a2e24]), 0.0)
	for k in 6: s.add("cove", "smooth", SC.pa(Kit.xf(C_shell(), -6.0 + R.between(-1.0, 1.0), 0.66, 1.2 + R.between(-0.5, 0.5), 0, R.next() * 3.0, 0), [0xe8e0d0, 0xb8b0a0]), 0.0)
	s.interior = { minX = -8.6, maxX = -4.4, minZ = -2.0, maxZ = 2.2, floor_y = 0.0, camera = { pitch = 58, distance = 10 } }
	s.hide = ["overhang"]
	s.extra.walk = [
		{ minX = -9.4, maxX = -3.6, minZ = 2.0, maxZ = 10.4, z = [2.0, 6.0, 10.4], y = [0.62, 0.37, 0.1] },
		{ minX = -8.5, maxX = -4.5, minZ = -1.9, maxZ = 2.2, z = [-1.9, 2.2], y = [0.65, 0.62] },
	]
	s.anchor("landing", Vector3(-6.0, 0.1, 10.0))
	s.anchor("cove", Vector3(-6.0, 0.35, 6.0))
	s.anchor("shelter", Vector3(-6.6, 0.65, -0.6))
	s.anchor("lookout", Vector3(4.0, 9.0, -3.0))
	return s.result("장산곶 앞 바위섬", Vector2(34.0, 30.0))

static func C_shell() -> Kit.Geo:
	return Kit.xf(Kit.cyl(0.05, 0.06, 0.02, 6), 0, 0, 0, 0.1, 0, 0)
