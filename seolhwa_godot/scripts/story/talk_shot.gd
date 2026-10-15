# 대화 카메라 화면(창 필요, 시험 저장으로만): --talkshot=<인물 id|auto> --shotdir=폴더 [--shotname=이름] --winshot
#   사건 장면이 서기를 기다려(여는 장면은 auto로 넘김) → 그 이야기 인물 곁(카메라 쪽 1.8m)으로 → E와 같은 d.interact(id) →
#   첫 대사가 뜬 채로 찍는다 → 끝. 시점 값(rig.override)과 talk_cam을 함께 찍는다. 놀이에는 쓰이지 않는다.
#   auto: 말을 걸 수 있는 이야기 인물 가운데 플레이어에게 가장 가까운 것.
#   재기획 2단계(대화 구도 talk_frame.gd):
#     --talkfrom=dx,dz   인물 발에서 이만큼 떨어진 자리에서 E(기본 -0.6,1.7 — 카메라 쪽, 가림을 일부러 재현하는 자리)
#     --talkmid=프레임    E 뒤 이 프레임에 한 장 더(옮겨 가는 도중) · --talkback  대화를 끝까지 넘기고 돌아온 화면도 찍는다
#     --talkcycle=N      화면 없이도 도는 시험: 네 방향에서 N번 말 걸기 — E를 3프레임마다 연타하며 끝까지 넘기고,
#                        끝난 뒤 카메라(yaw 0·talk_yaw 없음·override/focus 없음·평소 거리)·가림 기준점·이동 잠금이 되돌아왔나,
#                        한 번 누름에 두 줄을 넘지 않나, 닫힌 뒤 E가 곧바로 대화를 다시 열지 않나. 1인칭(--view=first)이면 대화 구도를 쓰지 않나.
#                        끝 줄: TALKCYCLE PASS n / TALKCYCLE FAIL …
extends RefCounted

var main

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

func run(spec: String) -> void:
	await _wait_load()
	var d = main.story
	if d == null: print("TALKSHOT FAIL 이야기 없음"); main._quit(); return
	d.ui.auto = true
	var n := 0
	while (not d._started or d.runner.busy or d.ui.modal) and n < 9000:
		await main._wait_frames(1); n += 1
	await main._wait_frames(30)
	var id := spec
	if spec == "auto" or spec == "":
		var pp := Vector2(main.player_pos.x, main.player_pos.z)
		var bd := INF
		for aid in d.actors:
			var x: Dictionary = d.actors[aid]
			if not x.shown or x.spec.get("talk") == null: continue
			var any := false
			for t in x.spec.talk:
				if d.runner.cond(t.get("when", true)): any = true; break
			if not any: continue
			var dd: float = pp.distance_to(Vector2(x.pos.x, x.pos.z))
			if dd < bd: bd = dd; id = String(aid)
	if not d.actors.has(id):
		for aid in d.actors:
			var x: Dictionary = d.actors[aid]
			print("TALKSHOT actor %s shown=%s vis=%s talk=%s" % [aid, x.shown, x.ch.visible, x.spec.get("talk") != null])
		print("TALKSHOT started=%s busy=%s modal=%s phase=%s" % [d._started, d.runner.busy, d.ui.modal, d.S.phase])
	if not d.actors.has(id): print("TALKSHOT FAIL 인물 없음 %s case=%s" % [id, d.case_id]); main._quit(); return
	var a: Dictionary = d.actors[id]
	if main.args.has("talkcycle"):
		d.ui.auto = false
		await _cycle(id, int(main.args.talkcycle))
		main._quit(); return
	var off := _from()
	main.teleport(a.pos.x + off.x, a.pos.z + off.y)
	main.rig.update(0, main.player_pos, main.player.facing, null, true)
	await _wait_load()
	await main._wait_frames(40)
	d.ui.auto = false
	var dir: String = main._abs(String(main.args.get("shotdir", "shots/talk")))
	var nm := String(main.args.get("shotname", "%s_%s" % [d.case_id, id]))
	d.interact(id)
	if main.args.has("talkmid"):
		await main._wait_frames(int(main.args.talkmid))
		main._save(dir.path_join(nm + "_mid.png"))
		await main._wait_frames(maxi(0, 120 - int(main.args.talkmid)))
	else:
		await main._wait_frames(120)
	print("TALKSHOT case=%s actor=%s talk_cam=%s override=%s cur=%.1f/%.0f/%.0f yaw=%.1f frame=%s" % [d.case_id, id, d.talk_cam, main.rig.override,
		main.rig.cur.distance, main.rig.cur.pitch, main.rig.cur.fov, rad_to_deg(main.rig.yaw), d.last_frame])
	main._save(dir.path_join(nm + ".png"))
	if main.args.has("talkback"):
		await _finish_talk(9999)
		await main._wait_frames(45)
		print("TALKSHOT back yaw=%.2f talk_yaw=%s override=%s focus=%s occ=%s talking=%s cur=%.1f/%.0f" % [rad_to_deg(main.rig.yaw), main.rig.talk_yaw,
			main.rig.override, main.rig.focus, main.occ_script, d.talking, main.rig.cur.distance, main.rig.cur.pitch])
		main._save(dir.path_join(nm + "_back.png"))
	main._quit()

func _from() -> Vector2:
	var p := String(main.args.get("talkfrom", "-0.6,1.7")).split(",")
	return Vector2(float(p[0]), float(p[1]) if p.size() > 1 else 1.7)

func _press_e() -> void:
	for down in [true, false]:
		var ev := InputEventKey.new()
		ev.physical_keycode = KEY_E; ev.keycode = KEY_E; ev.pressed = down
		Input.parse_input_event(ev)

# 대화를 끝까지 넘긴다(E를 every 프레임마다) — 대화 상자에 뜬 줄 수와 누른 수를 센다
func _finish_talk(every: int) -> Dictionary:
	var d = main.story
	var presses := 0; var lines := 0; var last := ""; var jumps := 0; var chg := 0
	var n := 0
	var step := every if every < 9999 else 3
	while (d.talking or d.runner.busy or d.ui.modal) and n < 3000:
		n += 1
		await main._wait_frames(1)
		var cur := String(d.ui._type_full) if d.ui._dialog.visible and d.ui.modal else ""
		if cur != "" and cur != last:
			lines += 1; last = cur; chg += 1
		if n % step == 0:
			if chg > 1: jumps += 1   # 누름 한 번 사이에 줄이 둘 넘게 바뀜
			chg = 0
			_press_e(); presses += 1
	return { presses = presses, lines = lines, frames = n, jumps = jumps }

func _cycle(id: String, times: int) -> void:
	var d = main.story
	var rig = main.rig
	var fails := []
	var offs := [Vector2(-0.6, 1.7), Vector2(1.7, 0.3), Vector2(-1.7, 0.2), Vector2(0.4, -1.6)]
	var fp: bool = bool(main.get("fp_active"))
	var ok_n := 0
	for i in times:
		var a: Dictionary = d.actors[id]
		var off: Vector2 = offs[i % offs.size()]
		main.teleport(a.pos.x + off.x, a.pos.z + off.y)
		rig.update(0, main.player_pos, main.player.facing, null, true)
		await main._wait_frames(30)
		var t := 0
		while d._target == null and t < 120:
			await main._wait_frames(1); t += 1
		if d._target == null or String(d._target.get("id", "")) != id:
			fails.append("%d: 대상 없음(%s) busy=%s modal=%s talking=%s cut=%s dist=%.2f fp=%s" % [i, d._target, d.runner.busy, d.ui.modal, d.talking, d._cut,
				Vector2(main.player_pos.x, main.player_pos.z).distance_to(Vector2(a.pos.x, a.pos.z)), main.get("fp_active")]); continue
		var d0: float = rig.cur.distance
		_press_e()
		var yaw_max := 0.0
		var t2 := 0
		while not d.talking and t2 < 20:
			await main._wait_frames(1); t2 += 1
		if not d.talking: fails.append("%d: E로 대화가 열리지 않음" % i); continue
		# 접근 동안(0.55초) 연타 — 대화가 두 번 열리거나 줄이 건너뛰면 안 된다
		var r := await _finish_talk(3)
		yaw_max = absf(rad_to_deg(rig.yaw))
		# 닫힌 뒤 0.15초 동안 E 연타 — 다시 열리면 안 된다(0.2초 막음)
		for k in 3:
			_press_e(); await main._wait_frames(3)
		var reopened: bool = d.talking or d.ui.modal
		await main.get_tree().create_timer(0.7).timeout   # 돌아오는 미끄러짐 0.45초(헤드리스는 프레임이 빨라 시간으로 기다린다)
		await main._wait_frames(2)
		var bad := []
		if reopened: bad.append("닫힌 뒤 E로 다시 열림")
		if absf(rig.yaw) > 0.01: bad.append("yaw %.1f°" % rad_to_deg(rig.yaw))
		if rig.talk_yaw != null: bad.append("talk_yaw 남음")
		if rig.override != null or rig.focus != null: bad.append("override/focus 남음")
		if main.occ_script != null: bad.append("가림 기준점 남음")
		if d.blocks_move(): bad.append("이동 잠김")
		if absf(rig.cur.distance - d0) > 0.6: bad.append("거리 %.1f→%.1f" % [d0, rig.cur.distance])
		if r.jumps > 0: bad.append("줄 건너뜀 %d" % r.jumps)
		if fp and not bool(main.get("fp_active")): bad.append("1인칭 풀림")
		if fp and not d.last_frame.is_empty(): bad.append("1인칭에서 대화 구도(옆 돌기·한 걸음)를 씀")
		if fp and (rig.talk_yaw != null or yaw_max > 0.01): bad.append("1인칭에서 yaw가 돎")
		print("TALKCYCLE %d off=%s fp=%s lines=%d presses=%d frames=%d frame=%s → %s" % [i, off, fp, r.lines, r.presses, r.frames,
			String(d.last_frame.get("phase", "-")), "ok" if bad.is_empty() else "; ".join(bad)])
		if bad.is_empty(): ok_n += 1
		else: fails.append("%d: %s" % [i, "; ".join(bad)])
	if fails.is_empty(): print("TALKCYCLE PASS %d" % ok_n)
	else: print("TALKCYCLE FAIL ", " | ".join(fails))
