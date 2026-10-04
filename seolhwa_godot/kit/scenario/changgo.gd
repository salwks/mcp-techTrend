# 창고 — 최종장 「칠패의 밤」(S8002·S8008 A·S8012~S8016)과 ACT 1 빈 창고(S1005). 들어갈 수 있다.
# style:
#   chilpae  칠패 창고 줄의 한 채: 기와, 흙벽, 높은 마루(바람 통하는 곳간식), 정면 3칸 가운데 널문. 곡물가마니·궤짝·저울
#   seogang  서강 옛 곡물창고(강창): 더 크고 낡음(바랜 벽·빠진 기와). 12년 전 불의 흔적(그을린 대들보). 숨은 바닥·수량패 홈 기본
#   empty    빈 창고(S1005 책쾌가 묶여 있던 곳): 초가, 흙바닥, 텅 빔 — 가운데 기둥(묶인 자리), 부서진 궤짝, 새끼줄
# 상태(주 그룹 main, PRP_FIN_003 창고 화재 3단계): NORMAL / FIRE_1 연기·한쪽 불 / FIRE_2 지붕까지 번진 불·검은 연기 /
#   FIRE_3 무너짐(지붕 내려앉음·불 남음) / BURNT 다 탄 뒤(식은 잔해, 옅은 연기). 무너진 뒤에도 마루 반쪽과 숨은 바닥은 남아 들어갈 수 있다.
# 그룹 hatch(params.hatch, PRP_COM_005·PRP_FIN_004 숨은 바닥 공간): SEALED 마루널 덮임 / OPEN 널을 걷어 낸 구멍 — 유해 일부·수량 기록 조각·박규상 표식
# 그룹 groove(params.groove, PRP_FIN_001 곡물 수량패 홈): NORMAL 빈 홈 / USED 나무패를 끼운 모습
# params: seed, style, hatch, groove, fill("grain"|"goods"|"empty"), old, cold(true: BURNT에 연기 없음 — 오래전에 탄 터)
#   part: ""(기본 — 권역 안에서 단면 실내로 들어감) | "shell"(권역 겉 건물: 실내 없음, 문 자리 막힘 — 안은 실내 공간) |
#         "inside"(실내 공간 region_data/interiors/<id> 안쪽: 앞벽·지붕 숨김, 둘레 어두운 흙바닥, 실내 연기·불티·벽을 타는 불).
#   shell과 inside는 같은 로컬 짜임·앵커라 상태(불·hatch·groove)와 앵커가 그대로 맞는다(prop_states 쌍 twin).
extends RefCounted
const SC := preload("res://kit/scenario/_sc.gd")
const C := preload("res://kit/village/_common.gd")
const Roof := preload("res://kit/landmark/_roof.gd")

const STYLES := {
	chilpae = { W = 10.0, D = 6.0, F = 0.65, H = 2.6, roof = "giwa", fill = "grain", old = false },
	seogang = { W = 13.0, D = 7.0, F = 0.8, H = 2.8, roof = "giwa", fill = "goods", old = true },
	empty = { W = 6.4, D = 4.4, F = 0.15, H = 2.3, roof = "choga", fill = "empty", old = true },
}
const INTACT := ["NORMAL", "FIRE_1", "FIRE_2"]
const RUIN := ["FIRE_3", "BURNT"]

static func build(params: Dictionary) -> Dictionary:
	var style: String = params.get("style", "chilpae")
	var st: Dictionary = STYLES.get(style, STYLES.chilpae)
	var W: float = st.W; var D: float = st.D; var F: float = st.F; var H: float = st.H
	var old: bool = bool(params.get("old", st.old))
	var hatch: bool = bool(params.get("hatch", style == "seogang"))
	var groove: bool = bool(params.get("groove", style == "seogang"))
	var fill: String = params.get("fill", st.fill)
	var s := SC.S.new(int(params.get("seed", 1)))
	var hole = null
	if hatch: hole = { x = W * 0.28, z = -0.2, w = 1.3, d = 1.0 }
	var bays: Array
	if style == "empty": bays = [{ w = 3.2, kind = "gate" }, { w = 3.2, kind = "wall" }]
	else:
		var n := 4 if style == "seogang" else 3
		for i in n: bays.append({ w = W / n, kind = "gate" if i == 1 else "wall" })
	var info := SC.shell(s, { W = W, D = D, F = F, H = H, old = old, roof = st.roof, bays = bays, floor = "earth" if style == "empty" else "wood",
		wall = SC.MUD_OLD if old else SC.MUD, floor_hole = hole, no_light = true, camera = { pitch = 56, distance = 13 if W > 8 else 10 } })
	var zb: float = info.zb; var zf: float = info.zf; var top: float = info.top
	var R := s.rng
	var kpart: String = params.get("part", "")
	if kpart == "shell":
		# 겉 건물: 들어가는 단면 실내 없음 — 문 자리를 막고(입구 자리에 서면 실내 공간으로) 실내 카메라도 쓰지 않는다
		s.interior = null
		s.hide = []
		for x in info.doors: s.box_c(float(x) - 1.15, float(x) + 1.15, zf - 0.2, zf + 0.3)
	elif kpart == "inside":
		# 실내 공간: 둘레는 어두운 흙(빈 곳이 하늘색으로 비치지 않게), 실내는 어둡다(dark — interior.json light가 덮어씀)
		s.add("base", "flat", SC.pa(Kit.box(W + 30.0, 0.04, D + 30.0, 0, -0.05, 0), [0x2a241c, 0x221d16], 0.02, R), 0.0)
		s.interior.near_fade = false
	# 높은 창(환기 살창) 뒷벽 둘
	if style != "empty":
		for x in [-W / 4, W / 4]:
			s.add("body", "wood", SC.pa(Kit.merge([Kit.box(0.9, 0.08, 0.24, x, top - 0.45, zb), Kit.box(0.9, 0.08, 0.24, x, top - 0.85, zb)]), SC.WOOD), 0.01)
			var bars := []
			for k in 5: bars.append(Kit.box(0.04, 0.4, 0.05, x - 0.36 + k * 0.18, top - 0.65, zb + 0.1))
			s.add("body", "wood", SC.pa(Kit.merge(bars), SC.WOOD), 0.0)
	# 12년 전 불의 흔적(서강): 그을린 대들보·벽 얼룩
	if style == "seogang":
		s.add("body", "wood", SC.pa(Kit.box(W - 0.4, 0.26, 0.28, 0, top - 0.1, -0.4), SC.CHAR, 0.05), 0.012)
		s.add("body", "flat", SC.pa(Kit.box(2.6, 1.6, 0.02, -W / 2 + 2.0, F + 1.2, zb + 0.11), [0x4a4038, 0x6a5a48], 0.05), 0.0)
	# 안 채움(멀쩡할 때)
	_fill(s, fill, W, D, F, hole)
	# 수량패 홈(뒷벽 기둥) — 무너져도 남는 굵은 기둥
	if groove: _groove(s, -W * 0.18, zb + 0.24, F)
	# 숨은 바닥
	if hatch: _hatch(s, hole, F)
	# --- 화재 상태 ---
	for part in ["body", "front", "roof", "interior"]: s.wrap_part(part, "main", INTACT)
	s.state_default["main"] = "NORMAL"
	for x in RUIN:
		if not (s.states.main as Array).has(x): s.states.main.append(x)
	# 무너진 모습을 먼저(난수 차례가 겉·안쪽에서 같게 — 불 연출은 part마다 다르다)
	_ruin(s, W, D, F, H, old, hole, style)
	_fire(s, W, D, F, top, info, bool(params.get("cold", false)), kpart == "inside")
	# 앵커
	s.anchor("rubble", Vector3(-W * 0.25, F, 0.2))
	s.anchor("back_wall", Vector3(0, F, zb + 0.8))
	# 최종장(S8014~S8018): 싸움 가운데·문 안쪽 — 실내 공간에서도 같은 로컬
	s.anchor("center", Vector3(0, F, 0.4))
	for x in info.doors:
		s.anchor("door_in", Vector3(float(x), F, zf - 1.0)); break
	if hatch: s.anchor("ritual", Vector3(float(hole.x) - float(hole.w) / 2 - 0.7, F, float(hole.z)))
	if style == "empty":
		s.anchor("bound", Vector3(0.9, F, -0.4))
	return s.result({ chilpae = "칠패 창고", seogang = "서강 옛 창고", empty = "빈 창고" }.get(style, "창고"), Vector2(W + 2.6, D + 3.0))

# 안 채움: 곡물가마니 더미·궤짝·저울 / 빈 창고는 거의 빈
static func _fill(s: SC.S, fill: String, W: float, D: float, F: float, hole) -> void:
	var R := s.rng
	var sacks := []
	var straw := [0xc8b07a, 0x9d8656]
	var spots := []
	if fill == "grain" or fill == "goods":
		# 뒷벽 쪽 가마니 더미(여러 단)
		var nx := int((W - 2.0) / 0.95)
		for i in nx:
			var x := -W / 2 + 1.0 + i * 0.95
			if hole is Dictionary and absf(x - float(hole.x)) < float(hole.w) * 0.5 + 0.6: continue
			var rows := 3 if fill == "grain" else 2
			for lv in rows:
				spots.append(Vector3(x + (lv % 2) * 0.3, F + 0.18 + lv * 0.36, -D / 2 + 0.8))
				if lv < 2: spots.append(Vector3(x + 0.2, F + 0.18 + lv * 0.36, -D / 2 + 1.55))
	for p in spots:
		var g := Kit.lump(0.34, 1, R, 0.12, 0.5)
		Kit.xf(g, p.x, p.y, p.z, 0, R.next() * 0.6, 0, 1.25, 1.0, 0.85)
		sacks.append(Kit.paint(g, Kit.hex(straw[0]), Kit.hex(straw[1]), 0.05, R))
	if not sacks.is_empty(): s.add("interior", "thatch", Kit.merge(sacks), 0.01)
	if fill == "goods" or fill == "grain":
		# 궤짝·저울·말(되)
		for q in [[W / 2 - 1.0, D / 2 - 1.2], [W / 2 - 1.6, D / 2 - 1.0]]:
			s.add("interior", "wood", SC.pa(Kit.box(0.8, 0.6, 0.6, q[0], F + 0.3, q[1]), [0x7a5a3a, 0x5a4028], 0.04, R), 0.012)
		s.add("interior", "wood", SC.pa(Kit.box(0.34, 0.2, 0.34, -W / 2 + 1.2, F + 0.1, D / 2 - 1.0), [0x9a7852, 0x7a5c3e]), 0.008)
		# 대저울(막대 + 추) — 걸이
		s.add("interior", "wood", SC.pa(Kit.box(1.2, 0.04, 0.04, -W / 2 + 1.6, F + 1.6, D / 2 - 1.6), [0x6a4428]), 0.004)
		s.add("interior", "flat", SC.pa(Kit.cyl(0.06, 0.06, 0.08, 6, -W / 2 + 2.1, F + 1.4, D / 2 - 1.6), [0x3a3633]), 0.0)
		s.box_c(W / 2 - 2.1, W / 2 - 0.5, D / 2 - 1.6, D / 2 - 0.6)
		var x0 := -W / 2 + 0.6; var x1 := W / 2 - 0.6
		s.box_c(x0, x1, -D / 2 + 0.2, -D / 2 + 1.95)
	else:
		# 빈 창고: 부서진 궤짝·새끼줄 사리(묶였던 기둥과 끈은 따로 — scenario/props kkeun을 anchors.bound 자리에)
		s.add("interior", "wood", SC.pa(Kit.xf(Kit.box(0.7, 0.5, 0.5), -1.6, F + 0.2, -1.0, 0.2, 0.5, 0.15), [0x7a6a52, 0x5a4c3a], 0.04, R), 0.012)
		for k in 3: s.add("interior", "wood", SC.pa(Kit.xf(Kit.box(0.6, 0.03, 0.12), -0.9 + k * 0.3, F + 0.02, 0.6 + k * 0.2, 0, k * 0.9, 0), [0x7a6a52]), 0.0)
		s.add("interior", "thatch", SC.pa(Kit.cyl(0.3, 0.3, 0.12, 10, -2.2, F + 0.06, 1.2), [0xc8b07a, 0x9d8656]), 0.008)
		s.box_c(-2.0, -1.2, -1.3, -0.7)

# 곡물 수량패 홈: 뒷벽에 붙은 굵은 기둥, 가운데 세로 홈 + 눈금. USED면 나무패가 끼워져 있다
static func _groove(s: SC.S, x: float, z: float, F: float) -> void:
	var p := s.p("groove_post")
	p.add("wood", SC.pa(Kit.box(0.34, 2.4, 0.3, x, F + 1.2, z), [0x5a4430, 0x3e2e20], 0.04), 0.015)
	p.add("flat", SC.pa(Kit.box(0.09, 0.62, 0.02, x, F + 1.3, z + 0.155), [0x1a1410]), 0.0)
	var marks := []
	for k in 9: marks.append(Kit.box(0.12 if k % 3 else 0.2, 0.02, 0.02, x + 0.12, F + 1.0 + k * 0.07, z + 0.155))
	p.add("flat", SC.pa(Kit.merge(marks), [0x2a2018]), 0.0)
	s.st("groove", "NORMAL", "NORMAL")
	var u := s.st("groove", "USED")
	u.add("wood", SC.pa(Kit.box(0.08, 0.58, 0.05, x, F + 1.3, z + 0.17), [0xb89a68, 0x8a6e48]), 0.006)
	var notch := []
	for k in 6: notch.append(Kit.box(0.04, 0.012, 0.01, x + 0.03, F + 1.1 + k * 0.07, z + 0.2))
	u.add("flat", SC.pa(Kit.merge(notch), [0x3a2c20]), 0.0)
	s.anchor("groove", Vector3(x, F, z + 0.8))

# 숨은 바닥 공간: SEALED = 구멍 위 마루널(살짝 다른 색·고리) / OPEN = 걷어 낸 널(옆에 쌓임) + 마루 밑 공간
static func _hatch(s: SC.S, hole: Dictionary, F: float) -> void:
	var hx: float = hole.x; var hz: float = hole.z; var hw: float = hole.w; var hd: float = hole.d
	var se := s.st("hatch", "SEALED", "SEALED")
	se.indoor = true
	var planks := []
	var n := 4
	for k in n: planks.append(Kit.box(hw / n - 0.02, 0.05, hd, hx - hw / 2 + (k + 0.5) * hw / n, F + 0.015, hz))
	se.add("wood", SC.pa(Kit.merge(planks), [0x8a6e4a, 0x6e5638], 0.05), 0.0)
	se.add("flat", SC.pa(Kit.cyl(0.06, 0.06, 0.015, 8, hx + hw * 0.3, F + 0.05, hz, PI / 2, 0, 0), [0x3a3633]), 0.0)
	var op := s.st("hatch", "OPEN")
	op.indoor = true
	# 걷어 낸 널(옆에 쌓음)
	for k in n: op.add("wood", SC.pa(Kit.box(hw / n - 0.02, 0.05, hd, hx + hw / 2 + 0.5, F + 0.05 + k * 0.05, hz + 0.1 * k), [0x8a6e4a, 0x6e5638], 0.05), 0.0)
	# 마루 밑 공간: 어두운 안벽 + 바닥 흙
	var pit := []
	pit.append(Kit.box(hw, F, 0.04, hx, F / 2, hz - hd / 2))
	pit.append(Kit.box(hw, F, 0.04, hx, F / 2, hz + hd / 2))
	pit.append(Kit.box(0.04, F, hd, hx - hw / 2, F / 2, hz))
	pit.append(Kit.box(0.04, F, hd, hx + hw / 2, F / 2, hz))
	op.add("flat", SC.pa(Kit.merge(pit), [0x2a2018, 0x140e0a]), 0.0)
	op.add("mud", SC.pa(Kit.box(hw, 0.04, hd, hx, 0.04, hz), [0x3a2e22, 0x2a2018]), 0.0)
	# 유해 일부(천에 싸인 뼈 몇 — 직접 그리지 않고 낡은 거적과 흰 조각으로) · 수량 기록 조각(작은 궤) · 박규상 표식(붉은 인 찍힌 나무패)
	op.add("thatch", SC.pa(Kit.xf(Kit.box(0.7, 0.1, 0.36), hx - 0.15, 0.1, hz - 0.1, 0, 0.3, 0), [0x6a5a40, 0x4a3e2c], 0.05), 0.006)
	for k in 4: op.add("organic", SC.pa(Kit.xf(Kit.cyl(0.025, 0.02, 0.22, 5), hx - 0.4 + k * 0.12, 0.12, hz + 0.15 + (k % 2) * 0.05, PI / 2, 0.4 * k, 0), [0xd8d0bc, 0xb8b09a]), 0.0)
	op.add("wood", SC.pa(Kit.box(0.34, 0.18, 0.26, hx + 0.35, 0.13, hz - 0.15), [0x5a4028, 0x3e2c1c]), 0.006)
	for k in 3: op.add("flat", SC.pa(Kit.xf(Kit.box(0.18, 0.004, 0.22), hx + 0.33 + k * 0.03, 0.23 + k * 0.004, hz - 0.15, 0, k * 0.4, 0), [0xc8b48a, 0x4a3a28], 0.05), 0.0)
	op.add("wood", SC.pa(Kit.box(0.08, 0.02, 0.2, hx + 0.1, 0.07, hz + 0.3), [0x9a7852]), 0.0)
	op.add("flat", SC.pa(Kit.box(0.05, 0.005, 0.05, hx + 0.1, 0.083, hz + 0.3), [0xa8282a]), 0.0)
	s.scol("hatch", "OPEN", { type = "box", minX = hx - hw / 2, maxX = hx + hw / 2, minZ = hz - hd / 2, maxZ = hz + hd / 2 })
	s.anchor("hatch", Vector3(hx, F, hz + hd / 2 + 0.6))
	s.anchor("pit", Vector3(hx, 0.05, hz))

# 불 연출: 불꽃(빛나는 혀) 모양은 상태 부분, 움직이는 불·연기·불티는 state_fx
static func _fire(s: SC.S, W: float, D: float, F: float, top: float, info: Dictionary, cold := false, inside := false) -> void:
	var R := s.rng
	var tongues := func(p, cx: float, cz: float, y0: float, n: int, h: float, spread: float) -> void:
		var gs := []
		for k in n:
			var g := Kit.cone(0.18 + R.next() * 0.15, h * (0.6 + R.next() * 0.6), 6)
			Kit.xf(g, cx + (R.next() - 0.5) * spread, y0 + h * 0.3, cz + (R.next() - 0.5) * 0.4, (R.next() - 0.5) * 0.3, 0, (R.next() - 0.5) * 0.3)
			gs.append(Kit.paint(g, Kit.hex(0xffd27a), Kit.hex(0xff6a20), 0.05, R))
		p.add("glow", Kit.merge(gs), 0.0)
	var zf: float = info.zf
	# FIRE_1: 오른쪽 아래 벽에 붙은 불 + 지붕에서 피어오르는 연기
	var f2 := s.st("main", "FIRE_2")
	if not inside:
		tongues.call(s.st("main", "FIRE_1"), W / 2 - 0.6, zf + 0.25, 0.0, 4, 1.4, 1.2)
		s.fx("main", "FIRE_1", { type = "fire", x = W / 2 - 0.6, y = 0.2, z = zf + 0.3, size = 0.6, k = 0.8 })
		s.fx("main", "FIRE_1", { type = "smoke", x = W / 4, y = top + 1.2, z = 0.0, size = 1.0, k = 0.8, dark = 0.4 })
		# FIRE_2: 지붕 앞면 따라 불 + 그을린 지붕 + 짙은 연기 둘 + 불티
		tongues.call(f2, W / 2 - 0.6, zf + 0.25, 0.0, 5, 2.2, 1.6)
		tongues.call(f2, 0.0, zf + 0.6, top + 0.4, 7, 2.0, W * 0.8)
		tongues.call(f2, -W * 0.3, -0.2, top + 1.6, 4, 1.6, W * 0.4)
		f2.add("organic", SC.pa(Kit.box(W * 0.5, 0.05, 1.6, W * 0.2, top + 0.95, D / 2 + 0.2), SC.CHAR, 0.08), 0.0)
		s.fx("main", "FIRE_2", { type = "fire", x = 0.0, y = top + 0.6, z = zf + 0.6, size = W * 0.3, k = 1.6 })
		s.fx("main", "FIRE_2", { type = "fire", x = W / 2 - 0.6, y = 0.3, z = zf + 0.3, size = 0.8, k = 1.0 })
		s.fx("main", "FIRE_2", { type = "smoke", x = -W / 4, y = top + 2.0, z = -0.3, size = 1.6, k = 1.3, dark = 0.85 })
		s.fx("main", "FIRE_2", { type = "smoke", x = W / 4, y = top + 2.0, z = 0.3, size = 1.6, k = 1.3, dark = 0.85 })
		s.fx("main", "FIRE_2", { type = "embers", x = 0.0, y = top + 1.5, z = 0.0, size = W * 0.3, k = 1.2 })
	# FIRE_3: 잔해 속 남은 불 + 연기
	var f3 := s.st("main", "FIRE_3")
	tongues.call(f3, -W * 0.25, 0.0, F, 5, 1.2, W * 0.35)
	tongues.call(f3, W * 0.38, -D * 0.3, F, 3, 0.9, 1.0)
	s.fx("main", "FIRE_3", { type = "fire", x = -W * 0.25, y = F + 0.3, z = 0.0, size = 1.2, k = 1.0 })
	s.fx("main", "FIRE_3", { type = "smoke", x = -W * 0.2, y = F + 1.5, z = 0.0, size = 1.4, k = 1.0, dark = 0.7 })
	s.fx("main", "FIRE_3", { type = "embers", x = -W * 0.2, y = F + 0.8, z = 0.0, size = 1.5, k = 0.6 })
	# BURNT: 식은 잔해 위 옅은 연기 한 줄기
	if not cold: s.fx("main", "BURNT", { type = "smoke", x = -W * 0.25, y = F + 0.6, z = 0.0, size = 0.5, k = 0.35, dark = 0.1 })
	if inside:
		# 실내에서 본 불: 지붕은 숨기므로 벽 윗머리·서까래를 타고 오르는 불, 방 안에 낮게 깔린 연기, 떨어지는 불티
		var zb: float = info.zb
		# FIRE_1: 오른쪽 벽 안쪽 아래에서 붙은 불(밖에서 보던 오른쪽 앞 불의 안쪽 면)
		var f1 := s.st("main", "FIRE_1")
		tongues.call(f1, W / 2 - 0.35, zf - 1.4, F, 4, 1.3, 0.3)
		s.fx("main", "FIRE_1", { type = "fire", x = W / 2 - 0.4, y = F + 0.2, z = zf - 1.4, size = 0.5, k = 0.8 })
		tongues.call(f2, W / 2 - 0.35, zf - 1.4, F, 5, 2.0, 0.4)
		s.fx("main", "FIRE_2", { type = "fire", x = W / 2 - 0.4, y = F + 0.3, z = zf - 1.4, size = 0.7, k = 1.0 })
		s.fx("main", "FIRE_1", { type = "smoke", x = 0.0, y = F + 2.3, z = -0.5, size = W * 0.3, k = 0.7, dark = 0.45 })
		tongues.call(f2, 0.0, zb + 0.3, top - 0.9, 8, 1.3, W * 0.8)
		tongues.call(f2, -W / 2 + 0.3, -D * 0.2, top - 0.9, 3, 1.1, 0.3)
		s.fx("main", "FIRE_2", { type = "fire", x = 0.0, y = top - 0.6, z = zb + 0.4, size = W * 0.3, k = 1.2 })
		s.fx("main", "FIRE_2", { type = "smoke", x = 0.0, y = F + 2.2, z = 0.0, size = W * 0.4, k = 1.2, dark = 0.8 })
		s.fx("main", "FIRE_2", { type = "embers", x = 0.0, y = top, z = 0.0, size = W * 0.35, k = 1.0 })
		s.fx("main", "FIRE_3", { type = "smoke", x = -W * 0.1, y = F + 2.0, z = -0.4, size = W * 0.25, k = 0.5, dark = 0.6 })

# 무너진 모습(FIRE_3·BURNT): 숯이 된 마루(구멍 자리 비움)·기둥 그루터기·낮게 남은 벽·내려앉은 지붕 더미(왼쪽 반)·흩어진 기와
static func _ruin(s: SC.S, W: float, D: float, F: float, H: float, old: bool, hole, style: String) -> void:
	var R := s.rng
	var p := s.st("main", RUIN)
	for rc in SC.floor_rects(W - 0.1, D - 0.1, hole):
		p.add("wood", SC.pa(Kit.box(rc[2], 0.06, rc[3], rc[0], F + 0.01, rc[1]), [0x3a2e24, 0x1e1812], 0.08, R), 0.0)
	# 기둥 그루터기
	var stubs := []
	for x in [-W / 2, -W / 6, W / 6, W / 2]:
		for z in [-D / 2, D / 2]:
			var h := R.between(0.4, 2.0)
			stubs.append(Kit.xf(Kit.box(0.2, h, 0.2), x, F + h / 2, z, R.between(-0.1, 0.1), 0, R.between(-0.15, 0.15)))
	p.add("wood", SC.pa(Kit.merge(stubs), SC.CHAR, 0.06), 0.015)
	# 낮게 남은 벽(그을린 흙)
	var wcol := [0x5a4a3a, 0x2a2018]
	p.add("mud", SC.pa(Kit.box(W, 0.9, 0.18, 0, F + 0.45, -D / 2), wcol, 0.08, R), 0.015)
	for sx in [-1, 1]: p.add("mud", SC.pa(Kit.box(0.18, 0.7, D, sx * W / 2, F + 0.35, 0), wcol, 0.08, R), 0.015)
	p.add("mud", SC.pa(Kit.box(W * 0.32, 0.5, 0.18, -W * 0.34, F + 0.25, D / 2), wcol, 0.08, R), 0.015)
	p.add("mud", SC.pa(Kit.box(W * 0.32, 0.6, 0.18, W * 0.34, F + 0.3, D / 2), wcol, 0.08, R), 0.015)
	# 내려앉은 지붕 더미(왼쪽 반): 기와·흙 더미 + 걸친 대들보
	var heap := Kit.lump(1.0, 1, R, 0.3, 0.45)
	Kit.xf(heap, -W * 0.25, F, 0.0, 0, 0, 0, W * 0.22, 1.4, D * 0.35)
	p.add("organic", SC.pa(heap, [0x4a4440, 0x2a2624], 0.08, R), 0.02)
	var tiles := []
	for k in 26:
		var a := R.next() * TAU; var rr := R.next()
		tiles.append(Kit.xf(Kit.box(0.32, 0.04, 0.26), -W * 0.25 + cos(a) * rr * W * 0.3, F + 0.05 + R.next() * 0.5, sin(a) * rr * D * 0.4, R.between(-0.5, 0.5), R.next() * 3.0, R.between(-0.4, 0.4)))
	p.add("tile", SC.pa(Kit.merge(tiles), [0x6a6a6e, 0x3e3e42], 0.06), 0.0)
	for k in 3:
		var a := Vector3(-W * 0.45 + k * 0.6, F + 1.4 - k * 0.3, -D * 0.4 + k * 0.5); var b := Vector3(W * 0.05 - k * 0.4, F + 0.1, D * 0.35 - k * 0.3)
		p.add("wood", SC.pa(Kit.limb(a, b, 0.13, 0.12, 6), SC.CHAR, 0.05), 0.015)
	# 재·탄 가마니
	if style != "empty":
		var burnt := []
		for k in 8:
			var g := Kit.lump(0.3, 0, R, 0.2, 0.35)
			Kit.xf(g, W * 0.1 + R.between(-1.0, W * 0.3), F + 0.08, -D / 2 + 0.8 + R.next() * 0.8, 0, R.next(), 0, 1.3, 1, 0.9)
			burnt.append(Kit.paint(g, Kit.hex(0x3a3028), Kit.hex(0x1a1612), 0.06, R))
		p.add("organic", Kit.merge(burnt), 0.0)
	# 무너진 더미는 지나갈 수 없다
	s.scol("main", "FIRE_3", { type = "box", minX = -W * 0.48, maxX = -W * 0.02, minZ = -D * 0.38, maxZ = D * 0.38 })
	s.scol("main", "BURNT", { type = "box", minX = -W * 0.48, maxX = -W * 0.02, minZ = -D * 0.38, maxZ = D * 0.38 })
