# 춘향 2a — 사건 코드 앞 기반: 조건부 배치(F-11) · 옥 · 오누이 흔적 · EventCrowd(C60/F-17) (2026-10-11)

근거: `seolhwa/docs/production/CHUNHYANG_ASSETS_PLACEMENT_v1.0.md`(상태 **확정**, §8-A 사용자 결정 1~6) ·
`seolhwa/docs/production/CITY_ROUTE_PRODUCTION_RULES_v1.0.md`(E절 · C60 · F-10 · F-11 · F-17) · 춘향 v1.1 시나리오·결정 · `commonize-1.md` · `namwon-v32.md`.
**춘향 이야기 흐름(사건 코드·데이터)은 만들지 않았다** — 다음 단계.

## 1. 사용자 결정 기록

| # | 결정 | 어디에 |
|---|---|---|
| 1 | 관아 기본 배치 그대로, 8A′(58/21/32, 겨냥 z 212)를 공식 8A로 | 배치 데이터 `cameras.8A`(옛 `8A_tuned` 지움) · 자산 문서 §4·§8-A · 결정 문서 §7 |
| 2 | 옥 = 관아 바깥마당 서쪽 (-3175, 229.5), 늘 있는 고을 시설. 사건은 문 상태·인물·등롱만 | `placement_namwon_local.json`의 `ti_jail`(when 없음) · 키트 `kit/story/chunhyang.gd` kind `ok` |
| 3 | 월매 집 = `nw_house_158`, 뜻은 차림 | 꽃 정적, 평상·등롱·감나무 단계 조건 |
| 4 | 그네 (-3330, 444) 그대로 — 최종 컷에서 재확인 | 변경 없음 |
| 5 | 오리정 = ACT 5 이별 배경 랜드마크만 | `ti_orijeong` 정적 (-3205.8, -10) · 시나리오 §16 제목 "남원 밖 길 — 오리정 곁 북쪽 길" + 한 줄 |
| 6 | 오누이 흔적 (가) | `nw_trace_well` · `nw_trace_sorghum` · `nw_trace_sorghum_red` 정적(임시, F-10 전) |

## 2. F-11 — 조건부 배치

| 무엇 | 어디 |
|---|---|
| 배치 항목의 `when`(이야기 DSL 그대로): `ph` `f` `w`(파일 머리 `case`의 단계·플래그·지역 상태 — 도는 사건이면 살아 있는 상태, 아니면 저장된 진행), `v`(공통 변수), `active(id)`(지금 공간에서 도는 사건), `fn('is_night')`·`night()` | `scripts/region/placement_gate.gd` |
| 거짓이면 장면에서 떼고 충돌체를 뺀다. 지은 노드는 남겨 두고 참이 되면 다시 붙인다(새로 짓지 않음) | `region_world.set_static_enabled` · `_attach_one`(off) · `remove_tagged`(off 충돌체 제외) |
| 다시 보는 때: 매 프레임 값 넷(progress.version · 도는 사건 id · 이야기 갱신 번호 · 밤/낮 — 시간 조건이 있을 때만)만 비교, 바뀐 프레임에만 식을 돌림 | `gate.poll()`(region_main) · `gate.mark()`(story_director._refresh) · `Progress.version`(set_var·save_case·clear_case·reset_all·load_slot·use_path) |
| when 항목은 땅을 바꾸지 않는다(터 고르기·마당 흙 없음). 식생 비우기만 늘(나타날 때 덤불을 뚫지 않게 — 광한루 앞 잔디·관아 마당 몇 곳). 고을 사람 자리·건물 이름표·지도 그림에서 뺀다 | `placement_loader` · `npc_ambient` · `building_titles` · `region_map` |
| `placeholder`: 키트가 그 kind를 아직 못 지으면(`has_kind`) 기존 키트로 대신 | `placement_loader._resolve_placeholder` |
| 파일의 `crowds`는 읽어 모아 둔다(+ `case`·앵커) | `placement_loader.crowds` |

- `tale_items` 우회를 없앴다. 춘향 차림 42개가 `items`에 `when`과 함께 있다(단오 색천·씨름판·좌판·그네, 추수 물자, 잔치 차일·잔칫상 등). 춘향 사건 코드가 없어 단계가 비어 **모두 꺼져 있다**.
- 늘 있는 시설(옥·오리정)에는 when이 없다 — `placement_namwon_local.json`(허브 배치 `placement_namwon.json`은 고치지 않음, E절).
- 배치 항목 수: 1,862 → 1,909(춘향 차림 42 + 남원 정적 5), `gated=44`(차림 41 + 흔적 3), `missing=0`.

## 3. 옥 키트 (NEW, M) — `kit/story/chunhyang.gd` kind `ok`

- 원옥: 둥근 담(반지름 5m · 높이 2.45m · 돌 아랫단 + 흙담 + 기와 덮개) · 동쪽 작은 기와 문 · 북쪽 반의 초가 옥사 3칸(너비 5m · 깊이 3.4m) · 짚자리 · 물독.
- **옥사 앞(나무살)을 남쪽으로** 두었다: 평소 시점(yaw 0, 남→북)에서 살과 칸 안이 정면으로 보이고, 12A도 같은 방향(남쪽 마당 → 북쪽 살)이 된다. 그래서 앵커·12A를 바꿨다:
  `ch_jail_cell` (-3175, 228.2) · `ch_jail_bars_out` (-3175, 231.4) · `ch_jail_gate` (-3170, 229.5) · 12A pos (-3174.4, +1.45, 233.6) → look (-3175.2, +1.0, 228.2), fov 40 · 옥 등롱 `ti_jail_lamp` (-3171.0, 231.6)(담 안).
- 상태(prop_states): `ti_jail/gate`(바깥 문) · `ti_jail/cell`(가운데 칸 살문) = SEALED | OPEN, 기본 SEALED. 닫힌 문은 충돌체가 있고 열면 빠진다. 앵커 `cell · bars_out · gate_in · gate_out · lamp`.
- 나머지 NEW kind(그네·씨름판·보계·교의·형틀·차일·가마)는 아직 없다 — 데이터의 placeholder로 지어진다(꺼져 있음).

## 4. 오누이 흔적 (결정 6 (가) — F-10 전 임시 조치)

`placement_namwon_local.json`:

| id | 키트 | 조건 |
|---|---|---|
| `nw_trace_well` | `village/well` (p_well과 같은 자리·모양) | `not active('namwon')` |
| `nw_trace_sorghum` | `story/tale` sorghum(푸름) | `not active('namwon') and not v('CASE_NAMWON_COMPLETE')` |
| `nw_trace_sorghum_red` | `story/tale` sorghum red | `not active('namwon') and v('CASE_NAMWON_COMPLETE')` |

- 오누이 사건이 이 공간에서 돌면(완료 뒤에도 다른 사건이 안 서면 `choose()`가 오누이를 고른다) **사건 소품(p_well·p_sorghum·p_sorghum_red)이 그대로 그리고 정적 흔적은 꺼진다** — 겹치지 않는다. 오누이 v3.2 흐름(수수밭 붉게 번지기 연출 등)은 손대지 않았다.
- 춘향이 활성 사건이 되거나 사건이 없는 때만 정적 흔적이 선다: 완료 전 푸름, 완료 뒤 붉음. 우물은 늘.
- 외딴집·헛간·큰 나무는 이미 정적(`placement_story_namwon.json`). 발톱 자국·단서 소품은 남기지 않는다. 주모·방앗간 주인(·포수)은 다음 단계에 춘향 데이터로 다시 세운다.

## 5. EventCrowd 최소판 (C60 · F-17) — `scripts/story/event_crowd.gd`

- 선언: 배치 파일 또는 사건 데이터의 `crowds: [{ id, preset, area{rects, exclude, dy}, density, density_start|count, roles, bank, watch_targets, seed, when, far_freeze_m }]`.
- 공통 preset: `festival`(idle·talk·walk·watch) · `banquet`(sit·stand·serve·watch). 구역·인원·seed·when은 춘향 데이터.
- 인원: low 6~10 · medium 10~18 · high 18~30 범위로 자름. 배치는 seed 하나로 결정적(사각형 안 · 빼는 곳 밖 · 0.9m 간격, 세계 충돌체는 보지 않음 — 스트리밍에 따라 바뀌지 않게).
- 사람: generic bank 허용 목록만(이야기 인물 그림은 버리고 알림). 동작은 서기·말하기(가까운 사람 쪽)·구경/앉음/섬(구역 앵커 쪽)·제자리 오가기(walk 2~5m · serve 구역 안 두 점). AI·스케줄·길찾기·충돌 회피·반응 없음.
- 보이기: `when`(F-11과 같은 gate). `force(id, on, density)` · 디버그 `--crowdshow=dano_market:high,byeon_banquet:medium`.
- 비용: `far_freeze_m`(단오 60m · 잔치 40m) 밖은 숨김(그림·갱신 없음) · 화면 밖은 멈춤 · 절반 거리 밖은 세 프레임에 한 번.
- `dano_market`(festival, high, seed 50501) · `byeon_banquet`(banquet, medium, seed 50502) 정의만 — 꺼져 있다.
- 촬영을 보고 고친 것: 확정 8A 틀은 가로 약 16m(x -3170~-3154)라 초안 잔치 구역(x -3181~-3143)의 사람이 화면에 거의 없었다 → 안마당 A·B를 축 쪽으로, 대청 C를 처마에 안 가리는 앞 띠(z 206.3~207.6)로, 잔칫상 줄을 x -3168.8 / -3155.4로 옮김.
- 1A: 초안값(누각 동쪽 31m · 높이 23m)은 지붕을 바로 내려다봐 누각만 차고 C구역 군중이 화면 밖이었다 → pos (-3216, +18, 456) → look (-3290, +4, 446), fov 38로 다시 잡음(앞 C구역 군중 · 가운데 누각 · 오른쪽 단오 마당).

### 성능 (창 모드 1024×768 — 레티나라 장면 2048×1536, Mobile 렌더러, vsync 끔, 11시, 시험 저장)

측정 중 사용자의 게임(`play_act9`)과 Godot 편집기가 함께 떠 있었다 — 절대값보다 군중 끔/켬 차이를 본다.

| 틀 | 군중 | 사람(그림/전체) | 평균 fps | 최악 ms |
|---|---|---:|---:|---:|
| 1A | 끔 | 0 | 67.1 / 65.0 | 24 / 29 |
| 1A | dano_market high | 15/28 | 61.7 | 22 |
| 1A | dano_market 30(상한) | 17/30 | 64.7 | 22 |
| 걷기(단오 마당 가운데, 평소 시점) | 끔 | 0 | 117 / 126 | 18 / 17 |
| 걷기 | dano_market high | 24/28 | 110 | 14 |
| 8A | 끔 | 0 | 125 / 118 | 14 / 17 |
| 8A | byeon_banquet medium | 14/14 | 131 | 31 |
| 8A | byeon_banquet 18(상한) | 18/18 | 130 | 23 |

군중 비용은 측정 잡음(±5fps) 안이다. 1A가 무거운 것은 먼 경치(누각·못·들) 때문이고 군중 때문이 아니다.

**제안 인원**: `dano_market` **28**(high, A 장터길 10 · B 마당 14 · C 길목 4 그대로 — 30도 차이 없음) · `byeon_banquet` **14**(medium, 4 · 4 · 4 · 2 — 18도 차이 없으나 확정 8A 틀이 좁아 14면 마당이 찬다).

## 6. 시험

| 시험 | 결과 |
|---|---|
| `tools/story/validate_event_class.gd` | EVENTCLASS PASS checked=127 (exit 0) |
| `tools/story/validate_case_meta.gd` | CASEMETA PASS 8 warn=5 (exit 0) |
| `tests/registry/case_registry_test.gd` | REGTEST PASS 47 (exit 0) |
| `tools/story/map_leads_test.gd` | MAPLEADS PASS fixtures=53 (exit 0) |
| `tests/audio/sound_test.gd` | SOUNDTEST PASS 38 (exit 0) |
| `tests/onboarding/onboarding_rule_test.gd` | ONBOARDRULE PASS 64 (exit 0) |
| `tests/commonize/commonize_test.gd` | COMMONTEST PASS 49 (exit 0) |
| `tools/run_story_tests.sh` 전체(마지막 한 번) | **53/53 PASS**, SCRIPT ERROR 0, exit 0 — 새 `chunhyang:prep` 포함(52 → 53). 남원 v3.2 `namwon:A·B·C·onboard`·`continue:namwon-*` 그대로 통과 |

새 시험 `chunhyang:prep`(`scripts/story/prep_test.gd --preptest`, 52 확인 — `PREPTEST PASS 52`):
F-11(단오 차림: 단계 없음 → 없음·충돌체 없음, 30프레임 동안 조건식 다시 안 돎, 단계 dano → 있음·충돌체, feast → 다시 없음, 실제 상태로 → 없음, 변수 바뀐 프레임에만 한 번 다시 봄) ·
옥(사건 없이 있음, when 없음, 문·살문 기본 SEALED, OPEN이면 지나가고 SEALED면 막힘, 사건이 없어도 그대로) ·
흔적(오누이가 돌면 정적 꺼짐·사건 소품 그대로, 다른 사건 완료 전 우물+푸름, 완료 뒤 우물+붉음, 사건 없음도 같음) ·
EventCrowd(두 프리셋 선언·꺼짐, 인원 범위 low/medium/high, 같은 seed 같음·다른 seed 다름, generic만·빼는 곳 밖, 이야기 인물 그림 빠짐, when dano/feast로 하나씩, 강제 켬 인원 = 계획, 가까이 그림·움직임, 60m 밖 숨김, 화면 밖 멈춤, 멀리 가면 모두 숨김, 강제 풀면 when대로).

## 7. 화면 (`seolhwa_godot/shots/chunhyang_prep/`, git 밖 — 창 모드, `--savefile=user://chp_prep.json` 시험 저장, 찍은 뒤 지움)

| 파일 | 내용 |
|---|---|
| `01_jail_exterior.png` · `01b_jail_game_view.png` | 옥 바깥(관아 바깥마당) · 평소 걷기 시점 |
| `02_jail_12A_bars.png` | 12A — 나무살 너머 가운데 칸(춘향 그림이 없어 마을 아낙 그림으로 구도만) |
| `03_sorghum_before_complete.png` · `04_sorghum_after_complete.png` | 수수밭 완료 전 푸름 / 뒤 붉음(정적 흔적) |
| `05_well.png` | 외딴집 우물(정적 흔적) |
| `06_dano_market_1A.png` | 단오 군중 high 강제 + 단오 차림, 새 1A |
| `07_byeon_banquet_8A.png` | 잔치 군중 medium 강제 + 잔치 차림, 확정 8A |
| `08_orijeong_farewell_5A.png` | 5A 북쪽 길과 오리정 |
| `kit_ok_closed.png` · `kit_ok_open.png` | 키트 미리보기(닫힘 / 문·살문 열림) |
| `fps.json` | 위 성능 표의 원자료 |

촬영에서는 placeholder로 지어지는 차림(그네·씨름판·보계·교의·형틀·차일·수레 자리)을 숨겼다(실제 모양이 아니다).
다시 찍기: `godot --path seolhwa_godot res://scenes/region.tscn --resolution 1024x768 -- --region=JL_NAMWON_UNBONG --prepshot[=jail,bars12a,sorghum,well,dano1a,banquet8a,orijeong,fps] --nostory --notitle --shotdir=shots/chunhyang_prep --savefile=user://chp_prep.json`

## 8. 남은 것 · 사용자 판단

1. **앉기 그림**: generic bank(선비·관속·마을 사람)에 sit 프레임이 없다. 지금은 선 그림을 0.42m 낮춰 잔칫상·대청 마루가 다리를 가리게 했다(8A 높이에서는 '서 있는 키 작은 사람'에 가깝다). 잔치 손님용 sit(+출두 때 bow·kneel) 굽기가 필요하다(S, 자산 문서 §5-2).
2. **잔치 손님 그림**: bank의 `pojol`·`official`이 많이 나와 '포졸 잔치'처럼 보일 수 있다. 기생 generic(NEW) 굽기 전까지 bank 비율을 사건 코드 때 조정.
3. **수레(`ti_wine_cart`)**: `story/snow_road` cart에 upright 변형이 아직 없어 단계가 서면 엎어진 수레가 나온다(VARIANT S — 사건 코드 전에).
4. **확정 8A 틀이 좁다**(가로 약 16m): 점고 기생 8명 줄(x -3169.8~-3154.4)은 들어가지만 사령 줄(x -3177.6 / -3146.6)은 틀 밖이다. 사령 줄을 안쪽으로 당길지, 8A에서 사령은 화면 밖으로 둘지.
5. **식생 비우기**: when 항목도 식생은 늘 비운다 — 광한루 앞 잔디·관아 마당 몇 곳의 풀·덤불이 사건 전에도 없다(땅은 그대로).
6. 오리정에는 지명 이름표("오리정")만 붙였다(다가가면 뜨는 건물 이름). 원치 않으면 `title`을 지우면 된다.
