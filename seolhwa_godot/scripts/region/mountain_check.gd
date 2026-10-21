# 산 지형 점검(mountain-terrain) — region_main --mtncheck=walk|routes|probe:…. 시험 저장으로만(--savefile), 창 필요.
#   godot --path . res://scenes/region.tscn --resolution 1920x1080 -- --region=JL_NAMWON_UNBONG --mtncheck=walk \
#     --savefile=user://mtn_test.json --kitcache=/tmp/seolhwa_mtn_kit_cache/ --nostory --notitle --time=11 --weather=clear
#   walk : mountain.json 산길 경로(길 id의 점들)를 플레이어 판정(move_circle 8cm 걸음)으로 끝까지 걷는다 — 막힌 곳·구배.
#          + 땅·충돌 같음(원경 16m 격자 실루엣 오차), 떠 있거나 묻힌 건물·소품·나무, 가파른 비탈 막힘 규칙, 카메라가 비탈에 묻히지 않음,
#          고을(평지)에서는 카메라 올림이 0인지. 끝 줄: MTNPASS n / MTNFAIL n
#   probe:x,z;x,z : 그 자리의 높이·기울기·막힘·충돌체(디버그)
#   성능은 region_main --bench=초 --benchroute=<길 id>[:x0,z0,x1,z1] --benchspeed=m/s (tools/mountain/bench.sh)
extends RefCounted

var main
var passes := 0
var fails := 0
var mj := {}

func _init(m) -> void:
	main = m

func _ok(c: bool, what: String) -> void:
	if c: passes += 1; print("MTNOK   ", what)
	else: fails += 1; print("MTNFAIL ", what)

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

func _road(id: String) -> Array:
	for r in main.world.region.get("roads", []):
		if String(r.id) == id: return r.points
	return []

# 경로의 걸을 점들: 길 id들의 점(통영별로는 여원재 오르막 구간만)
func route_points(rt: Dictionary) -> Array:
	var out := []
	for id in rt.get("roads", []):
		var pts := _road(String(id))
		var seg := []
		var bb: Array = rt.get("bbox", [-1e9, -1e9, 1e9, 1e9])
		for p in pts:
			if String(id) == "tongyeong_byeolro" and not (float(p[0]) > -1010.0 and float(p[0]) < 140.0 and float(p[1]) > -1010.0 and float(p[1]) < -540.0): continue
			if float(p[0]) < float(bb[0]) or float(p[1]) < float(bb[1]) or float(p[0]) > float(bb[2]) or float(p[1]) > float(bb[3]): continue
			seg.append(Vector2(float(p[0]), float(p[1])))
		if not seg.is_empty(): out.append({ id = String(id), pts = seg })
	return out

func run(spec: String) -> void:
	mj = main.world.mountain
	main.set_first_person(false, false)
	if spec.begins_with("probe:"):
		for q in spec.substr(6).split(";"):
			var xz := q.split(",")
			var x := float(xz[0]); var z := float(xz[1])
			main.teleport(x, z); await _wait_load()
			var w = main.world
			for dd in [0.0, 0.08, 0.16]:
				var fh = w.farm.height(x + dd, z) if w.farm != null else NAN
				print("   +%.2f terrain=%.3f ground=%.3f height=%.3f farm=%s walk=%s" % [dd, w.terrain_at(x + dd, z), w.ground_at(x + dd, z), w.height_at(x + dd, z), str(fh), str(w.walk_at(x + dd, z))])
			print("MTNPROBE (%.1f,%.1f) h=%.2f slope=%.2f road_d=%.2f blocked=%s river=%s near_cross=%s lu=%d" % [x, z, w.height_at(x, z), w.slope_at(x, z), w.road_distance(x, z), w.blocked(x, z, main.player.radius), w._in_river(x, z, main.player.radius), w._near_crossing(x, z), w.landuse_at(x, z)])
			for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
				print("   dir %s climb=%s blocked=%s slope=%.2f" % [d, w.climb_ok(x, z, x + d.x, z + d.y, main.player.radius), w.blocked(x + d.x, z + d.y, main.player.radius), w.slope_at(x + d.x, z + d.y)])
			var ci := floori(x / w.GRID); var cj := floori(z / w.GRID)
			for j in range(cj - 1, cj + 2):
				for i in range(ci - 1, ci + 2):
					for c in w._static_grid.get(Vector2i(i, j), []):
						if w._hit(c, x, z, main.player.radius + 1.0): print("   hit ", str(c).substr(0, 200))
					var sg = w._scatter_grid.get(w.tile_of(x, z))
					if sg != null:
						for c in sg.get(Vector2i(i, j), []):
							if w._hit(c, x, z, main.player.radius + 0.5): print("   scatter hit ", str(c).substr(0, 200))
			print("   pond=%s" % [(not w._ponds.is_empty()) and w.in_pond(x, z)])
		main._quit(); return
	await _walk_routes()
	if spec == "routes": print("MTNPASS %d / MTNFAIL %d" % [passes, fails]); main._quit(); return
	await _consistency()
	await _seat_checks()
	_slope_rule()
	await _camera_checks()
	print("MTNPASS %d / MTNFAIL %d" % [passes, fails])
	print("MTNDONE")
	main._quit()

# ---- 산길 걷기
func _walk_routes() -> void:
	var w = main.world
	for rt in mj.get("routes", []):
		for part in route_points(rt):
			var pts: Array = part.pts
			main.teleport(pts[0].x, pts[0].y)
			await _wait_load()
			var stuck := []
			var maxg := 0.0
			var pos := Vector3(pts[0].x, w.height_at(pts[0].x, pts[0].y), pts[0].y)
			var L := 0.0
			var hist := []   # [거리, 높이]
			for k in range(1, pts.size()):
				var t: Vector2 = pts[k]
				var guard := 0
				while guard < 4000:
					guard += 1
					var v := Vector2(t.x - pos.x, t.y - pos.z)
					if v.length() < 0.1: break
					var st := v.normalized() * minf(0.08, v.length())
					var q = w.move_circle(pos, st.x, st.y, main.player.radius)
					if q == null or Vector2(q.x - pos.x, q.z - pos.z).length() < 0.003:
						stuck.append(Vector2(pos.x, pos.z))
						print("   STUCK at (%.2f,%.2f) → (%.2f,%.2f) blocked=%s climb=%s slope=%.2f→%.2f dh=%.3f river=%s" % [pos.x, pos.z, pos.x + st.x, pos.z + st.y, w.blocked(pos.x + st.x, pos.z + st.y, main.player.radius), w.climb_ok(pos.x, pos.z, pos.x + st.x, pos.z + st.y, main.player.radius), w.slope_at(pos.x, pos.z), w.slope_at(pos.x + st.x, pos.z + st.y), w.height_at(pos.x + st.x, pos.z + st.y) - w.height_at(pos.x, pos.z), w._in_river(pos.x + st.x, pos.z + st.y, main.player.radius)])
						break
					L += Vector2(q.x - pos.x, q.z - pos.z).length()
					pos = Vector3(q.x, w.height_at(q.x, q.z), q.z)
					hist.append(Vector2(L, pos.y))
				if Vector2(t.x - pos.x, t.y - pos.z).length() >= 0.25:
					# 막힌 마디는 기록하고 다음 마디로 옮겨 계속(모든 막힘을 모은다)
					pos = Vector3(t.x, w.height_at(t.x, t.y), t.y)
			# 10m 구배 최대
			var j := 0
			for i in hist.size():
				while j < hist.size() and hist[j].x - hist[i].x < 10.0: j += 1
				if j < hist.size(): maxg = maxf(maxg, absf(hist[j].y - hist[i].y) / maxf(hist[j].x - hist[i].x, 0.1))
			var ys := hist.map(func(h): return h.y)
			print("MTNWALK %s/%s len=%.0fm y=%.1f..%.1f max_grade10=%.0f%% stuck=%d %s" % [rt.id, part.id, L, ys.min() if not ys.is_empty() else 0.0, ys.max() if not ys.is_empty() else 0.0, maxg * 100.0, stuck.size(), str(stuck.slice(0, 6))])
			_ok(stuck.is_empty(), "산길 %s/%s 끝까지 걸음(%.0fm, 최대 구배 %.0f%%)" % [rt.id, part.id, L, maxg * 100.0])
	# 자리(anchor)마다: 가장 가까운 길에서 자리까지 걸어 닿나(빈 터 slot은 들어설 수 있어야)
	for a in mj.get("anchors", []):
		if not a.has("route") or a.get("route") == null: continue
		var pts := _road(String(a.route))
		if pts.is_empty(): continue
		var best := Vector2.ZERO; var bd := INF
		for p in pts:
			var d := Vector2(float(p[0]) - float(a.x), float(p[1]) - float(a.z)).length()
			if d < bd: bd = d; best = Vector2(float(p[0]), float(p[1]))
		var tgt := Vector2(float(a.x), float(a.z))
		var reach := 3.0 if a.has("slot") else maxf(float(a.get("r", 6.0)), 6.0)
		var pos := Vector3(best.x, w.height_at(best.x, best.y), best.y)
		var guard := 0
		while guard < 3000 and Vector2(tgt.x - pos.x, tgt.y - pos.z).length() > reach:
			guard += 1
			var v := (tgt - Vector2(pos.x, pos.z)).normalized() * 0.08
			var q = w.move_circle(pos, v.x, v.y, main.player.radius)
			if q == null or Vector2(q.x - pos.x, q.z - pos.z).length() < 0.003: break
			pos = Vector3(q.x, w.height_at(q.x, q.z), q.z)
		var dleft := Vector2(tgt.x - pos.x, tgt.y - pos.z).length()
		print("MTNANCHOR %-18s from_road=%.0fm left=%.1fm" % [a.id, bd, dleft])
		_ok(dleft <= reach + 0.2, "자리 %s(%s) 길에서 닿음(길에서 %.0fm, 남은 %.1fm)" % [a.id, a.type, bd, dleft])

# ---- 땅·충돌 같음 + 원경 실루엣 오차
func _consistency() -> void:
	var w = main.world
	var rng := RandomNumberGenerator.new(); rng.seed = 1870
	var worst := 0.0
	# 걷는 높이(height_at → terrain_at: 렌더 메시와 같은 삼각형 보간·같은 잡음)는 렌더 정점과 같다 → 정수 격자점에서 lattice와 같아야
	for i in 2000:
		var x := rng.randf_range(-1100.0, 300.0); var z := rng.randf_range(-1300.0, -550.0)
		var xi := floorf(x); var zi := floorf(z)
		worst = maxf(worst, absf(w.terrain_at(xi, zi) - w.lattice_height(xi, zi)))
	_ok(worst < 0.01, "걷는 땅 = 그리는 땅(정수 격자점 2000곳 최대 차 %.4fm)" % worst)
	# 원경(16m 격자 쌍선형)과 실제 땅의 차: 먼 능선 실루엣이 걸을 수 있는 땅과 얼마나 같은가
	var errs := PackedFloat32Array()
	for i in 4000:
		var x := rng.randf_range(-4300.0, 4300.0); var z := rng.randf_range(-2050.0, 2050.0)
		var x0 := floorf(x / 16.0) * 16.0; var z0 := floorf(z / 16.0) * 16.0
		var tx := (x - x0) / 16.0; var tz := (z - z0) / 16.0
		var hf := lerpf(lerpf(w.data_height(x0, z0), w.data_height(x0 + 16, z0), tx), lerpf(w.data_height(x0, z0 + 16), w.data_height(x0 + 16, z0 + 16), tx), tz)
		errs.append(absf(hf - w.data_height(x, z)))
	errs.sort()
	print("MTNFAR silhouette err median=%.2fm p95=%.2fm max=%.2fm (원경 16m 격자 vs 실제 땅)" % [errs[errs.size() / 2], errs[int(errs.size() * 0.95)], errs[errs.size() - 1]])
	_ok(errs[int(errs.size() * 0.95)] < 2.5, "원경 실루엣 p95 오차 %.2fm < 2.5m" % errs[int(errs.size() * 0.95)])

# ---- 떠 있거나 묻힌 건물·소품·나무
func _seat_checks() -> void:
	var w = main.world
	for c in [Vector2(-320, -880), Vector2(20, -970), Vector2(-120, -920), Vector2(-3600, -150), Vector2(-3900, -430)]:
		main.teleport(c.x, c.y)
		await _wait_load(); await _sec(0.5)
		var nb := 0; var bad := []
		for t in w._statics:
			for e in w._statics[t]:
				if not e.attached or not is_instance_valid(e.node): continue
				var o: Vector3 = e.node.global_position
				if Vector2(o.x - c.x, o.z - c.y).length() > 160.0: continue
				var bb := AABB(); var first := true
				for m in e.node.find_children("*", "MeshInstance3D", true, false):
					if not m.visible or m.mesh == null: continue
					var a: AABB = m.global_transform * m.get_aabb()
					bb = a if first else bb.merge(a); first = false
				if first: continue
				nb += 1
				var ctr := bb.get_center()
				var gs := []
				for d in [Vector2(0, 0), Vector2(-0.3, -0.3), Vector2(0.3, -0.3), Vector2(-0.3, 0.3), Vector2(0.3, 0.3)]:
					gs.append(w.ground_at(ctr.x + d.x * bb.size.x, ctr.z + d.y * bb.size.z))
				var gmin: float = gs.min(); var gmax: float = gs.max()
				var bottom := bb.position.y
				if bottom > gmax + 0.35 and bb.size.y < 30.0: bad.append("%s 뜸 %.2fm" % [e.node.name, bottom - gmax])
				elif bottom < gmin - 1.6 and bb.size.y < 12.0: bad.append("%s 묻힘 %.2fm" % [e.node.name, gmin - bottom])
			if bad.size() > 30: break
		print("MTNSEAT at=%s statics=%d bad=%d %s" % [c, nb, bad.size(), str(bad.slice(0, 8))])
		_ok(bad.is_empty(), "건물·소품 앉음(%s 둘레 %d개)" % [c, nb])
		# 나무: 식생 MultiMesh 인스턴스 밑동 y − 땅 높이
		var nt := 0; var tb := 0; var worst := 0.0; var deep := 0
		for mmi in w.scatter_root.find_children("*", "MultiMeshInstance3D", true, false):
			var mm: MultiMesh = mmi.multimesh
			if mm == null: continue
			var step := maxi(1, mm.instance_count / 40)
			for i in range(0, mm.instance_count, step):
				var xf: Transform3D = mmi.global_transform * mm.get_instance_transform(i)
				if Vector2(xf.origin.x - c.x, xf.origin.z - c.y).length() > 120.0: continue
				var h: float = w.height_fast(xf.origin.x, xf.origin.z)
				var d := xf.origin.y - h
				nt += 1
				if d > 0.15: tb += 1; worst = maxf(worst, d)   # 뜸(식생은 경사·크기만큼 일부러 묻는다 — scatter put() sink)
				elif d < -1.6: deep += 1
		print("MTNTREES at=%s sampled=%d floating=%d worst_float=%.2fm deep_sunk(>1.6m, 큰 바위·벼랑 의도)=%d" % [c, nt, tb, worst, deep])
		_ok(tb == 0, "식생이 뜨지 않음(%s 표본 %d, 뜸 %d)" % [c, nt, tb])

# ---- 가파른 비탈 막힘 규칙
func _slope_rule() -> void:
	var w = main.world
	var rng := RandomNumberGenerator.new(); rng.seed = 7
	var n_steep := 0; var n_block := 0; var n_flat := 0; var n_pass := 0
	for i in 6000:
		var x := rng.randf_range(-1000.0, 200.0); var z := rng.randf_range(-1300.0, -600.0)
		if w.road_distance(x, z) < 1.0: continue
		var s: float = w.slope_at(x, z)
		# 옆 2m 덜 가파른 곳에서 이 칸으로
		var fx := x; var fz := z + 2.0
		var sf: float = w.slope_at(fx, fz)
		if s > w.SLOPE_BLOCK + 0.05 and sf < s - 0.05:
			n_steep += 1
			if not w.climb_ok(fx, fz, x, z): n_block += 1
		elif s < w.SLOPE_BLOCK - 0.3 and sf < w.SLOPE_BLOCK - 0.3 and absf(w.height_at(x, z) - w.height_at(fx, fz)) / 2.0 < w.MAX_SLOPE:
			n_flat += 1
			if w.climb_ok(fx, fz, x, z): n_pass += 1
	print("MTNSLOPE steep=%d blocked=%d gentle=%d passed=%d" % [n_steep, n_block, n_flat, n_pass])
	_ok(n_steep > 0 and n_block == n_steep, "가파른 비탈(tan > %.1f, 길 밖)은 모두 막힘 %d/%d" % [w.SLOPE_BLOCK, n_block, n_steep])
	_ok(n_flat > 0 and n_pass == n_flat, "완만한 비탈은 모두 걸음 %d/%d" % [n_pass, n_flat])

# ---- 카메라: 비탈에 묻히지 않음 · 평지 고을은 그대로
func _camera_checks() -> void:
	var w = main.world
	var rig = main.rig
	var bad := 0; var n := 0; var lifted := 0
	for rt in mj.get("routes", []):
		for part in route_points(rt):
			var pts: Array = part.pts
			for k in range(0, pts.size(), 6):
				var p: Vector2 = pts[k]
				main.player_pos = Vector3(p.x, w.height_at(p.x, p.y), p.y)
				main.player.position = main.player_pos
				for f in 4: rig.update(0.1, main.player_pos, "up", null, f == 0)
				var cp: Vector3 = rig.camera.position
				var tg: Vector3 = rig.target
				var clear: bool = cp.y > w.ground_at(cp.x, cp.z) + 1.0
				for s in range(1, 10):
					var q := tg.lerp(cp, 0.25 + 0.75 * s / 10.0)
					if w.ground_at(q.x, q.z) > q.y + 0.05: clear = false
				n += 1
				if not clear: bad += 1
				if rig._lift > 0.01: lifted += 1
	print("MTNCAM route_samples=%d occluded=%d lifted=%d" % [n, bad, lifted])
	_ok(bad == 0, "산길 카메라가 땅에 묻히지 않음(%d곳 중 가림 %d, 올림 %d)" % [n, bad, lifted])
	# 고을(평지): 올림 0
	var town_lift := 0
	for p in [Vector2(-3228, 110), Vector2(-3341, 272), Vector2(-3228, 300), Vector2(-3300, 420), Vector2(896, -763), Vector2(-3192, 700)]:
		main.player_pos = Vector3(p.x, w.height_at(p.x, p.y), p.y)
		rig._lift = 0.0
		for f in 4: rig.update(0.1, main.player_pos, "up", null, f == 0)
		if rig._lift > 0.001: town_lift += 1; print("MTNCAM town lift at ", p, " = ", rig._lift)
	_ok(town_lift == 0, "고을 평지에서 카메라 올림 없음(마을 카메라 값 그대로)")
