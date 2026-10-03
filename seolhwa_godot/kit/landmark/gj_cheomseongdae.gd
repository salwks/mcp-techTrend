# 첨성대(瞻星臺) — 신라 선덕여왕 때(7세기) 화강암 석조. 높이 약 9.17m, 밑지름 약 4.93m, 윗지름 약 2.85m, 27단 원통(병 모양),
# 가운데 남쪽 네모 창(약 1m), 꼭대기 정(井)자 장대석 2단, 아래 네모 기단 2단. 1870년에도 지금과 같은 모습(약간 기울어짐).
# 단 수·치수는 문화재 설명값을 따름, 단마다 높이는 고르게 나눈 근사. params: seed
extends RefCounted

const Co = preload("res://kit/landmark/_common.gd")

static func radius(t: float) -> float:
	# t 0(밑)..1(위): 아래가 불룩하고 위로 오목하게 좁아지는 병 모양
	return 2.46 - 1.03 * pow(t, 0.75) - 0.08 * sin(t * PI)

static func build(params: Dictionary) -> Dictionary:
	var rng := Kit.Rng.new(int(params.get("seed", 1)))
	var b := Kit.Batch.new()
	# 기단 2단(네모)
	b.add("stone", Co.pnt(Kit.box(5.36, 0.4, 5.36, 0, 0.2, 0), [0xb5ad9c, 0x8d8576], 0.05, rng), 0.03)
	b.add("stone", Co.pnt(Kit.box(5.0, 0.4, 5.0, 0, 0.6, 0), [0xbab2a1, 0x968e7e], 0.05, rng), 0.03)
	var y0 := 0.8
	var H := 7.7
	var rows := 27
	var seg := 16
	var g := Kit.Geo.new()
	var top := Kit.hex(0xc9c0aa); var bot := Kit.hex(0x9d9482)
	for k in rows:
		var t0 := float(k) / rows; var t1 := float(k + 1) / rows
		var ya := y0 + H * t0; var yb := y0 + H * t1 - 0.03
		var r0 := radius(t0); var r1 := radius(t1)
		var tone := rng.between(-0.04, 0.04)
		for i in seg:
			var a0 := TAU * i / seg + (0.1 if k % 2 == 1 else 0.0); var a1 := TAU * (i + 1) / seg + (0.1 if k % 2 == 1 else 0.0)
			# 네모 창 자리(남쪽 +z, 13~15단)
			var mid := (a0 + a1) / 2
			if k >= 13 and k <= 15 and absf(wrapf(mid - PI / 2, -PI, PI)) < 0.25: continue
			var A := Vector3(cos(a0) * r0, ya, sin(a0) * r0); var B := Vector3(cos(a1) * r0, ya, sin(a1) * r0)
			var C := Vector3(cos(a1) * r1, yb, sin(a1) * r1); var D := Vector3(cos(a0) * r1, yb, sin(a0) * r1)
			var base := g.size()
			Co.Roof.quad_facing(g, A, B, C, D, Vector3(cos(mid), 0, sin(mid)))
			for q in range(base, g.size()):
				var cc := bot.lerp(top, t0)
				g.col[q] = Color(cc.r + tone, cc.g + tone, cc.b + tone)
		# 줄눈(단 사이 어두운 띠) — 몸체 안쪽 원통으로 대신
	b.add("stone", g, 0.03)
	var core := Kit.cyl(radius(1.0) * 0.8, radius(0.0) * 0.8, H, seg, 0, y0 + H / 2, 0)
	b.add("flat", Co.pnt(core, [0x4a443c]), 0.0)
	# 남쪽 창(어두운 구멍 + 창틀 돌)
	var wy := y0 + H * 14.5 / 27
	var wr := radius(14.5 / 27.0)
	b.add("flat", Co.pnt(Co.vplane(1.0, 1.0, 0, wy, wr - 0.25), [0x1e1a17]), 0.0)
	b.add("stone", Co.pnt(Kit.box(1.3, 0.16, 0.5, 0, wy - 0.55, wr - 0.05), [0xbab2a1, 0x968e7e], 0.04, rng), 0.015)
	# 꼭대기 정(井)자석 2단
	var yt := y0 + H
	var rt := radius(1.0)
	var jg := []
	for lvl in 2:
		var yy := yt + 0.15 + lvl * 0.3
		var ang := 0.0 if lvl == 0 else PI / 2
		for s in [-1, 1]:
			var bar := Kit.box(3.1, 0.3, 0.32, 0, yy, s * (rt - 0.3))
			Kit.xf(bar, 0, 0, 0, 0, ang)
			jg.append(bar)
	b.add("stone", Co.pnt(Kit.merge(jg), [0xbfb7a5, 0x9a927f], 0.04, rng), 0.025)
	# 안쪽 판석 일부(중간 정자석 자리)
	return {
		node = b.build("첨성대"), colliders = [{ type = "circle", x = 0.0, z = 0.0, r = 2.7 }], lights = [], occluder = true,
		footprint = Vector2(5.4, 5.4), anchors = { front = Vector3(0, 0, 4.2), window = Vector3(0, wy, wr) },
	}
