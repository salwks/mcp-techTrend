#!/bin/zsh
# 설화록 대본 시험 한 번에 돌리기(헤드리스) — PASS/FAIL 표와 종료 코드를 찍는다.
#
#   tools/run_story_tests.sh                 # 전부(대본 시험 + 노정 걷기), 동시 3개
#   tools/run_story_tests.sh -j 1            # 한 줄로
#   tools/run_story_tests.sh namwon hwangju:B walk   # 이름(앞부분)이 맞는 것만
#   tools/run_story_tests.sh -l              # 목록만
#
# 판정: 로그에 PASS 줄(STORYTEST/ONBOARDTEST/RIDETEST/FASTTEST/TALKTEST/STATIONTEST/SAVETEST/CONTTEST/TRAVELTEST/MAPTEXTTEST/MAPKNOWNTEST/MAPPINTEST/VIEWTEST PASS, 걷기는 WALK done + TRAVEL arrive)이 있고 종료 코드 0, SCRIPT ERROR 0.
# 시험마다 저장 파일을 따로 쓴다(--savefile=user://st_<이름>.json → 모래상자 …/설화록_test/st_<이름>.json, save_guard.gd) — 동시에 돌려도 서로 덮어쓰지 않고, 사용자 저장 폴더에는 쓰지 않는다.
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
# 저장 지킴(scripts/region/save_guard.gd): 시험 인자가 있으면 user://st_*.json은 사용자 저장 폴더가 아니라 이 모래상자에 쓰인다
#   엔진 로그도 --log-file로 모래상자에(사용자 폴더 logs/의 돌려쓰기·지우기를 건드리지 않게)
SANDBOX="$HOME/Library/Application Support/Godot/app_userdata/설화록_test"
mkdir -p "$SANDBOX/logs"

# 이름 | 제한(초) | 인자
TESTS=(
	"namwon:A|600|--storytest=namwon:A"
	"namwon:B|600|--storytest=namwon:B"
	# A2: 갈래 A + B와 무관한 검사 셋(beast_way 틀린 판단 Fail Forward · 해 질 무렵 대답 trace · 크게 밀리면 포수 화살) — 2026-10-16 참기름 감사로 B에서 옮김
	"namwon:A2|600|--storytest=namwon:A2"
	"namwon:C|240|--storytest=namwon:C"
	"namwon:onboard|240|--storytest=namwon:onboard"
	# 게임플레이 구조 1차 §4(scripts/story/oneonui_observe_test.gd): 관찰 기록 · 둘 뒤 초급 판단 · 서쪽 숲 Fail Forward · 관찰/판단 도중 저장·불러오기 · 한 번만 · FIXED_BEATS 그대로
	"namwon:observe|240|--storytest=namwon:observe"
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
	"jeju:A|420|--route=SEA_NAMHAE_JEJU --storytest=jeju:A"
	"jeju:B|420|--route=SEA_NAMHAE_JEJU --storytest=jeju:B"
	"jeju:C|420|--route=SEA_NAMHAE_JEJU --storytest=jeju:C"
	"walk:hwangju-pyeongyang|300|--route=HH_HWANGJU-PA_PYEONGYANG --walkroute=01 --walkspeed=12"
	"walk:hangang-boat|600|--route=RIVER_HANGANG --walkroute=01 --walkspeed=12 --sailspeed=25"
	# 자동 기승·역마(scripts/region/ride_test.gd) — 시험만 4배 빠르게(--ridetime=4)
	"ride:namwon-unbong|420|--region=JL_NAMWON_UNBONG --ridetest=station_namwon:unbong_eup --ridefixture=res://story/hwangju/test_post_hanyang.json --ridetime=4 --notitle"
	"ride:r01-park|420|--route=JL_NAMWON_UNBONG-GG_HANYANG --ridetest=end_from:end_to --ridefixture=res://story/hwangju/test_post_hanyang.json --ridevars=MAIN_MASTER_TRACE=HANYANG --rideneed=R0101,R0102,R0103,R0104 --ridepark=1 --rideratio=0.5 --ridetime=4 --notitle"
	"ride:r05-event|300|--route=PA_PYEONGYANG-HG_HAMHEUNG --ridetest=end_from:end_to --ridefixture=res://story/hamhung/test_post_act3.json --rideexpect=event --ridetime=4 --notitle"
	"ride:hanyang-gate|420|--region=GG_HANYANG --ridetest=noryang_naru_0:hanyang_doseong_in --ridefresh --nostory --ridetime=4 --notitle"
	"ride:fork-yeongheung|420|--route=GG_HANYANG-HG_HAMHEUNG --ridetest=end_from:end_to --ridefork=갈림 --rideexpect=fork --ridedone=GG_HANYANG-HG_HAMHEUNG --nostory --ridetime=4 --notitle"
	"ride:blizzard|300|--region=HG_HAMHEUNG --ridetest=end_GG_HANYANG-HG_HAMHEUNG_to:hamheung_eup --rideweather=blizzard@300 --rideexpect=blizzard --ridefresh --nostory --ridetime=4 --notitle"
	# 건너뛰기(travel_overlay — Space · 단추): 길가 이야기(R0101~R0104 소문·장면·朴 표식)를 잃지 않는다 · 사건 앞에서 멈춘다
	"ride:r01-skip|420|--route=JL_NAMWON_UNBONG-GG_HANYANG --ridetest=end_from:end_to --ridefixture=res://story/hwangju/test_post_hanyang.json --ridevars=MAIN_MASTER_TRACE=HANYANG --rideneed=R0101,R0102,R0103,R0104 --ridepark=1 --rideskipall --ridetime=4 --notitle"
	"ride:r05-event-skip|300|--route=PA_PYEONGYANG-HG_HAMHEUNG --ridetest=end_from:end_to --ridefixture=res://story/hamhung/test_post_act3.json --rideexpect=event --rideskipall --ridetime=4 --notitle"
	"fast:same-space|240|--region=JL_NAMWON_UNBONG --fasttravel=JL_NAMWON_UNBONG/unbong_eup --ridefixture=res://story/hwangju/test_post_hanyang.json --notitle"
	"fast:to-hanyang|300|--region=JL_NAMWON_UNBONG --fasttravel=GG_HANYANG/noryangjin --ridefixture=res://story/hwangju/test_post_hanyang.json --notitle"
	"fast:jeju-blocked|240|--region=JL_NAMWON_UNBONG --fasttravel=JJ_JEJU/jeju_mok --fastexpect=blocked --ridefixture=res://story/hwangju/test_post_hanyang.json --notitle"
	# 역참(scripts/region/station_test.gd): 두 역 들러 '가 봄' → Travel.warp_to_station → 문 앞 넓은 E 없음 · 곁 사람이 마부보다 먼저 · 마부 E → 지도 고르기(금빛·흐림 까닭·확인 상자·1인칭 커서) 뒤에야 말 · Esc 그만 → 길목 깃발(가 봄·깃발↔역, 역마 건너뛰기) → 지도 R '말만 빌리기'로 다음 고을 어귀까지(보통 · 건너뛰기 같은 도착) / 다른 공간 역으로 역마
	"station:namwon|480|--region=JL_NAMWON_UNBONG --stationtest=namwon,inwol,unbong_eup --ridefixture=res://story/hwangju/test_post_hanyang.json --ridetime=4 --notitle"
	# 개발 '전국 이동 열림'(scripts/region/dev_travel.gd): 첫 사건 막음 흐림 → 켜면 모두 열림 · 저장 그대로 · 끄면 다시 막힘
	"station:dev|300|--region=JL_NAMWON_UNBONG --stationtest=dev --ridefixture=res://story/hwangju/test_post_hanyang.json --notitle"
	"station:to-cheongpa|300|--region=JL_NAMWON_UNBONG --stationtest=cross:cheongpa --ridefixture=res://story/hwangju/test_post_hanyang.json --notitle"
	# 이동 규칙(scripts/region/travel_rules_test.gd): 나루 배 E보다 곁 사람 · 권역 말 타는 곳 25m(노정 그대로·막 내린 자리 40m) · 남원 밤 먼 길 막음
	"travel:boat-priority|300|--region=GG_HANYANG --traveltest=boat --ridefixture=res://story/hwangju/test_post_hanyang.json --notitle"
	"travel:boat-skip|300|--region=GG_HANYANG --traveltest=boatskip --ridefixture=res://story/hwangju/test_post_hanyang.json --notitle"
	"travel:mount-region|300|--region=JL_NAMWON_UNBONG --traveltest=mount --ridefixture=res://story/hwangju/test_post_hanyang.json --notitle"
	"travel:mount-route|300|--route=HH_HWANGJU-PA_PYEONGYANG --traveltest=mount --nostory --notitle"
	"travel:namwon-night|300|--region=JL_NAMWON_UNBONG --traveltest=nightlock --notitle --case=namwon"
	# 강·바닷길 노정 깃발 없음(제작 규칙 결정 5): 남해~제주 뱃길 덕진다리 — 깃대·깃발 E 없음, '가 봄'·역마 창 목록·뱃길 그대로
	"travel:sea-waymark|300|--route=SEA_NAMHAE_JEJU --traveltest=waymark --notitle"
	# 고을 사람 말 걸기·이야기 인물 「…」(scripts/story/talk_test.gd) — 앞(새 저장) → 저장 얹고 뒤
	"talk:namwon|420|--region=JL_NAMWON_UNBONG --talktest=namwon_jang,namwon_eup --talkfixture=res://story/hwangju/test_post_hanyang.json --talkexpect=var"
	"talk:hanyang|420|--region=GG_HANYANG --talktest=chilpae_jang,ungjongga --talkfixture=res://story/hwangju/test_post_hanyang.json --talkexpect=need"
	"talk:jeju|420|--region=JJ_JEJU --talktest=gimnyeong,jeju_jang --talkfixture=res://story/jeju/test_post_act4.json --talkvars=CASE_JEJU_OUTCOME=A,CASE_JEJU_COMPLETE=true --talkexpect=var"
	# 대화 구도·복귀(재기획 2단계, scripts/story/talk_shot.gd --talkcycle): 네 방향에서 E 연타로 말 걸고 끝까지 — 카메라·가림·이동 잠금 복귀, 줄 건너뜀·다시 열림 없음
	#   (재기획 3단계: 새 게임 기본이 메인 서장이 되어 오누이 기름집 아낙은 --case=namwon으로 세운다)
	"talk:cycle|300|--talkshot=oil_wife --talkcycle=8 --newgame --case=namwon"
	"talk:cycle-fp|300|--talkshot=oil_wife --talkcycle=4 --newgame --view=first --case=namwon"
	# 앉은 고을 사람(scripts/region/seat_test.gd — 인물 빌더 3단계): 장터 좌판·가가·시전 장꾼이 앉아 있고 자리를 지킨다 · 이야기 인물·사건 군중 자리는 비킨다 · 앉은 채 말 걸기 · 평상 손님·툇마루 노인 자리
	"seat:namwon|300|--region=JL_NAMWON_UNBONG --seattest=namwon_jang --nostory --notitle"
	"seat:hanyang|300|--region=GG_HANYANG --seattest=ungjongga --nostory --notitle"
	# 시작 메뉴 → 이어 하기(남원 이른 옛 저장) / 새 게임 → 이야기 인물·고을 사람에게 E로 말 걸기(scripts/story/continue_test.gd)
	"continue:namwon-early|300|--region=JL_NAMWON_UNBONG --continuetest=continue --continuefixture=res://story/namwon/test_early_save.json"
	"continue:new|300|--region=JL_NAMWON_UNBONG --continuetest=new"
	# 남원 결정 6: 옛 밤 절정 도중 저장(꾸민 저장) → 저녁 준비 바로 앞으로 되돌림 → 귀환·경고·준비가 다시 돈다
	"continue:namwon-climax|300|--region=JL_NAMWON_UNBONG --continuetest=continue --continuefixture=res://story/namwon/test_climax_save.json --continueexpect=rollback"
	# 남원 v3.2: 새 흐름의 동아줄 도중 저장(꾸민 저장) → 같은 안전지점 · 옛 v3 아침 저장(꾸민 저장) → 새 아침(외딴집 마당)부터
	"continue:namwon-rope|300|--region=JL_NAMWON_UNBONG --continuetest=continue --continuefixture=res://story/namwon/test_rope_save.json --continueexpect=rollback_rope"
	"continue:namwon-morning|300|--region=JL_NAMWON_UNBONG --continuetest=continue --continuefixture=res://story/namwon/test_morning_save.json --continueexpect=morning"
	"continue:namwon-v1done|300|--region=JL_NAMWON_UNBONG --continuetest=continue --continuefixture=res://story/namwon/test_v1_done_save.json --continueexpect=v1_done"
	# 재기획 3단계(추가 지시 2·3, D3) 옛 저장: 끝난 오누이 → 메인 서장 합류(JOIN) · 그 자리에서 끝난 오누이가 메인에 자리를 내줌 · 한양 뒤 → 춘향 그대로 · 메인 서장 도중(편지 뒤) 이어 하기
	"continue:namwon-done-join|300|--region=JL_NAMWON_UNBONG --continuetest=continue --continuefixture=res://story/namwon/test_v1_done_save.json --continueexpect=join"
	"continue:namwon-done-yield|300|--region=JL_NAMWON_UNBONG --continuetest=continue --continuefixture=res://story/namwon/test_v1_done_save.json --case=namwon --continueexpect=yield"
	"continue:chunhyang-entry|300|--region=JL_NAMWON_UNBONG --continuetest=continue --continuefixture=res://story/hwangju/test_post_hanyang.json --continueexpect=chunhyang"
	"continue:main-letter|300|--region=JL_NAMWON_UNBONG --continuetest=continue --continuefixture=res://story/main_p1/test_main_letter_save.json --continueexpect=main_resume"
	# 재기획 3단계 첫 15분(story/main_p1/main_p1_first15_test.gd): 시작 메뉴 → 새 게임 → 거처 → 편지 → 견주기 → 「설화록」 → 걸어서 솔잎 주막 → 지도 [목적지 설정]
	#   D7(조작 반환 ≤12초) · 안내 여섯이 행동으로 끝남 · 이동 바로 복귀·카메라 복귀·E 겹침 없음 · 저장 재개 셋 · 순간이동 없음 / onui: 이어서 북문 밖 행상 → 오누이
	"first15:new|420|--region=JL_NAMWON_UNBONG --continuetest=first15 --storylog"
	"first15:onui|420|--region=JL_NAMWON_UNBONG --continuetest=first15 --first15=onui --storylog"
	# 저장 칸(scripts/story/ui_test.gd): 칸 1 저장 → 바꿈 → 칸 1 불러오기(장면 다시 열기) → 되돌아왔나 · 버전 1 저장 읽기
	"save:slot-load|300|--region=JL_NAMWON_UNBONG --notitle --savetest"
	# 지도 글(scripts/region/region_map.gd --maptexttest): 권역·고을·전국 지도를 최소·중간·최대 배율로 — 이름표 글 크기·높이가 같은가 · 기호 속 글자 MAP_GLYPH ·
	#   이름표 겹침 없음 · 확대 단계(멀리 건물 이름 없음, 가까이 건물 이름 있음, 크기 같음)
	"map:text-zoom|300|--region=JL_NAMWON_UNBONG --notitle --maptexttest --uifixture=res://story/hwangju/test_post_hanyang.json"
	"map:text-zoom-hanyang|300|--region=GG_HANYANG --notitle --maptexttest --uifixture=res://story/hwangju/test_post_hanyang.json"
	# 지도 세 단계(C65 — scripts/region/map_known_test.gd): 권역 진입 → 상식 KNOWN(VISITED 아님)·사건 장소·생활시설 UNKNOWN · 들음 → KNOWN · 다가감 → VISITED ·
	#   KNOWN은 역참·역마·깃발 조건을 채우지 않음 · 옛 저장에 상식 채움 · KNOWN 이름표 옅음/VISITED 보통(글 크기 같음) · 범례
	# 재기획 4단계 지도 목적지·역마(scripts/region/map_pin_test.gd): map — 커서 고정 휠 줌(5·10·20칸 ≤8px)·6px 끌기·빈 곳/안 가 본 곳 핀·바꾸기·지우기(우클릭)·Esc 차례·
	#   빠른 이동 잠금 까닭·다른 권역 카드·M 30번·저장 뒤 목적지 그대로 / ride — 걷기 vs 말·큰길 위 길·D6(말 위 지도 → 섬, 지도 동안 Space 없음)·다시 출발·
	#   목적지 어귀·성문 앞 하차·말 타는 곳까지 걷기 안내·다른 권역 목적지 → 길 끝
	"mappin:map|300|--region=JL_NAMWON_UNBONG --mappintest=map --ridefixture=res://story/hwangju/test_post_hanyang.json --notitle"
	"mappin:ride|420|--region=JL_NAMWON_UNBONG --mappintest=ride --ridefixture=res://story/hwangju/test_post_hanyang.json --ridetime=4 --notitle"
	"map:known-namwon|300|--region=JL_NAMWON_UNBONG --notitle --knowntest"
	"map:known-hanyang|300|--region=GG_HANYANG --notitle --knowntest"
	# 1인칭 시점(scripts/region/view_test.gd — C68 v2): 0 키 → 1인칭(눈높이·플레이어 층 숨김·점무늬 끔·땅 잔무늬) · 카메라 기준 걷기·돌기 · 마우스 둘러보기 ±70° ·
	#   고을 사람·이야기 인물 대화·살펴보기·선택지·문제 비교/결정·카메라 없는 장면·지도·Esc·역마 창 동안 1인칭 그대로(말하는 이·물건 쪽으로 돌아봄, 마우스 놓음) ·
	#   저작 연출(d.camera·shot·glide)은 컷으로 → 바로 눈높이 · 말 위 3인칭 · 0 키로 되돌림
	"view:namwon|300|--region=JL_NAMWON_UNBONG --viewtest --ridefixture=res://story/hwangju/test_post_hanyang.json --notitle"
	# 춘향 준비(scripts/story/prep_test.gd): 조건부 배치(F-11) 없음→있음→없음 · 옥(늘 있음·문 상태) · 오누이 흔적(우물·수수밭 푸름/붉음) · EventCrowd(인원·seed·when·이야기 인물 없음·먼 거리 숨김)
	"chunhyang:prep|300|--region=JL_NAMWON_UNBONG --preptest --notitle --case=namwon"
	# 춘향 PART II 준비(scripts/story/part2_prep_test.gd): 공용 자세(generic·이야기 인물) · PART II 차림 · SIT_SINK 없음 · 잔치 짜임 · set_pose 같은 사람 · PART II 소품 닫힘/강제
	"chunhyang:part2prep|300|--region=JL_NAMWON_UNBONG --p2preptest --notitle"
	# 춘향 PART I(story/namwon_chunhyang/namwon_chunhyang_test.gd): a 진입 판정·단오 군중 28·남원 사람·1A~5A 끝까지(같이 감·들었습니다·기다리실 겁니까) ·
	#   b 다른 선택(지나감·혼자 가시오·끄덕임·말 없음) · after PART I 끝+떠남+강릉 → PART II는 아무것도 서지 않는다
	"namwon_chunhyang:a|420|--region=JL_NAMWON_UNBONG --storytest=namwon_chunhyang:a --notitle"
	"namwon_chunhyang:b|420|--region=JL_NAMWON_UNBONG --storytest=namwon_chunhyang:b --notitle"
	"namwon_chunhyang:after|300|--region=JL_NAMWON_UNBONG --storytest=namwon_chunhyang:after --notitle"
	# 춘향 PART II-A(story/namwon_chunhyang/namwon_chunhyang_p2a_test.gd): p2a 열림 판정·6A 행차·아전(맡는다)·잡역·8A 점고(조작·줄 묶임)·월매 집(경고)·수청 8A→10A·
	#   곤장(잡는다 — 맞음)·팔·옥문 SEALED·첫 밤(가져다줌)·옥 대화·차일 규칙·조작 비율 고리·II-B 없음·머리 다시 굽기 / p2b 싫다(끌려감)·느슨하게·기다림·설득 / p2c 놓는다·지나간다
	"namwon_chunhyang:p2a|420|--region=JL_NAMWON_UNBONG --storytest=namwon_chunhyang:p2a --notitle"
	"namwon_chunhyang:p2b|420|--region=JL_NAMWON_UNBONG --storytest=namwon_chunhyang:p2b --notitle"
	"namwon_chunhyang:p2c|420|--region=JL_NAMWON_UNBONG --storytest=namwon_chunhyang:p2c --notitle"
	# 춘향 PART II-B(story/namwon_chunhyang/namwon_chunhyang_p2b_test.gd — 게임플레이 구조 1차 §7~§23): 술·쌀·상소(Activity/Problem, 순서 자유·한 번만) →
	#   몽룡 귀환 14A · 월매 집 · 옥중 상봉 · 잔치(EventCrowd 14 · 사령↔상 실제 틈 ≥1.6 · 차일 C62) · 시 17A · 출두(같은 노드 자세 · cower) · 피해 복구(본 것/들은 것) · 석방 · 포승 기억 · RELEASED
	#   iib1 순응·소극(관찰 도중·진 채 저장/불러오기) / iib2 저항(잔치 도중 저장/불러오기) / iib3 섞임(다시 묻기 전·잔치 날 아침 저장/불러오기)
	"namwon_chunhyang:iib1|300|--region=JL_NAMWON_UNBONG --storytest=namwon_chunhyang:iib1 --notitle"
	"namwon_chunhyang:iib2|300|--region=JL_NAMWON_UNBONG --storytest=namwon_chunhyang:iib2 --notitle"
	"namwon_chunhyang:iib3|300|--region=JL_NAMWON_UNBONG --storytest=namwon_chunhyang:iib3 --notitle"
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
	rm -f "$SANDBOX/st_${safe}.json" "$SANDBOX"/st_${safe}_slot<1-3>.json(N) "$SANDBOX"/st_${safe}_slot<1-3>.png(N) 2>/dev/null
	timeout $(( limit * TSCALE )) $GODOT --headless --log-file "$SANDBOX/logs/st_${safe}.log" --path $ROOT res://scenes/region.tscn -- ${=spec} --savefile=user://st_${safe}.json > $log 2>&1
	local code=$?
	local dt=$(( SECONDS - t0 ))
	local verdict=FAIL why=""
	local serr=$(grep -c "SCRIPT ERROR" $log)
	local rerr=$(grep -c -E "^ERROR: (Initializing already|Parameter \"(mem|multimesh|m)\" is null)" $log)
	if [[ $name == walk:* ]]; then
		grep -q "^WALK done" $log && grep -q "^TRAVEL arrive" $log && verdict=PASS
	else
		grep -q -E "^(STORYTEST|ONBOARDTEST|RIDETEST|FASTTEST|TALKTEST|STATIONTEST|SAVETEST|CONTTEST|TRAVELTEST|PREPTEST|MAPTEXTTEST|MAPKNOWNTEST|MAPPINTEST|VIEWTEST|SEATTEST|TALKCYCLE) PASS" $log && verdict=PASS
		grep -q -E "^(RIDETEST|FASTTEST|TALKTEST|STATIONTEST|SAVETEST|CONTTEST|TRAVELTEST|PREPTEST|MAPTEXTTEST|MAPKNOWNTEST|MAPPINTEST|VIEWTEST|SEATTEST|TALKCYCLE) FAIL" $log && verdict=FAIL
	fi
	local detail=$(grep -E "^(STORYTEST|ONBOARDTEST|RIDETEST|FASTTEST|TALKTEST|STATIONTEST|SAVETEST|CONTTEST|TRAVELTEST|PREPTEST|MAPTEXTTEST|MAPKNOWNTEST|MAPPINTEST|VIEWTEST|SEATTEST|TALKCYCLE) (PASS|FAIL)" $log | tail -1 | sed -E 's/^(STORYTEST|ONBOARDTEST|RIDETEST|FASTTEST|TALKTEST|STATIONTEST|SAVETEST|CONTTEST|TRAVELTEST|PREPTEST|MAPTEXTTEST|MAPKNOWNTEST|MAPPINTEST|VIEWTEST|SEATTEST|TALKCYCLE) //')
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
