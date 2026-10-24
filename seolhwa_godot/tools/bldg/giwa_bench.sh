#!/bin/bash
# 기와 줄 성능(giwa-geometry): bench_town.sh와 같은 자리·카메라(1920×1080 --scale=1, 맑음 11시, 20초) + 추가 게임 인자(EXTRA).
#   tools/bldg/giwa_bench.sh <log> [프로젝트 경로(전: 다른 작업 트리)]   예) EXTRA=--giwarows=0 tools/bldg/giwa_bench.sh /tmp/x.log
#   BLOCK=1: 기와집 30채 구역(먼저 godot --headless --path . -s res://tools/bldg/gallery_place.gd -- --set=giwablock)
#   각 자리 첫 실행은 키트 캐시 데우기(버림). 게임 인자는 '--' 뒤 · 시험 저장(--savefile=user://giwa_test.json)만.
LOG=${1:-/dev/stdout}
cd "${2:-$(dirname "$0")/../..}"
GODOT=${GODOT:-/opt/homebrew/bin/godot}
R=(--path . res://scenes/region.tscn --resolution 1920x1080 -- --region=JL_NAMWON_UNBONG --savefile=user://giwa_test.json --nostory --notitle --time=11 --weather=clear --scale=1 --bench=20 --kitcache=${KITCACHE:-/tmp/seolhwa_giwa_kit_cache/} $EXTRA)
run() { echo "== $*" >> "$LOG"; timeout 300 $GODOT "${R[@]}" "$@" 2>&1 | grep -E "^BENCH (avg|render|giwa)|^PLACEMENT" >> "$LOG"; }
if [ -n "$BLOCK" ]; then
  # 기와집 30채 구역(gallery_place.gd --set=giwablock, 읍성 서쪽 풀밭) — 기와 줄 최악 견줌
  B=--placedir=res://shots/building_builder/_place_giwablock/
  echo "# BLOCK $(date) $(pwd) EXTRA=$EXTRA other_godot=$(pgrep -f 'region.tscn|kit_preview|tools/bldg' | wc -l)" >> "$LOG"
  run $B --warp=-3488,532 --cam=14.1,22,30 --benchspeed=0
  run $B --warp=-3488,532 --cam=14.1,22,30 --benchspeed=0
  run $B --warp=-3488,532 --benchspeed=0
  run $B --warp=-3488,590 --cam=14.1,22,30 --benchspeed=2.2
  exit 0
fi
echo "# $(date) $(pwd) EXTRA=$EXTRA other_godot=$(pgrep -f 'region.tscn|kit_preview|tools/bldg' | wc -l)" >> "$LOG"
run --warp=-3228,295 --cam=14.1,22,30 --benchspeed=0
run --warp=-3228,295 --cam=14.1,22,30 --benchspeed=0
run --warp=-3228,295 --cam=22,40,30 --benchspeed=0
run --warp=-3228,320 --cam=14.1,22,30 --benchspeed=2.2
run --warp=-3365,282 --cam=14.1,22,30 --benchspeed=0
run --warp=-3365,282 --cam=14.1,22,30 --benchspeed=0
run --warp=-3341,300 --cam=14.1,22,30 --benchspeed=2.2
