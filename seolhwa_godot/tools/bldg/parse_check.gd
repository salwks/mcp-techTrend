# 건물 빌더 스크립트 문법 점검(헤드리스): 모두 불러 보고 실패하면 종료 코드 1
extends SceneTree
func _init() -> void:
	var bad := 0
	for p in ["res://kit/bldg/building.gd", "res://kit/bldg/compound.gd", "res://kit/bldg/gate.gd", "res://scripts/region/bldg_gallery.gd", "res://scripts/region/bldg_integ.gd",
			"res://tools/bldg/roof_check.gd", "res://tools/bldg/face_check.gd", "res://tools/bldg/gallery_place.gd"]:
		var s = load(p)
		if s == null or not (s as Script).can_instantiate(): print("PARSE FAIL ", p); bad += 1
	print("PARSE ok" if bad == 0 else "PARSE bad=%d" % bad)
	quit(bad)
