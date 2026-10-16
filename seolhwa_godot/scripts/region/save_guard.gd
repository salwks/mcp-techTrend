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
#   도구 엔진 인자(--headless·--write-movie·--fixed-fps·--quit·--quit-after·--check-only·--benchmark·--import·--export…) = 시험·도구 실행.
#   막음(실행 중단) = 엔진이 모르는 '-' 인자가 '--' 앞에 있다(게임 인자를 '--' 없이 넘김 — Godot은 그 인자를 버려 놀이 실행이 된다:
#               2026-10-16 사고 — 캡처 실행이 사용자 progress.json을 다시 썼다), 또는 모래상자 폴더를 만들지 못했다.
#               → 어떤 저장도 쓰지 않고(write_ok=false) region_main이 곧바로 끝낸다(종료 코드 3). 놀이 저장으로 넘어가지 않는다.
# 엔진·게임 캐시(logs·shader_cache·vulkan·kit_cache)는 저장이 아니라 그대로 user:// 를 같이 쓴다(키트 캐시는 내용 해시 — 찬 시작이 느려지지 않게).
extends RefCounted

const PLAY_ARGS := ["savefile", "devtravel", "scale", "view", "region", "fullscreen"]
# Godot 4.7 엔진 인자(godot --help) + 편집기에서 실행할 때 붙는 숨은 인자. 값은 따로 오는 낱말이라 '-'로 시작하지 않아 거르지 않는다
const ENGINE_OPTS := ["accessibility", "accessibility-driver", "accurate-breadcrumbs", "always-on-top", "audio-driver",
	"audio-output-latency", "benchmark", "benchmark-file", "breakpoints", "build-solutions", "check-only", "convert-3to4",
	"dap-port", "debug", "debug-avoidance", "debug-canvas-item-redraw", "debug-collisions", "debug-navigation", "debug-paths",
	"debug-server", "debug-stringnames", "delta-smoothing", "disable-crash-handler", "disable-render-loop", "disable-vsync",
	"display-driver", "doctool", "dump-extension-api", "dump-extension-api-with-docs", "dump-gdextension-interface",
	"dump-gdextension-interface-json", "editor", "editor-pseudolocalization", "export-debug", "export-pack", "export-patch",
	"export-release", "extra-gpu-memory-tracking", "fixed-fps", "frame-delay", "fullscreen", "gdextension-docs", "gdscript-docs",
	"generate-spirv-debug-info", "gpu-abort", "gpu-index", "gpu-profile", "gpu-validation", "headless", "help",
	"ignore-error-breaks", "import", "install-android-build-template", "language", "log-file", "lsp-port", "main-loop",
	"main-pack", "max-fps", "maximized", "no-docbase", "no-header", "patches", "path", "position", "print-fps", "profiling",
	"project-manager", "quiet", "quit", "quit-after", "recovery-mode", "remote-debug", "remote-fs", "remote-fs-password",
	"render-thread", "rendering-driver", "rendering-method", "resolution", "scene", "screen", "script", "single-threaded-scene",
	"single-window", "tablet-driver", "text-driver", "time-scale", "validate-conversion-3to4", "validate-extension-api",
	"verbose", "version", "wid", "windowed", "write-movie", "xr-mode",
	"editor-pid", "allow_focus_steal_pid", "embedded", "uid",
	"b", "d", "e", "f", "h", "l", "m", "p", "s", "t", "v", "w", "q"]
# 저장을 모래상자로 보내는 엔진 인자(시험·촬영·도구로만 쓰는 것)
const TOOL_ENGINE_OPTS := ["headless", "write-movie", "fixed-fps", "quit", "quit-after", "check-only", "benchmark",
	"benchmark-file", "import", "export-debug", "export-pack", "export-patch", "export-release", "doctool", "disable-render-loop",
	"script", "s"]
const TOOL_PROGRESS := "user://tool_progress.json"

static var _decided := false
static var _root := ""        # 모래상자 절대 폴더("" = 놀이 실행 — user:// 그대로)
static var _why := ""
static var _blocked := ""    # "" = 괜찮다 · 그 밖 = 막은 까닭(어떤 저장도 쓰지 않고 실행을 끝낸다)

static func _decide() -> void:
	if _decided: return
	_decided = true
	var user := _parse(OS.get_cmdline_user_args())
	var tool := classify(OS.get_cmdline_user_args(), OS.get_cmdline_args())
	if tool == "": return
	_why = tool
	if tool.begins_with("blocked:"):
		_blocked = tool.trim_prefix("blocked:")
		_root = OS.get_user_data_dir().trim_suffix("/") + "_test"   # 읽기도 사용자 저장을 보지 않게(쓰기는 write_ok가 막는다)
		push_error("SAVEGUARD 실행 중단: " + _blocked)
		return
	if user.has("saveroot") and String(user.saveroot) != "1":
		_root = String(user.saveroot)
	else:
		_root = OS.get_user_data_dir().trim_suffix("/") + "_test"
	DirAccess.make_dir_recursive_absolute(_root)
	if not DirAccess.dir_exists_absolute(_root) or is_real_user_path(_root.path_join("x")):
		_blocked = "모래상자 폴더를 쓸 수 없다 " + _root
		push_error("SAVEGUARD 실행 중단: " + _blocked)

static func _parse(user_args: PackedStringArray) -> Dictionary:
	var user := {}
	for a in user_args:
		var kv := a.trim_prefix("--").split("=", true, 1)
		user[kv[0]] = kv[1] if kv.size() > 1 else "1"
	return user

# 명령줄 가리기(순수 함수 — 지킴 시험이 여러 명령줄을 넣어 본다): "" = 놀이 실행, 그 밖 = 모래상자로 보내는 까닭
#   "blocked:<까닭>" = 실행 중단(게임 인자를 '--' 없이 넘겼다)
static func classify(user_args: PackedStringArray, eng_args: PackedStringArray) -> String:
	var user := _parse(user_args)
	var tool_eng := ""
	for a in eng_args:
		if a == "--" or a == "++": break   # 사용자 인자가 시작된다(엔진이 get_cmdline_args에 넣는 경우)
		if not a.begins_with("-"): continue   # 엔진 인자의 값·장면 경로
		var k := a.lstrip("-").split("=", true, 1)[0]
		if user_args.has(a): continue
		if not ENGINE_OPTS.has(k):
			return "blocked:엔진이 모르는 인자 %s 가 '--' 앞에 있다 — 게임 인자는 '--' 뒤에 넘긴다(godot --path . -- %s …)" % [a, a]
		if TOOL_ENGINE_OPTS.has(k) and tool_eng == "": tool_eng = "engine:" + a
	if user.has("saveroot"): return "saveroot"
	if tool_eng != "": return tool_eng
	for k in user:
		if not PLAY_ARGS.has(k): return "--" + String(k)
	return ""

# 막혔나(게임 인자를 '--' 없이 넘김 · 모래상자 실패) — 막혔으면 어떤 저장도 쓰지 않고 실행을 끝낸다
static func blocked() -> String:
	_decide()
	return _blocked

# 이 경로에 저장 파일을 써도 되나: 막혔으면 아무 데도 안 된다. 모래상자 실행이면 사용자 저장 폴더는 안 된다
static func write_ok(p: String) -> bool:
	_decide()
	if _blocked != "": return false
	if _root != "" and is_real_user_path(p): return false
	return true

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
