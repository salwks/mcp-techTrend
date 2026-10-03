// 권역 날씨 입자 — 비·눈·바람 티끌(scripts/region/weather.gd). 카메라 둘레 상자 안의 낱알 N개를 메시 하나로 그린다(그리기 1번).
// 정점 = (씨앗 xyz 0~1), UV = 네 귀퉁이, COLOR.r = 낱알 난수. 정점 셰이더가 시간·속도로 옮기고 상자 안으로 감아 돌린다(CPU 일 없음).
// 땅(높이맵) 아래 낱알은 그리지 않는다.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled, world_vertex_coords;

#include "res://shaders/region_common.gdshaderinc"

global uniform vec3 hemi_sky;
global uniform float hemi_i;
global uniform vec3 fog_color;

uniform vec3 center = vec3(0.0);
uniform vec3 box = vec3(56.0, 36.0, 56.0);
uniform float amount = 0.0;   // 0~1: 보이는 낱알 비율
uniform float mode = 0.0;     // 0 비, 1 눈, 2 바람 티끌
uniform vec3 vel = vec3(0.0, -9.0, 0.0);
uniform float use_ground = 1.0;

varying float v_a;
varying vec2 v_c;

void vertex() {
	vec3 seed = VERTEX;
	float rnd = COLOR.r;
	vec3 lo = center - box * 0.5;
	vec3 v = vel * (0.8 + 0.4 * rnd);
	vec3 p = seed * box + v * TIME;
	if (mode > 0.5 && mode < 1.5) {
		p.x += sin(TIME * 1.3 + rnd * 40.0) * 0.6;
		p.z += cos(TIME * 1.1 + rnd * 30.0) * 0.6;
	}
	p = lo + mod(p - lo, box);
	float vis = step(rnd, amount);
	if (use_ground > 0.5) vis *= step(r_hdata(p.xz) - 0.3, p.y);
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	vec3 to_cam = normalize(cam - p);
	vec3 up; vec3 right; float w; float l;
	if (mode > 0.5 && mode < 1.5) {
		right = INV_VIEW_MATRIX[0].xyz; up = INV_VIEW_MATRIX[1].xyz;
		w = 0.045 + 0.04 * rnd; l = w;
	} else {
		up = normalize(v);
		right = normalize(cross(up, to_cam));
		w = mode < 0.5 ? 0.02 : 0.03;
		l = mode < 0.5 ? 0.4 + 0.2 * rnd : 0.25;
	}
	vec2 c = UV * 2.0 - 1.0;
	VERTEX = p + right * c.x * w + up * c.y * l;
	v_c = c;
	vec2 e = abs(p.xz - center.xz) / box.xz;
	v_a = vis * (1.0 - smoothstep(0.32, 0.5, max(e.x, e.y))) * (1.0 - smoothstep(0.35, 0.5, abs(p.y - center.y) / box.y))
		* smoothstep(7.0, 14.0, length(cam - p));
}

void fragment() {
	float a;
	vec3 lit = max(hemi_sky * hemi_i, fog_color);
	vec3 col;
	if (mode > 0.5 && mode < 1.5) {
		a = (1.0 - smoothstep(0.35, 1.0, length(v_c))) * 0.95;
		col = lit * 1.15 + vec3(0.03);
	} else if (mode < 0.5) {
		a = (1.0 - abs(v_c.x)) * smoothstep(-1.0, 0.6, v_c.y) * 0.24;
		col = mix(fog_color, lit, 0.5) * 1.05;
	} else {
		a = (1.0 - abs(v_c.x)) * (1.0 - abs(v_c.y)) * 0.5;
		col = mix(fog_color, lit, 0.4) * 0.9;
	}
	a *= v_a;
	if (a < 0.01) discard;
	ALBEDO = col;
	ALPHA = a;
}
