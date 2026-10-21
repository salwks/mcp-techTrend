# 도시·마을 빌더 견본(등급마다 하나) — kit/bldg/settlement.gd로 짓고 시험 배치 폴더(shots/town_organic/_place_<이름>/)에 쓴다.
#   godot --headless --path . -s res://tools/bldg/settlement_place.gd -- [--only=metro,city,…]
#   견본은 세계 배치(region_data)를 바꾸지 않는다. 게임에서 볼 때: --placedir=res://shots/town_organic/_place_<이름>/ (+ 그 자리 옛 항목은 supersede로 뺀다)
#   점검 시점(tools/bldg/town_views.json sets.<이름>): 내려다보기 · 참고 그림 각 · 마을 카메라(큰길) · 1인칭 · 큰길·갈래길 걷기 · 필지 대문 걷기
extends SceneTree
const ST := preload("res://kit/bldg/settlement.gd")
const OG := preload("res://kit/bldg/organic.gd")
const DIR := "res://region_data/JL_NAMWON_UNBONG/"

# 자리: 성곽 등급(대·중·소도시)은 물 없는 완만한 비탈 터(-3490, 950 — 남원 남쪽 구릉, 높이 12~27m, 물길 없음 360×400m) — 남원 분지 평지는 어디나 개울·강이 지나 성벽이 물을 건넌다.
#   마을: 민촌·역촌 평지 터(-3847, 600 — 개울 곁, 필지는 물을 비킨다) · 반촌·산촌 비탈 터(-3067, 586 — 평균 기울기 17%)
const EX := {
	"metro": { tier = "metro", c = [-3490.0, 975.0], ry = 0.0, seed = 3001, label = "대도시(감영급) 견본" },
	"city": { tier = "city", c = [-3490.0, 950.0], ry = 0.0, seed = 3002, label = "중도시(목·부급) 견본" },
	"town": { tier = "town", c = [-3490.0, 940.0], ry = 0.0, seed = 3003, walled = true, label = "소도시(군·현급, 작은 읍성) 견본" },
	"town_open": { tier = "town", c = [-3490.0, 940.0], ry = 0.25, seed = 3004, walled = false, label = "소도시(무성읍치) 견본" },
	"minchon": { tier = "village", kind = "minchon", c = [-3847.0, 600.0], ry = -0.4, seed = 3005, label = "민촌 견본" },
	"yeokchon": { tier = "village", kind = "yeokchon", c = [-3847.0, 600.0], ry = 0.3, seed = 3006, label = "역촌 견본" },
	"banchon": { tier = "village", kind = "banchon", c = [-3067.0, 586.0], ry = 0.0, seed = 3007, label = "반촌(비탈) 견본" },
	"sanchon": { tier = "village", kind = "sanchon", c = [-3067.0, 586.0], ry = 0.0, seed = 3008, label = "산촌(비탈·축대) 견본" },
}

func _initialize() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1); args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var only: PackedStringArray = String(args.get("only", "")).split(",", false)
	var reg = JSON.parse_string(FileAccess.get_file_as_string(DIR + "region.json"))
	var hm: Dictionary = reg.height
	var himg := Image.load_from_file(ProjectSettings.globalize_path(DIR + String(hm.file)))
	var hfn := func(x: float, z: float) -> float:
		var i := clampi(int(round((x - float(hm.x0)) / float(hm.cell))), 0, himg.get_width() - 1)
		var j := clampi(int(round((z - float(hm.z0)) / float(hm.cell))), 0, himg.get_height() - 1)
		return float(hm.y_min) + himg.get_pixel(i, j).r * (float(hm.y_max) - float(hm.y_min))
	var rivers := []
	for rv in reg.rivers:
		var pts := []
		for p in rv.points: pts.append([float(p[0]), float(p[1])])
		rivers.append({ pts = pts, w = float(rv.get("width_m", 5.0)) })
	# 세계 배치 항목(견본 자리에 있으면 supersede로 뺀다)
	var world_items := []
	for f in DirAccess.get_files_at(DIR):
		if f.begins_with("placement_") and f.ends_with(".json"):
			var d = JSON.parse_string(FileAccess.get_file_as_string(DIR + f))
			if d is Dictionary:
				for it in d.get("items", []): world_items.append([String(it.get("id", "")), Vector2(float(it.x), float(it.z)), f.begins_with("placement_story")])
	var vpath := "res://tools/bldg/town_views.json"
	var V = JSON.parse_string(FileAccess.get_file_as_string(vpath))
	for name in EX:
		if not only.is_empty() and not only.has(name): continue
		var cfg: Dictionary = (EX[name] as Dictionary).duplicate(true)
		cfg.prefix = "st_" + name; cfg.group = "고을 빌더 견본 " + String(cfg.label)
		var t0 := Time.get_ticks_msec()
		var res := ST.build(cfg, hfn, rivers)
		var ms := Time.get_ticks_msec() - t0
		# 견본 둘레(항목 바운딩 + 20m) 안 세계 항목은 뺀다(이야기 항목은 빼지 않고 알린다)
		var bb := Rect2(Vector2(float(cfg.c[0]), float(cfg.c[1])), Vector2.ZERO)
		for it in res.items: bb = bb.expand(Vector2(float(it.x), float(it.z)))
		bb = bb.grow(20.0)
		var sup := []
		var story_hit := 0
		for w in world_items:
			if bb.has_point(w[1]):
				if w[2]: story_hit += 1
				else: sup.append(w[0])
		var out := "res://shots/town_organic/_place_%s/" % name
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
		var f := FileAccess.open(ProjectSettings.globalize_path(out + "placement_settle_%s.json" % name), FileAccess.WRITE)
		f.store_string(JSON.stringify({ note = "도시·마을 빌더 견본 " + String(cfg.label) + " — tools/bldg/settlement_place.gd", tier = res.tier, majors = res.majors, districts = res.districts, supersede = sup, alleys = res.alleys, items = res.items }, " ", false))
		f.close()
		var tc := {}
		for it in res.items:
			var k := String(it.kit) if String(it.kit) != "bldg/lot" else "lot:" + String(it.params.type)
			tc[k] = int(tc.get(k, 0)) + 1
		print("SETTLE %s %s items=%d majors=%d districts=%s supersede=%d story_in_box=%d ms=%d bbox=%s" % [name, res.label, res.items.size(), res.majors.size(), str(res.districts.map(func(d): return "%s:%d" % [d.id, d.lots])), sup.size(), story_hit, ms, str(bb)])
		print("SETTLE %s kinds %s" % [name, str(tc)])
		for l in res.log: if String(l).contains("필지 ") and String(l).contains("채움"): print("SETTLE %s %s" % [name, String(l).substr(0, 90)])
		V.sets[name] = _views(name, cfg, res, bb)
	var g := FileAccess.open(ProjectSettings.globalize_path(vpath), FileAccess.WRITE)
	g.store_string(JSON.stringify(V, " ", false)); g.close()
	quit()

func _views(name: String, cfg: Dictionary, res: Dictionary, bb: Rect2) -> Dictionary:
	var c := Vector2(float(cfg.c[0]), float(cfg.c[1]))
	var views := []
	var big := maxf(bb.size.x, bb.size.y)
	views.append({ id = "o1", label = "견본 내려다보기", mode = "over", x = c.x, z = c.y, dist = big * 0.9, pitch = 58, yaw = rad_to_deg(float(cfg.ry)) })
	views.append({ id = "o2", label = "높은 비스듬히(참고 그림 각 — 앞 동남에서)", mode = "over", x = c.x, z = c.y, dist = big * 0.75, pitch = 28, yaw = rad_to_deg(float(cfg.ry)) + 35.0 })
	views.append({ id = "o3", label = "앞(남)에서 비스듬히", mode = "over", x = c.x, z = c.y, dist = big * 0.7, pitch = 36, yaw = rad_to_deg(float(cfg.ry)) })
	var walks := []
	var k := 1
	var al: Array = res.alleys.duplicate()
	al.sort_custom(func(a, b): return (a.points as Array).size() > (b.points as Array).size())
	for a in al:
		var p: Array = a.points
		if p.size() < 3: continue
		if k <= 5:
			var m: Array = p[p.size() / 2]
			views.append({ id = "t%d" % k, label = "%s 가운데(마을 카메라)" % String(a.id), mode = "town", x = float(m[0]), z = float(m[1]) })
			if k <= 3:
				var q: Array = p[mini(p.size() - 1, p.size() / 2 + 1)]
				var yaw := rad_to_deg(atan2(float(q[0]) - float(m[0]), -(float(q[1]) - float(m[1]))))
				views.append({ id = "f%d" % k, label = "%s 1인칭" % String(a.id), mode = "fp", x = float(m[0]), z = float(m[1]), yaw = snappedf(yaw, 1), pitch = 3 })
			k += 1
		var pts := []
		var step := maxi(1, p.size() / 6)
		var i := 0
		while i < p.size():
			pts.append([snappedf(float(p[i][0]), 0.1), snappedf(float(p[i][1]), 0.1)]); i += step
		if (pts[pts.size() - 1] as Array) != [snappedf(float(p[p.size() - 1][0]), 0.1), snappedf(float(p[p.size() - 1][1]), 0.1)]: pts.append([snappedf(float(p[p.size() - 1][0]), 0.1), snappedf(float(p[p.size() - 1][1]), 0.1)])
		if walks.size() < 14: walks.append({ id = String(a.id).replace("st_" + name + "_", ""), label = String(a.id), pts = pts, shots = [] })
	return { label = "고을 빌더 견본 " + name, views = views, walks = walks,
		gates = { bbox = [bb.position.x, bb.position.y, bb.end.x, bb.end.y], file = "res://shots/town_organic/_place_%s/placement_settle_%s.json" % [name, name] } }
