# 가까운 사실 나무(trees-khs) — 숲 흩뿌리기의 임포스터 자료(kit/nature/scatter.gd khs_c*)에서 카메라 둘레 나무만 골라
# 층(변형)마다 LOD0·LOD1·그림자 MultiMesh 버퍼를 다시 채운다. 먼 나무는 임포스터 묶음이 그대로 그린다.
#   경계는 셰이더가 나무 하나 단위 거리 점무늬로 섞는다(kit/nature/khs_trees.gd 띠 r0·r1). 여기 버퍼는 띠보다 MARGIN 넓게 담아
#   카메라가 REBUILD_MOVE 움직일 때까지 다시 짓지 않아도 빈틈이 없다.
#   조건부 식생 비우기(e.hid)로 숨긴 인스턴스는 넣지 않는다. 충돌체는 흩뿌리기 원(줄기)이 그대로 맡는다.
extends Node3D

const Khs := preload("res://kit/nature/khs_trees.gd")
const CELL := 32.0
const MARGIN := 7.0
const REBUILD_MOVE := 4.0

var _items := {}        # 칸 Vector2i → Array[[entry, 번호, Transform3D, 층]]
var _by_tile := {}      # 타일 → [칸…]
var _mmi := {}          # "층:벌" → MultiMeshInstance3D
var _last := Vector3(INF, INF, INF)
var dirty := true
var stats := { near = 0, mid = 0, rebuild_us = 0 }
var wind := 0.35
var _trace := OS.get_cmdline_user_args().has("--treetrace")

func add(t: Vector2i, e: Dictionary, buf: PackedFloat32Array) -> void:
	var base: Transform3D = e.xf
	var stride := 16
	var cells: Array = _by_tile.get(t, [])
	for i in buf.size() / stride:
		var o := i * stride
		var xf := base * Transform3D(Basis(Vector3(buf[o], buf[o + 4], buf[o + 8]), Vector3(buf[o + 1], buf[o + 5], buf[o + 9]), Vector3(buf[o + 2], buf[o + 6], buf[o + 10])), Vector3(buf[o + 3], buf[o + 7], buf[o + 11]))
		var c := Vector2i(floori(xf.origin.x / CELL), floori(xf.origin.z / CELL))
		if not _items.has(c):
			_items[c] = []
			cells.append(c)
		_items[c].append([e, i, xf, int(buf[o + 12] + 0.5), buf[o + 13]])
	_by_tile[t] = cells
	dirty = true

func drop_tile(t: Vector2i) -> void:
	for c in _by_tile.get(t, []):
		_items.erase(c)
	_by_tile.erase(t)
	dirty = true

func _node(layer: int, band: String) -> MultiMeshInstance3D:
	var key := "%d:%s" % [layer, band]
	var n: MultiMeshInstance3D = _mmi.get(key)
	if n == null:
		n = MultiMeshInstance3D.new()
		n.name = "khs_%s_%s" % [Khs.NAMES[layer] if layer >= 0 else "all", band]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		if band == "sh":
			mm.use_custom_data = true
			mm.mesh = Khs.imp_shadow_mesh
		else:
			mm.mesh = Khs.mesh(layer, 0 if band == "l0" else 1, band)
		n.multimesh = mm
		n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY if band == "sh" else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(n)
		_mmi[key] = n
	return n

func _process(_dt: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null: return
	var p := cam.global_position
	for m in Khs.mats():
		(m as ShaderMaterial).set_shader_parameter("lod_cam", p)
		(m as ShaderMaterial).set_shader_parameter("wind_k", wind)
	if dirty or Vector2(p.x - _last.x, p.z - _last.z).length() > REBUILD_MOVE:
		_rebuild(p)

func _rebuild(p: Vector3) -> void:
	var t0 := Time.get_ticks_usec()
	dirty = false
	_last = p
	var r0 := Khs.r0; var r1 := Khs.r1
	var lo0 := r0 + MARGIN; var lo1 := r0 - Khs.f0 - MARGIN; var hi1 := r1 + MARGIN
	var bufs := {}   # "층:벌" → Array
	var c0 := Vector2i(floori((p.x - hi1) / CELL), floori((p.z - hi1) / CELL))
	var c1 := Vector2i(floori((p.x + hi1) / CELL), floori((p.z + hi1) / CELL))
	var pp := Vector2(p.x, p.z)
	var nn := 0; var nm := 0
	for cz in range(c0.y, c1.y + 1):
		for cx in range(c0.x, c1.x + 1):
			var arr = _items.get(Vector2i(cx, cz))
			if arr == null: continue
			for it in arr:
				var xf: Transform3D = it[2]
				var d := pp.distance_to(Vector2(xf.origin.x, xf.origin.z))
				if d > hi1: continue
				var e: Dictionary = it[0]
				if e.has("hid") and (e.hid as Dictionary).has(it[1]): continue
				var L: int = it[3]
				var f := [xf.basis.x.x, xf.basis.y.x, xf.basis.z.x, xf.origin.x, xf.basis.x.y, xf.basis.y.y, xf.basis.z.y, xf.origin.y, xf.basis.x.z, xf.basis.y.z, xf.basis.z.z, xf.origin.z]
				if d < Khs.rs + MARGIN: _acc(bufs, "-1:sh", f + [float(L), it[4], 0.0, 0.0])
				if d < lo0:
					_acc(bufs, "%d:l0" % L, f); nn += 1
				if d > lo1:
					_acc(bufs, "%d:l1" % L, f); nm += 1
	for key in _mmi:
		if not bufs.has(key): bufs[key] = []
	for key in bufs:
		var a: Array = bufs[key]
		var ks := String(key).split(":")
		if a.is_empty() and not _mmi.has(key): continue
		var n := _node(int(ks[0]), ks[1])
		var mm := n.multimesh
		mm.instance_count = a.size() / (16 if mm.use_custom_data else 12)
		if not a.is_empty(): mm.buffer = PackedFloat32Array(a)
		n.visible = not a.is_empty()
	stats.near = nn; stats.mid = nm
	stats.rebuild_us = Time.get_ticks_usec() - t0
	if _trace:
		print("TREELOD near=%d mid=%d us=%d items_cells=%d cam=%s" % [nn, nm, stats.rebuild_us, _items.size(), p])
		var best := []
		for c in _items:
			for it in _items[c]:
				var o: Vector3 = (it[2] as Transform3D).origin
				var dd := Vector2(o.x - p.x, o.z - p.z).length()
				if dd < 45.0 and it[3] <= 3 and (it[2] as Transform3D).basis.get_scale().y * Khs.height(it[3]) > 9.0: best.append([dd, it[3], o, (it[2] as Transform3D).basis.get_scale().y * Khs.height(it[3])])
		best.sort_custom(func(a, b): return a[0] < b[0])
		for b in best.slice(0, 6): print("  TREE d=%.1f layer=%d at=(%.1f,%.1f,%.1f) h=%.1f" % [b[0], b[1], b[2].x, b[2].y, b[2].z, b[3]])

static func _acc(bufs: Dictionary, key: String, f: Array) -> void:
	var a = bufs.get(key)
	if a == null:
		a = []
		bufs[key] = a
	(a as Array).append_array(f)
