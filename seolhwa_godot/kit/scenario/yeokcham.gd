# 산중 빈 역참(驛站) — S6004~S6010 「돌아오지 않는 전갈」. 함흥→북청 길 함관령 동쪽 숲 기슭, 길에서 비켜 앉은 버려진 역(驛)의 객사 채.
# 관북 겹집(田자) 대신 길가 역 객사: 초가 ㄱ자 없는 一자 다섯 칸(가운데 두 칸 흙바닥 대청·부엌, 양쪽 온돌방) — 이겸이 지내는 방(서쪽 방).
# 둘레: 무너진 마구간(지붕 반쯤 내려앉음), 말 매는 말뚝(PRP_ROAD_006), 쓰러진 역 표목, 부서진 울타리, 장작더미.
# 안의 사건 물건(등잔 deungjan·벽 지도 byeokjido·불탄 기록 jangbu/hwaro·이겸의 기록함 munseoham)은 scenario/props로 따로 놓는다(dy = 마루 높이).
# 그룹 door(앞 방문): SEALED 닫힘 / OPEN 열림(기본) — 들어가 방을 돌아본다(S6005).
# 가설: 함관령 길에 실제 역(함원역·평포역 등)이 있었으나 위치·평면은 확인하지 않음 — 산중 역참은 게임용 배치.
# params: seed
extends RefCounted
const SC := preload("res://kit/scenario/_sc.gd")
const C := preload("res://kit/village/_common.gd")
const PR := preload("res://kit/village/props.gd")

const W := 10.5
const D := 5.0
const F := 0.45

static func build(params: Dictionary) -> Dictionary:
	var s := SC.S.new(int(params.get("seed", 1)))
	var info := SC.shell(s, { W = W, D = D, F = F, H = 2.2, old = true, roof = "choga",
		bays = [{ w = 2.3, kind = "window" }, { w = 2.2, kind = "door" }, { w = 1.5, kind = "open" }, { w = 2.2, kind = "gate" }, { w = 2.3, kind = "window" }],
		camera = { pitch = 55, distance = 12 } })
	var zf: float = info.zf; var zb: float = info.zb; var top: float = info.top
	var R := s.rng
	# 방 칸막이(서쪽 방 | 대청 | 동쪽 방) — 실내에서 방이 읽히게(문 자리 비움)
	for x in [-W / 2 + 4.5, W / 2 - 4.5]:
		s.add("body", "mud", SC.pa(Kit.box(0.14, 2.2, D * 0.55, x, F + 1.1, zb + D * 0.275), SC.MUD_OLD, 0.04, R), 0.015)
		s.add("body", "mud", SC.pa(Kit.box(0.14, 2.2, D * 0.2, x, F + 1.1, zf - D * 0.1), SC.MUD_OLD, 0.04, R), 0.015)
		s.box_c(x - 0.08, x + 0.08, zb, zb + D * 0.55)
		s.box_c(x - 0.08, x + 0.08, zf - D * 0.2, zf)
	# 서쪽 방(이겸): 낡은 이불 자리·벽에 기댄 짐·바닥 종이 — 움직이는 것은 따로
	s.add("interior", "cloth", SC.pa(Kit.box(1.0, 0.08, 1.8, -W / 2 + 0.8, F + 0.04, -0.4), [0x7a6a58, 0x5a4c3e], 0.05), 0.006)
	s.add("interior", "cloth", SC.pa(Kit.xf(C.sphere(0.3, 8, 5), -W / 2 + 0.6, F + 0.25, zb + 0.5, 0, 0, 0, 1.2, 0.8, 1), [0x6a5a48, 0x4a3e30]), 0.008)
	s.add("interior", "wood", SC.pa(Kit.box(0.7, 0.04, 0.4, -W / 2 + 2.6, F + 0.3, zb + 0.5), [0x6a4428]), 0.008)
	for sx in [-1, 1]: s.add("interior", "wood", SC.pa(Kit.box(0.04, 0.28, 0.36, -W / 2 + 2.6 + sx * 0.32, F + 0.14, zb + 0.5), [0x6a4428]), 0.0)
	# 대청·부엌: 아궁이 자리(식은 부뚜막), 흩어진 짚
	s.add("interior", "mud", SC.pa(Kit.box(1.2, 0.55, 0.8, 1.0, F + 0.27, zb + 0.6), [0x9a8462, 0x6e5c44], 0.05, R), 0.015)
	s.box_c(0.4, 1.6, zb + 0.2, zb + 1.0)
	var straw := []
	for k in 10: straw.append(Kit.xf(Kit.box(0.5, 0.02, 0.06), R.between(-1.0, 2.0), F + 0.02, R.between(-1.5, 1.5), 0, R.next() * 3.0, 0))
	s.add("interior", "thatch", SC.pa(Kit.merge(straw), [0xb8a070, 0x8a7650]), 0.0)
	# 바깥: 무너진 마구간(동쪽 옆) — 기둥 넷, 반쯤 내려앉은 지붕, 여물통
	var mx := W / 2 + 3.2
	for q in [[-1.6, -1.4], [1.6, -1.4], [-1.6, 1.4], [1.6, 1.4]]:
		var hh := 2.0 if q[1] < 0 else 1.2
		s.add("yard", "wood", SC.pa(Kit.xf(Kit.box(0.16, hh, 0.16), mx + q[0], hh / 2, q[1], 0, 0, 0.08 * q[0]), SC.WOOD_OLD), 0.012)
		s.circle(mx + q[0], q[1], 0.15)
	var shed := Kit.box(4.0, 0.25, 3.6, 0, 0, 0)
	Kit.apply(shed, Transform3D(Basis(Vector3.RIGHT, -0.32) * Basis(Vector3.FORWARD, 0.12), Vector3(mx, 1.55, 0)))
	s.add("yard", "thatch", SC.pa(shed, [0x8a7a58, 0x5e5240], 0.06, R), 0.02)
	s.add("yard", "wood", SC.pa(Kit.box(2.2, 0.35, 0.5, mx, 0.25, -0.9), [0x6e5a44, 0x4e3e2e]), 0.012)
	s.box_c(mx - 1.1, mx + 1.1, -1.15, -0.65)
	# 말 매는 말뚝(PRP_ROAD_006) 둘 — 빈 말뚝
	for x in [-2.0, -0.8]:
		s.add("yard", "wood", SC.pa(Kit.cyl(0.07, 0.09, 1.1, 6, x, 0.55, zf + 2.6), SC.WOOD_OLD), 0.012)
		s.add("yard", "wood", SC.pa(Kit.cyl(0.08, 0.08, 0.06, 6, x, 0.9, zf + 2.6), [0x3a2e24]), 0.0)
		s.circle(x, zf + 2.6, 0.12)
	# 쓰러진 역 표목(驛 이름판 기둥) + 부서진 울타리
	s.add("yard", "wood", SC.pa(Kit.xf(Kit.box(0.22, 2.4, 0.22), -W / 2 - 1.6, 0.15, zf + 3.2, PI / 2 - 0.1, 0.5, 0), SC.WOOD_OLD), 0.015)
	s.add("yard", "flat", SC.pa(Kit.xf(Kit.box(0.5, 0.02, 1.2), -W / 2 - 1.9, 0.27, zf + 3.0, 0, 0.5, 0), [0xc8b890, 0x9a8a68]), 0.0)
	var fence := []
	for k in 9:
		var fx := -W / 2 - 2.5 + k * 1.3
		var lean := 0.0 if k % 3 else R.between(-0.6, 0.6)
		fence.append(Kit.xf(Kit.cyl(0.04, 0.05, 1.1, 5), fx, 0.5, zf + 4.4, lean, 0, 0))
		if k % 4 != 2: fence.append(Kit.xf(Kit.box(1.3, 0.05, 0.05), fx + 0.65, 0.8 - (0.4 if k == 5 else 0.0), zf + 4.4, 0, 0, 0.3 if k == 5 else 0.0))
	s.add("yard", "wood", SC.pa(Kit.merge(fence), SC.WOOD_OLD), 0.008)
	# 장작더미(눈 덮이면 덩이로 보임)
	s.add("yard", "wood", SC.pa(Kit.box(1.6, 0.8, 0.6, -W / 2 - 0.9, 0.4, zb + 0.6), [0x8a6a48, 0x5e442e], 0.06, R), 0.015)
	s.box_c(-W / 2 - 1.7, -W / 2 - 0.1, zb + 0.3, zb + 0.9)
	# 방문 상태(그룹 door) — 서쪽 방 문(칸 1)은 shell이 열린 창호로 그렸다: 닫힌 모습을 덧씌움
	var dx: float = -W / 2 + 2.3 + 1.1
	var sealed := s.st("door", "SEALED")
	sealed.add("paper", SC.Co.vplane(1.5, 1.8, dx, F + 0.92, zf + 0.07), 0.0)
	sealed.add("wood", SC.pa(Kit.merge([Kit.box(1.55, 0.06, 0.05, dx, F + 1.35, zf + 0.08), Kit.box(1.55, 0.06, 0.05, dx, F + 0.5, zf + 0.08), Kit.box(0.06, 1.8, 0.05, dx, F + 0.92, zf + 0.08)]), SC.WOOD_OLD), 0.0)
	s.st("door", "OPEN", "OPEN")
	s.scol("door", "SEALED", { type = "box", minX = dx - 0.75, maxX = dx + 0.75, minZ = zf - 0.15, maxZ = zf + 0.12 })
	s.anchor("room", Vector3(-W / 2 + 2.2, F, -0.3))
	s.anchor("wall_map", Vector3(-W / 2 + 2.6, F, zb + 0.2))
	s.anchor("hearth", Vector3(1.0, F, zb + 1.3))
	s.anchor("stable", Vector3(mx, 0, 2.2))
	s.anchor("post", Vector3(-1.4, 0, zf + 3.2))
	s.anchor("approach", Vector3(0, 0, zf + 7.0))
	return s.result("빈 역참", Vector2(W + 9.0, D + 10.0))
