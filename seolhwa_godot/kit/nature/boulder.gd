# 큰 바위 — 지리산 화강암: 둥글게 닳은 덩이 2~4개가 절리(갈라진 틈)를 두고 붙은 모양. 먹선 윤곽 + 아틀라스 rock 붓결로 준법(皴法) 느낌.
# params: seed, s(2.2, 대략 반지름 m), mossy(true)
extends RefCounted
const C := preload("res://kit/nature/_common.gd")

static func build(params: Dictionary) -> Dictionary:
	var r := Kit.Rng.new(int(params.get("seed", 1)))
	var s := float(params.get("s", 2.2))
	var mossy := bool(params.get("mossy", true))
	var b := Kit.Batch.new()
	var n := 2 + int(r.next() * 3)
	var ext := 0.0
	var cols := []
	var a0 := r.next() * TAU
	for i in n:
		var main := i == 0
		var rad := s * (1.0 if main else 0.5 + r.next() * 0.3)
		var a := a0 + i * 2.1 + r.next() * 0.6
		var d := 0.0 if main else s * (0.75 + r.next() * 0.25)
		var x := cos(a) * d; var z := sin(a) * d * 0.7
		var sy := 0.55 + r.next() * 0.25 if main else 0.6 + r.next() * 0.3
		var g := Kit.lump(rad, 1, r, 0.22, sy)
		# 바닥은 평평하게 묻고 윗면은 약간 눌러 각을 세움(절리면)
		var cut := rad * sy * (0.35 + r.next() * 0.2)
		for k in g.pos.size():
			var p := g.pos[k]
			if p.y > cut: p.y = cut + (p.y - cut) * 0.45
			g.pos[k] = p
		Kit.xf(g, x, rad * sy * 0.45, z, (r.next() - 0.5) * 0.25, r.next() * TAU, (r.next() - 0.5) * 0.25)
		var top := "#a9ab90" if mossy and r.next() < 0.45 else "#c2bcae"
		b.add("rock", Kit.paint(g, C.c(top), C.c("#67625a"), 0.06, r), 0.03 + rad * 0.008)
		ext = maxf(ext, maxf(absf(x), absf(z)) + rad)
		cols.append({ type = "circle", x = x, z = z, r = rad * 0.85 })
	return C.result(b, "큰바위", cols, Vector2(ext * 2, ext * 2), s > 1.6, { height = s * 1.1 })
