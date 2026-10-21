// 사실적 재질·빛 공용(material-lighting) — 키트·glTF 재질(scripts/materials.gd world_shader)과 지형(region_terrain)이 함께 쓴다.
// 층 번호 M_* 와 표 MP_* 는 scripts/render/pbr.gd LAYERS 순서와 같다. 텍스처는 tools/matlight/bake_pbr.gd가 굽는다.
//   pbr_a: rgb 바탕색 배율/2, a 높이   pbr_b: r 거칠기, g 법선 y, b 오목(AO), a 법선 x
// 전역 값(project.godot [shader_globals] · scripts/render/look.gd가 넣는다):
//   look_pbr 1 사실 재질·빛 / 0 예전 붓 바림(툰) · pbr_q 1 높음(시차 매핑) / 0 낮음 · sun_dir(해 쪽 단위 벡터)·sun_col(색×세기)
//   shelter_*: 처마 부호 거리(region_world.dress_tex — 배치 로더가 칠한 건물 처마 선). 처마 안 = 비·눈·하늘빛이 덜 든다
#ifndef PBR_COMMON
#define PBR_COMMON

global uniform float look_pbr;
global uniform float pbr_q;
global uniform vec3 sun_dir;
global uniform vec3 sun_col;
global uniform float amb_k;
global uniform vec3 sky_top;   // 하늘 그림판과 같은 하늘빛(복사휘도) — 반사(젖은 땅·물 고임·기와)에 쓴다
global uniform vec3 sky_hor;
global uniform sampler2DArray pbr_a : filter_linear_mipmap_anisotropic, repeat_enable;
global uniform sampler2DArray pbr_b : filter_linear_mipmap_anisotropic, repeat_enable;
global uniform sampler2D pbr_ids : filter_nearest, repeat_disable;
global uniform sampler2D shelter_tex : filter_linear, repeat_disable;
global uniform vec4 shelter_meta;   // x0, z0, 1/칸, 켜짐(1)
global uniform vec2 shelter_size;

const int M_PLASTER = 0; const int M_MUD = 1; const int M_THATCH = 2; const int M_TILE = 3; const int M_WOOD = 4;
const int M_MARU = 5; const int M_PAPER = 6; const int M_STONE = 7; const int M_ROCK = 8; const int M_PAVING = 9;
const int M_DIRT = 10; const int M_PATH = 11; const int M_GRASS = 12; const int M_JANGPAN = 13; const int M_BARK = 14;
const int M_FOLIAGE = 15; const int M_CLOTH = 16; const int M_SNOW = 17;
//                                 회벽  흙벽  이엉  기와  나무  마루  한지  돌    바위  박석  흙    길    풀    장판  껍질  잎    천    눈
const float MP_TILE[18]   = float[](2.0,  1.5,  1.0,  1.0,  1.0,  1.0,  0.5,  1.2,  2.0,  2.5,  2.0,  2.0,  1.0,  0.6,  1.0,  0.5,  0.25, 1.5);
const float MP_DEPTH[18]  = float[](0.008,0.04, 0.05, 0.004,0.012,0.004,0.0015,0.06,0.05, 0.035,0.03, 0.02, 0.03, 0.001,0.03, 0.004,0.0015,0.015);
// 아틀라스 붓 무늬를 얼마나 남길까(0 = 칸 평균색, 1 = 그대로) — 붓 획(돌·바위·흙)은 줄이고 짜임 무늬(창살·기와골·널)는 남긴다
const float MP_KEEP[18]   = float[](1.0,  0.4,  0.55, 0.95, 0.5,  0.85, 1.0,  0.3,  0.3,  1.0,  1.0,  1.0,  1.0,  1.0,  0.6,  1.0,  1.0,  1.0);
// 아틀라스 밝기 → 높이(m): +밝을수록 솟음(기와 수키와), -어두울수록 솟음(창살·널 이음은 어두운 쪽이 앞)
const float MP_ARELIEF[18]= float[](0.0,  0.0,  0.012,0.06, 0.0,  -0.004,-0.012,0.0, 0.0,  0.0,  0.0,  0.0,  0.0,  -0.002,0.0, 0.0,  0.0,  0.0);
const float MP_POROUS[18] = float[](0.5,  0.8,  0.6,  0.25, 0.55, 0.2,  0.4,  0.35, 0.3,  0.35, 0.8,  0.7,  0.3,  0.05, 0.5,  0.1,  0.7,  0.0);
const float MP_WETGLOSS[18]=float[](0.35, 0.5,  0.25, 0.95, 0.6,  0.7,  0.1,  0.85, 0.85, 0.9,  0.6,  0.8,  0.5,  0.3,  0.5,  0.7,  0.1,  0.0);
const float MP_TRANS[18]  = float[](0.0,  0.0,  0.04, 0.0,  0.0,  0.0,  0.55, 0.0,  0.0,  0.0,  0.0,  0.0,  0.2,  0.0,  0.0,  0.35, 0.25, 0.1);
const float MP_POM[18]    = float[](0.0,  1.0,  1.0,  1.0,  0.0,  0.0,  0.0,  1.0,  1.0,  1.0,  0.0,  0.0,  0.0,  0.0,  1.0,  0.0,  0.0,  0.0);
const vec3 SNOW_ALB = vec3(0.80, 0.84, 0.90);

// 처마 부호 거리(m, 안쪽 음수). 칠하기가 없으면 9
float pbr_eave_sd(vec3 wp) {
	if (shelter_meta.w < 0.5) return 9.0;
	vec2 t = ((wp.xz - shelter_meta.xy) * shelter_meta.z + 0.5) / shelter_size;
	return (texture(shelter_tex, t).r * 255.0 - 128.0) / 16.0;
}

// 미분으로 만든 접선 틀(T, B는 단위, N 그대로) — 키트에는 접선이 없고 UV가 아틀라스 칸이라 화면 미분으로 얻는다
mat3 pbr_frame(vec3 N, vec3 p, vec2 uv) {
	vec3 dp1 = dFdx(p), dp2 = dFdy(p);
	vec2 du1 = dFdx(uv), du2 = dFdy(uv);
	vec3 d2p = cross(dp2, N), d1p = cross(N, dp1);
	vec3 T = d2p * du1.x + d1p * du2.x;
	vec3 B = d2p * du1.y + d1p * du2.y;
	float lt = length(T), lb = length(B);
	T = lt > 1e-9 ? T / lt : vec3(1.0, 0.0, 0.0);
	B = lb > 1e-9 ? B / lb : cross(N, T);
	return mat3(T, B, N);
}

// 반사에 비치는 하늘(복사휘도): 하늘 그림판과 같은 색(sky_top·sky_hor), 아래는 땅빛(받는 빛/π)
vec3 pbr_sky(vec3 d, vec3 hs, vec3 hg, vec3 fc, float hi) {
	vec3 up = mix(sky_hor, sky_top, smoothstep(0.0, 0.6, d.y)) * 0.85;
	vec3 dn = (hg + sun_col * max(sun_dir.y, 0.0) * 0.06) * hi / PI;
	return mix(dn, up, smoothstep(-0.2, 0.06, d.y));
}
// 받는 빛(난반사 고루기): 하늘 반구 + 땅 반사(해 튐) + 해 쪽 하늘이 조금 밝다
vec3 pbr_irr(vec3 n, vec3 hs, vec3 hg, vec3 fc, float hi) {
	vec3 sky = mix(hg + sun_col * max(sun_dir.y, 0.0) * 0.07, mix(fc, hs, 0.65), 0.5 * n.y + 0.5);
	vec3 sflat = normalize(vec3(sun_dir.x, 0.25, sun_dir.z));
	sky += sun_col * 0.035 * max(dot(n, sflat), 0.0) * smoothstep(-0.05, 0.2, sun_dir.y);
	return sky * hi;
}
vec2 pbr_env_brdf(float nv, float r) {
	const vec4 c0 = vec4(-1.0, -0.0275, -0.572, 0.022);
	const vec4 c1 = vec4(1.0, 0.0425, 1.04, -0.04);
	vec4 rr = r * c0 + c1;
	float a004 = min(rr.x * rr.x, exp2(-9.28 * nv)) * rr.x + rr.y;
	return vec2(-1.04, 1.04) * a004 + rr.zw;
}

// 안개 빛깔: 해 쪽으로는 볕을 머금은 빛(대기 원근 — 해 질 녘 역광 능선이 붉게 녹는다)
vec3 pbr_fog_color(vec3 fc, vec3 vdir_w) {
#ifndef LOOK_PBR
	return fc;
#endif
	float mie = pow(max(dot(vdir_w, sun_dir), 0.0), 8.0) * smoothstep(-0.05, 0.15, sun_dir.y);
	return fc + sun_col * mie * 0.05;
}

// 젖음·눈(재질 위에 덮는다). n_w 기하 법선(세계), h 높이 0~1, cover 날씨 받는 정도(버텍스 알파), sd 처마 거리
// in/out: alb 바탕색, rough 거칠기, nmix(1 = 디테일 법선 그대로, 0 = 평평하게), out: snow 덮임
void pbr_weather(int id, vec3 wp, vec3 n_w, float h, float cover, float sd, float wet_v, float snow_v, float snow_line_v,
		inout vec3 alb, inout float rough, inout float nmix, inout float trans, out float s_cov, out float puddle) {
	s_cov = 0.0; puddle = 0.0;
	bool roof = id == M_THATCH || id == M_TILE || id == M_FOLIAGE || id == M_BARK;   // 지붕·나무는 처마 '밑'이 아니다(그 자체가 지붕)
	float under = roof ? 0.0 : smoothstep(0.15, -0.45, sd);   // 처마 밑
	float up = smoothstep(0.2, 0.75, n_w.y);
	float side = 1.0 - smoothstep(0.35, 0.8, abs(n_w.y));
	if (wet_v > 0.001) {
		// 위를 본 면: 처마 밖은 다 젖고, 처마 밑은 마른다 · 벽: 빗줄기 얼룩(세로) — 처마 밑 벽은 아래쪽 튄 물만
		float streak = smoothstep(0.35, 0.75, sin(dot(wp.xz, vec2(7.1, 5.3)) + sin(wp.y * 0.9 + dot(wp.xz, vec2(1.3, 2.1))) * 1.5) * 0.5 + 0.5);
		float w_up = up * (1.0 - under);
		float w_side = side * mix(0.55 + 0.45 * streak, 0.25 * streak, under);
		float w = clamp(max(w_up, w_side), 0.0, 1.0) * wet_v * cover;
		int i = clamp(id, 0, 17);
		alb *= 1.0 - 0.45 * MP_POROUS[i] * w;
		rough = mix(rough, mix(rough, 0.22, MP_WETGLOSS[i]), w);
		// 물 고임: 낮은 데부터(높이·젖음) — 평평하고 처마 밖
		float flat_k = smoothstep(0.86, 0.97, n_w.y) * (1.0 - under);
		float level = 0.1 + 0.24 * wet_v;
		puddle = (1.0 - smoothstep(level - 0.1, level, h)) * flat_k * wet_v * cover * step(0.3, MP_WETGLOSS[i]);
		alb *= 1.0 - 0.35 * puddle;
		rough = mix(rough, 0.03, puddle);
		nmix *= 1.0 - puddle;
	}
	float sc = max(snow_v, smoothstep(snow_line_v, snow_line_v + 30.0, wp.y));
	if (sc > 0.001) {
		// 눈: 위를 본 면 · 처마 밖 · 오목한 데부터 찬다(높이가 낮을수록 먼저). 처마 밑은 비워 둔다
		float nz = sin(wp.x * 1.3 + sin(wp.z * 0.7)) * 0.25 + sin(wp.z * 1.1 + sin(wp.x * 0.9)) * 0.25;
		float s = sc * 1.45 - 0.35 + (0.5 - h) * 0.55 + nz * 0.3;
		s_cov = clamp(s * 2.2, 0.0, 1.0) * smoothstep(0.25, 0.7, n_w.y) * (1.0 - under) * cover;
		alb = mix(alb, SNOW_ALB, s_cov);
		rough = mix(rough, 0.82, s_cov);
		nmix = mix(nmix, 0.35, s_cov);
		trans = mix(trans, 0.18, s_cov);
	}
}

// 빗방울 동심원(물 고인 데): 0.35m 칸마다 하나, 기울기(접선 xy)를 돌려준다
vec2 pbr_ripple(vec2 p, float tm) {
	vec2 q = p / 0.35;
	vec2 c = floor(q);
	vec2 acc = vec2(0.0);
	for (int y = 0; y <= 1; y++) for (int x = 0; x <= 1; x++) {
		vec2 ci = c + vec2(float(x), float(y));
		vec2 hh = fract(sin(vec2(dot(ci, vec2(127.1, 311.7)), dot(ci, vec2(269.5, 183.3)))) * 43758.5453);
		float ph = fract(tm * 0.9 + hh.x);
		vec2 d = (q - ci - hh * 0.6) * 0.35;
		float r = length(d);
		float rr = ph * 0.22;
		float w = sin((r - rr) * 90.0) * (1.0 - ph) * (1.0 - smoothstep(0.0, 0.035, abs(r - rr)));
		acc += (r > 1e-4 ? d / r : vec2(0.0)) * w;
	}
	return acc * 0.35;
}

// 직접광(해·등불): 램버트 + GGX. 밝기 규칙은 툰과 같다(LIGHT_COLOR/π² = 색×세기/π)
void pbr_direct(vec3 N, vec3 L, vec3 V, vec3 lc, float att, float rough, float trans, inout vec3 dl, inout vec3 sl) {
	float ndl = dot(N, L);
	float nl = max(ndl, 0.0);
	vec3 Ei = att * lc / (PI * PI);
	dl += Ei * (nl + trans * max(-ndl, 0.0) * 0.8);
	if (nl > 0.0) {
		vec3 H = normalize(L + V);
		float nh = max(dot(N, H), 0.0), nv = max(dot(N, V), 1e-3), vh = max(dot(V, H), 0.0);
		float a = max(rough * rough, 0.002);
		float a2 = a * a;
		float d = nh * nh * (a2 - 1.0) + 1.0;
		float D = a2 / (PI * d * d);
		float k = a * 0.5;
		float Vis = 0.25 / ((nl * (1.0 - k) + k) * (nv * (1.0 - k) + k));
		float F = 0.04 + 0.96 * pow(1.0 - vh, 5.0);
		sl += Ei * PI * D * Vis * F * nl;
	}
}
#endif
