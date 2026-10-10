# 길목 깃발(waymark) — 마을 어귀·노정 중간·쉼터(주막·고개)에 서는 작은 깃대: 돌 받침 + 나무 장대 + 가로대에 매단 쪽빛 깃발(붉은 테·꼬리).
#   역참 깃발(kit/station/hitch.gd — 노란 바탕 붉은 테)과 같은 짜임을 작게 줄이고 색으로 가른다(쪽빛 = 길목, 노랑 = 역참).
#   아직 모르는 깃발은 바랜 무명빛(known=false) — 가 보면(scripts/region/waymarks.gd) 쪽빛으로 바꿔 단다.
# params: seed, known(bool)
# 앵커: cloth(깃발 가운데)
extends RefCounted
const C := preload("res://kit/village/_common.gd")

const H := 4.2           # 장대 높이(m) — 게임 카메라(약 30~40m 위)에서 사람 키의 두 배 남짓으로 보이게

static func plan(_params: Dictionary) -> Dictionary:
	return { cloth = Vector3(0.62, H - 1.0, 0.0) }

static func build(params: Dictionary) -> Dictionary:
	var m := C.M.new(int(params.get("seed", 1)))
	var known := bool(params.get("known", true))
	var face: Array = [0x34476e, 0x26355a] if known else [0xd9d0bb, 0xbfb49a]
	var trim: Array = [0xa8443c, 0x8a3530] if known else [0xa89c86, 0x8f846f]
	# 돌 받침(두 단) + 장대
	m.add("p", "stone", C.P(Kit.box(0.62, 0.22, 0.62, 0, 0.11, 0), 0x9d978b, 0x77726a, 0.05), 0.015)
	m.add("p", "stone", C.P(Kit.box(0.4, 0.2, 0.4, 0, 0.32, 0), 0xa19b8f, 0x85806f, 0.05), 0.012)
	m.circle(0, 0, 0.35)
	m.add("p", "wood", C.P(Kit.cyl(0.05, 0.075, H, 6, 0, H / 2, 0), 0x7a5c3e, 0x5a4430, 0.03), 0.012)
	m.add("p", "wood", C.P(Kit.cyl(0.07, 0.04, 0.22, 6, 0, H + 0.1, 0), 0x3e2e22, 0x2e2219), 0.008)   # 꼭지
	# 가로대 + 깃발(두 조각으로 살짝 굽음) + 붉은 테 + 꼬리 둘
	m.add("p", "wood", C.P(Kit.box(1.25, 0.05, 0.05, 0.6, H - 0.18, 0), 0x6a5038), 0.008)
	var top := H - 0.22
	var hh := 1.5
	for k in 2:
		var y0 := top - k * hh * 0.5; var y1 := y0 - hh * 0.5
		m.add("p", "cloth", C.P(Kit.box(1.05, y0 - y1, 0.03, 0.64, (y0 + y1) / 2, 0.06 * sin(float(k) * 1.6)), face[0], face[1], 0.03), 0.012)
	m.add("p", "cloth", C.P(Kit.box(0.08, hh, 0.04, 0.1, top - hh / 2, 0), trim[0], trim[1]), 0)
	m.add("p", "cloth", C.P(Kit.box(0.08, hh, 0.04, 1.18, top - hh / 2, 0), trim[0], trim[1]), 0)
	for s in [0.36, 0.92]:
		m.add("p", "cloth", C.P(Kit.box(0.14, 0.5, 0.03, s, top - hh - 0.25, 0.02), trim[0], trim[1]), 0.006)
	for k in plan(params): m.anchor(k, plan(params)[k])
	return m.result("길목 깃발", Vector2(1.4, 0.7), false)

# 바로 장면 노드로(waymarks.gd가 가까이 온 깃발만 만든다)
static func node(params: Dictionary) -> Node3D:
	return build(params).node
