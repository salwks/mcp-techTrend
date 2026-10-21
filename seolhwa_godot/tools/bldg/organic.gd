# 고을 짜임 다시 짜기(town-organic) — 구역 설정(DISTRICTS) → kit/bldg/organic.gd → region_data/JL_NAMWON_UNBONG/placement_namwon_town.json
#   godot --headless --path . -s res://tools/bldg/organic.gd -- --district=west [--seed=N] [--dry] [--revert]
#   · 원본 배치(placement_namwon.json — namwon.py 생성물)는 고치지 않는다. 이 파일 머리 "supersede"에 구역 안 옛 집·마당 것 id를 적어 로더가 빼게 한다.
#     되돌리기: --revert(구역 하나) 또는 이 파일을 지운다.
#   · 구역 밖·이야기 자리·남기는 것(좌판·옛 다리 등)은 keep(비울 자리)로 넘겨 그 둘레에 필지를 두지 않는다.
#   · 땅: 지금 height.png로 길 굽음(등고선 따라)만 본다. 필지는 터 고르기(flatten)로 앉으므로 지형 담당이 땅을 바꿔도 다시 돌리면 된다.
extends SceneTree
const OG := preload("res://kit/bldg/organic.gd")

const DIR := "res://region_data/JL_NAMWON_UNBONG/"
const OUT := "res://region_data/JL_NAMWON_UNBONG/placement_namwon_town.json"
# 옛 배치에서 갈음할 것(집·마당 것) — 좌판·다리·장승·이야기 것은 남긴다
const REPLACE_KITS := ["village/choga", "village/house_compound", "village/giwa", "bldg/compound", "bldg/building", "village/yard_props", "village/haystack",
	"village/teotbat", "nature/garden_plot", "village/wall_run", "village/jige", "village/well", "village/firewood", "village/props", "village/jumak", "village/market_shop"]

const DISTRICTS := {
	# 서문 밖 장터길 민가 구역(building-rollout-1 west 자리) — 동쪽 = 장터길(읍성 서벽 앞), 서쪽 = 개울 r055, 가운데를 성황사 오솔길이 지난다
	west = {
		seed = 1873, prefix = "orgw", group = "남원 서문 밖(고을 짜임)", region = "south",
		area = [[-3341, 200], [-3341, 359], [-3460, 368], [-3445, 345], [-3434, 320], [-3424, 300], [-3410, 285], [-3410, 262], [-3428, 249], [-3428, 230], [-3405, 200]],
		trunk_ids = { namwon_market_lane = 3.6, namwon_west_gate_lane = 3.6, path_namwon_seonghwangsa = 3.0 },
		plazas = [{ c = [-3349, 246], r = 7.5, kind = "gate" }, { c = [-3350, 291], r = 6.0, kind = "well" }],
		centers = [{ c = [-3342, 246], r = 75.0, w = 1.0 }, { c = [-3342, 300], r = 55.0, w = 0.8 }],
		base_density = 0.12,
		branch = { gap_a = 38.0, gap_b = 56.0, p = 0.9, len_a = 40.0, len_b = 95.0, alley_gap_a = 26.0, alley_gap_b = 40.0, alley_p = 0.45 },
		street_spacing = 40.0, alley_spacing = 22.0,
		# 성 밖 초가 무리(참고: ACON 2203 #1 서문·남문 밖 초가 덩이): 마당집으로 촘촘히, 빈 땅은 밭
		inner_inset = 0.6, court_gap = 0.6, block_front = [15.0, 20.0], trunk_shop = 0.3, partial_walls = 0.25,
		junction_plaza_p = 0.35, empty_out = 0.12, empty_in = 0.02,
	},
	# 읍성 안 남쪽 절반(남문 ↔ 십자로, 서문 ↔ 동문 사이) — 옛 배치는 바둑판 줄(house_compound·giwa·choga). 북쪽 객사·관아(이야기 자리)는 그대로
	eup = {
		seed = 1877, prefix = "orge", group = "남원 읍성 안 남쪽(고을 짜임)", region = "south",
		area = [[-3315, 253], [-3140, 253], [-3140, 336], [-3315, 336]],
		trunk_ids = { namwon_eup_street = 5.0, namwon_eup_street_ew = 5.0 },
		# 성 안 둘레길(순성로 — 성벽 안쪽을 도는 길): 남·서·동 안쪽
		extra_trunks = [{ id = "inner_ring_s", w = 3.4, pts = [[-3312, 333], [-3270, 333.5], [-3232, 333], [-3223, 333], [-3185, 333.5], [-3143, 333]] },
			{ id = "inner_ring_w", w = 3.0, pts = [[-3312, 333], [-3312.5, 295], [-3312, 255]] },
			{ id = "inner_ring_e", w = 3.0, pts = [[-3143, 333], [-3143.5, 295], [-3143, 255]] }],
		plazas = [{ c = [-3227.8, 331], r = 8.0, kind = "gate" }, { c = [-3227.8, 256], r = 6.5, kind = "well" }],
		centers = [{ c = [-3227.8, 300], r = 70.0, w = 1.0 }, { c = [-3227.8, 252], r = 60.0, w = 1.0 }],
		base_density = 0.45,
		branch = { gap_a = 36.0, gap_b = 52.0, p = 0.95, len_a = 30.0, len_b = 80.0, alley_gap_a = 24.0, alley_gap_b = 36.0, alley_p = 0.4 },
		street_spacing = 42.0, alley_spacing = 22.0,
		junction_plaza_p = 0.3, empty_out = 0.05, empty_in = 0.0,
		# 성 안: 촘촘하게 — 마당 흙(urban), 빈터 나무 적게, 한 필지에 곁채 여럿(낙안읍성 필지 실측: 집마다 헛간채·아래채·가게채 2~4채)
		urban = true, trees = 0.12, extras_ratio = 0.55, extras_max = 4, front_in = [11.5, 15.0], depth_in = [28.0, 40.0], lot_gap = [0.4, 0.8], inner_inset = 0.45, court_gap = 0.5, trunk_shop = 0.55, front_yard = [3.4, 5.5], extras_gap = 0.9,
		# 문헌 규칙으로 더하는 공해(settlement-rules.md §2): 향청·작청은 관아(외삼문 −3162, 239.5) 앞 동서대로 건너에서 관아를 봄, 사창은 성 안 서남, 관아 앞 하마비
		majors = [
			{ tag = "hyangcheong", kit = "bldg/building", params = { type = "gangdang", region = "south", seed = 1874 }, at = [-3184.0, 262.0], ry = PI, fp = true },
			{ tag = "jakcheong", kit = "bldg/building", params = { type = "haengrang", region = "south", cls = "official", seed = 1875 }, at = [-3157.5, 262.0], ry = PI, fp = true },
			{ tag = "hama", kit = "bldg/stone", params = { kind = "bi", kind_bi = "hama", seed = 1876 }, at = [-3171.5, 243.6], ry = 0.0, fp = false },
		],
		table = {
			"dense": [["house_g", 0.3], ["giwa_house", 0.18], ["yangban", 0.08], ["house_c", 0.2], ["choga_house", 0.08], ["shop", 0.16]],
			"mid": [["house_g", 0.22], ["giwa_house", 0.14], ["yangban", 0.06], ["house_c", 0.3], ["choga_house", 0.2], ["jungnong", 0.08]],
			"outer": [["house_c", 0.4], ["choga_house", 0.35], ["house_g", 0.15], ["jungnong", 0.1]],
		},
	},
}

func _initialize() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1); args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var dname: String = args.get("district", "west")
	var D: Dictionary = (DISTRICTS[dname] as Dictionary).duplicate(true)
	if args.has("seed"): D.seed = int(args.seed)
	var reg = JSON.parse_string(FileAccess.get_file_as_string(DIR + "region.json"))
	# 기존 town 파일
	var out: Dictionary = { area = "namwon", generator = "tools/bldg/organic.gd (kit/bldg/organic.gd)", note = "고을 짜임(town-organic): 길 먼저 → 길 따라 필지 → 필지 따라 집·담. 구역별 다시 짜기, supersede로 옛 항목을 뺀다. docs/reports/town-organic.md", districts = {}, supersede = [], alleys = [], items = [] }
	if FileAccess.file_exists(OUT):
		var o = JSON.parse_string(FileAccess.get_file_as_string(OUT))
		if o is Dictionary: out = o
	# 이 구역 것 지우기(다시 짜기·되돌리기 공통)
	var pre: String = D.prefix
	var old_d: Dictionary = (out.districts as Dictionary).get(dname, {})
	var old_sup: Array = old_d.get("supersede", [])
	out.items = (out.items as Array).filter(func(it): return not String(it.id).begins_with(pre + "_"))
	out.alleys = (out.alleys as Array).filter(func(al): return not String(al.get("id", "")).begins_with(pre + "_"))
	out.supersede = (out.supersede as Array).filter(func(s): return not old_sup.has(s))
	var old_urb: Array = old_d.get("urban", [])
	if out.has("urban"): out.urban = (out.urban as Array).filter(func(u): return not old_urb.has(u))
	(out.districts as Dictionary).erase(dname)
	if args.has("revert"):
		_save(out); print("ORGANIC revert district=%s" % dname); quit(); return
	var area := []
	for p in D.area: area.append(Vector2(float(p[0]), float(p[1])))
	# 옛 항목: 구역 안 집·마당 것 → supersede, 나머지(좌판 등) → keep
	var sup := []
	var keep := []
	var keep_rects := []
	var da := DirAccess.open(DIR)
	for f in da.get_files():
		if not (f.begins_with("placement_") and f.ends_with(".json")) or f == OUT.get_file(): continue
		var d = JSON.parse_string(FileAccess.get_file_as_string(DIR + f))
		if not (d is Dictionary): continue
		var story := f.begins_with("placement_story_") or f.begins_with("placement_stations")
		for it in d.get("items", []):
			var p := Vector2(float(it.x), float(it.z))
			var inside := OG.pip(area, p)
			var near := inside
			if not inside:
				for i in area.size():
					if OG.seg_dist(p, area[i], area[(i + 1) % area.size()]) < 12.0: near = true; break
			if not near: continue
			if inside and not story and String(it.kit) in REPLACE_KITS: sup.append(String(it.id)); continue
			var rr := 2.0
			if it.get("footprint") is Array and not story:
				# 바닥 크기가 있는 항목은 돌린 사각(+1m)으로 비운다 — 원(대각 반지름)은 길 건너 필지까지 막았다
				var fw := Vector2(float(it.footprint[0]), float(it.footprint[1])) / 2 + Vector2(1, 1)
				var iry := float(it.get("ry", 0.0))
				var kp := []
				for q in [Vector2(-fw.x, -fw.y), Vector2(fw.x, -fw.y), Vector2(fw.x, fw.y), Vector2(-fw.x, fw.y)]:
					kp.append([p.x + q.x * cos(iry) + q.y * sin(iry), p.y - q.x * sin(iry) + q.y * cos(iry)])
				keep_rects.append(kp)
				continue
			if String(it.kit) == "village/jwapan": rr = 1.6
			if story: rr = maxf(rr, 4.0)
			keep.append({ c = [p.x, p.y], r = rr, id = String(it.id) })
	D.keep = keep
	# 고정 큰길: region roads에서 구역 둘레 40m 안 마디만
	var trunks := []
	for rd in reg.roads:
		if not (D.trunk_ids as Dictionary).has(String(rd.id)): continue
		var pts := []
		for p in rd.points:
			var v := Vector2(float(p[0]), float(p[1]))
			var close := OG.pip(area, v)
			if not close:
				for i in area.size():
					if OG.seg_dist(v, area[i], area[(i + 1) % area.size()]) < 40.0: close = true; break
			if close: pts.append([v.x, v.y])
			elif not pts.is_empty(): break
		if pts.size() >= 2: trunks.append({ id = String(rd.id), pts = pts, w = float(D.trunk_ids[rd.id]) })
	# 구역 설정의 새 큰길(성 안 둘레길 등 — region 길에 없는 것): 큰길로 두고 고샅처럼 칠한다
	for et in D.get("extra_trunks", []): trunks.append({ id = String(et.id), pts = et.pts, w = float(et.w), paint = true })
	D.trunks = trunks
	var rivers := []
	for rv in reg.rivers:
		var pts := []
		for p in rv.points: pts.append([float(p[0]), float(p[1])])
		rivers.append({ pts = pts, w = float(rv.get("width_m", 5.0)) })
	D.rivers = rivers
	# 높이
	var hm: Dictionary = reg.height
	var himg := Image.load_from_file(ProjectSettings.globalize_path(DIR + String(hm.file)))
	var hfn := func(x: float, z: float) -> float:
		var i := clampi(int(round((x - float(hm.x0)) / float(hm.cell))), 0, himg.get_width() - 1)
		var j := clampi(int(round((z - float(hm.z0)) / float(hm.cell))), 0, himg.get_height() - 1)
		return float(hm.y_min) + himg.get_pixel(i, j).r * (float(hm.y_max) - float(hm.y_min))
	# 큰 건물(문헌 규칙 공해 — majors): 먼저 놓고 그 자리를 비운다(keep_poly)
	var major_items := []
	var kpoly := []
	for mj in D.get("majors", []):
		var c := Vector2(float(mj.at[0]), float(mj.at[1])); var ry := float(mj.ry)
		var it := { id = "%s_%s" % [pre, String(mj.tag)], kit = mj.kit, params = mj.params, x = c.x, z = c.y, ry = snappedf(ry, 0.0001), y = null, flatten = bool(mj.fp), clear_veg = true, group = D.group, settlement = { role = mj.tag } }
		if bool(mj.fp):
			var bb: Rect2 = preload("res://kit/bldg/building.gd").bounds(preload("res://kit/bldg/_spec.gd").resolve(mj.params))
			it.footprint = [snappedf(bb.size.x, 0.1), snappedf(bb.size.y, 0.1)]
			var poly := []
			for q in [bb.position, Vector2(bb.end.x, bb.position.y), bb.end, Vector2(bb.position.x, bb.end.y)]:
				var g2: Vector2 = (q as Vector2) + (q - bb.get_center()).normalized() * 2.0
				poly.append([c.x + g2.x * cos(ry) + g2.y * sin(ry), c.y - g2.x * sin(ry) + g2.y * cos(ry)])
			kpoly.append(poly)
		major_items.append(it)
	D.keep_poly = kpoly + keep_rects
	var t0 := Time.get_ticks_msec()
	var g := OG.new(D, hfn)
	var res := g.run()
	for l in res.log: print("ORGANIC ", l)
	var ns := { trunk = 0, street = 0, alley = 0 }
	for s in res.streets: ns[s.kind] += 1
	print("ORGANIC streets trunk=%d street=%d alley=%d plazas=%d lots=%d items=%d supersede=%d keep=%d ms=%d" % [ns.trunk, ns.street, ns.alley, res.plazas.size(), res.lots.size(), res.items.size(), sup.size(), keep.size(), Time.get_ticks_msec() - t0])
	var tc := {}
	for it in res.items:
		if String(it.kit) == "bldg/lot": tc[String(it.params.type)] = int(tc.get(String(it.params.type), 0)) + 1
	print("ORGANIC types ", tc)
	var al := []
	for a in res.alleys:
		a.id = pre + "_" + String(a.id)
		al.append(a)
	# 큰길 중 좁은 산길(오솔길)은 고을 안에서 넓혀 칠한다
	for t in trunks:
		if t.get("paint", false):
			al.append({ id = pre + "_" + String(t.id), points = t.pts, width_m = float(t.w) - 0.6, kind = "street" }); continue
		if float(t.w) > 2.0 and String(t.id).begins_with("path_"):
			var pts := []
			for p in t.pts:
				if OG.pip(area, Vector2(float(p[0]), float(p[1]))): pts.append(p)
			if pts.size() >= 2: al.append({ id = pre + "_" + String(t.id), points = pts, width_m = float(t.w), kind = "street" })
	out.items.append_array(major_items)
	out.items.append_array(res.items)
	out.alleys.append_array(al)
	out.supersede.append_array(sup)
	var plz := []
	for pz in res.plazas: plz.append({ c = [snappedf(pz.c.x, 0.01), snappedf(pz.c.y, 0.01)], r = snappedf(float(pz.r), 0.01), kind = pz.kind })
	var urb := []
	if D.get("urban", false):
		var ab := OG._bbox(area)
		urb = [[snappedf(ab.position.x, 0.1), snappedf(ab.position.y, 0.1), snappedf(ab.end.x, 0.1), snappedf(ab.end.y, 0.1)]]
	if not out.has("urban"): out.urban = []
	out.urban.append_array(urb)
	out.districts[dname] = { seed = int(D.seed), area = D.area, supersede = sup, plazas = plz, lots = res.lots.size(), items = res.items.size(), urban = urb }
	if not args.has("dry"): _save(out)
	print("ORGANIC done district=%s%s" % [dname, " (dry)" if args.has("dry") else ""])
	quit()

func _save(out: Dictionary) -> void:
	var f := FileAccess.open(ProjectSettings.globalize_path(OUT), FileAccess.WRITE)
	f.store_string(JSON.stringify(out, " ", false))
	f.close()
