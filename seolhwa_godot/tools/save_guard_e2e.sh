#!/bin/zsh
# 저장 지킴 끝까지 시험 — 실제 게임 실행 여러 가지('--' 빠뜨림 포함)를 돌리고, 사용자 저장 폴더의 저장 파일 내용·수정 시각이 그대로인지 본다.
#   tools/save_guard_e2e.sh   (사용자가 켜 둔 게임이 있으면 그 게임의 자동 저장 때문에 바뀔 수 있다 — 게임을 닫고 돌린다)
#   끝 줄: SAVEGUARDE2E PASS n / SAVEGUARDE2E FAIL n
GODOT=${GODOT:-/opt/homebrew/bin/godot}
ROOT=${0:A:h:h}
REAL="$HOME/Library/Application Support/Godot/app_userdata/설화록"
SB="${REAL}_test"
mkdir -p "$SB/logs"
snap() { (cd "$REAL" && find . -maxdepth 1 -type f \( -name '*.json' -o -name '*.png' \) -exec stat -f '%N %m %z' {} \; -exec shasum -a 256 {} \; | sort) }
before=$(snap)
n=0; fails=0
run() {   # 이름 기대(blocked|ok) 인자…
	local name=$1 want=$2; shift 2
	n=$((n+1))
	timeout 60 $GODOT "$@" > "$SB/logs/e2e_$name.out" 2>&1
	local code=$?
	if [[ $want == blocked ]]; then
		if [[ $code == 3 ]] && grep -q "SAVEGUARD 실행 중단" "$SB/logs/e2e_$name.out"; then echo "  ok   $name → 실행 중단(종료 3)"
		else echo "  FAIL $name → 종료 $code (중단돼야 함)"; fails=$((fails+1)); fi
	else
		if grep -q "SAVEGUARD sandbox" "$SB/logs/e2e_$name.out"; then echo "  ok   $name → 모래상자"
		else echo "  FAIL $name → 모래상자 표시 없음(종료 $code)"; fails=$((fails+1)); fi
	fi
}
cd $ROOT
run nodash_titlecap blocked --path . --resolution 640x360 --savefile=user://st_e2e.json --titletest=new --storylog
run nodash_title    blocked --path . --resolution 640x360 --titletest=new
run nodash_headless blocked --headless --path . --storytest=namwon:observe
run nodash_nostory  blocked --path . --resolution 640x360 --nostory --mapshots=/tmp/x
run dash_headless   ok      --headless --path . --quit-after 600 -- --nostory
run dash_title      ok      --path . --resolution 640x360 --quit-after 900 -- --savefile=user://st_e2e.json --titletest=new --storylog
after=$(snap)
n=$((n+1))
if [[ "$before" == "$after" ]]; then echo "  ok   사용자 저장 폴더 저장 파일 $(echo $before | wc -l | tr -d ' ')개 — 내용(sha256)·크기·수정 시각 그대로"
else echo "  FAIL 사용자 저장 폴더가 바뀜:"; diff <(echo $before) <(echo $after); fails=$((fails+1)); fi
rm -f "$SB"/st_e2e*.json "$SB"/st_e2e*.png
echo "SAVEGUARDE2E $([[ $fails == 0 ]] && echo PASS $n || echo FAIL $fails)"
