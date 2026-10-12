# 1인칭 시점 시험(region_main --viewtest — tools/run_story_tests.sh view:namwon). 헤드리스로 돈다. 사용자 settings.json에 쓰지 않는다(view_persist=false).
#   1 기본 3인칭 · 0 키(view_toggle)로 1인칭: 눈높이 1.55m · 카메라가 플레이어 층(20)을 뺌 · 플레이어 그림 층 = 20 · 가림 점무늬 끔 · 땅 잔무늬 켬
#   2 카메라 기준 움직임: 동쪽(fp_yaw 90°)을 보고 W → +x로 · ←→ 돌기 · 마우스(잡은 커서) 둘러보기 · 위아래 ±70°
#   3 1인칭 그대로(C68 v2): 고을 사람 E 말 걸기 · 이야기 인물 대사 · 살펴보기 카드 · 선택지 · 문제 비교 카드·결정(decide) · 카메라 없는 각본 장면 ·
#     지도 · Esc 멈춤 — 모두 눈높이 그대로(fp_view), 말하는 이·물건 쪽으로 돌아봄(시선 오차), 대화·카드·창 동안 마우스를 놓고 끝나면 다시 잡음, 끝난 뒤 같은 쪽을 봄
#   4 저작 연출: d.camera(30°) · CameraRig.shot · glide — 컷으로 저작대로(첫 프레임부터 목표 구도 — 사이 3인칭 없음, 플레이어 보임) → 끝나면 바로 눈높이
#   5 0 키로 3인칭: 층·near 되돌림 · 땅 잔무늬 끔
#   통과하면 "VIEWTEST PASS checks=n", 아니면 "VIEWTEST FAIL <까닭>".
extends RefCounted

var main
var d
var _fails: Array = []
var _n := 0

func _init(m) -> void:
	main = m

func _ok(c: bool, why: String) -> void:
	_n += 1
	if c: print("VIEWTEST check ok ", why)
	else:
		_fails.append(why); print("VIEWTEST check FAIL ", why)

func _key(kc: int, down: bool) -> void:
	var ev := InputEventKey.new(); ev.physical_keycode = kc; ev.keycode = kc; ev.pressed = down
	Input.parse_input_event(ev)

func _tap(kc: int) -> void:
	_key(kc, true)
	await main._wait_frames(2)
	_key(kc, false)
	await main._wait_frames(2)

func run() -> void:
	Engine.max_fps = 0
	main.view_persist = false
	await main._wait_frames(10)
	var n := 0
	while main._loading and n < 6000:
		await main._wait_frames(1); n += 1
	n = 0
	while (main.world.stats.jobs > 0 or main.placement.busy()) and n < 900:
		await main._wait_frames(1); n += 1
	d = main.story
	if d != null: d.ui.auto = true
	await main._wait_frames(20)
	# 1
	_ok(not main.fp_active and not main.first_person, "기본은 3인칭")
	await _tap(KEY_0)
	await main._wait_frames(3)
	_ok(main.first_person and main.fp_active, "0 키 → 1인칭 (막힘: %s)" % main.fp_block)
	_ok((main.cam.cull_mask & main.PLAYER_LAYER) == 0, "카메라가 플레이어 층을 그리지 않음")
	var lay := -1
	for c in main.player.find_children("*", "VisualInstance3D", true, false): lay = (c as VisualInstance3D).layers; break
	_ok(lay == main.PLAYER_LAYER, "플레이어 그림 층 = 20 (%d)" % lay)
	_ok(absf(main.cam.global_position.y - main.player_pos.y - main.FP_EYE) < 0.05, "눈높이 %.2f" % (main.cam.global_position.y - main.player_pos.y))
	_ok(main.occ_now == Vector2.ZERO, "1인칭: 가림 점무늬 끔")
	# 2 카메라 기준 움직임
	main.fp_yaw = PI * 0.5
	var p0: Vector3 = main.player_pos
	_key(KEY_W, true)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 700: await main._wait_frames(1)   # 헤드리스는 프레임이 아주 빨라 시간으로 잰다
	_key(KEY_W, false)
	await main._wait_frames(2)
	var dv: Vector3 = main.player_pos - p0
	_ok(dv.x > 0.5 and absf(dv.z) < dv.x * 0.5, "동쪽을 보고 W → 동쪽으로 (dx=%.2f dz=%.2f)" % [dv.x, dv.z])
	_ok(main.player.facing == "right", "걸은 쪽으로 facing (%s)" % main.player.facing)
	var y0: float = main.fp_yaw
	_key(KEY_LEFT, true)
	t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 300: await main._wait_frames(1)
	_key(KEY_LEFT, false)
	_ok(main.fp_yaw < y0 - 0.1, "← 왼쪽으로 돈다 (%.2f → %.2f)" % [y0, main.fp_yaw])
	# 마우스 둘러보기(시험은 커서를 잡지 않고 fp_mouse_force로 같은 길을 탄다)
	main.fp_mouse_force = true
	_ok(main.fp_mouse_wanted(), "걷는 1인칭: 마우스를 잡는다")
	var yb: float = main.fp_yaw
	_motion(Vector2(100, 0))
	await main._wait_frames(2)
	_ok(absf(main.fp_yaw - yb - 100.0 * main.FP_SENS.normal) < 0.04, "마우스 → 돈다 (%.3f — 창 배율로 조금 다르다)" % (main.fp_yaw - yb))
	_motion(Vector2(0, -100000))
	await main._wait_frames(2)
	_ok(absf(main.fp_pitch - main.FP_PITCH) < 0.001 and absf(rad_to_deg(main.FP_PITCH) - 70.0) < 0.1, "위로 70°에서 멈춤 (%.1f°)" % rad_to_deg(main.fp_pitch))
	_motion(Vector2(0, 100000))
	await main._wait_frames(2)
	_ok(absf(main.fp_pitch + main.FP_PITCH) < 0.001, "아래로 −70°에서 멈춤")
	main.fp_pitch = -0.06
	_ok(main._near_detail == 1.0, "1인칭: 땅 잔무늬 켬")
	# 3 1인칭 그대로
	if d != null:
		_ok(d._look_score(Vector2.ZERO, main.fp_look_dir() * 1.5) < d._look_score(Vector2.ZERO, -main.fp_look_dir() * 1.2), "바라보는 쪽 1.5m가 뒤쪽 1.2m보다 먼저")
		d.ui.auto_hold = 0.7   # 돌아보기(0.4초)가 대사 동안 끝나게
		await _talk()
		await _story_say()
		await _inspect()
		await _choice()
		await _problem()
		await _beat()
		d.ui.auto_hold = 0.03
	if main._map != null:
		main._map.toggle()
		await main._wait_frames(3)
		_ok(main.fp_view(), "지도 → 1인칭 그대로 (%s)" % main.fp_block)
		_ok(not main.fp_mouse_wanted(), "지도: 마우스 놓음")
		main._map.toggle()
		await main._wait_frames(3)
		_ok(main.fp_view() and main.fp_mouse_wanted(), "지도 닫음 → 다시 잡음")
	main.get_tree().paused = true
	_ok(not main.fp_mouse_wanted() and main.fp_active, "Esc 멈춤: 1인칭 그대로 · 마우스 놓음")
	main.get_tree().paused = false
	# 역마 창(FAST_TRAVEL 상태)은 1인칭 그대로 · 말·배 위는 3인칭(fp_blocker — 상태만 잠깐 바꿔 판정만 본다)
	if main.horse_ride != null:
		main.horse_ride.set_fast_travel(true)
		await main._wait_frames(2)
		_ok(main.fp_view(), "역마 창(FAST_TRAVEL): 1인칭 그대로 (%s)" % main.fp_block)
		main.horse_ride.set_fast_travel(false)
		var st0: String = main.horse_ride.state
		main.horse_ride.state = "AUTO_RIDE"
		var why: String = main.fp_blocker()
		main.horse_ride.state = st0
		_ok(why == "ride", "말 위: 3인칭으로 (%s)" % why)
	# 4 저작 연출
	if d != null:
		await _authored()
	# 5
	await _tap(KEY_0)
	await main._wait_frames(3)
	_ok(not main.first_person and not main.fp_active, "0 키 → 3인칭")
	_ok((main.cam.cull_mask & main.PLAYER_LAYER) != 0 and is_equal_approx(main.cam.near, 0.5), "3인칭: 층·near 되돌림")
	_ok(main.rig.cur.pitch > 35.0, "3인칭 각 %.1f" % main.rig.cur.pitch)
	_ok(main._near_detail == 0.0, "3인칭: 땅 잔무늬 끔")
	if _fails.is_empty(): print("VIEWTEST PASS checks=%d" % _n)
	else: print("VIEWTEST FAIL ", "; ".join(_fails))
	main._quit()

func _motion(rel: Vector2) -> void:
	var ev := InputEventMouseMotion.new(); ev.relative = rel
	Input.parse_input_event(ev)

# 시선이 점(머리·물건)을 보나: 수평 각 오차(라디안)
func _yaw_err(p: Vector3) -> float:
	var v := Vector2(p.x - main.player_pos.x, p.z - main.player_pos.z)
	return absf(wrapf(main.fp_look_dir().angle_to(v), -PI, PI))

# 지켜보며 기다리기: 매 프레임 눈높이 그대로인지, 대화·카드 동안 마우스를 놓는지
var _all_eye := true
var _released := false
func _watch_frame() -> void:
	if not main.fp_view(): _all_eye = false
	if (d.ui.modal or d.ambient.busy) and not main.fp_mouse_wanted(): _released = true

func _run_watch(steps: Array) -> void:
	_all_eye = true; _released = false
	var st := { done = false }
	var f := func(): await d.runner.run(steps); st.done = true
	f.call()
	var w := 0
	while not st.done and w < 3000:
		_watch_frame()
		await main._wait_frames(1); w += 1
	await main._wait_frames(3)

func _probe_pos(dx: float, dz: float) -> Array:
	return [main.player_pos.x + dx, main.player_pos.z + dz]

# 이야기 인물 대사: 곁에 세운 인물이 말하면 그쪽(머리)으로 돌아본다 · 나그네 대사는 그대로
func _story_say() -> void:
	main.fp_yaw = 0.0
	var at := _probe_pos(2.5, 1.2)
	await _run_watch([{ "spawn": "fp_probe", "kind": "villager_m", "at": at, "name": "시험 사람" },
		{ "say": "시험 사람", "lines": ["1인칭 시험 대사."] }, { "say": "나그네", "lines": ["예."] }])
	var a = d.actors.get("fp_probe")
	_ok(a != null, "시험 인물 세움")
	if a == null: return
	var head: Vector3 = a.pos + Vector3(0, 1.45, 0)
	_ok(_all_eye, "이야기 인물 대사: 1인칭 그대로")
	_ok(_released, "대사 동안 마우스 놓음")
	_ok(_yaw_err(head) < 0.12, "말하는 인물 쪽으로 돌아봄 (오차 %.1f°)" % rad_to_deg(_yaw_err(head)))
	var want_p := atan2(head.y - main.player_pos.y - main.FP_EYE, Vector2(head.x - main.player_pos.x, head.z - main.player_pos.z).length())
	_ok(absf(main.fp_pitch - want_p) < 0.1, "머리 높이로 (pitch %.1f° / %.1f°)" % [rad_to_deg(main.fp_pitch), rad_to_deg(want_p)])
	_ok(main.rig.override == null and main.rig.focus == null, "대화 구도(TALK) 없음")
	var y1: float = main.fp_yaw
	await main._wait_frames(10)
	_ok(absf(main.fp_yaw - y1) < 0.001 and main.fp_mouse_wanted(), "끝나면 같은 쪽 · 마우스 다시 잡음")
	# 이야기 인물에게 E(interact): 대화 구도 대신 시선
	a.spec["talk"] = [{ "steps": [{ "say": "시험 사람", "lines": ["말을 거셨소."] }] }]
	main.fp_yaw = PI
	_all_eye = true; _released = false
	var st := { done = false }
	var f := func(): await d.interact("fp_probe"); st.done = true
	f.call()
	var w := 0
	var talk_o := false
	while not st.done and w < 3000:
		_watch_frame()
		if main.rig.override != null or main.rig.focus != null: talk_o = true
		await main._wait_frames(1); w += 1
	_ok(_all_eye and not talk_o, "이야기 인물 E: 1인칭 그대로 · 대화 카메라 없음")
	_ok(d.talk_cam.is_empty(), "talk_cam 비어 있음")
	_ok(_yaw_err(head) < 0.12, "E 대상 인물 쪽으로 (오차 %.1f°)" % rad_to_deg(_yaw_err(head)))
	d.despawn_actor("fp_probe")

# 살펴보기: 물건 쪽(아래)으로 · 카드 동안 마우스 놓음
func _inspect() -> void:
	main.fp_yaw = 0.0
	var at := _probe_pos(-2.0, 1.5)
	if not d.data.has("objects"): d.data["objects"] = []
	d.data.objects.append({ "id": "_fp_probe", "at": at, "label": "시험 살펴보기", "steps": [{ "examine": "시험 물건", "text": "1인칭 살펴보기." }] })
	_all_eye = true; _released = false
	var st := { done = false }
	var f := func(): await d.interact("_fp_probe"); st.done = true
	f.call()
	var w := 0
	while not st.done and w < 3000:
		_watch_frame()
		await main._wait_frames(1); w += 1
	var op := Vector3(at[0], main.world.height_at(at[0], at[1]) + 0.6, at[1])
	_ok(_all_eye, "살펴보기: 1인칭 그대로")
	_ok(_released, "살펴보기 카드: 마우스 놓음")
	_ok(_yaw_err(op) < 0.12 and main.fp_pitch < -0.2, "물건 쪽으로 숙여 봄 (오차 %.1f° · pitch %.1f°)" % [rad_to_deg(_yaw_err(op)), rad_to_deg(main.fp_pitch)])
	d.data.objects.pop_back()

func _choice() -> void:
	await _run_watch([{ "choice": "1인칭 시험 — 어느 쪽?", "options": [{ "label": "가", "id": "a", "do": [] }, { "label": "나", "id": "b", "do": [] }] }])
	_ok(_all_eye and _released, "선택지: 1인칭 그대로 · 마우스 놓음")

# 문제 비교 카드(compare)·결정(decide) — Problems가 만드는 단계 그대로
func _problem() -> void:
	var Problems = load("res://scripts/story/problems.gd")
	var p := { "activities": [{ "id": "cmp", "type": "compare", "text": "1인칭 시험 비교.", "record": { "title": "시험 비교" } },
		{ "id": "dec", "type": "decide", "prompt": "1인칭 시험 — 무엇으로 정하나?", "options": [{ "id": "x", "label": "가" }, { "id": "y", "label": "나" }] }] }
	await _run_watch(Problems._body("fp_view_probe", p, p.activities[0]))
	_ok(_all_eye and _released, "문제 비교 카드: 1인칭 그대로 · 마우스 놓음")
	await _run_watch(Problems._body("fp_view_probe", p, p.activities[1]))
	_ok(_all_eye and _released, "문제 결정(decide): 1인칭 그대로 · 마우스 놓음")
	_ok(String(d.S.flags.get(Problems.decision_key("fp_view_probe"), "")) != "", "결정이 기록됨")

# 카메라 없는 각본 장면(컷신·글자막·기다림): 1인칭 그대로 · 플레이어 숨김 그대로
func _beat() -> void:
	await _run_watch([{ "cutscene": true }, { "caption": "1인칭 시험 장면", "sec": 0.3 }, { "say": "나그네", "lines": ["…"] }, { "wait": 0.2 }, { "cutscene": false }])
	_ok(_all_eye, "카메라 없는 각본 장면: 1인칭 그대로")
	_ok((main.cam.cull_mask & main.PLAYER_LAYER) == 0, "각본 장면: 플레이어 그림 숨김 그대로")

# 저작 연출: 컷으로 저작대로, 사이 3인칭 없이, 끝나면 눈높이
func _authored() -> void:
	main.fp_yaw = 0.0; main.fp_pitch = -0.06
	await main._wait_frames(3)
	var eye: Vector3 = main.player_pos + Vector3(0, main.FP_EYE, 0)
	d.camera({ "pitch": 30.0, "distance": 12.0 })
	await main._wait_frames(1)
	_ok(main.fp_active and main.fp_cut, "d.camera → 1인칭 안의 컷")
	_ok(absf(main.rig.cur.pitch - 30.0) < 0.01 and absf(main.rig.cur.distance - 12.0) < 0.01, "첫 프레임부터 저작 구도(%.1f°/%.1f — 3인칭 40° 거치지 않음)" % [main.rig.cur.pitch, main.rig.cur.distance])
	_ok((main.cam.cull_mask & main.PLAYER_LAYER) != 0, "컷: 플레이어가 보인다")
	var cut_y: float = main.player_pos.y + 0.9 + sin(deg_to_rad(30.0)) * 12.0
	var maxy := 0.0
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 900:
		maxy = maxf(maxy, main.cam.global_position.y); await main._wait_frames(1)
	_ok(maxy < cut_y + 0.3, "눈높이 → 컷: 더 높이(3인칭 자리) 올라가지 않음 (최고 %.1f · 컷 %.1f)" % [maxy, cut_y])
	_ok(absf(main.cam.global_position.y - cut_y) < 0.3, "컷 자리 (%.1f / %.1f)" % [main.cam.global_position.y, cut_y])
	d.camera(null)
	await main._wait_frames(1)
	_ok(main.fp_active and not main.fp_cut, "컷 끝 → 눈높이")
	maxy = 0.0
	t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 800:
		maxy = maxf(maxy, main.cam.global_position.y); await main._wait_frames(1)
	_ok(maxy < cut_y + 0.3, "컷 → 눈높이: 3인칭 자리를 거치지 않음 (최고 %.1f)" % maxy)
	_ok(main.cam.global_position.distance_to(eye) < 0.05 and (main.cam.cull_mask & main.PLAYER_LAYER) == 0, "눈높이로 돌아옴 · 플레이어 숨김")
	# 각본 시점(shot): 바로 끊어 들어가고 바로 끊어 나온다
	var sp: Vector3 = eye + Vector3(6, 3, 6)
	main.rig.shot = { pos = sp, look = main.player_pos, fov = 40.0 }
	await main._wait_frames(1)
	_ok(main.fp_cut and main.cam.global_position.distance_to(sp) < 0.01, "shot: 바로 그 자리")
	main.rig.shot = null
	await main._wait_frames(1)
	_ok(not main.fp_cut and main.cam.global_position.distance_to(eye) < 0.05, "shot 끝: 바로 눈높이")
	# 미끄러짐(glide): 1인칭에서는 목표 구도로 바로, 돌아오는 미끄러짐은 버린다
	main.rig.focus = { x = main.player_pos.x + 6.0, z = main.player_pos.z }
	main.rig.override = { pitch = 25.0, distance = 10.0 }
	main.rig.glide(1.5)
	await main._wait_frames(1)
	_ok(main.fp_cut and not main.rig.gliding() and absf(main.rig.cur.pitch - 25.0) < 0.01, "glide → 첫 프레임부터 목표 구도 (%.1f°)" % main.rig.cur.pitch)
	main.rig.override = null; main.rig.focus = null
	main.rig.glide(1.2)
	await main._wait_frames(1)
	_ok(not main.fp_cut and not main.rig.gliding(), "돌아오는 glide → 눈높이(미끄러짐 버림)")
	t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 700: await main._wait_frames(1)
	_ok(main.cam.global_position.distance_to(eye) < 0.05, "눈높이 (%.2f)" % main.cam.global_position.distance_to(eye))
	# 대화 구도 값(talk 표시)은 1인칭에서 넣지 않는다
	var tc: Dictionary = d.talk_camera_base()
	if not tc.is_empty():
		tc.focus = [main.player_pos.x + 3.0, main.player_pos.z]
		d.camera(tc)
		await main._wait_frames(1)
		_ok(not main.fp_cut and main.rig.override == null, "대화 구도(talk_camera_base)는 1인칭에서 컷이 아니다")
		await main._wait_frames(30)

# 가까운 고을 사람 곁에 서서 비스듬히 보고 E → 말 거는 동안 1인칭 그대로, 그 사람 쪽으로 돌아봄 → 끝나도 1인칭 · 같은 쪽
func _talk() -> void:
	var npc = main.npcs_amb
	if npc == null:
		_ok(false, "주변 인물 없음"); return
	var c := Vector2(main.player_pos.x, main.player_pos.z)
	var key := -1
	var t := 0
	while key < 0 and t < 600:
		var bd := INF
		for k in npc.agents:
			var ag: Dictionary = npc.agents[k]
			if ag.animal or ag.mode == "gull": continue
			var dd := Vector2(ag.pos.x, ag.pos.z).distance_to(c)
			if dd < bd and dd < 150.0: bd = dd; key = k
		if key < 0:
			await main._wait_frames(10); t += 10
	if key < 0:
		_ok(false, "곁에 고을 사람 없음"); return
	var got := false
	for i in 6:
		if not npc.agents.has(key): break
		var ag: Dictionary = npc.agents[key]
		var ap := Vector2(ag.pos.x, ag.pos.z)
		main.teleport(ap.x - 1.0, ap.y)
		main.fp_yaw = PI * 0.5 - 0.6   # 사람 쪽(동쪽)에서 34° 비껴 본다
		await main._wait_frames(14)
		var tg = d._target
		if tg != null and String(tg.kind) == "ambient": got = true; break
	_ok(got, "1인칭: 바라보는 고을 사람이 E 대상")
	if not got: return
	_ok(main.fp_active, "E 앞: 1인칭")
	var y0: float = main.fp_yaw
	_key(KEY_E, true)
	await main._wait_frames(2)
	_key(KEY_E, false)
	_all_eye = true; _released = false
	var w := 0
	var started := false
	while w < 3000:
		_watch_frame()
		await main._wait_frames(1); w += 1
		if d.ambient.busy or d.ui.modal: started = true
		if started and not d.ambient.busy and not d.ui.modal: break
	_ok(started, "고을 사람과 말을 나눔")
	_ok(_all_eye, "말 거는 동안 1인칭 그대로 (%s)" % main.fp_block)
	_ok(_released, "말 거는 동안 마우스 놓음")
	var tp := Vector3(main.player_pos.x + 1.0, main.player_pos.y, main.player_pos.z)
	if npc.agents.has(key): tp = npc.agents[key].pos
	_ok(_yaw_err(tp) < 0.2, "그 사람 쪽으로 돌아봄 (%.1f° → %.1f°, 오차 %.1f°)" % [rad_to_deg(y0), rad_to_deg(main.fp_yaw), rad_to_deg(_yaw_err(tp))])
	var y1: float = main.fp_yaw
	await main._wait_frames(6)
	_ok(main.fp_active and absf(main.fp_yaw - y1) < 0.001, "말이 끝나면 같은 쪽을 본 채 1인칭 (막힘: %s)" % main.fp_block)
	_ok(main.fp_mouse_wanted(), "말이 끝나면 마우스 다시 잡음")
