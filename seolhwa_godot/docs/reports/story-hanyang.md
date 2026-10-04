# story-hanyang 보고 — 사건 「비어 있는 책방」(ACT 1 한양)과 추격 시스템

개발 우선순위 2번 작업이다. ACT 1 한양 사건(S1001~S1006)을 GG_HANYANG 권역에서 처음부터 끝까지 할 수 있게 만들었다. 남원 사건(S0010, `MAIN_MASTER_TRACE`에 HANYANG)에서 이어지고, R01 노정으로 와도, 역마로 와도 시작한다. 함께 만든 것은 다음과 같다.

- 다음 사건(4·6·9)도 쓸 추격 모듈
- 우치·책쾌·포졸 프레임
- 남원 사건에서 남은 일 두 가지: 호랑이 이야기 프레임 늦게 읽기, 시작 메뉴

## 1. 실행

| 하고 싶은 것 | 명령 |
|---|---|
| 그냥 하기(시작 메뉴) | `godot --path seolhwa_godot res://scenes/region.tscn` → 새 게임 / 이어 하기 |
| 한양에서 바로 | `-- --region=GG_HANYANG` (저장의 `MAIN_MASTER_TRACE`에 HANYANG이 있어야 사건이 선다. 없으면 한양은 소문만 돈다) |
| 대본 시험 | `-- --region=GG_HANYANG --storytest=hanyang`: 숭례문 앞 도착. 추격을 한 번 놓친 뒤 다시 쫓아 끝까지 간다 |
| | `--storytest=hanyang:r01`: R01 노정 끝(노들 남쪽) 도착. 추격을 놓친 뒤 발자국을 따라간다 |
| | `--headless`도 된다 |
| 시험 화면·fps | `--storyshots=<폴더>`: 추격 구간·책방·허브를 찍는다. `--novsync`: 추격 fps를 수직 동기 없이 잰다 |
| | `--blockmap=x0,z0,x1,z1`: 놓치기 구간에서 충돌 격자를 글자로 찍는다 |
| 시작 메뉴 시험 | `--titletest=new` 또는 `--titletest=continue[:찍을.png]` |
| 메뉴 없이 | `--notitle`. `--storytest·--bench·--tour·--shot·--warp·--newgame·--continue`이거나 다른 공간에서 넘어온 장면이면 메뉴를 띄우지 않는다 |

조작은 남원과 같다(이동 WASD·Shift, 조사 E, 기록 R). 추격 중에도 플레이어는 직접 달린다.

## 2. 무대(게임 좌표 x, z)

| 자리 | 좌표 | 내용 |
|---|---|---|
| 숭례문 | (−644, −332), 앞 (−644, −310) | S1001. 문을 지나면 자막 하나 |
| 종루 | (−291, −878) 반경 34 | S1001 끝. 쪽지를 떠올리는 알림 |
| 책쾌 책방 | (−252, −938) `hy_sc_chaekbang`. 문 (−252, −933.6), 앞 (−252, −930.2) | S1002 문턱. 단서 다섯은 먹통 (−251.9, −938.25), 찻잔 (−251.25, −937.65), 끈 (−249.5, −937.1), 장부 (−250.9, −937.1), 뒤창 (−250.4, −940.4) |
| 골목 어귀 | (−221.6, −929.5) `hy_alley_121`이 피맛골과 만나는 곳 | 우치가 서서 지켜본다 |
| 추격 끝 | 광통교 (−313.6, −815.4). 북쪽 끝 (−312.5, −826), 종이 (−313, −817.6) | S1004 |
| 빈 창고 | (−241.6, −938.6) `hy_sc_bin_changgo`. 대문 (−243.2, −934.2), 묶인 자리 (−240.7, −939) | S1005 |
| 포졸 순찰 | 종로 (−340 ↔ −215, −884), 개천 북쪽 (−298 ↔ −262, −826) | |

추격 길은 다음 순서로 간다(`hanyang_data.gd chases.s1003`).

1. 골목 어귀
2. 시전 뒤 풀밭
3. **지름길 ①**: 북쪽 시전 행랑 담을 타고 지붕 위로 (높이 4.1). 플레이어는 동쪽 틈(x −191)으로 돈다
4. 운종가로 뛰어내림 (−199.6, −890.6)
5. 중촌 골목(`hy_alley_177`)을 따라 남쪽으로
6. **지름길 ②**: 중촌 기와집 세 채(92·93·94) 지붕을 서쪽으로 건넌다 (높이 4.3, 먹 실루엣). 플레이어는 아래 골목(`hy_alley_141`, z −828.6)으로 따라간다
7. 뛰어내림 (−242.2, −831)
8. 개천 북쪽 둑
9. 광통교 동쪽 난간 끝을 돌아 다리를 건넌다
10. 남쪽으로 사라진다

길이는 약 200m, 따라가면 약 35초다. 충돌 격자로 확인했다. 쫓는 길(follow)에서 막힌 칸은 0이다. 처음에는 광통교 동쪽 난간에 막혀 다리 북쪽 끝으로 돌렸다.

## 3. 사건 진행(§10 대응)

- **S1001 입성**
  - 한양에 처음 들고 저장의 `MAIN_MASTER_TRACE`에 HANYANG이 있으면 시작한다(`case.requires`, 쉼표 목록이면 포함 여부로 본다 — 강릉 사건의 `HANYANG,GANGNEUNG` 형식).
  - 노정·역마로 넘어와도 시작한다(`start_on_arrival`).
  - 숭례문에서 600m보다 먼 곳(R01 포털은 노들 남쪽 약 3.5km)에 닿았으면 다음과 같이 한다: 암전 → "노들 나루를 건너 숭례문 앞에 섰다." → 숭례문 앞.
  - 숭례문을 3초 비추고(강제 컷신 최소) 조작을 돌려준다.
  - 기록책에 이겸의 쪽지("종루 뒤 피맛골, 책쾌. 옛 장부 일을 물어볼 것.")가 생긴다.
  - 숭례문을 지날 때 자막, 종루에 닿으면 알림이 나온다.
- **S1002 비어 있는 책방**
  - 문턱에서 "문이 열려 있다. 아무도 없다."만 나온다. NPC 설명은 없다.
  - 프롭 상태(world-scenario API)는 다음과 같다.

    | 프롭 | 상태 |
    |---|---|
    | 뒤창 | OPEN |
    | 먹통 | FALLEN |
    | 끈 | BROKEN |
    | 장부 | MOVED |
    | 서안 | MOVED |
    | 책더미 | FALLEN |
    | 찻잔 | USED (김) |

  - 조사 대상은 다섯이다: 넘어간 먹통, 끊어진 끈, 열린 뒤창, 찢긴 종이(이겸의 필체), 아직 따뜻한 차.
  - 뒤창을 조사하면 미리 깔린 데칼 그룹 `s1003_tracks`(뒤창 → 뒷골목 → 피맛골 짚신 자국)가 켜진다.
- **S1003 골목 추적**
  - 뒤창 단서와 단서 셋 이상이 있을 때 책방 앞으로 나서면 시작한다.
  - 피맛골 어귀의 사내가 이쪽을 본다(5초 이내). 그 뒤 추격이다.
  - 추격 중 자막: "사내가 시전 담을 짚고 지붕으로 뛰어오른다!", 포졸 "어이, 거기 서!", "또 지붕이다!", "사내가 개천 둑으로 꺾는다."
  - 끝: 다리 건너 인파 속으로 사라진다. 포졸 "또 우치 그놈이로군!"으로 이름이 처음 나온다(단서 '우치').
  - **놓치면(§29)**: "놓쳤다." 뒤에 고른다.
    - 다시 쫓는다(마지막 길목에서, 두 번까지)
    - 발자국을 따라간다: 젖은 발자국 데칼이 광통교까지 나 있다. 다리에 닿으면 "발자국은 광통교 난간 앞에서 끊겼다."
  - 어느 쪽이든 이야기는 이어진다. `CASE_HANYANG_OUTCOME` = followed | lost이고, 기록책과 결말 카드 문구가 다르다.
- **S1004 세 장의 종이**
  - 다리 난간의 종이: 강릉·경주·황주, 이겸 필체. 뒷면에 "쫓아올 테면 제대로 보고 오시오."
  - `MAIN_WOOCHI_KNOWN = true`, 이겸의 기록 조각(ITM_KEY_002) ×3.
- **S1005 책쾌 구조**
  - 종이를 본 뒤 책방 가까이 가면 "책방 옆 빈 창고에서 쿵— 쿵—"이 들린다.
  - 그 전에 빈 창고를 살피면 "빗장이 바깥에서 질러진 빈 창고. 안은 조용하다."만 나온다. 그 뒤에는 빗장을 벗긴다.
  - 묶인 책쾌(tied) → (끈을 끊는다) → 끈 BROKEN, 앉음.
  - 대사는 "…죽일 생각은 없던 모양이오." / "이겸 선생은?" / "그 사람도 옛 기록을 찾았소."뿐이다.
- **S1006 허브 개방**
  - 암전 뒤 책방이 다시 열린다(지역 변화: 뒤창 닫힘·먹통 세움·책 정리·차 김·책쾌가 앉아 있다).
  - 변수: `ACT2_OPEN = true`, `ACT2_ROUTES = [GG_HANYANG-GW_GANGNEUNG, -GS_GYEONGJU, -HH_HWANGJU]`.
  - 알림 "새 길 — 강릉 · 경주 · 황주 (어디부터 가도 된다)"와 사건 종결 카드가 나온다.
  - 책쾌에게 세 곳을 물으면 한 줄씩 관점만 준다(§27).
  - 기록책에 남은 곳이 적힌다.
- **ACT 3 잠금·§14 갈고리**
  - `act2_all_done()`: 강릉·경주·황주 결말 변수가 셋 다 있어야 참이다.
  - 그때 책쾌 대화가 `S1401`(§14 한양 중간 귀환)이 된다: "우치가 평양으로 올라갔소.", 위조 통행문서(ITM_KEY_003), `ACT3_OPEN = true`.
  - 평양 사건은 `ACT3_OPEN`을 requires로 쓰면 된다. 노정 자체는 막지 않았다(세계 쪽 담당).
- **소문(§24, `story/rumors_data.gd`)**
  - 한양 풀 5줄: 운종가, 결말과 상관없다.
  - S1006 뒤(`need: {ACT2_OPEN: true}`): 책방 앞 "대관령에서 제물 건드리면…", 종루 "감포 바다에서 밤마다 불이 셋 떠.", 광통교 "장산곶에서 바다가…". 칠패 장·배오개 장·마포 주막은 셋이 번갈아 나온다.
  - 소문 항목에 `need`(변수 조건)를 더했다.
- **§44 필드**: 장면마다 전부 있다. SOURCE_ID는 `MAIN-ACT1`이다. 메인 시나리오 장면이라 Fxx가 없다. ADAPTATION_MODE는 ECHO다(전우치 이름만 빌린 인물).
  - GG-01의 F16·F17·F21(빈 관)은 쓰지 않았다(뒤로 미룸).

## 4. 추격 시스템 `scripts/story/chase.gd`(사건 4·6·9가 같이 쓴다)

- 쓰는 방법
  - 데이터: 사건 데이터 `"chases": { id: spec }`
  - 실행: 이야기 명령 `{ "chase": id, "store": "chase" }`(story_runner) 또는 사건 GDScript `await Chase.run(d, id, 다시_쫓을_길목)`
  - 결과: `"end"` | `"lost"`. 놓친 길목은 `S.flags._chase_<id>_cp`에 남는다.
- spec 값

  | 키 | 뜻 |
  |---|---|
  | `actor` | 달아나는 인물 |
  | `speed` | 기본 4.4 (플레이어 달리기 4.6) |
  | `burst` | 6.3 |
  | `lead` | 바라는 앞섬 13m |
  | `min_lead` | 6 |
  | `wait_lead`·`wait_max` | 27m 넘게 벌어지면 4초까지 멈춰 돌아본다 |
  | `lose_lead`·`lose_off`·`lose_time` | 46m, 32m, 6초 |
  | `wake_lead`·`wake_time` | 처음 다가올 때까지 서서 본다 |
  | `retry_back` | 다시 쫓을 때 길목 몇 m 뒤에서 시작하나 |
  | `camera`·`frame_reach`·`frame_mix` | 카메라 |
  | `end_anim`·`vanish_delay` | 끝 동작과 사라지기까지 초 |

- 구간 `segments[]`
  - `mode`: lane · bank · climb(땅 → 지붕 높이 y) · roof(지붕 위, 보기만) · drop
  - `run`: 달아나는 길, `follow`: 플레이어가 갈 길(지름길이면 돌아가는 길)
  - 그 밖에 `speed` 배율 · `anim` · `ink`(먹 실루엣) · `caption`/`toast` · `call`(사건 함수) · `checkpoint`
- **순간이동 없음**: 앞섬은 follow 길을 이은 한 줄에서 잰다. 다음 세 가지로만 지킨다.
  - 고무줄 속도: 가까우면 burst로 플레이어보다 빠르게, 멀면 느리게
  - 기다림: 너무 멀면 멈춰 돌아보다가 4초 뒤 제 갈 길
  - 플레이어가 갈 수 없는 지름길: 담·지붕. 플레이어는 보이는 아래 길로 돈다
- 다시 쫓기만 암전 속에서 플레이어를 길목 9m 뒤로 옮긴다.
- 대본 시험 기록: 따라갈 때 앞섬 최소 약 5m(끝 다리 위 −0.2: 사라지는 자리), 최고 속도 6.3m/s.
- **카메라**: 시점이 고정(북쪽이 위)이라 남쪽으로 달아나면 화면 밖으로 나간다.
  - 그래서 추격 동안 초점을 플레이어와 달아나는 인물 사이로 둔다(플레이어 쪽 55%, 최대 18m 당김).
  - 거리 40, 피치 47.
- **지붕 실루엣**: SpriteChar의 번쩍임 칸에 먹빛(0.82)을 덮어 지붕 위에서 검은 사람 꼴로 보인다(`ink`).
- `director.free_move`: 추격 동안 이야기가 돌고 있어도 플레이어가 움직인다(story_director `blocks_move`).
- **순찰**: `Chase.patrol(d, dt)`. 인물 항목에 `"patrol": [자리…], "patrol_speed"`를 주면 그 자리들을 오간다(포졸). 사건 `ambient()`에서 부른다.

## 5. 이야기 틀에 더한 것(작은 수정, 공유 파일)

- **story_director**
  - `CASES`에 GG_HANYANG을 더했다.
  - `case.requires {변수: 값}`: 맞지 않으면 소문만. 쉼표 목록 값은 포함 여부로 본다.
  - `case.start_event`·`start_on_arrival`: 첫 장면을 S0001로 고정하지 않는다. 넘어온 장면에서도 시작한다.
  - `case.reset_vars`: 새 시작 때 되돌릴 공통 변수.
  - 사건별 대본 시험: `story/<사건>/<사건>_test.gd`가 있으면 그것을 쓴다. 그 파일의 `static prepare(d)`가 앞 사건 저장을 꾸민다.
  - `free_move`, 시작 메뉴, 이어 하기 자리 저장(10초마다·저장할 때), `resume_at`.
  - BANK_FILES에 `frames_story_hanyang.json`을 더했다. 프레임이 없을 때 대신 쓰는 종류는 다음과 같다: woochi → villager_m, chaekkwae → merchant, pojol → official.
  - 시작할 때 하던 `merge_bank("frames_story.json")`를 뺐다(늦게 읽기, 아래 6절).
- **story_runner**: `chase` 명령.
- **story_state**
  - VAR_DEFAULTS에 다음 셋을 더했다(§7에 없는 구현용 값): `ACT2_OPEN`, `ACT3_OPEN`, `CASE_HANYANG_OUTCOME`.
  - `clear_saved(keys)`.
- **progress.gd**: `where`(이어 하기 자리), `set_where`, `has_save`, `reset_all`.
- **sprite_char.gd**: `merge_bank(json, only=[])`. 종류를 고르고, 같은 파일·종류는 한 번만 더한다.

## 6. 남원에서 남은 것

- **호랑이 이야기 프레임 늦게 읽기**: 15쪽, 약 60MB.
  - 시작할 때가 아니라 주막에서 쉬어 밤으로 넘어갈 때 암전 속에서 읽는다(`namwon_case.rest → load_tiger_story`).
  - 밤 저장에서 이어 할 때(`on_load`)와 절정 시작(`climax`, 이미 읽었으면 그냥 지나감)에도 부른다.
  - 첫 조우(S0005)는 기본 호랑이 프레임만 쓰므로 영향이 없다.
- **시작 메뉴** `scripts/story/title_menu.gd`(한지 바탕, 설화록 / 새 게임 / 이어 하기)
  - 새 게임: 저장을 비우고 `world.props.reset_all()`. 남원이면 그 자리에서 S0001부터, 다른 공간이면 남원으로 넘어가 S0001부터(`pending.newgame`).
  - 이어 하기: 저장된 자리로. 다른 공간이면 그 공간으로 넘어가 `resume_at`. 저장이 없으면 흐리게 막힌다.
  - 확인한 것:
    - 한양 저장에서 이어 하기 → 같은 자리, S1001을 다시 돌리지 않음
    - 한양에서 새 게임 → `TRAVEL arrive JL_NAMWON_UNBONG from=title` → `EVENT S0001`

## 7. 캐릭터 프레임(데이터는 git 제외 — 다시 구워야 한다)

```
python3 seolhwa_godot/tools/web_export_server.py 8770
브라우저: http://localhost:8770/__tools/story_bake.html?set=hanyang
→ data/frames_story_hanyang.json + frames_story_{woochi,chaekkwae,pojol}_{0..2}.png (약 10초)
```

| 종류 | 인물 | 생김새 | 동작 |
|---|---|---|---|
| woochi | CHR_MAIN_003 | 가벼운 몸 0.9, 짙은 쪽빛 저고리·바지, 머리띠, 짐 없음 | idle·walk·run·talk·climb·crouch |
| chaekkwae | CHR_MAIN_007, 상인 베이스 변형 | 갓, 책 보따리 | idle·walk·talk·sit·tied |
| pojol | CHR_HUM_016 | 벙거지, 검은 쾌자, 붉은 띠, 긴 막대 | idle·walk·run·talk |

- 웹 `seolhwa/src/chars/anims.js`에 사람 이야기 동작 crouch(낮게 웅크림)·sit(땅에 앉기)·tied(팔을 등 뒤로, 이따금 몸 비틂)를 더했다(웹 쪽 기존 동작은 그대로).
- `?set=skills`: v2.2 숙련 동작(9절) → `frames_story_skills.json`.
- `?set=` 없이 열면 예전처럼 남원 묶음(frames_story.json)을 굽는다.

## 8. 시험 결과

| 시험 | 결과 |
|---|---|
| `--storytest=hanyang`(헤드리스·화면) | PASS, followed, 약 40초. 한 번 놓침 → 다시 쫓기 → 끝까지 |
| `--storytest=hanyang:r01`(헤드리스) | PASS, lost, 12초. 먼 도착 → 숭례문 앞, 놓침 → 발자국 → 광통교 |
| 남원 `namwon:A/B/C`, 강릉 `gangneung:A`(회귀, 헤드리스) | 모두 PASS: A A_repel 263초 · B · C 24초 · 강릉 A 15초. 숙련 해금 로그: 남원 받아밀기, 강릉 회피베기, 한양 빠른 투척 |

- 확인한 것
  - S1001~S1006 장면(seen)
  - 단서 13개
  - `MAIN_WOOCHI_KNOWN`, 종이 3, `ACT2_OPEN`, ACT 3 잠김, §14 갈고리 아직 안 열림
  - 책방 뒤창 SEALED(허브)
  - 소문 세 줄 조건, 종루에서 실제로 들림
- 화면: 추격 지붕(시전·기와 지붕 줄 실루엣), 운종가, 개천 둑, 책방, 허브. 시험 폴더 `--storyshots`.
- **성능**(2048×1536, Mobile, M1, 수직 동기 끔)
  - 추격 중(`--storytest=hanyang --novsync --storyspeed=1`): 평균 120~125fps, 최저 94fps(놓친 회차 / 따라간 회차)
  - 책방 앞 `--bench=15`: 132.1fps, p99 9.1ms, 33ms 넘은 프레임 0, 처음 불러오기 7.2초
  - 시간 배율 1에서도 PASS(89초)
- 회귀: v2.2 반영 뒤 다시 돌렸다. 남원 A(A_repel)·B(B_win)·C, 강릉 A, 한양 둘 모두 PASS, SCRIPT ERROR 0.

## 9. 시나리오 v2.2·v2.3 반영(데이터·작은 수정)

- **상태 변수**(story_state VAR_DEFAULTS)
  - 박규상 복선: `MAIN_PARK_MARK_COUNT`(int), `MAIN_PARK_NAME_KNOWN`(bool)
  - 숙련: `SKILL_GUARD_SHOVE`, `SKILL_QUICK_THROW`, `SKILL_EVADE_SLASH`, `SKILL_SNAP_SHOT`, `SKILL_BEAST_SIDESTEP`, `SKILL_TOOL_SLOT_PLUS`
  - 사건 완료 여덟: `CASE_NAMWON_COMPLETE`, `CASE_HANYANG_BOOKSHOP_COMPLETE`, `CASE_GANGNEUNG_COMPLETE`, `CASE_GYEONGJU_COMPLETE`, `CASE_HWANGJU_COMPLETE`, `CASE_PYONGYANG_COMPLETE`, `CASE_HAMHUNG_COMPLETE`, `CASE_JEJU_COMPLETE`
- **S1002 납품표**
  - 책 묶음 아래 (−253.5, −937)에 "반쯤 찢긴 납품표"가 있다. 조사 대상은 '책 묶음 · 들춰 보기'다.
  - 처음 보면 `MAIN_PARK_MARK_COUNT += 1`, `MAIN_PARK_NAME_KNOWN = true`.
  - 범죄 단서로 강조하지 않는다: 책방 단서 수(추격 조건)에 넣지 않고, 기록은 '평소 거래 기록' 어조다.
  - 허브에서는 책쾌가 치워 없다.
- **S1005**: 납품표를 봤으면 책쾌가 한 줄을 더한다(선택 없음): "박 객주? 종이값은 꼬박 치르는 큰손이오."
- **R0104 천안삼거리**(`story/vignettes_data.gd`, `scripts/story/vignettes.gd`)
  - 길가 장면 체계를 새로 만들었다(사건 기록 없음). 노정처럼 사건이 없는 공간에서도 돈다.
  - 길 북쪽 가(745, 6.8)에 곡물 가마니 셋과 포장 표식(朴), 상단 일꾼 둘이 선다.
  - 13m 안에 처음 들면 "상단 일꾼 “박규상 객주 물건은 날짜를 어기면 안 돼.”"가 나오고 `MAIN_PARK_MARK_COUNT += 1`이다. 저장 `progress.vignettes`에 남아 한 번만 일어난다.
  - **수레 모델은 키트 어디에도 없다**(새 모델 금지). 그래서 '수레에서 내려 쌓아 둔 짐'으로 보인다. 바퀴 고치는 수레는 수레 키트가 생기면 데이터에 더하면 된다.
- **남원 S0010**: 기록책 요약에 이겸의 한 줄을 더했다: "발자국은 한 번 남지만, 사람 말은 걸을수록 달라진다."
- **`朴` 표식 텍스처**: `assets/story/park_mark.png`(`tools/story/make_park_mark.py`, AppleMyungjo)
  - 한 그래픽 언어(붉은 백문 인장 + 한지·삼베)의 네 칸: 작은 인장 / 반쯤 찢긴 납품표(納品 紙二十束 墨十丁 朴奎祥客主) / 자루·포장 표식 / 운송장 한 칸(뒤 사건용)
  - `kit/story/park_mark.gd`(kind seal·slip·wrap·waybill)가 기존 소품 위에 얹는 판이다. 새 모델은 아니다.
- **전투 숙련(레벨 없음, v2.2 §6.1·§6.3.1, v2.3)** `scripts/story/skills.gd`
  - 해금표 `UNLOCK_CONDITION`: 갈래 중 하나라도 맞으면 열린다. 갈래가 배열이면 그 안의 조건이 모두 맞아야 한다.

    | 숙련 | 조건 |
    |---|---|
    | 받아밀기 | `CASE_NAMWON_COMPLETE` |
    | 빠른 투척 | `CASE_HANYANG_BOOKSHOP_COMPLETE` |
    | 회피베기 | `CASE_GANGNEUNG_COMPLETE` |
    | 빠른 사격 | `CASE_GYEONGJU_COMPLETE` |
    | 큰 짐승 흘리기 | `CASE_PYONGYANG_COMPLETE` 그리고 `SKILL_BEAST_TRACE` |
    | 보조도구 전환 | `CASE_HAMHUNG_COMPLETE` |

  - 사건이 끝나면(phase done) story_director가 `CASE_<case.complete_key 또는 id 대문자>_COMPLETE`를 세우고 표를 훑는다.
  - 결말 카드 뒤에 한 줄이 나온다: "새 행동을 익혔다 — 받아밀기". 레벨 문구는 없다.
  - 이 체계 전에 끝낸 저장도 불러올 때 조용히 해금한다. 체력·기력은 묶지 않는다.
  - 동작은 P0 둘만 있다(`scripts/combat/cplayer.gd`):
    - **받아밀기**: 막기를 누른 지 0.3초 안(`guard.timed`)에 앞발을 막으면 0.3초 밀치기(`shove`)를 하고, 범이 2.2m 밀려나며 움찔한다(`ctiger.shoved`).
    - **빠른 투척**: 떡을 걸음을 멈추지 않고 0.12초에 던진다. 거리·비행 85%, `quick_throw` 0.28초.
  - 프레임: `story_bake.html?set=skills` → `data/frames_story_skills.json`. 칼 든 플레이어 클립 `shove:a`·`quick_throw:a`, 각 5장이다. 이야기 틀이 시작할 때 플레이어 은행에 더한다.
  - 시험: `--allskills`(숙련 강제 + 대본 봇이 막기를 늦게 누르고 멀 때 던짐). namwon:A에서 받아밀기 84번, 빠른 투척 미끼를 확인했다.

## 10. 남은 것·알려진 문제

- 지붕 높이(시전 4.1, 기와집 4.3)는 화면으로 맞췄다. 지붕 메시를 따라가지는 않고 구간 시작 땅 높이 + y다.
- 우치가 지붕에서 지붕으로 건너는 틈(약 2.6m)도 같은 높이로 그냥 지나간다(뛰는 동작 없음).
- 추격 끝(광통교 남쪽)에서 우치는 '인파 속으로' 사라진다. 다리 남쪽 군중은 주변 인물(npc_ambient)에 맡겼다.
- 빈 창고 대문 칸은 기하상 열려 있다. S1005 전에 안으로 들어가도 책쾌는 보이지 않는다(`heard_thump` 전 숨김). 빗장 연출은 대화·조사뿐이다.
- 먼 도착(노들 남쪽 포털)은 암전 한 번으로 숭례문 앞까지 옮긴다. §28 "이동 대체 컷신 금지"와 부딪히지 않도록 노정 도착의 마무리로만 썼다. 포털을 숭례문 가까이 옮기는 것은 세계 쪽 결정이다.
- 소리가 없다(쿵 소리·포졸 외침은 자막·약한 흔들림).
- 추격 중 저장은 하지 않는다. 추격 도중 저장 파일이 남았으면 불러올 때 추격 앞(책방을 나서기 전)으로 되돌린다.
