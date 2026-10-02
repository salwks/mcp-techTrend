#!/usr/bin/env bash
# 화면이 있는 것처럼 Godot을 실행한다(Xvfb + lavapipe Vulkan, Forward+).
# 사용: tools/run.sh [godot 인자...] -- [게임 인자: --shot=out.png --frames=60 --warp=x,z --time=14 --quit]
set -euo pipefail
cd "$(dirname "$0")/.."
export VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json
exec timeout "${RUN_TIMEOUT:-300}" xvfb-run -a -s "-screen 0 1600x900x24" godot --path . --rendering-driver vulkan --audio-driver Dummy "$@"
