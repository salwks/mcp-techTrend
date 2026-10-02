# 실상사(實相寺, 남원 산내면) 배치 도우미 — 지리산 자락 평지에 앉은 드문 평지 가람.
# 남→북: (해탈교: 일주문 대신, 만수천 위 — 지형 담당/마을 키트 다리) → 천왕문 → 마당의 동·서 삼층석탑 → 석등 → 보광전.
# 약사전은 탑 오른편(동쪽)에 둠(검색 근거: "탑 오른쪽에 약사전"). 거리·담장 범위는 가설(실제 경내보다 줄임).
# 원점 = 경내 가운데 바닥, 정면(천왕문) +z. params: seed, width(64), depth(62)
extends RefCounted

const Co = preload("res://kit/landmark/_common.gd")

static func layout(params: Dictionary) -> Array:
	var seed: int = int(params.get("seed", 1))
	var W: float = float(params.get("width", 64.0)); var D: float = float(params.get("depth", 62.0))
	var x0 := -W / 2; var x1 := W / 2; var z0 := -D / 2; var z1 := D / 2
	var p := []
	p.append({ kit = "landmark/cheonwangmun", params = { seed = seed }, x = 0.0, z = z1 - 1.0, ry = 0.0, tag = "cheonwangmun" })
	p.append({ kit = "landmark/bogwangjeon", params = { seed = seed + 1 }, x = 0.0, z = z0 + 14.0, ry = 0.0, tag = "bogwangjeon" })
	p.append({ kit = "landmark/seokdeung", params = { seed = seed + 2 }, x = 0.0, z = z0 + 27.0, ry = 0.0, tag = "seokdeung" })
	p.append({ kit = "landmark/seoktap", params = { seed = seed + 3 }, x = -11.0, z = z0 + 36.0, ry = 0.0, tag = "seotap" })
	p.append({ kit = "landmark/seoktap", params = { seed = seed + 4, height = 8.6 }, x = 11.0, z = z0 + 36.0, ry = 0.0, tag = "dongtap" })
	p.append({ kit = "landmark/yaksajeon", params = { seed = seed + 5 }, x = 22.0, z = z0 + 30.0, ry = -PI / 2, tag = "yaksajeon" })
	p.append_array(Co.wall_pieces([Vector2(x0, z0), Vector2(x1, z0), Vector2(x1, z1), Vector2(x0, z1)], true, [[0.0, z1, 5.4]], seed + 20, 1.9))
	return p

static func build(params: Dictionary) -> Dictionary:
	var W: float = float(params.get("width", 64.0)); var D: float = float(params.get("depth", 62.0))
	var pieces := layout(params)
	var r := Co.assemble("실상사", pieces)
	r.occluder = true
	r.footprint = Vector2(W + 2, D + 8)
	r.pieces = pieces
	return r
