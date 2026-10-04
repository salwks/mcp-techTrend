# 잔영·소리·경계·호신물 체계(재사용) — 강릉 「고개에 남은 종소리」에서 처음 쓰고, 경주(세 번째 등불)·제주(감응 매듭)·
# 최종장(강복 잔영)이 같은 데이터 꼴로 쓴다. 이야기 총괄(story_director)이 사건마다 하나 만들어 update(dt)를 부른다.
#
# 시나리오 원칙(§1.4·§6.5): 플레이어는 마법을 쓰지 않는다. 호신물은 감지(sense)·접근·보호(protect)·의식 조건만 —
#   공격·방어 수치는 절대 바꾸지 않는다(전투 코드는 이 파일을 모른다). 잔영은 싸움 상대가 아니다.
#
# 사건 데이터(story/<사건>/<사건>_data.gd)에 넣는 것:
#   "spirits": [ { id, kind(구운 프레임 종류, 예 spirit_m), name, at(자리), facing,
#                  when(조건식), night(true면 밤에만), sense(true면 감지 호신물을 지녀야),
#                  zone(또렷함을 가르는 경계 id — 플레이어가 안쪽이면 alpha_in, 밖이면 alpha_out), alpha_in, alpha_out,
#                  motion("float" 제자리 떠 있음 | "drift" 느린 걸음으로 path를 돈다), path:[자리…], speed, loop,
#                  flicker:[보임 최소, 최대, 안 보임 최소, 최대](초 — 간헐적으로), range(이 거리 안에서만), watch(이 거리 안이면 고개를 돌려 본다),
#                  lift(땅에서 뜬 높이) } ]
#   "sounds":  [ { id, from(자리 또는 잔영 id), when, night, sense, every:[최소, 최대](초), range(들리는 거리),
#                  caption(먼 소리), near(가까운 소리, near_r 안), near_r, dir(true면 '왼쪽 앞에서' 같은 방향), fx("ring"|"shake"|""),
#                  audio(소리 파일 이름 — res://assets/audio/<이름>.ogg|wav가 있으면 3D로 튼다: 지금은 없음) } ]
#   "zones":   { id: { at, radius, when, enter:[단계…], exit:[단계…] } }   ← 들어설 때·나설 때(조건이 맞을 때마다) 단계 실행
#   "dread":   { zone, when, rate(초당 차오름), decay, on_full:[단계…] }    ← 공포·착란. 지닌 호신물의 protect만큼 덜 찬다
#   "talismans": { ITM_ID: { name, sense, protect, text } }                   ← 아래 TALISMANS에 없는 것만 더하면 된다
# 단계 명령(story_runner가 넘긴다):
#   { "spirit": id, "do": "appear|vanish|show|hide|release|anim|place|move|face", name, at, to, speed }
#   { "sound": id }  { "talisman": "give|equip|unequip|slots", "id": …, "n": … }  { "dread": 0~1 }
# 조건식(story_runner): tal('ITM_RIT_001')·tal('') 지녔나 · zone('id') 안인가 · night() · spv('id') 그 잔영이 지금 보이나
# 공통 변수(§7 + 확장, 사건을 넘어 남는다): ITEM_TALISMAN_SLOT(칸 수: 0 → 1, 뒤에 2) · TALISMANS_OWNED · TALISMAN_EQUIPPED
# 소리: 아직 음원이 없어 자막(방향 포함)과 화면 효과(먹 고리·흔들림)로 낸다. audio_hook을 바꾸거나 파일을 넣으면 소리가 난다.
extends Node

const SpiritChar := preload("res://scripts/story/spirit_char.gd")
const Progress := preload("res://scripts/region/progress.gd")

# 호신물 정의(ITEM_MASTER §ITM_RIT) — 감지·보호만. 공격 버프 금지.
const TALISMANS := {
	"ITM_RIT_001": { "name": "호신부", "sense": true, "protect": 0.7, "text": "두려움과 어지럼을 누그러뜨린다. 밤길에 남은 것을 보게 한다." },
	"ITM_RIT_003": { "name": "다라니", "sense": false, "protect": 0.5, "text": "정해진 자리에 오래 머물 수 있게 한다." },
	"ITM_RIT_004": { "name": "감응 매듭", "sense": true, "protect": 0.0, "text": "실제로 남은 흔적과 사람이 꾸민 것을 가를 실마리를 준다. 정답을 알려 주지는 않는다." },
}
const NIGHT_FROM := 19.0
const NIGHT_TO := 5.0
const FADE_IN := 0.9
const FADE_OUT := 0.7

static var audio_hook: Callable = Callable()   # (이름, Vector3 자리) — 음원 체계가 생기면 여기로

var d                 # story_director
var spirits := {}     # id → 기록
var sounds := []
var zones := {}
var dread_spec := {}
var defs := {}
var dread := 0.0
var _dread_fired := false
var _cond_t := 0.0
var _t := 0.0
var _fx: ColorRect
var _fx_mat: ShaderMaterial
var _ring_t := 9.0
var _slot_box: PanelContainer
var _slot_label: Label
var _slot_shown := ""

func setup(director) -> void:
	d = director
	name = "spirits"
	defs = TALISMANS.duplicate(true)
	defs.merge(d.data.get("talismans", {}), true)
	zones = d.data.get("zones", {}).duplicate(true)
	for zid in zones: zones[zid]["_in"] = false
	for s in d.data.get("sounds", []):
		var r: Dictionary = s.duplicate(true)
		r["_t"] = randf_range(2.0, 5.0)
		sounds.append(r)
	dread_spec = d.data.get("dread", {})
	for sp in d.data.get("spirits", []): _make(sp)
	_build_ui()
	if not InputMap.has_action("talisman"):
		InputMap.add_action("talisman")
		var ev := InputEventKey.new(); ev.physical_keycode = KEY_Q
		InputMap.action_add_event("talisman", ev)

# ---------------------------------------------------------------------------
# 조건식이 부르는 것
# ---------------------------------------------------------------------------
func is_night() -> bool:
	var h: float = d.main.hour
	return h >= NIGHT_FROM or h < NIGHT_TO

func in_zone(id: String) -> bool:
	var z = zones.get(id)
	if z == null: return false
	var pp := Vector2(d.main.player_pos.x, d.main.player_pos.z)
	return pp.distance_to(d.anchor(z.at)) <= float(z.get("radius", 8.0))

func spirit_visible(id: String) -> bool:
	var r = spirits.get(id)
	return r != null and r.ch.visible and r.op > 0.2

# ---------------------------------------------------------------------------
# 호신물(§6.5) — 칸은 ITEM_TALISMAN_SLOT, 가진 것·지닌 것은 공통 변수
# ---------------------------------------------------------------------------
func _vget(k: String, dflt):
	var v = d.S.vars.get(k)
	return v if v != null else dflt

func _vset(k: String, v) -> void:
	d.S.vars[k] = v
	Progress.set_var(k, v)
	d.mark_dirty()

func slots() -> int: return int(_vget("ITEM_TALISMAN_SLOT", 0))
func owned() -> Array: return (_vget("TALISMANS_OWNED", []) as Array).duplicate()
func equipped_list() -> Array: return (_vget("TALISMAN_EQUIPPED", []) as Array).duplicate()

func equipped(id := "") -> bool:
	var e := equipped_list()
	return not e.is_empty() if id == "" else e.has(id)

func senses() -> bool:
	for id in equipped_list():
		if bool(defs.get(id, {}).get("sense", false)): return true
	return false

func protect() -> float:
	var p := 0.0
	for id in equipped_list(): p = maxf(p, float(defs.get(id, {}).get("protect", 0.0)))
	return p

func tal_name(id: String) -> String: return String(defs.get(id, {}).get("name", id))

func set_slots(n: int) -> void:
	_vset("ITEM_TALISMAN_SLOT", clampi(n, 0, 2))
	d.runner.log_line("talisman_slots", n)

func give_talisman(id: String) -> void:
	var o := owned()
	if not o.has(id): o.append(id)
	_vset("TALISMANS_OWNED", o)
	d.runner.log_line("talisman_give", id)

func equip(id: String, quiet := false) -> bool:
	if slots() <= 0 or not owned().has(id): return false
	var e := equipped_list()
	if e.has(id): return true
	if e.size() >= slots(): e.pop_front()
	e.append(id)
	_vset("TALISMAN_EQUIPPED", e)
	d.runner.log_line("talisman_equip", id)
	if not quiet: d.ui.toast("호신물 — %s을(를) 지녔다" % tal_name(id), "item")
	return true

func unequip(id := "") -> void:
	var e := equipped_list()
	if id == "": e.clear()
	else: e.erase(id)
	_vset("TALISMAN_EQUIPPED", e)
	d.runner.log_line("talisman_unequip", id)

# Q: 가진 호신물을 차례로 지니고, 끝에서 한 번 더 누르면 푼다
func cycle() -> void:
	var o := owned()
	if slots() <= 0 or o.is_empty(): return
	var e := equipped_list()
	if e.is_empty():
		equip(o[0]); return
	var i := o.find(e[e.size() - 1])
	if i + 1 < o.size(): equip(o[i + 1])
	else:
		unequip()
		d.ui.toast("호신물을 풀어 품에 넣었다", "item")

func _unhandled_input(ev: InputEvent) -> void:
	if not (ev is InputEventKey and ev.pressed and not ev.echo): return
	if ev.is_action("talisman") and d.S != null and not d.ui.modal and not d.runner.busy and not (d.combat_view != null and d.combat_view.active):
		cycle()
		get_viewport().set_input_as_handled()

# ---------------------------------------------------------------------------
# 잔영
# ---------------------------------------------------------------------------
func _make(spec: Dictionary) -> void:
	var kind: String = d._ensure_bank(String(spec.get("kind", "spirit_m")))
	var ch = SpiritChar.new(kind)
	d.main.scene_vp.add_child(ch)
	ch.visible = false
	var p: Vector2 = d.anchor(spec.get("at", "player"))
	var r := { id = String(spec.id), spec = spec, ch = ch, pos = Vector3(p.x, 0.0, p.y), facing = String(spec.get("facing", "down")),
		want = false, forced = null, op = 0.0, dis = 1.0, cl = 1.0, fl_on = true, fl_t = 0.0, path = [], seg = 0,
		anim = "float", turned = false, ext_path = [] }
	ch.play("float", true)
	spirits[r.id] = r
	_reset_path(r)

func _reset_path(r: Dictionary) -> void:
	r.path = []
	for q in r.spec.get("path", []): r.path.append(d.anchor(q))
	r.seg = 0

func _want(r: Dictionary) -> bool:
	if r.forced != null: return bool(r.forced)
	var s: Dictionary = r.spec
	if not d.runner.cond(s.get("when", true)): return false
	if bool(s.get("night", true)) and not is_night(): return false
	if bool(s.get("sense", true)) and not senses(): return false
	var pp := Vector2(d.main.player_pos.x, d.main.player_pos.z)
	if pp.distance_to(Vector2(r.pos.x, r.pos.z)) > float(s.get("range", 45.0)): return false
	return true

func _update_spirit(r: Dictionary, dt: float) -> void:
	var s: Dictionary = r.spec
	var ch = r.ch
	# 간헐적으로(flicker 주기): 보이는 구간·안 보이는 구간을 번갈아
	var fl: Array = s.get("flicker", [])
	if fl.size() >= 4 and r.forced == null:
		r.fl_t -= dt
		if r.fl_t <= 0.0:
			r.fl_on = not r.fl_on
			r.fl_t = randf_range(float(fl[0]), float(fl[1])) if r.fl_on else randf_range(float(fl[2]), float(fl[3]))
	else: r.fl_on = true
	var on: bool = r.want and r.fl_on
	# 또렷함: 경계 안이면 alpha_in, 밖이면 alpha_out(§S2006 경계석 밖 희미 / 안 또렷)
	var zid := String(s.get("zone", ""))
	var inside := zid == "" or in_zone(zid)
	var target_op: float = float(s.get("alpha_in", 0.85)) if inside else float(s.get("alpha_out", 0.28))
	var target_cl := 1.0 if inside else 0.25
	if on:
		r.dis = maxf(0.0, r.dis - dt / FADE_IN)
		r.op = move_toward(r.op, target_op, dt * 1.2)
	else:
		r.dis = minf(1.0, r.dis + dt / FADE_OUT)
		if r.dis >= 1.0: r.op = 0.0
	r.cl = move_toward(r.cl, target_cl, dt * 1.5)
	var vis: bool = r.dis < 1.0 and r.op > 0.01
	if ch.visible != vis: ch.visible = vis
	# 움직임: drift는 느린 걸음으로 경로를 돈다(보일 때만 걷는다 — 안 보일 땐 그 자리에 머문다)
	var mv := String(s.get("motion", "float"))
	var moving := false
	var path: Array = r.ext_path if not r.ext_path.is_empty() else r.path
	if (mv == "drift" or not r.ext_path.is_empty()) and not path.is_empty() and (vis or not r.ext_path.is_empty()):
		var i: int = clampi(r.seg, 0, path.size() - 1)
		var tgt: Vector2 = path[i]
		var v: Vector2 = tgt - Vector2(r.pos.x, r.pos.z)
		var l := v.length()
		var step := float(r.get("speed_ext", s.get("speed", 0.55))) * dt
		if l <= step:
			r.pos.x = tgt.x; r.pos.z = tgt.y
			if not r.ext_path.is_empty():
				r.ext_path.pop_front()
			else:
				var lp = s.get("loop", true)
				if lp is String and lp == "restart" and i + 1 >= path.size():
					# 끝에 닿으면 사라졌다가 처음 자리에서 다시(앞서 가며 이끄는 형체)
					r.seg = 0
					r.pos.x = path[0].x; r.pos.z = path[0].y
					r.fl_on = false; r.fl_t = randf_range(1.5, 3.0); r.dis = 1.0; r.op = 0.0
				else:
					r.seg = (i + 1) % path.size() if (lp is bool and lp) else mini(i + 1, path.size() - 1)
		else:
			var q := Vector2(r.pos.x, r.pos.z) + v / l * step
			r.pos.x = q.x; r.pos.z = q.y
			moving = true
			r.facing = "right" if absf(v.x) > absf(v.y) * 1.05 and v.x > 0 else ("left" if absf(v.x) > absf(v.y) * 1.05 else ("down" if v.y > 0 else "up"))
	# 고개 돌림: 가까이 오면 한 번 돌아본다
	var pp := Vector2(d.main.player_pos.x, d.main.player_pos.z)
	var dist := pp.distance_to(Vector2(r.pos.x, r.pos.z))
	var watch := float(s.get("watch", 0.0))
	var want_anim := "drift" if moving else "float"
	if r.has("anim_force"): want_anim = String(r.anim_force)
	elif watch > 0.0 and dist < watch and vis and not moving:
		if not r.turned:
			r.turned = true
			var v2 := pp - Vector2(r.pos.x, r.pos.z)
			r.facing = "right" if absf(v2.x) > absf(v2.y) and v2.x > 0 else ("left" if absf(v2.x) > absf(v2.y) else ("down" if v2.y > 0 else "up"))
		want_anim = "head_turn"
	elif dist > watch + 3.0: r.turned = false
	if want_anim != r.anim:
		r.anim = want_anim
		ch.play(want_anim, true)
	if not vis: return
	var bob := 0.06 * sin(_t * 1.3 + r.pos.x)
	ch.position = Vector3(r.pos.x, d.world.height_at(r.pos.x, r.pos.z) + float(s.get("lift", 0.12)) + bob, r.pos.z)
	ch.facing = r.facing
	# 잔떨림(flicker): 희미할수록 크게 흔들린다
	var jit: float = 1.0 - (0.12 + 0.25 * (1.0 - r.cl)) * (0.5 + 0.5 * sin(_t * 23.0 + r.pos.z)) * (0.5 + 0.5 * sin(_t * 7.3))
	ch.set_look(r.op * jit, r.cl, r.dis)
	ch.update_char(dt, d.main.cam)

# ---------------------------------------------------------------------------
# 소리(자막 + 화면) — 음원이 생기면 audio_hook
# ---------------------------------------------------------------------------
func _src_pos(s: Dictionary) -> Vector2:
	var f = s.get("from", "player")
	if f is String and spirits.has(f): return Vector2(spirits[f].pos.x, spirits[f].pos.z)
	return d.anchor(f)

func _dir_word(src: Vector2) -> String:
	var pp := Vector2(d.main.player_pos.x, d.main.player_pos.z)
	var v := src - pp
	if v.length() < 4.0: return "바로 곁에서"
	var fwd3: Vector3 = -d.main.cam.global_transform.basis.z
	var fwd := Vector2(fwd3.x, fwd3.z).normalized()
	var a := rad_to_deg(fwd.angle_to(v.normalized()))
	var w := "앞쪽"
	if absf(a) > 135.0: w = "뒤쪽"
	elif a > 45.0: w = "오른쪽"
	elif a < -45.0: w = "왼쪽"
	return ("멀리 %s에서" % w) if v.length() > 90.0 else ("%s에서" % w)

func play_sound(s: Dictionary, quiet := false) -> void:
	var src := _src_pos(s)
	var pp := Vector2(d.main.player_pos.x, d.main.player_pos.z)
	var dist := pp.distance_to(src)
	var near := dist < float(s.get("near_r", 12.0))
	var text := String(s.get("near", s.get("caption", ""))) if near else String(s.get("caption", ""))
	if bool(s.get("dir", false)) and not near: text = "%s  (%s)" % [text, _dir_word(src)]
	printerr("SOUND %s d=%.0f %s" % [s.get("id", "?"), dist, text])
	d.runner.log_line("sound", [s.get("id", "?"), int(dist)])
	if not quiet and text != "" and not d.ui.modal: d.ui.caption(text, float(s.get("sec", 2.6)))
	match String(s.get("fx", "ring")):
		"ring": _ring(Vector3(src.x, d.world.height_at(src.x, src.y) + 1.4, src.y))
		"shake": d.shake(0.1, 0.5)
	_audio(String(s.get("audio", "")), Vector3(src.x, d.world.height_at(src.x, src.y), src.y))

func _audio(nm: String, at: Vector3) -> void:
	if nm == "": return
	if audio_hook.is_valid():
		audio_hook.call(nm, at); return
	for ext in ["ogg", "wav"]:
		var path := "res://assets/audio/%s.%s" % [nm, ext]
		if not ResourceLoader.exists(path): continue
		var p := AudioStreamPlayer3D.new()
		p.stream = load(path)
		p.position = at
		p.unit_size = 18.0
		d.main.scene_vp.add_child(p)
		p.finished.connect(p.queue_free)
		p.play()
		return

func _update_sounds(dt: float) -> void:
	if d.runner.busy or d.ui.modal: return
	var pp := Vector2(d.main.player_pos.x, d.main.player_pos.z)
	for s in sounds:
		s._t -= dt
		if s._t > 0.0: continue
		var ev: Array = s.get("every", [8.0, 14.0])
		s._t = randf_range(float(ev[0]), float(ev[1]))
		if not d.runner.cond(s.get("when", true)): continue
		if bool(s.get("night", true)) and not is_night(): continue
		if bool(s.get("sense", false)) and not senses(): continue
		if pp.distance_to(_src_pos(s)) > float(s.get("range", 200.0)): continue
		play_sound(s)

# ---------------------------------------------------------------------------
# 경계(들어섬·나섬)와 공포·착란
# ---------------------------------------------------------------------------
func _update_zones() -> void:
	if d.runner.busy or d.ui.modal: return
	for zid in zones:
		var z: Dictionary = zones[zid]
		var now := in_zone(zid)
		if now == bool(z._in): continue
		z._in = now
		var steps: Array = z.get("enter" if now else "exit", [])
		if steps.is_empty() or not d.runner.cond(z.get("when", true)): continue
		d.runner.log_line("zone", [zid, "enter" if now else "exit"])
		d.runner.run(steps)
		return

func _update_dread(dt: float) -> void:
	var on := false
	if not dread_spec.is_empty() and not d.runner.busy:
		on = d.runner.cond(dread_spec.get("when", true)) and (String(dread_spec.get("zone", "")) == "" or in_zone(String(dread_spec.zone)))
	if on:
		dread = minf(1.0, dread + float(dread_spec.get("rate", 0.06)) * (1.0 - protect()) * dt)
	elif not d.runner.busy:
		dread = maxf(0.0, dread - float(dread_spec.get("decay", 0.25)) * dt)
	if dread >= 1.0 and not _dread_fired:
		_dread_fired = true
		d.runner.log_line("dread_full", 1)
		await d.runner.run(dread_spec.get("on_full", []))
		dread = 0.0
		_dread_fired = false

# ---------------------------------------------------------------------------
# 프레임
# ---------------------------------------------------------------------------
func update(dt: float) -> void:
	_t += dt
	_cond_t -= dt
	if _cond_t <= 0.0:
		_cond_t = 0.25
		for id in spirits: spirits[id].want = _want(spirits[id])
		_update_zones()
	for id in spirits: _update_spirit(spirits[id], dt)
	_update_sounds(dt)
	_update_dread(dt)
	_ring_t += dt
	_fx_mat.set_shader_parameter("dread", dread)
	_fx_mat.set_shader_parameter("ring", clampf(_ring_t / 1.6, 0.0, 1.0))
	_update_slot_ui()

# ---------------------------------------------------------------------------
# 단계 명령(story_runner → 여기)
# ---------------------------------------------------------------------------
func step(st: Dictionary) -> void:
	if st.has("talisman"):
		var id := String(st.get("id", ""))
		match String(st.talisman):
			"give": give_talisman(id)
			"equip": equip(id, bool(st.get("quiet", false)))
			"unequip": unequip(id)
			"slots": set_slots(int(st.get("n", 1)))
		_update_slot_ui()
		return
	if st.has("sound"):
		var sid := String(st.sound)
		for s in sounds:
			if String(s.get("id", "")) == sid: play_sound(s, bool(st.get("quiet", false))); return
		play_sound({ "id": sid, "from": st.get("from", "player"), "caption": st.get("caption", ""), "fx": st.get("fx", "ring"), "audio": st.get("audio", "") })
		return
	if st.has("dread"):
		dread = float(st.dread); return
	var r = spirits.get(String(st.get("spirit", "")))
	if r == null:
		push_warning("잔영: 없는 id " + String(st.get("spirit", ""))); return
	match String(st.get("do", "appear")):
		"appear", "show":
			r.forced = true; r.want = true; r.fl_on = true
			if String(st.do) == "show": r.dis = 0.0; r.op = float(r.spec.get("alpha_in", 0.85))
		"vanish":
			r.forced = false; r.want = false
			await d.wait(FADE_OUT + 0.1)
		"hide":
			r.forced = false; r.want = false; r.dis = 1.0; r.op = 0.0; r.ch.visible = false
		"release":
			r.forced = null; r.erase("anim_force")
		"anim":
			r["anim_force"] = String(st.get("name", "float")); r.anim = ""
		"place":
			var p: Vector2 = d.anchor(st.get("at"))
			r.pos = Vector3(p.x, 0.0, p.y); r.ext_path = []
		"face":
			var to: Vector2 = d.anchor(st.get("to", "player"))
			var v := to - Vector2(r.pos.x, r.pos.z)
			r.facing = "right" if absf(v.x) > absf(v.y) and v.x > 0 else ("left" if absf(v.x) > absf(v.y) else ("down" if v.y > 0 else "up"))
		"move":
			var to = st.get("to", [])
			var pts: Array = to if (to is Array and to.size() > 0 and not (to[0] is float or to[0] is int)) else [to]
			r.ext_path = pts.map(func(q): return d.anchor(q))
			r["speed_ext"] = float(st.get("speed", r.spec.get("speed", 0.55))) * (8.0 if d.ui.auto else 1.0)
			var g := 0
			while not r.ext_path.is_empty() and g < 3000:
				await get_tree().process_frame; g += 1
			r.erase("speed_ext")

# ---------------------------------------------------------------------------
# 화면: 공포·착란 먹 번짐(가장자리) + 소리 고리 / 호신물 칸
# ---------------------------------------------------------------------------
const FX_CODE := """shader_type canvas_item;
uniform float dread = 0.0;
uniform float ring = 1.0;
uniform vec2 ring_at = vec2(0.5);
float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
void fragment() {
	float asp = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 d = UV - 0.5; d.x *= asp;
	float r = length(d) / (0.5 * max(asp, 1.0));
	float n = hash(floor(UV * vec2(160.0, 90.0)) + floor(TIME * 6.0));
	float wob = 0.05 * sin(UV.y * 30.0 + TIME * 2.0) * dread;
	float vig = smoothstep(1.0 - 0.75 * dread, 1.25, r + wob + 0.08 * n * dread) * min(1.0, dread * 1.6);
	vec2 q = UV - ring_at; q.x *= asp;
	float rr = length(q);
	float rad = 0.04 + ring * 0.22;
	float ra = (1.0 - ring) * smoothstep(0.012, 0.0, abs(rr - rad)) * 0.55;
	float ra2 = (1.0 - ring) * smoothstep(0.008, 0.0, abs(rr - rad * 0.62)) * 0.3;
	COLOR = vec4(vec3(0.06, 0.05, 0.045), clamp(vig * 0.9 + ra + ra2, 0.0, 0.92));
}
"""

func _build_ui() -> void:
	var fx_layer := CanvasLayer.new(); fx_layer.layer = 6; fx_layer.name = "spirit_fx"
	add_child(fx_layer)
	_fx = ColorRect.new()
	_fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx_mat = ShaderMaterial.new()
	var sh := Shader.new(); sh.code = FX_CODE
	_fx_mat.shader = sh
	_fx.material = _fx_mat
	fx_layer.add_child(_fx)
	var ui_layer := CanvasLayer.new(); ui_layer.layer = 7; ui_layer.name = "talisman_ui"
	add_child(ui_layer)
	_slot_box = d.ui._paper(0.9, 2, 12)
	_slot_label = d.ui._label(19, d.ui.INK)
	_slot_box.add_child(_slot_label)
	_slot_box.visible = false
	ui_layer.add_child(_slot_box)

func _ring(at: Vector3) -> void:
	var cam: Camera3D = d.main.cam
	var vs: Vector2 = Vector2(d.main.scene_vp.size)
	var uv := Vector2(0.5, 0.5)
	if not cam.is_position_behind(at):
		uv = (cam.unproject_position(at) / vs)
	else:
		var p := cam.unproject_position(at) / vs
		uv = Vector2(1.0 - p.x, 0.9)
	uv = uv.clamp(Vector2(0.06, 0.08), Vector2(0.94, 0.92))
	_fx_mat.set_shader_parameter("ring_at", uv)
	_ring_t = 0.0

func _update_slot_ui() -> void:
	var n := slots()
	var text := ""
	if n > 0:
		var e := equipped_list()
		var cells := []
		for i in n: cells.append("[%s]" % (tal_name(e[i]) if i < e.size() else "　"))
		text = "호신물  %s   Q 지니기·풀기" % " ".join(cells)
	if d.combat_view != null and d.combat_view.active: text = ""   # 싸우는 동안은 전투 HUD(화살·떡)와 겹치지 않게 숨긴다
	if text == _slot_shown: return
	_slot_shown = text
	_slot_box.visible = text != ""
	_slot_label.text = text
	var vs := get_viewport().get_visible_rect().size
	var k := clampf(vs.y / 768.0, 0.8, 2.4)
	_slot_label.add_theme_font_size_override("font_size", int(19 * k))
	_slot_box.reset_size()
	_slot_box.position = Vector2(18 * k, vs.y - _slot_box.get_combined_minimum_size().y - 18 * k)
