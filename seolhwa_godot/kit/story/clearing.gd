# 빈터(보이지 않는 배치 항목) — footprint만 가진다. 배치 로더가 그 안의 식생을 비우고(clear_veg), 원하면 땅을 고르고(flatten)
# 마당 흙(yard)을 칠한다. 싸움터(마당·숲속 빈터·고갯마루 아래 숲)를 나무 없이 비워 두는 데 쓴다.
# params: w(16), d(16)
extends RefCounted

static func build(params: Dictionary) -> Dictionary:
	var n := Node3D.new()
	n.name = "빈터"
	return { node = n, colliders = [], lights = [], occluder = false, footprint = Vector2(float(params.get("w", 16.0)), float(params.get("d", 16.0))) }

static func footprint(params: Dictionary) -> Vector2:
	return Vector2(float(params.get("w", 16.0)), float(params.get("d", 16.0)))
