# 물살 표식 — 플레이어가 물에 작은 표식(찌)을 던지고, 표식이 데이터로 정한 물살을 따라 떠내려가 어느 갯가에 닿는지 지켜본다.
#   황주 「빈 배의 값」 S4004(던진 표식이 다른 해안으로 돌아옴)에서 처음 쓰고, 강·바다 사건(떠내려온 물건·실종자 찾기)이 같이 쓴다.
#   믿음·소문보다 지금 눈으로 확인할 수 있는 물리 현상을 먼저 보게 하는 장치다(§13 S4008 이겸의 메모).
#
# 사건 데이터 "currents": { <물살 id>: field }
#   field = {
#     "streams": [{ "id", "points": [자리…], "width": m(이만큼 떨어지면 힘이 1/e), "speed": m/s, "pull": 0~1(물줄기 가운데로 끄는 힘) }],
#     "ambient": [vx, vz]   물줄기 밖의 느린 흐름(m/s, 바람·밀물)
#     "noise": m/s          좌우로 흔들리는 정도(표식마다 위상이 다르다)
#     "shores": [{ "id", "at": 자리, "radius": m, "name": "만 안쪽 모래톱", "rest": 자리(닿으면 여기로 밀려 올라감 — 없으면 at) }]
#     "max_time": 초(물살 시간 — 넘기면 먼바다로 '잃음'), "sea_y": 물 높이(없으면 world.sea_y 또는 0)
#   }
#   자리는 story_director.anchor()가 푸는 것(앵커 이름 · [x, z]).
#
# 이야기 명령 { "drift": <물살 id>, "from": 자리, "n": 3, "spread": 1.5, "seed": 4004, "watch": true, "time_scale": 3.0,
#               "hours": 0.5, "view": { "distance": 34, "pitch": 40 }, "store": "drift", "throw_from": "player" }
#   watch=true: 던지고 떠내려가는 것을 카메라가 따라가며 지켜본다(조작 막음, 다 닿거나 잃을 때까지). 결과는 표식마다 닿은 갯가 id("" = 잃음).
#   watch=false: 던지고 바로 돌아온다. 표식은 실제 시간으로 떠내려가 닿으면 깃발(flags)만 남긴다.
#   hours: 지켜보는 동안 흐르는 시각(물때가 바뀌도록 — d.set_hour).
#   닿은 수는 S.flags["drift_<갯가 id>"](정수)에, 마지막 결과는 S.flags["drift_last_<물살 id>"]에 남는다.
#   표식 노드는 끝나면 지운다 — 닿은 자리의 표식은 사건 데이터 props(조건 f('drift_<갯가>'))로 세워 저장·불러오기에도 남게 한다.
# 순수 함수 velocity(field, p, t, phase)와 simulate()는 노드 없이 쓸 수 있다(시험·물줄기 맞추기).
extends Node

const STEP := 0.1          # 물살 적분 간격(초, 물살 시간)

var d
var field: Dictionary
var field_id := ""
var markers: Array = []    # [{ node, p: Vector2, phase, state: "air"|"float"|"landed"|"lost", shore, t, air_t, from: Vector3, to: Vector2, foam }]
var sea_y := 0.0
var t := 0.0
var time_scale := 1.0
var watch := false
var hours := 0.0
var _h0 := 0.0
var _done := false
var _mat_wood: StandardMaterial3D
var _mat_cloth: StandardMaterial3D
var _mat_foam: StandardMaterial3D

signal finished(result: Array)

static func run(director, st: Dictionary) -> Array:
	var fid := String(st.drift)
	var f: Dictionary = director.data.get("currents", {}).get(fid, {})
	if f.is_empty():
		push_warning("물살: 없는 물살 " + fid); return []
	var dr = load("res://scripts/story/drift.gd").new()
	dr.name = "drift_" + fid
	dr.d = director
	dr.field = f
	dr.field_id = fid
	director.add_child(dr)
	dr._start(st)
	if not dr.watch: return []
	var res: Array = await dr.finished
	return res

# ---------------------------------------------------------------------------
# 물살(노드 없이도 쓰는 순수 함수)
# ---------------------------------------------------------------------------
# 꺾은선 위 가장 가까운 자리: { dist, tan, to(점→선 방향), s }
static func _closest(pts: PackedVector2Array, p: Vector2) -> Dictionary:
	var best := INF; var tan := Vector2.RIGHT; var to := Vector2.ZERO; var s := 0.0; var acc := 0.0; var last := false
	for i in pts.size() - 1:
		var a := pts[i]; var ab := pts[i + 1] - a
		var l := ab.length()
		if l < 1e-4: continue
		var u := clampf((p - a).dot(ab) / (l * l), 0.0, 1.0)
		var q := a + ab * u
		var dd := p.distance_to(q)
		if dd < best:
			best = dd; tan = ab / l; to = (q - p) / maxf(dd, 1e-4); s = acc + u * l; last = i == pts.size() - 2 and u >= 0.999
		acc += l
	return { dist = best, tan = tan, to = to, s = s, end = last }

static func prepare_field(director, f: Dictionary) -> Dictionary:
	if f.has("_ready"): return f
	var streams := []
	for sm in f.get("streams", []):
		var pts := PackedVector2Array()
		for q in sm.get("points", []): pts.append(director.anchor(q) if director != null else Vector2(float(q[0]), float(q[1])))
		streams.append({ id = String(sm.get("id", "")), pts = pts, width = float(sm.get("width", 6.0)), speed = float(sm.get("speed", 0.6)),
			pull = float(sm.get("pull", 0.4)) })
	var shores := []
	for sh in f.get("shores", []):
		var c: Vector2 = director.anchor(sh.at) if director != null else Vector2(float(sh.at[0]), float(sh.at[1]))
		var rest: Vector2 = c
		if sh.has("rest"): rest = director.anchor(sh.rest) if director != null else Vector2(float(sh.rest[0]), float(sh.rest[1]))
		shores.append({ id = String(sh.id), c = c, r = float(sh.get("radius", 4.0)), rest = rest, name = String(sh.get("name", "")) })
	var amb = f.get("ambient", [0.0, 0.0])
	f["_streams"] = streams; f["_shores"] = shores; f["_amb"] = Vector2(float(amb[0]), float(amb[1])); f["_ready"] = true
	return f

static func velocity(f: Dictionary, p: Vector2, tt: float, phase: float) -> Vector2:
	var v := Vector2.ZERO
	var wsum := 0.0
	var lat := Vector2.ZERO
	for sm in f._streams:
		var c := _closest(sm.pts, p)
		var w := exp(-pow(c.dist / sm.width, 2.0))
		if c.end: w *= 0.6   # 물줄기 끝 너머로는 힘이 줄어든다(갯가에 밀려 올라가도록 끝은 갯가 안쪽에 둔다)
		v += (c.tan * sm.speed + c.to * sm.pull * sm.speed * minf(1.0, c.dist / sm.width)) * w
		lat += Vector2(-c.tan.y, c.tan.x) * w
		wsum += w
	v += f._amb * maxf(0.0, 1.0 - wsum)
	var nz := float(f.get("noise", 0.15))
	if lat.length() > 1e-3: v += lat.normalized() * nz * sin(tt * 0.9 + phase) * minf(1.0, wsum)
	else: v += Vector2(cos(phase), sin(phase)) * nz * 0.5
	return v

# 노드 없이 끝까지 흘려 본다: { shore: id|"", t, path:[Vector2…] } — 물줄기 맞추기·시험용
static func simulate(f: Dictionary, p0: Vector2, phase: float, is_sea: Callable = Callable()) -> Dictionary:
	var p := p0; var tt := 0.0; var path := [p0]
	var max_t := float(f.get("max_time", 240.0))
	while tt < max_t:
		p += velocity(f, p, tt, phase) * STEP
		tt += STEP
		if int(tt / STEP) % 10 == 0: path.append(p)
		for sh in f._shores:
			if p.distance_to(sh.c) <= sh.r: return { shore = sh.id, t = tt, path = path, p = p }
		if is_sea.is_valid() and not is_sea.call(p): return { shore = "", t = tt, path = path, p = p, aground = true }
	return { shore = "", t = tt, path = path, p = p }

# ---------------------------------------------------------------------------
# 던지기·지켜보기
# ---------------------------------------------------------------------------
func _start(st: Dictionary) -> void:
	prepare_field(d, field)
	var w = d.world
	sea_y = float(field.get("sea_y", w.sea_y if not is_nan(float(w.sea_y)) else 0.0))
	watch = bool(st.get("watch", true))
	time_scale = float(st.get("time_scale", 3.0)) * (4.0 if d.ui.auto else 1.0)
	hours = float(st.get("hours", 0.0))
	_h0 = d.main.hour
	_make_mats()
	var c: Vector2 = d.anchor(st.get("from", "player"))
	var n := int(st.get("n", 3))
	var spread := float(st.get("spread", 1.5))
	var rng := RandomNumberGenerator.new(); rng.seed = int(st.get("seed", 4004))
	var tf = st.get("throw_from", "player")
	var hand: Vector3 = d.main.player_pos + Vector3(0, 1.3, 0)
	if tf != "player":
		var h2: Vector2 = d.anchor(tf); hand = Vector3(h2.x, d.world.height_at(h2.x, h2.y) + 1.3, h2.y)
	# 던지는 쪽(손 → 물) 방향에 수직으로 벌려 떨어뜨린다(표식마다 조금씩 다른 물줄기를 탄다)
	var dirv := (c - Vector2(hand.x, hand.z))
	var side := Vector2(-dirv.y, dirv.x).normalized() if dirv.length() > 0.1 else Vector2.RIGHT
	for i in n:
		var k := (float(i) / maxf(1.0, n - 1)) * 2.0 - 1.0 if n > 1 else 0.0
		var to := c + side * k * spread + Vector2(rng.randf_range(-0.4, 0.4), rng.randf_range(-0.4, 0.4))
		var node := _marker_node(i)
		d.main.scene_vp.add_child(node)
		node.position = hand
		markers.append({ node = node, p = to, phase = rng.randf() * TAU, state = "air", shore = "", t = 0.0,
			air_t = -0.18 * i, from = hand, to = to, foam = null })
	if watch:
		d.cutscene(true)
		if st.get("view") is Dictionary:
			var cm: Dictionary = st.view
			d.main.rig.override = { distance = float(cm.get("distance", 34.0)), pitch = float(cm.get("pitch", 40.0)) }
	d.anim_actor("player", "throw")
	d.runner.log_line("drift", ["throw", field_id, n])

func _process(dt: float) -> void:
	if _done: return
	var sdt := dt * time_scale
	var active := 0
	var cen := Vector2.ZERO
	for m in markers:
		match m.state:
			"air":
				m.air_t += dt
				if m.air_t < 0.0: m.node.position = m.from; active += 1; continue
				var u := clampf(m.air_t / 0.7, 0.0, 1.0)
				var q: Vector3 = m.from.lerp(Vector3(m.to.x, sea_y, m.to.y), u)
				q.y += sin(u * PI) * 2.2 * (1.0 - u * 0.3)
				if u >= 1.0: q.y = sea_y
				m.node.position = q
				m.node.rotation.y += dt * 9.0
				if u >= 1.0:
					m.state = "float"; m.p = m.to
					m.foam = _splash(Vector3(m.to.x, sea_y + 0.02, m.to.y))
				active += 1; cen += Vector2(q.x, q.z)
			"float":
				var steps := maxi(1, ceili(sdt / STEP))
				var h := sdt / steps
				for _k in steps:
					m.p += velocity(field, m.p, t + m.phase, m.phase) * h
					m.t += h
				_check_shore(m)
				var bob := sin((t + m.phase) * 2.6) * 0.05
				m.node.position = Vector3(m.p.x, sea_y + 0.03 + bob, m.p.y)
				var v := velocity(field, m.p, t, m.phase)
				if v.length() > 0.02: m.node.rotation.y = lerp_angle(m.node.rotation.y, atan2(v.x, v.y), minf(1.0, dt * 2.0))
				m.node.rotation.z = sin((t + m.phase) * 1.9) * 0.12
				if m.state == "float":
					active += 1; cen += m.p
					if m.t > float(field.get("max_time", 240.0)): _lose(m)
			"landed":
				# 갯가에 밀려 올라간다(닿은 자리 → rest)
				var tgt: Vector2 = m.rest
				m.p = m.p.lerp(tgt, minf(1.0, dt * 1.5))
				m.node.position = Vector3(m.p.x, maxf(sea_y + 0.03, d.world.height_at(m.p.x, m.p.y) + 0.05), m.p.y)
	t += sdt
	if hours > 0.0 and watch:
		var prog := 0.0
		for m in markers: prog = maxf(prog, minf(1.0, m.t / float(field.get("max_time", 240.0)) * 2.5))
		d.set_hour(_h0 + hours * prog)
	if watch and active > 0:
		cen /= active
		var f = d.main.rig.focus
		var cur := Vector2(f.x, f.z) if f is Dictionary else Vector2(d.main.player_pos.x, d.main.player_pos.z)
		var nx := cur.lerp(cen, minf(1.0, dt * 1.6))
		d.main.rig.focus = { x = nx.x, z = nx.y }
	if active == 0: _finish()

func _check_shore(m: Dictionary) -> void:
	for sh in field._shores:
		if m.p.distance_to(sh.c) <= sh.r:
			m.state = "landed"; m.shore = sh.id; m.rest = sh.rest + Vector2(sin(m.phase), cos(m.phase)) * 0.6
			var k := "drift_" + String(sh.id)
			d.S.flags[k] = int(d.S.flags.get(k, 0)) + 1
			d.runner.log_line("drift", ["landed", field_id, sh.id, snappedf(m.t, 0.1)])
			d.mark_dirty()
			return
	# 갯가 아닌 뭍에 걸림(물 밖) — 가장 가까운 갯가가 가까우면 그쪽, 아니면 잃음
	var g: float = d.world.ground_at(m.p.x, m.p.y) if d.world.has_method("ground_at") else -INF
	if g > sea_y + 0.15:
		_lose(m)

func _lose(m: Dictionary) -> void:
	m.state = "lost"; m.shore = ""
	d.runner.log_line("drift", ["lost", field_id, snappedf(m.t, 0.1)])
	var tw := create_tween()
	tw.tween_property(m.node, "scale", Vector3(0.01, 0.01, 0.01), 0.8)

func _finish() -> void:
	_done = true
	var res := []
	for m in markers: res.append(m.shore)
	d.S.flags["drift_last_" + field_id] = res
	d.runner.log_line("drift", ["done", field_id, res])
	if watch:
		await get_tree().create_timer(0.8 if not d.ui.auto else 0.05, true, false, true).timeout
		d.main.rig.override = null
		d.main.rig.focus = null
		d.cutscene(false)
	for m in markers:
		if is_instance_valid(m.node): m.node.queue_free()
		if m.foam != null and is_instance_valid(m.foam): m.foam.queue_free()
	d.mark_dirty()
	finished.emit(res)
	queue_free()

# ---------------------------------------------------------------------------
# 그림(작은 나무 찌 + 붉은 천 — 새 모델 없이 기본 도형)
# ---------------------------------------------------------------------------
func _make_mats() -> void:
	_mat_wood = StandardMaterial3D.new(); _mat_wood.albedo_color = Color("#8a6a44"); _mat_wood.roughness = 1.0
	_mat_cloth = StandardMaterial3D.new(); _mat_cloth.albedo_color = Color("#b8322a"); _mat_cloth.roughness = 1.0
	_mat_cloth.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat_foam = StandardMaterial3D.new(); _mat_foam.albedo_color = Color(1, 1, 1, 0.55); _mat_foam.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_foam.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

func _marker_node(i: int) -> Node3D:
	var root := Node3D.new(); root.name = "표식_%d" % i
	var log_m := MeshInstance3D.new()
	var cy := CylinderMesh.new(); cy.top_radius = 0.1; cy.bottom_radius = 0.1; cy.height = 0.7; cy.radial_segments = 8
	log_m.mesh = cy; log_m.material_override = _mat_wood; log_m.rotation = Vector3(0, 0, PI / 2); log_m.position = Vector3(0, 0.05, 0)
	root.add_child(log_m)
	var stick := MeshInstance3D.new()
	var sc := CylinderMesh.new(); sc.top_radius = 0.015; sc.bottom_radius = 0.02; sc.height = 0.55; sc.radial_segments = 4
	stick.mesh = sc; stick.material_override = _mat_wood; stick.position = Vector3(0, 0.32, 0)
	root.add_child(stick)
	var flag := MeshInstance3D.new()
	var q := QuadMesh.new(); q.size = Vector2(0.32, 0.2)
	flag.mesh = q; flag.material_override = _mat_cloth; flag.position = Vector3(0.17, 0.5, 0)
	root.add_child(flag)
	# 글자 한 자(一·二·三…)는 찍지 않는다 — 천 색만 같고 개수로 센다
	return root

func _splash(at: Vector3) -> Node3D:
	var m := MeshInstance3D.new()
	var tm := TorusMesh.new(); tm.inner_radius = 0.25; tm.outer_radius = 0.38; tm.rings = 12; tm.ring_segments = 3
	m.mesh = tm; m.material_override = _mat_foam
	d.main.scene_vp.add_child(m)
	m.position = at
	var tw := m.create_tween()
	tw.tween_property(m, "scale", Vector3(4.0, 1.0, 4.0), 1.2)
	tw.parallel().tween_property(m, "transparency", 1.0, 1.2)
	return m
