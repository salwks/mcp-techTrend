# 사건 「강을 판 사내」(ACT 3 평양, S5001~S5006) — 이야기 데이터.
# 시나리오: seolhwa/docs/scenario/seolhwarok_master_scenario_storyboard_v2.3.1_consistency_lock.md §15 (규칙 §1.3~§1.7,
#   성장 §6(레벨 없음 — 사건이 끝나면 숙련), 변수 §7, 소문 §24, 대사 §27, 컷신 §28, 실패 §29, 지역 변화 §30, 점검 §31 '문서 비교',
#   소스 잠금 §36, 거점 §39 PA-01 — F24 강을 산 상인(원형: 대동강 물을 판 사내 설화)을 변이로 쓴다. 원작 제목·인물 이름은 쓰지 않는다)
# 체감 장르(§1.7): 사기·문서 추리. 짧은 사람 싸움 하나(S5003 — 붙잡거나 보내 줄 수 있다). 실패(사기꾼 도주)는 게임오버가 아니라
#   소문(우치가 강을 팔았다는 잘못된 믿음이 남는다)·지역 변화로 남는다(§29).
# 새 체계: 문서 살피기·비교(scripts/story/documents.gd) — S5002 눈으로 견주기(종이·먹·도장 자리), S5006 문서 감정을 익힌 뒤
#   덧쓴 먹·도장 겹침·바꾼 종이·고친 날짜. 문서 그림과 짚을 곳은 아래 documents()에 데이터로 있다.
# 한 공간(PA_PYEONGYANG): 대동문 앞 나루(S5001~S5003) → 감영 뒤 기록 창고(S5004 — world-scenario py_sc_girokgo) → 모란봉 부벽루(S5005, 밤)
#   → 기록 창고 서리 책상(S5006). 한양 §14 S1401이 세운 ACT3_OPEN 뒤에만 선다. 끝나면 ACT4_OPEN(함흥 길 — R05/R07 노정).
# 조건식: story_runner(f·k·c·has·n·ph·v·out·w·fn).
extends RefCounted

const RG := "PA_PYEONGYANG"
const HAM_DOC := "ITM_PY_HAMHUNG"       # 우치가 던진 함흥 문서(S5005)
const PASS_DOC := "ITM_KEY_003"         # 한양 S1401의 위조 통행문서(한양 사건 소지품 — 있으면 S5006에 견줘 본다)
const RESOLVED := "out('A') or out('B')"
const SKILL_SPOTS := ["deed_a/a_over", "deed_a/a_date", "deed_b/b_patch", "deed_b/b_seal2"]

static func data() -> Dictionary:
	return {
		"case": {
			"id": "pyongyang", "record_title": "강을 판 사내", "region": RG, "outcome_var": "CASE_PYONGYANG_OUTCOME", "complete_key": "PYONGYANG",
			"start_hour": 10.0, "start_event": "S5001", "start_on_arrival": true,
			# 한양 §14 S1401(강릉·경주·황주를 다 끝낸 뒤 책쾌) 뒤에만 선다
			"requires": { "ACT3_OPEN": true },
			"rule_label": "문서의 결", "rules_title": "문서의 결",
			"reset_vars": ["CASE_PYONGYANG_OUTCOME", "CASE_PYONGYANG_DETAIL", "CASE_PYONGYANG_COMPLETE", "SKILL_DOCUMENT_CHECK", "ACT4_OPEN", "SKILL_BEAST_SIDESTEP"],
		},
		"items": {
			HAM_DOC: "함흥 전갈 문서", "COIN": "엽전",
			"ITM_TOOL_009": "사건 기록책", "ITM_WPN_001": "환도", "ITM_WPN_002": "활", "ITM_AMMO_001": "화살",
		},
		"hidden_items": ["ITM_TOOL_009", "ITM_WPN_001", "ITM_WPN_002", "ITM_AMMO_001"],
		"clues": clues(),
		# 꼬리표(onboarding P1-7): 규칙은 추정(△) — 문서에서 직접 본 것은 단서(◆확인)
		"rules": {
			"R_NOT_SAME": { "kind": "guess", "title": "두 문서는 한 손에서 나오지 않았다", "text": "같은 관인이 찍혔어도 종이·먹·도장 자리가 다르다. 적어도 하나는 감영이 낸 그대로가 아니다." },
			"R_TWO_SELLERS": { "kind": "guess", "title": "'우치'는 둘이었다", "text": "강을 판 사내의 생김새가 상인마다 다르다. 우치라는 이름을 둘이 나눠 썼다." },
			"R_OTHER_AIM": { "kind": "guess", "title": "창고에 든 자는 다른 문서를 노렸다", "text": "물길 문서와 상관없는 북관 문서 묶음만 비었다. 사기꾼들의 일과는 다른 손이다." },
			"R_EDIT_TRACE": { "kind": "fact", "title": "고친 자리는 남는다", "text": "긁어 낸 결, 겹친 도장, 이어 붙인 종이, 먹빛 다른 날짜 — 손은 옛 흔적을 다 지우지 못한다." },
		},
		"anchors": anchors(),
		"documents": documents(),
		# 지도에 적힐 곳(들음·가 봄)
		"map_places": [
			{ "id": "py_naru", "name": "대동강 나루", "at": "boatman_spot", "radius": 20.0, "start_known": true },
			{ "id": "py_jumak", "name": "나루 주막", "at": "jumo_spot", "radius": 14.0, "known": "c('seller_a') or c('seller_b')" },
			{ "id": "py_paper_yard", "name": "강창 뒤 종이 마당", "at": "paper_line", "radius": 14.0, "known": "f('hideout_known')" },
			{ "id": "py_girokgo", "name": "감영 기록 창고", "at": "store_door", "radius": 16.0, "known": "f('alarm')" },
			{ "id": "py_bubyeongnu", "name": "부벽루", "at": "bu_woochi", "radius": 22.0, "known": "f('bu_known')" },
			{ "id": "py_hamhung_road", "name": "칠성문 밖 — 함흥 길", "at": "hamhung_road", "radius": 30.0, "known": "ph('done')" },
		],
		"journal": {
			"unknowns": [
				{ "text": "두 물길 문서 가운데 어느 것이 감영이 낸 것인가.", "when": "f('case_started')", "until": "f('proven')" },
				{ "text": "강을 판 '우치'는 누구인가.", "when": "f('case_started')", "until": "f('swindlers_resolved')" },
				{ "text": "창고에 든 자는 무엇을 가져갔는가.", "when": "f('alarm')", "until": "c('rack_gap')" },
				{ "text": "우치는 무엇을 쫓고 있는가.", "when": "c('rack_gap')", "until": "f('woochi_met')" },
			],
			"places": [
				{ "name": "대동강 나루", "when": "true" }, { "name": "강창 뒤 종이 마당", "when": "f('hideout_known')" },
				{ "name": "감영 기록 창고", "when": "f('alarm')" }, { "name": "부벽루", "when": "f('woochi_met')" },
			],
		},
		"actors": actors(),
		"objects": objects(),
		"triggers": triggers(),
		"props": props(),
		"arenas": arenas(),
		"events": events(),
	}

static func clues() -> Dictionary:
	return {
		"two_deeds": { "kind": "fact", "title": "두 장의 물길 문서", "text": "한 객주와 윤 상인이 저마다 '대동강 나루 물길을 쓴다'는 문서를 들고 있다. 두 장 다 같은 감영 관인이 찍혔다." },
		"woochi_blamed": { "kind": "heard", "by": "나루 구경꾼", "title": "나루의 말", "text": "“우치가 강을 팔아먹었다더군.”" },
		# S5002 눈으로 견주기(문서 비교 — 짚을 곳 pair)
		"cmp_paper": { "kind": "fact", "title": "종이가 다르다", "text": "한 객주의 것은 두껍고 누런 장지, 윤 상인의 것은 얇고 흰 종이다." },
		"cmp_ink": { "kind": "fact", "title": "먹 번짐이 다르다", "text": "한 객주의 문서는 본문 획 가장자리로 먹이 번졌다. 윤 상인의 것은 또렷하다." },
		"cmp_seal": { "kind": "fact", "title": "도장 자리가 다르다", "text": "같은 관인인데 한 장은 날짜 끝에 걸쳤고, 한 장은 날짜에서 떨어져 찍혔다." },
		"seller_a": { "kind": "heard", "by": "한 객주", "title": "판 사내 — 한 객주의 말", "text": "“우치라 했소. 키가 크고 턱에 흉이 있었지.”" },
		"seller_b": { "kind": "heard", "by": "윤 상인", "title": "판 사내 — 윤 상인의 말", "text": "“우치? 작달막하고 말을 더듬던데.”" },
		"together": { "kind": "heard", "by": "대동강 사공", "title": "둘이 같이", "text": "“흉 있는 사내랑 작은 사내? 주막에서 둘이 한 상에 앉던데.”" },
		"paper_yard": { "kind": "heard", "by": "주모", "title": "종이 말리는 사내들", "text": "“그 둘, 강창 뒤에서 종이를 말리더이다. 장사꾼이 종이는 왜 말리나 했지.”" },
		"drying_paper": { "kind": "fact", "title": "마르는 종이", "text": "강창 뒤 줄에 얇고 흰 종이가 널려 있다. 감영 문서 꼴로 오려 둔 것도 있다." },
		"scraper": { "kind": "fact", "title": "긁개와 먹", "text": "멍석 위에 날 선 긁개, 종이 부스러기, 먹통. 오래된 공문 몇 장이 글자 긁힌 채 포개져 있다." },
		"confession": { "kind": "heard", "by": "붙잡힌 사내", "title": "사기꾼의 말", "text": "“우치 이름은 빌렸을 뿐이오. 감영에서 버린 공문을 사다 고쳤소. 창고? 우린 감영 창고엔 손도 안 댔소!”" },
		"fled": { "kind": "fact", "title": "달아난 사내들", "text": "흉 있는 사내와 작은 사내는 강창 뒤 골목으로 달아났다. 종이와 긁개는 두고 갔다." },
		# S5004
		"window": { "kind": "fact", "title": "부서진 뒤 살창", "text": "감영 기록 창고 뒤 살창이 바깥에서 비틀려 부러졌다. 가죽신 발자국이 서쪽 담으로 이어진다. 앞문 자물쇠는 그대로다." },
		"rack_gap": { "kind": "fact", "title": "빈 시렁", "text": "북관 — 함경도 쪽과 오간 문서 묶음 자리만 비었다. 다른 묶음에는 손도 대지 않았다." },
		"clerk_north": { "kind": "heard", "by": "평양 서리", "title": "서리의 말", "text": "“함흥 감영과 오간 공문들이오. 그런 걸 왜…”" },
		"woochi_note": { "kind": "fact", "title": "빈 칸의 쪽지", "text": "비어 버린 칸에 접힌 쪽지 하나. “달 뜨면 부벽루.” 광통교 종이 뒷면과 같은 손이다." },
		"ledger_seen": { "kind": "fact", "title": "곡물 운송 대장", "text": "창고 안쪽 궤 밑바닥에 오래된 곡물 운송 대장 한 장. 평양 강창에서 함흥 창으로 쌀과 조를 실어 보냈다." },
		"ledger_park": { "kind": "fact", "title": "운송 대장의 朴 표식", "text": "거래처 줄에 '박규상 객주', 끝에 붉은 朴 표식. 한양 책방 납품표와 같은 표식이다. 이것만으로는 무엇도 알 수 없다." },
		"ledger_qty": { "kind": "fact", "title": "운송 대장의 셈", "text": "석 수는 앞뒤가 맞는다. 눈으로 보기엔 고친 데가 없다." },
		"ledger_clean": { "kind": "fact", "title": "고치지 않은 장부", "text": "감정해 보아도 긁은 자리도 덧쓴 먹도 없다. 이 장부는 적힌 그대로다 — 적힌 것이 참이라면." },
		# S5005
		"woochi_words": { "kind": "heard", "by": "우치", "title": "부벽루의 말", "text": "“한때 같은 걸 봤고, 다르게 적었지.” 스승의 행방: “살아 있다면 동쪽이오.”" },
		"hamhung_doc": { "kind": "fact", "title": "함흥 전갈 문서", "text": "우치가 던진 문서. 함흥 감영에서 북청으로 보낸 전갈 세 사람의 이름과 떠난 날짜. 돌아온 날짜 칸은 비어 있다." },
		# S5006
		"master_note": { "kind": "fact", "title": "이겸의 옛 종이", "text": "평양 서리가 간직한 종이 한 장, 스승의 필체. “글보다 고쳐 쓴 자리를 먼저 보라. 거짓말은 새 문장을 만들지만, 손은 옛 흔적을 다 지우지 못한다.”" },
		"a_overwritten": { "kind": "fact", "title": "덧쓴 먹 — 한 객주의 문서", "text": "본문 자리를 긁어 내고 새로 썼다. 긁힌 결 밑에 옛 글자 '나룻배 세 받은 표'가 비친다." },
		"a_date": { "kind": "fact", "title": "고친 날짜 — 한 객주의 문서", "text": "'경오' 두 글자만 먹빛이 다르다. 밑에 '정묘'가 남았다 — 세 해 전에 낸 세금 표다." },
		"b_patched": { "kind": "fact", "title": "바꿔 붙인 종이 — 윤 상인의 문서", "text": "가운데 한 폭만 결이 다르다. 본문 줄을 오려 내고 다른 종이를 이어 붙였다." },
		"b_double_seal": { "kind": "fact", "title": "겹친 도장 — 윤 상인의 문서", "text": "관인이 두 번 찍혔다. 이음매를 덮으려고 한 번 더 눌러 테두리가 겹친다." },
		"pass_forged": { "kind": "fact", "title": "한양의 통행문서", "text": "관인 위로 먹이 지나갔다 — 도장보다 글을 나중에 썼다. 우치의 통행문서도 감영이 낸 그대로는 아니다." },
	}

static func anchors() -> Dictionary:
	return {
		# ---- 대동문 앞 나루(대동강) ----
		"naru_arrive": [212.0, 86.0], "boatman_spot": [219.5, 95.0], "ma_spot": [216.5, 97.5], "mb_spot": [221.5, 91.5],
		"crowd_a_spot": [211.5, 91.0], "crowd_b_spot": [213.0, 100.5], "deed_table": [217.8, 93.6], "notice_spot": [209.0, 84.5],
		"cargo_a": [214.0, 103.0], "cargo_b": [222.5, 88.0],
		"jumo_spot": [201.0, 60.0],
		# 강창 뒤 종이 마당(사기꾼 둘)
		"paper_line": [180.5, 111.5], "scrape_mat": [183.5, 113.5], "hideout": [181.0, 113.0], "sw_a_spot": [178.5, 115.0], "sw_b_spot": [184.0, 116.0],
		"sw_enter": [170.0, 116.0], "flee_west": [150.0, 122.0], "tied_spot": [186.5, 109.5], "tied_b": [188.0, 110.4],
		# ---- 감영(평안감영 남향) — 뒤뜰 기록 창고 py_sc_girokgo (14, −147) ----
		"gate_tied": [32.0, -33.0], "gate_pojol": [29.0, -33.5],
		#   안 마루(높이 +0.75)는 x 10.5~17.5, z −149~−145. 앞문(z −144.3)은 SEALED면 막힘
		"store_door": [14.0, -142.0], "store_inside": [14.0, -146.0], "store_chest": [13.0, -148.2], "chest_prop": [13.4, -147.0], "store_rack": [15.4, -148.0],
		"store_desk": [15.5, -145.0], "store_window_out": [11.6, -151.2], "tracks_end": [-4.0, -151.0],
		"clerk_store": [16.8, -141.0], "pojol_store": [11.5, -140.5], "clerk_desk": [17.3, -145.0],
		# ---- 모란봉 부벽루(강 쪽 +x) ----
		#   누각 바닥(311~322, −557~−538)은 막혀 있다 — 우치는 강 쪽 남동 모서리 난간 곁에 앉는다
		"bu_approach": [314.0, -534.5], "bu_stand": [327.5, -537.5], "bu_woochi": [324.2, -541.0], "bu_lantern": [323.4, -539.2],
		"bu_exit1": [330.0, -552.0], "bu_exit2": [336.0, -566.0],
		# ---- 함흥 길(칠성문 밖) ----
		"hamhung_road": [111.6, -380.0],
	}

# ---------------------------------------------------------------------------
# 문서(scripts/story/documents.gd) — 문서 정규 좌표(0~1). 세로쓰기는 오른쪽 줄부터 읽는다.
#   한 객주의 문서(deed_a): 세 해 전 감영이 낸 '나룻배 세 받은 표'를 긁어 내고 본문을 새로 썼다 — 긁힌 종이에 쓴 먹은 번진다(눈으로 보임),
#     날짜 두 글자는 고쳤다(감정). 관인은 진짜라 날짜 끝에 걸쳐 있다.
#   윤 상인의 문서(deed_b): 얇은 종이의 다른 공문에서 본문 폭을 오려 내고 새 종이를 이어 붙였다(감정), 이음매를 덮으려 관인을 한 번 더(감정).
#   곡물 운송 대장(grain_ledger): 박규상 객주 — 고친 데 없음(최종장 장부 조사가 다시 쓴다).
#   통행문서(pass_doc): 한양 S1401에서 받은 우치의 통행문서 — 가지고 있으면 S5006에 감정해 본다.
# ---------------------------------------------------------------------------
static func documents() -> Dictionary:
	return {
		"deed_a": { "title": "한 객주의 물길 문서", "short": "한 객주 문서", "aspect": 1.38, "seed": 5011,
			"paper": { "base": "#e2d3ae", "fiber": 0.85, "fiber_col": "#7a6444" },
			"scrapes": [{ "rect": [0.47, 0.13, 0.21, 0.56], "alpha": 0.16 }],
			"ghosts": [
				{ "x": 0.635, "y": 0.16, "text": "나룻배 세", "size": 0.062, "alpha": 0.2 },
				{ "x": 0.525, "y": 0.16, "text": "받은 표", "size": 0.062, "alpha": 0.2 },
				{ "x": 0.30, "y": 0.47, "text": "정묘", "size": 0.06, "alpha": 0.26 },
			],
			"cols": [
				{ "x": 0.84, "y": 0.08, "text": "대동강 나루 물길 문서", "size": 0.07, "ink": 0.95 },
				{ "x": 0.635, "y": 0.15, "text": "이 문서 지닌 이가 물길을 쓴다", "size": 0.055, "ink": 0.9, "bleed": 0.9 },
				{ "x": 0.525, "y": 0.15, "text": "배 대는 값은 이 사람이 받는다", "size": 0.055, "ink": 0.9, "bleed": 0.9 },
				{ "x": 0.415, "y": 0.15, "text": "값 일백 냥 받음", "size": 0.055, "ink": 0.92, "bleed": 0.35 },
				{ "x": 0.30, "y": 0.47, "text": "경오년 삼월", "size": 0.06, "ink": 0.97 },
				{ "x": 0.16, "y": 0.52, "text": "판 이 우치", "size": 0.055, "ink": 0.9 },
			],
			"seals": [{ "at": [0.31, 0.79], "size": 0.17, "text": "平安監營", "alpha": 0.85, "rot": -0.03, "seed": 3 }],
			"hotspots": [
				{ "id": "a_paper", "rect": [0.0, 0.0, 1.0, 1.0], "level": "plain", "label": "종이", "text": "두껍고 누런 장지. 닥 섬유가 굵게 비친다.", "pair": "cmp_paper" },
				{ "id": "a_ink", "rect": [0.47, 0.13, 0.21, 0.56], "level": "plain", "label": "먹", "text": "본문 획 가장자리로 먹이 번졌다. 제목 줄은 또렷한데.", "pair": "cmp_ink" },
				{ "id": "a_seal", "rect": [0.225, 0.705, 0.17, 0.17], "level": "plain", "label": "도장", "text": "관인이 날짜 끝에 반쯤 걸쳐 찍혔다.", "pair": "cmp_seal" },
				{ "id": "a_over", "rect": [0.47, 0.13, 0.21, 0.56], "level": "skill", "label": "덧쓴 먹", "text": "본문 자리를 긁어 내고 새로 썼다. 긁힌 결 밑에 옛 글자 '나룻배 세 받은 표'가 비친다.", "clue": "a_overwritten" },
				{ "id": "a_date", "rect": [0.26, 0.45, 0.085, 0.16], "level": "skill", "label": "고친 날짜", "text": "'경오' 두 글자만 먹빛이 다르다. 밑에 '정묘'가 남았다.", "clue": "a_date" },
			] },
		"deed_b": { "title": "윤 상인의 물길 문서", "short": "윤 상인 문서", "aspect": 1.38, "seed": 5012,
			"paper": { "base": "#f1ece0", "fiber": 0.3, "fiber_col": "#9a8c74", "thin": true, "lines": 7, "line_col": "#b0605080" },
			"patches": [{ "rect": [0.455, 0.06, 0.25, 0.88], "base": "#ebe4d2", "fiber": 0.45, "fiber_dir": 1.57, "seam": 0.2 }],
			"cols": [
				{ "x": 0.84, "y": 0.08, "text": "대동강 나루 물길 문서", "size": 0.07, "ink": 0.95 },
				{ "x": 0.645, "y": 0.15, "text": "이 문서 지닌 이가 물길을 쓴다", "size": 0.055, "ink": 0.95 },
				{ "x": 0.52, "y": 0.15, "text": "배 대는 값은 이 사람이 받는다", "size": 0.055, "ink": 0.95 },
				{ "x": 0.40, "y": 0.15, "text": "값 일백 냥 받음", "size": 0.055, "ink": 0.95 },
				{ "x": 0.27, "y": 0.42, "text": "경오년 삼월", "size": 0.06, "ink": 0.95 },
				{ "x": 0.14, "y": 0.50, "text": "판 이 우치", "size": 0.055, "ink": 0.95 },
			],
			"seals": [
				{ "at": [0.45, 0.80], "size": 0.17, "text": "平安監營", "alpha": 0.82, "rot": 0.02, "seed": 4 },
				{ "at": [0.468, 0.812], "size": 0.17, "text": "平安監營", "alpha": 0.42, "rot": 0.07, "seed": 9 },
			],
			"hotspots": [
				{ "id": "b_paper", "rect": [0.0, 0.0, 1.0, 1.0], "level": "plain", "label": "종이", "text": "얇고 흰 종이. 빛에 비추면 얼룩덜룩 비친다.", "pair": "cmp_paper" },
				{ "id": "b_ink", "rect": [0.36, 0.13, 0.32, 0.56], "level": "plain", "label": "먹", "text": "획이 또렷하다. 번진 데가 없다.", "pair": "cmp_ink" },
				{ "id": "b_seal", "rect": [0.36, 0.71, 0.19, 0.19], "level": "plain", "label": "도장", "text": "관인이 날짜에서 한 치쯤 떨어져 찍혔다.", "pair": "cmp_seal" },
				{ "id": "b_patch", "rect": [0.455, 0.06, 0.25, 0.62], "level": "skill", "label": "바꿔 붙인 종이", "text": "가운데 한 폭만 결이 다르다. 본문 줄을 오려 내고 다른 종이를 이어 붙였다.", "clue": "b_patched" },
				{ "id": "b_seal2", "rect": [0.36, 0.71, 0.19, 0.19], "level": "skill", "label": "겹친 도장", "text": "관인이 두 번 찍혔다. 이음매를 덮으려고 한 번 더 눌렀다 — 테두리가 겹친다.", "clue": "b_double_seal" },
			] },
		"grain_ledger": { "title": "곡물 운송 대장(낡은 한 장)", "short": "운송 대장", "aspect": 1.45, "seed": 5040,
			"paper": { "base": "#e6dabd", "fiber": 0.6, "fiber_col": "#7c6a4c", "lines": 8 },
			"cols": [
				{ "x": 0.86, "y": 0.07, "text": "곡물 운송 대장", "size": 0.065, "ink": 0.92 },
				{ "x": 0.755, "y": 0.10, "text": "기사년 시월", "size": 0.05, "ink": 0.88 },
				{ "x": 0.65, "y": 0.10, "text": "쌀 일백 석 평양 강창", "size": 0.05, "ink": 0.88 },
				{ "x": 0.545, "y": 0.10, "text": "쌀 일백 석 함흥 창", "size": 0.05, "ink": 0.88 },
				{ "x": 0.44, "y": 0.10, "text": "조 쉰 석 함흥 창", "size": 0.05, "ink": 0.88 },
				{ "x": 0.335, "y": 0.10, "text": "거래처 박규상 객주", "size": 0.05, "ink": 0.9 },
				{ "x": 0.23, "y": 0.10, "text": "대동강 뱃길로", "size": 0.05, "ink": 0.86 },
			],
			"images": [{ "tex": "res://assets/story/park_mark.png", "region": [0, 0, 128, 128], "rect": [0.12, 0.74, 0.15, 0.104], "alpha": 0.92 }],
			"hotspots": [
				{ "id": "ledger_park", "rect": [0.11, 0.73, 0.17, 0.125], "level": "plain", "label": "朴 표식", "text": "거래처 줄에 '박규상 객주', 끝에 붉은 朴 표식.", "clue": "ledger_park" },
				{ "id": "ledger_name", "rect": [0.305, 0.08, 0.06, 0.6], "level": "plain", "label": "거래처", "text": "'박규상 객주'. 한양 책방의 납품표에서 본 이름이다.", "clue": "ledger_park" },
				{ "id": "ledger_qty", "rect": [0.41, 0.08, 0.27, 0.6], "level": "plain", "label": "석 수", "text": "쌀 이백 석, 조 쉰 석. 앞뒤가 맞는다.", "clue": "ledger_qty" },
				{ "id": "ledger_clean", "rect": [0.41, 0.08, 0.27, 0.6], "level": "skill", "label": "고친 자리 없음", "text": "긁은 자리도 덧쓴 먹도 없다. 적힌 그대로다 — 적힌 것이 참이라면.", "clue": "ledger_clean" },
			] },
		"pass_doc": { "title": "한양에서 가져온 통행문서", "short": "통행문서", "aspect": 1.3, "seed": 1401,
			"paper": { "base": "#ece2c8", "fiber": 0.5, "fiber_col": "#806c50" },
			"cols": [
				{ "x": 0.80, "y": 0.10, "text": "통행 문서", "size": 0.07, "ink": 0.95 },
				{ "x": 0.65, "y": 0.14, "text": "한양에서 평양까지", "size": 0.056, "ink": 0.95 },
				{ "x": 0.52, "y": 0.14, "text": "관문은 막지 말 것", "size": 0.056, "ink": 0.95 },
				{ "x": 0.38, "y": 0.42, "text": "경오년 이월", "size": 0.058, "ink": 0.98 },
			],
			"seals": [{ "at": [0.38, 0.58], "size": 0.18, "text": "漢城府印", "alpha": 0.62, "rot": 0.0, "seed": 14 }],
			"hotspots": [
				{ "id": "pass_paper", "rect": [0.0, 0.0, 1.0, 1.0], "level": "plain", "label": "종이", "text": "관청 종이다. 깨끗하다." },
				{ "id": "pass_seal", "rect": [0.29, 0.49, 0.18, 0.18], "level": "plain", "label": "도장", "text": "관인 자리는 바르다. 눈으로는 흠이 없다." },
				{ "id": "pass_order", "rect": [0.29, 0.40, 0.18, 0.27], "level": "skill", "label": "도장 위의 먹", "text": "날짜 획이 관인 위로 지나갔다 — 도장보다 글을 나중에 썼다.", "clue": "pass_forged" },
			] },
	}

# ---------------------------------------------------------------------------
# 인물(CHARACTER_MASTER v1.3): 상인 CHR_HUM_002 변형 둘(한 객주·윤 상인), 뱃사공 CHR_HUM_007, 구경꾼(아낙·사내), 주모,
#   사기꾼 둘(CHR_HUM_027 짐꾼 → 사람 적 변형 — 우치 이름을 빌린 자들), 포졸 CHR_HUM_016, 평양 서리(관원 변형), 우치 CHR_MAIN_003
# ---------------------------------------------------------------------------
static func actors() -> Array:
	return [
		{ "id": "boatman", "chr": "CHR_HUM_007", "kind": "boatman", "name": "대동강 사공", "at": "boatman_spot", "facing": "left",
			"talk": [
				{ "when": "ph('done')", "steps": [{ "call": "boatman_done" }] },
				{ "when": "not f('case_started')", "steps": [{ "event": "S5001" }] },
				{ "when": "true", "steps": [{ "call": "boatman_talk" }] },
			] },
		{ "id": "merchant_a", "chr": "CHR_HUM_002", "kind": "py_merchant_a", "name": "한 객주", "at": "ma_spot", "facing": "right",
			"talk": [
				{ "when": "ph('done')", "steps": [{ "call": "merchant_done", "args": ["a"] }] },
				{ "when": "true", "steps": [{ "call": "merchant_talk", "args": ["a"] }] },
			] },
		{ "id": "merchant_b", "chr": "CHR_HUM_002", "kind": "py_merchant_b", "name": "윤 상인", "at": "mb_spot", "facing": "left",
			"when": "not (ph('done') and out('B'))",
			"talk": [
				{ "when": "ph('done')", "steps": [{ "call": "merchant_done", "args": ["b"] }] },
				{ "when": "true", "steps": [{ "call": "merchant_talk", "args": ["b"] }] },
			] },
		{ "id": "crowd_a", "chr": "CHR_HUM_010", "kind": "villager_f", "name": "구경꾼", "at": "crowd_a_spot", "facing": "right",
			"talk": [
				{ "when": "out('A')", "steps": [{ "say": "구경꾼", "lines": ["강을 판 게 우치가 아니라 강창 뒤 종이쟁이들이었다며?"] }] },
				{ "when": "out('B')", "steps": [{ "say": "구경꾼", "lines": ["우치가 강을 두 번 팔고 날랐대요. 감영도 손을 못 쓴다나."] }] },
				{ "when": "true", "steps": [{ "say": "구경꾼", "lines": ["강물을 사고판다니, 원. 우치 짓이래요."] }, { "clue": "woochi_blamed" }] },
			] },
		{ "id": "crowd_b", "chr": "CHR_HUM_001", "kind": "villager_m", "name": "구경꾼", "at": "crowd_b_spot", "facing": "up",
			"talk": [
				{ "when": RESOLVED, "steps": [{ "say": "구경꾼", "lines": ["물길을 산다 판다 하더니, 결국 배는 사공이 젓는 거지."] }] },
				{ "when": "true", "steps": [{ "say": "구경꾼", "lines": ["관인이 둘 다 진짜라니 감영도 골치겠소."] }] },
			] },
		{ "id": "jumo", "chr": "CHR_HUM_011", "kind": "innkeeper", "name": "주모", "at": "jumo_spot", "facing": "down",
			"talk": [
				{ "when": RESOLVED, "steps": [{ "say": "주모", "lines": ["종이쟁이들 앉던 상은 이제 비었소."] }] },
				{ "when": "(c('seller_a') or c('seller_b')) and not f('hideout_known')", "steps": [{ "call": "jumo_tell" }] },
				{ "when": "true", "steps": [{ "say": "주모", "lines": ["나루가 막혀 술손님도 없소. 배가 떠야 사람이 오지."] }] },
			] },
		# 사기꾼 둘 — 강창 뒤 종이 마당(S5003). 싸움은 arenas.hideout(scripts/combat/chuman.gd)이 따로 그린다. 붙잡히면 묶여 앉는다
		{ "id": "sw_a", "chr": "CHR_HUM_027", "kind": "py_swindler", "name": "흉 있는 사내", "at": "sw_a_spot", "facing": "right",
			"when": "(f('swindlers_met') and not f('swindlers_resolved')) or (f('caught_a') and not f('alarm'))",
			"talk": [{ "when": "f('caught_a')", "steps": [{ "call": "caught_talk", "args": ["a"] }] }] },
		{ "id": "sw_b", "chr": "CHR_HUM_027", "kind": "py_swindler_b", "name": "작은 사내", "at": "sw_b_spot", "facing": "left",
			"when": "(f('swindlers_met') and not f('swindlers_resolved')) or (f('caught_b') and not f('alarm'))",
			"talk": [{ "when": "f('caught_b')", "steps": [{ "call": "caught_talk", "args": ["b"] }] }] },
		# 결말 A: 감영 정문 앞에 묶여 앉은 사기꾼(§30 관아 앞 체포된 인물)
		{ "id": "sw_gate", "chr": "CHR_HUM_027", "kind": "py_swindler", "name": "묶인 사내", "at": "gate_tied", "facing": "down", "anim": "tied",
			"when": "ph('done') and out('A')",
			"talk": [{ "when": "true", "steps": [{ "say": "묶인 사내", "lines": ["…강물이야 누가 팔든 흐르는 건데."] }] }] },
		{ "id": "pojol_gate", "chr": "CHR_HUM_016", "kind": "pojol", "name": "포졸", "at": "gate_pojol", "facing": "down", "when": "ph('done') and out('A')",
			"talk": [{ "when": "true", "steps": [{ "say": "포졸", "lines": ["판 돈 반은 찾아 돌려줬소. 나머진 벌써 먹고 마셨다지."] }] }] },
		{ "id": "pojol", "chr": "CHR_HUM_016", "kind": "pojol", "name": "포졸", "at": "pojol_store", "facing": "right",
			"when": "f('alarm') and not ph('done')",
			"talk": [{ "when": "true", "steps": [{ "say": "포졸", "lines": ["뒤 살창으로 들었다오. 앞문 자물쇠는 멀쩡하고."] }] }] },
		# 평양 서리 — 기록 창고(S5004 문 앞 → S5006 서리 책상)
		{ "id": "clerk", "chr": "CHR_HUM_017", "kind": "py_clerk", "name": "평양 서리", "at": { "teach": "clerk_desk", "done": "clerk_desk", "default": "clerk_store" },
			"facing": { "teach": "left", "done": "left", "default": "down" }, "when": "f('alarm')", "radius": 2.6,
			"talk": [
				{ "when": "ph('done')", "steps": [{ "call": "clerk_done" }] },
				{ "when": "f('woochi_met') and not f('skill_learned')", "steps": [{ "event": "S5006" }] },
				{ "when": "f('skill_learned') and not f('proven')", "steps": [{ "call": "clerk_practice" }] },
				{ "when": "true", "steps": [{ "call": "clerk_talk" }] },
			] },
		# 우치 — 부벽루(밤, S5005)
		{ "id": "woochi", "chr": "CHR_MAIN_003", "kind": "woochi", "name": "우치", "at": "bu_woochi", "facing": "right", "anim": "crouch",
			"when": "f('bu_known') and not f('woochi_met') and fn('night_now')", "radius": 3.4,
			"talk": [{ "when": "true", "steps": [{ "call": "bu_approach" }] }] },
	]

# ---------------------------------------------------------------------------
# 조사 대상
# ---------------------------------------------------------------------------
static func objects() -> Array:
	return [
		{ "id": "deeds", "at": "deed_table", "label": "두 물길 문서 · 견주어 보기", "radius": 2.2,
			"when": "f('deeds_out') and not f('swindlers_resolved')", "steps": [{ "event": "S5002" }] },
		{ "id": "paper_line", "at": "paper_line", "label": "널어 둔 종이 · 살펴보기", "radius": 2.4,
			"when": "f('hideout_known') and not c('drying_paper') and not ph('done')", "steps": [{ "call": "yard_look", "args": ["paper"] }] },
		{ "id": "scrape_mat", "at": "scrape_mat", "label": "멍석 위 연장 · 살펴보기", "radius": 2.2,
			"when": "f('hideout_known') and not c('scraper') and not ph('done')", "steps": [{ "call": "yard_look", "args": ["scraper"] }] },
		# S5004 기록 창고
		{ "id": "store_window", "at": "store_window_out", "label": "뒤 살창 · 살펴보기", "radius": 2.4,
			"when": "f('alarm') and not c('window') and not ph('done')", "steps": [{ "call": "look_window" }] },
		{ "id": "store_door", "at": "store_door", "label": "창고 앞문 · 열어 달라고 한다", "radius": 2.2,
			"when": "f('alarm') and not f('store_open') and not ph('done')", "steps": [{ "call": "open_store" }] },
		{ "id": "store_rack", "at": "store_rack", "label": "빈 시렁 · 살펴보기", "radius": 1.8,
			"when": "f('store_open') and not c('rack_gap') and not ph('done')", "steps": [{ "call": "look_rack" }] },
		{ "id": "store_chest", "at": "store_chest", "label": "안쪽 궤 · 살펴보기", "radius": 1.5,
			"label_if": ["c('ledger_seen')", "운송 대장 · 다시 보기"],
			"when": "f('store_open') and not ph('done')", "steps": [{ "call": "look_ledger" }] },
		# S5005 — 낮에 부벽루에 닿으면 달 뜨기를 기다릴 수 있다
		{ "id": "bu_wait", "at": "bu_stand", "label": "부벽루 난간 · 달 뜨기를 기다린다", "radius": 3.0,
			"when": "f('bu_known') and not f('woochi_met') and not fn('night_now')", "steps": [{ "call": "bu_wait" }] },
		# S5006 뒤 — 서리 책상의 문서(감정)
		{ "id": "desk_deeds", "at": "store_desk", "label": "서리 책상의 두 문서 · 감정", "radius": 1.6,
			"when": "f('skill_learned') and not ph('done')", "steps": [{ "call": "examine_deeds" }] },
		{ "id": "desk_pass", "at": "store_inside", "label": "통행문서 · 감정", "radius": 1.2,
			"when": "f('skill_learned') and fn('has_pass') and not c('pass_forged')", "steps": [{ "call": "examine_pass" }] },
	]

static func triggers() -> Array:
	return [
		# S5001 나루 — 지나가며 엿듣는 말
		{ "id": "s5001_overhear", "at": "boatman_spot", "radius": 30.0, "when": "not f('case_started')", "ambient": [
			["구경꾼", "또 우치 짓이래."], ["구경꾼", "강물을 사고판다니, 원."]] },
		# S5004 — 사기꾼 일이 끝나면 포졸이 달려온다(나루·종이 마당 근처 어디서나)
		{ "id": "s5004_alarm", "at": "deed_table", "radius": 70.0, "when": "f('swindlers_resolved') and not f('alarm')", "event": "S5004" },
		# 기록 창고 앞에 닿음
		{ "id": "store_arrive", "at": "store_door", "radius": 12.0, "when": "f('alarm') and not f('store_seen')", "steps": [{ "call": "store_arrive" }] },
		# S5005 부벽루 — 등불
		{ "id": "bu_near", "at": "bu_woochi", "radius": 26.0, "when": "f('bu_known') and not f('woochi_met') and not f('bu_lamp_seen') and fn('night_now')", "steps": [{ "call": "bu_lamp" }] },
	]

# ---------------------------------------------------------------------------
# 소품(kit/story/river.gd · kit/story/park_mark.gd)·세계 상태(기록 창고 — 사건 GDScript store_state)
# ---------------------------------------------------------------------------
static func props() -> Array:
	return [
		{ "id": "p_deeds", "kit": "story/river", "params": { "kind": "deeds" }, "at": "deed_table", "ry": 0.4, "when": "f('deeds_out') and not f('swindlers_resolved')" },
		{ "id": "p_paper_line", "kit": "story/river", "params": { "kind": "paper_line" }, "at": "paper_line", "ry": -0.39, "when": "not ph('done') or out('B')" },
		{ "id": "p_scrape", "kit": "story/river", "params": { "kind": "scrape_kit" }, "at": "scrape_mat", "ry": 0.3, "when": "not ph('done')" },
		{ "id": "p_ledger", "kit": "story/park_mark", "params": { "kind": "waybill", "size": 0.34 }, "at": "chest_prop", "dy": 0.98, "ry": 0.2,
			"when": "f('ledger_open') and not ph('done')" },
		{ "id": "p_lantern", "kit": "story/river", "params": { "kind": "lantern" }, "at": "bu_lantern", "ry": 0.0, "when": "f('bu_known') and not f('woochi_met') and fn('night_now')" },
		# 지역 변화(§30): 나루에 방(감영 고시), 배가 다시 뜬다 — 짐
		{ "id": "p_notice", "kit": "story/river", "params": { "kind": "notice" }, "at": "notice_spot", "ry": 0.9, "when": "ph('done')" },
		{ "id": "p_cargo_a", "kit": "story/river", "params": { "kind": "cargo", "seed": 3 }, "at": "cargo_a", "ry": 0.3, "when": "ph('done')" },
		{ "id": "p_cargo_b", "kit": "story/river", "params": { "kind": "cargo", "seed": 8, "timber": true }, "at": "cargo_b", "ry": -0.6, "when": "ph('done') and out('A')" },
	]

# 싸움터 — 사람 적(scripts/combat/chuman.gd). 우치 이름을 빌린 사기꾼 둘(몽둥이)
static func arenas() -> Dictionary:
	return {
		"hideout": { "at": "hideout", "radius": 9.0, "camera": { "pitch": 46.0, "distance": 19.0, "fov": 30.0 },
			"foe_name": "사기꾼", "intro": "흉 있는 사내가 몽둥이를 집어 든다. 작은 사내는 종이 뭉치를 끌어안는다!", "flee_to": "flee_west",
			"humans": [
				{ "id": "sw_a", "kind": "py_swindler", "name": "흉 있는 사내", "weapon": "club", "hp": 55.0, "flee_at": 0.25, "offset": [-2.5, 2.0] },
				{ "id": "sw_b", "kind": "py_swindler_b", "name": "작은 사내", "weapon": "club", "hp": 40.0, "flee_at": 0.45, "dmg": 0.8, "offset": [3.0, 3.0] },
			] },
	}

# ---------------------------------------------------------------------------
# 사건 장면(§44 필드 + steps) — 소스 F24(설화·인물전설, 지역성 A 평양·대동강), 변이(VARIANT). SOURCE_VERIFIED=false면 실행하지 않는다.
# ---------------------------------------------------------------------------
static func _ev(id: String, trigger: String, loc: String, tw: String, actions: String, branches: String, wsc: String, steps: Array) -> Dictionary:
	return {
		"EVENT_ID": id, "RECORD_TITLE": "강을 판 사내", "SOURCE_ID": "F24",
		"SOURCE_TITLE_INTERNAL": "강을 산 상인(대동강 물 팔기 — 인물전설)", "SOURCE_TYPE": "tale", "SOURCE_REGION_GRADE": "A",
		"SOURCE_REGION_NOTE": "평양·대동강에 고정된 인물전설(§39 PA-01). 사전 연출과 사람 심리로 강을 가진 것처럼 속여 판 일화를, 우치의 이름을 빌린 사기꾼들의 물길 문서 사기로 옮겼다. 원작 제목과 인물 이름은 게임 안에 쓰지 않는다(§1.3). 강을 판 '우치'가 실제 우치가 아니라는 것은 플레이어가 문서와 사람으로 확인한다.",
		"ADAPTATION_MODE": "VARIANT", "TRIGGER": trigger, "LOCATION_TYPE": loc, "TIME_WEATHER": tw,
		"PLAYER_ACTIONS": actions, "RESOLUTION_BRANCHES": branches, "WORLD_STATE_CHANGE": wsc, "SOURCE_VERIFIED": true,
		"steps": steps,
	}

static func events() -> Dictionary:
	return {
		"S5001": _ev("S5001", "한양 S1401(ACT3_OPEN) 뒤 평양 도착 — 대동문 앞 나루", "대동강 나루", "낮 · 맑음",
			"엿듣는 말 · 두 상인과 사공의 다툼을 본다", "-", "사건 기록 생성", [
			{ "if": "not f('arrived')", "then": [{ "call": "arrival" }] },
			{ "call": "quarrel" },
		]),
		"S5002": _ev("S5002", "두 상인이 문서를 내놓은 뒤", "나루 사공의 짐 궤짝 위", "낮",
			"두 문서를 나란히 펴 놓고 종이·먹 번짐·도장 자리를 견준다(문서 비교 화면)", "-", "-", [
			{ "call": "compare" },
		]),
		"S5003": _ev("S5003", "두 문서가 한 손에서 나오지 않았다는 것을 안 뒤 — 판 사내를 쫓는다", "나루 주막 → 강창 뒤 종이 마당", "낮",
			"상인·사공·주모에게 묻고 종이 마당을 찾는다 · 사기꾼 둘을 붙잡거나(짧은 싸움) 보내 준다",
			"붙잡음(하나 또는 둘) / 달아남", "사기꾼 체포 또는 도주", [
			{ "call": "yard_meet" },
		]),
		"S5004": _ev("S5004", "사기꾼 일이 끝난 뒤 포졸이 달려옴", "평안감영 뒤 기록 창고", "낮",
			"뒤 살창·발자국·빈 시렁·안쪽 궤의 곡물 운송 대장을 본다", "-", "MAIN_PARK_MARK_COUNT += 1 · 부벽루 쪽지", [
			{ "call": "alarm" },
		]),
		"S5005": _ev("S5005", "빈 칸의 쪽지('달 뜨면 부벽루') 뒤 밤", "모란봉 부벽루", "밤 · 맑음",
			"우치와 마주한다(짧은 대면) — 함흥 문서를 받는다", "-", "함흥 쪽 단서", [
			{ "call": "bu_scene" },
		]),
		"S5006": _ev("S5006", "부벽루 뒤 평양 서리", "기록 창고 서리 책상", "아침",
			"기본 문서 감정을 배운다 · 이겸의 옛 종이 · 두 문서를 다시 감정한다",
			"A 사기꾼을 붙잡았다(판 돈 일부 돌려줌) · B 사기꾼이 달아났다(우치가 강을 팔았다는 말이 남음)",
			"SKILL_DOCUMENT_CHECK · CASE_PYONGYANG_COMPLETE · ACT4_OPEN(함흥 길) · 나루에 감영 방, 배 운항 재개", [
			{ "call": "teach" },
		]),
	}
