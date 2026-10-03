"""data-north 고증 제어점 — GG_HANYANG (한양 도성·한강 나루). 위경도 + 출처·신뢰도(확정/추정/가설).
places.py(남원)와 같은 꼴: LANDMARKS, SETTLEMENTS, PASSES, RIVER_CONTROL + 이 권역만: ROADS(경유 위경도), CROSSINGS, PROFILES, AXES, PORTALS, WALL.
좌표 길잡이는 OSM(현대 위치·복원 위치). 1870년 모습은 원칙(도성 짜임: 좌묘우사·전조후시)과 통설로 정함."""

SRC_OSM = "OpenStreetMap (Overpass, 2026-10 조회)"
SRC_WALL = SRC_OSM + " — barrier=city_wall '서울 한양도성' 구간(멸실 구간은 문·봉우리 사이 직선 보간)"
SRC_EKC = "한국민족문화대백과(통설)"
SRC_DAEDONG = "수선전도(1840년대)·도성도(18세기) 통설 — 원본 대조 대기"

# 성곽 둘레 따라 짚는 기준점(시계 방향, 북악에서). OSM 구간이 있으면 north_wall.py가 그 선을 쓰고, 끊긴 곳은 이 점들을 잇는다.
WALL_KEYPOINTS = [
    ("백악(북악) 마루", 37.5930, 126.9738), ("숙정문", 37.5955, 126.9811), ("말바위", 37.5935, 126.9860),
    ("혜화문", 37.5879, 127.0039), ("낙산", 37.5806, 127.0086), ("흥인지문", 37.5711, 127.0097),
    ("오간수문", 37.5698, 127.0093), ("광희문", 37.5644, 127.0100), ("남소문 터", 37.5501, 126.9998),
    ("목멱산(남산)", 37.5512, 126.9882), ("숭례문", 37.5600, 126.9754), ("소의문 터", 37.5623, 126.9717),
    ("돈의문 터", 37.5683, 126.9688), ("인왕산", 37.5850, 126.9579), ("창의문", 37.5926, 126.9665),
]

GATES = [  # (id, 이름, 위도, 경도, 종류, 1870 상태)
    ("sungnyemun", "숭례문(남대문)", 37.5600, 126.9754, "대문", "도성 정문. 2층 문루, 홍예. 1870년 현존"),
    ("heunginjimun", "흥인지문(동대문)", 37.5711, 127.0097, "대문", "옹성 둘린 유일한 대문(1869 고종 6년 개축 직후)"),
    ("donuimun", "돈의문(서대문, 새문)", 37.5683, 126.9688, "대문", "1870년 현존(1915 철거). 의주로 출발점"),
    ("sukjeongmun", "숙정문(북대문)", 37.5955, 126.9811, "대문", "평소 닫아 둠(풍수·음기 통설). 북악 동쪽 능선"),
    ("hyehwamun", "혜화문(동소문)", 37.5879, 127.0039, "소문", "북쪽(경흥대로·관북) 길"),
    ("gwanghuimun", "광희문(시구문)", 37.5644, 127.0100, "소문", "도성 밖 상여가 나가던 문 — 한강진 방면"),
    ("changuimun", "창의문(자하문)", 37.5926, 126.9665, "소문", "인왕·북악 사이 고개, 세검정 쪽"),
    ("souimun", "소의문(서소문)", 37.5623, 126.9717, "소문", "1870년 현존(1914 철거). 문 밖 처형터"),
]

LANDMARKS = [
    dict(id="hanyang_doseong", name="한양도성", kit="landmark/hanyang_wall", lat=37.5700, lon=126.9880, ry=0, confidence="확정",
         source=[SRC_WALL, SRC_EKC], size_m=None,
         notes="둘레 약 18.6km(실제) 산 능선 성곽 — 북악·낙산·남산·인왕 능선을 따름. 압축 후 둘레 ≈9.3km(게임, K=0.5). 선은 region.json wall(폴리라인)에. 성벽 높이·두께는 실물(평지 약 6m, 산 능선 약 4m)."),
    dict(id="gyeongbokgung", name="경복궁(1868 중건)", kit="landmark/gyeongbokgung", lat=37.5788, lon=126.9770, ry=0, confidence="확정",
         source=[SRC_OSM + " — 근정전 37.5785,126.9770 / 광화문 37.5759,126.9768", SRC_EKC + " '경복궁 중건'(1865~1868)"],
         notes="법궁. 광화문–흥례문–근정문–근정전–사정전–강녕전–교태전 남북 축, 서쪽 경회루. 1870년엔 막 중건된 새 궁(단청 선명). 건청궁·향원정은 1873년 이후라 넣지 않음. 실물 약 500×700m → 압축 땅에서 약 250×350m 경역, 전각은 실물 크기.",
         size_m=[250, 350]),
    dict(id="gwanghwamun", name="광화문", kit="landmark/palace_gate_gwanghwamun", lat=37.5759, lon=126.9768, ry=0, confidence="확정",
         source=[SRC_OSM], notes="3홍예 석축 + 2층 문루, 앞에 해태 한 쌍. 정남향, 육조거리 북쪽 끝.", size_m=[35, 16]),
    dict(id="changdeokgung", name="창덕궁·창경궁(동궐)", kit="landmark/changdeokgung", lat=37.5810, lon=126.9925, ry=0, confidence="확정",
         source=[SRC_OSM + " — 돈화문 37.5779,126.9900 / 인정전 37.5822,126.9918 / 창경궁 홍화문 37.5789,126.9964"],
         notes="이궁. 돈화문(정문, 서남 모서리) — 금천교 — 인정전, 지형 따라 비스듬한 배치. 뒤쪽 후원(금원). 경역 압축 약 220×200m.", size_m=[220, 200]),
    dict(id="jongmyo", name="종묘", kit="landmark/jongmyo", lat=37.5749, lon=126.9940, ry=0, confidence="확정",
         source=[SRC_OSM + " — 정전 37.5749,126.9940 / 외대문 37.5721,126.9946"], notes="좌묘(궁 동쪽). 정전 19칸 긴 맞배, 영녕전. 숲에 둘림. 경역 압축 약 120×150m.", size_m=[120, 150]),
    dict(id="sajikdan", name="사직단", kit="landmark/sajikdan", lat=37.5757, lon=126.9673, ry=0, confidence="확정",
         source=[SRC_OSM + " — 사직단 37.5757,126.9677"], notes="우사(궁 서쪽). 사단·직단 두 네모 단 + 낮은 담·홍살문.", size_m=[45, 45]),
    dict(id="unhyeongung", name="운현궁(흥선대원군 사저)", kit="landmark/unhyeongung", lat=37.5762, lon=126.9871, ry=0, confidence="확정",
         source=[SRC_OSM + " — 노안당·노락당 37.576,126.987"], notes="1870년 대원군 집권기 권력의 중심. 노안당·노락당·이로당. 큰 기와 사저.", size_m=[70, 60]),
    dict(id="bosingak", name="종루(보신각)", kit="landmark/jongnu_bell", lat=37.5698, lon=126.9834, ry=0, confidence="확정",
         source=[SRC_OSM + " — 보신각 37.5698,126.9834"], notes="운종가 한가운데 종각. 인정·파루에 종 침. 1870년 단층 종각(2층 누각은 1979 복원 모습 — 쓰지 않음, 가설).", size_m=[12, 10]),
    dict(id="gwangtonggyo", name="광통교(광교)", kit="landmark/stone_bridge_gwangtong", lat=37.5687, lon=126.9829, ry=0, confidence="추정",
         source=[SRC_OSM + " — 광통교 원위치 표석 37.5685,126.9829 (현 복원 다리는 상류 155m)"], notes="도성 제일 큰 돌다리(길이 약 12m, 폭 15m). 남대문로가 개천을 건너는 곳. 다리밟기 명소.", size_m=[15, 13]),
    dict(id="supyogyo", name="수표교와 수표", kit="landmark/stone_bridge_supyo", lat=37.5683, lon=126.9905, ry=0, confidence="추정",
         source=[SRC_OSM + " — 수표교 상점명·옛터 37.5682,126.9902 (다리는 1959 장충단으로 옮김)"], notes="돌기둥 다리(길이 약 27m) + 개천 물높이 재는 수표석.", size_m=[27, 8]),
    dict(id="ogansumun", name="오간수문", kit="landmark/wall_water_gate", lat=37.5698, lon=127.0093, ry=90, confidence="확정",
         source=[SRC_OSM], notes="개천이 성 밖으로 나가는 다섯 칸 홍예 수문(쇠살). 성벽에 붙음.", size_m=[25, 8]),
    dict(id="yukjo", name="육조거리 관아(의정부·육조)", kit="landmark/yukjo_offices", lat=37.5735, lon=126.9768, ry=0, confidence="추정",
         source=[SRC_OSM + " — 의정부지 37.5750,126.9779", SRC_DAEDONG], notes="광화문 앞 너른 길 양쪽 관청 줄(동쪽 의정부·이조·한성부·호조, 서쪽 예조·중추부·사헌부·병조·형조·공조). 길 폭 실제 약 55m.", size_m=[120, 330]),
    dict(id="seonggyungwan", name="성균관·문묘", kit="landmark/seonggyungwan", lat=37.5868, lon=126.9985, ry=0, confidence="확정",
         source=[SRC_OSM + " — 성균관 37.5856,126.9959 / 하마비 37.5848,126.9968"], notes="대성전·명륜당, 은행나무. 혜화문 안 서쪽 반촌.", size_m=[90, 110]),
    dict(id="gyeonghuigung_site", name="경희궁(서궐) — 헐린 궁", kit="landmark/palace_ruin", lat=37.5709, lon=126.9681, ry=0, confidence="추정",
         source=[SRC_OSM + " — 경희궁 37.5709,126.9681", SRC_EKC + " — 경복궁 중건 때 전각 대부분 헐어 목재로 씀"], notes="1870년엔 숭정전 등 일부만 남은 쓸쓸한 궁(가설: 남은 전각 수). 흥화문은 남아 있음.", size_m=[120, 100]),
    dict(id="mokmyeok_bongsu", name="목멱산 봉수대", kit="landmark/bongsudae", lat=37.5512, lon=126.9880, ry=0, confidence="추정",
         source=[SRC_OSM + " — 남산봉수대 37.5521,126.9876(복원)"], notes="전국 봉수가 모이는 다섯 봉수. 밤에 불(평시 하나).", size_m=[25, 10]),
    dict(id="mohwagwan", name="모화관·영은문", kit="landmark/mohwagwan", lat=37.5723, lon=126.9596, ry=0, confidence="확정",
         source=[SRC_OSM + " — 영은문 주초 37.5723,126.9596"], notes="돈의문 밖 의주로 — 사신 맞이 관과 영은문(1896 헐림, 1870 현존).", size_m=[50, 35]),
    dict(id="donggwanwangmyo", name="동관왕묘(동묘)", kit="landmark/gwanwangmyo", lat=37.5730, lon=127.0183, ry=0, confidence="확정",
         source=[SRC_OSM + " — 동묘 37.5730,127.0183"], notes="흥인지문 밖 관우 사당(1601). 벽돌 정전.", size_m=[50, 70]),
    dict(id="podocheong_left", name="좌포도청", kit="landmark/podocheong", lat=37.5712, lon=126.9925, ry=0, confidence="추정",
         source=[SRC_EKC + " '포도청' — 좌포청: 파자교 동북(현 종로3가 단성사 자리)"], notes="치안 관청 — 포교·포졸, 옥. 도시괴담·야담 사건의 출발점.", size_m=[45, 35]),
    dict(id="podocheong_right", name="우포도청", kit="landmark/podocheong", lat=37.5703, lon=126.9790, ry=0, confidence="추정",
         source=[SRC_EKC + " '포도청' — 우포청: 혜정교 남쪽(현 광화문우체국 부근)"], notes="", size_m=[45, 35]),
    dict(id="salgoji_bridge", name="살곶이다리(전곶교)", kit="landmark/stone_bridge_salgoji", lat=37.5533, lon=127.0465, ry=1.57, confidence="확정",
         source=[SRC_OSM + " — 살곶이다리 37.5533,127.0465", SRC_EKC], notes="조선에서 가장 긴 돌다리(1483, 약 76m) — 중랑천을 건너 광나루·송파로. 권역 동쪽 끝(포털 자리), 중랑천은 가장자리에 걸침.", size_m=[76, 6], nopad=True),
    dict(id="seobinggo", name="서빙고(얼음 창고)", kit="landmark/binggo", lat=37.5205, lon=126.9909, ry=0, confidence="추정",
         source=[SRC_OSM + " — 서빙고터 37.5205,126.9909"], notes="한강 얼음을 떠 저장하는 나라 빙고(8동). 겨울 채빙 장면.", size_m=[60, 40]),
    dict(id="saenamteo", name="새남터(노량 모래톱)", kit="landmark/sand_drill_ground", lat=37.5249, lon=126.9569, ry=0, confidence="추정",
         source=[SRC_OSM + " — 새남터 기념성당 37.5249,126.9569"], notes="한강 가 모래톱 군사 조련장·처형터(1866 병인박해). 무거운 장소 — 사건 연출은 총괄 판단.", size_m=[80, 50]),
]
for gid, nm, la, lo, kind, note in GATES:
    LANDMARKS.append(dict(id=gid, name=nm, kit=("landmark/hanyang_gate_great" if kind == "대문" else "landmark/hanyang_gate_small"), lat=la, lon=lo, ry=0,
                          confidence=("추정" if "터" in nm or gid in ("donuimun", "souimun") else "확정"), source=[SRC_OSM, SRC_EKC],
                          notes=f"{kind}. {note}", size_m=([30, 14] if kind == "대문" else [18, 10])))

SETTLEMENTS = [
    dict(id="hanyang_doseong_in", name="한양 도성 안", type="읍성", lat=37.5697, lon=126.9880, radius_m=900, size="XL", confidence="확정",
         source=[SRC_WALL], notes="도읍. 성 안 인구 약 20만(통설). 구역 profile로 나눔: 북촌·중촌(개천)·운종가·남촌·궁궐."),
    dict(id="bukchon", name="북촌(경복궁·창덕궁 사이)", type="마을", lat=37.5815, lon=126.9855, radius_m=180, size="L", confidence="추정",
         source=[SRC_DAEDONG], notes="권문세가 큰 기와집, 언덕 골목. 운현궁 아래."),
    dict(id="ungjongga", name="운종가(종로 시전 행랑)", type="장시", lat=37.5702, lon=126.9860, radius_m=150, size="L", confidence="확정",
         source=[SRC_OSM + " — 육의전 터 37.5704,126.9884", SRC_EKC], notes="육의전 등 시전 행랑이 길 양쪽 줄. 뒤로 피맛골(말 피하는 뒷골목)."),
    dict(id="jungchon", name="중촌(개천 가)", type="마을", lat=37.5676, lon=126.9945, radius_m=150, size="L", confidence="추정",
         source=[SRC_DAEDONG], notes="역관·의관 등 중인과 장인 동네. 개천(청계천) 다리들."),
    dict(id="namchon", name="남촌(남산골)", type="마을", lat=37.5605, lon=126.9925, radius_m=170, size="L", confidence="추정",
         source=[SRC_DAEDONG], notes="가난한 선비(남산골 샌님)·무반. 남산 북쪽 기슭 작은 기와·초가."),
    dict(id="baeogae_jang", name="배오개 장(이현)", type="장시", lat=37.5705, lon=126.9990, radius_m=50, size="M", confidence="추정",
         source=[SRC_EKC + " '이현시장'"], notes="동대문 안 난전 — 채소·곡식."),
    dict(id="chilpae_jang", name="칠패 장(남대문 밖)", type="장시", lat=37.5585, lon=126.9718, radius_m=50, size="M", confidence="추정",
         source=[SRC_EKC + " '칠패시장'"], notes="숭례문 밖 어물 난전 — 마포·용산에서 올라온 생선."),
    dict(id="wangsimni", name="왕십리 채마밭 마을", type="마을", lat=37.5632, lon=127.0310, radius_m=70, size="M", confidence="추정",
         source=["왕십리 미나리·채소(통설)"], notes="동대문 밖 채소 농사 마을 — 도성에 채소 댐."),
    dict(id="mapo", name="마포 나루(삼개)", type="마을", lat=37.5370, lon=126.9440, radius_m=90, size="M", confidence="추정",
         source=[SRC_OSM + " — 마포 일대", SRC_EKC + " '마포'"], notes="서해 배가 올라오는 경강 포구 — 소금·새우젓 객주, 창고."),
    dict(id="yongsan", name="용산 나루(용산강)", type="마을", lat=37.5285, lon=126.9530, radius_m=80, size="M", confidence="추정",
         source=[SRC_EKC + " '용산강'"], notes="세곡선 닿는 강창(군자감 강감), 객주."),
    dict(id="noryangjin", name="노량진 나루(노들)", type="원", lat=37.5150, lon=126.9545, radius_m=60, size="M", confidence="추정",
         source=[SRC_OSM + " — 노량진 37.5142,126.9420(현 역), 한강대교 남단", SRC_EKC + " '노량진'"], notes="한강 남쪽 나루 — 삼남대로(과천·수원) 길목. 1795 정조 배다리 자리."),
    dict(id="hangangjin", name="한강진 나루(한남)", type="원", lat=37.5290, lon=127.0080, radius_m=60, size="M", confidence="추정",
         source=[SRC_EKC + " '한강진'"], notes="광희문에서 버티고개 넘어 닿는 나루 — 건너 사평(신사)으로 영남·광주 길."),
    dict(id="seobinggo_village", name="서빙고 마을", type="마을", lat=37.5215, lon=126.9880, radius_m=50, size="S", confidence="추정",
         source=[SRC_OSM + " — 서빙고터"], notes="얼음 뜨는 빙부 마을."),
]

PASSES = [
    dict(id="muakjae", name="무악재", lat=37.5800, lon=126.9530, confidence="추정", source=[SRC_OSM + " — 무악재 하늘다리 37.5787,126.9538"], notes="의주대로 첫 고개(인왕–안산 사이). 호랑이 출몰 전설."),
    dict(id="jahamun_pass", name="자하문 고개(창의문)", lat=37.5926, lon=126.9665, confidence="확정", source=[SRC_OSM], notes="인왕–북악 안부."),
    dict(id="beotigogae", name="버티고개", lat=37.5480, lon=127.0080, confidence="추정", source=["약수동–한남동 고개(통설: 도둑 많던 고개)"], notes="광희문→한강진 길 남산 동쪽 고개. 길목 이벤트 자리."),
]

# 하천: grade 고정. width_real_m = 실제 1870 추정 폭(게임 폭 = ×K)
RIVER_CONTROL = {
    "hangang": dict(name="한강(경강)", grade="S", water_alt_max=6.2, flows_to="서해(권역 밖, 양화진·김포)",
                    ctrl=[(37.5420, 127.0480), (37.5359, 127.0214), (37.5267, 127.0133), (37.5160, 126.9960), (37.5102, 126.9815),
                          (37.5130, 126.9700), (37.5179, 126.9589), (37.5271, 126.9459), (37.5335, 126.9363)],
                    source=[SRC_OSM + " — waterway=river 한강 중심선", "1870 물길: 현대 정비(1980년대 한강종합개발) 전 — 너비 줄이고 모래톱 남김(가설)"],
                    notes="현대 강폭(약 1km)보다 좁게. 노들섬 자리는 모래톱(가설), 이촌·반포 쪽은 넓은 모래벌."),
    "cheonggyecheon": dict(name="개천(청계천)", grade="C", width_real_m=20, flows_to="권역 밖 — 중랑천→한강", carve=True,
                           ctrl=[(37.5800, 126.9690), (37.5735, 126.9748), (37.5691, 126.9786), (37.5686, 126.9829), (37.5682, 126.9905),
                                 (37.5687, 127.0000), (37.5696, 127.0093), (37.5670, 127.0200), (37.5640, 127.0300), (37.5615, 127.0420)], osm_names=["청계천"],
                           source=[SRC_OSM + " — waterway=river 청계천(복원 물길)", SRC_EKC + " '개천'(1760 영조 준천)"],
                           notes="도성 가운데를 서→동으로 흐르는 돌축대 개천. 1870년엔 준천 후 석축, 비 오면 물 불음."),
    "jungnangcheon": dict(name="중랑천", grade="B", width_real_m=40, flows_to="한강",
                          ctrl=[(37.6000, 127.0480), (37.5800, 127.0470), (37.5615, 127.0440), (37.5480, 127.0400), (37.5420, 127.0380)], osm_names=["중랑천"],
                          source=[SRC_OSM + " — 중랑천"], notes="동쪽 가장자리 — 살곶이다리 아래로 한강에 듦."),
    "manchocheon": dict(name="만초천(욱천)", grade="C", carve=True, width_real_m=8, flows_to="한강(용산 나루 앞)",
                        ctrl=[(37.5730, 126.9600), (37.5640, 126.9665), (37.5560, 126.9700), (37.5450, 126.9700), (37.5365, 126.9685),
                              (37.5330, 126.9600), (37.5290, 126.9545)],
                        source=["만초천: 무악재→서대문 밖→청파→용산으로 한강에 듦(통설, 현재 복개)", SRC_OSM + " — 욱천고가 37.535,126.969"],
                        notes="도성 서쪽 성 밖 내 — 현재 복개. 물길은 DEM 골짜기를 따름(가설)."),
    "baegundongcheon": dict(name="백운동천", grade="D", width_real_m=4, flows_to="개천",
                            ctrl=[(37.5880, 126.9650), (37.5800, 126.9690)], source=["인왕 백운동 물 — 개천 첫 물(통설)"], notes=""),
    "junghakcheon": dict(name="중학천(삼청동천)", grade="D", width_real_m=4, flows_to="개천",
                         ctrl=[(37.5895, 126.9796), (37.5800, 126.9800), (37.5700, 126.9800)], source=[SRC_OSM + " — 중학천"], notes="경복궁 동쪽으로 흘러 개천에 듦."),
    "bugyeongcheon": dict(name="북영천(창덕궁 금천)", grade="D", width_real_m=4, flows_to="개천",
                          ctrl=[(37.5860, 126.9930), (37.5800, 126.9922), (37.5745, 126.9917), (37.5712, 126.9916), (37.5684, 126.9915)], osm_names=["북영천"],
                          source=[SRC_OSM + " — 북영천", "창덕궁 금천교 물 → 파자교로 종로를 건너 개천에 듦(통설)"], notes="종로를 파자교로 건넘"),
    "namsan_stream": dict(name="남산골 물(남산동천)", grade="D", width_real_m=3, flows_to="개천",
                          ctrl=[(37.5560, 126.9900), (37.5610, 126.9905), (37.5680, 126.9905)], source=["가설: 남산 북사면 골"], notes=""),
}

# 길: 경유 위경도(고정 앞부분) — 그 사이는 A*. class·width_m(실물)
ROADS = [
    dict(id="yukjo_geori", name="육조거리(광화문 앞길)", cls="대로", width_m=30.0, via=[(37.5757, 126.9768), (37.5707, 126.9769)], astar=False,
         notes="실제 폭 약 55m. 게임은 30m(가설) — 광장 느낌."),
    dict(id="unjongga", name="운종가(종로)", cls="대로", width_m=15.0, via=[(37.5707, 126.9769), (37.5700, 126.9834), (37.5705, 126.9985), (37.5711, 127.0080)], astar=False,
         notes="황토현→종루→배오개→흥인지문."),
    dict(id="namdaemunro", name="남대문로(종루→숭례문)", cls="대로", width_m=12.0, via=[(37.5698, 126.9834), (37.5687, 126.9829), (37.5640, 126.9800), (37.5605, 126.9758)], astar=False),
    dict(id="seomun_ro", name="새문안길(황토현→돈의문→모화관→무악재)", cls="대로", width_m=10.0,
         via=[(37.5707, 126.9769), (37.5690, 126.9700), (37.5683, 126.9688), (37.5723, 126.9596), (37.5800, 126.9530), (37.5845, 126.9440)],
         notes="의주대로 시작 — 서북 끝 포털: 한양→평양 노정(개성·황주)."),
    dict(id="samnam_daero", name="삼남대로(숭례문→청파→노량진)", cls="대로", width_m=8.0,
         via=[(37.5595, 126.9754), (37.5585, 126.9718), (37.5455, 126.9690), (37.5300, 126.9620)], to_ferry=("noryang_ferry", 0),
         notes="숭례문→청파→노량진 나루 북쪽 선착장."),
    dict(id="noryang_ferry", name="노량진 나룻배 뱃길", cls="지선", width_m=4.0, ferry=True, via=[(37.5260, 126.9600), (37.5110, 126.9560)], notes="한강 나룻배(관선·사선) — 양 끝 선착장."),
    dict(id="samnam_south", name="삼남대로(노량진→과천 방면)", cls="대로", width_m=8.0, from_ferry=("noryang_ferry", 1), via=[(37.5082, 126.9490)],
         notes="남쪽 끝 포털: 남원↔한양 노정(과천·수원·천안삼거리·공주)."),
    dict(id="mapo_road", name="마포길(숭례문→아현→마포)", cls="지선", width_m=5.0, via=[(37.5595, 126.9750), (37.5570, 126.9580), (37.5480, 126.9520), (37.5370, 126.9440)]),
    dict(id="yongsan_road", name="용산길(청파→용산 나루)", cls="지선", width_m=5.0, via=[(37.5455, 126.9690), (37.5380, 126.9620), (37.5285, 126.9530)]),
    dict(id="dongdaemun_out", name="동대문 밖 길(왕십리→살곶이)", cls="대로", width_m=8.0, via=[(37.5711, 127.0080), (37.5711, 127.0105), (37.5725, 127.0180), (37.5650, 127.0260), (37.5570, 127.0400), (37.5535, 127.0455)],
         notes="동쪽 끝 포털: 한양→경주 노정(살곶이다리·송파 나루·광주)."),
    dict(id="gwanghuimun_lane", name="광희문길(배오개→광희문)", cls="지선", width_m=5.0, via=[(37.5705, 126.9985), (37.5665, 127.0040), (37.5644, 127.0095)]),
    dict(id="hangangjin_road", name="한강진길(광희문→버티고개→한강진)", cls="대로", width_m=6.0,
         via=[(37.5644, 127.0095), (37.5644, 127.0112), (37.5600, 127.0125), (37.5540, 127.0115), (37.5480, 127.0085)], to_ferry=("hangangjin_ferry", 0),
         notes="광희문→버티고개→한강진 나루."),
    dict(id="hangangjin_ferry", name="한강진 나룻배 뱃길", cls="지선", width_m=4.0, ferry=True, via=[(37.5310, 127.0090), (37.5160, 127.0170)], notes="한강진↔사평나루."),
    dict(id="sapyeong_road", name="사평길(한강진 건너 남동)", cls="대로", width_m=6.0, from_ferry=("hangangjin_ferry", 1), via=[(37.5085, 127.0250)],
         notes="남동 끝 포털: 영남대로 판교 방면(한양→경주 노정 갈래)."),
    dict(id="hyehwamun_out", name="동소문길(혜화문→경흥대로)", cls="대로", width_m=6.0, via=[(37.5705, 126.9990), (37.5800, 127.0020), (37.5879, 127.0039), (37.5960, 127.0150), (37.6003, 127.0230)],
         notes="북동 끝 포털: 경흥대로(의정부·철원·철령 → 함흥)."),
    dict(id="donhwamun_ro", name="돈화문로", cls="지선", width_m=8.0, via=[(37.5779, 126.9900), (37.5703, 126.9903)], astar=False),
    dict(id="bukchon_ro", name="북촌길(광화문 동쪽→돈화문)", cls="지선", width_m=6.0, via=[(37.5761, 126.9794), (37.5765, 126.9850), (37.5779, 126.9900)]),
    dict(id="gaecheon_lane", name="개천 남쪽 길(광통교→수표교→오간수문)", cls="마을길", width_m=4.0, via=[(37.5684, 126.9829), (37.5679, 126.9905), (37.5690, 127.0000), (37.5694, 127.0085)]),
    dict(id="namchon_lane", name="남산골 길(남대문로→남촌→남소문 터)", cls="마을길", width_m=3.5, via=[(37.5640, 126.9800), (37.5610, 126.9900), (37.5560, 126.9980)]),
    dict(id="seonggyungwan_lane", name="반촌길(종로→성균관)", cls="마을길", width_m=4.0, via=[(37.5705, 126.9990), (37.5800, 127.0000), (37.5860, 126.9985)]),
    dict(id="sajik_lane", name="사직단길", cls="마을길", width_m=4.0, via=[(37.5707, 126.9769), (37.5740, 126.9720), (37.5757, 126.9690)]),
    dict(id="changuimun_road", name="자하문길(경복궁 서쪽→창의문)", cls="지선", width_m=4.0, via=[(37.5740, 126.9720), (37.5790, 126.9748), (37.5850, 126.9712), (37.5926, 126.9665), (37.6003, 126.9640)],
         notes="세검정 쪽 북쪽 끝으로 나감(포털 없음, 산길)."),
    dict(id="namsan_trail", name="목멱산 봉수길", cls="산길", width_m=1.5, via=[(37.5610, 126.9900), (37.5560, 126.9880), (37.5512, 126.9880)]),
    dict(id="seobinggo_road", name="서빙고길(용산→서빙고→한강진)", cls="지선", width_m=4.0, via=[(37.5285, 126.9530), (37.5240, 126.9750), (37.5215, 126.9880), (37.5295, 127.0080)]),
]

CROSSINGS = [
    dict(id="noryang_naru", name="노량진 나루(노들 나루)", type="나루", river="hangang", road="noryang_ferry", lat=37.5190, lon=126.9565, confidence="추정",
         notes="큰 나룻배(말·가마 싣는 배). 임금 행차 땐 배다리(1795 정조)."),
    dict(id="hangangjin_naru", name="한강진 나루", type="나루", river="hangang", road="hangangjin_ferry", lat=37.5250, lon=127.0110, confidence="추정", notes="사평나루와 마주."),
    dict(id="gwangtonggyo_x", name="광통교", type="돌다리", river="cheonggyecheon", road="namdaemunro", lat=37.5687, lon=126.9829, confidence="추정", notes=""),
    dict(id="supyogyo_x", name="수표교", type="돌다리", river="cheonggyecheon", road=None, lat=37.5683, lon=126.9905, confidence="추정", notes="수표교 길(남북) — 돈화문로 이음."),
    dict(id="hyogyeonggyo_x", name="효경교", type="돌다리", river="cheonggyecheon", road="seonggyungwan_lane", lat=37.5693, lon=126.9985, confidence="가설", notes="배오개 앞."),
    dict(id="ogansumun_x", name="오간수문", type="수문", river="cheonggyecheon", road=None, lat=37.5698, lon=127.0093, confidence="확정", notes="길이 아니라 성벽 수문."),
]

AXES = [dict(town="한양 도성", center=(37.5715, 126.9880), jinsan=("백악(북악산)", 37.5930, 126.9738, "확정"), ansan=("목멱산(남산)", 37.5512, 126.9882, "확정"),
             note="주산 백악–안산 목멱, 좌청룡 낙산·우백호 인왕. 경복궁 축은 백악→광화문→육조거리(정남).")]

PORTALS = [  # 권역 끝 → 노정
    dict(id="to_pyeongyang", name="→ 황주·평양(의주대로)", road="seomun_ro", to_route="GG_HANYANG-HH_HWANGJU", note="의주대로(무악재 너머 → 개성 → 황주 → 평양)"),
    dict(id="to_namwon", name="→ 남원(삼남대로)", road="samnam_south", to_route="JL_NAMWON_UNBONG-GG_HANYANG", note="삼남대로(노량진 → 과천 → 수원 → 천안삼거리 → 공주 → 전주 → 남원)"),
    dict(id="to_gyeongju", name="→ 경주(살곶이·송파)", road="dongdaemun_out", to_route="GG_HANYANG-GS_GYEONGJU", note="동대문 → 살곶이다리 → 송파 나루(위성, 노정 첫 쉼터) → 광주 → 문경새재"),
    dict(id="to_gyeongju_hangangjin", name="→ 경주(한강진·판교)", road="sapyeong_road", to_route="GG_HANYANG-GS_GYEONGJU", note="한강진 → 사평 → 판교(영남대로 갈래)"),
    dict(id="to_hamheung", name="→ 함흥(경흥대로)", road="hyehwamun_out", to_route="GG_HANYANG-HG_HAMHEUNG", note="경흥대로(혜화문 → 의정부 → 철원 → 철령 → 함흥)"),
]

SPAWN = dict(lat=37.5596, lon=126.9754, note="숭례문 남쪽 앞(성 밖 길 위)")

_D = dict(archetype="capital", climate="central")
PROFILES = {
    "hanyang_doseong_in": dict(_D, district="all", roof={"giwa": 0.6, "choga": 0.4}, wall="todam", layout="walled_grid", layout_detail="capital_grid", entrance="great_gate",
                               people=["관원", "양반", "중인", "시전상인", "군졸", "백성"], animals=["말", "개"], signature="북악 아래 새로 지은 경복궁과 산 능선 성곽", trades=["관아", "시전", "수공업"],
                               notes="도읍 특수 유형: 압축 덜 함(K=0.5), 구역별 profile"),
    "bukchon": dict(_D, district="bukchon", roof={"giwa": 0.85, "choga": 0.15}, wall="todam_high", layout="terraced", layout_detail="hill_alleys", entrance="sotdae_gate",
                    people=["양반", "청지기", "하인"], animals=[], signature="솟을대문 큰 기와집이 언덕 골목을 따라 층층이", trades=["권문세가"]),
    "ungjongga": dict(_D, district="jongno", roof={"giwa": 0.9, "choga": 0.1}, wall="none", layout="linear_street", layout_detail="linear_arcade(시전 행랑)", entrance="jongnu_bell",
                      people=["시전상인", "보부상", "장꾼", "나그네"], animals=["말", "소"], signature="종루와 끝없는 시전 행랑, 뒷길 피맛골", trades=["시전", "육의전"]),
    "jungchon": dict(_D, district="jungchon", roof={"giwa": 0.5, "choga": 0.5}, wall="todam", layout="linear_street", layout_detail="along_stream(개천 따라)", entrance="stone_bridge",
                     people=["역관", "의관", "장인", "빨래하는 아낙"], animals=[], signature="개천 돌축대와 다리, 빨래터", trades=["중인 기술직", "수공업"]),
    "namchon": dict(_D, district="namchon", roof={"giwa": 0.4, "choga": 0.6}, wall="fence", layout="terraced", layout_detail="hill_alleys", entrance="pine_slope",
                    people=["가난한 선비", "무관"], animals=["개"], signature="남산 솔숲 아래 낡은 기와·초가(남산골 샌님)", trades=["글공부"]),
    "baeogae_jang": dict(_D, district="jongno", roof={"choga": 0.7, "giwa": 0.3}, wall="none", layout="round_cluster", layout_detail="market_square(난전)", entrance="awning_stalls",
                         people=["난전 상인", "농부", "장꾼"], animals=["소"], signature="동대문 안 채소·곡식 난전", trades=["난전"]),
    "chilpae_jang": dict(_D, district="outer_south", roof={"choga": 0.8, "giwa": 0.2}, wall="none", layout="round_cluster", layout_detail="market_square(난전)", entrance="awning_stalls",
                         people=["어물 장수", "짐꾼"], animals=[], signature="숭례문 밖 생선 비린내 난전", trades=["어물 난전"]),
    "wangsimni": dict(archetype="plain", climate="central", signature="성 밖 미나리꽝과 채마밭", trades=["채소 농사"], people=["농부"], animals=["소"]),
    "mapo": dict(archetype="river", climate="central", roof={"choga": 0.7, "giwa": 0.3}, signature="새우젓·소금 객주 창고와 돛배", trades=["객주", "소금", "젓갈"],
                 people=["뱃사공", "객주", "짐꾼"], animals=["갈매기"], notes="경강 포구(서해 배)"),
    "yongsan": dict(archetype="river", climate="central", roof={"choga": 0.7, "giwa": 0.3}, signature="세곡선과 강창 곳간", trades=["강창", "객주"], people=["뱃사공", "창고지기", "객주"]),
    "noryangjin": dict(archetype="river", climate="central", signature="큰 나룻배와 강 건너 도성 능선", trades=["나루", "주막"], people=["뱃사공", "나그네", "주모"], animals=["말"]),
    "hangangjin": dict(archetype="river", climate="central", signature="버티고개 넘어 닿는 나루와 사평 건너편", trades=["나루", "주막"], people=["뱃사공", "나그네"], animals=["말"]),
    "seobinggo_village": dict(archetype="river", climate="central", signature="겨울 강 얼음 뜨기", trades=["채빙"], people=["빙부"]),
}

META = dict(parent_province="경기도(한성부)", main_river="한강(경강)", connected_river=["개천(청계천)→중랑천→한강(권역 밖 동쪽)", "만초천→한강", "한강→서해(권역 밖 서쪽)"],
            watershed_divide="도성 둘레 내사산(백악·낙산·목멱·인왕) 능선: 안쪽 물은 모두 개천으로, 바깥은 한강·중랑천으로",
            main_mountain=["백악(북악산, 주산)", "인왕산(우백호)", "낙산(좌청룡)", "목멱산(남산, 안산)"],
            settlement_type="도읍(도성 + 궁궐·종묘사직·시전) + 경강 나루 마을(마포·용산·노량진·한강진)",
            economy=["시전(육의전)·난전", "경강 상업(소금·젓갈·세곡)", "채소 농사(왕십리)", "관청·궁궐 수요", "얼음(빙고)"],
            forbidden=["현대 도시(빌딩·아파트·도로)", "한강 제방·강변도로·다리", "지하철·철도", "직강 복개 하천", "1870년 뒤 건물(덕수궁 석조전·환구단·독립문 등)"],
            sources=["OpenStreetMap '서울 한양도성' 성곽 선·문 위치", "한국민족문화대백과(통설)", "수선전도(1840년대)·도성도 — 원본 대조 대기"])
MAIN_ROAD = "unjongga"
HYDRO_EXTRA = dict(edge_flows=[dict(cond="True", label="권역 밖 — 한강 수계(중랑천·한강 하류)")], width_game={"B": 15.0, "C": 6.0, "D": 3.0})
QA_ALT = [dict(id="gyeongbokgung", lo=20, hi=60), dict(id="mokmyeok_bongsu", lo=200, hi=280)]
ZOOMS = {"zoom_palace_jongno": [-900, -1500, 500, -600], "zoom_river_ferries": [-2000, 300, 800, 2400]}
for _p in PORTALS:
    _p["ref"] = list(next(r for r in ROADS if r["id"] == _p["road"])["via"][-1])

N_AUTO = 4

SPRINGS = [dict(id="namsan_spring", name="남산골 샘(우물)", lat=37.5600, lon=126.9922, settlement="namchon", confidence="가설",
                notes="남산 북쪽 기슭 샘 — 남촌 공동 우물·빨래터(가설 위치)", source=["원칙: 산기슭 마을의 샘"])]

DENOISE = dict(win_real_m=150.0, full_below=45.0, none_above=90.0)
