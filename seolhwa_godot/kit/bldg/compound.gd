# 건물 빌더 묶음(집 한 채 = 마당 둘레 건물 여럿 + 담·문 + 마당 것) — 마당 가운데가 원점, 대문이 +z(남).
#   params: { type: "choga_house"|"jungnong"|"giwa_house"|"yangban"|"jumak_yard", region, cls, seed, lot?: [w, d] }
#     lot: 필지 크기(m) — 담·마당을 그 안으로 줄인다(건물은 줄이지 않는다. 안 들면 고을 틀이 다른 시드를 고른다)
#   layout(params) → 배치 로더 조각 목록(건물마다 bldg/building으로 따로 지어 가림·스트리밍·LOD가 건물 단위)
#   build(params)  → 한 덩이(미리보기·갤러리) + pieces + yard
# 배치(고증 요지 — docs/reports/building-reference-map.md):
#   서민 초가: 안채가 마당 뒤에 남향, 헛간·뒷간이 마당 둘레, 싸리울(제주 돌담·올레, 산간 돌담) + 사립문, 텃밭
#   중농: 안채 + 아래채(사랑방·외양간·헛간)가 마당을 사이에 두고 마주보거나 ㄱ으로, 토담(이엉 갓) + 초가 대문
#   양반가: 행랑채(솟을대문) → 사랑마당·사랑채 → 중문 담 → 안마당·안채(ㄱ·ㄷ) → 뒤뜰 사당·장독대, 기와 토담
extends RefCounted
const S := preload("res://kit/bldg/_spec.gd")
const B := preload("res://kit/bldg/building.gd")
const HC := preload("res://kit/village/house_compound.gd")
const GT := preload("res://kit/bldg/gate.gd")

# 앞 담 + 대문: 대문 양옆 담이 문 기둥(anchors wall_l/r)에 맞닿는다. setback > 0이면 담을 안으로 꺾어 문간 마당(골목에서 물러난 대문)
static func _front_gate(L: Array, seed: int, X: float, Z1: float, gx: float, gp: Dictionary, kind: String, setback := 0.0) -> void:
	var hf := GT.half(gp)
	var gz := Z1 - setback
	var segs := []
	if setback <= 0.05:
		segs = [[-X, Z1, gx - hf, Z1], [gx + hf, Z1, X, Z1]]
	else:
		var nx := hf + 1.4
		segs = [[-X, Z1, gx - nx, Z1], [gx - nx, Z1, gx - nx, gz], [gx - nx, gz, gx - hf, gz], [gx + hf, gz, gx + nx, gz], [gx + nx, gz, gx + nx, Z1], [gx + nx, Z1, X, Z1]]
	var i := 0
	for sg in segs:
		if absf(sg[2] - sg[0]) + absf(sg[3] - sg[1]) < 0.3: continue
		var p := { seed = seed + 40 + i, ax = snappedf(sg[0], 0.01), az = snappedf(sg[1], 0.01), bx = snappedf(sg[2], 0.01), bz = snappedf(sg[3], 0.01) }
		match kind:
			"fence": p.lite = true; L.append(_v("wall_f%d" % i, "village/fence", p, 0, 0))
			"stone": p.lite = true; p.sparse = true; p.h = 1.25; L.append(_v("wall_f%d" % i, "village/stone_wall", p, 0, 0))
			"todam_thatch": p.h = 1.5; p.cap = "thatch"; L.append(_v("wall_f%d" % i, "village/todam", p, 0, 0))
			_: p.h = 1.7; p.cap = "tile"; p.tile_seg = 0.5; L.append(_v("wall_f%d" % i, "village/todam", p, 0, 0))
		i += 1
	if gp.get("type", "") != "none": L.append(_v("gate", "bldg/gate", gp, gx, gz, 0))

# 내외담: 대문(중문) 안쪽에 선 짧은 가림 담 — 문에서 안채가 곧장 보이지 않게
static func _naeoe(L: Array, seed: int, x: float, z: float, len := 2.8, kind := "todam_tile") -> void:
	L.append(_wall("naeoedam", seed, x - len / 2, z, x + len / 2, z, kind))

static func layout(params: Dictionary) -> Array:
	return plan(params).pieces

static func footprint(params: Dictionary) -> Vector2:
	return plan(params).fp

static func build(params: Dictionary) -> Dictionary:
	var p := plan(params)
	var res := HC.compose(p.pieces, "묶음_" + String(params.get("type", "")), p.fp)
	var ps := []
	for e in p.pieces:
		var q: Dictionary = e.duplicate()
		q.xform = Transform3D(Basis(Vector3.UP, e.ry), Vector3(e.x, 0, e.z))
		ps.append(q)
	res.pieces = ps
	res.yard = p.yard
	return res

static func _b(tag: String, sp_params: Dictionary, x: float, z: float, ry := 0.0) -> Dictionary:
	return { tag = tag, kit = "bldg/building", params = sp_params, x = snappedf(x, 0.01), z = snappedf(z, 0.01), ry = ry }

static func _v(tag: String, kit: String, p: Dictionary, x: float, z: float, ry := 0.0) -> Dictionary:
	return { tag = tag, kit = kit, params = p, x = snappedf(x, 0.01), z = snappedf(z, 0.01), ry = ry }

# 둘레 담(점은 마당 로컬, 조각 자리 원점) — 앞(+z) 줄에 문 자리 [g0, g1] 틈
static func _enclose(L: Array, seed: int, x0: float, x1: float, z0: float, z1: float, kind: String, g0: float, g1: float, skip_front := false) -> void:
	var segs := [["wall_n", x0, z0, x1, z0], ["wall_w", x0, z0, x0, z1], ["wall_e", x1, z0, x1, z1]]
	if not skip_front:
		segs.append(["wall_sw", x0, z1, g0, z1]); segs.append(["wall_se", g1, z1, x1, z1])
	var i := 0
	for s in segs:
		if absf(s[3] - s[1]) + absf(s[4] - s[2]) < 0.4: continue
		var p := { seed = seed + i, ax = snappedf(s[1], 0.01), az = snappedf(s[2], 0.01), bx = snappedf(s[3], 0.01), bz = snappedf(s[4], 0.01) }
		match kind:
			"fence": p.lite = true; L.append(_v(s[0], "village/fence", p, 0, 0))
			"todam_thatch": p.h = 1.5; p.cap = "thatch"; L.append(_v(s[0], "village/todam", p, 0, 0))
			"todam_tile": p.h = 1.7; p.cap = "tile"; p.tile_seg = 0.5; L.append(_v(s[0], "village/todam", p, 0, 0))
			"stone": p.lite = true; p.sparse = true; p.h = 1.25; L.append(_v(s[0], "village/stone_wall", p, 0, 0))
		i += 1

static func plan(params: Dictionary) -> Dictionary:
	var type: String = params.get("type", "choga_house")
	var region := S.region_of(String(params.get("region", "south")))
	var seed: int = int(params.get("seed", 1))
	var r := Kit.Rng.new(seed * 977 + hash(type + region) % 9973)
	var out: Dictionary
	match type:
		"jungnong": out = _jungnong(r, region, seed)
		"yangban": out = _yangban(r, region, seed)
		"jumak_yard": out = _jumak_yard(r, region, seed)
		"giwa_house": out = _giwa_house(r, region, seed, _lot(params), String(params.get("cls", "middle")))
		"gate_demo": out = _gate_demo(params, seed)
		"village_entry": out = _village_entry(params, seed)
		_: out = _choga_house(r, region, seed, _lot(params))
	_separate(out.pieces)
	# interior: 살림채(안채·사랑채·주막)를 실내까지 지어 들어가 볼 수 있게
	if params.get("interior", false):
		for e in out.pieces:
			if e.kit == "bldg/building" and e.tag in ["anchae", "sarang", "jumak"]: e.params = (e.params as Dictionary).merged({ interior = true })
	return out

static func _out(L: Array, X: float, Z0: float, Z1: float) -> Dictionary:
	return { pieces = L, fp = Vector2(X * 2 + 1.0, Z1 - Z0 + 1.0), yard = { minX = -X + 1.0, maxX = X - 1.0, minZ = Z0 + 1.0, maxZ = Z1 - 1.0 } }

# 서민 초가 한 채 ---------------------------------------------------------------------------------------
static func _lot(params: Dictionary) -> Vector2:
	var l = params.get("lot", null)
	if l is Array and l.size() >= 2: return Vector2(float(l[0]), float(l[1]))
	return Vector2(INF, INF)

static func _choga_house(r: Kit.Rng, region: String, seed: int, lot := Vector2(INF, INF)) -> Dictionary:
	var cls := "poor" if r.next() < 0.4 else "commoner"
	var bp := { type = "choga", region = region, cls = cls, seed = seed }
	var bb := B.bounds(S.resolve(bp))
	var X := maxf(bb.size.x / 2 + r.between(2.8, 4.2), 7.0)
	var madang := r.between(6.5, 9.0)
	# 필지: 담을 안으로(건물 옆 1.2m는 남김), 마당을 줄인다(4.5m까지)
	X = maxf(minf(X, lot.x / 2 - 0.5), bb.size.x / 2 + 1.2)
	madang = maxf(minf(madang, lot.y - 1.0 - bb.size.y - 1.4), 4.5)
	var Z0 := -(bb.size.y + madang + 1.4) / 2; var Z1 := -Z0
	var L := []
	var ax := -bb.get_center().x + r.between(-0.8, 0.8)
	var az := Z0 + 1.2 - bb.position.y
	L.append(_b("anchae", bp, ax, az))
	var sx := 1.0 if r.next() < 0.5 else -1.0
	# 헛간(마당 옆, 안쪽을 봄)
	if r.next() < 0.8 and X >= bb.size.x / 2 + 3.4:
		L.append(_b("heotgan", { type = "gotgan", region = region, cls = "commoner", seed = seed + 11 }, sx * (X - 2.4), az + bb.end.y + 1.6, -sx * PI / 2))
	L.append(_v("dwitgan", "village/dwitgan", { seed = seed * 10 + 3, s = 1.4 }, -sx * (X - 1.3), Z1 - 1.6, sx * PI / 2))
	if region != "jeju" and r.next() < 0.75:
		L.append(_v("teotbat", "village/teotbat", { seed = seed * 10 + 4, w = 4.2, d = 3.0 }, -sx * (X - 3.0), Z1 - 4.6, 0))
	if r.next() < 0.5: L.append(_v("work", "village/yard_props", { seed = seed * 10 + 5, set = "work" }, sx * 1.6, Z1 - 3.4, 0))
	var gx := r.between(-X * 0.35, X * 0.35)
	match region:
		"jeju", "mountain":
			_enclose(L, seed * 10 + 20, -X, X, Z0, Z1, "stone", 0, 0, true)
			_front_gate(L, seed * 10, X, Z1, gx, { type = "none" if region == "jeju" else "sarip", seed = seed, w = 1.6 }, "stone")
			if region == "jeju":
				pass   # 제주 올레: 문 없이 돌담 틈
		"north":
			if r.next() < 0.5:
				_enclose(L, seed * 10 + 20, -X, X, Z0, Z1, "fence", 0, 0, true)
				_front_gate(L, seed * 10, X, Z1, gx, { type = "sarip", seed = seed }, "fence")
		_:
			_enclose(L, seed * 10 + 20, -X, X, Z0, Z1, "fence", 0, 0, true)
			_front_gate(L, seed * 10, X, Z1, gx, { type = "sarip", seed = seed }, "fence")
	return _out(L, X, Z0, Z1)

# 읍내 기와집(중인·향리) ------------------------------------------------------------------------------
#   기와 一자 몸채(giwajip)가 마당 뒤에 앉고, 초가 곳간이 마당 옆, 장독대, 기와 갓 토담 + 평대문/일각문(문 안 짧은 내외담은 반쯤)
static func _giwa_house(r: Kit.Rng, region: String, seed: int, lot := Vector2(INF, INF), cls := "middle") -> Dictionary:
	var bp := { type = "giwajip", region = region, cls = cls, seed = seed }
	var bb := B.bounds(S.resolve(bp))
	var X := maxf(bb.size.x / 2 + r.between(1.4, 2.6), 6.8)
	X = maxf(minf(X, lot.x / 2 - 0.5), bb.size.x / 2 + 1.0)
	var madang := maxf(minf(r.between(6.0, 8.0), lot.y - 1.0 - bb.size.y - 1.8), 4.5)
	var Z0 := -(bb.size.y + madang + 1.8) / 2; var Z1 := -Z0
	var L := []
	var az := Z0 + 1.2 - bb.position.y
	L.append(_b("anchae", bp, -bb.get_center().x, az))
	var sx := 1.0 if r.next() < 0.5 else -1.0
	var gp := { type = "gotgan", region = region, cls = "middle", seed = seed + 11 }
	var gb := B.bounds(S.resolve(gp))
	if X - 0.6 - gb.size.y >= 2.6 and r.next() < 0.75:
		L.append(_b("gotgan", gp, sx * (X - 0.6 + gb.position.y), az + bb.end.y + 0.8 + gb.size.x / 2, -sx * PI / 2))
	L.append(_v("jangdok", "village/jangdok", { seed = seed * 10 + 3, w = 2.4, d = 1.8 }, -sx * (X - 1.8), Z0 + 1.0, 0))
	if r.next() < 0.55: L.append(_v("tree", "nature/persimmon", { seed = seed * 10 + 6, s = 0.9 }, -sx * (X - 1.4), Z1 - 1.8, 0))
	var gx := -sx * r.between(0.5, maxf(0.6, X - 3.0))
	_enclose(L, seed * 10 + 20, -X, X, Z0, Z1, "todam_tile", 0, 0, true)
	var gt := "pyeong" if r.next() < 0.6 else "ilgak"
	_front_gate(L, seed * 10, X, Z1, gx, { type = gt, seed = seed, wall_h = 1.7 }, "todam_tile")
	if r.next() < 0.5: _naeoe(L, seed + 61, gx, Z1 - 2.6, 2.6)
	return _out(L, X, Z0, Z1)

# 중농 -------------------------------------------------------------------------------------------------
static func _jungnong(r: Kit.Rng, region: String, seed: int) -> Dictionary:
	var bp := { type = "choga", region = region if region != "north" else "central", cls = "middle", seed = seed }
	var bb := B.bounds(S.resolve(bp))
	var ap := { type = "araechae", region = region, cls = "middle", seed = seed + 5 }
	var ab := B.bounds(S.resolve(ap))
	var facing := r.next() < 0.5   # 아래채가 안채와 마주봄(앞) / 옆에서 ㄱ으로
	var X := maxf(bb.size.x / 2 + 3.2, (ab.size.x / 2 + 3.0) if facing else 0.0)
	X = maxf(X, 9.0)
	var madang := r.between(8.0, 10.5)
	var Z0 := -(bb.size.y + madang + (ab.size.y if facing else 0.0) + 2.0) / 2; var Z1 := -Z0
	var L := []
	var az := Z0 + 1.2 - bb.position.y
	L.append(_b("anchae", bp, -bb.get_center().x, az))
	var sx := 1.0 if r.next() < 0.5 else -1.0
	var gx := 0.0
	if facing:
		# 아래채: 마당 앞에서 북쪽(안채)을 봄 — 대문은 아래채 옆
		var arx := -sx * (X - ab.size.x / 2 - 1.0)
		L.append(_b("araechae", ap, arx, Z1 - 1.0 - ab.end.y + 0.0, PI))
		gx = sx * (X - 2.4)
	else:
		L.append(_b("araechae", ap, sx * (X - 1.0 - ab.end.y), (az + bb.end.y + Z1) / 2 - 0.5, -sx * PI / 2))
		gx = -sx * r.between(1.0, 3.0)
	L.append(_b("gotgan", { type = "gotgan", region = region, cls = "middle", seed = seed + 7 }, -sx * (X - 2.5), az + 0.5, sx * PI / 2))
	L.append(_v("well", "village/well", { seed = seed * 10 + 2 }, -sx * (X - 3.6), Z1 - 4.0 if not facing else (Z0 + Z1) / 2 + 2.0, 0))
	L.append(_v("jangdok", "village/jangdok", { seed = seed * 10 + 3, w = 2.8, d = 2.0 }, sx * (bb.size.x / 2 - 1.5), Z0 + 0.4, 0))
	L.append(_v("dwitgan", "village/dwitgan", { seed = seed * 10 + 4, s = 1.4 }, -sx * (X - 1.3), Z0 + 1.6, sx * PI / 2))
	if r.next() < 0.6: L.append(_v("work", "village/yard_props", { seed = seed * 10 + 5, set = _pick(r, ["work", "manure_coop", "woodpile"]) }, sx * 1.8, (Z0 + Z1) / 2 + 2.0, 0))
	if r.next() < 0.6: L.append(_v("tree", "nature/persimmon", { seed = seed * 10 + 6, s = 0.9 }, -sx * (X - 1.6), Z0 + 2.0, 0))
	var wall: String = "stone" if region in ["jeju", "mountain"] else "todam_thatch"
	_enclose(L, seed * 10 + 20, -X, X, Z0, Z1, wall, 0, 0, true)
	_front_gate(L, seed * 10, X, Z1, gx, { type = "chomun" if wall == "todam_thatch" else "sarip", seed = seed, wall_h = 1.5, w = 1.6 if wall != "todam_thatch" else 1.9 }, wall)
	return _out(L, X, Z0, Z1)

static func _pick(r: Kit.Rng, a: Array):
	return a[mini(a.size() - 1, int(r.next() * a.size()))]

# 양반가 ------------------------------------------------------------------------------------------------
# 짜임 셋(시드마다 다르게):
#   0 "도성·읍내 큰 집": 행랑채(솟을대문) → 사랑마당·사랑채 → 중문 담 → 안마당·안채 → 뒤뜰 사당
#   1 "옆 사랑": 행랑채 없이 기와 토담 + 평대문, 사랑채가 마당 옆에서 안마당을 보고(동·서향), 안채 뒤 사당
#   2 "튼ㅁ자 향반가": 사랑채가 앞줄에 남향으로 서고 그 옆 평대문, 안채(ㄱ·ㄷ)와 곳간이 안마당을 둘러 튼 ㅁ자
static func _yangban(r: Kit.Rng, region: String, seed: int) -> Dictionary:
	var rg := region if region != "jeju" else "south"
	var variant := (seed + int(r.next() * 2.0) * 3) % 3
	var anp := { type = "anchae", region = rg, cls = "yangban", seed = seed }
	var anb := B.bounds(S.resolve(anp))
	var sap := { type = "sarang", region = rg, cls = "yangban", seed = seed + 3 }
	var sab := B.bounds(S.resolve(sap))
	var has_sd := variant != 2 or r.next() < 0.5
	var sdp := { type = "sadang", region = rg, cls = "yangban", seed = seed + 9 }
	var sdb := B.bounds(S.resolve(sdp))
	var back := (sdb.size.y + 1.0) if has_sd else 4.0
	var sx := 1.0 if r.next() < 0.5 else -1.0
	var L := []
	var X: float; var Z0: float; var Z1: float
	if variant == 0:
		var hrp := { type = "haengrang", region = rg, cls = "yangban", seed = seed + 5 }
		var hrsp := S.resolve(hrp)
		var hrb := B.bounds(hrsp)
		X = maxf(maxf(anb.size.x, hrb.size.x) / 2 + 2.5, sab.size.x / 2 + 7.0)
		var in_yard := r.between(7.0, 9.0); var out_yard := r.between(6.0, 8.0)
		var Zd := back + anb.size.y + in_yard + 1.0 + sab.size.y + out_yard + hrb.size.y
		Z0 = -Zd / 2; Z1 = Zd / 2
		var hz := Z1 - hrb.end.y + 0.6
		L.append(_b("haengrang", hrp, -hrb.get_center().x, hz))
		var gxl := -hrb.get_center().x
		var Lh := 0.0
		for b in hrsp.wings[0].bays: Lh += float(b.w)
		var az := Z0 + back - anb.position.y
		L.append(_b("anchae", anp, -anb.get_center().x, az))
		var zm := az + anb.end.y + in_yard
		# 중문: 대문 줄에서 비켜 낸다(대문 → 중문 → 안채가 한 줄로 보이지 않게) + 안마당 쪽 내외담
		var gxl0 := -hrb.get_center().x
		var mg := -sx * r.between(2.5, 4.0)
		var jp := { type = "jungmun", seed = seed + 3, wall_h = 1.7 }
		var jh := GT.half(jp)
		for seg in [[-X, mg - jh], [mg + jh, X]]:
			L.append(_wall("midwall%d" % L.size(), seed + L.size(), seg[0], zm, seg[1], zm, "todam_tile"))
		L.append(_v("jungmun", "bldg/gate", jp, mg, zm, 0))
		_naeoe(L, seed + 61, mg, zm - 2.0, 2.8)
		L.append(_b("sarang", sap, sx * (X - sab.size.x / 2 - 1.2) - sab.get_center().x, zm + 0.8 - sab.position.y))
		L.append(_b("gotgan", { type = "gotgan", region = rg, cls = "yangban", seed = seed + 7 }, -sx * (X - 2.6), az + anb.end.y + 2.4, sx * PI / 2))
		L.append(_v("well", "village/well", { seed = seed * 10 + 2 }, sx * (X - 3.0), az + anb.end.y + in_yard * 0.5, 0))
		if r.next() < 0.7: L.append(_v("tree", "nature/persimmon", { seed = seed * 10 + 6, s = 1.0 }, -sx * (X - 2.0), zm + out_yard * 0.6, 0))
		_enclose(L, seed * 10 + 20, -X, X, Z0, hz, "todam_tile", 0, 0, true)
		for seg in [[-X, gxl - Lh / 2 - 0.2], [gxl + Lh / 2 + 0.2, X]]:
			if seg[1] - seg[0] > 0.3: L.append(_wall("wall_f%d" % L.size(), seed + L.size(), seg[0], hz, seg[1], hz, "todam_tile"))
	elif variant == 1:
		# 옆 사랑: 사랑채가 마당 옆(동·서)에서 안마당을 본다
		X = anb.size.x / 2 + sab.size.y + 3.0
		var yard := r.between(9.0, 12.0)
		var Zd := back + anb.size.y + maxf(yard, sab.size.x + 2.0) + 2.0
		Z0 = -Zd / 2; Z1 = Zd / 2
		var az := Z0 + back - anb.position.y
		L.append(_b("anchae", anp, -anb.get_center().x * 0.0 - sx * 1.0, az))
		var sz := az + anb.end.y + sab.size.x / 2 + 1.0
		L.append(_b("sarang", sap, sx * (X - 1.0 - sab.end.y), sz, -sx * PI / 2))
		L.append(_b("gotgan", { type = "gotgan", region = rg, cls = "yangban", seed = seed + 7 }, -sx * (X - 2.4), sz + 1.0, sx * PI / 2))
		L.append(_v("well", "village/well", { seed = seed * 10 + 2 }, -sx * (X - 2.2), Z1 - 2.6, 0))   # 우물은 대문 길에서 비켜(앞 구석)
		if r.next() < 0.8: L.append(_v("tree", "nature/persimmon", { seed = seed * 10 + 6, s = 1.1 }, -sx * (X - 2.2), Z1 - 2.5, 0))
		var gx := -sx * r.between(1.0, 3.0)
		_enclose(L, seed * 10 + 20, -X, X, Z0, Z1, "todam_tile", 0, 0, true)
		# 골목에서 물러난 평대문(문간 마당) + 문 안 내외담
		_front_gate(L, seed * 10, X, Z1, gx, { type = "pyeong", seed = seed, wall_h = 1.7 }, "todam_tile", 1.8)
		_naeoe(L, seed + 61, gx, Z1 - 1.8 - 2.6, 3.0)
	else:
		# 튼ㅁ자: 사랑채가 앞줄(남향), 옆에 평대문, 안채와 곳간이 안마당을 둘러쌈
		X = maxf(anb.size.x / 2 + 2.0, sab.size.x / 2 + 5.5)
		var yard := r.between(7.5, 10.0)
		var Zd := back + anb.size.y + yard + sab.size.y + 1.0
		Z0 = -Zd / 2; Z1 = Zd / 2
		var az := Z0 + back - anb.position.y
		L.append(_b("anchae", anp, -anb.get_center().x, az))
		var sxp := -sx * (X - sab.size.x / 2 - 0.4) - sab.get_center().x
		L.append(_b("sarang", sap, sxp, Z1 - sab.end.y - 0.2))
		L.append(_b("gotgan", { type = "gotgan", region = rg, cls = "yangban", seed = seed + 7 }, sx * (X - 2.4), az + anb.end.y + yard * 0.45, -sx * PI / 2))
		var gx := sx * (X - 2.6)
		var sedge := sxp + sab.size.x / 2 * (1.0 if sx > 0 else -1.0)
		_enclose(L, seed * 10 + 20, -X, X, Z0, Z1, "todam_tile", 0, 0, true)
		_front_gate(L, seed * 10, X, Z1, gx, { type = "ilgak" if r.next() < 0.5 else "pyeong", seed = seed, wall_h = 1.7 }, "todam_tile")
		_naeoe(L, seed + 61, gx - sx * 0.6, Z1 - 3.0, 3.0)
		L.append(_v("well", "village/well", { seed = seed * 10 + 2 }, -gx * 0.4 - sx * 2.0, az + anb.end.y + yard * 0.4, 0))
	if has_sd:
		var sdx := sx * (X - sdb.size.x / 2 - 0.6)
		L.append(_b("sadang", sdp, sdx - sdb.get_center().x, Z0 + 0.6 - sdb.position.y, 0))
		# 사당 앞 낮은 담(사당 구역)
		L.append(_wall("sadang_wall", seed + 77, sdx - sdb.size.x / 2 - 0.3, Z0 + sdb.size.y + 0.9, sdx + sdb.size.x / 2 + 0.3, Z0 + sdb.size.y + 0.9, "todam_tile"))
	L.append(_v("jangdok", "village/jangdok", { seed = seed * 10 + 3, w = 3.4, d = 2.4, n = [4, 3, 2] }, -sx * (anb.size.x / 2 - 2.0), Z0 + 1.6, 0))
	return _out(L, X, Z0, Z1)

static func _wall(tag: String, seed: int, ax: float, az: float, bx: float, bz: float, kind: String) -> Dictionary:
	var p := { seed = seed, ax = snappedf(ax, 0.01), az = snappedf(az, 0.01), bx = snappedf(bx, 0.01), bz = snappedf(bz, 0.01), h = 1.7, cap = "tile", tile_seg = 0.5 }
	if kind == "todam_thatch": p.h = 1.5; p.cap = "thatch"
	return _v(tag, "village/todam", p, 0, 0)

# 주막 마당: 주막 + 반쯤 두른 싸리울 + 길가 쪽 트임
static func _jumak_yard(r: Kit.Rng, region: String, seed: int) -> Dictionary:
	var bp := { type = "jumak", region = region, cls = "commoner", seed = seed }
	var bb := B.bounds(S.resolve(bp))
	var X := bb.size.x / 2 + 2.5
	var Z0 := bb.position.y - 1.6; var Z1 := bb.end.y + 6.5
	var cz := (Z0 + Z1) / 2
	var L := []
	L.append(_b("jumak", bp, -bb.get_center().x, -cz))
	var sx := 1.0 if r.next() < 0.5 else -1.0
	# 뒤·옆만 싸리울(앞은 길로 트임)
	var x0 := -X; var x1 := X; var z0 := Z0 - cz; var z1 := Z1 - cz
	for s in [["wall_n", x0, z0, x1, z0], ["wall_w", x0, z0, x0, z1 - 3.0], ["wall_e", x1, z0, x1, z1 - 3.0]]:
		L.append(_v(s[0], "village/fence", { seed = seed + L.size(), lite = true, ax = snappedf(s[1], 0.01), az = snappedf(s[2], 0.01), bx = snappedf(s[3], 0.01), bz = snappedf(s[4], 0.01) }, 0, 0))
	if r.next() < 0.6: L.append(_v("tree", "nature/persimmon", { seed = seed * 10 + 6, s = 1.1 }, sx * (X - 1.0), z1 - 1.5, 0))
	return _out(L, X, Z0 - cz, Z1 - cz)

# 건물끼리 처마가 겹치면(지붕이 서로 뚫음) 뒤에 놓인 건물을 떼어 놓는다 — 처마 사이 0.3m 틈.
#   먼저 놓인 건물(안채·행랑채 순)이 자리를 지킨다. 축 하나로만 민다(겹침이 작은 쪽).
static func _separate(pieces: Array) -> void:
	var rects := []
	for e in pieces:
		if e.kit != "bldg/building": rects.append(null); continue
		var b := B.bounds(S.resolve(e.params))
		var xf := Transform3D(Basis(Vector3.UP, float(e.ry)), Vector3(float(e.x), 0, float(e.z)))
		rects.append(B._xf_rect(b, xf))
	for it in 6:
		var moved := false
		for i in pieces.size():
			if rects[i] == null: continue
			for j in i:
				if rects[j] == null: continue
				var a: Rect2 = (rects[i] as Rect2).grow(0.15); var b: Rect2 = (rects[j] as Rect2).grow(0.15)
				if not a.intersects(b): continue
				var ox := minf(a.end.x, b.end.x) - maxf(a.position.x, b.position.x)
				var oz := minf(a.end.y, b.end.y) - maxf(a.position.y, b.position.y)
				var d := Vector2.ZERO
				if ox < oz: d.x = ox * (1.0 if a.get_center().x >= b.get_center().x else -1.0)
				else: d.y = oz * (1.0 if a.get_center().y >= b.get_center().y else -1.0)
				pieces[i].x = snappedf(float(pieces[i].x) + d.x, 0.01); pieces[i].z = snappedf(float(pieces[i].z) + d.y, 0.01)
				rects[i] = (rects[i] as Rect2).grow(0.0)
				rects[i].position += d
				moved = true
		if not moved: break

# 대문 견본: 문 하나 + 양옆 담 토막(갤러리·비교용). params.gate = 대문 종류
static func _gate_demo(params: Dictionary, seed: int) -> Dictionary:
	var gt: String = params.get("gate", "pyeong")
	var wall: String = { sarip = "fence", chomun = "todam_thatch", hongsal = "none", samun = "stone" }.get(gt, "todam_tile")
	var gp := { type = gt, seed = seed, wall_h = 1.5 if wall == "todam_thatch" else 1.7 }
	var L := []
	var hf := GT.half(gp)
	var X := hf + 3.2
	if wall != "none": _front_gate(L, seed, X, 0.0, 0.0, gp, wall)
	else: L.append(_v("gate", "bldg/gate", gp, 0.0, 0.0, 0))
	return { pieces = L, fp = Vector2(X * 2 + 1.0, 4.0), yard = { minX = -X, maxX = X, minZ = -2.0, maxZ = 2.0 } }

# 마을 어귀: 길 양옆 장승 한 쌍 + 서낭당(돌무더기·당목) + 공동 우물 — 진입 소품 견본
static func _village_entry(params: Dictionary, seed: int) -> Dictionary:
	var L := []
	L.append(_v("jangseung_l", "village/jangseung", { seed = seed }, -2.2, 1.0, PI / 2))
	L.append(_v("jangseung_r", "village/jangseung", { seed = seed + 1, female = true }, 2.2, 1.0, -PI / 2))
	L.append(_v("seonghwang", "village/seonghwangdang", { seed = seed + 2 }, -6.5, -2.5, PI / 4))
	L.append(_v("well", "village/well", { seed = seed + 3 }, 6.0, -4.0, 0))
	return { pieces = L, fp = Vector2(18.0, 12.0), yard = { minX = -9.0, maxX = 9.0, minZ = -6.0, maxZ = 6.0 } }
