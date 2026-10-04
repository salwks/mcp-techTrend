# 역참 시험(헤드리스, tools/run_story_tests.sh station:*) — horse_ride.setup이 --stationtest를 보고 연다.
#   --stationtest=a,b[,ride_to]   같은 공간 역 a·b에 차례로 가서 '가 봄'으로 적히는지(역 구역에 들어서면 travel_nodes) → 마방의 말·마부가 생겼는지
#                                 → Travel.warp_to_station(a)(지도에서 고른 것과 같은 길: 역마 창이 길을 그리고 시각이 흐름) → a 마방 문 앞 도착
#                                 → 역에서 말 타기(마부가 가로대의 말을 끌고 나옴) → ride_to 거점 어귀까지 말로 가서 내림
#                                 + 처음 가는 길 막힘: 제주 역은 가 본 것으로 적어도 남해 뱃길을 안 건넜으면 못 간다
#   --stationtest=cross:<역>      그 역을 가 본 것으로 적고 다른 공간으로 역마 → 새 장면에서 그 역 마방 문 앞에 섰나(Engine 메타로 이어 봄)
# 판정: "STATIONTEST PASS …" / "STATIONTEST FAIL …"
extends RefCounted

const Stations := preload("res://scripts/region/stations.gd")
const Travel := preload("res://scripts/region/travel.gd")
const HorseRide := preload("res://scripts/region/horse_ride.gd")
const Progress := preload("res://scripts/region/progress.gd")
const RideNet := preload("res://scripts/region/ride_net.gd")
const CONT := "seolhwa_stationtest_cont"

var main
var _fails: Array = []

func _init(m) -> void:
	main = m

func _fail(w: String) -> void:
	_fails.append(w)
	print("STATIONTEST check FAIL ", w)

func _wait_load() -> void:
	await main._wait_frames(10)
	var n := 0
	while main._loading and n < 6000:
		await main._wait_frames(1); n += 1
	n = 0
	while (main.world.stats.jobs > 0 or main.placement.busy()) and n < 900:
		await main._wait_frames(1); n += 1

func _yard(s: Dictionary) -> Vector2:
	return Vector2(float(s.yard[0]), float(s.yard[1]))

func _pp() -> Vector2:
	return Vector2(main.player_pos.x, main.player_pos.z)

func _end() -> void:
	Engine.time_scale = 1.0
	if _fails.is_empty(): print("STATIONTEST PASS")
	else: print("STATIONTEST FAIL %s" % " / ".join(_fails))
	main._quit()

func run(spec: String) -> void:
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	if Engine.has_meta(CONT):
		await _verify_cross(); return
	await _wait_load()
	if spec.begins_with("cross:"):
		await _cross(spec.get_slice(":", 1)); return
	var parts := spec.split(",")
	var a := Stations.by_id(parts[0]); var b := Stations.by_id(parts[1])
	var ride_to := parts[2] if parts.size() > 2 else ""
	if a.is_empty() or b.is_empty():
		print("STATIONTEST FAIL 역 없음 %s" % spec); main._quit(); return
	var hr = main.horse_ride
	# 1) 두 역에 들러 '가 봄'
	for s in [a, b]:
		if Stations.known(String(s.id)): _fail("%s 처음부터 가 봄으로 되어 있음" % s.id)
		var y := _yard(s)
		main.teleport(y.x, y.y)
		main.rig.update(0, main.player_pos, main.player.facing, null, true)
		await _wait_load()
		await main._wait_frames(60)
		var known := Stations.known(String(s.id))
		var L = hr.life.live.get(String(s.id))
		var nst: int = L.stalls.size() if L != null else 0
		var npad: int = L.pads.size() if L != null else 0
		var eating := 0
		if L != null:
			for h in L.stalls:
				if String(h.ch.anim) == "eat": eating += 1
		print("STATIONTEST visit %s(%s) known=%s stalls=%d eating=%d pads=%d wait=%s groom=%s task=%s" % [s.id, s.name, known, nst, eating, npad,
			L != null and L.has("wait"), L.groom.ch.kind if L != null else "", L.groom.task if L != null else ""])
		if not known: _fail("%s 들렀는데 가 봄이 아님" % s.id)
		if L == null or nst < 3 or npad < 1 or not L.has("wait"): _fail("%s 마방에 말·마부가 없음" % s.id)
	# 2) 지도 API로 역마: 지금(b) → a
	var listing: Array = Travel.stations()
	var la = listing.filter(func(x): return String(x.id) == String(a.id))
	print("STATIONTEST listing n=%d %s discovered=%s ok=%s" % [listing.size(), a.id, la[0].discovered if not la.is_empty() else "?", la[0].ok if not la.is_empty() else "?"])
	if la.is_empty() or not bool(la[0].discovered) or not bool(la[0].ok): _fail("목록에서 %s 갈 수 없음" % a.id)
	var h0: float = main.hour
	var r: Dictionary = Travel.warp_to_station(String(a.id))
	if not bool(r.ok): _fail("warp_to_station 거절 %s" % r.why)
	var t0 := Time.get_ticks_msec()
	await main._wait_frames(5)
	while main.fast_ui != null and is_instance_valid(main.fast_ui) and Time.get_ticks_msec() - t0 < 20000:
		await main._wait_frames(1)
	await _wait_load()
	await main._wait_frames(30)
	var d := _pp().distance_to(_yard(a))
	print("STATIONTEST warp %s → %s d=%.1fm hour %.1f → %.1f" % [b.id, a.id, d, h0, main.hour])
	if d > 4.0: _fail("역마 도착이 마방 문 앞이 아님 %.1fm" % d)
	if is_equal_approx(h0, main.hour): _fail("시각이 흐르지 않음")
	var L2 = hr.life.live.get(String(a.id))
	if L2 == null or not L2.has("wait"): _fail("도착한 역에 기다리는 말이 없음")
	else:
		var wd := Vector2(L2.wait.position.x, L2.wait.position.z).distance_to(_pp())
		print("STATIONTEST waiting horse %.1fm" % wd)
		if wd > 9.0: _fail("기다리는 말이 멀다 %.1fm" % wd)
	# 3) 처음 가는 길: 제주 역은 가 본 것으로 적어도 막힘(남해 뱃길 안 건넘)
	var jj := Stations.by_id("jeju")
	if not jj.is_empty() and not Progress.route_done("SEA_NAMHAE_JEJU"):
		HorseRide.discover(String(jj.space), String(jj.node))
		var js := Stations.state("jeju")
		print("STATIONTEST jeju state ok=%s why=%s" % [js.ok, js.why])
		if bool(js.ok): _fail("제주 첫 뱃길 전에 제주 역으로 갈 수 있음")
		var rj := Travel.warp_to_station("jeju")
		if bool(rj.ok): _fail("제주 역 warp가 열림")
	# 4) 역에서 말 타기 — 마부가 끌어 옴 → ride_to까지
	if ride_to != "":
		await _ride(hr, a, ride_to)
	_end()

func _ride(hr, a: Dictionary, ride_to: String) -> void:
	Engine.time_scale = float(main.args.get("ridetime", "4"))
	hr.test_log = true
	var chk: Dictionary = hr.mount_check()
	print("STATIONTEST mount_check %s prompt=%s" % [chk, hr.prompt])
	if not bool(chk.get("ok", false)): _fail("역 문 앞에서 말에 오를 수 없음"); return
	if not hr.prompt.contains("역마를 낸다") and hr.prompt != "": _fail("역 안내 문구가 아님: %s" % hr.prompt)
	hr._choice_from = int(chk.gi)
	hr._build_choices(hr._choice_from)
	var c = null
	for x in hr.choices:
		if String(x.node.id) == ride_to: c = x
	if c == null:
		var b: Dictionary = hr.net.node_by.get(ride_to, {})
		if b.is_empty(): _fail("거점 없음 %s" % ride_to); return
		var g: Dictionary = hr.net.node_goal(hr.net.dijkstra(hr._choice_from), b)
		c = { node = b, gi = int(g.gi), d = float(g.d), name = hr._node_name(b), story = false }
	if not hr.begin_ride(c): _fail("말에 못 탐"); return
	var led: bool = not hr._lead_st.is_empty()
	var L = hr.life.live.get(String(a.id))
	var gp0: Vector3 = L.groom.ch.position if L != null else Vector3.ZERO
	print("STATIONTEST mount led=%s bring=%.1fs from=(%.1f,%.1f)" % [led, hr._t_bring, hr._mount_from.x, hr._mount_from.z])
	if not led: _fail("마부가 말을 끌어 오지 않음")
	var groom_moved := 0.0
	var t0 := Time.get_ticks_msec()
	var saw_ride := false
	while hr.mounted() and Time.get_ticks_msec() - t0 < 600000:
		await main._wait_frames(1)
		if L != null and hr.state == "MOUNTING": groom_moved = maxf(groom_moved, L.groom.ch.position.distance_to(gp0))
		if hr.riding(): saw_ride = true
	await main._wait_frames(20)
	var n: Dictionary = hr.net.node_by.get(ride_to, {})
	var gd := INF
	for g in n.get("gates", []): gd = minf(gd, _pp().distance_to(Vector2(float(g.x), float(g.z))))
	var stops: Array = hr.stats.get("stops", [])
	print("STATIONTEST ride %s → %s len=%.0fm groom_moved=%.1fm dismount gate_d=%.1f stops=%s" % [a.id, ride_to, hr.L, groom_moved, gd,
		stops.map(func(x): return "%s:%s" % [x.why, x.id])])
	if not saw_ride: _fail("말이 가지 않음")
	if groom_moved < 1.0: _fail("마부가 말을 끌고 걷지 않음")
	if stops.is_empty() or String(stops[stops.size() - 1].why) != "dest": _fail("목적지에서 안 내림")
	if gd > 25.0: _fail("내린 자리가 어귀에서 멂 %.1fm" % gd)

# ---- 다른 공간 역으로 ----
func _cross(id: String) -> void:
	var s := Stations.by_id(id)
	if s.is_empty():
		print("STATIONTEST FAIL 역 없음 %s" % id); main._quit(); return
	HorseRide.discover(String(s.space), String(s.node))
	var stt := Stations.state(id)
	print("STATIONTEST cross %s state=%s" % [id, stt])
	if not bool(stt.ok):
		print("STATIONTEST FAIL 갈 수 없음 %s" % stt.why); main._quit(); return
	Engine.set_meta(CONT, { id = id, space = String(s.space), h0 = main.hour })
	var r := Travel.warp_to_station(id)
	if not bool(r.ok):
		Engine.remove_meta(CONT)
		print("STATIONTEST FAIL warp 거절 %s" % r.why); main._quit()

func _verify_cross() -> void:
	var e: Dictionary = Engine.get_meta(CONT)
	Engine.remove_meta(CONT)
	await _wait_load()
	await main._wait_frames(60)
	var s := Stations.by_id(String(e.id))
	var here := String(main.world.region.get("route_id", main.world.region.get("region_id", "")))
	var d := _pp().distance_to(_yard(s))
	var L = main.horse_ride.life.live.get(String(e.id))
	print("STATIONTEST cross arrive space=%s d=%.1fm hour %.1f → %.1f life=%s" % [here, d, float(e.h0), main.hour, L != null])
	if here != String(e.space): _fail("다른 공간에 닿음 %s" % here)
	if d > 4.0: _fail("마방 문 앞이 아님 %.1fm" % d)
	if L == null or not L.has("wait"): _fail("마방 말이 없음")
	var chk: Dictionary = main.horse_ride.mount_check()
	if not bool(chk.get("ok", false)): _fail("도착한 역에서 말에 오를 수 없음 %s" % chk)
	_end()
