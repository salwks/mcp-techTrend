# 영남 ㅁ자 뜰집(안동형) — 안채(북)·좌우 익랑·사랑대문채(남)가 작은 안마당을 꽉 둘러싼 막힌 ㅁ자. 지붕이 한 덩이로 이어져
#   위에서 보면 가운데 네모난 '하늘 구멍'이 뚫린 지붕 고리로 읽힌다(이 문화권의 첫 신호).
# 고증: 경북 북부(안동·봉화·영주) 반가·민가의 ㅁ자 뜰집. 안채는 대청 두 칸을 사이에 두고 안방·건넌방, 부엌은 안방 쪽 익랑,
#   앞채는 대문간·사랑방·사랑마루·외양간·광. 안채를 높은 기단에 올려 지붕이 가장 높다. 초가 뜰집도 있다(봉화·영양 '까치구멍집' 계열은 가설로 단순화).
# params: seed, roof("giwa"|"choga"), w(14: 바깥 폭), d(13.6: 바깥 깊이)
# 앵커: anchae_daecheong, sarang_gate(대문 밖), sarang_gate_in(안마당), sarang_daecheong(사랑마루), west_kitchen
extends RefCounted
const C := preload("res://kit/village/_common.gd")
const CC := preload("res://kit/culture/_cc.gd")

static func build(params: Dictionary) -> Dictionary:
	var m := C.M.new(int(params.get("seed", 1)))
	var info := draw(m, params)
	return m.result("뜰집", Vector2(info.W + 3.0, info.D + 3.4))

static func draw(m: C.M, params: Dictionary) -> Dictionary:
	var giwa: bool = params.get("roof", "giwa") == "giwa"
	var W: float = params.get("w", 14.0 if giwa else 12.6); var Dd: float = params.get("d", 13.6 if giwa else 12.4)
	var hx := W / 2; var z0 := -Dd / 2; var z1 := Dd / 2
	var dn := 4.8 if giwa else 4.2    # 안채 깊이
	var ds := 3.7 if giwa else 3.4    # 앞채 깊이
	var dw := 3.5 if giwa else 3.2    # 익랑 깊이
	var wall := "plaster" if giwa else "red"
	var wings := [
		{ name = "anchae", x0 = -hx, x1 = hx, z0 = z0, z1 = z0 + dn, face = "s", bays = "wdmmdw", F = 0.95 if giwa else 0.55, wall_h = 2.3 if giwa else 1.9, wall = wall, maru = 0.0, eave_add = 0.25 },
		{ name = "west", x0 = -hx, x1 = -hx + dw, z0 = z0 + dn, z1 = z1 - ds, face = "e", bays = "kw", F = 0.6 if giwa else 0.4, wall_h = 2.1 if giwa else 1.8, wall = wall, chimney = "" },
		{ name = "east", x0 = hx - dw, x1 = hx, z0 = z0 + dn, z1 = z1 - ds, face = "w", bays = "dw", F = 0.6 if giwa else 0.4, wall_h = 2.1 if giwa else 1.8, wall = wall },
		{ name = "sarang", x0 = -hx, x1 = hx, z0 = z1 - ds, z1 = z1, face = "s", bays = "cbgwdm" if giwa else "cbgwd", F = 0.55 if giwa else 0.35, wall_h = 2.1 if giwa else 1.8, wall = wall, maru = 0.7 if giwa else 0.55, chimney = "low" },
	]
	CC.house(m, wings, "giwa" if giwa else "thatch", { ov = 1.2 if giwa else 0.75 })
	return { W = W, D = Dd }
