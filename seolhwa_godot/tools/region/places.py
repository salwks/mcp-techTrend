"""고증 제어점(위경도) — 출처·신뢰도 포함. 신뢰도: 확정/추정/가설 (계획서 §1.3, §3).
좌표 출처 표기: OSM = OpenStreetMap(Nominatim/Overpass, 2026-10 조회, 현대 지도 위치),
WIKI-KO = 한국어 위키백과, EKC = 한국민족문화대백과사전(encykorea.aks.ac.kr)."""

SRC_OSM = "OpenStreetMap (Nominatim/Overpass, 2026-10 조회)"
SRC_WIKI_EUPSEONG = "위키백과 '남원읍성' (좌표 35°24′46.6″N 127°23′4.2″E, 동충동 464-1 — 북성벽 잔존부)"
SRC_EKC_YONGSEONG = "한국민족문화대백과 '남원용성초등학교'(E0012066): 1907년 객사 용성관으로 이전, 현 교지가 용성관 터"
SRC_EKC_YEOWON = "한국민족문화대백과 '여원치 마애불'(E0067255): 이백면 양가리 여원치, 남원·운봉·함양을 잇던 길"
SRC_OHMY = "오마이뉴스 '철로에 묻힌 남원성 북문'(1935 전라선 개설로 북문·서문 철거, 구 남원역 자리)"
SRC_TOUR = "한국관광공사 '황산대첩비지'(운봉읍 가산화수길 84)"

# 남원읍성: 둘레 약 2.5km 평지 방형 읍성(위키). 북문 = 구 남원역(35.4134,127.3822) 부근(오마이뉴스),
# 북성벽 잔존 좌표(위키, 동북쪽), 객사 용성관(용성초)이 성 안 서쪽 → 한 변 ≈620m 정방형으로 추정.
EUP_N, EUP_S = 35.4128, 35.4072
EUP_W, EUP_E = 127.3780, 127.3848
EUP_C = ((EUP_N + EUP_S) / 2, (EUP_W + EUP_E) / 2)

LANDMARKS = [
    dict(id="namwon_eupseong", name="남원읍성", kit="landmark/namwon_eupseong", lat=EUP_C[0], lon=EUP_C[1], ry=0,
         confidence="추정", source=[SRC_WIKI_EUPSEONG, SRC_OHMY, SRC_EKC_YONGSEONG],
         notes="평지 방형 읍성, 실제 한 변 ≈620m(둘레 2.5km) → 압축 땅에서 한 변 ≈186m(게임). 성벽 높이 ≈4m·성문은 실물 크기, 둘레만 압축. 4문: 남 완월루·북 공신루·서 망미루·동 향일루. 1870년엔 성벽·4문 모두 있음(북·서문 철거는 1935).",
         size_m=[186, 186]),
    dict(id="namwon_south_gate", name="남원읍성 남문(완월루)", kit="landmark/eupseong_gate_wanwollu", lat=EUP_S, lon=EUP_C[1], ry=0,
         confidence="추정", source=[SRC_WIKI_EUPSEONG], notes="홍예문 + 문루(2층 누각). 실물 크기 약 14×9m, 성벽과 이어짐.", size_m=[16, 10]),
    dict(id="namwon_north_gate", name="남원읍성 북문(공신루) 터", kit="landmark/eupseong_gate", lat=EUP_N, lon=EUP_C[1], ry=180,
         confidence="추정", source=[SRC_OHMY], notes="구 남원역 부근. 북면은 카메라 반대편이라 단순하게.", size_m=[14, 9]),
    dict(id="namwon_east_gate", name="남원읍성 동문(향일루)", kit="landmark/eupseong_gate", lat=EUP_C[0], lon=EUP_E, ry=90,
         confidence="가설", source=[SRC_WIKI_EUPSEONG], notes="동벽 중앙으로 가정. 운봉 가는 길의 출발점.", size_m=[14, 9]),
    dict(id="namwon_west_gate", name="남원읍성 서문(망미루)", kit="landmark/eupseong_gate", lat=EUP_C[0], lon=EUP_W, ry=-90,
         confidence="가설", source=[SRC_WIKI_EUPSEONG], notes="서벽 중앙으로 가정.", size_m=[14, 9]),
    dict(id="yongseonggwan", name="용성관(남원 객사)", kit="landmark/namwon_gaeksa_yongseonggwan", lat=35.40984, lon=127.37984, ry=0,
         confidence="추정", source=[SRC_EKC_YONGSEONG, SRC_OSM + " — 남원용성초등학교 위치"],
         notes="정청+좌우 익헌, 남향. 실물 약 50×15m, 담·삼문 포함 약 72×40m(성 중심축 T자 끝). 현재 돌층계·축대만 남음.", size_m=[72, 40]),
    dict(id="namwon_dongheon", name="남원도호부 관아(동헌)", kit="landmark/namwon_gwana", lat=35.4108, lon=127.3830, ry=0,
         confidence="가설", source=["위치 근거 없음 — 읍성 안 객사 동쪽에 두는 일반 배치(가설)", "OSM 도로명 '동헌길'(죽항동, 35.4077~35.4079 N, 127.380~127.387 E) — 성 안 남쪽(게임 z≈315)에 동헌이 있었을 가능성(검수 필요)"],
         notes="동헌·내아·삼문. 약 50×40m.", size_m=[50, 40]),
    dict(id="gwanghallu", name="광한루", kit="landmark/gwanghallu", lat=35.40393, lon=127.37980, ry=0,
         confidence="확정", source=[SRC_OSM + " — 광한루 건물", "Nominatim 광한루원 35.40280,127.37954"],
         notes="정면 5칸 누각(보물→국보), 실물 약 18×11m. 앞 연못·오작교·삼신산 섬(광한루원). 현재 정원 넓이는 1960~70년대 확장분 포함 — 1870년 정원은 더 작게(가설).", size_m=[18, 11]),
    dict(id="ojakgyo", name="오작교(광한루원)", kit="landmark/gwanghallu_ojakgyo", lat=35.40365, lon=127.37936, ry=0,
         confidence="확정", source=[SRC_OSM + " — 오작교"], notes="4홍예 돌다리 약 58m(실물) — 연못 위. 압축하지 않으면 정원보다 커질 수 있어 총괄 판단 필요.", size_m=[58, 3]),
    dict(id="yeowonchi_maaebul", name="여원치 마애불", kit="landmark/maaebul_rock", lat=35.4458, lon=127.4985, ry=-60,
         confidence="가설", source=[SRC_EKC_YEOWON], notes="고개 정상 조금 못 미친 서쪽(이백 쪽) 길가 암벽, 불상 높이 2.5m. 정확한 좌표 미확인.", size_m=[6, 4]),
    dict(id="unbong_gwana", name="운봉현 관아", kit="landmark/hyeon_gwana", lat=35.4405, lon=127.5329, ry=0,
         confidence="가설", source=[SRC_OSM + " — 운봉초등학교·운봉읍 행정복지센터 부근(옛 읍치 중심으로 추정)"],
         notes="현(縣) 관아: 동헌·객사·작청. 규모 약 40×35m.", size_m=[40, 35]),
    dict(id="hwangsan_daecheopbi", name="황산대첩비(비각)", kit="landmark/bigak_daecheopbi", lat=35.45806, lon=127.56139, ry=0,
         confidence="확정", source=[SRC_OSM + " — 황산대첩비 attraction", SRC_TOUR],
         notes="1577년 건립 비와 비각(1870년엔 원비가 서 있음; 1945년 일제 파괴·1957 재건은 이후 일). 비각 약 6×6m + 담장 약 20×20m.", size_m=[20, 20]),
    dict(id="silsangsa", name="실상사", kit="landmark/silsangsa", lat=35.41700, lon=127.63530, ry=0,
         confidence="확정", source=[SRC_OSM + " — 실상사(입석리)", "영문 위키 'Silsangsa': 산이 아닌 들판에 자리한 절"],
         notes="평지 가람: 보광전·약사전·동서 삼층석탑·석등. 경내 약 120×100m(실물). 1870년 무렵 건물 규모는 가설(1882년 화재설 등 검수 필요).", size_m=[120, 100]),
]

SETTLEMENTS = [
    dict(id="namwon_eup", name="남원 읍내(읍성)", type="읍성", lat=EUP_C[0], lon=EUP_C[1], radius_m=130, size="L",
         confidence="추정", source=[SRC_WIKI_EUPSEONG], notes="남원도호부 읍치. 성 안 관아·객사, 성 밖 남쪽 광한루·장터."),
    dict(id="namwon_jang", name="남원 장(남문 밖 장터)", type="장시", lat=35.4062, lon=127.3790, radius_m=40, size="M",
         confidence="가설", source=["남문 밖 장터 일반 배치(가설); 현 시장사거리(OSM 35.4065,127.3764) 참고", "현대 남원장 4·9일(전북일보 등) — 조선 후기 장날은 미확인"], notes="장날 현대 4·9일. 18세기 이후 대부분 5일장(통설)."),
    dict(id="namwon_hyanggyo", name="남원향교", type="마을", lat=35.4190, lon=127.3830, radius_m=30, size="S",
         confidence="추정", source=[SRC_OSM + " — 향교동(35.4181,127.3822)", "위키백과 '남원향교 대성전': 향교동 1512, 35.42194N 127.38306E(게임 −3183,−147). 1410 대곡산 → 1428 덕음봉 아래 → 1443 현 위치(1870년에도 이 자리, 1892 중수)"],
         notes="실제 대성전 좌표는 게임 (−3183,−147). 배치 자리(−3247.3,−97.8)와 약 80m 차이 — 총괄 판단 대기."),
    dict(id="ibaek", name="이백 마을", type="마을", lat=35.4295, lon=127.4517, radius_m=50, size="M",
         confidence="추정", source=[SRC_OSM + " — 이백면"], notes="남원→여원재 길가 들마을."),
    dict(id="yeowon_jumak", name="여원재 아랫주막", type="주막", lat=35.4440, lon=127.4930, radius_m=15, size="S",
         confidence="가설", source=["고갯길 주막 일반 배치(가설)"], notes="여원재 서쪽 오르막 시작점."),
    dict(id="yeowon_seonghwang", name="여원재 성황당", type="성황당", lat=35.4470, lon=127.5013, radius_m=6, size="S",
         confidence="가설", source=[SRC_OSM + " — 여원재", "고개 성황당 일반 배치(가설)"], notes="고개 마루 돌무더기·당목."),
    dict(id="unbong_eup", name="운봉 읍치", type="마을", lat=35.4385, lon=127.5310, radius_m=90, size="L",
         confidence="추정", source=[SRC_OSM + " — 운봉읍·운봉초"], notes="운봉현 읍치(고원 분지). 읍성 유무는 검수 필요."),
    dict(id="unbong_jang", name="운봉 장", type="장시", lat=35.4365, lon=127.5300, radius_m=30, size="M",
         confidence="가설", source=["읍치 장시 일반 배치(가설)", "현대 운봉장 1·6일(한국관광공사)"], notes="장날 현대 1·6일."),
    dict(id="bijeon", name="비전 마을(황산 아래)", type="마을", lat=35.4565, lon=127.5605, radius_m=40, size="S",
         confidence="추정", source=[SRC_TOUR, "비전(碑前) = 황산대첩비 앞 마을"], notes="동편제 명창 송흥록 마을로 전함."),
    dict(id="inwol_yeok", name="인월역", type="역", lat=35.4625, lon=127.6000, radius_m=40, size="M",
         confidence="가설", source=[SRC_OSM + " — 인월리·인월전통시장"], notes="역참 위치는 인월 들 안쪽으로 가정. 함양 방면 길 갈림."),
    dict(id="inwol_jang", name="인월 장", type="장시", lat=35.4615, lon=127.6020, radius_m=35, size="M",
         confidence="추정", source=[SRC_OSM + " — 인월전통시장(35.4615,127.6020)", "현대 인월장 3·8일"], notes="지리산 동북 산간 물산 장. 장날 현대 3·8일."),
    dict(id="sannae", name="산내 마을", type="마을", lat=35.4005, lon=127.6164, radius_m=40, size="S",
         confidence="추정", source=[SRC_OSM + " — 산내면"], notes="만수천가 산촌."),
    dict(id="silsangsa_temple", name="실상사", type="사찰", lat=35.41700, lon=127.63530, radius_m=40, size="M",
         confidence="확정", source=[SRC_OSM], notes="들 가운데 평지 사찰."),
    dict(id="banseon", name="반선 마을(뱀사골 어귀)", type="마을", lat=35.3735, lon=127.5800, radius_m=25, size="S",
         confidence="추정", source=[SRC_OSM + " — 반선교(35.3723,127.5792)"], notes="뱀사골·달궁 물이 만나는 계곡 어귀 산촌."),
]

# 고개 (DEM 안장점으로 다시 맞춘다)
PASSES = [
    dict(id="yeowonjae", name="여원재(여원치)", lat=35.4470, lon=127.5013, confidence="확정", source=[SRC_OSM + " — natural=saddle 여원재", SRC_EKC_YEOWON]),
]

SPAWN_NOTE = "남원읍성 남문(완월루) 앞 남쪽 약 25m(게임)"

# 고증 하천 제어점(상류→하류). OSM 현대 하천선을 길잡이로, 흐름 누적이 이 점들을 지나게 강제.
RIVER_CONTROL = {
    "yocheon": dict(name="요천", grade="B", flows_to="섬진강(권역 밖, 남원 서남 금지면)",
                    ctrl=[(35.4810, 127.4668), (35.4568, 127.4342), (35.4330, 127.4140), (35.4190, 127.4045),
                          (35.4060, 127.3870), (35.4020, 127.3800), (35.3980, 127.3700), (35.3807, 127.3412)],
                    source=[SRC_OSM + " — waterway=river 요천", "요천은 장수 번암에서 남원을 지나 섬진강에 듦(통설)"]),
    "ramcheon": dict(name="람천", grade="C", flows_to="임천→엄천강→경호강→남강→낙동강(권역 밖)",
                     ctrl=[(35.4567955, 127.5748094), (35.4116797, 127.6430566)],
                     source=[SRC_OSM + " — waterway 람천", "운봉고원 → 인월 → 산내, 낙동강 수계(백두대간 동쪽)"]),
    "mansucheon": dict(name="만수천", grade="C", flows_to="람천",
                       ctrl=[(35.3711964, 127.5715202), (35.4027627, 127.6093716)],
                       source=[SRC_OSM + " — waterway 만수천", "뱀사골·달궁계곡 물이 반선에서 만나 실상사 앞에서 람천에 듦"]),
}
