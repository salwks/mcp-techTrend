# 한양도성 성벽 모듈(산 능선용) — 로컬 x축 방향 length m, 바깥 +z. rise(m)만큼 x+ 쪽이 높아지는 경사를 계단식 단(step)으로 나눠 쌓는다
# (각 단은 수평 성벽 + 여장, 단 사이 높이차). 한양도성: 둘레 약 18.6km, 높이 5~8m, 태조·세종·숙종 때 쌓은 돌 모양이 다름(숙종 때 큰 네모 돌).
# 1870년에는 전 구간이 서 있었다. 높이·단 길이는 가설. 각 단은 땅속으로 (단 높이차 + 1.2m) 내려 경사에서 뜨지 않음.
# params: seed, length(20), rise(0: 평지, ±값: x+ 끝이 그만큼 높음), height(5.5), step(4.0: 단 길이 최소)
extends RefCounted

const S = preload("res://kit/landmark/_seong.gd")

static func build(params: Dictionary) -> Dictionary:
	var rng := Kit.Rng.new(int(params.get("seed", 1)))
	var L: float = float(params.get("length", 20.0))
	var rise: float = float(params.get("rise", 0.0))
	var H: float = float(params.get("height", 5.5))
	var t := 4.2
	var n := 1
	if absf(rise) > 0.05:
		n = clampi(ceili(absf(rise) / 0.9), 1, maxi(1, floori(L / float(params.get("step", 4.0)))))
	var d := absf(rise) / n
	var root := Node3D.new(); root.name = "한양도성"
	for i in n:
		var b := Kit.Batch.new()
		var x0 := -L / 2 + L * i / n; var x1 := -L / 2 + L * (i + 1) / n
		var yc := rise * ((i + 0.5) / n - 0.5)
		S.wall_run(b, rng, x0 - 0.02, x1 + 0.02, 0.0, H + d, t, true)
		var nd: Node3D = b.build("단%d" % i)
		nd.position = Vector3(0, yc - d / 2, 0)
		root.add_child(nd)
	return {
		node = root, colliders = [{ type = "box", minX = -L / 2, maxX = L / 2, minZ = -t / 2 - 0.1, maxZ = t / 2 + 0.35 }], lights = [], occluder = true,
		footprint = Vector2(L, t + 0.6), anchors = { outside = Vector3(0, 0, t / 2 + 2.0), inside = Vector3(0, 0, -t / 2 - 2.0), walk_w = Vector3(-L / 2, H - rise / 2, 0), walk_e = Vector3(L / 2, H + rise / 2, 0) },
		slope = rise / L,
	}
