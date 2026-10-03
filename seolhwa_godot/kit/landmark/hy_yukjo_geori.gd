# 육조거리(광화문 앞 큰길) 배치형 — 광화문(hy_gwanghwamun) 앞 너비 약 60m(압축 40m) 길 양옆에 관청(hy_yukjo) 셋씩.
# 동쪽: 의정부·이조·호조(한성부 생략), 서쪽: 예조·병조·형조·공조(공조 생략) — 실제 순서 근사(가설). 관청은 길을 봄(동 ry=+π/2? — 정면 +z가 길 쪽이 되게 동쪽 줄 ry=−π/2, 서쪽 줄 ry=+π/2).
# 원점 = 길 가운데, 광화문은 북쪽 끝(z = −len/2). params: seed, length(130), gate(true). pieces 반환
extends RefCounted

const Hub = preload("res://kit/landmark/_hub.gd")

static func layout(params: Dictionary) -> Array:
	var seed: int = int(params.get("seed", 1))
	var L: float = float(params.get("length", 130.0))
	var road := 40.0
	var p := []
	if params.get("gate", true):
		p.append({ kit = "landmark/hy_gwanghwamun", params = { seed = seed }, x = 0.0, z = -L / 2 - 6.0, ry = 0.0, tag = "gwanghwamun" })
	var east := ["의정부", "이조", "호조"]; var west := ["예조", "병조", "형조"]
	for i in 3:
		var z := -L / 2 + 26.0 + i * 38.0
		p.append({ kit = "landmark/hy_yukjo", params = { seed = seed + 10 + i, name = east[i], width = 34.0, depth = 30.0 }, x = road / 2 + 15.0, z = z, ry = -PI / 2, tag = "yukjo_e%d" % i })
		p.append({ kit = "landmark/hy_yukjo", params = { seed = seed + 20 + i, name = west[i], width = 34.0, depth = 30.0 }, x = -road / 2 - 15.0, z = z, ry = PI / 2, tag = "yukjo_w%d" % i })
	return p

static func build(params: Dictionary) -> Dictionary:
	return Hub.composite("육조거리", layout(params), Vector2(110.0, float(params.get("length", 130.0)) + 20.0))
