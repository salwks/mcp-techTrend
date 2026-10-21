# 사진 스캔 PBR 묶기 — tools/pbr_scan/pack_maps.py가 만든 PNG를 Texture2DArray 두 장(BC3 + 밉맵)으로: assets/pbr_scan/scan_a.res · scan_b.res
#   godot --path . -s res://tools/pbr_scan/pack.gd   (창 필요 — 헤드리스는 텍스처 자료를 남기지 않는다)
# 층 순서 = tools/pbr_scan/fetch.py LAYERS = shaders/pbr_scan.gdshaderinc S_*
extends SceneTree

func _initialize() -> void:
	var dir := ProjectSettings.globalize_path("res://assets/pbr_scan/src/_packed/")
	var files := DirAccess.get_files_at(dir)
	var n := 0
	for f in files: if f.ends_with("_a.png"): n += 1
	var total := 0
	for side in ["a", "b"]:
		var arr: Array[Image] = []
		for i in n:
			var path := ""
			for f in files:
				if f.begins_with("%d_" % i) and f.ends_with("_%s.png" % side): path = dir + f
			var img := Image.load_from_file(path)
			img.convert(Image.FORMAT_RGBA8)
			img.generate_mipmaps()
			var e := img.compress(Image.COMPRESS_S3TC, Image.COMPRESS_SOURCE_GENERIC)
			if e != OK: print("SCAN compress failed ", e)
			total += img.get_data().size()
			arr.append(img)
		var tex := Texture2DArray.new()
		tex.create_from_images(arr)
		var p := "res://assets/pbr_scan/scan_%s.res" % side
		print("SCAN saved ", p, " err=", ResourceSaver.save(tex, p, ResourceSaver.FLAG_COMPRESS), " layers=", n, " size=", arr[0].get_width())
	var mp := "res://assets/pbr_scan/manifest.json"
	var man = JSON.parse_string(FileAccess.get_file_as_string(mp))
	man.packed = { files = ["scan_a.res", "scan_b.res"], compression = "S3TC/BC3 + mipmaps", resolution = Image.load_from_file(dir + files[0]).get_width(),
		a = "rgb sRGB albedo, a height", b = "r roughness, g normal.y (GL), b AO, a normal.x" }
	man.vram_bytes = total
	var fo := FileAccess.open(mp, FileAccess.WRITE); fo.store_string(JSON.stringify(man, " ")); fo.close()
	print("SCAN vram=%.1fMB" % (total / 1048576.0))
	quit()
