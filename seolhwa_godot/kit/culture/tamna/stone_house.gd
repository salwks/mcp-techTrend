# 탐라 돌집 — 현무암 돌벽(두껍게, 구멍 숭숭한 검은 돌) + 낮고 둥근 띠(새) 지붕을 새끼줄 바둑판(집줄)으로 얽음 + 상방 앞 풍채.
#   kind "an"(안거리: 정지·구들·상방·구들·고팡 5칸) / "bak"(밖거리: 구들·상방·구들 3칸, 작게)
# 고증: 제주 초가는 띠로 이은 지붕을 굵은 새끼(집줄)로 가로세로 얽어 바람을 견딘다. 벽은 현무암 막돌에 흙을 메움, 처마 낮음.
#   상방 앞 '풍채'(띠로 엮은 차양)를 막대로 받침. 정지가 따로 떨어지기도 한다(여기선 한 채).
# 위에서: 검은 돌벽 + 잿빛 갈색의 낮은 둥근 지붕 + 촘촘한 줄 격자 — 육지의 흙벽·노란 초가와 완전히 다름.
# params: seed, kind("an"|"bak"), pungchae(true)
extends RefCounted
const C := preload("res://kit/village/_common.gd")
const CC := preload("res://kit/culture/_cc.gd")

static func build(params: Dictionary) -> Dictionary:
	var m := C.M.new(int(params.get("seed", 1)))
	var an: bool = params.get("kind", "an") == "an"
	var L := 10.5 if an else 7.5
	var D := 5.0 if an else 4.4
	var bays := "kdjdb" if an else "djd"
	CC.house(m, [{ name = "house", x0 = -L / 2, x1 = L / 2, z0 = -D / 2, z1 = D / 2, face = "s", bays = bays, F = 0.25, wall_h = 1.65, wall = "basalt" }],
		"tti", { ov = 0.55, k = 1.0, rise_k = 0.42, rope = 0.55, ridge = false })
	if params.get("pungchae", true):
		# 풍채: 상방 칸 앞의 띠 차양 + 받침 막대 두 개
		var bw := L / bays.length()
		var x := -L / 2 + (bays.find("j") + 0.5) * bw
		var R := m.rng
		var g := Kit.box(bw + 0.5, 0.12, 1.3)
		Kit.xf(g, x, 1.72, D / 2 + 0.95, -0.32, 0, 0)
		m.add("p", "thatch", C.PA(g, CC.ROOF.tti.ecol if false else [0xa89d7e, 0x7a7058], 0.04, R), 0.02)
		for s in [-1, 1]:
			m.add("p", "wood", C.PA(Kit.cyl(0.04, 0.045, 1.55, 5, x + s * (bw / 2 + 0.1), 0.78, D / 2 + 1.5), C.WOOD), 0.01)
		m.circle(x - bw / 2 - 0.1, D / 2 + 1.5, 0.1); m.circle(x + bw / 2 + 0.1, D / 2 + 1.5, 0.1)
	return m.result("제주돌집", Vector2(L + 1.3, D + 2.2))
