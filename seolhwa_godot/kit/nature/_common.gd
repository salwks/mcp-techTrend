# kit/nature 공용: 웹 three 도형(SphereGeometry·ConeGeometry) 대응, 색 문자열, 결과 사전 만들기.
# preload("res://kit/nature/_common.gd") 로 쓴다(class_name 금지).
extends RefCounted

# '#rrggbb'(sRGB) → 선형 색 (three Color.set과 같음)
static func c(s: String) -> Color:
	return Kit.hex(s.trim_prefix("#").hex_to_int())

# three SphereGeometry(r, ws, hs)와 같은 꼭짓점·UV·감김(극점의 퇴화 삼각형은 뺌)
static func sphere(r: float, ws := 8, hs := 6) -> Kit.Geo:
	var g := Kit.Geo.new()
	var P := []
	var U := []
	for iy in hs + 1:
		var v := float(iy) / hs
		var row := []; var urow := []
		for ix in ws + 1:
			var u := float(ix) / ws
			row.append(Vector3(-r * cos(u * TAU) * sin(v * PI), r * cos(v * PI), r * sin(u * TAU) * sin(v * PI)))
			urow.append(Vector2(u, 1.0 - v))
		P.append(row); U.append(urow)
	for iy in hs:
		for ix in ws:
			var a: Vector3 = P[iy][ix + 1]; var b: Vector3 = P[iy][ix]; var cc: Vector3 = P[iy + 1][ix]; var d: Vector3 = P[iy + 1][ix + 1]
			if iy != 0: g.tri(a, b, d, U[iy][ix + 1], U[iy][ix], U[iy + 1][ix + 1])
			if iy != hs - 1: g.tri(b, cc, d, U[iy][ix], U[iy + 1][ix], U[iy + 1][ix + 1])
	return g

# 원뿔(꼭대기 +h/2, 바닥 -h/2). 퇴화 삼각형 없이 seg개 + 바닥 뚜껑(open=false)
static func cone(r: float, h: float, seg := 4, open := false) -> Kit.Geo:
	var g := Kit.Geo.new()
	var tip := Vector3(0, h / 2, 0)
	for i in seg:
		var a0 := TAU * i / seg; var a1 := TAU * (i + 1) / seg
		var b0 := Vector3(sin(a0) * r, -h / 2, cos(a0) * r); var b1 := Vector3(sin(a1) * r, -h / 2, cos(a1) * r)
		g.tri(b0, b1, tip, Vector2(float(i) / seg, 0), Vector2(float(i + 1) / seg, 0), Vector2((i + 0.5) / seg, 1))
		if not open:
			g.tri(Vector3(0, -h / 2, 0), b1, b0, Vector2(0.5, 0.5), Vector2(0.5, 0.5), Vector2(0.5, 0.5))
	return g

# 납작한 조약돌(사각 쌍뿔, 8삼각형): 반지름 r, 높이 h
static func pebble(r: float, h: float, rng: Kit.Rng) -> Kit.Geo:
	var g := Kit.Geo.new()
	var ring := []
	for i in 5:
		var a := TAU * i / 5 + rng.next() * 0.5
		var k := 0.75 + rng.next() * 0.4
		ring.append(Vector3(sin(a) * r * k, 0, cos(a) * r * k))
	var top := Vector3((rng.next() - 0.5) * r * 0.3, h, (rng.next() - 0.5) * r * 0.3)
	var bot := Vector3(0, -h * 0.25, 0)
	for i in 5:
		var p0: Vector3 = ring[i]; var p1: Vector3 = ring[(i + 1) % 5]
		g.tri(p0, p1, top, Vector2(0, 0), Vector2(1, 0), Vector2(0.5, 1))
		g.tri(p1, p0, bot, Vector2(1, 0), Vector2(0, 0), Vector2(0.5, 0))
	return g

static func pick(arr: Array, rng: Kit.Rng):
	return arr[mini(int(rng.next() * arr.size()), arr.size() - 1)]

# 키트 결과(계약서 §4) + mesh. Batch.mesh()는 한 번만 만든다.
static func result(b: Kit.Batch, name: String, colliders: Array, footprint: Vector2, occluder: bool, extra := {}) -> Dictionary:
	var m := b.mesh()
	var root := Node3D.new()
	root.name = name
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if extra.get("cast", true) else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	var out := { node = root, mesh = m, colliders = colliders, lights = [], occluder = occluder, footprint = footprint, anchors = {}, tris = b.tris }
	for k in extra: if k != "cast": out[k] = extra[k]
	return out

# 뚜껑 없는 가지(Kit.limb와 같은 변환, 위·아래 뚜껑 생략) — 땅속 밑동·잎덩이 속 끝처럼 안 보이는 뚜껑 삼각형을 아낀다
static func limb_open(a: Vector3, b: Vector3, r0: float, r1: float, seg := 6) -> Kit.Geo:
	var d := b - a
	var len := d.length()
	var g := Kit.cyl(r1, r0, len, seg, 0, len / 2, 0, 0, 0, 0, false)
	var dir := d / maxf(len, 1e-6)
	var axis := Vector3.UP.cross(dir)
	var basis := Basis.IDENTITY
	if axis.length() > 1e-6: basis = Basis(axis.normalized(), Vector3.UP.angle_to(dir))
	elif dir.y < 0.0: basis = Basis(Vector3.RIGHT, PI)
	return Kit.apply(g, Transform3D(basis, a))

# 가벼운 덩이: UV구(ws×hs)에 Kit.lump과 같은 잡음 — detail 1 정이십면체(80)보다 싸다(8×4 → 48삼각형)
static func lumpy(r: float, rng: Kit.Rng, rough := 0.2, sy := 1.0, ws := 8, hs := 4) -> Kit.Geo:
	var g := sphere(1.0, ws, hs)
	var sd := rng.next() * 100.0
	for i in g.pos.size():
		var p := g.pos[i]
		var n := Kit.vnoise(p.x * 1.7 + sd, p.z * 1.7 + p.y * 1.3 - sd) * 0.6 + Kit.vnoise(p.x * 3.9 - sd, p.y * 3.1 + sd) * 0.4
		var k := 1.0 + n * rough
		g.pos[i] = Vector3(p.x * r * k, p.y * r * k * sy, p.z * r * k)
	return g
