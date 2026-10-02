// 권역 원경 — 근·중경 타일 바깥의 권역 전체를 거친 격자(32m)로 세우고, 하늘 그림판(sky_backdrop)의 먼 산처럼
// 능선 쪽은 먹빛, 산발치는 운해·안개빛으로 칠한다(조명 없음). 근·중경이 있는 사각형(hole) 안은 그리지 않는다.
shader_type spatial;
render_mode unshaded, cull_back, fog_disabled, shadows_disabled;

#include "res://shaders/region_common.gdshaderinc"

uniform vec4 hole = vec4(0.0);      // 근·중경 타일이 덮는 사각형 minX, minZ, maxX, maxZ
uniform vec3 u_hor = vec3(0.8);
uniform vec3 u_ink = vec3(0.0103, 0.0131, 0.0232);
uniform vec3 u_fog = vec3(0.7);
uniform vec3 u_low = vec3(0.7);
uniform vec3 u_glow = vec3(1.0);
uniform float u_glow_i = 0.0;
uniform float grid_step = 32.0;
uniform float haze = 1.0;   // 0이면 거리 안개빛 없이(--nofog)

varying vec3 v_wp;
varying float v_ridge;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX.x, 0.0, VERTEX.z, 1.0)).xyz;
	float h = r_hdata(wp.xz);
	// 주변보다 얼마나 솟았나(능선 = 먹, 골짜기 = 안개)
	float s = grid_step * 3.0;
	float around = (r_hdata(wp.xz + vec2(s, 0)) + r_hdata(wp.xz - vec2(s, 0)) + r_hdata(wp.xz + vec2(0, s)) + r_hdata(wp.xz - vec2(0, s))) * 0.25;
	v_ridge = clamp((h - around) / 25.0 + 0.5, 0.0, 1.0);
	VERTEX.y = h - MODEL_MATRIX[3].y - 1.5;
	v_wp = vec3(wp.x, h, wp.z);
}

void fragment() {
	if (v_wp.x > hole.x && v_wp.x < hole.z && v_wp.z > hole.y && v_wp.z < hole.w) discard;
	float d = length(VERTEX);
	vec3 mtn = mix(u_hor, u_ink, 0.26 + 0.17 * v_ridge);
	mtn = mix(mtn, u_glow, 0.18 * u_glow_i);
	vec3 sea = mix(u_low, u_fog, 0.5);
	vec3 mist = mix(sea, u_hor, 0.25);
	// 멀수록, 낮을수록 안개
	float k = (smoothstep(300.0, 2600.0, d) * 0.75 + (1.0 - v_ridge) * 0.35) * haze;
	ALBEDO = mix(mtn, mist, clamp(k, 0.0, 0.92));
}
