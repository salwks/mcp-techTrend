#!/usr/bin/env python3
"""강 뱃길(수운 노정) 생성기 — 한강·남한강(마포→두물머리→여주→목계진→충주), 대동강(평양 대동문→하류→겸이포·황주).

    python3 tools/region/river_routes.py                  # 두 뱃길
    python3 tools/region/river_routes.py RIVER_HANGANG    # 하나만

방식(make_routes.py의 압축 띠를 강에 맞춤 — 명세 §4·5·8·14·25·26·30):
- 띠 x = 강을 따라(한강은 거슬러 오름, 대동강은 내려감), z = 옆. 포구·볼거리마다 실측 DEM 창(terrarium z13, K_h 0.3)을 그 자리
  실제 물길 방향(물 칸 주성분)으로 돌려 놓고, 창마다 실제 물길 가운데·폭을 줄마다 찾아 **실제 물길이 띠의 물길(zc)에 오게** 옆으로 맞춘다.
  물길 안은 실제 폭 → 게임 폭(55~120m)으로, 둑 밖은 K_h로 줄인다(둑이 물가에 바로 붙음). 높이 = (해발 − 그 창 수면) × 0.3.
- 물면은 띠 전체 y = 0 하나(sea.kind = "river" — 엔진 큰 강 모드). 강바닥을 파고 둑은 모래톱·갈대(토지이용 8)로.
- 포구마다 선창(잔교) 둘: 아래쪽 뱃길이 닿는 선창 → 포구 길(창고·객주·주막·장) → 위쪽 뱃길이 떠나는 선창. 뱃길은 선창 사이의 꺾은선
  (route.json river_lanes) — 엔진 scripts/region/river_lanes.gd가 갑판 걷기 면을 깔고 돛배가 저절로 간다(제주 뱃길 auto와 같은 방식, 꺾은선).
- 볼거리(포구 사이 2~3곳): 깊은 소(용왕), 여울(물살 — 배가 느려짐), 강 건너는 나루, 강가 당집, 모래톱, 조창, 벼랑 위 정자, 단구 위 마을.
- 떠가는 배(route.json river_traffic): 뗏목·세곡선·돛배가 물길을 따라 오르내린다(그림만).
DEM 캐시는 make_routes.py와 같다(tools/region/cache/routes/terrarium_z13/).
"""
import json, math, os, sys, zlib
import numpy as np
from PIL import Image
from scipy import ndimage
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_routes as M

CELL = M.CELL
HALF_W = M.HALF_W
KH = 0.3
KV = 0.3
DECK = 0.32
PIER = 13.0        # 선창 길이(뭍 뿌리 → 물 끝)
SAIL = 7.5         # 배 속도(m/s)
TAU = math.tau

def VIA(sight, key, name, title, lat, lon, tales=(), **kw):
    d = dict(sight=sight, key=key, name=name, title=title, lat=lat, lon=lon, tales=list(tales)); d.update(kw); return d

# ---------------------------------------------------------------- 뱃길 정의
# legs[i] = (뱃길 x 길이, [볼거리…]) — 포구 i → 포구 i+1. 포구 pd = 선창 둘 사이 반(포구 길 길이 = 2·pd).
ROUTES = [
 dict(id="RIVER_HANGANG", name="한강·남한강 뱃길(마포→두물머리→여주→목계진→충주)", short="남한강 뱃길", climate="central",
      culture="giho", river_name="한강·남한강", river_id="hangang_namhan", dead_end=True, downstream=-1, osm="osm_river_han.json", osm_exclude=("북한강",),
      frm=M.P("GG_HANYANG", x=-2028.0, z=939.0, inset=22, name="마포 나루(삼개) — 남한강 뱃길 들머리"),
      to=None,
      start=dict(key="mapo", name="마포 상류 선창(남한강 배 떠나는 곳)", title="마포 선창", lat=37.5370, lon=126.9420, a=70, bank="far",
                 tales=[("GH23", "노량진·마포 나루 이야기(경강 나루)", "A"), ("—", "경강 객주·소금배(마포 — 서해 소금·젓갈이 올라오는 곳)", "배경")]),
      ports=[
        dict(key="dumulmeori", name="두물머리 나루(북한강·남한강 합수머리 — 양수리)", title="두물머리", lat=37.5370, lon=127.3150, pd=62, bank="far",
             kind="port", trib=dict(id="bukhangang", name="북한강", width=46.0, lean=-0.35), extra=["zelkova"],
             tales=[("—", "두물머리 — 북한강·남한강 두 물이 만나는 합수머리(지명)", "배경"), ("JG25", "나무도령(큰물에서 살아남은 나무의 아들 — 강가 큰 나무)", "D"),
                    ("YN22", "나루 뱃사공·물귀신", "C")]),
        dict(key="yeoju", name="여주 조포나루(신륵사 아래 — 강월헌 벼랑 정자)", title="여주 조포나루", lat=37.2990, lon=127.6560, pd=62, bank="far",
             kind="port", extra=["pavilion_bluff", "market_small"],
             tales=[("—", "신륵사 마암 용마 — 강에서 나온 용마를 나옹이 신령한 굴레(神勒)로 다스림(절 이름 지명담, 카탈로그 밖)", "B"),
                    ("JG12", "도깨비 씨름(장 보고 오는 밤길)", "D")]),
        dict(key="mokgye", name="목계진(남한강 큰 나루 — 장터·객주·창고·뱃사공)", title="목계진", lat=37.0230, lon=127.8540, pd=88, bank="far",
             kind="port_big",
             tales=[("—", "목계 별신굿(뱃사람·장꾼이 무사·장사 잘되기를 비는 굿)", "배경"), ("JG12", "도깨비 씨름(장터 외곽 밤길)", "D"),
                    ("GH11", "박문수(장터 주막 일화)", "C")]),
      ],
      end=dict(key="chungju", name="충주 나루와 충주 읍성 서문(달천·남한강 — 읍치·장·창고)", title="충주", lat=36.9850, lon=127.9150, a=120, bank="far",
               gate_name="충주 읍성 서문",
               tales=[("GH10", "임경업 — 충주 달천 장군(억울하게 죽어 신이 됨)", "B"), ("—", "충주 감영·목 고을 장시(뱃길 끝)", "배경")]),
      legs=[
        (640, [VIA("side_ferry", "gwangnaru", "광나루(아차산 아래 — 강 건너는 나루)", "광나루", 37.5440, 127.1060,
                   tales=[("GH09", "온달과 평강 — 아차산 온달 이야기", "B"), ("—", "나루 물귀신(뱃사공 이야기)", "D")]),
               VIA("sandbar", "misa", "미사리 모래톱(도미나루 앞 — 강 가운데 모래섬)", "미사리 모래톱", 37.5640, 127.1900,
                   tales=[("GH08", "도미 부인 — 눈먼 남편과 배를 타고 떠난 아내(하남 도미나루)", "B")]),
               VIA("rapids", "dumihyeop", "두미협 여울목(팔당 — 벼랑 사이 물살 센 곳)", "두미협", 37.5230, 127.2650,
                   tales=[("YN22", "여울 물귀신(배 뒤집는 여울)", "C"), ("JG11", "도깨비 둑·도깨비 다리", "D")])]),
        (680, [VIA("hamlet", "yanggeun", "양근 강가 단구 마을(용문산 바라봄)", "양근", 37.4900, 127.4900,
                   tales=[("JG07", "우렁각시(논·외딴집)", "D")]),
               VIA("side_ferry", "ipo", "이포나루(강 건너는 큰 나루)", "이포나루", 37.4050, 127.5400,
                   tales=[("—", "나루 물귀신(뱃사공 이야기)", "D")]),
               VIA("deep_pool", "pasa", "파사성 벼랑 아래 깊은 소", "파사성 소", 37.3850, 127.5560,
                   tales=[("JG20", "용소·이무기 승천(깊은 소)", "C"), ("—", "용왕(배가 지날 때 비손하는 소)", "D")])]),
        (640, [VIA("jochang", "heungwon", "흥원창(섬강 어귀 조창 — 세곡 싣는 곳)", "흥원창", 37.2700, 127.7700,
                   tales=[("—", "흥원창 — 원주·강원 세곡을 모아 경창으로 보내던 조창(배경)", "배경"), ("YN22", "뱃사공·물귀신", "C")]),
               VIA("shrine", "burondang", "부론 강가 당집(뱃사람 비는 서낭)", "부론 당집", 37.2150, 127.8000,
                   tales=[("JG33", "성황당 돌무더기(뱃길 서낭)", "D"), ("—", "용왕(뱃길 비손)", "D")])]),
        (560, [VIA("pavilion", "tangeumdae", "탄금대(달천 어귀 벼랑 — 우륵이 가야금을 탄 대)", "탄금대", 36.9960, 127.9000,
                   tales=[("—", "탄금대 — 우륵이 가야금을 탄 대(지명담)", "B"), ("—", "열두대(벼랑에서 강으로 — 임진년 싸움 이야기)", "C")]),
               VIA("side_ferry", "dalcheon", "달천 나루(달래강 어귀)", "달천 나루", 36.9800, 127.9050,
                   tales=[("GH10", "임경업 — 충주 달천(나루·강)", "B"), ("—", "나루 물귀신", "D")])]),
      ],
      traffic=[dict(kit="route/tteotmok", params={"len": 13.0}, side=-0.30, speed=-2.2, phase=0.15, name="뗏목(강원 산판 → 한양)"),
               dict(kit="route/tteotmok", params={"len": 10.0, "logs": 8}, side=-0.26, speed=-2.0, phase=0.62, name="뗏목"),
               dict(kit="route/jounseon", params={"len": 15.0}, side=-0.22, speed=-3.2, phase=0.40, name="세곡선(흥원창·가흥창 → 경창)"),
               dict(kit="route/jounseon", params={"len": 13.0, "sail": False}, side=-0.24, speed=-2.8, phase=0.86, name="세곡선"),
               dict(kit="route/dotbae", params={"len": 9.0}, side=0.33, speed=3.0, phase=0.30, name="장삿배(소금·젓갈 싣고 오름)")]),
 dict(id="RIVER_DAEDONGGANG", name="대동강 뱃길(평양 대동문→두로도 포구→겸이포·황주)", short="대동강 뱃길", climate="north",
      culture="gwanseo", river_name="대동강", river_id="daedonggang", dead_end=False, downstream=1, osm="osm_river_daedong.json",
      frm=M.P("PA_PYEONGYANG", x=172.0, z=156.0, name="대동문 앞 아래 선창(대동강 뱃길)"),
      to={"region": "HH_HWANGJU", "x": -2500.0, "z": -1590.0, "name": "겸이포 나루길(대동강 뱃길)"},
      start=dict(key="daedongmun", name="대동문 아래 선창(평양 — 배 떠나는 곳)", title="대동문 선창", lat=39.0130, lon=125.7560, a=70, bank="near",
                 tales=[("GS04", "봉이 김선달 — 대동강 물을 판 건달(나루·장터 구비 일화)", "A"), ("GS07", "을밀대·부벽루(강가 누정)", "A")]),
      ports=[
        dict(key="duro", name="두로도 포구(대동강 가운데 섬 앞 — 가설 자리)", title="두로도 포구", lat=38.9300, lon=125.6800, pd=60, bank="far", frac=0.47,
             kind="port", culture="gwanseo", extra=["market_small"],
             tales=[("—", "대동강 포구 — 평양 장배·소금배가 쉬어 가는 곳(배경)", "배경"), ("YN22", "뱃사공·물귀신", "C")]),
      ],
      end=dict(key="gyeomipo", name="겸이포 포구(황주 서쪽 대동강 나루 — 황주·재령 곡식 싣는 곳)", title="겸이포", lat=38.7450, lon=125.6250, a=110, bank="far",
               culture="haeseo",
               tales=[("HS02", "심청 — 황주 도화동(소설 배경)·인당수 가는 뱃길", "B"), ("—", "겸이포 — 황주 곡식 싣는 포구(배경)", "배경")]),
      legs=[
        (700, [VIA("sandbar", "yanggak_sand", "양각도 아래 모래섬(능라도·양각도 아랫물)", "양각도 모래섬", 38.9900, 125.7320,
                   tales=[("—", "대동강 섬(능라도·양각도) — 평양 강 풍경(배경)", "배경"), ("—", "물새·갈대 모래섬", "D")]),
               VIA("shrine", "yongwangdang", "강가 용왕당(뱃사람 비는 당)", "용왕당", 38.9600, 125.7050,
                   tales=[("—", "용왕(뱃길 무사 비손)", "D"), ("JG33", "성황당 돌무더기", "D")])]),
        (700, [VIA("deep_pool", "daedong_so", "대동강 깊은 소(물빛 검은 곳)", "깊은 소", 38.8650, 125.6550,
                   tales=[("JG20", "용소·이무기 승천", "C"), ("—", "용왕·물귀신(배 끄는 소)", "D")]),
               VIA("side_ferry", "gangseo_naru", "강서 나루(대동강 건너는 나루)", "강서 나루", 38.8250, 125.6400,
                   tales=[("—", "나루 물귀신(뱃사공 이야기)", "D")]),
               VIA("sandbar", "ebb_sand", "썰물 모래톱(밀물·썰물이 드나드는 아랫강)", "썰물 모래톱", 38.7800, 125.6300,
                   tales=[("—", "밀물·썰물 — 바다 가까운 강(배경)", "배경"), ("JG30", "소금 나오는 맷돌(바다로 가는 배)", "D")])]),
      ],
      traffic=[dict(kit="route/jounseon", params={"len": 14.0}, side=-0.28, speed=2.6, phase=0.2, name="세곡선(황주·재령 곡식)"),
               dict(kit="route/dotbae", params={"len": 9.0}, side=0.30, speed=-2.8, phase=0.55, name="장삿배(평양 오름)"),
               dict(kit="route/tteotmok", params={"len": 10.0, "logs": 8}, side=-0.22, speed=1.8, phase=0.8, name="뗏목")]),
]

# ---------------------------------------------------------------- 실측 물길 찾기
def _frame(lat, lon, b, U, V):
    """창 좌표 (u 앞, v 오른쪽) → 경위도"""
    de, dn = math.sin(b), math.cos(b); re, rn = math.cos(b), -math.sin(b)
    east = U * de + V * re; north = U * dn + V * rn
    return M.geo_offset(lat, lon, east, north)

TILES_LO = os.path.join(M.HERE, "cache", "routes", "terrarium_z11")
_tlo = {}
def dem_lo(lat, lon, Z=11):
    """물길 따라가기용 거친 DEM(terrarium z11, 약 60m) — make_routes.dem과 같은 방식, 캐시 따로"""
    lat = np.asarray(lat, np.float64); lon = np.asarray(lon, np.float64)
    n = 2 ** Z
    tx = (lon + 180.0) / 360.0 * n; r = np.radians(lat); ty = (1 - np.log(np.tan(r) + 1 / np.cos(r)) / np.pi) / 2 * n
    x0, x1 = int(np.floor(tx.min())), int(np.floor(tx.max())); y0, y1 = int(np.floor(ty.min())), int(np.floor(ty.max()))
    os.makedirs(TILES_LO, exist_ok=True)
    mos = np.zeros(((y1 - y0 + 1) * 256, (x1 - x0 + 1) * 256), np.float32)
    import urllib.request
    for x in range(x0, x1 + 1):
        for y in range(y0, y1 + 1):
            pth = os.path.join(TILES_LO, f"{x}_{y}.png")
            if not os.path.exists(pth): urllib.request.urlretrieve(M.URL.format(z=Z, x=x, y=y), pth)
            if (x, y) not in _tlo:
                a = np.asarray(Image.open(pth).convert("RGB"), np.float32); _tlo[(x, y)] = a[..., 0] * 256 + a[..., 1] + a[..., 2] / 256 - 32768
            mos[(y - y0) * 256:(y - y0 + 1) * 256, (x - x0) * 256:(x - x0 + 1) * 256] = _tlo[(x, y)]
    return ndimage.map_coordinates(mos, [(ty - y0) * 256 - 0.5, (tx - x0) * 256 - 0.5], order=1, mode="nearest").astype(np.float32)

def trace_river(a, b, step=70.0):
    """두 경위도 사이 실제 큰 물길 가운데(낮은 골을 따라가는 최소 비용 경로, 8방향 Dijkstra). 돌려주는 값: [(lat, lon)…] a→b"""
    from scipy.sparse import coo_matrix
    from scipy.sparse.csgraph import dijkstra
    la0, la1 = min(a[0], b[0]) - 0.07, max(a[0], b[0]) + 0.07
    lo0, lo1 = min(a[1], b[1]) - 0.09, max(a[1], b[1]) + 0.09
    ny = int((la1 - la0) * 110574 / step) + 1; nx = int((lo1 - lo0) * 111320 * math.cos(math.radians((la0 + la1) / 2)) / step) + 1
    LA, LO = np.meshgrid(np.linspace(la1, la0, ny), np.linspace(lo0, lo1, nx), indexing="ij")
    h = dem_lo(LA, LO)
    low = ndimage.minimum_filter(h, size=35)
    cost = 1.0 + 40.0 * np.clip(h - low, 0, 30) + 0.0
    def cell(p):
        j = int(round((la1 - p[0]) / (la1 - la0) * (ny - 1))); i = int(round((p[1] - lo0) / (lo1 - lo0) * (nx - 1)))
        r = 12; jj = slice(max(j - r, 0), j + r + 1); ii = slice(max(i - r, 0), i + r + 1)
        sub = h[jj, ii]; k = np.unravel_index(int(np.argmin(sub)), sub.shape)
        return (jj.start + k[0]) * nx + (ii.start + k[1])
    idx = np.arange(ny * nx).reshape(ny, nx)
    rows, cols, ws = [], [], []
    for dj, di in ((0, 1), (1, 0), (1, 1), (1, -1)):
        if di >= 0: A = idx[0:ny - dj, 0:nx - di]; B = idx[dj:ny, di:nx]
        else: A = idx[0:ny - dj, -di:nx]; B = idx[dj:ny, 0:nx + di]
        ca = cost.ravel()[A.ravel()]; cb = cost.ravel()[B.ravel()]
        w = (ca + cb) * 0.5 * math.hypot(dj, di)
        rows += [A.ravel(), B.ravel()]; cols += [B.ravel(), A.ravel()]; ws += [w, w]
    G = coo_matrix((np.concatenate(ws), (np.concatenate(rows), np.concatenate(cols))), shape=(ny * nx, ny * nx)).tocsr()
    s0, s1 = cell(a), cell(b)
    _, pred = dijkstra(G, indices=s0, return_predecessors=True)
    path = [s1]
    while path[-1] != s0 and path[-1] >= 0: path.append(int(pred[path[-1]]))
    path = path[::-1]
    pj = np.array([p // nx for p in path], float); pi = np.array([p % nx for p in path], float)
    pj = ndimage.gaussian_filter1d(pj, 3, mode="nearest"); pi = ndimage.gaussian_filter1d(pi, 3, mode="nearest")
    lat = la1 - pj / (ny - 1) * (la1 - la0); lon = lo0 + pi / (nx - 1) * (lo1 - lo0)
    return list(zip(lat.tolist(), lon.tolist()))

_osm = {}
OSM_Q = {"osm_river_daedong.json": 'way["waterway"="river"]["name"~"대동강"](38.6,125.3,39.1,125.9);',
         "osm_river_han.json": 'way["waterway"="river"]["name"~"한강"](36.9,126.85,37.62,127.98);'}
def osm_path(fn, a, b, exclude=()):
    """OSM waterway=river 선(캐시 tools/region/cache/routes/<fn>)을 이어 a→b 물길 가운데 선. 없으면 None"""
    pth = os.path.join(M.HERE, "cache", "routes", fn)
    if not os.path.exists(pth) and fn in OSM_Q:   # 캐시가 없으면 Overpass에서 받는다(OSM 현대 물길 — 위치 확인용)
        import urllib.request, urllib.parse
        for srv in ["https://overpass-api.de/api/interpreter", "https://maps.mail.ru/osm/tools/overpass/api/interpreter", "https://overpass.kumi.systems/api/interpreter"]:
            try:
                q = f"[out:json][timeout:90];({OSM_Q[fn]});out geom tags;"
                rq = urllib.request.Request(srv, data=urllib.parse.urlencode({"data": q}).encode(), headers={"User-Agent": "seolhwa-terrain-research/0.1"})
                d = json.load(urllib.request.urlopen(rq, timeout=100))
                os.makedirs(os.path.dirname(pth), exist_ok=True); json.dump(d, open(pth, "w"), ensure_ascii=False); break
            except Exception as e: print("  overpass", srv, e)
    if not os.path.exists(pth): return None
    if fn not in _osm:
        d = json.load(open(pth))
        nodes = {}; adj = {}
        def nid(p):
            k = (round(p["lat"], 6), round(p["lon"], 6))
            if k not in nodes: nodes[k] = len(nodes)
            return nodes[k]
        for e in d["elements"]:
            if e.get("tags", {}).get("name", "") in exclude or "geometry" not in e: continue
            g = e["geometry"]
            for p, q in zip(g[:-1], g[1:]):
                i, j = nid(p), nid(q); w = M.dist_m((p["lat"], p["lon"]), (q["lat"], q["lon"]))
                adj.setdefault(i, []).append((j, w)); adj.setdefault(j, []).append((i, w))
        _osm[fn] = (list(nodes.keys()), adj)
    keys, adj = _osm[fn]
    P_ = np.array(keys)
    def near(p): return int(np.argmin((P_[:, 0] - p[0]) ** 2 + ((P_[:, 1] - p[1]) * 0.8) ** 2))
    s0, s1 = near(a), near(b)
    import heapq
    dist = {s0: 0.0}; prev = {}; hq = [(0.0, s0)]
    while hq:
        dd, u = heapq.heappop(hq)
        if u == s1: break
        if dd > dist.get(u, 1e18): continue
        for v, w in adj.get(u, []):
            nd = dd + w
            if nd < dist.get(v, 1e18): dist[v] = nd; prev[v] = u; heapq.heappush(hq, (nd, v))
    if s1 not in prev and s1 != s0: return None
    path = [s1]
    while path[-1] != s0: path.append(prev[path[-1]])
    pts = [tuple(P_[k]) for k in path[::-1]]
    # 고르게(약 150m) 다시 뽑고 살짝 매끄럽게
    cum = geo_cum(pts); ts = np.arange(0, cum[-1], 150.0)
    la = ndimage.gaussian_filter1d(np.interp(ts, cum, [p[0] for p in pts]), 1.5, mode="nearest")
    lo = ndimage.gaussian_filter1d(np.interp(ts, cum, [p[1] for p in pts]), 1.5, mode="nearest")
    return list(zip(la.tolist(), lo.tolist())) + [pts[-1]]

def geo_cum(line):
    d = [0.0]
    for p, q in zip(line[:-1], line[1:]): d.append(d[-1] + M.dist_m(p, q))
    return np.array(d)

def line_at(line, cum, t):
    """물길 선 위 길이 t(m) 자리와 그 자리 방향(±700m 평균)"""
    t = float(np.clip(t, 0, cum[-1]))
    la = float(np.interp(t, cum, [p[0] for p in line])); lo = float(np.interp(t, cum, [p[1] for p in line]))
    t0, t1 = max(t - 700, 0), min(t + 700, cum[-1])
    a = (float(np.interp(t0, cum, [p[0] for p in line])), float(np.interp(t0, cum, [p[1] for p in line])))
    b = (float(np.interp(t1, cum, [p[0] for p in line])), float(np.interp(t1, cum, [p[1] for p in line])))
    return la, lo, M.bearing(a, b)

def nearest_t(line, cum, p):
    d = [M.dist_m(q, p) for q in line]
    k = int(np.argmin(d)); return float(cum[k]), float(d[k])

def track_river(w, U0, U1):
    """창 안 줄(u)마다 실제 물길 가운데 c(u)·폭 Wr(u)(실제 m). 물 면 = 창 가운데 둘레 낮은 값"""
    st = 15.0
    us = np.arange(U0, U1 + 1, st); vs = np.arange(-1800, 1801, st)
    UU, VV = np.meshgrid(us, vs, indexing="ij")
    la, lo = _frame(w["lat"], w["lon"], w["bear"], UU, VV)
    E = M.dem(la, lo)
    i0 = int(np.argmin(np.abs(us)))
    band = (np.abs(us) < 400)[:, None] & (np.abs(vs) < 700)[None, :]
    wl = float(np.percentile(E[band], 3))
    m = E <= wl + 1.6
    c = np.zeros(len(us)); W = np.zeros(len(us))
    def runs(row):
        out = []; j = 0
        while j < len(row):
            if row[j]:
                k = j
                while k < len(row) and row[k]: k += 1
                out.append((vs[j], vs[k - 1])); j = k
            else: j += 1
        return out
    def pick(i, prev):
        rs = [r for r in runs(m[i]) if r[1] - r[0] >= 30]
        if not rs: return None
        cands = [((a + b) / 2, b - a + st) for a, b in rs if a - 250 <= prev <= b + 250]
        if not cands: return None
        return min(cands, key=lambda t: abs(t[0] - prev))
    r0 = pick(i0, 0.0) or (0.0, 400.0)
    c[i0], W[i0] = r0
    for rng_ in (range(i0 + 1, len(us)), range(i0 - 1, -1, -1)):
        prev_i = i0
        for i in rng_:
            r = pick(i, c[prev_i])
            if r is None: c[i], W[i] = c[prev_i], W[prev_i]
            else: c[i], W[i] = r
            prev_i = i
    c = ndimage.gaussian_filter1d(c, 3); W = ndimage.gaussian_filter1d(np.clip(W, 120, 1400), 3)
    w["wl"] = wl; w["track"] = (us, c, W)
    return wl

def w_track(w, u):
    us, c, W = w["track"]
    return np.interp(u, us, c), np.interp(u, us, W)

# ---------------------------------------------------------------- 띠 지형
def build(R):
    rid = R["id"]
    out = os.path.join(M.OUT_ROOT, rid); os.makedirs(out, exist_ok=True)
    # 창 차례: 시작(선창) · 볼거리 · 포구 · … · 끝. x 자리는 뱃길 길이로
    S = []
    st = dict(R["start"]); st.update(kind="start"); S.append(st)
    pos = 52.0                          # 시작 선창 x
    st["x"] = 0.0; st["pier"] = pos
    piers = [pos]                       # 뱃길 사이 선창 x(떠나는 곳, 닿는 곳 …)
    legs = []
    ports = R["ports"] + [None]
    for li, (L, sights) in enumerate(R["legs"]):
        x0 = pos
        n = len(sights)
        for k, v in enumerate(sights):
            d = dict(v); d.update(kind="via", x=x0 + L * (k + 0.5) / n, a=42.0, leg=li); S.append(d)
        pos = x0 + L
        legs.append(dict(xa=x0, xb=pos, sights=[v["key"] for v in sights]))
        pt = ports[li]
        if pt is not None:
            d = dict(pt); d["x"] = pos + pt["pd"]; d["a"] = pt["pd"] + 40.0; d["xa"] = pos; d["xb"] = pos + 2 * pt["pd"]
            S.append(d); pos = d["xb"]
        else:
            e = dict(R["end"]); e.update(kind="end", x=pos + 100.0, xa=pos); S.append(e)
    end = S[-1]
    X0 = -70.0; X1 = end["x"] + end["a"] + 30.0
    # 실측 물길 따라가기: 믿을 만한 자리(시작·포구·끝)를 이어 큰 물길 가운데 선을 찾고, 창은 그 선 위에(방향 = 선 방향)
    n = len(S)
    anchors = [w for w in S if w["kind"] != "via" and "frac" not in w]
    line = [(anchors[0]["lat"], anchors[0]["lon"])]
    for A_, B_ in zip(anchors[:-1], anchors[1:]):
        seg_ = osm_path(R["osm"], line[-1], (B_["lat"], B_["lon"]), R.get("osm_exclude", ())) if R.get("osm") else None
        if seg_ is None: seg_ = trace_river(line[-1], (B_["lat"], B_["lon"]))
        line += seg_[1:]
    cum = geo_cum(line)
    for w in anchors: w["t"] = nearest_t(line, cum, (w["lat"], w["lon"]))[0]
    for w in S:
        if "frac" in w: w["t"] = w["frac"] * cum[-1]
    # 볼거리: 앞뒤 포구 사이 선 위 가장 가까운 자리(4km 넘게 떨어지면 칸 비율), 차례는 지킨다
    for li in range(len(legs)):
        lo_w = [w for w in S if w["kind"] != "via"][li]; hi_w = [w for w in S if w["kind"] != "via"][li + 1]
        vs_ = [w for w in S if w["kind"] == "via" and w["leg"] == li]
        L_ = hi_w["t"] - lo_w["t"]
        last = lo_w["t"] + 0.08 * L_
        for k, w in enumerate(vs_):
            t_, d_ = nearest_t(line, cum, (w["lat"], w["lon"]))
            if d_ > 4000 or not (lo_w["t"] < t_ < hi_w["t"]): t_ = lo_w["t"] + L_ * (k + 0.5) / len(vs_)
            t_ = float(np.clip(t_, last, hi_w["t"] - 0.08 * L_ * (len(vs_) - k)))
            w["t"] = t_; last = t_ + 0.12 * L_
    for w in S:
        w.setdefault("culture", R["culture"]); w.setdefault("a", 60.0)
        w["lat"], w["lon"], w["bear"] = line_at(line, cum, w["t"])
        if "bearing_deg" in w: w["bear"] = math.radians(w["bearing_deg"])
    R["_line"] = line
    for i, w in enumerate(S):
        lo_x = (S[i - 1]["x"] - S[i - 1]["a"]) if i > 0 else X0
        hi_x = (S[i + 1]["x"] + S[i + 1]["a"]) if i + 1 < n else X1
        track_river(w, (lo_x - w["x"]) / KH - 60, (hi_x - w["x"]) / KH + 60)
        w["alt"] = w["wl"]
        print(f"  {w['key']:12s} x={w['x']:7.1f} bear={math.degrees(w['bear']):6.1f} wl={w['wl']:6.1f} Wr0={w_track(w, 0)[1]:5.0f}")
    W_ = int(round((X1 - X0) / CELL)) + 1; H_ = int(round(2 * HALF_W / CELL)) + 1
    gx = X0 + np.arange(W_) * CELL; gz = -HALF_W + np.arange(H_) * CELL
    # 창 가중치(열마다) — make_routes와 같은 smoothstep
    wts = np.zeros((n, W_), np.float32)
    for i, s in enumerate(S):
        lo_c = s["x"] - s["a"]; hi_c = s["x"] + s["a"]
        w = ((gx >= lo_c) & (gx <= hi_c)).astype(np.float32)
        if i > 0:
            pe = S[i - 1]["x"] + S[i - 1]["a"]; mm = (gx > pe) & (gx < lo_c); w[mm] = M.smoothstep((gx[mm] - pe) / max(lo_c - pe, 1.0))
        else: w[gx < lo_c] = 1.0
        if i < n - 1:
            ns = S[i + 1]["x"] - S[i + 1]["a"]; mm = (gx > hi_c) & (gx < ns); w[mm] = 1.0 - M.smoothstep((gx[mm] - hi_c) / max(ns - hi_c, 1.0))
        else: w[gx > hi_c] = 1.0
        wts[i] = w
    wts /= np.maximum(wts.sum(0, keepdims=True), 1e-6)
    core = np.zeros(W_, np.float32)
    for s in S: core = np.maximum(core, ((gx >= s["x"] - s["a"]) & (gx <= s["x"] + s["a"])).astype(np.float32))
    core = ndimage.uniform_filter1d(core, 40)
    # 게임 물길 폭 Wg(x)와 가운데 zc(x): 창 안 실제 굽이(K_h) + 창 사이 잔 굽이
    rng = np.random.default_rng(zlib.crc32(rid.encode()))
    Wg = np.zeros(W_)
    for i, s in enumerate(S):
        u = (gx - s["x"]) / KH
        _, Wr = w_track(s, u)
        wi = np.clip(50.0 + Wr * 0.06, 56.0, 116.0)
        if "wg" in s: wi = np.full(W_, float(s["wg"]))
        if s.get("sight") == "rapids":   # 여울목: 벼랑 사이로 좁아진다
            wi = np.minimum(wi, 46.0 + 60.0 * M.smoothstep((np.abs(gx - s["x"]) - 40.0) / 120.0))
        Wg += wts[i] * wi
    Wg *= 1.0 + 0.13 * np.sin(gx / 160.0 + rng.random() * TAU) * np.sin(gx / 530.0 + 1.3)   # 폭이 늘 같지 않게(명세 §6)
    Wg = ndimage.gaussian_filter1d(Wg, 12)
    g = np.zeros(W_)
    for i, s in enumerate(S):
        u = (gx - s["x"]) / KH
        c, _ = w_track(s, u); c0, _ = w_track(s, 0.0)
        g += wts[i] * np.clip(KH * (c - c0), -45, 45)
    ph = rng.random() * TAU
    meander = 34.0 * np.sin(gx / 115.0 + ph) * np.sin(gx / 410.0 + ph * 0.7)
    zc = g + (1.0 - core) * meander
    zc = ndimage.gaussian_filter1d(zc, 10)
    zc = np.clip(zc, -HALF_W + Wg / 2 + 95, HALF_W - Wg / 2 - 75)
    for s in S:
        s["zc"] = float(np.interp(s["x"], gx, zc)); s["wg"] = float(np.interp(s["x"], gx, Wg))
    # 높이: 창마다 실제 물길을 zc에, 물길 안은 Wr→Wg, 둑 밖은 K_h
    T = np.zeros((H_, W_), np.float32)
    for i, s in enumerate(S):
        cols = np.nonzero(wts[i] > 0)[0]
        if cols.size == 0: continue
        XX, ZZ = np.meshgrid(gx[cols], gz)
        u = (XX - s["x"]) / KH
        c, Wr = w_track(s, u)
        Wgc = Wg[cols][None, :]
        d = ZZ - zc[cols][None, :]
        ad = np.abs(d)
        v = np.where(ad < Wgc / 2, d * Wr / Wgc, np.sign(d) * (Wr / 2 + (ad - Wgc / 2) / KH)) + c
        la, lo = _frame(s["lat"], s["lon"], s["bear"], u, v)
        y = (M.dem(la, lo) - s["wl"]) * KV
        T[:, cols] += wts[i][cols][None, :] * y
    T = np.clip(T, -1.0, 75.0)
    ZC = zc[None, :]; WG = Wg[None, :]
    # 물가 선을 조금 들쑥날쑥하게(양쪽 따로): 물길 가운데에서 잰 거리에 잔 굽이를 더한다
    nb_far = ndimage.gaussian_filter1d(rng.standard_normal(W_), 9) * 14.0
    nb_near = ndimage.gaussian_filter1d(rng.standard_normal(W_), 9) * 14.0
    quiet = np.ones(W_)
    for s in S:   # 선창·포구 둘레는 물가 선을 곧게(선창 뿌리가 뭍에 걸리게)
        if s["kind"] == "via": continue
        lo_ = (s["pier"] - 40) if s["kind"] == "start" else s["xa"] - 40
        hi_ = (s["pier"] + 40) if s["kind"] == "start" else (s.get("xb", s["xa"]) + 40 if s["kind"] != "end" else X1)
        quiet = np.minimum(quiet, 1.0 - ((gx > lo_) & (gx < hi_)))
    quiet = ndimage.uniform_filter1d(quiet, 15)
    nb_far *= quiet; nb_near *= quiet
    D = gz[:, None] - ZC
    D = D - np.where(D < 0, -nb_far[None, :], nb_near[None, :]) * np.clip(np.abs(D) / (WG / 2), 0, 1)
    AD = np.abs(D)
    # 잔물결(아주 약하게)
    nz = ndimage.gaussian_filter(rng.standard_normal((H_, W_)).astype(np.float32), 6) * 5.0
    T += nz * np.clip(T / 6.0, 0, 1)
    # 둑: 물가는 모래톱처럼 낮게 이어 오르고(물 면 아래 뭍은 없음), 카메라 쪽(+z) 둑은 낮게(배에서 먼 둑이 보이게)
    edge = AD - WG / 2
    T = np.where(edge >= 0, np.maximum(T, 0.3 + 0.05 * np.minimum(edge, 20.0)), T)
    T = np.where(D > WG / 2, np.minimum(T, 1.0 + 0.35 * (D - WG / 2)), T)
    # 강바닥(가운데 깊게) + 갈래 물(지류)
    bed = -0.35 - 2.9 * M.smoothstep((1.0 - AD / (WG / 2)) / 0.4)
    water = AD < WG / 2
    T = np.where(water, np.minimum(T, bed), T).astype(np.float32)
    rivers_extra = []
    XX, ZZ = np.meshgrid(gx, gz)
    for s in S:
        tb = s.get("trib")
        if not tb: continue
        xs_ = s["xa"] - 40.0      # 합수머리: 포구(갈래 사이 혀 땅) 바로 아래에서 갈래 물이 들어온다
        p0 = np.array([xs_, s["zc"] - s["wg"] / 2 + 6.0]); p1 = np.array([xs_ + tb["lean"] * 260.0, -HALF_W - 10.0])
        ctrl = [p0 + (p1 - p0) * k / 5.0 + np.array([(18.0 * math.sin(k * 1.7 + 0.5)) if 0 < k < 5 else 0.0, 0.0]) for k in range(6)]
        tpts = np.array(M.catmull([tuple(c_) for c_ in ctrl], 2.0))
        from scipy.spatial import cKDTree as _KD
        dd, ki = _KD(tpts).query(np.stack([XX.ravel(), ZZ.ravel()], 1))
        dd = dd.reshape(XX.shape); tfrac = (ki.reshape(XX.shape) / max(len(tpts) - 1, 1))
        wt = tb["width"] * (1.0 - 0.25 * tfrac)        # 위로 갈수록 조금 좁게
        tbed = -0.35 - 2.2 * M.smoothstep((1.0 - dd / (wt / 2)) / 0.4)
        e2 = dd - wt / 2
        T = np.where(dd < wt / 2, np.minimum(T, tbed), np.where(e2 < 20, np.minimum(T, 0.3 + 0.2 * e2), T)).astype(np.float32)
        water |= dd < wt / 2
        pts_ = [[round(float(q[0]), 1), round(float(q[1]), 1), 0.0] for q in tpts[::-8][::1]]
        rivers_extra.append(dict(id=tb["id"], name=tb["name"], grade="B", spec_grade="S", render=False, width_m=tb["width"], points=pts_,
                                 flows_to=R["river_id"], note="갈래 물(합수머리) — 엔진 큰 강 모드 흐름 방향용 중심선(하류 순)"))
        s["trib_xz"] = (p0, p1)
    lane_z = zc + 0.12 * Wg
    # ---- 볼거리별 물 지형(모래섬·깊은 소)
    islands = []
    for s in S:
        if s.get("sight") == "sandbar":
            cx, cz = s["x"] + 10.0, s["zc"] - 0.24 * s["wg"]
            rx, rz = 70.0, max(0.13 * s["wg"], 9.0)
            ell = ((XX - cx) / rx) ** 2 + ((ZZ - cz) / rz) ** 2
            T = np.where(ell < 1.0, np.maximum(T, 0.35 + 0.5 * (1 - ell)), T).astype(np.float32)
            water &= ~(ell < 1.0)
            islands.append((cx, cz, rx, rz)); s["island"] = (cx, cz, rx, rz)
        if s.get("sight") == "deep_pool":
            cx, cz = s["x"], s["zc"] - 0.18 * s["wg"]
            ell = ((XX - cx) / 60.0) ** 2 + ((ZZ - cz) / (0.3 * s["wg"])) ** 2
            T = np.where((ell < 1.0) & water, np.minimum(T, -3.4 - 2.6 * (1 - ell)), T).astype(np.float32)
    # ---- 선창·뱃길·길
    def zr(x): return float(np.interp(x, gx, zc))
    def wg(x): return float(np.interp(x, gx, Wg))
    def bank_z(x, side): return zr(x) - wg(x) / 2 if side == "far" else zr(x) + wg(x) / 2
    def road_z(x, side): return bank_z(x, side) - 32.0 if side == "far" else bank_z(x, side) + 30.0
    def pier_pts(x, side):
        sg = 1.0 if side == "far" else -1.0          # 물 쪽 방향(z): 먼 둑이면 +z
        root = bank_z(x, side) - sg * 4.0; tip = root + sg * PIER
        return root, tip, sg
    sides = []   # 선창 차례(뱃길 끝)대로 둑
    sides.append(S[0]["bank"])
    for s in S:
        if s["kind"] in ("port", "port_big"): sides += [s["bank"], s["bank"]]
        if s["kind"] == "end": sides.append(s["bank"])
    pier_x = [S[0]["pier"]]
    for s in S:
        if s["kind"] in ("port", "port_big"): pier_x += [s["xa"], s["xb"]]
        if s["kind"] == "end": pier_x.append(s["xa"])
    lanes = []
    for li, lg in enumerate(legs):
        xa, xb = pier_x[2 * li], pier_x[2 * li + 1]
        sa, sb = sides[2 * li], sides[2 * li + 1]
        _, ta, ga = pier_pts(xa, sa); _, tb_, gb = pier_pts(xb, sb)
        # 선창 끝에서 처음·마지막 16m는 선창과 한 줄로 곧게(걷기 면이 선창 위로 이어지게)
        ctrl = [(xa, ta), (xa, ta + ga * 8.0), (xa, ta + ga * 16.0), (xa + 38, float(np.interp(xa + 38, gx, lane_z)))]
        xx = xa + 70
        while xx < xb - 60:
            ctrl.append((xx, float(np.interp(xx, gx, lane_z)))); xx += 40.0
        ctrl += [(xb - 38, float(np.interp(xb - 38, gx, lane_z))), (xb, tb_ + gb * 16.0), (xb, tb_ + gb * 8.0), (xb, tb_)]
        pts = M.catmull(ctrl, 2.0)
        dense_l, s_l = M.densify(pts, 1.0)
        lanes.append(dict(xa=xa, xb=xb, pts=dense_l, s=s_l, sa=sa, sb=sb))
    # 뱃길 따라 물을 깊게(모래섬·여울 바위 둘레도 배가 지나게)
    lane_all = np.vstack([l["pts"] for l in lanes])
    from scipy.spatial import cKDTree
    lt = cKDTree(lane_all)
    dl, _ = lt.query(np.stack([XX.ravel(), ZZ.ravel()], 1), distance_upper_bound=12.0)
    dl = dl.reshape(XX.shape)
    near_lane = dl < 7.0
    T = np.where(near_lane, np.minimum(T, -1.4), T).astype(np.float32)
    water |= near_lane
    # 길(뭍): 시작 → 선창 / 포구: 선창 → 포구 길 → 선창 / 끝: 선창 → 끝(성문)
    land = []   # (점들, 선창 뿌리 두 끝 표시)
    def pier_leg(x, side, inward):
        root, tip, sg = pier_pts(x, side)
        rzz = road_z(x, side)
        return [(x, rzz + sg * 9.0), (x, root)] if inward else [(x, root), (x, rzz + sg * 9.0)]
    main = []
    # 시작
    s0 = S[0]; side0 = s0["bank"]
    xs_ = np.arange(X0 + 8.0, s0["pier"] - 14.0, 6.0)
    seg = [(float(x), road_z(float(x), side0)) for x in xs_] + pier_leg(s0["pier"], side0, True)
    land.append(np.array(M.catmull(seg, 2.0)))
    main.append(("land", land[-1]))
    li_ = 0
    for s in S:
        if s["kind"] in ("port", "port_big", "end"):
            main.append(("lane", lanes[li_]["pts"])); li_ += 1
            side = s["bank"]
            if s["kind"] == "end":
                gx_ = s["x"] + 30.0
                seg = pier_leg(s["xa"], side, False) + [(s["xa"] + 16.0, road_z(s["xa"] + 16.0, side))]
                xx = s["xa"] + 22.0
                while xx < gx_ - 34: seg.append((xx, road_z(xx, side))); xx += 6.0
                zrz = road_z(gx_ - 30, side)
                if s.get("gate_name"):
                    s["gate"] = (gx_, zrz - 46.0)
                    seg += [(gx_ - 12.0, zrz - 6.0), (gx_, zrz - 24.0), (gx_, zrz - 46.0), (gx_, zrz - 70.0), (gx_, zrz - 86.0)]
                else:
                    while xx < X1 - 8: seg.append((xx, road_z(xx, side))); xx += 6.0
                land.append(np.array(M.catmull(seg, 2.0))); main.append(("land", land[-1]))
            else:
                seg = pier_leg(s["xa"], side, False) + [(s["xa"] + 16.0, road_z(s["xa"] + 16, side))]
                xx = s["xa"] + 22.0
                while xx < s["xb"] - 18: seg.append((xx, road_z(xx, side))); xx += 6.0
                seg += [(s["xb"] - 16.0, road_z(s["xb"] - 16, side))] + pier_leg(s["xb"], side, True)
                land.append(np.array(M.catmull(seg, 2.0))); main.append(("land", land[-1]))
    allp = np.vstack([p for _, p in main])
    dense, sarr = M.densify(allp, 1.0)
    is_lane = np.zeros(len(dense), bool)
    lane_set = cKDTree(lane_all)
    dd_, _ = lane_set.query(dense)
    land_set = cKDTree(np.vstack(land))
    dd2, _ = land_set.query(dense)
    is_lane = (dd_ < 0.8) & (dd2 > 0.8)
    roads = [dict(id=rid.lower() + "_main", name=R["name"], cls="대로", width=4.5, pts=dense)]
    # 볼거리 나루: 먼 둑 → 띠 끝 오솔길(강 건너 길)
    for s in S:
        if s.get("sight") == "side_ferry":
            bz = bank_z(s["x"], "far")
            br = np.array(M.catmull([(s["x"], bz - 6.0), (s["x"] + 6, bz - 40.0), (s["x"] + 22, bz - 90.0), (s["x"] + 30, -HALF_W + 6)], 2.0))
            roads.append(dict(id="ferry_path_" + s["key"], name=s["title"] + " 나루길(강 건너)", cls="마을길", width=3.0, pts=br))
            brn = np.array(M.catmull([(s["x"] - 4, bank_z(s["x"], "near") + 6.0), (s["x"] - 12, bank_z(s["x"], "near") + 60.0), (s["x"] - 24, HALF_W - 6)], 2.0))
            roads.append(dict(id="ferry_path_n_" + s["key"], name=s["title"] + " 나루길(이쪽)", cls="마을길", width=3.0, pts=brn))
    # 포구·시작·끝 터 고르기(물가 낮게 → 길 → 뒤로 조금 높게, §18 단구)
    for s in S:
        if s["kind"] not in ("start", "port", "port_big", "end"): continue
        side = s["bank"]
        x_lo = (s["pier"] - 60) if s["kind"] == "start" else s["xa"] - 24
        x_hi = (s["pier"] + 40) if s["kind"] == "start" else (s["xb"] + 24 if s["kind"] != "end" else s["x"] + s["a"])
        sg = -1.0 if side == "far" else 1.0                  # 뭍 쪽(z)
        bzc = bank_z(s["x"], side)
        inz = (XX > x_lo) & (XX < x_hi)
        dbank = (ZZ - (zc[None, :] + (-WG / 2 if side == "far" else WG / 2))) * sg   # 물가에서 뭍으로 거리
        zone = inz & (dbank > -1.0) & (dbank < 120.0)
        hmed = float(np.median(T[zone & (dbank > 30) & (dbank < 80)])) if np.any(zone & (dbank > 30) & (dbank < 80)) else 2.0
        h_top = float(np.clip(hmed, 1.4, 3.6 if side == "far" else 1.8))
        tgt = 0.55 + np.clip(dbank / 34.0, 0, 1) * (h_top - 0.55) + np.clip((dbank - 60) / 60.0, 0, 1) * 1.2
        bx = np.minimum(np.clip((XX - x_lo) / 22.0, 0, 1), np.clip((x_hi - XX) / 22.0, 0, 1))
        bz_ = np.clip((120.0 - dbank) / 30.0, 0, 1) * (dbank > 0)
        wgt = M.smoothstep(bx) * M.smoothstep(bz_)
        T = np.where(zone & ~water, T * (1 - wgt) + tgt * wgt, T).astype(np.float32)
        s["h_top"] = h_top
    # 성문 앞 터
    for s in S:
        if s.get("gate"):
            gx_, gz_ = s["gate"]
            dd = np.hypot(np.maximum(np.abs(XX - gx_) - 40, 0), np.maximum(np.abs(ZZ - gz_) - 30, 0))
            ph_ = float(np.median(T[dd == 0]))
            T = np.where(dd < 16, ph_ * (1 - M.smoothstep(dd / 16)) + T * M.smoothstep(dd / 16), T).astype(np.float32)
            s["gate_y"] = ph_
    # 길 깎기·메우기(뭍 길만 — 뱃길·선창은 빼고)
    mask = np.zeros((H_, W_), bool); pval = np.zeros((H_, W_), np.float32)
    for r in roads:
        pts_ = r["pts"]
        h = M.sample(T, gx, gz, pts_)
        keep = np.ones(len(pts_), bool)
        if r is roads[0]:
            keep = ~is_lane; h[is_lane] = 0.6
        h = ndimage.gaussian_filter1d(h, 10 if r["cls"] == "대로" else 5)
        h = np.maximum(h, 0.6)
        # 선창 뿌리 둘레는 갑판 높이에 가깝게(배에서 뭍으로 걸어 오르기), 선창 위(물 위) 점은 깎지 않는다
        for px_, side in zip(pier_x, sides):
            rt, tp, sg = pier_pts(px_, side)
            d_ = np.hypot(pts_[:, 0] - px_, pts_[:, 1] - rt)
            h = np.where(d_ < 10, np.minimum(h, 0.5 + 0.06 * d_), h)
            keep &= ~((np.abs(pts_[:, 0] - px_) < 1.5) & ((pts_[:, 1] - rt) * sg > 0.5))
        ii = np.clip(np.round((pts_[keep, 0] - X0) / CELL).astype(int), 0, W_ - 1)
        jj = np.clip(np.round((pts_[keep, 1] + HALF_W) / CELL).astype(int), 0, H_ - 1)
        mask[jj, ii] = True; pval[jj, ii] = h[keep]
    dist, (nj, ni) = ndimage.distance_transform_edt(~mask, return_indices=True)
    dist *= CELL
    rprof = pval[nj, ni]
    hw = 2.3
    blend = M.smoothstep((dist - hw) / 7.0)
    T = np.where((dist < hw + 7.0) & ~water, rprof * (1 - blend) + T * blend, T).astype(np.float32)
    # 선창 뿌리 둘레 낮추기(물가 → 갑판 높이)
    for px_, side in zip(pier_x, sides):
        rt, tp, sg = pier_pts(px_, side)
        d_ = np.hypot(XX - px_, (ZZ - rt) * 0.7)
        T = np.where((d_ < 12) & ~water, np.minimum(T, 0.42 + 0.07 * d_), T).astype(np.float32)
    # ---- 토지이용
    gy_, gx2 = np.gradient(T, CELL); slope = np.hypot(gx2, gy_)
    rel = T - ndimage.minimum_filter(T, size=61)
    lu = np.zeros((H_, W_), np.uint8)
    lu[(dist < 60) & (slope < 0.25)] = 1
    lu[(slope < 0.14) & (rel < 16) & (dist < 200)] = 3
    lu[(slope < 0.055) & (T < 9.0) & (T > 0.9)] = 2                 # 범람원 논(§24 하천 가 낮은 땅)
    lu[slope > 0.9] = 7
    shore = ~water & (ndimage.distance_transform_edt(~water) * CELL < 9.0) & (T < 1.4)
    lu[shore] = 8
    for (cx, cz, rx, rz) in islands:
        lu[(((XX - cx) / rx) ** 2 + ((ZZ - cz) / rz) ** 2) < 1.0] = 8
    lu[water] = 5
    lu[(dist < hw + 0.6) & ~water] = 4
    # ---- 기후대
    zcode = 1 if R["climate"] == "central" else 2
    col_zone = np.zeros(W_, np.uint8)
    for i, s in enumerate(S):
        col_zone[wts[i] >= wts.max(0)] = 0 if s["lat"] < 36 else (1 if s["lat"] < 38 else 2)
    cl = np.repeat(col_zone[None, :], H_, 0)
    cl4 = cl[::2, ::2]
    # ---- 배치
    ctx = dict(R=dict(R, sea=True), S=S, gx=gx, gz=gz, X0=X0, X1=X1, W=W_, H=H_, T=T, dist=dist, roads=roads, dense=dense, sarr=sarr,
               rivers=[], sea=water, lu=lu, slope=slope)
    pl = M.Placer(ctx)
    G = dict(zr=zr, wg=wg, bank_z=bank_z, road_z=road_z, pier_pts=pier_pts, lane_z=lambda x: float(np.interp(x, gx, lane_z)), lanes=lanes)
    out_ = place_all(pl, ctx, G, R, S, pier_x, sides)
    items, settlements, landmarks, stops_out, sights_out, lu_jobs = out_
    for job, xc, zc_, a in lu_jobs:
        ell = ((XX - xc) / (a + 60.0)) ** 2 + ((ZZ - zc_) / 110.0) ** 2
        free = (ell < 1.0) & (lu != 4) & (lu != 5) & (lu != 8) & (dist > hw + 1.5)
        lu[free & (slope < 0.09) & (ZZ > zc_)] = 2
        lu[free & (slope < 0.2) & (ZZ <= zc_)] = 3
    # ---- 저장
    y_min = float(T.min()) - 1.0; y_max = float(T.max()) + 1.0
    v16 = np.clip((T - y_min) / (y_max - y_min) * 65535.0, 0, 65535).astype(np.uint16)
    Image.fromarray(v16, mode="I;16").save(os.path.join(out, "height.png"))
    Image.fromarray(lu, mode="L").save(os.path.join(out, "landuse.png"))
    Image.fromarray(cl4.astype(np.uint8), mode="L").save(os.path.join(out, "climate.png"))
    def rnd(a): return [[round(float(p[0]), 1), round(float(p[1]), 1)] for p in a]
    main_pts = dense[::6]
    if (len(dense) - 1) % 6: main_pts = np.vstack([main_pts, dense[-1:]])
    road_json = [dict(id=roads[0]["id"], name=roads[0]["name"], **{"class": "대로"}, width_m=4.5, points=rnd(main_pts),
                      note="뭍 길 + 선창 + 뱃길(물 위 구간은 river_lanes와 같은 선 — 걷기 시험이 배를 타고 지나간다)")]
    for r in roads[1:]:
        road_json.append(dict(id=r["id"], name=r["name"], **{"class": r["cls"]}, width_m=r["width"], points=rnd(r["pts"][::5])))
    # 큰 강 중심선(흐름 방향 = 하류 순)
    cl_pts = [[round(float(x), 1), round(float(np.interp(x, gx, zc)), 1), 0.0] for x in np.arange(X0, X1 + 1, 16.0)]
    if R["downstream"] < 0: cl_pts = cl_pts[::-1]
    river_json = [dict(id=R["river_id"], name=R["river_name"], grade="S", spec_grade="S", render=False, width_m=round(float(Wg.mean()), 1),
                       widths=[round(float(np.interp(p[0], gx, Wg)), 1) for p in cl_pts], points=cl_pts, flows_to="",
                       note="큰 강 — 물면은 sea(kind river, y 0)가 그리고 이 선은 흐름 방향(하류 순)만")] + rivers_extra
    lanes_json = []
    stop_names = [S[0]["title"]] + [s["title"] for s in S if s["kind"] in ("port", "port_big", "end")]
    for li, l in enumerate(lanes):
        p8 = l["pts"][::6]
        if (len(l["pts"]) - 1) % 6: p8 = np.vstack([p8, l["pts"][-1:]])
        slow = []
        for s in S:
            if s.get("sight") == "rapids" and s["leg"] == li:
                k = int(np.argmin(np.abs(l["pts"][:, 0] - s["x"])))
                slow.append([round(float(l["s"][k] - 45), 1), round(float(l["s"][k] + 45), 1), 0.55])
        lanes_json.append(dict(id=f"{rid.lower()}_lane{li}", name=f"{R['short']} — {stop_names[li]} → {stop_names[li + 1]}",
                               from_name=stop_names[li], to_name=stop_names[li + 1], points=rnd(p8), pier=[PIER, PIER], speed=SAIL,
                               slow=slow, boat_kit="route/dotbae", boat_params={"len": 10.0}, auto=True,
                               length_m=round(float(l["s"][-1]), 1)))
    traffic_json = []
    for k, tr in enumerate(R.get("traffic", [])):
        xs2 = np.arange(X0 + 20, X1 - 20, 24.0)
        pts_t = [[round(float(x), 1), round(float(np.interp(x, gx, zc) + tr["side"] * np.interp(x, gx, Wg)), 1)] for x in xs2]
        traffic_json.append(dict(id=f"traffic{k}", name=tr["name"], kit=tr["kit"], params=dict(tr["params"], seed=40 + k), points=pts_t,
                                 speed=tr["speed"], phase=tr["phase"]))
    ln_ = R["_line"]; cm_ = geo_cum(ln_)
    geo = [[round(float(np.interp(t, cm_, [p[1] for p in ln_])), 4), round(float(np.interp(t, cm_, [p[0] for p in ln_])), 4)] for t in np.linspace(0, cm_[-1], 40)]
    portals = {"from": R["frm"]}
    if R.get("to"): portals["to"] = R["to"]
    sp = dense[min(20, len(dense) - 1)]
    total_lane = sum(l["s"][-1] for l in lanes)
    lat_mean = float(np.mean([s["lat"] for s in S]))
    route = {
        "route_id": rid, "id": rid, "name": R["name"], "short": R["short"], "kind": "route", "route_type": "river",
        "status": "river-routes(2026-10-04) — 실측 DEM 창(포구·볼거리, 실제 물길에 맞춤) + 압축 이음, tools/region/river_routes.py로 다시 만든다",
        "from_region": R["frm"]["region"], "to_region": R["to"].get("region", "") if R.get("to") else "", "dead_end": bool(R.get("dead_end")),
        "sail": {"lanes_m": round(float(total_lane), 0), "speed": SAIL, "sail_s": round(float(total_lane) / SAIL, 0),
                 "note": "포구마다 선창 둘(닿는 곳·떠나는 곳) — 배에서 내려 포구를 지나 다음 배에 오른다. 거꾸로 타면 되돌아간다"},
        "compression": {"note": "포구·볼거리마다 그 자리 실제 물길 방향으로 돌린 실측 DEM 창(수평 K_h 0.3, 높이 = (해발 − 그 창 수면) × 0.3). 창마다 실제 물길 가운데·폭을 찾아 띠의 물길(zc)에 맞추고 물길 안 폭만 55~120m로 줄임. 창 사이는 smoothstep 이음(§30: 상류·하류·포구 순서 유지, 거리 압축)",
                        "windows": [dict(key=s["key"], lat=round(s["lat"], 5), lon=round(s["lon"], 5), bearing_deg=round(math.degrees(s["bear"]), 1),
                                         water_alt_m=round(s["wl"], 1), x=round(s["x"], 1), core_half_m=s["a"], width_game_m=round(s["wg"], 1),
                                         width_real_m=round(float(w_track(s, 0)[1]), 0)) for s in S]},
        "projection": {"K": KV, "y_base_alt": 0.0, "lat0": round(lat_mean, 4), "lon0": round(float(np.mean([s["lon"] for s in S])), 4),
                       "note": "압축 띠라 경위도 투영이 아니다. y = (해발 − 그 자리 강 수면) × 0.3 — 강 수면이 띠 전체 y 0. 전국 지도 위치는 geo_line + 주 도로 진행도"},
        "climate_zone": R["climate"],
        "height": {"file": "height.png", "x0": X0, "z0": -HALF_W, "cell": CELL, "w": W_, "h": H_, "y_min": round(y_min, 3), "y_max": round(y_max, 3),
                   "note": "픽셀(i,j) 중심 = (x0+i*cell, z0+j*cell); y = y_min + v/65535*(y_max-y_min). 16bit, 행=+z"},
        "landuse": {"file": "landuse.png", "x0": X0, "z0": -HALF_W, "cell": CELL, "w": W_, "h": H_,
                    "classes": {"0": "숲", "1": "풀밭·초지", "2": "논", "3": "밭", "4": "길·맨땅", "5": "물", "6": "마을 터", "7": "바위·벼랑", "8": "모래톱·자갈"}},
        "climate": {"file": "climate.png", "x0": X0, "z0": -HALF_W, "cell": 4.0, "w": int(cl4.shape[1]), "h": int(cl4.shape[0]),
                    "codes": {"0": "south", "1": "central", "2": "north", "3": "alpine", "4": "coast"}, "band": R["climate"]},
        "sea": {"y": 0.0, "kind": "river", "name": R["river_name"],
                "note": "바다가 아니라 큰 강 물면(엔진 큰 강 모드). 강바닥 −0.35…−6m, 물가는 모래톱·갈대(토지이용 8)"},
        "rivers": river_json, "roads": road_json, "passes": [], "crossings": [],
        "river_lanes": lanes_json, "river_traffic": traffic_json,
        "settlements": settlements, "landmarks": landmarks, "stops": stops_out, "sights": sights_out,
        "spawn": {"x": round(float(sp[0]), 1), "z": round(float(sp[1]), 1)},
        "portals": portals, "geo_line": geo,
        "sources": ["AWS Terrain Tiles terrarium z13 (SRTM 등 공개 DEM 합성) — 포구·볼거리 창 지형과 물길 찾기",
                    "SRTM(2000)은 팔당호(1973)·충주호 아래 보 등 현대 물막이가 반영된 수면 — 물길 폭은 게임 폭으로 눌러 1870년 강처럼(가설)",
                    "포구·설화: seolhwa/docs/WORLD_SPEC_v0.3.md §4·5·8·14·25·26·30, CC-01·CC-02·GG-02·PA-02, docs/FOLKTALE_CATALOG.md",
                    "경위도는 현대 지명 기준 근사(기억값 — 확인 필요). 고증은 참고용"],
    }
    if R.get("to") is None: route["portals"]["note"] = "막다른 뱃길 — 끝(충주)에 닿으면 '지나옴'으로 기록되고, 마포 포털에서 배(H)로 끝까지 건너뛸 수 있다"
    json.dump(route, open(os.path.join(out, "route.json"), "w"), ensure_ascii=False, indent=1)
    json.dump({"area": "route_" + rid, "note": "river-routes — tools/region/river_routes.py가 만든다(손으로 고치면 다시 만들 때 덮어씀)", "items": items},
              open(os.path.join(out, "placement_route.json"), "w"), ensure_ascii=False, indent=1)
    if pl.dropped: print("  dropped:", pl.dropped)
    print(f"{rid}: {W_}x{H_} L={X1 - X0:.0f}m y {y_min:.1f}..{y_max:.1f} lanes={[round(float(l['s'][-1])) for l in lanes]} "
          f"sail={total_lane:.0f}m ({total_lane / SAIL / 60:.1f}min) items={len(items)} sights={len(sights_out)}")
    return route

# ---------------------------------------------------------------- 배치
HOUSE = M.HOUSE; COMP = M.COMP
FP = dict(M.FP)
FP.update({"route/seonchang": (2.8, 13.0), "route/tteotmok": (3.4, 14.6), "route/jounseon": (4.7, 16.0), "route/gangchang": (10.8, 7.2),
           "nature/cliff": (8.0, 4.0), "nature/reeds": (1.0, 0.7), "village/wall_run": (20.0, 14.0), "landmark/seoktap": (3.0, 3.0)})
PEOPLE_PORT = ["뱃사공", "객주", "짐꾼", "상인", "보부상", "주모", "나그네", "어물 장수", "소금 장수"]

def place_all(pl, ctx, G, R, S, pier_x, sides):
    items = pl.items
    settlements, landmarks, stops_out, sights_out, lu_jobs = [], [], [], [], []
    seed = [500]
    def sd(): seed[0] += 1; return seed[0]
    def put(sid, group, kit, params, x, z, ry=0.0, fp=None, flatten=True, y=None, water=False, note=None, tries=6, clear_veg=True, road_ok=False):
        fp = fp or FP.get(kit) or (6.0, 6.0)
        params = dict(params); params.setdefault("seed", sd())
        why = None
        for t in range(tries):
            dx = [0, 5, -5, 10, -10, 15][t % 6]; dz = [0, 0, 0, -3, -3, -6][t % 6] if not water else 0
            xx, zz = x + dx, z + dz
            why = pl.ok(kit, xx, zz, fp, ry, flatten, road_ok or water, water)
            if why is None:
                it = {"id": sid, "kit": kit, "params": params, "x": round(xx, 2), "z": round(zz, 2), "ry": round(ry, 4), "y": y,
                      "flatten": flatten, "clear_veg": clear_veg, "group": group}
                if note: it["note"] = note
                items.append(it); pl.disks.append((xx, zz, math.hypot(fp[0], fp[1]) / 2))
                return it
        pl.dropped.append((sid, why)); return None
    def boat(sid, g, kit, params, x, z, ry, note=None):
        return put(sid, g, kit, params, x, z, ry=ry, flatten=False, y=0.0, water=True, note=note, tries=1, clear_veg=False)
    def pier(sid, g, x, side):
        root, tip, sg = G["pier_pts"](x, side)
        return put(sid, g, "route/seonchang", {"len": PIER + 1.0}, x, (root + tip) / 2, ry=0.0 if sg > 0 else math.pi, flatten=False, y=0.0,
                   water=True, tries=1, clear_veg=True, note="선창(잔교) — 걷는 면은 엔진 river_lanes가 깐다")
    def bbox_of(n0, cx, cz, pad=14.0):
        mine = items[n0:]
        xs_ = [it["x"] for it in mine] + [cx]; zs_ = [it["z"] for it in mine] + [cz]
        return [round(min(xs_) - pad, 1), round(min(zs_) - pad, 1), round(max(xs_) + pad, 1), round(max(zs_) + pad, 1)]
    total = float(pl.sarr[-1])
    def t_of(x, z):
        k = int(np.argmin(np.hypot(pl.dense[:, 0] - x, pl.dense[:, 1] - z))); return round(float(pl.sarr[k]) / total, 3)
    # ---------------- 포구(시작·중간·끝)
    for s in S:
        if s["kind"] not in ("start", "port", "port_big", "end"): continue
        key = s["key"]; g = s["name"]; c = s.get("culture") or R["culture"]
        I = lambda nm, key=key: f"rt_{key}_{nm}"
        house = HOUSE.get(M.CULT_KEY.get(c, c), HOUSE["giho"])
        comp = COMP.get(M.CULT_KEY.get(c, c), COMP["giho"])
        side = s["bank"]
        sg = -1.0 if side == "far" else 1.0    # 뭍 쪽
        n0 = len(items)
        if s["kind"] == "start":
            xp = s["pier"]; pier(I("pier"), g, xp, side)
            rz = G["road_z"](xp - 30, side)
            put(I("chang"), g, "route/gangchang", {"roof": "choga", "w": 8.0}, xp - 34, rz - sg * 15.0, ry=0.0 if side == "far" else math.pi,
                note="선창 곳간(객주 짐)")
            boat(I("dotbae"), g, "route/dotbae", {"len": 9.0}, xp + 24, G["bank_z"](xp + 24, side) - sg * 9.0, math.pi / 2, note="매어 둔 돛배")
            boat(I("narutbae"), g, "village/narutbae", {}, xp - 18, G["bank_z"](xp - 18, side) - sg * 5.0, math.pi / 2)
            put(I("firewood"), g, "village/firewood", {"kind": "stack"}, xp - 52, rz + sg * 7.0, flatten=False)
            put(I("sacks"), g, "village/props", {"kind": "dok"}, xp - 12, rz + sg * 8.0, flatten=False)
            if side == "far":
                put(I("jumak"), g, "village/jumak", {}, xp - 30, rz - 14.0)
            s["cx"], s["cz"] = xp - 20, rz
        else:
            xa = s["xa"]; xb = s.get("xb", xa); xc = s["x"]
            pier(I("pier_a"), g, xa, side)
            if s["kind"] != "end": pier(I("pier_b"), g, xb, side)
            rz = G["road_z"](xc, side)
            def RZ(x): return G["road_z"](x, side)
            def BZ(x): return G["bank_z"](x, side)
            north = -1.0 if side == "far" else 1.0      # 길 뒤(뭍 안쪽) 방향
            # 물가 배(선창·뱃길에서 떨어지게)
            if s["kind"] != "end":
                boat(I("dotbae0"), g, "route/dotbae", {"len": 9.0}, xc - 18, BZ(xc - 18) + 9.0 * -north, math.pi / 2, note="매어 둔 돛배")
                boat(I("narut0"), g, "village/narutbae", {}, xc + 12, BZ(xc + 12) + 5.0 * -north, math.pi / 2 + 0.2)
            # 물가 곳간(길과 물 사이) — 앞이 물 쪽
            put(I("chang0"), g, "route/gangchang", {"roof": "giwa" if s["kind"] == "port_big" else "choga"}, xc - 38 if s["kind"] != "end" else xa + 40,
                RZ(xc) - north * 15.0, ry=0.0 if side == "far" else math.pi, note="포구 곳간(강창)")
            # 길 뒤: 주막·객주·집
            put(I("jumak"), g, "village/jumak", {}, xc - 8 if s["kind"] != "end" else xa + 64, RZ(xc) + north * 14.0)
            put(I("gaekju"), g, "village/giwa", {"plain": True}, xc + 26 if s["kind"] != "end" else xa + 96, RZ(xc) + north * 16.0, note="객주 집(포구 — 짐·돈 맡는 집)")
            put(I("house0"), g, comp[0], dict(comp[1]), xc - 34 if s["kind"] != "end" else xa + 22, RZ(xc) + north * 36.0, fp=comp[2])
            put(I("house1"), g, house[0], dict(house[1]), xc + 48 if s["kind"] != "end" else xa + 40, RZ(xc) + north * 36.0, fp=house[2])
            put(I("ferry_shed"), g, "route/ferry_shed", {}, (xb - 14) if s["kind"] != "end" else xa + 14, RZ(xc) - north * 9.0, ry=0.0 if side == "far" else math.pi)
            put(I("jangseung_m"), g, "village/jangseung", {"female": False}, xa + 26, RZ(xa + 26) - 5.0, flatten=False)
            put(I("jangseung_f"), g, "village/jangseung", {"female": True}, xa + 26, RZ(xa + 26) + 5.0, flatten=False)
            put(I("well"), g, "village/well", {}, xc + 6, RZ(xc) + north * 9.0, flatten=False)
            ex = s.get("extra", [])
            if "zelkova" in ex:
                put(I("zelkova"), g, "nature/big_tree", {"variant": "zelkova"}, xc + 4, BZ(xc + 4) + north * 10.0, flatten=False,
                    note="두물머리 큰 느티나무(합수머리 당산나무 자리)")
                put(I("dang"), g, "village/seonghwangdang", {"dangjip": True}, xc + 22, BZ(xc + 22) + north * 14.0)
            if "market_small" in ex or s["kind"] == "port_big":
                for k, dx in enumerate([-24, -6, 12] if s["kind"] != "port_big" else [-60, -42, -24, 30, 48]):
                    put(I(f"shop{k}"), g, "village/market_shop", {}, xc + dx, RZ(xc + dx) + north * 11.0)
                for k, dx in enumerate([-16, 2, 20] if s["kind"] != "port_big" else [-52, -34, -16, 38, 56]):
                    put(I(f"jwapan{k}"), g, "village/jwapan", {}, xc + dx, RZ(xc + dx) - north * 6.5, flatten=False)
            if "pavilion_bluff" in ex:
                # 신륵사 강월헌: 물가 가장 높은 벼랑 위 정자 + 탑(동대)
                bx_, bz_ = best_high(ctx, xb + 6, xb + 48, BZ(xb + 30) + north * 6.0, BZ(xb + 30) + north * 40.0)
                put(I("pavilion"), g, "village/jeongja", {"plain": False}, bx_, bz_, note="강월헌(신륵사 강가 정자 — 벼랑 위, 가설 자리)")
                put(I("tap"), g, "landmark/seoktap", {}, bx_ + 9, bz_ - 3, flatten=False, note="동대 삼층석탑(강가 바위 위 탑, 가설)")
                put(I("pine"), g, "nature/pine", {"s": 1.3}, bx_ - 8, bz_ - 6, flatten=False)
                landmarks.append(dict(id=f"rt_{key}_gangwolheon", name="강월헌·동대 탑(신륵사 강가)", type="누정", x=round(bx_, 1), z=round(bz_, 1)))
            if s["kind"] == "port_big":
                # 목계진: 창고 줄·객주 둘·주막 둘·세곡선·별신굿 마당
                put(I("chang1"), g, "route/gangchang", {"roof": "choga"}, xc - 20, RZ(xc - 20) - north * 15.0, ry=0.0 if side == "far" else math.pi)
                put(I("chang2"), g, "route/gangchang", {"roof": "giwa", "w": 11.0}, xc + 40, RZ(xc + 40) - north * 15.0, ry=0.0 if side == "far" else math.pi)
                put(I("gaekju1"), g, "village/giwa", {"plain": True}, xc - 56, RZ(xc - 56) + north * 30.0, note="객주 집")
                put(I("jumak1"), g, "village/jumak", {}, xc + 66, RZ(xc + 66) + north * 13.0)
                put(I("madang"), g, "village/village_square", {}, xc + 8, RZ(xc + 8) + north * 34.0, note="별신굿 마당(목계 별신제, 가설 자리)")
                put(I("byeolsindang"), g, "village/seonghwangdang", {"dangjip": True}, xc + 30, RZ(xc + 30) + north * 48.0)
                put(I("house2"), g, comp[0], dict(comp[1]), xc - 80, RZ(xc - 80) + north * 34.0, fp=comp[2])
                put(I("house3"), g, house[0], dict(house[1]), xc + 78, RZ(xc + 78) + north * 36.0, fp=house[2])
                boat(I("jounseon0"), g, "route/jounseon", {"len": 15.0}, xc - 46, BZ(xc - 46) + 11.0 * -north, math.pi / 2, note="매어 둔 세곡선")
                boat(I("jounseon1"), g, "route/jounseon", {"len": 13.0, "sail": False}, xc + 34, BZ(xc + 34) + 10.0 * -north, math.pi / 2 + 0.08)
                boat(I("dotbae1"), g, "route/dotbae", {"len": 9.0}, xc + 58, BZ(xc + 58) + 8.0 * -north, math.pi / 2 - 0.1)
                boat(I("narut1"), g, "village/narutbae", {}, xc - 4, BZ(xc - 4) + 5.0 * -north, math.pi / 2 - 0.3)
            if s["kind"] == "end":
                # 충주: 나루 → 창고·장 → 읍성 서문(성문 + 성벽)
                for k, dx in enumerate([30, 48, 66]):
                    put(I(f"shop{k}"), g, "village/market_shop", {}, xa + dx + 50, RZ(xa + dx + 50) + north * 11.0)
                put(I("chang1"), g, "route/gangchang", {"roof": "giwa", "w": 11.0}, xa + 84, RZ(xa + 84) - north * 15.0, ry=0.0 if side == "far" else math.pi,
                    note="충주 강창(가흥창 성격 — 세곡 모으는 곳, 가설)")
                boat(I("jounseon0"), g, "route/jounseon", {"len": 14.0}, xa + 40, BZ(xa + 40) + 11.0 * -north, math.pi / 2)
                boat(I("narut0"), g, "village/narutbae", {}, xa + 64, BZ(xa + 64) + 5.0 * -north, math.pi / 2 + 0.2)
                if s.get("gate"):
                    gx_, gz_ = s["gate"]
                    put(I("gate"), g, "landmark/seongmun", {"name": s["gate_name"], "open": "none", "width": 14.0, "lu": 1}, gx_, gz_, fp=(15.0, 7.0),
                        tries=1, road_ok=True)
                    for sd_ in (-1, 1):
                        for k in range(3):
                            cx = gx_ + sd_ * (17.5 + 20.0 * k)
                            h0 = pl.h(cx - 10, gz_); h1 = pl.h(cx + 10, gz_)
                            put(I(f"wall{'w' if sd_ < 0 else 'e'}{k}"), g, "landmark/hy_seong_wall", {"length": 20.0, "rise": round(h1 - h0, 2), "height": 4.5},
                                cx, gz_, fp=(20.0, 2.0), flatten=False, tries=1)
                    landmarks.append(dict(id="rt_chungju_gate", name=s["gate_name"], type="성문", x=round(gx_, 1), z=round(gz_, 1)))
            s["cx"], s["cz"] = xc, rz
        bb = bbox_of(n0, s["cx"], s["cz"])
        typ = "포구" if s["kind"] != "start" else "선창"
        settlements.append(dict(id=f"rt_{key}", name=g, title=s["title"], short=s["title"], type=typ, x=round(s["cx"], 1), z=round(s["cz"], 1),
                                radius_m=round(max(bb[2] - bb[0], bb[3] - bb[1]) / 2, 1), bbox=bb,
                                profile=dict(culture=c, archetype="river", climate=R["climate"], signature=g,
                                             people=PEOPLE_PORT if s["kind"] == "port_big" else ["뱃사공", "객주", "짐꾼", "주모", "나그네"],
                                             animals=["소", "개", "닭"])))
        enc = {"grade": "D", "candidates": ["도깨비(나루·장터 외곽)", "물귀신(나루)", "용왕"], "night_bias": True}
        stops_out.append(dict(key=key, id=f"rt_{key}", type=s["kind"], name=g, title=s["title"], x=round(s["cx"], 1), z=round(s["cz"], 1),
                              t=t_of(s["cx"], s["cz"]), culture=c, real={"lat": round(s["lat"], 4), "lon": round(s["lon"], 4), "water_alt_m": round(s["wl"], 0)},
                              folktales=[dict(code=a, title=b, grade=gr) for a, b, gr in s.get("tales", [])], encounter=enc,
                              piers=[round(float(x), 1) for x in ([s["pier"]] if s["kind"] == "start" else ([s["xa"], s["xb"]] if s["kind"] != "end" else [s["xa"]]))]))
    # ---------------- 물가 볼거리
    CAT = {"deep_pool": "pool", "rapids": "rapids", "side_ferry": "crossing", "shrine": "shrine", "sandbar": "shoal", "jochang": "jochang",
           "pavilion": "pavilion", "hamlet": "hamlet"}
    TYPE = {"deep_pool": "깊은 소(용왕)", "rapids": "여울(물살)", "side_ferry": "나루(강 건너기)", "shrine": "강가 당집", "sandbar": "모래톱·모래섬",
            "jochang": "조창(세곡 창고)", "pavilion": "벼랑 위 정자", "hamlet": "단구 위 마을"}
    ENC = {"deep_pool": (["용왕", "이무기", "물귀신"], False), "rapids": (["물귀신", "도깨비(여울)"], True), "side_ferry": (["도깨비(나루)", "물귀신"], True),
           "shrine": (["서낭·용왕(비손)", "도깨비불"], True), "sandbar": (["물귀신", "도깨비불(갈대밭)"], True), "jochang": (["도깨비(창고)", "귀신(빈 창)"], True),
           "pavilion": (["선비 귀신(누정)", "여우"], False), "hamlet": (["여우", "도깨비"], False)}
    for s in S:
        if s["kind"] != "via": continue
        key = s["key"]; g = s["name"]; sight = s["sight"]; c = s.get("culture") or R["culture"]
        I = lambda nm, key=key: f"rt_{key}_{nm}"
        x = s["x"]; BZ = G["bank_z"](x, "far"); BN = G["bank_z"](x, "near"); n0 = len(items)
        house = HOUSE.get(M.CULT_KEY.get(c, c), HOUSE["giho"]); comp = COMP.get(M.CULT_KEY.get(c, c), COMP["giho"])
        cx, cz = x, BZ - 10.0
        if sight == "side_ferry":
            put(I("shed"), g, "route/ferry_shed", {}, x - 10, BZ - 12.0)
            boat(I("narut0"), g, "village/narutbae", {}, x + 2, BZ + 5.0, 0.15)
            boat(I("narut1"), g, "village/narutbae", {}, x + 10, BZ + 5.5, -0.1)
            boat(I("narut_n"), g, "village/narutbae", {}, x - 6, BN - 5.0, 0.1, note="건너편(이쪽) 나룻배")
            put(I("boatman"), g, house[0], dict(house[1]), x + 22, BZ - 30.0, fp=house[2], note="뱃사공 집")
            put(I("jangseung_m"), g, "village/jangseung", {"female": False}, x + 4 - 2.5, BZ - 26.0, flatten=False)
            put(I("jangseung_f"), g, "village/jangseung", {"female": True}, x + 4 + 2.5, BZ - 26.0, flatten=False)
            put(I("willow"), g, "nature/big_tree", {"variant": "willow"}, x - 24, BZ - 8.0, flatten=False)
            put(I("jumak"), g, "village/jumak", {}, x - 30, BZ - 34.0)
        elif sight == "rapids":
            lz = G["lane_z"](x)
            k = 0
            for dx, fz in ((-38, -0.36), (-20, 0.42), (-4, -0.30), (14, 0.40), (30, -0.38), (46, 0.34)):
                zz = G["zr"](x + dx) + fz * G["wg"](x + dx)
                if abs(zz - lz) < 10.0: continue
                put(I(f"rock{k}"), g, "nature/boulder", {"s": 2.4 + 0.4 * (k % 3), "mossy": False}, x + dx, zz, flatten=False, y=-0.7, water=True, tries=1,
                    clear_veg=False); k += 1
            put(I("cliff0"), g, "nature/cliff", {"w": 9.0, "h": 8.0, "d": 3.5}, x - 18, BZ - 5.0, flatten=False, note="여울목 벼랑")
            put(I("cliff1"), g, "nature/cliff", {"w": 7.0, "h": 6.5, "d": 3.0}, x + 20, BZ - 4.0, flatten=False)
            put(I("cairn"), g, "village/cairn", {"altar": True}, x + 2, BZ - 16.0, flatten=False, note="여울 고사 돌무더기(뱃사람이 돌 얹고 비는 곳)")
            cz = BZ - 6.0
        elif sight == "sandbar":
            icx, icz, rx, rz = s["island"]
            for k, (dx, dz) in enumerate(((-40, 0), (-18, -2), (6, 1), (28, -1), (46, 0))):
                put(I(f"reeds{k}"), g, "nature/reeds", {"n": 11}, icx + dx, icz + dz * rz * 0.3, flatten=False, water=True, tries=1, clear_veg=False)
            put(I("snag"), g, "nature/deadwood", {"kind": "snag", "s": 1.1}, icx - 4, icz, flatten=False, water=True, tries=1)
            boat(I("fishing"), g, "village/narutbae", {"pole": True}, icx + 70, icz - 4, math.pi / 2 - 0.4, note="고기잡이 거룻배")
            cx, cz = icx, icz
        elif sight == "deep_pool":
            put(I("cliff0"), g, "nature/cliff", {"w": 10.0, "h": 11.0, "d": 4.0}, x - 10, BZ - 6.0, flatten=False, note="소 위 벼랑")
            put(I("cliff1"), g, "nature/cliff", {"w": 8.0, "h": 9.0, "d": 3.5}, x + 12, BZ - 5.0, flatten=False)
            bx_, bz_ = best_high(ctx, x - 30, x + 30, BZ - 14.0, BZ - 60.0)
            put(I("dang"), g, "village/seonghwangdang", {"dangjip": True}, bx_, bz_, note="벼랑 위 용왕당(가설)")
            put(I("altar"), g, "village/cairn", {"altar": True}, x + 30, BZ - 7.0, flatten=False, note="물가 비손 제단(용왕)")
            put(I("pine"), g, "nature/pine", {"s": 1.4}, bx_ + 10, bz_ - 4, flatten=False)
            cz = BZ - 4.0
        elif sight == "shrine":
            put(I("dang"), g, "village/seonghwangdang", {"dangjip": True}, x, BZ - 22.0)
            put(I("sinmok"), g, "route/sinmok", {"variant": "zelkova", "cloth": True}, x + 18, BZ - 14.0, flatten=False, fp=(6.6, 4.2))
            put(I("sotdae"), g, "village/sotdae", {"n": 3}, x - 14, BZ - 10.0, flatten=False)
            put(I("cairn"), g, "village/cairn", {"altar": True}, x + 4, BZ - 9.0, flatten=False)
            boat(I("narut"), g, "village/narutbae", {}, x - 6, BZ + 5.0, math.pi / 2)
        elif sight == "jochang":
            for k, dx in enumerate((-30, -8, 14)):
                put(I(f"chang{k}"), g, "route/gangchang", {"roof": "giwa", "w": 10.0}, x + dx * 1.15, BZ - 20.0, note="조창 곳간(세곡)")
            put(I("wall"), g, "village/wall_run", {"kind": "stone_lite", "h": 1.2, "closed": True, "gaps": [1], "jitter": 0.2,
                "points": [[-30, -8], [30, -8], [30, 9], [-30, 9]]}, x - 8, BZ - 34.0, fp=(62.0, 20.0), flatten=False, note="조창 담(가설)")
            boat(I("jounseon0"), g, "route/jounseon", {"len": 15.0}, x - 26, BZ + 11.0, math.pi / 2)
            boat(I("jounseon1"), g, "route/jounseon", {"len": 14.0, "sail": False}, x + 8, BZ + 11.5, math.pi / 2 - 0.06)
            put(I("jumak"), g, "village/jumak", {}, x + 44, BZ - 22.0)
            put(I("gaeksa"), g, "village/giwa", {"plain": True}, x - 56, BZ - 26.0, note="창 관원 집(해운판관 머무는 곳, 가설)")
            cz = BZ - 20.0
        elif sight == "pavilion":
            bx_, bz_ = best_high(ctx, x - 40, x + 40, BZ - 6.0, BZ - 46.0)
            put(I("pavilion"), g, "village/jeongja", {"plain": False}, bx_, bz_, note="벼랑 위 정자(가설)")
            put(I("pine0"), g, "nature/pine", {"s": 1.5}, bx_ - 9, bz_ - 5, flatten=False)
            put(I("pine1"), g, "nature/pine", {"s": 1.2}, bx_ + 10, bz_ - 7, flatten=False)
            put(I("cliff"), g, "nature/cliff", {"w": 10.0, "h": 9.0, "d": 4.0}, x, BZ - 4.0, flatten=False)
            put(I("rock"), g, "nature/boulder", {"s": 2.6, "mossy": True}, bx_ + 4, bz_ + 6, flatten=False)
            cx, cz = bx_, bz_
        elif sight == "hamlet":
            for k, (dx, dz, kk) in enumerate(((-34, -70, comp), (-4, -64, house), (26, -72, comp), (50, -90, house))):
                put(I(f"house{k}"), g, kk[0], dict(kk[1]), x + dx, BZ + dz, fp=kk[2])
            put(I("teotbat"), g, "village/teotbat", {}, x + 12, BZ - 98.0)
            put(I("haystack"), g, "village/haystack", {}, x - 14, BZ - 50.0, flatten=False)
            put(I("well"), g, "village/well", {}, x + 14, BZ - 52.0, flatten=False)
            put(I("sotdae"), g, "village/sotdae", {"n": 3}, x - 40, BZ - 44.0, flatten=False)
            put(I("tree"), g, "nature/big_tree", {"variant": "zelkova"}, x - 20, BZ - 40.0, flatten=False)
            boat(I("narut"), g, "village/narutbae", {}, x - 4, BZ + 5.0, math.pi / 2)
            lu_jobs.append(("fields", x, BZ - 40.0, 60.0))
            cz = BZ - 66.0
        bb = bbox_of(n0, cx, cz)
        bb = [round(min(bb[0], x - 60), 1), round(min(bb[1], BZ - 60), 1), round(max(bb[2], x + 60), 1), round(max(bb[3], BN + 10), 1)]
        tales = s.get("tales") or []
        grades = [t[2] for t in tales]
        top = next((gr for gr in ("A+", "A", "B", "C", "D") if gr in grades), "D")
        enc, night = ENC[sight]
        sights_out.append(dict(key=key, id=f"rt_{key}", sight=sight, type=TYPE[sight], category=CAT[sight], name=g, title=s["title"],
                               x=round(cx, 1), z=round(cz, 1), t=t_of(cx, G["lane_z"](cx)), culture=c, bbox=bb, items=len(items) - n0,
                               real={"lat": round(s["lat"], 4), "lon": round(s["lon"], 4), "water_alt_m": round(s["wl"], 0)},
                               folktales=[dict(code=a, title=b, grade=gr) for a, b, gr in tales],
                               encounter={"grade": "D", "type": TYPE[sight], "category": CAT[sight], "event_grade": top, "candidates": enc, "night_bias": night},
                               on_water=True, note="물 위에서 지나며 보는 볼거리(배가 늦어지는 여울은 river_lanes.slow)"))
        if sight in ("side_ferry", "hamlet", "jochang"):
            settlements.append(dict(id=f"rt_{key}", name=g, title=s["title"], short=s["title"], type={"side_ferry": "나루", "hamlet": "강가 마을", "jochang": "조창"}[sight],
                                    x=round(cx, 1), z=round(cz, 1), radius_m=round(max(bb[2] - bb[0], bb[3] - bb[1]) / 2, 1), bbox=bb,
                                    profile=dict(culture=c, archetype="river", climate=R["climate"], signature=g,
                                                 people=["뱃사공", "나그네", "농부"] if sight != "jochang" else ["관속", "짐꾼", "뱃사공"], animals=["소", "개"])))
        else:
            landmarks.append(dict(id=f"rt_{key}", name=g, type=TYPE[sight], x=round(cx, 1), z=round(cz, 1)))
    return items, settlements, landmarks, stops_out, sights_out, lu_jobs

def best_high(ctx, x0, x1, z0, z1):
    """사각 안에서 가장 높으면서 평평한 곳(벼랑 위 정자·당집 자리)"""
    gx, gz, T = ctx["gx"], ctx["gz"], ctx["T"]
    za, zb = min(z0, z1), max(z0, z1)
    ci = np.nonzero((gx >= x0) & (gx <= x1))[0]; rj = np.nonzero((gz >= za) & (gz <= zb))[0]
    if ci.size == 0 or rj.size == 0: return (x0 + x1) / 2, (z0 + z1) / 2
    sub = T[np.ix_(rj, ci)]
    rough = ndimage.maximum_filter(sub, 5) - ndimage.minimum_filter(sub, 5)
    score = sub - 4.0 * rough
    j, i = np.unravel_index(int(np.argmax(score)), sub.shape)
    return float(gx[ci[i]]), float(gz[rj[j]])

def main():
    want = sys.argv[1:]
    for R in ROUTES:
        if want and R["id"] not in want: continue
        build(R)

if __name__ == "__main__":
    main()
