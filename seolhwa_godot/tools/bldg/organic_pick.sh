#!/bin/bash
# 고을 짜임 씨앗 고르기: 구역을 씨앗 여럿으로 지어 실측 지표(settle_metrics)를 모두 통과하는 첫 씨앗을 고른다.
#   tools/bldg/organic_pick.sh <west|eup> <첫 씨앗> <개수>   → 고른 씨앗을 tools/bldg/organic.gd DISTRICTS에 적고 그 결과를 남긴다
cd "$(dirname "$0")/../.."
G=${GODOT:-/opt/homebrew/bin/godot}
D=$1; S0=$2; N=${3:-10}
PRE=$( [ "$D" = west ] && echo orgw || echo orge )
best=""; bestf=99
for i in $(seq 0 $((N-1))); do
  sd=$((S0+i))
  sed -i '' "s/seed = [0-9]*, prefix = \"$PRE\"/seed = $sd, prefix = \"$PRE\"/" tools/bldg/organic.gd
  timeout 200 $G --headless --path . -s res://tools/bldg/organic.gd -- --district=$D > /tmp/town_logs/pick_gen.log 2>&1
  r=$(timeout 300 $G --headless --path . -s res://tools/bldg/settle_metrics.gd -- --district=$D 2>&1 | grep -E "^METRICS $D pass")
  f=$(echo "$r" | sed -E 's/.*fail=([0-9]+).*/\1/')
  echo "$sd $r"
  if [ "$f" -lt "$bestf" ]; then bestf=$f; best=$sd; fi
  [ "$f" = 0 ] && break
done
sed -i '' "s/seed = [0-9]*, prefix = \"$PRE\"/seed = $best, prefix = \"$PRE\"/" tools/bldg/organic.gd
timeout 200 $G --headless --path . -s res://tools/bldg/organic.gd -- --district=$D > /tmp/town_logs/pick_gen.log 2>&1
echo "PICK $D seed=$best fail=$bestf"
