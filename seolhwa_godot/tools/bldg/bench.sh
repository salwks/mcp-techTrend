#!/bin/bash
# 건물 빌더 성능: 남원 권역에서 30채 마을 블록(있음/없음) — 1080p(--scale=1), 마을 카메라(22°·14.1m)·기본 카메라, 제자리·걷기
#   tools/bldg/bench.sh [log]
cd "$(dirname "$0")/../.."
GODOT=${GODOT:-/opt/homebrew/bin/godot}
LOG=${1:-/dev/stdout}
$GODOT --headless --path . -s res://tools/bldg/gallery_place.gd -- --set=block > /dev/null 2>&1
R=(--path . res://scenes/region.tscn --resolution 1920x1080 -- --region=JL_NAMWON_UNBONG --savefile=user://st_bldbench.json --nostory --notitle --time=11 --weather=clear --scale=1 --bench=20 --kitcache=${KITCACHE:-/tmp/seolhwa_bldg_kit_cache/})
B=--placedir=res://shots/building_builder/_place_block/
run() { echo "== $*" >> "$LOG"; timeout 300 $GODOT "${R[@]}" "$@" 2>&1 | grep -E "^BENCH|^PLACEMENT|KITMISS" | grep -v "weather" >> "$LOG"; }
run --warp=-3488,532 --cam=14.1,22,30 --benchspeed=0
run $B --warp=-3488,532 --cam=14.1,22,30 --benchspeed=0
run $B --warp=-3488,532 --benchspeed=0
run $B --warp=-3488,590 --cam=14.1,22,30 --benchspeed=2.2
run --warp=-3290,393 --cam=14.1,22,30 --benchspeed=0
