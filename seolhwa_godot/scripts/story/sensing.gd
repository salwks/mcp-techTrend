# 감응 매듭(ITM_RIT_004 — 시나리오 §6.5 '감지', ITEM_MASTER "자동 정답 표시 금지")과 흔적의 결(trace authenticity) — 재사용 체계.
#   제주 「굴에 남은 숨」(S7004~)에서 처음 쓰고, 최종장(진짜 강복의 흔적 대 우치가 꾸민 가짜)도 같은 데이터 꼴로 쓴다.
#   매듭은 답을 말하지 않는다. 지니고 있으면(호신물 칸 — spirits.gd) 플레이어 허리께에 붉은 매듭이 매달려 보이고,
#   곁에 '사람이 아닌 것'의 흔적이 있으면 떨고, 섞인 흔적이면 떨다 멎기를 되풀이하고, 사람이 만든 것뿐이면 가만히 늘어진다.
#   무엇이 무엇인지는 플레이어가 매듭을 보고 가린다(기록책에는 본 것만 — 사건이 '관찰'로 적는다).
#
# 흔적의 결 trace: "human"(사람이 만든) | "other"(사람이 아닌 것) | "mixed"(둘이 섞임). 어디에 다는가:
#   - 사건 데이터 "traces": [{ id, at(자리), radius(기본 4.5), trace, when(조건식) }]  ← 세계에 이미 있는 물건(금줄·제물상·벽)
#   - 사건 데이터 objects·props 항목에 "trace"(+ "trace_r")  ← 조사 대상·사건 소품
#   - 세계 데칼·발자국 줄 spec의 "trace"(decals.gd traces_near) ← region_data decals_*.json 또는 사건 props trail의 trace
# 읽기(사건 GDScript·시험): level(지금 떨림 0~1) · kind(가장 센 곁 흔적의 결) · reading_at(p) → { level, kind, id } ·
#   sensing() 매듭을 지녔나 · line(trace) 살펴볼 때 덧붙일 한 줄(매듭의 모양만 — 결론 없음)
extends Node

const KNOT := "ITM_RIT_004"
const W := { human = 0.0, mixed = 0.62, other = 1.0 }
const LINES := {
	"other": "품에서 꺼낸 매듭이 바르르 떤다. 멎지 않는다.",
	"mixed": "매듭이 떨리다 멎고, 다시 떨린다.",
	"human": "매듭은 가만히 늘어져 있다.",
	"": "매듭은 가만히 늘어져 있다.",
}

var d                     # story_director
var level := 0.0          # 매듭 떨림(부드럽게)
var raw := 0.0
var kind := ""
var src_id := ""
var _t := 0.0
var _scan_t := 0.0
var _node: Node3D
var _swing: Node3D
var _told := {}           # 처음 떨기 시작한 흔적마다 한 줄(조작을 막지 않는 자막)
var _boost := 0.0         # 사건 연출(잔영이 지나감 등)이 잠깐 세게 떨게 한다 — boost(세기, 초)
var _boost_t := 0.0

func boost(lv: float, sec: float) -> void:
	_boost = lv; _boost_t = sec

func setup(director) -> void:
	d = director
	name = "sensing"

func sensing() -> bool:
	return d.spirits != null and d.spirits.equipped(KNOT)

func line(trace: String) -> String:
	return String(LINES.get(trace, LINES[""]))

# p 곁 흔적 중 가장 센 것(매듭 떨림 = 결의 무게 × 가까움)
func reading_at(p: Vector2) -> Dictionary:
	var acc := { best = { level = 0.0, kind = "", id = "" }, human = "" }
	for tr in d.data.get("traces", []):
		if not d.runner.cond(tr.get("when", true)): continue
		_consider(acc, String(tr.id), String(tr.trace), d.anchor(tr.at).distance_to(p), float(tr.get("radius", 4.5)))
	for o in d.data.get("objects", []):
		if not o.has("trace") or not d.runner.cond(o.get("when", true)): continue
		_consider(acc, String(o.id), String(o.trace), d.anchor(o.at).distance_to(p), float(o.get("trace_r", 4.0)))
	for id in d.props:
		var rec: Dictionary = d.props[id]
		var sp: Dictionary = rec.spec
		if not sp.has("trace") or not rec.get("want", false) or not sp.has("at"): continue
		_consider(acc, String(id), String(sp.trace), d.anchor(sp.at).distance_to(p), float(sp.get("trace_r", 4.0)))
	var dc = d.world.get("decals")
	if dc != null and dc.has_method("traces_near"):
		for it in dc.traces_near(p, 1.3):   # 발자국 한 칸 — 가까이 서야 한다(곁의 다른 줄과 섞이지 않게)
			_consider(acc, String(it.group) if String(it.group) != "" else String(it.id), String(it.trace), float(it.d), 1.3)
	var best: Dictionary = acc.best
	if float(best.level) < 0.05 and String(acc.human) != "": best = { level = 0.0, kind = "human", id = String(acc.human) }
	return best

func _consider(acc: Dictionary, id: String, tr: String, dd: float, r: float) -> void:
	if dd > r: return
	var k := 1.0 - smoothstep(r * 0.35, r, dd)
	var lv: float = float(W.get(tr, 0.0)) * k
	if tr == "human" and k > 0.3 and String(acc.human) == "": acc.human = id
	if lv > float(acc.best.level): acc.best = { level = lv, kind = tr, id = id }

func update(dt: float) -> void:
	_t += dt
	var on := sensing()
	if not on:
		if _node != null and _node.visible: _node.visible = false
		level = move_toward(level, 0.0, dt * 2.0)
		raw = 0.0; kind = ""; src_id = ""
		return
	_scan_t -= dt
	if _scan_t <= 0.0:
		_scan_t = 0.15
		var r := reading_at(Vector2(d.main.player_pos.x, d.main.player_pos.z))
		raw = float(r.level); kind = String(r.kind); src_id = String(r.id)
		if raw > 0.35 and not _told.has(src_id) and not d.runner.busy and not d.ui.modal:
			_told[src_id] = true
			d.ui.caption("품의 매듭이 떨린다.", 2.0)
			d.runner.log_line("knot", [src_id, kind, snappedf(raw, 0.01)])
	# 섞인 흔적은 떨다 멎다(맥박), 사람 아닌 것은 멎지 않는다
	var want := raw
	if _boost_t > 0.0:
		_boost_t -= dt
		if _boost > want: want = _boost; kind = "other"
	if kind == "mixed": want *= 0.25 + 0.75 * clampf(sin(_t * 4.2) * 1.6, 0.0, 1.0)
	level = move_toward(level, want, dt * 3.5)
	_draw_knot(dt)

# ---------------------------------------------------------------------------
# 매듭 그림(세계 안 — 플레이어 허리께에 매달림): 고리 · 붉은 매듭 · 오색 술. 카메라 쪽으로 서고, 떨림만큼 흔들린다
# ---------------------------------------------------------------------------
func _mat(c: Color, em := 0.25) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c * em
	m.roughness = 0.9
	return m

func _build() -> void:
	_node = Node3D.new(); _node.name = "sensing_knot"
	d.main.scene_vp.add_child(_node)
	_swing = Node3D.new()
	_node.add_child(_swing)
	var cord := MeshInstance3D.new()
	var cm := CylinderMesh.new(); cm.top_radius = 0.012; cm.bottom_radius = 0.012; cm.height = 0.22; cm.radial_segments = 6
	cord.mesh = cm; cord.position = Vector3(0, -0.11, 0); cord.material_override = _mat(Color("#a8443c"))
	_swing.add_child(cord)
	var knot := MeshInstance3D.new()
	var km := SphereMesh.new(); km.radius = 0.07; km.height = 0.11; km.radial_segments = 10; km.rings = 6
	knot.mesh = km; knot.position = Vector3(0, -0.26, 0); knot.material_override = _mat(Color("#b8392f"), 0.35)
	_swing.add_child(knot)
	var loop := MeshInstance3D.new()
	var tm := TorusMesh.new(); tm.inner_radius = 0.035; tm.outer_radius = 0.055; tm.rings = 10; tm.ring_segments = 6
	loop.mesh = tm; loop.position = Vector3(0, -0.20, 0); loop.rotation = Vector3(PI / 2, 0, 0); loop.material_override = _mat(Color("#a8443c"))
	_swing.add_child(loop)
	var cols := [Color("#2f4262"), Color("#a8443c"), Color("#d9b84a"), Color("#efe9da"), Color("#3f6a4a")]
	for i in 5:
		var s := MeshInstance3D.new()
		var sm := CylinderMesh.new(); sm.top_radius = 0.008; sm.bottom_radius = 0.004; sm.height = 0.24; sm.radial_segments = 4
		s.mesh = sm
		s.position = Vector3((i - 2) * 0.016, -0.42, 0)
		s.rotation.z = (i - 2) * 0.08
		s.material_override = _mat(cols[i])
		_swing.add_child(s)
	_node.scale = Vector3.ONE * 1.6   # 인물(1.25배)과 어울리게 조금 크게

func _draw_knot(_dt: float) -> void:
	if _node == null: _build()
	var pl = d.main.player
	var cam: Camera3D = d.main.cam
	var vis: bool = pl.visible and not (d.combat_view != null and d.combat_view.active)
	_node.visible = vis
	if not vis: return
	var right := cam.global_transform.basis.x
	right.y = 0.0
	right = right.normalized() if right.length() > 0.01 else Vector3.RIGHT
	var side := -1.0 if pl.facing == "right" else 1.0
	_node.global_position = d.main.player_pos + Vector3(0, 1.32, 0) + right * (0.42 * side) + Vector3(0, 0.0, 0.05)
	var fwd := -cam.global_transform.basis.z
	_node.rotation = Vector3(0, atan2(-fwd.x, -fwd.z), 0)
	# 흔들림: 걸음의 느린 흔들림 + 떨림(빠르고 잘게)
	var walk: float = 0.12 * sin(_t * 5.0) if pl.anim in ["walk", "run"] else 0.04 * sin(_t * 1.3)
	var trem := level * (0.34 * sin(_t * 37.0) + 0.14 * sin(_t * 23.0 + 1.0))
	_swing.rotation = Vector3(level * 0.1 * sin(_t * 29.0), 0, walk + trem)
	_swing.position = Vector3(level * 0.012 * sin(_t * 41.0), 0, 0)
