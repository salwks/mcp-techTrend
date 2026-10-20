# 묶음 그림(시트) 만들기 — 낱장 PNG를 칸에 넣고 이름표를 단 JPEG. 글자를 그리려고 창이 필요하다(--headless 아님).
#   godot --path . -s res://tools/bldg/sheet.gd -- --spec=res://shots/building_rollout/sheets_step1.json
#   spec: { sheets: [ { out: "res://…/x.jpg", title, cols, cw?, ch?, cells: [ { path: "res://…png", label } … ] } … ] }
extends SceneTree
const UiFonts := preload("res://scripts/ui_fonts.gd")

func _initialize() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1); args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var spec = JSON.parse_string(FileAccess.get_file_as_string(String(args.spec)))
	_run.call_deferred(spec)

func _run(spec: Dictionary) -> void:
	for sh in spec.sheets: await _sheet(sh)
	quit()

func _sheet(sh: Dictionary) -> void:
	var cells: Array = sh.cells
	var cols := int(sh.get("cols", 2))
	var cw := int(sh.get("cw", 800)); var ch := int(sh.get("ch", 450)); var lh := 34; var pad := 8; var th := 56
	var rows := ceili(float(cells.size()) / cols)
	var W := cols * (cw + pad) + pad; var H := th + rows * (ch + lh + pad) + pad
	var vp := SubViewport.new()
	vp.size = Vector2i(W, H); vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var bg := ColorRect.new(); bg.color = Color(0.93, 0.9, 0.84); bg.size = Vector2(W, H); vp.add_child(bg)
	var font := UiFonts.main()
	var t := Label.new(); t.text = String(sh.get("title", "")); t.position = Vector2(pad + 4, 8)
	t.add_theme_font_override("font", font); t.add_theme_font_size_override("font_size", 32); t.add_theme_color_override("font_color", Color(0.15, 0.12, 0.1))
	vp.add_child(t)
	for i in cells.size():
		var c: Dictionary = cells[i]
		var cx := pad + (i % cols) * (cw + pad); var cy := th + (i / cols) * (ch + lh + pad)
		var p := ProjectSettings.globalize_path(String(c.path))
		if FileAccess.file_exists(p):
			var img := Image.load_from_file(p)
			if img != null:
				img.resize(cw, ch, Image.INTERPOLATE_LANCZOS)
				var tr := TextureRect.new(); tr.texture = ImageTexture.create_from_image(img)
				tr.position = Vector2(cx, cy); tr.size = Vector2(cw, ch); vp.add_child(tr)
		var l := Label.new(); l.text = String(c.label); l.position = Vector2(cx + 4, cy + ch + 2)
		l.add_theme_font_override("font", font); l.add_theme_font_size_override("font_size", 22); l.add_theme_color_override("font_color", Color(0.18, 0.14, 0.1))
		vp.add_child(l)
	root.add_child(vp)
	for k in 4: await process_frame
	var out := vp.get_texture().get_image()
	out.save_jpg(ProjectSettings.globalize_path(String(sh.out)), 0.85)
	print("SHEET ", sh.out, " ", out.get_size(), " cells=", cells.size())
	vp.queue_free()
