# 사건 「세 번째 등불」(ACT 2B 경주, S3001~S3008) — 이야기 데이터.
# 시나리오: seolhwa/docs/scenario/seolhwarok_master_scenario_storyboard_v2.3.1_consistency_lock.md §12 (규칙 §1.4·§1.5·§1.7,
#   변수 §7, 소문 §24, 대사 §27, 컷신 §28, 실패 §29, 지역 변화 §30, 소스 잠금 §36, 전승 앵커 §37 A08 망부석·치술령 / A07 배경)
# 체감 장르(§1.7): 관찰·복수 흔적 분리 — 한 현상(밤마다 고개에 뜨는 불 셋)에 원인이 셋(§1.4):
#   ① 사람의 등불(남편을 기다리는 아낙 — 괴이 없음) ② 사람의 꾸밈(감포 쪽 밀수꾼의 신호 — 짧은 싸움)
#   ③ 아무도 들지 않은 불(옛 바위 앞에서 사라짐 — 호신부를 지니면 사람 형체가 잠깐. 공격 없음, 정체는 끝까지 확정하지 않는다)
#   HUD에 번호를 매기지 않는다 — 흔들림·깜빡임·발소리로 플레이어가 가른다.
# 자리(게임 좌표 x,z — GS_GYEONGJU): 경주 장 주막(−3072, −2221) → 치술령 아래 마을(−1120, 2540) → 고개 성황당(−1054, 2759)
#   → 망부석(−947, 2821, region 망부석 바위) · 망부석 위 너럭바위(내려다보는 자리) · 동쪽 등성이(밀수꾼 신호 자리). 마을 ↔ 망부석 약 330m.
# 조건식: story_runner(f·k·c·has·n·ph·v·out·w·fn) + 잔영 체계(tal·zone·night·spv).
extends RefCounted

const CHARM := "ITM_RIT_001"     # 호신부(강릉에서 받았으면)
const TOOL := "ITM_TOOL_007"     # 탁본 도구(보상)
const FRAG := "ITM_KEY_004"      # 이겸의 탁본 조각
const COIN := "COIN"
const RESOLVED := "out('A') or out('B')"
const NIGHT := "ph('night')"

static func data() -> Dictionary:
	return {
		"case": {
			"id": "gyeongju", "record_title": "세 번째 등불", "region": "GS_GYEONGJU", "outcome_var": "CASE_GYEONGJU_OUTCOME",
			"start_hour": 11.0, "start_event": "S3001", "start_on_arrival": true,
			# 한양 S1006(세 방향 열림) 뒤에만 선다 — 강릉·황주와 순서 상관없음
			"requires": { "ACT2_OPEN": true },
			"rule_label": "불빛의 결", "rules_title": "불빛의 결",
			"reset_vars": { "CASE_GYEONGJU_OUTCOME": "", "CASE_GYEONGJU_DETAIL": "" },
		},
		"items": {
			TOOL: "탁본 도구", FRAG: "탁본 조각", CHARM: "호신부", COIN: "엽전",
			"ITM_TOOL_009": "사건 기록책", "ITM_WPN_001": "환도", "ITM_WPN_002": "활", "ITM_AMMO_001": "화살",
		},
		"hidden_items": ["ITM_TOOL_009", "ITM_WPN_001", "ITM_WPN_002", "ITM_AMMO_001", CHARM],
		# 확인/들음/추정(온보딩 UX 보강서 P1-7): kind fact(기본) | heard(by = 발언자 — 반드시) | guess. 증언을 사실로 자동으로 올리지 않는다
		"clues": {
			"rumor_lights": { "title": "고개의 불 셋", "kind": "heard", "by": "경주 장 주모",
				"text": "치술령에 밤마다 불이 셋 뜬다고 한다. 하나를 따라간 숯쟁이가 아직 안 돌아왔다고." },
			"missing_man": { "title": "사흘째 안 돌아온 숯쟁이", "kind": "heard", "by": "치술령 아래 마을 노인",
				"text": "사흘 전 밤, 마을 숯쟁이가 고개 너머 숯가마로 올라갔다. 불을 따라갔다는 말도 있다." },
			"pass_oil": { "title": "성황당 앞 기름 자국", "kind": "fact",
				"text": "고개 성황당 돌무더기 앞에 등잔 기름 몇 방울이 굳었다. 누가 밤마다 등불을 내려놓는 모양이다." },
			"spur_rag": { "title": "등성이의 그을린 천", "kind": "fact",
				"text": "동쪽 등성이 바위틈에 기름 먹인 천 조각. 그을음이 한쪽에만 났다. 바다 쪽이 트인 자리다." },
			"stone_day": { "title": "바다를 보는 바위", "kind": "fact",
				"text": "망부석. 큰 바위가 바다 쪽을 보고 섰다. 앞에 돌무더기. 둘레에 발자국은 없다. 이끼 사이로 닳은 새김이 있는 듯하나 읽히지 않는다." },
			"light_wife": { "title": "흔들리는 등불", "kind": "heard", "by": "치술령 아래 마을 아낙",
				"text": "사람 걸음으로 흔들리며 고갯길을 오르는 불. 아낙이 등을 들고 고개 너머를 본다 — 숯 구우러 간 남편을 기다린다고." },
			"light_signal": { "title": "가렸다 열리는 불", "kind": "fact",
				"text": "동쪽 등성이의 불은 셋 짧게, 하나 길게 가렸다 열린다. 먼 바다 쪽에서 작은 불이 답한다. 가까이 가자 꺼졌다." },
			"smugglers": { "title": "등성이의 사내들", "kind": "fact",
				"text": "불을 들고 있던 것은 사내 둘. 짚으로 싼 꾸러미를 지고 있었다. 감포 쪽 배에 신호를 보내던 것이다." },
			"rescued": { "title": "숯가마의 숯쟁이", "kind": "heard", "by": "숯쟁이",
				"text": "숯가마 뒤에 묶여 있었다. 등성이 불을 보러 갔다가 사내들에게 붙잡혔다고 한다." },
			"light_none": { "title": "흔들리지 않는 불", "kind": "fact",
				"text": "흰 불 하나가 흔들림 없이, 발소리 없이 비탈을 내려와 망부석 앞에서 꺼졌다. 든 사람이 없다." },
			"figure": { "title": "바위 앞의 형체", "kind": "fact",
				"text": "불이 꺼지는 순간, 바위 앞에 흰 옷의 사람 형체가 바다 쪽을 보고 서 있었다. 곧 없었다." },
			"fragment": { "title": "바위 밑의 탁본 조각", "kind": "fact",
				"text": "망부석 아래 틈에 기름종이로 싼 오래된 탁본 조각. 닳은 새김을 먹으로 떠 놓았고, 가장자리에 스승의 필체가 있다." },
			"woochi_here": { "title": "고개의 우치", "kind": "heard", "by": "우치",
				"text": "\"그 양반 아직도 그런 걸 적어놓고 다녔군.\" — 스승을 아느냐 묻자 \"나보다 당신이 더 늦었소.\"" },
			"rope": { "title": "신목에 매어 둔 밧줄", "kind": "fact",
				"text": "고개 성황당 신목 밑동에 밧줄이 매여 서쪽 비탈 아래로 늘어져 있다. 미리 매어 둔 하산길이다. 끝이 잘렸다." },
		},
		# 불빛의 결(규칙) — 번호 없이 보이는 결로만
		"rules": {
			"R_SWAY": { "title": "흔들리는 불은 사람의 걸음이다", "text": "등불은 걷는 사람 손에서 걸음에 맞춰 흔들린다.", "kind": "fact" },
			"R_BLINK": { "title": "가렸다 열리는 불은 신호다", "text": "일정하게 가렸다 열리는 불은 누군가에게 보내는 말이다. 답하는 불이 있다.", "kind": "fact" },
			"R_STILL": { "title": "흔들리지 않는 불은 든 사람이 없다", "text": "발소리도 흔들림도 없이 움직이는 불은 옛 바위 앞에서 꺼진다.", "kind": "guess" },
		},
		# 지도(discovery.gd): 단서·해결 자리는 넣지 않는다
		"map_places": [
			{ "id": "gj_jumak", "name": "경주 장 주막", "at": "jumo_spot", "building": true, "radius": 16.0, "start_known": true },
			{ "id": "chisul_village", "name": "치술령 아래 마을", "at": "village_square", "radius": 40.0, "known": "f('case_started')" },
			{ "id": "chisul_pass", "name": "치술령 성황당", "at": "pass", "radius": 16.0, "known": "c('missing_man')" },
			{ "id": "mangbuseok", "name": "망부석", "at": "stone", "radius": 14.0 },
		],
		"journal": {
			"unknowns": [
				{ "text": "숯쟁이는 어느 불을 따라갔는가.", "when": "c('missing_man')", "until": "f('man_rescued')" },
				{ "text": "밤의 불 셋은 각각 무엇인가.", "when": "f('case_started')", "until": "f('wife_met') and f('smugglers_met') and f('light3_seen')" },
				{ "text": "흔들리지 않는 흰 불은 누가 드는가.", "when": "c('light_none')" },
			],
			"places": [
				{ "name": "경주 장 주막", "when": "true" }, { "name": "치술령 아래 마을", "when": "talked('elder') > 0 or c('missing_man')" },
				{ "name": "치술령 성황당", "when": "c('pass_oil')" }, { "name": "망부석", "when": "c('stone_day') or c('light_none')" },
				{ "name": "동쪽 등성이", "when": "c('spur_rag') or f('smugglers_met')" },
			],
		},
		"anchors": anchors(),
		"actors": actors(),
		"objects": objects(),
		"triggers": triggers(),
		"props": props(),
		"arenas": arenas(),
		"chases": chases(),
		"events": events(),
		"spirits": spirits(),
		"zones": zones(),
	}

static func anchors() -> Dictionary:
	return {
		# 경주 장(서문 밖) 주막
		"town_start": [-3060.5, -2212.0], "jumo_spot": [-3066.0, -2216.5], "guest_spot": [-3062.5, -2219.8],
		# 치술령 아래 마을
		"village_arrive": [-1104.0, 2566.0], "elder_spot": [-1101.5, 2552.0], "wife_day": [-1145.5, 2532.5], "village_square": [-1102.4, 2554.6],
		"bound_a": [-1097.0, 2557.5], "bound_b": [-1099.5, 2559.2], "couple_m": [-1106.5, 2551.2], "couple_f": [-1108.0, 2552.8],
		"village_road": [-1091.0, 2580.0],
		# 고개 성황당·신목
		"pass": [-1049.5, 2763.0], "pass_oil": [-1051.0, 2762.6], "sinmok": [-1055.5, 2758.9], "rope_end": [-1068.0, 2764.5],
		"bundle_spot": [-1054.0, 2761.8],
		# 망부석
		"stone": [-947.4, 2821.1], "stone_front": [-951.8, 2827.6], "stone_gap": [-950.6, 2825.2], "cairn": [-940.9, 2824.0],
		"woochi_spot": [-958.0, 2837.5],
		# 망부석 위 너럭바위(내려다보는 자리)
		"lookout": [-922.0, 2846.0], "lookout_focus": [-925.0, 2836.0],
		# 첫째 불 — 아낙이 기다리는 고갯길 굽이
		"wife_bend": [-975.5, 2800.5], "wife_pass": [-1005.0, 2776.0],
		# 둘째 불 — 동쪽 등성이(바다 쪽이 트임)
		"spur": [-867.5, 2866.0], "spur_rag": [-865.2, 2863.6], "kiln": [-859.0, 2876.0], "kiln_front": [-861.0, 2873.0],
		"flee_east": [-790.0, 2905.0], "sea_answer": [-700.0, 2930.0],
		# 셋째 불 — 남서쪽 비탈에서 망부석 앞으로
		"l3_start": [-986.0, 2878.0],
	}

# 셋째 불이 내려오는 길(끝 = 망부석 앞)
const L3_PATH := [[-986.0, 2878.0], [-979.0, 2866.0], [-971.0, 2856.0], [-962.0, 2845.0], [-955.5, 2834.5], [-952.0, 2828.5]]

# ---------------------------------------------------------------------------
# 인물(CHARACTER_MASTER) — 주모 CHR_HUM_015, 마을 노인 CHR_HUM_022, 아낙 CHR_HUM_010(등롱), 숯쟁이 CHR_HUM_019 변형,
# 밀수꾼 CHR_HUM_027 경비 변형(사람 적 — 전투는 arenas), 우치 CHR_MAIN_003
# ---------------------------------------------------------------------------
static func actors() -> Array:
	return [
		{ "id": "jumo", "chr": "CHR_HUM_015", "kind": "innkeeper", "name": "주모", "at": "jumo_spot", "facing": "down",
			"talk": [
				{ "when": "ph('done')", "steps": [{ "call": "jumo_done" }] },
				{ "when": "not f('case_started')", "steps": [{ "event": "S3001" }] },
				{ "when": "true", "steps": [
					{ "say": "주모", "lines": ["치술령은 해 떨어지면 올라가지 마시오."] },
					{ "choice": "", "options": [
						{ "label": "치술령 아래 마을로 간다", "do": [{ "call": "travel", "args": ["village_arrive", "남산 자락을 돌아 치술령 아래 마을에 닿았다."] }] },
						{ "label": "그만 가 보겠소.", "end": true }] }] },
			] },
		{ "id": "guest", "chr": "CHR_HUM_013", "kind": "traveler", "name": "주막 손님", "at": "guest_spot", "facing": "left",
			"talk": [
				{ "when": RESOLVED, "steps": [{ "call": "guest_done" }] },
				{ "when": "true", "steps": [{ "say": "주막 손님", "lines": ["감포 바다에서 밤마다 불이 셋 떠. 아니, 치술령이랬나."] }] }] },
		# 마을 노인 — 사라진 숯쟁이(증언: 관점만)
		{ "id": "elder", "chr": "CHR_HUM_022", "kind": "elder", "name": "마을 노인", "at": "elder_spot", "facing": "down",
			"talk": [
				{ "when": "ph('done')", "steps": [{ "call": "elder_done" }] },
				{ "when": "not c('missing_man')", "steps": [
					{ "say": "마을 노인", "lines": ["사흘 전 밤, 숯쟁이가 고개로 올라가더니 안 돌아왔소.", "불을 따라갔다는 사람도 있고…"] },
					{ "call": "start_case", "args": ["elder"] }, { "clue": "missing_man" }] },
				{ "when": NIGHT, "steps": [{ "say": "마을 노인", "lines": ["이 밤에 고개로 가시오? 불 셋 가운데 어느 걸 볼 참이오."] }] },
				{ "when": "true", "steps": [{ "call": "elder_talk" }] },
			] },
		# 아낙(숯쟁이의 아내) — 낮에는 우물가, 밤에는 등을 들고 고갯길 굽이에서 기다린다(첫째 불)
		{ "id": "wife", "chr": "CHR_HUM_010", "kind": "lantern_wife", "name": "아낙",
			"at": { "night": "wife_bend", "done": "couple_f", "default": "wife_day" }, "facing": { "night": "right", "done": "right", "default": "down" },
			"anim": { "night": "idle", "done": "idle", "default": "cry" },
			"talk": [
				{ "when": "ph('done')", "steps": [{ "call": "wife_done" }] },
				{ "when": NIGHT + " and not f('wife_met')", "steps": [{ "event": "S3004" }] },
				{ "when": NIGHT, "steps": [{ "call": "wife_night" }] },
				{ "when": "true", "steps": [{ "say": "아낙", "lines": ["…고개 너머 숯가마에 간다고 나갔어요."] }] },
			] },
		# 숯쟁이 — 숯가마 뒤에 묶여 있다(밀수꾼과 부딪친 뒤에 찾는다). 풀어 주면 마을로, 끝나면 아낙 곁
		{ "id": "husband", "chr": "CHR_HUM_019", "kind": "charcoal_man", "name": "숯쟁이",
			"at": { "done": "couple_m", "default": "kiln" }, "facing": { "done": "left", "default": "down" },
			"anim": { "done": "idle", "default": "tied" },
			"when": "f('smugglers_met') or ph('done')",
			"talk": [
				{ "when": "ph('done')", "steps": [{ "say": "숯쟁이", "lines": ["숯가마는 당분간 쉬어야겠소. 고개 불은… 이제 하나만 보면 되겠지."] }] },
				{ "when": "not f('man_rescued')", "steps": [{ "call": "rescue" }] },
				{ "when": "true", "steps": [{ "say": "숯쟁이", "lines": ["집사람 등불을 보고 내려왔소."] }] },
			] },
		# 밀수꾼(낮에는 없다 — 밤의 신호 자리). 싸움은 combat_view 사람 적이 따로 그린다. 잡히면 마을 마당에 묶여 있다
		{ "id": "bound_a", "chr": "CHR_HUM_027", "kind": "smuggler", "name": "밀수꾼", "at": "bound_a", "facing": "down", "anim": "tied",
			"when": "ph('done') and f('caught_a')",
			"talk": [{ "when": "true", "steps": [{ "say": "밀수꾼", "lines": ["…감포 객주 창고까지만 져다 주면 된다고 했소."] }] }] },
		{ "id": "bound_b", "chr": "CHR_HUM_027", "kind": "smuggler_b", "name": "밀수꾼", "at": "bound_b", "facing": "down", "anim": "tied",
			"when": "ph('done') and f('caught_b')",
			"talk": [{ "when": "true", "steps": [{ "say": "밀수꾼", "lines": ["불은 우리 거 하나뿐이오. 나머지는 몰라."] }] }] },
		# 우치 — 망부석 뒤(S3008). 추격은 chases.s3008
		{ "id": "woochi", "chr": "CHR_MAIN_003", "kind": "woochi", "name": "우치", "at": "woochi_spot", "facing": "up",
			"when": "f('woochi_seen') and not f('woochi_done')" },
	]

# ---------------------------------------------------------------------------
# 조사 대상 — 낮(S3002, "별것 없음")·밤
# ---------------------------------------------------------------------------
static func objects() -> Array:
	var day := "f('case_started') and not ph('night') and not ph('done')"
	return [
		{ "id": "pass_oil", "at": "pass_oil", "label": "성황당 돌무더기 · 조사", "radius": 2.6, "when": day + " and not c('pass_oil')",
			"steps": [{ "examine": "성황당 앞", "text": ["돌무더기 앞 납작한 돌에 등잔 기름 몇 방울이 굳었다.", "누가 밤마다 여기 등불을 내려놓는 모양이다."] },
				{ "clue": "pass_oil" }, { "call": "on_day_clue" }] },
		{ "id": "spur_rag", "at": "spur_rag", "label": "등성이 바위틈 · 조사", "radius": 2.6, "when": day + " and not c('spur_rag')",
			"steps": [{ "examine": "동쪽 등성이", "text": ["바위틈에 기름 먹인 천 조각이 끼어 있다. 그을음이 한쪽에만 났다.", "바다 쪽이 트인 자리다. 짚신 자국 여럿 — 마른 땅이라 오래됐는지 모르겠다."] },
				{ "clue": "spur_rag" }, { "call": "on_day_clue" }] },
		{ "id": "stone_day", "at": "stone_front", "label": "망부석 · 조사", "radius": 3.0, "when": day + " and not c('stone_day')",
			"steps": [{ "call": "examine_stone_day" }, { "clue": "stone_day" }, { "call": "on_day_clue" }] },
		{ "id": "kiln_day", "at": "kiln_front", "label": "가지 더미 · 조사", "radius": 2.4, "when": day + " and not f('kiln_day')",
			"steps": [{ "examine": "마른 가지 더미", "text": "등성이 아래 마른 가지를 쌓아 두었다. 땔감인가. 별것 없다." }, { "flag": "kiln_day" }, { "call": "on_day_clue" }] },
		# 높은 데서 밤을 기다린다(S3002 → S3003)
		{ "id": "lookout", "at": "lookout", "label": "너럭바위 · 밤을 기다린다", "radius": 3.2, "when": day,
			"steps": [{ "call": "wait_night" }] },
		{ "id": "go_village", "at": "village_road", "label": "경주 읍내로 돌아간다", "radius": 3.0, "when": day,
			"steps": [{ "call": "travel", "args": ["town_start", "고개를 내려와 경주 장으로 돌아왔다."] }] },
		# 밤: 바위 밑 틈(셋째 불이 꺼진 뒤 — S3007)
		{ "id": "stone_gap", "at": "stone_gap", "label": "바위 밑 틈 · 살펴보기", "radius": 2.8, "when": NIGHT + " and f('light3_seen') and not f('fragment')",
			"steps": [{ "event": "S3007" }] },
		# 우치가 남긴 것(추격 뒤 — 신목 밑동)
		{ "id": "bundle", "at": "bundle_spot", "label": "신목 밑동 · 살펴보기", "radius": 3.0, "when": "f('woochi_done') and not has('%s')" % TOOL,
			"steps": [{ "call": "take_bundle" }] },
		# 너럭바위: 밤에도 다시 내려다볼 수 있다(카메라가 넓어진다 — 사건 ambient)
	]

static func triggers() -> Array:
	return [
		# S3001 경주 장 주막 — 지나가며 엿듣는다
		{ "id": "s3001_overhear", "at": "jumo_spot", "radius": 20.0, "when": "not f('case_started')", "ambient": [
			["주막 손님", "치술령에 밤마다 불이 셋 뜬다며?"], ["주모", "숯쟁이 하나가 따라갔다 안 돌아왔대요."]] },
		# 마을에 먼저 닿았을 때(노정·먼 길로)
		{ "id": "s3001_village", "at": "elder_spot", "radius": 16.0, "when": "not f('case_started')", "ambient": [
			["아낙", "…사흘째예요."], ["마을 노인", "고개 불 셋 가운데 하나를 따라갔다지."]] },
		# 밤: 불 가까이(가르기) — 흔들리는 불(아낙)은 움직이므로 사건 ambient가 거리로 본다
		{ "id": "near_spur", "at": "spur", "radius": 19.0, "when": NIGHT + " and not f('smugglers_met')", "steps": [{ "event": "S3005" }] },
	]

# ---------------------------------------------------------------------------
# 소품(키트·데칼)
# ---------------------------------------------------------------------------
static func props() -> Array:
	return [
		# 성황당 앞 기름 자국(작은 등잔 받침 — 조사 대상)
		{ "id": "p_oil", "kit": "story/clue", "params": { "kind": "oil", "r": 0.18 }, "at": "pass_oil" },
		# 등성이: 그을린 천·짚신 자국
		{ "id": "d_spur_prints", "trail": { "kind": "foot", "points": [[-875.0, 2872.0], [-869.5, 2867.5], [-865.0, 2864.5], [-860.0, 2868.0], [-858.5, 2874.0]], "step": 0.8, "size": 0.5 },
			"when": "not ph('done')" },
		# 숯가마(가지 더미 + 막돌) — 그 뒤에 숯쟁이가 묶여 있다
		{ "id": "p_kiln_wood", "kit": "village/firewood", "params": { "seed": 31 }, "at": [-857.0, 2878.5], "ry": 0.4 },
		{ "id": "p_kiln_stone", "kit": "nature/rock", "params": { "seed": 32, "s": 1.6 }, "at": [-855.0, 2880.5] },
		# 밀수꾼의 짐(싸움 뒤 남은 것)
		{ "id": "p_bundles", "kit": "story/ritual", "params": { "kind": "stash" }, "at": [-870.5, 2869.5], "ry": 0.6, "when": "f('smugglers_met') and not ph('done')" },
		# 신목에 매어 둔 밧줄(우치의 하산길) — 추격 뒤 보인다
		{ "id": "p_rope", "kit": "story/ritual", "params": { "kind": "geumjul", "state": "BROKEN", "w": 6.0 }, "at": [-1061.0, 2761.5], "ry": 2.8, "when": "f('woochi_done')" },
		# 지역 변화(§30): 망부석 앞 공양(모든 결말) — 마을 사람들이 바위 앞에 상을 차린다
		{ "id": "p_offering", "kit": "story/ritual", "params": { "kind": "jemul", "state": "NORMAL" }, "at": [-952.6, 2829.5], "ry": 0.5, "when": "ph('done')" },
		# A: 마을 어귀 횃대(밤길 사람이 는다)
		{ "id": "p_torch_a", "kit": "village/torch_post", "params": { "seed": 7 }, "at": [-1094.5, 2581.0], "when": "ph('done') and out('A')" },
	]

# ---------------------------------------------------------------------------
# 싸움터 — 사람 적(scripts/combat/chuman.gd). 둘째 불(신호)을 들고 있던 밀수꾼 둘
# ---------------------------------------------------------------------------
static func arenas() -> Dictionary:
	return {
		"spur": { "at": "spur", "radius": 10.0, "camera": { "pitch": 46.0, "distance": 20.0, "fov": 30.0 },
			"foe_name": "밀수꾼", "intro": "사내 둘이 짐을 내려놓고 몽둥이와 장대를 든다!", "flee_to": "flee_east",
			"humans": [
				{ "id": "sm_a", "kind": "smuggler", "name": "밀수꾼", "weapon": "club", "hp": 60.0, "flee_at": 0.2, "offset": [3.0, 2.0] },
				{ "id": "sm_b", "kind": "smuggler_b", "name": "장대 든 밀수꾼", "weapon": "pole", "hp": 50.0, "flee_at": 0.35, "offset": [-2.5, 3.5] },
			] },
	}

# ---------------------------------------------------------------------------
# 추격 S3008 — 우치가 준비해 둔 하산길(scripts/story/chase.gd). 망부석 → 고갯길 → 성황당 신목의 밧줄로 서쪽 비탈 아래
#   우치는 비탈을 곧장 가로지르고(밧줄을 잡고 미끄러짐), 플레이어는 고갯길(region chisul_trail)을 따라 돈다.
# ---------------------------------------------------------------------------
static func chases() -> Dictionary:
	return {
		"s3008": {
			"actor": "woochi", "speed": 4.2, "burst": 6.0, "lead": 12.0, "min_lead": 5.5, "wait_lead": 25.0, "wait_max": 3.5,
			"lose_lead": 42.0, "lose_off": 28.0, "lose_time": 6.0, "wake_lead": 9.0, "wake_time": 2.5, "retry_back": 8.0,
			"camera": { "distance": 40.0, "pitch": 47.0 }, "frame_reach": 16.0, "frame_mix": 0.5, "end_anim": "crouch", "vanish_delay": 1.2,
			"end_caption": "우치가 신목에 매인 밧줄을 잡고 서쪽 비탈 아래로 사라진다.",
			"segments": [
				{ "mode": "lane", "checkpoint": true, "run": ["woochi_spot", [-961.5, 2830.0], [-962.0, 2823.5]],
					"follow": ["stone_front", [-950.9, 2830.1], [-962.0, 2823.5]] },
				# 지름길: 나무에 매어 둔 밧줄을 잡고 비탈을 곧장 — 플레이어는 굽은 고갯길로
				{ "mode": "bank", "shortcut": true, "run": [[-972.0, 2810.0], [-988.0, 2790.0]], "speed": 1.1, "anim": "run",
					"follow": [[-962.0, 2823.5], [-967.0, 2821.8], [-973.5, 2799.8], [-990.0, 2786.0]],
					"caption": "우치가 나무에 매어 둔 밧줄을 잡고 비탈을 미끄러져 내려간다!" },
				{ "mode": "lane", "checkpoint": true, "run": [[-999.3, 2777.7], [-1007.8, 2774.8], [-1025.1, 2764.8], [-1040.0, 2764.0]],
					"follow": [[-990.0, 2786.0], [-999.3, 2777.7], [-1007.8, 2774.8], [-1025.1, 2764.8], [-1040.0, 2764.0]] },
				{ "mode": "lane", "run": ["sinmok", "rope_end"], "speed": 0.8,
					"follow": [[-1040.0, 2764.0], "pass"] },
			],
		},
	}

# ---------------------------------------------------------------------------
# 잔영(SPIRIT_BASE 여인 형체, CHR_CRE_004 계열) — 셋째 불이 꺼지는 순간, 호신부를 지녔으면 잠깐(사건 GDScript가 띄운다)
# ---------------------------------------------------------------------------
static func spirits() -> Array:
	return [
		{ "id": "jy_figure", "kind": "spirit_f", "name": "형체", "at": "stone_front", "facing": "right",
			"when": "false", "night": true, "sense": true, "alpha_in": 0.62, "motion": "float", "range": 60.0, "lift": 0.1 },
	]

static func zones() -> Dictionary:
	return {
		"lookout": { "at": "lookout", "radius": 6.5 },
	}

# ---------------------------------------------------------------------------
# 사건 장면(§44 필드 + steps) — 소스 A08(지역 고정 전승: 망부석·치술령). SOURCE_VERIFIED=false면 실행하지 않는다.
# ---------------------------------------------------------------------------
static func _ev(id: String, trigger: String, loc: String, tw: String, actions: String, branches: String, wsc: String, steps: Array) -> Dictionary:
	return {
		"EVENT_ID": id, "RECORD_TITLE": "세 번째 등불", "SOURCE_ID": "A08",
		"SOURCE_TITLE_INTERNAL": "망부석·치술령 전승", "SOURCE_TYPE": "legend", "SOURCE_REGION_GRADE": "A",
		"SOURCE_REGION_NOTE": "치술령 망부석(기다림·화석 모티프) 지역 전승을 배경으로만 쓴다. F09와 섞지 않는다(§37). 기다리는 아낙·바다를 보는 바위·바위 앞에서 꺼지는 불은 전승의 '기다림'을 현재 사건으로 비추는 장치이며, 원작 줄거리를 설명하지 않는다(§1.3). 셋째 불의 정체는 확정하지 않는다(§1.4). A07(왕경 신화)은 탁본 대상 비각의 배경으로만.",
		"ADAPTATION_MODE": "ECHO", "TRIGGER": trigger, "LOCATION_TYPE": loc, "TIME_WEATHER": tw,
		"PLAYER_ACTIONS": actions, "RESOLUTION_BRANCHES": branches, "WORLD_STATE_CHANGE": wsc, "SOURCE_VERIFIED": true,
		"steps": steps,
	}

static func events() -> Dictionary:
	return {
		"S3001": _ev("S3001", "한양 S1006 이후 경주 도착(경주 장 주막 또는 치술령 아래 마을)", "경주 장(서문 밖) 주막", "낮 · 맑음",
			"주변대화를 엿듣고 주모에게 묻는다", "-", "사건 기록 생성", [
			{ "if": "not f('arrived')", "then": [{ "call": "arrival" }] },
			{ "say": "나그네", "lines": ["치술령 불 말이오?"] },
			{ "say": "주모", "lines": ["밤마다 셋이 뜬대요. 하나 따라간 숯쟁이가 안 돌아왔고요."] },
			{ "call": "start_case", "args": ["jumo"] },
			{ "choice": "", "options": [
				{ "label": "치술령 아래 마을로 간다", "do": [{ "call": "travel", "args": ["village_arrive", "남산 자락을 돌아 치술령 아래 마을에 닿았다."] }] },
				{ "label": "장을 더 둘러본다", "end": true }] },
		]),
		"S3002": _ev("S3002", "사건 기록 생성 뒤", "치술령(성황당·망부석·동쪽 등성이)", "낮", "고갯길을 둘러본다 — 별것 없다. 높은 데서 밤을 기다릴 수 있다", "-", "-", []),
		"S3003": _ev("S3003", "너럭바위에서 밤을 기다린 뒤", "망부석 위 너럭바위", "밤 · 맑음", "불 셋을 내려다본다(번호 없이)", "-", "-", []),
		"S3004": _ev("S3004", "흔들리는 불에 다가감", "고갯길 굽이", "밤", "등을 든 아낙과 이야기한다", "-", "-", [
			{ "say": "아낙", "lines": ["…누구요?", "숯 구우러 간 우리 집 양반이 사흘째 안 와요.", "불 켜 두면 보고 찾아올까 싶어서."] },
			{ "call": "wife_met" },
		]),
		"S3005": _ev("S3005", "가렸다 열리는 불에 다가감", "동쪽 등성이", "밤", "불이 꺼지고 사내 둘이 막아선다 — 짧은 싸움(또는 물러남)",
			"쓰러뜨려 붙잡는다 / 달아난다", "밀수꾼 체포 또는 도주", [
			{ "call": "spur_encounter" },
		]),
		"S3006": _ev("S3006", "흔들리지 않는 불을 따라 망부석 앞", "망부석", "밤", "불이 바위 앞에서 꺼지는 것을 본다(호신부 — 형체가 잠깐)", "-", "-", []),
		"S3007": _ev("S3007", "셋째 불이 꺼진 바위 밑", "망부석", "밤", "바위 밑 틈에서 오래된 탁본 조각을 찾는다", "-", "MAIN_MASTER_TRACE += GYEONGJU", [
			{ "call": "find_fragment" },
		]),
		"S3008": _ev("S3008", "탁본 조각을 읽은 직후", "망부석 → 고개 성황당", "밤", "우치와 마주친다 — 짧은 추격(준비된 하산길)", "따라잡지 못한다(우치는 사라짐)",
			"신목에 밧줄 · 탁본 도구", [
			{ "call": "woochi_scene" },
		]),
	}
