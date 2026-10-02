# 실상사 석등(보물, 통일신라, 높이 약 5m) — 팔각 하대석(복련) + 장구 모양 간주석(가운데 띠) + 상대석(앙련) + 팔각 화사석(화창 4)
# + 팔각 옥개석(귀꽃) + 보개·보주. 석등 앞에 불을 켜러 오르는 돌계단이 있는 것이 특징(검색·답사기 근거). 비례는 가설.
# 밤에 화창이 빛난다(glow). params: seed, height(5.0), stair(true)
extends RefCounted

const Co = preload("res://kit/landmark/_common.gd")
const St = preload("res://kit/landmark/_stone.gd")

static func build(params: Dictionary) -> Dictionary:
	var rng := Kit.Rng.new(int(params.get("seed", 1)))
	var s: float = float(params.get("height", 5.0)) / 5.0
	var b := Kit.Batch.new()
	var p := []
	var y := 0.0
	p.append(Kit.box(2.2 * s, 0.3 * s, 2.2 * s, 0, 0.15 * s, 0)); y = 0.3 * s                     # 지대석
	p.append(St.oct(1.0 * s, 0.85 * s, 0.35 * s, y)); y += 0.35 * s                               # 하대석
	p.append(St.oct(0.75 * s, 0.45 * s, 0.25 * s, y)); y += 0.25 * s                              # 복련
	# 장구형 간주석: 아래 북 - 가운데 띠 - 위 북
	p.append(Kit.cyl(0.42 * s, 0.3 * s, 0.55 * s, 8, 0, y + 0.275 * s, 0)); y += 0.55 * s
	p.append(Kit.cyl(0.36 * s, 0.36 * s, 0.14 * s, 8, 0, y + 0.07 * s, 0)); y += 0.14 * s
	p.append(Kit.cyl(0.3 * s, 0.42 * s, 0.55 * s, 8, 0, y + 0.275 * s, 0)); y += 0.55 * s
	p.append(St.oct(0.5 * s, 0.85 * s, 0.32 * s, y)); y += 0.32 * s                              # 상대석(앙련)
	var hy := y
	var hh := 0.85 * s
	p.append(St.oct(0.5 * s, 0.5 * s, hh, y)); y += hh                                           # 화사석
	var og := Kit.cyl(0.12 * s, 1.0 * s, 0.5 * s, 8, 0, y + 0.25 * s, 0, 0, PI / 8, 0); y += 0.5 * s   # 옥개석
	p.append(og)
	b.add("stone", Co.pnt(Kit.merge(p), [0xbab4a6, 0x8f897c], 0.06, rng), 0.03)
	# 귀꽃(옥개석 여덟 귀)
	var gk := []
	for i in 8:
		var a := TAU * i / 8 + PI / 8
		gk.append(Kit.xf(Kit.box(0.12 * s, 0.22 * s, 0.12 * s), sin(a) * 0.95 * s, y - 0.42 * s, cos(a) * 0.95 * s, 0, a))
	# 보개 + 보주
	gk.append(Kit.cyl(0.22 * s, 0.28 * s, 0.18 * s, 8, 0, y + 0.09 * s, 0)); y += 0.18 * s
	var bj := Kit.icosphere(0.2 * s, 1); Kit.xf(bj, 0, y + 0.2 * s, 0); gk.append(bj); y += 0.4 * s
	b.add("stone", Co.pnt(Kit.merge(gk), [0xa9a395, 0x8a8478], 0.05, rng), 0.02)
	# 화창 4(앞뒤좌우): 어두운 판 + 안에 불빛
	var win := []
	for i in 4:
		var a := PI / 2 * i
		var q := Co.vplane(0.3 * s, 0.5 * s, 0, 0, 0)
		Kit.xf(q, sin(a) * 0.47 * s, hy + hh / 2, cos(a) * 0.47 * s, 0, a)
		win.append(q)
	b.add("flat", Co.pnt(Kit.merge(win), [0x2a2420]), 0.0)
	b.add("glow", Co.pnt(Kit.cyl(0.18 * s, 0.18 * s, 0.4 * s, 6, 0, hy + hh / 2, 0), [0xffd27a, 0xff9a3a]), 0.0)
	if params.get("stair", true):
		var sg := []
		var n := 6
		for k in n:
			var sh := (k + 1) * (hy - 0.75 * s) / n
			sg.append(Kit.box(0.6 * s, sh, 0.3 * s, 0, sh / 2, 1.25 * s + 0.15 * s + (n - 1 - k) * 0.28 * s))
		b.add("stone", Co.pnt(Kit.merge(sg), [0xb0aa9c, 0x8a8478], 0.05, rng), 0.02)
	return {
		node = b.build("석등"),
		colliders = [{ type = "circle", x = 0.0, z = 0.0, r = 1.2 * s }, { type = "box", minX = -0.4 * s, maxX = 0.4 * s, minZ = 1.1 * s, maxZ = 3.3 * s }],
		lights = [{ x = 0.0, y = hy + hh / 2, z = 0.0, kind = "shrine" }],
		occluder = false, footprint = Vector2(2.2 * s, 4.0 * s), anchors = { front = Vector3(0, 0, 3.8 * s) },
	}
