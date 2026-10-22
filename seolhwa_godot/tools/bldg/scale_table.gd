# 실제 크기 표(town-organic): 유형마다 옛 치수(rs=false) ↔ 새 치수 — 칸 너비·깊이·벽(기둥) 높이·기단·마루 높이·처마 내밀기·문 높이·용마루 높이·바닥 크기
#   godot --headless --path . -s res://tools/bldg/scale_table.gd
extends SceneTree
const B := preload("res://kit/bldg/building.gd")
const S := preload("res://kit/bldg/_spec.gd")

func _aabb(n: Node) -> AABB:
	var a := AABB(); var first := true
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null: continue
		var p: Node = mi.get_parent(); var skip := false
		while p != null and p != n:
			if String(p.name) in ["mid", "far"]: skip = true
			p = p.get_parent()
		if skip: continue
		var t: Transform3D = (mi as MeshInstance3D).global_transform if mi.is_inside_tree() else Transform3D.IDENTITY
		var b: AABB = t * (mi as MeshInstance3D).mesh.get_aabb()
		if first: a = b; first = false
		else: a = a.merge(b)
	return a

func _init() -> void:
	print("SCALE type | 신분 | 칸 너비(평균) | 깊이 | 벽 높이 | 기단 | 마루(기단 위) | 처마 | 문(방문 door2) | 용마루 | 바닥 W×D")
	for q in [["choga", "south", "commoner"], ["choga", "south", "poor"], ["jumak", "south", ""], ["giwajip", "south", "middle"], ["sijeon", "south", ""], ["anchae", "south", "yangban"], ["sarang", "south", "yangban"], ["haengrang", "south", "yangban"], ["gotgan", "south", "middle"], ["dongheon", "south", ""], ["gaeksa", "south", ""], ["daeung", "south", ""]]:
		var row := []
		for rs in [false, true]:
			var p := { type = q[0], region = q[1], seed = 1, rs = rs }
			if q[2] != "": p.cls = q[2]
			var sp := S.resolve(p)
			var w: Dictionary = sp.wings[0]
			var bw := 0.0
			for b in w.bays: bw += float(b.w)
			bw /= maxf(1, w.bays.size())
			var D := 0.0
			for d in w.depth: D += float(d)
			var dk: float = float((sp.get("real_scale", [1.0, 1.0]) as Array)[1])
			var hi: bool = sp.cls in ["yangban", "official"]
			var door: float = minf(float(sp.wall_h) - 0.35, (1.85 if hi else 1.7) * dk) - 0.05
			var r := B.build(p.merged({ lod = 0 }))
			root.add_child(r.node)
			var ab := _aabb(r.node)
			r.node.queue_free()
			var fp := B.footprint(p)
			row.append("%.2f | %.2f | %.2f | %.2f | %.2f | %.2f | %.2f | %.2f | %.1f×%.1f" % [bw, D, float(sp.wall_h), float(sp.base.h), float(sp.floor_dh), float(sp.roof.eave), door, ab.end.y, fp.x, fp.y])
		print("SCALE %s/%s | 옛 %s" % [q[0], sp_cls(q), row[0]])
		print("SCALE %s/%s | 새 %s" % [q[0], sp_cls(q), row[1]])
	quit()

func sp_cls(q: Array) -> String:
	return q[2] if q[2] != "" else "-"
