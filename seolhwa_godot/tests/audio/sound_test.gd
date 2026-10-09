# 소리 기반(scripts/audio/sound.gd) 시험 — 헤드리스(Dummy 오디오)에서 재생·겹침·페이드·맞바꿈·낮춤·고요가 오류 없이 도는지.
#   godot --headless --path . -s res://tests/audio/sound_test.gd
#   사용자 설정 파일(user://settings.json)은 건드리지 않는다(GameSettings.test_override). 끝 줄: SOUNDTEST PASS n / SOUNDTEST FAIL n
extends SceneTree

const Sound := preload("res://scripts/audio/sound.gd")
const GameSettings := preload("res://scripts/story/game_settings.gd")
const IDS := ["knock", "footstep_heavy", "flour_rustle", "basket_roll", "tiger_growl", "axe_hit", "rope_creak", "rope_snap",
	"fall_impact", "wind", "breath_gasp", "journal_stamp", "page_turn", "ui_select"]

var n := 0
var fails := 0

func ok(c: bool, what: String) -> void:
	n += 1
	if c: print("  ok  ", what)
	else:
		fails += 1
		print("  FAIL ", what)

func _wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout

func _initialize() -> void:
	_run()

func _run() -> void:
	GameSettings.test_override = { vol_master = "10", vol_bgm = "7", vol_sfx = "9", vol_ambient = "8" }
	Sound.verbose = true
	print("audio driver: ", AudioServer.get_driver_name() if AudioServer.has_method("get_driver_name") else "?")
	# 파일
	for id in IDS: ok(Sound.has(id), "sfx 있음 %s" % id)
	ok(Sound.has("bgm_day_calm", "bgm") and Sound.has("bgm_night_drone", "bgm"), "bgm 둘 있음")
	var st: AudioStream = Sound.stream("bgm_day_calm", "bgm")
	ok(st is AudioStreamWAV and st.loop_mode == AudioStreamWAV.LOOP_FORWARD and st.loop_end > 0, "bgm은 고리(loop)")
	ok(not Sound.has("no_such_sound"), "없는 id는 없음")
	# 아직 root에 붙기 전에 부른 것도 미뤄서 한다
	Sound.play("knock")
	await process_frame
	await process_frame
	var s := Sound.state()
	ok(bool(s.get("ready", false)), "소리 노드가 root 아래 생김")
	for b in ["BGM", "SFX", "Ambient"]: ok(AudioServer.get_bus_index(b) >= 0, "버스 %s" % b)
	# 겹침
	Sound.stop_sfx()
	for i in 3: Sound.play("knock")
	s = Sound.state()
	ok(int(s.by_id.get("knock", 0)) == 3, "같은 id 셋 겹침 (%s)" % JSON.stringify(s.by_id))
	for i in 5: Sound.play("knock")
	s = Sound.state()
	ok(int(s.by_id.get("knock", 0)) == Sound.PER_ID, "같은 id는 %d개까지 (%s)" % [Sound.PER_ID, JSON.stringify(s.by_id)])
	for i in 20: Sound.play(IDS[i % IDS.size()])
	s = Sound.state()
	ok(int(s.voices) <= Sound.POOL, "목소리 수 %d ≤ %d" % [s.voices, Sound.POOL])
	Sound.play("no_such_sound")   # 오류 없이 한 줄만
	# 자리 있는 소리
	var holder := Node3D.new()
	root.add_child(holder)
	Sound.play_at("tiger_growl", Vector3(3, 0, 4), holder)
	Sound.play_at("tiger_growl", Vector3(-3, 0, 4), holder)
	await process_frame
	ok(holder.get_child_count() == 2, "자리 있는 소리 둘(겹침) — %d" % holder.get_child_count())
	Sound.play_at("knock", Vector3.ZERO, null)   # 부모 없으면 그냥 재생
	# 음악: 틀기 → 맞바꿈 → 낮춤 → 고요 → 멈춤
	Sound.music("bgm_day_calm", 0.3)
	await _wait(0.6)
	s = Sound.state()
	ok(s.bgm == "bgm_day_calm" and float(s.bgm_lv[s.bgm_cur]) > 0.99, "음악 페이드 인 (%s)" % JSON.stringify(s.bgm_lv))
	var first: int = s.bgm_cur
	Sound.music("bgm_night_drone", 0.3)
	await _wait(0.15)
	s = Sound.state()
	var mid_old: float = s.bgm_lv[first]
	var mid_new: float = s.bgm_lv[s.bgm_cur]
	ok(s.bgm_cur != first and mid_old > 0.05 and mid_old < 0.95 and mid_new > 0.05, "맞바꿈 도중 둘 다 들림 (%.2f / %.2f)" % [mid_old, mid_new])
	await _wait(0.5)
	s = Sound.state()
	ok(float(s.bgm_lv[first]) == 0.0 and float(s.bgm_lv[s.bgm_cur]) > 0.99, "맞바꿈 끝 (%s)" % JSON.stringify(s.bgm_lv))
	Sound.duck(-12.0, 0.3, 0.05, 0.2)
	await _wait(0.2)
	s = Sound.state()
	ok(float(s.duck_db) < -8.0, "잠시 낮춤 (%.1fdB, 버스 %.1fdB)" % [s.duck_db, s.bus_bgm_db])
	await _wait(0.8)
	ok(absf(float(Sound.state().duck_db)) < 0.5, "낮춤 되돌아옴 (%.1fdB)" % Sound.state().duck_db)
	Sound.hush(0.3, 0.05, 0.2)
	await _wait(0.2)
	ok(float(Sound.state().hush) < 0.05, "고요 (%.2f)" % Sound.state().hush)
	await _wait(0.8)
	ok(float(Sound.state().hush) > 0.99, "고요 뒤 돌아옴 (%.2f)" % Sound.state().hush)
	Sound.hush(-1.0, 0.05, 0.1)
	await _wait(0.4)
	ok(float(Sound.state().hush) < 0.05, "hush_end까지 머묾")
	Sound.hush_end(0.1)
	await _wait(0.3)
	ok(float(Sound.state().hush) > 0.99, "hush_end 뒤 돌아옴")
	Sound.music_level(0.5, 0.1)
	await _wait(0.3)
	ok(absf(float(Sound.state().level) - 0.5) < 0.01, "음악 크기 0.5")
	Sound.music_level(1.0, 0.0)
	Sound.music_stop(0.2)
	await _wait(0.5)
	s = Sound.state()
	ok(s.bgm == "" and float(s.bgm_lv[0]) == 0.0 and float(s.bgm_lv[1]) == 0.0, "음악 멈춤")
	await _wait(2.6)   # 자리 있는 소리(범 2.2초)는 끝나면 사라진다
	ok(holder.get_child_count() == 0, "자리 있는 소리는 끝나면 사라짐 — %d" % holder.get_child_count())
	holder.queue_free()
	GameSettings.test_override = {}
	print("SOUNDTEST %s %d" % ["PASS" if fails == 0 else "FAIL", n if fails == 0 else fails])
	quit(0 if fails == 0 else 1)
