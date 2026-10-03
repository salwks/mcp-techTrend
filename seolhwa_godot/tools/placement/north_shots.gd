# placement-north 점검 사진: 권역 장면 하나를 띄워 여러 자리를 차례로 찍는다(한 번 불러오기로 여러 장).
#   godot --path . -s res://tools/placement/north_shots.gd -- --region=GG_HANYANG --time=10 \
#         --nshots="x,z,이름[,거리,피치];x,z,이름;..." --nshotdir=shots/placement/north
# 거리·피치를 주면 그 시점(높은 시점), 없으면 기본 게임 카메라. region_main의 _shot_at/_save를 그대로 쓴다.
extends SceneTree

var _args := {}

func _init() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		_args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	change_scene_to_file("res://scenes/region.tscn")
	_go.call_deferred()

func _go() -> void:
	for i in 30: await process_frame
	var m = current_scene
	var n := 0
	while m._loading and n < 6000:
		await process_frame; n += 1
	var dir: String = ProjectSettings.globalize_path("res://").path_join(_args.get("nshotdir", "shots/placement/north"))
	var h := float(_args.get("time", "10"))
	for s in String(_args.get("nshots", "")).split(";", false):
		var p := s.split(",")
		if p.size() > 4: m.rig.override = { distance = float(p[3]), pitch = float(p[4]), fov = 30.0 }
		else: m.rig.override = null
		await m._shot_at(float(p[0]), float(p[1]), h)
		for k in int(_args.get("settle", "40")): await process_frame
		m._save(dir.path_join(p[2] + ".png"))
	m._quit()
