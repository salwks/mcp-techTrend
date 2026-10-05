# 밤하늘 한 장(남원 「해와 달이 된 오누이」 v3) — 민화(일월오봉도) 결로 그린 하늘 판. 해와 달을 인물로 그리지 않고, 빛 둘이 자리 잡는 변화만.
#   mode "lights": 땅 쪽(오누이가 오른 자리)에서 빛 둘이 떠올라 왼쪽(붉은 해)·오른쪽(흰 달)에 자리 잡는다(progress 0→1, settle 0→1).
#   mode "look":   다음 날 밤 — 나그네의 뒷모습 실루엣이 밤하늘의 달을 올려다본다(별 몇, 붉은 해의 자리는 비어 있다).
# 이야기 UI(layer 8)보다 한 칸 아래(layer 7)라 자막·대화는 이 판 위에 뜬다. 쓰는 곳: story/namwon/namwon_case.gd
extends CanvasLayer

var mode := "lights"
var progress := 0.0     # 빛이 떠오름
var settle := 0.0       # 자리 잡은 뒤 번짐
var alpha := 0.0        # 판 전체
var _c: Control
var _t := 0.0

const SKY_TOP := Color("#0b1022")
const SKY_LOW := Color("#1d2a44")
const PEAK := Color("#1f3a35")
const PEAK_LINE := Color("#c9d6c4")
const WAVE := Color("#29506a")
const WAVE_LINE := Color("#d8e6ea")
const SUN := Color("#c8322a")
const MOON := Color("#f1ead2")

func _ready() -> void:
	layer = 7
	_c = Control.new()
	_c.set_anchors_preset(Control.PRESET_FULL_RECT)
	_c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_c.draw.connect(_draw_sky)
	add_child(_c)

func _process(dt: float) -> void:
	_t += dt
	_c.queue_redraw()

func _ease(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return 1.0 - pow(1.0 - x, 3.0)

func _draw_sky() -> void:
	if alpha <= 0.001: return
	var s := _c.size
	var a := alpha
	# 하늘(위아래 빛 차이)
	var bands := 24
	for i in bands:
		var t0 := float(i) / bands
		_c.draw_rect(Rect2(0, s.y * t0, s.x, s.y / bands + 1.0), Color(SKY_TOP.lerp(SKY_LOW, t0), a))
	# 별
	var R := RandomNumberGenerator.new(); R.seed = 49
	for i in 70:
		var p := Vector2(R.randf() * s.x, R.randf() * s.y * 0.6)
		var tw := 0.55 + 0.45 * sin(_t * (0.8 + R.randf()) + i)
		_c.draw_circle(p, 1.0 + R.randf() * 1.3, Color(1, 0.97, 0.9, a * 0.55 * tw))
	if mode == "lights": _lights(s, a)
	else: _look(s, a)
	_peaks(s, a)
	if mode == "lights": _waves(s, a)
	else: _figure(s, a)

# 다섯 봉우리(가운데가 높다) — 봉우리마다 둥근 어깨의 산 모양을 겹쳐 위쪽 테두리만 잇는다. 먹빛 면 + 옅은 선
func _peaks(s: Vector2, a: float) -> void:
	var base := s.y * (0.86 if mode == "lights" else 0.9)
	var lift := s.y * 0.06 if mode == "look" else 0.0
	var peaks := [[0.06, 0.60], [0.25, 0.50], [0.5, 0.36], [0.75, 0.50], [0.94, 0.60]]
	var top := PackedVector2Array()
	var n := 96
	for i in n + 1:
		var x := s.x * float(i) / n
		var y := base
		for pk in peaks:
			var px: float = pk[0] * s.x
			var py: float = pk[1] * s.y + lift
			var w := s.x * 0.16
			var u := clampf(absf(x - px) / w, 0.0, 1.0)
			var prof := 1.0 - u * u * (3.0 - 2.0 * u)   # 둥근 어깨(smoothstep)
			y = minf(y, base - (base - py) * prof)
		top.append(Vector2(x, y))
	var poly := top.duplicate()
	poly.append(Vector2(s.x, s.y)); poly.append(Vector2(0, s.y))
	_c.draw_colored_polygon(poly, Color(PEAK, a))
	_c.draw_polyline(top, Color(PEAK_LINE, a * 0.55), 2.0, true)

# 물결(민화 물결 무늬 — 겹친 반원)
func _waves(s: Vector2, a: float) -> void:
	var y0 := s.y * 0.86
	_c.draw_rect(Rect2(0, y0, s.x, s.y - y0), Color(WAVE, a))
	var r := s.x * 0.035
	for row in 4:
		var y := y0 + r * 0.9 * (row + 0.6)
		var off := (r if row % 2 == 1 else 0.0) + fmod(_t * 6.0, r * 2.0)
		var x := -r * 2.0 + off
		while x < s.x + r * 2.0:
			_c.draw_arc(Vector2(x, y), r, PI, TAU, 14, Color(WAVE_LINE, a * 0.6), 2.0, true)
			x += r * 2.0

func _glow(p: Vector2, r: float, col: Color, a: float, pulse: float) -> void:
	for k in 6:
		var rr := r * (1.0 + 0.45 * (k + 1) * (1.0 + pulse * 0.5))
		_c.draw_circle(p, rr, Color(col, a * 0.07 * (6 - k) / 6.0))
	_c.draw_circle(p, r, Color(col, a))
	_c.draw_arc(p, r * 1.12, 0, TAU, 40, Color(col.lightened(0.3), a * 0.6), 2.0, true)

func _lights(s: Vector2, a: float) -> void:
	var e := _ease(progress)
	var start := Vector2(s.x * 0.5, s.y * 0.82)
	var sun_to := Vector2(s.x * 0.27, s.y * 0.2)
	var moon_to := Vector2(s.x * 0.73, s.y * 0.2)
	var r := s.y * 0.055 * (0.35 + 0.65 * e)
	var pulse := sin(_t * 1.6) * 0.5 + 0.5
	# 떠오르는 길(곡선) — 처음엔 한데 모였다가 갈라진다
	var sun_p := start.lerp(sun_to, e) + Vector2(0, -sin(e * PI) * s.y * 0.08)
	var moon_p := start.lerp(moon_to, e) + Vector2(0, -sin(e * PI) * s.y * 0.08)
	var la := a * clampf(progress * 3.0, 0.0, 1.0)
	_glow(sun_p, r, SUN, la, pulse * settle)
	_glow(moon_p, r, MOON, la, pulse * settle)
	if settle > 0.0:   # 자리 잡으며 하늘로 번지는 고리
		for p in [sun_p, moon_p]:
			_c.draw_arc(p, r * (1.4 + settle * 3.0), 0, TAU, 48, Color(1, 0.95, 0.85, a * (1.0 - settle) * 0.5), 2.0, true)

func _look(s: Vector2, a: float) -> void:
	_glow(Vector2(s.x * 0.68, s.y * 0.22), s.y * 0.05, MOON, a, sin(_t * 1.2) * 0.5 + 0.5)

# 나그네 뒷모습(갓·도포·봇짐) — 왼쪽 아래에서 달 쪽을 올려다보는 실루엣
func _figure(s: Vector2, a: float) -> void:
	var k := s.y / 1080.0 * 1.25
	var c := Vector2(s.x * 0.27, s.y * 0.99)
	var ink := Color("#05070c", a)
	var P := func(pts: Array) -> PackedVector2Array:
		var out := PackedVector2Array()
		for q in pts: out.append(c + Vector2(q[0], q[1]) * k)
		return out
	_c.draw_colored_polygon(P.call([[-58, 0], [-44, -120], [-34, -160], [-14, -176], [16, -176], [36, -160], [46, -120], [60, 0]]), ink)   # 도포(어깨에서 아래로 넓게)
	_c.draw_colored_polygon(P.call([[18, -168], [52, -162], [58, -128], [50, -104], [22, -112]]), ink)                                 # 등에 멘 봇짐
	_c.draw_circle(c + Vector2(4, -192) * k, 19 * k, ink)                                                                          # 머리(살짝 젖혀 위를 본다)
	_c.draw_colored_polygon(P.call([[-62, -206], [70, -214], [72, -208], [-60, -199]]), ink)                                         # 갓 양태(기울어진 챙)
	_c.draw_colored_polygon(P.call([[-14, -208], [-10, -236], [22, -238], [26, -211]]), ink)                                         # 갓 모자
