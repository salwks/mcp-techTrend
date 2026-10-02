# 나란히 보기: 웹에서 옮긴 소나무·바위 곁에 새 모델들을 세워 어울림을 본다.
#   godot --path . res://scenes/kit_preview.tscn -- --scene=res://kit/nature/lineup_preview.gd --shot=shots/kit/nature/lineup.png --pitch=30
# --row=trees|rocks|small (기본 trees)
extends RefCounted

const ROWS := {
	trees = [["pine", {}], ["oak", { kind = "sangsuri" }], ["fir", {}], ["oak", { kind = "singal" }], ["korean_fir", {}], ["deadwood", {}], ["big_tree", { variant = "willow" }], ["persimmon", {}], ["bamboo", {}], ["pine", {}], ["big_tree", { variant = "zelkova" }]],
	rocks = [["rock", { s = 1.0 }], ["boulder", {}], ["cliff", {}], ["rock", { s = 1.6 }], ["slab_rock", {}], ["stream_stones", {}], ["pine", {}], ["gravel", {}], ["rock", { s = 0.6 }]],
	small = [["bush", {}], ["azalea", { kind = "jindallae" }], ["azalea", { kind = "cheoljjuk" }], ["bush", { flowers = true }], ["reeds", {}], ["grass", { kind = "eoksae" }], ["cover", { kind = "meadow" }], ["crop", { kind = "millet" }], ["rice_tuft", { patch = 3 }], ["flowers", {}], ["rock", { s = 0.5 }]],
}

static func make() -> Node3D:
	var row := "trees"
	for s in OS.get_cmdline_user_args():
		if s.begins_with("--row="): row = s.substr(6)
	var root := Node3D.new()
	var x := 0.0
	var items: Array = ROWS[row]
	var gap := 1.2 if row == "small" else 1.5
	for it in items:
		var p: Dictionary = (it[1] as Dictionary).duplicate()
		p.seed = 3
		var info: Dictionary = load("res://kit/nature/%s.gd" % it[0]).build(p)
		var w: float = (info.footprint as Vector2).x
		x += w * 0.5
		(info.node as Node3D).position = Vector3(x, 0, 0)
		root.add_child(info.node)
		x += w * 0.5 + gap
	for c in root.get_children(): (c as Node3D).position.x -= x * 0.5
	return root
