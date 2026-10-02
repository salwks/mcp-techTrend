# 감나무 — big_tree persimmon 변형(마을 터 가장자리). params: seed, s(1), lod
extends RefCounted
const BigTree := preload("res://kit/nature/big_tree.gd")

static func build(params: Dictionary) -> Dictionary:
	var s := float(params.get("s", 0.7))
	var p := { variant = "persimmon", seed = params.get("seed", 1), lod = params.get("lod", 0), h = 6 * s + 1.5, spread = 3.4 * s + 0.6 }
	return BigTree.build(p)
