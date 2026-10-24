# 고을 생성기 v2 — Layers 0–2 구현 보고 (settlement-v2-L0-2-impl)

브랜치 `claude/settlement-v2` · 명세 `docs/reports/settlement-v2-L0-2.md`(2회차 확정 명세가 기준) · 뒤 층 설계 `docs/reports/settlement-v2-L3-8.md`(참고, 구현 안 함).
Godot 쪽 변경 없음 — 오프라인 Python 도구만.

## 1. 실행

```sh
cd seolhwa_godot
python3 -m venv tools/settlement/.venv && tools/settlement/.venv/bin/pip install -r tools/settlement/requirements.txt
PY=tools/settlement/.venv/bin/python
$PY -m tools.settlement.cli bake --region JL_NAMWON_UNBONG --settlement namwon_eup --out OUT
$PY -m tools.settlement.cli fixture --name syn_terrace --out OUT
$PY -m tools.settlement.cli all --out OUT            # 합성 4(+보충 1) + 실제 4 + 실패 3
$PY -m tools.settlement.cli determinism --out OUT    # 두 번 구워 바이트 비교
$PY -m tools.settlement.cli sheet --out OUT          # combined.svg → combined.png (헤드리스 Chrome, 검토용)
$PY -m pytest -q tools/settlement/tests
```

선택 인자: `--envelope`/`--allowed`(명시 계획 영역 GeoJSON — 배정 우선순위 1), `--tier`, `--family`, `--label`.
산출(사이트마다): `input.json`(settlement-input/1), `plan.json`(settlement-plan/1), `site.geojson`, `site-fields.npz`, `00-site.svg`, `01-program.svg`, `02-frame.svg`, `combined.svg`.

의존성(정확히 고정, PyPI): numpy 2.5.4, scipy 1.18.1, shapely 2.2.0(GEOS 3.14.1), pillow 13.0.0, networkx 3.7, pytest 9.1.1. Python 3.13.0.

## 2. 모듈 (명세 §2 배치 그대로 + 보조 3개)

| 파일 | 역할 |
|---|---|
| `adapters/region.py` | region_data → 정규 입력. 높이는 한 번만 해독(remap 다시 안 함), 강 점 `[x,z,y]`+점별 폭, landuse 4 m → 2 m는 가장 가까운 중심(`floor(t+0.5)`), `sea.kind=river`(평양)는 민물, 배정 우선순위(명시 → core/기존 성벽 → area_m2 원판 → radius_m), bbox는 허가로 쓰지 않고 불일치만 보고, 확장 0 |
| `fixtures.py` | 명세 §4 합성 지형 4개(식 그대로, [-512,512], 2 m, 길 2개씩) + 보충 `syn_mountain`(산성용) + 실패 3개 |
| `raster.py` | 격자(셀 중심 규약), σ=2 m 평활, 경사·향, 원판 평균 TPI, 래스터화·다각형화, 결정적 npz |
| `site.py` | Layer 0 |
| `program.py` | Layer 1(수용력 먼저) + 배타적 면적 장부 |
| `frame.py` | Layer 2(4가족 생성기, 관아 터, 문, 수문, 주 가로, 평가·순위) |
| `routing.py` | 8방향 격자 최소비용(csgraph Dijkstra = 휴리스틱 0인 A*), 모서리 자르기 금지, 비용 l(1+8g²), 경사 상한 |
| `geometry.py` | 0.05 m 격자, 정규 고리(xz 수학 반시계, 가장 북쪽 꼭짓점 시작), 사슬 구간, 내용 해시 |
| `validate.py` | 명세 §5 자동 검사 + JSON 스키마 부분 검사기 |
| `svg.py` | 00/01/02/합본 도면 |
| `plan.py`·`model.py`·`rules.py` | (보조) 계획 조립·공유 기하 저장소 / 입력 모형 / 규칙 로더 |
| `rules/default.json` | 모든 조정값(value·unit·source·confidence·kind, 일부 applicability·note) |
| `schemas/*.json` | settlement-input/1, settlement-plan/1, settlement-rules/1 |

## 3. 층별 구현 요약

**Layer 0** — σ=2 m 가우스 평활 후 중심차분 경사·향(향은 내리막 방위), TPI 30/100/300 m(원판, 가장자리 정규화), 국지 기복, 백분위 고도, 물까지 거리(EDT)와 가장 가까운 수면 W(x), 범람 화면 +1/+3/+5(물에 8연결로 이어진 칸만, +3 점유 제외, 보조 지표 R), 물길 예비(폭/2+3 m), 용도별 건축 가능(주거 ≤15°/선호 8°, 관아 ≤10°/선호 5°), 길·물 접근 비용장(8방향, l(1+8g²), 지도에 있는 건널목만 물 위 통과), 농지 300/600 m·잠식, 터 점수 S_T(정보용). 보류: 흐름 누적, 일조, 조망, 진산/안산 자동 판정(주어진 축은 선호로 사용).

**Layer 1** — 등급은 시설 의무와 비율만 정하고 호수는 땅에서 나온다. 관아 묶음(full/compact 조합)을 큰 것부터, 주거 최소를 남기는 가장 큰 묶음 선택(못 하면 `insufficient_capacity`). 주거 성분마다 Σn·a ≤ (1−.12−.20)·A, 계급은 최대 나머지 반올림, 성분 배정은 탐욕 → 실패 시 정확 DFS(노드 상한; 상한에 걸리면 `optimal:false`로 하한 표시). ×1.2/×1.44는 `program.py`에서 단 한 번(`scale_applied:true`). 장부는 우선순위(물 → 물길 예비 → 보호 → 고정 → 관아 → 앞마당 → 주 가로 → 물 확보 → 범람 → 급경사 → 주거/자투리)로 배타 분할, 잔차 ≤0.1 m². 역사 호수는 근거 없으면 `null`.

**Layer 2** — 4가족:
- 평지성: 중심 9 × 방위 0–165°(15°)+축 × 10 m 크기(종횡 1–1.6) × 일반/모깎기 → 포함 필터 → 상위 24 → 꼭짓점 2 m 이동(고정 순서, 목표 개선+유효 유지).
- 평산성: 하위 등고 집합(2 m 간격) ∪ 뒤쪽 부채꼴(±60°, 축 또는 오르막 질량 방향)의 더 높은 하위 집합 → 씨앗 성분, 구멍 채움, 열고 닫기 6 m, 단순화 2 m. 뒤 언덕이 8 m 이상 들어와야 평산성으로 인정(가족 정의).
- 산성: 상위 등고 집합 2 m 간격 성분(구멍 있으면 능선 고리, 없으면 테뫼), 관아 터·물 접근을 둘러싼 것만. 실패는 `no_candidate_found`(증명 아님).
- 무성곽: 길 접근 비용장으로 자라는 주거 가능 성분 묶음(40/60/90/130 m + 전체), 각 성분은 걸어서 닿아야 수용력에 포함.
공통 평가: 관아 터 10 m 격자 × 15°+축(벡터화), 빔 탐색(폭 6, 상태당 다양한 8개), 입구는 모두 같은 ≤10 % 회랑 성분(경계/길에 닿는) 안; 묶음은 큰 것부터, 같은 배치 접두가 실패한 묶음은 건너뜀(정확한 가지치기), 24회 상한. 문: 둘레 4 m 표본, 길 접근(교차·근처) 방위 묶음(45°) → 묶음당 상위 8 후보 → 배정 열거(간격 ≥40 m, 2–4개 선호), 모자라면 ≤10 % 연결이 되는 자리에 추가 문. 성 밖 연결로도 같은 ≤10 % 규칙. 길/성벽 교차는 모두 문(허용 16 m 안) 또는 성 밖 우회로(경로 기록), 아니면 오류. 물길/성벽 교차는 수문(폭 ≥8 m)/수구, 40 m 넘는 물·열린 물 위 성벽은 기각. 주 가로: 8방향, 한 칸 한 칸 경사 ≤10 %, 7.2 m 폭 전체가 물·보호·고정·관아에서 떨어지도록 중심선 칸 제한, 최단 경로 나무를 명시 분기점으로 쪼갠 노드·링크(2 m 경사 단면 포함), 단순화 뒤 다시 경사 검사. 물 확보: 성 안 물가(≤300 m) 또는 우물 자리(지하수 불명 표시). 목표: 관아 적합 .25·접근 .25·조밀 .20·지형 경제 .20·축 .10(축 없으면 0.5 중립), 범위는 규칙 파일. 8개 대안(IoU>.92 중복 제거), 동점은 내용 해시 순.

**결정성** — 정렬 키 JSON, 좌표 0.05 m 격자, 타임스탬프 없음, npz는 zip 시각 1980 고정, 기하는 내용 해시 id(`g-<sha1 12>`, 충돌 검사)와 의미 id(`gate-01`, `civic-gaeksa`, `pc-01`) 분리, 후보·성분·동점 순서 고정.

## 4. 구현 중 발견한 것

1. **shapely `set_precision`이 결과에 정밀도 모형을 남긴다** → 이후 겹침 연산이 모두 0.05 m 스냅 반올림으로 돌아 `T∩g + T−g ≠ T`(원형 영역에서 −0.135~−0.46 m²). 장부 계산은 정밀도 모형을 지운(`set_precision(g, 0)`, 격자 위 꼭짓점이라 무손실) 부동소수 연산으로 바꿔 잔차 0. 회귀 시험 `test_overlay_additivity_regression`.
2. **세로 배율** — 권역 높이는 K=0.3(낮은 땅, remap 기울기 1)로 눌려 있어 "+3 m"를 원지형 m로 읽으면 게임 0.9 m, 게임 m로 읽으면 원지형 10 m가 된다. 규칙 `flood.stage_units`(기본 `source_m`)로 바꿀 수 있게 두었다 — **열린 결정**. 국지 배율은 배정 중앙 높이에서 한 번 구한 값이라 remap 꺾임을 넘는 곳은 근사.
3. **최근접 수면 범람의 누수** — 합성 산등성이처럼 물길이 능선을 넘으면 꼭대기 수면이 바깥 비탈 전체를 "범람"으로 만든다. 수평 도달 300 m 상한(`flood.max_reach_m`)으로 막았으나 근본 해결(HAND/흐름 방향)은 보류.

## 5. Codex 검토와 대응

### 5.1 계획 검토(코딩 전)
| 지적 | 대응 |
|---|---|
| 보호지를 빼고 경계를 만들면 물길을 둘러쌀 수 없음 — 보호는 점유 금지이지 둘러쌈 금지가 아님 | 물·물길은 둘러쌀 수 있고 수문으로 처리. (최종 검토 뒤 농지 보호도 둘러쌈 허용으로 바꿈, 5.2) |
| 8방향 유지(32방향은 명세 변경) | 8방향 유지. 산성 픽스처 실패를 그대로 보고 |
| 건널목 점 하나로 넓은 강을 건너게 하면 안 됨; 나루·섶다리는 상설 다리 아님 | 새 건널목은 만들지 않음(Layer 4), 지도에 있는 건널목 칸만 통과, 건널목 없는 물은 막힘 → `water_crossing_required` |
| 성분별 정수 배정, 묶음·배치 대안 유지, 탐색 소진과 용량 부족 구분 | 성분 배정 + 묶음 순회 + 빔 상태 순회, `capacity_search_exhausted`·`no_candidate_found` 분리 |
| 마을 터(6)로 배정 확장 금지 / 배정 밖 농지 보호, 안쪽 농지는 잠식으로 | 그대로 |
| 성 밖 우회는 장애·경사 규칙을 따르고 원래 길로 이어야 함; 한 길의 여러 교차 각각 처리 | 우회로는 성 밖 그래프(≤10 %)에서 교차점 → 문 경로로 기록, 교차마다 따로 |
| 래스터 정렬 규약 명시 | 셀 중심 규약, landuse 최근접 중심 재표본, 창 원점 정수 오프셋 검사(L0.alignment) |
| 평지성 방위 0–75°는 장축 90–165°를 놓침 | 0–165° 전부 |
| 장부는 배타적 범주·우선순위 필요 | 우선순위 분할 + 잔차 검사 |
| L3을 위한 의미 보존(허가 의미, 잠금 정체, 관아 기능, 물길 id, 회랑 예비 다각형) | plan.territory.permissions, civic_reserves(contents·court_min·socket), 회랑 reservation 다각형 + 중심선 + 노드, water_features id |
| 스키마·결정성 강화(사슬 감김, 의미 id와 해시 분리, 충돌 검사) | chainage `[s0,s1]`+`wraps`, 의미 id/기하 해시 분리, 충돌 시 예외 |

### 5.2 구현·도면 검토(8곳 시트 포함) — "아직 승인 불가" 판정, 지적과 대응
| 지적(심각도 순) | 대응 |
|---|---|
| 보호 농지를 둘러싸는 것까지 금지하고 있음 | 경계 생성 영역 = 허용 − 이웃 마을 − 잠금. 농지는 둘러쌀 수 있되 점유(관아·회랑·물 확보·주거) 0. 이웃 마을을 둘러싸면 오류 |
| 지도에 없는 길-물 교차를 통과 가능으로 처리 | 매칭된 건널목 칸만 통과(`bridge_mask`), 나머지는 막힘 + 경고 |
| 주거 접근이 유클리드 80 m | 회랑에서 걸어서 80 m(8방향 비용, 물·보호·관아 못 지남) 안에 닿는 성분만 수용력. 하구 픽스처 남쪽 덩어리(강 건너)가 빠져 59→32호 |
| 접근 실패 시 묶음 탐색을 바로 끝냄 | 틀 수준 실패 뒤에도 가장 작은 묶음을 한 번 더 시도 |
| 탐욕 배정이 최대가 아님(2,520+2,304 m²에서 7호, 실제 8호) | 탐욕 실패 시 정확 DFS, 노드 상한에 걸리면 `optimal:false`. 시험 `test_packing_exact_codex_case`(8호) |
| 회랑 7.2 m 폭 전체의 여유 미검증, 입구 점프 미검증 | 물·보호·잠금·관아를 반폭(2칸)만큼 부풀려 중심선 제한(앞마당은 예외), 입구 소켓→칸 직선이 관아·물·틀 밖을 지나면 기각 |
| 범람: 300 m 상한, 단위 변경, 국지 배율 | 단위를 규칙 스위치로 노출, 보고서에 열린 결정으로 기록. 상한·배율 근사는 알려진 한계로 남김 |
| 검증이 게시를 막지 않음, 허용 오차가 둘레 전체에 비례 | 독립 검사 하나라도 실패면 status를 `failed`(validation:…)로 내림. 보호 침범 허용 오차는 공유 경계 길이 × 격자/2(국소) |
| 도면: 기각 후보가 확정처럼 보임 | 기각 후보는 붉은 점선 + "기각 후보(진단용)" 표기 |
| 산성 실패는 규칙상 그럴 법하지만 증명 아님, 별도의 될 수 있는 산 픽스처 필요 | 보충 `syn_mountain`(평정 산·꼭대기 못) 추가 → 산성 유효 |
| 남원·마을의 실패는 옳은 동작 | 유지(아래 6) |

남은 지적(미처리): 평산성 뒤 부채꼴이 "턱" 모양으로 보이는 문제(방어 지형 판단 없음), 터라스/하구 회랑이 최단 경로 가지라 가로 위계가 아님(Layer 4 몫), 지역별 remap 꺾임, 넓은 범람원·여러 수면 시험 부족.

## 6. 결과 (2026-10-23 마지막 굽기, 시트는 `docs/reports/settlement-v2-L0-2/*.jpg`)

| # | 곳 | 지형 확인 | 가족·등급 | 상태 | 틀·호수 | 문/수문/우회 | 대안 |
|---|---|---|---|---|---|---|---|
| 01 | syn_terrace | 평탄(경사 중앙 0.23°), 북쪽 저지 범람 | 평지성·중 읍치 | **valid** | 133,843 m², 86호(관아 full) | 3/0/3 | 8 |
| 02 | syn_basin | 북쪽 뒷산 45 m, 경사 중앙 8° | 평산성·소 읍치 | **valid** | 36,190 m², 15호(배정 추정 126) | 2/0/1 | 1 |
| 03 | syn_ridge | 경사 중앙 28.7°, 능선 고리, 물길이 능선을 넘음 | 산성·산성(입보) | insufficient_capacity(civic_fit_failed) | — | — | 0 |
| 04 | syn_estuary | 경사 2.8°, 바다·하구 | 무성곽·물가 마을 | **valid** | 52,790 m², 32호(강 건너 덩어리는 접근 불가로 제외) | 길 입구 | 3 |
| 05 | JL_NAMWON_UNBONG/namwon_eup | 평탄(중앙 0°, 기복 3.2 m), +3 범람 5 % | 평지성(auto)·중 읍치 | insufficient_capacity | core 186 m 상자 안에 관아 compact 묶음+최소 25호 불가(배정 추정 13호) | — | 0 |
| 06 | GS_GYEONGJU/bulguksa_village | 완경사 5.7°, +3 범람 40 %(세로 배율 0.25) | 무성곽·민촌 | insufficient_capacity | 배정 원판 5,984 m² → 0호 | — | 0 |
| 07 | JL_NAMWON_UNBONG/banseon | **급경사 37.5°**(골 어귀), 주거 가능 1.9 % | 무성곽·산촌 | no_candidate_found | 배정 원판 4,560 m² 중 쓸 땅 없음 | — | 0 |
| 08 | GW_GANGNEUNG/anmok_village | 평탄 1.8°, 바닷가, +3 범람 43 % | 무성곽·물가 마을 | insufficient_capacity | 6,416 m² → 1호 | — | 0 |
| 보충 | syn_mountain | 평정 산, 비탈 ≤17 % | 산성(테뫼)·산성(입보) | **valid** | 90,564 m², 64호 | 2/0/0 | 4 |
| 실패1 | fail_blocked_access | 30 m 벼랑 웅덩이 | 평지성 | failed(**blocked_access**) | | | |
| 실패2 | fail_impossible_civic | 60×60 m 배정 | 평지성 | insufficient_capacity(**civic_fit_failed**) | | | |
| 실패3 | fail_water_crossing | 건널목 없는 강 | 평지성 | failed(**water_crossing_required**) | | | |

명세가 고른 실제 4곳은 모두 존재했다. 지형 확인 결과 "단구/산 등진/골/하구" 성격은 맞지만(남원 평탄, 불국사 완경사, 반선 급한 골, 안목 바닷가 저지), 3개 마을은 배정이 area_m2 원판(4.5–6.4천 m²)뿐이라 수용력이 0–1호다. 이것은 명세가 의도한 "억지로 넣지 않기"의 정직한 결과다.

**만약(what-if, `--envelope`·`--allowed`로 settlement bbox를 명시 계획 영역으로 준 경우 — 명세상 bbox는 허가가 아니므로 결과에 `variant: bbox-envelope` 표기)**: 남원 420×416 m → **valid**(60,296 m², 28호, 문 2·수문 2·우회 2, 축 136° 방향 관아), 불국사 1호·안목 2호(여전히 부족), 반선은 bbox도 경사 42°라 후보 없음.

**불변 조건**: 위 모든 산출물에서 독립 검사 실패 0. 유효한 틀(terrace·basin·estuary·mountain·남원 what-if)은 L0.decode·alignment·water·probes, L1.ledger(잔차 0.0 m²)·rounding·scale_once, L2.ring·crossings·openings·containment·intrusion·corridors, plan.geometry_refs·schema가 모두 통과(무성곽은 고리·문 검사 해당 없음). 기각된 곳의 L2 검사는 "기각 후보 결과"로만 기록(해당 없음 처리).

**결정성**: `determinism`으로 8곳(syn_terrace·basin·ridge·estuary·mountain, namwon_eup·bulguksa_village·anmok_village)을 두 번 구워 64개 파일(JSON·GeoJSON·npz·SVG) 바이트 동일(`docs/reports/settlement-v2-L0-2/determinism.json`). pytest 21개 통과(단위 15 + 파이프라인 6, 재실행 바이트 비교 포함).

## 7. 알려진 한계

- **명세 산등성이 픽스처의 산성은 통과하지 못함**: 안쪽 비탈 55 %에서 8방향·칸마다 ≤10 % 회랑은 내려갈 수 없고, 꼭대기 물길의 +3 m 범람이 분지 바닥을 지운다. 명세 변경(회랑 경사를 평활 중심선으로 재기, 산성 길 등급 분리) 또는 픽스처 변경이 필요 — 결정 대기. 대신 `syn_mountain`으로 산성 생성기를 시험.
- 관아 배치는 격자+빔이라 촘촘한 채우기에 약하다(남원 core에 compact 묶음이 기하적으로는 겨우 들어갈 수 있으나 못 찾음 → 어차피 주거 최소 미달).
- 순위가 명세 가중치만 써서 수용력이 작은 틀이 이길 수 있다(syn_basin 15호 vs 배정 추정 126호). 평산성 뒤 부채꼴이 "턱"처럼 보임.
- 범람: 정적 욕조 화면, 300 m 도달 상한, 세로 배율은 배정 중앙에서 한 번(remap 꺾임 근사), 단위(원지형 m vs 게임 m) 열린 결정, 해안 해일 자료 없음.
- 무성곽 마을 틀은 접근 비용으로 자란 땅 덩어리일 뿐 가로 위계가 없다(Layer 3–4 몫).
- 진산/안산 자동 판정·흐름 누적·일조·조망·토공 최적화 보류(명세 1차 범위대로).
- 실행 시간: 실제 곳 L0 약 8–10 초, 틀 탐색 수십 초–수 분(실패 픽스처는 묶음 순회로 더 김).

## 8. Layer 3+가 필요로 하는 것

- 배정 문제부터: 남원·마을들은 명시 계획 영역(allowed)을 주인이 정해야 한다(지금은 확장 0). Layer 3은 L0–2 허가를 넘을 수 없다.
- L2가 이미 내보내는 것: 걸어서 닿는 주거 성분 다각형(안정 id)·성분별 정수 호수 배정, 관아 터(내용·마당 최소·입구 소켓·방위), 주 가로 노드·링크(분기점 명시, 2 m 경사 단면, 7.2 m 예비 다각형), 성벽 사슬과 문·수문 구간, 길 우회·연결로, 물 확보 터(불확실성), 보호·잠금·허가 의미, revision_requests.
- 아직 없는 것(Codex 지적): 구역 면적 분포(중앙값만 있음), 성 밖 의무(향교·사직단·여단·장터 성 밖 안)의 배치, 건널목 예비(Layer 4 다리), 접근 계약의 완전한 입구 연결, 수정 요청의 대상별 형식(접근·수문·배정·프로그램).
- 열린 결정 2개: 범람 단위, 산성 회랑 경사 측정법.

## 9. 3회차 갱신(2026-10-23 조정자 결정 · 2026-10-25 소유자 결정 · 감사 K1–K3·K9–K11)

이 절이 §6보다 우선한다. 자세한 내용은 `settlement-v2-wp0-baseline.md`·`settlement-v2-wp1-contract.md`·`settlement-v2-wp2-identity-locks.md`·`settlement-v2-wp3-align.md`.

| 시트 | 곳 | 상태(기준안) | 비고 |
|---|---|---|---|
| 01 | syn_terrace | valid, 86호, 문 3 | |
| 02 | syn_basin | valid, **125호**, 문 2 | 수용력 순위 + 관아 입구 상호 도달 검사로 15호 → 125호 |
| 03 | syn_ridge | **valid**, 44호, 문 2 | 산 길 등급(갈지자 약 1 km), 물길을 골짜기로 |
| 04 | syn_estuary | valid, 33호 | |
| 05 / 09 | 남원 읍 | insufficient_capacity 3호 / 제안안 insufficient 3호 | 이야기 잠금 304개, 후보 20/24가 잠금 충돌 |
| 06 / 10 | 불국사 마을 | insufficient 0호 / **제안안 proposed 21호** | 제안안은 숲 5.3 ha 잠식·불국사 50 m 안 — 승인 필요 |
| 07 / 11 | 반선 | no_candidate_found / 제안안 동일 | 급경사 |
| 08 / 12 | 안목 | insufficient 1호 / 제안안 1호 | |
| 13 | syn_mountain | valid, 205호 | 보충 산성 |
| 14 | syn_terrace_locked | valid, 90호 | V14 잠금 픽스처 |
| 15–17 | 실패 3종 | failed / insufficient | |

범람은 게임 m(+0.5/+1.5/+3.0, +1.5 점유 제외)로 바뀌어 §6의 수치(원지형 m)와 다르다.
