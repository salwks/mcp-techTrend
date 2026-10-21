// 사진 스캔 PBR 층(integ-mountain, CC0 — Poly Haven · ambientCG). 지형(region_terrain → ground_real)과 키트 바위·벼랑(materials.gd PBR_CODE)이 함께 쓴다.
//   텍스처: assets/pbr_scan/scan_a.res(rgb sRGB 바탕색, a 높이) · scan_b.res(r 거칠기, g 법선 y(GL), b AO, a 법선 x) — tools/pbr_scan/{fetch.py, pack_maps.py, pack.gd}
//   출처·라이선스: assets/pbr_scan/manifest.json. 층 순서는 tools/pbr_scan/fetch.py LAYERS와 같다.
#ifndef PBR_SCAN
#define PBR_SCAN

global uniform sampler2DArray scan_a : filter_linear_mipmap_anisotropic, repeat_enable;
global uniform sampler2DArray scan_b : filter_linear_mipmap_anisotropic, repeat_enable;
global uniform float scan_on;   // 1 = 스캔 층 씀(텍스처가 있을 때 — scripts/render/pbr.gd), 0 = 예전 구운 층

const int S_GRANITE = 0; const int S_MOSSROCK = 1; const int S_FOREST = 2; const int S_LITTER = 3;
const int S_TRAIL = 4; const int S_MASATO = 5; const int S_PEBBLE = 6;
//                                  화강암 이끼바위 숲바닥 낙엽  산길흙 마사토 냇돌
const float S_TILE[7] = float[](    4.0,   3.0,    3.0,   2.5,  3.0,   3.0,   1.6);
// 바탕색 배율(선형 평균을 실제 땅 밝기로): 화강암은 풍화된 밝은 회색, 숲 바닥은 짙게, 마사토는 덜 노랗게
const vec3 S_GAIN[7] = vec3[](vec3(2.0, 2.0, 2.05), vec3(1.0, 1.0, 1.05), vec3(0.5, 0.56, 0.75), vec3(0.42, 0.6, 0.78),
	vec3(0.75, 0.75, 0.8), vec3(0.55, 0.44, 0.42), vec3(0.85, 0.88, 0.92));   // 마사토: 회갈색으로 어둡게(밝은 모래빛이 사막처럼 읽혔다)

struct ScanS { vec3 alb; float h; float r; float ao; vec2 n; };

ScanS scan_s(int l, vec2 uvm, vec2 gx, vec2 gy) {
	float t = S_TILE[l];
	vec3 c = vec3(uvm / t, float(l));
	vec4 a = textureGrad(scan_a, c, gx / t, gy / t);
	vec4 b = textureGrad(scan_b, c, gx / t, gy / t);
	ScanS s;
	s.alb = pow(a.rgb, vec3(2.2)) * S_GAIN[l];
	s.h = a.a; s.r = b.r; s.ao = b.b;
	s.n = vec2(b.a, b.g) * 2.0 - 1.0;
	return s;
}

// 높이 섞기: k(0~1 바탕 비율)에 두 층 높이 차를 더해 경계가 돌·잎 모양을 따라가게
float scan_hk(float k, float ha, float hb, float sharp) {
	return smoothstep(0.5 - 0.5 / sharp, 0.5 + 0.5 / sharp, k + (hb - ha) * 0.5 * (1.0 - abs(k * 2.0 - 1.0)) * 1.6);
}

ScanS scan_mix(ScanS a, ScanS b, float k) {
	ScanS o;
	o.alb = mix(a.alb, b.alb, k); o.h = mix(a.h, b.h, k); o.r = mix(a.r, b.r, k); o.ao = mix(a.ao, b.ao, k); o.n = mix(a.n, b.n, k);
	return o;
}

// 세 축 투영(벼랑·바위 메시, 가파른 지형): 세계 법선 nw를 돌려준다(UDN 섞기). sc = 크기 배율(1 = 층 기본 크기)
ScanS scan_tri(int l, vec3 wp, vec3 n, float sc, out vec3 nw) {
	vec3 w = pow(abs(n), vec3(4.0)); w /= (w.x + w.y + w.z);
	float t = S_TILE[l] * sc;
	ScanS o; o.alb = vec3(0.0); o.h = 0.0; o.r = 0.0; o.ao = 0.0; o.n = vec2(0.0);
	vec3 acc = vec3(0.0);
	if (w.x > 0.02) {
		vec4 a = texture(scan_a, vec3(wp.zy / t, float(l))); vec4 b = texture(scan_b, vec3(wp.zy / t, float(l)));
		vec2 tn = vec2(b.a, b.g) * 2.0 - 1.0;
		o.alb += a.rgb * w.x; o.h += a.a * w.x; o.r += b.r * w.x; o.ao += b.b * w.x;
		acc += vec3(0.0, tn.y, tn.x * sign(n.x)) * w.x;
	}
	if (w.y > 0.02) {
		vec4 a = texture(scan_a, vec3(wp.xz / t, float(l))); vec4 b = texture(scan_b, vec3(wp.xz / t, float(l)));
		vec2 tn = vec2(b.a, b.g) * 2.0 - 1.0;
		o.alb += a.rgb * w.y; o.h += a.a * w.y; o.r += b.r * w.y; o.ao += b.b * w.y;
		acc += vec3(tn.x, 0.0, tn.y) * w.y;
	}
	if (w.z > 0.02) {
		vec4 a = texture(scan_a, vec3(wp.xy / t, float(l))); vec4 b = texture(scan_b, vec3(wp.xy / t, float(l)));
		vec2 tn = vec2(b.a, b.g) * 2.0 - 1.0;
		o.alb += a.rgb * w.z; o.h += a.a * w.z; o.r += b.r * w.z; o.ao += b.b * w.z;
		acc += vec3(tn.x * sign(n.z), tn.y, 0.0) * w.z;
	}
	o.alb = pow(o.alb, vec3(2.2)) * S_GAIN[l];
	nw = normalize(n + acc * 1.3);
	return o;
}
#endif
