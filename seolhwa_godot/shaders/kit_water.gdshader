// 키트 'water' 키 물(못·연못·폭포 물막·빨래터 물 판) — water pass(2026-10-17).
// 예전에는 공용 반투명 재질(albedo_tex = 민화식 물결 줄 water.png)이었다. 이제 잔물결 법선 + 반사 + 프레넬 + 해 반짝임.
// 누운 면(못): 아주 잔잔한 물결·평면 반사(배치된 못은 region_world.add_static이 물 층으로 떼어 'water_refl' 재질을 준다).
// 선 면(폭포 물막): 아래로 흐르는 흰 물줄기 결. 버텍스 색 = 칠한 물빛(가운데 짙고 가장자리 옅게).
shader_type spatial;
render_mode cull_back, blend_mix, depth_draw_always;

#include "res://shaders/water_common.gdshaderinc"

global uniform vec3 hemi_sky;
global uniform vec3 hemi_ground;
global uniform float hemi_i;
global uniform vec3 fog_color;
global uniform float fog_density;
global uniform float fog_base;

uniform sampler2D ramp_tex : filter_linear, repeat_disable;
uniform vec4 albedo_color = vec4(0.457, 0.591, 0.578, 0.88);
uniform vec3 deep_col = vec3(0.05, 0.095, 0.085);

const vec2 POND_W = vec2(0.012, 0.16);   // WaterFX.POND

varying vec3 v_wp;
varying vec3 v_n;

void vertex() {
	v_wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_n = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float t = w_time();
	vec3 ng = normalize(v_n);
	float flat_k = smoothstep(0.6, 0.9, abs(ng.y));
	vec3 v = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
	float dist = length(VERTEX);
	// 칠한 물빛(버텍스 색)의 밝기 = 얕음: 밝은 가장자리는 바닥이 비치는 얕은 물
	float lum = dot(COLOR.rgb, vec3(0.3, 0.5, 0.2));
	float shallow = smoothstep(0.35, 0.8, lum);
	vec3 alb; vec3 emis; float a;
	if (flat_k > 0.5) {
		vec3 dt = w_detail(v_wp.xz, water_wind * t * 0.15, 1.2);
		vec3 wv = w_wave(v_wp.xz, t, POND_W.x * mix(1.0, water_k, 0.5), POND_W.y);
		vec2 slope = wv.yz + dt.xy * 0.13 * mix(0.3, 1.6, w_gust(v_wp.xz, t)) + w_rain(v_wp.xz, t);
		vec3 nw = normalize(vec3(-slope.x, 1.0, -slope.y));
		vec3 body = mix(deep_col, albedo_color.rgb * COLOR.rgb * 0.45, shallow * 0.7);
		float F = w_fresnel(nw, v) * refl_gain;
		vec3 refl = w_reflect(v_wp, nw, v, dist);
		alb = body * (1.0 - F);
		emis = refl * F;
		a = mix(0.95, 0.7, shallow);
		NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
	} else {
		// 폭포 물막: 위에서 아래로 빠르게 흐르는 흰 물줄기 결(잡음 — 그린 줄 아님)
		vec2 q = vec2(dot(v_wp.xz, normalize(vec2(-ng.z, ng.x) + 1e-5)) * 0.9, v_wp.y * 0.25 + t * 1.6);
		float h = texture(wnrm_tex, q).a * 0.6 + texture(wnrm_tex, q * vec2(2.1, 1.3) + 0.4).a * 0.4;
		float white = smoothstep(0.42, 0.62, h);
		alb = mix(albedo_color.rgb * COLOR.rgb, vec3(0.88, 0.91, 0.92), white * 0.8);
		emis = vec3(0.0);
		a = albedo_color.a * mix(0.55, 1.0, white);
	}
	ALBEDO = alb;
	ALPHA = a;
	vec3 hemi = mix(hemi_ground, hemi_sky, 0.85) * hemi_i;
	EMISSION = alb * hemi / PI + emis;
	float fog_d = -VERTEX.z;
	float fog_f = 1.0 - exp(-fog_density * fog_density * fog_d * fog_d);
	float fog_mist = fog_density * 24.0 * (1.0 - smoothstep(fog_base - 2.0, fog_base + 7.0, v_wp.y)) * smoothstep(14.0, 48.0, fog_d);
	fog_f = 1.0 - (1.0 - fog_f) * (1.0 - clamp(fog_mist, 0.0, 0.8));
	fog_f = aer_haze(fog_f, fog_d, v_wp.y, fog_base, fog_density);   // 공기원근(region_aer — water_common이 넣는다)
	FOG = vec4(fog_color, fog_f);
}

void light() {
	WATER_LIGHT
}
