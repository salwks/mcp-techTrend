# 메인 서장 「이겸의 수상한 편지」(main_p1) — 첫 15분의 연출·판정(재기획 3단계). 데이터: main_p1_data.gd
#   OP00 = 서장 프롤로그 「이겸과 제자의 어느 날」(거처 이전 4~7단계 — 새 게임만, 약 57초, 건너뛰기 Esc·Space·Enter, 처음 0.5초는 받지 않음):
#     INTRO_01 마당 와이드·다가감(대사 없음) · 02 투샷 S1.0 P00-B 앞 세 줄 · 03 가깝게 — 붓을 건네려다 손의 먹을 닦음 · 04 기록책을 서안에 펴 둠 → 펼친 쪽 첫 줄 내려다봄(약 2.9초) → 페이드·정적 →
#     이겸 없는 같은 마당 → 문 쪽 → 0.25초 dip으로 방 안 → “스승님은 어디로 가신 걸까.” → 조작. 옛 9초 여는 장면·“본 것은 본 대로” VO는 없앴다.
#     + 승인 연출 E1~E7(2026-10-18): 검은 화면 두드림 · 엿장수 · 소리 먼저 끊김 · 바람뿐 · 번진 기록지 끼움 컷 · 대답 없는 두드림 · 심부름꾼의 빠른 두드림(아래 _e2_loop 위 설명)
#   조사 CAM_OBJECT 0.35 진입·복귀 / 편지 0.4 / OP01 재기획 OP-04: 0–2 상승 · 2–4.5 요천·광한루 쪽 리프레이밍 · 4.5–8.5 「설화록」 · 8.5–9.5 사라짐
#     (구례 길 장승 어귀 — 조작은 막지 않는다. 다른 길로 가도 놓치지 않게: 거처에서 160m 넘게 · 나루 30m 안).
#   이야기 인물 대화는 2단계 대화 구도(CAM_TALK_2 0.55 / 복귀 0.45 — story_director·talk_frame)를 그대로 쓴다.
#   튜토리얼은 실제 행동으로만 끝난다(scripts/story/onboarding.gd CORE + 이 사건의 once 호출).
# 시험·기록: FIRST15 줄(로그) — control(새 게임 → 조작 반환 초) · step · title · waypoint.
extends RefCounted

const D := preload("res://story/main_p1/main_p1_data.gd")
const Docs := preload("res://scripts/story/documents.gd")
const Progress := preload("res://scripts/region/progress.gd")
const TitleMenu := preload("res://scripts/story/title_menu.gd")
const Sound := preload("res://scripts/audio/sound.gd")   # 프롤로그 E1~E7 — 작은 소리·높낮이

const ROOM := ["ledger", "shoes", "brush"]
const KNOCK_AFTER := 6.0       # 첫 조사 뒤 문 두드림까지(조작 중 — 한가한 시간만 센다)
const KNOCK_NEAR := 40.0       # 거처에서 이보다 멀면 돌아올 때까지 미룬다
const OBJ_IN := 0.35           # CAM_OBJECT 진입·복귀(첫15 P00-A)
const LETTER_IN := 0.4         # 편지 조사(첫15 P01-A)
const TITLE_AT_M := 10.0      # 장승 어귀(title_view)에서 이만큼 안이면 제목(거처 이전 — 첫15 '거처 밖 4m'를 대신함)
const TITLE_FAR_M := 160.0    # 다른 길로 가도: 거처에서 이보다 멀어지면(장승 어귀는 거처에서 곧장 143m — 그보다 멀리)
const TITLE_NARU_M := 30.0    # 또는 나루에서 이만큼 안이면
const PRO_SKIP_GUARD := 0.5   # 새 게임을 고른 Enter·Space가 건너뛰기로 읽히지 않게 처음 이만큼은 받지 않는다
const PRO_PAST := 0.15        # 지난날 색감(post.past — 옛 짧은 기억 0.45보다 훨씬 옅게, 화면 거르개처럼 보이지 않게)

var d
var S:
	get: return d.S
var control_t := -1.0          # 시험 기록: 새 게임 → 조작 반환(초)
var prologue_t: Array = []     # 시험 기록: 프롤로그 박자 [이름, 프롤로그 시작부터 초]
var prologue_played := false   # 이번 실행에서 프롤로그를 틀었나(시험)
var _skip_ok_at := 0.0
var _pro_nodes := {}           # 프롤로그 동안만 있는 소품 노드(지난날 기록지·기록책) — 끝나면 지운다
var _migrate_to = null         # 옛 거처 안 저장을 옮김: 아직 플레이어를 옮기지 않았으면 새 자리(Vector2)
var migrated := false          # 시험 기록
var op00_skipped := false
var title_running := false
var title_t := []              # 시험 기록: 제목 연출 단계별 시각
var steps_log: Array = []      # 시험 기록: [단계, 시각]
var _knock_t := -1.0

# ---- 프롤로그 승인 연출 E1~E7(2026-10-18 사용자 결정 — prologue_v2_existing_flow_eval.md v1.1. 액자판은 채택하지 않음) ----
#   E1 검은 화면 느린 두드림 · E2 지난 오후 먼 엿장수 가위(임시 소리) · E3 소리가 그림보다 0.3초 먼저 끊김 · E4 지금 마당은 바람뿐 ·
#   E5 이슬에 번진 기록지 끼움 컷 1.2초 + 마른 벼루 · E6 대답 없는 두드림 · E7 심부름꾼의 빠른 두드림
var _e2_on := false            # E2 지난 오후 바탕 소리 도는 중
var _pro_live := false         # 프롤로그가 아직 건너뛰지 않고 도는 중(늦게 오는 소리 타이머가 방 안에서 울리지 않게)
var _pt0 := 0.0                # 기록 기준(프롤로그 시작)

func _init(director) -> void:
	d = director

func flag(k: String, v = true) -> void:
	S.flags[k] = v; d.runner.log_line("flag", [k, v]); d.mark_dirty()

func f(k: String) -> bool: return S.is_flag(k)

func _now() -> float: return Time.get_ticks_msec() / 1000.0

func _log(step: String) -> void:
	steps_log.append([step, snappedf(_now(), 0.01)])
	printerr("FIRST15 step %s t=%.2f" % [step, _now()])

func room_seen() -> int:
	var n := 0
	for k in ROOM:
		if S.has_clue(k): n += 1
	return n

# ---------------------------------------------------------------------------
# 들머리 — 새 게임(OP00) / 옛 저장 합류(JOIN)
# ---------------------------------------------------------------------------
# 다른 사건을 이미 지난 저장(오누이·춘향 진행이 있음)은 새 게임이 아니다 — 여는 장면 없이 합류(추가 지시 2)
func is_joiner() -> bool:
	for id in Progress.data().cases:
		if String(id) != "main_p1" and not (Progress.case_state(String(id)) as Dictionary).is_empty(): return true
	return bool(Progress.get_var("CASE_NAMWON_COMPLETE", false))

func open() -> void:
	if is_joiner(): await join(); return
	await op00()

# 건너뛸 수 있는 기다림(Esc·Space·Enter — onboarding.skip). 건너뛰었으면 true
func _sw(sec: float) -> bool:
	var ob = d.onboard
	if ob == null: await d.wait(sec); return false
	if d.ui.auto and not d.ui.auto_real: sec = minf(sec, 0.05)
	var t := 0.0
	while t < sec:
		if ob.skip and _now() < _skip_ok_at: ob.skip = false   # 새 게임을 고른 키가 건너뛰기로 읽히지 않게(프롤로그 처음 0.5초)
		if ob.skip: return true
		await d.get_tree().process_frame
		t += d.get_process_delta_time() / maxf(Engine.time_scale, 0.01)
	return ob.skip

func _cam(spec, sec: float) -> void:
	d.camera(spec)
	d.main.rig.glide(sec)

func _mid(a: String, b: String) -> Array:
	var p: Vector2 = d.anchor(a); var q: Vector2 = d.anchor(b)
	return [(p.x + q.x) * 0.5, (p.y + q.y) * 0.5]

# 새 게임 공통: 거처 국면·시각·기록책·엽전 — 프롤로그를 보든 건너뛰든, 프롤로그가 없는 실행이든 같다
func _home_setup() -> void:
	S.phase = "home"; d.on_phase()
	d.set_hour(9.5); d.set_weather("clear")
	d.give("ITM_TOOL_009", 1, true); d.give(D.COIN, 12, true)
	flag("START_AT_IEGYEOM_HOME")

# 프롤로그는 시작 메뉴에서 '새 게임'을 고른 바로 그 실행에서만 튼다 — 옛 저장·이어 하기·불러오기에는 절대 끼지 않는다
func _fresh_new_game() -> bool:
	return TitleMenu.new_game_t0 > 0 and Time.get_ticks_msec() - TitleMenu.new_game_t0 < 30000

# OP00 — 새 게임: 서장 프롤로그(아래) → 방 안 조작. 시작 메뉴를 거치지 않은 실행(시험 --storytest 등)은 프롤로그 없이 방 안에서 바로
func op00() -> void:
	var t0 := _now()
	_home_setup()
	if _fresh_new_game() and d.main.get("args") != null and not d.main.args.has("noprologue"):
		await prologue()
	else:
		d.teleport_to("home_start", "up")
		d.camera(null)
		d.main.rig.update(0, d.main.player_pos, d.main.player.facing, null, true)
		d.ui.fade(false, 0.25)
		flag("OP00_DONE")
	var base: float = float(TitleMenu.new_game_t0) / 1000.0 if TitleMenu.new_game_t0 > 0 else t0
	control_t = _now() - base
	printerr("FIRST15 control %.2f s (op00 %.2f s, prologue=%s skipped=%s)" % [control_t, _now() - t0, prologue_played, op00_skipped])
	_log("op00_control")
	Progress.checkpoint("새 게임")   # 첫 조작권 반환 즉시 체크포인트(첫15 OP00)
	d.ui.caption("이겸의 방을 살펴보자", 3.0)   # 목표 문구 3초(첫15 OP00) — 뒤로는 기록책 '아직 모르는 것'에 남는다

# ---------------------------------------------------------------------------
# 서장 프롤로그 「이겸과 제자의 어느 날」 — 이겸이 사라지기 전의 평범한 오후(인게임 컷: 3D 땅 + 2D 인물 + 사선 카메라).
#   대사: S1.0 P00-B 그대로(이겸 셋 + 제자 선택 ① 고정). 연출 우선순위: S1.0 — 이겸이 젖은 기록지를 말린다 · 붓을 건네려다 손의 먹을 본다.
#   지시: 제자가 고개를 든다 · 작게 웃는다 · 기록책을 서안에 두고 → 이겸 없는 같은 마당 → 방 안. 「며칠 후」 자막 없음.
#   자막 머묾 = 1.2초 + 음절(공백 뺌) ÷ 7 — 들어옴·나감 0.35초씩을 빼고 0.5초 + 음절/7초를 온전히 읽는다(OP00 VO와 같은 빠르기).
#   동작은 있는 그림만: 이겸 kneel·read·walk·talk·bow·idle, 제자(플레이어) sit·idle. 새 동작 체계 없음.
# ---------------------------------------------------------------------------
static func line_sec(text: String) -> float:
	return 1.2 + float(text.replace(" ", "").length()) / 7.0

func _say_cap(who: String, text: String) -> float:
	var sec := line_sec(text)
	d.ui.caption("%s  “%s”" % [who, text], sec)
	return sec

func _beat(nm: String, p0: float) -> void:
	prologue_t.append([nm, snappedf(_now() - p0, 0.01)])
	printerr("FIRST15 prologue %s t=%.2f" % [nm, _now() - p0])

func _pro_prop(key: String, params: Dictionary, at: String, dy: float, ry := 0.0) -> void:
	var a: Vector2 = d.anchor(at)
	var n = d._build_prop({ "kit": "story/clue", "params": params, "ry": ry, "dy": dy }, a)
	if n != null: _pro_nodes[key] = n

func _pro_show(key: String, on: bool) -> void:
	var n = _pro_nodes.get(key)
	if n != null and is_instance_valid(n): n.visible = on

# 펼친 기록책(프롤로그 INTRO_04) — 표지 위 두 쪽: 왼쪽은 빈 쪽, 오른쪽은 문서 비교의 '스승의 옛 기록'(main_p1_data documents.old_record)을
#   documents.gd의 같은 그리기(draw_doc)로 그린 쪽. 새 동작·연출 체계 없이 소품 하나와 카메라 값만.
const BOOK_FIRST := "구월 열이틀 맑음"   # 옛 기록 첫 줄(D.documents().old_record.cols[0])
const BOOK_PAGE := 0.24                  # 쪽 너비(m) — 높이는 문서 aspect(1.36). 서안 키트의 펼친 책(0.54×0.34)을 덮는 크기
const BOOK_DY := 0.49 + 0.335            # 마당 서안(p_yard_desk dy 0.49) 상판 위
const BOOK_DZ := 0.02                    # 서안 키트 책 자리(z +0.02)
var _page_drawer = null                   # documents.gd 그리기(트리 밖 — 프롤로그가 끝나면 지운다)

func _book_page_at() -> Vector3:
	var a: Vector2 = d.anchor("pro_desk")
	var x := a.x + BOOK_PAGE * 0.5
	return Vector3(x, d._prop_ground(a) + BOOK_DY + 0.014, a.y + BOOK_DZ)

func _pro_open_book() -> void:
	var spec: Dictionary = D.documents().old_record
	var asp := float(spec.get("aspect", 1.36))
	var W := 640; var H := int(W * asp)
	var root := Node3D.new(); root.name = "pro_open_book"
	d._props_root.add_child(root)
	var vp := SubViewport.new()
	vp.size = Vector2i(W, H); vp.disable_3d = true; vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var ex = load("res://scripts/story/documents.gd").new()
	ex.d = d
	ex._font = preload("res://scripts/ui_fonts.gd").main()
	ex._fibers["old_record"] = ex._make_fibers(spec, int(spec.get("seed", 3161)))
	_page_drawer = ex
	var cv := Control.new()
	cv.size = Vector2(W, H)
	cv.draw.connect(func(): ex.draw_doc(cv, spec, "old_record", Rect2(Vector2.ZERO, Vector2(W, H)), float(W) / 360.0))
	vp.add_child(cv)
	var top: Vector3 = _book_page_at()
	var a: Vector2 = d.anchor("pro_desk")
	var ph := BOOK_PAGE * asp
	var base := top.y - 0.014
	root.global_position = Vector3(a.x, base, a.y + BOOK_DZ)
	var cover := MeshInstance3D.new()   # 누런 표지(두 쪽 아래 조금 넓게)
	var cb := BoxMesh.new(); cb.size = Vector3(BOOK_PAGE * 2.0 + 0.08, 0.008, ph + 0.04); cover.mesh = cb
	var cm := StandardMaterial3D.new(); cm.albedo_color = Color("#b89a6a"); cm.roughness = 0.9; cover.material_override = cm
	cover.position = Vector3(0, 0.004, 0)
	root.add_child(cover)
	for side in [-1, 1]:
		var pg := MeshInstance3D.new()
		var pm := PlaneMesh.new(); pm.size = Vector2(BOOK_PAGE, ph); pg.mesh = pm
		var mm := StandardMaterial3D.new(); mm.roughness = 0.95
		if side > 0:
			mm.albedo_texture = vp.get_texture()
			mm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		else:
			mm.albedo_color = Color(spec.get("paper", {}).get("base", "#e8dcbc"))
		pg.material_override = mm
		pg.position = Vector3(side * BOOK_PAGE * 0.5, 0.0095 + (0.001 if side > 0 else 0.0), 0)
		root.add_child(pg)
	_pro_nodes["book"] = root

# 지난날 붓(INTRO_03) — 이겸이 제자에게 내미는 붓 한 자루. 새 동작 없이 소품 자리·방향만 옮긴다(2026-10-17 결정 3 (가)).
#   방 안 붓걸이의 '끝이 갈라진 붓'과 같은 물건(조사 문구 "그날 건네주시려던 붓이다…"). 인물 그림(약 2m)에 맞춰 실물보다 조금 크게
const BRUSH_LEN := 0.5
func _pro_brush() -> Node3D:
	var root := Node3D.new(); root.name = "pro_brush"
	d._props_root.add_child(root)
	var shaft := MeshInstance3D.new()
	var sm := CylinderMesh.new(); sm.top_radius = 0.022; sm.bottom_radius = 0.026; sm.height = BRUSH_LEN; sm.radial_segments = 8
	shaft.mesh = sm
	var wm := StandardMaterial3D.new(); wm.albedo_color = Color("#7a5634"); wm.roughness = 0.8; shaft.material_override = wm
	shaft.rotation_degrees = Vector3(0, 0, -90)   # 붓대가 +x(붓끝 쪽)로 눕는다
	root.add_child(shaft)
	var tip := MeshInstance3D.new()
	var tm := CylinderMesh.new(); tm.top_radius = 0.034; tm.bottom_radius = 0.0; tm.height = 0.13; tm.radial_segments = 8
	tip.mesh = tm
	var im := StandardMaterial3D.new(); im.albedo_color = Color("#1b1714"); im.roughness = 0.9; tip.material_override = im
	tip.rotation_degrees = Vector3(0, 0, -90)
	tip.position = Vector3(BRUSH_LEN * 0.5 + 0.05, 0, 0)
	root.add_child(tip)
	_pro_nodes["brush"] = root
	return root

# 붓을 자리에: 이겸 손 높이에서 제자 쪽(dir)으로 reach만큼. 카메라 쪽으로 조금 앞(인물 그림 앞에 보이게)
func _brush_at(n: Node3D, reach: float, lift: float, sec: float) -> void:
	var ig = d.actors.get("yigyeom_past")
	if n == null or ig == null: return
	var a := Vector2(ig.pos.x, ig.pos.z)
	var b := Vector2(d.main.player_pos.x, d.main.player_pos.z)
	var dir := (b - a).normalized()
	var p := a + dir * reach
	var y: float = d.world.height_at(a.x, a.y) + lift
	var to := Vector3(p.x, y, p.y + 0.42)
	var yaw := -atan2(dir.y, dir.x)
	if sec <= 0.0:
		n.global_position = to; n.rotation = Vector3(0, yaw, deg_to_rad(8.0)); return
	var tw := n.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(n, "global_position", to, sec)
	tw.parallel().tween_property(n, "rotation", Vector3(0, yaw, deg_to_rad(8.0)), sec)

# 펼친 쪽을 내려다보는 자리(위에서 조금 남쪽 — 기본 yaw 0이라 쪽 위가 화면 위)
func _look_page(sec: float) -> void:
	var p: Vector3 = _book_page_at()
	d.main.rig.focus = { x = p.x, z = p.z, y = p.y - 0.9 }
	d.main.rig.override = { "pitch": 74.0, "distance": 1.05, "fov": 30.0 }
	d.main.rig.glide(sec)

func _story_prop(id: String, on: bool) -> void:
	var rec = d.props.get(id)
	if rec != null and rec.get("node") != null and is_instance_valid(rec.node): rec.node.visible = on

# 플레이어(제자)를 평상 위에 앉힌다 — 컷 동안 플레이어 이동은 이야기가 쥐고 있어(owns_player) 높이·자세가 그대로 남는다
func _seat_player(at: String, h: float, facing: String) -> void:
	var p: Vector2 = d.anchor(at)
	d.main.player_pos = Vector3(p.x, d.world.height_at(p.x, p.y) + h, p.y)
	d.main.player.position = d.main.player_pos
	d.main.player.facing = facing
	d.main.player.play("sit", true)

# 프롤로그 소리(기록 줄 FIRST15 sfx — 시각표의 '첫 소리'용)
func _tsfx(id: String, db := 0.0, pitch := 1.0, at = null) -> void:
	printerr("FIRST15 sfx %s t=%.2f" % [id, _now() - _pt0])
	if at != null and db == 0.0 and pitch == 1.0: d.sfx(id, at); return
	d.sfx_cue.emit(id)
	Sound.play(id, { "db": db, "pitch": pitch })

# E1·E6 느린 두 번 두드림(같은 knock.wav를 낮고 느리게 — 두 번 사이 약 0.53초) · E7 빠른 여러 번
func _knock_slow() -> void: _tsfx("knock", -2.0, 0.6)

# E2 지난 오후 바탕(임시): 먼 엿장수 가위 '찰칵, 찰칵'(cup_clink 높게·작게 — 임시 소리) + 새·개울을 이어 튼다(한 번 틀고 끝나는 소리라 E3 끊김이 들리게)
func _e2_loop() -> void:
	_e2_on = true
	var k := 0
	while _e2_on and _pro_live and d.is_inside_tree():
		if k % 2 == 0: _tsfx("cup_clink", -21.0, 1.7)   # 임시 — 엿장수 가위
		if k % 3 == 1: Sound.play("birds_day", { "db": -6.0 })
		if k % 3 == 2: Sound.play("stream_small", { "db": -6.0 })
		k += 1
		await d.get_tree().create_timer(1.9, false).timeout

func _e3_cut() -> void:
	_e2_on = false
	_beat("sound_cut", _pt0)
	Sound.stop_sfx()

# E5 시간의 흔적: 멍석의 기록지 한 장을 '이슬에 번진' 것으로(dew_paper.gd 그림 한 장), 서안 벼루에 마른 먹 갈라짐.
#   지금 마당에 남는다(조사 대상 아님 — 장면을 다시 열면 원래 기록지 소품으로 돌아온다. 놀이·저장에 영향 없음)
var _e5_nodes := {}
const DewPaper := preload("res://story/main_p1/dew_paper.gd")
func _dew_sheet() -> Node3D:
	var a: Vector2 = d.anchor("pro_mat")
	var mi := MeshInstance3D.new(); mi.name = "pro_dew_paper"
	var pm := PlaneMesh.new(); pm.size = Vector2(0.36, 0.466); mi.mesh = pm
	var mm := StandardMaterial3D.new(); mm.albedo_texture = DewPaper.texture(); mm.roughness = 0.95
	mm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mi.material_override = mm
	d._props_root.add_child(mi)
	mi.global_position = Vector3(a.x - 0.62, d._prop_ground(a) + 0.05 + 0.006, a.y - 0.22)   # 멍석 첫 장 자리(clue.gd _paper_dry i=0)
	mi.rotation = Vector3(0, 0.08, 0)
	return mi
func _e5_props(on: bool) -> void:
	if on and _e5_nodes.is_empty():
		_e5_nodes["dew"] = _dew_sheet()
		var b: Vector2 = d.anchor("pro_desk")
		var m = d._build_prop({ "kit": "story/clue", "params": { "kind": "ink_dry", "seed": 3179 }, "ry": 0.0, "dy": 0.49 }, b)
		if m != null: _e5_nodes["ink"] = m
	for k in _e5_nodes:
		var x = _e5_nodes[k]
		if x != null and is_instance_valid(x): x.visible = on
	_story_prop("p_paper_left", not on)

# 기록지 가까이(E5 끼움 컷의 시작 자리 — 곧바로 번진 종이 위로 좁힌다)
func _mat_close(sec: float) -> void:
	var a: Vector2 = d.anchor("pro_mat")
	var p := Vector2(a.x - 0.35, a.y + 0.1)
	var y: float = d.world.height_at(p.x, p.y)
	d.main.rig.focus = { x = p.x, z = p.y, y = y - 0.55 }
	d.main.rig.override = { "pitch": 52.0, "distance": 3.4, "fov": 32.0 }
	d.main.rig.glide(sec)

# 지난날 상태 세우기(프롤로그 처음)
func _past_setup() -> void:
	d.set_hour(15.0)   # 지난날 오후
	d.teleport_to("pro_disc", "right")
	_seat_player("pro_disc", 0.49, "right")
	d.spawn_actor("yigyeom_past", "yigyeom", d.anchor("pro_ig_kneel"), "left", "이겸", "")
	d.anim_actor("yigyeom_past", "kneel")
	for k in range(1, 5): _pro_prop("paper%d" % k, { "kind": "paper_dry", "n": k, "seed": 3190 }, "pro_mat", 0.05)
	for k in _pro_nodes: _pro_show(k, false)
	_story_prop("p_paper_left", false)
	var post = d.main.get("post")
	if post != null: post.past = PRO_PAST

func prologue() -> void:
	var ob = d.onboard
	prologue_played = true
	prologue_t = []
	var p0 := _now()
	_pt0 = p0
	_pro_live = true
	printerr("FIRST15 prologue_clock p0_ms=%d ng0_ms=%d" % [int(p0 * 1000.0), TitleMenu.new_game_t0])
	_skip_ok_at = p0 + PRO_SKIP_GUARD
	if ob != null: ob.skippable = true; ob.skip = false
	d.ui._fade.color.a = 1.0
	d.cutscene(true)
	if d.ui.get("_toasts") != null: d.ui._toasts.visible = false   # 컷 동안 알림 줄(길목 깃발 발견 등)은 감춘다
	_past_setup()
	_cam({ "focus": "pro_two", "distance": 30.0, "pitch": 46.0, "fov": 34.0 }, 0.01)
	d.main.rig.update(0, d.main.player_pos, d.main.player.facing, null, true)
	_log("prologue_start")
	var sk := false
	_knock_slow()   # E1 검은 화면에 느린 두 번 두드림(0.0~1.2)
	# ---- INTRO_01 (0–7.4): 솔숲·물·새·바람 — 카메라가 다가가 둘을 한 화면에. 이겸은 멍석에 젖은 기록지를 편다(S1.0). 대사 없음
	_beat("INTRO_01", p0)
	# E1: 두드림 동안 검은 화면을 둔다(시작 메뉴가 0.6초에 걸쳐 사라진 뒤 1.0초까지 검정 → 0.8초 페이드) · 바탕 소리는 1.2초에(+E2 엿장수)
	d.get_tree().create_timer(1.0, false).timeout.connect(func(): if _pro_live: d.ui.fade(false, 0.8))
	d.get_tree().create_timer(1.2, false).timeout.connect(func():
		if not _pro_live: return
		_tsfx("wind"); _tsfx("birds_day"); _tsfx("stream_small"); _e2_loop())
	_cam({ "focus": "pro_two", "distance": 13.0, "pitch": 34.0, "fov": 34.0 }, 5.2)
	for k in range(1, 5):
		if sk: break
		sk = await _sw(1.4)
		if not sk:
			for j in range(1, 5): _pro_show("paper%d" % j, j == k)
			d.sfx("page_turn")
	if not sk: sk = await _sw(1.6)
	# ---- INTRO_02 (7.4–21.0): 이겸이 기록을 들어 올린다 · 제자가 고개를 든다 — 컷 없는 투샷
	if not sk:
		_beat("INTRO_02", p0)
		_pro_open_book()   # 서안 위에 펴 둘 기록책(INTRO_04까지 숨김) — 견주기의 '스승의 옛 기록'과 같은 쪽. 처음 0.5초 건너뛰기 막이 동안 만들지 않는다(글자 굽기로 프레임이 밀리지 않게)
		_pro_show("book", false)
		d.place_actor("yigyeom_past", "pro_ig_stand", null, "right")
		d.anim_actor("yigyeom_past", "read")
		sk = await _sw(0.5)
	if not sk:
		sk = await _sw(_say_cap("이겸", "기억은 참 편하지. 자기가 빠뜨린 것도 빠뜨렸다는 사실을 잊으니까.") + 0.15)
	if not sk:
		d.main.player.facing = "left"   # 고개를 든다(서안에서 스승 쪽으로)
		sk = await _sw(0.4)
	if not sk: sk = await _sw(_say_cap("나그네", "그래서 전부 적으십니까?") + 0.2)
	if not sk:
		d.anim_actor("yigyeom_past", "talk")
		sk = await _sw(_say_cap("이겸", "글도 틀린다. 다만 틀린 자리를 다시 찾을 수 있지.") + 0.3)
	# ---- INTRO_03 (21.0–39.0): 붓을 건네려다 제자 손의 먹을 보고 옷자락으로 닦아 준다 → 이름 이야기 → 제 도포를 보고 멈칫 → 제자가 작게 웃는다
	if not sk:
		_beat("INTRO_03", p0)
		d.anim_actor("yigyeom_past", "read")   # 종이와 붓을 든 손
		_cam({ "focus": "pro_ig_hand", "distance": 9.0, "pitch": 32.0, "fov": 34.0 }, 2.0)
		d.move_actor("yigyeom_past", ["pro_ig_hand"], 1.3, "walk", "talk")   # 붓을 건네려 다가간다
		sk = await _sw(1.9)
	if not sk:
		d.face_actor("yigyeom_past", "right", null)
		var br := _pro_brush()   # 붓을 손에 들고(가슴께) → 제자 쪽으로 내민다 — 제자는 스승 쪽을 보고 있다(손을 내밀려다 먹이 보인다)
		_brush_at(br, 0.32, 1.12, 0.0)
		_cam({ "focus": "pro_ig_hand", "distance": 7.0, "pitch": 30.0, "fov": 34.0 }, 0.8)
		sk = await _sw(0.35)
		if not sk:
			_brush_at(br, 0.8, 1.08, 0.55)
			d.main.player.facing = "left"
			sk = await _sw(1.5)   # 내민 붓 — 그러다 제자 손의 먹을 본다
		if not sk:
			_brush_at(br, 0.30, 0.95, 0.4)   # 붓을 거둔다(건네지 못한 채)
			sk = await _sw(0.35)
	if not sk:
		d.anim_actor("yigyeom_past", "bow")   # 옷자락으로 닦아 준다
		d.sfx("flour_rustle")
		sk = await _sw(1.4)
	if not sk:
		d.anim_actor("yigyeom_past", "talk")
		sk = await _sw(_say_cap("이겸", "사람 이름은 더 조심해서 적어라. 누군가의 이름을 잘못 적으면 그 사람은 엉뚱한 자리에 가 있게 된다.") + 0.2)
	if not sk:
		d.anim_actor("yigyeom_past", "idle")
		d.face_actor("yigyeom_past", "down", null)   # 뒤늦게 제 옷을 내려다보고 멈칫
		sk = await _sw(0.9)
	if not sk:
		d.face_actor("yigyeom_past", "right", null)
		d.anim_actor("yigyeom_past", "talk")
		sk = await _sw(_say_cap("이겸", "이것도 적어야겠군. 제자의 손은 깨끗해졌고, 내 도포는 다시 빨아야 한다.") + 0.1)
	if not sk:
		d.anim_actor("yigyeom_past", "idle")
		d.main.player.facing = "down"   # 제자가 작게 웃는다(고개를 살짝 돌리고 소리만 — 글 없음)
		d.sfx("laugh_soft")
		_cam({ "focus": "pro_two", "distance": 11.0, "pitch": 33.0, "fov": 34.0 }, 1.0)
		sk = await _sw(1.0)
	# ---- INTRO_04 (39.0–54): 기록책을 서안에 펴 둔다 → 카메라가 펼친 쪽을 잠깐 내려다본다(첫 줄 '구월 열이틀 맑음' — 강조·설명 자막 없음) →
	#      페이드·정적 → 이겸 없는 같은 마당 → 방 안
	if not sk:
		_beat("INTRO_04", p0)
		d.main.player.facing = "left"
		_cam({ "focus": "pro_desk", "distance": 8.0, "pitch": 40.0, "fov": 34.0 }, 1.2)
		d.move_actor("yigyeom_past", ["pro_ig_via", "pro_ig_desk"], 1.6, "walk", "idle")   # 평상 동쪽으로 돌아 서안 옆에(카메라와 책 사이를 막지 않게)
		sk = await _sw(1.7)
	if not sk:
		d.face_actor("yigyeom_past", "left", null)
		d.anim_actor("yigyeom_past", "bow")   # 서안 위에 기록책을 둔다
		sk = await _sw(0.8)
	if not sk:
		_pro_show("book", true)
		_occ_off("pro_desk")
		d.sfx("page_turn")
		d.anim_actor("yigyeom_past", "idle")
		_beat("book_look", p0)
		_look_page(0.7)   # 펼친 쪽을 내려다본다 — 첫 줄을 읽을 만큼 가깝게
		sk = await _sw(0.7 + line_sec(BOOK_FIRST) - 0.3)   # 내려다보는 0.7초 + 첫 줄을 온전히 읽는 시간(자막 머묾과 같은 셈) — 마지막 0.3초는 소리 없이
		if not sk:
			_e3_cut()   # E3: 소리가 그림보다 0.3초 먼저 끊긴다
			sk = await _sw(0.3)
	if not sk:
		_beat("fade_out", p0)
		d.ui.fade(true, 0.9)
		sk = await _sw(0.95)
	if not sk:
		_beat("silence", p0)
		_present_swap()                  # 검은 화면 안에서: 이겸이 없는 지금으로
		_e5_props(true)   # E5 시간의 흔적(번진 기록지·마른 벼루)
		sk = await _sw(1.0)
	if not sk:
		_beat("present", p0)
		_tsfx("wind")   # E4 바람뿐(엿장수 소리가 없다)
		d.ui.fade(false, 0.9)
		sk = await _sw(1.6)   # 바람뿐인 마당, 남은 물건(평상의 서안·멍석의 기록지 한 장) — E5 끼움 컷 때문에 2.4 → 1.6초
	if not sk:
		_beat("E5_insert", p0)   # E5 이슬에 번진 기록지 끼움 컷(1.2초) — 종이 한 장이 화면 가운데 읽힐 만큼 가깝게
		_occ_off("pro_mat")
		_mat_close(0.01)
		var sp: Vector3 = (_e5_nodes["dew"] as Node3D).global_position if _e5_nodes.get("dew") != null else Vector3.ZERO
		if sp != Vector3.ZERO:
			d.main.rig.focus = { x = sp.x, z = sp.z + 0.1, y = sp.y - 0.62 }
			d.main.rig.override = { "pitch": 60.0, "distance": 1.9, "fov": 32.0 }
		d.main.rig.update(0, d.main.player_pos, d.main.player.facing, null, true)
		sk = await _sw(1.2)
		if not sk:   # 끼움 컷이 끝나면 와이드로 되돌아 컷 — 가까운 자리에서 문 쪽으로 미끄러지면 땅을 훑고 나그네 등에 부딪혀 보였다
			_cam({ "focus": "pro_wide", "distance": 13.0, "pitch": 34.0, "fov": 34.0 }, 0.01)
			d.main.rig.update(0, d.main.player_pos, d.main.player.facing, null, true)
			sk = await _sw(0.05)   # 와이드가 한 번 그려진 뒤에 문 쪽 미끄러짐을 시작(같은 프레임이면 가까운 자리에서 출발한다)
	if not sk:
		_occ_off("door")
		_cam({ "focus": "door", "distance": 8.5, "pitch": 40.0, "fov": 34.0 }, 1.5)   # 조용한 방 쪽으로(너무 다가가 앞벽이 반투명해지기 전까지)
		_beat("E6_knock", p0)   # E6 대답 없는 집: 밀어 들어가며 느린 두 번 두드림(E1과 같은 소리) → 대답 없이 1.0초
		sk = await _sw(0.3)
		if not sk: _knock_slow(); sk = await _sw(1.2)
		if not sk: sk = await _sw(1.0)
	if not sk:
		_beat("dip", p0)
		await d.ui.fade(true, 0.12)       # 0.25초 dip(나감 0.12 · 들어옴 0.13)으로 방 안
		_to_room()
		d.ui.fade(false, 0.13)
		sk = await _sw(0.15)
	if not sk:
		_beat("last_line", p0)
		sk = await _sw(_say_cap("나그네", "스승님은 어디로 가신 걸까.") - 0.3)
	if sk:
		op00_skipped = true
		flag("PROLOGUE_SKIPPED")
		_beat("skipped", p0)
		await d.ui.fade(true, 0.08)
		_pro_live = false
		_e3_cut()
		_present_swap()
		_e5_props(true)
		_to_room()
		d.ui.caption("", 0.01)
		d.ui.fade(false, 0.25)   # 건너뛰면 0.25초 페이드 뒤 방 안(첫15 OP00 건너뛰기와 같다)
	_pro_live = false; _e2_on = false
	_beat("control", p0)
	d.cutscene(false)
	if d.ui.get("_toasts") != null: d.ui._toasts.visible = true
	if ob != null: ob.skippable = false; ob.skip = false
	flag("PROLOGUE_SEEN"); flag("OP00_DONE")

# 지난날 → 지금(검은 화면 안): 이겸을 지우고 지난날 소품을 치우고 남은 물건만 — 색감도 지금으로
func _present_swap() -> void:
	_occ_off(null)
	d.despawn_actor("yigyeom_past")
	for k in _pro_nodes:
		var n = _pro_nodes[k]
		if n != null and is_instance_valid(n): n.queue_free()
	_pro_nodes = {}
	if _page_drawer != null and is_instance_valid(_page_drawer): _page_drawer.free()
	_page_drawer = null
	_story_prop("p_paper_left", true)
	var post = d.main.get("post")
	if post != null: post.past = 0.0
	d.set_hour(9.5)
	d.teleport_to("pro_present", "up")
	d.main.player.play("idle", true)
	_cam({ "focus": "pro_wide", "distance": 13.0, "pitch": 34.0, "fov": 34.0 }, 0.01)
	d.main.rig.update(0, d.main.player_pos, d.main.player.facing, null, true)

# 컷 한 장면만 가림 점무늬·카메라 앞 비우기를 끈다(평상 위 제자 곁의 서안·문 앞이 점무늬로 비지 않게) — null이면 평소
func _occ_off(at) -> void:
	if not d.main.has_method("set_occ_script"): return
	if at == null: d.main.set_occ_script(null); return
	var p: Vector2 = d.anchor(at)
	d.main.set_occ_script({ "focus": Vector3(p.x, d.world.height_at(p.x, p.y) + 0.9, p.y), "r": 0.0, "near": 0.0 })

func _to_room() -> void:
	_occ_off(null)
	d.teleport_to("home_start", "up")
	d.camera(null)
	d.main.rig.update(0, d.main.player_pos, d.main.player.facing, null, true)

# 옛 저장 합류(오누이를 지난 저장이 처음 이 사건을 만남) — 여는 장면 없이 지금 자리에서. 거처가 지도에 있다
func join() -> void:
	S.phase = "home"; d.on_phase()
	d.give("ITM_TOOL_009", 1, true)
	flag("JOINED"); flag("OP00_DONE")
	d.sfx("journal_stamp")
	d.ui.toast("새 사건 — 「%s」" % d.data.case.record_title, "journal")
	await d.ui.caption("이겸의 거처에 들러 보자.", 3.0)   # 신규 문구(합류) — 거처 이전으로 '남원 읍내'를 뺐다(사용자 결정)
	_log("join")

# ---------------------------------------------------------------------------
# P00-A 방 물건 · 문 두드림 · P00-B 짧은 기억
# ---------------------------------------------------------------------------
const ROOM_TEXT := {
	"ledger": ["밥값 장부", ["“국 두 그릇. 제자 몫은 내가 냄… 아니다, 둘 다 내가 냄.”"], "글씨는 늘 이렇게 고치셨지."],
	"shoes": ["다시 기운 신발", ["뒤축을 또 기웠다."], "걷는 데 문제없다더니, 다시 기우셨네."],
	"brush": ["말려 둔 붓", ["창가에 붓 셋을 말려 두었다. 하나는 끝이 갈라졌다."], "그날 건네주시려던 붓이다. 끝이 갈라졌는데도 여전히 쓰셨다."],   # 2026-10-17 결정 — 프롤로그 INTRO_03에서 내민 그 붓
}

func inspect_room(kind: String) -> void:
	var t: Array = ROOM_TEXT[kind]
	_cam({ "focus": kind, "distance": 6.5, "pitch": 50.0 }, OBJ_IN)
	await d.wait(OBJ_IN)
	d.sfx("page_turn" if kind == "ledger" else "brush_rustle")
	await d.ui.examine(String(t[0]), t[1], "clue")
	await d.ui.say("나그네", [String(t[2])])
	d.learn_clue(kind)
	_cam(null, OBJ_IN)
	var n := room_seen()
	_log("inspect_" + kind)
	if n == 1:
		flag("P00_ITEM_SEEN")
		if d.onboard != null: d.onboard.on_first_record()   # R 기록책 — 기록 한 장을 얻었을 때만(첫15 P00-A)
		if not f("KNOCKED"): _knock_t = KNOCK_AFTER
	if n == ROOM.size() and not f("FLASHBACK_SEEN"):
		await d.wait(OBJ_IN)
		await flashback()

# P00-B — 셋 다 보면: 재생 없음(서장 프롤로그가 S1.0 P00-B를 맨 앞에서 보여 주므로 첫15 짧은 기억은 겹쳐 뺐다). 깃발만 남긴다 — 조사 결과·기록은 그대로.
#   문 두드림은 첫 조사 뒤 6초 규칙으로 이미 온다(방문자 도착 조건 불변)
func flashback() -> void:
	flag("FLASHBACK_SEEN")
	_log("flashback")

func knock() -> void:
	if f("KNOCKED"): return
	flag("KNOCKED")
	_log("knock")
	# E7 낯선 손: 빠르고 여러 번(knock.wav 두 번 소리를 1.6배 빠르게 두 차례 — 탕탕탕탕, 0.2초 간격). 마당 앞에서 3D로(방 안에서는 조금 멀게)
	d.sfx_cue.emit("knock")
	var at: Vector3 = d.audio_pos("yard_front")
	for i in 2: get_e7_timer(i * 0.4).connect(func(): Sound.play_at("knock", at, d.main.scene_vp, { "pitch": 1.6, "db": 2.0 }))
	d.ui.caption("마당에서 문 두드리는 소리. “거기 계십니까? 이겸 어른 댁 맞소?”", 3.0)   # 메인 대본 P00-A
	d.mark_dirty()

# ---------------------------------------------------------------------------
# P01-A 문턱의 봉투 · P01-B 견주기
# ---------------------------------------------------------------------------
func get_e7_timer(sec: float) -> Signal:
	return d.get_tree().create_timer(maxf(sec, 0.001), false).timeout

func read_letter() -> void:
	_cam({ "focus": "threshold", "distance": 6.0, "pitch": 54.0 }, LETTER_IN)
	await d.wait(LETTER_IN)
	d.sfx("page_turn")
	await d.ui.examine("편지", ["앞면에 스승의 이름. 밀봉은 평범한 풀이다.",   # 무엇이 이상한지는 시스템이 먼저 말하지 않는다(2026-10-17 개편 — '날짜도 표시도 없다'를 뺐다)
		"“나는 며칠 떠나 신선의 가르침을 구하겠노라. 걱정하지 말고 기다려라.", "이 산의 일은 모두 내 뜻이니 남에게 책임을 묻지 말라. — 이겸”"], "item")
	flag("LETTER_RECEIVED")   # 대화를 넘겨도 편지는 남는다(첫15 P01-A)
	d.give(D.LETTER, 1)
	d.learn_clue("letter")
	_cam(null, LETTER_IN)
	_log("letter")
	await d.ui.say("나그네", ["이상하네. 스승님이 이런 글을 쓰실 분인가?"])   # 사용자 지정 대사(개편). 목표 자막 '서안의 옛 기록과 견주어 보자.'는 뺐다 — 서안 먹점(tutorial_high)이 이끈다

# P01-B 메아리를 띄울까: 프롤로그를 끝까지 봤거나, 옛 저장(프롤로그 전 판)에서 짧은 기억을 봤으면
func echo_ok() -> bool:
	if f("PROLOGUE_SEEN"): return not f("PROLOGUE_SKIPPED")
	return f("FLASHBACK_SEEN")

# 견주기 판정(2026-10-17 개편): 두 쌍 + 그 하나는 cmp_unknown(옛 기록 '모르는 것은 모른다고' ↔ 편지 '신선의 가르침을 구하겠노라').
#   날짜·방향 쌍은 마음대로 짚는다. 정답 표시·자동 고르기·열쇠 짝 귀띔은 없다 — 날짜가 없다거나 말투가 다르다는 것만으로는 끝나지 않는다.
#   옛 저장: 개편 전 짝 cmp_blame은 이미 시작한 견주기에서 열쇠 짝으로 인정한다(새 판에서는 cmp_blame을 얻을 길이 없다) · LETTER_COMPARE_2(옛 규칙 통과)도 그대로 인정
const PAIRS := ["cmp_date", "cmp_way", "cmp_unknown", "cmp_blame"]
const NUDGE := "글씨보다, 스승님이 무엇을 적고 무엇을 적지 않는 분이었는지 떠올려 보자."   # 사용자 지정 문구(두 쌍이지만 열쇠 짝이 없을 때 — 정답이 아닌 귀띔)

func compare_pairs() -> int:
	var n := 0
	for c in PAIRS:
		if S.has_clue(c): n += 1
	return n

# 0 = 아직 두 쌍 전 · 1 = 두 쌍이지만 '모르는 것 ↔ 신선' 쌍이 없음 · 2 = 끝
func compare_state() -> int:
	if f("LETTER_COMPARE_2"): return 2
	if compare_pairs() < 2: return 0
	return 2 if S.has_clue("cmp_unknown") or S.has_clue("cmp_blame") else 1

func compare_letter() -> void:
	_cam({ "focus": "desk", "distance": 5.5, "pitch": 58.0 }, OBJ_IN)
	await d.wait(OBJ_IN)
	_log("compare_open")
	var r: Dictionary = await Docs.open(d, { "docs": ["old_record", "letter"], "title": "옛 기록과 편지",
		"hint_after": 60.0, "hint_text": "날짜와 목적을 먼저 대조해 보자." })   # 메인 대본 P01-B 힌트(늦은 도움말 — 한 번). 답을 주는 머리말('날짜·방향·목격자를 적던 분인데.')은 뺐다
	_cam(null, OBJ_IN)
	var st := compare_state()
	_log("compare_close_%d_%d" % [compare_pairs(), st])
	if st == 0:
		await d.ui.caption("아직 두 군데를 다 견주지 못했다. 서안에서 다시 이어 볼 수 있다.", 2.6)   # 신규 문구 — ESC로 닫아도 이어 한다
		return
	if st == 1:
		_log("compare_nudge")
		await d.ui.caption(NUDGE, 3.6)   # 서안은 그대로 다시 열 수 있다
		return
	flag("LETTER_COMPARE_2")
	await d.ui.say("나그네", ["기다리라고? …내가 찾아 나서지 못하게 하려는 거라면?"])   # 사용자 지정 대사 — 의심이지 확정이 아니다
	await d.runner.exec([{ "choice": "", "options": [   # 메인 대본 P01-B [선택: 결론] A·B·C — 모두 '직접 확인해야 한다'로 귀결
		{ "label": "글씨를 흉내 낸 자가 있다.", "do": [] },
		{ "label": "누가 내용을 대신 써줬을지도 모른다.", "do": [] },
		{ "label": "스승이 일부러 평소처럼 쓰지 않았나?", "do": [] }] }], d.runner.gen)
	await d.ui.say("나그네", ["직접 확인해야 한다."])   # 메인 대본 P01-B
	d.learn_clue("suspicious")   # 추정(△) — 확정 위조로 기록하지 않는다
	flag("LETTER_SUSPICIOUS")
	S.phase = "town"; d.on_phase()
	if echo_ok(): await d.ui.caption("이겸  “틀린 자리를 다시 찾을 수 있지.”", 2.4)   # 메인 대본 P01-B 연출 — 프롤로그 L3의 메아리(끝까지 보이게 기다린다)
	if d.onboard != null: d.onboard.step({ "discover": "solip_jumak" })
	Progress.checkpoint("편지를 의심했다")
	_log("suspicious")
	await d.ui.caption("솔잎 주막을 찾아가자 — 광한루 앞 나루 길가.", 3.0)   # 신규 문구(목표 — 갈 곳 안내. 결론을 되풀이하지 않는다)

# ---------------------------------------------------------------------------
# OP01 거처 밖 4m — 「설화록」(재기획 OP-04 시간, 첫15 시점·조작 유지). 이야기 줄(runner)이 아니라 따로 돈다 — 이동을 막지 않는다
# ---------------------------------------------------------------------------
# OP01 자리: 구례 길 장승 어귀(숲길이 끝나고 요천 너머 광한루·읍성이 열린다). 다른 길로 가도 놓치지 않게 — 거처에서 160m 넘게, 또는 나루 30m 안
func _title_due() -> bool:
	var p := Vector2(d.main.player_pos.x, d.main.player_pos.z)
	if d.world.interior_at(p.x, p.y) != null: return false
	if p.distance_to(d.anchor("title_view")) <= TITLE_AT_M: return true
	if p.distance_to(d.anchor("naru")) <= TITLE_NARU_M: return true
	return p.distance_to(d.anchor("home_center")) >= TITLE_FAR_M

func title_walk() -> void:
	title_running = true
	flag("TITLE_IN_WORLD_SEEN")   # 한 번만(첫15 OP01 — 영상 반복 방지)
	var ob = d.onboard
	if ob != null: ob.skippable = true; ob.skip = false
	d.hush_hints = true   # 제목 동안 조작 안내는 멈춘다(이동 잠금은 없다)
	var t0 := _now()
	title_t = [["start", 0.0]]
	_log("title_start")
	_cam({ "focus": "title_mid", "pitch": 46.0, "distance": 32.0, "fov": 34.0 }, 2.0)   # 0–2.0 어귀 와이드(카메라 상승)
	# (2026-10-17: 독백 "사라진 길을 따라가야겠다." 삭제 — 설명 대사 대신 걷는 침묵)
	var sk := await _sw(2.0)
	if not sk:
		title_t.append(["reframe", _now() - t0])
		_cam({ "focus": "title_look", "pitch": 34.0, "distance": 46.0, "fov": 36.0 }, 2.5)   # 2.0–4.5 요천 너머 광한루·읍성 쪽 리프레이밍
		sk = await _sw(2.5)
	if not sk:
		title_t.append(["title_in", _now() - t0])
		d.ui.title_card("설화록", 5.0, 133, 0.8, 1.0)   # 4.5–8.5 등장(4초) · 8.5–9.5 사라짐(1초)
		sk = await _sw(4.0)
	if not sk:
		title_t.append(["title_out", _now() - t0])
		_cam(null, 1.0)                                  # 8.5–9.5 카메라만 돌아온다
		sk = await _sw(1.0)
	if sk:
		d.ui.title_card_stop()
		_cam(null, 0.4)
	title_t.append(["end", _now() - t0])
	d.hush_hints = false
	if ob != null: ob.skippable = false; ob.skip = false
	title_running = false
	printerr("FIRST15 title %s skipped=%s" % [JSON.stringify(title_t), sk])
	_log("title_end")

# ---------------------------------------------------------------------------
# P02 솔잎 주막 · 지도 목적지
# ---------------------------------------------------------------------------
func tavern_ledger() -> void:
	_cam({ "focus": "solip_ledger", "distance": 6.0, "pitch": 46.0 }, OBJ_IN)
	await d.wait(OBJ_IN)
	d.sfx("page_turn")
	await d.ui.examine("밥값 장부", ["주막 밥값 장부. 며칠 전 아침 줄에 ‘이겸 — 국 한 그릇’.", "국값 줄을 고쳐 쓴 글씨가 스승의 것이다."], "clue")   # 2026-10-17: 숙박 → 밥값(거처가 주막에서 걸어 2분 — 길 떠나기 전에 들렀다)
	d.learn_clue("tv_last")
	_cam(null, OBJ_IN)
	await tavern_clue()

# 짚신 손님 증언 · 밥값 장부 · 백운 소문 가운데 둘 이상 — 지도 목적지 후보 '여원재 방면'(메인 대본 P02-A 조건 · KNOWN_NOT_VISITED).
#   옛 판 주모 증언 tv_jumo(여원재 쪽 행선지)도 셈에 든다(옛 저장)
func tavern_sources() -> int:
	var n := 0
	for k in D.TAVERN_SOURCES:
		if S.has_clue(String(k)): n += 1
	return n

func tavern_clue() -> void:
	if f("TAVERN_CLUE"): return
	if tavern_sources() < 2:
		_log("tavern_source_%d" % tavern_sources())
		return
	flag("TAVERN_CLUE")
	_log("tavern_clue")
	if d.onboard != null:
		d.onboard.step({ "discover": "yeowon" })   # 지도에 '여원재 방면'(들음) → M 지도 안내(실제로 열어야 끝)
		d.onboard.on_waypoint_lead()               # → 목적지 설정 안내(실제로 정해야 끝)
	Progress.checkpoint("행선지를 들었다")
	await d.ui.caption("지도에 ‘여원재 방면’이 적혔다.", 2.4)   # 신규 문구

# 지도에서 목적지를 정했다(region_map → story_director.on_waypoint). 미방문이면 경로 안내만 — 순간이동하지 않는다
func on_waypoint(w: Dictionary) -> void:
	var key := String(w.get("key", ""))
	_log("waypoint_" + key)
	printerr("FIRST15 waypoint %s" % JSON.stringify(w))
	if key.ends_with("mp_yeowon") and not f("WAYPOINT_SET"):
		flag("WAYPOINT_SET"); flag("WAYPOINT_SELECTED")
		if d.onboard != null: d.onboard.observe("여원재", "확인된 것은 이겸의 마지막 행적(주막 밥값 장부). 고갯길 소문은 아직 전해 들은 말.")   # 첫15 P02-C 기록
		d.ui.toast("목적지를 표시했다. 직접 가거나 역마를 이용할 수 있다.", "info")   # 첫15 P02-C 시스템 문구
		S.phase = "road"; d.on_phase()
		Progress.checkpoint("목적지를 정했다")
		d.save()

# 북문 밖 행상 → 오누이(D1). 이 대화가 끝난 뒤 사건을 바꾼다(지금 줄이 다 끝난 프레임 끝)
func enter_onui() -> void:
	_log("enter_onui")
	d.save()
	d.switch_case.call_deferred("namwon", { "event": "N0000" })

# ---------------------------------------------------------------------------
# 프레임(story_director._update_ambient) · 음악 · 이어 하기
# ---------------------------------------------------------------------------
func ambient(dt: float) -> void:
	var busy: bool = d.runner.busy or d.ui.modal or d.talking or d._cut or d.ui.journal_open
	if _knock_t >= 0.0 and not busy:
		var far := Vector2(d.main.player_pos.x, d.main.player_pos.z).distance_to(d.anchor("home_center")) > KNOCK_NEAR
		if not far: _knock_t -= dt
		if _knock_t <= 0.0:
			_knock_t = -1.0
			knock()
	if _migrate_to != null and not busy and not (d.title != null and d.title.active) and d._started: _migrate_player()
	if f("LETTER_SUSPICIOUS") and not f("TITLE_IN_WORLD_SEEN") and not title_running and not busy and _title_due():
		title_walk()
	if f("TAVERN_CLUE") and not f("M_OPEN_SEEN"):
		var m = d.main.get("_map")
		if m != null and m.visible:
			flag("M_OPEN_SEEN"); flag("MAP_FIRST_OPEN"); _log("map_open")

func music_wanted() -> String:
	if S.phase == "start" or not f("OP00_DONE"): return ""
	var h: float = d.main.hour
	return "bgm_day_calm" if h >= 5.5 and h < 18.0 else ""

# 옛 거처(객사 담 앞) 안에서 저장한 옛 저장만 새 거처로 — 메인 서장 국면 home(편지를 의심하기 전)이고 저장 자리가 옛 집·앞마당 안일 때.
#   옛 자리 가까이라도 그 밖(길·다른 국면·다른 사건)은 옮기지 않는다. 사건 진행·기록책·인물 상태·다른 설화는 건드리지 않는다(자리와 지도 키만)
func _old_home_rel(x: float, z: float):
	var r: Array = D.OLD_RECT
	var lx := x - D.OLD_HX; var lz := z - D.OLD_HZ
	if lx < float(r[0]) or lx > float(r[2]) or lz < float(r[1]) or lz > float(r[3]): return null
	return Vector2(lx, lz)

func migrate_old_home() -> bool:
	if S.phase != "home" or f("LETTER_SUSPICIOUS") or f("HOME_MOVED"): return false
	var wh: Dictionary = Progress.where()
	if wh.is_empty() or String(wh.get("space", "")) != String(d.space_id) or String(wh.get("kind", "region")) != "region": return false
	var rel = _old_home_rel(float(wh.x), float(wh.z))
	if rel == null: return false
	var to: Vector2 = Vector2(D.HX, D.HZ) + rel
	wh["x"] = snappedf(to.x, 0.1); wh["z"] = snappedf(to.y, 0.1)   # 이어 하기(같은 공간 teleport)가 읽는 자리
	var kn: Dictionary = Progress.known(String(d.space_id))
	var ok := "bld:이겸의 거처@%d,%d" % [roundi(D.OLD_HX), roundi(D.OLD_HZ)]
	if kn.has(ok):
		var nk := "bld:이겸의 거처@%d,%d" % [roundi(D.HX), roundi(D.HZ)]
		var rank := { "known": 0, "told": 1, "visited": 2 }
		var v := String(kn[ok])
		if not kn.has(nk) or int(rank.get(v, 0)) > int(rank.get(String(kn[nk]), 0)): kn[nk] = v
		kn.erase(ok)
	S.flags["HOME_MOVED"] = true
	_migrate_to = to   # 불러오기가 장면을 다시 열어 옛 자리에 세웠으면 첫 한가한 프레임에 옮긴다
	migrated = true
	printerr("FIRST15 migrate old home → (%.1f, %.1f)" % [to.x, to.y])
	d.mark_dirty()
	return true

func _migrate_player() -> void:
	var p := Vector2(d.main.player_pos.x, d.main.player_pos.z)
	var rel = _old_home_rel(p.x, p.y)
	if rel != null: d.teleport_to(Vector2(D.HX, D.HZ) + rel, "up")
	_migrate_to = null

func on_load() -> void:
	migrate_old_home()
	# 여는 장면·제목·짧은 기억 도중 저장 — 본 것으로 넘긴다(다시 돌지 않는다)
	if S.phase != "start" and not f("OP00_DONE"):
		S.flags["OP00_DONE"] = true
	if f("P00_ITEM_SEEN") and not f("KNOCKED"): _knock_t = 1.0   # 첫 조사 뒤 문 두드림 전 저장 — 곧 두드린다
	if f("LETTER_SUSPICIOUS") and S.phase == "home": S.phase = "town"
	if f("WAYPOINT_SET") and S.phase != "done": S.phase = "road"
