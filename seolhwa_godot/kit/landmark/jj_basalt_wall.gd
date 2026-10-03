# 제주 현무암 돌담(관아·삼성혈 둘레): 네모 둘레(w×d, 원점 가운데) 또는 꺾은선(line). gates = [[x, z, 반폭]] 틈.
# 높이 1.6m 막쌓기(가설). params: seed, w, d, line([[x,z],…] 있으면 둘레 대신), gates, height(1.6)
extends RefCounted

const Co = preload("res://kit/landmark/_common.gd")
const Hub = preload("res://kit/landmark/_hub.gd")

static func build(params: Dictionary) -> Dictionary:
	var rng := Kit.Rng.new(int(params.get("seed", 1)))
	var b := Kit.Batch.new()
	var h: float = float(params.get("height", 1.6))
	var gates: Array = params.get("gates", [])
	var cols := []
	if params.has("line"):
		var ln: Array = params.line
		for i in ln.size() - 1:
			var a := Vector2(ln[i][0], ln[i][1]); var c := Vector2(ln[i + 1][0], ln[i + 1][1])
			cols.append_array(_seg(b, rng, a, c, gates, h))
	else:
		var hw: float = float(params.get("w", 20.0)) / 2; var hd: float = float(params.get("d", 20.0)) / 2
		cols = Hub.basalt_loop(b, rng, [Vector2(-hw, -hd), Vector2(hw, -hd), Vector2(hw, hd), Vector2(-hw, hd)], gates, h)
	return { node = b.build("돌담"), colliders = cols, lights = [], occluder = false, footprint = Vector2(float(params.get("w", 20.0)), maxf(1.0, float(params.get("d", 20.0)))), anchors = {} }

static func _seg(b, rng: Kit.Rng, a: Vector2, c: Vector2, gates: Array, h: float) -> Array:
	var L := a.distance_to(c); var dir := (c - a) / L
	var cuts := []
	for gp in gates:
		var q := Vector2(gp[0], gp[1]); var t := (q - a).dot(dir)
		if absf((q - a).cross(dir)) < 1.0 and t > 0 and t < L and float(gp[2]) > 0: cuts.append([t - float(gp[2]), t + float(gp[2])])
	var out := []
	var s0 := 0.0
	for cu in cuts:
		if cu[0] - s0 > 0.3: out.append(Hub.basalt_wall(b, rng, a + dir * s0, a + dir * float(cu[0]), h))
		s0 = cu[1]
	if L - s0 > 0.3: out.append(Hub.basalt_wall(b, rng, a + dir * s0, c, h))
	return out
