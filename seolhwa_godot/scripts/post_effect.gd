# 후처리 — 웹 fx/post.js 이식(컴포지터 효과 + compute 셰이더).
#   장면(HDR, 투명 물체까지 그린 뒤) → 틸트시프트 흐림(1/2, 가로→세로) → 블룸(1/4, 밝은 부분→가로→세로)
#   → 최종 1패스: 선명/흐림 섞기 + 먹선 + 블룸 + 톤매핑(Neutral) + sRGB + 색보정 + 한지 + 비네트 + 디더
# 최종 결과(sRGB)는 선형으로 되돌려 장면 버퍼에 쓴다. 이어지는 Godot 출력 단계(톤매퍼 Linear → sRGB)가 그대로 되돌린다.
# SubViewport를 패스마다 이어 붙이는 방식은 이 맥(Metal/Vulkan 모두)에서 패스당 수 ms가 들어 이 방식을 쓴다.
@tool
class_name PostEffect
extends CompositorEffect

var tilt := true
var bloom := true
var paper := true
var focus_y := 0.45
var band := 0.07        # 틸트시프트 선명 띠 반폭(화면 높이 비율). 배 위 낮은 시점에서는 넓힌다(region_main)
var top_bias := 1.0     # 띠 위쪽 흐림 세기(배 위: 먼 기슭·능선이 덜 흐리게)
var paper_ratio := 2.0
var state := {}
var paper_image: Image
# Mobile 렌더러는 장면 버퍼에 밝기를 1/2로 저장한다(0~2 범위를 10비트에 담기 위해). 읽을 때 곱하고 쓸 때 나눈다.
var lum_mult := 1.0

var rd: RenderingDevice
var _fmt := -1
var _shaders := {}
var _pipes := {}
var _size := Vector2i.ZERO
var _tex := {}
var _lin: RID
var _rep: RID
var _paper_tex: RID

const COMMON := """
#version 450
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
"""
const BLUR := """
layout(set = 0, binding = 0) uniform sampler2D src;
layout(%FMT%, set = 0, binding = 1) uniform restrict writeonly image2D dst;
layout(push_constant, std430) uniform P { vec2 step; vec2 inv_size; } p;
void main() {
	ivec2 g = ivec2(gl_GlobalInvocationID.xy);
	if (any(greaterThanEqual(g, imageSize(dst)))) return;
	vec2 uv = (vec2(g) + 0.5) * p.inv_size;
	vec3 c = textureLod(src, uv, 0.0).rgb * 0.227027;
	c += (textureLod(src, uv + p.step * 1.0, 0.0).rgb + textureLod(src, uv - p.step * 1.0, 0.0).rgb) * 0.1945946;
	c += (textureLod(src, uv + p.step * 2.0, 0.0).rgb + textureLod(src, uv - p.step * 2.0, 0.0).rgb) * 0.1216216;
	c += (textureLod(src, uv + p.step * 3.0, 0.0).rgb + textureLod(src, uv - p.step * 3.0, 0.0).rgb) * 0.054054;
	c += (textureLod(src, uv + p.step * 4.0, 0.0).rgb + textureLod(src, uv - p.step * 4.0, 0.0).rgb) * 0.016216;
	imageStore(dst, g, vec4(c, 1.0));
}
"""
const BRIGHT := """
layout(set = 0, binding = 0) uniform sampler2D src;
layout(%FMT%, set = 0, binding = 1) uniform restrict writeonly image2D dst;
layout(push_constant, std430) uniform P { vec2 texel; vec2 inv_size; float threshold; float lum; float pad1; float pad2; } p;
vec3 pick(vec2 uv, vec2 o) {
	vec3 c = min(textureLod(src, uv + o * p.texel, 0.0).rgb * p.lum, vec3(8.0));
	float l = max(c.r, max(c.g, c.b));
	float k = clamp((l - p.threshold) / 0.25, 0.0, 1.0);
	return c * k * k * max(l - p.threshold * 0.7, 0.0) / max(l, 1e-4);
}
void main() {
	ivec2 g = ivec2(gl_GlobalInvocationID.xy);
	if (any(greaterThanEqual(g, imageSize(dst)))) return;
	vec2 uv = (vec2(g) + 0.5) * p.inv_size;
	vec3 c = pick(uv, vec2(-1.0, -1.0)) + pick(uv, vec2(1.0, -1.0)) + pick(uv, vec2(-1.0, 1.0)) + pick(uv, vec2(1.0, 1.0));
	imageStore(dst, g, vec4(c * 0.25 / p.lum, 1.0));
}
"""
const FINAL := """
layout(set = 0, binding = 0) uniform sampler2D t_scene;
layout(set = 0, binding = 1) uniform sampler2D t_blur;
layout(set = 0, binding = 2) uniform sampler2D t_bloom;
layout(set = 0, binding = 3) uniform sampler2D t_paper;
layout(%FMT%, set = 0, binding = 4) uniform restrict writeonly image2D dst;
layout(push_constant, std430) uniform P {
	vec2 texel; vec2 paper_scale;
	float aspect; float focus_y; float band; float lum;
	float top_bias; float bottom_bias; float tilt; float bloom;
	float sat; float paper; float ink; float night;
	vec4 lift; vec4 gamma; vec4 gain;
} p;
const vec3 TINT = vec3(1.0, 0.985, 0.955);
float luma(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }
vec3 neutral_tm(vec3 color) {
	const float S = 0.76; const float D = 0.15;
	float x = min(color.r, min(color.g, color.b));
	float offset = x < 0.08 ? x - 6.25 * x * x : 0.04;
	color -= offset;
	float peak = max(color.r, max(color.g, color.b));
	if (peak < S) return color;
	float d = 1.0 - S;
	float np = 1.0 - d * d / (peak + d - S);
	color *= np / peak;
	float g = 1.0 - 1.0 / (D * (peak - np) + 1.0);
	return mix(color, vec3(np), g);
}
vec3 to_srgb(vec3 c) {
	c = max(c, vec3(0.0));
	return mix(pow(c, vec3(0.41666)) * 1.055 - 0.055, c * 12.92, vec3(lessThanEqual(c, vec3(0.0031308))));
}
vec3 to_linear(vec3 c) {
	c = max(c, vec3(0.0));
	return mix(pow((c + 0.055) / 1.055, vec3(2.4)), c / 12.92, vec3(lessThanEqual(c, vec3(0.04045))));
}
void main() {
	ivec2 g = ivec2(gl_GlobalInvocationID.xy);
	ivec2 sz = imageSize(dst);
	if (any(greaterThanEqual(g, sz))) return;
	vec2 uv = (vec2(g) + 0.5) / vec2(sz);
	float vy = 1.0 - uv.y;
	vec3 c = textureLod(t_scene, uv, 0.0).rgb * p.lum;
	float amt = 0.0;
	if (p.tilt > 0.5) {
		float dy = vy - p.focus_y;
		amt = smoothstep(0.0, 0.32, abs(dy) - p.band) * (dy > 0.0 ? p.top_bias : p.bottom_bias);
		c = mix(c, textureLod(t_blur, uv, 0.0).rgb * p.lum, amt);
	}
	if (p.ink > 0.0 && amt < 0.6) {
		float l = sqrt(luma(textureLod(t_scene, uv - vec2(p.texel.x, 0.0), 0.0).rgb * p.lum));
		float r = sqrt(luma(textureLod(t_scene, uv + vec2(p.texel.x, 0.0), 0.0).rgb * p.lum));
		float d = sqrt(luma(textureLod(t_scene, uv + vec2(0.0, p.texel.y), 0.0).rgb * p.lum));
		float u = sqrt(luma(textureLod(t_scene, uv - vec2(0.0, p.texel.y), 0.0).rgb * p.lum));
		float e = length(vec2(r - l, u - d));
		c *= 1.0 - p.ink * 0.35 * smoothstep(0.06, 0.28, e) * (1.0 - amt / 0.6);
	}
	if (p.bloom > 0.0) c += textureLod(t_bloom, uv, 0.0).rgb * p.lum * p.bloom;
	c = to_srgb(neutral_tm(c));
	c = p.gain.rgb * (c + p.lift.rgb * (1.0 - c));
	c = pow(max(c, vec3(0.0)), 1.0 / p.gamma.rgb);
	float L = luma(c);
	c = mix(vec3(L), c, p.sat);
	float sh = (1.0 - L) * (1.0 - L);
	c *= mix(vec3(1.0), vec3(0.93, 0.97, 1.07), sh * 0.6);
	c *= mix(vec3(1.0), vec3(1.03, 1.0, 0.96), smoothstep(0.5, 1.0, L) * 0.5);
	vec3 pp = textureLod(t_paper, (vec2(g) + 0.5) * p.paper_scale, 0.0).rgb;
	c = mix(c, c * TINT, p.paper * 0.6);
	c *= 1.0 + p.paper * ((pp.r - 0.5) * (0.16 + 0.12 * L) + (pp.g - 0.5) * 0.08);
	c = mix(c, TINT * 0.97, p.paper * 0.1 * smoothstep(0.75, 1.0, L));
	vec2 q = (vec2(uv.x, vy) - 0.5) * vec2(p.aspect, 1.0);
	float v = smoothstep(0.35 + 0.5 * p.aspect, 0.25, length(q) * 0.9);
	vec3 vc = mix(vec3(0.16, 0.12, 0.09), vec3(0.05, 0.06, 0.1), p.night);
	c = mix(c, c * vc * 2.2, (1.0 - v) * p.paper * 0.55);
	c += (pp.b - 0.5) * (1.5 / 255.0);
	imageStore(dst, g, vec4(to_linear(clamp(c, 0.0, 1.0)) / p.lum, 1.0));
}
"""

func _init() -> void:
	effect_callback_type = EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
	access_resolved_color = true
	rd = RenderingServer.get_rendering_device()

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and rd:
		for r in _tex.values() + _shaders.values() + [_lin, _rep, _paper_tex]:
			if r.is_valid(): rd.free_rid(r)

static func _fmt_name(f: int) -> String:
	match f:
		RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT: return "rgba16f"
		RenderingDevice.DATA_FORMAT_A2B10G10R10_UNORM_PACK32: return "rgb10_a2"
		RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT: return "rgba32f"
		RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM: return "rgba8"
	return "rgba16f"

func _build(fmt: int) -> void:
	_fmt = fmt
	print("POST color format ", fmt, " ", _fmt_name(fmt), " lum_mult=", lum_mult)
	var fname := _fmt_name(fmt)
	var srcs := { blur = BLUR, bright = BRIGHT, final = FINAL }
	for k in srcs:
		var src := RDShaderSource.new()
		src.language = RenderingDevice.SHADER_LANGUAGE_GLSL
		src.source_compute = COMMON + (srcs[k] as String).replace("%FMT%", fname)
		var spirv := rd.shader_compile_spirv_from_source(src)
		if spirv.compile_error_compute != "":
			push_error("post %s: %s" % [k, spirv.compile_error_compute]); return
		_shaders[k] = rd.shader_create_from_spirv(spirv)
		_pipes[k] = rd.compute_pipeline_create(_shaders[k])
	var ss := RDSamplerState.new()
	ss.min_filter = RenderingDevice.SAMPLER_FILTER_LINEAR; ss.mag_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	ss.repeat_u = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE; ss.repeat_v = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	_lin = rd.sampler_create(ss)
	ss.repeat_u = RenderingDevice.SAMPLER_REPEAT_MODE_REPEAT; ss.repeat_v = RenderingDevice.SAMPLER_REPEAT_MODE_REPEAT
	_rep = rd.sampler_create(ss)
	if paper_image:
		var img := paper_image.duplicate()
		img.convert(Image.FORMAT_RGBA8)
		var tf := RDTextureFormat.new()
		tf.width = img.get_width(); tf.height = img.get_height()
		tf.format = RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM
		tf.usage_bits = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT
		_paper_tex = rd.texture_create(tf, RDTextureView.new(), [img.get_data()])

func _free_textures() -> void:
	for k in _tex: if _tex[k].is_valid(): rd.free_rid(_tex[k])
	_tex.clear()

func _mk(w: int, h: int) -> RID:
	var tf := RDTextureFormat.new()
	tf.width = maxi(1, w); tf.height = maxi(1, h)
	tf.format = _fmt
	tf.usage_bits = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_TO_BIT
	return rd.texture_create(tf, RDTextureView.new())

func _ensure(size: Vector2i) -> void:
	if size == _size and not _tex.is_empty(): return
	_free_textures()
	_size = size
	var half := Vector2i(ceili(size.x / 2.0), ceili(size.y / 2.0))
	var quarter := Vector2i(ceili(size.x / 4.0), ceili(size.y / 4.0))
	_tex.ha = _mk(half.x, half.y); _tex.hb = _mk(half.x, half.y)
	_tex.qa = _mk(quarter.x, quarter.y); _tex.qb = _mk(quarter.x, quarter.y)
	_tex.out = _mk(size.x, size.y)

func _samp(binding: int, tex: RID, sampler := RID()) -> RDUniform:
	var u := RDUniform.new()
	u.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	u.binding = binding
	u.add_id(_lin if not sampler.is_valid() else sampler); u.add_id(tex)
	return u

func _img(binding: int, tex: RID) -> RDUniform:
	var u := RDUniform.new()
	u.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	u.binding = binding
	u.add_id(tex)
	return u

func _dispatch(pipe: String, uniforms: Array, push: PackedFloat32Array, size: Vector2i) -> void:
	var set := UniformSetCacheRD.get_cache(_shaders[pipe], 0, uniforms)
	var bytes := push.to_byte_array()
	var cl := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(cl, _pipes[pipe])
	rd.compute_list_bind_uniform_set(cl, set, 0)
	rd.compute_list_set_push_constant(cl, bytes, bytes.size())
	rd.compute_list_dispatch(cl, ceili(size.x / 8.0), ceili(size.y / 8.0), 1)
	rd.compute_list_end()

func _render_callback(_type: int, render_data: RenderData) -> void:
	if state.is_empty(): return
	var sb := render_data.get_render_scene_buffers() as RenderSceneBuffersRD
	if sb == null: return
	var size := sb.get_internal_size()
	if size.x == 0: return
	var color := sb.get_color_layer(0)
	var fmt := rd.texture_get_format(color).format
	if fmt != _fmt:
		_free_textures(); _build(fmt)
	if not _pipes.has("final"): return
	_ensure(size)
	var half := Vector2i(ceili(size.x / 2.0), ceili(size.y / 2.0))
	var quarter := Vector2i(ceili(size.x / 4.0), ceili(size.y / 4.0))
	if tilt:
		var sigma := size.y * 0.0042
		var st := (sigma / 2.0) * 0.75
		_dispatch("blur", [_samp(0, color), _img(1, _tex.ha)], PackedFloat32Array([st / half.x, 0, 1.0 / half.x, 1.0 / half.y]), half)
		_dispatch("blur", [_samp(0, _tex.ha), _img(1, _tex.hb)], PackedFloat32Array([0, st / half.y, 1.0 / half.x, 1.0 / half.y]), half)
	var bloom_k: float = state.bloom * 0.45 if bloom else 0.0
	if bloom_k > 0.001:
		_dispatch("bright", [_samp(0, color), _img(1, _tex.qa)], PackedFloat32Array([1.0 / size.x, 1.0 / size.y, 1.0 / quarter.x, 1.0 / quarter.y, state.thr, lum_mult, 0, 0]), quarter)
		_dispatch("blur", [_samp(0, _tex.qa), _img(1, _tex.qb)], PackedFloat32Array([1.5 / quarter.x, 0, 1.0 / quarter.x, 1.0 / quarter.y]), quarter)
		_dispatch("blur", [_samp(0, _tex.qb), _img(1, _tex.qa)], PackedFloat32Array([0, 1.5 / quarter.y, 1.0 / quarter.x, 1.0 / quarter.y]), quarter)
	var ps := 1.0 / (512.0 * maxf(1.0, paper_ratio * 0.75))
	var pf := 1.0 if paper else 0.0
	var lift: Vector3 = state.lift; var gam: Vector3 = state.gamma; var gain: Vector3 = state.gain
	var push := PackedFloat32Array([
		1.0 / size.x, 1.0 / size.y, ps, ps,
		float(size.x) / size.y, focus_y, band, lum_mult,
		top_bias, 0.75, 1.0 if tilt else 0.0, bloom_k,
		state.sat, pf, pf, state.night,
		lift.x, lift.y, lift.z, 0, gam.x, gam.y, gam.z, 0, gain.x, gain.y, gain.z, 0])
	var paper_rid: RID = _paper_tex if _paper_tex.is_valid() else _tex.hb
	_dispatch("final", [_samp(0, color), _samp(1, _tex.hb), _samp(2, _tex.qa), _samp(3, paper_rid, _rep), _img(4, _tex.out)], push, size)
	rd.texture_copy(_tex.out, color, Vector3.ZERO, Vector3.ZERO, Vector3(size.x, size.y, 1), 0, 0, 0, 0)
