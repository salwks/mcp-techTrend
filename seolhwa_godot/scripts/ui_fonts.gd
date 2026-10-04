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
		else: ff.data = bytes
		ff.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		ff.hinting = TextServer.HINTING_LIGHT
		ff.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
		_raw[which] = ff
	return _raw[which]

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
