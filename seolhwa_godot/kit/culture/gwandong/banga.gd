# 강릉 반가(오죽헌·선교장풍) — 높은 장대석 기단 위 긴 一자 기와 안채 + 앞에 나란한 긴 행랑채(대문간). 위에서 '二' 두 줄 지붕.
# 고증: 강릉 반가는 영동 평야의 넉넉한 一자·튼ㅁ자, 기단이 높고 처마가 깊다(오죽헌 별당 팔작, 선교장 긴 행랑 23칸). 행랑 길이는 줄임.
# params: seed, haengrang(true), bays(안채 칸 "wdmmmdw")
extends RefCounted
const C := preload("res://kit/village/_common.gd")
const CC := preload("res://kit/culture/_cc.gd")

static func build(params: Dictionary) -> Dictionary:
	var m := C.M.new(int(params.get("seed", 1)))
	var bays: String = params.get("bays", "wdmmmdw")
	var L := bays.length() * 2.45
	CC.house(m, [{ name = "anchae", x0 = -L / 2, x1 = L / 2, z0 = -6.6, z1 = -1.2, face = "s", bays = bays, F = 1.15, wall_h = 2.35, maru = 0.95 }], "giwa", { ov = 1.6 })
	var fd := 0.0
	if params.get("haengrang", true):
		var H := L + 3.0
		CC.house(m, [{ name = "haengrang", x0 = -H / 2, x1 = H / 2, z0 = 5.6, z1 = 8.6, face = "s", bays = "bcbbgbbcb", F = 0.35, wall_h = 2.0, wall = "plaster", steps = false }], "giwa", { ov = 1.1, rise_k = 0.6 })
		fd = 8.6 + 1.2
	return m.result("강릉반가", Vector2(L + 6.0, 6.6 + 1.6 + maxf(fd, 2.0)))
