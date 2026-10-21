# 고을 평면도(내려다본 배치 그림) — 헤드리스. 길·고샅·필지 담·건물 바닥·나무·이야기 자리를 한 장 PNG로.
#   godot --headless --path . -s res://tools/bldg/town_map.gd -- --bbox=-3480,140,-3100,460 --ppm=3 --out=shots/town_organic/map_before.png [--placedir=res://…/]
#   색: 기와 건물 짙은 회색 · 초가 금빛 · 너와 갈색 · 담 줄 밤색 · 대문 빨강 · 길(region roads) 흙빛 · 고샅(alleys) 옅은 흙빛 · 나무 초록 점
#       이야기 배치(placement_story_*) 자홍 테 · supersede로 빠진 옛 항목은 그리지 않는다(--ghost면 옅은 테로)
extends SceneTree
const CP := preload("res://kit/bldg/compound.gd")
const B := preload("res://kit/bldg/building.gd")
const S := preload("res://kit/bldg/_spec.gd")

var img: Image
var bb: Array
var ppm := 3.0

func _px(x: float, z: float) -> Vector2:
	return Vector2((x - bb[0]) * ppm, (z - bb[1]) * ppm)

func _dot(x: float, z: float, r: float, c: Color) -> void:
	var p := _px(x, z)
	var rp := maxf(1.0, r * ppm)
	for j in range(int(p.y - rp), int(p.y + rp) + 1):
		for i in range(int(p.x - rp), int(p.x + rp) + 1):
			if i < 0 or j < 0 or i >= img.get_width() or j >= img.get_height(): continue
			if Vector2(i, j).distance_to(p) <= rp: img.set_pixel(i, j, c)

func _line(a: Vector2, b: Vector2, w: float, c: Color) -> void:
	var pa := _px(a.x, a.y); var pb := _px(b.x, b.y)
	var hw := maxf(0.6, w * ppm / 2)
	var x0 := int(minf(pa.x, pb.x) - hw - 1); var x1 := int(maxf(pa.x, pb.x) + hw + 1)
	var y0 := int(minf(pa.y, pb.y) - hw - 1); var y1 := int(maxf(pa.y, pb.y) + hw + 1)
	var ab := pb - pa; var l2 := maxf(ab.length_squared(), 1e-6)
	for j in range(maxi(0, y0), mini(img.get_height(), y1 + 1)):
		for i in range(maxi(0, x0), mini(img.get_width(), x1 + 1)):
			var p := Vector2(i, j)
			var t := clampf((p - pa).dot(ab) / l2, 0, 1)
			if p.distance_to(pa + ab * t) <= hw: img.set_pixel(i, j, c)

# 돌린 사각(가운데 c, 반폭 h, 돌림 ry — 게임 규칙: 로컬 (x,z) → 월드 (x cos + z sin, −x sin + z cos))
func _rect(c: Vector2, h: Vector2, ry: float, fill: Color, edge: Color, only_edge := false) -> void:
	var cs := cos(ry); var sn := sin(ry)
	var pts := []
	for q in [Vector2(-h.x, -h.y), Vector2(h.x, -h.y), Vector2(h.x, h.y), Vector2(-h.x, h.y)]:
		pts.append(c + Vector2(q.x * cs + q.y * sn, -q.x * sn + q.y * cs))
	if not only_edge:
		var r := maxf(h.x, h.y) * 1.5
		var p0 := _px(c.x - r, c.y - r); var p1 := _px(c.x + r, c.y + r)
		for j in range(maxi(0, int(p0.y)), mini(img.get_height(), int(p1.y) + 1)):
			for i in range(maxi(0, int(p0.x)), mini(img.get_width(), int(p1.x) + 1)):
				var w := Vector2(bb[0] + (i + 0.5) / ppm, bb[1] + (j + 0.5) / ppm) - c
				var lx := w.x * cs - w.y * sn; var lz := w.x * sn + w.y * cs
				if absf(lx) <= h.x and absf(lz) <= h.y: img.set_pixel(i, j, fill)
	for k in 4: _line(pts[k], pts[(k + 1) % 4], 0.25, edge)

func _xf(c: Vector2, ry: float, l: Vector2) -> Vector2:
	return c + Vector2(l.x * cos(ry) + l.y * sin(ry), -l.x * sin(ry) + l.y * cos(ry))

func _roofcol(params: Dictionary) -> Color:
	var sp := S.resolve(params)
	match String(sp.roof.kind):
		"giwa": return Color(0.28, 0.29, 0.31)
		"neowa": return Color(0.45, 0.33, 0.22)
	return Color(0.86, 0.72, 0.38)

func _building(c: Vector2, ry: float, params: Dictionary) -> void:
	var sp := S.resolve(params)
	var b := B.bounds(sp)
	var lc := b.get_center()
	_rect(_xf(c, ry, lc), b.size / 2, ry, _roofcol(params), Color(0.1, 0.08, 0.06))
	# 앞(+z) 표시: 앞 처마 가운데 작은 점
	var f := _xf(c, ry, Vector2(lc.x, b.end.y - 0.4))
	_dot(f.x, f.y, 0.35, Color(0.9, 0.9, 0.85))

func _piece(c: Vector2, ry: float, e: Dictionary) -> void:
	var pc := _xf(c, ry, Vector2(float(e.x), float(e.z)))
	var pry := ry + float(e.get("ry", 0.0))
	var kit := String(e.kit)
	var p: Dictionary = e.params
	if kit == "bldg/building": _building(pc, pry, p); return
	if p.has("ax"):
		var a := _xf(pc, pry, Vector2(float(p.ax), float(p.az))); var b2 := _xf(pc, pry, Vector2(float(p.bx), float(p.bz)))
		var col := Color(0.42, 0.2, 0.12) if kit == "village/todam" else (Color(0.45, 0.45, 0.42) if kit == "village/stone_wall" else Color(0.55, 0.45, 0.3))
		_line(a, b2, 0.45 if kit != "village/fence" else 0.2, col); return
	if kit == "bldg/gate": _dot(pc.x, pc.y, 0.9, Color(0.85, 0.12, 0.1)); return
	if kit.begins_with("nature/"): _dot(pc.x, pc.y, float(p.get("s", 1.0)) * 1.8, Color(0.25, 0.5, 0.2)); return
	if kit == "village/well": _dot(pc.x, pc.y, 0.9, Color(0.2, 0.4, 0.8)); return
	_dot(pc.x, pc.y, 0.5, Color(0.5, 0.4, 0.3))

func _initialize() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1); args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	bb = []
	for s in String(args.get("bbox", "-3480,140,-3100,460")).split(","): bb.append(float(s))
	ppm = float(args.get("ppm", "3"))
	var dir := "res://region_data/JL_NAMWON_UNBONG/"
	var reg = JSON.parse_string(FileAccess.get_file_as_string(dir + "region.json"))
	var W := int((bb[2] - bb[0]) * ppm); var H := int((bb[3] - bb[1]) * ppm)
	img = Image.create(W, H, false, Image.FORMAT_RGB8)
	# 바탕: 높이 음영(1m 간격 등고 띠) + 땅 쓰임
	var hm: Dictionary = reg.height
	var himg := Image.load_from_file(ProjectSettings.globalize_path(dir + String(hm.file)))
	var hf := func(x: float, z: float) -> float:
		var i := clampi(int(round((x - float(hm.x0)) / float(hm.cell))), 0, himg.get_width() - 1)
		var j := clampi(int(round((z - float(hm.z0)) / float(hm.cell))), 0, himg.get_height() - 1)
		return float(hm.y_min) + himg.get_pixel(i, j).r * (float(hm.y_max) - float(hm.y_min))
	for j in H:
		for i in W:
			var x: float = bb[0] + (i + 0.5) / ppm; var z: float = bb[1] + (j + 0.5) / ppm
			var y: float = hf.call(x, z)
			var band := fmod(y, 2.0) < 0.12
			var sh: float = clampf((hf.call(x + 2.0, z) - hf.call(x - 2.0, z)) * 0.08 - (hf.call(x, z + 2.0) - hf.call(x, z - 2.0)) * 0.08, -0.15, 0.15)
			var c := Color(0.80, 0.84, 0.70).lightened(sh) if not band else Color(0.6, 0.65, 0.55)
			img.set_pixel(i, j, c)
	for rv in reg.get("rivers", []):
		var pts: Array = rv.get("points", [])
		for k in pts.size() - 1: _line(Vector2(pts[k][0], pts[k][1]), Vector2(pts[k + 1][0], pts[k + 1][1]), float(rv.get("width_m", 8.0)), Color(0.55, 0.7, 0.85))
	for rd in reg.get("roads", []):
		var pts: Array = rd.get("points", [])
		for k in pts.size() - 1: _line(Vector2(pts[k][0], pts[k][1]), Vector2(pts[k + 1][0], pts[k + 1][1]), float(rd.get("width_m", 3.0)), Color(0.78, 0.66, 0.48))
	var files := []
	var dirs := [dir]
	if args.has("placedir"): dirs.append(String(args.placedir))
	for d in dirs:
		var da := DirAccess.open(d)
		if da == null: continue
		for f in da.get_files():
			if f.begins_with("placement_") and f.ends_with(".json"): files.append(d.path_join(f))
	var datas := []
	var sup := {}
	for f in files:
		var d = JSON.parse_string(FileAccess.get_file_as_string(f))
		if not (d is Dictionary): continue
		datas.append([f, d])
		for s in d.get("supersede", []): sup[String(s)] = true
		for al in d.get("alleys", []):
			var pts: Array = al.get("points", [])
			for k in pts.size() - 1: _line(Vector2(pts[k][0], pts[k][1]), Vector2(pts[k + 1][0], pts[k + 1][1]), float(al.get("width_m", 3.0)), Color(0.86, 0.76, 0.58))
	for fd in datas:
		var story := String(fd[0]).get_file().begins_with("placement_story_")
		for it in fd[1].items:
			if not (it is Dictionary) or not it.has("kit"): continue
			var x := float(it.x); var z := float(it.z)
			if x < bb[0] - 40 or x > bb[2] + 40 or z < bb[1] - 40 or z > bb[3] + 40: continue
			var c := Vector2(x, z); var ry := float(it.get("ry", 0.0))
			if sup.has(String(it.get("id", ""))):
				if args.has("ghost") and it.get("footprint") is Array: _rect(c, Vector2(float(it.footprint[0]), float(it.footprint[1])) / 2, ry, Color(), Color(0.6, 0.55, 0.5), true)
				continue
			var kit := String(it.kit)
			if kit == "bldg/compound":
				for e in CP.layout(it.params): _piece(c, ry, e)
			elif kit == "bldg/lot":
				var pl: Array = it.params.get("poly", [])
				for k in pl.size():
					var a2 := _xf(c, ry, Vector2(float(pl[k][0]), float(pl[k][1]))); var b2 := _xf(c, ry, Vector2(float(pl[(k + 1) % pl.size()][0]), float(pl[(k + 1) % pl.size()][1])))
					_line(a2, b2, 0.12, Color(0.55, 0.5, 0.4))
				for e in it.params.get("pieces", []): _piece(c, ry, e)
			elif kit == "bldg/building": _building(c, ry, it.params)
			elif it.get("footprint") is Array:
				var fp := Vector2(float(it.footprint[0]), float(it.footprint[1]))
				var col := Color(0.62, 0.55, 0.45)
				if kit in ["village/choga", "village/house_compound", "village/jumak", "village/market_shop"]: col = Color(0.86, 0.72, 0.38) if not String(it.params.get("roof", "")) == "giwa" else Color(0.3, 0.3, 0.32)
				if kit == "village/giwa" or kit.begins_with("landmark/"): col = Color(0.3, 0.3, 0.32)
				_rect(c, fp / 2, ry, col, Color(0.1, 0.08, 0.06), kit.begins_with("landmark/") and fp.x > 60)
			else:
				_piece(Vector2.ZERO, 0.0, { kit = kit, params = it.params, x = x, z = z, ry = ry })
			if story: _rect(c, Vector2(3, 3), 0, Color(), Color(0.9, 0.1, 0.8), true)
	# 10m 격자 눈금(가장자리)
	for gx in range(int(ceil(bb[0] / 50.0)) * 50, int(bb[2]), 50):
		_line(Vector2(gx, bb[1]), Vector2(gx, bb[1] + 4), 0.4, Color(0, 0, 0))
	for gz in range(int(ceil(bb[1] / 50.0)) * 50, int(bb[3]), 50):
		_line(Vector2(bb[0], gz), Vector2(bb[0] + 4, gz), 0.4, Color(0, 0, 0))
	var out: String = args.get("out", "shots/town_organic/map.png")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://" + out).get_base_dir())
	img.save_png(ProjectSettings.globalize_path("res://" + out))
	print("TOWNMAP ", out, " ", W, "x", H, " files=", files.size(), " superseded=", sup.size())
	quit()
