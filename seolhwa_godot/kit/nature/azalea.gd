# 진달래·철쭉 덤불. kind: jindallae(진달래 — 저지대 야산, 분홍빛 자주, 잎보다 꽃이 먼저) / cheoljjuk(산철쭉 — 운봉 바래봉·세걸산 고원의 철쭉군락, 진분홍)
# params: seed, kind("jindallae"), s(1), bloom(true)
extends RefCounted
const C := preload("res://kit/nature/_common.gd")
const K := {
	jindallae = { leaf = [["#8c9460", "#525a3a"]], flower = ["#e08fb4", "#c2709a"], n = 14, lumps = 2 },
	cheoljjuk = { leaf = [["#7f9458", "#465734"], ["#879a5e", "#4c5c38"]], flower = ["#e46f9a", "#c04f7c"], n = 16, lumps = 3 },
}

static func build(params: Dictionary) -> Dictionary:
	var kind := str(params.get("kind", "jindallae"))
	var k: Dictionary = K.get(kind, K.jindallae)
	var r := Kit.Rng.new(int(params.get("seed", 1)))
	var s := float(params.get("s", 1.0))
	var bloom := bool(params.get("bloom", true))
	var b := Kit.Batch.new()
	var spots := []
	for i in int(k.lumps):
		var rad := (0.45 + r.next() * 0.3) * s
		var x := (r.next() - 0.5) * 1.0 * s; var z := (r.next() - 0.5) * 0.6 * s
		var g := C.sphere(rad, 7, 3)
		Kit.xf(g, x, 0.25 * s, z, 0, r.next() * 3, 0, 1, 0.66, 0.85)
		var c: Array = C.pick(k.leaf, r)
		b.add("leaf", Kit.paint(g, C.c(c[0]), C.c(c[1]), 0.04, r), 0.025)
		spots.append([x, z, rad])
	# 가는 가지 몇(진달래는 잎이 성겨 가지가 보인다)
	for i in 3:
		var sp: Array = spots[i % spots.size()]
		b.add("bark", Kit.paint(Kit.limb(Vector3(sp[0] * 0.4, 0, sp[1] * 0.4), Vector3(sp[0] + (r.next() - 0.5) * 0.5, (0.55 + r.next() * 0.2) * s, sp[1]), 0.025, 0.012, 3), C.c("#6a5442"), C.c("#4e3e32"), 0.03, r), 0.0)
	if bloom:
		var fc: Array = k.flower
		for i in int(k.n):
			var sp: Array = C.pick(spots, r)
			var th := r.next() * TAU; var ph := 0.2 + r.next() * 1.1
			var rad: float = sp[2]
			var g := C.sphere(0.085 * s, 4, 2)
			Kit.xf(g, sp[0] + cos(th) * sin(ph) * rad, 0.25 * s + cos(ph) * rad * 0.66, sp[1] + sin(th) * sin(ph) * rad * 0.85)
			b.add("organic", Kit.paint(g, C.c(fc[0]), C.c(fc[1]), 0.06, r), 0.0)
	return C.result(b, "철쭉" if kind == "cheoljjuk" else "진달래", [], Vector2(1.8 * s, 1.3 * s), false)
