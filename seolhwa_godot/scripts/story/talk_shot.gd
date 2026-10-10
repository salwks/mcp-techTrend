# 대화 카메라 화면(창 필요, 시험 저장으로만): --talkshot=<인물 id|auto> --shotdir=폴더 [--shotname=이름] --winshot
#   사건 장면이 서기를 기다려(여는 장면은 auto로 넘김) → 그 이야기 인물 곁(카메라 쪽 1.8m)으로 → E와 같은 d.interact(id) →
#   첫 대사가 뜬 채로 찍는다 → 끝. 시점 값(rig.override)과 talk_cam을 함께 찍는다. 놀이에는 쓰이지 않는다.
#   auto: 말을 걸 수 있는 이야기 인물 가운데 플레이어에게 가장 가까운 것.
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
	main.teleport(a.pos.x - 0.6, a.pos.z + 1.7)
	main.rig.update(0, main.player_pos, main.player.facing, null, true)
	await _wait_load()
	await main._wait_frames(40)
	d.ui.auto = false
	d.interact(id)
	await main._wait_frames(120)
	var dir: String = main._abs(String(main.args.get("shotdir", "shots/talk")))
	var nm := String(main.args.get("shotname", "%s_%s" % [d.case_id, id]))
	print("TALKSHOT case=%s actor=%s talk_cam=%s override=%s cur=%.1f/%.0f/%.0f" % [d.case_id, id, d.talk_cam, main.rig.override,
		main.rig.cur.distance, main.rig.cur.pitch, main.rig.cur.fov])
	main._save(dir.path_join(nm + ".png"))
	main._quit()
