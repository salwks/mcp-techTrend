# 건물 빌더 삼각형 나눔(부분별) — godot --headless --path . -s res://tools/bldg/tri_parts.gd -- --type=choga --region=south --seed=1
extends SceneTree
const B := preload("res://kit/bldg/building.gd")
const S := preload("res://kit/bldg/_spec.gd")
const C := preload("res://kit/village/_common.gd")
func _init() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1); args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var sp := S.resolve({ type = args.get("type", "choga"), region = args.get("region", "south"), seed = int(args.get("seed", "1")) })
	var m := C.M.new(1, false)
	B.draw(m, sp, 0)
	var tot := 0
	for p in m.parts:
		var b: Kit.Batch = m.parts[p]
		var n := 0; var nh := 0
		for g in b.parts.get("atlas", []):
			if g.col.size() > 0 and g.col[0] == Kit.hex(Kit.INK): nh += g.size() / 3
			else: n += g.size() / 3
		print("TRIPART %-10s geo=%d ink=%d" % [p, n, nh]); tot += b.tris
	print("TRIPART total=%d" % tot)
	quit()
