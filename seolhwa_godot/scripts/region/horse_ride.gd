# 자동 기승 — 이동수단 개선안 v1.0(seolhwa/docs/scenario/seolhwarok_TRAVEL_TRANSPORT_IMPROVEMENT_PLAN_v1.0.md) §3~§9·§13~§17·§23·§30~§32.
#   말은 탈것이 아니라 장거리 여행 모드다: 플레이어는 몰지 않는다. 큰길(대로·지선) 중심선을 따라 말이 저절로 가고,
#   TRAVEL_GATE(마을 어귀·성문 앞·나루·굴 앞·사건 70~200m 앞)에서 감속 → 멈춤 → 내림 → 걸어서 들어간다.
#   길 그래프·거점·멈춤 정책: region_data/travel/<공간>.json(tools/region/make_travel_gates.py, 손 고침 overrides.json) → ride_net.gd.
#
# 상태(TRAVEL_STATE §23): ON_FOOT → MOUNTING → AUTO_RIDE ⇄ RIDE_SLOW → DISMOUNTING → (EVENT_APPROACH) → ON_FOOT, FAST_TRAVEL(역마 연출 중)
# 타기(§13): 주막·역·마을 어귀·성문 앞·큰길 갈림·노정 끝(포털)·노정 큰길 위, 그리고 방금 내린 자리에서만. 골목·장 안·산길·숲·절·굴·실내·싸움 중엔 안 된다.
#   안내 "E 말에 오른다 — ○○ 쪽으로 (약 N분)  ·  Q 다른 곳". 기본 목적지는 이야기 쪽(사건이 있는 어귀) → 노정이면 먼 끝 → 가까운 고을.
# 타는 중: Space 멈춤·다시 감 · E 내리기 · 갈림길 앞에서 A/D(W)로 길 고르기(입력 없으면 정한 목적지대로).
#   저절로 멈춤(§32): 싸움(바로 내림), 길 막힘, FORCED_STOP·사건 앞, 성문 앞, 목적지, 노정 끝(공간 넘어가기 전), 눈보라(강제 하차).
#   OPTIONAL_STOP 구역은 감속(설정 '자동 감속 끔'이면 감속 안 함 — 이야기에 꼭 필요한 MUST 구역은 그대로).
# 카메라(§15): 배 타기와 같은 풍경 시점(낮은 pitch, yaw가 가는 방향을 부드럽게 따라감, 내리면 천천히 돌아옴), 걷기보다 조금 멀리.
#   플레이어는 카메라를 돌리지 않는다. 흔들림(설정 보통/약함/끔)은 말 걸음에 맞춘 작은 세로 흔들림.
# 소리(§16): 아직 소리 체계가 없다 — audio_cue(cue, value) 신호만 낸다:
#   "hooves_start"(속도) · "gait"(속도 m/s, 0.5초마다) · "hooves_stop" · "mount" · "dismount" · "slow"(구역 이름) · "halt" · "event_near"(사건 이름)
extends RefCounted

const RideNet := preload("res://scripts/region/ride_net.gd")
const Progress := preload("res://scripts/region/progress.gd")
const GameSettings := preload("res://scripts/story/game_settings.gd")
const Rumors := preload("res://story/rumors_data.gd")

signal state_changed(old: String, new: String)
signal audio_cue(cue: String, value: float)
signal ride_done(node_id: String, why: String)

const SPEED := { normal = 18.0, fast = 23.0 }   # 말 최고 속도(m/s) — 달리기 4.6의 약 4배. 감속 구역·굽이를 넣어 노정 7분 → 약 3분
const ACCEL := 3.2
const DECEL := 4.2
const SADDLE_Y := 1.85       # 안장 높이(탈 말 ride_horse 그림 — 등 1.87m). 주변 말 옆모습으로 대신할 때는 SADDLE_SMALL
const SADDLE_SMALL := 1.32
const MOUNT_R := 45.0        # 말 타는 곳 둘레
const ROAD_R := 7.5          # 큰길 중심선에서 이만큼 안이면 큰길 위
const T_BRING := 1.1         # 말이 다가와 서는 시간
const T_MOUNT := 0.75
const T_DISMOUNT := 0.7
const STORY_APPROACH := 100.0   # 사건 트리거 바깥에서 이만큼 앞에서 내린다(걸어서 30~90초 — §6)
const NO_STOP_NEAR := 25.0      # 탄 자리에서 이보다 가까운 멈춤은 무시(이미 그 앞에 있다)
const HIDDEN_KINDS := ["HAMLET", "SHRINE"]

var main
var world
var net                    # RideNet
var enabled := false
var state := "ON_FOOT"
var horse: SpriteChar = null
var horse_kind := ""
var rider_anim := "idle"
var saddle := SADDLE_Y
var path := PackedVector2Array()
var cum := PackedFloat32Array()
var L := 0.0
var s := 0.0
var v := 0.0
var top := 16.0
var dest := {}             # {node, gi, d, name}
var marks: Array = []      # 길 위: {kind:"slow"|"stop", s0, s1, speed, id, name, must, why}
var forks: Array = []      # {s, gi, opts:[{dir, label, node, gi}], done}
var stop_s := INF
var stop_mark := {}
var halted := false
var prompt := ""           # 걸을 때 아래 가운데 안내(E …)
var hint := ""             # 탈 때 아래 가운데 안내
var bob := 0.0             # 카메라 세로 흔들림(m)
var choices: Array = []
var ci := 0
var _choice_from := -1
var _choice_t := 0.0
var _t := 0.0
var _hud := ""
var _last_dismount := Vector2.INF
var _approach := {}        # EVENT_APPROACH {p, r, id, t}
var _disc_t := 0.0
var _gait_t := 0.0
var _block_t := 0.0
var _horse_s := 0.0        # 내린 뒤 말이 물러가는 자리(path s)
var _horse_leave := 0.0
var _mount_from := Vector3.ZERO
var _seat := Vector3.INF
var _bob_ph := 0.0
var _slow_name := ""
var _story_cache: Array = []
var _story_t := -1.0
var _arrived_mount := Vector2.INF   # 넘어온 자리(노정 끝 포털 곁) — 말 타는 곳
var test_log := false
var stats := {}            # 시험: {t0, dist, slow:{id:true}, stops:[], max_v}

func setup(m) -> void:
	main = m; world = m.world
	net = RideNet.new()
	var sid := String(world.region.get("route_id", world.region.get("region_id", "")))
	enabled = net.setup(sid) and net.ok()
	test_log = m.args.has("ridetest") or m.args.has("ridelog")
	for act in { ride_next = KEY_Q }:
		if not InputMap.has_action(act):
			InputMap.add_action(act)
			var ev := InputEventKey.new(); ev.physical_keycode = { ride_next = KEY_Q }[act]
			InputMap.action_add_event(act, ev)
	# 그림: 말(앞·옆·뒤, frames_ride.json — 없으면 주변 말 옆모습), 탄 사람(player ride·mount·dismount — 없으면 앉기)
	SpriteChar.merge_bank("frames_ride.json")
	if SpriteChar._banks.has("ride_horse"): horse_kind = "ride_horse"
	else:
		saddle = SADDLE_SMALL
		if FileAccess.file_exists("res://data/frames_amb.json"): SpriteChar.load_bank("horse", "frames_amb.json")
		if SpriteChar._banks.has("horse"): horse_kind = "horse"
	if m.player.has_anim("ride"): rider_anim = "ride"
	elif m.player.has_anim("sit"): rider_anim = "sit"
	if enabled:
		print("RIDE net space=%s pts=%d nodes=%d stops=%d horse=%s rider=%s" % [sid, net.pts.size(), net.nodes.size(), net.stops.size(), horse_kind, rider_anim])

# ---- 바깥에서 묻는 것 ----
func mounted() -> bool: return state in ["MOUNTING", "AUTO_RIDE", "RIDE_SLOW", "DISMOUNTING"]
func riding() -> bool: return state in ["AUTO_RIDE", "RIDE_SLOW"]
func busy() -> bool: return mounted() or state == "FAST_TRAVEL"
func take_hud() -> String:
	var h := _hud; _hud = ""; return h

func _set_state(st: String) -> void:
	if st == state: return
	var old := state
	state = st
	if test_log: print("RIDE state %s -> %s s=%.0f/%.0f v=%.1f" % [old, st, s, L, v])
	state_changed.emit(old, st)

func set_fast_travel(on: bool) -> void:
	if on and not mounted(): _set_state("FAST_TRAVEL")
	elif not on and state == "FAST_TRAVEL": _set_state("ON_FOOT")

func space_id() -> String: return net.space if net != null else ""

# 카메라 섞기(1 = 말 시점): 오르며 커지고, 멈춤에 다가가며(40m) 줄고, 내리면 0
func cam_k() -> float:
	match state:
		"MOUNTING": return clampf((_t - T_BRING) / T_MOUNT, 0.0, 1.0)
		"AUTO_RIDE", "RIDE_SLOW": return lerpf(0.35, 1.0, clampf((stop_s - s) / 40.0, 0.0, 1.0))
		"DISMOUNTING": return lerpf(0.35, 0.0, clampf(_t / T_DISMOUNT, 0.0, 1.0))
	return 0.0

# 카메라용 방향: 길의 잔굽이를 따라 흔들리지 않게 뒤 30m → 앞 90m 긴 현(chord) 방향을 쓴다
func heading() -> Vector2:
	if path.size() < 2: return Vector2.ZERO
	var a := _at(maxf(s - 30.0, 0.0)); var b := _at(minf(s + 90.0, L))
	var h := b - a
	return h.normalized() if h.length() > 1.0 else _heading(s)

# 카메라가 볼 쪽(가는 길 왼쪽 +1 / 오른쪽 −1): 더 높은 쪽(산·능선) — 배 타기 view_side와 같은 방식. 2초마다, 차이가 클 때만 바꾼다
var _side := 1.0
var _side_t := 0.0
func view_side(dt: float) -> float:
	_side_t -= dt
	if _side_t > 0.0 or path.size() < 2: return _side
	_side_t = 25.0   # 볼 쪽은 자주 바꾸지 않는다(카메라가 좌우로 오가며 어지럽지 않게)
	var h := _heading(s)
	var n := Vector2(-h.y, h.x)
	var c := _at(minf(s + 50.0, L))
	var y0: float = world.height_at(c.x, c.y)
	var sc := [0.0, 0.0]
	for i in 2:
		var sg := 1.0 if i == 0 else -1.0
		for d in [60.0, 120.0, 220.0]:
			var q: Vector2 = c + n * sg * d
			sc[i] += maxf(world.height_at(q.x, q.y) - y0, 0.0)
	var want := 1.0 if sc[0] >= sc[1] else -1.0
	if want != _side and absf(sc[0] - sc[1]) > 40.0: _side = want
	return _side

# ---- 매 프레임 ----
# free: 이야기·지도·배가 플레이어를 쥐고 있지 않음. want_e: 이번 프레임 E(이야기 대상·배가 없을 때만)
func update(dt: float, free: bool, want_e: bool) -> void:
	if not enabled:
		prompt = ""; hint = ""; return
	_discover(dt)
	var st = main.story
	# 싸움이 시작되면 바로 내린다(§32)
	if mounted() and st != null and st.drives_player():
		_drop("싸움", true); return
	match state:
		"ON_FOOT", "EVENT_APPROACH":
			hint = ""
			_update_foot(dt, free, want_e)
		"MOUNTING": _update_mounting(dt)
		"AUTO_RIDE", "RIDE_SLOW": _update_ride(dt, free)
		"DISMOUNTING": _update_dismounting(dt)
		"FAST_TRAVEL":
			prompt = ""; hint = ""
	_update_horse_leave(dt)

# ---- 걸을 때: 탈 수 있나·목적지 고르기 ----
func _update_foot(dt: float, free: bool, want_e: bool) -> void:
	prompt = ""
	if state == "EVENT_APPROACH":
		_approach.t = float(_approach.get("t", 0.0)) + dt
		var pp0 := Vector2(main.player_pos.x, main.player_pos.z)
		var fired := not _story_point_alive(String(_approach.get("id", "")))
		if fired or pp0.distance_to(_approach.p) > float(_approach.r) + STORY_APPROACH + 160.0 or float(_approach.t) > 240.0:
			_approach = {}
			_set_state("ON_FOOT")
	if not free: return
	var chk := mount_check()
	if not bool(chk.ok):
		if String(chk.get("show", "")) != "": prompt = String(chk.show)
		_choice_from = -1
		return
	var gi: int = int(chk.gi)
	_choice_t -= dt
	if gi != _choice_from or _choice_t <= 0.0:
		var keep := String(choices[ci].node.id) if ci < choices.size() and _choice_from == gi else ""
		_build_choices(gi)
		ci = 0
		for k in choices.size():
			if String(choices[k].node.id) == keep: ci = k
		_choice_from = gi; _choice_t = 2.0
	if choices.is_empty():
		prompt = ""
		return
	if Input.is_action_just_pressed("ride_next"): ci = (ci + 1) % choices.size()
	var c: Dictionary = choices[ci]
	var mins := maxf(1.0, round(float(c.d) / (_top_speed() * 0.75) / 60.0))
	prompt = "E   말에 오른다 — %s 쪽으로 (약 %d분)%s" % [String(c.name), int(mins), ("   ·   Q 다른 곳 %d/%d" % [ci + 1, choices.size()]) if choices.size() > 1 else ""]
	if want_e: begin_ride(c)

# 말 탈 수 있나: {ok, gi, why, show}
func mount_check() -> Dictionary:
	if not enabled: return { ok = false, why = "off" }
	if world.indoor != null: return { ok = false, why = "indoor" }
	var pp := Vector2(main.player_pos.x, main.player_pos.z)
	var gi: int = net.nearest(pp, ROAD_R + 1.5)
	if gi < 0: return { ok = false, why = "no_road" }
	if _blizzard(): return { ok = false, show = "눈보라 — 말은 고삐를 잡고 끌며 걷는다" }
	var lu: int = world.landuse_at(pp.x, pp.y)
	if lu in [0, 7, 9]: return { ok = false, why = "landuse %d" % lu }        # 숲·벼랑·대숲
	var here: Dictionary = net.node_at(pp)
	if not here.is_empty() and String(here.kind) in ["CITY", "MARKET", "TEMPLE", "CAVE"]: return { ok = false, why = "in " + String(here.id) }
	for sp in _story_points():
		if String(sp.kind) == "event" and pp.distance_to(sp.p) < float(sp.r) + float(sp.approach) * 0.9:
			return { ok = false, why = "story " + String(sp.id) }   # 사건 접근 구간 — 걸어서 살핀다
	if not world.is_route:
		var near := false
		for mt in net.mounts:
			if pp.distance_to(Vector2(float(mt.x), float(mt.z))) < MOUNT_R: near = true; break
		if not near and _last_dismount != Vector2.INF and pp.distance_to(_last_dismount) < 40.0: near = true
		if not near and _arrived_mount != Vector2.INF and pp.distance_to(_arrived_mount) < 60.0: near = true
		if not near: return { ok = false, why = "no_mount_spot" }
	return { ok = true, gi = gi }

func _blizzard() -> bool:
	var w = main.weather
	if w == null: return false
	return String(w.kind) == "blizzard" or String(w.get("script_kind")) == "blizzard"

func _top_speed() -> float:
	var base: float = SPEED.get(GameSettings.get_v("ride_speed"), SPEED.normal)
	if main.args.has("ridespeed"): base = float(main.args.ridespeed)
	var w = main.weather
	var mods: Dictionary = net.ride.get("WEATHER_SPEED_MOD", {})
	var k := 1.0
	if w != null:
		var kind := String(w.get("script_kind")) if String(w.get("script_kind")) != "" else String(w.kind)
		k = float(mods.get(kind, 1.0))
		if k <= 0.0: k = 0.5
	return base * k

# 목적지 후보: 이야기 쪽 어귀 → (노정) 먼 끝 → 가까운 순. 거점 이름·어귀까지 길 거리
func _build_choices(gi: int) -> void:
	choices = []
	var dj: Dictionary = net.dijkstra(gi)
	var pp := Vector2(main.player_pos.x, main.player_pos.z)
	var here: Dictionary = net.node_at(pp)
	var story_pts := _story_points()
	for n in net.nodes:
		if HIDDEN_KINDS.has(String(n.kind)) or (n.get("gates", []) as Array).is_empty(): continue
		if not bool(n.get("fast", false)) and not bool(n.get("mount", false)) and not String(n.kind) in ["ROUTE_END", "BOAT", "CAVE"]: continue
		if not here.is_empty() and String(here.id) == String(n.id): continue
		if RideNet.in_zone(n.zone, pp, 15.0): continue
		var g: Dictionary = net.node_goal(dj, n)
		if int(g.gi) < 0 or float(g.d) < 70.0: continue
		var c := { node = n, gi = int(g.gi), d = float(g.d), name = _node_name(n), score = float(g.d), story = false }
		# 이야기 쪽: 사건 자리가 이 어귀 400m 안
		for sp in story_pts:
			if String(sp.kind) == "event" and Vector2(float(g.gate.x), float(g.gate.z)).distance_to(sp.p) < 400.0:
				c.story = true; c.score -= 1e6
		choices.append(c)
	# 노정: 들어온 끝의 반대쪽 끝을 먼저(이야기 쪽 다음)
	if world.is_route:
		var entry := String(main.get("_route_entry"))
		for c in choices:
			if String(c.node.kind) == "ROUTE_END" and String(c.node.get("portal", "")) != entry and entry != "":
				c.score -= 1e5
	choices.sort_custom(func(a, b): return float(a.score) < float(b.score))
	# 너무 많으면 가까운 것 위주로(이야기·노정 끝은 남김)
	if choices.size() > 9: choices = choices.slice(0, 9)

func _node_name(n: Dictionary) -> String:
	var nm := String(n.get("name", ""))
	match String(n.kind):
		"ROUTE_END": return nm
		"CITY": return nm + " 성문 앞"
		"BOAT": return nm + " 나루"
		"CAVE": return nm
	return nm

# ---- 타기 시작 ----
func begin_ride(c: Dictionary) -> bool:
	if mounted(): return false
	var pp := Vector2(main.player_pos.x, main.player_pos.z)
	var dj: Dictionary = net.dijkstra(_choice_from if _choice_from >= 0 else net.nearest(pp, ROAD_R + 1.5))
	var ids: PackedInt32Array = net.path_ids(dj, int(c.gi))
	if ids.size() < 2: return false
	dest = c
	_make_path(pp, ids)
	s = 0.0; v = 0.0; halted = false
	_plan_marks()
	_find_forks(ids)
	_ensure_horse()
	# 말이 뒤에서 다가온다
	var h := _heading(0.0)
	var from := pp - h * 12.0
	_mount_from = Vector3(from.x, world.height_at(from.x, from.y), from.y)
	horse.position = _mount_from
	horse.visible = true
	horse.set_anim("walk")
	_t = 0.0
	_last_dismount = Vector2.INF
	_arrived_mount = Vector2.INF
	stats = { t0 = Time.get_ticks_msec() / 1000.0, dist = 0.0, slow = {}, stops = [], max_v = 0.0, run_s = L / 4.6, dest = String(c.node.id) }
	_set_state("MOUNTING")
	audio_cue.emit("mount", 0.0)
	print("RIDE start %s → %s(%s) len=%.0fm marks=%d forks=%d stop=%.0f" % [net.space, String(c.node.id), String(c.name), L, marks.size(), forks.size(), stop_s])
	if test_log:
		for mk in marks: print("RIDE mark %s %s s=%.0f~%.0f v=%.1f %s%s" % [mk.kind, mk.id, mk.s0, mk.s1, mk.speed, mk.name, " MUST" if mk.must else ""])
	var st = main.story
	if st != null and st.get("onboard") != null:
		st.onboard.once("RIDE", "말이 큰길을 따라 저절로 간다\nSpace 멈춤·다시 감   ·   E 내리기\n갈림길 앞에서는 A·D로 길을 고른다", func(): return not mounted(), 9.0)
	return true

func _make_path(start: Vector2, ids: PackedInt32Array) -> void:
	var raw := PackedVector2Array([start])
	for i in ids:
		var q: Vector2 = net.pts[i]
		if q.distance_to(raw[raw.size() - 1]) > 0.5: raw.append(q)
	# 모서리 다듬기(차이킨 1회 — 양 끝은 그대로)
	var sm := PackedVector2Array([raw[0]])
	for i in range(raw.size() - 1):
		var a := raw[i]; var b := raw[i + 1]
		if i > 0: sm.append(a.lerp(b, 0.25))
		if i < raw.size() - 2: sm.append(a.lerp(b, 0.75))
	sm.append(raw[raw.size() - 1])
	path = sm
	cum = PackedFloat32Array([0.0])
	for i in range(1, path.size()): cum.append(cum[i - 1] + path[i].distance_to(path[i - 1]))
	L = cum[cum.size() - 1]

func _at(ss: float) -> Vector2:
	if path.size() == 0: return Vector2.ZERO
	if ss <= 0.0: return path[0]
	if ss >= L: return path[path.size() - 1]
	var i := clampi(cum.bsearch(ss) - 1, 0, path.size() - 2)
	return path[i].lerp(path[i + 1], (ss - cum[i]) / maxf(cum[i + 1] - cum[i], 1e-5))

func _heading(ss: float) -> Vector2:
	var a := _at(clampf(ss - 3.0, 0.0, L)); var b := _at(clampf(ss + 5.0, 0.0, L))
	var d := b - a
	if d.length() < 0.01: return Vector2(0, -1)
	return d.normalized()

# 이 점에 가장 가까운 길 위 s(거리 d)
func _proj(p: Vector2) -> Array:
	var bs := 0.0; var bd := INF
	for i in path.size() - 1:
		var q := Geometry2D.get_closest_point_to_segment(p, path[i], path[i + 1])
		var d := q.distance_to(p)
		if d < bd: bd = d; bs = cum[i] + q.distance_to(path[i])
	return [bs, bd]

# ---- 길 위 표시(감속·멈춤) ----
func _plan_marks(keep_from := 0.0) -> void:
	marks = []
	_story_t = -1.0   # 이야기 자리는 지금 것으로
	var auto_slow := GameSettings.get_v("ride_slow") != "off"
	var done_route: bool = world.is_route and Progress.route_done(net.space)
	var st = main.story
	var dest_id := String(dest.node.id) if not dest.is_empty() else ""
	var start := _at(0.0)
	for sp in net.stops:
		var pol := String(sp.get("STOP_POLICY", "PASS"))
		var must := bool(sp.get("MUST", false))
		if pol == "PASS": continue
		if bool(sp.get("FIRST_VISIT_ONLY", false)) and done_route: pol = "OPTIONAL_STOP"
		if sp.has("WHEN"):
			if st == null or st.get("runner") == null or st.runner == null or not st.runner.cond(sp.WHEN): continue
		var nid := String(sp.get("node", ""))
		if nid != "" and nid == dest_id: continue
		var z: Dictionary = sp.get("zone", {})
		if z.is_empty() or RideNet.in_zone(z, start, 5.0) and not sp.has("APPROACH_M"): continue   # 떠나는 구역
		if sp.has("APPROACH_M"):   # 손 고침 사건 자리: 트리거 바깥에서 APPROACH_M 앞
			var tp: Array = sp.TRIGGER_POSITION
			var pr := _proj(Vector2(float(tp[0]), float(tp[1])))
			if float(pr[1]) > float(sp.get("RADIUS", 14.0)) + 20.0: continue
			var s_stop: float = float(pr[0]) - float(sp.get("RADIUS", 14.0)) - clampf(float(sp.APPROACH_M), 70.0, 200.0)
			if s_stop < keep_from + NO_STOP_NEAR: continue
			marks.append({ kind = "stop", s0 = s_stop, s1 = s_stop, speed = 0.0, id = String(sp.TRAVEL_EVENT_ID), name = String(sp.get("name", "")), must = true, why = "event" })
			continue
		var iv := _zone_interval(z)
		if iv.is_empty(): continue
		if pol == "FORCED_STOP":
			var s_stop: float = float(iv[0]) - 6.0
			if s_stop < keep_from + NO_STOP_NEAR: continue
			marks.append({ kind = "stop", s0 = s_stop, s1 = s_stop, speed = 0.0, id = String(sp.TRAVEL_EVENT_ID), name = String(sp.get("name", "")), must = true,
				why = "city" if String(sp.get("EVENT_TYPE", "")) == "CITY" else ("end" if nid.begins_with("end_") else "gate") })
		elif pol == "OPTIONAL_STOP" and (auto_slow or must):
			var spd := float(sp.get("SLOW_SPEED", 6.0))
			if spd <= 0.0: continue
			marks.append({ kind = "slow", s0 = float(iv[0]), s1 = float(iv[1]), speed = spd, id = String(sp.TRAVEL_EVENT_ID), name = String(sp.get("name", "")), must = must, why = "zone" })
	# 이야기(실행 중 사건 데이터): 사건 트리거·조사 대상 = 앞에서 내림, 엿듣는 대사·소문·길가 장면 = 감속
	for p in _story_points():
		var pr := _proj(p.p)
		if String(p.kind) == "event":
			if float(pr[1]) > float(p.r) + 18.0: continue
			var s_stop: float = float(pr[0]) - float(p.r) - float(p.approach)
			if s_stop < keep_from + NO_STOP_NEAR: continue
			marks.append({ kind = "stop", s0 = s_stop, s1 = s_stop, speed = 0.0, id = String(p.id), name = String(p.get("name", "")), must = true, why = "event", p = p.p, r = p.r })
		else:
			if float(pr[1]) > float(p.r) + 6.0: continue
			# 들어서기 10m 앞부터 들어선 뒤 (자막 4초 × 감속 빠르기)만큼 — 엿듣는 한 줄이 끝까지 보이게(구역 전체를 기지 않는다)
			var half := sqrt(maxf(0.0, pow(float(p.r), 2) - pow(float(pr[1]), 2)))
			var s_in: float = float(pr[0]) - half
			marks.append({ kind = "slow", s0 = s_in - 10.0, s1 = minf(s_in + float(p.speed) * 4.5, float(pr[0]) + half + 4.0), speed = float(p.speed), id = String(p.id),
				name = String(p.get("name", "")), must = true, why = "story" })
	# 가장 앞 멈춤 = 목적지 또는 그 전 멈춤
	stop_s = L; stop_mark = { kind = "stop", s0 = L, id = dest_id, name = String(dest.get("name", "")), why = "dest" }
	for mk in marks:
		if String(mk.kind) == "stop" and float(mk.s0) < stop_s and float(mk.s0) > keep_from:
			stop_s = maxf(float(mk.s0), keep_from + 2.0); stop_mark = mk

# 구역에 길이 처음 드는 s ~ 나오는 s(4m 간격). 없으면 []
func _zone_interval(z: Dictionary) -> Array:
	var s0 := -1.0; var s1 := -1.0
	var ss := 0.0
	while ss <= L:
		if RideNet.in_zone(z, _at(ss)):
			if s0 < 0.0: s0 = ss
			s1 = ss
		elif s0 >= 0.0: break
		ss += 4.0
	if s0 < 0.0: return []
	return [s0, s1]

# 갈림길: 길 점 이웃이 셋 넘는 곳에서 다른 갈래로 가면 닿는 거점(2.5km 안)
func _find_forks(ids: PackedInt32Array) -> void:
	forks = []
	var on := {}
	for i in ids: on[i] = true
	for k in range(2, ids.size() - 3):
		var gi: int = ids[k]
		if net.degree(gi) < 3: continue
		var nxt: int = ids[k + 1]; var prv: int = ids[k - 1]
		var fwd: Vector2 = (net.pts[ids[mini(k + 3, ids.size() - 1)]] - net.pts[gi]).normalized()
		var opts := []
		for b in net.nb[gi]:
			if b == nxt or b == prv or on.has(b) or net.city[b] == 1: continue
			var hit := _branch_target(gi, b)
			if hit.is_empty(): continue
			var bd: Vector2 = (net.pts[_walk_branch(gi, b, 3)] - net.pts[gi]).normalized()
			var side := fwd.cross(bd)   # 화면 좌우가 아니라 가는 방향 기준(+ = 오른쪽: x→z 좌표계에서)
			opts.append({ dir = "right" if side > 0.0 else "left", label = String(hit.name), node = hit.node, gi = int(hit.gi) })
		if opts.is_empty(): continue
		var pr := _proj(net.pts[gi])
		# 30m 안 갈림(한 네거리의 두 점)은 하나로
		if not forks.is_empty() and absf(float(forks[-1].s) - float(pr[0])) < 30.0:
			for o in opts:
				if not forks[-1].opts.any(func(x): return String(x.label) == String(o.label)): forks[-1].opts.append(o)
			continue
		forks.append({ s = float(pr[0]), gi = gi, opts = opts, done = false, cur = String(dest.get("name", "")) })

func _walk_branch(from: int, b: int, n: int) -> int:
	var prev := from; var cur := b
	for i in n:
		var nx := -1
		for w in net.nb[cur]:
			if w != prev: nx = w; break
		if nx < 0: break
		prev = cur; cur = nx
	return cur

# from에서 b 쪽으로만 가며 닿는 거점 어귀(2.5km 안) — 노정 끝 > 고을·마을·역·나루 > 그 밖, 같으면 가까운 것
func _branch_target(from: int, b: int) -> Dictionary:
	var gate_of := {}
	for n in net.nodes:
		if HIDDEN_KINDS.has(String(n.kind)): continue
		if not bool(n.get("fast", false)) and not String(n.kind) in ["ROUTE_END", "BOAT"]: continue
		if not dest.is_empty() and String(n.id) == String(dest.node.id): continue
		for g in n.get("gates", []): gate_of[int(g.gi)] = n
	var best := {}; var best_sc := INF
	var dist := { b: net.pts[from].distance_to(net.pts[b]) }
	var hk := PackedFloat32Array(); var hv := PackedInt32Array()
	RideNet._push(hk, hv, float(dist[b]), b)
	while hk.size() > 0:
		var top: Array = RideNet._pop(hk, hv)
		var d: float = top[0]; var u: int = top[1]
		if d > float(dist.get(u, INF)) + 0.01 or d > 2500.0: continue   # 힙은 32비트 실수 — 사전 값(64비트)과 비교할 때 오차
		if gate_of.has(u):
			var n: Dictionary = gate_of[u]
			if not RideNet.in_zone(n.zone, net.pts[from], 12.0):   # 갈림 자리 자체의 거점(갈림길 주막 등)은 빼고
				var pri: int = 0 if String(n.kind) == "ROUTE_END" else (1 if String(n.kind) in ["CITY", "HUB", "STATION", "VILLAGE", "MARKET", "FERRY", "BOAT"] else 2)
				var sc: float = pri * 10000.0 + d
				if sc < best_sc: best_sc = sc; best = { node = n, gi = u, name = _node_name(n) }
		for w in net.nb[u]:
			if w == from or net.city[w] == 1: continue
			var nd: float = d + net.pts[u].distance_to(net.pts[w])
			if nd < float(dist.get(w, INF)):
				dist[w] = nd
				RideNet._push(hk, hv, nd, w)
	return best

# ---- 말 오르기 ----
func _update_mounting(dt: float) -> void:
	_t += dt
	prompt = ""; hint = ""
	var pp: Vector3 = main.player_pos
	var h := _heading(0.0)
	var side := Vector2(-h.y, h.x)
	var stand := Vector2(pp.x, pp.z) + side * 0.9
	if _t < T_BRING:
		var k := smoothstep(0.0, 1.0, _t / T_BRING)
		var q := Vector2(_mount_from.x, _mount_from.z).lerp(stand, k)
		horse.position = Vector3(q.x, world.height_at(q.x, q.y), q.y)
		horse.facing = main.facing_cam(h.x, h.y, horse.facing)
		horse.set_anim("walk")
		return
	horse.set_anim("idle")
	horse.position = Vector3(stand.x, world.height_at(stand.x, stand.y), stand.y)
	var k2 := clampf((_t - T_BRING) / T_MOUNT, 0.0, 1.0)
	main.player.set_anim("mount" if main.player.has_anim("mount") else rider_anim)
	main.player.facing = horse.facing
	if k2 >= 1.0:
		# 말 위로: 플레이어 자리 = 말 자리(길 첫 점)
		var p0 := _at(0.0)
		s = 0.0
		var a := Vector2(horse.position.x, horse.position.z)
		var pr := _proj(a)
		s = minf(float(pr[0]), L)
		main.player_pos = Vector3(a.x, world.height_at(a.x, a.y), a.y)
		_seat = main.player_pos
		main.player.set_anim(rider_anim)
		_set_state("AUTO_RIDE")
		audio_cue.emit("hooves_start", 0.0)
		if p0 == Vector2.ZERO: pass

# ---- 타고 가기 ----
func _update_ride(dt: float, free: bool) -> void:
	prompt = ""
	var st = main.story
	# 이야기가 플레이어를 옮겼다(teleport) → 내린 것으로
	if _seat != Vector3.INF and main.player_pos.distance_to(_seat) > 3.0:
		_drop("옮겨짐", true); return
	var paused: bool = st != null and st.owns_player()
	if _blizzard():
		if stop_mark.get("why", "") != "blizzard":
			stop_s = minf(stop_s, s + maxf(4.0, v * v / (2.0 * DECEL) + 2.0)); stop_mark = { kind = "stop", s0 = stop_s, id = "blizzard", name = "눈보라", why = "blizzard" }
	# 입력: Space 멈춤·다시 감, E 내리기, 갈림길 A/D/W
	if free and not paused:
		if Input.is_action_just_pressed("boat_skip"):
			halted = not halted
			audio_cue.emit("halt" if halted else "hooves_start", v)
		if Input.is_action_just_pressed("interact"):
			stop_s = minf(stop_s, s + maxf(3.0, v * v / (2.0 * DECEL) + 1.0)); stop_mark = { kind = "stop", s0 = stop_s, id = "player", name = "", why = "player" }
			halted = false
	top = _top_speed()
	var want := top
	# 감속 구역
	var zone_now := ""
	for mk in marks:
		if String(mk.kind) != "slow": continue
		var spd := float(mk.speed)
		if s >= float(mk.s0) and s <= float(mk.s1):
			if spd < want: want = spd; zone_now = String(mk.name)
			if test_log and not stats.slow.has(mk.id):
				stats.slow[mk.id] = { s = s, v = v }
				print("RIDE slow %s %s s=%.0f v=%.1f" % [mk.id, mk.name, s, v])
		elif float(mk.s0) > s:
			want = minf(want, sqrt(spd * spd + 2.0 * DECEL * (float(mk.s0) - s)))
	if zone_now != _slow_name:
		_slow_name = zone_now
		if zone_now != "": audio_cue.emit("slow", 0.0)
	# 모서리
	var h0 := _heading(s); var h1 := _heading(minf(s + 18.0, L))
	var ang := absf(h0.angle_to(h1))
	want = minf(want, lerpf(top, 5.0, clampf(ang / 1.1, 0.0, 1.0)))
	# 갈림길 고르기
	var fk = _fork_ahead()
	if fk != null:
		want = minf(want, 9.0)
		if free and not paused: _fork_input(fk)
	# 멈춤(목적지·성문·사건) — 마지막 몇 m는 걸음으로 닿는다
	want = minf(want, maxf(sqrt(2.0 * DECEL * maxf(0.0, stop_s - s)), 1.2 if stop_s - s > 0.3 else 0.0))
	# 막힘(길 위 사람·짐승): 멈춰 기다리다(1.2초) 사람이 안 비키면 천천히 비켜 지난다
	if _blocked_ahead():
		if _block_t <= 0.0: audio_cue.emit("halt", v)
		_block_t += dt
	else: _block_t = 0.0
	if _block_t > 0.0: want = 0.0 if _block_t < 1.2 else minf(want, 2.5)
	if halted or paused: want = 0.0
	v = move_toward(v, want, (ACCEL if want > v else DECEL * 1.6) * dt)
	s = minf(s + v * dt, L)
	if test_log:
		stats.dist = s; stats.max_v = maxf(float(stats.max_v), v)
	var p := _at(s)
	main.player_pos = Vector3(p.x, world.height_at(p.x, p.y), p.y)
	_seat = main.player_pos
	var h := _heading(s)
	horse.position = main.player_pos
	horse.facing = main.facing_cam(h.x, h.y, horse.facing)
	main.player.facing = horse.facing
	var gait := "run" if v > 7.0 else ("walk" if v > 0.4 else "idle")
	horse.set_anim(gait)
	horse.move_speed = v * (0.5 if gait == "run" else 0.8)
	main.player.set_anim(rider_anim)
	main.player.anim_speed = 1.0 + v / 12.0
	_set_state("RIDE_SLOW" if (want < top * 0.6 and v < top * 0.7) else "AUTO_RIDE")
	_gait_t -= dt
	if _gait_t <= 0.0:
		_gait_t = 0.5; audio_cue.emit("gait", v)
	# 카메라 흔들림
	var amp: float = { normal = 0.0, weak = 0.0, off = 0.0 }.get(GameSettings.get_v("cam_shake"), 0.0)   # 흔들림 없음(눈 피로) — 설정은 남겨 둠
	_bob_ph += dt * (2.0 + v * 0.12) * TAU
	bob = amp * clampf(v / 10.0, 0.0, 1.0) * sin(_bob_ph)
	# 안내
	var mins := maxf(0.0, (L - s) / maxf(top * 0.8, 1.0) / 60.0)
	if fk != null: hint = _fork_text(fk)
	elif halted: hint = "멈춤 — Space 다시 간다 · E 내린다"
	elif zone_now != "": hint = "%s — 천천히 지난다   ·   E 내려서 둘러본다" % zone_now
	else: hint = "%s 쪽으로 · 약 %s   ·   Space 멈춤 · E 내리기" % [String(dest.get("name", "")), ("%d분" % ceili(mins)) if mins >= 1.0 else "곧"]
	# 멈춤에 닿음
	if s >= stop_s - 0.4 and v < 0.7:
		_arrive_stop()

func _fork_ahead():
	for f in forks:
		if bool(f.done): continue
		if s > float(f.s) + 2.0: f.done = true; continue
		if float(f.s) - s < 110.0: return f
		return null
	return null

func _fork_text(f: Dictionary) -> String:
	var parts := []
	for o in f.opts:
		parts.append("%s %s" % ["A ←" if o.dir == "left" else "D →", String(o.label)])
	return "갈림길 — %s   ·   그대로: %s" % [" · ".join(parts), String(dest.get("name", ""))]

func _fork_input(f: Dictionary) -> void:
	var pick := ""
	if Input.is_action_just_pressed("move_left"): pick = "left"
	elif Input.is_action_just_pressed("move_right"): pick = "right"
	if pick == "": return
	for o in f.opts:
		if String(o.dir) != pick: continue
		_replan_from(int(f.gi), o)
		f.done = true
		_hud = "갈림길 — %s 쪽으로" % String(o.label)
		return

# 갈림길에서 다른 목적지로: 지금 자리까지 지나온 길 + 갈림 점에서 새 길
func _replan_from(gi: int, o: Dictionary) -> void:
	var dj: Dictionary = net.dijkstra(gi)
	var ids: PackedInt32Array = net.path_ids(dj, int(o.gi))
	if ids.size() < 2: return
	var pr := _proj(net.pts[gi])
	var keep := PackedVector2Array()
	var ss := 0.0
	while ss < float(pr[0]):
		keep.append(_at(ss)); ss += 4.0
	var here_s := s
	var start: Vector2 = net.pts[gi]
	var old_dest := dest
	dest = { node = o.node, gi = int(o.gi), d = float(dj.dist[int(o.gi)]), name = String(o.label) }
	_make_path(start, ids)
	# 앞부분(지나온 길)을 붙인다
	var full := keep
	full.append_array(path)
	path = full
	cum = PackedFloat32Array([0.0])
	for i in range(1, path.size()): cum.append(cum[i - 1] + path[i].distance_to(path[i - 1]))
	L = cum[cum.size() - 1]
	var pr2 := _proj(Vector2(main.player_pos.x, main.player_pos.z))
	s = float(pr2[0])
	_plan_marks(s)
	_find_forks(ids)
	if test_log: print("RIDE fork %s → %s (was %s) s=%.0f→%.0f" % [gi, String(o.label), String(old_dest.get("name", "")), here_s, s])

# 길 앞 3m 안에 사람·짐승(주변 인물·이야기 인물)이 서 있으면 멈춰 기다린다(1.2초 — 안 비키면 천천히 비켜 지난다). 놓인 물체는 보지 않는다 —
# 길 데이터(걷기 시험으로 막힘 0)가 다리·여울을 건너며, 중심선에서 난간 충돌체를 스치는 것을 막힘으로 보지 않게.
func _blocked_ahead() -> bool:
	if v < 0.3 and _block_t <= 0.0: return false
	var h := _heading(s)
	var p := _at(s)
	var amb = main.get("npcs_amb")
	if amb != null:
		for k in amb.agents:
			var ag: Dictionary = amb.agents[k]
			if ag.get("ch") == null or not (ag.ch as SpriteChar).visible: continue
			if _in_front(Vector2(ag.pos.x, ag.pos.z) - p, h): return true
	var st = main.story
	if st != null:
		for id in st.actors:
			var a: Dictionary = st.actors[id]
			if a.get("ch") == null or not (a.ch as SpriteChar).visible: continue
			if _in_front(Vector2(a.pos.x, a.pos.z) - p, h): return true
	return false

static func _in_front(q: Vector2, h: Vector2) -> bool:
	var ahead := q.dot(h)
	return ahead > 1.0 and ahead < 3.4 and absf(q.cross(h)) < 0.9

func _arrive_stop() -> void:
	var why := String(stop_mark.get("why", "dest"))
	var nm := String(stop_mark.get("name", ""))
	if test_log:
		stats.stops.append({ why = why, id = String(stop_mark.get("id", "")), s = s, at = Vector2(main.player_pos.x, main.player_pos.z) })
	match why:
		"dest":
			var k := String(dest.node.kind) if not dest.is_empty() else ""
			if k == "CITY": _hud = "%s — 성 안은 걸어서 든다" % String(dest.name)
			elif k == "ROUTE_END": _hud = "길 끝 — 여기서부터 걸어서 넘어간다"
			elif k == "BOAT": _hud = "%s — 배는 걸어서 오른다" % String(dest.name)
			else: _hud = "%s 어귀에 닿았다" % String(dest.name)
		"city": _hud = "성문 앞 — 말에서 내린다"
		"end": _hud = "길 끝 — 말에서 내린다"
		"event":
			_hud = "이 앞은 걸어서 간다"
			_approach = { p = stop_mark.get("p", Vector2(main.player_pos.x, main.player_pos.z)), r = float(stop_mark.get("r", 14.0)), id = String(stop_mark.get("id", "")), t = 0.0 }
			audio_cue.emit("event_near", 0.0)
		"blizzard": _hud = "눈보라 — 말에서 내려 고삐를 잡고 걷는다"
		"blocked": _hud = "길이 막혔다 — 말에서 내린다"
		"gate": _hud = "%s — 이 앞은 걸어서 간다" % nm if nm != "" else "이 앞은 걸어서 간다"
		_: _hud = ""
	print("RIDE stop why=%s id=%s s=%.0f/%.0f at=(%.1f,%.1f) t=%.1fs" % [why, String(stop_mark.get("id", "")), s, L, main.player_pos.x, main.player_pos.z,
		Time.get_ticks_msec() / 1000.0 - float(stats.get("t0", 0.0))])
	_begin_dismount(why)

func _begin_dismount(why: String) -> void:
	_t = 0.0
	stop_mark["why"] = why
	_set_state("DISMOUNTING")
	audio_cue.emit("hooves_stop", 0.0)
	horse.set_anim("idle")

func _update_dismounting(dt: float) -> void:
	_t += dt
	hint = ""; prompt = ""
	main.player.set_anim("dismount" if main.player.has_anim("dismount") else "idle")
	if _t < T_DISMOUNT: return
	_finish_dismount()

func _finish_dismount() -> void:
	var why := String(stop_mark.get("why", "dest"))
	# 말 옆(길 가장자리)에 내려선다
	var h := _heading(s)
	var side := Vector2(-h.y, h.x)
	var p := Vector2(main.player_pos.x, main.player_pos.z) + side * 0.9
	if world.blocked(p.x, p.y, main.player.radius): p = Vector2(main.player_pos.x, main.player_pos.z)
	main.player_pos = Vector3(p.x, world.height_at(p.x, p.y), p.y)
	main.player.position = main.player_pos
	main.player.set_anim("idle")
	main.player.anim_speed = 1.0
	if main.player.get("_blob") != null: main.player._blob.visible = true
	_last_dismount = p
	_seat = Vector3.INF
	bob = 0.0
	_horse_s = s; _horse_leave = 3.2
	audio_cue.emit("dismount", 0.0)
	var nid := String(dest.node.id) if not dest.is_empty() else ""
	_set_state("EVENT_APPROACH" if why == "event" else "ON_FOOT")
	ride_done.emit(nid if why == "dest" else String(stop_mark.get("id", "")), why)
	if test_log:
		print("RIDE done why=%s dest=%s ride_s=%.1f dist=%.0f run_s=%.1f max_v=%.1f slow=%s" % [why, nid, Time.get_ticks_msec() / 1000.0 - float(stats.get("t0", 0.0)),
			s, float(stats.get("run_s", 0.0)), float(stats.get("max_v", 0.0)), (stats.slow as Dictionary).keys()])

# 바로 내림(싸움·이야기 teleport) — 말은 물러간다
func _drop(why: String, instant: bool) -> void:
	if not mounted(): return
	print("RIDE drop %s s=%.0f" % [why, s])
	stop_mark = { why = why, id = why }
	_seat = Vector3.INF
	bob = 0.0
	if main.player.get("_blob") != null: main.player._blob.visible = true
	main.player.anim_speed = 1.0
	if instant and main.player.anim in [rider_anim, "mount", "dismount"]: main.player.set_anim("idle")
	_horse_s = s; _horse_leave = 2.5
	_last_dismount = Vector2(main.player_pos.x, main.player_pos.z)
	_set_state("ON_FOOT")
	audio_cue.emit("hooves_stop", 0.0)

# 내린 뒤 말은 왔던 길로 물러가다 사라진다(§14)
func _update_horse_leave(dt: float) -> void:
	if horse == null or mounted() or not horse.visible: return
	if _horse_leave <= 0.0:
		horse.visible = false; return
	_horse_leave -= dt
	if _t < 0.4: _t += dt; horse.set_anim("idle")
	else:
		_horse_s = maxf(0.0, _horse_s - 2.6 * dt)
		var q := _at(_horse_s) + Vector2(-_heading(_horse_s).y, _heading(_horse_s).x) * -1.2
		horse.position = Vector3(q.x, world.height_at(q.x, q.y), q.y)
		var h := -_heading(_horse_s)
		horse.facing = main.facing_cam(h.x, h.y, horse.facing)
		horse.set_anim("walk")
	horse.update_char(dt, main.cam)

# region_main이 player.position = player_pos 다음에 부른다: 탄 사람을 안장 위에, 말 그림 갱신
func place_rider(dt: float) -> void:
	if horse == null or not mounted():
		return
	var cam: Camera3D = main.cam
	var hp := horse.position
	var to_cam := (cam.global_position - hp); to_cam.y = 0.0
	to_cam = to_cam.normalized() if to_cam.length() > 0.01 else Vector3.BACK
	var front := horse.facing == "down"   # 말이 카메라 쪽을 볼 때는 말 머리·목이 탄 사람 앞
	if state == "MOUNTING":
		var k := clampf((_t - T_BRING) / T_MOUNT, 0.0, 1.0)
		var base: Vector3 = main.player_pos
		var top_p := hp + Vector3(0, saddle, 0) + to_cam * (-0.12 if front else 0.12)
		main.player.position = base.lerp(top_p, smoothstep(0.0, 1.0, k)) if k > 0.0 else base
		if main.player.get("_blob") != null: main.player._blob.visible = k < 0.5
	elif state == "DISMOUNTING":
		var k2 := clampf(_t / T_DISMOUNT, 0.0, 1.0)
		var h := _heading(s); var side := Vector3(-h.y, 0, h.x) * 0.9
		var top_p := hp + Vector3(0, saddle, 0) + to_cam * (-0.12 if front else 0.12)
		var ground := hp + side
		ground.y = world.height_at(ground.x, ground.z)
		main.player.position = top_p.lerp(ground, smoothstep(0.0, 1.0, k2))
		if main.player.get("_blob") != null: main.player._blob.visible = k2 > 0.6
	else:
		main.player.position = hp + Vector3(0, saddle + bob * 0.4, 0) + to_cam * (-0.12 if front else 0.12)
		if main.player.get("_blob") != null: main.player._blob.visible = false
	horse.update_char(dt, cam)

func _ensure_horse() -> void:
	if horse != null: return
	horse = SpriteChar.new(horse_kind if horse_kind != "" else "player")
	horse.name = "말"
	main.scene_vp.add_child(horse)
	horse.visible = false

# ---- 노정 끝으로 넘어온 자리(포털 곁)는 말 타는 곳 ----
func on_arrived(p: Vector2) -> void:
	_arrived_mount = p

# ---- 빠른 이동 거점 알기(§10·§27·§28): 거점 구역에 들면 기록 ----
func _discover(dt: float) -> void:
	_disc_t -= dt
	if _disc_t > 0.0 or net == null: return
	_disc_t = 0.5
	if main._loading: return
	var pp := Vector2(main.player_pos.x, main.player_pos.z)
	for n in net.nodes:
		if not bool(n.get("fast", false)): continue
		var a: Array = n.get("arrive", [n.x, n.z])
		if RideNet.in_zone(n.zone, pp, 10.0) or pp.distance_to(Vector2(float(a[0]), float(a[1]))) < 30.0:
			discover(net.space, String(n.id))

static func known_nodes() -> Dictionary:
	var d := Progress.data()
	if not (d.get("travel_nodes") is Dictionary): d["travel_nodes"] = {}
	return d.travel_nodes

static func is_discovered(space: String, id: String) -> bool:
	var k = known_nodes().get(space)
	return k is Dictionary and k.has(id)

static func discover(space: String, id: String) -> bool:
	var kn := known_nodes()
	if not (kn.get(space) is Dictionary): kn[space] = {}
	if kn[space].has(id): return false
	kn[space][id] = Time.get_datetime_string_from_system()
	Progress.save()
	print("TRAVEL node %s/%s" % [space, id])
	return true

# ---- 이야기 자리(실행 중 사건 데이터에서) ----
# [{kind:"event"|"slow", p, r, id, name, approach, speed}]
func _story_points() -> Array:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _story_t < 0.5: return _story_cache
	_story_t = now
	var out := []
	var d = main.story
	if d == null:
		_story_cache = out; return out
	if d.case_id != "" and d.S != null and d.runner != null and bool(d.get("_started")):
		for t in d.data.get("triggers", []):
			if not t.has("at"): continue
			if t.get("once", true) and d.S.flags.has("_trig_" + String(t.id)): continue
			if not d.runner.cond(t.get("when", true)): continue
			var p: Vector2 = d.anchor(t.at)
			var r := float(t.get("radius", 8.0))
			if t.has("ambient"): out.append({ kind = "slow", p = p, r = r, id = "trig_" + String(t.id), name = "", speed = 4.0 })
			else: out.append({ kind = "event", p = p, r = r, id = "trig_" + String(t.id), name = String(t.id), approach = STORY_APPROACH })
		for o in d.data.get("objects", []):
			var w = o.get("when", true)
			if not (w is String) or String(w) == "true" or not o.has("at"): continue
			if not d.runner.cond(w): continue
			out.append({ kind = "event", p = d.anchor(o.at), r = float(o.get("radius", 2.5)) + 6.0, id = "obj_" + String(o.id), name = String(o.get("label", o.id)), approach = 70.0 })
	var vg = d.get("_vign")
	if vg != null:
		for it in vg.items:
			var vid := String(it.spec.id)
			if vg.seen(vid): continue
			out.append({ kind = "slow", p = it.p, r = float(it.spec.get("radius", 12.0)) + 8.0, id = "vign_" + vid, name = "", speed = 3.5 })
	var seen: Dictionary = d.get("_rumor_seen") if d.get("_rumor_seen") is Dictionary else {}
	for r in Rumors.for_space(String(d.space_id), world.region):
		if seen.has(String(r.id)): continue
		if Rumors.pick(r, Progress.vars(), d.S.vars if d.S != null else {}) == "": continue
		out.append({ kind = "slow", p = r.p, r = float(r.get("radius", 26.0)), id = "rumor_" + String(r.id), name = "", speed = 5.0 })
	_story_cache = out
	return out

func _story_point_alive(id: String) -> bool:
	_story_t = -1.0
	for p in _story_points():
		if String(p.id) == id: return true
	return false
