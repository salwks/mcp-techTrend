# 건물 덮임 비율(building coverage) — 구역 다각형 안에서 건물 바닥(처마 포함 바운딩, 돌림 반영)이 덮은 땅의 비율.
#   godot --headless --path . -s res://tools/bldg/coverage.gd -- --district=west|eup [--before] [--placedir=res://…/] [--area=x,z;x,z;…]
#   --before: 옛 배치(supersede를 무시하고 고을 짜임 파일은 뺀다) · 기본: 지금 배치(supersede 적용)
#   큰 건물(landmark/*)·관아 담 일곽 자리는 '마을 땅'에서 뺀다(주거 블록 덮임만 잼). 격자 0.5m.
extends SceneTree
const B := preload("res://kit/bldg/building.gd")
const S := preload("res://kit/bldg/_spec.gd")
const CP := preload("res://kit/bldg/compound.gd")
const OG := preload("res://kit/bldg/organic.gd")
const DIR := "res://region_data/JL_NAMWON_UNBONG/"
const ODG := preload("res://tools/bldg/organic.gd")

var fp_cache := {}

func _kit_fp(kit: String, params: Dictionary) -> Vector2:
	var k := kit + JSON.stringify(params, "", true)
	if fp_cache.has(k): return fp_cache[k]
	var s = load("res://kit/%s.gd" % kit)
	var v := Vector2.ZERO
	if s != null:
		var r: Dictionary = s.build(params)
		v = Vector2(r.get("footprint", Vector2.ZERO))
		if r.get("node") is Node: (r.node as Node).free()
	fp_cache[k] = v
	return v

# 항목 → 건물 사각 목록 [ [가운데, 반폭, ry] … ] (월드)
func _rects(it: Dictionary) -> Array:
	var out := []
	var kit := String(it.kit)
	var c := Vector2(float(it.x), float(it.z)); var ry := float(it.get("ry", 0.0))
	var sub := func(e: Dictionary) -> void:
		var pc := c + Vector2(float(e.x) * cos(ry) + float(e.z) * sin(ry), -float(e.x) * sin(ry) + float(e.z) * cos(ry))
		var pry := ry + float(e.get("ry", 0.0))
		if String(e.kit) == "bldg/building":
			var bb := B.bounds(S.resolve(e.params))
			var bc := pc + Vector2(bb.get_center().x * cos(pry) + bb.get_center().y * sin(pry), -bb.get_center().x * sin(pry) + bb.get_center().y * cos(pry))
			out.append([bc, bb.size / 2, pry])
		elif String(e.kit) in ["village/choga", "village/giwa", "village/heotgan", "village/jumak", "village/market_shop", "village/neowa_house", "village/choga_low", "village/oeyanggan"]:
			var f := _kit_fp(String(e.kit), e.params)
			if f != Vector2.ZERO: out.append([pc, f / 2, pry])
	match kit:
		"bldg/building": sub.call({ kit = kit, params = it.params, x = 0.0, z = 0.0, ry = 0.0 })
		"bldg/compound":
			for e in CP.layout(it.params): sub.call(e)
		"bldg/lot":
			for e in it.params.get("pieces", []): sub.call(e)
		"village/house_compound":
			var r: Dictionary = load("res://kit/village/house_compound.gd").build(it.params)
			for e in r.get("pieces", []): sub.call({ kit = e.kit, params = e.params, x = float(e.get("x", (e.xform as Transform3D).origin.x if e.has("xform") else 0.0)), z = float(e.get("z", (e.xform as Transform3D).origin.z if e.has("xform") else 0.0)), ry = float(e.get("ry", 0.0)) })
			if r.get("node") is Node: (r.node as Node).free()
		_:
			if kit in ["village/choga", "village/giwa", "village/jumak", "village/market_shop", "village/neowa_house", "village/choga_low", "village/heotgan"]:
				var f: Vector2 = Vector2(float(it.footprint[0]), float(it.footprint[1])) if it.get("footprint") is Array else _kit_fp(kit, it.params)
				out.append([c, f / 2, ry])
	return out

func _initialize() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1); args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var area := []
	if args.has("district"):
		for q in ODG.DISTRICTS[String(args.district)].area: area.append(Vector2(float(q[0]), float(q[1])))
	else:
		for q in String(args.area).split(";"):
			var v := q.split(","); area.append(Vector2(float(v[0]), float(v[1])))
	var files := []
	for f in DirAccess.get_files_at(DIR):
		if f.begins_with("placement_") and f.ends_with(".json"):
			if args.has("before") and f == "placement_namwon_town.json": continue
			files.append(DIR + f)
	if args.has("placedir"):
		for f in DirAccess.get_files_at(String(args.placedir)):
			if f.begins_with("placement_") and f.ends_with(".json"): files.append(String(args.placedir).path_join(f))
	var datas := []
	var sup := {}
	for f in files:
		var d = JSON.parse_string(FileAccess.get_file_as_string(f))
		if not (d is Dictionary): continue
		datas.append(d)
		if not args.has("before"):
			for s in d.get("supersede", []): sup[String(s)] = true
	var bb := OG._bbox(area)
	var cell := 0.5
	var nx := int(bb.size.x / cell) + 1; var nz := int(bb.size.y / cell) + 1
	var grid := PackedByteArray(); grid.resize(nx * nz)   # 0 밖 · 1 마을 땅 · 2 건물 · 3 큰 건물(뺌)
	for j in nz:
		for i in nx:
			var p := bb.position + Vector2((i + 0.5) * cell, (j + 0.5) * cell)
			grid[j * nx + i] = 1 if OG.pip(area, p) else 0
	var paint := func(rc: Array, val: int) -> void:
		var c: Vector2 = rc[0]; var h: Vector2 = rc[1]; var ry: float = rc[2]
		var R := h.length()
		var i0 := maxi(0, int((c.x - R - bb.position.x) / cell)); var i1 := mini(nx - 1, int((c.x + R - bb.position.x) / cell))
		var j0 := maxi(0, int((c.y - R - bb.position.y) / cell)); var j1 := mini(nz - 1, int((c.y + R - bb.position.y) / cell))
		for j in range(j0, j1 + 1):
			for i in range(i0, i1 + 1):
				var k := j * nx + i
				if grid[k] == 0: continue
				var w := bb.position + Vector2((i + 0.5) * cell, (j + 0.5) * cell) - c
				var lx := w.x * cos(ry) - w.y * sin(ry); var lz := w.x * sin(ry) + w.y * cos(ry)
				if absf(lx) <= h.x and absf(lz) <= h.y:
					if val == 3 or grid[k] != 3: grid[k] = val
	var nb := 0
	for d in datas:
		for it in d.get("items", []):
			if sup.has(String(it.get("id", ""))): continue
			var p := Vector2(float(it.x), float(it.z))
			if not bb.grow(60.0).has_point(p): continue
			var kit := String(it.kit)
			if kit.begins_with("landmark/") and it.get("footprint") is Array:
				paint.call([p, Vector2(float(it.footprint[0]), float(it.footprint[1])) / 2, float(it.get("ry", 0.0))], 3)
				continue
			for rc in _rects(it):
				paint.call(rc, 2); nb += 1
	var land := 0; var bld := 0
	for k in grid.size():
		if grid[k] == 1 or grid[k] == 2: land += 1
		if grid[k] == 2: bld += 1
	print("COVERAGE %s %s buildings=%d land=%.0fm2 built=%.0fm2 coverage=%.1f%%" % [String(args.get("district", "area")), "before" if args.has("before") else "after", nb, land * cell * cell, bld * cell * cell, 100.0 * bld / maxf(1, land)])
	quit()
