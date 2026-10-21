# 비탈 터 찾기(산촌·반촌 견본): W×D 안 평균 기울기가 --smin~--smax(%) 이고 물·바위가 적은 자리를 spawn에서 가까운 순으로.
#   godot --headless --path . -s res://tools/bldg/find_slope.gd -- --w=200 --d=200 --smin=6 --smax=16 --r=2500
extends SceneTree
func _init() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1); args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var W := float(args.get("w", "200")); var Dd := float(args.get("d", "200"))
	var dir := "res://region_data/JL_NAMWON_UNBONG/"
	var reg = JSON.parse_string(FileAccess.get_file_as_string(dir + "region.json"))
	var hm: Dictionary = reg.height
	var himg := Image.load_from_file(ProjectSettings.globalize_path(dir + String(hm.file)))
	var lu: Dictionary = reg.landuse
	var limg := Image.load_from_file(ProjectSettings.globalize_path(dir + "landuse.png"))
	var hf := func(x: float, z: float) -> float:
		var i := clampi(int(round((x - float(hm.x0)) / float(hm.cell))), 0, himg.get_width() - 1)
		var j := clampi(int(round((z - float(hm.z0)) / float(hm.cell))), 0, himg.get_height() - 1)
		return float(hm.y_min) + himg.get_pixel(i, j).r * (float(hm.y_max) - float(hm.y_min))
	var sp := Vector2(float(reg.spawn.x), float(reg.spawn.z))
	var RR := int(args.get("r", "2500"))
	var smin := float(args.get("smin", "6")) / 100.0; var smax := float(args.get("smax", "16")) / 100.0
	var out := []
	for cz in range(int(sp.y) - RR, int(sp.y) + RR, 40):
		for cx in range(int(sp.x) - RR * 2, int(sp.x) + RR * 2, 40):
			var ss := 0.0; var n := 0; var bad := 0
			for j in range(0, int(Dd), 10):
				for i in range(0, int(W), 10):
					var x: float = cx - W / 2 + i; var z: float = cz - Dd / 2 + j
					var g := Vector2(hf.call(x + 2, z) - hf.call(x - 2, z), hf.call(x, z + 2) - hf.call(x, z - 2)).length() / 4.0
					ss += g; n += 1
					var px := int((x - float(lu.x0)) / float(lu.cell)); var pz := int((z - float(lu.z0)) / float(lu.cell))
					if px < 0 or pz < 0 or px >= limg.get_width() or pz >= limg.get_height(): bad += 99; continue
					var k := int(round(limg.get_pixel(px, pz).r * 255.0))
					if k in [5, 7, 8]: bad += 1
			var s := ss / n
			if s >= smin and s <= smax and bad * 20 < n:
				out.append([Vector2(cx, cz).distance_to(sp), Vector2(cx, cz), snappedf(s * 100, 0.1), bad, snappedf(hf.call(cx, cz), 0.1)])
	out.sort_custom(func(a, b): return a[0] < b[0])
	for k in mini(10, out.size()): print("SLOPE ", out[k])
	print("SLOPE n=", out.size())
	quit()
