# 너와집 — 산촌(지리산·백두대간 고지) 민가. 흙벽 3칸 몸체에 나무판(너와) 맞배 지붕, 누름돌·누름대, 박공 까치구멍, 통나무 굴뚝.
# 고증: 너와는 소나무·전나무를 쪼갠 널(약 40~60cm 폭)을 처마부터 겹쳐 얹고 돌·장대로 눌렀다(강원·지리산 산간). 지리산 서부
#   반선·뱀사골 일대 너와집 분포는 "가설"(19세기 기록 희박, 20세기 조사 사진 기준).
# 위에서 볼 때: 회갈색 판 줄무늬 + 흩어진 회색 누름돌 + 가로 장대 하나 — 초가(노란 둥근 이엉)·기와(회색 곡면)와 바로 구별.
# params: seed, w(6.4), d(4.2), plan(""|"il"|"giyeok"), open(false), lod(0|1: 판 줄 2, 돌 없음)
extends RefCounted
const C := preload("res://kit/village/_common.gd")
const CH := preload("res://kit/village/choga.gd")

static func build(params: Dictionary) -> Dictionary:
	var m := C.M.new(int(params.get("seed", 1)))
	var info := draw(m, params, "neowa")
	return m.result("너와집", Vector2(info.W + 2.2, info.D + 2.6 + info.wing_len))

# 너와·굴피 공용: 초가 몸체를 빌리고 판 지붕을 얹음
static func draw(m: C.M, params: Dictionary, style: String) -> Dictionary:
	var o := params.duplicate()
	o.w = float(params.get("w", 6.4)); o.d = float(params.get("d", 4.2))
	o.roof = "none"; o.chimney = "log"
	var info := CH.draw(m, o)
	var W: float = info.W; var D: float = info.D
	var lod := int(params.get("lod", 0)) == 1
	var deep := 0.35 if o.get("plan", "") == "il" else 0.0
	C.board_roof(m, "roof", W + 1.5, D + 2.0 + deep * 2, info.top + 0.1, 1.75, style, W, D, info.top, lod)
	if o.get("plan", "") == "giyeok":
		var wl: float = info.wing_len; var bw: float = info.bw; var zf: float = info.zf
		var z0 := zf - 0.6; var z1 := zf + wl + 0.75
		var old := m.push(W / 2 - bw / 2, 0, (z0 + z1) / 2, PI / 2)
		C.board_roof(m, "roof", z1 - z0, bw + 1.5, info.top + 0.1, 1.35, style, 2.0 * (zf + wl - (z0 + z1) / 2), bw, info.top, lod, true)
		m.pop(old)
	return info
