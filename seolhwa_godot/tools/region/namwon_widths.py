"""남원(JL_NAMWON_UNBONG) region.json 하천에 점별 `widths`만 더한다(엔진 5단계 요청 4, 명세 v0.3 §6 '일정한 폭' 금지).
다른 내용(점·수면·등급·width_m·높이맵)은 그대로. 폭 규칙은 build_region의 hydro taper와 같다:
그 점의 D8 집수면적(8m 격자, 둘레 3×3 최대) 등급 폭(D 2.5·C 7·B 15 게임 m), 상류→하류 누적 최대(줄지 않음), 강 width_m 이하, 마지막 점은 width_m.
사용: python3 tools/region/namwon_widths.py   (SEOLHWA_OUT으로 다른 폴더에 쓸 수 있음)"""
import json, os
import numpy as np
from scipy import ndimage
import common as C, hydro, export
assert C.REGION_ID == "JL_NAMWON_UNBONG"
p = os.path.join(C.OUT, "region.json")
reg = json.load(open(p, encoding="utf-8"))
_, _, hlog = hydro.run(np.load(os.path.join(C.CACHE, "alt_fixed.npy")))
acc = ndimage.maximum_filter(hlog["acc"], 3)
gw = {"B": 15.0, "C": 7.0, "D": 2.5}
for r in reg["rivers"]:
    P = np.asarray(r["points"], float)
    i, j = C.xz_to_ij(P[:, 0], P[:, 1], hydro.HC)
    a = acc[np.clip(np.round(j).astype(int), 0, acc.shape[0] - 1), np.clip(np.round(i).astype(int), 0, acc.shape[1] - 1)]
    a = np.maximum.accumulate(ndimage.maximum_filter1d(a, 5))
    w = np.minimum(np.where(a >= hydro.A_B, gw["B"], np.where(a >= hydro.A_C, gw["C"], gw["D"])), r["width_m"])
    w = np.maximum(w, min(r["width_m"], gw["D"])); w[-1] = r["width_m"]
    r["widths"] = [round(float(v), 1) for v in w]
export.write_region(reg, p)
print("widths", sum(len(r["widths"]) for r in reg["rivers"]), "점,", sum(1 for r in reg["rivers"] if len(set(r["widths"])) > 1), "개 하천이 폭 변함")
