# 평안감영 기록 창고(문서고) — S5004 '관아 기록창고 침입 흔적'. 감영 뒤뜰의 기와 곳간, 높은 마루(습기 막이), 두꺼운 회벽, 작은 살창.
# 안: 벽 따라 문서 시렁(두루마리·책·문서 묶음), 가운데 문서함·궤짝(scenario/props munseoham — 따로 배치), 서리 책상.
# 그룹 door(정면 널문): SEALED 잠김(자물쇠) / OPEN 열림 / BROKEN 자물쇠 비틀어 연 흔적(문 반쯤 열림)
# 그룹 window(뒤 살창): SEALED / OPEN / BROKEN(살 부러짐 — 침입 자리)
# 가설: 감영 문서고의 실제 평면은 남은 것이 없어 규장각 서고·지방 사고(史庫)의 높은 마루 곳간을 줄여 썼다.
# params: seed
extends RefCounted
const SC := preload("res://kit/scenario/_sc.gd")
const C := preload("res://kit/village/_common.gd")
const Co := preload("res://kit/landmark/_common.gd")

const W := 9.0
const D := 5.4
const F := 0.75

static func build(params: Dictionary) -> Dictionary:
	var s := SC.S.new(int(params.get("seed", 1)))
	var info := SC.shell(s, { W = W, D = D, F = F, H = 2.7, wall = SC.PLASTER, roof = "giwa", no_light = true,
		bays = [{ w = 3.0, kind = "wall" }, { w = 3.0, kind = "open" }, { w = 3.0, kind = "wall" }],
		back_window = { x = -2.4, w = 0.8, h = 0.6, y = 1.4, default = "SEALED" }, camera = { pitch = 56, distance = 12 } })
	var zf: float = info.zf; var zb: float = info.zb; var top: float = info.top
	# 정면 널문(그룹 door): 가운데 칸(폭 3.0, "open")에 상태별 문
	var dw := 2.0; var dh := 2.1
	var fp := s.p("front")
	Co.holed_wall(fp, -1.5, 1.5, F, top, -dw / 2, dw / 2, F, F + dh, zf, 0.18, SC.PLASTER, "mud", s.rng)
	var sealed := s.st("door", "SEALED", "SEALED")
	Co.board_doors(sealed, 0.0, F, dw, dh, zf - 0.04, false, [0x5a4030, 0x3e2c20])
	sealed.add("flat", SC.pa(Kit.box(0.16, 0.08, 0.06, 0, F + dh * 0.5, zf + 0.04), [0xc9a24a, 0x8a6a2a]), 0.004)
	sealed.add("flat", SC.pa(Kit.box(0.1, 0.16, 0.05, 0, F + dh * 0.5 - 0.1, zf + 0.06), [0x3a3633]), 0.0)
	var op := s.st("door", "OPEN")
	Co.board_doors(op, 0.0, F, dw, dh, zf - 0.04, true, [0x5a4030, 0x3e2c20])
	var br := s.st("door", "BROKEN")
	# 한 짝은 닫힘, 한 짝은 반쯤 열림 + 바닥에 떨어진 비틀린 자물쇠
	br.add("wood", SC.pa(Kit.box(dw / 2 - 0.02, dh, 0.08, -dw / 4, F + dh / 2, zf - 0.04), [0x5a4030, 0x3e2c20]), 0.015)
	var leaf := Kit.box(dw / 2, dh, 0.08, -dw / 4, 0, 0)
	Kit.apply(leaf, Transform3D(Basis(Vector3.UP, 0.7), Vector3(dw / 2, F + dh / 2, zf - 0.04)))
	br.add("wood", SC.pa(leaf, [0x5a4030, 0x3e2c20]), 0.015)
	br.add("flat", SC.pa(Kit.xf(Kit.box(0.1, 0.16, 0.05), 0.4, 0.04, zf + 0.9, PI / 2, 0.8, 0), [0x3a3633]), 0.0)
	br.add("flat", SC.pa(Kit.xf(Kit.box(0.04, 0.12, 0.04), -0.02, F + dh * 0.5, zf + 0.05, 0, 0, 0.6), [0xc9a24a]), 0.0)
	s.scol("door", "SEALED", { type = "box", minX = -dw / 2, maxX = dw / 2, minZ = zf - 0.15, maxZ = zf + 0.1 })
	# 문 앞 돌계단(마루 높이)
	for k in 2: s.add("base", "stone", SC.pa(Kit.box(2.0, F * (2 - k) / 2.0, 0.4, 0, F * (2 - k) / 4.0, zf + 0.55 + k * 0.38), SC.STONE), 0.015)
	# 시렁(벽 선반) — 뒷벽(창 자리 비움)·양옆
	_rack(s, 1.4, zb + 0.26, 4.6, 0.0)
	_rack(s, -W / 2 + 0.26, -0.2, 3.6, PI / 2)
	_rack(s, W / 2 - 0.26, -0.2, 3.6, -PI / 2)
	# 서리 책상 자리(낮은 서안) — 움직이는 문서는 따로 배치
	s.add("interior", "wood", SC.pa(Kit.box(1.1, 0.04, 0.5, 2.4, F + 0.32, 1.3), [0x6a4428, 0x4a2e1c]), 0.012)
	for sx in [-1, 1]: s.add("interior", "wood", SC.pa(Kit.box(0.05, 0.3, 0.46, 2.4 + sx * 0.5, F + 0.15, 1.3), [0x6a4428]), 0.0)
	s.box_c(1.85, 2.95, 1.05, 1.55)
	# 처마 밑 현판(문서고 — 가설)
	s.add("front", "wood", SC.pa(Kit.box(1.4, 0.42, 0.06, 0, top - 0.1, zf + 0.25), [0x3a2c22, 0x2c2018]), 0.01)
	s.add("front", "flat", SC.pa(Kit.box(1.15, 0.26, 0.02, 0, top - 0.1, zf + 0.29), [0xe8dcb8]), 0.0)
	s.anchor("chest_spot", Vector3(-0.6, F, 0.0))
	s.anchor("desk", Vector3(2.4, F, 1.9))
	s.anchor("rack", Vector3(1.4, F, zb + 1.0))
	return s.result("기록 창고", Vector2(W + 1.8, D + 2.6))

# 시렁: 두루마리(가로 원통)·책·문서 묶음이 얹힌 3단 선반
static func _rack(s: SC.S, x: float, z: float, w: float, ry: float) -> void:
	var old: Transform3D = s.m.push(x, F, z, ry)
	var h := 1.9; var d := 0.42
	var frame := []
	for sx in [-1, 0, 1]: frame.append(Kit.box(0.06, h, d, sx * (w / 2 - 0.03), h / 2, 0))
	for k in 3: frame.append(Kit.box(w, 0.04, d, 0, 0.35 + k * 0.6, 0))
	s.add("interior", "wood", SC.pa(Kit.merge(frame), [0x5a3e28, 0x3e2a1a], 0.03), 0.012)
	var R := s.rng
	var items := []
	for k in 3:
		var y := 0.37 + k * 0.6
		var bx := -w / 2 + 0.1
		while bx < w / 2 - 0.3:
			var r := R.next()
			if r < 0.45:   # 두루마리 몇
				for j in 3:
					items.append(Kit.paint(Kit.cyl(0.045, 0.045, d * 0.85, 6, bx + 0.05 + j * 0.09, y + 0.05 + (j % 2) * 0.07, 0, PI / 2, 0, 0), Kit.hex(0xe8dcb8), Kit.hex(0xc8b890), 0.03, R))
				bx += 0.3
			elif r < 0.8:  # 문서 묶음(끈으로 묶은 종이 더미)
				items.append(Kit.paint(Kit.box(0.34, 0.16, d * 0.8, bx + 0.17, y + 0.08, 0), Kit.hex(0xd8c9a0), Kit.hex(0xb8a880), 0.04, R))
				items.append(Kit.paint(Kit.box(0.03, 0.17, d * 0.82, bx + 0.17, y + 0.085, 0), Kit.hex(0x8a3a2a), Kit.hex(0x8a3a2a), 0.0, R))
				bx += 0.4
			else:          # 책갑
				items.append(Kit.paint(Kit.box(0.22, 0.24, d * 0.75, bx + 0.11, y + 0.12, 0), Kit.hex(0x3f5f7a), Kit.hex(0x2c4458), 0.03, R))
				bx += 0.26
	s.add("interior", "flat", Kit.merge(items), 0.0)
	s.box_c(-w / 2, w / 2, -d / 2, d / 2)
	s.m.pop(old)
