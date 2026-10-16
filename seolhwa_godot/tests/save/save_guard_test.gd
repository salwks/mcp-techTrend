# 저장 지킴 시험(scripts/region/save_guard.gd — 재기획 2단계 저장 안전) — 헤드리스.
#   godot --headless --path . -s res://tests/save/save_guard_test.gd
#   -s 실행은 시험·도구 실행이다 → 진행·칸·작은 그림·설정 경로가 모두 모래상자(…/설화록_test) 안이고, 사용자 저장 폴더(…/설화록)가 아니다.
#   실제로 저장·칸 저장·설정 쓰기를 해 보고, 파일이 모래상자에만 생겼는지 본다. 끝나면 지운다.
#   끝 줄: SAVEGUARDTEST PASS n / SAVEGUARDTEST FAIL n
extends SceneTree

const Progress := preload("res://scripts/region/progress.gd")
const GameSettings := preload("res://scripts/story/game_settings.gd")
const SaveGuard := preload("res://scripts/region/save_guard.gd")

var n := 0
var fails := 0

func ok(c: bool, what: String) -> void:
	n += 1
	if c: print("  ok  ", what)
	else:
		fails += 1
		print("  FAIL ", what)

func _init() -> void:
	var real := OS.get_user_data_dir().trim_suffix("/") + "/"
	ok(SaveGuard.sandboxed(), "-s 실행은 모래상자(why=%s)" % SaveGuard.why())
	ok(SaveGuard.root() != "" and not (SaveGuard.root() + "/").begins_with(real), "모래상자 %s 는 사용자 폴더 %s 밖" % [SaveGuard.root(), real])
	# 명령줄 가리기 — 1단계 사고를 낸 --nostory 촬영 등은 반드시 모래상자, 사용자 놀이 명령줄만 user://
	var cases := [
		[[], [], ""],
		[["--savefile=user://play_chunhyang.json", "--devtravel"], [], ""],
		[["--view=first", "--scale=1.5", "--fullscreen"], [], ""],
		[["--warp=-3005,240", "--mapshots=/tmp/m", "--mapzooms", "--nostory"], [], "tool"],
		[["--nostory"], [], "tool"],
		[["--talkshot=oil_wife", "--newgame", "--winshot"], [], "tool"],
		[["--savefile=user://progress.json", "--storytest=namwon:A"], [], "tool"],
		[["--savefile=user://progress.json", "--saveroot=/tmp/x"], [], "tool"],
		[[], ["--headless", "-s", "res://tests/save/save_guard_test.gd"], "tool"],
		# 2026-10-16 사고: 게임 인자를 '--' 없이 넘김 → Godot이 버려 놀이 실행이 되던 것 → 이제 실행 중단
		[[], ["--path", ".", "--resolution", "1280x720", "--savefile=user://st_op_cap.json", "--titletest=newcap:x", "--storylog"], "blocked"],
		[[], ["--path", ".", "--titletest=new"], "blocked"],
		[[], ["--headless", "--path", ".", "--storytest=namwon:A"], "blocked"],
		[[], ["--path", ".", "--write-movie", "/tmp/a.avi", "--nostory"], "blocked"],
		# 엔진 도구 인자만 → 모래상자
		[[], ["--path", ".", "--write-movie", "/tmp/a.avi", "--fixed-fps", "10"], "tool"],
		[[], ["--headless", "--path", "."], "tool"],
		[[], ["--path", ".", "--quit-after", "100"], "tool"],
		# 놀이 실행(편집기 F5가 붙이는 인자 포함) → 그대로 user://
		[[], ["--path", "."], ""],
		[[], ["--path", ".", "--resolution", "1920x1080", "--log-file", "/tmp/g.log", "--verbose"], ""],
		[[], ["--remote-debug", "tcp://127.0.0.1:6007", "--editor-pid", "5805", "--position", "100,100", "--path", ".", "--scene", "res://scenes/region.tscn"], ""],
		[["--savefile=user://play_chunhyang.json"], ["--path", ".", "--", "--savefile=user://play_chunhyang.json"], ""],
		[["--storytest=namwon:A"], ["--headless", "--path", ".", "--", "--storytest=namwon:A"], "tool"],
	]
	for c in cases:
		var got := SaveGuard.classify(PackedStringArray(c[0]), PackedStringArray(c[1]))
		var kind := "" if got == "" else ("blocked" if got.begins_with("blocked:") else "tool")
		ok(kind == c[2], "명령줄 %s %s → %s" % [c[0], c[1], "놀이(user://)" if got == "" else ("실행 중단" if kind == "blocked" else "모래상자(" + got + ")")])
	# 기본 경로(--savefile 없음) → tool_progress.json
	var p0 := Progress.slot_path(0)
	ok(p0.begins_with(SaveGuard.root()) and p0.ends_with("tool_progress.json"), "기본 진행 경로 %s" % p0)
	# 명시 경로 user://X → 모래상자/X
	for f in ["user://progress.json", "user://play_chunhyang.json", "user://st_save_guard.json"]:
		Progress.use_path(f)
		var paths := [Progress.slot_path(0), Progress.slot_path(1), Progress.slot_path(3), Progress.thumb_path(0), Progress.thumb_path(2)]
		var bad := paths.filter(func(q): return SaveGuard.is_real_user_path(q) or not String(q).begins_with(SaveGuard.root()))
		ok(bad.is_empty(), "%s → %s (칸·그림 포함, 사용자 폴더 경로 %d)" % [f, paths[0], bad.size()])
	ok(not SaveGuard.is_real_user_path(GameSettings.path()) and GameSettings.path().begins_with(SaveGuard.root()), "설정 경로 %s" % GameSettings.path())
	# 실제로 써 본다
	Progress.use_path("user://st_save_guard.json")
	Progress.reset_all()
	Progress.set_var("SAVEGUARD_PROBE", 1)
	Progress.save()
	var img := Image.create(8, 8, false, Image.FORMAT_RGB8)
	Progress.save_slot(1, img)
	var made := [Progress.slot_path(0), Progress.slot_path(1), Progress.thumb_path(1)]
	ok(made.all(func(q): return FileAccess.file_exists(q)), "저장·칸·그림이 모래상자에 생김")
	ok(not FileAccess.file_exists(real + "st_save_guard.json") and not FileAccess.file_exists(real + "st_save_guard_slot1.json"), "사용자 폴더에 같은 이름 파일 없음")
	var s0 := GameSettings.get_v("guide")
	GameSettings.set_v("guide", s0)
	ok(FileAccess.file_exists(GameSettings.path()), "설정 쓰기는 모래상자 settings.json")
	for q in made: DirAccess.remove_absolute(q)
	Progress.use_path("")
	print("SAVEGUARDTEST %s %d" % ["PASS" if fails == 0 else "FAIL", n if fails == 0 else fails])
	quit(0 if fails == 0 else 1)
