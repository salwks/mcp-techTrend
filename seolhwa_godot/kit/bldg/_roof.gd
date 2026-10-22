# 건물 빌더 지붕 — 한 날개(一자 몸채) 지붕을 높이장(heightfield)으로 짓는다.
#   기와: 맞배(gable) · 우진각(hip) · 팔작(hipgable) · 모임(pyramid = 정사각 우진각). 양 끝 꼴을 따로 고른다(ends).
#     - 깊이 방향 칸(s = hd / nzh)과 끝 구역 x 칸을 같은 크기로 두고, 끝 구역 칸의 대각선을 추녀선 쪽으로 잘라
#       추녀(내림) 선이 꼭 삼각형 모서리 위에 오게 한다(선이 칸 안을 가로질러 톱니가 지지 않게).
#     - 팔작: 끝 구역은 min(앞뒤 거리, 옆 거리) 높이 = 아래 우진각, 가운데는 앞뒤 거리만 = 맞배. 둘 사이 수직 틈이 합각벽.
#     - 용마루·내림마루·추녀마루는 같은 높이 함수의 꼭짓점을 따라 놓는다 — 지붕에서 뜨지 않는다(fix-1017 뜬 용마루).
#     - 기와 골은 rect 반복(world UV)으로 0.33m 간격, 처마 끝 막새는 0.28m마다 하나, 처마 밑은 연등천장 무늬 + 서까래 끝.
#   초가: 둥근 모서리 사각 둘레의 등고선 고리(rings)로 — 볼록한 단면, 곧은 용마루 줄 + 용마름, 처마 두께 띠, 서까래 끝, 새끼 그물(선택).
#   좌표: 날개 로컬(지붕 가운데 = 원점 xz, 길이 x, 앞 +z). 반환 { ridge_y, ridge_half, h: 높이 함수(Callable) }
extends RefCounted
const C := preload("res://kit/village/_common.gd")
const A := preload("res://kit/bldg/_atlas.gd")

const TILE_P := 2.0     # 기와 칸 한 장(6골) = 2m
const MAKSE_P := 0.28   # 막새 간격

# 단면: 기와는 오목(처마 쪽 완만), 초가는 볼록
static func prof_giwa(s: float) -> float: return 0.28 * s + 0.72 * s * s
static func prof_thatch(s: float) -> float:
	s = clampf(s, 0, 1)
	return s * (1.5 - 0.5 * s)   # 처마 쪽 조금 가파르고 용마루 쪽 둥근(볼록) 단면

# 삼각형을 want 쪽을 보게(UV 함께)
static func tw(g: Kit.Geo, a: Vector3, b: Vector3, c: Vector3, ua: Vector2, ub: Vector2, uc: Vector2, want: Vector3) -> void:
	if (b - a).cross(c - a).dot(want) < 0.0: g.tri(a, c, b, ua, uc, ub)
	else: g.tri(a, b, c, ua, ub, uc)

# 기와 지붕 -------------------------------------------------------------------------------------------------
# o: hw, hd(처마 반폭·반깊이), eave(처마 높이), rise, thick, lift, ends[왼, 오른]("hip"|"gable"|"hipgable"), hap(팔작 아래 비율),
#    L, D(벽 길이·깊이 — 서까래 자리), lod(0|1|2), buyeon(부연), sag(용마루 처짐 m), cols{top,low,bot,ridge}, dan(단청 빛 서까래)
# 기와 지붕 꼴 준비(끝 구역·칸) — o에 _s·_nzh·_jh·_nzone·_xl·_xr을 적어 둔다
static func giwa_setup(o: Dictionary) -> void:
	if o.has("_xl"): return
	var hw: float = o.hw; var hd: float = o.hd
	var ends: Array = o.get("ends", ["hipgable", "hipgable"])
	var nzh: int = [6, 3, 2][int(o.get("lod", 0))]
	var s := hd / nzh
	var jh := clampi(roundi(float(o.get("hap", 0.45)) * nzh), 1, nzh)
	var nzone := []
	for f in ends: nzone.append(0 if f in ["gable", "open"] else (nzh if f == "hip" else (2 * nzh if f == "corner" else jh)))
	# 짧은 몸채: 두 끝 구역이 겹치면 줄인다(모임지붕 등)
	while (nzone[0] + nzone[1]) * s > 2.0 * hw + 1e-4 and (nzone[0] > 0 or nzone[1] > 0):
		if nzone[0] >= nzone[1]: nzone[0] -= 1
		else: nzone[1] -= 1
	o._s = s; o._nzh = nzh; o._jh = jh; o._nzone = nzone
	o._xl = -hw + nzone[0] * s; o._xr = hw - nzone[1] * s

# 기와 지붕 겉 높이(지붕 로컬). zone: -1 왼끝 구역 · 0 가운데 · 1 오른끝(합각 틈 때문에 구역을 따로 준다), 없으면 x로 고른다
static func giwa_h(o: Dictionary, x: float, z: float, zone := 99) -> float:
	giwa_setup(o)
	var hw: float = o.hw; var hd: float = o.hd
	if zone == 99: zone = -1 if x < float(o._xl) else (1 if x > float(o._xr) else 0)
	var ends: Array = o.get("ends", ["hipgable", "hipgable"])
	if zone != 0 and ends[0 if zone < 0 else 1] == "corner":
		# 회첨(ㄱ·ㄷ자 모퉁이): 몸채 비탈 Pm(z)과 날개 비탈 Pw(u)가 만난다. 날개는 앞(+z)으로 뻗고 u>0이 바깥.
		#   뒤·바깥: 추녀(낮은 쪽) · 앞·바깥: 날개 비탈 · 뒤·안: 몸채 비탈 · 앞·안: 회첨골(높은 쪽)
		var u: float = (x - (hw - hd)) if zone > 0 else -(x + (hw - hd))
		var pm: float = float(o.eave) + float(o.rise) * prof_giwa(maxf(hd - absf(z), 0.0) / hd)
		var pw: float = float(o.eave) + float(o.rise) * prof_giwa(maxf(hd - absf(u), 0.0) / hd)
		if u >= 0.0: return minf(pm, pw) if z <= 0.0 else pw
		return pm if z <= 0.0 else maxf(pm, pw)
	var dz := hd - absf(z)
	var e := dz
	if zone != 0: e = minf(dz, hw - absf(x))
	e = maxf(e, 0.0)
	var sn := e / hd
	var y: float = float(o.eave) + float(o.rise) * prof_giwa(sn)
	var lx := absf(x) / hw; var lz := absf(z) / hd
	var le: Array = o.get("lift_ends", [1.0, 1.0])
	if ends[0] in ["open", "corner"]: le = [0.0, le[1]]
	if ends[1] in ["open", "corner"]: le = [le[0], 0.0]
	y += float(o.get("lift", 0.45)) * float(le[0 if x < 0.0 else 1]) * maxf(pow(lx, 3) * smoothstep(0.5, 1.0, lz), pow(lz, 3) * smoothstep(0.5, 1.0, lx))
	y -= float(o.get("sag", 0.0)) * (1.0 - lx * lx) * sn
	return y

static func giwa(m: C.M, part: String, o: Dictionary) -> Dictionary:
	var hw: float = o.hw; var hd: float = o.hd; var eave: float = o.eave; var rise: float = o.rise
	var thick: float = o.get("thick", 0.22); var lod: int = o.get("lod", 0)
	var ends: Array = o.get("ends", ["hipgable", "hipgable"])
	giwa_setup(o)
	var nzh: int = o._nzh; var s: float = o._s; var jh: int = o._jh; var nzone: Array = o._nzone
	var xl: float = o._xl; var xr: float = o._xr
	# clip(x, z): 이 높이 위로는 올라가지 않는다(ㄱ·ㄷ자 몸채를 날개 지붕 밑으로 — 회첨골을 정확히, 박공이 날개 위로 뚫고 나오지 않게)
	var clip = o.get("clip")
	var H := func(x: float, z: float, zone: int) -> float:
		var y := giwa_h(o, x, z, zone)
		if clip is Callable: y = minf(y, (clip as Callable).call(x, z))
		return y
	var zs := []
	for i in 2 * nzh + 1: zs.append(-hd + i * s)
	var top := Kit.Geo.new(); var bot := Kit.Geo.new(); var band := Kit.Geo.new(); var verge := Kit.Geo.new()
	var col_t: Color = Kit.hex(o.get("c_top", 0x8f9296)); var col_l: Color = Kit.hex(o.get("c_low", 0x6d7176))
	# 구역: [x 목록, zone(-1 왼끝, 0 가운데, 1 오른끝), 끝 꼴]
	var zones := []
	if nzone[0] > 0:
		var xs := []
		for k in nzone[0] + 1: xs.append(-hw + k * s)
		zones.append([xs, -1])
	var nm := maxi(1, ceili((xr - xl) / ([1.3, 3.0, 6.0][lod])))
	if xr - xl > 1e-4:
		var xs := []
		for k in nm + 1: xs.append(lerpf(xl, xr, float(k) / nm))
		zones.append([xs, 0])
	if nzone[1] > 0:
		var xs := []
		for k in nzone[1] + 1: xs.append(xr + k * s)
		zones.append([xs, 1])
	for zn in zones:
		var xs: Array = zn[0]; var zone: int = zn[1]
		for i in xs.size() - 1:
			for j in zs.size() - 1:
				var x0: float = xs[i]; var x1: float = xs[i + 1]; var z0: float = zs[j]; var z1: float = zs[j + 1]
				var p00 := Vector3(x0, H.call(x0, z0, zone), z0); var p10 := Vector3(x1, H.call(x1, z0, zone), z0)
				var p01 := Vector3(x0, H.call(x0, z1, zone), z1); var p11 := Vector3(x1, H.call(x1, z1, zone), z1)
				var front := (z0 + z1) > 0.0
				var main_diag := true
				if zone != 0 and ends[0 if zone < 0 else 1] == "corner":
					main_diag = zone < 0   # 추녀(뒤·바깥)·회첨골(앞·안) 모두 같은 대각선 방향
				elif zone == 1: main_diag = front
				elif zone == -1: main_diag = not front
				var tris := [[p00, p10, p11], [p00, p11, p01]] if main_diag else [[p00, p10, p01], [p10, p11, p01]]
				for t in tris: _roof_tri(top, bot, t[0], t[1], t[2], thick, col_t, col_l, eave, rise)
		# 처마 끝 띠(막새) · 박공 끝(verge)
		var is_corner: bool = zone != 0 and ends[0 if zone < 0 else 1] == "corner"
		for i in xs.size() - 1:
			for zz in [-hd, hd]:
				if is_corner and zz > 0.0: continue   # 앞 끝은 날개 지붕으로 이어진다(띠 없음)
				var x0: float = xs[i]; var x1: float = xs[i + 1]
				_band(band, Vector3(x0, H.call(x0, zz, zone), zz), Vector3(x1, H.call(x1, zz, zone), zz), thick, Vector3(0, 0, signf(zz)))
		if zone != 0:
			var xe: float = -hw if zone == -1 else hw
			for j in zs.size() - 1:
				var z0: float = zs[j]; var z1: float = zs[j + 1]
				_band(band, Vector3(xe, H.call(xe, z0, zone), z0), Vector3(xe, H.call(xe, z1, zone), z1), thick, Vector3(signf(xe), 0, 0))
	# 맞배 끝: 박공 널(verge) — 가운데 구역 끝이 x=±hw일 때
	for sd in [-1, 1]:
		var f: String = ends[0 if sd < 0 else 1]
		if f != "gable": continue
		var xe: float = sd * hw
		for j in zs.size() - 1:
			var z0: float = zs[j]; var z1: float = zs[j + 1]
			var a := Vector3(xe, H.call(xe, z0, 0), z0); var b := Vector3(xe, H.call(xe, z1, 0), z1)
			_verge(verge, a, b, thick + 0.12, Vector3(sd, 0, 0))
	A.add_tiled(m, part, "giwa", top, 0.05 if lod < 2 else 0.0)
	if lod < 2: A.add_tiled(m, part, "soffit", bot, 0.0)
	else: m.add(part, "flat", bot, 0.0)
	A.add_tiled(m, part, "makse", band, 0.0)
	if verge.size() > 0: m.add(part, "flat", C.P(verge, 0x4a3a2c, 0x3a2d22, 0.02), 0.02 if lod == 0 else 0.0)
	# 합각벽(팔작 끝 위 세모)
	for zn in zones:
		if zn[1] == 0: continue
		var f: String = ends[0 if zn[1] < 0 else 1]
		if f != "hipgable": continue
		var xg: float = xl if zn[1] < 0 else xr
		var yb: float = H.call(xg, hd - jh * s, zn[1])
		var g := Kit.Geo.new()
		var pts := []
		for z in zs:
			if absf(z) <= hd - jh * s + 1e-4: pts.append(Vector3(xg, H.call(xg, z, 0), z))
		var base_y := yb - 0.02
		for k in pts.size() - 1:
			var a: Vector3 = pts[k]; var b: Vector3 = pts[k + 1]
			if a.y < base_y + 0.01 and b.y < base_y + 0.01: continue   # 합각 끝 납작한 조각(접힘) 빼기
			a.y = maxf(a.y, base_y + 0.005); b.y = maxf(b.y, base_y + 0.005)
			var a0 := Vector3(xg, base_y, a.z); var b0 := Vector3(xg, base_y, b.z)
			var want := Vector3(signf(xg), 0, 0)
			tw(g, a0, b0, b, Vector2(a.z / 2.0, 1), Vector2(b.z / 2.0, 1), Vector2(b.z / 2.0, 0), want)
			tw(g, a0, b, a, Vector2(a.z / 2.0, 1), Vector2(b.z / 2.0, 0), Vector2(a.z / 2.0, 0), want)
		A.add(m, part, "panbyeok", C.P(g, 0x8a7258, 0x6a5440, 0.03), 0.0)
		# 합각 박공 널(세모 위 두 변)
		if lod < 2:
			for k in pts.size() - 1:
				var a: Vector3 = pts[k] + Vector3(signf(xg) * 0.04, 0.02, 0); var b: Vector3 = pts[k + 1] + Vector3(signf(xg) * 0.04, 0.02, 0)
				m.add(part, "wood", C.P(C.beam(a, b, 0.08, 0.2), 0x4a3a2c, 0x3a2d22, 0.02), 0.012 if lod == 0 else 0.0)
	# 용마루 · 마루들
	var ridge_y: float = H.call(0.0, 0.0, 0)
	var rc: Array = o.get("ridge_col", [0x3d3f42, 0x2d2e30])
	var rxl := xl; var rxr := xr
	if ends[0] == "gable": rxl = -hw - 0.05
	if ends[1] == "gable": rxr = hw + 0.05
	if ends[0] == "open": rxl = -hw
	if ends[1] == "open": rxr = hw
	if ends[0] == "corner": rxl = -(hw - hd)
	if ends[1] == "corner": rxr = hw - hd
	var rpts := []
	var nr := maxi(1, ceili((rxr - rxl) / 1.5)) if lod == 0 else 1
	for k in nr + 1:
		var x := lerpf(rxl, rxr, float(k) / nr)
		# 모퉁이 구역 안의 용마루 점만 그 구역 높이로, 나머지(맞배·트인 끝 내민 점 포함)는 가운데 구역 높이로
		var zx := 0
		if x < xl - 1e-4 and ends[0] == "corner": zx = -1
		elif x > xr + 1e-4 and ends[1] == "corner": zx = 1
		rpts.append(Vector3(x, H.call(x if zx != 0 else clampf(x, xl, xr), 0.0, zx), 0))
	var rw: float = 0.36 if lod < 2 else 0.4
	for k in rpts.size() - 1:
		var a: Vector3 = rpts[k]; var b: Vector3 = rpts[k + 1]
		var g := C.beam(a + Vector3(0, -0.05, 0), b + Vector3(0, -0.05, 0), rw, 0.62)
		m.add(part, "flat", C.P(g, rc[0], rc[1], 0.02), 0.03 if lod < 2 else 0.0)
		if lod == 0:
			m.add(part, "flat", C.P(C.beam(a + Vector3(0, 0.3, 0), b + Vector3(0, 0.3, 0), rw * 0.62, 0.1), 0x55585c, 0x45474a, 0.02), 0.0)
	if lod == 0:
		# 망와(용마루 끝을 치켜든 기와)
		for sd in [-1, 1]:
			if ends[0 if sd < 0 else 1] in ["open", "corner"]: continue
			var e: Vector3 = rpts[0] if sd < 0 else rpts[rpts.size() - 1]
			m.add(part, "flat", C.P(Kit.xf(Kit.box(0.42, 0.34, rw * 0.95), e.x + sd * 0.12, e.y + 0.3, 0, 0, 0, -sd * 0.6), rc[0], rc[1], 0.02), 0.03)
	# 내림·추녀마루
	var hips := []
	for sd in [-1, 1]:
		var f: String = ends[0 if sd < 0 else 1]
		var zone := -1 if sd < 0 else 1
		var xe: float = xl if sd < 0 else xr
		var nz: int = nzone[0] if sd < 0 else nzone[1]
		if f == "open": continue
		if f == "corner":
			# 모퉁이: 날개 쪽 용마루(가운데 → 앞) + 추녀마루(가운데 → 뒤·바깥 모서리)
			var xc: float = sd * (hw - hd)
			var l1 := []; var l2 := []
			for j in nzh + 1:
				l1.append(Vector3(xc, H.call(xc, j * s, zone), j * s))
				var xx: float = xc + sd * j * s
				l2.append(Vector3(xx, H.call(xx, -j * s, zone), -j * s))
			hips.append(l1); hips.append(l2)
			continue
		if f == "gable":
			for zsgn in [-1, 1]:
				var line := []
				for j in nzh + 1:
					var z: float = zsgn * maxf(j * s, 0.2)   # 용마루 밑에서 시작(두 비탈 마루가 가운데서 겹치지 않게)
					line.append(Vector3(sd * (hw - 0.12), H.call(sd * (hw - 0.12), z, 0), z))
				hips.append(line)
		else:
			for zsgn in [-1, 1]:
				var line := []
				if f == "hipgable":
					for j in nzh - jh + 1:   # 합각 박공선(내림마루): 용마루 끝에서 합각 아래 끝까지
						var z: float = zsgn * maxf(j * s, 0.2)
						line.append(Vector3(xe, H.call(xe, z, 0), z))
					hips.append(line); line = []
				# 추녀마루: 끝 구역 대각선 위 꼭짓점
				for k in nz + 1:
					var x: float = xe + sd * k * s
					var z: float = zsgn * (hd - nz * s + k * s)
					line.append(Vector3(x, H.call(x, z, zone), z))
				hips.append(line)
	if lod < 2:
		for line in hips:
			for k in line.size() - 1:
				var a: Vector3 = line[k]; var b: Vector3 = line[k + 1]
				m.add(part, "flat", C.P(C.beam(a + Vector3(0, 0.06, 0), b + Vector3(0, 0.06, 0), 0.24, 0.3), rc[0], rc[1], 0.02), 0.02 if lod == 0 else 0.0)
	# 서까래 끝(처마 밑) · 부연 · 추녀
	if lod == 0 and o.get("rafters", true):
		_giwa_rafters(m, part, o, H, nzone, s, xl, xr)
	return { ridge_y = ridge_y, ridge_half = (rxr - rxl) / 2.0, h = H, xl = xl, xr = xr }

static func _roof_tri(top: Kit.Geo, bot: Kit.Geo, a: Vector3, b: Vector3, c: Vector3, thick: float, col_t: Color, col_l: Color, eave: float, rise: float) -> void:
	var n := (b - a).cross(c - a)
	if n.length_squared() < 1e-10: return
	if n.y < 0:
		var t := b
		b = c
		c = t
	n = (b - a).cross(c - a).normalized()
	var side := absf(n.x) > absf(n.z)
	var uvf := func(p: Vector3) -> Vector2:
		# 기와 골이 비탈 아래로 서게: 앞뒤 면은 u = x, 옆(추녀) 면은 u = z
		return Vector2(p.z / TILE_P, -p.x * 1.1 / TILE_P) if side else Vector2(p.x / TILE_P, (p.z if n.z > 0 else -p.z) * 1.1 / TILE_P)
	var base := top.pos.size()
	top.tri(a, b, c, uvf.call(a), uvf.call(b), uvf.call(c))
	for q in 3:
		var t := clampf((top.pos[base + q].y - eave) / maxf(rise, 0.01), 0, 1)
		top.col[base + q] = col_l.lerp(col_t, t)
	var dn := Vector3(0, -thick, 0)
	var ub := func(p: Vector3) -> Vector2: return Vector2(p.z / 2.0, p.x / 2.0) if side else Vector2(p.x / 2.0, p.z / 2.0)
	var b0 := bot.pos.size()
	bot.tri(a + dn, c + dn, b + dn, ub.call(a), ub.call(c), ub.call(b))
	for q in 3: bot.col[b0 + q] = Kit.hex(0xb8ab98)

# 처마 끝 두께 띠: a→b(지붕 겉 가장자리), 아래로 thick, 바깥 want
static func _band(g: Kit.Geo, a: Vector3, b: Vector3, thick: float, want: Vector3) -> void:
	var dn := Vector3(0, -thick, 0)
	var l := a.distance_to(b)
	var u0 := (a.x + a.z) / MAKSE_P; var u1 := u0 + l / MAKSE_P
	tw(g, a + dn, b + dn, b, Vector2(u0, 1), Vector2(u1, 1), Vector2(u1, 0), want)
	tw(g, a + dn, b, a, Vector2(u0, 1), Vector2(u1, 0), Vector2(u0, 0), want)

# 박공 널: 맞배 끝 지붕 가장자리를 따라 두꺼운 널
static func _verge(g: Kit.Geo, a: Vector3, b: Vector3, h: float, want: Vector3) -> void:
	var dn := Vector3(0, -h, 0); var o := want * 0.04
	C.qf(g, a + dn + o, b + dn + o, b + o + Vector3(0, 0.03, 0), a + o + Vector3(0, 0.03, 0), want)

static func _giwa_rafters(m: C.M, part: String, o: Dictionary, H: Callable, nzone: Array, s: float, xl: float, xr: float) -> void:
	var L: float = o.L; var D: float = o.D; var hw: float = o.hw; var hd: float = o.hd; var thick: float = o.get("thick", 0.22)
	var ends: Array = o.get("ends", ["hipgable", "hipgable"])
	var g := Kit.Geo.new(); var gb := Kit.Geo.new(); var gc := Kit.Geo.new()
	var r := 0.065; var sp := 0.34
	var buyeon: bool = o.get("buyeon", false)
	var zone_of := func(x: float) -> int: return -1 if x < xl else (1 if x > xr else 0)
	var under := func(x: float, z: float) -> float: return H.call(x, z, zone_of.call(x)) - thick - r - 0.01
	# 앞·뒤 처마
	var x0: float = float(o.get("wx0", -L / 2)) + 0.25; var x1: float = float(o.get("wx1", L / 2)) - 0.25
	var n := maxi(2, int((x1 - x0) / sp))
	for k in n + 1:
		var x := lerpf(x0, x1, float(k) / n)
		for zs in [-1, 1]:
			var zw: float = zs * (D / 2 - 0.1); var ze: float = zs * (hd - (0.45 if buyeon else 0.08))
			var a := Vector3(x, under.call(x, zw), zw); var b := Vector3(x, under.call(x, ze), ze)
			_rod(g, a, b, r)
			if buyeon:
				var bz0: float = zs * (hd - 0.55); var bz1: float = zs * (hd - 0.05)
				var ba := Vector3(x, under.call(x, bz0) + r + 0.02, bz0); var bb := Vector3(x, under.call(x, bz1) + r + 0.02, bz1)
				_box_into(gb, ba, bb, 0.1, 0.1)
	# 옆 처마(우진각·팔작 끝) — 맞배 끝은 박공이라 없음
	for sd in [-1, 1]:
		if ends[0 if sd < 0 else 1] in ["gable", "open", "corner"]: continue
		var zn := maxi(2, int((D - 0.5) / sp))
		for k in zn + 1:
			var z := lerpf(-D / 2 + 0.25, D / 2 - 0.25, float(k) / zn)
			var xw: float = sd * (L / 2 - 0.1); var xe: float = sd * (hw - (0.45 if buyeon else 0.08))
			_rod(g, Vector3(xw, under.call(xw, z), z), Vector3(xe, under.call(xe, z), z), r)
		# 추녀(모서리 굵은 각재)
		for zs in [-1, 1]:
			var a := Vector3(sd * L / 2, under.call(sd * L / 2 * 0.98, zs * D / 2 * 0.98) - 0.05, zs * D / 2)
			var cx: float = sd * (hw - 0.1); var cz: float = zs * (hd - 0.1)
			var b := Vector3(cx, under.call(cx, cz) + 0.02, cz)
			_box_into(gc, a, b, 0.2, 0.22)
	var wc: Array = o.get("rafter_col", [0x6b5038, 0x4d3826])
	m.add(part, "wood", C.P(g, wc[0], wc[1], 0.03), 0.012)
	if gb.size() > 0: m.add(part, "wood", C.P(gb, wc[0], wc[1], 0.03), 0.01)
	m.add(part, "wood", C.P(gc, wc[0], wc[1], 0.03), 0.015)

# 둥근 서까래(6각 막대, 앞 끝 마구리 포함)
static func _rod(g: Kit.Geo, a: Vector3, b: Vector3, r: float) -> void:
	var c := Kit.limb(a, b, r, r, 6)
	g.pos.append_array(c.pos); g.uv.append_array(c.uv); g.col.append_array(c.col)

static func _box_into(g: Kit.Geo, a: Vector3, b: Vector3, w: float, h: float) -> void:
	var c := C.beam(a, b, w, h)
	g.pos.append_array(c.pos); g.uv.append_array(c.uv); g.col.append_array(c.col)

# 초가 지붕 -------------------------------------------------------------------------------------------------
# 둥근 모서리 우진각(이엉). o: hw, hd, eave, rise, rc(모서리 반지름), thick(이엉 두께 띠 0.3), lod, L, D, wear, cols, net(새끼 그물 줄 수)
#   2026-10-21 rollout ②(김홍도·김득신·신윤복·김준근 초가 장면 — building_refs.json choga): 이엉이 한 덩이로 읽히지 않게
#   seed      변주 씨앗(무늬·띠·덧이엉·처마 끝)
#   bulge     단면 볼록함(0.2 납작 ~ 0.8 둥글게 부푼) — 프로필 s(1 + b − b s)
#   hip_k     옆(합각 쪽) 비탈 기울기 배율(처마 내밀기 ov 안쪽은 그대로 — 벽 위 여유 규칙). 크면 용마루가 짧고 둥근 집, 작으면 용마루가 긴 집
#   sag       용마루 가운데 처짐(m)
#   bands     켜 띠(이엉을 해마다 아래부터 덮어 올린 켜 — 켜마다 0.06m 턱 + 짧은 처마 그림자)
#   patch     덧이엉(새 짚으로 기운 자리) 수 0~3 — 묵은 지붕 위 금빛 조각(0.03m 위)
#   edge      "ragged"(묵은 이엉 처마 끝 들쭉날쭉 + 짚 끝 술) | "combed"(새로 다듬은 처마: 고른 선 + 얕은 물결)
# 안쪽 거리 e(둥근 사각 둘레에서 안으로)의 등고선이 고리. e = hd에서 용마루 선.
static func _hn(a: float, b: float, s: float) -> float:
	var v := sin(a * 12.9898 + b * 78.233 + s * 37.719) * 43758.5453
	return v - floorf(v)

# 둘레 각 θ의 주기 무늬(0~1) — 정수 진동수라 둘레를 돌아 이어진다
static func _per(th: float, s: float, k1: int, k2: int) -> float:
	return 0.5 + 0.3 * sin(th * k1 + s * 1.7) + 0.2 * sin(th * k2 + s * 4.1)

static func thatch(m: C.M, part: String, o: Dictionary) -> Dictionary:
	var hw: float = o.hw; var hd: float = o.hd; var eave: float = o.eave; var rise: float = o.rise
	var rc: float = minf(o.get("rc", 1.1), hd * 0.95); var lod: int = o.get("lod", 0)
	var thick: float = o.get("thick", 0.32)
	var sd: float = float(o.get("seed", 1)) * 0.618
	var bulge: float = clampf(float(o.get("bulge", 0.5)), 0.15, 0.85)
	var e0: float = maxf(float(o.get("ov", 0.8)), 0.2)
	var hk_max: float = (hw - 0.35 - e0) / maxf(hd - e0, 0.1)
	var hk: float = clampf(float(o.get("hip_k", 1.0)), 0.7, maxf(1.0, hk_max))
	var sag: float = float(o.get("sag", 0.0))
	var wear: float = o.get("wear", 0.3)
	var nr: int = [9, 4, 2][lod]
	var nside_x := maxi(1, ceili((hw - rc) / ([0.9, 2.0, 4.0][lod])))
	var nside_z := maxi(1, ceili((hd - rc) / ([0.9, 2.0, 4.0][lod])))
	var narc: int = [4, 2, 1][lod]
	var cols: Array = o.get("cols", C.THATCH)
	var prof := func(t: float) -> float:
		t = clampf(t, 0, 1)
		return t * (1.0 + bulge - bulge * t)
	var Hf := func(e: float) -> float: return eave + rise * prof.call(e / hd)
	var ex := func(e: float) -> float: return e if e <= e0 else e0 + (e - e0) * hk   # 옆 비탈 배율(처마 안쪽만)
	# 고리 점: 둥근 사각(반폭 a, b, 반지름 r)의 둘레 점 — 사분면마다 [z변 절반, 호, x변 절반]
	var ring := func(e: float, sharp := false) -> Array:
		var a := maxf(hw - ex.call(e), 0.0); var b := maxf(hd - e, 0.0); var r := 0.0 if sharp else maxf(rc - e, 0.0)
		r = minf(r, minf(a, b))
		var P := []
		for k in nside_z: P.append(Vector2(a, (b - r) * k / nside_z))
		for k in narc:
			var t := PI / 2 * k / narc
			P.append(Vector2(a - r + r * cos(t), b - r + r * sin(t)))
		for k in nside_x: P.append(Vector2((a - r) * (1.0 - float(k) / nside_x), b))
		var Q := P.slice(1)
		var Qr := Q.duplicate(); Qr.reverse()
		var pts := P.duplicate()
		pts.append(Vector2(0, b))
		for p in Qr: pts.append(Vector2(-p.x, p.y))
		pts.append(Vector2(-a, 0))
		for p in Q: pts.append(Vector2(-p.x, -p.y))
		pts.append(Vector2(0, -b))
		for p in Qr: pts.append(Vector2(p.x, -p.y))
		return pts
	# 켜 띠: 어느 고리에서 위 켜가 시작하나(씨앗마다 자리 다르게)
	var bands := {}
	if lod == 0 and bool(o.get("bands", true)):
		var pick := [[2, 4, 6], [2, 5, 7], [3, 5, 7], [2, 4, 7], [3, 6]]
		for k in pick[int(_hn(sd, 3.0, 1.0) * pick.size()) % pick.size()]: bands[k] = true
	var STEP := 0.06
	var rings := []
	for k in nr + 1:
		var e := hd * float(k) / nr
		if k == nr: e = hd - 1e-4
		var pts: Array = ring.call(e)
		# 고리 울퉁불퉁(묵은 이엉일수록): 처마·용마루 고리는 그대로
		if k > 0 and k < nr and lod == 0:
			var amp := 0.012 + 0.02 * wear
			for i in pts.size():
				var p: Vector2 = pts[i]
				var L2 := p.length()
				if L2 > 0.01: pts[i] = p + p / L2 * (_hn(float(i), float(k), sd) - 0.5) * amp * 2.0
		rings.append([pts, Hf.call(e), e])
	# 처마 처짐(droop, 면마다 m — building._thatch_droop): 벽 줄(e0) 밖 띠만 끝으로 갈수록 내린다 — 벽 줄 안 지붕은 그대로.
	#   ㄱ·ㄷ 이음(회첨) 가까이(다른 날개 방 위 0.7m 안)는 처지지 않고 2.8m에 걸쳐 되살아난다(처진 띠가 이웃 날개를 뚫지 않게)
	var drp: Dictionary = o.get("droop", {})
	var hide0 = o.get("hide_under")
	var dmax := 0.0
	for kk in drp: dmax = maxf(dmax, float(drp[kk]))
	var rdd := []
	for k in rings.size():
		var pts: Array = rings[k][0]; var e: float = rings[k][2]
		var arr := PackedFloat32Array(); arr.resize(pts.size())
		if dmax > 0.001 and e < e0:
			var wv := pow(1.0 - e / e0, 1.4)
			for q in pts.size():
				var p: Vector2 = pts[q]
				var ang := atan2(absf(p.y) * hw, absf(p.x) * hd) / (PI / 2)
				var sb := smoothstep(0.35, 0.65, ang)
				var dv := lerpf(float(drp.get("xp" if p.x > 0 else "xn", 0.0)), float(drp.get("zp" if p.y > 0 else "zn", 0.0)), sb)
				if hide0 is Callable and dv > 0.0:
					var f := 1.0
					for r in [0.0, 0.7, 1.4, 2.1, 2.8]:
						if (hide0 as Callable).call(p.x + r, p.y) or (hide0 as Callable).call(p.x - r, p.y) or (hide0 as Callable).call(p.x, p.y + r) or (hide0 as Callable).call(p.x, p.y - r):
							f = clampf((r - 0.7) / 2.1, 0.0, 1.0); break
					dv *= f
				arr[q] = dv * wv
		rdd.append(arr)
	var top := Kit.Geo.new(); var bot := Kit.Geo.new()
	var lips := Kit.Geo.new()   # 켜 턱(짧은 처마)
	var n: int = (rings[0][0] as Array).size()
	var ridge_half := maxf(hw - ex.call(hd), 0.3)
	var sagf := func(x: float, e: float) -> float: return sag * pow(clampf(e / hd, 0, 1), 2.0) * (1.0 - clampf(pow(x / maxf(hw, 0.5), 2.0), 0, 1))
	for k in nr:
		var r0: Array = rings[k][0]; var r1: Array = rings[k + 1][0]
		var e0k: float = rings[k][2]; var e1: float = rings[k + 1][2]
		var y0: float = float(rings[k][1]) + (STEP if bands.has(k) else 0.0)
		var y1: float = rings[k + 1][1]
		var dd0: PackedFloat32Array = rdd[k]; var dd1: PackedFloat32Array = rdd[k + 1]
		for i in n:
			var i2 := (i + 1) % n
			var a := Vector3(r0[i].x, y0 - sagf.call(r0[i].x, e0k) - dd0[i], r0[i].y); var b := Vector3(r0[i2].x, y0 - sagf.call(r0[i2].x, e0k) - dd0[i2], r0[i2].y)
			var c := Vector3(r1[i2].x, y1 - sagf.call(r1[i2].x, e1) - dd1[i2], r1[i2].y); var d := Vector3(r1[i].x, y1 - sagf.call(r1[i].x, e1) - dd1[i], r1[i].y)
			# 이엉 결: u = 둘레 쪽, v = 비탈(안쪽 거리)
			var ua := Vector2(_tu(a), e0k / 1.6); var ub := Vector2(_tu(b), e0k / 1.6); var uc := Vector2(_tu(c), e1 / 1.6); var ud := Vector2(_tu(d), e1 / 1.6)
			if absf(ub.x - ua.x) > 2.0: ub.x = ua.x + 0.3
			if absf(uc.x - ud.x) > 2.0: uc.x = ud.x + 0.3
			tw(top, a, b, c, ua, ub, uc, Vector3.UP)
			tw(top, a, c, d, ua, uc, ud, Vector3.UP)
			if bands.has(k):
				# 켜 턱: 위 켜 시작(y0) → 아래 켜 위로 조금 나와(3.5cm) 내려옴 — 켜 사이 짧은 그림자
				var oa := Vector3(r0[i].x, 0, r0[i].y).normalized() * 0.035; var ob := Vector3(r0[i2].x, 0, r0[i2].y).normalized() * 0.035
				var ya := y0 - STEP - 0.015; var yb := y0 - STEP - 0.015
				var la := Vector3(a.x + oa.x, ya - sagf.call(r0[i].x, e0k) - dd0[i], a.z + oa.z); var lb := Vector3(b.x + ob.x, yb - sagf.call(r0[i2].x, e0k) - dd0[i2], b.z + ob.z)
				var out := Vector3(a.x + b.x, 0.3, a.z + b.z)
				tw(lips, la, lb, b, Vector2(_tu(a), 0.3), Vector2(_tu(a) + a.distance_to(b) / 1.2, 0.3), Vector2(_tu(a) + a.distance_to(b) / 1.2, 0.0), out)
				tw(lips, la, b, a, Vector2(_tu(a), 0.3), Vector2(_tu(a) + a.distance_to(b) / 1.2, 0.0), Vector2(_tu(a), 0.0), out)
	# 처마 두께 띠 + 밑면 — 밑면 안쪽 고리는 벽·기둥 줄 바로 바깥(e_in)에서 벽 윗면 + 0.08m(벽이 이엉 밑면을 뚫지 않게)
	var r0: Array = rings[0][0]
	var e_in: float = maxf(float(o.get("ov", 0.8)) - 0.06, 0.1)
	var rin: Array = ring.call(e_in, true)   # 모서리 날카롭게 — 둥근 고리는 벽 모서리 안으로 파고든다
	var y_in: float = maxf(float(o.get("wall_top", eave - thick)) + 0.08, eave - thick + 0.05)
	var lip := Kit.Geo.new(); var tufts := Kit.Geo.new()
	var ragged: bool = String(o.get("edge", "ragged")) == "ragged"
	var grow := 1.0 + 0.03
	# 처마 끝 아래 선(점마다): 들쭉날쭉 — 묵은 이엉은 깊게(최대 8cm), 다듬은 처마는 얕은 물결(1.5cm)
	var hide = o.get("hide_under")
	var drop := []
	for i in n:
		var th := atan2(float(r0[i].y), float(r0[i].x))
		var dv := (0.02 + 0.06 * wear) * _hn(float(i), 5.0, sd) + 0.03 * _per(th, sd, 7, 13) if ragged else 0.015 * _per(th, sd, 5, 9)
		# 다른 날개(ㄱ·ㄷ 이음) 가까이는 처마 끝을 내리지 않는다 — 이음 안쪽 모서리에서 이웃 날개 벽 위 여유(≥ 0.04m)를 지킨다
		if hide is Callable:
			var pp := Vector2(r0[i].x, r0[i].y)
			for f in [1.0, 0.85, 0.7]:
				var q: Vector2 = pp * f
				if (hide as Callable).call(q.x, q.y) or (hide as Callable).call(q.x + 0.6, q.y) or (hide as Callable).call(q.x - 0.6, q.y) or (hide as Callable).call(q.x, q.y + 0.6) or (hide as Callable).call(q.x, q.y - 0.6):
					dv = 0.0
		drop.append(dv if lod == 0 else 0.0)
	for i in n:
		var i2 := (i + 1) % n
		var dz0: PackedFloat32Array = rdd[0]
		var a := Vector3(r0[i].x, eave - dz0[i], r0[i].y); var b := Vector3(r0[i2].x, eave - dz0[i2], r0[i2].y)
		if hide is Callable and (hide as Callable).call((a.x + b.x) * 0.5, (a.z + b.z) * 0.5): continue   # 다른 날개 방 위 — 처마 띠·밑면 없음
		var a1 := Vector3(r0[i].x * grow, eave - thick - float(drop[i]) - dz0[i], r0[i].y * grow); var b1 := Vector3(r0[i2].x * grow, eave - thick - float(drop[i2]) - dz0[i2], r0[i2].y * grow)
		var out := Vector3(a.x + b.x, 0, a.z + b.z)
		var ua := _tu(a); var ub := ua + a.distance_to(b) / 1.2
		tw(lip, a1, b1, b, Vector2(ua, 0.35), Vector2(ub, 0.35), Vector2(ub, 0.0), out)
		tw(lip, a1, b, a, Vector2(ua, 0.35), Vector2(ub, 0.0), Vector2(ua, 0.0), out)
		# 밑면(처마 안쪽은 어둡게): 처마 끝 → 벽 줄 바로 바깥, 거기서 안으로 닫는다
		var ia := Vector3(rin[i].x, y_in, rin[i].y); var ib := Vector3(rin[i2].x, y_in, rin[i2].y)
		C.qf(bot, a1, b1, ib, ia, Vector3.DOWN)
		C.tf(bot, ia, ib, Vector3(0, y_in, 0), Vector3.DOWN)
		# 짚 끝 술(묵은 이엉): 처마 아래끝에 촘촘한(0.055m) 가는 짚 끝 — 길이 2~8cm, 이엉 처마 띠와 같은 짚 빛·결
		if ragged and lod == 0:
			var seg := a1.distance_to(b1)
			var nt := maxi(1, int(seg / 0.055))
			var od := out.normalized()
			for t in nt:
				var hz := _hn(float(i * 31 + t), 9.0, sd)
				if hz < 0.3: continue   # 빈 자리(가지런하지 않게)
				var f0 := (t + 0.2 * _hn(float(i * 17 + t), 7.0, sd)) / nt; var f1 := minf(1.0, (t + 0.8 + 0.6 * _hn(float(i * 19 + t), 6.0, sd)) / nt)
				var fm := lerpf(f0, f1, 0.2 + 0.6 * _hn(float(i * 53 + t), 8.0, sd))
				var p0 := a1.lerp(b1, f0); var p1 := a1.lerp(b1, f1)
				var ln := 0.015 + 0.09 * pow(_hn(float(i * 37 + t), 10.0, sd), 2.0) * (0.5 + wear)
				var tip := a1.lerp(b1, fm) + od * 0.015 + Vector3(0, -ln, 0)
				p0 += od * 0.004 + Vector3(0, 0.03, 0); p1 += od * 0.004 + Vector3(0, 0.03, 0)
				var u0 := _tu(a) + f0 * seg / 1.2; var u1 := _tu(a) + f1 * seg / 1.2
				tw(tufts, p0, p1, tip, Vector2(u0, 0.3), Vector2(u1, 0.3), Vector2((u0 + u1) / 2, 0.36 + ln), od)
	# --- 빛: 높이 그라데이션 + 빗물 줄(처마 쪽 짙게) + 묵은 잿빛·이끼(낡음) + 켜마다 다른 해의 짚 빛 ---------------
	var ctop := Kit.hex(cols[0]); var cbot := Kit.hex(cols[1])
	var grey := Kit.hex(0x6c665a); var moss := Kit.hex(0x5f6646)
	var band_of := func(e: float) -> int:
		var bi := 0
		for k in bands:
			if e >= hd * float(k) / nr - 1e-3: bi += 1
		return bi
	var paint := func(g: Kit.Geo, dark: float) -> void:
		for i in g.pos.size():
			var p: Vector3 = g.pos[i]
			var t := clampf((p.y - eave) / maxf(rise, 0.3), 0.0, 1.0)
			var c := cbot.lerp(ctop, 0.3 + 0.7 * t)
			var th := atan2(p.z, p.x * hd / maxf(hw, 0.5))
			var streak := _per(th, sd, 29, 47) * (1.0 - t)
			c = c.darkened(dark + (0.08 + 0.22 * wear) * streak * streak)
			c = c.lerp(grey, clampf(wear * 0.45 * _per(th, sd + 2.0, 3, 8), 0, 0.5))
			if wear > 0.5: c = c.lerp(moss, clampf((wear - 0.5) * 0.7 * _per(th, sd + 5.0, 4, 11) * (1.0 - t), 0, 0.3))
			var e_here := hd * clampf(t, 0, 1)
			var bi: int = band_of.call(e_here)
			c = c.lightened(0.04 if bi % 2 == 1 else 0.0)
			c = c.darkened((_hn(float(i / 3), 2.0, sd) - 0.5) * 0.04)
			g.col[i] = c
	paint.call(top, 0.0)
	paint.call(lips, 0.22)
	# --- 덧이엉: 묵은 지붕을 새 짚으로 기운 자리 — 켜 하나(띠) 안에서 둘레 몇 m만 금빛, 가장자리는 부드럽게(판처럼 보이지 않게) ---
	var npatch: int = int(o.get("patch", 0)) if lod == 0 else 0
	if npatch > 0:
		var fresh := Kit.hex(0xd9c288)
		for q in npatch:
			var thc := (_hn(float(q), 11.0, sd) * 2.0 - 1.0) * PI
			var tw2 := 0.22 + 0.2 * _hn(float(q), 12.0, sd)
			var tlo := 0.15 + 0.35 * _hn(float(q), 13.0, sd); var thi := tlo + 0.18 + 0.12 * _hn(float(q), 14.0, sd)
			for i in top.pos.size():
				var p: Vector3 = top.pos[i]
				var t := (p.y - eave) / maxf(rise, 0.3)
				var th := atan2(p.z, p.x * hd / maxf(hw, 0.5))
				var da := absf(wrapf(th - thc, -PI, PI)) / tw2
				var dt := maxf(tlo - t, t - thi) / 0.06
				var f := clampf(1.0 - da, 0, 1) * clampf(1.0 - dt, 0, 1)
				f *= 0.75 + 0.25 * _hn(float(i / 3), 6.0, sd)
				if f > 0.0: top.col[i] = top.col[i].lerp(fresh.lerp(top.col[i], 0.25 + 0.35 * t), clampf(f * 1.4, 0, 0.85))
	A.add_tiled(m, part, "thatch", top, 0.05 if lod < 2 else 0.0)
	if lips.size() > 0: A.add_tiled(m, part, "thatch", lips, 0.0)
	var lipc: Array = o.get("lip_cols", C.THATCH_LIP)
	A.add_tiled(m, part, "thatch", C.PA(lip, lipc, 0.04, m.rng), 0.035 if lod == 0 else 0.0)
	if tufts.size() > 0: A.add_tiled(m, part, "thatch", C.PA(tufts, lipc, 0.06, m.rng), 0.0)
	m.add(part, "flat", C.P(bot, 0x5a4a36, 0x3e3226, 0.03), 0)
	var ridge_y: float = Hf.call(hd) - sag
	var rh := ridge_half
	# 용마름: 용마루 줄을 덮는 엮은 짚 ∧ 덮개(세모 기둥) — 양 끝은 둥근 끝으로 줄어든다 + 엮은 결(∧ 짚 묶음 줄)
	if lod < 2:
		var ym := Kit.Geo.new()
		var wy := 0.42; var hy := 0.2; var tp := 0.7
		var L2 := rh + 0.15
		var y0 := ridge_y - 0.1
		for sgn in [-1.0, 1.0]:
			var a := Vector3(-L2, y0, sgn * wy); var b := Vector3(L2, y0, sgn * wy)
			var c := Vector3(L2 - tp * 0.5, y0 + hy, 0); var d := Vector3(-L2 + tp * 0.5, y0 + hy, 0)
			tw(ym, a, b, c, Vector2(-L2, 1), Vector2(L2, 1), Vector2(L2, 0.5), Vector3(0, 1, sgn))
			tw(ym, a, c, d, Vector2(-L2, 1), Vector2(L2, 0.5), Vector2(-L2, 0.5), Vector3(0, 1, sgn))
		for sx in [-1.0, 1.0]:
			# 끝: 이엉 속으로 낮게 묻히는 꼬리
			var tip := Vector3(sx * (L2 + tp), y0 - 0.12, 0)
			tw(ym, Vector3(sx * L2, y0, -wy), Vector3(sx * L2, y0, wy), Vector3(sx * (L2 - tp * 0.5), y0 + hy, 0), Vector2(0, 1), Vector2(1, 1), Vector2(0.5, 0.5), Vector3(sx, 0.5, 0))
			tw(ym, Vector3(sx * L2, y0, -wy), tip, Vector3(sx * L2, y0, wy), Vector2(0, 1), Vector2(0.5, 0.6), Vector2(1, 1), Vector3(sx, 1, 0))
		A.add_tiled(m, part, "yongmareum", C.PA(ym, o.get("cols", C.THATCH), 0.03), 0.02 if lod == 0 else 0.0)
		if lod == 0:
			# 엮은 결: 0.3m마다 ∧ 짚 묶음(용마름 면 위 1.2cm) — 김홍도 「벼타작」·김준근 초가 용마름의 비늘 줄
			var ch := Kit.Geo.new()
			var nch := maxi(3, int((2.0 * L2 - tp) / 0.24))
			for q in nch:
				var x := -L2 + tp * 0.5 + (2.0 * L2 - tp) * (q + 0.5) / nch
				for sgn in [-1.0, 1.0]:
					var pa := Vector3(x, y0 + hy + 0.008, 0.0)
					var pb := Vector3(x - 0.2, y0 + 0.07 + 0.008, sgn * wy * 0.7)
					var w2 := Vector3(0.025, 0, 0)
					tw(ch, pa - w2, pa + w2, pb + w2, Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector3(0, 1, sgn))
					tw(ch, pa - w2, pb + w2, pb - w2, Vector2(0, 0), Vector2(1, 1), Vector2(0, 1), Vector3(0, 1, sgn))
			var cy := Kit.hex(cols[0]).lerp(Kit.hex(cols[1]), 0.6).darkened(0.05 + 0.08 * wear)
			m.add(part, "flat", C.P(ch, cy.to_rgba32() >> 8, cy.darkened(0.15).to_rgba32() >> 8, 0.04), 0.0)
	# 서까래 끝(이엉 처마 밑 가는 통나무) — 앞뒤만
	if lod == 0 and o.has("L"):
		var L: float = o.L; var D: float = o.D
		var g := Kit.Geo.new()
		var nn := maxi(2, int((L - 0.4) / 0.48))
		for k in nn + 1:
			var x := lerpf(-L / 2 + 0.2, L / 2 - 0.2, float(k) / nn)
			for zs in [-1, 1]:
				var zw: float = zs * (D / 2 - 0.05)
				var ze: float = zs * (_ring_z(hw, hd, rc, x) * 0.97 - 0.05)
				if absf(ze) <= absf(zw) + 0.1: continue
				# 서까래: 벽 줄(도리 위)에서 처마 끝 밑으로 내려간다 — 벽 위를 지나지 않게
				var yw: float = float(o.get("wall_top", eave)) + 0.02
				var dze := 0.0
				if dmax > 0.001:
					var dz0r: PackedFloat32Array = rdd[0]; var r0r: Array = rings[0][0]
					var bq := 0; var bd := INF
					for q in r0r.size():
						var dq := (r0r[q] as Vector2).distance_squared_to(Vector2(x, ze))
						if dq < bd: bd = dq; bq = q
					dze = dz0r[bq]
				_rod(g, Vector3(x, yw, zw), Vector3(x, eave - thick + 0.03 - dze, ze), 0.05)
		m.add(part, "bark", C.P(g, 0x6e5a46, 0x4a3b2e, 0.04), 0.01)
	# 새끼 그물(제주·바닷가): 앞뒤로 넘어가는 줄 + 길이 줄
	var net: int = o.get("net", 0)
	if net > 0 and lod < 2:
		var gn := Kit.Geo.new()
		var Hxz := func(x: float, z: float) -> float:
			var q := Vector2(absf(x) - (hw - rc), absf(z) - (hd - rc))
			var dist := Vector2(maxf(q.x, 0), maxf(q.y, 0)).length() + minf(maxf(q.x, q.y), 0.0) - rc
			var e := clampf(-dist, 0, hd)
			return Hf.call(e) + 0.04 + (STEP if lod == 0 and e > hd * 2.0 / nr else 0.0) + 0.03 - sagf.call(x, e)
		for k in net + 1:
			var x := lerpf(-hw + 0.6, hw - 0.6, float(k) / net)
			var prev := Vector3.ZERO
			for j in 9:
				var z := lerpf(-hd, hd, j / 8.0) * 0.98
				var p := Vector3(x, Hxz.call(x, z), z)
				if j > 0: _rod(gn, prev, p, 0.025)
				prev = p
		for e in [0.35, 0.7]:
			var rg: Array = ring.call(hd * e)
			var y: float = Hf.call(hd * e) + 0.04 + (STEP if lod == 0 else 0.0) + 0.03
			for i in rg.size():
				var a: Vector2 = rg[i]; var b: Vector2 = rg[(i + 1) % rg.size()]
				if a.distance_to(b) < 0.02: continue
				_rod(gn, Vector3(a.x, y, a.y), Vector3(b.x, y, b.y), 0.025)
		m.add(part, "flat", C.P(gn, 0x6f6040, 0x5a4c32, 0.03), 0)
	return { ridge_y = ridge_y, ridge_half = rh, h = Hf }

static func _tu(p: Vector3) -> float:
	return (atan2(p.z, p.x) + PI) * 1.4

# 둥근 사각 처마선의 z(앞) — x 자리
static func _ring_z(hw: float, hd: float, rc: float, x: float) -> float:
	return C.rr_extent(hd, hw, rc, x)

# 맞배 이엉(헛간·대장간·방앗간): 볼록 단면 두 비탈 + 박공 흙벽 + 용마름. o: hw, hd, eave, rise, lod, L, D, cols
static func thatch_gable(m: C.M, part: String, o: Dictionary) -> Dictionary:
	var hw: float = o.hw; var hd: float = o.hd; var eave: float = o.eave; var rise: float = o.rise; var lod: int = o.get("lod", 0)
	var cols: Array = o.get("cols", C.THATCH)
	var nz: int = [5, 3, 2][lod]
	var top := Kit.Geo.new(); var lip := Kit.Geo.new()
	var thick := 0.28
	# 처마 처짐(앞 zp · 뒤 zn, m): 벽 줄(처마 끝에서 ov) 밖 띠만 끝으로 갈수록 내린다
	var drp: Dictionary = o.get("droop", {})
	var ovg: float = maxf(float(o.get("ov", 0.0)), 0.01)
	var dg := func(sgn: float, sv: float) -> float:
		var e := sv * hd
		if e >= ovg: return 0.0
		return float(drp.get("zp" if sgn > 0 else "zn", 0.0)) * pow(1.0 - e / ovg, 1.4)
	for sgn in [-1.0, 1.0]:
		for k in nz:
			var s0 := float(k) / nz; var s1 := float(k + 1) / nz
			var z0: float = sgn * hd * (1.0 - s0); var z1: float = sgn * hd * (1.0 - s1)
			var y0: float = eave + rise * prof_thatch(s0) - dg.call(sgn, s0); var y1: float = eave + rise * prof_thatch(s1) - dg.call(sgn, s1)
			var x0 := hw - 0.15 * s0; var x1 := hw - 0.15 * s1
			var a := Vector3(-x0, y0, z0); var b := Vector3(x0, y0, z0); var c := Vector3(x1, y1, z1); var d := Vector3(-x1, y1, z1)
			tw(top, a, b, c, Vector2(-x0 / 2, s0 * hd / 1.6), Vector2(x0 / 2, s0 * hd / 1.6), Vector2(x1 / 2, s1 * hd / 1.6), Vector3(0, 1, sgn))
			tw(top, a, c, d, Vector2(-x0 / 2, s0 * hd / 1.6), Vector2(x1 / 2, s1 * hd / 1.6), Vector2(-x1 / 2, s1 * hd / 1.6), Vector3(0, 1, sgn))
		var a0 := Vector3(-hw, eave - dg.call(sgn, 0.0), sgn * hd); var b0 := Vector3(hw, eave - dg.call(sgn, 0.0), sgn * hd); var dn := Vector3(0, -thick, sgn * 0.03)
		tw(lip, a0 + dn, b0 + dn, b0, Vector2(-hw / 1.2, 0.35), Vector2(hw / 1.2, 0.35), Vector2(hw / 1.2, 0), Vector3(0, 0, sgn))
		tw(lip, a0 + dn, b0, a0, Vector2(-hw / 1.2, 0.35), Vector2(hw / 1.2, 0), Vector2(-hw / 1.2, 0), Vector3(0, 0, sgn))
		# 박공 끝 이엉 두께(옆)
		for sx in [-1.0, 1.0]:
			var g := Kit.Geo.new()
			for k in nz:
				var s0 := float(k) / nz; var s1 := float(k + 1) / nz
				var p0 := Vector3(sx * (hw - 0.15 * s0), eave + rise * prof_thatch(s0) - dg.call(sgn, s0), sgn * hd * (1.0 - s0))
				var p1 := Vector3(sx * (hw - 0.15 * s1), eave + rise * prof_thatch(s1) - dg.call(sgn, s1), sgn * hd * (1.0 - s1))
				var q := Vector3(0, -thick, 0)
				tw(lip, p0 + q, p1 + q, p1, Vector2(0, 0.35), Vector2(0.3, 0.35), Vector2(0.3, 0), Vector3(sx, 0, 0))
				tw(lip, p0 + q, p1, p0, Vector2(0, 0.35), Vector2(0.3, 0), Vector2(0, 0), Vector3(sx, 0, 0))
	A.add_tiled(m, part, "thatch", C.PA(top, cols, 0.05, m.rng), 0.05 if lod < 2 else 0.0)
	A.add_tiled(m, part, "thatch", C.PA(lip, C.THATCH_LIP, 0.04, m.rng), 0.03 if lod == 0 else 0.0)
	# 밑면
	var bot := Kit.Geo.new()
	for sgn in [-1.0, 1.0]:
		# 밑면: 벽 줄 안은 예전 곧은 판, 밖은 처진 처마 끝까지 따로
		var zw := hd - minf(ovg, hd * 0.9)
		var yw := eave - thick + rise * 0.8 * (1.0 - zw / hd)
		var dt0: float = dg.call(sgn, 0.0)
		C.qf(bot, Vector3(-hw, eave - thick - dt0, sgn * hd), Vector3(hw, eave - thick - dt0, sgn * hd), Vector3(hw, yw, sgn * zw), Vector3(-hw, yw, sgn * zw), Vector3(0, -1, 0))
		C.qf(bot, Vector3(-hw, yw, sgn * zw), Vector3(hw, yw, sgn * zw), Vector3(hw, eave + rise * 0.8 - thick, 0), Vector3(-hw, eave + rise * 0.8 - thick, 0), Vector3(0, -1, 0))
	m.add(part, "flat", C.P(bot, 0x5a4a36, 0x3e3226, 0.03), 0)
	var ridge_y := eave + rise
	if lod < 2:
		var ym := Kit.Geo.new()
		var L2 := hw - 0.1
		for sgn in [-1.0, 1.0]:
			tw(ym, Vector3(-L2, ridge_y - 0.08, sgn * 0.4), Vector3(L2, ridge_y - 0.08, sgn * 0.4), Vector3(L2, ridge_y + 0.18, 0), Vector2(-L2, 1), Vector2(L2, 1), Vector2(L2, 0.5), Vector3(0, 1, sgn))
			tw(ym, Vector3(-L2, ridge_y - 0.08, sgn * 0.4), Vector3(L2, ridge_y + 0.18, 0), Vector3(-L2, ridge_y + 0.18, 0), Vector2(-L2, 1), Vector2(L2, 0.5), Vector2(-L2, 0.5), Vector3(0, 1, sgn))
		A.add_tiled(m, part, "yongmareum", C.P(ym, 0xf0e6c8, 0xc8b88e, 0.03), 0.02 if lod == 0 else 0.0)
	# 박공 흙벽(벽 위 세모)
	if o.has("L"):
		var L: float = o.L; var D: float = o.D; var wt: float = o.get("wall_top", eave - 0.15)
		for sx in [-1.0, 1.0]:
			var g := Kit.Geo.new()
			var x: float = sx * L / 2
			var apex := eave + rise * 0.92 - thick
			C.tf(g, Vector3(x, wt, -D / 2), Vector3(x, wt, D / 2), Vector3(x, apex, 0), Vector3(sx, 0, 0))
			m.add(part, "mud", C.PA(g, [0x9a8460, 0x7a6648], 0.03, m.rng), 0.02 if lod == 0 else 0.0)
	return { ridge_y = ridge_y, ridge_half = hw }
