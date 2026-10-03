"""북쪽 대표 도시 4곳(한양·황주·평양·함흥) 고을 성격표 — 계약서 §9 profile + 문화권(culture) 키.

배치 생성기(tools/placement/north.py)가 읽고, `python3 tools/placement/north.py <id> --profiles`가 region.json
settlements[].profile에 합쳐 쓴다(terrain-data-north가 넣은 기본값 위에 덮어씀).

추가 키(계약서 §9 밖, 배치 전용):
- culture: giho | haeseo | gwanseo | gwanbuk — kit/culture/<culture>/ 가옥형을 고른다.
- district: 한양 구역(capital 유형) — palace·jongno·bukchon·jungchon·namchon·outer_south·river.
- houses: 이 고을에서 쓰는 집 키트(설명용).
고증은 참고용(1870 전후). 근거·가설: docs/reports/placement-north.md
"""

# ── 한양(기호, 중부, 도읍 특수 유형) ─────────────────────────────
_GH = dict(culture="giho", climate="central")
_CAP = dict(_GH, archetype="capital")
GG_HANYANG = {
    "hanyang_doseong_in": dict(_CAP, district="all", roof={"giwa": 0.6, "choga": 0.4}, wall="todam", layout="walled_grid",
                               entrance="great_gate", people=["관원", "양반", "중인", "시전 상인", "포교", "가마꾼"], animals=["말"],
                               signature="네 산 능선을 잇는 도성 안 — 궁궐 앞 큰길과 종로 시전 행랑, 골목마다 붙어 선 ㄷ·ㅁ자 기와집",
                               trades=["관아", "시전", "장인"],
                               houses=["culture/giho/compound(city=도시 한옥)", "culture/giho/compound(large)", "culture/giho/compound(medium)"],
                               notes="도읍(GG-01). 특정 전래동화는 붙이지 않고 소문·야담·귀신 이야기만 떠돈다(명세 §21)"),
    "bukchon": dict(_CAP, district="bukchon", roof={"giwa": 0.85, "choga": 0.15}, wall="todam", wall_detail="city_wall", layout="terraced",
                    entrance="alley_steps", people=["양반", "청지기", "몸종"], animals=[],
                    signature="경복궁·창덕궁 사이 비탈의 반가 기와 골목 — 담 너머로 처마가 겹친다",
                    trades=["벼슬", "서화"], houses=["culture/giho/compound(city ㅁ)", "culture/giho/compound(large)"],
                    notes="북촌: 고관·왕족 반가(가설: 필지 좁힘)"),
    "ungjongga": dict(_CAP, district="jongno", roof={"giwa": 0.9, "choga": 0.1}, wall="todam", wall_detail="city_wall", layout="linear_street",
                      entrance="bell_pavilion", people=["시전 상인", "보부상", "거간", "포교"], animals=["말", "소"],
                      signature="종루(보신각) 네거리에서 동대문까지 이어진 시전 행랑 — 육의전 차양과 피맛골",
                      trades=["시전", "육의전"], houses=["landmark/hy_sijeon", "culture/giho/compound(city)"],
                      notes="운종가(종로). 행랑 뒤 피맛골 골목에 주막·도시 한옥"),
    "jungchon": dict(_CAP, district="jungchon", roof={"giwa": 0.5, "choga": 0.5}, wall="todam", layout="linear_street",
                     entrance="stone_bridge", people=["중인", "역관", "의원", "빨래하는 아낙"], animals=[],
                     signature="개천(청계천) 돌 축대와 광통교·수표교 — 다리 밑 빨래터와 중인 기와집 줄",
                     trades=["역관", "의원", "장인"], houses=["culture/giho/compound(city ㄷ)", "culture/giho/compound(medium)"],
                     notes="중촌: 개천 가 중인 마을(가설)"),
    "namchon": dict(_CAP, district="namchon", roof={"giwa": 0.4, "choga": 0.6}, wall="todam", layout="terraced",
                    entrance="pine_slope", people=["가난한 선비", "남산골 딸깍발이"], animals=["개"],
                    signature="남산 기슭 비탈의 낡은 초가·작은 기와집 — 남산골 샌님",
                    trades=["글공부", "삯바느질"], houses=["culture/giho/compound(small)", "culture/giho/compound(medium)"],
                    notes="남촌: 벼슬 없는 선비 동네(남산골 딸깍발이 이야기 — 전승 표현)"),
    "baeogae_jang": dict(_CAP, district="jongno", roof={"choga": 0.7, "giwa": 0.3}, wall="todam", layout="round_cluster",
                         entrance="market_flag", people=["난전 상인", "채소 장수", "장꾼"], animals=["소"],
                         signature="배오개(이현) 난전 — 왕십리 채소가 들어오는 새벽장",
                         trades=["난전", "채소"], notes="시전 밖 사상(私商) 장(가설: 18세기 이후 성행)"),
    "chilpae_jang": dict(_GH, archetype="capital", district="outer_south", roof={"choga": 0.8, "giwa": 0.2}, wall="todam",
                         layout="round_cluster", entrance="market_flag", people=["어물 장수", "난전 상인", "짐꾼"], animals=["소", "말"],
                         signature="숭례문 밖 칠패 어물전 — 마포에서 올라온 생선 좌판", trades=["난전", "어물"]),
    "wangsimni": dict(_GH, archetype="plain", roof={"choga": 0.9, "giwa": 0.1}, wall="fence", layout="rows",
                      entrance="zelkova_square", people=["채소 농부"], animals=["소"],
                      signature="동대문 밖 채마밭 — 배추·무를 지게에 지고 도성으로", trades=["채소 농사"]),
    "mapo": dict(_GH, archetype="river", roof={"choga": 0.7, "giwa": 0.3}, wall="todam", layout="fan_from_ferry",
                 entrance="wharf", people=["객주", "선주", "짐꾼", "소금 장수", "젓갈 장수"], animals=["말", "소"],
                 signature="삼개 포구 — 객주 창고 줄과 소금·젓갈·땔나무 배", trades=["객주", "소금", "젓갈", "땔나무"],
                 notes="포구(§26): 나루보다 창고·객주·상인이 많다(GG-02)"),
    "yongsan": dict(_GH, archetype="river", roof={"choga": 0.7, "giwa": 0.3}, wall="todam", layout="fan_from_ferry",
                    entrance="wharf", people=["객주", "선주", "짐꾼"], animals=["소"],
                    signature="용산강 포구 — 세곡 창고와 강상 배", trades=["객주", "곡물"],
                    notes="포구(§26). 군자감 강감(창고) 자리 가설"),
    "noryangjin": dict(_GH, archetype="river", roof={"choga": 0.85, "giwa": 0.15}, wall="todam", layout="fan_from_ferry",
                       entrance="ferry", people=["뱃사공", "관원", "나그네", "말꾼"], animals=["말"],
                       signature="노들나루 — 삼남대로가 한강을 건너는 큰 나루, 나룻배 대기와 말 대기",
                       trades=["나루", "주막"], notes="대형 나루(§25, GG-03). 강 건너 노들섬 쪽"),
    "hangangjin": dict(_GH, archetype="river", roof={"choga": 0.85, "giwa": 0.15}, wall="todam", layout="fan_from_ferry",
                       entrance="ferry", people=["뱃사공", "관원", "나그네"], animals=["말"],
                       signature="한강진 나루 — 버티고개 넘어 사평으로 건너는 나룻배", trades=["나루", "주막"]),
    "seobinggo_village": dict(_GH, archetype="river", roof={"choga": 0.9, "giwa": 0.1}, wall="fence", layout="rows",
                              entrance="ferry", people=["빙고 일꾼", "뱃사공"], animals=[],
                              signature="서빙고 얼음 창고 아래 강가 마을", trades=["얼음 뜨기", "나루"]),
}
_AUTO_GH = dict(_GH, archetype="plain", roof={"choga": 0.9, "giwa": 0.1}, wall="fence", layout="rows",
                entrance="zelkova_square", people=["농부"], animals=["소"], signature="도성 밖 들의 ㄱ자 초가 마을", trades=["논농사", "채소"])

# ── 황주(해서, 중부) ─────────────────────────────────────────────
_HS = dict(culture="haeseo", climate="central")
HH_HWANGJU = {
    "hwangju_eup": dict(_HS, archetype="eupchi", roof={"giwa": 0.4, "choga": 0.6}, wall="todam", layout="walled_grid",
                        entrance="gate", people=["관속", "역졸", "장꾼", "사신 행렬"], animals=["말", "소"],
                        signature="들판 가운데 네모난 돌 읍성 — 의주대로가 남문에서 북문으로 꿰뚫고, 성 안엔 깊은 一자 겹집",
                        trades=["관아", "역참", "장시"], houses=["culture/haeseo/compound(large=기와)", "culture/haeseo/compound"],
                        notes="황주목 읍치(HH-02). 사신 길(의주대로) 객사 제안관. 평지 방형 읍성 가설"),
    "hwangju_jang": dict(_HS, archetype="eupchi", roof={"choga": 0.85, "giwa": 0.15}, wall="fence", layout="linear_street",
                         entrance="market_flag", people=["장꾼", "보부상", "주모"], animals=["소", "말"],
                         signature="남문 밖 의주대로 장거리 — 재령 쌀과 사과 좌판", trades=["장시", "주막"]),
    "dohwadong": dict(_HS, archetype="plain", roof={"choga": 1.0}, wall="fence", layout="rows",
                      entrance="peach_tree", people=["농부", "아낙"], animals=["소"],
                      signature="복숭아나무 아래 우물이 있는 들마을 — 심청 이야기가 떠도는 곳(고증 B, 확정 아님)",
                      trades=["논농사"], notes="심청 계열(FOLKTALE B 태그) — 장소 고정 아님, 소문으로만"),
    "namcheon_ferry_village": dict(_HS, archetype="river", roof={"choga": 1.0}, wall="fence", layout="fan_from_ferry",
                                   entrance="ferry", people=["뱃사공", "나그네"], animals=["소"],
                                   signature="황주천 섶다리 건넛마을과 주막", trades=["나루", "주막"]),
    "cheonju_village": dict(_HS, archetype="plain", roof={"choga": 1.0}, wall="fence", layout="rows",
                            entrance="zelkova_square", people=["농부"], animals=["소"],
                            signature="천주천 돌다리 건너 들마을", trades=["논농사"]),
}
_AUTO_HS = dict(_HS, archetype="plain", roof={"choga": 1.0}, wall="fence", layout="rows",
                entrance="zelkova_square", people=["농부"], animals=["소"], signature="넓은 들의 깊은 一자 겹집 초가 마을",
                trades=["논농사"])

# ── 평양(관서, 북부) ─────────────────────────────────────────────
_GS = dict(culture="gwanseo", climate="north")
PA_PYEONGYANG = {
    "pyeongyang_naeseong": dict(_GS, archetype="eupchi", roof={"giwa": 0.7, "choga": 0.3}, wall="todam", wall_detail="city_wall", layout="walled_grid",
                                entrance="gate", people=["감영 관속", "기생", "상인", "군관"], animals=["말"],
                                signature="모란봉을 등지고 대동강을 앞에 둔 감영 도시 — 짙은 기와 넓은 처마와 사괴석 도시 담",
                                trades=["감영", "장시", "기방"],
                                houses=["culture/gwanseo/compound(large=평양 기와)", "culture/gwanseo/compound(medium)"],
                                notes="평안감영(PA-01). 대동문 앞 나루와 종로가 도시 축(명세 §14)"),
    "pyeongyang_jongno": dict(_GS, archetype="eupchi", roof={"giwa": 0.7, "choga": 0.3}, wall="todam", wall_detail="city_wall", layout="linear_street",
                              entrance="bell_pavilion", people=["상인", "객주", "김선달 같은 건달"], animals=["말", "소"],
                              signature="대동문에서 보통문까지 종로 가게채 — 종각과 장꾼 차양", trades=["장시", "객주"]),
    "jungseong": dict(_GS, archetype="eupchi", roof={"choga": 0.7, "giwa": 0.3}, wall="todam", layout="linear_street",
                      entrance="gate", people=["장인", "농부"], animals=["소"],
                      signature="중성 안 길가 서북 초가 — 납작한 잿빛 이엉 줄", trades=["장인", "채소"]),
    "oeseong": dict(_GS, archetype="plain", roof={"choga": 1.0}, wall="fence", layout="rows",
                    entrance="field_grid", people=["농부"], animals=["소"],
                    signature="외성 들 — 기자 정전(井田) 터라 전하는 네모 반듯한 밭두렁", trades=["밭농사"],
                    notes="기자 정전 전승(전승 표현)"),
    "daedong_naru": dict(_GS, archetype="river", roof={"choga": 0.6, "giwa": 0.4}, wall="todam", layout="fan_from_ferry",
                         entrance="ferry", people=["뱃사공", "객주", "짐꾼", "관원"], animals=["말", "소"],
                         signature="대동문 앞 돌계단 선창과 나룻배·짐배 — 강창과 객주 창고",
                         trades=["나루", "객주", "강창"], notes="대형 나루(§25): 객주·관원·큰 창고"),
    "seongyo": dict(_GS, archetype="river", roof={"choga": 1.0}, wall="fence", layout="fan_from_ferry",
                    entrance="ferry", people=["뱃사공", "농부"], animals=["소"],
                    signature="대동강 건너 선교리 나루 마을", trades=["나루", "논농사"]),
    "neungrado": dict(_GS, archetype="river", roof={"choga": 1.0}, wall="fence", layout="rows",
                      entrance="ferry", people=["농부", "뱃사공"], animals=["소"],
                      signature="버드나무 섬 능라도의 작은 마을", trades=["밭농사", "고기잡이"]),
    "yanggakdo": dict(_GS, archetype="river", roof={"choga": 1.0}, wall="fence", layout="rows",
                      entrance="ferry", people=["농부", "뱃사공"], animals=["소"],
                      signature="강 가운데 섬 양각도 모래밭 마을", trades=["밭농사"]),
    "yeongmyeongsa_temple": dict(_GS, archetype="temple", roof={"giwa": 1.0}, wall="todam", layout="along_temple_road",
                                 entrance="stone_jangseung", people=["스님"], animals=[],
                                 signature="부벽루 곁 영명사 — 기린굴 이야기(동명왕)", trades=["절"]),
    "botong_out": dict(_GS, archetype="pass", roof={"choga": 0.9, "giwa": 0.1}, wall="fence", layout="linear_street",
                       entrance="seonghwang_cairn", people=["나그네", "역졸", "주모"], animals=["말"],
                       signature="보통문 밖 의주길 — 주막과 마방", trades=["주막", "역참"]),
}
_AUTO_GS = dict(_GS, archetype="plain", roof={"choga": 1.0}, wall="fence", layout="rows",
                entrance="zelkova_square", people=["농부"], animals=["소"], signature="잿빛 이엉 서북 초가 들마을", trades=["밭농사"])

# ── 함흥(관북, 북부) ─────────────────────────────────────────────
_GB = dict(culture="gwanbuk", climate="north")
HG_HAMHEUNG = {
    "hamheung_eup": dict(_GB, archetype="eupchi", roof={"giwa": 0.35, "choga": 0.65}, wall="todam", layout="walled_grid",
                         entrance="gate", people=["감영 관속", "군관", "장꾼"], animals=["말", "소"],
                         signature="반룡산 기슭 감영 성 — 두툼한 갈색 이엉 田자 집과 장작 井자 더미, 성천강 만세교",
                         trades=["감영", "장시", "군영"], houses=["culture/gwanbuk/compound", "culture/gwanbuk/jeonja"],
                         notes="함경감영(HG-03). 성천강 충적평야 + 배후 반룡산"),
    "hamheung_jang": dict(_GB, archetype="eupchi", roof={"choga": 0.9, "giwa": 0.1}, wall="fence", layout="linear_street",
                          entrance="market_flag", people=["장꾼", "보부상", "명태 장수"], animals=["소", "말"],
                          signature="남문 밖 성천강 둑 장거리 — 명태·삼베 좌판", trades=["장시", "주막"]),
    "manse_west": dict(_GB, archetype="pass", roof={"choga": 1.0}, wall="fence", layout="few_roadside",
                       entrance="long_bridge", people=["나그네", "주모", "말꾼"], animals=["말"],
                       signature="만세교 서쪽 머리 주막과 마방", trades=["주막"]),
    "bongung_village": dict(_GB, archetype="plain", roof={"choga": 1.0}, wall="fence", layout="rows",
                            entrance="pine_tree", people=["농부", "능지기"], animals=["소"],
                            signature="함흥본궁 반송 아래 들마을 — 함흥차사 이야기", trades=["밭농사"]),
    "unheung": dict(_GB, archetype="plain", roof={"choga": 1.0}, wall="fence", layout="rows",
                    entrance="zelkova_square", people=["농부"], animals=["소"],
                    signature="반룡산 동쪽 기슭 들마을", trades=["밭농사"]),
}
_AUTO_GB = dict(_GB, archetype="plain", roof={"choga": 1.0}, wall="fence", layout="rows",
                entrance="zelkova_square", people=["농부"], animals=["소"], signature="성천강 들의 田자 겹집 마을", trades=["밭농사"])

PROFILES = {"GG_HANYANG": GG_HANYANG, "HH_HWANGJU": HH_HWANGJU, "PA_PYEONGYANG": PA_PYEONGYANG, "HG_HAMHEUNG": HG_HAMHEUNG}
AUTO = {"GG_HANYANG": _AUTO_GH, "HH_HWANGJU": _AUTO_HS, "PA_PYEONGYANG": _AUTO_GS, "HG_HAMHEUNG": _AUTO_GB}
CULTURE = {"GG_HANYANG": "giho", "HH_HWANGJU": "haeseo", "PA_PYEONGYANG": "gwanseo", "HG_HAMHEUNG": "gwanbuk"}

# 지명 표시(place_title)용 짧은 이름 — settlement title로 쓴다
TITLES = {
    "GG_HANYANG": {"hanyang_doseong_in": "한양", "bukchon": "북촌", "ungjongga": "운종가", "jungchon": "개천", "namchon": "남산골",
                   "baeogae_jang": "배오개", "chilpae_jang": "칠패", "wangsimni": "왕십리", "mapo": "마포", "yongsan": "용산",
                   "noryangjin": "노량진", "hangangjin": "한강진", "seobinggo_village": "서빙고"},
    "HH_HWANGJU": {"hwangju_eup": "황주", "hwangju_jang": "황주", "dohwadong": "도화동", "namcheon_ferry_village": "황주천 나루",
                   "cheonju_village": "천주"},
    "PA_PYEONGYANG": {"pyeongyang_naeseong": "평양", "pyeongyang_jongno": "평양", "jungseong": "중성", "oeseong": "외성",
                      "daedong_naru": "대동강 나루", "seongyo": "선교리", "neungrado": "능라도", "yanggakdo": "양각도",
                      "yeongmyeongsa_temple": "영명사", "botong_out": "보통문 밖"},
    "HG_HAMHEUNG": {"hamheung_eup": "함흥", "hamheung_jang": "함흥", "manse_west": "만세교", "bongung_village": "본궁",
                    "unheung": "운흥"},
}


def profile_for(rid, s):
    p = PROFILES[rid].get(s["id"])
    if p:
        return dict(p)
    return dict(AUTO[rid])
