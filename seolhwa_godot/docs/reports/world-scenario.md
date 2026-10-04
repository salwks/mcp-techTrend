# world-scenario — 마스터 시나리오 v2.1이 쓰는 장소·프롭 상태·데칼·사건 날씨 (세계 쪽 API)

이야기 쪽(story agent)이 부르는 세계 API와, 새로 만든 장소의 id·앵커 목록. 이야기 논리는 여기 없다.
- 시나리오: `seolhwa/docs/scenario/seolhwarok_master_scenario_storyboard_v2.1_folklore_only_subevents.md`, 프롭: `seolhwarok_PROP_MASTER_v1.0.md`
- 배치 다시 만들기: `python3 tools/scenario/place_scenario.py` (아래 모든 `placement_scenario.json`·`world_scenario.json`·`decals_scenario.json`, 제주 사굴 항목)
- 키트 점검: `godot --headless --path . -s res://tools/scenario/check_kits.gd`
- 실행 중 시험: `godot --path . res://tools/scenario/sc_test.tscn -- --region=GG_HANYANG --nostory --warp=x,z --scsteps="state:id:FIRE_2;wait:60;shot:shots/x.png;quit"`
  (단계: `wait` `warp` `state` `decals:그룹:on|off` `decal:종류:x,z,크기` `trail:종류:x,z,…` `weather:종류:초:페이드` `release` `time:시:초:페이드` `anchor:id:이름` `interior:id` `shot` `quit`)
- 키트 미리보기에 상태: `kit_preview.tscn -- --kit=res://kit/scenario/changgo.gd --state=FIRE_2,hatch:OPEN --hide=front,roof`

`world` = `RegionWorld`(region_main의 `world`), `weather` = region_main의 `weather`.

## 1. 프롭 상태 (PROP_MASTER §11)

```gdscript
world.set_prop_state(key, state) -> bool      # key = 배치 id 또는 "배치 id/그룹"
world.get_prop_state(key) -> String
world.prop_anchor(id, "앵커") -> Vector3|null # 키트 앵커의 월드 좌표(문·책상·숨은 바닥…)
world.props.states_of(key) / groups_of(id) / anchors_of(id) / ids(prefix) / reset_all()
world.props.changed  # signal(key, state)
```
- 상태: `NORMAL USED EMPTY BROKEN FALLEN WET BLOODY BURNT MOVED SEALED OPEN` + 창고 불 `FIRE_1 FIRE_2 FIRE_3`(PRP_FIN_003: 연기·한쪽 불 / 지붕까지 번짐·검은 연기·불티 / 무너짐).
- 아직 지어지지 않은 물건(먼 타일)·F5 다시 읽기 중에도 상태를 기억했다가 놓일 때 적용한다. 새 게임은 `world.props.reset_all()`.
- 배치 데이터로 처음 상태: 항목 `"state": "BURNT"` 또는 `{"main": "BURNT", "hatch": "OPEN"}`. 배치형 조각은 부모의 `"states": {tag: 상태}`.
- 키트가 그 상태를 직접 그리면(노드 `S_<그룹>_<상태[-상태…]>`, 결과 `states/state_default/state_fx/state_colliders`) 그것을 보인다. 아니면 **모든 키트**에 일반 처리(주 그룹):
  BURNT·WET·BLOODY·BROKEN = 색 곱(재질 복사본), WET·BLOODY = 발밑 데칼(물기·핏자국), MOVED = 조금 옮김(키트 `move`), FALLEN = 옆으로 눕힘. USED·EMPTY·SEALED·OPEN은 모양 그대로.
- 연출(state_fx): 불·연기·김·불티 입자(`scripts/region/state_fx.gd`)와 불빛(밤 조명 슬롯 — torch/lantern)이 상태와 같이 켜지고 꺼진다. 상태 충돌체(무너진 더미·열린 바닥 구멍·닫힌 문)도.
- 구현: `scripts/region/prop_states.gd`(상태 기계), 배치 로더가 `world.props.register()`로 등록.

### 상태 있는 소품 키트 `scenario/props` (params.kind, 첫 상태가 기본)
| kind | PROP | 상태 |
|---|---|---|
| agungi | HOME_001 아궁이·솥 | NORMAL / USED(불·김) / EMPTY(재) / BROKEN(솥 엎어짐) |
| bapsang | HOME_002 밥상 | NORMAL / USED / EMPTY / FALLEN |
| jangdok | HOME_003 장독 | NORMAL / OPEN / BROKEN |
| muldongi | HOME_004 물동이 | NORMAL / FALLEN(물 쏟음) / BROKEN |
| mun | HOME_007 문·빗장 | SEALED(막힘) / OPEN / BROKEN |
| deungjan | HOME_009 등잔 | NORMAL(꺼짐) / USED(켜짐·불빛) / FALLEN |
| hwaro | HOME_010 화로 | NORMAL(재) / USED(종이 태우는 불·연기) |
| jusang | TAV_001 주막 상 | NORMAL / USED / EMPTY |
| pyeongsang | TAV_002 평상 | NORMAL / BROKEN / MOVED |
| chaeksang | OFF_001 서안·문갑 | NORMAL / MOVED(종이 흩어짐) / OPEN(문갑 열림) |
| munseoham | OFF_001 문서함 | SEALED / OPEN(문서) / EMPTY / BURNT / MOVED(엎어짐) |
| jangbu | OFF_002 장부 더미 | NORMAL / MOVED(흩어짐·찢김) / BURNT / WET |
| meoktong | OFF_003 먹통·벼루 | NORMAL / FALLEN(먹물 쏟음) |
| chaekjang / chaekdeomi | OFF_006 책장·책더미 | NORMAL / EMPTY(빠진 칸) / FALLEN |
| chatjan | OFF_007 찻잔·다관 | NORMAL(식음) / USED(따뜻함·김) |
| kkeun | 묶은 끈(기둥) | NORMAL / BROKEN(끊김) |
| gamani | MKT_004 곡물가마니 | NORMAL / BROKEN(터짐) / BURNT |
| gireumtong | 기름통(S8013A) | NORMAL / MOVED(치움) / EMPTY(쓰러짐) |
| jipsin | ROAD_003 짚신 | NORMAL / USED / MOVED(한 짝 버려짐) |
| geumjul | RIT_002 금줄 | NORMAL / BROKEN |
| jemul | RIT_001 제물상 | NORMAL / EMPTY(사라진 제물) / BROKEN |
| byeokjido | 벽 지도 | NORMAL / BURNT / MOVED(찢겨 떨어짐) |
params `indoor: true`면 눈·젖음을 받지 않는다(배치 생성기가 마루 위 소품에 자동으로 붙임). 다른 장소에 놓을 때는 배치 항목 `{"kit":"scenario/props","params":{"kind":"bapsang"},"dy":마루높이,"state":"USED"}`.

## 2. 데칼 (PRP_COM_002·004·006·007·008)

```gdscript
world.decals.add({kind, x, z, ry, size, w, y?, wall?, color:"#rrggbb", alpha, group, hidden, dry}) -> id
world.decals.remove(id)
world.decals.trail(id, kind, points:[Vector2|[x,z]…], {step, size, spread, group, hidden, dry}) -> [id…]   # 좌우 번갈아 찍는 발자국 줄
world.decals.set_group_visible(group, on) / clear_group(group) / ids_in(group)
world.decals.dry(id_or_group, 초)     # 점점 옅어져 사라짐(젖은 발자국이 마름 — wet_foot은 기본 120초)
```
- kind: `foot`(짚신) `shoe`(가죽신) `paw`(범) `hoof`(말굽) `wet_foot` `flour_foot` `flour_paw` `blood` `drip` `claw` `flour`(밀가루 면) `scorch`(그을림) `ash` `puddle` `mud` `rut`(바퀴 자국) `drag`(끌린 자국) `snake`(뱀 지나간 자국) `ink`(먹물).
- 발자국 ry: 걷는 방향(0 = 북 −z). 벽·나무 데칼은 `wall: true, y`(ry = 벽 면이 보는 방향).
- 땅·실내 마루·다리 위 높이(`height_at`)를 따라 덮는다. 32m 칸마다 메시 하나(반투명 키트 재질 — 빛·안개·그늘을 받음).
- 데이터: `region_data/<권역|노정>/decals_*.json` `{items:[…], trails:[…]}` — F5 다시 읽기 때 같이. 아틀라스 `assets/kit/decals.png`(`tools/scenario/make_decal_atlas.py`).
- 미리 넣어 둔 데칼 그룹(모두 hidden — 사건이 켠다): 한양 `s1003_tracks`(책방 뒤창→뒷골목) `s8002_scorch`(칠패 창고 벽 그을림) `s8004_wet`(창고 벽 따라 젖은 발자국) `s8009_carts`(밤 수레 바퀴·말굽) · 평양 `s5004_tracks` · 북청길 `s6004_tracks`(길→역참) · 제주 `s7003_tracks`(굴 입구·안 뱀 자국·신발 자국).

## 3. 사건 날씨·시간 (weather.gd)

```gdscript
weather.force(kind, duration := -1.0, fade := 10.0, values := {}) -> bool  # duration 초 뒤 저절로 풀림(<0: release까지)
weather.release(fade := 10.0)
weather.is_forced()
weather.force_time(hour, duration := -1.0, fade := 0.0)   # fade 초에 걸쳐 그 시각으로(가까운 쪽으로 돈다)
weather.release_time() / weather.time_forced()
```
- kind: `clear cloudy rain fog snow wind` + 사건 전용 `storm`(폭풍우) `blizzard`(눈보라). values로 목표값 덮어쓰기 `{cloud, rain, snowfall, fogm, wind}`(0~1, fogm은 안개 배율).
- 점점 나빠지는 평양→함흥 길(R05): `force("cloudy",-1,30)` → `force("snow",-1,40)` → `force("blizzard",-1,60)` 처럼 노정 구간마다 다시 부르면 그 사이를 fade로 옮겨 간다. 사건 강제가 U 키·`--weather`보다 앞선다.
- 실내(interior)에서는 비·눈 입자를 그리지 않는다. 실내 바닥·가구는 눈·젖음을 받지 않는다(버텍스 알파 — materials.gd).

## 4. 장소·실내 (id · 키트 · 앵커)

실내는 `world.interior_by_id(id)`(`{minX…maxZ, floor_world, camera{pitch,distance}}`), 들어가면 앞벽·지붕을 숨기고 실내 카메라. 실내 id = 배치 id.

### 한양 GG_HANYANG (`placement_scenario.json`, 지명 덧붙임 `world_scenario.json`)
| id | 키트 | 자리 | 상태 그룹 | 앵커 |
|---|---|---|---|---|
| hy_sc_chaekbang | scenario/chaekbang | 피맛골 가게 줄 (−252, −938), 앞=피맛골, 뒤창=뒷골목(z −942.8) | window: SEALED/OPEN/BROKEN | door, inside, desk, shelf, counter, back_window, back_window_out |
| hy_sc_chaekbang_desk / _meoktong / _tea / _kkeun / _papers / _books / _lamp | props chaeksang/meoktong/chatjan/kkeun/jangbu/chaekdeomi/deungjan | 책방 안 | main | — |
| hy_sc_bin_changgo | changgo style empty | 책방 동쪽 옆 (−241.6, −938.6), 사이 3m 샛길 | main(불) | door, inside, bound |
| hy_sc_bin_changgo_kkeun | props kkeun | 묶였던 기둥·끈(S1005) | main | knot |
| hy_sc_chilpae_changgo_1..4 | changgo style chilpae | 칠패 장 동남쪽 (−749/−736/−723/−710, −222) 남향 | main: NORMAL/FIRE_1/FIRE_2/FIRE_3/BURNT · **2번만** hatch: SEALED/OPEN | door, inside, rubble, back_wall, (2번) hatch, pit |
| hy_sc_chilpae_oil_1·2 | props gireumtong | 2·3번 창고 앞 | main | grab |
| hy_sc_chilpae_gamani_1·2, _jangbu, _ham | props | 창고 앞·2번 창고 안 | main | — |
| hy_sc_seogang_changgo | changgo style seogang(낡음) | 서강 강기슭 (−2268, 758) | main(불) · hatch(숨은 바닥: 유해 일부·수량 기록 조각·박규상 표식) · groove(수량패 홈: NORMAL 빈 홈 / USED 나무패 끼움) | door, inside, hatch, pit, groove, rubble |
| hy_sc_seogang_teo | changgo chilpae, state BURNT(cold) | 바로 남쪽 — 12년 전 불탄 창고 터 | main | rubble |
| hy_sc_seogang_seonchang, _bridge, _gamani | route/seonchang · village/seop_bridge · props | 한강 선창 · 무명 내(r011) 섶다리 | — | — |
- 서강: 권역에 서강이 없어 마포(−2030, 940) 서쪽 290m, 한강과 무명 내 사이 강기슭에 압축해 넣음(실제는 마포 서쪽 2~3km — 가설·게임용). 지명 `seogang`(서강), 오솔길 `sc_seogang_path`(마포→섶다리→창고).
- 최종장 숨은 바닥은 서강 옛 창고(12년 전 불 자리)와 칠패 2번 창고 둘 다에 있다 — 이야기가 고른다. 무너진 뒤(FIRE_3·BURNT)에도 마루 오른쪽 반과 숨은 바닥은 남아 들어갈 수 있다(왼쪽 반은 잔해 더미 — 충돌).

### 평양 PA_PYEONGYANG — 평안감영 뒤 기록 창고(S5004)
| id | 키트 | 자리 | 상태 그룹 | 앵커 |
|---|---|---|---|---|
| py_sc_girokgo | scenario/girokgo | 감영(26, −76) 뒤뜰 (14, −147) | door: SEALED/OPEN/BROKEN · window(뒤 살창): SEALED/OPEN/BROKEN | door, inside, chest_spot, desk, rack, back_window, back_window_out |
| py_sc_girokgo_ham_1·2, _jangbu, _meoktong, _shelf | props munseoham/jangbu/meoktong/chaekjang | 안 | main | — |

### 함흥→북청 노정 HG_HAMHEUNG-BUKCHEONG — 함관령 옛 역참(S6004~S6010)
- 자리: 함관령 서낭(−269) 동쪽 숲, 길(−203, −18)에서 북쪽 45m 오솔길(`sc_yeokcham_path`) 끝 (−202, −62). 북청 쪽으로 가는 길 위 산중이라 여기로 정함. 지명 `rt_hamgwal_yeokcham`.
| id | 키트 | 상태 그룹 | 앵커 |
|---|---|---|---|
| rt_sc_yeokcham | scenario/yeokcham(초가 다섯 칸 객사 + 무너진 마구간·말뚝·쓰러진 표목) | door(서쪽 방문): OPEN/SEALED | room, wall_map, hearth, stable, post, approach, door, inside |
| rt_sc_yeokcham_lamp / _map / _hwaro / _burnt / _ham / _jipsin | props deungjan / byeokjido / hwaro / jangbu(BURNT) / munseoham(OPEN) / jipsin | main | — |
- S6005 '불빛·한 노인이 종이를 태움' = `lamp:USED`, `hwaro:USED`. 눈길은 `weather.force("blizzard")`, 발자국 `s6004_tracks`.

### 제주 JJ_JEJU — 김녕사굴 입구 + 굴 안(S7003~S7006)
- **2026-10-04 바뀜(story-jeju)**: 굴 안은 이제 실내 공간 `region_data/interiors/jj_sagul/interior.json`(terrain-engine.md "실내 공간")이다. 권역의 `jj_sagul_sagul_01`은 예전 입구 키트 `landmark/jj_gimnyeongsagul`로 되돌렸고, 금줄·입구 밖 발자국만 권역에 남는다. 제물상·짚신·굴 안 발자국은 실내 공간 데이터로 옮겼다. 아래 표는 옮기기 전 기록이다.
- (옛) 기존 `placement_hub.json` 항목 `jj_sagul_sagul_01`의 키트를 `scenario/jj_sagul`로 바꿈(입구 얼굴 자리는 그대로, 원점은 굴 가운데로 20m 북쪽 (3432.4, −915.7), 길이 40m, 터 고르기).
| id | 키트 | 상태 그룹 | 앵커 |
|---|---|---|---|
| jj_sagul_sagul_01 | scenario/jj_sagul(입구·굽이치는 용암굴, 실내에선 굴 지붕·입구 바위를 숨김) | shed(뱀 허물): NORMAL/EMPTY | mouth, outside, rope, stele, altar(옛 제단 돌), niche(아이가 숨는 옆 굴), dig(도굴 흔적), deep_wall(잔영이 지나는 벽), deep, shed |
| jj_sc_sagul_geumjul / _jemul / _jipsin | props geumjul(입구) / jemul(제단 앞) / jipsin | main | — |
- S7003 '부서진 금줄·사라진 제물' = `geumjul:BROKEN`, `jemul:EMPTY`, 데칼 `s7003_tracks`.

### 황주→장산곶 노정 HH_HWANGJU-JANGSANGOT — 곶 앞 바위섬·암초(S4006)
| id | 키트 | 자리·앵커 |
|---|---|---|
| rt_sc_jangsan_islet | scenario/hj_islet | (505, −205) 북쪽 바다. 서남쪽 바위기둥 뒤 자갈 갯가 + 바위 밑 틈(실내: 처마 바위 숨김). 앵커 landing, cove, shelter(실종자 자리), lookout |
| rt_sc_jangsan_reef_0..6 | scenario/hj_reef | 섬 둘레 암초 |
| rt_sc_jangsan_seonchang | route/seonchang | 만 안쪽 서쪽 물가 선창 (360, −74), 오솔길 `sc_jangsan_pier_path`로 큰길과 이어짐 |
- 뱃길 `rt_jangsan_islet_lane`(world_scenario.json `river_lanes`, 197m): 선창에서 배(나룻배)에 오르면 암초 사이로 저절로 섬 갯가까지(river_lanes auto). 섬에서 다시 오르면 돌아온다. 지명 `rt_jangsan_islet`.
- 걷기 면은 갯가·틈에만(그 밖은 바다라 막힘). 시간·날씨 난이도는 이야기 쪽(예: `weather.force("storm")`).

## 5. 엔진에 더한 것(다른 에이전트 참고)
- `world_scenario.json`(권역·노정 폴더, 선택): 파이프라인 파일을 건드리지 않고 `settlements landmarks sights roads crossings river_lanes`를 덧붙인다(같은 id면 덮어씀).
- `RegionWorld.add_static()`이 항목(Dictionary)을 돌려준다. 같은 키트를 두 번째부터 instantiate로 놓을 때 interior.hide가 첫 노드를 가리키던 문제 고침. 실내에 `id`(배치 id).
- 배치 항목 `state`·`states`·`dy`(지형 위로 더 올림 — 마루 위 소품). `kit/scenario/catalog`도 읽는 칸 목록에 넣음.
- `materials.gd` WEATHER_CODE: 버텍스 색 알파 = 날씨 받는 정도(기본 1, 기존 모델 변화 없음).

## 6. 측정 (2048×1536, `--bench`, M1)
| 공간·자리 | avg fps | 불러오기 |
|---|---|---|
| 한양 칠패 창고 | 121 | ready 8.7s |
| 한양 피맛골 책방 | 135 | ready 10.2s |
| 한양 서강 | 108 | ready 7.2s |
| 평양 기록 창고 | 110 | ready 6.3s |
| 제주 김녕사굴 | 111 | ready 6.8s |
| 북청길 역참 | 147 | ready 2.4s |
| 장산곶 노정 | 115 | ready 2.3s |
창고 셋을 FIRE_1·2·3으로 켠 밤에도 수직 동기 60 유지(입자 + 불빛 슬롯).

## 7. 남은 것·가설
- 책쾌 가게·감영 문서고·산중 역참의 실제 평면은 근거 없이 게임용(가설). 서강 위치는 압축.
- ~~굴 안은 지붕을 숨기면 햇빛이 그대로 든다~~ → 실내 공간 + 어둠(dark)·등불로 고침(story-jeju).
- 불꽃 혀는 빛나는 원뿔(정지) + 움직이는 입자. 데칼 발자국은 도성 카메라 거리(30m)에서 작게 보인다 — 단서로 쓸 땐 카메라를 당기거나 크기 0.45 이상 권장.
