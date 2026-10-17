// region_sea 본문 — region_sea.gdshader(반투명, 바다·호수·큰 강 물가 띠)와 region_sea_opaque.gdshader(큰 강 안쪽 불투명)가 같이 쓴다.
// water pass(2026-10-17): 그린 물결 줄(water.png)·밀려오는 띠(band)를 걷고 실제 물결로 바꿨다.
//   - 바다 물결 판(region_world.sea_patch, wave_disp=1)은 꼭짓점이 너울로 움직인다(얕은 물가에서는 줄어듦). 먼 판은 법선만.
//   - 잔물결 법선 지도(wnrm_tex)를 바람(바다)·흐름(큰 강 flow_tex) 쪽으로 흘리고, 반사(평면/하늘)·프레넬·해 반짝임.
//   - 물가: 수심(높이맵)으로 흰 거품 띠 — 물결 판에서는 너울을 따라 물가선이 들락날락한다. 물가 먹선은 water_ink(기본 끔).
#include "res://shaders/region_common.gdshaderinc"
#include "res://shaders/water_common.gdshaderinc"

global uniform vec3 hemi_sky;
global uniform vec3 hemi_ground;
global uniform float hemi_i;
global uniform vec3 fog_color;
global uniform float fog_density;

uniform sampler2D ramp_tex : filter_linear, repeat_disable;
uniform sampler2D mask_blur : filter_linear_mipmap, repeat_disable;   // R 바다 칸, G 뭍 — 밉맵 = 흐린 '물가 가까움'
uniform vec4 mask_meta;     // x0, z0, 1/(셀*w), 1/(셀*h) — 칸 중심 기준
uniform float is_lake = 0.0;
uniform float is_river = 0.0;   // 큰 강 물면(sea.kind="river"): 바다 너울·흰 파도 없이 흐름 방향으로
uniform sampler2D flow_tex : filter_linear, repeat_disable;   // RG = 하류 방향*0.5+0.5 (32m 칸)
uniform vec4 flow_meta = vec4(0.0, 0.0, 0.0, 0.0);
uniform vec3 deep_col = vec3(0.035, 0.085, 0.10);
uniform vec3 shallow_col = vec3(0.12, 0.21, 0.19);
uniform vec3 foam_col = vec3(0.90, 0.91, 0.86);
uniform vec3 ink_col = vec3(0.17, 0.2, 0.2);
uniform float mist_base = 0.0;
uniform float wave_a = 0.20;      // 물결 높이(m) — 바다 WaterFX.SEA, 큰 강·호수는 region_world가 줄인다
uniform float wave_ls = 1.0;      // 물결 파장 배율
uniform float wave_disp = 0.0;    // 1 = 꼭짓점을 움직이는 물결 판
uniform vec4 wave_patch = vec4(0.0, 0.0, 128.0, 32.0);   // 물결 판 가운데 x,z · 반폭 · 가장자리 줄임 폭
uniform vec4 hole = vec4(0.0, 0.0, -1.0, 0.0);            // 먼 판: 물결 판 네모 안은 버린다

varying vec3 v_wp;
varying float v_amp;

// 물결 높이 배율: 판 가장자리·얕은 물가에서 줄인다(꼭짓점과 조각이 같은 값을 쓰도록 함수로)
float sea_amp(vec2 xz, float depth) {
	float a = wave_a * mix(1.0, water_k, 1.0 - max(is_lake, is_river) * 0.5);
	a *= mix(0.35, 1.0, smoothstep(0.0, 4.0, depth));
	if (wave_disp > 0.5) {
		vec2 dd = abs(xz - wave_patch.xy);
		a *= 1.0 - smoothstep(wave_patch.z - wave_patch.w, wave_patch.z - 2.0, max(dd.x, dd.y));
	}
	return a;
}

void vertex() {
	v_wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_amp = 0.0;
	if (wave_disp > 0.5) {
		float a = sea_amp(v_wp.xz, v_wp.y - r_hdata(v_wp.xz));
		float h = w_wave(v_wp.xz, w_time(), a, wave_ls).x;
		VERTEX.y += h;
		v_wp.y += h;
		v_amp = a;
	}
}

void fragment() {
	vec2 xz = v_wp.xz;
#ifndef SEA_INTERIOR
	if (hole.z > 0.0) {
		vec2 dd = abs(xz - hole.xy);
		if (max(dd.x, dd.y) < hole.z - 1.0) discard;
	}
#endif
	float wy = v_wp.y;
	float t = w_time();
	vec2 muv = (xz - mask_meta.xy) * mask_meta.zw;
	// 바다 칸 판정은 한 단 흐린 값으로(4m 칸 계단이 보이지 않게) — 실제 물가선은 아래 수심이 정한다
	float sea = textureLod(mask_blur, muv, 1.0).r;
#ifndef SEA_INTERIOR
	if (is_lake < 0.5 && sea < 0.15) discard;
#endif
	// 수심(게임 m). 지도 밖은 가장자리 값이 이어진다. 물결 판은 출렁인 물면 기준 — 물가선이 너울 따라 들락날락
	float depth = wy - r_hdata(xz);
#ifndef SEA_INTERIOR
	if (depth < -0.02) discard;
#endif
#if defined(SEA_SPLIT) && !defined(SEA_INTERIOR)
	// 큰 강 나누기: 물가 띠(얕아 비치는 곳)만 반투명 판, 나머지(알파 ≥ SPLIT_A — 거의 불투명)는 불투명 판이 그린다.
	float a_split = mix(0.97, 0.75, 1.0 - smoothstep(0.0, 0.32, depth)) * clamp(sea * 3.0, 0.0, 1.0);
#ifdef SEA_OPAQUE
	if (a_split < SPLIT_A) discard;
#else
	if (a_split >= SPLIT_A) discard;
#endif
#endif
	// 물가 가까움(0 먼 바다 … 1 물가): 16m·64m·256m 흐림을 섞는다
	float n1 = textureLod(mask_blur, muv, 2.0).g;
	float n2 = textureLod(mask_blur, muv, 4.0).g;
	float n3 = textureLod(mask_blur, muv, 6.0).g;
	float nearness = clamp(n1 * 1.6 + n2 * 1.0 + n3 * 0.6, 0.0, 1.0);
	float calm = max(is_lake, is_river);   // 파도 없는 물(호수·큰 강)
	if (calm > 0.5) nearness = clamp(n1 * 1.4 + n2 * 0.6, 0.0, 1.0) * 0.8;
	float shore = 1.0 - smoothstep(0.0, 0.32, depth);   // 수심 0~0.32m: 물가선 바로 앞
	// 잔물결: 바다는 바람 쪽으로, 큰 강은 흐름 지도(두 위상 — 8초마다 번갈아 되감아 늘어짐을 숨김)
	vec3 dt;
	if (is_river > 0.5) {
		vec2 fd = textureLod(flow_tex, (xz - flow_meta.xy) * flow_meta.zw, 0.0).rg * 2.0 - 1.0;
		float ph0 = fract(t / 8.0), ph1 = fract(t / 8.0 + 0.5);
		float wgt = abs(ph0 * 2.0 - 1.0);
		dt = mix(w_detail(xz, fd * ph0 * 8.0 * 0.6, 1.3), w_detail(xz + 37.0, fd * ph1 * 8.0 * 0.6, 1.3), wgt);
	} else {
		dt = w_detail(xz, water_wind * t * mix(0.9, 0.25, is_lake), mix(1.6, 0.9, is_lake));
	}
	float amp = wave_disp > 0.5 ? v_amp : sea_amp(xz, depth);
	vec3 wv = w_wave(xz, t, amp, wave_ls);
	vec2 slope = wv.yz + dt.xy * mix(0.5, 0.38, calm) * mix(0.35, 1.5, w_gust(xz, t)) + w_rain(xz, t);
	vec3 nw = normalize(vec3(-slope.x, 1.0, -slope.y));
	vec3 base = mix(deep_col, shallow_col, smoothstep(0.05, 0.85, nearness));
	base = mix(base, shallow_col * 1.25, shore * 0.6);
	base *= 0.8 + 0.4 * dt.z;   // 아주 얕은 물: 모래 바닥 빛
	// 너울 마루는 조금 밝고 옥빛(물속으로 빛이 비침)
	float crest = clamp(wv.x / max(amp, 0.01), -1.0, 1.0);
	base *= 1.0 + crest * 0.22 * (1.0 - calm);
	// 물가 거품: 물가선 바로 앞 얇은 띠를 잔물결 높이로 성기게 끊고(그린 선이 아니게), 바다는 너울 마루가 닿을 때마다
	// 밀려와 넓어졌다 빠진다(swash). 바람 센 날 먼 바다 너울 마루에 흰 물결(whitecap)
	float brk = smoothstep(0.42, 0.6, dt.z + crest * 0.08);
	float lap = 0.5 + 0.5 * sin(t * 0.9 + dot(xz, water_wind) * 0.08 + dt.z * 3.0);
	float band = 1.0 - smoothstep(0.0, mix(0.06, 0.22, lap * (1.0 - calm)), depth);
	float swash = (1.0 - calm) * smoothstep(0.3, 1.0, crest) * (1.0 - smoothstep(0.0, 0.5, depth));
	float cap = (1.0 - calm) * smoothstep(0.75, 0.95, crest) * smoothstep(0.55, 0.7, dt.z) * smoothstep(1.1, 1.8, water_k);
	float foam = max(max(band, swash * 0.7) * brk, cap * 0.7) * mix(1.0, 0.45, is_lake) * mix(1.0, 0.25, is_river);
	float ink = smoothstep(0.9, 1.0, shore) * 0.45 * water_ink;
	vec3 v = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
	float dist = length(VERTEX);
	float F = w_fresnel(nw, v) * mix(1.0, 0.6, shore) * refl_gain;
	vec3 refl = w_reflect(v_wp, nw, v, dist);
	vec3 alb = base * (1.0 - F);
	alb = mix(alb, foam_col, foam);
	alb = mix(alb, ink_col, ink);
	ALBEDO = alb;
	// 얕은 물가는 바닥이 비치게, 먼 바다는 거의 불투명
	float a_out = mix(0.95, 0.72, smoothstep(0.3, 1.0, nearness)) * mix(1.0, 0.85, shore) + foam * 0.15;
	if (calm > 0.5) a_out = mix(0.97, 0.75, shore);   // 석호: 바닥(하천 바닥 칠 등)이 비치지 않게 물가만 얕게
	a_out = clamp(a_out, 0.0, 1.0) * clamp(sea * 3.0 + is_lake, 0.0, 1.0);
#ifndef SEA_OPAQUE
	ALPHA = a_out;   // 불투명 판은 ALPHA를 쓰지 않는다(쓰면 반투명 판으로 그려진다) — 0.94~0.97이 1이 될 뿐
#endif
	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
	vec3 hemi = hemi_sky * hemi_i;
	EMISSION = alb * hemi / PI + refl * F * (1.0 - foam);
	FOG = w_fog(fog_color, fog_density, mist_base, wy, -VERTEX.z);
}

void light() {
	WATER_LIGHT
}
