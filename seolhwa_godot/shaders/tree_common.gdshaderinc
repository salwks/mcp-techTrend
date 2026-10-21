// 사실 나무 공용(trees-khs) — 곰솔(국가유산청 스캔)·참나무(CC0 잎) 카드 나무와 임포스터가 함께 쓴다.
//   scripts/materials.gd의 사실 빛(PBR_CODE·light)과 같은 식: 하늘빛(EMISSION) + 해(pbr_direct) + 안개·공기원근·먼 물체 녹임 + 가림 점무늬.
//   LOD 섞기: 인스턴스(나무 하나) 단위 거리로 점무늬 교차(가까운 벌 ↔ 먼 벌이 같은 문턱의 반대쪽을 그려 빈틈·겹침이 없다).
//   메시 CUSTOM0 = (x 높이 비 0~1, y 가지 흔들림 0~1, z 카드 위상 0~1, w 잎 떨림 0~1), COLOR = (r 수관 그늘 AO, g 카드 색 난수, b 잎(1)·껍질(0), a 날씨 받음)
#ifndef TREE_COMMON
#define TREE_COMMON
#define LOOK_PBR
#include "res://shaders/pbr_common.gdshaderinc"

global uniform vec3 hemi_sky;
global uniform vec3 hemi_ground;
global uniform float hemi_i;
global uniform vec3 fog_color;
global uniform float fog_density;
global uniform float aer_k;
global uniform vec2 obj_fade;
global uniform float fog_base;
global uniform vec3 occ_a;
global uniform vec3 occ_b;
global uniform float occ_r;
global uniform float occ_near;
global uniform float wet;
global uniform float snow;
global uniform float snow_line;

// 거리 띠(카메라 → 나무 밑동): x,y = 들어오는 점무늬 구간(이 아래는 안 그림), z,w = 나가는 구간(이 위는 안 그림). 들어옴이 없으면 x=y=-1
uniform vec4 lod_band = vec4(-1.0, -1.0, 1e6, 1e6);
uniform float wind_k = 0.35;        // 바람 세기(0 고요 ~ 1 강풍) — tree_lod.gd가 날씨에서 넣는다
uniform vec2 wind_dir = vec2(0.86, 0.5);

const float T_BAYER[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

float tree_hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

// 인스턴스 거리로 띠 판정: in(0~1)·out(0~1). 아예 안 보이면 false(꼭짓점을 한 점으로 모아 래스터 비용을 없앤다)
bool tree_band(float d, out float s_in, out float s_out) {
	s_in = lod_band.x < 0.0 ? 1.0 : smoothstep(lod_band.x, lod_band.y, d);
	s_out = smoothstep(lod_band.z, lod_band.w, d);
	return s_in > 0.0 && s_out < 1.0;
}

// 점무늬: 들어올 때는 (1-b) < s_in, 나갈 때는 b < 1 - s_out — 이웃 띠(같은 구간의 나감/들어옴)와 정확히 갈린다
void tree_dither(vec2 fc, float s_in, float s_out) {
	if (s_in >= 1.0 && s_out <= 0.0) return;
	ivec2 q = ivec2(fc) % 4;
	float b = (T_BAYER[q.y * 4 + q.x] + 0.5) / 16.0;
	if (1.0 - b >= s_in || b >= 1.0 - s_out) discard;
}

// 바람(세계 변위): 줄기 흔들림(높이²) + 가지 출렁임 + 잎 떨림. ph 나무 위상, H 나무 키(m)
vec3 tree_wind(vec4 c0, vec3 wp, vec3 nrm_w, float ph, float H, float t) {
	vec2 wd = normalize(wind_dir);
	float k = wind_k;
	float gust = 0.65 + 0.35 * sin(t * 0.23 + ph * 2.1) * sin(t * 0.37 + wp.x * 0.01);
	float trunk = (sin(t * 0.55 + ph * 6.28) * 0.6 + sin(t * 1.13 + ph * 3.1) * 0.4 + 0.6) * k * gust;
	vec3 d = vec3(wd.x, 0.0, wd.y) * trunk * 0.011 * H * c0.x * c0.x;
	float br = sin(t * 1.6 + ph * 6.28 + dot(wp.xz, vec2(0.21, 0.17))) * 0.5 + sin(t * 2.7 + c0.z * 6.28) * 0.3;
	d += (vec3(wd.x, 0.15, wd.y) * 0.6 + vec3(0.0, 0.4, 0.0)) * br * c0.y * 0.09 * (0.3 + k) * gust;
	float fl = sin(t * 7.3 + c0.z * 31.0 + wp.y) * sin(t * 4.1 + c0.z * 13.0);
	d += nrm_w * fl * c0.w * 0.035 * (0.25 + k);
	return d;
}

// 가림 점무늬(scripts/materials.gd DITHER와 같은 식)
void tree_occ(vec3 owp, vec2 fc) {
	if (occ_r > 0.0 || occ_near > 0.0) {
		float keep = 1.0;
		if (occ_r > 0.0) {
			vec3 ab = occ_b - occ_a;
			float ot = clamp(dot(owp - occ_a, ab) / max(dot(ab, ab), 1e-4), 0.0, 0.92);
			float od = length(owp - (occ_a + ab * ot));
			keep = smoothstep(occ_r * 0.55, occ_r, od);
		}
		if (occ_near > 0.0) keep = min(keep, smoothstep(6.0 * occ_near, 12.0 * occ_near, length(owp - occ_a)));
		ivec2 q = ivec2(fc) % 4;
		if ((T_BAYER[q.y * 4 + q.x] + 0.5) / 16.0 > keep) discard;
	}
}

// 안개·공기원근·먼 물체 녹임(scripts/materials.gd FOG_CODE와 같은 식) — 돌려주는 값을 FOG에
vec4 tree_fog(vec3 vtx, vec3 wp, vec3 cam) {
	float fog_d = -vtx.z;
	float fog_f = 1.0 - exp(-fog_density * fog_density * fog_d * fog_d);
	float fog_mist = fog_density * 24.0 * (1.0 - smoothstep(fog_base - 2.0, fog_base + 7.0, wp.y)) * smoothstep(14.0, 48.0, fog_d);
	fog_f = 1.0 - (1.0 - fog_f) * (1.0 - clamp(fog_mist, 0.0, 0.8));
	if (aer_k > 0.0) {
		float aer_hz = 0.86 * (1.0 - exp(-fog_d * max(fog_density, 1e-4) / (1900.0 * 0.0085)));
		fog_f = mix(fog_f, max(min(fog_f, 0.55), aer_hz), aer_k);
	}
	return vec4(pbr_fog_color(fog_color, normalize(wp - cam)), fog_f);
}
#define TREE_FADE_DISCARD(fd, fc) if ((fd) > obj_fade.x && fract(sin(dot(floor(fc), vec2(12.9898, 78.233))) * 43758.5453) < smoothstep(obj_fade.x, obj_fade.y, (fd))) discard;

// 하늘빛(난반사·정반사 환경) — EMISSION에
vec3 tree_ambient(vec3 alb, vec3 n_view, vec3 v_view, mat4 inv_view, float rough, float ao, float spec_k) {
	vec3 nw = normalize((inv_view * vec4(n_view, 0.0)).xyz);
	vec3 vw = normalize((inv_view * vec4(v_view, 0.0)).xyz);
	vec3 irr = pbr_irr(nw, hemi_sky, hemi_ground, fog_color, hemi_i);
	float nv = max(dot(nw, vw), 1e-3);
	vec2 AB = pbr_env_brdf(nv, rough);
	vec3 env = mix(pbr_sky(reflect(-vw, nw), hemi_sky, hemi_ground, fog_color, hemi_i), irr / PI, rough * rough);
	return alb * irr * ao * amb_k / PI + env * (0.04 * AB.x + AB.y) * ao * spec_k;
}

// 해·등불: 램버트+GGX(pbr_direct) + 잎 비침(역광 — 해를 등진 잎이 햇빛에 노랗게 밝다)
void tree_light(vec3 N, vec3 L, vec3 V, vec3 lc, float att, bool dirl, float rough, float trans, vec3 alb, inout vec3 dl, inout vec3 sl) {
	vec3 d0 = vec3(0.0), s0 = vec3(0.0);
	float a = att * (dirl ? sun_k : 1.0);
	pbr_direct(N, L, V, lc, a, rough, trans * 0.6, d0, s0);
	if (trans > 0.0) {
		float back = pow(max(dot(-V, L), 0.0), 5.0);
		d0 += a * lc / (PI * PI) * trans * back * 0.9 * vec3(0.9, 1.0, 0.6);
	}
	dl += d0; sl += s0;
}
#endif
