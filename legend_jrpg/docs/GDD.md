# 빛의 계승자 — 게임 기획서 (GDD)

고전 JRPG(영웅전설 초기작 스타일)를 지향하는 웹 브라우저용 턴제 RPG.
플레이 시간 목표: 60~90분. 최종 레벨 목표: 20~22.

## 1. 스토리 개요

소년 **렌**은 변방의 **루멘 마을**에서 자란 평범한 16살 소년이다.
붉은 달이 뜬 밤, 봉인되어 있던 **마왕 자르가스**의 부활과 함께 마물이 마을을 습격한다.
소꿉친구와 마을 사람을 지키려다 마을 사당에 잠들어 있던 **봉인된 성검**을 뽑아 들게 되고,
성검이 렌에게 반응하며 그는 전설 속 "빛의 계승자"(용사)로 선택된다.

장로는 성검의 봉인을 완전히 풀려면 **별빛의 탑**에 가야 한다고 알려주고, 렌은 여정을 떠난다.

### 챕터 구성

| 챕터 | 장소(맵 ID) | 사건 | 파티 합류 | 보스(troop ID) | 권장 Lv |
|---|---|---|---|---|---|
| 프롤로그 | 루멘 마을 `village`, 사당 `shrine` | 마물 습격, 성검을 뽑음(용사 각성) | 렌 | `troop_tutorial`, `boss_goblin_chief` | 1~2 |
| 1장 | 속삭임의 숲 `forest` | 늑대에게 둘러싸인 견습 사제 미아 구출. 미아는 "빛의 용사"의 꿈을 꾸어 왔다 | **미아** (Lv3) | `troop_mia_rescue`(렌 단독), `boss_treant` | 2~5 |
| 2장 | 항구도시 벨포트 `port`, 해안 동굴 `cave` | 바다 괴물 때문에 항구가 봉쇄됨. 누명을 쓰고 기사단에서 쫓겨난 기사 가렌이 홀로 괴물을 쫓고 있다. 함께 동굴로 가며 합류. 보스 격파 후 대장장이가 성검을 1차 해방(`awakened_sword`) | **가렌** (Lv7) | `boss_sea_serpent` | 5~9 |
| 3장 | 별빛의 탑 `tower` | 스승을 마왕군 리치에게 잃은 마법사 셀라가 복수를 위해 탑을 오르고 있다. 탑 정상에서 리치를 쓰러뜨리고 셀라 합류. 탑의 제단에서 성검 완전 해방(`holy_sword`) | **셀라** (Lv11) | `boss_lich` | 9~13 |
| 4장 | 잿빛 황야 `wasteland` | 마왕성으로 가는 길을 흑룡이 막고 있다 | – | `boss_black_dragon` | 12~16 |
| 종장 | 마왕성 `castle`, 옥좌 `throne` | 마장군 보르그, 마왕 자르가스(2단계 변신) 격파 → 엔딩 | – | `boss_general_vorg`, `boss_demon_king` → `boss_demon_king_true` | 16~22 |

엔딩: 마왕이 쓰러지고 붉은 달이 사라진다. 동료들은 각자의 길(미아: 신전, 가렌: 기사단 복귀,
셀라: 스승의 탑을 잇는다)로 떠나고, 렌은 루멘 마을로 돌아온다. 크레딧.

## 2. 캐릭터

| ID | 이름 | 역할 | 특징 |
|---|---|---|---|
| `ren` | 렌 | 용사 | 밸런스형. 성검 무기는 이야기 진행으로만 강화됨(상점 구매 불가) |
| `mia` | 미아 | 사제 | 회복/부활/보조. 밝고 다정하지만 겁이 많음 |
| `garen` | 가렌 | 기사 | 높은 HP/방어, 도발로 아군 보호. 과묵하고 책임감이 강함 |
| `sela` | 셀라 | 마법사 | 속성 공격 마법 전문. 새침하지만 속정이 깊음 |

악역: 마왕 **자르가스**, 마장군 **보르그**, 리치(셀라의 원수) **네크로스**.
주요 NPC: 장로 **오웬**(루멘 마을), 소꿉친구 **리나**(루멘 마을), 대장장이 **도르만**(벨포트).

## 3. 고정 ID 목록 (모든 에이전트 공통 — 임의로 바꾸지 말 것)

### 스킬 (`src/data/skills.js`) — 습득 레벨
- ren: `power_slash`(2), `holy_blade`(7), `brave_cry`(12), `star_blade`(18)
- mia: `heal`(1), `cure`(1), `protect`(5), `heal_all`(8), `revive`(11), `holy_light`(14), `full_heal`(18)
- garen: `shield_bash`(7), `provoke`(9), `iron_wall`(12), `earth_splitter`(16)
- sela: `flame`(11), `frost`(11), `spark`(11), `blaze`(14), `blizzard`(16), `thunderstorm`(18), `meteor`(22)

### 아이템 (`src/data/items.js`)
- 소비: `herb`, `potion`, `hi_potion`, `elixir`, `ether`, `hi_ether`, `antidote`, `panacea`, `phoenix_feather`, `fire_bomb`
- 무기 — ren: `sealed_sword`, `awakened_sword`, `holy_sword` (이벤트 전용, 가격 0)
- 무기 — mia: `oak_staff`, `silver_staff`, `saint_staff`
- 무기 — garen: `iron_spear`, `steel_spear`, `dragon_spear`
- 무기 — sela: `magic_rod`, `star_rod`, `archmage_rod`
- 방어구: `travel_clothes`(전원), `leather_armor`, `chain_mail`, `silver_mail`, `mithril_mail`(ren·garen), `cloth_robe`, `silk_robe`, `sage_robe`(mia·sela, ren도 착용 가능)
- 장신구: `power_ring`, `guard_ring`, `speed_boots`, `magic_earring`, `angel_charm`

### 상점 판매 가능 시점(가이드)
- 루멘 마을: herb, antidote, leather_armor, cloth_robe, oak_staff
- 벨포트: herb, potion, ether, antidote, phoenix_feather, chain_mail, silk_robe, silver_staff, steel_spear, star_rod, power_ring, guard_ring
- 별빛의 탑 1층 상인 / 황야 캠프 상인: hi_potion, hi_ether, panacea, phoenix_feather, fire_bomb, silver_mail, sage_robe, speed_boots, magic_earring
- 마왕성 입구 상인(선택): elixir, mithril_mail, saint_staff, dragon_spear, archmage_rod, angel_charm

### 맵 ID와 인카운터 테이블
| 맵 ID | 이름 | 인카운터 테이블 키 | 전투 배경 키 | BGM 키 |
|---|---|---|---|---|
| `village` | 루멘 마을 | – | `village` | `village` |
| `shrine` | 루멘 사당 | – | `shrine` | `sad` / `dungeon` |
| `forest` | 속삭임의 숲 | `forest` | `forest` | `forest` |
| `port` | 항구도시 벨포트 | – | `plains` | `town` |
| `cave` | 해안 동굴 | `cave` | `cave` | `dungeon` |
| `tower` | 별빛의 탑 | `tower` | `tower` | `tower` |
| `wasteland` | 잿빛 황야 | `wasteland` | `wasteland` | `field` |
| `castle` | 마왕성 | `castle` | `castle` | `castle` |
| `throne` | 마왕의 옥좌 | – | `throne` | `final_boss` |

시나리오 담당은 연결용 맵(예: `plains` 들판, 건물 내부 `village_inn` 등)을 추가해도 된다.
추가 맵의 인카운터는 위 테이블 키 중 하나를 재사용한다(`plains` 테이블도 전투 담당이 제공).

## 4. 게임 규칙 요약
- 파티 최대 4명, 합류 후 이탈 없음. 전멸 시 게임오버 → 마지막 세이브 또는 타이틀.
- 전투: 정면 시점(드래곤퀘스트/초기 영웅전설 스타일), 속도(spd) 순 턴제.
  명령: 공격 / 스킬 / 아이템 / 방어 / 도주(보스전 불가).
- 상태이상: `poison`(독, 턴마다 피해), `sleep`(수면, 행동불가, 피격 시 해제), `stun`(기절 1턴).
- 속성: `fire`, `ice`, `thunder`, `holy`. 적은 약점(weak)/내성(resist)을 가진다.
- 경험치: 레벨 L에 도달하는 누적 경험치 = `10*(L-1)^2 + 10*(L-1)` (state.js의 `expForLevel`). 최대 Lv 30.
- 세이브: 필드 메뉴에서 언제든(3슬롯, localStorage).
