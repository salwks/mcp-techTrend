#!/bin/bash
# 실측 지표 보고 한꺼번에: 남원 west·eup + 견본 8곳(구역마다) → /tmp/town_logs/metrics_<이름>.txt, 요약 한 줄씩
#   tools/bldg/metrics_all.sh [견본…]   (헤드리스 · 생성은 따로)
cd "$(dirname "$0")/../.."
G=${GODOT:-/opt/homebrew/bin/godot}
OUT=${OUT:-/tmp/town_logs}
mkdir -p $OUT
run() { timeout 400 $G --headless --path . -s res://tools/bldg/settle_metrics.gd -- "$@" 2>&1 | grep -E "^METRIC" ; }
for d in eup west; do run --district=$d > $OUT/metrics_$d.txt; echo "$(tail -1 $OUT/metrics_$d.txt)"; done
EX=${*:-metro city town town_open minchon yeokchon banchon sanchon}
for n in $EX; do
  f=shots/town_organic/_place_$n/placement_settle_$n.json
  for did in $(/opt/homebrew/bin/python3 -c "import json;print(' '.join(x['id'] for x in json.load(open('$f'))['districts']))"); do
    tv=""
    case "$n:$did" in banchon:upper) tv="--tier_village=banchon";; minchon:*|yeokchon:*|sanchon:*|banchon:*) tv="--tier_village=minchon";; esac
    run --settle=$n --dist=$did $tv > $OUT/metrics_${n}_$did.txt
    echo "$(tail -1 $OUT/metrics_${n}_$did.txt)"
  done
done
