#!/bin/zsh
# 건물 빌더 갤러리: 배치 만들기 → 남원 권역에서 찍기 → 묶음 그림(shots/building_builder/*.jpg)
#   tools/bldg/gallery.sh [추가 게임 인자…]   예) tools/bldg/gallery.sh --bgonly=bg_choga_s1 --bgnosheet
# 게임 인자는 반드시 '--' 뒤(save_guard) · 시험 저장(--savefile)으로만.
set -e
cd "$(dirname "$0")/../.."
GODOT=${GODOT:-/opt/homebrew/bin/godot}
$GODOT --headless --path . -s res://tools/bldg/parse_check.gd || exit 1
$GODOT --headless --path . -s res://tools/bldg/gallery_place.gd -- --set=gallery
$GODOT --path . res://scenes/region.tscn --resolution 1920x1080 -- --region=JL_NAMWON_UNBONG \
  --placedir=res://shots/building_builder/_place_gallery/ --bldgallery=shots/building_builder \
  --savefile=user://st_bldgallery.json --kitcache=${KITCACHE:-/tmp/seolhwa_bldg_kit_cache/} --nostory --notitle --time=11 --weather=clear --nodof "$@"
