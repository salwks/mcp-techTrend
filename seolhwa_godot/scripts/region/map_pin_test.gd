# 지도 목적지·역마 시험(재기획 4단계 — tools/run_story_tests.sh mappin:*). horse_ride.setup이 --mappintest를 보고 연다.
#   --mappintest=map    커서 고정 휠 줌(5·10·20칸, 매 프레임 커서 아래 땅 오차 · 보간 시간) · 6px 끌기 문턱(누르기와 구분) · 빈 곳 누르기 → 이름 없는 핀 카드(PREVIEW)
#                       → [목적지 설정](순간이동 없음) · 안 가 본 아는 곳으로 바꾸기 · 빠른 이동 잠금(빈 곳·안 가 본 곳 — 까닭) · 가 본 역참 빠른 이동 열림 ·
#                       큰길 없는 빈 곳 말 잠금 · 다른 권역(한양) 카드 — 말은 길 끝까지 · 우클릭(선택 해제 → 목적지 카드 → 지우기) · Esc 차례 ·
#                       카드 글 크기(MAP_MIN)·자리 · M 30번 · 저장 → 다시 읽기(목적지 그대로)
#   --mappintest=ride   걷기([목적지 설정]만 — 말 없음) vs 말([말로 이동] — 큰길 점만 밟음) · D6(말 위 지도 → 말이 섬 · 지도 동안 Space 건너뛰기 없음 · 닫아도 선 채)
#                       · 지도에서 [말로 이동]으로 다시 출발(새 길) · 목적지 어귀에서 내림 · 성 안 핀 → 성문 앞에서 내림 · 말 타는 곳이 멀면 걸어가라는 안내(순간이동 없음)
#                       → 그 자리에서 목적지 쪽 말 안내 · 다른 권역 목적지 → 걷기 목적지 후보 맨 앞이 그쪽 길 끝
#   --mappintest=shots  화면(창 — --shotdir): 빈 곳 핀 카드·말 길 미리보기 · 안 가 본 곳 카드 · 역참 카드 · 지도 밖 목적지 화살 · 전국 지도 다른 권역 카드 ·
#                       말 위 지도(D6) · 말 타는 곳 안내 줄
# 판정: "MAPPINTEST PASS n" / "MAPPINTEST FAIL …"
extends RefCounted

const Progress := preload("res://scripts/region/progress.gd")
const HorseRide := preload("res://scripts/region/horse_ride.gd")
const Discovery := preload("res://scripts/region/discovery.gd")
const Stations := preload("res://scripts/region/stations.gd")
const WaypointPlan := preload("res://scripts/region/waypoint_plan.gd")
const UiFonts := preload("res://scripts/ui_fonts.gd")

const YARD := Vector2(-2992.7, 219.8)     # 남원 역참 문 앞(말 타는 곳)
const MARKET := Vector2(-3231.9, 378.2)   # 남원 장 어귀(말 타는 곳에서 멀다)

var main
var _fails: Array = []
var _n := 0
var shots := ""

func _init(m) -> void:
	main = m

func _ok(c: bool, w: String) -> void:
	_n += 1
	if c: print("MAPPINTEST ok ", w)
	else:
		_fails.append(w); print("MAPPINTEST check FAIL ", w)

func _wait_load() -> void:
	await main._wait_frames(10)
	var n := 0
	while main._loading and n < 6000:
		await main._wait_frames(1); n += 1
	n = 0
	while (main.world.stats.jobs > 0 or main.placement.busy()) and n < 900:
		await main._wait_frames(1); n += 1

func _sec(t: float) -> void:   # 게임 시간(Engine.time_scale 따름)
	await main.get_tree().create_timer(t).timeout

func _pp() -> Vector2: return Vector2(main.player_pos.x, main.player_pos.z)

func _go(p: Vector2) -> void:
	main.teleport(p.x, p.y)
	main.rig.update(0, main.player_pos, main.player.facing, null, true)
	await _wait_load()
	await main._wait_frames(20)

func _shot(name: String) -> void:
	if shots == "": return
	for i in 4: await RenderingServer.frame_post_draw
	main._save(shots.path_join(name + ".png"))
	print("MAPPINTEST shot ", name)

func _end() -> void:
	Engine.time_scale = 1.0
	if _fails.is_empty(): print("MAPPINTEST PASS %d" % _n)
	else: print("MAPPINTEST FAIL %d/%d: %s" % [_fails.size(), _n, " / ".join(_fails.slice(0, 12))])
	main._quit()

func run(spec: String) -> void:
	Engine.max_fps = 0
	await _wait_load()
	Progress.clear_waypoint()
	if spec == "shots":
		shots = main._abs(String(main.args.get("shotdir", "shots/replan_stage4")))
		DirAccess.make_dir_recursive_absolute(shots)
	var mp = main.get("_map")
	if mp == null:
		print("MAPPINTEST FAIL 지도 없음"); main._quit(); return
	match spec:
		"map": await _map_part(mp)
		"ride": await _ride_part(mp)
		"shots": await _shots(mp)
	_end()

# ---- 지도 열기·보기 ----
func _open(mp) -> void:
	if not mp.visible: mp.toggle()
	await main._wait_frames(6)

func _close(mp) -> void:
	if mp.visible: mp.toggle()
	await main._wait_frames(6)

func _view(mp, k: float, at: Vector2) -> void:
	mp._set_view("all", k, at)
	await mp._redraw_wait()

func _click(mp, p: Vector2, btn := MOUSE_BUTTON_LEFT) -> void:
	for down in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = btn; ev.pressed = down; ev.position = p
		ev.button_mask = MOUSE_BUTTON_MASK_LEFT if (down and btn == MOUSE_BUTTON_LEFT) else 0
		mp._on_input(ev)
		await main._wait_frames(2)
	await mp._redraw_wait()

func _key(mp, kc: int) -> void:
	var ev := InputEventKey.new(); ev.pressed = true; ev.physical_keycode = kc; ev.keycode = kc
	mp._unhandled_input(ev)
	await main._wait_frames(3)

# 빈 곳(표지·카드 없는 화면 자리) — want_road: 그 땅에서 큰길이 PIN_SNAP 안(true) / 밖(false) / 상관없음(null)
func _empty_px(mp, want_road = null) -> Vector2:
	var hr = main.horse_ride
	var cs: Vector2 = mp._canvas.size
	for gy in range(3, 18):
		for gx in range(3, 18):
			var p := Vector2(cs.x * gx / 20.0, cs.y * gy / 20.0)
			if mp._hit(p) != null or mp.card_rect().grow(30).has_point(p + mp._canvas.position): continue
			var w: Vector2 = mp._to_world(p)
			if want_road != null:   # true: 큰길이 가깝고 말 타는 곳(역참)에서 큰길이 이어진다 / false: 큰길이 PIN_SNAP 밖
				var gi: int = hr.net.nearest(w, HorseRide.PIN_SNAP)
				if bool(want_road) and (gi < 0 or is_inf(float(_yard_dj(hr).dist[gi]))): continue
				if not bool(want_road) and gi >= 0: continue
			return p
	return Vector2(-1, -1)

var _ydj := {}
func _yard_dj(hr) -> Dictionary:
	if _ydj.is_empty(): _ydj = hr.net.dijkstra(hr.net.nearest(YARD, 12.0))
	return _ydj

func _hit_where(mp, f: Callable):
	for h in mp._hits:
		if h.has("place") and f.call(h.place): return h
	return null

# ==================================================================================
func _map_part(mp) -> void:
	await _go(YARD)
	await _open(mp)
	_ok(mp.visible and mp.card_t.is_empty(), "M — 지도 열림, 카드 없음")
	# 1) 커서 고정 휠 줌: 5·10·20칸(매 프레임 커서 아래 땅 오차 ≤ 8px), 한 칸 보간 0.12~0.30초
	for ticks in [5, 10, 20]:
		await _view(mp, mp.tier2_k() * 0.9, _pp())
		var a: Vector2 = mp._canvas.size * Vector2(0.32, 0.41)
		var w0: Vector2 = mp._to_world(a)
		var worst := 0.0
		var m0: String = mp.mode
		for i in ticks:
			var ev := InputEventMouseButton.new(); ev.button_index = MOUSE_BUTTON_WHEEL_UP; ev.pressed = true; ev.position = a
			mp._on_input(ev)
			for f in 2:
				await main._wait_frames(1)
				worst = maxf(worst, (mp._to_px(w0) - a).length())
		var guard := 0
		while mp.zooming() and guard < 2000:
			await main._wait_frames(1); guard += 1
			worst = maxf(worst, (mp._to_px(w0) - a).length())
		await mp._redraw_wait()
		worst = maxf(worst, (mp._to_px(w0) - a).length())
		print("MAPPIN zoom ticks=%d k=%.3f mode %s→%s worst=%.2fpx" % [ticks, mp._k, m0, mp.mode, worst])
		_ok(worst <= 8.0, "휠 %d칸 — 커서 아래 땅 오차 %.2fpx ≤ 8" % [ticks, worst])
	await _view(mp, mp.tier2_k(), _pp())
	var ev1 := InputEventMouseButton.new(); ev1.button_index = MOUSE_BUTTON_WHEEL_UP; ev1.pressed = true; ev1.position = mp._canvas.size / 2.0
	var k0: float = mp._k
	var t0 := Time.get_ticks_usec()
	mp._on_input(ev1)
	await main._wait_frames(1)
	_ok(mp._k < k0 * 1.15 - 0.0001, "휠 한 칸이 바로 뛰지 않고 보간(첫 프레임 k %.3f < 목표 %.3f)" % [mp._k, k0 * 1.15])
	while mp.zooming(): await main._wait_frames(1)
	var zt := (Time.get_ticks_usec() - t0) / 1e6
	_ok(zt >= 0.10 and zt <= 0.35 and absf(mp._k - k0 * 1.15) < 0.001, "한 칸 보간 %.2f초 · 목표 배율 도착" % zt)
	# 2) 끌기 문턱 6px
	await _view(mp, mp.tier2_k() * 1.2, _pp())
	var c0: Vector2 = mp._center
	var p0: Vector2 = _empty_px(mp)
	var press := InputEventMouseButton.new(); press.button_index = MOUSE_BUTTON_LEFT; press.pressed = true; press.position = p0; press.button_mask = MOUSE_BUTTON_MASK_LEFT
	mp._on_input(press)
	var mv := InputEventMouseMotion.new(); mv.position = p0 + Vector2(3, 2); mv.relative = Vector2(3, 2); mv.button_mask = MOUSE_BUTTON_MASK_LEFT
	mp._on_input(mv)
	_ok(mp._center == c0, "4px 움직임은 지도를 밀지 않는다")
	var mv2 := InputEventMouseMotion.new(); mv2.position = p0 + Vector2(80, 50); mv2.relative = Vector2(77, 48); mv2.button_mask = MOUSE_BUTTON_MASK_LEFT
	mp._on_input(mv2)
	var moved: Vector2 = (c0 - mp._center) * mp._k
	_ok(moved.distance_to(Vector2(80, 50)) < 1.0, "6px 넘으면 그동안 움직인 만큼 한 번에 끈다(%s)" % moved)
	var rel := InputEventMouseButton.new(); rel.button_index = MOUSE_BUTTON_LEFT; rel.pressed = false; rel.position = p0 + Vector2(80, 50)
	mp._on_input(rel)
	await main._wait_frames(2)
	_ok(mp.card_t.is_empty(), "끌기를 놓아도 누르기(카드)가 아니다")
	# 3) 빈 곳 누르기 → 이름 없는 핀 카드(PREVIEW)
	await _view(mp, mp.tier2_k() * 1.2, _pp())
	var pe: Vector2 = _empty_px(mp, true)
	_ok(pe.x >= 0, "큰길 가까운 빈 곳을 찾음")
	await _click(mp, pe)
	_ok(String(mp.card_t.get("kind", "")) == "point" and mp._card.visible, "빈 곳 누르기 → 이름 없는 핀 카드 '%s'" % mp.card_t.get("name", ""))
	_ok(mp.wp_status() == "PREVIEW" and Progress.waypoint().is_empty(), "누르기만 해서는 목적지가 아니다(PREVIEW)")
	_ok(mp._fast_btn.disabled and String(mp._fast_why.text).contains("빈 곳"), "빈 곳 빠른 이동 잠김 — 「%s」" % mp._fast_why.text)
	_ok(not mp._ride_btn.disabled, "큰길 가까운 빈 곳은 말로 갈 수 있다 — 「%s」" % mp._ride_why.text)
	_card_checks(mp, "빈 곳")
	var pos0 := _pp()
	mp._wp_btn.pressed.emit()
	await main._wait_frames(4)
	var wp := Progress.waypoint()
	_ok(String(wp.get("kind", "")) == "point" and mp.wp_event == "SET" and mp.wp_status() == "ACTIVE", "[목적지 설정] → 빈 곳 목적지 %s" % JSON.stringify(wp))
	_ok(_pp().distance_to(pos0) < 0.5 and not main.horse_ride.mounted(), "목적지만 — 순간이동·말 없음")
	_ok(mp._wp_btn.text.begins_with("목적지 지우기"), "지금 목적지 카드는 [목적지 지우기]")
	# 4) 안 가 본 아는 곳(KNOWN)으로 바꾸기 — 빠른 이동은 까닭과 함께 잠김
	await _view(mp, mp._k_min, _pp())
	var hk = _hit_where(mp, func(pl): return String(pl.kind) in ["town", "landmark", "pass"] and Discovery.state(String(pl.space), String(pl.key)) == Discovery.KNOWN)
	_ok(hk != null, "안 가 본 아는 곳 표지가 지도에 있다")
	if hk != null:
		await _click(mp, hk.p)
		_ok(String(mp._card_state.text).contains("아는 곳"), "카드 상태 「%s」" % mp._card_state.text)
		_ok(mp._fast_btn.disabled and mp._fast_why.text != "", "안 가 본 곳 빠른 이동 잠김 — 「%s」" % mp._fast_why.text)
		_card_checks(mp, "아는 곳")
		mp._wp_btn.pressed.emit()
		await main._wait_frames(4)
		_ok(mp.wp_event == "CHANGED" and String(Progress.waypoint().get("name", "")) == String(hk.place.name), "목적지 바꾸기 → %s" % Progress.waypoint().get("name", ""))
	# 5) 가 본 역참 → 빠른 이동 열림 · 다른 권역(한양) — 말은 그쪽 길 끝까지, 빠른 이동은 가 본 역이 있어야
	HorseRide.discover("JL_NAMWON_UNBONG", "inwol_yeok")
	mp._refresh_dynamic()
	await _view(mp, mp.tier2_k() * 1.3, Vector2(2507.5, -1506.0))
	var hs = _hit_where(mp, func(pl): return String(pl.kind) == "station" and String(pl.get("station_id", "")) == "inwol")
	_ok(hs != null, "가 본 인월역 표지")
	if hs != null:
		await _click(mp, hs.p)
		_ok(not mp._fast_btn.disabled, "가 본 역참 빠른 이동 열림 — 「%s」" % mp._fast_btn.text)
		_ok(String(mp._card_state.text).begins_with("가 본 곳"), "역참 카드 상태 「%s」" % mp._card_state.text)
	mp.open_card(WaypointPlan.region_target("GG_HANYANG", "한양"))
	await mp._redraw_wait()
	var rr: Dictionary = mp.card_plan.ride
	_ok(bool(rr.ok) and bool(rr.c.cross) and String(rr.c.node.kind) == "ROUTE_END", "다른 권역 목적지 — 말은 %s까지(%s)" % [rr.get("c", {}).get("name", "-"), rr.get("why", "")])
	_ok(mp._fast_btn.disabled, "한양에 가 본 역이 없으면 빠른 이동 잠김 — 「%s」" % mp._fast_why.text)
	HorseRide.discover("GG_HANYANG", String(mp.card_t.get("node", "")))
	mp.open_card(WaypointPlan.region_target("GG_HANYANG", "한양"))
	_ok(not mp._fast_btn.disabled, "한양 거점을 가 보았고 노정을 지나왔으면 빠른 이동 열림 — 「%s」 %s" % [mp._fast_btn.text, mp._fast_why.text])
	# 6) 큰길 없는 빈 곳 — 말 잠금(까닭), 핀은 된다
	await _view(mp, mp._k_min, _pp())
	mp.card_close()
	var pn: Vector2 = _empty_px(mp, false)
	if pn.x >= 0:
		await _click(mp, pn)
		_ok(mp._ride_btn.disabled and String(mp._ride_why.text).contains("큰길"), "큰길 없는 빈 곳 — 말 잠금 「%s」" % mp._ride_why.text)
		_ok(not mp._wp_btn.disabled, "큰길 없는 빈 곳도 목적지는 된다")
	else: print("MAPPIN 큰길 없는 빈 곳을 이 배율에서 못 찾음")
	# 7) 우클릭: 선택 해제 → (없으면) 목적지 카드 → 지우기 · Esc 차례
	await _click(mp, mp._canvas.size / 2.0, MOUSE_BUTTON_RIGHT)
	_ok(mp.card_t.is_empty(), "우클릭 — 카드 닫힘(선택 해제)")
	_ok(not Progress.waypoint().is_empty(), "우클릭은 바로 지우지 않는다")
	await _click(mp, mp._canvas.size / 2.0, MOUSE_BUTTON_RIGHT)
	_ok(mp._is_current(mp.card_t) and mp._wp_btn.text.begins_with("목적지 지우기"), "카드 없을 때 우클릭 — 지금 목적지 카드")
	mp._wp_btn.pressed.emit()
	await main._wait_frames(3)
	_ok(Progress.waypoint().is_empty() and mp.wp_event == "CLEARED" and mp.wp_status() == "NONE", "[목적지 지우기] → 목적지 없음")
	await _click(mp, _empty_px(mp))
	await _key(mp, KEY_ESCAPE)
	_ok(mp.visible and mp.card_t.is_empty(), "Esc 한 번 — 카드만 닫힘")
	await _key(mp, KEY_ESCAPE)
	_ok(not mp.visible, "Esc 두 번 — 지도 닫힘")
	# 8) M 30번
	var nch: int = mp.get_child_count()
	var bad := 0
	for i in 30:
		await _key(mp, KEY_M)
		if mp.visible != (i % 2 == 0): bad += 1
		if mp._card.visible: bad += 1
	_ok(bad == 0 and mp.get_child_count() == nch and not mp.visible, "M 30번 — 열림·닫힘 차례 그대로, 카드·노드 늘지 않음")
	# 9) 저장 → 다시 읽기(목적지 그대로)
	await _open(mp)
	await _view(mp, mp.tier2_k() * 1.2, _pp())
	await _click(mp, _empty_px(mp, true))
	mp._wp_btn.pressed.emit()
	var w1 := Progress.waypoint().duplicate()
	Progress.save()
	Progress._d = null   # 파일에서 다시 읽는다
	var w2 := Progress.waypoint()
	_ok(not w1.is_empty() and JSON.stringify(w1) == JSON.stringify(w2), "저장 → 다시 읽기: 목적지 그대로 %s" % JSON.stringify(w2))
	await _close(mp)
	await _open(mp)
	await mp._redraw_wait()
	_ok(mp.wp_status() == "ACTIVE" and mp.card_t.is_empty(), "지도를 닫았다 열어도 목적지 그대로, 미리보기 카드는 비움")
	await _close(mp)

# 카드 글 크기·자리
func _card_checks(mp, tag: String) -> void:
	var small := []
	for l in mp._card.find_children("*", "Label", true, false) + mp._card.find_children("*", "Button", true, false):
		if (l as Control).is_visible_in_tree() and (l as Control).get_theme_font_size("font_size") < UiFonts.MAP_MIN: small.append(String(l.text))
	_ok(small.is_empty(), "%s 카드 글 모두 MAP_MIN(%d) 이상 %s" % [tag, UiFonts.MAP_MIN, small])
	var cr: Rect2 = mp.card_rect()
	var mr := Rect2(mp._canvas.position, mp._canvas.size)
	_ok(mr.encloses(cr), "%s 카드가 지도 안 %s" % [tag, cr])

# ==================================================================================
func _ride_part(mp) -> void:
	Engine.time_scale = float(main.args.get("ridetime", "4"))
	var hr = main.horse_ride
	var hy: Dictionary = hr.net.node_by["ibaek"]   # 이백 마을(역참에서 큰길로 약 2km — 말이 제 빠르기에 닿는다)
	var t1 := { kind = "place", space = "JL_NAMWON_UNBONG", c = Vector2(float(hy.x), float(hy.z)), name = "이백 마을", key = "" }
	# 1) 걷기: [목적지 설정]만 — 말이 오지 않는다
	await _go(YARD)
	await _open(mp)
	mp.open_card(t1)
	await mp._redraw_wait()
	_ok(not mp._ride_btn.disabled and not mp._wp_btn.disabled, "이백 마을 카드 — 걷기·말 둘 다 고를 수 있다(「%s」)" % mp._ride_why.text)
	var p0 := _pp()
	mp._wp_btn.pressed.emit()
	await _close(mp)
	await _sec(2.0)
	_ok(not hr.mounted() and _pp().distance_to(p0) < 0.5, "걷기 고름 — 말 없음·자리 그대로")
	var hud = main.story.get_node_or_null("waypoint_hud") if main.story != null else null
	if hud != null:
		await _sec(0.5)
		_ok(String(hud.text).contains("이백 마을"), "방위 줄 「%s」" % hud.text)
	# 2) 말: [말로 이동] — 큰길 점만 밟는다
	await _open(mp)
	mp.open_card(t1)
	mp.card_ride()
	await main._wait_frames(4)
	_ok(not mp.visible and mp.wp_event == "RIDE" and hr.mounted() and bool(hr.dest.get("pin", false)), "[말로 이동] → 지도 닫힘, 말이 온다(%s)" % hr.state)
	var off := 0.0
	var ss := 14.0
	while ss < hr.L:
		off = maxf(off, hr.net.road_dist(hr._at(ss), 40.0)); ss += 6.0
	_ok(off < 8.0, "말 길은 큰길 위(중심선에서 가장 먼 점 %.1fm)" % off)
	var w := 0
	while not hr.riding() and w < 400: await main._wait_frames(1); w += 1
	w = 0
	while hr.v < 6.0 and hr.riding() and w < 2000: await main._wait_frames(1); w += 1
	# 3) D6: 말 위에서 지도 → 말이 선다 · 지도 동안 Space 건너뛰기 없음
	var v0: float = hr.v
	await _open(mp)
	await _sec(2.0)
	var s1: float = hr.s
	_ok(hr.halted and hr.map_halt and hr.v < 0.05, "말 위에서 지도 → 말이 섬(v %.1f → %.2f)" % [v0, hr.v])
	await _sec(1.0)
	_ok(absf(hr.s - s1) < 0.05 and hr.mounted(), "지도 동안 말이 움직이지 않음(Δs %.2f)" % (hr.s - s1))
	_ok(not hr.can_skip(), "지도 동안 건너뛰기 불가")
	var ov = main.get_node_or_null("travel_overlay")
	Input.action_press("boat_skip")
	await main._wait_frames(3)
	Input.action_release("boat_skip")
	await main._wait_frames(10)
	_ok(not hr.skipping_now and absf(hr.s - s1) < 0.05 and (ov == null or not ov._btn.visible), "지도 동안 Space — 건너뛰지 않음")
	if shots != "": await _shot("06_ride_map_halt")
	await _close(mp)
	await _sec(1.0)
	_ok(hr.halted and absf(hr.s - s1) < 0.05, "지도를 닫아도 선 채(S·지도에서 다시 간다)")
	# 4) 지도에서 [말로 이동] — 그 자리에서 새 길로 다시 출발 → 목적지 어귀에서 내림
	await _open(mp)
	mp.open_card(t1)
	_ok(not mp._ride_btn.disabled, "말 위 카드 — [말로 이동](새 길)")
	mp.card_ride()
	await _sec(1.5)
	_ok(not hr.halted and hr.v > 0.5, "다시 출발(v %.1f)" % hr.v)
	var stops: Array = []
	var cb := func(nid, why): stops.append([nid, why])
	hr.ride_done.connect(cb)
	w = 0
	while hr.mounted() and w < 6000: await main._wait_frames(1); w += 1
	print("MAPPIN ride1 stops=%s at=%s" % [stops, _pp()])
	_ok(not stops.is_empty() and String(stops[0][1]) in ["dest", "gate", "city", "event"], "목적지 쪽에서 내림(%s)" % [stops])
	if not stops.is_empty() and String(stops[0][1]) == "dest": _ok(_pp().distance_to(t1.c) < 260.0, "이백 마을 어귀(%.0fm)" % _pp().distance_to(t1.c))
	# 5) 성 안 핀 → 성문 앞에서 내림(성 안은 걸어서)
	var eup: Dictionary = hr.net.node_by["namwon_eup"]
	var t2 := { kind = "point", space = "JL_NAMWON_UNBONG", c = Vector2(float(eup.x), float(eup.z)), name = "읍성 안", key = "" }
	var pl: Dictionary = hr.pin_plan(t2)
	_ok(bool(pl.ok) and String(pl.c.node.kind) == "CITY", "성 안 핀 → 말 목적지는 읍성 어귀(%s %s)" % [pl.get("c", {}).get("name", "-"), pl.get("why", "")])
	if bool(pl.ok):
		stops.clear()
		await _open(mp)
		mp.open_card(t2)
		mp.card_ride()
		w = 0
		while hr.mounted() and w < 6000: await main._wait_frames(1); w += 1
		var gi_in: int = hr.net.nearest(_pp(), 14.0, true)
		var inside: bool = gi_in >= 0 and hr.net.city[gi_in] == 1
		print("MAPPIN ride2 stops=%s at=%s inside=%s" % [stops, _pp(), inside])
		_ok(not stops.is_empty() and not inside, "성문 앞에서 내림 — 성 안에 말을 들이지 않음(%s)" % [stops])
	hr.ride_done.disconnect(cb)
	# 6) 말 타는 곳이 멀다 → 걸어가라는 안내(순간이동 없음) → 그 자리에서 목적지 쪽 말 안내
	await _go(MARKET)
	await _open(mp)
	mp.open_card(t1)
	var pm := _pp()
	_ok(not mp._ride_btn.disabled and String(mp._ride_why.text).contains("걸어가서"), "말 타는 곳이 멀다 — 「%s」" % mp._ride_why.text)
	mp.card_ride()
	await main._wait_frames(6)
	_ok(mp.wp_event == "WALK_TO_MOUNT" and not hr.intent.is_empty() and not hr.mounted() and _pp().distance_to(pm) < 0.5, "걸어가라는 안내 — 말·순간이동 없음(%s)" % hr.intent.get("name", ""))
	if hud != null:
		await _sec(0.6)
		_ok(String(hud.text).begins_with("말 타는 곳"), "방위 줄 「%s」" % hud.text)
	if shots != "": await _shot("07_walk_to_mount_hud")
	var mpnt: Vector2 = hr.intent.p if not hr.intent.is_empty() else YARD
	await _go(mpnt)
	await _sec(2.5)
	print("MAPPIN prompt at mount: 「%s」" % hr.prompt)
	_ok(String(hr.prompt).contains("목적지 · " + String(t1.name)), "말 타는 곳에 닿으면 목적지 쪽 말 안내 「%s」" % hr.prompt)
	# 7) 다른 권역 목적지 → 그쪽 노정 길 끝까지 말(큰길이 이어진 말 타는 곳에서) · 걷기 목적지 후보 맨 앞이 그쪽 길 끝 · 방위 줄은 길 끝
	hr.intent = {}
	var th := WaypointPlan.region_target("GG_HANYANG", "한양")
	Progress.set_waypoint({ space = "GG_HANYANG", x = th.c.x, z = th.c.y, name = "한양", key = "region:GG_HANYANG", state = "known", kind = "region", node = String(th.get("node", "")) })
	var plh: Dictionary = hr.pin_plan(th)
	print("MAPPIN hanyang plan ok=%s why=%s goal=%s walk_to=%s" % [plh.ok, plh.get("why", ""), plh.get("c", {}).get("name", "-"), plh.get("walk_to", {}).get("name", "-")])
	_ok(bool(plh.ok) and bool(plh.c.cross) and String(plh.c.node.kind) == "ROUTE_END", "다른 권역 목적지 — 말은 그쪽 길 끝 %s까지" % plh.get("c", {}).get("name", "-"))
	if bool(plh.ok):
		if not (plh.walk_to as Dictionary).is_empty(): await _go(plh.walk_to.p)
		# 그 말 타는 곳은 길 끝 바로 곁(PIN_NEAR 안 — 탈 까닭 없음)일 수 있다: 같은 큰길에서 400~900m 떨어진 점에서 후보를 센다
		var djs: Dictionary = hr.net.dijkstra(int(plh.src))
		var gi := -1
		for i in hr.net.pts.size():
			if float(djs.dist[i]) > 400.0 and float(djs.dist[i]) < 900.0: gi = i; break
		hr._build_choices(gi if gi >= 0 else int(plh.src))
		var c0: Dictionary = hr.choices[0] if not hr.choices.is_empty() else {}
		_ok(bool(c0.get("pin", false)) and String(c0.node.kind) == "ROUTE_END" and String(c0.name).contains("한양"), "말 타는 곳에서 말 후보 맨 앞 「%s」" % c0.get("name", "-"))
	if hud != null:
		await _sec(0.6)
		_ok(String(hud.text).contains("한양") and String(hud.text).contains("길목"), "방위 줄 — 그쪽 길 끝 「%s」" % hud.text)
	Progress.clear_waypoint()

# ==================================================================================
# 화면(창): 1280×720·1920×1080 각각 — tools 없이 --resolution으로
func _shots(mp) -> void:
	HorseRide.discover("JL_NAMWON_UNBONG", "inwol_yeok")
	await _go(YARD)
	await _open(mp)
	await _view(mp, mp.tier2_k() * 1.25, _pp() + Vector2(-260, -160))
	var pe: Vector2 = _empty_px(mp, true)
	await _click(mp, pe)
	await _sec(0.5)
	await _shot("01_card_point_preview")
	await _view(mp, mp._k_min, _pp())
	var hk = _hit_where(mp, func(pl): return String(pl.kind) in ["town", "landmark", "pass"] and Discovery.state(String(pl.space), String(pl.key)) == Discovery.KNOWN)
	if hk != null:
		await _click(mp, hk.p)
		await _sec(0.5)
		await _shot("02_card_known_unvisited")
		mp._wp_btn.pressed.emit()
	mp._refresh_dynamic()
	await _view(mp, mp.tier2_k() * 1.3, Vector2(2507.5, -1506.0))
	var hs = _hit_where(mp, func(pl): return String(pl.kind) == "station" and String(pl.get("station_id", "")) == "inwol")
	if hs != null:
		await _click(mp, hs.p)
		await _sec(0.5)
		await _shot("03_card_station_fast")
	mp.card_close()
	await _view(mp, mp.tier3_k(), _pp())
	await _shot("04_waypoint_edge_arrow")
	mp.show_mode("nation")
	await mp._redraw_wait()
	mp.open_card(WaypointPlan.region_target("GG_HANYANG", "한양"))
	await _sec(0.4)
	await _shot("05_nation_card_hanyang")
	await _close(mp)
	Progress.clear_waypoint()
	await _ride_part(mp)
