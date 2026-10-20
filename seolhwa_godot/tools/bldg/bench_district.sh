#!/bin/bash
# 세계 반영 구역 성능: 남원 서문 밖 구역 — 마을 카메라(22°·14.1m)·기본 카메라(40°·22m) 제자리 + 마을 카메라로 걸어 지나감. 1080p(--scale=1), 키트 캐시 더움(앞에서 한 번 돌린 뒤)
#   tools/bldg/bench_district.sh <log> [x,z]   (게임 인자는 '--' 뒤 · 시험 저장)
cd "$(dirname "$0")/../.."
GODOT=${GODOT:-/opt/homebrew/bin/godot}
LOG=${1:-/dev/stdout}
P=${2:--3341,272}
R=(--path . res://scenes/region.tscn --resolution 1920x1080 -- --region=JL_NAMWON_UNBONG --savefile=user://st_bldbench.json --nostory --notitle --time=11 --weather=clear --scale=1 --bench=20 --kitcache=${KITCACHE:-/tmp/seolhwa_bldg_kit_cache/})
run() { echo "== $*" >> "$LOG"; timeout 300 $GODOT "${R[@]}" "$@" 2>&1 | grep -E "^BENCH avg|^PLACEMENT" >> "$LOG"; }
run --warp=$P --cam=14.1,22,30 --benchspeed=0
run --warp=$P --cam=14.1,22,30 --benchspeed=0
run --warp=$P --cam=22,40,30 --benchspeed=0
run --warp=-3341,245 --cam=14.1,22,30 --benchspeed=2.2
