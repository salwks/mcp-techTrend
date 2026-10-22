# 고을 짜임 필지(organic lot) — kit/bldg/organic.gd가 짠 조각 목록을 그대로 놓는다(필지 다각형 담 + 대문 + 집 + 마당 것).
#   params: { type, seed, fp: [w, d](터 고르기·마당 흙 사각 — 필지 바운딩 사각보다 1m씩 안), pieces: [{tag, kit, params, x, z, ry}…](필지 로컬), poly: [[x,z]…](필지 로컬, 참고·검사용) }
#   배치 로더는 layout()으로 조각마다 따로 짓는다(건물 단위 LOD·가림·스트리밍 — bldg/compound와 같은 길).
extends RefCounted
const HC := preload("res://kit/village/house_compound.gd")

static func layout(params: Dictionary) -> Array:
	return (params.get("pieces", []) as Array).duplicate(true)

static func footprint(params: Dictionary) -> Vector2:
	var f: Array = params.get("fp", [10.0, 10.0])
	return Vector2(float(f[0]), float(f[1]))

static func build(params: Dictionary) -> Dictionary:
	var ps := layout(params)
	var res := HC.compose(ps, "필지_" + String(params.get("type", "")), footprint(params))
	var out := []
	for e in ps:
		var q: Dictionary = e.duplicate()
		q.xform = Transform3D(Basis(Vector3.UP, float(e.ry)), Vector3(float(e.x), 0, float(e.z)))
		out.append(q)
	res.pieces = out
	return res
