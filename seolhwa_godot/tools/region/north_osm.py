"""data-north 보조: 권역별 OSM Overpass 참고층 → cache/<ID>/osm_*.json (권역 osm_fetch.py와 같은 형식) + osm_names.json(이름 있는 지물 중심점).
실행: python3 tools/region/north_osm.py [ID ...]"""
import json, os, sys, time, urllib.request, urllib.parse
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

def cfg(rid):
    return json.load(open(os.path.join(HERE, "regions", f"{rid}.json")))

def bb(c, m=0.01):
    b = c["osm_bbox"]  # [lat_s, lon_w, lat_n, lon_e] (여백 포함)
    return f"({b[0]},{b[1]},{b[2]},{b[3]})"

def queries(c):
    B = bb(c)
    return {
     "water": (f'way["natural"="water"]{B};relation["natural"="water"]{B};way["landuse"="reservoir"]{B};nwr["waterway"="dam"]{B};nwr["waterway"="weir"]{B};', "geom"),
     "rivers": (f'way["waterway"="river"]{B};way["waterway"~"^(stream|canal)$"]["name"]{B};', "geom"),
     "modern": (f'way["highway"~"^(motorway|trunk|primary|secondary)$"]{B};way["railway"]{B};way["aeroway"]{B};', "geom"),
     "coast": (f'way["natural"="coastline"]{B};', "geom"),
     "walls": (f'way["barrier"="city_wall"]{B};way["historic"~"city_wall|citywalls|fort"]{B};', "geom"),
     "names": (f'nwr["name"]["historic"]{B};nwr["name"]["tourism"]{B};nwr["name"]["natural"~"peak|saddle|cave_entrance|cliff|island|islet"]{B};'
               f'nwr["name"]["place"]{B};nwr["name"]["amenity"="place_of_worship"]{B};nwr["name"]["man_made"="bridge"]{B};nwr["name"]["barrier"="city_wall"]{B};'
               f'nwr["name"]["leisure"="park"]{B};nwr["name"]["building"]["name"~"문|루|정|대|전|궁|사|각"]{B};', "center"),
    }

def fetch(rid, only=None):
    c = cfg(rid); d0 = os.path.join(HERE, "cache", rid); os.makedirs(d0, exist_ok=True)
    for k, (body, mode) in queries(c).items():
        if only and k not in only: continue
        p = os.path.join(d0, f"osm_{k}.json")
        if os.path.exists(p): continue
        for srv in ["https://overpass-api.de/api/interpreter", "https://overpass.kumi.systems/api/interpreter", "https://overpass.private.coffee/api/interpreter"]:
            try:
                q = f"[out:json][timeout:180];({body});out {mode} tags;"
                r = urllib.request.Request(srv, data=urllib.parse.urlencode({"data": q}).encode(), headers={"User-Agent": "seolhwa-terrain-research/0.1"})
                d = json.load(urllib.request.urlopen(r, timeout=200))
                json.dump(d, open(p, "w"), ensure_ascii=False); print(rid, k, len(d["elements"]), flush=True); break
            except Exception as e:
                print(rid, k, srv, e, flush=True); time.sleep(5)

if __name__ == "__main__":
    ids = [a for a in sys.argv[1:] if not a.startswith("--only=")]
    only = next((a[7:].split(",") for a in sys.argv[1:] if a.startswith("--only=")), None)
    for rid in (ids or ["GG_HANYANG", "HH_HWANGJU", "PA_PYEONGYANG", "HG_HAMHEUNG"]):
        fetch(rid, only)
