# 나무 짓기 공용(나무 손질 시험 trees-overhaul, 2026-10-18) — 가지 구조 + 잎 카드.
# preload("res://kit/nature/_tree.gd") 로 쓴다(class_name 금지). 이 칸의 _*.gd라 kit_cache 해시에 들어간다(고치면 캐시가 저절로 새로 지어짐).
#
# 생성기: 외부 생성기(EZ-Tree Godot 이식 MIT · gdTree3D MIT) 대신 직접 짠 절차 생성 — 이유는 보고서 docs/reports/trees-overhaul-trial.md §6.
#   줄기·가지 = 휘어진 다각 관(tube): 마디마다 고리, 고리 사이 면. 끝으로 갈수록 가늘다. 줄기·굵은 가지는 먹선 껍질(Kit.hull).
#   잎 = 카드(알파 자르기 사각판) 송이를 가지 끝에. 법선은 수관 중심(타원체)에서 바깥으로 — 덩이처럼 그늘진다.
#   lod 1(원경 판) = 줄기·굵은 가지(면 적게) + 카메라를 보는 큰 잎 판(빌보드 구름). UV2 = 판 귀퉁이 오프셋(m).
# 재질: 껍질 'bark_wind'(아틀라스 + 바람) · 잎 'foliage'(assets/kit/foliage.png 칸 0 솔잎 · 1 느티 잎 · 2 덤불 · 3 솔잎 덩이).
extends RefCounted
const C := preload("res://kit/nature/_common.gd")

const TILE_PINE := 0
const TILE_ZELKOVA := 1
const TILE_BUSH := 2
const TILE_PINE_FAR := 3
const TILES := 4.0
const GOLDEN := 2.39996

# ---------------------------------------------------------------------------
# 잎 카드 묶음(표면 하나)
# ---------------------------------------------------------------------------
class Leaves:
	var P := PackedVector3Array()
	var N := PackedVector3Array()
	var U := PackedVector2Array()
	var U2 := PackedVector2Array()
	var Cc := PackedColorArray()
	var tris := 0

	# 고정 방향 카드: 가운데 c, 가로 a·세로 b(반 길이 벡터), 칸 tile
	func card(c: Vector3, a: Vector3, b: Vector3, tile: int, nrm: Array, col: Array) -> void:
		var q := [c - a + b, c + a + b, c + a - b, c - a - b]
		_quad(q, [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO], tile, nrm, col)

	# 카메라를 보는 판: 꼭짓점은 모두 c, UV2에 귀퉁이 오프셋(셰이더가 카메라 쪽으로 편다)
	func billboard(c: Vector3, hw: float, hh: float, tile: int, nrm: Vector3, col: Color) -> void:
		_quad([c, c, c, c], [Vector2(-hw, hh), Vector2(hw, hh), Vector2(hw, -hh), Vector2(-hw, -hh)], tile, [nrm, nrm, nrm, nrm], [col, col, col, col])

	func _quad(q: Array, o: Array, tile: int, nrm: Array, col: Array) -> void:
		var u0 := (tile + 0.004) / TILES; var u1 := (tile + 0.996) / TILES
		var uv := [Vector2(u0, 0.004), Vector2(u1, 0.004), Vector2(u1, 0.996), Vector2(u0, 0.996)]
		for k in [0, 1, 2, 0, 2, 3]:
			P.append(q[k]); U.append(uv[k]); U2.append(o[k]); N.append(nrm[k]); Cc.append(col[k])
		tris += 2

	func is_empty() -> bool: return P.is_empty()

	func arrays() -> Array:
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = P; arr[Mesh.ARRAY_NORMAL] = N; arr[Mesh.ARRAY_TEX_UV] = U; arr[Mesh.ARRAY_TEX_UV2] = U2; arr[Mesh.ARRAY_COLOR] = Cc
		return arr

# ---------------------------------------------------------------------------
# 가지(관)
# ---------------------------------------------------------------------------
# 점 목록 pts, 마디 반지름 rad → 관(Kit.Geo, 반시계 앞면, UV v = 길이 비율). 끝 뚜껑 없음
static func tube(pts: Array, rad: Array, seg: int) -> Kit.Geo:
	var g := Kit.Geo.new()
	var n := pts.size()
	var rings := []
	var X := Vector3.ZERO
	var acc := [0.0]
	for i in range(1, n): acc.append(acc[i - 1] + (pts[i] as Vector3).distance_to(pts[i - 1]))
	var total: float = maxf(acc[n - 1], 1e-4)
	for i in n:
		var T: Vector3 = ((pts[mini(i + 1, n - 1)] as Vector3) - (pts[maxi(i - 1, 0)] as Vector3)).normalized()
		if i == 0:
			X = (Vector3.RIGHT if absf(T.x) < 0.9 else Vector3.FORWARD).cross(T).normalized()
		else:
			X = (X - T * X.dot(T)).normalized()   # 평행 이동(비틀림 없게)
		var Z := X.cross(T)
		var ring := []
		for j in seg + 1:
			var a := TAU * j / seg
			ring.append((pts[i] as Vector3) + (X * sin(a) + Z * cos(a)) * float(rad[i]))
		rings.append(ring)
	for i in n - 1:
		var v0: float = acc[i] / total; var v1: float = acc[i + 1] / total
		for j in seg:
			var u0 := float(j) / seg; var u1 := float(j + 1) / seg
			g.quad(rings[i][j], rings[i][j + 1], rings[i + 1][j + 1], rings[i + 1][j], Vector2(u0, v0), Vector2(u1, v0), Vector2(u1, v1), Vector2(u0, v1))
	return g

# 휘며 자라는 선: 시작 p, 방향 d, 길이 L, 마디 n, 굽음 gnarl, 위로 굽는 정도 up0(시작)→up1(끝)
static func grow(p: Vector3, d: Vector3, L: float, n: int, gnarl: float, up0: float, up1: float, r: Kit.Rng) -> Array:
	var pts := [p]
	var dir := d.normalized()
	for i in n:
		var t := float(i) / maxf(1.0, n - 1)
		var rnd := Vector3(r.next() - 0.5, (r.next() - 0.5) * 0.5, r.next() - 0.5)
		dir = (dir + rnd * gnarl + Vector3.UP * lerpf(up0, up1, t)).normalized()
		p = p + dir * (L / n)
		pts.append(p)
	return pts

# 선 위 t(0~1) 자리의 [위치, 방향, 마디 번호]
static func at(pts: Array, t: float) -> Array:
	var n := pts.size() - 1
	var f := clampf(t, 0.0, 1.0) * n
	var i := mini(int(f), n - 1)
	var a: Vector3 = pts[i]; var b: Vector3 = pts[i + 1]
	return [a.lerp(b, f - i), (b - a).normalized(), i]

# 방향 T에서 θ만큼 벌어지고 방위 φ로 돈 방향
static func spread_dir(T: Vector3, theta: float, phi: float) -> Vector3:
	var X := (Vector3.UP if absf(T.y) < 0.95 else Vector3.RIGHT).cross(T).normalized()
	var Z := T.cross(X)
	return (T * cos(theta) + (X * cos(phi) + Z * sin(phi)) * sin(theta)).normalized()

static func radii(n: int, r0: float, r1: float, pw := 1.0) -> Array:
	var out := []
	for i in n: out.append(lerpf(r0, r1, pow(float(i) / maxf(1.0, n - 1), pw)))
	return out

# 껍질 하나 더하기(바람 껍질, 먹선 ol)
static func bark(b: Kit.Batch, pts: Array, rad: Array, seg: int, cols: Array, r: Kit.Rng, ol: float) -> void:
	b.add("wbark", Kit.paint(tube(pts, rad, seg), C.c(cols[0]), C.c(cols[1]), 0.05, r), ol)

# ---------------------------------------------------------------------------
# 잎 송이
# ---------------------------------------------------------------------------
# 수관 둥근 법선: 수관 중심 cc·반지름 ext 타원체 기준 바깥 + 송이 중심 기준 바깥 조금 + 위로 조금
static func crown_normal(v: Vector3, cc: Vector3, ext: Vector3, pc: Vector3) -> Vector3:
	var a := ((v - cc) / ext).normalized()
	var b := (v - pc).normalized()
	return (a * 0.7 + b * 0.3 + Vector3.UP * 0.15).normalized()

static func leaf_col(n: Vector3, light: Color, dark: Color, j: float) -> Color:
	var t := clampf(0.5 + 0.45 * n.y + j, 0.0, 1.0)
	return dark.lerp(light, t)

# 고정 카드 송이: 가운데 pc, 반지름 pr, 납작함 flat(세로 배율), 카드 수 n, 카드 반 크기 hs, 위 향함 up_bias
static func cluster(L: Leaves, pc: Vector3, pr: float, flat: float, n: int, hs: float, up_bias: float, tile: int,
		cc: Vector3, ext: Vector3, light: Color, dark: Color, r: Kit.Rng, vert_every := 3) -> void:
	for k in n:
		var off := Vector3(r.next() - 0.5, (r.next() - 0.5) * flat, r.next() - 0.5) * pr * 1.1
		var c := pc + off
		var nr := Vector3(r.next() - 0.5, r.next() - 0.5, r.next() - 0.5).normalized()
		if vert_every > 0 and k % vert_every == vert_every - 1: nr = (Vector3(nr.x, 0.0, nr.z).normalized() + Vector3.UP * 0.25).normalized()   # 몇 장에 하나는 세운 카드(옆에서도 보이게)
		else: nr = (nr + Vector3.UP * up_bias).normalized()
		var a0 := (Vector3.UP if absf(nr.y) < 0.9 else Vector3.RIGHT).cross(nr).normalized()
		var rot := r.next() * TAU
		var a := (a0 * cos(rot) + nr.cross(a0) * sin(rot)) * hs * (0.85 + r.next() * 0.3)
		var bb := nr.cross(a.normalized()) * a.length()
		# 카드 '위'(그림 위쪽)는 되도록 하늘 쪽
		if bb.y < 0.0: bb = -bb
		var q := [c - a + bb, c + a + bb, c + a - bb, c - a - bb]
		var ns := []; var cs := []
		var j := (r.next() - 0.5) * 0.12
		for v in q:
			var nn := crown_normal(v, cc, ext, pc)
			ns.append(nn); cs.append(leaf_col(nn, light, dark, j))
		L.card(c, a, bb, tile, ns, cs)

# ---------------------------------------------------------------------------
# 결과(계약서 §4): 껍질(Batch) + 잎 표면
# ---------------------------------------------------------------------------
static func result(b: Kit.Batch, L: Leaves, name: String, colliders: Array, footprint: Vector2, occluder: bool, extra := {}) -> Dictionary:
	var m := b.mesh() if not b.is_empty() else ArrayMesh.new()
	if not L.is_empty():
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, L.arrays())
		m.surface_set_material(m.get_surface_count() - 1, Kit.material("foliage"))
	var root := Node3D.new()
	root.name = name
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if extra.get("cast", true) else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	var out := { node = root, mesh = m, colliders = colliders, lights = [], occluder = occluder, footprint = footprint, anchors = {}, tris = b.tris + L.tris }
	for k in extra: if k != "cast": out[k] = extra[k]
	return out

# ---------------------------------------------------------------------------
# 소나무(적송): 휘고 기운 붉은 줄기, 아래 절반은 맨 줄기, 위에서 가지가 돌아가며 나와 끝이 위로 들린다.
# 가지 끝마다 납작한 솔잎 송이(층층이 우산 — 민화 소나무 모양은 지키되 덩어리판 대신 솔잎 다발 카드).
# ---------------------------------------------------------------------------
const PINE_LEAF := [["#8a9d64", "#2f3e2b"], ["#7e9560", "#2b3a29"], ["#93a06a", "#36452f"]]
const PINE_BARK := ["#bf7a4e", "#6e4632"]
const PINE_BARK_UP := ["#c98656", "#8a5a3e"]

static func pine(params: Dictionary) -> Dictionary:
	var r := Kit.Rng.new(int(params.get("seed", 1)))
	var s := float(params.get("s", 1.0))
	var lod := int(params.get("lod", 0))
	var b := Kit.Batch.new()
	var L := Leaves.new()
	var H := (5.4 + r.next() * 3.0) * s
	var lean_a := r.next() * TAU
	var lean_d := Vector3(cos(lean_a), 0, sin(lean_a))
	var perp := Vector3(-lean_d.z, 0, lean_d.x)
	var lean := (0.04 + r.next() * 0.12) * H
	var wob := (0.15 + r.next() * 0.3) * s
	var ph := r.next() * TAU
	var nt := 4 if lod else 7
	var tp := []
	for i in nt + 1:
		var t := float(i) / nt
		var off := lean_d * (lean * t * t + sin(t * PI * 1.4 + ph) * wob) + perp * sin(t * PI * 2.2 + ph * 1.7) * wob * 0.6
		tp.append(Vector3(off.x, t * H - 0.3, off.z))
	var tr := 0.25 * s
	var trad := []
	for i in nt + 1:
		var t := float(i) / nt
		trad.append(lerpf(tr * (1.25 if i == 0 else 1.0), 0.05 * s, pow(t, 0.85)))
	# 아래 줄기는 짙고 거칠게, 위 줄기는 밝은 주황(적송) — 두 토막으로 칠한다
	var cut := int(nt * 0.55)
	bark(b, tp.slice(0, cut + 1), trad.slice(0, cut + 1), 5 if lod else 7, PINE_BARK, r, 0.0 if lod else 0.022 * s)
	bark(b, tp.slice(cut), trad.slice(cut), 4 if lod else 6, PINE_BARK_UP, r, 0.0 if lod else 0.018 * s)
	var col: Array = C.pick(PINE_LEAF, r)
	var light := C.c(col[0]); var dark := C.c(col[1])
	# 가지: 줄기 위쪽 0.48~0.93에서 돌아가며
	var nb := 5 if lod else (7 + int(r.next() * 3))
	var pads := []   # [가운데, 반지름]
	var top: Vector3 = tp[nt]
	pads.append([top + Vector3(0, 0.1 * s, 0), (1.2 + r.next() * 0.35) * s])
	var az := r.next() * TAU
	for i in nb:
		var t := lerpf(0.46, 0.9, (float(i) + r.next() * 0.6) / nb)
		var A := at(tp, t)
		az += GOLDEN + (r.next() - 0.5) * 0.6
		var el := lerpf(0.05, 0.6, (t - 0.46) / 0.44) + (r.next() - 0.5) * 0.25   # 아래 가지는 거의 수평, 위는 비스듬히 위로
		var d := Vector3(cos(az) * cos(el), sin(el), sin(az) * cos(el))
		var len := (1.7 + r.next() * 1.4) * s * lerpf(1.15, 0.55, (t - 0.5) / 0.43)
		var bp := grow(A[0], d, len, 2 if lod else 4, 0.35, -0.08, 0.32, r)
		var r0: float = lerpf(trad[A[2]], trad[mini(A[2] + 1, nt)], 0.5) * 0.55
		if lod == 0 or i < 5:
			bark(b, bp, radii(bp.size(), r0, 0.03 * s), 3 if lod else 5, PINE_BARK_UP, r, 0.0 if lod else 0.012 * s)
		var tip: Vector3 = bp[bp.size() - 1]
		pads.append([tip + Vector3(0, 0.12 * s, 0), (0.85 + r.next() * 0.35) * s * lerpf(1.1, 0.85, (t - 0.5) / 0.43)])
		if lod == 0:
			# 가지 가운데에도 솔잎 송이(밑에서 올려다볼 때 맨 가지가 길게 드러나지 않게)
			if len > 1.6 * s: pads.append([(at(bp, 0.55)[0] as Vector3) + Vector3(0, 0.1 * s, 0), (0.55 + r.next() * 0.2) * s])
			# 잔가지 1~2 + 작은 솔잎 송이
			for k in 1 + int(r.next() * 2):
				var B := at(bp, 0.5 + r.next() * 0.4)
				var dd := spread_dir(B[1], 0.6 + r.next() * 0.35, r.next() * TAU)
				dd = (dd + Vector3.UP * 0.35).normalized()
				var tw := grow(B[0], (dd + Vector3(dd.x, 0.0, dd.z)).normalized(), (0.55 + r.next() * 0.4) * s, 2, 0.3, 0.0, 0.25, r)
				bark(b, tw, radii(tw.size(), 0.035 * s, 0.015 * s), 3, PINE_BARK_UP, r, 0.0)
				pads.append([(tw[tw.size() - 1] as Vector3) + Vector3(0, 0.08 * s, 0), (0.5 + r.next() * 0.25) * s])
	# 수관 중심·크기(둥근 법선 기준)
	var lo := Vector3(INF, INF, INF); var hi := -lo
	for pd in pads:
		var pc: Vector3 = pd[0]; var pr: float = pd[1]
		lo = Vector3(minf(lo.x, pc.x - pr), minf(lo.y, pc.y - pr * 0.4), minf(lo.z, pc.z - pr)); hi = Vector3(maxf(hi.x, pc.x + pr), maxf(hi.y, pc.y + pr * 0.4), maxf(hi.z, pc.z + pr))
	var cc := (lo + hi) * 0.5
	var ext := ((hi - lo) * 0.5).max(Vector3(0.5, 0.5, 0.5))
	for pd in pads:
		var pc: Vector3 = pd[0]; var pr: float = pd[1]
		if lod:
			var nn := crown_normal(pc + Vector3(0, pr * 0.2, 0), cc, ext, pc - Vector3(0, pr, 0))
			L.billboard(pc, pr * 1.35, pr * 0.95, TILE_PINE_FAR, nn, leaf_col(nn, light, dark, (r.next() - 0.5) * 0.1))
		else:
			cluster(L, pc, pr, 0.22, clampi(int(pr * pr * 3.0 / (s * s)) + 2, 3, 5), pr * 1.25, 2.2, TILE_PINE, cc, ext, light, dark, r, 4)
	var ex := maxf(maxf(absf(lo.x), absf(hi.x)), maxf(absf(lo.z), absf(hi.z)))
	return result(b, L, "소나무", [{ type = "circle", x = 0.0, z = 0.0, r = 0.3 * s }], Vector2(ex * 2, ex * 2), true, { height = hi.y })

# ---------------------------------------------------------------------------
# 느티나무(마을 어귀 정자나무): 짧고 굵은 줄기가 낮게 여러 갈래로 갈라져 비스듬히 위·바깥으로 퍼지고(부채꼴),
# 갈래가 다시 두세 번 갈라진다. 넓은 둥근 지붕 수관. 잎은 작은 톱니 잎송이 카드.
# o: h(7.2), spread(4.6), trunk(0.55), branches(5), leaf[[밝은, 짙은]…], seed, lod, bare
# ---------------------------------------------------------------------------
const ZEL_BARK := ["#7a6a56", "#4a3e32"]

static func zelkova(o: Dictionary) -> Dictionary:
	var r := Kit.Rng.new(int(o.get("seed", 1)))
	var lod := int(o.get("lod", 0))
	var hgt := float(o.get("h", 7.2)); var spread := float(o.get("spread", 4.6)); var tr := float(o.get("trunk", 0.55))
	var ks := spread / 4.6
	var b := Kit.Batch.new()
	var L := Leaves.new()
	var ol := 0.0 if lod else 1.0
	# 줄기: 밑동 퍼짐 + 살짝 굽은 줄기 → 갈래 자리
	var fork_y := hgt * (0.3 + r.next() * 0.06)
	var lean := Vector3(r.next() - 0.5, 0, r.next() - 0.5) * 0.5
	var tp := [Vector3(0, -0.25, 0)]
	var nt := 2 if lod else 4
	for i in range(1, nt + 1):
		var t := float(i) / nt
		tp.append(Vector3(lean.x * t * t + sin(t * 2.6) * 0.08, t * fork_y, lean.z * t * t))
	var trad := []
	for i in nt + 1: trad.append(lerpf(tr * 1.1, tr * 0.82, float(i) / nt))
	bark(b, tp, trad, 6 if lod else 9, ZEL_BARK, r, 0.03 * ol)
	if not lod:
		# 뿌리 퍼짐(밑동 판근 느낌): 짧은 원뿔대 + 굵은 뿌리 넷
		b.add("wbark", Kit.paint(Kit.cyl(tr * 0.95, tr * 1.55, 0.6, 9, 0, 0.0, 0), C.c("#5e5040"), C.c("#44392e"), 0.05, r), 0.03)
		for k in 4:
			var a := TAU * k / 4 + r.next() * 0.8
			var rp := [Vector3(cos(a) * tr * 0.5, 0.35, sin(a) * tr * 0.5), Vector3(cos(a) * tr * 1.5, 0.02, sin(a) * tr * 1.5), Vector3(cos(a) * tr * 2.3, -0.2, sin(a) * tr * 2.3)]
			bark(b, rp, [tr * 0.38, tr * 0.24, tr * 0.08], 5, ZEL_BARK, r, 0.0)
	var fork: Vector3 = tp[nt]
	var leaf: Array = o.get("leaf", [["#a2ab66", "#56623a"]])
	var tips := []   # 잎송이 [가운데, 반지름]
	var groups := []  # 원경 판: 큰 갈래마다 송이 모음
	var nb := int(o.get("branches", 5))
	if lod: nb = mini(nb, 4)
	var az := r.next() * TAU
	for i in nb:
		az += TAU / nb + (r.next() - 0.5) * 0.5
		var th := 0.82 + r.next() * 0.2   # 수직에서 45~63° — 넓게 퍼지는 부채꼴
		var d := spread_dir(Vector3.UP, th, az)
		var len1 := hgt * (0.5 + r.next() * 0.08) * lerpf(1.0, ks, 0.5)
		var p1 := grow(fork + Vector3(cos(az), 0, sin(az)) * tr * 0.3, d, len1, 2 if lod else 4, 0.22, 0.04, 0.12, r)
		bark(b, p1, radii(p1.size(), tr * 0.62, tr * 0.3), 4 if lod else 7, ZEL_BARK, r, 0.024 * ol)
		var grp := []
		var n2 := 3
		for j in n2:
			var t := 0.55 + 0.45 * float(j + 1) / n2
			var A := at(p1, t)
			var d2 := spread_dir(A[1], 0.4 + r.next() * 0.4, az + (r.next() - 0.5) * 2.2)
			var len2 := len1 * (0.5 + r.next() * 0.2)
			var p2 := grow(A[0], d2, len2, 2 if lod else 3, 0.3, 0.0, 0.08, r)
			bark(b, p2, radii(p2.size(), tr * 0.3, tr * 0.12), 3 if lod else 5, ZEL_BARK, r, 0.0)
			if lod:
				grp.append(p2[p2.size() - 1])
				continue
			for k in 2:
				var B := at(p2, 0.55 + r.next() * 0.45)
				var d3 := spread_dir(B[1], 0.4 + r.next() * 0.4, r.next() * TAU)
				var p3 := grow(B[0], (d3 + Vector3(d3.x, 0.0, d3.z) * 0.4).normalized(), len2 * (0.45 + r.next() * 0.2), 2, 0.3, 0.0, 0.1, r)
				bark(b, p3, radii(p3.size(), tr * 0.11, tr * 0.04), 3, ZEL_BARK, r, 0.0)
				tips.append([p3[p3.size() - 1], (1.05 + r.next() * 0.35) * lerpf(1.0, ks, 0.5)])
			# 갈래 가운데에도 송이(수관 속이 비지 않게)
			var mid: Vector3 = at(p2, 0.5)[0]
			tips.append([mid + Vector3(0, 0.25, 0), 0.9 * lerpf(1.0, ks, 0.5)])
		if lod: groups.append(grp)
	var cols := [{ type = "circle", x = 0.0, z = 0.0, r = tr + 0.15 }]
	var fp := Vector2(spread * 2.2, spread * 2.0)
	if bool(o.get("bare", false)):
		return result(b, L, "느티나무", cols, fp, true, { height = hgt })
	var pts := []
	if lod:
		for g in groups:
			for p in g: pts.append(p)
	else:
		for t in tips: pts.append(t[0])
	var lo := Vector3(INF, INF, INF); var hi := -lo
	for p in pts:
		lo = Vector3(minf(lo.x, p.x), minf(lo.y, p.y), minf(lo.z, p.z)); hi = Vector3(maxf(hi.x, p.x), maxf(hi.y, p.y), maxf(hi.z, p.z))
	lo -= Vector3(1.2, 1.0, 1.2); hi += Vector3(1.2, 1.0, 1.2)
	var cc := (lo + hi) * 0.5
	var ext := ((hi - lo) * 0.5).max(Vector3(0.8, 0.8, 0.8))
	var lc: Array = C.pick(leaf, r)
	var light := C.c(lc[0]); var dark := C.c(lc[1])
	if lod:
		for p in pts:
			var pc: Vector3 = p + Vector3(0, 0.2, 0)
			var pr := (1.5 + r.next() * 0.4) * lerpf(1.0, ks, 0.5)
			var nn := crown_normal(pc + Vector3(0, pr * 0.3, 0), cc, ext, pc)
			L.billboard(pc, pr * 1.2, pr * 1.0, TILE_ZELKOVA, nn, leaf_col(nn, light, dark, (r.next() - 0.5) * 0.1))
	else:
		for t in tips:
			cluster(L, t[0], t[1], 0.75, 4, t[1] * 1.25, 0.5, TILE_ZELKOVA, cc, ext, light, dark, r)
	return result(b, L, "느티나무", cols, fp, true, { height = hi.y })

# ---------------------------------------------------------------------------
# 덤불: 둥근 잎덩이 2~3개를 잎 카드 송이로(윗면 납작 없음). 꽃(진달래 등)은 작은 공 그대로(아틀라스 표면)
# ---------------------------------------------------------------------------
static func bush(params: Dictionary, col: Array, flowers: bool) -> Dictionary:
	var r := Kit.Rng.new(int(params.get("seed", 1)) * 31 + 7)
	var s := float(params.get("s", 1.0))
	var b := Kit.Batch.new()
	var L := Leaves.new()
	var light := C.c(col[0]); var dark := C.c(col[1])
	var n := 2 + int(r.next() * 2)
	var lobes := []
	for i in n:
		var rad := (0.42 + r.next() * 0.22) * s
		var c := Vector3((r.next() - 0.5) * 0.8 * s, rad * 0.75, (r.next() - 0.5) * 0.55 * s)
		lobes.append([c, rad])
	var cc := Vector3(0, 0.35 * s, 0)
	var ext := Vector3(0.85, 0.55, 0.7) * s
	for lb in lobes:
		cluster(L, lb[0], lb[1], 0.9, 4, lb[1] * 1.05, 0.35, TILE_BUSH, cc, ext, light, dark, r)
	if flowers:
		for i in 5:
			var g := C.sphere(0.09 * s, 5, 3)
			Kit.xf(g, (r.next() - 0.5) * 0.9 * s, (0.45 + r.next() * 0.25) * s, (r.next() - 0.5) * 0.6 * s)
			b.add("organic", Kit.paint(g, C.c("#e79ab2"), C.c("#c97890"), 0.05, r), 0.0)
	return result(b, L, "덤불", [], Vector2(1.6 * s, 1.2 * s), false)
