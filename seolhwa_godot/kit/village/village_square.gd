# 마을 공동 마당(어귀 정자나무 그늘) — 정자나무(느티) + 둥근 돌 축대 + 평상 둘 + 넓적 돌 의자 + 짚신·멍석.
# 고증: 마을 어귀 정자나무(당산나무) 밑은 둥근 돌단을 쌓고 평상을 놓아 쉼터·마을 회의·농사 품앗이 의논 자리로 썼다.
# params: seed, tree("nature": kit/nature/big_tree 느티(있으면) | "own": 키트 안 단순 신목 | "none": 자리만),
#         pyeongsang(2), seats(4)
extends RefCounted
const C := preload("res://kit/village/_common.gd")
const PR := preload("res://kit/village/props.gd")
const SH := preload("res://kit/village/seonghwangdang.gd")
const NATURE_TREE := "res://kit/nature/big_tree.gd"

static func build(params: Dictionary) -> Dictionary:
	var m := C.M.new(int(params.get("seed", 1)))
	var R := m.rng
	var tx := 0.0; var tz := -1.2
	var mode: String = params.get("tree", "nature")
	if mode == "nature" and not ResourceLoader.exists(NATURE_TREE): mode = "own"
	# 둥근 돌 축대(나무 둘레)
	m.add("p", "stone", C.P(Kit.cyl(1.7, 1.8, 0.45, 12, tx, 0.22, tz), 0xa8a294, 0x7e796e, 0.06, R), 0.025)
	m.add("p", "mud", C.P(Kit.cyl(1.55, 1.55, 0.02, 12, tx, 0.46, tz), 0x9a8a62), 0)
	for i in 12:
		var a := i * TAU / 12 + 0.13
		m.add("p", "stone", C.P(Kit.xf(Kit.lump(0.2, 0, R, 0.3, 0.6), tx + cos(a) * 1.8, 0.2, tz + sin(a) * 1.8, 0, 0, 0, 1.2, 1, 0.6), 0xbdb7aa, 0x8e897f), 0)
	if mode == "own":
		SH.sacred_tree(m, tx, tz)
	m.circle(tx, tz, 1.8)
	m.anchor("tree", Vector3(tx, 0.45, tz))
	# 평상(나무 앞 그늘)
	var np: int = params.get("pyeongsang", 2)
	var spots := [[-1.6, 1.4, 0.15], [1.9, 1.1, -0.3]]
	for i in mini(np, 2):
		var old := m.push(spots[i][0], 0, spots[i][1], spots[i][2])
		PR.pyeongsang(m, 2.0, 1.3)
		m.pop(old)
		m.anchor("pyeongsang%d" % i, Vector3(spots[i][0], 0.5, spots[i][1]))
	# 돌 의자
	var ns: int = params.get("seats", 4)
	for i in ns:
		var x := -3.0 + i * 6.0 / maxf(ns - 1, 1) + (m.r() - 0.5) * 0.4
		var z := 2.4 + (m.r() - 0.5) * 0.6
		if absf(x) < 0.6: z += 0.6
		var g := Kit.lump(0.32, 0, R, 0.15, 0.45)
		Kit.xf(g, x, 0.12, z + 0.4, 0, m.r() * 3, 0, 1.3, 1, 1)
		m.add("p", "stone", C.P(g, 0xbdb7aa, 0x8a857b, 0.06, R), 0.015)
		m.anchor("seat%d" % i, Vector3(x, 0.3, z + 0.4))
	# 짚신 한 켤레, 담뱃대 놓인 자리(작은 소품)
	for s in [-1, 1]: m.add("p", "thatch", C.PA(Kit.xf(Kit.box(0.11, 0.05, 0.27), -1.0 + s * 0.08, 0.03, 2.25, 0, 0.2, 0), C.STRAW), 0)
	var res := m.result("마을마당", Vector2(8.0, 7.6))
	if mode == "nature":
		var tinfo: Dictionary = load(NATURE_TREE).build({ seed = int(params.get("seed", 1)) * 7 + 3, variant = "zelkova" })
		var tn: Node3D = tinfo.node
		tn.position = Vector3(tx, 0.45, tz)
		res.node.add_child(tn)
		for c in tinfo.get("colliders", []):
			if c.type == "circle": res.colliders.append({ type = "circle", x = c.x + tx, z = c.z + tz, r = c.r })
		res.tree_kit = { kit = "nature/big_tree", params = { seed = int(params.get("seed", 1)) * 7 + 3, variant = "zelkova" }, x = tx, z = tz, y = 0.45 }
	return res
