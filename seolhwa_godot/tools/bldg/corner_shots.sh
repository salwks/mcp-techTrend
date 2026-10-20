#!/bin/bash
# 모서리 가까이 전후 낱장: tools/bldg/corner_shots.sh <before|after> → shots/building_rollout/corners/raw/
cd "$(dirname "$0")/../.."
R=shots/building_rollout/corners/raw; T=$1
shot(){ timeout 60 godot --path . res://scenes/kit_preview.tscn -- --kit=${8:-res://kit/bldg/building.gd} --params="$1" --center=$2 --dist=$3 --yaw=$4 --pitch=$5 --shot=$R/${6}_$T.png --w=1200 --h=900 --nofog --time=13 $7 2>&1 | grep -E 'PREVIEW' | head -1; }
shot '{"type":"choga","region":"central","seed":1}' -3.3,0.45,-1.25 2.6 200 8 c1_choga_c1_junction ""
shot '{"type":"anchae","region":"central","seed":1}' -5.66,0.7,-1.47 3.0 200 8 c2_anchae_c1_junction ""
shot '{"type":"anchae","region":"north","seed":2}' -5.3,0.7,-1.47 3.0 200 8 c3_anchae_n2_junction ""
shot '{"type":"choga","region":"south","seed":1}' 3.385,0.6,1.31 2.6 45 10 c4_choga_s1_frontR ""
shot '{"type":"choga","region":"south","seed":1}' -3.385,0.6,-1.31 2.6 225 10 c5_choga_s1_backL ""
shot '{"type":"gotgan","region":"south","seed":1}' 2.32,0.6,1.2 2.6 45 10 c6_gotgan_frontR ""
shot '{"type":"choga","region":"jeju","seed":1}' 3.68,0.8,-1.49 2.8 135 10 c7_choga_j1_backR ""
shot '{"type":"giwajip","region":"south","seed":2}' 4.52,0.9,-1.22 2.8 135 10 c8_giwajip_backR ""
shot '{"type":"choga","region":"south","seed":1,"interior":true}' 3.2,1.0,-1.1 1.8 -45 12 c9_choga_s1_inside "--hide=roof,front"
shot '{"type":"anchae","region":"south","seed":2,"interior":true}' 0,1.4,-1.3 2.4 -30 14 c10_anchae_s2_inside "--hide=roof,front"
shot '{"type":"giwa_house","region":"south","seed":1064,"lot":[14.8,14.0]}' 6.9,0.8,-6.5 3.0 135 12 c11_giwahouse_wallcorner "" res://kit/bldg/compound.gd
shot '{"type":"giwa_house","region":"south","seed":1064,"lot":[14.8,14.0]}' 0.23,0.8,6.5 3.0 30 10 c12_giwahouse_gatejoin "" res://kit/bldg/compound.gd
