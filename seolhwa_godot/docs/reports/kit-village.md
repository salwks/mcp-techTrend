# kit-village 보고서 — 민가·마을 소품 키트 (JL_NAMWON_UNBONG)

담당: kit-village · 범위: `kit/village/**`, `shots/kit/village/**` · 시대: 1870년 전후 조선 후기

## 1. 만든 것

모든 모델은 `kit/village/<이름>.gd`(`extends RefCounted`, `static func build(params) -> Dictionary`)이고 계약서 §4 형식을 지킨다.
반환값은 `{node, colliders, lights, occluder, footprint, anchors}`이고, 들어갈 수 있는 초가는 `interior`도 준다. 정면은 +z(남쪽)이다. 밤 창호지는 `paper` 키로 빛나고, 창 자리는 `lights`에 `kind:"window"`로 넣었다.
전체 목록과 수치(params 예, 변형별 삼각형 수, footprint, 충돌체·조명 수, 앵커 이름)는 `kit/village/catalog.json`에 있다.
이 파일은 `godot --path . --headless -s res://kit/village/_catalog_dump.gd`로 다시 만든다.

### 1-1. 웹 buildings.js를 옮긴 모델 (같은 모양·색)
| 모델 | 설명 | 삼각형(먹선 포함) |
|---|---|---|
| `choga` | 초가삼간: 방 창, 방문, 부엌 널문, 툇마루, 댓돌, 굴뚝, 둥근 이엉 지붕. 웹 `gourd` 옵션(박 넝쿨) 포함. `interior:true`로 들어갈 수 있는 외딴집이 된다(웹 chogaInterior, part 노드 base/body/front/roof/interior, `interior.hide`=[roof, front]) | 1,984 / 실내 3,010 |
| `giwa` | 기와집: 높은 기단과 계단, 5칸, 곡선 팔작 지붕. `plain`은 단청을 뺀 민가 기와집, `bays`로 칸 수를 바꾼다 | 4,464 (plain 3칸 3,856) |
| `jeongja` | 정자: 계자난간, 사모 지붕, 청사초롱. `plain`은 마을 모정 | 3,296 |
| `well` | 우물. `roof`는 이엉 덮개(가설) | 392 |
| `jangdok` | 장독대(옹기 7개) | **1,244** (작은 판 924) |
| `haystack` | 짚가리 | 376 |
| `jangseung` | 장승 대장군·여장군(얼굴은 아틀라스 face0/1) | 450 / 370 |
| `torch_post` | 횃대(불꽃이 glow라 밤에 빛남) | 262 |
| `stone_wall` | 돌담, 두 점 사이 | 약 220/m (4.5m 984) |
| `fence` | 싸리울, 두 점 사이. `lite`는 톱니 판 | 4m 640 / lite 6m 578 |
| `stone_bridge` | 홍예 돌다리. z방향, y=0이 둑, 아치는 y=−1.7까지 | 1,520 |
| `cairn` | 서낭당 돌무더기 + 제단 + 촛불 | 750 |
| (bigTree) | kit-nature와 겹쳐 뺐다. 성황당 신목만 단순화해 직접 만들었다 | — |

### 1-2. 새로 만든 모델
| 모델 | 설명 | 삼각형 |
|---|---|---|
| `jumak` | 주막: 초가(방문 열림, 안쪽 어둡게) + 평상(소반·사발·술병) + 한데부뚜막 가마솥(불빛 torch) + 용수 장대와 흰 천 + 술독 + 장작 | 4,410 |
| `market_shop` | 장터 가게(가가): 3칸 트인 초가 맞배, 거적 차양, 길 쪽으로 낸 판매대. `goods`: onggi/cloth/grain/straw/fish/mixed | 1,696 (onggi 2,480) |
| `jwapan` | 좌판: 멍석, 널 좌판, 물건, 장꾼 자리만 덮는 흰 차일 | 608 |
| `mulbang_a` | 물레방앗간: 용마루가 남북인 맞배이고 남쪽 박공에 문과 윗물레 바퀴(정면에서 보임). 동쪽 홈통에서 물줄기가 떨어지고 바퀴 밑 도랑이 있다 | 1,636 |
| `didil_bang_a` | 디딜방앗간: 트인 헛간, Y자 방아채, 볼씨, 공이, 돌확 | 728 |
| `oeyanggan` | 외양간: 구유, 깔짚, 살대, 여물(소 자리는 anchor `cow`) | 744 |
| `heotgan` | 헛간: 볏단, 지게, 소쿠리, 농기구 | 1,132 |
| `dwitgan` | 뒷간: 거적문, 둥근 이엉, 잿더미 | 468 |
| `daemun` | 대문. `style` tile(평대문)/soseul(솟을대문 + 행랑 2칸)/thatch(초가 대문). anchors `wall_l/wall_r`(담 잇는 자리) | 616 / 1,724 / 424 |
| `saripmun` | 사립문 | 376 |
| `todam` | 토담(막돌 박은 흙담). `cap` thatch/tile, 두 점 사이 | 약 50~70/m |
| `seonghwangdang` | 성황당: 돌무더기 + 신목(금줄, 종이 술, 오색 천). `dangjip`은 작은 기와 당집. `tree:false`면 nature 나무 자리(anchor `tree`)만 남긴다 | 1,928 / 2,464 / 750 |
| `sotdae` | 솟대(장대 끝 오리), `n`개 | 468 |
| `jingeom` | 징검다리(z방향, 물 면 y=0, 충돌체 없음, 디딤돌 앵커 s0..) | 360 |
| `seop_bridge` | 섶다리: Y자 다리발, 멍에, 장선, 솔가지, 흙길(z방향) | 1,632 |
| `narutbae` | 평저 나룻배(원점 = 물 면, 이물 −z), 멍에, 깔판, 삿대 | 240 |
| `ppallaeteo` | 빨래터: 빨랫돌, 방망이, 젖은 빨래, 광주리, 물 판(washer 앵커는 +z에서 북쪽을 본다) | 536 |
| `jige` | 지게 + 작대기. `load` basket/wood/none | 320 |
| `firewood` | 장작더미 row(벽 따라, `cover` 이엉) / stack(井자) | 640 / 720 |
| `props` | `kind`: pyeongsang 평상, gamasot 한데부뚜막, yongsu 용수 장대, jeolgu 절구, maetdol 맷돌, dok 항아리, soguri 소쿠리, byeotdan 볏단, scarecrow 허수아비(웹 index.js), meongseok 멍석 | 80~494 |
| `house_compound` | 집 한 채 프리셋, 마당 중심이 원점, 대문이 +z. **small**: 초가 안채, 헛간, 뒷간, 작은 장독대, 장작, 싸리울(lite), 사립문. **medium**: 초가 안채와 사랑채(동향), 외양간, 헛간, 장독대, 뒷간, 장작, 이엉 토담, 초가 대문. **large**: 기와 안채와 사랑채(plain), 곳간, 장독대, 뒷간, 기와 토담, 솟을대문. 앵커는 건물마다 접두어가 붙는다(`anchae_door`, `sarang_maru`, `oeyang_cow`, `gate_gate_out` …). `yard`(마당 사각형)도 준다 | 10,950 / 12,712 / 14,452 |

### 1-3. 공용 코드 `kit/village/_common.gd` (preload, class_name 없음)
- three.js 도형 중 Kit에 없는 것을 옮겼다: `sphere`(SphereGeometry, theta 범위 포함), `lathe`, `torus`, `vplane`(세운 PlaneGeometry), `extrude_xy`(ExtrudeGeometry), `beam`(두 점 사이 각재).
- 웹 도우미: `curved_roof`(curvedRoof, 막새 띠 포함), `ridge_cap`, `holed_wall`, `paper_panel`, `onggi`.
- 새 도우미: `thatch_cap`(작은 둥근 이엉), `thatch_gable`(도톰한 맞배 이엉, 3띠 둥근 단면), `tile_roof`(작은 기와), `shed`(헛간류 몸체), `dark_door`, `seg_xform`(두 점 모델용).
- `M` 조립기: part별 Batch를 두고 `push/pop`으로 하위 조립을 옮기거나 돌린다. 충돌체·조명·앵커는 현재 변환을 따라간다(집 묶음 조합용). `merged=false`로 만들면 part마다 자식 노드가 따로 생긴다(실내 숨김용).

## 2. 스크린샷 (`shots/kit/village/`)
- 전체 모음: **`shots/kit/village/contact_sheet.png`** (63장)
- 모델 기본값: `<이름>.png`. 변형: `choga_interior`, `giwa_plain`, `market_shop_onggi`, `jwapan_onggi`, `daemun_{tile,soseul,thatch}`, `todam_tile`, `fence_lite`, `firewood_stack`, `seonghwangdang_dangjip`, `jangdok_small`, `props_<kind>`, `house_compound_{small,medium,large}`
- 옆에서 본 것(땅 없이 `--ground=0`): `stone_bridge_side`, `seop_bridge_side`, `narutbae_side`
- 해질녘(18.3): `choga_dusk`, `giwa_dusk`, `jumak_dusk`, `jeongja_dusk`
- 밤(22): `choga_night`, `giwa_night`, `jumak_night`, `jeongja_night`, `torch_post_night`, `seonghwangdang_night`, `house_compound_medium_night`. 밤에는 창호지(paper), 청사초롱(lamp), 횃불·부뚜막·촛불(glow)이 빛나는 것을 확인했다.

찍은 사진은 모두 직접 열어 보고 고쳤다. 고친 것:
- 시장 가게와 좌판은 위에서 볼 때 차양이 물건을 가렸다. 판매대를 차양 앞으로 냈고, 차일은 뒤쪽 반만 덮게 했다.
- 물레바퀴가 옆면(+x)에 있어 카메라에서 모서리만 보였다. 박공을 남쪽으로 돌렸다.
- 돌무더기는 위에서 보면 고리처럼 비어 보였다. 속을 채우는 큰 덩이를 넣었다.
- 옹기 뚜껑을 닫힌 원기둥으로 바꿨다(위가 뚫려 보였다).
- 맞배 이엉은 평판처럼 보였다. 둥근 단면으로 바꿨다.
- 토담 기와 갓의 결이 뭉개졌다. 0.4m 마디로 나눴다.
- 사립문이 바깥으로 열렸다. 안쪽으로 열리게 고쳤다.
- 장작의 무작위 회전을 없앴다.

## 3. 성능
- 민가 예산(≤ 6,000) 안: choga 1,984, giwa 4,464, jeongja 3,296, jumak 4,410, 그 밖의 건물은 모두 2,500 이하.
- 웹보다 줄인 것: giwa 지붕 격자 36×20 → 24×12(웹 그대로면 지붕만 먹선 포함 약 6,000), jeongja 28×28 → 16×16, 정면에서 안 보이는 뒷기둥은 각기둥으로. 기와 골은 웹보다 조금 굵어 보인다.
- 소품 예산(≤ 800) 안: well, haystack, jangseung, torch_post, cairn, jwapan, saripmun, sotdae, jingeom, narutbae, ppallaeteo, jige, firewood, props 전부.
- **예산을 넘는 것(총괄 판단 요청)**:
  - `jangdok` 1,244: 옹기 7개, 웹은 13개. 작은 판 `n:[2,2,1]`은 924.
  - `stone_wall`: 약 220/m. 막돌 하나하나가 먹선 덩이라서다. 긴 담은 `todam`(약 50/m)이나 `fence lite`를 권한다.
  - 다리(`stone_bridge` 1,520, `seop_bridge` 1,632)는 '소품'보다 구조물로 봤다.
  - `house_compound`는 여러 건물 묶음이라 '큰 건물' 예산(≤ 15,000)에 맞췄다: 10,950 / 12,712 / 14,452.

## 4. 고증 근거와 가설
근거(일반적 통설·민속 자료):
- 남부 민가는 一자형 안채가 남향하고, 사랑채·헛간·외양간이 마당 둘레에 따로 선다(튼 ㅁ·ㄷ자). 장독대는 부엌 뒤편, 뒷간은 마당 구석에 둔다.
- 주막은 길가 초가에 마당 평상을 두고, 장대에 용수를 매달거나 '酒'를 쓴 등으로 표시했다(김홍도·신윤복 풍속화).
- 장시(5일장)에는 상설 점포보다 가가(假家)·좌판·차일이 많았다.
- 성황당은 누석단에 신목, 왼새끼 금줄, 오색 천을 짝지었다. 솟대와 장승은 마을 어귀에 세웠다.
- 물레방아는 산간 계곡 마을에서 봇도랑 물을 홈통으로 받아 바퀴 위에 떨어뜨렸다. 디딜방아는 Y자 방아채로 두 사람이 밟았다.
- 나룻배는 강 나루의 평저선이었다. 빨래터는 냇가 넓적돌과 방망이였다.
- 기와 민가(향반·이서)에는 단청을 쓰지 않는다. 그래서 집 묶음 large는 `plain`이다. 웹 giwa의 단청 기둥은 관아·정자풍이라 기본값으로는 남겨 두었다.

가설(확인 필요):
1. 주막 용수 장대에 흰 천 한 폭을 단 것(멀리서 알아보게 하려고). 실제로는 용수만 달거나 등만 걸었을 수 있다. `flag:false`나 `yongsu(cloth=false)`로 뺄 수 있다.
2. 우물 이엉 덮개(`roof`)는 산간 공동우물 덮개로 넣었다.
3. 섶다리는 영월·평창 사례로 잘 알려져 있다. 남원·운봉 하천(람천 상류, 만수천)의 얕은 개울에서도 썼다고 보았다.
4. 물레바퀴 지름 3.2m, 윗물레(상사식) 방식.
5. 성황당 당집(작은 기와 사당)은 지리산 자락 당산 사례를 참고했다.
6. 남원 읍내장에 상설 가게채(`market_shop`)가 있었다고 보았다. 인월·운봉장은 `jwapan` 위주를 권한다.
7. 집 묶음의 크기와 배치(마당 14~24m)는 축척을 압축한 땅에 맞춘 게임용 근사치다.

## 5. 총괄에게 요청
1. **Kit 공용 도구**: `_common.gd`의 `sphere/lathe/torus/vplane/extrude_xy/beam`과 `curved_roof` 계열은 kit-landmark에서도 쓸 만하다. `scripts/kit/kit.gd`로 올리는 것을 검토해 주기 바란다. `paint`가 rng 없이 불리면 `randf()`를 써서 결과가 매번 달라지므로, 기본 rng를 고정하는 것도 권한다.
2. **kit_preview**: 스크립트 오류가 나면 종료하지 않고 멈춘다(`get_tree().quit()`에 닿지 못함). 오류가 나면 바로 끝나도록 바꾸거나 `--timeout`을 넣어 주기 바란다. 실내 미리보기에서 `interior.hide`를 숨기는 `--interior` 옵션도 있으면 좋겠다.
3. **배치(terrain-engine)**:
   - `stone_bridge`, `seop_bridge`, `jingeom`은 로컬 z가 건너는 방향이다(강은 x로 흐른다). 둑 높이가 y=0이고 다리발과 홍예는 그 아래로 내려간다.
   - 결과에 `deck` 높이식 문자열을 넣었다(stone_bridge, seop_bridge). 걷기 높이로 쓰려면 엔진이 이 함수를 써야 한다.
   - `narutbae`와 `ppallaeteo`는 원점이 물 면이다.
   - `mulbang_a`의 도랑 물 판은 키트 안의 장식이라 지형 수계와 맞춰야 한다.
4. **kit-nature**: 성황당은 `tree:false` + `anchors.tree` 자리에 nature의 큰 느티·당산나무를 놓고 금줄만 남기는 방식으로 바꿀 수 있다. 지금 신목은 자체 단순판(약 1,200)이다.
5. **집 묶음 occluder**: 묶음 하나가 노드 하나(병합)라 가림 반투명이 묶음 전체에 걸린다. 건물별로 따로 페이드하려면 묶음 대신 개별 모델을 배치하거나, `merged=false` part 분리를 요청해 달라.
6. `godot --import`는 돌리지 않았다. 새 스크립트 `.uid`와 `shots/kit/village/*.png`의 import는 총괄이 해야 한다.
