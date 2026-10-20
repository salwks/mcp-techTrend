# 짓기·캐시 시간(헤드리스): 마을 블록 30채를 키트 캐시로 짓고(찬 캐시) 다시 불러(더운 캐시) 시간을 잰다.
#   godot --headless --path . -s res://tools/bldg/cache_time.gd -- --cache=<절대 폴더>   (사용자 user:// 캐시를 건드리지 않게 절대 폴더)
extends SceneTree
const KC := preload("res://scripts/region/kit_cache.gd")
func _init() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1); args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	KC.DIR = String(args.get("cache", "/tmp/bldg_kit_cache/")).trim_suffix("/") + "/"
	var d := DirAccess.open(KC.DIR)
	if d:
		for f in d.get_files(): d.remove(f)
	var man = JSON.parse_string(FileAccess.get_file_as_string("res://shots/building_builder/_place_block/manifest.json"))
	var scr = load("res://kit/bldg/building.gd")
	var cold := []; var save := []; var warm := []; var tris := []
	for it in man.items:
		var t0 := Time.get_ticks_usec()
		var r: Dictionary = KC.build("bldg/building", scr, it.params)
		var t1 := Time.get_ticks_usec()
		KC.save_if_needed(r)
		var t2 := Time.get_ticks_usec()
		cold.append((t1 - t0) / 1000.0); save.append((t2 - t1) / 1000.0)
		tris.append(r.get("stats", {}).get("tris", []))
		r.node.free()
	for it in man.items:
		var t0 := Time.get_ticks_usec()
		var r: Dictionary = KC.build("bldg/building", scr, it.params)
		warm.append((Time.get_ticks_usec() - t0) / 1000.0)
		r.node.free()
	var sum := func(a: Array) -> float: return a.reduce(func(x, y): return x + y, 0.0)
	cold.sort(); warm.sort()
	print("CACHETIME n=%d build_total=%.0fms build_med=%.0fms build_max=%.0fms save_total=%.0fms warm_total=%.0fms warm_med=%.1fms hits=%d misses=%d" % [cold.size(), sum.call(cold), cold[cold.size() / 2], cold[cold.size() - 1], sum.call(save), sum.call(warm), warm[warm.size() / 2], KC.hits, KC.misses])
	var t_near := 0; var t_mid := 0; var t_far := 0
	for t in tris:
		if t.size() == 3: t_near += t[0]; t_mid += t[1]; t_far += t[2]
	print("CACHETIME block_tris near=%d mid=%d far=%d" % [t_near, t_mid, t_far])
	quit()
