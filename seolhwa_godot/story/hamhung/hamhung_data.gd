# 사건 「돌아오지 않는 전갈」(ACT 4 함흥, S6001~S6011)과 R05 노정 사건(평양→함흥) — 이야기 데이터.
# 시나리오: seolhwa/docs/scenario/seolhwarok_master_scenario_storyboard_v2.4_integrated_improvement.md §16(R05)·§17(S6001~S6011 — S6009 조사 카드 「서강의 두 필체」)·§18(제주 접근)
#   (규칙 §1.3~§1.8, 이겸 §3.2, 서강 화재 §4, 성장 §6, 변수 §7, 소문 §24, 대사 §27, 컷신 §28, 실패 §29, 지역 변화 §30, 소스 잠금 §36,
#    전승 앵커 §37 A15 함흥차사 — 사람들의 농담으로만, 사건의 정체가 아니다)
# 체감 장르(§1.7·§23): 생존·이동 — "기록만으로 사람을 구할 수 없을 때가 있다". 함흥에서 가져갈 원칙: 기록보다 구조가 먼저 필요한 순간이 있다.
# 실패(전갈꾼을 다 구하지 못함)는 게임오버가 아니라 결말·소문·지역 변화로 남는다(§29). 전투는 사람 도적과 짧게 한 번(S6003)뿐.
#
# 세 공간에 걸친 사건(story_director CASES — 같은 사건 id, 항목 "space"로 가름):
#   PA_PYEONGYANG-HG_HAMHEUNG(R05 노정 — 성천·양덕 고개·고원): 평양 사건(ACT 3)이 끝난 뒤 처음 지날 때만 날씨가 단계로 나빠지고(흐림→바람→눈→고개 눈보라)
#     네 가지 고정 사건(쓰러진 말·돌아간 이정표·눈에 묻힌 짐·세 갈래 발자국)이 길 위에 있다. 퀘스트 표시 없음. 한 번 지나면 보통 날씨.
#   HG_HAMHEUNG(권역): 동문 밖 — 세 전갈꾼(S6001). 끝난 뒤 돌아온 전갈꾼·소문(지역 변화).
#   HG_HAMHEUNG-BUKCHEONG(노정, 북청길): 함관령 눈보라(S6002 길 잃은 막동) → 고개 넘어 수레 약탈(S6003 갑술, 도적 둘) → 숲 발자국(S6004)
#     → 함관령 옛 역참(world-scenario rt_sc_yeokcham: 등잔·벽 지도·화로·불탄 장부·기록함) S6005~S6011 — 이겸 재회, 「서강의 두 필체」 카드(S6009).
# 조건식: story_runner(f·k·c·has·n·ph·v·out·w·fn·seen).
extends RefCounted

const RT5 := "PA_PYEONGYANG-HG_HAMHEUNG"
const HG := "HG_HAMHEUNG"
const RTB := "HG_HAMHEUNG-BUKCHEONG"
const COIN := "COIN"
const POUCH := "ITM_HG_POUCH"          # 막동의 전갈 주머니(감영 인)
const LUGGAGE := "ITM_HG_LUGGAGE"      # R05 눈에 묻힌 봇짐
const RECORD := "ITM_KEY_HG_RECORD"    # 이겸의 기록 한 묶음(서강 창고 — 곽칠성)
const RESOLVED := "out('A') or out('B') or out('C')"
const ACTIVE := "f('case_started') and not ph('done')"
const PASS_X := -20.0                  # R05 양덕 고갯마루(노정 좌표 x)
const SOUTH_ROUTE := "SEA_NAMHAE_JEJU"

static func data() -> Dictionary:
	return {
		"case": {
			"id": "hamhung", "record_title": "돌아오지 않는 전갈", "EVENT_CLASS": "MAIN_FRAME", "SOURCE_ID": "MAIN_FRAME_HAMHUNG_COURIERS", "region": HG, "outcome_var": "CASE_HAMHUNG_OUTCOME",
			"start_hour": 11.0, "start_event": { HG: "S6001", RT5: "", RTB: "" }, "start_on_arrival": true,
			# 평양(ACT 3) 사건이 끝나야 선다 — 그 전에는 R05·함흥·북청길 모두 소문만
			"requires": { "CASE_PYONGYANG_COMPLETE": true },
			"rule_label": "눈길에서 본 것", "rules_title": "눈길에서 본 것",
			"reset_vars": ["CASE_HAMHUNG_OUTCOME", "CASE_HAMHUNG_DETAIL", "CASE_HAMHUNG_COMPLETE", "MAIN_MASTER_FOUND", "MAIN_PAST_EVENT_KNOWN", "SKILL_TOOL_SLOT_PLUS",
				"HAMHUNG_MESSENGERS_RETURNED", "HAMHUNG_SEOGANG_CARD_SEEN"],
		},
		"items": {
			COIN: "엽전", POUCH: "전갈 주머니(함흥 감영 인)", LUGGAGE: "눈에 묻혀 있던 봇짐", RECORD: "이겸의 기록 한 묶음",
			"ITM_TOOL_009": "사건 기록책", "ITM_WPN_001": "환도", "ITM_WPN_002": "활", "ITM_AMMO_001": "화살",
		},
		"hidden_items": ["ITM_TOOL_009", "ITM_WPN_001", "ITM_WPN_002", "ITM_AMMO_001"],
		"clues": clues(),
		"rules": {
			"R_SNOW_COVERS": { "kind": "fact", "title": "눈은 발자국을 덮는다", "text": "눈보라 속 발자국은 금세 옅어진다. 지금 따라가지 않으면 길이 없어진다." },
			"R_TURNED_SIGN": { "kind": "guess", "title": "길을 돌려놓는 사람이 있다", "text": "양덕 고개의 이정표도, 함관령의 표목도 사람이 돌려놓았다. 짐수레가 엉뚱한 길로 들도록.",
				"text_if": [["not f('r05_sign_seen')", "함관령 표목은 사람이 돌려놓았다. 짐수레가 엉뚱한 길로 들도록."]] },
			"R_RESCUE_FIRST": { "kind": "fact", "title": "기록보다 구조가 먼저인 때가 있다", "text": "노인은 제 기록을 한 장씩 태워 언 사람을 살렸다. 묻는 것은 그다음이었다." },
		},
		"anchors": anchors(),
		# 지도: 아전이 북청길·함관령을 일러 준다(들음). 역참은 가 봐야 적힌다(이겸이 있다는 것을 미리 알려 주지 않는다)
		"map_places": [
			{ "id": "hg_east_gate", "space": HG, "name": "함흥 동문 밖 역참 마당", "at": "clerk_spot", "radius": 20.0, "known": "f('case_started')" },
			{ "id": "hamgwal", "space": RTB, "name": "함관령", "at": "shrine_rest", "radius": 24.0, "known": "f('case_started')" },
			{ "id": "yeokcham", "space": RTB, "name": "함관령 옛 역참", "at": "station_door", "radius": 14.0 },
			{ "id": "gowon_jumak", "space": RT5, "name": "고원 길가 주막", "at": "gowon_inn", "radius": 30.0 },
		],
		# 지도 붉은 표(갈 곳, 보강서 §20) — 아전·봇짐 쪽지·눈길 발자국이 일러 준 곳만. 막동·갑술 자리, 역참 안 이겸은 미리 알리지 않는다(fn 금지)
		"map_leads": [
			{ "id": "hg_gowon_inn", "space": RT5, "name": "고원 주막(봇짐 주인)", "at": "gowon_inn", "when": "c('r05_luggage')", "until": "f('r05_returned')",
				"note": "R0701 눈에 묻힌 봇짐의 쪽지 “고원 주막 — 김 서방”" },
			{ "id": "hg_east_gate", "space": HG, "name": "함흥 동문 밖 역참 마당", "at": "clerk_spot", "hub": true, "when": "true", "until": "ph('done')",
				"note": "S6001 평양 사건 뒤 함흥 도착 — 역참 아전(사건의 들머리)" },
			{ "id": "hg_hamgwal", "space": RTB, "name": "함관령(북청길)", "at": "shrine_rest", "when": "f('case_started')",
				"until": "f('cart_seen') or c('turned_post') or f('station_entered')",
				"note": "S6001 아전 “구휼미 수레를 따라 함관령을 넘었소.” · 선택지 “북청길로 간다 (함관령)”" },
			{ "id": "hg_forest_light", "space": RTB, "name": "숲 위 불빛", "at": "station_door", "when": "c('tracks')", "until": "f('station_entered')",
				"note": "S6004 clue tracks “길에서 북쪽 숲으로 발자국 둘 … 숲 위에 불빛.” · 갑술 “순돌이는 북쪽 숲으로 뛰었소” — 이름(역참·이겸)은 쓰지 않는다" },
			{ "id": "hg_to_jeju", "name": "제주", "region": "JJ_JEJU", "when": "seen('S6010')", "until": "v('CASE_JEJU_COMPLETE') == true",
				"note": "S6010 이겸 “곽칠성은 제주로 갔다.” · Discovery.tell region:JJ_JEJU · “제주 가는 배는 해남 관두포에서 뜬다”" },
		],
		"journal": {
			"unknowns": [
				{ "text": "세 전갈꾼은 어디 있는가.", "when": "f('case_started')", "until": "f('station_entered')" },
				{ "text": "막동은 어디로 갔는가.", "when": "c('pouch') and not f('madong_saved')", "until": "f('madong_saved') or f('station_entered')" },
				{ "text": "수레는 왜 고개 북쪽으로 끌려갔는가.", "when": "c('cart_raided')", "until": "k('R_TURNED_SIGN')" },
				{ "text": "숲으로 간 발자국 둘은 누구인가.", "when": "c('tracks')", "until": "f('station_entered')" },
				{ "text": "스승은 왜 돌아오지 않았는가.", "when": "f('master_met')", "until": "f('asked_why')" },
			],
			"places": [
				{ "name": "함흥 동문 밖", "when": "f('case_started')" }, { "name": "함관령 서낭당", "when": "f('rtb_arrived')" },
				{ "name": "고개 넘어 수레 자리", "when": "c('cart_raided')" }, { "name": "함관령 옛 역참", "when": "f('station_entered')" },
			],
			"items": [{ "id": POUCH, "when": "true" }, { "id": RECORD, "when": "true" }],
			"solutions_when": "f('case_started')",
		},
		"actors": actors(),
		"objects": objects(),
		"triggers": triggers(),
		"props": props(),
		"arenas": arenas(),
		"documents": documents(),
		"events": events(),
	}

static func clues() -> Dictionary:
	return {
		# ---- R05(노정) — 사건 기록이 서기 전이라 기록책에는 사건이 열린 뒤 '적어 둔 것'으로 보인다 ----
		"r05_horse": { "kind": "fact", "title": "쓰러진 짐말", "text": "양덕 서쪽 숲길. 짐말이 얼어 쓰러졌다. 짐은 벗겨 갔다.",
			"text_if": [["f('r05_horse_read')", "양덕 서쪽 숲길. 짐말이 얼어 쓰러졌다. 짐승이 건드린 자국은 없다 — 추위다. 짐은 사람이 벗겨 갔다."]] },
		"r05_sign": { "kind": "fact", "title": "돌아간 이정표", "text": "신창 옛 원터 갈림길. 이정표 기둥 밑동의 언 흙이 새로 갈라져 있다. 누가 돌려놓았다 — '양덕'이 막다른 원터 쪽을 가리켰다." },
		"r05_luggage": { "kind": "fact", "title": "눈에 묻힌 봇짐", "text": "양덕 고갯마루 아래. 눈 둔덕 밑에 봇짐 하나 — 언 주먹밥, 짚신 한 켤레, '고원 주막 — 김 서방'이라 적힌 쪽지." },
		"r05_tracks": { "kind": "fact", "title": "세 갈래 발자국", "text": "고원 쪽 내리막에서 사람 발자국이 세 갈래로 갈라졌다. 두 줄은 조금 가다 되돌아와 다시 한 줄이 됐다.",
			"text_if": [["f('r05_tracks_read')", "고원 쪽 내리막에서 사람 발자국이 세 갈래로 갈라졌다. 두 줄은 길을 찾다 되돌아왔고, 셋은 고원 쪽으로 같이 갔다. 따라붙은 짐승 발자국은 없다."]] },
		# ---- 함흥 ----
		"three_couriers": { "kind": "heard", "by": "역참 아전", "title": "세 전갈꾼", "text": "사흘 전 북청으로 보낸 전갈꾼 셋 — 막동·갑술·순돌. 구휼미 수레를 따라갔다. 아무도 돌아오지 않았다." },
		"joke": { "kind": "heard", "by": "동문 밖 사람들", "title": "함흥차사 농담", "text": "사람들은 함흥에서 보낸 사람이 안 돌아오니 '함흥차사'라고 웃는다. 아전은 웃지 않는다." },
		# ---- 북청길 ----
		"pouch": { "kind": "fact", "title": "길 위의 전갈 주머니", "text": "함관령 오르는 길 위. 감영 인이 찍힌 가죽 주머니. 길 아래 골짜기로 비틀거린 발자국이 내려간다." },
		"madong": { "kind": "heard", "by": "막동", "title": "막동", "text": "떨군 주머니를 주우러 돌아섰다가 눈보라에 길을 잃었다고 한다. 갑술과 순돌은 수레와 고개를 넘었다." },
		"cart_raided": { "kind": "fact", "title": "약탈당한 수레", "text": "고개 넘어 길가. 엎어진 구휼미 수레, 터진 가마니. 끌채 끈은 칼로 끊겼다." },
		"turned_post": { "kind": "fact", "title": "돌아간 표목", "text": "함관령 서낭당 곁 표목이 고개 북쪽 옛 숲길을 가리킨다. 밑동 흙이 새로 갈라져 있다." },
		"gapsul": { "kind": "heard", "by": "갑술", "title": "갑술", "text": "표목을 따라 북쪽 숲길로 들었다가 도적 둘에게 붙잡혔다. 순돌은 숲으로 달아났다고 한다." },
		"gapsul_taken": { "kind": "fact", "title": "끌려간 갑술", "text": "도적들은 수레 끌던 갑술을 끌고 고개 북쪽으로 사라졌다." },
		"tracks": { "kind": "fact", "title": "숲으로 간 발자국 둘", "text": "길에서 북쪽 숲으로 발자국 둘 — 끌리듯 걷는 짚신 하나, 곁을 받치는 가죽신 하나. 숲 위에 불빛." },
		# ---- 역참 ----
		"station": { "kind": "fact", "title": "함관령 옛 역참", "text": "버려진 역참 서쪽 방. 등잔불, 벽 지도, 화로. 노인 하나가 종이를 한 장씩 불에 넣는다. 화로 곁에 젊은 역졸 하나가 떨며 누워 있다." },
		"sundol": { "kind": "heard", "by": "순돌", "title": "순돌", "text": "숲에서 쓰러졌는데 노인이 업어 왔다. 노인은 사흘째 제 종이를 태워 불을 지폈다." },
		"ledger_rows": { "kind": "fact", "title": "맞지 않는 섬 수", "text": "반쯤 탄 서강 창 출납 장부. 들어온 섬과 나간 섬이 줄마다 맞지 않는다 — 나간 것이 더 많다." },
		"park_ledger": { "kind": "fact", "title": "불탄 장부의 朴", "text": "반쯤 탄 곡물 장부. 그을린 가장자리에 붉은 朴 표식 — 돋보기로 그을음 밑을 훑어 찾았다. 한양 책방 납품표·운송장·평양 대장에서 본 것과 같다." },
		"gwak_record": { "kind": "fact", "title": "곽칠성이라는 이름", "text": "기록함 속 이겸의 옛 기록. 서강 창고 사건의 증인 명단 — 곽칠성. 이름 위에 줄이 그어져 있다." },
		"woochi_map": { "kind": "fact", "title": "벽 지도의 다른 먹", "text": "이겸의 벽 지도. 지나온 고을마다 작은 표. 한양 서강에만 다른 사람의 먹으로 동그라미 — 마른 지 오래지 않다." },
		# S6009 조사 카드 「서강의 두 필체」 — 설명 없이 카드로. 뒷장은 최종장(S8003·S8004) 복선: 들음·적힌 것·결론 그대로(정답 확정 금지)
		"seogang_hands": { "kind": "fact", "title": "서강의 두 필체", "text": "불탄 기록 묶음. 같은 서강 창고 일을 두 손이 적었다 — 본 것과 들은 것을 갈라 적은 스승의 필체, 사람을 모으려 부풀린 다른 필체. 그 먹빛은 벽 지도 서강 동그라미의 먹이다." },
		"seogang_testimony": { "kind": "heard", "by": "옛 증언", "title": "창고 벽을 세 번", "text": "“불이 난 뒤 며칠, 창고 벽을 세 번 치는 소리를 들었다.”" },
		"seogang_memo": { "kind": "fact", "title": "젖은 쌀겨 위의 자국", "text": "기록 묶음 뒷장에 이렇게 적혀 있다 — “비가 그친 뒤 젖은 쌀겨 위로 자국이 이어졌으나 발자국은 없었다.” 누가 본 것인지는 적혀 있지 않다." },
		"seogang_conclusion": { "kind": "fact", "title": "스승의 당시 결론", "text": "“확인할 수 없음.”" },
		"gwak_jeju": { "kind": "heard", "by": "이겸", "title": "곽칠성 — 제주", "text": "곽칠성은 제주로 귀양 갔다. “내가 가야 했는데 못 갔다.”" },
	}

static func anchors() -> Dictionary:
	return {
		# ---- R05 평양→함흥(노정 좌표) ----
		"r05_horse": [-205.0, 4.6], "r05_horse_look": [-205.0, 2.2], "r05_sign": [-118.0, 2.6], "r05_sign_look": [-118.5, 5.2],
		"r05_luggage": [42.0, 14.6], "r05_luggage_look": [41.0, 12.0], "r05_split": [130.0, 8.4],
		"gowon_inn": [299.6, 8.0], "gowon_spot_a": [296.5, 3.4], "gowon_spot_b": [299.0, 3.0], "gowon_spot_c": [301.6, 3.6],
		# ---- 함흥 동문 밖(권역 좌표) ----
		"hg_arrive": [-178.0, 64.0], "clerk_spot": [-188.0, 57.0], "town_a_spot": [-176.0, 71.0], "town_b_spot": [-174.0, 73.0],
		"madong_home": [-183.0, 55.8], "gapsul_home": [-180.8, 56.4], "sundol_home": [-185.2, 55.2], "raiders_tied": [-196.5, 66.5], "bowl_spot": [-189.0, 52.0],
		# ---- 북청길(노정 좌표) ----
		"rtb_start": [-372.0, 11.0], "pouch": [-332.0, 5.4], "madong_spot": [-321.0, 32.0], "shrine_rest": [-265.5, 9.0], "shrine_fire": [-264.0, 10.6],
		"pass_post": [-262.0, -1.5], "cart": [-236.0, -5.0], "cart_arena": [-236.0, 0.0], "gapsul_spot": [-239.0, -7.5], "raider_flee": [-200.0, -35.0],
		"tracks_start": [-196.6, -22.5], "station_door": [-203.6, -57.6], "room_in": [-204.3, -60.3],
		"yg_spot": [-204.9, -62.0], "sundol_spot": [-203.4, -62.7], "ledger": [-203.33, -61.26], "ham": [-206.44, -63.16], "wall_map": [-204.86, -64.0],
	}

# ---------------------------------------------------------------------------
# 인물(CHARACTER_MASTER v1.3): 이겸 CHR_MAIN_002(yigyeom), 전갈꾼 셋(나그네 변형 courier·courier_b·courier_c), 역참 아전(official),
#   동문 밖 사람(villager_m·villager_f), 고원 주막 나그네 셋(traveler·peddler·villager_m), 도적 둘(raider·raider_b — 싸움은 arenas)
# ---------------------------------------------------------------------------
static func actors() -> Array:
	return [
		# ---- R05 고원 주막: 눈보라를 피한 나그네 셋(세 갈래 발자국의 주인) ----
		{ "id": "gowon_kim", "space": RT5, "kind": "traveler", "name": "김 서방", "at": "gowon_spot_b", "facing": "down", "anim": "idle",
			"when": "fn('r05_on')",
			"talk": [{ "when": "true", "steps": [{ "call": "gowon_talk" }] }] },
		{ "id": "gowon_b", "space": RT5, "kind": "peddler", "name": "나그네", "at": "gowon_spot_a", "facing": "right", "when": "fn('r05_on')",
			"talk": [{ "when": "true", "steps": [{ "say": "나그네", "lines": ["고개에서 길을 셋으로 나눠 찾았소. 둘은 헛걸음이었지."] }] }] },
		{ "id": "gowon_c", "space": RT5, "kind": "villager_m", "name": "나그네", "at": "gowon_spot_c", "facing": "left", "when": "fn('r05_on')",
			"talk": [{ "when": "true", "steps": [{ "say": "나그네", "lines": ["함흥 간다고? 거기서 북청 보낸 전갈꾼이 사흘째 안 온다더군. 함흥차사가 따로 없지, 허허."] }] }] },
		# ---- 함흥 ----
		{ "id": "clerk", "space": HG, "chr": "CHR_HUM_016", "kind": "official", "name": "역참 아전", "at": "clerk_spot", "facing": "down", "radius": 2.6,
			"talk": [
				{ "when": "ph('done')", "steps": [{ "call": "clerk_done" }] },
				{ "when": "not f('case_started')", "steps": [{ "event": "S6001" }] },
				{ "when": "true", "steps": [{ "say": "역참 아전", "lines": ["함관령만 넘으면 홍원이오. 눈이 그치길 기다릴 수는 없소."] }, { "call": "offer_travel" }] },
			] },
		{ "id": "town_a", "space": HG, "kind": "villager_m", "name": "장꾼", "at": "town_a_spot", "facing": "left",
			"talk": [
				{ "when": RESOLVED, "steps": [{ "call": "town_done" }] },
				{ "when": "true", "steps": [{ "say": "장꾼", "lines": ["함흥에서 보낸 사람은 안 돌아오는 법이라오. 옛날부터 그랬다지 않소, 허허."] }, { "clue": "joke" }] },
			] },
		{ "id": "town_b", "space": HG, "kind": "villager_f", "name": "아낙", "at": "town_b_spot", "facing": "up",
			"talk": [
				{ "when": "out('A')", "steps": [{ "say": "아낙", "lines": ["셋 다 왔대요. 이번 차사는 돌아왔네."] }] },
				{ "when": RESOLVED, "steps": [{ "say": "아낙", "lines": ["다들 함흥차사라고 웃었지요. …웃을 일이 아니었어."] }] },
				{ "when": "true", "steps": [{ "say": "아낙", "lines": ["순돌이 어미가 사흘째 동문 밖에 나와 있어요."] }] },
			] },
		{ "id": "madong_hg", "space": HG, "kind": "courier", "name": "막동", "at": "madong_home", "facing": "down", "anim": "sit",
			"when": "ph('done') and f('madong_saved')",
			"talk": [{ "when": "true", "steps": [{ "say": "막동", "lines": ["주머니 그거, 감영에 잘 들어갔소. 발가락은 다 붙어 있고."] }] }] },
		{ "id": "gapsul_hg", "space": HG, "kind": "courier_b", "name": "갑술", "at": "gapsul_home", "facing": "down",
			"when": "ph('done') and f('gapsul_saved')",
			"talk": [{ "when": "true", "steps": [{ "say": "갑술", "lines": ["다음엔 표목 말고 서낭당 돌무더기를 보고 가겠소."] }] }] },
		{ "id": "sundol_hg", "space": HG, "kind": "courier_c", "name": "순돌", "at": "sundol_home", "facing": "down",
			"when": "ph('done')",
			"talk": [{ "when": "true", "steps": [{ "say": "순돌", "lines": ["그 노인 어른은 아직 그 역참에 계시오? 종이를 다 태우셨을 텐데."] }] }] },
		# ---- 북청길 ----
		# S6002 막동: 길 아래 골짜기 소나무 밑(눈보라). 역참에 먼저 들어가면 그 사이 발자국이 덮인다(구조 기회가 닫힌다)
		{ "id": "madong", "space": RTB, "kind": "courier", "name": "막동", "at": "madong_spot", "facing": "down", "anim": "cower", "radius": 2.8,
			"when": ACTIVE + " and not f('madong_saved') and not f('station_entered')",
			"talk": [{ "when": "true", "steps": [{ "event": "S6002" }] }] },
		{ "id": "madong_rest", "space": RTB, "kind": "courier", "name": "막동", "at": "shrine_rest", "facing": "right", "anim": "sit", "radius": 2.4,
			"when": ACTIVE + " and f('madong_saved')",
			"talk": [{ "when": "true", "steps": [{ "say": "막동", "lines": ["불 곁에 있으리다. 갑술이랑 순돌이를… 부탁하오."] }] }] },
		{ "id": "raider_hg", "space": HG, "kind": "raider", "name": "붙잡힌 도적", "at": "raiders_tied", "facing": "down", "anim": "tied",
			"when": "ph('done') and f('raider_caught')",
			"talk": [{ "when": "true", "steps": [{ "say": "붙잡힌 도적", "lines": ["…표목 하나 돌렸을 뿐이오. 눈이 다 한 일이지."] }] }] },
		{ "id": "gapsul", "space": RTB, "kind": "courier_b", "name": "갑술", "at": "gapsul_spot", "facing": "up", "anim": { "default": "tied" }, "radius": 2.6,
			"when": "f('cart_seen') and not f('gapsul_taken') and not f('gapsul_gone') and not ph('done')",
			"talk": [
				{ "when": "f('gapsul_saved')", "steps": [{ "say": "갑술", "lines": ["함흥으로 내려가 알리겠소. 순돌이는 북쪽 숲으로 뛰었소."] }] },
				{ "when": "f('cart_fought')", "steps": [{ "call": "free_gapsul" }] },
			] },
		# 이겸(CHR_MAIN_002) — 역참 서쪽 방 화로 곁. 처음엔 종이를 태우고(burn), 끝난 뒤엔 적는다(write)
		{ "id": "yigyeom", "space": RTB, "chr": "CHR_MAIN_002", "kind": "yigyeom", "name": "노인", "at": "yg_spot", "facing": "right",
			"anim": { "done": "write", "default": "burn" }, "radius": 2.0,
			"when": "f('case_started')",
			"talk": [
				{ "when": "ph('done')", "steps": [{ "call": "master_done" }] },
				{ "when": "f('master_met')", "steps": [{ "call": "master_talk" }] },
			] },
		{ "id": "sundol", "space": RTB, "kind": "courier_c", "name": "순돌", "at": "sundol_spot", "facing": "left",
			"anim": { "default": "cower", "done": "sit" }, "radius": 1.8,
			"when": "f('case_started') and not ph('done')",
			"talk": [
				{ "when": "f('sundol_tended')", "steps": [{ "say": "순돌", "lines": ["…발이 이제 제 발 같소."] }] },
				{ "when": "f('master_met')", "steps": [{ "call": "tend_sundol" }] },
			] },
	]

# ---------------------------------------------------------------------------
# 조사 대상
# ---------------------------------------------------------------------------
static func objects() -> Array:
	var r05 := "fn('r05_on')"
	return [
		# ---- R05 노정 사건 넷(퀘스트 표시 없음 — 길 위에 그냥 있다) ----
		{ "id": "r05_horse", "space": RT5, "at": "r05_horse", "label": "쓰러진 말 · 살펴보기", "radius": 3.4, "when": r05 + " and not c('r05_horse')",
			"steps": [{ "call": "r05_horse" }] },
		{ "id": "r05_sign", "space": RT5, "at": "r05_sign", "label": "이정표 · 살펴보기", "radius": 2.8, "when": r05 + " and not f('r05_sign_done')",
			"steps": [{ "call": "r05_sign" }] },
		{ "id": "r05_luggage", "space": RT5, "at": "r05_luggage", "label": "눈 둔덕 · 살펴보기", "radius": 2.6, "when": r05 + " and not c('r05_luggage')",
			"steps": [{ "call": "r05_luggage" }] },
		{ "id": "r05_tracks", "space": RT5, "at": "r05_split", "label": "발자국 · 살펴보기", "radius": 3.2, "when": r05 + " and not c('r05_tracks')",
			"steps": [{ "call": "r05_tracks" }] },
		# ---- 북청길 ----
		{ "id": "pouch", "space": RTB, "at": "pouch", "label": "길 위의 주머니 · 살펴보기", "radius": 2.4, "when": ACTIVE + " and not c('pouch')",
			"steps": [{ "call": "take_pouch" }] },
		{ "id": "pass_post", "space": RTB, "at": "pass_post", "label": "표목 · 살펴보기", "radius": 2.4, "when": ACTIVE + " and not c('turned_post')",
			"steps": [{ "call": "pass_post" }] },
		{ "id": "cart", "space": RTB, "at": "cart", "label": "엎어진 수레 · 살펴보기", "radius": 3.0, "when": ACTIVE + " and f('cart_fought') and not f('cart_looked')",
			"steps": [{ "call": "look_cart" }] },
		# 역참 방(S6007) — 물건마다 짧은 주고받음
		{ "id": "ledger", "space": RTB, "at": "ledger", "label": "불탄 장부 · 살펴보기", "radius": 1.3, "when": ACTIVE + " and f('master_met') and not f('ledger_done')",
			"steps": [{ "call": "room_ledger" }] },
		{ "id": "ham", "space": RTB, "at": "ham", "label": "기록함 · 살펴보기", "radius": 1.4, "when": ACTIVE + " and f('master_met') and not f('ham_done')",
			"steps": [{ "call": "room_ham" }] },
		{ "id": "wall_map", "space": RTB, "at": "wall_map", "label": "벽 지도 · 살펴보기", "radius": 1.4, "when": ACTIVE + " and f('master_met') and not f('map_done')",
			"steps": [{ "call": "room_map" }] },
		# S6009 — 물음(S6008) 뒤 이겸이 불탄 장부 자리에 내려놓은 기록 묶음. 살펴보면 「서강의 두 필체」 카드
		{ "id": "seogang_bundle", "space": RTB, "at": "ledger", "label": "불탄 기록 묶음 · 살펴보기", "radius": 1.3,
			"when": ACTIVE + " and f('asked_why') and not f('seogang_card_seen')", "steps": [{ "event": "S6009" }] },
	]

static func triggers() -> Array:
	return [
		# R05: 처음 지날 때(날씨 단계는 case.ambient) — 길가에 무언가 보이면 한 줄(조작을 막지 않는 엿보기 자막)
		{ "id": "r05_horse_see", "space": RT5, "at": "r05_horse", "radius": 18.0, "when": "fn('r05_on')", "steps": [{ "call": "glance", "args": ["길가 눈 속에 무언가 시커멓게 누워 있다."] }] },
		{ "id": "r05_tracks_see", "space": RT5, "at": "r05_split", "radius": 14.0, "when": "fn('r05_on')", "steps": [{ "call": "glance", "args": ["눈 위의 발자국이 여기서 갈라진다."] }] },
		# 함흥 동문 밖 — 지나가며 듣는 농담(§37 A15 — 사람들의 농담으로만)
		{ "id": "s6001_overhear", "space": HG, "at": "clerk_spot", "radius": 22.0, "when": "not f('case_started')", "ambient": [
			["장꾼", "북청 간 전갈꾼이 사흘째 깜깜이라며?"], ["장꾼", "함흥차사 났구먼. 함흥에서 보낸 놈은 원래 안 오는 거야, 허허."]] },
		# 북청길에 들어서면(사건 중)
		{ "id": "rtb_arrive", "space": RTB, "at": "rtb_start", "radius": 60.0, "when": ACTIVE + " and not f('rtb_arrived')", "steps": [{ "call": "rtb_arrival" }] },
		# S6003 고개 넘어 수레 — 다가가면 도적이 일어선다
		{ "id": "s6003", "space": RTB, "at": "cart_arena", "radius": 15.0, "when": ACTIVE + " and not f('cart_seen')", "event": "S6003" },
		# S6004 숲으로 간 발자국
		{ "id": "s6004", "space": RTB, "at": "tracks_start", "radius": 11.0, "when": ACTIVE + " and not f('tracks_seen')", "event": "S6004" },
		# S6005 역참 문 앞
		{ "id": "s6005", "space": RTB, "at": "station_door", "radius": 3.6, "when": ACTIVE + " and not f('station_entered')", "event": "S6005" },
	]

# ---------------------------------------------------------------------------
# 소품(kit/story/snow_road.gd, kit/route/ijeongpyo.gd, kit/story/sea.gd, 세계 데칼)
# ---------------------------------------------------------------------------
static func props() -> Array:
	var r05 := "fn('r05_on') or c('r05_horse')"
	return [
		# R05 — 한 번 지난 뒤에도 쓰러진 말과 이정표는 남는다(바로 세웠으면 바로 선 채)
		{ "id": "p_r05_horse", "space": RT5, "kit": "story/snow_road", "params": { "kind": "horse", "seed": 501 }, "at": "r05_horse", "ry": 1.35, "when": "fn('r05_active_ever')" },
		{ "id": "p_r05_sign_bad", "space": RT5, "kit": "route/ijeongpyo", "params": { "kind": "post", "seed": 502 }, "at": "r05_sign", "ry": -1.45,
			"when": "fn('r05_active_ever') and not f('r05_sign_fixed')" },
		{ "id": "p_r05_sign_ok", "space": RT5, "kit": "route/ijeongpyo", "params": { "kind": "post", "seed": 502 }, "at": "r05_sign", "ry": 0.15, "when": "f('r05_sign_fixed')" },
		{ "id": "p_r05_sign_dirt", "space": RT5, "at": "r05_sign", "decal": { "kind": "mud", "size": 1.1 }, "when": "fn('r05_active_ever')" },
		{ "id": "p_r05_luggage", "space": RT5, "kit": "story/snow_road", "params": { "kind": "luggage", "seed": 503 }, "at": "r05_luggage", "ry": 0.4,
			"when": r05 + " and not c('r05_luggage')" },
		{ "id": "p_r05_luggage_dug", "space": RT5, "kit": "story/snow_road", "params": { "kind": "mound", "r": 0.5, "seed": 504 }, "at": "r05_luggage", "ry": 0.4, "when": "c('r05_luggage')" },
		{ "id": "p_r05_hoof", "space": RT5, "trail": { "kind": "hoof", "points": [[-226.0, 0.2], [-214.0, 1.6], [-207.0, 3.6]], "step": 0.9, "size": 0.45 }, "when": "fn('r05_on')" },
		{ "id": "p_r05_tr_a", "space": RT5, "trail": { "kind": "foot", "points": [[112.0, 8.2], [130.0, 8.4], [148.0, 8.0], [170.0, 8.0]], "step": 0.8, "size": 0.5 }, "when": "fn('r05_on')" },
		{ "id": "p_r05_tr_b", "space": RT5, "trail": { "kind": "foot", "points": [[130.5, 7.6], [136.0, -4.0], [141.0, -13.0], [135.5, -4.5], [131.0, 7.0]], "step": 0.8, "size": 0.5 }, "when": "fn('r05_on')" },
		{ "id": "p_r05_tr_c", "space": RT5, "trail": { "kind": "foot", "points": [[130.0, 9.2], [126.0, 19.0], [121.0, 27.0], [125.5, 19.5], [129.5, 9.8]], "step": 0.8, "size": 0.5 }, "when": "fn('r05_on')" },
		# 함흥 — 지역 변화(§30)
		{ "id": "p_hg_bowl", "space": HG, "kit": "story/sea", "params": { "kind": "bowl" }, "at": "bowl_spot", "ry": 0.2, "when": "ph('done') and not f('madong_saved')" },
		# 북청길
		{ "id": "p_pouch", "space": RTB, "kit": "story/snow_road", "params": { "kind": "pouch" }, "at": "pouch", "ry": 0.6, "when": ACTIVE + " and not c('pouch')" },
		{ "id": "p_lost_trail", "space": RTB, "trail": { "kind": "foot", "points": [[-331.5, 7.0], [-329.0, 14.0], [-326.0, 20.5], [-323.0, 27.0], [-321.5, 30.5]], "step": 0.85, "size": 0.5 },
			"when": ACTIVE + " and not f('madong_saved') and not f('station_entered')" },
		{ "id": "p_shrine_fire", "space": RTB, "kit": "story/snow_road", "params": { "kind": "fire" }, "at": "shrine_fire", "ry": 0.0, "when": "f('madong_saved') and not ph('done')" },
		{ "id": "p_pass_post", "space": RTB, "kit": "route/ijeongpyo", "params": { "kind": "post", "seed": 603 }, "at": "pass_post", "ry": 1.6 },
		{ "id": "p_pass_post_dirt", "space": RTB, "at": "pass_post", "decal": { "kind": "mud", "size": 1.0 }, "when": "f('case_started')" },
		{ "id": "p_cart", "space": RTB, "kit": "story/snow_road", "params": { "kind": "cart", "seed": 604 }, "at": "cart", "ry": 0.5, "when": "f('case_started')" },
		{ "id": "p_cart_drag", "space": RTB, "trail": { "kind": "drag", "points": [[-238.0, -7.0], [-232.0, -14.0], [-222.0, -24.0], [-210.0, -32.0]], "step": 1.2, "size": 0.7 },
			"when": "f('gapsul_taken')" },
	]

# 문서(scripts/story/documents.gd): S6007 불탄 장부 — 그을린 가장자리 밑의 朴은 플레이어가 돋보기로 직접 찾는다
static func documents() -> Dictionary:
	return {
		"burnt_ledger": { "title": "불탄 출납 장부", "short": "불탄 장부", "aspect": 1.42, "seed": 6007,
			"paper": { "base": "#e3d5b4", "fiber": 0.55, "fiber_col": "#7a6648", "lines": 7, "line_col": "#9a5a4a70" },
			"cols": [
				{ "x": 0.86, "y": 0.07, "text": "서강 창 곡물 출납", "size": 0.06, "ink": 0.9 },
				{ "x": 0.75, "y": 0.1, "text": "들어온 쌀 이백 석", "size": 0.05, "ink": 0.88 },
				{ "x": 0.645, "y": 0.1, "text": "나간 쌀 이백오십 석", "size": 0.05, "ink": 0.88 },
				{ "x": 0.54, "y": 0.1, "text": "들어온 조 일백 석", "size": 0.05, "ink": 0.86 },
				{ "x": 0.435, "y": 0.1, "text": "나간 조 일백사십 석", "size": 0.05, "ink": 0.86 },
				{ "x": 0.33, "y": 0.1, "text": "남은 것 없음", "size": 0.05, "ink": 0.8, "bleed": 0.3 },
				{ "x": 0.2, "y": 0.1, "text": "받은 이", "size": 0.05, "ink": 0.75 },
			],
			"images": [{ "tex": "res://assets/story/park_mark.png", "region": [0, 0, 128, 128], "rect": [0.12, 0.775, 0.13, 0.09], "alpha": 0.8 }],
			"burns": [{ "side": "bottom", "depth": 0.3, "seed": 61 }, { "side": "left", "depth": 0.16, "seed": 62 }],
			"hotspots": [
				{ "id": "rows", "rect": [0.4, 0.08, 0.4, 0.55], "level": "plain", "label": "섬 수", "text": "들어온 쌀 이백 석, 나간 쌀 이백오십 석. 조도 들어온 것보다 나간 것이 많다.", "clue": "ledger_rows" },
				{ "id": "park_edge", "rect": [0.1, 0.76, 0.17, 0.12], "level": "plain", "label": "그을린 가장자리", "text": "그을음 밑에 붉은 인 — 朴. '받은 이' 줄 끝이다.", "clue": "park_ledger" },
			] },
		# S6009 「서강의 두 필체」 — 같은 서강 창고 일을 두 사람이 적은 두 장. 왼쪽(스승)은 줄머리마다 확인·들음·모름, 오른쪽(다른 먹)은 부풀린 글
		"seogang_yigyeom": { "title": "기록 한 장 — 스승의 필체", "short": "스승의 필체", "aspect": 1.42, "seed": 6091,
			"paper": { "base": "#e6dcc2", "fiber": 0.5, "fiber_col": "#7a6648", "lines": 7, "line_col": "#9a5a4a60" },
			"cols": [
				{ "x": 0.86, "y": 0.07, "text": "서강 창 화재", "size": 0.06, "ink": 0.92 },
				{ "x": 0.74, "y": 0.1, "text": "확인 · 창 서쪽 벽이 먼저 탔다", "size": 0.05, "ink": 0.9 },
				{ "x": 0.63, "y": 0.1, "text": "확인 · 짐꾼 강복 죽음", "size": 0.05, "ink": 0.9 },
				{ "x": 0.52, "y": 0.1, "text": "확인 · 장부 섬 수 맞지 않음", "size": 0.05, "ink": 0.9 },
				{ "x": 0.41, "y": 0.1, "text": "들음 · 불 전날 밤 수레 소리", "size": 0.05, "ink": 0.86 },
				{ "x": 0.30, "y": 0.1, "text": "들음 · 원혼이 운다는 말", "size": 0.05, "ink": 0.86 },
				{ "x": 0.19, "y": 0.1, "text": "모름 · 누가 불을 냈는가", "size": 0.05, "ink": 0.86 },
			],
			"burns": [{ "side": "left", "depth": 0.1, "seed": 63 }],
			"hotspots": [
				{ "id": "split", "rect": [0.14, 0.08, 0.66, 0.11], "level": "plain", "label": "줄머리",
					"text": "줄마다 머리에 '확인'·'들음'·'모름'. 본 것과 들은 것을 갈라 적었다. 스승의 필체다.", "pair": "seogang_hands" },
			] },
		"seogang_woochi": { "title": "기록 한 장 — 다른 필체", "short": "다른 필체", "aspect": 1.42, "seed": 6092,
			"paper": { "base": "#ddd2b8", "fiber": 0.7, "fiber_col": "#6e5f4a", "lines": 0 },
			"cols": [
				{ "x": 0.85, "y": 0.06, "text": "서강 창 원혼기", "size": 0.066, "ink": 0.9, "bleed": 0.35, "col": "#3b3346" },
				{ "x": 0.72, "y": 0.12, "text": "불 속에서 짐꾼이 사흘 밤 울었다", "size": 0.054, "ink": 0.88, "bleed": 0.35, "col": "#3b3346" },
				{ "x": 0.60, "y": 0.09, "text": "벽 치는 소리를 온 마포가 들었다", "size": 0.054, "ink": 0.88, "bleed": 0.35, "col": "#3b3346" },
				{ "x": 0.48, "y": 0.13, "text": "창 주인이 죄를 묻으려 불을 놓았다", "size": 0.054, "ink": 0.86, "bleed": 0.35, "col": "#3b3346" },
				{ "x": 0.36, "y": 0.1, "text": "원혼이 이름을 부르기 전에", "size": 0.054, "ink": 0.86, "bleed": 0.35, "col": "#3b3346" },
				{ "x": 0.24, "y": 0.12, "text": "모두 창 앞에 모이라", "size": 0.06, "ink": 0.9, "bleed": 0.35, "col": "#3b3346" },
			],
			"burns": [{ "side": "bottom", "depth": 0.12, "seed": 64 }],
			"hotspots": [
				{ "id": "swell", "rect": [0.55, 0.08, 0.22, 0.62], "level": "plain", "label": "부풀린 줄",
					"text": "본 사람 없는 울음을 '사흘 밤', 몇이 들은 소리를 '온 마포'라 적었다. 사람을 모으려는 글. 먹빛이 벽 지도의 서강 동그라미와 같다.", "pair": "seogang_hands" },
			] },
	}

# 싸움터: 고개 넘어 수레 — 도적 둘(몽둥이·장대). 달아나면 고개 북쪽 숲으로
static func arenas() -> Dictionary:
	return {
		"cart": { "at": "cart_arena", "radius": 11.0, "camera": { "pitch": 46.0, "distance": 20.0, "fov": 30.0 },
			"foe_name": "도적", "intro": "가마니를 뒤지던 사내 둘이 몽둥이와 장대를 든다!", "flee_to": "raider_flee",
			"humans": [
				{ "id": "rd_a", "kind": "raider", "name": "도적", "weapon": "club", "hp": 60.0, "flee_at": 0.2, "offset": [3.0, -2.0] },
				{ "id": "rd_b", "kind": "raider_b", "name": "장대 든 도적", "weapon": "pole", "hp": 50.0, "flee_at": 0.35, "offset": [-3.0, -3.5] },
			] },
	}

# ---------------------------------------------------------------------------
# 사건 장면(§44 필드 + steps) — EVENT_CLASS MAIN_FRAME(§1.11). 함흥차사(A15)는 사람들의 농담·연상(FOLKLORE_ECHO_IDS)일 뿐 출처가 아니다.
# R05 노정 사건은 §16 고정 이동 사건(메인) — 함흥 사건의 들머리(새 괴이·금기 없음).
# ---------------------------------------------------------------------------
static func _ev(id: String, trigger: String, loc: String, tw: String, actions: String, branches: String, wsc: String, steps: Array) -> Dictionary:
	return {
		"EVENT_ID": id, "EVENT_CLASS": "MAIN_FRAME", "RECORD_TITLE": "돌아오지 않는 전갈", "SOURCE_ID": "MAIN_FRAME_HAMHUNG_COURIERS",
		"MAIN_FRAME_ORIGIN_NOTE": "창작 메인 프레임 ACT 4 — 눈보라·도적·돌린 표목이라는 사람의 일과 이겸 재회, 서강 창고의 두 필체(S6009). 함흥차사는 사람들의 농담·연상일 뿐 출처가 아니다.",
		"FOLKLORE_ECHO_IDS": ["A15"], "FOLKLORE_ANCHOR_IDS": [], "FOLKLORE_ANCHOR_MODE": "",
		"FOLKLORE_ECHO_TITLE_INTERNAL": "함흥차사(돌아오지 않는 차사 모티프)",
		"FOLKLORE_ECHO_NOTE": "함흥 지역 고정 전승(§37 A15). 사건의 정체가 아니라 사람들이 실종을 두고 하는 농담으로만 쓴다. 차사·태조 고사는 설명하지 않는다(§1.3). 실제 실종은 눈보라·도적·길이라는 사람의 일이다.",
		"TRIGGER": trigger, "LOCATION_TYPE": loc, "TIME_WEATHER": tw,
		"PLAYER_ACTIONS": actions, "RESOLUTION_BRANCHES": branches, "WORLD_STATE_CHANGE": wsc,
		"steps": steps,
	}

static func events() -> Dictionary:
	return {
		"R0701": _ev("R0701", "평양 사건 뒤 처음 평양→함흥 노정을 지남", "성천·양덕 고개·고원 길", "흐림 → 바람 → 눈 → 고개 눈보라",
			"쓰러진 말·돌아간 이정표·눈에 묻힌 짐·세 갈래 발자국을 본다(짐승 흔적 읽기)", "-", "이정표를 바로 세움 · 봇짐을 주인에게", []),
		"S6001": _ev("S6001", "평양 사건 뒤 함흥 도착(동문 밖 역참 마당)", "함흥 동문 밖", "낮 · 눈발",
			"엿듣는 농담 · 아전과 대화", "-", "사건 기록 생성", [
			{ "if": "not f('arrived')", "then": [{ "call": "arrival" }] },
			{ "face": "clerk", "to": "player" },
			{ "say": "역참 아전", "lines": ["웃을 일이 아니오. 북청 보낸 전갈꾼 셋이 사흘째요.", "구휼미 수레를 따라 함관령을 넘었소. 막동, 갑술, 순돌."] },
			{ "call": "start_case" },
			{ "call": "offer_travel" },
		]),
		"S6002": _ev("S6002", "함관령 오르는 길 아래 골짜기 — 발자국을 따라가면", "함관령 골짜기", "낮 · 눈보라",
			"주머니를 줍고 발자국을 따라 막동을 찾는다 · 업어 서낭당 돌담 밑 불 곁으로", "구조 / 역참에 먼저 가면 발자국이 덮여 놓침", "-", [
			{ "call": "rescue_madong" },
		]),
		"S6003": _ev("S6003", "고개 넘어 엎어진 수레", "함관령 동쪽 길가", "낮 · 눈보라",
			"도적 둘과 짧게 싸운다 · 묶인 갑술을 푼다", "이김: 갑술을 구함 / 물러남·쓰러짐: 도적이 갑술을 끌고 감", "-", [
			{ "call": "cart_fight" },
		]),
		"S6004": _ev("S6004", "길에서 숲으로 간 발자국", "함관령 동쪽 숲", "저녁 · 눈보라",
			"발자국을 따라 숲 위 불빛으로", "-", "-", [
			{ "call": "tracks" },
		]),
		"S6005": _ev("S6005", "역참 문 앞", "함관령 옛 역참 서쪽 방", "저녁 · 눈보라 · 실내 등잔",
			"방을 돌아본다(등잔·벽 지도·불탄 기록·종이를 태우는 노인)", "-", "-", [
			{ "call": "enter_station" },
		]),
		"S6006": _ev("S6006", "S6005 바로 뒤", "역참 방", "-", "-", "-", "MAIN_MASTER_TRACE += HAMHUNG", []),
		"S6007": _ev("S6007", "방의 물건을 살펴볼 때마다", "역참 방", "-", "불탄 장부(朴 — 플레이어가 먼저 찾음)·기록함(곽칠성)·벽 지도(우치)", "-", "MAIN_PARK_MARK_COUNT += 1", []),
		"S6008": _ev("S6008", "물건을 다 본 뒤 이겸에게", "역참 방", "-", "“왜 돌아오지 않았습니까?”", "-", "-", []),
		# S6009 조사 카드 「서강의 두 필체」(v2.4 §17) — 장문 대사 없이 카드로. 닫은 뒤 이겸 한 줄: “그때 우치도 거기 있었지.”
		"S6009": _ev("S6009", "S6008 뒤 — 이겸이 내려놓은 불탄 기록 묶음을 살펴봄", "역참 방", "-",
			"두 필체 카드(이겸: 확인·들음을 가름 / 우치: 사람을 움직이려 부풀림) · 뒷장의 옛 증언·메모·이겸의 결론", "-",
			"MAIN_PAST_EVENT_KNOWN · HAMHUNG_SEOGANG_CARD_SEEN(최종장 S8003·S8004 복선)", [
			{ "call": "seogang_card" },
		]),
		"S6010": _ev("S6010", "S6009 카드를 닫은 뒤", "역참 방", "-", "기록을 챙긴다", "-", "MAIN_MASTER_FOUND · 곽칠성 — 제주 · 남해 뱃길 안내", []),
		# S6011 결말 판정(v2.4 §17) — 돌아온 전갈꾼 수. 지역 결말·후속 대사에만 쓰고 최종장 FINAL_*에는 직접 쓰지 않는다
		"S6011": _ev("S6011", "S6010 뒤", "함관령 옛 역참 → 함흥", "새벽 · 눈 그침", "-",
			"A 셋 다 돌아옴(3) · B 둘 — 막동 또는 갑술을 놓침(2) · C 하나 — 순돌만(1)",
			"HAMHUNG_MESSENGERS_RETURNED 3/2/1 · CASE_HAMHUNG_OUTCOME A/B/C · CASE_HAMHUNG_COMPLETE", []),
	}
