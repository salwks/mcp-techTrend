# 탁본 — 닳은 새김·표식을 먹으로 떠 조사 카드로 본다(SKILL_RUBBING, 경주 「세 번째 등불」 보상). 어느 공간에서나(권역·노정).
#   대상: story/rubbings_data.gd(손으로 둔 자리 + 배치 키트 — 장승·돌장승·비각·성황당). SKILL_RUBBING이 참일 때만 선다.
#   사건의 조사 대상이 더 가까우면 그쪽이 먼저다(story_director._target). 안내는 "탁본을 뜬다 · <이름>" — E.
#   다른 사건이 데이터로 탁본 결과를 바꾸고 싶으면 사건 데이터에 "rubbings": [{ id, at, radius, label, title, text, when }]를 넣는다
#   (같은 id면 사건 것이 이긴다, when은 이야기 조건식).
# story_director.update가 매 프레임 부른다(사건 유무와 상관없이). 조작을 막지 않는다 — 카드가 뜨는 동안만(ui.modal).
extends Node

const Data := preload("res://story/rubbings_data.gd")
const Progress := preload("res://scripts/region/progress.gd")

var d
var items: Array = []
var _built := false
var _target = null
var _t := 0.0
var _busy := false

func setup(director) -> void:
	d = director
	name = "rubbing"

func enabled() -> bool:
	if d.S != null and bool(d.S.vars.get("SKILL_RUBBING", false)): return true
	return bool(Progress.get_var("SKILL_RUBBING", false))

func _build() -> void:
	_built = true
	var placed := []
	var loader = d.main.get("placement")
	if loader != null and loader.has_method("files"):
		for f in loader.files():
			var j = JSON.parse_string(FileAccess.get_file_as_string(f))
			if j is Dictionary: placed.append_array(j.get("items", []))
	items = Data.for_space(d.space_id, placed)
	for r in d.data.get("rubbings", []):
		var rr: Dictionary = r.duplicate()
		rr.p = d.anchor(r.at)
		items = items.filter(func(x): return String(x.id) != String(r.id))
		items.append(rr)
	printerr("RUBBING targets=%d space=%s" % [items.size(), d.space_id])

func update(dt: float) -> void:
	_t -= dt
	if _t > 0.0:
		# 사건 쪽이 매 프레임 안내를 지우므로 대상이 있으면 매 프레임 다시 쓴다
		if _target != null and not d.ui.modal and d.get("_target") == null: d.ui.prompt("탁본을 뜬다 · %s" % String(_target.label))
		return
	_t = 0.2
	if not enabled() or _busy:
		_drop(); return
	if not _built: _build()
	if items.is_empty(): return
	if d.ui.modal or (d.runner != null and d.runner.busy) or (d.combat_view != null and d.combat_view.active) or d.get("_target") != null:
		_drop(); return
	var pp := Vector2(d.main.player_pos.x, d.main.player_pos.z)
	var best = null; var bd := INF
	for r in items:
		var dist: float = pp.distance_to(r.p)
		if dist < float(r.get("radius", 2.6)) and dist < bd:
			if r.has("when") and d.runner != null and not d.runner.cond(r.when): continue
			bd = dist; best = r
	_target = best
	if best != null: d.ui.prompt("탁본을 뜬다 · %s" % String(best.label))
	elif _target == null and _shown: d.ui.prompt("")
	_shown = best != null

var _shown := false
func _drop() -> void:
	if _target != null or _shown:
		_target = null
		if _shown and not d.ui.modal: d.ui.prompt("")
		_shown = false

func _unhandled_input(ev: InputEvent) -> void:
	if _target == null or _busy or not (ev is InputEventKey and ev.pressed and not ev.echo): return
	if not ev.is_action("interact") or d.ui.modal or d.ui.busy_input(): return
	if d.get("_target") != null or (d.runner != null and d.runner.busy): return
	get_viewport().set_input_as_handled()
	use(_target)

# 탁본 뜨기: 쪼그려 먹을 두드리고 → 카드. 처음 뜬 것은 progress.rubbings에 남는다(기록용)
func use(r: Dictionary) -> void:
	_busy = true
	d.ui.prompt("")
	d.main.player.play("crouch", true)
	if d.runner != null: d.runner.log_line("rubbing", r.id)
	else: printerr("STORY rubbing %s" % r.id)
	await d.wait(0.7)
	await d.ui.examine(String(r.get("title", "탁본")), r.get("text", []), "clue")
	d.main.player.play("idle", true)
	var s = Progress.data().get("rubbings")
	if not (s is Dictionary): s = {}; Progress.data()["rubbings"] = s
	if not s.has(String(r.id)):
		s[String(r.id)] = Time.get_datetime_string_from_system()
		if d.test == null: Progress.save()
	_busy = false
	_t = 0.0
