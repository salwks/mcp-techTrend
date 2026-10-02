# 대숲 한 무리 — 왕대·솜대 따위 줄기 여럿 + 위쪽 깃털 같은 잎 무더기. 남원 일대 마을 뒤 대밭(가설: 1870년에도 흔했다).
# params: seed, n(12), r(1.6, 무리 반지름), h(8), lod(0|1)
extends RefCounted
const C := preload("res://kit/nature/_common.gd")

static func build(params: Dictionary) -> Dictionary:
	var r := Kit.Rng.new(int(params.get("seed", 1)))
	var lod := int(params.get("lod", 0))
	var n := int(params.get("n", 12))
	if lod: n = mini(n, 7)
	var R := float(params.get("r", 1.6))
	var H := float(params.get("h", 8.0))
	var b := Kit.Batch.new()
	var tops := []
	for i in n:
		var a := r.next() * TAU; var d := sqrt(r.next()) * R
		var base := Vector3(cos(a) * d, -0.2, sin(a) * d)
		var h := H * (0.7 + r.next() * 0.35)
		var lean := Vector3(cos(a), 0, sin(a)) * (0.6 + r.next() * 1.2) + Vector3((r.next() - 0.5) * 0.6, 0, (r.next() - 0.5) * 0.6)
		var top := base + Vector3(0, h, 0) + lean
		var cr := 0.06 + r.next() * 0.03
		b.add("smooth", Kit.paint(Kit.limb(base, top, cr, cr * 0.6, 4), C.c("#a4b06c"), C.c("#6e7c46"), 0.06, r), 0.0 if lod else 0.012)
		# 마디: 짙은 고리 두어 개
		if not lod:
			for k in 1:
				var t := 0.35 + r.next() * 0.05
				var p := base.lerp(top, t)
				var dv := (top - base).normalized() * 0.03
				var ring := Kit.cyl(cr * 1.3, cr * 1.3, 0.06, 4, 0, 0, 0, 0, 0, 0, false)
				Kit.apply(ring, Transform3D(Basis(Quaternion(Vector3.UP, dv.normalized())), p))
				b.add("flat", Kit.paint(ring, C.c("#5e6a3a"), C.c("#5e6a3a"), 0.02, r), 0.0)
		tops.append([base, top])
	# 잎: 줄기 위쪽에 줄기 방향으로 길쭉한 깃털 덩이(붓으로 세워 친 댓잎 무더기 느낌) — 수평 판처럼 보이지 않게 세로로
	var leaf := [["#b0bc6e", "#5e703c"], ["#a2b466", "#566a38"], ["#bac27a", "#687442"]]
	for pr in tops:
		var base: Vector3 = pr[0]; var top: Vector3 = pr[1]
		var axis := (top - base).normalized()
		var out := Vector3(axis.x, 0, axis.z).normalized() if Vector2(axis.x, axis.z).length() > 0.01 else Vector3.RIGHT
		for k in (1 if lod else 3):
			var tt: float = [0.66, 0.86, 0.52][k]
			var p := base.lerp(top, tt)
			var c: Array = C.pick(leaf, r)
			var g := Kit.lump(0.42 + r.next() * 0.12, 0, r, 0.35, 1.0)
			var ln: float = [2.4, 1.8, 1.6][k]
			Kit.xf(g, 0, 0, 0, 0, r.next() * TAU, 0, 0.8, ln, 0.8)
			# 줄기 방향 + 바깥으로 조금 더 기울임
			var side := Vector3(-out.z, 0, out.x) * (0.6 if k == 2 else 0.0)
			var lean: float = [0.25, 0.55, 0.9][k]
			var dir := (axis + out * lean + side).normalized()
			Kit.apply(g, Transform3D(Basis(Quaternion(Vector3.UP, dir)), p + (out + side) * (0.25 + k * 0.2)))
			b.add("leaf", Kit.paint(g, C.c(c[0]), C.c(c[1]), 0.05, r), 0.025 if (k == 0 and not lod) else 0.0)
	return C.result(b, "대숲", [{ type = "circle", x = 0.0, z = 0.0, r = R * 0.75 }], Vector2(R * 2 + 2.5, R * 2 + 2.5), true, { height = H * 1.05 })
