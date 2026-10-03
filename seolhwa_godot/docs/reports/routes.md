# routes 보고서 — 노정(권역 사이 길) 공간과 길목 쉼터 (2026-10-03)

계약서 §10, WORLD_SCOPE_PLAN §4, WORLD_SPEC §19·20·22~23·25·27·29·30을 따랐다.
생성기: `tools/region/make_routes.py`. 결과: `region_data/routes/<id>/{route.json, height.png, landuse.png, climate.png, placement_route.json}`.

```bash
python3 tools/region/make_routes.py                 # 모든 노정(약 1분, DEM 타일 캐시 tools/region/cache/routes/)
python3 tools/region/make_routes.py GG_HANYANG-GS_GYEONGJU
godot --path . res://scenes/region.tscn -- --route=GG_HANYANG-GS_GYEONGJU
```

## 1. 만든 노정 (10개)
| 노정 id | 이름 | 길이 | 쉼터·성읍(순서대로) | 권역 쪽 포털 |
|---|---|---|---|---|
| JL_NAMWON_UNBONG-GG_HANYANG | 삼남대로 | 4.1km | 오수(의견비) → 전주(풍남문) → 앵곡(콩쥐팥쥐) → **곰나루**(금강 나루) → 차령(고개) → **천안삼거리**(능소 버들·주막 셋·영남 갈래길) | 남원 북문 길 끝(새) / 한양 to_namwon |
| GG_HANYANG-GS_GYEONGJU | 영남대로·안동길 | 5.5km | **송파나루·장**(첫 쉼터) → **문경새재**(조령관·조곡관·주흘관, 원터, 주막 둘, 성황당, 교귀정 자리) → 상주(성문) → 하회(낙동강 나루·종가·뜰집) → 제비원(석불·원집) | 한양 to_gyeongju / 경주 portal_west |
| GG_HANYANG-GW_GANGNEUNG | 관동대로 | 3.1km | 원주(감영 문루) → 치악산 기슭(꿩 보은) → 횡계 고원(너와·귀틀, 고산) | 한양 동쪽 끝(새, 2540,−560) / 강릉 portal_daegwallyeong |
| GG_HANYANG-HH_HWANGJU | 의주대로 | 3.5km | 임진나루 → 개성(남대문·장, 전우치) → **선죽교**(돌다리·비각) → 청석골(고개·임꺽정 산채) → 서흥 주막 | 한양 to_pyeongyang / 황주 to_kaesong |
| HH_HWANGJU-PA_PYEONGYANG | 의주대로 | 1.3km | 중화(관서 첫 고을) | 황주 to_pyeongyang / 평양 to_hanyang |
| GG_HANYANG-HG_HAMHEUNG | 경흥대로 | 4.7km | 축석령 → 철원 → **철령(철령관, 고산)** → 원산포(바다) → 영흥 | 한양 to_hamheung / 함흥 남서 끝(새, −2530,1745) |
| PA_PYEONGYANG-HG_HAMHEUNG | 성천·양덕·고원길 | 2.5km | 성천(정자) → 양덕(산골 고개) → 고원 | 평양 to_hamheung / 함흥 to_cheollyeong |
| HH_HWANGJU-JANGSANGOT | 장산곶 띠(막다른 길) | 2.1km | 재령 들 → 구월산 기슭(삼성사 자리·산채) → 장산곶(벼랑·바다) | 황주 to_jangsangot |
| HG_HAMHEUNG-BUKCHEONG | 북청길(막다른 길) | 1.5km | 홍원(바닷가) → 북청(사자놀음 마당) | 함흥 to_bukcheong |
| SEA_NAMHAE_JEJU | 남해 뱃길(최소 장면) | 1.3km | 덕진다리 주막(돌다리) → 해남 관두포(포구·창고·배) → 포털 = 배 타기 | 남원 남쪽 구례길 끝(새) / 제주 portal_hwabuk_ferry |

쉼터마다 route.json `stops[]`에 `folktales`(FOLKTALE_CATALOG 코드·등급)와 `encounter`(D급 조우 후보 — 호랑이=고개·산, 도깨비=나루·주막·장터 외곽·산길, 귀신=원터·나루·객사, 용왕=큰 강·바다, `night_bias`)를 넣었다. 이벤트 담당이 그대로 쓰면 된다.

## 2. 지형 만드는 법 (실측 DEM 창 + 압축 이음)
- 띠: x = 길 방향, z = 옆(−256…256m), 2m 격자. 카메라가 남쪽 고정이라 어느 노정이든 화면 좌→우로 간다.
- stop마다(양 끝 포털 자리 포함) **실측 DEM 창**: 그 자리 실제 길 방향(앞뒤 stop을 잇는 방위, 문경새재는 3관→1관)으로 돌려 terrarium z13을 샘플. 수평 K_h(기본 0.3 — 권역과 같음; 문경새재 0.15, 철령 0.22). 높이 = 창 기준점 해발×0.3 + 둘레 기복×K_h(줄인 창도 실제 경사 유지).
- 창 사이(실제 수십 km)는 smoothstep으로 두 창을 섞는다. 이음 길이 = max(280m, 높이차/0.18), 최대 1100m(§30: 순서·지형 성격 유지, 거리 압축).
- 길: 지형 위 최소 비용 경로(낮고 완만한 곳, 가운데 쪽 — §19 골짜기→고개→나루). 성문 자리는 길이 S자로 꺾여 **남→북으로 문을 통과**(문 정면이 카메라를 봄), 문 둘레 터 고르기. 삼거리는 북쪽 갈래길(지선).
- 나루·다리: 실측 골짜기 바닥(창 안 가장 낮은 열)에 남북 물길을 파고 둔덕 경사를 줌. 건너는 곳은 0.55m 얕은 여울(엔진 나루 허용 28m 상자 안에 들도록 강폭 ≤24m). 선죽교·덕진다리는 돌다리(walk).
- 바다(4개 노정): DEM ≤0.3m를 바다로, 띠 가장자리에 닿지 않는 웅덩이는 뭍으로. `sea {y:0}`. 길은 바다를 피하고 막다른 곶은 물가에서 끊는다.
- 토지이용(경사·상대고도·길 거리), 기후대(창 위도대 + 눈선 위 고산 + 바다 가까이 해안). 눈선: 영남대로 560m, 관동 650m, 경흥 600m, 평양-함흥 650m.
- 결과 높이: 남원길 0~72, 영남대로 −1~215(새재), 관동 2~269(횡계 고원), 경흥 −2~274(철령).

## 3. 배치 (placement_route.json, 노정마다 14~99항목, 모두 기존 키트)
문화권 가옥형: 호남 `village/*`, 기호 `culture/giho/*`, 영남 `culture/yeongnam/*`(하회 종가·뜰집), 관동 `village/neowa_house`·`culture/gwandong/*`, 해서 `culture/haeseo/*`, 관서 `culture/gwanseo/*`, 관북 `culture/gwanbuk/*`, 고산 `village/guitul_house`, 바닷가 `village/choga_low`.
쉼터 짜임: 주막(§27 — 고개 앞뒤·나루·삼거리·읍성 밖), 성황당+돌무더기(§29 — 고개·어귀), 나루(§25 — 나룻배 3·뱃사공 집·창고·주막·빨래터·건너편 집), 성문+계단식 성벽(`landmark/seongmun`, `hy_seong_wall` rise), 장승 한 쌍.
빌려 쓴 키트(가설, note에 적음): 의견비·선죽교 비각 ← `gj_gyerim_bigak`(marker 끔), 제비원 석불 ← `maaebul_rock`, 삼성사 ← `samun`+`village/giwa plain`, 성천 강선루 ← `village/jeongja`, 조령원 터 ← `wall_run`(허문 담).
생성기는 길·물·다른 항목·가파른 땅을 피해 자리를 밀어 보고, 안 되면 뺀다(성문 바깥 셋째 성벽 조각 몇 개, 북청 집 2채 등 — 실행 로그 `dropped`).

**TITLES**: `scripts/region/place_title.gd` TITLES 끝에 `rt_*` 35개만 덧붙임(다시 읽은 뒤 한 번 편집). route.json settlements에도 `title/short`가 있다.

## 4. regions.json 바꾼 것 (기록)
포털 id는 고치지 않았다(모든 region.json 포털 `route:<id>`가 노정 id와 맞음). 엔진은 regions.json 포털을 읽지 않지만 목록을 맞추려고 **항목만 추가**:
- JL_NAMWON_UNBONG: `to_hanyang`(−3495,−2077.4 → JL_NAMWON_UNBONG-GG_HANYANG), `to_jeju_sea`(−2726,2074 → SEA_NAMHAE_JEJU)
- GG_HANYANG: `to_gangneung`(2540,−560 → GG_HANYANG-GW_GANGNEUNG)
- HG_HAMHEUNG: `to_hanyang_cheollyeong`(−2530,1745 → GG_HANYANG-HG_HAMHEUNG)
원본 백업은 남기지 않았다(git diff로 확인 가능 — 위 4항목 추가만).

## 5. 확인
- **남원 → 노정 → 한양**: `--region=JL_NAMWON_UNBONG --portaltest=3 --weather=clear` → 남원 북쪽 포털 → 노정 도착(−2016,−16) → 노정 끝 → 한양 도착(−1800,2519). `shots/region/routes/t_namwon_hanyang/`.
- **한양↔경주**: `--route=GG_HANYANG-GS_GYEONGJU --portaltest=3` → 경주 portal_west 도착 → 노정 to 끝으로 되돌아옴 → 한양 to_gyeongju 도착(2433,27). `shots/region/routes/t_hanyang_gyeongju/`.
- 나머지 8개 노정 불러오기: 오류 없음, 키트 missing=0, 포털 2개(막다른 길 1개). `shots/region/routes/load_*.png`.
- **지도 Tab**: 전국 지도에 10개 노정 선(geo_line)과 지금 자리(노정 위 진행도)가 나온다 — `map_nation_route.png`, `map_all_route.png`(노정 벡터 지도), `map_nation_hanyang.png`.
- 지명: 새재 2관 앞에서 "문경새재"가 뜬다 — `saejae_gate2.png`.

## 6. 엔진 요청 (엔진 코어는 고치지 않음)
1. **포털 중복**: 권역 쪽 포털이 route.json(노정 파일들)과 region.json `portals` 두 곳에서 같은 자리에 두 번 만들어진다(장승 두 쌍·글씨 겹침, 한양 10개 중 5개가 중복). 같은 target·10m 안이면 하나로 합쳐 주길. 지금은 노정 쪽 것이 목록 앞이라 먼저 걸려 도착 자리가 맞다.
2. region.json 포털(`tx` 없음)로 노정에 들어가면 노정 `spawn`(from 끝)에 선다 — 그 권역이 노정의 **to 끝**이면 반대편에 떨어진다. `route:<id>`일 때 노정 portals에서 그 권역 쪽 끝을 찾아 도착 자리를 정해 주길(위 1과 같이 고치면 됨).
3. 노정 하나에 갈림(분기)이 없다: 평양→함흥과 한양→함흥이 실제로는 영흥·정평에서 합류하는데, 지금은 함흥에 남서 포털 둘(to_cheollyeong = 평양 노정, 새 −2530,1745 = 한양·철령 노정)로 따로 들어간다.
4. 전국 지도에서 노정 이름이 길어 글씨가 겹친다(평양·황주 둘레). 노정 `short` 필드(예: "삼남대로")를 읽거나 이름을 줄여 그리면 좋겠다 — 원하면 route.json에 `short`를 넣겠다.
5. `--portaltest`는 40m 넘게 떨어지면 포털 앞까지 순간이동한다 — 노정 전체를 실제로 걷는 시험(막힘·물·성벽)은 아직 없다. 길 따라 걷는 시험 인자(`--walkroute`)가 있으면 좋겠다.
6. 배는 바다 위에 `y=0`으로 놓았다(로더는 하천 수면만 찾음). 바다 수면도 찾아 주면 `y`를 빼겠다.

## 7. 데이터 담당(data-north)에게
- 함흥 `to_cheollyeong` 이름이 "철령(… 한양/평양 노정)"인데 연결은 평양 노정(PA_PYEONGYANG-HG_HAMHEUNG, 철령 없음 — 양덕·고원길)이다. 철령은 실제 경흥대로(한양 노정)에 있다. 이름을 "→ 정평·영흥(평양 노정)"으로 바꾸고, 한양 노정 포털(−2530,1745)을 region.json에 넣어 주길.
- 한양 region.json에 관동대로(→강릉) 포털이 없어 동쪽 끝 들판(2540,−560)에 새로 두었다. 동대문 밖 길에서 갈라지는 관동대로 끝을 만들어 주면 그 자리로 옮기겠다.

## 8. 남은 문제·가설
- stop 경위도는 기억값 근사(일부는 DEM으로 골짜기·마루를 찾아 고침: 새재 세 관문, 치악산 기슭, 장산곶 끝, 관두포 물가, 북청). 고증은 참고용.
- 창 사이 이음은 두 실측 지형의 혼합이라 실제 지명과 무관하다. 큰 높이차 이음(송파→새재, 원주→횡계)은 20% 안팎 오르막.
- 대관령 마루·동쪽 내리막(영서→영동 바뀜)은 강릉 권역 안에 있다(포털이 대관령 서쪽 횡계 쪽). 노정은 영서 고원(고산 기후, 너와·귀틀)까지.
- 남해 뱃길은 최소 장면: 포구 물가 길 끝 포털이 곧 배 타기(불러오기 화면이 바다 건너기). 배 위 장면 없음.
- 남원 노정 도착 화면 가운데에 세로 풀빛 띠가 보인다(논 사이) — 토지이용인지 엔진 타일 경계인지 확인 못 함.
- 문화권 없는 공용 키트(주막·성황당·장승)는 모든 노정에 같은 모양이다.

---

# 2차 (2026-10-04) — 짧은 노정 · 길목 볼거리 · 걷기 시험 · 영흥 갈림 · 제주 뱃길 · 역마

```bash
python3 tools/region/make_routes.py          # 10개 노정 약 1분(새 DEM 타일은 처음 한 번 받음)
godot --path . res://scenes/region.tscn -- --route=<id> --walkroute=01 --walkspeed=12   # 노정 하나 끝까지 걷기(01 = 넘어간 뒤 끝)
```

## 1. 길이 — 짧게(사용자 결정 B): 쉼터 사이 300m, 큰 고개 460m
처음에 쉼터 사이를 1.2~2km로 늘렸다가(노정 7.6~10.9km) 총괄 지시로 되돌려 **짧게** 다시 만들었다. 달리기 4.6m/s로 노정 하나 약 2~8분.
- `make_routes.py` 맨 위 상수: `STOP_GAP=300`(쉼터 가운데 사이), `PASS_GAP=460`(문경새재·철령관·횡계 고원 쪽), `END_GAP=250`(권역 포털 끝 ↔ 첫 쉼터), `STOP_A=70`(쉼터 실측 창 핵심 반길이), `DS_SCALE=0.62`(1차 쉼터 장면을 길 방향으로 좁힘), `MAX_GRADE=0.13`.
  **간격을 다시 바꾸려면 이 숫자만** 고치면 된다 — 볼거리는 DEM 창이 아니라 쉼터 사이 구간 안 비율 + 지형 선호로 자리를 다시 잡는다.
- 쉼터 순서·쉼터 수는 그대로. 문경새재는 세 관문이 들어가게 창 kh 0.06(핵심 380m), 철령관 핵심 190m.
- 높이: 노정마다 `kv_eff = min(0.3, 0.13 × 이음 길이 / 해발 차)`로 **노정 전체를 같은 비율로 눌러** 오르막을 13% 아래로(높고 낮음 순서·바다 0m 유지). 영남대로 0.053, 경흥대로 0.062, 삼남대로 0.278. 창 둘레 기복은 실측 × kh 그대로.

| 노정 | 길이 | 쉼터 사이(m) | 볼거리 | 배치 | 달리기 4.6m/s |
|---|---|---|---|---|---|
| 삼남대로 남원→한양 | 2.12km | 300 ×5 | 15 | 164 | 약 7.8분 |
| 영남대로 한양→경주 | 2.14km | 460·460·300·300 | 12 | 162 | 약 8.7분 |
| 관동대로 한양→강릉 | 1.41km | 300·460 | 9 | 91 | 약 5.2분 |
| 의주대로 한양→황주 | 1.82km | 300 ×4 | 13 | 130 | 약 6.8분 |
| 의주대로 황주→평양 | 0.62km | (쉼터 하나) | 2 | 22 | 약 2.1분 |
| 경흥대로 한양→함흥 | 2.14km | 300·460·460·300 | 12 | 117 | 약 8.1분 |
| 평양→영흥 갈림 | 1.22km | 300·300 | 7 | 75 | 약 4.2분 |
| 장산곶 띠 | 1.14km | 300·300 | 5 | 67 | 약 4.7분(왕복 아님) |
| 북청길 | 0.78km | 300 | 4 | 43 | 약 3.2분 |
| 남해 뱃길 | 1.37km | 300 + 뱃길 540m | 6 | 57 | 걷기 약 3분 + 배 약 1분 |

## 2. 길목 볼거리 85곳 (`tools/region/route_sights.py`)
쉼터 사이마다 **2~3곳**(권역 끝 구간은 1~3곳). 기계적으로 고르게 깔지 않고, 노정마다 그 사이 실제 지명·지형에 맞는 것만 골랐다(경위도 기억값 근사, 고증은 참고용).
자리는 쉼터 장면 사이 빈 구간을 볼거리 수만큼 나눈 칸 안에서 **지형이 말하는 곳**: 서낭당·쉼바위·폭포 = 칸 안 가장 높은 길, 나루·여울·마을·신목·길가 쉼터 = 가장 낮은 곳, 숲·무덤·원터 = 칸 가운데. 물길 볼거리는 앞뒤 쉼터의 나루·다리에서 100m 넘게 띄운다.

| 종류(분류 category) | 놓는 곳(명세) | 키트 |
|---|---|---|
| 서낭당 seonang (pass) | 고갯마루·갈림(§29) — 슬치·차령 북쪽·의성 고개·혜음령·동선령·고원 고개·함관령 | village/seonghwangdang + 돌무더기 둘 + 소나무 |
| 쉼바위 view_rock (pass) | 마루 전망 — 지지대·토끼비리(고모산성)·울음산(GD08 A)·구림(HN28 A)·몽금포 | nature/slab_rock(카메라 쪽 낮게) + 바위·소나무 |
| 호랑이 숲 tiger_forest (forest) | 큰 고개 앞뒤(§23 호랑이) — 차령·남태령·소조령·문재·대관령·청석골·동선령·철령·양덕·구월산·함관령 | 길섶까지 숲(토지이용 0), 들머리 돌무더기·횃대, 고사목·바위 |
| 나루 ferry_shed (crossing) | 길목 강(§25) — 삼례 만경강·달천·용진·한탄강·용흥강·비류강·재령강·영산강 | 물길 + **route/ferry_shed** + 나룻배 둘 + 뱃사공 집·건너편 집·장승·버들 |
| 도깨비 여울 dokkaebi_ruin (ruin) | 옛 여울목(§23 도깨비) — 정안천·금호강·금천·무진천·장연 | 얕은 물길 + 징검다리 + **route/ruin_house** + 버들·고사목·갈대 |
| 빈 주막터·원터 inn_ruin (inn_site) | 옛 원·주막(§23 귀신·도깨비) — 노성·소사원·낙양·대화·혜음원·다락원·회양·신창 | **route/ruin_house** + 허문 원 담 + 우물·고사목 |
| 무덤 mound (tomb) | 산기슭(§23 귀신·여우·시묘) — 임실·풍산·치악 효자 산소·장단, 함창·반남은 '옛 왕릉이라는 말'(C) | **route/myo** 셋 + 소나무 |
| 폭포와 소 pool (pool) | 용소(§23 용왕·수중) — 구룡소·박연폭포(GH20 A)·재인폭포·석왕사 계곡·양덕 온정 | **route/waterfall** + 너럭바위 + 작은 제단 |
| 신목 sinmok / 이정표 milestone / 길가 쉼터 roadside (roadside) | 들 가운데 큰 나무·도 경계·길가 그늘 | **route/sinmok**(금줄) · **route/ijeongpyo** + 장승 · 정자나무+평상+지게 |
| 길가 마을 hamlet (hamlet) | 골짜기 들(§18·24) — 서도·풍세·이천·풍산 들·지평·진부·장단·평산·김화·문천·강동·고원 들·신천·신포·곡성 | 문화권 집 4채 + 텃밭·짚가리·우물, 어귀 솟대+장승, 앞 논·뒤 밭 토지이용 |

**route.json `sights[]`**(쉼터 `stops[]`와 같은 자리): `{key, id, sight, category, type, name, title, x, z, t(노정 진행도), culture, bbox, items, real{lat,lon,alt_m}, folktales:[{code,title,grade}], encounter:{grade:"D", type, category, event_grade(설화 중 가장 높은 등급), candidates, night_bias}}`.
이벤트는 `category`(pass/forest/crossing/ruin/inn_site/tomb/pool/roadside/hamlet/sea)로 붙이면 된다. 길가 마을·나루는 `settlements`(주변 인물·지명)에도, 나머지는 `landmarks`에도. 지나갈 때 지명(`title`)이 뜬다(place_title이 sights를 읽음).

## 3. 걷기 시험 — 모든 노정 막힘 0 (`--walkroute=01 --walkspeed=12`)
| 노정 | 걸은 거리·시간 | 막힘 |
|---|---|---|
| 삼남대로 | 2153m · 180s | 0 |
| 영남대로 | 2390m · 199s | 0 |
| 관동대로 | 1444m · 120s | 0 |
| 의주대로(한양→황주) | 1876m · 156s | 0 (1차의 3건 포함 해결) |
| 의주대로(황주→평양) | 578m · 48s | 0 |
| 경흥대로 | 2246m · 187s | 0 |
| 평양→영흥 갈림 | 1166m · 97s → 경흥대로 노정 갈래길에 도착 | 0 |
| 장산곶 띠·북청길(막다른 길) | 1297m · 873m | 0 (끝까지 걸은 뒤 마지막 점이 출발 포털이라 순간이동 1회 — 시험 방식) |
| 남해 뱃길 | 1437m · 134s (배 포함) → 제주 도착 | 0 |

고친 막힘: (1) 물 건너는 곳 — 길이 물길을 비스듬히 건너 다리·징검다리 끝에 걸림 → 물길 앞뒤 50m 길을 곧게, 길 높이를 물 면 +0.35m(징검다리 +0.08m)로 완만히. (2) 징검다리·돌다리를 굽이친 실제 물길 가운데에, 징검다리 y = 물 면. (3) 비탈에 걸린 물길이 둑보다 높던 것 → 물 면을 건너는 둘레 ±40m 가장 낮은 땅 +0.2m 이하로. (4) 볼거리 물길이 쉼터 나루와 붙어 겹치던 것 → 100m 띄움. (5) 출발 포털 곁 막힘(1차) → 걷기 시험이 플레이어 둘레 길 점부터. (6) 관두포 뱃길 들머리 → 포구 길 끝에서 곧게.
`exit=124`(시간 초과)는 넘어간 권역에서 PTEST를 찍은 다음 끝내기에서 멈춘 것(경주 등 큰 권역) — 걷기와 무관, 엔진 쪽 확인 필요.

## 4. 영흥 갈림 — 노정 끝 셋(엔진 지원) + 함흥 포털 하나
- **route.json `portals.branch`**: `{route, name, route_x, route_z, at}` — 경흥대로 노정의 영흥 갈림길 주막에서 북쪽(화면 안쪽)으로 갈래길(지선 ~150m) → 끝이 평양 노정 포털. 갈림 어귀에 돌 이정표·서낭당·돌무더기, 갈래길 들머리 장승 한 쌍(§29).
- 평양 노정 `portals.to = {route: "GG_HANYANG-HG_HAMHEUNG"}`(to_region ""): 평양 → 성천 → 양덕 → 고원 → 영흥 갈림(경흥대로 노정 갈래길 끝에 도착) → 정평 → 함흥.
- 엔진 travel.gd: 노정 portals의 **모든 끝**(from·to·branch…)이 포털, `route`면 노정→노정(도착 = 상대 노정에서 `route == 이 노정`인 끝). `_arrive`는 노정에서 가장 가까운 길(갈래 지선 포함)을 따라 들어선다.
- 함흥: 남서 포털 둘(to_pyeongyang −2510,1824 / to_hanyang_cheollyeong −2530,1745)을 **to_yeongheung** 하나(경흥대로 끝 → 경흥대로 노정)로. `region_data/HG_HAMHEUNG/region.json`·`regions.json`·`tools/region/north_places_hg.py`·`tools/region/regions/HG_HAMHEUNG.json`을 같이 고쳐 다시 만들어도 유지. 함흥 지형은 안 건드려 `cheollyeong_road`(정평 갈래 80m)는 포털 없는 들길로 남음.
- 확인: 평양 노정 끝 → `TRAVEL arrive space=GG_HANYANG-HG_HAMHEUNG`(갈래길 20m 안쪽), 그 노정 포털 3개. `shots/region/routes2/walk/travel_1_gg_hanyang-hg_hamheung.png`.
- 고증 메모: 실제 양덕길은 고원에서 경흥대로와 만나지만 요청대로 영흥 합류(고원 쉼터는 평양 노정 쪽).

## 5. 제주 뱃길 장면
남해 뱃길 노정: 남원 → 곡성 들·영산강 나루·반남 고분 → 덕진다리 → 해남 당산·구림 → **해남 관두포**(주막·객주·창고) → **돛배** → 보길도·노화도 앞바다(실측 DEM 섬, kh 0.06·기복 0.28) → **화북포**(탐라 돌집·돌담·포구 당 신목·방사탑·창고) → 제주 portal_hwabuk_ferry.
- route.json `crossings`에 `{type:"나루", sea_lane:true, auto:true, boat_kit:"route/dotbae", ends}`(뱃길 약 540m). 엔진 region_world: 바다(강 아님)에서도 sea_lane 뱃길에 갑판 걷기 면을 깔고 돛배(새 키트)가 발밑을 따라오며 너울에 흔들림. **뱃길 물 위(배)에 오르면 건너편 포구까지 9m/s로 저절로 간다**(입력·걷기 시험보다 앞섬), HUD "배에 올랐다 — 제주 뱃길". 배 위 화면 `shots/region/routes2/sea_crossing.png`.

## 6. 역마(지나온 노정 건너뛰기) + 진행 기록
- 엔진에 저장 상태가 없어 최소 파일 **`user://progress.json`**(`scripts/region/progress.gd`): `{routes_done: {노정 id: 시각}}`.
- 노정에 들어온 끝과 **다른 끝 포털로 나가면** 그 노정을 '지나옴'으로 기록(region_main `_route_entry`). 걷기 시험도 기록된다.
- 권역에서 지나온 노정의 포털 16m 안에 서면 HUD "H: 역마 타고 ○○까지 (지나온 길 건너뛰기)", **H**를 누르면 노정을 건너뛰고 반대쪽 끝 권역 포털 자리로(갈림길 노정이면 이어진 노정의 그 끝으로) 바로 넘어간다(`Travel.fast_target`). 시험 `--fasttest`: 황주 → 평양 역마 확인.
- 지도(Tab)에서 고르는 건너뛰기는 아직 없다(역마만).

## 7. 성능·불러오기·메모리 (2048×1536, `--bench=25 --weather=clear`)
| 자리 | 평균 fps | p99 | 33ms 넘음 | 불러오기 |
|---|---|---|---|---|
| 삼남대로 전주 | 125.9 | 9.0ms | 0 | 2.6s |
| 영남대로 문경새재 | 135.3 | 12.5ms | 0 | 2.6s |
| 남해 뱃길 관두포 | 130.7 | 8.3ms | 0 | 1.6s |
노정 메모리(PTEST mem) 185~200MB(1차와 같음), 불러오기 화면 2.5~4.4s(둘씩 돌릴 때).

## 8. 새 키트 `kit/route/` (catalog.json, 미리보기 `shots/kit/route/`)
ijeongpyo(192/416 tris) · myo(~600) · ruin_house(1816) · ferry_shed(612) · waterfall(1352, water outline) · sinmok(1790, big_tree + 금줄) · dotbae(632).

## 9. 남은 것
- 볼거리 경위도는 기억값 근사(가설). 함창·반남 '왕릉'은 C급 — 진짜라고 하지 않는 전설로만.
- 짧아진 해안 쉼터(원산포·홍원)는 창이 좁아 바다가 화면 가장자리에만 보일 수 있다.
- 남원 노정 끝 구간(삼거리 → 한양)은 볼거리 셋이 200m 안에 몰려 있다(END_GAP을 늘리면 벌어짐).
- 막다른 노정 걷기 시험은 끝까지 갔다가 마지막에 순간이동한다(되돌아오기 아님).
- 넘어간 뒤 PTEST 끝내기 멈춤(exit=124)은 엔진 쪽.
