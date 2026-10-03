"""노정 쉼터 사이 길목 볼거리(via 창) — make_routes.py가 읽는다.

쉼터(stop) 사이를 1.2~2km(큰 고개는 더 길게)로 늘리면서, 그 사이 실제 길이 지나던 자리(대략의 경위도)에 실측 DEM 창을 하나씩 더 두고
지형이 말해 주는 볼거리를 놓는다(명세 §19 길, §23 D급 설화 배치, §27 주막, §29 성황당·당집). 기계적으로 고르게 깔지 않고 노정마다
실제 지명·지형(고개·나루·들·숲·소)에 맞는 것만 골랐다. 경위도는 기억값 근사 — 고증은 참고용.

via: VIA(sight, key, name, title, lat, lon, tales=[(코드, 제목, 등급)…], **선택)
  sight: seonang(서낭당·돌무더기) · sinmok(홀로 선 신목·금줄) · inn_ruin(빈 주막터·원터) · milestone(이정표·후·장승)
         · hamlet(길가 작은 마을·논밭) · ferry_shed(나루 대기막·나룻배, 물길 팜) · mound(무덤) · tiger_forest(호랑이 숲 고갯길)
         · dokkaebi_ruin(옛 여울목 폐가·징검다리, 물길 팜) · pool(폭포와 소) · view_rock(쉼바위·전망)
  선택: a(창 핵심 반길이 m), kh(수평 압축), snap("low" = 옆 1km 안 가장 낮은 곳으로 — 골짜기 길), river(dict), culture
VIAS[노정 id] = { 앞 창 key: [via…] }  — 앞 창 key는 "from_end" 또는 쉼터 key(그 쉼터 다음 구간)
"""

def VIA(sight, key, name, title, lat, lon, tales=(), **kw):
    d = dict(sight=sight, key=key, name=name, title=title, lat=lat, lon=lon, tales=list(tales))
    d.update(kw)
    return d

# 볼거리 종류별 기본 설화·조우(명세 §22·23 — D급은 지역에 고정하지 않고 맞는 환경에만)
SIGHT_DEFAULT = {
    "seonang": dict(tales=[("JG33", "장승·성황당 이야기(길손이 돌 얹고 비는 고갯마루)", "D")], enc=["호랑이", "여우", "도깨비(산길)"], night=True, a=110),
    "sinmok": dict(tales=[("JG29", "나무 그늘 산 총각(정자나무)", "D")], enc=["귀신(나무 밑)", "도깨비"], night=True, a=100),
    "inn_ruin": dict(tales=[("JG10", "도깨비 방망이(산속 빈집)", "D")], enc=["귀신(폐가)", "도깨비"], night=True, a=110),
    "milestone": dict(tales=[("JG33", "장승 동티(장승을 해친 자가 벌 받음)", "D")], enc=["도깨비(밤길)", "여우"], night=True, a=90),
    "hamlet": dict(tales=[("JG07", "우렁각시(논·외딴집)", "D")], enc=["여우", "도깨비"], night=False, a=140),
    "ferry_shed": dict(tales=[("—", "나루 물귀신(뱃사공 이야기)", "D")], enc=["도깨비(나루)", "물귀신"], night=True, a=130),
    "mound": dict(tales=[("JG24", "효자와 호랑이(산소 지킴)", "D"), ("JG14", "여우고개·구미호(무덤 파는 여우)", "C")], enc=["귀신(무덤)", "여우"], night=True, a=100),
    "tiger_forest": dict(tales=[("JG01", "해와 달이 된 오누이(고개 호랑이)", "D"), ("JG22", "호랑이와 곶감", "D")], enc=["호랑이"], night=True, a=210),
    "dokkaebi_ruin": dict(tales=[("JG11", "도깨비 다리·도깨비 둑", "C"), ("JG12", "도깨비 씨름·도깨비불", "D")], enc=["도깨비"], night=True, a=120),
    "pool": dict(tales=[("JG20", "용소·이무기 승천", "C")], enc=["이무기·용", "물귀신"], night=False, a=120),
    "view_rock": dict(tales=[("JG18", "망부석(기다리다 돌이 된 아내)", "C")], enc=["여우", "산신(노인)"], night=False, a=100),
    "roadside": dict(tales=[("JG28", "좁쌀 한 톨로 장가든 총각(길에서 바꿔 가기)", "D")], enc=["나그네(길손)", "도깨비(밤길)", "여우"], night=False, a=60),
}
# 이벤트 담당용 큰 분류(사용자 요청: pass/forest/crossing/ruin/tomb/pool/roadside/inn site …)
CATEGORY = {
    "seonang": "pass", "view_rock": "pass", "tiger_forest": "forest", "ferry_shed": "crossing", "dokkaebi_ruin": "ruin",
    "inn_ruin": "inn_site", "mound": "tomb", "pool": "pool", "sinmok": "roadside", "milestone": "roadside", "roadside": "roadside",
    "hamlet": "hamlet",
}
GRADE_TYPE = {   # 조우 종류(type) — 이벤트 담당이 쓰는 분류
    "seonang": "고개·성황", "sinmok": "당산나무", "inn_ruin": "폐가·원터", "milestone": "길가 표지", "hamlet": "길가 마을",
    "ferry_shed": "나루", "mound": "무덤", "tiger_forest": "호랑이 숲", "dokkaebi_ruin": "도깨비 여울", "pool": "용소·폭포", "view_rock": "쉼바위", "roadside": "길가 쉼터",
}

VIAS = {
 # 삼남대로: 남원 → 오수 → (임실·슬치) → 전주 → 앵곡 → (삼례 만경강·여산 도계·노성) → 곰나루 → (정안 여울·차령 숲) → 차령 → (풍세 들) → 천안삼거리 → (성환·소사·지지대·남태령) → 한양
 "JL_NAMWON_UNBONG-GG_HANYANG": {
   "from_end": [VIA("hamlet", "seodo", "남원 북쪽 들마을(서도)", "서도 들", 35.4930, 127.3520, tales=[("JG07", "우렁각시(논)", "D")])],
   "osu": [VIA("mound", "imsil_myo", "임실 길가 산소", "임실 산소", 35.6150, 127.2850),
           VIA("seonang", "seulchi", "슬치 고개 서낭당(임실→전주)", "슬치", 35.7150, 127.2150,
               tales=[("JG33", "성황당 돌무더기", "D"), ("JG23", "호랑이 형님", "D")])],
   "jeonju": [VIA("roadside", "jeonju_west", "전주 서문 밖 길가 쉼터(정자나무 평상)", "서문 밖 쉼터", 35.8150, 127.1300),
              VIA("sinmok", "hyoja_tree", "효자리 당산나무(전주 서쪽 들)", "효자리 당산", 35.8200, 127.1050,
                  tales=[("JG21", "열녀·효자 정려담(마을 어귀)", "C"), ("JG29", "나무 그늘 산 총각", "D")])],
   "aenggok": [VIA("ferry_shed", "samnye", "삼례 만경강 나루", "삼례 나루", 35.9100, 127.0700, snap="low",
                   river=dict(id="mangyeong", name="만경강(삼례)", width=16.0, grade="B")),
               VIA("milestone", "yeosan", "여산 도계 이정표(전라·충청 경계)", "여산 도계", 36.0600, 127.0850,
                   tales=[("JG33", "장승 동티", "D"), ("GH11", "박문수(도계 주막 일화)", "C")]),
               VIA("inn_ruin", "noseong", "노성 빈 주막터", "노성 주막터", 36.2200, 127.1300,
                   tales=[("JG10", "도깨비 방망이(빈집)", "D"), ("GD12", "김삿갓(주막 시 한 수)", "C")])],
   "gomnaru": [VIA("dokkaebi_ruin", "jeongan", "정안천 옛 여울목(폐가)", "정안 여울", 36.5300, 127.1250, snap="low",
                   river=dict(id="jeongancheon", name="정안천 여울", width=5.0, grade="C", type="징검다리")),
               VIA("tiger_forest", "charyeong_wood", "차령 남쪽 잣나무 숲길", "차령 숲길", 36.5850, 127.1300)],
   "charyeong": [VIA("seonang", "charyeong_north", "차령 북쪽 내리막 서낭", "차령 서낭", 36.6400, 127.1400),
                 VIA("hamlet", "pungse", "풍세 들 마을", "풍세", 36.7150, 127.1500, tales=[("JG09", "방귀쟁이 며느리", "D")])],
   "samgeori": [VIA("inn_ruin", "sosa", "소사원 터(옛 원집 자리)", "소사원 터", 37.0050, 127.0600, kind_param="won",
                    tales=[("—", "원터 귀신(빈 원집)", "D"), ("JG12", "도깨비불", "D")]),
                VIA("view_rock", "jijidae", "지지대 고개 쉼바위(수원 바라봄)", "지지대", 37.3100, 126.9750,
                    tales=[("—", "지지대 — 정조가 화성 쪽을 돌아보며 더디 간 고개(지명담)", "B"), ("JG18", "망부석", "C")]),
                VIA("tiger_forest", "namtaeryeong", "남태령 숲 고갯길(과천)", "남태령", 37.4650, 126.9900,
                    tales=[("JG23", "호랑이 형님", "D"), ("—", "남태령 도적·호랑이(여우고개라고도)", "C")])],
 },
 # 영남대로·안동길: 한양 → 송파 → (이천 들·달천 나루·수안보 숲) → 문경새재 → (토끼비리·함창 고분) → 상주 → (낙양 원터·풍산 신목) → 하회 → (들마을) → 제비원 → (의성 고개·금호강 여울) → 경주
 "GG_HANYANG-GS_GYEONGJU": {
   "from_end": [VIA("milestone", "salgoji", "살곶이 다리 건너 이정표", "살곶이", 37.5560, 127.0450)],
   "songpa": [VIA("hamlet", "icheon", "이천 들마을", "이천 들", 37.2700, 127.4400, tales=[("JG07", "우렁각시", "D")]),
              VIA("ferry_shed", "dalcheon", "충주 달천 나루", "달천 나루", 36.9800, 127.9000, snap="low",
                  river=dict(id="dalcheon", name="달천", width=18.0, grade="B"),
                  tales=[("GH10", "임경업 — 달천 사람(장군 이야기)", "B"), ("—", "나루 물귀신", "D")]),
              VIA("tiger_forest", "suanbo", "수안보 소조령 숲길", "소조령", 36.8450, 128.0300,
                  tales=[("JG22", "호랑이와 곶감", "D"), ("JG01", "해와 달이 된 오누이", "D")])],
   "saejae": [VIA("view_rock", "tokkibiri", "토끼비리 벼랑길·고모산성 바라봄", "토끼비리", 36.6950, 128.1800,
                  tales=[("—", "토끼비리 — 토끼가 낸 벼랑길(고려 태조 지명담)", "B"), ("JG16", "오누이 힘내기(고모산성)", "C")]),
              VIA("mound", "hamchang", "함창 고령가야 왕릉(전설)", "함창 고분", 36.5600, 128.1800, kind_param="royal",
                  tales=[("—", "고령가야 태조왕릉(전설 — 진짜라고 하지 않음)", "C"), ("JG24", "효자와 호랑이", "D")])],
   "sangju": [VIA("inn_ruin", "nagyang", "낙양역 옛 원터", "낙양 원터", 36.4500, 128.2800, kind_param="won"),
              VIA("sinmok", "pungsan", "풍산 들 당산나무", "풍산 당산", 36.5100, 128.4300)],
   "hahoe": [VIA("mound", "pungsan_myo", "풍산 길가 산소", "풍산 산소", 36.5800, 128.6400),
             VIA("hamlet", "pungsan_field", "풍산 들 길가 마을", "풍산 들", 36.5700, 128.6000, tales=[("JG27", "반쪽이", "D")])],
   "jebiwon": [VIA("seonang", "uiseong", "의성 고갯마루 서낭당", "의성 고개", 36.3500, 128.7000),
               VIA("dokkaebi_ruin", "geumho", "금호강 옛 여울목(영천)", "금호 여울", 35.9900, 128.9200, snap="low",
                   river=dict(id="geumho_ford", name="금호강 여울", width=6.0, grade="C", type="징검다리"))],
 },
 # 관동대로: 한양 → (용진 나루·용문 은행나무·지평 들) → 원주 → (구룡소) → 치악산 → (문재 숲·대화 원터·진부 들) → 횡계 → (대관령 숲) → 강릉
 "GG_HANYANG-GW_GANGNEUNG": {
   "from_end": [VIA("ferry_shed", "yongjin", "용진 나루(두물머리 위)", "용진 나루", 37.5300, 127.3100, snap="low",
                    river=dict(id="bukhan_yongjin", name="북한강(용진)", width=20.0, grade="B")),
                VIA("sinmok", "yongmun", "용문 은행나무 아래 길(신목)", "용문 은행나무", 37.5100, 127.5600, variant="broadleaf",
                    tales=[("—", "용문사 은행나무(의상 지팡이·마의태자 — 전설, 진짜라고 하지 않음)", "C")]),
                VIA("hamlet", "jipyeong", "지평 들마을", "지평", 37.4700, 127.6300)],
   "wonju": [VIA("mound", "chiak_myo", "치악 기슭 효자 산소(시묘)", "효자 산소", 37.3700, 127.9800, tales=[("JG24", "효자와 호랑이(시묘살이)", "D")]),
             VIA("pool", "guryongso", "치악산 구룡소(아홉 용 못)", "구룡소", 37.3950, 128.0350,
                 tales=[("—", "구룡사 아홉 용(의상이 용을 쫓고 절을 세움 — 지명담)", "C"), ("JG20", "용소·이무기", "C")])],
   "chiak": [VIA("tiger_forest", "munjae", "안흥 문재 숲 고갯길", "문재", 37.4850, 128.1700,
                 tales=[("JG24", "효자와 호랑이", "D"), ("JG01", "해와 달이 된 오누이", "D")]),
             VIA("inn_ruin", "daehwa", "대화 역 옛 원터", "대화 원터", 37.4900, 128.4500, kind_param="won"),
             VIA("hamlet", "jinbu", "진부 고랭지 들마을", "진부", 37.6400, 128.5600, tales=[("JG02", "팥죽할멈과 호랑이", "D")])],
   "hoenggye": [VIA("tiger_forest", "daegwallyeong_wood", "대관령 서쪽 옛길 숲", "대관령 숲길", 37.6850, 128.7300,
                    tales=[("GD03", "대관령 산신·국사여성황(호랑이가 데려간 정씨 처녀)", "A+"), ("JG23", "호랑이 형님", "D")])],
 },
 # 의주대로(한양→황주): 한양 → (혜음령·혜음원 터·파주 신목) → 임진나루 → (장단 들·무덤) → 개성 → (신목) → 선죽교 → (박연폭포·숲) → 청석골 → (금천 여울·평산 들) → 서흥 → (동선령) → 황주
 "GG_HANYANG-HH_HWANGJU": {
   "from_end": [VIA("seonang", "hyeeumryeong", "혜음령 서낭당", "혜음령", 37.7250, 126.8850),
                VIA("inn_ruin", "hyeeumwon", "혜음원 터(고려 원집 자리)", "혜음원 터", 37.7450, 126.8850, kind_param="won",
                    tales=[("—", "혜음원 — 도적·호랑이 많던 고개의 원집(지명담)", "B"), ("JG12", "도깨비불", "D")]),
                VIA("sinmok", "paju", "파주 길가 느티나무", "파주 느티", 37.8300, 126.7800)],
   "imjin": [VIA("hamlet", "jangdan", "장단 들마을", "장단", 37.9300, 126.6600, tales=[("GH06", "의좋은 형제(볏단 나르기 — 이야기형만)", "D")]),
             VIA("mound", "jangdan_myo", "장단 길가 산소", "장단 산소", 37.9500, 126.6100)],
   "kaesong": [VIA("roadside", "songdo_well", "송도 북문 길가 우물·평상", "송도 길가", 37.9750, 126.5600, tales=[("GH18", "전우치(송도 장터 도술)", "B")]),
               VIA("sinmok", "songdo", "송도 북문 밖 느티나무", "송도 느티", 37.9780, 126.5580)],
   "seonjuk": [VIA("pool", "bagyeon", "박연폭포와 고모담", "박연폭포", 38.0300, 126.4900, h=7.0,
                   tales=[("GH20", "황진이·박연폭포(서경덕·박연 삼절)", "A"), ("—", "박연 — 피리 불다 용녀에게 끌려간 박 진사(지명담)", "B")]),
               VIA("tiger_forest", "cheongseok_wood", "청석골 아래 숲길", "청석골 숲", 38.0500, 126.4800,
                   tales=[("HS04", "임꺽정 청석골(실록형)", "B"), ("JG23", "호랑이 형님", "D")])],
   "cheongseok": [VIA("dokkaebi_ruin", "geumcheon", "금천 옛 여울목 폐가", "금천 여울", 38.1500, 126.4000, snap="low",
                      river=dict(id="geumcheon_ford", name="예성강 지류 여울", width=6.0, grade="C", type="징검다리")),
                  VIA("hamlet", "pyeongsan", "평산 들마을", "평산", 38.3300, 126.3800)],
   "seoheung": [VIA("seonang", "dongseonryeong", "동선령 서낭당(서흥→봉산)", "동선령", 38.5300, 126.0500,
                    tales=[("JG33", "성황당 돌무더기", "D"), ("JG14", "여우고개", "C")]),
                VIA("tiger_forest", "dongseon_wood", "동선령 북쪽 숲길", "동선령 숲", 38.5600, 126.0000)],
 },
 # 의주대로(황주→평양)
 "HH_HWANGJU-PA_PYEONGYANG": {
   "from_end": [VIA("sinmok", "hwangju_north", "황주 북쪽 들 당산나무", "황주 북들 당산", 38.7500, 125.8000)],
   "junghwa": [VIA("dokkaebi_ruin", "mujin", "무진천 옛 여울목", "무진 여울", 38.9500, 125.7800, snap="low",
                   river=dict(id="mujin_ford", name="무진천 여울", width=5.0, grade="C", type="징검다리"))],
 },
 # 경흥대로(한양→함흥): 한양 → (다락원 터) → 축석령 → (재인폭포·울음산 쉼바위·한탄강 나루) → 철원 → (김화 들·회양 원터·철령 숲) → 철령 → (안변 신목·석왕사 계곡) → 원산 → (문천 들·용흥강 나루) → 영흥(갈림) → (정평 신목) → 함흥
 "GG_HANYANG-HG_HAMHEUNG": {
   "from_end": [VIA("inn_ruin", "darakwon", "다락원 터(도봉 아래 옛 원집)", "다락원 터", 37.6900, 127.0500, kind_param="won",
                    tales=[("—", "다락원 — 원집 다락에서 길손이 묵던 곳(지명담)", "B"), ("JG12", "도깨비불", "D")])],
   "chukseok": [VIA("pool", "jaein", "재인폭포(한탄강 지류)", "재인폭포", 38.0700, 127.1200, h=6.5,
                    tales=[("—", "재인폭포 — 줄 끊긴 광대 재인(지명담)", "C"), ("JG20", "용소·이무기", "C")]),
                VIA("view_rock", "ureumsan", "울음산(명성산) 바라보는 쉼바위", "울음산", 38.1000, 127.2600,
                    tales=[("GD08", "궁예 울음산(명성산)", "A"), ("JG19", "애기바위·며느리바위", "C")]),
                VIA("ferry_shed", "hantan", "한탄강 나루", "한탄강 나루", 38.1700, 127.2600, snap="low",
                    river=dict(id="hantangang", name="한탄강", width=16.0, grade="B"))],
   "cheorwon": [VIA("hamlet", "gimhwa", "김화 들마을", "김화", 38.2900, 127.4300, tales=[("JG02", "팥죽할멈과 호랑이", "D")]),
                VIA("inn_ruin", "hoeyang", "회양 신안역 옛 원터", "회양 원터", 38.6500, 127.3800, kind_param="won"),
                VIA("tiger_forest", "cheollyeong_wood", "철령 남쪽 숲 고갯길", "철령 숲길", 38.7600, 127.3800,
                    tales=[("JG01", "해와 달이 된 오누이", "D"), ("JG23", "호랑이 형님", "D")])],
   "cheollyeong": [VIA("sinmok", "anbyeon", "안변 들 당산나무", "안변 당산", 38.9800, 127.3900),
                   VIA("pool", "seogwang", "석왕사 계곡 소", "석왕사 계곡", 39.0800, 127.3700,
                       tales=[("GB06", "이성계 — 석왕사 무학의 꿈풀이(서까래 셋 진 꿈)", "B"), ("JG20", "용소·이무기", "C")])],
   "wonsan": [VIA("hamlet", "muncheon", "문천 바닷가 들마을", "문천", 39.2500, 127.3500),
              VIA("ferry_shed", "yongheung_river", "용흥강 나루(영흥 앞)", "용흥강 나루", 39.5000, 127.2800, snap="low",
                  river=dict(id="yongheunggang", name="용흥강", width=16.0, grade="B"),
                  tales=[("GB06", "이성계 — 용이 일어난 강(용흥강 지명담)", "B"), ("—", "나루 물귀신", "D")])],
   "yeongheung": [VIA("sinmok", "jeongpyeong", "정평 들 당산나무", "정평 당산", 39.7800, 127.4000)],
 },
 # 평양→함흥(영흥에서 경흥대로와 만남): 평양 → (강동 들·비류강 나루) → 성천 → (양덕 숲·신창 원터) → 양덕 → (온정 소·고원 고개) → 고원 → (고원 들) → 영흥 갈림
 "PA_PYEONGYANG-HG_HAMHEUNG": {
   "from_end": [VIA("hamlet", "gangdong", "강동 들마을", "강동", 39.1400, 126.1000),
                VIA("ferry_shed", "biryu", "비류강 나루(성천 앞)", "비류강 나루", 39.2300, 126.1900, snap="low",
                    river=dict(id="biryugang", name="비류강", width=14.0, grade="B"),
                    tales=[("—", "비류국 송양왕과 동명왕(비류강 — 지명담)", "B"), ("—", "나루 물귀신", "D")])],
   "seongcheon": [VIA("tiger_forest", "yangdeok_wood", "양덕 서쪽 숲 고갯길", "양덕 숲길", 39.2200, 126.4500),
                  VIA("inn_ruin", "sinchang", "신창 옛 원터", "신창 원터", 39.2300, 126.5600, kind_param="won")],
   "yangdeok": [VIA("pool", "yangdeok_spring", "양덕 온정(더운 샘)과 소", "양덕 온정", 39.2300, 126.7600,
                    tales=[("—", "온정 — 상처 씻던 사슴이 알려 준 더운 샘(지명담)", "C"), ("JG32", "젊어지는 샘물", "D")]),
                VIA("seonang", "gowon_pass", "고원 가는 고갯마루 서낭당", "고원 고개", 39.3300, 127.0000)],
   "gowon": [VIA("hamlet", "gowon_field", "고원 들마을", "고원 들", 39.4800, 127.2500)],
 },
 # 장산곶 띠: 황주 → (재령강 나루) → 재령 → (신천 들) → (구월산 숲) → 구월산 → (장연 폐가·몽금포 쉼바위) → 장산곶
 "HH_HWANGJU-JANGSANGOT": {
   "from_end": [VIA("ferry_shed", "jaeryeong_river", "재령강 나루", "재령강 나루", 38.4600, 125.7100, snap="low",
                    river=dict(id="jaeryeonggang", name="재령강", width=16.0, grade="B"))],
   "jaeryeong": [VIA("hamlet", "sincheon", "신천 들마을", "신천", 38.3500, 125.4700, tales=[("JG07", "우렁각시", "D")]),
                 VIA("tiger_forest", "guwol_wood", "구월산 기슭 숲길", "구월산 숲", 38.4800, 125.3500,
                     tales=[("HS04", "임꺽정 구월산 산채(실록형)", "B"), ("JG22", "호랑이와 곶감", "D")])],
   "guwol": [VIA("dokkaebi_ruin", "jangyeon", "장연 옛 여울목 폐가", "장연 여울", 38.2500, 125.1000, snap="low",
                 river=dict(id="jangyeon_ford", name="장연 내 여울", width=5.0, grade="C", type="징검다리")),
             VIA("view_rock", "monggeumpo", "몽금포 바다 보이는 쉼바위", "몽금포", 38.1800, 124.8000,
                 tales=[("HS02", "심청 — 인당수 바라보는 바위", "B"), ("JG18", "망부석", "C")])],
 },
 # 북청길: 함흥 → (함관령) → 홍원 → (신포 바닷가 마을) → 북청
 "HG_HAMHEUNG-BUKCHEONG": {
   "from_end": [VIA("seonang", "hamgwallyeong", "함관령 서낭당", "함관령", 39.9800, 127.7500,
                    tales=[("GB06", "이성계 함관령 싸움(활·말 이야기)", "B"), ("JG33", "성황당 돌무더기", "D")]),
                VIA("tiger_forest", "hamgwal_wood", "함관령 동쪽 숲길", "함관령 숲", 39.9900, 127.8200)],
   "hongwon": [VIA("sinmok", "bukcheong_dang", "북청 어귀 당산나무", "북청 어귀 당산", 40.0700, 128.2500, tales=[("GB04", "북청 사자놀음(잡귀 쫓기)", "A")]),
               VIA("hamlet", "sinpo", "신포 바닷가 마을", "신포", 40.0400, 128.1500, tales=[("JG30", "소금 나오는 맷돌", "D")])],
 },
 # 남해 뱃길: 남원 → (곡성 들·나주 영산강 나루·반남 고분) → 덕진다리 → (구림 쉼바위) → 관두포 ⛵ (보길도 앞바다) → 화북포
 "SEA_NAMHAE_JEJU": {
   "from_end": [VIA("hamlet", "gokseong", "곡성 들마을", "곡성 들", 35.2800, 127.2500, tales=[("HN26", "원홍장 연기(곡성 관음사 — 심청 근원)", "B")]),
                VIA("ferry_shed", "yeongsan", "영산강 나주 나루", "영산강 나루", 35.0100, 126.7100, snap="low",
                    river=dict(id="yeongsangang", name="영산강(나주)", width=20.0, grade="A")),
                VIA("mound", "bannam", "반남 큰 무덤들(옛 고분)", "반남 고분", 34.9100, 126.6500, kind_param="royal",
                    tales=[("—", "반남 큰 무덤 — 옛 왕 무덤이라는 말(진짜라고 하지 않음)", "C"), ("JG14", "여우고개·구미호", "C")])],
   "deokjin": [VIA("sinmok", "haenam_dang", "해남 들 당산나무", "해남 당산", 34.6500, 126.5500),
               VIA("view_rock", "gurim", "구림 비둘기바위·월출산 바라봄", "구림", 34.7400, 126.6300,
                   tales=[("HN28", "도선 출생(구림 비둘기바위)", "A")])],
 },
}
