# 참나무류(활엽수) — 점엽법(點葉法) 수관: 납작한 잎덩이 여러 겹 + 덩이 윗면에 먹빛 잎점.
# kind: sangsuri(상수리·굴참나무, 저지대 — 넓고 둥근 수관, 밝은 녹색)
#       singal(신갈나무, 해발 800m 위 능선 — 낮고 비틀린 줄기, 짙고 차가운 녹색)
# params: seed, kind("sangsuri"), s(1), lod(0|1)
extends RefCounted
const C := preload("res://kit/nature/_common.gd")

const KINDS := {
	sangsuri = { h = 7.6, spread = 3.4, trunk = 0.3, twist = 0.5, leaf = [["#a2a866", "#5e6a3c"], ["#97a05e", "#56623a"], ["#aaa96a", "#666a3e"]], dot = "#46532f", bark = ["#857a68", "#564b3e"] },
	singal = { h = 5.8, spread = 2.9, trunk = 0.26, twist = 1.1, leaf = [["#8d9e60", "#4b5c36"], ["#839858", "#455632"], ["#94a064", "#525e38"]], dot = "#36452a", bark = ["#8a8270", "#5a5244"] },
}

static func build(params: Dictionary) -> Dictionary:
	var kind := str(params.get("kind", "sangsuri"))
	var K: Dictionary = KINDS.get(kind, KINDS.sangsuri)
	var r := Kit.Rng.new(int(params.get("seed", 1)))
	var s := float(params.get("s", 1.0))
	var lod := int(params.get("lod", 0))
	var b := Kit.Batch.new()
	var ol := 0.0 if lod else 1.0
	var h: float = K.h * s * (0.85 + r.next() * 0.3)
	var sp: float = K.spread * s * (0.85 + r.next() * 0.3)
	var tr: float = K.trunk * s
	var bark: Array = K.bark
	# 줄기: 두 마디로 살짝 굽음 → 갈래
	var p0 := Vector3(0, -0.3, 0)
	var p1 := Vector3((r.next() - 0.5) * K.twist * s, h * 0.28, (r.next() - 0.5) * 0.3 * s)
	var fork := Vector3(p1.x + (r.next() - 0.5) * K.twist * s, h * 0.4, p1.z + (r.next() - 0.5) * 0.3 * s)
	b.add("bark", Kit.paint(C.limb_open(p0, p1, tr, tr * 0.85, 5 if lod else 6), C.c(bark[0]), C.c(bark[1]), 0.05, r), 0.025 * s * ol)
	b.add("bark", Kit.paint(C.limb_open(p1, fork, tr * 0.85, tr * 0.68, 5 if lod else 6), C.c(bark[0]), C.c(bark[1]), 0.05, r), 0.022 * s * ol)
	var nb := 2 if lod else 3
	var tips := []
	for i in nb:
		var a := TAU * i / nb + r.next() * 0.9
		var tip := Vector3(fork.x + cos(a) * sp * (0.45 + r.next() * 0.25), h * (0.6 + r.next() * 0.14), fork.z + sin(a) * sp * 0.4 * (0.5 + r.next() * 0.4))
		b.add("bark", Kit.paint(C.limb_open(fork, tip, tr * 0.55, tr * 0.2, 4 if lod else 5), C.c(bark[0]), C.c(bark[1]), 0.05, r), 0.018 * s * ol)
		tips.append(tip)
	# 잎덩이: 꼭대기 하나 + 가지 끝마다 + (가까이선) 사이를 메우는 작은 덩이. 납작(sy)하게 겹쳐 층을 낸다
	var leaf: Array = K.leaf
	var blobs := [[fork.x, h * 0.86, fork.z, sp * 0.6, 1]]
	for t in tips: blobs.append([t.x, t.y + 0.25 * s, t.z, sp * (0.48 + r.next() * 0.1), 1])
	if not lod:
		for i in 1:
			var a := r.next() * TAU
			blobs.append([fork.x + cos(a) * sp * 0.55, h * (0.62 + r.next() * 0.3), fork.z + sin(a) * sp * 0.35, sp * (0.3 + r.next() * 0.08), 0])
	var dots := 0
	for bl in blobs:
		var x: float = bl[0]; var y: float = bl[1]; var z: float = bl[2]; var rad: float = bl[3]
		var c: Array = C.pick(leaf, r)
		var det := 0 if lod else int(bl[4])
		var blob := Kit.lump(rad, 0, r, 0.2, 0.58) if det == 0 else C.lumpy(rad, r, 0.2, 0.58)
		b.add("leaf", Kit.paint(Kit.xf(blob, x, y, z), C.c(c[0]), C.c(c[1]), 0.05, r), 0.04 * s * ol)
		# 점엽: 덩이 윗면·앞면에 짙은 잎점(납작한 작은 덩이)
		if not lod and bl[4] == 1:
			for k in 4:
				var th := r.next() * TAU; var ph := 0.15 + r.next() * 1.1
				var d := C.sphere(0.26 * s, 4, 2)
				Kit.xf(d, x + cos(th) * sin(ph) * rad * 1.08, y + cos(ph) * rad * 0.58 * 1.12, z + sin(th) * sin(ph) * rad * 1.08, 0, r.next() * 3, 0, 1, 0.4, 1)
				b.add("organic", Kit.paint(d, C.c(K.dot), C.c(K.dot), 0.03, r), 0.0)
				dots += 1
	return C.result(b, "신갈나무" if kind == "singal" else "참나무", [{ type = "circle", x = 0.0, z = 0.0, r = tr + 0.1 }], Vector2(sp * 2.2, sp * 1.6), true, { height = h + sp * 0.3 })
