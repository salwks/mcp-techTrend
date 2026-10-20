# 건물 빌더 갤러리 찍기 — region_main --bldgallery=<폴더>. 시험 저장으로만(--savefile), 창 필요.
#   1) 배치 만들기: godot --headless --path . -s res://tools/bldg/gallery_place.gd            (shots/building_builder/_place_gallery/)
#   2) 찍기:       godot --path . res://scenes/region.tscn --resolution 1920x1080 -- --region=JL_NAMWON_UNBONG \
#                    --placedir=res://shots/building_builder/_place_gallery/ --bldgallery=shots/building_builder \
#                    --savefile=user://st_bldgallery.json --nostory --notitle --time=11 --weather=clear
#   한꺼번에: tools/bldg/gallery.sh
#   --bgonly=id,id   그 항목만   --bgviews=town,std,fp,int   찍을 시점   --bgnosheet  낱장만
# 항목마다(manifest.json):
#   town  마을 카메라(22°, 기본 거리 22m × 0.64 = 14.1m, fov 30) — 플레이어가 건물 앞에 서고 카메라가 남쪽에서 본다(건물 크기에 맞게 거리만 늘림)
#   std   기본 카메라(40°, 22m)
#   fp    1인칭(눈높이 1.55m, 처마 앞 3m에서 북쪽을 조금 올려다봄)
#   int   실내 항목: 방 안에 서서 게임의 실내 카메라(지붕·앞벽 숨김 — 잘라 보기)
# 끝에 낱장을 모아 묶음 그림(JPEG, 이름표)을 만든다: sheet_variety_*.jpg · sheet_compare.jpg · sheet_interior.jpg · sheet_fp.jpg
extends RefCounted

const UiFonts := preload("res://scripts/ui_fonts.gd")
const TOWN_DIST := 22.0 * 0.64
const TOWN_PITCH := 22.0

var main
var dir := ""
var man := {}
var shots := {}   # id → { view: path }

func _init(m) -> void:
	main = m

func _wait_load() -> void:
	await main._wait_frames(10)
	var n := 0
	while main._loading and n < 6000:
		await main._wait_frames(1); n += 1
	n = 0
	while (main.world.stats.jobs > 0 or main.placement.busy()) and n < 1500:
		await main._wait_frames(1); n += 1

func _sec(s: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < s * 1000.0: await main._wait_frames(1)

func run(spec: String) -> void:
	dir = main._abs(spec if spec != "1" else "shots/building_builder")
	var mpath := ""
	for d in String(main.args.get("placedir", "")).split(";", false):
		var p: String = d.path_join("manifest.json")
		if FileAccess.file_exists(p): mpath = p
	if mpath == "":
		print("BGALLERY 목록(manifest.json) 없음 — --placedir 확인"); main._quit(); return
	man = JSON.parse_string(FileAccess.get_file_as_string(mpath))
	var only: PackedStringArray = String(main.args.get("bgonly", "")).split(",", false)
	var views: PackedStringArray = String(main.args.get("bgviews", "town,std,fp,int,app")).split(",", false)
	main.set_first_person(false, false)
	await _wait_load()
	var t0 := Time.get_ticks_msec()
	for it in man.items:
		if not only.is_empty() and not only.has(String(it.id)): continue
		await _item(it, views)
	print("BGALLERY shots %d ms=%d" % [shots.size(), Time.get_ticks_msec() - t0])
	if not main.args.has("bgnosheet"): await _sheets()
	print("BGALLERY done")
	main._quit()

func _goto(x: float, z: float) -> void:
	main.teleport(x, z)
	await _wait_load()
	await _sec(0.4)

func _item(it: Dictionary, views: PackedStringArray) -> void:
	var id: String = it.id
	var x: float = it.x; var z: float = it.z
	var fp := Vector2(it.fp[0], it.fp[1])
	var front := z + fp.y / 2 + 2.2
	shots[id] = {}
	main.set_first_person(false, false)
	await _goto(x + 1.2, front)
	main.player.facing = "up"
	var occ_off := { "focus": Vector3(x, 1.0, z), "r": 0.0, "near": 0.0 }
	var gy: float = main.world.height_at(x, z)
	var size := maxf(fp.x * 0.72, fp.y * 1.1)
	if views.has("town") and it.group != "interior":
		# 마을 카메라: 22°·14.1m. 큰 건물은 화면에 들게 거리만 늘린다(각·fov는 그대로)
		var d := maxf(TOWN_DIST, size * 1.5)
		var look := Vector3(x, gy + 1.9, z)
		var p := look + Vector3(0, sin(deg_to_rad(TOWN_PITCH)), cos(deg_to_rad(TOWN_PITCH))) * d
		main.rig.shot = { pos = p, look = look, fov = 30.0 }
		main.set_occ_script({ "focus": Vector3(x, gy + 1.0, z + fp.y / 2 + 1.5), "r": 2.4, "near": 1.0 })   # 카메라 앞을 가리는 나무·지붕은 게임처럼 비운다
		main.fog_on = d < 24.0   # 넓게 물러난 시점(묶음·긴 건물)은 안개를 끈다 — 게임 거리(14m)에선 그대로
		main._apply_time()
		await _sec(0.7)
		_shot(id, "town")
		main.fog_on = true
		main._apply_time()
	if views.has("std") and it.group in ["variety"]:
		var d := maxf(22.0, size * 1.35)
		var look := Vector3(x, gy + 1.2, z)
		var yaw := deg_to_rad(-28.0)
		var p := look + Vector3(sin(yaw) * cos(deg_to_rad(40.0)), sin(deg_to_rad(40.0)), cos(yaw) * cos(deg_to_rad(40.0))) * d
		main.rig.shot = { pos = p, look = look, fov = 30.0 }
		main.set_occ_script(occ_off)
		main.fog_on = false
		main._apply_time()
		await _sec(0.6)
		_shot(id, "std")
		main.fog_on = true
		main._apply_time()
	main.rig.shot = null
	main.set_occ_script(null)
	if views.has("fp") and it.group in ["variety", "compare"] and it.kit != "bldg/compound":
		# 1인칭: 처마 끝 앞 1.5m(기단 앞)에서 몸채를 올려다봄
		await _goto(x + fp.x * 0.18, z + fp.y / 2 + 1.5)
		main.set_first_person(true, false)
		main.fp_yaw = deg_to_rad(-12.0); main.fp_pitch = deg_to_rad(8.0)
		await _sec(0.8)
		_shot(id, "fp")
		main.set_first_person(false, false)
	if views.has("fp") and it.kit == "bldg/compound":
		# 묶음: 대문 앞에서 1인칭(담·문·마당 너머)
		await _goto(x, z + fp.y / 2 + 3.0)
		main.set_first_person(true, false)
		main.fp_yaw = 0.0; main.fp_pitch = deg_to_rad(2.0)
		await _sec(0.8)
		_shot(id, "fp")
		main.set_first_person(false, false)
	if it.group == "gate":
		# 대문: 골목에서 1인칭(문을 마주) + 문지방 넘어 안에서 뒤돌아봄
		await _goto(x + 0.3, z + 4.5)
		main.set_first_person(true, false)
		main.fp_yaw = 0.0; main.fp_pitch = deg_to_rad(4.0)
		await _sec(0.8)
		_shot(id, "fp")
		main.set_first_person(false, false)
	if views.has("app") and it.has("approach"):
		await _approach(it)
	if views.has("int") and it.group == "interior" and it.has("inside"):
		var k := 0
		var seen := {}
		for q in it.inside:
			if not (q[0] in ["room", "kitchen", "hall", "maru"]) or seen.has(q[0]): continue
			seen[q[0]] = true
			await _goto(x + float(q[1]) + 0.3, z + 0.3)
			var inn = main.world.interior_at(main.player_pos.x, main.player_pos.z)
			await _sec(1.0)
			_shot(id, "int%d_%s" % [k, q[0]])
			print("BGINT %s %s at=(%.1f) interior=%s foot=%.2f" % [id, q[0], float(q[1]), inn != null, main.player_pos.y - main.world.ground_at(main.player_pos.x, main.player_pos.z)])
			k += 1
			if k >= 3: break
		# 실내 1인칭(방 안에서 뒷벽 쪽)
		if not it.inside.is_empty():
			var q = it.inside[0]
			await _goto(x + float(q[1]), z + 0.6)
			main.set_first_person(true, false)
			main.fp_yaw = deg_to_rad(10.0); main.fp_pitch = deg_to_rad(-14.0)
			await _sec(0.8)
			_shot(id, "intfp")
			main.set_first_person(false, false)

# 진입 길 걷기: 골목 → 대문 바깥 → 문지방 넘어 → 마당 → (내외담·중문) → 안마당. 마디마다 마을 카메라 + 1인칭, 발 높이 기록
func _approach(it: Dictionary) -> void:
	var id: String = it.id
	var C0 := Vector3(float(it.x), 0, float(it.z))
	var pts: Array = it.approach
	var base_y: float = main.world.height_base_at(C0.x, C0.z)
	main.set_first_person(false, false)
	main.teleport(C0.x + float(pts[0][1]), C0.z + float(pts[0][2]))
	await _wait_load(); await _sec(0.4)
	for k in pts.size():
		var q: Array = pts[k]
		var tgt := C0 + Vector3(float(q[1]), 0, float(q[2]))
		var ok := true if k == 0 else _walk_to(tgt)
		var nxt: Vector3 = (C0 + Vector3(float(pts[k + 1][1]), 0, float(pts[k + 1][2]))) if k + 1 < pts.size() else (tgt + Vector3(0, 0, -5))
		var d: Vector3 = nxt - main.player_pos
		print("BGAPP %s %s reached=%s foot=%.2f" % [id, q[0], ok, main.player_pos.y - base_y])
		# 마을 카메라(플레이어 기준 22°·14.1m)
		var look: Vector3 = main.player_pos + Vector3(0, 1.0, 0)
		main.rig.shot = { pos = look + Vector3(0, sin(deg_to_rad(TOWN_PITCH)), cos(deg_to_rad(TOWN_PITCH))) * TOWN_DIST, look = look, fov = 30.0 }
		main.set_occ_script(null)   # 게임과 같은 가림 처리(플레이어 앞 지붕·담 비우기)
		await _sec(0.6)
		_shot(id, "app%d_%s_town" % [k, q[0]])
		main.rig.shot = null; main.set_occ_script(null)
		main.set_first_person(true, false)
		main.fp_yaw = atan2(d.x, -d.z); main.fp_pitch = deg_to_rad(2.0)
		await _sec(0.6)
		_shot(id, "app%d_%s_fp" % [k, q[0]])
		main.set_first_person(false, false)

func _walk_to(t: Vector3) -> bool:
	var w = main.world
	var pos: Vector3 = main.player_pos
	for i in 1600:
		var v := Vector2(t.x - pos.x, t.z - pos.z)
		if v.length() < 0.06: break
		var st := v.normalized() * minf(0.05, v.length())
		var q = w.move_circle(pos, st.x, st.y, main.player.radius)
		if q == null: break
		pos = Vector3(q.x, w.height_at(q.x, q.z), q.z)
		main.player.facing = main.facing_from(st.x, st.y, main.player.facing)
	main.player_pos = pos
	main.player.position = pos
	return Vector2(t.x - pos.x, t.z - pos.z).length() < 0.15

func _shot(id: String, view: String) -> void:
	var p := dir.path_join("raw/%s_%s.png" % [id, view])
	main._save(p)
	shots[id][view] = p

# ---- 묶음 그림 ----------------------------------------------------------------------------------------
func _sheets() -> void:
	var lab := {}
	for it in man.items: lab[it.id] = it.label
	var groups := { variety = [], compare = [], interior = [] }
	for it in man.items:
		if groups.has(it.group) and shots.has(it.id): groups[it.group].append(it.id)
	# 다양성: 마을 카메라 시트(낱 건물 · 묶음 따로), 기본 시점 시트, 1인칭 시트
	var singles := []; var comps := []
	for id in groups.variety:
		var kit := ""
		for it in man.items:
			if it.id == id: kit = it.kit
		(comps if kit == "bldg/compound" else singles).append(id)
	await _sheet("sheet_variety_town_a", "건물 빌더 — 마을 카메라(22°, ×0.64)", _cells(singles.slice(0, 14), "town", lab), 4)
	await _sheet("sheet_variety_town_b", "건물 빌더 — 마을 카메라(22°, ×0.64)", _cells(singles.slice(14), "town", lab), 4)
	await _sheet("sheet_variety_compound", "건물 빌더 — 묶음(마을 카메라 · 대문 앞 1인칭)", _cells(comps, "town", lab) + _cells(comps, "fp", lab, " · 1인칭"), 3)
	await _sheet("sheet_variety_std", "건물 빌더 — 기본 시점(40°, 22m)", _cells(singles + comps, "std", lab), 5)
	await _sheet("sheet_variety_fp", "건물 빌더 — 1인칭 가까이", _cells(singles, "fp", lab), 5)
	await _sheet("sheet_compare_town", "기존 키트 ↔ 새 빌더(마을 카메라)", _cells(groups.compare, "town", lab), 4)
	await _sheet("sheet_compare_fp", "기존 키트 ↔ 새 빌더(1인칭)", _cells(groups.compare, "fp", lab), 4)
	var ic := []
	for id in groups.interior:
		for v in ["int0_room", "int0_kitchen", "int0_hall", "int1_room", "int1_kitchen", "int1_hall", "int2_room", "int2_kitchen", "int2_hall", "intfp"]:
			if shots[id].has(v): ic.append({ path = shots[id][v], label = "%s · %s" % [lab[id], { intfp = "1인칭" }.get(v, { room = "방", kitchen = "부엌", hall = "대청", maru = "마루" }.get(v.substr(5), v.substr(5)))] })
	await _sheet("sheet_interior", "실내 잘라 보기(게임 실내 카메라) · 1인칭", ic, 4)
	var gates := []
	for it in man.items:
		if it.group == "gate" and shots.has(it.id): gates.append(it.id)
	await _sheet("sheet_gates", "대문 종류 — 마을 카메라 · 골목에서 1인칭", _cells(gates, "town", lab) + _cells(gates, "fp", lab, " · 1인칭"), 3)
	for it in man.items:
		if not it.has("approach") or not shots.has(it.id): continue
		var ac := []
		for k in it.approach.size():
			var nm: String = it.approach[k][0]
			for v in ["town", "fp"]:
				var key := "app%d_%s_%s" % [k, nm, v]
				if shots[it.id].has(key): ac.append({ path = shots[it.id][key], label = "%d %s · %s" % [k + 1, { alley = "골목", gate_out = "대문 앞", gate_in = "문지방 넘어", naeoe = "내외담 옆", jungmun_out = "중문 앞", jungmun_in = "중문 안", anmadang = "안마당" }.get(nm, nm), "마을 카메라" if v == "town" else "1인칭"] })
		await _sheet("sheet_approach_" + String(it.id), "진입: %s — 골목 → 대문 → 마당 → 중문·내외담 → 안마당" % String(lab[it.id]), ac, 4)

func _cells(ids: Array, view: String, lab: Dictionary, suffix := "") -> Array:
	var out := []
	for id in ids:
		if shots.has(id) and shots[id].has(view): out.append({ path = shots[id][view], label = String(lab[id]) + suffix })
	return out

func _sheet(name: String, title: String, cells: Array, cols: int) -> void:
	if cells.is_empty(): return
	var cw := 640; var ch := 360; var lh := 34; var pad := 8; var th := 56
	var rows := ceili(float(cells.size()) / cols)
	var W := cols * (cw + pad) + pad; var H := th + rows * (ch + lh + pad) + pad
	var vp := SubViewport.new()
	vp.size = Vector2i(W, H); vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var bg := ColorRect.new(); bg.color = Color(0.93, 0.9, 0.84); bg.size = Vector2(W, H); vp.add_child(bg)
	var font := UiFonts.main()
	var t := Label.new(); t.text = title; t.position = Vector2(pad + 4, 8); t.add_theme_font_override("font", font); t.add_theme_font_size_override("font_size", 34)
	t.add_theme_color_override("font_color", Color(0.15, 0.12, 0.1)); vp.add_child(t)
	for i in cells.size():
		var c: Dictionary = cells[i]
		var img := Image.load_from_file(c.path)
		if img == null: continue
		img.resize(cw, ch, Image.INTERPOLATE_LANCZOS)
		var tr := TextureRect.new(); tr.texture = ImageTexture.create_from_image(img)
		var cx := pad + (i % cols) * (cw + pad); var cy := th + (i / cols) * (ch + lh + pad)
		tr.position = Vector2(cx, cy); tr.size = Vector2(cw, ch)
		vp.add_child(tr)
		var l := Label.new(); l.text = c.label; l.position = Vector2(cx + 4, cy + ch + 2)
		l.add_theme_font_override("font", font); l.add_theme_font_size_override("font_size", 24); l.add_theme_color_override("font_color", Color(0.18, 0.14, 0.1))
		vp.add_child(l)
	main.add_child(vp)
	await main._wait_frames(4)
	var out := vp.get_texture().get_image()
	var p := dir.path_join(name + ".jpg")
	out.save_jpg(p, 0.86)
	print("BGSHEET ", p, " ", out.get_size(), " cells=", cells.size())
	vp.queue_free()
