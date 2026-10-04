# 바닥·벽 데칼(PRP_COM_002 피·진흙·발자국, 004 발톱 긁힘, 006 젖은 발자국(마름), 007 밀가루 면, 008 그을림) — RegionWorld.decals.
# 데이터: region_data/<권역|노정>/decals_*.json  { "items": [데칼…], "trails": [발자국 줄…] }  (배치 다시 읽기 F5 때 같이 다시 읽는다)
#   데칼: { id, kind, x, z, ry(라디안, 발자국은 걷는 방향: 0 = −z(북) 쪽으로 걸음), size(m, 긴 변), w(폭 배율), y(없으면 땅·마루 높이),
#          wall:true(벽·나무에 세운 데칼 — y 필수, ry = 벽 면이 보는 방향), color:"#rrggbb", alpha, group, hidden, dry(초 — 그동안 옅어져 사라짐) }
#   발자국 줄: { id, kind:"foot"|"paw"|"shoe"|"hoof"|"wet_foot"…, points:[[x,z]…], step(m), size, spread(좌우 벌림 m), group, hidden }
# 실행 중(사건): world.decals.add(spec) → id, remove(id), trail(id, kind, points, opts) → [id…], set_group_visible(group, on),
#   clear_group(group), dry(id_or_group, 초), traces_near(p, r)(감응 — spec의 trace: human|other|mixed)
# 그리기: 32m 칸마다 메시 하나(반투명 키트 재질 — 빛·안개·젖음을 키트와 같이 받는다), 땅 모양에 맞게 0.5m 격자로 덮는다.
extends Node3D

const CELL := 32.0
const LIFT := 0.035
const KINDS := {
	foot = { cell = 0, color = Color(0.2, 0.15, 0.1, 0.9), size = 0.36, w = 0.55 },
	wet_foot = { cell = 0, color = Color(0.06, 0.08, 0.11, 0.7), size = 0.36, w = 0.55, dry = 120.0 },
	paw = { cell = 1, color = Color(0.2, 0.15, 0.1, 0.9), size = 0.3, w = 1.0 },
	blood = { cell = 2, color = Color(0.34, 0.03, 0.03, 0.85), size = 0.7, w = 1.0 },
	claw = { cell = 3, color = Color(0.2, 0.15, 0.1, 0.85), size = 0.6, w = 0.8 },
	flour = { cell = 4, color = Color(0.96, 0.95, 0.9, 0.95), size = 1.6, w = 1.0 },
	scorch = { cell = 5, color = Color(0.03, 0.025, 0.02, 1.0), size = 2.5, w = 1.0 },
	puddle = { cell = 6, color = Color(0.12, 0.14, 0.17, 0.5), size = 1.0, w = 1.0, dry = 0.0 },
	hoof = { cell = 7, color = Color(0.2, 0.15, 0.1, 0.85), size = 0.2, w = 1.0 },
	rut = { cell = 8, color = Color(0.3, 0.24, 0.17, 0.7), size = 1.6, w = 0.25 },
	drag = { cell = 9, color = Color(0.3, 0.24, 0.17, 0.65), size = 1.5, w = 0.6 },
	mud = { cell = 10, color = Color(0.28, 0.21, 0.14, 0.85), size = 0.6, w = 1.0 },
	snake = { cell = 11, color = Color(0.5, 0.46, 0.4, 0.4), size = 1.8, w = 0.45 },
	shoe = { cell = 12, color = Color(0.2, 0.15, 0.1, 0.9), size = 0.32, w = 0.5 },
	drip = { cell = 13, color = Color(0.34, 0.03, 0.03, 0.85), size = 1.0, w = 0.25 },
	ash = { cell = 14, color = Color(0.32, 0.31, 0.3, 0.9), size = 0.9, w = 1.0 },
	ink = { cell = 15, color = Color(0.03, 0.03, 0.04, 0.92), size = 0.45, w = 1.0 },
	flour_foot = { cell = 0, color = Color(0.4, 0.38, 0.33, 0.85), size = 0.3, w = 0.55 },   # 밀가루 위 발자국(밀가루 데칼 위에 놓는다)
	flour_paw = { cell = 1, color = Color(0.45, 0.42, 0.36, 0.85), size = 0.24, w = 1.0 },
}

var world
var _mat: ShaderMaterial
var _items := {}       # id → spec(정규화: x z y ry size w wall color(선형 RGBA) group hidden fade dry_t dry_left data)
var _cells := {}       # Vector2i → { mi: MeshInstance3D, ids: {} , dirty }
var _seq := 0
var _hidden_groups := {}
var _drying := {}      # id → true
var _dry_acc := 0.0

func setup(w) -> void:
	world = w
	name = "decals"
	_mat = ShaderMaterial.new()
	var code: String = Materials.world_shader(true, true, false).code
	code = code.replace("ALPHA = albedo_color.a * t.a * fade;", "ALPHA = albedo_color.a * t.a * fade * COLOR.a;")
	var sh := Shader.new(); sh.code = code
	_mat.shader = sh
	_mat.set_shader_parameter("ramp_tex", Materials.ramp_texture())
	_mat.set_shader_parameter("albedo_tex", Kit.texture("decals"))
	_mat.set_shader_parameter("kit_tiling", 0.0)
	_mat.set_shader_parameter("albedo_color", Vector4(1, 1, 1, 1))
	# 반투명 물결(region_main이 물 재질에 넣는 값)은 쓰지 않음

# ---------------------------------------------------------------------------
# 데이터
# ---------------------------------------------------------------------------
func reload_data() -> void:
	for id in _items.keys():
		if _items[id].data: _remove(id)
	var dir: String = world.data_dir
	var da := DirAccess.open(dir)
	if da == null: return
	var n := 0
	for f in da.get_files():
		if not (f.begins_with("decals_") and f.ends_with(".json")): continue
		var d = JSON.parse_string(FileAccess.get_file_as_string(dir + f))
		if not (d is Dictionary): push_warning("데칼 파일 형식 오류: " + f); continue
		for it in d.get("items", []):
			if it is Dictionary: _add(it, true); n += 1
		for t in d.get("trails", []):
			if t is Dictionary and t.get("points") is Array:
				n += _trail(String(t.get("id", "trail")), String(t.get("kind", "foot")), t.points, t, true).size()
	if n > 0: print("DECALS data=%d" % n)

# ---------------------------------------------------------------------------
# 공개 API
# ---------------------------------------------------------------------------
func add(spec: Dictionary) -> String:
	return _add(spec, false)

func remove(id: String) -> void:
	_remove(id)

func has(id: String) -> bool:
	return _items.has(id)

# 발자국 줄: points(꺾은선 [[x,z]…] 또는 Vector2 배열)를 따라 step 간격으로 좌우 번갈아. opts: step, size, spread, group, hidden, color, alpha, dry
func trail(id: String, kind: String, points: Array, opts := {}) -> Array:
	return _trail(id, kind, points, opts, false)

func set_group_visible(group: String, on: bool) -> void:
	if on: _hidden_groups.erase(group)
	else: _hidden_groups[group] = true
	for id in _items:
		if _items[id].group == group:
			_items[id].hidden = not on
			_dirty(id)

func clear_group(group: String) -> void:
	for id in _items.keys():
		if _items[id].group == group: _remove(id)

# id 또는 group을 seconds 동안 옅게 하다 지운다(젖은 발자국이 마름)
func dry(id_or_group: String, seconds: float) -> void:
	for id in _items:
		var it: Dictionary = _items[id]
		if id == id_or_group or it.group == id_or_group:
			it.dry_t = maxf(0.01, seconds); it.dry_left = it.dry_t
			_drying[id] = true

# 흔적의 결(감응 매듭 — scripts/story/sensing.gd): 데칼·발자국 줄 spec의 trace: "human"(사람이 만든) | "other"(사람 아닌 것) | "mixed".
# p 둘레 r 안의 보이는 데칼 중 trace가 있는 것 [{ id, trace, kind, group, d }] (가까운 순 아님)
func traces_near(p: Vector2, r: float) -> Array:
	var out := []
	for id in _items:
		var it: Dictionary = _items[id]
		if it.trace == "" or it.hidden or it.fade <= 0.05: continue
		var dd := Vector2(it.x, it.z).distance_to(p)
		if dd <= r: out.append({ id = id, trace = it.trace, kind = it.kind, group = it.group, d = dd })
	return out

func ids_in(group: String) -> Array:
	var out := []
	for id in _items:
		if _items[id].group == group: out.append(id)
	return out

# ---------------------------------------------------------------------------
func _add(spec: Dictionary, from_data: bool) -> String:
	var kind := String(spec.get("kind", "foot"))
	var k: Dictionary = KINDS.get(kind, KINDS.foot)
	var id := String(spec.get("id", ""))
	if id == "":
		_seq += 1; id = "decal_%d" % _seq
	if _items.has(id): _remove(id)
	var col: Color = k.color
	if spec.get("color") is String: col = Color(String(spec.color)); col.a = k.color.a
	if spec.has("alpha"): col.a = float(spec.alpha)
	var group := String(spec.get("group", ""))
	var it := {
		id = id, kind = kind, cell = int(k.cell), x = float(spec.get("x", 0.0)), z = float(spec.get("z", 0.0)),
		y = (float(spec.y) if spec.get("y") != null else NAN), ry = float(spec.get("ry", 0.0)),
		size = float(spec.get("size", k.size)), w = float(spec.get("w", k.w)), wall = bool(spec.get("wall", false)),
		color = col.srgb_to_linear() if spec.get("color") is String else col, group = group,
		hidden = bool(spec.get("hidden", false)) or _hidden_groups.has(group), fade = 1.0, dry_t = 0.0, dry_left = 0.0, data = from_data,
		trace = String(spec.get("trace", "")),
	}
	it.color.a = col.a
	var dr := float(spec.get("dry", k.get("dry", 0.0)))
	if dr > 0.0:
		it.dry_t = dr; it.dry_left = dr; _drying[id] = true
	_items[id] = it
	_dirty(id)
	return id

func _trail(id: String, kind: String, points: Array, opts: Dictionary, from_data: bool) -> Array:
	var pts := PackedVector2Array()
	for p in points:
		if p is Vector2: pts.append(p)
		elif p is Vector3: pts.append(Vector2(p.x, p.z))
		elif p is Array and p.size() >= 2: pts.append(Vector2(float(p[0]), float(p[1])))
	var out := []
	if pts.size() < 2: return out
	var k: Dictionary = KINDS.get(kind, KINDS.foot)
	var step := float(opts.get("step", 0.7 if kind in ["foot", "shoe", "wet_foot", "flour_foot"] else (1.1 if kind == "paw" else 0.9)))
	var spread := float(opts.get("spread", 0.14 if kind in ["foot", "shoe", "wet_foot", "flour_foot"] else 0.1))
	var cont := kind in ["rut", "drag", "snake"]
	if cont: step = float(opts.get("step", float(k.size) * 0.95))
	var acc := 0.0; var n := 0
	for i in pts.size() - 1:
		var a := pts[i]; var b := pts[i + 1]
		var L := a.distance_to(b)
		if L < 0.01: continue
		var d := (b - a) / L
		var side := Vector2(-d.y, d.x)
		var s := acc
		while s < L:
			var p := a + d * s
			if not cont: p += side * spread * (1.0 if n % 2 == 0 else -1.0)
			var spec := opts.duplicate()
			spec.erase("points"); spec.erase("step"); spec.erase("spread")
			spec.merge({ id = "%s_%03d" % [id, n], kind = kind, x = p.x, z = p.y, ry = atan2(d.x, -d.y) }, true)
			out.append(_add(spec, from_data))
			n += 1
			s += step
		acc = s - L
	return out

func _remove(id: String) -> void:
	if not _items.has(id): return
	_dirty(id)
	_items.erase(id)
	_drying.erase(id)

func _cell_of(it: Dictionary) -> Vector2i:
	return Vector2i(floori(it.x / CELL), floori(it.z / CELL))

func _dirty(id: String) -> void:
	var c := _cell_of(_items[id])
	if not _cells.has(c): _cells[c] = { mi = null, dirty = true }
	_cells[c].dirty = true

# region_world.update에서 매 프레임
func update(dt: float) -> void:
	if not _drying.is_empty():
		_dry_acc += dt
		if _dry_acc >= 0.5:
			for id in _drying.keys():
				if not _items.has(id): _drying.erase(id); continue
				var it: Dictionary = _items[id]
				it.dry_left -= _dry_acc
				var f := clampf(it.dry_left / maxf(it.dry_t, 0.01), 0.0, 1.0)
				if f <= 0.0: _remove(id); continue
				if absf(f - it.fade) > 0.04: it.fade = f; _dirty(id)
			_dry_acc = 0.0
	var built := 0
	for c in _cells:
		if not _cells[c].dirty: continue
		_build_cell(c)
		built += 1
		if built >= 4: break

func _build_cell(c: Vector2i) -> void:
	var cell: Dictionary = _cells[c]
	cell.dirty = false
	var v := PackedVector3Array(); var nrm := PackedVector3Array(); var uv := PackedVector2Array(); var col := PackedColorArray()
	var idx := PackedInt32Array()
	for id in _items:
		var it: Dictionary = _items[id]
		if it.hidden or _cell_of(it) != c: continue
		_emit(it, v, nrm, uv, col, idx)
	if v.is_empty():
		if cell.mi != null: cell.mi.queue_free(); cell.mi = null
		return
	var arr := []; arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v; arr[Mesh.ARRAY_NORMAL] = nrm; arr[Mesh.ARRAY_TEX_UV] = uv; arr[Mesh.ARRAY_COLOR] = col; arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	m.surface_set_material(0, _mat)
	if cell.mi == null:
		var mi := MeshInstance3D.new()
		mi.name = "decals_%d_%d" % [c.x, c.y]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visibility_range_end = 160.0
		add_child(mi)
		cell.mi = mi
	cell.mi.mesh = m

# 데칼 하나 → 삼각형(Godot 시계 방향 앞면)
func _emit(it: Dictionary, v: PackedVector3Array, nrm: PackedVector3Array, uv: PackedVector2Array, col: PackedColorArray, idx: PackedInt32Array) -> void:
	var L: float = it.size; var Wd: float = it.size * it.w
	var ci: int = it.cell
	var u0 := (ci % 4) * 0.25 + 0.002; var v0 := (ci / 4) * 0.25 + 0.002; var cw := 0.25 - 0.004
	var cc: Color = it.color
	cc.a = it.color.a * it.fade
	var ry: float = it.ry
	var fwd := Vector2(sin(ry), -cos(ry))       # 데칼 위쪽(텍스처 v 0 → 앞) = 걷는 방향
	var rt := Vector2(-fwd.y, fwd.x)
	var base := v.size()
	if it.wall:
		# 세운 데칼: 면 방향 (sin ry, cos ry)
		var n3 := Vector3(sin(ry), 0, cos(ry))
		var r3 := Vector3(cos(ry), 0, -sin(ry))
		var c3 := Vector3(it.x, it.y if not is_nan(it.y) else world.height_at(it.x, it.z) + L * 0.5, it.z) + n3 * 0.03
		var corners := [[-0.5, 0.5], [0.5, 0.5], [0.5, -0.5], [-0.5, -0.5]]   # (가로, 세로) 위가 +
		for q in corners:
			v.append(c3 + r3 * (q[0] * Wd) + Vector3.UP * (q[1] * L))
			nrm.append(n3)
			uv.append(Vector2(u0 + (q[0] + 0.5) * cw, v0 + (0.5 - q[1]) * cw))
			col.append(cc)
		idx.append_array(PackedInt32Array([base, base + 1, base + 2, base, base + 2, base + 3]))
		return
	var n := clampi(ceili(maxf(L, Wd) / 0.5), 1, 8)
	for j in n + 1:
		for i in n + 1:
			var a := float(i) / n - 0.5; var b := float(j) / n - 0.5   # a: 가로(오른쪽 +), b: 세로(앞 +)
			var p := Vector2(it.x, it.z) + rt * (a * Wd) + fwd * (b * L)
			var y: float = (it.y if not is_nan(it.y) else world.height_at(p.x, p.y)) + LIFT
			v.append(Vector3(p.x, y, p.y))
			nrm.append(Vector3.UP)
			uv.append(Vector2(u0 + (a + 0.5) * cw, v0 + (0.5 - b) * cw))
			col.append(cc)
	for j in n:
		for i in n:
			var q := base + j * (n + 1) + i
			# 위에서 볼 때 시계 방향(Godot 앞면)
			idx.append_array(PackedInt32Array([q, q + n + 1, q + 1, q + 1, q + n + 1, q + n + 2]))
