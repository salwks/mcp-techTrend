# 춘향 PART II 준비 — 공용 자세 · PART II 인물 · 잔치 군중 짜임 · PART II 소품 (2026-10-11)

근거: `chunhyang-part1.md` · `chunhyang-prep.md` · `seolhwa/docs/production/CHUNHYANG_ASSETS_PLACEMENT_v1.0.md`(§1·§2-4·§5-2, 새 §11) · `CITY_ROUTE_PRODUCTION_RULES_v1.0.md`(C60) · 춘향 v1.1 시나리오·결정.
순서대로 했다: 자세 → 인물 → 군중 → 소품. **PART II 사건 흐름(장면·대사)은 만들지 않았다** — 다음 단계. PART I은 그대로, PART II는 닫힌 채(보이는 것 없음).

## 1. 공용 자세 sit · bow · kneel (모든 사람)

| 무엇 | 어디 |
|---|---|
| 자세 정의(웹 굽기 엔진 확장 — 웹 코드 `seolhwa/src`는 고치지 않음, `hum_combat_light.js`와 같은 방식) | `tools/pose_common.js` — `installPoses(kind)` · `poseSpec`(가만히 있는 자세라 한 주기 2장, 숨쉬기) |
| sit | 양반다리(방석·마루): 엉덩이가 땅에서 한 뼘, 무릎 앞, 손은 무릎 위. 치마·두루마기 자락은 땅에 퍼짐 |
| bow | 선 채 허리를 깊이 굽힌 절(국궁): 옆은 약 45°, 앞·뒤는 몸통이 짧아지고 머리가 가슴께로(정수리·갓 챙이 보임) |
| kneel | 꿇어앉기: 발뒤꿈치 위에 앉아 몸을 앞으로 숙이고 고개를 떨굼 — 관아 마당·출두 엎드림 |
| sit_chair | 교의에 앉기(변학도만 — 그의 `sit`) |
| 모든 사람 종류 목록 | `tools/kind_specs.js` `HUMAN_BANKS`(각 굽기 파일의 차림 표를 그대로 읽음 — 차림을 두 번 적지 않음). 62종: 플레이어 · 마을 사람 9 · 고을 사람 14 · 이야기 인물(오누이·한양·황주·춘향 PART I·강릉·경주·평양·함흥·제주) · 마부 |
| 결과(git 밖) | `data/frames_pose.json` + `frames_pose_<kind>_0.png`(62장, 15MB) |
| Godot | `SpriteChar.ensure_poses(kind)` — sit·bow·kneel을 **처음 부를 때**(play·set_anim·has_anim·anim_duration) 그 종류의 클립을 은행에 더한다(페이지도 그때 읽음). **이미 그 이름의 클립이 있으면 그대로** — 춘향 PART I·책쾌·연이 등의 예전 sit 그림이 바뀌지 않는다. 별칭 `stand` = idle |
| 이야기 DSL · 군중 | `anim_actor <id> kneel` 등이 그대로 된다(story_director → SpriteChar.play). EventCrowd sit 역할은 진짜 sit |
| SIT_SINK 없앰 | `event_crowd.gd`의 `SIT_SINK 0.42`(선 그림을 낮춤)와 `sink` 자리 보정 모두 지움. 앉은 사람 높이 = 땅(또는 대청 dy) 그대로 |

다시 굽기: `python3 tools/web_export_server.py 8770` → 브라우저 `http://localhost:8770/__tools/story_bake.html?set=poses` (약 1분).
견본 확인: `…/__tools/pose_preview.html?kinds=villager_m,scholar&anims=idle,sit,bow,kneel&out=preview/poses.png`(같은 축척으로 한 장 → `data/preview/`).

## 2. PART II 인물 — 굽기 세트 `?set=chunhyang_part2`

차림 부속은 `tools/dress_art.js`(먹선·한지·평면 채색, 머리·몸통·손 부위를 따라 움직임). 결과(git 밖) `data/frames_story_chunhyang_part2.json` + `frames_story_chunhyang_part2_<kind>_<n>.png`(15장, 9MB) — `story_director.BANK_FILES`·`KIND_FALLBACK`에 연결.
다시 굽기: `…/__tools/story_bake.html?set=chunhyang_part2`.

| kind | 차림 | 동작 |
|---|---|---|
| `chunhyang_prison` | 흰 무명 저고리·치마, 풀어 헤친 머리(앞은 얼굴 양옆 가는 두 가닥, 뒤는 등까지), 목에 칼(枷 — 긴 널빤지, 쇠띠 둘, 먹 글씨 자국) | idle · walk · talk · sit · kneel · bow |
| `mongryong_beggar` | 바랜 도포 + 덧댄 누더기, 파립(챙 한 조각이 떨어져 나간 갓), 흙빛 행전. 마패는 손에 든 소품 — `mapae` 동작에서만 보임 | idle · walk · run · talk · sit · bow · kneel · **mapae** |
| `byeon` | 홍단령(둥근 깃) · 사모(날개 둘) · 흉배(학) · 각대(금 장식판), 검은 수염 | idle · walk · talk · **sit(= 교의)** · stand(=idle) · bow · kneel · cower |
| `gisaeng` · `gisaeng_b` · `gisaeng_c` | 얹은머리(땋은 타래 + 떨잠) · 회장저고리. 옥색+쪽빛 / 연분홍+자주 / 연노랑+청록 (춘향 노랑·다홍과 겹치지 않게) | idle · walk · talk · sit · bow · kneel · **serve**(술병 들고 따름) |
| 사령·포졸 | 기존 `pojol`(한양 굽기) 그대로 — bow·kneel은 1의 공용 자세로 생김(시험 확인) | |

## 3. 잔치 군중 짜임 · 고정 자리 · 자세 바꾸기

### byeon_banquet (14 — 손님 8 · 기생 4 · 시중 2)

| 구역 | 짜임(`rect_roles` — 역할:묶음) |
|---|---|
| A 안마당 서 | sit:guest ×3(잔칫상 방석) · serve:gisaeng |
| B 안마당 동 | sit:guest ×3 · serve:gisaeng |
| C 대청 | sit:guest ×2 · sit:gisaeng ×2(손님 곁) — 동헌 가운데 열린 칸만(분합문 칸은 벽 뒤라 촬영에서 안 보였다 → 옮김) |
| D 동헌 서쪽 곁 | serve:servant ×2 |

- `banks`: guest = scholar · py_clerk · elder / gisaeng = 세 색 / servant = villager_m · villager_f. 묶음 안에서 seed로 시작해 돌아가며 고른다(같은 색 기생이 몰리지 않음). **포졸·관속은 군중에서 뺐다**(bank에도 없음).
- `seats`: sit은 정해진 자리·방향(손님은 상을 보고 가운데 통로 쪽). 단오 군중(PART I)은 예전 길(roles 비율 + bank) 그대로 — 28명 배치 불변.
- 묶음 이름이 사람의 `tag`가 된다(set_pose 고르기에 씀).

### 사령·포졸 고정 자리 (이야기 인물)

`story/namwon_chunhyang/namwon_chunhyang_data.gd` `guard_posts()`(actors에 포함): 사령 8(공식 8A 양옆 줄 `ch_saryeong_w0~3`·`e0~3`, 서쪽 줄은 축을, 동쪽 줄은 서쪽을 봄) + 선임 사령(`ch_saryeong_e4`) + 외삼문 포졸(`ch_gate_guard`). CHR_HUM_016 · pojol · tags `saryeong`/`row_w|e`/`senior`/`pojol`. `when` = office · feast · reveal(포졸은 office · jail · feast) — PART II가 닫혀 있어 지금은 서지 않는다.

### 자세 바꾸기 API (출두 반전 — 같은 사람, 제자리)

- `EventCrowd.set_pose(crowd_id, filter, pose)` — filter: 역할 · tag · kind · 그 배열 · ""(모두). 노드·자리·그림은 그대로, 오가던 사람은 그 자리에서 멈춤. 돌려주는 값 = 바뀐 수.
- `EventCrowd.apply_on_flag(crowd_id, flag)` — 선언의 `on_flag`(`royal_inspector_reveal`: sit→kneel, stand/serve/watch→bow). `clear_pose(crowd_id, filter)`로 원래 동작.
- `story_director.set_pose(filter, pose)` — 이야기 인물: id 배열 · glob(`"saryeong_*"`) · tags. 같은 노드, 단계가 바뀌어도 제자리 자세로 되돌리지 않음(scripted). 바뀐 id 목록을 돌려줌.

## 4. PART II 소품 (키트 `story/chunhyang` 새 kind + 수레 variant)

| 배치 id | 키트 | 단계(F-11 when) |
|---|---|---|
| `ti_dais` | `dais` 보계 7×2×1.05 — 기둥·귀틀·밝은 새 마루널·가림 판·앞 계단 셋, 충돌체 | office · jail · feast · reveal |
| `ti_seat_screen` | `seat_screen` 교의(붉은 옻칠·붉은 방석·발받침) + 병풍 여덟 폭(먹 산수 띠), dy 1.05 | 같음 |
| `ti_hyeongteul` | `hyeongteul` 형틀(묶는 새끼 둘) + 곤장 둘(곁에 눕힘) — 놓여 있기만 | office |
| `ti_chail` | `chail` 18×8×4.6 — 흰 천(가운데 살짝 처짐·가장자리 붉은/푸른 술), 장대 여섯은 **짧은 변에 셋씩**(가운데 축·보계에 장대 없음 — 첫 촬영에서 장대가 보계 한가운데 섰다 → 고침), 당김줄·말뚝. 상태 `cloth` SPREAD(기본)/FURLED(양쪽 가로대에 말아 올림) | feast · reveal |
| `ti_feast_w0~e2` · `ti_jansang_hall_w/e`(새) | `jansang` 손님 독상(그릇·떡 괸 것·술병·잔) + 방석. 대청 둘은 `rich`(붉은 방석). 사령 줄 안쪽 x -3166.9 / -3157.3 | feast · reveal |
| `ti_jusang_dais_w/e` | 기존 `jusang` — dy 1.05(보계 위)로 고침 | feast · reveal |
| `ti_wine_cart` | `story/snow_road cart upright` — 바로 선 수레(두 바퀴·살·끌채를 앞 땅에) + 술독 셋 + 새끼 | office · jail |
| 옥 | 기존 `ok` 그대로 | 늘 |

배치 고침(PART II용, 지금은 꺼져 있음): §42 서안·벼루·`ch_poem_table`·17A를 (-3165.7, 212.0)으로(손님 자리와 겹침), `ch_byeon_seat` z 206.9(교의 앞 0.3m — 앉은 그림이 교의에 가리지 않게).

## 5. 시험 (차례로 한 번씩, 동시에 돌리지 않음)

| 시험 | 결과 |
|---|---|
| `validate_event_class` | EVENTCLASS PASS checked=145 (exit 0) |
| `validate_case_meta` | CASEMETA PASS 9 warn=5 (exit 0) |
| `case_registry_test` | REGTEST PASS 47 (exit 0) |
| `map_leads_test` | MAPLEADS PASS fixtures=61 (exit 0) |
| `sound_test` | SOUNDTEST PASS 42 (exit 0) |
| `onboarding_rule_test` | ONBOARDRULE PASS 64 (exit 0) |
| `commonize_test` | COMMONTEST PASS 49 (exit 0) |
| `chunhyang:prep` | PREPTEST PASS 65 (처음 한 번 FAIL — 옮긴 손님 자리가 §42 서안 빼는 곳에 들어감 → 서안을 옮기고 PASS) |
| `chunhyang:part2prep`(새) | PREPTEST PASS 61 (part2 prep) |
| `tools/run_story_tests.sh` 전체(마지막 한 번) | **57/57 PASS**, SCRIPT ERROR 0, exit 0 — 새 `chunhyang:part2prep` 포함(56 → 57). `namwon_chunhyang:a` 88 · `b` 79 · `after` 16 · `chunhyang:prep` 65 그대로 |

새 시험 `chunhyang:part2prep`(`scripts/story/part2_prep_test.gd --p2preptest`, prep_test를 이어 씀): 고을 사람 15종·이야기 인물 11종 sit·bow·kneel 앞·옆·뒤 + kneel 그림 · 춘향 PART I sit 클립 불변 · stand 별칭 · PART II 차림 여섯의 동작 · 변학도 sit이 선 키보다 낮음 · SIT_SINK 상수·코드 없음 · 잔치 14 = 손님 8·기생 4·시중 2, 포졸·관속 없음(계획·bank), 기생 세 색, 앉은 사람 10 모두 방석 자리 · 같은 seed 같은 짜임 · 단오 28 그대로 · 8A에서 14명 그림, 앉은 사람 진짜 sit·높이 그대로 · apply_on_flag 14명 → **같은 노드 id·그림·자리**, sit→kneel·나머지→bow, 바뀐 시중·기생은 멈춤 · tag/배열 고르기 · clear_pose 뒤에도 같은 노드 · 이야기 인물 set_pose(tag·glob·배열, 같은 노드·자리) · 사령 고정 자리 10(앵커·pojol·PART II 단계·방향) · 새 kind 다섯·수레·차일 상태 · PART II 소품 실제 키트(placeholder 아님) · 닫힘 → 모두 없음 · office 강제 → 보계·교의·형틀·수레만 · feast 강제 → 보계·교의·차일·잔칫상, 형틀 없음 · 차일 FURLED · 실제 상태 → 다시 없음.

## 6. 화면 (`seolhwa_godot/shots/chunhyang_part2_prep/`, git 밖 — 창 모드 1024×768(레티나 2048×1536), 시험 저장 `user://chp_p2prep.json`, 찍은 뒤 지움)

| 파일 | 내용 |
|---|---|
| `01_pose_sheet_front.png` · `01b_pose_sheet_side.png` · `01c_pose_sheet_8A_distance.png` | 공용 자세 한 장(줄: idle·sit·bow·kneel / 칸: 마을 남·여·선비·노인·농부·관속·포졸·아이) — 평소 걷기 거리와 8A 높이·거리 |
| `02_look_chunhyang_prison.png` · `03_look_mongryong_beggar.png` · `04_look_byeon.png` · `05_look_gisaeng.png` | 새 차림 넷(앞·옆, 동작별) |
| `06_8A_banquet_seated.png` | 공식 8A, feast 강제 — 손님 독상에 앉음 · 대청 손님·기생 · 변학도 교의 · 사령 양옆 줄(대신 선 그림 — 고정 자리와 같은 앵커) · 차일 FURLED |
| `07_8A_after_set_pose.png` | 같은 틀, apply_on_flag 뒤 — 같은 사람이 꿇음·절, 사령 kneel, 변학도 cower |
| `06b_court_close_seated.png` · `07b_court_close_after.png` | 안마당 가까이(10A 높이) 앞·뒤 |
| `08_8A_chail_spread.png` | 차일을 편 8A(천이 안마당을 덮음 — 판단 1) |
| `09_8A_office_hyeongteul.png` | office 강제 — 보계·교의·형틀, 칼 쓴 춘향 kneel |
| `10_wine_cart_upright.png` | 외삼문 동쪽 술 수레 |
| `kit_dais.png` · `kit_seat_screen.png` · `kit_hyeongteul.png` · `kit_chail.png` · `kit_chail_furled.png` · `kit_jansang.png` · `kit_wine_cart_upright.png` | 키트 미리보기 |

보고 고친 것: 앞모습 절이 팔짱 낀 선 사람처럼 보임 → 몸통을 더 줄이고 머리를 가슴께까지(정수리·갓 챙이 보임) · 옆 앉음 종아리가 땅 밑으로 → 땅을 따라 접음 · 두루마기 자락이 땅 밑으로 → 짧게 · 앞 꿇음이 "다리 벌린 작은 사람" → 무릎만 짧게 · 기생 얹은머리가 줄무늬 모자 같음 → 땋은 고리 두 줄 · 사모 옆모습이 원뿔 → 낮은 앞 산 + 뒤 둥근 산 · 춘향 옥 앞머리가 얼굴을 덮는 장막 → 가는 두 가닥 · 대청 손님이 분합문 벽 뒤에 숨음 → 가운데 열린 칸으로 · 차일 가운데 장대가 보계 한가운데 → 짧은 변으로 · 변학도가 교의 뒤에 묻힘 → 자리 앞 0.3m.

다시 찍기:
- `godot --path seolhwa_godot res://scenes/region.tscn --resolution 1024x768 -- --region=JL_NAMWON_UNBONG --p2prepshot[=poses,looks,banquet] --nostory --notitle --shotdir=shots/chunhyang_part2_prep --savefile=user://chp_p2prep.json`
- 키트: `godot --path seolhwa_godot res://scenes/kit_preview.tscn -- --kit=res://kit/story/chunhyang.gd --params='{"kind":"chail"}' --state=cloth:FURLED --shot=…`

## 7. 판단이 필요한 것

1. **차일과 8A**: 차일(18×8, 높이 4.6, 반투명 금지)을 펴면 8A(높이 약 18m)에서 안마당 전체가 흰 천에 덮인다(`08_8A_chail_spread.png`). 상태 FURLED(양쪽에 말아 올림)를 만들어 두었다 — 사건 코드에서 8A 컷 동안 FURLED로 둘지, 차일을 보계·대청 앞만 덮게 줄일지, 8A에서만 차일을 숨길지.
2. **잔칫상 형식**: 큰 멍석 차림(`story/clue feast`, 4.6×2.6 — 사령 줄과 겹침) 대신 손님마다 독상(`jansang`)으로 바꿨다. 사령 줄(±6.6m)과 상 줄(±4.8m) 사이가 1.2m라 좁다.
3. **춘향 옥 차림의 인상**: 흰 옷 + 풀어 헤친 긴 머리는 원귀 이미지와 겹친다. 칼(널빤지)이 구별해 주지만, 머리를 반쯤 묶은 모양으로 바꿀지.
4. **변학도 sit = 교의**: 그의 `sit`은 의자 자세다(바닥 앉기 없음). 출두 때 자세는 `cower`(웅크림)로 찍었다 — 시나리오대로 달아나기·숨기를 쓸지는 사건 코드에서.
5. **예전 sit과 새 sit의 차이**: 이미 sit이 있던 이야기 인물(춘향 PART I·책쾌·연이·장님 노인·숯쟁이·이겸·곽·전령)은 예전(다리를 앞으로 뻗은) sit을 그대로 쓴다(그림 불변 원칙). 모두 양반다리로 맞추려면 그 세트를 다시 구워야 한다.
6. 굽기 확인은 앱 브라우저 창에서 했다(머리 없는 Brave는 큰 묶음에서 멈춤).
