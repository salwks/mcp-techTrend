# 추격 — 스크립트로 달아나는 인물을 플레이어가 쫓는다(데이터 중심, 사건 4·6·9도 같이 쓴다).
#   사건 데이터 "chases": { <id>: spec }. 이야기 명령 { "chase": "<id>", "store": "chase" } 또는 사건 GDScript에서 Chase.run(d, id).
#   결과: "end"(끝 자리까지 따라감 — 달아난 인물은 거기서 사라진다) | "lost"(놓침). 놓친 자리(되돌아갈 길목)는 S.flags["_chase_<id>_cp"].
#
# spec:
#   actor: 달아나는 인물 id(사건 actors에 있어야 한다)        speed: 기본 달리기 m/s(플레이어 달리기 4.6)
#   burst: 따라붙으면 내는 속도(플레이어보다 빠르게 — 순간이동 없이 앞섬을 지킨다)   lead: 바라는 앞섬(m, 쫓는 길 따라)
#   min_lead: 이보다 가까우면 burst      wait_lead: 이보다 멀어지면 멈춰 돌아본다(기다림)
#   lose_lead / lose_off: 앞섬이 이보다 커지거나 쫓는 길에서 이만큼 벗어난 채 lose_time초 지나면 놓침
#   wake_lead: 첫 구간은 플레이어가 이만큼 다가올 때까지(또는 wake_time초) 서서 지켜본다
#   camera: 추격 동안 카메라 { distance, pitch, fov }      end_anim·vanish_delay: 끝 자리에서의 동작과 사라지기까지 초
#   segments: [{ mode, run:[자리…], follow:[자리…], speed(배율), anim, y(지붕 높이, m — climb의 목표), ink(먹 실루엣),
#               caption(들어설 때 자막), checkpoint(다시 쫓기 시작점), shortcut(지름길 — 플레이어가 돌아갈 길이 follow) }]
#     mode: lane(골목) · bank(개천 둑) · climb(담·지붕 오르기: 땅 → 지붕 높이) · roof(지붕 위, 보기만 — 플레이어는 아래 길로) ·
#           drop(뛰어내림: 지붕 → 땅). run은 달아나는 인물의 길, follow는 플레이어가 따라갈 길(없으면 run과 같다).
#     앞섬은 follow를 이은 한 줄 위에서 잰다(달아나는 인물의 구간 진행률을 follow 길이로 옮겨서).
#
# 순간이동 금지: 달아나는 인물은 늘 길을 따라 움직이고, 앞섬은 속도(따라붙으면 더 빨리, 멀어지면 멈춰 기다림)와
#   플레이어가 갈 수 없는 지름길(담·지붕)로만 지킨다. 놓쳤을 때 다시 쫓기는 플레이어를 마지막 길목 뒤로 옮긴다(암전 속).
# 지나가는 인물 순찰(patrol)도 여기 있다: Chase.patrol(d, dt) — actors 항목의 "patrol": [자리…], "patrol_speed".
extends Node

signal done(result: String)

var d                      # story_director
var id := ""
var spec: Dictionary
var a: Dictionary          # 달아나는 인물(director.actors 항목)
var segs: Array = []
var follow_total := 0.0
var seg_i := 0
var seg_s := 0.0
var cur_y := NAN           # 지붕 위 높이(절대 y). NAN이면 땅
var prog := 0.0            # 플레이어 진행(follow 길이)
var lead := 0.0
var off := 0.0
var t := 0.0
var lost_t := 0.0
var started := false
var waiting := false
var finished := false
var _end_t := -1.0
var _wait_used := 0.0      # 이번에 멈춰 기다린 시간 — wait_max를 넘기면 다시 달린다(그래야 놓칠 수 있다)
var _anim := ""
var _ink := false
var min_lead_seen := INF
var max_speed_seen := 0.0
var fps_min := INF
var _fps_acc := 0.0
var _fps_n := 0

static func run(director, chase_id: String, from_cp := -1) -> String:
	var spec_d: Dictionary = director.data.get("chases", {}).get(chase_id, {})
	if spec_d.is_empty():
		push_warning("추격: 없는 추격 " + chase_id); return "end"
	var c = load("res://scripts/story/chase.gd").new()
	c.name = "chase"
	c.d = director
	c.id = chase_id
	c.spec = spec_d
	director.add_child(c)
	c._begin(from_cp)
	var res: String = await c.done
	c.queue_free()
	return res

# ---------------------------------------------------------------------------
# 준비
# ---------------------------------------------------------------------------
func _pts(list) -> PackedVector2Array:
	var out := PackedVector2Array()
	for q in list: out.append(d.anchor(q))
	return out

static func _len(p: PackedVector2Array) -> float:
	var l := 0.0
	for i in range(1, p.size()): l += p[i - 1].distance_to(p[i])
	return l

static func _at(p: PackedVector2Array, s: float) -> Vector2:
	if p.size() == 1: return p[0]
	for i in range(1, p.size()):
		var l := p[i - 1].distance_to(p[i])
		if s <= l or i == p.size() - 1:
			return p[i - 1].lerp(p[i], clampf(s / maxf(l, 0.0001), 0.0, 1.0))
		s -= l
	return p[p.size() - 1]

func _build() -> void:
	segs.clear()
	var f0 := 0.0
	var prev_end = null
	for sg in spec.get("segments", []):
		var run_p := _pts(sg.get("run", []))
		if prev_end != null and run_p.size() > 0 and run_p[0].distance_to(prev_end) > 0.05: run_p.insert(0, prev_end)
		if run_p.size() == 1: run_p.append(run_p[0])
		var fol := _pts(sg.get("follow", [])) if sg.has("follow") else run_p
		var fl := _len(fol)
		segs.append({ src = sg, run = run_p, rlen = maxf(_len(run_p), 0.01), follow = fol, flen = fl, f0 = f0, f1 = f0 + fl,
			mode = String(sg.get("mode", "lane")) })
		f0 += fl
		prev_end = run_p[run_p.size() - 1]
	follow_total = f0

# 이어 붙인 follow 길 위의 점(거리 s)
func follow_point(s: float) -> Vector2:
	s = clampf(s, 0.0, follow_total)
	for sg in segs:
		if s <= sg.f1 or sg == segs[segs.size() - 1]:
			return _at(sg.follow, s - sg.f0)
	return Vector2.ZERO

func _begin(from_cp: int) -> void:
	_build()
	a = d.actors.get(String(spec.actor), {})
	if a.is_empty():
		push_warning("추격: 인물 없음 " + String(spec.get("actor", "")))
		_finish.call_deferred("end"); return
	seg_i = clampi(from_cp, 0, segs.size() - 1) if from_cp >= 0 else 0
	seg_s = 0.0
	cur_y = NAN
	a.scripted = true
	a.path = []
	a.spec.erase("_hidden")
	a.shown = true
	a.ch.visible = true
	_set_ink(false)
	prog = segs[seg_i].f0 if from_cp >= 0 else 0.0
	if from_cp >= 0:
		# 다시 쫓기: 플레이어를 그 길목 조금 뒤에(암전 속에서 — 이야기 쪽이 가린다)
		var back := maxf(0.0, segs[seg_i].f0 - float(spec.get("retry_back", 10.0)))
		var p := follow_point(back)
		d.teleport_to(p)
		prog = back
		_place_runner()
		started = true
	else:
		_place_runner()
	if spec.has("camera"): d.camera(spec.camera)
	d.free_move = true
	d.runner.log_line("chase", [id, "start", seg_i])

func _place_runner() -> void:
	var sg: Dictionary = segs[seg_i]
	var p := _at(sg.run, seg_s)
	var g: float = d.world.height_at(p.x, p.y)
	a.pos = Vector3(p.x, g, p.y)
	match sg.mode:
		"climb":
			var y0: float = cur_y if not is_nan(cur_y) else g
			var top := _seg_top(sg)
			a.y_abs = lerpf(y0, top, clampf(seg_s / sg.rlen, 0.0, 1.0))
		"roof":
			if is_nan(cur_y): cur_y = _seg_top(sg)
			a.y_abs = cur_y
		"drop":
			var y0: float = cur_y if not is_nan(cur_y) else g
			var u := clampf(seg_s / sg.rlen, 0.0, 1.0)
			a.y_abs = lerpf(y0, g, u * u)
		_:
			a.y_abs = NAN

func _seg_top(sg: Dictionary) -> float:
	var p0: Vector2 = sg.run[0]
	return d.world.height_at(p0.x, p0.y) + float(sg.src.get("y", 4.0))

# ---------------------------------------------------------------------------
# 프레임
# ---------------------------------------------------------------------------
func _process(dt: float) -> void:
	if finished or a.is_empty() or d.main._loading: return
	t += dt
	var fps := Engine.get_frames_per_second()
	if t > 1.0:
		fps_min = minf(fps_min, fps); _fps_acc += fps; _fps_n += 1
	if d.test != null and d.test.has_method("chase_bot"): d.test.chase_bot(self, dt)
	_measure_player()
	_frame_camera()
	var sg: Dictionary = segs[seg_i]
	var rp: float = sg.f0 + seg_s / sg.rlen * (sg.f1 - sg.f0)
	lead = rp - prog
	if _end_t >= 0.0:
		_end_t -= dt
		if _end_t <= 0.0:
			d.show_actor(String(spec.actor), false)
			_finish("end")
		return
	# 놓침
	if started and (lead > float(spec.get("lose_lead", 45.0)) or off > float(spec.get("lose_off", 30.0))):
		lost_t += dt
		if lost_t > float(spec.get("lose_time", 6.0)):
			_lose(); return
	else:
		lost_t = maxf(0.0, lost_t - dt * 2.0)
	# 첫 구간: 다가올 때까지 서서 지켜본다
	if not started:
		_face_player()
		_play("idle")
		if lead <= float(spec.get("wake_lead", 16.0)) or t > float(spec.get("wake_time", 8.0)):
			started = true
			_enter(sg)
		return
	min_lead_seen = minf(min_lead_seen, lead)
	if lead < float(spec.get("lead", 12.0)): _wait_used = 0.0
	var spd := _speed(sg)
	if spd <= 0.01: _wait_used += dt
	max_speed_seen = maxf(max_speed_seen, spd)
	if spd <= 0.01:
		if not waiting:
			waiting = true
			d.runner.log_line("chase", [id, "wait", seg_i, snappedf(lead, 0.1)])
		_face_player()
		_play("crouch" if sg.mode == "roof" else String(spec.get("wait_anim", "idle")))
		return
	waiting = false
	seg_s += spd * dt
	while seg_s >= sg.rlen:
		seg_s -= sg.rlen
		if sg.mode == "climb": cur_y = _seg_top(sg)
		elif sg.mode == "roof": cur_y = a.y_abs if not is_nan(a.y_abs) else _seg_top(sg)
		else: cur_y = NAN
		if seg_i >= segs.size() - 1:
			seg_s = sg.rlen
			_place_runner()
			_arrive_end()
			return
		seg_i += 1
		sg = segs[seg_i]
		if sg.src.get("checkpoint", false): d.S.flags["_chase_%s_cp" % id] = seg_i
		_enter(sg)
	_place_runner()
	var dir := _at(sg.run, minf(seg_s + 0.5, sg.rlen)) - _at(sg.run, maxf(seg_s - 0.5, 0.0))
	if dir.length() > 0.05: a.facing = _facing(dir)
	_play(String(sg.src.get("anim", "climb" if sg.mode == "climb" else "run")))

func _speed(sg: Dictionary) -> float:
	var base: float = float(spec.get("speed", 4.4)) * float(sg.src.get("speed", 1.0))
	if sg.mode == "climb": return base   # 오르기는 제 속도(빨라지지 않는다)
	var want := float(spec.get("lead", 12.0))
	if lead < float(spec.get("min_lead", 5.0)): return float(spec.get("burst", 6.2)) * float(sg.src.get("speed", 1.0))
	if lead > float(spec.get("wait_lead", 26.0)):
		if _wait_used < float(spec.get("wait_max", 4.0)): return 0.0
		return base * 0.85   # 기다려도 안 오면 제 갈 길을 간다
	# 고무줄: 바라는 앞섬보다 가까우면 빨리, 멀면 천천히
	return clampf(base + (want - lead) * 0.25, base * 0.45, float(spec.get("burst", 6.2)))

func _enter(sg: Dictionary) -> void:
	d.runner.log_line("chase", [id, "seg", seg_i, sg.mode])
	_set_ink(bool(sg.src.get("ink", sg.mode == "roof")))
	if sg.src.has("caption"): d.ui.caption(String(sg.src.caption), float(sg.src.get("sec", 2.0)))
	if sg.src.has("toast"): d.ui.toast(String(sg.src.toast), "info")
	if sg.src.has("call") and d.case_fn != null and d.case_fn.has_method(String(sg.src.call)): d.case_fn.call(String(sg.src.call))

func _arrive_end() -> void:
	_set_ink(bool(spec.get("end_ink", false)))
	_play(String(spec.get("end_anim", "idle")))
	_face_player()
	if spec.has("end_caption"): d.ui.caption(String(spec.end_caption), 2.4)
	_end_t = float(spec.get("vanish_delay", 1.2))
	d.runner.log_line("chase", [id, "end"])

func _lose() -> void:
	var cp := 0
	for i in range(seg_i, -1, -1):
		if segs[i].src.get("checkpoint", false) or i == 0: cp = i; break
	d.S.flags["_chase_%s_cp" % id] = cp
	d.show_actor(String(spec.actor), false)
	d.runner.log_line("chase", [id, "lost", seg_i, snappedf(lead, 0.1), snappedf(off, 0.1)])
	_finish("lost")

func _finish(res: String) -> void:
	if finished: return
	finished = true
	_set_ink(false)
	d.free_move = false
	if spec.has("camera"): d.camera(null)
	if _fps_n > 0: d.runner.log_line("chase", [id, "fps", snappedf(_fps_acc / _fps_n, 0.1), snappedf(fps_min, 0.1)])
	d.runner.log_line("chase", [id, "result", res, "min_lead", snappedf(min_lead_seen, 0.1), "max_speed", snappedf(max_speed_seen, 0.01)])
	done.emit(res)

# 카메라: 플레이어와 달아나는 인물 사이(플레이어 쪽으로 기울여)를 비춘다 — 고정 시점이라 남쪽으로 달아나면 화면 밖으로 나가므로
func _frame_camera() -> void:
	if not spec.has("camera") or not a.shown: return
	var pp: Vector3 = d.main.player_pos
	var v := Vector2(a.pos.x - pp.x, a.pos.z - pp.z)
	v = v.limit_length(float(spec.get("frame_reach", 16.0))) * float(spec.get("frame_mix", 0.5))
	d.main.rig.focus = { x = pp.x + v.x, z = pp.z + v.y, y = pp.y }

# 플레이어를 follow 길에 비춘다(앞뒤로 좁은 창 안에서 — 길이 다시 지나가는 곳에서 건너뛰지 않게)
func _measure_player() -> void:
	var pp := Vector2(d.main.player_pos.x, d.main.player_pos.z)
	var lo := prog - 25.0
	var hi := prog + 60.0
	var best := INF
	var best_s := prog
	for sg in segs:
		if sg.f1 < lo or sg.f0 > hi: continue
		var f: PackedVector2Array = sg.follow
		var acc: float = sg.f0
		for i in range(1, f.size()):
			var q := Geometry2D.get_closest_point_to_segment(pp, f[i - 1], f[i])
			var dd := pp.distance_to(q)
			var s: float = acc + f[i - 1].distance_to(q)
			if s >= lo and s <= hi and dd < best:
				best = dd; best_s = s
			acc += f[i - 1].distance_to(f[i])
	off = best
	prog = best_s

func _face_player() -> void:
	var v := Vector2(d.main.player_pos.x - a.pos.x, d.main.player_pos.z - a.pos.z)
	if v.length() > 0.1: a.facing = _facing(v)

static func _facing(v: Vector2) -> String:
	return "right" if absf(v.x) > absf(v.y) * 1.05 and v.x > 0 else ("left" if absf(v.x) > absf(v.y) * 1.05 else ("down" if v.y > 0 else "up"))

func _play(nm: String) -> void:
	if nm == _anim: return
	_anim = nm
	a.anim = nm
	a.ch.play(nm, true)

# 지붕 위 먹 실루엣: 그림 위에 먹빛을 덮는다(SpriteChar 피격 번쩍임 칸을 그대로 씀)
func _set_ink(on: bool) -> void:
	if on == _ink or a.is_empty(): return
	_ink = on
	var m = a.ch.get("_mat")
	if m != null: m.set_shader_parameter("flash", Color(0.07, 0.07, 0.09, 0.82) if on else Color(1, 1, 1, 0))

# ---------------------------------------------------------------------------
# 순찰: actors 항목 "patrol": [자리…] 를 오가며 걷는다(스크립트가 쥔 동안은 쉰다)
# ---------------------------------------------------------------------------
static func patrol(dir, _dt: float) -> void:
	for aid in dir.actors:
		var ac: Dictionary = dir.actors[aid]
		var pts = ac.spec.get("patrol")
		if pts == null or not ac.shown or ac.get("patrol_hold", false): continue
		if not ac.path.is_empty(): continue
		var i: int = (int(ac.get("patrol_i", 0)) + 1) % int(pts.size())
		ac.patrol_i = i
		ac.path = [dir.anchor(pts[i])]
		ac.speed = float(ac.spec.get("patrol_speed", 1.3))
		ac.end_anim = "walk"
		if ac.anim != "walk":
			ac.anim = "walk"; ac.ch.play("walk")
