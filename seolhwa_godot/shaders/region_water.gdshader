// 권역 하천 물(water pass 2026-10-17): 흐르는 띠 — 잔물결 꼭짓점 물결 + 흐름 방향으로 흐르는 잔물결 법선 + 반사(평면/하늘) + 해 반짝임.
// 예전 민화식 물결 줄 텍스처(water.png)는 쓰지 않는다(그림 맥락이 다른 제목 화면·지도만 그대로).
// UV.x = 하류 방향 거리/7, UV.y = 가로(0~1). COLOR.r = 여울(물살 빠름), COLOR.g = 소(깊고 고요함), COLOR.b = 강폭(m)/40, TANGENT = 하류 방향
// 수심은 높이맵(region_common r_hdata)으로: 물가 얕은 곳은 바닥이 비치고, 물가선에 젖은 테·잔 거품.
shader_type spatial;
render_mode cull_disabled, blend_mix, depth_draw_opaque;

#include "res://shaders/region_common.gdshaderinc"
#include "res://shaders/water_common.gdshaderinc"

global uniform vec3 hemi_sky;
global uniform vec3 hemi_ground;
global uniform float hemi_i;
global uniform vec3 fog_color;
global uniform float fog_density;

uniform sampler2D ramp_tex : filter_linear, repeat_disable;
uniform vec3 deep_col = vec3(0.028, 0.07, 0.06);
uniform vec3 shallow_col = vec3(0.17, 0.17, 0.115);   // 비치는 냇바닥(모래·자갈)
uniform vec3 foam_col = vec3(0.86, 0.89, 0.86);
uniform float mist_base = 0.0;
uniform float gate = 1.0;
uniform float dry = 0.0;    // 건천: 마른 현무암 자갈·바위 바닥, gate만큼 가운데 물줄기(비 올 때만 0→1 — region_world._update_dry)
uniform float has_depth = 1.0;
float wh(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float wn(vec2 p) { vec2 i = floor(p), f = fract(p); vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(wh(i), wh(i + vec2(1, 0)), u.x), mix(wh(i + vec2(0, 1)), wh(i + vec2(1, 1)), u.x), u.y); }

const vec2 RIVER_W = vec2(0.022, 0.22);   // WaterFX.RIVER

varying vec3 v_wp;
varying vec3 v_c;
varying vec2 v_flow;

void vertex() {
	v_wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_c = COLOR.rgb;
	v_flow = normalize((MODEL_MATRIX * vec4(TANGENT, 0.0)).xz + vec2(1e-5, 0.0));
	if (dry < 0.5) {
		// 잔물결(소는 더 잔잔하게, 여울은 조금 더) — 물가(가로 끝)는 붙여 둔다
		float edge = smoothstep(0.0, 0.25, min(UV.y, 1.0 - UV.y));
		float a = RIVER_W.x * mix(1.0, water_k, 0.5) * (1.0 - COLOR.g * 0.6 + COLOR.r * 0.8) * edge;
		VERTEX.y += w_wave(v_wp.xz, w_time(), a, RIVER_W.y).x;
	}
}

void fragment() {
	float t = w_time();
	float rapid = v_c.r, pool = v_c.g;
	vec2 xz = v_wp.xz;
	// 흐름: 하류로 미는 거리(m) — 여울 빠르게, 소 느리게
	float spd = 0.32 * (1.0 + rapid * 2.5) * (1.0 - pool * 0.6);
	// 흐름 두 박자(flow map): 미는 거리를 T초마다 되감고 반 박자 어긋난 두 장을 엇갈려 섞는다.
	//   예전엔 v_flow·t를 끝없이 키워서, 굽이에서 이웃 화소의 흐름 방향 차이가 시간에 비례해 벌어져 무늬가 뒤틀렸다.
	const float FT = 3.0;
	float ph0 = fract(t / FT), ph1 = fract(t / FT + 0.5);
	float dsc = mix(1.0, 0.7, rapid);
	vec3 d0 = w_detail(xz, v_flow * spd * ph0 * FT, dsc);
	vec3 d1 = w_detail(xz + vec2(7.3, 3.1), v_flow * spd * ph1 * FT, dsc);
	vec3 dt = mix(d0, d1, abs(ph0 * 2.0 - 1.0));
	float uv_edge = min(UV.y, 1.0 - UV.y);
	float edge_amp = smoothstep(0.0, 0.25, uv_edge);
	vec3 wv = w_wave(xz, t, RIVER_W.x * mix(1.0, water_k, 0.5) * (1.0 - pool * 0.6 + rapid * 0.8) * edge_amp, RIVER_W.y);
	float gust = w_gust(xz, t);
	vec2 slope = wv.yz + dt.xy * mix(0.42, 0.6, rapid) * mix(1.0, 0.6, pool) * mix(0.35, 1.5, gust) + w_rain(xz, t);
	vec3 nw = normalize(vec3(-slope.x, 1.0, -slope.y));
	// 수심(높이맵) — 물 띠가 땅 위로 떠 있는 곳도 가장자리(UV)는 얕게 본다
	float d = has_depth > 0.5 ? v_wp.y - r_hdata(xz) : 1.0;
	float shallow = max(1.0 - smoothstep(0.04, 0.75, d), 1.0 - smoothstep(0.02, 0.2, uv_edge));
	vec3 body = mix(deep_col, shallow_col, shallow * 0.85);
	body = mix(body, body * vec3(0.78, 0.9, 0.92), pool * 0.6);
	body *= 0.8 + 0.4 * dt.z;   // 잔물결 골은 조금 짙게(붓 바림)
	// 흰 물살(여울): 흐름 쪽으로 늘인 잡음 — 그린 줄이 아니라 덩어리로 끊긴다
	//   물길 좌표(UV.x = 하류 거리/7, UV.y = 가로)로 — 세계 좌표를 흐름 방향에 투영하면 굽이에서 줄무늬가 부채꼴로 휜다
	float along = UV.x * 7.0, across = (UV.y - 0.5) * max(v_c.b * 40.0, 2.0);
	float fh = texture(wnrm_tex, vec2(along * 0.09 - t * spd * 0.2, across * 0.35)).a;
	float foam = smoothstep(0.58, 0.74, fh * 0.7 + dt.z * 0.3) * rapid;
	// 물가선: 아주 얕은 띠에 젖은 밝은 테·잔 거품(물결 따라 끊김)
	float lip = (1.0 - smoothstep(0.0, 0.07, d)) * smoothstep(0.35, 0.65, dt.z) * has_depth;
	foam = max(foam, lip * 0.55);
	vec3 v = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
	float dist = length(VERTEX);
	float F = w_fresnel(nw, v) * mix(1.0, 0.55, shallow) * refl_gain;
	vec3 refl = w_reflect(v_wp, nw, v, dist);
	vec3 alb = body * (1.0 - F);
	alb = mix(alb, foam_col, foam * 0.85);
	float ink = water_ink * (1.0 - smoothstep(0.0, 0.05, uv_edge)) * 0.5;
	alb = mix(alb, vec3(0.05, 0.055, 0.05), ink);
	float edge = smoothstep(0.0, 0.12, uv_edge);
	float a = mix(0.97, 0.6, shallow) * mix(0.5, 1.0, edge);
	a = max(a, foam * 0.9);
	vec3 emis = refl * F * (1.0 - foam);
	if (dry > 0.5) {
		// 돌 바닥: 짙은 현무암 자갈 + 둥근 바위(밝은 윗면, 먹빛 테). 젖으면 어둡게
		vec2 p = v_wp.xz;
		vec3 grav = mix(vec3(0.10, 0.095, 0.085), vec3(0.15, 0.14, 0.125), wn(p * 3.1));
		float bv = wn(p * 1.5) * 0.6 + wn(p * 4.2 + 7.0) * 0.4;
		float rock = smoothstep(0.6, 0.65, bv), rim = smoothstep(0.56, 0.6, bv) * (1.0 - rock);
		vec3 st = mix(grav, vec3(0.22, 0.205, 0.185) * (0.85 + 0.3 * wn(p * 6.0)), rock);
		st = mix(st, vec3(0.05), rim * 0.5) * (1.0 - 0.35 * gate);
		float stream = (1.0 - smoothstep(0.05, 0.1, abs(UV.y - 0.5) - gate * 0.06)) * gate;
		alb = mix(st, alb, stream);
		emis *= stream;
		a = mix(smoothstep(0.0, 0.22, uv_edge), a, stream);
		nw = normalize(mix(vec3(0.0, 1.0, 0.0), nw, stream));
	}
	ALBEDO = alb;
	ALPHA = a;
	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
	vec3 hemi = mix(hemi_ground, hemi_sky, 0.85) * hemi_i;
	EMISSION = alb * hemi / PI + emis;
	FOG = w_fog(fog_color, fog_density, mist_base, v_wp.y, -VERTEX.z);
}

void light() {
	WATER_LIGHT
}
