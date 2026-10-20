# 건물 빌더 짓기 점검(헤드리스): 프리셋마다 짓고 삼각형·충돌체·걷기 면·시간을 적는다.
#   godot --headless --path . -s res://tools/bldg/smoke.gd [-- --types=choga,jumak --seeds=3]
extends SceneTree
const B := preload("res://kit/bldg/building.gd")
func _init() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1); args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var types: PackedStringArray = String(args.get("types", "choga,jumak,sijeon,anchae,sarang,haengrang,sadang,gotgan,araechae,dongheon,gaeksa,daeseong,gangdang,jeongja,nugak,mill,smithy,daeung")).split(",")
	var regions: PackedStringArray = String(args.get("regions", "south")).split(",")
	var seeds := int(args.get("seeds", "2"))
	var fails := 0
	for t in types:
		for rg in regions:
			for s in seeds:
				var p := { type = t, region = rg, seed = s + 1 }
				if args.has("interior"): p.interior = true
				var res = B.build(p)
				if not (res is Dictionary) or not res.has("node"):
					print("BSMOKE FAIL ", p); fails += 1; continue
				print("BSMOKE %s/%s/%d tris=%s gen=%.0fms cols=%d walk=%d fp=%s" % [t, rg, s + 1, str(res.stats.tris), res.stats.gen_ms, res.colliders.size(), res.get("walk", []).size(), str(res.footprint)])
				res.node.free()
	print("BSMOKE done fails=%d" % fails)
	quit(1 if fails > 0 else 0)
