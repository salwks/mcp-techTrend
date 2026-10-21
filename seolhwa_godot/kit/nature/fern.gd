# 숲 밑 풀(integ-mountain) — 한국 산 숲 바닥: 고사리 잎이 둥글게 휘어 퍼진 포기 + (sasa=true) 조릿대 잎 무더기.
#   예전 숲 밑 덤불(bush를 1.6~2.6배)은 멀리서 이끼 낀 둥근 바위처럼 읽혀서 바꿨다. 그림자·충돌 없음.
# params: seed, s(1), sasa(seed로)
extends RefCounted
const C := preload("res://kit/nature/_common.gd")

static func build(params: Dictionary) -> Dictionary:
	var r := Kit.Rng.new(int(params.get("seed", 1)))
	var s := float(params.get("s", 1.0))
	var sasa := bool(params.get("sasa", r.next() < 0.4))
	var b := Kit.Batch.new()
	var cols := [["#5f7a3c", "#2f4223"], ["#55703a", "#2a3b20"], ["#6a7f40", "#344526"]]
	if sasa:
		# 조릿대: 가는 줄기 끝에 길쭉한 잎 몇 장 — 무릎 높이 무더기
		var n := 9 + int(r.next() * 6)
		for i in n:
			var a := r.next() * TAU; var d := r.next() * 0.55 * s
			var hh := (0.45 + r.next() * 0.35) * s
			var x := cos(a) * d; var z := sin(a) * d
			var c: Array = C.pick(cols, r)
			for k in 3:
				var g := C.sphere(0.5, 5, 2)
				var ya := r.next() * TAU
				Kit.xf(g, x + cos(ya) * 0.12 * s, hh - k * 0.08 * s, z + sin(ya) * 0.12 * s, -0.5 - r.next() * 0.4, ya, 0, 0.07 * s, 0.02 * s, 0.32 * s)
				b.add("leaf", Kit.paint(g, C.c(c[0]), C.c(c[1]), 0.04, r), 0.0)
	else:
		# 고사리: 가운데에서 7~10장이 활처럼 휘어 바깥으로 — 잎마다 두 마디(오르다 처진다)
		var n := 7 + int(r.next() * 4)
		var c: Array = C.pick(cols, r)
		for i in n:
			var a := TAU * i / n + r.next() * 0.5
			var L := (0.55 + r.next() * 0.35) * s
			for k in 2:
				var g := C.sphere(0.5, 6, 2)
				var t := (k + 0.5) / 2.0
				var dist := L * (0.25 + t * 0.55)
				var y := (0.42 - 0.3 * t * t) * s * (0.9 + r.next() * 0.2)
				Kit.xf(g, cos(a) * dist, y, sin(a) * dist, 0.0, -a + PI / 2, (0.35 if k == 0 else -0.45), L * 0.5, 0.025 * s, 0.17 * s)
				b.add("leaf", Kit.paint(g, C.c(c[0]), C.c(c[1]), 0.05, r), 0.0)
	return C.result(b, "숲 밑 풀", [], Vector2(1.6 * s, 1.6 * s), false, { cast = false })
