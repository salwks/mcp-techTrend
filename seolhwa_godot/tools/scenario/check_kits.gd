# 시나리오 키트 빠른 점검(문법·짓기·삼각형) — godot --headless --path . -s res://tools/scenario/check_kits.gd -- [--only=props]
extends SceneTree

const CASES := [
	["props", [{"kind": "agungi"}, {"kind": "bapsang"}, {"kind": "jangdok"}, {"kind": "muldongi"}, {"kind": "mun"}, {"kind": "deungjan"},
		{"kind": "jusang"}, {"kind": "pyeongsang"}, {"kind": "chaeksang"}, {"kind": "munseoham"}, {"kind": "jangbu"}, {"kind": "meoktong"},
		{"kind": "chaekjang"}, {"kind": "chaekdeomi"}, {"kind": "chatjan"}, {"kind": "kkeun"}, {"kind": "gamani"}, {"kind": "gireumtong"},
		{"kind": "jipsin"}, {"kind": "geumjul"}, {"kind": "jemul"}, {"kind": "byeokjido"}, {"kind": "hwaro"}]],
	["chaekbang", [{}]],
	["changgo", [{"style": "chilpae"}, {"style": "chilpae", "hatch": true}, {"style": "seogang"}, {"style": "empty"}]],
	["girokgo", [{}]],
	["yeokcham", [{}]],
	["jj_sagul", [{}]],
	["hj_islet", [{}]],
	["hj_reef", [{}, {"n": 5}]],
]

func _init() -> void:
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="): only = a.substr(7)
	var bad := 0
	for c in CASES:
		if only != "" and c[0] != only: continue
		var path := "res://kit/scenario/%s.gd" % c[0]
		if not FileAccess.file_exists(path): print("SKIP ", path); continue
		var scr = load(path)
		if scr == null or not scr.can_instantiate(): print("BAD ", path); bad += 1; continue
		for p in c[1]:
			p = p.duplicate(); p.seed = 7
			var info: Dictionary = scr.build(p)
			var tris := 0
			for mi in (info.node as Node3D).find_children("*", "MeshInstance3D", true, false):
				for s in mi.mesh.get_surface_count(): tris += mi.mesh.surface_get_array_len(s) / 3
			print("KIT %s %s tris=%d cols=%d states=%s anchors=%s interior=%s" % [c[0], JSON.stringify(p), tris, info.get("colliders", []).size(),
				JSON.stringify(info.get("states", {})), str(info.get("anchors", {}).keys()), "yes" if info.has("interior") else "no"])
			info.node.free()
	print("CHECK done bad=%d" % bad)
	quit()
