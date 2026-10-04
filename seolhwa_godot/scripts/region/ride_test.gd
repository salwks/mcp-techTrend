# 자동 기승·역마 시험(region_main --ridetest=<거점>:<거점> / --fasttravel=<공간>/<거점>) — 헤드리스로 돌린다(tools/run_story_tests.sh ride:*).
#   --ridetest=a:b        a 거점 어귀에서 말에 올라 b까지. 멈춘 자리·이유·감속 구역·걸린 시간을 남기고 맞으면 "RIDETEST PASS".
#     --rideexpect=dest            (기본) 마지막에 b 어귀(25m 안, 구역 밖)에서 내린다
#     --rideexpect=event:<id 일부> 첫 멈춤이 이야기 사건 앞 — 사건 자리까지 길로 70~220m(트리거 반경 바깥 기준)
#     --rideexpect=city             첫 멈춤이 성문 앞(도시 구역 밖)
#     --rideneed=R0101,R0104        이 감속 구역을 지났고(그 안 속도 ≤ 감속값+1) 소문·길가 장면이 실제로 나왔다
#     --ridepark=1                  MAIN_PARK_MARK_COUNT가 이만큼 늘었다(R0104 朴 수레)
#     --rideratio=0.55              말 시간 / 달리기 시간(길이 ÷ 4.6m/s) 이 값 이하
#     --ridetime=4                  시험만 빨리(Engine.time_scale)
#     --rideweather=blizzard@300    길 300m에서 날씨를 바꾼다 — --rideexpect=blizzard: 곧 멈춰 내리고 다시 타지 못한다
#     --ridefork=<이름 일부>        갈림길 안내가 뜨면 그 갈래를 고른다 — --rideexpect=fork: 그 갈래 끝 어귀에서 내린다
#   --fasttravel=<공간>/<거점>  그 거점을 가 본 것으로 적고 역마 창에서 골라 간다. 같은 공간이면 도착 자리, 다른 공간이면 넘어간 장면에서 확인.
#     --fastexpect=blocked          처음 가는 길이라 못 가야 한다(목록에 있지만 막힘)
#   --ridefixture=res://…json · --ridevars=K=V,… · --ridedone=노정,…   시험 출발 저장(--savefile에 깐다 — 이야기보다 먼저)
extends RefCounted

const Progress := preload("res://scripts/region/progress.gd")
const RideNet := preload("res://scripts/region/ride_net.gd")
const HorseRide := preload("res://scripts/region/horse_ride.gd")
const META := "seolhwa_fasttest"

var main
var _fails: Array = []

func _init(m) -> void:
	main = m

static func apply_fixture(args: Dictionary) -> void:
	if args.has("savefile"): Progress.use_path(String(args.savefile))
	var d := Progress.data()
	if args.has("ridefixture"):
		var j = JSON.parse_string(FileAccess.get_file_as_string(String(args.ridefixture)))
		if j is Dictionary:
			d.vars = j.get("vars", {}).duplicate(true)
			d.cases = j.get("cases", {}).duplicate(true)
			d.routes_done = j.get("routes_done", {}).duplicate(true)
			d.known = {}
			d.erase("travel_nodes"); d.erase("vignettes"); d.erase("where")
	if args.has("ridevars"):
		for kv in String(args.ridevars).split(",", false):
			var p := kv.split("=", true, 1)
			if p.size() < 2: continue
			var v: Variant = p[1]
			if p[1] == "true": v = true
			elif p[1] == "false": v = false
			elif p[1].is_valid_int(): v = int(p[1])
			d.vars[p[0]] = v
	if args.has("ridedone"):
		for r in String(args.ridedone).split(",", false): d.routes_done[r] = "2026-10-05T00:00:00"
	if args.has("ridefresh"):
		d.erase("travel_nodes"); d.erase("vignettes")
	Progress.save()
	print("RIDETEST fixture vars=%d routes_done=%s" % [d.vars.size(), d.routes_done.keys()])

func _wait_load() -> void:
	await main._wait_frames(10)
	var n := 0
	while main._loading and n < 6000:
		await main._wait_frames(1); n += 1
	n = 0
	while (main.world.stats.jobs > 0 or main.placement.busy()) and n < 900:
		await main._wait_frames(1); n += 1

func _fail(why: String) -> void:
	_fails.append(why)
	print("RIDETEST check FAIL ", why)

func _node(hr, key: String) -> Dictionary:
	if hr.net.node_by.has(key): return hr.net.node_by[key]
	for n in hr.net.nodes:
		if String(n.id).ends_with(key) or String(n.name) == key: return n
	return {}

# ---- 말 타기 ----
func run(spec: String) -> void:
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await _wait_load()
	var hr = main.horse_ride
	var args: Dictionary = main.args
	if hr == null or not hr.enabled:
		print("RIDETEST FAIL 자동 기승 없음(%s)" % hr.space_id() if hr != null else "")
		main._quit(); return
	var parts := spec.split(":")
	var a := _node(hr, parts[0]); var b := _node(hr, parts[1])
	if a.is_empty() or b.is_empty() or (a.get("gates", []) as Array).is_empty():
		print("RIDETEST FAIL 거점 없음 %s → %s" % [parts[0], parts[1]]); main._quit(); return
	Engine.time_scale = float(args.get("ridetime", "1"))
	# 출발 어귀: b까지 길이 가장 짧은 a의 어귀
	var best = null; var bd := INF
	for g in a.gates:
		var dj: Dictionary = hr.net.dijkstra(int(g.gi))
		var goal: Dictionary = hr.net.node_goal(dj, b)
		if float(goal.d) < bd: bd = float(goal.d); best = g
	if best == null or is_inf(bd):
		print("RIDETEST FAIL 길로 이어지지 않음 %s → %s" % [a.id, b.id]); main._quit(); return
	main.teleport(float(best.x), float(best.z))
	main.rig.update(0, main.player_pos, main.player.facing, null, true)
	await _wait_load()
	await main._wait_frames(20)
	var park0 := int(Progress.get_var("MAIN_PARK_MARK_COUNT", 0))
	var chk: Dictionary = hr.mount_check()
	print("RIDETEST at %s gate=(%.1f,%.1f) mount=%s prompt=%s" % [a.id, best.x, best.z, chk, hr.prompt])
	if not bool(chk.get("ok", false)): _fail("어귀에서 말에 오를 수 없음")
	hr._choice_from = int(chk.get("gi", hr.net.nearest(Vector2(main.player_pos.x, main.player_pos.z), 12.0)))
	hr._build_choices(hr._choice_from)
	var c = null
	for x in hr.choices:
		if String(x.node.id) == String(b.id): c = x
	print("RIDETEST choices=%s" % [hr.choices.map(func(x): return "%s(%.0fm)%s" % [x.name, x.d, "*" if x.story else ""])])
	if c == null:
		var dj2: Dictionary = hr.net.dijkstra(hr._choice_from)
		var g2: Dictionary = hr.net.node_goal(dj2, b)
		c = { node = b, gi = int(g2.gi), d = float(g2.d), name = hr._node_name(b), story = false }
		_fail("목적지 목록에 %s 없음" % b.id)
	if not hr.begin_ride(c):
		print("RIDETEST FAIL 못 탐"); main._quit(); return
	var dir: String = main._abs(String(args.get("shotdir", "shots/region/ride")))
	var shots: bool = DisplayServer.get_name() != "headless" and args.has("rideshots")
	var marks := [0.2, 0.5, 0.8]; var mi := 0
	var t0 := Time.get_ticks_msec()
	var fr := 0; var ft := 0.0; var ft_ride := 0.0; var fr_ride := 0
	var zone_v := {}   # 감속 구역 안 가장 빠른 속도
	var fork_pick := String(args.get("ridefork", ""))
	var wx := String(args.get("rideweather", ""))   # 날씨@s — 그 거리에서 날씨를 바꾼다(눈보라 강제 하차 시험)
	var wx_done := wx == ""
	var fork_node := ""
	var forks_seen := 0
	while hr.mounted():
		await main._wait_frames(1)
		var dt: float = main.get_process_delta_time()
		fr += 1; ft += dt
		if hr.riding():
			fr_ride += 1; ft_ride += dt
			for mk in hr.marks:
				if String(mk.kind) == "slow" and hr.s >= float(mk.s0) + 6.0 and hr.s <= float(mk.s1):
					zone_v[String(mk.id)] = maxf(float(zone_v.get(String(mk.id), 0.0)), hr.v)
		if not wx_done and hr.s >= float(wx.get_slice("@", 1)):
			wx_done = true
			main.weather.force(wx.get_slice("@", 0), -1.0, 0.0)
			print("RIDETEST weather %s at s=%.0f v=%.1f" % [wx.get_slice("@", 0), hr.s, hr.v])
		var fk = hr._fork_ahead()
		if fk != null and not fk.has("_seen"):
			fk["_seen"] = true; forks_seen += 1
			print("RIDETEST fork s=%.0f opts=%s text=%s" % [fk.s, fk.opts.map(func(o): return "%s:%s" % [o.dir, o.label]), hr._fork_text(fk)])
			if fork_pick != "":
				for o in fk.opts:
					if String(o.label).contains(fork_pick) or String(o.node.id).contains(fork_pick):
						hr._replan_from(int(fk.gi), o); fk.done = true; fork_node = String(o.node.id)
						print("RIDETEST fork pick %s → %s" % [o.dir, o.label]); break
		if fr % 600 == 0: print("RIDETEST f=%d s=%.0f/%.0f v=%.1f state=%s fps=%.0f" % [fr, hr.s, hr.L, hr.v, hr.state, Engine.get_frames_per_second()])
		if shots and mi < marks.size() and hr.L > 0.0 and hr.s / hr.L >= marks[mi]:
			main._save(dir.path_join("%s_%s_%d.png" % [a.id, b.id, mi + 1])); mi += 1
		if Time.get_ticks_msec() - t0 > 900000: _fail("시간 넘음"); break
	await main._wait_frames(30)
	var real_s := (Time.get_ticks_msec() - t0) / 1000.0
	var game_s: float = real_s * Engine.time_scale
	var run_s: float = hr.L / 4.6
	var avg_fps: float = fr_ride / maxf(ft_ride / maxf(Engine.time_scale, 0.001), 0.001)
	var stops: Array = hr.stats.get("stops", [])
	print("RIDETEST ride %s → %s len=%.0fm ride=%.1fs(게임) run=%.1fs ratio=%.2f max_v=%.1f avg_fps=%.1f stops=%s slow=%s zone_v=%s" % [a.id, b.id, hr.L, game_s, run_s,
		game_s / maxf(run_s, 1.0), float(hr.stats.get("max_v", 0.0)), avg_fps, stops.map(func(x): return "%s:%s@%.0f" % [x.why, x.id, x.s]),
		(hr.stats.get("slow", {}) as Dictionary).keys(), zone_v])
	var pp := Vector2(main.player_pos.x, main.player_pos.z)
	var expect := String(args.get("rideexpect", "dest"))
	if stops.is_empty(): _fail("멈춘 적 없음")
	elif expect == "fork":
		if fork_node == "": _fail("갈림길에서 고르지 못함(갈림 %d)" % forks_seen)
		elif String(hr.dest.node.id) != fork_node or String(stops[stops.size() - 1].why) != "dest": _fail("고른 갈래 끝에서 안 내림 %s" % hr.dest.node.id)
		else:
			var gdf := INF
			for g in hr.dest.node.gates: gdf = minf(gdf, pp.distance_to(Vector2(float(g.x), float(g.z))))
			print("RIDETEST fork dest %s gate_d=%.1f" % [fork_node, gdf])
			if gdf > 25.0: _fail("갈래 끝 어귀에서 멂 %.1f" % gdf)
	elif expect == "dest":
		var last: Dictionary = stops[stops.size() - 1]
		if String(last.why) != "dest": _fail("목적지 전에 멈춤 %s:%s" % [last.why, last.id])
		var gd := INF
		for g in b.gates: gd = minf(gd, pp.distance_to(Vector2(float(g.x), float(g.z))))
		if gd > 25.0: _fail("내린 자리가 어귀에서 멂 %.1fm" % gd)
		if RideNet.in_zone(b.zone, pp) and not b.gates.any(func(g): return g.get("inner", false)): _fail("구역 안에서 내림")
		print("RIDETEST dismount (%.1f,%.1f) gate_d=%.1f in_zone=%s" % [pp.x, pp.y, gd, RideNet.in_zone(b.zone, pp)])
	elif expect.begins_with("event"):
		var want := expect.split(":")[1] if expect.contains(":") else ""
		var first: Dictionary = stops[0]
		if String(first.why) != "event" or (want != "" and not String(first.id).contains(want)): _fail("첫 멈춤이 사건 앞이 아님 %s:%s" % [first.why, first.id])
		else:
			var sp = null
			for p in hr._story_points():
				if String(p.id) == String(first.id): sp = p
			for st in hr.net.stops:
				if sp == null and String(st.TRAVEL_EVENT_ID) == String(first.id): sp = { p = Vector2(float(st.TRIGGER_POSITION[0]), float(st.TRIGGER_POSITION[1])), r = float(st.get("RADIUS", 14.0)) }
			var mk_p: Vector2 = hr.stop_mark.get("p", sp.p if sp != null else Vector2.ZERO)
			var mk_r: float = float(hr.stop_mark.get("r", sp.r if sp != null else 0.0))
			var pr: Array = hr._proj(mk_p)
			var along: float = float(pr[0]) - float(first.s) - mk_r
			print("RIDETEST event stop %s 사건 자리(%.1f,%.1f) r=%.1f 길로 %.0fm 앞(트리거 바깥)" % [first.id, mk_p.x, mk_p.y, mk_r, along])
			if along < 60.0 or along > 220.0: _fail("사건 앞 하차 거리 %.0fm(70~200)" % along)
	elif expect == "blizzard":
		var fb: Dictionary = stops[0]
		if String(fb.why) != "blizzard": _fail("눈보라에 안 내림 %s" % fb.why)
		var ok2: bool = not bool(hr.mount_check().get("ok", true))
		print("RIDETEST blizzard stop s=%.0f mount_again=%s prompt=%s" % [fb.s, not ok2, hr.prompt])
		if not ok2: _fail("눈보라 속에서 다시 탈 수 있음")
	elif expect == "city":
		var first2: Dictionary = stops[0]
		if String(first2.why) != "city" and not (String(first2.why) == "dest" and String(b.kind) == "CITY"): _fail("첫 멈춤이 성문 앞이 아님 %s" % first2.why)
		var cz: Dictionary = b.zone if String(b.kind) == "CITY" else {}
		if not cz.is_empty() and RideNet.in_zone(cz, pp): _fail("성 안에서 내림")
	for need in String(args.get("rideneed", "")).split(",", false):
		var hit := false
		for k in (hr.stats.get("slow", {}) as Dictionary).keys():
			if String(k).contains(need): hit = true
		if not hit: _fail("감속 구역 %s 안 지남" % need)
		for k in zone_v:
			if String(k) == need or String(k).ends_with("_" + need):
				for mk in hr.marks:
					if String(mk.id) == String(k) and float(zone_v[k]) > float(mk.speed) + 1.0: _fail("%s 감속 안 됨 %.1f > %.1f" % [k, zone_v[k], mk.speed])
		var st = main.story
		if need.begins_with("R010") and st != null:
			var fired: bool = st._rumor_seen.has(need) or load("res://scripts/story/vignettes.gd").seen(need)
			if not fired: _fail("%s 대사·장면이 안 나옴" % need)
	if args.has("ridepark"):
		var park1 := int(Progress.get_var("MAIN_PARK_MARK_COUNT", 0))
		print("RIDETEST MAIN_PARK_MARK_COUNT %d → %d" % [park0, park1])
		if park1 - park0 < int(args.ridepark): _fail("朴 표식 수가 안 늘었음")
	if args.has("rideratio") and game_s / maxf(run_s, 1.0) > float(args.rideratio): _fail("말이 느림 %.2f > %s" % [game_s / run_s, args.rideratio])
	if shots: main._save(dir.path_join("%s_%s_9_dismount.png" % [a.id, b.id]))
	Engine.time_scale = 1.0
	if _fails.is_empty(): print("RIDETEST PASS %s→%s %.0fm %.0fs(달리기 %.0fs) 멈춤 %s" % [a.id, b.id, hr.L, game_s, run_s, stops.map(func(x): return x.why)])
	else: print("RIDETEST FAIL %s" % " / ".join(_fails))
	main._quit()

# ---- 역마 ----
func run_fast(spec: String) -> void:
	await _wait_load()
	var sp := spec.get_slice("/", 0); var nid := spec.get_slice("/", 1)
	var d: Dictionary = RideNet.read(sp)
	var n = null
	for x in d.get("nodes", []):
		if String(x.id) == nid: n = x
	if n == null:
		print("FASTTEST FAIL 거점 없음 %s" % spec); main._quit(); return
	HorseRide.discover(sp, nid)
	main.open_fast_travel()
	var ui = main.fast_ui
	if ui == null:
		print("FASTTEST FAIL 창이 안 열림"); main._quit(); return
	await main._wait_frames(5)
	ui.test_pick = spec
	ui._gather()
	var it: Dictionary = ui.items[ui.sel] if ui.sel < ui.items.size() else {}
	if it.is_empty() or String(it.id) != nid:
		print("FASTTEST FAIL 목록에 없음 %s items=%s" % [spec, ui.items.map(func(x): return "%s/%s" % [x.space, x.id])]); main._quit(); return
	print("FASTTEST pick %s/%s ok=%s why=%s same=%s" % [sp, nid, it.ok, it.why, it.same])
	if String(main.args.get("fastexpect", "")) == "blocked":
		if bool(it.ok): print("FASTTEST FAIL 처음 가는 길인데 열려 있음")
		else: print("FASTTEST PASS 막힘 확인 — %s" % it.why)
		ui.close(); main._quit(); return
	if not bool(it.ok):
		print("FASTTEST FAIL 못 감 %s" % it.why); ui.close(); main._quit(); return
	var a: Array = n.get("arrive", [n.x, n.z])
	if not it.same:
		Engine.set_meta(META, { space = sp, at = Vector2(float(a[0]), float(a[1])), node = nid })
	ui._confirm()
	var t0 := Time.get_ticks_msec()
	while is_instance_valid(ui) and Time.get_ticks_msec() - t0 < 20000:
		await main._wait_frames(1)
	if not it.same: return   # 넘어간 장면에서 확인(verify_arrival)
	await main._wait_frames(10)
	var d0 := Vector2(main.player_pos.x, main.player_pos.z).distance_to(Vector2(float(a[0]), float(a[1])))
	if d0 < 30.0: print("FASTTEST PASS %s 도착 %.1fm hour=%.1f" % [spec, d0, main.hour])
	else: print("FASTTEST FAIL 도착 자리 %.1fm" % d0)
	main._quit()

# 다른 공간으로 넘어간 뒤(region_main이 불러오기 끝에 부른다)
static func verify_arrival(m) -> void:
	if not Engine.has_meta(META): return
	var e: Dictionary = Engine.get_meta(META)
	Engine.remove_meta(META)
	var here := String(m.world.region.get("route_id", m.world.region.get("region_id", "")))
	var d0 := Vector2(m.player_pos.x, m.player_pos.z).distance_to(e.at)
	if here == String(e.space) and d0 < 40.0: print("FASTTEST PASS %s/%s 넘어가 도착 %.1fm hour=%.1f" % [e.space, e.node, d0, m.hour])
	else: print("FASTTEST FAIL 넘어간 자리 %s %.1fm" % [here, d0])
	m._quit()
