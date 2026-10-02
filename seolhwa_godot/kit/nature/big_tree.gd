# 큰 정자나무 — 웹 buildings.js bigTree 이식. variant: zelkova(느티나무, 마을 어귀 정자나무) / willow(버드나무, 개울가)
#   / broadleaf(마을 가 활엽수) / persimmon(감나무, 주황 열매). 예산 맞추려고 보조 잎덩이는 detail 0.
# params: seed, variant("zelkova"), h, spread, trunk, branches, lod(0|1), bare(false)
extends RefCounted
const C := preload("res://kit/nature/_common.gd")

const PRESET := {
	zelkova = { h = 7.2, spread = 4.6, trunk = 0.55, branches = 5, leaf = [["#a2ab66", "#5f6c3e"], ["#94a05e", "#566238"]] },
	willow = { h = 5.2, spread = 3.2, trunk = 0.3, branches = 3, willow = true, leaf = [["#a9b87a", "#6d7e4a"], ["#b4bf82", "#76844e"]] },
	broadleaf = { h = 5.6, spread = 3.0, trunk = 0.32, branches = 3, leaf = [["#a8a468", "#6a6a3e"], ["#9aa262", "#5e663a"]] },
	persimmon = { h = 5.4, spread = 3.0, trunk = 0.32, branches = 3, fruit = true, leaf = [["#b2a660", "#6f6a3a"], ["#c0a256", "#7e6a3a"]] },
}
const NAMES := { zelkova = "느티나무", willow = "버드나무", broadleaf = "활엽수", persimmon = "감나무" }

static func build(params: Dictionary) -> Dictionary:
	var variant := str(params.get("variant", "zelkova"))
	var o: Dictionary = PRESET.get(variant, PRESET.zelkova).duplicate()
	for k in params: o[k] = params[k]
	var r := Kit.Rng.new(int(o.get("seed", 1)))
	var lod := int(o.get("lod", 0))
	var hgt := float(o.h); var spread := float(o.spread); var tr := float(o.trunk)
	var willow := bool(o.get("willow", false)); var fruit := bool(o.get("fruit", false))
	var b := Kit.Batch.new()
	var ol := 0.0 if lod else 1.0
	var base := Vector3(0, -0.2, 0)
	var fork := Vector3((r.next() - 0.5) * 0.6, hgt * 0.38, (r.next() - 0.5) * 0.3)
	b.add("bark", Kit.paint(C.limb_open(base, fork, tr, tr * 0.72, 6 if lod else 8), C.c("#6a5a48"), C.c("#4a3e32"), 0.05, r), 0.03 * ol)
	if not lod: b.add("bark", Kit.paint(Kit.cyl(tr * 0.9, tr * 1.6, 0.5, 8, 0, 0.05, 0), C.c("#5a4c3e"), C.c("#44392e"), 0.05, r), 0.03)
	var tips := []
	var nb := int(o.branches)
	if lod: nb = mini(nb, 3)
	for i in nb:
		var a := TAU * i / nb + r.next() * 0.6
		var tip := Vector3(cos(a) * spread * (0.5 + r.next() * 0.3), hgt * (0.7 + r.next() * 0.2), sin(a) * spread * 0.5 * (0.5 + r.next() * 0.3))
		b.add("bark", Kit.paint(C.limb_open(fork, tip, tr * 0.6, tr * 0.22, 4 if lod else 6), C.c("#6a5a48"), C.c("#4a3e32"), 0.05, r), 0.025 * ol)
		tips.append(tip)
	var cols := [{ type = "circle", x = 0.0, z = 0.0, r = tr + 0.15 }]
	var fp := Vector2(spread * 2.2, spread * 1.4)
	if bool(o.get("bare", false)):
		return C.result(b, NAMES.get(variant, "큰나무"), cols, fp, true, { height = hgt })
	var leaf: Array = o.leaf
	var blobs := [[0.0, hgt * 0.95, 0.0, spread * 0.55, 1]]
	for t in tips: blobs.append([t.x, t.y + 0.4, t.z, spread * (0.38 + r.next() * 0.12), 1])
	for i in (1 if lod else 3):
		blobs.append([(r.next() - 0.5) * spread * 1.2, hgt * (0.65 + r.next() * 0.25), (r.next() - 0.5) * spread * 0.6, spread * 0.35, 0])
	var bi := 0
	for bl in blobs:
		var x: float = bl[0]; var y: float = bl[1]; var z: float = bl[2]; var rad: float = bl[3]
		var c: Array = C.pick(leaf, r)
		var det := 0 if lod else int(bl[4])
		b.add("leaf", Kit.paint(Kit.xf(Kit.lump(rad, det, r, 0.16, 0.6 if willow else 0.72), x, y, z), C.c(c[0]), C.c(c[1]), 0.04, r), 0.045 * ol)
		if fruit and not lod:
			for k in 3:
				var th := r.next() * TAU; var ph := 0.3 + r.next() * 1.1
				b.add("organic", Kit.paint(Kit.xf(C.sphere(0.13, 4, 2), x + cos(th) * sin(ph) * rad * 0.95, y + cos(ph) * rad * 0.7, z + sin(th) * sin(ph) * rad * 0.95), C.c("#e8782e"), C.c("#c85a22"), 0.03, r), 0.0)
		if willow and bi < (2 if lod else 4):
			for k in (4 if lod else 6):
				var th := r.next() * TAU; var len := 1.6 + r.next() * 1.8
				var gx := x + cos(th) * rad * 0.85; var gz := z + sin(th) * rad * 0.85
				var g := Kit.cyl(0.1, 0.02, len, 4, 0, 0, 0, 0, 0, 0, false)
				Kit.xf(g, gx, y - len / 2, gz, (r.next() - 0.5) * 0.15, 0, (r.next() - 0.5) * 0.15)
				b.add("leaf", Kit.paint(g, C.c(c[0]), C.c(c[1]), 0.03, r), 0.0)
		bi += 1
	return C.result(b, NAMES.get(variant, "큰나무"), cols, fp, true, { height = hgt + spread * 0.5 })
