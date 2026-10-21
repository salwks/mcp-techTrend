# 건물 빌더 폐가(廢家) 옵션 — 명세(spec)의 `ruin` 칸이 모든 유형·프리셋 위에 얹힌다(따로 빌더를 두지 않는다).
#   레퍼런스: 폐가 레퍼런스 문서(공산무인도 872·감로도 689·순절도 947/948·화개현구장도 970 + 이엉·기와·외엮기 문헌) — 단계 값은 게임용 추정.
#   ruin: { stage 0~4(실수 허용), seed, cause("abandon"), collapse_side("left"|"right"|"none" — 없으면 seed), roof_loss, sag, wall_loss,
#           doors("shut"|"ajar"|"hanging"|"fallen"|"gone"), paper(창호지 찢김 0~1), lean_deg, overgrowth, debris, salvaged(true), enterable("auto"|"yes"|"no") }
#   stage: 0 막 비운 집 · 1 몇 해 · 2 반쯤 무너짐(한 칸 꺼질 수 있음) · 3 무너짐(절반 이상 꺼짐, 실내 없음) · 4 터만 남음(기단·주춧돌·더미·풀)
#   칸을 따로 주면 그 칸만 단계 기본값을 덮어쓴다. ruin이 없거나 stage 0 + 칸 없음이면 지금과 똑같이 짓는다(캐시·기존 시트 그대로).
extends RefCounted
const C := preload("res://kit/village/_common.gd")
const A := preload("res://kit/bldg/_atlas.gd")
const Grass := preload("res://kit/nature/grass.gd")

#                 roof_loss  sag   wall_loss doors      paper lean  floor_holes overgrowth debris
const TABLE := [[0.0,       0.0,  0.0,      "ajar",    0.15, 0.0,  0.0,        0.15,      0.05],
				[0.06,      0.12, 0.18,     "hanging", 0.6,  0.8,  0.05,       0.45,      0.25],
				[0.28,      0.22, 0.42,     "fallen",  0.9,  3.5,  0.2,        0.7,       0.5],
				[0.62,      0.3,  0.75,     "gone",    1.0,  8.0,  0.6,        0.9,       0.8],
				[1.0,       0.3,  1.0,      "gone",    1.0,  0.0,  1.0,        1.0,       0.6]]
const KEYS := ["roof_loss", "sag", "wall_loss", "doors", "paper", "lean_deg", "floor_holes", "overgrowth", "debris"]

# 명세 → 풀린 폐가 값(없으면 {})
static func resolve(sp: Dictionary) -> Dictionary:
	var r = sp.get("ruin", null)
	if not (r is Dictionary) or r.is_empty(): return {}
	var st := clampf(float(r.get("stage", 0.0)), 0.0, 4.0)
	var lo := int(floor(st)); var hi := mini(lo + 1, 4); var f := st - lo
	var out := { stage = st, seed = int(r.get("seed", int(sp.get("seed", 1)) * 13 + 5)), cause = String(r.get("cause", "abandon")), salvaged = bool(r.get("salvaged", true)) }
	for k in KEYS.size():
		var a = TABLE[lo][k]; var b = TABLE[hi][k]
		out[KEYS[k]] = (a if f < 0.5 else b) if a is String else lerpf(float(a), float(b), f)
	for k in KEYS:
		if r.has(k): out[k] = r[k]
	var rr := Kit.Rng.new(int(out.seed) * 7 + 3)
	out.side = String(r.get("collapse_side", "left" if rr.next() < 0.5 else "right"))
	out.site = st >= 3.75                 # 터만 남음
	out.interior_ok = st < 2.75 if String(r.get("enterable", "auto")) == "auto" else String(r.enterable) == "yes"
	out.climate = String(r.get("climate", { north = "snow", mountain = "snow", jeju = "coastal" }.get(String(sp.get("region", "south")), "humid")))
	return out

# 날개마다 꺼진 칸(몸채는 무너지는 쪽 끝부터) · 지붕 구멍. ruin 값에 collapsed{wi: [칸…]} · holes[[wi, x, z, r]]을 적는다
static func plan(sp: Dictionary, rz: Dictionary) -> void:
	var rr := Kit.Rng.new(int(rz.seed) * 31 + 11)
	var col := {}; var holes := []
	var wi := 0
	for w in sp.wings:
		var n: int = w.bays.size()
		var k := 0
		if float(rz.stage) >= 1.75:
			k = int(round(n * clampf(float(rz.roof_loss) * 1.1 - 0.15, 0.0, 1.0)))
			if wi > 0 and float(rz.stage) >= 2.5: k = maxi(k, int(ceil(n * 0.5)))
		k = mini(k, n)
		var from_left: bool = String(rz.side) == "left" if wi == 0 else rr.next() < 0.5
		var lst := []
		for j in k: lst.append(j if from_left else n - 1 - j)
		col[wi] = lst
		# 구멍: 꺼지지 않은 칸 위 이엉·기와에(단계 1~3)
		var L := 0.0
		for b in w.bays: L += float(b.w)
		var D := 0.0
		for d in w.depth: D += float(d)
		var nh := 0
		if float(rz.stage) >= 0.75 and float(rz.stage) < 3.75: nh = 1 + int(float(rz.roof_loss) * 4.0 * rr.next())
		var x := -L / 2
		var xs := []
		for b in w.bays: xs.append([x, x + float(b.w)]); x += float(b.w)
		for h in nh:
			var bi := int(rr.next() * n) % n
			if lst.has(bi): continue
			var hx: float = lerpf(xs[bi][0] + 0.5, xs[bi][1] - 0.5, rr.next())
			var hz: float = (rr.next() - 0.5) * D * 0.7
			holes.append([wi, hx, hz, 0.45 + 0.5 * float(rz.stage) * rr.next() * 0.5])
		wi += 1
	rz.collapsed = col
	rz.holes = holes

# ---- 그리기 조각 ------------------------------------------------------------------------------------------
# 외엮기(흙이 떨어진 벽 속): 중깃(세로 0.3m) + 외(가로 0.12m) 막대 — 벽 로컬 사각형 [x0,x1]×[y0,y1], 두께 가운데
static func lath(m: C.M, part: String, x0: float, x1: float, y0: float, y1: float) -> void:
	if x1 - x0 < 0.05 or y1 - y0 < 0.05: return
	var g := Kit.Geo.new()
	var nx := maxi(1, int((x1 - x0) / 0.3))
	for i in nx + 1:
		var x := lerpf(x0 + 0.03, x1 - 0.03, float(i) / nx)
		g = Kit.merge([g, Kit.box(0.035, y1 - y0, 0.035, x, (y0 + y1) / 2, 0.0)])
	var ny := maxi(1, int((y1 - y0) / 0.12))
	for j in ny + 1:
		var y := lerpf(y0 + 0.02, y1 - 0.02, float(j) / ny)
		g = Kit.merge([g, Kit.box(x1 - x0 - 0.02, 0.016, 0.02, (x0 + x1) / 2, y, 0.022 if j % 2 == 0 else -0.022)])
	m.add(part, "wood", C.P(g, 0x6a5038, 0x4a3828, 0.06, m.rng), 0.0)

# 벽 채움 사각형 하나를 무너짐에 따라 나눈다 → [[x0,x1,y0,y1] …](남은 흙), 드러난 자리에는 외엮기를 그린다
static func wall_rects(m: C.M, part: String, rz: Dictionary, r: Array, frame: bool) -> Array:
	var wl := float(rz.wall_loss)
	if wl <= 0.01: return [r]
	var x0: float = r[0]; var x1: float = r[1]; var y0: float = r[2]; var y1: float = r[3]
	var w := x1 - x0; var h := y1 - y0
	var roll := m.r()
	if float(rz.stage) >= 2.75 and roll < wl * 0.8:
		if frame: lath(m, part, x0, x1, y0, y0 + h * (0.3 + 0.6 * m.r()))
		return []
	if roll < wl * 0.55 and w > 0.6 and h > 0.7:
		# 구멍(흙이 떨어져 뚫림): 밑동 쪽일수록 잦다
		var hw := minf(w - 0.2, 0.4 + 0.8 * m.r()); var hh := minf(h - 0.2, 0.4 + 0.9 * m.r())
		var hx0 := x0 + 0.1 + (w - 0.2 - hw) * m.r(); var hy0 := y0 + 0.05 + (h - 0.1 - hh) * pow(m.r(), 1.6)
		if frame: lath(m, part, hx0, hx0 + hw, hy0, hy0 + hh)
		var out := []
		if hx0 > x0 + 0.03: out.append([x0, hx0, y0, y1])
		if hx0 + hw < x1 - 0.03: out.append([hx0 + hw, x1, y0, y1])
		if hy0 > y0 + 0.03: out.append([hx0, hx0 + hw, y0, hy0])
		if hy0 + hh < y1 - 0.03: out.append([hx0, hx0 + hw, hy0 + hh, y1])
		return out
	if roll < wl:
		# 밑동이 패임(빗물·튄 물): 아래 0.08~0.35m 흙이 없고 외엮기 드러남
		var e := minf(h * 0.4, 0.08 + 0.27 * m.r())
		if frame: lath(m, part, x0, x1, y0, y0 + e)
		return [[x0, x1, y0 + e, y1]]
	return [r]

# 문짝·창 한 짝(폐가): 처리했으면 true. lx, ocy = 짝 가운데, lw·oh = 짝 크기(벽 로컬). front = 바깥이 +z
static func leaf(m: C.M, part: String, rz: Dictionary, lx: float, ocy: float, lw: float, oh: float, lkey: String, fw: Array, y_floor: float) -> bool:
	if rz.is_empty(): return false
	var doors := String(rz.doors)
	var torn := m.r() < float(rz.paper)
	var st := doors
	if doors == "hanging" and m.r() < 0.5: st = "ajar"
	if doors == "fallen" and m.r() < 0.35: st = "hanging"
	if doors == "gone" and m.r() < 0.2: st = "fallen"
	if st == "shut" and not torn: return false
	# 짝 뒤 어둠(빈 방이 들여다보임)
	if st in ["fallen", "gone"] or torn:
		m.add(part, "flat", C.P(Kit.box(lw - 0.02, oh - 0.02, 0.02, lx, ocy, -0.12), 0x1f1914), 0)
	if st == "gone": return true
	var g := Kit.Geo.new()
	if torn:
		# 살만 남은 창호(문울거미 + 살 몇 가닥) + 찢긴 종이 조각 둘
		var fr := 0.045
		for q in [[0.0, oh / 2 - fr / 2, lw, fr], [0.0, -oh / 2 + fr / 2, lw, fr], [-lw / 2 + fr / 2, 0.0, fr, oh], [lw / 2 - fr / 2, 0.0, fr, oh]]:
			g = Kit.merge([g, Kit.box(q[2], q[3], 0.05, q[0], q[1], 0.0)])
		for k in 3: g = Kit.merge([g, Kit.box(0.018, oh - 0.08, 0.02, -lw / 2 + lw * (k + 1) / 4.0, 0.0, 0.0)])
		for k in 4: g = Kit.merge([g, Kit.box(lw - 0.08, 0.018, 0.02, 0.0, -oh / 2 + oh * (k + 1) / 5.0, 0.0)])
	else:
		g = Kit.box(lw - 0.05, oh - 0.05, 0.04, 0, 0, 0)
	var px := lx; var py := ocy; var pz := 0.118 + 0.025 * m.r(); var rx := 0.0; var rz2 := 0.0; var ry := 0.0   # 짝마다 앞뒤를 조금 달리(기운 두 짝이 한 평면에 겹치지 않게)
	match st:
		"ajar": ry = 0.5 + 0.6 * m.r(); px = lx - lw / 2 * cos(ry); pz = 0.12 + lw / 2 * sin(ry)
		"hanging": rz2 = (0.25 + 0.2 * m.r()) * (1.0 if m.r() < 0.5 else -1.0); py = ocy - 0.08
		"fallen":
			# 떨어져 앞에 누운 짝(살짝 들린 한쪽)
			rx = -PI / 2 + 0.06; py = y_floor + 0.04 + 0.05 * m.r(); pz = 0.14 + oh / 2; ry = (m.r() - 0.5) * 0.5
	Kit.xf(g, px, py, pz, rx, ry, rz2)
	m.add(part, "wood", C.PA(g, [0x7a6450, 0x5a4838] if not torn else fw, 0.05, m.rng), 0.012)
	if torn and m.r() < 0.8:
		var p := Kit.box(lw * 0.35, oh * 0.18, 0.006)
		Kit.xf(p, lx + (m.r() - 0.5) * lw * 0.4, ocy + (m.r() - 0.2) * oh * 0.3, 0.012, 0, 0, (m.r() - 0.5) * 0.6)
		m.add(part, "flat", C.P(p, 0xd8cfb4, 0xb8ad90, 0.04), 0)
	return true

# 무너진 칸: 흙·짚(초가)·기와 조각(기와) 더미 + 부러진 기둥 하나 누움 + 덮는 충돌(낮은 더미 — 0.32m보다 높아 넘지 못함)
static func mound(m: C.M, part: String, x0: float, x1: float, z0: float, z1: float, y: float, giwa: bool, debris: float) -> void:
	var R := m.rng
	var w := x1 - x0; var d := z1 - z0
	var n := 3 + int(debris * 5.0)
	for i in n:
		var s := Kit.lump(0.5 + 0.6 * m.r(), 0, R, 0.35, 0.5)
		Kit.xf(s, x0 + w * (0.15 + 0.7 * m.r()), y + 0.05, z0 + d * (0.15 + 0.7 * m.r()), 0, m.r() * 3, 0, 1.0 + m.r(), 0.4 + 0.5 * debris, 1.0 + m.r() * 0.6)
		m.add(part, "mud", C.P(s, 0x8c7656, 0x6a573e, 0.08, R), 0.01)
	if giwa:
		for i in int(8 + debris * 14):
			var t := Kit.box(0.28, 0.025, 0.2, x0 + w * m.r(), y + 0.25 + 0.4 * m.r() * debris, z0 + d * m.r())
			Kit.xf(t, 0, 0, 0, (m.r() - 0.5) * 0.9, m.r() * 3, (m.r() - 0.5) * 0.9)
			m.add(part, "flat", C.P(t, 0x5a5d62, 0x44474c, 0.05, R), 0)
	else:
		for i in 2 + int(debris * 3):
			var s := Kit.lump(0.45 + 0.4 * m.r(), 0, R, 0.4, 0.35)
			Kit.xf(s, x0 + w * (0.2 + 0.6 * m.r()), y + 0.35 + 0.2 * debris, z0 + d * (0.2 + 0.6 * m.r()), 0, m.r() * 3, 0, 1.3, 0.5, 1.0)
			m.add(part, "thatch", C.PA(s, [0x6c614c, 0x4a4234], 0.08, R), 0.01)
	# 부러져 누운 기둥·서까래
	for i in 1 + int(debris * 2):
		var L := 1.4 + m.r() * 1.6
		var g := Kit.box(0.16, 0.16, L, 0, 0, 0)
		Kit.xf(g, x0 + w * (0.2 + 0.6 * m.r()), y + 0.2 + 0.35 * m.r(), z0 + d * (0.3 + 0.4 * m.r()), (m.r() - 0.5) * 0.5, m.r() * 3, (m.r() - 0.5) * 0.3)
		m.add(part, "wood", C.P(g, 0x4e4234, 0x3a3128, 0.05, R), 0.012)
	m.box_c(x0 + 0.15, x1 - 0.15, z0 + 0.15, z1 - 0.15)

# 풀(마당 가·기단 둘레·무너진 칸) — 높이는 overgrowth를 따라(짧은 풀 → 허리 높이 억새·쑥대). 먹선 없음
class Off:
	var m
	var part := ""
	var ox := 0.0
	var oy := 0.0
	var oz := 0.0
	var sc := 1.0
	var sy := 1.0
	func add(key: String, g: Kit.Geo, outline := 0.03) -> Kit.Geo:
		Kit.xf(g, ox, oy, oz, 0, 0, 0, sc, sc * sy, sc)
		m.add(part, key, g, outline)
		return g

static func grass(m: C.M, part: String, pts: Array, y: float, og: float, stage: float) -> void:
	var o := Off.new(); o.m = m; o.part = part
	for p in pts:
		o.ox = p.x; o.oz = p.y; o.oy = y
		# 쑥대·망초 높이: 단계가 높을수록 크게(억새 이삭 대신 마른 풀·들풀 키를 키운다)
		var tall := stage >= 1.5 and m.r() < og * 0.6
		o.sc = 0.8 + og * 0.5; o.sy = (1.0 + og * 0.6) * (2.0 if tall else 1.0)   # 키만 키운다(굵게 부풀리지 않게)
		Grass.draw(o, m.rng, { kind = "dry" if m.r() < 0.45 else "meadow", n = 5 + int(og * 6) })

# 덤불(단계 2~): 둥근 풀빛 덩이 + 원 충돌
static func shrub(m: C.M, part: String, x: float, z: float, y: float, s: float) -> void:
	var g := Kit.lump(0.6 * s, 0, m.rng, 0.35, 0.8)
	Kit.xf(g, x, y + 0.45 * s, z)
	m.add(part, "leaf", C.P(g, 0x7d8c58, 0x4a5638, 0.08, m.rng), 0.01)
	m.circle(x, z, 0.45 * s)

# ---- 지은 뒤(모든 단계 메시) ---------------------------------------------------------------------------------
# 지붕 자르기: part "roof"의 삼각형 중 cut(건물 로컬 x, z)가 참인 것을 뺀다(먹선 껍질 포함 — 잘린 가장자리는 너덜한 끝)
static func cut_roof(m: C.M, cut: Callable) -> void:
	if not m.parts.has("roof"): return
	var b: Kit.Batch = m.parts["roof"]
	var tris := 0
	for mk in b.parts:
		var keep := []
		for g in b.parts[mk]:
			var ng := Kit.Geo.new()
			var has_rect: bool = g.rect.size() == g.pos.size() * 4
			var has_n: bool = g.nrm.size() == g.pos.size()
			for i in range(0, g.pos.size() - 2, 3):
				# 긴 삼각형(맞배 이엉 줄·처마 띠는 한 줄이 집 길이만큼)은 잘게 나눠서 자른다 — 안 그러면 잘린 자리에 긴 가시가 남는다
				var stack := [[g.pos[i], g.pos[i + 1], g.pos[i + 2], g.uv[i], g.uv[i + 1], g.uv[i + 2], g.col[i], g.col[i + 1], g.col[i + 2],
					g.nrm[i] if has_n else Vector3.UP, g.nrm[i + 1] if has_n else Vector3.UP, g.nrm[i + 2] if has_n else Vector3.UP, 0]]
				var rect := PackedFloat32Array()
				if has_rect:
					for q in 4: rect.append(g.rect[i * 4 + q])
				while not stack.is_empty():
					var t: Array = stack.pop_back()
					var a: Vector3 = t[0]; var bv: Vector3 = t[1]; var c: Vector3 = t[2]
					var la := a.distance_to(bv); var lb := bv.distance_to(c); var lc := c.distance_to(a)
					var mx := maxf(la, maxf(lb, lc))
					var cen := (a + bv + c) / 3.0
					var ia: bool = cut.call(a.x, a.z, a.y); var ib: bool = cut.call(bv.x, bv.z, bv.y); var ic: bool = cut.call(c.x, c.z, c.y)
					var ice: bool = cut.call(cen.x, cen.z, cen.y)
					var mixed: bool = not ((ia and ib and ic and ice) or not (ia or ib or ic or ice))   # 자르는 선에 걸친 것만 나눈다
					if mx > 0.8 and int(t[12]) < 5 and mixed:
						# 가장 긴 변을 반으로
						var sh: Array = [[0, 1, 2], [1, 2, 0], [2, 0, 1]][0 if mx == la else (1 if mx == lb else 2)]
						var P := [t[0], t[1], t[2]]; var U := [t[3], t[4], t[5]]; var Cc := [t[6], t[7], t[8]]; var N := [t[9], t[10], t[11]]
						var i0: int = sh[0]; var i1: int = sh[1]; var i2: int = sh[2]
						var mp: Vector3 = (P[i0] + P[i1]) / 2; var mu: Vector2 = (U[i0] + U[i1]) / 2; var mc: Color = (Cc[i0] as Color).lerp(Cc[i1], 0.5); var mn: Vector3 = ((N[i0] + N[i1]) / 2).normalized()
						var d := int(t[12]) + 1
						stack.append([P[i0], mp, P[i2], U[i0], mu, U[i2], Cc[i0], mc, Cc[i2], N[i0], mn, N[i2], d])
						stack.append([mp, P[i1], P[i2], mu, U[i1], U[i2], mc, Cc[i1], Cc[i2], mn, N[i1], N[i2], d])
						continue
					if ice: continue
					for k in 3:
						ng.pos.append(t[k]); ng.uv.append(t[3 + k]); ng.col.append(t[6 + k]); ng.nrm.append(t[9 + k])
						if has_rect: ng.rect.append_array(rect)
			if ng.pos.size() > 0: keep.append(ng); tris += ng.pos.size() / 3
		b.parts[mk] = keep
	b.tris = tris

# 기울기(전단): y > y0인 꼭짓점을 x로 (y − y0)·tan 만큼 — base 부분은 그대로
static func lean(m: C.M, deg: float, dirx: float, y0: float) -> void:
	if absf(deg) < 0.05: return
	var t := tan(deg_to_rad(deg)) * dirx
	for p in m.parts:
		if p == "base": continue
		var b: Kit.Batch = m.parts[p]
		for mk in b.parts:
			for g in b.parts[mk]:
				for i in g.pos.size():
					var v: Vector3 = g.pos[i]
					if v.y > y0: g.pos[i] = Vector3(v.x + (v.y - y0) * t, v.y, v.z)

# 부분을 다시 한 덩이로(실내 없는 폐가 — 그리기 호출 줄임)
static func merge_all(m: C.M) -> void:
	var all := Kit.Batch.new()
	for p in m.order:
		var b: Kit.Batch = m.parts[p]
		for mk in b.parts:
			if not all.parts.has(mk): all.parts[mk] = []
			all.parts[mk].append_array(b.parts[mk])
		all.tris += b.tris
	m.parts = { all = all }
	m.order = ["all"]
	m.merge_parts = true
