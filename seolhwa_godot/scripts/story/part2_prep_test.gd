# 춘향 PART II 준비 시험·촬영 — 공용 자세(sit·bow·kneel) · PART II 차림 넷 · 잔치 군중 짜임 · set_pose(같은 사람) · PART II 소품
#   시험(헤드리스):  --region=JL_NAMWON_UNBONG --p2preptest --notitle      → 끝 줄 PREPTEST PASS n (part2 prep) / FAIL …(run_story_tests 판정 줄과 같은 머리)
#   촬영(창):        --region=JL_NAMWON_UNBONG --p2prepshot[=poses,looks,banquet] --nostory --notitle --shotdir=shots/chunhyang_part2_prep --savefile=user://chp_p2prep.json
#   상태는 placement_gate.fake(가짜 단계)로만 바꾼다 — 실제 저장은 쓰지 않는다(시험 저장 파일만). prep_test.gd의 도움 함수를 그대로 쓴다.
extends "res://scripts/story/prep_test.gd"

const ChData := preload("res://story/namwon_chunhyang/namwon_chunhyang_data.gd")
const ChunKit := preload("res://kit/story/chunhyang.gd")
const POSES := ["sit", "bow", "kneel"]
const GENERIC_SAMPLE := ["villager_m", "villager_f", "elder", "child_boy", "child_girl", "hunter", "innkeeper", "scholar", "merchant", "official",
	"farmer", "farmwife", "traveler", "monk", "player"]
const STORY_SAMPLE := ["chunhyang", "mongryong", "bangja", "wolmae", "hyangdan", "pojol", "py_clerk", "woochi", "chaekkwae", "daughter", "yigyeom"]
const PART2_LOOKS := {
	chunhyang_prison = ["idle", "walk", "talk", "sit", "kneel", "bow"],
	mongryong_beggar = ["idle", "walk", "talk", "mapae", "sit", "bow", "kneel"],
	byeon = ["idle", "talk", "sit", "stand", "bow", "kneel"],
	gisaeng = ["idle", "talk", "sit", "serve", "bow", "kneel"],
	gisaeng_b = ["idle", "talk", "sit", "serve", "bow", "kneel"],
	gisaeng_c = ["idle", "talk", "sit", "serve", "bow", "kneel"],
}
const P2_PROPS_OFFICE := ["ti_dais", "ti_seat_screen", "ti_hyeongteul", "ti_wine_cart"]
const P2_PROPS_FEAST := ["ti_dais", "ti_seat_screen", "ti_chail", "ti_feast_w0", "ti_feast_e2", "ti_jansang_hall_w", "ti_jansang_hall_e", "ti_jusang_dais_w"]

func _check(cond: bool, what: String) -> void:
	if cond: ok += 1
	else:
		fails.append(what)
		print("P2PREPTEST check FAIL: ", what)

func _char(kind: String) -> SpriteChar:
	var b: String = crowd._ensure_bank(kind)
	var ch := SpriteChar.new(b)
	main.scene_vp.add_child(ch)
	return ch

func run() -> void:
	gate = main.placement.gate
	crowd = main.crowd
	if main.args.has("p2prepshot"): await _p2_shots(); return
	await _wait_load()
	print("P2PREPTEST start case=%s" % [main.story.case_id if main.story != null else "-"])
	_poses_checks()
	_looks_checks()
	_sink_checks()
	_cast_checks()
	await _crowd_pose_checks()
	_story_pose_checks()
	_guard_checks()
	await _props_checks()
	if fails.is_empty(): print("PREPTEST PASS %d (part2 prep)" % ok)
	else: print("PREPTEST FAIL %d/%d (part2 prep) — %s" % [fails.size(), ok + fails.size(), "; ".join(fails)])
	main._quit()

# ---- 1. 공용 자세: 고을 사람(generic)·이야기 인물 모두 sit·bow·kneel, 앞·옆·뒤. 예전 sit(이야기 인물)은 그대로 ----
func _poses_checks() -> void:
	_check(FileAccess.file_exists("res://data/" + SpriteChar.POSE_FILE), "공용 자세 묶음 data/frames_pose.json 있음(굽기 ?set=poses)")
	var miss := []
	for kind in GENERIC_SAMPLE + STORY_SAMPLE:
		var ch := _char(kind)
		if ch.kind != kind: miss.append(kind + "(그림 없음)")
		for p in POSES:
			if not ch.has_anim(p): miss.append("%s:%s" % [kind, p])
			for v in ["front", "side", "back"]:
				if not (ch._bank.clips as Dictionary).has("%s|%s" % [v, p]): miss.append("%s:%s|%s" % [kind, v, p])
		ch.play("kneel", true)
		ch.update_char(0.016, main.cam)
		if ch.anim != "kneel" or ch._frame.is_empty(): miss.append(kind + ":kneel 그림")
		ch.queue_free()
	_check(miss.is_empty(), "고을 사람 %d종·이야기 인물 %d종 모두 sit·bow·kneel(앞·옆·뒤) %s" % [GENERIC_SAMPLE.size(), STORY_SAMPLE.size(), miss])
	# 이미 sit이 있던 이야기 인물(춘향 PART I 굽기)은 예전 클립 그대로(PART I 불변)
	var src = JSON.parse_string(FileAccess.get_file_as_string("res://data/frames_story_namwon_chunhyang.json"))
	var ch2 := _char("chunhyang")
	ch2.has_anim("bow")
	var same := true
	for v in ["front", "side", "back"]:
		var a: Dictionary = ch2._bank.clips.get("%s|sit" % v, {})
		var b: Dictionary = src.chunhyang.clips.get("%s|sit" % v, {})
		same = same and not a.is_empty() and a.frames.size() == b.frames.size() and int(a.frames[0].page) == int(b.frames[0].page) and is_equal_approx(float(a.frames[0].u0), float(b.frames[0].u0))
	_check(same and ch2._bank.clips.has("front|kneel"), "춘향(PART I)의 예전 sit은 그대로, kneel·bow만 더함")
	ch2.queue_free()
	# 별칭 stand = idle
	var ch3 := _char("villager_m")
	ch3.play("stand", true)
	_check(ch3.anim == "idle", "stand는 idle(별칭)")
	ch3.queue_free()

# ---- 2. PART II 차림 넷(+기생 셋) — 묶음 frames_story_chunhyang_part2.json ----
func _looks_checks() -> void:
	var bad := []
	for kind in PART2_LOOKS:
		var ch := _char(kind)
		if ch.kind != kind: bad.append(kind + "(그림 없음)")
		for a in PART2_LOOKS[kind]:
			if not ch.has_anim(a): bad.append("%s:%s" % [kind, a])
		ch.queue_free()
	_check(bad.is_empty(), "PART II 차림(춘향 옥·몽룡 거지·변학도·기생 셋) 동작 다 있음 %s" % [bad])
	_check(main.story.BANK_FILES.has("frames_story_chunhyang_part2.json"), "PART II 묶음이 이야기 그림 목록에")
	var ch := _char("byeon")
	ch.play("sit", true); ch.facing = "down"; ch.update_char(0.016, main.cam)
	var y_sit: float = float(ch._frame.get("y1", 0.0))
	ch.play("idle", true); ch.update_char(0.016, main.cam)
	var y_idle: float = float(ch._frame.get("y1", 0.0))
	_check(y_sit < y_idle - 0.3, "변학도 sit(교의)은 선 키보다 낮다(%.2f < %.2f)" % [y_sit, y_idle])
	ch.queue_free()

# ---- 3. SIT_SINK 없음 — 앉은 사람은 땅(또는 대청 dy) 높이 그대로, 그림이 앉은 그림 ----
func _sink_checks() -> void:
	_check(not (EventCrowd as GDScript).get_script_constant_map().has("SIT_SINK"), "EventCrowd에 SIT_SINK 상수 없음")
	var src := FileAccess.get_file_as_string("res://scripts/story/event_crowd.gd")
	_check(src.find("SIT_SINK") < 0 and src.find("sink") < 0, "EventCrowd 코드에 서 있기 낮추기 꼼수 없음")

# ---- 4. 잔치 군중 짜임: 14 = 손님 8 · 기생 4 · 시중 2, 포졸·관속 없음 ----
func _cast_checks() -> void:
	var sb: Dictionary = crowd.crowds.byeon_banquet.spec
	var pb: Array = EventCrowd.plan(sb)
	var tags := {}
	var kinds := {}
	for m in pb:
		tags[m.tag] = int(tags.get(m.tag, 0)) + 1
		kinds[m.kind] = int(kinds.get(m.kind, 0)) + 1
	print("P2PREPTEST banquet tags=", tags, " kinds=", kinds)
	_check(pb.size() == 14, "잔치 군중 14명(%d)" % pb.size())
	_check(int(tags.get("guest", 0)) == 8 and int(tags.get("gisaeng", 0)) == 4 and int(tags.get("servant", 0)) == 2, "손님 8 · 기생 4 · 시중 2(%s)" % tags)
	_check(not kinds.has("pojol") and not kinds.has("official") and not kinds.has("py_clerk_guard"), "잔치 군중에 포졸·관속 없음(%s)" % kinds)
	var gk := {}
	for m in pb:
		if m.tag == "gisaeng":
			gk[m.kind] = true
			if not (String(m.kind) in ["gisaeng", "gisaeng_b", "gisaeng_c"]): gk["bad_" + m.kind] = true
	_check(gk.size() >= 3 and not gk.keys().any(func(k): return String(k).begins_with("bad_")), "기생은 기생 그림 세 색으로 돌아가며(%s)" % [gk.keys()])
	var seated_ok := true
	var seats: Dictionary = sb.seats
	for m in pb:
		if m.role != "sit": continue
		var on := false
		for st in seats.get(m.rect, []):
			if (m.home as Vector2).distance_to(Vector2(float(st[0]), float(st[1]))) < 0.01 and m.facing == String(st[2]): on = true
		seated_ok = seated_ok and on and m.has("seat")
	_check(seated_ok, "앉은 사람은 모두 잔칫상 방석 자리·그 방향")
	_check(pb.filter(func(m): return m.role == "sit").size() == 10, "앉은 사람 10(손님 8 + 대청 기생 2)")
	var bank_kinds: Array = sb.bank.map(func(b): return String(b[1]))
	_check(not bank_kinds.has("pojol") and not bank_kinds.has("official"), "잔치 bank에서 포졸·관속을 뺌")
	_check(_same(pb, EventCrowd.plan(sb)), "같은 seed → 같은 짜임")
	# 단오 군중(PART I)은 예전 길 그대로 — 짜임 없음
	_check(not (crowd.crowds.dano_market.spec as Dictionary).has("rect_roles") and EventCrowd.plan(crowd.crowds.dano_market.spec).size() == 28, "단오 군중 28 그대로(예전 배치 길)")

# ---- 5. 출두 반전: set_pose — 같은 사람(같은 노드·같은 자리), 자세만 ----
func _crowd_pose_checks() -> void:
	await _go(-3162.1, 213.5)
	await _fake({ case_id = "", cases = { namwon_chunhyang = { phase = "feast" } }, vars = {} })
	crowd.force("byeon_banquet", true)
	_cam(Vector2(-3162.1, 212.0), 58.0, 21.0, 32.0)
	await main._wait_frames(40)
	var mem: Array = crowd.members("byeon_banquet")
	var before := []
	for m in mem:
		before.append({ id = m.ch.get_instance_id() if m.ch != null else 0, pos = m.ch.position if m.ch != null else Vector3.INF, home = m.home, kind = m.kind, anim = m.ch.anim if m.ch != null else "" })
	var made: Array = mem.filter(func(m): return m.ch != null)
	_check(made.size() == 14, "8A에서 잔치 14명 모두 그림이 섬(%d)" % made.size())
	var sit_ok := true
	for m in mem:
		if m.role == "sit" and m.ch != null:
			var w = main.world
			var gy: float = (w.ground_at(m.home.x, m.home.y) if float(m.dy) > 0.0 else w.height_at(m.home.x, m.home.y)) + float(m.dy)
			sit_ok = sit_ok and m.ch.anim == "sit" and m.ch.has_anim("sit") and absf(m.ch.position.y - gy) < 0.001
	_check(sit_ok, "앉은 사람은 진짜 sit 그림 · 높이는 땅/대청 그대로(낮추기 없음)")
	await main._wait_frames(30)
	var serve_pos := {}
	for m in mem:
		if m.role == "serve" and m.ch != null: serve_pos[m.ch.get_instance_id()] = m.ch.position
	var n: int = crowd.apply_on_flag("byeon_banquet", "royal_inspector_reveal")
	await main._wait_frames(5)
	_check(n == 14, "출두 자세 바꾸기 14명(%d)" % n)
	var mem2: Array = crowd.members("byeon_banquet")
	var same := mem2.size() == before.size()
	var poses_ok := true
	for i in mini(mem2.size(), before.size()):
		var m: Dictionary = mem2[i]
		same = same and m.ch != null and m.ch.get_instance_id() == before[i].id and m.kind == before[i].kind and m.home == before[i].home
		var want := "kneel" if m.role == "sit" else "bow"
		poses_ok = poses_ok and m.ch.anim == want
	_check(same, "자세를 바꿔도 같은 사람(같은 노드 id·그림·자리 — 군중을 다시 짜지 않음)")
	_check(poses_ok, "sit → kneel · stand/serve/watch → bow")
	await main._wait_frames(60)
	var still := not serve_pos.is_empty()
	for m in mem2:
		if m.role == "serve" and m.ch != null and serve_pos.has(m.ch.get_instance_id()):
			still = still and m.has("pose") and m.ch.position.distance_to(serve_pos[m.ch.get_instance_id()]) < 0.3
	var p_now := {}
	for m in mem2:
		if m.role == "serve" and m.ch != null: p_now[m.ch.get_instance_id()] = m.ch.position
	await main._wait_frames(40)
	var moved := false
	for m in mem2:
		if m.role == "serve" and m.ch != null: moved = moved or m.ch.position.distance_to(p_now[m.ch.get_instance_id()]) > 0.001
	_check(still and not moved, "자세가 바뀐 시중·기생은 그 자리에 멈춤")
	_check(crowd.set_pose("byeon_banquet", "gisaeng", "kneel") == 4 and mem2.filter(func(m): return m.tag == "gisaeng" and m.ch.anim == "kneel").size() == 4, "tag로 고르기(기생 4 → kneel)")
	_check(crowd.set_pose("byeon_banquet", ["guest"], "bow") == 8, "배열 filter(손님 8 → bow)")
	_check(crowd.clear_pose("byeon_banquet") == 14 and mem2.filter(func(m): return m.role == "sit" and m.ch.anim == "sit").size() == 10, "clear_pose → 원래 동작")
	var ids_after: Array = crowd.members("byeon_banquet").map(func(m): return m.ch.get_instance_id())
	_check(ids_after == before.map(func(b): return b.id), "되돌린 뒤에도 같은 노드")
	crowd.force("byeon_banquet", null)
	await _fake(null)
	_cam_reset()

# ---- 6. 이야기 인물 set_pose(같은 인물·같은 노드) ----
func _story_pose_checks() -> void:
	var d = main.story
	d.spawn_actor("t_sar_a", "pojol", [-3168.7, 212.6], "right", "사령", "")
	d.spawn_actor("t_sar_b", "pojol", [-3155.5, 212.6], "left", "사령", "")
	d.actors.t_sar_a.spec["tags"] = ["saryeong"]
	d.actors.t_sar_b.spec["tags"] = ["saryeong"]
	var ia: int = d.actors.t_sar_a.ch.get_instance_id()
	var pa: Vector3 = d.actors.t_sar_a.pos
	var got: Array = d.set_pose("saryeong", "kneel")
	_check(got.size() == 2 and got.has("t_sar_a") and got.has("t_sar_b"), "이야기 인물 tag로 자세 바꿈(%s)" % [got])
	_check(d.actors.t_sar_a.ch.get_instance_id() == ia and d.actors.t_sar_a.pos == pa and d.actors.t_sar_a.ch.anim == "kneel", "같은 인물 노드·자리, 자세만 kneel")
	_check(d.set_pose("t_sar_*", "bow").size() == 2 and d.actors.t_sar_b.ch.anim == "bow", "glob으로 고르기(bow)")
	_check(d.set_pose(["t_sar_a"], "kneel") == ["t_sar_a"], "배열로 고르기")
	d.despawn_actor("t_sar_a"); d.despawn_actor("t_sar_b")

# ---- 7. 사령·포졸 고정 자리(춘향 데이터) — 공식 8A 양옆 줄, PART II 단계에서만 ----
func _guard_checks() -> void:
	var g: Array = ChData.guard_posts()
	var pl = JSON.parse_string(FileAccess.get_file_as_string("res://region_data/JL_NAMWON_UNBONG/placement_story_namwon_chunhyang.json"))
	var ok_at := true
	for a in g:
		ok_at = ok_at and pl.anchors.has(String(a.at)) and String(a.kind) == "pojol" and String(a.chr) == "CHR_HUM_016"
		ok_at = ok_at and String(a.when).find("ph('") >= 0 and String(a.when).find("dano") < 0
	_check(g.size() == 10 and ok_at, "사령 9(양옆 줄 8 + 선임) + 외삼문 포졸 1 — 공식 8A 앵커·pojol·PART II 단계 조건")
	var ids: Array = ChData.actors().map(func(a): return String(a.id))
	_check(ids.has("saryeong_w0") and ids.has("saryeong_senior") and ids.has("pojol_gate"), "춘향 인물 목록에 고정 자리 포함")
	var face_ok := true
	for a in g:
		if String(a.id).begins_with("saryeong_w"): face_ok = face_ok and a.facing == "right"
		elif String(a.id).begins_with("saryeong_e") or a.id == "saryeong_senior": face_ok = face_ok and a.facing == "left"
	_check(face_ok, "서쪽 줄은 동쪽(축)을, 동쪽 줄은 서쪽을 본다")

# ---- 8. PART II 소품: 닫혀 있으면 없음 · 단계 강제면 섬(실제 키트, placeholder 아님) ----
func _props_checks() -> void:
	for k in ["dais", "seat_screen", "hyeongteul", "chail", "jansang"]:
		_check(ChunKit.has_kind(k), "키트 story/chunhyang kind %s 있음" % k)
	var cart: Dictionary = load("res://kit/story/snow_road.gd").build({ kind = "cart", upright = true })
	_check(String(cart.node.name).find("cart") >= 0 or cart.node.get_child_count() > 0, "바로 선 술 수레(story/snow_road cart upright)")
	cart.node.free()
	var chail: Dictionary = ChunKit.build({ kind = "chail" })
	_check((chail.get("states", {}) as Dictionary).get("cloth", []) == ["SPREAD", "FURLED"] and chail.state_default.cloth == "SPREAD", "차일 천 상태 SPREAD(기본)/FURLED")
	chail.node.free()
	for id in P2_PROPS_OFFICE + P2_PROPS_FEAST:
		var it := _find_item(id)
		_check(not it.is_empty() and main.placement._resolve_placeholder(it).kit == it.kit, "%s: 실제 키트(placeholder 아님)" % id)
	await _go(-3162.1, 222.0)
	var all_off := true
	for id in P2_PROPS_OFFICE + P2_PROPS_FEAST: all_off = all_off and _off(id)
	_check(all_off, "PART II 닫힘(실제 상태) → PART II 소품 모두 없음")
	_check(not crowd.is_shown("byeon_banquet"), "PART II 닫힘 → 잔치 군중 없음")
	await _fake({ case_id = "", cases = { namwon_chunhyang = { phase = "office" } }, vars = {} })
	var on1 := true
	for id in P2_PROPS_OFFICE: on1 = on1 and _attached(id)
	_check(on1 and _off("ti_chail") and _off("ti_feast_w0"), "단계 office 강제 → 보계·교의·형틀·수레 있음, 차일·잔칫상 없음")
	_check(main.world.blocked(-3162.1, 209.0, 0.3), "보계는 막힘(충돌체)")
	await _fake({ case_id = "", cases = { namwon_chunhyang = { phase = "feast" } }, vars = {} })
	var on2 := true
	for id in P2_PROPS_FEAST: on2 = on2 and _attached(id)
	_check(on2 and _off("ti_hyeongteul"), "단계 feast 강제 → 보계·교의·차일·잔칫상 있음, 형틀 없음")
	_check(main.world.set_prop_state("ti_chail/cloth", "FURLED") and main.world.props.get_state("ti_chail/cloth") == "FURLED", "차일 FURLED로(8A 내려다보기용)")
	main.world.set_prop_state("ti_chail/cloth", "SPREAD")
	await _fake(null)
	var all_off2 := true
	for id in P2_PROPS_OFFICE + P2_PROPS_FEAST: all_off2 = all_off2 and _off(id)
	_check(all_off2, "실제 상태로 → 다시 모두 없음")

# ---------------------------------------------------------------------------
# 촬영(창 모드)
# ---------------------------------------------------------------------------
func _p2_shots() -> void:
	var want: Array = String(main.args.get("p2prepshot", "1")).split(",", false)
	if want.has("1") or want.is_empty(): want = ["poses", "looks", "banquet"]
	main.hour = 11.0; main._apply_time()
	await _wait_load()
	if "poses" in want: await _shot_poses()
	if "looks" in want: await _shot_looks()
	if "banquet" in want: await _shot_banquet()
	main._quit()

func _lineup(kinds: Array, anims: Array, origin: Vector2, dx: float, dz: float, facing: String) -> Array:
	var out := []
	for r in anims.size():
		for i in kinds.size():
			var ch := _stand_in(kinds[i], origin + Vector2(i * dx, r * dz), facing)
			ch.play(anims[r], true)
			ch.update_char(0.016, main.cam)
			out.append(ch)
	return out

# 공용 자세 한 장: 줄마다 idle · sit · bow · kneel, 칸마다 고을 사람 — 평소 걷기 시점(거리)과 8A 거리
func _shot_poses() -> void:
	var o := Vector2(-3150.0, 223.0)   # 관아 바깥마당 동쪽(빈터)
	await _go(o.x + 4.0, o.y + 6.0)
	main.player.visible = false
	var kinds := ["villager_m", "villager_f", "scholar", "elder", "farmer", "official", "pojol", "child_girl"]
	var tmp := _lineup(kinds, ["idle", "sit", "bow", "kneel"], o, 1.15, 2.2, "down")
	_cam(o + Vector2(4.0, 3.5), 38.0, 16.0, 34.0)
	await main._wait_frames(10)
	for c in tmp: c.update_char(0.016, main.cam)
	await _snap("01_pose_sheet_front")
	for c in tmp: c.facing = "left"; c.update_char(0.016, main.cam)
	await _snap("01b_pose_sheet_side")
	for c in tmp: c.facing = "down"; c.update_char(0.016, main.cam)
	_cam(o + Vector2(4.0, 3.5), 58.0, 21.0, 32.0)   # 8A와 같은 높이·거리
	await main._wait_frames(5)
	for c in tmp: c.update_char(0.016, main.cam)
	await _snap("01c_pose_sheet_8A_distance")
	for c in tmp: c.queue_free()
	_cam_reset()

func _shot_looks() -> void:
	var o := Vector2(-3150.0, 223.0)
	await _go(o.x + 3.0, o.y + 5.0)
	main.player.visible = false
	var sets := [
		["02_look_chunhyang_prison", ["chunhyang_prison"], ["idle", "kneel", "sit", "walk"]],
		["03_look_mongryong_beggar", ["mongryong_beggar"], ["idle", "walk", "talk", "mapae"]],
		["04_look_byeon", ["byeon"], ["idle", "talk", "sit", "bow"]],
		["05_look_gisaeng", ["gisaeng", "gisaeng_b", "gisaeng_c"], ["idle", "serve", "sit", "bow"]],
	]
	for st in sets:
		var tmp := []
		var kinds: Array = st[1]
		var anims: Array = st[2]
		for i in anims.size():
			for j in kinds.size():
				for fi in 2:
					var at := o + Vector2(i * 2.4 + fi * 1.0, j * 1.8)
					var ch := _stand_in(kinds[j], at, ["down", "left"][fi])
					ch.play(anims[i], true)
					tmp.append(ch)
		_cam(o + Vector2(4.0, (kinds.size() - 1) * 0.9 + 0.2), 30.0, 11.0 + kinds.size() * 1.5, 34.0)
		await main._wait_frames(8)
		for c in tmp: c.update_char(0.016, main.cam)
		await _snap(st[0])
		for c in tmp: c.queue_free()
	_cam_reset()

# 공식 8A: 잔치(feast 강제) + 사령 줄(대신 선 그림 — 이야기 인물 고정 자리와 같은 앵커) + 변학도 교의, 그다음 출두 반전(set_pose)
func _shot_banquet() -> void:
	var d = JSON.parse_string(FileAccess.get_file_as_string("res://region_data/JL_NAMWON_UNBONG/placement_story_namwon_chunhyang.json"))
	var an: Dictionary = {}
	for k in d.anchors: an[k] = Vector2(float(d.anchors[k].at[0]), float(d.anchors[k].at[1]))
	await _go(-3162.1, 213.5)
	main.player.visible = false
	await _fake({ case_id = "", cases = { namwon_chunhyang = { phase = "feast" } }, vars = {} })
	main.world.set_prop_state("ti_chail/cloth", "FURLED")
	crowd.force("byeon_banquet", true)
	var tmp := []
	for a in ChData.guard_posts():
		if String(a.id) == "pojol_gate": continue
		tmp.append(_stand_in("pojol", an[String(a.at)], String(a.facing)))
	var byeon := _stand_in("byeon", an.ch_byeon_seat, "down")
	byeon.position.y = main.world.ground_at(an.ch_byeon_seat.x, an.ch_byeon_seat.y) + 1.05
	byeon.play("sit", true)
	tmp.append(byeon)
	_cam(Vector2(-3162.1, 212.0), 58.0, 21.0, 32.0)
	await main._wait_frames(40)
	for c in tmp: c.update_char(0.016, main.cam)
	await _snap("06_8A_banquet_seated")
	print("P2PREPSHOT banquet crowd=", crowd.stats)
	# 출두: 같은 사람이 제자리에서 — 잔치 군중 apply_on_flag, 사령은 kneel, 변학도는 몸을 웅크림
	crowd.apply_on_flag("byeon_banquet", "royal_inspector_reveal")
	for c in tmp:
		if c != byeon: c.play("kneel", true)
	byeon.play("cower", true)
	await main._wait_frames(20)
	for c in tmp: c.update_char(0.016, main.cam)
	await _snap("07_8A_after_set_pose")
	# 가까이(10A 높이) — 앉음·꿇음이 읽히는지
	_cam(Vector2(-3162.1, 212.5), 32.0, 11.0, 34.0)
	await main._wait_frames(20)
	for c in tmp: c.update_char(0.016, main.cam)
	await _snap("07b_court_close_after")
	crowd.clear_pose("byeon_banquet")
	for c in tmp: c.play("idle", true)
	byeon.play("sit", true)
	await main._wait_frames(20)
	for c in tmp: c.update_char(0.016, main.cam)
	await _snap("06b_court_close_seated")
	main.world.set_prop_state("ti_chail/cloth", "SPREAD")
	_cam(Vector2(-3162.1, 212.0), 58.0, 21.0, 32.0)
	await main._wait_frames(20)
	for c in tmp: c.update_char(0.016, main.cam)
	await _snap("08_8A_chail_spread")
	# 점고·곤장(office): 형틀·보계·교의
	await _fake({ case_id = "", cases = { namwon_chunhyang = { phase = "office" } }, vars = {} })
	crowd.force("byeon_banquet", null)
	var ch := _stand_in("chunhyang_prison", an.ch_chunhyang_center, "up")
	ch.play("kneel", true)
	tmp.append(ch)
	_cam(Vector2(-3162.1, 212.0), 58.0, 21.0, 32.0)
	await main._wait_frames(30)
	for c in tmp: c.update_char(0.016, main.cam)
	await _snap("09_8A_office_hyeongteul")
	# 외삼문 동쪽 술 수레
	_cam(Vector2(-3146.5, 249.0), 36.0, 12.0, 34.0)
	await _go(-3150.0, 252.0)
	await main._wait_frames(20)
	await _snap("10_wine_cart_upright")
	for c in tmp: c.queue_free()
	await _fake(null)
	_cam_reset()
