# 기와 줄 삼각형·그리기 수 표(헤드리스): godot --headless --path . -s res://tools/bldg/giwa_tris.gd [-- --types=anchae/central/1,sarang/south/1]
#   단계별 삼각형(near·mid·far), 가까운 단계 조각별(giwa_rows·giwa_hi·giwa_lo·그 밖) 삼각형·표면(그리기) 수, 짓는 시간(ms) — 기와 줄 켬/끔
#   MM 견줌: 줄 띠 대신 국가유산청 수키와 두 장 조각(112삼각형, 0.62m × 배율)을 줄 길이만큼 늘어놓았을 때 삼각형(계산)
extends SceneTree
const B := preload("res://kit/bldg/building.gd")

func _init() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1); args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var types: PackedStringArray = String(args.get("types", "anchae/central/1,sarang/south/1,anchae/south/1,giwajip/south/1")).split(",")
	for on in [false, true]:
		B.GIWA_ROWS = on
		for t in types:
			var q := t.split("/")
			var r: Dictionary = B.build({ type = q[0], region = q[1], seed = int(q[2]) })
			var near: Node = r.node.get_node("near")
			var parts := {}
			var surf := 0
			for mi in near.find_children("*", "MeshInstance3D", true, false):
				var n := 0
				for s in mi.mesh.get_surface_count():
					n += mi.mesh.surface_get_array_index_len(s) / 3 if mi.mesh.surface_get_format(s) & Mesh.ARRAY_FORMAT_INDEX else mi.mesh.surface_get_array_len(s) / 3
				surf += mi.mesh.get_surface_count()
				parts[String(mi.name)] = "%d tris/%d surf%s" % [n, mi.mesh.get_surface_count(), "" if mi.cast_shadow else " noshadow"]
			var mm := ""
			if on and near.get_node_or_null("giwa_rows"):
				# 줄 띠 삼각형 12개 = 한 마디(≤0.5m). 수막새 원판·둘레 30삼각형. 줄 길이 ≈ 띠 삼각형 수 / 12 × 마디 길이(대략) → 조각 수
				var rows_tris := 0
				var mesh: ArrayMesh = (near.get_node("giwa_rows") as MeshInstance3D).mesh
				var arr := mesh.surface_get_arrays(0)
				var P: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
				var L := 0.0
				for i in range(0, P.size(), 3): L += 0.0
				# 띠 길이: 마디 삼각형 12개마다 첫 두 점 사이 길이(띠 방향 모서리)를 더한다
				var segs := P.size() / 36
				for sgi in segs:
					var b := sgi * 36
					L += maxf(P[b].distance_to(P[b + 2]), P[b].distance_to(P[b + 1]))
				mm = " | MM(수키와 두 장 조각 112삼각형): 줄 길이 %.0fm → 조각 %d개 · %d삼각형" % [L, ceili(L / (0.6208 * 1.2)), ceili(L / (0.6208 * 1.2)) * 112]
			print("GIWATRIS rows=%s %s lods=%s gen_ms=%.0f near_surfaces=%d parts=%s%s" % [on, t, str(r.stats.tris), float(r.stats.gen_ms), surf, JSON.stringify(parts), mm])
			r.node.free()
	quit()
