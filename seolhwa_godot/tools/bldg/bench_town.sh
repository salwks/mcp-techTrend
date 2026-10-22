#!/bin/bash
# 고을 짜임 성능(town-organic): 서문 밖·읍성 안 남쪽 — 마을 카메라(22°·14.1m)·기본 카메라(40°·22m) 제자리 + 마을 카메라로 걸어 지나감.
#   1920×1080 --scale=1, 맑음 11시, --nostory, 20초. 각 자리 첫 실행은 키트 캐시 데우기(버림), 둘째가 더운 값.
#   tools/bldg/bench_town.sh <log> [프로젝트 경로(전 비교: 다른 작업 트리)]   (게임 인자는 '--' 뒤 · 시험 저장)
LOG=${1:-/dev/stdout}
cd "${2:-$(dirname "$0")/../..}"
GODOT=${GODOT:-/opt/homebrew/bin/godot}
R=(--path . res://scenes/region.tscn --resolution 1920x1080 -- --region=JL_NAMWON_UNBONG --savefile=user://st_townbench.json --nostory --notitle --time=11 --weather=clear --scale=1 --bench=20 --kitcache=${KITCACHE:-/tmp/seolhwa_town_kit_cache/})
run() { echo "== $*" >> "$LOG"; timeout 300 $GODOT "${R[@]}" "$@" 2>&1 | grep -E "^BENCH avg|^PLACEMENT" >> "$LOG"; }
echo "# $(date) $(pwd) godot=$(pgrep -fl godot | grep -c region.tscn) other region.tscn running" >> "$LOG"
run --warp=-3365,282 --cam=14.1,22,30 --benchspeed=0
run --warp=-3365,282 --cam=14.1,22,30 --benchspeed=0
run --warp=-3365,282 --cam=22,40,30 --benchspeed=0
run --warp=-3341,300 --cam=14.1,22,30 --benchspeed=2.2
run --warp=-3228,295 --cam=14.1,22,30 --benchspeed=0
run --warp=-3228,295 --cam=14.1,22,30 --benchspeed=0
run --warp=-3228,320 --cam=14.1,22,30 --benchspeed=2.2
