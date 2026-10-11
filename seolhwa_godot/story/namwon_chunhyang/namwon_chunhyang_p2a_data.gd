# 사건 「남원의 약속」 PART II-A 「새 사또」 — 이야기 데이터(ACT 6 남원 재방문 ~ ACT 12 옥의 첫 밤 §30·§31).
# 시나리오 v1.1 §19~§31 · 결정 §4(열림) · 자산 배치 v1.0(§3-2 PART II 앵커 · §4 카메라) · 대사 요청서 v1.0(짧게, 눈앞의 일, 명언 없이).
# 단계: arrival(행차 · 아전) → office(잡역 · 점고 · 명령서 · 월매 집 · 수청 · 곤장 · 옥으로) → jail(옥문 닫힘 뒤 저녁 · 첫 밤).
# II-B(술·쌀·상소, 몽룡의 귀환 이후)의 장면·인물·소품은 여기 없다 — 장면 번호는 C06xx~C12xx뿐.
# namwon_chunhyang_data.gd가 이 목록을 PART I 목록 뒤에 잇는다.
extends RefCounted

const TALLY := "ITM_CH_TALLY"       # 관아 잡역 목패(장면 물건 — ITEM_MASTER에 올리지 않음, PART I 결정과 같음)
const DOCS := "ITM_CH_DOCS"         # 관아 문서 묶음(이방에게)
const SUMMONS := "ITM_CH_SUMMONS"   # 관아 명령서(춘향을 부르는 종이)
const FOOD := "ITM_CH_FOOD"         # 월매의 밥 바구니(§30)

const PLACEMENT := "res://region_data/JL_NAMWON_UNBONG/placement_story_namwon_chunhyang.json"

# 카메라(배치 파일 cameras와 같은 값 · 확정 8A 58/21/32)
const CAM_6A := { pos = [-3226.0, 1.7, 258.0], look = [-3228.4, 1.6, 330.0], fov = 34.0 }   # 촬영: 축에서 2m 비켜 — 앞 포졸 사이로 가마가 보이게
const CAM_8A := { "focus": [-3162.1, 212.0], "pitch": 58.0, "distance": 21.0, "fov": 32.0 }
const CAM_10A := { "focus": "ch_chunhyang_center", "pitch": 22.0, "distance": 4.6, "fov": 40.0 }   # 촬영: 거리 9는 내삼문 지붕 너머라 기와 끝이 전경을 덮음 → 안마당 안 4.6m
const CAM_12A := { pos = [-3174.4, 1.45, 233.6], look = [-3175.2, 1.0, 228.2], fov = 40.0 }
const CAM_PILLAR := { pos = [-3171.4, 0.9, 215.6], look = [-3166.6, 3.0, 207.4], fov = 30.0 }   # 곤장 넷째 컷 — 동헌 앞 기둥을 마당에서 올려다봄(소리만)
const CAM_JAIL_DOOR := { pos = [-3163.4, 2.3, 234.4], look = [-3170.4, 1.2, 229.5], fov = 34.0 }

# §19 행차 길: 남문 안 → 네거리 → 동쪽 관아 앞 → 외삼문 안. 행렬은 이 길을 따라 '뒤로 몇 m'씩 떨어져 걷는다(back · 옆 side)
const PROC_PATH := [[-3228.0, 334.0], [-3228.0, 251.5], [-3170.0, 247.6], [-3162.1, 244.0], [-3162.1, 233.0]]
const PROC_START_S := 46.0   # 6A 첫 프레임에 앞 포졸이 z≈288(카메라 앞 30m) — 촬영: 44m는 작고 길 위 사람에 가렸고, 24m는 앞 포졸이 화면을 덮었다
const PROC_MEMBERS := [
	{ "id": "proc_pojol_a", "back": 0.0, "side": -0.9 }, { "id": "proc_pojol_b", "back": 0.0, "side": 0.9 },
	{ "id": "proc_bearer_1", "back": 2.8, "side": -0.58 }, { "id": "proc_bearer_2", "back": 2.8, "side": 0.58 },
	{ "id": "p_gama", "back": 4.6, "side": 0.0 },
	{ "id": "proc_bearer_3", "back": 6.4, "side": -0.58 }, { "id": "proc_bearer_4", "back": 6.4, "side": 0.58 },
	{ "id": "proc_porter_1", "back": 8.8, "side": -0.4 }, { "id": "proc_porter_2", "back": 10.4, "side": 0.45 },
]
const ONLOOKERS := ["on_1", "on_2", "on_3", "on_4", "on_5", "on_6", "on_7", "on_8"]
const GISAENG := ["gisaeng_1", "gisaeng_2", "gisaeng_3", "gisaeng_4", "gisaeng_5", "gisaeng_6"]

static func items() -> Dictionary:
	return { TALLY: "관아 잡역 목패", DOCS: "관아 문서 묶음", SUMMONS: "관아 명령서", FOOD: "월매의 밥 바구니" }

# 배치 파일의 앵커(PART II 관아·옥 자리 — 사령 줄·기생 줄·이방·형틀·옥 등)를 사건 앵커로 — 같은 값을 두 번 적지 않는다
static func placement_anchors() -> Dictionary:
	var out := {}
	if not FileAccess.file_exists(PLACEMENT): return out
	var j = JSON.parse_string(FileAccess.get_file_as_string(PLACEMENT))
	if not (j is Dictionary): return out
	for k in j.get("anchors", {}):
		var e = j.anchors[k]
		if e is Dictionary and e.has("at"): out[k] = e.at
	return out

static func anchors() -> Dictionary:
	var a := {
		# §19 행차 · 6A
		"ch_proc_watch": [-3223.6, 268.0], "ch_proc_gama": [-3228.0, 297.4],
		"on_1": [-3231.9, 264.0], "on_2": [-3232.2, 274.5], "on_3": [-3231.8, 286.0], "on_4": [-3232.0, 297.0],
		"on_5": [-3224.3, 277.0], "on_6": [-3224.0, 285.0], "on_7": [-3224.4, 293.5], "on_8": [-3224.2, 301.5],
		# §20 아전 · 잡역
		"ch_ajeon": [-3165.2, 245.0], "ch_ajeon_player": [-3166.6, 247.6], "ch_ajeon_office": [-3159.0, 235.8], "ch_ajeon_line": [-3170.2, 216.9],
		"ch_gisaeng_wait_0": [-3157.6, 233.8], "ch_gisaeng_wait_1": [-3156.2, 234.6], "ch_gisaeng_wait_2": [-3154.8, 233.6],
		"ch_gisaeng_wait_3": [-3157.0, 235.4], "ch_gisaeng_wait_4": [-3155.4, 235.9], "ch_gisaeng_wait_5": [-3153.8, 234.8],
		"ch_court_gate_in": [-3162.1, 221.2], "ch_wolmae_gate_watch": [-3161.3, 220.7],
		# §27·§28 곤장
		"ch_chun_bound": [-3162.1, 216.4], "ch_bind_w": [-3163.3, 216.7], "ch_bind_e": [-3160.9, 216.7], "ch_senior_order": [-3164.9, 217.7],
		"ch_player_rope": [-3163.9, 217.3], "ch_rope_help": [-3164.5, 218.0], "ch_player_aside": [-3166.2, 218.4],
		# §29 옥 · §30 · §31
		"ch_jail_keeper": [-3168.7, 228.3], "ch_jail_escort_p": [-3167.6, 227.4], "ch_jail_talk_p": [-3173.3, 231.5], "ch_jail_gate_in2": [-3172.6, 229.0], "ch_dismiss_player": [-3160.6, 237.6],
		"ch_oesammun_in": [-3162.1, 237.4], "ch_jail_leave": [-3168.2, 230.6],
	}
	return a

# ---------------------------------------------------------------------------
# 인물(PART II-A) — 고유 그림: byeon · gisaeng(세 색) · chunhyang_prison(옥) / generic: 아전 py_clerk · 이방 official · 포졸·사령 pojol · 고을 사람
# ---------------------------------------------------------------------------
static func actors() -> Array:
	var out := [
		{ "id": "ajeon", "chr": "CHR_HUM_004", "kind": "py_clerk", "name": "아전",
			"at": { "arrival": "ch_ajeon", "office": "ch_ajeon_office", "jail": "ch_ajeon_office", "default": "ch_ajeon" }, "facing": "down",
			"when": "(ph('arrival') and f('proc_in')) or ph('office') or (ph('jail') and not f('p2a_done'))",
			"talk": [
				{ "when": "ph('arrival') and f('labour_refused') and not f('rounded_up')", "steps": [{ "say": "아전", "lines": ["볼일 없으면 가시오."] }] },
				{ "when": "ph('office') and has('%s')" % DOCS, "steps": [{ "say": "아전", "lines": ["이방은 안마당 단 옆에 계시오."] }] },
				{ "when": "ph('office') and f('summons_given') and not f('wolmae_summoned')", "steps": [{ "say": "아전", "lines": ["월매 집. 남문 나가서 광한루 동쪽이오. 꾸물대지 마시오."] }] },
				{ "when": "ph('office')", "steps": [{ "say": "아전", "lines": ["부르면 바로 오시오."] }] },
				{ "when": "ph('jail')", "steps": [{ "say": "아전", "lines": ["목패는 내일 아침에."] }] },
				{ "when": "true", "steps": [{ "say": "아전", "lines": ["관아 앞에서 서성대지 마시오."] }] },
			] },
		{ "id": "ibang", "chr": "CHR_HUM_004", "kind": "official", "name": "이방", "at": "ch_ibang", "facing": "down", "when": "ph('office')",
			"talk": [
				{ "when": "has('%s') and not f('docs_delivered')" % DOCS, "steps": [{ "event": "C0704" }] },
				{ "when": "f('docs_delivered') and not f('gisaeng_called')", "steps": [{ "say": "이방", "lines": ["기생들 안으로 들이라니까. 바깥마당이오."] }] },
				{ "when": "f('gisaeng_called') and not f('in_line')", "steps": [{ "say": "이방", "lines": ["서쪽 사령 줄 끝. 저기."] }] },
				{ "when": "true", "steps": [{ "say": "이방", "lines": ["바쁘오."] }] },
			] },
		{ "id": "byeon", "chr": "CHR_CH_BYEON", "kind": "byeon", "name": "변학도", "at": "ch_byeon_seat", "facing": "down", "anim": "sit",
			"when": "ph('office')", "accent": false },
		{ "id": "chunhyang_jail", "chr": "CHR_CH_CHUNHYANG", "kind": "chunhyang_prison", "name": "춘향", "at": "ch_jail_cell", "facing": "down", "anim": "sit",
			"when": "ph('jail')", "accent": false },
		{ "id": "roundup_pojol", "chr": "CHR_HUM_016", "kind": "pojol", "name": "포졸", "at": "ch_gwana_front", "facing": "down", "when": "f('roundup_on')", "accent": false },
		{ "id": "roundup_m1", "chr": "CHR_HUM_028", "kind": "villager_m", "name": "끌려온 장정", "at": "ch_gwana_front", "facing": "down", "when": "f('roundup_on')", "accent": false },
		{ "id": "roundup_m2", "chr": "CHR_HUM_009", "kind": "farmer", "name": "끌려온 농군", "at": "ch_gwana_front", "facing": "down", "when": "f('roundup_on')", "accent": false },
	]
	# 기생 여섯(세 색 순환) — 부르기 전 바깥마당, 부른 뒤 단 앞 줄(사건 코드 stage_office)
	var kinds := ["gisaeng", "gisaeng_b", "gisaeng_c"]
	for i in GISAENG.size():
		out.append({ "id": GISAENG[i], "chr": "CHR_CH_GISAENG", "kind": kinds[i % 3], "name": "기생", "at": "ch_gisaeng_wait_%d" % i, "facing": "down",
			"when": "ph('office')", "accent": false,
			"talk": [
				{ "when": "f('docs_delivered') and not f('gisaeng_called')", "steps": [{ "event": "C0705" }] },
				{ "when": "not f('docs_delivered')", "steps": [{ "say": "기생", "lines": ["새 사또는 첫날부터 점고래요."] }] },
				{ "when": "true", "steps": [{ "say": "기생", "lines": ["…"] }] },
			] })
	# §19 행차 — 앞 포졸 둘 · 가마꾼 넷(가마 소품 p_gama가 그 사이) · 짐꾼 둘. 사건 코드가 길을 따라 옮긴다
	var proc := [["proc_pojol_a", "pojol", "포졸", "CHR_HUM_016"], ["proc_pojol_b", "pojol", "포졸", "CHR_HUM_016"],
		["proc_bearer_1", "villager_m", "가마꾼", "CHR_HUM_027"], ["proc_bearer_2", "villager_m", "가마꾼", "CHR_HUM_027"],
		["proc_bearer_3", "villager_m", "가마꾼", "CHR_HUM_027"], ["proc_bearer_4", "villager_m", "가마꾼", "CHR_HUM_027"],
		["proc_porter_1", "woodcutter", "짐꾼", "CHR_HUM_027"], ["proc_porter_2", "woodcutter", "짐꾼", "CHR_HUM_027"]]
	for p in proc:
		out.append({ "id": p[0], "chr": p[3], "kind": p[1], "name": p[2], "at": "ch_proc_gama", "facing": "up", "anim": "walk",
			"when": "f('proc_on') and not f('proc_in')", "accent": false })
	# 길가 사람(행차 동안 양옆 — 가마가 지나면 고개를 숙인다)
	var ol := [["villager_m", "CHR_HUM_028", "새 사또 행차라오. 고개 숙이고 계시오."], ["villager_f", "CHR_HUM_029", "단오 때랑은 딴판이지요?"],
		["elder", "CHR_HUM_022", "잔치 준비한다고 곡식을 다 걷어 간대."], ["farmwife", "CHR_HUM_010", "쉿, 행차 지나가오."],
		["peddler", "CHR_HUM_003", "엿판 걷으라고 아침부터 난리였소."], ["villager_f", "CHR_HUM_023", "포졸들 눈에 띄지 마시오."],
		["farmer", "CHR_HUM_009", "올해 추수는 반이 관아 몫이라더군."], ["child_boy", "CHR_HUM_020", "가마다, 가마!"]]
	for i in ol.size():
		out.append({ "id": ONLOOKERS[i], "chr": ol[i][1], "kind": ol[i][0], "name": "고을 사람", "at": ONLOOKERS[i],
			"facing": "right" if i < 4 else "left", "when": "ph('arrival') and not f('proc_in')", "accent": false,
			"talk": [{ "when": "true", "steps": [{ "say": "고을 사람", "lines": [ol[i][2]] }] }] })
	return out

# ---------------------------------------------------------------------------
# 자리 트리거 · 엿듣는 말(조작을 막지 않음)
# ---------------------------------------------------------------------------
static func triggers() -> Array:
	return [
		{ "id": "c0601_proc", "at": [-3228.0, 290.0], "radius": 28.0, "when": "ph('arrival') and not f('proc_seen')", "event": "C0601" },
		{ "id": "c0601_proc_b", "at": "ch_gwana_front", "radius": 26.0, "when": "ph('arrival') and not f('proc_seen')", "event": "C0601" },
		{ "id": "c0701_recog", "at": "ch_gwana_front", "radius": 9.0, "when": "ph('arrival') and f('proc_in') and not f('recog_done')", "event": "C0701" },
		{ "id": "c0703_line", "at": "ch_player_saryeong", "radius": 1.4, "when": "ph('office') and f('gisaeng_called') and not f('in_line')", "event": "C0703" },
		{ "id": "c0902_wolmae", "at": "ch_wolmae_front", "radius": 6.5, "when": "ph('office') and f('summons_given') and not f('wolmae_summoned')", "event": "C0902" },
		{ "id": "c1001_court", "at": "ch_court", "radius": 6.5, "when": "ph('office') and f('escorting') and fn('chun_close')", "event": "C1001" },
		{ "id": "c1103_jail", "at": "ch_jail_gate", "radius": 3.6, "when": "ph('office') and f('escort_jail') and fn('chun_close')", "event": "C1103" },
		{ "id": "c1201_food", "at": "ch_prison_food", "radius": 8.0, "when": "ph('jail') and f('dismissed') and not f('food_scene')", "event": "C1201" },
		{ "id": "c1202_bars", "at": "ch_jail_bars_out", "radius": 2.2, "when": "ph('jail') and f('brought_prison_food') and not f('jail_talked')", "event": "C1202" },
		# 엿듣는 말
		{ "id": "b_gate_street", "at": "ch_south_gate_in", "radius": 16.0, "when": "ph('arrival') and not f('proc_seen')",
			"ambient": [["길가 아낙", "비켜요, 비켜. 행차가 온대요."], ["노인", "북소리 들리지? 고개 숙이고 있어."]] },
		{ "id": "b_gwana_wait", "at": "ch_gwana_front", "radius": 14.0, "when": "ph('arrival') and f('proc_seen') and not f('proc_in')",
			"ambient": [["포졸", "물러서시오. 행차 드신다."]] },
		{ "id": "b_yard", "at": "ch_feast_store", "radius": 10.0, "when": "ph('office') and not f('jeomgo_done')",
			"ambient": [["관속", "가마니는 동쪽 담 밑으로! 잔치 때 쓸 거다."], ["관속", "술독 깨면 네 품삯에서 뺀다."]] },
		{ "id": "b_summons_road", "at": "ch_crossroads", "radius": 12.0, "when": "ph('office') and f('summons_given') and not f('wolmae_summoned')",
			"ambient": [["장꾼", "관아 종이 들고 어디 가오?"], ["장꾼 아낙", "쉿. 묻지 마요."]] },
		{ "id": "b_escort_gate", "at": "ch_south_gate_in", "radius": 14.0, "when": "ph('office') and f('escorting')",
			"ambient": [["노인", "춘향이 아니냐…"], ["아낙", "새 사또가 불렀대요. 월매 집 딸을."]] },
		{ "id": "b_escort_cross", "at": "ch_crossroads", "radius": 12.0, "when": "ph('office') and f('escorting')",
			"ambient": [["장꾼", "저 외지 사람은 누구요? 관아 목패를 찼네."]] },
	]

static func props() -> Array:
	return [
		{ "id": "p_gama", "kit": "story/chunhyang", "params": { "kind": "gama" }, "at": "ch_proc_gama", "dy": 0.0, "when": "f('proc_on') and not f('proc_in')" },
	]

static func clues() -> Dictionary:
	return {
		"new_magistrate": { "title": "새 사또", "text": "새 사또가 행차로 들어왔다. 길가 사람들이 “변학도.” 하고 수군거렸다.", "kind": "heard", "by": "고을 사람" },
		"labour": { "title": "임시 잡역", "text": "관아 아전이 범 일 때의 나를 알아보고 하루 잡역을 맡겼다. 문서 나르고 사람 데려오는 일. 목패를 찼다.", "kind": "fact" },
		"roll_call": { "title": "기생 점고", "text": "새 사또가 첫날 기생 점고를 했다. 이방이 명부의 이름을 불렀고 기생들이 “예.” 했다.", "kind": "fact" },
		"bring_her": { "title": "데려와", "text": "이방이 퇴기 월매의 딸 성춘향은 관기 명부에 없다고 하려는데 사또가 말을 끊었다. “데려와.”", "kind": "heard", "by": "변학도" },
		"summons_paper": { "title": "관아 명령서", "text": "“퇴기 월매의 딸 성춘향을 관아로 데려올 것.” 이방의 수결.", "kind": "fact" },
		"chun_decides": { "title": "제가 가겠습니다", "text": "월매가 막았지만 춘향이 스스로 나섰다. “안 가면 더 많은 사람이 올 겁니다.”", "kind": "heard", "by": "춘향" },
		"sucheong": { "title": "수청 거절", "text": "“내 수청을 들어라.” — “못 합니다. 이미 정한 사람이 있습니다.” 두 번째 요구에도 “싫습니다.”", "kind": "heard", "by": "춘향" },
		"gonjang": { "title": "곤장", "text": "곤장. 사또가 “하겠느냐?” 물을 때마다 춘향은 “못 합니다.” 했다.", "kind": "fact" },
		"jailed": { "title": "옥", "text": "춘향이 관아 바깥마당 서쪽 옥에 갇혔다. 옥문이 닫혔다.", "kind": "fact" },
		"food_refused": { "title": "막힌 밥", "text": "밤, 월매가 밥을 들고 왔지만 외삼문 포졸이 막았다. “사또 분부요.”", "kind": "fact" },
		"jail_talk": { "title": "나무살 너머", "text": "옥 나무살 너머로 춘향과 몇 마디를 나눴다. 밥은 들어갔다.", "kind": "fact" },
	}

static func map_leads() -> Array:
	return [
		{ "id": "ch_p2_return", "name": "남원 — 새 사또의 잔치", "region": "JL_NAMWON_UNBONG",
			"when": "v('CASE_NAMWON_CHUNHYANG_LEFT_AFTER_PART1') == true and (v('CASE_GANGNEUNG_COMPLETE') == true or v('CASE_GYEONGJU_COMPLETE') == true or v('CASE_HWANGJU_COMPLETE') == true)",
			"until": "f('p2_started')", "note": "결정 §4 PART II 귀환 — 강릉·경주·황주 뒤 소문 “남원 새 사또가 잔치를 크게 벌인다더군”(rumors CH_P2_*). 강제하지 않는다" },
		{ "id": "ch_p2_street", "name": "남원 읍내 큰길", "at": "ch_crossroads", "hub": true, "when": "f('p2_started')", "until": "f('proc_seen')", "note": "§19 남원의 공기 · 6A" },
		{ "id": "ch_p2_gwana", "name": "관아 앞 — 행차가 들어간 곳", "at": "ch_gwana_front", "when": "f('proc_seen')", "until": "f('recog_done')", "note": "§20 아전" },
		{ "id": "ch_p2_ibang", "name": "이방 — 안마당 단 옆", "at": "ch_ibang", "when": "f('labour_started')", "until": "f('docs_delivered')", "note": "잡역 1 문서" },
		{ "id": "ch_p2_gisaeng", "name": "바깥마당 — 기생들", "at": "ch_gisaeng_wait_0", "when": "f('docs_delivered')", "until": "f('gisaeng_called')", "note": "잡역 2" },
		{ "id": "ch_p2_line", "name": "서쪽 사령 줄 끝", "at": "ch_player_saryeong", "when": "f('gisaeng_called')", "until": "f('in_line')", "note": "잡역 3 · §21 점고" },
		{ "id": "ch_p2_wolmae", "name": "월매 집", "at": "ch_wolmae_gate", "when": "f('summons_given')", "until": "f('wolmae_summoned')", "note": "§23·§24 명령서" },
		{ "id": "ch_p2_court", "name": "관아 안마당", "at": "ch_court", "when": "f('escorting')", "until": "f('sucheong1_done')", "note": "§25 춘향을 데려간다" },
		{ "id": "ch_p2_jail", "name": "옥 — 바깥마당 서쪽", "at": "ch_jail_gate", "when": "f('escort_jail')", "until": "f('jailed')", "note": "§29" },
		{ "id": "ch_p2_gate", "name": "외삼문 밖", "at": "ch_prison_food", "when": "f('dismissed')", "until": "f('food_scene')", "note": "§30 첫날 밤" },
		{ "id": "ch_p2_bars", "name": "옥사 나무살 앞", "at": "ch_jail_bars_out", "when": "f('brought_prison_food')", "until": "f('jail_talked')", "note": "§31" },
	]

static func map_places() -> Array:
	return [
		{ "id": "gwana", "name": "남원 관아", "at": "ch_court", "building": true, "radius": 18.0, "known": "f('labour_started')" },
		{ "id": "jail", "name": "옥", "at": "ch_jail", "building": true, "radius": 6.0, "known": "f('escort_jail') or f('jailed')" },
	]

static func _ev(id: String, trigger: String, loc: String, tw: String, actions: String, branches: String, wsc: String, steps: Array) -> Dictionary:
	return {
		"EVENT_ID": id, "EVENT_CLASS": "FOLKLORE_EVENT", "RECORD_TITLE": "남원의 약속", "SOURCE_ID": "F50", "CATALOG_ID": "HN01",
		"SOURCE_TITLE_INTERNAL": "춘향전(열녀춘향수절가)", "SOURCE_TYPE": "pansori_novel", "SOURCE_REGION_GRADE": "A",
		"SOURCE_REGION_NOTE": "남원 고정 전승(지역 앵커 A01 춘향 계열 — 관아·옥). 완판 84장본의 변학도 부임~투옥(PART II-A)을 화면에서 그대로 겪는다(DIRECT). 플레이어는 관아가 부리는 외지인.",
		"ADAPTATION_MODE": "DIRECT", "TRIGGER": trigger, "LOCATION_TYPE": loc, "TIME_WEATHER": tw,
		"PLAYER_ACTIONS": actions, "RESOLUTION_BRANCHES": branches, "WORLD_STATE_CHANGE": wsc, "SOURCE_VERIFIED": true,
		"steps": steps,
	}

static func events() -> Dictionary:
	return {
		"C0601": _ev("C0601", "PART II 열림 뒤 남원 읍내 큰길(또는 관아 앞)", "남문 안 큰길", "낮", "길가에서 본다", "-", "변학도 행차 → 관아", [{ "call": "procession" }]),
		"C0701": _ev("C0701", "행차가 들어간 뒤 관아 앞", "외삼문 앞", "낮", "알아보는 말에 답한다 · 잡역을 맡거나 싫다고 한다",
			"맞소 / 아니오 / 무슨 일이오? · 맡는다 / 싫다고 한다(첫 태도만 — 어느 쪽이든 들어간다)", "labour_accepted | labour_refused · 단계 office", [{ "call": "recognition" }]),
		"C0702": _ev("C0702", "싫다고 하고 떠나려 할 때", "관아 앞 길", "낮", "막힌다", "-", "rounded_up · 단계 office", [{ "call": "roundup" }]),
		"C0704": _ev("C0704", "문서 묶음을 들고 이방에게", "관아 안마당", "낮", "문서를 건넨다", "-", "docs_delivered", [{ "call": "docs_to_ibang" }]),
		"C0705": _ev("C0705", "바깥마당 기생들에게", "관아 바깥마당", "낮", "안으로 들라 전한다", "-", "gisaeng_called", [{ "call": "call_gisaeng" }]),
		"C0703": _ev("C0703", "서쪽 사령 줄 끝에 선다", "관아 안마당(공식 8A)", "낮", "줄에 서서 본다(조작은 그대로)", "-", "jeomgo_done · summons_given", [{ "call": "take_line" }]),
		"C0902": _ev("C0902", "명령서를 들고 월매 집", "월매 집 대문", "낮", "월매에게 전한다",
			"관아에서 나오라 합니다 / 좋은 일로 부르는 것 같지 않습니다 / 성춘향을 데려오라 했습니다 — 춘향은 어느 경우든 스스로 간다",
			"summons_plain | warned_wolmae | summons_words · escorting", [{ "call": "summons_wolmae" }]),
		"C1001": _ev("C1001", "춘향을 데리고 관아 안마당", "관아 안마당(8A → 10A)", "낮", "사령 줄에서 본다 · 줄을 잡으라는 명령에 답한다 · 팔을 내밀지 정한다",
			"잡는다 / 느슨하게 잡는다 / 놓는다(어느 경우든 춘향은 맞는다) · 팔을 내민다 / 기다린다",
			"restraint_obeyed | restraint_loose | restraint_refused · arm_offered | arm_waited", [{ "call": "sucheong" }]),
		"C1103": _ev("C1103", "춘향을 데리고 옥문 앞", "관아 바깥마당 서쪽 옥", "낮 → 저녁", "본다", "-", "옥문 SEALED · 단계 jail", [{ "call": "jail_door" }]),
		"C1201": _ev("C1201", "잡역이 끝난 밤 외삼문 밖", "외삼문 밖", "밤", "고른다", "내가 가져다주겠다 / 포졸을 설득한다 / 지나간다(어느 경우든 밥은 들어간다)",
			"brought_prison_food | persuaded_guard | passed_food", [{ "call": "prison_food" }]),
		"C1202": _ev("C1202", "밥을 들고 옥사 나무살 앞", "옥(CAMERA 12A)", "밤", "말을 건넨다", "몽룡이 돌아올 겁니다 / 왜 그렇게까지 합니까? / 아무 말 없이 밥을 둔다",
			"jail_talk_*", [{ "call": "jail_talk" }]),
	}
