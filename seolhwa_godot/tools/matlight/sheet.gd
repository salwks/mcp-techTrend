# 사진 묶음 시트 — 그림 여러 장을 칸에 줄여 붙여 JPG 한 장으로(글자 없음, 순서는 인자 순서).
#   godot --headless --path . -s res://tools/matlight/sheet.gd -- --out=shots/x.jpg --cols=3 --w=640 a.png b.png …
extends SceneTree

func _initialize() -> void:
	var out := ""; var cols := 3; var w := 640; var files := []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out = a.substr(6)
		elif a.begins_with("--cols="): cols = int(a.substr(7))
		elif a.begins_with("--w="): w = int(a.substr(4))
		else: files.append(a)
	var imgs := []
	var h := 0
	for f in files:
		var im := Image.load_from_file(ProjectSettings.globalize_path(f) if f.begins_with("res://") else f)
		if im == null: imgs.append(null); continue
		im.convert(Image.FORMAT_RGB8)
		var hh := int(round(float(im.get_height()) * w / im.get_width()))
		im.resize(w, hh, Image.INTERPOLATE_LANCZOS)
		h = maxi(h, hh)
		imgs.append(im)
	var rows := int(ceil(float(imgs.size()) / cols))
	var pad := 4
	var sheet := Image.create(cols * (w + pad) + pad, rows * (h + pad) + pad, false, Image.FORMAT_RGB8)
	sheet.fill(Color(0.1, 0.1, 0.1))
	for i in imgs.size():
		if imgs[i] == null: continue
		var im: Image = imgs[i]
		sheet.blit_rect(im, Rect2i(Vector2i.ZERO, im.get_size()), Vector2i(pad + (i % cols) * (w + pad), pad + (i / cols) * (h + pad)))
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	sheet.save_jpg(out, 0.86)
	print("SHEET ", out, " ", sheet.get_size())
	quit()
