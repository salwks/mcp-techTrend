#!/bin/bash
# 건물 빌더 세계 반영: tools/bldg/rollout.sh <구역> [--revert]
cd "$(dirname "$0")/../.."
GODOT=${GODOT:-/opt/homebrew/bin/godot}
D=${1:-west}; shift
$GODOT --headless --path . -s res://tools/bldg/rollout.gd -- --district=$D "$@" 2>&1 | grep -E "^ROLLOUT|ERROR|SCRIPT"
/opt/homebrew/bin/python3 tools/bldg/rollout_apply.py $D
