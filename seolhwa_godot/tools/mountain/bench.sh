#!/bin/bash
# 산 지형 성능(전·후 견주기): 고을(남원 서문 밖 장터길) 마을 카메라·기본 카메라·걷기 + 여원재(골짜기 위 길) 게임 카메라 + 1인칭 먼 산 보기.
#   tools/mountain/bench.sh <작업 트리의 seolhwa_godot> <log> [kitcache]
#   1920×1080(--scale=1), 맑음 11시, --nostory, 20초, 시험 저장. 같은 키트 캐시로 한 번 덥힌 뒤 잰다(첫 줄은 덥히기).
ROOT=${1:?seolhwa_godot path}; LOG=${2:-/dev/stdout}; KC=${3:-/tmp/seolhwa_mtn_kit_cache/}
cd "$ROOT"
GODOT=${GODOT:-/opt/homebrew/bin/godot}
R=(--path . res://scenes/region.tscn --resolution 1920x1080 -- --region=JL_NAMWON_UNBONG --savefile=user://mtn_bench.json --nostory --notitle --time=11 --weather=clear --scale=1 --bench=20 --kitcache=$KC)
run() { echo "== $*" >> "$LOG"; echo "   other_godot=$(pgrep -f 'godot --path' | wc -l | tr -d ' ')" >> "$LOG"; timeout 400 $GODOT "${R[@]}" "$@" 2>&1 | grep -E "^BENCH avg" >> "$LOG"; }
run --warp=-3341,272 --cam=14.1,22,30 --benchspeed=0      # 덥히기
run --warp=-3341,272 --cam=14.1,22,30 --benchspeed=0      # 마을 카메라 22° 제자리
run --warp=-3341,272 --cam=22,40,30 --benchspeed=0        # 기본 카메라 40°
run --warp=-3341,245 --cam=14.1,22,30 --benchspeed=2.2    # 마을 카메라로 걷기
run --warp=-166,-917 --benchspeed=0                       # 여원재 골짜기 위(게임 카메라)
run --warp=-166,-917 --benchspeed=2.2                     # 여원재 걷기(방향 무작위 — 막히면 돈다)
run --warp=14,-966 --view=first --fpyaw=-110,3 --benchspeed=0   # 재 마루 1인칭, 남원 쪽(먼 산)
run --warp=-3228,380 --view=first --fpyaw=-48,4 --benchspeed=0  # 남원 남문 밖 1인칭, 교룡산 쪽
