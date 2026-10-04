# 사건 「산길의 실종」(ACT 0 남원, S0001~S0010) — 이야기 데이터.
# 시나리오: seolhwa/docs/scenario/seolhwarok_master_scenario_storyboard_v2.1_folklore_only_subevents.md §8 (규칙 §1, 대사 §27, 컷신 §28, 실패 §29, 지역 변화 §30)
# 웹 프로토타입(seolhwa/src/story/case_sanggil.js·dialogue.js)의 흐름·규칙(범의 버릇 K_*)·세 결말을 옮기고, 대사는 시나리오에 맞춰 줄였다.
# ID: CHARACTER/ITEM/PROP_MASTER v1.0. 원작 제목은 화면에 쓰지 않는다(내부 SOURCE_TITLE_INTERNAL만).
#
# 자리(게임 좌표 x,z — JL_NAMWON_UNBONG): 남원 동문 밖 주막 → 읍성 → 북문 → 북쪽 어귀(장승·쉼터, 포수) → 고개(서낭당) →
#   고개 너머 숲가 외딴집(오누이)·물레방앗간·서쪽 숲 빈터(범의 영역). 건물은 region_data/JL_NAMWON_UNBONG/placement_story_namwon.json.
# 조건식은 story_runner.gd의 짧은 함수(f 플래그, k 버릇, c 단서, has/n 소지품, ph 국면, v 변수, out 결말, w 지역 상태, fn 사건 함수)를 쓴다.
extends RefCounted

const TTEOK := "ITM_LIFE_001"
const OIL := "ITM_LIFE_002"
const TORCH := "ITM_TOOL_002"
const COIN := "COIN"

static func data() -> Dictionary:
	return {
		"case": {
			"id": "namwon", "record_title": "산길의 실종", "region": "JL_NAMWON_UNBONG", "outcome_var": "CASE_NAMWON_OUTCOME",
			"start_hour": 9.5,
		},
		"items": {
			TTEOK: "떡", OIL: "참기름", TORCH: "횃불", COIN: "엽전",
			"ITM_TOOL_009": "사건 기록책", "ITM_WPN_001": "환도", "ITM_WPN_002": "활", "ITM_AMMO_001": "화살",
		},
		"hidden_items": ["ITM_TOOL_009", "ITM_WPN_001", "ITM_WPN_002", "ITM_AMMO_001"],
		"clues": {
			"rumor": { "title": "떡장수 어미의 실종", "text": "고개 너머 사는 떡장수가 장에 갔다가 사흘째 돌아오지 않는다." },
			"kids_story": { "title": "오누이의 말", "text": "어머니는 장에 갔다. 해 지기 전엔 온다고 했다." },
			"cold_hearth": { "title": "식은 아궁이", "text": "재가 차갑다. 사흘은 불을 때지 않았다." },
			"mother_route": { "title": "떡가루 묻은 함지", "text": "새벽에 떡을 쪄 광주리에 담았다. 고개 너머 장으로 가는 길이다." },
			"voice_at_night": { "title": "문밖의 목소리", "text": "어젯밤 문밖에서 어머니 목소리가 불렀다. 아이들은 문을 열지 않았다." },
			"cakes": { "title": "고갯길의 떡", "text": "굽이마다 떡이 하나씩 떨어져 있다. 둘레 흙을 큰 코가 파헤쳤다." },
			"torn_skirt": { "title": "찢어진 치맛자락", "text": "덤불에 걸린 쪽빛 치맛자락. 네 줄로 길게 찢겼다." },
			"blood": { "title": "마른 핏자국", "text": "길가 돌에 검붉은 자국. 사흘은 지난 빛이다." },
			"tracks": { "title": "끊긴 짚신 자국", "text": "짚신 자국 곁에 큰 짐승 발자국. 짚신 자국만 고갯마루에서 끊긴다." },
			"basket": { "title": "서낭당 앞 빈 광주리", "text": "엎어진 광주리. 떡은 한 조각도 없다. 머리에 받치던 수건이 곁에 떨어져 있었다." },
			"flour_sack": { "title": "찢긴 밀가루 자루", "text": "방앗간 자루가 발톱에 갈라졌다. 가루는 먹지 않고 흩뜨리기만 했다." },
			"flour_prints": { "title": "밀가루 속 큰 발자국", "text": "흰 가루를 밟은 발자국이 숲가 외딴집 쪽으로 간다. 앞발 자국만 유난히 하얗다." },
			"hunter_word": { "title": "포수의 말", "text": "사람 가까이까지 내려오는 놈은 버릇이 든 것이다." },
			"claw_marks": { "title": "큰 나무의 긁힌 껍질", "text": "사람 키를 넘는 곳까지 깊이 긁혔다. 매끈한 옹이 자리에선 미끄러진 자국뿐이다." },
			"territory": { "title": "숲속 빈터", "text": "뼈가 구르고 나무마다 발톱 자국. 어귀엔 타다 만 횃불 — 누군가 불로 몰아낸 적이 있다." },
			"first_sight": { "title": "고갯마루 아래 숲의 그것", "text": "몸을 낮추고, 멈추고, 덮쳤다. 집채만 한 범이다." },
		},
		"rules": {
			"K_FOOD": { "title": "먹이에 집착한다", "text": "떡 냄새를 따라 내려왔다. 먹을 것이 보이면 그쪽으로 간다." },
			"K_MIMIC": { "title": "사람 목소리를 흉내 낸다", "text": "아는 사람 목소리로 부른다. 목소리만으로는 믿을 수 없다." },
			"K_FLOUR": { "title": "앞발을 희게 칠한다", "text": "밀가루를 묻혀 사람 손인 척한다. 손을 보면 안다." },
			"K_CLIMB": { "title": "나무를 탄다", "text": "높이 오른다. 다만 미끄러운 줄기는 오르지 못한다." },
			"K_TERRITORY": { "title": "숲속 빈터가 제 영역", "text": "영역 밖까지는 쫓지 않는다. 불을 들이대면 제 자리로 물러난다." },
		},
		"anchors": anchors(),
		"arenas": {
			# 첫 조우(S0005): 고갯마루 아래 숲. 보스전 아님 — 피해를 주거나 물러나면 범도 물러난다
			"pass_wood": { "name": "고갯마루 아래 숲", "at": "player", "radius": 11.0, "tiger_offset": [-6.5, -7.0],
				"retreat_to": "territory", "camera": { "pitch": 46.0, "distance": 21.0, "fov": 30.0 } },
			# 마당(S0008 A·B): 큰 나무 포함, 지름 약 15m
			"house_yard": { "name": "외딴집 마당", "at": [-3212.5, -346.0], "radius": 7.5, "tiger_start": [-3219.0, -341.0], "player_start": [-3208.0, -349.5],
				"focus": "big_tree", "retreat_to": "territory", "camera": { "pitch": 46.0, "distance": 19.0, "fov": 30.0 } },
			# 범의 영역(숲속 빈터) — C에서 칼을 뽑으면 여기서
			"territory": { "name": "숲속 빈터", "at": "territory", "radius": 11.0, "tiger_start": [-3283.0, -400.0], "player_start": [-3264.0, -390.0],
				"camera": { "pitch": 48.0, "distance": 23.0, "fov": 30.0 } },
		},
		"actors": actors(),
		"objects": objects(),
		"triggers": triggers(),
		"props": props(),
		"events": events(),
	}

static func anchors() -> Dictionary:
	return {
		# 남원
		"start": [-2952.0, 184.0], "yocheon_view": [-2960.0, 262.0], "jiri_view": [-2860.0, -420.0], "east_gate": [-3135.3, 248.8],
		"tavern": [-3005.0, 231.0], "jumo": [-3001.0, 227.6], "guest": [-3010.6, 228.4],
		"oil_shop": [-3220.1, 53.8], "oil_jars": [-3217.6, 53.4], "elder_town": [-3209.5, 38.0],
		"north_square": [-3196.0, -132.0], "hunter": [-3192.5, -133.5], "feast": [-3190.0, -146.0],
		"feast_a": [-3188.0, -143.5], "feast_b": [-3192.6, -143.2], "kids_after_a": [-3201.5, -126.5], "kids_after_b": [-3200.4, -126.0], "neighbor_after": [-3203.0, -127.5],
		# 고갯길 단서(S0004)
		"cake_1": [-3186.4, -138.4], "cake_2": [-3174.9, -162.4], "cake_3": [-3164.6, -184.3], "torn_skirt": [-3161.6, -199.4],
		"blood": [-3153.6, -215.3], "tracks": [-3158.8, -229.6], "tracks_end": [-3172.4, -249.6],
		"shrine": [-3147.5, -212.0], "basket": [-3148.6, -207.8], "offering": [-3148.2, -208.6], "first_seen": [-3157.0, -222.0],
		"merchant_a": [-3160.4, -190.0], "merchant_b": [-3166.5, -239.5],
		# 고개 너머
		"mill": [-3176.0, -318.0], "miller": [-3179.6, -313.4], "flour": [-3178.6, -314.6],
		"house": [-3214.0, -357.0], "house_door": [-3214.0, -353.4], "hearth": [-3212.2, -356.4], "kneading": [-3216.0, -356.6],
		"kid_in_a": [-3215.6, -356.4], "kid_in_b": [-3213.6, -356.2], "yard": [-3212.5, -346.0],
		"big_tree": [-3205.5, -342.0], "claw": [-3205.5, -342.0], "perch_a": [-3205.0, -342.9], "perch_b": [-3206.2, -341.8],
		"barn": [-3223.5, -356.0], "barn_front": [-3223.5, -353.6],
		"yard_torch": [-3221.0, -339.6], "cake_bait": [-3222.0, -341.6], "hide_spot": [-3203.4, -351.0], "tiger_from": [-3233.0, -349.0],
		"kids_morning_a": [-3211.4, -348.6], "kids_morning_b": [-3210.0, -348.2], "neighbor_morning": [-3208.4, -347.0],
		"elder_morning": [-3215.6, -344.6], "morning_player": [-3212.0, -342.6],
		"night_start": [-3196.0, -130.0], "wake_spot": [-3195.0, -129.0],
		"territory": [-3275.0, -395.0], "territory_edge": [-3261.5, -386.5], "lure_end": [-3266.0, -390.0], "lure_player": [-3255.0, -383.0],
		"jeogori_c": [-3270.0, -392.0], "jeogori_yard": [-3215.0, -344.0],
	}

# ---------------------------------------------------------------------------
# 인물(CHARACTER_MASTER) — at: 자리(국면별 사전 가능), when: 보일 조건, talk: 위에서부터 조건이 맞는 첫 묶음
# ---------------------------------------------------------------------------
static func actors() -> Array:
	return [
		{ "id": "jumo", "chr": "CHR_HUM_015", "kind": "innkeeper", "name": "주모", "at": "jumo", "facing": "down",
			"talk": [
				{ "when": "out('A') or out('B')", "steps": [{ "say": "주모", "lines": ["고갯길에 장꾼들이 다시 넘어오오. 주막도 살 맛이 나구려."] }] },
				{ "when": "out('C')", "steps": [{ "say": "주모", "lines": ["서낭당에 떡 한 접시 올리고 왔소.", "…밤이면 멀리서 우는 소리가 들려."] }] },
				{ "when": "ph('night')", "steps": [
					{ "say": "주모", "lines": ["그 집 애들 생각에 나도 잠이 안 오오."] },
					{ "if": "k('K_TERRITORY') and not has('%s') and not w('torch_lit')" % TORCH, "then": [
						{ "choice": "", "options": [
							{ "label": "횃불 하나 빌릴 수 있겠소?", "do": [{ "say": "주모", "lines": ["관솔 넉넉히 감았소."] }, { "give": TORCH }] },
							{ "label": "그만 가 보겠소.", "end": true }] }] }] },
				{ "when": "not f('case_started')", "steps": [{ "event": "S0002" }] },
				{ "when": "true", "steps": [
					{ "say": "주모", "lines": ["산에서 뭘 보셨소? 얼굴이 하얗구려."], "when": "f('first_encounter')" },
					{ "say": "주모", "lines": ["그 집 애들은 좀 보고 오셨소?"], "when": "not f('first_encounter')" },
					{ "choice": "", "loop": true, "options": [
						{ "label": "떡을 좀 얻을 수 있겠소?", "when": "k('K_FOOD') and not f('jumo_tteok')", "do": [
							{ "say": "주모", "lines": ["어제 찐 거요. 냄새는 고소하지."] }, { "give": TTEOK, "n": 2 }, { "flag": "jumo_tteok" }] },
						{ "label": "횃불 하나 빌릴 수 있겠소?", "when": "k('K_TERRITORY') and not has('%s') and not w('torch_lit')" % TORCH, "do": [
							{ "say": "주모", "lines": ["관솔 넉넉히 감았소. 불은 짐승이 꺼리지."] }, { "give": TORCH }] },
						{ "label": "하룻밤 묵어 가겠소.", "disabled_when": "not fn('can_rest')", "hint": "아직 알아볼 것이 남은 것 같다.", "end": true,
							"do": [{ "call": "rest" }] },
						{ "label": "그만 가 보겠소.", "end": true }] }] },
			] },
		{ "id": "guest", "chr": "CHR_HUM_013", "kind": "traveler", "name": "손님", "at": "guest", "facing": "right",
			"talk": [
				{ "when": "v('CASE_NAMWON_OUTCOME') != ''", "steps": [{ "say": "손님", "lines": ["고개가 열렸다니 오늘은 넘어가 볼까."] }] },
				{ "when": "true", "steps": [{ "say": "손님", "lines": ["사흘이면… 돌아올 사람이면 벌써 왔지."] }] },
			] },
		{ "id": "hunter", "chr": "CHR_HUM_017", "kind": "hunter", "name": "포수", "at": "hunter", "facing": "down",
			"talk": [
				{ "when": "out('A') or out('B')", "steps": [{ "say": "포수", "lines": ["그놈 가죽은 내가 손질해 두리다."] }] },
				{ "when": "out('C')", "steps": [{ "say": "포수", "lines": ["살려 보냈다고? …그래도 이제 그 빈터 쪽으론 아무도 안 가오."] }] },
				{ "when": "ph('night')", "steps": [
					{ "say": "포수", "lines": ["오늘 밤이오? 나도 멀리서 지켜보리다."] }, { "flag": "hunter_watch" },
					{ "if": "k('K_TERRITORY') and not has('%s') and not w('torch_lit')" % TORCH, "then": [
						{ "say": "포수", "lines": ["이거 가져가시오. 관솔 횃불이오."] }, { "give": TORCH }] }] },
				{ "when": "f('woke_by_hunter') and not f('hunter_after_wake')", "steps": [
					{ "flag": "hunter_after_wake" }, { "say": "포수", "lines": ["고갯길에 쓰러져 있길래 업어 왔소. 그놈을 봤구려."] }] },
				{ "when": "not c('hunter_word')", "steps": [
					{ "say": "포수", "lines": ["사람 가까이까지 내려오는 놈은 버릇이 든 거요."] }, { "clue": "hunter_word" }] },
				{ "when": "true", "steps": [
					{ "choice": "", "loop": true, "options": [
						{ "label": "그놈은 어디 사오?", "when": "not f('hm_where')", "do": [{ "flag": "hm_where" },
							{ "say": "포수", "lines": ["고개 너머 서쪽 숲 어딘가. 거기까진 나도 안 들어가오."] }] },
						{ "label": "횃불을 얻을 수 있겠소?", "when": "k('K_TERRITORY') and not has('%s') and not w('torch_lit')" % TORCH, "do": [
							{ "say": "포수", "lines": ["아껴 쓰시오."] }, { "give": TORCH }] },
						{ "label": "그만 가 보겠소.", "end": true }] }] },
			] },
		{ "id": "miller", "chr": "CHR_HUM_009", "kind": "miller", "name": "방앗간 주인", "at": "miller", "facing": "down",
			"talk": [
				{ "when": "v('CASE_NAMWON_OUTCOME') != ''", "steps": [{ "say": "방앗간 주인", "lines": ["자루 찢던 놈이 사라지니 살 것 같소."] }] },
				{ "when": "not c('flour_sack')", "steps": [
					{ "say": "방앗간 주인", "lines": ["자루를 또 찢어 놨소. 먹지도 않고 흩뜨리기만 했어."] }, { "clue": "flour_sack" }] },
				{ "when": "true", "steps": [{ "say": "방앗간 주인", "lines": ["쥐새끼 짓은 아니오."] }] },
			] },
		{ "id": "oil_wife", "chr": "CHR_HUM_010", "kind": "farmwife", "name": "기름집 아낙", "at": "oil_shop", "facing": "down",
			"talk": [
				{ "when": "v('CASE_NAMWON_OUTCOME') != ''", "steps": [{ "say": "기름집 아낙", "lines": ["그 기름이 애들 목숨 값이 됐다면서요."] }] },
				{ "when": "not has('%s') and not w('oil_on_tree')" % OIL, "steps": [
					{ "say": "기름집 아낙", "lines": ["참기름 사러 오셨소? 갓 짠 거요."] },
					{ "choice": "", "options": [
						{ "label": "한 병 주시오. (엽전 다섯 닢)", "disabled_when": "n('%s') < 5" % COIN, "hint": "엽전이 모자란다.", "do": [
							{ "take": COIN, "n": 5 }, { "give": OIL }, { "say": "기름집 아낙", "lines": ["한 방울만 묻어도 손이 미끄러워요."] }] },
						{ "label": "다음에 사겠소.", "end": true }] }] },
				{ "when": "true", "steps": [{ "say": "기름집 아낙", "lines": ["고소하지요? 남원 참기름이 제일이에요."] }] },
			] },
		{ "id": "elder", "chr": "CHR_HUM_022", "kind": "elder", "name": "노인",
			"at": { "morning": "elder_morning", "default": "elder_town" }, "facing": { "morning": "right", "default": "down" },
			"talk": [
				{ "when": "ph('done')", "steps": [{ "say": "노인", "lines": ["한양 가는 길이면 오수 지나 전주로 가게."] }] },
				{ "when": "ph('morning')", "steps": [{ "say": "노인", "lines": ["고을이 자네한테 빚을 졌네."] }] },
				{ "when": "true", "steps": [{ "say": "노인", "lines": ["고개 서낭당에 돌 하나 얹고 가게. 요즘은 그냥 지나가면 탈이 난다네."] }] },
			] },
		{ "id": "nui", "chr": "CHR_MAIN_009", "kind": "story_girl", "name": "누이",
			"at": { "explore": "kid_in_a", "night": "kid_in_a", "morning": "kids_morning_a", "done": "kids_after_a", "default": "kid_in_a" },
			"facing": "down", "when": "not f('kids_hidden')",
			"talk": [
				{ "when": "ph('done')", "steps": [{ "say": "누이", "lines": ["…어머니 저고리는 제가 기워 둘 거예요."] }] },
				{ "when": "ph('night')", "steps": [{ "call": "kids_night" }] },
				{ "when": "not f('met_kids')", "steps": [{ "event": "S0003" }] },
				{ "when": "true", "steps": [
					{ "choice": "", "loop": true, "options": [
						{ "label": "어머니는 언제 떠나셨니?", "when": "not f('nui_when')", "do": [{ "flag": "nui_when" },
							{ "say": "누이", "lines": ["사흘 전 새벽에요. 해 지기 전엔 온다고 했어요."] }] },
						{ "label": "밤에 별일은 없었니?", "when": "not f('nui_night')", "do": [{ "flag": "nui_night" },
							{ "say": "누이", "lines": ["어젯밤에 문밖에서 어머니 목소리가 났어요. 문은 안 열었어요."] },
							{ "clue": "voice_at_night" }, { "rule": "K_MIMIC" }] },
						{ "label": "문 꼭 걸고 있거라.", "end": true }] }] },
			] },
		{ "id": "au", "chr": "CHR_MAIN_010", "kind": "story_boy", "name": "아우",
			"at": { "explore": "kid_in_b", "night": "kid_in_b", "morning": "kids_morning_b", "done": "kids_after_b", "default": "kid_in_b" },
			"facing": "down", "when": "not f('kids_hidden')",
			"talk": [
				{ "when": "ph('done')", "steps": [{ "say": "아우", "lines": ["아저씨, 이웃집 밥 맛있어. 근데… 엄마 밥이 더 맛있어."] }] },
				{ "when": "ph('night')", "steps": [{ "call": "kids_night" }] },
				{ "when": "not f('met_kids')", "steps": [{ "event": "S0003" }] },
				{ "when": "true", "steps": [{ "say": "아우", "lines": ["오늘은 와요?"] }] },
			] },
		{ "id": "neighbor", "chr": "CHR_HUM_010", "kind": "villager_f", "name": "이웃 아낙",
			"at": { "morning": "neighbor_morning", "default": "neighbor_after" }, "facing": "down", "when": "ph('morning') or ph('done')",
			"talk": [{ "when": "true", "steps": [{ "say": "이웃 아낙", "lines": ["애들은 걱정 마세요. 밥상에 숟가락 둘 더 놓으면 되지."] }] }] },
		{ "id": "mother", "chr": "CHR_MAIN_011", "kind": "ricecake_mother", "name": "떡장수 어머니", "at": "kneading", "when": "f('show_mother')" },
		# 지역 변화(§30): 고갯길에 장꾼이 다시 다닌다
		{ "id": "merchant_a", "chr": "CHR_HUM_003", "kind": "peddler", "name": "장꾼", "at": "merchant_a", "facing": "down",
			"when": "v('CASE_NAMWON_OUTCOME') != ''",
			"talk": [
				{ "when": "out('C')", "steps": [{ "say": "장꾼", "lines": ["서낭당에 떡 한 조각 놓고 넘었소. 요샌 다들 그런다더구먼."] }] },
				{ "when": "true", "steps": [{ "say": "장꾼", "lines": ["고개가 다시 열렸다길래 사흘 길을 하루에 왔소!"] }] }] },
		{ "id": "merchant_b", "chr": "CHR_HUM_002", "kind": "merchant", "name": "장꾼", "at": "merchant_b", "facing": "left",
			"when": "v('CASE_NAMWON_OUTCOME') != ''",
			"talk": [{ "when": "true", "steps": [{ "say": "장꾼", "lines": ["해 지기 전에 넘으려고 서두르는 중이오."] }] }] },
		# 잔치(A·B)
		{ "id": "feast_m", "chr": "CHR_HUM_009", "kind": "villager_m", "name": "마을 사람", "at": "feast_a", "facing": "left",
			"when": "out('A') or out('B')", "talk": [{ "when": "true", "steps": [{ "say": "마을 사람", "lines": ["한 잔 받으시오! 오늘은 잔칫날이오."] }] }] },
		{ "id": "feast_f", "chr": "CHR_HUM_010", "kind": "villager_f", "name": "마을 아낙", "at": "feast_b", "facing": "right",
			"when": "out('A') or out('B')", "talk": [{ "when": "true", "steps": [{ "say": "마을 아낙", "lines": ["떡 좀 드시오. 이젠 떡 냄새도 겁나지 않아요."] }] }] },
	]

# ---------------------------------------------------------------------------
# 조사 대상(물건) — 소품은 props()가 보인다
# ---------------------------------------------------------------------------
static func objects() -> Array:
	var cake := func(id: String, text: String) -> Dictionary:
		return { "id": id, "at": id, "label": "떨어진 떡 · 조사", "radius": 2.0, "when": "not f('%s') and f('case_started')" % id,
			"steps": [{ "flag": id }, { "examine": "떨어진 떡", "text": text }, { "clue": "cakes" }, { "give": TTEOK, "quiet": true },
				{ "call": "check_food" }] }
	return [
		cake.call("cake_1", "길섶에 떡 하나가 반쯤 묻혀 있다. 둘레 흙을 큰 코가 킁킁댄 듯 파헤쳤다."),
		cake.call("cake_2", "굽이를 돌자 또 떡 하나. 짐승 이빨 자국이 났는데, 먹다 말고 버렸다."),
		cake.call("cake_3", "세 번째 떡. 고개마다 하나씩 던져 주며 걸음을 재촉한 것 같다."),
		{ "id": "torn_skirt", "at": "torn_skirt", "label": "덤불에 걸린 천 · 조사", "when": "not c('torn_skirt') and f('case_started')",
			"steps": [{ "examine": "찢어진 치맛자락", "text": "덤불에 쪽빛 무명 치맛자락이 걸려 있다. 날카로운 것에 네 줄로 길게 찢겼다." }, { "clue": "torn_skirt" }] },
		{ "id": "blood", "at": "blood", "label": "길가의 얼룩 · 조사", "when": "not c('blood') and f('case_started')",
			"steps": [{ "examine": "마른 얼룩", "text": "길가 돌에 검붉은 얼룩이 번져 있다. 둘레 풀이 한쪽으로 쓸려 누웠다." }, { "clue": "blood" }] },
		{ "id": "tracks", "at": "tracks", "label": "발자국 · 조사", "when": "not c('tracks') and f('case_started')",
			"steps": [{ "examine": "뒤섞인 발자국", "text": ["짚신 자국 곁에 손바닥보다 큰 둥근 발자국.", "짚신 자국은 고갯마루에서 끊기고, 큰 발자국만 숲으로 간다."] },
				{ "clue": "tracks" }] },
		{ "id": "basket", "at": "basket", "label": "서낭당 앞 광주리 · 조사", "when": "not c('basket') and f('case_started')",
			"steps": [{ "examine": "빈 광주리", "text": ["서낭당 돌무더기 앞에 광주리가 엎어져 있다. 떡은 한 조각도 없다.", "곁에 무명 수건 하나. 광주리를 일 때 머리에 받치던 것이다."] },
				{ "clue": "basket" }, { "call": "check_food" }] },
		# S0003 집 안
		{ "id": "hearth", "at": "hearth", "label": "아궁이 · 조사", "radius": 1.6, "when": "not c('cold_hearth') and f('case_started')",
			"steps": [{ "examine": "식은 아궁이", "text": "재를 헤집어도 불씨 하나 없다. 사흘은 불을 때지 않았다." }, { "clue": "cold_hearth" }] },
		{ "id": "kneading", "at": "kneading", "label": "떡가루 묻은 함지 · 조사", "radius": 1.6, "when": "not c('mother_route') and f('case_started')",
			"steps": [{ "call": "mother_flashback" }, { "clue": "mother_route" }] },
		# S0006 추가 조사
		{ "id": "flour_prints", "at": "flour", "label": "흰 발자국 · 조사", "radius": 2.4, "when": "not c('flour_prints') and f('case_started')",
			"steps": [{ "examine": "밀가루 속 큰 발자국", "text": ["쏟아진 밀가루를 밟은 큰 발자국이 숲가 외딴집 쪽으로 이어진다.", "뒷발보다 앞발 자국이 유난히 하얗다."] },
				{ "clue": "flour_prints" }, { "rule": "K_FLOUR" }] },
		{ "id": "claw", "at": "claw", "radius": 2.6, "label": "큰 나무 · 조사", "label_if": ["c('claw_marks')", "나무 밑동 · 참기름 바르기"],
			"when": "f('case_started') and (not c('claw_marks') or (ph('night') and has('%s') and not w('oil_on_tree') and not f('climax_started')))" % OIL,
			"steps": [
				{ "if": "not c('claw_marks')", "then": [
					{ "examine": "긁힌 껍질", "text": ["사람 키를 훌쩍 넘는 곳까지 껍질이 깊게 긁혀 있다.", "거친 껍질엔 발톱이 박혔고, 매끈한 옹이 자리에선 미끄러진 자국뿐이다."] },
					{ "clue": "claw_marks" }, { "rule": "K_CLIMB" }] },
				{ "if": "ph('night') and has('%s')" % OIL, "then": [{ "call": "oil_tree" }] }] },
		{ "id": "barn", "at": "barn_front", "label": "헛간 · 살펴보기", "radius": 2.2, "when": "f('case_started') and not f('barn_seen')",
			"steps": [{ "flag": "barn_seen" }, { "examine": "헛간", "text": ["볏단 사이에 곡식 자루와 떡 몇 덩이를 싼 보자기.", "장에 내다 팔고 남은 것이다."], "kind": "item" },
				{ "give": TTEOK, "n": 2 }] },
		{ "id": "territory_edge", "at": "territory_edge", "label": "숲속 빈터 어귀 · 조사", "radius": 3.0, "when": "not c('territory')",
			"steps": [{ "examine": "숲속 빈터", "text": ["빈터 어귀에 짐승 뼈가 구른다. 둘레 나무마다 발톱 자국.", "타다 만 횃불 하나. 누군가 불을 들고 여기까지 몰아낸 적이 있다."] },
				{ "clue": "territory" }, { "rule": "K_TERRITORY" }] },
		# 밤의 준비(S0007 전)
		{ "id": "cake_bait", "at": "cake_bait", "label": "숲 오솔길 어귀 · 떡 놓기", "radius": 2.4,
			"when": "ph('night') and not w('cake_bait') and has('%s') and not f('climax_started')" % TTEOK, "steps": [{ "call": "place_bait" }] },
		{ "id": "yard_torch", "at": "yard_torch", "label": "마당 횃대 · 불 붙이기", "radius": 2.0,
			"when": "ph('night') and not w('torch_lit') and has('%s') and not f('climax_started')" % TORCH,
			"steps": [{ "take": TORCH }, { "world": "torch_lit" }, { "caption": "횃대에 불을 옮겨 붙였다. 마당이 붉게 일렁인다.", "sec": 2.2 }] },
		{ "id": "house_door", "at": "hide_spot", "label": "숨어서 기다린다", "radius": 2.6, "when": "ph('night') and not f('climax_started')",
			"steps": [{ "call": "wait_at_door" }] },
	]

static func triggers() -> Array:
	return [
		# S0001 끝: 성문 통과
		{ "id": "s0001_gate", "at": "east_gate", "radius": 12.0, "when": "ph('explore') and not f('s0001_done')", "steps": [{ "flag": "s0001_done" }] },
		# S0002 주막 주변대화(지나가며 엿듣는다 — 조작을 막지 않는다)
		{ "id": "s0002_overhear", "at": "tavern", "radius": 15.0, "when": "ph('explore') and not f('case_started')", "ambient": [
			["주모", "아직도 안 돌아왔다지?"], ["손님", "사흘이면…"]] },
		# S0005 첫 조우: 고갯길 단서 셋 이상 + 고갯마루 아래, 또는 빈터에 먼저 들어섬
		{ "id": "s0005_pass", "at": "first_seen", "radius": 16.0, "when": "ph('explore') and f('case_started') and not f('first_encounter') and fn('path_clues') >= 3",
			"event": "S0005" },
		{ "id": "s0005_territory", "at": "territory", "radius": 10.0, "when": "ph('explore') and f('case_started') and not f('first_encounter')", "event": "S0005" },
		# 밤: 외딴집 가까이
		{ "id": "night_arrive", "at": "yard", "radius": 16.0, "when": "ph('night') and not f('climax_started')", "steps": [
			{ "caption": "창호지 너머로 등잔불이 가물거린다. 아직은 조용하다.", "sec": 2.6 },
			{ "toast": "준비를 마치면 마당 구석에 숨어 기다리자.", "kind": "info" }] },
	]

# ---------------------------------------------------------------------------
# 소품(조건이 참일 때만) — kit/story/clue.gd + 세계 데칼(있으면)
# ---------------------------------------------------------------------------
static func props() -> Array:
	return [
		{ "id": "p_cake_1", "kit": "story/clue", "params": { "kind": "tteok", "seed": 1 }, "at": "cake_1", "ry": 0.3, "when": "not f('cake_1')" },
		{ "id": "p_cake_2", "kit": "story/clue", "params": { "kind": "tteok", "seed": 2 }, "at": "cake_2", "ry": 1.2, "when": "not f('cake_2')" },
		{ "id": "p_cake_3", "kit": "story/clue", "params": { "kind": "tteok", "seed": 3 }, "at": "cake_3", "ry": 2.1, "when": "not f('cake_3')" },
		{ "id": "p_skirt", "kit": "story/clue", "params": { "kind": "skirt" }, "at": "torn_skirt", "ry": 0.0 },
		{ "id": "p_blood", "kit": "story/clue", "params": { "kind": "blood" }, "at": "blood", "ry": 0.4 },
		{ "id": "d_blood", "decal": { "kind": "blood", "size": 1.1, "ry": 0.6 }, "at": "blood" },
		{ "id": "p_tracks", "kit": "story/clue", "params": { "kind": "tracks", "length": 4.5 }, "at": "tracks", "ry": 0.55 },
		{ "id": "d_tracks", "trail": { "kind": "paw", "points": ["tracks", "tracks_end", [-3180.0, -262.0]], "step": 0.9, "size": 0.5 } },
		{ "id": "p_basket", "kit": "story/clue", "params": { "kind": "basket" }, "at": "basket", "ry": 0.2, "when": "not out('C')" },
		{ "id": "p_offering", "kit": "story/clue", "params": { "kind": "offering" }, "at": "offering", "when": "out('C')" },
		{ "id": "p_flour", "kit": "story/clue", "params": { "kind": "flour", "length": 5.0 }, "at": "flour", "ry": -0.9 },
		{ "id": "d_shoes", "trail": { "kind": "shoe", "points": [[-3163.0, -192.0], [-3157.0, -212.0], "tracks"], "step": 0.8, "size": 0.45 } },
		{ "id": "d_claw", "decal": { "kind": "claw", "size": 0.9, "wall": true, "dy": 3.0, "ry": 0.0 }, "at": [-3205.5, -341.45] },
		{ "id": "d_claw_low", "decal": { "kind": "claw", "size": 0.6, "wall": true, "dy": 1.2, "ry": 0.3 }, "at": [-3205.4, -341.45] },
		{ "id": "d_flour", "decal": { "kind": "flour", "size": 1.8 }, "at": "flour" },
		{ "id": "d_flour_trail", "trail": { "kind": "flour_paw", "points": ["flour", [-3190.0, -327.0], [-3200.0, -338.0]], "step": 0.9, "size": 0.48 } },
		{ "id": "p_claw", "kit": "story/clue", "params": { "kind": "claw", "r": 0.42, "h": 3.4 }, "at": "big_tree" },
		{ "id": "p_oil", "kit": "story/clue", "params": { "kind": "oil", "r": 0.42 }, "at": "big_tree", "when": "w('oil_on_tree') and not ph('done')" },
		{ "id": "p_oil_jars", "kit": "story/clue", "params": { "kind": "oil_jars" }, "at": "oil_jars" },
		{ "id": "p_bones", "kit": "story/clue", "params": { "kind": "bones" }, "at": "territory_edge" },
		{ "id": "p_bait", "kit": "story/clue", "params": { "kind": "cake_trail", "n": 6, "length": 10.0 }, "at": [-3227.0, -341.5], "ry": 0.15,
			"when": "w('cake_bait')" },
		{ "id": "p_torch_fire", "kit": "story/clue", "params": { "kind": "torch_fire" }, "at": "yard_torch", "when": "w('torch_lit')" },
		{ "id": "p_white_paw", "kit": "story/clue", "params": { "kind": "white_paw" }, "at": "house_door", "dy": 0.42, "when": "w('white_paw')" },
		{ "id": "p_jeogori_c", "kit": "story/clue", "params": { "kind": "jeogori" }, "at": "jeogori_c", "when": "out('C')" },
		{ "id": "p_feast", "kit": "story/clue", "params": { "kind": "feast" }, "at": "feast", "when": "out('A') or out('B')" },
	]

# ---------------------------------------------------------------------------
# 사건 장면(§44 필드 + steps). SOURCE_VERIFIED=false인 장면은 실행하지 않는다.
# ---------------------------------------------------------------------------
static func _ev(id: String, trigger: String, loc: String, tw: String, actions: String, branches: String, wsc: String, steps: Array) -> Dictionary:
	return {
		"EVENT_ID": id, "RECORD_TITLE": "산길의 실종", "SOURCE_ID": "JG01",   # docs/FOLKTALE_CATALOG.md JG01 (전국형 D)
		"SOURCE_TITLE_INTERNAL": "해와 달이 된 오누이", "SOURCE_TYPE": "tale", "SOURCE_REGION_GRADE": "D",
		"SOURCE_REGION_NOTE": "전국형 민담. 남원 고유 전승이라고 주장하지 않는다(§36.2 각색: VARIANT).",
		"ADAPTATION_MODE": "VARIANT", "TRIGGER": trigger, "LOCATION_TYPE": loc, "TIME_WEATHER": tw,
		"PLAYER_ACTIONS": actions, "RESOLUTION_BRANCHES": branches, "WORLD_STATE_CHANGE": wsc, "SOURCE_VERIFIED": true,
		"steps": steps,
	}

static func events() -> Dictionary:
	return {
		"S0001": _ev("S0001", "새 게임", "남원 외곽(동쪽 통영별로)", "오전 · 맑음", "성문까지 직접 걷는다", "-", "-", [
			{ "phase": "explore" }, { "time": 9.5 }, { "weather": "clear" },
			{ "teleport": "start", "face": "left" },
			{ "give": "ITM_TOOL_009", "quiet": true }, { "give": "ITM_WPN_001", "quiet": true }, { "give": "ITM_WPN_002", "quiet": true },
			{ "give": "ITM_AMMO_001", "n": 12, "quiet": true }, { "give": COIN, "n": 12, "quiet": true },
			{ "call": "opening" },
			{ "journal": "마지막으로 적힌 곳 — 남원" },
		]),
		"S0002": _ev("S0002", "주모에게 다가감(지나가면 주변대화)", "남원 동문 밖 주막", "오전", "누구 말인지 묻는다", "-", "사건 기록 생성", [
			{ "say": "나그네", "lines": ["누구 말입니까?"] },
			{ "say": "주모", "lines": ["고개 너머 사는 떡장수요."] },
			{ "call": "start_case", "args": ["jumo"] },
		]),
		"S0003": _ev("S0003", "오누이에게 말을 건다", "고개 너머 외딴집", "낮", "집 안을 살핀다(아궁이·떡가루)", "-", "-", [
			{ "flag": "met_kids" },
			{ "say": "누이", "lines": ["어머니가 장에 갔어요."] },
			{ "say": "아우", "lines": ["오늘은 와요?"] },
			{ "call": "start_case", "args": ["kids"] },
			{ "clue": "kids_story" },
		]),
		# S0004·S0006·S0008은 장면 하나가 아니라 조사 대상·선택이 모인 구간 — 기록용(단서·결말을 고르면 seen에 남는다)
		"S0004": _ev("S0004", "사건 기록 생성 뒤 고갯길", "고갯길(떡 셋·치맛자락·핏자국·발자국·서낭당 광주리)", "낮", "순서 없이 조사(3개 이상이면 첫 조우 가능)",
			"-", "-", []),
		"S0006": _ev("S0006", "첫 조우 뒤(선택)", "방앗간·포수·기름집·헛간·큰 나무·숲속 빈터", "낮~해질녘", "추가 조사·준비(참기름·떡·횃불)",
			"-", "-", []),
		"S0008": _ev("S0008", "S0007 뒤", "외딴집 마당 / 숲속 빈터", "밤", "싸운다 / 기름 바른 나무 / 떡과 횃불로 영역 밖까지",
			"A 처치(마당 전투) · B 함정(미끄러진 범 + 짧은 전투) · C 물러나게 함(전투 없음)", "A·B: 잔치·장꾼 / C: 서낭당 떡 공양·밤 울음소리·장꾼", []),
		"S0005": _ev("S0005", "고갯길 단서 3개 이상 + 고갯마루 아래 숲", "고갯마루 아래 숲", "해질녘", "싸우거나 물러난다(보스전 아님)",
			"범이 물러남 / 플레이어가 물러남 / 쓰러져 포수에게 업혀 옴", "-", [
			{ "flag": "first_encounter" }, { "cutscene": true },
			{ "time": 17.4 },
			{ "caption": "바람이 멎는다. 새소리도 그쳤다.", "sec": 2.2 },
			{ "cutscene": false },
			{ "combat": "pass_wood", "mods": { "firstEncounter": true }, "allow_flee": true, "retreat_at": { "hpRatio": 0.9, "seconds": 25.0 }, "store": "first" },
			{ "call": "after_first_encounter" },
		]),
		"S0007": _ev("S0007", "밤, 외딴집에서 숨어 기다린다", "외딴집 마당", "밤", "지켜본다 / 뛰어나간다", "-", "-", [
			{ "call": "climax" },
		]),
		"S0009": _ev("S0009", "결말 다음 날 아침", "외딴집 마당", "아침", "말없이 저고리를 건넨다", "-", "마을 사람들이 오누이를 거둔다", [
			{ "call": "mother_news" },
		]),
		"S0010": _ev("S0010", "S0009 직후", "외딴집 마당", "아침", "기록책을 보인다", "-", "MAIN_MASTER_TRACE = HANYANG, SKILL_BEAST_TRACE", [
			{ "say": "노인", "lines": ["그 책… 전에도 그런 책 들고 다니던 양반이 있었소."] },
			{ "say": "나그네", "lines": ["어디로 갔습니까?"] },
			{ "say": "노인", "lines": ["한양 간다고 했지."] },
			{ "var": "MAIN_MASTER_TRACE", "value": "HANYANG" },
			{ "var": "SKILL_BEAST_TRACE", "value": true },
			{ "toast": "새 해결 수단 — 짐승 흔적 읽기", "kind": "rule" },
			{ "journal": "이겸의 흔적 — 한양" },
		]),
	}
