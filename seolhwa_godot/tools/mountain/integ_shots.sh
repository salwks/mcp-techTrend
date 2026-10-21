#!/bin/bash
# integ-mountain 전·후 낱장: tools/mountain/integ_shots.sh <작업 트리의 seolhwa_godot> <tag> [set…]
#   → <이 작업 트리>/shots/integ_mountain/raw/<set>_<id>_<tag>.png (1920×1080, 맑음 11시, 시험 저장)
ROOT=${1:?seolhwa_godot path}; TAG=${2:?tag}; shift 2
SETS=${*:-cam mtn}
OUT=$(cd "$(dirname "$0")/../.." && pwd)/shots/integ_mountain/raw
VIEWS=$(cd "$(dirname "$0")" && pwd)/integ_views.json
mkdir -p "$OUT"; cd "$ROOT"
for S in $SETS; do
  timeout 1200 ${GODOT:-/opt/homebrew/bin/godot} --path . res://scenes/region.tscn --resolution 1920x1080 -- --scale=1 --region=JL_NAMWON_UNBONG \
    --bldgrollout="$VIEWS" --brset=$S --brtag=$TAG --brout="$OUT" --savefile=user://integ_test.json --kitcache=${KC:-/tmp/seolhwa_integ_kit_cache/} \
    --nostory --notitle --time=11 --weather=clear --nodof $EXTRA 2>&1 | grep -E "BRSHOT|SCRIPT ERROR"
done
