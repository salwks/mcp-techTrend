# 저장 지킴이 — 시험·촬영·도구 실행이 사용자 저장 폴더(user:// = ~/Library/Application Support/Godot/app_userdata/설화록)에
# 저장 파일을 쓰지 못하게 한다(재기획 2단계 저장 안전 — 1단계 §7-3 사고: --nostory 촬영이 사용자 progress.json을 다시 썼다).
#
# 규칙(명령줄만 보고 한 번 정한다 — 어느 스크립트가 먼저 저장 경로를 묻든 같은 답):
#   놀이 실행 = 사용자 인자(-- 뒤)가 없거나 PLAY_ARGS만 있다(예: godot --path . / -- --savefile=user://play_chunhyang.json --devtravel)
#               → 지금처럼 user:// 에 쓴다.
#   시험·도구 실행 = 그 밖의 사용자 인자가 하나라도 있다(--storytest·--talkshot·--nostory·--mapshots·--warp·--notitle …),
#               또는 -s/--script(헤드리스 시험 스크립트), 또는 --saveroot=<폴더>
#               → 저장 파일(진행·칸·작은 그림·play_*·settings.json)의 user://X 를 모래상자 폴더/X 로 바꾼다.
#               모래상자 = --saveroot=<절대 폴더> 또는 사용자 폴더 옆 '<이름>_test'(…/app_userdata/설화록_test).
#               --savefile 없이 돈 시험·도구 실행은 진행 파일을 모래상자 tool_progress.json으로 하고, 시작할 때 비운다(늘 새 저장).
# 엔진·게임 캐시(logs·shader_cache·vulkan·kit_cache)는 저장이 아니라 그대로 user:// 를 같이 쓴다(키트 캐시는 내용 해시 — 찬 시작이 느려지지 않게).
extends RefCounted

const PLAY_ARGS := ["savefile", "devtravel", "scale", "view", "region", "fullscreen"]
const TOOL_PROGRESS := "user://tool_progress.json"

static var _decided := false
static var _root := ""        # 모래상자 절대 폴더("" = 놀이 실행 — user:// 그대로)
static var _why := ""

static func _decide() -> void:
	if _decided: return
	_decided = true
	var user := _parse(OS.get_cmdline_user_args())
	var tool := classify(OS.get_cmdline_user_args(), OS.get_cmdline_args())
	if tool == "": return
	_why = tool
	if user.has("saveroot") and String(user.saveroot) != "1":
		_root = String(user.saveroot)
	else:
		_root = OS.get_user_data_dir().trim_suffix("/") + "_test"
	DirAccess.make_dir_recursive_absolute(_root)

static func _parse(user_args: PackedStringArray) -> Dictionary:
	var user := {}
	for a in user_args:
		var kv := a.trim_prefix("--").split("=", true, 1)
		user[kv[0]] = kv[1] if kv.size() > 1 else "1"
	return user

# 명령줄 가리기(순수 함수 — 지킴 시험이 여러 명령줄을 넣어 본다): "" = 놀이 실행, 그 밖 = 모래상자로 보내는 까닭
static func classify(user_args: PackedStringArray, eng_args: PackedStringArray) -> String:
	var user := _parse(user_args)
	if user.has("saveroot"): return "saveroot"
	if eng_args.has("-s") or eng_args.has("--script"): return "script"
	for k in user:
		if not PLAY_ARGS.has(k): return "--" + String(k)
	return ""

# 시험·도구 실행인가(모래상자에 쓰는가)
static func sandboxed() -> bool:
	_decide()
	return _root != ""

static func root() -> String:
	_decide()
	return _root

static func why() -> String:
	_decide()
	return _why

# 저장 경로 바꾸기: 모래상자면 user://X → <모래상자>/X. res:// · 절대 경로 · 놀이 실행은 그대로
static func resolve(p: String) -> String:
	_decide()
	if _root == "" or not p.begins_with("user://"): return p
	return _root.path_join(p.trim_prefix("user://"))

# 사용자 저장 폴더(놀이 실행의 user://) 안인가 — 지킴 시험용
static func is_real_user_path(p: String) -> bool:
	var a := ProjectSettings.globalize_path(p) if p.begins_with("user://") or p.begins_with("res://") else p
	var u := OS.get_user_data_dir().trim_suffix("/") + "/"
	return a.begins_with(u)
