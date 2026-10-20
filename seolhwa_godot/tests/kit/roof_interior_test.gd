# 초가 지붕 틈(벽이 이엉을 뚫지 않나) · 실내 겹친 면(z-fighting) 시험(fix-1021) — 헤드리스, 저장 없음.
#   godot --headless --path . -s res://tests/kit/roof_interior_test.gd [-- --verbose]
#   A 지붕 틈: 초가 몸을 쓰는 키트(초가 一자·ㄱ자·기본, 실내, 낮은 해안 초가, 주막, 이야기 초가 껍데기)를 씨앗·크기·hump 극값마다 지어
#     지붕(part "roof", 먹선 껍질 뺌) 밑면과 벽·기둥·도리·굴뚝(body·front·interior) 꼭짓점·모서리 가운데의 세로 틈을 잰다.
#     - 지붕 밑(세로선이 지붕 면에 닿는 자리): 틈 ≥ CLEAR(먹선 두께 포함 여유) — 음수면 벽이 지붕을 뚫는다
#     - 지붕 밖인데 처마 띠 아래끝보다 높은 꼭짓점 = 지붕 밖으로 삐져나온 벽(0개여야)
#     변형마다 최소 틈(전체 · 벽 둘레 위 · 네 모서리)을 찍는다.
#   B 겹친 면: 실내 키트(초가 실내, 주막, 이야기 껍데기 책방·창고·기록고·역참, 관아 내아·동헌)에서 같은 쪽을 보는 거의 같은 평면
#     (간격 < GAP)의 삼각형이 넓이 > AREA로 겹치고, 그 자리가 다른 면 뒤·닫힌 몸 속에 묻히지 않았으면 z-fighting 자리.
#     온전한 모습과 실내 잘라 보기(interior.hide 숨김) 두 번 본다. 실내 상자가 있으면 그 방 안(둘레 0.3m)만.
#     실제 면끼리 0곳이어야 하고, 먹선 껍질이 닿은 면과 겹치는 곳(물건 접촉선)은 세어 찍기만 한다.
#   끝 줄: ROOFTEST PASS n / ROOFTEST FAIL n
extends SceneTree

const C := preload("res://kit/village/_common.gd")
const CLEAR := 0.03      # 지붕 밑면 - 벽 꼭대기 최소(먹선 껍질 0.02×0.7 + 여유)
const GAP := 0.002       # 같은 쪽을 보는 면 사이가 이보다 가까우면 다툰다(2mm — 깊이 버퍼·그림자 지도·먹 AO가 가르지 못하는 간격)
const AREA := 2e-4       # 겹친 넓이(m²) 이보다 작으면 무시(맞닿은 모서리)
# B는 먹선 껍질도 같이 넣어 찾되(앞 면을 가리는지 보려고) 실패는 실제 면끼리만 — 껍질-면 접촉은 세어 찍기만
var INK: Color

var n := 0
var fails := 0
var verbose := false

func ok(c: bool, what: String) -> void:
	n += 1
	if c:
		if verbose: print("  ok  ", what)
	else:
		fails += 1
		print("  FAIL ", what)

func _initialize() -> void:
	verbose = OS.get_cmdline_user_args().has("--verbose")
	INK = Kit.hex(Kit.INK)
	C.M.keep_parts = true
	_roof_all()
	_faces_all()
	C.M.keep_parts = false
	print("ROOFTEST %s %d" % ["PASS" if fails == 0 else "FAIL", n if fails == 0 else fails])
	quit(0 if fails == 0 else 1)

# ---------------------------------------------------------------------------
# 메시 읽기: part 노드 이름 → { tris: PackedVector3Array(3개씩, 바깥 법선 감김), ink: PackedVector3Array }
# ---------------------------------------------------------------------------
func _parts(node: Node) -> Dictionary:
	var out := {}
	_walk(node, node, out)
	return out

func _walk(root: Node, nd: Node, out: Dictionary) -> void:
	if nd is MeshInstance3D and nd.mesh != null:
		# part 이름 = 메시 바로 위 부분 노드 이름(상태 노드 S_*로 감싼 부분도 제 이름). 한 덩이(merged)면 "all"
		var part := "all" if nd.get_parent() == root else String(nd.get_parent().name)
		# 상태 노드(S_그룹_상태, scenario/_sc.gd) 밑이면 'S_…/부분' — 같은 그룹의 다른 상태끼리는 함께 보이지 않는다
		var hp: Node = nd.get_parent()
		while hp != null and hp != root:
			if String(hp.name).begins_with("S_") and hp != nd.get_parent(): part = String(hp.name) + "/" + part; break
			hp = hp.get_parent()
		var xf := Transform3D.IDENTITY
		var q: Node = nd
		while q != root and q is Node3D:
			xf = (q as Node3D).transform * xf
			q = q.get_parent()
		if not out.has(part): out[part] = { tris = PackedVector3Array(), ink = PackedVector3Array() }
		var am: Mesh = nd.mesh
		for si in am.get_surface_count():
			var arr := am.surface_get_arrays(si)
			var P: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var Cc = arr[Mesh.ARRAY_COLOR]
			var idx = arr[Mesh.ARRAY_INDEX]
			var cnt: int = P.size() if idx == null or (idx as PackedInt32Array).is_empty() else (idx as PackedInt32Array).size()
			for i in range(0, cnt, 3):
				var i0: int = i; var i1: int = i + 1; var i2: int = i + 2
				if idx != null and not (idx as PackedInt32Array).is_empty():
					i0 = idx[i]; i1 = idx[i + 1]; i2 = idx[i + 2]
				# 저장 감김(Godot 시계) → 바깥 법선 감김(three 반시계)으로 되돌린다: a, c, b
				var a: Vector3 = xf * P[i0]; var b: Vector3 = xf * P[i2]; var c: Vector3 = xf * P[i1]
				var is_ink: bool = Cc != null and (Cc as PackedColorArray).size() > i0 and _is_ink((Cc as PackedColorArray)[i0])
				var dst: PackedVector3Array = out[part].ink if is_ink else out[part].tris
				dst.append(a); dst.append(b); dst.append(c)
	for ch in nd.get_children(): _walk(root, ch, out)

func _is_ink(c: Color) -> bool:
	return absf(c.r - INK.r) < 0.006 and absf(c.g - INK.g) < 0.006 and absf(c.b - INK.b) < 0.006

# ---------------------------------------------------------------------------
# A 지붕 틈
# ---------------------------------------------------------------------------
func _roof_all() -> void:
	print("A 지붕 틈 (꼭짓점 세로 틈, m: 최소 · 벽 둘레 위 · 모서리)")
	var sizes := [[6.0, 4.0], [7.2, 4.4], [5.4, 3.6], [6.0, 4.6], [5.0, 3.4]]
	var worst := INF
	var cnt := 0
	for plan in ["", "il", "giyeok"]:
		for sz in sizes:
			for hump in [-0.15, 0.0, 0.15]:
				for inside in [false, true]:
					var seed := 11 + cnt * 7
					cnt += 1
					var p := { seed = seed, w = sz[0], d = sz[1], plan = plan, hump = hump, interior = inside }
					var r := _roof_check(load("res://kit/village/choga.gd").build(p), sz[0], sz[1], 0.4, 1.85, "choga %s" % JSON.stringify(p))
					worst = minf(worst, r)
	# hump 없는 씨앗 여럿(집 묶음·배치 그대로: hump = 씨앗 난수)
	for seed in range(1, 41):
		var p := { seed = seed * 13, w = 6.0, d = 4.0, plan = "il" if seed % 2 == 0 else "", gourd = seed % 3 == 0 }
		worst = minf(worst, _roof_check(load("res://kit/village/choga.gd").build(p), 6.0, 4.0, 0.4, 1.85, "choga seed %s" % JSON.stringify(p)))
	for plan in ["", "il"]:
		for sz in sizes:
			for lod in [0, 1]:
				var p := { seed = 5 + cnt, w = sz[0], d = sz[1], plan = plan, lod = lod }
				cnt += 1
				worst = minf(worst, _roof_check(load("res://kit/village/choga_low.gd").build(p), sz[0], sz[1], 0.3, 1.6, "choga_low %s" % JSON.stringify(p)))
	for seed in range(1, 9):
		var p := { seed = seed * 31, w = 7.2, d = 4.4 }
		worst = minf(worst, _roof_check(load("res://kit/village/jumak.gd").build(p), 7.2, 4.4, 0.4, 1.85, "jumak %s" % JSON.stringify(p)))
	for k in [["scenario/yeokcham", {}], ["scenario/changgo", { style = "empty" }]]:
		var p: Dictionary = (k[1] as Dictionary).duplicate(); p.seed = 7
		worst = minf(worst, _roof_check(load("res://kit/%s.gd" % k[0]).build(p), -1, -1, 0, 0, "%s %s" % [k[0], JSON.stringify(p)]))
	print("  초가 지붕 틈 최소(모든 변형) %.3f m" % worst)

# 반환: 최소 틈. W·D를 주면 벽 둘레·모서리 최소도 찍는다
func _roof_check(res: Dictionary, W: float, D: float, F: float, wallH: float, what: String) -> float:
	var parts := _parts(res.node)
	var roof: PackedVector3Array = PackedVector3Array()
	for pn in parts:
		if String(pn).get_slice("/", String(pn).count("/")).begins_with("roof"): roof.append_array(parts[pn].tris)   # 상태 노드로 감싼 지붕(S_…/roof)도
	if roof.is_empty():
		ok(false, "%s: 지붕 부분 없음" % what); res.node.free(); return INF
	var grid := _tri_grid(roof)
	var ylow := INF   # 처마 띠 아래끝(지붕 가장 낮은 점)
	for v in roof: ylow = minf(ylow, v.y)
	var mins := INF; var mper := INF; var mcor := INF
	var at := Vector3.ZERO
	var outside := 0; var out_at := Vector3.ZERO
	for pn in parts:
		var nm := String(pn)
		if not (nm.get_slice("/", nm.count("/")) in ["body", "front", "interior"]): continue
		var T: PackedVector3Array = parts[pn].tris
		var pts := PackedVector3Array()
		for i in range(0, T.size(), 3):
			pts.append(T[i]); pts.append((T[i] + T[i + 1]) * 0.5)
		for v in pts:
			if v.y < ylow - 0.6: continue
			var h := _roof_low(grid, roof, v.x, v.z)
			if h == INF:
				if v.y > ylow + 0.005: outside += 1; out_at = v
				continue
			var cl := h - v.y
			if cl < mins: mins = cl; at = v
			if W > 0.0:
				var on_per: bool = absf(absf(v.x) - W / 2) < 0.25 or absf(absf(v.z) - D / 2) < 0.4
				if on_per and v.y > F + wallH - 0.3: mper = minf(mper, cl)
				if absf(absf(v.x) - W / 2) < 0.3 and absf(absf(v.z) - D / 2) < 0.45 and v.y > F + wallH - 0.3: mcor = minf(mcor, cl)
	# 지붕 밑면(아래를 보는 면: 처마 밑 비탈·천장)이 이엉 겉(위를 보는 면)을 뚫고 나오지 않나 — 나오면 위에서 밑면 먹선이 보인다
	var up := PackedVector3Array()
	var dn := PackedVector3Array()
	for i in range(0, roof.size(), 3):
		var nn := (roof[i + 1] - roof[i]).cross(roof[i + 2] - roof[i])
		if nn.y > 0.0:
			if nn.length() < 0.06: continue   # 작은 조각(처마 돌·새끼 매듭·박)은 이엉 겉이 아니다(넓이 0.03m² 밑)
			up.append(roof[i]); up.append(roof[i + 1]); up.append(roof[i + 2])
		else: dn.append(roof[i]); dn.append(roof[i + 1]); dn.append(roof[i + 2])
	var ug := _tri_grid(up)
	var y_eave := INF   # 큰 위쪽 면(이엉 겉·처마 띠 바깥)의 가장 낮은 점 ≈ 처마 띠 아래끝 — 밑면은 이 근처(+0.3 안)에만 있다
	for v in up: y_eave = minf(y_eave, v.y)
	var self_min := INF; var self_at := Vector3.ZERO
	for v in dn:
		var hu := _roof_high(ug, up, v.x, v.z)
		if v.y > y_eave + 0.5: continue   # 이엉 겉 위에 얹힌 것(박·잎)의 밑면은 뺀다
		if hu == -INF: continue
		if hu - v.y < self_min: self_min = hu - v.y; self_at = v
	ok(self_min >= -0.002, "%s: 처마 밑면이 이엉 겉 아래(최소 %.3f at (%.2f, %.2f, %.2f))" % [what, self_min, self_at.x, self_at.y, self_at.z])
	ok(mins >= CLEAR, "%s: 지붕 밑 최소 틈 %.3f(≥ %.2f) at (%.2f, %.2f, %.2f)" % [what, mins, CLEAR, at.x, at.y, at.z])
	ok(outside == 0, "%s: 지붕 밖으로 나온 꼭짓점 %d개(처마 아래끝 %.2f 위)%s" % [what, outside, ylow, "" if outside == 0 else " 예 (%.2f, %.2f, %.2f)" % [out_at.x, out_at.y, out_at.z]])
	if verbose or mins < CLEAR: print("    %s  최소 %.3f · 둘레 %.3f · 모서리 %.3f" % [what, mins, mper, mcor])
	res.node.free()
	return mins

# 세로선(x, z)이 지붕 삼각형에 닿는 가장 낮은 y(없으면 INF)
func _roof_low(grid: Dictionary, T: PackedVector3Array, x: float, z: float) -> float:
	var key := Vector2i(floori(x / 0.5), floori(z / 0.5))
	if not grid.has(key): return INF
	var best := INF
	for i in grid[key]:
		var a: Vector3 = T[i]; var b: Vector3 = T[i + 1]; var c: Vector3 = T[i + 2]
		var d := (b.x - a.x) * (c.z - a.z) - (c.x - a.x) * (b.z - a.z)
		if absf(d) < 1e-10: continue
		var u := ((x - a.x) * (c.z - a.z) - (c.x - a.x) * (z - a.z)) / d
		var w := ((b.x - a.x) * (z - a.z) - (x - a.x) * (b.z - a.z)) / d
		if u < -1e-6 or w < -1e-6 or u + w > 1.0 + 1e-6: continue
		best = minf(best, a.y + u * (b.y - a.y) + w * (c.y - a.y))
	return best

func _roof_high(grid: Dictionary, T: PackedVector3Array, x: float, z: float) -> float:
	var key := Vector2i(floori(x / 0.5), floori(z / 0.5))
	if not grid.has(key): return -INF
	var best := -INF
	for i in grid[key]:
		var a: Vector3 = T[i]; var b: Vector3 = T[i + 1]; var c: Vector3 = T[i + 2]
		var d := (b.x - a.x) * (c.z - a.z) - (c.x - a.x) * (b.z - a.z)
		if absf(d) < 1e-10: continue
		var u := ((x - a.x) * (c.z - a.z) - (c.x - a.x) * (z - a.z)) / d
		var w := ((b.x - a.x) * (z - a.z) - (x - a.x) * (b.z - a.z)) / d
		if u < -1e-6 or w < -1e-6 or u + w > 1.0 + 1e-6: continue
		best = maxf(best, a.y + u * (b.y - a.y) + w * (c.y - a.y))
	return best

func _tri_grid(T: PackedVector3Array) -> Dictionary:
	var g := {}
	for i in range(0, T.size(), 3):
		var lo := Vector2(minf(T[i].x, minf(T[i + 1].x, T[i + 2].x)), minf(T[i].z, minf(T[i + 1].z, T[i + 2].z)))
		var hi := Vector2(maxf(T[i].x, maxf(T[i + 1].x, T[i + 2].x)), maxf(T[i].z, maxf(T[i + 1].z, T[i + 2].z)))
		for gx in range(floori(lo.x / 0.5), floori(hi.x / 0.5) + 1):
			for gz in range(floori(lo.y / 0.5), floori(hi.y / 0.5) + 1):
				var k := Vector2i(gx, gz)
				if not g.has(k): g[k] = []
				g[k].append(i)
	return g

# ---------------------------------------------------------------------------
# B 겹친 면(z-fighting)
# ---------------------------------------------------------------------------
func _faces_all() -> void:
	print("B 실내 키트 겹친 면(같은 쪽 · 간격 < %.0fmm · 넓이 > %.0fcm²)" % [GAP * 1000.0, AREA * 1e4])
	var list := []
	for sz in [[6.0, 4.0], [7.2, 4.4], [5.4, 3.6]]:
		for seed in [3, 17, 3171]:
			list.append(["village/choga", { seed = seed, w = sz[0], d = sz[1], interior = true }])
	list.append(["village/choga", { seed = 5, w = 6.0, d = 4.0, plan = "il", interior = true }])
	list.append(["village/choga", { seed = 5, w = 6.0, d = 4.0, plan = "giyeok", interior = true }])
	list.append(["village/jumak", { seed = 9 }])
	for k in ["scenario/chaekbang", "scenario/changgo", "scenario/girokgo", "scenario/yeokcham"]: list.append([k, { seed = 7 }])
	list.append(["scenario/changgo", { seed = 7, style = "empty" }])
	list.append(["landmark/naea", { seed = 1876, wing = true }])
	list.append(["landmark/dongheon", { seed = 1875, bays = 7 }])
	for e in list:
		var res: Dictionary = load("res://kit/%s.gd" % e[0]).build(e[1])
		var parts := _parts(res.node)
		var all := PackedVector3Array()
		var tags := []
		for pn in parts:
			all.append_array(parts[pn].tris); all.append_array(parts[pn].ink)
			for i in parts[pn].tris.size() / 3: tags.append(String(pn))
			for i in parts[pn].ink.size() / 3: tags.append(String(pn) + "/먹선")
		var hits := _coplanar(all, tags)
		# 실내 잘라 보기(지붕·앞 숨김): 숨은 부분을 빼고 다시 — 지붕 밑에 묻혀 있던 벽 꼭대기 같은 곳이 드러난다
		var hide := []
		if res.has("interior"):
			for hn in res.interior.get("hide", []): hide.append(String((hn as Node).name))
		if not hide.is_empty():
			var all2 := PackedVector3Array(); var tags2 := []
			for pn in parts:
				if String(pn) in hide: continue
				all2.append_array(parts[pn].tris); all2.append_array(parts[pn].ink)
				for i in parts[pn].tris.size() / 3: tags2.append(String(pn))
				for i in parts[pn].ink.size() / 3: tags2.append(String(pn) + "/먹선")
			var seen := {}
			for h in hits: seen["%d,%d,%d" % [roundi(h.at.x * 4), roundi(h.at.y * 4), roundi(h.at.z * 4)]] = true
			for h in _coplanar(all2, tags2):
				var sk := "%d,%d,%d" % [roundi(h.at.x * 4), roundi(h.at.y * 4), roundi(h.at.z * 4)]
				if seen.has(sk): continue
				h.ta += "(잘라 보기)"; hits.append(h)
		var what := "%s %s" % [e[0], JSON.stringify(e[1])]
		# 실제 면끼리(같은 면이 두 번 — 벽 겹침·도배 벽·문틀 등)는 0곳이어야. 먹선 껍질(뒤집힌 겉 껍질)이 닿은 면과 겹치는 곳은
		#   물건이 맞닿은 자리의 먹선(접촉선)이라 따로 세기만 한다
		var real_hits := []; var ink_hits := 0
		# 실내 상자가 있는 키트는 그 방(둘레 0.3m 더) 안의 겹침만 — 바깥 계단·기단 같은 집 밖 면은 이 시험의 몫이 아니다
		var box = res.get("interior")
		for h in hits:
			if _other_state(String(h.ta), String(h.tb)): continue
			if h.at.y < 0.0: continue   # 땅속(기단 밑면끼리)
			if String(h.ta).begins_with("roof") and String(h.tb).begins_with("roof"): continue   # 지붕끼리(용마루 끝 등)는 실내 몫이 아님
			if box is Dictionary and (h.at.x < float(box.minX) - 0.3 or h.at.x > float(box.maxX) + 0.3 or h.at.z < float(box.minZ) - 0.3 or h.at.z > float(box.maxZ) + 0.3): continue
			if String(h.ta).contains("먹선") or String(h.tb).contains("먹선"): ink_hits += 1
			else: real_hits.append(h)
		print("    %s: 실제 면 겹침 %d · 먹선 접촉 %d" % [what, real_hits.size(), ink_hits])
		hits = real_hits
		ok(real_hits.is_empty(), "%s: 실제 면 겹침 %d곳" % [what, real_hits.size()])
		if not real_hits.is_empty() or verbose:
			var shown := 0
			for h in hits:
				if shown >= (400 if verbose else 200): print("      … %d곳 더" % (hits.size() - shown)); break
				print("      gap %.4f area %.4f n(%.2f,%.2f,%.2f) at (%.3f, %.3f, %.3f) %s × %s" % [h.gap, h.area, h.n.x, h.n.y, h.n.z, h.at.x, h.at.y, h.at.z, h.ta, h.tb])
				print("        a %s  b %s" % [h.get("ba", ""), h.get("bb", "")])
				shown += 1
		res.node.free()

# 같은 쪽을 보는 거의 같은 평면 삼각형 쌍 중 겹친 넓이가 AREA보다 크고, 겹친 자리가 앞(법선 쪽 COVER 안)에서 다른 면에 가리지 않는 것
#   (벽 속·마루 밑처럼 다른 면 뒤에 묻힌 겹침은 보이지 않으니 뺀다) — 자리별로 묶어 돌려준다
const COVER := 0.05
func _coplanar(T: PackedVector3Array, tags: Array) -> Array:
	var buckets := {}
	var N := []; var Dd := []
	var real := PackedVector3Array()
	for i in range(0, T.size(), 3):
		if not String(tags[i / 3]).ends_with("/먹선"): real.append(T[i]); real.append(T[i + 1]); real.append(T[i + 2])
		var nn := (T[i + 1] - T[i]).cross(T[i + 2] - T[i])
		if nn.length() < 1e-9: N.append(Vector3.ZERO); Dd.append(0.0); continue
		nn = nn.normalized()
		N.append(nn); Dd.append(nn.dot(T[i]))
		var key := Vector3i(roundi(nn.x * 20), roundi(nn.y * 20), roundi(nn.z * 20))
		var kd := floori(nn.dot(T[i]) / GAP)
		var ks := str([key, kd])
		if not buckets.has(ks): buckets[ks] = { key = key, kd = kd, ids = [] }
		buckets[ks].ids.append(i / 3)
	var g3 := _grid3(real)
	var seen := {}
	var hits := []
	for ks in buckets:
		var bk: Dictionary = buckets[ks]
		for dk in [0, 1]:
			var ks2 := str([bk.key, bk.kd + dk])
			if not buckets.has(ks2): continue
			var A: Array = bk.ids; var B: Array = buckets[ks2].ids
			for ia in A:
				for ib in B:
					if dk == 0 and ib <= ia: continue
					var na: Vector3 = N[ia]; var nb: Vector3 = N[ib]
					if na.dot(nb) < 0.9995: continue   # 1.8° 안 — 기울어 엇갈린 면(교차선만 다툼)은 빼고 같은 평면만
					var gap := absf(float(Dd[ia]) - float(Dd[ib]))
					if gap > GAP: continue
					var ov := _overlap(T, ia * 3, ib * 3, na)
					if ov.area <= AREA: continue
					var front := maxf(float(Dd[ia]), float(Dd[ib])) + 0.0005
					var vis := false
					for sp in ov.samples:
						var p0: Vector3 = sp + na * (front - na.dot(sp))
						if not _hidden(g3, real, p0, na):
							vis = true
							if verbose: print("        보이는 표본 (%.3f, %.3f, %.3f)" % [p0.x, p0.y, p0.z])
							break
					if not vis: continue
					var c: Vector3 = ov.samples[0]
					var sk := "%d,%d,%d" % [roundi(c.x * 4), roundi(c.y * 4), roundi(c.z * 4)]
					if seen.has(sk): continue
					seen[sk] = true
					hits.append({ gap = gap, area = ov.area, n = na, at = c, ta = tags[ia], tb = tags[ib], ba = _tbox(T, ia * 3), bb = _tbox(T, ib * 3) })
	return hits

# 같은 상태 그룹의 서로 다른 상태(예: S_window_SEALED · S_window_BROKEN)는 함께 보이지 않는다
func _other_state(a: String, b: String) -> bool:
	if not (a.begins_with("S_") and b.begins_with("S_")): return false
	var sa := a.get_slice("/", 0).split("_"); var sb := b.get_slice("/", 0).split("_")
	return sa.size() > 2 and sb.size() > 2 and sa[1] == sb[1] and a.get_slice("/", 0) != b.get_slice("/", 0)

func _tbox(T: PackedVector3Array, i: int) -> String:
	var lo := T[i].min(T[i + 1]).min(T[i + 2]); var hi := T[i].max(T[i + 1]).max(T[i + 2])
	return "[%.3f..%.3f, %.3f..%.3f, %.3f..%.3f]" % [lo.x, hi.x, lo.y, hi.y, lo.z, hi.z]

# 두 삼각형을 a의 평면에 투영해 겹친 넓이와 겹친 자리 표본(가운데 + 꼭짓점을 가운데 쪽으로 25% 당긴 점, a 평면 위 3D)
func _overlap(T: PackedVector3Array, a: int, b: int, nn: Vector3) -> Dictionary:
	var u := nn.cross(Vector3.UP if absf(nn.y) < 0.9 else Vector3.RIGHT).normalized()
	var v := nn.cross(u)
	var d0 := nn.dot(T[a])
	var pa := PackedVector2Array([Vector2(T[a].dot(u), T[a].dot(v)), Vector2(T[a + 1].dot(u), T[a + 1].dot(v)), Vector2(T[a + 2].dot(u), T[a + 2].dot(v))])
	var pb := PackedVector2Array([Vector2(T[b].dot(u), T[b].dot(v)), Vector2(T[b + 1].dot(u), T[b + 1].dot(v)), Vector2(T[b + 2].dot(u), T[b + 2].dot(v))])
	var r := Geometry2D.intersect_polygons(pa, pb)
	var area := 0.0
	var samples := []
	for poly in r:
		var s := 0.0
		var cen := Vector2.ZERO
		for i in poly.size():
			var p0: Vector2 = poly[i]; var p1: Vector2 = poly[(i + 1) % poly.size()]
			s += p0.x * p1.y - p1.x * p0.y
			cen += p0
		area += absf(s) * 0.5
		if poly.size() == 0: continue
		cen /= poly.size()
		samples.append(u * cen.x + v * cen.y + nn * d0)
		for q in poly:
			var w: Vector2 = cen.lerp(q, 0.75)
			samples.append(u * w.x + v * w.y + nn * d0)
	return { area = area, samples = samples }

# 3D 칸(0.5m)에 삼각형 번호
func _grid3(T: PackedVector3Array) -> Dictionary:
	var g := {}
	for i in range(0, T.size(), 3):
		var lo := T[i].min(T[i + 1]).min(T[i + 2]); var hi := T[i].max(T[i + 1]).max(T[i + 2])
		for gx in range(floori(lo.x / 0.5), floori(hi.x / 0.5) + 1):
			for gy in range(floori(lo.y / 0.5), floori(hi.y / 0.5) + 1):
				for gz in range(floori(lo.z / 0.5), floori(hi.z / 0.5) + 1):
					var k := Vector3i(gx, gy, gz)
					if not g.has(k): g[k] = []
					g[k].append(i)
	return g

# 점 o가 가려졌나: 법선 쪽(d)으로 쏜 첫 면이 COVER 안이면 가려짐(바로 앞에 다른 면), 아니면 닫힌 몸 속인지 본다 —
#   축 방향 여섯 줄마다 줄이 지나는 면의 감김 수(나가는 면 +1, 들어오는 면 −1)를 더해 넷 이상에서 양수면 몸 속
#   (겹친 몸이 여럿이어도 맞고, 열린 껍질 한 장에 속지 않게 다수결)
func _hidden(g: Dictionary, T: PackedVector3Array, o: Vector3, d: Vector3) -> bool:
	var f := _first(g, T, o, d)
	if f.dist <= COVER: return true
	var inside := 0
	for ax in [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.FORWARD, Vector3.BACK]:
		if _winding(g, T, o, ax) > 0: inside += 1
	return inside >= 4

func _winding(g: Dictionary, T: PackedVector3Array, o: Vector3, d: Vector3) -> int:
	var w := 0
	var done := {}
	var t := 0.0
	while t < 30.0:
		var q := o + d * t
		for ox in [-1, 0, 1]:
			for oy in [-1, 0, 1]:
				for oz in [-1, 0, 1]:
					var k := Vector3i(floori(q.x / 0.5) + ox, floori(q.y / 0.5) + oy, floori(q.z / 0.5) + oz)
					if not g.has(k): continue
					for i in g[k]:
						if done.has(i): continue
						done[i] = true
						var r = Geometry3D.segment_intersects_triangle(o, o + d * 30.0, T[i], T[i + 1], T[i + 2])
						if r == null: continue
						w += 1 if (T[i + 1] - T[i]).cross(T[i + 2] - T[i]).dot(d) > 0.0 else -1
		t += 1.0
	return w

# 방향 d로 쏜 첫 면: { dist, n }
func _first(g: Dictionary, T: PackedVector3Array, o: Vector3, d: Vector3) -> Dictionary:
	var best := INF; var bn := Vector3.ZERO
	var done := {}
	var t := 0.0
	while t < 30.0:
		var q := o + d * t
		for ox in [-1, 0, 1]:
			for oy in [-1, 0, 1]:
				for oz in [-1, 0, 1]:
					var k := Vector3i(floori(q.x / 0.5) + ox, floori(q.y / 0.5) + oy, floori(q.z / 0.5) + oz)
					if not g.has(k): continue
					for i in g[k]:
						if done.has(i): continue
						done[i] = true
						var r = Geometry3D.segment_intersects_triangle(o, o + d * 30.0, T[i], T[i + 1], T[i + 2])
						if r == null: continue
						var dist := (r as Vector3).distance_to(o)
						if dist < best:
							best = dist
							bn = (T[i + 1] - T[i]).cross(T[i + 2] - T[i])
		if best < t: break
		t += 0.5
	return { dist = best, n = bn }
