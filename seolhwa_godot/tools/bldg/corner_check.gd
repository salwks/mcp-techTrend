# 모서리 틈 검사 — 외벽끼리 만나는 자리(건물 모서리·ㄱ/ㄷ 날개 이음·기단 모서리·담 모서리·대문–담 이음)에 빛이 새는 틈이 있나(헤드리스).
#   godot --headless --path . -s res://tools/bldg/corner_check.gd -- [--set=builder|compound|all] [--types=a,b] [--seeds=3] [--out=res://…json] [--dbg]
# 방법: near 단계 메시(먹선 껍질 뺌)의 삼각형에 벽을 가로지르는 짧은 광선을 쏜다.
#   · 건물 모서리마다(날개 로컬): 대각선 광선 1 + 두 벽면에서 모서리로부터 d = 0.02·0.05·0.1·0.15·0.25m 떨어진 수직 광선(벽 바깥 0.6m → 안 0.6m),
#     높이는 그 칸 바닥 + 0.04m부터 창방 밑 − 0.06m까지 0.12m 간격. 트인 면(대청·마루·가게·대문간·들어열개)은 건너뛴다.
#   · 기단 모서리: 기단 높이 절반에서 대각선 + 두 면 광선.
#   · 묶음: 담 모서리(대각선 + 두 면, 높이 0.2~담 높이 − 0.15) · 대문 기둥 바로 옆 담 줄(문 밖 → 안 광선, 문 자리 바깥 0.05~0.3m).
#   광선이 아무 면에도 닿지 않으면 '틈'. 끝 줄: CORNERCHECK total gaps=n checked=m
extends SceneTree
const B := preload("res://kit/bldg/building.gd")
const S := preload("res://kit/bldg/_spec.gd")
const CP := preload("res://kit/bldg/compound.gd")
const GT := preload("res://kit/bldg/gate.gd")

const OFFS := [0.02, 0.05, 0.1, 0.15, 0.25]
var INK: Color
var dbg := false
var report := []

class Tris:
	var a := PackedVector3Array(); var b := PackedVector3Array(); var c := PackedVector3Array()
	func add_mesh(mi: MeshInstance3D, xf: Transform3D, ink: Color) -> void:
		for s in mi.mesh.get_surface_count():
			var arr: Array = mi.mesh.surface_get_arrays(s)
			var pos: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var col: PackedColorArray = arr[Mesh.ARRAY_COLOR] if arr[Mesh.ARRAY_COLOR] != null else PackedColorArray()
			var idx = arr[Mesh.ARRAY_INDEX]
			var n: int = idx.size() if idx != null else pos.size()
			for i in range(0, n - 2, 3):
				var i0: int = idx[i] if idx != null else i
				var i1: int = idx[i + 1] if idx != null else i + 1
				var i2: int = idx[i + 2] if idx != null else i + 2
				# 먹선 껍질: 메시 색은 8비트로 줄어 저장되므로(0.0242 → 6/255) 너그럽게 견준다
				if col.size() > i0 and _near(col[i0], ink) and _near(col[i1], ink) and _near(col[i2], ink): continue
				a.append(xf * pos[i0]); b.append(xf * pos[i1]); c.append(xf * pos[i2])
	static func _near(a: Color, b: Color) -> bool:
		return absf(a.r - b.r) < 0.006 and absf(a.g - b.g) < 0.006 and absf(a.b - b.b) < 0.006
	# 광선(선분 p→q)이 삼각형에 닿나 — 근처 삼각형만(상자 거름)
	func hit(p: Vector3, q: Vector3) -> bool:
		var d := q - p
		var lo := Vector3(minf(p.x, q.x), minf(p.y, q.y), minf(p.z, q.z)) - Vector3(0.01, 0.01, 0.01)
		var hi := Vector3(maxf(p.x, q.x), maxf(p.y, q.y), maxf(p.z, q.z)) + Vector3(0.01, 0.01, 0.01)
		for i in a.size():
			var A := a[i]; var Bv := b[i]; var Cv := c[i]
			if maxf(A.x, maxf(Bv.x, Cv.x)) < lo.x or minf(A.x, minf(Bv.x, Cv.x)) > hi.x: continue
			if maxf(A.z, maxf(Bv.z, Cv.z)) < lo.z or minf(A.z, minf(Bv.z, Cv.z)) > hi.z: continue
			if maxf(A.y, maxf(Bv.y, Cv.y)) < lo.y or minf(A.y, minf(Bv.y, Cv.y)) > hi.y: continue
			var e1 := Bv - A; var e2 := Cv - A
			var h := d.cross(e2); var det := e1.dot(h)
			if absf(det) < 1e-12: continue
			var f := 1.0 / det
			var s := p - A
			var u := f * s.dot(h)
			if u < -1e-5 or u > 1.0 + 1e-5: continue
			var qv := s.cross(e1)
			var v := f * d.dot(qv)
			if v < -1e-5 or u + v > 1.0 + 1e-5: continue
			var t := f * e2.dot(qv)
			if t >= 0.0 and t <= 1.0: return true
		return false

func _init() -> void:
	INK = Kit.hex(Kit.INK)
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1); args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	dbg = args.has("dbg")
	var set: String = args.get("set", "all")
	var types: PackedStringArray = String(args.get("types", "choga,jumak,sijeon,anchae,sarang,haengrang,sadang,gotgan,araechae,dongheon,gaeksa,daeseong,gangdang,jeongja,nugak,mill,smithy,daeung,giwajip")).split(",")
	var regions: PackedStringArray = String(args.get("regions", "south,central,north,jeju,mountain")).split(",")
	var seeds := int(args.get("seeds", "3"))
	var gaps := 0; var rays := 0
	if set in ["builder", "all"]:
		for t in types:
			for rg in regions:
				if rg == "mountain" and t != "choga": continue
				for s in seeds:
					for inside in ([false, true] if t in ["choga", "anchae", "sarang", "jumak", "giwajip"] else [false]):
						var pp := { type = t, region = rg, seed = s + 1, interior = inside }
						if args.has("ruin"): pp.over = { ruin = { stage = float(args.ruin), seed = 5 } }   # 폐가 단계(0·1 — 2부터는 일부러 무너진 벽이라 뺀다)
						var r := _building("%s/%s/%d%s" % [t, rg, s + 1, "/int" if inside else ""], pp)
						gaps += r.x; rays += r.y
	if set in ["compound", "all"]:
		for t in ["choga_house", "jungnong", "giwa_house", "yangban", "jumak_yard"]:
			for rg in ["south", "central", "jeju"]:
				for s in seeds:
					var r := _compound("compound/%s/%s/%d" % [t, rg, s + 1], { type = t, region = rg, seed = s + 1 })
					gaps += r.x; rays += r.y
		for gt in ["sarip", "chomun", "ilgak", "pyeong", "soseul", "jungmun", "hyeop", "samun"]:
			var r := _compound("gate/" + gt, { type = "gate_demo", gate = gt, seed = 1 })
			gaps += r.x; rays += r.y
	var out: String = args.get("out", "res://shots/building_rollout/corners/corner_check.json")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out.get_base_dir()))
	var f := FileAccess.open(ProjectSettings.globalize_path(out), FileAccess.WRITE)
	f.store_string(JSON.stringify(report, "\t")); f.close()
	var nb := 0
	for e in report:
		if e.gaps > 0: nb += 1
	print("CORNERCHECK total gaps=%d rays=%d items=%d bad_items=%d" % [gaps, rays, report.size(), nb])
	quit(1 if gaps > 0 else 0)

func _tris_of(node: Node, xf: Transform3D, only_near := true) -> Tris:
	var T := Tris.new()
	_collect(T, node, xf, only_near)
	return T

func _collect(T: Tris, node: Node, xf: Transform3D, only_near: bool) -> void:
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		if only_near and _has_ancestor(mi, node, ["mid", "far"]): continue
		T.add_mesh(mi, xf * _xf_to(mi, node), INK)

static func _has_ancestor(n: Node, root: Node, names: Array) -> bool:
	var c := n.get_parent()
	while c != null and c != root:
		if String(c.name) in names: return true
		c = c.get_parent()
	return false

static func _xf_to(n: Node3D, root: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	var c: Node = n
	while c != null and c != root:
		if c is Node3D: t = (c as Node3D).transform * t
		c = c.get_parent()
	return t

# 한 모서리: 원점 o(월드), 두 벽 방향 u(벽 1을 따라 모서리에서 멀어지는 쪽), v(벽 2), 바깥 = −(u+v). 높이 ys.
#   tq(벽 두께 1/4): 바깥 모서리 네모(두 벽이 가운데 줄에서 멈추면 비는 자리) 검사 — 모서리 바깥 반쪽 두께 줄을 따라 바깥에서 모서리 줄 바로 앞까지
#   두 방향 광선이 둘 다 아무것도 안 맞으면 '홈'(notch)
func _corner(T: Tris, o: Vector3, u: Vector3, v: Vector3, ys: Array, faces: Array, at: Array, tq := 0.035) -> Vector2i:
	var g := 0; var n := 0
	var out := -(u + v).normalized()
	for y in ys:
		var p := Vector3(o.x, y, o.z)
		if faces[0] and faces[1]:
			n += 1
			var r1 := T.hit(p - v * tq - u * 0.6, p - v * tq - u * 0.01)
			var r2 := T.hit(p - u * tq - v * 0.6, p - u * tq - v * 0.01)
			if not (r1 or r2):
				g += 1; at.append(["notch", snappedf(p.x, 0.01), snappedf(y, 0.01), snappedf(p.z, 0.01)])
		if faces[0] and faces[1]:
			n += 1
			if not T.hit(p + out * 0.6, p - out * 0.6):
				g += 1; at.append(["diag", snappedf(p.x, 0.01), snappedf(y, 0.01), snappedf(p.z, 0.01)])
		for k in 2:
			if not faces[k]: continue
			var along: Vector3 = u if k == 0 else v
			var nrm: Vector3 = -(v if k == 0 else u)   # 벽 1의 바깥 = −v
			for d in OFFS:
				var q: Vector3 = p + along * d
				n += 1
				if not T.hit(q + nrm * 0.6, q - nrm * 0.6):
					g += 1; at.append(["face%d" % k, d, snappedf(q.x, 0.01), snappedf(y, 0.01), snappedf(q.z, 0.01)])
	return Vector2i(g, n)

static func _ys(y0: float, y1: float, step := 0.12) -> Array:
	var out := []
	var y := y0
	while y <= y1 + 1e-4:
		out.append(y); y += step
	return out

const OPEN_FACES := ["open", "rail", "shop", "gate", "join", "bunhap_up"]

func _building(name: String, params: Dictionary) -> Vector2i:
	var sp := S.resolve(params)
	var r := B.build(params.merged({ lod = 0 }))
	var T := _tris_of(r.node, Transform3D.IDENTITY, false)
	r.node.free()
	var ctx := B._ctx(sp)
	var gaps := 0; var n := 0
	var at := []
	var bodies := []
	for w in sp.wings:
		var L := 0.0
		for b in w.bays: L += float(b.w)
		var D := 0.0
		for d in w.depth: D += float(d)
		bodies.append([w, L, D, Transform3D(Basis(Vector3.UP, float(w.ry)), Vector3(float(w.x), 0, float(w.z)))])
	for wi in bodies.size():
		var w: Dictionary = bodies[wi][0]; var L: float = bodies[wi][1]; var D: float = bodies[wi][2]; var xf: Transform3D = bodies[wi][3]
		var bays: Array = w.bays
		var Ff: float = float(ctx.Ff) + float(w.floor_up)
		var top: float = Ff + float(sp.wall_h) + float(w.roof_up)
		if Ff - float(ctx.Fb) > 1.2: continue   # 누각: 아래층 트임
		for sd in [0, 1]:
			if w.open_end[sd]: continue
			var b: Dictionary = bays[0 if sd == 0 else bays.size() - 1]
			if b.fn == "maru" or (b.has("side") and String(b.side.kind) in OPEN_FACES): continue
			var y0: float = B._bay_floor(ctx, w, b)
			var sx := -1.0 if sd == 0 else 1.0
			for zs in [-1.0, 1.0]:
				var face: Dictionary = b.front if zs > 0 else b.back
				var front_ok := not (String(face.get("kind", "wall")) in OPEN_FACES)
				var o: Vector3 = xf * Vector3(sx * L / 2, 0, zs * D / 2)
				var u: Vector3 = xf.basis * Vector3(-sx, 0, 0)   # 앞/뒤 벽을 따라 안쪽
				var v: Vector3 = xf.basis * Vector3(0, 0, -zs)   # 옆벽을 따라 안쪽
				# 다른 날개 몸 속 모서리(ㄱ 이음 안쪽)는 건너뛴다 — 그 자리는 다른 날개 벽이 덮는다
				var inside_other := false
				for wj in bodies.size():
					if wj == wi: continue
					var lo: Vector3 = (bodies[wj][3] as Transform3D).affine_inverse() * o
					if absf(lo.x) < float(bodies[wj][1]) / 2 - 0.05 and absf(lo.z) < float(bodies[wj][2]) / 2 - 0.05: inside_other = true
				if inside_other: continue
				var r2 := _corner(T, o, u, v, _ys(y0 + 0.04, top - 0.06), [front_ok, true], at)
				gaps += r2.x; n += r2.y
		# 기단 모서리(트인 끝·맞댐 없는 몸채 기단): 기단 높이 절반
		if sp.base.kind != "none" and float(ctx.Fb) > 0.12:
			pass   # 기단은 한 상자(_base) — 모서리가 이어진 덩이라 틈이 생길 수 없다(검사 생략, 보고서에 적음)
	report.append({ name = name, gaps = gaps, rays = n, at = at.slice(0, 12) })
	if gaps > 0 or dbg: print("CORNERCHECK %s gaps=%d/%d at=%s" % [name, gaps, n, str(at.slice(0, 4))])
	return Vector2i(gaps, n)

func _compound(name: String, params: Dictionary) -> Vector2i:
	var pl := CP.plan(params)
	var T := Tris.new()
	var walls := []
	var gates := []
	for e in pl.pieces:
		var xf := Transform3D(Basis(Vector3.UP, float(e.ry)), Vector3(float(e.x), 0, float(e.z)))
		var kit := String(e.kit)
		# 싸리울(fence)은 성긴 울이라(살 사이로 보이는 게 맞다) 빼고, 흙·돌담과 대문만 본다
		if not (kit.contains("todam") or kit.contains("stone_wall") or kit == "bldg/gate"): continue
		var r: Dictionary = load("res://kit/%s.gd" % kit).build(e.params)
		_collect(T, r.node, xf, true)
		r.node.free()
		if kit == "bldg/gate": gates.append(e)
		else: walls.append(e)
	var gaps := 0; var n := 0
	var at := []
	# 담 모서리: 두 담 가운데 줄이 직각으로 만나는 점이 두 토막 끝 0.5m 안(묶음이 모서리에서 한 토막을 늘리고 한 토막을 물리므로 끝점이 아니라 교점으로 찾는다)
	var segs := []
	for e in walls:
		var p: Dictionary = e.params
		var a := Vector3(float(p.ax), 0, float(p.az)); var b := Vector3(float(p.bx), 0, float(p.bz))
		var h := float(p.get("h", 1.25 if String(e.kit).contains("stone") else 1.2))
		segs.append([a, b, h])
	var ends := []
	for sg in segs: ends.append([sg[0], ((sg[1] as Vector3) - (sg[0] as Vector3)).normalized(), sg[2]]); ends.append([sg[1], ((sg[0] as Vector3) - (sg[1] as Vector3)).normalized(), sg[2]])
	for i in segs.size():
		for j in range(i + 1, segs.size()):
			var a1: Vector3 = segs[i][0]; var b1: Vector3 = segs[i][1]; var a2: Vector3 = segs[j][0]; var b2: Vector3 = segs[j][1]
			var d1 := (b1 - a1).normalized(); var d2 := (b2 - a2).normalized()
			if absf(d1.dot(d2)) > 0.3: continue
			# 교점(xz)
			var den := d1.x * d2.z - d1.z * d2.x
			var t := ((a2.x - a1.x) * d2.z - (a2.z - a1.z) * d2.x) / den
			var o := a1 + d1 * t
			var near1 := minf(o.distance_to(a1), o.distance_to(b1)); var near2 := minf(o.distance_to(a2), o.distance_to(b2))
			if near1 > 0.5 or near2 > 0.5: continue
			# 모서리에서 각 담을 따라 안쪽(토막 가운데 쪽)
			var u := (((a1 + b1) / 2 - o) * Vector3(1, 0, 1)).normalized(); var v := (((a2 + b2) / 2 - o) * Vector3(1, 0, 1)).normalized()
			var h := minf(float(segs[i][2]), float(segs[j][2]))
			var r2 := _corner(T, o, u, v, _ys(0.2, h - 0.15, 0.15), [true, true], at, 0.11)
			gaps += r2.x; n += r2.y
	# 대문 기둥 옆: 문 자리 바깥 0.05~0.3m에서 담 줄을 가로지르는 광선(문 밖 → 안)
	for g in gates:
		var hf := GT.half(g.params)
		if String(g.params.get("type", "")) in ["none", "hongsal"]: continue
		var c := Vector3(float(g.x), 0, float(g.z))
		for sx in [-1.0, 1.0]:
			# 그 쪽에 담이 붙어 있을 때만
			var has_wall := false
			for e in ends:
				if (e[0] as Vector3).distance_to(c + Vector3(sx * hf, 0, 0)) < 0.08: has_wall = true
			if not has_wall: continue
			for d in [0.03, 0.08, 0.15, 0.3]:
				for y in _ys(0.2, 1.1, 0.15):
					var q: Vector3 = c + Vector3(sx * (hf + d), y, 0)
					n += 1
					if not T.hit(q + Vector3(0, 0, 0.8), q - Vector3(0, 0, 0.8)):
						gaps += 1; at.append(["gatejoin", sx, d, snappedf(y, 0.01)])
	report.append({ name = name, gaps = gaps, rays = n, at = at.slice(0, 12) })
	if gaps > 0 or dbg: print("CORNERCHECK %s gaps=%d/%d at=%s" % [name, gaps, n, str(at.slice(0, 4))])
	return Vector2i(gaps, n)
