// region_sea 본문 — region_sea.gdshader(반투명, 바다·호수·큰 강 물가 띠)와 region_sea_opaque.gdshader(큰 강 안쪽 불투명)가 같이 쓴다.
#include "res://shaders/region_common.gdshaderinc"

global uniform vec3 hemi_sky;
global uniform vec3 hemi_ground;
global uniform float hemi_i;
global uniform vec3 fog_color;
global uniform float fog_density;

uniform sampler2D water_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D ramp_tex : filter_linear, repeat_disable;
uniform sampler2D mask_blur : filter_linear_mipmap, repeat_disable;   // R 바다 칸, G 뭍 — 밉맵 = 흐린 '물가 가까움'
uniform vec4 mask_meta;     // x0, z0, 1/(셀*w), 1/(셀*h) — 칸 중심 기준
uniform float is_lake = 0.0;
uniform float is_river = 0.0;   // 큰 강 물면(sea.kind="river"): 바다 물결 띠·흰 파도 없이 흐름 방향으로 느리게
uniform sampler2D flow_tex : filter_linear, repeat_disable;   // RG = 하류 방향*0.5+0.5 (32m 칸)
uniform vec4 flow_meta = vec4(0.0, 0.0, 0.0, 0.0);
uniform vec3 deep_col = vec3(0.20, 0.33, 0.37);
uniform vec3 shallow_col = vec3(0.42, 0.58, 0.55);
uniform vec3 foam_col = vec3(0.90, 0.91, 0.86);
uniform vec3 ink_col = vec3(0.17, 0.2, 0.2);
uniform float mist_base = 0.0;

varying vec3 v_wp;

void vertex() {
	v_wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 xz = v_wp.xz;
	float wy = v_wp.y;
	vec2 muv = (xz - mask_meta.xy) * mask_meta.zw;
	// 바다 칸 판정은 한 단 흐린 값으로(4m 칸 계단이 보이지 않게) — 실제 물가선은 아래 수심이 정한다
	float sea = textureLod(mask_blur, muv, 1.0).r;
#ifndef SEA_INTERIOR
	if (is_lake < 0.5 && sea < 0.15) discard;
#endif
	// 수심(게임 m). 지도 밖은 가장자리 값이 이어진다
	float depth = wy - r_hdata(xz);
	// 땅 위(모래톱·바위) — 깊이 시험보다 먼저 버려 물가에서 깜박이지 않게(한가운데 판은 버리지 않는다 — 땅이 없는 칸만 맡는다)
#ifndef SEA_INTERIOR
	if (depth < -0.02) discard;
#endif
#if defined(SEA_SPLIT) && !defined(SEA_INTERIOR)
	// 큰 강 나누기: 물가 띠(얕아 비치는 곳)만 반투명 판, 나머지(알파 ≥ SPLIT_A — 거의 불투명)는 불투명 판이 그린다.
	// 두 판이 같은 식으로 고르므로 겹치거나 빈 곳이 없다. 반투명 판은 화면 대부분을 여기서 일찍 버린다.
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
	// 물결: water.png를 아주 크게, 바람 방향으로 느리게(바다) / 거의 멈춤(호수)
	float spd = mix(0.012, 0.004, is_lake);
	vec3 t = texture(water_tex, xz / 21.0 + vec2(TIME * spd, TIME * spd * 0.4)).rgb;
	vec3 t2 = texture(water_tex, xz / 9.0 * mat2(vec2(0.8, -0.6), vec2(0.6, 0.8)) - vec2(TIME * spd * 1.7, 0.0)).rgb;
	if (is_river > 0.5) {
		// 흐름 지도(flow map) 두 위상: 하류 방향으로 결을 밀고, 8초마다 번갈아 되감아 늘어짐을 숨긴다
		vec2 fd = textureLod(flow_tex, (xz - flow_meta.xy) * flow_meta.zw, 0.0).rg * 2.0 - 1.0;
		float ph0 = fract(TIME / 8.0), ph1 = fract(TIME / 8.0 + 0.5);
		float wgt = abs(ph0 * 2.0 - 1.0);
		vec2 off0 = fd * ph0 * 8.0 * 0.6, off1 = fd * ph1 * 8.0 * 0.6;   // 0.6 m/s
		vec3 ta = texture(water_tex, (xz - off0) / 17.0).rgb, tb = texture(water_tex, (xz - off1) / 17.0 + 0.37).rgb;
		t = mix(ta, tb, wgt);
		vec3 sa = texture(water_tex, (xz - off0 * 1.4) / 7.0 + 0.11).rgb, sb = texture(water_tex, (xz - off1 * 1.4) / 7.0 + 0.61).rgb;
		t2 = mix(sa, sb, wgt);
	}
	vec3 base = mix(deep_col, shallow_col, smoothstep(0.05, 0.85, nearness));
	base *= mix(vec3(1.0), t * 1.25, 0.55);
	// 밀려오는 물결 띠(바다만): 물가 가까움의 등치선을 따라 시간에 따라 물가 쪽으로 — 툰이라 단단한 띠
	float wave = 0.0;
	if (calm < 0.5) {
		// 위상은 16m 흐림(n1)만 — 거친 밉의 모난 등치선이 보이지 않게. 붓 텍스처로 띠를 군데군데 끊는다
		float ph = clamp(n1 * 1.8, 0.0, 1.0) * 4.0 + TIME * 0.12 + (t2.r - 0.5) * 0.6;
		float band = smoothstep(0.88, 0.94, fract(ph)) * (1.0 - smoothstep(0.94, 1.0, fract(ph)));
		band *= smoothstep(0.45, 0.7, t.g);
		wave = band * smoothstep(0.2, 0.6, n1 * 1.8) * (1.0 - shore) * 0.4;
	}
	// 물가선: 흰 거품(붓 텍스처로 끊기게) + 땅 쪽 끝에 옅은 먹선
	float brk = smoothstep(0.35, 0.65, t2.g);
	float foam = smoothstep(0.35, 0.75, shore) * mix(0.55, 1.0, brk) * mix(1.0, 0.45, is_lake) * mix(1.0, 0.25, is_river);
	// 강: 흐름 결을 따라 옅은 물비늘 줄(흰 파도 대신)
	if (is_river > 0.5) base = mix(base, base * 1.18 + vec3(0.03), smoothstep(0.62, 0.8, t2.g) * 0.35 * (1.0 - shore));
	float ink = smoothstep(0.9, 1.0, shore) * 0.45;
	base = mix(base, foam_col, max(foam, wave));
	base = mix(base, ink_col, ink);
	ALBEDO = base;
	// 얕은 물가는 바닥이 비치게, 먼 바다는 거의 불투명
	float a_out = mix(0.95, 0.72, smoothstep(0.3, 1.0, nearness)) * mix(1.0, 0.85, shore) + foam * 0.15;
	if (calm > 0.5) a_out = mix(0.97, 0.75, shore);   // 석호: 바닥(하천 바닥 칠 등)이 비치지 않게 물가만 얕게
	a_out = clamp(a_out, 0.0, 1.0) * clamp(sea * 3.0 + is_lake, 0.0, 1.0);
#ifndef SEA_OPAQUE
	ALPHA = a_out;   // 불투명 판은 ALPHA를 쓰지 않는다(쓰면 반투명 판으로 그려진다) — 0.94~0.97이 1이 될 뿐
#endif
	vec3 hemi = mix(hemi_ground, hemi_sky, 1.0) * hemi_i;
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
