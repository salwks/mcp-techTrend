# 김녕사굴(金寧蛇窟) 입구 + 걸어 들어가는 용암굴 — S7003~S7006 「굴에 남은 숨」. 기존 landmark/jj_gimnyeongsagul(입구만)을 대신한다.
# 원점 = 굴 가운데(바닥), 굴은 로컬 −z(북)로 뻗고 입구는 +z 끝(남, 카메라 쪽). 길이 L(기본 40m), 폭 4.5~6m로 굽이친다.
# 밖에서 보면 덩굴 덮인 낮은 현무암 등성이(용암굴 지붕) — 실내에 들어가면 지붕(ceiling)·입구 바위(mouth)를 숨기고
# 1.4m 높이로 잘린 굴 벽 안을 내려다본다(인형집 단면).
# 안: 입구 안쪽 옛 제단 돌(제물 자리), 옆 굴(아이가 숨는 자리 niche), 도굴 흔적(파헤친 바닥·깨진 독), 안쪽 막다른 큰 벽(deep_wall — 잔영이 지나는 벽).
# 그룹 shed(PRP_SPEC_007 뱀 허물): NORMAL 있음 / EMPTY 없음. 금줄·제물상·발자국은 따로(scenario/props geumjul·jemul, decals_*.json).
# params: seed, len(40), stele(true: 서련 판관 사적비), interior(true: 실내 공간 region_data/interiors/jj_sagul — 지붕·입구 바위·마당·비석 없이
#   굴 안만, 남쪽 끝은 빛이 드는 출구 자리. 권역 쪽 입구는 landmark/jj_gimnyeongsagul이 그대로 맡는다)
extends RefCounted
const SC := preload("res://kit/scenario/_sc.gd")
const Hub := preload("res://kit/landmark/_hub.gd")
const Co := preload("res://kit/landmark/_common.gd")

const BASALT := [0x4a4642, 0x2a2826]
const BASALT_L := [0x5e5a54, 0x3a3733]
const FLOOR := [0x3a3632, 0x26231f]

# 굴 가운데 선(입구 쪽 6m는 입구와 줄을 맞추려 0으로 모은다 — 기본 길이 40m 기준 z = 12..18)
static func cx_at(z: float) -> float:
	return (1.2 * sin(z * 0.12) + 0.6 * sin(z * 0.31 + 1.0)) * clampf((18.0 - z) / 6.0, 0.0, 1.0)

static func w_at(z: float) -> float:
	return 5.0 + 0.8 * sin(z * 0.23 + 0.5)

static func build(params: Dictionary) -> Dictionary:
	var s := SC.S.new(int(params.get("seed", 1)))
	var R := s.rng
	var L: float = float(params.get("len", 40.0))
	var indoor_space := bool(params.get("interior", false))
	var z0 := -L / 2; var z1 := L / 2 - 0.8      # 굴 안쪽 끝 / 입구 안쪽
	var step := 1.25
	# --- 바닥: 굽이치는 띠(조금 울퉁불퉁), 용암 줄무늬 ---
	var fl := Kit.Geo.new()
	var n := int((z1 - z0) / step)
	for i in n:
		var za := z0 + i * step; var zb := za + step
		var ca := cx_at(za); var cb := cx_at(zb); var wa := w_at(za) * 0.5 + 0.3; var wb := w_at(zb) * 0.5 + 0.3
		# 위를 보는 면(Kit.plane과 같은 순서: 남쪽(+z) 변에서 북쪽 변으로)
		fl.quad(Vector3(cb - wb, 0.02, zb), Vector3(cb + wb, 0.02, zb), Vector3(ca + wa, 0.02, za), Vector3(ca - wa, 0.02, za))
	s.add("floor_in", "rock", SC.pa(fl, FLOOR, 0.06, R), 0.0)
	var ropes := []
	for i in int(n * 0.8):
		var z := s.between(z0 + 1, z1 - 1)
		ropes.append(Kit.xf(Kit.box(s.between(0.6, 1.6), 0.03, 0.08), cx_at(z) + s.between(-1.5, 1.5), 0.04, z, 0, s.between(-0.4, 0.4), 0))
	s.add("floor_in", "flat", SC.pa(Kit.merge(ropes), [0x2a2724, 0x1e1c1a]), 0.0)
	# --- 벽(잘린 높이 1.4m 덩이) + 지붕(밖에서 보이는 등성이, 실내에서 숨김) ---
	var walls := []; var ceil := []; var vines := []
	var cols := []
	for i in n + 1:
		var z := z0 + i * step
		var c := cx_at(z); var hw := w_at(z) * 0.5
		for sx in [-1, 1]:
			var g := Kit.lump(1.0, 1 if i % 2 == 0 else 0, R, 0.25, 1.0)
			Kit.xf(g, c + sx * (hw + 0.55), 0.55, z, 0, R.next() * 3.0, 0, 0.9, 0.95, 0.9)
			walls.append(Kit.paint(g, Kit.hex(BASALT[0]), Kit.hex(BASALT[1]), 0.08, R))
			if i % 2 == 0: cols.append([c + sx * (hw + 0.55), z, 0.95])
		# 지붕: 굴을 덮는 넓적한 덩이(밖에서 등성이)
		if i % 2 == 0:
			var t := Kit.lump(1.0, 1, R, 0.22, 0.45)
			Kit.xf(t, c, 1.9, z, 0, R.next() * 3.0, 0, hw + 1.6, 1.2, 1.6)
			ceil.append(Kit.paint(t, Kit.hex(BASALT_L[0]), Kit.hex(BASALT_L[1]), 0.08, R))
			if R.next() < 0.6:
				var v := Kit.lump(s.between(0.6, 1.1), 1, R, 0.3, 0.55)
				Kit.xf(v, c + s.between(-hw, hw), 2.5, z + s.between(-0.6, 0.6))
				vines.append(Kit.paint(v, Kit.hex(0x6f8a4a), Kit.hex(0x3e5a32), 0.08, R))
	s.add("walls", "rock", Kit.merge(walls), 0.03)
	if not indoor_space:
		s.add("ceiling", "rock", Kit.merge(ceil), 0.04)
		s.add("ceiling", "leaf", Kit.merge(vines), 0.02)
	for q in cols: s.circle(q[0], q[1], q[2])
	# 안쪽 끝 막는 벽
	var endw := Kit.lump(1.0, 1, R, 0.2, 1.0)
	Kit.xf(endw, cx_at(z0), 0.7, z0 - 0.8, 0, 0, 0, w_at(z0) * 0.6, 1.2, 1.0)
	s.add("walls", "rock", SC.pa(endw, BASALT, 0.08, R), 0.03)
	s.box_c(cx_at(z0) - 3.5, cx_at(z0) + 3.5, z0 - 1.8, z0 - 0.2)
	var zm := L / 2 - 0.6
	if indoor_space:
		# 실내 공간: 남쪽 끝은 출구 — 빛이 드는 바닥 한 장과 양옆 바위, 그 너머는 막는다(나가기는 interior.json exits)
		s.add("floor_in", "flat", SC.pa(Kit.xf(Kit.box(3.6, 0.02, 1.6), 0.0, 0.035, zm - 0.2), [0xb8b09a, 0x9a927e]), 0.0)
		for sx in [-1, 1]:
			var g := Kit.lump(1.1, 1, R, 0.25, 1.2)
			Kit.xf(g, sx * 2.6, 0.7, zm + 0.4)
			s.add("walls", "rock", Kit.paint(g, Kit.hex(BASALT[0]), Kit.hex(BASALT[1]), 0.08, R), 0.03)
		s.box_c(-4.0, 4.0, zm + 0.9, zm + 2.5)
		s.box_c(-4.5, -1.9, zm - 0.6, zm + 1.2)
		s.box_c(1.9, 4.5, zm - 0.6, zm + 1.2)
		s.anchor("mouth", Vector3(0, 0, zm - 0.4))
		s.anchor("exit_light", Vector3(0, 2.2, zm + 0.4))
	else:
		# --- 입구(기존 사굴 입구 모양): 바위 얼굴·어두운 아가리·둔덕은 실내에서 숨김(mouth), 바깥 돌·비석은 남김(yard) ---
		var old: Transform3D = s.m.push(0, 0, zm)
		var fz: float = Hub.cave_mouth(s.p("mouth"), R, 5.0, 3.0, [0x6a665e, 0x3a3733], Vector3(16, 3.6, 10))
		s.add("yard", "mud", Co.pnt(Kit.box(6.0, 0.05, 3.0, 0, 0.02, fz + 1.4), [0x4a4238, 0x3a332c], 0.05, R), 0.0)
		for k in 8:
			var a := R.between(-0.3, PI + 0.3)
			Hub.rock(s.p("yard"), R, cos(a) * R.between(4.0, 7.5), fz + 0.6 + sin(a) * R.between(0.5, 2.0) - 1.0, R.between(0.5, 1.1), R.between(0.3, 0.7), R.between(0.5, 1.0), Hub.BASALT, 0, 0.35, a)
		if params.get("stele", true):
			Hub.stele(s.p("yard"), R, 5.5, fz + 4.0, 1.4, 0.55, false, -0.3)
			s.circle(5.5, fz + 4.0, 0.6)
			s.anchor("stele", Vector3(5.5, 0, fz + 5.2))
		s.box_c(-8.0, -2.6, -5.0, fz)
		s.box_c(2.6, 8.0, -5.0, fz)
		s.anchor("mouth", Vector3(0, 0, fz + 1.0))
		s.anchor("outside", Vector3(0, 0, fz + 5.0))
		s.anchor("rope", Vector3(0, 0, fz + 0.4))
		s.m.pop(old)
	# --- 굴 안 ---
	# 옛 제단 돌(입구 안쪽 오른편) — 제물상은 따로
	var az := zm - 7.0
	s.add("inner", "stone", SC.pa(Kit.box(1.4, 0.5, 0.8, cx_at(az) + 1.4, 0.25, az), [0x6e6a62, 0x4a4640], 0.06, R), 0.02)
	s.box_c(cx_at(az) + 0.7, cx_at(az) + 2.1, az - 0.4, az + 0.4)
	s.anchor("altar", Vector3(cx_at(az) + 1.4, 0.5, az + 0.9))
	# 옆 굴(niche): 오른쪽 벽이 움푹 — 낮은 천장 바위 + 안쪽 어둠
	var nz := -2.0
	var nx := cx_at(nz) + w_at(nz) * 0.5 + 0.2
	s.add("inner", "flat", SC.pa(Kit.box(1.6, 0.03, 1.6, nx + 0.5, 0.03, nz), [0x141210]), 0.0)
	s.anchor("niche", Vector3(nx - 0.4, 0, nz))
	# 도굴 흔적: 파헤친 흙 더미·구덩이·깨진 독·버린 곡괭이 자루
	var dz := -9.0
	var dx := cx_at(dz) - 1.2
	s.add("inner", "flat", SC.pa(Kit.cyl(0.6, 0.5, 0.02, 9, dx, 0.04, dz), [0x141210]), 0.0)
	var dirt := Kit.lump(0.7, 1, R, 0.3, 0.4)
	Kit.xf(dirt, dx + 1.0, 0.05, dz + 0.3)
	s.add("inner", "organic", SC.pa(dirt, [0x5a4a3a, 0x3a3026], 0.06, R), 0.01)
	for k in 5: s.add("inner", "onggi", SC.pa(Kit.xf(Kit.box(0.16, 0.03, 0.12), dx - 0.4 + k * 0.25, 0.04, dz + 0.8 + (k % 2) * 0.2, 0.3, k, 0.2), [0x8a5a3a, 0x5a3a26]), 0.0)
	s.add("inner", "wood", SC.pa(Kit.xf(Kit.cyl(0.025, 0.025, 1.0, 5), dx + 0.3, 0.04, dz - 0.6, PI / 2, 0.8, 0), [0x8a6a48]), 0.0)
	s.circle(dx + 1.0, dz + 0.3, 0.6)
	s.anchor("dig", Vector3(dx, 0, dz + 1.2))
	# 안쪽 큰 벽(잔영이 지나가는 벽) — 매끈한 용암 벽면 한 장
	var ez := z0 + 3.0
	s.add("walls", "rock", SC.pa(Kit.xf(Kit.box(0.4, 2.2, 5.0), cx_at(ez) - w_at(ez) * 0.5 - 0.1, 1.1, ez, 0, 0, -0.08), [0x3e3a36, 0x2a2724], 0.04, R), 0.02)
	s.anchor("deep_wall", Vector3(cx_at(ez) - w_at(ez) * 0.5 + 1.2, 0, ez))
	s.anchor("deep", Vector3(cx_at(z0 + 2.0), 0, z0 + 2.0))
	# 뱀 허물(그룹 shed)
	var sh := s.st("shed", "NORMAL", "NORMAL")
	s.states.shed.append("EMPTY")
	var hz := -15.0
	var skin := Kit.Geo.new()
	for k in 14:
		var t := float(k) / 13.0
		var a := Vector3(cx_at(hz) + 1.5 + sin(t * 6.0) * 0.5, 0.05, hz - 1.5 + t * 3.0)
		var b := Vector3(cx_at(hz) + 1.5 + sin((t + 0.077) * 6.0) * 0.5, 0.05, hz - 1.5 + (t + 0.077) * 3.0)
		skin = Kit.merge([skin, Kit.limb(a, b, 0.07, 0.065, 5)])
	sh.add("organic", SC.pa(skin, [0xd8d0b0, 0xb8ae8c], 0.05), 0.0)
	s.anchor("shed", Vector3(cx_at(hz) + 1.5, 0, hz + 2.0))
	# 굴 안은 어둡다(dark — region_main이 해·하늘빛을 줄이고, 이야기가 등불을 켜면 플레이어 곁 불빛). 지붕(ceiling)을 숨겨도
	# 햇빛이 바닥에 들지 않게 한다. near_fade=false: 카메라 앞 12m 안을 점무늬로 비우는 가림(occ_near)을 굴 안에서는 끈다 —
	# 실내 카메라(12.5m)가 굴 바닥·벽을 그 거리 안에 두어 바닥에 쐐기 모양 구멍이 뚫리고 겉 지형이 비쳤다
	s.interior = { minX = -5.2, maxX = 5.2, minZ = z0 - 0.2, maxZ = zm - 1.5, floor_y = 0.0, camera = { pitch = 60, distance = 12.5 }, dark = 0.92, near_fade = false }
	if indoor_space:
		s.interior.dark = 0.92
		s.interior.maxZ = zm + 0.4
		s.hide = []
	else:
		s.hide = ["ceiling", "mouth"]
	return s.result("김녕사굴", Vector2(17.0, L + 6.0))
