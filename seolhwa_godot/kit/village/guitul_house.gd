# 귀틀집 — 통나무를 井자로 귀를 맞춰 쌓은 벽(귀틀)의 산간·북부 민가(북부·고산 권역용 미리).
# 고증: 통나무 끝을 반턱으로 따서 네 귀를 엇물려 쌓고 틈을 진흙으로 메웠다(강원·평안·함경 산간, 울릉 투막집). 지붕은 억새·너와·
#   굴피. 1870년 지리산권에 귀틀집이 있었는지는 "가설"(화전민 움막 수준으로 드묾).
# 위에서 볼 때: 네 귀에 엇물려 튀어나온 통나무 끝 + 희뿌연 억새 맞배(기본) — 흙벽 집과 벽·지붕 모두 다르다.
# params: seed, w(6.0), d(4.2), roof("eoksae"|"neowa"|"gulpi"), lod(0|1)
extends RefCounted
const C := preload("res://kit/village/_common.gd")

static func build(params: Dictionary) -> Dictionary:
	var m := C.M.new(int(params.get("seed", 1)))
	var info := draw(m, params)
	return m.result("귀틀집", Vector2(info.W + 2.2, info.D + 2.6))

static func draw(m: C.M, o: Dictionary) -> Dictionary:
	var W: float = o.get("w", 6.0); var D: float = o.get("d", 4.2)
	var lod := int(o.get("lod", 0)) == 1
	var R := m.rng
	var F := 0.3; var wallH := 1.9; var top := F + wallH; var zf := D / 2
	var n := 5 if lod else 8
	var dy := wallH / n; var r := dy * 0.56
	var ov := 0.28   # 귀 밖으로 튀어나온 길이
	var logs := []
	# 막돌 기단(낮게)
	m.add("base", "stone", C.PA(Kit.box(W + 0.9, 0.4, D + 0.9, 0, F - 0.2, 0), C.STONE, 0.06, R), 0.03)
	# 안쪽 진흙 벽(통나무 틈 메움) — 뒤·옆만(앞은 문·창 구멍)
	m.add("body", "mud", C.PA(Kit.box(W - 0.1, wallH, 0.1, 0, F + wallH / 2, -zf + 0.02), C.MUD, 0.04, R), 0)
	for s in [-1, 1]: m.add("body", "mud", C.PA(Kit.box(0.1, wallH, D - 0.1, s * (W / 2 - 0.02), F + wallH / 2, 0), C.MUD, 0.04, R), 0)
	# 앞벽 구멍(로컬 x 구간, y 구간): 왼쪽 방 창, 가운데 방문, 오른쪽 부엌문
	var holes := [[-W / 3 - 0.4, -W / 3 + 0.4, F + 0.8, F + 1.45], [-0.5, 0.5, F - 0.1, F + 1.68], [W / 3 - 0.45, W / 3 + 0.45, F - 0.1, F + 1.62]]
	for i in n:
		var y := F + dy * (i + 0.5)
		var ys := y + dy * 0.5   # 옆벽은 반 단 엇갈림
		# 뒤
		logs.append(_log(R, -W / 2 - ov, W / 2 + ov, y, -zf, true))
		# 옆
		if i < n - 1 or true:
			for s in [-1, 1]: logs.append(_log(R, -zf - ov, zf + ov, minf(ys, top - r * 0.5), s * W / 2, false))
		# 앞(구멍 피해 토막)
		var segs := [[-W / 2 - ov, W / 2 + ov]]
		for h in holes:
			if y + r * 0.6 < h[2] or y - r * 0.6 > h[3]: continue
			var nxt := []
			for sgm in segs:
				if h[1] <= sgm[0] or h[0] >= sgm[1]: nxt.append(sgm); continue
				if h[0] - 0.07 > sgm[0]: nxt.append([sgm[0], h[0] - 0.07])
				if sgm[1] > h[1] + 0.07: nxt.append([h[1] + 0.07, sgm[1]])
			segs = nxt
		for sgm in segs:
			if sgm[1] - sgm[0] > 0.12: logs.append(_log(R, sgm[0], sgm[1], y, zf, true))
	m.add("body", "bark", Kit.merge(logs), 0.0 if lod else 0.014)
	# 문·창
	if lod:
		m.add("front", "paper", C.vplane(0.9, 1.5, -0.0, F + 0.8, zf + 0.02), 0)
	else:
		C.paper_panel(m, "front", -W / 3, F + 1.125, 0.72, 0.6, zf + 0.03)
		C.paper_panel(m, "front", -0.24, F + 0.8, 0.46, 1.5, zf + 0.03)
		C.paper_panel(m, "front", 0.24, F + 0.8, 0.46, 1.5, zf + 0.03)
		m.add("front", "wood", C.P(Kit.box(0.86, 1.6, 0.06, W / 3, F + 0.75, zf - 0.03), 0x5a4432, 0x3f2f22, 0.04, R), 0.012)
		for x in [-0.55, 0.55, W / 3 - 0.5, W / 3 + 0.5]: m.add("front", "wood", C.PA(Kit.box(0.1, 1.72, 0.14, x, F + 0.82, zf + 0.02), C.WOOD), 0.012)
		# 쪽마루 + 디딤돌
		m.add("front", "wood", C.PA(Kit.box(1.8, 0.08, 0.5, -0.4, F + 0.02, zf + 0.42), C.WOOD_L), 0.015)
		m.add("base", "stone", C.P(Kit.box(0.8, 0.16, 0.45, 0, 0.06, zf + 0.95), 0xb8b2a5, 0x8e897f, 0.05, R), 0.02)
		# 통나무 굴뚝
		m.add("body", "bark", C.P(Kit.cyl(0.2, 0.23, 2.9, 7, W / 2 + 0.5, 1.45, -zf + 0.4), 0x6e5a46, 0x4a3b2e, 0.05, R), 0.025)
		m.circle(W / 2 + 0.5, -zf + 0.4, 0.3)
	# 지붕
	var roof: String = o.get("roof", "eoksae")
	var eave := top + 0.12
	if roof == "neowa" or roof == "gulpi":
		C.board_roof(m, "roof", W + 1.6, D + 2.0, eave, 1.7, roof, W, D, top, lod)
	else:
		C.thatch_gable(m, "roof", W + 1.6, D + 2.1, eave, 1.75, C.EOKSAE, C.EOKSAE_RIDGE)
		if not lod:
			# 억새 누름 새끼(가로 두 줄)
			for s in [-1.0, 1.0]:
				for tp in [0.35, 0.7]:
					var z: float = s * (D + 2.1) / 2 * (1.0 - tp)
					var y := eave + 1.75 * sin(tp * PI / 2) + 0.1
					m.add("roof", "flat", C.P(Kit.cyl(0.04, 0.04, W + 1.2, 4, 0, y, z, 0, 0, PI / 2), 0x6a604e), 0)
	m.box_c(-W / 2 - ov - 0.1, W / 2 + ov + 0.1, -zf - ov - 0.1, zf + 0.7)
	m.light(-W / 3, F + 1.1, zf + 0.2, "window")
	m.light(0, F + 0.9, zf + 0.2, "window")
	m.anchor("door", Vector3(0, 0, zf + 1.3))
	m.anchor("maru", Vector3(-0.4, F, zf + 0.42))
	m.anchor("kitchen", Vector3(W / 3, 0, zf + 0.6))
	return { W = W, D = D, F = F, top = top, eave = eave }

# 통나무 한 토막: along_x면 x0..x1(z=c), 아니면 z0..z1(x=c)
static func _log(R: Kit.Rng, a: float, b: float, y: float, c: float, along_x: bool) -> Kit.Geo:
	var len := b - a; var mid := (a + b) / 2
	var rr := R.between(0.13, 0.15)
	var g := Kit.cyl(rr, rr * R.between(0.9, 1.05), len, 6, 0, 0, 0, 0, 0, PI / 2)
	if along_x: Kit.xf(g, mid, y, c, R.between(0, 1.0), 0, 0)
	else: Kit.xf(g, c, y, mid, R.between(0, 1.0), PI / 2, 0)
	var tone := R.next()
	return C.P(g, 0x86705a if tone < 0.5 else 0x7a6450, 0x5e4c3a if tone < 0.5 else 0x544232, 0.04, R)
