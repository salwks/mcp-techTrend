"""OSM Overpass 참고 자료(현대 지도) 받기 — 하천 중심선·저수지·댐·도로·철도 위치 확인용. 캐시만 쓴다."""
import json, sys, time, urllib.request, urllib.parse, os
BB = "(35.35,127.33,35.49,127.67)"
Q = {
 "water": f'way["natural"="water"]{BB};relation["natural"="water"]{BB};way["landuse"="reservoir"]{BB};nwr["waterway"="dam"]{BB};',
 "rivers": f'way["waterway"="river"]{BB};way["waterway"="stream"]["name"]{BB};',
 "modern": f'way["highway"~"^(motorway|trunk|primary)$"]{BB};way["railway"]{BB};',
}
for k, body in Q.items():
    p = os.path.join(os.path.dirname(__file__), "cache", f"osm_{k}.json")
    if os.path.exists(p): continue
    for srv in ["https://overpass-api.de/api/interpreter", "https://overpass.kumi.systems/api/interpreter"]:
        try:
            q = f"[out:json][timeout:120];({body});out geom tags;"
            r = urllib.request.Request(srv, data=urllib.parse.urlencode({"data": q}).encode(), headers={"User-Agent": "seolhwa-terrain-research/0.1"})
            d = json.load(urllib.request.urlopen(r, timeout=150))
            json.dump(d, open(p, "w"), ensure_ascii=False); print(k, len(d["elements"])); break
        except Exception as e:
            print(k, srv, e); time.sleep(3)
