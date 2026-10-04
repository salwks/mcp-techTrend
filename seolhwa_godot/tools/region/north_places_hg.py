"""data-north 고증 제어점 — HG_HAMHEUNG (함흥 · 성천강 충적평야 · 반룡산). 형식은 north_places_gg.py와 같다.
명세 HG-03: 성천강이 만든 충적평야가 함흥의 핵심 지형 — 넓은 평야, 배후 산(반룡산), 함흥읍성·관아(함경감영)·시장."""

SRC_OSM = "OpenStreetMap (Overpass, 2026-10 조회 — 북한 지도, 위치 정확도 보통)"
SRC_EKC = "한국민족문화대백과(통설)"
SRC_SPEC = "WORLD_SPEC v0.3 §21 HG-03"

LANDMARKS = [
    dict(id="seonhwadang", name="함경감영 선화당", kit="landmark/gamyeong", lat=39.9140, lon=127.5239, ry=0, confidence="추정",
         source=[SRC_OSM + " — 선화당 39.9140,127.5239", SRC_EKC + " '함흥 선화당'"], notes="함경도 관찰사 집무처(정면 7칸 팔작). 반룡산 남쪽 기슭 성 안.", size_m=[80, 60]),
    dict(id="hamheung_south_gate", name="함흥읍성 남문", kit="landmark/eupseong_gate", lat=39.9066, lon=127.5240, ry=0, confidence="가설",
         source=["원칙: 감영 정면 남쪽 문(위치 가설)"], notes="", size_m=[16, 10]),
    dict(id="nakminnu", name="낙민루(서문루)", kit="landmark/pavilion_nakmin", lat=39.9118, lon=127.5188, ry=-1.57, confidence="가설",
         source=[SRC_EKC + " '낙민루' — 성천강 가 서쪽 성문 누각, 만세교와 마주함"], notes="성천강을 내려다보는 누각. 만세교 동쪽 머리.", size_m=[16, 10]),
    dict(id="hamheung_east_gate", name="함흥읍성 동문", kit="landmark/eupseong_gate", lat=39.9132, lon=127.5320, ry=1.57, confidence="가설",
         source=["원칙: 북청·홍원 가는 길 쪽 문(위치 가설)"], notes="", size_m=[14, 9]),
    dict(id="gucheongak", name="구천각(북장대)", kit="landmark/pavilion_small", lat=39.9200, lon=127.5235, ry=0, confidence="가설",
         source=[SRC_EKC + " '구천각' — 반룡산 성곽 위 장대"], notes="반룡산 능선 성곽 위 누각.", size_m=[12, 9]),
    dict(id="chimadae", name="치마대", kit="landmark/stone_platform", lat=39.9235, lon=127.5262, ry=0, confidence="가설",
         source=["반룡산 꼭대기 말 달리던 대(전설)"], notes="", size_m=[20, 14]),
    dict(id="manse_bridge", name="만세교", kit="landmark/long_wooden_bridge", lat=39.9133, lon=127.5160, ry=1.57, confidence="추정",
         source=[SRC_EKC + " '만세교' — 성천강의 긴 나무다리(관북 제일)", SRC_OSM + " — 성천강 물길"], notes="성천강 넓은 자갈 바닥을 건너는 긴 널다리(실물 수백 m — 물길 폭만큼). 큰물이면 떠내려가 다시 놓음.", size_m=[30, 6], nopad=True),
    dict(id="hamheung_bongung", name="함흥본궁", kit="landmark/bongung", lat=39.8708, lon=127.5669, ry=0, confidence="확정",
         source=[SRC_OSM + " — 함흥본궁 39.8708,127.5669 / 풍패루"], notes="태조 이성계의 옛집 — 함흥차사 이야기의 무대. 정전·이안전·풍패루, 태조 손수 심었다는 소나무.", size_m=[70, 60]),
]

SETTLEMENTS = [
    dict(id="hamheung_eup", name="함흥 읍내(감영)", type="읍성", lat=39.9115, lon=127.5245, radius_m=160, size="XL", confidence="추정",
         source=[SRC_OSM + " — 선화당·서문동·남문동 일대"], notes="함경감영 도읍. 반룡산 남쪽 비탈과 성천강 사이."),
    dict(id="hamheung_jang", name="함흥 장(남문 밖)", type="장시", lat=39.9050, lon=127.5225, radius_m=50, size="L", confidence="가설",
         source=["원칙: 읍성 남문 밖 장터"], notes="관북 물산(삼베·명태·소)."),
    dict(id="manse_west", name="만세교 서쪽 마을", type="원", lat=39.9150, lon=127.5070, radius_m=45, size="M", confidence="가설",
         source=["원칙: 큰 다리 맞은편 길목 마을"], notes="정평·영흥 가는 경흥대로 길목 — 주막·마방."),
    dict(id="bongung_village", name="본궁 아래 마을", type="마을", lat=39.8745, lon=127.5615, radius_m=50, size="M", confidence="가설",
         source=[SRC_OSM + " — 함흥본궁 부근"], notes="호련천·성천강 합류 들마을."),
    dict(id="unheung", name="운흥 들마을", type="마을", lat=39.9300, lon=127.5320, radius_m=45, size="M", confidence="가설",
         source=[SRC_OSM + " — 운흥동 일대(현대 지명)"], notes="반룡산 북쪽 들."),
]

PASSES = []

RIVER_CONTROL = {
    "seongcheongang": dict(name="성천강", grade="B", width_real_m=90, flows_to="권역 밖 — 동해(서호·흥남 앞바다)", osm_names=["성천강"],
                           ctrl=[(39.9845, 127.4730), (39.9640, 127.4897), (39.9373, 127.5007), (39.9221, 127.5108), (39.9132, 127.5165),
                                 (39.9030, 127.5220), (39.8829, 127.5468), (39.8655, 127.5595), (39.8440, 127.5705)], carve=True,
                           source=[SRC_OSM + " — 성천강", SRC_SPEC], notes="넓은 자갈 바닥에 물길 여러 갈래(가설). 함흥평야를 만든 강."),
    "horyeoncheon": dict(name="호련천", grade="C", width_real_m=25, flows_to="성천강(권역 밖 — 본궁 앞 합류 근처)", osm_names=["호련천"],
                         ctrl=[(39.9845, 127.5960), (39.9560, 127.5712), (39.9313, 127.5593), (39.9074, 127.5555), (39.8762, 127.5534)], carve=True,
                         source=[SRC_OSM + " — 호련천"], notes="성 동쪽을 흘러 본궁 앞에서 성천강에 듦."),
    "yeowicheon": dict(name="여위천", grade="C", width_real_m=15, flows_to="권역 밖 — 성천강", osm_names=["여위천"],
                       ctrl=[(39.9670, 127.4580), (39.9000, 127.4900), (39.8455, 127.5250)], source=[SRC_OSM + " — 여위천"], notes="평야 서쪽 내"),
}

ROADS = [
    dict(id="gyeongheung_daero", name="경흥대로(정평→만세교→함흥)", cls="대로", width_m=6.0,
         via=[(39.8600, 127.4420), (39.8900, 127.4780), (39.9150, 127.5060), "c:manse_crossing", (39.9118, 127.5200), (39.9130, 127.5235)],
         notes="남서 끝 포털: 정평·영흥·안변·철령 → 한양(경흥대로), 평양 노정은 영흥에서 갈라짐."),
    dict(id="hamheung_inner", name="함흥 성안길(남문→선화당)", cls="지선", width_m=6.0, via=[(39.9066, 127.5240), (39.9130, 127.5238)], astar=False),
    dict(id="bukcheong_road", name="북청길(선화당→동문→호련천→홍원)", cls="대로", width_m=5.0,
         via=[(39.9130, 127.5238), (39.9132, 127.5320), (39.9200, 127.5600), (39.9280, 127.6399)],
         notes="동쪽 끝 포털: 홍원·북청(사자놀음) 노정."),
    dict(id="bongung_road", name="본궁길(남문→본궁)", cls="지선", width_m=5.0, via=[(39.9066, 127.5240), (39.8950, 127.5400), (39.8760, 127.5600), (39.8715, 127.5665)]),
    dict(id="seoho_road", name="서호길(본궁→서호진 포구)", cls="지선", width_m=4.0, via=[(39.8760, 127.5600), (39.8600, 127.5750), (39.8460, 127.5850)],
         notes="남쪽 끝(권역 밖 서호진 포구 — 지도에만)."),
    dict(id="unheung_lane", name="운흥 마을길", cls="마을길", width_m=3.5, via=[(39.9132, 127.5320), (39.9300, 127.5320)]),
    # cheollyeong_road(정평 갈래 → 옛 to_hanyang_cheollyeong 포털) 지움 — routes 3차: 포털이 to_yeongheung으로 합쳐져 막다른 길이 됨
    dict(id="bannyong_trail", name="반룡산 산길(구천각·치마대)", cls="산길", width_m=1.5, via=[(39.9140, 127.5239), (39.9200, 127.5235), (39.9235, 127.5262)]),
]

CROSSINGS = [
    dict(id="manse_crossing", name="만세교", type="섶다리", river="seongcheongang", road="gyeongheung_daero", lat=39.9133, lon=127.5160, confidence="추정",
         notes="실제는 긴 널다리(나무다리) — kit landmark/long_wooden_bridge. 계약 형식상 섶다리로 표기(가설)."),
]

AXES = [dict(town="함흥 읍성", center=(39.9115, 127.5245), jinsan=("반룡산", 39.9235, 127.5262, "추정"), ansan=("성천강 건너 남쪽 들(안산 미상)", 39.8900, 127.5100, "가설"),
             note="반룡산을 등지고 성천강 평야를 내려다봄.")]

PORTALS = [
    # routes 2차(2026-10-04): 한양 철령길과 평양 양덕길은 영흥에서 만나므로 함흥 남서 포털은 하나(경흥대로 노정 → 영흥 갈림길에서 평양 노정으로)
    dict(id="to_yeongheung", name="→ 영흥 갈림(한양 철령길·평양 양덕길)", road="gyeongheung_daero", to_route="GG_HANYANG-HG_HAMHEUNG",
         note="경흥대로 남서 끝 → 정평 → 영흥 갈림길(노정 GG_HANYANG-HG_HAMHEUNG 안). 평양 양덕길(PA_PYEONGYANG-HG_HAMHEUNG)은 영흥에서 갈라진다 — 옛 to_pyeongyang·to_hanyang_cheollyeong을 합침"),
    dict(id="to_bukcheong", name="→ 북청(홍원)", road="bukcheong_road", to_route="HG_HAMHEUNG-BUKCHEONG", note="홍원 → 북청(사자놀음) — 노정 미정"),
]
for _p in PORTALS:
    r_ = next(r for r in ROADS if r["id"] == _p["road"])
    _p["ref"] = list(r_["via"][0] if _p["id"] == "to_yeongheung" else r_["via"][-1])

SPAWN = dict(lat=39.9122, lon=127.5185, note="만세교 동쪽 머리, 낙민루 앞")

PROFILES = {
    "hamheung_eup": dict(archetype="eupchi", climate="north", roof={"giwa": 0.4, "choga": 0.6}, wall="stone", signature="만세교 긴 다리와 반룡산 성곽, 낙민루",
                         trades=["감영", "장시"], people=["감영 관속", "포수", "장꾼", "양반"], animals=["소", "말"],
                         notes="관북 田자 겹집(정주간) — 바람막이 겹집, 지붕 낮고 두꺼움(문화권 키트)"),
    "hamheung_jang": dict(archetype="eupchi", climate="north", signature="명태 두름·삼베 필이 쌓인 남문 밖 장", trades=["장시"], people=["장꾼", "보부상"], animals=["소"]),
    "manse_west": dict(archetype="pass", climate="north", signature="다리 건너기 전 주막과 마방", trades=["주막", "마방"], people=["나그네", "마부", "주모"], animals=["말"]),
    "bongung_village": dict(archetype="plain", climate="north", signature="본궁 솔숲과 함흥차사 이야기", trades=["논농사", "본궁 수호"], people=["농부", "궁지기"], animals=["소"]),
    "unheung": dict(archetype="plain", climate="north", signature="넓은 들의 낮은 겹집 무리", trades=["밭농사", "논농사"], people=["농부"], animals=["소"]),
}

META = dict(parent_province="함경도", main_river="성천강", connected_river=["호련천→성천강", "여위천→성천강", "성천강→동해(권역 밖 남동, 서호)"],
            watershed_divide="반룡산(동흥산) 능선: 서쪽 성천강·동쪽 호련천",
            main_mountain=["반룡산(진산)", "북쪽 함경산맥 앞자락"], settlement_type="감영 도읍(함흥읍성) + 성천강 충적평야 들마을 + 본궁",
            economy=["논·밭농사(함흥평야)", "장시(관북 물산)", "명태·소금(서호 포구, 권역 밖)", "삼베"],
            forbidden=["현대 함흥·흥남 공업지대", "철도·도로", "제방 직강 하천", "기념비·동상"],
            sources=["OpenStreetMap 북한 지도", "한국민족문화대백과(통설)", SRC_SPEC])
MAIN_ROAD = "gyeongheung_daero"
HYDRO_EXTRA = dict(edge_flows=[dict(cond="True", label="권역 밖 — 성천강 수계(동해)")], width_game={"B": 27.0, "C": 7.0, "D": 2.5})
QA_ALT = [dict(id="seonhwadang", lo=10, hi=70), dict(id="hamheung_bongung", lo=3, hi=40)]
ZOOMS = {"zoom_hamheung_manse": [-1200, -600, 300, 400], "zoom_bongung": [-300, 800, 1200, 1800]}
WALLS = {
    "hamheung_wall": dict(name="함흥읍성", closed=True, height_m=[4.0, 6.0], kit="landmark/town_wall",
                          gates=["hamheung_south_gate", "nakminnu", "hamheung_east_gate", "gucheongak"], confidence="가설",
                          source=["원칙: 반룡산 남쪽 비탈을 감싼 평산성(모양 가설)"], notes="북쪽은 반룡산 능선(구천각)까지 올라감.",
                          latlon=[(39.9066, 127.5240), (39.9070, 127.5195), (39.9118, 127.5188), (39.9175, 127.5195), (39.9200, 127.5235),
                                  (39.9195, 127.5290), (39.9132, 127.5320), (39.9085, 127.5300), (39.9066, 127.5240)]),
}
N_AUTO = 6

TRUNK_FIX = [("horyeoncheon", "seongcheongang")]
