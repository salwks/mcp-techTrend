"""data-east 보조: Overpass로 권역 bbox 안 이름 있는 고증 길잡이(유적·봉우리·고개·굴·샘·마을) 한 번에 → cache/east/names_<R>.json"""
import json, os, sys, time, urllib.request, urllib.parse
HERE = os.path.dirname(os.path.abspath(__file__))
BB = {"GS": "35.60,129.10,35.93,129.56", "GW": "37.62,128.66,37.84,129.06", "JJ": "33.38,126.44,33.60,126.86"}
for reg, bb in BB.items():
    p = os.path.join(HERE, "cache", "east", f"names_{reg}.json")
    if os.path.exists(p): continue
    body = (f'nwr["historic"]["name"]({bb});nwr["tourism"~"attraction|viewpoint|museum"]["name"]({bb});'
            f'node["natural"~"peak|saddle|cave_entrance|spring|rock|cape|bay"]["name"]({bb});nwr["natural"~"cave_entrance|spring|bay|beach|water"]["name"]({bb});'
            f'node["place"~"village|hamlet|neighbourhood|quarter|suburb|town|islet"]["name"]({bb});nwr["amenity"="place_of_worship"]["name"]({bb});'
            f'way["waterway"~"river|stream"]["name"]({bb});nwr["mountain_pass"]["name"]({bb});')
    q = f"[out:json][timeout:180];({body});out center tags;"
    for srv in ["https://maps.mail.ru/osm/tools/overpass/api/interpreter", "https://overpass-api.de/api/interpreter", "https://overpass.kumi.systems/api/interpreter"]:
        try:
            r = urllib.request.Request(srv, data=urllib.parse.urlencode({"data": q}).encode(), headers={"User-Agent": "seolhwa-terrain-research/0.1"})
            d = json.load(urllib.request.urlopen(r, timeout=200))
            out = []
            for e in d["elements"]:
                c = e.get("center") or e
                if "lat" not in c: continue
                t = e.get("tags", {})
                out.append(dict(name=t.get("name"), lat=c["lat"], lon=c["lon"], kind=next((f"{k}={t[k]}" for k in ("historic", "tourism", "natural", "place", "amenity", "waterway", "mountain_pass") if k in t), "?"), osm=f"{e['type']}/{e['id']}"))
            json.dump(out, open(p, "w"), ensure_ascii=False, indent=0); print(reg, len(out)); break
        except Exception as ex:
            print(reg, srv, ex); time.sleep(5)
