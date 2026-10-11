# 춘향 준비(2a) 시험·촬영 — 조건부 배치(F-11) · 옥 · 오누이 흔적(우물·수수밭) · EventCrowd(C60)
#   시험(헤드리스):  --region=JL_NAMWON_UNBONG --preptest --notitle            → 끝 줄 PREPTEST PASS n / FAIL …
#   촬영·성능(창):   --region=JL_NAMWON_UNBONG --prepshot[=이름,…] --nostory --notitle --shotdir=shots/chunhyang_prep --savefile=user://chp_prep.json
#     이름: jail · bars12a · sorghum · well · dano1a · banquet8a · orijeong · fps (없으면 전부). fps는 1A·8A 프레임에서 군중 끔/켬/최대를 잰다.
#   상태는 placement_gate.fake(가짜 사건 단계·변수)로 바꾼다 — 실제 저장(progress)은 쓰지 않는다(시험 저장 파일만).
#   촬영에서는 아직 kind가 없어 placeholder로 지어진 차림(그네·씨름판·보계·교의·형틀·차일 자리)을 숨긴다 — 실제 모양이 아니므로.
extends RefCounted

const EventCrowd := preload("res://scripts/story/event_crowd.gd")
const STORY_UNIQUE := ["chunhyang", "mongryong", "mongryong_beggar", "bangja", "wolmae", "byeon", "hyangdan",
	"woochi", "chaekkwae", "yigyeom", "gwak", "story_girl", "story_boy", "ricecake_mother", "tiger", "wolsim", "thief", "courier", "courier_b", "courier_c"]
const PLACEHOLDER_IDS := ["ti_swing", "ti_ssireum", "ti_dais", "ti_seat_screen", "ti_hyeongteul", "ti_chail", "ti_wine_cart"]

var main
var gate
var crowd
var ok := 0
var fails: Array = []

func _init(m) -> void:
	main = m

func _check(cond: bool, what: String) -> void:
	if cond: ok += 1
	else:
		fails.append(what)
		print("PREPTEST check FAIL: ", what)

func _wait_load(maxf_frames := 1500) -> void:
	await main._wait_frames(5)
	var n := 0
	while main._loading and n < 6000:
		await main._wait_frames(1); n += 1
	n = 0
	while (main.world.stats.jobs > 0 or main.placement.busy()) and n < maxf_frames:
		await main._wait_frames(1); n += 1
	await main._wait_frames(3)

func _go(x: float, z: float) -> void:
	main.teleport(x, z)
	main.rig.update(0, main.player_pos, main.player.facing, null, true)
	await _wait_load()

func _entry(id: String):
	return main.placement.gated.get(id)

func _attached(id: String) -> bool:
	var e = _entry(id)
	return e != null and bool(e.attached) and not bool(e.get("off", false)) and (e.node as Node3D).is_inside_tree()

func _off(id: String) -> bool:
	var e = _entry(id)
	return e != null and bool(e.get("off", false)) and not (e.node as Node3D).is_inside_tree()

func _fake(f) -> void:
	gate.fake = f
	gate.refresh()
	await main._wait_frames(2)

func run() -> void:
	gate = main.placement.gate
	crowd = main.crowd
	if main.args.has("prepshot"): await _shots(); return
	await _wait_load()
	print("PREPTEST start case=%s gated=%d crowds=%s" % [main.story.case_id if main.story != null else "-", main.placement.stats.get("gated", 0), crowd.ids() if crowd != null else []])
	# ---- 0. 남원 오누이가 이 공간 사건(춘향 사건 코드는 아직 없다) ----
	_check(main.story != null and String(main.story.case_id) == "namwon", "도는 사건이 namwon")
	_check(int(main.placement.stats.get("gated", 0)) >= 40, "조건부 항목 40개 이상 읽음(%d)" % int(main.placement.stats.get("gated", 0)))
	# ---- A. F-11 — 단오 차림(when 거짓) 없음 → 단계가 서면 있음 → 다시 없음 ----
	await _go(-3297.0, 428.0)
	_check(_entry("ti_streamers_ground") != null, "단오 색천 항목이 놓임(조건부)")
	_check(_off("ti_streamers_ground"), "사건 단계 없음 → 단오 색천 없음")
	_check(_off("ti_yeot_stall"), "사건 단계 없음 → 엿판 없음")
	var stall_e = _entry("ti_yeot_stall")
	var stall_blk_before: bool = main.world.blocked(-3272.5, 425.0, 0.3)
	_check(not stall_blk_before, "꺼진 엿판 자리에 충돌체 없음")
	var ev0: int = gate.evals
	await main._wait_frames(30)
	_check(gate.evals == ev0, "아무것도 안 바뀌면 조건식을 다시 돌리지 않음(30프레임 동안 %d→%d)" % [ev0, gate.evals])
	await _fake({ case_id = "namwon", cases = { namwon_chunhyang = { phase = "dano" } }, vars = {} })
	_check(_attached("ti_streamers_ground"), "단계 dano → 단오 색천 있음")
	_check(_attached("ti_yeot_stall"), "단계 dano → 엿판 있음")
	_check(stall_e == null or main.world.blocked(-3272.5, 425.0, 0.3) or (stall_e.colliders as Array).is_empty(), "켜진 엿판 충돌체 돌아옴")
	await _fake({ case_id = "namwon", cases = { namwon_chunhyang = { phase = "feast" } }, vars = {} })
	_check(_off("ti_streamers_ground"), "단계 feast → 단오 색천 다시 없음")
	await _fake(null)
	_check(_off("ti_streamers_ground") and _off("ti_yeot_stall"), "실제 상태로 돌아오면 다시 없음")
	# 실제 변수 바뀜(progress.set_var) → 다음 프레임에 한 번만 다시 봄
	var Progress = load("res://scripts/region/progress.gd")
	var r0: int = gate.refreshes
	var old = Progress.get_var("CASE_NAMWON_CHUNHYANG_PART1_COMPLETE", false)
	Progress.set_var("CASE_NAMWON_CHUNHYANG_PART1_COMPLETE", not bool(old))
	await main._wait_frames(3)
	_check(gate.refreshes == r0 + 1, "변수가 바뀐 프레임에만 다시 봄(refresh %d→%d)" % [r0, gate.refreshes])
	Progress.set_var("CASE_NAMWON_CHUNHYANG_PART1_COMPLETE", old)
	await main._wait_frames(2)
	# ---- B. 옥: 늘 있음(when 없음) · 문 상태 ----
	await _go(-3172.0, 238.0)
	var props = main.world.props
	_check(props.has("ti_jail"), "옥이 배치에 있음(사건 없이)")
	var jail_item := _find_item("ti_jail")
	_check(not jail_item.is_empty() and not jail_item.has("when"), "옥 항목에 when 없음(늘 있는 시설)")
	var jrec: Dictionary = props._props.get("ti_jail", {})
	_check(not jrec.is_empty() and (jrec.node as Node3D).is_inside_tree(), "옥 노드가 장면에 있음")
	_check(props.get_state("ti_jail/gate") == "SEALED" and props.get_state("ti_jail/cell") == "SEALED", "옥 문·살문 기본 SEALED")
	var gx := -3175.0 + 5.0
	_check(main.world.blocked(gx, 229.5, 0.3), "닫힌 옥문은 막힘")
	_check(main.world.set_prop_state("ti_jail/gate", "OPEN") and props.get_state("ti_jail/gate") == "OPEN", "옥문 OPEN으로")
	_check(not main.world.blocked(gx, 229.5, 0.3), "열린 옥문은 지나감")
	_check(main.world.set_prop_state("ti_jail/cell", "OPEN") and props.get_state("ti_jail/cell") == "OPEN", "살문 OPEN으로")
	_check(not main.world.blocked(-3175.0, 230.05, 0.2), "열린 살문은 지나감")
	main.world.set_prop_state("ti_jail/gate", "SEALED"); main.world.set_prop_state("ti_jail/cell", "SEALED")
	_check(main.world.blocked(gx, 229.5, 0.3) and main.world.blocked(-3175.0, 230.05, 0.2), "다시 SEALED면 막힘")
	await _fake({ case_id = "", cases = {}, vars = {} })
	_check((jrec.node as Node3D).is_inside_tree(), "사건이 없어도 옥은 그대로")
	await _fake(null)
	# ---- C. 오누이 흔적: 우물·수수밭(F-10 전 임시) ----
	await _go(-3203.0, -338.0)
	_check(_off("nw_trace_well") and _off("nw_trace_sorghum") and _off("nw_trace_sorghum_red"), "오누이 사건이 돌면 정적 흔적은 꺼짐(사건 소품이 그림 — 겹치지 않음)")
	var st = main.story
	_check(st.props.has("p_well") and st.props.has("p_sorghum"), "오누이 사건 소품(우물·수수밭) 그대로")
	await _fake({ case_id = "namwon_chunhyang", cases = {}, vars = { CASE_NAMWON_COMPLETE = false } })
	_check(_attached("nw_trace_well"), "다른 사건 · 완료 전: 우물 있음")
	_check(_attached("nw_trace_sorghum") and _off("nw_trace_sorghum_red"), "완료 전: 수수밭 푸름")
	await _fake({ case_id = "namwon_chunhyang", cases = {}, vars = { CASE_NAMWON_COMPLETE = true } })
	_check(_attached("nw_trace_well"), "완료 뒤: 우물 남음")
	_check(_attached("nw_trace_sorghum_red") and _off("nw_trace_sorghum"), "완료 뒤: 수수밭 붉음")
	await _fake({ case_id = "", cases = {}, vars = { CASE_NAMWON_COMPLETE = true } })
	_check(_attached("nw_trace_well") and _attached("nw_trace_sorghum_red"), "사건 없는 때도 우물·붉은 수수밭")
	await _fake(null)
	_check(_off("nw_trace_well") and _off("nw_trace_sorghum_red"), "오누이가 다시 돌면 정적 흔적 꺼짐")
	# ---- D. EventCrowd ----
	_check(crowd != null and crowd.ids().has("dano_market") and crowd.ids().has("byeon_banquet"), "군중 프리셋 둘 선언")
	_check(not crowd.is_shown("dano_market") and not crowd.is_shown("byeon_banquet"), "지금은 둘 다 꺼짐(when 거짓)")
	var sd: Dictionary = crowd.crowds.dano_market.spec
	var sb: Dictionary = crowd.crowds.byeon_banquet.spec
	var pd: Array = EventCrowd.plan(sd)
	var pb: Array = EventCrowd.plan(sb)
	_check(pd.size() >= 18 and pd.size() <= 30, "dano_market 인원 high 범위(%d)" % pd.size())
	_check(pb.size() >= 10 and pb.size() <= 18, "byeon_banquet 인원 medium 범위(%d)" % pb.size())
	for dk in ["low", "medium", "high"]:
		var n: int = EventCrowd.plan(sd, dk).size()
		var rg: Array = EventCrowd.DENSITY[dk]
		_check(n >= int(rg[0]) and n <= int(rg[1]), "밀도 %s 인원 %d 범위 %s" % [dk, n, rg])
	_check(_same(pd, EventCrowd.plan(sd)), "같은 seed → 같은 배치")
	var sd2: Dictionary = sd.duplicate(true); sd2.seed = int(sd.seed) + 7
	_check(not _same(pd, EventCrowd.plan(sd2)), "다른 seed → 다른 배치")
	var bad := []
	var actor_ids: Array = main.story.actors.keys() if main.story != null else []
	for m in pd + pb:
		if not (String(m.kind) in EventCrowd.GENERIC) or String(m.kind) in STORY_UNIQUE: bad.append(m.kind)
		if not (String(m.role) in EventCrowd.ACTIONS): bad.append(m.role)
		if EventCrowd._excluded(sd.area if pd.has(m) else sb.area, m.home): bad.append("excluded@%s" % m.home)
	_check(bad.is_empty(), "군중은 generic 그림·정해진 동작만·빼는 곳 밖(%s)" % [bad])
	var sx: Dictionary = sd.duplicate(true); sx.bank = [["X", "chunhyang"], ["Y", "mongryong"], ["Z", "villager_m"]]
	var px: Array = EventCrowd.plan(sx)
	_check(px.all(func(m): return m.kind == "villager_m"), "이야기 인물 그림은 군중에서 빠짐")
	await _fake({ case_id = "", cases = { namwon_chunhyang = { phase = "dano" } }, vars = {} })
	_check(crowd.is_shown("dano_market") and not crowd.is_shown("byeon_banquet"), "단계 dano → 단오 군중만")
	await _fake({ case_id = "", cases = { namwon_chunhyang = { phase = "feast" } }, vars = {} })
	_check(not crowd.is_shown("dano_market") and crowd.is_shown("byeon_banquet"), "단계 feast → 잔치 군중만")
	await _fake(null)
	_check(not crowd.is_shown("dano_market") and not crowd.is_shown("byeon_banquet"), "실제 상태 → 둘 다 꺼짐")
	# LOD: 단오 군중을 켜고 광한루 앞 → 가까운 사람 그림·먼 사람 숨김 · 화면 밖 멈춤
	crowd.force("dano_market", true)
	await _go(-3290.0, 433.0)
	await main._wait_frames(20)
	var s0: Dictionary = crowd.stats
	print("PREPTEST crowd near stats=", s0)
	_check(int(s0.shown) > 0 and int(s0.active) > 0, "가까운 군중은 그려지고 움직임(%s)" % s0)
	_check(int(s0.hidden) > 0, "60m 밖 군중은 숨김(%s)" % s0)
	_check(int(s0.frozen) + int(s0.reduced) > 0, "화면 밖·중간 거리 군중은 멈추거나 덜 갱신(%s)" % s0)
	var mem: Array = crowd.members("dano_market")
	var story_ids_hit := mem.filter(func(m): return actor_ids.has(String(m.get("id", ""))))
	_check(story_ids_hit.is_empty() and mem.size() == pd.size(), "강제 켬 인원 = 계획 인원(%d), 이야기 인물 없음" % mem.size())
	await _go(-3160.0, 120.0)
	await main._wait_frames(10)
	_check(int(crowd.stats.shown) == 0 and int(crowd.stats.hidden) == mem.size(), "멀리 가면 모두 숨김(%s)" % crowd.stats)
	crowd.force("dano_market", null)
	await main._wait_frames(2)
	_check(not crowd.is_shown("dano_market"), "강제 풀면 when대로(꺼짐)")
	if fails.is_empty(): print("PREPTEST PASS %d" % ok)
	else: print("PREPTEST FAIL %d/%d — %s" % [fails.size(), ok + fails.size(), "; ".join(fails)])
	main._quit()

func _find_item(id: String) -> Dictionary:
	for f in main.placement.files():
		var d = JSON.parse_string(FileAccess.get_file_as_string(f))
		if d is Dictionary:
			for it in d.get("items", []):
				if it is Dictionary and String(it.get("id", "")) == id: return it
	return {}

static func _same(a: Array, b: Array) -> bool:
	if a.size() != b.size(): return false
	for i in a.size():
		if a[i].home != b[i].home or a[i].kind != b[i].kind or a[i].role != b[i].role or a[i].facing != b[i].facing: return false
	return true

# ---------------------------------------------------------------------------
# 촬영·성능(창 모드)
# ---------------------------------------------------------------------------
func _dir() -> String:
	return main._abs(String(main.args.get("shotdir", "shots/chunhyang_prep")))

func _snap(nm: String) -> void:
	await main._wait_frames(45)
	main._save(_dir().path_join(nm + ".png"))

func _hide_placeholders() -> void:
	for id in PLACEHOLDER_IDS:
		var e = _entry(id)
		if e != null: main.world.set_static_enabled(e, false)

func _cam_reset() -> void:
	main.rig.shot = null; main.rig.override = null; main.rig.focus = null
	main.set_occ_script(null); main.set_cine_sharp(false)

func _cam(focus: Vector2, pitch: float, dist: float, fov: float) -> void:
	main.rig.shot = null
	main.rig.focus = { x = focus.x, z = focus.y }
	main.rig.override = { pitch = pitch, distance = dist, fov = fov, lookAhead = 0.0, aimZ = 0.0 }
	main.rig.update(0, main.player_pos, main.player.facing, null, true)
	main.set_cine_sharp(true)

func _shot_cam(pos: Array, look: Array, fov: float) -> void:
	var w = main.world
	var p := Vector3(float(pos[0]), w.height_at(float(pos[0]), float(pos[2])) + float(pos[1]), float(pos[2]))
	var l := Vector3(float(look[0]), w.height_at(float(look[0]), float(look[2])) + float(look[1]), float(look[2]))
	main.rig.focus = null; main.rig.override = null
	main.rig.shot = { pos = p, look = l, fov = fov }
	# 각본 시점(사건 컷과 같이): 흐림 띠를 끄고 카메라 앞 점무늬 비우기도 끈다(살·처마가 그대로 보이게)
	main.set_occ_script({ focus = l, r = 0.0, near = 0.0 })
	main.set_cine_sharp(true)

func _stand_in(kind: String, at: Vector2, facing: String) -> Node3D:
	var b: String = crowd._ensure_bank(kind)
	var ch := SpriteChar.new(b)
	main.scene_vp.add_child(ch)
	ch.set_silhouette(false)
	ch.facing = facing
	ch.position = Vector3(at.x, main.world.height_at(at.x, at.y), at.y)
	ch.update_char(0.016, main.cam)
	return ch

func _measure(sec: float) -> Dictionary:
	await _wait_load(600)
	await main._wait_frames(180)   # 짓기·셰이더 준비가 끝난 뒤(순간이동 직후 멈춤을 재지 않게)
	var t := 0.0; var fr := 0; var worst := 0.0
	var t0 := Time.get_ticks_usec()
	while t < sec:
		await main._wait_frames(1)
		var now := Time.get_ticks_usec()
		var dt := (now - t0) / 1e6
		t0 = now
		t += dt; fr += 1; worst = maxf(worst, dt)
	return { fps = fr / maxf(t, 0.001), worst_ms = worst * 1000.0, frames = fr, crowd = crowd.stats.duplicate(),
		draws = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME) }

func _shots() -> void:
	var want: Array = String(main.args.get("prepshot", "1")).split(",", false)
	if want.has("1") or want.is_empty(): want = ["jail", "bars12a", "sorghum", "well", "dano1a", "banquet8a", "orijeong", "fps"]
	main.hour = 11.0; main._apply_time()
	await _wait_load()
	_hide_placeholders()
	if "jail" in want:
		await _go(-3172.0, 239.0)
		main.player.visible = true
		_cam(Vector2(-3174.0, 231.0), 40.0, 22.0, 34.0)
		await _snap("01_jail_exterior")
		_cam(Vector2(-3174.0, 230.0), 38.0, 16.0, 30.0)   # 평소 걷기 시점(남→북)
		main.teleport(-3175.0, 233.2); main.player.facing = "up"
		await _snap("01b_jail_game_view")
	if "bars12a" in want:
		await _go(-3173.0, 233.4)
		main.player.visible = false
		var si := _stand_in("villager_f", Vector2(-3175.2, 228.0), "down")   # 춘향 대신(그림 없음 — 구도만)
		_shot_cam([-3174.4, 1.45, 233.6], [-3175.2, 1.0, 228.2], 40.0)
		await _snap("02_jail_12A_bars")
		si.queue_free()
		main.player.visible = true
		_cam_reset()
	if "sorghum" in want or "well" in want:
		await _go(-3203.0, -338.0)
		main.player.visible = false
		await _fake({ case_id = "", cases = {}, vars = { CASE_NAMWON_COMPLETE = false } })
		_cam(Vector2(-3201.0, -346.0), 36.0, 17.0, 34.0)
		if "sorghum" in want: await _snap("03_sorghum_before_complete")
		await _fake({ case_id = "", cases = {}, vars = { CASE_NAMWON_COMPLETE = true } })
		if "sorghum" in want: await _snap("04_sorghum_after_complete")
		if "well" in want:
			_cam(Vector2(-3207.8, -343.8), 40.0, 12.0, 32.0)
			await _snap("05_well")
		await _fake(null)
		main.player.visible = true
		_cam_reset()
	if "dano1a" in want:
		await _go(-3250.0, 447.0)   # 광한루 footprint 밖(안이면 지붕 잘라 보기가 켜진다) — 군중 C구역
		main.player.visible = false
		await _fake({ case_id = "", cases = { namwon_chunhyang = { phase = "dano" } }, vars = {} })
		_hide_placeholders()
		crowd.force("dano_market", true, "high")
		_shot_cam([-3216.0, 18.0, 456.0], [-3290.0, 4.0, 446.0], 38.0)
		await main._wait_frames(30)
		await _snap("06_dano_market_1A")
		print("PREPSHOT dano 1A crowd=", crowd.stats)
		crowd.force("dano_market", null)
		await _fake(null)
		_cam_reset()
	if "banquet8a" in want:
		await _go(-3162.1, 213.5)   # 안마당 가운데(흐림 초점이 마당에 오게, 그림은 숨김)
		main.player.visible = false
		await _fake({ case_id = "", cases = { namwon_chunhyang = { phase = "feast" } }, vars = {} })
		_hide_placeholders()
		crowd.force("byeon_banquet", true, "medium")
		_cam(Vector2(-3162.1, 212.0), 58.0, 21.0, 32.0)
		await main._wait_frames(30)
		await _snap("07_byeon_banquet_8A")
		print("PREPSHOT banquet 8A crowd=", crowd.stats)
		crowd.force("byeon_banquet", null)
		await _fake(null)
		_cam_reset()
	if "orijeong" in want:
		await _go(-3212.3, 2.0)
		main.player.visible = true
		main.player.facing = "up"
		_cam(Vector2(-3212.3, -6.0), 24.0, 22.0, 36.0)
		await _snap("08_orijeong_farewell_5A")
		_cam_reset()
	if "fps" in want: await _fps()
	main._quit()

func _fps() -> void:
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var res := []
	# 1A(단오) — 끔 / high(계획 28) / 30(상한)
	await _go(-3250.0, 447.0)
	main.player.visible = false
	await _fake({ case_id = "", cases = { namwon_chunhyang = { phase = "dano" } }, vars = {} })
	_hide_placeholders()
	crowd.force("dano_market", false)
	_shot_cam([-3216.0, 18.0, 456.0], [-3290.0, 4.0, 446.0], 38.0)
	for c in ["off", "high", "30", "off"]:
		if c == "off": crowd.force("dano_market", false)
		else: crowd.force("dano_market", true, c)
		var r := await _measure(6.0)
		r.frame = "1A"; r.crowd_spec = "dano_market:" + c; r.count = crowd.members("dano_market").size() if c != "off" else 0
		res.append(r); print("PREPFPS ", JSON.stringify(r))
	crowd.force("dano_market", false)
	# 평소 걷기 시점(단오 마당 가운데) — high
	_cam_reset()
	await _go(-3292.0, 436.0)
	for c in ["off", "high", "off"]:
		if c == "off": crowd.force("dano_market", false)
		else: crowd.force("dano_market", true, c)
		var r := await _measure(6.0)
		r.frame = "walk"; r.crowd_spec = "dano_market:" + c; r.count = crowd.members("dano_market").size() if c != "off" else 0
		res.append(r); print("PREPFPS ", JSON.stringify(r))
	crowd.force("dano_market", null)
	# 8A(잔치) — 끔 / medium(계획 14) / 18(상한)
	await _go(-3162.1, 213.5)
	await _fake({ case_id = "", cases = { namwon_chunhyang = { phase = "feast" } }, vars = {} })
	_hide_placeholders()
	_cam(Vector2(-3162.1, 212.0), 58.0, 21.0, 32.0)
	for c in ["off", "medium", "18", "off"]:
		if c == "off": crowd.force("byeon_banquet", false)
		else: crowd.force("byeon_banquet", true, c)
		var r := await _measure(6.0)
		r.frame = "8A"; r.crowd_spec = "byeon_banquet:" + c; r.count = crowd.members("byeon_banquet").size() if c != "off" else 0
		res.append(r); print("PREPFPS ", JSON.stringify(r))
	crowd.force("byeon_banquet", null)
	await _fake(null)
	var f := FileAccess.open(_dir().path_join("fps.json"), FileAccess.WRITE)
	if f != null: f.store_string(JSON.stringify(res, " ")); f.close()
