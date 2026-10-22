#!/bin/bash
# 성능 풀이(perf pass): 장면 × 설정 벤치 — 1080p, 맑음 11시, --nostory, 더운 키트 캐시, 시험 저장. 줄마다 다른 Godot 수를 적는다.
#   tools/perf/perf_bench.sh <log> [장면…] [-- 더할 게임 인자]
#   장면: town(남원 장터 마을) · valley(여원재 골짜기 위 들·산 구도) · pass(여원재 대로 걷기 2.2m/s) · forestfp(숲 속 1인칭)
cd "$(dirname "$0")/../.."
LOG=${1:?log}; shift
SC=(); EX=()
while [ $# -gt 0 ]; do if [ "$1" = "--" ]; then shift; EX=("$@"); break; fi; SC+=("$1"); shift; done
[ ${#SC[@]} -eq 0 ] && SC=(town valley pass forestfp)
G=${GODOT:-/opt/homebrew/bin/godot}; KC=${KC:-/tmp/seolhwa_integ_kit_cache/}; T=${T:-15}
run() { local name=$1; shift
  local og=$(pgrep -f 'godot.*region.tscn' | wc -l | tr -d ' ')
  local out=$(timeout 400 $G --path . res://scenes/region.tscn --resolution ${RES:-1920x1080} -- --region=JL_NAMWON_UNBONG --savefile=user://perf_bench.json --nostory --notitle --time=11 --weather=clear --scale=1 --kitcache=$KC "$@" "${EX[@]}" 2>&1 | grep -E "^BENCH (avg|render)")
  local fps=$(echo "$out" | grep -oE "avg_fps=[0-9.]+" | cut -d= -f2); local p99=$(echo "$out" | grep -oE "p99_ms=[0-9.]+" | cut -d= -f2)
  local tris=$(echo "$out" | grep -oE "tris=[0-9]+k" | cut -d= -f2); local dr=$(echo "$out" | grep -oE "draws=[0-9]+" | cut -d= -f2); local sh=$(echo "$out" | grep -oE "shadow_draws=[0-9]+" | cut -d= -f2)
  echo "$name | ${EX[*]} | fps=$fps p99=$p99 tris=$tris draws=$dr shadow_draws=$sh other_godot=$og" | tee -a "$LOG"; }
for s in "${SC[@]}"; do case $s in
  town) run town --warp=-3341,272 --bench=$T --benchspeed=0;;
  valley) run valley --warp=-166,-917 --bench=$T --benchspeed=0;;
  pass) run pass --benchroute=tongyeong_byeolro:-1010,-1010,140,-540 --bench=$((T+10)) --benchspeed=2.2;;
  forestfp) run forestfp --warp=-240,-900 --view=first --fpyaw=200,0 --bench=$T --benchspeed=0;;
esac; done
