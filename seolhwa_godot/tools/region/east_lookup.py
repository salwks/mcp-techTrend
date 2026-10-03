"""data-east 보조: 고증 좌표 길잡이(OSM Nominatim) 조회 → cache/east/nominatim.json (이름 → 후보 목록). 1초 간격."""
import json, os, sys, time, urllib.request, urllib.parse
HERE = os.path.dirname(os.path.abspath(__file__))
P = os.path.join(HERE, "cache", "east", "nominatim.json")
VB = {"GS": "129.10,35.95,129.60,35.40", "GW": "128.65,37.85,129.10,37.60", "JJ": "126.40,33.60,126.90,33.30"}
Q = {
 "GS": ["경주읍성", "동경관", "경주문화원", "첨성대", "계림", "월성", "반월성", "불국사", "석굴암", "치술령", "망부석", "박제상", "감포", "감포항", "문무대왕릉",
        "이견대", "감은사지", "대종천", "형산강", "북천", "남천", "토함산", "남산", "선도산", "소금강산", "나정", "오릉", "포석정", "황룡사지", "분황사", "봉황대",
        "경주향교", "대릉원", "괘릉", "외동", "모화", "처용암", "연오랑세오녀", "덕동호", "보문호", "명활산성", "낭산", "금장대", "효현교", "서천"],
 "GW": ["임영관", "강릉대도호부관아", "칠사당", "경포대", "경포호", "오죽헌", "대관령", "대관령옛길", "반정", "대관령 국사성황사", "강릉향교", "남대천", "선교장",
        "허균허난설헌", "초당", "안목", "강문", "주문진", "정동진", "안인", "구산", "성산", "화부산", "모산봉", "홍장암", "굴산사지", "학산", "남항진", "연곡천", "섬석천"],
 "JJ": ["관덕정", "제주목 관아", "삼성혈", "제주향교", "산지천", "한천", "병문천", "오현단", "제주성지", "송당", "본향당", "김녕사굴", "만장굴", "김녕", "김녕항",
        "조천", "연북정", "화북", "삼양", "용두암", "사라봉", "별도봉", "원당봉", "불탑사", "아부오름", "다랑쉬오름", "거문오름", "함덕", "신촌", "와흘", "선흘", "동문시장", "제주항", "탑동", "알뜨르"],
}
db = json.load(open(P)) if os.path.exists(P) else {}
for reg, names in Q.items():
    for n in names:
        key = f"{reg}:{n}"
        if key in db: continue
        url = "https://nominatim.openstreetmap.org/search?" + urllib.parse.urlencode(dict(q=n, format="json", limit=5, viewbox=VB[reg], bounded=1))
        try:
            r = json.load(urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": "seolhwa-terrain-research/0.1"}), timeout=30))
        except Exception as e:
            print(key, e); time.sleep(2); continue
        db[key] = [dict(name=x.get("name"), lat=float(x["lat"]), lon=float(x["lon"]), cls=x["class"], type=x["type"], disp=x["display_name"][:80]) for x in r]
        print(key, [(x["name"], round(x["lat"], 4), round(x["lon"], 4), x["type"]) for x in db[key][:3]], flush=True)
        json.dump(db, open(P, "w"), ensure_ascii=False, indent=0)
        time.sleep(1.1)
