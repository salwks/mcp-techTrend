# 오작교(烏鵲橋) — 광한루원 연못을 건너는 돌 홍예다리. 길이 57m·폭 2.4m, 홍예 4개(1582 남원부사 장의국 가설, 전라관찰사 정철 때 삼신산 조성).
# 로컬 z축이 다리 방향(남북), 원점 = 다리 가운데 수면(바닥) 높이. 홍예 지름·상판 높이는 사진 비례 가설.
# params: seed, length(57), width(2.4), arches(4)
extends RefCounted

const Co = preload("res://kit/landmark/_common.gd")
const S = preload("res://kit/landmark/_seong.gd")

static func deck(z: float, L: float) -> float:
	var e := L / 2 - absf(z)
	return 0.35 + 1.75 * clampf(e / 9.0, 0.0, 1.0)

static func build(params: Dictionary) -> Dictionary:
	var rng := Kit.Rng.new(int(params.get("seed", 1)))
	var L: float = float(params.get("length", 57.0))
	var Wd: float = float(params.get("width", 2.4))
	var na: int = int(params.get("arches", 4))
	var r := 1.35; var sp := 0.15; var gap := 5.2
	var b := Kit.Batch.new()
	# 옆면 다각형(u = z, y): 바닥 -0.8, 위 = 상판, 홍예 구멍
	var poly := PackedVector2Array()
	var y0 := -0.8
	poly.append(Vector2(-L / 2, y0))
	var centers := []
	for i in na: centers.append((i - (na - 1) / 2.0) * gap)
	for c in centers:
		poly.append(Vector2(c - r, y0)); poly.append(Vector2(c - r, sp))
		for k in range(1, 10):
			var a := PI - PI * k / 10
			poly.append(Vector2(c + cos(a) * r, sp + sin(a) * r))
		poly.append(Vector2(c + r, sp)); poly.append(Vector2(c + r, y0))
	poly.append(Vector2(L / 2, y0))
	var n := 16
	for i in n + 1:
		var u := L / 2 - L * i / n
		poly.append(Vector2(u, deck(u, L)))
	# 마지막 점(-L/2, deck)과 첫 점(-L/2, y0) 사이는 닫힘
	var g := Co.extrude_xy(poly, Wd - 0.1)
	# (u,y,w) → 다리 방향 z: ry = -90° 로 u축을 z축으로
	Kit.xf(g, 0, 0, 0, 0, -PI / 2)
	b.add("flat", Co.pnt(g, [0xaea89b, 0x8a8478], 0.03, rng), 0.03)
	# 옆면 면석(홍예 사이·접근부)
	var fg := Kit.Geo.new()
	var zz := -L / 2 + 0.1
	while zz < L / 2 - 0.6:
		var w: float = rng.between(0.9, 1.5)
		var zc := zz + w / 2
		var in_arch := false
		for c in centers:
			if absf(zc - c) < r + w / 2 + 0.1: in_arch = true
		var top := deck(zz + w, L) - 0.12
		var y := -0.3
		var row := 0
		while y + 0.35 < top:
			if not (in_arch and y > sp - 0.4):
				for sx in [-1, 1]:
					var q := Co.vplane(w - 0.06, 0.4, 0, y + 0.2, 0)
					Kit.xf(q, sx * (Wd / 2 - 0.035), 0, zc + (0.25 if row % 2 == 1 else 0.0) * 0, 0, sx * PI / 2)
					var base := fg.size()
					fg = Kit.merge([fg, q])
			y += 0.45; row += 1
		zz += w
	b.add("stone", Co.pnt(fg, [0xc2bcae, 0x9f998c], 0.07, rng), 0.0)
	# 상판 박석 + 양옆 낮은 턱돌
	var dg := []; var cg := []
	for i in n:
		var za := -L / 2 + L * i / n; var zb := -L / 2 + L * (i + 1) / n
		var ya := deck(za, L); var yb := deck(zb, L)
		var ang := atan2(yb - ya, zb - za)
		dg.append(Kit.xf(Kit.box(Wd, 0.16, zb - za + 0.04), 0, (ya + yb) / 2 + 0.02, (za + zb) / 2, -ang, 0, 0))
		for s in [-1, 1]:
			cg.append(Kit.xf(Kit.box(0.24, 0.26, zb - za + 0.02), s * (Wd / 2 - 0.1), (ya + yb) / 2 + 0.18, (za + zb) / 2, -ang, 0, 0))
	b.add("stone", Co.pnt(Kit.merge(dg), [0xc4beb0, 0xa8a294], 0.05, rng), 0.015)
	b.add("stone", Co.pnt(Kit.merge(cg), [0xaaa497, 0x8e887c], 0.05, rng), 0.015)
	# 홍예석 띠(양쪽 면)
	for c in centers:
		for s in [-1, 1]:
			var ring := []
			for k in 9:
				var a := PI * (k + 0.5) / 9
				var st := Kit.box(0.09, 0.5, 0.36)
				Kit.xf(st, (Wd / 2 - 0.02) * s, sp + sin(a) * (r + 0.24), c + cos(a) * (r + 0.24), PI / 2 - a, 0, 0)
				ring.append(st)
			b.add("stone", Co.pnt(Kit.merge(ring), [0xd0c9b8, 0xb2ab9b], 0.05, rng), 0.0)
	var cols := []
	# 다리 위는 걸을 수 있게 비우고 양옆 턱만 막는다(상판 높이는 deck(z) 식 — anchors 참고)
	cols.append({ type = "box", minX = -Wd / 2 - 0.25, maxX = -Wd / 2 + 0.05, minZ = -L / 2, maxZ = L / 2 })
	cols.append({ type = "box", minX = Wd / 2 - 0.05, maxX = Wd / 2 + 0.25, minZ = -L / 2, maxZ = L / 2 })
	return {
		node = b.build("오작교"), colliders = cols, lights = [], occluder = false,
		footprint = Vector2(Wd + 0.4, L),
		anchors = { north_end = Vector3(0, deck(-L / 2, L), -L / 2), south_end = Vector3(0, deck(L / 2, L), L / 2), middle = Vector3(0, deck(0, L), 0) },
		deck_height = "0.35 + 1.75·clamp((L/2-|z|)/9, 0, 1)",
	}
