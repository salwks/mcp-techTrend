"""data-north 고증 제어점 — PA_PYEONGYANG (평양 · 대동강 · 모란봉). 형식은 north_places_gg.py와 같다.
북한 지역: OSM 위치는 현대(복원·이전 포함) — 문루·누정은 대체로 옛 자리. 현대 시설(댐·도로·제방·보통강 개수)은 원칙으로 지운다."""

SRC_OSM = "OpenStreetMap (Overpass, 2026-10 조회 — 북한 지도, 위치 정확도 보통)"
SRC_EKC = "한국민족문화대백과(통설)"
SRC_MAP = "평양성도(18~19세기 회화식 지도) 통설 — 원본 대조 대기"

LANDMARKS = [
    dict(id="pyeongyangseong", name="평양성(내성·중성·북성)", kit="landmark/pyeongyang_wall", lat=39.0300, lon=125.7520, ry=0, confidence="추정",
         source=[SRC_OSM + " — 대동문·보통문·칠성문·현무문·전금문 위치", SRC_EKC + " '평양성'", SRC_MAP],
         notes="고구려 장안성을 이은 조선 평양성: 북성(모란봉)–내성(감영·만수대)–중성–외성(남서 들, 기자 정전 터). 내성 둘레 실제 약 7km. 선은 wall에 — 강 쪽은 대동강 벼랑·강둑을 따름. 외성 성벽은 1870년 무너진 곳 많음(가설)."),
    dict(id="daedongmun", name="대동문", kit="landmark/pyeongyang_gate_daedong", lat=39.0226, lon=125.7568, ry=1.57, confidence="확정",
         source=[SRC_OSM + " — 대동문 39.0226,125.7568"], notes="내성 동문, 대동강 나루로 열림. 2층 문루(1635 중건). 강을 향해 동쪽.", size_m=[30, 16]),
    dict(id="ryeongwangjeong", name="연광정", kit="landmark/pavilion_ryeongwang", lat=39.0233, lon=125.7574, ry=1.57, confidence="확정",
         source=[SRC_OSM + " — 련광정 39.0233,125.7574"], notes="대동문 옆 강가 벼랑 위 누정(ㄱ자 두 채 이음). '천하제일강산' 현판.", size_m=[25, 15]),
    dict(id="pyongyang_jonggak", name="평양 종각", kit="landmark/jongnu_bell", lat=39.0230, lon=125.7570, ry=0, confidence="확정",
         source=[SRC_OSM + " — 평양종각"], notes="대동문 안 종각(1714 종).", size_m=[10, 10]),
    dict(id="botongmun", name="보통문", kit="landmark/pyeongyang_gate", lat=39.0271, lon=125.7419, ry=-1.57, confidence="확정",
         source=[SRC_OSM + " — 보통문 39.0271,125.7419"], notes="내성 서문 — 의주 가는 길(관서대로) 출발점. 보통강 쪽.", size_m=[26, 14]),
    dict(id="chilseongmun", name="칠성문", kit="landmark/pyeongyang_gate", lat=39.0360, lon=125.7543, ry=3.14, confidence="확정",
         source=[SRC_OSM + " — 칠성문 39.036,125.7543"], notes="내성 북문(모란봉 서쪽 기슭). 북면 — 카메라 반대쪽이라 단순하게.", size_m=[18, 10]),
    dict(id="hyeonmumun", name="현무문", kit="landmark/pyeongyang_gate", lat=39.0425, lon=125.7607, ry=3.14, confidence="확정",
         source=[SRC_OSM], notes="북성 북문.", size_m=[16, 9]),
    dict(id="jeongeummun", name="전금문", kit="landmark/pyeongyang_gate", lat=39.0409, lon=125.7617, ry=1.57, confidence="확정",
         source=[SRC_OSM], notes="북성 동문 — 부벽루로 내려가는 문.", size_m=[14, 8]),
    dict(id="bubyeongnu", name="부벽루", kit="landmark/pavilion_bubyeok", lat=39.0415, lon=125.7622, ry=1.57, confidence="확정",
         source=[SRC_OSM + " — 부벽루 39.0415,125.7622", SRC_EKC], notes="청류벽 위 강가 누각(정면 5칸 팔작). 영명사의 부속 누각이었음.", size_m=[20, 10]),
    dict(id="yeongmyeongsa", name="영명사(터)", kit="landmark/temple_small", lat=39.0420, lon=125.7612, ry=0, confidence="가설",
         source=[SRC_EKC + " '영명사' — 부벽루 서쪽, 고구려 구제궁 터 전설(한국전쟁 때 소실)"], notes="1870년엔 현존 사찰(가설: 규모). 기린굴 곁.", size_m=[50, 40]),
    dict(id="girin_gul", name="기린굴", kit="landmark/cave_mouth", lat=39.0408, lon=125.7613, ry=1.57, confidence="가설",
         source=[SRC_EKC + " '기린굴' — 부벽루 서쪽 아래 영명사 곁, 동명왕이 기린마를 기른 굴(전설)"], notes="정확한 좌표 미확인 — 부벽루 아래 벼랑 굴로 둠(가설). 조천석은 그 앞 강가(전설).", size_m=[8, 6]),
    dict(id="eulmildae", name="을밀대", kit="landmark/pavilion_eulmil", lat=39.0415, lon=125.7596, ry=0, confidence="확정",
         source=[SRC_OSM + " — 을밀대 39.0415,125.7596"], notes="모란봉 능선 높은 축대 위 정자(사허정). 봄 경치.", size_m=[14, 12]),
    dict(id="choeseungdae", name="최승대", kit="landmark/pavilion_small", lat=39.0430, lon=125.7622, ry=0, confidence="확정",
         source=[SRC_OSM], notes="모란봉 꼭대기 장대.", size_m=[10, 8]),
    dict(id="cheongnyubyeok", name="청류벽", kit="landmark/cliff_inscription", lat=39.0439, lon=125.7655, ry=1.57, confidence="확정",
         source=[SRC_OSM + " — natural=cliff 청류벽"], notes="모란봉 동쪽 강가 벼랑(글씨 새김).", size_m=[200, 40]),
    dict(id="sungnyeongjeon", name="숭령전·숭인전", kit="landmark/shrine_hall", lat=39.0246, lon=125.7511, ry=0, confidence="추정",
         source=[SRC_OSM + " — 숭령전 39.0245,125.7512 / 숭인전 39.0248,125.7511"], notes="숭령전(단군·동명왕 사당), 숭인전(기자 사당). 숭인전은 옮겨진 것(원위치 가설).", size_m=[50, 40]),
    dict(id="pyeongan_gamyeong", name="평안감영(선화당)", kit="landmark/gamyeong", lat=39.0280, lon=125.7510, ry=0, confidence="가설",
         source=[SRC_MAP + " — 내성 가운데 감영"], notes="평안감사 집무처. 위치는 내성 가운데 만수대 남쪽 기슭으로 가정.", size_m=[90, 70]),
    dict(id="gijareung", name="기자릉", kit="landmark/royal_tomb_small", lat=39.0505, lon=125.7640, ry=0, confidence="가설",
         source=[SRC_EKC + " '기자릉' — 모란봉 북쪽 토산(1959 파괴)"], notes="조선 시대 제사 지내던 능(전설). 위치는 모란봉 북쪽 기슭(가설).", size_m=[40, 40]),
]

SETTLEMENTS = [
    dict(id="pyeongyang_naeseong", name="평양 내성(감영·종로)", type="읍성", lat=39.0280, lon=125.7500, radius_m=300, size="XL", confidence="추정",
         source=[SRC_MAP], notes="평안감영 도읍. 대동문–보통문 사이 종로 시전, 감영·관아."),
    dict(id="pyeongyang_jongno", name="평양 종로 장", type="장시", lat=39.0240, lon=125.7530, radius_m=60, size="L", confidence="가설",
         source=[SRC_OSM + " — 종로동 39.0242,125.7534"], notes="대동문 안 시전 거리 — 서북 상업(개성·의주 무역)."),
    dict(id="jungseong", name="중성 마을", type="마을", lat=39.0170, lon=125.7480, radius_m=160, size="L", confidence="추정",
         source=[SRC_OSM + " — 중성동 39.0161,125.7494"], notes="내성 남쪽 성안 민가."),
    dict(id="oeseong", name="외성 들(기자 정전 터)", type="마을", lat=39.0080, lon=125.7420, radius_m=120, size="M", confidence="추정",
         source=[SRC_OSM + " — 외성동 39.0105,125.7481", "외성 정전(井田) 터 전설(통설)"], notes="반듯한 밭두렁(정전) 들과 농가."),
    dict(id="daedong_naru", name="대동강 나루(대동문 앞)", type="원", lat=39.0216, lon=125.7558, radius_m=50, size="M", confidence="추정",
         source=[SRC_OSM + " — 대동문 앞 강안"], notes="동쪽 건너편(선교리)으로 가는 나룻배, 놀잇배. 1866 셔먼호 사건 이야기가 도는 곳."),
    dict(id="seongyo", name="선교리(강 건너)", type="마을", lat=39.0080, lon=125.7650, radius_m=80, size="M", confidence="추정",
         source=[SRC_OSM + " — 선교동 39.0077,125.7624"], notes="대동강 동쪽 나루 마을 — 중화·황주(남쪽) 가는 길."),
    dict(id="neungrado", name="능라도 마을", type="마을", lat=39.0350, lon=125.7700, radius_m=50, size="S", confidence="가설",
         source=[SRC_OSM + " — 릉라동 39.0337,125.7730"], notes="강 가운데 섬 — 버드나무·뽕밭(가설)."),
    dict(id="yanggakdo", name="양각도(강 가운데 섬)", type="마을", lat=38.9985, lon=125.7460, radius_m=30, size="S", confidence="가설",
         source=[SRC_OSM + " — 양각도", "WORLD_SPEC §14: 능라도·양각도 필수"], notes="모래·버들 섬, 작은 농가. 1866 셔먼호가 이 부근 모래톱에 걸려 불탐(통설)."),
    dict(id="yeongmyeongsa_temple", name="영명사", type="사찰", lat=39.0420, lon=125.7612, radius_m=25, size="S", confidence="가설",
         source=[SRC_EKC], notes="모란봉 강가 절."),
    dict(id="botong_out", name="보통문 밖 마을", type="마을", lat=39.0285, lon=125.7340, radius_m=80, size="M", confidence="가설",
         source=[SRC_OSM + " — 보통문동 39.0226,125.7329"], notes="의주로 길가 — 보통강 건너 서쪽."),
]

PASSES = []

RIVER_CONTROL = {
    "daedonggang": dict(name="대동강", grade="S", water_alt_max=5.5, flows_to="서해(권역 밖 남서, 남포)",
                        ctrl=[(39.0345, 125.8487), (39.0281, 125.8216), (39.0496, 125.7874), (39.0400, 125.7690), (39.0251, 125.7606), (39.0122, 125.7571),
                              (39.0009, 125.7502), (38.9911, 125.7304), (38.9931, 125.7109), (38.9750, 125.6800), (38.9660, 125.6513)],
                        islands=[("능라도", 39.0335, 125.7712, 2600, 650, 20), ("양각도", 38.9985, 125.7462, 1900, 520, 70)],
                        source=[SRC_OSM + " — 대동강 중심선", "물면은 DEM 평탄 수면(능라도·양각도 등 섬은 남김)", "현대 갑문·강안 석축은 원칙으로 지움"],
                        notes="평양 앞에서 S자로 굽이치며 능라도·양각도를 끼고 흐름. 1866 제너럴셔먼호가 양각도 부근에서 불탐(소문)."),
    "botonggang": dict(name="보통강", grade="B", width_real_m=40, flows_to="대동강", osm_names=["보통강"],
                       ctrl=[(39.0867, 125.6950), (39.0612, 125.7035), (39.0474, 125.7110), (39.0340, 125.7039), (39.0160, 125.7090), (39.0004, 125.6964)],
                       source=["OSM 보통강(1946 개수 후 물길)", "옛 물길은 성 서쪽 가까이 굽이쳤다(통설) — 가설"],
                       notes="1870년엔 범람 잦은 굽이 많은 내(가설: 사행 복원)."),
    "hapjanggang": dict(name="합장강", grade="C", width_real_m=15, flows_to="대동강", osm_names=["합장강"],
                        ctrl=[(39.0867, 125.8250), (39.0650, 125.8050), (39.0471, 125.7979)], source=[SRC_OSM + " — 합장강"], notes="대동강 동북 지류"),
    "mujincheon": dict(name="무진천", grade="C", width_real_m=12, flows_to="대동강", osm_names=["무진천", "Mujin Stream"],
                       ctrl=[(38.9711, 125.8487), (38.9847, 125.7838), (38.9876, 125.7448)], source=[SRC_OSM + " — 무진천"], notes="대동강 남안 지류"),
}

ROADS = [
    dict(id="jongno_pyeongyang", name="평양 종로(대동문→보통문)", cls="대로", width_m=10.0, from_ferry=("daedong_ferry_route", 0), via=[(39.0228, 125.7560), (39.0240, 125.7530), (39.0260, 125.7470), (39.0271, 125.7425)], astar=False),
    dict(id="gwanseo_daero", name="관서대로(보통문→의주 방면)", cls="대로", width_m=6.0, via=[(39.0271, 125.7415), (39.0285, 125.7340), (39.0350, 125.7150), (39.0450, 125.6900), (39.0550, 125.6513)],
         notes="서북 끝 포털: 평양→의주(지도에만). 보통강 건넘."),
    dict(id="chilseong_road", name="칠성문길(감영→칠성문→북쪽)", cls="지선", width_m=5.0, via=[(39.0270, 125.7510), (39.0330, 125.7530), (39.0360, 125.7543), (39.0450, 125.7500), (39.0600, 125.7500), (39.0867, 125.7600)],
         notes="북쪽 끝 포털: 평양→함흥 노정(양덕·철령 방면은 동쪽이 맞지만 북문으로 나감 — 가설: 순안·안주 길 겸용)."),
    dict(id="moranbong_trail", name="모란봉 산길(을밀대·최승대·부벽루)", cls="산길", width_m=2.0, via=[(39.0330, 125.7545), (39.0415, 125.7596), (39.0430, 125.7622), (39.0415, 125.7622), (39.0226, 125.7575)]),
    dict(id="riverside_road", name="강가길(대동문→연광정→부벽루)", cls="마을길", width_m=3.5, via=[(39.0228, 125.7575), (39.0300, 125.7600), (39.0380, 125.7620), (39.0415, 125.7625)]),
    dict(id="gamyeong_road", name="감영 앞길(종로→감영)", cls="지선", width_m=6.0, via=[(39.0245, 125.7510), (39.0280, 125.7510)], astar=False),
    dict(id="jungseong_road", name="중성길(종로→중성→외성)", cls="지선", width_m=5.0, via=[(39.0240, 125.7500), (39.0170, 125.7480), (39.0080, 125.7420)]),
    dict(id="daedong_ferry_route", name="대동강 나룻배 뱃길(대동문 앞→선교)", cls="지선", width_m=4.0, ferry=True, via=[(39.0224, 125.7570), (39.0195, 125.7680)],
         notes="나룻배로 건넘 — 양 끝이 선착장. 길 바닥을 돋우지 않음(물면)."),
    dict(id="junghwa_road", name="중화길(선교→남쪽)", cls="대로", width_m=6.0, from_ferry=("daedong_ferry_route", 1), via=[(39.0080, 125.7690), (38.9900, 125.7720), (38.9640, 125.7800)],
         notes="남쪽 끝 포털: 한양→평양 노정(중화·황주·개성)."),
]

CROSSINGS = [
    dict(id="daedong_ferry", name="대동강 나루(대동문 앞)", type="나루", river="daedonggang", road="daedong_ferry_route", lat=39.0215, lon=125.7600, confidence="추정", notes="나룻배·놀잇배(기생 뱃놀이)."),
    dict(id="botong_bridge", name="보통강 건널목", type="섶다리", river="botonggang", road="gwanseo_daero", lat=39.0280, lon=125.7365, confidence="가설", notes="보통문 앞 — 섶다리/나룻배(가설)."),
]

AXES = [dict(town="평양 내성", center=(39.0280, 125.7500), jinsan=("모란봉(금수산)", 39.0430, 125.7623, "확정"), ansan=("대동강 건너 문수봉", 39.0155, 125.8026, "가설"),
             note="모란봉을 등지고 대동강을 앞에 둔 배산임수. 감영은 남향(가설).")]

PORTALS = [
    dict(id="to_hanyang", name="→ 황주·한양(중화)", road="junghwa_road", to_route="HH_HWANGJU-PA_PYEONGYANG", note="중화 → 황주 → 개성 → 한양"),
    dict(id="to_hamheung", name="→ 함흥(노정)", road="chilseong_road", to_route="PA_PYEONGYANG-HG_HAMHEUNG", note="평양 → (성천·양덕) → 철령/원산 방면 → 함흥(노정)"),
]

SPAWN = dict(lat=39.0222, lon=125.7585, note="대동문 앞 강가(나루)")

PROFILES = {
    "pyeongyang_naeseong": dict(archetype="eupchi", climate="north", roof={"giwa": 0.6, "choga": 0.4}, wall="stone", layout="walled_grid", entrance="gate",
                                people=["감영 관속", "기생", "상인", "양반"], animals=["말"], signature="대동문 문루와 강가 연광정, 뒤로 모란봉 능선", trades=["감영", "시전", "무역"],
                                notes="관서 문화권: 평안도 홑집(一자) + 두꺼운 흙벽, 북부 기후(눈)"),
    "pyeongyang_jongno": dict(archetype="eupchi", climate="north", roof={"giwa": 0.7, "choga": 0.3}, wall="none", layout="linear_street", entrance="awning_stalls",
                              people=["상인", "보부상", "역관"], animals=["말", "소"], signature="종각 앞 시전과 의주 무역 짐바리", trades=["시전", "무역"]),
    "jungseong": dict(archetype="eupchi", climate="north", roof={"choga": 0.7, "giwa": 0.3}, signature="성안 초가 골목과 우물", trades=["수공업"]),
    "oeseong": dict(archetype="plain", climate="north", signature="반듯한 정전(井田) 밭두렁과 농가", trades=["밭농사"], people=["농부"], animals=["소"]),
    "daedong_naru": dict(archetype="river", climate="north", signature="나룻배와 놀잇배, 강 건너 문수봉", trades=["나루", "뱃놀이"], people=["뱃사공", "기생", "나그네"]),
    "seongyo": dict(archetype="river", climate="north", signature="강 건너에서 본 평양성 능선", trades=["나루", "주막"], people=["뱃사공", "주모"]),
    "neungrado": dict(archetype="river", climate="north", signature="강 가운데 버드나무 섬", trades=["뽕밭"], people=["농부"]),
    "yanggakdo": dict(archetype="river", climate="north", signature="강 가운데 모래섬과 걸린 이양선 이야기", trades=["뽕밭", "고기잡이"], people=["농부", "어부"]),
    "yeongmyeongsa_temple": dict(archetype="temple", climate="north", signature="벼랑 위 부벽루와 굴", trades=["절"]),
    "botong_out": dict(archetype="pass", climate="north", signature="보통문 밖 의주길 주막", trades=["주막"], people=["나그네", "보부상"]),
}

META = dict(parent_province="평안도", main_river="대동강", connected_river=["보통강→대동강", "대동강→서해(권역 밖 남서, 남포)"],
            watershed_divide="모란봉–만수대 낮은 구릉(성 안 물은 대동강·보통강으로 갈림)",
            main_mountain=["모란봉(금수산)", "만수대", "대성산(권역 동북)", "문수봉(강 건너)"],
            settlement_type="감영 도읍(평양성 내성·중성·외성·북성) + 대동강 나루·강 건너 마을",
            economy=["시전(서북 무역: 의주·청)", "대동강 수운·뱃놀이", "밭농사(외성 들)", "평양 기생·놀잇배(관광)"],
            forbidden=["현대 평양 시가지·고층 건물", "대동강 갑문·석축 강안", "보통강 직강 운하", "철도·도로", "기념탑·동상"],
            sources=["OpenStreetMap 북한 지도(문루·누정 위치)", "한국민족문화대백과(통설)", "평양성도(회화식 지도) — 원본 대조 대기"])
MAIN_ROAD = "jongno_pyeongyang"
HYDRO_EXTRA = dict(edge_flows=[dict(cond="True", label="권역 밖 — 대동강 수계")])
QA_ALT = [dict(id="daedongmun", lo=3, hi=30), dict(id="eulmildae", lo=40, hi=110)]
ZOOMS = {"zoom_castle_moranbong": [-700, -800, 600, 300], "zoom_daedong_ferry": [-200, -300, 600, 600]}
for _p in PORTALS:
    _p["ref"] = list(next(r for r in ROADS if r["id"] == _p["road"])["via"][-1])

WALLS = {
    "pyeongyang_naeseong_wall": dict(name="평양성 내성·북성", closed=True, height_m=[5.0, 8.0], kit="landmark/pyeongyang_wall",
        gates=["daedongmun", "botongmun", "chilseongmun", "hyeonmumun", "jeongeummun"], confidence="가설",
        source=[SRC_OSM + " — 문루 위치", SRC_MAP], notes="문 사이는 지형(강 벼랑·만수대·모란봉 능선)을 따라 근사(가설). 강 쪽은 대동강 벼랑 위.",
        latlon=[(39.0226, 125.7568), (39.0300, 125.7598), (39.0380, 125.7628), (39.0409, 125.7617), (39.0430, 125.7622), (39.0425, 125.7607),
                (39.0415, 125.7596), (39.0360, 125.7543), (39.0320, 125.7480), (39.0271, 125.7419), (39.0200, 125.7430), (39.0185, 125.7490),
                (39.0195, 125.7555), (39.0226, 125.7568)]),
    "pyeongyang_jungseong_wall": dict(name="평양성 중성", closed=False, height_m=[4.0, 6.0], gates=[], confidence="가설", source=[SRC_MAP],
        notes="내성 남쪽 중성(문 위치 미확인 — 길이 지나는 곳에 문을 두면 됨)",
        latlon=[(39.0200, 125.7430), (39.0120, 125.7430), (39.0110, 125.7520), (39.0150, 125.7568)]),
}
