# 기호 ㄱ자집 — ㄱ자 안채(북쪽 몸채 + 서쪽에서 앞으로 꺾인 부엌·건넌방 칸) + 앞 오른쪽에 따로 선 一자 사랑채(튼 ㅁ자 마당).
# 고증: 경기·충청(기호) 민가·반가의 대표형은 ㄱ자 안채 — 안방이 꺾인 귀에, 부엌이 앞으로 나온다. 사랑채는 대문 가까이 따로(一자·ㄱ자).
# 위에서: 꺾인 지붕 하나(ㄱ) + 앞쪽에 떨어진 작은 지붕 하나 — 영남(막힌 ㅁ)·호남(一자 둘셋)과 구별.
# params: seed, roof("giwa"|"choga"), sarang(true)
extends RefCounted
const C := preload("res://kit/village/_common.gd")
const CC := preload("res://kit/culture/_cc.gd")

static func build(params: Dictionary) -> Dictionary:
	var m := C.M.new(int(params.get("seed", 1)))
	var giwa: bool = params.get("roof", "giwa") == "giwa"
	var rf := "giwa" if giwa else "thatch"
	var wall := "plaster" if giwa else "mud"
	var an := [
		{ name = "anchae", x0 = -6.0, x1 = 5.6, z0 = -7.0, z1 = -2.6, face = "s", bays = "dmmdw", wall = wall, maru = 0.7 if giwa else 0.55, F = 0.8 if giwa else 0.45, chimney = "low" },
		{ name = "wing", x0 = -6.0, x1 = -2.6, z0 = -2.6, z1 = 3.2, face = "e", bays = "kd", wall = wall, F = 0.8 if giwa else 0.45 },
	]
	CC.house(m, an, rf, { ov = 1.3 if giwa else 0.8 })
	if params.get("sarang", true):
		CC.house(m, [{ name = "sarang", x0 = 0.4, x1 = 7.6, z0 = 3.6, z1 = 7.2, face = "s", bays = "dmw", wall = wall, maru = 0.7, F = 0.6 if giwa else 0.4 }], rf, { ov = 1.2 if giwa else 0.8 })
	return m.result("ㄱ자집", Vector2(16.5, 17.5))
