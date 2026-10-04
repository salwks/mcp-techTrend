"""시나리오 장소 배치(마스터 시나리오 v2.1이 쓰는 장소) — 권역·노정 폴더에 세 파일을 쓴다.
  placement_scenario.json  건물·프롭(kit/scenario/*) — 배치 로더가 다른 placement_*.json과 같이 읽는다
  world_scenario.json      장소 덧붙임(settlements 지명·roads 오솔길·river_lanes 뱃길) — RegionWorld._merge_overlay
  decals_scenario.json     발자국·그을림 데칼(사건 전에는 hidden — 이야기 쪽이 group으로 켠다)
다시 만들기: python3 tools/scenario/place_scenario.py
좌표는 각 권역·노정의 게임 좌표(m). 로컬→월드: ry는 Godot Basis(UP, ry)와 같다(x' = x·cos + z·sin, z' = −x·sin + z·cos).
"""
import json, math, os, zlib

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
RD = os.path.join(ROOT, "region_data")


def w(ox, oz, ry, lx, lz):
    c, s = math.cos(ry), math.sin(ry)
    return round(ox + lx * c + lz * s, 2), round(oz - lx * s + lz * c, 2)


def item(id, kit, x, z, ry=0.0, params=None, **kw):
    it = {"id": id, "kit": kit, "params": dict(params or {}), "x": round(x, 2), "z": round(z, 2), "ry": round(ry, 4)}
    it["params"].setdefault("seed", zlib.crc32(id.encode()) % 9973)
    it.update(kw)
    return it


def prop(id, kind, ox, oz, ory, lx, lz, dy=0.0, ry=0.0, state=None, group="", **params):
    x, z = w(ox, oz, ory, lx, lz)
    if dy > 0.0: params.setdefault("indoor", True)   # 마루 위 = 건물 안
    it = item(id, "scenario/props", x, z, ory + ry, dict(kind=kind, **params), dy=dy, flatten=False, clear_veg=False, yard=False, footprint=[1.2, 1.0])
    if state: it["state"] = state
    if group: it["group"] = group
    return it


def save(folder, name, data):
    path = os.path.join(RD, folder, name)
    with open(path, "w") as f:
        json.dump(data, f, ensure_ascii=False, indent=1)
    print("wrote", os.path.relpath(path, ROOT), len(data.get("items", data.get("settlements", []))))


def trail_pts(pts):
    return [[round(p[0], 2), round(p[1], 2)] for p in pts]


# ---------------------------------------------------------------------------
# 한양: 피맛골 책쾌 책방 + 빈 창고(ACT 1), 칠패 창고 줄·서강 옛 창고(ACT 6)
# ---------------------------------------------------------------------------
def hanyang():
    items = []; decals = []; trails = []
    # 책방: 피맛골(종로 뒤) 가게 줄(z −938)의 빈자리, 앞은 넓은 피맛골, 뒤창은 뒷골목(hy_alley_113, z −942.8)
    BX, BZ = -252.0, -938.0
    F = 0.45
    items.append(item("hy_sc_chaekbang", "scenario/chaekbang", BX, BZ, 0.0, {}, flatten=True, footprint=[9.0, 6.6],
                      title="책쾌의 책방", group="피맛골 책방"))
    items += [
        prop("hy_sc_chaekbang_desk", "chaeksang", BX, BZ, 0, -0.4, -0.2, dy=F, group="피맛골 책방"),
        prop("hy_sc_chaekbang_meoktong", "meoktong", BX, BZ, 0, 0.1, -0.25, dy=F + 0.34, group="피맛골 책방"),
        prop("hy_sc_chaekbang_tea", "chatjan", BX, BZ, 0, 0.75, 0.35, dy=F, group="피맛골 책방"),
        prop("hy_sc_chaekbang_kkeun", "kkeun", BX, BZ, 0, 2.5, 0.9, dy=F, ry=-0.6, group="피맛골 책방"),
        prop("hy_sc_chaekbang_papers", "jangbu", BX, BZ, 0, 1.1, 0.9, dy=F, n=7, group="피맛골 책방"),
        prop("hy_sc_chaekbang_books", "chaekdeomi", BX, BZ, 0, -2.0, 0.5, dy=F, group="피맛골 책방"),
        prop("hy_sc_chaekbang_lamp", "deungjan", BX, BZ, 0, -1.4, -1.6, dy=F, group="피맛골 책방"),
    ]
    # 빈 창고(S1005): 책방 동쪽 옆(사이 3m 샛길이 뒷골목으로 이어짐)
    EX, EZ = -241.6, -938.6
    items.append(item("hy_sc_bin_changgo", "scenario/changgo", EX, EZ, 0.0, {"style": "empty"}, flatten=True, footprint=[8.6, 7.0],
                      title="빈 창고", group="피맛골 책방"))
    items.append(prop("hy_sc_bin_changgo_kkeun", "kkeun", EX, EZ, 0, 0.9, -0.5, dy=0.15, ry=0.4, group="피맛골 책방"))
    # S1003 뒤창 밖 발자국: 뒤창(로컬 1.6, −3.3) → 뒷골목 → 동쪽(청계천·장 쪽)
    wx, wz = w(BX, BZ, 0, 1.6, -3.4)
    trails.append({"id": "hy_s1003_tracks", "kind": "foot", "group": "s1003_tracks", "hidden": True,
                   "points": trail_pts([[wx, wz], [wx + 1.0, -942.8], [-235.0, -943.2], [-223.5, -943.0], [-221.6, -936.0], [-221.6, -928.0]])})

    # 칠패 창고 줄(남대문 밖 칠패 장 동남쪽 빈터, 남향 네 채). 2번 = 박규상 쪽 창고(숨은 바닥)
    CZ = -222.0
    xs = [-749.0, -736.0, -723.0, -710.0]
    fills = ["grain", "grain", "goods", "grain"]
    for i, x in enumerate(xs):
        p = {"style": "chilpae", "fill": fills[i]}
        if i == 1: p["hatch"] = True
        items.append(item("hy_sc_chilpae_changgo_%d" % (i + 1), "scenario/changgo", x, CZ, 0.0, p, flatten=True, footprint=[12.6, 9.0],
                          title="칠패 창고", group="칠패 창고"))
    # 기름통(S8013A 불 붙기 전 치울 수 있는 것)·곡물가마니(밖에 쌓음)
    items.append(prop("hy_sc_chilpae_oil_1", "gireumtong", xs[1], CZ, 0, 3.6, 4.0, group="칠패 창고"))
    items.append(prop("hy_sc_chilpae_oil_2", "gireumtong", xs[2], CZ, 0, -3.8, 4.1, ry=0.5, group="칠패 창고"))
    items.append(prop("hy_sc_chilpae_gamani_1", "gamani", xs[0], CZ, 0, 3.4, 4.3, group="칠패 창고"))
    items.append(prop("hy_sc_chilpae_gamani_2", "gamani", xs[3], CZ, 0, -3.0, 4.4, ry=0.3, group="칠패 창고"))
    items.append(prop("hy_sc_chilpae_jangbu", "jangbu", xs[1], CZ, 0, 3.0, 1.5, dy=0.65, n=8, group="칠패 창고"))
    items.append(prop("hy_sc_chilpae_ham", "munseoham", xs[1], CZ, 0, 3.6, 0.6, dy=0.65, group="칠패 창고"))
    # S8002 벽 그을림 · S8004 젖은 흔적(창고 벽을 따라)
    for i, x in enumerate(xs[:3]):
        decals.append({"id": "hy_s8002_scorch_%d" % i, "kind": "scorch", "x": x - 2.0 + i, "z": CZ + 3.2, "y": 1.5, "ry": 0.0, "wall": True,
                       "size": 2.2, "hidden": True, "group": "s8002_scorch"})
    trails.append({"id": "hy_s8004_wet", "kind": "wet_foot", "group": "s8004_wet", "hidden": True, "step": 0.8,
                   "points": trail_pts([[xs[0] - 5.5, CZ + 5.0], [xs[1], CZ + 4.6], [xs[2] + 4.0, CZ + 4.8], [xs[3] + 6.5, CZ + 3.0]])})
    # S8009 밤 수레 자국(말발굽·바퀴) — 칠패 길에서 2번 창고 앞으로
    trails.append({"id": "hy_s8009_rut_l", "kind": "rut", "group": "s8009_carts", "hidden": True,
                   "points": trail_pts([[-795.0, -236.0], [-770.0, -230.0], [xs[1] - 0.6, CZ + 5.5]])})
    trails.append({"id": "hy_s8009_rut_r", "kind": "rut", "group": "s8009_carts", "hidden": True,
                   "points": trail_pts([[-795.0, -234.4], [-770.0, -228.4], [xs[1] + 0.6, CZ + 5.4]])})
    trails.append({"id": "hy_s8009_hoof", "kind": "hoof", "group": "s8009_carts", "hidden": True, "step": 0.5, "spread": 0.2,
                   "points": trail_pts([[-795.0, -235.2], [-770.0, -229.2], [xs[1], CZ + 6.5]])})

    # 서강 옛 창고(강창): 마포 서쪽, 한강과 무명 내(r011) 사이 강기슭. 옛 불에 탄 창고 터(12년 전) + 다시 쓴 낡은 곡물창고(숨은 바닥·수량패 홈)
    SX, SZ = -2268.0, 758.0
    items.append(item("hy_sc_seogang_changgo", "scenario/changgo", SX, SZ, 0.0, {"style": "seogang", "hatch": True, "groove": True},
                      flatten=True, footprint=[15.6, 10.0], title="서강 옛 창고", group="서강"))
    items.append(item("hy_sc_seogang_teo", "scenario/changgo", SX - 2.0, SZ + 13.5, 0.0, {"style": "chilpae", "fill": "empty", "cold": True, "old": True},
                      flatten=True, footprint=[12.6, 9.0], state="BURNT", title="불탄 창고 터", group="서강"))
    items.append(item("hy_sc_seogang_seonchang", "route/seonchang", -2306.0, 773.0, -math.pi / 2, {"len": 12.0, "sacks": True}, y=0.0,
                      flatten=False, clear_veg=False, yard=False, group="서강"))
    items.append(item("hy_sc_seogang_bridge", "village/seop_bridge", -2252.5, 781.5, -2.25, {"len": 8.0, "hw": 0.8}, flatten=False, clear_veg=True, group="서강"))
    items.append(prop("hy_sc_seogang_gamani", "gamani", SX, SZ, 0, 5.2, 5.0, state="NORMAL", group="서강"))
    world = {
        "note": "시나리오 장소 덧붙임(tools/scenario/place_scenario.py) — 서강 지명, 마포→서강 오솔길",
        "settlements": [{"id": "seogang", "name": "서강 옛 강창(광흥창 아래 강기슭)", "title": "서강", "type": "창고", "x": SX, "z": SZ + 8, "radius_m": 40.0,
                         "bbox": [-2300.0, 735.0, -2235.0, 795.0], "confidence": "가설",
                         "notes": "실제 서강(광흥창 일대)은 마포 서쪽 2~3km — 권역 서쪽 끝(K=0.5)에 넣느라 마포 290m 서쪽 강기슭에 압축해 둠",
                         "profile": {"archetype": "river", "climate": "central", "signature": "강가 곡물창고·선창"}}],
        "roads": [{"id": "sc_seogang_path", "name": "마포→서강 강둑길", "class": "마을길", "width_m": 2.5,
                   "points": [[-2045.0, 905.0], [-2110.0, 872.0], [-2170.0, 842.0], [-2215.0, 815.0], [-2252.5, 781.5], [-2266.0, 768.0]]}],
    }
    save("GG_HANYANG", "placement_scenario.json", {"area": "scenario_hanyang", "note": "마스터 시나리오 v2.1 장소(ACT 1·ACT 6) — tools/scenario/place_scenario.py", "items": items})
    save("GG_HANYANG", "world_scenario.json", world)
    save("GG_HANYANG", "decals_scenario.json", {"items": decals, "trails": trails})


# ---------------------------------------------------------------------------
# 평양: 평안감영 뒤 기록 창고(S5004)
# ---------------------------------------------------------------------------
def pyeongyang():
    GX, GZ = 14.0, -147.0
    F = 0.75
    items = [item("py_sc_girokgo", "scenario/girokgo", GX, GZ, 0.0, {}, flatten=True, footprint=[10.8, 8.0], title="감영 기록 창고", group="감영 기록창고"),
             prop("py_sc_girokgo_ham_1", "munseoham", GX, GZ, 0, -0.6, 0.0, dy=F, group="감영 기록창고"),
             prop("py_sc_girokgo_ham_2", "munseoham", GX, GZ, 0, -2.0, 0.6, dy=F, ry=0.3, group="감영 기록창고"),
             prop("py_sc_girokgo_jangbu", "jangbu", GX, GZ, 0, 2.4, 1.3, dy=F + 0.34, n=5, group="감영 기록창고"),
             prop("py_sc_girokgo_meoktong", "meoktong", GX, GZ, 0, 2.0, 1.25, dy=F + 0.34, group="감영 기록창고"),
             prop("py_sc_girokgo_shelf", "chaekjang", GX, GZ, 0, -3.3, 1.6, dy=F, ry=math.pi / 2, w=1.4, group="감영 기록창고")]
    trails = [{"id": "py_s5004_tracks", "kind": "shoe", "group": "s5004_tracks", "hidden": True,
               "points": trail_pts([[w(GX, GZ, 0, -2.4, -3.6)[0], w(GX, GZ, 0, -2.4, -3.6)[1]], [GX - 4.0, GZ - 5.5], [GX - 10.0, GZ - 6.0], [GX - 18.0, GZ - 4.0]])}]
    save("PA_PYEONGYANG", "placement_scenario.json", {"area": "scenario_pyeongyang", "note": "S5004 감영 기록창고 — tools/scenario/place_scenario.py", "items": items})
    save("PA_PYEONGYANG", "decals_scenario.json", {"items": [], "trails": trails})


# ---------------------------------------------------------------------------
# 함흥→북청 노정: 함관령 동쪽 숲 기슭 빈 역참(S6004~S6010)
# ---------------------------------------------------------------------------
def bukcheong():
    folder = os.path.join("routes", "HG_HAMHEUNG-BUKCHEONG")
    YX, YZ, YR = -202.0, -62.0, 0.1
    F = 0.45
    zb = -2.5
    items = [item("rt_sc_yeokcham", "scenario/yeokcham", YX, YZ, YR, {"seed": 61}, flatten=True, footprint=[19.5, 15.0], title="함관령 옛 역참", group="빈 역참"),
             prop("rt_sc_yeokcham_lamp", "deungjan", YX, YZ, YR, -3.6, 0.8, dy=F, group="빈 역참"),
             prop("rt_sc_yeokcham_map", "byeokjido", YX, YZ, YR, -2.65, zb + 0.22, dy=F, group="빈 역참"),
             prop("rt_sc_yeokcham_hwaro", "hwaro", YX, YZ, YR, -2.0, 0.2, dy=F, group="빈 역참"),
             prop("rt_sc_yeokcham_burnt", "jangbu", YX, YZ, YR, -1.4, 0.6, dy=F, state="BURNT", group="빈 역참"),
             prop("rt_sc_yeokcham_ham", "munseoham", YX, YZ, YR, -4.3, -1.6, dy=F, state="OPEN", group="빈 역참"),
             prop("rt_sc_yeokcham_jipsin", "jipsin", YX, YZ, YR, -2.1, 3.0, state="USED", group="빈 역참")]
    world = {
        "note": "시나리오 장소 덧붙임 — 함관령 옛 역참(S6004~S6010)",
        "settlements": [{"id": "rt_hamgwal_yeokcham", "name": "함관령 옛 역참(버려진 역)", "title": "함관령 옛 역참", "type": "역", "x": YX, "z": YZ,
                         "radius_m": 18.0, "bbox": [-214.0, -74.0, -190.0, -50.0], "confidence": "가설",
                         "profile": {"archetype": "pass", "climate": "north", "signature": "버려진 산중 역참"}}],
        "roads": [{"id": "sc_yeokcham_path", "name": "역참 오르는 옛길", "class": "산길", "width_m": 1.6,
                   "points": [[-203.1, -17.8], [-205.0, -32.0], [-203.5, -46.0], [-202.6, -55.5]]}],
    }
    trails = [{"id": "rt_s6004_tracks", "kind": "foot", "group": "s6004_tracks", "hidden": True, "step": 0.75,
               "points": trail_pts([[-196.6, -22.5], [-204.2, -31.0], [-203.8, -46.0], [-202.4, -55.0]])}]
    save(folder, "placement_scenario.json", {"area": "scenario_bukcheong", "note": "S6004~S6010 빈 역참 — tools/scenario/place_scenario.py", "items": items})
    save(folder, "world_scenario.json", world)
    save(folder, "decals_scenario.json", {"items": [], "trails": trails})


# ---------------------------------------------------------------------------
# 제주: 김녕사굴 입구 + 굴 안(S7003~S7006) — 기존 placement_hub.json 항목 jj_sagul_sagul_01을 이 키트로 바꾼다
# ---------------------------------------------------------------------------
def jeju():
    L = 40.0
    # 입구 얼굴(옛 키트 원점 + 0.6)이 같은 자리에 오게: 새 원점 = 옛 원점 − (L/2 − 0.6)을 ry 방향으로
    OX, OZ, OR = 3432.62, -896.26, 0.0136
    ox, oz = w(OX, OZ, OR, 0.0, -(L / 2 - 0.6))
    hub = os.path.join(RD, "JJ_JEJU", "placement_hub.json")
    d = json.load(open(hub))
    for it in d["items"]:
        if it["id"] == "jj_sagul_sagul_01":
            it.update({"kit": "scenario/jj_sagul", "params": {"seed": 1110, "len": L, "stele": True}, "x": ox, "z": oz, "ry": OR,
                       "footprint": [17.0, L + 6.0], "flatten": True, "title": "김녕사굴"})
    json.dump(d, open(hub, "w"), ensure_ascii=False, indent=1)
    print("updated JJ_JEJU/placement_hub.json jj_sagul_sagul_01 →", ox, oz)
    zm = L / 2 - 0.6
    items = [prop("jj_sc_sagul_geumjul", "geumjul", ox, oz, OR, 0.0, zm + 1.2, w=4.6, group="김녕사굴"),
             prop("jj_sc_sagul_jemul", "jemul", ox, oz, OR, 2.0, zm - 5.9, group="김녕사굴", indoor=True),
             prop("jj_sc_sagul_jipsin", "jipsin", ox, oz, OR, -1.4, 3.0, state="MOVED", group="김녕사굴")]
    tr_s = [[0.3, zm + 2.0], [0.6, zm - 3.0], [-0.4, zm - 10.0], [0.8, 4.0], [0.2, -6.0], [1.4, -14.0]]
    tr_h = [[-0.8, zm + 3.0], [-1.0, zm - 4.0], [-1.6, -6.0], [-1.6, -9.0]]
    trails = [{"id": "jj_s7003_snake", "kind": "snake", "group": "s7003_tracks", "hidden": True, "points": trail_pts([w(ox, oz, OR, *p) for p in tr_s])},
              {"id": "jj_s7003_shoe", "kind": "shoe", "group": "s7003_tracks", "hidden": True, "points": trail_pts([w(ox, oz, OR, *p) for p in tr_h])}]
    save("JJ_JEJU", "placement_scenario.json", {"area": "scenario_jeju", "note": "S7003~S7006 김녕사굴 — tools/scenario/place_scenario.py", "items": items})
    save("JJ_JEJU", "decals_scenario.json", {"items": [], "trails": trails})


# ---------------------------------------------------------------------------
# 황주→장산곶 노정: 곶 앞 바위섬·암초·숨은 갯구멍(S4006) + 만 안쪽 선창에서 섬까지 뱃길
# ---------------------------------------------------------------------------
def jangsangot():
    folder = os.path.join("routes", "HH_HWANGJU-JANGSANGOT")
    IX, IZ = 505.0, -205.0
    items = [item("rt_sc_jangsan_islet", "scenario/hj_islet", IX, IZ, 0.0, {"seed": 4006}, y=0.0, flatten=False, clear_veg=False, yard=False,
                  footprint=[34.0, 30.0], title="장산곶 앞 바위섬", group="장산곶 바위섬")]
    for i, (x, z, n) in enumerate([(445, -128, 3), (470, -150, 4), (528, -165, 3), (463, -207, 3), (540, -226, 4), (418, -160, 2), (487, -232, 2)]):
        items.append(item("rt_sc_jangsan_reef_%d" % i, "scenario/hj_reef", x, z, 0.0, {"seed": 400 + i, "n": n, "r": 3.0}, y=0.0, flatten=False,
                          clear_veg=False, yard=False, footprint=[8.0, 8.0], group="장산곶 바위섬"))
    items.append(item("rt_sc_jangsan_seonchang", "route/seonchang", 360.0, -74.0, math.pi / 2, {"len": 10.0, "sacks": False}, y=0.0, flatten=False,
                      clear_veg=False, yard=False, group="장산곶 바위섬"))
    land = w(IX, IZ, 0.0, -6.0, 9.6)
    world = {
        "note": "시나리오 장소 덧붙임 — 장산곶 앞 바위섬(S4006)과 뱃길",
        "settlements": [{"id": "rt_jangsan_islet", "name": "장산곶 앞 바위섬(숨은 갯구멍)", "title": "장산곶 앞 바위섬", "type": "섬", "x": IX, "z": IZ,
                         "radius_m": 20.0, "bbox": [485.0, -222.0, 525.0, -188.0], "confidence": "가설",
                         "profile": {"archetype": "coast", "climate": "coast", "signature": "암초 뒤 바위섬"}}],
        "roads": [{"id": "sc_jangsan_pier_path", "name": "선창 내려가는 길", "class": "산길", "width_m": 1.6,
                   "points": [[341.2, -10.7], [346.0, -30.0], [350.0, -52.0], [355.0, -72.0]]}],
        "river_lanes": [{"id": "rt_jangsan_islet_lane", "name": "장산곶 바위섬 뱃길", "from_name": "장산곶 선창", "to_name": "바위섬 갯구멍",
                         "boat_kit": "village/narutbae", "boat_params": {"seed": 4006}, "speed": 6.0, "pier": [4.0, 1.0],
                         "points": [[360.0, -74.0], [371.0, -82.0], [382.0, -100.0], [400.0, -122.0], [425.0, -142.0], [452.0, -162.0], [480.0, -173.0],
                                    [503.0, -181.0], [land[0], land[1]]]}],
    }
    save(folder, "placement_scenario.json", {"area": "scenario_jangsangot", "note": "S4006 바위섬 — tools/scenario/place_scenario.py", "items": items})
    save(folder, "world_scenario.json", world)


if __name__ == "__main__":
    hanyang(); pyeongyang(); bukcheong(); jeju(); jangsangot()
