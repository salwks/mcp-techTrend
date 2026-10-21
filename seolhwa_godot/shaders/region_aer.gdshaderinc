// 공기원근(mountain-terrain 2026-10-21) — 땅·물·논밭 셰이더가 같은 식을 쓴다(region_far_look·water_common·region_farm).
// 물체(나무·건물)는 기존 안개(exp²)로 200m 남짓에서 사라지지만 땅은 멀어질수록 옅어지기만 하고 끝까지 남는다.
// 필요: 없음(fog_density는 부르는 쪽이 넘긴다)
global uniform float aer_k;         // 1 = 공기원근 켬(산 지형 권역 — region_main), 0 = 예전 안개 그대로(다른 권역·--noaer)
const float AER_PLATEAU = 0.55;    // 가까운 안개(exp²)가 여기까지만 짙어지고(약 110m), 그 너머는 먼 거리 공기원근이 맡는다

// 땅 안개 비율: 가까이는 예전 안개(exp²) 그대로, 약 110m부터는 AER_PLATEAU에서 멈추고, 수 km에 걸쳐 공기원근으로 옅어진다
//   (물체 재질 Materials.FOG_CODE·캐릭터·키트 물도 같은 식 — 같은 거리의 나무와 땅이 같은 만큼 흐리다)
float aer_haze(float fog_f, float d, float y, float base, float dens) {
	if (aer_k <= 0.0) return fog_f;
	float L = 1400.0 * 0.0085 / max(dens, 1e-4);
	float hz = 0.93 * (1.0 - exp(-d / L));
	// 골짜기 안개: 보는 이(발)보다 낮은 먼 땅
	float low = 1.0 - smoothstep(-40.0, 50.0, y - base);
	hz = 1.0 - (1.0 - hz) * (1.0 - 0.35 * low * smoothstep(150.0, 700.0, d));
	return mix(fog_f, max(min(fog_f, AER_PLATEAU), hz), aer_k);
}

// 안개 빛: 멀고 높은 능선일수록 먹빛 쪽(겹 능선), 낮은 골짜기는 안개빛
vec3 aer_tint(vec3 fog_c, vec3 ink, float d, float y, float base, float ny) {
	if (aer_k <= 0.0) return fog_c;
	float far = smoothstep(150.0, 900.0, d);
	float hrel = smoothstep(-20.0, 220.0, y - base);
	float steep = 1.0 - smoothstep(0.55, 0.95, ny);
	return mix(fog_c, ink, far * clamp(0.16 + 0.42 * hrel + 0.14 * steep, 0.0, 0.66));
}

