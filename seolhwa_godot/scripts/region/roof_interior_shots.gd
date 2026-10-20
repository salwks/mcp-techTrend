# 초가 지붕 뚫림 · 실내 벽 깜빡임(z-fighting) 점검 촬영(fix-1021) — region_main --roofshots=<폴더>. 시험 저장으로만(--savefile), 창 필요.
#   godot --path . --resolution 1280x720 res://scenes/region.tscn -- --roofshots=shots/fix_1021 --rsphase=before \
#     --savefile=user://st_roofshots.json --nostory --notitle --time=14 --weather=clear
#   --rsids=id,id…  찍을 배치 id(기본: 이겸 집·서원 집·남원 一자 초가·집 묶음 small/medium·주막·내아)
#   집마다: 마을 구도(22° ×0.64) 앞·옆 · 기본 40° · 1인칭 바깥(앞·처마 밑 모서리 올려다보기) · 실내가 있으면 잘라 보기 + 느린 카메라 이동 8장 ·
#   1인칭 안(뒷벽·옆벽·천장) + 천천히 돌기 8장. 플레이어 자리는 집 로컬 좌표(집 묶음은 안채 자리로 옮긴다).
extends RefCounted

var main
var dir := ""
var tag := "before"

const DEFAULT_IDS := "ig_house,sw_house,nw_house_005,nw_house_003,nw_house_001,nw_jumak_naru,nw_naea"
# 집 묶음 안채 자리(house_compound.entries와 같은 값)·크기
const COMPOUND := { small = [0.0, -2.6, 6.0, 4.0], medium = [0.0, -3.8, 7.2, 4.4], large = [0.0, -4.9, 9.0, 5.4] }

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

func run(spec: String) -> void:
	dir = main._abs(spec if spec != "1" else "shots/fix_1021")
	tag = String(main.args.get("rsphase", "before"))
	main.view_persist = false
	await _wait_load()
	for id in String(main.args.get("rsids", DEFAULT_IDS)).split(",", false):
		await _house(id)
	print("RSHOT done")
	main._quit()

func _house(id: String) -> void:
	var it := _item(id)
	if it.is_empty(): print("RSHOT %s 없음" % id); return
	var kit := String(it.get("kit", ""))
	var P: Dictionary = it.get("params", {})
	var x := float(it.x); var z := float(it.z); var ry := float(it.get("ry", 0.0))
	main.teleport(x, z + 14.0)
	await _wait_load()
	await _sec(0.5)
	var xf := Transform3D(Basis(Vector3.UP, ry), Vector3(x, main.world.ground_at(x, z), z))
	var W := float(P.get("w", 6.0)); var D := float(P.get("d", 4.0)); var F := 0.4
	match kit:
		"village/house_compound":
			var c: Array = COMPOUND.get(String(P.get("size", "small")), COMPOUND.small)
			xf = xf * Transform3D(Basis.IDENTITY, Vector3(c[0], 0, c[1]))
			W = c[2]; D = c[3]
		"village/jumak": W = float(P.get("w", 7.2)); D = float(P.get("d", 4.4))
		"village/giwa": W = float(P.get("w", 9.0)); D = float(P.get("d", 5.4)); F = 0.75
		"landmark/naea": W = 12.5; D = 5.4; F = 0.7
	var plan := String(P.get("plan", ""))
	var front := D / 2 + (1.7 if plan == "il" else 1.3) + 3.0
	# 1 마을 구도 22°(×0.64) 앞·옆, 기본 40°
	main.set_first_person(false, false)
	await _third(xf, Vector3(0, 0, front), { pitch = 22.0, distance = 22.0 * 0.64, fov = 30.0 }, "%s_town22_front" % id)
	await _third(xf, Vector3(W / 2 + 3.5, 0, 0.5), { pitch = 22.0, distance = 22.0 * 0.64, fov = 30.0 }, "%s_town22_side" % id)
	await _third(xf, Vector3(0, 0, front), { pitch = 40.0, distance = 16.0, fov = 30.0 }, "%s_cam40_front" % id)
	main.rig.override = null
	# 2 1인칭 바깥: 앞에서 집 전체 · 처마 밑 모서리 올려다보기
	main.set_first_person(true, false)
	await _fp(xf, Vector3(W * 0.35, 0, front - 0.5), Vector3(W / 2, F + 1.9, D / 2), "%s_fp_out_front" % id)
	await _fp(xf, Vector3(W / 2 + 1.6, 0, D / 2 + 1.8), Vector3(W / 2, F + 2.2, D / 2), "%s_fp_out_eave" % id)
	await _fp(xf, Vector3(-W / 2 - 1.4, 0, -0.4), Vector3(-W / 2, F + 2.1, 0.0), "%s_fp_out_side" % id)
	# 3 실내(interior가 있는 키트)
	var inside := bool(P.get("interior", false)) or kit == "landmark/naea"
	if inside:
		var cin := Vector3(0.4, 0, 0.3) if kit != "landmark/naea" else Vector3(-2.5, 0, 0.3)
		# 1인칭 안: 뒷벽 · 옆벽 · 천장 + 천천히 돌기
		await _fp(xf, cin, cin + Vector3(-0.3, F + 1.2, -3.0), "%s_fp_in_back" % id, true)
		await _fp(xf, cin, cin + Vector3(-3.0, F + 1.3, -0.6), "%s_fp_in_side" % id, true)
		await _fp(xf, cin, cin + Vector3(-0.8, F + 3.2, -1.2), "%s_fp_in_up" % id, true)
		await _fp(xf, cin, cin + Vector3(-3.0, F + 1.0, -2.2), "", true)
		for i in 8:
			main.fp_yaw += deg_to_rad(1.5)
			await main._wait_frames(3)
			await _shot("%s_fp_in_turn_%02d" % [id, i])
		# 3인칭 잘라 보기 + 느린 카메라 이동(실내 카메라 값에서 조금씩)
		main.set_first_person(false, false)
		var p: Vector3 = xf * cin
		main.teleport(p.x, p.z)
		_put(p)
		main.rig.override = null
		await _sec(1.5)
		await _shot("%s_cut" % id)
		var c0: Dictionary = main.rig.cur.duplicate()
		for i in 8:
			main.rig.override = { pitch = float(c0.pitch) - 1.0 * (i + 1), distance = float(c0.distance) - 0.15 * (i + 1), fov = float(c0.fov), lookAhead = 0.0, aimZ = 0.0 }
			await main._wait_frames(4)
			await _shot("%s_cut_move_%02d" % [id, i])
		main.rig.override = null
	main.set_first_person(false, false)
	main.set_occ_script(null)

# 충돌체를 무시하고 그 자리에 세운다(관아 내아·동헌은 몸채 전체가 충돌 상자 — 이야기가 실내로 옮겨 놓는 자리와 같게)
func _put(p: Vector3) -> void:
	main.player_pos = Vector3(p.x, main.world.height_at(p.x, p.z), p.z)
	main.player.position = main.player_pos

# 3인칭: 플레이어를 로컬 자리에 두고 카메라 값(override)으로
func _third(xf: Transform3D, lp: Vector3, cam: Dictionary, nm: String) -> void:
	var p: Vector3 = xf * lp
	main.teleport(p.x, p.z)
	main.player.facing = "up"
	var o := cam.duplicate(); o.lookAhead = 0.0; o.aimZ = 0.0
	main.rig.override = o
	main.set_occ_script({ "focus": main.player_pos + Vector3(0, 0.9, 0), "r": 0.0, "near": 0.0 })
	await _sec(1.2)
	await _shot(nm)

# 1인칭: 로컬 자리 lp에 서서 로컬 점 look을 본다
func _fp(xf: Transform3D, lp: Vector3, look: Vector3, nm: String, exact := false) -> void:
	var p: Vector3 = xf * lp
	main.teleport(p.x, p.z)
	if exact: _put(p)
	await _sec(0.4)
	var eye: Vector3 = main.player_pos + Vector3(0, main.FP_EYE, 0)
	var tg: Vector3 = xf * look
	var v := tg - eye
	main.fp_yaw = atan2(v.x, -v.z)
	main.fp_pitch = clampf(atan2(v.y, Vector2(v.x, v.z).length()), -1.2, 1.2)
	await _sec(0.8)
	if nm != "": await _shot(nm)
