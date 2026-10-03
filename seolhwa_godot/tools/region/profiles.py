"""고을 성격표(계약서 §9, 계획서 A0.5·A2·B1): 입지 유형 기본값 + 고을별 profile, 마을 터 짜임."""
import math
import numpy as np

# 계약서 §9 예시 값 그대로
ARCHETYPES = {
    "eupchi":   {"roof": {"giwa": 0.45, "choga": 0.55}, "wall": "todam", "layout": "walled_grid", "entrance": "gate", "people": ["관속", "양반", "장꾼"], "animals": [], "mood": {"fog": 0.3, "wind": 0.2}},
    "plain":    {"roof": {"choga": 0.9, "giwa": 0.1}, "wall": "fence", "layout": "round_cluster", "entrance": "zelkova_square", "people": ["농부"], "animals": ["소"]},
    "river":    {"roof": {"choga": 0.85, "giwa": 0.15}, "wall": "todam", "layout": "fan_from_ferry", "entrance": "ferry", "people": ["뱃사공", "장꾼"], "animals": ["소"]},
    "mountain": {"roof": {"neowa": 0.6, "gulpi": 0.2, "choga": 0.2}, "wall": "stone_terrace", "layout": "terraced", "entrance": "watermill_bridge", "people": ["약초꾼", "사냥꾼", "숯쟁이"], "animals": ["개"]},
    "pass":     {"roof": {"choga": 1.0}, "wall": "none", "layout": "few_roadside", "entrance": "seonghwang_cairn", "people": ["나그네", "주모"], "animals": []},
    "temple":   {"roof": {"choga": 0.8, "giwa": 0.2}, "wall": "todam", "layout": "along_temple_road", "entrance": "stone_jangseung", "people": ["스님", "보살"], "animals": []},
    "coast":    {"roof": {"choga_low": 1.0}, "wall": "stone_net", "layout": "linear_shore", "entrance": "wharf", "people": ["어부", "객주"], "animals": ["갈매기"]},
    "island":   {"roof": {"jeju_stone": 1.0}, "wall": "basalt", "layout": "olle_alleys", "entrance": "dolhareubang", "people": ["해녀"], "animals": ["말"]},
    "capital":  {"special": True},
}

_INWOL = dict(archetype="river", climate="south", layout="linear_street", entrance="mabang_station_flag",
              people=["역졸", "보부상", "장꾼", "뱃사공"], animals=["말", "소"], trades=["역참", "장시"])

PROFILES = {
    "namwon_eup": dict(archetype="eupchi", climate="south", signature="성문과 광한루", trades=["관아", "장시"], notes="남원도호부 읍치, 평지 방형 읍성"),
    "namwon_jang": dict(archetype="eupchi", climate="south", signature="남문 밖 장터 차일과 광한루 가는 길", trades=["장시"]),
    "namwon_hyanggyo": dict(archetype="eupchi", climate="south", signature="향교 홍살문과 은행나무", trades=["향교"]),
    "ibaek": dict(archetype="plain", climate="south", signature="여원재 아래 길가 들마을, 정자나무 마당", trades=["논농사"], notes="고원으로 오르기 전 들"),
    "yeowon_jumak": dict(archetype="pass", climate="south", signature="성황당 돌무더기·오색 천", trades=["주막"]),
    "yeowon_seonghwang": dict(archetype="pass", climate="south", signature="성황당 돌무더기·오색 천", trades=[]),
    "unbong_eup": dict(archetype="plain", climate="south", roof={"choga": 0.8, "giwa": 0.2}, wall="stone", signature="억새 들판 + 돌장승",
                       trades=["논농사", "장시"], notes="고원 들, 동편제 고장. 장터 둘레 둥근 무리"),
    "unbong_jang": dict(archetype="plain", climate="south", roof={"choga": 0.8, "giwa": 0.2}, wall="stone", signature="억새 들판 + 돌장승(장터 둘레 둥근 무리)",
                        trades=["장시"], notes="고원 들 장시"),
    "bijeon": dict(archetype="plain", climate="south", signature="황산대첩비 비각 앞 들마을", trades=["논농사"], notes="동편제 송흥록 마을로 전함"),
    "inwol_yeok": dict(_INWOL, signature="마방과 역 깃발", notes="통영별로 길가 띠 마을(길촌)"),
    "inwol_jang": dict(_INWOL, signature="마방과 역 깃발(장날 보부상 행렬)", notes="통영별로 길가 띠 장시"),
    "inwol_south_village": dict(_INWOL, signature="섶다리 건너 강 남쪽 길가 마을", notes="인월장 맞은편 길가 띠"),
    "sannae": dict(archetype="temple", climate="south", signature="절길·석장승", trades=["논농사", "절 시주"], notes="실상사 가는 절길 따라"),
    "silsangsa_temple": dict(archetype="temple", climate="south", signature="들 가운데 평지 절 + 석장승", trades=["절"], notes="실상사 둘레"),
    "banseon": dict(archetype="mountain", climate="alpine", signature="물레방아 줄 + 계곡 다리", trades=["약초", "숯", "사냥"],
                    notes="뱀사골 어귀 계곡 비탈 계단식. 기후대는 지리산 고지 쪽(잔설·안개) 성격으로 alpine"),
}

# 마을 터(landuse 6) 모양 — 계획서 A2. 남원·여원재·이백·비전은 기존 모양 그대로(키 없음).
SHAPE = {
    "inwol_yeok": dict(layout="linear_street", roads=["tongyeong_byeolro"], half=18.0),
    "inwol_jang": dict(layout="linear_street", roads=["tongyeong_byeolro"], half=18.0),
    "inwol_south_village": dict(layout="linear_street", roads=["inwol_south_lane", "inwol_banseon_road"], half=16.0),
    "banseon": dict(layout="terraced"),
    "unbong_eup": dict(layout="round_cluster"),
    "unbong_jang": dict(layout="round_cluster"),
    "sannae": dict(layout="along_temple_road", roads=["inwol_banseon_road"], half=16.0, toward="silsangsa"),
}

def auto_profile(y4, slope, x, z, climate_code):
    """들마을 후보: 지형(둘레 60m 경사·기복)에 따라 plain 또는 mountain."""
    import common as C
    i, j = [int(round(float(v))) for v in C.xz_to_ij(x, z, C.LU_CELL)]
    r, R = 15, 40                                      # 경사: 둘레 60m, 기복: 둘레 160m(게임)
    sl = slope[max(j - r, 0):j + r + 1, max(i - r, 0):i + r + 1]
    sub = y4[max(j - R, 0):j + R + 1, max(i - R, 0):i + R + 1]
    relief = float(sub.max() - sub.min()) / C.K; med = float(np.median(sl))
    mountain = med > 0.12 or relief > 200.0
    cl = CLIMATE_NAMES[climate_code]
    if mountain:
        return dict(archetype="mountain", climate=cl, signature="산기슭 비탈 너와·돌축대 마을", trades=["밭농사", "약초", "숯"],
                    notes=f"자동: 둘레 60m 경사 중앙값 {med:.2f}, 둘레 160m 기복 {relief:.0f}m(실제) → 산촌(기준 경사 0.12 또는 기복 200m 초과)")
    return dict(archetype="plain", climate=cl, signature="논 가 정자나무 들마을", trades=["논농사"],
                notes=f"자동: 둘레 60m 경사 중앙값 {med:.2f}, 둘레 160m 기복 {relief:.0f}m(실제) → 들마을(기준 경사 0.12 또는 기복 200m 초과면 산촌)")

# ── 기후대 (계획서 B1) ──
CLIMATE_CODES = {"0": "south", "1": "central", "2": "north", "3": "alpine", "4": "coast"}
CLIMATE_NAMES = {int(k): v for k, v in CLIMATE_CODES.items()}
ALPINE_ALT = {0: 1100.0, 1: 1000.0, 2: 850.0}     # 위도대별 고산 하한(실제 해발 m)
COAST_KM = 5.0

def climate_grid(y4, coast_dist_km=None):
    """4m landuse 격자 기후대 코드: 위도 → 남·중·북, 해안 5km 안 → coast, 해발이 하한 이상 → alpine(가장 우선)."""
    import common as C
    from scipy import ndimage
    Hh, Ww = y4.shape
    _, zs = C.ij_to_xz(np.zeros(Hh), np.arange(Hh), C.LU_CELL)
    lat, _ = C.game_to_geo(np.zeros(Hh), zs)
    band = np.where(lat < 36.0, 0, np.where(lat < 38.0, 1, 2)).astype(np.uint8)[:, None] * np.ones((1, Ww), np.uint8)
    code = band.copy()
    if coast_dist_km is not None:
        code[coast_dist_km < COAST_KM] = 4
    alt = C.y_to_alt(ndimage.uniform_filter(y4.astype(np.float64), 7))       # 28m 평균(얼룩 방지)
    thr = np.vectorize(ALPINE_ALT.get)(band)
    code[alt >= thr] = 3
    return code, dict(alpine_alt_m=ALPINE_ALT, coast_km=COAST_KM, lat_bands="lat<36 south, <38 central, else north",
                      coast="권역에 바다 없음 — 해안 거리 무한" if coast_dist_km is None else "해안선 거리")
