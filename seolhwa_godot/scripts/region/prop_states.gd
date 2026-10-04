# 프롭 상태 기계(PROP_MASTER §11) — 배치 항목 id로 물건의 상태를 바꾼다. RegionWorld.props (world.set_prop_state가 부른다).
#
# 상태: NORMAL USED EMPTY BROKEN FALLEN WET BLOODY BURNT MOVED SEALED OPEN (+ 창고 불 FIRE_1·FIRE_2·FIRE_3, PRP_FIN_003)
# 키: "배치 id"(주 그룹 main) 또는 "배치 id/그룹"(한 물건 안의 따로 바뀌는 부분 — 책방 뒤창 window, 창고 숨은 바닥 hatch …).
#     배치형 조각은 id가 "부모 id/조각 tag"이므로 그 조각 자체가 하나의 id다.
#
# 키트가 상태를 그리는 법(kit/scenario/_sc.gd가 만들어 준다):
#   - node 아래 이름이 "S_<그룹>_<상태>"인 노드: 그 그룹이 그 상태일 때만 보인다(같은 그룹의 다른 상태 노드는 숨김).
#   - build() 결과: states {그룹: [상태…]}, state_default {그룹: 상태}, state_fx {그룹: {상태: [fx…]}} (state_fx.gd — 불·연기·김·불빛),
#     state_colliders {그룹: {상태: [충돌체(로컬)]}}, move (MOVED 때 옮길 로컬 Vector3)
# 키트가 그 상태 노드를 갖고 있지 않으면 일반 처리(주 그룹만): BURNT·WET·BLOODY·BROKEN = 색 곱(키트 재질 복사본의 albedo_color),
#   WET·BLOODY = 발밑 데칼(물기·핏자국), MOVED = 조금 옮김, FALLEN = 옆으로 눕힘. 그 밖(USED·EMPTY·SEALED·OPEN)은 모양 그대로.
#
# 상태는 물건이 아직 지어지지 않았거나(먼 타일) 다시 읽기(F5) 중이어도 기억했다가 놓일 때 적용한다.
extends RefCounted

const Fx := preload("res://scripts/region/state_fx.gd")

const STATES := ["NORMAL", "USED", "EMPTY", "BROKEN", "FALLEN", "WET", "BLOODY", "BURNT", "MOVED", "SEALED", "OPEN"]
const FIRE := ["FIRE_1", "FIRE_2", "FIRE_3"]
const TINT := {
	BURNT = Vector3(0.3, 0.26, 0.23), WET = Vector3(0.7, 0.72, 0.78), BLOODY = Vector3(0.96, 0.86, 0.84), BROKEN = Vector3(0.86, 0.83, 0.79),
	FIRE_3 = Vector3(0.3, 0.26, 0.23),
}

signal changed(key: String, state: String)

var world
var _want := {}      # 키 → 상태(사건이 정한 값, 다시 읽기·스트리밍에도 남는다)
var _props := {}     # id → rec { id, node, entry, info, xf, base, groups:{g:{STATE:[Node]}}, cur:{g:STATE}, fx:{g:[Node]}, cols:{g:[c]}, lights:{g:[l]}, decal:{g:id} }
# 쌍(twin): 실내 공간(interior_space.gd, interior.json "twin")이 권역의 겉 건물과 같은 id로 세운 안쪽 키트. 같은 상태를 같이 받는다
#   (밖에서 불을 놓으면 안에도, 안에서 숨은 바닥을 열면 밖 껍데기에도). 들어가 있는 동안 앵커는 안쪽 것을 돌려준다.
var _twins := {}     # id → rec(_props와 같은 꼴)

func _init(w) -> void:
	world = w

# ---------------------------------------------------------------------------
# 공개 API (world.set_prop_state 등이 부른다)
# ---------------------------------------------------------------------------
# 상태 바꾸기. 아직 놓이지 않은 물건이면 기억해 두었다가 놓일 때 적용(true). 모르는 상태 이름이면 false
func set_state(key: String, state: String) -> bool:
	state = state.to_upper()
	if not (state in STATES or state in FIRE or _custom_ok(key, state)):
		push_warning("프롭 상태: 모르는 상태 %s (%s)" % [state, key]); return false
	_want[key] = state
	var p := _resolve(key)
	if not p.is_empty(): _apply(_props[p[0]], p[1], state)
	var tp := _resolve_in(_twins, key)
	if not tp.is_empty(): _apply(_twins[tp[0]], tp[1], state)
	changed.emit(key, state)
	return true

func get_state(key: String) -> String:
	var p := _resolve(key)
	if not p.is_empty(): return String(_props[p[0]].cur.get(p[1], "NORMAL"))
	var tp := _resolve_in(_twins, key)
	if not tp.is_empty(): return String(_twins[tp[0]].cur.get(tp[1], "NORMAL"))
	return String(_want.get(key, "NORMAL"))

# 그 키가 그리는 상태 목록(키트가 직접 그리는 것 + 일반 처리되는 것)
func states_of(key: String) -> Array:
	var p := _resolve(key)
	if p.is_empty(): return []
	var rec: Dictionary = _props[p[0]]
	var own: Array = (rec.info.get("states", {}) as Dictionary).get(p[1], [])
	var out: Array = own.duplicate()
	for s in rec.groups.get(p[1], {}):
		if not out.has(s): out.append(s)
	if p[1] == "main":
		for s in STATES:
			if not out.has(s): out.append(s)
	return out

# 놓인 물건의 그룹 목록(main 포함)
func groups_of(id: String) -> Array:
	if not _props.has(id): return []
	var gs: Array = ["main"]
	for g in (_props[id].info.get("states", {}) as Dictionary):
		if not gs.has(g): gs.append(g)
	for g in _props[id].groups:
		if not gs.has(g): gs.append(g)
	return gs

func has(id: String) -> bool:
	return _props.has(id)

func node_of(id: String) -> Node3D:
	return _props[id].node if _props.has(id) else null

# 키트 앵커(로컬)를 월드 좌표로. 없으면 null. 쌍(실내 공간 안쪽 키트)이 있으면 그 앵커(안쪽 월드 자리).
# 쌍이 지금 없어도(밖에 있을 때) 실내 공간 데이터가 이 id를 twin으로 가지면, 실내 bounds 안에 드는 앵커(inside·hatch·pit…)는
# 실내 공간의 월드 자리로, 밖에 남는 앵커(door 등)는 겉 건물 자리로 돌려준다 — teleport가 그대로 들어가고 나온다.
func anchor(id: String, name: String) -> Variant:
	var src = _props.get(id, _twins.get(id))
	if src == null: return null
	var a = (src.info.get("anchors", {}) as Dictionary).get(name)
	if a == null: return null
	var tw = _twin_space(id)
	if tw != null:
		var p = tw.call(a as Vector3)
		if p != null: return p
	if not _props.has(id): return null
	return (_props[id].xf as Transform3D) * (a as Vector3)

func anchors_of(id: String) -> Dictionary:
	if not _props.has(id) and not _twins.has(id): return {}
	var out := {}
	var names: Dictionary = (_twins[id] if _twins.has(id) else _props[id]).info.get("anchors", {})
	for k in names: out[k] = anchor(id, k)
	return out

# 이 id를 쌍으로 갖는 실내 공간(지금 권역) — 로컬 앵커 → 실내 월드 자리(bounds 안일 때만, 아니면 null)를 돌려주는 Callable
func _twin_space(id: String) -> Variant:
	if world == null or world.get("region") == null: return null
	var IS = load("res://scripts/region/interior_space.gd")
	var sid := String(world.region.get("region_id", world.region.get("route_id", "")))
	for sp in IS.for_space(sid):
		if String(sp.get("twin", "")) != id: continue
		return func(l: Vector3) -> Variant:
			var w2: Vector2 = IS.world_of(sp, Vector2(l.x, l.z))
			if not IS.contains(sp, w2): return null
			var o: Array = sp.get("origin", [0, 0, 0])
			return Vector3(w2.x, float(o[1]) + l.y, w2.y)
	return null

# 실내 공간이 안쪽 키트를 겉 건물 id의 쌍으로 세운다 — 지금 상태(사건이 정한 값, 없으면 겉 건물의 지금 상태, 없으면 기본)를 그대로
func register_twin(id: String, node: Node3D, entry: Dictionary, info: Dictionary) -> void:
	var groups := {}
	_scan(node, groups)
	var rec := { id = id, node = node, entry = entry, info = info, xf = node.transform, base = node.transform, groups = groups,
		cur = {}, fx = {}, cols = {}, lights = {}, decal = {} }
	_twins[id] = rec
	var gs: Array = ["main"]
	for g in (info.get("states", {}) as Dictionary).keys() + groups.keys():
		if not gs.has(g): gs.append(g)
	for g in gs:
		var key: String = id if g == "main" else id + "/" + g
		var st: String
		if _want.has(key): st = _want[key]
		elif _props.has(id) and (_props[id].cur as Dictionary).has(g): st = _props[id].cur[g]
		else: st = _default(rec, g, null)
		_apply(rec, g, st)

func drop_twin(id: String) -> void:
	if not _twins.has(id): return
	var rec: Dictionary = _twins[id]
	for g in rec.cols.keys(): _drop_cols(rec, g)
	for g in rec.lights.keys(): _drop_lights(rec, g)
	for g in rec.decal.keys(): _drop_decal(rec, g)
	_twins.erase(id)

# 놓인 id 목록(prefix로 거름) — 시험·디버그용
func ids(prefix := "") -> Array:
	var out := []
	for id in _props:
		if prefix == "" or String(id).begins_with(prefix): out.append(id)
	return out

# 기억해 둔 상태를 모두 지운다(새 게임). 놓인 물건은 기본 상태로
func reset_all() -> void:
	_want.clear()
	for d in [_props, _twins]:
		for id in d:
			var rec: Dictionary = d[id]
			for g in rec.cur.keys(): _apply(rec, g, _default(rec, g, null))

# ---------------------------------------------------------------------------
# 배치 로더가 부른다
# ---------------------------------------------------------------------------
# entry: RegionWorld.add_static이 돌려준 정적 물체 항목(조명·붙음 상태), initial: 배치 항목 state(문자열 = main, 사전 = 그룹별)
func register(id: String, node: Node3D, entry: Dictionary, info: Dictionary, initial = null) -> void:
	if id == "" or node == null: return
	var groups := {}
	_scan(node, groups)
	var has_meta: bool = info.has("states") or info.has("state_fx") or info.has("state_colliders")
	var want_here := false
	for k in _want:
		if k == id or (String(k).begins_with(id + "/") and not String(k).substr(id.length() + 1).contains("/")): want_here = true; break
	# 상태가 없는 물건(대부분의 마을 소품)은 등록만 가볍게(사건이 바꾸면 그때 일반 처리)
	var rec := { id = id, node = node, entry = entry, info = info, xf = node.transform, base = node.transform, groups = groups,
		cur = {}, fx = {}, cols = {}, lights = {}, decal = {} }
	_props[id] = rec
	if groups.is_empty() and not has_meta and not want_here and initial == null: return
	var gs := groups_of(id)
	for g in gs:
		var init = null
		if initial is String and g == "main": init = initial
		elif initial is Dictionary: init = initial.get(g, initial.get("" if g == "main" else g))
		var st := _default(rec, g, init)
		if st != "NORMAL" or groups.has(g) or (info.get("state_fx", {}) as Dictionary).has(g): _apply(rec, g, st)

# 다시 읽기(F5)·권역 떠나기 전: 노드 참조와 동적 충돌체·불빛을 정리(기억한 상태는 남긴다)
func clear_nodes() -> void:
	for id in _props:
		var rec: Dictionary = _props[id]
		for g in rec.cols.keys(): _drop_cols(rec, g)
		for g in rec.lights.keys(): _drop_lights(rec, g)
		for g in rec.decal.keys(): _drop_decal(rec, g)
	_props.clear()

# ---------------------------------------------------------------------------
func _custom_ok(key: String, state: String) -> bool:
	# 키트가 직접 그리는 다른 이름의 상태(예: 등잔 LIT 같은 것)도 허용
	var p := _resolve(key)
	if p.is_empty(): return false
	var rec: Dictionary = _props[p[0]]
	if (rec.groups.get(p[1], {}) as Dictionary).has(state): return true
	return ((rec.info.get("states", {}) as Dictionary).get(p[1], []) as Array).has(state)

func _resolve(key: String) -> Array:
	return _resolve_in(_props, key)

static func _resolve_in(d: Dictionary, key: String) -> Array:
	if d.has(key): return [key, "main"]
	var i := key.rfind("/")
	if i > 0 and d.has(key.substr(0, i)): return [key.substr(0, i), key.substr(i + 1)]
	return []

func _default(rec: Dictionary, g: String, init) -> String:
	var key: String = rec.id if g == "main" else rec.id + "/" + g
	if _want.has(key): return _want[key]
	if init != null and String(init) != "": return String(init).to_upper()
	return String((rec.info.get("state_default", {}) as Dictionary).get(g, "NORMAL"))

static func _scan(n: Node, out: Dictionary) -> void:
	for c in n.get_children():
		var nm := String(c.name)
		if nm.begins_with("S_"):
			var rest := nm.substr(2)
			var i := rest.find("_")
			if i > 0:
				var g := rest.substr(0, i)
				if not out.has(g): out[g] = {}
				for st in rest.substr(i + 1).split("-", false):   # 여러 상태에서 보이는 노드: "S_main_NORMAL-FIRE_1"
					if not out[g].has(st): out[g][st] = []
					out[g][st].append(c)
		_scan(c, out)

func _apply(rec: Dictionary, g: String, state: String) -> void:
	if not is_instance_valid(rec.node): return
	rec.cur[g] = state
	var nodes: Dictionary = rec.groups.get(g, {})
	var explicit := nodes.has(state)
	# 상태 노드: 고른 상태만 보이게. 키트가 그 상태를 안 그리면 기본(NORMAL 또는 기본값) 노드
	var show := state
	if not explicit:
		show = String((rec.info.get("state_default", {}) as Dictionary).get(g, "NORMAL"))
		if not nodes.has(show) and nodes.has("NORMAL"): show = "NORMAL"
	for s in nodes:
		for n in nodes[s]:
			if is_instance_valid(n): n.visible = false
	for n in nodes.get(show, []):
		if is_instance_valid(n): n.visible = true
	# 일반 처리(주 그룹, 키트가 그 상태를 안 그릴 때)
	if g == "main":
		var tint: Vector3 = TINT.get(state, Vector3.ONE) if not explicit else Vector3.ONE
		if tint != Vector3.ONE or rec.get("tinted", false):
			_tint_node(rec.node, tint, rec.entry.get("occ"))
			rec.tinted = tint != Vector3.ONE
		var xf: Transform3D = rec.base
		if not explicit and state == "MOVED":
			var mv = rec.info.get("move", Vector3(0.7, 0.0, 0.4))
			xf = xf * Transform3D(Basis.IDENTITY, mv if mv is Vector3 else Vector3(0.7, 0, 0.4))
		elif not explicit and state == "FALLEN":
			xf = xf * _fallen_xf(rec.node)
		rec.node.transform = xf
		rec.xf = rec.base
		_drop_decal(rec, g)
		if not explicit and (state == "BLOODY" or state == "WET") and world.get("decals") != null:
			var fp = rec.info.get("footprint", Vector2(1, 1))
			var sz: float = clampf(maxf(world.to_v2(fp).x, world.to_v2(fp).y) * 0.8, 0.6, 2.5)
			var o: Vector3 = rec.base.origin
			rec.decal[g] = world.decals.add({ id = "prop:%s" % rec.id, kind = "blood" if state == "BLOODY" else "puddle", x = o.x, z = o.z, size = sz, ry = randf() * TAU })
	# 연출(불·연기·김·불빛)
	for n in rec.fx.get(g, []):
		if is_instance_valid(n): n.queue_free()
	rec.fx[g] = []
	_drop_lights(rec, g)
	var specs: Array = ((rec.info.get("state_fx", {}) as Dictionary).get(g, {}) as Dictionary).get(state, [])
	var add_lights := []
	for sp in specs:
		if not (sp is Dictionary): continue
		var ty: String = sp.get("type", "smoke")
		if ty == "light" or (ty == "fire" and sp.get("light", true)):
			var p: Vector3 = (rec.base as Transform3D) * Vector3(float(sp.get("x", 0.0)), float(sp.get("y", 0.0)) + (0.6 if ty == "fire" else 0.0), float(sp.get("z", 0.0)))
			add_lights.append({ x = p.x, y = p.y, z = p.z, kind = String(sp.get("kind", "torch" if ty == "fire" else "lantern")) })
		if ty == "light": continue
		var n := Fx.make(sp)
		rec.node.add_child(n)
		rec.fx[g].append(n)
	if not add_lights.is_empty():
		rec.lights[g] = add_lights
		rec.entry.lights.append_array(add_lights)
		if rec.entry.get("attached", false):
			world.lights.append_array(add_lights)
			world.lights_version += 1
	# 상태 충돌체(무너진 잔해·열린 바닥 구멍 등)
	_drop_cols(rec, g)
	var cs: Array = ((rec.info.get("state_colliders", {}) as Dictionary).get(g, {}) as Dictionary).get(state, [])
	if not cs.is_empty():
		rec.cols[g] = []
		for c in cs: rec.cols[g].append(world.add_dynamic_collider(c, rec.base))

func _drop_lights(rec: Dictionary, g: String) -> void:
	var ls: Array = rec.lights.get(g, [])
	if ls.is_empty(): return
	for l in ls:
		rec.entry.lights.erase(l)
		world.lights.erase(l)
	world.lights_version += 1
	rec.lights.erase(g)

func _drop_cols(rec: Dictionary, g: String) -> void:
	for c in rec.cols.get(g, []): world.remove_dynamic_collider(c)
	rec.cols.erase(g)

func _drop_decal(rec: Dictionary, g: String) -> void:
	if rec.decal.has(g) and world.get("decals") != null: world.decals.remove(rec.decal[g])
	rec.decal.erase(g)

# 색 곱: 키트 재질(공용)의 복사본(albedo_color = tint)을 표면에 덮는다 — 같은 (재질, 색)은 하나만 만든다.
# 가림 처리(occluder)가 표면 재질을 바꿔 끼우므로 그 캐시(solid·fadedm)를 지워 다음 번에 새 재질로 다시 만들게 한다.
static var _tint_mats := {}
static func _tint_node(n: Node, t: Vector3, occ) -> void:
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m: Mesh = (mi as MeshInstance3D).mesh
		if m == null: continue
		for s in m.get_surface_count():
			var base = m.surface_get_material(s)
			if not (base is ShaderMaterial): continue
			if t == Vector3.ONE:
				mi.set_surface_override_material(s, base)
				continue
			var key := "%d|%s" % [base.get_instance_id(), t]
			if not _tint_mats.has(key):
				var c: ShaderMaterial = base.duplicate()
				var a0 = base.get_shader_parameter("albedo_color")
				var a: float = (a0 as Vector4).w if a0 is Vector4 else 1.0
				var b: Vector3 = Vector3((a0 as Vector4).x, (a0 as Vector4).y, (a0 as Vector4).z) if a0 is Vector4 else Vector3.ONE
				c.set_shader_parameter("albedo_color", Vector4(b.x * t.x, b.y * t.y, b.z * t.z, a))
				_tint_mats[key] = c
			mi.set_surface_override_material(s, _tint_mats[key])
	if occ is Dictionary:
		occ.erase("solid"); occ.erase("fadedm")

# 옆으로 눕힘: 로컬 x축으로 −90°, 가장 낮은 점이 땅에 닿게
static func _fallen_xf(node: Node3D) -> Transform3D:
	var bb := AABB(); var first := true
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var b: AABB = mi.transform * (mi as MeshInstance3D).get_aabb()
		bb = b if first else bb.merge(b); first = false
	var r := Basis(Vector3.RIGHT, -PI / 2)
	var lo := INF
	for i in 8:
		lo = minf(lo, (r * bb.get_endpoint(i)).y)
	return Transform3D(r, Vector3(0, -lo if lo < INF else 0.0, 0))
