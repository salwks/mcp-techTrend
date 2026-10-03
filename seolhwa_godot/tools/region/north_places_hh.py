"""data-north 고증 제어점 — HH_HWANGJU (황주 · 황주천 · 의주대로 중간 거점). 형식은 north_places_gg.py와 같다.
명세 HH-02: 개성↔평양 북상로의 중간 핵심거점, 심청 계열 사건 지역연계 후보(고증 태그 B — 강제 확정하지 않음).
위성 '장산곶·인당수 바닷가'(약 100km 서남)와 길목 '구월산 기슭'(약 50km 서남)은 권역에서 멀어 노정·바닷가 띠로 뺌(보고서)."""

SRC_OSM = "OpenStreetMap (Overpass, 2026-10 조회 — 북한 지도, 위치 정확도 보통)"
SRC_EKC = "한국민족문화대백과(통설)"
SRC_SPEC = "WORLD_SPEC v0.3 §21 HH-02"

EUP = (38.6930, 125.7612)     # 황주읍(OSM town 38.6936,125.7615) — 읍성 중심(가설: 평지 방형)

LANDMARKS = [
    dict(id="hwangju_eupseong", name="황주읍성", kit="landmark/eupseong_generic", lat=EUP[0], lon=EUP[1], ry=0, confidence="가설",
         source=[SRC_OSM + " — 황주읍 38.6936,125.7615", "원칙: 평지 방형 읍성(실제 모양·둘레 미확인)"],
         notes="한 변 실제 약 500m → 압축 땅에서 약 150m(게임). 4문. 의주대로가 남문→북문으로 꿰뚫음.", size_m=[150, 150]),
    dict(id="hwangju_gaeksa", name="황주 객사", kit="landmark/gaeksa", lat=EUP[0] + 0.0004, lon=EUP[1], ry=0, confidence="가설",
         source=["원칙: 읍성 가운데 객사"], notes="사신 길(의주대로) 객사 — 중국 사신이 묵던 큰 객사(가설 규모).", size_m=[55, 35]),
    dict(id="hwangju_dongheon", name="황주목 동헌", kit="landmark/hyeon_gwana", lat=EUP[0] - 0.0005, lon=EUP[1] + 0.0010, ry=0, confidence="가설",
         source=["원칙: 객사 동쪽 동헌"], notes="", size_m=[40, 32]),
    dict(id="wolparu", name="월파루", kit="landmark/pavilion_small", lat=38.6805, lon=125.7540, ry=0, confidence="가설",
         source=[SRC_EKC + " '월파루' — 황주 읍치 앞 물가 누각(위치 가설)"], notes="황주천 가 누각 — 달 비친 물결. 기생·사신 연회(가설).", size_m=[16, 10]),
    dict(id="dohwadong_well", name="도화동 우물(심청 이야기 자리)", kit="landmark/village_well", lat=38.6752, lon=125.7440, ry=0, confidence="가설",
         source=["심청전: 황주 도화동(소설 배경, 지역연계 B — 강제 확정 않음)"], notes="심봉사가 빠진 개울·우물 이야기 자리로 쓸 수 있음(가설).", size_m=[8, 8]),
]

SETTLEMENTS = [
    dict(id="hwangju_eup", name="황주 읍내(읍성)", type="읍성", lat=EUP[0], lon=EUP[1], radius_m=110, size="L", confidence="추정",
         source=[SRC_OSM + " — 황주읍"], notes="황주목 읍치. 의주대로(사신 길) 객사 고을."),
    dict(id="hwangju_jang", name="황주 장(남문 밖)", type="장시", lat=38.6890, lon=125.7608, radius_m=40, size="M", confidence="가설",
         source=["원칙: 남문 밖 장터"], notes="황해 곡물·사과(가설: 사과는 근대 — 쓰지 않음)·소."),
    dict(id="dohwadong", name="도화동", type="마을", lat=38.6755, lon=125.7445, radius_m=45, size="M", confidence="가설",
         source=["심청전 배경 지명(소설) — 위치는 황주천 남서 들마을로 둠(가설)"], notes="심청 이야기 마을(B 태그)."),
    dict(id="namcheon_ferry_village", name="황주천 건넛마을", type="원", lat=38.6655, lon=125.7650, radius_m=35, size="S", confidence="가설",
         source=["원칙: 대로가 큰 내를 건너는 자리 길목 마을"], notes="의주대로 남쪽 — 주막·섶다리."),
    dict(id="cheonju_village", name="천주천 들마을", type="마을", lat=38.7050, lon=125.7560, radius_m=40, size="S", confidence="가설",
         source=[SRC_OSM + " — 천주천"], notes="읍성 북쪽 내 건너 들."),
]

PASSES = []

RIVER_CONTROL = {
    "hwangjucheon": dict(name="황주천", grade="B", width_real_m=40, flows_to="권역 밖 — 대동강(겸이포 아래)", osm_names=["황주천"],
                         ctrl=[(38.6362, 125.8594), (38.6443, 125.8151), (38.6530, 125.7992), (38.6639, 125.7762), (38.6684, 125.7635), (38.6792, 125.7511),
                               (38.6796, 125.7195), (38.6806, 125.7079), (38.6949, 125.6743), (38.7063, 125.6728), (38.7120, 125.6600)], carve=True,
                         source=[SRC_OSM + " — 황주천"], notes="읍 남쪽을 서쪽으로 흘러 대동강에 듦. 넓은 들(논)."),
    "cheonjucheon": dict(name="천주천", grade="C", width_real_m=15, flows_to="황주천", osm_names=["천주천"],
                         ctrl=[(38.7103, 125.8249), (38.7116, 125.7977), (38.7061, 125.7713), (38.7014, 125.7481), (38.6947, 125.7250), (38.6818, 125.7173)], carve=True,
                         source=[SRC_OSM + " — 천주천"], notes="읍 북쪽 내."),
    "seongsancheon": dict(name="성산천", grade="C", width_real_m=12, flows_to="황주천", osm_names=["성산천"],
                          ctrl=[(38.5955, 125.8250), (38.6219, 125.8046), (38.6440, 125.8047), (38.6513, 125.8031)], source=[SRC_OSM + " — 성산천"], notes="정방산 쪽 남쪽 내."),
}

ROADS = [
    dict(id="uiju_south", name="의주대로(황주 남문→정방산·봉산 방면)", cls="대로", width_m=6.0,
         via=["g:S", (38.6890, 125.7608), "c:hwangjucheon_bridge", (38.6400, 125.7700), (38.5960, 125.7760)],
         notes="남쪽 끝 포털: 한양→평양 노정(봉산·서흥·개성)."),
    dict(id="uiju_north", name="의주대로(황주 북문→중화·평양 방면)", cls="대로", width_m=6.0,
         via=["g:N", "c:cheonju_bridge", (38.7200, 125.7700), (38.7340, 125.7820)],
         notes="북쪽 끝 포털: 중화 → 평양."),
    dict(id="eup_ns", name="황주 성안 남북길", cls="지선", width_m=6.0, fixed=["gc:S", "gc:N"]),
    dict(id="eup_ew", name="황주 성안 동서길", cls="지선", width_m=5.0, fixed=["gc:W", "gc:E"]),
    dict(id="gyeomipo_road", name="겸이포길(서문→대동강 포구)", cls="지선", width_m=4.0, via=["g:W", (38.6935, 125.7480), (38.6990, 125.7300), (38.7060, 125.6900), (38.7120, 125.6620)],
         notes="서쪽 끝(권역 밖 겸이포 — 대동강 포구, 지도에만)."),
    dict(id="dohwa_lane", name="도화동 길", cls="마을길", width_m=3.5, branch_of="uiju_south", via=[(38.6800, 125.7520), (38.6755, 125.7445)]),
    dict(id="east_lane", name="동문 밖 길(성산천 들)", cls="마을길", width_m=3.5, via=["g:E", (38.6800, 125.7900), (38.6500, 125.8050)]),
]

CROSSINGS = [
    dict(id="hwangjucheon_bridge", name="황주천 섶다리(남천 건널목)", type="섶다리", river="hwangjucheon", road="uiju_south", lat=38.6688, lon=125.7640, confidence="가설",
         notes="겨울~봄 섶다리, 여름 큰물엔 나룻배(가설)."),
    dict(id="cheonju_bridge", name="천주천 돌다리", type="돌다리", river="cheonjucheon", road="uiju_north", lat=38.7010, lon=125.7640, confidence="가설", notes="사신 길 돌다리(가설)."),
]

AXES = [dict(town="황주 읍성", center=EUP, jinsan=("읍 북쪽 뒷산(이름 미상)", 38.7200, 125.7650, "가설"), ansan=("남쪽 앞산(이름 미상)", 38.6500, 125.7700, "가설"),
             note="평지 읍성 — 진산·안산은 DEM 봉우리 가설.")]

PORTALS = [
    dict(id="to_kaesong", name="→ 개성·한양(의주대로)", road="uiju_south", to_route="GG_HANYANG-HH_HWANGJU", note="봉산(사리원·정방산 성불사) → 서흥 → 평산 → 개성 → 한양"),
    dict(id="to_pyeongyang", name="→ 평양(의주대로)", road="uiju_north", to_route="HH_HWANGJU-PA_PYEONGYANG", note="중화 → 평양"),
    dict(id="to_jangsangot", name="→ 장산곶·인당수(바닷가 띠)", road="gyeomipo_road", to_route="HH_HWANGJU-JANGSANGOT", note="겸이포·재령평야 → 구월산 기슭(삼성사·임꺽정) → 장산곶 — 노정 미정"),
]
for _p in PORTALS:
    _p["ref"] = list(next(r for r in ROADS if r["id"] == _p["road"])["via"][-1])

SPAWN = dict(lat=38.6875, lon=125.7608, note="황주읍성 남문 밖 장터 길")

PROFILES = {
    "hwangju_eup": dict(archetype="eupchi", climate="central", roof={"giwa": 0.45, "choga": 0.55}, wall="stone", signature="사신 길 객사와 남문 밖 장, 황주천 월파루",
                        trades=["관아", "객사(사신 접대)", "장시"], people=["관속", "역졸", "사신 행렬", "장꾼"], animals=["말"],
                        notes="해서 문화권: 一자·ㄱ자 겹집 섞임(가설)"),
    "hwangju_jang": dict(archetype="eupchi", climate="central", signature="곡식 섬과 소 시장", trades=["장시"], people=["장꾼", "보부상"], animals=["소"]),
    "dohwadong": dict(archetype="plain", climate="central", signature="개울 외나무다리와 우물, 눈먼 아비 이야기", trades=["논농사"], people=["농부", "아낙"], animals=["소"],
                      notes="심청 이야기 연계 후보(B) — 사건은 '이야기', 장소는 평범한 들마을"),
    "namcheon_ferry_village": dict(archetype="river", climate="central", signature="대로 섶다리와 주막", trades=["주막", "나루"], people=["뱃사공", "주모", "나그네"]),
    "cheonju_village": dict(archetype="plain", climate="central", signature="낮은 들의 둥근 초가 무리", trades=["논농사"], people=["농부"], animals=["소"]),
}

META = dict(parent_province="황해도", main_river="황주천", connected_river=["천주천·성산천→황주천", "황주천→대동강(권역 밖 서쪽, 겸이포)"],
            watershed_divide="정방산 줄기(남쪽, 권역 밖) — 북쪽 황주천·남쪽 재령강",
            main_mountain=["읍 북쪽 구릉", "정방산(남쪽 권역 밖, 성불사)"], settlement_type="목(牧) 읍성 + 의주대로 길목 + 황주천 들마을",
            economy=["논농사(황주천 들)", "의주대로 역참·객사(사신 길)", "장시", "대동강 포구(겸이포, 권역 밖)"],
            forbidden=["현대 공장·철도(평부선)·도로", "직강 하천·저수지", "기념비"],
            sources=["OpenStreetMap 북한 지도", "한국민족문화대백과(통설)", SRC_SPEC])
MAIN_ROAD = "uiju_south"
HYDRO_EXTRA = dict(edge_flows=[dict(cond="True", label="권역 밖 — 황주천·대동강 수계")])
QA_ALT = [dict(id="hwangju_gaeksa", lo=3, hi=60)]
ZOOMS = {"zoom_hwangju_eup": [-700, -1300, 500, -200], "zoom_dohwadong": [-900, -600, 200, 200]}
EUPSEONG = dict(landmark="hwangju_eupseong", settlement="hwangju_eup", half=75.0, gates="SNEW")
N_AUTO = 8
CLIMATE_BAND = "central"
