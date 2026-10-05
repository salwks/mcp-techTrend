# 2D 프레임 캐릭터 — 웹 chars/Character.js의 'frames' 스타일 이식.
# 구워 둔 프레임 시트(페이지 PNG + frames.json)에서 지금 동작·시점의 그림 한 장을 사각형에 싣고,
# 카메라 쪽을 향하게 세운다(약간 뒤로 젖힘). 발밑 그림자 타원, 종이빛 테두리(halo), 가려지면 먹색 실루엣.
class_name SpriteChar
extends Node3D

const LEAN := deg_to_rad(8.0)
const DZ := 0.0006
const PAPER := Color("#f1e9d6")
const HALO_INK := Color("#1a1512")
const SIL_COLOR := Color("#1b2130")

static var _banks := {}      # kind → { pages:[ImageTexture], clips:{} }
static var _shaders := {}

var kind: String
var facing := "down"
var anim := "idle"
var anim_time := 0.0
var t := 0.0
var phase := randf()
var radius := 0.375
var height := 2.06
var move_speed := -1.0
var anim_speed := 1.0      # 동작 재생 배율(전투가 판정 길이에 맞춘다)
var armed := false         # 칼 든 대기·걷기(<동작>:a 클립이 있으면)
var variant := ""          # "disguised" → <동작>:d 클립 먼저(변장 호랑이)
var roll := 0.0            # 연출: 화면 안에서 그림을 돌린다(라디안, 그림 가운데 기준 — 남원 범이 뒤집혀 떨어질 때). 0이면 평소
var fx_scale := 1.0        # 연출: 그림 크기 배율(가운데 기준)
var accent = null          # 테두리 바깥 띠 색(Color) — 고을 사람과 같은 그림을 쓰는 이야기 인물(story_director). null이면 한지빛

var _bank: Dictionary
var _billboard: Node3D
var _sprite: MeshInstance3D
var _halo: MeshInstance3D
var _blob: MeshInstance3D
var _mesh: ArrayMesh
var _mat: ShaderMaterial
var _halo_mat: ShaderMaterial
var _sil_mat: ShaderMaterial
var _page := -1
var _frame: Dictionary = {}
var _mirror := false
var _last_pos := Vector3.INF
var _measured := 0.0

const STRIDE := { walk = 1.6987, run = 3.3641 }  # 웹 rigs.strideOf(player)

static func load_bank(kind: String, json_file: String) -> void:
	if _banks.has(kind): return
	var all: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/" + json_file))
	for k in all:
		if _banks.has(k): continue
		var pages := []
		for p in all[k].pages:
			var img := Image.load_from_file(ProjectSettings.globalize_path("res://data/" + p))
			img.generate_mipmaps()
			pages.append(ImageTexture.create_from_image(img))
		_banks[k] = { pages = pages, clips = all[k].clips }

# 이미 읽은 종류에 클립을 더한다(이야기용 추가 프레임 frames_story.json — 페이지 번호를 뒤로 민다). 없는 종류는 새로.
# only: 이 종류만(예: ["tiger"] — 절정 직전에 늦게 읽기). 같은 파일·종류는 한 번만 더한다.
static var _merged := {}
static func merge_bank(json_file: String, only: Array = []) -> void:
	var path := "res://data/" + json_file
	if not FileAccess.file_exists(path): return
	var all = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (all is Dictionary): return
	for k in all:
		if not only.is_empty() and not only.has(k): continue
		if _merged.has(json_file + "|" + k): continue
		_merged[json_file + "|" + k] = true
		var pages := []
		for p in all[k].pages:
			var img := Image.load_from_file(ProjectSettings.globalize_path("res://data/" + p))
			if img == null or img.is_empty(): continue
			img.generate_mipmaps()
			pages.append(ImageTexture.create_from_image(img))
		if not _banks.has(k):
			_banks[k] = { pages = pages, clips = all[k].clips }
			continue
		var bank: Dictionary = _banks[k]
		var off: int = bank.pages.size()
		bank.pages.append_array(pages)
		for ck in all[k].clips:
			var c: Dictionary = all[k].clips[ck]
			for f in c.frames: f.page = int(f.page) + off
			bank.clips[ck] = c

static func _shader(name: String, code: String) -> Shader:
	if not _shaders.has(name):
		var s := Shader.new(); s.code = code; _shaders[name] = s
	return _shaders[name]

const LIT_COMMON := """
global uniform vec3 hemi_sky;
global uniform vec3 hemi_ground;
global uniform float hemi_i;
global uniform vec3 fog_color;
global uniform float fog_density;
global uniform float fog_base;
global uniform float wet;
"""
const FOG := """
	float fog_d = -VERTEX.z;
	vec3 fog_wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float fog_f = 1.0 - exp(-fog_density * fog_density * fog_d * fog_d);
	float fog_mist = fog_density * 24.0 * (1.0 - smoothstep(fog_base - 2.0, fog_base + 7.0, fog_wp.y)) * smoothstep(14.0, 48.0, fog_d);
	fog_f = 1.0 - (1.0 - fog_f) * (1.0 - clamp(fog_mist, 0.0, 0.8));
	FOG = vec4(fog_color, fog_f);
"""
# 본 그림: MeshLambertMaterial + alphaTest 0.5, 좌우 반전돼도 법선을 뒤집지 않는다(NORMAL_FIX)
const SPRITE_CODE := "shader_type spatial;\nrender_mode cull_disabled, specular_disabled, depth_prepass_alpha;\n" + LIT_COMMON + """
uniform sampler2D page : source_color, filter_linear_mipmap;
uniform vec4 flash = vec4(1.0, 1.0, 1.0, 0.0);
void fragment() {
	vec4 c = texture(page, UV);
	if (!FRONT_FACING) NORMAL = -NORMAL;
	c.rgb *= 1.0 - 0.12 * wet; // 비에 젖은 옷(권역 날씨, 기본 0)
	c.rgb = mix(c.rgb, flash.rgb, flash.a);
	ALBEDO = c.rgb;
	ALPHA = c.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	vec3 wn = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	EMISSION = c.rgb * mix(hemi_ground, hemi_sky, 0.5 * wn.y + 0.5) * hemi_i / PI;
""" + FOG + """}
void light() {
	DIFFUSE_LIGHT += max(dot(NORMAL, LIGHT), 0.0) * ATTENUATION * LIGHT_COLOR / (PI * PI);
}
"""
# 테두리: 알파를 두 반경으로 팽창 — 안쪽 띠는 먹, 바깥 띠는 한지빛(발광 0.3)
const HALO_CODE := "shader_type spatial;\nrender_mode cull_disabled, specular_disabled;\n" + LIT_COMMON + """
uniform sampler2D page : source_color, filter_linear;
uniform vec2 texel;
uniform vec3 paper;
uniform vec3 ink;
void fragment() {
	vec2 px = fwidth(UV);
	vec2 r1 = max(texel * 1.6, px * 0.9), r2 = max(texel * 3.6, px * 1.9);
	float a1 = 0.0, a2 = 0.0;
	for (int i = 0; i < 8; i++) {
		float ang = float(i) * 0.7853982;
		vec2 d = vec2(cos(ang), sin(ang));
		a1 = max(a1, texture(page, UV + d * r1).a);
		a2 = max(a2, texture(page, UV + d * r2).a);
	}
	float hink = step(0.5, a1);
	if (!FRONT_FACING) NORMAL = -NORMAL;
	vec3 base = mix(paper, ink, hink);
	ALBEDO = base;
	ALPHA = max(a1, a2);
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	vec3 wn = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	EMISSION = base * mix(hemi_ground, hemi_sky, 0.5 * wn.y + 0.5) * hemi_i / PI + paper * 0.3 * (1.0 - hink);
""" + FOG + """}
void light() {
	DIFFUSE_LIGHT += max(dot(NORMAL, LIGHT), 0.0) * ATTENUATION * LIGHT_COLOR / (PI * PI);
}
"""
# 실루엣: 가려진 곳에서만(깊이 반전) 먹색 반투명
const SIL_CODE := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_inverted, depth_draw_never, blend_mix, fog_disabled;
uniform sampler2D page : filter_linear;
uniform vec3 color;
void fragment() {
	float a = texture(page, UV).a;
	if (a < 0.2) discard;
	ALBEDO = color;
	ALPHA = 0.42;
}
"""
const BLOB_CODE := """shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, blend_mix, fog_disabled;
uniform float opacity = 0.5;
void fragment() {
	float r = length(UV - 0.5) * 2.0;
	float a = smoothstep(1.0, 0.25, r);
	ALBEDO = vec3(0.0232, 0.0144, 0.0091);
	ALPHA = a * opacity;
}
"""

func _init(k: String) -> void:
	kind = k
	name = "char_" + k
	_bank = _banks.get(k, {})
	if k == "tiger": radius = 0.9

func _ready() -> void:
	_billboard = Node3D.new()
	add_child(_billboard)
	_mesh = ArrayMesh.new()
	_mat = ShaderMaterial.new(); _mat.shader = _shader("sprite", SPRITE_CODE)
	_halo_mat = ShaderMaterial.new(); _halo_mat.shader = _shader("halo", HALO_CODE)
	_halo_mat.set_shader_parameter("paper", _lin(accent if accent != null else PAPER)); _halo_mat.set_shader_parameter("ink", _lin(HALO_INK))
	_sil_mat = ShaderMaterial.new(); _sil_mat.shader = _shader("sil", SIL_CODE)
	_sil_mat.set_shader_parameter("color", Vector3(SIL_COLOR.r, SIL_COLOR.g, SIL_COLOR.b))
	_sil_mat.render_priority = 10
	_sprite = MeshInstance3D.new(); _sprite.mesh = _mesh
	_halo = MeshInstance3D.new(); _halo.mesh = _mesh
	_halo.position.z = -1.5 * DZ
	_halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_billboard.add_child(_halo)
	_billboard.add_child(_sprite)
	var sil := MeshInstance3D.new(); sil.mesh = _mesh; sil.position.z = 0.02
	sil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sil.material_override = _sil_mat
	sil.name = "silhouette"
	_billboard.add_child(sil)
	_blob = MeshInstance3D.new()
	var q := PlaneMesh.new(); q.size = Vector2.ONE
	_blob.mesh = q
	var bm := ShaderMaterial.new(); bm.shader = _shader("blob", BLOB_CODE)
	_blob.material_override = bm
	_blob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_blob.position.y = 0.025
	_blob.scale = Vector3(0.9, 1, 0.506) if kind != "tiger" else Vector3(2.0, 1, 0.9)
	add_child(_blob)

static func _lin(c: Color) -> Vector3:
	var l := c.srgb_to_linear(); return Vector3(l.r, l.g, l.b)

func set_facing(dir: String) -> void: facing = dir

func set_anim(a: String) -> void:
	if a == anim: return
	anim = a; anim_time = 0.0; anim_speed = 1.0

# 전투·이야기용: 같은 동작이어도 restart면 처음부터, speed는 재생 배율
func play(a: String, restart := false, speed := 1.0) -> void:
	if a != anim or restart: anim_time = 0.0
	anim = a; anim_speed = speed

# 지금 시점에서 이 동작 클립의 길이(초). 없으면 0
func anim_duration(a: String) -> float:
	var clip = _clip(_view_of()[0], a)
	if clip == null: return 0.0
	var sp: Dictionary = clip.spec
	if sp.has("dur"): return float(sp.dur)
	var T: Array = sp.get("times", [])
	return float(T[T.size() - 1]) if T.size() > 0 else 0.0

func has_anim(a: String) -> bool:
	var clips: Dictionary = _bank.get("clips", {})
	for v in ["front", "side", "back"]:
		if clips.has("%s|%s" % [v, a]): return true
	return false

# 피격 번쩍임(색, 밀리초)
var _flash_t := 0.0
var _flash_dur := 0.0
var _flash_c := Color.WHITE
func flash(c: Color, ms: float) -> void:
	_flash_t = ms / 1000.0; _flash_dur = _flash_t; _flash_c = c
	if _mat: _mat.set_shader_parameter("flash", Color(c.r, c.g, c.b, 0.85))

func set_accent(c) -> void:
	accent = c
	if _halo_mat: _halo_mat.set_shader_parameter("paper", _lin(c if c != null else PAPER))

func set_silhouette(on: bool) -> void:
	_billboard.get_node("silhouette").visible = on

func _view_of() -> Array:
	match facing:
		"up": return ["back", false]
		"left": return ["side", false]
		"right": return ["side", true]
	return ["front", false]

func _clip(view: String, a: String) -> Variant:
	var clips: Dictionary = _bank.get("clips", {})
	var keys := []
	if variant == "disguised": keys.append_array(["%s|%s:d" % [view, a], "side|%s:d" % a])
	if armed: keys.append_array(["%s|%s:a" % [view, a], "side|%s:a" % a])
	keys.append_array(["%s|%s" % [view, a], "side|%s" % a, "%s|idle" % view, "front|idle"])
	for key in keys:
		if clips.has(key): return clips[key]
	return null

# 웹 frameCore.frameIndex
static func frame_index(spec: Dictionary, at: float, ph: float, tt: float) -> int:
	var T: Array = spec.times
	if spec.kind == "phase":
		return int(floor(fposmod(ph, 1.0) * spec.n)) % int(spec.n)
	if spec.kind == "loop":
		var tb: bool = spec.get("tBased", false)
		var x := tt if tb else at
		if not tb and x < spec.intro:
			var i := 0
			while i + 1 < int(spec.loopStart) and T[i + 1] <= x: i += 1
			return i
		var lt: float = x if tb else x - spec.intro
		return int(spec.loopStart) + posmod(int(floor(lt / spec.step)), int(spec.n))
	var j := 0
	while j + 1 < T.size() and T[j + 1] <= at + 1e-6: j += 1
	return j

func update_char(dt: float, cam: Camera3D) -> void:
	t += dt
	anim_time += dt * anim_speed
	if _flash_t > 0.0:
		_flash_t -= dt
		if _mat: _mat.set_shader_parameter("flash", Color(_flash_c.r, _flash_c.g, _flash_c.b, 0.85 * maxf(0.0, _flash_t / maxf(_flash_dur, 0.001))))
		if _flash_t <= 0.0 and _mat: _mat.set_shader_parameter("flash", Color(1, 1, 1, 0))
	# 걸음 위상: 실제 이동 속도 기준(웹 _advancePhase)
	if _last_pos != Vector3.INF and dt > 0.0:
		var v := Vector2(position.x - _last_pos.x, position.z - _last_pos.z).length() / dt
		_measured += (v - _measured) * minf(1.0, dt * 10.0)
	_last_pos = position
	if anim == "walk" or anim == "run":
		var def := 4.6 if anim == "run" else 2.2
		var sp := move_speed if move_speed >= 0.0 else (_measured if _measured > 0.3 else def)
		sp = maxf(sp, def * 0.35)
		phase += dt * sp / STRIDE[anim]
	# 카메라 쪽을 향해 세우고 살짝 뒤로 젖힘
	var fwd := -cam.global_transform.basis.z
	if absf(fwd.x) + absf(fwd.z) > 1e-4:
		var yaw := atan2(-fwd.x, -fwd.z)
		_billboard.rotation = Vector3(-LEAN, yaw, 0)
		_billboard.rotation_order = EULER_ORDER_YXZ
	_show_frame()
	if roll != 0.0 or fx_scale != 1.0 or _billboard.position != Vector3.ZERO:
		var b := Basis.from_euler(Vector3(-LEAN, _billboard.rotation.y, roll), EULER_ORDER_YXZ).scaled_local(Vector3.ONE * fx_scale)
		var pv := Vector3(0, (float(_frame.get("y0", 0.0)) + float(_frame.get("y1", 0.0))) * 0.5, 0)
		var b0 := Basis.from_euler(Vector3(-LEAN, _billboard.rotation.y, 0), EULER_ORDER_YXZ)
		_billboard.transform = Transform3D(b, b0 * pv - b * pv)   # 그림 가운데가 제자리에 남게

func _show_frame() -> void:
	var vm := _view_of()
	var clip = _clip(vm[0], anim)
	if clip == null: return
	var frames: Array = clip.frames
	var f: Dictionary = frames[clamp(frame_index(clip.spec, anim_time, phase, t), 0, frames.size() - 1)]
	var mirror: bool = vm[1]
	if int(f.page) != _page:
		_page = int(f.page)
		var tex: Texture2D = _bank.pages[_page]
		_mat.set_shader_parameter("page", tex)
		_halo_mat.set_shader_parameter("page", tex)
		_halo_mat.set_shader_parameter("texel", Vector2(1.0 / tex.get_width(), 1.0 / tex.get_height()))
		_sil_mat.set_shader_parameter("page", tex)
	if f == _frame and mirror == _mirror: return
	_frame = f; _mirror = mirror
	var sg := -1.0 if mirror else 1.0
	var v := PackedVector3Array([
		Vector3(sg * f.x0, f.y1, 0), Vector3(sg * f.x1, f.y1, 0), Vector3(sg * f.x0, f.y0, 0), Vector3(sg * f.x1, f.y0, 0)])
	var uv := PackedVector2Array([Vector2(f.u0, f.v0), Vector2(f.u1, f.v0), Vector2(f.u0, f.v1), Vector2(f.u1, f.v1)])
	var n := PackedVector3Array([Vector3.BACK, Vector3.BACK, Vector3.BACK, Vector3.BACK])
	# 앞면(카메라 쪽 +z)이 보이도록: Godot은 시계 방향이 앞면
	var idx := PackedInt32Array([0, 1, 2, 2, 1, 3]) if not mirror else PackedInt32Array([0, 2, 1, 2, 3, 1])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v; arr[Mesh.ARRAY_TEX_UV] = uv; arr[Mesh.ARRAY_NORMAL] = n; arr[Mesh.ARRAY_INDEX] = idx
	_mesh.clear_surfaces()
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	_mesh.surface_set_material(0, null)
	_sprite.material_override = _mat
	_halo.material_override = _halo_mat
	var lift: float = f.get("lift", 0.0)
	var kk := maxf(0.45, 1.0 - lift * 0.9)
	(_blob.material_override as ShaderMaterial).set_shader_parameter("opacity", 0.5 * (0.5 + 0.5 * kk))
