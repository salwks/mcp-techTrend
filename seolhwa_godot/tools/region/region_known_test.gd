# 권역 상식(region_known, C65) 데이터 시험 — 여덟 권역 목록이 모두 지도에 있는 이름·id로 풀리는가 · 금지 항목이 없는가(헤드리스).
#   godot --headless --path . -s res://tools/region/region_known_test.gd          → REGIONKNOWN PASS n / REGIONKNOWN FAIL …
#   godot --headless --path . -s res://tools/region/region_known_test.gd -- dump  → 권역마다 고을 이름·이름 있는 건물 목록도 찍는다(목록 짤 때)
# 금지: 사건 장소(place:)·사건 map_places 이름(공공 건물 building·start_known 제외)·개별 생활시설(주막·방앗간)·외딴집·월매 집·옥·사람 집.
extends SceneTree

const RegionKnown := preload("res://scripts/region/region_known.gd")
const RegionMap := preload("res://scripts/region/region_map.gd")
const PlaceTitle := preload("res://scripts/region/place_title.gd")
const CaseRegistry := preload("res://scripts/story/case_registry.gd")

const HUBS := ["JL_NAMWON_UNBONG", "GG_HANYANG", "GS_GYEONGJU", "GW_GANGNEUNG", "HH_HWANGJU", "PA_PYEONGYANG", "HG_HAMHEUNG", "JJ_JEJU"]
const BANNED_WORDS := ["주막", "방앗간", "외딴집", "월매", "옥", "집"]

func _init() -> void:
	var dump := OS.get_cmdline_user_args().has("dump")
	var fails: Array = []
	# 사건 장소 이름(map_places) — 상식 목록에 들면 안 된다(건물 이름으로 겹쳐도 사건이 알려 줄 곳이다)
	var case_names := {}
	for id in CaseRegistry.all_ids():
		var d := CaseRegistry.load_data(String(id))
		for sp in d.get("map_places", []):
			# 사건이 쓰는 공공 건물(building: true — 광한루·광통교)·처음부터 아는 자리(start_known — 대동강 나루)는 상식과 겹쳐도 된다:
			#   place: 키는 그대로 사건이 정한다. 그 밖의 사건 장소 이름(외딴집·월매 집·고갯길 …)은 상식 목록에 들면 안 된다
			if sp is Dictionary and not bool(sp.get("building", false)) and not bool(sp.get("start_known", false)):
				case_names[String(sp.get("name", ""))] = String(id)
	var total := 0
	for sp in HUBS:
		var s := RegionKnown.spec(sp)
		if s.is_empty(): fails.append("%s 목록 없음" % sp); continue
		var dir := "res://region_data/%s/" % sp
		var region = JSON.parse_string(FileAccess.get_file_as_string(dir + "region.json"))
		if not (region is Dictionary): fails.append("%s region.json" % sp); continue
		var own := PlaceTitle.uses_own_titles(region)
		var towns: Array = []
		for st in region.get("settlements", []):
			var t := PlaceTitle.title_for(st, own)
			if t != "" and not towns.has(t): towns.append(t)
		var items: Array = []
		var da := DirAccess.open(dir)
		for f in da.get_files():
			if not (f.begins_with("placement_") and f.ends_with(".json")): continue
			var d = JSON.parse_string(FileAccess.get_file_as_string(dir + f))
			if not (d is Dictionary): continue
			for it in d.get("items", []):
				if it.has("when"): continue
				var params: Dictionary = it.get("params", {}) if it.get("params") is Dictionary else {}
				if RegionMap.map_kind(String(it.get("kit", "")), params) == "": continue
				var nm := RegionMap.item_name(it)
				if nm != "": items.append({ name = nm, c = Vector2(float(it.x), float(it.z)) })
		var r := RegionKnown.resolve(sp, towns, items, region)
		for m in r.missing: fails.append("%s 지도에 없음 %s" % [sp, m])
		var names: Array = []
		for k in ["towns", "buildings"]:
			for n in s.get(k, []): names.append(String(n))
		for n in names:
			if case_names.has(n): fails.append("%s 사건 장소 이름 '%s'(%s)" % [sp, n, case_names[n]])
			for w in BANNED_WORDS:
				if n.contains(w): fails.append("%s 금지 '%s' ⊃ '%s'" % [sp, n, w])
		for k in r.keys:
			if String(k).begins_with("place:"): fails.append("%s 사건 장소 키 %s" % [sp, k])
		var counts := "towns=%d landmarks=%d buildings=%d passes=%d ferries=%d" % [s.get("towns", []).size(), s.get("landmarks", []).size(), s.get("buildings", []).size(), s.get("passes", []).size(), s.get("ferries", []).size()]
		print("REGIONKNOWN %s entries=%d keys=%d (%s)" % [sp, names.size() + s.get("landmarks", []).size() + s.get("passes", []).size() + s.get("ferries", []).size(), r.keys.size(), counts])
		total += r.keys.size()
		if dump:
			print("  towns ", towns)
			var bn: Array = []
			for it in items:
				if not bn.has(it.name): bn.append(it.name)
			print("  buildings ", bn)
	for f in fails: print("REGIONKNOWN fail ", f)
	print("REGIONKNOWN %s regions=%d keys=%d fails=%d" % ["PASS" if fails.is_empty() else "FAIL", HUBS.size(), total, fails.size()])
	quit(0 if fails.is_empty() else 1)
