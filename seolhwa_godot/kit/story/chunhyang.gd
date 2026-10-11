# 춘향 「남원의 약속」 차림 키트(seolhwa/docs/production/CHUNHYANG_ASSETS_PLACEMENT_v1.0.md §2) — kind로 고른다. 원점 = 바닥 중심.
#   지금 지을 수 있는 kind: has_kind() 목록. 아직 없는 kind(가마)는 배치 항목의 placeholder로 대신한다
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
#
#   PART II(관아 잔치 · 곤장 · 출두 — 2026-10-11 PART II 준비). 모두 앞 = +z(남쪽, 안마당 쪽).
#   kind "dais" — 보계(補階): 동헌 대청 높이로 앞에 덧댄 임시 나무 단. 기둥 줄 + 귀틀 + 마루널 + 옆 판 + 앞 가운데 계단(셋).
#     params: w(기본 7) · d(기본 2) · h(기본 1.05 — 대청 마루 높이) · steps(기본 3). 앵커: top(단 위 가운데) · stair(계단 앞 땅)
#   kind "seat_screen" — 교의(등받이·팔걸이 의자, 붉은 방석) + 뒤 병풍(여덟 폭, 지그재그). 대청 위(배치 dy 1.05).
#     params: screen(병풍, 기본 true) · panels(폭 수, 기본 8). 앵커: seat(교의 앉는 자리)
#   kind "hyeongteul" — 곤장 형틀: 긴 나무 틀(다리 넷 · 가로 받침 · 묶는 새끼) + 곤장 둘(납작한 긴 매, 틀 곁에 기대어 둠). 놓여 있기만(§52).
#     params: len(기본 2.1, x 방향) · paddles(기본 2)
#   kind "chail" — 잔치 차일: 흰 천 지붕(가장자리 술) + 장대 여섯 + 당김줄·말뚝. 천은 반투명이 아니다.
#     장대는 짧은 변(동·서)에 셋씩 — 가운데 축(보계·가운데 통로)에는 서지 않는다.
#     상태 "cloth": SPREAD(편 천, 기본) / FURLED(천을 반씩 양쪽 짧은 변 가로대에 말아 올림 — 8A처럼 높이서 내려다보는 컷에서 안마당이 보이게).
#     params: w(기본 18) · d(기본 8) · h(기본 4.6)
#   kind "jansang" — 손님 한 사람의 잔칫상 차림: 낮은 독상(술병·잔·떡·나물 그릇) + 뒤(+z) 방석. 손님은 방석에 앉아 −z(상)를 본다.
#     params: cushion(기본 true) · rich(그릇 더, 기본 false — 대청 위 수령 상). 앵커: seat(방석 위)
extends RefCounted

const C := preload("res://kit/village/_common.gd")
const SC := preload("res://kit/scenario/_sc.gd")

const KINDS := ["ok", "swing", "ssireum_ring", "fan", "dais", "seat_screen", "hyeongteul", "chail", "jansang"]
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
		"dais": return _dais(params)
		"seat_screen": return _seat_screen(params)
		"hyeongteul": return _hyeongteul(params)
		"chail": return _chail(params)
		"jansang": return _jansang(params)
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

# ---------------------------------------------------------------------------
# PART II — 보계(관아 단)
# ---------------------------------------------------------------------------
const PLANK := [0xa8875c, 0x86683f]      # 새로 깐 마루널(대청보다 밝다 — 임시로 덧댄 단)
const RED_CLOTH := [0xa83a32, 0x7a2a24]
const WHITE_CLOTH := [0xf2eee4, 0xd6cfbf]

static func _dais(P: Dictionary) -> Dictionary:
	var s := SC.S.new(int(P.get("seed", 3501)))
	var R := s.rng
	var w := float(P.get("w", 7.0)); var d := float(P.get("d", 2.0)); var h := float(P.get("h", 1.05))
	var hw := w / 2; var hd := d / 2
	# 기둥(주초 돌 위) — 가로 1.75m 간격
	var nx := int(round(w / 1.75)) + 1
	for i in nx:
		var x := -hw + 0.12 + (w - 0.24) * i / (nx - 1)
		for z in [-hd + 0.12, hd - 0.12]:
			s.add("frame", "wood", SC.pa(Kit.box(0.18, h - 0.1, 0.18, x, (h - 0.1) / 2, z), SC.WOOD, 0.03, R), 0.02)
			s.add("frame", "stone", SC.pa(Kit.box(0.32, 0.12, 0.32, x, 0.06, z), C.STONE, 0.05, R), 0.015)
	# 귀틀(테두리) + 마루널(세로 널 — 대청처럼 우물마루는 아니다)
	s.add("deck", "wood", SC.pa(Kit.box(w, 0.16, 0.18, 0, h - 0.08, hd - 0.09), SC.WOOD, 0.03, R), 0.02)
	s.add("deck", "wood", SC.pa(Kit.box(w, 0.16, 0.18, 0, h - 0.08, -hd + 0.09), SC.WOOD, 0.03, R), 0.02)
	var planks := []
	var np := int(w / 0.32)
	for i in np:
		var x := -hw + w * (i + 0.5) / np
		planks.append(Kit.box(w / np - 0.015, 0.06, d - 0.04, x, h - 0.03, 0))
	s.add("deck", "wood", SC.pa(Kit.merge(planks), PLANK, 0.06, R), 0.012)
	# 앞·옆 가림 판(아래가 비어 보이지 않게)
	s.add("frame", "wood", SC.pa(Kit.box(w - 0.1, h - 0.25, 0.04, 0, (h - 0.25) / 2 + 0.06, hd - 0.05), [0x7a5c3e, 0x5a4330], 0.04, R), 0.015)
	for sx in [-1, 1]:
		s.add("frame", "wood", SC.pa(Kit.box(0.04, h - 0.25, d - 0.1, sx * (hw - 0.05), (h - 0.25) / 2 + 0.06, 0), [0x7a5c3e, 0x5a4330], 0.04, R), 0.015)
	# 앞 가운데 계단(+z로 내려옴)
	var steps := int(P.get("steps", 3))
	var sw := 1.6; var run := 0.32
	for k in steps:
		var y := h * (steps - k) / (steps + 1.0)
		var z := hd + run * (k + 0.5)
		s.add("stair", "wood", SC.pa(Kit.box(sw, 0.08, run + 0.02, 0, y, z), PLANK, 0.05, R), 0.015)
		s.add("stair", "wood", SC.pa(Kit.box(sw, y - 0.04, 0.05, 0, (y - 0.04) / 2, z + run / 2), [0x7a5c3e, 0x5a4330], 0.04, R), 0.012)
	for sx in [-1, 1]:
		s.add("stair", "wood", SC.pa(Kit.xf(Kit.box(0.08, 0.18, run * steps + 0.4, sx * (sw / 2 + 0.04), h * 0.5, hd + run * steps / 2), 0, 0, 0, 0.0, 0, 0), SC.WOOD, 0.03, R), 0.015)
	s.box_c(-hw, hw, -hd, hd)
	s.anchor("top", Vector3(0, h, 0))
	s.anchor("stair", Vector3(0, 0, hd + run * steps + 0.4))
	return s.result("보계", Vector2(w, d + run * steps))

# ---------------------------------------------------------------------------
# PART II — 교의 + 병풍
# ---------------------------------------------------------------------------
static func _seat_screen(P: Dictionary) -> Dictionary:
	var s := SC.S.new(int(P.get("seed", 3502)))
	var R := s.rng
	var lac := [0x5a2a22, 0x3a1a16]       # 붉은 옻칠
	var sy := 0.5
	# 교의: 다리 넷 · 앉음판 · 등받이(세 살) · 팔걸이 · 발받침
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			s.add("chair", "wood", SC.pa(Kit.box(0.07, sy, 0.07, sx * 0.3, sy / 2, sz * 0.25), lac, 0.03, R), 0.012)
		s.add("chair", "wood", SC.pa(Kit.box(0.06, 0.62, 0.06, sx * 0.3, sy + 0.31, -0.25), lac, 0.03, R), 0.012)   # 등받이 기둥
		s.add("chair", "wood", SC.pa(Kit.box(0.06, 0.06, 0.56, sx * 0.31, sy + 0.24, 0.0), lac, 0.03, R), 0.01)     # 팔걸이
		s.add("chair", "wood", SC.pa(Kit.box(0.05, 0.24, 0.05, sx * 0.31, sy + 0.12, 0.24), lac, 0.03, R), 0.01)
	s.add("chair", "wood", SC.pa(Kit.box(0.68, 0.06, 0.58, 0, sy, 0), lac, 0.03, R), 0.015)
	s.add("chair", "wood", SC.pa(Kit.box(0.7, 0.08, 0.07, 0, sy + 0.62, -0.25), lac, 0.03, R), 0.012)
	s.add("chair", "wood", SC.pa(Kit.box(0.34, 0.5, 0.04, 0, sy + 0.32, -0.26), [0x8a4a30, 0x6a3420], 0.03, R), 0.01)
	s.add("chair", "cloth", SC.pa(Kit.box(0.6, 0.06, 0.52, 0, sy + 0.06, 0.01), RED_CLOTH, 0.04, R), 0.008)   # 방석
	s.add("chair", "wood", SC.pa(Kit.box(0.62, 0.12, 0.3, 0, 0.06, 0.46), lac, 0.03, R), 0.012)               # 발받침(족대)
	s.box_c(-0.36, 0.36, -0.3, 0.3)
	# 병풍: 폭마다 테 + 그림(산수 — 엷은 먹빛 띠), 지그재그로 세움
	if bool(P.get("screen", true)):
		var n := int(P.get("panels", 8))
		var pw := 0.42; var ph := 1.75
		var z0 := -0.75
		for i in n:
			var x := -pw * n / 2.0 + pw * (i + 0.5)
			var a := 0.22 if i % 2 == 0 else -0.22
			var zz := z0 + (0.04 if i % 2 == 0 else -0.04)
			s.add("screen", "wood", SC.pa(Kit.box(pw, ph, 0.03, x, ph / 2 + 0.06, zz, a), [0x3a2a20, 0x2a1e16], 0.02, R), 0.012)
			s.add("screen", "flat", SC.pa(Kit.box(pw - 0.07, ph - 0.22, 0.012, x, ph / 2 + 0.08, zz + 0.02 * cos(a), a), [0xe8dfc6, 0xd6caa8], 0.03, R), 0.0)
			# 먹 산수 띠(산 둘 · 물 한 줄)
			s.add("screen", "flat", SC.pa(Kit.box(pw - 0.12, 0.28, 0.006, x, 0.75 + (i % 3) * 0.12, zz + 0.032 * cos(a), a), [0x8a9488, 0x6a7468], 0.05, R), 0.0)
			s.add("screen", "flat", SC.pa(Kit.box(pw - 0.12, 0.05, 0.006, x, 0.45, zz + 0.032 * cos(a), a), [0x6e8aa0, 0x5a7488], 0.03, R), 0.0)
		s.box_c(-pw * n / 2.0, pw * n / 2.0, z0 - 0.15, z0 + 0.15)
	s.anchor("seat", Vector3(0, sy + 0.06, 0))
	return s.result("교의와 병풍", Vector2(3.6, 1.6), false)

# ---------------------------------------------------------------------------
# PART II — 곤장 형틀
# ---------------------------------------------------------------------------
static func _hyeongteul(P: Dictionary) -> Dictionary:
	var s := SC.S.new(int(P.get("seed", 3503)))
	var R := s.rng
	var L := float(P.get("len", 2.1))
	var hl := L / 2; var top := 0.55
	var old_wood := [0x7a6248, 0x58442f]
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			s.add("frame", "wood", SC.pa(Kit.box(0.09, top, 0.09, sx * (hl - 0.15), top / 2, sz * 0.2), old_wood, 0.04, R), 0.015)
		s.add("frame", "wood", SC.pa(Kit.box(0.08, 0.08, 0.46, sx * (hl - 0.15), 0.18, 0), old_wood, 0.04, R), 0.01)   # 다리 받침
	s.add("frame", "wood", SC.pa(Kit.box(L, 0.1, 0.5, 0, top, 0), old_wood, 0.05, R), 0.018)
	for sx in [-1, 1]: s.add("frame", "wood", SC.pa(Kit.box(L, 0.06, 0.06, 0, top - 0.09, sx * 0.24), SC.WOOD, 0.03, R), 0.01)
	# 머리 쪽 턱(−x) · 묶는 새끼 두 곳
	s.add("frame", "wood", SC.pa(Kit.box(0.1, 0.16, 0.5, -hl + 0.05, top + 0.12, 0), old_wood, 0.04, R), 0.012)
	for x in [-0.25, 0.55]:
		s.add("rope", "flat", SC.pa(Kit.box(0.06, 0.13, 0.54, x, top + 0.01, 0), [0xb39a68, 0x8a7348], 0.05, R), 0.006)
	# 곤장 둘: 납작한 긴 매(손잡이 둥글게) — 틀 남쪽(+z)에 비스듬히 눕힘
	var n := int(P.get("paddles", 2))
	for i in n:
		var g := Kit.merge([Kit.box(1.25, 0.04, 0.16, 0.2, 0, 0), Kit.cyl(0.035, 0.035, 0.45, 6, -0.62, 0, 0, 0, 0, PI / 2)])
		Kit.xf(g, -0.2 + i * 0.35, 0.03 + i * 0.045, 0.62 + i * 0.12, 0.0, 0.18 - i * 0.3, 0.0)
		s.add("paddle", "wood", SC.pa(g, [0x8a6440, 0x6a4a2e], 0.04, R), 0.01)
	s.box_c(-hl, hl, -0.27, 0.27)
	return s.result("형틀", Vector2(L + 0.2, 1.4), false)

# ---------------------------------------------------------------------------
# PART II — 잔치 차일
# ---------------------------------------------------------------------------
static func _chail(P: Dictionary) -> Dictionary:
	var s := SC.S.new(int(P.get("seed", 3504)))
	var R := s.rng
	var w := float(P.get("w", 18.0)); var d := float(P.get("d", 8.0)); var h := float(P.get("h", 4.6))
	var hw := w / 2; var hd := d / 2
	# 장대 여섯: 짧은 변(x = ±w/2)에 셋씩 — 가운데 축(보계·통로)에는 장대를 세우지 않는다. 당김줄 · 말뚝은 바깥으로
	for sx in [-1, 1]:
		for k in 3:
			var z := -hd + d * k / 2.0
			var x: float = sx * hw
			s.add("poles", "wood", SC.pa(Kit.cyl(0.06, 0.08, h + 0.35, 7, x, (h + 0.35) / 2, z), SC.WOOD, 0.04, R), 0.02)
			s.circle(x, z, 0.12)
			var gx: float = x + sx * 1.4; var gz: float = z + (0.0 if k == 1 else (-1.2 if k == 0 else 1.2))
			s.add("poles", "flat", SC.pa(Kit.limb(Vector3(x, h + 0.25, z), Vector3(gx, 0.15, gz), 0.012, 0.012, 3), [0xb39a68, 0x8a7348]), 0.0)
			s.add("poles", "wood", SC.pa(Kit.box(0.07, 0.3, 0.07, gx, 0.12, gz), SC.WOOD, 0.03, R), 0.008)
		# 짧은 변 위 가로대(천을 매는 장대)
		s.add("poles", "wood", SC.pa(Kit.cyl(0.05, 0.05, d + 0.3, 6, sx * hw, h + 0.05, 0, PI / 2, 0, 0), SC.WOOD, 0.03, R), 0.015)
	# 편 천: 가운데가 살짝 처진 흰 천(가로 띠 여러 장 — 이음 솔기) + 가장자리 붉은·푸른 술
	var spread := s.st("cloth", "SPREAD", "SPREAD")
	var nz := 8
	for i in nz:
		var z0 := -hd + d * i / nz; var z1 := -hd + d * (i + 1) / nz
		var zm := (z0 + z1) / 2
		var sag := 0.35 * (1.0 - pow(zm / hd, 2))
		spread.add("cloth", SC.pa(Kit.box(w + 0.3, 0.03, d / nz + 0.02, 0, h - sag, zm), WHITE_CLOTH, 0.02, R), 0.01)
	for sz in [-1, 1]:
		var tas := []
		for k in int(w / 0.6):
			tas.append(Kit.box(0.28, 0.22, 0.015, -hw + 0.3 + k * 0.6, h - 0.12, sz * (hd + 0.02)))
		spread.add("flat", SC.pa(Kit.merge(tas), [0xb8423a, 0x8e2a24] if sz < 0 else [0x3a5a8a, 0x2a4266], 0.04, R), 0.004)
	# 만 천: 천을 반씩 양쪽 짧은 변 가로대에 말아 올림(가운데가 열려 8A에서 안마당이 보인다)
	var furled := s.st("cloth", "FURLED")
	for sx in [-1, 1]:
		furled.add("cloth", SC.pa(Kit.cyl(0.22, 0.22, d + 0.2, 10, sx * (hw - 0.2), h + 0.08, 0, PI / 2, 0, 0), WHITE_CLOTH, 0.03, R), 0.012)
		for k in 3:
			furled.add("flat", SC.pa(Kit.cyl(0.24, 0.24, 0.08, 10, sx * (hw - 0.2), h + 0.08, -hd + d * (k + 0.5) / 3.0, PI / 2, 0, 0), [0xb39a68, 0x8a7348]), 0.004)
	return s.result("차일", Vector2(w + 2.4, d + 3.0), false)

# ---------------------------------------------------------------------------
# PART II — 잔칫상(손님 한 사람)
# ---------------------------------------------------------------------------
static func _jansang(P: Dictionary) -> Dictionary:
	var s := SC.S.new(int(P.get("seed", 3505)))
	var R := s.rng
	var rich := bool(P.get("rich", false))
	var tw := 0.78; var td := 0.48; var th := 0.3
	var lac := [0x6a3a26, 0x4a2618]
	s.add("table", "wood", SC.pa(Kit.box(tw, 0.05, td, 0, th, 0), lac, 0.04, R), 0.012)
	s.add("table", "wood", SC.pa(Kit.box(tw + 0.04, 0.025, td + 0.04, 0, th + 0.03, 0), [0x7a4a30, 0x5a3420], 0.03, R), 0.008)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			s.add("table", "wood", SC.pa(Kit.cyl(0.025, 0.035, th, 6, sx * (tw / 2 - 0.07), th / 2, sz * (td / 2 - 0.07)), lac, 0.03, R), 0.006)
	# 그릇: 흰 사발·접시 + 떡 괸 것 + 술병 · 잔
	var dishes := [[-0.24, -0.1, 0.075, 0.05], [0.0, -0.12, 0.07, 0.04], [0.24, -0.1, 0.075, 0.05], [-0.14, 0.1, 0.06, 0.04], [0.12, 0.1, 0.06, 0.04]]
	if rich: dishes.append_array([[-0.3, 0.12, 0.055, 0.035], [0.3, 0.12, 0.055, 0.035]])
	var foods := [[0xc8a858, 0xa88a40], [0x6a8a48, 0x4a6a30], [0xb8504a, 0x8e3a34], [0xe8dcc0, 0xc8bca0], [0x8a6a48, 0x6a4a30]]
	for i in dishes.size():
		var dd: Array = dishes[i]
		s.add("dish", "onggi", C.P(Kit.cyl(dd[2], dd[2] * 0.7, dd[3], 10, dd[0], th + 0.05 + dd[3] / 2, dd[1]), 0xf0ebe0, 0xc8c0b0), 0.004)
		s.add("dish", "smooth", SC.pa(Kit.cyl(dd[2] * 0.82, dd[2] * 0.82, 0.02, 10, dd[0], th + 0.05 + dd[3], dd[1]), foods[i % foods.size()], 0.05, R), 0.0)
	# 떡 괸 것(가운데 뒤)
	for k in 4:
		s.add("dish", "smooth", SC.pa(Kit.cyl(0.07 - k * 0.012, 0.07 - k * 0.012, 0.035, 8, 0.0, th + 0.1 + k * 0.035, 0.08), [0xf0e6d0, 0xd8ccb0] if k % 2 == 0 else [0xd88a8a, 0xb86a6a], 0.04, R), 0.0)
	s.add("dish", "onggi", C.P(Kit.xf(C.onggi(0.06, 0.16, 8), 0.33, th + 0.05, -0.02), 0xece6d8, 0xc8c0b0), 0.004)   # 술병
	s.add("dish", "onggi", C.P(Kit.cyl(0.03, 0.022, 0.03, 8, 0.24, th + 0.07, 0.12), 0xf0ebe0, 0xc8c0b0), 0.003)        # 잔
	if bool(P.get("cushion", true)):
		s.add("cushion", "cloth", SC.pa(Kit.box(0.6, 0.07, 0.58, 0, 0.035, 0.62), [0x3a5a8a, 0x2a4266] if not rich else RED_CLOTH, 0.04, R), 0.008)
		s.add("cushion", "cloth", SC.pa(Kit.box(0.5, 0.02, 0.48, 0, 0.075, 0.62), [0xd8c890, 0xb8a870], 0.03, R), 0.0)
	s.box_c(-tw / 2, tw / 2, -td / 2, td / 2)
	s.anchor("seat", Vector3(0, 0.07, 0.62))
	return s.result("잔칫상", Vector2(0.9, 1.3), false)
