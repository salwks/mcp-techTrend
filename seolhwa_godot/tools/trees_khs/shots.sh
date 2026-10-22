#!/bin/bash
# trees-khs 전·후 낱장: tools/trees_khs/shots.sh <작업 트리의 seolhwa_godot> <tag> [set…]
#   → <이 작업 트리>/shots/trees_khs/raw/<set>_<id>_<tag>.png (1920×1080, 맑음 11시, 시험 저장 — 게임 인자는 반드시 -- 뒤)
ROOT=${1:?seolhwa_godot path}; TAG=${2:?tag}; shift 2
SETS=${*:-trees}
OUT=$(cd "$(dirname "$0")/../.." && pwd)/shots/trees_khs/raw
VIEWS=${VIEWS:-$(cd "$(dirname "$0")" && pwd)/views.json}
mkdir -p "$OUT"; cd "$ROOT"
for S in $SETS; do
  timeout 1500 ${GODOT:-/opt/homebrew/bin/godot} --path . res://scenes/region.tscn --resolution 1920x1080 -- --scale=1 --region=JL_NAMWON_UNBONG \
    --bldgrollout="$VIEWS" --brset=$S --brtag=$TAG --brout="$OUT" --savefile=user://trees_test.json --kitcache=${KC:-/tmp/seolhwa_trees_kit_cache/} \
    --nostory --notitle --time=11 --weather=clear --nodof $EXTRA 2>&1 | grep -E "BRSHOT|SCRIPT ERROR|ERROR"
done
