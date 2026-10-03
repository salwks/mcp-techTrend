// 권역 하천 물 — 웹 개울(buildStream)과 같은 민화식 물결 텍스처(water.png, 7m 반복)가 흐름 방향으로 흐르는 반투명 띠.
// UV.x = 하류 방향 거리/7, UV.y = 가로(0~1). COLOR.r = 여울(물살 빠름), COLOR.g = 소(깊고 고요함), COLOR.b = 강폭(m)/40
shader_type spatial;
render_mode specular_disabled, cull_disabled, blend_mix, depth_draw_opaque;

global uniform vec3 hemi_sky;
global uniform vec3 hemi_ground;
global uniform float hemi_i;
global uniform vec3 fog_color;
global uniform float fog_density;

uniform sampler2D water_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D ramp_tex : filter_linear, repeat_disable;
uniform vec4 albedo = vec4(0.457, 0.591, 0.578, 0.88); // 웹 0xb4cac8(선형), 불투명도 0.88
uniform float mist_base = 0.0;
uniform float gate = 1.0;
uniform float dry = 0.0;    // 건천: 마른 현무암 자갈·바위 바닥, gate만큼 가운데 물줄기
float wh(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float wn(vec2 p) { vec2 i = floor(p), f = fract(p); vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(wh(i), wh(i + vec2(1, 0)), u.x), mix(wh(i + vec2(0, 1)), wh(i + vec2(1, 1)), u.x), u.y); }   // 건천(dry) 물줄기: 비 올 때만 0→1 (region_world._update_dry)

varying vec3 v_wp;
varying vec3 v_c;

void vertex() {
	v_wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_c = COLOR.rgb;
}

void fragment() {
	float rapid = v_c.r, pool = v_c.g;
	float width = max(v_c.b * 40.0, 1.0);
	float spd = 0.045 * (1.0 + rapid * 2.5) * (1.0 - pool * 0.6);
	vec2 uv = vec2(UV.x - TIME * spd, UV.y * width / 7.0 + sin(TIME * 0.6) * 0.01);
	vec3 t = texture(water_tex, uv).rgb;
	// 여울: 흰 물살 줄을 한 겹 더(빠르게), 소: 짙고 고요하게
	vec3 t2 = texture(water_tex, vec2(UV.x * 1.7 - TIME * spd * 2.2, UV.y * width / 4.0 + 0.37)).rgb;
	float foam = smoothstep(0.72, 0.9, max(t2.r, t2.g)) * rapid;
	vec3 base = albedo.rgb * t;
	base = mix(base, base * vec3(0.62, 0.7, 0.72), pool * 0.7);
	base = mix(base, vec3(0.86, 0.89, 0.86), foam * 0.8);
	float edge = smoothstep(0.0, 0.14, min(UV.y, 1.0 - UV.y));
	float a = albedo.a * mix(0.55, 1.0, edge) * (1.0 - rapid * 0.1);
	if (dry > 0.5) {
		// 돌 바닥: 짙은 현무암 자갈 + 둥근 바위(밝은 윗면, 먹빛 테). 젖으면 어둡게
		vec2 p = v_wp.xz;
		vec3 grav = mix(vec3(0.10, 0.095, 0.085), vec3(0.15, 0.14, 0.125), wn(p * 3.1));
		float bv = wn(p * 1.5) * 0.6 + wn(p * 4.2 + 7.0) * 0.4;
		float rock = smoothstep(0.6, 0.65, bv), rim = smoothstep(0.56, 0.6, bv) * (1.0 - rock);
		vec3 st = mix(grav, vec3(0.22, 0.205, 0.185) * (0.85 + 0.3 * wn(p * 6.0)), rock);
		st = mix(st, vec3(0.05), rim * 0.5) * (1.0 - 0.35 * gate);
		float stream = (1.0 - smoothstep(0.05, 0.1, abs(UV.y - 0.5) - gate * 0.06)) * gate;
		base = mix(st, base, stream);
		a = mix(smoothstep(0.0, 0.22, min(UV.y, 1.0 - UV.y)), a, stream);
	}
	ALBEDO = base;
	ALPHA = a;
	vec3 wn = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 hemi = mix(hemi_ground, hemi_sky, 0.5 * wn.y + 0.5) * hemi_i;
	EMISSION = base * hemi / PI;
	float fog_d = -VERTEX.z;
	float fog_f = 1.0 - exp(-fog_density * fog_density * fog_d * fog_d);
	float fog_mist = fog_density * 24.0 * (1.0 - smoothstep(-2.0, 7.0, v_wp.y - mist_base)) * smoothstep(14.0, 48.0, fog_d);
	fog_f = 1.0 - (1.0 - fog_f) * (1.0 - clamp(fog_mist, 0.0, 0.8));
	FOG = vec4(fog_color, fog_f);
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float ramp = texture(ramp_tex, vec2(ndl * 0.5 + 0.5, 0.5)).r;
	DIFFUSE_LIGHT += ramp * ATTENUATION * LIGHT_COLOR / (PI * PI);
}
