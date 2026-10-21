// 먼 땅 보기(mountain-terrain 2026-10-21) — 근·중경 지형(region_terrain)과 원경(region_far)이 같은 식을 쓴다.
//  · 공기원근(aer_haze): 물체(나무·건물)는 기존 안개(exp²)로 200m 남짓에서 사라지지만, 땅은 멀어질수록 옅어지기만 하고 끝까지 남는다
//    → 고을·길·들에서 실제 산줄기(걸어 갈 수 있는 그 땅)가 겹겹이 보인다. 골짜기(보는 이보다 낮은 땅)는 안개가 더 끼고,
//      높은 능선은 먹빛(far_ink) 쪽으로 — 산수화의 겹 능선.
//  · 수관(canopy_color): 나무를 그리지 않는 거리부터 숲 땅을 수관 빛(짙은 솔·참나무 잎 덩이)으로 바꾼다 — 먼 숲이 맨땅으로 보이지 않게.
//  · 지붕(roof_color): 건물이 안개에 묻히는 거리부터 처마 안 땅(땅 꾸밈 칠하기 R < 128)을 지붕 빛으로 — 먼 고을이 빈 마당으로 보이지 않게.
// 필요: global fog_density, region_common(r_hash·r_vnoise)

#include "res://shaders/region_aer.gdshaderinc"

uniform float canopy_d0 = 120.0;    // 이 거리(카메라 m)부터 숲 땅을 수관 빛으로(region_main: 식생 그리는 거리의 0.55)
uniform float canopy_d1 = 220.0;    // 여기서 다 바뀜(식생 그리는 거리)

// 수관 빛(선형이 아닌 sRGB 값 — 지형 색 col과 같은 공간). y: 게임 높이(높을수록 참나무·신갈 섞여 밝고 누렇게)
vec3 canopy_color(vec2 p, float y) {
	float a = r_vnoise(p * 0.13);                         // 나무 한 그루 크기(≈8m) 덩이
	float b = r_vnoise(p * 0.035 + vec2(13.0, 7.0));      // 숲 얼룩(솔밭·참나무 무리)
	vec3 pine = vec3(0.235, 0.318, 0.196);
	vec3 oak = vec3(0.345, 0.392, 0.224);
	vec3 c = mix(pine, oak, clamp(smoothstep(0.35, 0.75, b) * 0.7 + smoothstep(120.0, 420.0, y) * 0.5, 0.0, 1.0));
	float crown = smoothstep(0.35, 0.75, a);
	return c * (0.72 + 0.42 * crown);                     // 수관 위는 밝고 사이는 어둡다
}

// 지붕 빛(초가·기와 섞임): 처마 안(d < 0)
vec3 roof_color(vec2 p) {
	float h = r_vnoise(p * 0.08);
	return mix(vec3(0.62, 0.53, 0.36), vec3(0.34, 0.34, 0.36), smoothstep(0.45, 0.6, h));
}
