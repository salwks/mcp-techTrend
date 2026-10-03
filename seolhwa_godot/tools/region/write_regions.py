"""region_data/regions.json에 권역 항목을 넣거나 고친다(다른 에이전트 항목은 그대로 — 쓸 때마다 다시 읽고 합침).
형식(엔진 scripts/region/travel.gd): [{id, name, culture, climate, entry:{x,z}, lat, lon, map_pos:{x,y}(0~1, 경도 124~131·위도 33~43 상자, 위가 0), K, portals}]
사용: python3 tools/region/write_regions.py JL_NAMWON_UNBONG GS_GYEONGJU …"""
import json, math, os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
P = os.path.join(ROOT, "region_data", "regions.json")

def entry(rid):
    cfg = json.load(open(os.path.join(HERE, "regions", rid + ".json"), encoding="utf-8"))
    reg = json.load(open(os.path.join(ROOT, "region_data", rid, "region.json"), encoding="utf-8"))
    pj = reg["projection"]; sp = reg["spawn"]
    lon = pj["lon0"] + sp["x"] / pj["K"] / (math.cos(math.radians(pj["lat0"])) * 111320.0)
    lat = pj["lat0"] - sp["z"] / pj["K"] / 110574.0
    return dict(id=rid, name=reg.get("region_name", cfg.get("name", rid)), culture=cfg.get("culture", ""), climate=cfg.get("climate", ""),
                entry=dict(x=sp["x"], z=sp["z"]), lat=round(lat, 4), lon=round(lon, 4),
                map_pos=dict(x=round((lon - 124.0) / 7.0, 4), y=round((43.0 - lat) / 10.0, 4)), K=pj["K"],
                portals=[dict(id=p["id"], name=p["name"], x=p["x"], z=p["z"], to=p["to"]) for p in reg.get("portals", [])])

if __name__ == "__main__":
    cur = json.load(open(P, encoding="utf-8")) if os.path.exists(P) else []
    lst = cur if isinstance(cur, list) else cur.get("regions", [])
    for rid in sys.argv[1:]:
        e = entry(rid)
        lst = [x for x in lst if x.get("id") != rid] + [e]
    tmp = P + ".tmp"
    out = lst if isinstance(cur, list) else dict(cur, regions=lst)
    json.dump(out, open(tmp, "w", encoding="utf-8"), ensure_ascii=False, indent=1); os.replace(tmp, P)
    print([x["id"] for x in lst])
