# 시흥시 정책·사업 지도

시흥시청 게시판(보도자료, 고시·공고)을 **매주 1회** 자동으로 수집해 OpenStreetMap 지도 위에 표시합니다.

## 구성

| 파일 | 역할 |
|---|---|
| `collect.py` | 수집기 (표준 라이브러리만 사용). 목록 → 본문 → 분야 분류 → 위치 추정 → `data/projects.json` 누적 저장 |
| `sources.json` | 수집할 게시판 주소. 게시판을 추가/수정하려면 여기만 고치면 됩니다 |
| `places.json` | 동·지명 → 좌표 사전 (근사값). 새 지명을 추가하면 위치 정확도가 올라갑니다 |
| `index.html` | 지도 화면 (Leaflet + OpenStreetMap, 분야/기간/출처 필터, 검색) |
| `data/projects.json` | 수집 결과 |
| `../.github/workflows/siheung-policy-map.yml` | 매주 월요일 08:17(KST) 실행 |

## 동작 방식과 한계

- **위치**: 제목·본문에 나오는 동 이름/지명(예: 배곧, 목감, 거북섬)을 찾아 그 대표 좌표에 표시합니다. 지명이 없으면 "시 전역"으로 시청 위치에 모입니다. 정확한 주소 좌표가 아니라 **동 단위 추정**입니다.
- **분야**: 키워드 기반 자동 분류(복지·교통·도시개발·환경·경제·문화·교육·안전·행정 일반)라 틀릴 수 있습니다.
- **누적**: 한 번 수집된 항목은 계속 보관되고, 매주 최근 3페이지를 다시 확인합니다.
- **수집 실패**: 시청 홈페이지 구조가 바뀌거나 해외 IP(GitHub Actions)를 차단하면 실패할 수 있습니다. 실패 내역은 `projects.json`의 `sources[].errors`와 지도 상단에 표시되고, 모든 출처가 실패하면 워크플로가 실패로 끝납니다.

## 실행

```bash
python3 siheung_policy_map/collect.py          # 수집
python3 -m http.server -d siheung_policy_map   # http://localhost:8000 에서 지도 확인
python3 -m pytest siheung_policy_map/tests     # 파서 테스트
```

`index.html`은 `data/projects.json`을 fetch 하므로 파일을 직접 여는 대신 로컬 서버나 GitHub Pages로 열어야 합니다.
