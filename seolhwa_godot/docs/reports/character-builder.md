# 인물 빌더(character builder) — 1~3단계

문제: 인물을 하나씩 그리다 보니 모두 같은 사람이 옷만 바꿔 입고 돌아다니는 것처럼 보였다. 하나 그릴 때마다 토큰과 시간도 많이 들었다.
목표: 자료(JSON) 하나로 많은 사람을 만들고, 같은 리그와 같은 동작 묶음에 굽는다. 사용자가 승인한 순서 가운데 1~3단계를 했다. 4단계(본편 새 인물)는 아직 하지 않았다.

## 1. 조사와 설계

### 1.1 지금 그림이 만들어지는 길

| 단계 | 파일 | 하는 일 |
|---|---|---|
| 차림 | `seolhwa/src/chars/rigs.js` `SPECS` | 기본 몸 10개(player, villager_m/f, elder, child_boy/girl, hunter, innkeeper, miller, woodcutter, tiger). 키·체형은 `height`·`build`, 차림은 색과 깃발(`top`, `bottom`, `vest`, `hat`, `hair`, `back`, `staff` …) |
| 부위 | `rigs.js` `humanView` | 시점(front·side·back)마다 머리·몸통·치마·팔·다리 그림을 한 번 그린다(`painter.js` 먹선·담채·한지 결) |
| 자세 | `rigs.js` `humanBasePose`, `anims.js`(전투·이야기), `tools/pose_common.js`(sit·bow·kneel) | 시각 t의 관절 각 |
| 굽기 | `frameCore.js` `BakeBank` | 그림마다 팔·다리·몸통·치마를 곡선 따라 휘어 다시 그린다(띠 워프). 컷아웃이 아니라 프레임 그림이다. 1024² 페이지에 담는다 |
| 내보내기 | `tools/export_*_frames.js` + `*_bake.html` | 종류마다 `SPECS`에 `{base, over}`를 실행 중에만 더해 굽는다. 결과는 `data/frames_*.json` + PNG(git 밖) |
| Godot | `scripts/sprite_char.gd` | `_banks[kind] = {pages, clips}`. `merge_bank`, `ensure_poses`(frames_pose.json) |
| 고을 사람 | `scripts/region/npc_ambient.gd` | 역할(`PEOPLE_KIND`: 농부·상인…) → 종류 하나. `frames_npc.json`(9종) + `frames_amb.json`(14종 + 짐승) |
| 군중 | `scripts/story/event_crowd.gd` | `GENERIC` 26종 중에서 `bank`로 고른다 |
| 이야기 인물 | `story_director.BANK_FILES`·`KIND_FALLBACK`, 사건 자료 `{chr: "CHR_HUM_015", kind: "innkeeper"}` | `CHR_HUM_*`(generic 26) → kind 하나 |

### 1.2 그대로 쓸 수 있는 것
- 굽기 엔진 전부: 띠 워프, 스프링, 같은 그림 재사용(sig), 번짐, 먹선 떨림. 같은 화풍이 그대로 나온다.
- `painter.js` 붓 도구, `rigs.js`의 차림 그림(저고리·두루마기·치마·배자·행전·지게·봇짐·삿갓·갓·벙거지·광주리·담뱃대·지팡이).
- 공용 자세 `pose_common.js`(sit·bow·kneel), Godot 프레임 꼴(`spec`, `frames[{page,u,v,x,y,lift}]`)과 `SpriteChar`.
- `dress_art.js`의 부속 붙이기 방식(`addPart` — 머리·몸통·손을 따라 움직이는 덧부위).

### 1.3 다양성을 막던 것
1. **몸이 둘뿐이다.** `ADULT`·`CHILD` 골격 두 개에 `build`가 어깨·허리 폭만 바꾼다. 키는 `ppm`(그림 배율)만 바꿔서 1.5m 사람과 1.75m 사람의 비례가 똑같다. 청소년이나 노인 체형, 머리 크기, 다리 길이가 없다.
2. **얼굴이 하나다.** `faceFront`/`faceSide`가 눈·눈썹·코·입을 모두 같은 자리, 같은 꼴로 그린다. 다른 것은 볼 연지, 입술 색, 눈썹 굵기, 주름 있음/없음, 흰 수염 하나뿐이다. 얼굴 윤곽은 모두 같은 타원이다.
3. **머리 모양·쓰개가 적다.** 상투, 쪽, 댕기, 아이 머리, 짧은 머리 / 갓, 삿갓, 벙거지가 전부다. 정자관·패랭이·전립·사모·족두리·남바위·조바위·떠꺼머리·얹은머리·삭발이 없다.
4. **차림이 손으로 쓴 표다.** 고을 사람 23종을 `{base, over}`로 하나씩 적었고, 역할 하나에 그림 하나다. 장터에 상인이 열 명 있어도 모두 같은 상인이다.
5. **물감이 정해져 있다.** 신분이나 고을에 따른 염료 치우침, 해짐, 흙때가 없다(덧댐 하나는 있다).

### 1.4 빌더 설계

**인물 = 자료(JSON)**:
```json
{ "id": "jl_farmer_0", "template": "farmer", "region": "JL", "seed": "farmer.0", "role": "farmer",
  "body":  { "sex": "m", "age": "adult", "build": 1.08, "height": 1.63, "stoop": 0, "head": 1.02, "legs": 0.98 },
  "face":  { "shape": "square", "brows": "thick", "browW": 1.1, "eyes": "droopy", "eyeSize": 0.95, "eyeGap": 0.41, "nose": "broad",
             "mouth": "thin", "mouthY": 0.6, "wrinkles": 1, "mark": "mole_cheek", "beard": "stubble", "moustache": "none",
             "skin": "#e0bd92", "cheek": 0.15 },
  "hair":  { "style": "sangtu", "color": "#2c2724" },
  "clothes": { "top": "jeogori", "outer": "none", "vest": "baeja", "bottom": "baji", "sash": "none", "shoes": "jipsin", "legwrap": true, "apron": false },
  "colors":  { "coat": "#e2d6b8", "pants": "#d8ccb0", "vest": "#46627b" },
  "headwear": "band",
  "items": { "back": "jige", "load": "wood", "head": "none", "hand": "none", "handLoad": "none" },
  "wear": 0.6, "dirt": 0.5 }
```

| 칸 | 값 |
|---|---|
| body | sex m/f · age child/youth/adult/elder(골격: 아이 / 아이·어른 0.8 섞음 / 어른 / 어른+굽음) · build(어깨·허리) · height(m) · stoop · head(머리 크기) · legs(다리 길이) |
| face | shape oval·round·long·square·heart(앞 윤곽 턱 넓이, 옆 코·턱) · brows thin·thick·arched·straight·droop·sparse(+굵기·색) · eyes narrow·round·droopy·upturned·sleepy·small(+크기·사이) · nose small·long·broad·hooked · mouth small·wide·thin·full·smile·frown(+높이) · wrinkles 0~3(이마 → 팔자·눈가 → 눈밑·입가) · mark 점(볼·입가·눈썹)·마맛자국·주근깨·흉터 · beard 없음·거뭇·염소수염·텁석부리·긴 수염 · moustache 없음·가는·짙은·처진 · skin(7단계 범위) |
| hair | 상투(망건 또는 수건 띠) · 쪽머리(비녀) · 댕기머리 · 떠꺼머리(혼인 전 사내, 등에 땋은 꼬리) · 얹은머리 · 승려 삭발 · 아이 머리 · 짧은 머리. 혼인 전 머리에는 갓·관을 씌우지 않는다 |
| clothes | top 저고리/짧은 저고리 · outer 두루마기·도포(넓은 소매 + 세조대)·쾌자(소매 없는 겉옷 — 안 저고리 소매색)·장삼(넓은 소매)·장옷·쓰개치마(머리부터 덮음) · vest 배자·털배자 · bottom 바지/치마 · sash 붉은 띠·세조대·가사·허리띠 · legwrap 행전 · apron · shoes 짚신·미투리·태사혜·꽃신·버선 |
| headwear | 갓 · 정자관 · 패랭이 · 삿갓 · 벙거지 · 전립 · 사모 · 족두리 · 남바위 · 조바위 · 머릿수건 · 수건 띠 |
| items | back 지게(짚·장작)·봇짐·괴나리봇짐 · head 광주리·물동이 · hand 지팡이·장죽(담뱃대)·합죽선·둥근 부채·국자·도끼·방울 · handLoad 바구니·보자기(carry 동작에서 손에 든다) · pipe(입의 곰방대) |
| colors | 옷감마다(coat·pants·skirt·vest·inner·goreum·cuff·collar·cloak·cord·gasa·sash·bundle·ribbon·scarf) |
| wear·dirt | 0~1. wear는 물감을 바래게 하고 0.35를 넘으면 사내 바지에 덧댐을 더한다. dirt는 아랫단·무릎·소매에 흙빛 얼룩을 입힌다 |

**물감**(`DYES`): 바탕(흰 무명·소색·바랜 무명·삼베·회백), 서민 물(쪽 연·쪽·짙은 쪽·감물·갈옷·밤색·황토·치자·잿빛·먹), 비싼 물(옥색·하늘·남·다홍·연지·자주·연두·송화·분홍·청록·검정·노랑·보라). 서민 틀은 고을의 `natural` 비율(전라 0.62, 강원 0.7, 제주 0.4 + 갈옷 0.6)만큼 바탕 쪽으로 치우친다. 비싼 물은 양반·기생·혼례 틀만 쓴다.

**고을**(`REGIONS`, 권역 앞 두 글자): 물 빈도, 바탕 비율, 피부 쪽 치우침, 북쪽(황해·평안·함경)의 남바위·조바위·털배자, 평안·함경의 얹은머리, 제주의 갈옷이 다르다.

**틀(template)과 무작위 범위**(`TEMPLATES` — 나이 무게, 체형·키 범위, 차림 확률):

| 틀 | 범위의 요지 |
|---|---|
| 양반(남) yangban_m | 어른·노인, 1.62~1.75m, 도포 65%/두루마기, 세조대, 갓 85%/정자관, 태사혜, 수염(염소·텁석·긴), 부채·장죽·지팡이, 해짐 0~0.12 |
| 양반(여) yangban_f | 짧은 저고리(송화·옥색·분홍…) + 남·다홍·자주 치마, 회장, 쪽/얹은머리, 장옷 45%, 북쪽은 조바위 |
| 선비 seonbi | 청년·어른, 마른 체형, 흰·옥색 두루마기/도포, 갓(청년은 30%가 떠꺼머리 맨머리), 부채, 괴나리봇짐 15% |
| 중인 jungin | 쪽 연·잿빛 두루마기, 챙 좁은 갓, 배자 30%, 미투리 |
| 아전(서리) ajeon | 쪽·남·먹 두루마기, 갓/벙거지, 허리띠 |
| 포졸·사령 pojol | 쾌자(먹·짙은 쪽) + 흰 안 소매, 붉은 띠, 벙거지 70%/전립, 행전, 막대 80% |
| 농부 farmer | 바탕 무명 저고리·바지, 배자 30%, 수건 띠/패랭이/삿갓/맨상투(북쪽 남바위), 지게 35%, 해짐 0.3~0.85, 흙 0.25~0.75 |
| 장꾼(상인) jangkkun | 배자 60%, 갓·패랭이·삿갓·수건 띠, 봇짐·지게, 보자기 든 손 35% |
| 보부상 bobusang | 패랭이, 지게 70%/봇짐, 행전, 지팡이 50% |
| 나그네 traveler | 잿빛·바랜 두루마기, 갓·삿갓·패랭이, 괴나리봇짐 70%, 지팡이 60% |
| 뱃사공 boatman | 삿갓·수건 띠, 삿대, 그을린 피부 |
| 주모 jumo | 짧은 저고리 + 밤색·쪽·감물 치마, 앞치마 70%, 머릿수건 55%, 국자 45% |
| 아낙 ajimae | 바탕 저고리 + 쪽·밤색·잿빛 치마, 쪽(청년은 댕기), 머릿수건, 광주리·물동이, 바구니·보자기, 쓰개치마 8% |
| 해녀 haenyeo | 흰 물옷, 머릿수건, 바구니 |
| 천민(노비·백정) cheonmin | 삼베·회백 옷, 패랭이·수건 띠, 떠꺼머리 25%, 해짐 0.55~1, 흙 0.45~0.9 |
| 승려 monk | 잿빛 장삼(넓은 소매), 가사 55%, 삭발, 삿갓 40%, 지팡이, 바랑 |
| 무당 mudang | 흰·노랑 저고리 + 다홍·남 치마, 쾌자 50%, 전립 가끔, 부채·방울 |
| 기생 gisaeng | 얹은머리, 비싼 물 회장저고리, 장옷 30%, 둥근 부채, 연지 짙게 |
| 아이 child | 아이 골격, 사내아이(아이 머리·떠꺼머리·짧은 머리)/계집아이(댕기), 색동은 드물게 |
| 노인(남·여) elder_m·elder_f | 흰·잿빛 머리, 굽음 0.1~0.3, 지팡이, 긴 수염, 북쪽 남바위·조바위 |

얼굴은 틀과 따로 모든 사람이 고른다. 윤곽 5 × 눈썹 6 × 눈 6 × 코 4 × 입 6 × 점·자국 7 × 피부 7에 굵기·크기·사이·높이 연속값이 더해진다.

**동작 묶음**(모든 사람 같음 — `char_builder.ANIMS` 15개): idle · walk · run · talk · sit · sit_seat · sit_down · stand_up · sit_talk · sit_work · squat · bow · kneel · carry · jump.
- sit은 땅에 앉기다. 사내는 양반다리로, 여인(빌더 `sitStyle: 'knee'`)은 한쪽 무릎을 세우고 다른 다리는 접어 깐다. sit_seat는 평상·걸상·의자·툇마루 끝에 걸터앉기(발은 땅)다.
- sit_down·stand_up은 서기와 땅에 앉기 사이를 한 번 오간다(7장, 대기 자세와 sit 자세를 섞음).
- sit_talk는 앉아서 손짓하며 부르거나 말하는 동작이다(부채·장죽·국자·방울은 손에 보인다). sit_work는 앉아 물건을 매만지거나 먹는 동작으로, 손을 앞 아래로 뻗었다가 가슴께로 가져온다. squat는 쪼그려 앉기다.
- carry는 걷기 다리에 짐에 맞춘 팔을 얹는다. 이고 가면 한 손으로 받치고, 지고 가면 두 손으로 멜빵을 잡고, 들고 가면 한 팔을 곧게 늘어뜨려 손 짐이 보인다.
- jump는 한 번 동작이다(10장): 웅크림(팔 뒤로) → 박차기(팔 앞·위로) → 공중(다리 접음, 그림 높이 약 0.45m) → 착지 눌림(팔 앞으로 받침) → 서기. 앞·옆·뒤 모두 있고, 팔은 고친 흔들기와 같은 규칙(앞뒤 모습은 몸 옆에서 위·옆으로)을 따른다. 긴 옷은 무릎을 덜 접는다.
- 고을 사람 묶음은 run·sit_down·stand_up을 뺀다(돌아다니는 사람이 쓰지 않음). carry는 짐 든 사람만 굽는다.

**만드는 길**: `generate({template, region, seed, count})` → 자료 → `compile` → rigs `SPECS`(+ `sp.S` 골격, `sp.drawHead` = 빌더 머리, `sp.partFx`·`limbFx` = 흙때, `sp.staff` = 손 소품 함수, `sp.sleeveW`·`armCoat`) → `getRig` → 덧부위(장옷·세조대·가사·손 짐) → 공용 자세 → `BakeBank`. 실행 중 인형이 아니라 굽기 때 그림마다 합성한다.

## 2. 팔 버그 — 원인과 고침(공용 리그, 모든 인물)

**원인**(`seolhwa/src/chars/rigs.js` `humanBasePose`, 굽기 `frameCore.js`):
- **옆 걷기**: 팔 부위 기본 각 r0(위팔 0.06~0.1, 아래팔 0.12~0.15)이 앞쪽이었다. 걷기는 여기에 아래팔 굽힘 `0.15 + 0.35·max(0, …)`를 늘 더했다. 그래서 위팔이 뒤로 가도 손은 엉덩이 앞에 남았고, 손이 몸 뒤로 한 번도 가지 않았다(늘 앞으로 내민 팔).
- **앞·뒤 걷기**: 흔들기가 0.07rad의 옆 흔들림과 약한 짧아짐뿐이었다. 다리와 반대로 흔드는 모습이 없었다.
- **앞·뒤 뛰기**: 아래팔을 ±0.6rad 안쪽으로 접어 배 앞을 가로질렀다(팔을 앞으로 모아 내민 모습).
- **앞 대화**: 손짓하는 아래팔(−1.3)이 배 앞을 가로질렀다.
- 굽기 그림 순서(z)가 부위마다 고정이어서, 앞뒤 모습에서 뒤로 간 팔도 몸통 위에 그려졌다.

**고침**:
- 옆 걷기: 위팔은 다리와 반대로 ±0.36(치마는 0.8배)만큼, 반 박자 늦게 흔들고, r0를 상쇄하는 뒤쪽 치우침을 두었다. 아래팔은 뒤로 갈 때 거의 곧게(−0.1), 앞으로 갈 때만 0.42까지 굽는다. 뛰기는 팔꿈치를 굽힌 채(1.0 + 0.35) ±0.62로 흔든다.
- 앞·뒤 걷기: 팔은 몸 옆에 늘어져 다리와 반대로 깊이 방향으로 흔든다. 앞으로 간 팔은 손이 조금 안쪽으로 오고 아래팔이 짧아진다(팔꿈치 굽음). 뒤로 간 팔은 손이 엉덩이 뒤로 숨는다. **카메라에서 먼 쪽으로 간 팔은 몸통 뒤에 그린다**: 자세가 `P.arm.z`를 주면 `frameCore._drawHuman`이 그 그림만 순서를 바꾼다.
- 앞·뒤 뛰기: 손은 허리께 몸 옆에 둔다. 아래팔은 카메라 쪽으로 접혀 짧아진다(0.62 → 0.32).
- 앞 대화: 아래팔을 몸 밖으로 들어 손바닥을 보인다. 옆 대화는 조금 낮췄다.
- carry(새 동작): 이고·지고·들고 세 가지 팔.
- 대기(idle)는 r0만큼 앞으로 늘어진 그대로다. 사람이 서 있을 때 자연스러운 정도라 고치지 않았다.

**다시 굽기**(같은 차림, 클립 목록도 예전과 똑같음 — 파일별로 확인): frames.json(player — 지금 파일의 클립 53개를 그대로, tiger는 그대로) · frames_npc · frames_amb · frames_story(기본·hanyang·hwangju·namwon_chunhyang·chunhyang_part2) · gangneung · gyeongju · pyongyang · hamhung · jeju · stable(마부).
- 춘향·몽룡도 같은 차림으로 다시 구웠다(팔만 달라짐).
- 다시 굽지 않은 것: frames_pose(sit·bow·kneel), namwon_rope(rope_up), skills(전투), ride·boat(말·노 젓기 전용 자세). 이것들은 걷기·뛰기·대화를 쓰지 않는다.

**화면** (`shots/char_builder/`):
- `arm_<kind>_before.png` / `arm_<kind>_after.png`: player · villager_m · villager_f · mongryong · chunhyang · pojol. 줄은 차례로 front·back·side walk, front·back·side run, front·side talk다.
- `arm_player_compare.png` · `arm_villager_m_compare.png`: 왼쪽이 전, 오른쪽이 뒤.

## 3. 빌더와 미리 보기 — 쓰는 법

**파일**:

| 파일 | 하는 일 |
|---|---|
| `tools/char_builder.js` | 자료 꼴 · `OPTIONS`(고를 값) · `DYES`·`REGIONS` · `TEMPLATES`(20틀) · `generate()` · `compile()` · `registerSpec()` · `PRESETS` · 권역 무리 `POOL`·`poolSpecs()` |
| `tools/char_parts.js` | 빌더 머리(얼굴·머리·쓰개·머리 짐) · 덧부위(장옷·쓰개치마·세조대·가사·손 짐) · 손 소품 · 흙때 |
| `tools/pose_common.js` | 공용 자세 + 새 동작(sit_seat·sit_down·stand_up·sit_talk·sit_work·squat·jump, 여인 sit) |
| `tools/character_builder.html` | 미리 보기·편집 |
| `tools/export_char_frames.js` + `chars_bake.html` | 묶음 굽기 → `data/chars/<set>.json` + 2048² 페이지 |
| `tools/sheet_bake.js` + `sheet_bake.html` | 확인용 동작 표(`?kinds=…&anims=…&views=…`, `builder:<틀>#<시드>@<권역>`, `layout=grid`) |
| `scripts/char_bank.gd` | Godot 로더: id → 묶음, 페이지 공유, S3TC |

**미리 보기** — `python3 tools/web_export_server.py 8770`(launch.json `seolhwa-web`) → `http://localhost:8770/__tools/character_builder.html`
- 왼쪽: 틀·고을·프리셋·시드, 몸·얼굴·머리·옷·물감·소품·해짐 슬라이더와 드롭다운. **Randomize**는 새 시드, 「같은 틀 다음」은 시드 +1이다.
- 가운데: 동작(15개)을 앞·옆·뒤로 움직여 보인다. 바꿀 때마다 그 동작 하나만 굽는다(약 0.1초, 120px/m). 「묶음 만들기」(개수)와 「모든 틀 하나씩」은 썸네일 격자를 만들고, 누르면 편집기로 들어온다.
- 오른쪽: 자료 JSON(고쳐서 「적용」). 「자료 내려받기」·「묶음 자료 내려받기」(JSON), 「자료 저장」(`data/chars/specs/<id>.json`), 「이 인물 굽기」·「묶음 굽기」(묶음 이름 → `data/chars/<이름>.json`, 모든 동작, 96px/m).
- 주소로 바로 열기: `?preset=jumo` · `?template=farmer&region=JL&seed=3&anim=jump` · `&grid=all`.

**코드에서**:
```js
import * as B from '/__tools/char_builder.js';
const list = B.generate({ template: 'jangkkun', region: 'GG', seed: 7, count: 12 });   // 같은 인자 → 같은 12명
const id = B.registerSpec(list[0]);            // SPECS에 올림 → BakeBank(id)로 굽기
const E = await import('/__tools/export_char_frames.js');
await E.bakeSet('my_set', list, { px: 96, anims: B.ANIMS });   // data/chars/my_set.json
```
새 인물은 자료만 더하면 된다(틀을 고르거나 JSON을 쓴다). 그리는 코드는 건드리지 않는다.

**프리셋**(`PRESETS`, 묶음 `presets`, 모든 동작, 116px/m — 예전 high와 같음): `p_jumo`(innkeeper) · `p_bangja` · `p_pojol` · `p_villager`(villager_m). 색·키·체형·차림을 예전 차림 표에서 그대로 옮겼다.
- 비교 `preset_compare_grid.png`(왼쪽 예전, 오른쪽 빌더 — 앞·옆·뒤 대기·걷기): 주모·방자·포졸·마을 사내 모두 같은 사람으로 읽힌다. 다른 점은 포졸 수염 그늘이 조금 옅은 것 정도다.
- 이야기 인물 kind는 지금 그대로다(춘향·몽룡 등은 재굽기만). 이야기 자료에서 kind를 `p_jumo`처럼 빌더 id로 쓰면 `story_director._ensure_bank` → `CharBank.ensure`가 찾는다.

**Godot 로더**: `CharBank.ensure(id)`는 그 묶음 페이지를 읽어 `SpriteChar._banks[id]`에 올리므로, 그 뒤로는 `SpriteChar.new(id)`를 쓴다. 그 밖에 `ids(set, role)`, `region_set(region_id)`, `bank_src()`(작업 스레드에서 읽는 쪽), `stats()`가 있다.
- 예전 `frames_*` 꼴과 로더는 그대로다. 빌더 묶음은 새 경로(`data/chars/`)만 쓴다.

**다양성 표** `variety_42.png`: 21틀 × 시드 둘 × 고을 여섯, 42명. 칸마다 앞·옆 대기, 앞·옆 땅에 앉기, 앞·옆 뛰기(공중). 얼굴 윤곽, 수염, 쓰개, 머리, 차림, 물감, 체형, 키가 모두 다르다.

## 4. 고을 사람·군중(3단계)

**바꾼 것**:
- `npc_ambient`: 사람 역할(농부·아낙·상인·마을 사내/아낙·노인·아이·선비·관속·보부상·나그네·주모·스님·뱃사공·해녀·무당)은 권역 빌더 묶음 `amb_<권역>`의 여러 사람에서 칸 번호 해시로 고른다. 같은 칸이면 다시 와도 같은 사람이다. `ROLE_VARIANTS`가 노인 ↔ 노파, 마을 사내 ↔ 천민·중인, 선비 ↔ 양반, 관속 ↔ 포졸을 섞는다.
  - 묶음에 없는 역할(도롱이·포수·방앗간·나무꾼·목자·보살)과 짐승은 예전 그림을 쓴다. 짐을 든 빌더 사람은 걸을 때 carry로 걷는다.
  - 말 걸기 내용은 역할(kind)로 정하므로 그대로다.
- `event_crowd`: generic 고을 사람 kind는 그 권역 빌더 사람으로 그린다(군중 id·순번 해시). 계획(plan)의 kind·역할·자리는 그대로다. 관속·포졸·서리·기생 generic은 예전 그림이다.
- `--nobuilder`로 둘 다 예전 그림으로 돌릴 수 있다(비교·측정용).

**권역 무리**(`POOL` — 공간당 고유 인물 상한 `POOL_CAP` 36): 기본은 농부 5, 아낙 5, 상인 4, 마을 사내·아낙 3, 노인·노파·아이 둘씩, 선비·관속·보부상·나그네 둘, 주모·스님·천민·양반·뱃사공 하나다. 고을마다 더하거나 뺀다.
- 한양: 양반·양반 여인·중인·포졸·기생을 더한다.
- 제주: 해녀 셋, 무당을 더한다.
- 평양: 기생·상인을 더한다.
- 남원: 기생·포졸을 더한다 …
- 36을 넘으면 가장 많은 역할부터 덜어 낸다. 여덟 권역 288명이고, 권역마다 시드가 달라 같은 사람이 없다.

**앉은 사람**(사용자 의견 반영: "장터나 건물, 가판에 앉은 캐릭터가 들어가야지 죄다 서 있고 팔려는 이들이 없네"):
- 자리는 키트 앵커에서 저절로 나온다(`world.props.anchor`, 키트 build의 `m.anchor`). 앵커가 없는 키트는 로컬 자리를 쓴다. 표는 `npc_ambient.SEAT_KIT`.

| 자리 | 키트(앵커) | 사람 · 앉음새 · 동작 |
|---|---|---|
| 장꾼 vendor | 좌판 `jwapan`(seller) · 가가 `market_shop`(seller) · 시전 `hy_sijeon`(counter_w·e) | 물건(`goods`)에 맞는 사람 — 생선: 아낙·상인(제주는 해녀) / 포목: 상인 / 옹기: 상인·사내·노인 / 곡식·채소: 아낙·농부 / 짚: 농부·사내 / 섞음: 아낙·상인·노인. 땅에 앉음 55~70% · 낮은 걸상 10~25% · 서서 팔기 20%. 앉으면 sit ↔ sit_talk(부르기) ↔ sit_work(물건 매만지기)를 3~9초마다 바꾼다(부채·장죽은 손에 보인다) |
| 주막 손님 guest | `jumak`(guest_seat — 평상 위) | 나그네·보부상·사내·노인·상인 셋, 평상 위에 나란히 앉아 먹기(sit_work)·말하기 · 밤에도 |
| 평상 platform | `props` pyeongsang(seat) · `village_square`(pyeongsang·seat) | 노인·사내·아낙·아이 |
| 툇마루·문간 maru | 집 키트(`*maru` 앵커, 앵커 없는 초가는 앞면) | 노인·노파가 마루 끝에 걸터앉음(sit_seat) · 집마다 10%(도성 5%) |
| 나무 그늘 rest | `big_tree` | 줄기 둘레에 둘이 앉거나 쪼그림 |
| 정자 pavilion | `jeongja`(floor) | 선비·노인 |
| 나룻배 boatman | `narutbae`(boatman) | 사공이 배 위에 앉음 |
| 관아 앞 petition | 관아·동헌 앞 2.6m | 쪼그려 기다리는 백성(squat) |

- 앉은 사람은 자리를 떠나지 않고 길·손님 쪽(키트 앞)을 본다. 앉은 그림은 빌더 사람만 갖고 있어서 앉는 자리에는 빌더 역할만 앉힌다. 높이는 평상·배·정자처럼 앵커 위에 앉을 때는 앵커 높이로, 걸터앉기·쪼그림·서서 팔기는 땅 높이로 둔다.
- 말 걸기: 땅에 앉은 사람은 앉은 채 sit_talk로 말하고, 끝나면 하던 자세로 돌아간다.
- **이야기와 겹치지 않게**: `seat_taken(p)`가 보이는 이야기 인물(`story.actors`, 1.4m 안)과 켜진 사건 군중 자리(`crowd.crowds[].members.home`, 1.2m 안)를 본다. 그 자리에는 앉히지 않고, 앉아 있다가 이야기 인물이나 군중이 오면 바로 놓는다(화면 안이어도). 비우기 구역(C63 `excluded`)도 그대로 적용된다.
- 고을 밖 집·나무·평상은 비워 둔다. 밤에는 주막 손님만 남는다(날씨·밤 계수는 다른 고을 사람과 같다).

**메모리·속도**:
- 고을 사람 묶음은 84px/m이고, 대기 2장과 run·sit_down·stand_up 빼기(`lean`)로 그림을 줄였다.
- 2048² 공유 아틀라스에 담고(채움 0.81~0.87), Godot에서 읽을 때 **S3TC(DXT5)로 압축**한다. 한 장 22MB(RGBA+밉맵)가 5.6MB가 되고, 압축은 장당 약 10ms다. 먹선과 한지 테에서 차이는 눈에 띄지 않았다.
- 권역 하나는 36명, 12~13장, 약 73MB다. 그 권역 묶음만 작업 스레드에서 읽는다(lazy). 쓰는 역할의 사람만 올리며, 페이지는 군중과 공유한다.

**측정**: 1920×1080 창(렌더 2560×1440), 맑음 11시, `--bench=20 --benchspeed=1.2`(장터 안을 천천히 걸음), `--nostory`. `--nobuilder`(전)와 빌더(뒤)를 번갈아 쟀다. 사용자의 다른 Godot이 함께 돌고 있어서 fps는 ±10 잡음이 있다.

| 곳 | fps 전 → 뒤 | p99 ms | 첫 불러오기 s | 인물 텍스처 MB(장) | 텍스처 VRAM 전체 MB | 고유 얼굴(그림) 수 / 사람 | 화면 안 사람 |
|---|---|---|---|---|---|---|---|
| 남원 장(-3293,375) | 95.9 → 99.2 | 14.3 → 11.7 | 3.5 → 3.8 | 229(43) → 133(25) | 838 → 742 | 8 → 26 / 150·142 | 22 → 23 |
| 한양 운종가(-168,-876) | 78.2 → 75.3 | 16.8 → 14.7 | 7.3 → 8.9 | 229(43) → 128(24) | 818 → 716 | 8 → 21 / 150·155 | 25 → 62 |

- 인물 텍스처가 약 100MB 줄었다(S3TC). 고유 그림은 8종에서 21~26명으로 늘었다. 그리기 호출은 비슷하다(사람 하나에 그림·테두리·그림자 셋, 예전과 같음).
- 한양은 앉은 장꾼·평상 사람이 붙어 화면 안 사람이 25에서 62가 됐는데도 fps 차이는 잡음 안이다.
- 첫 불러오기는 0.3~1.6s 늘었다. 2048² PNG 풀기와 압축 때문이고, 작업 스레드에서 하므로 불러오기 화면 안이다.
- 첫 채우기 때 NPC 갱신 한 프레임이 약 135ms인 것은 `--nobuilder`에서도 똑같다(예전부터 있던 것 — 사람 150명을 한 번에 놓음).

화면(`shots/char_builder/before|after/`):
- `jl_namwon_jang`: 남원 장. 전에는 모두 서 있고 장꾼이 없었다. 뒤에는 옹기·채소·짚 좌판 뒤에 장꾼이 앉아 있다.
- `gg_ungjongga`: 한양 운종가. 전에는 같은 그림이 반복됐다. 뒤에는 차림·쓰개 색이 사람마다 다르다.
- `jl_jumak`: 요천 나루 주막. 뒤에는 평상에 손님 둘이 앉아 있다.
- after만 있는 것:
  - `jl_seat_maru`: 툇마루에 걸터앉은 아낙.
  - `jl_seat_guest`
  - `jl_seat_rest`: 나무 그늘.
  - `jl_seat_platform`
  - `jl_seat_pavilion`: 정자.
  - `jl_seat_boatman`: 배 위 사공.
  - `gg_seat_petition`: 관아 앞에 쪼그린 백성.
  - `gg_seat_guest`
  - `gg_seat_platform`
  - `gg_seat_boatman`
- `namwon_market_after.png`: 앉은 자리 이전, 빌더 사람만 들어간 첫 화면.

## 5. 동작 화면
- `anim_sit_jump.png`: 아낙(여인 앉음새)과 농부. sit · sit_seat · jump × 앞·옆·뒤.
- `anim_seated_actions.png`: 주모·장꾼. sit_talk · sit_work · squat · sit_down · stand_up · carry × 앞·옆.
- jump를 게임에 붙이는 법(이번에는 하지 않음 — 물리·조작 없음):
  - `SpriteChar.play("jump", true)`로 재생하고, `anim_duration("jump")`(0.9초) 뒤에 원래 동작으로 돌린다.
  - 그림이 몸을 띄우므로(프레임 `lift`, 발 그림자가 옅어짐) 높이를 따로 움직이지 않아도 제자리 뛰기로 보인다.
  - 앞으로 뛰게 하려면 0.33~0.72초(공중 구간) 동안만 노드를 진행 방향으로 옮긴다.
- 앉고 일어나기: `play("sit_down")` → 끝나면 `set_anim("sit")`, 일어날 때는 `play("stand_up")` → `idle`.

## 6. 다시 굽기(data/는 git 밖)
`python3 tools/web_export_server.py 8770`을 띄우고 **앱 브라우저 창**(헤드리스 Brave는 멈춘 적이 있음)으로 차례로 연다. 페이지마다 수 초에서 1분이다.
1. 빌더 묶음:
   - `__tools/chars_bake.html?set=presets` → `data/chars/presets.json`(+ `presets_<n>.png`)
   - `__tools/chars_bake.html?set=amb_all` → `data/chars/amb_<JL|GG|GS|GW|HH|PA|HG|JJ>.json`(+ 페이지). 권역 하나만이면 `?set=amb_JL`.
2. 팔 고침 반영(예전 굽기 다시 — 같은 차림):
   - `__tools/core_bake.html` → frames.json(player)·frames_npc.json
   - `__tools/npc_bake.html` → frames_amb.json
   - `__tools/story_bake.html`, `?set=hanyang`, `?set=hwangju`, `?set=namwon_chunhyang`, `?set=chunhyang_part2`
   - `__tools/gangneung_bake.html` · `gyeongju_bake.html` · `pyongyang_bake.html` · `hamhung_bake.html` · `jeju_bake.html` · `stable_bake.html`
3. 확인 표: `__tools/sheet_bake.html?…` → `data/_sheets/<name>.png`
- 묶음 파일이 없으면 고을 사람·군중은 예전 그림으로 돌아간다(빌더 앉은 자리는 생기지 않음).

## 7. 시험
모두 마지막에 한 번씩, 한 번에 하나만 돌렸다(실제로 돌린 것).

| 시험 | 결과 |
|---|---|
| `tools/story/validate_event_class.gd` | EVENTCLASS PASS checked=170 (exit 0) |
| `tools/story/validate_case_meta.gd` | CASEMETA PASS 9 warn=5 |
| `tools/story/validate_problems.gd` | PROBLEMS PASS 9 problems=5 |
| `tools/story/map_leads_test.gd` | MAPLEADS PASS fixtures=69 |
| `tests/registry/case_registry_test.gd` | REGTEST PASS 47 |
| `tests/audio/sound_test.gd` | SOUNDTEST PASS 50 |
| `tests/onboarding/onboarding_rule_test.gd` | ONBOARDRULE PASS 64 |
| `tests/commonize/commonize_test.gd` | COMMONTEST PASS 49 |
| `tests/activity/activity_test.gd` | ACTIVITYTEST PASS 71 |
| `tests/camera/camera_view_test.gd` | CAMVIEWTEST PASS 27 |
| `tests/char_builder/char_bank_test.gd` (새) | CHARBANK PASS 208 — 프리셋 넷 × 동작 15 × 시점 3, 권역 여덟(인물 24~36·페이지 ≤14·역할·id·그림 크기), 뛰기 once·높이, 앉기 2장, SpriteChar carry 위상, 짐 든 사람만 carry, 권역 이름, 다양성 |
| `tools/run_story_tests.sh` 전체 | **75/75 PASS, SCRIPT ERROR 0** — 원래 73 + 새 `seat:namwon`·`seat:hanyang`(SEATTEST: 장꾼 38명 중 앉은 32 > 선 6, 자리 지킴, 이야기 인물·군중 자리 비움, 앉은 채 말 걸기, 평상 손님·툇마루 자리) |
| 묶음 다시 구운 뒤 | CHARBANK PASS 208 · `run_story_tests.sh seat` 2/2 PASS(마지막 자세 다듬기 뒤 다시 확인) |

새 시험 돌리기: `godot --headless --path . -s res://tests/char_builder/char_bank_test.gd` · `tools/run_story_tests.sh seat`.

## 8. 남은 것(4단계 — 본편 새 인물, 하지 않음)
- 본편 새 인물을 빌더 자료로 만들기: 설정 문서의 인물마다 틀 + 고정 자료(얼굴·차림 지정). 굽기 묶음은 `story_<사건>`으로 하고, 이야기 자료 kind에 빌더 id를 넣는다.
- 기존 이야기 인물(춘향·몽룡·향단·월매·변학도·기생 등)을 프리셋으로 옮길지는 사용자가 판단한다. 지금은 예전 그림을 재굽기만 했다.
- 짐 소품을 장꾼 곁에 두는 것(내려놓은 지게·광주리)은 하지 않았다. 지금은 키트 자체의 물건과 인물이 든 짐뿐이다.
- 군중 generic 관속·포졸·기생도 빌더 묶음으로 옮길 수 있다(지금은 예전 그림).
- 도롱이·포수·방앗간·나무꾼·목자·보살 틀을 빌더에 더하면, 고을 사람의 예전 그림 페이지(약 14장 1024²)를 마저 뺄 수 있다.
- 시전(hy_sijeon) 장꾼은 앵커가 가게 앞이어서 가게 앞 땅에 앉는다. 마루 안쪽에 앉히려면 키트에 seller 앵커를 더해야 한다.
- 앞모습 sit_seat에서 두루마기·치마를 입은 사람은 자락이 다리를 덮어 서 있는 것과 비슷하게 보인다(앉은 자리 물건이 있으면 읽힌다).
