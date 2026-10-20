# 건물 빌더 대문·문 — 담에 끼우는 문 한 채. 원점 = 문 가운데 바닥(담 줄 위), 바깥(골목) = +z, 안(마당) = -z.
#   params: { type, seed, open(true), wall_h(1.7: 양옆 담 높이 — 지붕 처마가 담 갓 위로 지나가게), cls, w(문 너비) }
#   type:
#     sarip    사립문 — 싸리·잡목 엮은 문짝, 거친 기둥 둘(서민 싸리울·돌담)
#     ilgak    일각문 — 기둥 둘 + 작은 맞배 기와지붕(담 사이 단독 문, 사당·별당·뒷문)
#     pyeong   평대문 — 기둥 넷(대문간 한 칸) + 맞배, 담 갓과 같은 줄 높이(행랑채 없는 반가·중인 집)
#     soseul   솟을대문 — 가운데 대문 칸 지붕을 한 층 올리고 양옆 낮은 행랑 칸(지붕은 겹치지 않고 층으로 — 옆 지붕 박공은 가운데 처마 밑)
#     jungmun  중문 — 사랑마당 ↔ 안마당 사이 담의 작은 일각문(문짝 하나 반)
#     hyeop    협문 — 담에 낸 좁은 쪽문(너비 1m, 갓 기와 지붕 낮게)
#     samun    관아·향교 삼문 — 세 칸, 가운데 칸 지붕을 올린 솟을삼문, 붉은 기둥, 가운데 문짝 태극
#     chomun   초가 대문 — 평대문 짜임 + 맞배 이엉(중농 토담 집)
#     hongsal  홍살문 — 붉은 둥근 기둥 둘 + 가로대 + 위 살대(화살 모양) + 가운데 태극(문짝 없음, 관아·향교·능 앞)
#   쓰임새 디테일: 대문 디딤돌(바깥·안) · 문지방(넘어서는 턱 0.18m — 걷기 면) · 문간 바닥(박석) · 문짝(널판) + 문고리 · 빗장 · 둔테 · 등 걸이
#   반환: anchors wall_l / wall_r(담이 붙는 x), approach(문 앞 바깥 자리), inside(문 안 자리), eave_min(지붕 처마 밑 가장 낮은 높이)
extends RefCounted
const C := preload("res://kit/village/_common.gd")
const A := preload("res://kit/bldg/_atlas.gd")
const RF := preload("res://kit/bldg/_roof.gd")

const RED := [0x8a3e2e, 0x6a2e22]

static func footprint(params: Dictionary) -> Vector2:
	var t: String = params.get("type", "pyeong")
	var w := _width(params)
	match t:
		"soseul": return Vector2(w + 5.4, 3.4)
		"samun": return Vector2(w * 3 + 1.6, 3.2)
		"hongsal": return Vector2(w + 1.2, 1.2)
		"sarip", "hyeop": return Vector2(w + 0.8, 1.2)
	return Vector2(w + 1.6, 2.8)

# 담이 붙는 반폭(짓지 않고)
static func half(params: Dictionary) -> float:
	var t: String = params.get("type", "pyeong")
	var w := _width(params)
	match t:
		"sarip": return w / 2 + 0.08
		"hongsal": return w / 2 + 0.3
		"soseul": return w / 2 + 0.13 + 2.3 + 0.1
		"samun": return 1.5 * (w + 0.28) + 0.05
		"hyeop": return w / 2 + 0.1
	return w / 2 + 0.12

static func _width(params: Dictionary) -> float:
	var t: String = params.get("type", "pyeong")
	var dflt := { chomun = 1.9, sarip = 1.4, ilgak = 1.5, pyeong = 2.0, soseul = 2.3, jungmun = 1.3, hyeop = 0.95, samun = 2.4, hongsal = 3.2 }
	return float(params.get("w", dflt.get(t, 2.0)))

static func build(params: Dictionary) -> Dictionary:
	var t: String = params.get("type", "pyeong")
	var m := C.M.new(int(params.get("seed", 1)))
	var w := _width(params)
	var wall_h: float = float(params.get("wall_h", 1.7))
	var open: bool = bool(params.get("open", true))
	var info := { half = w / 2 + 0.15, eave_min = 99.0 }
	match t:
		"sarip": _sarip(m, w, open)
		"hongsal": _hongsal(m, w)
		"samun": info = _samun(m, w, wall_h, open)
		"soseul": info = _soseul(m, w, wall_h, open)
		_: info = _framed(m, t, w, wall_h, open)
	if t != "hongsal": _approach(m, t, w)
	m.anchor("wall_l", Vector3(-float(info.half), 0, 0)); m.anchor("wall_r", Vector3(float(info.half), 0, 0))
	m.anchor("approach", Vector3(0, 0, 2.2)); m.anchor("inside", Vector3(0, 0, -2.2))
	var res := m.result("문_" + t, footprint(params))
	res.eave_min = info.eave_min
	return res

# 디딤돌(바깥·안) + 문간 바닥(박석) + 문지방은 _sill에서. 걷기 면: 디딤돌 0.14 · 문간 0.05
static func _approach(m: C.M, t: String, w: float) -> void:
	var R := m.rng
	if t == "sarip":
		m.add("p", "stone", C.P(Kit.box(0.8, 0.12, 0.45, 0, 0.06, 0.55), 0xb8b2a5, 0x8e897f, 0.05, R), 0.012)
		m.walk_floor(-0.4, 0.4, 0.33, 0.77, 0.12)
		return
	var dd := 0.9 if t != "hyeop" else 0.7
	for zz in [0.62, -0.62]:
		m.add("p", "stone", C.P(Kit.box(minf(w, 1.3), 0.13, 0.46, 0, 0.065, zz), 0xb8b2a5, 0x8e897f, 0.05, R), 0.012)
		m.walk_floor(-minf(w, 1.3) / 2, minf(w, 1.3) / 2, zz - 0.23, zz + 0.23, 0.13)
	# 문간 박석
	for i in 3:
		m.add("p", "stone", C.P(Kit.box(w / 3 - 0.03, 0.05, 0.3, -w / 3 + i * w / 3, 0.025, -0.3), 0xa8a294, 0x857f74, 0.05, R), 0)

# 문지방(넘어서는 턱): 높이 h, 걷기 면
static func _sill(m: C.M, w: float, h := 0.18) -> void:
	m.add("p", "wood", C.PA(Kit.box(w + 0.1, h, 0.16, 0, h / 2, 0), [0x6a5038, 0x4d3826], 0.03, m.rng), 0.012)
	m.walk_floor(-w / 2, w / 2, -0.08, 0.08, h)

# 문짝 둘(널판, 안으로 열림) + 문고리(바깥) + 빗장 걸이·빗장(안) + 둔테(위아래 축 받침)
static func _leaves(m: C.M, w: float, h: float, y0: float, open: bool, n := 2, paint := false) -> void:
	var lw := w / n
	for k in n:
		var side := -1.0 if k == 0 else 1.0
		if n == 1: side = -1.0
		var hx: float = -w / 2 if side < 0 else w / 2
		var ang: float = (-side * 1.35) if open else 0.0   # 안(-z)으로 열림
		var old := m.push(hx, y0, -0.06, ang)
		var cx: float = -side * lw / 2
		var g := A.panel(lw - 0.03, h, cx, h / 2, 0.025)
		A.add(m, "p", "panbyeok", C.P(g, 0x9a7a58, 0x7a5c40, 0.03, m.rng), 0)
		A.add(m, "p", "panbyeok", C.P(A.panel(lw - 0.03, h, cx, h / 2, -0.025, PI), 0x8a6a48, 0x6a5038, 0.03, m.rng), 0)
		m.add("p", "wood", C.PA(Kit.box(lw - 0.03, h, 0.04, cx, h / 2, 0), [0x6a5038, 0x4d3826]), 0.01)
		for yy in [0.25, h - 0.25]: m.add("p", "flat", C.P(Kit.box(lw - 0.08, 0.06, 0.07, cx, yy, 0), 0x3a2e24), 0)   # 띠장
		if paint and n == 2:
			# 삼문 가운데 문짝 태극(붉은·푸른 반원)
			m.add("p", "flat", C.P(Kit.xf(Kit.cyl(0.22, 0.22, 0.02, 12, 0, 0, 0, PI / 2, 0, 0), cx, h * 0.62, 0.035), 0x9a3a2a), 0)
			m.add("p", "flat", C.P(Kit.xf(Kit.box(0.44, 0.22, 0.022), cx, h * 0.62 - 0.11, 0.037), 0x2e4a7a), 0)
		# 문고리(바깥, 고리 + 받침)
		var rx: float = -side * (lw - 0.18)
		m.add("p", "flat", C.P(Kit.box(0.08, 0.08, 0.02, rx, h * 0.48, 0.05), 0x3a3a3c), 0)
		m.add("p", "flat", C.P(Kit.xf(C.torus(0.055, 0.012, 4, 10), rx, h * 0.48 - 0.06, 0.06), 0x3a3a3c, 0x2a2a2c), 0)
		# 빗장 걸이(안)
		m.add("p", "wood", C.PA(Kit.box(0.1, 0.12, 0.08, rx, h * 0.52, -0.06), C.WOOD), 0)
		m.pop(old)
		# 둔테(축 받침): 기둥 안쪽 위·아래
		for yy in [y0 + 0.06, y0 + h - 0.04]:
			m.add("p", "wood", C.PA(Kit.box(0.16, 0.1, 0.22, hx - side * 0.0, yy, -0.12), [0x5a4432, 0x3f2f22]), 0.008)
	if not open:
		m.add("p", "wood", C.PA(Kit.box(w * 0.6, 0.08, 0.08, 0, y0 + h * 0.52, -0.12), C.WOOD), 0.008)   # 빗장(닫힘)
		m.box_c(-w / 2, w / 2, -0.12, 0.12)
	else:
		# 열린 빗장은 안쪽 기둥에 기대 둠
		m.add("p", "wood", C.P(Kit.xf(Kit.box(0.08, 1.1, 0.08), w / 2 - 0.15, y0 + 0.55, -0.45, 0.25, 0, 0), 0x6a5038), 0.008)

static func _post(m: C.M, x: float, z: float, h: float, r: float, round_ := false, col: Array = C.WOOD) -> void:
	m.add("p", "stone", C.P(Kit.box(r * 3.2, 0.14, r * 3.2, x, 0.07, z), 0xb5afa2, 0x948f84, 0.03, m.rng), 0.01)
	if round_: m.add("p", "wood", C.PA(Kit.cyl(r * 0.95, r, h - 0.14, 8, x, 0.14 + (h - 0.14) / 2, z), col, 0.03, m.rng), 0.015)
	else: m.add("p", "wood", C.PA(Kit.box(r * 2, h - 0.14, r * 2, x, 0.14 + (h - 0.14) / 2, z), col, 0.03, m.rng), 0.015)
	m.circle(x, z, r + 0.02)

# 맞배 기와 지붕(작은 문 지붕): 반폭 hw, 반깊이 hd, 처마 eave
static func _gable_roof(m: C.M, hw: float, hd: float, eave: float, rise: float, lift := 0.25) -> void:
	var old := m.push(0, 0, 0)
	m.pop(old)
	var o := { hw = hw, hd = hd, eave = eave, rise = rise, thick = 0.18, lift = lift, ends = ["gable", "gable"], lod = 0, L = hw * 2 - 1.0, D = hd * 2 - 0.9, rafters = true,
		rafter_col = C.WOOD }
	# 문 지붕은 조각 'p'에 — 작은 모델은 한 덩이
	var mm: C.M = m
	RF.giwa(mm, "p", o)

# 일각문·평대문·중문·협문: 기둥 + 상인방 + 문지방 + 문짝 + 맞배(처마 밑이 담 갓보다 0.1m 위)
static func _framed(m: C.M, t: String, w: float, wall_h: float, open: bool) -> Dictionary:
	var R := m.rng
	var deep: bool = t in ["pyeong", "chomun"]
	var post_h := 2.35 if t != "hyeop" else 1.95
	if t == "jungmun": post_h = 2.15
	# 처마 밑(지붕 밑면)이 담 갓(wall_h + 0.3) 위로 0.1m — 갓이 처마 밑으로 들어간다(뚫지 않음)
	var eave := maxf(post_h + 0.32, wall_h + 0.3 + 0.1 + 0.18 + 0.05)
	var r := 0.12 if t != "hyeop" else 0.1
	var zs := [0.0] if not deep else [0.55, -0.55]
	for z in zs:
		for sx in [-1.0, 1.0]: _post(m, sx * (w / 2 + r), z, eave - 0.1, r)
	var dz: float = 0.0 if not deep else -0.55   # 문짝은 안쪽 기둥 줄에
	var old := m.push(0, 0, dz)
	_sill(m, w, 0.18 if t != "hyeop" else 0.12)
	m.add("p", "wood", C.PA(Kit.box(w + 2 * r, 0.16, 0.18, 0, post_h - 0.08, 0), C.WOOD, 0.03, R), 0.012)   # 상인방(기둥 바깥까지만 — 담 갓과 겹치지 않게)
	_leaves(m, w, post_h - 0.38, 0.18, open, 1 if t in ["hyeop"] else 2)
	m.pop(old)
	# 상인방 위 ~ 처마: 회벽(작은 박공 밑)
	if eave - post_h > 0.25:
		for z in zs: m.add("p", "mud", C.PA(Kit.box(w + 2 * r, eave - post_h - 0.05, 0.12, 0, (post_h + eave - 0.05) / 2, z), C.PLASTER, 0.03, R), 0.01)
	# 평대문: 대문간 양옆 회벽(담과 이어짐)
	if deep:
		for sx in [-1.0, 1.0]:
			m.add("p", "mud", C.PA(Kit.box(0.14, eave - 0.3, 1.1, sx * (w / 2 + r), (eave - 0.3) / 2 + 0.14, 0), C.PLASTER, 0.03, R), 0.012)
			m.box_c(sx * (w / 2 + r) - 0.1, sx * (w / 2 + r) + 0.1, -0.6, 0.6)
		# 등 걸이(바깥 기둥에 쇠 갈고리)
		m.add("p", "flat", C.P(Kit.box(0.04, 0.04, 0.25, w / 2 + 0.05, post_h - 0.3, 0.75), 0x2a2a2c), 0)
		m.add("p", "flat", C.P(Kit.box(0.03, 0.18, 0.03, w / 2 + 0.05, post_h - 0.4, 0.86), 0x2a2a2c), 0)
	var hd := (0.55 + 0.95) if deep else (0.85 if t != "hyeop" else 0.6)
	var hw := w / 2 + r + (0.55 if t != "hyeop" else 0.3)
	if t == "chomun":
		RF.thatch_gable(m, "p", { hw = hw, hd = hd, eave = eave, rise = hd * 0.75, lod = 0, cols = C.THATCH, L = w + 2 * r, D = 1.1, wall_top = post_h })
		return { half = w / 2 + r, eave_min = eave - 0.3 }
	_gable_roof(m, hw, hd, eave, hd * (0.62 if t != "hyeop" else 0.55), 0.2)
	return { half = w / 2 + r, eave_min = eave - 0.18 }

# 사립문: 거친 기둥 둘 + 싸리 엮은 문짝(안으로 젖힘)
static func _sarip(m: C.M, w: float, open: bool) -> void:
	var R := m.rng
	for sx in [-1.0, 1.0]:
		m.add("p", "bark", C.P(Kit.cyl(0.07, 0.09, 1.6, 6, sx * (w / 2 + 0.08), 0.8, 0, 0, 0, sx * 0.04), 0x6e5a46, 0x4a3b2e, 0.05, R), 0.012)
		m.circle(sx * (w / 2 + 0.08), 0, 0.1)
	m.add("p", "bark", C.P(Kit.cyl(0.05, 0.05, w + 0.4, 5, 0, 1.55, 0, 0, 0, PI / 2), 0x6e5a46, 0x4a3b2e), 0.01)
	var old := m.push(-w / 2, 0, -0.05, 1.2 if open else 0.0)
	var n := int(w / 0.07)
	for i in n:
		var x := 0.04 + i * (w - 0.08) / n
		m.add("p", "thatch", C.P(Kit.cyl(0.012, 0.016, 1.2 + (m.r() - 0.5) * 0.15, 4, x, 0.72, 0, 0, 0, (m.r() - 0.5) * 0.12), 0x9a8058, 0x6e5a3e), 0)
	for yy in [0.35, 0.8, 1.2]: m.add("p", "bark", C.P(Kit.cyl(0.025, 0.025, w, 5, w / 2, yy, 0.02, 0, 0, PI / 2), 0x7a6040), 0)
	m.pop(old)

# 홍살문: 붉은 둥근 기둥 둘 + 가로대 둘 + 살대(화살) + 가운데 태극
static func _hongsal(m: C.M, w: float) -> void:
	var R := m.rng
	var h := 5.6
	for sx in [-1.0, 1.0]:
		m.add("p", "stone", C.P(Kit.box(0.6, 0.35, 0.6, sx * w / 2, 0.175, 0), 0xb5afa2, 0x948f84, 0.03, R), 0.012)
		m.add("p", "wood", C.PA(Kit.cyl(0.13, 0.15, h, 10, sx * w / 2, h / 2, 0), RED, 0.03, R), 0.018)
		m.circle(sx * w / 2, 0, 0.32)
	for yy in [h - 1.3, h - 0.35]:
		m.add("p", "wood", C.PA(Kit.box(w + 0.5, 0.16, 0.16, 0, yy, 0), RED, 0.03, R), 0.012)
	var n := int(w / 0.22)
	for i in n:
		var x := -w / 2 + 0.2 + i * (w - 0.4) / maxf(n - 1, 1)
		m.add("p", "wood", C.PA(Kit.box(0.045, 1.6, 0.045, x, h - 0.6, 0), RED), 0)
		m.add("p", "flat", C.P(Kit.cone(0.05, 0.16, 4, x, h + 0.28, 0), 0x2a2420), 0)
	# 가운데 태극 + 삼지창
	m.add("p", "flat", C.P(Kit.xf(Kit.cyl(0.32, 0.32, 0.04, 14, 0, 0, 0, PI / 2, 0, 0), 0, h - 0.82, 0.06), 0x9a3a2a), 0.01)
	m.add("p", "flat", C.P(Kit.xf(Kit.box(0.64, 0.32, 0.045), 0, h - 0.98, 0.065), 0x2e4a7a), 0)
	m.add("p", "flat", C.P(Kit.box(0.04, 0.9, 0.04, 0, h + 0.3, 0), 0x2a2420), 0)

# 솟을대문: 가운데 대문간(높은 기둥·맞배) + 양옆 낮은 행랑 칸(회벽·작은 창·맞배) — 옆 지붕 박공 끝은 가운데 처마 밑(층)
static func _soseul(m: C.M, w: float, wall_h: float, open: bool) -> Dictionary:
	var R := m.rng
	var side_w := 2.3; var dpt := 2.2
	var low_eave := maxf(2.55, wall_h + 0.55)
	var low_rise := 0.62 * (dpt / 2 + 0.8)
	var hi_eave := low_eave + low_rise + 0.45   # 가운데 처마 밑이 옆 지붕 용마루보다 위
	var r := 0.13
	for z in [dpt / 2, -dpt / 2]:
		for sx in [-1.0, 1.0]: _post(m, sx * (w / 2 + r), z, hi_eave - 0.1, r)
	_sill(m, w)
	m.add("p", "wood", C.PA(Kit.box(w + 0.4, 0.18, 0.2, 0, 2.6, 0), C.WOOD, 0.03, R), 0.012)
	_leaves(m, w, 2.42, 0.18, open, 2)
	m.add("p", "mud", C.PA(Kit.box(w + 0.3, hi_eave - 2.75, 0.12, 0, (2.7 + hi_eave) / 2 - 0.05, 0), C.PLASTER, 0.03, R), 0.01)
	_gable_roof_at(m, 0.0, w / 2 + r + 0.6, dpt / 2 + 0.85, hi_eave, (dpt / 2 + 0.85) * 0.62)
	for sx in [-1.0, 1.0]:
		var cx: float = sx * (w / 2 + r + side_w / 2)
		m.add("p", "stone", C.PA(Kit.box(side_w + 0.3, 0.3, dpt + 0.3, cx, 0.15, 0), C.STONE, 0.05, R), 0.015)
		m.add("p", "mud", C.PA(Kit.box(side_w, low_eave - 0.55, dpt, cx, 0.3 + (low_eave - 0.55) / 2, 0), C.PLASTER, 0.03, R), 0.02)
		for z in [dpt / 2, -dpt / 2]: _post(m, cx + sx * side_w / 2, z, low_eave - 0.1, 0.11)
		A.add(m, "p", "yong", A.panel(0.5, 0.45, cx, 1.55, dpt / 2 + 0.01), 0)
		m.box_c(cx - side_w / 2, cx + side_w / 2, -dpt / 2, dpt / 2)
		# 옆 지붕: 바깥 끝 맞배, 안 끝은 가운데 칸 벽에서 끝남(가운데 처마 밑)
		_gable_roof_at(m, cx + sx * 0.25, side_w / 2 + 0.25 + 0.0, dpt / 2 + 0.8, low_eave, low_rise)
	return { half = w / 2 + r + side_w + 0.1, eave_min = low_eave - 0.18 }

static func _gable_roof_at(m: C.M, cx: float, hw: float, hd: float, eave: float, rise: float) -> void:
	var old := m.push(cx, 0, 0)
	RF.giwa(m, "p", { hw = hw, hd = hd, eave = eave, rise = rise, thick = 0.2, lift = 0.25, ends = ["gable", "gable"], lod = 0, L = hw * 2 - 0.6, D = hd * 2 - 1.2, rafter_col = C.WOOD })
	m.pop(old)

# 삼문(솟을삼문): 세 칸 — 가운데 칸 지붕을 올림, 붉은 기둥, 가운데 문짝 태극
static func _samun(m: C.M, w: float, wall_h: float, open: bool) -> Dictionary:
	var R := m.rng
	var dpt := 2.0
	var low_eave := maxf(2.7, wall_h + 0.6)
	var low_rise := 0.6 * (dpt / 2 + 0.8)
	var hi_eave := low_eave + low_rise + 0.4
	var r := 0.14
	for b in [-1, 0, 1]:
		var cx: float = b * (w + 2 * r)
		var eh: float = hi_eave if b == 0 else low_eave
		for z in [dpt / 2, -dpt / 2]:
			for sx in [-1.0, 1.0]: _post(m, cx + sx * (w / 2 + r), z, eh - 0.1, r, true, RED)
		var old := m.push(cx, 0, 0)
		_sill(m, w)
		m.add("p", "wood", C.PA(Kit.box(w + 0.4, 0.18, 0.2, 0, 2.65, 0), [0x5f8072, 0x48675a], 0.03, R), 0.012)
		_leaves(m, w, 2.45, 0.18, open, 2, b == 0)
		m.pop(old)
		if b != 0: m.add("p", "mud", C.PA(Kit.box(w + 0.3, low_eave - 2.8, 0.12, cx, (2.75 + low_eave) / 2, 0), C.PLASTER, 0.03, R), 0.01)
		else: m.add("p", "mud", C.PA(Kit.box(w + 0.3, hi_eave - 2.8, 0.12, cx, (2.75 + hi_eave) / 2, 0), C.PLASTER, 0.03, R), 0.01)
		_gable_roof_at(m, cx + (b * 0.3 if b != 0 else 0.0), w / 2 + r + (0.6 if b == 0 else 0.3), dpt / 2 + 0.8, eh, (dpt / 2 + 0.8) * (0.62 if b == 0 else 0.6))
	return { half = 1.5 * (w + 2 * r) + 0.05, eave_min = low_eave - 0.18 }
