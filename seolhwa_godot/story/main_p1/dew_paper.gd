# 이슬에 번진 기록지(메인 서장 프롤로그 E5 — 시간의 흔적). 멍석 위에 남은 한 장을 그림(텍스처) 한 장으로 그린다:
#   누런 한지 · 바랜 먹 글씨 세로줄 · 젖은 자리에서 먹이 번져 나간 회청색 물빛(가장자리가 흐림) · 말라붙은 물자국 테.
#   키트 상자(먹줄·얼룩 상자)로는 가장자리가 딱딱해 '검은 조각'으로 읽혀서(2026-10-18 사용자 지적) 픽셀로 그린다. 한 번 만들어 둔다.
extends RefCounted

const W := 176
const H := 228
static var _tex: ImageTexture = null

static func texture() -> ImageTexture:
	if _tex != null: return _tex
	var rng := RandomNumberGenerator.new(); rng.seed = 3178
	# 젖은 자리(물이 고였다 마른 곳) — 가우스 덩어리 셋. wet 0~1
	var blobs := [[0.56, 0.40, 0.26], [0.42, 0.60, 0.17], [0.72, 0.62, 0.13]]
	var wet := PackedFloat32Array(); wet.resize(W * H)
	for y in H:
		for x in W:
			var u := float(x) / W; var v := float(y) / H
			var s := 0.0
			for b in blobs:
				var dx: float = (u - b[0]) / b[2]; var dy: float = (v - b[1]) / (b[2] * 0.8)
				s += exp(-(dx * dx + dy * dy))
			s *= 0.78 + 0.22 * sin(u * 29.0 + 1.7) * sin(v * 23.0 + 0.4)   # 번진 가장자리를 둥근 판이 아니게 들쭉날쭉
			wet[y * W + x] = clampf(s, 0.0, 1.0)
	# 먹 글씨: 세로줄 일곱(글자 덩이로 끊김) — ink 0~1
	var ink := PackedFloat32Array(); ink.resize(W * H)
	for c in 7:
		var cx := int(W * (0.84 - c * 0.11))
		var y := int(H * 0.08)
		while y < int(H * (0.9 - rng.randf() * 0.12)):
			var gh := rng.randi_range(10, 18)
			for yy in range(y, mini(y + gh, H)):
				for xx in range(cx - 3, cx + 4):
					if xx < 0 or xx >= W: continue
					if rng.randf() < 0.55: ink[yy * W + xx] = maxf(ink[yy * W + xx], rng.randf_range(0.5, 0.9))
			y += gh + rng.randi_range(4, 8)
	# 번짐: 먹을 넓게 흐린 판(작게 줄였다 늘림 — 엔진 안에서 빠르게). 젖은 자리에서만 섞는다
	var im := Image.create(W, H, false, Image.FORMAT_L8)
	for y in H:
		for x in W: im.set_pixel(x, y, Color(ink[y * W + x], 0, 0))
	im.resize(W / 9, H / 9, Image.INTERPOLATE_BILINEAR)
	im.resize(W, H, Image.INTERPOLATE_CUBIC)
	var blur := PackedFloat32Array(); blur.resize(W * H)
	for y in H:
		for x in W: blur[y * W + x] = im.get_pixel(x, y).r
	var img := Image.create(W, H, false, Image.FORMAT_RGB8)
	var paper := Color("#d6caa9"); var paper2 := Color("#c8b994")   # 키트 한지(PAPER)보다 조금 누렇게 — 흰 판처럼 뜨지 않게
	var wash := Color("#5d6c7c")     # 번진 먹의 회청색 물빛
	var inkc := Color("#2f2c2a")
	var stain := Color("#9c8050")    # 마른 물자국 테
	for y in H:
		for x in W:
			var i := y * W + x
			var u := float(x) / W; var v := float(y) / H
			var c := paper.lerp(paper2, clampf(0.5 + 0.5 * sin(u * 37.0 + v * 11.0) * cos(v * 23.0), 0.0, 1.0) * 0.35)   # 한지 결
			var w := wet[i]
			# 물자국 테: 첫 덩어리 둘레에 얇고 흐린 고리
			var dx := (u - 0.56) / 0.34; var dy := (v - 0.47) / 0.30
			var r := sqrt(dx * dx + dy * dy) + 0.07 * sin(3.0 * atan2(dy, dx) + 1.3) + 0.04 * sin(7.0 * atan2(dy, dx))
			c = c.lerp(stain, exp(-pow((r - 1.0) / 0.07, 2.0)) * 0.6 + w * 0.12)
			# 번진 먹 물빛(가장자리 흐림) + 바랜 글씨: 마른 자리는 또렷하되 옅게, 젖은 자리는 흐린 번짐으로
			var bleed := clampf(blur[i] * 2.4, 0.0, 1.0) * w
			c = c.lerp(wash, clampf(w * 0.42 + bleed * 0.6, 0.0, 0.8))
			var sharp := ink[i] * (1.0 - w) * 0.5
			c = c.lerp(inkc, clampf(sharp + bleed * 0.3, 0.0, 0.8))
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	_tex = ImageTexture.create_from_image(img)
	return _tex
