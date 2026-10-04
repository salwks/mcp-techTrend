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
const DEFAULTS := { guide = "early", help = "normal", ride_speed = "normal", ride_slow = "on", cam_shake = "off" }

static var _d = null
static var test_override := {}   # 대본 시험: 사용자 설정과 상관없이 기본값으로(--storytest·--onboardtest)

static func data() -> Dictionary:
	if _d == null:
		_d = DEFAULTS.duplicate()
		if FileAccess.file_exists(PATH):
			var j = JSON.parse_string(FileAccess.get_file_as_string(PATH))
			if j is Dictionary: _d.merge(j, true)
	return _d

static func get_v(k: String) -> String:
	if test_override.has(k): return String(test_override[k])
	return String(data().get(k, DEFAULTS.get(k, "")))

static func set_v(k: String, v: String) -> void:
	data()[k] = v
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data(), " "))
		f.close()

static func guide() -> String: return get_v("guide")
static func help() -> String: return get_v("help")
