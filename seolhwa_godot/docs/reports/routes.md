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
