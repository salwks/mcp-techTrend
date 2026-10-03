# 운종가(종로) 네거리 배치형 — 동서 큰길 양옆 시전 행랑(hy_sijeon) 줄 + 네거리 북동 모서리 종각(hy_bosingak). 남쪽으로 광통교 길이 갈라짐.
# 길 너비(약 17m)·행랑 길이는 압축 가설. 원점 = 네거리 가운데, 큰길은 x 방향. 북쪽 줄은 정면 +z(길 쪽), 남쪽 줄은 ry=π(길 쪽을 봄 — 카메라에는 등).
# params: seed, length(200: 동서 전체 길이), south_off(0: 남쪽 줄을 길에서 더 물림 m — 카메라 쪽 줄이 플레이어를 덜 가리게),
#         south_signs(true: 남쪽 줄 간판 — 카메라에는 등이라 끄면 가볍다). pieces 반환
extends RefCounted

const Hub = preload("res://kit/landmark/_hub.gd")

static func layout(params: Dictionary) -> Array:
	var seed: int = int(params.get("seed", 1))
	var half: float = float(params.get("length", 200.0)) / 2
	var road := 17.0
	var goods := ["silk", "cloth", "paper", "fish", "mixed"]
	var p := [{ kit = "landmark/hy_bosingak", params = { seed = seed }, x = road / 2 + 7.5, z = -road / 2 - 7.0, ry = 0.0, tag = "jonggak" }]
	var seg := 12 * 2.7 + 1.0
	var k := 0
	var s_off: float = float(params.get("south_off", 0.0)); var s_signs: bool = bool(params.get("south_signs", true))
	# 네거리에서 동·서로 줄지어: 북쪽 줄(종각 자리 피함), 남쪽 줄(광통교 길 너비 비움)
	for side in [-1, 1]:
		for row in [-1, 1]:
			var start: float = road / 2 + (17.0 if (row < 0 and side > 0) else 1.0)
			var x: float = start + seg / 2
			while x + seg / 2 <= half:
				var z: float = row * (road / 2 + 3.5) + (s_off if row > 0 else 0.0)
				var prm := { seed = seed + 10 + k, bays = 12, goods = goods[k % goods.size()] }
				if row > 0 and not s_signs: prm.signs = false
				p.append({ kit = "landmark/hy_sijeon", params = prm, x = side * x, z = z, ry = 0.0 if row < 0 else PI, tag = "sijeon_%d" % k })
				k += 1
				x += seg
	return p

static func build(params: Dictionary) -> Dictionary:
	return Hub.composite("운종가", layout(params), Vector2(float(params.get("length", 200.0)) + 4.0, 40.0))
