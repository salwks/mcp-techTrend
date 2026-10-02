extends SceneTree
func _init():
	var RW = load("res://scripts/region/region_world.gd")
	var PL = load("res://scripts/region/placement_loader.gd")
	var w = RW.new(); w.markers = false; w.use_scatter = false
	root.add_child(w)
	w.load_region("")
	var pl = PL.new(w, [])
	pl.load_all()
	var bad := 0; var n := 0
	for f in pl.files():
		var d = JSON.parse_string(FileAccess.get_file_as_string(f))
		for it in d.items:
			if not str(it.id).begins_with("nw_") or not (it.kit in ["village/stone_bridge", "village/seop_bridge", "village/jingeom", "landmark/gwanghallu_pond"]): continue
			var ox := 0.0
			if it.kit == "landmark/gwanghallu_pond": ox = -float(it.params.get("width", 110.0)) * 0.18
			n += 1
			var info = pl._cache.get(pl._key(it.kit, it.params), {})
			var b := Basis(Vector3.UP, float(it.ry))
			var L := float(it.params.get("len", 57.0 if it.kit == "landmark/gwanghallu_pond" else 8.0))
			var line := ""; var blocked := 0; var maxstep := 0.0; var prev = null
			var ns := maxi(20, int((L + 3.0) / 0.5))
			for i in ns + 1:
				var zl := -L / 2 - 1.5 + (L + 3.0) * i / float(ns)
				var p: Vector3 = b * Vector3(ox, 0, zl)
				var x: float = float(it.x) + p.x; var z: float = float(it.z) + p.z
				var h: float = w.height_at(x, z)
				if w.blocked(x, z, 0.375): blocked += 1
				if prev != null: maxstep = maxf(maxstep, absf(h - prev))
				prev = h
				if i % maxi(1, ns / 20) == 0: line += "%.1f:%.2f%s " % [zl, h, "B" if w.blocked(x, z, 0.375) else ""]
			if blocked > 0 or maxstep > 0.45: bad += 1
			print(line)
			print("%s %s walk=%s blocked=%d maxstep=%.2f" % [it.id, it.kit.get_file(), info.has("walk"), blocked, maxstep])
	print("BRIDGES n=%d bad=%d" % [n, bad])
	w.shutdown()
	quit()
