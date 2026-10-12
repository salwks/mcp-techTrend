# 1인칭 시점 시험(region_main --viewtest — tools/run_story_tests.sh view:namwon). 헤드리스로 돈다. 사용자 settings.json에 쓰지 않는다(view_persist=false).
#   1 기본 3인칭 · 0 키(view_toggle)로 1인칭: 눈높이 1.55m · 카메라가 플레이어 층(20)을 뺌 · 플레이어 그림 층 = 20 · 가림 점무늬 끔
#   2 카메라 기준 움직임: 동쪽(fp_yaw 90°)을 보고 W → +x로 · ←→ 돌기
#   3 E 대상: 1인칭에서도 고을 사람이 E 대상이 되고(바라보는 쪽을 먼저 — _look_score), E로 말을 걸면 그동안 3인칭 → 끝나면 1인칭으로
#   4 저절로 3인칭: 컷신(cutscene) · 연출 카메라(d.camera) · 지도(M) 동안 3인칭, 끝나면 1인칭으로 돌아온다(바란 값 그대로)
#   5 0 키로 3인칭: 층·near 되돌림
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
	# 3 E 대상 · 말 걸기
	if d != null:
		_ok(d._look_score(Vector2.ZERO, main.fp_look_dir() * 1.5) < d._look_score(Vector2.ZERO, -main.fp_look_dir() * 1.2), "바라보는 쪽 1.5m가 뒤쪽 1.2m보다 먼저")
		await _talk()
	# 4 저절로 3인칭
	if d != null:
		d.cutscene(true)
		await main._wait_frames(3)
		_ok(not main.fp_active and main.fp_block == "story", "컷신 → 3인칭 (%s)" % main.fp_block)
		_ok((main.cam.cull_mask & main.PLAYER_LAYER) != 0, "컷신: 플레이어가 다시 보인다")
		d.cutscene(false)
		await main._wait_frames(3)
		_ok(main.fp_active, "컷신 끝 → 1인칭으로 돌아옴")
		d.camera({ "pitch": 30.0, "distance": 12.0 })
		await main._wait_frames(3)
		_ok(not main.fp_active and main.fp_block == "camera", "연출 카메라 → 3인칭 (%s)" % main.fp_block)
		_ok(is_equal_approx(float(main.rig.params(main.player_pos, null).pitch), 30.0), "연출 카메라 값 그대로(30)")
		d.camera(null)
		await main._wait_frames(3)
		_ok(main.fp_active, "연출 카메라 끝 → 1인칭")
	if main._map != null:
		main._map.toggle()
		await main._wait_frames(3)
		_ok(not main.fp_active, "지도 → 3인칭 (%s)" % main.fp_block)
		main._map.toggle()
		await main._wait_frames(3)
		_ok(main.fp_active, "지도 닫음 → 1인칭")
	# 5
	await _tap(KEY_0)
	await main._wait_frames(3)
	_ok(not main.first_person and not main.fp_active, "0 키 → 3인칭")
	_ok((main.cam.cull_mask & main.PLAYER_LAYER) != 0 and is_equal_approx(main.cam.near, 0.5), "3인칭: 층·near 되돌림")
	_ok(main.rig.cur.pitch > 35.0, "3인칭 각 %.1f" % main.rig.cur.pitch)
	if _fails.is_empty(): print("VIEWTEST PASS checks=%d" % _n)
	else: print("VIEWTEST FAIL ", "; ".join(_fails))
	main._quit()

# 가까운 고을 사람 곁에 서서 그쪽을 보고 E → 말 거는 동안 3인칭 → 끝나면 1인칭
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
		main.fp_yaw = PI * 0.5   # 동쪽(사람 쪽)을 본다
		await main._wait_frames(14)
		var tg = d._target
		if tg != null and String(tg.kind) == "ambient": got = true; break
	_ok(got, "1인칭: 바라보는 고을 사람이 E 대상")
	if not got: return
	_ok(main.fp_active, "E 앞: 1인칭")
	_key(KEY_E, true)
	await main._wait_frames(2)
	_key(KEY_E, false)
	var saw_third := false
	var w := 0
	while w < 900:
		await main._wait_frames(1); w += 1
		if not main.fp_active: saw_third = true
		if saw_third and not d.ambient.busy and not d.ui.modal: break
	_ok(saw_third, "말 거는 동안 3인칭 (%s)" % main.fp_block)
	await main._wait_frames(4)
	_ok(main.fp_active, "말이 끝나면 1인칭으로 돌아옴 (막힘: %s)" % main.fp_block)
