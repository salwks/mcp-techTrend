# 집 한 채(집 묶음 프리셋) — 안채·사랑채·헛간 등을 마당 둘레로 묶고 담·문을 두른다. 마당 가운데가 원점, 대문이 +z(남).
# size:
#   "small"  초가 3칸 안채 + 헛간 + 뒷간 + 작은 장독대 + 장작 + 싸리울 + 사립문            (가난한 소작농·산간 화전민 집)
#   "medium" 초가 안채(넓게) + 초가 사랑채 + 외양간 + 헛간 + 장독대 + 뒷간 + 이엉 토담 + 초가 대문  (자작농·중농)
#   "large"  기와 안채 + 기와 사랑채 + 곳간(헛간) + 장독대 + 뒷간 + 기와 토담 + 솟을대문       (향반·이서층 기와집, 남원 읍내)
# 고증: 남부 민가는 一자형 안채가 남향하고, 사랑채·헛간·외양간이 마당 둘레에 따로 선다(트인 ㅁ자·튼 ㄷ자). 장독대는 부엌(안채
#   오른쪽) 뒤편, 뒷간은 마당 구석·대문 가까이. 기와 안채에 단청은 쓰지 않는다(plain) — 단청은 관아·사찰·정자.
#
# 세 가지로 쓴다:
#   build(params)            건물별 자식 노드를 가진 한 덩이 + pieces(계약서 §4: kit, params, x, z, ry, tag, xform)
#   layout(params)           배치 로더용 조각 목록(§8) — 로더가 건물마다 따로 지어 가림·스트리밍을 건물 단위로 처리
#                            (lod=1 또는 merged=true면 자기 자신 한 조각 = 한 덩이)
#   params.lod = 1           먼 읍내용 가벼운 한 덩이(≤ 4,000 삼각형: 몸체 상자 + 창호 띠 + 지붕, 소품 생략)
# 성능: 한 덩이(lod 0)는 '큰 건물' 예산 ≤ 15,000. 조각 하나하나는 각 모델 예산 안.
# params: seed, size("small"|"medium"|"large"), lod(0|1), merged(false)
extends RefCounted
const C := preload("res://kit/village/_common.gd")

const E := -PI / 2   # 서쪽을 보게(오른쪽 건물)
const Wf := PI / 2   # 동쪽을 보게(왼쪽 건물)

# 마당 크기: [X(반폭), Z0(북), Z1(남, 대문 줄)]
const YARD := { small = [7.0, -6.5, 6.5], medium = [9.6, -8.2, 7.6], large = [12.0, -10.0, 9.2] }

static func footprint(params: Dictionary) -> Vector2:
	var y: Array = YARD.get(params.get("size", "small"), YARD.small)
	var extra := 2.6 if params.get("size", "small") == "large" else 1.0
	return Vector2(y[0] * 2 + 0.8, y[2] - y[1] + extra)

static func layout(params: Dictionary) -> Array:
	if int(params.get("lod", 0)) == 1 or params.get("merged", false):
		var p := params.duplicate(); p.merged = true
		return [{ kit = "village/house_compound", params = p, x = 0.0, z = 0.0, ry = 0.0, tag = "all" }]
	return entries(params)

static func build(params: Dictionary) -> Dictionary:
	var size: String = params.get("size", "small")
	var fp := footprint(params)
	var res: Dictionary
	if int(params.get("lod", 0)) == 1:
		var m := C.M.new(int(params.get("seed", 1)))
		for e in entries(params): lod_draw(m, e)
		res = m.result("집_%s_lod" % size, fp)
	else:
		res = compose(entries(params), "집_" + size, fp)
		if not params.get("merged", false):
			var ps := []
			for e in entries(params):
				var q: Dictionary = e.duplicate()
				q.xform = Transform3D(Basis(Vector3.UP, e.ry), Vector3(e.x, 0, e.z))
				ps.append(q)
			res.pieces = ps
	var Y: Array = YARD.get(size, YARD.small)
	res.yard = { minX = -Y[0] + 1.0, maxX = Y[0] - 1.0, minZ = Y[1] + 1.0, maxZ = Y[2] - 1.0 }
	return res

# ---------------------------------------------------------------------------
# 조각 목록: { tag, kit, params, x, z, ry } — kit은 kit/ 아래 경로(확장자 없이)
# ---------------------------------------------------------------------------
static func entries(params: Dictionary) -> Array:
	var r := Kit.Rng.new(int(params.get("seed", 1)))
	var size: String = params.get("size", "small")
	var Y: Array = YARD.get(size, YARD.small)
	var X: float = Y[0]; var Z0: float = Y[1]; var Z1: float = Y[2]
	var L := []
	var s0 := int(params.get("seed", 1)) * 10
	match size:
		"medium":
			L.append(_e("anchae", "choga", { seed = s0 + 1, w = 7.2, d = 4.4, hump = snappedf((r.next() - 0.5) * 0.3, 0.01), gourd = r.next() < 0.5 }, 0, -3.8, 0))
			L.append(_e("sarang", "choga", { seed = s0 + 2, w = 5.4, d = 3.6, hump = snappedf((r.next() - 0.5) * 0.3, 0.01) }, -6.3, 1.8, Wf))
			L.append(_e("oeyang", "oeyanggan", { seed = s0 + 3, w = 3.4, d = 2.8 }, 7.0, 3.6, E))
			L.append(_e("heotgan", "heotgan", { seed = s0 + 4, w = 3.4, d = 2.6, walls = "three" }, 7.0, -1.4, E))
			L.append(_e("jangdok", "jangdok", { seed = s0 + 5, w = 3.0, d = 2.0 }, 5.9, -6.6, 0))
			L.append(_e("dwitgan", "dwitgan", { seed = s0 + 6, s = 1.4 }, -8.3, -6.8, Wf))
			L.append(_e("firewood", "firewood", { seed = s0 + 7, style = "row", len = 2.4, rows = 4 }, -4.9, -4.5, Wf))
			_enclose(L, s0 + 20, -X, X, Z0, Z1, 1.25, "todam_thatch")
			L.append(_e("gate", "daemun", { seed = s0 + 8, style = "thatch", open = true, lantern = false }, 0, Z1, 0))
		"large":
			L.append(_e("anchae", "giwa", { seed = s0 + 1, w = 9.0, d = 5.4, plain = true, roof_nx = 18, roof_nz = 9 }, 0, -4.9, 0))
			L.append(_e("sarang", "giwa", { seed = s0 + 2, w = 6.6, d = 4.2, bays = 3, plain = true, roof_nx = 14, roof_nz = 7 }, -7.4, 2.6, Wf))
			L.append(_e("gotgan", "heotgan", { seed = s0 + 3, w = 4.4, d = 2.8, walls = "three" }, 8.6, 1.8, E))
			L.append(_e("jangdok", "jangdok", { seed = s0 + 4, w = 3.0, d = 2.2, n = [3, 2, 1] }, 7.4, -7.4, 0))
			L.append(_e("dwitgan", "dwitgan", { seed = s0 + 5, s = 1.5 }, 10.6, 7.4, E))
			_enclose(L, s0 + 20, -X, X, Z0, Z1, 3.3, "todam_tile")
			L.append(_e("gate", "daemun", { seed = s0 + 8, style = "soseul", open = true, lantern = true }, 0, Z1 + 0.6, 0))
		_:
			L.append(_e("anchae", "choga", { seed = s0 + 1, w = 6.0, d = 4.0, hump = snappedf((r.next() - 0.5) * 0.3, 0.01), gourd = r.next() < 0.5 }, 0, -2.6, 0))
			L.append(_e("heotgan", "heotgan", { seed = s0 + 2, w = 3.2, d = 2.4, walls = "three" }, 5.2, 1.6, E))
			L.append(_e("dwitgan", "dwitgan", { seed = s0 + 3, s = 1.4 }, -5.6, 4.9, Wf))
			L.append(_e("jangdok", "jangdok", { seed = s0 + 4, w = 2.4, d = 1.8, n = [2, 2, 1] }, 4.6, -4.7, 0))
			L.append(_e("firewood", "firewood", { seed = s0 + 5, style = "row", len = 2.4, rows = 4 }, -4.7, -2.8, Wf))
			_enclose(L, s0 + 20, -X, X, Z0, Z1, 0.75, "fence")
			L.append(_e("gate", "saripmun", { seed = s0 + 8, w = 1.4, open = true }, 0, Z1, 0))
	return L

static func _e(tag: String, kit: String, p: Dictionary, x: float, z: float, ry: float) -> Dictionary:
	return { tag = tag, kit = "village/" + kit, params = p, x = x, z = z, ry = ry }

# 둘레 담 조각: 점이 마당 로컬 좌표(조각 자리는 원점)
static func _enclose(L: Array, seed: int, x0: float, x1: float, z0: float, z1: float, gh: float, kind: String) -> void:
	var segs := [["wall_n", x0, z0, x1, z0], ["wall_w", x0, z0, x0, z1], ["wall_e", x1, z0, x1, z1], ["wall_sw", x0, z1, -gh, z1], ["wall_se", gh, z1, x1, z1]]
	var i := 0
	for s in segs:
		var p := { seed = seed + i, ax = s[1], az = s[2], bx = s[3], bz = s[4] }
		match kind:
			"fence": p.lite = true; L.append(_e(s[0], "fence", p, 0, 0, 0))
			"todam_thatch": p.h = 1.5; p.cap = "thatch"; L.append(_e(s[0], "todam", p, 0, 0, 0))
			"todam_tile": p.h = 1.6; p.cap = "tile"; p.tile_seg = 0.5; L.append(_e(s[0], "todam", p, 0, 0, 0))
		i += 1

# 조각마다 지어 자식 노드로 묶음(충돌체·조명·앵커는 묶음 로컬로 옮김, 앵커 이름 앞에 tag_)
static func compose(list: Array, name: String, fp: Vector2) -> Dictionary:
	var root := Node3D.new(); root.name = name
	var cols := []; var lights := []; var anchors := {}
	for e in list:
		var info: Dictionary = load("res://kit/%s.gd" % e.kit).build(e.params)
		var t := Transform3D(Basis(Vector3.UP, e.ry), Vector3(e.x, 0, e.z))
		var n: Node3D = info.node
		n.name = e.tag; n.transform = t
		root.add_child(n)
		for c in info.get("colliders", []):
			if c.type == "circle":
				var p := t * Vector3(c.x, 0, c.z)
				cols.append({ type = "circle", x = p.x, z = p.z, r = c.r })
			else:
				var a := t * Vector3(c.minX, 0, c.minZ); var b := t * Vector3(c.maxX, 0, c.maxZ)
				var cc := t * Vector3(c.minX, 0, c.maxZ); var d := t * Vector3(c.maxX, 0, c.minZ)
				cols.append({ type = "box", minX = minf(minf(a.x, b.x), minf(cc.x, d.x)), maxX = maxf(maxf(a.x, b.x), maxf(cc.x, d.x)),
					minZ = minf(minf(a.z, b.z), minf(cc.z, d.z)), maxZ = maxf(maxf(a.z, b.z), maxf(cc.z, d.z)) })
		for l in info.get("lights", []):
			var p := t * Vector3(l.x, l.y, l.z)
			lights.append({ x = p.x, y = p.y, z = p.z, kind = l.kind })
		var an: Dictionary = info.get("anchors", {})
		for k in an: anchors["%s_%s" % [e.tag, k]] = t * (an[k] as Vector3)
	return { node = root, colliders = cols, lights = lights, occluder = true, footprint = fp, anchors = anchors }

# ---------------------------------------------------------------------------
# LOD: 같은 자리에 아주 단순한 몸체·지붕만(먹선은 지붕만)
# ---------------------------------------------------------------------------
static func lod_draw(m: C.M, e: Dictionary) -> void:
	var p: Dictionary = e.params
	var old := m.push(e.x, 0, e.z, e.ry)
	var R := m.rng
	match e.kit:
		"village/choga":
			var W: float = p.get("w", 6.0); var D: float = p.get("d", 4.0)
			m.add("p", "stone", C.PA(Kit.box(W + 0.9, 0.4, D + 0.9, 0, 0.2, 0), C.STONE, 0.05, R), 0.02)
			m.add("p", "mud", C.PA(Kit.box(W, 1.85, D, 0, 1.32, 0), C.MUD, 0.04, R), 0.02)
			m.add("p", "paper", C.vplane(W * 0.55, 1.1, -W * 0.08, 1.25, D / 2 + 0.01), 0)
			m.add("p", "wood", C.PA(Kit.box(W * 0.5, 0.08, 0.6, 0, 0.38, D / 2 + 0.4), C.WOOD_L), 0)
			C.thatch_cap(m, "p", W / 2 + 0.75, D / 2 + 0.8, 2.37, 1.35 + float(p.get("hump", 0.0)), 10, 3)
			m.light(-W / 3, 1.55, D / 2 + 0.2, "window")
			m.box_c(-W / 2 - 0.45, W / 2 + 0.45, -D / 2 - 0.45, D / 2 + 0.75)
		"village/giwa":
			var W: float = p.get("w", 9.0); var D: float = p.get("d", 5.4)
			m.add("p", "stone", C.P(Kit.box(W + 1.2, 0.85, D + 1.2, 0, 0.32, 0), 0xaaa498, 0x7b766c, 0.05, R), 0.02)
			m.add("p", "mud", C.PA(Kit.box(W, 2.3, D, 0, 1.9, 0), C.PLASTER, 0.03, R), 0.02)
			m.add("p", "paper", C.vplane(W * 0.7, 1.4, 0, 1.95, D / 2 + 0.01), 0)
			m.add("p", "wood", C.PA(Kit.box(W + 0.4, 0.26, 0.3, 0, 3.15, D / 2), C.WOOD), 0)
			var r := C.curved_roof(W / 2 + 1.7, D / 2 + 1.55, 3.6, 2.4, 0.6, 1.9, 0.26, 10, 5)
			m.add("p", "tile", r.roof, 0.05)
			m.add("p", "makse", r.edge, 0)
			m.add("p", "flat", C.P(Kit.box(r.ridge_half * 2 + 0.4, 0.3, 0.36, 0, r.ridge_y + 0.08, 0), C.ROOF_DARK), 0)
			m.light(0, 1.9, D / 2 + 0.2, "window")
			m.box_c(-W / 2 - 0.6, W / 2 + 0.6, -D / 2 - 0.6, D / 2 + 1.45)
		"village/heotgan", "village/oeyanggan":
			var W: float = p.get("w", 4.0); var D: float = p.get("d", 2.8)
			m.add("p", "mud", C.PA(Kit.box(W, 1.9, D, 0, 1.13, -0.1), C.MUD, 0.04, R), 0.02)
			m.add("p", "flat", C.P(Kit.box(W - 0.3, 1.7, 0.03, 0, 1.03, D / 2 - 0.08), 0x4a3c2e, 0x2e251c), 0)
			C.thatch_gable(m, "p", W + 0.9, D + 1.1, 2.2, 0.9)
			m.box_c(-W / 2 - 0.2, W / 2 + 0.2, -D / 2 - 0.2, D / 2 - 0.4)
		"village/dwitgan":
			var s: float = p.get("s", 1.5)
			m.add("p", "mud", C.PA(Kit.box(s, 1.75, s, 0, 1.07, 0), C.MUD, 0.04, R), 0.02)
			C.thatch_cap(m, "p", s / 2 + 0.45, s / 2 + 0.45, 2.05, 0.55, 8, 2)
			m.box_c(-s / 2, s / 2, -s / 2, s / 2)
		"village/jangdok":
			var w: float = p.get("w", 3.0); var d: float = p.get("d", 2.0)
			m.add("p", "stone", C.P(Kit.box(w, 0.4, d, 0, 0.15, 0), 0xb0aa9e, 0x827d73, 0.06, R), 0)
			for i in 3: m.add("p", "onggi", C.PA(Kit.cyl(0.25, 0.35, 0.7, 6, -w / 3 + i * w / 3, 0.7, 0), C.ONGGI, 0.05, R), 0)
			m.box_c(-w / 2, w / 2, -d / 2, d / 2)
		"village/firewood":
			var Lw: float = p.get("len", 2.4)
			m.add("p", "wood", C.P(Kit.box(Lw, 0.75, 0.9, 0, 0.38, 0), 0xa88a62, 0x7a5c3e, 0.05, R), 0)
		"village/todam":
			_lod_wall(m, p, "todam")
		"village/fence":
			_lod_wall(m, p, "fence")
		"village/daemun":
			for s in [-1, 1]: m.add("p", "wood", C.PA(Kit.box(0.22, 2.4, 0.22, s * 1.0, 1.2, 0), C.WOOD), 0)
			if p.get("style", "tile") == "thatch": C.thatch_cap(m, "p", 1.6, 0.95, 2.15, 0.6, 8, 2)
			else:
				var r := C.curved_roof(1.75, 1.0, 2.6, 0.8, 0.28, 2.6, 0.16, 6, 2)
				m.add("p", "tile", r.roof, 0.035); m.add("p", "makse", r.edge, 0)
				if p.get("style", "tile") == "soseul":
					for s in [-1, 1]:
						m.add("p", "mud", C.PA(Kit.box(2.0, 2.0, 2.0, s * 2.3, 1.0, -0.6), C.PLASTER, 0.03, R), 0.02)
						var r2 := C.curved_roof(1.35, 1.45, 2.2, 0.7, 0.2, 1.6, 0.16, 4, 4)
						Kit.xf(r2.roof, s * 2.3, 0, -0.6); Kit.xf(r2.edge, s * 2.3, 0, -0.6)
						m.add("p", "tile", r2.roof, 0.035); m.add("p", "makse", r2.edge, 0)
						m.box_c(s * 2.3 - 1.1, s * 2.3 + 1.1, -1.7, 0.5)
			for s in [-1, 1]: m.circle(s * 1.0, 0, 0.22)
		"village/saripmun":
			var w: float = p.get("w", 1.4)
			for s in [-1, 1]: m.add("p", "wood", C.P(Kit.box(0.12, 1.55, 0.12, s * w / 2, 0.77, 0), 0x6b5038), 0)
			for s in [-1, 1]: m.circle(s * w / 2, 0, 0.12)
	m.pop(old)

static func _lod_wall(m: C.M, p: Dictionary, kind: String) -> void:
	var ax: float = p.ax; var az: float = p.az; var bx: float = p.bx; var bz: float = p.bz
	var len := Vector2(bx - ax, bz - az).length()
	var old := m.xform
	m.xform = old * C.seg_xform(ax, az, bx, bz)
	if kind == "fence":
		m.add("p", "flat", C.P(Kit.box(len, 1.1, 0.06, 0, 0.55, 0), 0x9c8462, 0x6e5a44, 0.06, m.rng), 0)
	else:
		var h: float = p.get("h", 1.5)
		m.add("p", "mud", C.P(Kit.box(len, h, 0.45, 0, h / 2, 0), 0xc9b08a, 0xa08866, 0.04, m.rng), 0.02)
		var g := Kit.Geo.new()
		var cw := 0.45; var rh := 0.32
		for s in [-1, 1]:
			var a := Vector3(-len / 2 - 0.1, h, s * cw); var b := Vector3(len / 2 + 0.1, h, s * cw)
			var c := Vector3(len / 2 + 0.1, h + rh, 0); var d := Vector3(-len / 2 - 0.1, h + rh, 0)
			if s > 0: g.quad(a, b, c, d)
			else: g.quad(b, a, d, c)
		if p.get("cap", "thatch") == "tile": m.add("p", "flat", C.P(g, 0x6a6c6e, 0x55575a), 0.02)
		else: m.add("p", "thatch", C.PA(g, C.THATCH, 0.05, m.rng), 0.02)
	m.xform = old
	preload("res://kit/village/stone_wall.gd").add_line_collider(m, ax, az, bx, bz, 0.3 if kind != "fence" else 0.12)
