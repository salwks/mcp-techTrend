# 놀이 설정 — user://settings.json(저장 파일과 따로: 새 게임을 해도 남는다). 전투 난이도와 상관없는 안내 옵션(보강서 §13·§26).
#   guide(상호작용 안내): always 항상 · early 초반만(기본) · minimal 최소 · off 끔
#     always  — 조사 먹점·처음 한 번 안내를 늘 강하게
#     early   — 첫 20~30분(첫 사건이 끝나기 전)엔 강하게, 그 뒤 기본
#     minimal — 먹점 없음, 조사 거리 안에서만 'E 살펴보기'
#     off     — 먹점·처음 안내 없음(조사 거리 안 글자만 남는다 — 없으면 조작할 수 없으므로)
#   help(조사 도움): normal 기본 · detailed 자세히 · minimal 최소
#     detailed — 조사물 강조 거리↑, 기록책의 '아직 모르는 것' 강조, 단서 방향 줄을 둘째 단서에도
#     minimal  — 첫 필수 조작만 안내, 단서 강조 거의 없음(방향 줄 없음)
#   자동 기승(이동수단 개선안 §31 — scripts/region/horse_ride.gd):
#     ride_speed(자동 기승 속도) normal 보통 · fast 빠름 / ride_slow(자동 감속) on 켬 · off 끔(이야기에 꼭 필요한 감속은 그대로) /
#     cam_shake(이동 카메라 흔들림) normal 보통 · weak 약함 · off 끔
#   소리 크기(scripts/audio/sound.gd 버스): vol_master 전체 · vol_bgm 음악 · vol_sfx 효과음 · vol_ambient 환경음 — "0"~"10"
#     바꾼 뒤 Sound.apply_settings()(options_menu가 부른다)
extends RefCounted

const PATH := "user://settings.json"
const GUIDE := ["always", "early", "minimal", "off"]
const GUIDE_LABEL := { always = "항상", early = "초반만", minimal = "최소", off = "끔" }
const HELP := ["normal", "detailed", "minimal"]
const HELP_LABEL := { normal = "기본", detailed = "자세히", minimal = "최소" }
const RIDE_SPEED := ["normal", "fast"]
const RIDE_SPEED_LABEL := { normal = "보통", fast = "빠름" }
const RIDE_SLOW := ["on", "off"]
const RIDE_SLOW_LABEL := { on = "켬", off = "끔" }
const CAM_SHAKE := ["normal", "weak", "off"]
const CAM_SHAKE_LABEL := { normal = "보통", weak = "약함", off = "끔" }
# 시점(region_main 1인칭 — 0 키와 같은 값): third 3인칭(기본) · first 1인칭. 깊이 흐림(post_effect dof): normal 보통 · weak 약함 · off 끔
const VIEW := ["third", "first"]
const VIEW_LABEL := { third = "3인칭", first = "1인칭" }
const DOF := ["normal", "weak", "off"]
const DOF_LABEL := { normal = "보통", weak = "약함", off = "끔" }
# 1인칭 마우스 감도(region_main.FP_SENS): low 낮음 · normal 보통 · high 높음
const MOUSE_SENS := ["low", "normal", "high"]
const MOUSE_SENS_LABEL := { low = "낮음", normal = "보통", high = "높음" }
const VOLUME := ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10"]
const VOLUME_LABEL := {}
const DEFAULTS := { guide = "early", help = "normal", ride_speed = "normal", ride_slow = "on", cam_shake = "off",
	view = "third", dof = "normal", mouse_sens = "normal",
	vol_master = "10", vol_bgm = "7", vol_sfx = "9", vol_ambient = "8" }

const SaveGuard := preload("res://scripts/region/save_guard.gd")
static var _d = null
static var test_override := {}   # 대본 시험: 사용자 설정과 상관없이 기본값으로(--storytest·--onboardtest)

static func data() -> Dictionary:
	if _d == null:
		_d = DEFAULTS.duplicate()
		if FileAccess.file_exists(path()):
			var j = JSON.parse_string(FileAccess.get_file_as_string(path()))
			if j is Dictionary: _d.merge(j, true)
	return _d

# 시험·도구 실행은 모래상자 settings.json(없으면 기본값) — 사용자 설정을 읽지도 쓰지도 않는다
static func path() -> String:
	return SaveGuard.resolve(PATH)

static func get_v(k: String) -> String:
	if test_override.has(k): return String(test_override[k])
	return String(data().get(k, DEFAULTS.get(k, "")))

static func set_v(k: String, v: String) -> void:
	data()[k] = v
	if not SaveGuard.write_ok(path()): return   # 저장 지킴: 막힌 실행·시험이 사용자 설정을 쓰지 않는다
	var f := FileAccess.open(path(), FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data(), " "))
		f.close()

static func guide() -> String: return get_v("guide")
static func help() -> String: return get_v("help")
