# 모델링 공용 도구 — 웹 src/world/util.js + materials.js 이식.
# 모든 건물·소품·식생은 이 도구로 만든다: 낮은 폴리곤 + 버텍스 색 그라데이션 + 붓 텍스처 아틀라스 + 먹선(뒤집은 헐).
#
# 좌표 규칙은 three.js와 같다(웹 코드를 옮기기 쉽게): 삼각형은 반시계(CCW)가 앞면, UV의 v는 위가 1.
# Kit.build()가 Godot 규칙(시계 방향 앞면, v 아래가 1)으로 바꾼다.
#
# 쓰는 법:
#   var b := Kit.Batch.new()
#   b.add("thatch", Kit.paint(Kit.box(4, 1, 3, 0, 2, 0), Kit.hex(0xd8c79a), Kit.hex(0xb59a68)))
#   var node := b.build("초가")          # MeshInstance3D 묶음(Node3D)
class_name Kit
extends RefCounted

const ATLAS_W := 1024.0
const ATLAS_H := 512.0
const REG := {
	lattice = [0, 0, 128, 128], thatch = [128, 0, 384, 128], tile = [384, 0, 512, 128], makse = [512, 0, 640, 128],
	rock = [640, 0, 896, 128], mud = [896, 0, 1024, 128],
	needle = [0, 128, 256, 256], leaf = [256, 128, 512, 256], bark = [512, 128, 640, 256],
	face0 = [640, 128, 704, 384], face1 = [704, 128, 768, 384], white = [768, 128, 896, 256], lamp = [896, 128, 1024, 256],
	wood = [0, 256, 256, 384], stone = [256, 256, 512, 384], cloth = [512, 256, 640, 384],
}
# 재질 키 → 아틀라스 영역 (웹 KEY_REG와 같음)
const KEY_REG := {
	flat = "white", smooth = "white", organic = "white", onggi = "white", cloth = "white",
	paper = "lattice", thatch = "thatch", tile = "tile", makse = "makse", rock = "rock", mud = "mud",
	needle = "needle", leaf = "leaf", bark = "bark", face0 = "face0", face1 = "face1", lamp = "lamp", glow = "lamp",
	wood = "wood", stone = "stone",
}
# 각진 음영(면 법선)을 쓰는 인공물. 나머지는 부드러운 법선(붓 번짐 느낌)
const FACETED := ["flat", "wood", "mud", "paper", "tile", "makse", "stone"]
const INK := 0x2b2622
const OUTLINE_SCALE := 0.7
const ASSETS := "res://assets/kit/"

# ---------------------------------------------------------------------------
# Geo: 비인덱스 삼각형 목록(three의 prep된 BufferGeometry에 해당)
# ---------------------------------------------------------------------------
class Geo:
	var pos := PackedVector3Array()
	var uv := PackedVector2Array()
	var col := PackedColorArray()   # 선형(linear) 색
	var nrm := PackedVector3Array() # build 때 채움

	func tri(a: Vector3, b: Vector3, c: Vector3, ua := Vector2.ZERO, ub := Vector2.ZERO, uc := Vector2.ZERO) -> void:
		pos.append(a); pos.append(b); pos.append(c)
		uv.append(ua); uv.append(ub); uv.append(uc)
		col.append(Color.WHITE); col.append(Color.WHITE); col.append(Color.WHITE)

	# 사각형 a-b-c-d (반시계)
	func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, ua := Vector2(0, 0), ub := Vector2(1, 0), uc := Vector2(1, 1), ud := Vector2(0, 1)) -> void:
		tri(a, b, c, ua, ub, uc)
		tri(a, c, d, ua, uc, ud)

	func copy() -> Geo:
		var g := Geo.new()
		g.pos = pos.duplicate(); g.uv = uv.duplicate(); g.col = col.duplicate(); g.nrm = nrm.duplicate()
		return g

	func size() -> int:
		return pos.size()

	func aabb() -> AABB:
		if pos.is_empty(): return AABB()
		var b := AABB(pos[0], Vector3.ZERO)
		for p in pos: b = b.expand(p)
		return b

# ---------------------------------------------------------------------------
# 수학·잡음 (웹 util.js와 같은 값이 나오게)
# ---------------------------------------------------------------------------
static func hash2(x: float, z: float) -> float:
	var h := sin(x * 127.1 + z * 311.7) * 43758.5453123
	return h - floorf(h)

static func vnoise(x: float, z: float) -> float:
	var xi := floorf(x); var zi := floorf(z)
	var xf := x - xi; var zf := z - zi
	var u := xf * xf * (3.0 - 2.0 * xf); var v := zf * zf * (3.0 - 2.0 * zf)
	var a := hash2(xi, zi); var b := hash2(xi + 1, zi); var c := hash2(xi, zi + 1); var d := hash2(xi + 1, zi + 1)
	return lerpf(lerpf(a, b, u), lerpf(c, d, u), v) * 2.0 - 1.0

static func fbm(x: float, z: float, oct := 4) -> float:
	var s := 0.0; var a := 0.5; var f := 1.0
	for i in oct:
		s += a * vnoise(x * f + i * 17.3, z * f - i * 9.1); f *= 2.03; a *= 0.5
	return s

# 시드 고정 난수(웹 rng의 mulberry32와 같은 수열)
class Rng:
	var t: int
	func _init(seed: int) -> void: t = seed & 0xffffffff
	func next() -> float:
		t = (t + 0x6d2b79f5) & 0xffffffff
		var r := _imul(t ^ (t >> 15), 1 | t)
		r = ((r + _imul(r ^ (r >> 7), 61 | r)) & 0xffffffff) ^ r
		return float((r ^ (r >> 14)) & 0xffffffff) / 4294967296.0
	func between(a: float, b: float) -> float: return a + (b - a) * next()
	static func _imul(a: int, b: int) -> int:
		return ((a & 0xffffffff) * (b & 0xffffffff)) & 0xffffffff

static func hex(h: int) -> Color:
	return Color.hex((h << 8) | 0xff).srgb_to_linear()

# ---------------------------------------------------------------------------
# 기본 도형 (three의 Box/Cylinder/Cone/Icosahedron/Plane과 같은 UV 규칙, 반시계 앞면)
# ---------------------------------------------------------------------------
# 중심 (x,y,z), 크기 w(x)·h(y)·d(z), y축 회전 ry
static func box(w: float, h: float, d: float, x := 0.0, y := 0.0, z := 0.0, ry := 0.0) -> Geo:
	var g := Geo.new()
	var hw := w / 2; var hh := h / 2; var hd := d / 2
	var P := [Vector3(-hw, -hh, -hd), Vector3(hw, -hh, -hd), Vector3(hw, hh, -hd), Vector3(-hw, hh, -hd),
		Vector3(-hw, -hh, hd), Vector3(hw, -hh, hd), Vector3(hw, hh, hd), Vector3(-hw, hh, hd)]
	g.quad(P[4], P[5], P[6], P[7]) # +z
	g.quad(P[1], P[0], P[3], P[2]) # -z
	g.quad(P[5], P[1], P[2], P[6]) # +x
	g.quad(P[0], P[4], P[7], P[3]) # -x
	g.quad(P[7], P[6], P[2], P[3]) # +y
	g.quad(P[0], P[1], P[5], P[4]) # -y
	return xf(g, x, y, z, 0, ry)

# 원기둥/원뿔대: 위 반지름 rt, 아래 rb, 높이 h(중심 기준), 둘레 seg
static func cyl(rt: float, rb: float, h: float, seg := 8, x := 0.0, y := 0.0, z := 0.0, rx := 0.0, ry := 0.0, rz := 0.0, caps := true) -> Geo:
	var g := Geo.new()
	var hh := h / 2
	for i in seg:
		var a0 := TAU * i / seg; var a1 := TAU * (i + 1) / seg
		var t0 := Vector3(sin(a0) * rt, hh, cos(a0) * rt); var t1 := Vector3(sin(a1) * rt, hh, cos(a1) * rt)
		var b0 := Vector3(sin(a0) * rb, -hh, cos(a0) * rb); var b1 := Vector3(sin(a1) * rb, -hh, cos(a1) * rb)
		var u0 := float(i) / seg; var u1 := float(i + 1) / seg
		g.quad(b0, b1, t1, t0, Vector2(u0, 0), Vector2(u1, 0), Vector2(u1, 1), Vector2(u0, 1))
		if caps and rt > 0.0:
			g.tri(Vector3(0, hh, 0), t0, t1, Vector2(0.5, 0.5), Vector2(0.5 + sin(a0) * 0.5, 0.5 + cos(a0) * 0.5), Vector2(0.5 + sin(a1) * 0.5, 0.5 + cos(a1) * 0.5))
		if caps and rb > 0.0:
			g.tri(Vector3(0, -hh, 0), b1, b0, Vector2(0.5, 0.5), Vector2(0.5 + sin(a1) * 0.5, 0.5 + cos(a1) * 0.5), Vector2(0.5 + sin(a0) * 0.5, 0.5 + cos(a0) * 0.5))
	return xf(g, x, y, z, rx, ry, rz)

static func cone(r: float, h: float, seg := 8, x := 0.0, y := 0.0, z := 0.0) -> Geo:
	return cyl(0.0, r, h, seg, x, y, z)

# 두 점을 잇는 가지(웹 limb)
static func limb(a: Vector3, b: Vector3, r0: float, r1: float, seg := 6) -> Geo:
	var d := b - a
	var len := d.length()
	var g := cyl(r1, r0, len, seg, 0, len / 2, 0)
	var up := Vector3.UP
	var dir := d / maxf(len, 1e-6)
	var axis := up.cross(dir)
	var basis := Basis.IDENTITY
	if axis.length() > 1e-6:
		basis = Basis(axis.normalized(), up.angle_to(dir))
	elif dir.y < 0.0:
		basis = Basis(Vector3.RIGHT, PI)
	return apply(g, Transform3D(basis, a))

# 울퉁불퉁한 덩이(바위·나뭇잎 덩이): 정이십면체 세분 + 잡음
static func lump(r: float, detail: int, rng: Rng, rough := 0.25, sy := 1.0) -> Geo:
	var g := icosphere(1.0, detail)
	var seed := rng.next() * 100.0
	var cache := {}
	for i in g.pos.size():
		var p := g.pos[i]
		var key := Vector3i(roundi(p.x * 1000), roundi(p.y * 1000), roundi(p.z * 1000))
		if not cache.has(key):
			var n := vnoise(p.x * 1.7 + seed, p.z * 1.7 + p.y * 1.3 - seed) * 0.6 + vnoise(p.x * 3.9 - seed, p.y * 3.1 + seed) * 0.4
			cache[key] = 1.0 + n * rough
		var k: float = cache[key]
		g.pos[i] = Vector3(p.x * r * k, p.y * r * k * sy, p.z * r * k)
	return g

static func icosphere(r: float, detail := 1) -> Geo:
	var t := (1.0 + sqrt(5.0)) / 2.0
	var V := [Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0), Vector3(0, -1, t), Vector3(0, 1, t),
		Vector3(0, -1, -t), Vector3(0, 1, -t), Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1)]
	var F := [[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11], [1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6], [7, 1, 8],
		[3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9], [4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1]]
	var tris := []
	for f in F: tris.append([V[f[0]].normalized(), V[f[1]].normalized(), V[f[2]].normalized()])
	for d in detail:
		var nt := []
		for tr in tris:
			var a: Vector3 = tr[0]; var b: Vector3 = tr[1]; var c: Vector3 = tr[2]
			var ab := ((a + b) / 2).normalized(); var bc := ((b + c) / 2).normalized(); var ca := ((c + a) / 2).normalized()
			nt.append([a, ab, ca]); nt.append([b, bc, ab]); nt.append([c, ca, bc]); nt.append([ab, bc, ca])
		tris = nt
	var g := Geo.new()
	for tr in tris:
		var uvs := []
		for p in tr: uvs.append(Vector2(atan2(p.x, p.z) / TAU + 0.5, p.y * 0.5 + 0.5))
		g.tri(tr[0] * r, tr[1] * r, tr[2] * r, uvs[0], uvs[1], uvs[2])
	return g

# 바닥에 눕힌 판(위를 봄): 크기 w×d, 중심
static func plane(w: float, d: float, x := 0.0, y := 0.0, z := 0.0) -> Geo:
	var g := Geo.new()
	var hw := w / 2; var hd := d / 2
	g.quad(Vector3(-hw, 0, hd), Vector3(hw, 0, hd), Vector3(hw, 0, -hd), Vector3(-hw, 0, -hd))
	return xf(g, x, y, z)

# 2D 다각형(xz, 반시계)을 높이 h로 세운 기둥(바닥 y0)
static func extrude(poly: PackedVector2Array, h: float, y0 := 0.0, caps := true) -> Geo:
	var g := Geo.new()
	var n := poly.size()
	var per := 0.0
	for i in n: per += poly[i].distance_to(poly[(i + 1) % n])
	var acc := 0.0
	for i in n:
		var p0 := poly[i]; var p1 := poly[(i + 1) % n]
		var l := p0.distance_to(p1)
		var u0 := acc / maxf(per, 1e-6); acc += l; var u1 := acc / maxf(per, 1e-6)
		g.quad(Vector3(p0.x, y0, p0.y), Vector3(p1.x, y0, p1.y), Vector3(p1.x, y0 + h, p1.y), Vector3(p0.x, y0 + h, p0.y),
			Vector2(u0, 0), Vector2(u1, 0), Vector2(u1, 1), Vector2(u0, 1))
	if caps:
		var idx := Geometry2D.triangulate_polygon(poly)
		for i in range(0, idx.size(), 3):
			var a := poly[idx[i]]; var b := poly[idx[i + 1]]; var c := poly[idx[i + 2]]
			g.tri(Vector3(a.x, y0 + h, a.y), Vector3(c.x, y0 + h, c.y), Vector3(b.x, y0 + h, b.y))
	return g

# ---------------------------------------------------------------------------
# 변환·색칠·병합
# ---------------------------------------------------------------------------
# 위치 x,y,z / 회전(라디안, YXZ 순서) / 크기
static func xf(g: Geo, x := 0.0, y := 0.0, z := 0.0, rx := 0.0, ry := 0.0, rz := 0.0, sx := 1.0, sy := NAN, sz := NAN) -> Geo:
	if is_nan(sy): sy = sx
	if is_nan(sz): sz = sx
	var b := Basis.from_euler(Vector3(rx, ry, rz), EULER_ORDER_YXZ).scaled_local(Vector3(sx, sy, sz))
	return apply(g, Transform3D(b, Vector3(x, y, z)))

static func apply(g: Geo, t: Transform3D) -> Geo:
	for i in g.pos.size(): g.pos[i] = t * g.pos[i]
	# 음수 배율이면 감김이 뒤집힌다 → 되돌림
	if t.basis.determinant() < 0.0: _flip(g)
	return g

static func _flip(g: Geo) -> void:
	for i in range(0, g.pos.size(), 3):
		var p := g.pos[i + 1]; g.pos[i + 1] = g.pos[i + 2]; g.pos[i + 2] = p
		var u := g.uv[i + 1]; g.uv[i + 1] = g.uv[i + 2]; g.uv[i + 2] = u
		var c := g.col[i + 1]; g.col[i + 1] = g.col[i + 2]; g.col[i + 2] = c

static var _paint_rng := Rng.new(20261002) # rng를 안 넘겨도 실행마다 같은 얼룩

# 세로 그라데이션(아래 bottom → 위 top) + 면마다 약간의 얼룩(웹 paint). 색은 Kit.hex()로(선형)
static func paint(g: Geo, top: Color, bottom = null, jitter := 0.05, rng: Rng = null) -> Geo:
	var bot: Color = top if bottom == null else bottom
	var b := g.aabb()
	var y0 := b.position.y
	var hy := b.size.y if b.size.y > 0.0 else 1.0
	for i in range(0, g.pos.size(), 3):
		var j := ((rng.next() if rng else _paint_rng.next()) - 0.5) * jitter
		for k in 3:
			var t := (g.pos[i + k].y - y0) / hy
			g.col[i + k] = Color(maxf(0, lerpf(bot.r, top.r, t) + j), maxf(0, lerpf(bot.g, top.g, t) + j), maxf(0, lerpf(bot.b, top.b, t) + j * 0.8))
	return g

static func merge(list: Array) -> Geo:
	var out := Geo.new()
	for g in list:
		out.pos.append_array(g.pos); out.uv.append_array(g.uv); out.col.append_array(g.col); out.nrm.append_array(g.nrm)
	return out

# ---------------------------------------------------------------------------
# 법선·UV·먹선
# ---------------------------------------------------------------------------
static func _key(p: Vector3) -> Vector3i:
	return Vector3i(roundi(p.x * 500), roundi(p.y * 500), roundi(p.z * 500))

static func face_normals(g: Geo) -> void:
	g.nrm.resize(g.pos.size())
	for i in range(0, g.pos.size(), 3):
		var n := (g.pos[i + 1] - g.pos[i]).cross(g.pos[i + 2] - g.pos[i]).normalized()
		g.nrm[i] = n; g.nrm[i + 1] = n; g.nrm[i + 2] = n

static func smooth_normals(g: Geo) -> void:
	var acc := {}
	for i in range(0, g.pos.size(), 3):
		var fn := (g.pos[i + 1] - g.pos[i]).cross(g.pos[i + 2] - g.pos[i])
		for k in 3:
			var key := _key(g.pos[i + k])
			acc[key] = acc.get(key, Vector3.ZERO) + fn
	g.nrm.resize(g.pos.size())
	for i in g.pos.size():
		g.nrm[i] = (acc[_key(g.pos[i])] as Vector3).normalized()

static func remap_uv(g: Geo, key: String) -> void:
	var rname: String = KEY_REG.get(key, "white")
	var r: Array = REG[rname]
	var inset := 3.0
	var u0: float = (r[0] + inset) / ATLAS_W; var u1: float = (r[2] - inset) / ATLAS_W
	var v_top: float = (r[1] + inset) / ATLAS_H; var v_bot: float = (r[3] - inset) / ATLAS_H
	var solid := rname == "white" or rname == "lamp"
	for i in g.uv.size():
		var u := 0.5 if solid else clampf(g.uv[i].x, 0, 1)
		var v := 0.5 if solid else clampf(g.uv[i].y, 0, 1)
		# three의 v(위가 1) → Godot 이미지 좌표(위가 0)
		g.uv[i] = Vector2(u0 + (u1 - u0) * u, v_top + (v_bot - v_top) * (1.0 - v))

# 먹선 껍질: 같은 위치 꼭짓점을 면 법선 평균 방향으로 t만큼 밀고 감김을 뒤집어 먹색으로
static func hull(g: Geo, t: float) -> Geo:
	var acc := {}
	for i in range(0, g.pos.size(), 3):
		var fn := (g.pos[i + 1] - g.pos[i]).cross(g.pos[i + 2] - g.pos[i])
		if fn.length() > 1e-12: fn = fn.normalized()
		for k in 3:
			var key := _key(g.pos[i + k])
			acc[key] = acc.get(key, Vector3.ZERO) + fn
	var h := Geo.new()
	var ink := hex(INK)
	for i in g.pos.size():
		var v: Vector3 = acc[_key(g.pos[i])]
		h.pos.append(g.pos[i] + (v.normalized() if v.length() > 0 else Vector3.ZERO) * t)
		h.uv.append(Vector2(0.5, 0.5))
		h.col.append(ink)
	_flip(h)
	face_normals(h)
	remap_uv(h, "white")
	return h

# ---------------------------------------------------------------------------
# 재질
# ---------------------------------------------------------------------------
static var _tex := {}
static var _mats := {}
static var _lock := Mutex.new() # 작업 스레드(타일 흩뿌리기)에서도 부를 수 있게

static func texture(name: String) -> Texture2D:
	_lock.lock()
	if not _tex.has(name):
		var img := Image.load_from_file(ProjectSettings.globalize_path(ASSETS + name + ".png"))
		img.generate_mipmaps()
		_tex[name] = ImageTexture.create_from_image(img)
	var t: Texture2D = _tex[name]
	_lock.unlock()
	return t

# 'atlas'(거의 전부, 창호지·초롱은 밤에 빛남) / 'cloth'(양면 천) / 'water'(반투명 물결, 웹 개울과 같은 재질)
static func material(kind := "atlas") -> ShaderMaterial:
	_lock.lock()
	var m0: ShaderMaterial = _mats.get(kind)
	_lock.unlock()
	if m0: return m0
	var made := _make_material(kind)
	_lock.lock()
	if not _mats.has(kind): _mats[kind] = made
	var out: ShaderMaterial = _mats[kind]
	_lock.unlock()
	return out

static func _make_material(kind: String) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	if kind == "water":
		m.shader = Materials.world_shader(true, true, false)
		m.set_shader_parameter("ramp_tex", Materials.ramp_texture())
		m.set_shader_parameter("albedo_tex", texture("water"))
		var c := hex(0xb4cac8)
		m.set_shader_parameter("albedo_color", Vector4(c.r, c.g, c.b, 0.88))
		return m
	m.shader = Materials.world_shader(true, false, kind == "cloth")
	m.set_shader_parameter("ramp_tex", Materials.ramp_texture())
	m.set_shader_parameter("albedo_tex", texture("atlas") if kind != "cloth" else null)
	if kind == "atlas":
		m.set_shader_parameter("emission_tex", texture("mask"))
		m.set_shader_parameter("emissive_color", Vector3(1.0, 0.4564, 0.1022)) # 0xffb45a 선형
		m.set_shader_parameter("use_emission", 1.0)
	return m

# ---------------------------------------------------------------------------
# Batch: 재질 키별 조각을 아틀라스 재질 하나로 합침(먹선 포함). 'cloth'만 양면 재질로 따로 (웹 Batch)
# ---------------------------------------------------------------------------
class Batch:
	var parts := {}   # "atlas" | "cloth" → Array[Geo]
	var tris := 0

	# outline: 먹선 두께(m). 0이면 먹선 없음
	func add(key: String, g: Geo, outline := 0.03) -> Geo:
		# 'water': 물 재질(반투명, 물결 텍스처 반복). UV는 그대로(1 = 텍스처 한 장, 약 4m 간격 권장), 먹선 없음
		if key == "water":
			Kit.face_normals(g)
			for i in g.uv.size(): g.uv[i] = Vector2(g.uv[i].x, 1.0 - g.uv[i].y)
			if not parts.has("water"): parts["water"] = []
			parts["water"].append(g)
			tris += g.size() / 3
			return g
		if key in Kit.FACETED: Kit.face_normals(g)
		else: Kit.smooth_normals(g)
		Kit.remap_uv(g, key)
		var mk := "cloth" if key == "cloth" else "atlas"
		if not parts.has(mk): parts[mk] = []
		parts[mk].append(g)
		tris += g.size() / 3
		if outline > 0.0:
			if not parts.has("atlas"): parts["atlas"] = []
			var h := Kit.hull(g, outline * Kit.OUTLINE_SCALE)
			parts["atlas"].append(h)
			tris += h.size() / 3
		return g

	func is_empty() -> bool:
		return parts.is_empty()

	# 하나의 ArrayMesh(재질별 표면)로
	func mesh() -> ArrayMesh:
		var am := ArrayMesh.new()
		for mk in parts:
			var g := Kit.merge(parts[mk])
			if g.size() == 0: continue
			var arr := []
			arr.resize(Mesh.ARRAY_MAX)
			# three(반시계) → Godot(시계): 두 번째·세 번째 꼭짓점 교환
			var P := g.pos.duplicate(); var N := g.nrm.duplicate(); var U := g.uv.duplicate(); var C := g.col.duplicate()
			for i in range(0, P.size(), 3):
				var p := P[i + 1]; P[i + 1] = P[i + 2]; P[i + 2] = p
				var n := N[i + 1]; N[i + 1] = N[i + 2]; N[i + 2] = n
				var u := U[i + 1]; U[i + 1] = U[i + 2]; U[i + 2] = u
				var c := C[i + 1]; C[i + 1] = C[i + 2]; C[i + 2] = c
			arr[Mesh.ARRAY_VERTEX] = P; arr[Mesh.ARRAY_NORMAL] = N; arr[Mesh.ARRAY_TEX_UV] = U; arr[Mesh.ARRAY_COLOR] = C
			am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
			am.surface_set_material(am.get_surface_count() - 1, Kit.material(mk))
		return am

	func build(name := "", cast := true) -> Node3D:
		var root := Node3D.new()
		root.name = name if name != "" else "kit"
		var mi := MeshInstance3D.new()
		mi.mesh = mesh()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
		return root
