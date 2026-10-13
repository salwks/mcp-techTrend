# 화면 글꼴 한 곳 — 덕온공주체(국립한글박물관 무료 글꼴, assets/fonts/).
#   UiFonts.main()    본문·안내·대화·메뉴(DeogonPrincess)
#   UiFonts.classic() 제목·기록책 머리·지명(DeogonPrincessClassic — 더 옛 책 같은 획)
#   UiFonts.install() 테마 기본 글꼴(ThemeDB.fallback_font)을 main()으로 — 글꼴을 따로 주지 않은 Label·Button도 같은 글꼴
#   UiFonts.label(글, 크기, 색, classic?) 간단한 Label 하나
#   UiFonts.TITLE · HEAD · NAME · BODY · DETAIL · KEYS · NOTE · MIN · MAP_* — 화면 글 크기 한 표(HUD·메뉴·지도가 같이 쓴다)
#   UiFonts.fit(글꼴, 글, 크기, 너비) — 한 줄에 넘치면 끝을 '…'로
# 덕온공주체에 없는 글자(한자 朴·驛 등, 일부 기호)는 시스템 명조 줄(AppleMyungjo → 나눔명조 → 바탕 → Noto Serif CJK)이 그린다.
# 글자 확인: godot --headless --path seolhwa_godot --script res://tools/font_coverage.gd
# 글꼴 파일은 임포트 없이 실행 중에 읽는다(.otf 바이트 → FontFile) — 내보내기 설정에 *.otf를 넣을 것.
extends RefCounted

# ---- 화면 글 크기 한 표(공통 UI 규칙 — seolhwa/docs/production/CITY_ROUTE_PRODUCTION_RULES_v1.0.md '화면 글 크기' C64) ----
# 기준 화면 1920×1080(project.godot — stretch canvas_items · aspect expand, 창 크기에 따라 화면 전체가 같이 커지고 작아진다).
# 표의 값은 그 1920×1080 캔버스의 픽셀. 각 화면은 UiFonts.k(보이는 크기) = 높이/1080(16:9보다 세로가 긴 창에서만 1보다 커진다)을 곱한다.
# 2026-10-13 1024×768 → 1920×1080: 예전 값 × 1.45(화면 높이에 대한 비율로 예전보다 조금 크게 — 1080/768 = 1.406).
# 지도 글은 확대·축소와 상관없이 이 크기 그대로. 글이 넘치면 줄이지 말고 나누기·두 단·쪽 넘김·줄바꿈(StoryUI.wrap_words)·말줄임(fit)으로 맞춘다.
const BASE_W := 1920.0
const BASE_H := 1080.0
const TITLE := 64       # 창 제목(잠시 멈춤 · 저장 · 역마)
const HEAD := 50        # 머리(조사 카드 제목 · 시작 메뉴 항목 · 갈래 제목)
const NAME := 44        # 이름(대화 화자 · 저장 칸 이름 · 지도 판 제목)
const BODY := 40        # 본문 · 메뉴 줄 · 대화 · 선택지
const DETAIL := 35      # 덧붙임(저장 칸 시각 · 물음 · 목록 부가)
const KEYS := 32        # 조작 안내 줄(↑↓ 고르기 …) · 키 칸 옆 글
const NOTE := 29        # 작은 덧글(두주 · 쪽 수 · 지도 판 부제)
const MIN := 26         # 이보다 작은 글은 쓰지 않는다
# 지도(권역·고을·전국·역마 창 작은 지도 — 확대·축소와 상관없이 화면에서 늘 이 크기).
#   2026-10-11 사용자: 고을(도시) 이름 크기는 그대로(예전 MAP_HUB 26 · MAP_TOWN 24 — 1080 기준 38 · 35), 그 밖의 지도 글은 모두 고을 이름 크기 이상 —
#   마을·건물·이름난 곳·고개·물 이름, 범례(글·기호), 기호 속 글자, 판, 아래 안내, 10리 자, 확인 상자, 역마 창 작은 지도 이름.
#   고을 이름은 크기 대신 Classic 글꼴·먹색·한지 판(읍치)으로 도드라진다. 넘치면 줄이지 말고 솎기·확대 단계·판 쪽 넘김으로.
const MAP_HUB := 38     # 읍치·권역 거점·지금 고을(고을 이름 — 다른 지도 글과의 비율을 바꾸지 않는다)
const MAP_TOWN := 35    # 장터·역·원·절 고을(고을 이름)
const MAP_MIN := 38     # 고을 이름이 아닌 지도 글의 바닥(= MAP_HUB)
const MAP_LABEL := 38   # 마을·이름난 곳·건물·물 이름·역참·사건 장소·사건 이름(전국)
const MAP_MINOR := 38   # 고개·나루·오름·용천수·노정 이름·전국 거점
const MAP_GLYPH := 38   # 기호 속 글자('역' · '사' · 방위 · 번호) — 기호 그림이 글자에 맞춰 커진다
const MAP_PANEL := 38   # 지도 판(범례 · 사건 · 역참) 줄·머리
const MAP_KEYS := 38    # 지도 아래 조작 안내 · 10리 자 · 표지 설명 · 확인 상자

# 화면 배율: 보이는 크기(get_visible_rect().size)의 높이/1080. 16:9 이상 넓은 창이면 늘 1(캔버스가 1080 높이 그대로 늘고 준다).
static func k(vs: Vector2, lo := 0.75, hi := 2.4) -> float:
	return clampf(vs.y / BASE_H, lo, hi)

# 한 줄에 넣기: 넘치면 끝을 '…'로(긴 지명·목록 줄)
static func fit(font: Font, text: String, size: int, max_w: float) -> String:
	if font == null or max_w <= 0.0 or font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x <= max_w: return text
	var lo := 0
	var hi := text.length()
	while lo < hi:
		var mid := (lo + hi + 1) / 2
		if font.get_string_size(text.substr(0, mid) + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, size).x <= max_w: lo = mid
		else: hi = mid - 1
	return text.substr(0, lo).strip_edges() + "…"

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
