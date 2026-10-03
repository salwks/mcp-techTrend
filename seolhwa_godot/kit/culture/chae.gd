# 채 하나(一자) — 문화권 묶음에서 사랑채·행랑채·밖거리·곳간채 등으로 쓰는 범용 키트. 정면 +z.
# params: seed, l(길이 9), d(깊이 4.2), bays("dmd" — _cc.gd 글자), roof("giwa"|"giwa_dark"|"thatch"|"thatch_old"|"thatch_sea"|"tti"),
#         F, wall_h, wall("mud"|"plaster"|"red"|"basalt"|"urban"), maru(0), chimney(""|"low"|"log"|"tall"), gable(false: 맞배), ov(지붕 내밈),
#         rope(0: 새끼 그물 간격 m), rope_dir("both"|"x"|"z"), rope_stones(false), rise_k
extends RefCounted
const C := preload("res://kit/village/_common.gd")
const CC := preload("res://kit/culture/_cc.gd")

static func build(params: Dictionary) -> Dictionary:
	var m := C.M.new(int(params.get("seed", 1)))
	var L: float = params.get("l", 9.0); var D: float = params.get("d", 4.2)
	var roof: String = params.get("roof", "giwa")
	var w := { x0 = -L / 2, x1 = L / 2, z0 = -D / 2, z1 = D / 2, face = "s", bays = params.get("bays", "dmd") }
	for k in ["F", "wall_h", "wall", "maru", "chimney", "gable", "steps"]:
		if params.has(k): w[k] = params[k]
	var ro := {}
	for k in ["ov", "rope", "rope_dir", "rope_stones", "rise_k", "k", "thick"]:
		if params.has(k): ro[k] = params[k]
	CC.house(m, [w], roof, ro)
	var ov: float = ro.get("ov", CC.ROOF[roof].ov)
	return m.result("채", Vector2(L + ov * 2, D + ov * 2 + float(params.get("maru", 0.0))))
