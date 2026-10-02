# 키트 build() 결과 디스크 캐시 — user://kit_cache/<해시>.scn(노드·메시) + .info(충돌체·조명·walk 등).
# 해시 = kit 경로 + params + 키트 스크립트와 같은 칸의 공용 스크립트(_*.gd) + scripts/kit/kit.gd 내용.
# 스크립트를 고치면 해시가 바뀌어 저절로 다시 짓는다. 작업 스레드에서 불러도 된다(노드는 트리 밖).
# 재질: Kit 공용 재질(Kit.material)은 파일에 넣지 않고 종류 이름만 적어 두었다가 불러올 때 다시 붙인다(모두 같은 재질 하나를 쓰게).
extends RefCounted

const DIR := "user://kit_cache/"
const VERSION := "1"

static var enabled := true
static var _src_hash := {}     # 칸 폴더 → 공용 스크립트 해시
static var _lock := Mutex.new()
static var hits := 0
static var misses := 0

static func _dir_hash(kit: String) -> String:
	var dir := "res://kit/" + kit.get_base_dir() + "/"
	_lock.lock()
	var h = _src_hash.get(dir)
	_lock.unlock()
	if h != null: return h
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_MD5)
	ctx.update(FileAccess.get_file_as_bytes("res://scripts/kit/kit.gd"))
	var da := DirAccess.open(dir)
	if da:
		var fs := Array(da.get_files()); fs.sort()
		for f in fs:
			if f.begins_with("_") and f.ends_with(".gd"): ctx.update(FileAccess.get_file_as_bytes(dir + f))
	var out := ctx.finish().hex_encode()
	_lock.lock(); _src_hash[dir] = out; _lock.unlock()
	return out

static func _key(kit: String, params: Dictionary) -> String:
	var s := VERSION + "|" + kit + "|" + JSON.stringify(params, "", true) + "|" + _dir_hash(kit)
	s += "|" + FileAccess.get_md5("res://kit/%s.gd" % kit)
	return s.md5_text()

# 캐시에서 읽거나 지어서 저장한다
static func build(kit: String, scr: Script, params: Dictionary) -> Dictionary:
	if not enabled: return scr.build(params)
	var k := _key(kit, params)
	var scn := DIR + k + ".scn"; var inf := DIR + k + ".info"
	if FileAccess.file_exists(scn) and FileAccess.file_exists(inf):
		var info = _load(scn, inf)
		if info is Dictionary:
			_lock.lock(); hits += 1; _lock.unlock()
			return info
	var res = scr.build(params)
	_lock.lock(); misses += 1; _lock.unlock()
	# 저장은 메인 스레드에서(메시 저장은 렌더 서버와 동기화가 필요해 작업 스레드에서 하면 멈춘다) — save_if_needed()
	if res is Dictionary and res.get("node") is Node3D:
		res["__cache_save"] = [scn, inf]
	return res

# 메인 스레드: 처음 지은 결과면 놓기 전에 디스크에 쓴다
static func save_if_needed(info: Dictionary) -> void:
	if not info.has("__cache_save"): return
	var p: Array = info["__cache_save"]
	info.erase("__cache_save")
	_save(info, p[0], p[1])

static func _save(info: Dictionary, scn: String, inf: String) -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	var root: Node3D = info.node
	# 공용 재질은 떼어 두고 이름만 적는다
	var mats := []   # [노드 경로, 표면, 종류]
	var meshes := root.find_children("*", "MeshInstance3D", true, false)
	if root is MeshInstance3D: meshes.push_front(root)
	var restore := []
	for mi in meshes:
		if mi.mesh == null: continue
		for s in mi.mesh.get_surface_count():
			var m = mi.mesh.surface_get_material(s)
			for kind in ["atlas", "cloth", "water"]:
				if m != null and m == Kit.material(kind):
					mats.append([str(root.get_path_to(mi)), s, kind])
					restore.append([mi.mesh, s, m])
					mi.mesh.surface_set_material(s, null)
					break
	_own(root, root)
	var ps := PackedScene.new()
	var ok := ps.pack(root) == OK and ResourceSaver.save(ps, scn, ResourceSaver.FLAG_COMPRESS) == OK
	for r in restore: r[0].surface_set_material(r[1], r[2])
	if not ok:
		DirAccess.remove_absolute(scn)
		return
	var data: Dictionary = _strip(info, root)
	data.erase("node")
	data["__mats"] = mats
	var f := FileAccess.open(inf, FileAccess.WRITE)
	if f: f.store_var(data, false)

static func _own(n: Node, root: Node) -> void:
	for c in n.get_children():
		c.owner = root
		_own(c, root)

# 사전 안의 Node는 경로 문자열(@node:경로)로, 그 밖의 Object(Resource)는 버린다
static func _strip(v, root: Node):
	if v is Dictionary:
		var o := {}
		for k in v: o[k] = _strip(v[k], root)
		return o
	if v is Array:
		var a := []
		for x in v: a.append(_strip(x, root))
		return a
	if v is Node:
		return "@node:" + str(root.get_path_to(v))
	if v is Object:
		return null
	return v

static func _unstrip(v, root: Node):
	if v is Dictionary:
		var o := {}
		for k in v: o[k] = _unstrip(v[k], root)
		return o
	if v is Array:
		var a := []
		for x in v: a.append(_unstrip(x, root))
		return a
	if v is String and v.begins_with("@node:"):
		return root.get_node_or_null(NodePath(v.substr(6)))
	return v

static func _load(scn: String, inf: String):
	var ps = ResourceLoader.load(scn, "", ResourceLoader.CACHE_MODE_IGNORE)
	if not (ps is PackedScene): return null
	var f := FileAccess.open(inf, FileAccess.READ)
	if f == null: return null
	var data = f.get_var(false)
	if not (data is Dictionary): return null
	var root = ps.instantiate()
	if not (root is Node3D): return null
	for m in data.get("__mats", []):
		var mi = root if m[0] == "." else root.get_node_or_null(NodePath(m[0]))
		if mi is MeshInstance3D and mi.mesh: mi.mesh.surface_set_material(int(m[1]), Kit.material(String(m[2])))
	data.erase("__mats")
	var info: Dictionary = _unstrip(data, root)
	info.node = root
	return info
