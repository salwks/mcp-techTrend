# 초가(초가삼간) — 웹 buildings.js choga()/chogaInterior() 이식.
# params: seed, w(6, 3칸 폭), d(4), hump(지붕 볼록, 없으면 seed로), gourd(박 넝쿨), open(가운데 방문 열림),
#         chimney(true | "log" 통나무 굴뚝), interior(false: true면 open + 실내 + part 노드 분리)
#         plan: ""(기본) | "il"(남부 一자 홑집: 넓은 통 툇마루, 처마 깊게) | "giyeok"(중부 ㄱ자: 오른쪽 부엌 칸이 앞으로 꺾여 나옴)
#         draw()만 쓰는 옵션(다른 키트가 몸체를 빌릴 때): roof("thatch"|"none"), wall_h(1.85), F(0.4), wing_len(2.8)
# 앞(+z): 왼쪽 방 창, 가운데 방문(두 짝), 오른쪽 부엌 널문, 툇마루, 댓돌. 굴뚝은 오른쪽 뒤.
extends RefCounted
const C := preload("res://kit/village/_common.gd")

static func build(params: Dictionary) -> Dictionary:
	var seed := int(params.get("seed", 1))
	var inside := bool(params.get("interior", false))
	var m := C.M.new(seed, not inside)
	var o := params.duplicate()
	if not o.has("hump"): o.hump = (m.r() - 0.5) * 0.3
	if inside:
		o.open = true; o.dark_inside = false
	var info := draw(m, o)
	var W: float = info.W; var D: float = info.D
	var inn := interior(m, W, D, info.F) if inside else {}
	var res := m.result("초가", Vector2(W + 2.2, D + 2.4))
	if inside:
		var node: Node3D = res.node
		res.interior = { minX = -W / 2 + 0.1, maxX = W / 2 - 0.1, minZ = -D / 2 + 0.1, maxZ = D / 2 - 0.05,
			camera = { pitch = 50, distance = 9, fov = 30 }, hide = [node.get_node("roof"), node.get_node("front")] }
		res.lights.append({ x = inn.lamp.x, y = inn.lamp.y, z = inn.lamp.z, kind = "lantern" })
	return res

# m에 초가 한 채를 그리고 충돌체·조명·앵커를 등록. o: w,d,hump,gourd,open,chimney
static func draw(m: C.M, o: Dictionary) -> Dictionary:
	var W: float = o.get("w", 6.0); var D: float = o.get("d", 4.0)
	var F: float = o.get("F", 0.4); var wallH: float = o.get("wall_h", 1.85)
	var plan: String = o.get("plan", "")
	var top := F + wallH; var zf := D / 2; var t := 0.16
	var R := m.rng
	# 기단
	m.add("base", "stone", C.PA(Kit.box(W + 0.9, 0.55, D + 0.9, 0, F - 0.275, 0), C.STONE, 0.06, R), 0.03)
	for i in 9:
		var s := Kit.lump(0.2 + m.r() * 0.08, 0, R, 0.3, 0.7)
		m.add("base", "stone", C.P(Kit.xf(s, -W / 2 - 0.2 + (W + 0.4) * (i / 8.0), 0.1 + m.r() * 0.1, D / 2 + 0.45), 0xb0aa9e, 0x8a857b, 0.05, R), 0.02)
	# 기둥
	# 기둥은 벽보다 0.03 높게(도리 밑까지) — 벽 윗면과 기둥 윗면이 같은 높이로 겹치면 잘라 보기(지붕 숨김)에서 깜빡인다(fix-1021)
	var ph := wallH + 0.03
	for x in [-W / 2, -W / 6, W / 6, W / 2]:
		m.add("front", "wood", C.PA(Kit.box(0.2, wallH + 0.05, 0.2, x, F + wallH / 2, zf), C.WOOD), 0.02)
		m.add("body", "wood", C.PA(Kit.box(0.2, ph, 0.2, x, F + ph / 2, -zf), C.WOOD), 0.02)
	for s in [-1, 1]: m.add("body", "wood", C.PA(Kit.box(0.2, ph, 0.2, s * W / 2, F + ph / 2, 0), C.WOOD), 0.02)
	# 뒷벽, 옆벽
	m.add("body", "mud", C.PA(Kit.box(W, wallH, t, 0, F + wallH / 2, -zf), C.MUD, 0.04, R), 0.02)
	for s in [-1, 1]: m.add("body", "mud", C.PA(Kit.box(t, wallH, D, s * W / 2, F + wallH / 2, 0), C.MUD, 0.04, R), 0.02)
	# 앞벽 3칸
	var bw := W / 3
	C.holed_wall(m, "front", -W / 2, -W / 2 + bw, F, top, -W / 3 - 0.36, -W / 3 + 0.36, F + 0.85, F + 1.45, zf, t, C.MUD)
	C.paper_panel(m, "front", -W / 3, F + 1.15, 0.72, 0.6, zf)
	C.holed_wall(m, "front", -bw / 2, bw / 2, F, top, -0.7, 0.7, F, F + 1.62, zf, t, C.MUD)
	if o.get("open", false):
		for s in [-1, 1]:
			var g := Kit.box(0.7, 1.6, 0.05, -s * 0.35, 0, 0)
			Kit.xf(g, s * 0.7, F + 0.81, zf + 0.06, 0, s * 1.2, 0)
			m.add("front", "paper", g, 0)
		# 문설주는 문구멍(±0.7) 안쪽으로 내어 세운다(면이 문구멍 벽 면과 겹치면 깜빡임), 위끝은 인방 속(F + 1.64)
		#   두께 0.18(벽 0.16·인방 0.2 사이 — 앞뒤 면이 어느 쪽과도 같은 평면이 아니게), 문지방은 문설주 사이
		for s in [-1, 1]: m.add("front", "wood", C.PA(Kit.box(0.08, 1.64, 0.18, s * 0.66, F + 0.82, zf), C.WOOD), 0.012)
		m.add("front", "wood", C.PA(Kit.box(1.48, 0.1, 0.2, 0, F + 1.66, zf), C.WOOD), 0.012)
		m.add("front", "wood", C.PA(Kit.box(1.24, 0.06, 0.2, 0, F + 0.03, zf), C.WOOD), 0.01)
		if o.get("dark_inside", true):
			# 실내가 없으면 열린 문 안쪽을 어두운 방으로 막음(장판 + 안벽)
			m.add("body", "flat", C.P(Kit.box(1.6, 1.7, 0.04, 0, F + 0.85, zf - 1.2), 0x4a3c2e, 0x2e251c), 0)
			m.add("body", "flat", C.P(Kit.box(1.56, 0.03, 1.16, 0, F + 0.02, zf - 0.6), 0xb8955a, 0x9a7a48), 0)   # 안벽 안쪽(옆면이 안벽 옆면과 겹치지 않게)
	else:
		C.paper_panel(m, "front", -0.35, F + 0.82, 0.66, 1.58, zf)
		C.paper_panel(m, "front", 0.35, F + 0.82, 0.66, 1.58, zf)
	C.holed_wall(m, "front", bw / 2, W / 2, F, top, W / 3 - 0.45, W / 3 + 0.45, F, F + 1.6, zf, t, C.MUD)
	# 부엌 널문
	m.add("front", "wood", C.P(Kit.box(0.9, 1.6, 0.06, W / 3, F + 0.8, zf - 0.02), 0x5a4432, 0x3f2f22, 0.04, R), 0.012)
	# 도리
	m.add("front", "wood", C.PA(Kit.box(W + 0.4, 0.18, 0.22, 0, top + 0.02, zf), C.WOOD), 0.02)
	m.add("body", "wood", C.PA(Kit.box(W + 0.4, 0.18, 0.22, 0, top + 0.02, -zf), C.WOOD), 0.02)
	# 툇마루
	var wing_len: float = o.get("wing_len", 2.8)
	if plan == "il":
		# 남부 홑집: 앞면 전체에 깊은 툇마루
		m.add("front", "wood", C.PA(Kit.box(W + 0.3, 0.1, 0.95, 0, F - 0.02, zf + 0.55), C.WOOD_L), 0.02)
		for x in [-W / 2, -W / 6, W / 6, W / 2]: m.add("front", "wood", C.PA(Kit.box(0.12, 0.4, 0.12, x, F - 0.24, zf + 0.95), C.WOOD), 0.01)
	elif plan == "giyeok":
		var mx0 := -W / 2 - 0.15; var mx1 := bw / 2 - 0.1
		m.add("front", "wood", C.PA(Kit.box(mx1 - mx0, 0.1, 0.62, (mx0 + mx1) / 2, F - 0.02, zf + 0.42), C.WOOD_L), 0.02)
		for x in [mx0 + 0.1, mx1 - 0.1]: m.add("front", "wood", C.PA(Kit.box(0.12, 0.4, 0.12, x, F - 0.24, zf + 0.62), C.WOOD), 0.01)
		wing(m, bw / 2, W / 2, zf, zf + wing_len, F, top, t, C.MUD, "mud", C.STONE)
	else:
		m.add("front", "wood", C.PA(Kit.box(bw + 1.2, 0.1, 0.62, 0, F - 0.02, zf + 0.42), C.WOOD_L), 0.02)
		for s in [-1, 1]: m.add("front", "wood", C.PA(Kit.box(0.12, 0.4, 0.12, s * (bw / 2 + 0.45), F - 0.24, zf + 0.62), C.WOOD), 0.01)
	# 댓돌(남부 一자는 깊은 툇마루 앞으로 — 마루 밑에 묻히지 않게)
	m.add("base", "stone", C.P(Kit.box(0.9, 0.18, 0.5, 0, 0.05, zf + _dz(plan)), 0xb8b2a5, 0x8e897f, 0.05, R), 0.02)
	# 굴뚝
	if str(o.get("chimney", true)) == "log":
		# 산촌 통나무 굴뚝(구새통)
		# 처마 밖에 세운다(지붕 둘레 W/2 + 0.75 + 띠 2% 바깥) — 옛 W/2 + 0.5는 처마 속이라 통나무가 이엉을 뚫고 올라왔다
		var lx := W / 2 + 1.1
		m.add("body", "bark", C.P(Kit.cyl(0.2, 0.23, 2.9, 7, lx, 1.45, -zf + 0.4), 0x6e5a46, 0x4a3b2e, 0.05, R), 0.025)
		m.circle(lx, -zf + 0.4, 0.3)
	elif o.get("chimney", true):
		m.add("body", "stone", C.P(Kit.box(0.42, 1.5, 0.42, W / 2 + 0.55, 0.75 - 0.3, -zf + 0.4), 0x9d8a6a, 0x6f6452, 0.06, R), 0.025)
		m.add("body", "flat", C.P(Kit.box(0.56, 0.1, 0.56, W / 2 + 0.55, 1.2, -zf + 0.4), 0x6f6452), 0.02)
		m.circle(W / 2 + 0.55, -zf + 0.4, 0.4)
	# 초가 지붕
	var eave := top + 0.12
	if o.get("roof", "thatch") == "thatch":
		thatch_roof(m, o, W, D, eave, plan, bw, zf, wing_len)
	_finish(m, o, W, D, F, zf, plan, bw, wing_len)
	return { F = F, top = top, eave = eave, W = W, D = D, bw = bw, zf = zf, wing_len = wing_len if plan == "giyeok" else 0.0 }

# 처마 모서리 반지름(m): 처마가 벽에서 0.75~0.8m 나오고 모서리만 둥글다 — 벽 모서리 위 처마 폭 약 0.65m
const ROOF_RC := 1.0
# 처마 밑면(soffit, fix-1021): 처마 띠 아래끝(처마 - 0.32)에서 안쪽 0.45m까지 비스듬히 올라 처마 + 0.04 높이 천장으로.
#   벽 꼭대기 top = 처마 - 0.12, 도리 윗면 top + 0.11 = 처마 - 0.01 → 천장과 도리 사이 0.05m(먹선 0.01 포함해도 0.03 이상).
#   안쪽 0.35m: 처마 둘레(벽선 + 0.75~0.8)에서 들어간 둘레가 벽선 + 0.40(모서리 반지름 0.65) — 도리 끝(벽선 + 0.2)·모서리 기둥(+0.1) 바깥.
#   wall_h·F를 바꿔도 처마가 top + 0.12를 따르므로 그대로 맞는다(낮은 초가는 choga_low가 따로).
const SOFFIT_UP := 0.04
const SOFFIT_IN := 0.35

static func thatch_roof(m: C.M, o: Dictionary, W: float, D: float, eave: float, plan: String, bw: float, zf: float, wing_len: float) -> void:
	var R := m.rng
	var th := 1.12; var X := W / 2 + 0.75; var Z := D / 2 + 0.8; var Hh: float = 1.35 + float(o.get("hump", 0.0))
	var zc := 0.0
	if plan == "il": Z += 0.3; zc = 0.25
	# 이엉 몸: 둥근 모서리 사각 둘레(C.rr_dome) — 옛 타원 돔은 모서리에서 처마가 벽선 안으로 들어갔다
	m.add("roof", "thatch", C.PA(C.rr_dome(X, Z, ROOF_RC, eave, Hh, zc, th, 28, 6), C.THATCH, 0.05, R), 0.05)
	m.add("roof", "thatch", C.PA(C.rr_band(X, Z, ROOF_RC, eave + 0.02, eave - 0.32, zc, 0.02, 28, eave + SOFFIT_UP, SOFFIT_IN), C.THATCH_LIP, 0.04, R), 0.04)
	m.add("roof", "thatch", C.P(Kit.cyl(0.17, 0.17, W * 0.42, 8, 0, eave + Hh - 0.08, zc, 0, 0, PI / 2), 0xb39d6c, 0x8f7b52), 0.03)
	if o.get("gourd", false):
		for q in [[-0.35, 0.35, 0.3], [0.1, 0.5, 0.36], [0.4, 0.2, 0.26]]:
			var px: float = q[0] * X; var pz: float = q[1] * Z; var gs: float = q[2]
			var py := C.rr_height(X, Z, ROOF_RC, eave, Hh, zc, th, px, pz)
			m.add("roof", "organic", C.P(Kit.xf(C.sphere(gs, 8, 5), px, py + gs * 0.55, pz, 0, 0, 0, 1, 0.8, 1), 0xf1ecd6, 0xc9c9a0), 0.015)
			m.add("roof", "leaf", C.P(Kit.xf(Kit.lump(gs * 0.9, 0, R, 0.2, 0.35), px + 0.3, py + 0.08, pz - 0.2), 0x7f9456, 0x56663a), 0.012)
	if plan == "giyeok":
		# 꺾인 부엌 칸 지붕: 좁은 둥근 모서리 이엉이 안채 지붕에 파고든다
		var cx := (bw / 2 + W / 2) / 2; var z0 := zf - 0.9; var z1 := zf + wing_len + 0.8
		var X2 := (W / 2 - bw / 2) / 2 + 0.75; var Z2 := (z1 - z0) / 2; var H2 := Hh * 0.82
		var rc2 := minf(ROOF_RC, X2 * 0.6)
		m.add("roof", "thatch", C.PA(Kit.xf(C.rr_dome(X2, Z2, rc2, eave, H2, 0.0, th, 22, 5), cx, 0, (z0 + z1) / 2), C.THATCH, 0.05, R), 0.05)
		# 처마 띠·밑면은 안채 앞 도리 바깥(zf + 0.12)부터만 — 안채 지붕 밑으로 파고든 뒤쪽 띠는 안채 방 안·앞벽 위에 매달린다(fix-1021)
		var wb := _keep_front(Kit.xf(C.rr_band(X2, Z2, rc2, eave + 0.02, eave - 0.32, 0.0, 0.02, 22, eave + SOFFIT_UP + 0.02, SOFFIT_IN), cx, 0, (z0 + z1) / 2), zf + 0.12)
		m.add("roof", "thatch", C.PA(wb, C.THATCH_LIP, 0.04, R), 0.04)
		m.add("roof", "thatch", C.P(Kit.cyl(0.15, 0.15, Z2 * 0.8, 8, cx, eave + H2 - 0.07, (z0 + z1) / 2 + 0.3, PI / 2, 0, 0), 0xb39d6c, 0x8f7b52), 0.03)

# 삼각형 중 z가 모두 zmin보다 앞(+z)인 것만 남긴다(꺾인 칸 처마 띠의 뒤쪽 자르기)
static func _keep_front(g: Kit.Geo, zmin: float) -> Kit.Geo:
	var o := Kit.Geo.new()
	for i in range(0, g.pos.size(), 3):
		if g.pos[i].z < zmin or g.pos[i + 1].z < zmin or g.pos[i + 2].z < zmin: continue
		o.tri(g.pos[i], g.pos[i + 1], g.pos[i + 2], g.uv[i], g.uv[i + 1], g.uv[i + 2])
	return o

# 댓돌 자리(앞벽 zf에서 앞으로)
static func _dz(plan: String) -> float:
	return 1.3 if plan == "il" else 0.95

# 충돌·조명·앵커·걷기 면
# 충돌체는 벽(과 기단 옆·뒤 띠)만 — 기단 앞 띠·툇마루·댓돌은 걷기 면(M.walk_floor): 기단(F 0.3~0.4m)은 한 걸음 단(0.32m)보다 높아
# 댓돌을 밟아야 오르고, 마루에서 열린 방문으로 방바닥에 들어선다(발이 바닥 높이에 선다).
static func _finish(m: C.M, o: Dictionary, W: float, D: float, F: float, zf: float, plan: String, bw: float, wing_len: float) -> void:
	var tt := 0.12
	m.box_c(-W / 2 - 0.45, W / 2 + 0.45, -D / 2 - 0.45, -D / 2 + tt)   # 뒷벽 + 기단 뒤 띠
	m.box_c(-W / 2 - 0.45, -W / 2 + tt, -D / 2, D / 2)                  # 옆벽 + 기단 옆 띠
	m.box_c(W / 2 - tt, W / 2 + 0.45, -D / 2, D / 2)
	if o.get("open", false):
		m.box_c(-W / 2 - 0.1, -0.72, D / 2 - tt, D / 2 + 0.1)            # 앞벽(방문 양옆)
		m.box_c(0.72, W / 2 + 0.1, D / 2 - tt, D / 2 + 0.1)
		if o.get("dark_inside", true):
			# 실내가 없는 열린 문: 문 안 어두운 방(1.2m)까지만
			m.box_c(-0.86, 0.86, zf - 1.32, zf - 1.16)
			m.box_c(-0.86, -0.72, zf - 1.32, zf)
			m.box_c(0.72, 0.86, zf - 1.32, zf)
	else:
		m.box_c(-W / 2 - 0.1, W / 2 + 0.1, -D / 2, D / 2 + 0.1)           # 닫힌 집: 몸채 전체
	# 걷기 면: 기단 윗면 · 툇마루 · 댓돌(지면에서 한 단) · 꺾인 칸 기단
	m.walk_floor(-W / 2 - 0.45, W / 2 + 0.45, -D / 2 - 0.45, D / 2 + 0.45, F)
	if plan == "il":
		m.walk_floor(-(W + 0.3) / 2, (W + 0.3) / 2, zf + 0.075, zf + 1.025, F + 0.03)
	elif plan == "giyeok":
		m.walk_floor(-W / 2 - 0.15, bw / 2 - 0.1, zf + 0.11, zf + 0.73, F + 0.03)
	else:
		m.walk_floor(-(bw + 1.2) / 2, (bw + 1.2) / 2, zf + 0.11, zf + 0.73, F + 0.03)
	var dz := zf + _dz(plan)
	m.walk_floor(-0.45, 0.45, dz - 0.25, dz + 0.25, 0.14)
	m.light(-W / 3, F + 1.15, zf + 0.2, "window")
	m.light(0, F + 0.95, zf + 0.2, "window")
	m.anchor("door", Vector3(0, 0, zf + (1.7 if plan == "il" else 1.3)))
	m.anchor("maru", Vector3(0, F, zf + (0.55 if plan == "il" else 0.42)))
	if plan == "giyeok":
		m.box_c(bw / 2 - 0.3, W / 2 + 0.45, zf, zf + wing_len + 0.4)
		m.walk_floor(bw / 2 - 0.25, W / 2 + 0.65, zf, zf + wing_len + 0.45, F)
		m.anchor("kitchen", Vector3(bw / 2 - 0.7, 0, zf + wing_len / 2))
	else:
		m.anchor("kitchen", Vector3(W / 3, 0, zf + 0.5))

# ㄱ자 꺾인 칸(부엌·건넌방): x0..x1, 안채 앞벽 zf=z0에서 z1까지 앞으로. 서쪽(마당 쪽) 벽에 문, 남쪽 벽에 작은 창
# base_dz: 안채 기단이 앞벽에서 나온 폭 — 꺾인 칸 기단은 거기서부터(두 기단 윗면이 같은 높이로 겹치면 깜빡인다, fix-1021)
static func wing(m: C.M, x0: float, x1: float, z0: float, z1: float, F: float, top: float, t: float, col: Array, key: String, base_col: Array, base_dz := 0.45) -> void:
	var R := m.rng
	var L := z1 - z0; var cz := (z0 + z1) / 2
	var bz0 := z0 + base_dz; var bz1 := z1 + 0.445
	m.add("base", "stone", C.PA(Kit.box(x1 - x0 + 0.9, F + 0.15, bz1 - bz0, (x0 + x1) / 2 + 0.2, (F + 0.15) / 2 - 0.15, (bz0 + bz1) / 2), base_col, 0.06, R), 0.03)
	m.add("body", key, C.PA(Kit.box(t, top - F, L, x1, (F + top) / 2, cz), col, 0.04, R), 0.02)
	C.holed_wall(m, "front", x0, x1, F, top, (x0 + x1) / 2 - 0.36, (x0 + x1) / 2 + 0.36, F + 0.8, F + 1.4, z1, t, col, key)
	C.paper_panel(m, "front", (x0 + x1) / 2, F + 1.1, 0.72, 0.6, z1)
	var old := m.push(x0, 0, cz, -PI / 2)
	C.holed_wall(m, "front", -L / 2, L / 2, F, top, -0.45, 0.45, F, F + 1.65, 0, t, col, key)
	m.add("front", "wood", C.P(Kit.box(0.9, 1.62, 0.06, 0, F + 0.81, -0.03), 0x5a4432, 0x3f2f22, 0.04, R), 0.012)
	m.pop(old)
	for q in [[x0, z1], [x1, z1]]: m.add("front", "wood", C.PA(Kit.box(0.2, top - F + 0.05, 0.2, q[0], (F + top) / 2, q[1]), C.WOOD), 0.02)
	m.add("front", "wood", C.PA(Kit.box(x1 - x0 + 0.4, 0.18, 0.22, (x0 + x1) / 2, top + 0.02, z1), C.WOOD), 0.02)
	# 옆 도리는 안채 앞 도리와 꺾인 칸 앞 도리 사이(끝이 두 도리 속에 같은 밑면으로 겹치지 않게)
	m.add("front", "wood", C.PA(Kit.box(0.22, 0.18, L - 0.22, x0, top + 0.02, cz), C.WOOD), 0.02)

# 외딴집 실내(웹 chogaInterior). part "interior"
static func interior(m: C.M, W: float, D: float, F: float) -> Dictionary:
	var R := m.rng
	var iw := W - 0.2; var id := D - 0.2
	m.add("interior", "flat", C.P(Kit.box(iw, 0.04, id, 0, F, 0), 0xd8b36b, 0xcaa25a, 0.04, R), 0)
	m.walk_floor(-iw / 2, iw / 2, -id / 2, id / 2, F + 0.02)   # 방바닥(장판)
	for i in range(-2, 3): m.add("interior", "flat", C.P(Kit.box(0.02, 0.005, id, i * iw / 5.2, F + 0.025, 0), 0x9c7a40), 0)
	# 도배 벽(종이 바른 안벽): 기둥 안면(벽선 - 0.1)·도리 안면(뒤 - 0.11)보다 안쪽 0.11~0.13에 — 옛 자리(벽선 - 0.1 가운데)는 뒤 도리
	#   안면과 같은 평면이라 방 뒤 벽 윗단이 깜빡였다(fix-1021). 뒷벽이 옆벽 사이를 막고 옆벽은 뒷벽 안면에서 시작(모서리 겹침 없음).
	var lw := W / 2 - 0.12; var lb := -D / 2 + 0.12
	m.add("interior", "flat", C.P(Kit.box(lw * 2 + 0.02, 1.8, 0.02, 0, F + 0.92, lb), 0xefe5cc, 0xddd0b0, 0.02, R), 0)
	for s in [-1, 1]: m.add("interior", "flat", C.P(Kit.box(0.02, 1.8, D / 2 - 0.13 - lb - 0.01, s * lw, F + 0.92, (lb + 0.01 + D / 2 - 0.13) / 2), 0xefe5cc, 0xddd0b0, 0.02, R), 0)
	var cx := -W / 2 + 0.9; var cz := -D / 2 + 0.55
	m.add("interior", "wood", C.P(Kit.box(1.3, 0.75, 0.55, cx, F + 0.4, cz), 0x5c3c26, 0x43291a, 0.03, R), 0.02)
	for dx in [-0.4, 0, 0.4]: m.add("interior", "flat", C.P(Kit.box(0.12, 0.14, 0.02, cx + dx, F + 0.55, cz + 0.285), 0xc9a348), 0.005)
	m.add("interior", "flat", C.P(Kit.box(1.36, 0.05, 0.6, cx, F + 0.79, cz), 0x4a2f1d), 0.01)
	var bc := [0xa8483a, 0x3f5f7a, 0xe2d8bf, 0xc9a34a]
	for i in bc.size(): m.add("interior", "flat", C.P(Kit.box(1.0 - i * 0.04, 0.12, 0.6, cx, F + 0.88 + i * 0.12, cz), bc[i], bc[i], 0.03, R), 0.01)
	var tx := 0.75; var tz := -1.05
	m.add("interior", "wood", C.P(Kit.cyl(0.42, 0.42, 0.05, 12, tx, F + 0.32, tz), 0x7a5234, 0x6a4428), 0.015)
	m.add("interior", "wood", C.P(Kit.cyl(0.34, 0.3, 0.26, 12, tx, F + 0.16, tz), 0x5c3c26, 0x43291a), 0.01)
	m.add("interior", "flat", C.P(Kit.cyl(0.1, 0.07, 0.07, 10, tx - 0.12, F + 0.38, tz), 0xe8e2d2, 0xc8c0ac), 0.006)
	m.add("interior", "flat", C.P(Kit.cyl(0.09, 0.06, 0.06, 10, tx + 0.15, F + 0.38, tz + 0.08), 0xe8e2d2, 0xc8c0ac), 0.006)
	for q in [[tx - 0.75, tz + 0.15], [tx + 0.7, tz + 0.3]]: m.add("interior", "flat", C.P(Kit.box(0.55, 0.06, 0.55, q[0], F + 0.04, q[1]), 0x8a3e3a, 0x6e302c, 0.03, R), 0.01)
	var lx := W / 2 - 0.55; var lz := -D / 2 + 0.55
	m.add("interior", "flat", C.P(Kit.cyl(0.16, 0.2, 0.05, 8, lx, F + 0.03, lz), 0x5a3f2a), 0.01)
	m.add("interior", "flat", C.P(Kit.cyl(0.025, 0.03, 0.62, 6, lx, F + 0.34, lz), 0x5a3f2a), 0.008)
	m.add("interior", "flat", C.P(Kit.cyl(0.11, 0.06, 0.05, 8, lx, F + 0.67, lz), 0xe0d6be, 0xbfb49a), 0.008)
	m.add("interior", "glow", C.P(Kit.cone(0.03, 0.1, 6, lx, F + 0.75, lz), 0xffd27a, 0xff9a3a), 0)
	m.add("interior", "wood", C.PA(Kit.box(1.1, 0.05, 0.25, 0.9, F + 1.35, -D / 2 + 0.25), C.WOOD_L), 0.01)
	m.add("interior", "onggi", C.P(Kit.cyl(0.1, 0.12, 0.2, 10, 0.7, F + 1.48, -D / 2 + 0.25), 0x6a4430, 0x4a2e20), 0.006)
	m.add("interior", "onggi", C.P(Kit.cyl(0.08, 0.1, 0.16, 10, 1.05, F + 1.46, -D / 2 + 0.25), 0x6a4430, 0x4a2e20), 0.006)
	m.box_c(cx - 0.7, cx + 0.7, cz - 0.35, cz + 0.35)
	m.circle(tx, tz, 0.45)
	m.circle(lx, lz, 0.22)
	return { lamp = { x = lx, y = F + 0.8, z = lz } }
