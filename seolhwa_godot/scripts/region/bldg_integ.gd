# 건물 빌더 통합 점검 — 묶음 하나(양반가, 안채·사랑채 실내 포함)를 모래상자 배치로 놓고
# 걷기(대문 → 마당 → 기단 계단 → 툇마루 → 대청·방), 충돌(벽·높은 기단 옆), 대화 카메라 구도, 1인칭, 먹 그늘 켬/끔을 기록·촬영한다.
#   godot --headless --path . -s res://tools/bldg/gallery_place.gd -- --set=integ
#   godot --path . res://scenes/region.tscn --resolution 1920x1080 -- --region=JL_NAMWON_UNBONG --placedir=res://shots/building_builder/_place_integ/ \
#     --bldginteg=shots/building_builder/integ --savefile=user://st_bldginteg.json --nostory --notitle --time=11 --weather=clear
# 줄 기록: BIWALK <구간> reached=… foot=… (집 바닥 기준) · BIBLOCK … · BITALK … · BIPASS n / BIFAIL n
extends RefCounted
const B := preload("res://kit/bldg/building.gd")
const CP := preload("res://kit/bldg/compound.gd")
const TalkFrame := preload("res://scripts/story/talk_frame.gd")
const CameraRig := preload("res://scripts/camera_rig.gd")

var main
var dir := ""
var passes := 0
var fails := 0

func _init(m) -> void:
	main = m

func _ok(c: bool, what: String) -> void:
	if c: passes += 1; print("BIOK   ", what)
	else: fails += 1; print("BIFAIL ", what)

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

func _shot(nm: String) -> void:
	main._save(dir.path_join(nm + ".png"))

# 플레이어 판정(move_circle) 5cm 걸음 — 닿으면 true
func _walk_to(t: Vector3) -> bool:
	var w = main.world
	var pos: Vector3 = main.player_pos
	for i in 1200:
		var v := Vector2(t.x - pos.x, t.z - pos.z)
		if v.length() < 0.06: break
		var st := v.normalized() * minf(0.05, v.length())
		var q = w.move_circle(pos, st.x, st.y, main.player.radius)
		if q == null:
			var why := "slope/step"
			if w.blocked(pos.x + st.x, pos.z + st.y, main.player.radius):
				why = "collider r=%.2f" % main.player.radius
				for c in w.colliders:
					if c.type != "circle" and Vector2(pos.x + st.x - clampf(pos.x + st.x, c.minX, c.maxX), pos.z + st.y - clampf(pos.z + st.y, c.minZ, c.maxZ)).length() < main.player.radius:
						why += " box(%.2f..%.2f,%.2f..%.2f)" % [c.minX, c.maxX, c.minZ, c.maxZ]
					elif c.type == "circle" and Vector2(pos.x + st.x - c.x, pos.z + st.y - c.z).length() < main.player.radius + c.r:
						why += " circ(%.2f,%.2f r%.2f)" % [c.x, c.z, c.r]
			print("BISTALL at=(%.2f,%.2f) to=(%.2f,%.2f) %s h=%.2f→%.2f" % [pos.x, pos.z, t.x, t.z, why, w.height_at(pos.x, pos.z), w.height_at(pos.x + st.x, pos.z + st.y)])
			break
		pos = Vector3(q.x, w.height_at(q.x, q.z), q.z)
		main.player.facing = main.facing_from(st.x, st.y, main.player.facing)
	main.player_pos = pos
	main.player.position = pos
	return Vector2(t.x - pos.x, t.z - pos.z).length() < 0.12

func run(spec: String) -> void:
	dir = main._abs(spec if spec != "1" else "shots/building_builder/integ")
	var mpath := ""
	for d in String(main.args.get("placedir", "")).split(";", false):
		if FileAccess.file_exists(d.path_join("manifest.json")): mpath = d.path_join("manifest.json")
	var man = JSON.parse_string(FileAccess.get_file_as_string(mpath))
	var it: Dictionary = man.items[0]
	var C0 := Vector3(float(it.x), 0, float(it.z))
	var plan := CP.plan(it.params)
	var pcs := {}
	for e in plan.pieces: pcs[e.tag] = e
	main.set_first_person(false, false)
	main.teleport(C0.x, C0.z + float(it.fp[1]) / 2 + 4.0)
	await _wait_load()
	await _sec(1.0)
	var base_y: float = main.world.height_base_at(C0.x, C0.z) if main.world.has_method("height_base_at") else main.world.height_at(C0.x, C0.z)
	# 조각 → 월드 변환, 앵커
	var info := {}
	for tag in ["anchae", "sarang", "haengrang"]:
		var e: Dictionary = pcs[tag]
		var r := B.build(e.params)
		var xf := Transform3D(Basis(Vector3.UP, float(e.ry)), C0 + Vector3(float(e.x), 0, float(e.z)))
		info[tag] = { xf = xf, an = r.anchors, sp = e.params }
		r.node.free()
	var foot := func() -> float: return main.player_pos.y - base_y
	# 1) 대문(행랑채 대문간) 지나 마당으로
	var gate: Vector3 = info.haengrang.xf.origin
	var hsp := preload("res://kit/bldg/_spec.gd").resolve(info.haengrang.sp)
	var gi: int = int(hsp.get("gate_i", 0))
	var bays: Array = hsp.wings[0].bays
	var Lh := 0.0
	for b in bays: Lh += float(b.w)
	var acc := 0.0
	for i in gi: acc += float(bays[i].w)
	var gx: float = gate.x - Lh / 2 + acc + float(bays[gi].w) / 2
	main.teleport(gx, gate.z + 5.0)
	await _sec(0.6)
	var ok_gate := _walk_to(Vector3(gx, 0, gate.z - 4.0))
	print("BIWALK gate reached=%s foot=%.2f" % [ok_gate, foot.call()])
	_ok(ok_gate, "행랑채 대문간을 지나 마당으로 들어간다")
	main.rig.shot = { pos = Vector3(gx + 3.5, base_y + 2.2, gate.z + 1.0), look = Vector3(gx, base_y + 1.2, gate.z - 3.0), fov = 45.0 }
	await _sec(0.8); _shot("01_gate_passage")
	main.rig.shot = null
	# 2) 사랑채: 계단 발치 → 계단 → 툇마루 → 대청
	var sa: Dictionary = info.sarang
	var sxf: Transform3D = sa.xf
	var steps = sa.an.get("steps")
	var maru = sa.an.get("maru")
	var dae = sa.an.get("daecheong")
	if steps != null:
		var p0: Vector3 = sxf * (steps as Vector3)
		_walk_to(p0)
		var y_ground: float = foot.call()
		var pm: Vector3 = sxf * Vector3((steps as Vector3).x, 0, (maru as Vector3).z if maru != null else 2.0)
		var ok := _walk_to(pm)
		var y_maru: float = foot.call()
		var lq: Vector3 = sxf.affine_inverse() * main.player_pos
		print("BIWALK sarang_steps→maru reached=%s ground=%.2f maru=%.2f local=(%.2f,%.2f) target_z=%.2f" % [ok, y_ground, y_maru, lq.x, lq.z, (maru as Vector3).z if maru != null else 0.0])
		if not ok:
			var prof := ""
			for k in 24:
				var q: Vector3 = sxf * Vector3(lq.x, 0, 3.6 - k * 0.1)
				prof += "%.1f:%.2f/%s " % [3.6 - k * 0.1, main.world.height_at(q.x, q.z) - base_y, "B" if main.world.blocked(q.x, q.z, main.player.radius) else "-"]
			print("BIDBG prof ", prof, " r=", main.player.radius)
			var nx: Vector3 = main.player_pos + sxf.basis * Vector3(0, 0, -0.06)
			print("BIDBG h_here=%.3f h_next=%.3f blocked=%s floor_next=%s" % [main.world.height_at(main.player_pos.x, main.player_pos.z), main.world.height_at(nx.x, nx.z), main.world.blocked(nx.x, nx.z, main.player.radius), str(main.world._floor_at(nx.x, nx.z))])
		_ok(ok and y_maru - y_ground > 0.5, "사랑채 계단으로 높은 기단·툇마루에 오른다(발 높이 %.2f → %.2f)" % [y_ground, y_maru])
		main.rig.shot = { pos = main.player_pos + sxf.basis * Vector3(3.6, 1.6, 4.2), look = main.player_pos + Vector3(0, 0.6, 0), fov = 40.0 }
		main.set_occ_script({ "focus": main.player_pos + Vector3(0, 0.9, 0), "r": 0.0, "near": 0.0 })
		await _sec(0.8); _shot("02_sarang_maru_feet")
		if dae != null:
			var ok2 := _walk_to(sxf * (dae as Vector3))
			print("BIWALK sarang_daecheong reached=%s foot=%.2f" % [ok2, foot.call()])
			_ok(ok2, "툇마루에서 대청 마루로 들어선다(발 %.2f)" % foot.call())
			main.rig.shot = { pos = main.player_pos + sxf.basis * Vector3(2.8, 1.8, 4.0), look = main.player_pos + Vector3(0, 0.7, -0.5), fov = 42.0 }
			await _sec(0.8); _shot("03_sarang_daecheong")
		main.rig.shot = null; main.set_occ_script(null)
	# 3) 높은 기단 옆에서 곧장: 막혀야(계단 없는 쪽)
	var an: Dictionary = info.anchae
	var axf: Transform3D = an.xf
	var asp := preload("res://kit/bldg/_spec.gd").resolve(an.sp)
	var aw: Dictionary = asp.wings[0]
	var La := 0.0
	for b in aw.bays: La += float(b.w)
	var Da := 0.0
	for d in aw.depth: Da += float(d)
	var side0: Vector3 = axf * Vector3(-La / 2 + 0.4, 0, Da / 2 + 3.0)
	main.teleport(side0.x, side0.z)
	await _sec(0.4)
	var hit := _walk_to(axf * Vector3(-La / 2 + 0.4, 0, 0.0))
	var lp: Vector3 = axf.affine_inverse() * main.player_pos
	print("BIBLOCK anchae_plinth_side reached=%s local_z=%.2f foot=%.2f base_h=%.2f" % [hit, lp.z, foot.call(), float(asp.base.h)])
	_ok(not hit and foot.call() < 0.2, "안채 높은 기단(%.2fm) 옆에서는 곧장 오르지 못한다" % float(asp.base.h))
	# 4) 안채 앞 계단 → 대청 → 안방(실내: 지붕·앞벽 숨김 + 실내 카메라)
	var ast = an.an.get("steps")
	var adae = an.an.get("daecheong")
	if ast != null and adae != null:
		main.teleport((axf * (ast as Vector3)).x, (axf * (ast as Vector3)).z)
		await _sec(0.4)
		var ok3 := _walk_to(axf * Vector3((ast as Vector3).x, 0, Da / 2 + 0.3))
		var ok4 := _walk_to(axf * (adae as Vector3))
		print("BIWALK anchae_daecheong reached=%s foot=%.2f" % [ok3 and ok4, foot.call()])
		_ok(ok3 and ok4, "안채 계단 → 툇마루 → 대청(발 %.2f)" % foot.call())
		# 안방: 대청 옆 방 가운데로(문 열림)
		# 대청(adae)과 맞닿은 방 칸(가장 가까운 방)
		var x := -La / 2; var room_x := 0.0; var room_x0 := 0.0; var room_x1 := 0.0
		var best := INF
		for b in aw.bays:
			if b.fn == "room":
				var cxr := x + float(b.w) / 2
				if absf(cxr - (adae as Vector3).x) < best: best = absf(cxr - (adae as Vector3).x); room_x = cxr; room_x0 = x; room_x1 = x + float(b.w)
			x += float(b.w)
		print("BIDBG bays=%s" % str(aw.bays.map(func(b): return "%s:%.2f" % [b.fn, float(b.w)])))
		# 대청 가운데 → 칸막이 문(가운데 0.9m 트임) → 방 가운데
		#   칸막이 문은 날개 로컬 z=0(날개 깊이 가운데)에 난다 — 툇마루가 있는 날개는 집 로컬과 z가 어긋나므로 문 줄을 앞뒤로 찾아 든다
		var ok5 := false
		var p_dae: Vector3 = main.player_pos
		for dz in [0.0, 0.42, -0.42, 0.8, -0.8]:
			main.player_pos = p_dae; main.player.position = p_dae
			if not _walk_to(axf * Vector3((adae as Vector3).x, 0, dz)): continue
			_walk_to(axf * Vector3(room_x, 0, dz))
			# 방 가운데에 보료·서안이 올 수 있다 — 방 칸 안(칸막이를 0.3m 넘게 지남)이면 든 것
			var lpr: Vector3 = axf.affine_inverse() * main.player_pos
			print("BIDBG dz=%.2f end_local=(%.2f,%.2f) world=(%.2f,%.2f)" % [dz, lpr.x, lpr.z, main.player_pos.x, main.player_pos.z])
			if lpr.x > room_x0 + 0.3 and lpr.x < room_x1 - 0.3: ok5 = true; break
		print("BIDBG room_x=%.2f La=%.2f Da=%.2f local=%s" % [room_x, La, Da, str(axf.affine_inverse() * main.player_pos)])
		var ok6 := ok5
		var room_stop: Vector3 = main.player_pos
		if not ok6 and ok5:
			# 실제 크기로 방이 넓어져 방 가운데에 가구(보료·서안)가 올 수 있다 — 방 칸 안 다른 자리로(문 쪽 가까이)
			for alt in [Vector3(room_x, 0, 0.6), Vector3(room_x + 0.7, 0, 0.0), Vector3(room_x - 0.7, 0, 0.0)]:
				main.player_pos = room_stop; main.player.position = room_stop
				if _walk_to(axf * alt): ok6 = true; break
		var inn = main.world.interior_at(main.player_pos.x, main.player_pos.z)
		print("BIWALK anchae_room reached=%s interior=%s foot=%.2f" % [ok6, inn != null, foot.call()])
		_ok(ok6 and inn != null, "대청에서 칸막이 문으로 안방에 들어서고(발 %.2f), 실내(잘라 보기) 상자 안이다" % foot.call())
		await _sec(1.2); _shot("04_anchae_room_cutaway")
		main.set_first_person(true, false)
		main.fp_yaw = 0.0; main.fp_pitch = deg_to_rad(-10.0)
		await _sec(0.8); _shot("05_anchae_room_fp")
		main.set_first_person(false, false)
		# 5) 벽 충돌: 방 안에서 뒷벽 쪽으로
		var ok7 := _walk_to(axf * Vector3(room_x, 0, -Da / 2 - 1.0))
		var lp2: Vector3 = axf.affine_inverse() * main.player_pos
		print("BIBLOCK anchae_backwall reached=%s local_z=%.2f" % [ok7, lp2.z])
		_ok(not ok7 and lp2.z > -Da / 2 - 0.05, "방 뒷벽(가구)에 막힌다(로컬 z %.2f)" % lp2.z)
	# 6) 대화 카메라: 안채 툇마루에 앉은 이와 마당의 플레이어
	var am = an.an.get("maru")
	if am != null:
		var npc_p: Vector3 = axf * (am as Vector3)
		var npc_y: float = main.world.height_at(npc_p.x, npc_p.z)
		var who := _spawn_npc(Vector3(npc_p.x, npc_y, npc_p.z))
		main.teleport(npc_p.x + 1.6, npc_p.z + 3.0)
		await _sec(0.5)
		var tf = TalkFrame.new({ main = main })
		var pl: Dictionary = tf.plan(Vector3(npc_p.x, npc_y, npc_p.z), 1.6, true, CameraRig.TALK)
		print("BITALK phase=%s overlap=%.2f occ_npc=%d occ_player=%d stand=%s yaw=%.1f" % [pl.phase, pl.overlap, pl.occ_npc, pl.occ_player, str(pl.stand), rad_to_deg(pl.yaw)])
		if pl.stand != null:
			main.player_pos = Vector3(pl.stand.x, main.world.height_at(pl.stand.x, pl.stand.y), pl.stand.y); main.player.position = main.player_pos
		var foc: Vector2 = pl.focus
		var cp: Vector3 = tf._cam_pos(foc, pl.yaw, pl.pitch, pl.distance)
		main.rig.shot = { pos = cp, look = Vector3(foc.x, main.world.height_at(foc.x, foc.y) + 0.9, foc.y), fov = pl.fov }
		main.set_occ_script(TalkFrame.occ_spec(main.player_pos, 1.6, Vector3(npc_p.x, npc_y, npc_p.z), 1.6))
		_ok(pl.phase != "overlap", "대화 구도가 겹침 없이 잡힌다(%s)" % pl.phase)
		await _sec(1.0); _shot("06_talk_camera")
		main.rig.shot = null; main.set_occ_script(null)
		if who: who.queue_free()
	# 7) 먹 그늘 켬/끔(같은 마을 카메라 시점)
	var look := C0 + Vector3(0, base_y + 1.5, 0)
	var cp2 := look + Vector3(0, sin(deg_to_rad(22.0)), cos(deg_to_rad(22.0))) * 30.0
	main.teleport(C0.x, C0.z + 6.0)
	await _sec(0.5)
	main.rig.shot = { pos = cp2, look = look, fov = 30.0 }
	var ao0: float = main.post.ao_strength
	await _sec(0.8); _shot("07_ao_on")
	var ao_drawn: bool = main.post.ao_ok
	main.args["ao"] = "0"; main.post.ao_strength = 0.0
	await _sec(0.8); _shot("08_ao_off")
	main.args.erase("ao"); main.post.ao_strength = ao0
	_ok(ao0 > 0.0 and ao_drawn, "먹 그늘이 켜진 채 그려진다(세기 %.2f)" % ao0)
	main.rig.shot = null
	print("BIPASS %d" % passes if fails == 0 else "BIFAIL %d (pass %d)" % [fails, passes])
	main._quit()

func _spawn_npc(p: Vector3) -> Node3D:
	var SC = load("res://scripts/sprite_char.gd")
	for k in ["elder", "villager_f", "villager_m", "innkeeper"]:
		if SC._banks.has(k):
			var ch = SC.new(k)
			main.scene_vp.add_child(ch)
			ch.position = p
			ch.set_facing("down")
			return ch
	return null
