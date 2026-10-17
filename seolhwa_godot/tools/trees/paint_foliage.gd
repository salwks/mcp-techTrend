# 잎 카드 그림(assets/kit/foliage.png) 그리기 — 나무 손질 시험(trees-overhaul) 2026-10-18.
#   godot --headless --path . -s res://tools/trees/paint_foliage.gd            → assets/kit/foliage.png(2048×512, 칸 512 넷)
#   godot --headless --path . -s res://tools/trees/paint_foliage.gd -- preview → 같은 그림 + shots/trees_trial/foliage_preview.png(종이 바탕)
# 칸: 0 솔잎 다발(소나무 근경) · 1 느티 잎송이(톱니 작은 잎) · 2 덤불 잎덩이(둥근 잎) · 3 솔잎 덩이(원경 판 — 빈틈 적은 둥근 덩이)
# RGB = 밝기 배율(꼭짓점 색 = 수종 빛깔에 곱한다, 1 언저리), A = 덮임(셰이더가 0.5에서 자른다).
# 먹선 느낌: 잎·솔잎마다 짙은 밑칠(조금 굵게)을 먼저 깔고 밝은 칠을 얹는다 — 가장자리에 먹빛 테두리가 남는다.
# 결정적: 고정 시드. 2배 크기(1024)로 그린 뒤 줄여 가장자리를 부드럽게 한다.
extends SceneTree

const T := 1024          # 그리는 칸 크기(2배)
const OUT_T := 512
const OUT := "res://assets/kit/foliage.png"
const OUT_RES := "res://assets/kit/foliage.res"   # 밉맵까지 만든 그림(Kit.foliage_texture가 읽는다)

var V := PackedFloat32Array()   # 밝기
var A := PackedFloat32Array()   # 덮임
var W := T * 4
var rng := RandomNumberGenerator.new()

func _init() -> void:
	V.resize(W * T); A.resize(W * T)
	V.fill(0.62); A.fill(0.0)
	rng.seed = 20261018
	_pine_tile(0, 12, 56, false)
	_leaf_tile(1, 170, Vector2(0.12, 0.056), 0.40, true)
	_leaf_tile(2, 210, Vector2(0.085, 0.06), 0.41, false)
	_pine_tile(3, 26, 44, true)
	var img := Image.create(W, T, false, Image.FORMAT_RGBA8)
	for y in T:
		for x in W:
			var i := y * W + x
			var v := V[i]
			# 아주 옅은 따뜻함(밝은 곳) · 서늘함(짙은 곳) — 한지 위 먹·채색 느낌
			img.set_pixel(x, y, Color(clampf(v * 1.02, 0, 1), clampf(v, 0, 1), clampf(v * (0.94 + 0.08 * (1.0 - v)), 0, 1), clampf(A[i], 0, 1)))
	img.resize(W / 2, T / 2, Image.INTERPOLATE_LANCZOS)
	_bleed(img)
	var err := img.save_png(ProjectSettings.globalize_path(OUT))
	var mips := _coverage_mips(img)
	var err2 := ResourceSaver.save(mips, OUT_RES, ResourceSaver.FLAG_COMPRESS)
	print("FOLIAGE saved %s %dx%d err=%d · %s mips=%d err=%d" % [OUT, img.get_width(), img.get_height(), err, OUT_RES, mips.get_mipmap_count(), err2])
	if OS.get_cmdline_user_args().has("preview"):
		var pv := Image.create(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8)
		pv.fill(Color(0.93, 0.9, 0.82))
		var tint := Color(0.42, 0.52, 0.30)
		for y in pv.get_height():
			for x in pv.get_width():
				var c := img.get_pixel(x, y)
				if c.a > 0.5: pv.set_pixel(x, y, Color(c.r * tint.r * 1.6, c.g * tint.g * 1.6, c.b * tint.b * 1.6))
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots/trees_trial"))
		pv.save_png(ProjectSettings.globalize_path("res://shots/trees_trial/foliage_preview.png"))
	quit(0)

# 덮어 칠하기(over): 밝기 v, 덮임 a
func _put(x: int, y: int, v: float, a: float) -> void:
	if x < 0 or y < 0 or x >= W or y >= T or a <= 0.0: return
	var i := y * W + x
	var a0 := A[i]
	var na := a + a0 * (1.0 - a)
	V[i] = (v * a + V[i] * a0 * (1.0 - a)) / maxf(na, 1e-5)
	A[i] = na

# 굵기 w의 선(양 끝 둥글게), 끝으로 갈수록 가늘어짐(taper 0~1)
func _line(p0: Vector2, p1: Vector2, w: float, v: float, a := 1.0, taper := 0.0, lo := 0, hi := 1 << 30) -> void:
	var bb := Rect2(p0, Vector2.ZERO).expand(p1).grow(w)
	var d := p1 - p0
	var L2 := maxf(d.length_squared(), 1e-6)
	for y in range(int(bb.position.y), int(bb.end.y) + 1):
		for x in range(maxi(int(bb.position.x), lo), mini(int(bb.end.x) + 1, hi)):
			var p := Vector2(x + 0.5, y + 0.5)
			var t := clampf((p - p0).dot(d) / L2, 0.0, 1.0)
			var hw := w * 0.5 * (1.0 - taper * t)
			var dist := p.distance_to(p0 + d * t)
			var cov := clampf(hw - dist + 0.5, 0.0, 1.0)
			if cov > 0.0: _put(x, y, v, cov * a)

# 솔잎 다발 칸: 다발 n개(한 다발 needles개) — 가운데에서 바깥·위로 부채꼴. dense=원경용 둥근 덩이
func _pine_tile(tile: int, n: int, needles: int, dense: bool) -> void:
	var ox := tile * T
	var lo := ox + 4; var hi := ox + T - 4
	var c := Vector2(ox + T * 0.5, T * 0.53)
	var centers := []
	for k in n:
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * T * (0.27 if dense else 0.25)
		centers.append(c + Vector2(cos(a) * r * 1.1, sin(a) * r * 0.8))
	_blob(c, T * (0.17 if dense else 0.13), 0.42, lo, hi)
	centers.sort_custom(func(p, q): return p.y > q.y)   # 아래(뒤) 다발부터 — 위 다발이 덮는다
	for ce in centers:
		var cen: Vector2 = ce
		var L := T * (0.15 if dense else 0.2) * rng.randf_range(0.85, 1.15)
		var lines := []
		for i in needles:
			# 위·바깥으로 퍼지는 부채(아래쪽은 짧게)
			var ang := -PI * 0.5 + rng.randf_range(-1.0, 1.0) * PI * 0.92
			var up := -sin(ang)   # 1 = 위
			var len := L * rng.randf_range(0.55, 1.0) * (0.65 + 0.35 * clampf(up + 0.6, 0.0, 1.0))
			var bend := rng.randf_range(-0.18, 0.18)
			var s := cen + Vector2(rng.randf_range(-6, 6), rng.randf_range(-4, 4))
			var e := s + Vector2(cos(ang + bend), sin(ang + bend)) * len
			lines.append([s, e, up])
		# 먹빛 밑칠(굵게) → 밝은 솔잎
		for l in lines: _line(l[0], l[1], 10.0, 0.22, 1.0, 0.5, lo, hi)
		for l in lines:
			var v := 0.78 + 0.28 * clampf(l[2] * 0.5 + 0.5, 0.0, 1.0) + rng.randf_range(-0.08, 0.08)
			if dense: v *= lerpf(1.06, 0.82, clampf((cen.y - T * 0.25) / (T * 0.6), 0.0, 1.0))
			_line(l[0], l[1], 5.2, v, 1.0, 0.6, lo, hi)
		# 다발 밑동(짙은 눈)
		_line(cen - Vector2(5, 0), cen + Vector2(5, 0), 9.0, 0.3, 0.9, 0.0, lo, hi)

# 잎송이 칸: n장, 잎 크기 sz(칸 비율: 길이, 너비), 송이 반지름 rad. serr = 톱니(느티)
func _leaf_tile(tile: int, n: int, sz: Vector2, rad: float, serr: bool) -> void:
	var ox := tile * T
	var lo := ox + 4; var hi := ox + T - 4
	var c := Vector2(ox + T * 0.5, T * 0.52)
	var leaves := []
	for i in n:
		var a := rng.randf() * TAU
		var r := pow(rng.randf(), 0.7) * T * rad
		var p := c + Vector2(cos(a) * r, sin(a) * r * 0.85)
		var out := (p - c).angle() if r > 4.0 else rng.randf() * TAU
		leaves.append([p, out + rng.randf_range(-0.7, 0.7), rng.randf_range(0.8, 1.2), r / (T * rad)])
	_blob(c + Vector2(0, T * 0.03), T * rad * 0.55, 0.32, lo, hi)
	# 잔가지(먹선)
	if serr:
		for k in 5:
			var a := rng.randf() * TAU
			_line(c, c + Vector2(cos(a), sin(a)) * T * rad * 0.8, 5.0, 0.25, 1.0, 0.7, lo, hi)
	leaves.sort_custom(func(p, q): return p[0].y < q[0].y)   # 위쪽 잎을 먼저(뒤) — 아래로 늘어진 잎이 앞으로
	for lf in leaves:
		var p: Vector2 = lf[0]; var ang: float = lf[1]; var k: float = lf[2]
		var L := T * sz.x * k; var Wd := T * sz.y * k
		var up := clampf(0.5 - (p.y - c.y) / (T * rad * 2.0), 0.0, 1.0)   # 송이 위쪽일수록 밝게
		var v := 0.74 + 0.34 * up + rng.randf_range(-0.07, 0.07)
		_leaf(p, ang, L, Wd, v, serr, lo, hi)

func _leaf(p: Vector2, ang: float, L: float, Wd: float, v: float, serr: bool, lo: int, hi: int) -> void:
	var dir := Vector2(cos(ang), sin(ang)); var nrm := Vector2(-dir.y, dir.x)
	var R := L * 0.6 + 4.0
	for y in range(int(p.y - R), int(p.y + R) + 1):
		for x in range(maxi(int(p.x - R), lo), mini(int(p.x + R) + 1, hi)):
			var q := Vector2(x + 0.5, y + 0.5) - p
			var u := q.dot(dir) / L + 0.5            # 0 밑동 → 1 끝
			if u < -0.02 or u > 1.02: continue
			var w := q.dot(nrm)
			var prof := pow(maxf(sin(PI * clampf(u, 0.0, 1.0)), 0.0), 0.75) * (1.0 - 0.35 * u)   # 끝이 뾰족한 달걀꼴
			var half := Wd * 0.5 * prof
			if serr: half *= 1.0 + 0.1 * sin(u * 34.0)  # 톱니
			var dd := half - absf(w)
			if dd < -1.0: continue
			var cov := clampf(dd + 0.5, 0.0, 1.0)
			# 먹빛 테두리(2.2px) · 가운데 잎맥
			var val := v
			if dd < 2.6: val = 0.24
			elif absf(w) < 1.1 and u > 0.08 and u < 0.9: val = v * 0.72
			else: val = v * (0.92 + 0.12 * (absf(w) / maxf(half, 1.0)))   # 가장자리 쪽 조금 밝게(볼륨)
			_put(x, y, val, cov)

# 송이 속 짙은 덩이(잎 사이로 하늘이 덜 보이게 — 붓으로 먼저 깐 짙은 바탕). 가장자리는 잡음으로 들쭉날쭉
func _blob(c: Vector2, r: float, v: float, lo: int, hi: int) -> void:
	var ph := rng.randf() * TAU
	for y in range(int(c.y - r * 1.3), int(c.y + r * 1.3) + 1):
		for x in range(maxi(int(c.x - r * 1.3), lo), mini(int(c.x + r * 1.3) + 1, hi)):
			var q := Vector2(x + 0.5, y + 0.5) - c
			var a := q.angle()
			var rr := r * (1.0 + 0.18 * sin(a * 5.0 + ph) + 0.1 * sin(a * 11.0 - ph))
			var d := rr - q.length()
			if d > -1.0: _put(x, y, v, clampf(d + 0.5, 0.0, 1.0))

# 투명한 곳 색 = 잎 평균 밝기 × 0.8(먼 밉맵에서 잎 가장자리가 검게 번지지 않게)
func _bleed(img: Image) -> void:
	var d := img.get_data()
	var sum := 0.0; var n := 0
	for i in range(0, d.size(), 4):
		if d[i + 3] > 128: sum += d[i + 1]; n += 1
	var avg := int(sum / maxi(n, 1) * 0.8)
	for i in range(0, d.size(), 4):
		if d[i + 3] < 8: d[i] = avg; d[i + 1] = avg; d[i + 2] = int(avg * 0.95)
	img.set_data(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8, d)

# 덮임을 지키는 밉맵: 단계마다 알파 배율 s를 찾아(이분 탐색) 0.5를 넘는 화소 비율을 원본과 같게
func _coverage_mips(base: Image) -> Image:
	var w := base.get_width(); var h := base.get_height()
	var cov0 := _cov(_hist(base), 1.0)
	var all := PackedByteArray(base.get_data())
	var lw := w; var lh := h
	while lw > 1 or lh > 1:
		lw = maxi(1, lw / 2); lh = maxi(1, lh / 2)
		var m: Image = base.duplicate()
		m.resize(lw, lh, Image.INTERPOLATE_BILINEAR if lw >= 64 else Image.INTERPOLATE_NEAREST)
		var hg := _hist(m)
		var lo := 0.5; var hi := 4.0
		for it in 14:
			var mid := (lo + hi) * 0.5
			if _cov(hg, mid) < cov0: lo = mid
			else: hi = mid
		var md := m.get_data()
		for i in range(3, md.size(), 4): md[i] = clampi(int(md[i] * hi), 0, 255)
		all.append_array(md)
	return Image.create_from_data(w, h, true, Image.FORMAT_RGBA8, all)

func _hist(img: Image) -> PackedInt32Array:
	var hg := PackedInt32Array(); hg.resize(256)
	var d := img.get_data()
	for i in range(3, d.size(), 4): hg[d[i]] += 1
	return hg

func _cov(hg: PackedInt32Array, s: float) -> float:
	var c := 0; var all := 0
	var lim := 127.5 / s
	for a in 256:
		all += hg[a]
		if a > lim: c += hg[a]
	return float(c) / maxf(1.0, all)
