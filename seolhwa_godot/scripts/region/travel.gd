# 여러 권역·노정 오가기(계약서 §10, 계획서 §2.1) — 공간(권역·노정) 목록, 포털, 공간 넘어가기 예약, 전국 지도용 위치.
#
# 공간
#   권역: res://region_data/<id>/region.json (+ height.png …)          — region_data/regions.json 목록(없으면 폴더를 훑어 만든다)
#   노정: res://region_data/routes/<id>/route.json (권역과 같은 형식: height·landuse·rivers·roads·settlements·spawn·placement_*.json)
#         + from_region / to_region / stops:[{type,name,t,x,z}] / portals:{from:{region,x,z}, to:{region,x,z}}
#         portals.from.x,z = 그 권역 안의 포털 자리(권역 좌표). 노정 쪽 자리는 portals.from.route_x/route_z(없으면 노정 주 도로의 첫 점,
#         to는 끝 점). 권역 쪽 포털은 노정 파일들에서 모아 만든다. region.json `portals:[{id,name,x,z,to:{route|region,x?,z?}}]`도 읽는다.
#   시험 노정 폴더는 --routedir=res://…/(세미콜론으로 여러 개)로 더한다.
# 넘어가기: region_main이 Engine 메타 "seolhwa_travel"에 {kind, id, dir, at, hour, weather, via}를 적고 장면을 다시 연다
#   → 새 장면은 명령줄(--region 등)보다 이 예약을 먼저 본다. 스레드·타일·키트 캐시 정리는 장면을 지우기 전에 한다(region_main._leave).
extends RefCounted

const REGION_ROOT := "res://region_data/"
const ROUTE_ROOT := "res://region_data/routes/"
const META := "seolhwa_travel"

static var extra_route_dirs: Array = []     # --routedir
static var _regions_cache = null
static var _routes_cache = null

static func region_dir(id: String) -> String:
	return REGION_ROOT + id + "/"

static func route_dirs() -> Array:
	var out := [ROUTE_ROOT]
	for d in extra_route_dirs: out.append(d if d.ends_with("/") else d + "/")
	return out

# 노정 id → 폴더(route.json이 있는 곳). 루트 폴더 자체에 route.json이 있어도 된다
static func find_route_dir(id: String) -> String:
	for root in route_dirs():
		if FileAccess.file_exists(root + id + "/route.json"): return root + id + "/"
		if FileAccess.file_exists(root + "route.json"):
			var j = _read_json(root + "route.json")
			if j is Dictionary and String(j.get("route_id", j.get("id", ""))) == id: return root
	return ""

static func _read_json(p: String) -> Variant:
	if not FileAccess.file_exists(p): return null
	return JSON.parse_string(FileAccess.get_file_as_string(p))

# 모든 노정: [{id, dir, name, from, to, json}] (json은 큰 높이맵 빼고 route.json 전체 — 작다)
static func routes() -> Array:
	if _routes_cache != null: return _routes_cache
	var out := []
	var seen := {}
	for root in route_dirs():
		var cands := []
		if FileAccess.file_exists(root + "route.json"): cands.append(root)
		var da := DirAccess.open(root)
		if da != null:
			for sub in da.get_directories(): cands.append(root + sub + "/")
		for d in cands:
			var j = _read_json(d + "route.json")
			if not (j is Dictionary): continue
			var id := String(j.get("route_id", j.get("id", d.trim_suffix("/").get_file())))
			if seen.has(id): continue
			seen[id] = true
			out.append({ id = id, dir = d, name = String(j.get("name", j.get("route_name", id))), from = String(j.get("from_region", _portal(j, "from").get("region", ""))),
				to = String(j.get("to_region", _portal(j, "to").get("region", ""))), json = j })
	_routes_cache = out
	return out

static func _portal(j: Dictionary, end: String) -> Dictionary:
	var p = j.get("portals", {})
	if p is Dictionary and p.get(end) is Dictionary: return p[end]
	return {}

# 권역 목록: regions.json이 있으면 그것, 없으면 region_data/<id>/region.json을 훑는다.
# 항목: {id, name, culture, climate, entry:{x,z}, map_pos, lonlat: Vector2|null(경도, 위도)}
static func regions() -> Array:
	if _regions_cache != null: return _regions_cache
	var out := []
	var j = _read_json(REGION_ROOT + "regions.json")
	var list: Array = []
	if j is Array: list = j
	elif j is Dictionary: list = j.get("regions", [])
	if list.is_empty():
		var da := DirAccess.open(REGION_ROOT)
		if da != null:
			for sub in da.get_directories():
				if FileAccess.file_exists(REGION_ROOT + sub + "/region.json"): list.append({ id = sub })
	for e in list:
		if not (e is Dictionary): continue
		var r: Dictionary = e.duplicate()
		var id := String(r.get("id", ""))
		r.lonlat = _lonlat_of(r)
		if (r.lonlat == null or String(r.get("name", "")) == "") and FileAccess.file_exists(region_dir(id) + "region.json"):
			var rj = _read_json(region_dir(id) + "region.json")
			if rj is Dictionary:
				if String(r.get("name", "")) == "": r.name = String(rj.get("region_name", id))
				var pj = rj.get("projection")
				if r.lonlat == null and pj is Dictionary: r.lonlat = Vector2(float(pj.lon0), float(pj.lat0))
				if not r.has("entry") and rj.get("spawn") is Dictionary: r.entry = rj.spawn
				if not r.has("climate"): r.climate = String(rj.get("climate_zone", ""))
		r.short = short_name(String(r.get("name", id)))
		out.append(r)
	_regions_cache = out
	return out

static func region_info(id: String) -> Dictionary:
	for r in regions():
		if String(r.get("id", "")) == id: return r
	return {}

static func short_name(n: String) -> String:
	for sep in ["·", " ", "(", "—"]:
		var i := n.find(sep)
		if i > 0: n = n.substr(0, i)
	return n

# map_pos 해석: {x,y}가 0~1이면 전국 지도 상자(OUTLINE_BOX) 안 비율(위가 0), 경위도 범위면 경도·위도. lat/lon 필드도 읽는다
static func _lonlat_of(r: Dictionary) -> Variant:
	if r.has("lon") and r.has("lat"): return Vector2(float(r.lon), float(r.lat))
	var mp = r.get("map_pos")
	if mp is Dictionary and mp.has("x") and mp.has("y"):
		var x := float(mp.x); var y := float(mp.y)
		if x >= 0.0 and x <= 1.0 and y >= 0.0 and y <= 1.0:
			return Vector2(lerpf(OUTLINE_BOX.position.x, OUTLINE_BOX.end.x, x), lerpf(OUTLINE_BOX.end.y, OUTLINE_BOX.position.y, y))
		if x > 120.0 and x < 135.0 and y > 30.0 and y < 45.0: return Vector2(x, y)
		if y > 120.0 and y < 135.0 and x > 30.0 and x < 45.0: return Vector2(y, x)
	return null

# 권역 좌표 → 경위도(region.json projection)
static func local_to_lonlat(region: Dictionary, x: float, z: float) -> Variant:
	var pj = region.get("projection")
	if not (pj is Dictionary): return null
	var K := float(pj.get("K", 0.3)); var lat0 := float(pj.lat0); var lon0 := float(pj.lon0)
	return Vector2(lon0 + x / K / (cos(deg_to_rad(lat0)) * 111320.0), lat0 - z / K / 110574.0)

# 이 공간(권역 또는 노정)의 포털 목록: [{id, name, x, z, kind:"route"|"region", target, tx, tz, label}]
#   target 공간에 도착할 자리 tx,tz(그 공간 좌표)
static func portals_for(space: Dictionary, is_route: bool) -> Array:
	var out := []
	if is_route:
		var rid := String(space.get("route_id", space.get("id", "")))
		var ends := route_ends(space)
		for end in ["from", "to"]:
			var p := _portal(space, end)
			var reg := String(p.get("region", space.get("from_region" if end == "from" else "to_region", "")))
			if reg == "" or not p.has("x"): continue
			var info := region_info(reg)
			var nm := String(p.get("name", ""))
			out.append({ id = "%s_%s" % [rid, end], name = nm, x = ends[end].x, z = ends[end].y, kind = "region", target = reg,
				tx = float(p.x), tz = float(p.z), label = "%s%s" % [String(info.get("short", short_name(reg))), " · " + nm if nm != "" else ""] })
		return out
	var my_id := String(space.get("region_id", ""))
	for r in routes():
		var j: Dictionary = r.json
		var ends := route_ends(j)
		for end in ["from", "to"]:
			var p := _portal(j, end)
			if String(p.get("region", "")) != my_id or not p.has("x"): continue
			var nm := String(p.get("name", ""))
			out.append({ id = "%s_%s" % [r.id, end], name = nm, x = float(p.x), z = float(p.z), kind = "route", target = r.id,
				tx = ends[end].x, tz = ends[end].y, label = "%s%s" % [r.name, " · " + nm if nm != "" else ""] })
	for p in (space.get("portals") if space.get("portals") is Array else []):
		if not (p is Dictionary) or not p.has("x"): continue
		var to: Dictionary = p.get("to", {}) if p.get("to") is Dictionary else {}
		if p.get("to") is String:   # "route:<id>" · "region:<id>" · "map_only"(지도에만 — 넘어가지 않음)
			var ts := String(p.to).split(":", true, 1)
			if ts.size() == 2: to = { ts[0]: ts[1] }
		var kind := "route" if to.has("route") else "region"
		var tgt := String(to.get("route", to.get("region", "")))
		if tgt == "": continue
		out.append({ id = String(p.get("id", tgt)), name = String(p.get("name", "")), x = float(p.x), z = float(p.z), kind = kind, target = tgt,
			tx = float(to.get("x", NAN)), tz = float(to.get("z", NAN)), label = String(p.get("name", tgt)) })
	return out

# 노정 양 끝(노정 좌표): portals.*.route_x/route_z, 없으면 주 도로(대로 중 가장 긴 길, 없으면 roads[0])의 첫·끝 점, 없으면 spawn
static func route_ends(j: Dictionary) -> Dictionary:
	var main := main_road(j)
	var a := Vector2.ZERO; var b := Vector2.ZERO
	if main.size() >= 2:
		a = main[0]; b = main[main.size() - 1]
	elif j.get("spawn") is Dictionary:
		a = Vector2(float(j.spawn.x), float(j.spawn.z)); b = a
	var out := { from = a, to = b }
	for end in ["from", "to"]:
		var p := _portal(j, end)
		if p.has("route_x") and p.has("route_z"): out[end] = Vector2(float(p.route_x), float(p.route_z))
	return out

static func main_road(j: Dictionary) -> PackedVector2Array:
	var best: Array = []; var best_l := -1.0
	for r in j.get("roads", []):
		var pts: Array = r.get("points", [])
		var l := 0.0
		for i in pts.size() - 1: l += Vector2(pts[i][0], pts[i][1]).distance_to(Vector2(pts[i + 1][0], pts[i + 1][1]))
		if String(r.get("class", "")) == "대로": l *= 10.0
		if l > best_l: best_l = l; best = pts
	var out := PackedVector2Array()
	for p in best: out.append(Vector2(float(p[0]), float(p[1])))
	return out

# 노정 위 진행도(0~1): 주 도로에 가장 가까운 점의 길이 비율
static func route_progress(j: Dictionary, x: float, z: float) -> float:
	var pts := main_road(j)
	if pts.size() < 2: return 0.5
	var total := 0.0; var best := INF; var at := 0.0
	var p := Vector2(x, z)
	for i in pts.size() - 1:
		var a := pts[i]; var b := pts[i + 1]
		var ab := b - a; var l := ab.length()
		var t := clampf((p - a).dot(ab) / maxf(l * l, 1e-6), 0.0, 1.0)
		var d := p.distance_to(a + ab * t)
		if d < best: best = d; at = total + t * l
		total += l
	return at / maxf(total, 1e-6)

# ---- 넘어가기 예약 ----
static func set_pending(d: Dictionary) -> void:
	Engine.set_meta(META, d)

static func take_pending() -> Dictionary:
	if not Engine.has_meta(META): return {}
	var d: Dictionary = Engine.get_meta(META)
	Engine.remove_meta(META)
	return d

# ---- 전국 지도 윤곽(간단한 한반도·제주 — 주요 곶·만을 이은 경위도 꺾은선, 축척 지도용 근사) ----
const OUTLINE_BOX := Rect2(124.0, 33.0, 7.0, 10.0)   # 경도 124~131, 위도 33~43
const PENINSULA := [
	[124.36, 40.05], [124.9, 39.62], [125.45, 39.55], [125.6, 39.4], [125.25, 38.95], [125.4, 38.7], [125.1, 38.55], [124.7, 38.12],
	[125.2, 37.95], [125.7, 38.0], [126.1, 37.75], [126.45, 37.72], [126.62, 37.45], [126.65, 37.2], [126.8, 37.0], [126.5, 36.98],
	[126.13, 36.85], [126.3, 36.6], [126.5, 36.35], [126.62, 36.1], [126.72, 35.98], [126.48, 35.62], [126.42, 35.38], [126.3, 35.1],
	[126.38, 34.8], [126.27, 34.55], [126.5, 34.3], [126.8, 34.52], [127.05, 34.6], [127.3, 34.47], [127.55, 34.65], [127.75, 34.72],
	[127.92, 34.82], [128.15, 34.88], [128.42, 34.85], [128.65, 34.72], [128.85, 35.05], [129.05, 35.06], [129.22, 35.2],
	[129.4, 35.5], [129.5, 35.85], [129.58, 36.08], [129.43, 36.4], [129.42, 36.75], [129.43, 37.05], [129.18, 37.45],
	[128.92, 37.78], [128.6, 38.2], [128.35, 38.6], [127.9, 38.95], [127.5, 39.15], [127.45, 39.45], [127.6, 39.82],
	[128.2, 40.0], [128.7, 40.3], [129.2, 40.65], [129.75, 41.2], [129.8, 41.8], [130.3, 42.25], [130.68, 42.3],
	[130.25, 42.75], [129.9, 42.98], [129.55, 42.42], [129.15, 42.25], [128.65, 42.05], [128.08, 41.98], [128.25, 41.45],
	[127.6, 41.42], [126.95, 41.75], [126.3, 41.15], [125.7, 40.82], [125.3, 40.5], [124.9, 40.42], [124.36, 40.05],
]
static func jeju() -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in 25:
		var a := TAU * i / 24.0
		out.append(Vector2(126.55 + cos(a) * 0.36, 33.38 + sin(a) * 0.15))
	return out
