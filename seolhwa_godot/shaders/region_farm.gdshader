// 논·밭 필지 땅(scripts/region/farm.gd): 논두렁·바닥·둑 비탈·석축·현무암 돌담·이랑·테두리 비탈.
// 지형 셰이더(region_terrain)와 같은 툰 규칙: 붓 바림 램프(LIGHT_COLOR/π²) + 반구광 + ground.png + 같은 안개.
// COLOR.rgb = sRGB 바탕색, COLOR.a = 무늬(0 흙·풀, 0.5 막돌 석축, 1 현무암 돌담)
shader_type spatial;
render_mode specular_disabled, cull_back;

global uniform vec3 hemi_sky;
global uniform vec3 hemi_ground;
global uniform float hemi_i;
global uniform vec3 fog_color;
global uniform float fog_density;
global uniform float wet;
global uniform float snow;
global uniform float snow_line;

uniform sampler2D ground_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable, hint_default_white;
uniform sampler2D ramp_tex : filter_linear, repeat_disable;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform float mist_base = 0.0;

varying vec3 v_wp;
varying vec4 v_c;
varying vec3 v_wn;

vec3 srgb(vec3 c) { return pow(max(c, vec3(0.0)), vec3(2.2)); }
float tn(vec2 uv) { return (texture(noise_tex, uv).r + texture(noise_tex, uv * 0.6180 + vec2(0.37, 0.71)).r - 1.0) * 1.15; }
float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

// 막돌 쌓기: 줄마다 어긋난 돌, 돌 사이 먹빛 줄눈
float stones(vec2 uv, out float id) {
	float row = floor(uv.y);
	float x = uv.x + h21(vec2(row, 3.1)) * 0.7;
	float w = 0.8 + 0.5 * h21(vec2(floor(x), row));
	vec2 cell = vec2(floor(x / w), row);
	vec2 f = vec2(fract(x / w), fract(uv.y));
	id = h21(cell);
	vec2 e = min(f, 1.0 - f) * vec2(w, 1.0);
	return smoothstep(0.03, 0.09, min(e.x, e.y));
}

void vertex() {
	v_wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_c = COLOR;
	v_wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 p = v_wp.xz;
	float n1 = tn(p * 0.019);
	float n2 = clamp(tn(p * 0.075 + vec2(0.37, 0.11)) * 2.0, -1.0, 1.0);
	vec3 col = v_c.rgb * (0.94 + 0.12 * n1) ;
	col = mix(col, col * vec3(1.04, 1.0, 0.86), clamp(n2 * 0.5, 0.0, 0.4));
	float pat = v_c.a;
	vec3 base;
	if (pat > 0.25) {
		// 석축·돌담: 벽 면을 따라 가로 = 수평 거리, 세로 = 높이
		vec2 hz = abs(v_wn.x) > abs(v_wn.z) ? vec2(v_wp.z, v_wp.y) : vec2(v_wp.x, v_wp.y);
		if (v_wn.y > 0.7) hz = p;   // 윗면
		float id;
		float sc = pat > 0.75 ? 2.4 : 3.2;
		// 돌 모양을 둥글게 흔들어(현무암 막돌) 벽돌처럼 반듯하지 않게
		vec2 wob = vec2(tn(hz * 0.9), tn(hz * 0.9 + vec2(3.7, 1.3))) * 0.12;
		float s = stones(hz * sc + wob * sc, id);
		vec3 sc0 = pat > 0.75 ? vec3(0.17, 0.165, 0.16) : vec3(0.60, 0.57, 0.51);
		vec3 sc1 = pat > 0.75 ? vec3(0.26, 0.25, 0.235) : vec3(0.72, 0.68, 0.60);
		vec3 st = mix(sc0, sc1, id) * (0.9 + 0.2 * n1);
		col = mix(st * 0.35, st, s);
		base = srgb(col);
	} else {
		base = srgb(col) * texture(ground_tex, p / 7.0).rgb;
	}
	float water = 0.0;
	if (wet > 0.0 || snow > 0.0 || snow_line < 9e4) {
		float sc = max(snow, smoothstep(snow_line, snow_line + 30.0, v_wp.y) * (0.75 + 0.25 * n1));
		float cov = 0.0;
		if (sc > 0.0) cov = clamp(sc * 1.6 - 0.5 + tn(p * 0.11) * 0.45, 0.0, 0.92) * smoothstep(0.35, 0.8, v_wn.y);
		base *= 1.0 - 0.32 * wet * (1.0 - cov);
		base = mix(base, vec3(0.80, 0.83, 0.88), cov);
	}
	ALBEDO = base;
	vec3 hemi = mix(hemi_ground, hemi_sky, 0.5 * v_wn.y + 0.5) * hemi_i;
	EMISSION = ALBEDO * hemi / PI;
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
