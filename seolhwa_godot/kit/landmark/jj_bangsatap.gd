# 방사탑(防邪塔, 거욱대) — 제주 마을 어귀·허한 방위에 쌓은 돌탑(액막이). 현무암 막돌을 원뿔대로 쌓고(높이 2~4m) 꼭대기에 새(까마귀) 모양 돌이나 사람 모양 석상을 얹음.
# 조선 후기 마을 신앙(1870 무렵 있었다고 봄). 크기는 현존 탑 평균 가설. params: seed, height(3.2), top("bird"|"man"|"stone")
extends RefCounted

const Co = preload("res://kit/landmark/_common.gd")
const Hub = preload("res://kit/landmark/_hub.gd")

static func build(params: Dictionary) -> Dictionary:
	var rng := Kit.Rng.new(int(params.get("seed", 1)))
	var H: float = float(params.get("height", 3.2))
	var b := Kit.Batch.new()
	var g := []
	var r0 := H * 0.6; var r1 := H * 0.32
	var rows := roundi(H / 0.5)
	for k in rows:
		var t := float(k) / rows
		var rr := lerpf(r0, r1, t)
		var y := H * t
		var n := maxi(6, roundi(TAU * rr / 0.7))
		for i in n:
			var a := TAU * (i + (0.5 if k % 2 == 1 else 0.0)) / n
			var st := Kit.box(rng.between(0.6, 0.8), H / rows * 1.05, rng.between(0.35, 0.5))
			Kit.xf(st, cos(a) * rr, y + H / rows * 0.5, sin(a) * rr, rng.between(-0.12, 0.12), -a + PI / 2, rng.between(-0.1, 0.1))
			g.append(st)
	b.add("stone", Co.pnt(Kit.merge(g), Hub.BASALT, 0.14, rng), 0.0)
	b.add("stone", Co.pnt(Kit.cyl(r1 * 0.95, r0 * 0.95, H, 10, 0, H / 2, 0), [0x3a3733]), 0.02)
	b.add("stone", Co.pnt(Kit.cyl(r1 + 0.1, r1 + 0.15, 0.2, 10, 0, H + 0.1, 0), Hub.BASALT_L, 0.06, rng), 0.015)
	var top: String = str(params.get("top", "bird"))
	var tg := []
	if top == "bird":
		tg.append(Kit.xf(Kit.box(0.18, 0.5, 0.16), 0, H + 0.45, 0))
		tg.append(Kit.xf(Kit.box(0.12, 0.12, 0.36), 0, H + 0.72, 0.1))
	elif top == "man":
		tg.append(Kit.cyl(0.18, 0.22, 0.6, 7, 0, H + 0.5, 0))
		var hd := Kit.lump(0.16, 0, rng, 0.05, 1.2); Kit.xf(hd, 0, H + 0.95, 0); tg.append(hd)
	else:
		var st := Kit.lump(0.35, 0, rng, 0.2, 0.8); Kit.xf(st, 0, H + 0.35, 0); tg.append(st)
	b.add("stone", Co.pnt(Kit.merge(tg), Hub.BASALT_L, 0.06, rng), 0.015)
	return {
		node = b.build("방사탑"), colliders = [{ type = "circle", x = 0.0, z = 0.0, r = r0 + 0.2 }], lights = [], occluder = H > 3.0,
		footprint = Vector2(r0 * 2 + 0.6, r0 * 2 + 0.6), anchors = { front = Vector3(0, 0, r0 + 1.0) },
	}
