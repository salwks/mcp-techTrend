# 건물 이름 — 이름 있는 건물·경내(관아·객사·광한루·향교·주막 …)의 터에 들어서면 지명 자리에 건물 이름을 띄운다.
extends RefCounted

# 키트 → 표시 이름(여기 없는 키트는 이름을 띄우지 않음)
const NAMES := {
	"landmark/gwana": "남원도호부 관아", "landmark/hyeon_gwana": "운봉현 관아",
	"landmark/gaeksa": "용성관", "landmark/gwanghallu": "광한루", "landmark/gwanghallu_pond": "광한루원",
	"landmark/hyanggyo": "남원향교", "landmark/maaebul_rock": "여원치 마애불", "landmark/hwangsan_bigak": "황산대첩비",
	"landmark/silsangsa": "실상사", "village/jumak": "주막", "village/seonghwangdang": "성황당",
	"village/mulbang_a": "물레방앗간", "village/jeongja": "정자", "village/village_square": "쉼터",
}
const EXIT_EXTRA := 3.0

var _areas: Array = []   # {name, c:Vector2, ry, half:Vector2, pri}
var current := -1

func setup(loader) -> void:
	for f in loader.files():
		var d = JSON.parse_string(FileAccess.get_file_as_string(f))
		if not (d is Dictionary): continue
		for it in d.get("items", []):
			var kit := String(it.get("kit", ""))
			if not NAMES.has(kit): continue
			var params: Dictionary = it.get("params", {}) if it.get("params") is Dictionary else {}
			var fp := Vector2.ZERO
			var f0 = it.get("footprint")
			if f0 is Array and f0.size() >= 2: fp = Vector2(float(f0[0]), float(f0[1]))
			if fp == Vector2.ZERO:
				var s = loader._script(kit)
				if s and loader._has(s, "footprint"): fp = loader.world.to_v2(s.footprint(params))
			if fp == Vector2.ZERO: fp = loader._catalog_fp(kit, params)
			if fp == Vector2.ZERO: fp = Vector2(10, 10)
			# 작은 건물이 큰 경내 안에 있으면 작은 쪽이 이긴다(광한루원 안 광한루)
			_areas.append({ name = NAMES[kit], c = Vector2(float(it.x), float(it.z)), ry = float(it.get("ry", 0.0)), half = fp / 2.0, pri = -fp.x * fp.y })

func _inside(a: Dictionary, p: Vector2, extra: float) -> bool:
	var q: Vector2 = (p - (a.c as Vector2)).rotated(-float(a.ry))
	var hf: Vector2 = a.half
	return absf(q.x) <= hf.x + extra and absf(q.y) <= hf.y + extra

# 새로 들어선 건물 이름을 돌려준다(없으면 "")
func update(pos: Vector3) -> String:
	var p := Vector2(pos.x, pos.z)
	if current >= 0 and not _inside(_areas[current], p, EXIT_EXTRA): current = -1
	var best := -1
	for i in _areas.size():
		if _inside(_areas[i], p, 0.0) and (best < 0 or _areas[i].pri > _areas[best].pri): best = i
	if best >= 0 and best != current and (current < 0 or _areas[best].pri > _areas[current].pri):
		current = best
		return _areas[best].name
	return ""
