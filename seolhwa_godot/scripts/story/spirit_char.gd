# 잔영(殘影) 그림 — SPIRIT_BASE(CHARACTER_MASTER §7: still/float · slow_walk · head_turn · flicker · appear · disappear).
# SpriteChar의 구운 프레임(정지 float · 느린 걸음 drift · 고개 돌림 head_turn)을 그대로 쓰되, 그리는 법만 바꾼다:
#   - 빛을 받지 않는 옅은 먹빛(밝은 곳은 한지빛, 먹선은 먹) — 밤에도 희끄무레하게 보인다.
#   - opacity(전체 진하기) · clarity(1 또렷 / 0 희미 — 얼룩지게 번짐) · dissolve(0 온전 → 1 흩어짐: appear/disappear).
#   - 발치로 갈수록 옅어진다(땅에 닿지 않는다). 테두리·그림자·가림 실루엣 없음.
# 깜빡임(flicker)·나타남·사라짐의 시간 흐름은 spirits.gd가 opacity·dissolve로 몬다.
extends SpriteChar

const SPIRIT_CODE := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, specular_disabled, fog_disabled;
uniform sampler2D page : source_color, filter_linear_mipmap;
uniform vec4 flash = vec4(1.0, 1.0, 1.0, 0.0);
uniform float opacity = 0.0;
uniform float clarity = 1.0;
uniform float dissolve = 0.0;
uniform float seed = 0.0;
uniform vec3 pale = vec3(0.78, 0.81, 0.85);
uniform vec3 ink = vec3(0.09, 0.10, 0.12);
varying float ly;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
void vertex() { ly = VERTEX.y; }
void fragment() {
	vec4 c = texture(page, UV);
	float lum = dot(c.rgb, vec3(0.3, 0.59, 0.11));
	vec2 q = vec2(UV.x * 40.0, ly * 6.0) + vec2(seed, -TIME * 0.4);
	float n = noise(q) * 0.65 + noise(q * 2.7) * 0.35;
	vec3 col = mix(ink, pale, smoothstep(0.12, 0.7, lum));
	float a = c.a * opacity;
	a *= mix(0.25 + 0.75 * n, 1.0, clarity);        // 희미할수록 얼룩져 번진다
	a *= smoothstep(0.05, 0.75, ly);                  // 발치는 비어 있다
	if (n < dissolve * 1.05) discard;                 // 흩어짐(나타남·사라짐)
	ALBEDO = mix(col, flash.rgb, flash.a);
	ALPHA = clamp(a, 0.0, 1.0);
}
"""

var opacity := 0.0
var clarity := 1.0
var dissolve := 1.0
var _smat: ShaderMaterial

func _ready() -> void:
	super._ready()
	_smat = ShaderMaterial.new()
	_smat.shader = SpriteChar._shader("spirit", SPIRIT_CODE)
	_smat.set_shader_parameter("seed", randf() * 100.0)
	_smat.set_shader_parameter("opacity", opacity)
	_smat.set_shader_parameter("clarity", clarity)
	_smat.set_shader_parameter("dissolve", dissolve)
	_mat = _smat                                  # SpriteChar._show_frame이 이 재질에 page를 꽂는다
	_halo.visible = false
	_blob.visible = false
	_billboard.get_node("silhouette").visible = false
	_sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func set_look(op: float, cl: float, dis: float) -> void:
	if not is_equal_approx(op, opacity): opacity = op; _smat.set_shader_parameter("opacity", op)
	if not is_equal_approx(cl, clarity): clarity = cl; _smat.set_shader_parameter("clarity", cl)
	if not is_equal_approx(dis, dissolve): dissolve = dis; _smat.set_shader_parameter("dissolve", dis)
