# 건물 바닥·초가 지붕 점검(촬영 + 걷기 기록) — region_main --buildshots=<폴더>. 시험 저장으로만(--savefile), 창 필요(장면 찍기).
#   godot --path . --resolution 1280x720 res://scenes/region.tscn -- --buildshots=shots/building_sim --bsphase=after \
#     --savefile=user://st_buildshots.json --nostory --notitle --time=14 --weather=clear
#   --bswalk=id,id…   걸어 들어가 볼 건물(배치 id, 기본 ig_house,nw_jumak_naru,nw_house_032)
#   --bscorner=id,id… 처마 모서리를 비스듬히 찍을 초가(기본 ig_house,nw_house_008)
#   걷기는 world.move_circle로 한 걸음(5cm)씩 — 플레이어와 같은 충돌·단 오르기 판정. 줄마다 BSWALK 기록(닿음·발 높이·바닥 높이).
extends RefCounted

var main
var dir := ""
var tag := "after"

# 키트별 걷는 길(키트 로컬 x,z)·바닥 높이 F·찍을 시점(로컬 카메라 자리·보는 점)
const PLANS := {
	"village/choga": { F = 0.4, block = [[2.3, 5.2], [2.3, 2.2], [5.0, 1.6, 5.6], [2.3, 0.5, 2.4]], legs = [
		["daetdol", [[0.0, 5.5], [0.0, 2.95]], [3.6, 1.6, 6.2], [0.0, 0.5, 2.6]],
		["maru", [[0.0, 2.45]], [3.6, 1.8, 6.0], [0.0, 0.7, 2.3]],
		["room", [[0.0, 1.2], [0.0, -0.2]], null, null],
		["chest", [[-2.1, -0.4], [-2.1, -1.7]], null, null] ] },
	"village/jumak": { F = 0.4, legs = [
		["daetdol", [[0.0, 5.6], [0.0, 3.15]], [3.8, 1.6, 6.6], [0.0, 0.5, 2.8]],
		["maru", [[0.0, 2.65]], [3.8, 1.8, 6.4], [0.0, 0.7, 2.5]],
		["inside", [[0.0, 1.5]], [3.0, 2.2, 6.0], [0.0, 0.8, 1.8]] ] },
	"village/giwa": { F = 0.75, block = [[2.6, 6.5], [2.6, 3.0], [5.6, 1.8, 7.0], [2.6, 0.6, 3.2]], legs = [
		["step1", [[0.0, 7.6], [0.0, 4.65]], [4.6, 1.8, 7.8], [0.0, 0.6, 4.0]],
		["step3", [[0.0, 4.3], [0.0, 3.95]], [4.6, 2.0, 7.6], [0.0, 0.9, 3.6]],
		["maru", [[0.0, 3.2]], [4.6, 2.2, 7.4], [0.0, 1.1, 3.0]],
		["daecheong", [[0.0, 2.0]], [4.2, 2.4, 7.0], [0.0, 1.2, 2.2]] ] },
}

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

func _rec(id: String) -> Variant:
	var pr = main.world.get("props")
	if pr == null or not pr._props.has(id): return null
	return pr._props[id]

func run(spec: String) -> void:
	dir = main._abs(spec if spec != "1" else "shots/building_sim")
	tag = String(main.args.get("bsphase", "after"))
	await _wait_load()
	var walks: PackedStringArray = String(main.args.get("bswalk", "ig_house,nw_jumak_naru,nw_house_032")).split(",", false)
	var corners: PackedStringArray = String(main.args.get("bscorner", "ig_house,nw_house_008")).split(",", false)
	for id in walks: await _walk_building(id)
	for id in corners: await _corner_shots(id)
	print("BSHOT done")
	main._quit()

# 건물 앞에서 길을 따라 걸어 들어가며 단마다 발 높이를 적고 찍는다
func _walk_building(id: String) -> void:
	var r = await _goto(id)
	if r == null: print("BSWALK %s 없음" % id); return
	var kit := String(r.get("kit", ""))
	if kit == "" and r.info.get("node") != null: kit = _kit_of(id)
	var plan: Dictionary = PLANS.get(kit, {})
	if plan.is_empty(): print("BSWALK %s 키트 %s 길 없음" % [id, kit]); return
	var xf: Transform3D = r.xf
	var first := true
	for leg in plan.legs:
		var pts: Array = leg[1]
		if first:
			var p0: Vector3 = xf * Vector3(pts[0][0], 0, pts[0][1])
			main.teleport(p0.x, p0.z)
			await _sec(0.4)
			pts = pts.slice(1)
			first = false
		var ok := true
		for q in pts:
			if not _walk_to(xf * Vector3(q[0], 0, q[1])): ok = false
		var pp: Vector3 = main.player_pos
		var lp: Vector3 = xf.affine_inverse() * pp
		print("BSWALK %s %s reached=%s local=(%.2f, %.2f) foot=%.3f above_origin=%.3f ground=%.3f" % [id, leg[0], ok, lp.x, lp.z, pp.y, pp.y - xf.origin.y, main.world.ground_at(pp.x, pp.z) - xf.origin.y])
		main.player.set_anim("idle")
		if leg[2] != null:
			# 옆 앞에서 발 높이를 본다: 플레이어 자리 기준(로컬) 오른쪽 4.2m · 앞 3.4m · 높이 1.5m
			var cp: Vector3 = xf * Vector3(lp.x + 4.4, lp.y + 1.3, lp.z + 1.6)
			var lk: Vector3 = xf * Vector3(lp.x, lp.y + 0.5, lp.z - 0.2)
			main.rig.shot = { pos = cp, look = lk, fov = 40.0 }
			main.set_occ_script({ "focus": pp + Vector3(0, 0.9, 0), "r": 0.0, "near": 0.0 })   # 각본 시점: 집 흐리기 끔(발과 단이 보이게)
		else:
			main.rig.shot = null
			main.set_occ_script(null)
		await _sec(0.8)
		await _shot("%s_%s" % [id, leg[0]])
	# 방 안 서안(이야기 소품 story/clue seoan — 이야기가 놓는 자리·높이 그대로: 이겸 방 desk L(-0.6, -1.3), dy 0.4)를 놓고 마주 걸어 본다
	if id == "ig_house" and main.story == null:
		var info: Dictionary = load("res://kit/story/clue.gd").build({ kind = "seoan", seed = 3171 })
		var dp: Vector3 = xf * Vector3(-0.6, 0, -1.3)
		var n: Node3D = info.node
		main.scene_vp.add_child(n)
		var gy: float = main.world.height_base_at(dp.x, dp.z) if main.world.has_method("height_base_at") else main.world.height_at(dp.x, dp.z)
		n.global_transform = Transform3D(xf.basis, Vector3(dp.x, gy + 0.4, dp.z))
		var wcs := []
		if bool(info.get("block", false)):
			for c in info.colliders: wcs.append(main.world.add_dynamic_collider(c, n.global_transform))
		var s0: Vector3 = xf * Vector3(-0.6, 0, 0.6)
		main.teleport(s0.x, s0.z)
		await _sec(0.3)
		var ok := _walk_to(xf * Vector3(-0.6, 0, -1.7))
		var pp: Vector3 = main.player_pos
		var lp: Vector3 = xf.affine_inverse() * pp
		print("BSWALK %s seoan reached=%s local=(%.2f, %.2f) foot=%.3f above_origin=%.3f desk_y=%.3f cols=%d" % [id, ok, lp.x, lp.z, pp.y, pp.y - xf.origin.y, n.global_position.y - xf.origin.y, wcs.size()])
		main.rig.shot = null
		await _sec(0.8)
		await _shot("%s_seoan" % id)
		for wc in wcs: main.world.remove_dynamic_collider(wc)
		n.queue_free()
	# 높은 기단은 계단·댓돌 말고는 못 오른다(옆에서 곧장 걸어 들기)
	if plan.has("block"):
		var bk: Array = plan.block
		var b0: Vector3 = xf * Vector3(bk[0][0], 0, bk[0][1])
		main.teleport(b0.x, b0.z)
		await _sec(0.3)
		var ok := _walk_to(xf * Vector3(bk[1][0], 0, bk[1][1]))
		var pp: Vector3 = main.player_pos
		var lp: Vector3 = xf.affine_inverse() * pp
		print("BSWALK %s plinth_side reached=%s local=(%.2f, %.2f) foot=%.3f above_origin=%.3f" % [id, ok, lp.x, lp.z, pp.y, pp.y - xf.origin.y])
		main.rig.shot = { pos = xf * Vector3(bk[2][0], bk[2][1], bk[2][2]), look = xf * Vector3(bk[3][0], bk[3][1], bk[3][2]), fov = 38.0 }
		main.set_occ_script({ "focus": pp + Vector3(0, 0.9, 0), "r": 0.0, "near": 0.0 })
		await _sec(0.8)
		await _shot("%s_plinth_side" % id)
	main.rig.shot = null
	main.set_occ_script(null)

# 플레이어를 world.move_circle로 5cm씩(플레이어와 같은 판정) — 닿으면 true
func _walk_to(t: Vector3) -> bool:
	var w = main.world
	var pos: Vector3 = main.player_pos
	for i in 600:
		var v := Vector2(t.x - pos.x, t.z - pos.z)
		if v.length() < 0.06: break
		var st := v.normalized() * minf(0.05, v.length())
		var q = w.move_circle(pos, st.x, st.y, main.player.radius)
		if q == null:
			if main.args.has("bsdebug"):
				var nx := pos.x + st.x; var nz := pos.z + st.y
				print("BSDEBUG stuck at (%.2f,%.2f) h=%.3f -> h=%.3f floor=%s ground=%.3f blocked=%s r=%.2f" % [pos.x, pos.z, w.height_at(pos.x, pos.z), w.height_at(nx, nz), str(w._floor_at(nx, nz)) if w.has_method("_floor_at") else "-", w.ground_at(nx, nz), w.blocked(nx, nz, main.player.radius), main.player.radius])
			break
		pos = Vector3(q.x, w.height_at(q.x, q.z), q.z)
		main.player.facing = main.facing_from(st.x, st.y, main.player.facing)
	main.player_pos = pos
	main.player.position = pos
	return Vector2(t.x - pos.x, t.z - pos.z).length() < 0.1

func _goto(id: String) -> Variant:
	var at = _item_xz(id)
	if at == null: return null
	main.teleport(at.x + 0.0, at.y + 12.0)
	await _wait_load()
	await _sec(0.5)
	return _rec(id)

# 배치 파일에서 항목 자리·키트
var _items := {}
func _load_items() -> void:
	if not _items.is_empty(): return
	for f in main.placement.files():
		var d = JSON.parse_string(FileAccess.get_file_as_string(f))
		if not (d is Dictionary): continue
		for it in d.get("items", []):
			if it is Dictionary and it.has("id"): _items[String(it.id)] = it

func _item_xz(id: String) -> Variant:
	_load_items()
	var it = _items.get(id)
	if it == null: return null
	return Vector2(float(it.x), float(it.z))

func _kit_of(id: String) -> String:
	_load_items()
	return String(_items.get(id, {}).get("kit", ""))

# 초가 처마 모서리(앞 오른쪽)를 세 각도에서 — 플레이어는 집에서 멀리 두어 가림·실내 숨김이 지붕을 지우지 않게
func _corner_shots(id: String) -> void:
	var r = await _goto(id)
	if r == null: print("BSCORNER %s 없음" % id); return
	var xf: Transform3D = r.xf
	var it: Dictionary = _items.get(id, {})
	var P: Dictionary = it.get("params", {})
	var W := float(P.get("w", 6.0)); var D := float(P.get("d", 4.0))
	var kit := String(it.get("kit", ""))
	if kit == "village/choga_low": W = float(P.get("w", 6.0)); D = float(P.get("d", 4.0))
	var away: Vector3 = xf * Vector3(0, 0, D / 2 + 14.0)
	main.teleport(away.x, away.z)
	main.set_occ_script({ "focus": main.player_pos + Vector3(0, 0.9, 0), "r": 0.0, "near": 0.0 })   # 집 흐리기·카메라 앞 비우기 끔
	await _sec(0.6)
	var corner := Vector3(W / 2, 1.9, D / 2)
	var views := [["a", Vector3(1.0, 0.0, 1.0)], ["b", Vector3(1.0, 0.0, 0.35)], ["c", Vector3(0.35, 0.0, 1.0)]]
	for v in views:
		var dvec: Vector3 = (v[1] as Vector3).normalized()
		var cp: Vector3 = xf * (corner + dvec * 5.2 + Vector3(0, 0.9, 0))
		var lk: Vector3 = xf * (corner + Vector3(0, 0.15, 0))
		main.rig.shot = { pos = cp, look = lk, fov = 40.0 }
		await _sec(0.8)
		await _shot("%s_corner_%s" % [id, v[0]])
	main.rig.shot = { pos = xf * Vector3(W * 0.9, 9.0, D * 1.6 + 4.0), look = xf * Vector3(0, 1.4, 0), fov = 38.0 }
	await _sec(0.8)
	await _shot("%s_corner_top" % id)
	main.rig.shot = null
	main.set_occ_script(null)
