# 문화권 비교 그림(눈가림 시험용) — 문화권마다 대표 집 묶음 하나를 4×2로 늘어놓는다. 글자 없음.
#   godot --path . res://scenes/kit_preview.tscn -- --scene=res://kit/culture/_compare.gd --shot=shots/kit/culture/compare.png --pitch=58 --nofog
#   --set=large 이면 큰 집(기와·반가) 판.
# 순서(왼→오른, 위→아래): 호남 · 영남 · 기호 · 관동 / 해서 · 관서 · 관북 · 탐라
extends RefCounted

const SETS := {
	small = [
		["village/house_compound", { seed = 3, size = "medium", plan = "il" }],
		["culture/yeongnam/compound", { seed = 1, size = "medium" }],
		["culture/giho/compound", { seed = 1, size = "medium" }],
		["culture/gwandong/compound", { seed = 1, size = "small" }],
		["culture/haeseo/compound", { seed = 1, size = "medium" }],
		["culture/gwanseo/compound", { seed = 1, size = "small" }],
		["culture/gwanbuk/compound", { seed = 1, size = "medium" }],
		["culture/tamna/compound", { seed = 1, size = "medium" }],
	],
	large = [
		["village/house_compound", { seed = 3, size = "large" }],
		["culture/yeongnam/compound", { seed = 1, size = "large" }],
		["culture/giho/compound", { seed = 1, size = "large" }],
		["culture/gwandong/compound", { seed = 1, size = "large" }],
		["culture/haeseo/compound", { seed = 1, size = "large" }],
		["culture/gwanseo/compound", { seed = 1, size = "large" }],
		["culture/gwanbuk/compound", { seed = 1, size = "large" }],
		["culture/giho/compound", { seed = 2, size = "city" }],
	],
}

static func make() -> Node3D:
	var set := "small"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--set="): set = a.trim_prefix("--set=")
	var root := Node3D.new(); root.name = "compare"
	var list: Array = SETS[set]
	var gap := 40.0 if set == "large" else 30.0
	for i in list.size():
		var it: Array = list[i]
		var info: Dictionary = load("res://kit/%s.gd" % it[0]).build(it[1])
		var n: Node3D = info.node
		n.position = Vector3((i % 4 - 1.5) * gap, 0, (i / 4 - 0.5) * gap)
		root.add_child(n)
	return root
