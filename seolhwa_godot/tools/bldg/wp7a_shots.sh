#!/bin/bash
# WP7a 보정 전후 낱장(kit_preview, 창 필요): tools/bldg/wp7a_shots.sh <tag>  → shots/wp7a/raw/<이름>_<tag>.png
#   기준 각(거리 14~17, 22°)과 문 앞 1인칭(눈높이 ≈1.6m, 화각 60°, 걸어 들어가는 집 interior=true)
#   게임 인자는 '--' 뒤에만(저장 안전). kit_preview는 저장을 읽거나 쓰지 않지만 시험 저장 경로를 같이 넘긴다.
cd "$(dirname "$0")/../.."
GODOT=${GODOT:-/opt/homebrew/bin/godot}
R=shots/wp7a/raw; T=${1:-after}
mkdir -p $R
shot(){ timeout 90 $GODOT --path . res://scenes/kit_preview.tscn -- --savefile=user://wp7a_test.json --kit=res://kit/bldg/building.gd --params="$1" --shot=$R/${2}_$T.png --w=1200 --h=800 --nofog --time=11 $3 2>&1 | grep -E 'PREVIEW' | sed 's/.*tris=/tris=/;s/^/'$2' /'; }
REF="--dist=15 --yaw=-20 --pitch=22"
FP="--center=0,1.4,0 --dist=6.8 --yaw=8 --pitch=2 --fov=60 --fit=0"
for s in 1 2 3; do
  shot '{"type":"choga","region":"south","seed":'$s'}' choga_s${s}_ref "$REF"
  shot '{"type":"choga","region":"south","seed":'$s',"interior":true}' choga_s${s}_door "$FP"
done
shot '{"type":"choga","region":"central","seed":1}' choga_c1_ref "$REF"
shot '{"type":"choga","region":"central","seed":1,"interior":true}' choga_c1_door "$FP"
for rg in south central; do
  for s in 1 2; do
    shot '{"type":"anchae","region":"'$rg'","seed":'$s'}' anchae_${rg}${s}_ref "--dist=22 --yaw=-20 --pitch=22"
    shot '{"type":"anchae","region":"'$rg'","seed":'$s',"interior":true}' anchae_${rg}${s}_door "--center=0,1.6,0 --dist=8.5 --yaw=8 --pitch=3 --fov=60 --fit=0"
  done
  shot '{"type":"sarang","region":"'$rg'","seed":1}' sarang_${rg}1_ref "--dist=20 --yaw=-20 --pitch=22"
  shot '{"type":"sarang","region":"'$rg'","seed":1,"interior":true}' sarang_${rg}1_door "--center=0,1.6,0 --dist=8.5 --yaw=8 --pitch=3 --fov=60 --fit=0"
done
