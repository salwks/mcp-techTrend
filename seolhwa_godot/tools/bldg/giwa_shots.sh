#!/bin/bash
# 기와 줄(giwa-geometry) 전후 낱장(kit_preview, 창 필요): tools/bldg/giwa_shots.sh <tag> [프로젝트 경로(전: 다른 작업 트리)]
#   → shots/giwa_geometry/raw/<이름>_<tag>.png (이 작업 트리 아래). 게임 인자는 '--' 뒤에만(저장 안전) · 시험 저장 경로.
#   안채(ㄱ자·회첨)·사랑채(팔작): 기준 각(22°) · 1인칭(눈높이 1.6m, 3~8m) · 낮은 해(7시) 스치는 빛 · 가까운 모퉁이(회첨)
OUT="$(cd "$(dirname "$0")/../.." && pwd)/shots/giwa_geometry/raw"
cd "${2:-$(dirname "$0")/../..}"
GODOT=${GODOT:-/opt/homebrew/bin/godot}
T=${1:-after}
mkdir -p "$OUT"
shot(){ timeout 120 $GODOT --path . res://scenes/kit_preview.tscn -- --savefile=user://giwa_test.json --kit=res://kit/bldg/building.gd --params="$1" --shot="$OUT/${2}_$T.png" --w=1200 --h=800 --nofog $3 2>&1 | grep -E 'PREVIEW' | sed 's/.*tris=/tris=/;s/^/'$2' /'; }
A='{"type":"anchae","region":"central","seed":1}'
S='{"type":"sarang","region":"south","seed":1}'
shot "$A" anchae_ref "--time=11 --dist=22 --yaw=-20 --pitch=22"
shot "$A" anchae_low "--time=7 --dist=22 --yaw=-20 --pitch=22"
shot "$A" anchae_fp "--time=11 --center=-2,3.8,4 --dist=7 --yaw=40 --pitch=-10 --fov=60 --fit=0"
shot "$A" anchae_corner "--time=8 --center=-4,4.4,3 --dist=9 --yaw=30 --pitch=35 --fov=60 --fit=0"
shot "$S" sarang_ref "--time=11 --dist=20 --yaw=-20 --pitch=22"
shot "$S" sarang_low "--time=17 --dist=20 --yaw=-20 --pitch=22"
shot "$S" sarang_fp "--time=11 --center=3,3.6,2 --dist=6 --yaw=35 --pitch=-12 --fov=60 --fit=0"
shot "$S" sarang_hap "--time=8 --center=4,4.6,0 --dist=8 --yaw=70 --pitch=26 --fov=60 --fit=0"
# 가까이(같은 각, 거리만): 사랑채 앞 비탈 처마 모퉁이 쪽, 낮은 해(8시) 스치는 빛 — 3·7·15·30m
for d in 3 7 15 30; do shot "$S" sarang_c${d} "--time=8 --center=3.5,4.3,3.2 --dist=$d --yaw=30 --pitch=28 --fov=50 --fit=0"; done
# 거리별(40m 바뀜 앞뒤): 안채 기준 각, 거리만 — 시트는 같은 크기로 잘라 키운다(giwa_sheet.py)
for d in 34 38 42 46; do shot "$A" anchae_d${d} "--time=11 --dist=$d --yaw=-20 --pitch=22 --fov=30"; done
