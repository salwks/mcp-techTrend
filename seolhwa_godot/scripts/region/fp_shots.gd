# 1인칭 v2 화면 찍기(창 필요, 시험 저장으로만 — 사용자 저장 칸·progress.json을 건드리지 않게 --savefile을 꼭 준다):
#   godot --path . res://scenes/region.tscn --resolution 1024x768 -- --region=JL_NAMWON_UNBONG --fpshots=shots/fp_v2 \
#     --ridefixture=res://story/hwangju/test_post_hanyang.json --savefile=user://fpshots_progress.json --notitle --winshot --time=11 --weather=clear
#   1인칭으로 바꾼 뒤: 고을 사람 대화(돌아봄) · 이야기 인물 대사 · 살펴보기 카드 · 문제 결정 카드 · 저작 컷(전·중·후) · 가까운 땅(잔무늬 끔/켬) ·
#   먼 산(대기 원근 끔/켬, 1인칭·3인칭). 놀이에는 쓰이지 않는다.
extends RefCounted

var main
var d
var dir := ""

func _init(m) -> void:
	main = m

func _wait_load() -> void:
	await main._wait_frames(10)
	var n := 0
	while main._loading and n < 6000:
		await main._wait_frames(1); n += 1
	n = 0
	while (main.world.stats.jobs > 0 or main.placement.busy()) and n < 900:
		await main._wait_frames(1); n += 1

func _sec(s: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < s * 1000.0: await main._wait_frames(1)

func _shot(nm: String) -> void:
	main._save(dir.path_join(nm + ".png"))
	print("FPSHOT %s yaw=%.0f pitch=%.0f view=%s cut=%s fps=%.0f" % [nm, rad_to_deg(main.fp_yaw), rad_to_deg(main.fp_pitch), main.fp_view(), main.fp_cut, Engine.get_frames_per_second()])

func _go(x: float, z: float, yaw_deg: float, pitch_deg: float) -> void:
	main.teleport(x, z)
	await _wait_load()
	main.fp_yaw = deg_to_rad(yaw_deg); main.fp_pitch = deg_to_rad(pitch_deg)
	await _sec(1.0)

func _key(kc: int, down: bool) -> void:
	var ev := InputEventKey.new(); ev.physical_keycode = kc; ev.keycode = kc; ev.pressed = down
	Input.parse_input_event(ev)

func run(spec: String) -> void:
	dir = main._abs(spec if spec != "1" else "shots/fp_v2")
	main.view_persist = false
	await _wait_load()
	d = main.story
	if d != null:
		d.ui.auto = true
		var n := 0
		while (not d._started or d.runner.busy or d.ui.modal) and n < 9000:
			await main._wait_frames(1); n += 1
	main.set_first_person(true, false)
	await _sec(1.0)
	var home := Vector2(main.player_pos.x, main.player_pos.z)
	main.args.erase("winshot")   # 땅·먼 산은 장면만(글 띠 없이), 대화·카드는 창 그대로
	# 1 가까운 땅 — 남문 앞 흙길(잔무늬 끔/켬), 풀밭
	await _go(-3240.0, 300.0, 0.0, -28.0)
	main.args["nonear"] = "1"; await _sec(0.5); await _shot("ground_road_before")
	main.args.erase("nonear"); await _sec(0.5); await _shot("ground_road_after")
	var g := _find_lu(home, [1, 0])
	await _go(g.x, g.y, 90.0, -28.0)
	main.args["nonear"] = "1"; await _sec(0.5); await _shot("ground_grass_before")
	main.args.erase("nonear"); await _sec(0.5); await _shot("ground_grass_after")
	# 2 먼 산 — 대기 원근 끔/켬(1인칭 동쪽 지리산 쪽, 3인칭 같은 자리)
	var v := _find_lu(home, [2, 3], 300)
	var vy := _high_yaw(v)
	await _go(v.x, v.y, vy, 3.0)
	var ab: float = main.post.aerial_blur
	await _aerial(false); await _shot("far_fp_before")
	await _aerial(true); await _shot("far_fp_after")
	main.set_first_person(false, false); await _sec(1.0)
	await _aerial(false); await _shot("far_third_before")
	await _aerial(true); await _shot("far_third_after")
	# 낮은 각본 시점(shot — 먼 끝 6000m, 실제 먼 산 지형): 산 쪽으로 높이 9m에서
	var dv := Vector2(sin(deg_to_rad(vy)), -cos(deg_to_rad(vy)))
	var sp: Vector3 = main.player_pos + Vector3(0, 9.0, 0)
	main.rig.shot = { pos = sp, look = sp + Vector3(dv.x * 40.0, -1.5, dv.y * 40.0), fov = 40.0 }
	await _sec(1.0)
	await _aerial(false); await _shot("far_vista_before")
	await _aerial(true); await _shot("far_vista_after")
	main.rig.shot = null
	main.set_first_person(true, false); await _sec(0.5)
	main.args["winshot"] = "1"
	# 3 고을 사람 대화: 비스듬히 보고 E → 그쪽으로 돌아봄, 대화 창
	if d != null:
		d.ui.auto_hold = 4.0
		main.teleport(home.x, home.y); await _wait_load(); await _sec(2.0)
		await _ambient_talk(home)
		await _story_say()
		await _inspect()
		await _decide()
		d.ui.auto_hold = 0.03
		await _cut()
	print("FPSHOT done")
	main._quit()

# 가까운 풀밭·숲 자리(건물에서 떨어진) 찾기
func _find_lu(c: Vector2, kinds: Array, r0 := 40) -> Vector2:
	for r in range(r0, r0 + 1500, 20):
		for i in 16:
			var a := TAU * i / 16.0
			var q := c + Vector2(cos(a), sin(a)) * r
			var ok := true
			for dq in [Vector2(0, 0), Vector2(8, 0), Vector2(16, 0), Vector2(8, 6), Vector2(8, -6)]:
				if not kinds.has(main.world.landuse_at(q.x + dq.x, q.y + dq.y)): ok = false; break
			if ok: print("FPSHOT grass at ", q); return q
	return c

# 2~3km 밖 가장 높은 쪽(산)으로 보는 yaw(도, 0 = 북쪽)
func _high_yaw(c: Vector2) -> float:
	var best := 0.0; var bh := -INF
	for i in 36:
		var a := TAU * i / 36.0
		var dv := Vector2(sin(a), -cos(a))
		var h := 0.0
		for r in [1500.0, 2500.0, 3500.0]: h = maxf(h, main.world.height_at(c.x + dv.x * r, c.y + dv.y * r))
		if h > bh: bh = h; best = rad_to_deg(a)
	print("FPSHOT vista at %s yaw=%.0f h=%.0f" % [c, best, bh])
	return best

func _aerial(on: bool) -> void:
	main.AERIAL_BLUR   # 상수(읽기만)
	var k := 1.0 if on else 0.0
	# region_main._update_dof가 매 프레임 넣으므로 끌 때는 post 값을 직접 0으로(덮어쓰기 위해 몇 프레임 동안)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 600:
		if not on: main.post.aerial_blur = 0.0; main.post.aerial_haze = 0.0
		await main._wait_frames(1)
	if not on: main.post.aerial_blur = 0.0; main.post.aerial_haze = 0.0

func _ambient_talk(home: Vector2) -> void:
	var npc = main.npcs_amb
	if npc == null: return
	for tries in 8:
		var c := Vector2(main.player_pos.x, main.player_pos.z)
		var key := -1; var bd := INF
		for k in npc.agents:
			var ag: Dictionary = npc.agents[k]
			if ag.animal or ag.mode == "gull" or not ag.ch.visible: continue
			var dd := Vector2(ag.pos.x, ag.pos.z).distance_to(c)
			if dd < bd and dd < 200.0: bd = dd; key = k
		if key < 0: await _sec(0.5); continue
		var ag: Dictionary = npc.agents[key]
		main.teleport(ag.pos.x - 1.4, ag.pos.z + 0.6)
		main.fp_yaw = deg_to_rad(40.0); main.fp_pitch = -0.06
		await main._wait_frames(20)
		if d._target != null and String(d._target.kind) == "ambient": break
	await _shot("talk_ambient_before")
	_key(KEY_E, true); await main._wait_frames(2); _key(KEY_E, false)
	await _sec(1.2)
	await _shot("talk_ambient_fp")
	var n := 0
	while (d.ambient.busy or d.ui.modal) and n < 3000:
		await main._wait_frames(1); n += 1
	await _sec(0.3)

func _story_say() -> void:
	var pp := Vector2(main.player_pos.x, main.player_pos.z)
	main.fp_yaw = 0.0
	var f := func(): await d.runner.run([{ "spawn": "fp_shot", "kind": "scholar", "at": [pp.x + 2.6, pp.y + 0.8], "facing": "left", "name": "선비" },
		{ "say": "선비", "lines": ["길손이시오? 이 고을엔 처음 보는 얼굴이구려."] }])
	f.call()
	await _sec(1.4)
	await _shot("talk_story_fp")
	while d.runner.busy: await main._wait_frames(1)
	d.despawn_actor("fp_shot")

func _inspect() -> void:
	var pp := Vector2(main.player_pos.x, main.player_pos.z)
	main.fp_yaw = 0.0; main.fp_pitch = -0.06
	if not d.data.has("objects"): d.data["objects"] = []
	d.data.objects.append({ "id": "_fp_shot", "at": [pp.x - 1.6, pp.y + 1.2], "label": "살펴보기", "steps": [{ "examine": "길바닥 자국", "text": "짚신 자국이 남문 쪽으로 이어진다. 흙이 아직 무르다." }] })
	var f := func(): await d.interact("_fp_shot")
	f.call()
	await _sec(1.2)
	await _shot("inspect_fp")
	while d.runner.busy: await main._wait_frames(1)
	d.data.objects.pop_back()

func _decide() -> void:
	var Problems = load("res://scripts/story/problems.gd")
	var p := { "activities": [{ "id": "dec", "type": "decide", "prompt": "누구 말을 믿을까?", "options": [{ "id": "a", "label": "주모의 말 — 고갯길" }, { "id": "b", "label": "마부의 말 — 큰길" }, { "id": "c", "label": "아직 정하지 않는다" }] }] }
	main.fp_yaw = deg_to_rad(-30.0)
	var f := func(): await d.runner.run(Problems._body("fp_shot_probe", p, p.activities[0]))
	f.call()
	await _sec(1.2)
	await _shot("decide_fp")
	while d.runner.busy: await main._wait_frames(1)

# 저작 컷(남원 7A와 같은 34/17/36 구도 — 플레이어 곁 겨냥): 전(눈높이) · 컷 · 뒤(눈높이)
func _cut() -> void:
	main.fp_yaw = 0.0; main.fp_pitch = -0.06
	await _sec(0.5)
	await _shot("cut_0_fp_before")
	d.camera({ "pitch": 34.0, "distance": 17.0, "fov": 36.0, "focus": "player" })
	await main._wait_frames(2)
	await _shot("cut_1_first_frame")
	await _sec(1.2)
	await _shot("cut_2_authored")
	d.camera(null)
	await main._wait_frames(2)
	await _shot("cut_3_first_frame_back")
	await _sec(0.8)
	await _shot("cut_4_fp_after")
