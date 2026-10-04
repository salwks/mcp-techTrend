# 시나리오 세계 API 시험 — region.tscn을 자식으로 띄우고 --scsteps의 단계를 차례로 한다.
#   godot --path . res://tools/scenario/sc_test.tscn -- --region=GG_HANYANG --nostory --warp=x,z --time=11 \
#     --scsteps="wait:30;state:hy_sc_chilpae_changgo_2:FIRE_2;wait:60;shot:shots/scenario/t1.png;quit"
# 단계: wait:프레임 · warp:x,z · decal:종류:x,z[,크기,ry] · state:키:상태 · decals:그룹:on|off · trail:종류:x,z,x,z… · weather:종류[:초[:페이드]] · release
#       time:시각[:초[:페이드]] · shot:경로 · anchor:id:이름(출력) · print · quit
extends Node

var rm   # region_main

func _ready() -> void:
	rm = get_child(0)
	_run.call_deferred()

func _frames(n: int) -> void:
	for i in n: await get_tree().process_frame

func _run() -> void:
	var steps := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--scsteps="): steps = a.substr(10)
	while rm._loading: await _frames(5)
	await _frames(10)
	for st in steps.split(";", false):
		var p := st.split(":")
		match p[0]:
			"wait": await _frames(int(p[1]))
			"warp":
				var c := p[1].split(",")
				rm.teleport(float(c[0]), float(c[1])); await _frames(20)
			"state": print("SCT state %s=%s ok=%s" % [p[1], p[2], rm.world.set_prop_state(p[1], p[2])])
			"decals": rm.world.decals.set_group_visible(p[1], p[2] == "on"); print("SCT decals %s %s n=%d" % [p[1], p[2], rm.world.decals.ids_in(p[1]).size()])
			"trail":
				var c := p[2].split(",")
				var pts := []
				for i in range(0, c.size() - 1, 2): pts.append(Vector2(float(c[i]), float(c[i + 1])))
				print("SCT trail n=%d" % rm.world.decals.trail("sct_trail", p[1], pts).size())
			"decal":
				var c := p[2].split(",")
				print("SCT decal ", rm.world.decals.add({ kind = p[1], x = float(c[0]), z = float(c[1]), size = float(c[2]) if c.size() > 2 else 1.0, ry = float(c[3]) if c.size() > 3 else 0.0 }))
			"weather": print("SCT weather ", rm.weather.force(p[1], float(p[2]) if p.size() > 2 else -1.0, float(p[3]) if p.size() > 3 else 0.0), " ", rm.weather.label())
			"release": rm.weather.release(0.0)
			"time": rm.weather.force_time(float(p[1]), float(p[2]) if p.size() > 2 else -1.0, float(p[3]) if p.size() > 3 else 0.0)
			"anchor": print("SCT anchor %s.%s = %s" % [p[1], p[2], rm.world.prop_anchor(p[1], p[2])])
			"interior": print("SCT interior %s = %s" % [p[1], rm.world.interior_by_id(p[1])])
			"shot":
				await RenderingServer.frame_post_draw
				rm._save(ProjectSettings.globalize_path("res://").path_join(p[1])); print("SCT shot ", p[1], " fps=", Engine.get_frames_per_second(), " pos=", rm.player_pos)
			"print": print("SCT ids ", rm.world.props.ids("hy_sc").size(), " lights=", rm.world.lights.size())
			"quit": rm._quit(); return
