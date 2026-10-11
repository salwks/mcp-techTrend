# 춘향 「남원의 약속」 차림 키트(seolhwa/docs/production/CHUNHYANG_ASSETS_PLACEMENT_v1.0.md §2) — kind로 고른다. 원점 = 바닥 중심.
#   지금 지을 수 있는 kind: has_kind() 목록. 아직 없는 kind(그네·씨름판·보계·교의·형틀·차일·가마)는 배치 항목의 placeholder로 대신한다
#   (placement_loader._resolve_placeholder).
#
#   kind "ok" — 옥(獄, 원옥). 남원 관아 바깥마당 서쪽의 늘 있는 고을 시설(사용자 결정 2, 2026-10-11).
#     둥근 담(돌 아랫단 + 흙담 + 기와 덮개, 반지름 r) · 동쪽(+x) 작은 기와 문 · 북쪽 반의 초가 옥사(세 칸, 앞(+z, 남쪽)이 나무살).
#     앞이 남쪽이라 평소 시점(남→북, yaw 0)에서 나무살과 칸 안이 정면으로 보이고, 12A(살 너머 춘향)도 남쪽 마당에서 북쪽을 본다.
#     상태(prop_states — 배치 id/그룹): "gate"(바깥 문 SEALED 닫힘 / OPEN 열림) · "cell"(가운데 칸 살문 SEALED / OPEN). 기본 둘 다 SEALED.
#       닫힌 문·살문은 충돌체가 있고 열면 빠진다. 예: world.set_prop_state("ti_jail/gate", "OPEN")
#     앵커: cell(가운데 칸 안) · bars_out(살 앞 마당) · gate_in · gate_out · lamp(문 안 등롱 자리)
#     params: r(담 반지름, 기본 5.0) · cell_w(옥사 너비, 기본 5.0) · cell_d(옥사 깊이, 기본 3.4) · seed
#
#   kind "swing" — 단오 그네(광한루원 북서). 기둥 둘(x ±span/2) · 가로대(높이 h, x 방향) · 색천. 줄 둘과 발판은 부분 "seat" —
#     사건 스크립트가 가로대(앵커 pivot)를 축으로 x축 둘레로 돌려 흔든다(남북으로 오간다 — 동쪽에서 보는 1A·1B에 옆으로 보인다).
#     앵커: pivot(가로대 가운데) · seat(발판 위). params: h(기본 8.5) · span(기본 6.0) · cloth(색천, 기본 true)
#   kind "fan" — 땅에 떨어진 접부채(방자, §5). 반쯤 펼친 부챗살 + 한지. params: r(기본 0.32)
#   kind "ssireum_ring" — 씨름판: 모래 원판 + 짚 새끼 테. params: r(기본 3.5)
extends RefCounted

const C := preload("res://kit/village/_common.gd")
const SC := preload("res://kit/scenario/_sc.gd")

const KINDS := ["ok", "swing", "ssireum_ring", "fan"]
const BAR := [0x5a4330, 0x3c2c1e]        # 옥 나무살 — 짙은 통나무
const BAR_RAIL := [0x6b5038, 0x4a3726]
const STRAW_MAT := [0xc9b27a, 0x9c8656]
const WALL_MUD := [0xc8b089, 0x9c8562]
const DARK_IN := [0x3a2f26, 0x2a221b]    # 칸 안 그늘(뒤 벽 안쪽)

static func has_kind(k: String) -> bool:
	return k in KINDS

static func build(params: Dictionary) -> Dictionary:
	var kind := String(params.get("kind", ""))
	match kind:
		"ok": return _ok(params)
		"swing": return _swing(params)
		"ssireum_ring": return _ssireum(params)
		"fan": return _fan(params)
	push_warning("story/chunhyang: 아직 없는 kind " + kind)
	var m := C.M.new(1)
	m.add("p", "flat", C.P(Kit.box(0.3, 0.3, 0.3, 0, 0.15, 0), 0x777777), 0.02)
	return m.result("춘향_" + kind, Vector2(0.5, 0.5), false)

# ---------------------------------------------------------------------------
# 옥(원옥)
# ---------------------------------------------------------------------------
static func _ok(P: Dictionary) -> Dictionary:
	var s := SC.S.new(int(P.get("seed", 3301)))
	var R := s.rng
	var r := float(P.get("r", 5.0))
	var cw := float(P.get("cell_w", 5.0))
	var cd := float(P.get("cell_d", 3.4))
	var gate_hw := 0.9          # 문 반폭(z)
	var wall_t := 0.42
	var wall_h := 2.45
	# --- 둥근 담: 토막을 원으로 이어 쌓는다(문 자리는 비운다) ---
	var n := 44
	var seg_len := TAU * r / n * 1.06
	var gate_a := asin(clampf((gate_hw + 0.25) / r, 0.0, 1.0))
	var stones := []; var muds := []; var caps := []; var caps_dark := []
	for i in n:
		var a := (i + 0.5) * TAU / n            # 0 = +x(동쪽)
		var da := wrapf(a, -PI, PI)
		if absf(da) < gate_a: continue
		var cx := cos(a) * r; var cz := sin(a) * r
		var ry := -a + PI / 2                    # 토막 길이 방향 = 원의 접선
		stones.append(Kit.box(seg_len, 0.95, wall_t + 0.08, cx, 0.47, cz, ry))
		muds.append(Kit.box(seg_len, wall_h - 0.95, wall_t, cx, 0.95 + (wall_h - 0.95) / 2, cz, ry))
		caps.append(Kit.box(seg_len * 1.02, 0.12, wall_t + 0.34, cx, wall_h + 0.06, cz, ry))
		caps_dark.append(Kit.box(seg_len * 1.02, 0.07, 0.14, cx, wall_h + 0.15, cz, ry))
		s.circle(cx, cz, wall_t * 0.75)
	s.add("wall", "stone", SC.pa(Kit.merge(stones), C.STONE, 0.07, R), 0.0)   # 토막 이음매에 먹선이 서지 않게(둘레 먹선은 덮개가 낸다)
	s.add("wall", "mud", SC.pa(Kit.merge(muds), WALL_MUD, 0.05, R), 0.0)
	s.add("wall", "tile", C.P(Kit.merge(caps), 0x6a6c70, 0x4a4c50, 0.03), 0.025)
	s.add("wall", "flat", C.P(Kit.merge(caps_dark), C.ROOF_DARK, 0x2d2e30, 0.02), 0.0)
	# --- 동쪽 문: 기둥 둘 · 인방 · 작은 기와 맞배(용마루가 담을 따라 z 방향) ---
	var gx := r
	var post_h := 2.7
	for sz in [-1, 1]:
		s.add("gate", "wood", SC.pa(Kit.box(0.24, post_h, 0.24, gx, post_h / 2, sz * (gate_hw + 0.12)), SC.WOOD, 0.03, R), 0.02)
		s.add("gate", "stone", SC.pa(Kit.box(0.42, 0.18, 0.42, gx, 0.09, sz * (gate_hw + 0.12)), C.STONE, 0.05, R), 0.02)
		s.circle(gx, sz * (gate_hw + 0.12), 0.2)
	s.add("gate", "wood", SC.pa(Kit.box(0.26, 0.22, gate_hw * 2 + 0.6, gx, post_h - 0.05, 0), SC.WOOD, 0.03, R), 0.02)
	s.add("gate", "wood", SC.pa(Kit.box(0.3, 0.12, gate_hw * 2 + 0.2, gx, 0.06, 0), SC.WOOD, 0.03, R), 0.015)   # 문지방
	var old: Transform3D = s.m.push(gx, 0.0, 0.0, PI / 2)
	C.tile_roof(s.m, "gate", gate_hw + 0.75, 0.95, post_h + 0.12, 0.62, 10, 4, 0.18, 2.4)
	s.m.pop(old)
	# 문짝: 닫힘(두 짝이 문을 막음) / 열림(안쪽으로 젖혀 담 안쪽에 붙음)
	var leaf_w := gate_hw
	var shut := s.st("gate", "SEALED", "SEALED")
	for sz in [-1, 1]:
		var zc: float = sz * leaf_w / 2
		shut.add("wood", SC.pa(Kit.box(0.08, 2.15, leaf_w - 0.03, gx, 1.2, zc), [0x6e5236, 0x4e3a26], 0.04, R), 0.02)
		for yb in [0.55, 1.2, 1.85]:   # 띠장
			shut.add("wood", SC.pa(Kit.box(0.04, 0.1, leaf_w - 0.1, gx - 0.06, yb, zc), SC.WOOD, 0.03, R), 0.01)
	shut.add("flat", C.P(Kit.box(0.06, 0.1, 0.34, gx - 0.08, 1.15, 0), 0x2a2420), 0.01)   # 빗장
	s.scol("gate", "SEALED", { type = "box", minX = gx - 0.25, maxX = gx + 0.25, minZ = -gate_hw, maxZ = gate_hw })
	var open := s.st("gate", "OPEN")
	for sz in [-1, 1]:
		var hz: float = sz * gate_hw
		open.add("wood", SC.pa(Kit.box(leaf_w - 0.03, 2.15, 0.08, gx - leaf_w / 2 - 0.05, 1.2, hz - sz * 0.08), [0x6e5236, 0x4e3a26], 0.04, R), 0.02)
	# --- 옥사(북쪽 반): 앞(+z) = 나무살, 뒤·옆 = 흙벽, 초가 맞배(용마루 x 방향) ---
	var z_front := 0.55
	var z_back := z_front - cd
	var zc_b := (z_front + z_back) / 2
	var hx := cw / 2
	var base_h := 0.28
	var top := base_h + 2.05
	s.add("cell", "stone", SC.pa(Kit.box(cw + 0.5, base_h, cd + 0.4, 0, base_h / 2 - 0.02, zc_b), C.STONE, 0.06, R), 0.03)
	# 칸 안 바닥(흙 + 짚자리)과 안쪽 그늘(살 너머가 비어 보이지 않게 — 뒤 벽 안쪽을 어둡게)
	s.add("cell", "mud", SC.pa(Kit.box(cw - 0.2, 0.04, cd - 0.25, 0, base_h + 0.02, zc_b), [0x7a6650, 0x5e4e3c], 0.04, R), 0.0)
	for k in 3:
		var x := -hx + cw * (k + 0.5) / 3.0
		s.add("cell", "thatch", SC.pa(Kit.box(cw / 3.0 - 0.5, 0.05, 1.3, x + (R.next() - 0.5) * 0.2, base_h + 0.05, z_back + 1.0, (R.next() - 0.5) * 0.15), STRAW_MAT, 0.06, R), 0.0)
	s.add("cell", "flat", C.P(Kit.box(cw - 0.25, top - base_h - 0.1, 0.04, 0, (top + base_h) / 2, z_back + 0.2), DARK_IN[0], DARK_IN[1], 0.02), 0.0)
	# 뒤·옆 흙벽 + 칸막이(두꺼운 판벽)
	s.add("cell", "mud", SC.pa(Kit.box(cw + 0.12, top - base_h, 0.22, 0, (top + base_h) / 2, z_back + 0.05), WALL_MUD, 0.05, R), 0.025)
	for sx in [-1, 1]:
		s.add("cell", "mud", SC.pa(Kit.box(0.22, top - base_h, cd - 0.05, sx * hx, (top + base_h) / 2, zc_b), WALL_MUD, 0.05, R), 0.025)
	for k in [1, 2]:
		var x: float = -hx + cw * k / 3.0
		s.add("cell", "wood", SC.pa(Kit.box(0.12, top - base_h, cd - 0.4, x, (top + base_h) / 2, zc_b - 0.1), [0x5e4630, 0x463424], 0.04, R), 0.02)
	# 기둥(앞 넷·뒤 둘)과 도리
	for k in 4:
		var x: float = -hx + cw * k / 3.0
		s.add("cell", "wood", SC.pa(Kit.box(0.22, top - base_h + 0.1, 0.22, x, (top + base_h) / 2 + 0.05, z_front), SC.WOOD, 0.03, R), 0.02)
	s.add("cell", "wood", SC.pa(Kit.box(cw + 0.4, 0.2, 0.24, 0, top + 0.08, z_front), SC.WOOD, 0.03, R), 0.02)
	s.add("cell", "wood", SC.pa(Kit.box(cw + 0.4, 0.2, 0.24, 0, top + 0.08, z_back + 0.05), SC.WOOD, 0.03, R), 0.02)
	# 나무살: 굵은 통나무 살(지름 0.1, 사이 0.13) + 아래·가운데·위 가로대. 가운데 칸 살문은 상태로
	var bar_r := 0.055
	var gap := 0.235
	var door_hw := 0.48
	var bars_fixed := []
	var door_bars := []
	for k in 3:
		var x0 := -hx + cw * k / 3.0 + 0.16
		var x1 := -hx + cw * (k + 1) / 3.0 - 0.16
		var nb := int((x1 - x0) / gap) + 1
		for b in nb:
			var x := x0 + (x1 - x0) * b / maxf(1.0, nb - 1)
			var g := Kit.cyl(bar_r, bar_r * 1.1, top - base_h, 6, x, (top + base_h) / 2, z_front + 0.02)
			if k == 1 and absf(x) < door_hw: door_bars.append(g)
			else: bars_fixed.append(g)
	s.add("cell", "wood", SC.pa(Kit.merge(bars_fixed), BAR, 0.06, R), 0.022)
	var rails := []
	for yb in [base_h + 0.18, base_h + 1.05, top - 0.22]:
		for seg in [[-hx, -door_hw - 0.05], [door_hw + 0.05, hx]]:
			rails.append(Kit.box(seg[1] - seg[0], 0.1, 0.13, (seg[0] + seg[1]) / 2, yb, z_front + 0.07))
	s.add("cell", "wood", SC.pa(Kit.merge(rails), BAR_RAIL, 0.04, R), 0.018)
	s.box_c(-hx - 0.15, -door_hw, z_front - 0.12, z_front + 0.16)
	s.box_c(door_hw, hx + 0.15, z_front - 0.12, z_front + 0.16)
	s.box_c(-hx - 0.2, hx + 0.2, z_back - 0.1, z_back + 0.25)
	s.box_c(-hx - 0.2, -hx + 0.2, z_back, z_front)
	s.box_c(hx - 0.2, hx + 0.2, z_back, z_front)
	# 살문: 닫힘 = 살 + 가로대 + 자물쇠 / 열림 = 살문이 바깥으로 젖혀 옆 살 앞에 붙음
	var shut_c := s.st("cell", "SEALED", "SEALED")
	var dr := []
	for g in door_bars: dr.append(g)
	for yb in [base_h + 0.18, base_h + 1.05, top - 0.22]: dr.append(Kit.box(door_hw * 2, 0.1, 0.13, 0, yb, z_front + 0.07))
	shut_c.add("wood", SC.pa(Kit.merge(dr), BAR, 0.06, R), 0.022)
	shut_c.add("flat", C.P(Kit.box(0.16, 0.2, 0.08, door_hw - 0.12, base_h + 1.05, z_front + 0.17), 0x2a2622, 0x1a1714), 0.01)   # 무쇠 자물쇠
	s.scol("cell", "SEALED", { type = "box", minX = -door_hw, maxX = door_hw, minZ = z_front - 0.12, maxZ = z_front + 0.16 })
	var open_c := s.st("cell", "OPEN")
	var dr2 := []
	var nd := door_bars.size()
	for b in nd:
		var z := z_front + 0.12 + door_hw * 2 * (b + 0.5) / maxf(1.0, nd)
		dr2.append(Kit.cyl(bar_r, bar_r * 1.1, top - base_h, 6, door_hw + 0.06, (top + base_h) / 2, z))
	for yb in [base_h + 0.18, base_h + 1.05, top - 0.22]: dr2.append(Kit.box(0.13, 0.1, door_hw * 2, door_hw + 0.06, yb, z_front + 0.12 + door_hw))
	open_c.add("wood", SC.pa(Kit.merge(dr2), BAR, 0.06, R), 0.022)
	# 초가 맞배(용마루 x) — 앞 처마가 살 위로 0.55m 나온다
	old = s.m.push(0.0, 0.0, zc_b)
	C.thatch_gable(s.m, "roof", cw + 0.95, cd + 1.1, top + 0.18, 1.05)
	s.m.pop(old)
	# 마당 앞 소품: 물독 하나 · 문 안 등롱 기둥(밤 등롱은 사건 차림 ti_jail_lamp)
	s.add("yard", "onggi", SC.pa(Kit.xf(C.onggi(0.26, 0.52), -hx + 0.6, 0.0, z_front + 0.9), C.ONGGI, 0.05, R), 0.02)
	s.anchor("cell", Vector3(0, base_h, z_back + 1.5))
	s.anchor("bars_out", Vector3(0, 0, z_front + 1.4))
	s.anchor("gate_in", Vector3(r - 1.2, 0, 0))
	s.anchor("gate_out", Vector3(r + 1.2, 0, 0))
	s.anchor("lamp", Vector3(r - 1.0, 0, 2.1))
	s.circle(-hx + 0.6, z_front + 0.9, 0.3)
	return s.result("옥", Vector2(r * 2 + 1.0, r * 2 + 0.2))

# ---------------------------------------------------------------------------
# 단오 그네
# ---------------------------------------------------------------------------
static func _swing(P: Dictionary) -> Dictionary:
	var s := SC.S.new(int(P.get("seed", 3401)))
	var R := s.rng
	var h := float(P.get("h", 8.5))
	var span := float(P.get("span", 6.0))
	var hx := span / 2
	for sx in [-1, 1]:
		var x: float = sx * hx
		s.add("frame", "wood", SC.pa(Kit.cyl(0.13, 0.17, h + 0.25, 7, x, (h + 0.25) / 2, 0), SC.WOOD, 0.04, R), 0.025)
		# 버팀 다리(남북으로 벌림)
		for sz in [-1, 1]:
			var g := Kit.cyl(0.06, 0.08, h * 0.42, 6, 0, 0, 0)
			s.add("frame", "wood", SC.pa(Kit.xf(g, x, h * 0.19, sz * 0.55, sz * -0.3, 0, 0), SC.WOOD, 0.04, R), 0.02)
		s.circle(x, 0, 0.25)
	s.add("frame", "wood", SC.pa(Kit.cyl(0.11, 0.11, span + 0.7, 7, 0, h, 0, 0, 0, PI / 2), SC.WOOD, 0.03, R), 0.025)
	if bool(P.get("cloth", true)):
		var cols := [[0xc0392b, 0x8e2a20], [0xe8c547, 0xb8962e], [0x2f6fa8, 0x22507a], [0x3f8a4f, 0x2c6238], [0xefe9da, 0xc9c0a8]]
		for i in 9:
			var x := -hx + 0.5 + (span - 1.0) * i / 8.0
			if absf(x) < 0.7: continue
			s.add("cloth", "flat", SC.pa(Kit.box(0.22, 0.9, 0.02, x, h - 0.5, 0.0), cols[i % cols.size()], 0.05, R), 0.01)
	# 줄 둘 + 발판(부분 seat — 흔들기)
	var seat_y := 0.9
	var rope_l := h - seat_y
	for sx in [-1, 1]:
		s.add("seat", "flat", SC.pa(Kit.cyl(0.045, 0.045, rope_l, 5, sx * 0.32, seat_y + rope_l / 2, 0), [0x8c6a3e, 0x6a4e2c], 0.05, R), 0.02)
	s.add("seat", "wood", SC.pa(Kit.box(0.8, 0.06, 0.26, 0, seat_y, 0), SC.WOOD_L, 0.04, R), 0.015)
	s.anchor("pivot", Vector3(0, h, 0))
	s.anchor("seat", Vector3(0, seat_y + 0.03, 0))
	return s.result("그네", Vector2(span + 1.0, 2.4), false)

# ---------------------------------------------------------------------------
# 씨름판(모래 원판 + 새끼 테)
# ---------------------------------------------------------------------------
static func _ssireum(P: Dictionary) -> Dictionary:
	var s := SC.S.new(int(P.get("seed", 3402)))
	var R := s.rng
	var r := float(P.get("r", 3.5))
	s.add("ring", "flat", SC.pa(Kit.cyl(r, r + 0.15, 0.06, 28, 0, 0.03, 0), [0xd9c79c, 0xc2ad80], 0.04, R), 0.0)
	var segs := []
	var n := 30
	for i in n:
		var a := TAU * (i + 0.5) / n
		segs.append(Kit.box(TAU * r / n * 1.05, 0.1, 0.12, cos(a) * r, 0.09, sin(a) * r, -a + PI / 2))
	s.add("ring", "flat", SC.pa(Kit.merge(segs), C.STRAW, 0.06, R), 0.012)
	return s.result("씨름판", Vector2(r * 2 + 0.4, r * 2 + 0.4), false)

# ---------------------------------------------------------------------------
# 접부채(땅에 펼쳐진 채)
# ---------------------------------------------------------------------------
static func _fan(P: Dictionary) -> Dictionary:
	var s := SC.S.new(int(P.get("seed", 3403)))
	var R := s.rng
	var r := float(P.get("r", 0.32))
	var paper := []; var ribs := []
	var n := 9
	for i in n:
		var a := -0.95 + 1.9 * i / (n - 1)
		var cx := sin(a) * r * 0.62; var cz := -cos(a) * r * 0.62
		paper.append(Kit.box(r * 0.2, 0.008, r * 0.62, cx, 0.012, cz, -a))
		ribs.append(Kit.box(0.012, 0.014, r, sin(a) * r * 0.5, 0.02, -cos(a) * r * 0.5, -a))
	s.add("fan", "flat", SC.pa(Kit.merge(paper), [0xf0e8d2, 0xd8cdb0], 0.03, R), 0.006)
	s.add("fan", "flat", SC.pa(Kit.merge(ribs), [0x6b4a2e, 0x4d3420], 0.03, R), 0.004)
	return s.result("부채", Vector2(r * 2, r), false)
