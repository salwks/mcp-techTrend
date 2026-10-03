"""대표 도시 3곳(경주·강릉·제주목) 고을 성격표 — 계약서 §9 profile + 문화권(culture) 키.

배치 생성기(tools/placement/hubs.py)가 읽고, `python3 tools/placement/hubs.py <id> --profiles`가 region.json
settlements[].profile에 합쳐 쓴다(data-east가 넣은 기본값 위에 덮어씀).

추가 키(계약서 §9 밖, 배치 전용):
- culture: yeongnam | gwandong | tamna — kit/culture/<culture>/ 가옥형을 고른다(kit-culture 보고서 §6 요청 1).
- houses: 이 고을에서 쓰는 집 키트(설명용 — 생성기는 culture + roof로 고른다).
roof 키(계약서): giwa·choga·choga_low·neowa·gulpi·guitul·jeju_stone. 문화권마다 실제 키트는 hubs.py CULTURE_HOUSE 표.
"""

# ── 경주(영남, 남부) ──────────────────────────────────────────────
_YN = dict(culture="yeongnam", climate="south")
GS_GYEONGJU = {
    "gyeongju_eup": dict(_YN, archetype="eupchi", roof={"giwa": 0.55, "choga": 0.45}, wall="todam", layout="walled_grid",
                         entrance="gate", people=["관속", "양반", "유생", "장꾼"], animals=["소"],
                         signature="방형 석성 4문 안 ㅁ자 기와 뜰집 골목, 성 밖 들판에 봉분(고분)이 솟은 옛 도읍",
                         trades=["관아", "장시", "향교"],
                         houses=["culture/yeongnam/compound(large=종가)", "culture/yeongnam/tteuljip(giwa)", "culture/yeongnam/choga"],
                         notes="경주부(부윤 종2품) 읍치. 성 안 T자 가로: 객사 동경관이 남북 축 끝, 관아는 객사 서쪽 곁(가설). 성 안은 이속·향리 기와 뜰집 위주"),
    "gyeongju_jang": dict(_YN, archetype="eupchi", roof={"choga": 0.8, "giwa": 0.2}, wall="todam", layout="linear_street",
                          entrance="tumulus_market", people=["장꾼", "보부상", "주모"], animals=["소"],
                          signature="봉황대 고분 그늘 아래 장 — 정만서가 장꾼을 놀리는 곳", trades=["장시", "주막"],
                          notes="서문 밖 영천길 가 장(가설: 1870년 경주 읍내장은 서문 밖 봉황대 둘레)"),
    "gyochon": dict(_YN, archetype="plain", roof={"giwa": 0.7, "choga": 0.3}, wall="todam", layout="round_cluster",
                    entrance="hyanggyo_hongsal", people=["양반", "유생", "농부"], animals=["소"],
                    signature="향교 옆 큰 ㅁ자 종가(최부잣집 곳간)와 계림 숲", trades=["논농사", "향교"],
                    houses=["culture/yeongnam/jongga", "culture/yeongnam/compound"]),
    "bulguksa_village": dict(_YN, archetype="temple", roof={"choga": 0.85, "giwa": 0.15}, wall="todam", layout="along_temple_road",
                             entrance="stone_jangseung", people=["스님", "보살", "농부"], animals=[],
                             signature="석축 절 아래 석장승과 공양 떡집", trades=["논농사", "절 시주"]),
    "bulguksa_temple": dict(_YN, archetype="temple", roof={"giwa": 1.0}, wall="todam", layout="along_temple_road",
                            entrance="stone_jangseung", people=["스님"], animals=[],
                            signature="청운교·백운교 석축 위 다보탑 — 회랑은 초석만 남은 퇴락한 절", trades=["절"]),
    "chisul_village": dict(_YN, archetype="mountain", roof={"choga": 0.8, "neowa": 0.2}, wall="stone_terrace", layout="terraced",
                           entrance="sotdae_toward_pass", people=["농부", "숯쟁이", "약초꾼"], animals=["개"],
                           signature="고개 쪽을 바라보는 솟대와 은을암(새바위) 이야기", trades=["밭농사", "숯", "약초"]),
    "daebon": dict(culture="yeongnam", climate="coast", archetype="coast", roof={"choga_low": 1.0}, wall="stone_net",
                   layout="linear_shore", entrance="wharf", people=["어부", "해녀", "무당"], animals=["갈매기"],
                   signature="대왕암을 향한 이견대 터와 몽돌 해변 갯마을", trades=["고기잡이", "미역"]),
    "gampo": dict(culture="yeongnam", climate="coast", archetype="coast", roof={"choga_low": 0.85, "choga": 0.15}, wall="stone_net",
                  layout="linear_shore", entrance="wharf", people=["어부", "객주", "해녀"], animals=["갈매기"],
                  signature="배 끌어올린 포구와 객주 창고, 미역 말리는 돌담", trades=["고기잡이", "미역", "객주"],
                  notes="포구(§26): 객주·창고·상인이 나루보다 많다"),
    "jangang": dict(_YN, archetype="pass", roof={"choga": 1.0}, wall="none", layout="few_roadside",
                    entrance="seonghwang_cairn", people=["나그네", "주모"], animals=[],
                    signature="추령 넘은 골짜기 주막과 성황 돌무더기", trades=["주막"]),
}
_AUTO_YN = dict(_YN, archetype="plain", roof={"choga": 0.85, "giwa": 0.15}, wall="todam", layout="rows",
                entrance="zelkova_square", people=["농부"], animals=["소"], signature="논 가운데 고분 곁 초가 들마을", trades=["논농사"])

# ── 강릉(관동, 중부 + 해안·고산) ─────────────────────────────────
_GD = dict(culture="gwandong", climate="central")
GW_GANGNEUNG = {
    "gangneung_eup": dict(_GD, archetype="eupchi", roof={"giwa": 0.4, "choga": 0.6}, wall="todam", layout="linear_street",
                          entrance="hongsalmun", people=["관속", "양반", "장꾼", "무당"], animals=["소"],
                          signature="임영관 삼문과 칠사당 — 성벽 없이 객사·관아 둘레로 길 따라 늘어선 반가 기와집과 잿빛 초가",
                          trades=["관아", "장시", "단오제"],
                          houses=["culture/gwandong/banga", "culture/gwandong/compound(large)", "culture/gwandong/haean"],
                          notes="강릉대도호부 읍치. 성벽은 1870년 무렵 흔적만이라 보고(가설) 길촌형으로"),
    "gangneung_jang": dict(_GD, archetype="river", roof={"choga": 0.9, "giwa": 0.1}, wall="todam", layout="fan_from_ferry",
                           entrance="ferry", people=["장꾼", "보부상", "뱃사공", "무당"], animals=["소"],
                           signature="남대천 둑 아래 단오 난장 — 굿당 차일과 좌판", trades=["장시", "단오제"]),
    "gyeongpo_village": dict(culture="gwandong", climate="coast", archetype="plain", roof={"giwa": 0.5, "choga": 0.5}, wall="todam",
                             layout="rows", entrance="pavilion_pine", people=["양반", "농부", "어부"], animals=["소"],
                             signature="경포호 가 반가(선교장·오죽헌)와 솔숲 정자", trades=["논농사", "고기잡이(호수)"]),
    "anmok_village": dict(culture="gwandong", climate="coast", archetype="coast", roof={"choga_low": 1.0}, wall="stone_net",
                          layout="linear_shore", entrance="wharf", people=["어부", "해녀", "무당"], animals=["갈매기"],
                          signature="남대천 하구 모래톱 갯마을 — 그물 이엉 지붕과 헌화 벼랑", trades=["고기잡이", "소금"]),
    "haksan": dict(_GD, archetype="plain", roof={"choga": 0.9, "giwa": 0.1}, wall="fence", layout="round_cluster",
                   entrance="dangganjiju", people=["농부"], animals=["소"],
                   signature="들 가운데 굴산사 터 당간지주와 석천 우물(범일국사 탄생)", trades=["논농사"]),
    "gusan_yeok": dict(_GD, archetype="pass", roof={"choga": 0.6, "neowa": 0.4}, wall="stone", layout="few_roadside",
                       entrance="mabang_station_flag", people=["역졸", "나그네", "주모", "보부상"], animals=["말"],
                       signature="대관령 넘기 전 역마 마방과 주막 — 호랑이 조심 방", trades=["역참", "주막"]),
    "banjeong_jumak": dict(culture="gwandong", climate="alpine", archetype="pass", roof={"neowa": 1.0}, wall="none", layout="few_roadside",
                           entrance="seonghwang_cairn", people=["나그네", "주모"], animals=[],
                           signature="안개 낀 고개 중턱 너와 주막과 돌무더기", trades=["주막"]),
    "daegwallyeong_seonghwang": dict(culture="gwandong", climate="alpine", archetype="pass", roof={"neowa": 1.0}, wall="none",
                                     layout="few_roadside", entrance="seonghwang_cairn", people=["나그네", "무당"], animals=[],
                                     signature="구름 위 고개 마루 성황 돌무더기 — 동해가 내려다보임", trades=[]),
}
_AUTO_GD = dict(_GD, archetype="plain", roof={"choga": 0.9, "giwa": 0.1}, wall="fence", layout="rows",
                entrance="zelkova_square", people=["농부"], animals=["소"], signature="잿빛 이엉 그물 지붕 들마을", trades=["논농사"])
_AUTO_GD_MT = dict(_GD, archetype="mountain", roof={"neowa": 0.6, "guitul": 0.4}, wall="stone_terrace", layout="terraced",
                   entrance="watermill_bridge", people=["화전민", "숯쟁이"], animals=["개"], signature="비탈 너와·귀틀집 산촌", trades=["화전", "숯"])

# ── 제주목(탐라, 해안섬) ─────────────────────────────────────────
_TN = dict(culture="tamna", climate="coast")
JJ_JEJU = {
    "jeju_mok": dict(_TN, archetype="eupchi", roof={"jeju_stone": 0.93, "giwa": 0.07}, wall="basalt", layout="walled_grid",
                     entrance="dolhareubang", people=["관속", "양반", "장꾼", "해녀", "목자"], animals=["말"],
                     signature="검은 현무암 성벽과 성문 돌하르방, 관덕정 앞 광장, 올레로 드나드는 낮은 돌집",
                     trades=["관아", "장시"], houses=["culture/tamna/compound", "culture/chae(roof giwa, wall basalt)"],
                     notes="탐라 읍치: 기와는 관아·객사와 몇몇 관속 집만, 민가는 바람 막는 낮은 띠지붕 돌집. 논 없음"),
    "jeju_jang": dict(_TN, archetype="eupchi", roof={"jeju_stone": 0.95, "giwa": 0.05}, wall="basalt", layout="linear_street",
                      entrance="dolhareubang", people=["장꾼", "해녀", "목자"], animals=["말"],
                      signature="동문 안 산지천 물가 장 — 말총·미역·귤 좌판", trades=["장시"]),
    "sanji_po": dict(_TN, archetype="coast", roof={"jeju_stone": 1.0}, wall="basalt", layout="linear_shore",
                     entrance="wharf", people=["뱃사공", "객주", "해녀"], animals=["갈매기"],
                     signature="산지천 하구 배 대는 포구와 산지물 빨래터", trades=["포구", "고기잡이"]),
    "hwabuk_po": dict(_TN, archetype="coast", roof={"jeju_stone": 1.0}, wall="basalt", layout="linear_shore",
                      entrance="wharf", people=["뱃사공", "객주", "진졸", "해녀"], animals=["말", "갈매기"],
                      signature="뱃길 관문 — 해신사와 화북진 돌 성, 말 실어 내는 포구", trades=["포구", "객주", "말 수출"]),
    "jocheon": dict(_TN, archetype="island", roof={"jeju_stone": 1.0}, wall="basalt", layout="olle_alleys",
                    entrance="yongcheon_spring", people=["해녀", "뱃사공", "나그네"], animals=["말", "갈매기"],
                    signature="조천진 돌 성 위 연북정과 용천수 물통 — 고종달이 끊지 못한 물", trades=["포구", "물질(해녀)", "밭농사"]),
    "songdang": dict(_TN, archetype="island", roof={"jeju_stone": 1.0}, wall="basalt", layout="olle_alleys",
                     entrance="sindang_tree", people=["심방", "목자", "농부"], animals=["말", "소"],
                     signature="오름에 둘러싸인 목장 마을 — 당오름 팽나무 신당과 굿 소리", trades=["목축", "밭농사", "굿"],
                     notes="바다에서 멀어 해녀 없음"),
    "gimnyeong": dict(_TN, archetype="island", roof={"jeju_stone": 1.0}, wall="basalt", layout="olle_alleys",
                      entrance="bangsatap", people=["해녀", "어부"], animals=["말", "갈매기"],
                      signature="흰 모래 해변과 검은 돌담 밭 — 해녀 불턱과 뱀굴 이야기", trades=["물질(해녀)", "고기잡이", "밭농사"]),
}
_AUTO_TN = dict(_TN, archetype="island", roof={"jeju_stone": 1.0}, wall="basalt", layout="olle_alleys",
                entrance="yongcheon_spring", people=["해녀", "농부"], animals=["말"],
                signature="검은 현무암 돌담 올레와 용천수 물통, 해녀 불턱", trades=["물질(해녀)", "밭농사"])

PROFILES = {"GS_GYEONGJU": GS_GYEONGJU, "GW_GANGNEUNG": GW_GANGNEUNG, "JJ_JEJU": JJ_JEJU}
AUTO = {"GS_GYEONGJU": _AUTO_YN, "GW_GANGNEUNG": _AUTO_GD, "JJ_JEJU": _AUTO_TN}

# 지명 표시(scripts/region/place_title.gd TITLES와 같게)
TITLES = {
    "GS_GYEONGJU": {"gyeongju_eup": "경주", "gyeongju_jang": "경주", "gyochon": "교촌", "bulguksa_village": "진현",
                    "bulguksa_temple": "불국사", "chisul_village": "치술령", "daebon": "대본", "gampo": "감포", "jangang": "장항"},
    "GW_GANGNEUNG": {"gangneung_eup": "강릉", "gangneung_jang": "강릉", "gyeongpo_village": "경포", "anmok_village": "안목",
                     "haksan": "학산", "gusan_yeok": "구산역", "banjeong_jumak": "반정", "daegwallyeong_seonghwang": "대관령"},
    "JJ_JEJU": {"jeju_mok": "제주목", "jeju_jang": "제주목", "sanji_po": "산지포", "hwabuk_po": "화북포", "jocheon": "조천",
                "songdang": "송당", "gimnyeong": "김녕"},
}


def profile_for(rid, s, mountain=False):
    p = PROFILES[rid].get(s["id"])
    if p:
        return dict(p)
    if rid == "GW_GANGNEUNG" and mountain:
        return dict(_AUTO_GD_MT)
    old = s.get("profile") or {}
    if old.get("archetype") == "mountain":
        base = dict(AUTO[rid], archetype="mountain", wall="stone_terrace", layout="terraced",
                    roof=({"neowa": 0.6, "guitul": 0.4} if rid == "GW_GANGNEUNG" else {"choga": 0.8, "neowa": 0.2}) if rid != "JJ_JEJU" else {"jeju_stone": 1.0})
        return base
    return dict(AUTO[rid])
