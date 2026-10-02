# 담 긴 구간 프리셋 — 길 따라 꺾은선(points)으로 돌담·토담·싸리울을 잇는다. 마을 길가·고샅 채우기용.
# params: seed, kind("stone_lite"|"stone"|"todam_thatch"|"todam_tile"|"fence_lite"|"fence"), points([[x,z],…] 로컬, 없으면 18m 완만한 곡선),
#         h(종류별 기본), closed(false), gaps([구간 번호…] 비워 둘 구간 — 골목·사립 자리), jitter(0: 꼭짓점 흔들기 m)
# 삼각형(대략, m당): stone 220 / stone_lite 90 / todam 50~70 / fence 160 / fence_lite 35.  긴 구간은 lite 종류를 권한다.
extends RefCounted
const C := preload("res://kit/village/_common.gd")
const SW := preload("res://kit/village/stone_wall.gd")
const TD := preload("res://kit/village/todam.gd")
const FE := preload("res://kit/village/fence.gd")

const DEFAULT_PTS := [[-9.0, 0.0], [-4.5, 0.5], [0.0, 0.7], [4.5, 0.4], [9.0, -0.3]]

static func build(params: Dictionary) -> Dictionary:
	var m := C.M.new(int(params.get("seed", 1)))
	var kind: String = params.get("kind", "stone_lite")
	var pts: Array = params.get("points", DEFAULT_PTS)
	var jit: float = params.get("jitter", 0.0)
	var P := []
	for q in pts: P.append(Vector2(float(q[0]) + (m.r() - 0.5) * jit, float(q[1]) + (m.r() - 0.5) * jit))
	if params.get("closed", false) and P.size() > 2: P.append(P[0])
	var gaps: Array = params.get("gaps", [])
	var mn := Vector2(INF, INF); var mx := Vector2(-INF, -INF)
	for p in P: mn = mn.min(p); mx = mx.max(p)
	for i in P.size() - 1:
		if i in gaps or float(i) in gaps: continue
		var a: Vector2 = P[i]; var b: Vector2 = P[i + 1]
		match kind:
			"stone": SW.draw(m, a.x, a.y, b.x, b.y, float(params.get("h", 1.3)), false)
			"stone_lite": SW.draw(m, a.x, a.y, b.x, b.y, float(params.get("h", 1.2)), true)
			"todam_thatch": TD.draw(m, a.x, a.y, b.x, b.y, float(params.get("h", 1.5)), "thatch")
			"todam_tile": TD.draw(m, a.x, a.y, b.x, b.y, float(params.get("h", 1.6)), "tile", 0.5)
			"fence": FE.draw(m, a.x, a.y, b.x, b.y, float(params.get("h", 1.15)), false)
			_: FE.draw(m, a.x, a.y, b.x, b.y, float(params.get("h", 1.15)), true)
	var res := m.result("담_" + kind, (mx - mn) + Vector2(0.8, 0.8), kind.begins_with("todam") or kind.begins_with("stone"))
	res.bounds = { minX = mn.x - 0.4, maxX = mx.x + 0.4, minZ = mn.y - 0.4, maxZ = mx.y + 0.4 }
	return res
