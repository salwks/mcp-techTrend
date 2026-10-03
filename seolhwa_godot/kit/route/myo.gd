# 무덤(봉분) — 길가 산기슭의 둥근 흙무덤. 풀 덮인 봉분 + (stone) 앞 상석·작은 비석 / (old) 돌보지 않아 내려앉은 묵은 무덤(풀·잡목)
# 명세 §23: 귀신 이야기는 무덤·폐가, 여우(구미호)는 고개·무덤. 효자 시묘(효자와 호랑이 JG24)도 무덤 자리.
# params: seed, r(2.1), stone(true), old(false), n(1: 무덤 수 — 2면 나란히 쌍분)
extends RefCounted
const C := preload("res://kit/village/_common.gd")

static func build(params: Dictionary) -> Dictionary:
	var m := C.M.new(int(params.get("seed", 1)))
	var r0: float = float(params.get("r", 2.1))
	var old := bool(params.get("old", false))
	var stone := bool(params.get("stone", not old))
	var n: int = int(params.get("n", 1))
	var R := m.rng
	for i in n:
		var x := (i - (n - 1) * 0.5) * (r0 * 2.3)
		var r := r0 * (0.9 + m.r() * 0.15)
		var h := r * (0.42 if old else 0.55)
		var pts := []
		for k in 7:
			var t := float(k) / 6.0
			pts.append(Vector2(r * cos(t * PI / 2) * (1.0 + 0.08 * (1 - t)), h * sin(t * PI / 2)))
		var g := C.lathe(pts, 14)
		Kit.xf(g, x, -0.05, 0, 0, m.r(), 0, 1.0, 1.0, 1.08)
		var top := 0x8d9a5a if not old else 0x9a9a62
		m.add("p", "organic", C.P(g, top, 0x6c7448, 0.06, R), 0.03)
		# 둘레 낮은 둔덕(사성 — 뒤쪽 말굽 둔덕)
		for k in 6:
			var a := PI * (1.12 + 0.76 * k / 5.0)
			m.add("p", "organic", C.P(Kit.xf(Kit.lump(0.7, 0, R, 0.2, 0.45), x + cos(a) * r * 1.4, 0.0, sin(a) * r * 1.3), 0x95a060, 0x707a4a, 0.05, R), 0.0)
		if stone:
			m.add("p", "stone", C.P(Kit.box(1.1, 0.32, 0.6, x, 0.16, r + 0.55), 0xb2ac9e, 0x8a8579, 0.04, R), 0.015)
			m.add("p", "stone", C.P(Kit.box(0.36, 0.95, 0.12, x - r * 0.55, 0.47, r + 0.4), 0xb8b2a4, 0x8e8a7e, 0.04, R), 0.012)
			m.add("p", "stone", C.P(Kit.box(0.5, 0.1, 0.24, x - r * 0.55, 0.98, r + 0.4), 0xa49e90, 0x8a857a, 0.03, R), 0.01)
			m.box_c(x - 0.6, x + 0.6, r + 0.25, r + 0.85)
		if old:
			for k in 5:
				var a := m.r() * TAU; var rr := r * (0.3 + m.r() * 0.6)
				m.add("p", "leaf", C.P(Kit.xf(Kit.lump(0.25 + m.r() * 0.2, 0, R, 0.4, 0.8), x + cos(a) * rr, h * 0.6, sin(a) * rr * 0.9), 0x8a9256, 0x5a6238, 0.05, R), 0)
			m.add("p", "stone", C.P(Kit.xf(Kit.box(0.34, 0.6, 0.1), x - r * 0.4, 0.2, r + 0.5, 0.35, 0.2, 0.25), 0xa29c8e, 0x7a756b, 0.04, R), 0.01)
		m.circle(x, 0, r * 0.85)
	m.anchor("front", Vector3(0, 0, r0 + 1.6))
	return m.result("무덤", Vector2(n * r0 * 2.3 + 1.0, r0 * 2.8 + 1.4), false)
