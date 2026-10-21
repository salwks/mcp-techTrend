# 도시·마을 빌더(settlement builder) — 고을 등급(대도시·중도시·소도시·마을)과 지형·물·씨앗을 받아
#   ① 성곽·성문 ② 주 가로(성문 축·십자로·성 안 둘레길) ③ 문헌 규칙으로 큰 건물(객사·동헌/감영·내아·향청·작청·사창·옥·향교·사직단·여단·성황사·장시·나루·정자·서당·당산나무…)
#   ④ 구역 나누기(관아·양반·중인·서민·성 밖) ⑤ 구역마다 고을 짜임 생성기(kit/bldg/organic.gd — 갈래길·필지·담·집·마당 것)를 돌린다.
#   규칙과 근거: docs/reports/settlement-rules.md (고증은 참고 — 정확한 실측 재현이 아님). 결정적(씨앗).
#
#   API
#     var S := preload("res://kit/bldg/settlement.gd")
#     var res := S.build(cfg, height, rivers)   # → { items: [배치 항목…], alleys: [{id, points, width_m}], majors: […], districts: [{id, area, lots, items}], log: [] }
#   cfg = {
#     tier: "metro" | "city" | "town" | "village",
#     kind: (village) "banchon" 반촌 | "minchon" 민촌 | "sanchon" 산촌 | "yeokchon" 역촌,   (town) walled: true|false(무성읍치)
#     c: [x, z] 고을 가운데(읍성 한가운데 / 마을 어귀 안쪽), ry: 정면 방향(로컬 +z = 남문·안산 쪽, 뒤 −z = 진산) — 라디안,
#     seed, region("south"…), prefix(항목 id 머리), group(배치 묶음 이름), size(배율, 1),
#     rivers: [{pts, w}] (물길 — 필지가 비키고, 마을 짜임이 물가 정자·나루를 고른다), keep: [{c, r}](비울 자리)
#   }
#   좌표: 로컬(x 동, z 남 — ry로 돌림)에서 짜고 월드로 옮긴다.
extends RefCounted
const OG := preload("res://kit/bldg/organic.gd")
const B := preload("res://kit/bldg/building.gd")
const S := preload("res://kit/bldg/_spec.gd")
const CP := preload("res://kit/bldg/compound.gd")

# 등급 표(기본값 — 문헌 근거·출처는 settlement-rules.md §2)
const TIERS := {
	"metro": { side = 300.0, wall = true, ong = true, label = "대도시(감영·유수부급)" },
	"city": { side = 200.0, wall = true, ong = true, label = "중도시(목·부·대도호부급)" },
	"town": { side = 130.0, wall = true, ong = false, label = "소도시(군·현급)" },
	"village": { side = 0.0, wall = false, ong = false, label = "마을" },
}

static func _rot(v: Vector2, a: float) -> Vector2:
	return Vector2(v.x * cos(a) + v.y * sin(a), -v.x * sin(a) + v.y * cos(a))

class Ctx:
	var cfg: Dictionary
	var c: Vector2
	var ry: float
	var seed: int
	var pre: String
	var group: String
	var region: String
	var items := []
	var majors := []
	var keep_poly := []      # 월드 다각형(배열 [x,z])
	var keep := []
	var districts := []      # organic 설정
	var trunks := []         # [{id, pts(월드 [x,z]), w, paint}]
	var log := []
	var n := 0
	func W(lx: float, lz: float) -> Vector2:
		return c + Vector2(lx * cos(ry) + lz * sin(ry), -lx * sin(ry) + lz * cos(ry))
	func Wa(lx: float, lz: float) -> Array:
		var v := W(lx, lz); return [snappedf(v.x, 0.01), snappedf(v.y, 0.01)]
	# 큰 건물 하나(월드 항목) + 그 자리(돌린 사각 → keep_poly)
	func put(tag: String, kit: String, params: Dictionary, lx: float, lz: float, lry := 0.0, fp := Vector2.ZERO, pad := 2.0, extra := {}) -> Dictionary:
		var p := W(lx, lz)
		n += 1
		var it := { id = "%s_%s%02d" % [pre, tag, n], kit = kit, params = params, x = snappedf(p.x, 0.01), z = snappedf(p.y, 0.01), ry = snappedf(ry + lry, 0.0001), y = null,
			flatten = extra.get("flatten", true), clear_veg = true, group = group, settlement = { role = tag } }
		if fp != Vector2.ZERO:
			it.footprint = [snappedf(fp.x, 0.1), snappedf(fp.y, 0.1)]
			var poly := []
			for q in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
				var lq := Vector2(q.x * (fp.x / 2 + pad), q.y * (fp.y / 2 + pad))
				var w := W(lx, lz) + Vector2(lq.x * cos(ry + lry) + lq.y * sin(ry + lry), -lq.x * sin(ry + lry) + lq.y * cos(ry + lry))
				poly.append([snappedf(w.x, 0.01), snappedf(w.y, 0.01)])
			keep_poly.append(poly)
		for k in extra:
			if k != "flatten": it[k] = extra[k]
		items.append(it)
		majors.append({ role = tag, kit = kit, at = [it.x, it.z] })
		return it
	func trunk(id: String, local_pts: Array, w: float, paint := true) -> void:
		var pts := []
		for q in local_pts: pts.append(Wa(float(q[0]), float(q[1])))
		trunks.append({ id = id, pts = pts, w = w, paint = paint })
	func poly(local_pts: Array) -> Array:
		var out := []
		for q in local_pts: out.append(Wa(float(q[0]), float(q[1])))
		return out
	func district(id: String, area_local: Array, extra: Dictionary) -> void:
		var d := { id = id, area = poly(area_local) }
		for k in extra: d[k] = extra[k]
		districts.append(d)

# 표(구역마다 집 종류 무게 — organic.gd TABLE 꼴)
const T_GWAN := { dense = [["house_g", 0.4], ["giwa_house", 0.25], ["yangban", 0.1], ["shop", 0.1], ["house_c", 0.15]],
	mid = [["house_g", 0.3], ["giwa_house", 0.2], ["yangban", 0.1], ["house_c", 0.25], ["choga_house", 0.15]], outer = [["house_g", 0.25], ["house_c", 0.4], ["choga_house", 0.35]] }
const T_SIJEON := { dense = [["shop", 0.45], ["house_g", 0.25], ["house_c", 0.2], ["giwa_house", 0.1]],
	mid = [["house_g", 0.25], ["house_c", 0.35], ["choga_house", 0.2], ["shop", 0.2]], outer = [["house_c", 0.45], ["choga_house", 0.4], ["hut", 0.15]] }
const T_YANGBAN := { dense = [["yangban", 0.35], ["giwa_house", 0.35], ["house_g", 0.3]], mid = [["yangban", 0.25], ["giwa_house", 0.35], ["house_g", 0.25], ["house_c", 0.15]],
	outer = [["giwa_house", 0.3], ["house_g", 0.3], ["choga_house", 0.4]] }
const T_SEOMIN := { dense = [["house_c", 0.45], ["choga_house", 0.3], ["shop", 0.1], ["house_g", 0.15]], mid = [["choga_house", 0.4], ["house_c", 0.35], ["jungnong", 0.15], ["hut", 0.1]],
	outer = [["choga_house", 0.38], ["jungnong", 0.22], ["house_c", 0.15], ["hut", 0.17], ["field", 0.08]] }
const T_MINCHON := { dense = [["choga_house", 0.5], ["house_c", 0.3], ["jungnong", 0.2]], mid = [["choga_house", 0.45], ["jungnong", 0.25], ["house_c", 0.15], ["hut", 0.15]],
	outer = [["choga_house", 0.35], ["jungnong", 0.25], ["hut", 0.25], ["field", 0.15]] }

static func build(cfg: Dictionary, height: Callable = Callable(), rivers: Array = []) -> Dictionary:
	var X := Ctx.new()
	X.cfg = cfg
	X.c = Vector2(float(cfg.c[0]), float(cfg.c[1]))
	X.ry = float(cfg.get("ry", 0.0))
	X.seed = int(cfg.get("seed", 1))
	X.pre = String(cfg.get("prefix", "set"))
	X.group = String(cfg.get("group", "고을 빌더"))
	X.region = String(cfg.get("region", "south"))
	var tier: String = cfg.get("tier", "city")
	match tier:
		"metro": _metro(X)
		"city": _city(X)
		"town": _town(X)
		_: _village(X, String(cfg.get("kind", "minchon")))
	# 구역마다 고을 짜임(갈래길·필지·집)
	var alleys := []
	var dsum := []
	for k in X.districts.size():
		var d: Dictionary = X.districts[k]
		var oc := {
			seed = X.seed * 31 + k * 7 + 1, prefix = "%s_%s" % [X.pre, String(d.id)], group = X.group, region = d.get("region", X.region),
			area = d.area, trunks = [], keep = X.keep + (cfg.get("keep", []) as Array), keep_poly = X.keep_poly, rivers = rivers,
			plazas = d.get("plazas", []), centers = d.get("centers", []), base_density = d.get("base_density", 0.3),
			branch = d.get("branch", { gap_a = 22.0, gap_b = 36.0, p = 0.9, len_a = 30.0, len_b = 80.0, alley_gap_a = 16.0, alley_gap_b = 26.0, alley_p = 0.7 }),
			junction_plaza_p = d.get("junction_plaza_p", 0.3), empty_out = d.get("empty_out", 0.08), empty_in = d.get("empty_in", 0.0),
			table = d.get("table", {}), trunk_shop = d.get("trunk_shop", 0.0), terrace = true, trees = d.get("trees", 0.35 if String(d.id).begins_with("in") else 0.8),
		}
		# 이 구역에 닿는 큰길(구역 둘레 40m 안 마디)
		var apoly := []
		for q in d.area: apoly.append(Vector2(float(q[0]), float(q[1])))
		for t in X.trunks:
			var near := false
			for q in t.pts:
				var v := Vector2(float(q[0]), float(q[1]))
				if OG.pip(apoly, v): near = true; break
				for i in apoly.size():
					if OG.seg_dist(v, apoly[i], apoly[(i + 1) % apoly.size()]) < 30.0: near = true; break
				if near: break
			if near: oc.trunks.append({ id = t.id, pts = t.pts, w = t.w })
		var g := OG.new(oc, height)
		var res := g.run()
		for it in res.items: X.items.append(it)
		for a in res.alleys:
			a.id = String(oc.prefix) + "_" + String(a.id)
			alleys.append(a)
		dsum.append({ id = d.id, area = d.area, lots = res.lots.size(), items = res.items.size(), streets = res.streets.size() - oc.trunks.size() })
		for l in res.log: X.log.append("[%s] %s" % [d.id, l])
	for t in X.trunks:
		if t.get("paint", true): alleys.append({ id = "%s_%s" % [X.pre, t.id], points = t.pts, width_m = snappedf(float(t.w) - 0.4, 0.01), kind = "trunk" })
	return { items = X.items, alleys = alleys, majors = X.majors, districts = dsum, log = X.log, tier = tier, label = TIERS.get(tier, {}).get("label", tier) }

# ------------------------------------------------------------------------------------------------------
# 공통: 읍성(방형 석성, 4문 + 옹성) · 성문 축 · 성 안 둘레길 · 성 밖 삼단일묘·향교·장시
static func _walls(X: Ctx, side: float, ong: bool) -> void:
	var ongp = { S = "front", N = "west", E = "south", W = "north" } if ong else false
	X.put("eupseong", "landmark/namwon_eupseong", { seed = X.seed, side = side, ongseong = ongp }, 0, 0, 0.0, Vector2.ZERO, 0.0, { flatten = false })
	var h := side / 2.0 - 8.0
	X.trunk("ring_s", [[-h, h], [0, h + 0.5], [h, h]], 3.2)
	X.trunk("ring_w", [[-h, h], [-h - 0.5, 0], [-h, -h]], 3.0)
	X.trunk("ring_e", [[h, h], [h + 0.5, 0], [h, -h]], 3.0)
	X.trunk("ring_n", [[-h, -h], [0, -h - 0.5], [h, -h]], 3.0)

# 삼단일묘·향교(성 밖): 사직단 서, 여단 북, 성황사 진산 쪽(북서), 향교 동(성에서 조금 떨어져) + 향교 앞 홍살문·하마비
static func _sandan(X: Ctx, side: float, far := 1.0) -> void:
	var h := side / 2.0
	X.put("sajikdan", "landmark/sajikdan", { seed = X.seed + 11 }, -(h + 62.0 * far), -side * 0.08, 0.0, Vector2(25, 25))
	X.put("yeodan", "landmark/yeodan", { seed = X.seed + 12 }, side * 0.12, -(h + 58.0 * far), 0.0, Vector2(19, 19))
	X.put("seonghwangsa", "landmark/seonghwangsa", { seed = X.seed + 13 }, -side * 0.32, -(h + 78.0 * far), 0.0, Vector2(20, 18))
	X.put("dangsan", "nature/big_tree", { seed = X.seed + 14, variant = "zelkova", h = 12.0 }, -side * 0.32 + 12.0, -(h + 70.0 * far), 0.0, Vector2(6, 6), 0.0, { flatten = false })
	var hx := h + 78.0 * far
	X.put("hyanggyo", "landmark/hyanggyo", { seed = X.seed + 15 }, hx, -side * 0.12, 0.0, Vector2(42, 62))
	X.put("hyanggyo_hongsal", "bldg/gate", { type = "hongsal", seed = X.seed + 16 }, hx, -side * 0.12 + 40.0, 0.0, Vector2(4, 1.2), 0.5)
	X.put("hyanggyo_hama", "bldg/stone", { kind = "bi", kind_bi = "hama", seed = X.seed + 17 }, hx - 5.0, -side * 0.12 + 42.0, 0.0, Vector2(1.2, 1.0), 0.3, { flatten = false })
	X.trunk("to_hyanggyo", [[h + 4.0, 0.0], [h + 30.0, 2.0], [hx, 2.0], [hx, -side * 0.12 + 46.0]], 3.0)

# 장시(성문 밖): 남문 밖 큰길가 장마당(좌판 줄·차일) + 주막 묶음 + 정자나무. 길목 마당(plaza)
static func _jangsi(X: Ctx, side: float, rows := 2, len := 70.0) -> void:
	var h := side / 2.0
	var z0 := h + 22.0
	var k := 0
	var goods := ["cloth", "onggi", "grain", "straw", "fish", "mixed"]
	for sx in [-1.0, 1.0]:
		for rr in rows:
			var z := z0
			while z < z0 + len:
				X.put("jwapan", "village/jwapan", { seed = X.seed * 100 + k, goods = goods[k % goods.size()], awning = (k % 3) != 0 }, sx * (5.2 + rr * 3.4), z, PI / 2 * sx, Vector2.ZERO, 0.2, { flatten = false })
				z += 3.6 + float(k % 3) * 0.6; k += 1
	X.put("jumak", "bldg/compound", { type = "jumak_yard", region = X.region, seed = X.seed + 21 }, 22.0, z0 + len * 0.55, -PI / 2, CP.footprint({ type = "jumak_yard", region = X.region, seed = X.seed + 21 }), 1.0)
	X.put("jangsi_tree", "nature/big_tree", { seed = X.seed + 22, variant = "zelkova", h = 11.0 }, -14.0, z0 + 8.0, 0.0, Vector2(5, 5), 0.0, { flatten = false })

# ------------------------------------------------------------------------------------------------------
# 중도시(목·부·대도호부급 — 남원도호부 꼴): 객사가 남문 축 북쪽 가운데, 관아(동헌·내아)는 객사 동쪽, 향청·작청이 관아 앞 길 건너, 사창 서북, 옥 관아 가까이
static func _city(X: Ctx) -> void:
	var side: float = float(X.cfg.get("side", TIERS.city.side)) * float(X.cfg.get("size", 1.0))
	var h := side / 2.0
	_walls(X, side, true)
	# 주 가로: 남문 → 객사 앞(남북 대로), 서문 ↔ 동문(동서 대로) — 객사 앞에서 T·十자
	var zg := -side * 0.08   # 객사 삼문 앞
	X.trunk("ns", [[0, h + 95.0], [0, h], [0, zg]], 5.0)
	X.trunk("ew", [[-(h + 40.0), 0], [-h, 0], [h, 0], [h + 40.0, 0]], 5.0)
	X.trunk("n_gate", [[0, -(h + 40.0)], [0, -h], [0, -h + 12.0], [side * 0.3, -h + 12.0]], 3.4)
	# 객사(전패 봉안 — 읍치 가운데, 남향, 남문 축 위) + 삼문 + 앞 박석 마당
	X.put("gaeksa", "landmark/gaeksa", { seed = X.seed + 1, jeongdang_bays = 5 }, 0, -side * 0.28, 0.0, Vector2(67.2, 14.0), 3.0)
	X.put("gaeksa_samun", "landmark/samun", { seed = X.seed + 2, kind = "outer", name = "객사" }, 0, zg - 3.0, 0.0, Vector2(10.8, 5.6), 1.0)
	X.put("gaeksa_court", "bldg/stone", { kind = "baksuk", w = 12.0, d = 14.0, seed = X.seed + 3 }, 0, (zg - 3.0 + (-side * 0.28 + 7.0)) / 2.0, 0.0, Vector2(12, 14), 0.5, { flatten = false })
	_court_wall(X, "gaeksa_wall", 0.0, -side * 0.28 + 4.0, 76.0, (zg - 3.0) - (-side * 0.28 - 12.0), zg - 3.0, 11.0)
	# 관아(동헌·내아 — 객사 동쪽, 남향) + 홍살문·하마비
	var gx := side * 0.3; var gz := -side * 0.2
	X.put("gwana", "landmark/gwana", { seed = X.seed + 4, width = 54.0, depth = 64.0 }, gx, gz, 0.0, Vector2(56, 70), 2.0)
	X.put("gwana_hongsal", "bldg/gate", { type = "hongsal", seed = X.seed + 5 }, gx, gz + 38.0, 0.0, Vector2(4.4, 1.2), 0.3)
	X.put("gwana_hama", "bldg/stone", { kind = "bi", kind_bi = "hama", seed = X.seed + 6 }, gx - 6.0, gz + 39.0, 0.0, Vector2(1.2, 1.0), 0.3, { flatten = false })
	# 향청(유향소 — 수령 자문, 관아 가까이) · 작청(질청, 향리 — 관아 앞) : 동서 대로 남쪽, 관아를 바라봄
	X.put("hyangcheong", "bldg/building", { type = "gangdang", region = X.region, seed = X.seed + 7 }, gx - 22.0, side * 0.11, PI, B.footprint({ type = "gangdang", region = X.region, seed = X.seed + 7 }), 2.0)
	X.put("jakcheong", "bldg/building", { type = "haengrang", region = X.region, cls = "official", seed = X.seed + 8 }, gx + 16.0, side * 0.1, PI, B.footprint({ type = "haengrang", region = X.region, cls = "official", seed = X.seed + 8 }), 2.0)
	# 사창(환곡 창고 — 곳간 셋이 마당을 둘러쌈) : 서북
	_sachang(X, -side * 0.3, -side * 0.24)
	# 옥(둥근 담 원옥 — 관아 동남 가까이)
	_ok(X, side * 0.36, side * 0.3)
	_sandan(X, side)
	_jangsi(X, side)
	X.trunk("out_ew", [[-side * 0.62, h + 20.0], [-side * 0.25, h + 22.0], [side * 0.25, h + 21.0], [side * 0.62, h + 20.0]], 3.6)   # 성 밖 해자 앞 길(성 둘레 바깥 길)
	X.trunk("out_ew2", [[-side * 0.6, h + 98.0], [0, h + 104.0], [side * 0.6, h + 96.0]], 3.4)
	# 비보 숲(수구막이): 성 밖 동남 물 나가는 쪽 소나무 줄
	for i in 9: X.put("bibo", "nature/pine", { seed = X.seed + 40 + i, s = 1.15 }, h + 18.0 + i * 5.5, h + 26.0 + (i % 2) * 4.0, 0.0, Vector2.ZERO, 0.0, { flatten = false })
	# 구역: 성 안 북(관아·중인 — 관아 가까이 향리·기와집) · 성 안 남(시전·서민) · 성 밖 남(장시·서민 초가)
	var i_ := h - 9.0
	X.district("in_n", [[-i_, -i_], [i_, -i_], [i_, -3.0], [-i_, -3.0]], { table = T_GWAN, base_density = 0.55, centers = [{ c = X.Wa(0, zg), r = side * 0.5, w = 1.0 }], trunk_shop = 0.15 })
	X.district("in_s", [[-i_, 3.0], [i_, 3.0], [i_, i_], [-i_, i_]], { table = T_SIJEON, base_density = 0.5, trunk_shop = 0.55,
		centers = [{ c = X.Wa(0, 0), r = side * 0.45, w = 1.0 }, { c = X.Wa(0, h), r = side * 0.35, w = 0.9 }],
		plazas = [{ c = X.Wa(0, 4.0), r = 6.5, kind = "well" }, { c = X.Wa(0, h - 10.0), r = 7.0, kind = "gate" }] })
	X.district("out_s", [[-side * 0.62, h + 16.0], [side * 0.62, h + 16.0], [side * 0.62, h + 120.0], [-side * 0.62, h + 120.0]], { table = T_SEOMIN, base_density = 0.25, trunk_shop = 0.3,
		centers = [{ c = X.Wa(0, h + 40.0), r = 90.0, w = 0.8 }], empty_out = 0.15, plazas = [{ c = X.Wa(0, h + 22.0 + 35.0), r = 38.0, kind = "market" }] })

# 대도시(감영·유수부급, 축소형 — 전주·대구·평양 꼴): 감영(선화당)이 남문 축 북쪽 가운데, 객사는 서쪽, 부 관아(부영)는 동쪽,
#   남문길·동서길이 시전 거리(가게채 줄), 북동 양반 동네, 남쪽·성 밖 서민, 남문 밖 큰 장시
static func _metro(X: Ctx) -> void:
	var side: float = float(X.cfg.get("side", TIERS.metro.side)) * float(X.cfg.get("size", 1.0))
	var h := side / 2.0
	_walls(X, side, true)
	var zg := -side * 0.1
	X.trunk("ns", [[0, h + 110.0], [0, h], [0, zg]], 6.0)
	X.trunk("ew", [[-(h + 50.0), 0], [-h, 0], [h, 0], [h + 50.0, 0]], 6.0)
	X.trunk("n_gate", [[0, -(h + 50.0)], [0, -h], [0, -h + 12.0], [side * 0.36, -h + 12.0]], 3.6)
	X.trunk("w_lane", [[-side * 0.25, 0], [-side * 0.25, h - 8.0]], 4.0)
	X.trunk("e_lane", [[side * 0.25, 0], [side * 0.25, h - 8.0]], 4.0)
	# 감영(관찰사 — 선화당·내아·포정문) : 가운데 북, 크게
	X.put("gamyeong", "landmark/gwana", { seed = X.seed + 1, width = 70.0, depth = 84.0 }, 0, -side * 0.24, 0.0, Vector2(72, 90), 2.0)
	X.put("gamyeong_hongsal", "bldg/gate", { type = "hongsal", seed = X.seed + 2 }, 0, zg - 2.0, 0.0, Vector2(4.4, 1.2), 0.3)
	X.put("gamyeong_hama", "bldg/stone", { kind = "bi", kind_bi = "hama", seed = X.seed + 3 }, -6.0, zg - 1.0, 0.0, Vector2(1.2, 1.0), 0.3, { flatten = false })
	X.put("gamyeong_court", "bldg/stone", { kind = "baksuk", w = 16.0, d = 10.0, seed = X.seed + 4 }, 0, zg - 8.0, 0.0, Vector2(16, 10), 0.3, { flatten = false })
	# 객사(서쪽) + 부영(동쪽, 작은 관아)
	X.put("gaeksa", "landmark/gaeksa", { seed = X.seed + 5, jeongdang_bays = 5 }, -side * 0.3, -side * 0.24, 0.0, Vector2(67.2, 14.0), 3.0)
	X.put("gaeksa_samun", "landmark/samun", { seed = X.seed + 6, kind = "outer", name = "객사" }, -side * 0.3, -side * 0.1, 0.0, Vector2(10.8, 5.6), 1.0)
	_court_wall(X, "gaeksa_wall", -side * 0.3, -side * 0.24 + 4.0, 76.0, side * 0.24 - 4.0 - side * 0.1 + 12.0, -side * 0.1, 11.0)
	X.put("buyeong", "landmark/hyeon_gwana", { seed = X.seed + 7 }, side * 0.32, -side * 0.24, 0.0, Vector2(38, 42), 2.0)
	X.put("hyangcheong", "bldg/building", { type = "gangdang", region = X.region, seed = X.seed + 8 }, side * 0.14, side * 0.09, PI, B.footprint({ type = "gangdang", region = X.region, seed = X.seed + 8 }), 2.0)
	X.put("yeongnicheong", "bldg/building", { type = "haengrang", region = X.region, cls = "official", seed = X.seed + 9 }, -side * 0.12, side * 0.09, PI, B.footprint({ type = "haengrang", region = X.region, cls = "official", seed = X.seed + 9 }), 2.0)
	_sachang(X, -side * 0.38, side * 0.32)
	_ok(X, side * 0.4, side * 0.36)
	_sandan(X, side, 1.2)
	_jangsi(X, side, 3, 100.0)
	X.trunk("out_ew", [[-side * 0.62, h + 20.0], [-side * 0.25, h + 22.0], [side * 0.25, h + 21.0], [side * 0.62, h + 20.0]], 4.0)
	X.trunk("out_ew2", [[-side * 0.6, h + 128.0], [0, h + 134.0], [side * 0.6, h + 126.0]], 3.4)
	for i in 12: X.put("bibo", "nature/pine", { seed = X.seed + 40 + i, s = 1.2 }, h + 20.0 + i * 5.0, h + 30.0 + (i % 2) * 4.0, 0.0, Vector2.ZERO, 0.0, { flatten = false })
	var i_ := h - 9.0
	# 북서(객사 둘레 중인) · 북동(양반 동네 — 관아 뒤 조용한 쪽) · 남(시전 거리 + 서민) · 성 밖 남(장시·서민) · 성 밖 서(초가 무리)
	X.district("in_nw", [[-i_, -i_], [-3.0, -i_], [-3.0, -3.0], [-i_, -3.0]], { table = T_GWAN, base_density = 0.6, trunk_shop = 0.2, centers = [{ c = X.Wa(-side * 0.25, 0), r = side * 0.4, w = 1.0 }] })
	X.district("in_ne", [[3.0, -i_], [i_, -i_], [i_, -3.0], [3.0, -3.0]], { table = T_YANGBAN, base_density = 0.5, centers = [{ c = X.Wa(side * 0.2, -side * 0.1), r = side * 0.4, w = 0.9 }] })
	X.district("in_s", [[-i_, 3.0], [i_, 3.0], [i_, i_], [-i_, i_]], { table = T_SIJEON, base_density = 0.55, trunk_shop = 0.65,
		centers = [{ c = X.Wa(0, 0), r = side * 0.5, w = 1.0 }, { c = X.Wa(0, h), r = side * 0.35, w = 1.0 }],
		plazas = [{ c = X.Wa(0, 5.0), r = 8.0, kind = "well" }, { c = X.Wa(0, h - 10.0), r = 8.0, kind = "gate" }] })
	X.district("out_s", [[-side * 0.62, h + 16.0], [side * 0.62, h + 16.0], [side * 0.62, h + 140.0], [-side * 0.62, h + 140.0]], { table = T_SEOMIN, base_density = 0.35, trunk_shop = 0.4,
		centers = [{ c = X.Wa(0, h + 50.0), r = 110.0, w = 0.9 }], empty_out = 0.12, plazas = [{ c = X.Wa(0, h + 22.0 + 50.0), r = 52.0, kind = "market" }] })

# 소도시(군·현급): 작은 읍성(또는 무성읍치) — 동헌(현 관아 일곽)이 북쪽 가운데, 객사가 그 서쪽, 짧은 남북 길 + 동서 길, 십자로 앞 5일장 마당
static func _town(X: Ctx) -> void:
	var side: float = float(X.cfg.get("side", TIERS.town.side)) * float(X.cfg.get("size", 1.0))
	var h := side / 2.0
	var walled: bool = bool(X.cfg.get("walled", true))
	if walled: _walls(X, side, false)
	X.trunk("ns", [[0, h + 90.0], [0, h], [0, -side * 0.08]], 4.0)
	X.trunk("ew", [[-(h + 40.0), side * 0.12], [-h, side * 0.12], [h, side * 0.12], [h + 40.0, side * 0.12]], 4.0)
	X.put("gwana", "landmark/hyeon_gwana", { seed = X.seed + 1 }, side * 0.12, -side * 0.24, 0.0, Vector2(38, 42), 2.0)
	X.put("gwana_hongsal", "bldg/gate", { type = "hongsal", seed = X.seed + 2 }, side * 0.12, -side * 0.24 + 25.0, 0.0, Vector2(4.4, 1.2), 0.3)
	var gp := { type = "gaeksa", region = X.region, seed = X.seed + 3 }
	X.put("gaeksa", "bldg/building", gp, -side * 0.24, -side * 0.24, 0.0, B.footprint(gp), 2.0)
	_sachang(X, -side * 0.26, side * 0.32)
	_sandan(X, side, 0.7)
	# 5일장: 십자로 남쪽 길가 좌판 + 주막
	var k := 0
	for sx in [-1.0, 1.0]:
		var z := side * 0.16
		while z < h - 4.0:
			X.put("jwapan", "village/jwapan", { seed = X.seed * 100 + k, goods = ["grain", "onggi", "straw", "cloth"][k % 4], awning = k % 2 == 0 }, sx * 4.6, z, PI / 2 * sx, Vector2(2.4, 1.6), 0.2, { flatten = false })
			z += 4.2; k += 1
	X.trunk("out_ew", [[-side * 0.7, h + 18.0], [0, h + 20.0], [side * 0.7, h + 18.0]], 3.4)
	var i_ := h - (9.0 if walled else 0.0)
	X.district("in", [[-i_, -i_], [i_, -i_], [i_, i_], [-i_, i_]], { table = T_SIJEON if not walled else T_GWAN, base_density = 0.45, trunk_shop = 0.35,
		centers = [{ c = X.Wa(0, side * 0.12), r = side * 0.6, w = 1.0 }], plazas = [{ c = X.Wa(0, side * 0.12), r = 6.0, kind = "well" }] })
	X.district("out_s", [[-side * 0.7, h + 14.0], [side * 0.7, h + 14.0], [side * 0.7, h + 90.0], [-side * 0.7, h + 90.0]], { table = T_SEOMIN, base_density = 0.2, empty_out = 0.18,
		centers = [{ c = X.Wa(0, h + 20.0), r = 70.0, w = 0.7 }] })

# 마을: 반촌(종가 위·사당·서당·정자, 아래 민가) · 민촌 · 산촌(비탈 축대·너와) · 역촌(역·원·마방이 큰길가)
static func _village(X: Ctx, kind: String) -> void:
	var R: float = 85.0 * float(X.cfg.get("size", 1.0))
	# 어귀(앞, +z) → 마을 길(조금 굽음) → 뒤(진산 쪽)
	X.trunk("main", [[0, R + 40.0], [6.0, R * 0.6], [-4.0, R * 0.2], [3.0, -R * 0.25], [0, -R * 0.55]], 3.6)
	# 어귀: 장승 한 쌍 · 솟대 · 당산나무 마당 · 마을숲(수구막이 소나무 줄)
	X.put("jangseung_l", "village/jangseung", { seed = X.seed }, -3.2, R + 22.0, PI / 2, Vector2(1, 1), 0.2, { flatten = false })
	X.put("jangseung_r", "village/jangseung", { seed = X.seed + 1, female = true }, 3.2, R + 22.0, -PI / 2, Vector2(1, 1), 0.2, { flatten = false })
	X.put("sotdae", "village/sotdae", { seed = X.seed + 2 }, 6.0, R + 25.0, 0.0, Vector2(1, 1), 0.2, { flatten = false })
	X.put("dangsan", "village/village_square", { seed = X.seed + 3, tree = "nature" }, -14.0, R + 8.0, 0.0, Vector2(8, 7.6), 1.0)
	for i in 10: X.put("forest", "nature/pine", { seed = X.seed + 30 + i, s = 1.2 }, -R * 0.8 + i * (R * 1.6 / 9.0), R + 32.0 + (i % 3) * 3.0, 0.0, Vector2.ZERO, 0.0, { flatten = false })
	X.put("seonghwangdang", "village/seonghwangdang", { seed = X.seed + 4 }, 10.0, -R * 0.75, 0.0, Vector2(4, 4), 0.5, { flatten = false })
	X.put("well", "village/well", { seed = X.seed + 5, roof = true }, 9.0, R * 0.35, 0.0, Vector2(2.4, 2.4), 0.3, { flatten = false })
	var area := [[-R, -R * 0.75], [R, -R * 0.75], [R * 1.05, R * 0.2], [R * 0.7, R], [-R * 0.7, R], [-R * 1.05, R * 0.2]]
	match kind:
		"banchon":
			# 종가(대종가 양반가 — 뒤 높은 곳 가운데, 사당은 묶음 안 뒤뜰) · 서당 · 정자(어귀 물가·언덕) · 그 아래 양반·민가
			var jp := { type = "yangban", region = X.region, seed = X.seed + 7 }
			X.put("jongga", "bldg/compound", jp, 0, -R * 0.45, 0.0, CP.footprint(jp), 2.0)
			var sp := { type = "sarang", region = X.region, cls = "yangban", seed = X.seed + 8 }
			X.put("seodang", "bldg/building", sp, R * 0.55, -R * 0.2, -0.3, B.footprint(sp), 2.0)
			X.put("jeongja", "village/jeongja", { seed = X.seed + 9 }, -R * 0.55, R * 0.7, 0.4, Vector2(6, 6), 1.0)
			X.district("upper", [[-R, -R * 0.75], [R, -R * 0.75], [R * 1.05, 0.0], [-R * 1.05, 0.0]], { table = T_YANGBAN, base_density = 0.45, centers = [{ c = X.Wa(0, -R * 0.45), r = R, w = 0.9 }] })
			X.district("lower", [[-R * 1.05, 4.0], [R * 1.05, 4.0], [R * 0.7, R], [-R * 0.7, R]], { table = T_MINCHON, base_density = 0.3, empty_out = 0.15, centers = [{ c = X.Wa(0, R * 0.5), r = R, w = 0.7 }] })
		"sanchon":
			X.district("all", area, { table = T_MINCHON, base_density = 0.2, region = "mountain", empty_out = 0.2, centers = [{ c = X.Wa(0, 0), r = R, w = 0.6 }],
				branch = { gap_a = 18.0, gap_b = 30.0, p = 0.9, len_a = 25.0, len_b = 60.0, alley_gap_a = 14.0, alley_gap_b = 22.0, alley_p = 0.6 } })
		"yeokchon":
			# 역(마방·역사 — 큰길가) · 원(길손 묵는 집 = 주막) — 큰길이 마을을 가로지름
			X.put("yeok", "bldg/building", { type = "haengrang", region = X.region, cls = "official", seed = X.seed + 10 }, 14.0, R * 0.1, -PI / 2, B.footprint({ type = "haengrang", region = X.region, cls = "official", seed = X.seed + 10 }), 2.0)
			X.put("mabang", "bldg/building", { type = "araechae", region = X.region, seed = X.seed + 11 }, 15.0, -R * 0.15, -PI / 2, B.footprint({ type = "araechae", region = X.region, seed = X.seed + 11 }), 2.0)
			var wp := { type = "jumak_yard", region = X.region, seed = X.seed + 12 }
			X.put("won", "bldg/compound", wp, -16.0, R * 0.25, PI / 2, CP.footprint(wp), 1.5)
			X.district("all", area, { table = T_MINCHON, base_density = 0.35, trunk_shop = 0.3, centers = [{ c = X.Wa(0, 0), r = R, w = 0.8 }] })
		_:
			X.district("all", area, { table = T_MINCHON, base_density = 0.35, centers = [{ c = X.Wa(0, R * 0.3), r = R, w = 0.8 }] })

# 마당 담(객사·향교 둘레): 가운데 (cx, cz), 너비 w, 깊이 d, 앞(+z) 줄 z_front에 문 자리 ±gap/2
static func _court_wall(X: Ctx, tag: String, cx: float, cz: float, w: float, d: float, z_front: float, gap: float) -> void:
	var x0 := cx - w / 2; var x1 := cx + w / 2; var z0 := z_front - d; var z1 := z_front
	var segs := [[x0, z0, x1, z0], [x0, z0, x0, z1], [x1, z0, x1, z1], [x0, z1, cx - gap / 2, z1], [cx + gap / 2, z1, x1, z1]]
	var pieces := []
	var i := 0
	for s in segs:
		var a: Vector2 = X.W(s[0], s[1]) - X.W(cx, (z0 + z1) / 2); var b: Vector2 = X.W(s[2], s[3]) - X.W(cx, (z0 + z1) / 2)
		var la := _rot(a, -X.ry); var lb := _rot(b, -X.ry)
		pieces.append({ tag = "w%d" % i, kit = "village/todam", params = { seed = X.seed + 300 + i, ax = snappedf(la.x, 0.01), az = snappedf(la.y, 0.01), bx = snappedf(lb.x, 0.01), bz = snappedf(lb.y, 0.01), h = 2.2, cap = "tile", tile_seg = 0.5 }, x = 0.0, z = 0.0, ry = 0.0 })
		i += 1
	CP._join_walls(pieces)
	X.put(tag, "bldg/lot", { type = "court_wall", seed = X.seed, fp = [w, d], pieces = pieces }, cx, (z0 + z1) / 2, 0.0, Vector2.ZERO, 0.0, { flatten = false, yard = false })

# 사창(환곡 곳간 셋 + 기와 갓 담 + 평대문)
static func _sachang(X: Ctx, cx: float, cz: float) -> void:
	var pieces := []
	var g := { type = "gotgan", region = X.region, cls = "official", seed = X.seed + 50 }
	var gb := B.bounds(S.resolve(g))
	pieces.append({ tag = "chang0", kit = "bldg/building", params = g, x = 0.0, z = -6.0, ry = 0.0 })
	pieces.append({ tag = "chang1", kit = "bldg/building", params = g.merged({ seed = X.seed + 51 }), x = -9.5, z = 1.0, ry = PI / 2 })
	pieces.append({ tag = "chang2", kit = "bldg/building", params = g.merged({ seed = X.seed + 52 }), x = 9.5, z = 1.0, ry = -PI / 2 })
	var hw := 14.0; var hd := 11.0
	var gp := { type = "pyeong", seed = X.seed + 53, wall_h = CP.WH_TILE }
	CP._enclose(pieces, X.seed + 54, -hw, hw, -hd, hd, "todam_tile", 0, 0, true)
	CP._front_gate(pieces, X.seed + 55, hw, hd, 0.0, gp, "todam_tile")
	CP._join_walls(pieces)
	X.put("sachang", "bldg/lot", { type = "sachang", seed = X.seed, fp = [hw * 2 + 1, hd * 2 + 1], pieces = pieces }, cx, cz, 0.0, Vector2(hw * 2 + 1, hd * 2 + 1), 2.0)

# 옥(원옥 — 둥근 담 안 옥사 한 채, 문 하나)
static func _ok(X: Ctx, cx: float, cz: float) -> void:
	var pieces := []
	var r := 9.0
	var n := 14
	var gap_a := PI / 2   # 앞(+z)
	for i in n:
		var a0 := TAU * i / n; var a1 := TAU * (i + 1) / n
		var mid := (a0 + a1) / 2.0
		if absf(wrapf(mid - gap_a, -PI, PI)) < PI / n: continue
		pieces.append({ tag = "ow%d" % i, kit = "village/stone_wall", params = { seed = X.seed + 70 + i, ax = snappedf(cos(a0) * r, 0.01), az = snappedf(sin(a0) * r, 0.01), bx = snappedf(cos(a1) * r * 1.0, 0.01), bz = snappedf(sin(a1) * r, 0.01), h = 2.4, lite = true }, x = 0.0, z = 0.0, ry = 0.0 })
	pieces.append({ tag = "oksa", kit = "bldg/building", params = { type = "gotgan", region = X.region, cls = "official", seed = X.seed + 90 }, x = 0.0, z = -2.0, ry = 0.0 })
	pieces.append({ tag = "gate", kit = "bldg/gate", params = { type = "ilgak", seed = X.seed + 91, wall_h = 2.4 }, x = 0.0, z = r, ry = 0.0 })
	X.put("ok", "bldg/lot", { type = "ok", seed = X.seed, fp = [r * 2 + 1, r * 2 + 1], pieces = pieces }, cx, cz, 0.0, Vector2(r * 2 + 1, r * 2 + 1), 2.0)
