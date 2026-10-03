# 굴산사지 당간지주(崛山寺址 幢竿支柱, 강릉 구정면 학산리, 통일신라 9세기) — 우리나라에서 가장 큰 당간지주(높이 약 5.4m).
# 1870년에는 절은 없어지고 논밭 가운데 거칠게 다듬은 화강암 기둥 둘만 서 있었다(밑동이 땅에 묻혀 받침돌은 안 보임 — 가설).
# 두 기둥은 x로 0.6m 떨어져 마주 보고(안쪽 면 수직), 바깥 위쪽은 둥글게 깎였고 장대(간)를 꿰던 구멍이 위·가운데에 있음.
# budo=true면 몇 m 옆에 굴산사지 승탑(부도, 팔각원당형 — 실제로는 조금 떨어진 곳)을 작게 둔다. params: seed, budo(true)
extends RefCounted

const Co = preload("res://kit/landmark/_common.gd")
const St = preload("res://kit/landmark/_stone.gd")

const GRANITE := [0xb3ab9a, 0x847d6f]

# 기둥 하나(안쪽 면이 x=0, 바깥으로 +x). 옆에서 본 윤곽(x-y)을 z로 깊이 d만큼 세우고 꼭짓점을 조금씩 흔들어 거칠게
static func pillar(rng: Kit.Rng, w: float, h: float, d: float) -> Kit.Geo:
	var poly := PackedVector2Array()
	poly.append(Vector2(0, -0.4))
	poly.append(Vector2(w, -0.4))
	poly.append(Vector2(w * 0.86, h * 0.78))     # 위로 갈수록 바깥 면이 조금 좁아짐
	var n := 5
	for i in range(1, n + 1):
		var a := PI / 2 * i / n
		poly.append(Vector2(w * 0.86 * cos(a), h * 0.78 + (h * 0.22) * sin(a)))   # 바깥 위 둥근 머리
	var g := Co.extrude_xy(poly, d, 0.0)
	var sd := rng.next() * 30.0
	var cache := {}
	for i in g.pos.size():
		var p := g.pos[i]
		var key := Kit._key(p)
		if not cache.has(key):
			cache[key] = Vector3(Kit.vnoise(p.y * 1.3 + sd, p.z * 2.0) - 0.5, 0, Kit.vnoise(p.y * 1.1 - sd, p.x * 2.0) - 0.5) * 0.1
		var o: Vector3 = cache[key]
		if p.x > 0.01: g.pos[i] = p + o            # 안쪽 면(x=0)은 곧게
		else: g.pos[i] = p + Vector3(0, 0, o.z)
	# 위로 갈수록 앞뒤 두께도 조금 줄임
	for i in g.pos.size():
		var p := g.pos[i]
		g.pos[i] = Vector3(p.x, p.y, p.z * (1.0 - 0.12 * clampf(p.y / h, 0, 1)))
	return g

# 팔각원당형 승탑(부도): 지대석 + 하대석(구름·사자 새김 자리) + 중대석 + 상대석(연꽃) + 팔각 탑신 + 옥개석 + 보주. 높이 약 3.2m(실물 3.6m, 가설로 작게)
static func budo(b, rng: Kit.Rng, x: float, z: float) -> void:
	var g := []
	g.append(St.oct(1.25, 1.2, 0.3, 0.0))
	g.append(St.oct(1.05, 0.9, 0.42, 0.3))
	g.append(St.oct(0.5, 0.5, 0.45, 0.72))
	g.append(St.oct(0.72, 0.9, 0.32, 1.17))     # 상대석(위로 벌어진 연꽃)
	g.append(St.oct(0.52, 0.5, 0.85, 1.49))     # 탑신
	# 옥개석(팔각 지붕, 처마 살짝 두께) + 노반 + 보주
	g.append(St.oct(0.95, 0.95, 0.12, 2.34))
	g.append(Kit.cyl(0.18, 0.95, 0.45, 8, 0, 2.46 + 0.225, 0, 0, PI / 8, 0))
	g.append(St.oct(0.2, 0.18, 0.14, 2.91))
	var bj := Kit.lump(0.16, 0, rng, 0.05, 1.2); Kit.xf(bj, 0, 3.2, 0); g.append(bj)
	var gg := Kit.merge(g)
	Kit.xf(gg, x, -0.05, z)
	b.add("stone", Co.pnt(gg, [0xb8b1a2, 0x857e70], 0.05, rng), 0.02)
	# 탑신 문비(앞 면 어두운 네모)
	var dq := Co.vplane(0.28, 0.42, 0, 1.92, 0.47)
	Kit.xf(dq, x, -0.05, z)
	b.add("flat", Co.pnt(dq, [0x6e685e]), 0.0)

static func build(params: Dictionary) -> Dictionary:
	var rng := Kit.Rng.new(int(params.get("seed", 1)))
	var b := Kit.Batch.new()
	var H := 5.4; var w := 0.82; var d := 1.2; var gap := 0.6
	var parts := []
	for s in [-1.0, 1.0]:
		var p := pillar(rng, w, H, d)
		if s < 0.0: Kit.xf(p, 0, 0, 0, 0, PI)     # 왼쪽 기둥은 돌려서 안쪽 면이 +x를 봄
		Kit.xf(p, s * gap / 2, 0, 0)
		parts.append(p)
	b.add("rock", Co.pnt(Kit.merge(parts), GRANITE, 0.06, rng), 0.03)
	# 간공(장대 꿰는 구멍): 바깥 면 위·가운데 어두운 네모
	var holes := []
	for s in [-1.0, 1.0]:
		for hy in [H * 0.82, H * 0.5]:
			var q := Co.vplane(0.22, 0.26, 0, hy, 0.0)
			Kit.xf(q, s * (gap / 2 + w * (0.85 if hy > H * 0.6 else 0.915) + 0.02), 0, 0, 0, s * PI / 2)
			holes.append(q)
	b.add("flat", Co.pnt(Kit.merge(holes), [0x2a2520]), 0.0)
	# 밑동 흙 둔덕·잡풀(받침이 묻힘)
	var m := Kit.lump(1.0, 1, rng, 0.2, 1.0)
	Kit.xf(m, 0, -0.05, 0, 0, 0, 0, 1.6, 0.28, 1.1)
	b.add("organic", Co.pnt(m, [0x8a8a58, 0x6e6a48], 0.05, rng), 0.02)
	var cols := [{ type = "box", minX = -gap / 2 - w - 0.1, maxX = gap / 2 + w + 0.1, minZ = -d / 2 - 0.1, maxZ = d / 2 + 0.1 }]
	var anchors := { front = Vector3(0, 0, 2.2), between = Vector3(0, 0, 0) }
	if params.get("budo", true):
		var bx := 3.6; var bz := -1.8
		budo(b, rng, bx, bz)
		cols.append({ type = "circle", x = bx, z = bz, r = 1.3 })
		anchors.budo = Vector3(bx, 0, bz + 1.8)
	return {
		node = b.build("굴산사지당간지주"), colliders = cols, lights = [], occluder = true,
		footprint = Vector2(10.0, 8.0), anchors = anchors,
	}
