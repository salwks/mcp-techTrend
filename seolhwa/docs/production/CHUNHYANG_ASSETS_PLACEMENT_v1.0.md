# 춘향 「남원의 약속」 — 자산 목록 · 남원 실제 좌표 배치 v1.0 (2026-10-11)

> 사건 id `namwon_chunhyang`. 착수 순서(결정 문서 「착수 순서」·시나리오 §60)의 2·3단계 — **자산 목록과 남원 좌표 배치**만 한다.
> 사건 코드(`namwon_chunhyang_case.gd`)와 `EventCrowd` 구현은 다음 단계다.
>
> 기준: `seolhwa/docs/scenario/seolhwarok_NAMWON_CHUNHYANG_v1.1_scenario.md` · `…_v1.1_DECISIONS.md` ·
> `seolhwa/docs/production/CITY_ROUTE_PRODUCTION_RULES_v1.0.md`(E절 설화 층 계약 · C60 EventCrowd · G절) ·
> `seolhwa_godot/docs/reports/multi-case-registry.md` · `commonize-1.md` · `namwon-v32.md`.
>
> 좌표·배치 초안 데이터: `seolhwa_godot/region_data/JL_NAMWON_UNBONG/placement_story_namwon_chunhyang.json`
> (앵커 68 · 사건 차림 44 · 군중 2 · 카메라 12 — **`items`는 비어 있어 놀이에 보이지 않는다**, §6).
> 스크린숏: `seolhwa_godot/shots/chunhyang_plan/`(git 제외 폴더, §7).

좌표는 게임 좌표 `(x, z)`(m, +z = 남쪽, K=0.30 축척). 높이는 모두 지형(`y: null`) — 남원 읍내·광한루 일대는 y ≈ 11.1~12.5로 평탄하다(height.png 표본).

---

## 0. 요약

| 구분 | EXISTS | REUSE / VARIANT | NEW | 합 |
|---|---:|---:|---:|---:|
| 인물(고유 6명 · 외형 8벌) | 0 | 0 | 6명(8벌) | 6 |
| 인물(generic bank 역할) | 12 | 2(어사 수행원 · 아전) | 1(기생 generic) | 15 |
| 공간(건물·무대 — §2-1 표의 줄) | 8 | 4 | 5(그네 · 씨름판 · 관아 단(보계) · 교의+병풍 · 옥) | 17 |
| 소품(단오 · 추수 · 잔치 · 연출 — §2-2~2-4, §2-1과 겹치는 줄·인물 부속 제외) | 18 | 3 | 5(방자 부채 · 형틀 · 차일 · 가마 · 악기(선택)) | 26 |
| **합** | **38** | **9** | **17** | **64** |

크기 합(NEW·VARIANT): 인물 M 2 · S 6(기생 포함) / 공간 M 2(그네 · 옥) · S 3 / 소품 M 1(가마) · S 7. 칼(枷)·마패·파립·관복·사모는 인물 부속으로 인물 크기에 넣었다.

- 가장 큰 빈자리: **① 관아 안마당이 얕다**(동헌 기단 앞 ~ 내삼문 footprint 8.7m — 8A에서 내삼문 지붕이 화면 아래 1/3을 덮는다) · **② 옥이 남원 어디에도 없다** · **③ 한 공간에 사건 하나만 활성** — 춘향이 서는 순간 오누이 사건 소품(외딴집 우물·붉은 수수밭)과 주모·포수 등이 사라진다 · ④ 배치 로더가 `when`을 모른다(F-11) · ⑤ 변학도 관복·사모, 기생 generic이 없다.
- 사용자 결정이 필요한 것은 §8에 모았다(관아 마당 깊이 · 옥 자리 · 월매 집 · 그네 자리 · 오리정 · 오누이 잔존물 처리).

---

## 1. 인물

### 1-1. 고유 외형 6명 (결정 6 · 시나리오 §54-1)

굽기 방식은 기존 그대로다: `seolhwa_godot/tools/export_story_frames.js`에 `SETS.namwon_chunhyang`을 더하고(웹 굽기 엔진 `frameCore.BakeBank`, 기존 rig `villager_m`·`villager_f` 바탕 + `over` 색·부속), 결과 `data/frames_story_namwon_chunhyang.json`을 `story_director.BANK_FILES`·`KIND_FALLBACK`에 잇는다(우치·책쾌·포졸·연이와 같은 길). 그림체는 기존 먹선 + 한지빛 테두리(halo) + 평면 채색, 세 시점(앞·옆·뒤) 프레임. 얼굴 클로즈업이 없는 편이므로(§6 "몸을 훑는 클로즈업을 하지 않는다", §36 "정면 클로즈업 금지") **실루엣과 색으로 읽히게** 만든다.

| 인물 | kind(제안) | 바탕 rig · 기존 부속 | 외형 메모 | 동작(기존 / 새) | 상태 · 크기 |
|---|---|---|---|---|---|
| 성춘향 | `chunhyang` | `villager_f` · `hair:'braid'`+`ribbon`(황주 연이와 같은 부속) | PART I 단오: 노랑 저고리 · 다홍 치마 · 붉은 댕기, 키 1.55 · build 0.88. 멀리서 그네 위에서도 읽히는 **다홍 치맛자락**. PART II 옥: 흰 무명 옷 · 머리 풀어 늘어뜨림 · 목에 칼(枷) | idle·walk·talk·sit·cower·tied(기존) / **swing_stand**(그네 발판 위 선 자세 — 몸은 발판에 실려 움직이고 프레임은 무릎 굽힘 2장) · **kneel**(관아 마당) | NEW · **M** (외형 2벌 + 새 부속 `hair:'loose'`·`neck:'cangue'` + 동작 2) |
| 이몽룡(평복) | `mongryong` | `villager_m` · `top:'durumagi'` · `hat:'gat'` | 옥색 도포 · 갓 · 수염 없음 · build 0.95 · 키 1.68 — 젊은 양반 자제 | idle·walk·run·talk·sit | NEW · **S** |
| 이몽룡(거지 차림) | `mongryong_beggar` | 같은 몸 · `patch` · `legwrap` | 해진 도포(누더기 덧댐) · **찢어진 갓(파립)** · 흙빛. 출두 뒤 **마패**가 옷 위로 보인다(§44) | 위와 같음 + sit(시 쓰기) | NEW · **S** (새 부속 `hat:'parip'`·`badge:'mapae'`) |
| 방자 | `bangja` | `villager_m` · `hat:'beonggeoji'` · `top:'short'` | 짧은 저고리·잠방이 · 벙거지 · 손에 부채(§5 떨어뜨림 — 소품 S) · build 1.0, 장난스러운 볼(cheek) | idle·walk·run·talk | NEW · **S** |
| 월매 | `wolmae` | `villager_f` · `hair:'jjok'` | 퇴기 — 쪽머리에 은비녀, 옥색 비단 저고리 · 남치마(아낙보다 고운 색) · 키 1.56 · build 1.0. PART II 옥 음식: `carry:'basket'`(기존) | idle·walk·talk·cry·hug(기존) | NEW · **S** |
| 변학도 | `byeon` | `villager_m` 몸 | **관복(단령) + 사모 + 흉배 · 각대** — 지금 painter에 없다. 수염 · build 1.15 | idle·walk·talk·sit(교의) | NEW · **M** (새 부속 `top:'dallyeong'`·`hat:'samo'`) |
| 향단 | `hyangdan` | `villager_f` · `hair:'braid'` | 무명 저고리 · 쪽빛 치마 · 붉지 않은 댕기(춘향과 구별) · 키 1.48 | idle·walk·talk | NEW · **S** |

### 1-2. generic bank 재사용 (결정 6 — 고유 외형을 만들지 않는 역할)

CHR id는 `seolhwarok_CHARACTER_MASTER_v1.3.md`, kind는 지금 쓰는 프레임 은행(`data/frames_*.json`) 이름이다.

| 역할 | CHR id | 쓸 kind(은행) | 상태 | 메모 |
|---|---|---|---|---|
| 이방(吏房) | CHR_HUM_004 관리 | `official`(frames_amb) | EXISTS | §22 단 곁. 이름만 "이방" |
| 아전(§20 알아보는 자) | CHR_HUM_004 | `py_clerk`(frames_pyongyang — 서리 차림) | REUSE | 평양 은행이 이미 `BANK_FILES`에 있음. 이방과 구별되게 |
| 사령 · 선임 사령 · 포졸 | CHR_HUM_016 포졸 | `pojol`(frames_story_hanyang — 벙거지·검은 쾌자·붉은 띠·긴 막대) | EXISTS | 점고 줄·곤장·옥문·행렬 앞. 선임은 이름만 |
| 어사 수행원(역졸) | CHR_HUM_016 | `pojol` + `courier_b`(frames_story_hamhung) 섞기 | REUSE | 육모방망이 대신 막대 — 마패는 몽룡만 |
| 장터 군중(남·여) | CHR_HUM_028 · 029 | `villager_m`·`peddler` / `villager_f`·`farmwife` | EXISTS | 강릉 `crowd_a/b`와 같은 매핑 |
| 아이(그네 곁 · 끝 장면) | CHR_HUM_020 · 021 | `child_boy` · `child_girl` | EXISTS | §49 아이 둘 |
| 노인(나무 그늘 · 상소 노인) | CHR_HUM_022 | `elder` | EXISTS | §34 상소 노인은 story actor |
| 노파 | CHR_HUM_023 | `villager_f` | EXISTS | 노파 전용 그림 없음(남원 오누이와 같음) |
| 농민(§33 쌀) | CHR_HUM_009 | `farmer` | EXISTS | story actor |
| 술 상인(§32) | CHR_HUM_002 | `merchant` | EXISTS | story actor |
| 보부상 · 엿장수 | CHR_HUM_003 | `peddler` | EXISTS | 엿판은 소품 |
| 잔치 손님(고을 수령들) | CHR_HUM_024 양반 남성 | `scholar`(frames_amb) | EXISTS | 대청 위 앉기(군중 sit, dy 1.05) |
| 짐꾼 · 가마꾼 | CHR_HUM_027 | `woodcutter`(지게) · `villager_m` | EXISTS | §19 행렬 뒤 짐 |
| 하인 · 잔치 시중 | CHR_HUM_026 | `villager_m` / `villager_f` | EXISTS | 군중 serve |
| **기생(점고 6~8 · 잔치)** | — (마스터에 없음) | **`gisaeng`** = `villager_f` 변형(얹은머리·회장저고리·쪽빛/자줏빛 치마, 3색 순환) | **NEW generic · S** | 고유 인물이 아니라 군중용 묶음. 결정 6 "고유 6명"을 늘리지 않는다 |

악공(잔치 음악)은 `villager_m`에 악기 소품(장구·피리 — NEW S, 선택)으로 둔다.

---

## 2. 공간 · 소품

표기: **EXISTS** 그대로(경로) · **REUSE/VARIANT** 기존 키트의 다른 params·작은 변형 · **NEW** 새로 만든다. 크기: S ≤ 1일 · M 2~3일 · L 5~8일(제작 규칙 F절 기준).
NEW 키트는 하나의 묶음 키트 `kit/story/chunhyang.gd`(kind로 고름 — `story/tale`·`story/ritual`과 같은 형식)로 제안한다.

### 2-1. 공간

| 공간 | 상태 | 경로 · 자리 | 크기 | 메모 |
|---|---|---|---|---|
| 광한루(본루 + 익루) | **EXISTS** | `kit/landmark/gwanghallu.gd` · `nw_gwanghallu` (-3271.4, 450.1) footprint 30×14.4 | — | OSM 위치 확정. 2층 헌함이 있어 몽룡 자리로 쓸 수 있다(1B는 땅 위 서쪽 끝으로 둠 — §4) |
| 광한루원 못 · 삼신산 · 오작교 | **EXISTS** | `kit/landmark/gwanghallu_pond.gd` · `nw_gwanghallu_pond` (-3279, 483) 물 84×40 | — | §13 장면 B(오작교 -3283.4, 459.4) |
| 광한루 앞 잔디(단오 마당) | **EXISTS**(땅) | landuse 풀밭 x -3335~-3255 · z 422~470 | — | 식생만 비운다(`story/clearing` 66×17) |
| 남문 밖 장터 | **EXISTS** | `nw_shop_*`·`nw_jwapan_*`(남원 장터, 가게채 줄 z≈386 · 좌판 줄 z≈398·405) | — | settlement `namwon_jang` (-3293.1, 374.8) |
| **그네(단오 그넷대)** | **NEW** | `story/chunhyang` kind `swing` @ (-3330, 444) | **M** | 장대 둘(8.5m) + 들보 + 동아줄 둘 + 발판 + 오색 천. 발판이 z 방향으로 흔들린다(누각·1B 시점에서 옆으로 오르내림이 읽힘). state `SWING`/`EMPTY`(§49 빈 그네). 춘향 actor는 발판에 실린다(dy·회전 따라감) |
| 그네 나무(버드나무 둘) | **EXISTS** | `nature/big_tree` variant `willow` @ (-3338.5, 446) · (-3321.5, 446.5) | — | "멀리 나무 사이 그네"(§6) — 시험 촬영 02에서 확인 |
| **씨름판** | **NEW** | `story/chunhyang` kind `ssireum_ring` @ (-3292, 431) | **S** | 모래판 지름 7m + 짚 둘레. 사람은 군중 watch |
| 월매 집 | **REUSE** | `nw_house_158` (-3212.99, 449.82) — 작은 집 묶음 · 기와 안채 · 초가 헛간 · 토담 · 대문 남향 | — | 광한루 동쪽 45m, 구례길 건너. 남쪽 23m가 나루 주막(§10 "주막 가는 길"과 맞는다). 마당 약 12×7m(시험 촬영 03) |
| **월매 집 연출 구역** | **REUSE + NEW 소품** | 마당 평상 · 대문 등롱 · 대문 곁 꽃 · (P2) 감나무 | **S** | 실내는 없다(대화·백년가약은 마당과 대문 앞) |
| 객사 용성관 · 읍성 · 남문 | **EXISTS** | `nw_gaeksa` · `nw_eupseong` · 남문 완월루(-3227.8, 341.7) | — | §19 행렬 · ACT14 남문 |
| 관아(외삼문 · 내삼문 · 동헌 · 내아 · 담) | **EXISTS** | `nw_gwana_oesammun`(-3162.1, 239.5) · `nw_gwana_naesammun`(-3162.1, 219.5) · `nw_dongheon`(-3162.1, 203.5, 7칸, 마루 높이 F 1.05) · `nw_naea` · `nw_gwana_wall_00~25`(x -3182.6~-3141.6 · z 164~239.5) | — | 안마당 깊이가 문제(§5 빈자리 1) |
| **관아 단(보계 補階)** | **NEW** | `story/chunhyang` kind `dais` 7×2m · 높이 1.05 @ (-3162.1, 209.0) | **S** | 동헌 대청 높이로 앞에 덧댄 나무 단 + 앞 계단(잔치 때 실제로 쓰던 보계). 동헌 처마 밑 0.8m 겹침은 의도 |
| 교의 + 병풍 | **NEW** | kind `seat_screen` @ (-3162.1, 206.6) dy 1.05 | **S** | 변학도 자리 |
| **옥(원옥)** | **NEW** | kind `ok` 둥근 담 지름 10m · 3칸 옥사 · 나무살 · 동쪽 문 @ (-3175, 229.5) | **M** | 관아 바깥마당 서쪽 반(§8 결정 2). 살 state `SEALED`/`OPEN` |
| 동문 밖 농가(§33 쌀) | **REUSE** | `nw_house_001`(중간 집 묶음) (-3109.36, 263.28) | — | 동문 30m 밖, 통영별로 곁 |
| 북쪽 전주길(§16 이별) | **EXISTS** | `namwon_north_road` 곧은 구간 x≈-3212, z 51 → -39 · 광치천 징검다리(-3218.1, -50.7) | — | 시험 촬영 08 |
| 오리정(五里亭) | **REUSE(선택)** | `village/jeongja` plain @ (-3203.5, -10) | — | 원작 이별 지명. 결정 문서에 없음 → §8 결정 5 |

### 2-2. PART I 단오 차림 (광한루·장터 둘레만 — 결정 3)

| 소품 | 상태 | 키트 · params | 자리 | 크기 |
|---|---|---|---|---|
| 그네 · 그네 나무 둘 | NEW · EXISTS | 위 2-1 | 광한루원 북서 | M |
| 색천(오색 천 줄) ×3 | **EXISTS** | `story/ritual` kind `streamers`(강릉 단오 키트) | 장터길 가로(-3268.2, 392.6 ry 90°) · 단오 마당 북쪽(-3297, 423.6) · 광한루 드는 길목(-3249.5, 446 ry 90°) | — |
| 씨름판 | NEW | `story/chunhyang` `ssireum_ring` | (-3292, 431) | S |
| 장터(좌판·가게) | EXISTS | 허브 배치 그대로 + 단오 좌판 둘(`village/jwapan` cloth·mixed) | (-3320.5, 426) · 엿판 (-3272.5, 425) | — |
| 엿장수 판 | **VARIANT** | `village/jwapan` goods `yeot`(엿판·엿가위) — 지금은 `mixed` | (-3272.5, 425) | S |
| 노인 평상(나무 그늘) | EXISTS | `village/props` kind `pyeongsang` | (-3317, 437.5) | — |
| 방자 부채(떨어뜨림) | NEW | 들고 다니는 소품(인물 부속) + 바닥 소품 1 | §5 | S |
| 방자가 드는 술병·음식(§10) | **EXISTS** | `scenario/props` `jusang`을 들고 가는 연출 — 새 아이템 시스템 아님 | — | — |
| 월매 집 등롱(밤) | EXISTS | `story/river` kind `lantern` | (-3209.6, 458.2) | — |
| 월매 집 마당 평상 · 대문 곁 꽃 | EXISTS | `village/props pyeongsang` · `nature/flowers` | (-3213, 451.6) · (-3219, 459) | — |

### 2-3. PART II 추수 차림 (관아·읍성 둘레만 — 결정 3, 숲 단풍 없음)

| 소품 | 상태 | 키트 · params | 자리 | 크기 |
|---|---|---|---|---|
| 곡식 가마니 | **EXISTS** | `scenario/props` kind `gamani`(NORMAL/BROKEN/BURNT) | 바깥마당 동쪽 물자(-3150.5, 228) · (-3147.6, 230.6) · 농가 대문 앞(-3103, 273.2) | — |
| 볏단 더미 | **EXISTS** | `village/props` kind `byeotdan` | 동문 안 길가(-3140.5, 252.5) · 남문 밖(-3219.5, 347.6) | — |
| 멍석에 곡식 널기 | **EXISTS** | `village/props` kind `meongseok` | 바깥마당(-3146.2, 223.2) | — |
| 짚가리 | **EXISTS** | `village/haystack` | 농가 곁(-3122.5, 252) | — |
| 감나무(열매) | **EXISTS** | `nature/persimmon`(= big_tree persimmon, `fruit`) | 관아 바깥마당 동남(-3145.6, 235.6) · 농가(-3123.5, 258) · 월매 집 곁(-3225, 443) | — |
| 술독(잔치용) | **EXISTS** | `village/props` kind `dok` n 4 · `scenario/props` `jangdok` | 바깥마당(-3154.8, 225.6) · 동헌 서쪽(-3179.6, 206) | — |
| 짐수레(술 상인) | **VARIANT** | `story/snow_road` kind `cart` — 지금은 엎어진 수레뿐 → `upright` | 외삼문 동쪽 길가(-3146.5, 249) | S |
| 들판 벼 색 | **하지 않음** | `farm.gd --farmseason=autumn`은 전역 디버그 스위치 | — | C31: 숲·들 전체 색 변경 금지 |
| 단오 장식 철거 | — | PART I 소품은 `when`으로 사라진다 | — | — |

### 2-4. 관아 · 옥 · 잔치 · 출두 소품

| 소품 | 상태 | 키트 | 자리 | 크기 |
|---|---|---|---|---|
| 보계(관아 단) · 교의+병풍 | NEW | `story/chunhyang` `dais` · `seat_screen` | §2-1 | S · S |
| 곤장 형틀 + 곤장 | NEW | `story/chunhyang` `hyeongteul` | (-3162.1, 215.4) | S — 놓여 있기만, 타격은 소리(§28·§52) |
| 옥(둥근 담 · 옥사 · 살) | NEW | `story/chunhyang` `ok` | (-3175, 229.5) | M |
| 옥 등롱(밤) | EXISTS | `story/river` `lantern` | (-3169.4, 231.4) | — |
| 춘향 목의 칼(枷) | NEW | 인물 부속(1-1) | — | (춘향 M에 포함) |
| 아전 목패 · 명령서(종이) | **EXISTS** | `scenario/props` `jangbu`·`munseoham` / 들고 다니는 연출 | — | — |
| 잔치 차일(흰 천 지붕, 장대 여섯) | NEW | `story/chunhyang` `chail` 18×8 · 높이 4.6 | 안마당 위(-3162.1, 213.8) | S |
| 잔칫상 ×6 | **EXISTS** | `story/clue` kind `feast` | 안마당 양옆 x -3176.4 / -3147.8, z 210.6·213.2·215.8 | — |
| 대청 위 술상 ×2 | **EXISTS** | `scenario/props` `jusang` dy 1.05 | (-3165, 208.9) · (-3159.2, 208.9) | — |
| 시 쓰는 서안 · 붓·벼루 | **EXISTS** | `scenario/props` `chaeksang` · `meoktong` | (-3168, 213) | — |
| 술잔 | EXISTS | `scenario/props` `chatjan`/`jusang` 안 | — | — |
| 마패 | NEW | 몽룡 부속(1-1) | — | S |
| 가마(사또 행렬) | **NEW** | `story/chunhyang` `gama` — 가마꾼 넷 actor 사이에 매달려 경로를 따라 움직이는 소품 | §19 | M |
| 행렬 짐 | EXISTS | 짐꾼(지게) 인물 | — | — |
| 관아 문 열림(§44 "정문이 열린다") | **VARIANT** | `landmark/samun`에 판문 state `SEALED`/`OPEN` — 지금은 늘 열린 모양 | 외삼문 · 내삼문 | S |
| 악기(장구·피리) | NEW(선택) | 악공 부속 | (-3177.6, 203.5) | S |

---

## 3. 남원 실제 좌표 배치

### 3-1. 원칙

- 새 건물을 짓기보다 **기존 허브 배치(`placement_namwon.json`)의 건물·빈터를 무대로 쓴다**. 허브 배치 파일은 고치지 않는다(E절 원칙).
- 새 자리는 (1) 기존 배치 footprint와 겹치지 않고(AABB 검사 — 의도한 겹침 2건만 남음, 아래), (2) landuse가 풀밭·마을 터·길인 곳(논 위에 군중을 세우지 않음), (3) 오누이 v3.2 앵커·무대와 떨어진 곳으로 골랐다.
- 겹침 검사(생성 스크립트, 허브·동부·오누이·역참 배치 1,862항목 대상): 남은 겹침은 `ti_wolmae_bench`(집 묶음 **마당 안**에 놓은 평상 — 시험 촬영 03에서 건물과 안 닿음 확인)와 `ti_dais`(동헌 처마 밑 0.8m — 기단에 붙인 의도) 둘뿐이다.

### 3-2. 장면 → 앵커 표

"근거"가 기존이면 배치 id/region.json 항목, 새면 고른 이유. 전체 68개는 데이터 `anchors`에 있다(기생 8 · 사령 8 포함).

**PART I**

| 장면 | 앵커 id | (x, z) | 근거 |
|---|---|---|---|
| ACT0 장터 · 군중 | `ch_market` | (-3290, 392.5) | 기존 장터길 — 가게채 줄(z≈386)과 좌판 줄(z≈398) 사이 |
| ACT0 씨름판 | `ch_ssireum` | (-3292, 431) | 새 — 광한루 앞 잔디 가운데 |
| §4 CAMERA 1A 겨냥 · ACT22 | `ch_gwanghallu` | (-3271.4, 450.1) | 기존 `nw_gwanghallu`(OSM 확정) |
| §5 몽룡·방자 / §9 / §49 | `ch_gwanghallu_front` | (-3271.4, 437) | 새 — 누각 footprint 북쪽 끝(442.9)에서 5.9m |
| §5 방자와 부딪힘 | `ch_bangja_bump` | (-3264, 432) | 새 — 잔디 동쪽(군중 비움 구역 안) |
| §6 CAMERA 1B 몽룡 | `ch_mong_view` | (-3291, 447.5) | 새 — 누각 서쪽 끝 4.6m · 못 footprint(z ≥ 454) 밖 |
| §6 그네 · §49 빈 그네 | `ch_swing` | (-3330, 444) | 새 — 광한루원 북서 풀밭(y 11.1), 누각에서 서쪽 44m |
| §8 CAMERA 2A | `ch_swing_land` · `ch_hyangdan` | (-3325, 438.5) · (-3327.6, 439.2) | 새 — 그네 앞 |
| §10 주막 가는 길 | `ch_jumak_naru` | (-3206.9, 484.2) | 기존 `nw_jumak_naru` |
| §10·§13C 월매 집 앞 | `ch_wolmae_front` | (-3216, 459.8) | 새 — 대문 앞 서남, 구례길과 사이 |
| §11·§24·§37 월매가 문을 연다 | `ch_wolmae_gate` | (-3213, 457.2) | `nw_house_158` 대문(키트 `gate_gate_out`, +z) |
| §14 백년가약(밤) | `ch_wolmae_yard` | (-3213, 451) | `nw_house_158` 마당(원점 = 마당 가운데) |
| §13 장면 B | `ch_ojakgyo` | (-3283.4, 459.4) | 기존 region.json `ojakgyo` |
| §16 이별 길 | `ch_farewell_follow` · `ch_farewell_stand` · `ch_farewell_mong` | (-3211.6, 4) · (-3212.3, -6) · (-3212.7, -14) | 새 — 북문–전주길의 곧은 구간(90m, 시험 촬영 08) |
| §17 몽룡이 사라짐 | `ch_farewell_vanish` | (-3223.5, -60) | 광치천 징검다리(-3218.1, -50.7) 건너 |

**PART II**

| 장면 | 앵커 id | (x, z) | 근거 |
|---|---|---|---|
| §19 행렬 시작 → 남문 → 네거리 → 외삼문 | `ch_proc_start` → `ch_south_gate_in` → `ch_crossroads` → `ch_gwana_front` | (-3228, 372) → (-3228, 334) → (-3228, 251) → (-3166, 246.5) | 기존 길(`namwon_market_lane` → `namwon_eup_street` → 동서길). 약 160m |
| §20 아전 · §19 행렬 끝 | `ch_gwana_front` | (-3166, 246.5) | 새 — 외삼문 앞 길(맞은편 기와집 북쪽 끝 257.5) |
| §21 점고 · ACT10 · ACT17 · ACT18 | `ch_court` | (-3162.1, 214.5) | 새 — 동헌 기단 앞(≈208)과 내삼문 담(219.5) 사이, 관아 축 x = -3162.1 |
| 변학도 높은 단 | `ch_dais` · `ch_byeon_seat` | (-3162.1, 209) · (-3162.1, 206.6, dy 1.05) | NEW 보계 · 동헌 대청 앞 마루 |
| §21 기생 일렬 | `ch_gisaeng_0~7` | x -3169.8 ~ -3154.4(2.2m), z 213.6 | 새 |
| 사령 줄 | `ch_saryeong_w0~3` · `_e0~3` | x -3177.6 / -3146.6, z 210~217.5 | 새 |
| §25·§27 플레이어(사령 사이) | `ch_player_saryeong` | (-3175.2, 216.6) | 새 — 서쪽 줄 끝 |
| §22 이방 | `ch_ibang` | (-3168.6, 210.4) | 새 — 단 서쪽 계단 곁 |
| §25 춘향 중앙 · §28 형틀 | `ch_chunhyang_center` · `ch_hyeongteul` | (-3162.1, 214.2) · (-3162.1, 215.4) | 새 |
| §28 셋째 컷 월매 | `ch_wolmae_watch` | (-3160.6, 222.4) | 내삼문 바깥에서 안을 봄 |
| §29·ACT12·16·20 옥 | `ch_jail` · `ch_jail_cell` · `ch_jail_bars_out` · `ch_jail_gate` | (-3175, 229.5) · (-3176.4, 229.4) · (-3172.4, 229.6) · (-3169.8, 229.5) | 새 — 바깥마당 서쪽 반(서담 2m · 내삼문 footprint 2.2m · 외삼문 footprint 2.2m 여유) |
| §30 월매 음식 실랑이 | `ch_prison_food` · `ch_gate_guard` | (-3164.6, 244.6) · (-3159.2, 243) | 외삼문 밖 — 옥이 관아 안이라 월매는 문에서 막힌다 |
| §32 술 · 상인 | `ch_wine_cart` → `ch_feast_store` | (-3146.5, 249) → (-3150.5, 229.5) | 새 — 외삼문 동쪽 길가 → 바깥마당 동쪽 빈터(17×20m) |
| §33 쌀 | `ch_farmer_house` · `ch_rice_sacks` · `ch_farmer` | `nw_house_001` (-3109.36, 263.28) · (-3103, 273.2) · (-3108, 273) | 기존 동문 밖 농가 대문 앞 |
| §34 상소 노인 | `ch_elder_petition` | (-3173.5, 241.6) | 새 — 외삼문 서쪽 담 밑(앉음) |
| ACT14 남문 거지 몽룡 | `ch_beggar_meet` · `ch_player_sgate` | (-3228, 352.5) · (-3226.2, 347.2) | 남문 밖 장터길 |
| §40 잔치 음악 | `ch_musicians` | (-3177.6, 203.5) | 동헌 서쪽 곁(서담과 동헌 사이 8.6m) |
| §41 몽룡 가장자리 | `ch_mong_edge` | (-3170.5, 217.8) | 내삼문 footprint(x -3167.5~-3156.7) 바로 서쪽 |
| §42 시 · CAMERA 17A | `ch_poem_table` | (-3168, 213) | 새 — 단 앞 서쪽 |
| §47·§48·ACT21 옥문 · 재회 | `ch_jail_gate` · `ch_reunion` | (-3169.8, 229.5) · (-3166, 231) | 바깥마당 |
| §49 끝 아이 둘 | `ch_end_kids` | (-3323.5, 441) | 그네 곁 |

### 3-3. 오누이 v3.2와의 충돌 검사

- 대상: `namwon_data._anchors()` 96개 + 역참 앵커 2 + `placement_story_namwon.json` 무대 10(합 98). 오누이 무대는 거의 모두 **북쪽 고개 너머(z < -100)**와 동문 밖 주막(-3005, 231)이다.
- 결과: 춘향 앵커 68개 중 40m 안에 오누이 앵커가 있는 것은 17개. 모두 오누이의 **지도 표지용 앵커 `east_gate`(-3135.3, 248.8, 반지름 20)**과 관아 동쪽이 가까운 것이고(가장 가까운 것 `ch_wine_cart` 11.2m), 그 밖은 `ch_farewell_follow` ↔ `elder_town`(34.1m) 하나다. **연출 자리(인물이 서는 자리) 겹침은 없다.**
- 이별 길(x≈-3212, z 4~-14)은 오누이 기름집(-3220.1, 53.8) · 노인(-3209.5, 38)보다 40~60m 남쪽(지도상 북쪽)이고, 오누이 북쪽 어귀(-3196, -132)·고개(z < -150)에는 닿지 않는다(몽룡은 광치천 건너 z -60에서 사라진다).
- 소문 `NW_TOWN_MARKET`(near `namwon_jang`, 반지름 40)은 단오 군중 A구역과 겹친다. 소문 글은 오누이 결말 얘기라 단오 날에도 자연스럽지만, 1A·2A 컷신 동안은 사건이 소문 띄우기를 막아야 한다(사건 코드 때).

### 3-4. CASE_NAMWON_COMPLETE 뒤 오누이 v3.2에서 남길 것 · 숨길 것

`case_registry.choose()`는 "요구 조건이 맞고 끝나지 않은 첫 사건"을 고른다. 한양 책방까지 끝내고 남원에 오면 **춘향이 활성 사건이 되고 오누이 사건의 actor·object·trigger·prop은 하나도 서지 않는다**(multi-case-registry §5-1).

| 오누이 요소 | 어디 | 춘향 활성일 때 | 판정 |
|---|---|---|---|
| 외딴집·헛간·큰 나무·방앗간·서낭당·빈터(`placement_story_namwon.json`) | 정적 배치 | 그대로 보인다 | **남김**(맞음) |
| 외딴집 우물 `p_well` | namwon `props()` | **사라진다** | **남겨야 함** — 건물의 일부. `placement_story_namwon.json`으로 옮기거나 F-10 '비활성 사건 소품 층' |
| 붉은 수수밭 `p_sorghum_red` · 큰 나무 발톱 `d_claw`/`p_claw` | namwon `props()` | 사라진다 | **남기길 권함**(사건의 흔적이 세상에 남는다 — v3.2 §65 "사건 뒤에도 남는다") — 위와 같은 방법 |
| 떡·피·발자국·광주리·밀가루 등 단서 소품 | namwon `props()` | 사라진다 | 숨김(맞음 — 오래된 흔적) |
| 주모(주막) · 포수 · 방앗간 주인 · 기름집 아낙 · 노인 · 이웃 아낙 | namwon `actors()` | 사라진다 | 주모·방앗간 주인은 **고을 사람으로 남아야 자연스럽다** → 춘향 데이터에 같은 CHR로 다시 세우거나(대사는 춘향 시점) F-10. 포수·이웃 아낙은 숨겨도 됨 |
| 오누이 지도 표지·리드 | namwon `map_places/map_leads` | 활성 사건 것만 | 숨김(맞음) |
| 역참 마부 첫 안내(`station_intro`) | `namwon_case` | 없음 | 숨김(맞음 — 첫 방문 전용) |
| 첫 사건 고을 막음 `travel_gate` | namwon `case` | 풀린 상태 | 영향 없음 |
| 마지막 밤 달 감추기 · 두 빛 | `namwon_case` on_load 안전장치 | 없음 | 영향 없음 |
| 소문 `NW_TOWN_*`(rumors_data) | 공통 소문 | 그대로 | 남김 |
| 고을 사람(npc_ambient) · 장시 밀도 0.14 | 공통 | 그대로 | 남김 — 단오 군중은 그 위에 더한다(밀도 상수는 고치지 않음, E 금지) |

---

## 4. 카메라 (실제 자리)

지금 카메라는 **yaw 0(남쪽에서 북쪽을 봄) 고정**이다. 단계 `{camera:{pitch, distance, fov, focus}}`는 이 방향 그대로 겨냥점·거리만 바꾼다. 방향이 다른 구도는 사건 코드가 `main.rig.shot = {pos, look, fov}`를 쓴다(남원 7A·7C·rope 장면과 같은 방법). 아래 pos·look의 가운데 값은 **지형 위 높이(m)**.

| 컷 | 방식 | 값 | 무엇이 보이나 |
|---|---|---|---|
| **1A** 먼 광한루 | shot | pos (-3241.0, +23.1, 453.15) → look (-3271.4, +4.0, 450.1), fov 36 (= pitch 32 · 거리 36) | yaw 0으로는 "앞 장터 사람 → 누각 → 그네"가 안 된다(광한루가 장터 남쪽). 누각 동쪽 31m 위에서 서쪽으로: 앞에 C구역 군중(길목), 가운데 누각, 그 뒤 59m 그네. 시선 계산상 그네 위쪽(5m 이상)은 누각 지붕(약 12m) 위로 보인다 |
| **1B** 몽룡의 뒤 | shot | pos (-3286.5, +2.6, 448.6) → look (-3330, +4, 444), fov 34 | 화면 한쪽 몽룡(4.6m 앞), 44m 밖 버드나무 둘 사이 그네 |
| 2A 3인 | camera | focus `ch_swing_land`, pitch 34 · 거리 16 · fov 40 | 공통 TALK(38/13.5/38)보다 넓게 |
| 5A 긴 길 | camera | focus `ch_farewell_stand`, pitch 24 · 거리 22 · fov 36 | yaw 0이 그대로 북쪽 전주길을 길게 본다 — 뒤(남) 방자·플레이어, 앞(북)으로 멀어지는 몽룡(시험 촬영 08) |
| 6A 행렬 | shot | pos (-3228, +1.7, 258) → look (-3228, +1.6, 330), fov 34 | 네거리 남쪽에서 남문 쪽으로 낮고 길게. 행렬이 카메라 쪽으로 걸어온다(앞 포졸 · 가운데 가마 · 뒤 짐), 군중 양옆 |
| **8A** 권력 대칭 | camera | focus `ch_court`, pitch 52 · 거리 23 · fov 32 (명세) | 카메라가 내삼문 위(z≈228.7, 높이 18) — 동헌이 화면 위 가운데, 관아 축 대칭. **시험 촬영 05: 내삼문 지붕이 화면 아래 1/3을 덮는다**(가림 페이드로 반투명) |
| 8A′ (보정안) | camera | focus (-3162.1, 212.0), pitch 58 · 거리 21 · fov 32 | 시험 촬영 06: 동헌 위 가운데 · 안마당 전체 · 내삼문 지붕은 아래 끝 띠만. 점고·곤장·잔치·출두에 같은 틀을 되풀이(§52) |
| 10A | camera | 8A → focus `ch_chunhyang_center`, pitch 22 · 거리 9 · fov 34 | 두 번째 요구에서 처음으로 춘향 높이로 |
| **12A** 창살 | shot | pos (-3171.6, +1.45, 229.9) → look (-3176.4, +1.0, 229.4), fov 42 | 옥 칸 앞 나무살(x≈-3174)이 늘 전경 일부를 가린다. 춘향 안, 플레이어 밖 |
| 14A 남문 | shot | pos (-3225.4, +1.75, 345.6) → look (-3228, +1.5, 352.5), fov 38 | 플레이어 어깨 너머, 해 질 녘 남문 밖. 정면 클로즈업 금지 |
| **17A** 시 | shot | pos (-3168, +2.3, 213.05) → look (-3168, +0.4, 213.0), fov 30 | 서안 위 종이를 위에서. 잔치 소리 줄이기(duck) |
| **18A** 출두 | shot | pos (-3162.1, +2.75, 203.6) → look (-3162.1, +1.8, 239.5), fov 40 | 변학도(대청 z 206.6) 뒤에서 남쪽 — 열린 내삼문 틀 안에 외삼문. 같은 관아 축에서 사람들 자세만 뒤집힌다(군중 `on_flag` → bow/kneel) |

---

## 5. EventCrowd 구역 (C60 — 인원은 성능 시험 뒤 확정)

데이터 `crowds[]`(placement 초안 파일) — 사건 코드 때 `namwon_chunhyang_data.crowds`로 옮긴다. 구역은 축 정렬 사각형(`rects`) + 빼는 곳(`exclude` 사각형·원). 사각형 = `[x0, z0, x1, z1]`.

### 5-1. `dano_market` — PART I 단오 (density **high**, 시작값 28)

| 구역 | 사각형 | 시작 인원 | 바닥 | 역할 |
|---|---|---:|---|---|
| A 장터길 | [-3336, 389.6, -3230, 396.4] | 10 | 마을 터 | idle·talk·walk(장터길 따라) |
| B 광한루 앞 잔디 | [-3330, 424, -3262, 441.5] | 14 | 풀밭 | watch(씨름판 쪽) · talk · idle · 노인 sit(평상) |
| C 광한루 드는 길목 | [-3256, 441, -3243.5, 453.5] | 4 | 풀밭 | watch(누각 쪽) · idle — **1A의 앞 군중** |

- 뺄 곳: 가게 `nw_shop_14` · 씨름판 원(r 3.8) · 그네 흔들림 원(r 6) · 광한루 footprint · 엿판 · **대화 비움 구역** [-3275, 430, -3258, 440.5](§5 방자 부딪힘 · 몽룡 대화).
- 역할 비율: idle 0.30 · talk 0.25 · walk 0.20 · watch 0.25. 아이(child_boy/girl)는 그네·엿판 둘레에 몰리게.
- bank: CHR_HUM_028/029(villager_m·villager_f) · 020/021 아이 · 022 노인 · 009/010 농부·아낙 · 003 보부상 · 002 상인 · 001 선비.
- seed 50501. `when` = PART I `dano`·`courtship` 단계. 60m 밖은 멈춤.
- 중요 프레임: **1A**(C구역이 화면 앞 — 반드시 사람이 있어야 한다) · **1B**(그네 6m 안은 비움 — 그네가 가려지지 않게) · 2A · 평소 걷기 시점.
- 논(z 405~422, x < -3262)에는 세우지 않는다 — A와 B 사이는 길(구례길 x≈-3232)로만 이어진다.

### 5-2. `byeon_banquet` — PART II 생일잔치 (density **medium**, 시작값 14)

| 구역 | 사각형 | 시작 인원 | 높이 | 역할 |
|---|---|---:|---|---|
| A 안마당 서쪽 | [-3181, 209.5, -3167.8, 218.6] | 4 | 땅 | sit(잔칫상) · stand(기생) |
| B 안마당 동쪽 | [-3156.4, 209.5, -3143.2, 218.6] | 4 | 땅 | sit · stand |
| C 대청 위 | [-3172, 204, -3152.2, 207.6] | 4 | **dy 1.05** | sit(고을 수령들) |
| D 동헌 서쪽 곁 | [-3181, 199, -3175, 208.5] | 2 | 땅 | 악공 sit · 시중 serve |

- 뺄 곳: **가운데 통로** [-3164.6, 209.5, -3159.6, 219.5](몽룡 입장 · 수행원 길) · 보계 · 변학도 자리 · 서안.
- 역할: sit 0.45 · stand 0.25 · serve 0.15(바깥마당 물자 → 내삼문 → 안마당 짧은 왕복) · watch 0.15.
- **출두(`royal_inspector_reveal`) 때 같은 사람의 자세만 바꾼다**: sit → kneel · stand/serve/watch → bow(§44 "사람들의 자세로"). 지금 C60 행동 목록에 bow·kneel이 없다 → 동작 2개 NEW(S) + `on_flag` 한 줄.
- bank: CHR_HUM_024 `scholar` · 004 `official` · 016 `pojol` · 026 하인 · 기생(NEW generic `gisaeng`).
- seed 50502. `when` = `feast`·`reveal` 단계. 40m 밖 멈춤.
- 중요 프레임: **8A/8A′**(대칭 — 양옆 인원 수를 같게) · **17A**(화면 밖, 소리만) · **18A**(사람들이 정문 쪽을 보다 고개를 숙인다).

선택: §19 행렬 구경꾼은 `dano_market` bank를 low density(6~10)로 남북길 양옆 [-3236, 262, -3232, 330] · [-3224, 262, -3220, 330]에 다시 쓰면 된다(새 프리셋 아님).

---

## 6. 배치 초안 파일 — 비활성 확인

`seolhwa_godot/region_data/JL_NAMWON_UNBONG/placement_story_namwon_chunhyang.json`

- 이름은 관례(`placement_story_<case>.json`, 제작 규칙 E·B-3)를 따른다. 그런데 **`placement_loader.gd`는 `placement_*.json`의 `items`를 `when` 없이 늘 읽는다**(E절 "placement는 when 없이 늘 읽힘", F-11 미구현). 그래서:
  - `items: []` — 로더·탁본(`rubbings_data.for_space`)·역참/길목 도구(`make_stations.py`·`make_travel_gates.py`·`render_joseon_map.py`)가 읽는 키는 비어 있다.
  - 실제 항목은 `tale_items`(when·phase·status·cost·placeholder), `anchors`, `crowds`, `cameras`에 둔다.
  - 켜는 방법(다음 단계 중 하나): (a) F-11 조건부 로더가 `tale_items`의 `when`을 읽게 하거나, (b) `namwon_chunhyang_data.props()`로 옮긴다(이야기 소품은 이미 `when`을 지원 — 단, 사건이 활성일 때만 선다). 옥·보계처럼 늘 있어도 되는 건물은 (c) 결정에 따라 `items`로 옮겨 정적 배치로.
- `when` 문자열은 이야기 DSL(`ph`·`f`·`fn`)이고, 단계 이름(`dano · courtship · farewell · arrival · office · jail · feast · reveal · release · epilogue · done`)과 `fn('is_night')`는 **사건 코드에서 정할 초안**이다.
- NEW 항목의 kit `story/chunhyang`은 아직 없다. `placeholder`는 미리보기용 기존 키트다.
- 확인(창 모드, 시험 저장 `user://chp_shot.json`): 디버그 폴더 없이 실행 → `PLACEMENT files=5 items=1862 … missing=0`(파일 하나 늘고 항목 수는 그대로 1,862), 오류·경고 줄 없음(촬영 11). 시험 결과는 §9.

---

## 7. 스크린숏 (`seolhwa_godot/shots/chunhyang_plan/`, git 제외)

디버그 표지(낮은 솟대 = 앵커 · 낮은 울타리 = 군중 구역 테두리 · NEW 자리 = 기존 키트 대용)는 `--placedir=shots/chunhyang_plan/debug_place`로만 읽었다 — 배포 안 함. 창 모드 1024×768, 11시, `--nofog --nostory`(11만 이야기 켬), 시험 저장.

| 파일 | 내용 |
|---|---|
| `01_gwanghallu_overview.png` | 광한루 · 단오 마당(B 테두리) · 씨름판 자리 · 색천 · 좌판 · 평상 · 그네 자리 · 장터 |
| `02_swing_spot.png` | 그네 자리(장대 대용 둘) · 버드나무 둘 · 2A 앵커 |
| `03_wolmae_house.png` | 월매 집(`nw_house_158`) · 마당 평상 · 대문 등롱 · 감나무 |
| `04_gwana_overview.png` | 관아 전체 — 동헌 · 얕은 안마당(잔칫상·군중 A/B 테두리) · 내삼문 · 넓은 바깥마당(옥 자리 · 물자 · 감나무) · 외삼문 |
| `05_gwana_8A_frame.png` | 8A 명세값(52/23/32) — 내삼문 지붕이 아래 1/3을 덮음 |
| `06_gwana_8A_tuned.png` | 8A′(58/21/32, 겨냥 z 212) |
| `07_jail_spot.png` | 옥 자리(바깥마당 서쪽) · 옥 앵커 · 등롱 |
| `08_farewell_road_5A.png` | 5A — 북쪽 전주길 이별 구간 · (선택) 오리정 |
| `09_farmer_rice.png` | §33 동문 밖 농가 · 쌀가마니 |
| `10_dano_road_C.png` | 1A 앞 군중 C구역(광한루 동쪽 길목) |
| `11_gwanghallu_live_no_debug.png` | 디버그 없이 실제 게임 — 초안 파일이 아무것도 안 보이게 함 |
| `plan_gwanghallu.png` · `plan_gwana.png` · `plan_town.png` · `plan_farewell.png` | 2D 계획 지도(landuse 바탕 · 배치 footprint · 빨강 = 춘향 앵커 · 보라 = 오누이 앵커 · 파랑/주황 = 군중 구역 · 빨간 사각형 = NEW) |

---

## 8. 사용자 결정이 필요한 것

1. **관아 안마당 깊이** — 동헌 기단 앞(≈208)에서 내삼문 footprint(216.7)까지 축 위 8.7m, 보계를 놓으면 6.7m. 8A 명세값에선 내삼문 지붕이 화면 아래를 덮는다.
   - A(권장): 그대로 쓰고 8A′(58/21, 겨냥 2.5m 북쪽)로 구도를 맞춘다. 점고 기생 8 · 사령 8 · 춘향 · 플레이어는 들어간다(촬영 06).
   - B: 점고·곤장만 바깥마당(20×41m)에서 — 넓지만 "동헌이 위 가운데" 구도를 잃는다.
   - C: 허브 배치에서 내삼문 가로담을 남쪽으로 6m 옮긴다 — 지역 층(`tools/placement/namwon.py`) 수정이라 E절 원칙 밖, 따로 승인 필요.
2. **옥 자리** — A(권장): 관아 바깥마당 서쪽(-3175, 229.5) — 월매가 외삼문에서 막히는 §30과 맞고 18A·재회 동선이 짧다. B: 안쪽 북서 구석(-3174.5, 180, 내아 곁) — 더 숨지만 수령 살림채 곁이라 고증이 어색. 그리고 사건 뒤 옥을 **남길지**(조선 읍치에 옥은 늘 있었다 → 정적 `items`로 옮기기) 정해 주세요.
3. **월매 집** — A(권장): `nw_house_158` 재사용(기와 작은 집, 광한루 45m · 나루 주막 23m). B: `nw_house_018`(기와 작은 집, 장터 쪽). C: 별당 있는 큰 집을 새로 — 결정 6 범위를 넘는다.
4. **그네 자리** — A(권장): 광한루원 북서 잔디(-3330, 444) — 누각에서 서쪽 44m, 1A·1B 둘 다 성립. B: 오작교 건너 못 남쪽 둑 — 시적이지만 요천 둑까지 14m뿐이라 군중·카메라 자리가 없다.
5. **오리정** — 원작 이별 지명(五里亭)을 이별 길 곁 정자(`village/jeongja` plain)로 둘지. 결정 문서에 없어 `optional`로만 넣었다.
6. **오누이 잔존물** — 춘향 활성 때 사라지는 외딴집 우물(`p_well`) · 붉은 수수밭 · 발톱 자국, 그리고 주모 · 방앗간 주인. (a) 우물·수수밭을 `placement_story_namwon.json`(정적)으로 옮기고 고을 사람은 춘향 데이터에 다시 세우기(작음) vs (b) F-10 '비활성 사건 소품·인물 층'(L)을 먼저.
7. **1A 그네 가시성** — 계산상 그네 위쪽은 누각 지붕 위로 보이지만, 사건 코드 때 실제 컷으로 확인한다. 안 되면 그네를 북쪽으로 6m(z 438) 당긴다.

---

## 9. 빈자리(gap)와 최소 추가

| # | 빈자리 | 최소 추가 | 크기 |
|---|---|---|---|
| G1 | 관아 안마당이 얕다(8.7m) · 8A에서 내삼문 지붕 가림 | §8-1 A: 8A′ 값만. (C는 지역 층 수정) | S |
| G2 | 옥 건물이 없다 | `story/chunhyang` `ok`(둥근 담 · 옥사 · 살 상태) | M |
| G3 | "높은 단"이 동헌 마루(F 1.05)뿐 | 보계 `dais` + 교의·병풍 `seat_screen` | S+S |
| G4 | 삼문 판문이 늘 열린 모양(§44 "정문이 열린다") | `landmark/samun`에 문짝 state | S |
| G5 | 그네 · 씨름판 · 차일 · 형틀 · 가마 키트 없음 | `story/chunhyang` kind 5개 | M+S+S+S+M |
| G6 | 변학도 관복·사모, 기생, 칼(枷), 마패, 파립 부속 없음 | painter 부속 + 굽기 세트 | M |
| G7 | 짐수레는 엎어진 것뿐 | `story/snow_road cart` upright | S |
| G8 | 엿판 goods 없음 | `jwapan` goods `yeot` | S |
| G9 | 배치 로더가 `when`을 모름 | F-11(조건부 로더) 또는 이야기 `props()`로 옮김 | M / S |
| G10 | 한 공간 한 사건 — 오누이 잔존물·고을 인물이 사라짐 | §8-6 (a) 작게 / (b) F-10 | S / L |
| G11 | EventCrowd 없음 + 사각형·빼는 곳·대청 dy·출두 자세 바꾸기 | F-17 최소 구현 + bow·kneel 동작 | M + S |
| G12 | 월매 집 실내 없음 | 필요 없음 — 마당·대문 앞으로 연출 | — |
| G13 | 카메라 yaw 고정 — 1A·1B·6A·12A·14A·17A·18A는 다른 방향 | 이미 있는 `rig.shot`(사건 코드에서) | — |

추가하지 않는 것: 계절 시스템, 관아·읍성 새 건물(옥·단 말고), 새 미니게임, 전역 군중 시스템.

---

## 10. 확인

- 배치 초안 로드: 위 §6.
- 시험(마지막에 한 번): `validate_event_class` · `validate_case_meta` · `tests/registry/case_registry_test.gd` · `map_leads_test` · `tools/run_story_tests.sh` 전부 — 결과는 이 문서를 넣은 커밋 메시지와 보고에 적는다.
