# 재질·빛 점검 촬영(material-lighting) — region_main --mlshots=<폴더> [--mlphase=before|after] [--mlstates=day,dusk,night,rain,snow]
#   시험 저장으로만(--savefile), 창 필요. 같은 자리·같은 카메라를 상태(시간·날씨)마다 찍는다 — 전후 비교 시트(tools/matlight/sheet.gd)의 재료.
#   godot --path . --resolution 1920x1080 res://scenes/region.tscn -- --mlshots=shots/material_lighting --mlphase=before \
#     --savefile=user://matlight_test.json --kitcache=user://matlight_kit_cache/ --nostory --notitle --scale=1
extends RefCounted

var main
var dir := ""
var tag := "before"

# 상태: 이름 → [시각, 날씨]
const STATES := { day = [10.5, "clear"], dusk = [18.3, "clear"], night = [22.0, "clear"], rain = [10.5, "rain"], snow = [10.5, "snow"],
	low = [17.4, "clear"], overcast = [11.0, "cloudy"] }
# --mlviews=close: 1인칭 1~3m 가까이(재질 굴곡·시차 매핑) — 흙벽 모서리 · 기단·주춧돌 · 이엉 처마 · 기와 처마 밑 · 내아 마당 땅 · 내아 기단 돌
# 볼 집: 남원 一자 초가(마을 구도), 이겸 집(실내), 관아 내아(기와)
const HOUSE_TOWN := "nw_house_005"
const HOUSE_IN := "ig_house"
const HOUSE_GIWA := "nw_naea"

func _init(m) -> void:
	main = m

func _wait_load() -> void:
	await main._wait_frames(10)
	var n := 0
	while main._loading and n < 6000:
		await main._wait_frames(1); n += 1
	n = 0
	while (main.world.stats.jobs > 0 or main.placement.busy()) and n < 1200:
		await main._wait_frames(1); n += 1

func _sec(s: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < s * 1000.0: await main._wait_frames(1)

func _shot(nm: String) -> void:
	main._save(dir.path_join("%s_%s.png" % [nm, tag]))

var _items := {}
func _item(id: String) -> Dictionary:
	if _items.is_empty():
		for f in main.placement.files():
			var d = JSON.parse_string(FileAccess.get_file_as_string(f))
			if not (d is Dictionary): continue
			for it in d.get("items", []):
				if it is Dictionary and it.has("id"): _items[String(it.id)] = it
	return _items.get(id, {})

func _xf(id: String) -> Transform3D:
	var it := _item(id)
	if it.is_empty(): return Transform3D()
	var x := float(it.x); var z := float(it.z)
	return Transform3D(Basis(Vector3.UP, float(it.get("ry", 0.0))), Vector3(x, main.world.ground_at(x, z), z))

func _set_state(st: String) -> void:
	var s: Array = STATES[st]
	main.hour = float(s[0])
	var w = main.weather
	if w != null:
		w.forced = String(s[1]); w.kind = w.forced; w._snap()
	main._apply_time()

func run(spec: String) -> void:
	dir = main._abs(spec if spec != "1" else "shots/material_lighting")
	tag = String(main.args.get("mlphase", "before"))
	main.view_persist = false
	await _wait_load()
	var states := String(main.args.get("mlstates", "day,dusk,night,rain,snow")).split(",", false)
	var close := String(main.args.get("mlviews", "")) == "close"
	for st in states:
		_set_state(st)
		if close: await _close(st)
		else: await _views(st)
	print("MLSHOT done")
	main._quit()

func _views(st: String) -> void:
	var xt := _xf(HOUSE_TOWN); var xi := _xf(HOUSE_IN); var xg := _xf(HOUSE_GIWA)
	# 1 마을 구도(22° × 0.64) — 一자 초가 앞
	main.set_first_person(false, false)
	await _third(xt, Vector3(0, 0, 6.5), { pitch = 22.0, distance = 22.0 * 0.64, fov = 30.0 }, "%s_town" % st)
	# 2 기본 시점(40°/22m) — 관아 내아(기와) 앞
	await _third(xg, Vector3(0, 0, 9.0), { pitch = 40.0, distance = 22.0, fov = 30.0 }, "%s_default" % st)
	# 3 1인칭 — 이겸 집 처마 모서리(재질 가까이)
	main.set_first_person(true, false)
	await _fp(xi, Vector3(4.6, 0, 4.6), Vector3(2.2, 1.6, 2.0), "%s_fp_eave" % st)
	# 4 1인칭 — 내아 기와 지붕·기단
	await _fp(xg, Vector3(3.5, 0, 7.5), Vector3(0.0, 2.2, 2.7), "%s_fp_giwa" % st)
	# 5 1인칭 실내(이겸 집 안 — 창호 쪽)
	await _fp(xi, Vector3(0.4, 0, 0.3), Vector3(0.0, 1.3, 3.0), "%s_fp_in" % st, true)
	# 6 3인칭 잘라 보기(이겸 집 실내)
	main.set_first_person(false, false)
	var p: Vector3 = xi * Vector3(0.4, 0, 0.3)
	main.teleport(p.x, p.z)
	_put(p)
	main.rig.override = null
	await _sec(1.5)
	await _shot("%s_cut" % st)
	main.set_occ_script(null)

func _close(st: String) -> void:
	var xi := _xf(HOUSE_IN); var xg := _xf(HOUSE_GIWA)
	main.set_first_person(true, false)
	await _fp(xi, Vector3(4.4, 0, 3.6), Vector3(3.0, 1.3, 2.0), "%s_c_mudwall" % st)
	await _fp(xi, Vector3(2.4, 0, 3.9), Vector3(1.4, 0.35, 2.4), "%s_c_base" % st)
	await _fp(xi, Vector3(5.5, 0, 6.5), Vector3(2.0, 2.7, 2.6), "%s_c_thatch" % st)
	await _fp(xg, Vector3(2.5, 0, 8.5), Vector3(1.5, 3.8, 3.2), "%s_c_giwa" % st)
	await _fp(xg, Vector3(-1.0, 0, 9.5), Vector3(-0.6, 0.0, 6.5), "%s_c_ground" % st)
	await _fp(xg, Vector3(1.6, 0, 4.8), Vector3(0.6, 0.6, 3.2), "%s_c_giwabase" % st)
	main.set_first_person(false, false)

func _put(p: Vector3) -> void:
	main.player_pos = Vector3(p.x, main.world.height_at(p.x, p.z), p.z)
	main.player.position = main.player_pos

func _third(xf: Transform3D, lp: Vector3, cam: Dictionary, nm: String) -> void:
	var p: Vector3 = xf * lp
	main.teleport(p.x, p.z)
	await _wait_load()
	main.player.facing = "up"
	var o := cam.duplicate(); o.lookAhead = 0.0; o.aimZ = 0.0
	main.rig.override = o
	main.set_occ_script({ "focus": main.player_pos + Vector3(0, 0.9, 0), "r": 0.0, "near": 0.0 })
	await _sec(1.2)
	await _shot(nm)
	main.rig.override = null

func _fp(xf: Transform3D, lp: Vector3, look: Vector3, nm: String, exact := false) -> void:
	var p: Vector3 = xf * lp
	main.teleport(p.x, p.z)
	if exact: _put(p)
	await _wait_load()
	await _sec(0.4)
	var eye: Vector3 = main.player_pos + Vector3(0, main.FP_EYE, 0)
	var tg: Vector3 = xf * look
	var v := tg - eye
	main.fp_yaw = atan2(v.x, -v.z)
	main.fp_pitch = clampf(atan2(v.y, Vector2(v.x, v.z).length()), -1.2, 1.2)
	await _sec(0.8)
	await _shot(nm)
