# 시작 메뉴 움직이는 바탕(living wallpaper) — 「설화록」 움직이는 배경(Godot 4, 3840×2160 캔버스 11겹)을 게임 안으로 옮긴 것.
#   원본: Seolhwarok_LivingWallpaper_Godot.zip(사용자 제공, 2026-10-13) — LivingWallpaper.gd/.tscn · shaders/(water · mist · scholar · wind).
#   docs/reports/resolution-1080-title-art.md에 출처·바꾼 것을 적었다.
# 겹(아래→위): 01 하늘 · 02 산 · 04 강 · 03 마을 · 07 안개 · 05 소나무 · 11 앞 바위 · 06 선비(족자) · 학 셋 · 꽃잎 28 · 10 로고(그림의 일부 — 다른 제목을 따로 그리지 않는다).
# 움직임: 강 물결(water) · 안개 흐름(mist) · 선비 도포·족자 물결(scholar) · 소나무·하늘 바람(wind) · 꽃잎(아틀라스 조각) · 학(가로 활공).
# 그림: assets/title_wallpaper/*.webp(1920×1080 — 선비·로고만 2560×1440, 셰이더 겹은 캔버스 전체, 나머지는 그림 둘레만 잘라 자리를 wallpaper.json에)
#   실행 중에 읽는다(assets/.gdignore — 임포트 없음). 정적 캐시를 두지 않아 메뉴가 닫히면 텍스처가 함께 풀린다.
# 화면 맞춤: 캔버스 3840×2160을 보이는 크기에 '덮기'(cover) — 16:9가 아니면 FOCUS 둘레를 남기고 자른다.
# 원본의 설정 창(H) · Space 멈춤 · F 전체 화면 · R 처음부터 · Esc · 안내 글 · --record · Engine.max_fps 고정은 뺐다(입력은 시작 메뉴가 가진다).
extends Node2D

const CANVAS := Vector2(3840.0, 2160.0)
const DIR := "res://assets/title_wallpaper/"
const FOCUS := Vector2(0.5, 0.5)
const PETALS := 18          # 원본 기본값(0~28 중 18)
const WIND := 0.75          # 원본 '보통'
const SHADERS := { "04_river": "water", "07_mist": "mist", "06_scholar": "scholar", "05_pine": "wind", "01_sky": "wind" }

var elapsed := 0.0
var particle_elapsed := 0.0
var _mats: Array[ShaderMaterial] = []
var _petals: Array = []
var _cranes: Array = []
var _layers := {}

func _ready() -> void:
	var man = JSON.parse_string(FileAccess.get_file_as_string(DIR + "wallpaper.json"))
	if not (man is Dictionary):
		push_warning("TitleWallpaper: wallpaper.json 없음"); return
	for l in man.layers:
		var t := _tex(String(l.file))
		if t == null: continue
		var s := Sprite2D.new()
		s.name = String(l.name)
		s.texture = t
		s.centered = false
		s.position = Vector2(float(l.pos[0]), float(l.pos[1]))
		s.scale = Vector2.ONE * float(l.scale)
		s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		add_child(s)
		_layers[s.name] = s
		if SHADERS.has(s.name):
			var m := ShaderMaterial.new()
			m.shader = load("res://shaders/title_wp_%s.gdshader" % SHADERS[s.name])
			s.material = m
			_mats.append(m)
			if s.name == "05_pine": m.set_shader_parameter("amount", 0.0012); m.set_shader_parameter("anchor_y", 0.88)
			if s.name == "01_sky": m.set_shader_parameter("amount", 0.003); m.set_shader_parameter("anchor_y", 0.43)
	# 꽃잎(원본과 같은 씨앗·경로) — 아틀라스는 반으로 줄였으니 크기 ×2
	var atlas := _tex("petals_atlas.webp")
	var rng := RandomNumberGenerator.new(); rng.seed = 1739
	var regs: Array = man.petals
	for i in 28:
		var base := rng.randf_range(0.16, 0.36)
		var item := { phase = rng.randf(), duration = rng.randf_range(32.0, 50.0), scale = base * float(man.petal_scale), start_y = rng.randf_range(-500.0, 450.0), turn = rng.randf_range(-1.0, 1.0) }
		if i >= PETALS or atlas == null: continue
		var at := AtlasTexture.new(); at.atlas = atlas
		var r: Array = regs[i % regs.size()]
		at.region = Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3])); at.filter_clip = true
		var sp := Sprite2D.new(); sp.name = "Petal_%02d" % i; sp.texture = at; sp.z_index = 20
		add_child(sp)
		item.sprite = sp
		_petals.append(item)
	for i in 3:
		var t := _tex("crane_%d.webp" % i)
		if t == null: continue
		var sp := Sprite2D.new(); sp.name = "Crane_%d" % i; sp.texture = t; sp.z_index = 12
		sp.scale = Vector2.ONE * 0.38 * float(man.crane_scale)
		add_child(sp)
		_cranes.append({ sprite = sp, phase = 0.65 + i * 0.065, duration = 88.0, height = 860.0 + i * 65.0 })
	if _layers.has("10_logo"): _layers["10_logo"].z_index = 30
	get_viewport().size_changed.connect(fit)
	fit()
	_apply()

static func _tex(file: String) -> Texture2D:
	var img := Image.new()
	if img.load_webp_from_buffer(FileAccess.get_file_as_bytes(DIR + file)) != OK:
		push_warning("TitleWallpaper: %s 읽기 실패" % file); return null
	return ImageTexture.create_from_image(img)

# 캔버스를 보이는 크기에 덮기 — 화면 좌표(보이는 크기 안)로 캔버스의 한 점(0~1)이 어디에 오는지 돌려준다(메뉴 자리 잡기)
func fit() -> void:
	var vs := get_viewport().get_visible_rect().size
	var k := maxf(vs.x / CANVAS.x, vs.y / CANVAS.y)
	scale = Vector2.ONE * k
	position = (vs - CANVAS * k) * FOCUS

func to_screen(uv: Vector2) -> Vector2:
	return position + CANVAS * uv * scale.x

func _process(dt: float) -> void:
	elapsed += dt
	particle_elapsed += dt * (0.6 + WIND * 0.5)
	_apply()

func _apply() -> void:
	for m in _mats:
		m.set_shader_parameter("clock", elapsed)
		m.set_shader_parameter("strength", WIND)
	for i in _petals.size():
		var it: Dictionary = _petals[i]
		var sp: Sprite2D = it.sprite
		var ph := fposmod(particle_elapsed / float(it.duration) + float(it.phase), 1.0)
		sp.position = Vector2(4050.0 - ph * 4400.0 + sin(ph * TAU + i) * 150.0, float(it.start_y) + ph * 2400.0 + sin(ph * TAU * 2.0 + i) * 80.0)
		sp.rotation = float(it.turn) + ph * TAU * (0.65 + float(it.turn))
		sp.scale = Vector2(float(it.scale) * (0.65 + 0.35 * absf(cos(elapsed * 0.6 + i))), float(it.scale))
		sp.modulate.a = smoothstep(0.0, 0.07, ph) * (1.0 - smoothstep(0.91, 1.0, ph)) * 0.88
	for i in _cranes.size():
		var it: Dictionary = _cranes[i]
		var sp: Sprite2D = it.sprite
		var ph := fposmod(elapsed / float(it.duration) + float(it.phase), 1.0)
		sp.position = Vector2(-350.0 + ph * 4540.0, float(it.height) + sin(ph * TAU + i * 0.65) * 75.0)
		sp.rotation = sin(elapsed * 0.55 + i) * 0.025
		sp.modulate.a = smoothstep(0.0, 0.06, ph) * (1.0 - smoothstep(0.94, 1.0, ph))
