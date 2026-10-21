// 권역 원경 — 근·중경 타일 바깥의 권역 전체를 거친 격자(16m)로 세운다. 근·중경이 있는 사각형(hole) 안은 그리지 않는다.
// mountain-terrain(2026-10-21): 먹빛 단색 그림판 대신 근·중경 지형과 **같은 빛**(붓 바림 램프 + 반구광)과 같은 땅 색 규칙(수관·들·바위·마을 지붕),
// 같은 공기원근(region_far_look)으로 칠한다 → 먼 능선 실루엣이 걸어서 닿는 그 땅이고, 근·중경 경계(약 1.1~1.3km)에 이음매가 없다.
shader_type spatial;
render_mode cull_back, specular_disabled, shadows_disabled;

#include "res://shaders/region_common.gdshaderinc"
#include "res://shaders/region_far_look.gdshaderinc"

global uniform vec3 hemi_sky;
global uniform vec3 hemi_ground;
global uniform float hemi_i;
global uniform vec3 fog_color;
global uniform float fog_density;
global uniform float snow;       // 눈 덮기(날씨) — 원경 산도 하얗게
global uniform float snow_line;  // 이 높이 위 잔설

uniform vec4 hole = vec4(0.0);      // 근·중경 타일이 덮는 사각형 minX, minZ, maxX, maxZ
uniform sampler2D ramp_tex : filter_linear, repeat_disable;
uniform sampler2D dress_tex : filter_linear, repeat_disable;
uniform float dress_on = 0.0;
uniform vec3 far_ink = vec3(0.07, 0.085, 0.08);
uniform float mist_base = 0.0;
uniform float grid_step = 16.0;
uniform float haze = 1.0;           // 0이면 안개 없이(--nofog)
// 예전 그림판 값(region_main이 넣는다 — 지금은 쓰지 않지만 이름은 남긴다)
uniform vec3 u_hor = vec3(0.8);
uniform vec3 u_ink = vec3(0.0103, 0.0131, 0.0232);
uniform vec3 u_fog = vec3(0.7);
uniform vec3 u_low = vec3(0.7);
uniform vec3 u_glow = vec3(1.0);
uniform float u_glow_i = 0.0;

varying vec3 v_wp;
varying vec3 v_wn;

vec3 srgb(vec3 c) { return pow(c, vec3(2.2)); }

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX.x, 0.0, VERTEX.z, 1.0)).xyz;
	float h = r_hdata(wp.xz);
	float s = grid_step;
	float hl = r_hdata(wp.xz - vec2(s, 0.0)), hr = r_hdata(wp.xz + vec2(s, 0.0));
	float hd = r_hdata(wp.xz - vec2(0.0, s)), hu = r_hdata(wp.xz + vec2(0.0, s));
	vec3 n = normalize(vec3(hl - hr, 2.0 * s, hd - hu));
	VERTEX.y = h - MODEL_MATRIX[3].y - 0.6;   // 근·중경 아래로 살짝(겹침 깜빡임 방지)
	NORMAL = n;
	v_wp = vec3(wp.x, h, wp.z);
	v_wn = n;
}

void fragment() {
	if (v_wp.x > hole.x && v_wp.x < hole.z && v_wp.z > hole.y && v_wp.z < hole.w) discard;
	vec2 p = v_wp.xz;
	ivec2 li = ivec2(round((p - lu_meta.xy) * lu_meta.z));
	int c = r_lu(li);
	float slope = length(v_wn.xz) / max(v_wn.y, 0.05);
	float n1 = r_vnoise(p * 0.02) - 0.5;
	vec3 col;
	if (c == 0 || c == 9) col = canopy_color(p, v_wp.y);
	else if (c == 2) col = mix(vec3(0.486, 0.416, 0.294), vec3(0.56, 0.61, 0.36), 0.55 + n1 * 0.4);
	else if (c == 3) col = mix(vec3(0.64, 0.54, 0.37), vec3(0.56, 0.61, 0.36), 0.4 + n1 * 0.4);
	else if (c == 5) col = vec3(0.42, 0.47, 0.50);
	else if (c == 6 || c == 4) col = mix(vec3(0.616, 0.651, 0.420), vec3(0.788, 0.671, 0.471), 0.35);
	// integ-mountain: 산 지형 권역(aer_k)에서 바위 칸은 바위틈 숲이 섞인 회록색, 너덜은 회갈색 — 먼 산이 모래·황토빛으로 읽히지 않게
	else if (c == 7) col = mix(mix(vec3(0.557, 0.525, 0.463), vec3(0.416, 0.396, 0.357), 0.4 + n1), mix(canopy_color(p, v_wp.y), vec3(0.47, 0.47, 0.45), 0.45), aer_k);
	else if (c == 8) col = mix(vec3(0.80, 0.76, 0.64), vec3(0.50, 0.48, 0.44), aer_k);
	else col = mix(vec3(0.616, 0.651, 0.420), vec3(0.525, 0.596, 0.361), 0.5 + n1);
	col = mix(col, mix(vec3(0.557, 0.525, 0.463), vec3(0.45, 0.45, 0.43), aer_k), mix(smoothstep(1.0, 1.5, slope) * 0.6, smoothstep(1.4, 2.0, slope) * 0.5, aer_k));
	col = mix(col, vec3(0.553, 0.576, 0.486), smoothstep(200.0, 520.0, v_wp.y) * 0.25);
	if (dress_on > 0.0) {
		float ed = texture(dress_tex, ((p - h_meta.xy) * h_meta.z + 0.5) / vec2(h_size)).r * 255.0 - 128.0;
		col = mix(col, roof_color(p), 1.0 - smoothstep(-6.0, 2.0, ed));
	}
	vec3 base = srgb(col);
	float sc = max(snow * 0.85, smoothstep(snow_line, snow_line + 40.0, v_wp.y) * 0.8) * smoothstep(0.35, 0.8, v_wn.y);
	base = mix(base, vec3(0.80, 0.83, 0.88), sc);
	ALBEDO = base;
	vec3 hemi = mix(hemi_ground, hemi_sky, 0.5 * v_wn.y + 0.5) * hemi_i;
	EMISSION = base * hemi / PI;
	float d = length(VERTEX);
	float fog_f = 1.0 - exp(-fog_density * fog_density * d * d);
	fog_f = aer_haze(fog_f, d, v_wp.y, mist_base, fog_density) * haze;
	vec3 fc = aer_tint(fog_color, far_ink, d, v_wp.y, mist_base, v_wn.y);
	FOG = vec4(fc, fog_f);
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float ramp = texture(ramp_tex, vec2(ndl * 0.5 + 0.5, 0.5)).r;
	DIFFUSE_LIGHT += ramp * ATTENUATION * LIGHT_COLOR / (PI * PI);
}
