# 사건 「굴에 남은 숨」(ACT 5 제주, S7001~S7008)과 ACT 4.5 제주 접근(남해 뱃길 첫 건넘) — 이야기 데이터.
# 시나리오: seolhwa/docs/scenario/seolhwarok_master_scenario_storyboard_v2.3.1_consistency_lock.md §18(제주 접근)·§19(S7001~S7008)
#   (규칙 §1.3~§1.8, 곽칠성 §3.4, 주술 §6.5 — 감지·접근·보호·의식만, 변수 §7, 소문 §24, 대사 §27, 컷신 §28, 실패 §29, 지역 변화 §30,
#    소스 잠금 §36(제주 무가·심방은 제주 안에서만), 전승 앵커 §37 A18~A21(제주 — 소문·풍경으로만), §39 JJ-03, F48 김녕 큰 구렁이(원작 제목은 내보이지 않는다))
# 체감 장르(§1.7): 신앙·감응 — "섞여 있는 흔적을 나누되, 먼저 살아 있는 사람을 찾는다."(S7008 — 플레이어 자신의 첫 문장, 이겸 메모 없음)
# 실패(구조만 하고 나옴)는 게임오버가 아니라 결말 B(굴 봉쇄)·소문·지역 변화로 남는다(§29). 싸움은 C를 고를 때만(구렁이 — 짐승 상대 ccreature.gd).
#
# 두 공간에 걸친 사건(story_director CASES — 같은 사건 id, 항목 "space"로 가름):
#   SEA_NAMHAE_JEJU(남해 뱃길 — 남원 남쪽 끝 → 곡성 → 영산강 나루 → 덕진다리 → 해남 관두포 → 바다 → 화북포): 함흥 뒤 처음 지날 때
#     길목마다 한 줄, 관두포 사공, 제주 첫 뱃길(건너뛰기 없음 — boats.skip_lock) 동안 바다 위 몇 줄.
#   굴 안은 실내 공간 jj_sagul(region_data/interiors/jj_sagul/interior.json — 김녕 앞바다 1000m 북쪽 자리에 따로 세운다). 아래 굴 안 자리는 그 월드 좌표.
#     입구(권역 금줄 안쪽)로 걸어 들면 짧은 암전으로 들어가고, 출구 자리에서 나온다. 이야기 teleport도 그대로 넘나든다(region_main.teleport).
#   JJ_JEJU(권역): 화북포 생활(해녀·불턱·용천수·돌담) → 곽칠성(S7001) → 김녕 아이 실종(S7002) → 김녕사굴 입구(S7003) → 심방·감응 매듭(S7004)
#     → 굴 안(S7005 — 어둠·등불, 실제 구렁이, 도굴 자리, 벽 너머 큰 잔영) → 아이(S7006) → 해결(S7007 A·B·C) → 곽칠성의 나무패(S7008)
# 감응 매듭: scripts/story/sensing.gd(흔적의 결 trace human|other|mixed — objects·traces·데칼). 매듭은 답을 말하지 않는다 — 떨거나 가만하다.
# 조건식: story_runner(f·k·c·has·n·ph·v·out·w·fn·seen·tal).
extends RefCounted

const RS := "SEA_NAMHAE_JEJU"
const JJ := "JJ_JEJU"
const LANE := "jeju_sea_lane"
const KNOT := "ITM_RIT_004"            # 감응 매듭(호신물 — spirits.gd TALISMANS)
const LANTERN := "ITM_JJ_LANTERN"      # 초롱(곽칠성이 건넴 — 굴 안은 어둡다)
const BOWL := "ITM_JJ_BOWL"            # 놋 제물 그릇(도굴 자리)
const TALLY := "ITM_KEY_001"           # 강복의 곡물 수량패(나무패)
const SAG := "jj_sagul"                # 김녕사굴 안 — 실내 공간(region_data/interiors/jj_sagul). 권역의 입구는 jj_sagul_sagul_01
const RESOLVED := "out('A') or out('B') or out('C')"
const ACTIVE := "f('case_started') and not ph('done') and not ph('after')"
const INCAVE := "f('case_started') and ph('gimnyeong')"
const PLAYER_LINE := "섞여 있는 흔적을 나누되, 먼저 살아 있는 사람을 찾는다."

static func data() -> Dictionary:
	return {
		"case": {
			"id": "jeju", "record_title": "굴에 남은 숨", "region": JJ, "outcome_var": "CASE_JEJU_OUTCOME",
			"start_hour": 10.0, "start_event": { JJ: "", RS: "" }, "start_on_arrival": true,
			# 함흥(ACT 4)이 끝나야 선다 — 그 전에는 남해 뱃길·제주 모두 소문만
			"requires": { "CASE_HAMHUNG_COMPLETE": true },
			"rule_label": "굴에서 본 것", "rules_title": "굴에서 본 것",
			"reset_vars": ["CASE_JEJU_OUTCOME", "CASE_JEJU_COMPLETE", "MAIN_GWAK_FOUND", "ITEM_SENSING_KNOT", "ITEM_KEY_001", "ACT6_OPEN", "PLAYER_FIRST_LINE"],
		},
		"items": {
			LANTERN: "초롱", BOWL: "놋 제물 그릇", TALLY: "강복의 곡물 수량패(나무패)", KNOT: "감응 매듭",
			"COIN": "엽전", "ITM_TOOL_009": "사건 기록책", "ITM_WPN_001": "환도", "ITM_WPN_002": "활", "ITM_AMMO_001": "화살",
		},
		"hidden_items": ["ITM_TOOL_009", "ITM_WPN_001", "ITM_WPN_002", "ITM_AMMO_001", KNOT],
		"clues": clues(),
		"rules": {
			"R_KNOT_STILL": { "kind": "guess", "title": "사람 손이 만든 자국 곁에서 매듭은 가만하다", "text": "끊긴 금줄, 가죽신 발자국 곁에서 매듭은 늘어져 있었다. 큰 뱀이 기어 든 자국 곁에서는 떨었다." },
			"R_FAKE_TRACK": { "kind": "guess", "title": "넓은 '뱀 자국' 하나는 사람이 끌어 만들었다", "text": "비늘 결이 없고 짚 부스러기가 묻었다. 매듭도 가만했다. 굴에 사람이 오지 않게 하려는 것일까." },
			"R_MIXED_ALTAR": { "kind": "guess", "title": "제단 자리엔 둘이 섞였다", "text": "뱀이 떡을 먹고 끌어간 자국과, 사람이 놋그릇을 들고 간 자리. 매듭이 떨리다 멎다 했다." },
		},
		"anchors": anchors(),
		"traces": traces(),
		"map_places": [
			{ "id": "hw_port", "space": JJ, "name": "화북포 물가", "at": "hw_spring", "radius": 30.0 },
			{ "id": "gw_cave", "space": JJ, "name": "김녕 굴(김녕사굴)", "at": "gw_gather", "radius": 24.0, "known": "f('case_started')" },
		],
		"journal": {
			"unknowns": [
				{ "text": "덕이는 굴 어디에 있는가.", "when": "f('case_started')", "until": "f('child_found')" },
				{ "text": "금줄을 끊고 제물을 가져간 것은 누구인가.", "when": "c('rope_cut') or c('offer_gone')", "until": "c('dig_site')" },
				{ "text": "입구의 흔적 가운데 무엇이 사람이 만든 것인가.", "when": "f('s7003')", "until": "k('R_KNOT_STILL')" },
				{ "text": "굴 안쪽 벽 너머로 지나간 것은 무엇인가.", "when": "c('shade')", "until": "false" },
			],
			"places": [
				{ "name": "화북포", "when": "f('jj_arrived')" }, { "name": "김녕 굴 입구", "when": "f('s7003')" },
				{ "name": "굴 안 옛 제단", "when": "c('offer_gone')" }, { "name": "굴 안 옆 굴(덕이가 숨은 곳)", "when": "f('child_found')" },
				{ "name": "굴 안 도굴 자리", "when": "c('dig_site')" },
			],
			"items": [{ "id": LANTERN, "when": "true" }, { "id": BOWL, "when": "true" }],
			"solutions_when": "f('child_saved')",
		},
		"actors": actors(),
		"objects": objects(),
		"triggers": triggers(),
		"props": props(),
		"arenas": arenas(),
		"spirits": [
			# 김녕 대형 구렁이 잔영(CHR_CRE_009 — 확대 변형): 굴 안쪽 끝 벽 너머로 길게 지나간다. 싸움 상대가 아니다.
			{ "id": "shade", "space": JJ, "kind": "jj_shade", "name": "", "at": "shade_a", "facing": "left", "when": "f('shade_wake')",
				"night": false, "sense": true, "motion": "drift", "path": ["shade_a", "shade_b"], "loop": false, "speed": 1.7,
				"range": 70.0, "alpha_in": 0.72, "alpha_out": 0.72, "lift": 0.95 },
		],
		"sounds": [
			# B·C 뒤 밤 — 막힌 굴(또는 베인 뱀 뒤) 돌 틈에서 새는 긴 숨(매듭을 지니면 들린다)
			{ "id": "breath", "space": JJ, "from": "gw_gather", "when": "out('B') or out('C')", "night": true, "sense": true,
				"every": [14.0, 22.0], "range": 60.0, "caption": "굴 쪽에서 길게 숨 내쉬는 소리가 난다.", "near": "막힌 돌 틈 사이로 긴 숨이 샌다.", "near_r": 14.0, "dir": true, "fx": "ring" },
		],
		"events": events(),
	}

static func clues() -> Dictionary:
	return {
		# ---- 화북포 ----
		"gwak_porter": { "kind": "heard", "by": "화북 아낙", "title": "귀양 온 늙은 짐꾼", "text": "“귀양 온 늙은이? 곽 서방이오. 열 몇 해째 포구에서 짐을 지오. 말은 없소.”" },
		"gwak_closed": { "kind": "heard", "by": "곽칠성", "title": "곽칠성", "text": "서강 창고 일을 묻자 짐을 내려놓고 한마디만 했다. “그 일은 끝났소.”" },
		"outsiders": { "kind": "heard", "by": "화북 뱃사람", "title": "육지 배", "text": "“육지 배가 어제 둘 들었소. 한 배는 짐도 안 풀고 김녕 쪽으로 돌았지.”" },
		# ---- 김녕 ----
		"child_missing": { "kind": "heard", "by": "김녕 사람", "title": "덕이가 없어졌다", "text": "김녕 아이 덕이가 어제 해 질 녘 굴 쪽으로 가는 것을 본 사람이 있다. 밤새 돌아오지 않았다." },
		"cave_talk": { "kind": "heard", "by": "김녕 노인", "title": "굴의 뱀", "text": "“그 굴엔 큰 뱀이 사오. 옛날 어느 판관이 베었다지만, 그 뒤로도 굴 앞엔 금줄을 치고 제물을 올렸소.”" },
		"rope_cut": { "kind": "fact", "title": "끊긴 금줄", "text": "굴 입구 금줄이 끊겼다. 끝이 칼로 자른 듯 반듯하다." },
		"snake_track": { "kind": "fact", "title": "큰 뱀이 기어 든 자국", "text": "입구 흙에 굵은 몸이 기어 들어간 자국. 비늘 결이 그대로 찍혔다." },
		"shoe_track": { "kind": "fact", "title": "가죽신 발자국", "text": "굴 안으로 든 가죽신 발자국 둘. 이 마을 사람들은 짚신이나 미투리를 신는다." },
		"fake_track": { "kind": "fact", "title": "넓은 '뱀 자국'", "text": "입구 왼편 풀밭에서 굴로 넓게 끈 자국. 비늘 결이 없고, 가장자리에 짚 부스러기.",
			"text_if": [["f('sack_found')", "입구 왼편 풀밭에서 굴로 넓게 끈 자국. 비늘 결이 없다. 자국 끝 풀숲에 찢어진 짚 섬과 새끼줄."]] },
		"offer_gone": { "kind": "fact", "title": "비어 있는 제물상", "text": "굴 안 옛 제단 돌 앞 제물상이 비었다. 떡 부스러기 위로 무언가 굵게 끌고 간 자국. 놋그릇은 없다." },
		"stele": { "kind": "fact", "title": "입구 곁 옛 비석", "text": "닳은 비석. 다 읽을 수 없다. 마을 사람들은 옛날 판관 이야기를 한다 — 지금 굴에 있는 것과 같은 것인지는 모른다." },
		# ---- 굴 안 ----
		"snake_seen": { "kind": "fact", "title": "굴 안의 구렁이", "text": "굴 안쪽에 사람 팔뚝보다 굵은 구렁이가 사려 있다. 다가가면 고개를 치켜든다." },
		"shade": { "kind": "fact", "title": "벽 너머로 지나간 것", "text": "굴 안쪽 끝 벽 너머로, 굴보다 긴 무엇이 천천히 지나갔다. 사려 있던 구렁이와는 크기가 다르다." },
		"child_story": { "kind": "heard", "by": "덕이", "title": "덕이가 본 것", "text": "“등불 든 아저씨 둘이 굴로 들어가길래 따라갔어. 큰 뱀이 나와서 옆 굴에 숨었어.”" },
		"dig_site": { "kind": "fact", "title": "도굴 자리", "text": "굴 안 바닥을 파헤친 구덩이. 깨진 독 조각, 곡괭이 자루. 구덩이 곁에 흙 묻은 놋그릇 — 제단에서 사라진 그릇이다." },
		"shed": { "kind": "fact", "title": "허물", "text": "굴 안쪽 바닥에 큰 허물. 사려 있던 구렁이보다 조금 작다." },
		# ---- S7008 ----
		"tally": { "kind": "fact", "title": "강복의 곡물 수량패", "text": "닳은 나무패. 칼로 새긴 섬 수 눈금. 곽칠성이 열두 해 동안 지녔다. “저 숫자 때문에 사람이 죽었소.”" },
		"park_alive": { "kind": "heard", "by": "곽칠성", "title": "박규상", "text": "그 이름을 대자 곽칠성이 되물었다. “아직 살아 있소?”" },
	}

static func anchors() -> Dictionary:
	return {
		# ---- 남해 뱃길(노정 좌표) — 관두포 선창은 불러올 때 뱃길 내릴 자리로 고친다(jeju_case.on_load) ----
		"rs_start": [-646.0, 13.1], "rs_deokjin": [-374.3, -93.8], "rs_gwandu": [-164.1, -109.2], "rs_pier": [-70.0, -40.0], "rs_boatman": [-74.0, -36.0],
		"rs_hwabuk": [535.7, -18.8],
		# ---- 화북포(권역 좌표) ----
		"jj_arrive": [-1923.2, -418.0], "hw_square": [-1919.0, -428.4], "hw_spring": [-1927.2, -535.0], "hw_woman_spot": [-1931.0, -530.5], "heobeok": [-1929.6, -529.4],
		"bulteok": [-1958.0, -566.0], "haenyeo_a": [-1955.8, -562.8], "haenyeo_b": [-1960.2, -563.0], "tewak": [-1951.5, -569.5],
		"gwak_pier": [-1913.0, -543.0], "hw_man_spot": [-1908.0, -539.5], "runner_from": [-1878.0, -498.0], "runner_to": [-1909.5, -541.5],
		# ---- 김녕사굴(권역 좌표 — 굴 가운데 (3432.4, −915.7), 입구는 남쪽 z −895) ----
		"gw_arrive": [3432.4, -882.5], "gw_gather": [3432.4, -886.5], "gw_mother": [3429.8, -885.0], "gw_elder": [3436.4, -884.3], "gw_man": [3427.4, -887.4],
		"gw_gwak": [3434.9, -887.6], "gw_simbang": [3438.6, -886.4], "gw_simbang_in": [3438.6, -879.0], "gw_child_out": [3430.6, -884.6],
		"rope": [3432.6, -895.1], "snake_tr": [3433.3, -893.3], "shoe_tr": [3431.6, -892.6], "fake_tr": [3428.2, -885.6], "sack": [3425.6, -879.0],
		"stele": [3437.6, -890.6],
		"altar_look": [3433.21, -1901.59], "jemul": [3434.32, -1902.17],
		"cave_mid": [3433.35, -1911.69], "child_spot": [3434.93, -1917.67], "child_look": [3433.23, -1917.69],
		"dig": [3430.11, -1923.43], "pit": [3429.52, -1924.64], "bowl_prop": [3430.21, -1924.03],
		"snake_spot": [3430.97, -1928.12], "snake_face": [3430.73, -1925.12], "crevice": [3430.46, -1934.93], "shed": [3432.98, -1928.69], "deep": [3431.94, -1933.61],
		"arena_c": [3430.75, -1926.62], "fight_start": [3430.99, -1922.12],
		"shade_a": [3441.82, -1938.77], "shade_b": [3422.82, -1939.03],
		"stones": [3432.4, -894.4],
	}

# 흔적의 결(감응 매듭 — sensing.gd): 세계에 이미 있는 것(금줄·제물상·굴 안쪽)
static func traces() -> Array:
	return [
		{ "id": "t_rope", "space": JJ, "at": "rope", "radius": 2.2, "trace": "human", "when": INCAVE },
		{ "id": "t_altar", "space": JJ, "at": "jemul", "radius": 3.0, "trace": "mixed", "when": INCAVE },
		{ "id": "t_snake", "space": JJ, "at": "snake_spot", "radius": 4.5, "trace": "other", "when": INCAVE + " and not f('snake_dead') and not f('snake_gone')" },
		{ "id": "t_deep", "space": JJ, "at": "deep", "radius": 6.5, "trace": "other", "when": "f('case_started') and not out('A')" },
		{ "id": "t_deep_a", "space": JJ, "at": "deep", "radius": 4.0, "trace": "mixed", "when": "out('A')" },
	]

# ---------------------------------------------------------------------------
# 인물(CHARACTER_MASTER v1.3): 곽칠성 CHR_MAIN_004(gwak), 제주 심방 CHR_MAIN_012(simbang), 덕이(jj_child), 제주 사람(jj_man·jj_woman — 갈옷),
#   해녀(haenyeo — 고을 사람 프레임), 관두포 사공(boatman), 구렁이 CHR_CRE_008(jj_snake — 싸움은 arenas)
# ---------------------------------------------------------------------------
static func actors() -> Array:
	var gw := "f('case_started')"
	return [
		# ---- 남해 뱃길 — 관두포 사공 ----
		{ "id": "rs_boatman", "space": RS, "kind": "boatman", "name": "관두포 사공", "at": "rs_boatman", "facing": "down",
			"talk": [{ "when": "true", "steps": [{ "call": "boatman_talk" }] }] },
		# ---- 화북포 생활 ----
		{ "id": "hw_woman", "space": JJ, "kind": "jj_woman", "name": "화북 아낙", "at": "hw_woman_spot", "facing": "right",
			"talk": [
				{ "when": "ph('done')", "steps": [{ "call": "hw_woman_done" }] },
				{ "when": "true", "steps": [{ "call": "hw_woman_talk" }] },
			] },
		{ "id": "haenyeo_a", "space": JJ, "kind": "haenyeo", "name": "해녀", "at": "haenyeo_a", "facing": "left",
			"talk": [{ "when": "true", "steps": [{ "say": "해녀", "lines": ["물이 차서 오늘은 일찍 나왔소. 불턱에 와서 손 좀 녹이시오."] }] }] },
		{ "id": "haenyeo_b", "space": JJ, "kind": "haenyeo", "name": "해녀", "at": "haenyeo_b", "facing": "right",
			"talk": [{ "when": "true", "steps": [{ "call": "haenyeo_b_talk" }] }] },
		{ "id": "hw_man", "space": JJ, "kind": "jj_man", "name": "화북 뱃사람", "at": "hw_man_spot", "facing": "left",
			"talk": [{ "when": "true", "steps": [{ "say": "화북 뱃사람", "lines": ["육지 배가 어제 둘 들었소. 한 배는 짐도 안 풀고 김녕 쪽으로 돌았지."] }, { "clue": "outsiders" }] }] },
		# 곽칠성(CHR_MAIN_004) — 처음엔 '늙은 짐꾼'. 화북포 물가에서 짐을 진다 → 김녕 수색 → 사건 뒤 굴 앞
		{ "id": "gwak", "space": JJ, "chr": "CHR_MAIN_004", "kind": "gwak", "name": "늙은 짐꾼",
			"at": { "default": "gwak_pier", "gimnyeong": "gw_gwak", "after": "gw_gwak", "done": "gw_gwak" }, "facing": { "default": "left", "gimnyeong": "down" },
			"anim": { "default": "idle", "after": "sit" }, "radius": 2.4,
			"talk": [
				{ "when": "ph('done')", "steps": [{ "call": "gwak_done" }] },
				{ "when": "ph('after')", "steps": [{ "event": "S7008" }] },
				{ "when": "ph('gimnyeong')", "steps": [{ "call": "gwak_search" }] },
				{ "when": "not f('gwak_met')", "steps": [{ "event": "S7001" }] },
				{ "when": "true", "steps": [{ "call": "gwak_again" }] },
			] },
		# ---- 김녕 굴 앞 수색 ----
		{ "id": "mother", "space": JJ, "kind": "jj_woman", "name": "덕이 어미", "at": "gw_mother", "facing": "right",
			"anim": { "default": "cry" }, "when": gw,
			"talk": [
				{ "when": "f('child_saved')", "steps": [{ "say": "덕이 어미", "lines": ["…고맙소. 고맙소."] }] },
				{ "when": "true", "steps": [{ "say": "덕이 어미", "lines": ["어제 해 질 녘에 굴 쪽으로 가는 걸 봤다는 사람이 있소. 밤새 불러도 대답이 없었소."] }, { "clue": "child_missing" }] },
			] },
		{ "id": "gw_elder", "space": JJ, "kind": "jj_man", "name": "김녕 노인", "at": "gw_elder", "facing": "left", "when": gw,
			"talk": [
				{ "when": RESOLVED, "steps": [{ "call": "elder_done" }] },
				{ "when": "true", "steps": [{ "say": "김녕 노인", "lines": ["그 굴엔 큰 뱀이 사오. 옛날 어느 판관이 베었다지만, 그 뒤로도 굴 앞엔 금줄을 치고 제물을 올렸소."] }, { "clue": "cave_talk" }] },
			] },
		{ "id": "gw_man", "space": JJ, "kind": "jj_man", "name": "김녕 장정", "at": "gw_man", "facing": "right", "when": gw,
			"talk": [
				{ "when": "f('child_saved') and not " + RESOLVED, "steps": [{ "call": "decide" }] },
				{ "when": RESOLVED, "steps": [{ "say": "김녕 장정", "lines": ["덕이는 어미 곁에서 잠만 자오."] }] },
				{ "when": "true", "steps": [{ "say": "김녕 장정", "lines": ["밤새 굴 앞까지는 와 봤소. 안은… 아무도 안 들어갔소."] }] },
			] },
		# 제주 심방(CHR_MAIN_012) — S7003 흔적을 둘 넘게 본 뒤 굴 앞에 닿는다(S7004 감응 매듭)
		{ "id": "simbang", "space": JJ, "chr": "CHR_MAIN_012", "kind": "simbang", "name": "심방", "at": "gw_simbang", "facing": "left",
			"anim": { "default": "idle" }, "when": "f('simbang_here')",
			"talk": [
				{ "when": RESOLVED, "steps": [{ "call": "simbang_done" }] },
				{ "when": "f('bowl_got') and f('pit_filled') and f('child_saved')", "steps": [{ "call": "ritual_offer" }] },
				{ "when": "true", "steps": [{ "call": "simbang_talk" }] },
			] },
		# 덕이(아이) — 굴 안 옆 굴에 웅크림(S7006). 구한 뒤엔 어미 곁
		{ "id": "child", "space": JJ, "kind": "jj_child", "name": "아이", "at": { "default": "child_spot" }, "facing": "left", "anim": { "default": "cower" }, "radius": 2.2,
			"when": INCAVE + " and not f('child_saved')",
			"talk": [{ "when": "true", "steps": [{ "event": "S7006" }] }] },
		{ "id": "child_out", "space": JJ, "kind": "jj_child", "name": "덕이", "at": "gw_child_out", "facing": "left", "anim": "hug",
			"when": "f('child_saved')",
			"talk": [{ "when": "true", "steps": [{ "say": "덕이", "lines": ["벽 뒤로 커다란 게 지나갔어. 그 뱀보다 훨씬 컸어."] }] }] },
		# 구렁이(실제 뱀) — 굴 안쪽에 사려 있다. 다가가면 고개를 치켜들고 문다(jeju_case.ambient). C를 고르면 싸움(arenas.snake)
		{ "id": "snake", "space": JJ, "kind": "jj_snake", "name": "구렁이", "at": "snake_spot", "facing": "right", "anim": "idle", "radius": 3.9,
			"when": INCAVE + " and not f('snake_gone') and not f('snake_dead')", "verb": "살펴보기",
			"talk": [{ "when": "true", "steps": [{ "call": "snake_face" }] }] },
		{ "id": "snake_body", "space": JJ, "kind": "jj_snake", "name": "", "at": "snake_spot", "facing": "right", "anim": "fall",
			"when": "f('snake_dead')" },
	]

# ---------------------------------------------------------------------------
# 조사 대상(trace — 감응 매듭이 떠는가: human 가만 · other 떪 · mixed 떨다 멎다)
# ---------------------------------------------------------------------------
static func objects() -> Array:
	var mouth := INCAVE + " and f('s7003')"
	return [
		{ "id": "rope", "space": JJ, "at": "rope", "label": "끊긴 금줄 · 살펴보기", "radius": 1.6, "trace": "human", "trace_r": 2.0, "when": mouth, "steps": [{ "call": "look", "args": ["rope"] }] },
		{ "id": "snake_tr", "space": JJ, "at": "snake_tr", "label": "흙 위의 자국 · 살펴보기", "radius": 1.3, "trace": "other", "trace_r": 1.6, "when": mouth, "steps": [{ "call": "look", "args": ["snake_tr"] }] },
		{ "id": "shoe_tr", "space": JJ, "at": "shoe_tr", "label": "발자국 · 살펴보기", "radius": 1.3, "trace": "human", "trace_r": 1.6, "when": mouth, "steps": [{ "call": "look", "args": ["shoe_tr"] }] },
		{ "id": "fake_tr", "space": JJ, "at": "fake_tr", "label": "넓게 끈 자국 · 살펴보기", "radius": 1.8, "trace": "human", "trace_r": 2.2, "when": mouth, "steps": [{ "call": "look", "args": ["fake_tr"] }] },
		{ "id": "altar", "space": JJ, "at": "altar_look", "label": "옛 제단 · 살펴보기", "radius": 1.8, "trace": "mixed", "trace_r": 3.0, "when": mouth, "steps": [{ "call": "look", "args": ["altar"] }] },
		{ "id": "stele", "space": JJ, "at": "stele", "label": "옛 비석 · 살펴보기", "radius": 1.6, "when": mouth + " and not c('stele')", "steps": [{ "call": "look", "args": ["stele"] }] },
		{ "id": "sack", "space": JJ, "at": "sack", "label": "풀숲 · 살펴보기", "radius": 1.6, "trace": "human", "when": mouth + " and c('fake_track') and not f('sack_found')", "steps": [{ "call": "look", "args": ["sack"] }] },
		{ "id": "dig", "space": JJ, "at": "dig", "label": "파헤친 자리 · 살펴보기", "radius": 1.7, "trace": "human", "trace_r": 2.2, "when": INCAVE + " and has('" + LANTERN + "') and not f('pit_filled')",
			"steps": [{ "call": "look", "args": ["dig"] }] },
		{ "id": "shed", "space": JJ, "at": "shed", "label": "허물 · 살펴보기", "radius": 1.5, "trace": "other", "trace_r": 2.0, "when": INCAVE + " and (f('snake_gone') or f('snake_dead')) and not c('shed')",
			"steps": [{ "call": "look", "args": ["shed"] }] },
	]

static func triggers() -> Array:
	return [
		# ---- 남해 뱃길(함흥 뒤 첫 지남 — 조작을 막지 않는 한 줄) ----
		{ "id": "rs_arrive", "space": RS, "at": "rs_start", "radius": 90.0, "when": "fn('approach_on')", "steps": [{ "call": "rs_arrival" }] },
		{ "id": "rs_deokjin", "space": RS, "at": "rs_deokjin", "radius": 30.0, "when": "fn('approach_on')", "steps": [{ "call": "glance", "args": ["덕진다리 주막. 뱃사람들이 남쪽 바람을 두고 말을 주고받는다."] }] },
		{ "id": "rs_gwandu", "space": RS, "at": "rs_gwandu", "radius": 34.0, "when": "fn('approach_on')", "steps": [{ "call": "glance", "args": ["해남 관두포. 제주 가는 돛배가 바람을 기다린다."] }] },
		# ---- 화북포 ----
		{ "id": "jj_arrive", "space": JJ, "at": "jj_arrive", "radius": 120.0, "when": "not f('jj_arrived')", "steps": [{ "call": "jj_arrival" }] },
		{ "id": "hw_overhear", "space": JJ, "at": "hw_spring", "radius": 18.0, "when": "not f('case_started')", "ambient": [
			["화북 아낙", "육지 배가 또 들었네. 이번엔 무얼 싣고 왔을까."], ["해녀", "물이 차. 불턱에 불 좀 지펴 두게."]] },
		# ---- 김녕 굴 ----
		{ "id": "s7003", "space": JJ, "at": "rope", "radius": 7.5, "when": INCAVE + " and not f('s7003')", "event": "S7003" },
		{ "id": "s7004", "space": JJ, "at": "gw_gather", "radius": 30.0, "once": true, "when": INCAVE + " and fn('mouth_seen') >= 2 and not f('simbang_here')", "event": "S7004" },
		{ "id": "s7005", "space": JJ, "at": "cave_mid", "radius": 3.2, "when": INCAVE + " and has('" + LANTERN + "') and not seen('S7005')", "event": "S7005" },
	]

# ---------------------------------------------------------------------------
# 소품(kit/story/jeju.gd, 세계 데칼) — 화북포 생활과 굴의 지역 변화(§30)
# ---------------------------------------------------------------------------
static func props() -> Array:
	return [
		# 화북포 생활(사건과 상관없이)
		{ "id": "p_bulteok", "space": JJ, "kit": "story/jeju", "params": { "kind": "bulteok", "seed": 7101 }, "at": "bulteok", "ry": 0.3 },
		{ "id": "p_tewak", "space": JJ, "kit": "story/jeju", "params": { "kind": "tewak", "n": 3, "seed": 7102 }, "at": "tewak", "ry": -0.2 },
		{ "id": "p_heobeok", "space": JJ, "kit": "story/jeju", "params": { "kind": "heobeok", "seed": 7103 }, "at": "heobeok", "ry": 0.0 },
		# 굴 앞: 넓게 끈 가짜 '뱀 자국'(사람 — 매듭이 가만하다)과 그것을 끈 짚 섬
		{ "id": "p_fake_drag", "space": JJ, "trail": { "kind": "drag", "points": [[3425.8, -879.6], [3427.2, -883.0], [3428.4, -886.4], [3429.6, -890.2], [3430.6, -893.6]],
			"step": 1.1, "size": 1.4, "trace": "human" }, "when": "f('s7003')" },
		{ "id": "p_sack", "space": JJ, "kit": "story/jeju", "params": { "kind": "sack", "seed": 7104 }, "at": "sack", "ry": 2.6, "when": "f('case_started')" },
		# 굴 안: 도굴 자리의 놋그릇(가져가면 사라짐) · 메운 구덩이
		{ "id": "p_bowl", "space": JJ, "kit": "story/jeju", "params": { "kind": "bowl" }, "at": "bowl_prop", "ry": 0.4, "when": "f('case_started') and not f('bowl_got')" },
		{ "id": "p_pit", "space": JJ, "kit": "story/jeju", "params": { "kind": "pit", "seed": 7105 }, "at": "pit", "ry": 0.0, "when": "f('pit_filled')" },
		# B — 굴 입구를 돌로 막음
		{ "id": "p_stones", "space": JJ, "kit": "story/jeju", "params": { "kind": "stones", "w": 5.6, "seed": 7106 }, "at": "stones", "ry": 0.0, "when": "f('sealed')" },
	]

# 싸움터: 굴 안쪽 — 구렁이(짐승 상대 ccreature.gd). 물러나면 바위틈(crevice)에 숨었다가 다시 문다
static func arenas() -> Dictionary:
	return {
		"snake": { "at": "arena_c", "radius": 6.5, "camera": { "pitch": 56.0, "distance": 15.0, "fov": 30.0 },
			"foe_name": "구렁이", "intro": "구렁이가 사린 몸을 풀며 고개를 든다!",
			"humans": [
				{ "id": "snake", "creature": "snake", "kind": "jj_snake", "name": "구렁이", "hp": 120.0, "retreat_at": 0.35, "lurk": 3.0,
					"at": "snake_spot", "crevice": "crevice" },
			] },
	}

# ---------------------------------------------------------------------------
# 사건 장면(§44 필드 + steps) — 소스 F48(김녕 큰 구렁이 전승, 지역 고정 A 김녕). 원작 제목은 내보이지 않는다(§1.3).
# 각색: 옛 판관 퇴치담은 마을의 말·비석으로만 남기고, 지금의 일(아이 실종·도굴·실제 뱀·벽 너머의 큰 것)을 그것과 가른다(F48 '판관 퇴치담과 현재 현상 구분').
# ---------------------------------------------------------------------------
static func _ev(id: String, trigger: String, loc: String, tw: String, actions: String, branches: String, wsc: String, steps: Array, mode := "VARIANT") -> Dictionary:
	return {
		"EVENT_ID": id, "RECORD_TITLE": "굴에 남은 숨", "SOURCE_ID": "F48",
		"SOURCE_TITLE_INTERNAL": "김녕굴 큰 구렁이(김녕사굴 전설)", "SOURCE_TYPE": "legend", "SOURCE_REGION_GRADE": "A",
		"SOURCE_REGION_NOTE": "김녕 고정 전승(F48, §39 제주 — 김녕). 옛 판관 퇴치담은 비석·노인의 말로만 남기고 사건의 답으로 쓰지 않는다. 심방·감응 매듭은 제주 안에서만 건넨다(§36.3).",
		"ADAPTATION_MODE": mode, "TRIGGER": trigger, "LOCATION_TYPE": loc, "TIME_WEATHER": tw,
		"PLAYER_ACTIONS": actions, "RESOLUTION_BRANCHES": branches, "WORLD_STATE_CHANGE": wsc, "SOURCE_VERIFIED": true,
		"steps": steps,
	}

static func events() -> Dictionary:
	return {
		"S7001": _ev("S7001", "화북포 물가의 늙은 짐꾼에게 말을 건다", "화북포 물가", "낮 · 바닷바람",
			"서강 창고 일을 묻는다(설득 선택지 없음)", "-", "곽칠성 확인", [{ "call": "s7001" }]),
		"S7002": _ev("S7002", "S7001 뒤 김녕에서 사람이 달려온다", "화북포 → 김녕 굴 앞", "낮",
			"수색에 합류한다", "-", "사건 기록 생성 · 곽칠성 수색 참여", [{ "call": "s7002" }]),
		"S7003": _ev("S7003", "김녕 굴 입구에 다가간다", "김녕 굴 입구", "오후",
			"부서진 금줄·사라진 제물·큰 뱀 흔적·사람 신발 흔적을 살핀다", "-", "데칼 s7003_tracks", [{ "call": "s7003" }]),
		"S7004": _ev("S7004", "입구 흔적을 둘 넘게 본 뒤", "김녕 굴 앞", "오후",
			"심방에게 감응 매듭을 받는다 · 곽칠성의 초롱", "-", "ITEM_SENSING_KNOT · 호신물 칸", [{ "call": "s7004" }]),
		"S7005": _ev("S7005", "등불을 들고 굴 안 옆 굴께까지 든다", "김녕사굴 안", "굴 안 · 어둠 · 등불",
			"실제 큰 뱀 · 도굴 흔적 · 매듭 반응 · 벽 너머 큰 잔영", "-", "-", [{ "call": "s7005" }]),
		"S7006": _ev("S7006", "옆 굴의 아이에게 다가간다", "김녕사굴 옆 굴", "굴 안 · 어둠",
			"아이를 업고 나온다(괴이를 해결하지 않고 구조만 하고 나올 수 있다)", "-", "-", [{ "call": "s7006" }]),
		"S7007": _ev("S7007", "아이를 구한 뒤", "김녕 굴", "-",
			"A 제물·굴 길 복원 / B 굴 봉쇄 / C 구렁이를 벤다", "A 제의 복원 · B 구조 후 봉쇄 · C 물리적 뱀 처치(잔영은 남음)", "CASE_JEJU_OUTCOME", []),
		"S7008": _ev("S7008", "사건 뒤 곽칠성이 먼저 찾아온다", "김녕 굴 앞", "다음 날 아침",
			"나무패를 받는다 · “박규상?”", "-", "MAIN_GWAK_FOUND · ITEM_KEY_001 · 플레이어의 첫 문장", [{ "call": "s7008" }]),
	}
