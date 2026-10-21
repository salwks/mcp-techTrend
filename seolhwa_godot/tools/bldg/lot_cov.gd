# 필지별 건물 덮임(고을 짜임 점검) — godot --headless --path . -s res://tools/bldg/lot_cov.gd -- --prefix=orge [--file=res://…json]
extends SceneTree
const B := preload("res://kit/bldg/building.gd")
const S := preload("res://kit/bldg/_spec.gd")
const OG := preload("res://kit/bldg/organic.gd")
func _initialize() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1); args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var f := String(args.get("file", "res://region_data/JL_NAMWON_UNBONG/placement_namwon_town.json"))
	var d = JSON.parse_string(FileAccess.get_file_as_string(f))
	var tl := 0.0; var tb := 0.0
	var rows := []
	for it in d.items:
		if String(it.kit) != "bldg/lot" or not String(it.id).begins_with(String(args.get("prefix", "org"))): continue
		var poly := []
		for q in it.params.poly: poly.append(Vector2(float(q[0]), float(q[1])))
		var la := absf(OG.area(poly))
		var ba := 0.0; var nb := 0
		for e in it.params.pieces:
			if String(e.kit) != "bldg/building": continue
			var bb := B.bounds(S.resolve(e.params))
			ba += bb.size.x * bb.size.y; nb += 1
		tl += la; tb += ba
		rows.append("%s %s area=%.0f bld=%.0f n=%d cov=%.0f%%" % [it.id, it.params.type, la, ba, nb, 100.0 * ba / maxf(la, 1)])
	for r in rows: print(r)
	print("LOTCOV lots=%d area=%.0f built=%.0f cov=%.1f%%" % [rows.size(), tl, tb, 100.0 * tb / maxf(tl, 1)])
	quit()
