# 건물 빌더 — 명세(kit/bldg/_spec.gd)로 조선 건물 한 채를 짓는 키트. 계약서 §4 build(params) → { node, colliders, walk, lights, anchors, interior … }
#   params: { type, region, cls, seed, over?, interior? }  또는  { spec: {…완성 명세…} }   lod: -1(기본, 세 단계 + 거리 전환) | 0 | 1 | 2(그 단계만)
# 세 단계(한 노드 안 near/mid/far, MeshInstance3D.visibility_range):
#   near(0~55m)  기단·주춧돌·기둥·창방·도리·벽 짜임(인방·중방)·창살 문짝·툇마루·댓돌·계단·서까래 끝·막새·용마루·굴뚝·곁 것·(실내)
#   mid(55~160m) 기단·몸 상자·앞 기둥·창호 판·지붕(거친 칸)·용마루      far(160m~) 몸 상자 + 지붕 덩이
# 재질은 Kit 공용 아틀라스 재질 하나(+천) — 건물마다 따로 만들지 않는다. 키트 캐시(kit_cache)가 params 해시로 그대로 담는다.
# 좌표: 원점 = 몸채(첫 날개) 가운데 땅, 앞 +z. 날개는 명세 x·z·ry로 놓인다.
extends RefCounted
const C := preload("res://kit/village/_common.gd")
const A := preload("res://kit/bldg/_atlas.gd")
const RF := preload("res://kit/bldg/_roof.gd")
const S := preload("res://kit/bldg/_spec.gd")
const FU := preload("res://kit/bldg/_furn.gd")
const PR := preload("res://kit/village/props.gd")
const MS := preload("res://kit/village/market_shop.gd")
const JD := preload("res://kit/village/jangdok.gd")
const FW := preload("res://kit/village/firewood.gd")
const DP := preload("res://kit/village/dress_props.gd")

const RANGES := [[0.0, 55.0], [55.0, 160.0], [160.0, 0.0]]
const LOD_NAMES := ["near", "mid", "far"]
const OPEN_FNS := ["hall", "maru", "shed", "mill", "forge", "shop", "stable"]

static func build(params: Dictionary) -> Dictionary:
	var t0 := Time.get_ticks_usec()
	var sp := S.resolve(params)
	var want: int = int(params.get("lod", -1))
	var lods: Array = [0, 1, 2] if want < 0 else [want]
	var inside: bool = sp.interior
	var root := Node3D.new(); root.name = String(sp.id)
	var res := {}
	var tris := []
	for lod in lods:
		var m := C.M.new(int(sp.seed) * 31 + 7, not (inside and lod == 0))
		var info := draw(m, sp, lod)
		var node := m.build_node(LOD_NAMES[lod])
		tris.append(m.tris())
		if want < 0:
			for mi in node.find_children("*", "MeshInstance3D", true, false):
				var g := mi as GeometryInstance3D
				g.visibility_range_begin = RANGES[lod][0]
				g.visibility_range_end = RANGES[lod][1]
				g.visibility_range_begin_margin = 2.0 if lod > 0 else 0.0
				g.visibility_range_end_margin = 2.0 if lod < 2 else 0.0
				if lod == 2: g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(node)
		if res.is_empty():
			res = { colliders = m.colliders, lights = m.lights, anchors = m.anchors, occluder = true, footprint = info.footprint }
			if not m.walks.is_empty(): res.walk = m.walks
			res.info = info
	res.node = root
	if inside:
		var near := root.get_node_or_null("near")
		var hide := []
		for p in ["roof", "front"]:
			var n = near.get_node_or_null(p) if near else null
			if n: hide.append(n)
		var b: Rect2 = res.info.body
		res.interior = { minX = b.position.x, maxX = b.end.x, minZ = b.position.y, maxZ = b.end.y,
			camera = { pitch = 52, distance = 10.5, fov = 32 }, hide = hide }
	res.stats = { tris = tris, gen_ms = (Time.get_ticks_usec() - t0) / 1000.0, lods = lods }
	res.spec_id = sp.id
	if res.info.has("chimney"): res.anchors["chimney"] = res.info.chimney
	res.erase("info")
	return res

# ---------------------------------------------------------------------------------------------------
# 한 단계 그리기
# ---------------------------------------------------------------------------------------------------
static func draw(m: C.M, sp: Dictionary, lod: int) -> Dictionary:
	var ctx := _ctx(sp)
	var body := Rect2(); var first := true
	var fp_box := Rect2()
	var chimney_at = null
	var wi := 0
	for w in sp.wings:
		var old := m.push(float(w.x), 0, float(w.z), float(w.ry))
		var info := _wing(m, sp, ctx, w, lod, wi)
		if wi == int(sp.chimney.get("wing", 0)) and sp.chimney.kind != "none":
			chimney_at = _chimney(m, sp, ctx, info, lod)
		m.pop(old)
		var xf := Transform3D(Basis(Vector3.UP, float(w.ry)), Vector3(float(w.x), 0, float(w.z)))
		var r := _xf_rect(info.body, xf)
		var rf := _xf_rect(info.eaves, xf)
		if first:
			body = r; fp_box = rf; first = false
		else:
			fp_box = fp_box.merge(rf)
		wi += 1
	if lod == 0: _attachments(m, sp, ctx)
	var out := { body = body, footprint = Vector2(maxf(absf(fp_box.position.x), absf(fp_box.end.x)) * 2.0 + 0.4, maxf(absf(fp_box.position.y), absf(fp_box.end.y)) * 2.0 + 0.4) }
	if chimney_at != null: out.chimney = chimney_at
	return out

static func _xf_rect(r: Rect2, xf: Transform3D) -> Rect2:
	var a := xf * Vector3(r.position.x, 0, r.position.y); var b := xf * Vector3(r.end.x, 0, r.end.y)
	return Rect2(Vector2(minf(a.x, b.x), minf(a.z, b.z)), Vector2(absf(b.x - a.x), absf(b.z - a.z)))

# 공용 값(색·높이)
static func _ctx(sp: Dictionary) -> Dictionary:
	var wear: float = sp.wear
	var hi: bool = sp.cls in ["yangban", "official"]
	var paint: String = sp.paint
	var wood := [0x6b5038, 0x4d3826]
	if wear > 0.5: wood = [0x6a5a48, 0x4c4034]   # 낡은 나무는 잿빛
	var col: Array = wood
	var beam: Array = wood
	if paint == "gachil": col = [0x7a3a2a, 0x5a2a1e]; beam = [0x5f8072, 0x48675a]
	elif paint == "full": col = [0x8a3e2e, 0x6a2e22]; beam = [0x557d70, 0x3f6558]
	var wallc: Array
	match String(sp.wall):
		"plaster": wallc = [0xece4cf, 0xd8ccb0]
		"stone": wallc = [0x5a5650, 0x3e3b37]
		"board": wallc = [0x7a5c40, 0x5a4430]
		_:
			wallc = [0xd2b98c, 0xa88c62] if wear < 0.6 else [0xbfa880, 0x977e5a]
			var tint: float = float(sp.get("wall_tint", 0.5))
			if tint < 0.33: wallc = [0xc9a476, 0x9a7a52]       # 붉은 황토
			elif tint > 0.75: wallc = [0xb8ad94, 0x8c826c]     # 잿빛 흙
	var Fb: float = float(sp.base.h) if sp.base.kind != "none" else 0.05
	return { wear = wear, hi = hi, wood = wood, col = col, beam = beam, wallc = wallc, Fb = Fb, Ff = Fb + float(sp.floor_dh),
		paint = paint, lattice = String(sp.lattice), thick_roof = sp.roof.kind == "giwa" }

# 바닥 높이(칸 쓰임별)
static func _bay_floor(ctx: Dictionary, w: Dictionary, b: Dictionary) -> float:
	match String(b.fn):
		"kitchen": return 0.04
		"gate": return 0.04
		"shed", "stable", "mill", "forge": return ctx.Fb
	return float(ctx.Ff) + float(w.floor_up) + float(b.get("floor_up", 0.0))

# ---------------------------------------------------------------------------------------------------
# 날개(一자 몸채) 하나
# ---------------------------------------------------------------------------------------------------
static func _wing(m: C.M, sp: Dictionary, ctx: Dictionary, w: Dictionary, lod: int, wi: int) -> Dictionary:
	var bays: Array = w.bays
	var L := 0.0
	for b in bays: L += float(b.w)
	var D := 0.0
	for d in w.depth: D += float(d)
	var zf := D / 2.0; var zb := -D / 2.0
	var tk: String = w.toet.kind; var T: float = float(w.toet.d) if tk != "none" else 0.0
	var Fb: float = ctx.Fb
	var Ff: float = float(ctx.Ff) + float(w.floor_up)
	var raised := Ff - Fb > 1.2   # 누각: 아래층 트인 기둥
	var top: float = Ff + float(sp.wall_h) + float(w.roof_up)
	if raised: top = Ff + float(sp.wall_h)
	var xs := [-L / 2.0]
	for b in bays: xs.append(float(xs[xs.size() - 1]) + float(b.w))
	var floors := []
	for b in bays: floors.append(_bay_floor(ctx, w, b))
	var zcol := zf + (T if tk == "toet" else 0.0)   # 앞 기둥 줄(퇴기둥)
	var R := m.rng
	var hiq: bool = ctx.hi
	var info := { L = L, D = D, zf = zf, zb = zb, top = top, Ff = Ff, xs = xs, body = Rect2(-L / 2, zb, L, D) }

	# --- 기단 ---------------------------------------------------------------------------------
	var runs := _runs(bays, func(b): return not (b.fn in ["kitchen", "gate"] or b.front.kind == "join"))
	var mfront := (T + 0.55 if tk != "none" else 0.6) + (0.45 if float(sp.floor_dh) > 0.12 else 0.0)   # 댓돌 앞 디딤 자리
	var mback := 0.5; var mside := 0.5
	if sp.base.kind != "none":
		for rn in runs:
			var butt: Array = w.get("butt", [false, false])
			var bcut: Array = w.get("base_cut", [false, false])
			butt = [butt[0] or bcut[0], butt[1] or bcut[1]]
			var x0: float = xs[rn[0]] - (mside if rn[0] == 0 and not w.open_end[0] and not butt[0] else 0.0)
			var x1: float = xs[rn[1] + 1] + (mside if rn[1] == bays.size() - 1 and not w.open_end[1] and not butt[1] else 0.0)
			_base(m, sp, ctx, x0, x1, zb - mback, zf + mfront, Fb - 0.016 * wi, lod)   # 날개 기단은 몸채보다 1.6cm 낮게(겹친 앞 여유가 한 평면이 되지 않게)
			m.walk_floor(x0, x1, zb - mback, zf + mfront, Fb)
		# ㄱ자 모퉁이 칸(앞이 몸채 끝 벽): 앞 여유 없이(몸채 기단과 겹치지 않게)
		for rn in _runs(bays, func(b): return b.front.kind == "join" and not (b.fn in ["kitchen", "gate"])):
			var x0: float = xs[rn[0]] - (mside if rn[0] == 0 and not w.open_end[0] else 0.0)
			var x1: float = xs[rn[1] + 1] + (mside if rn[1] == bays.size() - 1 and not w.open_end[1] else 0.0)
			_base(m, sp, ctx, x0, x1, zb - mback, zf - 0.004, Fb - 0.004, lod)
			m.walk_floor(x0, x1, zb - mback, zf, Fb)
	# 바닥 몸(기단 위 ~ 방·마루 바닥): 고막이
	if Ff - Fb > 0.02 and not raised:
		for rn in _runs(bays, func(b): return not (b.fn in ["kitchen", "gate", "shed", "stable", "mill", "forge"])):
			var x0: float = xs[rn[0]]; var x1: float = xs[rn[1] + 1]
			m.add("base", "mud" if sp.wall != "stone" else "stone", C.PA(Kit.box(x1 - x0 - 0.004, Ff - Fb - 0.004, D - 0.004, (x0 + x1) / 2, (Fb + Ff) / 2 - 0.002, 0), [0x9a8462, 0x7a6648] if sp.wall != "plaster" else [0xb8b0a0, 0x908878], 0.04, R), 0.02 if lod == 0 else 0.0)

	# --- 아래 단계(mid·far): 몸 상자 + 창호 판 + 지붕 --------------------------------------------
	if lod > 0:
		_wing_coarse(m, sp, ctx, w, lod, info, bays, xs, floors, top, zf, zb, zcol, T, tk, raised)
		info.eaves = _roof(m, sp, ctx, w, lod, info, zcol)
		_soseul(m, sp, ctx, w, lod, info, bays, xs, zcol)
		return info

	# --- 주춧돌 · 기둥 --------------------------------------------------------------------------
	var zlines := [zb, zf]
	var acc := 0.0
	for i in range(0, w.depth.size() - 1):
		acc += float(w.depth[i]); zlines.append(zb + acc)
	var cols := []
	for i in xs.size():
		var x: float = xs[i]
		var bot := Fb
		var adj := []
		if i > 0: adj.append(bays[i - 1])
		if i < bays.size(): adj.append(bays[i])
		for b in adj:
			if b.fn == "kitchen" or b.fn == "gate": bot = 0.0
		var joined_bay := false
		for b in adj:
			if b.front.kind == "join": joined_bay = true
		for z in zlines:
			if i == 0 and w.open_end[0] or i == xs.size() - 1 and w.open_end[1]:
				if absf(z - zf) > 0.01 and absf(z - zb) > 0.01: continue
			if joined_bay and absf(z - zf) < 0.01: continue   # ㄱ자 모퉁이 칸 앞 기둥 = 몸채 끝 기둥(같은 자리 두 번 세우지 않음)
			cols.append([x, z, bot])
		if tk == "toet":
			var ok := false
			for b in adj:
				if _has_maru(b): ok = true
			if ok: cols.append([x, zcol, Fb])
	var cr: float = float(sp.col) / 2.0
	for c in cols:
		_column(m, sp, ctx, c[0], c[1], c[2], top, cr, raised)

	# --- 창방 · 도리 · 퇴보 ---------------------------------------------------------------------
	var beam: Array = ctx.beam
	var bh := 0.22
	for z in [zcol, zb]:
		var g := Kit.box(L + 0.1, bh, 0.2, 0, top + bh / 2, z)
		if ctx.paint == "full":
			_dancheong_beam(m, "front" if z > 0 else "body", L + 0.3, bh, z, top + bh / 2)
		else:
			m.add("front" if z > 0 else "body", "wood", C.PA(g, beam, 0.03, R), 0.02)
		var dext := 0.3 if sp.roof.kind == "giwa" else 0.15   # 도리 내밀기(초가는 둥근 처마 모서리 밖으로 나오지 않게 짧게)
		var dor := Kit.cyl(0.13, 0.13, L + dext, 8, 0, top + bh + 0.13, z, 0, 0, PI / 2) if hiq else Kit.box(L + dext - 0.1, 0.18, 0.18, 0, top + bh + 0.09, z)
		m.add("front" if z > 0 else "body", "wood", C.PA(dor, ctx.wood, 0.03, R), 0.02)
	for sx in [-1.0, 1.0]:
		if w.open_end[0 if sx < 0 else 1]: continue
		m.add("body", "wood", C.PA(Kit.box(0.15, bh - 0.02, zcol - zb - 0.2, sx * L / 2, top + bh / 2, (zcol + zb) / 2), beam, 0.03, R), 0.02)   # 옆 창방(앞뒤 창방 사이 — 모서리에서 겹치지 않게 조금 가늘고 짧게)
	if tk == "toet":
		for i in xs.size():
			m.add("front", "wood", C.PA(Kit.box(0.12, 0.17, T - 0.1, xs[i], top + 0.1, zf + T / 2), ctx.wood, 0.03, R), 0.012)
	# 하방(문지방 줄) 없는 칸 바닥 귀틀: 트인 칸 앞 끝
	# --- 면(벽·창호) ---------------------------------------------------------------------------
	var lights := 0
	for i in bays.size():
		var b: Dictionary = bays[i]
		var x0: float = xs[i]; var x1: float = xs[i + 1]; var cx := (x0 + x1) / 2; var bw := x1 - x0
		var y0: float = floors[i]
		if raised and b.fn == "maru": continue
		var fk: String = b.front.kind
		if sp.interior and b.fn == "room" and fk in ["door2", "door1"]: b.front.open = true
		_face(m, "front", sp, ctx, Vector3(cx, 0, zf), 0.0, bw, y0, top, b.front, b, lod)
		_face(m, "body", sp, ctx, Vector3(cx, 0, zb), PI, bw, y0, top, b.back, b, lod)
		if b.fn == "room" and lights < 2 and fk in ["door2", "door1", "window", "door4"]:
			m.light(cx, y0 + 1.1, zf + 0.25, "window"); lights += 1
	# 옆벽(끝 칸)
	for sd in [0, 1]:
		if w.open_end[sd]: continue
		var bi: int = 0 if sd == 0 else bays.size() - 1
		var b: Dictionary = bays[bi]
		if raised and b.fn == "maru": continue
		var x: float = -L / 2 if sd == 0 else L / 2
		var zz := zb
		for d in w.depth:
			var seg := float(d)
			var kind := "wall"
			if b.has("side"): kind = b.side.kind
			elif b.fn in ["maru"]: kind = "open"
			elif b.fn in ["room"] and seg > 2.0 and R.next() < 0.5: kind = "smallwin"
			elif b.fn == "kitchen" and R.next() < 0.6: kind = "salchang"
			_face(m, "body", sp, ctx, Vector3(x, 0, zz + seg / 2), -PI / 2 if sd == 0 else PI / 2, seg, floors[bi], top, { kind = kind }, b, lod)
			zz += seg
	# 칸막이(실내 또는 트인 칸 옆)
	for i in range(1, bays.size()):
		var a: Dictionary = bays[i - 1]; var b: Dictionary = bays[i]
		var oa := _is_open(a); var ob := _is_open(b)
		if not (sp.interior or oa or ob): continue
		if oa and ob: continue
		var kind := _partition_kind(a, b)
		var zz := zb
		for d in w.depth:
			var seg := float(d)
			_face(m, "interior" if sp.interior else "body", sp, ctx, Vector3(xs[i], 0, zz + seg / 2), PI / 2, seg, maxf(floors[i - 1], floors[i]) if kind != "wall" else minf(floors[i - 1], floors[i]), top, { kind = kind, inner = true }, b, lod)
			zz += seg
	# 겹집 가운데 줄 칸막이(방 칸)
	if w.depth.size() > 1 and sp.interior:
		for i in bays.size():
			if bays[i].fn != "room": continue
			var bw: float = xs[i + 1] - xs[i]
			_face(m, "interior", sp, ctx, Vector3((xs[i] + xs[i + 1]) / 2, 0, zlines[2]), 0.0, bw, floors[i], top, { kind = "door1", inner = true }, bays[i], lod)

	# --- 바닥(장판·마루·흙) + 툇마루 + 댓돌·계단 -----------------------------------------------
	for i in bays.size():
		var b: Dictionary = bays[i]
		var x0: float = xs[i]; var x1: float = xs[i + 1]; var cx := (x0 + x1) / 2; var bw := x1 - x0
		var y: float = floors[i]
		var part := "interior" if sp.interior else "body"
		match String(b.fn):
			"room", "shrine":
				if sp.interior or b.fn == "shrine": A.add(m, part, "jangpan" if b.fn == "room" else "maru", A.floor_quad(bw - 0.12, D - 0.12, cx, y + 0.012, 0), 0)
			"hall", "maru", "shop":
				A.add(m, "body", "maru", A.floor_quad(bw - 0.04, D - 0.04, cx, y + 0.012, 0), 0)
				if b.fn == "maru" and float(b.get("floor_up", 0.0)) > 0.0:
					m.add("base", "wood", C.PA(Kit.box(bw, y - Ff, D, cx, (y + Ff) / 2, 0), ctx.wood, 0.03, R), 0.02)
			"kitchen", "shed", "stable", "mill", "forge", "gate":
				m.add("body", "flat", C.P(Kit.box(bw - 0.3, 0.02, D - 0.3, cx, y + 0.01, 0), 0x7a6650, 0x6a5844, 0.04), 0)
		# 걷기 면: 트인 칸 · 실내면 방까지
		if _is_open(b) or sp.interior or b.fn in ["kitchen", "gate"]:
			m.walk_floor(x0 + 0.05, x1 - 0.05, zb + 0.1, zf - 0.02, y + (0.012 if b.fn in ["hall", "maru", "shop", "room", "shrine"] else 0.0))
	if raised:
		_raised_floor(m, sp, ctx, L, D, Ff, Fb, xs, lod)
	elif sp.get("rail", false):
		_railing(m, L + 0.1, D + 0.1, Ff, false)
	# 툇마루·쪽마루
	if tk != "none" and not raised:
		for rn in _runs(bays, func(b): return _has_maru(b)):
			var x0: float = xs[rn[0]] - (0.15 if rn[0] == 0 else 0.0)
			var x1: float = xs[rn[1] + 1] + (0.15 if rn[1] == bays.size() - 1 else 0.0)
			var y := Ff + 0.0
			m.add("front", "wood", C.PA(Kit.box(x1 - x0, 0.1, T - 0.01, (x0 + x1) / 2, y - 0.06, zf + T / 2 + 0.005), [0x8a6a48, 0x6a5038], 0.03, R), 0.02)
			A.add(m, "front", "maru", A.floor_quad(x1 - x0, T, (x0 + x1) / 2, y + 0.006, zf + T / 2), 0)
			m.add("front", "wood", C.PA(Kit.box(x1 - x0 + 0.04, 0.14, 0.12, (x0 + x1) / 2, y - 0.07, zf + T - 0.04), ctx.wood, 0.03, R), 0.015)
			if tk == "jjok":
				var n := maxi(2, int((x1 - x0) / 1.6) + 1)
				for k in n:
					var px := lerpf(x0 + 0.15, x1 - 0.15, float(k) / (n - 1))
					m.add("front", "wood", C.PA(Kit.box(0.1, y - Fb, 0.1, px, (y + Fb) / 2, zf + T - 0.08), ctx.wood), 0)
			m.walk_floor(x0, x1, zf - 0.02, zf + T, y + 0.002)
			m.anchor("maru" if wi == 0 else "maru%d" % wi, Vector3((x0 + x1) / 2, y, zf + T * 0.5))
	# 댓돌 · 계단
	_steps(m, sp, ctx, w, wi, bays, xs, floors, zf, T, tk, Fb, Ff, mfront, raised)

	# --- 칸 속 살림(트인 칸은 늘, 닫힌 방은 실내일 때) -------------------------------------------
	for i in bays.size():
		var b: Dictionary = bays[i]
		var x0: float = xs[i]; var x1: float = xs[i + 1]
		if not (sp.interior or _is_open(b) or b.fn == "kitchen" and b.front.kind == "open"): continue
		_furnish(m, sp, ctx, b, x0, x1, zb, zf, floors[i], i, bays, top)

	# --- 충돌체 ---------------------------------------------------------------------------------
	for i in bays.size():
		var b: Dictionary = bays[i]
		var x0: float = xs[i]; var x1: float = xs[i + 1]
		var open: bool = _is_open(b) or b.fn == "gate" or (sp.interior and b.fn in ["room", "kitchen", "shrine", "jeongju"]) or (b.fn == "kitchen" and b.front.kind == "open")
		if raised: open = true
		if not open:
			m.box_c(x0, x1, zb - 0.1, zf + 0.1)
			continue
		if not (b.back.kind in ["open", "gate"]) and not raised: m.box_c(x0, x1, zb - 0.12, zb + 0.12)
		if i == 0 and not w.open_end[0] and not raised and b.fn != "maru": m.box_c(x0 - 0.12, x0 + 0.12, zb, zf)
		if i == bays.size() - 1 and not w.open_end[1] and not raised and b.fn != "maru": m.box_c(x1 - 0.12, x1 + 0.12, zb, zf)
		if sp.interior and b.fn in ["room", "kitchen", "shrine", "jeongju"] and b.front.kind != "open":
			# 앞벽: 문 자리(가운데 0.9m)만 트임
			var cx := (x0 + x1) / 2
			m.box_c(x0, cx - 0.45, zf - 0.1, zf + 0.1); m.box_c(cx + 0.45, x1, zf - 0.1, zf + 0.1)
	if sp.interior:
		for i in range(1, bays.size()):
			var x: float = xs[i]
			var k := _partition_kind(bays[i - 1], bays[i])
			if k == "open": continue
			if k == "wall": m.box_c(x - 0.08, x + 0.08, zb, zf)
			else:
				m.box_c(x - 0.08, x + 0.08, zb, -0.45); m.box_c(x - 0.08, x + 0.08, 0.45, zf)
	if raised:
		for c in cols: m.circle(c[0], c[1], cr + 0.05)

	# --- 앵커 -----------------------------------------------------------------------------------
	for i in bays.size():
		var b: Dictionary = bays[i]
		var cx: float = (xs[i] + xs[i + 1]) / 2
		var pre := "" if wi == 0 else "w%d_" % wi
		match String(b.fn):
			"hall": if not m.anchors.has(pre + "daecheong"): m.anchor(pre + "daecheong", Vector3(cx, floors[i], zf - 0.8))
			"kitchen": if not m.anchors.has(pre + "kitchen"): m.anchor(pre + "kitchen", Vector3(cx, floors[i], zf + 0.6))
			"room": if not m.anchors.has(pre + "door"): m.anchor(pre + "door", Vector3(cx, 0, zf + T + 1.3))
			"shop": m.anchor(pre + "shop%d" % i, Vector3(cx, 0, zf + 1.2))
	# --- 지붕 -----------------------------------------------------------------------------------
	info.eaves = _roof(m, sp, ctx, w, lod, info, zcol)
	_soseul(m, sp, ctx, w, lod, info, bays, xs, zcol)
	return info

# 솟을대문 칸 x 범위 [x0, x1](날개 로컬) — 없으면 []
static func _soseul_span(w: Dictionary, info: Dictionary) -> Array:
	var xs: Array = info.xs
	for i in w.bays.size():
		if w.bays[i].get("soseul", false): return [float(xs[i]), float(xs[i + 1])]
	return []

# 솟을대문: 대문 칸만 기둥을 올리고 맞배 지붕을 한 층 높게(양옆 행랑 지붕이 그 밑으로 지나간다)
static func _soseul(m: C.M, sp: Dictionary, ctx: Dictionary, w: Dictionary, lod: int, info: Dictionary, bays: Array, xs: Array, zcol: float) -> void:
	if sp.roof.kind != "giwa": return
	for i in bays.size():
		var b: Dictionary = bays[i]
		if not b.get("soseul", false): continue
		var cx: float = (xs[i] + xs[i + 1]) / 2; var bw: float = xs[i + 1] - xs[i]
		var up := 1.05
		var top: float = info.top
		for x in [xs[i], xs[i + 1]]:
			for z in [info.zb, info.zf]:
				m.add("body", "wood", C.PA(Kit.box(0.22, up, 0.22, x, top + up / 2, z), ctx.col, 0.03), 0.015 if lod == 0 else 0.0)
		m.add("front", "wood", C.PA(Kit.box(bw + 0.3, 0.22, 0.2, cx, top + up + 0.11, info.zf), ctx.beam, 0.03), 0.015 if lod == 0 else 0.0)
		var rd: Dictionary = info.get("roof_dims", {})
		if rd.is_empty(): return
		var za: float = rd.za; var zb2: float = rd.zb2
		var hd: float = rd.hd; var hw := bw / 2 + 0.6
		var rise: float = rd.rise
		var old := m.push(cx, 0, (za + zb2) / 2)
		var eave: float = float(rd.eave) + up
		RF.giwa(m, "roof", { hw = hw, hd = hd, eave = eave, rise = rise, thick = 0.22, lift = 0.35, ends = ["gable", "gable"], L = bw, D = info.D, lod = lod,
			rafter_col = ctx.wood, rafters = lod == 0 })
		if lod == 0:
			for sd in [-1.0, 1.0]: _pungpan(m, sd * (bw / 2 + 0.2), hd, eave, rise, top + 0.4, sd, info.D, zcol, 0.0)
		m.pop(old)

static func _has_maru(b: Dictionary) -> bool:
	return b.fn in ["room", "hall", "shrine", "jeongju"] and b.front.kind != "join"

static func _is_open(b: Dictionary) -> bool:
	if b.fn in OPEN_FNS: return true
	return b.front.kind in ["open", "bunhap_up"] and b.fn != "room"

static func _partition_kind(a: Dictionary, b: Dictionary) -> String:
	var fa: String = a.fn; var fb: String = b.fn
	if fa in ["hall", "maru"] and fb in ["hall", "maru"]: return "open"
	if fa == "room" and fb == "room": return "door1"
	if (fa == "room" and fb in ["hall", "maru"]) or (fb == "room" and fa in ["hall", "maru"]): return "door2"
	if (fa == "kitchen" and fb in ["room", "jeongju"]) or (fb == "kitchen" and fa in ["room", "jeongju"]): return "door1"
	if fa == "jeongju" or fb == "jeongju": return "open"
	if fa == "shrine" and fb == "shrine": return "open"
	return "wall"

# 조건에 맞는 연속 칸 묶음 [[i0, i1] …]
static func _runs(bays: Array, ok: Callable) -> Array:
	var out := []; var s := -1
	for i in bays.size():
		if ok.call(bays[i]):
			if s < 0: s = i
		elif s >= 0:
			out.append([s, i - 1]); s = -1
	if s >= 0: out.append([s, bays.size() - 1])
	return out

# ---------------------------------------------------------------------------------------------------
# 기단
static func _base(m: C.M, sp: Dictionary, ctx: Dictionary, x0: float, x1: float, z0: float, z1: float, h: float, lod: int) -> void:
	var R := m.rng
	var cx := (x0 + x1) / 2; var cz := (z0 + z1) / 2; var W := x1 - x0; var Dd := z1 - z0
	var kind: String = sp.base.kind
	match kind:
		"earth":
			m.add("base", "mud", C.PA(Kit.box(W, h, Dd, cx, h / 2, cz), [0xb9a27a, 0x9a845e], 0.04, R), 0.025 if lod == 0 else 0.0)
			if lod == 0:
				var n := int(W / 0.55)
				for i in n:
					var s := Kit.lump(0.13 + m.r() * 0.06, 0, R, 0.3, 0.6)
					m.add("base", "stone", C.P(Kit.xf(s, x0 + 0.2 + (W - 0.4) * i / maxf(n - 1, 1), h - 0.06, z1 - 0.02), 0xa8a294, 0x857f74, 0.05, R), 0)
		"jangdae":
			var tiers: int = int(sp.base.get("tiers", 2))
			var th := h / tiers
			for t in tiers:
				var inset := (tiers - 1 - t) * 0.0
				var y0 := t * th
				m.add("base", "stone", C.PA(Kit.box(W - inset, th, Dd - inset, cx, y0 + th / 2, cz), [0xb5afa2, 0x948f84], 0.04, R), 0.02 if lod == 0 else 0.0)
				if lod == 0:
					# 장대석 이음(앞·옆 면): 길쭉한 돌 줄눈
					var xx := x0 + (0.3 if t % 2 == 1 else 0.0) + m.r() * 0.3
					while xx < x1 - 0.2:
						var lw := 0.9 + m.r() * 0.8
						m.add("base", "flat", C.P(Kit.box(0.025, th - 0.03, 0.02, xx + lw, y0 + th / 2, z1 + 0.005), 0x6e6a62), 0)
						xx += lw
					m.add("base", "flat", C.P(Kit.box(W - 0.02, 0.018, 0.02, cx, y0 + th - 0.013, z1 + 0.006), 0x7e7a72), 0)   # 단 줄눈(윗면보다 0.4cm 낮게)
		_:
			m.add("base", "stone", C.PA(Kit.box(W, h, Dd, cx, h / 2, cz), [0x8f897c, 0x66625a], 0.05, R), 0.025 if lod == 0 else 0.0)
			if lod == 0:
				# 막돌 허튼층: 앞면에 박힌 돌 두 줄
				var rows := 1 if h < 0.3 else 2
				for rr in rows:
					var n := int(W / 0.42)
					for i in n:
						var s := Kit.lump(0.12 + m.r() * 0.08, 0, R, 0.3, 0.55)
						var px := x0 + 0.15 + (W - 0.3) * (i + (0.5 if rr == 1 else 0.0)) / maxf(n, 1)
						if px > x1 - 0.1: continue
						m.add("base", "stone", C.P(Kit.xf(s, px, h * (0.3 + rr * 0.42), z1 - 0.04, 0, m.r() * 3.0, 0, 1, 0.7, 0.5), 0x8a8478, 0x6a655c, 0.06, R), 0)

# 주춧돌 + 기둥(raised면 아래층 높은 기둥 그대로 위층까지)
static func _column(m: C.M, sp: Dictionary, ctx: Dictionary, x: float, z: float, bot: float, top: float, cr: float, raised: bool) -> void:
	var R := m.rng
	var part := "front" if z > 0.05 else "body"
	var ch := 0.12
	match String(sp.cho):
		"dumbeong":
			var s := Kit.lump(cr * 1.9, 0, R, 0.25, 0.45)
			m.add("base", "stone", C.P(Kit.xf(s, x, bot + 0.02, z), 0xaaa498, 0x847f75, 0.06, R), 0.012)
			ch = 0.1
		"dressed":
			m.add("base", "stone", C.P(Kit.box(cr * 3.6, 0.16, cr * 3.6, x, bot + 0.08, z), 0xbab4a7, 0x9a958a, 0.03, R), 0.012)
			ch = 0.16
		"round":
			m.add("base", "stone", C.P(Kit.cyl(cr * 1.8, cr * 2.0, 0.18, 10, x, bot + 0.09, z), 0xbab4a7, 0x9a958a, 0.03, R), 0.012)
			ch = 0.18
		_: ch = 0.0
	var y0 := bot + ch
	var hh := top - y0 + 0.1   # 기둥 머리는 창방 속으로(윗면이 벽 윗면·창방 밑면과 한 평면에 겹치지 않게)
	var colc: Array = ctx.col
	if String(sp.column) == "round":
		m.add(part, "wood", C.PA(Kit.cyl(cr * 0.94, cr, hh, 8, x, y0 + hh / 2, z), colc, 0.03, R), 0.018)
	else:
		m.add(part, "wood", C.PA(Kit.box(cr * 1.9, hh, cr * 1.9, x, y0 + hh / 2, z), colc, 0.03, R), 0.018)

# 단청 창방(뇌록 바탕 + 머리초) — 반복 칸으로
static func _dancheong_beam(m: C.M, part: String, L: float, h: float, z: float, y: float) -> void:
	var g := Kit.box(L, h, 0.2, 0, y, z)
	for i in g.uv.size():
		var p := g.pos[i]
		g.uv[i] = Vector2(p.x / 1.8 + 0.5, (y + h / 2 - p.y) / h) if absf(p.z - z) > 0.09 else Vector2(p.x / 1.8, 0.5)
	A.add_tiled(m, part, "dancheong", g, 0.02)

# ---------------------------------------------------------------------------------------------------
# 면 하나: 지금 프레임에서 (c.x, c.z)에 돌려(ry) 놓는다 — 로컬: 벽은 x 축(−w/2…w/2), 바깥 +z
static func _face(m: C.M, part: String, sp: Dictionary, ctx: Dictionary, c: Vector3, ry: float, w: float, y0: float, y1: float, f: Dictionary, b: Dictionary, lod: int) -> void:
	var kind: String = f.get("kind", "wall")
	if kind in ["join"]: return
	var old := m.push(c.x, 0, c.z, ry)
	var R := m.rng
	var cr: float = float(sp.col) / 2.0
	var xa := -w / 2 + cr * 0.9; var xb := w / 2 - cr * 0.9
	var t := 0.14
	var wallc: Array = ctx.wallc
	var wkey := "mud"
	if sp.wall == "board": wkey = "panbyeok"
	elif sp.wall == "stone": wkey = "stone"
	var lat: String = f.get("lattice", ctx.lattice)
	var hi: bool = ctx.hi
	var inner: bool = f.get("inner", false)
	var both: bool = inner or sp.interior
	var H := y1 - y0
	var op := []   # [ox0, ox1, oy0, oy1]
	match kind:
		"open", "rail":
			if kind == "rail":
				for k in 3: m.add(part, "wood", C.PA(Kit.box(w - 0.1, 0.09, 0.09, 0, y0 + 0.35 + k * 0.38, 0), ctx.wood, 0.03, R), 0.012)
			# 트인 칸 위 소벽(창방 아래 짧은 벽)
			if kind == "open" and not b.fn in ["maru", "shed", "mill", "forge", "stable"] and H > 2.0:
				pass
			m.pop(old); return
		"wall":
			op = []
		"board":
			A.add(m, part, "panbyeok", A.panel(xb - xa, H, 0, y0 + H / 2, t / 2 + 0.005), 0)
			m.add(part, "wood", C.PA(Kit.box(xb - xa, H, t, 0, y0 + H / 2, 0), [0x6a4e36, 0x4e3a28], 0.03, R), 0.02)
			if both: A.add(m, part, "panbyeok", A.panel(xb - xa, H, 0, y0 + H / 2, -t / 2 - 0.005, PI), 0)
			m.pop(old); return
		"window":
			var ww := minf(xb - xa - 0.3, 1.25 if hi else 1.0)
			var sill := 0.62 if (hi or sp.meoreum) else 0.8
			var wh := 1.05 if hi else 0.85
			op = [-ww / 2, ww / 2, y0 + sill, y0 + sill + wh]
		"smallwin":
			var ww := 0.5
			op = [-ww / 2 + (0.0 if w < 2.2 else -0.3), ww / 2 + (0.0 if w < 2.2 else -0.3), y0 + 1.05, y0 + 1.5]
		"salchang":
			op = [-0.45, 0.45, y0 + 1.35, y0 + 1.8]
		"door2":
			var dw := minf(xb - xa - 0.35, 1.5 if hi else 1.35)
			op = [-dw / 2, dw / 2, y0 + 0.05, y0 + minf(H - 0.35, 1.85 if hi else 1.7)]
		"door1":
			var dw := 0.74
			var off: float = 0.0 if inner else clampf(float(f.get("off", 0.0)), -(xb - xa) / 2 + 0.5, (xb - xa) / 2 - 0.5)
			op = [off - dw / 2, off + dw / 2, y0 + 0.05, y0 + minf(H - 0.3, 1.7)]
		"door4", "bunhap_up":
			op = [xa + 0.02, xb - 0.02, y0 + 0.05, y0 + H - (0.5 if H > 2.4 else 0.35)]
		"plank":
			op = [-0.45, 0.45, y0 + 0.03, y0 + minf(H - 0.3, 1.72)]
		"plank2":
			op = [-0.75, 0.75, y0 + 0.03, y0 + minf(H - 0.3, 1.8)]
		"gate":
			op = [xa + 0.05, xb - 0.05, y0, y0 + H - 0.3]
		"shop":
			op = [xa, xb, y0 + 0.0, y0 + H - 0.25]
	# 벽 채움(구멍 둘레) — 흙·회벽은 짜임(인방) 사이 채움
	var rects := []
	if op.is_empty():
		rects.append([xa, xb, y0, y1])
	else:
		if op[0] > xa + 0.02: rects.append([xa, op[0], y0, y1])
		if op[1] < xb - 0.02: rects.append([op[1], xb, y0, y1])
		if op[2] > y0 + 0.02: rects.append([op[0], op[1], y0, op[2]])
		if op[3] < y1 - 0.02: rects.append([op[0], op[1], op[3], y1])
	for r in rects:
		if r[1] - r[0] < 0.02 or r[3] - r[2] < 0.02: continue
		# 벽 채움: 위아래 0.4cm 물려(창방 밑면·바닥과 같은 평면에 겹치지 않게)
		var g := Kit.box(r[1] - r[0], r[3] - r[2] - 0.008, t, (r[0] + r[1]) / 2, (r[2] + r[3]) / 2, 0)
		if wkey == "panbyeok":
			m.add(part, "wood", C.PA(g, [0x6a4e36, 0x4e3a28], 0.03, R), 0.015)
			A.add(m, part, "panbyeok", A.panel(r[1] - r[0], r[3] - r[2], (r[0] + r[1]) / 2, (r[2] + r[3]) / 2, t / 2 + 0.004), 0)
		elif wkey == "stone":
			A.add_tiled(m, part, "rock", _uv_box(g, 1.2), 0.015)
			C.PA(g, wallc, 0.06, R)
		else:
			m.add(part, wkey, C.PA(g, wallc, 0.04, R), 0.015)
		if sp.interior and b.fn == "room" and not (wkey == "stone"):
			# 방 안 벽은 흰 도배
			m.add(part if part == "front" else "interior", "flat", C.P(Kit.box(r[1] - r[0], r[3] - r[2], 0.01, (r[0] + r[1]) / 2, (r[2] + r[3]) / 2, -t / 2 - 0.006), 0xf0e8d4, 0xe0d4ba, 0.02), 0)
	if lod > 0:
		m.pop(old); return
	# 짜임: 하인방 · 중방 · 상인방 · 문선(돌벽은 없음)
	var fw: Array = ctx.wood
	var frame: bool = sp.wall != "stone"
	# 가로재(인방)는 벽보다 0.5cm, 세로재(문선)는 1.5cm 나오고 기둥보다는 들어간다 — 같은 평면에 겹친 면이 없게(z-fighting)
	var fm := func(x0: float, x1: float, ya: float, yb: float, dep := 0.01) -> void:
		m.add(part, "wood", C.PA(Kit.box(x1 - x0, yb - ya, t + dep, (x0 + x1) / 2, (ya + yb) / 2, 0), fw, 0.03, R), 0.012)
	if frame:
		fm.call(xa, xb, y0, y0 + 0.11)                             # 하인방
		if op.is_empty() or op[2] > y0 + 0.5:
			var ym: float = y0 + minf(0.95, H * 0.45) if op.is_empty() else op[2]
			fm.call(xa, xb, ym - 0.05, ym + 0.05)                  # 중방 · 창 하방
		if not op.is_empty():
			fm.call(xa, xb, op[3], op[3] + 0.12)                   # 상인방
			# 문선: 구멍 안으로 1cm 물려(벽 끝면과 같은 평면에 겹치지 않게)
			if op[0] > xa + 0.05: fm.call(op[0] - 0.07, op[0] + 0.01, y0 + 0.1, op[3], 0.03)
			if op[1] < xb - 0.05: fm.call(op[1] - 0.01, op[1] + 0.07, y0 + 0.1, op[3], 0.03)
		elif H > 2.0:
			fm.call(xa, xb, y0 + H * 0.78, y0 + H * 0.78 + 0.09)   # 상인방(벽만)
		# 머름(창 밑 널 판)
		if kind == "window" and (hi or sp.meoreum):
			var mh: float = op[2] - y0 - 0.12
			m.add(part, "wood", C.PA(Kit.box(op[1] - op[0] + 0.16, mh, t + 0.06, 0, y0 + 0.11 + mh / 2, 0), [0x7a5a3c, 0x5e442e], 0.03, R), 0.012)
			for k in 3: m.add(part, "flat", C.P(Kit.box(0.04, mh - 0.06, 0.02, op[0] + (op[1] - op[0]) * (k + 1) / 4.0, y0 + 0.11 + mh / 2, t / 2 + 0.035), 0x4e3a28), 0)
	# 구멍 채우기
	if op.is_empty():
		m.pop(old); return
	var ow: float = op[1] - op[0]; var oh: float = op[3] - op[2]
	var ocx: float = (op[0] + op[1]) / 2; var ocy: float = (op[2] + op[3]) / 2
	match kind:
		"window", "smallwin", "door2", "door1", "door4", "bunhap_up":
			var n := 1
			if kind in ["window", "door2"]: n = 2
			elif kind in ["door4", "bunhap_up"]: n = 4 if ow > 2.0 else 3
			if kind == "smallwin": n = 1
			var lkey := lat
			if kind == "smallwin": lkey = "yong"
			var opened: bool = f.get("open", false)
			var trans := kind in ["door4", "bunhap_up"] and H - oh > 0.3
			var leaf_w := ow / n
			for k in n:
				var lx: float = op[0] + leaf_w * (k + 0.5)
				if kind == "bunhap_up":
					# 들어열개: 문짝을 들어 처마 밑 걸쇠에 건다(가로로 누움)
					var lg := A.panel(leaf_w - 0.04, oh - 0.04, 0, 0, 0)
					Kit.xf(lg, lx, op[3] - 0.08, 0.06 + (oh - 0.04) / 2, PI / 2 - 0.05, 0, 0)
					A.add(m, part, lkey, lg, 0)
					m.add(part, "wood", C.PA(Kit.xf(Kit.box(leaf_w - 0.02, 0.05, oh), lx, op[3] - 0.11, 0.06 + oh / 2, -0.05, 0, 0), fw, 0.03), 0.01)
					continue
				if opened and kind in ["door2", "door1"]:
					var side := -1.0 if lx < ocx or n == 1 else 1.0
					var hx: float = op[0] if side < 0 else op[1]
					var g := A.panel(leaf_w - 0.04, oh - 0.04, side * -(leaf_w / 2), 0, 0)
					Kit.xf(g, hx, ocy, t / 2 + 0.03, 0, side * -1.25, 0)
					A.add(m, part, lkey, g, 0)
					var g2 := A.panel(leaf_w - 0.04, oh - 0.04, side * -(leaf_w / 2), 0, 0, PI)
					Kit.xf(g2, hx, ocy, t / 2 + 0.03, 0, side * -1.25, 0)
					A.add(m, part, lkey, g2, 0)
					continue
				A.add(m, part, lkey, A.panel(leaf_w - 0.05, oh - 0.05, lx, ocy, 0.012), 0)
				if both: A.add(m, part, lkey, A.panel(leaf_w - 0.05, oh - 0.05, lx, ocy, -0.012, PI), 0)
				# 문울거미(테)
				var fr := 0.045
				m.add(part, "wood", C.PA(Kit.box(leaf_w, fr, 0.06, lx, op[3] - fr / 2, 0.01), fw), 0)
				m.add(part, "wood", C.PA(Kit.box(leaf_w, fr, 0.06, lx, op[2] + fr / 2, 0.01), fw), 0)
				m.add(part, "wood", C.PA(Kit.box(fr, oh, 0.06, lx - leaf_w / 2 + fr / 2, ocy, 0.01), fw), 0)
				if k == n - 1: m.add(part, "wood", C.PA(Kit.box(fr, oh, 0.06, lx + leaf_w / 2 - fr / 2, ocy, 0.01), fw), 0)
				if kind in ["door4"] and hi:
					# 궁창(문짝 아래 널)
					m.add(part, "wood", C.PA(Kit.box(leaf_w - 0.06, 0.32, 0.03, lx, op[2] + 0.2, 0.03), [0x6a4e36, 0x4e3a28]), 0)
			if trans:
				# 교창(문 위 가로 창)
				var ty0: float = op[3] + 0.12; var ty1: float = y1 - 0.08
				if ty1 - ty0 > 0.18:
					A.add(m, part, "yong", A.panel(ow - 0.1, ty1 - ty0, ocx, (ty0 + ty1) / 2, 0.012), 0)
		"salchang":
			m.add(part, "flat", C.P(Kit.box(ow, oh, 0.02, ocx, ocy, -0.05), 0x2a221b), 0)
			for k in 6: m.add(part, "wood", C.PA(Kit.box(0.04, oh, 0.05, op[0] + ow * (k + 0.5) / 6.0, ocy, 0.0), fw), 0)
		"plank", "plank2":
			var n := 1 if kind == "plank" else 2
			var opened: bool = f.get("open", false) or (b.fn == "kitchen" and m.r() < 0.35)
			for k in n:
				var lw := ow / n
				var lx: float = op[0] + lw * (k + 0.5)
				var g := A.panel(lw - 0.03, oh - 0.03, lx, ocy, 0.02)
				if opened and k == 0:
					g = A.panel(lw - 0.03, oh - 0.03, lw / 2, 0, 0)
					Kit.xf(g, op[0], ocy, t / 2 + 0.03, 0, -1.2, 0)
					m.add(part, "flat", C.P(Kit.box(ow, oh, 0.02, ocx, ocy, -0.3), 0x2a221b), 0)
				A.add(m, part, "panbyeok", C.P(g, 0xb8a080, 0x8a7458, 0.03), 0)
				if both and not opened: A.add(m, part, "panbyeok", A.panel(lw - 0.03, oh - 0.03, lx, ocy, -0.02, PI), 0)
			m.add(part, "flat", C.P(Kit.box(0.06, 0.06, 0.03, ocx + ow * 0.3, ocy, 0.04), 0x2a2420), 0)
		"gate":
			_gate_doors(m, part, sp, ctx, op, b, t)
		"shop":
			_shop_front(m, part, sp, ctx, op, b, w, y0, y1, t)
	m.pop(old)

# 박스 UV를 m 단위 반복으로(rect 모드) — 돌벽 등
static func _uv_box(g: Kit.Geo, period: float) -> Kit.Geo:
	for i in range(0, g.pos.size(), 3):
		var n := (g.pos[i + 1] - g.pos[i]).cross(g.pos[i + 2] - g.pos[i])
		for k in 3:
			var p := g.pos[i + k]
			if absf(n.x) > absf(n.z) and absf(n.x) > absf(n.y): g.uv[i + k] = Vector2(p.z / period, -p.y / period)
			elif absf(n.y) > absf(n.z): g.uv[i + k] = Vector2(p.x / period, p.z / period)
			else: g.uv[i + k] = Vector2(p.x / period, -p.y / period)
	return g

static func _gate_doors(m: C.M, part: String, sp: Dictionary, ctx: Dictionary, op: Array, b: Dictionary, t: float) -> void:
	var ow: float = op[1] - op[0]; var oh: float = op[3] - op[2]
	if b.front.get("passage", false): return
	var G := preload("res://kit/bldg/gate.gd")
	var cx: float = (op[0] + op[1]) / 2
	var old := m.push(cx, 0, 0)
	# 문지방(넘어서는 턱) · 문짝(안으로 열림) + 문고리·빗장 걸이·둔테 · 디딤돌(바깥·안) · 등 걸이
	G._sill(m, ow - 0.12)
	G._leaves(m, ow - 0.02, minf(oh - 0.2, 2.45), 0.18, true, 2)
	for zz in [0.62, -0.62]:
		m.add("p", "stone", C.P(Kit.box(minf(ow, 1.3), 0.13, 0.46, 0, 0.065, zz), 0xb8b2a5, 0x8e897f, 0.05, m.rng), 0.012)
		m.walk_floor(-minf(ow, 1.3) / 2, minf(ow, 1.3) / 2, zz - 0.23, zz + 0.23, 0.13)
	m.add("p", "flat", C.P(Kit.box(0.04, 0.04, 0.25, ow / 2 + 0.05, 2.3, 0.3), 0x2a2a2c), 0)
	m.add("p", "flat", C.P(Kit.box(0.03, 0.18, 0.03, ow / 2 + 0.05, 2.2, 0.41), 0x2a2a2c), 0)
	m.pop(old)

# 가게 앞: 판매대(마루) + 들창(위로 젖혀 받침대) + 차양(선택) + 물건
static func _shop_front(m: C.M, part: String, sp: Dictionary, ctx: Dictionary, op: Array, b: Dictionary, w: float, y0: float, y1: float, t: float) -> void:
	var R := m.rng
	var ow: float = op[1] - op[0]
	var cx: float = (op[0] + op[1]) / 2
	# 들창: 위 상인방에 걸린 널판을 바깥으로 젖혀 받침대로 괸다
	var dh := 1.0
	var g := A.panel(ow - 0.1, dh, 0, -dh / 2, 0)
	Kit.xf(g, cx, op[3] - 0.02, 0.08, -1.15, 0, 0)
	A.add(m, part, "panbyeok", C.P(g, 0xb8a080, 0x8a7458, 0.03), 0)
	var g2 := A.panel(ow - 0.1, dh, 0, -dh / 2, 0, PI)
	Kit.xf(g2, cx, op[3] - 0.02, 0.08, -1.15, 0, 0)
	A.add(m, part, "panbyeok", C.P(g2, 0x8a7458, 0x6a5840, 0.03), 0)
	var tip := Vector3(cx, op[3] - 0.02 - cos(1.15) * dh, 0.08 + sin(1.15) * dh)
	for sx in [-1.0, 1.0]:
		m.add(part, "wood", C.P(C.beam(Vector3(cx + sx * (ow / 2 - 0.3), y0 + 0.6, 0.35), tip + Vector3(sx * (ow / 2 - 0.3), 0, 0), 0.04, 0.04), 0x6b5038), 0)
	# 판매대
	m.add(part, "wood", C.PA(Kit.box(ow, 0.08, 0.7, cx, y0 + 0.02, 0.2), [0x8a6a48, 0x6a5038], 0.03, R), 0.015)
	var goods: String = b.get("goods", "mixed")
	var mapped := { silk = "cloth", paper = "straw", shoes = "straw", brass = "onggi" }
	var gk: String = mapped.get(goods, goods)
	var old := m.push(cx, 0, 0)
	if goods == "brass":
		for i in 5: m.add(part, "flat", C.P(Kit.cyl(0.13, 0.09, 0.08, 10, -ow / 2 + 0.35 + i * (ow - 0.7) / 4.0, y0 + 0.11, 0.25 + (i % 2) * 0.15), 0xc9a348, 0x9a7a30), 0)
	elif goods == "paper":
		for i in 4: m.add(part, "flat", C.P(Kit.box(0.5, 0.06 + i * 0.03, 0.4, -ow / 2 + 0.45 + i * (ow - 0.9) / 3.0, y0 + 0.1, 0.22), 0xf0ead8, 0xd8ccb0, 0.02), 0)
	else:
		MS.goods(m, gk, ow - 0.3, y0 + 0.06, 0.25)
	m.pop(old)
	# 차양(거적·이엉 차양을 장대로)
	if b.get("canopy", false):
		var cz := 1.5
		var gy := y1 - 0.25
		var cg := Kit.Geo.new()
		C.qf(cg, Vector3(cx - ow / 2, gy, 0.1), Vector3(cx + ow / 2, gy, 0.1), Vector3(cx + ow / 2, gy - 0.45, cz), Vector3(cx - ow / 2, gy - 0.45, cz), Vector3(0, 1, 0.3))
		A.add_tiled(m, part, "thatch", _uv_box(C.P(cg, 0xc8b88a, 0x9a8a62), 1.6), 0.015)
		for sx in [-1.0, 1.0]: m.add(part, "wood", C.P(Kit.cyl(0.035, 0.04, gy - 0.45, 5, cx + sx * (ow / 2 - 0.1), (gy - 0.45) / 2, cz), 0x6b5038), 0)

# ---------------------------------------------------------------------------------------------------
# 댓돌 · 돌계단 · 누각 나무 계단
static func _steps(m: C.M, sp: Dictionary, ctx: Dictionary, w: Dictionary, wi: int, bays: Array, xs: Array, floors: Array, zf: float, T: float, tk: String, Fb: float, Ff: float, mfront: float, raised: bool) -> void:
	var R := m.rng
	var zedge := zf + mfront   # 기단 앞 끝
	# 큰 계단: 기단이 한 걸음(0.32)보다 높으면 대청(없으면 가운데) 앞에
	var main_i := -1
	for i in bays.size():
		if bays[i].fn == "hall": main_i = i; break
	if main_i < 0:
		for i in bays.size():
			if bays[i].fn in ["room", "shrine", "maru"]: main_i = i; break
	if Fb > 0.33 and main_i >= 0 and sp.base.kind != "none":
		var cx: float = (xs[main_i] + xs[main_i + 1]) / 2
		var n := ceili(Fb / 0.24)
		var rise := Fb / n
		var sw := minf(1.8, float(bays[main_i].w) - 0.3)
		for k in n - 1:
			var top := rise * (k + 1)
			var zc := zedge + (n - 1 - k) * 0.32 - 0.16
			m.add("base", "stone", C.P(Kit.box(sw - 0.004 * k, top, 0.32, cx, top / 2, zc), 0xb8b2a5, 0x8e897f, 0.04, R), 0.02)
			m.walk_floor(cx - sw / 2, cx + sw / 2, zc - 0.17, zc + 0.17, top)
		if sp.cls in ["official", "yangban"]:
			for sx in [-1.0, 1.0]:
				m.add("base", "stone", C.P(Kit.box(0.16, Fb + 0.05, (n - 1) * 0.32 + 0.05, cx + sx * (sw / 2 + 0.086), (Fb + 0.05) / 2, zedge + (n - 1) * 0.16), 0xa8a294, 0x857f74, 0.03, R), 0.015)
		m.anchor("steps" if wi == 0 else "steps%d" % wi, Vector3(cx, 0, zedge + n * 0.32 + 0.6))
	# 댓돌: 마루·방 바닥이 기단보다 높으면 방문·대청 앞에
	if Ff - Fb > 0.12 and not raised:
		var zs := (zf + T + 0.2) if tk != "none" else zf + 0.2   # 툇마루 앞 끝에 붙여(틈 없이) 놓는다
		var done := {}
		for i in bays.size():
			var b: Dictionary = bays[i]
			if not (b.fn in ["room", "hall", "shrine"]) or b.front.kind == "join": continue
			if b.fn == "room" and not (b.front.kind in ["door2", "door1", "door4"]): continue
			var cx: float = (xs[i] + xs[i + 1]) / 2
			var hh := Fb + (Ff - Fb) * 0.5
			var s := Kit.box(0.74, hh - Fb + 0.06, 0.42, cx, Fb + (hh - Fb) / 2 - 0.03, zs)
			m.add("base", "stone", C.P(s, 0xbbb5a8, 0x918c81, 0.05, R), 0.015)
			m.walk_floor(cx - 0.37, cx + 0.37, zs - 0.22, zs + 0.21, hh)
	# 누각: 나무 계단(옆, 마루까지)
	if raised and sp.get("stair", false):
		var L: float = xs[xs.size() - 1] - xs[0]
		var n := ceili((Ff - Fb) / 0.24)
		var rise := (Ff - Fb) / n
		var run := 0.28
		var x0: float = L / 2 - 1.0
		for k in n - 1:
			var y := Fb + rise * (k + 1)
			var z := zf + 0.15 + (n - 1 - k) * run
			m.add("front", "wood", C.PA(Kit.box(1.0, 0.06, run + 0.02, x0, y - 0.03, z), C.WOOD_L), 0.01)
			m.walk_floor(x0 - 0.5, x0 + 0.5, z - run / 2, z + run / 2, y)
		for sx in [-1.0, 1.0]:
			m.add("front", "wood", C.P(C.beam(Vector3(x0 + sx * 0.52, Fb - 0.1, zf + 0.15 + n * run), Vector3(x0 + sx * 0.52, Ff - 0.05, zf), 0.07, 0.24), 0x5a4432), 0.012)
		m.anchor("stair_foot", Vector3(x0, 0, zf + n * run + 0.6))

# 누각 위층 마루: 바닥 판 + 귀틀 + 계자난간 + 걷기 면 + 난간 충돌
static func _raised_floor(m: C.M, sp: Dictionary, ctx: Dictionary, L: float, D: float, Ff: float, Fb: float, xs: Array, lod: int) -> void:
	var R := m.rng
	m.add("base", "wood", C.PA(Kit.box(L + 0.6, 0.2, D + 0.6, 0, Ff - 0.1, 0), [0x6a5038, 0x4d3826], 0.03, R), 0.02)
	A.add(m, "base", "maru", A.floor_quad(L + 0.56, D + 0.56, 0, Ff + 0.004, 0), 0)
	m.walk_floor(-L / 2 - 0.3, L / 2 + 0.3, -D / 2 - 0.3, D / 2 + 0.3, Ff + 0.004)
	_railing(m, L + 0.6, D + 0.6, Ff, sp.get("stair", false))

# 계자난간(닭다리 난간 대신 간단한 살대 + 돌란대)
static func _railing(m: C.M, W: float, Dd: float, y: float, gap: bool) -> void:
	var R := m.rng
	var h := 0.62
	for side in 4:
		var horiz := side < 2
		var len := W if horiz else Dd
		var zz: float = (Dd / 2 if side == 0 else -Dd / 2) if horiz else 0.0
		var xx: float = 0.0 if horiz else (W / 2 if side == 2 else -W / 2)
		var segs := [[-len / 2, len / 2]]
		if gap and side == 0: segs = [[-len / 2, len / 2 - 1.5], [len / 2 - 0.5, len / 2]]
		for s in segs:
			var a: float = s[0]; var b: float = s[1]
			if b - a < 0.1: continue
			var cx := (a + b) / 2; var l := b - a
			var g := Kit.box(l, 0.07, 0.07, cx, y + h, 0) if horiz else Kit.box(0.07, 0.07, l, 0, y + h, cx)
			Kit.xf(g, xx, 0, zz)
			m.add("front", "wood", C.PA(g, [0x7a3a2a, 0x5a2a1e]), 0.01)
			var g2 := Kit.box(l, 0.24, 0.04, cx, y + 0.2, 0) if horiz else Kit.box(0.04, 0.24, l, 0, y + 0.2, cx)
			Kit.xf(g2, xx, 0, zz)
			m.add("front", "wood", C.PA(g2, [0x7a5a3c, 0x5e442e]), 0)
			var n := int(l / 0.9)
			for k in (range(n + 1) if not horiz else range(1, n)):   # 모서리 기둥은 세로 변만 — 같은 자리 두 번 그리지 않게
				var p: float = a + l * float(k) / maxf(n, 1)
				var g3 := Kit.box(0.05, h, 0.05, p, y + h / 2, 0) if horiz else Kit.box(0.05, h, 0.05, 0, y + h / 2, p)
				Kit.xf(g3, xx, 0, zz)
				m.add("front", "wood", C.PA(g3, [0x7a3a2a, 0x5a2a1e]), 0)
			if horiz: m.box_c(a, b, zz - 0.05, zz + 0.05)
			else: m.box_c(xx - 0.05, xx + 0.05, a, b)

# ---------------------------------------------------------------------------------------------------
# 지붕: 날개 로컬 지붕 범위 → 지붕 함수
# 날개 지붕 틀(짓지 않고 값만): 벽 길이·깊이·높이 → 지붕 범위·가운데·반폭·높이
static func _roof_frame(sp: Dictionary, ctx: Dictionary, w: Dictionary) -> Dictionary:
	var L := 0.0
	for b in w.bays: L += float(b.w)
	var D := 0.0
	for d in w.depth: D += float(d)
	var tk: String = w.toet.kind; var T: float = float(w.toet.d) if tk != "none" else 0.0
	var Ff: float = float(ctx.Ff) + float(w.floor_up)
	var raised: bool = Ff - float(ctx.Fb) > 1.2
	var top: float = Ff + float(sp.wall_h) + (0.0 if raised else float(w.roof_up))
	var zcol: float = D / 2 + (T if tk == "toet" else 0.0)
	var rf: Dictionary = sp.roof
	var ov: float = float(rf.eave)
	var ends: Array = w.ends
	var ext: Array = w.get("ext", [0.0, 0.0])
	var kind: String = rf.kind
	var xa := -L / 2; var xb := L / 2
	var cw: Array = w.get("corner_w", [0.0, 0.0])
	for sd in [0, 1]:
		var f: String = ends[sd]
		var o2: float = (ov * 0.92 if f != "gable" else 0.6) if kind != "thatch" else ov * 0.9
		if kind == "neowa": o2 = 0.55
		if float(ext[sd]) > 0.0: o2 = 0.0   # 날개 용마루까지 늘린 끝: 늘린 길이만큼만(박공이 날개 지붕 너머로 나가지 않게)
		if f == "corner": o2 = float(cw[sd]) + ov   # 모퉁이: 날개 바깥 처마까지(정사각 회첨 구역)
		if (w.get("butt", [false, false]) as Array)[sd]: o2 = 0.08   # 더 높은 건물 벽에 맞대는 끝(객사 익헌 → 정청): 처마를 내밀지 않는다
		if sd == 0: xa -= o2 + float(ext[0])
		else: xb += o2 + float(ext[1])
	var za: float = -D / 2 - ov; var zb2 := zcol + ov
	var hd := (zb2 - za) / 2
	if w.get("joined", false):
		# ㄱ·ㄷ 날개: 뒤 끝을 몸채 앞 처마 줄에서 자른다(그 뒤는 몸채 모퉁이 지붕)
		var fm := _roof_frame(sp, ctx, sp.wings[0])
		var cut_z: float = float(fm.czr) + float(fm.hd)   # 몸채 지붕 앞 끝(건물 = 몸채 로컬)
		var sxw := -signf(sin(float(w.ry)))               # ry = -sx·π/2
		var lx: float = (cut_z - float(w.z)) * (1.0 if sxw > 0 else -1.0)
		if sxw > 0: xa = lx
		else: xb = lx
	return { L = L, D = D, top = top, zcol = zcol, xa = xa, xb = xb, za = za, zb2 = zb2, cxr = (xa + xb) / 2, czr = (za + zb2) / 2,
		hw = (xb - xa) / 2, hd = hd, rise = float(rf.rise_k) * hd, eave = top + 0.26 - float(w.get("lower", 0.0)), ends = ends, ext = ext }

# 이엉 처마 밑면·처마 띠를 다른 날개 방 위에서는 그리지 않는다(ㄱ자: 날개 처마 밑면이 몸채 방 안으로 들어가지 않게)
static func _hide_under(sp: Dictionary, ctx: Dictionary, w: Dictionary, cx: float, cz: float) -> Variant:
	if sp.wings.size() < 2: return null
	var rects := []
	for w2 in sp.wings:
		if w2 == w: continue
		var L := 0.0
		for b in w2.bays: L += float(b.w)
		var D := 0.0
		for d in w2.depth: D += float(d)
		rects.append([Transform3D(Basis(Vector3.UP, float(w2.ry)), Vector3(float(w2.x), 0, float(w2.z))).affine_inverse(), L / 2 + 0.2, D / 2 + 0.2])
	var mxf := Transform3D(Basis(Vector3.UP, float(w.ry)), Vector3(float(w.x), 0, float(w.z)))
	return func(x: float, z: float) -> bool:
		var pb := mxf * Vector3(x + cx, 0, z + cz)
		for r in rects:
			var q: Vector3 = (r[0] as Transform3D) * pb
			if absf(q.x) < float(r[1]) and absf(q.z) < float(r[2]): return true
		return false

# 몸채 지붕을 다른 날개 지붕 밑으로 묶는 clip(몸채 지붕 로컬 x, z → 넘지 말 높이)
static func _wing_clip(sp: Dictionary, ctx: Dictionary, w: Dictionary, fr: Dictionary, lod: int) -> Variant:
	if sp.roof.kind != "giwa": return null
	var ext: Array = w.get("ext", [0.0, 0.0])
	if float(ext[0]) <= 0.0 and float(ext[1]) <= 0.0: return null
	var others := []
	for w2 in sp.wings:
		if w2 == w: continue
		var f2 := _roof_frame(sp, ctx, w2)
		var o2 := { hw = f2.hw, hd = f2.hd, eave = f2.eave, rise = f2.rise, lift = float(sp.roof.lift), ends = f2.ends, hap = 0.45, lod = lod, sag = float(sp.wear) * 0.12 }
		var xf2 := Transform3D(Basis(Vector3.UP, float(w2.ry)), Vector3(float(w2.x), 0, float(w2.z)))
		others.append([o2, xf2.affine_inverse(), f2.cxr, f2.czr])
	var mxf := Transform3D(Basis(Vector3.UP, float(w.ry)), Vector3(float(w.x), 0, float(w.z)))
	var cx: float = fr.cxr; var cz: float = fr.czr
	return func(x: float, z: float) -> float:
		var pb := mxf * Vector3(x + cx, 0, z + cz)
		var best := INF
		for ot in others:
			var q: Vector3 = (ot[1] as Transform3D) * pb
			var lx: float = q.x - float(ot[2]); var lz: float = q.z - float(ot[3])
			var oo: Dictionary = ot[0]
			if absf(lx) <= float(oo.hw) and absf(lz) <= float(oo.hd):
				best = minf(best, RF.giwa_h(oo, lx, lz) - 0.04)
		return best

static func _roof(m: C.M, sp: Dictionary, ctx: Dictionary, w: Dictionary, lod: int, info: Dictionary, zcol: float) -> Rect2:
	var fr := _roof_frame(sp, ctx, w)
	var L: float = info.L; var D: float = info.D; var top: float = info.top
	var rf: Dictionary = sp.roof
	var ends: Array = w.ends
	var ext: Array = fr.ext
	var kind: String = rf.kind
	var xa: float = fr.xa; var xb: float = fr.xb; var za: float = fr.za; var zb2: float = fr.zb2
	var cxr: float = fr.cxr; var czr: float = fr.czr; var hw: float = fr.hw; var hd: float = fr.hd
	var rise: float = fr.rise
	var lowr: float = -float(w.get("lower", 0.0))
	var old := m.push(cxr, 0, czr)
	match kind:
		"giwa":
			var eave := top + 0.26 + lowr
			# 솟을대문 칸이 있으면 지붕을 그 칸에서 끊어 두 토막(대문 쪽 끝은 맞배) — 대문 지붕이 한 층 위에 따로 선다(겹친 판 아님)
			var gate := _soseul_span(w, info)
			var segs := [[xa, xb, ends[0], ends[1], ext]]
			if gate.size() == 2:
				segs = [[xa, gate[0], ends[0], "gable", [ext[0], 0.0]], [gate[1], xb, "gable", ends[1], [0.0, ext[1]]]]
			m.pop(old)
			for sg in segs:
				var sxa: float = sg[0]; var sxb: float = sg[1]; var se: Array = [sg[2], sg[3]]; var sext: Array = sg[4]
				var scx := (sxa + sxb) / 2; var shw := (sxb - sxa) / 2
				var o2 := m.push(scx, 0, czr)
				var clip = null
				if gate.size() != 2:
					var cf = _wing_clip(sp, ctx, w, fr, lod)
					if cf != null: clip = cf
				RF.giwa(m, "roof", { hw = shw, hd = hd, eave = eave, rise = rise, thick = 0.24, lift = float(rf.lift), ends = se, hap = 0.45, clip = clip,
					lift_ends = [0.0 if float(sext[0]) > 0.0 or (gate.size() == 2 and sxa == gate[1]) else 1.0, 0.0 if float(sext[1]) > 0.0 or (gate.size() == 2 and sxb == gate[0]) else 1.0],
					L = minf(L, sxb - sxa), wx0 = maxf(-L / 2, sxa) - scx, wx1 = minf(L / 2, sxb) - scx, D = info.zf - info.zb + (zcol - info.zf), lod = lod, buyeon = rf.get("buyeon", false), sag = float(sp.wear) * 0.12,
					rafter_col = ctx.col if ctx.paint != "none" else ctx.wood, c_top = 0x8f9296 if sp.wear < 0.5 else 0x878a84, c_low = 0x6d7176 })
				# 맞배 끝: 풍판(박공 아래 널) — 다른 지붕에 묻히는 끝·대문 쪽 끝은 없음
				if lod == 0:
					for sd in [-1.0, 1.0]:
						var i := 0 if sd < 0 else 1
						if se[i] != "gable" or float(sext[i]) > 0.0: continue
						if gate.size() == 2 and ((sd > 0 and sxb == gate[0]) or (sd < 0 and sxa == gate[1])): continue
						var xw: float = (-L / 2 if sd < 0 else L / 2)
						_pungpan(m, (xw - scx) + sd * 0.35, hd, eave, rise, top, sd, D, zcol, czr)
				m.pop(o2)
			old = m.push(cxr, 0, czr)
			info.roof_dims = { za = za, zb2 = zb2, hd = hd, rise = rise, eave = eave }
		"neowa":
			C.board_roof(m, "roof", hw * 2, hd * 2, top + 0.1 + lowr, rise * 1.1, "neowa", L, D, top, lod > 0)
		_:
			var eave := top + 0.3 + lowr   # 이엉 처마: 도리(벽 위 0.48m)를 덮을 만큼 — 낮은 지붕(제주)에서 도리가 이엉 밖으로 나오지 않게
			if ends[0] == "gable" and ends[1] == "gable":
				RF.thatch_gable(m, "roof", { hw = hw, hd = hd, eave = eave, rise = rise, lod = lod, L = L, D = D, cols = rf.get("cols", C.THATCH), wall_top = top + 0.2 })
			else:
				# 처마 둥근 모서리 반지름: 벽·기둥 모서리(+0.3m 여유)를 덮을 만큼만 — 크면 모서리 벽이 이엉 밖으로 나온다
				var oxv: float = float(rf.eave) * 0.9; var ozv: float = float(rf.eave)
				var rcv: float = float(rf.get("rc", 1.1))
				while rcv > 0.3 and pow(rcv - oxv, 2) + pow(rcv - ozv, 2) > pow(rcv - 0.32, 2): rcv -= 0.05
				var rr := RF.thatch(m, "roof", { hw = hw, hd = hd, eave = eave, rise = rise, rc = rcv, lod = lod, L = L, D = D,
					ov = minf(float(rf.eave), float(rf.eave) * 0.9), wall_top = top + 0.48, hide_under = _hide_under(sp, ctx, w, cxr, czr),
					cols = rf.get("cols", C.THATCH), net = int(rf.get("net", 0)), wear = sp.wear })
				info.thatch = { hw = hw, hd = hd, rc = float(rf.get("rc", 1.1)), eave = eave, rise = rise, cx = cxr, cz = czr }
	m.pop(old)
	return Rect2(xa, za, xb - xa, zb2 - za)

# 풍판: 맞배 박공 밑을 가리는 세로 널(지붕 밑면 아래, 처마 끝 안쪽)
static func _pungpan(m: C.M, x: float, hd: float, eave: float, rise: float, top: float, sd: float, D: float, zcol: float, czr: float) -> void:
	var g := Kit.Geo.new()
	var n := 8
	var z0 := -hd * 0.82; var z1 := hd * 0.82
	for k in n:
		var za := lerpf(z0, z1, float(k) / n); var zb := lerpf(z0, z1, float(k + 1) / n)
		var ya := eave + rise * RF.prof_giwa((hd - absf(za)) / hd) - 0.3
		var yb := eave + rise * RF.prof_giwa((hd - absf(zb)) / hd) - 0.3
		var lo := top + 0.45
		if ya < lo + 0.05 and yb < lo + 0.05: continue
		RF.tw(g, Vector3(x, lo, za), Vector3(x, lo, zb), Vector3(x, maxf(yb, lo), zb), Vector2(za / 2, 1), Vector2(zb / 2, 1), Vector2(zb / 2, 0), Vector3(sd, 0, 0))
		RF.tw(g, Vector3(x, lo, za), Vector3(x, maxf(yb, lo), zb), Vector3(x, maxf(ya, lo), za), Vector2(za / 2, 1), Vector2(zb / 2, 0), Vector2(za / 2, 0), Vector3(sd, 0, 0))
	for i in g.uv.size(): g.uv[i] = Vector2(g.pos[i].z / 2.0, -g.pos[i].y / 2.0)
	A.add_tiled(m, "roof", "panbyeok", C.P(g, 0x9a7a58, 0x7a5c40, 0.03), 0.012)

# ---------------------------------------------------------------------------------------------------
# 거친 단계(mid·far) 몸
static func _wing_coarse(m: C.M, sp: Dictionary, ctx: Dictionary, w: Dictionary, lod: int, info: Dictionary, bays: Array, xs: Array, floors: Array, top: float, zf: float, zb: float, zcol: float, T: float, tk: String, raised: bool) -> void:
	var R := m.rng
	var L: float = info.L; var D: float = info.D
	if raised:
		m.add("body", "wood", C.PA(Kit.box(L + 0.6, 0.25, D + 0.6, 0, info.Ff - 0.12, 0), [0x6a5038, 0x4d3826]), 0.0)
		if lod == 1:
			for x in xs:
				for z in [zb, zf]: m.add("body", "wood", C.PA(Kit.box(0.26, top, 0.26, x, top / 2, z), ctx.col), 0.0)
		return
	for i in bays.size():
		var b: Dictionary = bays[i]
		var x0: float = xs[i]; var x1: float = xs[i + 1]; var cx := (x0 + x1) / 2
		var y0: float = floors[i]
		var open: bool = _is_open(b) or b.fn == "gate"
		if open and lod == 1:
			m.add("body", "flat", C.P(Kit.box(x1 - x0, top - y0, 0.1, cx, (y0 + top) / 2, zb), 0x3e3128, 0x2c231c), 0)
			continue
		var wc: Array = ctx.wallc
		m.add("body", "mud" if sp.wall != "board" else "wood", C.PA(Kit.box(x1 - x0, top - y0, D, cx, (y0 + top) / 2, 0), wc, 0.04, R), 0.0)
		if lod == 1 and b.front.kind in ["door2", "door1", "window", "door4", "bunhap_up", "smallwin"]:
			var fh := 1.5 if b.front.kind != "smallwin" else 0.45
			var fw := minf(x1 - x0 - 0.4, 1.4) if b.front.kind != "smallwin" else 0.5
			A.add(m, "body", ctx.lattice if b.front.kind != "smallwin" else "yong", A.panel(fw, fh, cx, y0 + 0.2 + fh / 2 + (0.6 if b.front.kind == "window" else 0.0), zf + 0.01), 0)
		elif lod == 1 and b.front.kind in ["plank", "plank2"]:
			A.add(m, "body", "panbyeok", A.panel(0.9, 1.6, cx, y0 + 0.85, zf + 0.01), 0)
	if lod == 1:
		for x in xs: m.add("body", "wood", C.PA(Kit.box(0.22, top - ctx.Fb, 0.22, x, (top + ctx.Fb) / 2, zcol), ctx.col), 0.0)
		m.add("body", "wood", C.PA(Kit.box(L + 0.3, 0.24, 0.22, 0, top + 0.12, zcol), ctx.beam), 0.0)
		if tk != "none":
			m.add("body", "wood", C.PA(Kit.box(L, 0.1, T, 0, info.Ff - 0.05, zf + T / 2), [0x8a6a48, 0x6a5038]), 0.0)

# ---------------------------------------------------------------------------------------------------
# 굴뚝
static func _chimney(m: C.M, sp: Dictionary, ctx: Dictionary, info: Dictionary, lod: int) -> Vector3:
	var at: String = sp.chimney.get("at", "side_right")
	var L: float = info.L; var D: float = info.D
	var p := Vector3.ZERO
	match at:
		"back_left": p = Vector3(-L / 2 + 0.9, 0, -D / 2 - 0.85)
		"back_right": p = Vector3(L / 2 - 0.9, 0, -D / 2 - 0.85)
		"side_left": p = Vector3(-L / 2 - 0.6, 0, -D / 2 + 0.45)
		_: p = Vector3(L / 2 + 0.6, 0, -D / 2 + 0.45)
	var R := m.rng
	var kind: String = sp.chimney.kind
	var h := 1.6
	match kind:
		"log":
			h = info.top + 1.6
			m.add("chimney", "bark", C.P(Kit.cyl(0.2, 0.24, h, 7, p.x, h / 2, p.z), 0x6e5a46, 0x4a3b2e, 0.05, R), 0.025 if lod == 0 else 0.0)
			if lod == 0: m.add("chimney", "flat", C.P(Kit.cyl(0.16, 0.16, 0.02, 7, p.x, h, p.z), 0x1e1813), 0)
		"pot":
			h = 1.45
			m.add("chimney", "mud", C.P(Kit.box(0.5, 0.7, 0.5, p.x, 0.35, p.z), 0xa8906a, 0x7e6a4c, 0.05, R), 0.02 if lod == 0 else 0.0)
			if lod == 0:
				var g := C.onggi(0.24, 0.55, 10)
				Kit.xf(g, p.x, 1.3, p.z, PI, 0, 0)
				m.add("chimney", "onggi", C.PA(g, C.ONGGI, 0.04, R), 0.012)
				m.add("chimney", "onggi", C.PA(Kit.cyl(0.1, 0.12, 0.25, 8, p.x, 1.42, p.z), C.ONGGI), 0)
		"stone":
			h = info.top + 0.3
			m.add("chimney", "stone", C.P(Kit.box(0.62, h, 0.62, p.x, h / 2, p.z), 0x9a8a78, 0x7a6a5a, 0.05, R), 0.025 if lod == 0 else 0.0)
			if lod == 0:
				for k in int(h / 0.45): m.add("chimney", "flat", C.P(Kit.box(0.64, 0.03, 0.64, p.x, 0.3 + k * 0.45, p.z), 0xd8d0c0), 0)
				# 연가(작은 기와 지붕 모자)
				m.add("chimney", "flat", C.P(Kit.box(0.5, 0.25, 0.5, p.x, h + 0.12, p.z), 0x6a6a68, 0x4a4a48), 0.012)
				m.add("chimney", "flat", C.P(Kit.xf(Kit.cyl(0.0, 0.48, 0.3, 4, 0, 0, 0), p.x, h + 0.4, p.z, 0, PI / 4, 0), 0x3d3f42, 0x2d2e30), 0.015)
		_:
			h = 1.25   # 남부 낮은 흙 굴뚝(처마 밑)
			m.add("chimney", "mud", C.P(Kit.box(0.48, h, 0.48, p.x, h / 2, p.z), 0x9d8a6a, 0x6f6452, 0.06, R), 0.025 if lod == 0 else 0.0)
			if lod == 0:
				for k in 3:
					var s := Kit.lump(0.14, 0, R, 0.3, 0.6)
					m.add("chimney", "stone", C.P(Kit.xf(s, p.x + 0.24, 0.3 + k * 0.45, p.z + (m.r() - 0.5) * 0.3), 0xa8a294, 0x857f74, 0.05, R), 0)
				m.add("chimney", "flat", C.P(Kit.box(0.62, 0.08, 0.62, p.x, h + 0.02, p.z), 0x6f6452), 0.015)
	if lod == 0: m.circle(p.x, p.z, 0.4)
	return m.xform * Vector3(p.x, h + 0.2, p.z)

# ---------------------------------------------------------------------------------------------------
# 칸 속 살림
static func _furnish(m: C.M, sp: Dictionary, ctx: Dictionary, b: Dictionary, x0: float, x1: float, zb: float, zf: float, y: float, i: int, bays: Array, top: float) -> void:
	var part := "interior" if sp.interior else "body"
	var bw := x1 - x0; var cx := (x0 + x1) / 2
	var role: String = b.get("role", "")
	var hi: bool = ctx.hi
	var bz := zb + 0.42   # 뒷벽 앞
	match String(b.fn):
		"room":
			match role:
				"anbang":
					if hi:
						FU.ibuljang(m, part, x0 + 0.75, y, bz + 0.05, 0)
						FU.mungap(m, part, x1 - 0.95, y, bz - 0.05, 0)
						FU.byeongpung(m, part, cx + 0.2, y, zb + 0.95, 0, 5, 1.1)
						FU.boryo(m, part, cx + 0.2, y, zb + 1.5, 0)
					else:
						FU.bandaji(m, part, x0 + 0.65, y, bz, 0, 3)
						FU.sireong(m, part, cx, y, zb + 0.08, 0, bw - 0.6)
					FU.deungjan(m, part, x0 + 0.35, y, zf - 0.45)   # 등잔은 앞 구석(칸막이 문 길을 막지 않게)
					FU.soban(m, part, x1 - 0.55, y, zf - 0.55, 2)
				"sarang", "office":
					FU.seoan(m, part, cx, y, zb + 0.9, 0.0)
					FU.boryo(m, part, cx, y, zb + 0.55, 0)
					FU.sabang(m, part, x1 - 0.4, y, bz, 0)
					FU.mungap(m, part, x0 + 0.95, y, bz - 0.05, 0)
					FU.byeongpung(m, part, cx, y, zb + 0.18, 0, 6, 1.25)
					FU.deungjan(m, part, x0 + 0.35, y, zf - 0.5)
				"chaekbang":
					FU.sabang(m, part, x0 + 0.4, y, bz, 0)
					FU.sabang(m, part, x0 + 1.0, y, bz, 0)
					FU.seoan(m, part, cx + 0.3, y, 0.0, 0)
					FU.bangseok(m, part, cx + 0.3, y, -0.45)
				"bongno":
					FU.ibul_pile(m, part, x0 + 0.6, y, bz, 0, 4)
					FU.mokchim(m, part, x0 + 0.3, y, zf - 0.6, int(bw / 0.45))
					FU.soban(m, part, x1 - 0.6, y, zf - 0.6, 3, false)
					FU.deungjan(m, part, x1 - 0.35, y, bz)
				_:
					FU.bandaji(m, part, x0 + 0.65, y, bz, 0, 2 + int(m.r() * 2))
					if m.r() < 0.6: FU.sireong(m, part, cx, y, zb + 0.08, 0, bw - 0.6)
					FU.deungjan(m, part, x1 - 0.35, y, bz + 0.2)
					if m.r() < 0.5: FU.ibul_pile(m, part, x1 - 0.7, y, 0.2, PI / 2, 2)
		"hall":
			if role == "office" or role == "jeongcheong":
				FU.byeongpung(m, part, cx, y, zb + 0.2, 0, 8, 1.5)
				FU.gyoui(m, part, cx, y, zb + 0.7, 0)
			elif role == "gangdang" or role == "ikheon":
				FU.seoan(m, part, cx, y, zb + 0.8, 0)
			else:
				FU.dwiju(m, part, x0 + 0.6, y, bz, 0)
				if hi: FU.mungap(m, part, x1 - 0.95, y, bz - 0.05, 0)
				else: FU.dok(m, part, x1 - 0.4, y, bz, 0.8)
				if m.r() < 0.5: FU.soban(m, part, x1 - 0.5, y, zf - 0.6, 0)
		"shrine":
			if role == "buddha": FU.buddha(m, part, cx, y, zb + 1.2)
			elif role == "sindo" or bw > 2.5 or sp.type == "sadang": FU.jesang(m, part, cx, y, zb + 0.4, 0)
		"maru":
			if role == "sulcheong":
				FU.soban(m, part, x0 + 0.6, y, -0.2, 3)
				FU.soban(m, part, x1 - 0.6, y, -0.4, 2)
				FU.bangseok(m, part, cx - 0.4, y, 0.85)
		"kitchen":
			# 부뚜막은 방 쪽 칸막이를 따라(그 방 구들에 불을 넣는다)
			var right_room: bool = i + 1 < bays.size() and bays[i + 1].fn in ["room", "jeongju"]
			var left_room: bool = i > 0 and bays[i - 1].fn in ["room", "jeongju"]
			var sx := 1.0 if right_room or not left_room else -1.0
			var bl := minf(zf - zb - 0.4, 2.2)
			FU.buttumak(m, part, cx + sx * (bw / 2 - 0.45), y, (zb + zf) / 2 - 0.1, -sx * PI / 2, bl, 2 if bl > 1.6 else 1, role == "jumak")
			FU.salgang(m, part, cx - sx * 0.2, y, zb + 0.08, 0, minf(bw - 1.2, 1.4))
			FU.dok(m, part, cx - sx * (bw / 2 - 0.4), y, zb + 0.45, 0.95)
			var old := m.push(cx - sx * (bw / 2 - 0.5), y + 0.013, zf - 0.6, PI / 2)
			FW.row(m, 1.0, 3, false)
			m.pop(old)
			if role == "jumak":
				for k in 3: FU.dok(m, part, cx - sx * 0.3 + k * 0.5 * sx, y, zf - 0.45, 0.75 + k * 0.08)
		"shed":
			var old := m.push(cx, y, (zb + zf) / 2)
			PR.byeotdan(m)
			m.pop(old)
			var o2 := m.push(cx + bw * 0.25, y, zb + 0.6)
			PR.soguri(m, "grain")
			m.pop(o2)
		"stable":
			# 구유 + 깔짚
			m.add(part, "wood", C.P(Kit.box(bw - 0.6, 0.36, 0.45, cx, y + 0.18, zb + 0.4), 0x6b5038, 0x4d3826, 0.03), 0.012)
			m.add(part, "flat", C.P(Kit.box(bw - 0.6, 0.04, 0.3, cx, y + 0.35, zb + 0.4), 0x2a221b), 0)
			m.add(part, "thatch", C.PA(Kit.box(bw - 0.4, 0.06, (zf - zb) - 1.2, cx, y + 0.03, 0.3), C.STRAW, 0.06, m.rng), 0)
			m.anchor("cow", Vector3(cx, y, 0.2))
		"store":
			if sp.interior:
				for k in 3: FU.dok(m, part, x0 + 0.45 + k * 0.55, y, bz, 0.9)
		"mill":
			_mill_inside(m, part, cx, y, zb, zf, bw)
		"forge":
			_forge(m, part, cx, y, zb, zf, bw)

# 방앗간 안: 확(돌 절구) + 공이 달린 굴대(물레 쪽으로)
static func _mill_inside(m: C.M, part: String, cx: float, y: float, zb: float, zf: float, bw: float) -> void:
	for k in 2:
		var px := cx - 0.6 + k * 1.2
		m.add(part, "stone", C.P(Kit.cyl(0.38, 0.45, 0.5, 10, px, y + 0.25, -0.2), 0xa8a294, 0x857f74, 0.04), 0.015)
		m.add(part, "flat", C.P(Kit.cyl(0.24, 0.24, 0.02, 10, px, y + 0.5, -0.2), 0x3a3028), 0)
		# 방아 공이(세운 각재) + 가로 방아채
		m.add(part, "wood", C.PA(Kit.box(0.14, 1.3, 0.14, px, y + 1.15, -0.2), C.WOOD), 0.012)
		m.add(part, "wood", C.PA(Kit.box(0.16, 0.16, 2.0, px, y + 1.75, -0.5), C.WOOD), 0.012)
		m.circle(px, -0.2, 0.5)
	# 굴대(물레 축)
	m.add(part, "wood", C.P(Kit.cyl(0.13, 0.13, bw + 1.6, 8, cx + 0.5, y + 1.05, 0.6, 0, 0, PI / 2), 0x6b5038, 0x4d3826), 0.015)
	var old := m.push(cx - bw * 0.3, y, zb + 0.6)
	PR.soguri(m, "grain")
	m.pop(old)

# 대장간: 흙 화덕 + 풀무(상자) + 모루(통나무 위) + 물통 + 숯 더미 + 연장 걸이
static func _forge(m: C.M, part: String, cx: float, y: float, zb: float, zf: float, bw: float) -> void:
	var R := m.rng
	var fx := cx - bw * 0.2; var fz := zb + 0.75
	m.add(part, "mud", C.PA(Kit.box(1.3, 0.75, 1.0, fx, y + 0.375, fz), [0x9a7a58, 0x6a5038], 0.05, R), 0.02)
	m.add(part, "flat", C.P(Kit.box(0.6, 0.04, 0.5, fx, y + 0.76, fz + 0.1), 0x1e1814), 0)
	m.add(part, "glow", C.P(Kit.xf(Kit.lump(0.16, 0, R, 0.3, 0.5), fx, y + 0.8, fz + 0.1), 0xffb84a, 0xff6a20), 0)
	m.add(part, "mud", C.PA(Kit.box(0.5, 1.4, 0.5, fx, y + 1.45, fz - 0.2), [0x8a6a4a, 0x5a4430], 0.05, R), 0.015)   # 화덕 굴뚝(덮개)
	m.light(fx, y + 1.0, fz + 0.4, "torch")
	# 풀무
	m.add(part, "wood", C.PA(Kit.box(0.6, 0.5, 1.2, fx - 1.0, y + 0.25, fz), [0x7a5a3c, 0x5e442e], 0.03, R), 0.012)
	m.add(part, "wood", C.PA(Kit.box(0.05, 0.6, 0.05, fx - 1.0, y + 0.65, fz + 0.5), C.WOOD), 0)
	# 모루 + 통나무
	var ax := cx + bw * 0.2; var az := (zb + zf) / 2 + 0.2
	m.add(part, "bark", C.P(Kit.cyl(0.28, 0.3, 0.55, 8, ax, y + 0.275, az), 0x6e5a46, 0x4a3b2e, 0.05, R), 0.012)
	m.add(part, "flat", C.P(Kit.box(0.5, 0.18, 0.2, ax, y + 0.64, az), 0x3a3a3c, 0x2a2a2c), 0.01)
	m.add(part, "flat", C.P(Kit.xf(Kit.cyl(0.0, 0.1, 0.22, 4, 0, 0, 0), ax + 0.33, y + 0.66, az, 0, 0, PI / 2), 0x3a3a3c), 0)
	m.circle(ax, az, 0.35)
	# 물통 · 숯 더미
	m.add(part, "wood", C.P(Kit.cyl(0.3, 0.27, 0.45, 10, fx + 0.9, y + 0.225, fz + 0.4), 0x6b5038, 0x4d3826), 0.01)
	m.add(part, "flat", C.P(Kit.cyl(0.26, 0.26, 0.02, 10, fx + 0.9, y + 0.41, fz + 0.4), 0x4a5a5a), 0)
	m.add(part, "flat", C.P(Kit.xf(Kit.lump(0.45, 0, R, 0.3, 0.5), cx + bw * 0.35, y + 0.1, zb + 0.5), 0x2a2522, 0x1a1614), 0.01)
	# 연장 걸이(벽): 집게·망치
	for k in 4: m.add(part, "flat", C.P(Kit.box(0.05, 0.6, 0.03, cx - 0.2 + k * 0.22, y + 1.3, zb + 0.1), 0x3a3a3c), 0)
	m.anchor("smith", Vector3(ax, y, az + 0.6))

# ---------------------------------------------------------------------------------------------------
# 곁 것(attach) — 몸채 로컬(원점 기준)
static func _attachments(m: C.M, sp: Dictionary, ctx: Dictionary) -> void:
	var R := m.rng
	for a in sp.attach:
		var x: float = float(a.get("x", 0.0)); var z: float = float(a.get("z", 0.0)); var ry: float = float(a.get("ry", 0.0))
		match String(a.kind):
			"firewood":
				var old := m.push(x, 0, z, ry)
				FW.row(m, float(a.get("len", 2.0)), 4, false)
				m.pop(old)
				m.box_c(x - 0.4, x + 0.4, z - float(a.get("len", 2.0)) / 2, z + float(a.get("len", 2.0)) / 2)
			"jangdok_s":
				var n: int = int(a.get("n", 4))
				var w := 0.5 + n * 0.32
				m.add("p", "stone", C.P(Kit.box(w, 0.22, 1.1, x, 0.11, z), 0xb0aa9e, 0x827d73, 0.06, R), 0.02)
				for k in n:
					var rr := 0.17 + m.r() * 0.08
					JD.jar(m, "p", x - w / 2 + 0.35 + k * 0.32 + (m.r() - 0.5) * 0.06, 0.22, z + (0.2 if k % 2 == 0 else -0.2), rr, rr * 1.9)
				m.box_c(x - w / 2, x + w / 2, z - 0.55, z + 0.55)
			"pyeongsang":
				var old := m.push(x, 0, z, ry)
				PR.pyeongsang(m, float(a.get("w", 2.0)), 1.3, 0.45)
				if a.get("soban", false):
					FU.soban(m, "p", -0.3, 0.49, 0.0, 3)
				m.pop(old)
			"yongsu":
				var old := m.push(x, 0, z, ry)
				PR.yongsu(m, true)
				m.pop(old)
			"gamasot":
				var old := m.push(x, 0, z, ry)
				PR.gamasot(m, true)
				m.pop(old)
			"sul_dok":
				var n: int = int(a.get("n", 3))
				for k in n: FU.dok(m, "p", x + (k % 3) * 0.55 - 0.55, 0.0, z + (k / 3) * 0.55, 1.0 + m.r() * 0.3)
			"soguri":
				var old := m.push(x, 0, z, ry)
				PR.soguri(m, ["grain", "red", "veg"][int(m.r() * 3)])
				m.pop(old)
			"tools":
				var old := m.push(x, 0, z, ry)
				DP.tools(m)
				m.pop(old)
			"wheel":
				_wheel(m, x, z, float(a.get("r", 1.6)), a.get("overshot", true))
			"gourd":
				_gourds(m, sp)
			"dwiju":
				pass

# 물레바퀴(상사식: 홈통으로 위에서 물을 받음) + 홈통 + 굴대 받침
static func _wheel(m: C.M, x: float, z: float, r: float, overshot: bool) -> void:
	var R := m.rng
	var old := m.push(x, 0, z, PI / 2)
	var cy := r + 0.25
	var n := 16
	for side in [-0.32, 0.32]:
		var rim := C.torus(r, 0.06, 4, 20)
		Kit.xf(rim, 0, cy, side)
		m.add("p", "wood", C.PA(rim, [0x6b5038, 0x4d3826], 0.03, R), 0.012)
		for k in 6:
			var a := TAU * k / 6
			m.add("p", "wood", C.PA(C.beam(Vector3(0, cy, side), Vector3(cos(a) * r, cy + sin(a) * r, side), 0.07, 0.07), C.WOOD), 0)
	for k in n:
		var a := TAU * k / n
		var p := Vector3(cos(a) * (r - 0.12), cy + sin(a) * (r - 0.12), 0)
		m.add("p", "wood", C.PA(Kit.xf(Kit.box(0.26, 0.04, 0.7), p.x, p.y, 0, 0, 0, a + PI / 2), [0x8a6a48, 0x6a5038]), 0)
	m.add("p", "wood", C.P(Kit.cyl(0.11, 0.11, 1.4, 8, 0, cy, -0.3, PI / 2, 0, 0), 0x5a4432), 0.012)
	for sx in [-1.0, 1.0]:
		m.add("p", "stone", C.P(Kit.box(0.4, cy, 0.4, 0, cy / 2, sx * 0.62), 0xa8a294, 0x857f74, 0.05, R), 0.015)
	# 물길(바퀴 밑 도랑)
	m.add("p", "flat", C.P(Kit.box(6.0, 0.04, 1.0, 0, 0.02, 0), 0x6a7a78, 0x5a6866), 0)
	if overshot:
		# 홈통: 위에서 물을 떨어뜨린다
		var y := cy + r + 0.25
		m.add("p", "wood", C.PA(Kit.box(4.5, 0.18, 0.4, -2.6, y, 0), [0x7a5a3c, 0x5e442e], 0.03, R), 0.012)
		for k in 3: m.add("p", "wood", C.PA(Kit.box(0.1, y, 0.1, -1.4 - k * 1.4, y / 2, 0.25), C.WOOD), 0)
		m.add("p", "water", _water_strip(Vector3(-0.35, y - 0.05, 0), Vector3(0.2, cy + r - 0.1, 0), 0.32), 0)
	m.circle(0, 0, r * 0.7)
	m.pop(old)
	m.circle(x, z, 0.9)

static func _water_strip(a: Vector3, b: Vector3, w: float) -> Kit.Geo:
	var g := Kit.Geo.new()
	g.quad(a + Vector3(0, 0, -w / 2), a + Vector3(0, 0, w / 2), b + Vector3(0, 0, w / 2), b + Vector3(0, 0, -w / 2), Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1))
	g.quad(a + Vector3(0, 0, w / 2), a + Vector3(0, 0, -w / 2), b + Vector3(0, 0, -w / 2), b + Vector3(0, 0, w / 2), Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1))
	return g

# 박 넝쿨(초가 지붕 위)
static func _gourds(m: C.M, sp: Dictionary) -> void:
	var w: Dictionary = sp.wings[0]
	var L := 0.0
	for b in w.bays: L += float(b.w)
	var D := 0.0
	for d in w.depth: D += float(d)
	var rf: Dictionary = sp.roof
	var hd: float = D / 2 + float(rf.eave)
	var top: float = float(sp.base.h) + float(sp.floor_dh) + float(sp.wall_h)
	var eave := top + 0.3; var rise: float = float(rf.rise_k) * hd
	for q in [[-0.3, 0.45, 0.3], [0.12, 0.6, 0.36], [0.35, 0.25, 0.26]]:
		var px: float = q[0] * L / 2; var pz: float = q[1] * hd; var gs: float = q[2]
		var e := hd - absf(pz)
		var py := eave + rise * RF.prof_thatch(e / hd)
		m.add("roof", "organic", C.P(Kit.xf(C.sphere(gs, 8, 5), px, py + gs * 0.5, pz, 0, 0, 0, 1, 0.8, 1), 0xf1ecd6, 0xc9c9a0), 0.015)
		m.add("roof", "leaf", C.P(Kit.xf(Kit.lump(gs * 0.9, 0, m.rng, 0.2, 0.35), px + 0.3, py + 0.06, pz - 0.2), 0x7f9456, 0x56663a), 0.012)

# ---------------------------------------------------------------------------------------------------
# 짓지 않고 크기만: 처마 사각형(건물 로컬 Rect2 — x, z) — 묶음 배치·배치 로더 footprint용
static func bounds(sp: Dictionary) -> Rect2:
	var out := Rect2(); var first := true
	for w in sp.wings:
		var L := 0.0
		for b in w.bays: L += float(b.w)
		var D := 0.0
		for d in w.depth: D += float(d)
		var T: float = float(w.toet.d) if (w.toet.kind == "toet") else 0.0
		var ov: float = float(sp.roof.eave)
		var ext: Array = w.get("ext", [0.0, 0.0])
		var r := Rect2(-L / 2 - ov - float(ext[0]), -D / 2 - ov, L + 2 * ov + float(ext[0]) + float(ext[1]), D + T + 2 * ov)
		var xf := Transform3D(Basis(Vector3.UP, float(w.ry)), Vector3(float(w.x), 0, float(w.z)))
		var rr := _xf_rect(r, xf)
		if first: out = rr; first = false
		else: out = out.merge(rr)
	return out

static func footprint(params: Dictionary) -> Vector2:
	var b := bounds(S.resolve(params))
	return Vector2(maxf(absf(b.position.x), absf(b.end.x)) * 2.0 + 0.4, maxf(absf(b.position.y), absf(b.end.y)) * 2.0 + 0.4)

# ---------------------------------------------------------------------------------------------------
# 지붕 검사용(tools/bldg/roof_check.gd): 날개마다 따로 지은 지붕 조각(Geo, 건물 로컬) — [{ wing, geo, walls }]
#   walls: 벽·기둥·창방·도리(앞·몸 부분 — 굴뚝·곁 것·기단·실내 제외)
static func roof_geos(sp: Dictionary) -> Array:
	sp = S.normalize(sp)
	var ctx := _ctx(sp)
	var out := []
	var wi := 0
	for w in sp.wings:
		var m := C.M.new(int(sp.seed) * 31 + 7, false)
		var old := m.push(float(w.x), 0, float(w.z), float(w.ry))
		_wing(m, sp, ctx, w, 0, wi)
		m.pop(old)
		var b = m.parts.get("roof")
		var wl := []
		for p in ["body", "front"]:
			if m.parts.has(p): wl.append_array(m.parts[p].parts.get("atlas", []))
		if b != null: out.append({ wing = String(w.id), geo = Kit.merge(b.parts.get("atlas", [])), walls = Kit.merge(wl), top = _roof_frame(sp, ctx, w).top })
		wi += 1
	return out
