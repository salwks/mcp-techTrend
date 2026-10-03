"""화면에 집이 많이 드는 길 위 자리 찾기(점검 사진·눈가림 시험용). python3 tools/placement/north_spots.py <id> [group 부분 문자열]"""
import json, sys, os, math
rid = sys.argv[1]; key = sys.argv[2] if len(sys.argv) > 2 else ""
R = os.path.join(os.path.dirname(__file__), "..", "..", "region_data", rid)
d = json.load(open(os.path.join(R, "placement_north.json")))
reg = json.load(open(os.path.join(R, "region.json")))
H = [(i["x"], i["z"]) for i in d["items"] if key in i["group"] and (i["kit"].startswith("culture/") or "sijeon" in i["kit"] or "landmark/" in i["kit"])]
best = []
for r in reg["roads"]:
    p = r["points"]
    for a, b in zip(p[:-1], p[1:]):
        L = math.hypot(b[0]-a[0], b[1]-a[1]); n = max(1, int(L / 6))
        for k in range(n):
            x = a[0] + (b[0]-a[0])*k/n; z = a[1] + (b[1]-a[1])*k/n
            c = sum(1 for hx, hz in H if abs(hx-x) < 20 and -24 < hz-z < 8)
            best.append((c, round(x), round(z), r["id"]))
best.sort(reverse=True)
seen = []
for c, x, z, rd in best:
    if all(math.hypot(x-a, z-b) > 60 for a, b in seen):
        seen.append((x, z)); print(c, x, z, rd)
    if len(seen) >= 8: break
