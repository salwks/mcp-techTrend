# 먼 숲 층(trees-khs) — 흩뿌리기 임포스터(근경 타일, khs_far까지) 너머의 산이 숲으로 읽히게, 불러온 모든 타일(근경·중경)의 숲(토지이용 0)과
# 덜 가파른 바위틈(7)에 8m 격자로 임포스터 나무를 심는다(타일마다 MultiMesh 하나, 충돌 없음). 거리 띠로 khs_far 너머에서만 보인다.
#   자리·층·키는 자리 해시(흩뿌리기와 무관) — 수종은 scatter.forest_mix(해발)를 따른다. 짓기는 작업 스레드, 노드는 메인 스레드.
#   헤드리스(시험)에서는 짓지 않는다(화면이 없다).
extends Node3D

const Khs := preload("res://kit/nature/khs_trees.gd")
const Jobs := preload("res://scripts/region/jobs.gd")
const SCATTER := "res://kit/nature/scatter.gd"
const STEP := 8.0
const TILE := 256

var world: Node = null
var _tiles := {}     # Vector2i → { job, hold, node }
var _sc: Script = null
var enabled := DisplayServer.get_name() != "headless" and not OS.get_cmdline_user_args().has("--nofarforest")

func _ready() -> void:
	_sc = load(SCATTER)

func request(t: Vector2i) -> void:
	if not enabled or _tiles.has(t) or Khs.imp_far_mesh == null: return
	_tiles[t] = { job = -1, hold = {}, node = null, queued = true }

# 짓기 시작은 불러오기가 끝난 뒤, 동시에 2개까지(배치 로더가 높이·토지이용 배열을 고치거나 갈아 끼우는 동안 읽지 않게 — reset_edits도 wait_all)
func _start() -> void:
	if world == null or bool(world.get("loading")): return
	var running := 0
	for t in _tiles:
		if _tiles[t].job >= 0: running += 1
	for t in _tiles:
		if running >= 2: return
		var st: Dictionary = _tiles[t]
		if not st.get("queued", false): continue
		st.queued = false
		st.job = Jobs.add(_build.bind(t, Callable(world, "height_fast"), Callable(world, "landuse_at"), _sc, st.hold), "far_forest")
		running += 1

func wait_all() -> void:
	for t in _tiles:
		if _tiles[t].job >= 0:
			Jobs.wait(_tiles[t].job)

func drop(t: Vector2i) -> void:
	var st = _tiles.get(t)
	if st == null: return
	if st.node != null: st.node.queue_free()
	if st.job >= 0: Jobs.wait(st.job)
	_tiles.erase(t)

static func _build(t: Vector2i, ha: Callable, la: Callable, sc: Script, hold: Dictionary) -> void:
	var buf := PackedFloat32Array()
	var n := int(TILE / STEP)
	for j in n:
		for i in n:
			var cx := t.x * TILE + (i + 0.5) * STEP; var cz := t.y * TILE + (j + 0.5) * STEP
			var px := cx + (Khs.h01(cx, cz, 21.0) - 0.5) * STEP * 0.9
			var pz := cz + (Khs.h01(cx, cz, 22.0) - 0.5) * STEP * 0.9
			var l := int(la.call(px, pz))
			if l != 0 and l != 7: continue
			if l == 7 and Khs.h01(px, pz, 23.0) > 0.45: continue
			var y: float = ha.call(px, pz)
			var alt: float = sc.alt_of(y)
			var mix: Array = sc.forest_mix(alt)
			var tot := 0.0
			for m in mix: tot += float(m[1])
			var a := Khs.h01(px, pz, 24.0) * tot
			var kind: String = mix[mix.size() - 1][0]
			for m in mix:
				a -= float(m[1])
				if a <= 0.0:
					kind = m[0]
					break
			var u := Khs.h01(px, pz, 25.0)
			var layer := Khs.L_A
			var hgt := 12.0
			match kind:
				"pine":
					layer = [Khs.L_A, Khs.L_C, Khs.L_C, Khs.L_E][int(u * 3.99)]
					hgt = lerpf(10.0, 17.0, Khs.h01(px, pz, 26.0))
				"sangsuri":
					layer = Khs.L_SANG_A if u < 0.5 else Khs.L_SANG_B
					hgt = lerpf(9.0, 13.0, Khs.h01(px, pz, 26.0))
				"singal":
					layer = Khs.L_SINGAL
					hgt = lerpf(7.0, 10.5, Khs.h01(px, pz, 26.0))
				_:
					layer = Khs.L_E
					hgt = lerpf(5.0, 8.0, Khs.h01(px, pz, 26.0))
			var rs := hgt / Khs.height(layer)
			var ry := Khs.h01(px, pz, 27.0) * TAU
			var c := cos(ry) * rs; var s := sin(ry) * rs
			buf.append_array(PackedFloat32Array([c, 0.0, s, px, 0.0, rs, 0.0, y - 0.3, -s, 0.0, c, pz, float(layer), Khs.h01(px, pz, 3.0), 0.0, 0.0]))
	hold.buf = buf

func _process(_dt: float) -> void:
	_start()
	for t in _tiles:
		var st: Dictionary = _tiles[t]
		if st.job < 0 or not Jobs.done(st.job): continue
		Jobs.wait(st.job)
		st.job = -1
		var buf: PackedFloat32Array = st.hold.get("buf", PackedFloat32Array())
		if buf.is_empty(): continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = Khs.imp_far_mesh
		mm.instance_count = buf.size() / 16
		mm.buffer = buf
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "far_forest_%d_%d" % [t.x, t.y]
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)
		st.node = mmi

func _exit_tree() -> void:
	for t in _tiles:
		if _tiles[t].job >= 0: Jobs.wait(_tiles[t].job)

# 띠: khs_far 언저리에서 흩뿌리기 임포스터와 점무늬로 엇갈려 이어 받는다
static func set_far(khs_far: float, far_end: float) -> void:
	if Khs.imp_far_mat == null: return
	Khs.imp_far_mat.set_shader_parameter("lod_band", Vector4(khs_far * 0.8, khs_far * 0.95, 1e6, 1e6))
	Khs.imp_far_mat.set_shader_parameter("imp_fade", Vector2(far_end * 0.85, far_end))
