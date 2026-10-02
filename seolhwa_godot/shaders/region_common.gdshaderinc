// 권역 지형 공통: 높이맵(16비트, RG8 = 상위·하위 바이트) + 토지이용(R8 인덱스) + 아주 약한 절차 잡음.
// scripts/region/region_world.gd의 height_at()과 **같은 계산**이어야 한다(발이 땅에 붙도록).
uniform sampler2D hmap : filter_nearest, repeat_disable;
uniform sampler2D lumap : filter_nearest, repeat_disable;
uniform vec4 h_meta;    // x0, z0, 1/cell, -
uniform vec2 h_range;   // y_min, (y_max-y_min)/65535
uniform ivec2 h_size;
uniform vec4 lu_meta;   // x0, z0, 1/cell, -
uniform ivec2 lu_size;
uniform float detail_amp = 1.0;
// 토지이용별 잡음 세기: 숲 풀밭 논 밭 길 물 마을 바위 모래 대숲
const float LU_DETAIL[10] = float[](1.0, 0.8, 0.12, 0.45, 0.35, 0.0, 0.35, 1.5, 0.3, 1.0);

float r_hraw(ivec2 p) {
	p = clamp(p, ivec2(0), h_size - 1);
	vec4 t = texelFetch(hmap, p, 0);
	return h_range.x + (round(t.r * 255.0) * 256.0 + round(t.g * 255.0)) * h_range.y;
}
float r_hdata(vec2 xz) {
	vec2 f = (xz - h_meta.xy) * h_meta.z;
	f = clamp(f, vec2(0.0), vec2(h_size - 1) - 0.001);
	ivec2 i = ivec2(floor(f));
	vec2 t = f - vec2(i);
	float a = r_hraw(i), b = r_hraw(i + ivec2(1, 0)), c = r_hraw(i + ivec2(0, 1)), d = r_hraw(i + ivec2(1, 1));
	return mix(mix(a, b, t.x), mix(c, d, t.x), t.y);
}
int r_lu(ivec2 p) {
	p = clamp(p, ivec2(0), lu_size - 1);
	return int(round(texelFetch(lumap, p, 0).r * 255.0));
}
float r_hash(ivec2 p) {
	uint h = uint(p.x) * 374761393u + uint(p.y) * 668265263u;
	h = (h ^ (h >> 13u)) * 1274126177u;
	h = h ^ (h >> 16u);
	return float(h) * (1.0 / 4294967295.0);
}
float r_vnoise(vec2 p) {
	vec2 fl = floor(p);
	ivec2 i = ivec2(fl);
	vec2 f = p - fl;
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = r_hash(i), b = r_hash(i + ivec2(1, 0)), c = r_hash(i + ivec2(0, 1)), d = r_hash(i + ivec2(1, 1));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}
float r_detail_mask(vec2 xz) {
	vec2 f = (xz - lu_meta.xy) * lu_meta.z;
	f = clamp(f, vec2(0.0), vec2(lu_size - 1) - 0.001);
	ivec2 i = ivec2(floor(f));
	vec2 t = f - vec2(i);
	float a = LU_DETAIL[r_lu(i)], b = LU_DETAIL[r_lu(i + ivec2(1, 0))];
	float c = LU_DETAIL[r_lu(i + ivec2(0, 1))], d = LU_DETAIL[r_lu(i + ivec2(1, 1))];
	return mix(mix(a, b, t.x), mix(c, d, t.x), t.y);
}
float r_detail(vec2 xz) {
	return (r_vnoise(xz * 0.14) - 0.5) * 0.36 + (r_vnoise(xz * 0.45 + vec2(31.0, 17.0)) - 0.5) * 0.10;
}
// 격자점(정수 m) 높이 — 근경 메시의 꼭짓점
float r_height(vec2 xz) {
	return r_hdata(xz) + r_detail(xz) * r_detail_mask(xz) * detail_amp;
}
