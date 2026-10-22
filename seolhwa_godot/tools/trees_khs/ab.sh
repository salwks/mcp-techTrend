#!/bin/bash
# trees-khs 번갈아 견주기(다른 Godot이 도는 중에도 상대 비교가 되게): tools/trees_khs/ab.sh <A seolhwa_godot> <B seolhwa_godot> <log> [회수]
#   장면: 소나무 숲 1인칭(-729,-660.5) · 여원재 골짜기 위 · 대로 오르막 걷기 — 1080p 높음, 맑음 11시, 시험 저장
A=${1:?A}; B=${2:?B}; LOG=${3:?log}; N=${4:-2}; KC=${KC:-/tmp/seolhwa_trees_kit_cache/}; GODOT=${GODOT:-/opt/homebrew/bin/godot}
# 다른 Godot(다른 에이전트)이 돌면 끝날 때까지(최대 WAITMAX초) 기다렸다가 잰다 — 기록에 그때 수를 남긴다
one() { local root=$1 tag=$2; shift 2; local w=0
  while [ $(pgrep -f 'bin/godot --path' | wc -l) -gt 0 ] && [ $w -lt ${WAITMAX:-900} ]; do sleep 5; w=$((w+5)); done
  local o=$(pgrep -f 'bin/godot --path' | wc -l | tr -d ' ')
  local r=$(cd "$root" && timeout 400 $GODOT --path . res://scenes/region.tscn --resolution 1920x1080 -- --region=JL_NAMWON_UNBONG --savefile=user://trees_bench.json --nostory --notitle --time=11 --weather=clear --scale=1 --kitcache=$KC "$@" 2>&1 | grep -E "^BENCH avg" | cut -c1-80)
  echo "$tag other=$o $* :: $r" >> "$LOG"; }
for i in $(seq 1 $N); do
  for S in "--warp=-729,-660.5 --view=first --fpyaw=50,14 --bench=15 --benchspeed=0" "--warp=-166,-917 --bench=15 --benchspeed=0" "--benchroute=tongyeong_byeolro:-1010,-1010,140,-540 --bench=25 --benchspeed=2.2"; do
    one "$A" A $S; one "$B" B $S
  done
done
