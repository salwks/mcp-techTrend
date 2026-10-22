# 지붕 겹침 검사 — 지붕끼리·지붕과 담 갓(기와 갓)이 서로 뚫고 지나가는지 본다(헤드리스 가능).
#   godot --headless --path . -s res://tools/bldg/roof_check.gd -- [--set=builder|old|all] [--out=res://shots/building_builder/roof_check.json]
# 방법: 조각마다 지붕 겉면(위를 보는 삼각형)·밑면(아래를 보는 삼각형)을 위에서 내려다본 0.15m 격자에 그려
#   top(가장 높은 겉) · under(가장 낮은 밑) 두 판을 만든다(먹선 껍질은 뺀다). 그리고:
#   · 다른 건물(묶음의 조각)끼리: 겹친 칸에서 낮은 지붕의 겉이 높은 지붕의 밑면보다 높으면 '뚫음'(처마가 처마 밑으로 들어가는 것만 허용)
#   · 한 건물의 날개끼리(ㄱ·ㄷ 회첨, 솟을대문): 한 지붕의 가장자리(처마·박공 끝) 칸이 다른 지붕 면을 뚫고 위로 나오면 '뚫음'
#     (회첨골처럼 두 면이 만나 골을 이루는 것은 허용 — 가장자리가 다른 지붕 속에 숨거나 그 위로 떠 있으면 통과)
#   · 담 갓: 지붕 아래 칸에서 갓 윗면이 지붕 밑면보다 높으면 '뚫음'(갓은 처마 밑으로 들어가거나 맞닿아야 한다)
# 끝 줄: ROOFCHECK <이름> pass|FAIL … · ROOFCHECK total fail=n
extends SceneTree
const B := preload("res://kit/bldg/building.gd")
const S := preload("res://kit/bldg/_spec.gd")
const CP := preload("res://kit/bldg/compound.gd")

const CELL := 0.15
const TOL := 0.05
var report := []

func _init() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1); args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var set: String = args.get("set", "all")
	var fails := 0
	if args.has("only"):
		var q: PackedStringArray = String(args.only).split("/")
		fails += _check_building(String(args.only), S.resolve({ type = q[0], region = q[1], seed = int(q[2]) }))
		set = "none"
	if set in ["builder", "all"]:
		for t in ["choga", "jumak", "sijeon", "anchae", "sarang", "haengrang", "sadang", "gotgan", "araechae", "dongheon", "gaeksa", "daeseong", "gangdang", "jeongja", "nugak", "mill", "smithy", "daeung", "giwajip"]:
			for rg in ["south", "central", "north", "jeju"]:
				for s in [1, 2, 3]:
					fails += _check_building("%s/%s/%d" % [t, rg, s], S.resolve({ type = t, region = rg, seed = s }))
		for t in ["choga_house", "jungnong", "giwa_house", "yangban", "jumak_yard"]:
			for rg in ["south", "central"]:
				for s in [1, 2, 3, 4, 5, 6]:
					fails += _check_compound("compound/%s/%s/%d" % [t, rg, s], { type = t, region = rg, seed = s })
	if set in ["old", "all"]:
		for sz in ["small", "medium", "large"]:
			for s in [1, 2, 3]:
				fails += _check_old("village/house_compound/%s/%d" % [sz, s], "village/house_compound", { seed = s, size = sz })
		fails += _check_old("village/house_compound/medium/giwa_giyeok", "village/house_compound", { seed = 5, size = "medium", roof = "giwa", plan = "giyeok" })
		fails += _check_old("village/house_compound/large/lod1", "village/house_compound", { seed = 1, size = "large", lod = 1 })
		fails += _check_old("village/house_compound/medium/lod1", "village/house_compound", { seed = 1, size = "medium", lod = 1 })
		fails += _check_single_old("village/giwa/giyeok", "village/giwa", { seed = 1, plan = "giyeok" })
		fails += _check_single_old("village/choga/giyeok", "village/choga", { seed = 1, plan = "giyeok" })
		for st in ["tile", "soseul", "thatch"]: fails += _check_single_old("village/daemun/" + st, "village/daemun", { seed = 1, style = st })
		# 옛 키트 실제 크기(placement_loader plan_scale): 묶음 k · 한 채 w·d·wall_h × k
		for sz in ["small", "medium", "large"]:
			var kk: float = { small = 1.16, medium = 1.2, large = 1.22 }[sz]
			for s in [1, 2]:
				fails += _check_old("village/house_compound/%s/%d/k%.2f" % [sz, s, kk], "village/house_compound", { seed = s, size = sz, k = kk })
		fails += _check_single_old("village/giwa/k1.22", "village/giwa", { seed = 1, w = 9.0 * 1.22, d = 5.4 * 1.22, wall_h = 2.3 * 1.22 })
		fails += _check_single_old("village/giwa/giyeok/k1.22", "village/giwa", { seed = 1, plan = "giyeok", w = 9.0 * 1.22, d = 5.4 * 1.22, wall_h = 2.3 * 1.22 })
		fails += _check_single_old("village/choga/k1.2", "village/choga", { seed = 1, w = 7.2, d = 4.8, wall_h = 2.22 })
		fails += _check_single_old("village/choga/giyeok/k1.2", "village/choga", { seed = 1, plan = "giyeok", w = 7.2, d = 4.8, wall_h = 2.22 })
	if set == "ruin":
		# 폐가 단계마다(자른 지붕·처짐·기울기 포함): 남은 지붕 밑에서 벽이 뚫고 나오지 않나 — 지붕이 없어진 자리의 벽('outside')은 폐가라 셈하지 않는다
		for t in ["choga", "anchae", "sarang", "gotgan", "araechae", "jumak", "giwajip", "haengrang"]:
			for rg in ["south", "central", "north", "jeju"]:
				for st in [1.0, 2.0, 3.0]:
					var sp := S.resolve({ type = t, region = rg, seed = 1 })
					sp.ruin = { stage = st, seed = 5 }
					var rz := preload("res://kit/bldg/_ruin.gd").resolve(sp)
					preload("res://kit/bldg/_ruin.gd").plan(sp, rz)
					sp._rz = rz
					ruin_mode = true
					fails += _check_clear("ruin/%s/%s/%d" % [t, rg, int(st)], sp)
		ruin_mode = false
	if set == "place":
		fails += _check_place(String(args.get("file", "res://region_data/JL_NAMWON_UNBONG/placement_namwon.json")), String(args.get("bbox", "-3420,200,-3322,365")).split(","))
	var out: String = args.get("out", "res://shots/building_builder/roof_check.json")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out.get_base_dir()))
	var f := FileAccess.open(ProjectSettings.globalize_path(out), FileAccess.WRITE)
	f.store_string(JSON.stringify(report, "\t")); f.close()
	var nc := 0; var mc := 99.0
	for c in clear_report:
		if not c.ok: nc += 1
		mc = minf(mc, c.min_clear)
	print("WALLCLEAR total fail=%d checked=%d min_clear=%.2f" % [nc, clear_report.size(), mc])
	var f2 := FileAccess.open(ProjectSettings.globalize_path(out.get_basename() + "_wallclear.json"), FileAccess.WRITE)
	f2.store_string(JSON.stringify(clear_report, "\t")); f2.close()
	print("ROOFCHECK total fail=%d checked=%d" % [fails, report.size()])
	quit(1 if fails > 0 else 0)

# ---- 격자 ----------------------------------------------------------------------------------------
class Grid:
	var top := {}    # Vector2i → y
	var under := {}
	var name := ""
	var group := ""
	var kind := "roof"   # roof | coping

# 삼각형 목록(월드)을 격자에 — ccw: three 감김(빌더 Geo)이면 true, Godot 메시 배열이면 false
static func rasterize(gr: Grid, pos: PackedVector3Array, col: PackedColorArray, xf: Transform3D, ccw: bool, min_y := -INF) -> void:
	var ink := Kit.hex(Kit.INK)
	for i in range(0, pos.size() - 2, 3):
		if col.size() > i and col[i].is_equal_approx(ink) and col[i + 1].is_equal_approx(ink): continue
		var a: Vector3 = xf * pos[i]; var b: Vector3 = xf * pos[i + 1]; var c: Vector3 = xf * pos[i + 2]
		if minf(a.y, minf(b.y, c.y)) < min_y: continue
		var n := (b - a).cross(c - a) if ccw else (c - a).cross(b - a)
		var L := n.length()
		if L < 1e-9: continue
		n /= L
		var up := n.y > 0.2; var dn := n.y < -0.2
		if not (up or dn): continue
		var x0 := floori(minf(a.x, minf(b.x, c.x)) / CELL); var x1 := floori(maxf(a.x, maxf(b.x, c.x)) / CELL)
		var z0 := floori(minf(a.z, minf(b.z, c.z)) / CELL); var z1 := floori(maxf(a.z, maxf(b.z, c.z)) / CELL)
		var d := (b.x - a.x) * (c.z - a.z) - (c.x - a.x) * (b.z - a.z)
		if absf(d) < 1e-9: continue
		for zi in range(z0, z1 + 1):
			for xi in range(x0, x1 + 1):
				var px := (xi + 0.5) * CELL; var pz := (zi + 0.5) * CELL
				var u := ((b.x - px) * (c.z - pz) - (c.x - px) * (b.z - pz)) / d
				var v := ((c.x - px) * (a.z - pz) - (a.x - px) * (c.z - pz)) / d
				var w := 1.0 - u - v
				if u < -1e-4 or v < -1e-4 or w < -1e-4: continue
				var y := u * a.y + v * b.y + w * c.y
				var k := Vector2i(xi, zi)
				if up:
					if not gr.top.has(k) or y > gr.top[k]: gr.top[k] = y
				else:
					if not gr.under.has(k) or y < gr.under[k]: gr.under[k] = y

static func _under(g: Grid, k: Vector2i) -> float:
	return g.under[k] if g.under.has(k) else g.top[k] - 0.3

static func _edge(g: Grid, k: Vector2i) -> bool:
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if not g.top.has(k + d): return true
	return false

static func _inside(g: Grid, k: Vector2i, r := 2) -> bool:
	for dz in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if not g.top.has(k + Vector2i(dx, dz)): return false
	return true

# 두 판 견주기 → [{kind, n, at: [x,z], depth}]
static func compare(p: Grid, q: Grid) -> Array:
	var out := []
	var same := p.group == q.group and p.group != ""
	if p.kind == "coping" and q.kind == "coping": return out
	if p.kind == "coping" or q.kind == "coping":
		var cp: Grid = p if p.kind == "coping" else q; var rf: Grid = q if cp == p else p
		var n := 0; var worst := 0.0; var at := Vector2.ZERO
		for k in cp.top:
			if not rf.top.has(k): continue
			var dd: float = cp.top[k] - _under(rf, k)
			if dd > 0.02:
				n += 1
				if dd > worst: worst = dd; at = Vector2((k.x + 0.5) * CELL, (k.y + 0.5) * CELL)
		if n > 3: out.append({ kind = "coping_through_roof", a = cp.name, b = rf.name, n = n, depth = snappedf(worst, 0.01), at = [snappedf(at.x, 0.1), snappedf(at.y, 0.1)] })
		return out
	for pair in [[p, q], [q, p]]:
		var A: Grid = pair[0]; var Bq: Grid = pair[1]
		var n := 0; var worst := 0.0; var at := Vector2.ZERO
		for k in A.top:
			if not Bq.top.has(k): continue
			var at_ := float(A.top[k]); var bt := float(Bq.top[k])
			if same:
				# 날개끼리: A 가장자리가 B 면 안쪽에서 B를 뚫고 나옴(A 판이 B 겉을 가로지름)
				if not _edge(A, k) or not _inside(Bq, k): continue
				if at_ > bt + TOL and _under(A, k) < bt - TOL:
					n += 1
					if at_ - bt > worst: worst = at_ - bt; at = Vector2((k.x + 0.5) * CELL, (k.y + 0.5) * CELL)
			else:
				# 다른 건물: 낮은 쪽(A)의 겉이 높은 쪽(B)의 밑면보다 높으면서 B 겉보다는 낮다 = 두 판이 엇갈림
				if at_ > bt: continue
				if at_ > _under(Bq, k) + 0.02:
					n += 1
					var dd := at_ - _under(Bq, k)
					if dd > worst: worst = dd; at = Vector2((k.x + 0.5) * CELL, (k.y + 0.5) * CELL)
		if n > 3: out.append({ kind = "roof_poke" if same else "roof_through_roof", a = A.name, b = Bq.name, n = n, depth = snappedf(worst, 0.01), at = [snappedf(at.x, 0.1), snappedf(at.y, 0.1)] })
	return out

func _finish(name: String, grids: Array) -> int:
	var issues := []
	for i in grids.size():
		for j in range(i + 1, grids.size()):
			issues.append_array(compare(grids[i], grids[j]))
	report.append({ name = name, ok = issues.is_empty(), pieces = grids.size(), issues = issues })
	if issues.is_empty(): print("ROOFCHECK %s pass (%d)" % [name, grids.size()])
	else:
		for it in issues: print("ROOFCHECK %s FAIL %s %s↔%s cells=%d depth=%.2f at=%s" % [name, it.kind, it.a, it.b, it.n, it.depth, str(it.at)])
	return 0 if issues.is_empty() else 1

func _builder_grids(tag: String, sp: Dictionary, xf: Transform3D) -> Array:
	var out := []
	for e in B.roof_geos(sp):
		var g := Grid.new(); g.name = "%s.%s" % [tag, e.wing]; g.group = tag
		rasterize(g, e.geo.pos, e.geo.col, xf, true)
		if not g.top.is_empty(): out.append(g)
	return out

func _check_building(name: String, sp: Dictionary) -> int:
	return _finish(name, _builder_grids("b", sp, Transform3D.IDENTITY)) + _check_clear(name, sp)

# 벽·기둥·도리 윗면이 지붕 밑면보다 낮은가(처마 밖으로 나온 벽 모서리·이엉을 뚫는 벽이 없나) — 칸마다 여유 CLEAR
const CLEAR := 0.03
var clear_report := []
var ruin_mode := false
func _check_clear(name: String, sp: Dictionary) -> int:
	# 벽·기둥 윗면(벽 높이 top 이하) ↔ 지붕 밑면: 여유 CLEAR 이상 · 창방·도리(top 위) ↔ 지붕 겉면: 뚫고 나오지 않음 · 처마 밖 벽 칸 없음
	var roof := Grid.new(); var wall := Grid.new(); var beam := Grid.new()
	for e in B.roof_geos(sp):
		var t: float = e.top
		rasterize(roof, e.geo.pos, e.geo.col, Transform3D.IDENTITY, true)
		rasterize_band(wall, e.walls.pos, e.walls.col, t - 0.6, t + 0.02)
		rasterize_band(beam, e.walls.pos, e.walls.col, t + 0.02, t + 1.2)
	var n_out := 0; var n_hit := 0; var n_top := 0; var at := Vector2.ZERO; var minc := 99.0
	for k in wall.top:
		var wy: float = wall.top[k]
		if not roof.top.has(k):
			n_out += 1; at = Vector2((k.x + 0.5) * CELL, (k.y + 0.5) * CELL); continue
		var c: float = _under(roof, k) - wy
		minc = minf(minc, c)
		if c < CLEAR:
			n_hit += 1; at = Vector2((k.x + 0.5) * CELL, (k.y + 0.5) * CELL)
			if OS.get_cmdline_user_args().has("--dbg"): print("  DBG %s cell=%s wall_y=%.2f under=%.2f roof_top=%.2f has_under=%s" % [name, str(at), wy, _under(roof, k), roof.top[k], roof.under.has(k)])
	for k in beam.top:
		if (not roof.top.has(k) and not ruin_mode) or (roof.top.has(k) and beam.top[k] > roof.top[k] - 0.02):
			n_top += 1
			if OS.get_cmdline_user_args().has("--dbg"): print("  DBGB %s cell=(%.2f,%.2f) beam_y=%.2f roof_top=%s" % [name, (k.x + 0.5) * CELL, (k.y + 0.5) * CELL, beam.top[k], str(roof.top.get(k))])
	var ok := (n_out <= 2 or ruin_mode) and n_hit <= 2 and n_top <= 2
	clear_report.append({ name = name, ok = ok, wall_cells = wall.top.size(), outside = n_out, through = n_hit, beam_through_top = n_top, min_clear = snappedf(minc, 0.01), at = [snappedf(at.x, 0.1), snappedf(at.y, 0.1)] })
	if not ok: print("WALLCLEAR %s FAIL outside=%d through=%d beam_top=%d min_clear=%.2f at=%s" % [name, n_out, n_hit, n_top, minc, str(at)])
	return 0 if ok else 1

# 높이 띠 [y0, y1] 안에 다 든 위를 보는 삼각형만
static func rasterize_band(gr: Grid, pos: PackedVector3Array, col: PackedColorArray, y0: float, y1: float) -> void:
	var keep := PackedVector3Array(); var kc := PackedColorArray()
	for i in range(0, pos.size() - 2, 3):
		var lo := minf(pos[i].y, minf(pos[i + 1].y, pos[i + 2].y)); var hi := maxf(pos[i].y, maxf(pos[i + 1].y, pos[i + 2].y))
		if lo < y0 or hi > y1: continue
		keep.append(pos[i]); keep.append(pos[i + 1]); keep.append(pos[i + 2])
		if col.size() > i: kc.append(col[i]); kc.append(col[i + 1]); kc.append(col[i + 2])
	rasterize(gr, keep, kc, Transform3D.IDENTITY, true)

func _mesh_grid(node: Node3D, name: String, group: String, kind: String, xf: Transform3D, min_y: float) -> Grid:
	var g := Grid.new(); g.name = name; g.group = group; g.kind = kind
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var t: Transform3D = xf * _xf_to(mi, node)
		for s in mi.mesh.get_surface_count():
			var arr: Array = mi.mesh.surface_get_arrays(s)
			var cols: PackedColorArray = arr[Mesh.ARRAY_COLOR] if arr[Mesh.ARRAY_COLOR] != null else PackedColorArray()
			rasterize(g, arr[Mesh.ARRAY_VERTEX], cols, t, false, min_y)
	return g

static func _xf_to(n: Node3D, root: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var c: Node = n
	while c != null and c != root:
		if c is Node3D: t = (c as Node3D).transform * t
		c = c.get_parent()
	return t

static func _is_wall(kit: String) -> bool:
	for w in ["todam", "stone_wall", "fence", "wall_run"]:
		if kit.contains(w): return true
	return false

func _check_compound(name: String, params: Dictionary) -> int:
	var grids := []
	for e in CP.plan(params).pieces:
		var xf := Transform3D(Basis(Vector3.UP, float(e.ry)), Vector3(float(e.x), 0, float(e.z)))
		if e.kit == "bldg/building":
			grids.append_array(_builder_grids(String(e.tag), S.resolve(e.params), xf))
		elif _is_wall(e.kit) or e.kit.contains("daemun") or e.kit.contains("gate"):
			var r: Dictionary = load("res://kit/%s.gd" % e.kit).build(e.params)
			var g := _mesh_grid(r.node, String(e.tag), String(e.tag), "coping" if _is_wall(e.kit) else "roof", xf, 0.9 if _is_wall(e.kit) else 1.6)
			if not g.top.is_empty(): grids.append(g)
			r.node.free()
	return _finish(name, grids)

# 배치에 놓인 건물 전부(범위 안): 빌더 묶음·건물은 조각마다, 옛 키트(초가·기와·집 묶음)는 지어서 — 다른 항목끼리 · 묶음 안 조각끼리 · 벽–지붕 여유
#   --set=place --file=res://…/placement_namwon.json --bbox=x0,z0,x1,z1
func _check_place(file: String, bb: PackedStringArray) -> int:
	var d = JSON.parse_string(FileAccess.get_file_as_string(file))
	var grids := []
	var fails := 0
	var x0 := float(bb[0]); var z0 := float(bb[1]); var x1 := float(bb[2]); var z1 := float(bb[3])
	var nb := 0
	for it in d.items:
		var X := float(it.x); var Z := float(it.z)
		if X < x0 or X > x1 or Z < z0 or Z > z1: continue
		var kit := String(it.kit)
		var ixf := Transform3D(Basis(Vector3.UP, float(it.get("ry", 0.0))), Vector3(X, 0, Z))
		var id := String(it.id)
		if kit == "bldg/compound":
			for e in CP.plan(it.params).pieces:
				var xf := ixf * Transform3D(Basis(Vector3.UP, float(e.ry)), Vector3(float(e.x), 0, float(e.z)))
				if e.kit == "bldg/building":
					var sp := S.resolve(e.params)
					for g in _builder_grids(id + "/" + String(e.tag), sp, xf): g.group = id + "/" + String(e.tag); grids.append(g)
					fails += _check_clear(id + "/" + String(e.tag), sp); nb += 1
				elif _is_wall(e.kit) or e.kit.contains("gate"):
					var r: Dictionary = load("res://kit/%s.gd" % e.kit).build(e.params)
					var g := _mesh_grid(r.node, id + "/" + String(e.tag), id + "/" + String(e.tag), "coping" if _is_wall(e.kit) else "roof", xf, 0.9 if _is_wall(e.kit) else 1.6)
					if not g.top.is_empty(): grids.append(g)
					r.node.free()
		elif kit == "bldg/building":
			var sp := S.resolve(it.params)
			for g in _builder_grids(id, sp, ixf): g.group = id; grids.append(g)
			fails += _check_clear(id, sp); nb += 1
		elif kit in ["village/choga", "village/giwa", "village/jumak"]:
			var r: Dictionary = load("res://kit/%s.gd" % kit).build(it.params)
			var g := _mesh_grid(r.node, id, id, "roof", ixf, 1.7)
			if not g.top.is_empty(): grids.append(g)
			r.node.free(); nb += 1
		elif kit == "village/house_compound":
			for e in load("res://kit/village/house_compound.gd").layout(it.params):
				if e.kit.contains("jangdok") or e.kit.contains("firewood") or e.kit.contains("teotbat"): continue
				var r: Dictionary = load("res://kit/%s.gd" % e.kit).build(e.params)
				var xf := ixf * Transform3D(Basis(Vector3.UP, float(e.ry)), Vector3(float(e.x), 0, float(e.z)))
				var wall := _is_wall(e.kit)
				var g := _mesh_grid(r.node, id + "/" + String(e.tag), id + "/" + String(e.tag), "coping" if wall else "roof", xf, 0.9 if wall else 1.7)
				if not g.top.is_empty(): grids.append(g)
				r.node.free()
			nb += 1
	print("ROOFCHECK place items(buildings)=%d grids=%d" % [nb, grids.size()])
	return fails + _finish("place:" + file.get_file(), grids)

# 기존 묶음(village/house_compound): 조각마다 지어서 메시로
func _check_old(name: String, kit: String, params: Dictionary) -> int:
	var scr = load("res://kit/%s.gd" % kit)
	var grids := []
	var ps: Array = scr.layout(params)
	for e in ps:
		var r: Dictionary = load("res://kit/%s.gd" % e.kit).build(e.params)
		var xf := Transform3D(Basis(Vector3.UP, float(e.ry)), Vector3(float(e.x), 0, float(e.z)))
		var wall := _is_wall(e.kit)
		if e.kit.contains("jangdok") or e.kit.contains("firewood") or e.kit.contains("teotbat"): r.node.free(); continue
		var g := _mesh_grid(r.node, String(e.tag), String(e.tag), "coping" if wall else "roof", xf, 0.9 if wall else 1.7)
		if not g.top.is_empty(): grids.append(g)
		r.node.free()
	return _finish(name, grids)

func _check_single_old(name: String, kit: String, params: Dictionary) -> int:
	var r: Dictionary = load("res://kit/%s.gd" % kit).build(params)
	var g := _mesh_grid(r.node, name, "x", "roof", Transform3D.IDENTITY, 1.7)
	r.node.free()
	report.append({ name = name, ok = true, pieces = 1, issues = [], note = "단일 메시 — 날개 분리 불가(눈으로 확인)" })
	print("ROOFCHECK %s single-mesh cells=%d (날개를 나눌 수 없어 눈으로 확인)" % [name, g.top.size()])
	return 0
