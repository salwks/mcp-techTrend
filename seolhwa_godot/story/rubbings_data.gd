# 탁본(ITM_TOOL_007 탁본 도구, SKILL_RUBBING — 경주 「세 번째 등불」 보상) — 닳은 새김·표식을 먹으로 떠 조사 카드로 본다.
# 시나리오 §6.1(조사 숙련: 흔적 읽기·탁본·문서 감정), §31 체크리스트 "탁본", ITEM_MASTER ITM_TOOL_007(마모 글자·표식 확인).
# 탁본은 정답을 알려 주지 않는다. 읽히는 만큼만 — 닳아 못 읽는 획은 못 읽는다고 적는다(이겸의 원칙 "모르는 것은 모른다고").
#   PLACES: 공간마다 손으로 둔 자리 { space, at:[x,z], radius, label, title, text:[…] }
#   KITS:   배치(placement_*.json)에서 이 키트를 쓴 항목은 어디서나 탁본 대상이 된다(장승·돌장승·비각·성황당 돌무더기 등).
#           { kit: { label, title, text, radius, when_param: {이름: 값} } } — 항목 title이 있으면 제목 앞에 붙인다.
# 고증은 참고용 — 비문은 대표 글자 몇 자만(A07 등 배경 전승), 확정할 수 없는 것은 "~로 보인다".
extends RefCounted

const PLACES := [
	# ---- 경주(GS_GYEONGJU) ----
	{ "id": "gj_mangbuseok", "space": "GS_GYEONGJU", "at": [-951.8, 2827.6], "radius": 3.2, "label": "망부석",
		"title": "탁본 — 망부석",
		"text": ["바위 앞쪽 이끼를 걷고 먹을 두드리자 얕은 획 몇 개가 떠오른다.",
			"사람 이름 같은 글자 둘, 날짜인 듯한 획 하나 — 와서 빌고 간 사람들이 새긴 것이다. 가장 오래된 획은 너무 닳아 읽히지 않는다.",
			"스승의 탁본 조각과 같은 자리다. 조각에 남은 획이 지금보다 또렷하다."] },
	{ "id": "gj_gyerim", "space": "GS_GYEONGJU", "at": [-2872.3, -1909.0], "radius": 5.0, "label": "계림 비각",
		"title": "탁본 — 계림 비각",
		"text": ["비각 안 비석의 글자를 떴다. 큰 글자는 또렷하다 — 김씨 시조가 났다는 숲을 기리는 비로 보인다.",
			"아래 잔글씨는 세운 해와 사람 이름. 몇 자는 비바람에 닳았다."] },
	{ "id": "gj_najeong", "space": "GS_GYEONGJU", "at": [-2741.6, -1443.5], "radius": 5.0, "label": "나정 비각",
		"title": "탁본 — 나정 비각",
		"text": ["우물 곁 비각의 비석. 박씨 시조가 났다는 자리를 기리는 글로 보인다.",
			"비석 옆구리에 누가 긁어 놓은 작은 획들 — 비문과는 다른 손이다."] },
	# ---- 남원(JL_NAMWON_UNBONG) ----
	{ "id": "nw_hwangsan", "space": "JL_NAMWON_UNBONG", "at": [0.0, 0.0], "kit_ref": "landmark/hwangsan_bigak", "radius": 6.0, "label": "황산대첩비",
		"title": "탁본 — 황산대첩비",
		"text": ["비각 안의 큰 비. 머리의 큰 글자는 荒山大捷 — 이 들에서 왜구를 크게 이긴 일을 적은 비다.",
			"본문 잔글씨는 길고 빽빽하다. 한 장에 다 뜨지 못했다."] },
	# ---- 강릉(GW_GANGNEUNG) — 국사성황사 길 옛 경계석(누운 선돌) ----
	{ "id": "gn_boundary", "space": "GW_GANGNEUNG", "at": [-2400.5, 1393.0], "radius": 2.6, "label": "누운 선돌",
		"title": "탁본 — 옛 경계석",
		"text": ["반쯤 닳은 새김을 떴다. 城隍 두 자가 겨우 읽힌다. 그 아래 한 자는 境 또는 界로 보인다.",
			"성황 길이 시작되는 자리를 표하던 돌이다. 누가 언제 세웠는지는 적혀 있지 않다."] },
]

const KITS := {
	"village/jangseung": { "label": "장승", "title": "탁본 — 장승",
		"text": ["나무 장승 몸에 먹을 먹였다. 天下大將軍 — 다섯 자가 겨우 남았다.", "옆구리에 마을 이름인 듯한 작은 글자가 있으나 갈라진 결에 묻혀 읽히지 않는다."],
		"text_female": ["나무 장승 몸에 먹을 먹였다. 地下女將軍 — 다섯 자가 겨우 남았다.", "옆구리에 마을 이름인 듯한 작은 글자가 있으나 갈라진 결에 묻혀 읽히지 않는다."] },
	"village/stone_jangseung": { "label": "돌장승", "title": "탁본 — 돌장승",
		"text": ["돌장승 가슴께를 떴다. 이끼 밑에 얕은 새김 — 장군 이름 넉 자 가운데 둘만 읽힌다.", "새김보다 오래된 정 자국이 아래쪽에 있다."] },
	"landmark/gj_gyerim_bigak": { "label": "비각", "title": "탁본 — 비각",
		"text": ["비각 안 비석을 떴다. 큰 글자는 또렷하나 잔글씨 몇 자는 닳았다.", "누군가를 기리는 비다."] },
	"village/seonghwangdang": { "label": "성황당 돌", "title": "탁본 — 성황당 돌무더기",
		"text": ["돌무더기 맨 아래 넓적한 돌에 획 몇 개. 글자라기보다 표식이다 — 길을 표하던 금 셋.", "그 위에 쌓인 돌들은 지나는 사람이 하나씩 얹은 것이다."] },
}

# 이 공간의 탁본 대상(자리 p: Vector2). placement 항목은 loader가 넘겨준다(이미 읽은 것)
static func for_space(space: String, placement_items: Array) -> Array:
	var out := []
	for r in PLACES:
		if String(r.space) != space: continue
		var rr: Dictionary = r.duplicate()
		if r.has("kit_ref"):
			var hit := false
			for it in placement_items:
				if String(it.get("kit", "")) == String(r.kit_ref):
					rr.p = Vector2(float(it.x), float(it.z)); hit = true; break
			if not hit: continue
		else:
			rr.p = Vector2(float(r.at[0]), float(r.at[1]))
		out.append(rr)
	for it in placement_items:
		var kit := String(it.get("kit", ""))
		if not KITS.has(kit): continue
		var k: Dictionary = KITS[kit]
		var p := Vector2(float(it.x), float(it.z))
		var dup := false
		for o in out:
			if (o.p as Vector2).distance_to(p) < 4.0: dup = true; break
		if dup: continue
		var params = it.get("params", {})
		var female: bool = params is Dictionary and bool(params.get("female", false))
		var nm := String(it.get("title", "")) if it.get("title") is String else ""
		out.append({ "id": String(it.get("id", kit)), "p": p, "radius": float(k.get("radius", 2.6)),
			"label": nm if nm != "" else String(k.label), "title": String(k.title) + ("" if nm == "" else " (%s)" % nm),
			"text": k.get("text_female", k.text) if female else k.text })
	return out
