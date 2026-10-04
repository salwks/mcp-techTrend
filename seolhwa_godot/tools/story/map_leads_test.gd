# 지도 사건 표지(map_leads) 시험 — 저장 상태(fixture)마다 보여야 할 표지·숨어야 할 표지를 센다(헤드리스).
#   godot --headless --path . -s res://tools/story/map_leads_test.gd
#   fixture: tools/story/map_leads_fixtures.json [{case, note, state, vars, visible[], hidden[], requires_met?}]
#   또 모든 사건의 표지 'at'이 앵커로 풀리는지(인물 id 제외) 본다. 끝 줄: MAPLEADS PASS n / MAPLEADS FAIL …
extends SceneTree

const MapLeads := preload("res://scripts/region/map_leads.gd")

func _init() -> void:
	var fx = JSON.parse_string(FileAccess.get_file_as_string("res://tools/story/map_leads_fixtures.json"))
	var fails := 0
	var n := 0
	for f in fx:
		n += 1
		var vis := MapLeads.visible(null, { f.case: f.state }, f.get("vars", {}))
		var ids := []
		for l in vis:
			if l.case == f.case: ids.append(l.id)
		for id in f.get("visible", []):
			if not ids.has(id): fails += 1; print("FAIL %s「%s」: %s 이(가) 보여야 함 (보임 %s)" % [f.case, f.note, id, ids])
		for id in f.get("hidden", []):
			if ids.has(id): fails += 1; print("FAIL %s「%s」: %s 이(가) 숨어야 함" % [f.case, f.note, id])
	for c in MapLeads.cases():
		for l in c.leads:
			if l.has("at") and l.at is String and MapLeads.anchor_of(l.at, c.anchors, "start") == null and not String(l.at).begins_with("actor:"):
				print("WARN %s %s: at '%s' 앵커 아님(인물 id면 지금 사건일 때만 자리)" % [c.id, l.id, l.at])
		print("CASE %s 표지 %d" % [c.id, c.leads.size()])
	print("MAPLEADS %s fixtures=%d fails=%d" % ["PASS" if fails == 0 else "FAIL", n, fails])
	quit(0 if fails == 0 else 1)
