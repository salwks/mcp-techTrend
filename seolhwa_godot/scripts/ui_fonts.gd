# 화면 글꼴 한 곳 — 덕온공주체(국립한글박물관 무료 글꼴, assets/fonts/).
#   UiFonts.main()    본문·안내·대화·메뉴(DeogonPrincess)
#   UiFonts.classic() 제목·기록책 머리·지명(DeogonPrincessClassic — 더 옛 책 같은 획)
#   UiFonts.install() 테마 기본 글꼴(ThemeDB.fallback_font)을 main()으로 — 글꼴을 따로 주지 않은 Label·Button도 같은 글꼴
#   UiFonts.label(글, 크기, 색, classic?) 간단한 Label 하나
# 덕온공주체에 없는 글자(한자 朴·驛 등, 일부 기호)는 시스템 명조 줄(AppleMyungjo → 나눔명조 → 바탕 → Noto Serif CJK)이 그린다.
# 글자 확인: godot --headless --path seolhwa_godot --script res://tools/font_coverage.gd
# 글꼴 파일은 임포트 없이 실행 중에 읽는다(.otf 바이트 → FontFile) — 내보내기 설정에 *.otf를 넣을 것.
extends RefCounted

const MAIN_PATH := "res://assets/fonts/DeogonPrincess.otf"
const CLASSIC_PATH := "res://assets/fonts/DeogonPrincessClassic.otf"
const SYSTEM_SERIF := ["AppleMyungjo", "Nanum Myeongjo", "NanumMyeongjo", "Batang", "Noto Serif CJK KR", "Apple SD Gothic Neo"]

static var _raw := {}
static var _main: Font = null
static var _classic: Font = null
static var _sys: SystemFont = null
static var _installed := false

static func system() -> SystemFont:
	if _sys == null:
		_sys = SystemFont.new()
		_sys.font_names = PackedStringArray(SYSTEM_SERIF)
	return _sys

# 대체 글꼴 없는 원본(글자 확인용)
static func raw(which: String) -> FontFile:
	if not _raw.has(which):
		var ff := FontFile.new()
		var p := CLASSIC_PATH if which == "classic" else MAIN_PATH
		var bytes := FileAccess.get_file_as_bytes(p)
		if bytes.is_empty(): push_warning("UiFonts: %s 를 읽지 못함 — 시스템 명조로" % p)
		else:
			if which == "classic": _drop_cursive(bytes)
			ff.data = bytes
		ff.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		ff.hinting = TextServer.HINTING_LIGHT
		ff.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
		_raw[which] = ff
	return _raw[which]

# Classic(흘림 궁체)은 받침 없는 ㅗ·ㅛ 글자(고·노·도·소·오·교…)를 한 획으로 이어 써서 'ㄹ'·'ㄴ'처럼 보인다
# (「스승의 가르침」 "모른다고."의 '고'가 'ㄹ'로 읽힘). 실행 중에 읽은 바이트의 cmap(형식 4)에서 그 글자들의 글리프 번호를 0으로
# 지운다 — 글꼴에 '없는 글자'가 되어 대체 글꼴(main, 같은 덕온공주체의 바른 꼴)이 그린다. 파일 자체는 고치지 않는다.
const CURSIVE_VOWELS := [8, 12]   # 중성 번호: ㅗ, ㅛ
static func cursive_chars() -> PackedInt32Array:
	var out := PackedInt32Array()
	for l in 19:
		for v in CURSIVE_VOWELS: out.append(0xAC00 + (l * 21 + v) * 28)
	return out

static func _be16(b: PackedByteArray, o: int) -> int: return (b[o] << 8) | b[o + 1]
static func _be32(b: PackedByteArray, o: int) -> int: return (_be16(b, o) << 16) | _be16(b, o + 2)

static func _drop_cursive(b: PackedByteArray) -> int:
	var cmap := -1
	for i in _be16(b, 4):
		var r: int = 12 + 16 * i
		if b.slice(r, r + 4).get_string_from_ascii() == "cmap": cmap = _be32(b, r + 8)
	if cmap < 0: return 0
	var done := {}
	var n := 0
	for i in _be16(b, cmap + 2):
		var st: int = cmap + _be32(b, cmap + 8 + 8 * i)
		if done.has(st) or _be16(b, st) != 4: continue
		done[st] = true
		var seg2: int = _be16(b, st + 6)
		var ends := st + 14; var starts := ends + seg2 + 2; var deltas := starts + seg2; var ros := deltas + seg2
		for c in cursive_chars():
			for k in seg2 / 2:
				if _be16(b, ends + 2 * k) < c: continue
				if _be16(b, starts + 2 * k) > c: break
				var ro: int = _be16(b, ros + 2 * k)
				if ro == 0: break   # 델타 구간은 낱자만 지울 수 없다(이 글꼴의 한글은 모두 배열 구간)
				var at: int = ros + 2 * k + ro + 2 * (c - _be16(b, starts + 2 * k))
				b[at] = 0; b[at + 1] = 0
				n += 1
				break
	return n

static func main() -> Font:
	if _main == null:
		var ff: FontFile = raw("main").duplicate()
		if ff.data.is_empty(): _main = system()
		else:
			ff.fallbacks = [system()]
			_main = ff
	install()
	return _main

static func classic() -> Font:
	if _classic == null:
		var ff: FontFile = raw("classic").duplicate()
		if ff.data.is_empty(): _classic = main()
		else:
			ff.fallbacks = [raw("main"), system()]
			_classic = ff
	return _classic

static func install() -> void:
	if _installed: return
	_installed = true
	ThemeDB.fallback_font = main()

static func label(text: String, size: int, col := Color("#2b2622"), classic_face := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", classic() if classic_face else main())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
