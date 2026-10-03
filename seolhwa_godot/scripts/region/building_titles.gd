# 건물 이름 — 이름 있는 건물·경내(관아·객사·광한루·향교·주막 …)의 터에 들어서면 지명 자리에 건물 이름을 띄운다.
extends RefCounted

# 키트 → 표시 이름(여기 없는 키트는 이름을 띄우지 않음)
const NAMES := {
	"landmark/gwana": "남원도호부 관아", "landmark/hyeon_gwana": "운봉현 관아",
	"landmark/gaeksa": "용성관", "landmark/gwanghallu": "광한루", "landmark/gwanghallu_pond": "광한루원",
	"landmark/hyanggyo": "남원향교", "landmark/maaebul_rock": "여원치 마애불", "landmark/hwangsan_bigak": "황산대첩비",
	"landmark/silsangsa": "실상사", "village/jumak": "주막", "village/seonghwangdang": "성황당",
	"landmark/dongheon": "동헌", "landmark/naea": "내아",
	"landmark/sajikdan": "사직단", "landmark/yeodan": "여단", "landmark/seonghwangsa": "성황사",
	"village/mulbang_a": "물레방앗간", "village/jeongja": "정자", "village/village_square": "쉼터",
	# 대표 도시 랜드마크(경주·강릉·제주) — 같은 키트를 여러 고을이 쓰면 배치 항목의 "title"이 이긴다
	"landmark/gj_dongyeonggwan": "동경관", "landmark/gj_cheomseongdae": "첨성대", "landmark/gj_gyerim_bigak": "계림",
	"landmark/gj_banwolseong": "반월성 터", "landmark/gj_bulguksa": "불국사", "landmark/gj_seokguram": "석굴암",
	"landmark/gj_mojeon_tap": "분황사 모전석탑", "landmark/gj_tumulus": "고분",
	"landmark/gn_imyeonggwan": "임영관", "landmark/gn_gwana": "강릉대도호부 관아", "landmark/gn_ojukheon": "오죽헌",
	"landmark/gn_gyeongpodae": "경포대", "landmark/gn_guksa_seonghwangdang": "대관령 국사성황사", "landmark/gn_dangganjiju": "굴산사 터 당간지주",
	"landmark/jj_gwandeokjeong": "관덕정", "landmark/jj_mokgwana": "제주목 관아", "landmark/jj_samseonghyeol": "삼성혈",
	"landmark/jj_gimnyeongsagul": "김녕사굴", "landmark/jj_yeonbukjeong": "연북정",
	# 북쪽 대표 도시(한양·황주·평양·함흥) — 배치 항목 title이 먼저
	"landmark/hy_gyeongbokgung": "경복궁", "landmark/hy_changdeokgung": "창덕궁", "landmark/hy_jongmyo": "종묘",
	"landmark/hy_sajikdan": "사직단", "landmark/hy_yukjo_geori": "육조거리", "landmark/hy_unjongga": "운종가",
	"landmark/hy_bosingak": "종루(보신각)", "landmark/hy_sijeon": "시전 행랑", "landmark/hy_gwangtonggyo": "광통교",
	"landmark/hy_supyogyo": "수표교", "landmark/hy_sungnyemun": "숭례문", "landmark/hy_heunginjimun": "흥인지문",
	"landmark/hy_donuimun": "돈의문", "landmark/hy_sukjeongmun": "숙정문",
	"landmark/hj_gaeksa": "제안관", "landmark/hj_eupseong_gate": "황주읍성", "landmark/hj_dohwadong": "도화동",
	"landmark/py_daedongmun": "대동문", "landmark/py_botongmun": "보통문", "landmark/py_chilseongmun": "칠성문",
	"landmark/py_ryeongwangjeong": "연광정", "landmark/py_bubyeongnu": "부벽루", "landmark/py_eulmildae": "을밀대",
	"landmark/py_giringgul": "기린굴", "landmark/py_daedong_naru": "나루",
	"landmark/hh_bongung": "함흥본궁", "landmark/hh_mansegyo": "만세교", "landmark/hh_eupseong_gate": "함흥읍성",
	"landmark/hh_bansong": "본궁 반송",
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
			# 항목에 title이 있으면 그것(대표 도시 배치: 같은 키트라도 고을마다 이름이 다름), 없으면 키트 이름표
			var nm := String(it.get("title", "")) if it.get("title") is String else ""
			if nm == "":
				if not NAMES.has(kit): continue
				nm = NAMES[kit]
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
			_areas.append({ name = nm, c = Vector2(float(it.x), float(it.z)), ry = float(it.get("ry", 0.0)), half = fp / 2.0, pri = -fp.x * fp.y })

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
