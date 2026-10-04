# kit/scenario 공용 — 시나리오 장소(들어가는 건물·굴·섬)와 상태 있는 프롭.
#   S: 부분(part)별 묶음 + 상태 부분("S_<그룹>_<상태>") + 상태 메타(states·state_default·state_fx·state_colliders)를 모아
#      build() 결과를 만든다. 상태 규칙은 scripts/region/prop_states.gd 머리말.
#      여러 상태에서 같이 보이는 부분은 이름에 상태를 '-'로 잇는다: "S_main_NORMAL-FIRE_1-FIRE_2".
#   shell(): 들어가는 목조 건물 한 채(기단·마루·기둥·벽·앞벽·지붕) — 앞벽(front)·지붕(roof)은 실내에서 숨긴다.
# 쓰는 법: const SC := preload("res://kit/scenario/_sc.gd"); var s := SC.S.new(seed); SC.shell(s, {...}); return s.result("이름", fp)
extends RefCounted

const C := preload("res://kit/village/_common.gd")
const Co := preload("res://kit/landmark/_common.gd")
const Roof := preload("res://kit/landmark/_roof.gd")
const CH := preload("res://kit/village/choga.gd")

const WOOD := [0x6b5038, 0x4d3826]
const WOOD_L := [0x9a7852, 0x7a5c3e]
const WOOD_OLD := [0x6e6256, 0x4e463e]     # 비바람에 바랜 나무
const CHAR := [0x2a2420, 0x161210]         # 숯
const MUD := [0xd2b98c, 0xa88c62]
const MUD_OLD := [0xbfae8a, 0x8f7f62]
const PLASTER := [0xe8dfc8, 0xd2c4a6]
const STONE := [0xa19b8f, 0x77726a]
const PAPER := [0xece2c6, 0xd8ccac]

# 부분 하나에 add(key, geo, outline)를 넘기는 대리(landmark 도우미가 Batch처럼 쓴다)
class P:
	var m
	var part: String
	func _init(mm, p: String) -> void:
		m = mm; part = p
	var indoor := false
	func add(key: String, g: Kit.Geo, outline := 0.03) -> Kit.Geo:
		if indoor: S.SC_indoor(g)
		m.add(part, key, g, outline)
		return g
	func is_empty() -> bool:
		return false

class S:
	var m          # village/_common.gd M (부분별 노드)
	var rng: Kit.Rng
	var states := {}           # 그룹 → [상태…]
	var state_default := {}
	var state_fx := {}         # 그룹 → {상태: [fx]}
	var state_cols := {}       # 그룹 → {상태: [충돌체]}
	var wrap := {}             # 부분 → 감쌀 상태 노드 이름(실내 숨김과 상태 숨김이 겹치지 않게 부모로)
	var interior = null
	var hide := []             # 실내에서 숨길 부분 이름
	var extra := {}            # 결과에 덧붙일 것(move, walk …)

	func _init(seed := 1) -> void:
		m = C.M.new(seed, false)
		rng = m.rng

	func r() -> float: return rng.next()
	func between(a: float, b: float) -> float: return rng.between(a, b)
	var indoor_parts := ["interior", "floor_in"]   # 이 부분은 날씨(눈·젖음)를 받지 않는다(버텍스 알파 0 — materials.gd WEATHER_CODE)
	var all_indoor := false                       # 소품 전체가 실내(params.indoor)
	func add(part: String, key: String, g: Kit.Geo, outline := 0.03) -> void:
		if all_indoor or part in indoor_parts: SC_indoor(g)
		m.add(part, key, g, outline)
	static func SC_indoor(g: Kit.Geo) -> Kit.Geo:
		for i in g.col.size(): g.col[i].a = 0.0
		return g
	func p(part: String) -> P:
		var pp := P.new(m, part)
		pp.indoor = all_indoor or part in indoor_parts
		return pp

	# 그룹 group의 상태 state(들)에서만 보이는 부분. states는 "FIRE_1" 또는 ["NORMAL","FIRE_1"]
	func st(group: String, sts, default := "") -> P:
		var arr: Array = sts if sts is Array else [sts]
		if not states.has(group): states[group] = []
		for x in arr:
			if not (states[group] as Array).has(x): states[group].append(x)
		if default != "": state_default[group] = default
		var pp := P.new(m, "S_%s_%s" % [group, "-".join(arr)])
		pp.indoor = all_indoor
		return pp

	# 이미 있는 부분(예: roof)을 상태 노드로 감싼다(그 상태들에서만 보임)
	func wrap_part(part: String, group: String, sts: Array) -> void:
		if not states.has(group): states[group] = []
		for x in sts:
			if not (states[group] as Array).has(x): states[group].append(x)
		wrap[part] = "S_%s_%s" % [group, "-".join(sts)]

	func fx(group: String, state: String, spec: Dictionary) -> void:
		if not state_fx.has(group): state_fx[group] = {}
		if not state_fx[group].has(state): state_fx[group][state] = []
		state_fx[group][state].append(spec)

	func scol(group: String, state: String, c: Dictionary) -> void:
		if not state_cols.has(group): state_cols[group] = {}
		if not state_cols[group].has(state): state_cols[group][state] = []
		state_cols[group][state].append(c)

	func box_c(a: float, b: float, c: float, d: float) -> void: m.box_c(a, b, c, d)
	func circle(x: float, z: float, rr: float) -> void: m.circle(x, z, rr)
	func light(x: float, y: float, z: float, kind: String) -> void: m.light(x, y, z, kind)
	func anchor(n: String, v: Vector3) -> void: m.anchor(n, v)

	func result(name: String, fp: Vector2, occluder := true) -> Dictionary:
		var res: Dictionary = m.result(name, fp, occluder)
		var node: Node3D = res.node
		# 감싸기: 상태 노드(부모) 아래로 부분을 옮긴다
		var holders := {}
		for part in wrap:
			var n := node.get_node_or_null(NodePath(part))
			if n == null: continue
			var hn: String = wrap[part]
			if not holders.has(hn):
				var h := Node3D.new(); h.name = hn
				node.add_child(h); holders[hn] = h
			node.remove_child(n); holders[hn].add_child(n)
		if not states.is_empty():
			res.states = states
			res.state_default = state_default
		if not state_fx.is_empty(): res.state_fx = state_fx
		if not state_cols.is_empty(): res.state_colliders = state_cols
		if interior != null:
			var it: Dictionary = interior.duplicate()
			var hs := []
			for h in hide:
				var hn: Node = node.find_child(h, true, false)
				if hn != null: hs.append(hn)
			it.hide = hs
			res.interior = it
		res.merge(extra, true)
		return res

# 색칠(색 배열 하나짜리도 받는다): cols = [위, 아래] 또는 [색]
static func pa(g: Kit.Geo, cols: Array, jit := 0.05, rng: Kit.Rng = null) -> Kit.Geo:
	return Kit.paint(g, Kit.hex(cols[0]), Kit.hex(cols[1] if cols.size() > 1 else cols[0]), jit, rng)

# 바닥 사각형(중심 0, 크기 w×d)에서 구멍 hole{x,z,w,d}를 뺀 사각형들 [[cx, cz, w, d]…]
static func floor_rects(w: float, d: float, hole) -> Array:
	if not (hole is Dictionary): return [[0.0, 0.0, w, d]]
	var hx0: float = float(hole.x) - float(hole.w) / 2; var hx1: float = float(hole.x) + float(hole.w) / 2
	var hz0: float = float(hole.z) - float(hole.d) / 2; var hz1: float = float(hole.z) + float(hole.d) / 2
	var out := []
	if hx0 > -w / 2: out.append([(-w / 2 + hx0) / 2, 0.0, hx0 + w / 2, d])
	if hx1 < w / 2: out.append([(hx1 + w / 2) / 2, 0.0, w / 2 - hx1, d])
	if hz0 > -d / 2: out.append([(hx0 + hx1) / 2, (-d / 2 + hz0) / 2, hx1 - hx0, hz0 + d / 2])
	if hz1 < d / 2: out.append([(hx0 + hx1) / 2, (hz1 + d / 2) / 2, hx1 - hx0, d / 2 - hz1])
	return out

# 사각 판(위를 봄), 크기 w×d, 중심, 높이 y
static func slab(w: float, d: float, x: float, y: float, z: float) -> Kit.Geo:
	return Kit.plane(w, d, x, y, z)

# ---------------------------------------------------------------------------
# 들어가는 건물 한 채. 정면 +z, 원점 = 바닥 중심(땅).
# o: W, D, F(마루 높이), H(벽 높이), bays:[{w, kind}] kind: door(두 짝 창호문, 열림 open) gate(널문 열림) gate_closed shutter(가게 널판 덧문 — 열린 가게)
#    window wall open, roof: giwa|choga|none, wall: MUD|PLASTER|WOOD 색 배열, wall_key(mud|wood), old(bool: 바랜 색·빠진 기와),
#    floor: wood|earth, back_window:{x, w, h, y} (그룹 "window": SEALED 닫힘 / OPEN 열림 / BROKEN 부서짐), side_door: -1|1(옆문, 0 없음),
#    camera:{pitch, distance}, front_part(앞벽 부분 이름, 기본 "front"), roof_part("roof")
# 반환 { W, D, F, top, eave, zf, zb, doors:[x…] } · s.interior·s.hide·충돌체 등록
# ---------------------------------------------------------------------------
static func shell(s: S, o: Dictionary) -> Dictionary:
	var W: float = o.get("W", 7.0); var D: float = o.get("D", 5.0)
	var F: float = o.get("F", 0.45); var H: float = o.get("H", 2.4)
	var old: bool = o.get("old", false)
	var wall: Array = o.get("wall", MUD_OLD if old else MUD)
	var wkey: String = o.get("wall_key", "mud")
	var wood: Array = WOOD_OLD if old else WOOD
	var fpart: String = o.get("front_part", "front")
	var rpart: String = o.get("roof_part", "roof")
	var R := s.rng
	var top := F + H
	var zf := D / 2; var zb := -D / 2
	var t := 0.18
	# 기단(돌)
	var bh := maxf(F, 0.18)
	if o.get("floor_hole") is Dictionary and F > 0.4:
		# 숨은 바닥 칸이 있으면 기단을 둘레 돌담으로(마루 밑이 비어 구멍 아래가 보이게) + 안쪽 흙바닥
		var t2 := 0.6
		var ring := [Kit.box(W + 0.7, bh, t2, 0, bh / 2 - 0.02, (D + 0.7 - t2) / 2), Kit.box(W + 0.7, bh, t2, 0, bh / 2 - 0.02, -(D + 0.7 - t2) / 2),
			Kit.box(t2, bh, D + 0.7 - t2 * 2, (W + 0.7 - t2) / 2, bh / 2 - 0.02, 0), Kit.box(t2, bh, D + 0.7 - t2 * 2, -(W + 0.7 - t2) / 2, bh / 2 - 0.02, 0)]
		s.add("base", "stone", C.PA(Kit.merge(ring), STONE, 0.06, R), 0.03)
		s.add("base", "mud", C.PA(Kit.box(W - 0.5, 0.04, D - 0.5, 0, 0.02, 0), [0x3a2e22, 0x2a2018], 0.05, R), 0.0)
		# 마루 귀틀(멍에) — 마루널을 받치는 굵은 나무, 구멍 자리에서도 보인다
		var joists := []
		for k in int(W / 1.6) + 1: joists.append(Kit.box(0.16, 0.18, D - 0.3, -W / 2 + 0.3 + k * (W - 0.6) / int(W / 1.6), F - 0.12, 0))
		s.add("base", "wood", C.PA(Kit.merge(joists), WOOD, 0.03), 0.0)
	else:
		s.add("base", "stone", C.PA(Kit.box(W + 0.7, bh, D + 0.7, 0, bh / 2 - 0.02, 0), STONE, 0.06, R), 0.03)
	if F > 0.5:
		# 높은 마루 밑 바람구멍(곳간·창고 — 마루 밑으로 바람이 통하게)
		var vents := []
		for i in int(W / 1.6):
			vents.append(Kit.box(0.34, minf(0.24, F - 0.25), 0.02, -W / 2 + 0.8 + i * 1.6, F * 0.5, D / 2 + 0.36))
		s.add("base", "flat", C.P(Kit.merge(vents), 0x1e1814), 0.0)
	# 바닥(floor_hole이 있으면 그 자리를 비운다 — 숨은 바닥 칸)
	var floor_k: String = o.get("floor", "wood")
	var fcol: Array = (WOOD_L if not old else [0x8a7558, 0x6a5840]) if floor_k == "wood" else [0x8a7458, 0x6e5c46]
	for rc in floor_rects(W - 0.1, D - 0.1, o.get("floor_hole")):
		s.add("body", "wood" if floor_k == "wood" else "mud", S.SC_indoor(C.PA(Kit.box(rc[2], 0.06, rc[3], rc[0], F + 0.01, rc[1]), fcol, 0.04, R)), 0.0)
	if floor_k == "wood":
		var n := int(W / 0.32)
		var lines := []
		var fh = o.get("floor_hole")
		for i in range(1, n):
			var lx := -W / 2 + i * W / n
			if fh is Dictionary and absf(lx - float(fh.x)) < float(fh.w) / 2:
				var z0 := float(fh.z) - float(fh.d) / 2; var z1 := float(fh.z) + float(fh.d) / 2
				lines.append(Kit.box(0.015, 0.004, z0 + (D - 0.12) / 2, lx, F + 0.043, (z0 - (D - 0.12) / 2) / 2))
				lines.append(Kit.box(0.015, 0.004, (D - 0.12) / 2 - z1, lx, F + 0.043, (z1 + (D - 0.12) / 2) / 2))
			else:
				lines.append(Kit.box(0.015, 0.004, D - 0.12, lx, F + 0.043, 0))
		s.add("body", "flat", S.SC_indoor(C.P(Kit.merge(lines), 0x6e5438)), 0.0)
	# 기둥(네 귀 + 칸마다 앞·뒤)
	var bays: Array = o.get("bays", [{ w = W, kind = "door" }])
	var xs := [-W / 2]
	var acc := -W / 2
	for b in bays:
		acc += float(b.w); xs.append(acc)
	var cols := []
	for x in xs:
		cols.append(Kit.box(0.2, H, 0.2, x, F + H / 2, zf))
		cols.append(Kit.box(0.2, H, 0.2, x, F + H / 2, zb))
	for sx in [-1, 1]: cols.append(Kit.box(0.2, H, 0.2, sx * W / 2, F + H / 2, 0))
	s.add("body", "wood", C.PA(Kit.merge(cols), wood, 0.03), 0.02)
	# 뒷벽(창 구멍)
	var bwin = o.get("back_window")
	if bwin is Dictionary:
		var wx: float = bwin.get("x", 0.0); var ww: float = bwin.get("w", 0.9); var wh: float = bwin.get("h", 0.75); var wy: float = F + float(bwin.get("y", 1.0))
		Co.holed_wall(s.p("body"), -W / 2, W / 2, F, top, wx - ww / 2, wx + ww / 2, wy, wy + wh, zb, t, wall, wkey, R)
		# 창틀
		s.add("body", "wood", C.PA(Kit.merge([Kit.box(ww + 0.16, 0.08, 0.24, wx, wy - 0.04, zb), Kit.box(ww + 0.16, 0.08, 0.24, wx, wy + wh + 0.04, zb),
			Kit.box(0.08, wh, 0.24, wx - ww / 2 - 0.04, wy + wh / 2, zb), Kit.box(0.08, wh, 0.24, wx + ww / 2 + 0.04, wy + wh / 2, zb)]), wood), 0.012)
		# SEALED: 닫힌 창호(안에서 보면 창호지) / OPEN: 바깥(−z)으로 들어 올려 연 창(들창) / BROKEN: 찢긴 창호 + 부러진 살
		var cl := s.st("window", "SEALED", String(bwin.get("default", "SEALED")))
		cl.add("paper", Co.vplane(ww, wh, wx, wy + wh / 2, zb + 0.06, 1.0), 0.0)
		cl.add("wood", C.PA(Kit.merge([Kit.box(ww, 0.04, 0.04, wx, wy + wh * 0.33, zb + 0.07), Kit.box(ww, 0.04, 0.04, wx, wy + wh * 0.66, zb + 0.07), Kit.box(0.04, wh, 0.04, wx, wy + wh / 2, zb + 0.07)]), wood), 0.0)
		var op := s.st("window", "OPEN")
		var pane := Kit.box(ww, wh, 0.05, 0, -wh / 2, 0)
		Kit.apply(pane, Transform3D(Basis(Vector3.RIGHT, 1.1), Vector3(wx, wy + wh, zb - 0.1)))
		op.add("wood", C.PA(pane, WOOD_L), 0.012)
		op.add("wood", C.P(Kit.limb(Vector3(wx + ww * 0.4, wy, zb - 0.12), Vector3(wx + ww * 0.4, wy + wh * 0.9, zb - 0.75), 0.02, 0.02, 4), 0x6b5038), 0.0)
		var br := s.st("window", "BROKEN")
		var shred := Kit.box(ww * 0.45, wh * 0.6, 0.02, wx - ww * 0.22, wy + wh * 0.62, zb + 0.06)
		br.add("paper", shred, 0.0)
		br.add("wood", C.PA(Kit.merge([Kit.xf(Kit.box(0.04, wh * 0.7, 0.04), wx + 0.1, wy + wh * 0.45, zb + 0.07, 0, 0, 0.5), Kit.xf(Kit.box(ww * 0.6, 0.04, 0.04), wx, wy + wh * 0.3, zb + 0.07, 0, 0, -0.3)]), wood), 0.0)
		br.add("flat", pa(Kit.xf(Kit.box(0.3, 0.02, 0.22), wx + 0.2, F + 0.05, zb + 0.5, 0, 0.7, 0), PAPER), 0.0)
		s.anchor("back_window", Vector3(wx, F, zb + 0.7))
		s.anchor("back_window_out", Vector3(wx, 0, zb - 1.0))
	else:
		s.add("body", wkey, C.PA(Kit.box(W, H, t, 0, F + H / 2, zb), wall, 0.04, R), 0.02)
	# 옆벽(옆문)
	var sd: int = int(o.get("side_door", 0))
	for sx in [-1, 1]:
		if sd == sx:
			var g := Kit.Geo.new()
			var old_x: Transform3D = s.m.push(sx * W / 2, 0, 0, -PI / 2 * sx)
			Co.holed_wall(s.p("body"), -D / 2, D / 2, F, top, -0.45, 0.45, F, F + 1.8, 0, t, wall, wkey, R)
			s.m.pop(old_x)
			s.add("body", "wood", C.PA(Kit.box(0.06, 1.75, 0.85, sx * (W / 2 + 0.02), F + 0.88, 0.0), [0x5a4432, 0x3f2f22], 0.04, R), 0.01)
			s.anchor("side_door", Vector3(sx * (W / 2 + 0.9), 0, 0))
		else:
			s.add("body", wkey, C.PA(Kit.box(t, H, D, sx * W / 2, F + H / 2, 0), wall, 0.04, R), 0.02)
	# 앞벽(칸)
	var fp := s.p(fpart)
	var doors := []
	for i in bays.size():
		var b: Dictionary = bays[i]
		var x0: float = xs[i]; var x1: float = xs[i + 1]; var cx := (x0 + x1) / 2; var bw := x1 - x0
		var kind: String = b.get("kind", "wall")
		match kind:
			"door":
				var dw := minf(bw - 0.3, 1.5)
				Co.holed_wall(fp, x0, x1, F, top, cx - dw / 2, cx + dw / 2, F, F + 1.85, zf, t, wall, wkey, R)
				for sgn in [-1, 1]:
					var g := Kit.box(dw / 2, 1.8, 0.05, -sgn * dw / 4, 0, 0)
					Kit.xf(g, cx + sgn * dw / 2, F + 0.92, zf + 0.06, 0, sgn * 1.25, 0)
					fp.add("paper", g, 0.0)
				fp.add("wood", C.PA(Kit.box(dw + 0.1, 0.08, 0.22, cx, F + 1.88, zf), wood), 0.012)
				doors.append(cx)
			"gate", "gate_closed":
				var dw := minf(bw - 0.3, 2.0)
				Co.holed_wall(fp, x0, x1, F, top, cx - dw / 2, cx + dw / 2, F, F + 2.0, zf, t, wall, wkey, R)
				Co.board_doors(fp, cx, F, dw, 2.0, zf - 0.04, kind == "gate", [0x6a5240, 0x4e3c2e] if not old else [0x6a6058, 0x4a443e])
				if kind == "gate": doors.append(cx)
			"shutter":
				# 가게 덧문: 위로 걷어 올린 널판(처마 밑에 매달림) + 문지방 — 칸 전체가 열림
				fp.add("wood", C.PA(Kit.box(bw - 0.1, 0.12, 0.22, cx, F + 0.06, zf), wood), 0.012)
				var g2 := Kit.box(bw - 0.2, 0.9, 0.05, 0, -0.45, 0)
				Kit.apply(g2, Transform3D(Basis(Vector3.RIGHT, -1.25), Vector3(cx, top - 0.05, zf + 0.05)))
				fp.add("wood", C.PA(g2, WOOD_L), 0.012)
				doors.append(cx)
			"window":
				Co.holed_wall(fp, x0, x1, F, top, cx - 0.45, cx + 0.45, F + 0.9, F + 1.6, zf, t, wall, wkey, R)
				Co.paper_panel(fp, cx, F + 1.25, 0.9, 0.7, zf + 0.02)
			"open":
				doors.append(cx)
			_:
				fp.add(wkey, C.PA(Kit.box(bw, H, t, cx, F + H / 2, zf), wall, 0.04, R), 0.02)
	# 도리·창방
	s.add("body", "wood", C.PA(Kit.merge([Kit.box(W + 0.4, 0.2, 0.24, 0, top + 0.08, zb), Kit.box(0.24, 0.2, D + 0.3, -W / 2, top + 0.08, 0), Kit.box(0.24, 0.2, D + 0.3, W / 2, top + 0.08, 0)]), wood), 0.02)
	fp.add("wood", C.PA(Kit.box(W + 0.4, 0.2, 0.24, 0, top + 0.08, zf), wood), 0.02)
	# 앞 댓돌(문마다)
	for x in doors:
		s.add("body", "stone", C.P(Kit.box(1.0, maxf(0.12, F * 0.55), 0.55, x, maxf(0.12, F * 0.55) / 2, zf + 0.62), 0xb8b2a5, 0x8e897f, 0.05, R), 0.02)
	# 지붕
	var roof: String = o.get("roof", "giwa")
	var eave := top + 0.3
	if roof == "giwa":
		var ro := { type = "matbae", hw = W / 2 + 0.9, hd = D / 2 + 1.0, eave = eave, rise = (D / 2 + 1.0) * 0.62, lift = 0.25, thick = 0.22,
			nx = maxi(8, int(W * 1.6)), nz = 8, outline = 0.04, gable_x = W / 2 + 0.05, gable_d = D / 2 + 0.1, gable_y = top + 0.2 }
		Roof.add(s.p(rpart), ro)
		if old:
			# 빠진 기와 자리(어두운 흙 조각)
			for k in 5:
				var x := s.between(-W / 2, W / 2); var z := s.between(-D / 2, D / 2)
				var y := Roof.height(ro, x, z) + 0.02
				s.add(rpart, "mud", C.PA(Kit.xf(Kit.box(0.7, 0.04, 0.5), x, y, z, (0.35 if z > 0 else -0.35), s.r() * 0.5, 0), [0x6a5a44, 0x4a3e30], 0.05), 0.0)
	elif roof == "choga":
		var mm = s.m
		var keep_parts = mm.parts.duplicate()
		CH.thatch_roof(mm, { hump = 0.0 }, W, D, eave - 0.12, "", W / 3, zf, 0.0)
		# thatch_roof는 "roof" 부분에 그린다 → 이름이 다르면 옮긴다
		if rpart != "roof" and mm.parts.has("roof"):
			mm.parts[rpart] = mm.parts["roof"]; mm.parts.erase("roof")
			mm.order[mm.order.find("roof")] = rpart
	# 충돌체: 벽(문 자리 비움)
	var tt := 0.16
	s.box_c(-W / 2 - 0.35, W / 2 + 0.35, zb - 0.35, zb + tt)
	for sx in [-1, 1]:
		if sd == sx:
			s.box_c(minf(sx * W / 2 - tt * sx, sx * (W / 2 + 0.35)), maxf(sx * W / 2 - tt * sx, sx * (W / 2 + 0.35)), zb, -0.5)
			s.box_c(minf(sx * W / 2 - tt * sx, sx * (W / 2 + 0.35)), maxf(sx * W / 2 - tt * sx, sx * (W / 2 + 0.35)), 0.5, zf)
		else:
			s.box_c(minf(sx * W / 2 - tt * sx, sx * (W / 2 + 0.35)), maxf(sx * W / 2 - tt * sx, sx * (W / 2 + 0.35)), zb, zf)
	var ox := -W / 2
	var gaps := []
	for i in bays.size():
		var b: Dictionary = bays[i]
		var x0: float = xs[i]; var x1: float = xs[i + 1]; var cx := (x0 + x1) / 2
		match String(b.get("kind", "wall")):
			"door": gaps.append([cx - minf(x1 - x0 - 0.3, 1.5) / 2 + 0.1, cx + minf(x1 - x0 - 0.3, 1.5) / 2 - 0.1])
			"gate": gaps.append([cx - minf(x1 - x0 - 0.3, 2.0) / 2 + 0.1, cx + minf(x1 - x0 - 0.3, 2.0) / 2 - 0.1])
			"shutter", "open": gaps.append([x0 + 0.15, x1 - 0.15])
	for gp in gaps:
		if gp[0] > ox + 0.05: s.box_c(ox - (0.35 if ox <= -W / 2 + 0.01 else 0.0), gp[0], zf - tt, zf + 0.35)
		ox = gp[1]
	if ox < W / 2 - 0.05: s.box_c(ox, W / 2 + 0.35, zf - tt, zf + 0.35)
	# 실내
	var cam: Dictionary = o.get("camera", { pitch = 54, distance = 11 })
	s.interior = { minX = -W / 2 + 0.15, maxX = W / 2 - 0.15, minZ = zb + 0.15, maxZ = zf - 0.05, floor_y = F, camera = cam }
	s.hide = [fpart, rpart]
	for x in doors: s.anchor("door" if x == doors[0] else "door_%d" % doors.find(x), Vector3(x, 0, zf + 1.2))
	s.anchor("inside", Vector3(0, F, 0))
	if not o.get("no_light", false): s.light(0, F + 1.6, zf + 0.3, "window")
	return { W = W, D = D, F = F, top = top, eave = eave, zf = zf, zb = zb, doors = doors, xs = xs }
