#!/bin/zsh
# 설화록 대본 시험 한 번에 돌리기(헤드리스) — PASS/FAIL 표와 종료 코드를 찍는다.
#
#   tools/run_story_tests.sh                 # 전부(대본 시험 + 노정 걷기), 동시 3개
#   tools/run_story_tests.sh -j 1            # 한 줄로
#   tools/run_story_tests.sh namwon hwangju:B walk   # 이름(앞부분)이 맞는 것만
#   tools/run_story_tests.sh -l              # 목록만
#
# 판정: 로그에 PASS 줄(STORYTEST/ONBOARDTEST PASS, 걷기는 WALK done + TRAVEL arrive)이 있고 종료 코드 0, SCRIPT ERROR 0.
# 시험마다 저장 파일을 따로 쓴다(--savefile=user://st_<이름>.json) — 동시에 돌려도 서로 덮어쓰지 않는다.
# 로그: $LOGDIR(기본 /tmp/seolhwa_tests/<시각>/<이름>.log). 환경 변수 GODOT, LOGDIR, TIMEOUT_SCALE(제한 시간 배율).

emulate -L zsh
setopt pipe_fail
ROOT=${0:A:h:h}
GODOT=${GODOT:-/opt/homebrew/bin/godot}
JOBS=3
LIST_ONLY=0
while [[ $# -gt 0 ]]; do
	case $1 in
		-j) JOBS=$2; shift 2;;
		-j*) JOBS=${1#-j}; shift;;
		-l) LIST_ONLY=1; shift;;
		-h|--help) sed -n '2,12p' $0; exit 0;;
		*) break;;
	esac
done
FILTERS=("$@")
LOGDIR=${LOGDIR:-/tmp/seolhwa_tests/$(date +%Y%m%d_%H%M%S)}
TSCALE=${TIMEOUT_SCALE:-1}

# 이름 | 제한(초) | 인자
TESTS=(
	"namwon:A|600|--storytest=namwon:A"
	"namwon:B|600|--storytest=namwon:B"
	"namwon:C|240|--storytest=namwon:C"
	"namwon:onboard|240|--storytest=namwon:onboard"
	"hanyang|300|--region=GG_HANYANG --storytest=hanyang"
	"hanyang:r01|240|--region=GG_HANYANG --storytest=hanyang:r01"
	"hanyang:act3|240|--region=GG_HANYANG --storytest=hanyang:act3"
	"gangneung:A|240|--region=GW_GANGNEUNG --storytest=gangneung:A"
	"gangneung:B|240|--region=GW_GANGNEUNG --storytest=gangneung:B"
	"gangneung:C|240|--region=GW_GANGNEUNG --storytest=gangneung:C"
	"gyeongju:A|240|--region=GS_GYEONGJU --storytest=gyeongju:A"
	"gyeongju:B|240|--region=GS_GYEONGJU --storytest=gyeongju:B"
	"hwangju:A|300|--region=HH_HWANGJU --storytest=hwangju:A"
	"hwangju:B|300|--region=HH_HWANGJU --storytest=hwangju:B"
	"hwangju:C|300|--region=HH_HWANGJU --storytest=hwangju:C"
	"pyongyang:A|300|--region=PA_PYEONGYANG --storytest=pyongyang:A"
	"pyongyang:B|300|--region=PA_PYEONGYANG --storytest=pyongyang:B"
	"pyongyang:C|300|--region=PA_PYEONGYANG --storytest=pyongyang:C"
	"hamhung:r05|240|--route=PA_PYEONGYANG-HG_HAMHEUNG --storytest=hamhung:R05"
	"hamhung:A|300|--region=HG_HAMHEUNG --storytest=hamhung:A"
	"hamhung:B|300|--region=HG_HAMHEUNG --storytest=hamhung:B"
	"hamhung:C|300|--region=HG_HAMHEUNG --storytest=hamhung:C"
	"walk:hwangju-pyeongyang|300|--route=HH_HWANGJU-PA_PYEONGYANG --walkroute=01 --walkspeed=12"
	"walk:hangang-boat|600|--route=RIVER_HANGANG --walkroute=01 --walkspeed=12 --sailspeed=25"
)

selected=()
for t in $TESTS; do
	name=${t%%|*}
	if (( ${#FILTERS} == 0 )); then selected+=$t; continue; fi
	for f in $FILTERS; do
		if [[ $name == ${f}* ]]; then selected+=$t; break; fi
	done
done
if (( LIST_ONLY )); then
	for t in $selected; do print -- "${t//|/   }"; done
	exit 0
fi
(( ${#selected} == 0 )) && { print "맞는 시험이 없다: $FILTERS"; exit 2; }
mkdir -p $LOGDIR
print "로그: $LOGDIR  (동시 $JOBS개, 시험 ${#selected}개)"

run_one() {
	local name=$1 limit=$2 spec=$3
	local safe=${name//[:\/]/_}
	local log=$LOGDIR/$safe.log
	local t0=$SECONDS
	# 시험마다 따로 저장(user://st_<이름>.json) — 남은 저장이 있으면 지운다(prepare가 새로 깐다)
	rm -f "$HOME/Library/Application Support/Godot/app_userdata/설화록/st_${safe}.json" 2>/dev/null
	timeout $(( limit * TSCALE )) $GODOT --headless --path $ROOT res://scenes/region.tscn -- ${=spec} --savefile=user://st_${safe}.json > $log 2>&1
	local code=$?
	local dt=$(( SECONDS - t0 ))
	local verdict=FAIL why=""
	local serr=$(grep -c "SCRIPT ERROR" $log)
	local rerr=$(grep -c -E "^ERROR: (Initializing already|Parameter \"(mem|multimesh|m)\" is null)" $log)
	if [[ $name == walk:* ]]; then
		grep -q "^WALK done" $log && grep -q "^TRAVEL arrive" $log && verdict=PASS
	else
		grep -q -E "^(STORYTEST|ONBOARDTEST) PASS" $log && verdict=PASS
	fi
	local detail=$(grep -E "^(STORYTEST|ONBOARDTEST) (PASS|FAIL)" $log | tail -1 | sed -E 's/^(STORYTEST|ONBOARDTEST) //')
	[[ $name == walk:* ]] && detail=$(grep "^WALK done" $log | tail -1 | sed -E 's/^WALK done //')
	if (( code == 124 )); then why="시간 초과"; verdict=FAIL
	elif (( code != 0 )); then why="종료 코드 $code"; verdict=FAIL
	fi
	(( serr > 0 )) && { why="$why SCRIPT ERROR $serr"; verdict=FAIL; }
	(( rerr > 0 )) && why="$why RID 오류 $rerr"
	grep -q "handle_crash" $log && why="$why crash"
	print -- "$name|$verdict|$code|$dt|$serr|${why# }|$detail" > $LOGDIR/$safe.res
}

pids=()
for t in $selected; do
	name=${t%%|*}; rest=${t#*|}; limit=${rest%%|*}; spec=${rest#*|}
	# 빈자리가 날 때까지 기다린다(살아 있는 pid 수 < JOBS)
	while true; do
		alive=()
		for p in $pids; do kill -0 $p 2>/dev/null && alive+=$p; done
		pids=($alive)
		(( ${#pids} < JOBS )) && break
		sleep 1
	done
	print "  시작 $name"
	run_one $name $limit $spec &
	pids+=$!
done
wait

print
printf "%-26s %-5s %5s %6s %4s  %s\n" "시험" "결과" "코드" "초" "SE" "비고 / 결과 줄"
printf -- "-%.0s" {1..100}; print
fail=0
for t in $selected; do
	name=${t%%|*}; safe=${name//[:\/]/_}
	res=$LOGDIR/$safe.res
	if [[ ! -f $res ]]; then printf "%-26s %-5s\n" $name "?"; fail=1; continue; fi
	IFS='|' read -r n v c d s w det < $res
	[[ $v == PASS ]] || fail=1
	printf "%-26s %-5s %5s %6s %4s  %s\n" $n $v $c $d $s "${w:+[$w] }$det"
done
print
(( fail )) && print "실패 있음 — 로그: $LOGDIR" || print "모두 PASS"
exit $fail
