#!/bin/bash
# 도시·마을 빌더 견본: 다시 짓기 → 견본마다 점검(시점 찍기·걷기·대문) — tools/bldg/settle_pipeline.sh [견본…]
#   게임 인자는 '--' 뒤 · 시험 저장(user://town_test_<견본>.json) · 키트 캐시 /tmp/seolhwa_town_kit_cache/
cd "$(dirname "$0")/../.."
G=${GODOT:-/opt/homebrew/bin/godot}
EX=${*:-metro city town town_open minchon yeokchon banchon sanchon}
ONLY=$(echo $EX | tr ' ' ',')
[ -z "$NOGEN" ] && timeout 3600 $G --headless --path . -s res://tools/bldg/settlement_place.gd -- --only=$ONLY > /tmp/town_logs/settle_pipe_gen.log 2>&1
for n in $EX; do
  timeout 3000 $G --path . res://scenes/region.tscn --resolution 1920x1080 -- --region=JL_NAMWON_UNBONG --placedir=res://shots/town_organic/_place_$n/ \
    --bldgrollout=res://tools/bldg/town_views.json --brset=$n --brtag=after --brout=shots/town_organic/raw --savefile=user://town_test_$n.json \
    --kitcache=${KITCACHE:-/tmp/seolhwa_town_kit_cache/} --nostory --notitle --time=11 --weather=clear --nodof > /tmp/town_logs/br_$n.log 2>&1
  echo "$n $(grep -E 'BRPASS' /tmp/town_logs/br_$n.log | tail -1)" >> /tmp/town_logs/settle_pipe.txt
done
echo DONE >> /tmp/town_logs/settle_pipe.txt
