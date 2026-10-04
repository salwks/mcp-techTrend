# 제의·경계 단서 소품(강릉 「고개에 남은 종소리」 등) — 이야기 총괄(story_director)이 조건이 맞을 때만 세운다.
# 원점 = 바닥 중심, 앞 = +z. PROP_MASTER: PRP_RIT_001(제물상) PRP_RIT_002(금줄) PRP_RIT_003(방울) + 경계석·도둑의 숨긴 꾸러미.
# params.kind:
#   stone       옛 경계석(사람 무릎~허리 높이 막돌 선돌, 이끼·옛 새김). tilt(기울기 rad), lying(true면 뉘어 끌려 나간 모양)
#   socket      경계석이 뽑혀 나간 빈 자리(흙 구덩이 + 이끼 테두리 — 오래 박혀 있던 자국)
#   restored    제자리에 다시 세운 경계석 + 새 금줄 + 방울(결말 A)
#   bell        제의용 방울(놋쇠 방울 묶음 + 오색 천) — 말뚝에 걸림(hung) 또는 바닥에 놓임
#   stash       도둑이 숨긴 꾸러미(보자기·북어·초·쌀 자루) — 바위 밑
#   scratch     바위에 난 가는 긁힘(세 줄 — 짐승 발톱도 사람 연장도 아닌)
#   streamers   단오 준비 오색 천 줄(두 장대 사이) — w
#   geumjul / jemul   scenario/props의 금줄·제물상을 state(NORMAL·BROKEN / NORMAL·EMPTY)로 굳혀 세운다
#   sandals     주막 일꾼의 짚신(뒤축을 새끼로 감은) 한 켤레
extends RefCounted
const C := preload("res://kit/village/_common.gd")
const Props := preload("res://kit/scenario/props.gd")

const MOSS := [0x5e6a3e, 0x3e4a2a]
const ROCK := [0x9a958a, 0x6a665e]
const DIRT := [0x6b5640, 0x4a3a2a]
const BRASS := [0xd0aa50, 0x8a6a2a]
const ROPE := [0xc8b07a, 0x9d8656]
const PAPER := [0xf2ede0, 0xd8d0bc]
const OBANG := [0x3d5a8a, 0xa8443c, 0xe8d24a, 0xf2ede0, 0x2b2622]   # 청·적·황·백·흑

static func build(params: Dictionary) -> Dictionary:
	var kind := String(params.get("kind", "stone"))
	if kind in ["geumjul", "jemul"]: return _state_prop(kind, params)
	var m := C.M.new(int(params.get("seed", 11)))
	var fp := Vector2(1.2, 1.2)
	match kind:
		"stone": _stone(m, float(params.get("tilt", 0.0)), bool(params.get("lying", false)))
		"socket": _socket(m)
		"restored":
			_stone(m, 0.0, false)
			_rope_stakes(m, 2.6, true)
			_bell(m, Vector3(1.3, 1.0, 0.0), true)
			fp = Vector2(3.0, 1.2)
		"bell": _bell(m, Vector3(0, 0, 0), bool(params.get("hung", true)))
		"stash": _stash(m)
		"scratch": _scratch(m)
		"streamers": fp = _streamers(m, float(params.get("w", 6.0)))
		"sandals": _sandals(m)
		_: push_warning("story/ritual: 모르는 kind " + kind)
	return m.result("제의_" + kind, fp, false)

# scenario/props(상태 소품)를 한 상태로 굳혀서
static func _state_prop(kind: String, params: Dictionary) -> Dictionary:
	var p := params.duplicate(); p.kind = kind
	var info: Dictionary = Props.build(p)
	var want := String(params.get("state", "NORMAL"))
	var n: Node3D = info.node
	for c in n.get_children():
		var nm := String(c.name)
		if not nm.begins_with("S_"): continue
		var sts := nm.substr(nm.find("_", 2) + 1).split("-")
		c.visible = sts.has(want)
	return info

static func _stone(m: C.M, tilt: float, lying: bool) -> void:
	var R := m.rng
	var g := Kit.lump(0.32, 1, R, 0.22, 2.3)
	if lying: Kit.xf(g, 0, 0.3, 0, PI / 2 - 0.15, 0.3, 0.1)
	else: Kit.xf(g, 0, 0.62, 0, tilt, 0, tilt * 0.4)
	m.add("p", "stone", C.PA(g, ROCK, 0.06, R), 0.02)
	# 이끼(아래쪽) — 뉘인 돌은 이끼 낀 면이 옆을 본다
	var mg := Kit.lump(0.3, 0, R, 0.3, 0.6)
	if lying: Kit.xf(mg, -0.5, 0.25, 0.05, 0, 0, 1.4)
	else: Kit.xf(mg, 0, 0.2, 0.02)
	m.add("p", "organic", C.PA(mg, MOSS, 0.08, R), 0.0)
	# 옛 새김(희미한 먹빛 획 셋)
	for i in 3:
		var s := Kit.box(0.025, 0.22 - i * 0.04, 0.01)
		if lying: Kit.xf(s, -0.1 + i * 0.09, 0.62, 0.15, PI / 2 - 0.15, 0.3, 0.1)
		else: Kit.xf(s, -0.08 + i * 0.08, 0.8, 0.29, tilt, 0, 0)
		m.add("p", "flat", C.P(s, 0x3a3630, 0x2a2622), 0.0)
	m.circle(0, 0, 0.32)

static func _socket(m: C.M) -> void:
	var R := m.rng
	m.add("p", "flat", C.PA(Kit.xf(Kit.cyl(1.0, 1.0, 0.02, 12), 0, 0.01, 0, 0, 0.3, 0, 0.42, 1, 0.34), [0x2e241a, 0x1e1812]), 0.0)
	# 둘레: 오래 눌려 있던 이끼 테두리 + 파헤쳐진 흙덩이
	var ring := C.torus(0.42, 0.06, 4, 14)
	Kit.xf(ring, 0, 0.02, 0, 0, 0, 0, 1, 0.5, 0.82)
	m.add("p", "organic", C.PA(ring, MOSS, 0.1, R), 0.0)
	for i in 5:
		var a := i * 1.3 + R.next()
		m.add("p", "organic", C.PA(Kit.xf(Kit.lump(0.08, 0, R, 0.4, 0.5), cos(a) * 0.62, 0.03, sin(a) * 0.5), DIRT), 0.0)

static func _rope_stakes(m: C.M, w: float, with_paper: bool) -> void:
	for sx in [-1, 1]: m.add("p", "wood", C.PA(Kit.cyl(0.045, 0.055, 1.25, 6, sx * w / 2, 0.62, 0), C.WOOD), 0.012)
	var seg := 8
	for i in seg:
		var x0 := -w / 2 + w * i / seg; var x1 := -w / 2 + w * (i + 1) / seg
		var y0 := 1.12 - 0.16 * sin(PI * i / seg); var y1 := 1.12 - 0.16 * sin(PI * (i + 1) / seg)
		m.add("p", "thatch", C.PA(Kit.limb(Vector3(x0, y0, 0), Vector3(x1, y1, 0), 0.02, 0.02, 4), ROPE), 0.0)
		if with_paper and i % 2 == 1:
			m.add("p", "flat", C.PA(Kit.box(0.08, 0.2, 0.01, (x0 + x1) / 2, (y0 + y1) / 2 - 0.12, 0), PAPER), 0.0)

static func _bell(m: C.M, at: Vector3, hung: bool) -> void:
	var base := at
	if hung:
		m.add("p", "wood", C.PA(Kit.cyl(0.035, 0.045, 1.15, 6, at.x, 0.57, at.z), C.WOOD), 0.01)
		base = Vector3(at.x, 1.05, at.z + 0.05)
	# 손잡이 + 방울 일곱(놋쇠) + 오색 천
	var hy := base.y + (0.0 if hung else 0.05)
	m.add("p", "wood", C.PA(Kit.xf(Kit.cyl(0.018, 0.02, 0.22, 6), base.x, hy - 0.11, base.z + 0.02, 0 if hung else PI / 2, 0, 0), C.WOOD_L), 0.006)
	for i in 7:
		var a := i * TAU / 7.0
		var x := base.x + cos(a) * 0.055; var z := base.z + 0.02 + sin(a) * 0.055
		var y := (hy - 0.25 - (0.03 if i % 2 == 0 else 0.0)) if hung else (base.y + 0.04)
		if not hung: x = base.x + 0.12 + cos(a) * 0.06
		m.add("p", "smooth", C.PA(Kit.xf(C.sphere(0.032, 7, 5), x, y, z), BRASS), 0.004)
	for i in 5:
		var g := Kit.box(0.035, 0.42, 0.006)
		if hung: Kit.xf(g, base.x - 0.08 + i * 0.04, hy - 0.42, base.z + 0.05, 0.05 * i, 0, 0.08 * (i - 2))
		else: Kit.xf(g, base.x - 0.25 - i * 0.03, base.y + 0.01, base.z + 0.05 + i * 0.04, PI / 2, 0.3 * (i - 2), 0)
		m.add("p", "cloth", C.P(g, OBANG[i], OBANG[i]), 0.0)
	if hung: m.circle(at.x, at.z, 0.08)

static func _stash(m: C.M) -> void:
	var R := m.rng
	m.add("p", "stone", C.PA(Kit.xf(Kit.lump(0.7, 1, R, 0.25, 0.55), 0, 0.3, -0.35), ROCK, 0.06, R), 0.02)
	m.add("p", "cloth", C.P(Kit.xf(Kit.lump(0.26, 1, R, 0.2, 0.6), 0.1, 0.13, 0.35), 0x5a6a7e, 0x3a4658, 0.05, R), 0.01)   # 보자기
	for i in 3:   # 북어
		m.add("p", "smooth", C.PA(Kit.xf(Kit.box(0.42, 0.05, 0.07), -0.35, 0.04 + i * 0.05, 0.42 + i * 0.03, 0, 0.3 + i * 0.2, 0), [0xc8a878, 0x9a7a4a]), 0.004)
	for i in 2:   # 초
		m.add("p", "smooth", C.PA(Kit.xf(Kit.cyl(0.025, 0.025, 0.24, 6), 0.42, 0.03, 0.5 + i * 0.08, PI / 2, 0.9, 0), PAPER), 0.004)
	m.add("p", "cloth", C.P(Kit.xf(Kit.lump(0.18, 0, R, 0.2, 0.9), 0.5, 0.12, 0.2), 0xd8ccb0, 0xb6a888), 0.008)   # 쌀 자루
	# 끊어 온 금줄 토막
	m.add("p", "thatch", C.PA(Kit.limb(Vector3(-0.2, 0.03, 0.62), Vector3(0.35, 0.03, 0.75), 0.018, 0.018, 4), ROPE), 0.0)
	m.circle(0, -0.35, 0.6)

static func _scratch(m: C.M) -> void:
	var R := m.rng
	m.add("p", "stone", C.PA(Kit.xf(Kit.lump(0.55, 1, R, 0.2, 0.75), 0, 0.38, 0), ROCK, 0.06, R), 0.02)
	for i in 3:
		var g := Kit.box(0.018, 0.5, 0.01)
		Kit.xf(g, -0.1 + i * 0.07, 0.5, 0.5, -0.35, 0, 0.05 * (i - 1))
		m.add("p", "flat", C.P(g, 0xe2ddd0, 0xc6c0b0), 0.0)
	m.circle(0, 0, 0.5)

static func _streamers(m: C.M, w: float) -> Vector2:
	for sx in [-1, 1]: m.add("p", "wood", C.PA(Kit.cyl(0.05, 0.06, 3.2, 6, sx * w / 2, 1.6, 0), C.WOOD_L), 0.012)
	var seg := 10
	for i in seg:
		var x0 := -w / 2 + w * i / seg; var x1 := -w / 2 + w * (i + 1) / seg
		var y0 := 3.0 - 0.45 * sin(PI * i / seg); var y1 := 3.0 - 0.45 * sin(PI * (i + 1) / seg)
		m.add("p", "thatch", C.PA(Kit.limb(Vector3(x0, y0, 0), Vector3(x1, y1, 0), 0.018, 0.018, 4), ROPE), 0.0)
		var col: int = OBANG[i % 5]
		m.add("p", "cloth", C.P(Kit.box(0.14, 0.55, 0.008, (x0 + x1) / 2, (y0 + y1) / 2 - 0.3, 0), col, col), 0.0)
	for sx in [-1, 1]: m.circle(sx * w / 2, 0, 0.1)
	return Vector2(w + 0.4, 0.4)

static func _sandals(m: C.M) -> void:
	for k in 2:
		var x := -0.09 + k * 0.18
		m.add("p", "thatch", C.PA(Kit.xf(Kit.box(0.11, 0.035, 0.27), x, 0.02, 0.0, 0, 0.1 * k, 0), [0xc8a868, 0x9a7e4e]), 0.006)
		# 뒤축을 새끼로 감은 자국(짙은 띠)
		m.add("p", "thatch", C.PA(Kit.xf(Kit.box(0.12, 0.045, 0.05), x, 0.025, -0.1, 0, 0.1 * k, 0), [0x6a5434, 0x4a3a24]), 0.0)
