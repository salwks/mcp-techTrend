"""역참 마방 자리 비워 두기 — 배치 생성기(hubs·north·namwon·east·make_routes)가 쓰기 직전에 부른다.

region_data/stations.json(tools/region/make_stations.py)의 마방 터(27×21m, ry)와 길가 문 앞(9.2×2.6m)에 놓일 물체를 뺀다.
그래서 생성기를 다시 돌려도 마방 자리가 남는다(마방은 placement_stations.json — 생성기가 건드리지 않는 파일).
    import station_reserve; items = station_reserve.keep_clear(space_id, items)
"""
import json
import math
import os

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
PATH = os.path.join(ROOT, "region_data", "stations.json")
PAD = 2.0


def rects(space_id):
    if not os.path.exists(PATH):
        return []
    out = []
    for st in json.load(open(PATH, encoding="utf-8")).get("stations", []):
        if st.get("space") != space_id:
            continue
        w, d = st.get("footprint", [27.0, 21.0])
        out.append((tuple(st["pos"]), float(st.get("ry", 0.0)), w / 2 + PAD, d / 2 + PAD))
        if st.get("hitch"):
            out.append((tuple(st["hitch"]), 0.0, 4.6 + 1.0, 1.3 + 1.0))
    return out


def inside(x, z, rs):
    for (cx, cz), ry, hw, hd in rs:
        dx, dz = x - cx, z - cz
        lx = dx * math.cos(ry) - dz * math.sin(ry)
        lz = dx * math.sin(ry) + dz * math.cos(ry)
        if abs(lx) <= hw and abs(lz) <= hd:
            return True
    return False


def keep_clear(space_id, items):
    rs = rects(space_id)
    if not rs:
        return items
    keep = [it for it in items if not (isinstance(it, dict) and "x" in it and not str(it.get("kit", "")).startswith("station/")
                                       and inside(float(it["x"]), float(it["z"]), rs))]
    if len(keep) != len(items):
        print(f"  station_reserve {space_id}: 마방 자리 물체 {len(items) - len(keep)}개 뺌")
    return keep
