# 세로쓰기 글자 한 자 — 기록책(journal_view.gd)·문서(documents.gd)가 같이 쓴다.
#   한글·한자는 바로 세우고, 꺾쇠·괄호·줄표·말줄임은 90° 돌리고(︵ 꼴), 마침표·쉼표는 칸 오른쪽 위에 둔다.
#   따옴표 “ ” ‘ ’ 는 세로 글의 꺾쇠 「 」 『 』 로 바꾼다.
#   advance(글자, 크기, 글꼴) = 세로로 차지하는 길이 · draw(…) = 칸 가운데(center)에 그린다.
extends RefCounted

const ROTATE := "「」『』()[]〔〕{}〈〉《》—–-~…‥―:;<>→←"
const CORNER := ".,、。"
const CLOSERS := "」』)]〕}〉》.,、。!?:;…"   # 글줄 첫머리에 오지 않게(앞 줄 끝에 매단다)
const QUOTE := { "“": "「", "”": "」", "‘": "『", "’": "』", "\"": "「" }

static func vchar(ch: String) -> String:
	return QUOTE.get(ch, ch)

static func is_closer(ch: String) -> bool:
	return CLOSERS.contains(vchar(ch))

static func advance(ch: String, fs: float, font: Font) -> float:
	ch = vchar(ch)
	if ch == " ": return fs * 0.45
	if CORNER.contains(ch): return fs * 0.5
	if ch == "·": return fs * 0.7
	if ROTATE.contains(ch):
		return maxf(fs * 0.5, font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, int(fs)).x)
	var c := ch.unicode_at(0)
	if c < 0x1100: return fs * 0.8   # 숫자·로마자는 조금 좁게
	return fs * 1.06

static func draw(ci: CanvasItem, font: Font, center: Vector2, ch: String, fs: float, col: Color) -> void:
	ch = vchar(ch)
	if ch == " ": return
	var ifs := int(fs)
	var w := font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, ifs).x
	var asc := font.get_ascent(ifs); var desc := font.get_descent(ifs)
	var base := (asc - desc) * 0.5
	if ROTATE.contains(ch):
		ci.draw_set_transform(center, PI * 0.5)
		ci.draw_string(font, Vector2(-w * 0.5, base), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, ifs, col)
		ci.draw_set_transform_matrix(Transform2D.IDENTITY)
	elif CORNER.contains(ch):
		ci.draw_string(font, center + Vector2(fs * 0.22 - w * 0.5, base - fs * 0.32), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, ifs, col)
	else:
		ci.draw_string(font, center + Vector2(-w * 0.5, base), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, ifs, col)

# 한 줄을 위에서 아래로(줄바꿈 없이) — 칸 가운데 x, 첫 칸 위 y. 그린 길이를 돌려준다
static func column(ci: CanvasItem, font: Font, top_center: Vector2, text: String, fs: float, col: Color) -> float:
	var y := 0.0
	for i in text.length():
		var ch := text.substr(i, 1)
		var a := advance(ch, fs, font)
		draw(ci, font, top_center + Vector2(0, y + a * 0.5), ch, fs, col)
		y += a
	return y

static func length(font: Font, text: String, fs: float) -> float:
	var y := 0.0
	for i in text.length(): y += advance(text.substr(i, 1), fs, font)
	return y

# 한자 숫자(판심 장수): 1 → 一, 12 → 十二, 20 → 二十
static func hanja_num(n: int) -> String:
	var D := ["", "一", "二", "三", "四", "五", "六", "七", "八", "九"]
	if n <= 0: return "〇"
	if n < 10: return D[n]
	if n < 100: return (D[n / 10] if n / 10 > 1 else "") + "十" + D[n % 10]
	return str(n)
