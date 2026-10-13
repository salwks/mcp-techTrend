# 제목 그림 한 곳 — 붓글씨 로고(검은 먹 「설화록」 + 붉은 해 + 錄 도장). 원래 「설화록」 제목이 있던 자리에만 쓴다(새 자리에 더하지 않는다):
#   불러오기 화면(region_main._make_load_ui) · 남원 여는 장면 제목 카드(story_ui.title_card("설화록")). 시작 메뉴는 움직이는 바탕(title_wallpaper.gd)에 로고가 그려져 있다.
#   TitleArt.logo()  로고 텍스처(2000×758, 투명 바탕) — 밉맵이 있어 작게 그려도 거칠지 않다(TextureRect.texture_filter = LINEAR_WITH_MIPMAPS)
#   TitleArt.halo()  로고 뒤 엷은 한지 번짐(가운데 진하고 가장자리로 사라지는 타원) — 3D 장면 위에서도 먹 글씨가 읽히게
# 그림은 임포트 없이 실행 중에 읽는다(.webp 바이트 → Image) — 글꼴(ui_fonts.gd)과 같은 방식. 내보내기 설정에 *.webp를 넣을 것.
extends RefCounted

const LOGO_PATH := "res://assets/ui/title_logo_source.webp"
const LOGO_ASPECT := 2000.0 / 758.0
const PAPER := Color("#efe6d2")

static var _logo: Texture2D = null
static var _halo: Texture2D = null

static func _read(path: String, mips: bool) -> Texture2D:
	var img := Image.new()
	if img.load_webp_from_buffer(FileAccess.get_file_as_bytes(path)) != OK:
		push_warning("TitleArt: %s 읽기 실패" % path)
		return null
	if mips: img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

static func logo() -> Texture2D:
	if _logo == null: _logo = _read(LOGO_PATH, true)
	return _logo

static func halo() -> Texture2D:
	if _halo == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.45, 0.75, 1.0])
		g.colors = PackedColorArray([Color(PAPER, 0.78), Color(PAPER, 0.62), Color(PAPER, 0.22), Color(PAPER, 0.0)])
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5); t.fill_to = Vector2(1.0, 0.5)
		t.width = 256; t.height = 128
		_halo = t
	return _halo

# 로고 한 벌(번짐 + 로고)을 Control로 — 크기·위치는 부르는 쪽이 정한다(rect 가운데 맞춤, 비율 유지)
static func logo_node(with_halo := true) -> Control:
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if with_halo:
		var h := TextureRect.new()
		h.name = "halo"
		h.texture = halo(); h.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; h.stretch_mode = TextureRect.STRETCH_SCALE
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.set_anchors_preset(Control.PRESET_FULL_RECT)
		h.anchor_left = -0.12; h.anchor_right = 1.12; h.anchor_top = -0.35; h.anchor_bottom = 1.35
		root.add_child(h)
	var l := TextureRect.new()
	l.name = "logo"
	l.texture = logo(); l.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; l.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	l.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(l)
	return root
