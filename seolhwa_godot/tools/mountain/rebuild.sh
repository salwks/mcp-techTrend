#!/bin/bash
# 산 지형 다시 만들기: 원본(cache/base, 없으면 git 1da7b59) → region_data/JL_NAMWON_UNBONG (height·landuse·region·mountain·배치 y) → 필지 → 지도 → 말길
set -e
cd "$(dirname "$0")/../.."
PY=${PY:-/Users/sinjaeho/miniconda3/bin/python3}
$PY tools/mountain/build_mountain.py
$PY tools/mountain/fix_pass_ford.py   # integ-mountain: 대로 골물 여울 → 고른 노면 + 돌다리 2
$PY tools/region/parcels.py JL_NAMWON_UNBONG
$PY tools/region/render_joseon_map.py JL_NAMWON_UNBONG
$PY tools/region/make_travel_gates.py JL_NAMWON_UNBONG
