# 길가 장면(story/vignettes_data.gd) — 사건 기록 없이 지나가며 보는 복선(v2.2 R0104 등).
#   그 공간에 들면 소품·인물을 세우고, 반경 안에 처음 들면 대사 한 줄(자막)과 변수 더하기를 한 번만(저장 progress.vignettes).
#   story_director.update가 사건이 있든 없든(노정 = 소문만) 부른다.
extends RefCounted

const Data := preload("res://story/vignettes_data.gd")
const Progress := preload("res://scripts/region/progress.gd")

var d
var items: Array = []     # { spec, p, nodes, chars, built }
var _t := 0.0

func _init(director) -> void:
	d = director
	for v in Data.VIGNETTES:
		if String(v.space) != d.space_id: continue
		var ok := true
		for k in v.get("requires", {}):
			var have := str(Progress.get_var(k, ""))
			if have != str(v.requires[k]) and not have.split(",").has(str(v.requires[k])): ok = false
		if not ok: continue
		items.append({ spec = v, p = Vector2(float(v.at[0]), float(v.at[1])), nodes = [], chars = [], built = false })

static func seen(id: String) -> bool:
	var s = Progress.data().get("vignettes")
	return s is Dictionary and s.has(id)

func update(dt: float) -> void:
	if items.is_empty(): return
	var pp := Vector2(d.main.player_pos.x, d.main.player_pos.z)
	for it in items:
		var dist: float = pp.distance_to(it.p)
		if not it.built and dist < 220.0: _build(it)
		for c in it.chars:
			c.visible = dist < 140.0
			if c.visible: c.update_char(dt, d.main.cam)
	_t -= dt
	if _t > 0.0: return
	_t = 0.25
	if d.runner != null and d.runner.busy: return
	for it in items:
		var v: Dictionary = it.spec
		if seen(String(v.id)) or pp.distance_to(it.p) > float(v.get("radius", 12.0)): continue
		var s = Progress.data().get("vignettes")
		if not (s is Dictionary): s = {}; Progress.data()["vignettes"] = s
		s[String(v.id)] = Time.get_datetime_string_from_system()
		for k in v.get("add", {}):
			var nv := int(Progress.get_var(k, 0)) + int(v.add[k])
			Progress.set_var(k, nv)
			if d.S != null: d.S.vars[k] = int(d.S.vars.get(k, 0)) + int(v.add[k])
		if not (d.test != null): Progress.save()
		printerr("VIGNETTE %s %s" % [v.id, JSON.stringify(v.get("add", {}))])
		if v.has("line"): d.ui.caption("%s  “%s”" % [String(v.line[0]), String(v.line[1])], 3.2)

func _build(it: Dictionary) -> void:
	it.built = true
	var w = d.main.world
	for p in it.spec.get("props", []):
		var path := "res://kit/%s.gd" % String(p.kit)
		if not FileAccess.file_exists(path): continue
		var info: Dictionary = load(path).build(p.get("params", {}))
		var n: Node3D = info.node
		var at: Vector2 = it.p + Vector2(float(p.at[0]), float(p.at[1]))
		d.main.scene_vp.add_child(n)
		n.global_transform = Transform3D(Basis(Vector3.UP, float(p.get("ry", 0.0))), Vector3(at.x, w.height_at(at.x, at.y) + float(p.get("dy", 0.0)), at.y))
		it.nodes.append(n)
	for pe in it.spec.get("people", []):
		var kind: String = d._ensure_bank(String(pe.kind))
		var ch := SpriteChar.new(kind)
		d.main.scene_vp.add_child(ch)
		ch.set_silhouette(false)
		var at: Vector2 = it.p + Vector2(float(pe.at[0]), float(pe.at[1]))
		ch.position = Vector3(at.x, w.height_at(at.x, at.y), at.y)
		ch.facing = String(pe.get("facing", "down"))
		ch.play(String(pe.get("anim", "idle")), true)
		it.chars.append(ch)
