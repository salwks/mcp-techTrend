# 설화록 — 도시·노정 제작 규칙 v1.0 (공통 · 지역 · 설화 3층)

> 작성: 2026-10-11 · 근거: 브랜치 `claude/youthful-gauss-d0fxzv`의 실제 코드·데이터. 문서만 다루며 코드는 바꾸지 않았다.
> 갱신: 2026-10-11 공통 승격 1차(`seolhwa_godot/docs/reports/commonize-1.md`) — C17·C27·C46 구현(G), 길목 깃발 land 노정만(결정 5·6), F-1·F-6 완료.
> 경로는 따로 적지 않으면 `seolhwa_godot/` 기준이다. 상태 표기는 다음과 같다.
> - **G**: 공통 코드에 이미 있어 모든 공간에 적용된다.
> - **N**: 남원 코드·데이터에만 있다. 공통으로 승격해야 한다.
> - **P**: 결정만 있고 코드가 없다(문서 위 규칙).

---

## A. 원칙

1. **남원이 규칙을 만들고, 다음 도시는 규칙을 적용한다.** 남원 v3.2는 내용 템플릿이 아니라 품질 기준이다(`seolhwarok_NAMWON_v3.2_DECISIONS.md` 「위상」).
2. **도시의 기본 모습은 데이터(CITY_PROFILE)와 공통 builder가 만든다.**
   - 사람은 중요한 10~20%만 손으로 다듬는다: 랜드마크 구도, 사건 무대, 카메라 구역.
3. **세 층을 섞지 않는다.**
   - 공통 층의 상수는 사건이 바꾸지 않는다.
   - 설화 층은 E절의 계약(hook·데이터 키)으로만 더하거나 덮어쓴다.
   - 공통 코드 안에 `if space == "JL_..."` 같은 분기를 새로 만들지 않는다.
4. **이동은 편하게 하되, 곁의 말 걸기·이야기 장면을 가로채지 않는다**(v3.2 다듬기 「이동 규칙 셋」 원칙).
5. **고증은 참고용이다**(1870년 전후). 실측에 억지로 맞추지 않는다.

---

## B. 공통 규칙 목록

### B-1. 공통 층 (전국 규칙)

| # | 규칙 | 현재 값 | 소유 파일 · 함수 | 상태 |
|---|---|---|---|---|
| C01 | E 대상 우선순위 | 이야기 인물·물체(트리거 포함) → 고을 사람·마부·깃발 가운데 **가장 가까운 것** → 탁본 → 배 → 말 | `story_director._update_target`(801), `region_main._story_talking`(1357), `e_frame` | G |
| C02 | E 닿는 거리 | 이야기 인물 2.2 · 이야기 물체 2.0 · 고을 사람 1.9 · 마부 2.4 · 깃발 2.4 · 탁본 2.6 · 배 `BOARD_R` 5.0 · 트리거 기본 8.0 | `story_director._targets` · `ambient_talk.REACH` · `station_keeper.REACH` · `waymarks.REACH` · `boat_ride.BOARD_R` | G |
| C03 | 곁 대상이 E를 가져간 프레임 | 그 프레임과 다음 프레임에는 배·말이 E로 오르지 않는다 | `story_director._unhandled_input`(306), `region_main._story_talking` | G |
| C04 | 마부 대화 흐름 | E(2.4m) → "어디로 가시오?" → 목록: 역마·깃발 최대 `MAX_DEST` 7(못 가는 곳은 둘까지 흐리게) → 말 빌리기 → 역마 창 → "그만두겠소." 고른 뒤에야 말이 온다(`bring` 0.8~4초) | `station_keeper.gd`, `station_life.hold/unhold/bring` | G |
| C05 | 역 문 앞 조용 구역 | `STATION_QUIET` 45m 안에서는 큰길 말 타기 안내·E가 없다(마부만 연다) | `horse_ride.gd:25`, `_update_foot` | G |
| C06 | 말 타는 곳 (권역) | `MOUNT_R` **25m**. 예외는 막 내린 자리 40m, 포털 도착점 60m. 옛 stations 보고서의 45m는 낡은 값이다(v3.2 다듬기에서 45→25) | `horse_ride.gd:36`, `mount_check`(256–277) | G |
| C07 | 말 타는 곳 (노정) | 큰길(`ROAD_R` 7.5) 어디서나 다시 탄다 | `horse_ride.mount_check` | G |
| C08 | 말 타는 곳이 될 수 있는 거점 | 역 문 앞 · 노정 끝 · 배 나루 양 끝만. 성문 앞·마을 어귀·길가 주막은 뺀다 | `tools/region/make_travel_gates.py` → `travel/<공간>.json` `mount` | G |
| C09 | 도시 하차 | 읍성·도성은 FORCED_STOP. 성문 앞에서 내리고 성 안에 말을 들이지 않는다(그래프 `city` 점은 길 찾기 제외) | `make_travel_gates.py`, `ride_net.gd` | G |
| C10 | 거점별 지나가기 정책 | 장시 6 m/s · 마을·주막·역 9~10 · 여울 7 · 고개·성황당 10~11 · 배 나루·절·굴·노정 끝 FORCED. 말 최고 속도 18(빠르게 23) | `travel/<공간>.json` `gates/stops`, `horse_ride.SPEED` | G |
| C11 | 날씨 속도 | 맑음 1 · 안개 0.9 · 강풍 0.92 · 비 0.85 · 눈 0.75 · 폭풍우 0.7 · 눈보라는 강제 하차("눈보라 — 말은 고삐를 잡고 끌며 걷는다") | `travel` `ride.WEATHER_SPEED_MOD`, `horse_ride.mount_check` | G |
| C12 | 사건 접근 하차 | 트리거 반경 바깥 `STORY_APPROACH` 100m(70~200) 앞에서 내린다. 접근 구간(×0.9) 안에서는 다시 탈 수 없다 | `horse_ride._story_points`(0.5초) | G |
| C13 | 처음 가는 길 | 지나는 노정이 모두 '지나옴'이어야 역마로 간다("처음 가는 길은 걸어서(말 타고) 가 봐야 한다"). 제주는 남해 뱃길을 한 번 건너야 한다 | `fast_travel.reachable_from`(168) | G |
| C14 | 역마 시간 | `HORSE_KMH` 7, 지리 km×1.25, 0.3~60시간. 연출 2.8초. 2시간 넘으면 60% 확률로 날씨를 다시 뽑는다 | `fast_travel.gd:21–22, 289` | G |
| C15 | H 키 | 아무 데서나 여는 역마 창은 없다. 지나온 노정 포털 16m 안에서만 "H: 역마 타고 ○○까지 (지나온 길 건너뛰기)". 지도(M) 역참 목록은 그대로 | `region_main._check_portals`(1233), `region_map._station_go` | G |
| C16 | 사건 중 이동 잠금 | 사건이 `travel_lock()`으로 이유 글을 돌려주면 장면을 떠나는 9경로(역·역마 창·지도·포털·건너뛰기·말·배·마부·깃발)를 막는다. **걷기는 막지 않는다**(보이지 않는 벽 없음). 큰길 말 안내는 숨기고, E를 누르면 알림만 띄운다. 알림은 `_show_hud(이유)` 한 줄이다(예: "아이들을 두고 멀리 떠날 수 없다"). 장치는 공통이고 내용은 사건이 정한다 | `story_director.travel_lock`(106) → `fast_travel.lock_why/refuse`(144–157) | G |
| C17 | 사건 선언 고을 막음 | 사건 머리 `case.travel_gate { leave_space_until, notice, spaces? }`가 있으면 그 사건을 올린 공간에서 다른 공간으로 가는 역마·깃발을 막는다. 풀림: 풀림 변수 참 · 그 사건 phase done. 남원: `{ leave_space_until: "CASE_NAMWON_COMPLETE", notice: "남원 일이 아직 끝나지 않았다 — 고을을 떠날 수 없다" }`. `FIRST_SPACE` 하드코딩 없음 (구현 commonize-1) | `fast_travel.gate_for/gate_why` ← `case_registry.ids_for` + `namwon_data` `case.travel_gate` | G |
| C18 | 배·나루 | `BOARD_R` 5 · 나룻배 5.5 m/s(바다 9) · 건너뛰기 ×8(최대 40) · 강 뱃길 7.5 m/s(`river_lanes`). 이야기 배(`scripted`)는 잠금을 비켜 간다. 사공 대화는 없다 | `boat_ride.gd`, `river_lanes.gd` | G |
| C19 | 역참 키트 | 마방 27×21m(칸 2.6m×5, 대표 도시는 6칸) + 문 앞 9×2.6m. 정면은 남향 ±30°, 높이차 4.5m 안. 지역 차림은 `STYLES`(honam·yeongnam·giho·gwanseo·haeseo·gwandong·gwanbuk·tamna) | `kit/station/mabang.gd`, `hitch.gd`, `tools/region/make_stations.py` | G |
| C20 | 역참 생활 | 150m 안에서 만들고 200m 밖에서 지운다. 칸 말 하나는 비우고 마당 말 2(조랑말 3). 마부 일 고리(솔질→여물→쉼) | `station_life.gd:17–20, 268` | G |
| C21 | 역참 자리 예약 | 배치 생성기는 쓰기 직전에 마방 터(+2m)·문 앞(+1m)을 비운다 | `tools/placement/station_reserve.py` | G |
| C22 | 길목 깃발 | 자리 출처는 `travel/<공간>.json`의 fast 노드 중 kind ∈ {CITY, MARKET, VILLAGE, HUB, COAST, INN, PASS}의 도착점이다. **권역과 `ROUTE_PROFILE.kind == land` 노정만** 세운다 — river·sea 노정은 깃대·깃발 E가 없고 그 거점의 fast·가 봄은 그대로(역마 창·지도·배로 간다). kind 출처: ROUTE_PROFILE이 아직 없어 `route.json route_type` → 공간 id 접두사 `RIVER_`/`SEA_` → 그 밖 land. 충돌체 없음(지나갈 수 있다). 큰길에서 4m 비켜 세우고 새 좌표는 없다. 160m에서 만들고 220m에서 지운다. 가 봄은 도착 30m 또는 구역+10m. 깃발 102 → 96 (구현 commonize-1) | `waymarks.route_kind/space_has_flags/is_flag(n, sp)`, `kit/station/waymark.gd` | G |
| C23 | 지도 3단계 | L3 고을 · L2 권역 · L0 전국 그림은 오프라인 렌더다. 이름표 우선순위는 HERE > CASE > HUB > TOWN > STATION > VILLAGE > LANDMARK > MINOR. 화면 px 고정 | `tools/region/render_joseon_map.py`, `region_map.gd:38–55` | G |
| C24 | 지도 표지 | 기호: 읍치(네모 성+붉은 점) · 장 · 마을 · 역(붉은 테 '역') · 깃발(쪽빛) · 나루 · 고개 · 절 · 성황당 · 봉수. 사건 표지는 기운 붉은 인 '사', 할 말 있는 사람은 붉은 「…」. 발견 반경: 이름난 곳 45m, 고개 70m, 장소 18m | `region_map._icon`(1017), `discovery.gd` | G |
| C25 | map_leads | 들은 행선지만 적는다(단서·범인·해결 자리는 금지). 다른 사건은 progress로 평가하며 `fn`은 쓰지 않는다 | `map_leads.gd`, 사건 `map_leads[]` | G |
| C26 | 기본 카메라 | 고정 yaw(남→북). 기본 pitch 38 · 거리 16 · fov 30. 말 20/21/38, 배 15/15/40. 권역 `camera_zones`로 덮어쓴다(예: 도성 안 45/28) | `camera_rig.gd:9, 22, 30, 56` | G |
| C27 | 대화 카메라 | 공통 `CameraRig.TALK` pitch 38 · 거리 13.5 · fov 38. 이야기 인물(사건 actor)에게 직접 말을 걸 때만(고을 사람·마부·깃발 제외). 우선순위 공통 → `case.talk_camera` → `actor.talk_camera` → 대화 중 명시적 camera/cutscene. `talk_camera = false`면 평소 카메라(`true`는 다시 켬). 플레이어와 인물 사이를 겨냥하고 대화 동안 음악 0.5. 사건 연출이 대화 구도를 다시 쓸 때는 `d.talk_camera_base()` (구현 commonize-1) | `camera_rig.TALK/talk_spec`, `story_director.interact/_talk_camera/talk_camera_base` | G |
| C28 | '보면' 트리거 금지 | 고정 카메라라서 트리거는 모두 '접근하면 / 반경에 들면'으로 쓴다. 공포 장면은 고정 구도 안에 미리 짠다 | v3.2 결정 3. 검사기 없음 | P |
| C29 | 하루 빛 | 전국 공통 키프레임 표 하나(0 · 4.4 · 5.6 · 7 · 9 · 15.6 · 17.2 · 18.3 · 19.4 · 20.6시). 등불은 18.5→19.5시에 켜지고 5→6시에 꺼진다. 시간은 기본적으로 흐르지 않는다(`time_flow=false`, 시작 10시) | `time_of_day.gd`, `region_main:81` | G |
| C30 | 기후·날씨 | 권역 `climate.png`(4m, 남부·중부·북부·고산·해안). 다시 뽑는 주기 120~260초. 눈선은 `climate.rule.alpine_alt_m` | `weather.gd` | G |
| C31 | 계절 | **전역 계절 시스템을 두지 않는다.** 계절은 사건별 set dressing으로만 나타낸다(E절) | 춘향 v1.1 결정 3. 디버그 `--farmseason`만 있음 | P |
| C32 | 고을 사람 밀도 | 장시·종로 0.14 · 도성·읍치 0.012 · 나루·포구·섬 0.014 · 들·산·절 0.01 /m². 고을 밖 큰길은 120m마다 확률 0.45(산길은 200m·0.25). 최대 사람 150·짐승 36. 150m에서 만들고 175m에서 지우며, 70m 안에서는 화면에 갑자기 나타나지 않는다 | `npc_ambient.gd` | G |
| C33 | 고을 사람 일과 | 시간표는 없다. 자리별 밤 계수(장 0.05 · 주막 1.0 · 관아 0.3 · 성문 0.6 · 들 0 · 집 0.05). 비에는 −55%, 들일은 −85%, 일꾼 75%가 도롱이 차림. 눈 −50% | `npc_ambient._presence`(412) | G |
| C34 | 닻 자리 → 사람 | 가게→상인 · 주막→주모·나그네 · 나루→사공 · 우물→아낙(제주는 해녀) · 관아·성문→관속 · 절→스님 · 밭→농부·소 · 성황당→나그네·무당. 고을 고유 인물은 settlement `profile.people/animals` | `npc_ambient.gd:226–285`, `PEOPLE_KIND` | G |
| C35 | 고을 사람 말 걸기 | 1.9m, 25초 안에 다시 말하면 "이미 한 말", 최근 48줄. 소문은 progress `heard`에 남는다 | `ambient_talk.gd`, `rumors_data.gd` | G |
| C36 | 핵심 안내 (CORE) | MOVE · RUN · INSPECT · TALK · JOURNAL · MAP · COMBAT_DODGE · COMBAT_GUARD. **행동을 마칠 때까지 남고** 시간으로는 끝나지 않는다. 저장하면 `ONBOARD_PENDING`에 남는다. 정보 안내는 실제로 보인 시간만 세며 `MIN_SHOWN` 2.5초 | `onboarding.gd:42–50, 145, 155(hold)` | G |
| C37 | 초반 안내 창 | `early()`가 `CASE_NAMWON_COMPLETE`에 묶여 있다(`EARLY_SEC` 25분). `guidance_flag`는 남원만 쓴다 | `onboarding.gd:120` | N |
| C38 | JOURNAL 안내 발화 | `on_case_started()`는 남원·평양·제주 셋만 부른다. 나머지 사건은 "R 기록책" 안내가 서지 않는다 | `onboarding.gd:250`, 각 `_case.gd` | N |
| C39 | 기록 종류 | `fact` ◆확인(본 것) · `heard` ◇들음 — `by` 말한 사람(필수) · `guess` △추정. 원칙 세 줄: "본 것은 본 대로. / 들은 것은 누가 말했는지. / 모르는 것은 모른다고." | `journal_view.gd:25`, `journal_book.gd:14–29` | G |
| C40 | 소리 API · 버스 | Master → BGM · SFX · Ambient. 음성은 전체 12, id당 4. 페이드는 실제 시간으로 잰다. 파일은 `assets/audio/{sfx,bgm}/<id>.(ogg\|wav)`. 기본 크기 10/7/9/8 | `scripts/audio/sound.gd:23–25`, `game_settings.gd:31` | G |
| C41 | 음악 정책 | 공간·시간대별 음악 규칙은 없다. 사건 `music_wanted()` 훅이 있지만 남원만 구현했다. 효과음도 남원만 부른다(11곳) | `story_director._update_music`(925) | N |
| C42 | 환경음·말발굽 | 권역 환경음 체계가 없다. `horse_ride.audio_cue`가 이어지지 않았다 | — | P |
| C43 | 아래쪽 글 크기 (1024×768 기준, ×`_k`) | 자막 40 · 안내 띠 30 · 조사·대화 E 32(처음 38, 키 칸 26/30) · 키 안내 F 27 · 소지품 25 · 말·배 안내 32 · 왼쪽 위 HUD 28. 위치는 `BOTTOM_ITEMS` 46 · `KEYHINT` 94 · `PROMPT` 152(높이 52) · `HINT` 160. 줄바꿈은 `wrap_words`(띄어쓰기에서만 끊음) | `story_ui.gd:35–44, 376`, `region_main._boat_text/_show_hud` | G |
| C44 | 사건 등록 | `case_registry.SPACE_CASES`, 공간 → id 배열. **한 공간에 한 번에 한 사건만 활성**이다. `choose()` 순서는 요구 조건 만족 + 미완료 → 요구 조건 만족 → 소문만. 사건은 장면을 열 때만 바뀐다 | `case_registry.gd:14, 106`, `story_director._setup` | G |
| C45 | 사건 변수 | 저장은 `cases.<id>` namespace. 완료 변수는 `CASE_<ID>_COMPLETE`, 결말 기본값은 `CASE_<ID>_OUTCOME`. 그런데 `COMPLETE_VARS`와 StoryState 기본 vars, 남원 reset 목록은 하드코딩이다 | `skills.complete_var`, `skills.gd:23`, `story_state.gd:11, 22, 78` | N |
| C46 | 새 사건 필수 메타 | `case.id · record_title · region · outcome_var · reset_vars · requires · EVENT_CLASS · SOURCE_ID` — 등록부 모든 사건에 키가 있어야 한다(requires는 비어도 키는 있어야, reset_vars는 목록 또는 사전). 경고(실패 아님): 남원 아닌 사건에 `rule_label` 없음("범의 버릇"이 뜸) · 싸움터가 있는데 `combat_bait_item` 없음(떡을 던짐) (구현 commonize-1) | `tools/story/validate_case_meta.gd`(CASEMETA) — `validate_event_class.gd`와 나란히 | G |
| C47 | 대화 구조 | 새 엔진을 만들지 않는다. story_runner의 `choice · loop · when · disabled_when · do · flag`로 쓴다 | v3.2 결정 7, `story_runner.gd` | G |
| C48 | 지형 만들기 | DEM + 압축 K, 투영식 `x=(lon−lon0)·cos(lat0)·111320·K`, `y=(alt−base)·K`. `forbidden` 목록(현대 제방·댐·도로 등)으로 고친다 | `tools/region/build.py`, `build_region.py`, `modern_fix.py` | G |
| C49 | 고을 성격표 → 모양새 | `region.json archetypes`(eupchi · plain · river · mountain · pass · temple · coast · island · capital) + `settlements[].profile`(culture · climate · roof · wall · layout · entrance · people · animals · signature · trades) → `Style` | `tools/placement/town_profile.resolve` | G |
| C50 | 문화권 가옥 키트 | `kit/culture/<culture_key>/`. 남원 region.json에는 `culture_key`가 없어 `village/*` 범용 키트를 쓴다 | `hubs.py CULTURE_HOUSE`, `north.py` | N |
| C51 | 성벽 | 한양·평양·함흥은 `walls` polygon을 엔진이 그린다. 경주·제주·황주는 builder `eupseong()`가 만든다. 남원은 `namwon.py`가 직접 만든다(186m 방형, `SIDE`). 구현이 셋이다 | `region_world`, `hubs.eupseong`, `namwon.wall_pieces` | N |
| C52 | 도시 builder | 도시마다 손으로 짠 함수다(`hubs.BUILDERS` 3 · `north.BUILDERS` 4 · `namwon.py` · `east.py`). 공용 helper는 `street_rows · village_c · eupseong · seonghwang · bridges · naru_set · port_set · grid_fill · lane_grid`. profile에서 밀도·폭·식생을 읽지 않는다 | `tools/placement/*.py` | P |
| C53 | 지명 표시 | `place_title.TITLES`(남원 고정)와 `hub_profiles/north_profiles.TITLES`가 이중이다. 남원만 고유 표를 쓴다 | `place_title.gd:13, 66` | N |
| C54 | 논밭 | `farm.png`(`farm_find.py`) → `farm.gd`. 기후대별 벼 상태 | `farm.gd` | G |
| C55 | 노정 길이 | 쉼터 사이 300m, 큰 고개 460m(압축 이음). 볼거리 등급 A 8 · B 10 m/s(OPTIONAL), C·D는 PASS | `tools/region/make_routes.py`, `route_sights.py` | G |
| C56 | 강·바다 뱃길 | `AUTO_RIDE_ALLOWED=false`. 꺾은선 lane을 사공이 젓는다. 포구·볼거리는 `stops[]·sights[]` | `river_routes.py`, `river_lanes.gd` | G |
| C57 | 식생 scatter | 고도를 `hg/K + 60`으로 되돌린다(**남원 K 0.30·기준 고도 60 고정**). 수종 고도대는 지리산 서부 기준이고 기후·권역 입력이 없다. 그래서 다른 일곱 권역(K 0.25~0.5, 기준 0m)에도 남원 식생이 깔린다 | `kit/nature/scatter.gd:519` | N |
| C58 | 지형 색 | 풀·숲·논 색이 shader 상수로 전국 같다(C_GRASS #9da66b 등) | `shaders/region_terrain.gdshader` | G |
| C59 | 권역 지형 빌드 경로 | 일곱 권역은 설정 파일(`tools/region/regions/<id>.json`)로 `build_region.main()`을 돈다. 남원만 전용 `main()` + `places.py · profiles.PROFILES · landuse.AREA_ID · hydro.KNOWN · namwon_widths` 경로를 쓰고, `qa.py`·`render.py`에도 남원 분기가 있다 | `tools/region/build.py:635`, `qa.py:10` | N |
| C60 | 이벤트 군중 | **공통 규칙 확정 / 최소 구현 필요.** 설화용 일시 군중은 `EventCrowd` 프리셋으로 배치: generic character bank 재사용 → 지정 구역 안 배치 → 단순 행동(idle/talk/watch/walk, 잔치는 sit/stand/serve) → density(low 6~10 / medium 10~18 / high 18~30, 1024×768 실행 기준 시작값 — 성능 시험 뒤 확정) → seed로 같은 배치 재현 → 사건 flag로 생성/제거 → 카메라 밖·먼 거리는 줄이거나 멈춤. 핵심 이야기 인물은 넣지 않는다(story actor). **만들지 않는 것**: 개별 군중 AI·생활 스케줄·길찾기·충돌 회피·감정 전파·관중 반응·대규모 navigation. 목적은 "군중 시뮬레이션"이 아니라 "사건 장면 채우기" | (계획) 춘향 자산·좌표 배치 때 구현 | P |

**공통 층 집계: 59개 = G 46 · N 9 · P 4** (표의 상태 칸을 세어 확인. commonize-1에서 C17·C27 N→G, C46 P→G).
- **N(남원에만 있어 공통 승격 필요)**: C37 · C38 · C41 · C45 · C50 · C51 · C53 · C57 · C59
- **P(문서만)**: C28 · C31 · C42 · C52
- 덧붙임: G 가운데 C16 이동 잠금·C41 음악 훅처럼 **장치는 공통이지만 지금 쓰는 사건이 남원 하나뿐**인 것이 있다. 다른 사건이 쓰기 시작할 때 E절 계약대로 쓰면 된다.

### B-2. 지역 층 (권역·노정 profile — 값은 C절)

| 항목 | 지금 출처 | 상태 |
|---|---|---|
| 지형·투영·K | `region.json projection`, `regions.json K` | G (데이터) |
| 건물 밀도 | builder 함수 안의 상수(`grid_fill pitch` 18~19m, `lane_grid` 21m, `fill_to_target`) | P (profile 필드 없음) |
| 식생 | builder 안 `tree()` 손 호출 + `scatter.gd`(남원 K·고도·지리산 수종 고정, C57) | N / P |
| 기후 | `climate.png` + `regions.json climate` | G |
| 주산업 | `region.json economy`, settlement `trades` | G (설명용 — 배치에 직접 쓰이지 않음) |
| 색 (palette) | 문화권 키트 재질 + 역참 `STYLES`. 하루 빛은 전국 공통이다 | P |
| 랜드마크 | `region.json landmarks[]` + builder 손 배치 | G (데이터) / builder 손 |
| 길 폭 | `region.json roads[].width_m`(대로 4~30m) | G |
| 관아 규모 | builder 손(`court_pcs`, `landmark/gwana*`) | P |
| 장 밀도 | `npc_ambient` 장시 0.14 + builder `sajeon_row`/`place_market` | G (사람) / 손 (가게) |
| 카메라 구역 | `region.json camera_zones`(한양·평양·함흥만) | G (남원·경주·강릉·황주·제주는 없음) |

### B-3. 설화 층 (사건마다)

| 항목 | 지금 방식 | 예 |
|---|---|---|
| 사건 인물·물체·트리거·소품 | `<id>_data.gd` `actors/objects/triggers/props`(`when`, phase별 `at`) | 남원 오누이·포수·이웃 아낙 |
| 사건 무대 건물 | `placement_story_<case>.json`. 사건과 관계없이 늘 읽힌다(`placement_loader.gd:49`) | 남원 외딴집·방앗간 10개 · 강릉 식생 비우기 2개 |
| 카메라 | 공통 TALK 위에 `case.talk_camera` · `actors[].talk_camera`(false = 끔), 단계 `{camera:{…}}`, `cutscene` | 남원 7A pitch 34·거리 17·fov 36 |
| 임시 군중 | 지금은 `when`으로 감싼 사건 actor(평양 `crowd_a/b` · 강릉 `town_crowd_*`). 앞으로는 `EventCrowd` 프리셋(C60) | 평양 `crowd_a/b` · 강릉 `town_crowd_*` |
| 환경 변화 | `set_hour · set_weather · world_state · set_moon · prop_states` | 남원 `u_moon` 0, 강릉 `snow_line` |
| 이동 잠금 | `case_fn.travel_lock()`(장면 안 조건) · `case.travel_gate`(공간 떠나기 — 데이터 선언) | 남원 밤 · 남원 첫 사건 |
| 음악·소리 | `case_fn.music_wanted()`, 단계 `sfx/bgm/duck/hush` | 남원만 |
| 계절 차림 | 사건 소품·배치(계획) | 춘향 PART I 단오·PART II 추수(아직 코드 없음) |

---

## C. CITY_PROFILE 스키마 제안

### C-1. 결정

> **확정 (2026-10-11) — 부록 결정표 참조**
> 1. **범용 placer는 지금 만들지 않는다.** 도시별 builder 함수(`hubs.py`·`north.py`·`namwon.py`)를 그대로 두고 CITY_PROFILE hook을 붙인다. builder는 밀도·길 폭·식생·랜드마크를 하드코딩 대신 profile에서 읽는다. 범용 placer는 F절 맨 끝의 나중 선택지로만 남긴다.
> 2. **남원 region.json 형식을 맞춘다**(`culture_key · walls · camera_zones · portals`). 승격 백로그 F-4에 넣는다.
> 3. **말 타기 거리**: 권역 `MOUNT_R` 25m · 노정 큰길 어디서나 · 막 내린 자리 40m · 역 문 앞 `STATION_QUIET` 45m. stations 보고서의 '45m 말 타는 곳'은 낡은 값이다.

### C-2. 필드 → 기존 소비처 → 필요한 것

`region_data/<id>/city_profile.json`(또는 `region.json`의 `city_profile` 블록)으로 둔다. 있는 값은 **복사하지 않고 참조**한다.

| 필드 | 뜻 | 지금 있는 곳 · 읽는 곳 | 필요한 일 |
|---|---|---|---|
| `id`, `culture_key`, `climate` | 권역 id · 문화권 · 기본 기후대 | `region.json culture_key`(남원 없음) · `regions.json climate` → `weather.gd`, 키트 선택 | 남원 culture_key=`honam` 추가 |
| `scale` | `{K, settlements, target_items, eup_extent_m}` | `regions.json K`, `region.json settlements`, placement 항목 수 | QA 기준(목표 항목 수)으로 쓴다 |
| `government_complex` | `{grade: 현/군/도호부/부/목/감영/도읍, dongheon, gaeksa, size_m, layout}` | builder 손(`court_pcs`, `landmark/gwana·gaeksa·samun·dongheon`) | builder가 grade→크기 표를 읽게 한다 |
| `wall` | `{type: none\|square\|polygon\|basalt, side_m, gates[], ongseong, source: walls[]}` | `region.json walls`(3곳) · `hubs.eupseong()` · `namwon.SIDE=186` | 세 구현을 `walls` polygon 하나로 |
| `road_width` | `{daero, jiseon, maeulgil, alley}` m | `region.json roads[].width_m`, `north.add_lane w=3.0` | 기본값 표를 두고 roads에 없는 것만 채운다 |
| `density_by_ring` | `{core, inner, outer, field}` → 필지 간격 m · 채움 비율 | `north.grid_fill step(19,18)` · `fill pitch 18` · `lane_grid pitch 21` · `in_frac` · `namwon.fill_to_target` | builder 인자로 넘긴다 |
| `market_density` | `{shops, stall_rows, npc_m2}` | `npc_ambient` 0.14 · `north.sajeon_row bays` · `namwon.place_market` | 가게 수를 profile에서 |
| `station` | `{ids[], style, pony}` | `region_data/stations.json` → `make_stations.py STYLES` | style을 profile에서 읽는다 |
| `ferry` | `{naru[], boat_lanes[], port[]}` | `region.json crossings(type=나루)`, `world.ferries`, routes `stops` | 참조만 |
| `vegetation` | `{forest_mix, town_trees[], river_trees[], field_crops[]}` | builder `tree(variant…)` 손 호출, `farm.png` | scatter·builder가 읽는다 |
| `palette` | `{roof, wall, ground, accent}`. 키트 재질 프리셋 이름 | 문화권 키트 · 역참 STYLES | 키트 프리셋 이름만(하루 빛은 공통) |
| `industry` | `[...]` | `region.json economy`, settlement `trades` | 닻 자리 비중·소품 묶음에 쓴다 |
| `landmarks[]` | `{id, kit, anchor, hand: true}` | `region.json landmarks[]` + builder 손 | hand=true면 사람이 다듬는 10~20%에 든다 |
| `special_spaces[]` | 사건·고유 공간(고분 들, 오름, 섬 등) | builder 함수 안 | 이름 붙은 hook으로 |
| `camera_zones[]` | 구역 pitch·거리 | `region.json camera_zones` → `camera_rig` | 남원·경주·강릉·황주·제주에 추가 |
| `archetype_overrides` | settlement profile 덮어쓰기 | `hub_profiles.py`, `north_profiles.py` | 이 두 파일이 profile의 원본이 된다 |

### C-3. 여덟 권역 초안 (현재 데이터 기준)

`density_by_ring`은 초안이다(측정 전). 단위는 필지 간격 m이다.
- H(빽빽) = 18
- M = 21
- L = 26
- 들마을 = 자동

| 필드 | JL_NAMWON_UNBONG | GG_HANYANG | GW_GANGNEUNG | GS_GYEONGJU |
|---|---|---|---|---|
| culture · climate | honam(추가) · south | giho · central | gwandong · central(해안·고산 섞임) | yeongnam · south |
| scale | K 0.3 · 고을 29 · 항목 1852 | K 0.5 · 17 · 6174 | K 0.3 · 15 · 880 | K 0.25 · 18 · 934 |
| government | 도호부 — 동헌 + 용성관(객사) | 도읍 — 경복궁·창덕궁·육조거리 | 대도호부 — 임영관 삼문·칠사당 | 부 — 부윤 관아 일승각·동경관 |
| wall | square 186m, 4문(완월루·향일루·망미루·공신루 터) + 옹성 | polygon 한양도성 · 4대문 | none(길촌형 읍치) | square 석성 4문(builder) |
| road_width 대로/지선/마을 | 5 / 3.5 / 2.5~4 | 6~30 / 4~6 / 3.5~4 | 4.5 / 3.5 / 3~4 | 4.5 / 3.5 / 3~4 |
| density core/inner/outer | H / M / L | H(도시 한옥 lane) / H / M | M(길 따라) / L / L | H / M / L(고분 사이 비움) |
| market | 남문 밖 장 + 운봉·인월 장 | 운종가 시전 행랑 · 배오개 · 칠패 | 남대천 단오 난장 | 봉황대 앞 장 |
| station · pony | 남원 역참 · 인월역 · 한양 길목 | 청파역 · 경주·함흥 길목 | 강릉 역참 · 구산역 · 한양 길목 | 경주 역참 |
| ferry | 요천 광한루 앞 나루 1 · 여울·징검 18 | 노량진·한강진·마포·용산 나루 5 · BOAT 4 · 한강 뱃길 | 남대천·경포 나루 3 | 서천(형산강) 나루 1 |
| vegetation | 지리산 활엽·소나무, 요천 버들, 운봉 고원 풀밭 | 백악·남산 소나무, 개천 버들, 왕십리 채마밭 | 경포 솔숲, 대관령 고산 풀·안개 | 계림 숲, 들 가운데 봉분 잔디, 토함산 솔 |
| palette | 황토 초가 + 회청 기와 | 회벽·회청 기와(ㄷ·ㅁ자) | 잿빛 이엉 그물 지붕 · 반가 기와 | 붉은 흙벽 · ㅁ자 기와 뜰집 |
| industry | 논(요천 들·운봉) · 장시 · 임산물 | 시전·경강 상업·빙고 | 논 · 고기잡이·소금 · 단오 난장 | 논 · 장시 · 미역 · 절 시주 |
| landmarks[] | 남원읍성 · 광한루·오작교 · 용성관 · 여원치 마애불 · 황산대첩비 · 실상사 | 한양도성 · 경복궁·광화문 · 창덕궁 · 종묘·사직 · 종루 · 광통교·수표교 · 목멱산 봉수 | 임영관 · 칠사당 · 오죽헌 · 선교장 · 경포대 · 대관령 국사성황사 · 굴산사지 | 경주읍성 · 봉황대(고분) · 첨성대 · 계림 · 반월성 터 · 불국사 · 석굴암 · 감은사 터 · 대왕암 |
| special_spaces[] | 지리산 고원 길(여원재) · 산내 계곡 | 북촌 비탈 · 개천 · 경강 포구 띠 | 석호(경포호) · 대관령 고개 | 고분 들 · 동해 갯마을(감포·대본) |
| camera_zones | 없음 → 추가 | 도성 안 45/28 · 운종가 47/32 | 없음 | 없음 |

| 필드 | HH_HWANGJU | PA_PYEONGYANG | HG_HAMHEUNG | JJ_JEJU |
|---|---|---|---|---|
| culture · climate | haeseo · central | gwanseo · north | gwanbuk · north | tamna · coast |
| scale | K 0.3 · 13 · 400 | K 0.3 · 18 · 1392 | K 0.3 · 11 · 1735 | K 0.28 · 13 · 1323 |
| government | 목 — 동헌 + 객사(제안관) | 감영 — 선화당 | 감영 — 선화당 | 목 — 홍화각·연희각·망경루 + 관덕정 광장 |
| wall | square 돌 읍성(builder), 의주대로가 남북으로 꿰뚫음 | polygon 내성·북성(대동문·보통문·칠성문·현무문·전금문) | polygon 함흥읍성(남문·낙민루·동문·구천각) | basalt 현무암 성(builder) + 돌하르방 |
| road_width 대로/지선/마을 | 6 / – / – | 6~10 / 4~6 / 3.5 | 5~6 / – / – | 4 / 3~3.5 / 2.5~4 |
| density core/inner/outer | M / L / L(겹집) | H / H / M(외성 정전 들) | M(田자 집) / L / L | M(올레) / L / L |
| market | 남문 밖 의주대로 장거리 | 대동문→보통문 종로 | 남문 밖 성천강 둑 장 | 관덕정 앞·동문 밖 장 |
| station · pony | 황주 역참 + 한양·평양·장산곶 길목 | 대동역 + 황주·함흥 길목 | 함흥 역참 + 한양 길목 | 제주목 마방 · 송당 목마장(조랑말) |
| ferry | 없음(섶다리·돌다리) | 대동강 나루 2 · BOAT 2 · 대동강 뱃길 | 없음(만세교) | 포구 산지포·화북포(남해 뱃길 도착) |
| vegetation | 도화동 복숭아나무 · 넓은 들 | 능라도 버들 · 모란봉 솔 | 본궁 반송 · 반룡산 | 억새 오름 · 팽나무 신당 · 돌담 밭 |
| palette | 깊은 一자 겹집 초가 · 짙은 기와 | 짙은 기와 · 넓은 처마 · 사괴석 담 | 두꺼운 갈색 이엉 · 장작 井자 더미 | 검은 현무암 · 새끼 그물 띠지붕 |
| industry | 논 · 역참·객사(사신 길) | 시전(서북 무역) · 대동강 수운 | 논·밭 · 명태·소금 · 삼베 | 밭(조·보리) · 물질 · 목축(말) · 귤 |
| landmarks[] | 황주읍성 · 객사 · 동헌 · 월파루 · 도화동 우물 | 평양성 · 대동문 · **연광정** · 부벽루 · 을밀대 · 청류벽 · 선화당 · 기자릉 | 선화당 · 남문 · 낙민루 · 구천각 · 만세교 · 함흥본궁 | 제주성 · 관덕정 · 삼성혈 · 연북정 · 송당 본향당 · 김녕사굴 · 화북포 해신사 |
| special_spaces[] | 의주대로 축 | **대동강** 강 앞 도시 · 능라도·양각도 섬 | 성천강 충적평야 | **오름** 54 · **돌담** 올레 · 용천수 |
| camera_zones | 없음 → 추가 | 평양 내성 45/28 | 함흥 성 안 45/28 | 없음 → 추가 |

### C-4. ROUTE_PROFILE (노정·뱃길)

필드는 다음과 같다. ★표는 `route.json`·`travel/*.json`에 이미 있다.
- `route_id`★, `kind: land|river|sea`★
- `from/to`★, `compression`★, `climate_zone`★
- `terrain`: plain · hills · pass · coast · river
- `rest_spacing_m`: 기본 300, 큰 고개 460
- `stops[]`★: jumak · town · naru · pass · pass_gate · samgeori · coast · port …
- `stations[]`(make_stations), `flags`(fast 노드에서 자동)
- `ferries[]`(naru stop · BOAT ends), `inns[]`(jumak stop + 길가 주막 키트)
- `sights[]`★(A~D 등급)
- `ride`★: `AUTO_RIDE_ALLOWED · FIRST_VISIT_REQUIRED · FORCED_STOPS`
- `overrides`(`overrides.json`)
- `no_station`: 설화 예외

| 노정 | kind · 지형 | 쉼터·나루·역 (stops / stations) | 깃발 | 손 고침·예외 |
|---|---|---|---|---|
| JL_NAMWON–GG_HANYANG (삼남대로) | land · 평야·고개 | 오수 주막 · 전주 남문 · 앵곡 · 곰나루 · 차령 · 천안삼거리 / 오수역 · 전주(삼례역) | 5 | R0101~0104 MUST 감속(소문·객주 수레) |
| GG_HANYANG–GS_GYEONGJU (영남대로) | land · 새재 | 송파나루 · 문경새재 · 상주 · 하회 나루 · 제비원 / 안보역 · 상주(낙양역) | 3 | 새재 FORCED + FIRST_VISIT_ONLY |
| GG_HANYANG–GW_GANGNEUNG (관동대로) | land · 고원 | 원주 · 치악산 주막 · 횡계 / 원주 역참 · 횡계역 | 3 | 치악산 FORCED + FIRST_VISIT_ONLY |
| GG_HANYANG–HG_HAMHEUNG (경흥대로) | land · 철령 | 축석령 · 철원 · 철령관 · 원산포 · 영흥 갈림 / 철령 아래 · 영흥 | 5 | 철령관 FORCED + FIRST_VISIT_ONLY · 영흥 갈림(노정 끝 셋) |
| GG_HANYANG–HH_HWANGJU (의주대로) | land · 평야 | 임진나루 · 개성 · 선죽교 · 청석골 · 서흥 / 청교역 | 4 | — |
| HH_HWANGJU–PA_PYEONGYANG | land · 평야 | 중화 | 1 | — |
| PA_PYEONGYANG–HG_HAMHEUNG | land · 산골 | 성천 · 양덕 · 고원 주막 / 고원 역참 | 3 | 평양 사건 뒤 FORCED 넷(`WHEN r05_on`) |
| HG_HAMHEUNG–BUKCHEONG | land · 해안 | 홍원 · 북청 | 2 | **NO_STATION**(함관령 옛 역 — 설화 층) |
| HH_HWANGJU–JANGSANGOT | land · 곶 | 재령 · 구월산 · 장산곶 | 3 | 막다른 길 |
| RIVER_HANGANG | river | 마포 · 두물머리 · 조포 · 목계진 · 충주 | 0 (예전 3 — 결정 5로 뺌) | AUTO_RIDE false |
| RIVER_DAEDONGGANG | river | 대동문 선창 · 두로도 · 겸이포 | 0 (예전 2) | AUTO_RIDE false |
| SEA_NAMHAE_JEJU | sea | 덕진다리 주막 · 관두포 · 화북포 | 0 (예전 1) | 첫 뱃길 `skip_lock` · 첫 통과가 제주 역마의 조건 |

---

## D. 도시 제작 체크리스트 (새로 만들거나 다시 만들 때)

| 단계 | 할 일 | 자동 / 사람 | 도구 · 산출 | 확인 |
|---|---|---|---|---|
| 1 지형 | DEM·투영 K·물길·길·고을 자리, `forbidden` 고치기 | 자동(설정은 사람) | `tools/region/build.py <id>`(`regions/<id>.json`) → `region.json`·height·landuse·climate | `qa.py`, 걷기 시험 |
| 2 랜드마크 | `landmarks[]` 자리 확정 → builder 손 배치(관아·객사·성문·이름난 곳) | **사람** — 10~20%의 핵심 | builder `lm_put/put/search` | 고정 카메라 화면, 지도 L3 |
| 3 지역색 | CITY_PROFILE 채우기(문화권·밀도·폭·식생·색) → builder 실행 → 역참 예약 → 마방·이동 거점 | 자동(profile 값만 사람) | `hubs.py/north.py <id>` → `make_stations.py` → `make_travel_gates.py` → `render_joseon_map.py` | fps, 항목 수, 깃발 수 |
| 4 사건 공간 | `placement_story_<case>.json`(무대 건물·식생 비우기) + 사건 data의 actors/props/anchors | **사람** | 손 JSON, `<id>_data.gd` | 사건 시험(`run_story_tests.sh`) |
| 5 특수 자산 | 고유 키트(`kit/landmark/*`), 인물 그림 굽기, 지역 소리 | **사람** | `export_*_frames.js`, 키트 | 키트 미리보기 |
| 6 검사 | 공통 규칙 검사기(F-5) | 자동 | (계획) `tools/validate_city.py`, 사건 메타 검사 | PASS |

---

## E. 설화 층 계약 — 사건이 더하거나 덮어쓸 수 있는 것

**원칙**
- 사건은 자기 데이터(`story/<id>/<id>_data.gd`)와 hook(`<id>_case.gd`)으로만 말한다.
- 공통 상수·공통 파일·`placement_<hub>.json`은 바꾸지 않는다.
- 활성 사건은 공간마다 하나다(C44, `multi-case-registry.md` §5).

| 할 수 있는 것 | 어떻게 (키 · hook) | 지금 상태 | 지킬 것 |
|---|---|---|---|
| 이동 잠금 | `case_fn.travel_lock() -> String` | G(남원만 씀) | 걷기는 막지 않는다. 이유 한 줄. 아침·phase로 저절로 풀린다 |
| 고을 막음 | `case.travel_gate { leave_space_until, notice, spaces? }` | G(남원 첫 사건이 씀 — F-1 완료) | 풀림 변수는 자기 사건 것. 이유 한 줄. 사건이 끝나면(phase done) 저절로 풀린다 |
| 대화 카메라 | 공통 TALK(38/13.5/38) 위에 `case.talk_camera {pitch, distance, fov 일부}` · `actors[].talk_camera` · `false`로 끄기 | G(F-6 완료) | 구도가 틀어지는 인물만 덮어쓴다 |
| 카메라 샷 | 단계 `{camera:{pitch, distance, fov, focus}}`, `cutscene`, `rig.shot` | G | 끝나면 `camera(null)`. 사용자 틸트 설정 복원 |
| 임시 군중 | **축제·잔치·관아 행사처럼 일시적으로 사람이 늘어나는 장면은 공용 이벤트 군중 프리셋(`EventCrowd`, C60)을 쓴다. 도시의 상시 인구 시스템을 새로 만들지 않는다.** 사건 데이터에 `crowds: [{ preset, area, density, roles, seed, when }]`로 선언 | P(최소 구현 필요) | 핵심 인물은 story actor. 인원은 성능 시험 뒤. 기존 `crowd_` actor 관례는 옮길 때까지 유지 |
| set dressing (계절·잔치) | `props[]`(`when`/phase) + `placement_story_<case>[_part].json` | 부분적(placement는 when 없이 늘 읽힘) | 숲 전체 색 변경 금지. 관아·읍성 둘레만(춘향 v1.1 §3) |
| 환경 변화 | `set_hour · set_weather · world_state · set_moon · prop_states` | G | `on_load`·`_quit`에서 되돌린다(남원 달 안전장치처럼) |
| 음악·소리 | `case_fn.music_wanted()`, 단계 `sfx/bgm/duck/hush` | G(남원만 씀) | 같은 id 체계(`assets/audio`) |
| 지도 표지 | `map_leads[]` | G | 들은 행선지만 |
| 기록 | `clues/rules/journal`, `kind`·`by` | G | heard는 `by`가 필수 |
| 안내 | `onboard.hold(key, 글, until)` · `guidance_flag` | G / N | 핵심 안내는 행동까지 |
| 사건 무대 비우기 | `placement_story_<case>.json`(식생 지우기) | G | 땅은 그대로 둔다 |

**금지**
- 공통 코드에 공간·사건 id 분기 추가
- 보이지 않는 벽
- 전역 계절 전환
- 다른 사건 변수 덮어쓰기(`reset_vars`는 자기 것만)
- 일반 NPC 밀도 상수 수정

---

## F. 승격 백로그 (우선순위 · 크기)

크기 기준은 S ≤ 1일, M 2~3일, L 5~8일, XL 2주 이상이다. 이 문서는 구현하지 않는다.

| 순위 | 일 | 크기 | 근거 규칙 |
|---|---|---|---|
| F-1 | ~~`fast_travel.gate_why` → 사건 선언 규칙~~ **완료(commonize-1)**: `case.travel_gate` + `fast_travel.gate_for`, `FIRST_SPACE` 제거 | **S** | C17 |
| F-2 | CITY_PROFILE 스키마 + 로더(Python `tools/placement/city_profile.py`, `hub_profiles/north_profiles`를 원본으로) | **M** | C-2 |
| F-3 | builder profile hook: `hubs.py`·`north.py`·`namwon.py`가 `road_width · density_by_ring · vegetation · landmarks · market_density · government_complex`를 profile에서 읽기 | **L** | C49 · C52 |
| F-3a | scatter 식생이 권역 `projection.K · y_base_alt · climate`를 읽고 profile `vegetation`(수종 고도대)을 따르게 하기. 지금은 남원 값이 전국에 깔린다 | **M** | C57 |
| F-3b | 남원 지형 빌드를 설정 파일 경로(`build_region` + `regions/JL_NAMWON_UNBONG.json`)로 옮기기. `places.py·AREA_ID·hydro.KNOWN·qa/render` 분기 제거(결과 비교 필수) | L | C59 |
| F-4 | 남원 region.json 형식 맞추기(`culture_key=honam · walls polygon · camera_zones · portals`) + `namwon.py` 성벽을 walls polygon으로. 다른 권역 camera_zones 채우기 | **M** | C26 · C50 · C51 |
| F-5 | 검사기: 새 도시(profile 필수 키 · 역참 · 깃발 · 말 타는 곳 · camera_zones · forbidden)와 새 사건(~~필수 메타~~ — C46 최소판 `validate_case_meta.gd` 완료 · 공통 코드 id 분기 금지 · heard `by` · map_leads 금지어) | **M** | C46 · C28 |
| F-6 | ~~대화 카메라 공통 기본값(`camera_rig.TALK`)과 사건·인물 덮어쓰기~~ **완료(commonize-1)** | S | C27 |
| F-7 | onboarding `early()`·JOURNAL 안내를 등록부의 '첫 사건'·`on_case_started` 공통 호출로 | S | C37 · C38 |
| F-8 | `COMPLETE_VARS`·StoryState 기본 vars·reset 목록을 등록부·사건 데이터에서 만들기 | M | C45 |
| F-9 | 지명 TITLES 하나로(`place_title` ← settlement `title`) | S | C53 |
| F-10 | 다중 사건: 비활성 사건 인물 층 · 같은 장면 사건 전환 · id 접두사 규칙 · 바뀐 키만 저장 | L | C44 |
| F-11 | set dressing 계약: `placement_story_<case>_<part>.json`에 `when` 붙이기(로더가 조건부로) | M | C31 · E |
| F-12 | 공간 음악·환경음 정책(시간대 낮·밤 고리, 권역 환경음) + 말발굽 `audio_cue` | M | C41 · C42 |
| F-13 | 탁본 대상도 배·말 E 막음에 넣기(`region_main._story_talking`이 탁본을 모름) | S | C01 |
| F-14 | 노정 `no_station` 같은 설화 예외를 ROUTE_PROFILE로(`make_stations.NO_STATION_SPACES`) | S | C-4 |
| F-15 | 권역 색(하루 빛 tint) — 결정 뒤에만 | M | B-2 palette |
| F-16 | (장기 백로그) 범용 placer | XL | 부록 결정 1 |
| F-17 | `EventCrowd` 최소 구현(C60) — generic bank 선택·구역 배치·단순 행동·density·seed·flag 표시/숨김·먼 거리 줄이기. **춘향 자산·좌표 배치 때** 만든다(남원 오누이용으로 미리 만들지 않음) | M | C60, E절 |

**상위 다섯**: ~~F-1(S)~~ 완료 · F-2(M) · F-3(L) · F-4(M) · F-5(M). F-3a(M)는 눈에 보이는 문제라 F-3과 함께 하기를 권한다.

---

## G. 남원 고유로 남길 것 (일반화하지 않는다)

| 항목 | 위치 | 이유 |
|---|---|---|
| 오누이 밤 전체(노크·흰 앞발·나무·동아줄·두 빛·아침), 범 배우기 mods | `story/namwon/*`, `ctiger._tut_next` | 사건 내용. 흐름(추적→조사→밤→위기)을 복제하지 않는다(v3.2 위상) |
| 외딴집·방앗간·수수밭·큰 나무 무대 | `placement_story_namwon.json` | 사건 무대 |
| 밤 이동 잠금 문구 "아이들을 두고 멀리 떠날 수 없다" | `namwon_case.travel_lock` | 내용만 남원. 장치는 공통(C16) |
| 첫 사건 막음 **문구**와 대상 변수 | `namwon_data` `case.travel_gate`(F-1 완료) | 장치는 공통(`fast_travel.gate_for`), 값은 남원 데이터 |
| 첫 방문 마부 안내(`station_intro`, 기다리는 말 7m, 사건 뒤만) | `namwon_case.gd:159–187` | 튜토리얼 연출 |
| 대화 카메라 값 38/13.5/38, 7A 34/17/36, 방어 46/19/30 · 34/15/34 | `namwon_data`, `namwon_case` | 사건 연출값. 공통 기본값은 따로 정한다 |
| 마지막 밤 달 감추기(`u_moon`) | `namwon_case`, `region_main.set_moon` | 장치는 공통, 사용은 남원 |
| `FIRST_RECORD` 네 줄, `tale_sky`, 결말 A/B/C | `namwon_case.gd`, `tale_sky.gd` | 사건 내용 |
| 새 게임 시작 자리 `NAMWON_START`·9.5시, `START_REGION` | `title_menu.gd:20–21`, `discovery.gd:24` | 게임 시작은 남원 하나다(설계) |
| 춘향 단오(그네·색천·씨름판)·추수(곡식가마·볏짚·감) 차림 | (계획) `story/namwon_chunhyang/` | 계절 시스템 대신 사건 차림(C31). **아직 코드 없음** |
| 춘향 군중 | PART I 단오 → `EventCrowd: dano_market`(density high, idle/talk/walk/watch, 광한루·장터 둘레) · PART II 생일잔치 → `EventCrowd: byeon_banquet`(density medium, sit/stand/serve/watch, 관아 마당·잔치상 둘레) | 프리셋은 공통(C60), 구역·밀도·seed는 춘향 데이터. 춘향·몽룡·변학도 등은 story actor |
| 광한루·오작교 키트, 지도 광한루 못 | `kit/landmark/gwanghallu*`, `region_map.gd:185` | 지역 층 랜드마크(설화 층 아님). 남원 profile에 둔다 |
| 범·떡 기본값(`rule_label` "범의 버릇", `combat_bait_item` 떡, 전투 HUD 떡) | `story_director.gd:398, 898`, `story_ui.gd:45` | **주의**: 남원 값이 공통 기본값으로 새어 있다. 다른 사건은 자기 값을 넣어야 한다(F-5 검사기 항목) |

---

## 부록. 결정 (2026-10-11 모두 확정)

| # | 항목 | 결정 |
|---|---|---|
| 1 | profile hook | 범용 placer는 만들지 않는다. 기존 builder에 `CITY_PROFILE`을 연결(F-2 → F-3/F-3a → F-4). F-16은 장기 백로그 |
| 2 | 남원 형식 | 전국 형식으로 통일 — `culture_key`·`walls`·`camera_zones`·빌드 경로만. 남원 모습은 다시 만들지 않고 전후 비교 스크린숏으로 보존 |
| 3 | 권역 승마 | 25m. 노정 자유 재탑승, 막 내린 자리 40m, 포털 도착 60m 예외 유지 |
| 4 | 대화 카메라 | **구현(commonize-1)** 공통 TALK 기본값 pitch 38 / distance 13.5 / fov 38 — story actor와 직접 대화할 때만(ambient_talk·마부·깃발 제외). 우선순위: 공통 기본 → `case.talk_camera` → `actor.talk_camera` → 대화 중 명시적 camera/cutscene. `talk_camera = false`로 인물별 끄기 |
| 5 | 수상 노정 깃발 | **구현(commonize-1)** 6개 제거(한강 마포·목계진·충주, 대동강 대동문 선창·겸이포, 남해~제주 덕진다리). 규칙: `ROUTE_PROFILE.kind == land`만 waymark, `river/sea`는 생성 안 함. 노드의 `fast`·발견 정보는 유지(물리 깃발과 깃발 E만 제거) |
| 6 | 깃발 충돌체 | 없음 (확인: 깃발 키트에 충돌체 없음 — commonize 시험) |
| 7 | 권역 빛 tint | `공통 time_of_day × CITY_PROFILE.light_tint` 하나뿐. 권역별 하루 조명표 금지, 사건이 tint를 영구 변경하지 않음, saturation/contrast 지역화 금지, 극단 그레이딩 금지, 기본 neutral, 중립 대비 ±5~8% 이내에서 시작, 1024×768 같은 시각 8권역 비교 스크린숏 후 확정. 방향: 남원 약간 따뜻 · 한양 중립 · 경주 따뜻·건조 · 강릉 맑고 차가움 · 황주 중립~차가움 · 평양 약간 차가움 · 함흥 가장 차가움 · 제주 밝고 따뜻 |
| 8 | EventCrowd | 이미 확정(C60, F-17) |
| 9 | 남원 밤 장거리 이동 잠금 | 이미 확정·구현 |

남원에서 얻은 시각·이동·대화 규칙은 이것으로 닫는다. 다음 권역은 `CITY_PROFILE` 지역값과 랜드마크·설화 공간만 정한다.
