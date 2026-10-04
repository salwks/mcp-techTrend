# 글꼴 글자 확인 — 게임이 쓰는 글자(스크립트·이야기 데이터·지명 json의 비ASCII 글자)가 덕온공주체에 있나.
#   godot --headless --path seolhwa_godot --script res://tools/font_coverage.gd
# 없는 글자는 scripts/ui_fonts.gd의 시스템 명조 줄(대체 글꼴)이 그린다. 결과: 글꼴마다 빠진 글자 목록.
extends SceneTree

const UiFonts := preload("res://scripts/ui_fonts.gd")

func _init() -> void:
	var chars := {}
	var files: Array = []
	for root in ["res://scripts", "res://story"]: _walk(root, [".gd", ".json"], files)
	_walk("res://region_data", ["region.json", "route.json", "nation_map.json", "world_scenario.json"], files)
	for f in files:
		var s := FileAccess.get_file_as_string(f)
		for i in s.length():
			var c := s.unicode_at(i)
			if c >= 0x80: chars[c] = int(chars.get(c, 0)) + 1
	print("FONTCOV files=%d chars=%d" % [files.size(), chars.size()])
	for nm in ["main", "classic"]:
		var ff: FontFile = UiFonts.raw(nm)
		var miss := []
		var hangul_miss := 0
		for c in chars:
			if not ff.has_char(c):
				miss.append(c)
				if c >= 0xAC00 and c <= 0xD7A3: hangul_miss += 1
		miss.sort()
		var shown := miss.map(func(c): return "%s(U+%04X ×%d)" % [String.chr(c), c, chars[c]])
		print("FONTCOV %s missing=%d hangul_missing=%d" % [nm, miss.size(), hangul_miss])
		print("FONTCOV %s: %s" % [nm, " ".join(shown)])
	quit()

func _walk(dir: String, exts: Array, out: Array) -> void:
	var da := DirAccess.open(dir)
	if da == null: return
	for f in da.get_files():
		for e in exts:
			if f.ends_with(e): out.append(dir.path_join(f)); break
	for sd in da.get_directories():
		if sd.begins_with(".") or sd == "map" or sd == "placement": continue
		_walk(dir.path_join(sd), exts, out)
