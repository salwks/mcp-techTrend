# 영남 작은집 — 길가·읍내 빈 틈에 들어가는 좁은 집(폭 8.4~10.5m). 一자 3칸(il: 부엌·안방·마루) / ㄱ자(giyeok: 동쪽 1칸이 앞으로 꺾임).
# roof "giwa"(읍내 이속·상인 집: 회벽, 높은 기단) | "choga"(붉은 흙벽, 낮은 기단). 울은 없다 — 길가에 바로 붙거나 이웃 담을 같이 쓴다.
# 고증: 읍내 길가에는 ㅁ자 뜰집 사이로 一자·ㄱ자 작은 집이 촘촘했다(호구 대장의 2~3칸 집이 다수). 크기·칸 짜임은 가설로 단순화.
# 위에서: 짧은 一자 또는 작은 ㄱ — 옆의 ㅁ자 고리(compound·tteuljip)보다 확실히 작다.
# params: seed, plan("il"|"giyeok"), roof("giwa"|"choga"), w(9.0)
extends RefCounted
const C := preload("res://kit/village/_common.gd")
const CC := preload("res://kit/culture/_cc.gd")

static func build(params: Dictionary) -> Dictionary:
	var m := C.M.new(int(params.get("seed", 1)))
	var W: float = params.get("w", 9.0)
	var hx := W / 2
	var giwa: bool = params.get("roof", "choga") == "giwa"
	var wall := "plaster" if giwa else "red"
	var F := 0.5 if giwa else 0.3
	var wings := [{ name = "anchae", x0 = -hx, x1 = hx, z0 = -1.9, z1 = 1.9, face = "s", bays = "kdm", wall = wall, F = F, maru = 0.6,
		chimney = "low" }]
	var fd := 0.0
	if params.get("plan", "il") == "giyeok":
		wings.append({ name = "wing", x0 = hx - 3.0, x1 = hx, z0 = 1.9, z1 = 5.2, face = "w", bays = "cd", wall = wall, F = F, maru = 0.0 })
		fd = 3.3
	var ov := 1.0 if giwa else 0.7
	CC.house(m, wings, "giwa" if giwa else "thatch", { ov = ov })
	return m.result("영남작은집", Vector2(W + ov * 2, 3.8 + ov * 2 + fd + 0.6))
