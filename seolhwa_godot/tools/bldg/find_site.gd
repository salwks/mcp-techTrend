# 빈 터 찾기(갤러리·마을 블록 시험 자리): 남원 권역에서 W×D 사각형 안이 풀밭·밭·논(물·길·숲·마을 터 아님)이고
# 배치 항목이 없는 자리를 읍성(spawn)에서 가까운 순으로 찾는다.  godot --headless --path . -s res://tools/bldg/find_site.gd -- --w=240 --d=150
extends SceneTree
func _init() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1); args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var W := float(args.get("w", "240")); var Dd := float(args.get("d", "150"))
	var dir := "res://region_data/JL_NAMWON_UNBONG/"
	var reg = JSON.parse_string(FileAccess.get_file_as_string(dir + "region.json"))
	var lu: Dictionary = reg.landuse
	var img := Image.load_from_file(ProjectSettings.globalize_path(dir + "landuse.png"))
	var hm: Dictionary = reg.height
	var items := []
	var da := DirAccess.open(dir)
	for f in da.get_files():
		if f.begins_with("placement_") and f.ends_with(".json"):
			var d = JSON.parse_string(FileAccess.get_file_as_string(dir + f))
			for it in d.get("items", []): items.append(Vector2(float(it.x), float(it.z)))
	var sp := Vector2(float(reg.spawn.x), float(reg.spawn.z))
	var cands := []
	var x0: float = lu.x0; var z0: float = lu.z0; var cell: float = lu.cell
	var RR := int(args.get("r", "1500"))
	for cz in range(int(sp.y) - RR, int(sp.y) + RR, 20):
		for cx in range(int(sp.x) - RR * 2, int(sp.x) + RR * 2, 20):
			var c := Vector2(cx, cz)
			var bad := false
			for p in items:
				if args.has("anyitems"): break
				if absf(p.x - cx) < W / 2 + 25 and absf(p.y - cz) < Dd / 2 + 25: bad = true; break
			if bad: continue
			var nbad := 0; var n := 0
			for j in range(0, int(Dd), 8):
				for i in range(0, int(W), 8):
					var px := int((cx - W / 2 + i - x0) / cell); var pz := int((cz - Dd / 2 + j - z0) / cell)
					if px < 0 or pz < 0 or px >= img.get_width() or pz >= img.get_height(): nbad += 999; continue
					var k := int(round(img.get_pixel(px, pz).r * 255.0))
					n += 1
					if not (k in ([0, 1, 2, 3, 6] if args.has("forest") else [1, 2, 3])): nbad += 1
					if k == 5 and args.has("nowater"): nbad += 9999   # 물(강·개울)이 하나라도 있으면 버림
			if nbad * int(args.get("tol", "50")) > n: continue   # 2% 넘게 물·길·숲이면 버림(--tol=10이면 10%)
			cands.append([c.distance_to(sp), c, nbad])
	cands.sort_custom(func(a, b): return a[0] < b[0])
	for k in mini(8, cands.size()): print("SITE ", cands[k])
	print("SITE n=", cands.size())
	quit()
