# 제주 사건 소품(「굴에 남은 숨」 S7001~S7008 + 화북포 생활 장면) — 이야기 총괄(story_director)이 조건이 맞을 때만 세운다. 원점 = 바닥 중심, 앞 = +z.
# PROP_MASTER: PRP_SPEC_038(김녕굴 제의·구렁이 흔적) 곁의 작은 것들 — 새 대형 모델 없이 기본 도형을 짜 맞춘다.
# params.kind:
#   stones    굴 입구를 막은 현무암 돌무더기(B — 굴 봉쇄)
#   bowl      놋 제물 그릇(도굴꾼이 흙을 퍼 담던 — 제단에서 사라진 것)
#   sack      찢어진 짚 섬 + 새끼줄(넓은 '뱀 자국'을 끈 것)
#   pit       도굴 구덩이를 메운 자리(흙 둔덕) — filled
#   tewak     해녀 테왁(박 부표) + 망사리(그물 자루) — 화북포 물가
#   bulteok   불턱(해녀가 물질 뒤 불 쬐는 돌담 둥지) + 모닥불
#   heobeok   물허벅(물 긷는 항아리) — 용천수 곁
#   lamp      초롱(굴 앞 바위 위에 둔 등불, 불빛)
extends RefCounted
const C := preload("res://kit/village/_common.gd")

const BASALT := [0x4a4642, 0x2a2826]
const BASALT_L := [0x5e5a54, 0x3a3733]
const BRASS := [0xc9a14a, 0x8a6a2a]
const STRAW := [0xc2a868, 0x8e7442]
const ROPE := [0xb39a62, 0x7e6a3e]
const DIRT := [0x5a4a3a, 0x3a3026]
const GOURD := [0xd88a3a, 0xa45a22]
const NET := [0x5a5a48, 0x3a3a2c]
const FIRE := [0xffb050, 0xe06a28]
const ONGGI := [0x8a5a3a, 0x5a3a26]
const PAPER := [0xefe6d0, 0xc8bea4]

static func build(params: Dictionary) -> Dictionary:
	var m := C.M.new(int(params.get("seed", 7001)))
	var kind := String(params.get("kind", "stones"))
	var fp := Vector2(1.2, 1.2)
	match kind:
		"stones": fp = _stones(m, float(params.get("w", 5.0)))
		"bowl": _bowl(m)
		"sack": _sack(m)
		"pit": _pit(m)
		"tewak": _tewak(m, int(params.get("n", 3)))
		"bulteok": fp = _bulteok(m)
		"heobeok": _heobeok(m)
		"lamp": _lamp(m)
	return m.result("제주_" + kind, fp, false)

static func _stones(m: C.M, w: float) -> Vector2:
	var R := m.rng
	var n := int(w * 3.2)
	for i in n:
		var x := R.between(-w * 0.5, w * 0.5)
		var row := i % 3
		var r := R.between(0.35, 0.65) * (1.0 - row * 0.18)
		var g := Kit.lump(r, 1, R, 0.25, 0.8)
		Kit.xf(g, x, r * 0.6 + row * 0.55, R.between(-0.5, 0.5) - row * 0.15, R.next(), R.next() * 3.0, 0.0)
		m.add("p", "rock", C.PA(g, BASALT if i % 2 == 0 else BASALT_L, 0.07, R), 0.03)
	for k in 5: m.circle(-w * 0.5 + w * (k + 0.5) / 5.0, 0.0, w / 9.0 + 0.15)
	return Vector2(w + 1.0, 2.0)

static func _bowl(m: C.M) -> void:
	m.add("p", "smooth", C.PA(Kit.xf(Kit.cyl(0.16, 0.09, 0.09, 12), 0.0, 0.05, 0.0), BRASS), 0.006)
	m.add("p", "flat", C.PA(Kit.xf(Kit.cyl(0.14, 0.14, 0.01, 12), 0.0, 0.095, 0.0), DIRT), 0.0)

static func _sack(m: C.M) -> void:
	var R := m.rng
	var g := Kit.lump(0.4, 1, R, 0.2, 0.35)
	Kit.xf(g, 0.0, 0.08, 0.0, 0.0, 0.4, 0.0, 1.0, 1.0, 1.6)
	m.add("p", "cloth", C.PA(g, STRAW, 0.06, R), 0.012)
	m.add("p", "cloth", C.PA(Kit.limb(Vector3(0.1, 0.12, 0.6), Vector3(-0.3, 0.03, 1.8), 0.03, 0.025, 5), ROPE), 0.003)
	m.add("p", "cloth", C.PA(Kit.limb(Vector3(-0.3, 0.03, 1.8), Vector3(0.2, 0.03, 2.6), 0.03, 0.025, 5), ROPE), 0.003)

static func _pit(m: C.M) -> void:
	var R := m.rng
	var g := Kit.lump(0.7, 1, R, 0.25, 0.25)
	Kit.xf(g, 0.0, 0.02, 0.0)
	m.add("p", "organic", C.PA(g, DIRT, 0.06, R), 0.01)

static func _tewak(m: C.M, n: int) -> void:
	var R := m.rng
	for i in n:
		var x := (i - (n - 1) * 0.5) * 0.75
		var gb := Kit.lump(0.22, 1, R, 0.05, 0.85)
		Kit.xf(gb, x, 0.2, R.between(-0.2, 0.2))
		m.add("p", "smooth", C.PA(gb, GOURD, 0.04, R), 0.006)
		var net := Kit.lump(0.2, 0, R, 0.25, 0.5)
		Kit.xf(net, x + 0.1, 0.06, 0.35)
		m.add("p", "cloth", C.PA(net, NET, 0.06, R), 0.004)

static func _bulteok(m: C.M) -> Vector2:
	var R := m.rng
	for i in 18:
		var a := -2.4 + i * (4.8 / 17.0)
		var g := Kit.lump(R.between(0.3, 0.42), 1, R, 0.25, 0.75)
		Kit.xf(g, sin(a) * 2.1, 0.32, cos(a) * 2.1, R.next(), R.next() * 3.0, 0.0)
		m.add("p", "rock", C.PA(g, BASALT, 0.07, R), 0.03)
		var g2 := Kit.lump(R.between(0.25, 0.34), 1, R, 0.25, 0.75)
		Kit.xf(g2, sin(a) * 2.1, 0.85, cos(a) * 2.1)
		m.add("p", "rock", C.PA(g2, BASALT_L, 0.07, R), 0.02)
		if i % 3 == 0: m.circle(sin(a) * 2.1, cos(a) * 2.1, 0.45)
	for i in 4:
		var a := i * TAU / 4 + 0.3
		m.add("p", "wood", C.PA(Kit.limb(Vector3(cos(a) * 0.32, 0.03, sin(a) * 0.32), Vector3(0, 0.22, 0), 0.04, 0.03, 5), C.WOOD), 0.004)
	m.add("p", "smooth", C.PA(Kit.xf(Kit.cone(0.16, 0.38, 7), 0, 0.12, 0), FIRE), 0.0)
	m.light(0, 0.5, 0, "torch")
	return Vector2(5.0, 5.0)

static func _heobeok(m: C.M) -> void:
	var R := m.rng
	var g := Kit.lump(0.26, 1, R, 0.04, 0.9)
	Kit.xf(g, 0.0, 0.3, 0.0, 0.0, 0.0, 0.0, 1.0, 1.15, 1.0)
	m.add("p", "smooth", C.PA(g, ONGGI, 0.04, R), 0.008)
	m.add("p", "smooth", C.PA(Kit.xf(Kit.cyl(0.06, 0.08, 0.14, 8), 0.0, 0.62, 0.0), ONGGI), 0.004)

static func _lamp(m: C.M) -> void:
	m.add("p", "wood", C.PA(Kit.xf(Kit.box(0.24, 0.03, 0.24), 0.0, 0.02, 0.0), C.WOOD), 0.004)
	m.add("p", "smooth", C.PA(Kit.xf(Kit.cyl(0.11, 0.11, 0.3, 8), 0.0, 0.19, 0.0), PAPER), 0.006)
	m.add("p", "smooth", C.PA(Kit.xf(Kit.cone(0.13, 0.08, 8), 0.0, 0.38, 0.0), C.WOOD), 0.004)
	m.light(0, 0.3, 0, "lantern")
