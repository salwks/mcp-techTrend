# 월드: 웹 프로토타입에서 내보낸 마을(glTF)과 데이터(world.json, 높이 격자)를 불러온다.
# 계약은 웹 CONTRACTS.md §2의 World와 같다(heightAt, colliders, cameraZones, interiors, occluders, lights...).
class_name World
extends Node3D

const DATA := "res://data/"
const MAX_SLOPE := 1.1

var data: Dictionary
var heights: PackedFloat32Array
var hx0: float; var hz0: float; var hstep: float; var hnx: int; var hnz: int
var colliders: Array = []
var camera_zones: Array = []
var interiors: Array = []   # { name, minX.., camera, hide:[Node3D] }
var occluders: Array = []   # { node, aabb:AABB(월드), meshes:[MeshInstance3D], alpha, target }
var lights: Array = []
var npcs: Array = []
var spawn := Vector2.ZERO
var glow_meshes: Array = []
var stream_mats: Array = []
var _nodes := {}

func load_all() -> void:
	data = JSON.parse_string(FileAccess.get_file_as_string(DATA + "world.json"))
	_load_heights(data.heights)
	colliders = data.colliders
	camera_zones = data.cameraZones
	lights = data.lights
	npcs = data.npcs
	spawn = Vector2(data.spawn.x, data.spawn.z)
	_load_scene()
	for it in data.interiors:
		var hide := []
		for n in it.hide:
			if _nodes.has(n): hide.append(_nodes[n])
		var d: Dictionary = it.duplicate()
		d.hide = hide
		interiors.append(d)
	for n in data.occluders:
		if not _nodes.has(n): continue
		var node: Node3D = _nodes[n]
		var meshes := []
		var box := AABB()
		var first := true
		for m in node.find_children("*", "MeshInstance3D", true, false):
			meshes.append(m)
			var b: AABB = m.global_transform * m.get_aabb()
			box = b if first else box.merge(b)
			first = false
		if meshes.is_empty(): continue
		occluders.append({ node = node, aabb = box, meshes = meshes, alpha = 1.0, target = 1.0, faded = false })

func _load_heights(h: Dictionary) -> void:
	hx0 = h.x0; hz0 = h.z0; hstep = h.step; hnx = int(h.nx); hnz = int(h.nz)
	heights = FileAccess.get_file_as_bytes(DATA + h.file).to_float32_array()

func height_at(x: float, z: float) -> float:
	var fx := clampf((x - hx0) / hstep, 0.0, hnx - 1.001)
	var fz := clampf((z - hz0) / hstep, 0.0, hnz - 1.001)
	var i := int(fx); var j := int(fz)
	var tx := fx - i; var tz := fz - j
	var a := heights[j * hnx + i]; var b := heights[j * hnx + i + 1]
	var c := heights[(j + 1) * hnx + i]; var d := heights[(j + 1) * hnx + i + 1]
	return lerpf(lerpf(a, b, tx), lerpf(c, d, tx), tz)

func _load_scene() -> void:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_file(ProjectSettings.globalize_path(DATA + "village.glb"), state)
	if err != OK:
		push_error("village.glb 불러오기 실패: %s" % err)
		return
	var root: Node = doc.generate_scene(state)
	add_child(root)
	var meta: Dictionary = data.meshes
	var glow := {}
	for n in data.glow: glow[n] = true
	var hidden := {}
	for n in data.hidden: hidden[n] = true
	var mat_cache := {}
	for node in root.find_children("*", "Node3D", true, false):
		_nodes[String(node.name)] = node
	for name in _nodes:
		var node: Node3D = _nodes[name]
		if hidden.has(name): node.visible = false
		if not (node is MeshInstance3D): continue
		var mi := node as MeshInstance3D
		var m := meta.get(name, [1, 1, "", 0, 0, 1, 0]) as Array
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if int(m[0]) == 1 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for s in mi.mesh.get_surface_count():
			var src := mi.get_active_material(s) as BaseMaterial3D
			if src == null: continue
			var key := [src.get_instance_id(), glow.has(name)]
			if not mat_cache.has(key):
				mat_cache[key] = Materials.from_standard(src, glow.has(name))
			mi.set_surface_override_material(s, mat_cache[key])
		if glow.has(name): glow_meshes.append(mi)
		if name == data.get("stream_name", "") or data.origNames.get(name, "") == "stream":
			var sm: ShaderMaterial = mi.get_surface_override_material(0)
			stream_mats.append(sm)

# 가림 처리용으로 재질을 물체마다 따로 갖게 한다(웹 occlusion.js의 clone과 같음)
func own_materials(occ: Dictionary) -> void:
	if occ.has("solid"): return
	var solid := []; var faded := []
	for mi in occ.meshes:
		var s_list := []; var f_list := []
		for s in mi.mesh.get_surface_count():
			var sm := mi.get_surface_override_material(s) as ShaderMaterial
			s_list.append(sm)
			var f := Materials.faded_copy(sm) if sm else null
			f_list.append(f)
		solid.append(s_list); faded.append(f_list)
	occ.solid = solid; occ.fadedm = faded

func set_occluder_alpha(occ: Dictionary, a: float) -> void:
	own_materials(occ)
	var use_fade := a < 0.999
	for i in occ.meshes.size():
		var mi: MeshInstance3D = occ.meshes[i]
		for s in mi.mesh.get_surface_count():
			var f: ShaderMaterial = occ.fadedm[i][s]
			if f == null: continue
			if use_fade:
				f.set_shader_parameter("fade", a)
				mi.set_surface_override_material(s, f)
			else:
				mi.set_surface_override_material(s, occ.solid[i][s])

func update(_dt: float, time: float) -> void:
	for sm in stream_mats:
		sm.set_shader_parameter("uv_offset", Vector2(-time * 0.045, sin(time * 0.6) * 0.01))

# ---- 충돌(웹 core/motion.js) ----
func blocked(x: float, z: float, r: float) -> bool:
	for c in colliders:
		if c.type == "circle":
			var dx: float = x - c.x; var dz: float = z - c.z; var rr: float = r + c.r
			if dx * dx + dz * dz < rr * rr: return true
		else:
			var nx := clampf(x, c.minX, c.maxX); var nz := clampf(z, c.minZ, c.maxZ)
			var dx := x - nx; var dz := z - nz
			if dx * dx + dz * dz < r * r: return true
	return false

func _step_ok(fx: float, fz: float, tx: float, tz: float, r: float, extra: Callable) -> bool:
	if blocked(tx, tz, r): return false
	if extra.is_valid() and extra.call(tx, tz): return false
	var dist := maxf(Vector2(tx - fx, tz - fz).length(), 1e-6)
	return (height_at(tx, tz) - height_at(fx, fz)) / dist <= MAX_SLOPE

# 막히면 축별로 미끄러지듯. pos는 Vector3(x, y, z)이고 갱신된 값을 돌려준다(이동 못 하면 null)
func move_circle(pos: Vector3, dx: float, dz: float, r: float, extra := Callable()) -> Variant:
	var tx := pos.x + dx; var tz := pos.z + dz
	if _step_ok(pos.x, pos.z, tx, tz, r, extra): return Vector3(tx, pos.y, tz)
	if dx != 0.0 and _step_ok(pos.x, pos.z, tx, pos.z, r, extra): return Vector3(tx, pos.y, pos.z)
	if dz != 0.0 and _step_ok(pos.x, pos.z, pos.x, tz, r, extra): return Vector3(pos.x, pos.y, tz)
	return null

static func in_box(b: Dictionary, x: float, z: float) -> bool:
	return x >= b.minX and x <= b.maxX and z >= b.minZ and z <= b.maxZ

func interior_at(x: float, z: float) -> Variant:
	for it in interiors:
		if in_box(it, x, z): return it
	return null
