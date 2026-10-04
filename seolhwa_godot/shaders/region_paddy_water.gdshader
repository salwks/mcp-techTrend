// 논물(scripts/region/farm.gd): 얕은 고인 물 — 하늘빛 반사(위에서 볼수록 진흙이 비침), 하천 물(region_water)과 같은 물결 텍스처를 아주 느리게.
// COLOR.r = 풀빛(모 자란 논은 푸르스름), COLOR.g = 흐림(갓 갈아 물 댄 논은 흙탕)
shader_type spatial;
render_mode specular_disabled, cull_back, blend_mix, depth_draw_opaque;

global uniform vec3 hemi_sky;
global uniform vec3 hemi_ground;
global uniform float hemi_i;
global uniform vec3 fog_color;
global uniform float fog_density;
global uniform float wet;

uniform sampler2D water_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform float mist_base = 0.0;

varying vec3 v_wp;
varying vec3 v_c;

void vertex() {
	v_wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_c = COLOR.rgb;
}

void fragment() {
	vec2 p = v_wp.xz;
	float t = TIME * (0.006 + wet * 0.02);
	vec3 w1 = texture(water_tex, p / 9.0 + vec2(t, t * 0.7)).rgb;
	vec3 w2 = texture(water_tex, p / 5.3 - vec2(t * 0.8, -t * 0.5) + 0.37).rgb;
	float rip = dot(w1 + w2, vec3(0.1666));
	float n = texture(noise_tex, p * 0.031).r;
	vec3 mud = mix(vec3(0.115, 0.098, 0.068), vec3(0.17, 0.15, 0.10), n);
	vec3 green = vec3(0.12, 0.16, 0.085);
	vec3 deep = mix(vec3(0.30, 0.40, 0.40), mud * 1.6, v_c.g);
	deep = mix(deep, green * 1.6, v_c.r * 0.55);
	vec3 vdir = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
	float fres = 0.28 + 0.72 * pow(1.0 - clamp(vdir.y, 0.0, 1.0), 2.0);
	vec3 sky = mix(hemi_sky, fog_color, 0.35);
	vec3 base = deep * (0.75 + 0.5 * rip);
	ALBEDO = base * 0.5;
	ALPHA = clamp(0.38 + fres * 0.45 + v_c.g * 0.25, 0.0, 0.9);
	vec3 hemi = mix(hemi_ground, hemi_sky, 0.85) * hemi_i;
	// 툰: 반사 하늘빛은 두 단으로 끊어 그린다(민화 물빛) — 얕은 논물은 하늘을 거울처럼
	float band = smoothstep(0.45, 0.52, fres + (rip - 0.5) * 0.35);
	// 필지마다 물빛이 조금씩 다르게(COLOR.b = 필지 난수) + 비친 구름(큰 잡음 띠, 아주 느리게 흐름)
	float pv = v_c.b;
	vec3 sk = sky * mix(vec3(0.92, 0.98, 1.06), vec3(1.04, 1.02, 0.94), pv);
	float cloud = smoothstep(0.56, 0.66, texture(noise_tex, p * 0.012 + vec2(TIME * 0.0015, 0.0)).r);
	EMISSION = ALBEDO * hemi / PI + sk * hemi_i * (mix(0.28, 0.46, band) * (0.55 + fres) * (0.88 + 0.24 * pv) + cloud * 0.12);
	float fog_d = -VERTEX.z;
	float fog_f = 1.0 - exp(-fog_density * fog_density * fog_d * fog_d);
	float fog_mist = fog_density * 24.0 * (1.0 - smoothstep(-2.0, 7.0, v_wp.y - mist_base)) * smoothstep(14.0, 48.0, fog_d);
	fog_f = 1.0 - (1.0 - fog_f) * (1.0 - clamp(fog_mist, 0.0, 0.8));
	FOG = vec4(fog_color, fog_f);
}

void light() {
	// 그림자 받기만(물 위 그림자) — 빛은 바탕을 조금만 밝힌다
	DIFFUSE_LIGHT += ATTENUATION * LIGHT_COLOR / (PI * PI) * 0.5;
}
