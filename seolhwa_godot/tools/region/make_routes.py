#!/usr/bin/env python3
"""노정(권역 사이 길) 공간 생성기 — 계약서 §10, WORLD_SCOPE_PLAN §4, WORLD_SPEC §19·20·23·25·27·29·30.

    python3 tools/region/make_routes.py            # 모든 노정
    python3 tools/region/make_routes.py GG_HANYANG-GS_GYEONGJU …

방식(압축 띠 공간 — 계획서 §2.1):
- 노정 = 길을 따라 편 띠(x = 길 방향, z = 옆, 폭 512m). 지나가는 쉼터·성읍·고개·나루(stop)마다 실측 DEM 창을 하나씩 둔다.
  창은 그 자리의 실제 길 방향으로 돌려 놓은 실측 지형(terrarium z13, 권역과 같은 자료)이고 수평 압축 K_h(기본 0.3, 문경새재 0.15),
  수직 KV=0.3. 창 사이(실제로는 수십 km)는 두 창을 smoothstep으로 섞어 잇는다(§30: 순서·관계는 지키고 거리만 줄임).
- 길: 지형 위 최소 비용 경로(낮은 곳·완만한 곳 — §19 골짜기→기슭→고개→나루). 성문 자리는 길이 화면 안쪽(북)으로 문을 지나가게 S자로 꺾는다.
- 나루·다리: 그 자리 실측 골짜기 바닥에 남북으로 흐르는 물길을 판다(건너는 곳은 얕은 여울 = 엔진 나루 건너기 허용).
- 양 끝 포털: 권역 쪽 자리(권역 좌표)는 region.json 포털과 같은 값, 노정 쪽 자리는 주 도로 첫·끝 점(엔진 규칙).
- 배치: placement_route.json(키트 kit/·kit/culture/·kit/landmark/, 문화권별 가옥형).
DEM 타일 캐시: tools/region/cache/routes/terrarium_z13/
"""
import json, math, os, sys, urllib.request, zlib
import numpy as np
from PIL import Image
from scipy import ndimage
from concurrent.futures import ThreadPoolExecutor
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import route_sights as RS

HERE = os.path.dirname(os.path.abspath(__file__))
PROJ = os.path.normpath(os.path.join(HERE, "..", ".."))
RD = os.path.join(PROJ, "region_data")
OUT_ROOT = os.path.join(RD, "routes")
TILES = os.path.join(HERE, "cache", "routes", "terrarium_z13")
Z = 13
URL = "https://s3.amazonaws.com/elevation-tiles-prod/terrarium/{z}/{x}/{y}.png"
CELL = 2.0
HALF_W = 256.0
KV = 0.3
KH = 0.3
ROAD_HW = 2.5

# ---------------------------------------------------------------- DEM
def tile_xy(lat, lon):
    n = 2 ** Z
    x = (np.asarray(lon) + 180.0) / 360.0 * n
    r = np.radians(np.asarray(lat))
    y = (1 - np.log(np.tan(r) + 1 / np.cos(r)) / np.pi) / 2 * n
    return x, y

_tc = {}
def _tile_path(x, y): return os.path.join(TILES, f"{x}_{y}.png")
def _fetch(xy):
    p = _tile_path(*xy)
    if not (os.path.exists(p) and os.path.getsize(p) > 0):
        urllib.request.urlretrieve(URL.format(z=Z, x=xy[0], y=xy[1]), p)
def _tile(x, y):
    k = (x, y)
    if k not in _tc:
        a = np.asarray(Image.open(_tile_path(x, y)).convert("RGB"), np.float32)
        _tc[k] = a[..., 0] * 256 + a[..., 1] + a[..., 2] / 256 - 32768
    return _tc[k]

def dem(lat, lon):
    lat = np.asarray(lat, np.float64); lon = np.asarray(lon, np.float64)
    tx, ty = tile_xy(lat, lon)
    x0, x1 = int(np.floor(tx.min() - 0.01)), int(np.floor(tx.max() + 0.01))
    y0, y1 = int(np.floor(ty.min() - 0.01)), int(np.floor(ty.max() + 0.01))
    os.makedirs(TILES, exist_ok=True)
    jobs = [(x, y) for x in range(x0, x1 + 1) for y in range(y0, y1 + 1)]
    with ThreadPoolExecutor(8) as ex: list(ex.map(_fetch, jobs))
    mos = np.zeros(((y1 - y0 + 1) * 256, (x1 - x0 + 1) * 256), np.float32)
    for (x, y) in jobs:
        mos[(y - y0) * 256:(y - y0 + 1) * 256, (x - x0) * 256:(x - x0 + 1) * 256] = _tile(x, y)
    px = (tx - x0) * 256 - 0.5; py = (ty - y0) * 256 - 0.5
    return ndimage.map_coordinates(mos, [py.ravel(), px.ravel()], order=1, mode="nearest").reshape(lat.shape).astype(np.float32)

def geo_offset(lat0, lon0, east_m, north_m):
    return lat0 + north_m / 110574.0, lon0 + east_m / (111320.0 * math.cos(math.radians(lat0)))

def bearing(a, b):
    e = (b[1] - a[1]) * 111320.0 * math.cos(math.radians((a[0] + b[0]) / 2)); n = (b[0] - a[0]) * 110574.0
    return math.atan2(e, n)

def dist_m(a, b):
    e = (b[1] - a[1]) * 111320.0 * math.cos(math.radians((a[0] + b[0]) / 2)); n = (b[0] - a[0]) * 110574.0
    return math.hypot(e, n)

# ---------------------------------------------------------------- 권역 정보
_regions = {}
def region(rid):
    if rid not in _regions:
        _regions[rid] = json.load(open(os.path.join(RD, rid, "region.json")))
    return _regions[rid]

def region_geo(rid, x, z):
    pj = region(rid)["projection"]; K = float(pj["K"]); lat0 = float(pj["lat0"]); lon0 = float(pj["lon0"])
    return lat0 - z / K / 110574.0, lon0 + x / K / (math.cos(math.radians(lat0)) * 111320.0)

def road_end_inset(rid, x, z, inset=12.0):
    """권역 길 끝(x,z)에 가장 가까운 길 끝에서 길을 따라 inset m 안쪽 점"""
    best = None
    for r in region(rid)["roads"]:
        p = r["points"]
        for pts in (p, p[::-1]):
            d = math.hypot(pts[0][0] - x, pts[0][1] - z)
            if best is None or d < best[0]: best = (d, pts)
    pts = best[1]; acc = 0.0
    for i in range(len(pts) - 1):
        a, b = pts[i], pts[i + 1]; l = math.hypot(b[0] - a[0], b[1] - a[1])
        if acc + l >= inset:
            t = (inset - acc) / max(l, 1e-6)
            return round(a[0] + (b[0] - a[0]) * t, 1), round(a[1] + (b[1] - a[1]) * t, 1)
        acc += l
    return pts[-1][0], pts[-1][1]

# ---------------------------------------------------------------- 키트(문화권별)
CULT_KEY = {"호남": "honam", "기호": "giho", "영남": "yeongnam", "관동": "gwandong", "해서": "haeseo", "관서": "gwanseo", "관북": "gwanbuk", "탐라": "tamna"}
HOUSE = {   # 한 채(작은 집)
    "honam": ("village/choga", {}, (8.2, 6.4)),
    "giho": ("culture/giho/choga_giyeok", {}, (10.8, 9.4)),
    "yeongnam": ("culture/yeongnam/choga", {}, (11.4, 6.8)),
    "gwandong": ("village/neowa_house", {}, (8.6, 6.8)),
    "haeseo": ("culture/haeseo/gyeopjip", {}, (12.4, 8.2)),
    "gwanseo": ("culture/gwanseo/choga", {}, (14.4, 8.8)),
    "gwanbuk": ("culture/gwanbuk/jeonja", {}, (15.1, 11.6)),
    "tamna": ("culture/tamna/stone_house", {"kind": "bak"}, (11.8, 7.2)),
}
COMP = {    # 집 한 채 묶음(프리셋 small)
    "honam": ("village/house_compound", {"size": "small"}, (14.8, 14.0)),
    "giho": ("culture/giho/compound", {"size": "small"}, (16.0, 15.0)),
    "yeongnam": ("culture/yeongnam/compound", {"size": "small"}, (16.0, 15.0)),
    "gwandong": ("culture/gwandong/compound", {"size": "small"}, (18.0, 15.0)),
    "haeseo": ("culture/haeseo/compound", {"size": "small"}, (16.0, 15.0)),
    "gwanseo": ("culture/gwanseo/compound", {"size": "small"}, (17.0, 15.0)),
    "gwanbuk": ("culture/gwanbuk/compound", {"size": "small"}, (18.0, 17.0)),
    "tamna": ("culture/tamna/compound", {"size": "small"}, (19.0, 22.0)),
}
COAST_HOUSE = {"gwandong": ("culture/gwandong/haean", {}, (10.6, 9.0))}
ALPINE_HOUSE = ("village/guitul_house", {}, (8.2, 6.8))
FP = {
    "village/jumak": (11.2, 9.6), "village/firewood": (1.9, 1.2), "village/jige": (0.9, 1.1), "village/jangseung": (1.2, 1.2),
    "village/seonghwangdang": (7.5, 4.6), "village/cairn": (2.8, 3.4), "village/narutbae": (1.9, 6.6), "village/heotgan": (5.0, 4.0),
    "village/market_shop": (7.0, 6.4), "village/jwapan": (2.4, 2.0), "village/well": (2.4, 2.0), "village/haystack": (2.4, 2.4),
    "village/sotdae": (2.7, 1.0), "village/torch_post": (0.7, 0.7), "village/stone_bridge": (3.0, 12.0), "village/jeongja": (6.0, 6.0),
    "village/giwa": (12.6, 8.8), "village/jangdok": (3.2, 2.2), "village/props": (2.0, 1.3), "village/choga_low": (8.0, 6.2),
    "village/stone_wall": (5.1, 0.6), "village/ppallaeteo": (4.9, 2.6), "village/oeyanggan": (5.0, 4.2), "village/teotbat": (4.8, 3.5),
    "village/village_square": (8.0, 7.6), "village/stone_jangseung": (1.2, 1.2), "village/yard_props": (4.4, 3.0),
    "landmark/seongmun": (17.0, 7.0), "landmark/hy_seong_wall": (20.0, 4.8), "landmark/maaebul_rock": (9.0, 6.5),
    "landmark/gj_gyerim_bigak": (10.0, 7.0), "landmark/samun": (10.8, 5.6), "landmark/hj_jangsangot_rock": (28.0, 18.0),
    "landmark/hh_bukcheong_madang": (15.0, 15.0), "nature/big_tree": (8.0, 8.0), "culture/yeongnam/tteuljip": (17.0, 17.0),
    "culture/yeongnam/jongga": (27.0, 36.0), "culture/yeongnam/sadang": (11.2, 10.0), "landmark/seonghwangsa": (20.0, 18.0),
    "route/ijeongpyo": (1.2, 1.0), "route/myo": (5.6, 7.3), "route/ruin_house": (9.4, 6.8), "route/ferry_shed": (5.2, 3.6),
    "route/waterfall": (11.4, 11.6), "route/sinmok": (10.1, 6.4), "route/dotbae": (3.3, 9.8), "nature/slab_rock": (4.8, 3.2),
    "nature/boulder": (5.0, 5.0), "nature/deadwood": (2.4, 2.4), "nature/pine": (3.4, 3.4), "village/jingeom": (1.4, 6.0),
}

# ---------------------------------------------------------------- 노정 정의
# stop: key, name(지명 전체), title(화면 지명), kind, lat, lon, a(핵심 반길이 m), culture, kh(수평 압축), river/gates/…, tales(설화 연결)
def P(rid, pid=None, x=None, z=None, name="", inset=None):
    """권역 포털: region.json 포털 id 또는 좌표"""
    if pid is not None:
        for p in region(rid).get("portals") or []:
            if p.get("id") == pid: x, z = float(p["x"]), float(p["z"])
    if inset:
        x, z = road_end_inset(rid, x, z, inset)
    return {"region": rid, "x": round(x, 1), "z": round(z, 1), "name": name}

ROUTES = [
 dict(id="JL_NAMWON_UNBONG-GG_HANYANG", name="삼남대로(남원→한양)", climate="central",
      frm=P("JL_NAMWON_UNBONG", x=-3485.0, z=-2087.0, inset=14, name="삼남대로 남쪽 끝(남원 북문 밖)"),
      to=P("GG_HANYANG", "to_namwon", name="삼남대로 북쪽 끝(과천·노량진 방면)"),
      stops=[
        dict(key="osu", name="오수 역마을(의견비)", title="오수", kind="jumak", lat=35.5420, lon=127.3230, a=120, culture="honam",
             extra=["bigak"], tales=[("—", "오수의 개(의견) — 주인을 살리고 죽은 개, 『보한집』", "A·지명"), ("JG22", "호랑이와 곶감", "D")]),
        dict(key="jeonju", name="전주 남문(풍남문) 밖 — 감영 고을", title="전주", kind="town", lat=35.8133, lon=127.1474, a=170, culture="honam",
             gate_name="풍남문", tales=[("—", "전주 감영 장시(지나가는 성읍)", "배경"), ("JG12", "도깨비 씨름(장 보고 오는 밤길)", "D")]),
        dict(key="aenggok", name="이서 앵곡 마을(콩쥐팥쥐)", title="앵곡", kind="village", lat=35.8350, lon=127.0550, a=120, culture="honam",
             extra=["kongjwi"], tales=[("HN24", "콩쥐팥쥐(밑 빠진 독·두꺼비)", "B")]),
        dict(key="gomnaru", name="공주 곰나루(고마나루)", title="곰나루", kind="naru", lat=36.4650, lon=127.1070, a=150, culture="giho",
             river=dict(id="geumgang", name="금강(웅진)", width=22.0, grade="A"), extra=["shrine_bank"],
             tales=[("GH13", "곰나루 — 버림받은 암곰과 강", "A"), ("YN22", "나루 뱃사공·물귀신", "D")]),
        dict(key="charyeong", name="차령 고개(성황당)", title="차령", kind="pass", lat=36.6050, lon=127.1290, a=130, culture="giho",
             tales=[("JG23", "호랑이 형님", "D"), ("JG33", "성황당 돌무더기", "D")]),
        dict(key="samgeori", name="천안삼거리(능소 버들·주막거리)", title="천안삼거리", kind="samgeori", lat=36.7790, lon=127.1720, a=150, culture="giho",
             tales=[("GH16", "천안삼거리 능소", "A"), ("GH11", "박문수(주막 일화)", "D")]),
      ]),
 dict(id="GG_HANYANG-GS_GYEONGJU", name="영남대로·안동길(한양→경주)", climate="central", alpine={"1": 560.0},
      frm=P("GG_HANYANG", "to_gyeongju", name="살곶이·송파 방면"),
      to=P("GS_GYEONGJU", "portal_west", name="영천 방면 서쪽 끝"),
      stops=[
        dict(key="songpa", name="송파나루와 송파장", title="송파", kind="naru", lat=37.5065, lon=127.1050, a=190, culture="giho",
             river=dict(id="hangang_songpa", name="한강(송파 나루)", width=24.0, grade="S"), extra=["market"],
             tales=[("GH22", "송파 산대놀이·나루 장시", "A"), ("JG12", "도깨비 씨름(장 보고 오는 밤길)", "D")]),
        dict(key="saejae", name="문경새재(조령 — 세 관문·원터·주막·성황당)", title="문경새재", kind="saejae", lat=36.7885, lon=128.0700, a=520,
             culture="yeongnam", kh=0.15, gap=420,
             bearing_from=(36.8140, 128.0700), bearing_to=(36.7630, 128.0750),
             gates=[dict(key="gate3", name="조령관(제3관문)", lat=36.8140, lon=128.0700),
                    dict(key="gate2", name="조곡관(제2관문)", lat=36.7880, lon=128.0650),
                    dict(key="gate1", name="주흘관(제1관문)", lat=36.7630, lon=128.0750)],
             tales=[("YN21", "문경새재 성황(여신)·과거길 선비", "A"), ("JG14", "여우고개·구미호", "D"), ("JG22", "호랑이와 곶감", "D")]),
        dict(key="sangju", name="상주 읍성 남문 밖", title="상주", kind="town", lat=36.4110, lon=128.1590, a=160, culture="yeongnam",
             gate_name="상주 남문", tales=[("—", "상주 장시(지나가는 성읍)", "배경"), ("JG28", "좁쌀 한 톨로 장가든 총각", "D")]),
        dict(key="hahoe", name="하회 마을과 하회 나루(낙동강)", title="하회", kind="naru", lat=36.5390, lon=128.5180, a=180, culture="yeongnam",
             river=dict(id="nakdong_hahoe", name="낙동강(하회 물돌이)", width=20.0, grade="A"), extra=["hahoe"],
             tales=[("YN11", "하회탈 허도령", "A"), ("YN22", "나루 뱃사공·물귀신", "D")]),
        dict(key="jebiwon", name="제비원(연미사 석불)·원집", title="제비원", kind="jebiwon", lat=36.5960, lon=128.7110, a=130, culture="yeongnam",
             tales=[("YN10", "성주풀이 제비원 — 성주신 본향", "A"), ("JG14", "여우고개", "D")]),
      ]),
 dict(id="GG_HANYANG-GW_GANGNEUNG", name="관동대로(한양→강릉)", climate="central", alpine={"1": 650.0},
      frm={"region": "GG_HANYANG", "x": 2540.0, "z": -560.0, "name": "관동대로(망우리·평구 방면)"},
      to=P("GW_GANGNEUNG", "portal_daegwallyeong", name="대관령 서쪽(횡계 고원)"),
      stops=[
        dict(key="wonju", name="원주 감영 고을", title="원주", kind="town", lat=37.3480, lon=127.9500, a=160, culture="gwandong",
             gate_name="원주 감영 문루", tales=[("—", "강원 감영 고을(지나가는 성읍)", "배경"), ("JG12", "도깨비 씨름", "D")]),
        dict(key="chiak", name="치악산 기슭 주막(상원사 길)", title="치악산", kind="pass", lat=37.4000, lon=128.0000, a=140, culture="gwandong",
             tales=[("GD01", "은혜 갚은 꿩 — 치악산 상원사 종", "A"), ("JG24", "효자와 호랑이", "D")]),
        dict(key="hoenggye", name="횡계 고원(대관령 서쪽 마을)", title="횡계", kind="alpine_village", lat=37.6720, lon=128.7000, a=150, culture="gwandong",
             tales=[("GD03", "대관령 산신·국사성황(강릉 단오 — 고개 너머)", "A+"), ("JG01", "해와 달이 된 오누이(산골 호랑이)", "D")]),
      ]),
 dict(id="GG_HANYANG-HH_HWANGJU", name="의주대로(한양→개성→황주)", climate="central",
      frm=P("GG_HANYANG", "to_pyeongyang", name="무악재 너머 의주대로"),
      to=P("HH_HWANGJU", "to_kaesong", name="봉산·서흥 방면 남쪽 끝"),
      stops=[
        dict(key="imjin", name="임진나루(임진강)", title="임진나루", kind="naru", lat=37.8880, lon=126.7460, a=150, culture="giho",
             river=dict(id="imjingang", name="임진강", width=22.0, grade="A"),
             tales=[("YN22", "나루 뱃사공·물귀신", "D"), ("JG11", "도깨비 다리", "D")]),
        dict(key="kaesong", name="개성(송도) 남대문 밖", title="개성", kind="town", lat=37.9690, lon=126.5540, a=170, culture="giho",
             gate_name="개성 남대문", extra=["market"], tales=[("GH18", "전우치 — 송도 도사", "B"), ("—", "송상(개성 상인) 장시", "배경")]),
        dict(key="seonjuk", name="선죽교(정몽주 핏자국)", title="선죽교", kind="bridge", lat=37.9840, lon=126.5620, a=110, culture="giho",
             river=dict(id="seonjuk_stream", name="자남산 개울(선죽교)", width=6.0, grade="C", type="돌다리"),
             tales=[("GH19", "선죽교 핏자국", "A")]),
        dict(key="cheongseok", name="청석골 고갯길", title="청석골", kind="pass", lat=38.0600, lon=126.4700, a=140, culture="haeseo",
             extra=["sanchae"], tales=[("HS04", "임꺽정(실록형) 청석골 산채", "B"), ("HS05", "청석골 만남", "C"), ("JG23", "호랑이 형님", "D")]),
        dict(key="seoheung", name="서흥 길가 주막", title="서흥", kind="jumak", lat=38.4150, lon=126.2100, a=120, culture="haeseo",
             tales=[("JG12", "도깨비 씨름·도깨비불", "D")]),
      ]),
 dict(id="HH_HWANGJU-PA_PYEONGYANG", name="의주대로(황주→평양)", climate="north",
      frm=P("HH_HWANGJU", "to_pyeongyang", name="중화 방면 북쪽 끝"),
      to=P("PA_PYEONGYANG", "to_hanyang", name="중화길 남쪽 끝"),
      stops=[
        dict(key="junghwa", name="중화 고을(평안도 첫 고을)", title="중화", kind="village", lat=38.8680, lon=125.8030, a=150, culture="gwanseo",
             extra=["jumak_in"], tales=[("JG22", "호랑이와 곶감", "D"), ("JG13", "여우누이", "D")]),
      ]),
 dict(id="GG_HANYANG-HG_HAMHEUNG", name="경흥대로(한양→철령→함흥)", climate="north", alpine={"2": 600.0}, sea=True,
      frm=P("GG_HANYANG", "to_hamheung", name="혜화문 밖 경흥대로"),
      to=P("HG_HAMHEUNG", "to_yeongheung", name="정평·함흥 방면(경흥대로 북동 끝)"),
      stops=[
        dict(key="chukseok", name="축석령(효자와 호랑이)", title="축석령", kind="pass", lat=37.7880, lon=127.1020, a=120, culture="giho",
             tales=[("JG24", "효자와 호랑이(축석령 오백주)", "D"), ("JG33", "성황당 돌무더기", "D")]),
        dict(key="cheorwon", name="철원 길가 마을", title="철원", kind="jumak", lat=38.2050, lon=127.2150, a=120, culture="gwandong",
             tales=[("JG12", "도깨비 씨름", "D")]),
        dict(key="cheollyeong", name="철령(철령관)", title="철령", kind="pass_gate", lat=38.8150, lon=127.3670, a=180, culture="gwanbuk", kh=0.22,
             gate_name="철령관", tales=[("GB05", "철령 — 이항복 귀양 노래", "A"), ("JG01", "해와 달이 된 오누이(고개 호랑이)", "D")]),
        dict(key="wonsan", name="원산포 바닷가 마을", title="원산", kind="coast", lat=39.1530, lon=127.4430, a=150, culture="gwanbuk",
             tales=[("JG30", "소금 나오는 맷돌", "D")]),
        dict(key="yeongheung", name="영흥 갈림길 주막(이성계 고향 — 평양 양덕길이 갈라짐)", title="영흥 갈림길", kind="jumak", lat=39.5500, lon=127.2500, a=140, culture="gwanbuk",
             branch=dict(route="PA_PYEONGYANG-HG_HAMHEUNG", name="고원·양덕·평양 갈림길"),
             tales=[("GB06", "이성계 활·말 이야기", "B"), ("JG22", "호랑이와 곶감", "D")]),
      ]),
 dict(id="PA_PYEONGYANG-HG_HAMHEUNG", name="평양→함흥(성천·양덕·고원길)", climate="north", alpine={"2": 650.0},
      frm=P("PA_PYEONGYANG", "to_hamheung", name="칠성문 밖 북쪽 끝"),
      to={"route": "GG_HANYANG-HG_HAMHEUNG", "name": "영흥 갈림길(경흥대로와 만남 — 함흥·한양 방면)", "lat": 39.5500, "lon": 127.2500},
      stops=[
        dict(key="seongcheon", name="성천(강선루 아래 마을)", title="성천", kind="village", lat=39.2470, lon=126.2200, a=140, culture="gwanseo",
             extra=["pavilion"], tales=[("—", "성천 강선루 — 관서 명루(지나가는 고을)", "배경"), ("JG03", "선녀와 나무꾼", "D")]),
        dict(key="yangdeok", name="양덕 산골 고갯길", title="양덕", kind="pass", lat=39.2170, lon=126.6550, a=150, culture="gwanseo",
             extra=["alpine_houses"], tales=[("JG01", "해와 달이 된 오누이", "D"), ("JG02", "팥죽할멈과 호랑이", "D")]),
        dict(key="gowon", name="고원 길가 주막", title="고원", kind="jumak", lat=39.4330, lon=127.2400, a=120, culture="gwanbuk",
             tales=[("GB07", "바리데기 함경형(오구)", "B"), ("JG12", "도깨비불", "D")]),
      ]),
 dict(id="HH_HWANGJU-JANGSANGOT", name="장산곶 바닷가 띠(황주→재령→구월산→장산곶)", climate="central", sea=True, dead_end=True,
      frm=P("HH_HWANGJU", "to_jangsangot", name="겸이포길 서쪽 끝"),
      to=None,
      stops=[
        dict(key="jaeryeong", name="재령 들 마을", title="재령", kind="village", lat=38.4000, lon=125.6200, a=140, culture="haeseo",
             extra=["paddy"], tales=[("JG07", "우렁각시", "D")]),
        dict(key="guwol", name="구월산 기슭(삼성사·청석골 산채 길)", title="구월산", kind="shrine", lat=38.4950, lon=125.2900, a=150, culture="haeseo",
             tales=[("HS01", "단군 — 구월산 삼성사", "A+"), ("HS04", "임꺽정 구월산 산채", "B"), ("JG23", "호랑이 형님", "D")]),
        dict(key="jangsan", name="장산곶(인당수 바라보는 곶)", title="장산곶", kind="cape", lat=38.1310, lon=124.6590, a=130, culture="haeseo", tail=230, bearing_to=(38.13, 124.60),
             tales=[("HS03", "장산곶 매", "A"), ("HS02", "심청 — 인당수", "B"), ("JG30", "소금 나오는 맷돌", "D")]),
      ]),
 dict(id="HG_HAMHEUNG-BUKCHEONG", name="북청길(함흥→홍원→북청)", climate="north", sea=True, dead_end=True,
      frm=P("HG_HAMHEUNG", "to_bukcheong", name="동문 밖 북청길"),
      to=None,
      stops=[
        dict(key="hongwon", name="홍원 바닷가 주막", title="홍원", kind="coast", lat=40.0250, lon=127.9600, a=130, culture="gwanbuk",
             tales=[("JG30", "소금 나오는 맷돌", "D"), ("YN22", "뱃사공·물귀신", "D")]),
        dict(key="bukcheong", name="북청 고을(사자놀음 마당)", title="북청", kind="bukcheong", lat=40.0850, lon=128.3000, a=170, culture="gwanbuk", tail=170,
             tales=[("GB04", "북청 사자놀음 유래", "A"), ("JG22", "호랑이와 곶감", "D")]),
      ]),
 dict(id="SEA_NAMHAE_JEJU", name="남해 뱃길(남원→영암 덕진→해남 관두포→제주 화북포)", climate="south", sea=True, sea_lane=("gwandu", "hwabuk"), short="남해 뱃길",
      frm=P("JL_NAMWON_UNBONG", x=-2720.0, z=2086.0, inset=14, name="구례·남해 방면 남쪽 끝"),
      to=P("JJ_JEJU", "portal_hwabuk_ferry", name="화북포 뱃길"), to_window=False,
      stops=[
        dict(key="deokjin", name="영암 덕진다리 주막", title="덕진다리", kind="bridge", lat=34.7930, lon=126.6600, a=120, culture="honam",
             river=dict(id="deokjin_stream", name="덕진 개울", width=6.0, grade="C", type="돌다리"), extra=["jumak_in"],
             tales=[("HN27", "덕진다리 — 주모 덕진의 다리", "A"), ("JG11", "도깨비 다리", "D")]),
        dict(key="gwandu", name="해남 관두포(제주 가는 배 떠나는 포구 — 배 타는 곳)", title="관두포", kind="port", lat=34.6000, lon=126.4680, a=140, culture="honam",
             bearing_to=(34.60, 126.40), tales=[("—", "제주 뱃길(바람 기다리는 포구)", "배경"), ("JG30", "소금 나오는 맷돌", "D"), ("TR08", "영등할망(바람신)", "A")]),
        dict(key="bogil", name="보길도·노화도 앞바다(뱃길)", title="보길도 앞바다", kind="sea", sea_win=True, lat=34.1600, lon=126.4900, a=230, culture="honam",
             kh=0.06, kz=0.28, sea_gap=120, bearing_from=(34.30, 126.49), bearing_to=(34.00, 126.49),
             tales=[("—", "보길도 — 섬 사이 물길(바닷길 쉼)", "배경"), ("—", "바다 귀신·용왕(뱃길 조우)", "D")]),
        dict(key="hwabuk", name="제주 화북포(배 닿는 포구)", title="화북포", kind="port_arrive", lat=33.5220, lon=126.5750, a=150, culture="tamna", tail=150,
             sea_gap=130, bearing_from=(33.60, 126.575), bearing_to=(33.50, 126.575),
             tales=[("TR08", "영등할망(바람신 — 포구 당)", "A"), ("TR12", "고종달(물혈 끊는 술사)", "A")]),
 ]),
]

# ---------------------------------------------------------------- 지형
def smoothstep(t):
    t = np.clip(t, 0.0, 1.0); return t * t * (3 - 2 * t)

BIG_PASS = ("saejae", "pass_gate", "alpine_village")

def snap_low(prev, nxt, v, half=1000.0, step=50.0):
    """via 자리를 앞뒤 창을 잇는 선에 수직으로 ±half m 훑어 가장 낮은 곳(골짜기 길)으로 — 가운데에서 멀수록 조금 벌점"""
    b = bearing((prev["lat"], prev["lon"]), (nxt["lat"], nxt["lon"]))
    re, rn = math.cos(b), -math.sin(b)
    offs = np.arange(-half, half + 1, step)
    la, lo = geo_offset(v["lat"], v["lon"], offs * re, offs * rn)
    h = dem(la, lo) + 0.03 * np.abs(offs)
    k = int(np.argmin(h))
    v["lat"], v["lon"] = float(la[k]), float(lo[k])

# ---- 간격(2026-10-04 사용자 결정 B: 짧게 — 노정 하나를 달리기 4.6m/s로 6~7분, 1.6~2km)
# 쉼터 가운데 사이 STOP_GAP, 큰 고개 PASS_GAP, 권역 포털 끝 ↔ 첫 쉼터 END_GAP. 볼거리(spot)는 DEM 창이 아니라 그 사이 자리라
# 이 숫자만 바꾸면 다시 벌어지거나 좁혀진다(볼거리 자리는 구간 안 비율 + 지형 선호로 다시 정해짐).
STOP_GAP = 300.0
PASS_GAP = 460.0
END_GAP = 250.0
STOP_A = 70.0        # 쉼터 핵심 반길이(실측 창이 온전히 보이는 곳) — 큰 고개는 따로
DS_SCALE = 0.62      # 쉼터 장면 배치 길 방향 거리 배율(1차 장면을 짧은 간격에 맞게 좁힘)
MAX_GRADE = 0.13     # 창 사이 이음 오르막 상한 — 넘으면 창 기준 높이를 눌러 맞춤(수직 관계는 유지, 크기만 줄임)

def windows(R):
    """창(실측 DEM): from_end + 쉼터… + to_end. 쉼터 사이 볼거리(spot)는 창이 아니라 따로(route_sights.VIAS[노정][앞 쉼터 key])"""
    vias = RS.VIAS.get(R["id"], {})
    S = []; SP = []
    if R["frm"]:
        la, lo = region_geo(R["frm"]["region"], R["frm"]["x"], R["frm"]["z"])
        S.append(dict(key="from_end", kind="end", lat=la, lon=lo, a=60, culture=None))
    def add_spots(after, before, culture):
        for v in vias.get(after, [])[:3]:      # 쉼터 사이 2~3곳(넘지 않음)
            d = dict(v); d["kind"] = "via"; d["after"] = after; d["before"] = before
            d.setdefault("culture", culture)
            SP.append(d)
    stops = R["stops"]
    for st in stops:
        if S: add_spots(S[-1]["key"], st["key"], st["culture"])
        d = dict(st)
        if d["kind"] == "saejae": d["a"] = 190.0; d["kh"] = 0.06
        elif d["kind"] in ("pass_gate", "alpine_village"): d["a"] = min(d["a"], 95.0)
        elif d["kind"] == "sea": d["a"] = min(d["a"], 110.0)
        else: d["a"] = min(d["a"], STOP_A)
        S.append(d)
    to = R.get("to")
    if to and R.get("to_window", True):
        if "region" in to: la, lo = region_geo(to["region"], to["x"], to["z"])
        else: la, lo = to["lat"], to["lon"]
        S.append(dict(key="to_end", kind="end", lat=la, lon=lo, a=60, culture=None))
    if stops and S[-1]["key"] == "to_end": add_spots(stops[-1]["key"], "to_end", stops[-1]["culture"])
    return S, SP

def seg_target(A, B, R):
    """창 가운데 사이 목표 거리(m)"""
    if "D" in B: return float(B["D"])
    if A.get("sea_win") or B.get("sea_win"): return float(B.get("sea_gap", 130.0)) + A["a"] + B["a"]
    if A["kind"] == "end" or B["kind"] == "end": return END_GAP
    if A["kind"] in BIG_PASS or B["kind"] in BIG_PASS or A.get("big_pass") or B.get("big_pass"): return PASS_GAP
    return STOP_GAP

def build_route(R):
    rid = R["id"]
    out = os.path.join(OUT_ROOT, rid); os.makedirs(out, exist_ok=True)
    S, SP = windows(R)
    n = len(S)
    for i, s in enumerate(S):
        s.setdefault("kh", KH)
        if "bearing_from" in s and "bearing_to" in s: b = bearing(s["bearing_from"], s["bearing_to"])
        elif "bearing_to" in s: b = bearing((s["lat"], s["lon"]), s["bearing_to"])
        else:
            p = S[max(i - 1, 0)]; q = S[min(i + 1, n - 1)]
            b = bearing((p["lat"], p["lon"]), (q["lat"], q["lon"]))
        s["bear"] = b
        s["alt"] = float(dem(np.array([s["lat"]]), np.array([s["lon"]]))[0])
        if s.get("sea_win"): s["alt"] = 0.0
    # x 자리(순서 유지, 거리 압축)
    xs_c = [0.0] * n
    for k in range(1, n):
        D = max(seg_target(S[k - 1], S[k], R), S[k - 1]["a"] + S[k]["a"] + 120.0)
        xs_c[k] = xs_c[k - 1] + D
    # 창 기준 높이: 실제 해발 × KV, 이음 오르막이 MAX_GRADE를 넘으면 그 차이를 줄인다(높고 낮음의 순서는 그대로)
    kv_eff = KV   # 노정 전체를 같은 비율로 눌러 순서·바다 0m는 그대로 두고 이음 오르막만 MAX_GRADE 아래로
    for k in range(1, n):
        blend = max(xs_c[k] - xs_c[k - 1] - S[k - 1]["a"] - S[k]["a"], 60.0)
        da = abs(S[k]["alt"] - S[k - 1]["alt"])
        if da > 1.0: kv_eff = min(kv_eff, MAX_GRADE * blend / da)
    yb = [s["alt"] * kv_eff for s in S]
    print(f"  kv_eff={kv_eff:.3f}")
    for s, y_ in zip(S, yb): s["ybase"] = y_
    X0 = xs_c[0] - S[0]["a"]; X1 = xs_c[-1] + S[-1].get("tail", S[-1]["a"])
    mid = round((X0 + X1) / 2 / CELL) * CELL
    xs_c = [x - mid for x in xs_c]; X0 -= mid; X1 -= mid
    X0 = math.floor(X0 / CELL) * CELL; X1 = math.ceil(X1 / CELL) * CELL
    for s, x in zip(S, xs_c): s["x"] = x
    W = int(round((X1 - X0) / CELL)) + 1; H = int(round(2 * HALF_W / CELL)) + 1
    gx = X0 + np.arange(W) * CELL; gz = -HALF_W + np.arange(H) * CELL
    # 창 가중치(열마다)
    wts = np.zeros((n, W), np.float32)
    for i, s in enumerate(S):
        lo_core = s["x"] - s["a"]; hi_core = s["x"] + s["a"]
        w = ((gx >= lo_core) & (gx <= hi_core)).astype(np.float32)
        if i > 0:
            pe = S[i - 1]["x"] + S[i - 1]["a"]
            m = (gx > pe) & (gx < lo_core); w[m] = smoothstep((gx[m] - pe) / (lo_core - pe))
        else: w[gx < lo_core] = 1.0
        if i < n - 1:
            ns = S[i + 1]["x"] - S[i + 1]["a"]
            m = (gx > hi_core) & (gx < ns); w[m] = 1.0 - smoothstep((gx[m] - hi_core) / (ns - hi_core))
        else: w[gx > hi_core] = 1.0
        wts[i] = w
    wts /= np.maximum(wts.sum(0, keepdims=True), 1e-6)
    T = np.zeros((H, W), np.float32)
    for i, s in enumerate(S):
        cols = np.nonzero(wts[i] > 0)[0]
        if cols.size == 0: continue
        XX, ZZ = np.meshgrid(gx[cols], gz)
        along = (XX - s["x"]) / s["kh"]; side = ZZ / s["kh"]
        b = s["bear"]; de, dn = math.sin(b), math.cos(b); re, rn = math.cos(b), -math.sin(b)
        east = along * de + side * re; north = along * dn + side * rn
        lat, lon = geo_offset(s["lat"], s["lon"], east, north)
        alt = dem(lat, lon)
        if R.get("sea"): alt = np.where(alt <= 0.3, -4.0, alt)   # 바다(이 자료는 바다가 0m인 곳이 많다)
        else: alt = np.maximum(alt, 1.0)
        # 높이: 창 기준점 해발은 KV로, 그 둘레 기복은 창의 수평 압축 K_h로(문경새재처럼 더 줄인 창도 실제 경사 유지)
        y = s["ybase"] + (alt - s["alt"]) * s.get("kz", s["kh"])
        T[:, cols] += wts[i][cols][None, :] * y
    if R.get("sea"):
        T = np.maximum(T, -6.0)
        # 띠 가장자리에 닿지 않는 낮은 웅덩이(DEM 0m 들판)는 바다가 아니다 → 뭍으로
        lab, nl = ndimage.label(T < -0.05)
        edge = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
        sizes = ndimage.sum(np.ones_like(T), lab, index=np.arange(1, nl + 1))
        keep = np.zeros(nl + 1, bool)
        for k in range(1, nl + 1): keep[k] = (k in edge) and sizes[k - 1] > 400
        T = np.where((lab > 0) & ~keep[lab], np.maximum(T, 0.8), T).astype(np.float32)
    # 잔물결 디테일(창 사이 이음매가 매끈해 보이지 않게, 아주 약하게)
    rng = np.random.default_rng(zlib.crc32(rid.encode()))
    nz = ndimage.gaussian_filter(rng.standard_normal((H, W)).astype(np.float32), 6) * 6.0
    T += nz * np.clip(T / 6.0, 0, 1)
    # ---- 볼거리 자리(spot): 앞뒤 쉼터 장면 사이 빈 구간을 볼거리 수만큼 나누고, 칸 안에서 지형이 말하는 곳으로 옮긴다
    #      (서낭당·쉼바위·폭포 = 높은 곳, 나루·여울·마을·신목 = 낮고 너른 곳, 숲·무덤 = 칸 가운데)
    prof_c = ndimage.uniform_filter1d(T[np.abs(gz) < 40].mean(0), 9)
    keyx = {w_["key"]: w_ for w_ in S}
    groups = {}
    for v in SP: groups.setdefault((v["after"], v["before"]), []).append(v)
    LOW = ("ferry_shed", "dokkaebi_ruin", "hamlet", "sinmok", "roadside")
    HIGH = ("seonang", "view_rock", "pool")
    for (ak, bk), grp in groups.items():
        A_, B_ = keyx[ak], keyx[bk]
        ea = 25.0 if A_["kind"] == "end" else max(A_["a"], 62.0); eb = 25.0 if B_["kind"] == "end" else max(B_["a"], 62.0)
        L_, R_ = A_["x"] + ea, B_["x"] - eb
        if R_ - L_ < 70.0 * len(grp):
            c_ = (A_["x"] + B_["x"]) / 2; L_, R_ = c_ - 35.0 * len(grp), c_ + 35.0 * len(grp)
        wd = (R_ - L_) / len(grp)
        for k, v in enumerate(grp):
            lo_, hi_ = L_ + wd * (k + 0.2), L_ + wd * (k + 0.8)
            cols = np.nonzero((gx >= lo_) & (gx <= hi_))[0]
            if v.get("river") is not None:
                # 물길이 있는 볼거리는 앞뒤 쉼터의 물길(나루·다리)과 떨어지게
                for st_ in (A_, B_):
                    if st_.get("river"): cols = cols[np.abs(gx[cols] - st_["x"]) > 100.0]
            if v["sight"] in LOW and cols.size: x_ = float(gx[cols[np.argmin(prof_c[cols])]])
            elif v["sight"] in HIGH and cols.size: x_ = float(gx[cols[np.argmax(prof_c[cols])]])
            else: x_ = L_ + wd * (k + 0.5)
            v["x"] = x_; v["a"] = float(min(wd / 2, 45.0)); v["kh"] = KH
            t_ = (x_ - A_["x"]) / max(B_["x"] - A_["x"], 1.0)
            v["alt"] = A_["alt"] * (1 - t_) + B_["alt"] * t_
    S_all = sorted(S + SP, key=lambda w_: w_["x"])
    ctx = dict(R=R, S=S_all, gx=gx, gz=gz, X0=X0, X1=X1, W=W, H=H)
    # ---- 물길(나루·다리)
    rivers = []
    for s in S_all:
        rv = s.get("river")
        if not rv: continue
        hb_ = 90.0 if s["kind"] != "via" else max(s["a"], 20.0)
        band = (gx > s["x"] - hb_) & (gx < s["x"] + hb_)
        prof = T[(np.abs(gz) < 40)][:, band].mean(0)
        xr = float(gx[band][np.argmin(ndimage.uniform_filter1d(prof, 9))]) if s["kind"] != "via" else round(s["x"] / CELL) * CELL
        w = rv["width"]; ph = rng.random() * 6
        xr_z = xr + 10.0 * np.sin(gz / 95.0 + ph) - 10.0 * math.sin(ph)
        DX = np.abs(gx[None, :] - xr_z[:, None])
        near = (DX < w / 2 + 3) & (np.abs(gz[:, None]) < 120)
        wy = float(np.percentile(T[near], 10)) + 0.3
        # 물 면은 길이 건너는 둘레(±40m)의 가장 낮은 땅보다 높지 않게 — 비탈에 걸린 물길이 둑 위로 올라앉지 않도록
        band40 = (gx > xr - 40) & (gx < xr + 40)
        wy = min(wy, float(T[np.abs(gz) < 30][:, band40].mean(0).min()) + 0.2)
        T = np.minimum(T, np.where(DX < w / 2 + 110, wy + 0.5 + np.maximum(DX - w / 2, 0) * (0.22 if w > 10 else 0.35), 1e9)).astype(np.float32)
        rivers.append(dict(stop=s["key"], id=rv["id"], name=rv["name"], grade=rv["grade"], width=w, y=wy, xr=xr, xr_z=xr_z,
                           type=rv.get("type", "나루")))
        s["river_x"] = xr
    # ---- 길(최소 비용 경로)
    road = dp_road(T, gx, gz, R.get("sea", False))
    road = gate_bends(road, S, T, gx, gz)
    if R.get("dead_end") and R.get("sea"):
        # 곶·바닷가 끝: 바다로 들어가는 꼬리는 자른다
        hs = sample(T, gx, gz, road)
        keep = len(road)
        for k in range(len(road) - 1, 0, -1):
            if hs[k] < 0.6: keep = k
            else: break
        road = road[:max(keep - 2, 10)]
    # 물 건너는 곳: 길이 물길을 곧게(옆으로 비스듬히 말고) 건너게 — 다리·징검다리·나룻배 방향과 맞춘다
    for rv in rivers:
        zc = float(np.interp(rv["xr"], road[:, 0], road[:, 1]))
        dxr = np.abs(road[:, 0] - rv["xr"])
        wgt = 1.0 - smoothstep((dxr - 24.0) / 26.0)
        road[:, 1] = road[:, 1] * (1 - wgt) + zc * wgt
    lane = None
    if R.get("sea_lane"):
        road, T, lane = sea_lane(R, S, road, T, gx, gz)
    # 성문 자리 터 고르기(문 앞뒤 길이 평평하게 지나가게)
    for st in S:
        for gg, xg in gate_xs(st):
            if "x" not in gg: continue
            XX, ZZ = np.meshgrid(gx, gz)
            dxb = np.maximum(np.abs(XX - gg["x"]) - 12.0, 0); dzb = np.maximum(np.abs(ZZ - gg["z"]) - 24.0, 0)
            dd = np.hypot(dxb, dzb)
            inner = dd == 0
            ph = float(np.median(T[inner]))
            gg["pad_y"] = ph
            T = np.where(dd < 14.0, ph * (1 - smoothstep(dd / 14.0)) + T * smoothstep(dd / 14.0), T).astype(np.float32)
    dense, sarr = densify(road, 1.0)
    roads = [dict(id=rid.lower() + "_main", name=R["name"], cls="대로", width=5.0, pts=dense)]
    # 삼거리 갈래길
    for s in S:
        if s["kind"] == "samgeori" or s.get("branch"):
            k = int(np.argmin(np.abs(dense[:, 0] - s["x"])))
            x0_, z0_ = dense[k]
            L_ = float(np.clip(z0_ + 232.0, 80.0, 150.0))
            br = np.array([[x0_ + 0.0, z0_ - t] for t in np.arange(0, L_, 2.0)] , np.float64)
            br[:, 0] += 18 * np.sin(np.linspace(0, 1.6, len(br)))
            if s.get("branch"):
                roads.append(dict(id="branch_" + s["key"], name=s["branch"]["name"], cls="지선", width=4.0, pts=br))
                s["branch_start"] = (float(x0_), float(z0_)); s["branch_end"] = (float(br[-1, 0]), float(br[-1, 1]))
            else:
                roads.append(dict(id="samgeori_yeongnam", name="삼거리 갈래(영남길)", cls="지선", width=3.5, pts=br))
    # ---- 길 깎기·메우기
    hw_main = ROAD_HW
    prof_list = []
    for r in roads:
        h = sample(T, gx, gz, r["pts"])
        h = ndimage.gaussian_filter1d(h, 14 if r["cls"] == "대로" else 8)
        # 물 건너는 곳 앞뒤 30m는 물 면 + 0.35m로 완만히 내려간다(둑이 가파르면 다리·징검다리·여울 끝에서 막힘)
        for rv in rivers:
            dxr = np.abs(r["pts"][:, 0] - rv["xr"]); near_ = (dxr < 34.0) & (np.abs(r["pts"][:, 1] - float(np.interp(rv["xr"], dense[:, 0], dense[:, 1]))) < 30.0)
            wgt = np.where(near_, 1.0 - smoothstep((dxr - 4.0) / 30.0), 0.0)
            h = h * (1 - wgt) + (rv["y"] + (0.08 if rv.get("type") == "징검다리" else 0.35)) * wgt
        if R.get("sea"): h = np.maximum(h, 1.0)
        prof_list.append(h)
    mask = np.zeros((H, W), bool); pval = np.zeros((H, W), np.float32)
    for r, h in zip(roads, prof_list):
        pts_ = r["pts"]
        keep_ = np.ones(len(pts_), bool)
        if lane is not None and r is roads[0]:
            keep_ = ~((pts_[:, 0] > lane["xa"] + 1.0) & (pts_[:, 0] < lane["xb"] - 1.0))
        ii = np.clip(np.round((pts_[keep_, 0] - X0) / CELL).astype(int), 0, W - 1)
        jj = np.clip(np.round((pts_[keep_, 1] + HALF_W) / CELL).astype(int), 0, H - 1)
        mask[jj, ii] = True; pval[jj, ii] = h[keep_]
    dist, (nj, ni) = ndimage.distance_transform_edt(~mask, return_indices=True)
    dist *= CELL
    rprof = pval[nj, ni]
    blend = smoothstep((dist - hw_main) / 7.0)
    T = np.where(dist < hw_main + 7.0, rprof * (1 - blend) + T * blend, T).astype(np.float32)
    # ---- 물길 다시(길이 메운 곳 포함) — 건너는 곳은 얕은 여울
    lu_water = np.zeros((H, W), bool); lu_sand = np.zeros((H, W), bool)
    for rv in rivers:
        DX = np.abs(gx[None, :] - rv["xr_z"][:, None])
        ch = DX < rv["width"] / 2
        depth = np.where(dist < 6.0, 0.55, 2.0 if rv["width"] > 10 else 0.9)
        T = np.where(ch, np.minimum(T, rv["y"] - depth), T).astype(np.float32)
        lu_water |= ch
        lu_sand |= (DX >= rv["width"] / 2) & (DX < rv["width"] / 2 + (7 if rv["width"] > 10 else 2))
    # ---- 토지이용
    gy_, gx_ = np.gradient(T, CELL); slope = np.hypot(gx_, gy_)
    rel = T - ndimage.minimum_filter(T, size=61)
    lu = np.zeros((H, W), np.uint8)
    lu[(dist < 60) & (slope < 0.25)] = 1
    lu[(slope < 0.14) & (rel < 16) & (dist < 200)] = 3
    lu[(slope < 0.055) & (rel < 4.5) & (T / KV < 450)] = 2
    lu[slope > 0.9] = 7
    sea = (T < -0.05) if R.get("sea") else np.zeros_like(lu_water)
    if R.get("sea"):
        shore = ~sea & (ndimage.distance_transform_edt(~sea) * CELL < 10) & (T < 1.5)
        lu[shore] = 8
    lu[lu_sand] = 8
    lu[lu_water | sea] = 5
    lu[dist < hw_main + 0.6] = 4
    # ---- 기후대
    alp = R.get("alpine", {})
    lat_mean = float(np.mean([s["lat"] for s in S]))
    band = "0" if lat_mean < 36.0 else ("1" if lat_mean < 38.0 else "2")
    alpine_alt = {"0": 1100.0, "1": 1000.0, "2": 850.0}; alpine_alt.update(alp)
    zcode = {"south": 0, "central": 1, "north": 2}
    col_zone = np.zeros(W, np.uint8)
    for i, s in enumerate(S):
        z = 0 if s["lat"] < 36.0 else (1 if s["lat"] < 38.0 else 2)
        col_zone[wts[i] >= wts.max(0)] = z
    cl = np.repeat(col_zone[None, :], H, 0)
    for i, s in enumerate(S):   # 고산: 그 창의 실제 해발이 눈선 가까이(창 기준 높이는 눌렀으므로 실제 해발로 판정)
        if s["alt"] > alpine_alt[band] - 60.0:
            cl[:, wts[i] >= wts.max(0)] = 3
    if R.get("sea"):
        cl[(ndimage.distance_transform_edt(~sea) * CELL < 140)] = 4
    cl4 = cl[::2, ::2]
    ctx.update(T=T, dist=dist, roads=roads, dense=dense, sarr=sarr, rivers=rivers, sea=sea, lu=lu, slope=slope)
    items, settlements, landmarks, passes, crossings, stops_out = place_all(ctx)
    # ---- 볼거리 토지이용: 길가 마을 앞 논·뒤 밭(§24 산→마을→밭→논→내), 호랑이 숲은 길섶까지 숲
    for job, xc, a in ctx.get("lu_jobs", []):
        rz_ = 170.0 if job == "fields" else 300.0
        ell = ((gx[None, :] - xc) / (a + 60.0)) ** 2 + (gz[:, None] / rz_) ** 2
        rng_lu = np.random.default_rng(int(abs(xc)) + 7)
        wob = ndimage.gaussian_filter(rng_lu.standard_normal((H, W)).astype(np.float32), 8) * 3.0
        band_ = ell + wob < 1.0
        free = band_ & (lu != 4) & (lu != 5) & (lu != 8) & (dist > hw_main + 1.5)
        if job == "fields":
            zr_ = np.interp(gx, dense[:, 0], dense[:, 1])[None, :]
            south = gz[:, None] > zr_
            lu[free & south & (slope < 0.09) & (dist < 150)] = 2
            lu[free & ~south & (slope < 0.2) & (dist > 14) & (dist < 110)] = 3
        else:
            lu[free & (lu != 7)] = 0
    if lane is not None:
        crossings.append(dict(id="jeju_sea_lane", name="제주 뱃길(관두포 → 화북포)", type="나루", sea_lane=True, auto=True, boat_kit="route/dotbae",
                              ends=[[round(lane["xa"] - 3.0, 1), round(lane["z"], 1)], [round(lane["xb"] + 3.0, 1), round(lane["z"], 1)]],
                              x=round((lane["xa"] + lane["xb"]) / 2, 1), z=round(lane["z"], 1), river_id="", road_id=roads[0]["id"], confidence="가설",
                              notes="바다 뱃길: 엔진이 갑판 걷기 면을 깔고 배(돛배)가 발밑을 따라온다. auto=true면 배에 오르면 저절로 건너편 포구까지 간다"))
    # ---- 저장
    y_min = float(T.min()) - 1.0; y_max = float(T.max()) + 1.0
    v = np.clip((T - y_min) / (y_max - y_min) * 65535.0, 0, 65535).astype(np.uint16)
    Image.fromarray(v, mode="I;16").save(os.path.join(out, "height.png"))
    Image.fromarray(lu, mode="L").save(os.path.join(out, "landuse.png"))
    Image.fromarray(cl4.astype(np.uint8), mode="L").save(os.path.join(out, "climate.png"))
    # 노정 진행도용 주 도로 점(8m)
    main_pts = dense[::8]
    if len(dense) and (len(dense) - 1) % 8: main_pts = np.vstack([main_pts, dense[-1:]])
    def rnd(a): return [[round(float(p[0]), 1), round(float(p[1]), 1)] for p in a]
    road_json = [dict(id=roads[0]["id"], name=roads[0]["name"], **{"class": "대로"}, width_m=5.0, points=rnd(main_pts))]
    for r in roads[1:]:
        road_json.append(dict(id=r["id"], name=r["name"], **{"class": r["cls"]}, width_m=r["width"], points=rnd(r["pts"][::6])))
    river_json = []
    for rv in rivers:
        pts = [[round(float(rv["xr_z"][j]), 1), round(float(gz[j]), 1), round(rv["y"], 2)] for j in range(0, H, 4)]
        river_json.append(dict(id=rv["id"], name=rv["name"], grade=rv["grade"], width_m=rv["width"], points=pts, flows_to=""))
    geo = [[round(s["lon"], 4), round(s["lat"], 4)] for s in S_all]
    if R.get("to") and not R.get("to_window", True) and "region" in R["to"]:
        la, lo = region_geo(R["to"]["region"], R["to"]["x"], R["to"]["z"]); geo.append([round(lo, 4), round(la, 4)])
    portals = {}
    if R["frm"]: portals["from"] = R["frm"]
    if R.get("to"): portals["to"] = {k: v for k, v in R["to"].items() if k not in ("lat", "lon")}
    for st in S:
        if st.get("branch_end") is not None:
            bx_, bz_ = st["branch_end"]
            portals["branch"] = dict(route=st["branch"]["route"], name=st["branch"]["name"], route_x=round(bx_, 1), route_z=round(bz_, 1),
                                     at=st["key"], note="갈림길 끝 포털 — 다른 노정의 그 노정 쪽 끝(portals.*.route == 이 노정)으로 넘어간다")
    sp = dense[min(30, len(dense) - 1)]
    route = {
        "route_id": rid, "id": rid, "name": R["name"], "kind": "route", **({"short": R["short"]} if R.get("short") else {}),
        "status": "routes 담당 2차(2026-10-04) — 실측 DEM 창(쉼터 + 길목 via) + 압축 이음, 쉼터 사이 1.2~2km, tools/region/make_routes.py로 다시 만든다",
        "from_region": R["frm"]["region"] if R["frm"] else "", "to_region": R["to"].get("region", "") if R.get("to") else "",
        "dead_end": bool(R.get("dead_end")),
        "compression": {"note": "stop마다 실제 길 방향으로 돌린 실측 DEM 창(수평 K_h, 수직 KV=0.3), 창 사이는 smoothstep으로 섞어 이음 — 순서·지형 성격은 실측, 쉼터 사이 거리는 압축(명세 §30)",
                        "windows": [dict(key=s["key"], lat=round(s["lat"], 5), lon=round(s["lon"], 5), bearing_deg=round(math.degrees(s["bear"]), 1),
                                         kh=s["kh"], alt_m=round(s["alt"], 1), x=round(s["x"], 1), core_half_m=s["a"]) for s in S]},
        "projection": {"K": KV, "y_base_alt": 0.0, "lat0": round(lat_mean, 4), "lon0": round(float(np.mean([s["lon"] for s in S])), 4),
                       "note": "노정은 압축 띠라 경위도 투영이 아니다. y = 해발(m) × 0.3. 전국 지도 위치는 geo_line + 주 도로 진행도"},
        "climate_zone": R.get("climate", "central"),
        "height": {"file": "height.png", "x0": X0, "z0": -HALF_W, "cell": CELL, "w": W, "h": H, "y_min": round(y_min, 3), "y_max": round(y_max, 3),
                   "note": "픽셀(i,j) 중심 = (x0+i*cell, z0+j*cell); y = y_min + v/65535*(y_max-y_min). 16bit, 행=+z"},
        "landuse": {"file": "landuse.png", "x0": X0, "z0": -HALF_W, "cell": CELL, "w": W, "h": H,
                    "classes": {"0": "숲", "1": "풀밭·초지", "2": "논", "3": "밭", "4": "길·맨땅", "5": "물", "6": "마을 터", "7": "바위·벼랑", "8": "모래톱·자갈"}},
        "climate": {"file": "climate.png", "x0": X0, "z0": -HALF_W, "cell": 4.0, "w": int(cl4.shape[1]), "h": int(cl4.shape[0]),
                    "codes": {"0": "south", "1": "central", "2": "north", "3": "alpine", "4": "coast"},
                    "rule": {"alpine_alt_m": alpine_alt, "lat_bands": "lat<36 south, <38 central, else north (창마다)", "coast_km": 0.47}},
        "rivers": river_json, "roads": road_json, "passes": passes, "crossings": crossings,
        "settlements": settlements, "landmarks": landmarks, "stops": stops_out, "sights": ctx.get("sights", []),
        "spawn": {"x": round(float(sp[0]), 1), "z": round(float(sp[1]), 1)},
        "portals": portals, "geo_line": geo,
        "sources": ["AWS Terrain Tiles terrarium z13 (SRTM 등 공개 DEM 합성) — stop 창 지형",
                    "경유지·설화: docs/WORLD_SCOPE_PLAN.md §4, docs/FOLKTALE_CATALOG.md, seolhwa/docs/WORLD_SPEC_v0.3.md §19~30",
                    "stop 경위도는 현대 지명 기준 근사(기억값 — 확인 필요). 고증은 참고용"],
    }
    if R.get("sea"): route["sea"] = {"y": 0.0, "name": "바다", "note": "해발 0m 평면. 띠 안 바다 칸(landuse 5, 하천 아님)"}
    json.dump(route, open(os.path.join(out, "route.json"), "w"), ensure_ascii=False, indent=1)
    json.dump({"area": "route_" + rid, "note": "routes 담당 — tools/region/make_routes.py가 만든다(손으로 고치면 다시 만들 때 덮어씀)", "items": items},
              open(os.path.join(out, "placement_route.json"), "w"), ensure_ascii=False, indent=1)
    print(f"{rid}: sights={len(ctx.get('sights', []))} " + " ".join(f"{a['key']}:{a['sight']}({a['items']})" for a in ctx.get('sights', [])))
    print(f"{rid}: {W}x{H} L={X1 - X0:.0f}m y {y_min:.1f}..{y_max:.1f} stops={len(R['stops'])} items={len(items)} rivers={len(rivers)} sea={int(sea.sum())}")
    return route

def sea_lane(R, S, road, T, gx, gz):
    """관두포 → 화북포 바다 뱃길: 두 포구 사이 길을 곧은 뱃길로 바꾸고(배가 지나는 띠는 깊게 판다), 뱃길 양 끝 x를 돌려준다"""
    ka, kb = R["sea_lane"]
    sa = next(s for s in S if s["key"] == ka); sb = next(s for s in S if s["key"] == kb)
    XX, ZZ = np.meshgrid(gx, gz)
    # 뱃길 시작: 관두포 다음 길이 처음 물에 닿는 자리(그 z로 곧게 화북포까지)
    lz = -40.0   # 뱃길 z: 북쪽 섬들(z < −95)이 화면 위로 보이게 띠 가운데보다 조금 북쪽
    jl = int(np.argmin(np.abs(gz - lz)))
    prof = ndimage.uniform_filter1d(T[max(jl - 4, 0):jl + 5].max(0), 5)
    cand = np.nonzero((gx > sa["x"]) & (gx < sb["x"]) & (prof < -0.6))[0]
    if cand.size == 0:
        print("  sea prof", sa["x"], sb["x"], [round(float(v), 1) for v in prof[(gx > sa["x"]) & (gx < sb["x"])][::10]])
    xa = float(gx[cand[0]]); xb = float(gx[cand[-1]])
    inl = (XX > xa + 6) & (XX < xb - 6)
    dz = np.abs(ZZ - lz)
    T = np.where(inl & (dz < 70), np.minimum(T, -4.0 + np.maximum(dz - 30.0, 0) * 0.25), T).astype(np.float32)
    def zat(x): return float(np.interp(x, road[:, 0], road[:, 1]))
    pre = road[road[:, 0] < xa - 40]; post = road[road[:, 0] > xb + 40]
    pre = road[road[:, 0] < sa["x"] - 30]
    z0_ = zat(sa["x"] - 30)
    a1 = catmull([(sa["x"] - 30, z0_), (min(sa["x"] - 10, xa - 14), (z0_ + lz) / 2), (xa - 5, lz), (xa, lz)], 3.0)
    mid = np.stack([np.arange(xa, xb, 4.0), np.full(len(np.arange(xa, xb, 4.0)), lz)], 1)
    b1 = catmull([(xb, lz), (xb + 6, lz), (xb + 20, (zat(xb + 40) + lz) / 2), (xb + 40, zat(xb + 40))], 3.0)
    road = np.vstack([pre, a1, mid, b1, post])
    print(f"  sea lane x {xa:.0f}..{xb:.0f} ({xb - xa:.0f}m) z={lz}")
    return road, T, dict(xa=xa, xb=xb, z=lz)

def sample(T, gx, gz, pts):
    fi = (pts[:, 0] - gx[0]) / CELL; fj = (pts[:, 1] - gz[0]) / CELL
    return ndimage.map_coordinates(T, [fj, fi], order=1, mode="nearest")

def densify(pts, step):
    pts = np.asarray(pts, np.float64)
    seg = np.hypot(*np.diff(pts, axis=0).T); s = np.concatenate([[0], np.cumsum(seg)])
    ss = np.arange(0, s[-1], step)
    return np.stack([np.interp(ss, s, pts[:, 0]), np.interp(ss, s, pts[:, 1])], 1), ss

def dp_road(T, gx, gz, sea):
    ci = np.arange(4, len(gx) - 4, 4); rj = np.nonzero(np.abs(gz) <= 200)[0][::2]
    Hc = T[np.ix_(rj, ci)].T   # (cols, rows)
    zr = gz[rj]
    node = 0.35 * (Hc - Hc.min(1, keepdims=True)) + 0.0007 * zr[None, :] ** 2
    if sea: node += 400.0 * (Hc < 0.5)
    nc, nr = Hc.shape
    cost = node[0].copy(); back = np.zeros((nc, nr), np.int8)
    for i in range(1, nc):
        best = np.full(nr, np.inf); arg = np.zeros(nr, np.int8)
        for dk in (-2, -1, 0, 1, 2):
            prev = np.full(nr, np.inf); hp = np.full(nr, np.nan)
            if dk >= 0:
                prev[dk:] = cost[:nr - dk]; hp[dk:] = Hc[i - 1, :nr - dk]
            else:
                prev[:dk] = cost[-dk:]; hp[:dk] = Hc[i - 1, -dk:]
            c = prev + 2.5 * np.abs(Hc[i] - np.nan_to_num(hp)) + 1.2 * abs(dk)
            m = c < best; best[m] = c[m]; arg[m] = dk
        cost = best + node[i]; back[i] = arg
    k = int(np.argmin(cost)); path = np.zeros(nc, int)
    for i in range(nc - 1, -1, -1):
        path[i] = k; k = int(k - back[i, k])
    z = ndimage.gaussian_filter1d(zr[path].astype(np.float64), 3.0)
    return np.stack([gx[ci].astype(np.float64), np.clip(z, -205, 205)], 1)

def catmull(ctrl, step=3.0):
    ctrl = np.asarray(ctrl, np.float64); out = []
    P_ = np.vstack([ctrl[0], ctrl, ctrl[-1]])
    for i in range(1, len(P_) - 2):
        p0, p1, p2, p3 = P_[i - 1], P_[i], P_[i + 1], P_[i + 2]
        n = max(2, int(np.hypot(*(p2 - p1)) / step))
        for t in np.linspace(0, 1, n, endpoint=False):
            t2, t3 = t * t, t * t * t
            out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3))
    out.append(ctrl[-1]); return np.array(out)

def gate_xs(s):
    """성문 x 자리(실측 경위도를 창 축에 투영)"""
    res = []
    for g in s.get("gates", []):
        b = s["bear"]
        e = (g["lon"] - s["lon"]) * 111320.0 * math.cos(math.radians(s["lat"])); nn = (g["lat"] - s["lat"]) * 110574.0
        along = e * math.sin(b) + nn * math.cos(b)
        res.append((g, s["x"] + along * s["kh"]))
    if s["kind"] in ("town", "pass_gate"):
        gd = s.setdefault("_gate", dict(key="gate", name=s.get("gate_name", "성문")))
        res.append((gd, s["x"] + (0.0 if s["kind"] == "pass_gate" else -40.0)))
    return res

def gate_bends(road, S, T, gx, gz):
    for s in S:
        for g, xg in gate_xs(s):
            zA = float(np.interp(xg - 60, road[:, 0], road[:, 1])); zB = float(np.interp(xg + 60, road[:, 0], road[:, 1]))
            zg = (zA + zB) / 2
            ctrl = [(xg - 60, zA), (xg - 32, zg + 30), (xg - 8, zg + 30), (xg, zg + 20), (xg, zg - 20), (xg + 8, zg - 30), (xg + 32, zg - 30), (xg + 60, zB)]
            seg = catmull(ctrl, 3.0)
            before = road[road[:, 0] < xg - 60]; after = road[road[:, 0] > xg + 60]
            road = np.vstack([before, seg, after])
            g["x"] = xg; g["z"] = zg
    return road

# ---------------------------------------------------------------- 배치
class Placer:
    def __init__(s, ctx):
        s.c = ctx; s.items = []; s.disks = []
        s.dense = ctx["dense"]; s.sarr = ctx["sarr"]
        s.sub = [r["pts"] for r in ctx["roads"]]
        allp = np.vstack(s.sub)
        from scipy.spatial import cKDTree
        s.tree = cKDTree(allp)
        s.dropped = []
    def s_of_x(s, x):
        return float(s.sarr[int(np.argmin(np.abs(s.dense[:, 0] - x)))])
    def at(s, s0, ds, off):
        sv = np.clip(s0 + ds, 0, s.sarr[-1]); k = int(np.clip(np.searchsorted(s.sarr, sv), 1, len(s.dense) - 2))
        t = s.dense[min(k + 4, len(s.dense) - 1)] - s.dense[max(k - 4, 0)]; t = t / max(np.hypot(*t), 1e-6)
        nrm = np.array([t[1], -t[0]])
        if nrm[1] > 0: nrm = -nrm
        p = s.dense[k] + nrm * off
        th = math.atan2(-t[1], t[0]) if t[0] > 0.3 else 0.0
        return float(p[0]), float(p[1]), float(np.clip(th, -0.45, 0.45))
    def h(s, x, z): return float(sample(s.c["T"], s.c["gx"], s.c["gz"], np.array([[x, z]]))[0])
    def ok(s, kit, x, z, fp, ry, flatten, road_ok=False, water_ok=False):
        r = math.hypot(fp[0], fp[1]) / 2
        if abs(z) > HALF_W - r - 6 or x < s.c["X0"] + r + 6 or x > s.c["X1"] - r - 6: return "edge"
        if not road_ok:
            d, _ = s.tree.query([x, z])
            if d < min(fp) / 2 + ROAD_HW + 1.5: return "road"
        for (dx, dz, dr) in s.disks:
            if math.hypot(dx - x, dz - z) < dr + r * 0.85: return "overlap"
        if not water_ok:
            for rv in s.c["rivers"]:
                xr = float(np.interp(z, s.c["gz"], rv["xr_z"]))
                if abs(x - xr) < rv["width"] / 2 + r * 0.7 + 1: return "water"
            if s.h(x, z) < 0.6 and s.c["R"].get("sea"): return "sea"
        if flatten:
            xs = np.linspace(x - fp[0] / 2, x + fp[0] / 2, 5); zs = np.linspace(z - fp[1] / 2, z + fp[1] / 2, 5)
            XX, ZZ = np.meshgrid(xs, zs)
            hh = sample(s.c["T"], s.c["gx"], s.c["gz"], np.stack([XX.ravel(), ZZ.ravel()], 1))
            if hh.max() - hh.min() > max(7.0, 0.45 * max(fp)): return "steep"
        return None
    def add(s, sid, group, kit, params, s0, ds, off, flatten=True, ry=None, y=None, fp=None, note=None, road_ok=False, water_ok=False, tries=6, xz=None, clear_veg=True):
        fp = fp or FP.get(kit) or (6.0, 6.0)
        for t in range(tries):
            if xz is not None and t == 0: x, z, th = xz[0], xz[1], 0.0
            else:
                o = off + (math.copysign(4.0 * t, off) if off != 0 else 0.0); d2 = ds * DS_SCALE + (0 if t % 2 == 0 else (5.0 if t % 4 == 1 else -5.0))
                x, z, th = s.at(s0, d2, o)
            r_ = th if ry is None else ry
            why = s.ok(kit, x, z, fp, r_, flatten, road_ok, water_ok)
            if why is None:
                it = {"id": sid, "kit": kit, "params": params, "x": round(x, 2), "z": round(z, 2), "ry": round(r_, 4), "y": y,
                      "flatten": flatten, "clear_veg": clear_veg, "group": group}
                if note: it["note"] = note
                s.items.append(it); s.disks.append((x, z, math.hypot(fp[0], fp[1]) / 2))
                return it
        s.dropped.append((sid, why)); return None

def place_all(ctx):
    R = ctx["R"]; S = ctx["S"]; pl = Placer(ctx)
    settlements, landmarks, passes, crossings, stops_out = [], [], [], [], []
    rid = R["id"]; pre = "rt_"
    total = pl.sarr[-1]
    seed = [100]
    def sd(): seed[0] += 1; return seed[0]
    for s in S:
        if s["kind"] == "end":
            continue
        if s["kind"] in ("via", "sea"):
            place_sight(pl, s, ctx, sd, settlements, landmarks, crossings)
            continue
        c = s["culture"]; g = s["name"]; key = s["key"]; s0 = pl.s_of_x(s["x"])
        n0 = len(pl.items)
        I = lambda name: f"{pre}{key}_{name}"
        house = HOUSE[c]; comp = COMP[c]
        def H1(name, ds, off, kk=None):
            k_, p_, f_ = kk or house; return pl.add(I(name), g, k_, dict(p_, seed=sd()), s0, ds, off, fp=f_)
        def jumak(ds, off=13.0, pref="jumak"):
            pl.add(I(pref), g, "village/jumak", {"seed": sd()}, s0, ds, off)
            pl.add(I(pref + "_wood"), g, "village/firewood", {"seed": sd(), "kind": "stack"}, s0, ds + 9, off + 7, flatten=False)
            pl.add(I(pref + "_jige"), g, "village/jige", {"seed": sd(), "load": "wood"}, s0, ds - 8, 6.5, flatten=False)
        def jangseung(ds):
            pl.add(I("jangseung_m"), g, "village/jangseung", {"seed": sd(), "female": False}, s0, ds, 5.0, flatten=False)
            pl.add(I("jangseung_f"), g, "village/jangseung", {"seed": sd(), "female": True}, s0, ds, -5.0, flatten=False)
        def shrine(ds, off=12.0, dang=True, name="seonghwang"):
            pl.add(I(name), g, "village/seonghwangdang", {"seed": sd(), "dangjip": dang}, s0, ds, off)
            pl.add(I(name + "_cairn"), g, "village/cairn", {"seed": sd()}, s0, ds + 8, off - 3, flatten=False)
        def boats(rv, n=2, side=1):
            zr = float(np.interp(rv["xr"], pl.dense[:, 0], pl.dense[:, 1]))
            for i in range(n):
                zz = zr + side * (11 + 9 * i); xx = float(np.interp(zz, ctx["gz"], rv["xr_z"]))
                pl.add(I(f"narutbae{i}"), g, "village/narutbae", {"seed": sd()}, s0, 0, 0, flatten=False, xz=(xx, zz), road_ok=True, water_ok=True, tries=1, clear_veg=False)
        kind = s["kind"]
        rv = next((r for r in ctx["rivers"] if r["stop"] == key), None)
        if kind == "jumak":
            if s.get("branch_end") is not None:
                # 갈림길: 주막은 갈래길 서쪽, 갈래 어귀에 이정표·서낭(§29 길 갈림), 장승 한 쌍은 갈래길 들머리
                bx0, bz0 = s["branch_start"]
                jumak(-40, 14)
                H1("house1", -70, 16); H1("house2", 48, 28, comp)
                pl.add(I("ijeongpyo"), g, "route/ijeongpyo", {"seed": sd(), "kind": "stone"}, s0, 0, 0, flatten=False, xz=(bx0 + 7.0, bz0 - 8.0),
                       fp=(1.2, 1.0), note="영흥 갈림 이정표(→ 함흥 / → 고원·양덕·평양)")
                pl.add(I("seonang"), g, "village/seonghwangdang", {"seed": sd(), "dangjip": False}, s0, 0, 0, xz=(bx0 + 16.0, bz0 - 26.0), fp=(7.5, 4.6))
                pl.add(I("cairn"), g, "village/cairn", {"seed": sd()}, s0, 0, 0, flatten=False, xz=(bx0 - 9.0, bz0 - 30.0))
                pl.add(I("jangseung_bm"), g, "village/jangseung", {"seed": sd(), "female": False}, s0, 0, 0, flatten=False, xz=(bx0 - 5.0, bz0 - 44.0), road_ok=True)
                pl.add(I("jangseung_bf"), g, "village/jangseung", {"seed": sd(), "female": True}, s0, 0, 0, flatten=False, xz=(bx0 + 5.0, bz0 - 44.0), road_ok=True)
                landmarks.append(dict(id=key + "_junction", name="영흥 갈림길(경흥대로 ↔ 양덕·평양길)", type="갈림길", x=round(float(bx0), 1), z=round(float(bz0), 1)))
            else:
                jumak(0)
                H1("house1", -26, 15); H1("house2", 28, 16, comp)
                jangseung(-55)
                pl.add(I("sotdae"), g, "village/sotdae", {"seed": sd(), "n": 3}, s0, -60, 12, flatten=False)
            if "bigak" in s.get("extra", []):
                pl.add(I("bigak"), g, "landmark/gj_gyerim_bigak", {"seed": sd(), "marker": False}, s0, 58, 14,
                       note="의견비(오수 개 무덤 비) 비각 — 계림 비각 키트를 일반 비각으로 빌려 씀(가설)")
                pl.add(I("bigtree"), g, "nature/big_tree", {"seed": sd(), "variant": "zelkova"}, s0, 72, 22, flatten=False)
        elif kind == "town":
            gate = next(gg for gg, _ in gate_xs(s) if gg["key"] == "gate")
            gate_scene(pl, s, gate, I, g, sd, ctx, walls=3)
            sg = pl.s_of_x(gate["x"] + 70)
            for i, dd in enumerate([0, 18, 36]):
                pl.add(I(f"shop{i}"), g, "village/market_shop", {"seed": sd()}, sg, dd, 11)
            for i, dd in enumerate([6, 24]):
                pl.add(I(f"jwapan{i}"), g, "village/jwapan", {"seed": sd()}, sg, dd, -7, flatten=False)
            H1("house1", (sg - s0) + 62, 16, comp); H1("house2", (sg - s0) + 84, 30)
            pl.add(I("giwa"), g, "village/giwa", {"seed": sd(), "plain": True}, sg, 30, 32)
            pl.add(I("well"), g, "village/well", {"seed": sd()}, sg, 52, -9, flatten=False)
            H1("house3", -110, 15); H1("house4", -128, -16)
            jangseung(-150)
            if "market" in s.get("extra", []):
                for i, dd in enumerate([54, 72]):
                    pl.add(I(f"shop_b{i}"), g, "village/market_shop", {"seed": sd()}, sg, dd, 11)
        elif kind == "village":
            sq = pl.add(I("square"), g, "village/village_square", {"seed": sd()}, s0, 0, 12)
            for i, (dd, oo) in enumerate([(-30, 16), (24, 18), (-8, 38), (40, 40), (-48, 42)]):
                H1(f"comp{i}", dd, oo, comp if i % 2 == 0 else house)
            pl.add(I("well"), g, "village/well", {"seed": sd()}, s0, 14, -8, flatten=False)
            pl.add(I("haystack0"), g, "village/haystack", {"seed": sd()}, s0, -20, -12, flatten=False)
            pl.add(I("haystack1"), g, "village/haystack", {"seed": sd()}, s0, 30, -14, flatten=False)
            jangseung(-80)
            ex = s.get("extra", [])
            if "kongjwi" in ex:
                pl.add(I("jangdok"), g, "village/jangdok", {"seed": sd()}, s0, -18, 30, flatten=False)
                pl.add(I("dok"), g, "village/props", {"seed": sd(), "kind": "dok"}, s0, -4, -10, flatten=False,
                       note="콩쥐 '밑 빠진 독' 사건 자리(두꺼비)")
                pl.add(I("teotbat"), g, "village/teotbat", {"seed": sd()}, s0, 58, 20)
            if "jumak_in" in ex: jumak(70)
            if "paddy" in ex:
                for i in range(3): pl.add(I(f"haystack_f{i}"), g, "village/haystack", {"seed": sd()}, s0, 70 + 12 * i, -30, flatten=False)
            if "pavilion" in ex:
                pl.add(I("jeongja"), g, "village/jeongja", {"seed": sd(), "plain": False}, s0, 75, 24,
                       note="성천 강선루 대신 정자(관서 명루 표지, 가설)")
        elif kind in ("naru",):
            sr = pl.s_of_x(rv["xr"]); w = rv["width"]
            jumak(sr - s0 - w / 2 - 34, 14)
            pl.add(I("boatman"), g, house[0], dict(house[1], seed=sd()), sr, -w / 2 - 26, -15, fp=house[2],
                   note="뱃사공 집")
            pl.add(I("store"), g, "village/heotgan", {"seed": sd()}, sr, -w / 2 - 52, 13, note="나루 창고")
            pl.add(I("ppallae"), g, "village/ppallaeteo", {"seed": sd()}, s0, 0, 0, flatten=False, water_ok=True,
                   xz=(rv["xr"] - w / 2 - 2.5, float(np.interp(rv["xr"], pl.dense[:, 0], pl.dense[:, 1])) - 26), tries=1)
            boats(rv, 2, 1); boats_far = dict(rv);
            zr = float(np.interp(rv["xr"], pl.dense[:, 0], pl.dense[:, 1]))
            zz = zr - 14; pl.add(I("narutbae_n"), g, "village/narutbae", {"seed": sd()}, s0, 0, 0, flatten=False,
                                 xz=(float(np.interp(zz, ctx["gz"], rv["xr_z"])), zz), road_ok=True, water_ok=True, tries=1, clear_veg=False)
            H1("far1", sr - s0 + w / 2 + 30, 15, comp); H1("far2", sr - s0 + w / 2 + 52, -16)
            jangseung(sr - s0 + w / 2 + 80)
            ex = s.get("extra", [])
            if "market" in ex:
                for i, dd in enumerate([0, 18, 36, 54]):
                    pl.add(I(f"shop{i}"), g, "village/market_shop", {"seed": sd()}, sr, w / 2 + 96 + dd, 11)
                for i, dd in enumerate([4, 16, 28, 40, 52]):
                    pl.add(I(f"jwapan{i}"), g, "village/jwapan", {"seed": sd()}, sr, w / 2 + 96 + dd, -7, flatten=False)
                pl.add(I("square"), g, "village/village_square", {"seed": sd()}, sr, w / 2 + 160, 14, note="송파 산대놀이 판 자리")
            if "shrine_bank" in ex:
                shrine(sr - s0 - w / 2 - 70, 30, True, "ungsindan")
            if "hahoe" in ex:
                pl.add(I("jongga"), g, "culture/yeongnam/jongga", {"seed": sd()}, sr, w / 2 + 120, 30, note="하회 종가(양진당·충효당 성격, 가설)")
                pl.add(I("tteul1"), g, "culture/yeongnam/tteuljip", {"seed": sd(), "roof": "giwa"}, sr, w / 2 + 92, 22)
                pl.add(I("tteul2"), g, "culture/yeongnam/tteuljip", {"seed": sd(), "roof": "choga"}, sr, w / 2 + 150, 22)
                pl.add(I("bigtree"), g, "nature/big_tree", {"seed": sd(), "variant": "zelkova"}, sr, w / 2 + 128, -14, flatten=False,
                       note="하회 삼신당 느티나무 자리(가설)")
            crossings.append(dict(id=f"{key}_naru", name=rv["name"].split("(")[0] + " 나루", type="나루", river_id=rv["id"], road_id=ctx["roads"][0]["id"],
                                  x=round(rv["xr"], 1), z=round(zr, 1), confidence="가설", notes="여울처럼 얕게 판 건너는 자리(엔진 나루 건너기 허용 28m) + 나룻배"))
        elif kind == "bridge":
            zr = float(np.interp(rv["xr"], pl.dense[:, 0], pl.dense[:, 1]))
            pl.add(I("bridge"), g, "village/stone_bridge", {"seed": sd(), "len": 12.0, "hw": 1.6, "arch": 0.6}, s0, 0, 0, flatten=False, ry=math.pi / 2,
                   xz=(float(np.interp(zr, ctx["gz"], rv["xr_z"])), zr), road_ok=True, water_ok=True, tries=1, fp=(3.2, 12.0), clear_veg=True)
            if key == "seonjuk":
                pl.add(I("bigak"), g, "landmark/gj_gyerim_bigak", {"seed": sd(), "marker": False}, s0, 24, 15,
                       note="선죽교 표충비각(1740·1872 비) 대신 계림 비각 키트(가설)")
                H1("house1", -36, 16, comp); H1("house2", 52, 30)
                pl.add(I("bigtree"), g, "nature/big_tree", {"seed": sd(), "variant": "broadleaf"}, s0, -18, -14, flatten=False)
            if "jumak_in" in s.get("extra", []):
                jumak(-34); H1("house1", 30, 16); H1("house2", 50, -16, comp)
            crossings.append(dict(id=f"{key}_bridge", name=g, type="돌다리", river_id=rv["id"], road_id=ctx["roads"][0]["id"],
                                  x=round(rv["xr"], 1), z=round(zr, 1), confidence="가설"))
        elif kind in ("pass", "alpine_village", "shrine"):
            if kind == "pass":
                shrine(0, 11); jumak(-110)
                H1("house1", -132, 16, ALPINE_HOUSE if s["alt"] > 450 else None)
                pl.add(I("torch"), g, "village/torch_post", {"seed": sd()}, s0, -96, -6, flatten=False)
                passes.append(dict(id=key, name=g, x=round(pl.at(s0, 0, 0)[0], 1), z=round(pl.at(s0, 0, 0)[1], 1),
                                   y=round(pl.h(*pl.at(s0, 0, 0)[:2]), 2), alt_m=round(s["alt"], 0)))
                if "sanchae" in s.get("extra", []):
                    for i, (dd, oo) in enumerate([(40, 70), (58, 84)]):
                        pl.add(I(f"sanchae{i}"), g, ALPINE_HOUSE[0], {"seed": sd()}, s0, dd, oo, fp=ALPINE_HOUSE[2], note="임꺽정 산채 자리(가설)")
                if "alpine_houses" in s.get("extra", []):
                    for i, dd in enumerate([60, 80]):
                        pl.add(I(f"guitul{i}"), g, ALPINE_HOUSE[0], {"seed": sd()}, s0, dd, 18 + 6 * i, fp=ALPINE_HOUSE[2])
            elif kind == "alpine_village":
                jumak(0)
                for i, (dd, oo) in enumerate([(-30, 18), (28, 20), (-12, 40), (46, 36)]):
                    k_ = ALPINE_HOUSE if i % 2 else HOUSE["gwandong"]
                    pl.add(I(f"house{i}"), g, k_[0], dict(k_[1], seed=sd()), s0, dd, oo, fp=k_[2])
                pl.add(I("haystack"), g, "village/haystack", {"seed": sd()}, s0, 10, -12, flatten=False)
                shrine(90, 12, False, "seonghwang_w")
                passes.append(dict(id=key, name="대관령 서쪽 고원(횡계)", x=round(pl.at(s0, 0, 0)[0], 1), z=round(pl.at(s0, 0, 0)[1], 1),
                                   y=round(pl.h(*pl.at(s0, 0, 0)[:2]), 2), alt_m=round(s["alt"], 0),
                                   notes="대관령 마루와 동쪽 내리막은 강릉 권역(GW_GANGNEUNG) 안 — 포털 너머에서 영서→영동 바뀜이 보인다"))
            else:   # shrine (구월산 삼성사)
                pl.add(I("samun"), g, "landmark/samun", {"seed": sd(), "kind": "outer"}, s0, 0, 20)
                pl.add(I("sadang"), g, "village/giwa", {"seed": sd(), "plain": True}, s0, 0, 38, note="삼성사(환인·환웅·단군 사당) — 민가 기와집 키트로 대신(가설)")
                shrine(-40, 12, False)
                jumak(-90); H1("house1", 40, 16, comp)
                for i, (dd, oo) in enumerate([(80, 80), (96, 92)]):
                    pl.add(I(f"sanchae{i}"), g, ALPINE_HOUSE[0], {"seed": sd()}, s0, dd, oo, fp=ALPINE_HOUSE[2], note="임꺽정 산채 자리(가설)")
                landmarks.append(dict(id=key + "_samseongsa", name="구월산 삼성사(가설 자리)", type="사당", x=round(pl.at(s0, 0, 38)[0], 1), z=round(pl.at(s0, 0, 38)[1], 1)))
        elif kind == "samgeori":
            k = int(np.argmin(np.abs(pl.dense[:, 0] - s["x"])))
            jx, jz = pl.dense[k]
            pl.add(I("willow"), g, "nature/big_tree", {"seed": sd(), "variant": "willow"}, s0, 0, 0, flatten=False, xz=(jx - 14, jz - 12),
                   note="능소 버들(천안삼거리 능수버들)")
            jumak(-36, 14, "jumak_a"); jumak(42, 15, "jumak_b"); jumak(10, -16, "jumak_c")
            H1("house1", -64, 16, comp); H1("house2", 76, 30)
            jangseung(-90)
            pl.add(I("torch"), g, "village/torch_post", {"seed": sd()}, s0, 24, 7, flatten=False)
            landmarks.append(dict(id="samgeori_junction", name="천안삼거리(영남길·호남길 갈림)", type="삼거리", x=round(float(jx), 1), z=round(float(jz), 1)))
        elif kind == "saejae":
            gl = [(gg, xg) for gg, xg in gate_xs(s)]
            for gg, xg in gl:
                gate_scene(pl, s, gg, I, g, sd, ctx, walls=3, prefix=gg["key"])
                landmarks.append(dict(id="saejae_" + gg["key"], name=gg["name"], type="관문", x=round(gg["x"], 1), z=round(gg["z"], 1)))
            g3 = gl[0][1]; g2 = gl[1][1]; g1 = gl[2][1]
            s3, s2, s1 = pl.s_of_x(g3), pl.s_of_x(g2), pl.s_of_x(g1)
            # 고개 마루(3관) 성황 돌무더기, 2관 아래 성황당, 그 사이 주막, 1관~2관 사이 원터
            pl.add(I("cairn_top"), g, "village/cairn", {"seed": sd()}, s3, 70, 9, flatten=False)
            shrine(s2 - s0 + 90, 16, True, "seonghwang")
            pl.add(I("seonghwang_tree"), g, "nature/big_tree", {"seed": sd(), "variant": "broadleaf"}, s2, 104, 28, flatten=False)
            jumak(s2 - s0 - 120, 13, "jumak_a")
            jumak((s1 + s2) / 2 - s0 + 30, 13, "jumak_b")
            wm = (s1 + s2) / 2 - s0 - 40
            wx, wz, _ = pl.at(s0, wm, 26)
            pl.add(I("wonteo_wall"), g, "village/wall_run", {"seed": sd(), "kind": "stone_lite", "h": 0.7, "closed": True, "gaps": [2],
                   "points": [[-11, -8], [11, -8], [11, 8], [-11, 8]], "jitter": 0.4}, s0, wm, 26, flatten=True, fp=(23.0, 17.0),
                   note="조령원 터 — 허물어진 원(院) 담장 터(가설)")
            wit = pl.items[-1] if pl.items and pl.items[-1]["id"] == I("wonteo_wall") else None
            wx, wz = (wit["x"], wit["z"]) if wit else pl.at(s0, wm, 26)[:2]
            pl.add(I("wonteo_house"), g, HOUSE["yeongnam"][0], {"seed": sd()}, s0, wm + 26, 18, fp=HOUSE["yeongnam"][2], note="원터 곁 길손 집")
            pl.add(I("gyogwi"), g, "village/jeongja", {"seed": sd(), "plain": True}, s0, wm - 60, 20, note="교귀정 자리(새재 안 정자, 가설)")
            jangseung(s1 - s0 + 80)
            passes.append(dict(id="mungyeong_saejae", name="문경새재(조령)", x=round(gl[0][0]["x"], 1), z=round(gl[0][0]["z"], 1),
                               y=round(pl.h(gl[0][0]["x"], gl[0][0]["z"]), 2), alt_m=642, notes="3관(조령관)이 마루 — 북쪽 한강 수계 / 남쪽 낙동강 수계"))
            landmarks.append(dict(id="saejae_wonteo", name="조령원 터", type="원터", x=round(wx, 1), z=round(wz, 1)))
        elif kind == "jebiwon":
            pl.add(I("maaebul"), g, "landmark/maaebul_rock", {"seed": sd(), "offering": True, "pillars": False}, s0, 0, 22,
                   note="제비원 석불(연미사 마애여래) — 여원치 마애불 키트를 빌려 씀(크기·얼굴은 다름, 가설)")
            pl.add(I("won"), g, "village/giwa", {"seed": sd(), "plain": True}, s0, -44, 16, note="제비원(연미원) 원집 — 길손 숙소(가설)")
            jumak(42, 14); H1("house1", 74, 30, comp)
            shrine(-90, 12, False)
            landmarks.append(dict(id="jebiwon_buddha", name="제비원 석불(연미사)", type="마애불", x=round(pl.at(s0, 0, 22)[0], 1), z=round(pl.at(s0, 0, 22)[1], 1)))
        elif kind == "pass_gate":
            gate = next(gg for gg, _ in gate_xs(s) if gg["key"] == "gate")
            gate_scene(pl, s, gate, I, g, sd, ctx, walls=3)
            sg = pl.s_of_x(gate["x"])
            shrine(sg - s0 + 70, 14, True)
            jumak(sg - s0 - 110, 13)
            pl.add(I("guitul1"), g, ALPINE_HOUSE[0], {"seed": sd()}, s0, sg - s0 - 136, 18, fp=ALPINE_HOUSE[2])
            H1("house1", sg - s0 + 120, 16)
            passes.append(dict(id=key, name=g, x=round(gate["x"], 1), z=round(gate["z"], 1), y=round(pl.h(gate["x"], gate["z"]), 2), alt_m=round(s["alt"], 0)))
            landmarks.append(dict(id=key + "_gwan", name=s.get("gate_name", "관문"), type="관문", x=round(gate["x"], 1), z=round(gate["z"], 1)))
        elif kind in ("coast", "port", "cape"):
            ch = COAST_HOUSE.get(c, ("village/choga_low", {}, (8.0, 6.2)))
            if kind == "port" and ctx["R"].get("sea_lane"): s0 = pl.s_of_x(s["x"] - 90)   # 배 타는 물가 앞 뭍에 포구 마을
            if kind != "cape": jumak(0)
            for i, (dd, oo) in enumerate([(-30, 15), (26, 16), (-50, -15), (48, -15)]):
                pl.add(I(f"coast{i}"), g, ch[0], dict(ch[1], seed=sd()), s0, dd, oo, fp=ch[2])
            pl.add(I("dok"), g, "village/props", {"seed": sd(), "kind": "dok"}, s0, 10, -8, flatten=False)
            if kind == "port":
                for i, dd in enumerate([70, 86]):
                    pl.add(I(f"store{i}"), g, "village/heotgan", {"seed": sd()}, s0, dd, 12, note="포구 창고(객주 짐)")
                pl.add(I("gaekju"), g, "village/giwa", {"seed": sd(), "plain": True}, s0, -80, 18, note="객주 집(가설)")
            if kind == "cape":
                endx, endz = pl.dense[-1]
                pl.add(I("rock"), g, "landmark/hj_jangsangot_rock", {"seed": sd()}, s0, 0, 0, flatten=False, xz=(float(endx) - 6, float(endz) - 36),
                       water_ok=True, tries=1, note="장산곶 바위 벼랑(인당수 쪽)")
                shrine(-70, 12, False)
                landmarks.append(dict(id="jangsangot_rock", name="장산곶 벼랑", type="곶", x=round(float(endx) - 6, 1), z=round(float(endz) - 36, 1)))
            # 바다 위 배(가까운 바다 칸)
            sea = ctx["sea"]
            if sea.any():
                cx, cz, _ = pl.at(s0, 60 if kind == "port" else 0, 0)
                jj, ii = np.nonzero(sea)
                X = ctx["gx"][ii]; Zs = ctx["gz"][jj]
                dd = np.hypot(X - cx, Zs - cz)
                # 물가에서 8m 이상 떨어진 바다 칸
                deep = ndimage.distance_transform_edt(sea) * CELL
                dd[deep[jj, ii] < 8] = 1e9
                order = np.argsort(dd)[:4000:600]
                for bi, o in enumerate(order[:3]):
                    if dd[o] > 220: break
                    pl.add(I(f"boat{bi}"), g, "village/narutbae", {"seed": sd()}, s0, 0, 0, flatten=False, y=0.0, xz=(float(X[o]), float(Zs[o])),
                           road_ok=True, water_ok=True, tries=1, clear_veg=False, note="포구 배(바다 수면 y=0)")
        elif kind == "port_arrive":
            # 제주 화북포: 배 닿는 물가 → 포구 창고·객주 → 탐라 돌집·돌담, 포구 당(신목), 방사탑. 바다 쪽(x 작은 쪽)이 물가
            for i, (dd, oo) in enumerate([(30, 16), (58, 20)]):
                pl.add(I(f"stone_house{i}"), g, "culture/tamna/stone_house", {"seed": sd(), "kind": "bak" if i else "an"}, s0, dd, oo, fp=(11.8, 7.2))
            pl.add(I("compound"), g, "culture/tamna/compound", {"seed": sd(), "size": "small"}, s0, 96, 26, fp=(19.0, 22.0))
            pl.add(I("store"), g, "village/heotgan", {"seed": sd()}, s0, -6, 13, note="화북포 창고(진상품·객주 짐)")
            pl.add(I("dang"), g, "route/sinmok", {"seed": sd(), "variant": "broadleaf", "cloth": True}, s0, 10, -12, flatten=False, fp=(6.6, 4.2),
                   note="포구 당(해신당 성격 — 영등할망 모시는 바닷가 당, 가설)")
            pl.add(I("bangsatap"), g, "landmark/jj_bangsatap", {"seed": sd()}, s0, 70, -10, flatten=False, fp=(4.0, 4.0))
            pl.add(I("doldam0"), g, "culture/tamna/doldam", {"seed": sd(), "points": [[-9, 0], [9, 0]]}, s0, 44, 9, flatten=False, fp=(18.0, 0.8))
            landmarks.append(dict(id="hwabuk_port", name="화북포(제주 배 닿는 곳)", type="포구", x=round(pl.at(s0, 0, 0)[0], 1), z=round(pl.at(s0, 0, 0)[1], 1)))
        elif kind == "bukcheong":
            pl.add(I("madang"), g, "landmark/hh_bukcheong_madang", {"seed": sd()}, s0, 0, 20)
            for i, (dd, oo) in enumerate([(-34, 16), (36, 18), (-12, 44), (58, 40)]):
                H1(f"comp{i}", dd, oo, comp if i % 2 == 0 else house)
            jumak(-80); pl.add(I("well"), g, "village/well", {"seed": sd()}, s0, 16, -9, flatten=False)
            jangseung(-110)
            landmarks.append(dict(id="bukcheong_madang", name="북청 사자놀음 마당", type="놀이 마당", x=round(pl.at(s0, 0, 20)[0], 1), z=round(pl.at(s0, 0, 20)[1], 1)))
        # 쉼터(settlement)
        mine = pl.items[n0:]
        if mine:
            xs_ = [it["x"] for it in mine]; zs_ = [it["z"] for it in mine]
            bb = [round(min(xs_) - 12, 1), round(min(zs_) - 12, 1), round(max(xs_) + 12, 1), round(max(zs_) + 12, 1)]
        else:
            x_, z_, _ = pl.at(s0, 0, 0); bb = [x_ - 40, z_ - 40, x_ + 40, z_ + 40]
        cx_, cz_, _ = pl.at(s0, 0, 0)
        arche = {"jumak": "pass", "pass": "pass", "pass_gate": "pass", "saejae": "pass", "naru": "river", "bridge": "river", "town": "eupchi",
                 "village": "plain", "samgeori": "pass", "jebiwon": "pass", "alpine_village": "mountain", "shrine": "mountain", "coast": "coast",
                 "port": "coast", "cape": "coast", "bukcheong": "eupchi", "port_arrive": "coast"}[kind]
        zone = "alpine" if kind in ("saejae", "pass_gate", "alpine_village") else ("coast" if arche == "coast" else
               ("south" if s["lat"] < 36 else "central" if s["lat"] < 38 else "north"))
        settlements.append(dict(id=pre + key, name=g, title=s["title"], short=s["title"], type={"river": "나루", "eupchi": "읍성", "coast": "포구"}.get(arche, "쉼터"),
                                x=round(cx_, 1), z=round(cz_, 1), radius_m=round(max(bb[2] - bb[0], bb[3] - bb[1]) / 2, 1), bbox=bb,
                                profile=dict(culture=c, archetype=arche, climate=zone, signature=s["name"])))
        stops_out.append(dict(key=key, id=pre + key, type=kind, name=g, title=s["title"], x=round(cx_, 1), z=round(cz_, 1),
                              t=round(pl.s_of_x(s["x"]) / total, 3), culture=c, real={"lat": s["lat"], "lon": s["lon"], "alt_m": round(s["alt"], 0)},
                              folktales=[dict(code=a, title=b, grade=gr) for a, b, gr in s.get("tales", [])],
                              encounter=encounter(kind, s)))
    if pl.dropped: print("  dropped:", pl.dropped)
    return pl.items, settlements, landmarks, passes, crossings, stops_out

def place_sight(pl, s, ctx, sd, settlements, landmarks, crossings):
    """쉼터 사이 길목 볼거리(via 창) — route_sights.py. 놓은 것은 ctx["sights"](route.json sights)와 ctx["lu_jobs"](논밭·숲 칠하기)에 남긴다."""
    key = s["key"]; g = s["name"]; sight = s.get("sight", "sea"); c = s.get("culture") or "giho"
    I = lambda name: f"rt_{key}_{name}"
    s0 = pl.s_of_x(s["x"]); n0 = len(pl.items)
    house = HOUSE.get(c, HOUSE["giho"]); comp = COMP.get(c, COMP["giho"])
    hi_alt = s["alt"] > 420
    if hi_alt and c not in ("tamna",): house = ALPINE_HOUSE
    rv = next((r for r in ctx["rivers"] if r["stop"] == key), None)
    def add(name, kit, params, ds, off, **kw):
        params = dict(params); params.setdefault("seed", sd())
        return pl.add(I(name), g, kit, params, s0, ds, off, **kw)
    lu_jobs = ctx.setdefault("lu_jobs", [])
    if sight == "seonang":
        add("seonghwang", "village/seonghwangdang", {"dangjip": s["alt"] > 300}, 0, 12)
        add("cairn", "village/cairn", {}, 9, 9, flatten=False)
        add("cairn_s", "village/cairn", {"altar": False}, -14, -7, flatten=False)
        add("pine", "nature/pine", {"s": 1.4}, 22, 14, flatten=False)
    elif sight == "sinmok":
        add("sinmok", "route/sinmok", {"variant": s.get("variant", "zelkova")}, 0, 15, flatten=False)
        add("cairn", "village/cairn", {"altar": False}, 10, 9, flatten=False)
        if c in ("honam", "giho", "yeongnam"):
            add("stone_jang_m", "village/stone_jangseung", {"variant": 0}, -24, 5.0, flatten=False)
            add("stone_jang_f", "village/stone_jangseung", {"variant": 2}, -24, -5.0, flatten=False)
        else:
            add("sotdae", "village/sotdae", {"n": 3}, -22, 8, flatten=False)
    elif sight == "inn_ruin":
        won = s.get("kind_param") == "won"
        add("ruin", "route/ruin_house", {"inn": not won, "w": 7.4 if won else 6.4}, 0, 15, fp=(10.4 if won else 9.4, 6.8))
        if won:
            add("wall", "village/wall_run", {"kind": "stone_lite", "h": 0.6, "closed": True, "gaps": [2, 5], "jitter": 0.5,
                "points": [[-13, -9], [0, -10], [13, -9], [13, 9], [0, 10], [-13, 9]]}, -2, 17, fp=(27.0, 20.0),
                note="옛 원(院) 담장 터(허문 돌담) — 가설")
        add("well", "village/well", {}, 18, 9, flatten=False)
        add("deadwood", "nature/deadwood", {"kind": "snag", "s": 1.2}, -18, 22, flatten=False)
        add("bush_tree", "nature/big_tree", {"variant": "broadleaf", "bare": True}, 26, 26, flatten=False)
    elif sight == "milestone":
        add("ijeongpyo", "route/ijeongpyo", {"kind": "post"}, 0, 5.5, flatten=False)
        add("ijeongpyo_s", "route/ijeongpyo", {"kind": "stone"}, 6, -4.6, flatten=False)
        add("jangseung_m", "village/jangseung", {"female": False}, 14, 5.0, flatten=False)
        add("jangseung_f", "village/jangseung", {"female": True}, 14, -5.0, flatten=False)
        add("tree", "nature/big_tree", {"variant": "zelkova"}, -16, 16, flatten=False)
    elif sight == "hamlet":
        coastal = ctx["R"].get("sea") and float(np.min(ctx["T"][:, max(0, int((s["x"] - ctx["X0"]) / CELL) - 3):int((s["x"] - ctx["X0"]) / CELL) + 3])) < -0.05
        hk = COAST_HOUSE.get(c, ("village/choga_low", {}, (8.0, 6.2))) if coastal else house
        for i, (dd, oo, kk) in enumerate([(-34, 17, comp), (-4, 22, hk), (28, 18, comp), (52, 36, hk)]):
            k_, p_, f_ = kk
            add(f"house{i}", k_, p_, dd, oo, fp=f_)
        add("teotbat", "village/teotbat", {}, 10, 40)
        add("haystack0", "village/haystack", {}, -12, -11, flatten=False)
        add("haystack1", "village/haystack", {}, 6, -12, flatten=False)
        add("yard", "village/yard_props", {"set": "work"}, -16, 30, flatten=False)
        add("well", "village/well", {}, 18, -8, flatten=False)
        # 어귀: 솟대 + 장승 한 쌍(마을 들머리 — 노정 진행 방향 앞쪽)
        add("sotdae", "village/sotdae", {"n": 3}, -66, 10, flatten=False)
        add("jangseung_m", "village/jangseung", {"female": False}, -74, 5.0, flatten=False)
        add("jangseung_f", "village/jangseung", {"female": True}, -74, -5.0, flatten=False)
        lu_jobs.append(("fields", s["x"], s["a"]))
    elif sight == "ferry_shed":
        sr = pl.s_of_x(rv["xr"]); w = rv["width"]
        zr = float(np.interp(rv["xr"], pl.dense[:, 0], pl.dense[:, 1]))
        pl.add(I("shed"), g, "route/ferry_shed", {"seed": sd()}, sr, -w / 2 - 14, 9)
        pl.add(I("boatman"), g, house[0], dict(house[1], seed=sd()), sr, -w / 2 - 34, 17, fp=house[2], note="뱃사공 집")
        for i in range(2):
            zz = zr + 11 + 9 * i; xx = float(np.interp(zz, ctx["gz"], rv["xr_z"]))
            pl.add(I(f"narutbae{i}"), g, "village/narutbae", {"seed": sd()}, s0, 0, 0, flatten=False, xz=(xx, zz), road_ok=True, water_ok=True, tries=1, clear_veg=False)
        pl.add(I("jangseung_m"), g, "village/jangseung", {"seed": sd(), "female": False}, sr, w / 2 + 22, 5.0, flatten=False)
        pl.add(I("jangseung_f"), g, "village/jangseung", {"seed": sd(), "female": True}, sr, w / 2 + 22, -5.0, flatten=False)
        pl.add(I("far_house"), g, comp[0], dict(comp[1], seed=sd()), sr, w / 2 + 40, 18, fp=comp[2])
        pl.add(I("willow"), g, "nature/big_tree", {"seed": sd(), "variant": "willow"}, sr, -w / 2 - 8, -12, flatten=False)
        crossings.append(dict(id=f"{key}_naru", name=rv["name"].split("(")[0] + " 나루", type="나루", river_id=rv["id"], road_id=ctx["roads"][0]["id"],
                              x=round(rv["xr"], 1), z=round(zr, 1), confidence="가설", notes="길목 나루(여울처럼 얕게 판 건너는 자리 + 나룻배)"))
    elif sight == "mound":
        royal = s.get("kind_param") == "royal"
        add("myo0", "route/myo", {"r": 3.4 if royal else 2.1, "stone": True, "n": 1}, 0, 26, fp=(8.8 if royal else 5.6, 10.4 if royal else 7.3))
        add("myo1", "route/myo", {"r": 2.8 if royal else 1.8, "old": True}, 22, 34, fp=(7.4 if royal else 4.6, 9.0 if royal else 6.6))
        add("myo2", "route/myo", {"r": 1.6, "old": True}, -20, 30, fp=(4.2, 6.0))
        add("pine0", "nature/pine", {"s": 1.3}, 10, 40, flatten=False)
        add("pine1", "nature/pine", {"s": 1.1}, -8, 44, flatten=False)
    elif sight == "tiger_forest":
        add("cairn", "village/cairn", {"altar": False}, -40, 8, flatten=False, note="숲 들머리 돌무더기(호환 막이로 돌 얹기)")
        add("deadwood0", "nature/deadwood", {"kind": "snag", "s": 1.3}, -10, 9, flatten=False)
        add("deadwood1", "nature/deadwood", {"kind": "standing", "s": 1.2}, 50, -8, flatten=False)
        add("boulder0", "nature/boulder", {"s": 2.4, "mossy": True}, 20, 10, flatten=False)
        add("boulder1", "nature/boulder", {"s": 1.8, "mossy": True}, 80, 9, flatten=False)
        add("torch", "village/torch_post", {}, -46, -5, flatten=False, note="밤길 횃대(호랑이 막이)")
        lu_jobs.append(("forest", s["x"], s["a"] + 20.0))
    elif sight == "dokkaebi_ruin":
        sr = pl.s_of_x(rv["xr"]); w = rv["width"]
        zr = float(np.interp(rv["xr"], pl.dense[:, 0], pl.dense[:, 1]))
        xc_ = float(np.interp(zr, ctx["gz"], rv["xr_z"]))   # 길 z에서 실제 물길 가운데(물길은 굽이친다)
        pl.add(I("jingeom"), g, "village/jingeom", {"seed": sd(), "len": w + 4.0}, s0, 0, 0, flatten=False, ry=math.pi / 2, xz=(xc_, zr), y=round(rv["y"], 2),
               road_ok=True, water_ok=True, tries=1, fp=(1.4, w + 4.0), clear_veg=True, note="옛 여울목 징검다리")
        pl.add(I("ruin"), g, "route/ruin_house", {"seed": sd(), "inn": False}, sr, -w / 2 - 22, 16, fp=(7.6, 5.6))
        pl.add(I("willow"), g, "nature/big_tree", {"seed": sd(), "variant": "willow"}, sr, w / 2 + 9, 10, flatten=False)
        pl.add(I("deadwood"), g, "nature/deadwood", {"seed": sd(), "kind": "snag", "s": 1.1}, sr, -w / 2 - 6, -10, flatten=False)
        pl.add(I("reeds"), g, "nature/reeds", {"seed": sd(), "n": 9}, sr, w / 2 + 3, -8, flatten=False, fp=(1.0, 0.7))
        crossings.append(dict(id=f"{key}_ford", name=rv["name"], type="징검다리", river_id=rv["id"], road_id=ctx["roads"][0]["id"],
                              x=round(rv["xr"], 1), z=round(zr, 1), confidence="가설", notes="옛 여울목(징검다리, 얕아서 걸어 건넘)"))
    elif sight == "pool":
        h = float(s.get("h", 5.5))
        add("waterfall", "route/waterfall", {"h": h, "r": 4.2}, 0, 24, fp=(11.4, 11.6))
        add("slab", "nature/slab_rock", {"w": 4.0, "d": 2.6}, -10, 13, flatten=False)
        add("willow", "nature/big_tree", {"variant": "broadleaf"}, 14, 15, flatten=False)
        add("cairn", "village/cairn", {"altar": True}, -16, 9, flatten=False, note="소 앞 작은 제단(용왕 비손 자리)")
    elif sight == "roadside":
        add("tree", "nature/big_tree", {"variant": "zelkova"}, 0, 13, flatten=False)
        add("pyeongsang", "village/props", {"kind": "pyeongsang"}, 4, 7.5, flatten=False, fp=(2.0, 1.3))
        add("jige", "village/jige", {"load": "wood"}, -4, 6.5, flatten=False)
        add("firewood", "village/firewood", {"kind": "stack"}, 10, 9, flatten=False)
        add("cairn", "village/cairn", {"altar": False}, -12, -7, flatten=False)
    elif sight == "view_rock":
        add("slab", "nature/slab_rock", {"w": 4.4, "d": 2.8}, 0, -7, flatten=False, road_ok=False)
        add("boulder", "nature/boulder", {"s": 2.6, "mossy": False}, 4, 9, flatten=False)
        add("pine", "nature/pine", {"s": 1.5}, -8, 10, flatten=False)
        add("cairn", "village/cairn", {"altar": False}, 12, -9, flatten=False)
    # 기록
    mine = pl.items[n0:]
    cx_, cz_, _ = pl.at(s0, 0, 0)
    if mine:
        xs_ = [it["x"] for it in mine]; zs_ = [it["z"] for it in mine]
        bb = [round(min(xs_ + [cx_]) - 14, 1), round(min(zs_ + [cz_]) - 14, 1), round(max(xs_ + [cx_]) + 14, 1), round(max(zs_ + [cz_]) + 14, 1)]
    else:
        bb = [round(cx_ - 60, 1), round(cz_ - 60, 1), round(cx_ + 60, 1), round(cz_ + 60, 1)]
    if sight == "tiger_forest":
        bb = [round(s["x"] - s["a"], 1), -200.0, round(s["x"] + s["a"], 1), 200.0]
    if sight == "sea":
        bb = [round(s["x"] - s["a"], 1), -250.0, round(s["x"] + s["a"], 1), 250.0]
    d = RS.SIGHT_DEFAULT.get(sight, dict(tales=[], enc=["용왕·바다 귀신"], night=False))
    tales = s.get("tales") or d["tales"]
    grades = [t[2] for t in tales]
    top = next((gr for gr in ("A+", "A", "B", "C", "D") if gr in grades), "D")
    sid = "rt_" + key
    ctx.setdefault("sights", []).append(dict(
        key=key, id=sid, sight=sight, type=RS.GRADE_TYPE.get(sight, "뱃길"), name=g, title=s.get("title", g), x=round(cx_, 1), z=round(cz_, 1),
        t=round(pl.s_of_x(s["x"]) / pl.sarr[-1], 3), culture=c, bbox=bb, items=len(mine),
        real={"lat": round(s["lat"], 4), "lon": round(s["lon"], 4), "alt_m": round(s["alt"], 0)},
        folktales=[dict(code=a, title=b, grade=gr) for a, b, gr in tales],
        category=RS.CATEGORY.get(sight, "sea"),
        encounter={"grade": "D", "type": RS.GRADE_TYPE.get(sight, "뱃길"), "category": RS.CATEGORY.get(sight, "sea"), "event_grade": top,
                   "candidates": d["enc"], "night_bias": d["night"]}))
    if sight in ("hamlet", "ferry_shed"):
        arche = "river" if sight == "ferry_shed" else ("mountain" if hi_alt else "plain")
        zone = "south" if s["lat"] < 36 else "central" if s["lat"] < 38 else "north"
        settlements.append(dict(id=sid, name=g, title=s.get("title", g), short=s.get("title", g), type="나루" if sight == "ferry_shed" else "길가 마을",
                                x=round(cx_, 1), z=round(cz_, 1), radius_m=round(max(bb[2] - bb[0], bb[3] - bb[1]) / 2, 1), bbox=bb,
                                profile=dict(culture=c, archetype=arche, climate=zone, signature=g)))
    if sight in ("inn_ruin", "pool", "mound", "view_rock", "sinmok", "milestone", "seonang"):
        landmarks.append(dict(id=sid, name=g, type=RS.GRADE_TYPE[sight], x=round(cx_, 1), z=round(cz_, 1)))

def encounter(kind, s):
    """D급 조우 자리(명세 §23): 호랑이=산·고개, 도깨비=나루·주막·장터 외곽·산길, 귀신=나루·폐가·원터, 용왕=큰 강·바다"""
    m = {"pass": ["호랑이", "여우", "도깨비(산길)"], "pass_gate": ["호랑이", "도깨비(산길)"], "saejae": ["호랑이", "여우", "귀신(원터)", "도깨비(산길)"],
         "alpine_village": ["호랑이"], "shrine": ["호랑이", "도깨비(산길)"], "jumak": ["도깨비", "여우"], "samgeori": ["도깨비", "귀신(주막)"],
         "naru": ["도깨비(나루)", "귀신(나루)", "물귀신·용"], "bridge": ["도깨비 다리", "귀신"], "town": ["도깨비(장터 외곽)", "귀신(객사)"],
         "village": ["도깨비", "여우"], "jebiwon": ["여우", "도깨비(산길)"], "coast": ["용왕", "도깨비불"], "port": ["용왕·바다 귀신", "도깨비"],
         "cape": ["용왕", "바다 귀신"], "bukcheong": ["잡귀(사자놀음)", "호랑이"], "port_arrive": ["용왕·바다 귀신", "도깨비불"]}
    return {"grade": "D", "candidates": m.get(kind, ["도깨비"]), "night_bias": kind in ("naru", "bridge", "jumak", "samgeori", "saejae")}

def gate_scene(pl, s, gate, I, g, sd, ctx, walls=3, prefix="gate"):
    """성문(정면 +z, 길이 남→북으로 지남) + 양옆 성벽(경사면 따라 단)"""
    xg, zg = gate["x"], gate["z"]
    pl.add(I(prefix), g, "landmark/seongmun", {"seed": sd(), "name": gate["name"], "open": "none", "width": 14.0, "lu": 1}, 0, 0, 0,
           flatten=True, ry=0.0, xz=(xg, zg), road_ok=True, tries=1, fp=(15.0, 7.0))
    for side in (-1, 1):
        for k in range(walls):
            cx = xg + side * (7.5 + 10.0 + 20.0 * k)
            h0 = pl.h(cx - 10, zg); h1 = pl.h(cx + 10, zg)
            pl.add(I(f"{prefix}_wall{'w' if side < 0 else 'e'}{k}"), g, "landmark/hy_seong_wall",
                   {"seed": sd(), "length": 20.0, "rise": round(h1 - h0, 2), "height": 4.5}, 0, 0, 0, flatten=False, ry=0.0,
                   xz=(cx, zg), road_ok=False, tries=1, fp=(20.0, 2.0))

def main():
    want = sys.argv[1:]
    for R in ROUTES:
        if want and R["id"] not in want: continue
        build_route(R)
        if os.environ.get("SEOLHWA_NO_PARCELS") != "1":
            import parcels   # 논·밭 필지(노정도 같은 형식)
            parcels.run(os.path.join(OUT_ROOT, R["id"]))

if __name__ == "__main__":
    main()
