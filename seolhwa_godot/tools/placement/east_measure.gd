# placement-east 도우미: 키트 build() 결과의 실제 크기(메시 AABB)·삼각형·앵커를 잰다.
#   godot --path . --headless -s res://tools/placement/east_measure.gd -- --in=<specs.json> --out=<bounds.json>
# specs.json = [{key, kit, params}], 결과 = {key: {tris, footprint, aabb:[minx,maxx,minz,maxz,miny,maxy], anchors:{n:[x,y,z]}, pieces:n}}
extends SceneTree

func _rel_xform(n: Node, root: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	var c := n
	while c != null and c != root:
		if c is Node3D: t = (c as Node3D).transform * t
		c = c.get_parent()
	return t

func _measure(node: Node3D) -> Dictionary:
	var tris := 0
	var box := AABB(); var first := true
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var m: Mesh = mi.mesh
		if m == null: continue
		for s in m.get_surface_count(): tris += m.surface_get_array_len(s) / 3
		var bb: AABB = _rel_xform(mi, node) * m.get_aabb()
		if first: box = bb; first = false
		else: box = box.merge(bb)
	for mm in node.find_children("*", "MultiMeshInstance3D", true, false):
		var mmesh: MultiMesh = mm.multimesh
		if mmesh == null or mmesh.mesh == null: continue
		var per := 0
		for s in mmesh.mesh.get_surface_count(): per += mmesh.mesh.surface_get_array_len(s) / 3
		tris += per * mmesh.instance_count
	return { tris = tris, box = box }

func _init() -> void:
	var inp := ""; var outp := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--in="): inp = a.substr(5)
		elif a.begins_with("--out="): outp = a.substr(6)
	var specs: Array = JSON.parse_string(FileAccess.get_file_as_string(inp))
	var res := {}
	for sp in specs:
		var scr = load("res://kit/%s.gd" % sp.kit)
		if scr == null:
			res[sp.key] = { error = "no kit" }; continue
		var p: Dictionary = sp.params
		# JSON 숫자는 float — seed 등 정수 필드는 int로
		for k in p.keys():
			if typeof(p[k]) == TYPE_FLOAT and p[k] == floor(p[k]) and k in ["seed", "bays", "spans", "n"]: p[k] = int(p[k])
		var r: Dictionary = scr.build(p)
		var m := _measure(r.node)
		var b: AABB = m.box
		var anc := {}
		for k in (r.get("anchors", {}) as Dictionary).keys():
			var v = r.anchors[k]
			if v is Vector3: anc[k] = [snappedf(v.x, 0.01), snappedf(v.y, 0.01), snappedf(v.z, 0.01)]
		var fp: Vector2 = r.get("footprint", Vector2.ZERO)
		res[sp.key] = { tris = m.tris, footprint = [fp.x, fp.y],
			aabb = [b.position.x, b.end.x, b.position.z, b.end.z, b.position.y, b.end.y],
			anchors = anc, pieces = (r.get("pieces", []) as Array).size(), keys = r.keys() }
		(r.node as Node3D).free()
	var f := FileAccess.open(outp, FileAccess.WRITE)
	f.store_string(JSON.stringify(res, " "))
	f.close()
	print("MEASURED ", res.size())
	quit()
