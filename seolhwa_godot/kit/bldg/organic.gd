# 고을 짜임 생성기(town-organic) — 길이 먼저, 필지가 길을 따라, 집이 필지를 따라. 씨앗이 같으면 결과가 같다(결정적).
#   쓰는 곳: tools/bldg/organic.gd(구역 설정 → placement_*_town.json). 키트가 아니다(놓는 것은 bldg/lot · bldg/building · village/* · nature/*).
#
#   참고(docs/reports/town-reference-acon.md): ACON3D 조선 성곽 도시·마을 세트의 전경 그림(배치·비례만 참고, 모델은 쓰지 않음) +
#   아카이브 802 경기감영도 · 947 동래부순절도 · 24~26 신윤복 골목 · 624 함평 마을. 뽑은 규칙:
#     ① 길 위계: 큰길(기존 region 길, 4~7m) → 갈래길(3~4m, 굽고 갈라짐) → 고샅(2~2.8m, 막다른 길도) — 바둑판이 아니다.
#     ② 길은 땅을 따라 굽는다(등고선 쪽으로 휨) · 문 앞·장터·우물·갈림목은 넓어져 마당(plaza)이 된다.
#     ③ 필지는 길에 붙어 길을 따라 이어지고, 너비·깊이·옆선 기울기가 제각각(사다리꼴·오각) — 담이 필지 가장자리를 따라 꺾인다.
#     ④ 대문은 길 쪽, 몸채는 길 쪽을 보되 몇 도씩 어긋남 · 담과 담 사이 1m 안팎 틈(뒷길·처마 물받이).
#     ⑤ 가운데(문 앞·큰길)는 촘촘하고 작은 필지·기와집·가게, 밖으로 갈수록 필지가 크고 듬성하며 초가·싸리울·텃밭·짚가리.
#     ⑥ 큰 나무(느티·소나무)가 마당·길모퉁이·마당 마당(plaza)에, 우물은 갈림목·마당에.
#
#   구역 설정(cfg): { seed, area: [[x,z]…](다각형), trunks: [{pts, w}](고정 큰길 — 다시 짓지 않음, 필지가 붙음),
#     keep: [{c:[x,z], r}](비울 자리 — 남기는 옛 항목·이야기 자리), rivers: [{pts, w}], plazas: [{c, r, kind}],
#     centers: [{c, r, w}](촘촘함 중심), region, branch: {…}(갈래길 매개), cls_bias }
#   결과: { streets: [{pts, w, kind}], lots: [{poly, front:[i0,i1], street, zone}], items: [placement 항목], alleys: [{points, width_m}] }
extends RefCounted
const CP := preload("res://kit/bldg/compound.gd")
const B := preload("res://kit/bldg/building.gd")
const S := preload("res://kit/bldg/_spec.gd")
const GT := preload("res://kit/bldg/gate.gd")

# ---- 2D 기하 -------------------------------------------------------------------------------------------
static func pip(poly: Array, p: Vector2) -> bool:
	var c := false
	var n := poly.size()
	var j := n - 1
	for i in n:
		var a: Vector2 = poly[i]; var b: Vector2 = poly[j]
		if ((a.y > p.y) != (b.y > p.y)) and (p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x): c = not c
		j = i
	return c

static func seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-9), 0.0, 1.0)
	return p.distance_to(a + ab * t)

# 줄(점 배열)까지 거리 + 가장 가까운 마디 i·t·점
static func line_near(p: Vector2, pts: Array) -> Dictionary:
	var best := { d = INF, i = 0, t = 0.0, q = Vector2.ZERO }
	for i in pts.size() - 1:
		var a: Vector2 = pts[i]; var b: Vector2 = pts[i + 1]
		var ab := b - a
		var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-9), 0.0, 1.0)
		var q := a + ab * t
		var d := p.distance_to(q)
		if d < best.d: best = { d = d, i = i, t = t, q = q }
	return best

static func segs_cross(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> bool:
	var o := func(p: Vector2, q: Vector2, r: Vector2) -> float: return (q - p).cross(r - p)
	var d1: float = o.call(a, b, c); var d2: float = o.call(a, b, d); var d3: float = o.call(c, d, a); var d4: float = o.call(c, d, b)
	return ((d1 > 0) != (d2 > 0)) and ((d3 > 0) != (d4 > 0))

static func seg_seg_dist(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> float:
	if segs_cross(a, b, c, d): return 0.0
	return minf(minf(seg_dist(a, c, d), seg_dist(b, c, d)), minf(seg_dist(c, a, b), seg_dist(d, a, b)))

static func poly_dist(A: Array, Bp: Array) -> float:
	for p in A:
		if pip(Bp, p): return 0.0
	for p in Bp:
		if pip(A, p): return 0.0
	var best := INF
	for i in A.size():
		for j in Bp.size():
			best = minf(best, seg_seg_dist(A[i], A[(i + 1) % A.size()], Bp[j], Bp[(j + 1) % Bp.size()]))
	return best

static func poly_line_dist(poly: Array, pts: Array) -> float:
	var best := INF
	for p in pts:
		if pip(poly, p): return 0.0
	for i in poly.size():
		for j in pts.size() - 1:
			best = minf(best, seg_seg_dist(poly[i], poly[(i + 1) % poly.size()], pts[j], pts[j + 1]))
	return best

static func area(poly: Array) -> float:
	var s := 0.0
	for i in poly.size(): s += (poly[i] as Vector2).cross(poly[(i + 1) % poly.size()])
	return s / 2.0

# 다각형 안으로 d만큼 줄임(볼록·완만한 오목 — 이웃 변 선의 교점). 반시계/시계 모두
static func inset(poly: Array, d: float) -> Array:
	var n := poly.size()
	var sg := 1.0 if area(poly) > 0 else -1.0
	var lines := []
	for i in n:
		var a: Vector2 = poly[i]; var b: Vector2 = poly[(i + 1) % n]
		var t := (b - a).normalized()
		var nn := Vector2(-t.y, t.x) * sg   # 안쪽(반시계면 왼쪽)
		lines.append([a + nn * d, t])
	var out := []
	for i in n:
		var l0: Array = lines[(i - 1 + n) % n]; var l1: Array = lines[i]
		var p0: Vector2 = l0[0]; var d0: Vector2 = l0[1]; var p1: Vector2 = l1[0]; var d1: Vector2 = l1[1]
		var den := d0.cross(d1)
		if absf(den) < 1e-6: out.append(p1); continue
		var t := (p1 - p0).cross(d1) / den
		out.append(p0 + d0 * t)
	return out

static func rot(v: Vector2, a: float) -> Vector2:
	# 게임 규칙: 로컬 (x, z) → 월드 (x cos a + z sin a, −x sin a + z cos a)
	return Vector2(v.x * cos(a) + v.y * sin(a), -v.x * sin(a) + v.y * cos(a))

static func unrot(v: Vector2, a: float) -> Vector2:
	return rot(v, -a)

# 줄 다시 찍기(간격 step)
static func resample(pts: Array, step: float) -> Array:
	var out := [pts[0]]
	var acc := 0.0
	for i in pts.size() - 1:
		var a: Vector2 = pts[i]; var b: Vector2 = pts[i + 1]
		var L := a.distance_to(b)
		var s := step - acc
		while s <= L:
			out.append(a.lerp(b, s / L)); s += step
		acc = L - (s - step)
	if (out[out.size() - 1] as Vector2).distance_to(pts[pts.size() - 1]) > step * 0.3: out.append(pts[pts.size() - 1])
	return out

static func length(pts: Array) -> float:
	var L := 0.0
	for i in pts.size() - 1: L += (pts[i] as Vector2).distance_to(pts[i + 1])
	return L

# 줄 위 길이 s 자리(점·방향)
static func at(pts: Array, s: float) -> Array:
	var acc := 0.0
	for i in pts.size() - 1:
		var a: Vector2 = pts[i]; var b: Vector2 = pts[i + 1]
		var L := a.distance_to(b)
		if acc + L >= s or i == pts.size() - 2:
			var t := clampf((s - acc) / maxf(L, 1e-6), 0.0, 1.0)
			return [a.lerp(b, t), (b - a).normalized()]
		acc += L
	return [pts[0], ((pts[1] as Vector2) - pts[0]).normalized()]

# ---- 생성기 --------------------------------------------------------------------------------------------
var cfg: Dictionary
var r: Kit.Rng
var hf: Callable          # 높이(x, z) → y (없으면 평지)
var area_poly: Array
var streets := []        # { pts: Array[Vector2], w, kind: trunk|street|alley, parent }
var plazas := []         # { c, r, kind }
var lots := []           # { poly, fr: [a, b](앞 변 두 점), n(바깥 = 길 쪽 법선), street, zone, side }
var keep := []           # { c, r }
var keep_poly := []      # [Vector2…] 큰 건물 자리
var rivers := []
var items := []
var log := []
var terraces := 0

func _init(c: Dictionary, height: Callable = Callable()) -> void:
	cfg = c
	r = Kit.Rng.new(int(c.get("seed", 1)) * 7717 + 13)
	hf = height
	area_poly = []
	for p in c.area: area_poly.append(Vector2(float(p[0]), float(p[1])))
	for k in c.get("keep", []): keep.append({ c = Vector2(float(k.c[0]), float(k.c[1])), r = float(k.r) })
	# 큰 건물 자리(관아·객사·향교 등 — 고을 빌더 settlement.gd가 먼저 놓은 것): 다각형. 필지·길이 들지 않는다
	for kp in c.get("keep_poly", []):
		var pp := []
		for q in kp: pp.append(Vector2(float(q[0]), float(q[1])))
		keep_poly.append(pp)
	# 물길: 구역 둘레 30m 안 마디만(이어진 토막별로)
	var abb := _bbox(area_poly).grow(30.0)
	for rv in c.get("rivers", []):
		var pts := []
		for p in rv.pts:
			var v := Vector2(float(p[0]), float(p[1]))
			if abb.has_point(v): pts.append(v)
			elif pts.size() >= 2: rivers.append({ pts = pts, w = float(rv.w) }); pts = []
			else: pts = []
		if pts.size() >= 2: rivers.append({ pts = pts, w = float(rv.w) })
	for t in c.get("trunks", []):
		var pts := []
		for p in t.pts: pts.append(Vector2(float(p[0]), float(p[1])))
		streets.append({ pts = resample(pts, 3.0), w = float(t.w), kind = "trunk", parent = -1, id = String(t.get("id", "trunk")) })
	for pz in c.get("plazas", []):
		plazas.append({ c = Vector2(float(pz.c[0]), float(pz.c[1])), r = float(pz.r), kind = String(pz.get("kind", "plaza")) })

func _h(p: Vector2) -> float:
	return float(hf.call(p.x, p.y)) if hf.is_valid() else 0.0

# 촘촘함 0(바깥) ~ 1(가운데)
func density(p: Vector2) -> float:
	var d := float(cfg.get("base_density", 0.25))
	for c in cfg.get("centers", []):
		var cc := Vector2(float(c.c[0]), float(c.c[1]))
		var k := clampf(1.0 - p.distance_to(cc) / float(c.r), 0.0, 1.0)
		d = maxf(d, float(c.get("w", 1.0)) * (k * k * (3.0 - 2.0 * k)))
	return d

func _blocked(p: Vector2, pad: float) -> bool:
	if not pip(area_poly, p): return true
	for kp in keep_poly:
		if pip(kp, p) or _poly_edge_d(kp, p) < pad: return true
	for k in keep:
		if p.distance_to(k.c) < k.r + pad: return true
	for rv in rivers:
		if line_near(p, rv.pts).d < rv.w / 2 + 4.0 + pad: return true
	for pz in plazas:
		if p.distance_to(pz.c) < pz.r + pad * 0.5: return true
	return false

# ① 갈래길 키우기: 큰길(·갈래길)에서 옆으로 뻗어 굽어 가다가 다른 길에 닿으면 T자로 잇고, 밖·막힌 데서 멈춘다
func grow_streets() -> void:
	var bc: Dictionary = cfg.get("branch", {})
	for pass_i in 2:
		var kind := "street" if pass_i == 0 else "alley"
		var parents := []
		for i in streets.size():
			var s: Dictionary = streets[i]
			if pass_i == 0 and s.kind == "trunk": parents.append(i)
			if pass_i == 1 and s.kind in ["street", "trunk"]: parents.append(i)
		var gap_a: float = float(bc.get("gap_a" if pass_i == 0 else "alley_gap_a", 30.0 if pass_i == 0 else 24.0))
		var gap_b: float = float(bc.get("gap_b" if pass_i == 0 else "alley_gap_b", 50.0 if pass_i == 0 else 40.0))
		for pi in parents:
			var par: Dictionary = streets[pi]
			var L := length(par.pts)
			for side in [-1.0, 1.0]:
				var s := r.between(gap_a * 0.4, gap_a)
				while s < L - 8.0:
					var pr: float = float(bc.get("p", 0.8)) if pass_i == 0 else float(bc.get("alley_p", 0.55))
					if par.kind == "trunk" and pass_i == 1: pr *= 0.5
					if r.next() < pr: _grow_one(pi, s, side, kind)
					s += r.between(gap_a, gap_b)

func _grow_one(pi: int, s0: float, side: float, kind: String) -> void:
	var par: Dictionary = streets[pi]
	var bc: Dictionary = cfg.get("branch", {})
	var a: Array = at(par.pts, s0)
	var p0: Vector2 = a[0]; var t0: Vector2 = a[1]
	var nrm := Vector2(-t0.y, t0.x) * side
	var w: float = r.between(3.0, 4.0) if kind == "street" else r.between(2.2, 2.8)
	var Lmax: float = r.between(float(bc.get("len_a", 45.0)), float(bc.get("len_b", 110.0))) if kind == "street" else r.between(14.0, 42.0)
	var head := nrm.rotated(r.between(-0.42, 0.42))
	var start := p0 + nrm * (float(par.w) / 2)
	if _blocked(start + head * 3.0, 1.0): return
	# 시작 자리 둘레에 다른 갈래 시작이 너무 가까우면 버림(같은 쪽 18m 안)
	for s in streets:
		if s.kind == "trunk": continue
		if (s.pts[0] as Vector2).distance_to(start) < (float(cfg.get("street_spacing", 26.0)) * 0.7 if kind == "street" else 12.0): return
	var pts := [start]   # 부모 길 가장자리에서 시작(부모 가운데 줄 p0을 넣으면 그 토막이 부모 길 띠를 덮는다)
	var p := start
	var turn := 0.0
	var step := 4.0
	var joined := -1
	var dist := 0.0
	while dist < Lmax:
		# 굽음: 매끈한 무작위 꺾임 + 땅 기울기를 따라(등고선 쪽으로)
		turn = turn * 0.7 + r.between(-0.11, 0.11)
		head = head.rotated(turn).normalized()
		if hf.is_valid():
			var g := Vector2(_h(p + Vector2(2, 0)) - _h(p - Vector2(2, 0)), _h(p + Vector2(0, 2)) - _h(p - Vector2(0, 2))) / 4.0
			if g.length() > 0.02:
				var cont := Vector2(-g.y, g.x).normalized()
				if cont.dot(head) < 0: cont = -cont
				head = head.lerp(cont, clampf(g.length() * 3.0, 0.0, 0.35)).normalized()
		var q := p + head * step
		if _blocked(q, 1.5): break
		# 다른 길에 닿음 → 이어 붙이고 멈춤(T자). 갈래끼리 나란히 너무 가까우면(필지 두 줄이 들 자리 없음) 멈춤
		var hit := false
		for j in streets.size():
			if j == pi and dist < 12.0: continue
			var o: Dictionary = streets[j]
			var nr: Dictionary = line_near(q, o.pts)
			var lim: float = float(o.w) / 2 + w / 2 + 4.0
			if nr.d < lim:
				var dirv: Vector2 = (nr.q as Vector2) - p
				if dirv.normalized().dot(head) > 0.35 and dist > 10.0:
					pts.append(nr.q); joined = j
				hit = true; break
			# 나란히: 옆 22m 안에 다른 갈래(필지 두 줄 깊이보다 좁음)
			if j != pi and nr.d < (float(cfg.get("street_spacing", 26.0)) if kind == "street" else float(cfg.get("alley_spacing", 15.0))) and dist > 6.0:
				var tj: Vector2 = ((o.pts[mini(nr.i + 1, o.pts.size() - 1)] as Vector2) - o.pts[nr.i]).normalized()
				if absf(tj.dot(head)) > 0.75: hit = true; break
		if hit: break
		pts.append(q); p = q; dist += step
	if dist < (16.0 if kind == "street" else 10.0) and joined < 0: return
	streets.append({ pts = resample(pts, 3.0), w = w, kind = kind, parent = pi, joined = joined, id = "%s%d" % [kind, streets.size()] })

# 갈림목·길 끝 마당(plaza): 큰길–갈래 갈림목에 몇 개(우물·정자나무 자리)
func auto_plazas() -> void:
	for s in streets:
		if s.kind != "street": continue
		if r.next() < float(cfg.get("junction_plaza_p", 0.35)):
			var c: Vector2 = (s.pts[1] as Vector2)
			var ok := true
			for pz in plazas:
				if pz.c.distance_to(c) < pz.r + 20.0: ok = false
			if ok: plazas.append({ c = c + ((s.pts[2] as Vector2) - (s.pts[1] as Vector2)).normalized() * 3.0, r = r.between(5.0, 7.0), kind = "junction" })

# ② 필지: 길 양쪽 가장자리를 따라 걸으며 앞 변(길 따라 굽음)·깊이·옆선 기울기를 제각각 정한다
# ②' 필지(보로노이 띠): 땅 칸마다 가장 가까운 길(·쪽)을 정하고, 길 양쪽 띠를 앞 변 길이로 자른다 — 뒤는 다른 길 띠와 만나는 데까지(등을 맞댄 필지).
#   빈 땅 없이 블록이 메워지고, 길이 휘면 옆선이 부채꼴로 벌어지거나 모여 필지 꼴이 제각각이 된다.
var _own := {}      # Vector2i(칸) → [si, side]
var _cum := []      # 길마다 누적 길이
func _own_grid() -> void:
	_cum = []
	for st in streets:
		var c := [0.0]
		for i in st.pts.size() - 1: c.append(float(c[c.size() - 1]) + (st.pts[i] as Vector2).distance_to(st.pts[i + 1]))
		_cum.append(c)
	var sbb := []
	for st in streets:
		var b := Rect2(st.pts[0], Vector2.ZERO)
		for p in st.pts: b = b.expand(p)
		sbb.append(b.grow(40.0))
	var bb := _bbox(area_poly)
	var y := floorf(bb.position.y)
	while y < bb.end.y:
		var x := floorf(bb.position.x)
		while x < bb.end.x:
			var p := Vector2(x + 0.5, y + 0.5)
			x += 1.0
			if not pip(area_poly, p): continue
			var best := INF; var bs := -1; var bside := 0.0
			for si in streets.size():
				if not (sbb[si] as Rect2).has_point(p): continue
				var st: Dictionary = streets[si]
				var nr: Dictionary = line_near(p, st.pts)
				var de: float = float(nr.d) - float(st.w) / 2
				if de < best:
					best = de; bs = si
					var a: Vector2 = st.pts[nr.i]; var b: Vector2 = st.pts[mini(nr.i + 1, st.pts.size() - 1)]
					bside = signf((b - a).cross(p - a))
			if bs < 0 or best < 0.3 or best > 40.0: continue
			if _blocked(p, 0.3): continue   # 막힌 칸(큰 건물·물·비울 자리)은 띠에서 뺀다 — 깊이 재기가 칸만 본다
			_own[Vector2i(int(floorf(p.x)), int(floorf(p.y)))] = [bs, bside]
		y += 1.0

func _owned(p: Vector2, si: int, side: float) -> bool:
	var o = _own.get(Vector2i(int(floorf(p.x)), int(floorf(p.y))))
	return o != null and int(o[0]) == si and float(o[1]) == side

# 길 si의 side 쪽, 자리 s에서 앞(물림 bk) → 뒤로 띠가 이어지는 깊이
func _depth_at(si: int, side: float, s: float, bk: float) -> float:
	var st: Dictionary = streets[si]
	var a: Array = at(st.pts, s)
	var n := Vector2(-(a[1] as Vector2).y, (a[1] as Vector2).x) * side
	var F: Vector2 = (a[0] as Vector2) + n * (float(st.w) / 2 + bk)
	var k := 0.0
	# 길이 구역 가장자리에 붙어 앞 2.5m가 구역 밖이면 그 너머부터 잰다(구역 경계가 큰길 옆 몇 m 안쪽일 때)
	while k < 2.5 and not _owned(F + n * (k + 0.5), si, side) and not _own.has(Vector2i(int(floorf((F + n * (k + 0.5)).x)), int(floorf((F + n * (k + 0.5)).y)))): k += 0.5
	if k >= 2.5: k = 0.0
	while k < 40.0:
		var p := F + n * (k + 0.5)
		if not _owned(p, si, side):
			if k == 0.0 and OS.has_environment("ORG_DBG3"): print("DBGD p=%s own=%s blocked=%s" % [str(p), str(_own.get(Vector2i(int(floorf(p.x)), int(floorf(p.y))))), _blocked(p, 0.3)])
			break
		k += 0.5
	return k

func cut_lots_v() -> void:
	_own_grid()
	var order := []
	for k in ["trunk", "street", "alley"]:
		for i in streets.size():
			if streets[i].kind == k: order.append(i)
	for si in order:
		var st: Dictionary = streets[si]
		var L := length(st.pts)
		for side in [-1.0, 1.0]:
			var s := 1.0 if st.kind == "trunk" else float(st.w) + 1.0
			while s < L - 6.0:
				var a0: Array = at(st.pts, s)
				var p: Vector2 = a0[0]
				# 이 쪽 앞 4m가 구역 밖이면 빨리 건너뜀(큰길은 구역 밖까지 뻗는다)
				var pr: Vector2 = p + Vector2(-(a0[1] as Vector2).y, (a0[1] as Vector2).x) * side * (float(st.w) / 2 + 4.0)
				if not pip(area_poly, pr): s += 3.0; continue
				var den := density(p)
				if r.next() < lerpf(float(cfg.get("empty_out", 0.22)), float(cfg.get("empty_in", 0.04)), den) * 0.6:
					s += r.between(4.0, 10.0); continue
				var fr_in: Array = cfg.get("front_in", [14.0, 17.5])
				var f: float = lerpf(r.between(15.5, 20.0), r.between(float(fr_in[0]), float(fr_in[1])), den)   # 초가 3칸(처마 포함 약 11m) + 담 안 여유가 드는 너비
				if st.kind == "alley": f *= 0.95
				# 종류를 먼저 고르고 그에 맞는 앞 너비(기와집·양반가는 몸채가 길어 넓게)
				var t0 := _pick_type(den, {})
				if st.kind == "trunk" and r.next() < float(cfg.get("trunk_shop", 0.0)): t0 = "shop"   # 시전 거리: 큰길가 필지는 가게채
				if t0 == "shop" and st.kind != "trunk": t0 = "house_g"
				f *= { house_g = 1.3, giwa_house = 1.35, yangban = 1.6, jungnong = 1.2 }.get(t0, 1.0)
				var lot := _strip_lot(si, side, s, f, den)
				if not lot.is_empty(): lot.t = t0
				if not lot.is_empty() and not _accept(lot):
					lot = _strip_lot(si, side, s, f * 1.3, den)
					if not lot.is_empty():
						lot.t = t0
						if not _accept(lot): lot = {}
				if lot.is_empty():
					s += 1.5; continue
				var lg: Array = cfg.get("lot_gap", [0.7, 1.1])
				s += float(lot.flen) + r.between(float(lg[0]), float(lg[1]))

func _strip_lot(si: int, side: float, s: float, f0: float, den: float) -> Dictionary:
	var st: Dictionary = streets[si]
	var L := length(st.pts)
	for fk in [1.0, 0.8]:
		var f: float = minf(f0 * fk, L - 1.0 - s)
		if f < 9.0: return {}
		for bk in [r.between(0.3, 1.1), 2.4, 3.8, 5.2]:
			# 띠 깊이: 앞 변 위 몇 자리에서 재서 가장 얕은 것 — 8.5m 안 되면 이 자리는 버림
			var dmin := INF
			var k := 0.5
			while k <= f - 0.5:
				dmin = minf(dmin, _depth_at(si, side, s + k, bk)); k += 2.0
			dmin = minf(dmin, _depth_at(si, side, s + f - 0.5, bk))
			if dmin < 8.5:
				why["strip_shallow"] = int(why.get("strip_shallow", 0)) + 1
				if OS.has_environment("ORG_DBG2"): print("DBGSTRIP si=%d side=%d s=%.0f bk=%.1f dmin=%.1f" % [si, side, s, bk, dmin])
				continue
			var dc_in: Array = cfg.get("depth_in", [13.5, 18.0])
			var dcap: float = lerpf(r.between(17.0, 25.0), r.between(float(dc_in[0]), float(dc_in[1])), den)
			var d0: float = minf(_depth_at(si, side, s + 0.4, bk), dcap) - 0.4
			var d1: float = minf(_depth_at(si, side, s + f - 0.4, bk), dcap) - 0.4
			d0 = maxf(d0, 8.5); d1 = maxf(d1, 8.5)
			var fr := []; var nn := []
			for q in 3:
				var a: Array = at(st.pts, s + f * q / 2.0)
				var nrm := Vector2(-(a[1] as Vector2).y, (a[1] as Vector2).x) * side
				fr.append((a[0] as Vector2) + nrm * (float(st.w) / 2 + bk)); nn.append(nrm)
			var mid_off := seg_dist(fr[1], fr[0], fr[2])
			for attempt in 6:
				var b0: Vector2 = (fr[0] as Vector2) + (nn[0] as Vector2) * d0
				var b1: Vector2 = (fr[2] as Vector2) + (nn[2] as Vector2) * d1
				var poly := [fr[0]] + ([fr[1]] if mid_off > 0.35 else []) + [fr[2], b1, b0]
				if not segs_cross(fr[0], b0, fr[2], b1) and _lot_ok(poly, si):
					var front_n: Vector2 = -((nn[0] as Vector2) + (nn[2] as Vector2)).normalized()
					return { poly = poly, bb = _bbox(poly), fa = fr[0], fb = fr[2], n = front_n, street = si, zone = den, side = side, flen = f, depth = (d0 + d1) / 2 }
				d0 = maxf(8.5, d0 * 0.88); d1 = maxf(8.5, d1 * 0.88)
	return {}

# ②'' 블록 채우기(perimeter block — 기본): 길마다 양쪽 띠를 끊김 없이 앞 너비로 잘라, 이웃 필지가 옆선을 함께 쓰고(맞담)
#   뒤는 띠 끝(다른 길 띠와 만나는 곳)까지 — 블록이 빈터 없이 필지로 찬다. 옆선은 길 법선, 뒤 선은 띠 깊이를 매끄럽게 한 선.
#   담: 앞(대문)·뒤·시작 옆선은 이 필지가, 끝 옆선은 다음 필지의 시작 옆선이 맡는다(맞담 한 줄).
func cut_lots_blocks() -> void:
	_own_grid()
	var order := []
	for k in ["trunk", "street", "alley"]:
		for i in streets.size():
			if streets[i].kind == k: order.append(i)
	var dmax: float = float(cfg.get("block_depth", 34.0))
	var dmin_ok: float = 7.0
	for si in order:
		var st: Dictionary = streets[si]
		var L := length(st.pts)
		var bk: float = float(cfg.get("block_setback", 0.4))
		for side in [-1.0, 1.0]:
			# 깊이 1m 간격(띠 끝까지, dmax에서 자름) — 이웃과 1.5m 넘게 튀지 않게 매끄럽게
			var ds := []
			var s := 0.5
			while s < L - 0.5:
				ds.append(minf(_depth_at(si, side, s, bk), dmax)); s += 1.0
			for it in 2:
				for i in ds.size():
					var m: float = ds[i]
					if i > 0: m = minf(m, float(ds[i - 1]) + 1.5)
					if i + 1 < ds.size(): m = minf(m, float(ds[i + 1]) + 1.5)
					ds[i] = m
			if OS.has_environment("ORG_DBG5"):
				var hist := {}
				for v in ds: hist[int(float(v) / 5.0) * 5] = int(hist.get(int(float(v) / 5.0) * 5, 0)) + 1
				print("DBGBLK %s side=%d L=%.0f depth_hist=%s" % [String(st.id), side, L, str(hist)])
			# 깊이가 dmin_ok 넘는 이어진 구간(run)마다 앞 너비로 끊김 없이 나눈다
			var i0 := 0
			while i0 < ds.size():
				if float(ds[i0]) < dmin_ok: i0 += 1; continue
				var i1 := i0
				while i1 + 1 < ds.size() and float(ds[i1 + 1]) >= dmin_ok: i1 += 1
				var a0 := 0.5 + i0; var a1 := 0.5 + i1
				var run_len := a1 - a0
				if run_len >= 8.0: _cut_run(si, side, a0, a1, ds, bk)
				i0 = i1 + 1

func _cut_run(si: int, side: float, a0: float, a1: float, ds: Array, bk: float) -> void:
	var st: Dictionary = streets[si]
	var s := a0
	var first := true
	while s < a1 - 0.5:
		var p: Vector2 = at(st.pts, s)[0]
		var den := density(p)
		var t0 := _pick_type(den, {})
		if st.kind == "trunk" and r.next() < float(cfg.get("trunk_shop", 0.0)): t0 = "shop"
		if t0 == "shop" and st.kind != "trunk": t0 = "house_g"
		var fr_in: Array = cfg.get("block_front", [17.0, 23.0])
		var f: float = lerpf(r.between(19.0, 26.0), r.between(float(fr_in[0]), float(fr_in[1])), den)   # 낙안읍성 필지 실측 135~620㎡(가운데 470) — 마당집이 드는 너비
		f *= { house_g = 1.1, giwa_house = 1.15, yangban = 1.4, jungnong = 1.1, shop = 0.6, hut = 0.7 }.get(t0, 1.0)
		var s1: float = minf(s + f, a1)
		if a1 - s1 < 8.0: s1 = a1   # 남는 끝은 이 필지에 붙인다
		var lot := _block_lot(si, side, s, s1, ds, bk, den)
		if lot.is_empty(): s = s1; first = true; continue
		lot.t = t0
		lot.share_end = s1 < a1 - 0.01
		lot.share_start = not first
		lots.append(lot)
		var li := lots.size() - 1
		var it := fill_one(li, lot)
		if it.is_empty() and float(s1 - s) < 22.0 and s1 < a1:
			# 안 들면 앞 너비를 늘려 다시(이웃과 이어 붙임)
			lots.pop_back()
			var s2: float = minf(s1 + 8.0, a1)
			if a1 - s2 < 8.0: s2 = a1
			lot = _block_lot(si, side, s, s2, ds, bk, den)
			if not lot.is_empty():
				lot.t = t0; lot.share_end = s2 < a1 - 0.01; lot.share_start = not first
				lots.append(lot); li = lots.size() - 1
				it = fill_one(li, lot)
				s1 = s2
		if it.is_empty():
			# 그래도 안 들면 밭(텃밭·짚가리)으로 — 블록에 빈터를 남기지 않는다
			it = _fill(li, lot, "field")
		if it.is_empty(): lots.pop_back(); s = s1; first = true; continue
		lot.filled = true
		items.append(it)
		first = false
		s = s1

func _block_lot(si: int, side: float, s0: float, s1: float, ds: Array, bk: float, den: float) -> Dictionary:
	var st: Dictionary = streets[si]
	var front := []; var back := []; var nn := []
	var n_steps := maxi(1, int(ceilf((s1 - s0) / 2.5)))
	for k in n_steps + 1:
		var sv: float = lerpf(s0, s1, float(k) / n_steps)
		var a: Array = at(st.pts, sv)
		var nrm := Vector2(-(a[1] as Vector2).y, (a[1] as Vector2).x) * side
		var F: Vector2 = (a[0] as Vector2) + nrm * (float(st.w) / 2 + bk)
		var di := clampi(int(round(sv - 0.5)), 0, ds.size() - 1)
		var d: float = float(ds[di]) - 0.5   # 뒤 필지와 0.5m 뒷길(처마 물받이) — 등을 맞대는 담 사이
		front.append(F); back.append(F + nrm * d); nn.append(nrm)
	# 앞 변이 거의 곧으면 가운데 점을 줄인다(담 마디 수)
	var fpts := [front[0]]
	for k in range(1, front.size() - 1):
		if seg_dist(front[k], fpts[fpts.size() - 1], front[k + 1]) > 0.25: fpts.append(front[k])
	fpts.append(front[front.size() - 1])
	var bpts := [back[back.size() - 1]]
	for k in range(back.size() - 2, 0, -1):
		if seg_dist(back[k], bpts[bpts.size() - 1], back[k - 1]) > 0.6: bpts.append(back[k])
	bpts.append(back[0])
	var poly := fpts + bpts
	if absf(area(poly)) < 60.0: return {}
	# 옆선이 엇갈리면(안쪽 굽이에서 법선이 모임) 버림
	if segs_cross(front[0], back[0], front[front.size() - 1], back[back.size() - 1]): return {}
	for kp in keep_poly:
		if poly_dist(poly, kp) < 0.6: return {}
	var front_n: Vector2 = -((nn[0] as Vector2) + (nn[nn.size() - 1] as Vector2)).normalized()
	var dsum := 0.0
	for k in front.size(): dsum += (front[k] as Vector2).distance_to(back[k])
	return { poly = poly, bb = _bbox(poly), fa = fpts[0], fb = fpts[fpts.size() - 1], n = front_n, street = si, zone = den, side = side,
		flen = s1 - s0, depth = dsum / front.size(), nfront = fpts.size() - 1, block = true }

func cut_lots() -> void:
	var order := []
	for k in ["trunk", "street", "alley"]:
		for i in streets.size():
			if streets[i].kind == k: order.append(i)
	# 첫 줄: 제 크기 필지(촘촘함에 따라) · 둘째 줄(메우기): 남은 틈에 작은 필지
	for pass_i in 2:
		for si in order:
			var st: Dictionary = streets[si]
			var L := length(st.pts)
			for side in [-1.0, 1.0]:
				var s := 2.0
				if st.kind != "trunk": s = float(st.w) + 1.5   # 갈래 시작 마디(부모 길 가장자리)는 비움
				while s < L - 4.0:
					var a: Array = at(st.pts, s)
					var p: Vector2 = a[0]
					var pr2: Vector2 = p + Vector2(-(a[1] as Vector2).y, (a[1] as Vector2).x) * side * (float(st.w) / 2 + 4.0)
					if not pip(area_poly, pr2): s += 3.0; continue
					var den := density(p)
					if pass_i == 0 and r.next() < lerpf(float(cfg.get("empty_out", 0.22)), float(cfg.get("empty_in", 0.04)), den):
						s += r.between(5.0, 14.0); continue   # 빈터(밭·숲 자리) — 바깥일수록 자주
					if pass_i == 1 and r.next() < lerpf(0.55, 0.1, den):
						s += 3.0; continue
					var f: float
					var d: float
					if pass_i == 0:
						f = lerpf(r.between(15.0, 22.0), r.between(11.5, 16.0), den)
						d = lerpf(r.between(20.0, 30.0), r.between(17.0, 26.0), den)   # 깊게 잡고 막히면 줄인다 — 뒤 필지와 등을 맞대게
						if cfg.has("depth_in"): d = maxf(d, float(cfg.depth_in[1]) * 0.8)
					else:
						f = r.between(11.0, 14.0); d = r.between(14.0, 24.0)
						if cfg.has("depth_in"): d = maxf(d, float(cfg.depth_in[1]) * 0.8)   # 읍내: 깊게 잡고 막히면 줄인다(뒤 필지와 등을 맞대게)
					if st.kind == "alley": f *= 0.92; d *= 0.92
					var lot := _try_lot(si, s, f, d, side, den)
					if not lot.is_empty() and not _accept(lot): lot = {}
					if lot.is_empty():
						s += 1.5 if pass_i == 1 else 2.0; continue
					s += float(lot.flen) + r.between(0.7, 1.2)

func _try_lot(si: int, s: float, f0: float, d0_: float, side: float, den: float) -> Dictionary:
	var st: Dictionary = streets[si]
	var L := length(st.pts)
	for fk in [1.0, 0.78]:
		var f: float = f0 * fk
		if s + f > L - 1.0: f = L - 1.0 - s
		if f < 8.0: return {}
		# 길 가장자리에서 물림 — 막히면(좌판·나무) 더 물려 본다
		for bk in [r.between(0.3, 1.2), 2.4, 3.8, 5.2]:
			var back: float = float(st.w) / 2 + bk
			var fr := []
			var nn := []
			for k in 3:
				var a: Array = at(st.pts, s + f * k / 2.0)
				var nrm := Vector2(-(a[1] as Vector2).y, (a[1] as Vector2).x) * side
				fr.append((a[0] as Vector2) + nrm * back); nn.append(nrm)
			# 앞 변이 거의 곧으면 가운데 점을 뺀다(사각·사다리꼴), 굽으면 오각(앞 변이 길을 따라 꺾임)
			var mid_off := seg_dist(fr[1], fr[0], fr[2])
			var skew0 := r.between(-0.17, 0.17); var skew1 := r.between(-0.17, 0.17)
			var d := d0_
			var j0 := r.between(0.88, 1.1); var j1 := r.between(0.88, 1.1)
			for attempt in 11:
				var d0 := d * j0; var d1 := d * j1
				var b0: Vector2 = (fr[0] as Vector2) + (nn[0] as Vector2).rotated(skew0) * d0
				var b1: Vector2 = (fr[2] as Vector2) + (nn[2] as Vector2).rotated(skew1) * d1
				var poly := [fr[0]] + ([fr[1]] if mid_off > 0.35 else []) + [fr[2], b1, b0]
				# 꼬인 사변형(옆선이 엇갈림)은 버림
				var w0 := why.duplicate()
				var okk := not segs_cross(fr[0], b0, fr[2], b1) and _lot_ok(poly, si)
				if OS.has_environment("ORG_DBG") and String(st.id) == OS.get_environment("ORG_DBG"):
					var dd := {}
					for kk in why: if int(why[kk]) != int(w0.get(kk, 0)): dd[kk] = 1
					print("DBGLOT s=%.0f side=%d bk=%.1f d=%.1f f=%.1f poly=%s -> %s" % [s, side, bk, d, f, str(poly.map(func(v): return Vector2(snappedf(v.x, 0.1), snappedf(v.y, 0.1)))), str(dd) if not okk else "OK"])
				if okk:
					var front_n: Vector2 = -((nn[0] as Vector2) + (nn[2] as Vector2)).normalized()   # 길 쪽(대문이 보는 쪽)
					return { poly = poly, bb = _bbox(poly), fa = fr[0], fb = fr[2], n = front_n, street = si, zone = den, side = side, flen = f, depth = (d0 + d1) / 2 }
				d *= 0.9
				if d < 8.5: break
	return {}

var why := {}
func _no(k: String) -> bool:
	why[k] = int(why.get(k, 0)) + 1
	return false

func _lot_ok(poly: Array, si: int) -> bool:
	if absf(area(poly)) < 70.0: return _no("small")
	for p in poly:
		if not pip(area_poly, p): return _no("area")
	# 다른 필지와 0.9m 이상
	var pb := _bbox(poly).grow(1.0)
	for l in lots:
		if not pb.intersects(l.bb): continue
		if poly_dist(poly, l.poly) < 0.7: return _no("lot")
	# 길 띠(제 길 포함 — 앞 변은 길 가장자리 밖이므로 통과)
	for j in streets.size():
		var o: Dictionary = streets[j]
		if poly_line_dist(poly, o.pts) < float(o.w) / 2 + 0.25: return _no("street_" + String(o.kind))
	for kp in keep_poly:
		if poly_dist(poly, kp) < 1.5: return _no("keep")
	for k in keep:
		for i in poly.size():
			if seg_dist(k.c, poly[i], poly[(i + 1) % poly.size()]) < k.r: return _no("keep")
		if pip(poly, k.c): return _no("keep")
	for pz in plazas:
		if pip(poly, pz.c): return _no("plaza")
		for i in poly.size():
			if seg_dist(pz.c, poly[i], poly[(i + 1) % poly.size()]) < pz.r: return _no("plaza")
	for rv in rivers:
		if poly_line_dist(poly, rv.pts) < rv.w / 2 + 3.0: return _no("river")
	return true

# ③ 필지 채우기 — 표(TABLE)에서 묶음 종류를 고르고, 묶음의 집·마당 것을 필지 틀(앞 변 = 대문 줄)에 맞춰 넣는다.
#   묶음 자체의 네모 둘레 담·대문은 버리고, 필지 다각형 가장자리를 따라 담을 새로 두르고 대문을 앞 변에 낸다.
const TABLE := {
	"dense": [["house_g", 0.26], ["giwa_house", 0.14], ["house_c", 0.26], ["choga_house", 0.12], ["shop", 0.22]],
	"mid": [["choga_house", 0.32], ["house_c", 0.24], ["jungnong", 0.16], ["giwa_house", 0.1], ["house_g", 0.12], ["yangban", 0.06]],
	"outer": [["choga_house", 0.38], ["jungnong", 0.2], ["house_c", 0.16], ["hut", 0.18], ["field", 0.08]],
}
func _pick_type(den: float, lot: Dictionary) -> String:
	var zk := "dense" if den > 0.62 else ("mid" if den > 0.3 else "outer")
	var rows: Array = (cfg.get("table", {}) as Dictionary).get(zk, TABLE[zk])   # 구역마다 표를 바꿀 수 있다(읍성 안: 기와집·양반가 더)
	var tot := 0.0
	for e in rows: tot += float(e[1])
	var x := r.next() * tot
	for e in rows:
		x -= float(e[1])
		if x <= 0.0: return String(e[0])
	return String(rows[0][0])

func fill_lots() -> void:
	var n := 0
	for li in lots.size():
		if lots[li].get("filled", false): n += 1; continue
		var it := fill_one(li, lots[li])
		if it.is_empty(): log.append("lot %d 비움(%.0f㎡)" % [li, absf(area(lots[li].poly))]); continue
		items.append(it); n += 1
	log.append("필지 %d 중 %d 채움 · 필지 거절 %s" % [lots.size(), n, str(why)])

# 필지 하나 채우기: 표에서 종류 → 안 들면 작은 쪽으로(묶음 → 한 채 → 오두막 → 밭)
func fill_one(li: int, lot: Dictionary) -> Dictionary:
	var st: Dictionary = streets[lot.street]
	var t: String = lot.t if lot.has("t") else _pick_type(float(lot.zone), lot)
	if t == "shop" and st.kind != "trunk": t = "house_g"
	if t == "yangban" and (float(lot.flen) < 19.0 or float(lot.depth) < 20.0): t = "giwa_house"
	var it := {}
	# 블록 필지(맞담): 마당을 둘러 몸채·곁채·앞채로 필지를 채운다(ㄱ·ㄷ·ㅁ자 마당집) — 양반가 묶음·밭은 그대로
	if bool(lot.get("block", false)) and t in ["house_c", "house_g", "choga_house", "giwa_house", "jungnong", "shop", "hut"]:
		it = _fill_court(li, lot, t)
	if it.is_empty(): it = _fill(li, lot, t)
	if it.is_empty() and t in ["giwa_house", "yangban"]: it = _fill(li, lot, "house_g")
	if it.is_empty() and t in ["jungnong", "giwa_house", "yangban"]: it = _fill(li, lot, "choga_house")
	if it.is_empty() and t != "hut" and t != "field": it = _fill(li, lot, "house_c")
	if it.is_empty() and (float(lot.zone) < 0.35 or t == "hut"): it = _fill(li, lot, "hut")   # 오두막(싸리울 뒤·옆만)은 바깥에서만
	if it.is_empty() and absf(area(lot.poly)) > 160.0 and float(lot.zone) < 0.45: it = _fill(li, lot, "field")
	return it

# 마당집(courtyard) 채우기: 필지 틀(로컬 +z = 길 쪽)에서 뒤에 몸채, 옆에 곁채(돌려 마당을 봄), 앞에 앞채(가게·헛간·행랑 — 등이 길),
#   가운데 마당을 비우고, 대문은 앞 담의 앞채 비킨 자리. 낙안읍성 실측(필지마다 안채 + 헛간채·아래채·가게채 2~4채)과
#   ACON 성곽도시(담이 맞닿은 ㄱ·ㄷ·ㅁ 마당집)를 따른 것. 덮임 목표: 읍내 35~55%, 마을 20~35%.
func _court_sets(t: String) -> Dictionary:
	var rg: String = cfg.get("region", "south")
	match t:
		"house_g", "giwa_house":
			return { main = [{ type = "giwajip", region = rg, cls = "middle" }], wing = [{ type = "gotgan", region = rg, cls = "middle" }, { type = "araechae", region = rg, cls = "middle" }, { type = "sarang", region = rg, cls = "middle" }],
				front = [{ type = "sarang", region = rg, cls = "middle" }, { type = "haengrang", region = rg, cls = "middle" }, { type = "araechae", region = rg, cls = "middle" }, { type = "gotgan", region = rg, cls = "middle" }], wall = "todam_tile", gate = "pyeong" }
		"shop":
			return { main = [{ type = "giwajip", region = rg, cls = "middle" }, { type = "choga", region = rg, cls = "commoner" }], wing = [{ type = "gotgan", region = rg, cls = "commoner" }],
				front = [{ type = "sijeon", region = rg, cls = "middle" }], wall = "todam_thatch", gate = "none", shopfront = true }
		"hut":
			return { main = [{ type = "choga", region = rg, cls = "poor" }], wing = [{ type = "gotgan", region = rg, cls = "commoner" }], front = [], wall = "fence", gate = "sarip" }
	return { main = [{ type = "choga", region = rg, cls = "commoner" }], wing = [{ type = "araechae", region = rg, cls = "commoner" }, { type = "gotgan", region = rg, cls = "commoner" }, { type = "choga", region = rg, cls = "poor" }],
		front = [{ type = "araechae", region = rg, cls = "commoner" }, { type = "choga", region = rg, cls = "poor" }, { type = "gotgan", region = rg, cls = "commoner" }], wall = _wall_kind("choga_house", float(cfg.get("_den", 0.5))), gate = "chomun" }

func _fill_court(li: int, lot: Dictionary, t: String) -> Dictionary:
	var poly: Array = lot.poly
	var lry: float = atan2((lot.n as Vector2).x, (lot.n as Vector2).y)
	var C := _centroid(poly)
	var ii: float = float(cfg.get("inner_inset", 1.0))
	var inner := inset(poly, ii)
	var loc := []
	for p in poly: loc.append(unrot(p - C, lry))
	var lb := _bbox(loc)   # 로컬: x 길 따라, z 앞(+) 뒤(−)
	var W := func(lx: float, lz: float) -> Vector2: return C + rot(Vector2(lx, lz), lry)
	cfg._den = lot.zone
	var sets := _court_sets(t)
	var seed0: int = int(cfg.get("seed", 1)) * 1000 + li * 7
	var placed := []    # [월드 사각, params, 월드 자리, ry]
	var free := func(rc: Array, gap: float) -> bool:
		for q in placed:
			if poly_dist(rc, q[0]) < gap: return false
		return true
	# 몸채: 뒤에서부터 앞으로 밀며, 가운데 쪽부터 좌우로
	var main_ok := false
	var mains: Array = (sets.main as Array).duplicate()
	mains.append({ type = "choga", region = String(cfg.get("region", "south")), cls = "poor" })   # 좁은 필지: 2칸 오두막 몸채
	for k in 12:
		var mp: Dictionary = (mains[mini(k / 3, mains.size() - 1)] as Dictionary).duplicate()
		mp.seed = seed0 + k
		var bb := _bounds(mp)
		for turn in [0.0, PI / 2, -PI / 2]:   # 좁으면 박공을 길로(옆마당을 봄)
			if main_ok: break
			var ext: Vector2 = bb.size if float(turn) == 0.0 else Vector2(bb.size.y, bb.size.x)
			var zc := lb.position.y + ii + ext.y / 2
			while zc < lb.position.y + lb.size.y * (0.75 if float(turn) == 0.0 else 0.55) and not main_ok:
				for xo in [0.0, -2.0, 2.0, -4.0, 4.0, -6.0, 6.0, -8.0, 8.0]:
					var lc: Vector2 = Vector2(xo, zc) - rot(bb.get_center(), float(turn))
					var c: Vector2 = W.call(lc.x, lc.y)
					var ry: float = lry + float(turn) + r.between(-0.03, 0.03)
					if _rect_in(bb, c, ry, inner):
						placed.append([_rect_world(bb, c, ry, 0.2), mp, c, ry]); main_ok = true; break
				zc += 0.6
		if main_ok: break
	if not main_ok:
		why["court_main"] = int(why.get("court_main", 0)) + 1
		return {}
	var main_front_z := -INF   # 몸채 앞 처마 줄(로컬 z) — 네 귀 중 가장 앞
	for q in _rect_world(_bounds(placed[0][1]), placed[0][2], placed[0][3], 0.0): main_front_z = maxf(main_front_z, unrot(q - C, lry).y)
	var shop: bool = sets.get("shopfront", false)
	# 곁채(옆, 마당을 봄): 왼·오른 옆 — 몸채 앞 처마와 앞채 사이
	for sd in [-1.0, 1.0]:
		if r.next() < 0.15: continue
		for k in 6:
			var wp: Dictionary = (sets.wing[(k + (0 if sd < 0 else 1)) % sets.wing.size()] as Dictionary).duplicate()
			wp.seed = seed0 + 40 + k + (10 if sd > 0 else 0)
			var bb := _bounds(wp)
			var ry: float = lry - float(sd) * PI / 2   # 로컬 −x 쪽 곁채는 +x(마당)를 봄
			var done := false
			var xmid: float = lb.get_center().x
			var xo: float = (lb.position.x + ii + bb.size.y / 2) if sd < 0 else (lb.end.x - ii - bb.size.y / 2)
			while absf(xo - xmid) > 2.5 and not done:
				var zos := []
				# 마당 쪽(몸채 앞)부터, 안 되면 몸채 옆(뒤 줄까지 — ㄱ자)
				var zz := main_front_z + 0.8 + bb.size.x / 2
				while zz < lb.end.y - ii - bb.size.x / 2: zos.append(zz); zz += 1.2
				zz = lb.position.y + ii + bb.size.x / 2
				while zz < main_front_z + 0.8 + bb.size.x / 2: zos.append(zz); zz += 1.2
				for zo in zos:
					var lc := Vector2(xo, zo) - rot(bb.get_center(), -sd * PI / 2)
					var c: Vector2 = W.call(lc.x, lc.y)
					var rc := _rect_world(bb, c, ry, 0.2)
					var ins := _rect_in(bb, c, ry, inner); var fr2: bool = free.call(rc, float(cfg.get("court_gap", 1.0)))
					why["wing_in_%s_free_%s" % [ins, fr2]] = int(why.get("wing_in_%s_free_%s" % [ins, fr2], 0)) + 1
					if OS.has_environment("ORG_DBG7") and li == int(OS.get_environment("ORG_DBG7")): print("DBGW sd=%d k=%d type=%s xo=%.1f zo=%.1f in=%s free=%s bb=%s mfz=%.1f lb=%s" % [sd, k, String(wp.type), xo, zo, ins, fr2, str(bb), main_front_z, str(lb)])
					if ins and fr2:
						placed.append([rc, wp, c, ry]); done = true; break
				xo -= sd * 0.6
			if done: break
	# 앞채(가게채는 길로 트이게 앞 처마가 앞 담 줄, 나머지는 등이 길 — 마당을 봄)
	var front_rc := []
	for k in 6:
		if sets.front.is_empty() or lb.size.y < 18.0 and not shop: break
		var fp: Dictionary = (sets.front[k % sets.front.size()] as Dictionary).duplicate()
		fp.seed = seed0 + 20 + k
		var bb := _bounds(fp)
		var ry := lry if shop else lry + PI
		var done := false
		var zf := lb.end.y - ii - bb.size.y / 2
		while zf > main_front_z + 4.0 + bb.size.y / 2 and not done:
			for xo in ([0.0] if shop else [-lb.size.x * 0.2, lb.size.x * 0.2, -lb.size.x * 0.28, lb.size.x * 0.28, -lb.size.x * 0.1, lb.size.x * 0.1]):
				var lc := Vector2(xo, zf) - (rot(bb.get_center(), PI) if not shop else bb.get_center())
				var c: Vector2 = W.call(lc.x, lc.y)
				var rc := _rect_world(bb, c, ry, 0.2)
				if _rect_in(bb, c, ry, inner) and free.call(rc, float(cfg.get("court_gap", 1.0))):
					placed.append([rc, fp, c, ry]); front_rc = rc; done = true; break
			zf -= 0.6
		if done: break
	# 대문: 앞 담 위, 앞채·곁채를 비킨 자리(대문 → 마당 4m 길)
	var nfront: int = int(lot.get("nfront", 1))
	var wl := inset(poly, 0.35)
	var fpts := []
	for i in nfront + 1: fpts.append(wl[i])
	var fl := length(fpts)
	var gate := {}
	var n: Vector2 = lot.n
	var gtype: String = sets.gate
	if gtype != "none":
		for gq in [0.5, 0.35, 0.65, 0.22, 0.78, 0.12, 0.88]:
			var G: Vector2 = at(fpts, fl * gq)[0]
			var ok := _gate_clear(G, n)
			for q in placed:
				if poly_line_dist(q[0], [G, G - n * 4.0]) < 0.6: ok = false; break
			if ok:
				var gp := { type = gtype, seed = seed0 + 3 }
				if gtype == "pyeong": gp.wall_h = CP.WH_TILE
				elif gtype == "chomun": gp.wall_h = CP.WH_THATCH; gp.w = 1.9
				gate = { tag = "gate", kit = "bldg/gate", params = gp, x = G.x, z = G.y, ry = lry, world = true }
				break
		if gate.is_empty():
			why["court_gate"] = int(why.get("court_gate", 0)) + 1
			return {}
	why["court_ok_%d" % placed.size()] = int(why.get("court_ok_%d" % placed.size(), 0)) + 1
	if OS.has_environment("ORG_DBG6") and placed.size() == 1: print("DBGC lot=%d lb=%s main=%s mfz=%.1f turn=%.2f area=%.0f" % [li, str(lb), String(placed[0][1].type), main_front_z, wrapf(float(placed[0][3]) - lry, -PI, PI), absf(area(poly))])
	var pieces := []
	for k in placed.size():
		var q: Array = placed[k]
		pieces.append({ tag = ["main", "front", "wing", "wing2"][mini(k, 3)] + str(k), kit = "bldg/building", params = q[1], x = (q[2] as Vector2).x, z = (q[2] as Vector2).y, ry = q[3], world = true })
	# 장독대(몸채 뒤 구석이 아니면 옆) · 우물(큰 마당)
	var jd: Vector2 = W.call(lb.position.x + ii + 1.6, lb.position.y + ii + 1.2)
	var jrc := [jd + Vector2(-1.2, -0.9), jd + Vector2(1.2, -0.9), jd + Vector2(1.2, 0.9), jd + Vector2(-1.2, 0.9)]
	if pip(inner, jd) and free.call(jrc, 0.4): pieces.append({ tag = "jangdok", kit = "village/jangdok", params = { seed = seed0 + 5, w = 2.0, d = 1.5 }, x = jd.x, z = jd.y, ry = lry, world = true })
	var walls := [sets.wall, true]
	if sets.get("shopfront", false): walls = [sets.wall, false]   # 가게채가 길 쪽 담을 대신한다
	return _emit(li, lot, C, lry, pieces, t, Vector2(lb.size.x, lb.size.y), walls, gate)

# 자른 필지를 곧바로 채워 본다 — 안 들면 필지를 버린다(빈 필지가 이웃 자리를 막지 않게)
func _accept(lot: Dictionary) -> bool:
	lots.append(lot)
	var li := lots.size() - 1
	var it := fill_one(li, lot)
	if it.is_empty():
		lots.pop_back(); return false
	lot.filled = true
	items.append(it)
	return true

# 필지 틀: 원점 = 앞 변 가운데에서 안쪽, ry = 앞 법선(길 쪽)이 로컬 +z
func _frame(lot: Dictionary) -> Dictionary:
	var nrm: Vector2 = lot.n
	var ry := atan2(nrm.x, nrm.y)
	return { ry = ry }

func _wall_kind(t: String, den: float) -> String:
	match t:
		"giwa_house", "yangban": return "todam_tile"
		"jungnong": return "todam_thatch" if den > 0.2 or r.next() < 0.6 else "stone"
		"choga_house":
			if den > 0.55: return "todam_thatch" if r.next() < 0.7 else "stone"
			if den > 0.3: return _pick(["todam_thatch", "stone", "fence"])
			return "fence" if r.next() < 0.65 else "stone"
	return "fence"

func _pick(a: Array):
	return a[mini(a.size() - 1, int(r.next() * a.size()))]

func _fill(li: int, lot: Dictionary, t: String) -> Dictionary:
	var region: String = cfg.get("region", "south")
	var den: float = lot.zone
	var fm := _frame(lot)
	var ry: float = fm.ry + r.between(-0.05, 0.05)   # 몇 도 어긋남
	var poly: Array = lot.poly
	var wall_line := inset(poly, 0.35)              # 담 가운데 줄
	var inner := inset(poly, float(cfg.get("inner_inset", 1.0)))   # 건물이 들 자리(담 + 처마 물받이) — 읍내는 처마가 담 줄에 닿을 만큼 바짝(0.6)
	var fa: Vector2 = lot.fa; var fb: Vector2 = lot.fb
	# 로컬(앞 변 = 대문 줄) 크기 어림: 너비 = 앞 변, 깊이 = 평균 깊이
	var lw: float = fa.distance_to(fb) - 1.0
	var ld: float = float(lot.depth) - 1.0
	var seed0: int = int(cfg.get("seed", 1)) * 1000 + li * 7
	match t:
		"field":
			var c := _centroid(poly)
			var pieces := [{ tag = "field", kit = "nature/garden_plot", params = { seed = seed0, w = snappedf(clampf(lw * 0.6, 4.0, 8.0), 0.1), d = snappedf(clampf(ld * 0.5, 4.0, 8.0), 0.1) }, x = 0.0, z = 0.0, ry = 0.0 }]
			if r.next() < 0.6: pieces.append({ tag = "hay", kit = "village/haystack", params = { seed = seed0 + 1, s = r.between(0.8, 1.1) }, x = snappedf(lw * 0.3, 0.01), z = snappedf(-ld * 0.3, 0.01), ry = 0.0 })
			return _emit(li, lot, c, ry, pieces, "field", Vector2(lw, ld), [])
		"hut", "shop", "house_c", "house_g":
			# 한 채 집: 몸채가 길을 보고 앞마당을 둔다(초가 서민·읍내 기와집) · 오두막(싸리울 뒤·옆만) · 길가 가게(마당 없이 길로 트임)
			var bp: Dictionary
			match t:
				"hut": bp = { type = "choga", region = region, cls = "poor", seed = seed0 }
				"shop": bp = { type = "sijeon", region = region, cls = "middle", seed = seed0 }
				"house_g": bp = { type = "giwajip", region = region, cls = "middle", seed = seed0 }
				_: bp = { type = "choga", region = region, cls = "commoner", seed = seed0 }
			var wk := "fence"
			if t == "house_g": wk = "todam_tile"
			elif t == "house_c": wk = _wall_kind("choga_house", den)
			var mid := (fa + fb) / 2.0
			var u := (fb - fa).normalized()
			var n: Vector2 = lot.n
			for k in 12:
				bp.seed = seed0 + k
				var bb := _bounds(bp)
				# 몸채 앞 처마가 앞 변에서 fi 안(가게 0.6m — 가게 칸이 길로 트임, 집은 앞마당 3~7m)
				var fy: Array = cfg.get("front_yard", [3.2, 7.0])
				var fi: float = 0.6 if t == "shop" else (r.between(2.0, 4.5) if t == "hut" else r.between(float(fy[0]), float(fy[1])))
				if k >= 4 and t != "shop": fi = 3.4
				# 좁은 필지: 몸채를 옆으로 돌려(박공이 길 쪽) 옆마당을 보게 — 읍내 좁은 필지에 흔한 꼴
				var turn := 0.0
				if k >= 6 and t != "shop": turn = PI / 2 if k % 2 == 0 else -PI / 2
				var hx: float = bb.size.x if turn == 0.0 else bb.size.y
				var hz: float = bb.end.y if turn == 0.0 else bb.size.x / 2
				var shift := r.between(-0.25, 0.25) * maxf(lw - hx, 0.0)
				var c: Vector2 = mid + u * shift - n * (fi + hz)
				var bry: float = ry + turn
				var bc: Vector2 = c + rot(Vector2(-bb.get_center().x, -bb.get_center().y if turn != 0.0 else 0.0), bry)
				if not _rect_in(bb, bc, bry, inner): continue
				var pieces := [{ tag = "house", kit = "bldg/building", params = bp.duplicate(), x = bc.x, z = bc.y, ry = bry, world = true }]
				var walls := []
				var gate := {}
				if t == "hut": walls = ["fence", false]   # 싸리울 뒤·옆만(앞은 트임)
				elif t in ["house_c", "house_g"]:
					walls = [wk, true]
					var gp: Dictionary
					if t == "house_g": gp = { type = "pyeong" if r.next() < 0.6 else "ilgak", seed = seed0, wall_h = CP.WH_TILE }
					elif wk == "todam_thatch": gp = { type = "chomun", seed = seed0, wall_h = CP.WH_THATCH, w = 1.9 }
					else: gp = { type = "sarip", seed = seed0 }
					# 대문: 앞 변 위, 몸채 가운데를 비켜(조선 집은 대문–대청이 한 줄이 아니게)
					var wl2 := inset(poly, 0.35)
					var nfr: int = int(lot.get("nfront", 2 if poly.size() == 5 else 1))
					var fp2 := []
					for i in nfr + 1: fp2.append(wl2[i])
					var fl2 := length(fp2)
					# 대문 안 3.4m는 마당(몸채 처마가 문 앞을 막지 않게) — 맞는 자리가 없으면 다음 시드·자리로
					var hrect := _rect_world(bb, bc, bry, 0.3)
					var gt := -1.0
					for gq in [_pick([0.22, 0.3, 0.7, 0.78]), 0.2, 0.8, 0.35, 0.65, 0.5]:
						var Gq: Vector2 = at(fp2, fl2 * gq)[0]
						if poly_line_dist(hrect, [Gq, Gq - n * 3.4]) > 0.4 and _gate_clear(Gq, n): gt = gq; break
					if gt < 0.0: continue
					var G: Vector2 = at(fp2, fl2 * gt)[0]
					gate = { tag = "gate", kit = "bldg/gate", params = gp, x = G.x, z = G.y, ry = ry, world = true }
					# 마당 것: 장독대(뒤 구석) · 감나무 · 장작
					var side_sx := -1.0 if gt > 0.5 else 1.0
					var jd: Vector2 = bc + rot(Vector2(bb.get_center().x + side_sx * (bb.size.x / 2 + 1.6), bb.position.y + 1.2), bry)
					var appr := [G, G - n * 7.0]   # 대문 → 마당 안 길
					if pip(inner, jd) and seg_dist(jd, appr[0], appr[1]) > 2.6 and r.next() < 0.7: pieces.append({ tag = "jangdok", kit = "village/jangdok", params = { seed = seed0 + 3, w = 2.0, d = 1.5 }, x = jd.x, z = jd.y, ry = ry, world = true })
					var tp: Vector2 = G - n * 2.0 + u * (side_sx * 3.6)   # 대문 → 몸채 길 옆으로 비켜
					if pip(inner, tp) and seg_dist(tp, appr[0], appr[1]) > 2.4 and r.next() < 0.45: pieces.append({ tag = "tree", kit = "nature/persimmon", params = { seed = seed0 + 5, s = r.between(0.85, 1.1) }, x = tp.x, z = tp.y, ry = 0.0, world = true })
				return _emit(li, lot, bc, ry, pieces, t, Vector2(lw, ld), walls, gate)
			return {}
	# 묶음
	for k in 10:
		var p := { type = t, region = region, seed = seed0 + k * 13 }
		if t in ["choga_house", "giwa_house"]: p.lot = [snappedf(maxf(lw, 8.0), 0.1), snappedf(maxf(ld, 8.0), 0.1)]
		if t == "giwa_house": p.cls = "middle"
		var wk := _wall_kind(t, den)
		if t == "choga_house": p.wall = wk
		var plan := CP.plan(p)
		var gate_l := Vector2(0, float(plan.fp.y) / 2 - 0.5)
		var gate_p := {}
		var keep_pieces := []
		var blds := []
		for e in plan.pieces:
			var tag := String(e.tag)
			if tag == "gate": gate_l = Vector2(float(e.x), float(e.z)); gate_p = e.params; continue
			if tag.begins_with("wall_"): continue
			keep_pieces.append(e)
			if e.kit == "bldg/building": blds.append(e)
		var Z1: float = float(plan.fp.y) / 2 - 0.5
		# 대문 자리를 앞 변 담 줄 위 여러 곳에 대 보고 집이 필지 안에 드는 곳
		var nfront: int = int(lot.get("nfront", 2 if poly.size() == 5 else 1))
		var fpts := []
		for i in nfront + 1: fpts.append(wall_line[i])
		var fl := length(fpts)
		var tries := [0.5, 0.38, 0.62, 0.28, 0.72, 0.2, 0.8]
		for tt in tries:
			var G: Vector2 = (at(fpts, fl * tt)[0] as Vector2)
			if not _gate_clear(G, lot.n): continue
			# 묶음 로컬 (gx, Z1) → G, 로컬 +z → 앞 법선(ry)
			var O: Vector2 = G - rot(Vector2(gate_l.x, Z1), ry)
			var ok := true
			for e in blds:
				var bb := _bounds(e.params)
				var pc: Vector2 = O + rot(Vector2(float(e.x), float(e.z)), ry)
				if not _rect_in(bb, pc, ry + float(e.ry), inner): ok = false; break
			if not ok: continue
			# 다른 마당 것(우물·장독·나무·텃밭·뒷간·내외담…)은 필지 안에 든 것만
			var pieces := []
			for e in keep_pieces:
				var pc: Vector2 = O + rot(Vector2(float(e.x), float(e.z)), ry)
				var q: Dictionary = e.duplicate(true)
				if (q.params as Dictionary).has("ax"):
					var a2: Vector2 = pc + rot(Vector2(float(q.params.ax), float(q.params.az)), ry + float(e.ry))
					var b2: Vector2 = pc + rot(Vector2(float(q.params.bx), float(q.params.bz)), ry + float(e.ry))
					if not (pip(inner, a2) and pip(inner, b2)): continue
				elif e.kit != "bldg/building" and not pip(inner, pc): continue
				# 대문 → 마당 안 길(안으로 5m, 폭 ±1.8m)에 놓인 마당 것(일거리·텃밭·장독)은 뺀다 — 묶음 짜임이 필지 담 대문 자리와 어긋날 때
				if e.kit != "bldg/building" and not (q.params as Dictionary).has("ax") and seg_dist(pc, G, G - (lot.n as Vector2) * 5.0) < 1.8 + (2.0 if String(e.kit) in ["village/teotbat", "village/jangdok"] else 0.6): continue
				q.x = pc.x; q.z = pc.y; q.ry = ry + float(e.ry)   # 월드(아래 _emit에서 필지 로컬로)
				q.world = true
				pieces.append(q)
			var gate := {}
			if not gate_p.is_empty():
				gate = { tag = "gate", kit = "bldg/gate", params = gate_p, x = G.x, z = G.y, ry = ry, world = true }
			return _emit(li, lot, O, ry, pieces, t, Vector2(lw, ld), [wk, true], gate)
	return {}

var _bcache := {}
func _bounds(params: Dictionary) -> Rect2:
	var k := JSON.stringify(params, "", true)
	if not _bcache.has(k): _bcache[k] = B.bounds(S.resolve(params))
	return _bcache[k]

# 대문 밖 길(문 앞 2.2m)이 비울 자리(좌판·남긴 옛 항목)에 막히지 않나
func _gate_clear(G: Vector2, n: Vector2) -> bool:
	for k in [0.8, 1.6, 2.4]:
		var q: Vector2 = G + n * k
		for kk in keep:
			if q.distance_to(kk.c) < float(kk.r) + 0.45: return false
		for kp in keep_poly:
			if pip(kp, q): return false
	return true

static func _centroid(poly: Array) -> Vector2:
	var c := Vector2.ZERO
	for p in poly: c += p
	return c / poly.size()

# 건물 바닥(로컬 bounds) + 자리 → 네 귀가 다각형 안
static func _rect_in(bb: Rect2, c: Vector2, ry: float, poly: Array) -> bool:
	for q in [bb.position, Vector2(bb.end.x, bb.position.y), bb.end, Vector2(bb.position.x, bb.end.y)]:
		if not pip(poly, c + rot(q, ry)): return false
	return true

static func _rect_world(bb: Rect2, c: Vector2, ry: float, grow := 0.0) -> Array:
	var g := bb.grow(grow)
	var out := []
	for q in [g.position, Vector2(g.end.x, g.position.y), g.end, Vector2(g.position.x, g.end.y)]: out.append(c + rot(q, ry))
	return out


# 옛 방식(토막마다 담 한 조각) — wall_paths=false
func _wall_pieces(li: int, wk: String, cut: Array, out: Array, to_local: Callable) -> int:
	var nwall := 0
	# 꼭짓점 맞춤(miter): 이웃 토막 끝이 같은 점이면 꺾인 각의 절반 기울기로 끝을 자른다
	for ci in cut.size():
		var sg: Array = cut[ci]
		var a: Vector2 = sg[0]; var b: Vector2 = sg[1]
		var p := { seed = seed_of(li) + ci, ax = 0.0, az = 0.0, bx = 0.0, bz = 0.0 }
		var la: Vector2 = to_local.call(a); var lb: Vector2 = to_local.call(b)
		p.ax = snappedf(la.x, 0.001); p.az = snappedf(la.y, 0.001); p.bx = snappedf(lb.x, 0.001); p.bz = snappedf(lb.y, 0.001)
		var kit := "village/todam"
		match wk:
			"fence": kit = "village/fence"; p.lite = true
			"stone": kit = "village/stone_wall"; p.lite = true; p.sparse = true; p.h = CP.WH_STONE
			"todam_thatch": p.h = CP.WH_THATCH; p.cap = "thatch"
			_: p.h = CP.WH_TILE; p.cap = "tile"; p.tile_seg = 0.5
		if kit == "village/todam":
			for end in [0, 1]:
				var pt: Vector2 = a if end == 0 else b
				var dout: Vector2 = (a - b).normalized() if end == 0 else (b - a).normalized()
				if sg[4 + end]: p["open_" + ("a" if end == 0 else "b")] = true; continue
				for cj in cut.size():
					if cj == ci: continue
					var o: Array = cut[cj]
					for oe in [0, 1]:
						var op: Vector2 = o[0] if oe == 0 else o[1]
						if op.distance_to(pt) > 0.05: continue
						var odir: Vector2 = ((o[1] as Vector2) - (o[0] as Vector2)).normalized() if oe == 0 else ((o[0] as Vector2) - (o[1] as Vector2)).normalized()   # 모서리에서 그 담 가운데 쪽
						var phi := absf(dout.angle_to(odir))   # 꺾인 각(곧게 이어지면 0, 직각 π/2)
						if phi < 0.05: continue
						var ang := atan2((b - a).y, (b - a).x)
						var lz := Vector2(-sin(ang), cos(ang))
						var sgn := signf(odir.dot(lz))
						p["miter_" + ("a" if end == 0 else "b")] = snappedf(sgn * tan(clampf(phi, 0.0, 2.4) / 2.0), 0.0001)
		elif kit == "village/stone_wall":
			# 돌담은 끝을 두께 절반 늘려 모서리 홈을 메운다(성긴 막돌이라 겹침이 드러나지 않음)
			var u := (b - a).normalized()
			var la2: Vector2 = to_local.call(a - u * 0.25); var lb2: Vector2 = to_local.call(b + u * 0.25)
			if not sg[4]: p.ax = snappedf(la2.x, 0.001); p.az = snappedf(la2.y, 0.001)
			if not sg[5]: p.bx = snappedf(lb2.x, 0.001); p.bz = snappedf(lb2.y, 0.001)
		out.append({ tag = "wall_%d" % ci, kit = kit, params = p, x = 0.0, z = 0.0, ry = 0.0 })
		nwall += 1
	return nwall

# 담 길(wall path) 규칙 — 곧게/굽게를 까닭으로 정한다(사용자 요청: "담장이 직선이기도 곡선이기도 해야 하고, 지형·지리·이유로").
#   곧음: 계획된 기와 갓 담(읍내 기와집·양반가·관아)이 평지에 설 때 · 곧은 큰길 앞 담 → 각진 모서리
#   굽음: ① 굽은 길 가장자리(앞 담이 길 마디를 따름) ② 비탈(옆·뒤 담이 등고선을 따름 — 터 고른 단 위라 담 위는 수평)
#        ③ 흙담·돌담·싸리울 모서리는 둥글게 ④ 마을 막돌담·싸리울은 손으로 쌓아 조금씩 굽음 ⑤ 나무 둘레를 비켜 감
#   한 줄(run) = 대문·건물에 끊기지 않고 이어진 담 — bldg/wall 한 조각(마디마다 miter로 이어 몸·갓이 끊기지 않음). 까닭은 params.why(감사용)
func _wall_runs(li: int, lot: Dictionary, t: String, wk: String, cut: Array, out: Array, to_local: Callable, pieces: Array, anchor: Vector2, ry: float) -> int:
	if cut.is_empty(): return 0
	var poly: Array = lot.poly
	var C := _centroid(poly)
	var planned: bool = wk == "todam_tile" and t in ["house_g", "giwa_house", "yangban"]
	var slope_lot := 0.0
	if hf.is_valid():
		var gx := (_h(C + Vector2(3, 0)) - _h(C - Vector2(3, 0))) / 6.0; var gz := (_h(C + Vector2(0, 3)) - _h(C - Vector2(0, 3))) / 6.0
		slope_lot = Vector2(gx, gz).length()
	if slope_lot > 0.05: planned = false   # 비탈이면 계획된 담도 등고선을 따른다(섞임: 앞은 곧게, 뒤는 굽게)
	# 나무(필지 안 마당 나무) 자리
	var trees := []
	for e in pieces:
		if String(e.kit).begins_with("nature/"):
			trees.append(Vector2(float(e.x), float(e.z)) if e.get("world", false) else anchor + rot(Vector2(float(e.x), float(e.z)), ry))
	# 1) 이어진 토막끼리 묶기(앞 토막 끝 = 다음 토막 시작, 둘 다 열린 끝이 아님)
	var runs := []
	var cur := [cut[0]]
	for k in range(1, cut.size()):
		var prev: Array = cur[cur.size() - 1]
		if (prev[1] as Vector2).distance_to(cut[k][0]) < 0.05 and not prev[5] and not cut[k][4]: cur.append(cut[k])
		else: runs.append(cur); cur = [cut[k]]
	runs.append(cur)
	if runs.size() > 1:
		var last: Array = runs[runs.size() - 1]; var first: Array = runs[0]
		if (last[last.size() - 1][1] as Vector2).distance_to(first[0][0]) < 0.05 and not last[last.size() - 1][5] and not first[0][4]:
			runs[0] = last + first; runs.pop_back()
	var closed_all: bool = runs.size() == 1 and (cut[cut.size() - 1][1] as Vector2).distance_to(cut[0][0]) < 0.05 and not cut[0][4] and not cut[cut.size() - 1][5]
	var n := 0
	for ri in runs.size():
		var run: Array = runs[ri]
		var why := {}
		var pts := []   # [점, 고정(끝·모서리 원점)]
		pts.append([run[0][0], true])
		for k in run.size():
			var sg: Array = run[k]
			var a: Vector2 = sg[0]; var b: Vector2 = sg[1]
			var L := a.distance_to(b)
			var en := Vector2(-(b - a).normalized().y, (b - a).normalized().x)
			if en.dot(C - (a + b) / 2) < 0: en = -en   # 안쪽(필지 가운데 쪽) 법선
			# 변마다 굽힘 까닭
			var mode := "straight"
			var dh_along := 0.0; var g_n := 0.0
			if hf.is_valid():
				dh_along = absf(_h(b) - _h(a)) / maxf(L, 0.1)
				var m2 := (a + b) / 2
				g_n = (_h(m2 + en * 1.5) - _h(m2 - en * 1.5)) / 3.0
			if not sg[2] and absf(g_n) > 0.05 and dh_along < 0.06 and L > 4.0: mode = "contour"
			elif not planned and wk in ["stone", "fence"] and L > 3.0: mode = "wavy"
			var reason := ""
			match mode:
				"contour": reason = "비탈 등고선을 따라 굽음(옆·뒤 담)"
				"wavy": reason = "마을 막돌담·싸리울 — 손으로 쌓아 조금씩 굽음"
				_:
					if sg[2] and run.size() > 1 and k > 0 and bool(run[k - 1][2]) and absf((b - a).normalized().angle_to((run[k - 1][1] as Vector2) - (run[k - 1][0] as Vector2))) > 0.04: reason = "굽은 길 가장자리를 따라 꺾임(앞 담)"
					elif planned: reason = "계획된 기와 갓 담·평지 — 곧은 줄"
					elif sg[2]: reason = "곧은 길 앞 — 곧은 담"
					else: reason = "곧은 필지 경계"
			why[reason] = int(why.get(reason, 0)) + 1
			var nsub := 1 if mode == "straight" else maxi(1, int(L / 2.0))
			var ph := r.between(0, TAU)
			for q in range(1, nsub + 1):
				var tq := float(q) / nsub
				var p := a.lerp(b, tq)
				var fixed := q == nsub
				if not fixed:
					match mode:
						"contour":
							var href := (_h(a) + _h(b)) / 2.0
							var mv := clampf((href - _h(p)) / g_n, -0.9, 0.9) if absf(g_n) > 1e-3 else 0.0
							p += en * clampf(mv, 0.0, 0.9)   # 안쪽으로만(이웃 담과 겹치지 않게)
						"wavy":
							p += en * (0.12 + 0.14 * sin(ph + tq * PI * L / 4.5))
				# 나무 둘레 비키기
				for tr in trees:
					var dd: float = (p as Vector2).distance_to(tr)
					if dd < 1.7 and not fixed:
						p = tr + ((p as Vector2) - tr).normalized() * 1.7
						why["마당 나무 둘레를 비켜 감"] = int(why.get("마당 나무 둘레를 비켜 감", 0)) + 1
				pts.append([p, fixed])
		# 2) 모서리 둥글게(흙·돌담·싸리울 — 계획된 기와 갓 담은 각지게)
		if not planned and wk in ["todam_thatch", "stone", "fence"]:
			var np := [pts[0]]
			for k in range(1, pts.size() - 1):
				var P: Vector2 = pts[k][0]
				var A: Vector2 = np[np.size() - 1][0]; var Bq: Vector2 = pts[k + 1][0]
				var th := absf((P - A).angle_to(Bq - P))
				if pts[k][1] and th > 0.45:
					var rr := minf(1.3, minf(P.distance_to(A), P.distance_to(Bq)) * 0.4)
					var p1 := P + (A - P).normalized() * rr; var p2 := P + (Bq - P).normalized() * rr
					for q in [0.0, 0.33, 0.66, 1.0]:
						var u2: float = q
						np.append([p1.lerp(P, u2).lerp(P.lerp(p2, u2), u2), q == 0.0 or q == 1.0])
					why["흙·돌담 모서리를 둥글게"] = int(why.get("흙·돌담 모서리를 둥글게", 0)) + 1
				else: np.append(pts[k])
			np.append(pts[pts.size() - 1])
			pts = np
		var lp := []
		for q in pts:
			var v: Vector2 = to_local.call(q[0])
			if lp.is_empty() or Vector2(float(lp[lp.size() - 1][0]), float(lp[lp.size() - 1][1])).distance_to(v) > 0.08: lp.append([snappedf(v.x, 0.01), snappedf(v.y, 0.01)])
		if lp.size() < 2: continue
		var closed: bool = closed_all and runs.size() == 1
		if closed and Vector2(float(lp[0][0]), float(lp[0][1])).distance_to(Vector2(float(lp[lp.size() - 1][0]), float(lp[lp.size() - 1][1]))) < 0.1: lp.pop_back()
		var h: float = { todam_tile = CP.WH_TILE, todam_thatch = CP.WH_THATCH, stone = CP.WH_STONE, fence = 1.15 }.get(wk, 1.7)
		var wy := []
		for k2 in why: wy.append("%s ×%d" % [k2, why[k2]])
		out.append({ tag = "wallrun_%d" % ri, kit = "bldg/wall", params = { kind = wk, pts = lp, closed = closed, h = h, seed = seed_of(li) + 300 + ri,
			open_a = bool(run[0][4]), open_b = bool(run[run.size() - 1][5]), why = wy }, x = 0.0, z = 0.0, ry = 0.0 })
		n += 1
	return n

# 필지 항목 하나(bldg/lot) — 조각을 필지 로컬로, 둘레 담(다각형) + 대문 + 마당 것
#   walls: [] 담 없음 | [kind, front(true: 앞 변에도 담 + 대문 틈)]
func _emit(li: int, lot: Dictionary, anchor: Vector2, ry: float, pieces: Array, t: String, lsz: Vector2, walls: Array, gate := {}) -> Dictionary:
	var poly: Array = lot.poly
	var lry: float = atan2((lot.n as Vector2).x, (lot.n as Vector2).y)
	# 필지 로컬 원점: 다각형을 lry로 돌린 바운딩 사각 가운데
	var lo := Vector2(INF, INF); var hi := Vector2(-INF, -INF)
	for p in poly:
		var q := unrot(p, lry)
		lo = Vector2(minf(lo.x, q.x), minf(lo.y, q.y)); hi = Vector2(maxf(hi.x, q.x), maxf(hi.y, q.y))
	var O := rot((lo + hi) / 2.0, lry)
	var to_local := func(w: Vector2) -> Vector2: return unrot(w - O, lry)
	var out := []
	var brects := []   # 담을 자를 건물 바닥(월드 다각형)
	for e in pieces:
		var q: Dictionary = e.duplicate(true)
		var wp: Vector2 = Vector2(float(e.x), float(e.z)) if e.get("world", false) else anchor + rot(Vector2(float(e.x), float(e.z)), ry)
		var wry: float = float(e.ry) if e.get("world", false) else ry + float(e.ry)
		if q.kit == "bldg/building": brects.append(_rect_world(_bounds(q.params), wp, wry, 0.25))
		var lp: Vector2 = to_local.call(wp)
		q.erase("world")
		q.x = snappedf(lp.x, 0.01); q.z = snappedf(lp.y, 0.01); q.ry = snappedf(wry - lry, 0.0001)
		out.append(q)
	# 넓은 필지: 남은 마당에 곁채(곳간·헛간)·텃밭·짚가리 — 마당이 비어 보이지 않게(필지 면적 대비 건물이 작을 때만)
	if t in ["house_c", "house_g", "choga_house", "jungnong", "giwa_house", "hut"]:
		var inner2 := inset(poly, float(cfg.get("inner_inset", 1.0)) + 0.1)
		var built := 0.0
		for rr in brects: built += absf(area(rr))
		var la := absf(area(poly))
		var tries := 0
		var added := 0
		var xr := float(cfg.get("extras_ratio", 0.4)); var xm := int(cfg.get("extras_max", 3))
		while built < la * xr and tries < 60 and added < xm:
			tries += 1
			var kind: String = _pick(["gotgan", "gotgan", "teotbat", "hay"]) if float(lot.zone) < 0.5 else _pick(["gotgan", "gotgan", "gotgan", "araechae", "jangdok"])
			var c2: Vector2 = _centroid(poly) + Vector2(r.between(-1, 1), r.between(-1, 1)) * sqrt(la) * 0.45
			var ry2: float = lry + (0.0 if r.next() < 0.5 else PI / 2) + (PI if r.next() < 0.5 else 0.0)
			var e2 := {}
			var bb2 := Rect2()
			match kind:
				"gotgan":
					var gp := { type = "gotgan", region = String(cfg.get("region", "south")), cls = "middle" if t in ["house_g", "giwa_house"] else "commoner", seed = seed_of(li) + 31 + tries }
					bb2 = _bounds(gp)
					e2 = { tag = "gotgan", kit = "bldg/building", params = gp }
				"araechae":
					# 아래채·가게채(낙안읍성 집들처럼 한 필지에 두세 채 — 아래채·헛간채·가게채)
					var ap2 := { type = "araechae", region = String(cfg.get("region", "south")), cls = "commoner", seed = seed_of(li) + 33 + tries }
					bb2 = _bounds(ap2)
					e2 = { tag = "araechae", kit = "bldg/building", params = ap2 }
					kind = "gotgan"
				"teotbat": bb2 = Rect2(-2.4, -1.7, 4.8, 3.4); e2 = { tag = "teotbat", kit = "village/teotbat", params = { seed = seed_of(li) + 41, w = 4.4, d = 3.0 } }
				"hay": bb2 = Rect2(-1.3, -1.3, 2.6, 2.6); e2 = { tag = "hay", kit = "village/haystack", params = { seed = seed_of(li) + 43, s = r.between(0.85, 1.1) } }
				"jangdok": bb2 = Rect2(-1.2, -0.9, 2.4, 1.8); e2 = { tag = "jangdok2", kit = "village/jangdok", params = { seed = seed_of(li) + 47, w = 2.2, d = 1.6 } }
			if not _rect_in(bb2, c2, ry2, inner2): continue
			var mine := _rect_world(bb2, c2, ry2, 0.0)
			var clash := false
			for rr in brects:
				if poly_dist(mine, rr) < float(cfg.get("extras_gap", 1.4)): clash = true; break
			# 대문 → 마당 안 길(대문에서 안으로 7m 띠, 폭 ±1.7m)은 비운다 — 문 안 내외담은 묶음 것이라 그대로
			if not gate.is_empty():
				var Gw := Vector2(float(gate.x), float(gate.z))
				if poly_line_dist(mine, [Gw, Gw - (lot.n as Vector2) * 7.0]) < 1.7: clash = true
			if clash: continue
			var lp2: Vector2 = to_local.call(c2)
			e2.x = snappedf(lp2.x, 0.01); e2.z = snappedf(lp2.y, 0.01); e2.ry = snappedf(ry2 - lry, 0.0001)
			out.append(e2)
			brects.append(_rect_world(bb2, c2, ry2, 0.25) if kind == "gotgan" else mine)
			if kind == "gotgan": built += absf(area(mine))
			added += 1
	# 마당 나무(감나무·느티·대추 자리): 집 뒤·옆 빈 구석에 0~1그루 — 지붕 사이로 나무가 솟는 그림(참고 그림)
	if t in ["house_c", "house_g", "choga_house", "jungnong", "giwa_house", "yangban", "hut"] and r.next() < 0.55:
		var inner3 := inset(poly, 1.6)
		for k3 in 14:
			var c3: Vector2 = _centroid(poly) + Vector2(r.between(-1, 1), r.between(-1, 1)) * sqrt(absf(area(poly))) * 0.5
			if not pip(inner3, c3): continue
			var ok3 := true
			for rr in brects:
				if poly_dist([c3 + Vector2(-1.2, -1.2), c3 + Vector2(1.2, -1.2), c3 + Vector2(1.2, 1.2), c3 + Vector2(-1.2, 1.2)], rr) < 0.6: ok3 = false; break
			if not gate.is_empty() and seg_dist(c3, Vector2(float(gate.x), float(gate.z)), Vector2(float(gate.x), float(gate.z)) - (lot.n as Vector2) * 7.0) < 2.4: ok3 = false
			if not ok3: continue
			var lp3: Vector2 = to_local.call(c3)
			var tk: Dictionary
			match int(r.next() * 4.0):
				0, 1: tk = { tag = "ytree", kit = "nature/persimmon", params = { seed = seed_of(li) + 71, s = r.between(0.9, 1.2) } }
				2: tk = { tag = "ytree", kit = "nature/big_tree", params = { seed = seed_of(li) + 73, variant = "zelkova" if r.next() < 0.5 else "broadleaf", h = r.between(7.0, 10.0) } }
				_: tk = { tag = "ytree", kit = "nature/pine", params = { seed = seed_of(li) + 77, s = r.between(0.8, 1.1) } }
			tk.x = snappedf(lp3.x, 0.01); tk.z = snappedf(lp3.y, 0.01); tk.ry = 0.0
			out.append(tk)
			break
	# 비탈 필지(축대): 필지 가운데 땅보다 변 바깥 땅이 0.45m 넘게 낮으면 그 변을 따라 막돌 축대(village/stone_terrace) — 터 고르기로 생긴 단을 받친다.
	#   땅은 생성할 때의 높이장(hf) 기준. 지형이 바뀌면 생성기를 다시 돌린다(docs/reports/town-organic.md 지형 가정)
	if hf.is_valid() and bool(cfg.get("terrace", true)):
		var h0 := _h(_centroid(poly))
		var nfr3: int = int(lot.get("nfront", 2 if poly.size() == 5 else 1))
		for i in poly.size():
			if i < nfr3: continue   # 앞 변(길·대문 쪽)에는 축대를 두지 않는다 — 대문 앞을 막지 않게(터 고르기 가장자리 경사로 오른다)
			var a3: Vector2 = poly[i]; var b3: Vector2 = poly[(i + 1) % poly.size()]
			var mid3 := (a3 + b3) / 2.0
			var outn := (mid3 - _centroid(poly)).normalized()
			var ho := minf(_h(mid3 + outn * 2.0), minf(_h(a3.lerp(b3, 0.2) + outn * 2.0), _h(a3.lerp(b3, 0.8) + outn * 2.0)))
			var drop := h0 - ho
			if drop < 0.45 or a3.distance_to(b3) < 2.0: continue
			# a→b 방향의 앞(+z) = (−dy, dx)가 바깥(아래)을 보게
			var dv := (b3 - a3).normalized()
			var pa := a3; var pb := b3
			if Vector2(-dv.y, dv.x).dot(outn) < 0: pa = b3; pb = a3
			var la3: Vector2 = to_local.call(pa); var lb3: Vector2 = to_local.call(pb)
			var dr := clampf(drop, 0.5, 3.2)
			out.append({ tag = "terrace_%d" % i, kit = "village/stone_terrace", params = { seed = seed_of(li) + 90 + i, ax = snappedf(la3.x, 0.01), az = snappedf(la3.y, 0.01), bx = snappedf(lb3.x, 0.01), bz = snappedf(lb3.y, 0.01),
				drop = snappedf(dr, 0.05), tiers = clampi(ceili(dr / 0.9), 1, 3), step = 0.5, wall = false }, x = 0.0, z = 0.0, ry = 0.0 })
			terraces += 1
	var nwall := 0
	if not walls.is_empty():
		var wk: String = walls[0]; var front: bool = walls[1]
		var wl := inset(poly, 0.35)
		var nfront: int = int(lot.get("nfront", 2 if poly.size() == 5 else 1))    # 앞 변 마디 수(오각이면 앞 두 변)
		var segs := []   # [a, b, is_front]
		var side_skip := -1
		if float(cfg.get("partial_walls", 0.0)) > 0.0 and wk in ["fence", "stone"] and r.next() < float(cfg.get("partial_walls", 0.0)):
			side_skip = nfront if r.next() < 0.5 else wl.size() - 1   # 앞 변 바로 다음 변(오른 옆) 또는 마지막 변(왼 옆)
		for i in wl.size():
			var isf: bool = i < nfront
			if isf and not front: continue
			# 담을 다 두르지 않은 집(옆 한 변 없음 — 이웃 담·텃밭이 경계, ACON 47649 평면·낙안읍성 '맞담'): cfg.partial_walls 확률, 싸리울·돌담 집만
			if not isf and side_skip == i: continue
			if not isf and i == nfront and bool(lot.get("share_end", false)): continue   # 맞담: 끝 옆선은 다음 필지 담이 맡는다
			segs.append([wl[i], wl[(i + 1) % wl.size()], isf, i])
		# 대문 틈
		var gpiece := {}
		if not gate.is_empty():
			var G := Vector2(float(gate.x), float(gate.z))
			var hf2 := GT.half(gate.params)
			var ns := []
			for sg in segs:
				if not sg[2]: ns.append(sg); continue
				var a: Vector2 = sg[0]; var b: Vector2 = sg[1]
				if seg_dist(G, a, b) > 0.6: ns.append(sg); continue
				var u := (b - a).normalized()
				var tg := (G - a).dot(u)
				if tg - hf2 > 0.3: ns.append([a, a + u * (tg - hf2), true, sg[3], "gate_b"])
				if a.distance_to(b) - (tg + hf2) > 0.3: ns.append([a + u * (tg + hf2), b, true, sg[3], "gate_a"])
				# 대문은 이 변의 방향을 따른다(앞 변이 꺾였으면 그 마디)
				var gry := atan2(-u.y, u.x)   # 로컬 x(문 너비) = 변 방향 · 로컬 +z = 길 쪽
				var gq: Dictionary = gate.duplicate(true)
				var gp := G
				gq.ry = gry
				if Vector2(sin(gry), cos(gry)).dot(lot.n) < 0: gq.ry = gry + PI
				var lp: Vector2 = to_local.call(gp)
				gq.erase("world")
				gq.x = snappedf(lp.x, 0.01); gq.z = snappedf(lp.y, 0.01); gq.ry = snappedf(float(gq.ry) - lry, 0.0001)
				gpiece = gq
			segs = ns
			# 낙안읍성 민가처럼 '담을 쌓다가 터 놓은 자리'가 대문인 집(초가 사립·초가 대문의 40%) — 문 짜임 없이 담 틈만(KHS 낙안읍성 대나무 서까래집·주막집 해설)
			if not gpiece.is_empty() and String(gpiece.params.get("type", "")) in ["sarip", "chomun"] and r.next() < 0.4: gpiece = {}
			if not gpiece.is_empty(): out.append(gpiece)
		# 건물에 닿는 담은 잘라 건물 벽에 맞댄다
		var cut := []
		for sg in segs:
			var a: Vector2 = sg[0]; var b: Vector2 = sg[1]
			var L := a.distance_to(b)
			var n := maxi(2, int(L / 0.1))
			var run_a := -1.0
			for k in n + 1:
				var tk := float(k) / n
				var p := a.lerp(b, tk)
				var inb := false
				for rr in brects:
					if pip(rr, p): inb = true; break
				if not inb and run_a < 0: run_a = tk
				if (inb or k == n) and run_a >= 0:
					var t1 := tk if not inb else float(k - 1) / n
					if (t1 - run_a) * L > 0.5:
						cut.append([a.lerp(b, run_a), a.lerp(b, t1), sg[2], sg[3], run_a > 0.001 or (sg.size() > 4 and sg[4] == "gate_a"), t1 < 0.999 or (sg.size() > 4 and sg[4] == "gate_b")])
					run_a = -1.0
		if bool(cfg.get("wall_paths", true)):
			nwall += _wall_runs(li, lot, t, wk, cut, out, to_local, pieces, anchor, ry)
		else:
			nwall += _wall_pieces(li, wk, cut, out, to_local)
	var fp := hi - lo
	var c := O
	var it := { id = "%s_lot%03d" % [String(cfg.get("prefix", "org")), li], kit = "bldg/lot",
		params = { type = t, seed = seed_of(li), fp = [snappedf(maxf(fp.x - 2.0, 4.0), 0.1), snappedf(maxf(fp.y - 2.0, 4.0), 0.1)], pieces = out, poly = _poly_local(poly, O, lry) },
		x = snappedf(c.x, 0.01), z = snappedf(c.y, 0.01), ry = snappedf(lry, 0.0001), y = null, flatten = true, clear_veg = true,
		group = String(cfg.get("group", "고을 짜임")), footprint = [snappedf(maxf(fp.x - 2.0, 4.0), 0.1), snappedf(maxf(fp.y - 2.0, 4.0), 0.1)],
		organic = { lot = li, zone = snappedf(float(lot.zone), 0.01), street = String(streets[lot.street].id), walls = nwall } }
	return it

func seed_of(li: int) -> int:
	return int(cfg.get("seed", 1)) * 1000 + li

static func _poly_local(poly: Array, O: Vector2, lry: float) -> Array:
	var out := []
	for p in poly:
		var q := unrot(p - O, lry)
		out.append([snappedf(q.x, 0.01), snappedf(q.y, 0.01)])
	return out

# ④ 길·마당 꾸밈: 마당(plaza)에 정자나무·우물·평상, 갈림목·빈터에 나무·텃밭·짚가리
func dress() -> void:
	var k := 0
	var placed := []   # 마당 것끼리 겹치지 않게 [자리, 반지름]
	for pz in plazas:
		var c: Vector2 = pz.c
		match String(pz.kind):
			"gate", "market":
				if r.next() < 0.8:
					var q := _plaza_spot(pz, 2.2, placed)
					if q.x < INF: items.append(_free("tree", "nature/big_tree", { seed = k + 1, variant = "zelkova", h = r.between(9.0, 12.0) }, q, 0.0)); k += 1
			"well", "junction":
				var q := _plaza_spot(pz, 1.4, placed)
				if q.x < INF: items.append(_free("well", "village/well", { seed = k + 3, roof = r.next() < 0.4 }, q, r.between(0, TAU))); k += 1
				if r.next() < 0.7:
					var q2 := _plaza_spot(pz, 2.2, placed)
					if q2.x < INF: items.append(_free("tree", "nature/big_tree", { seed = k + 5, variant = _pick(["zelkova", "zelkova", "broadleaf"]), h = r.between(8.0, 11.0) }, q2, 0.0)); k += 1
				if r.next() < 0.6:
					var q3 := _plaza_spot(pz, 1.6, placed)
					if q3.x < INF: items.append(_free("bench", "village/props", { seed = k + 7, kind = "pyeongsang" }, q3, r.between(0, TAU))); k += 1
	# 빈 땅: 필지·길·마당 밖, 구역 안 — 성긴 격자에서 나무·텃밭·짚가리
	var bb := _bbox(area_poly)
	var step := 7.5
	var y := bb.position.y + step / 2
	while y < bb.end.y:
		var x := bb.position.x + step / 2
		while x < bb.end.x:
			var p := Vector2(x + r.between(-3.5, 3.5), y + r.between(-3.5, 3.5))
			x += step
			if _blocked(p, 2.0): continue
			var near := false
			for l in lots:
				if pip(l.poly, p) or _poly_edge_d(l.poly, p) < 2.5: near = true; break
			if near: continue
			var sd := INF
			for s in streets: sd = minf(sd, line_near(p, s.pts).d - float(s.w) / 2)
			if sd < 2.0: continue
			var den := density(p)
			var u := r.next()
			if bool(cfg.get("urban", false)):
				# 읍내 빈 땅은 채마밭(텃밭)·장작더미 — 풀숲이 아니라 쓰는 땅으로(낙안읍성 텃밭)
				if u < 0.3: items.append(_free("garden", "nature/garden_plot", { seed = k, w = snappedf(r.between(4.5, 7.0), 0.1), d = snappedf(r.between(4.0, 6.0), 0.1) }, p, r.between(-0.4, 0.4)))
				elif u < 0.42: items.append(_free("teotbat", "village/teotbat", { seed = k, w = r.between(4.0, 6.0), d = r.between(3.0, 4.2) }, p, r.between(-0.3, 0.3)))
				elif u < 0.48: items.append(_free("tree", "nature/persimmon", { seed = k, s = r.between(0.9, 1.15) }, p, 0.0))
				k += 1
				continue
			if u < 0.34 * float(cfg.get("trees", 1.0)): items.append(_free("tree", "nature/pine" if r.next() < 0.55 else "nature/oak", { seed = k, s = r.between(0.85, 1.25) }, p, r.between(0, TAU)))
			elif u < 0.36 and den < 0.5: items.append(_free("teotbat", "village/teotbat", { seed = k, w = r.between(4.0, 6.0), d = r.between(3.0, 4.2) }, p, r.between(-0.3, 0.3)))
			elif u < 0.42 and den < 0.4: items.append(_free("hay", "village/haystack", { seed = k, s = r.between(0.8, 1.15) }, p, 0.0))
			k += 1
		y += step

# 마당(plaza) 안 빈자리: 길 가운데 띠(반폭 + 1.3m)·필지·다른 마당 것에서 떨어진 점. 없으면 INF
func _plaza_spot(pz: Dictionary, rad: float, placed: Array) -> Vector2:
	for k in 40:
		var q: Vector2 = (pz.c as Vector2) + Vector2(sqrt(r.next()) * float(pz.r) * 1.15, 0).rotated(r.between(0, TAU))
		var ok := true
		for st in streets:
			if line_near(q, st.pts).d < float(st.w) / 2 + 1.3 + rad * 0.5: ok = false; break
		if not ok: continue
		for l in lots:
			if pip(l.poly, q) or _poly_edge_d(l.poly, q) < rad + 0.3: ok = false; break
		if not ok: continue
		for e in placed:
			if q.distance_to(e[0]) < rad + float(e[1]) + 0.6: ok = false; break
		if not ok or _blocked_nonplaza(q, rad): continue
		placed.append([q, rad])
		return q
	return Vector2(INF, INF)

func _blocked_nonplaza(p: Vector2, pad: float) -> bool:
	if not pip(area_poly, p): return true
	for kp in keep_poly:
		if pip(kp, p) or _poly_edge_d(kp, p) < pad: return true
	for k in keep:
		if p.distance_to(k.c) < k.r + pad: return true
	for rv in rivers:
		if line_near(p, rv.pts).d < rv.w / 2 + 3.0 + pad: return true
	return false

static func _poly_edge_d(poly: Array, p: Vector2) -> float:
	var best := INF
	for i in poly.size(): best = minf(best, seg_dist(p, poly[i], poly[(i + 1) % poly.size()]))
	return best

static func _bbox(poly: Array) -> Rect2:
	var lo := Vector2(INF, INF); var hi := Vector2(-INF, -INF)
	for p in poly:
		lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y)); hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
	return Rect2(lo, hi - lo)

func _free(tag: String, kit: String, params: Dictionary, p: Vector2, ry: float) -> Dictionary:
	var n := items.size()
	return { id = "%s_%s%03d" % [String(cfg.get("prefix", "org")), tag, n], kit = kit, params = params, x = snappedf(p.x, 0.01), z = snappedf(p.y, 0.01), ry = snappedf(ry, 0.0001), y = null,
		flatten = false, clear_veg = kit.begins_with("village/"), group = String(cfg.get("group", "고을 짜임")) }

func run() -> Dictionary:
	var t0 := Time.get_ticks_msec()
	grow_streets()
	auto_plazas()
	var t1 := Time.get_ticks_msec()
	if cfg.get("lots", "blocks") == "blocks":
		cut_lots_blocks()
		log.append("필지: 블록 %d" % lots.size())
	elif cfg.get("lots", "blocks") == "strip":
		cut_lots_v()
		var n1 := lots.size()
		cut_lots()   # 남은 틈 메우기(첫 줄 + 작은 필지)
		log.append("필지: 띠 %d + 메우기 %d" % [n1, lots.size() - n1])
	else: cut_lots()
	var t2 := Time.get_ticks_msec()
	fill_lots()
	var t3 := Time.get_ticks_msec()
	dress()
	log.append("시간 ms: 길 %d · 필지 %d · 채움 %d · 꾸밈 %d · 축대 %d" % [t1 - t0, t2 - t1, t3 - t2, Time.get_ticks_msec() - t3, terraces])
	var alleys := []
	for s in streets:
		if s.kind == "trunk": continue
		var pts := []
		for p in s.pts: pts.append([snappedf(p.x, 0.01), snappedf(p.y, 0.01)])
		alleys.append({ id = String(s.id), points = pts, width_m = snappedf(float(s.w), 0.01), kind = String(s.kind) })
	return { items = items, alleys = alleys, streets = streets, lots = lots, plazas = plazas, log = log }
