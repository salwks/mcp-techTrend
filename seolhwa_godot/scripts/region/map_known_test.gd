# 지도 세 단계(C65) 시험 — region_map이 --knowntest를 보면 부른다. 끝 줄: MAPKNOWNTEST PASS / FAIL n
#   1 권역 진입 → 상식 목록이 모두 KNOWN(VISITED 아님) · 사건 장소(place:)·월매 집·외딴집·주막·방앗간은 UNKNOWN
#   2 들음(tell) → KNOWN("told") · 3 다가감 → VISITED · 4 KNOWN은 역참·역마·깃발(travel_nodes) 조건을 채우지 않는다
#   5 옛 저장(visited/told만) → 상식이 채워지고 옛 값은 그대로 · 6 그림: KNOWN 이름표는 옅게(faint), VISITED는 보통 — 글 크기는 같다
#   7 범례에 '가 본 곳'·'아는 곳'
#   godot --path . res://scenes/region.tscn -- --region=JL_NAMWON_UNBONG --notitle --knowntest --savefile=user://st_known.json
extends RefCounted

const Discovery := preload("res://scripts/region/discovery.gd")
const Progress := preload("res://scripts/region/progress.gd")
const RegionKnown := preload("res://scripts/region/region_known.gd")
const UiFonts := preload("res://scripts/ui_fonts.gd")

static func run(map) -> void:
	var m = map.get_parent()
	var tree: SceneTree = map.get_tree()
	while m._loading: await tree.process_frame
	for i in 20: await tree.process_frame
	var sp: String = map._space
	var fails: Array = []
	var ok := func(c: bool, what: String) -> void:
		print("KNOWN %s %s" % ["ok  " if c else "FAIL", what])
		if not c: fails.append(what)
	ok.call(map.rk_missing.is_empty(), "상식 목록이 모두 지도에 있다 %s" % [map.rk_missing])
	ok.call(not map._rk_keys.is_empty(), "상식 키 %d개" % map._rk_keys.size())
	var tn_before := JSON.stringify(Progress.data().get("travel_nodes", {}))
	var nation_before := JSON.stringify(Progress.known(Discovery.NATION))
	# 1 진입: 저장을 비우고(새 게임과 같다) 상식만 적는다 — 아직 아무 데도 가지 않았다
	Progress.known(sp).clear()
	var n: int = map.grant_region_known()
	ok.call(n == map._rk_keys.size(), "진입 → 상식 %d개 KNOWN" % n)
	var all_known := true
	for k in map._rk_keys:
		if Discovery.state(sp, k) != Discovery.KNOWN: all_known = false; print("KNOWN   not KNOWN ", k)
	ok.call(all_known, "상식 키는 모두 KNOWN(VISITED 아님)")
	for k in Progress.known(sp):
		if String(k).begins_with("place:"): ok.call(false, "사건 장소가 자동으로 적힘 " + String(k))
	for k in Progress.known(sp):
		for w in ["주막", "물레방앗간", "외딴집", "월매", "옥@"]:
			if String(k).contains(w): ok.call(false, "생활시설·사적 공간이 자동으로 적힘 " + String(k))
	var gwang := _bld(map, "광한루")
	var dongheon := _bld(map, "동헌")
	if sp == "JL_NAMWON_UNBONG":
		ok.call(gwang != "" and Discovery.state(sp, gwang) == Discovery.KNOWN, "남원: 광한루 KNOWN (%s)" % gwang)
		ok.call(dongheon != "" and Discovery.state(sp, dongheon) == Discovery.KNOWN, "남원: 동헌(관아) KNOWN (%s)" % dongheon)
		ok.call(Discovery.state(sp, "lm:gwanghallu") == Discovery.KNOWN and Discovery.state(sp, "lm:namwon_dongheon") == Discovery.KNOWN, "남원: 이름난 곳 광한루·관아 KNOWN")
		ok.call(not Discovery.is_visited(sp, "lm:gwanghallu"), "남원: 광한루는 아직 VISITED 아님")
		for k in ["place:wolmae_house", "place:house", "place:north_pass", "place:clearing", "place:jail"]:
			ok.call(Discovery.state(sp, k) == Discovery.UNKNOWN, "남원: %s UNKNOWN" % k)
		var jm := _bld(map, "주막"); var mb := _bld(map, "물레방앗간")
		ok.call(jm != "" and Discovery.state(sp, jm) == Discovery.UNKNOWN and mb != "" and Discovery.state(sp, mb) == Discovery.UNKNOWN, "남원: 주막·물레방앗간 UNKNOWN")
	# 1b 사건 map_places(지금 공간 사건) — 상식이 건드리지 않는다
	var st = map._story()
	if st != null and not st.data.is_empty():
		for p in st.data.get("map_places", []):
			ok.call(not Discovery.is_known(sp, "place:" + String(p.id)) or bool(p.get("start_known", false)), "사건 장소 place:%s 자동 아님" % p.id)
	# 4 역참·역마·깃발: KNOWN이 가 봄을 대신하지 않는다
	ok.call(JSON.stringify(Progress.data().get("travel_nodes", {})) == tn_before, "상식이 travel_nodes(역참·깃발 가 봄)를 바꾸지 않는다")
	ok.call(JSON.stringify(Progress.known(Discovery.NATION)) == nation_before, "상식이 전국 지도(권역·거점) 키를 바꾸지 않는다")
	var Stations: Script = load("res://scripts/region/stations.gd")
	var HR: Script = load("res://scripts/region/horse_ride.gd")
	var st_bad := []
	for s in Stations.in_space(sp):
		var was: bool = HR.is_discovered(sp, String(s.node))
		if Stations.known(String(s.id)) != was: st_bad.append(s.id)
		var stt: Dictionary = Stations.state(String(s.id))
		if not was and bool(stt.ok): st_bad.append(String(s.id) + "(역마 됨)")
	ok.call(st_bad.is_empty(), "역참 가 봄·역마 조건은 travel_nodes 그대로 %s (역 %d)" % [st_bad, Stations.in_space(sp).size()])
	# 2 들음 → KNOWN
	Discovery.tell(sp, "place:north_pass")
	ok.call(Discovery.state(sp, "place:north_pass") == Discovery.KNOWN and Discovery.how(sp, "place:north_pass") == "told", "들음(told) → KNOWN")
	# 6a 그림(KNOWN): 상식 건물(광한루 먼저)을 가운데 두고 2단계 이상으로 — 이름표가 옅다(솎기로 빠진 건물은 건너뛰고 다음 것)
	if map.get_viewport().get_visible_rect().size.y < 700: tree.root.size = Vector2i(1024, 768)   # 헤드리스: 1024×768
	await tree.process_frame
	map.page = 0
	if not map.visible: map.toggle()
	var cands: Array = []
	if gwang != "": cands.append(gwang)
	for k in map._rk_keys:
		var ci = _item_of(map, String(k))
		if ci != null and int(ci.tier) == 2 and not cands.has(String(k)): cands.append(String(k))
	var it = null
	var target := ""
	var lab = null
	for k in cands:
		var ci = _item_of(map, k)
		map._set_view("city", maxf(map.tier2_k() * 1.2, map._city_k() * 1.2), ci.c)
		await map._redraw_wait()
		lab = _placed(map, String(ci.name))
		if lab != null: it = ci; target = k; break
	ok.call(it != null, "그림 시험 건물 %s (후보 %d)" % [target, cands.size()])
	if it == null:
		_end(m, fails); return
	ok.call(bool(lab.faint), "그림: KNOWN '%s' 이름표 옅음 %s" % [it.name, lab])
	var sz_known: int = int(lab.size) if lab != null else -1
	# 3 다가감 → VISITED (그 자리에 선 것으로 셈)
	var keep: Vector3 = map._player
	map._player = Vector3(it.c.x, 0.0, it.c.y)
	map._update_discovery()
	map._player = keep
	ok.call(Discovery.state(sp, target) == Discovery.VISITED, "다가감 → VISITED " + target)
	if sp == "JL_NAMWON_UNBONG": ok.call(Discovery.is_visited(sp, "lm:gwanghallu"), "광한루 이름난 곳도 VISITED")
	map._center = it.c
	await map._redraw_wait()
	lab = _placed(map, String(it.name))
	ok.call(lab != null and not bool(lab.faint), "그림: VISITED '%s' 이름표 보통 %s" % [it.name, lab])
	ok.call(lab != null and int(lab.size) == sz_known and sz_known >= UiFonts.MAP_MIN, "그림: KNOWN·VISITED 글 크기 같음(%d)" % sz_known)
	# 7 범례
	var lg := []
	for e in map.LEGEND: lg.append(String(e[0]))
	ok.call(lg.has("known") and lg.has("visited"), "범례에 아는 곳·가 본 곳")
	map.set_page(1)
	await map._redraw_wait()
	var cols: int = map.legend_cols()
	var colw: float = map._legend.size.x / float(cols)
	for e in map.LEGEND:
		if map.LEGEND_ICON_W + 6.0 + map._font.get_string_size(String(e[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, UiFonts.MAP_PANEL).x > colw + 0.5: ok.call(false, "범례 '%s' 칸 넘침" % e[1])
	map.set_page(0)
	# 5 옛 저장: visited/told만 있는 이 공간 → 다음 진입(지도 발견 셈)에 상식이 채워지고 옛 값은 그대로
	var old := { "town:%s" % String(map._towns[0][0]): "visited", "place:north_pass": "told" }
	if gwang != "": old[gwang] = "visited"
	Progress.data().known[sp] = old.duplicate()
	map._update_discovery()
	var ok_old := true
	for k in old:
		if Discovery.how(sp, k) != String(old[k]): ok_old = false; print("KNOWN   old changed ", k, " ", Discovery.how(sp, k))
	ok.call(ok_old, "옛 저장 값(visited·told)은 그대로")
	var filled := 0
	for k in map._rk_keys:
		if Discovery.is_known(sp, k): filled += 1
	ok.call(filled == map._rk_keys.size(), "옛 저장에 상식 %d/%d 채움" % [filled, map._rk_keys.size()])
	if dongheon != "": ok.call(Discovery.state(sp, dongheon) in [Discovery.KNOWN, Discovery.VISITED], "옛 저장: 동헌 보임")
	# 저장 파일로 다시 읽어도 같다(디스크 왕복)
	Progress.save()
	var path := Progress.path
	Progress.use_path(path)
	ok.call(Discovery.how(sp, "place:north_pass") == "told" and Discovery.is_known(sp, map._rk_keys[0]), "저장 왕복 뒤에도 told·known 그대로")
	_end(m, fails)

static func _end(m, fails: Array) -> void:
	if fails.is_empty(): print("MAPKNOWNTEST PASS states/transitions/gating/render")
	else: print("MAPKNOWNTEST FAIL %d %s" % [fails.size(), fails.slice(0, 6)])
	m._quit()

static func _bld(map, nm: String) -> String:
	for it in map._items:
		if String(it.name) == nm: return Discovery.bld_key(String(it.name), it.c)
	return ""

static func _first_bld(map) -> String:
	for k in map._rk_keys:
		if String(k).begins_with("bld:"):
			var it = _item_of(map, String(k))
			if it != null and int(it.tier) == 2: return String(k)
	return ""

static func _item_of(map, key: String):
	for it in map._items:
		if Discovery.bld_key(String(it.name), it.c) == key: return it
	return null

static func _placed(map, text: String):
	for q in map.placed:
		if String(q.text) == text: return q
	return null

# --knownshots=<폴더>: 첫 진입(상식 KNOWN — 옅게) · 광한루(또는 첫 상식 건물)에 가 본 뒤(보통) · 범례 — 창 모드로 찍는다
#   godot --path . res://scenes/region.tscn -- --region=JL_NAMWON_UNBONG --notitle --knownshots=shots/map_known_states --savefile=user://st_knownshots.json
static func shots(map, dir: String) -> void:
	var m = map.get_parent()
	var tree: SceneTree = map.get_tree()
	while m._loading: await tree.process_frame
	for i in 30: await tree.process_frame
	var out: String = m._abs(dir)
	DirAccess.make_dir_recursive_absolute(out)
	var tag: String = { "JL_NAMWON_UNBONG": "namwon", "GG_HANYANG": "hanyang" }.get(map._space, String(map._space).to_lower())
	var sp: String = map._space
	# 첫 진입: 지금 고을(시작 자리 둘레 가 봄)만 남기고 상식을 적은 상태 — 새 게임과 같다
	map.grant_region_known()
	var target := _bld(map, "광한루")
	if target == "": target = _first_bld(map)
	var it = _item_of(map, target)
	map.page = 0
	if not map.visible: map.toggle()
	var home = map._town_at(it.c if it != null else Vector2(map._player.x, map._player.z))
	if home != null: map._show_city(home)
	await _shot(map, out.path_join("%s_first_entry_city.png" % tag))
	if it != null:
		map._set_view("city", maxf(map.tier2_k() * 1.3, map._city_k() * 1.6), it.c)
		await _shot(map, out.path_join("%s_first_entry_close.png" % tag))
	map._show_all()
	await _shot(map, out.path_join("%s_first_entry_region.png" % tag))
	if it != null and m.args.has("knownvisit"):
		# 광한루에 가 봄(그 자리에 선 것으로 셈) — 같은 자리를 다시 찍는다
		var keep: Vector3 = map._player
		map._player = Vector3(it.c.x, 0.0, it.c.y)
		map._update_discovery()
		map._player = keep
		print("KNOWNSHOT visited %s → %d" % [target, Discovery.state(sp, target)])
		map._set_view("city", maxf(map.tier2_k() * 1.3, map._city_k() * 1.6), it.c)
		await _shot(map, out.path_join("%s_after_visit_close.png" % tag))
		if home != null: map._show_city(home)
		await _shot(map, out.path_join("%s_after_visit_city.png" % tag))
	map.set_page(1)
	if home != null: map._show_city(home)
	await _shot(map, out.path_join("%s_legend.png" % tag))
	map.set_page(0)
	m._quit()

static func _shot(map, f: String) -> void:
	map._after_view()
	for i in 5: await RenderingServer.frame_post_draw
	var img: Image = map.get_viewport().get_texture().get_image()
	if img != null: img.save_png(f); print("KNOWNSHOT ", f, " labels=", map.placed.map(func(q): return "%s%s" % [q.text, "(옅음)" if bool(q.get("faint", false)) else ""]))
