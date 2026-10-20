#!/bin/bash
# 초가 지붕 전후 낱장(kit_preview): tools/bldg/thatch_shots.sh <tag>  → shots/building_rollout/thatch/raw/<이름>_<tag>.png
cd "$(dirname "$0")/../.."
GODOT=${GODOT:-/opt/homebrew/bin/godot}
R=shots/building_rollout/thatch/raw; T=${1:-after}
shot(){ timeout 60 $GODOT --path . res://scenes/kit_preview.tscn -- --kit=${7:-res://kit/bldg/building.gd} --params="$1" --dist=$2 --yaw=$3 --pitch=$4 --shot=$R/${5}_$T.png --w=1200 --h=800 --nofog --time=11 $6 2>&1 | grep -E 'PREVIEW' | sed 's/.*tris=/tris=/;s/^/'$5' /'; }
for s in 1 2 3 4 5 6; do shot '{"type":"choga","region":"south","seed":'$s'}' 14 -20 22 s$s ""; done
shot '{"type":"choga","region":"central","seed":1}' 15 -20 22 c1 ""
shot '{"type":"choga","region":"north","seed":1}' 15 -20 22 n1 ""
shot '{"type":"jumak","region":"south","seed":1}' 17 -20 22 jumak1 ""
shot '{"type":"choga","region":"jeju","seed":1}' 14 -20 22 j1 ""
for s in 1 4; do shot '{"type":"choga","region":"south","seed":'$s'}' 5 25 4 eave$s "--center=2.4,2.2,1.6"; done
shot '{"type":"choga","region":"south","seed":2}' 30 -30 40 std2 ""
