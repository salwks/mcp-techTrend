# 책쾌의 책방 — 종로 피맛골 뒷줄의 작은 기와 가게(정면 3칸 · 측면 1칸 반, 마루). S1002 「비어 있는 책방」, S8007 책쾌 방.
# 앞: 가운데 칸 열린 덧문(가게), 양옆 창. 안: 뒷벽·옆벽 책장(책 가득), 바닥 책 더미·종이 묶음, 대들보에 매단 책 보따리.
# 뒤창(그룹 window: SEALED 닫힘 / OPEN 열림 / BROKEN 부서짐) — S1002 '열린 뒤창', 창밖은 뒷골목(피맛골 뒷길).
# 책상·먹통·찻잔·끈·찢긴 종이처럼 사건이 바꾸는 소품은 따로 배치한 scenario/props 항목(dy = 마루 높이)으로 놓는다.
# 1870년 무렵 책쾌(책 거간)는 가게 없이 책을 지고 다니는 경우가 많았다 → 여기서는 거간이 책을 쌓아 두는 '책 가게 겸 거처'(가설).
# params: seed
extends RefCounted
const SC := preload("res://kit/scenario/_sc.gd")
const C := preload("res://kit/village/_common.gd")

const W := 7.2
const D := 4.6
const F := 0.45

static func build(params: Dictionary) -> Dictionary:
	var s := SC.S.new(int(params.get("seed", 1)))
	var info := SC.shell(s, { W = W, D = D, F = F, H = 2.35, wall = SC.PLASTER, roof = "giwa",
		bays = [{ w = 2.2, kind = "window" }, { w = 2.8, kind = "shutter" }, { w = 2.2, kind = "window" }],
		back_window = { x = 1.6, w = 0.9, h = 0.75, y = 0.95, default = "SEALED" }, camera = { pitch = 55, distance = 10.5 } })
	var R := s.rng
	var zb: float = info.zb; var zf: float = info.zf
	# 책장: 뒷벽(창 자리 비움) + 왼쪽 옆벽
	_shelf(s, -1.9, zb + 0.24, 2.4, 0.0)
	_shelf(s, -W / 2 + 0.24, -0.4, 2.6, PI / 2)
	_shelf(s, W / 2 - 0.24, 0.1, 1.6, -PI / 2)
	# 바닥 책 더미·종이 묶음(움직이지 않는 것)
	var cols := [0x8a6a40, 0x3f5f7a, 0x6a3a2a, 0xd8c9a0, 0xa88a58]
	var stacks := []
	for q in [[-2.6, 0.9], [-2.2, 1.3], [2.7, -1.0], [2.6, 1.2], [0.6, -1.5]]:
		var n := 3 + int(s.r() * 6)
		for i in n:
			var col: int = cols[(i + int(q[0] * 3)) % cols.size()]
			stacks.append(Kit.paint(Kit.xf(Kit.box(0.24, 0.04, 0.32), q[0] + (s.r() - 0.5) * 0.04, F + 0.02 + i * 0.042, q[1] + (s.r() - 0.5) * 0.04, 0, (s.r() - 0.5) * 0.3, 0), Kit.hex(col), Kit.hex(col), 0.03))
	s.add("interior", "flat", Kit.merge(stacks), 0.0)
	# 종이 묶음(끈으로 묶은 한지 뭉치) 둘
	for q in [[2.2, 1.5], [-1.0, -1.4]]:
		s.add("interior", "flat", C.P(Kit.box(0.5, 0.18, 0.36, q[0], F + 0.09, q[1]), 0xece2c6, 0xd8ccac), 0.006)
		s.add("interior", "thatch", C.P(Kit.box(0.04, 0.19, 0.38, q[0], F + 0.095, q[1]), 0x9d8656), 0.0)
	# 대들보에 매단 책 보따리(보자기)
	s.add("interior", "cloth", C.P(Kit.xf(C.sphere(0.25, 8, 5), -0.6, info.top - 0.55, -0.6, 0, 0, 0, 1.2, 0.8, 1), 0x3f5f7a, 0x2c4458), 0.01)
	s.add("interior", "thatch", C.P(Kit.cyl(0.01, 0.01, 0.5, 4, -0.6, info.top - 0.2, -0.6), 0x9d8656), 0.0)
	# 앞 처마 밑 책 간판(서책 書冊) — 가설
	s.add("front", "wood", C.P(Kit.box(1.3, 0.38, 0.06, 0, info.top - 0.15, zf + 0.25), 0x3a2c22, 0x2c2018), 0.01)
	s.add("front", "flat", C.P(Kit.box(1.05, 0.22, 0.02, 0, info.top - 0.15, zf + 0.29), 0xe8dcb8), 0.0)
	s.anchor("desk", Vector3(-0.4, F, -0.2))
	s.anchor("shelf", Vector3(-1.9, F, zb + 0.9))
	s.anchor("counter", Vector3(0.0, F, zf - 0.6))
	s.light(-1.0, F + 1.2, 0.0, "lantern")
	return s.result("책방", Vector2(W + 1.8, D + 2.0))

# 책장(높이 1.8): 중심 (x,z), 폭 w, ry(0이면 앞 +z)
static func _shelf(s: SC.S, x: float, z: float, w: float, ry: float) -> void:
	var h := 1.8; var d := 0.34
	var old: Transform3D = s.m.push(x, F, z, ry)
	var frame := []
	for sx in [-1, 1]: frame.append(Kit.box(0.05, h, d, sx * (w / 2 - 0.025), h / 2, 0))
	for k in 5: frame.append(Kit.box(w, 0.035, d, 0, 0.05 + k * (h - 0.05) / 4, 0))
	s.add("interior", "wood", C.P(Kit.merge(frame), 0x6a4428, 0x4a2e1c), 0.012)
	var cols := [0x8a6a40, 0x3f5f7a, 0x6a3a2a, 0xd8c9a0, 0x5a6a48, 0xa88a58]
	var books := []
	for k in 4:
		var y := 0.07 + k * (h - 0.05) / 4
		var bx := -w / 2 + 0.07
		var i := 0
		while bx < w / 2 - 0.16:
			if s.r() < 0.12:   # 눕혀 쌓은 책
				for j in 3: books.append(Kit.paint(Kit.box(0.22, 0.035, d * 0.8, bx + 0.11, y + 0.02 + j * 0.037, 0), Kit.hex(cols[(i + j) % 6]), Kit.hex(cols[(i + j) % 6]), 0.03))
				bx += 0.26
			else:
				var bw := s.between(0.07, 0.11); var bh := s.between(0.24, 0.33)
				books.append(Kit.paint(Kit.box(bw, bh, d * 0.8, bx + bw / 2, y + bh / 2, 0), Kit.hex(cols[(k * 5 + i) % 6]), Kit.hex(cols[(k * 5 + i) % 6]), 0.03))
				bx += bw + 0.006
			i += 1
	s.add("interior", "flat", Kit.merge(books), 0.0)
	s.box_c(-w / 2, w / 2, -d / 2, d / 2)
	s.m.pop(old)
