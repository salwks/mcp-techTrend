# 소리 — 게임 전체 공용 최소 소리 기반(남원 v3.2 §70 · 착수 결정 1). Godot AudioStreamPlayer(3D)만 쓴다.
#   장면을 다시 열어도(공간 넘어가기 reload_current_scene) 끊기지 않게 root 아래 노드 하나로 산다 — 처음 부를 때 스스로 생긴다(자동 로드 없음).
#   헤드리스(Dummy 오디오)에서도 그대로 돈다(소리만 안 난다).
#
# 부르는 법(모두 static — const Sound := preload("res://scripts/audio/sound.gd")):
#   Sound.play(id, {db, pitch, bus})          효과음 한 번. 같은 id를 겹쳐 틀 수 있다(id당 PER_ID개, 넘으면 가장 오래된 것을 끊는다)
#   Sound.play_at(id, 자리 Vector3, 부모 Node3D, {db, unit, max_dist})   자리 있는 효과음(AudioStreamPlayer3D, 끝나면 사라짐).
#                                             부모가 없으면 그냥 play(). 부모가 SubViewport 안이면 그 뷰포트의 3D 듣기를 켠다.
#   Sound.music(id, 페이드초)                  음악(BGM) 틀기 — 틀던 것이 있으면 맞바꿈(crossfade). ""이면 멈춤
#   Sound.music_stop(페이드초) · Sound.music_level(0~1, 초)   음악 멈춤 · 음악 크기를 천천히 바꿈(1이 기본)
#   Sound.duck(db, 머묾초, 내려가는초, 올라오는초)   잠시 음악을 낮췄다가 되돌림(대사·큰 소리 위)
#   Sound.hush(머묾초, 꺼지는초, 돌아오는초, 효과음도)  '갑자기 고요' — 음악·환경음을 거의 끈 채 머물다 돌아옴. 머묾 <0이면 hush_end()까지
#   Sound.hush_end(돌아오는초) · Sound.stop_sfx() · Sound.apply_settings() · Sound.has(id) · Sound.state()(시험용)
#
# 소리 파일: res://assets/audio/sfx/<id>.(ogg|wav) · res://assets/audio/bgm/<id>.(ogg|wav) — .ogg가 먼저.
#   임포트 없이 실행 중에 읽는다(ui_fonts.gd 글꼴과 같은 방식). 에디터가 임포트해 두었으면 그것을 쓴다.
#   지금 들어 있는 것은 모두 임시 합성 소리(tools/audio/make_placeholders.py, 목록 assets/audio/README.md) — 같은 id로 바꿔 넣으면 된다.
# 버스: Master → BGM · SFX · Ambient(없으면 만든다). 크기는 놀이 설정(game_settings.gd vol_*: "0"~"10").
extends Node

const GameSettings := preload("res://scripts/story/game_settings.gd")
const DIR := "res://assets/audio/"
const BUSES := ["BGM", "SFX", "Ambient"]
const POOL := 12          # 효과음(2D) 목소리 수
const PER_ID := 4         # 같은 id 동시
const SILENT := 0.0005    # 이보다 작은 크기는 -80dB로

# id별 기본값: bus · db(더할 크기) · pitch(높낮이 흔들기 ±)
const TUNE := {
	"wind": { bus = "Ambient" },
	"footstep_heavy": { pitch = 0.06 },
	"knock": { pitch = 0.03 },
	"rope_creak": { pitch = 0.08 },
	"axe_hit": { pitch = 0.05 },
	"basket_roll": { pitch = 0.05 },
	"brush_rustle": { pitch = 0.08 },
	"page_turn": { pitch = 0.08 },
	"ui_select": { pitch = 0.05 },
}

static var _inst = null
static var _cache := {}       # "sfx/<id>" → AudioStream(없으면 null도 기억)
static var _missing := {}
static var verbose := false   # 대본 시험·--storylog: SOUND 줄을 찍는다

# ---------------------------------------------------------------- static 입구
static func inst():
	if _inst != null and is_instance_valid(_inst): return _inst
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null: return null
	_inst = load("res://scripts/audio/sound.gd").new()
	_inst.name = "Sound"
	# 장면 _ready 도중에는 root에 바로 붙일 수 없다 — 미루고, 그 사이 부른 것도 미뤄서 차례대로 한다
	tree.root.add_child.call_deferred(_inst)
	return _inst

static func play(id: String, opts := {}) -> void:
	var s = inst()
	if s != null: s._play(id, opts)

static func play_at(id: String, pos: Vector3, parent: Node = null, opts := {}) -> void:
	var s = inst()
	if s != null: s._play_at(id, pos, parent, opts)

static func music(id: String, fade := 1.5) -> void:
	var s = inst()
	if s != null: s._music(id, fade)

static func music_stop(fade := 1.5) -> void:
	music("", fade)

static func music_level(level: float, sec := 1.0) -> void:
	var s = inst()
	if s != null: s._music_level(level, sec)

static func duck(db := -10.0, hold := 1.5, attack := 0.2, release := 0.8) -> void:
	var s = inst()
	if s != null: s._duck(db, hold, attack, release)

static func hush(hold := 1.5, fade_out := 0.12, fade_in := 1.2, sfx_too := false) -> void:
	var s = inst()
	if s != null: s._hush(hold, fade_out, fade_in, sfx_too)

static func hush_end(fade_in := 1.2) -> void:
	var s = inst()
	if s != null: s._hush_end(fade_in)

static func stop_sfx() -> void:
	var s = inst()
	if s != null: s._stop_sfx()

static func apply_settings() -> void:
	var s = inst()
	if s != null: s._apply_buses()

static func has(id: String, kind := "sfx") -> bool:
	return stream(id, kind) != null

static func state() -> Dictionary:
	var s = inst()
	return s._state() if s != null else {}

# 소리 파일 읽기(캐시) — kind: "sfx" | "bgm"
static func stream(id: String, kind := "sfx") -> AudioStream:
	var key := kind + "/" + id
	if _cache.has(key): return _cache[key]
	var st: AudioStream = null
	for ext in ["ogg", "wav"]:
		var p: String = DIR + key + "." + ext
		if ResourceLoader.exists(p): st = load(p)
		elif FileAccess.file_exists(p): st = _raw(p, ext)
		if st != null: break
	if st != null and kind == "bgm": _set_loop(st)
	_cache[key] = st
	return st

static func _raw(p: String, ext: String) -> AudioStream:
	var bytes := FileAccess.get_file_as_bytes(p)
	if bytes.is_empty(): return null
	if ext == "ogg": return AudioStreamOggVorbis.load_from_buffer(bytes)
	return AudioStreamWAV.load_from_buffer(bytes)

static func _set_loop(st: AudioStream) -> void:
	if st is AudioStreamWAV:
		st.loop_mode = AudioStreamWAV.LOOP_FORWARD
		st.loop_begin = 0
		st.loop_end = int(st.get_length() * st.mix_rate)
	elif st is AudioStreamOggVorbis:
		st.loop = true

static func vol_setting(key: String) -> float:
	var v := clampf(float(GameSettings.get_v(key)) / 10.0, 0.0, 1.0)
	return v * v   # 귀에 고르게 들리게(대략)

static func _db(lin: float) -> float:
	return -80.0 if lin < SILENT else linear_to_db(lin)

# ---------------------------------------------------------------- 노드
var _voices: Array = []        # [{p: AudioStreamPlayer, id, t}]
var _bgm: Array = []           # 두 줄(맞바꿈)
var _bgm_lv := [0.0, 0.0]      # 지금 크기(선형)
var _bgm_to := [0.0, 0.0]      # 목표
var _bgm_rate := [1.0, 1.0]    # 초당 바뀌는 양
var _bgm_cur := 0
var _bgm_id := ""
var _level := 1.0              # music_level
var _level_to := 1.0
var _level_rate := 1.0
var _duck_db := 0.0
var _duck_floor := 0.0
var _duck_until := 0.0
var _duck_att := 0.2
var _duck_rel := 0.8
var _hush_lv := 1.0               # 1 = 보통, 0 = 고요
var _hush_until := -1.0        # <0: 고요 없음 · INF: hush_end까지
var _hush_out := 0.12
var _hush_in := 1.2
var _hush_sfx := false
var _hush_on := false
var _t_us := 0

func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # 멈춤 메뉴 중에도 페이드는 흐른다(효과음 목소리는 멈춘다)

func _ready() -> void:
	_ensure_buses()
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.name = "bgm_%d" % i
		p.bus = "BGM"
		p.volume_db = -80.0
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(p)
		_bgm.append(p)
	_t_us = Time.get_ticks_usec()
	_apply_buses()

static func _ensure_buses() -> void:
	for b in BUSES:
		if AudioServer.get_bus_index(b) != -1: continue
		AudioServer.add_bus()
		var i := AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, b)
		AudioServer.set_bus_send(i, "Master")

func _now() -> float:
	return Time.get_ticks_usec() / 1000000.0

func _later(m: StringName, args: Array) -> bool:
	if is_inside_tree(): return false
	callv("call_deferred", [m] + args)
	return true

func _say(what: String) -> void:
	if verbose: printerr("SOUND " + what)

# ---- 효과음 ----
func _play(id: String, opts: Dictionary) -> void:
	if _later(&"_play", [id, opts]): return
	var st := stream(id)
	if st == null: _miss(id); return
	var p := _voice_for(id)
	var tune: Dictionary = TUNE.get(id, {})
	p.stream = st
	p.bus = String(opts.get("bus", tune.get("bus", "SFX")))
	p.volume_db = float(opts.get("db", 0.0)) + float(tune.get("db", 0.0))
	var pv: float = float(tune.get("pitch", 0.0))
	p.pitch_scale = float(opts.get("pitch", 1.0)) * (1.0 + randf_range(-pv, pv))
	p.play()
	_say("sfx " + id)

func _voice_for(id: String) -> AudioStreamPlayer:
	var same := []
	var free_v = null
	var oldest = null
	for v in _voices:
		var playing: bool = v.p.playing
		if playing and v.id == id: same.append(v)
		if not playing and free_v == null: free_v = v
		if oldest == null or v.t < oldest.t: oldest = v
	var pick = null
	if same.size() >= PER_ID:
		pick = same[0]
		for v in same:
			if v.t < pick.t: pick = v
	elif free_v != null: pick = free_v
	elif _voices.size() < POOL:
		var p := AudioStreamPlayer.new()
		p.name = "sfx_%d" % _voices.size()
		p.process_mode = Node.PROCESS_MODE_PAUSABLE
		add_child(p)
		pick = { p = p, id = "", t = 0.0 }
		_voices.append(pick)
	else: pick = oldest
	pick.p.stop()
	pick.id = id
	pick.t = _now()
	return pick.p

func _play_at(id: String, pos: Vector3, parent: Node, opts: Dictionary) -> void:
	if _later(&"_play_at", [id, pos, parent, opts]): return
	if parent == null or not is_instance_valid(parent) or not parent.is_inside_tree():
		_play(id, opts); return
	var st := stream(id)
	if st == null: _miss(id); return
	var vp := parent.get_viewport()
	if vp is SubViewport and not vp.audio_listener_enable_3d: vp.audio_listener_enable_3d = true
	var tune: Dictionary = TUNE.get(id, {})
	var p := AudioStreamPlayer3D.new()
	p.stream = st
	p.bus = String(opts.get("bus", tune.get("bus", "SFX")))
	p.volume_db = float(opts.get("db", 0.0)) + float(tune.get("db", 0.0))
	p.unit_size = float(opts.get("unit", 14.0))
	p.max_distance = float(opts.get("max_dist", 120.0))
	var pv: float = float(tune.get("pitch", 0.0))
	p.pitch_scale = 1.0 + randf_range(-pv, pv)
	parent.add_child(p)
	p.global_position = pos
	p.finished.connect(p.queue_free)
	# 끝 신호가 오지 않는 드라이버에서도 남지 않게
	var wr: WeakRef = weakref(p)
	get_tree().create_timer(st.get_length() / maxf(p.pitch_scale, 0.1) + 0.5, true, false, true).timeout.connect(
		func():
			var o = wr.get_ref()
			if o != null: o.queue_free())
	p.play()
	_say("sfx3d %s (%.0f, %.0f)" % [id, pos.x, pos.z])

func _stop_sfx() -> void:
	for v in _voices: v.p.stop()

func _miss(id: String) -> void:
	if _missing.has(id): return
	_missing[id] = true
	printerr("SOUND 없음 %s — assets/audio/sfx/%s.(ogg|wav)" % [id, id])

# ---- 음악 ----
func _music(id: String, fade: float) -> void:
	if _later(&"_music", [id, fade]): return
	if id == _bgm_id and (id == "" or _bgm[_bgm_cur].playing): return
	var rate := 1.0 / maxf(fade, 0.001)
	var old := _bgm_cur
	_bgm_to[old] = 0.0
	_bgm_rate[old] = rate
	if fade <= 0.0: _bgm_lv[old] = 0.0
	_bgm_id = id
	if id == "":
		_say("bgm stop")
		return
	var st := stream(id, "bgm")
	if st == null:
		_miss("bgm/" + id); _bgm_id = ""; return
	var n := 1 - old
	var p: AudioStreamPlayer = _bgm[n]
	p.stream = st
	p.play()
	_bgm_cur = n
	_bgm_lv[n] = 1.0 if fade <= 0.0 else 0.0
	_bgm_to[n] = 1.0
	_bgm_rate[n] = rate
	_say("bgm %s fade=%.1f" % [id, fade])

func _music_level(level: float, sec: float) -> void:
	_level_to = clampf(level, 0.0, 1.0)
	_level_rate = absf(_level_to - _level) / maxf(sec, 0.001)
	if sec <= 0.0: _level = _level_to

# ---- 잠시 낮춤 · 고요 ----
func _duck(db: float, hold: float, attack: float, release: float) -> void:
	_duck_floor = minf(db, 0.0) if _now() >= _duck_until else minf(_duck_floor, db)
	_duck_att = maxf(attack, 0.01)
	_duck_rel = maxf(release, 0.01)
	_duck_until = maxf(_duck_until, _now() + attack + maxf(hold, 0.0))
	_say("duck %.0fdB %.1fs" % [db, hold])

func _hush(hold: float, fade_out: float, fade_in: float, sfx_too: bool) -> void:
	_hush_out = maxf(fade_out, 0.01)
	_hush_in = maxf(fade_in, 0.01)
	_hush_sfx = sfx_too
	_hush_until = INF if hold < 0.0 else _now() + fade_out + hold
	_hush_on = true
	_say("hush %.1fs" % hold)

func _hush_end(fade_in: float) -> void:
	_hush_in = maxf(fade_in, 0.01)
	_hush_until = _now()

func _process(_delta: float) -> void:
	var t := Time.get_ticks_usec()
	var dt := clampf((t - _t_us) / 1000000.0, 0.0, 0.25)   # 실제 시간(Engine.time_scale·느린 화면과 상관없이)
	_t_us = t
	var now := _now()
	for i in _bgm.size():
		if _bgm_lv[i] != _bgm_to[i]:
			_bgm_lv[i] = move_toward(_bgm_lv[i], _bgm_to[i], _bgm_rate[i] * dt)
		if _bgm_lv[i] <= 0.0 and _bgm_to[i] <= 0.0 and _bgm[i].playing: _bgm[i].stop()
		_bgm[i].volume_db = _db(_bgm_lv[i])
	_level = move_toward(_level, _level_to, _level_rate * dt)
	var dt_to := _duck_floor if now < _duck_until else 0.0
	var drate := absf(_duck_floor) / (_duck_att if dt_to < _duck_db else _duck_rel)
	_duck_db = move_toward(_duck_db, dt_to, maxf(drate, 1.0) * dt)
	if _hush_on:
		var quiet := now < _hush_until
		_hush_lv = move_toward(_hush_lv, 0.0 if quiet else 1.0, dt / (_hush_out if quiet else _hush_in))
		if not quiet and _hush_lv >= 1.0: _hush_on = false; _hush_until = -1.0
	_apply_buses()

func _apply_buses() -> void:
	var lv := {
		"Master": vol_setting("vol_master"),
		"BGM": vol_setting("vol_bgm") * _level * _hush_lv * db_to_linear(_duck_db),
		"SFX": vol_setting("vol_sfx") * (_hush_lv if _hush_sfx else 1.0),
		"Ambient": vol_setting("vol_ambient") * _hush_lv,
	}
	for b in lv:
		var i := AudioServer.get_bus_index(b)
		if i >= 0: AudioServer.set_bus_volume_db(i, _db(float(lv[b])))

func _state() -> Dictionary:
	var playing := 0
	var ids := {}
	for v in _voices:
		if v.p.playing:
			playing += 1
			ids[v.id] = int(ids.get(v.id, 0)) + 1
	return { ready = is_inside_tree(), voices = _voices.size(), playing = playing, by_id = ids,
		bgm = _bgm_id, bgm_lv = _bgm_lv.duplicate(), bgm_cur = _bgm_cur, level = _level,
		duck_db = _duck_db, hush = _hush_lv,
		bus_bgm_db = AudioServer.get_bus_volume_db(AudioServer.get_bus_index("BGM")) if AudioServer.get_bus_index("BGM") >= 0 else 0.0 }
