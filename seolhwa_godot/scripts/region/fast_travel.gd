# 역마 — 알게 된 거점으로 빠른 이동(이동수단 개선안 v1.0 §10·§11·§27·§28·§29). H(지도에서도 H)로 연다.
#   - 거점: region_data/travel/<공간>.json nodes 중 fast(대표 고을·위성 마을·큰 주막·역·나루·중요한 고개·이야기 거점·노정 끝)이고
#     가 본 곳(horse_ride.discover — 거점 구역에 들면 progress.json travel_nodes에 적힌다). 지나온 노정의 양 끝은 처음부터 안다(예전 역마 저장 호환).
#   - 다른 공간으로: 공간 그래프(권역 ↔ 노정)에서 지나는 노정이 모두 '지나옴'(routes_done)이어야 한다 — 처음 가는 길은 건너뛸 수 없다
#     (§10·§18: 제주 첫 뱃길도 남해 뱃길을 한 번 건너야 열린다). 끝까지 안 지난 노정 안에서는 들어온 쪽으로만 나간다.
#   - 표현(§11): 지도 위 지금 자리 → 이동선 → 목적지가 그려지며 시각이 흐르고(날씨가 바뀔 수 있음) 도착. 삯 없음(§29: 메인 진행을 막지 않음).
# 조작: ↑↓(W·S) 고르기 · Enter·E·Space 간다 · Esc·H 닫기 · 클릭(한 번 고르고 한 번 더 누르면 간다)
extends CanvasLayer

const RideNet := preload("res://scripts/region/ride_net.gd")
const HorseRide := preload("res://scripts/region/horse_ride.gd")
const Progress := preload("res://scripts/region/progress.gd")
const Travel := preload("res://scripts/region/travel.gd")
const Discovery := preload("res://scripts/region/discovery.gd")
const PAPER := Color("#efe6d2")
const INK := Color("#2b2622")
const INK_SOFT := Color("#5a5048")
const SEAL := Color("#a8443c")
const HORSE_KMH := 7.0          # 역마 하루 길(쉬는 때 포함 평균)
const ANIM := 2.8

var main
var prefer := ""
var items: Array = []
var sel := 0
var here := ""
var here_ll = null
var _canvas: Control
var _font: SystemFont
var _anim := -1.0
var _go: Dictionary = {}
var _was_paused := false
var _k := 1.0
var _list_top := 0
var test_pick := ""             # 시험: 이 거점 id를 골라 바로 간다

func _init(m, prefer_portal := "") -> void:
	main = m
	prefer = prefer_portal
	layer = 32
	name = "fast_travel"
	process_mode = Node.PROCESS_MODE_ALWAYS

func _ready() -> void:
	_font = SystemFont.new()
	_font.font_names = PackedStringArray(["AppleMyungjo", "Nanum Myeongjo", "NanumMyeongjo", "Batang", "Noto Serif CJK KR", "Apple SD Gothic Neo"])
	_k = clampf(get_viewport().get_visible_rect().size.y / 768.0, 0.8, 2.4)
	_was_paused = get_tree().paused
	get_tree().paused = true
	var dim := ColorRect.new(); dim.color = Color(0, 0, 0, 0.5); dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	_canvas = Control.new(); _canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.draw.connect(_draw)
	_canvas.gui_input.connect(_on_input)
	add_child(_canvas)
	if main.horse_ride != null: main.horse_ride.set_fast_travel(true)
	_gather()
	print("FAST open here=%s items=%d ok=%d" % [here, items.size(), items.filter(func(i): return i.ok).size()])
	_canvas.queue_redraw()

func _exit_tree() -> void:
	if get_tree() != null and _anim < 0.0: get_tree().paused = _was_paused

# ---- 후보 ----
func _gather() -> void:
	here = String(main.world.region.get("route_id", main.world.region.get("region_id", "")))
	here_ll = _ll(here, Vector2(main.player_pos.x, main.player_pos.z))
	var reach := _reachable()
	var pp := Vector2(main.player_pos.x, main.player_pos.z)
	var out := []
	for sp in RideNet.all_spaces():
		var d: Dictionary = RideNet.read(sp)
		for n in d.get("nodes", []):
			if not bool(n.get("fast", false)): continue
			var known := HorseRide.is_discovered(sp, String(n.id)) or _done_end(sp, n)
			if not known: continue
			var a: Array = n.get("arrive", [n.x, n.z])
			var at := Vector2(float(a[0]), float(a[1]))
			var it := { space = sp, node = n, id = String(n.id), name = String(n.name), at = at, same = sp == here, ok = true, why = "",
				space_name = _space_name(sp), kind = String(n.kind) }
			if sp == here:
				if at.distance_to(pp) < 80.0: continue
				it.dist = at.distance_to(pp)
			elif not reach.has(sp):
				it.ok = false
				it.why = "처음 가는 길은 걸어서(말 타고) 가 봐야 한다"
			else:
				it.dist = 1e7 + float(reach[sp].size()) * 1e5
				it.via = reach[sp]
			out.append(it)
	out.sort_custom(func(a, b):
		if a.ok != b.ok: return a.ok
		if a.same != b.same: return a.same
		if a.space != b.space: return String(a.space_name) < String(b.space_name)
		return float(a.get("dist", 0.0)) < float(b.get("dist", 0.0)))
	items = out
	sel = 0
	# 지나온 노정 포털 곁에서 열었으면 그 노정 먼 끝을 먼저
	if prefer != "":
		for pt in main.portals:
			if String(pt.id) != prefer: continue
			var ft := Travel.fast_target(String(pt.target), String(main.world.region.get("region_id", "")))
			if ft.is_empty(): break
			for i in items.size():
				var it: Dictionary = items[i]
				if it.ok and String(it.space) == String(ft.target) and Vector2(float(ft.tx), float(ft.tz)).distance_to(it.at) < 80.0: sel = i; break
	if test_pick != "":
		for i in items.size():
			if String(items[i].id) == test_pick or "%s/%s" % [items[i].space, items[i].id] == test_pick: sel = i

# 노정을 지나왔으면 그 노정의 양 끝(노정 안 끝·권역 쪽 포털 끝)은 아는 곳
func _done_end(sp: String, n: Dictionary) -> bool:
	if String(n.kind) != "ROUTE_END": return false
	if Progress.route_done(sp): return true
	var tgt := String(n.get("target", ""))
	return tgt != "" and Progress.route_done(tgt)

# 공간 그래프 너비 우선: {공간: [지나는 공간들]} — 지나는 노정은 '지나옴'이어야 하고, 안 지난 노정 안이면 들어온 쪽으로만 나간다
func _reachable() -> Dictionary:
	var adj := {}
	for r in Travel.routes():
		var ps = r.json.get("portals", {})
		if not (ps is Dictionary): continue
		for e in ps:
			var p = ps[e]
			if not (p is Dictionary): continue
			var o := String(p.get("region", p.get("route", "")))
			if o == "": continue
			if not adj.has(r.id): adj[r.id] = []
			if not adj.has(o): adj[o] = []
			if not adj[r.id].has(o): adj[r.id].append(o)
			if not adj[o].has(r.id): adj[o].append(r.id)
	var is_route := {}
	for r in Travel.routes(): is_route[r.id] = true
	var out := { here: [] }
	var q := [here]
	var first := true
	while not q.is_empty():
		var u: String = q.pop_front()
		var nbrs: Array = adj.get(u, [])
		if first and is_route.has(u) and not Progress.route_done(u):
			# 들어온 끝 쪽만(포털 id <노정>_<끝>)
			var entry := String(main.get("_route_entry"))
			var end := entry.trim_prefix(u + "_")
			var p = main.world.region.get("portals", {}).get(end) if main.world.region.get("portals") is Dictionary else null
			nbrs = [String(p.get("region", p.get("route", "")))] if p is Dictionary else []
		first = false
		for w in nbrs:
			if out.has(w): continue
			out[w] = (out[u] as Array) + [w]
			if is_route.has(w) and not Progress.route_done(w): continue   # 안 지난 노정: 그 안 아는 거점까지만, 넘어가지 않는다
			q.append(w)
	return out

func _space_name(sp: String) -> String:
	for r in Travel.routes():
		if r.id == sp: return String(r.get("short", r.name))
	var info := Travel.region_info(sp)
	return String(info.get("short", info.get("name", sp)))

# 공간 좌표 → 경위도(전국 지도)
func _ll(sp: String, p: Vector2):
	var d: Dictionary = RideNet.read(sp)
	if d.get("projection") is Dictionary: return Travel.local_to_lonlat({ projection = d.projection }, p.x, p.y)
	var gl: Array = d.get("geo_line", [])
	if gl.size() >= 2:
		# 가장 가까운 거점의 t(진행도)로 geo_line 위 자리
		var t := 0.5; var bd := INF
		for n in d.get("nodes", []):
			var dd := Vector2(float(n.x), float(n.z)).distance_to(p)
			if dd < bd: bd = dd; t = float(n.get("t", 0.5))
		var line := PackedVector2Array()
		for g in gl: line.append(Vector2(float(g[0]), float(g[1])))
		return _poly_at(line, t)
	var info := Travel.region_info(sp)
	return info.get("lonlat")

static func _poly_at(px: PackedVector2Array, f: float) -> Vector2:
	var total := 0.0
	for i in px.size() - 1: total += px[i].distance_to(px[i + 1])
	var want := total * clampf(f, 0.0, 1.0)
	for i in px.size() - 1:
		var l := px[i].distance_to(px[i + 1])
		if want <= l: return px[i].lerp(px[i + 1], want / maxf(l, 1e-6))
		want -= l
	return px[px.size() - 1]

# ---- 가기 ----
func _confirm() -> void:
	if items.is_empty() or _anim >= 0.0: return
	var it: Dictionary = items[sel]
	if not bool(it.ok):
		return
	var km := 0.0
	if it.same:
		km = _road_km(it)
	else:
		var a = here_ll; var b = _ll(String(it.space), it.at)
		if a != null and b != null: km = _geo_km(a, b) * 1.25
	var hours := clampf(km / HORSE_KMH, 0.3, 60.0)
	var h0: float = main.hour
	_go = { it = it, hours = hours, h0 = h0, h1 = fposmod(h0 + hours, 24.0), km = km }
	_anim = 0.0
	print("FAST go %s/%s km=%.1f hours=%.1f" % [it.space, it.id, km, hours])

func _road_km(it: Dictionary) -> float:
	var hr = main.horse_ride
	var pp := Vector2(main.player_pos.x, main.player_pos.z)
	var K := float(main.world.K) if main.world.K > 0.0 else 0.3
	if hr != null and hr.net != null and hr.net.pts.size() > 1:
		var a: int = hr.net.nearest(pp, 400.0, true); var b: int = hr.net.nearest(it.at, 400.0, true)
		if a >= 0 and b >= 0:
			var dj: Dictionary = hr.net.dijkstra(a)
			var d := float(dj.dist[b])
			if not is_inf(d): return (d + pp.distance_to(hr.net.pts[a]) + it.at.distance_to(hr.net.pts[b])) / K / 1000.0
	return pp.distance_to(it.at) * 1.3 / K / 1000.0

static func _geo_km(a: Vector2, b: Vector2) -> float:
	var R := 6371.0
	var la1 := deg_to_rad(a.y); var la2 := deg_to_rad(b.y)
	var dla := la2 - la1; var dlo := deg_to_rad(b.x - a.x)
	var h := sin(dla / 2) * sin(dla / 2) + cos(la1) * cos(la2) * sin(dlo / 2) * sin(dlo / 2)
	return 2.0 * R * asin(sqrt(h))

func _process(delta: float) -> void:
	if _anim < 0.0: return
	_anim += delta / ANIM
	_canvas.queue_redraw()
	if _anim >= 1.0: _arrive()

func _arrive() -> void:
	var g := _go
	_anim = -1.0
	get_tree().paused = _was_paused
	var it: Dictionary = g.it
	main.hour = float(g.h1)
	var w = main.weather
	if w != null and float(g.hours) >= 2.0 and String(w.forced) == "" and not w.is_forced() and randf() < 0.6: w._roll()
	main._apply_time()
	if main.horse_ride != null: main.horse_ride.set_fast_travel(false)
	print("FAST arrive %s/%s hour=%.1f" % [it.space, it.id, main.hour])
	if it.same:
		var st = main.story
		if st != null and st.get("ui") != null: await st.ui.fade(true, 0.3)
		main.teleport(it.at.x, it.at.y)
		main.rig.update(0, main.player_pos, main.player.facing, null, true)
		HorseRide.discover(String(it.space), String(it.id))
		if main.horse_ride != null: main.horse_ride.on_arrived(it.at)
		main._show_hud("역마 — %s에 닿았다" % String(it.name))
		if st != null and st.get("ui") != null: st.ui.fade(false, 0.5)
		queue_free()
		return
	var kind := "route" if Travel.find_route_dir(String(it.space)) != "" else "region"
	var pt := { id = "fast_node_%s" % it.id, kind = kind, target = String(it.space), tx = it.at.x, tz = it.at.y,
		label = "%s %s (역마)" % [String(it.space_name), String(it.name)], fast = true }
	queue_free()
	main._travel(pt)

func close() -> void:
	if _anim >= 0.0: return
	get_tree().paused = _was_paused
	if main.horse_ride != null: main.horse_ride.set_fast_travel(false)
	queue_free()

func _unhandled_input(ev: InputEvent) -> void:
	if not (ev is InputEventKey and ev.pressed and not ev.echo): return
	if _anim >= 0.0: get_viewport().set_input_as_handled(); return
	match ev.physical_keycode:
		KEY_UP, KEY_W: sel = posmod(sel - 1, maxi(1, items.size()))
		KEY_DOWN, KEY_S: sel = posmod(sel + 1, maxi(1, items.size()))
		KEY_ENTER, KEY_KP_ENTER, KEY_E, KEY_SPACE: _confirm()
		KEY_ESCAPE, KEY_H, KEY_M, KEY_TAB: close()
		_: return
	get_viewport().set_input_as_handled()
	_canvas.queue_redraw()

func _on_input(e: InputEvent) -> void:
	if not (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) or _anim >= 0.0: return
	var i := _row_at(e.position)
	if i < 0: return
	if i == sel: _confirm()
	else: sel = i
	_canvas.queue_redraw()

# ---- 그리기 ----
func _panel() -> Rect2:
	var vs := get_viewport().get_visible_rect().size
	return Rect2(vs * Vector2(0.05, 0.07), vs * Vector2(0.9, 0.86))

func _list_rect() -> Rect2:
	var p := _panel()
	return Rect2(p.position + Vector2(24, 76) * _k, Vector2(p.size.x * 0.38, p.size.y - 120 * _k))

func _map_rect() -> Rect2:
	var p := _panel(); var l := _list_rect()
	return Rect2(Vector2(l.end.x + 20 * _k, l.position.y), Vector2(p.end.x - l.end.x - 44 * _k, l.size.y))

func _row_h() -> float: return 30.0 * _k

func _rows_visible() -> int: return maxi(1, int(_list_rect().size.y / _row_h()))

func _row_at(p: Vector2) -> int:
	var lr := _list_rect()
	if not lr.has_point(p): return -1
	var i := _list_top + int((p.y - lr.position.y) / _row_h())
	return i if i < items.size() else -1

func _text(s: String, at: Vector2, size: int, col: Color, center := false) -> void:
	var sz := int(size * _k)
	var x := at.x - (_font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x / 2.0 if center else 0.0)
	_canvas.draw_string(_font, Vector2(x, at.y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, col)

func _draw() -> void:
	var p := _panel()
	_canvas.draw_rect(p, Color(PAPER.r, PAPER.g, PAPER.b, 0.98))
	_canvas.draw_rect(p, INK, false, 3.0)
	_text("역마 — 가 본 곳으로", p.position + Vector2(24, 44) * _k, 30, INK)
	_text("삯 없음 · 처음 가는 길은 건너뛸 수 없다", p.position + Vector2(p.size.x - 360 * _k, 44 * _k), 15, INK_SOFT)
	# 목록
	var lr := _list_rect()
	var nv := _rows_visible()
	if sel < _list_top: _list_top = sel
	if sel >= _list_top + nv: _list_top = sel - nv + 1
	if items.is_empty():
		_text("아직 가 본 거점이 없다 — 고을·주막·나루에 들르면 적힌다", lr.position + Vector2(0, 24 * _k), 17, INK_SOFT)
	var last_space := ""
	for r in range(_list_top, mini(items.size(), _list_top + nv)):
		var it: Dictionary = items[r]
		var y := lr.position.y + (r - _list_top) * _row_h() + 22 * _k
		var on := r == sel
		var col := SEAL if on else (INK if it.ok else Color(INK_SOFT.r, INK_SOFT.g, INK_SOFT.b, 0.6))
		var sp := "" if String(it.space) == last_space else String(it.space_name) + " · "
		last_space = String(it.space)
		_text(("▸ " if on else "   ") + sp + String(it.name), Vector2(lr.position.x, y), 19, col)
	# 지도
	var mr := _map_rect()
	_canvas.draw_rect(mr, Color(0.93, 0.90, 0.83))
	_canvas.draw_rect(mr, INK_SOFT, false, 1.5)
	if not items.is_empty():
		var it: Dictionary = items[sel]
		if it.same: _draw_local(mr, it)
		else: _draw_nation(mr, it)
		var foot := String(it.why) if not it.ok else ("Enter 간다 · ↑↓ 고르기 · Esc 닫기")
		if _anim >= 0.0:
			foot = "길에서 약 %s — %s → %s" % [_dur_text(float(_go.hours)), _clock(float(_go.h0)), _clock(lerpf(float(_go.h0), float(_go.h0) + float(_go.hours), clampf(_anim, 0.0, 1.0)))]
		_text(foot, Vector2(mr.position.x, mr.end.y + 30 * _k), 17, INK if it.ok else SEAL)

static func _clock(h: float) -> String:
	var hh := fposmod(h, 24.0)
	var ih := int(hh)
	var tag := "새벽" if ih < 5 else ("아침" if ih < 9 else ("낮" if ih < 17 else ("저녁" if ih < 20 else "밤")))
	var h12 := ih % 12
	if h12 == 0: h12 = 12
	return "%s %d시" % [tag, h12]

static func _dur_text(h: float) -> String:
	if h >= 24.0: return "%d일 %d시간" % [int(h / 24.0), int(fmod(h, 24.0))]
	if h >= 1.0: return "%d시간" % int(round(h))
	return "%d분" % int(round(h * 60.0))

# 같은 공간: 큰길 그래프와 가 본 거점, 지금 자리 → 목적지 길(다익스트라)
func _draw_local(mr: Rect2, it: Dictionary) -> void:
	var hr = main.horse_ride
	var pp := Vector2(main.player_pos.x, main.player_pos.z)
	var line := PackedVector2Array([pp, it.at])
	if hr != null and hr.net != null and hr.net.pts.size() > 1:
		var a: int = hr.net.nearest(pp, 400.0, true); var b: int = hr.net.nearest(it.at, 400.0, true)
		if a >= 0 and b >= 0:
			var ids: PackedInt32Array = hr.net.path_ids(hr.net.dijkstra(a), b)
			if ids.size() >= 2:
				line = PackedVector2Array([pp])
				for i in ids: line.append(hr.net.pts[i])
				line.append(it.at)
	var bb := Rect2(pp, Vector2.ZERO)
	for q in line: bb = bb.expand(q)
	bb = bb.grow(maxf(bb.size.x, bb.size.y) * 0.15 + 60.0)
	var sc := minf(mr.size.x / bb.size.x, mr.size.y / bb.size.y)
	var off := mr.get_center() - bb.get_center() * sc
	var X := func(g: Vector2) -> Vector2: return g * sc + off
	if hr != null and hr.net != null:
		for i in hr.net.pts.size():
			var pi: Vector2 = hr.net.pts[i]
			if not bb.has_point(pi): continue
			for k in hr.net.nb[i]:
				if k > i: _canvas.draw_line(X.call(pi), X.call(hr.net.pts[k]), Color(0.72, 0.62, 0.46), 2.0)
	for o in items:
		if o.same and bb.has_point(o.at):
			_canvas.draw_circle(X.call(o.at), 4.0 * _k, INK_SOFT)
			_text(String(o.name), X.call(o.at) + Vector2(6, -6) * _k, 13, INK_SOFT)
	_draw_route_line(line, X)
	_canvas.draw_circle(X.call(pp), 7.0 * _k, Color(0.75, 0.15, 0.1))
	_text("여기", X.call(pp) + Vector2(8, 16) * _k, 14, SEAL)

func _draw_route_line(line: PackedVector2Array, X: Callable) -> void:
	var px := PackedVector2Array()
	for q in line: px.append(X.call(q))
	_canvas.draw_polyline(px, Color(0.62, 0.2, 0.12, 0.35), 3.0 * _k, true)
	var f := clampf(_anim, 0.0, 1.0) if _anim >= 0.0 else 1.0
	var total := 0.0
	for i in px.size() - 1: total += px[i].distance_to(px[i + 1])
	var want := total * f
	var part := PackedVector2Array([px[0]])
	for i in px.size() - 1:
		var l := px[i].distance_to(px[i + 1])
		if want <= l:
			part.append(px[i].lerp(px[i + 1], want / maxf(l, 1e-6))); break
		part.append(px[i + 1]); want -= l
	if part.size() >= 2: _canvas.draw_polyline(part, SEAL, 4.0 * _k, true)
	var head: Vector2 = part[part.size() - 1]
	_canvas.draw_circle(head, 6.0 * _k, SEAL if _anim >= 0.0 else Color(0.62, 0.2, 0.12, 0.6))
	_canvas.draw_circle(px[px.size() - 1], 6.0 * _k, INK)

# 다른 공간: 전국 윤곽 + 지나는 노정 geo_line을 이은 선
func _draw_nation(mr: Rect2, it: Dictionary) -> void:
	var a = here_ll; var b = _ll(String(it.space), it.at)
	var line := PackedVector2Array()
	if a != null: line.append(a)
	for sp in it.get("via", []):
		var d: Dictionary = RideNet.read(String(sp))
		var gl: Array = d.get("geo_line", [])
		if gl.size() < 2 or sp == it.space: continue
		var seg := PackedVector2Array()
		for g in gl: seg.append(Vector2(float(g[0]), float(g[1])))
		if line.size() > 0 and line[line.size() - 1].distance_to(seg[seg.size() - 1]) < line[line.size() - 1].distance_to(seg[0]): seg.reverse()
		line.append_array(seg)
	if b != null: line.append(b)
	var bb := Rect2(Vector2(124.2, 33.0), Vector2(6.8, 10.0))
	if line.size() >= 2:
		var lb := Rect2(line[0], Vector2.ZERO)
		for q in line: lb = lb.expand(q)
		bb = lb.grow(maxf(1.2, maxf(lb.size.x, lb.size.y) * 0.25))
	var sc := minf(mr.size.x / bb.size.x, mr.size.y / bb.size.y)
	var X := func(g: Vector2) -> Vector2: return Vector2((g.x - bb.get_center().x) * sc, -(g.y - bb.get_center().y) * sc) + mr.get_center()
	var land := PackedVector2Array()
	for q in Travel.PENINSULA: land.append(X.call(Vector2(q[0], q[1])))
	_canvas.draw_colored_polygon(land, Color(0.96, 0.93, 0.85))
	land.append(land[0])
	_canvas.draw_polyline(land, INK_SOFT, 1.5, true)
	var jj := PackedVector2Array()
	for q in Travel.jeju(): jj.append(X.call(q))
	_canvas.draw_colored_polygon(jj, Color(0.96, 0.93, 0.85))
	for r in Travel.regions():
		if r.get("lonlat") == null or not Discovery.region_known(String(r.id)): continue
		var c: Vector2 = X.call(r.lonlat)
		if not mr.has_point(c): continue
		_canvas.draw_circle(c, 5.0 * _k, INK)
		_text(String(r.get("short", r.id)), c + Vector2(7, -5) * _k, 14, INK)
	if line.size() >= 2: _draw_route_line(line, X)
