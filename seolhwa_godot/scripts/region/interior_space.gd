# 실내 공간(interior space) — 굴·지하·큰 실내를 권역 지형 안이 아니라 따로 세운 작은 공간으로 둔다(권역·노정 곁의 세 번째 공간 종류).
#   데이터: region_data/interiors/<id>/interior.json
#     { id, name, region(입구가 있는 권역·노정 id), origin: [x, y, z](이 공간의 로컬 0을 둘 월드 자리 — 권역 지도 안, 쓰지 않는 자리(먼 바다 등)),
#       ry, kit, params(키트 — 실내만 짓는 꼴), light: { dark(0~1), exit_light: [x, y, z] 로컬, exit_energy }, camera: { pitch, distance },
#       entrances: [{ id, at: [x, z](권역 월드), radius, spawn: [x, z](로컬), face }],
#       exits: [{ id, at: [x, z](로컬), radius, to: [x, z](권역 월드), face, label }],
#       props: [{ id, kit, params, at: [x, z](로컬), ry, dy, state }],      ← 상태 있는 소품(world.props에 등록 — set_prop_state가 그대로 듣는다)
#       decals: { items: [...], trails: [{ …, points: [[x, z] 로컬…] }] },   ← 데칼(그룹 hidden·trace 그대로)
#       twin: "배치 id" }   ← 선택: 이 공간의 키트가 권역 겉 건물(같은 키트, params.part "shell"/"inside")의 안쪽이다.
#                          안쪽 키트를 그 id의 쌍으로 등록해 상태(불·숨은 바닥…)를 같이 받고(prop_states.register_twin),
#                          키트 실내의 hide(앞벽·지붕)를 그대로 숨긴다. 앵커는 prop_anchor(그 id, …)가 실내 자리로 돌려준다.
#   들어가 있는 동안(RegionWorld.indoor = 이 객체):
#     - 지형·물·정적 물체·식생·원경 노드를 숨기고 타일 갈기(focus)를 멈춘다(권역은 메모리에 그대로 — 다시 읽지 않는다).
#     - height_at·ground_at·blocked·interior_at은 이 공간이 답한다(바닥 높이 = origin.y + floor_y, 충돌체 = 키트 + 상자 밖).
#     - 하늘·날씨 입자·안개 없음, 어두움(light.dark — region_main._apply_dark, 등불 lantern 그대로), 실내 카메라.
#     - 이야기(사건·기록책·싸움·잔영·데칼·소품)는 같은 장면에서 그대로 돈다 — 좌표만 이 공간의 월드 자리다.
#   region_main: enter_interior(id, entrance_id) · exit_interior(exit_id) — 짧은 암전. 걸어서 입구·출구 자리에 들면 저절로.
#     이야기가 teleport로 실내 자리(또는 밖)를 가리키면 저절로 들어가고 나온다(main.teleport).
extends RefCounted

const ROOT := "res://region_data/interiors/"

var id := ""
var spec := {}
var origin := Vector3.ZERO
var xf := Transform3D()
var node: Node3D
var cols: Array = []
var interior := {}           # 실내 사전(카메라·dark·near_fade·floor_world …) — world.interior_at이 돌려준다
var floor_y := 0.0
var bounds := Rect2()        # 월드 xz(이 안이면 이 공간 자리)
var props_ids: Array = []
var decal_ids: Array = []
var light: OmniLight3D
var twin := ""
var _world

static var _index := {}      # id → spec(한 번 읽기)

static func list() -> Dictionary:
	if not _index.is_empty(): return _index
	var da := DirAccess.open(ROOT)
	if da == null: return _index
	for dn in da.get_directories():
		var p := ROOT + dn + "/interior.json"
		if not FileAccess.file_exists(p): continue
		var j = JSON.parse_string(FileAccess.get_file_as_string(p))
		if j is Dictionary: _index[String(j.get("id", dn))] = j
	return _index

static func for_space(space_id: String) -> Array:
	var out := []
	var all := list()
	for k in all:
		if String(all[k].get("region", "")) == space_id: out.append(all[k])
	return out

static func spec_of(iid: String) -> Dictionary:
	return list().get(iid, {})

# 이 공간의 월드 자리(로컬 → 월드)
func to_world(l: Vector2) -> Vector2:
	var p := xf * Vector3(l.x, 0.0, l.y)
	return Vector2(p.x, p.z)

static func world_of(sp: Dictionary, l: Vector2) -> Vector2:
	var o: Array = sp.get("origin", [0, 0, 0])
	var t := Transform3D(Basis(Vector3.UP, float(sp.get("ry", 0.0))), Vector3(float(o[0]), float(o[1]), float(o[2])))
	var p := t * Vector3(l.x, 0.0, l.y)
	return Vector2(p.x, p.z)

# 월드 xz가 이 실내 공간(데이터만으로 — 짓기 전에도) 안인가
static func contains(sp: Dictionary, p: Vector2) -> bool:
	var b: Array = sp.get("bounds", [])
	if b.size() < 4: return false
	var a := world_of(sp, Vector2(float(b[0]), float(b[1])))
	var c := world_of(sp, Vector2(float(b[2]), float(b[3])))
	return Rect2(Vector2(minf(a.x, c.x), minf(a.y, c.y)), (a - c).abs()).has_point(p)

func build(world, sp: Dictionary) -> void:
	spec = sp
	_world = world
	id = String(sp.get("id", ""))
	twin = String(sp.get("twin", ""))
	var o: Array = sp.get("origin", [0, 0, 0])
	origin = Vector3(float(o[0]), float(o[1]), float(o[2]))
	xf = Transform3D(Basis(Vector3.UP, float(sp.get("ry", 0.0))), origin)
	var info: Dictionary = load("res://kit/%s.gd" % String(sp.kit)).build(sp.get("params", {}))
	node = info.node
	node.name = "indoor_" + id
	node.transform = xf
	world.add_child(node)
	for c in info.get("colliders", []): cols.append(world._xf_collider(c, xf))
	var it: Dictionary = info.get("interior", {}).duplicate()
	floor_y = origin.y + float(it.get("floor_y", 0.0))
	if it.has("minX"): it.merge(world._xf_box(it, xf), true)
	it.id = id
	it.floor_world = floor_y
	# 쌍 키트(창고 안쪽 등): 키트 실내의 앞벽·지붕은 이 공간에서 늘 숨긴다(region_main 가림 목록에 넣지 않는다 — 나올 때 노드가 지워진다)
	if twin != "":
		for h in it.get("hide", []):
			if h is Node3D: h.visible = false
	it.hide = []
	it.space = true
	if sp.get("camera") is Dictionary: it.camera = sp.camera
	var lt: Dictionary = sp.get("light", {})
	if lt.has("dark"): it.dark = float(lt.dark)
	it.near_fade = false
	interior = it
	var b: Array = sp.get("bounds", [-6, -22, 6, 22])
	var a := to_world(Vector2(float(b[0]), float(b[1]))); var c := to_world(Vector2(float(b[2]), float(b[3])))
	bounds = Rect2(Vector2(minf(a.x, c.x), minf(a.y, c.y)), (a - c).abs())
	if world.get("props") != null:
		if twin != "": world.props.register_twin(twin, node, { lights = [], attached = true }, info)
		else:
			world.props.register(id, node, { lights = [], attached = true }, info, null)
			props_ids.append(id)
		for pr in sp.get("props", []):
			var pi: Dictionary = load("res://kit/%s.gd" % String(pr.kit)).build(pr.get("params", {}))
			var pn: Node3D = pi.node
			pn.name = String(pr.id)
			var at := Vector2(float(pr.at[0]), float(pr.at[1]))
			var pxf := xf * Transform3D(Basis(Vector3.UP, float(pr.get("ry", 0.0))), Vector3(at.x, float(pr.get("dy", 0.0)), at.y))
			pn.transform = pxf
			node.get_parent().add_child(pn)
			for cc in pi.get("colliders", []): cols.append(world._xf_collider(cc, pxf))
			world.props.register(String(pr.id), pn, { lights = [], attached = true }, pi, pr.get("state"))
			props_ids.append(String(pr.id))
			pn.set_meta("indoor_prop", true)
	# 출구 쪽 빛(굴 밖에서 드는 빛)
	if lt.has("exit_light"):
		var el: Array = lt.exit_light
		light = OmniLight3D.new()
		light.light_color = Color(lt.get("exit_color", "#cfd6dc"))
		light.omni_range = float(lt.get("exit_range", 7.0))
		light.light_energy = float(lt.get("exit_energy", 1.4))
		light.shadow_enabled = false
		light.position = xf * Vector3(float(el[0]), float(el[1]), float(el[2]))
		world.add_child(light)
	var dc = world.get("decals")
	if dc != null and sp.get("decals") is Dictionary:
		for d in sp.decals.get("items", []):
			var q: Dictionary = d.duplicate()
			var wp := to_world(Vector2(float(q.x), float(q.z)))
			q.x = wp.x; q.z = wp.y
			decal_ids.append(dc.add(q))
		for tr in sp.decals.get("trails", []):
			var pts := []
			for p in tr.points: pts.append(to_world(Vector2(float(p[0]), float(p[1]))))
			var opts: Dictionary = tr.duplicate(); opts.erase("points"); opts.erase("kind"); opts.erase("id")
			decal_ids.append_array(dc.trail(String(tr.id), String(tr.kind), pts, opts))

func teardown(world) -> void:
	var dc = world.get("decals")
	if dc != null:
		for i in decal_ids: dc.remove(i)
	decal_ids.clear()
	if world.get("props") != null:
		for pid in props_ids:
			var rec = world.props._props.get(pid)
			if rec != null:
				for g in rec.cols.keys(): world.props._drop_cols(rec, g)
				for g in rec.lights.keys(): world.props._drop_lights(rec, g)
				for g in rec.decal.keys(): world.props._drop_decal(rec, g)
				if rec.node != node and is_instance_valid(rec.node): rec.node.queue_free()
			world.props._props.erase(pid)
	props_ids.clear()
	if twin != "" and world.get("props") != null: world.props.drop_twin(twin)
	if light != null: light.queue_free(); light = null
	if node != null: node.queue_free(); node = null
	cols.clear()

func height_at(_x: float, _z: float) -> float:
	return floor_y

func blocked(x: float, z: float, r: float) -> bool:
	if not bounds.grow(-r).has_point(Vector2(x, z)): return true
	for c in cols:
		if _world_script._hit(c, x, z, r): return true
	# 상태 충돌체(열린 숨은 바닥·무너진 더미 — prop_states가 world.add_dynamic_collider로 더한 것)
	if _world != null:
		for c in _world._dyn_cols:
			if _world_script._hit(c, x, z, r): return true
	return false

static var _world_script: Script = load("res://scripts/region/region_world.gd")
