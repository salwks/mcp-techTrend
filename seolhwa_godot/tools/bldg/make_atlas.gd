# 건물 빌더 아틀라스 칸 그리기 — assets/kit/atlas.png·mask.png의 빈 자리(아래 줄 y 384~512, 오른쪽 [768,256,1024,384])에
# 창살·마루·장판·판벽·용마름·잔 기와골·단청 띠·연등천장 무늬를 그린다. 기존 칸(웹에서 내보낸 것)은 건드리지 않는다.
#   godot --headless --path . -s res://tools/bldg/make_atlas.gd
# 아틀라스를 웹에서 다시 내보내면 이 칸들이 지워진다 — 그때 이 스크립트를 다시 돌린다(같은 결과, 결정적).
# 칸 자리는 kit/bldg/_atlas.gd REG와 같아야 한다.
extends SceneTree

const A := preload("res://kit/bldg/_atlas.gd")

var img: Image
var mask: Image

func _init() -> void:
	var ap := ProjectSettings.globalize_path("res://assets/kit/atlas.png")
	var mp := ProjectSettings.globalize_path("res://assets/kit/mask.png")
	img = Image.load_from_file(ap); mask = Image.load_from_file(mp)
	img.convert(Image.FORMAT_RGBA8); mask.convert(Image.FORMAT_RGBA8)
	for k in A.REG:
		var r: Array = A.REG[k]
		mask.fill_rect(Rect2i(r[0], r[1], r[2] - r[0], r[3] - r[1]), Color.BLACK)
		call("_" + k, Rect2i(r[0], r[1], r[2] - r[0], r[3] - r[1]))
	img.save_png(ap); mask.save_png(mp)
	# atlas.json(웹 도구용 표)에도 칸을 적어 둔다
	var jp := ProjectSettings.globalize_path("res://assets/kit/atlas.json")
	var j = JSON.parse_string(FileAccess.get_file_as_string(jp))
	if j is Dictionary:
		for k in A.REG: j.REG["b_" + k] = A.REG[k]
		var f := FileAccess.open(jp, FileAccess.WRITE); f.store_string(JSON.stringify(j)); f.close()
	print("BLDG ATLAS ok ", A.REG.keys())
	quit()

func _h(x: int, y: int, s := 0) -> float:
	var n := (x * 374761393 + y * 668265263 + s * 2147483647) & 0x7fffffff
	n = ((n ^ (n >> 13)) * 1274126177) & 0x7fffffff
	return float(n % 10007) / 10007.0

func _vn(x: float, y: float, s := 0) -> float:
	var xi := floori(x); var yi := floori(y); var fx := x - xi; var fy := y - yi
	var a := _h(xi, yi, s); var b := _h(xi + 1, yi, s); var c := _h(xi, yi + 1, s); var d := _h(xi + 1, yi + 1, s)
	fx = fx * fx * (3 - 2 * fx); fy = fy * fy * (3 - 2 * fy)
	return lerpf(lerpf(a, b, fx), lerpf(c, d, fx), fy)

# 바탕을 색 + 붓 얼룩으로
func _fill(r: Rect2i, c: Color, amp := 0.06, sc := 9.0, s := 1) -> void:
	for y in r.size.y:
		for x in r.size.x:
			var n := _vn(x / sc, y / sc, s) * 0.7 + _vn(x / 2.5, y / 2.5, s + 7) * 0.3
			var d := (n - 0.5) * amp * 2
			img.set_pixel(r.position.x + x, r.position.y + y, Color(c.r + d, c.g + d, c.b + d, 1))

func _rect(r: Rect2i, x0: int, y0: int, w: int, h: int, c: Color, wob := 0.0, glow := -1.0) -> void:
	for y in range(maxi(0, y0), mini(r.size.y, y0 + h)):
		for x in range(maxi(0, x0), mini(r.size.x, x0 + w)):
			var k := 1.0 - wob * _h(x, y, 5)
			img.set_pixel(r.position.x + x, r.position.y + y, Color(c.r * k, c.g * k, c.b * k, 1))
			if glow >= 0.0: mask.set_pixel(r.position.x + x, r.position.y + y, Color(glow, glow, glow, 1))

# 창호지 칸: 종이 바탕은 밤에 빛남(mask 흰색), 살은 검게
func _paper(r: Rect2i) -> void:
	_fill(r, Color(0.94, 0.9, 0.8), 0.04, 7.0, r.position.x)
	for y in r.size.y:
		for x in r.size.x: mask.set_pixel(r.position.x + x, r.position.y + y, Color(0.92, 0.92, 0.92, 1))

const BAR := Color(0.36, 0.26, 0.18)
func _bar(r: Rect2i, x0: int, y0: int, w: int, h: int) -> void:
	_rect(r, x0, y0, w, h, BAR, 0.12, 0.0)

func _frame(r: Rect2i, t := 3) -> void:
	_bar(r, 0, 0, r.size.x, t); _bar(r, 0, r.size.y - t, r.size.x, t)
	_bar(r, 0, 0, t, r.size.y); _bar(r, r.size.x - t, 0, t, r.size.y)

# 띠살: 촘촘한 세로살 + 위·가운데·아래 가로살 세 줄 묶음
func _ddi(r: Rect2i) -> void:
	_paper(r)
	var W := r.size.x; var H := r.size.y
	for i in range(1, 11): _bar(r, int(i * W / 11.0) - 1, 0, 2, H)
	for g in [0.1, 0.5, 0.9]:
		for k in 3: _bar(r, 0, int(g * H) - 6 + k * 5, W, 2)
	_frame(r)

# 용자살: 세로살 하나 + 가로살 몇
func _yong(r: Rect2i) -> void:
	_paper(r)
	var W := r.size.x; var H := r.size.y
	_bar(r, W / 2 - 1, 0, 3, H)
	for i in range(1, 5): _bar(r, 0, int(i * H / 5.0) - 1, W, 3)
	_frame(r)

# 아자살(亞): 칸마다 가운데 십자 + 안쪽 꺾임
func _a(r: Rect2i) -> void:
	_paper(r)
	var W := r.size.x; var H := r.size.y
	var cw := W / 2; var ch := H / 4
	for j in 4:
		for i in 2:
			var x0 := i * cw; var y0 := j * ch
			_bar(r, x0, y0 + ch / 2 - 1, cw, 2); _bar(r, x0 + cw / 2 - 1, y0, 2, ch)
			var q := cw / 4
			_bar(r, x0 + q, y0 + q, cw - 2 * q, 2); _bar(r, x0 + q, y0 + ch - q - 2, cw - 2 * q, 2)
			_bar(r, x0 + q, y0 + q, 2, ch - 2 * q); _bar(r, x0 + cw - q - 2, y0 + q, 2, ch - 2 * q)
	_frame(r)

# 빗살(교살): 두 방향 빗살
func _gyo(r: Rect2i) -> void:
	_paper(r)
	var W := r.size.x; var H := r.size.y
	for y in H:
		for x in W:
			if posmod(x + y, 11) < 2 or posmod(x - y, 11) < 2:
				img.set_pixel(r.position.x + x, r.position.y + y, BAR)
				mask.set_pixel(r.position.x + x, r.position.y + y, Color.BLACK)
	_frame(r)

# 꽃살(절 문): 나무 바탕 빗살 + 꽃잎 점(종이 없음 — 빛나지 않음)
func _kkot(r: Rect2i) -> void:
	_fill(r, Color(0.47, 0.33, 0.22), 0.06, 6.0, 3)
	var W := r.size.x; var H := r.size.y
	for y in H:
		for x in W:
			var u := posmod(x + y, 12); var v := posmod(x - y, 12)
			if u < 2 or v < 2: img.set_pixel(r.position.x + x, r.position.y + y, Color(0.3, 0.21, 0.14))
			var cx := posmod(x, 12) - 6; var cy := posmod(y + 6, 12) - 6
			if cx * cx + cy * cy < 7:
				var pal := [Color(0.72, 0.28, 0.2), Color(0.25, 0.48, 0.42), Color(0.86, 0.72, 0.36)]
				img.set_pixel(r.position.x + x, r.position.y + y, pal[(floori(x / 12.0) + floori(y / 12.0) * 2) % 3])
	_frame(r, 4)

# 우물마루: 긴 귀틀 사이에 짧은 청판을 엇갈려
func _maru(r: Rect2i) -> void:
	_fill(r, Color(0.62, 0.5, 0.38), 0.07, 5.0, 11)
	var W := r.size.x; var H := r.size.y
	for j in 4:
		var y0 := j * H / 4
		_rect(r, 0, y0, W, 3, Color(0.38, 0.27, 0.17), 0.1)   # 장귀틀
		for i in 4:
			var x0 := i * W / 4
			_rect(r, x0, y0, 3, H / 4, Color(0.42, 0.3, 0.2), 0.1)   # 동귀틀
			for k in range(1, 4): _rect(r, x0, y0 + k * H / 16, W / 4, 1, Color(0.55, 0.4, 0.26), 0.1)   # 청판 이음
	# 결
	for y in H:
		for x in W:
			if _h(x / 9, y, 21) < 0.12:
				var c := img.get_pixel(r.position.x + x, r.position.y + y)
				img.set_pixel(r.position.x + x, r.position.y + y, c.darkened(0.08))

# 장판: 기름 먹인 누런 종이 + 네모 이음
func _jangpan(r: Rect2i) -> void:
	_fill(r, Color(0.86, 0.66, 0.36), 0.06, 14.0, 13)
	var W := r.size.x; var H := r.size.y
	for i in range(0, W, 32): _rect(r, i, 0, 1, H, Color(0.66, 0.47, 0.24))
	for j in range(0, H, 32): _rect(r, 0, j, W, 1, Color(0.66, 0.47, 0.24))

# 판벽: 세로 널 + 이음 먹줄
func _panbyeok(r: Rect2i) -> void:
	_fill(r, Color(0.5, 0.37, 0.25), 0.07, 4.0, 17)
	var W := r.size.x; var H := r.size.y
	for i in range(0, W, 16): _rect(r, i, 0, 2, H, Color(0.27, 0.19, 0.13))
	for y in H:
		for x in W:
			if _h(x, y / 7, 23) < 0.1:
				var c := img.get_pixel(r.position.x + x, r.position.y + y)
				img.set_pixel(r.position.x + x, r.position.y + y, c.darkened(0.12))

# 용마름: 엮은 짚 ∧ 무늬(헤링본)
func _yongmareum(r: Rect2i) -> void:
	_fill(r, Color(0.8, 0.7, 0.48), 0.06, 5.0, 19)
	var W := r.size.x; var H := r.size.y
	for y in H:
		for x in W:
			var u := posmod(x + absi(y - H / 2), 10)
			if u < 2: img.set_pixel(r.position.x + x, r.position.y + y, Color(0.52, 0.43, 0.27))
			elif _h(x, y, 29) < 0.1: img.set_pixel(r.position.x + x, r.position.y + y, Color(0.9, 0.82, 0.6))

# 잔 기와골: 수키와 줄(세로) 6줄 + 가로 겹 그늘
func _giwa(r: Rect2i) -> void:
	var W := r.size.x; var H := r.size.y
	for y in H:
		for x in W:
			var cu := fposmod(x, W / 6.0) / (W / 6.0)   # 0..1 골 하나
			var round_ := sin(cu * PI)                   # 수키와 볼록
			var v := 0.55 + 0.38 * pow(round_, 0.6)
			if cu < 0.08 or cu > 0.92: v = 0.36          # 골 그늘
			var cy := fposmod(y, 16.0) / 16.0
			if cy > 0.86: v *= 0.72                        # 겹(아래 끝) 그늘
			v += (_vn(x / 6.0, y / 6.0, 31) - 0.5) * 0.08
			img.set_pixel(r.position.x + x, r.position.y + y, Color(v, v, v * 1.02, 1))

# 단청 띠: 뇌록 바탕 + 끝 머리초(붉은·흰·주황 테)
func _dancheong(r: Rect2i) -> void:
	_fill(r, Color(0.31, 0.5, 0.42), 0.05, 8.0, 37)
	var W := r.size.x; var H := r.size.y
	var bands := [[0, 6, Color(0.6, 0.2, 0.14)], [6, 4, Color(0.92, 0.9, 0.84)], [10, 8, Color(0.85, 0.55, 0.2)], [18, 4, Color(0.92, 0.9, 0.84)], [22, 10, Color(0.24, 0.36, 0.55)]]
	for b in bands:
		_rect(r, b[0], 0, b[1], H, b[2], 0.05)
		_rect(r, W - b[0] - b[1], 0, b[1], H, b[2], 0.05)
	# 가운데 연꽃 점
	for y in H:
		for x in range(40, W - 40):
			var dx := x - W / 2; var dy := posmod(y, 32) - 16
			if dx * dx + dy * dy < 60: img.set_pixel(r.position.x + x, r.position.y + y, Color(0.78, 0.3, 0.24))
	_rect(r, 0, 0, W, 2, Color(0.2, 0.18, 0.15)); _rect(r, 0, H - 2, W, 2, Color(0.2, 0.18, 0.15))

# 연등천장(처마 밑): 둥근 서까래 줄 + 사이 흰 회 앙토
func _soffit(r: Rect2i) -> void:
	var W := r.size.x; var H := r.size.y
	for y in H:
		for x in W:
			var cu := fposmod(x, W / 6.0) / (W / 6.0)
			var c: Color
			if cu < 0.45:
				var s := sin(cu / 0.45 * PI)
				c = Color(0.3, 0.22, 0.15).lerp(Color(0.52, 0.38, 0.25), s)
			else:
				c = Color(0.78, 0.74, 0.66)
			c = c.darkened((_vn(x / 5.0, y / 5.0, 41) - 0.5) * 0.1)
			img.set_pixel(r.position.x + x, r.position.y + y, c)
