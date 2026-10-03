# terrain-data-north 보고서 — GG_HANYANG · HH_HWANGJU · PA_PYEONGYANG · HG_HAMHEUNG

상태: **초안(에이전트 생성, 역사지리 검수 전)**. 원칙은 고증 → 원칙 → 게임성이고, 고증은 참고용이다. 기준 문서는 계약서 §5·§9·§10과 WORLD_SPEC v0.3 §5–7·§14·§21·§24·§30·§36이다.
data-east의 일반 빌더(`build.py <id>` → `build_region.py`)를 그대로 썼다. 공용 파일은 고치지 않았다. 내 몫은 설정 파일과 `north_*.py` 보조 스크립트뿐이다.

## 1. 다시 만들기
```
python3 tools/region/north_dem.py <ID>; python3 tools/region/north_osm.py <ID>      # 캐시 없을 때만(Overpass 느림)
python3 tools/region/north_prep.py <ID>      # DEM 다듬기 + 하천선·큰 강 + regions/<ID>.json 쓰기
python3 tools/region/build.py <ID> && python3 tools/region/render.py <ID>
python3 tools/region/north_post.py <ID>      # 큰 강·나루·성곽·물길 바닥·기후대 보강, 그림에 성곽 덧그림
python3 tools/region/qa.py <ID> && python3 tools/region/render_map.py <ID>
python3 tools/region/write_regions.py GG_HANYANG HH_HWANGJU PA_PYEONGYANG HG_HAMHEUNG
```
고증 데이터는 `north_places_{gg,hh,pa,hg}.py`에 있다(places.py 꼴: 위경도, 출처, 신뢰도). `regions/<ID>.json`은 이 데이터로 **만들어지는 파일**이다.
`north_prep.py`는 매번 원 DEM(`cache/<ID>/dem_alt_raw.npy`)부터 다시 계산하므로 여러 번 돌려도 결과가 같다.

## 2. 결과 (QA: 네 권역 모두 전 항목 PASS — H·Q1·Q2·Q3·Q4·Q5·Q6·Q7·Q8·Q10·Q11·Q14·QR·QL·QW·QP·QC)
| 권역 | K | 격자(2m) | 하천·길·도강·마을·랜드마크 | 크기 | spawn |
|---|---|---|---|---|---|
| GG_HANYANG | **0.5** | 2561×2561 | 28·24·27·17·30, 성곽 1 | 7.4MB | 숭례문 남쪽 앞 |
| HH_HWANGJU | 0.3 | 2561×2305 | 62·7·10·13·5(방형 읍성 eupseong) | 8.1MB | 남문 밖 장터 길 |
| PA_PYEONGYANG | 0.3 | 2561×2049 | 55·9·8·18·17, 성곽 2 | 7.2MB | 대동문 앞 나루 |
| HG_HAMHEUNG | 0.3 | 2561×2305 | 61·7·7·11·8, 성곽 1 | 7.9MB | 만세교 동쪽 머리 |

- 권역마다 산출물은 다음과 같다: `height/landuse/climate.png`, `region.json`(archetypes + 마을 profile §9, axes, portals, `walls`, `big_rivers`), `map.png/json`, `qa.json`.
- 확인용 그림은 `shots/region_data/<ID>/`(overview, landuse_map, climate_map, zoom_*)에 있다.
- 엔진 불러오기를 `--region=GG_HANYANG`, `--region=PA_PYEONGYANG`으로 시험했다. 둘 다 정상이고 그림은 `shots/region_data/load_test/`에 있다.
- `region_data/regions.json`에 네 권역을 합쳤다(data-east의 `write_regions.py` 사용). 포털은 엔진 §'노정·포털 규칙'을 따랐다: `{id,name,x,z,to:"route:<A>-<B>"}`이고, 위치는 권역 안 길 끝이다.
  - 노정 id: `GG_HANYANG-HH_HWANGJU`, `HH_HWANGJU-PA_PYEONGYANG`, `JL_NAMWON_UNBONG-GG_HANYANG`, `GG_HANYANG-GS_GYEONGJU`, `GG_HANYANG-HG_HAMHEUNG`, `PA_PYEONGYANG-HG_HAMHEUNG`, `HH_HWANGJU-JANGSANGOT`, `HG_HAMHEUNG-BUKCHEONG`.
  - 노정 데이터는 아직 없다.
- 기후대: 한양·황주는 중부, 평양·함흥은 북부다.
  - 황주는 위도 38.7°N이라 공용 위도 규칙으로는 '북부'가 된다. 지시에 따라 `north_post`에서 중부로 바꿔 칠했다.
  - 네 권역 모두 바다에 닿지 않고 고산 하한(중부 1000m·북부 850m)에도 못 미친다(최고 336·374·277·460m). 그래서 coast·alpine 칸이 없는 것이 맞다.
  - 큰 강 물면은 해안으로 치지 않았다(`coast_km=0`).

## 3. 결정과 그 이유
1. **한양은 한 권역에 K=0.5로 담았다.**
   - 범위는 도성 전체(북악–낙산–남산–인왕)와 한강 나루 띠(마포·용산·서빙고·노량진·한강진·중랑천 어귀)다. 게임 좌표로 5.1×5.1km이고 높이맵 6.6M칸이다.
   - **송파는 뺐다.** 도성에서 동남쪽으로 약 12km 떨어져 있어 범위가 두 배가 된다. 송파는 한양→경주 노정의 첫 쉼터(나루·장)로 돌린다. 동대문 밖 길 → 살곶이다리 → 포털로 이어진다.
   - 구역은 settlement profile `district`로 나눴다: 궁궐·종로(운종가)·북촌·중촌(개천)·남촌·성 밖 장(칠패·배오개)·나루.
   - 짜임(layout)은 §9 허용 키로 쓰고 세부는 `layout_detail`에 남겼다(capital_grid·hill_alleys·linear_arcade 등).
2. **S급 큰 강(한강·대동강)은 build_region의 '바다' 경로로 만들었다.**
   - 원 DEM의 평탄 물면(해발 ≤6.2·5.5m)을 고르고, 강 제어선에 닿는 덩어리만 남겨 해발 −3m로 내렸다.
   - 그래서 물면은 y=해발 0 평면이고, 섬(능라도·양각도·노들섬)은 뭍으로 남는다.
   - region.json에는 다음과 같이 들어 있다.
     - `sea.kind="river"`, `big_rivers`
     - `rivers`에는 중심선이 `grade:"B"`, `spec_grade:"S"`, `render:false`로 들어 있다. 계약 등급 표기가 B까지이고 QA 코드도 그렇다.
   - 명세 §6에 따라 큰 강은 다리 없이 **나룻배 뱃길**로 건넌다.
     - 해당 길: 노량진·한강진·대동문 앞(`ferry` 길, class 지선).
     - 물 위 길 칸은 강바닥 높이로 되돌렸다. 그래서 강을 가로지르는 둑은 없다.
     - crossings에는 나루 1개와 뱃길 중간 표지점(`part_of`)을 넣었다.
   - 평양 능라도·양각도는 DEM 구멍과 타원 섬 가설(양쪽 물길 보장)을 함께 써서 만들었다(명세 §14).
3. **도시 DEM 보정.** 서울·평양 DEM에는 건물 높이가 섞여 있다. 저지대만 grey opening으로 깎았다(서울 150m 창, 평양 60m 창).
   - 개천·만초천·황주천·천주천·성천강·호련천은 OSM/제어선을 따라 하류로 단조 감소하는 골을 팠다(`carve`).
   - 지류 끝은 부모 선에 이었다.
   - 판 골을 따라가는 현대 도로·철도 선은 modern_fix가 메우지 않게 OSM 참고층에서 뺐다.
4. **위성·길목 처리.**
   - 황주의 장산곶·인당수(약 100km)와 구월산(약 50km)은 서쪽 포털 `HH_HWANGJU-JANGSANGOT`로 넘겼다(바닷가 띠/노정).
   - 평양의 묘향산과 함흥의 북청(약 80km)·철령은 노정 쪽에 둔다.
   - 함흥 안에는 본궁(함흥차사)과 성천강 충적평야(HG-03)를 넣었다.
5. **성곽.**
   - 한양도성: OSM '서울 한양도성' 선과 문·봉우리 기준점으로 만들었다. 멸실 구간은 직선이다. 사대문·사소문과 오간수문도 넣었다.
   - 평양 내성·북성·중성, 함흥읍성: 문을 잇는 가설 선이다.
   - 황주는 평지 방형 읍성 가설로, data-east의 `eupseong` 문 통로를 썼다.
   - region.json에 `walls:[{id,points,gates,height_m}]`를 더했고 `build.north_qw`에 길×성벽 검사 결과를 남겼다.

## 4. 가설 목록(검수 필요)
- **한양**
  - 개천 물길: 1760 준천 석축 가정. 이름은 '개천'(현대명 청계천).
  - 광통교·수표교는 원위치 표석 기준이다. 길과 만나는 건널목이 정확히 맞지 않아 랜드마크로만 둔 것이 있다(build.warnings).
  - 북영천(창덕궁 물)은 돈화문로 동쪽 약 50m로 옮겼다(길과 겹치지 않게).
  - 경희궁은 1870년에 일부 전각만 남은 상태로 가정했다. 육조거리 폭은 30m(실제 약 55m)다.
  - 한강 물면은 현대 강폭이다(1870년엔 모래벌이 더 넓었음).
- **평양**: 감영(선화당) 위치, 영명사·기린굴 좌표, 보통강 옛 물길(1946 개수 전)은 가설이다.
- **황주**
  - 읍성 모양과 크기, 객사·동헌·월파루 위치는 가설이다.
  - 도화동은 심청전 지명(B 태그, 강제 확정 아님)을 들마을로 둔 것이다.
- **함흥**
  - 읍성 선, 남문·동문·낙민루·구천각·치마대 위치는 가설이다.
  - 만세교는 실제 긴 널다리인데 계약 형식상 '섶다리'로 적었다.
  - 성천강 B급 폭은 게임 27m다.
- 자동 마을 후보(`auto_village_*`)와 무명 고개는 입지 규칙으로 만든 것이다(사료 없음).

## 5. 남은 문제·요청
- **(data-east·총괄) 공용 코드에 넣으면 좋을 것:**
  - `hydro`가 S급과 '강 물면'을 직접 아는 경로. 지금은 바다 경로 + north_post로 해결했다.
  - 위도 띠를 덮어쓰는 `climate_rule.band`.
  - remeander를 하천별로 끄는 설정(개천 같은 석축 하천).
  - QA QW에 `walls` 폴리라인 검사.
- **(terrain-engine)**
  - `sea.kind=="river"`이면 파도 대신 느린 강 물결로 그려 주길.
  - `render:false` 하천선은 리본으로 그리지 말 것.
  - `walls`(성곽 꺾은선)는 kit-landmark 성벽을 깔 자리다.
- **(kit-landmark)** 필요 kit: `hanyang_wall`·`hanyang_gate_great/small`·`gyeongbokgung`·`changdeokgung`·`jongmyo`·`pyeongyang_wall`·`pavilion_*`·`long_wooden_bridge`·`bongung` 등. 이름과 `size_m`은 region.json landmarks에 있다.
- QW-north 경고(근사 성벽 선 탓): 평양 강가길이 내성 강쪽 선과 겹친다. 함흥 경흥대로가 낙민루에서 55m 떨어진 곳에서 성벽 선을 지난다. 성벽 선을 다듬거나 문을 하나 더 두면 된다.
- 북한 지역 OSM은 위치 정확도가 보통이고, Overpass가 자주 시간 초과됐다. 캐시는 `tools/region/cache/<ID>/`(git 제외).
- 한양 성벽 선은 인왕산 쪽에 작은 꺾임이 남아 있다.
