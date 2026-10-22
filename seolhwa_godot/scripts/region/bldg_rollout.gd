# 건물 빌더 세계 반영(rollout) 점검 — region_main --bldgrollout=<시점 목록 json>. 시험 저장으로만(--savefile), 창 필요.
#   godot --path . res://scenes/region.tscn --resolution 1920x1080 -- --region=JL_NAMWON_UNBONG --bldgrollout=res://tools/bldg/rollout_views.json \
#     --brset=west --brtag=after --savefile=user://st_bldgrollout.json --kitcache=/tmp/seolhwa_bldg_kit_cache/ --nostory --notitle --time=11 --weather=clear --nodof
#   시점 목록(json): { sets: { <이름>: { views: [ {id, label, mode, x, z, yaw?, pitch?, dist?, h?} ], walks: [ {id, label, pts: [[x,z]…], shots: [k…]} ],
#                                       gates: { bbox: [x0,z0,x1,z1] } } } }
#     mode  town  게임 카메라 그대로(고을 안 = 마을 구도 22°·×0.64)   std  기본 카메라(40°, 22m)   fp  1인칭(yaw: 0 = 북, +90 = 동)
#           over  높은 내려다보기(dist·pitch, 안개 끔 — 구역 전체 확인용)
#   --brtag=before|after  낱장 이름 뒤에 붙인다(shots/building_rollout/raw/<set>_<id>_<tag>.png)   --brnoshots  걷기 점검만
#   gates: 그 범위의 bldg/compound 묶음마다 대문 밖 6m → 문지방 → 마당 안 3m를 플레이어 판정(move_circle 5cm 걸음)으로 걷고,
#          옆 담 밖에서 마당 가운데로 곧장 걸어 담에 막히는지 본다. 줄: BRGATE <id> in=… blocked_side=… foot=…
#   끝 줄: BRPASS n / BRFAIL n
extends RefCounted
const CP := preload("res://kit/bldg/compound.gd")
const GT := preload("res://kit/bldg/gate.gd")

var main
var dir := ""
var tag := "after"
var passes := 0
var fails := 0

func _init(m) -> void:
	main = m

func _ok(c: bool, what: String) -> void:
	if c: passes += 1; print("BROK   ", what)
	else: fails += 1; print("BRFAIL ", what)

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
	var path: String = spec if spec != "1" else "res://tools/bldg/rollout_views.json"
	var all = JSON.parse_string(FileAccess.get_file_as_string(path))
	var setname: String = main.args.get("brset", "west")
	var S: Dictionary = all.sets[setname]
	tag = main.args.get("brtag", "after")
	dir = main._abs(main.args.get("brout", "shots/building_rollout/raw"))
	DirAccess.make_dir_recursive_absolute(dir)
	main.set_first_person(false, false)
	var v0: Dictionary = S.views[0] if S.has("views") and not S.views.is_empty() else { x = 0, z = 0 }
	main.teleport(float(v0.x), float(v0.z))
	await _wait_load()
	await _sec(1.0)
	if main.args.has("brprobe"):   # 막힘 격자 찍기(디버그): --brprobe=x0,z0,x1,z1
		var q: PackedStringArray = String(main.args.brprobe).split(",")
		main.teleport(float(q[0]), float(q[1])); await _wait_load()
		var z := float(q[1])
		while z <= float(q[3]):
			var line := ""
			var x := float(q[0])
			while x <= float(q[2]):
				line += "#" if main.world.blocked(x, z, main.player.radius) else "."
				x += 0.25
			print("BRPROBE %.2f %s" % [z, line]); z += 0.25
		var w = main.world
		var px := (float(q[0]) + float(q[2])) / 2; var pz := (float(q[1]) + float(q[3])) / 2
		print("BRPROBE at (%.1f,%.1f) blocked=%s river=%s pond=%s" % [px, pz, w.blocked(px, pz, main.player.radius), w._in_river(px, pz, main.player.radius) and not w._near_crossing(px, pz), (not w._ponds.is_empty()) and w.in_pond(px, pz)])
		var ci := floori(px / w.GRID); var cj := floori(pz / w.GRID)
		for j in range(cj - 1, cj + 2):
			for i in range(ci - 1, ci + 2):
				for c in w._static_grid.get(Vector2i(i, j), []):
					if w._hit(c, px, pz, main.player.radius): print("BRPROBE hit ", str(c).substr(0, 300))
	if not main.args.has("brnoshots"):
		for v in S.get("views", []): await _view(setname, v)
		for w in S.get("walks", []): await _walk(setname, w)
	if S.has("gates"): await _gates(S.gates)
	print("BRPASS %d / BRFAIL %d" % [passes, fails])
	print("BRDONE")
	main._quit()

func _shot(nm: String) -> void:
	main._save(dir.path_join("%s_%s.png" % [nm, tag]))

func _view(setname: String, v: Dictionary) -> void:
	var x := float(v.x); var z := float(v.z)
	main.rig.shot = null; main.rig.override = null
	main.set_first_person(false, false)
	main.teleport(x, z)
	main.player.facing = String(v.get("facing", "up"))
	await _wait_load()
	var mode: String = v.get("mode", "town")
	match mode:
		"std": main.rig.override = { distance = 22.0, pitch = 40.0, fov = 30.0 }
		"fp":
			main.set_first_person(true, false)
			main.fp_yaw = deg_to_rad(float(v.get("yaw", 0.0))); main.fp_pitch = deg_to_rad(float(v.get("pitch", 3.0)))
		"over":
			var gy: float = main.world.height_at(x, z)
			var look := Vector3(x, gy + 1.0, z)
			var pd := deg_to_rad(float(v.get("pitch", 45.0))); var yw := deg_to_rad(float(v.get("yaw", 0.0)))
			var d := float(v.get("dist", 70.0))
			main.rig.shot = { pos = look + Vector3(sin(yw) * cos(pd), sin(pd), cos(yw) * cos(pd)) * d, look = look, fov = float(v.get("fov", 30.0)) }
			main.set_occ_script({ "focus": look, "r": 0.0, "near": 0.0 })
			main.fog_on = bool(v.get("fog", false)); main._apply_time()
	if v.get("gaze", false): main.args["gazetest"] = "1"   # 바라보기(integ-mountain) — 누르고 있는 것처럼, 다 들 때까지 기다린다
	main.rig.update(0, main.player_pos, main.player.facing, null, true)
	await _sec(float(v.get("wait", 2.0 if v.get("gaze", false) else 1.2)))
	_shot("%s_%s" % [setname, String(v.id)])
	main.args.erase("gazetest")
	print("BRSHOT %s_%s mode=%s at=(%.1f,%.1f) fps=%.0f tris=%dk zone=%s pitch=%.1f dist=%.1f tilt=%.1f gaze=%.2f lift=%.1f camdy=%.1f" % [setname, v.id, mode, x, z, Engine.get_frames_per_second(), RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME) / 1000,
		main.rig.zone_name, main.rig.cur.pitch, main.rig.cur.distance, float(main.rig.cur.get("tilt", 0.0)), float(main.rig.get("gaze") if main.rig.get("gaze") != null else 0.0), float(main.rig.get("_lift") if main.rig.get("_lift") != null else 0.0), main.cam.global_position.y - main.player_pos.y])
	if mode == "over":
		main.set_occ_script(null); main.fog_on = true; main._apply_time()
	main.rig.shot = null; main.rig.override = null
	main.set_first_person(false, false)

# 길 걷기(게임 카메라 그대로): 점마다 걸어서 닿았나 기록, shots에 든 마디에서 찍는다(마을 카메라 + 같은 자리 1인칭)
func _walk(setname: String, w: Dictionary) -> void:
	var pts: Array = w.pts
	main.set_first_person(false, false)
	main.teleport(float(pts[0][0]), float(pts[0][1]))
	await _wait_load(); await _sec(0.6)
	var shots: Array = w.get("shots", [])
	for k in pts.size():
		var t := Vector3(float(pts[k][0]), 0, float(pts[k][1]))
		var ok := true if k == 0 else await _walk_live(t)
		print("BRWALK %s %d reached=%s at=(%.1f,%.1f) foot=%.2f" % [w.id, k, ok, main.player_pos.x, main.player_pos.z, main.player_pos.y - main.world.height_at(main.player_pos.x, main.player_pos.z)])
		_ok(ok, "%s 걷기 마디 %d 닿음" % [w.id, k])
		if shots.has(k) or shots.has(float(k)):
			await _sec(0.5)
			_shot("%s_%s_%d_town" % [setname, w.id, k])
			if k + 1 < pts.size():
				var d := Vector2(float(pts[k + 1][0]) - main.player_pos.x, float(pts[k + 1][1]) - main.player_pos.z)
				main.set_first_person(true, false)
				main.fp_yaw = atan2(d.x, -d.y) + deg_to_rad(float(w.get("fp_turn", 0.0))); main.fp_pitch = deg_to_rad(3.0)
				await _sec(0.7)
				_shot("%s_%s_%d_fp" % [setname, w.id, k])
				main.set_first_person(false, false)
				await _sec(0.3)

# 화면을 돌리며 걷는다(걸음마다 한 프레임 — 카메라·가림이 게임처럼 따라온다)
func _walk_live(t: Vector3) -> bool:
	var w = main.world
	for i in 4000:
		var pos: Vector3 = main.player_pos
		var v := Vector2(t.x - pos.x, t.z - pos.z)
		if v.length() < 0.08: break
		var st := v.normalized() * minf(0.09, v.length())
		var q = w.move_circle(pos, st.x, st.y, main.player.radius)
		if q == null or Vector2(q.x - pos.x, q.z - pos.z).length() < 0.004:
			_stall_why(pos, st)
			break
		main.player_pos = Vector3(q.x, w.height_at(q.x, q.z), q.z)
		main.player.position = main.player_pos
		main.player.facing = main.facing_from(st.x, st.y, main.player.facing)
		if i % 2 == 0: await main._wait_frames(1)
	return Vector2(t.x - main.player_pos.x, t.z - main.player_pos.z).length() < 0.2

# 막힌 까닭(점검 기록): 충돌체(가장 가까운 것) 또는 비탈
func _stall_why(pos: Vector3, st: Vector2) -> void:
	var w = main.world
	var tx := pos.x + st.x; var tz := pos.z + st.y
	var r: float = main.player.radius
	var why := "?"
	if w.blocked(tx, tz, r):
		if w.has_method("_in_river") and w._in_river(tx, tz, r): why = "river"
		elif w.has_method("in_pond") and w.in_pond(tx, tz): why = "pond"
		elif w.has_method("tile_of"):
			var sg = w._scatter_grid.get(w.tile_of(tx, tz))
			if sg != null:
				for k in [Vector2i(floori(tx / w.GRID), floori(tz / w.GRID))]:
					for j in range(-1, 2):
						for i in range(-1, 2):
							for c in sg.get(k + Vector2i(i, j), []):
								if not c.get("off", false) and w._hit(c, tx, tz, r): why = "scatter %s" % str(c).left(120)
		for c in w.colliders:
			var hit := false
			if c.type == "circle": hit = Vector2(tx - c.x, tz - c.z).length() < r + c.r
			else: hit = Vector2(tx - clampf(tx, c.minX, c.maxX), tz - clampf(tz, c.minZ, c.maxZ)).length() < r
			if hit:
				why = "collider %s %s" % [c.type, str(c.get("tag", c.get("name", c.get("id", ""))))]
				if c.type == "circle": why += " at=(%.1f,%.1f) r=%.2f" % [c.x, c.z, c.r]
				else: why += " box=(%.1f..%.1f, %.1f..%.1f)" % [c.minX, c.maxX, c.minZ, c.maxZ]
				break
	else:
		why = "slope dh=%.2f over %.2f" % [w.height_at(tx, tz) - w.height_at(pos.x, pos.z), st.length()]
	print("BRSTALL at=(%.1f,%.1f) %s" % [pos.x, pos.z, why])

func _walk_to(t: Vector3) -> bool:
	var w = main.world
	var pos: Vector3 = main.player_pos
	for i in 2400:
		var v := Vector2(t.x - pos.x, t.z - pos.z)
		if v.length() < 0.06: break
		var st := v.normalized() * minf(0.05, v.length())
		var q = w.move_circle(pos, st.x, st.y, main.player.radius)
		if q == null:
			_stall_why(pos, st)
			break
		pos = Vector3(q.x, w.height_at(q.x, q.z), q.z)
	main.player_pos = pos
	main.player.position = pos
	return Vector2(t.x - pos.x, t.z - pos.z).length() < 0.15

# 묶음 대문 걷기 · 옆 담 막힘
func _gates(g: Dictionary) -> void:
	var bb: Array = g.bbox
	var files := [String(g.get("file", "res://region_data/JL_NAMWON_UNBONG/placement_namwon.json"))]
	for f in files:
		var d = JSON.parse_string(FileAccess.get_file_as_string(f))
		for it in d.items:
			if not String(it.kit) in ["bldg/compound", "bldg/lot"]: continue
			var x := float(it.x); var z := float(it.z)
			if x < float(bb[0]) or x > float(bb[2]) or z < float(bb[1]) or z > float(bb[3]): continue
			if String(it.kit) == "bldg/lot": await _lot_item(it)
			else: await _gate_item(it)

# 고을 짜임 필지(bldg/lot, town-organic): 대문 밖 1.6m → 문지방 → 마당 안 3m(내외담이면 옆으로 돌아) · 뒷담 밖 1.5m → 필지 가운데: 막혀야
func _lot_item(it: Dictionary) -> void:
	var id: String = it.id
	var C0 := Vector2(float(it.x), float(it.z))
	var ry := float(it.get("ry", 0.0))
	var rot := func(v: Vector2) -> Vector2: return C0 + Vector2(v.x * cos(ry) + v.y * sin(ry), -v.x * sin(ry) + v.y * cos(ry))
	var gate := {}
	for e in it.params.get("pieces", []):
		if String(e.tag) == "gate": gate = e
	var poly: Array = it.params.get("poly", [])
	var cen := Vector2.ZERO
	for q in poly: cen += Vector2(float(q[0]), float(q[1]))
	cen /= maxf(1.0, poly.size())
	if not gate.is_empty():
		var gl := Vector2(float(gate.x), float(gate.z)); var gry := float(gate.ry)
		var dir := Vector2(sin(gry), cos(gry))   # 문 로컬 +z = 바깥(길)
		var out: Vector2 = rot.call(gl + dir * 1.6)
		var thr: Vector2 = rot.call(gl)
		var inn: Vector2 = rot.call(gl - dir * 3.0)
		main.set_first_person(false, false)
		main.teleport(out.x, out.y)
		await _wait_load(); await _sec(0.3)
		var y0: float = main.world.height_at(out.x, out.y)
		var a := _walk_to(Vector3(thr.x, 0, thr.y))
		var foot_thr: float = main.player_pos.y - y0
		var b := _walk_to(Vector3(inn.x, 0, inn.y))
		var detour := ""
		if a and not b:
			var side := Vector2(dir.y, -dir.x)
			for sx in [1.0, -1.0]:
				main.player_pos = Vector3(thr.x, main.world.height_at(thr.x, thr.y), thr.y)
				var s1: Vector2 = rot.call(gl - dir * 1.0)
				var s2: Vector2 = rot.call(gl - dir * 1.2 + side * sx * 2.4)
				var s3: Vector2 = rot.call(gl - dir * 4.0 + side * sx * 2.4)
				if _walk_to(Vector3(s1.x, 0, s1.y)) and _walk_to(Vector3(s2.x, 0, s2.y)) and _walk_to(Vector3(s3.x, 0, s3.y)):
					b = true; detour = "옆으로 돌아"; break
		print("BRGATE %s(%s) gate_world=(%.1f,%.1f) to_threshold=%s in=%s foot_thr=%.2f end=(%.1f,%.1f) %s" % [id, String(it.params.get("type", "")), thr.x, thr.y, a, b, foot_thr, main.player_pos.x, main.player_pos.z, detour])
		_ok(a and b, "%s 대문 밖 → 문지방 → 마당 안" % id)
	if int((it.get("organic", {}) as Dictionary).get("walls", 0)) > 0 and poly.size() >= 4 and not String(it.params.get("type", "")) in ["hut", "field", "shop"]:
		# 뒷변(앞 변 반대쪽 = 마지막 변: b1 → b0) 가운데 밖 1.5m에서 필지 가운데로
		var n := poly.size()
		var pa := Vector2(float(poly[n - 2][0]), float(poly[n - 2][1])); var pb := Vector2(float(poly[n - 1][0]), float(poly[n - 1][1]))
		var mid := (pa + pb) / 2.0
		var outv := (mid - cen).normalized()
		var sw: Vector2 = rot.call(mid + outv * 1.5)
		var mc: Vector2 = rot.call(cen)
		main.teleport(sw.x, sw.y)
		await _sec(0.2)
		var blocked_start: bool = main.world.blocked(sw.x, sw.y, main.player.radius)
		var c := _walk_to(Vector3(mc.x, 0, mc.y))
		print("BRGATE %s back_wall from=(%.1f,%.1f) start_blocked=%s crossed=%s" % [id, sw.x, sw.y, blocked_start, c])
		if not blocked_start: _ok(not c, "%s 뒷담을 뚫고 지나가지 않음" % id)

static func gate_local(params: Dictionary) -> Vector2:
	var p := CP.plan(params)
	for e in p.pieces:
		if String(e.tag) == "gate": return Vector2(float(e.x), float(e.z))
	for e in p.pieces:
		if String(e.tag) == "haengrang":
			var sp := preload("res://kit/bldg/_spec.gd").resolve(e.params)
			var bays: Array = sp.wings[0].bays
			var Lh := 0.0
			for b in bays: Lh += float(b.w)
			var gi := int(sp.get("gate_i", 0))
			var acc := 0.0
			for i in gi: acc += float(bays[i].w)
			var D := 0.0
			for dd in sp.wings[0].depth: D += float(dd)
			return Vector2(float(e.x) - Lh / 2 + acc + float(bays[gi].w) / 2, float(e.z) + D / 2)
	return Vector2(0, p.fp.y / 2 - 0.5)

func _gate_item(it: Dictionary) -> void:
	var id: String = it.id
	var C0 := Vector2(float(it.x), float(it.z))
	var ry := float(it.get("ry", 0.0))
	var gl := gate_local(it.params)
	var fp: Vector2 = CP.footprint(it.params)
	var rot := func(v: Vector2) -> Vector2: return C0 + Vector2(v.x * cos(ry) + v.y * sin(ry), -v.x * sin(ry) + v.y * cos(ry))
	var out: Vector2 = rot.call(gl + Vector2(0, float(main.args.get("brgateout", "1.6"))))
	var thr: Vector2 = rot.call(gl + Vector2(0, 0.0))
	var inn: Vector2 = rot.call(gl + Vector2(0, -3.0))
	main.set_first_person(false, false)
	main.teleport(out.x, out.y)
	await _wait_load(); await _sec(0.3)
	var y0: float = main.world.height_at(out.x, out.y)
	var a := _walk_to(Vector3(thr.x, 0, thr.y))
	var foot_thr: float = main.player_pos.y - y0
	var b := _walk_to(Vector3(inn.x, 0, inn.y))
	var detour := ""
	if a and not b:
		# 문 안 내외담: 옆으로 돌아 들어간다(곧장 못 들어가는 게 맞다)
		for sx in [1.0, -1.0]:
			var thp := Vector3(thr.x, 0, thr.y)
			main.player_pos = Vector3(thp.x, main.world.height_at(thp.x, thp.z), thp.z)
			var s1: Vector2 = rot.call(gl + Vector2(0, -1.0))
			var s2: Vector2 = rot.call(gl + Vector2(sx * 2.4, -1.2))
			var s3: Vector2 = rot.call(gl + Vector2(sx * 2.4, -4.4))
			if _walk_to(Vector3(s1.x, 0, s1.y)) and _walk_to(Vector3(s2.x, 0, s2.y)) and _walk_to(Vector3(s3.x, 0, s3.y)):
				b = true; detour = "내외담 옆(%s)" % ("동" if sx > 0 else "서"); break
	print("BRGATE %s gate_world=(%.1f,%.1f) to_threshold=%s in=%s foot_thr=%.2f end=(%.1f,%.1f) %s" % [id, thr.x, thr.y, a, b, foot_thr, main.player_pos.x, main.player_pos.z, detour])
	_ok(a and b, "%s 대문 밖 → 문지방 → 마당 안" % id)
	# 옆 담 밖(묶음 옆 +x 쪽 2m 밖)에서 마당 가운데로 → 막혀야
	var side: Vector2 = rot.call(Vector2(fp.x / 2 + 1.5, 0.0))
	var mid: Vector2 = rot.call(Vector2(fp.x / 2 - 3.0, 0.0))
	main.teleport(side.x, side.y)
	await _sec(0.2)
	var blocked_start: bool = main.world.blocked(side.x, side.y, main.player.radius)
	var c := _walk_to(Vector3(mid.x, 0, mid.y))
	print("BRGATE %s side_wall from=(%.1f,%.1f) start_blocked=%s crossed=%s" % [id, side.x, side.y, blocked_start, c])
	if not blocked_start: _ok(not c, "%s 옆 담을 뚫고 지나가지 않음" % id)
