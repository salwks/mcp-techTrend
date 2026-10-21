// 가까운 풀잎(material-lighting 2차 — scripts/render/grass.gd). 사실 쪽(--look=real)만 쓴다.
//   카메라 둘레 격자(노드가 격자 간격 단위로 따라 움직임)의 포기마다: 자리 흔들기·돌림·키는 세계 칸 해시 → 움직여도 같은 자리에 같은 포기.
//   땅 높이·풀 덮임은 땅 셰이더와 같은 식(region_common r_height, ground_mask gm_grass) — 흙길·마당·처마 밑에는 서지 않는다.
//   잎: 뿌리 짙고 끝 밝음, 바람에 휨(끝일수록), 뒤에서 오는 볕이 비침. 그림자는 받기만(드리우지 않음 — 비용).
shader_type spatial;
render_mode cull_disabled;
#define LOOK_PBR

#include "res://shaders/region_common.gdshaderinc"
#include "res://shaders/pbr_common.gdshaderinc"

global uniform vec3 hemi_sky;
global uniform vec3 hemi_ground;
global uniform float hemi_i;
global uniform vec3 fog_color;
global uniform float fog_density;
global uniform float fog_base;
global uniform float wet;
global uniform float snow;

uniform sampler2D paint_tex : filter_linear, repeat_disable;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D dress_tex : filter_linear, repeat_disable;
uniform float dress_on = 0.0;
uniform sampler2D farm_tex : filter_linear, repeat_disable;
uniform vec4 farm_meta = vec4(0.0, 0.0, 0.5, 0.0);
uniform vec2 farm_size = vec2(1.0);
uniform float farm_on = 0.0;
uniform float urban_ground = 0.0;
uniform float spacing = 0.3;       // 격자 간격(m)
uniform float radius = 24.0;       // 이 거리(초점에서)까지, 끝 25%에서 줄어든다
uniform float inner = 0.0;         // 이 안(초점에서 정사각)은 비운다(가까운 벌이 맡음)
uniform vec3 focus = vec3(0.0);    // 풀밭 가운데(플레이어 · 1인칭이면 카메라 앞)
uniform float tall = 1.0;          // 키 배율

#include "res://shaders/ground_mask.gdshaderinc"

varying vec3 v_col;
varying float v_t;
varying vec3 v_wp;
varying float v_cov;

void vertex() {
	vec3 org = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	ivec2 cell = ivec2(round(org.xz / spacing));
	float h0 = r_hash(cell + ivec2(11, 7)), h1 = r_hash(cell + ivec2(3, 51)), h2 = r_hash(cell + ivec2(71, 19)), h3 = r_hash(cell + ivec2(29, 83));
	vec2 p = vec2(cell) * spacing + (vec2(h0, h1) - 0.5) * spacing * 0.95;
	vec2 dq = abs(p - focus.xz);
	float dfo = max(dq.x, dq.y);
	float keep = (1.0 - smoothstep(radius * 0.72, radius, length(p - focus.xz))) * step(inner, dfo);
	float gw = 0.0;
	float hgt = r_height(p);
	if (keep > 0.001) {
		float hx = r_hdata(p + vec2(1.0, 0.0)), hz = r_hdata(p + vec2(0.0, 1.0));
		float slope = length(vec2(hx - hgt, hz - hgt));
		vec2 uvh = gm_huv(p);
		vec4 pt = texture(paint_tex, uvh);
		vec4 dv = dress_on > 0.0 ? textureLod(dress_tex, uvh, 0.0) : vec4(1.0, 0.0, 1.0, 0.0);
		gw = gm_grass(p, slope, pt, dv, textureLod(noise_tex, p * 0.21 + vec2(0.31, 0.77), 0.0).r * 0.62 + textureLod(noise_tex, p * 0.93 + vec2(0.13, 0.52), 0.0).r * 0.38);
	}
	// 덮임이 옅은 데는 성기고 낮게(흙과 섞이는 경계)
	float live = step(h2, gw * 1.6) * keep * (1.0 - 0.85 * snow);
	float sz = live * (0.35 + 0.65 * smoothstep(0.05, 0.6, gw)) * (0.75 + 0.85 * h3 * h3) * tall;
	// 잎 꼭짓점: 메시 VERTEX = (잎 방향 단위 · 높이 비율) — x,z 퍼짐, y 0~1
	float a = h0 * 6.2832;
	mat2 rot = mat2(vec2(cos(a), sin(a)), vec2(-sin(a), cos(a)));
	vec3 lv = VERTEX;
	float t = UV.y;
	vec2 xz = rot * lv.xz;
	float H = 0.24 * sz;
	// 바람: 끝일수록 휜다(두 박자 + 세계 자리 위상)
	float ph = dot(p, vec2(0.21, 0.17)) + TIME * 1.7;
	vec2 wind = vec2(0.8, 0.45) * (sin(ph) * 0.6 + sin(ph * 2.3 + 1.7) * 0.3 + 0.35) * 0.09 * t * t * H / 0.24;
	vec3 wp = vec3(p.x + xz.x * sz + wind.x, hgt - 0.04 + lv.y * H, p.y + xz.y * sz + wind.y);
	VERTEX = wp - org;   // 포기 변환은 옮김뿐(grass.gd)
	// 법선: 잎 면 + 위쪽(땅빛과 어울리게 · 뒷면 검지 않게)
	vec3 bn = normalize(vec3(-xz.y, 0.0, xz.x) + vec3(0.0, 1e-3, 0.0));
	NORMAL = normalize(mix(bn, vec3(0.0, 1.0, 0.0), 0.65));
	// 잎 빛깔(선형): 짙은 풀 · 연둣빛 · 마른 짚빛, 큰 잡음으로 마른 얼룩
	float dry = smoothstep(0.45, 0.75, textureLod(noise_tex, p * 0.045 + vec2(0.6, 0.1), 0.0).r) * 0.6;
	vec3 c0 = mix(vec3(0.10, 0.165, 0.032), vec3(0.17, 0.235, 0.05), h1);
	c0 = mix(c0, vec3(0.28, 0.23, 0.09), max(dry * h3, step(0.85, h2 / max(gw * 1.6, 1e-3)) * 0.7));
	v_col = c0 * (0.85 + 0.3 * COLOR.r);
	v_t = t;
	v_wp = wp;
	v_cov = gw;
}

void fragment() {
	vec3 alb = v_col * mix(0.6, 1.5, v_t);   // 뿌리 쪽은 잎 그늘(짙다)
	alb *= 1.0 - 0.3 * wet;
	ALBEDO = alb;
	ROUGHNESS = mix(0.75, 0.35, wet);
	BACKLIGHT = vec3(0.35);
	vec3 nw = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 irr = pbr_irr(nw, hemi_sky, hemi_ground, fog_color, hemi_i);
	float ao = mix(0.6, 1.0, v_t);   // 포기 안쪽 밑동은 하늘이 덜 보인다
	EMISSION = alb * irr * ao * amb_k / PI;
	float fog_d = -VERTEX.z;
	float fog_f = 1.0 - exp(-fog_density * fog_density * fog_d * fog_d);
	FOG = vec4(pbr_fog_color(fog_color, normalize(v_wp - CAMERA_POSITION_WORLD)), fog_f);
}

void light() {
	vec3 dl = vec3(0.0), sl = vec3(0.0);
	pbr_direct(NORMAL, LIGHT, VIEW, LIGHT_COLOR, ATTENUATION * (LIGHT_IS_DIRECTIONAL ? sun_k : 1.0), ROUGHNESS, BACKLIGHT.r, dl, sl);
	DIFFUSE_LIGHT += dl;
	SPECULAR_LIGHT += sl * 0.5;
}
