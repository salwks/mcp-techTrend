# 가까운 사실 나무(trees-khs) — 숲 흩뿌리기의 임포스터 자료(kit/nature/scatter.gd khs_c*)에서 카메라 둘레(rh 안) 나무를 골라
# 나무마다 벌(LOD0 · LOD1 · 가까운 임포스터)을 정하고, 층마다 MultiMesh 버퍼를 다시 채운다. rh 밖은 흩뿌리기 임포스터 묶음이 그린다.
#   벌 고르기: 가까운 순으로 삼각형 예산(Khs.budget0·budget1) 안에서 LOD0(< r0) → LOD1(< r1) → 임포스터. 경계는 2m 머뭇거림.
#   벌이 바뀌면 lod_fade초 동안 두 벌을 같이 그리며 점무늬로 시간 섞기(인스턴스 자료 z 시작 시각·w 방향) — 거리 점무늬 띠가 화면에 남지 않게.
#   그림자: 가까운 순 cap_sh그루(rs 안)만 해를 향한 임포스터로. 조건부 식생 비우기(e.hid)로 숨긴 나무는 넣지 않는다. 충돌은 흩뿌리기 원 그대로.
extends Node3D

const Khs := preload("res://kit/nature/khs_trees.gd")
const CELL := 32.0
const MARGIN := 6.0
const REBUILD_MOVE := 2.5
const HYST := 2.0

var _items := {}        # 칸 Vector2i → Array[[entry, 번호, Transform3D, 층, 색, 열쇠]]
var _by_tile := {}      # 타일 → [칸…]
var _state := {}        # 열쇠 → [지금 벌, 이전 벌(-1 없음), 시작 시각]   벌: 0 LOD0, 1 LOD1, 2 가까운 임포스터, -1 안 그림(흩뿌리기 임포스터 몫)
var _mmi := {}          # "층:벌" → MultiMeshInstance3D (층 -1 = 모든 층: 임포스터·그림자)
var _last := Vector3(INF, INF, INF)
var _last_t := 0.0
var _busy := false      # 섞는 중인 나무가 있다 → 끝나면 다시 지어 나간 벌을 뺀다
var _next_id := 1
var dirty := true
var stats := { n0 = 0, n1 = 0, nimp = 0, nsh = 0, rebuild_us = 0 }
var wind := 0.35
var _trace := OS.get_cmdline_user_args().has("--treetrace")
var _t0 := Time.get_ticks_msec()
var _ucam := Vector3(INF, INF, INF)
var _ut := -10.0
var _uw := -1.0

func now() -> float:
	return float(Time.get_ticks_msec() - _t0) * 0.001

func add(t: Vector2i, e: Dictionary, buf: PackedFloat32Array) -> void:
	var base: Transform3D = e.xf
	var stride := 16
	if not e.has("khs_id"):
		e.khs_id = _next_id; _next_id += 1
	var cells: Array = _by_tile.get(t, [])
	for i in buf.size() / stride:
		var o := i * stride
		var xf := base * Transform3D(Basis(Vector3(buf[o], buf[o + 4], buf[o + 8]), Vector3(buf[o + 1], buf[o + 5], buf[o + 9]), Vector3(buf[o + 2], buf[o + 6], buf[o + 10])), Vector3(buf[o + 3], buf[o + 7], buf[o + 11]))
		var c := Vector2i(floori(xf.origin.x / CELL), floori(xf.origin.z / CELL))
		if not _items.has(c):
			_items[c] = []
			cells.append(c)
		var pf := PackedFloat32Array([xf.basis.x.x, xf.basis.y.x, xf.basis.z.x, xf.origin.x, xf.basis.x.y, xf.basis.y.y, xf.basis.z.y, xf.origin.y, xf.basis.x.z, xf.basis.y.z, xf.basis.z.z, xf.origin.z])
		_items[c].append([e, i, xf, int(buf[o + 12] + 0.5), buf[o + 13], int(e.khs_id) * 65536 + i, pf])
	_by_tile[t] = cells
	dirty = true

func drop_tile(t: Vector2i) -> void:
	for c in _by_tile.get(t, []):
		for it in _items.get(c, []): _state.erase(it[5])
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
		mm.use_custom_data = true
		match band:
			"sh": mm.mesh = Khs.imp_shadow_mesh
			"imp": mm.mesh = Khs.imp_near_mesh
			_: mm.mesh = Khs.mesh(layer, 0 if band == "l0" else 1, "mm")
		n.multimesh = mm
		n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY if band == "sh" else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(n)
		_mmi[key] = n
	return n

func _process(_dt: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null: return
	var p := cam.global_position
	var tn := now()
	# 재질 값은 바뀔 때만 넣는다(재질 30여 개 × 프레임마다 넣으면 그 자체가 값이 든다): 카메라 0.25m, 섞는 중일 때만 시각, 바람 0.02
	var set_cam := p.distance_to(_ucam) > 0.25
	var set_t := _busy or tn - _ut > 1.0
	var set_w := absf(wind - _uw) > 0.02
	if set_cam or set_t or set_w:
		for m in Khs.mats():
			var sm := m as ShaderMaterial
			if set_cam: sm.set_shader_parameter("lod_cam", p)
			if set_t: sm.set_shader_parameter("lod_time", tn)
			if set_w: sm.set_shader_parameter("wind_k", wind)
		if set_cam: _ucam = p
		if set_t: _ut = tn
		if set_w: _uw = wind
	var moved := Vector2(p.x - _last.x, p.z - _last.z).length()
	if dirty or moved > REBUILD_MOVE or (_busy and tn - _last_t > Khs.lod_fade + 0.02) or (moved > 0.5 and tn - _last_t > 0.4):
		_rebuild(p, tn, moved > 30.0)

func _rebuild(p: Vector3, tn: float, jump: bool) -> void:
	var t0 := Time.get_ticks_usec()
	dirty = false
	_last = p; _last_t = tn
	var r0 := Khs.r0; var r1 := Khs.r1; var rh := Khs.rh; var rs := Khs.rs
	var hi := rh + MARGIN
	var pp := Vector2(p.x, p.z)
	# 1) 후보(rh 안) — 거리순
	var cand := []
	var c0 := Vector2i(floori((p.x - hi) / CELL), floori((p.z - hi) / CELL))
	var c1 := Vector2i(floori((p.x + hi) / CELL), floori((p.z + hi) / CELL))
	for cz in range(c0.y, c1.y + 1):
		for cx in range(c0.x, c1.x + 1):
			var arr = _items.get(Vector2i(cx, cz))
			if arr == null: continue
			for it in arr:
				var xf: Transform3D = it[2]
				var d := pp.distance_to(Vector2(xf.origin.x, xf.origin.z))
				if d > hi: continue
				var e: Dictionary = it[0]
				if e.has("hid") and (e.hid as Dictionary).has(it[1]): continue
				cand.append([d, it])
	cand.sort_custom(func(a, b): return a[0] < b[0])
	# 2) 벌 정하기(예산·머뭇거림) → 바뀌면 시간 섞기 시작
	var used0 := 0; var used1 := 0; var nsh := 0
	var bufs := {}
	var seen := {}
	_busy = false
	var n0 := 0; var n1 := 0; var ni := 0
	for ci in cand:
		var d: float = ci[0]
		var it: Array = ci[1]
		var key: int = it[5]
		var L: int = it[3]
		seen[key] = true
		var st: Array = _state.get(key, [-1, -1, 0.0])
		var cur: int = st[0]
		var want := -1
		if d < (r0 + HYST if cur == 0 else r0) and used0 + Khs.tris0[L] <= Khs.budget0: want = 0
		elif d < (r1 + HYST if cur == 0 or cur == 1 else r1) and used1 + Khs.tris1[L] <= Khs.budget1: want = 1
		elif d < rh: want = 2
		if want == 0: used0 += Khs.tris0[L]
		elif want == 1: used1 += Khs.tris1[L]
		if want != cur:
			# 가까운 임포스터 ↔ 흩뿌리기 임포스터(같은 그림)는 바로, 나머지는 섞는다. 처음 보는 나무가 메시 벌이면 임포스터에서 섞어 들어온다
			var prev := cur
			if jump: prev = -1
			elif cur == -1 and want >= 0 and want < 2: prev = 2
			elif want == -1: prev = -1
			st = [want, prev, tn]
			_state[key] = st
		elif st[1] >= 0 and tn - float(st[2]) >= Khs.lod_fade:
			st = [cur, -1, st[2]]
			_state[key] = st
		var f: PackedFloat32Array = it[6]
		var fading: bool = st[1] >= 0
		if fading: _busy = true
		_put(bufs, st[0], L, f, it[4], float(st[2]) if fading else 0.0, 1.0 if fading else 0.0)
		if fading: _put(bufs, st[1], L, f, it[4], float(st[2]), -1.0)
		match int(st[0]):
			0: n0 += 1
			1: n1 += 1
			2: ni += 1
		if d < rs and nsh < Khs.cap_sh:
			nsh += 1
			_acc(bufs, "-1:sh", f, PackedFloat32Array([float(L), it[4], 0.0, 0.0]))
	for key in _state.keys():
		if not seen.has(key): _state.erase(key)
	# 3) 버퍼 넣기
	for key in _mmi:
		if not bufs.has(key): bufs[key] = []
	for key in bufs:
		var a: Array = bufs[key]
		if a.is_empty() and not _mmi.has(key): continue
		var ks := String(key).split(":")
		var n := _node(int(ks[0]), ks[1])
		var mm := n.multimesh
		var pb := PackedFloat32Array()
		for chunk in a: pb.append_array(chunk)
		mm.instance_count = pb.size() / 16
		if not pb.is_empty(): mm.buffer = pb
		n.visible = not pb.is_empty()
	stats.n0 = n0; stats.n1 = n1; stats.nimp = ni; stats.nsh = nsh
	stats.rebuild_us = Time.get_ticks_usec() - t0
	if _trace: print("TREELOD lod0=%d lod1=%d imp=%d sh=%d tris0=%dk tris1=%dk us=%d" % [n0, n1, ni, nsh, used0 / 1000, used1 / 1000, stats.rebuild_us])

func _put(bufs: Dictionary, band: int, L: int, f: PackedFloat32Array, hue: float, t0: float, dir: float) -> void:
	if band < 0: return
	var key := ("-1:imp" if band == 2 else "%d:%s" % [L, "l0" if band == 0 else "l1"])
	_acc(bufs, key, f, PackedFloat32Array([float(L), hue, t0, dir]))

static func _acc(bufs: Dictionary, key: String, f: PackedFloat32Array, cu: PackedFloat32Array) -> void:
	var a = bufs.get(key)
	if a == null:
		a = []
		bufs[key] = a
	(a as Array).append(f)
	(a as Array).append(cu)
