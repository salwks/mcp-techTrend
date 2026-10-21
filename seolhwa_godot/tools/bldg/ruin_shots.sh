#!/bin/bash
# 폐가 단계 낱장(kit_preview): tools/bldg/ruin_shots.sh → shots/building_rollout/ruin/raw/<유형>_s<단계>_{town,fp}.png
cd "$(dirname "$0")/../.."
GODOT=${GODOT:-/opt/homebrew/bin/godot}
R=shots/building_rollout/ruin/raw
shot(){ timeout 90 $GODOT --path . res://scenes/kit_preview.tscn -- --kit=$1 --params="$2" --dist=$3 --yaw=$4 --pitch=$5 --shot=$R/$6.png --w=1200 --h=800 --nofog --time=11 $7 2>&1 | grep -E 'PREVIEW' | sed 's/.*tris=/tris=/;s/^/'$6' /'; }
for st in 0 1 2 3 4; do
	shot res://kit/bldg/building.gd '{"type":"choga","region":"south","seed":2,"over":{"ruin":{"stage":'$st',"seed":3}}}' 15 -20 22 choga_s${st}_town ""
	shot res://kit/bldg/building.gd '{"type":"anchae","region":"central","seed":1,"over":{"ruin":{"stage":'$st',"seed":5}}}' 22 -25 22 anchae_s${st}_town ""
	shot res://kit/bldg/building.gd '{"type":"gotgan","region":"south","seed":1,"over":{"ruin":{"stage":'$st',"seed":2}}}' 11 -20 22 gotgan_s${st}_town ""
	shot res://kit/bldg/compound.gd '{"type":"choga_house","region":"south","seed":1113,"ruin":{"stage":'$st',"seed":4}}' 26 -15 32 chogahouse_s${st}_town ""
	shot res://kit/bldg/compound.gd '{"type":"giwa_house","region":"south","seed":1064,"lot":[14.8,14.0],"ruin":{"stage":'$st',"seed":6}}' 26 -15 32 giwahouse_s${st}_town ""
	shot res://kit/bldg/building.gd '{"type":"choga","region":"south","seed":2,"over":{"ruin":{"stage":'$st',"seed":3}}}' 6 15 6 choga_s${st}_close ""
done
