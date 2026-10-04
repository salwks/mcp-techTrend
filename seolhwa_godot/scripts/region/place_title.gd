# 지명 표시 — 마을에 들어서거나 게임이 켜질 때 화면 중앙 상단에 지명(예: 남원)이 떠올랐다 사라진다.
# 지명 구역은 region.json settlements를 짧은 이름으로 묶어 만든다(bbox 또는 반지름 + 여유).
extends CanvasLayer

const MARGIN := 40.0      # 마을 터 바깥 여유(m) — 이 안에 들어서면 지명을 띄운다
const EXIT_EXTRA := 40.0  # 나갈 때는 더 멀리 가야 나간 것으로(경계에서 깜박이지 않게)
const FADE_IN := 0.9
const HOLD := 2.4
const FADE_OUT := 1.2

# settlement id → 표시 이름(없으면 표시하지 않음 — 들마을 후보 등)
const TITLES := {
	namwon_eup = "남원", namwon_jang = "남원", namwon_hyanggyo = "남원",
	ibaek = "이백", yeowon_jumak = "여원재", yeowon_seonghwang = "여원재",
	unbong_eup = "운봉", unbong_jang = "운봉", bijeon = "황산",
	inwol_yeok = "인월", inwol_jang = "인월", sannae = "산내",
	silsangsa_temple = "실상사", banseon = "반선",
	# 경주(GS_GYEONGJU)
	gyeongju_eup = "경주", gyeongju_jang = "경주", gyochon = "교촌", bulguksa_village = "진현",
	bulguksa_temple = "불국사", chisul_village = "치술령", daebon = "대본", gampo = "감포", jangang = "장항",
	# 강릉(GW_GANGNEUNG)
	gangneung_eup = "강릉", gangneung_jang = "강릉", gyeongpo_village = "경포", anmok_village = "안목",
	haksan = "학산", gusan_yeok = "구산역", banjeong_jumak = "반정", daegwallyeong_seonghwang = "대관령",
	# 제주(JJ_JEJU)
	jeju_mok = "제주목", jeju_jang = "제주목", sanji_po = "산지포", hwabuk_po = "화북포", jocheon = "조천",
	songdang = "송당", gimnyeong = "김녕",
	# 한양(GG_HANYANG) — 구역마다 이름(도성 안 '한양'은 종루 둘레)
	hanyang_doseong_in = "한양", bukchon = "북촌", ungjongga = "운종가", jungchon = "개천", namchon = "남산골",
	baeogae_jang = "배오개", chilpae_jang = "칠패", wangsimni = "왕십리", mapo = "마포", yongsan = "용산",
	noryangjin = "노량진", hangangjin = "한강진", seobinggo_village = "서빙고",
	# 황주(HH_HWANGJU)
	hwangju_eup = "황주", hwangju_jang = "황주", dohwadong = "도화동", namcheon_ferry_village = "황주천 나루", cheonju_village = "천주",
	# 평양(PA_PYEONGYANG)
	pyeongyang_naeseong = "평양", pyeongyang_jongno = "평양", jungseong = "중성", oeseong = "외성", daedong_naru = "대동강 나루",
	seongyo = "선교리", neungrado = "능라도", yanggakdo = "양각도", yeongmyeongsa_temple = "영명사", botong_out = "보통문 밖",
	# 함흥(HG_HAMHEUNG)
	hamheung_eup = "함흥", hamheung_jang = "함흥", manse_west = "만세교", bongung_village = "본궁", unheung = "운흥",
	# 노정 길목 쉼터(region_data/routes/*/route.json settlements, routes 담당 — tools/region/make_routes.py)
	rt_osu = "오수", rt_jeonju = "전주", rt_aenggok = "앵곡", rt_gomnaru = "곰나루", rt_charyeong = "차령", rt_samgeori = "천안삼거리",
	rt_songpa = "송파", rt_saejae = "문경새재", rt_sangju = "상주", rt_hahoe = "하회", rt_jebiwon = "제비원",
	rt_wonju = "원주", rt_chiak = "치악산", rt_hoenggye = "횡계",
	rt_imjin = "임진나루", rt_kaesong = "개성", rt_seonjuk = "선죽교", rt_cheongseok = "청석골", rt_seoheung = "서흥",
	rt_junghwa = "중화",
	rt_chukseok = "축석령", rt_cheorwon = "철원", rt_cheollyeong = "철령", rt_wonsan = "원산", rt_yeongheung = "영흥",
	rt_seongcheon = "성천", rt_yangdeok = "양덕", rt_gowon = "고원",
	rt_jaeryeong = "재령", rt_guwol = "구월산", rt_jangsan = "장산곶",
	rt_hongwon = "홍원", rt_bukcheong = "북청",
	rt_deokjin = "덕진다리", rt_gwandu = "관두포",
	# 강 뱃길(river_routes.py) — 포구·나루·조창(볼거리는 route.json sights title)
	rt_mapo = "마포 선창", rt_dumulmeori = "두물머리", rt_yeoju = "여주 조포나루", rt_mokgye = "목계진", rt_chungju = "충주",
	rt_gwangnaru = "광나루", rt_yanggeun = "양근", rt_ipo = "이포나루", rt_heungwon = "흥원창", rt_dalcheon = "달천 나루",
	rt_daedongmun = "대동문 선창", rt_duro = "두로도 포구", rt_gyeomipo = "겸이포", rt_gangseo_naru = "강서 나루",
	# 시나리오 장소(world_scenario.json 덧붙임 — tools/scenario/place_scenario.py)
	seogang = "서강", rt_hamgwal_yeokcham = "함관령 옛 역참", rt_jangsan_islet = "장산곶 앞 바위섬",
}

var areas := {}   # 이름 → [Rect2…]
var current := ""
var _label: Label
var _rule: ColorRect
var _t := -1.0

# 남원 권역은 위 TITLES(기존 동작 그대로). 다른 권역·노정은 settlement의 title/short, 없으면 이름 앞부분(들마을 후보 등은 뺀다)
static func uses_own_titles(region: Dictionary) -> bool:
	for s in region.get("settlements", []):
		if TITLES.has(String(s.get("id", ""))): return true
	return false

static func title_for(s: Dictionary, own: bool) -> String:
	if own:
		var t: String = TITLES.get(String(s.get("id", "")), "")
		# 노정 길목(rt_*)은 TITLES에 없으면 route.json title(routes 2차 — 길가 마을·나루)
		if t == "" and String(s.get("id", "")).begins_with("rt_"): t = String(s.get("title", ""))
		return t
	for k in ["title", "short"]:
		if String(s.get(k, "")) != "": return String(s[k])
	var id := String(s.get("id", "")); var n := String(s.get("name", ""))
	if id.begins_with("auto_") or n.contains("후보") or n == "": return ""
	for sep in [" ", "(", "·"]:
		var i := n.find(sep)
		if i > 0: n = n.substr(0, i)
	return n

func setup(region: Dictionary) -> void:
	var own := uses_own_titles(region)
	# 노정 길목 볼거리(route.json sights — 서낭당·신목·원터·소 등): 마을이 아니어도 지나갈 때 이름을 띄운다
	var named := {}
	for s in region.get("settlements", []): named[String(s.get("id", ""))] = true
	var extra := []
	for s in region.get("sights", []):
		if s is Dictionary and not named.has(String(s.get("id", ""))) and String(s.get("title", "")) != "": extra.append(s)
	for s in region.get("settlements", []) + extra:
		var title: String = title_for(s, own)
		if title == "": continue
		var r: Rect2
		var bb = s.get("bbox")
		if bb is Array and bb.size() == 4:
			r = Rect2(Vector2(bb[0], bb[1]), Vector2(bb[2] - bb[0], bb[3] - bb[1]))
		else:
			var rad := float(s.get("radius_m", 40.0))
			r = Rect2(Vector2(float(s.x) - rad, float(s.z) - rad), Vector2(rad * 2.0, rad * 2.0))
		if not areas.has(title): areas[title] = []
		areas[title].append(r)

func _ready() -> void:
	layer = 5
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	box.position.y = 0
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["AppleMyungjo", "Nanum Myeongjo", "NanumMyeongjo", "Batang", "Noto Serif CJK KR", "Apple SD Gothic Neo"])
	_label.add_theme_font_override("font", font)
	_label.add_theme_font_size_override("font_size", 46)
	_label.add_theme_color_override("font_color", Color(1, 1, 1))
	_label.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.035, 1.0))
	_label.add_theme_constant_override("outline_size", 6)
	_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.35))
	_label.add_theme_constant_override("shadow_offset_y", 2)
	box.add_child(_label)
	_rule = ColorRect.new() # 이름 아래 가는 선(흰 선 + 검은 테두리 느낌)
	_rule.color = Color(1, 1, 1)
	_rule.custom_minimum_size = Vector2(120, 2)
	_rule.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var rule_bg := PanelContainer.new()
	var sb := StyleBoxFlat.new(); sb.bg_color = Color(0.05, 0.04, 0.035); sb.content_margin_left = 1; sb.content_margin_right = 1; sb.content_margin_top = 1; sb.content_margin_bottom = 1
	rule_bg.add_theme_stylebox_override("panel", sb)
	rule_bg.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	rule_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rule_bg.add_child(_rule)
	box.add_child(rule_bg)
	_resize()
	get_viewport().size_changed.connect(_resize)
	_set_alpha(0.0)

func _resize() -> void:
	var vs := get_viewport().get_visible_rect().size
	var box: Control = _label.get_parent()
	box.size.x = vs.x
	box.position = Vector2(0, vs.y * 0.08)
	_label.add_theme_font_size_override("font_size", int(clampf(vs.y * 0.06, 28.0, 72.0)))

func _set_alpha(a: float) -> void:
	_label.modulate.a = a
	(_rule.get_parent() as Control).modulate.a = a * 0.9

func _inside(title: String, p: Vector2, extra: float) -> bool:
	for r in areas.get(title, []):
		if (r as Rect2).grow(MARGIN + extra).has_point(p): return true
	return false

func show_title(title: String) -> void:
	_label.text = title
	_rule.custom_minimum_size.x = maxf(120.0, title.length() * 52.0)
	_t = 0.0

# 매 프레임: 플레이어 위치(x, z)
func update(dt: float, pos: Vector3) -> void:
	var p := Vector2(pos.x, pos.z)
	if current != "" and not _inside(current, p, EXIT_EXTRA): current = ""
	if current == "":
		for title in areas:
			if _inside(title, p, 0.0):
				current = title
				show_title(title)
				break
	if _t < 0.0: return
	_t += dt
	var a := 0.0
	if _t < FADE_IN: a = smoothstep(0.0, 1.0, _t / FADE_IN)
	elif _t < FADE_IN + HOLD: a = 1.0
	elif _t < FADE_IN + HOLD + FADE_OUT: a = 1.0 - smoothstep(0.0, 1.0, (_t - FADE_IN - HOLD) / FADE_OUT)
	else: _t = -1.0
	_set_alpha(a)
