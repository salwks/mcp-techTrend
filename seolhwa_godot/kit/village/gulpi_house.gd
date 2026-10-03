# 굴피집 — 굴참나무 껍질(굴피)을 얹은 산촌 민가. 몸체는 너와집과 같고 지붕만 다르다.
# 고증: 굴피는 굴참나무 껍질을 벗겨 펴 말린 판(너와보다 넓고 얇음)으로, 처마부터 겹쳐 얹고 누름목(통나무)을 가로로 여러 줄
#   얹어 눌렀다(강원 삼척 신리 등). 지리산권 분포는 "가설".
# 위에서 볼 때: 짙은 갈색 넓은 판 + 밝은 누름목 가로 세 줄 + 용마루 통나무 — 너와(회갈색·돌)와 색·줄이 다르다.
# params: seed, w(6.0), d(4.0), plan(""|"il"|"giyeok"), open(false), lod(0|1)
extends RefCounted
const C := preload("res://kit/village/_common.gd")
const NW := preload("res://kit/village/neowa_house.gd")

static func build(params: Dictionary) -> Dictionary:
	var m := C.M.new(int(params.get("seed", 1)))
	var p := params.duplicate()
	p.w = float(params.get("w", 6.0)); p.d = float(params.get("d", 4.0))
	var info := NW.draw(m, p, "gulpi")
	return m.result("굴피집", Vector2(info.W + 2.2, info.D + 2.6 + info.wing_len))
