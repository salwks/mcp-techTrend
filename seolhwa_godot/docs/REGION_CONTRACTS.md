# 권역 제작 계약서 — JL_NAMWON_UNBONG (남원·운봉·지리산 서부)

월드 개발계획서 v1.1(`seolhwa/docs/WORLD_DEV_PLAN.md`) W2~W3의 첫 권역. 여러 에이전트가 동시에 만든다.
**모든 에이전트는 이 문서와 계획서 §2·§3·§32·§33을 먼저 읽는다.** 명세서 원칙: 조선을 그리지 말고 조선이 생겨날 수밖에 없는 땅을 먼저 만든다.

시대: 1870년 전후 조선 후기. 근대·현대 요소(전봇대, 아스팔트, 콘크리트, 직강 제방, 댐 호수, 철도, 유리창) 금지.

## 1. 좌표와 축척

| 항목 | 값 |
|---|---|
| 실제 범위(초안) | 위도 35.3539–35.4811, 경도 127.3401–127.6599 (terrain-data 확정: 게임 범위를 256m 타일 경계에 맞춤. 남원읍성·광한루·여원재·운봉·황산대첩비·인월·실상사·반선·정령치 모두 포함) |
| 투영 | 기준점 lat0=35.4175, lon0=127.50 중심의 등장방형: `east_m = (lon-lon0)·cos(lat0)·111320`, `north_m = (lat-lat0)·110574` |
| 압축 | **K = 0.30** (가로·세로·높이 모두 같은 비율 → 경사는 실제와 같다) |
| 게임 좌표 | 1단위 = 1m. `x = east_m·K`(동쪽 +), `z = -north_m·K`(남쪽 +, 카메라 쪽), `y = (고도m − 60)·K` |
| 게임 범위 | x −4352…+4352, z −2112…+2112 (8704×4224m = 34×16.5 타일; height.png 4353×2113, cell 2m) |
| 타일 | 256m × 256m, 타일 (tx, tz)의 원점 = (tx·256, tz·256) — 계획서 §2.2 |
| 건물·캐릭터·식생 | **실물 크기(압축하지 않음)**. 마을 배치 간격만 압축된 땅에 맞춘다 |

카메라는 남쪽(+z)에서 북쪽(−z)을 내려다보고 회전하지 않는다(yaw 고정, pitch 27~50°, 거리 15~23m, fov 30). 건물 북쪽 면은 보이지 않으므로 단순하게 해도 된다(무대 세트 원칙). 한국 전통 건물은 대개 남향이라 잘 맞는다.

## 2. 파일 소유권 (자기 칸 밖의 파일은 고치지 않는다 — 필요하면 보고서에 요청)

| 경로 | 담당 |
|---|---|
| `tools/region/**`, `region_data/JL_NAMWON_UNBONG/**`, `shots/region_data/**` | **terrain-data** (실측 DEM·고증·수계·도로·토지이용 파이프라인, Python) |
| `scripts/region/**`, `scenes/region.tscn`, `shaders/region_*`, `shots/region/**` | **terrain-engine** (Godot 지형 메시·타일 스트리밍·물·원경·권역 실행 장면) |
| `kit/village/**`, `shots/kit/village/**` | **kit-village** (민가·마을 소품·다리·주막·장터) |
| `kit/landmark/**`, `shots/kit/landmark/**` | **kit-landmark** (남원읍성·관아·객사·광한루·실상사·비각) |
| `kit/nature/**`, `shots/kit/nature/**` | **kit-nature** (나무·풀·바위·벼랑·여울 + 타일별 식생 흩뿌리기) |
| `scripts/kit/kit.gd`, `scripts/kit/kit_preview.gd`, `scripts/materials.gd`, `scripts/main.gd` 등 기존 파일, 이 문서 | 총괄 |

- `class_name`을 새로 만들지 않는다(전역 클래스 등록이 겹친다). 같은 칸 안의 공용 코드는 `preload("res://kit/village/_common.gd")`처럼 불러 쓴다.
- `godot --import`는 돌리지 않는다(총괄이 한다). git 커밋도 하지 않는다(총괄이 통합할 때 한다).
- 웹 원본 코드: `../seolhwa/src/world/` (buildings.js, vegetation.js, terrain.js, materials.js, util.js) — 옮길 때 참고.

## 3. 공용 모델링 도구 `Kit` (`scripts/kit/kit.gd`)

웹 util.js를 옮긴 것. 좌표는 three.js 규칙(반시계 앞면, v 위가 1)으로 만들고 `Batch`가 Godot 규칙으로 바꾼다.
- 도형: `Kit.box(w,h,d, x,y,z, ry)`, `Kit.cyl(rt,rb,h,seg, x,y,z, rx,ry,rz)`, `Kit.cone`, `Kit.limb(a,b,r0,r1)`, `Kit.lump(r,detail,rng,rough,sy)`, `Kit.icosphere`, `Kit.plane`, `Kit.extrude(poly2d,h,y0)`, 직접 만들 땐 `Kit.Geo.new()`의 `tri()/quad()`
- 변환·색: `Kit.xf(g, x,y,z, rx,ry,rz, sx,sy,sz)`, `Kit.apply(g, Transform3D)`, `Kit.paint(g, top, bottom, jitter, rng)` — 색은 `Kit.hex(0xRRGGBB)`(sRGB 16진 → 선형)
- 난수: `Kit.Rng.new(seed).next()` / `.between(a,b)` (웹 rng와 같은 수열), 잡음 `Kit.vnoise/fbm/hash2`
- 묶기: `var b := Kit.Batch.new(); b.add(key, geo, outline=0.03); var node := b.build(name)` — 키 → 붓 텍스처: `thatch tile makse rock mud paper(창호지 띠살) needle leaf bark wood stone cloth(양면) lamp/glow(밤에 빛남) flat smooth organic onggi`(무늬 없음). 먹선 두께 0이면 생략. `water` 키는 반투명 물결 재질(UV 1 = 텍스처 한 장, 먹선 없음).
- 밤에 빛나는 것: `paper`·`lamp` 키는 아틀라스 마스크로 밤에 창호지·초롱이 빛난다(전역 `glow_k`).
- 미리보기: `godot --path seolhwa_godot res://scenes/kit_preview.tscn -- --kit=res://kit/<칸>/<이름>.gd --params='{"seed":3}' --shot=shots/kit/<칸>/<이름>.png [--time=18.3] [--pitch=38] [--yaw=20] [--dist=30] [--nofog]` — 게임과 같은 조명·후처리. `PREVIEW ... tris=` 로 삼각형 수가 찍힌다.

## 4. 키트(모델) 계약

각 모델은 `kit/<칸>/<이름>.gd` 하나, `extends RefCounted`, 다음 함수 하나:
```gdscript
static func build(params: Dictionary) -> Dictionary
# 반환:
# {
#   node: Node3D,             # 원점 = 바닥 중심. 정면(대문·마루)이 +z(남쪽, 카메라 쪽)를 향한다
#   colliders: [ {type:"circle", x, z, r} | {type:"box", minX, maxX, minZ, maxZ} ],  # 로컬 좌표, 통과 불가
#   lights: [ {x, y, z, kind:"lantern"|"window"|"torch"|"shrine"} ],               # 밤 조명 자리
#   occluder: bool,           # 플레이어를 가릴 만큼 크면 true (코어가 반투명 처리)
#   footprint: Vector2,       # 차지하는 x·z 크기(m) — 배치 겹침 검사용
#   anchors: { 이름: Vector3 },  # 문·마루·우물가 등 사건·NPC가 쓸 자리(선택)
#   interior: { minX, maxX, minZ, maxZ, floor_y, camera:{pitch,distance}, hide:[Node3D] }  # 들어갈 수 있으면(선택). floor_y = 마루 높이
#   pieces: [ {kit, params, xform: Transform3D(로컬), info: build() 결과} ]  # 배치형(읍성·관아·사찰)만: 조각 단위로 놓아 가림·스트리밍을 따로 처리(선택)
#   water: { y, outline: PackedVector2Array }  # 연못 등 물면(선택)
# }
```
- `params`: 최소 `seed`(int). 크기·변형은 각자 정하고 `kit/<칸>/catalog.json`에 목록(이름, 설명, params 예, footprint, 삼각형 수)을 남긴다.
- 성능 예산(먹선 포함 삼각형): 큰 건물 ≤ 15,000 / 민가 ≤ 6,000 / 소품 ≤ 800 / 나무 ≤ 1,500(LOD용 `params.lod=1`이면 ≤ 300) / 풀·작은 돌 ≤ 120. 같은 모델을 수백 번 놓을 식생은 `node` 대신 `mesh: ArrayMesh`도 함께 돌려주면 MultiMesh로 찍는다(`Batch.mesh()`).
- 화풍: 웹 CONTRACTS §2 — 낮은 폴리곤 + 부드러운 버텍스 색 그라데이션 + 먹선 + 채도 낮은 자연색(오방색 절제). 사실주의 텍스처 금지. 웹 마을(`data/ref/ref_*.png`, 원본 seolhwa/src/world)과 나란히 놓아도 어색하지 않아야 한다.
- 고증: 1870년 전후 조선 후기 기준. 확실하지 않으면 보고서에 "가설"로 적는다.

## 5. 권역 데이터 (`region_data/JL_NAMWON_UNBONG/`, terrain-data가 만들고 terrain-engine이 읽는다)

| 파일 | 내용 |
|---|---|
| `region.json` | 계획서 §8 양식(region_id, main_river, …, status, sources) + 아래 목록. 좌표는 모두 **게임 좌표(m)** |
| `height.png` | 16비트 회색조 높이맵. `region.json.height = {file, x0, z0, cell, w, h, y_min, y_max}` — 픽셀 (i,j) 중심이 게임 좌표 (x0+i·cell, z0+j·cell), 값 v → y = y_min + v/65535·(y_max−y_min). cell ≤ 2m 권장 |
| `landuse.png` | 8비트 인덱스(같은 격자 또는 2배 거친 격자, `region.json.landuse`에 메타): 0 숲, 1 풀밭·초지, 2 논, 3 밭, 4 길·맨땅, 5 물, 6 마을 터, 7 바위·벼랑, 8 모래톱·자갈, 9 대숲 |
| `region.json.rivers` | `[{id, name, grade:"S|A|B|C|D", width_m(게임), points:[[x,z,y수면],…], flows_to}]` 상류→하류 |
| `region.json.roads` | `[{id, name, class:"대로|지선|마을길|산길", width_m, points:[[x,z],…]}]` |
| `region.json.passes` / `crossings` | 고개 `{id,name,x,z,y}` / 나루·여울·다리 `{id,type,river_id,road_id,x,z}` |
| `region.json.settlements` | `[{id, name, type:"읍성|마을|역|원|주막|사찰|성황당|장시", x, z, radius_m, size, notes, confidence}]` |
| `region.json.landmarks` | `[{id, name, kit:"landmark/…", x, z, ry, confidence, source}]` (광한루, 남원읍성, 용성관, 실상사, 황산대첩비 등) |
| `region.json.spawn` | 플레이어 시작점 `{x, z}` (남원읍성 남문 앞 권장) |

## 6. 지형 엔진 계약 (`scripts/region/region_world.gd`, terrain-engine)

기존 `scripts/world.gd`(World)와 **같은 이름의 필드·함수**를 제공해 기존 코드(카메라·가림 처리·이동)를 그대로 쓸 수 있게 한다:
`height_at(x,z)`, `blocked(x,z,r)`, `move_circle(pos,dx,dz,r,extra)`, `interior_at(x,z)`, `camera_zones`, `interiors`, `occluders`, `lights`, `npcs`, `spawn`, `update(dt,time)`.
추가: `landuse_at(x,z) -> int`, `focus(pos: Vector3)`(스트리밍 중심 갱신), `add_static(node: Node3D, world_xform: Transform3D, info: Dictionary)`(키트 build() 결과를 놓고 충돌체·조명·가림을 등록 — 타일 단위로 붙였다 뗀다).
식생은 kit-nature의 `kit/nature/scatter.gd`를 타일마다 부른다:
```gdscript
static func scatter(tile_rect: Rect2, height_at: Callable, landuse_at: Callable, seed: int, lod: int, exclude: Array = [], roads = null) -> Dictionary
# roads: region.json roads 형식(null이면 scatter가 region.json을 직접 읽음). 중심선 폭/2+1m 안은 길로 보고 비우며, 길 남쪽 카메라 통로(4~20m)엔 큰 나무를 두지 않음
# exclude: 월드 xz Rect2(축정렬) 또는 {x, z, r} — 그 안에는 놓지 않음(건물·광장 자리)
# 반환 { nodes: [Node3D…(MultiMeshInstance3D 권장, 좌표는 월드)], buffers: [PackedFloat32Array|null …(nodes와 같은 순서, MultiMesh.buffer 형식)], colliders: [ {type:"circle", x, z, r} ], stats }  # 월드 좌표
# 이름 끝이 "_shadow"인 노드는 그림자 전용(보이지 않음)
```

## 7. 보고서

각 에이전트는 끝나면 `docs/reports/<담당>.md`에 남긴다: 만든 것, 미리보기 스크린샷 경로, 삼각형 수·성능, 고증 근거와 "가설" 목록, 총괄에게 요청할 것. 최종 응답은 이 보고서 요약.

## 8. 배치 (2단계)

배치는 데이터로 한다. 배치 담당이 `region_data/JL_NAMWON_UNBONG/placement_<구역>.json`을 쓰고, terrain-engine의 `scripts/region/placement_loader.gd`가 모든 `placement_*.json`을 읽어 놓는다.
```json
{ "area": "namwon", "items": [
  { "id": "nw_house_012", "kit": "village/house_compound", "params": {"seed": 12, "size": "medium"},
    "x": -3200.0, "z": 340.0, "ry": 0.0,            // 게임 좌표, ry = y축 회전(라디안). 정면 +z가 기본(남향)
    "y": null,                                     // null이면 지형 높이(터 고르기 후)
    "flatten": true,                               // footprint(+여유 2m) 안의 땅을 평평하게(가장자리는 부드럽게)
    "clear_veg": true,                             // footprint 안 식생 비우기 (기본 true)
    "group": "남원 읍내" }
]}
```
- `kit`은 `kit/` 아래 경로(확장자 없이). 배치형(읍성·관아·실상사·향교)은 로더가 `pieces`로 풀어 조각마다 등록한다.
- 다리·징검다리·섶다리: build() 결과 `walk`(걷기 면) 정보를 로더가 지형 높이 위에 덧씌운다. 형식(terrain-engine):
  ```gdscript
  walk: [ { minX, maxX, minZ, maxZ,            # 로컬 사각형(m) — 이 안에서만 걷기 면이 있다
            z: [z0, z1, …], y: [y0, y1, …] } ]  # 로컬 z를 따라 걷는 높이(로컬 y, 원점 기준) 꺾은선. 같은 개수, z 오름차순
  # 건너는 축이 x면 "axis": "x"와 x: […]. 사각형 안의 걷는 높이 = max(지형, 원점 y + 꺾은선 y)
  ```
  - 걷기 면 위에서는 하천 막기를 하지 않는다. 다리가 놓인 crossings(25m 안)에서는 "물 걸어 건너기" 임시 허용을 끈다.
  - walk가 없으면 로더가 `village/stone_bridge`(len·hw·arch), `village/seop_bridge`(len·hw), `village/jingeom`(len)은 params로 만든다.
  - 다리 `y`가 null이면 둑 높이(다리 양 끝 1m 바깥 지형 평균), `jingeom`·`narutbae`·`ppallaeteo`는 가까운 하천 수면(40m 안).
- 로더 동작(terrain-engine, `scripts/region/placement_loader.gd`):
  - 배치형은 키트에 `static func layout(params) -> Array`가 있으면 그것만 부르고(짓지 않음), 없으면 build() 결과 `pieces`를 쓴다. 조각 `{kit, params, x, z, ry, y?}`는 부모 기준 로컬. 조각의 y는 지형(터 고르기 후), `y`가 있으면 부모 높이 + y.
  - `footprint`를 항목에 `[w, d]`로 직접 줄 수 있다(없으면 build() 결과, 배치형은 조각 자리 + 8m).
  - flatten: footprint + 2m(회전 반영) 안을 평평하게(높이 = 항목 y, 없으면 그 안 평균), 바깥 5m에 걸쳐 원래 땅으로. 고른 터는 마당색(토지이용 6)으로 칠하고 잡음 디테일을 없앤다.
  - clear_veg(기본 true): footprint + 1m(flatten이면 고른 터 전체) 안 식생을 비운다. `kit/nature/scatter.gd`가 6번째 인자 `exclude: Array`(월드 xz `Rect2` 또는 `{x,z,r}`)를 받으면 넘기고, 결과에서도 거른다.
  - 같은 kit+params는 한 번만 짓는다(작업 스레드 여러 개). 돌린 상자 충돌체는 방향 있는 상자로 처리한다.
  - 다시 읽기: 실행 중 F5, 또는 `--reload`(파일이 바뀌면 1초 안에). 시험용 폴더는 `--placedir=res://…`(세미콜론으로 여러 개).
- 회전은 남향(ry=0)을 기본으로, 길·물길에 맞춰 ±30° 안에서. 카메라가 남쪽에 고정이라 북향 건물은 등만 보인다.
- 고증: 건물 수·간격은 압축된 땅(K=0.30)에 맞춘 근사. 위치는 region.json settlements·landmarks·roads를 따른다. 근거와 가설은 보고서에.
- 확인 방법: `godot --path . res://scenes/region.tscn -- --warp=x,z --time=10 --shot=shots/... --frames=200 --quit` (+ `--cam=` 등 region_main 인자, 보고서 terrain-engine.md 참고)

## 9. 고을 성격표 (고을 차이 — docs/TOWN_IDENTITY_CLIMATE_PLAN.md A0·A0.5)

`region.json` 최상위 `archetypes`(입지 유형 기본값)와 각 settlement의 `profile`(유형 + 고유값 덮어쓰기). 배치 생성기와 엔진은 `profile`을 유형 기본값과 합쳐 읽는다.
```json
"archetypes": {
  "eupchi":   { "roof": {"giwa": 0.45, "choga": 0.55}, "wall": "todam", "layout": "walled_grid", "entrance": "gate", "people": ["관속","양반","장꾼"], "animals": [], "mood": {"fog": 0.3, "wind": 0.2} },
  "plain":    { "roof": {"choga": 0.9, "giwa": 0.1}, "wall": "fence", "layout": "round_cluster", "entrance": "zelkova_square", "people": ["농부"], "animals": ["소"] },
  "river":    { "roof": {"choga": 0.85, "giwa": 0.15}, "wall": "todam", "layout": "fan_from_ferry", "entrance": "ferry", "people": ["뱃사공","장꾼"], "animals": ["소"] },
  "mountain": { "roof": {"neowa": 0.6, "gulpi": 0.2, "choga": 0.2}, "wall": "stone_terrace", "layout": "terraced", "entrance": "watermill_bridge", "people": ["약초꾼","사냥꾼","숯쟁이"], "animals": ["개"] },
  "pass":     { "roof": {"choga": 1.0}, "wall": "none", "layout": "few_roadside", "entrance": "seonghwang_cairn", "people": ["나그네","주모"], "animals": [] },
  "temple":   { "roof": {"choga": 0.8, "giwa": 0.2}, "wall": "todam", "layout": "along_temple_road", "entrance": "stone_jangseung", "people": ["스님","보살"], "animals": [] },
  "coast":    { "roof": {"choga_low": 1.0}, "wall": "stone_net", "layout": "linear_shore", "entrance": "wharf", "people": ["어부","객주"], "animals": ["갈매기"] },
  "island":   { "roof": {"jeju_stone": 1.0}, "wall": "basalt", "layout": "olle_alleys", "entrance": "dolhareubang", "people": ["해녀"], "animals": ["말"] },
  "capital":  { "special": true }
},
"settlements": [ { "id": "unbong_eup", …, "profile": { "archetype": "plain", "climate": "south", "roof": {"choga": 0.8, "giwa": 0.2}, "wall": "stone", "signature": "억새 들판 + 돌장승", "trades": ["장시"], "notes": "고원 들, 동편제 고장" } } ]
```
- 키: `roof`(지붕 비율: giwa·choga·choga_low·neowa·gulpi·guitul·jeju_stone), `wall`(stone·stone_terrace·todam·fence·none·stone_net·basalt), `layout`(walled_grid·round_cluster·linear_street·fan_from_ferry·terraced·few_roadside·along_temple_road·linear_shore·olle_alleys), `entrance`(어귀 장면 키), `people`·`animals`(NPC 종류), `climate`(south·central·north·alpine·coast — §B 기후대), `signature`(고을 상징 한 줄), `trades`(생업).
- 통과 기준: 고을 이름을 가린 게임 화면으로 어느 고을인지 맞힐 수 있어야 한다(눈가림 시험).
