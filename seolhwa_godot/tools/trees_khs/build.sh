#!/bin/bash
# trees-khs 나무 자산 다시 짓기 — 원본이 있어야 한다:
#   assets/trees/khs_gomsol/src/ ← /Users/sinjaeho/Documents/works/khs_assets/godot_ready/trees/ (국가유산청 곰솔, 공공누리 1유형)
#   assets/trees/src_cc0/LeafSet016, Bark012 ← ambientCG 2K(CC0) — manifest.json 참고
# 창이 필요하다(헤드리스는 텍스처·렌더 자료를 남기지 않는다). 셰이더 색 보정 값은 assets/trees/*.tres에 있다 — 고친 뒤 bake부터 다시.
set -e
cd "$(dirname "$0")/../.."
PY=${PY:-/Users/sinjaeho/miniconda3/bin/python3}; GODOT=${GODOT:-/opt/homebrew/bin/godot}
$PY -I tools/trees_khs/prep_textures.py leaf
$PY -I tools/trees_khs/prep_textures.py oak
$PY -I tools/trees_khs/prep_textures.py broad2
$GODOT --path . -s res://tools/trees_khs/build.gd -- --stage=tex,mesh,bake
$PY -I tools/trees_khs/prep_textures.py imp
$GODOT --path . -s res://tools/trees_khs/build.gd -- --stage=pack
