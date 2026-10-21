// 사실 땅(2차) 공용: 풀 덮임 마스크 — 땅 셰이더(region_terrain, LOOK_PBR 풀 층)와 풀잎 셰이더(grass.gdshader)가 같은 식을 쓴다.
// 이 파일을 넣기 전에 region_common.gdshaderinc와 아래 uniform(이름 그대로)이 있어야 한다:
//   paint_tex(길·마당 칠하기) · dress_tex/dress_on(처마 부호 거리·박석·물가) · farm_tex/farm_meta/farm_size/farm_on · noise_tex · urban_ground
#ifndef GROUND_MASK
#define GROUND_MASK

// 토지이용별 풀 덮임: 숲 풀밭 논 밭 길 물 마을 바위 모래 대숲
// integ-mountain: 숲(0)·대숲(9)은 풀이 숲 틈에만(0.75 → 0.32 · 0.55 → 0.25) — 숲 바닥은 부엽토·낙엽(ground_real 스캔 층)
const float LU_GRASS[10] = float[](0.32, 1.0, 0.9, 0.85, 0.8, 0.0, 0.62, 0.12, 0.05, 0.25);

float gm_lu(vec2 p) {
	vec2 f = (p - lu_meta.xy) * lu_meta.z;
	f = clamp(f, vec2(0.0), vec2(lu_size - 1) - 0.001);
	ivec2 i = ivec2(floor(f));
	vec2 t = smoothstep(0.15, 0.85, f - vec2(i));
	float a = LU_GRASS[r_lu(i)], b = LU_GRASS[r_lu(i + ivec2(1, 0))];
	float c = LU_GRASS[r_lu(i + ivec2(0, 1))], d = LU_GRASS[r_lu(i + ivec2(1, 1))];
	return mix(mix(a, b, t.x), mix(c, d, t.x), t.y);
}
vec2 gm_huv(vec2 p) { return ((p - h_meta.xy) * h_meta.z + 0.5) / vec2(h_size); }
// 풀 덩이 잡음(0~1): 5m 덩이 + 1m 잔덩이
float gm_noise(vec2 p) {
	return texture(noise_tex, p * 0.21 + vec2(0.31, 0.77)).r * 0.62 + texture(noise_tex, p * 0.93 + vec2(0.13, 0.52)).r * 0.38;
}
// pt = paint_tex(길 거리 rd·반폭 rhw·마당 거리 yd), dv = dress_tex(처마 sd·장터·물가 wd·박석), slope = |∇h|
float gm_grass(vec2 p, float slope, vec4 pt, vec4 dv, float n) {
	float g = gm_lu(p) * (1.0 - 0.3 * urban_ground);
	float rd = pt.r * 16.0, rhw = pt.g * 8.0, yd = pt.b * 16.0;
	g *= smoothstep(0.05, 0.9, rd - rhw + (n - 0.5) * 0.9);   // 길 위에는 없고 길섶부터
	g *= smoothstep(1.0, 3.6, yd + (n - 0.5) * 2.4);          // 집 둘레 흙 마당
	if (dress_on > 0.5) {
		float sd = (dv.r * 255.0 - 128.0) / 16.0;
		float wd = dv.b * 255.0 / 16.0;
		float pav = dv.a * 255.0;
		g *= smoothstep(0.15, 1.1, sd + (n - 0.5) * 0.7);       // 처마 밑·기단 둘레는 맨흙
		g *= smoothstep(1.2, 3.2, wd + (n - 0.5) * 1.5);         // 우물·빨래터 둘레 진흙
		if (pav > 0.5) g *= 1.0 - smoothstep(-1.0, -0.7, (pav - 1.0) / 32.0 - 1.0);
	}
	if (farm_on > 0.5) {
		float fd = (texture(farm_tex, ((p - farm_meta.xy) * farm_meta.z + 0.5) / farm_size).r * 255.0 - 128.0) / 16.0;
		g *= smoothstep(0.1, 0.6, fd);
	}
	g *= 1.0 - smoothstep(0.55, 1.0, slope);
	return clamp(g * 1.35 - 0.12 + (n - 0.5) * 0.95, 0.0, 1.0);
}
#endif
