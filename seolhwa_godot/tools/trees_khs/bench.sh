#!/bin/bash
# trees-khs 성능: 고을(남원 장터) · 산골(여원재 골짜기 위 들·산 구도) · 재 대로 오르막 걷기 × 1080p 높음/낮음. 맑음 11시, --nostory, 시험 저장.
#   tools/trees_khs/bench.sh <seolhwa_godot 경로> <log> [추가 게임 인자…]   — 줄마다 다른 Godot 수(other_godot)를 적는다
ROOT=${1:?path}; LOG=${2:-/dev/stdout}; shift 2; XA="$*"; KC=${KC:-/tmp/seolhwa_trees_kit_cache/}
cd "$ROOT"; GODOT=${GODOT:-/opt/homebrew/bin/godot}
run() { local res=$1; shift; echo "== $res $* $XA" >> "$LOG"; echo "   other_godot=$(pgrep -f 'bin/godot' | wc -l | tr -d ' ')" >> "$LOG"
  timeout 400 $GODOT --path . res://scenes/region.tscn --resolution $res -- --region=JL_NAMWON_UNBONG --savefile=user://trees_bench.json --nostory --notitle --time=11 --weather=clear --scale=1 --kitcache=$KC "$@" $XA 2>&1 | grep -E "^BENCH avg" >> "$LOG"; }
run 1920x1080 --warp=-3341,272 --bench=10 --benchspeed=0
for Q in high low; do
  run 1920x1080 --gfx=$Q --warp=-3341,272 --bench=20 --benchspeed=0
  run 1920x1080 --gfx=$Q --warp=-166,-917 --bench=20 --benchspeed=0
  run 1920x1080 --gfx=$Q --benchroute=tongyeong_byeolro:-1010,-1010,140,-540 --bench=30 --benchspeed=2.2
done
