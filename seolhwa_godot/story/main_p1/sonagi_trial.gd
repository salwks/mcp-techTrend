# 여는 사건 A 「소나기」 회색 상자 시험 — 브랜치 claude/opening-a-sonagi-trial 전용. 메인 게임에 합치지 않는다.
#   켜기: godot --path . -- --opening=sonagi        (빗소리로 시작 — E1 두드림 없음)
#         godot --path . -- --opening=sonagi_knock  (E1을 지킨 판 — 검은 화면에서 빗소리 위로 느린 두 번 두드림)
#   인자가 없으면 출시판(지금 판 + E1~E7) 그대로다. --opening=…은 save_guard의 놀이 인자가 아니어서 저장은 모래상자(설화록_test)로 간다.
#   자동 놀이(시험·캡처): --sonagibot=name|other — 사람과 같은 걸음(걷기 2.2m/s, 반응 0.5초)으로 줍는다.
#
# 흐름(main_p1_case.prologue가 INTRO_01 자리에서 부른다 — 끝나면 INTRO_02~04 · E3~E7 · ㉤ 전환은 출시판 그대로):
#   0.0–0.8 검은 화면 · 후드득(임시 rain_patter) → 0.8 마당이 열림(15시 · 비가 들이침) → 1.2 돌풍, 기록지 ①이 평상 쪽으로 날아감
#   2.5 조작(첫 조작) — '기록지를 줍자 — WASD 이동 · E 줍기' · ① 줍기(E) → ② 장작더미 쪽 → ② 줍기(E)   ← 이동·E를 익히는 심부름 둘
#   센 돌풍: ③ 이름 적힌 기록지(먹 동그라미)는 서쪽 빗물 도랑 쪽, ④ 날씨 기록은 동남쪽 웅덩이 쪽 · 이겸 '이름 적힌 것부터!'
#     먼저 주운 쪽이 건져지고 다른 쪽은 물에 잠겨 먹이 번진다(숫자 타이머 없음 · 둘 다 잃는 일은 없다 — 물가에 걸려 기다린다)
#   처마 밑에 두기(E) → 소나기가 그친다 → 0.3초 dip → 멍석에 다시 펴 말리는 기록지 · 이겸 반응(이름: 말없이 끄덕 / 날씨: '이름이 번졌구나.' 뒤 끄덕)
#   → INTRO_02(이겸이 들어 올린 종이 = 이번 갈래의 종이) … INTRO_04 기록책 왼쪽 쪽에 건진 종이를 끼워 둠 → 지금 마당: 번진 종이가 멍석에(E5)
# 갈래는 저장한다: S.flags.SONAGI_SAVED = "name" | "other" (+ 기록책 첫 줄 summary). 필수 정보·진행 조건은 바꾸지 않는다.
# 임시(회색 상자): 날리는 종이(키운 평면 + 그린 먹줄) · 빗물 도랑·웅덩이(물빛 평면) · 줍기 표시 고리 · 소리 rain_patter·rain_shower(tools/audio/make_sonagi_placeholders.py)
extends RefCounted

const Sound := preload("res://scripts/audio/sound.gd")

const PICK_R := 1.9          # 줍기 반지름(넉넉하게)
const EAVES_R := 1.9
const PAPER_W := 0.5         # 임시 — 실물(약 0.3m)보다 키움(인물 그림이 약 2m라 화면에서 읽히게)
const PAPER_H := 0.66
const WATER := Color(0.47, 0.52, 0.55, 0.8)   # 임시 물빛(흙탕 빗물 — 반쯤 비침)

var c                        # main_p1_case
var d
var variant := "sonagi"      # sonagi | sonagi_knock
var bot := ""                # "" | name | other
var saved := ""              # name | other — 이번에 건진 쪽
var t := {}                  # 시각 기록(프롤로그 시작부터 초)
var papers := {}             # key → { n: Node3D, mat, state, a, b, t0, dur, h, drift, hop_t, kind }
var held: Array = []
var _rain: AudioStreamPlayer = null
var _nodes: Array = []
var _p0 := 0.0
var _eaves_mark: MeshInstance3D = null
var _ink_cloud: MeshInstance3D = null
var _bot_e := false
var _hint_mine := ""         # 소나기 동안 안내 줄(처음 하는 안내 MOVE 등이 같은 자리를 덮지 않게 매 프레임 지킨다 — 그동안 hush_hints)
var skipped := false

func _init(case_fn, v: String) -> void:
	c = case_fn; d = case_fn.d; variant = v
	bot = String(d.main.args.get("sonagibot", "")) if d.main.get("args") != null else ""

static func L(x: float, z: float) -> Vector2:
	var D = load("res://story/main_p1/main_p1_data.gd")
	return Vector2(D.HX + x, D.HZ + z)

# 자리(거처 기준 — main_p1_data anchors와 같은 꼴)
var P_START := L(1.6, 6.7)       # 제자: 평상 남서쪽 곁에 서 있다
var P1_LAND := L(-0.6, 4.3)      # ① 평상과 집 앞 사이
var P2_LAND := L(4.3, 2.7)       # ② 장작더미 앞
var P3_LAND := L(-5.2, 8.3)      # ③ 이름 적힌 것 — 서쪽 빗물 도랑 쪽
var P3_SINK := L(-6.2, 8.6)
var P4_LAND := L(4.0, 8.9)       # ④ 날씨 기록 — 동남쪽 웅덩이 쪽
var P4_SINK := L(4.6, 9.5)
var EAVES := L(-0.6, 3.9)        # 처마 밑(문 앞 왼쪽)
var IG_EAVES := L(0.9, 3.7)
var DITCH := [L(-6.35, 4.2), L(-6.35, 9.0), L(-10.0, 8.8)]
var PUDDLE := L(4.7, 9.6)

func _now() -> float: return Time.get_ticks_msec() / 1000.0
func _mark(k: String) -> void:
	t[k] = snappedf(_now() - _p0, 0.01)
	printerr("FIRST15 sonagi %s t=%.2f" % [k, t[k]])

func _y(p: Vector2) -> float: return d.world.height_at(p.x, p.y)

# ---------------------------------------------------------------- 소품(임시)
func _paper_tex(kind: String, ruined := false) -> ImageTexture:
	var W := 96; var H := 128
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	img.fill(Color("#efe5c8") if not ruined else Color("#d9d2bf"))
	var rng := RandomNumberGenerator.new(); rng.seed = 5130 + kind.length()
	var ink := Color("#1d1a17")
	for col in 5:   # 세로쓰기 먹줄 다섯
		var x := W - 14 - col * 16
		var y := 12
		while y < H - 14:
			var l := rng.randi_range(5, 12)
			for yy in range(y, mini(y + l, H - 12)):
				for xx in range(x - 1, x + 1): img.set_pixel(xx, yy, ink)
			y += l + rng.randi_range(3, 6)
	if kind == "name":   # 먹으로 둥글게 표시한 쪽(멀리서도 보이는 큰 동그라미)
		var cx := W - 30; var cy := 44; var r := 26
		for a in 360:
			for th in 4:
				var rr := r - th
				img.set_pixel(clampi(int(cx + rr * cos(deg_to_rad(a))), 0, W - 1), clampi(int(cy + rr * sin(deg_to_rad(a))), 0, H - 1), Color("#a3221a"))
	if ruined:   # 물에 잠겨 먹이 번짐(회색 얼룩이 줄을 덮음)
		for k in 26:
			var cx2 := rng.randi_range(6, W - 6); var cy2 := rng.randi_range(6, H - 6); var r2 := rng.randi_range(6, 16)
			for yy in range(cy2 - r2, cy2 + r2):
				for xx in range(cx2 - r2, cx2 + r2):
					if xx < 0 or yy < 0 or xx >= W or yy >= H: continue
					if Vector2(xx - cx2, yy - cy2).length() > r2: continue
					var o := img.get_pixel(xx, yy)
					img.set_pixel(xx, yy, o.lerp(Color("#6f6c70"), 0.35))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

func _paper_node(kind: String, ruined := false, scale := 1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); mi.name = "sonagi_paper_" + kind
	var pm := PlaneMesh.new(); pm.size = Vector2(PAPER_W, PAPER_H) * scale; mi.mesh = pm
	var m := StandardMaterial3D.new()
	m.albedo_texture = _paper_tex(kind, ruined)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 0.9
	m.emission_enabled = true; m.emission = Color("#efe5c8") * (0.0 if ruined else 0.28)   # 비 오는 어둑한 마당에서 종이가 읽히게(임시)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mi.material_override = m
	d._props_root.add_child(mi)
	_nodes.append(mi)
	return mi

func _flat(mesh: Mesh, col: Color, unshaded := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); mi.mesh = mesh
	var m := StandardMaterial3D.new(); m.albedo_color = col
	if col.a < 1.0: m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if unshaded: m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	d._props_root.add_child(mi)
	_nodes.append(mi)
	return mi

func _ring(r: float, col: Color) -> MeshInstance3D:
	var tm := TorusMesh.new(); tm.inner_radius = r - 0.07; tm.outer_radius = r; tm.rings = 32; tm.ring_segments = 6
	return _flat(tm, col)

# 빗물 도랑(서쪽 — 오솔길을 따라 주촌천으로) · 웅덩이(동남쪽) — 임시 물빛 평면
func _water_bits() -> void:
	for i in DITCH.size() - 1:
		var a: Vector2 = DITCH[i]; var b: Vector2 = DITCH[i + 1]
		var bm := BoxMesh.new(); bm.size = Vector3(0.55, 0.02, a.distance_to(b) + 0.4)
		var mi := _flat(bm, WATER, false)
		(mi.material_override as StandardMaterial3D).roughness = 0.12
		var m := (a + b) * 0.5
		mi.global_position = Vector3(m.x, _y(m) + 0.025, m.y)
		mi.rotation.y = atan2(b.x - a.x, b.y - a.y)
		c._pro_nodes["s_ditch%d" % i] = mi
	var cm := CylinderMesh.new(); cm.top_radius = 0.95; cm.bottom_radius = 0.95; cm.height = 0.02; cm.radial_segments = 20
	var pu := _flat(cm, WATER, false)
	(pu.material_override as StandardMaterial3D).roughness = 0.1
	pu.global_position = Vector3(PUDDLE.x, _y(PUDDLE) + 0.02, PUDDLE.y)
	pu.scale = Vector3(1.0, 1.0, 0.7)
	c._pro_nodes["s_puddle"] = pu

# ---------------------------------------------------------------- 비
func _rain_on(fade: float) -> void:
	var st: AudioStream = Sound.stream("rain_shower")
	if st == null: return
	if st is AudioStreamWAV:
		(st as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
		(st as AudioStreamWAV).loop_end = (st as AudioStreamWAV).data.size() / 2
	_rain = AudioStreamPlayer.new(); _rain.stream = st; _rain.bus = "Ambient"; _rain.volume_db = -18.0
	d.add_child(_rain)
	_rain.play()
	_rain.create_tween().tween_property(_rain, "volume_db", -2.0, fade)
	printerr("FIRST15 sfx rain_shower t=%.2f" % (_now() - _p0))

func _rain_off(sec: float) -> void:
	var w = d.main.weather
	if w != null: w.force("clear", -1.0, sec)
	if _rain != null and is_instance_valid(_rain):
		var r := _rain
		var tw := r.create_tween(); tw.tween_property(r, "volume_db", -60.0, maxf(sec * 0.4, 0.05))
		tw.tween_callback(r.queue_free)
	_rain = null

# 건너뛰기·끝: 남은 것 치우기(소품 노드는 c._pro_nodes에 넣어 _present_swap이 지운다)
func cleanup() -> void:
	if _rain != null and is_instance_valid(_rain): _rain.queue_free()
	_rain = null
	d.free_move = false
	d.set("story_prompt", "")
	_hint_mine = ""
	d.hush_hints = false
	d.ui.hint_clear()
	for a in ["move_right", "move_left", "move_down", "move_up", "run", "interact"]: Input.action_release(a)

# ---------------------------------------------------------------- 종이 움직임
func _paper(key: String, kind: String, at: Vector2) -> Dictionary:
	var n := _paper_node(kind)
	n.global_position = Vector3(at.x, _y(at) + 0.07, at.y)
	n.rotation = Vector3(0, randf_range(-0.4, 0.4), 0)
	var p := { n = n, state = "rest", kind = kind, a = Vector3.ZERO, b = Vector3.ZERO, t0 = 0.0, dur = 1.0, h = 1.6, drift = null, hop_t = 1.4, hop0 = Vector3.ZERO, hop1 = Vector3.ZERO, hop_s = -1.0 }
	papers[key] = p
	c._pro_nodes["s_" + key] = n
	return p

func _fly(key: String, to: Vector2, dur: float, h: float, drift = null) -> void:
	var p: Dictionary = papers[key]
	p.state = "fly"; p.a = (p.n as Node3D).global_position; p.b = Vector3(to.x, _y(to) + 0.05, to.y)
	p.t0 = _now(); p.dur = dur; p.h = h; p.drift = drift; p.hop_t = 1.1
	d.sfx("page_turn")

func _update_papers(dt: float) -> void:
	var now := _now()
	for key in papers:
		var p: Dictionary = papers[key]
		var n: Node3D = p.n
		if not is_instance_valid(n): continue
		match String(p.state):
			"fly":
				var s := clampf((now - float(p.t0)) / float(p.dur), 0.0, 1.0)
				var e := 1.0 - pow(1.0 - s, 2.0)
				var pos: Vector3 = (p.a as Vector3).lerp(p.b, e)
				pos.y += float(p.h) * 4.0 * s * (1.0 - s)
				n.global_position = pos
				n.rotation = Vector3(sin(now * 9.0 + key.length()) * 0.9 * (1.0 - s), n.rotation.y + dt * 5.0 * (1.0 - s), cos(now * 7.0) * 0.6 * (1.0 - s))
				if s >= 1.0: p.state = "ground"
			"ground":
				n.rotation.x = sin(now * 6.0 + key.length()) * 0.12   # 바람에 파르르
				n.rotation.z = cos(now * 5.0) * 0.08
				if float(p.hop_s) >= 0.0:   # 바람에 다시 들림(정해 둔 쪽으로 반 걸음)
					p.hop_s = float(p.hop_s) + dt / 0.55
					var hs := minf(float(p.hop_s), 1.0)
					var hp: Vector3 = (p.hop0 as Vector3).lerp(p.hop1, hs); hp.y += 0.35 * 4.0 * hs * (1.0 - hs)
					n.global_position = hp
					if hs >= 1.0: p.hop_s = -1.0
				else:
					p.hop_t = float(p.hop_t) - dt
					if float(p.hop_t) <= 0.0:
						p.hop_t = randf_range(1.0, 1.6)
						var cur := Vector2(n.global_position.x, n.global_position.z)
						var tgt: Vector2 = p.drift if p.drift != null else cur + Vector2(randf_range(-0.25, 0.25), randf_range(-0.25, 0.25))
						var v := tgt - cur
						var stepv := v.limit_length(0.5)
						if v.length() > 0.08:
							var to := cur + stepv
							p.hop0 = n.global_position; p.hop1 = Vector3(to.x, _y(to) + 0.05, to.y); p.hop_s = 0.0
			"held":
				var i := held.find(key)
				var pp: Vector3 = d.main.player_pos
				n.global_position = Vector3(pp.x + 0.18, pp.y + 1.0 + i * 0.03, pp.z + 0.45)
				n.rotation = Vector3(deg_to_rad(70.0), 0.1 * i, 0.0)
			"sink":
				var s2 := clampf((now - float(p.t0)) / 0.9, 0.0, 1.0)
				n.global_position = (p.a as Vector3).lerp(p.b, s2)
				n.rotation.x = 0.0; n.rotation.z = 0.0
				if s2 >= 1.0: p.state = "lost"
	if _ink_cloud != null and is_instance_valid(_ink_cloud) and _ink_cloud.scale.x < 1.0:
		_ink_cloud.scale = Vector3.ONE * minf(1.0, _ink_cloud.scale.x + dt * 0.6)

func _sink(key: String, to: Vector2) -> void:
	var p: Dictionary = papers[key]
	var n: MeshInstance3D = p.n
	p.state = "sink"; p.t0 = _now(); p.a = n.global_position; p.b = Vector3(to.x, _y(to) + 0.035, to.y)
	(n.material_override as StandardMaterial3D).albedo_texture = _paper_tex(String(p.kind), true)
	(n.material_override as StandardMaterial3D).emission = Color.BLACK
	var cm := CylinderMesh.new(); cm.top_radius = 0.55; cm.bottom_radius = 0.55; cm.height = 0.004; cm.radial_segments = 18
	_ink_cloud = _flat(cm, Color(0.08, 0.07, 0.07, 0.45))
	_ink_cloud.global_position = Vector3(to.x, _y(to) + 0.04, to.y)
	_ink_cloud.scale = Vector3.ONE * 0.25
	c._pro_nodes["s_ink"] = _ink_cloud
	d.sfx("flour_rustle")

func _pickable(key: String) -> bool:
	var p: Dictionary = papers.get(key, {})
	return not p.is_empty() and String(p.state) in ["ground", "fly"] and (String(p.state) == "ground" or _now() - float(p.t0) > float(p.dur) * 0.7)

func _dist_to(key: String) -> float:
	var n: Node3D = papers[key].n
	return Vector2(n.global_position.x - d.main.player_pos.x, n.global_position.z - d.main.player_pos.z).length()

func _pick(key: String) -> void:
	papers[key].state = "held"
	held.append(key)
	d.sfx("page_turn")
	_mark("pick_" + key)

# ---------------------------------------------------------------- 자동 놀이(시험·캡처)
var _bot_goal = null
var _bot_wait := 0.0
var _bot_still := 0.0
var _bot_last := Vector2.INF
func _bot_go(goal, react := 0.5) -> void:
	if bot == "": return
	_bot_goal = goal; _bot_wait = react
func _bot_tick(dt: float) -> void:
	if bot == "": return
	for a in ["move_right", "move_left", "move_down", "move_up"]: Input.action_release(a)
	if _bot_goal == null: return
	if _bot_wait > 0.0: _bot_wait -= dt; return
	var g: Vector2 = _bot_goal.call() if _bot_goal is Callable else _bot_goal
	var p := Vector2(d.main.player_pos.x, d.main.player_pos.z)
	var v := g - p
	if v.length() < 1.0:
		_bot_e = true; _bot_goal = null; return
	var nv := v.normalized()
	if _bot_last != Vector2.INF and p.distance_to(_bot_last) < 0.004: _bot_still += dt
	else: _bot_still = 0.0
	_bot_last = p
	if _bot_still > 0.6: nv = nv.rotated(0.9)   # 무엇에 걸렸으면 옆으로 비켜 걷는다
	Input.action_press("move_right", maxf(0.0, nv.x)); Input.action_press("move_left", maxf(0.0, -nv.x))
	Input.action_press("move_down", maxf(0.0, nv.y)); Input.action_press("move_up", maxf(0.0, -nv.y))
	for a in ["move_right", "move_left", "move_down", "move_up"]:
		if Input.get_action_strength(a) <= 0.001: Input.action_release(a)

func _e_pressed() -> bool:
	if _bot_e: _bot_e = false; return true
	return Input.is_action_just_pressed("interact")

func _skip_now() -> bool:
	var ob = d.onboard
	if ob == null: return false
	if ob.skip and c._now() < c._skip_ok_at: ob.skip = false
	return ob.skip

# 한 프레임 기다림(건너뛰면 true)
func _frame() -> bool:
	await d.get_tree().process_frame
	var dt: float = d.get_process_delta_time()
	if dt > 0.12: printerr("FIRST15 sonagi hitch dt=%.2f t=%.2f" % [dt, _now() - _p0])   # 끊김 기록(첫 조작 시각을 미는 것)
	_update_papers(dt)
	_bot_tick(dt)
	if _hint_mine != "" and d.ui.hint_text() != _hint_mine: d.ui.hint(_hint_mine)
	return _skip_now()

# 프롤로그 시작(p0)부터 t초가 될 때까지(끊김이 있어도 차례가 밀려 쌓이지 않게)
func _until(at: float) -> bool:
	while _now() - _p0 < at:
		if await _frame(): return true
	return false

func _wait(sec: float) -> bool:
	var t0 := _now()
	while _now() - t0 < sec:
		if await _frame(): return true
	return false

# ---------------------------------------------------------------- 놀이
# 돌려줌: 건너뛰었으면 true. 끝나면 마당은 비 그친 지난 오후 · 이겸 pro_ig_stand에서 종이를 든 채 · 제자는 평상(pro_disc)에 앉아 있다(INTRO_02 L1 바로 앞)
func run(p0: float) -> bool:
	_p0 = p0
	var ob = d.onboard
	t = {}
	printerr("FIRST15 sonagi variant=%s bot=%s" % [variant, bot])
	# ---- 0.0–0.8 검은 화면 · 소리 ----
	d._cut = true   # 띠 없이 이동만 막는다(조작이 2.5초에 바로 오게 — 띠가 드나들지 않게)
	c._past_setup()   # 출시판과 같은 지난날 상태(15시 · 이겸 · 멍석 기록지 소품 · 색감) — 그 위에 제자를 세운다
	d.teleport_to(P_START, "left")
	d.main.player.play("idle", true)
	_water_bits()
	var mat: Vector2 = d.anchor("pro_mat")
	_paper("p1", "plain", mat + Vector2(0.55, -0.2))
	_paper("p2", "plain", mat + Vector2(-0.3, 0.25))
	_paper("p3", "name", mat + Vector2(-0.6, -0.25))
	_paper("p4", "weather", mat + Vector2(0.2, 0.3))
	d.camera({ "focus": L(-0.4, 6.2), "distance": 14.5, "pitch": 44.0, "fov": 40.0 })   # 마당 전체(도랑·웅덩이·처마까지 한 화면 — 종이가 어디로 갔는지 읽히게)
	d.main.rig.update(0, d.main.player_pos, d.main.player.facing, null, true)
	c._log("prologue_start")
	c._beat("SONAGI_open", p0)
	var w0 = d.main.weather
	if w0 != null: w0.force("storm", -1.0, 0.9, { "fogm": 1.5, "wind": 0.85 })   # 비는 검은 화면 안에서 먼저 — 첫 그림에 이미 내리고(입자 첫 그리기 끊김도 검은 화면 안에서)
	if variant == "sonagi_knock":
		# E1을 지킨 판: 검은 화면에 출시판 E1과 같은 느린 두 번(0.0 · 약 0.53) — 빗소리(쏴)가 그 밑에 깔리고, 후드득은 두드림 뒤에
		c._knock_slow()
		if await _until(0.3): return true
		_rain_on(0.9)
		if await _until(0.7): return true
		c._tsfx("rain_patter", -1.0)
	else:
		c._tsfx("rain_patter", -1.0)             # 후드득 — 종이에 떨어지는 굵은 빗방울(임시). E1(두드림) 자리
		if await _until(0.45): return true
		_rain_on(0.9)                            # 쏴 — 빗소리 고리(임시 rain_shower)
	if await _until(0.75): return true
	# ---- 0.75 마당이 열림 ----
	d.ui.fade(false, 0.6)
	c._tsfx("wind", 2.0, 1.25)
	if await _until(1.05): return true
	# ---- 1.1 돌풍: ① 평상 쪽으로 ----
	_mark("gust1")
	d.face_actor("yigyeom_past", "up", null)   # 하늘을 본다
	_fly("p1", P1_LAND, 1.0, 1.8)
	if await _until(2.32): return true   # 새 게임 → 프롤로그 시작이 약 0.03초 + 첫 프레임 — 새 게임부터 약 2.45초
	# ---- 2.5 조작 ----
	d._cut = false
	d.free_move = true
	_mark("control")
	c._beat("control_play", p0)
	d.hush_hints = true   # 저장에 남은 처음 안내(MOVE 등)가 이 줄을 덮지 않게 — 방 안 조작에서 다시 뜬다
	_hint_mine = "기록지를 줍자  —  W A S D 이동 · E 줍기"
	d.ui.hint(_hint_mine)
	d.anim_actor("yigyeom_past", "kneel")
	d.face_actor("yigyeom_past", "left", null)
	_bot_go(func(): return Vector2(papers.p1.n.global_position.x, papers.p1.n.global_position.z), 0.5)
	var said_hurry := false
	var t_ctl := _now()
	var stage := 1     # 1 ①을 줍는다 · 2 ② · 3 고르기 · 4 처마 · 5 끝
	var choice_at := 0.0
	while stage < 5:
		if await _frame(): return true
		if not said_hurry and _now() - t_ctl > 0.5:
			said_hurry = true
			c._say_cap("이겸", "어서!")
		var prompt := ""
		match stage:
			1, 2:
				var key := "p%d" % stage
				if _pickable(key) and _dist_to(key) <= PICK_R:
					prompt = "기록지 줍기"
					if _e_pressed():
						_pick(key)
						if stage == 1:
							_mark("first_e")
							stage = 2
							if await _wait(0.35): return true
							_mark("gust2")
							c._tsfx("wind", 1.0, 1.3)
							_fly("p2", P2_LAND, 1.2, 2.0)
							_bot_go(func(): return Vector2(papers.p2.n.global_position.x, papers.p2.n.global_position.z), 0.5)
						else:
							stage = 3
							if await _wait(0.45): return true
							_split()
							choice_at = _now()
							if bot == "name": _bot_go(func(): return Vector2(papers.p3.n.global_position.x, papers.p3.n.global_position.z), 0.6)
							elif bot == "other": _bot_go(func(): return Vector2(papers.p4.n.global_position.x, papers.p4.n.global_position.z), 0.6)
			3:
				if not t.has("ig_line") and _now() - choice_at > 0.45:
					_mark("ig_line")
					d.anim_actor("yigyeom_past", "read")   # 젖은 종이 한 장을 들어 보인다
					d.face_actor("yigyeom_past", "left", null)
					c._say_cap("이겸", "이름 적힌 것부터!")
				for key in ["p3", "p4"]:
					if _pickable(key) and _dist_to(key) <= PICK_R:
						prompt = "기록지 줍기"
						if _e_pressed():
							_pick(key)
							saved = "name" if key == "p3" else "other"
							_sink("p4" if key == "p3" else "p3", P4_SINK + (PUDDLE - P4_SINK) * 0.6 if key == "p3" else DITCH[1].lerp(DITCH[0], 0.12))
							_mark("branch")
							c._beat("branch_" + saved, p0)
							c.flag("SONAGI_SAVED", saved)
							c.flag("SONAGI_LINE", line_for(saved))
							d.save()   # 갈래를 바로 저장(프롤로그 도중 끝내도 남게)
							stage = 4
							_hint_mine = "처마 밑에 두자  —  E"
							d.ui.hint(_hint_mine)
							_eaves_mark = _ring(0.75, Color(1.0, 0.95, 0.75, 0.5))
							_eaves_mark.global_position = Vector3(EAVES.x, _y(EAVES) + 0.05, EAVES.y)
							c._pro_nodes["s_eaves"] = _eaves_mark
							d.move_actor("yigyeom_past", [IG_EAVES], 1.6, "walk", "idle")   # 남은 기록지를 끌어안고 처마로
							_bot_go(EAVES, 0.4)
							break
			4:
				if Vector2(d.main.player_pos.x, d.main.player_pos.z).distance_to(EAVES) <= EAVES_R:
					prompt = "처마 밑에 두기"
					if _e_pressed():
						_deliver()
						stage = 5
		_show_marker(stage)
		d.set("story_prompt", prompt)
	d.set("story_prompt", "")
	_hint_mine = ""
	d.hush_hints = false
	d.ui.hint_clear()
	d.free_move = false
	for a in ["move_right", "move_left", "move_down", "move_up"]: Input.action_release(a)
	# ---- 소나기가 그친다 ----
	d.cutscene(true)
	d.main.player.play("idle", true)
	if await _wait(0.5): return true
	_mark("rain_end")
	c._beat("rain_end", p0)
	_rain_off(1.4)
	d.face_actor("yigyeom_past", "right", null)
	d.anim_actor("yigyeom_past", "read")   # 종이를 센다
	d.sfx("page_turn")
	if await _wait(0.7): return true
	d.sfx("page_turn")
	if await _wait(0.8): return true
	# ---- dip: 멍석에 다시 펴 말림 · 이겸 반응 ----
	await d.ui.fade(true, 0.15)
	_calm_setup()
	d.ui.fade(false, 0.2)
	c._beat("reaction", p0)
	_mark("reaction")
	if await _wait(0.9): return true
	if saved == "other":
		var sec: float = c._say_cap("이겸", "이름이 번졌구나.")   # 번진 종이를 보며(제자가 아니라 종이에게 하는 말)
		if await _wait(sec + 0.25): return true
	d.face_actor("yigyeom_past", "right", null)
	d.anim_actor("yigyeom_past", "bow")   # 제자 쪽으로 고개를 끄덕인다(두 갈래 같은 몸짓 — 제자가 한 일을 받는다)
	if await _wait(0.9): return true
	d.anim_actor("yigyeom_past", "read")   # 다시 종이를 든다(INTRO_02 '기록을 들어 올린다')
	if await _wait(0.3): return true
	return false

# 갈래 문구(설화록 첫 줄 — 기록책 사건 쪽 맨 위). 건진 것을 먼저 적는다(맞고 틀림이 아니다)
static func line_for(k: String) -> String:
	if k == "name": return "그날 소나기에 이름 적힌 기록을 건졌다. 날씨 기록 한 장은 웅덩이에 번졌다."
	if k == "other": return "그날 소나기에 날씨 기록을 건졌다. 이름 적힌 한 장은 도랑에 번졌다."
	return ""

func _split() -> void:
	_mark("split")
	c._beat("split", _p0)
	c._tsfx("wind", 4.0, 1.1)
	var w = d.main.weather
	if w != null: w.force("storm", -1.0, 0.5, { "fogm": 1.6, "wind": 1.0 })
	_fly("p3", P3_LAND, 1.5, 2.6, P3_SINK)
	_fly("p4", P4_LAND, 1.3, 2.2, P4_SINK)

func _deliver() -> void:
	_mark("deliver")
	var i := 0
	for key in held:
		var n: Node3D = papers[key].n
		papers[key].state = "placed"
		n.global_position = Vector3(EAVES.x - 0.3 + i * 0.05, _y(EAVES) + 0.06 + i * 0.01, EAVES.y - 0.35)
		n.rotation = Vector3(0, 0.15 * i, 0)
		i += 1
	held = []
	d.sfx("page_turn")
	if _eaves_mark != null and is_instance_valid(_eaves_mark): _eaves_mark.visible = false

var _marks := {}
func _show_marker(stage: int) -> void:
	var want := []
	if stage == 1: want = ["p1"]
	elif stage == 2: want = ["p2"]
	elif stage == 3: want = ["p3", "p4"]   # 고르기: 두 장 다 표시(어느 쪽도 정답 표시가 아니다 — 같은 고리)
	for key in ["p1", "p2", "p3", "p4"]:
		if not _marks.has(key):
			_marks[key] = _ring(0.62, Color(1.0, 0.96, 0.78, 0.55))
			c._pro_nodes["s_mark_" + key] = _marks[key]
		var mk: MeshInstance3D = _marks[key]
		var on: bool = key in want and papers.has(key) and String(papers[key].state) in ["ground", "fly"] and _pickable(key)
		mk.visible = on
		if not on: continue
		var n: Node3D = papers[key].n
		mk.global_position = Vector3(n.global_position.x, _y(Vector2(n.global_position.x, n.global_position.z)) + 0.04, n.global_position.z)
		(mk.material_override as StandardMaterial3D).albedo_color.a = 0.35 + 0.25 * sin(_now() * 5.0)

# 비 그친 뒤(검은 dip 안): 멍석에 젖은 기록지를 다시 펴 말린다(출시판 INTRO_01의 그림 — 젖은 까닭이 생겼다) · 이겸은 그날의 종이를 든다 · 제자는 평상에
func _calm_setup() -> void:
	var w = d.main.weather
	if w != null: w.force("clear", -1.0, 0.0)
	for key in papers:
		var n: Node3D = papers[key].n
		if is_instance_valid(n): n.visible = false
	for k in _marks.values() + [_eaves_mark]:
		if k != null and is_instance_valid(k): k.visible = false
	c._pro_show("paper4", true)
	var ruined_key := "p4" if saved == "name" else "p3"
	var keep_key := "p3" if saved == "name" else "p4"
	var mat: Vector2 = d.anchor("pro_mat")
	var rn: MeshInstance3D = papers[ruined_key].n
	rn.visible = true
	rn.global_position = Vector3(mat.x + 0.75, _y(mat) + 0.075, mat.y + 0.32)
	rn.rotation = Vector3(0, 0.3, 0)
	if _ink_cloud != null and is_instance_valid(_ink_cloud): _ink_cloud.visible = false
	d.place_actor("yigyeom_past", "pro_ig_stand", null, "right")
	d.anim_actor("yigyeom_past", "read")
	c._seat_player("pro_disc", 0.49, "left")
	hold_paper(papers[keep_key].n if saved == "name" else rn)
	c._cam({ "focus": "pro_two", "distance": 13.0, "pitch": 34.0, "fov": 34.0 }, 0.01)
	d.main.rig.update(0, d.main.player_pos, d.main.player.facing, null, true)
	c._tsfx("birds_day"); c._tsfx("stream_small"); c._e2_loop()   # E2: 비가 그친 뒤 새·개울·먼 엿장수가 돌아온다

# 이겸 손의 종이(INTRO_02 들어 올린 기록 = 이번 갈래의 종이) — 붓(INTRO_03)을 들면 내려놓는다
var _in_hand: Node3D = null
func hold_paper(n: Node3D) -> void:
	_in_hand = n
	var ig = d.actors.get("yigyeom_past")
	if n == null or ig == null: return
	n.visible = true
	n.global_position = Vector3(ig.pos.x + 0.35, d.world.height_at(ig.pos.x, ig.pos.z) + 1.15, ig.pos.z + 0.42)
	n.rotation = Vector3(deg_to_rad(80.0), 0.0, deg_to_rad(-8.0))
	(n as MeshInstance3D).scale = Vector3.ONE * 0.8

func drop_paper() -> void:
	if _in_hand == null or not is_instance_valid(_in_hand): return
	var ruined_n = papers["p4" if saved == "name" else "p3"].n
	if _in_hand == ruined_n:   # 번진 종이는 멍석으로 되돌려 말린다
		var mat: Vector2 = d.anchor("pro_mat")
		_in_hand.global_position = Vector3(mat.x + 0.75, _y(mat) + 0.075, mat.y + 0.32); _in_hand.rotation = Vector3(0, 0.3, 0); _in_hand.scale = Vector3.ONE
	else: _in_hand.visible = false   # 건진 종이는 품에(INTRO_04에서 기록책에 끼운다)
	_in_hand = null

# INTRO_04: 건진 종이를 기록책 왼쪽(빈) 쪽에 끼워 둔다 — 오른쪽 '구월 열이틀 맑음'은 가리지 않는다
func tuck_in_book() -> void:
	if saved == "": return
	var keep: MeshInstance3D = papers["p3" if saved == "name" else "p4"].n
	if not is_instance_valid(keep): return
	var a: Vector2 = d.anchor("pro_desk")
	var top: Vector3 = c._book_page_at()
	keep.visible = true
	keep.scale = Vector3.ONE * 0.42
	keep.global_position = Vector3(a.x - c.BOOK_PAGE * 0.5, top.y + 0.004, top.z + 0.01)
	keep.rotation = Vector3(0, 0.04, 0)
	(keep.material_override as StandardMaterial3D).emission = Color.BLACK
