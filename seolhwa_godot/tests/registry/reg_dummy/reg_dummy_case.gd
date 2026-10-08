# 시험 전용 가짜 사건 스크립트(tests/registry) — 파일이 있는지만 본다(놀이 중에는 불리지 않는다)
extends RefCounted

var d

func _init(director = null) -> void:
	d = director
