"""data-north 보조: 고증 좌표 길잡이(OSM Nominatim) 조회 → cache/north/nominatim.json (이름 → 후보 목록). 1초 간격."""
import json, os, sys, time, urllib.request, urllib.parse
HERE = os.path.dirname(os.path.abspath(__file__))
P = os.path.join(HERE, "cache", "north", "nominatim.json")
# (질의, 국가코드, viewbox lon0,lat0,lon1,lat1)
VB = {"GG": "126.90,37.62,127.15,37.48", "HH": "125.55,38.80,125.95,38.45", "PA": "125.60,39.15,125.90,38.95", "HG": "127.40,40.00,127.70,39.78"}
Q = {
 "GG": ["경복궁", "창덕궁", "종묘", "사직단", "숭례문", "흥인지문", "돈의문터", "숙정문", "혜화문", "광희문", "창의문", "소의문터", "보신각",
        "광통교", "수표교", "청계천", "북악산", "인왕산", "낙산", "남산", "마포나루", "용산", "노량진", "한강진", "살곶이다리", "운현궁", "경희궁", "동관왕묘", "남대문시장", "서빙고", "동빙고", "새남터", "양화나루", "밤섬", "여의도", "선유도", "중랑천", "만초천", "욱천", "창경궁", "원구단", "모화관", "독립문", "환구단", "성균관", "문묘"],
 "HH": ["황주", "황주읍", "황주천", "정방산", "성불사", "월파루", "겸이포", "송림", "사리원", "황주성", "도화동", "구월산", "재령강", "대동강"],
 "PA": ["대동문", "보통문", "칠성문", "연광정", "부벽루", "을밀대", "기린굴", "모란봉", "능라도", "대동강", "보통강", "만수대", "숭령전", "숭인전", "영명사", "청류벽", "현무문", "전금문", "정해문", "주작문", "양각도", "대성산", "평양성", "기자릉", "단군릉"],
 "HG": ["함흥", "만세교", "성천강", "함흥본궁", "반룡산", "동흥산", "구천각", "낙민루", "치마대", "호련천", "서호", "흥남", "함흥성", "함흥향교"],
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
