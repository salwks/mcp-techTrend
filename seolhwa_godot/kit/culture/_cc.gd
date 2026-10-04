# kit-culture 공용 도구 — 문화권 가옥형(ㅁ자·ㄱ자·ㄷ자·田자·一자 겹집 등)을 '채(wing)' 사각형 몇 개로 짓는다.
#   const CC := preload("res://kit/culture/_cc.gd")
#   var m := C.M.new(seed)
#   CC.house(m, [ {x0,x1,z0,z1, face:"s"|"n"|"e"|"w", bays:"wdmdk", F, wall_h, ...}, … ], "giwa", {ov=1.4})
# 지붕: 채마다 팔작/우진각 높이장 H_i(x,z)를 두고 겹친 곳은 max(H_i) — 실제 겹친 지붕처럼 골(회첨)과 추녀가 저절로 생긴다.
#   그래서 ㅁ자·ㄱ자·田자도 지붕 하나로 이어져 위에서 볼 때 평면 모양이 그대로 보인다(고정 카메라에서 가장 큰 신호).
# bays 글자(정면 = face 쪽, 왼→오른):
#   d 방문 두 짝   w 창   s 작은 창(북부·제주)   h 높은 들창(도시 바깥벽)   k 부엌 널문   m 대청(트임, 어두운 안)
#   g 대문간(뚫린 통로, 문짝 안으로 열림)   c 외양간(트임 + 살대)   b 민벽   j 제주 상방(널문 두 짝 + 풍채)
extends RefCounted
const C := preload("res://kit/village/_common.gd")

# 지붕 재료: key, 색(처마→용마루), 처마 끝 띠(key·색·두께), 단면(profile), 기본 처마 내밈
const ROOF := {
	giwa = { key = "tile", top = 0xd9d9d4, low = 0xb9b8b2, ekey = "makse", ecol = [0x9a9a94, 0x7a7a74], thick = 0.24, prof = "giwa", ov = 1.4, lift = 0.5 },
	giwa_dark = { key = "tile", top = 0xb4b6b6, low = 0x8e9092, ekey = "makse", ecol = [0x7a7c7e, 0x5e6062], thick = 0.26, prof = "giwa", ov = 1.5, lift = 0.6 },
	thatch = { key = "thatch", top = 0xe0cc98, low = 0xa18a5e, ekey = "thatch", ecol = [0xa69064, 0x7d6a48], thick = 0.34, prof = "round", ov = 0.8, lift = 0.0 },
	thatch_old = { key = "thatch", top = 0x9e865c, low = 0x5e4a32, ekey = "thatch", ecol = [0x76643f, 0x544630], thick = 0.6, prof = "thick", ov = 0.75, lift = 0.0 },
	thatch_sea = { key = "thatch", top = 0xaea58f, low = 0x77705f, ekey = "thatch", ecol = [0x857d6a, 0x635c4d], thick = 0.28, prof = "round", ov = 0.75, lift = 0.0 },
	thatch_nw = { key = "thatch", top = 0xcfc6ac, low = 0x958c74, ekey = "thatch", ecol = [0x8a7f63, 0x655c48], thick = 0.36, prof = "round", ov = 0.95, lift = 0.0 },
	tti = { key = "thatch", top = 0x9a9c94, low = 0x66675f, ekey = "thatch", ecol = [0x6a6455, 0x4c4840], thick = 0.3, prof = "low", ov = 0.55, lift = 0.0 },
}

const BASALT := [0x5d5954, 0x403c38]
const BASALT_L := [0x6e6a64, 0x4a4641]
const SAGOE := [0xb4b0a6, 0x8f8b82]     # 사괴석(도시 화방벽 아랫단)
const MUD_RED := [0xcfae84, 0xa0805a]   # 영남 붉은 흙벽(가설: 경상 내륙 마사토 빛)

# ---------------------------------------------------------------------------
# 집 한 채: 채 몸체들 + 이어진 지붕
# ropts: ov(처마 내밈), rise_k(높이/반깊이), k(팔작 끝 기울기 배수), eave_add, rope(새끼 그물 간격 m, 0 없음), ridge(true)
# 반환 { rects, eave, H: Callable }
static func house(m: C.M, wings: Array, roof := "giwa", ropts := {}) -> Dictionary:
	var st: Dictionary = ROOF[roof]
	var ov: float = ropts.get("ov", st.ov)
	var rects := []
	var pre := m.prefix
	for w in wings:
		if w.has("name"): m.prefix = pre + str(w.name) + "_"
		var info := wing(m, w, roof)
		m.prefix = pre
		if w.get("noroof", false): continue
		var r := { x0 = w.x0 - ov, x1 = w.x1 + ov, z0 = w.z0 - ov, z1 = w.z1 + ov,
			axis = "x" if w.get("face", "s") in ["s", "n"] else "z", eave = info.top + float(ropts.get("eave_add", 0.45 if st.prof == "giwa" else 0.1)) + float(w.get("eave_add", 0.0)),
			k = float(w.get("k", ropts.get("k", 1.9 if st.prof == "giwa" else 1.2))), gable = bool(w.get("gable", false)) }
		if w.has("axis"): r.axis = w.axis
		var hb: float = ((r.z1 - r.z0) if r.axis == "x" else (r.x1 - r.x0)) / 2.0
		r.rise = float(w.get("rise", hb * float(ropts.get("rise_k", 0.56 if st.prof == "giwa" else (0.62 if st.prof == "thick" else (0.36 if st.prof == "low" else 0.5))))))
		rects.append(r)
	var res := env_roof(m, rects, roof, ropts)
	return res

# 채 몸체 하나(지붕 빼고). w: x0,x1,z0,z1(평면), face, bays, F(기단), wall_h, wall("mud"|"plaster"|"red"|"basalt"|"urban"), maru(툇마루 깊이), chimney
static func wing(m: C.M, w: Dictionary, roof: String) -> Dictionary:
	var face: String = w.get("face", "s")
	var cx: float = (w.x0 + w.x1) / 2.0; var cz: float = (w.z0 + w.z1) / 2.0
	var ry := 0.0; var L: float = w.x1 - w.x0; var D: float = w.z1 - w.z0
	match face:
		"n": ry = PI
		"e": ry = PI / 2; L = w.z1 - w.z0; D = w.x1 - w.x0
		"w": ry = -PI / 2; L = w.z1 - w.z0; D = w.x1 - w.x0
	var giwa := roof.begins_with("giwa")
	var F: float = w.get("F", 0.7 if giwa else 0.4)
	var wallH: float = w.get("wall_h", 2.25 if giwa else 1.85)
	var bays: String = w.get("bays", "wdk")
	var wall: String = w.get("wall", "plaster" if giwa else "mud")
	var old := m.push(cx, 0, cz, ry)
	var o := body(m, L, D, F, wallH, bays, wall, w)
	m.pop(old)
	return o

# 로컬 몸체: 길이 L(x), 깊이 D(z), 정면 +z
static func body(m: C.M, L: float, D: float, F: float, wallH: float, bays: String, wall: String, w: Dictionary) -> Dictionary:
	var R := m.rng
	var hl := L / 2; var hd := D / 2
	var top := F + wallH
	var n := bays.length()
	var bw := L / n
	var basalt := wall == "basalt"
	var t := 0.42 if basalt else 0.16
	var wc: Array = C.MUD
	var wkey := "mud"
	match wall:
		"plaster", "urban": wc = C.PLASTER
		"red": wc = MUD_RED
		"basalt": wc = BASALT; wkey = "stone"
	var base_col: Array = [0xaaa498, 0x7b766c] if F > 0.55 else C.STONE
	if basalt: base_col = BASALT_L
	# 기단·벽은 g(통로) 칸에서 끊는다
	var runs := []   # [i0, i1) 연속 구간
	var i0 := 0
	for i in n + 1:
		if i == n or bays[i] == "g":
			if i > i0: runs.append([i0, i])
			i0 = i + 1
	var frontless := "mgcj"   # 앞벽 없는 칸
	for rn in runs:
		var xa: float = -hl + rn[0] * bw; var xb: float = -hl + rn[1] * bw
		var ea := 0.3 if rn[0] == 0 else 0.0; var eb := 0.3 if rn[1] == n else 0.0
		m.add("p", "stone", C.PA(Kit.box(xb - xa + ea + eb, F, D + 0.6, (xa + xb + eb - ea) / 2, F / 2, 0), base_col, 0.05, R), 0.025)
		# 뒷벽
		m.add("p", wkey, C.PA(Kit.box(xb - xa, wallH, t, (xa + xb) / 2, F + wallH / 2, -hd + t / 2), wc, 0.04, R), 0.02)
		m.box_c(xa - ea, xb + eb, -hd - 0.3, hd + 0.3 + float(w.get("maru", 0.0)))
	# 옆벽
	if bays[0] != "g": m.add("p", wkey, C.PA(Kit.box(t, wallH, D, -hl + t / 2, F + wallH / 2, 0), wc, 0.04, R), 0.02)
	if bays[n - 1] != "g": m.add("p", wkey, C.PA(Kit.box(t, wallH, D, hl - t / 2, F + wallH / 2, 0), wc, 0.04, R), 0.02)
	# 앞벽: 벽 있는 칸을 이어 한 상자로
	var j := 0
	while j < n:
		if frontless.find(bays[j]) >= 0: j += 1; continue
		var k := j
		while k < n and frontless.find(bays[k]) < 0: k += 1
		var xa := -hl + j * bw; var xb := -hl + k * bw
		if wall == "urban":
			m.add("p", "stone", C.PA(Kit.box(xb - xa, 1.0, t + 0.04, (xa + xb) / 2, F + 0.5, hd - t / 2), SAGOE, 0.05, R), 0.02)
			m.add("p", "mud", C.PA(Kit.box(xb - xa, wallH - 1.0, t, (xa + xb) / 2, F + 1.0 + (wallH - 1.0) / 2, hd - t / 2), wc, 0.03, R), 0.02)
		else:
			m.add("p", wkey, C.PA(Kit.box(xb - xa, wallH, t, (xa + xb) / 2, F + wallH / 2, hd - t / 2), wc, 0.04, R), 0.02)
		j = k
	if basalt:
		# 현무암 돌벽: 앞면에 구멍 숭숭한 큰 돌 몇 개(위에서도 거친 돌벽으로 읽히게)
		var sg := []
		var ns := int(L / 0.9)
		for i in ns:
			var x := -hl + (i + 0.5) * L / ns
			if bays[clampi(int((x + hl) / bw), 0, n - 1)] != "b": continue
			for row in 2:
				if R.next() < 0.35: continue
				var lg := Kit.lump(R.between(0.2, 0.28), 0, R, 0.35, 0.8)
				sg.append(C.PA(Kit.xf(lg, x + R.between(-0.2, 0.2), F + 0.35 + row * 0.75, hd + 0.02, 0, R.next() * 3, 0, 1.2, 1, 0.45), BASALT_L, 0.08, R))
		if sg.size() > 0: m.add("p", "stone", Kit.merge(sg), 0)
	# 칸 장식
	var lights := 0
	for i in n:
		var c := bays[i]
		var x := -hl + (i + 0.5) * bw
		var zf := hd + 0.012
		match c:
			"d":
				panel(m, x - 0.29, F + 0.82, 0.54, 1.45, zf)
				panel(m, x + 0.29, F + 0.82, 0.54, 1.45, zf)
				if lights < 3: m.light(x, F + 1.0, hd + 0.25, "window"); lights += 1
				if not m.anchors.has(m.prefix + "door"): m.anchor("door", Vector3(x, 0, hd + 1.2))
			"w":
				panel(m, x, F + 1.15, 0.72, 0.6, zf)
				if lights < 3: m.light(x, F + 1.15, hd + 0.25, "window"); lights += 1
			"s":
				panel(m, x, F + 1.2, 0.42, 0.38, zf)
				if lights < 2: m.light(x, F + 1.2, hd + 0.25, "window"); lights += 1
			"h":
				panel(m, x, F + wallH - 0.45, 0.6, 0.3, zf)
			"k":
				m.add("p", "wood", C.P(Kit.box(0.9, 1.55, 0.06, x, F + 0.78, hd + 0.01), 0x5a4432, 0x3f2f22, 0.04, R), 0.01)
				if not m.anchors.has(m.prefix + "kitchen"): m.anchor("kitchen", Vector3(x, 0, hd + 0.9))
			"m", "c", "j":
				var dep := minf(1.4, D - 0.4)
				m.add("p", "flat", C.P(Kit.box(bw, wallH, 0.04, x, F + wallH / 2, hd - dep), 0x3e3128, 0x2a211a), 0)
				m.add("p", "flat", C.P(Kit.box(bw, 0.05, dep, x, F + 0.02, hd - dep / 2), 0x9a7a52 if c != "c" else 0x6a5a40, 0x846848), 0)
				for s in [-1, 1]: m.add("p", wkey, C.PA(Kit.box(0.08, wallH, dep, x + s * (bw / 2 - 0.04), F + wallH / 2, hd - dep / 2), wc, 0.03, R), 0)
				if c == "c":
					for q in 4: m.add("p", "wood", C.PA(Kit.box(0.07, 1.3, 0.07, x - bw / 2 + (q + 0.5) * bw / 4, F + 0.65, hd), C.WOOD), 0.008)
					m.add("p", "wood", C.PA(Kit.box(bw, 0.08, 0.08, x, F + 1.25, hd), C.WOOD), 0.008)
					m.anchor("cow", Vector3(x, F, hd - 0.7))
				elif c == "j":
					# 제주 상방: 널문(호령문) 두 짝을 열어 둠
					for s in [-1, 1]: m.add("p", "wood", C.P(Kit.box(0.5, 1.5, 0.05, x + s * (bw / 2 - 0.3), F + 0.78, hd + 0.03), 0x6a5440, 0x4a3a2c, 0.04, R), 0.01)
					m.anchor("sangbang", Vector3(x, F, hd - 0.5))
				else:
					if not m.anchors.has(m.prefix + "daecheong"): m.anchor("daecheong", Vector3(x, F, hd - 0.6))
			"g":
				for s in [-1, 1]:
					m.add("p", wkey, C.PA(Kit.box(0.14, wallH, D, x + s * (bw / 2 - 0.07), F * 0.3 + wallH / 2, 0), wc, 0.04, R), 0.02)
					var lf := Kit.box(bw / 2 - 0.15, wallH - 0.3, 0.06, -s * (bw / 4 - 0.07), 0, 0)
					Kit.xf(lf, x + s * (bw / 2 - 0.15), (wallH - 0.3) / 2 + 0.08, -hd + 0.4, 0, -s * 1.3, 0)
					m.add("p", "wood", C.P(lf, 0x5a4432, 0x3f2f22, 0.04, R), 0.01)
				m.add("p", "stone", C.PA(Kit.box(bw, 0.12, D + 0.6, x, 0.06, 0), C.STONE, 0.04, R), 0.01)
				m.add("p", "wood", C.PA(Kit.box(bw, 0.2, 0.22, x, F * 0.3 + wallH - 0.1, hd), C.WOOD), 0.012)
				for s in [-1, 1]: m.box_c(x + s * (bw / 2 - 0.07) - 0.12, x + s * (bw / 2 - 0.07) + 0.12, -hd, hd)
				m.anchor("gate", Vector3(x, 0, hd + 1.0))
				m.anchor("gate_in", Vector3(x, 0, -hd - 1.0))
	# 기둥(앞) + 도리
	if not basalt:
		for i in n + 1:
			var x := -hl + i * bw
			m.add("p", "wood", C.PA(Kit.box(0.2, wallH + 0.05, 0.2, x, F + wallH / 2, hd), C.WOOD), 0.015)
		m.add("p", "wood", C.PA(Kit.box(L + 0.3, 0.18, 0.22, 0, top + 0.05, hd), C.WOOD), 0.015)
	# 툇마루
	var maru: float = w.get("maru", 0.0)
	if maru > 0.0:
		var j2 := 0
		while j2 < n:
			if bays[j2] in "gkc": j2 += 1; continue
			var k2 := j2
			while k2 < n and not bays[k2] in "gkc": k2 += 1
			m.add("p", "wood", C.PA(Kit.box((k2 - j2) * bw, 0.09, maru, -hl + (j2 + k2) * bw / 2, F - 0.03, hd + maru / 2), C.WOOD_L), 0.012)
			j2 = k2
		if not m.anchors.has(m.prefix + "maru"): m.anchor("maru", Vector3(0, F, hd + maru / 2))
	# 댓돌(높은 기단이면 계단)
	if F > 0.55 and w.get("steps", true):
		var sx := 0.0
		var mi := bays.find("m")
		if mi >= 0: sx = -hl + (mi + 0.5) * bw
		for s in 2: m.add("p", "stone", C.P(Kit.box(1.5, F / 2, 0.36, sx, F / 4 + s * F / 4, hd + 0.3 + maru + 0.36 - s * 0.32), 0xb8b2a5, 0x8e897f, 0.04, R), 0.015)
	# 굴뚝
	match str(w.get("chimney", "")):
		"low":   # 남부: 낮은 굴뚝(기단 옆, 처마 아래)
			m.add("p", "stone", C.P(Kit.box(0.42, 1.2, 0.42, hl + 0.55, 0.6, -hd + 0.3), 0x9d8a6a, 0x6f6452, 0.06, R), 0.02)
			m.circle(hl + 0.55, -hd + 0.3, 0.35)
		"log":
			m.add("p", "bark", C.P(Kit.cyl(0.2, 0.23, top + 1.6, 7, hl + 0.5, (top + 1.6) / 2, -hd + 0.4), 0x6e5a46, 0x4a3b2e, 0.05, R), 0.02)
			m.circle(hl + 0.5, -hd + 0.4, 0.3)
		"tall":  # 북부: 처마 밖에 따로 선 높은 흙·통나무 굴뚝 + 낮은 고래(연도)
			var cxp: float = hl + float(w.get("chim_off", 1.5))
			m.add("p", "mud", C.PA(Kit.box(0.62, top + 2.0, 0.62, cxp, (top + 2.0) / 2, -hd + 0.6), C.MUD, 0.04, R), 0.02)
			m.add("p", "flat", C.P(Kit.box(0.74, 0.1, 0.74, cxp, top + 2.0, -hd + 0.6), 0x5e5446), 0.015)
			m.add("p", "mud", C.PA(Kit.box(cxp - hl, 0.4, 0.4, (hl + cxp) / 2, 0.2, -hd + 0.6), C.MUD, 0.04, R), 0.015)
			m.circle(cxp, -hd + 0.6, 0.4)
	return { top = top, F = F, L = L, D = D }

# 창호 한 장: 문틀 판(뒤) + 창호지(앞). 먹선 없이 싸게
static func panel(m: C.M, x: float, y: float, w: float, h: float, z: float) -> void:
	m.add("p", "wood", C.PA(Kit.box(w + 0.12, h + 0.12, 0.05, x, y, z - 0.01), C.DOOR), 0)
	m.add("p", "paper", C.vplane(w, h, x, y, z + 0.02), 0)

# ---------------------------------------------------------------------------
# 이어진 지붕(높이장 max)
# rects: [{x0,x1,z0,z1, axis, eave, rise, k, gable}]
# ---------------------------------------------------------------------------
static func height(rects: Array, prof: String, lift: float, x: float, z: float) -> float:
	var best := -INF
	for r in rects:
		if x < r.x0 - 1e-3 or x > r.x1 + 1e-3 or z < r.z0 - 1e-3 or z > r.z1 + 1e-3: continue
		var cx: float = (r.x0 + r.x1) / 2; var cz: float = (r.z0 + r.z1) / 2
		var a: float; var b: float; var ha: float; var hb: float
		if r.axis == "x":
			a = absf(x - cx); b = absf(z - cz); ha = (r.x1 - r.x0) / 2; hb = (r.z1 - r.z0) / 2
		else:
			a = absf(z - cz); b = absf(x - cx); ha = (r.z1 - r.z0) / 2; hb = (r.x1 - r.x0) / 2
		var ec := hb - b
		var ea: float = INF if r.gable else (ha - a) * r.k
		var e0 := minf(ea, ec)
		if prof != "giwa" and not r.gable:
			# 이엉: 추녀선을 둥글게(부드러운 최소) — 모난 상자가 아니라 부푼 덩이로
			var tau := 0.45
			e0 = -tau * log(exp(-maxf(ea, 0.0) / tau) + exp(-maxf(ec, 0.0) / tau)) + tau * log(2.0) * clampf(minf(ea, ec) / tau, 0.0, 1.0)
		var s := clampf(e0 / hb, 0.0, 1.0)
		var f: float
		match prof:
			"giwa": f = 0.25 * s + 0.75 * s * s
			"thick": f = pow(sin(s * PI / 2), 0.7)
			_: f = sin(s * PI / 2)
		var y: float = r.eave + r.rise * f
		if lift > 0.0 and not r.gable:
			# 추녀 들림: 다른 채에 묻히지 않은 바깥 귀에만
			var qi := (1 if x > cx else 0) + (2 if z > cz else 0)
			var fr = r.get("free")
			if fr == null or fr[qi]:
				var la := clampf(a / ha, 0, 1); var lb := clampf(b / hb, 0, 1)
				y += lift * maxf(pow(la, 3) * smoothstep(0.5, 1.0, lb), pow(lb, 3) * smoothstep(0.5, 1.0, la))
		best = maxf(best, y)
	return best

static func _grid(vals: Array, step: float) -> PackedFloat32Array:
	vals.sort()
	var u := []
	for v in vals:
		if u.is_empty() or absf(v - u[-1]) > 0.05: u.append(v)
	var out := PackedFloat32Array()
	for i in u.size() - 1:
		var nn := maxi(1, ceili((u[i + 1] - u[i]) / step))
		for q in nn: out.append(lerpf(u[i], u[i + 1], float(q) / nn))
	out.append(u[-1])
	return out

static func _inside(rects: Array, x: float, z: float, eps := 0.0) -> bool:
	for r in rects:
		if x > r.x0 - eps and x < r.x1 + eps and z > r.z0 - eps and z < r.z1 + eps: return true
	return false

static func env_roof(m: C.M, rects: Array, roof: String, ropts := {}) -> Dictionary:
	var st: Dictionary = ROOF[roof]
	var prof: String = st.prof
	var lift: float = ropts.get("lift", st.lift)
	for r in rects:
		var fr := []
		for q in 4:
			var px: float = r.x1 if q % 2 == 1 else r.x0; var pz: float = r.z1 if q >= 2 else r.z0
			var free := true
			for o in rects:
				if o != r and px > o.x0 - 0.05 and px < o.x1 + 0.05 and pz > o.z0 - 0.05 and pz < o.z1 + 0.05: free = false
			fr.append(free)
		r.free = fr
	var step: float = ropts.get("step", 0.62 if prof == "giwa" else 0.8)
	var xs := []; var zs := []
	for r in rects:
		xs.append(r.x0); xs.append(r.x1); xs.append((r.x0 + r.x1) / 2)
		zs.append(r.z0); zs.append(r.z1); zs.append((r.z0 + r.z1) / 2)
	var X := _grid(xs, step); var Z := _grid(zs, step)
	var nx := X.size(); var nz := Z.size()
	var Hc := {}
	var Hf := func(i: int, j: int) -> float:
		var key := i * 4096 + j
		if not Hc.has(key): Hc[key] = height(rects, prof, lift, X[i], Z[j])
		return Hc[key]
	var inc := {}
	for j in nz - 1:
		for i in nx - 1:
			if _inside(rects, (X[i] + X[i + 1]) / 2, (Z[j] + Z[j + 1]) / 2): inc[i * 4096 + j] = true
	var R := m.rng
	var g := Kit.Geo.new()
	var e := Kit.Geo.new()
	var c_top := Kit.hex(st.top); var c_low := Kit.hex(st.low)
	var y_lo := INF; var y_hi := -INF
	for r in rects: y_lo = minf(y_lo, r.eave); y_hi = maxf(y_hi, r.eave + r.rise)
	var thick: float = ropts.get("thick", st.thick)
	var dn := Vector3(0, -thick, 0)
	for key in inc:
		var i: int = key / 4096; var j: int = key % 4096
		var x0 := X[i]; var x1 := X[i + 1]; var z0 := Z[j]; var z1 := Z[j + 1]
		var a := Vector3(x0, Hf.call(i, j), z0); var b := Vector3(x1, Hf.call(i + 1, j), z0)
		var c := Vector3(x0, Hf.call(i, j + 1), z1); var d := Vector3(x1, Hf.call(i + 1, j + 1), z1)
		var gx := (b.y + d.y - a.y - c.y); var gz := (c.y + d.y - a.y - b.y)
		var side := absf(gx) > absf(gz)
		var U := func(p: Vector3) -> Vector2:
			return Vector2((p.z - z0) / (z1 - z0), (p.x - x0) / (x1 - x0)) if side else Vector2((p.x - x0) / (x1 - x0), (p.z - z0) / (z1 - z0))
		var hm := height(rects, prof, lift, (x0 + x1) / 2, (z0 + z1) / 2)
		var base := g.pos.size()
		if absf((a.y + d.y) / 2 - hm) <= absf((b.y + c.y) / 2 - hm):
			g.tri(a, c, d, U.call(a), U.call(c), U.call(d)); g.tri(a, d, b, U.call(a), U.call(d), U.call(b))
		else:
			g.tri(a, c, b, U.call(a), U.call(c), U.call(b)); g.tri(b, c, d, U.call(b), U.call(c), U.call(d))
		var jit := (R.next() - 0.5) * 0.04
		for q in 6:
			var tt := clampf((g.pos[base + q].y - y_lo) / maxf(0.1, y_hi - y_lo), 0, 1)
			var cc := c_low.lerp(c_top, tt)
			g.col[base + q] = Color(maxf(0, cc.r + jit), maxf(0, cc.g + jit), maxf(0, cc.b + jit))
		# 처마 끝 띠
		var nb := [[0, -1, a, b, Vector3(0, 0, -1)], [0, 1, d, c, Vector3(0, 0, 1)], [-1, 0, c, a, Vector3(-1, 0, 0)], [1, 0, b, d, Vector3(1, 0, 0)]]
		for q in nb:
			var ni: int = i + q[0]; var nj: int = j + q[1]
			if ni >= 0 and nj >= 0 and ni < nx - 1 and nj < nz - 1 and inc.has(ni * 4096 + nj): continue
			var p1: Vector3 = q[2]; var p2: Vector3 = q[3]
			C.qf(e, p1, p2, p2 + dn, p1 + dn, q[4])
	m.add("p", st.key, g, 0.045)
	m.add("p", st.ekey, C.PA(e, st.ecol, 0.03, R), 0.02)
	# 용마루
	if ropts.get("ridge", true):
		for r in rects:
			var hb: float = ((r.z1 - r.z0) if r.axis == "x" else (r.x1 - r.x0)) / 2
			var ha: float = ((r.x1 - r.x0) if r.axis == "x" else (r.z1 - r.z0)) / 2
			var half: float = ha - 0.15 if r.gable else maxf(0.0, ha - hb / r.k)
			if half < 0.2: continue
			var cx: float = (r.x0 + r.x1) / 2; var cz: float = (r.z0 + r.z1) / 2
			var y: float = r.eave + r.rise
			var rot := 0.0 if r.axis == "x" else PI / 2
			if prof == "giwa":
				m.add("p", "flat", Kit.xf(C.P(Kit.box(half * 2 + 0.3, 0.3, 0.38), C.ROOF_DARK, 0x2d2e30, 0.02), cx, y + 0.08, cz, 0, rot, 0), 0.03)
				for s in [-1, 1]:
					var tip := Kit.xf(Kit.box(0.5, 0.26, 0.34), 0, 0, 0, 0, 0, s * 0.55)
					Kit.xf(tip, s * (half + 0.2), y + 0.22, 0)
					Kit.xf(tip, cx, 0, cz, 0, rot, 0)
					m.add("p", "flat", C.P(tip, C.ROOF_DARK, 0x2d2e30, 0.02), 0.03)
			else:
				var rc: Array = [0xb39d6c, 0x8f7b52] if roof == "thatch" else st.ecol
				m.add("p", "thatch", C.PA(Kit.xf(Kit.cyl(0.18, 0.18, half * 2 + 0.2, 8, 0, 0, 0, 0, 0, PI / 2), cx, y - 0.04, cz, 0, rot, 0), rc, 0.03, R), 0.025)
	# 새끼 그물(제주·해안·북부): 높이장을 따라 늘어뜨린 줄
	var rope: float = ropts.get("rope", 0.0)
	if rope > 0.0:
		_ropes(m, rects, prof, lift, X[0], X[nx - 1], Z[0], Z[nz - 1], rope, ropts.get("rope_dir", "both"), ropts.get("rope_stones", false))
	return { rects = rects, x0 = X[0], x1 = X[nx - 1], z0 = Z[0], z1 = Z[nz - 1] }

static func _ropes(m: C.M, rects: Array, prof: String, lift: float, x0: float, x1: float, z0: float, z1: float, gap: float, dir: String, stones: bool) -> void:
	var R := m.rng
	var g := Kit.Geo.new()
	var w := 0.045
	var st := []
	var segs := 0.5
	var H := func(x: float, z: float) -> float:
		return height(rects, prof, lift, x, z) + 0.04 if _inside(rects, x, z, 0.01) else -INF
	# x방향 줄(z 고정)
	if dir in ["both", "x"]:
		var zz := z0 + gap / 2
		while zz < z1:
			var x := x0
			var prev_in := false
			while x < x1:
				var xb := minf(x + segs, x1)
				var ya: float = H.call(x, zz); var yb: float = H.call(xb, zz)
				if ya > -INF and yb > -INF:
					C.qf(g, Vector3(x, ya, zz - w), Vector3(xb, yb, zz - w), Vector3(xb, yb, zz + w), Vector3(x, ya, zz + w), Vector3.UP)
					if not prev_in and stones: st.append(Vector3(x, ya - 0.3, zz))
					prev_in = true
				else:
					if prev_in and stones: st.append(Vector3(x, H.call(x - segs, zz) - 0.3, zz))
					prev_in = false
				x = xb
			zz += gap
	if dir in ["both", "z"]:
		var xx := x0 + gap / 2
		while xx < x1:
			var z := z0
			var prev_in := false
			while z < z1:
				var zb := minf(z + segs, z1)
				var ya: float = H.call(xx, z); var yb: float = H.call(xx, zb)
				if ya > -INF and yb > -INF:
					C.qf(g, Vector3(xx - w, ya + 0.01, z), Vector3(xx + w, ya + 0.01, z), Vector3(xx + w, yb + 0.01, zb), Vector3(xx - w, yb + 0.01, zb), Vector3.UP)
					if not prev_in and stones: st.append(Vector3(xx, ya - 0.3, z))
					prev_in = true
				else:
					if prev_in and stones: st.append(Vector3(xx, H.call(xx, z - segs) - 0.3, z))
					prev_in = false
				z = zb
			xx += gap
	m.add("p", "flat", C.P(g, 0x5e4e38, 0x4a3d2c, 0.03, R), 0)
	if stones and st.size() > 0:
		var sg := []
		for p in st:
			if p.y < -1e6: continue
			sg.append(C.P(Kit.xf(Kit.lump(R.between(0.1, 0.14), 0, R, 0.3, 0.9), p.x, p.y, p.z), 0x6f6b64, 0x4f4b45, 0.06, R))
		m.add("p", "stone", Kit.merge(sg), 0.012)

# ---------------------------------------------------------------------------
# 묶음(compound) 도우미: 조각 목록 → village/house_compound.compose 재사용
# ---------------------------------------------------------------------------
static func e(tag: String, kit: String, p: Dictionary, x: float, z: float, ry := 0.0) -> Dictionary:
	return { tag = tag, kit = kit, params = p, x = x, z = z, ry = ry }

# 둘레 담 5토막(북·서·동·남서·남동, 남쪽 가운데 문 자리 반폭 gh). kind: village 담 kit 이름 + params
static func enclose(L: Array, seed: int, x0: float, x1: float, z0: float, z1: float, gh: float, kit: String, p0: Dictionary, skip := []) -> void:
	var segs := [["wall_n", x0, z0, x1, z0], ["wall_w", x0, z0, x0, z1], ["wall_e", x1, z0, x1, z1], ["wall_sw", x0, z1, -gh, z1], ["wall_se", gh, z1, x1, z1]]
	var i := 0
	for s in segs:
		i += 1
		if s[0] in skip: continue
		var p := p0.duplicate()
		p.seed = seed + i; p.ax = s[1]; p.az = s[2]; p.bx = s[3]; p.bz = s[4]
		L.append(e(s[0], kit, p, 0, 0, 0))

static func compound(entries: Array, name: String, fp: Vector2, params: Dictionary, self_kit: String) -> Dictionary:
	var HC := preload("res://kit/village/house_compound.gd")
	var res: Dictionary = HC.compose(entries, name, fp)
	if not params.get("merged", false):
		var ps := []
		for en in entries:
			var q: Dictionary = en.duplicate()
			q.xform = Transform3D(Basis(Vector3.UP, en.ry), Vector3(en.x, 0, en.z))
			ps.append(q)
		res.pieces = ps
	return res

static func finish(m: C.M, name: String, fp: Vector2) -> Dictionary:
	return m.result(name, fp, true)

# 도시 담(한양·평양 골목): 사괴석 아랫단 + 회벽 + 기와 갓. 두 점 사이
static func city_wall(m: C.M, ax: float, az: float, bx: float, bz: float, h := 2.2) -> void:
	var len := Vector2(bx - ax, bz - az).length()
	var R := m.rng
	var old := m.xform
	m.xform = old * C.seg_xform(ax, az, bx, bz)
	m.add("p", "stone", C.PA(Kit.box(len, 1.0, 0.5, 0, 0.5, 0), SAGOE, 0.05, R), 0.025)
	m.add("p", "mud", C.PA(Kit.box(len, h - 1.0, 0.42, 0, 1.0 + (h - 1.0) / 2, 0), C.PLASTER, 0.03, R), 0.02)
	var g := Kit.Geo.new()
	var cw := 0.48; var rh := 0.3
	var segs := maxi(1, roundi(len / 0.5))
	for i in segs:
		var x0 := -len / 2 - 0.1 + (len + 0.2) * i / segs; var x1 := -len / 2 - 0.1 + (len + 0.2) * (i + 1) / segs
		for s in [-1, 1]:
			C.qf(g, Vector3(x0, h, s * cw), Vector3(x1, h, s * cw), Vector3(x1, h + rh, 0), Vector3(x0, h + rh, 0), Vector3(0, 1, s))
	m.add("p", "tile", C.P(g, 0xd0d0cb, 0xa9a8a2, 0.03, R), 0.03)
	m.add("p", "flat", C.P(Kit.box(len + 0.3, 0.12, 0.2, 0, h + rh, 0), C.ROOF_DARK), 0.02)
	m.xform = old
	preload("res://kit/village/stone_wall.gd").add_line_collider(m, ax, az, bx, bz, 0.3)
