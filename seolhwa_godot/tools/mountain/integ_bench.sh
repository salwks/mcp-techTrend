#!/bin/bash
# integ-mountain 성능: 고을(남원 장터 마을 구도) · 산(여원재 골짜기 위 — 들·산 구도) · 산 걷기(대로 오르막) · 1인칭 능선 봉우리
#   × 1080p/1440p × 화면 품질 높음/낮음. 맑음 11시, --nostory, 20초(걷기 30초), 시험 저장. 첫 줄은 덥히기.
#   tools/mountain/integ_bench.sh <seolhwa_godot 경로> <log>
ROOT=${1:?path}; LOG=${2:-/dev/stdout}; KC=${KC:-/tmp/seolhwa_integ_kit_cache/}
cd "$ROOT"; GODOT=${GODOT:-/opt/homebrew/bin/godot}
run() { local res=$1; shift; echo "== $res $*" >> "$LOG"; echo "   other_godot=$(( $(pgrep -f 'godot' | wc -l) ))" >> "$LOG"
  timeout 400 $GODOT --path . res://scenes/region.tscn --resolution $res -- --region=JL_NAMWON_UNBONG --savefile=user://integ_bench.json --nostory --notitle --time=11 --weather=clear --scale=1 --kitcache=$KC "$@" 2>&1 | grep -E "^BENCH avg" >> "$LOG"; }
run 1920x1080 --warp=-3341,272 --bench=15 --benchspeed=0
for R in 1920x1080 2560x1440; do for Q in high low; do
  run $R --gfx=$Q --warp=-3341,272 --bench=20 --benchspeed=0
  run $R --gfx=$Q --warp=-166,-917 --bench=20 --benchspeed=0
  run $R --gfx=$Q --benchroute=tongyeong_byeolro:-1010,-1010,140,-540 --bench=30 --benchspeed=2.2
  run $R --gfx=$Q --warp=-326,-1134 --view=first --fpyaw=150,0 --bench=20 --benchspeed=0
done; done
