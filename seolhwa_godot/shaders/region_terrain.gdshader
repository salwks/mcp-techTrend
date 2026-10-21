// 권역 지형 — 타일 격자 메시(평평한 정수 격자)를 정점 셰이더에서 높이맵으로 세운다.
// 재질은 Materials 툰 셰이더와 같은 규칙: 붓 바림 램프(LIGHT_COLOR/π²) + 반구광(EMISSION = base·hemi/π) + 높이 안개.
// 색은 웹 terrain.js의 들판·숲·길·바위 색을 토지이용별로 고르고, 웹 땅 붓 텍스처(ground.png, 7m 반복)를 곱한다.
shader_type spatial;
render_mode cull_back;
#define LOOK_PBR   // 사실 재질·빛 — --look=ink면 scripts/render/pbr.gd가 이 줄을 빼고 컴파일한다

#include "res://shaders/region_common.gdshaderinc"
#include "res://shaders/pbr_common.gdshaderinc"
#include "res://shaders/pbr_scan.gdshaderinc"
#include "res://shaders/region_far_look.gdshaderinc"

global uniform vec3 hemi_sky;
global uniform vec3 hemi_ground;
global uniform float hemi_i;
global uniform vec3 fog_color;
global uniform float fog_density;
global uniform float wet;        // 젖음 0~1(scripts/region/weather.gd)
global uniform float snow;       // 눈 덮기 0~1
global uniform float snow_line;  // 이 높이(y) 위는 잔설(고산 기후대) — 기본 1e5 = 없음

uniform sampler2D ground_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable, hint_default_white;
uniform sampler2D ramp_tex : filter_linear, repeat_disable;
uniform sampler2D paint_tex : filter_linear, repeat_disable; // 길·마당 칠하기(region_world._paint_roads, paint_yard)
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable; // 이음매 없는 잡음(픽셀 잡음을 해시 대신 텍스처로 — 빠르다)
uniform float grid_step = 1.0;     // 격자 간격(근경 1m, 중경 4m) — 법선 계산용
uniform float skirt = 6.0;         // 가장자리 치마(이음매 틈 가리기) 깊이
uniform vec3 far_ink = vec3(0.07, 0.085, 0.08); // 원경 먹빛(선형) — region_main이 시간대에 맞춰 넣는다
uniform float far_k = 0.0;         // 먼 능선을 먹빛으로 남기는 정도(0 = 기존 안개 그대로 — 식생·키트 재질과 맞추려면 0. 공용 안개에 같은 규칙이 들어오면 켠다)
uniform sampler2D dry_tex : filter_nearest, repeat_disable;   // 건천 바닥 칸(토지이용 격자, region_world.dry_mask)
uniform float has_dry = 0.0;
uniform float urban_ground = 0.0;  // 도시 땅이 있는 권역(배치 urban): 마당 흙(yd≈0) 위에서는 길섶 풀 띠를 끈다
// 논·밭 필지(scripts/region/farm.gd): 필지 합집합 부호 거리(2m, 128 + d·16). 근경에서 필지 안 땅은 내리고(필지 메시가 덮는다),
// 필지 밖에 남은 논·밭 칸은 풀밭으로 칠한다(흐린 필지 무늬 대신 경계는 메시가 만든다)
uniform sampler2D farm_tex : filter_linear, repeat_disable;
uniform vec4 farm_meta = vec4(0.0, 0.0, 0.5, 0.0);   // x0, z0, 1/cell
uniform vec2 farm_size = vec2(1.0);
uniform float farm_on = 0.0;
uniform sampler2D dress_tex : filter_linear, repeat_disable;   // 땅 꾸밈 칠하기(region_world.dbytes): 처마 부호 거리 · 장터 · 물가 · 박석
uniform float dress_on = 0.0;      // 꾸밈 칠하기가 있으면 1(배치 로더)
uniform float dress_far = 75.0;    // 이 너머(카메라 m)는 꾸밈 무늬를 그리지 않는다(설정 '화면 품질' 낮음이면 45)
uniform float near_detail = 0.0;   // 1인칭 가까운 땅 잔무늬(region_main — 눈높이 화면만 1, 3인칭 0). near_layer
uniform float mist_base = 0.0;     // 낮은 안개 기준 높이(플레이어 발 높이). 기존 Materials는 마을 바닥 y=0 기준         // 먼 능선을 먹빛으로 남기는 정도(0 = 기존 안개 그대로)

#include "res://shaders/ground_mask.gdshaderinc"

varying vec3 v_wp;
varying vec3 v_wn;

vec3 srgb(vec3 c) { return pow(c, vec3(2.2)); }

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX.x, 0.0, VERTEX.z, 1.0)).xyz;
	float h = r_height(wp.xz);
	float s = grid_step;
	float hl = r_height(wp.xz - vec2(s, 0.0)), hr = r_height(wp.xz + vec2(s, 0.0));
	float hd = r_height(wp.xz - vec2(0.0, s)), hu = r_height(wp.xz + vec2(0.0, s));
	vec3 n = normalize(vec3(hl - hr, 2.0 * s, hd - hu));
	float drop = VERTEX.y < -0.5 ? skirt : 0.0;
	if (farm_on > 0.5) {
		float fd = (textureLod(farm_tex, ((wp.xz - farm_meta.xy) * farm_meta.z + 0.5) / farm_size, 0.0).r * 255.0 - 128.0) / 16.0;
		if (fd < 0.1) drop += 6.0;
	}
	VERTEX.y = h - drop - MODEL_MATRIX[3].y;
	NORMAL = n;
	v_wp = vec3(wp.x, h - drop, wp.z);
	v_wn = n;
}

// 웹 terrain.js 색
const vec3 C_GRASS = vec3(0.616, 0.651, 0.420);   // #9da66b
const vec3 C_GRASS2 = vec3(0.525, 0.596, 0.361);  // #86985c
const vec3 C_DRY = vec3(0.710, 0.671, 0.463);     // #b5ab76
const vec3 C_FOREST = vec3(0.431, 0.478, 0.306);  // #6e7a4e
const vec3 C_FOREST2 = vec3(0.337, 0.388, 0.247); // #56633f
const vec3 C_LANE = vec3(0.788, 0.671, 0.471);    // #c9ab78
const vec3 C_PATH = vec3(0.714, 0.604, 0.408);    // #b69a68
const vec3 C_ROCK = vec3(0.557, 0.525, 0.463);    // #8e8676
const vec3 C_CLIFF = vec3(0.416, 0.396, 0.357);   // #6a655b
const vec3 C_BANK = vec3(0.659, 0.616, 0.518);    // #a89d84
const vec3 C_BED = vec3(0.365, 0.373, 0.325);     // #5d5f53
const vec3 C_PADDY = vec3(0.486, 0.416, 0.294);   // #7c6a4b
const vec3 C_HIGH = vec3(0.553, 0.576, 0.486);    // #8d937c
const vec3 C_SOIL = vec3(0.640, 0.540, 0.370);
const vec3 C_CROP = vec3(0.560, 0.610, 0.360);
const vec3 C_SAND = vec3(0.800, 0.760, 0.640);
const vec3 C_BAMBOO = vec3(0.400, 0.470, 0.280);
const vec3 C_BASALT = vec3(0.330, 0.320, 0.300);  // 건천 자갈(현무암)
const vec3 C_BASALT2 = vec3(0.420, 0.405, 0.375);
const vec3 C_BOULDER = vec3(0.560, 0.540, 0.500);


// 토지이용 한 칸의 색. water: 논물(하늘 반사) 비율을 돌려준다
vec3 lu_color(int c, vec2 p, float n1, float n2, vec4 cq, float block_edge, inout float water) {
	if (c == 0) return mix(C_FOREST, C_FOREST2, clamp(0.5 + n1 * 1.2, 0.0, 1.0));
	if (c == 1) {
		vec3 g = mix(C_GRASS, C_GRASS2, clamp(0.5 + n1, 0.0, 1.0));
		return mix(g, C_DRY, clamp(n2 * 0.4, 0.0, 0.35));
	}
	if (c == 2 || c == 3) {
		// 논·밭 필지: 48m 구역마다 등고선 방향으로 돌린 격자(긴 변이 등고선을 따름 — 다랑이처럼).
		// cq.xy = 구역 안 등고선 좌표, cq.zw = 구역 번호
		bool paddy = c == 2;
		vec2 sz = paddy ? vec2(24.0, 9.0) : vec2(28.0, 13.0);
		vec2 q = cq.xy / sz + vec2(r_vnoise(p * 0.05) * 0.18, 0.0);
		vec2 cell = floor(q);
		vec2 l = (q - cell) * sz;
		float edge = min(min(l.x, sz.x - l.x), min(l.y, sz.y - l.y));
		edge = min(edge, block_edge);
		float hsh = r_hash(ivec2(cell) + ivec2(cq.zw) * 97 + ivec2(91, 37));
		vec3 bund = mix(C_GRASS, C_GRASS2, 0.5 + 0.3 * n1);
		if (paddy) {
			float dyke = 1.0 - smoothstep(0.3, 0.55, edge);
			float flooded = step(0.5, hsh);
			float rows = smoothstep(0.55, 0.9, sin(cq.y * 7.0 + hsh * 6.0)) * 0.22;
			vec3 young = mix(mix(C_PADDY, C_CROP, 0.62 + n1 * 0.3), C_PADDY, rows);
			vec3 inner = mix(young, C_PADDY * 0.95, flooded);
			water += flooded * (1.0 - dyke) * (0.8 + 0.2 * n2);
			return mix(inner, bund, dyke);
		}
		// 밭: 등고선을 따르는 고랑(1.1m) 그늘 + 필지 경계 밭둑
		float st = sin(cq.y * 6.2832 / 1.1);
		float crop = r_hash(ivec2(cell) + ivec2(cq.zw) * 31 + ivec2(3, 77));
		vec3 field = crop > 0.4 ? mix(C_SOIL, C_CROP, 0.45 + 0.3 * crop) : C_SOIL * (0.95 + 0.1 * n1);
		field = mix(field, field * 0.8, smoothstep(0.4, 0.95, st) * 0.55);
		return mix(field, bund, 1.0 - smoothstep(0.3, 0.7, edge));
	}
	// 길 래스터(4m)는 밟힌 풀 정도로만 — 흙길은 region.json roads를 칠하기 텍스처로 또렷하게 그린다
	if (c == 4) return mix(mix(C_GRASS, C_GRASS2, clamp(0.5 + n1, 0.0, 1.0)), C_DRY, 0.35 + 0.15 * n2);
	if (c == 5) {
		// 건천(제주): 물 없는 현무암 바닥 — 짙은 자갈 바탕에 둥근 바위(밝은 윗면·먹빛 테)
		if (has_dry > 0.5 && texelFetch(dry_tex, clamp(ivec2(round((p - lu_meta.xy) * lu_meta.z)), ivec2(0), lu_size - 1), 0).r > 0.5) {
			vec3 grav = mix(C_BASALT, C_BASALT2, clamp(0.5 + n2 * 0.6, 0.0, 1.0));
			float bv = r_vnoise(p * 0.55) * 0.7 + r_vnoise(p * 1.6 + vec2(7.1, 3.3)) * 0.3;
			float rock = smoothstep(0.6, 0.66, bv);
			float rim = smoothstep(0.55, 0.6, bv) * (1.0 - rock);
			vec3 c5 = mix(grav, C_BOULDER * (0.9 + 0.2 * n1), rock);
			return mix(c5, C_BASALT * 0.6, rim * 0.7);
		}
		// 하상(mountain-terrain): 물에 닳은 둥근 돌·자갈 바닥 — 물이 반투명이라 비친다
		float bv = r_vnoise(p * 0.8) * 0.65 + r_vnoise(p * 2.1 + vec2(3.7, 1.9)) * 0.35;
		float st = smoothstep(0.56, 0.62, bv);
		vec3 bed = mix(C_BED, C_BED * 1.25, clamp(0.5 + n2, 0.0, 1.0));
		bed = mix(bed, C_BOULDER * (0.8 + 0.25 * n1), st);
		return mix(bed, C_BED * 0.6, (smoothstep(0.5, 0.55, bv) - st) * 0.6);
	}
	// 마을 터: 웹 마을 땅처럼 풀밭 + 마른 흙 얼룩(맨 흙은 건물 둘레·길에만 — 칠하기 텍스처)
	if (c == 6) {
		vec3 g = mix(C_GRASS, C_GRASS2, clamp(0.5 + n1, 0.0, 1.0));
		g = mix(g, C_DRY, clamp(n2 * 0.5 + 0.1, 0.0, 0.4));
		return mix(g, C_LANE, smoothstep(0.25, 0.55, n1 + n2 * 0.2) * 0.35);
	}
	if (c == 7) {
		// 드러난 바위(mountain-terrain): 화강암 바탕 + 층리(높이 따라 결) + 금(먹빛 갈라짐) + 이끼·지의 얼룩
		vec3 rk = mix(C_ROCK * 1.08, C_CLIFF, clamp(0.5 + n1 * 1.5, 0.0, 1.0));
		float strata = smoothstep(0.82, 0.95, fract(v_wp.y * 0.55 + r_vnoise(p * 0.12) * 1.4));
		rk = mix(rk, C_CLIFF * 0.72, strata * 0.55);
		float crack = 1.0 - smoothstep(0.0, 0.035, abs(r_vnoise(p * 0.35 + vec2(7.0, 2.0)) - 0.5));
		rk = mix(rk, vec3(0.20, 0.19, 0.18), crack * 0.5);
		return mix(rk, C_FOREST2 * 0.9, smoothstep(0.62, 0.8, r_vnoise(p * 0.07 + vec2(1.3, 9.1))) * 0.45);
	}
	if (c == 8) {
		// 자갈·모래 기슭 / 너덜: 모래 바탕에 둥근 돌(물가에서 멀수록 모난 돌이 많다 — 셰이더는 한 무늬)
		vec3 sb = mix(C_SAND, C_BANK, clamp(0.5 + n2, 0.0, 1.0));
		float gv = r_vnoise(p * 1.1) * 0.6 + r_vnoise(p * 3.0 + vec2(5.1, 2.3)) * 0.4;
		float pb = smoothstep(0.58, 0.64, gv);
		sb = mix(sb, C_BOULDER * (0.85 + 0.2 * n1), pb);
		return mix(sb, C_CLIFF * 0.7, (smoothstep(0.53, 0.58, gv) - pb) * 0.5);
	}
	return mix(C_BAMBOO, C_FOREST2, clamp(0.5 + n1, 0.0, 1.0));
}

// 이음매 없는 잡음 텍스처 한 장을 두 배율로 겹쳐 되풀이 무늬가 보이지 않게
float tn(vec2 uv) { return (texture(noise_tex, uv).r + texture(noise_tex, uv * 0.6180 + vec2(0.37, 0.71)).r - 1.0) * 1.15; }

// 선분 a→b까지 거리(x)와 선분 위 자리(y, 0~1)
vec2 seg_dt(vec2 q, vec2 a, vec2 b) {
	vec2 ab = b - a;
	float t = clamp(dot(q - a, ab) / max(dot(ab, ab), 1e-6), 0.0, 1.0);
	return vec2(length(q - a - ab * t), t);
}

// 1인칭 가까운 땅 잔무늬(C68): 카메라 0~9m는 다 보이고 9~15m에서 사라진다. 먹·한지 결로만(사진 텍스처 없음), 모두 세계 좌표 절차 무늬.
//   흙 알갱이(먹 점) · 잔돌(밝은 윗면 + 아래 먹 테) · 풀 포기(먹선 잎 다섯 가닥) · 흙길·마당 발자국과 끌린 자국 · 땅 붓 결 한 번 더(1.3m).
//   px = 화소 하나가 덮는 땅 크기(m): 화소보다 작아지는 무늬는 그 무늬만 먼저 지운다(비스듬한 먼 땅에서 반짝이지 않게).
//   dirt = 흙길·마당 비율, green = 풀빛 땅 비율(색에서), rdir = 길 방향(발자국·자국 방향).
vec3 near_layer(vec3 base, vec2 p, vec3 col, float dirt, float slope, vec2 rdir, float dist, float px, vec2 cam_xz) {
	float nk = near_detail * (1.0 - smoothstep(9.0, 15.0, dist));
	if (nk < 0.002) return base;
	float rocky = smoothstep(0.5, 1.0, slope);
	float green = clamp((col.g - col.r) * 9.0 + 0.4, 0.0, 1.0) * (1.0 - dirt) * (1.0 - rocky);
	// 1 흙 알갱이
	float gk = nk * (1.0 - smoothstep(0.012, 0.03, px));
	if (gk > 0.0) {
		float g1 = texture(noise_tex, p * 3.7).r, g2 = texture(noise_tex, p * 9.1 + vec2(0.3, 0.6)).r;
		float speck = smoothstep(0.64, 0.70, g1 * 0.45 + g2 * 0.55);
		float lite = smoothstep(0.32, 0.26, g2);
		base *= 1.0 - gk * 0.17 * speck * (0.45 + 0.55 * dirt) + gk * 0.07 * lite * dirt;
	}
	// 2 잔돌(0.55m 칸에 하나 — 흙·비탈에 많이): 잡음으로 일그러진 둥근 돌, 바탕 흙빛을 섞은 밝은 윗면 + 아래쪽 먹 테 + 옅은 그늘
	float sk = nk * (1.0 - smoothstep(0.03, 0.07, px));
	if (sk > 0.0) {
		vec2 q = p / 0.55;
		ivec2 ci = ivec2(floor(q));
		vec2 f = fract(q);
		float h0 = r_hash(ci + ivec2(17, 3)), h1 = r_hash(ci + ivec2(5, 41)), h2 = r_hash(ci + ivec2(29, 7));
		if (h0 < mix(0.08, 0.4, dirt) + 0.3 * rocky) {
			float r = (0.025 + 0.05 * h1 * h1 + 0.02 * h2) / 0.55;
			vec2 d = (f - (vec2(0.25) + vec2(h1, h2) * 0.5));
			float an = h0 * 40.0;
			d = mat2(vec2(cos(an), sin(an)), vec2(-sin(an), cos(an))) * d * vec2(1.0, 1.25 + 0.5 * h2);
			float dl = length(d) * (1.0 + 0.22 * (texture(noise_tex, p * 2.3 + vec2(h1, h2)).r - 0.5) * 2.0);
			float aa = px / 0.55;
			float body = 1.0 - smoothstep(r - aa, r + aa * 0.5, dl);
			float sh = (1.0 - smoothstep(r, r * 1.6 + aa, length(d - vec2(0.0, r * 0.45)))) * (1.0 - body);   // 남쪽 그늘
			float rim = smoothstep(r * 0.55, r, dl) * smoothstep(-0.4, 0.8, d.y / r);   // 아래쪽 먹 테
			float top = 1.0 - smoothstep(0.0, r * 0.8, length(d + vec2(0.0, r * 0.35)));   // 윗면 밝음
			vec3 stone = mix(base * 1.1, srgb(vec3(0.6, 0.58, 0.53)), 0.35 + 0.25 * h2) * (1.0 + 0.18 * top);
			stone = mix(stone, srgb(vec3(0.25, 0.23, 0.21)), rim * 0.7);
			base *= 1.0 - sh * sk * 0.25;
			base = mix(base, stone, body * sk * 0.9);
		}
	}
	// 3 풀 포기(0.45m 칸에 하나 — 풀빛 땅에서): 잎 3~6가닥을 카메라에서 먼 쪽으로 부채꼴로 — 눈높이에서 땅에 누운 획이 화면에서는 서 있는 잎처럼 보인다.
	//   뿌리 쪽 짙은 먹, 끝은 가늘고 옅게. fix-1017: 포기마다 크기·잎 수·부채 폭·빛깔을 달리하고, 발밑 1~3m는 성기게(눈앞 큰 별 무늬 없앰)
	float tk = nk * green * (1.0 - smoothstep(0.035, 0.09, px)) * smoothstep(1.0, 3.0, dist);
	if (tk > 0.01) {
		vec2 q = p / 0.45;
		ivec2 ci = ivec2(floor(q));
		vec2 f = fract(q);
		float h0 = r_hash(ci + ivec2(71, 13));
		if (h0 < 0.45) {
			float h1 = r_hash(ci + ivec2(59, 23)), h2 = r_hash(ci + ivec2(17, 83)), h3 = r_hash(ci + ivec2(97, 31));
			vec2 c = vec2(0.3) + vec2(r_hash(ci + ivec2(3, 97)), r_hash(ci + ivec2(41, 9))) * 0.4;
			vec2 cw = (vec2(ci) + c) * 0.45;
			vec2 away = normalize(cw - cam_xz + vec2(1e-4));
			float a0 = atan(away.y, away.x) + (r_hash(ci + ivec2(11, 5)) - 0.5) * 1.0;
			float sz = (0.12 + 0.3 * h1 * h1) / 0.45;
			int nb = 3 + int(h2 * 3.99);
			float spread = 0.8 + 0.9 * h3;
			float ink = 0.0, tipk = 0.0;
			for (int k = 0; k < 6; k++) {
				if (k >= nb) break;
				float fk2 = float(k) / float(nb - 1) - 0.5;
				float a = a0 + fk2 * spread + sin(float(k) * 2.7 + h0 * 9.0 + h2 * 4.0) * 0.25;
				float L = sz * (0.45 + 0.55 * fract(h0 * 7.3 + float(k) * 0.37 + h3)) * (1.0 - 0.35 * abs(fk2));
				vec2 b0 = c + vec2(-sin(a), cos(a)) * fk2 * 0.04;
				vec2 dt = seg_dt(f, b0, b0 + vec2(cos(a), sin(a)) * L);
				float w = ((0.008 + 0.006 * h1) * (1.0 - 0.8 * dt.y)) / 0.45;
				float m = 1.0 - smoothstep(w, w + px / 0.45, dt.x);
				if (m > ink) { ink = m; tipk = dt.y; }
			}
			vec3 root = mix(srgb(vec3(0.2, 0.24, 0.13)), srgb(vec3(0.34, 0.31, 0.17)), step(0.8, h3) * 0.8);
			vec3 tip = h2 < 0.5 ? srgb(C_GRASS2 * 0.75) : (h2 < 0.85 ? srgb(C_GRASS2 * vec3(0.95, 1.0, 0.8)) : srgb(vec3(0.6, 0.53, 0.3)));
			base = mix(base, mix(root, tip, tipk), ink * tk * (0.5 + 0.35 * h1) * (1.0 - 0.35 * tipk));
		}
	}
	// 4 발자국·끌린 자국(흙길·마당): 길 방향 0.36m 걸음으로 좌우 엇갈림, 옅게 눌린 흙 + 테
	float fk = nk * dirt * (1.0 - smoothstep(0.05, 0.12, px));
	if (fk > 0.01) {
		vec2 t = rdir;
		vec2 n = vec2(-t.y, t.x);
		vec2 lp = vec2(dot(p, t), dot(p, n));
		vec2 q = vec2(lp.x / 0.36, lp.y / 1.1);
		ivec2 ci = ivec2(floor(q));
		float h0 = r_hash(ci + ivec2(91, 23));
		if (h0 < 0.4) {
			float side = mod(float(ci.x), 2.0) < 0.5 ? -1.0 : 1.0;
			vec2 c = vec2((float(ci.x) + 0.5) * 0.36, (float(ci.y) + 0.5) * 1.1 + side * 0.1 + (h0 - 0.2) * 0.5);
			vec2 d = lp - c;
			float e = length(d / vec2(0.125, 0.048));
			float pr = 1.0 - smoothstep(0.85, 1.0, e);
			float rimp = smoothstep(0.55, 0.95, e) * pr;
			base *= 1.0 - fk * (0.09 * pr + 0.09 * rimp) * (0.6 + h0);
		}
		float st = texture(noise_tex, vec2(lp.x * 0.05, lp.y * 2.4)).r;
		base *= 1.0 - fk * 0.07 * smoothstep(0.62, 0.76, st);
	}
	// 5 땅 붓 결 한 번 더(7m 반복이 눈높이에서 무르게 보이던 것)
	vec3 gt2 = texture(ground_tex, p / 1.3 + vec2(0.37, 0.11)).rgb;
	base *= mix(vec3(1.0), gt2 / max(dot(gt2, vec3(0.333)), 0.05), 0.3 * nk);
	return base;
}


// ---- 땅 꾸밈(visual-pass 2026-10-17, 3인칭 거리) ----
// 잔돌: cell m 칸마다 하나(dens 확률), 반지름 rmin~rmax m. 밝은 윗면 + 아래 먹 테 + 남쪽 옅은 그늘. 화소보다 작아지면 지운다.
vec3 t_stones(vec3 base, vec2 p, float cell, float rmin, float rmax, float dens, float px, float k, int salt) {
	if (dens <= 0.002 || k <= 0.002) return base;
	float sk = k * (1.0 - smoothstep(rmin * 0.6, rmin * 1.4, px));
	if (sk <= 0.002) return base;
	vec2 q = p / cell;
	ivec2 ci = ivec2(floor(q));
	vec2 f = fract(q);
	float h0 = r_hash(ci + ivec2(17 + salt, 3)), h1 = r_hash(ci + ivec2(5, 41 + salt)), h2 = r_hash(ci + ivec2(29 + salt, 7));
	if (h0 >= dens) return base;
	float r = (rmin + (rmax - rmin) * h1 * h1) / cell;
	vec2 d = f - (vec2(0.3) + vec2(h1, h2) * 0.4);
	float an = h0 * 40.0 + h2 * 9.0;
	d = mat2(vec2(cos(an), sin(an)), vec2(-sin(an), cos(an))) * d * vec2(1.0, 1.2 + 0.5 * h2);
	if (dot(d, d) > r * r * 4.0) return base;   // 돌·그늘 밖
	float dl = length(d + vec2(d.y, -d.x) * (h2 - 0.5) * 0.3) * (1.0 + 0.12 * (h1 - 0.5));
	float aa = px / cell;
	float body = 1.0 - smoothstep(r - aa, r + aa * 0.5, dl);
	float sh = (1.0 - smoothstep(r, r * 1.7 + aa, length(d - vec2(0.0, r * 0.5)))) * (1.0 - body);
	float rim = smoothstep(r * 0.5, r, dl) * smoothstep(-0.3, 0.8, d.y / r);
	float top = 1.0 - smoothstep(0.0, r * 0.8, length(d + vec2(0.0, r * 0.35)));
	vec3 stone = mix(base * 1.08, srgb(vec3(0.62, 0.6, 0.55)), 0.4 + 0.3 * h2) * (1.0 + 0.2 * top);
	stone = mix(stone, srgb(vec3(0.24, 0.22, 0.2)), rim * 0.75);
	base *= 1.0 - sh * sk * 0.3;
	return mix(base, stone, body * sk);
}

// 풀 포기(먹선 잎 3~6가닥, 화면 위쪽 = 카메라에서 먼 쪽으로 부채꼴 — 비스듬히 내려다보면 서 있는 포기처럼 읽힌다)
//   fix-1017: 똑같은 별 모양이 되풀이되어 보이던 것 — 포기마다 크기(0.4~1.4배, 작은 것이 많게)·잎 수·부채 폭·기울기·빛깔(짙은 풀 · 연둣빛 · 마른 짚빛)·진하기를 달리한다
vec3 t_tufts(vec3 base, vec2 p, float cell, float size, float dens, float px, float k, vec2 away) {
	if (dens <= 0.002 || k <= 0.002) return base;
	float tk = k * (1.0 - smoothstep(0.03, 0.07, px));
	if (tk <= 0.002) return base;
	vec2 q = p / cell;
	ivec2 ci = ivec2(floor(q));
	vec2 f = fract(q);
	float h0 = r_hash(ci + ivec2(71, 13));
	if (h0 >= dens) return base;
	float h1 = r_hash(ci + ivec2(59, 23)), h2 = r_hash(ci + ivec2(17, 83)), h3 = r_hash(ci + ivec2(97, 31));
	vec2 c = vec2(0.3) + vec2(r_hash(ci + ivec2(3, 97)), r_hash(ci + ivec2(41, 9))) * 0.4;
	float a0 = atan(away.y, away.x) + (r_hash(ci + ivec2(11, 5)) - 0.5) * 1.3;
	float sz = size * (0.4 + 1.0 * h1 * h1) / cell;
	if (length(f - c) > sz * 1.05) return base;   // 포기 밖 화소는 잎 고리를 돌지 않는다(대부분)
	int nb = 3 + int(h2 * 3.99);                  // 잎 3~6
	float spread = 0.8 + 1.0 * h3;                // 부채 폭(라디안)
	float ink = 0.0, tipk = 0.0;
	for (int i = 0; i < 6; i++) {
		if (i >= nb) break;
		float fk = float(i) / float(nb - 1) - 0.5;
		float a = a0 + fk * spread + sin(float(i) * 2.7 + h0 * 9.0 + h2 * 5.0) * 0.28;
		float L = sz * (0.45 + 0.55 * fract(h0 * 7.3 + float(i) * 0.37 + h3)) * (1.0 - 0.4 * abs(fk));
		vec2 b0 = c + vec2(-sin(a), cos(a)) * fk * 0.05;
		vec2 dt = seg_dt(f, b0, b0 + vec2(cos(a), sin(a)) * L);
		float w = ((0.014 + 0.012 * h1) * (1.0 - 0.75 * dt.y)) / cell;
		float m = 1.0 - smoothstep(w, w + px / cell, dt.x);
		if (m > ink) { ink = m; tipk = dt.y; }
	}
	vec3 root = mix(srgb(vec3(0.22, 0.27, 0.13)), srgb(vec3(0.36, 0.33, 0.17)), step(0.8, h3) * 0.8);
	vec3 tip = h2 < 0.5 ? srgb(C_GRASS * 0.9) : (h2 < 0.85 ? srgb(C_GRASS * vec3(1.05, 1.08, 0.85)) : srgb(vec3(0.62, 0.55, 0.32)));
	vec3 leaf = mix(root, tip, tipk);
	return mix(base, leaf, ink * tk * (0.55 + 0.35 * h1) * (1.0 - 0.3 * tipk));
}

// 짚 부스러기(장터·마당): 짧은 노란 획 몇 개, 배추 잎(장터): 둥근 초록 조각
vec3 t_litter(vec3 base, vec2 p, float straw, float leaf, float px, float k) {
	float sk = k * (1.0 - smoothstep(0.02, 0.05, px));
	if (sk <= 0.002) return base;
	if (straw > 0.002) {
		vec2 q = p / 0.42; ivec2 ci = ivec2(floor(q)); vec2 f = fract(q);
		float h0 = r_hash(ci + ivec2(7, 61));
		if (h0 < straw * 0.6) {
			float a = r_hash(ci + ivec2(19, 3)) * 6.2832;
			vec2 c = vec2(0.25) + vec2(r_hash(ci + ivec2(2, 8)), r_hash(ci + ivec2(9, 4))) * 0.5;
			vec2 dir = vec2(cos(a), sin(a)) * (0.2 + 0.25 * h0 / max(straw, 0.01)) / 0.42;
			vec2 dt = seg_dt(f, c - dir * 0.5, c + dir * 0.5);
			float m = 1.0 - smoothstep(0.008 / 0.42, (0.008 + px) / 0.42, dt.x);
			vec3 sc = mix(srgb(vec3(0.84, 0.74, 0.46)), srgb(vec3(0.66, 0.55, 0.32)), r_hash(ci + ivec2(5, 5)));
			base = mix(base, sc, m * sk * 0.75);
		}
	}
	if (leaf > 0.002) {
		vec2 q = p / 1.1; ivec2 ci = ivec2(floor(q)); vec2 f = fract(q);
		float h0 = r_hash(ci + ivec2(37, 23));
		if (h0 < leaf) {
			vec2 c = vec2(0.3) + vec2(r_hash(ci + ivec2(1, 77)), r_hash(ci + ivec2(66, 2))) * 0.4;
			vec2 d = (f - c) * 1.1;
			float a = h0 * 31.0;
			d = mat2(vec2(cos(a), sin(a)), vec2(-sin(a), cos(a))) * d * vec2(1.0, 1.5);
			float r = 0.13 + 0.07 * r_hash(ci + ivec2(4, 4));
			float dl = length(d) * (1.0 + 0.3 * (texture(noise_tex, p * 3.1).r - 0.5));
			float m = 1.0 - smoothstep(r - px, r + px * 0.5, dl);
			float vein = 1.0 - smoothstep(0.004, 0.004 + px, abs(d.y));
			vec3 lc = mix(srgb(vec3(0.62, 0.72, 0.42)), srgb(vec3(0.82, 0.86, 0.62)), r_hash(ci + ivec2(8, 1)));
			lc = mix(lc, lc * 0.75, vein * 0.6);
			base = mix(base, lc, m * sk);
		}
	}
	return base;
}

// 박석(넓적한 자연석을 깐 마당): 흔든 격자의 가장 가까운 두 점으로 돌 경계(먹 줄)와 돌마다 다른 빛
vec3 t_paving(vec3 base, vec2 p, float inner, float px, float k) {
	float pk = k * smoothstep(0.0, 0.25, inner);
	if (pk <= 0.002) return base;
	vec2 q = p / 0.75;
	ivec2 ci = ivec2(floor(q));
	vec2 f = fract(q);
	float d1 = 9.0, d2 = 9.0; ivec2 best = ci;
	for (int y = -1; y <= 1; y++) for (int x = -1; x <= 1; x++) {
		ivec2 cc = ci + ivec2(x, y);
		vec2 o = vec2(float(x), float(y)) + vec2(0.5) + (vec2(r_hash(cc + ivec2(3, 11)), r_hash(cc + ivec2(13, 5))) - 0.5) * 0.7;
		float d = length(f - o);
		if (d < d1) { d2 = d1; d1 = d; best = cc; } else if (d < d2) d2 = d;
	}
	float edge = (d2 - d1) * 0.75;   // m
	float gap = 1.0 - smoothstep(0.015, 0.015 + px * 1.2, edge);
	float hs = r_hash(best + ivec2(21, 9));
	vec3 st = srgb(mix(vec3(0.70, 0.67, 0.60), vec3(0.58, 0.56, 0.51), hs)) * (0.93 + 0.14 * texture(noise_tex, p * 0.9).r);
	st = mix(st, base, 0.25);
	vec3 c = mix(st, srgb(vec3(0.30, 0.27, 0.23)), gap * 0.8);
	// 가장자리 경계석: 안쪽 0.35m 띠는 긴 장대석
	float curb = 1.0 - smoothstep(0.35, 0.4, inner);
	if (curb > 0.0) {
		float seg = fract(dot(p, vec2(0.707)) / 1.2);
		float cg = 1.0 - smoothstep(0.02, 0.02 + px * 2.0, min(seg, 1.0 - seg) * 1.2);
		vec3 cs = srgb(vec3(0.64, 0.62, 0.57)) * (0.95 + 0.1 * texture(noise_tex, p * 0.6).r);
		cs = mix(cs, srgb(vec3(0.3, 0.27, 0.23)), max(cg, 1.0 - smoothstep(0.0, 0.05, inner)) * 0.7);
		c = mix(c, cs, curb);
	}
	return mix(base, c, pk);
}

// town_layer: dress_tex(처마 부호 거리 sd · 장터 mk · 물가 wd · 박석 pav)와 길 칠하기(rd·rhw)로 땅에 꾸밈을 얹는다.
//   water: 웅덩이(하늘 반사) 비율을 올려 준다
vec3 town_layer(vec3 base, vec2 p, vec3 col, float dirt, float slope, float rd, float rhw, float dist, float px, vec2 cam_xz, float bankw, inout float water) {
	float k = dress_on * (1.0 - smoothstep(dress_far * 0.7, dress_far, dist));
	if (k < 0.002) return base;
	vec4 dv = texture(dress_tex, ((p - h_meta.xy) * h_meta.z + 0.5) / vec2(h_size));
	float sd = (dv.r * 255.0 - 128.0) / 16.0;
	float mk = dv.g;
	float wd = dv.b * 255.0 / 16.0;
	float pav = dv.a * 255.0;
	float rocky = smoothstep(0.5, 1.0, slope);
	float green = clamp((col.g - col.r) * 9.0 + 0.4, 0.0, 1.0) * (1.0 - dirt) * (1.0 - rocky);
	vec2 away = normalize(p - cam_xz + vec2(1e-4));
	float n = texture(noise_tex, p * 0.37).r;
	// 1인칭(near_detail)에서는 카메라 7m 안 포기를 성기게·옅게 지운다 — 눈앞 큰 납작 별 대신 near_layer의 가는 포기가 받는다
	float tnear = mix(1.0, smoothstep(3.0, 9.0, dist), near_detail);
	float edge = rd - rhw;   // 길 가장자리(+ 바깥)
	// 1 박석 마당
	if (pav > 0.5) base = t_paving(base, p, (pav - 1.0) / 32.0 - 1.0, px, k);
	float paved = pav > 0.5 ? smoothstep(0.0, 0.25, (pav - 1.0) / 32.0 - 1.0) : 0.0;
	// 2 처마 밑·낙숫물 줄·기단 둘레
	if (sd < 7.5) {
		float under = smoothstep(0.05, -0.35, sd);
		base *= 1.0 - k * under * 0.22;
		base = mix(base, base * vec3(1.04, 1.0, 0.94), k * under * 0.3);   // 처마 밑은 마른 흙
		float drip = 1.0 - smoothstep(0.08, 0.3, abs(sd - 0.28 + (n - 0.5) * 0.12));
		float dk = k * drip * (1.0 - smoothstep(0.03, 0.08, px));
		base *= 1.0 - dk * 0.16 * (1.0 - paved);
		// 낙숫물 구멍(작은 먹 점) 줄
		if (dk > 0.01) {
			vec2 q = p / 0.16; ivec2 ci = ivec2(floor(q));
			float h = r_hash(ci + ivec2(41, 77));
			float dd = length(fract(q) - 0.5) * 0.16;
			base *= 1.0 - dk * 0.35 * step(h, 0.5) * (1.0 - smoothstep(0.018, 0.018 + px, dd));
		}
		// 기단·담 밑: 바깥 0.4~1.6m 띠에 잔돌 · 풀 포기(풀빛 땅)
		float wall = smoothstep(0.3, 0.5, sd) * (1.0 - smoothstep(1.0, 1.9, sd + (n - 0.5) * 0.8));
		base = t_stones(base, p, 0.45, 0.035, 0.09, 0.45 * wall * (1.0 - paved), px, k, 5);
		base = t_tufts(base, p, 0.55, 0.32, (0.25 + 0.5 * green) * wall * (1.0 - paved) * (1.0 - dirt * 0.6) * tnear, px, k * tnear, away);
	}
	// 3 길 가장자리: 부서진 테 + 잔돌 + 길섶 풀 포기
	if (edge > -1.0 && edge < 2.2) {
		float rim = 1.0 - smoothstep(0.0, 0.9, abs(edge + 0.15 + (n - 0.5) * 0.7));
		base = t_stones(base, p, 0.5, 0.03, 0.08, 0.4 * rim * (1.0 - paved), px, k, 11);
		float verge = smoothstep(-0.1, 0.35, edge) * (1.0 - smoothstep(1.0, 2.0, edge));
		base = t_tufts(base, p + vec2(0.21, 0.37), 0.6, 0.34, 0.55 * verge * (1.0 - paved) * (0.3 + 0.7 * (1.0 - dirt * 0.5)) * tnear, px, k * tnear, away);
	}
	// 3b 길 바닥: 바퀴·발 자국 줄(길 방향 — 칠하기 거리의 기울기에 수직) · 밟혀 짙은 가운데 · 옅은 가장자리 흙 · 말발굽 점
	if (rd < rhw + 0.3 && rhw > 0.6) {
		vec2 uvp = ((p - h_meta.xy) * h_meta.z + 0.5) / vec2(h_size);
		vec2 e1 = vec2(1.0 / float(h_size.x), 0.0), e2 = vec2(0.0, 1.0 / float(h_size.y));
		vec2 gr = vec2(texture(paint_tex, uvp + e1).r - texture(paint_tex, uvp - e1).r, texture(paint_tex, uvp + e2).r - texture(paint_tex, uvp - e2).r);
		vec2 tdir = dot(gr, gr) > 1e-9 ? normalize(vec2(-gr.y, gr.x)) : vec2(1.0, 0.0);
		vec2 nrm = vec2(-tdir.y, tdir.x);
		float along = dot(p, tdir), across = dot(p, nrm);
		float roadk = k * (1.0 - smoothstep(rhw - 0.3, rhw + 0.2, rd));
		// 짙게 밟힌 가운데(폭의 60%) · 바깥 30%는 부슬흙
		base *= 1.0 - roadk * 0.07 * (1.0 - smoothstep(rhw * 0.45, rhw * 0.8, rd)) + roadk * 0.05 * smoothstep(rhw * 0.65, rhw * 0.95, rd);
		// 자국 줄: 가로 0.22m 주기 잡음 줄무늬, 길 따라 끊김
		float br = texture(noise_tex, vec2(along * 0.035, across * 0.9)).r;
		float lines = smoothstep(0.58, 0.72, br) * (0.6 + 0.4 * texture(noise_tex, vec2(along * 0.12, 0.3)).r);
		base *= 1.0 - roadk * 0.11 * lines * (1.0 - smoothstep(0.02, 0.05, px));
		// 수레바퀴 두 줄(큰길 · 지선): 가운데에서 ±0.7m
		float wheel = (1.0 - smoothstep(0.05, 0.13, abs(rd - 0.75))) * step(1.25, rhw);
		base *= 1.0 - roadk * 0.12 * wheel * (0.5 + 0.5 * texture(noise_tex, vec2(along * 0.07, 0.6)).r);
		// 말발굽·짚신 자국 점(작은 반달)
		vec2 fq = vec2(along / 0.5, across / 0.38); ivec2 fc = ivec2(floor(fq)); vec2 ff = fract(fq) - 0.5;
		float fh = r_hash(fc + ivec2(5, 91));
		float fm = (1.0 - smoothstep(0.16, 0.22, length(ff * vec2(1.0, 1.4)))) * step(fh, 0.18) * smoothstep(-0.05, 0.1, ff.x);
		base *= 1.0 - roadk * 0.12 * fm * (1.0 - smoothstep(0.015, 0.035, px));
	}
	// 3c 풀빛 땅(마을 안 빈터·길섶 바깥): 포기·작은 들꽃 점
	if (green > 0.2) {
		base = t_tufts(base, p + vec2(0.13, 0.71), 0.85, 0.36, 0.35 * green * tnear, px, k * tnear, away);
		vec2 q = p / 0.6; ivec2 ci = ivec2(floor(q));
		float fh = r_hash(ci + ivec2(33, 17));
		if (fh < 0.05 * green) {
			vec2 f = fract(q) - (vec2(r_hash(ci + ivec2(1, 2)), r_hash(ci + ivec2(2, 1))) * 0.5 + 0.25);
			float dm = 1.0 - smoothstep(0.035, 0.035 + px, length(f) * 0.6);
			vec3 fc2 = fh < 0.02 * green ? srgb(vec3(0.95, 0.92, 0.82)) : (fh < 0.035 * green ? srgb(vec3(0.92, 0.78, 0.3)) : srgb(vec3(0.78, 0.5, 0.62)));
			base = mix(base, fc2, dm * k * (1.0 - smoothstep(0.02, 0.04, px)));
		}
	}
	// 4 흙 땅 전체: 흙 결(0.6~2m 얼룩) · 마당 빗자루 자국(반달 줄) · 성긴 잔돌·자갈(밟힌 길 가운데는 적게)
	float mid = rd < rhw ? smoothstep(rhw * 0.25, rhw * 0.8, rhw - rd) : 0.0;
	float m1 = texture(noise_tex, p * 0.43 + vec2(0.13, 0.71)).r;
	base *= 1.0 + k * dirt * (m1 - 0.5) * 0.18;
	float yardk = dirt * step(rhw + 0.6, rd) * (1.0 - paved) * (1.0 - smoothstep(0.025, 0.06, px));
	if (yardk > 0.01) {
		vec2 q = p / 1.7; ivec2 ci = ivec2(floor(q)); vec2 f = fract(q);
		float h0 = r_hash(ci + ivec2(13, 59));
		vec2 c0 = vec2(r_hash(ci + ivec2(2, 3)), r_hash(ci + ivec2(7, 1))) * 0.6 + 0.2;
		vec2 dd = (f - c0) * 1.7;
		float rr = length(dd);
		if (rr < 0.35 || rr > 1.25) { } else {
		float sector = smoothstep(0.25, 0.75, dot(dd / max(rr, 1e-3), vec2(cos(h0 * 6.2832), sin(h0 * 6.2832))));
		float band = smoothstep(0.35, 0.5, rr) * (1.0 - smoothstep(1.0, 1.25, rr));
		float st = sin(rr * 6.2832 / 0.075 + h0 * 20.0);
		base *= 1.0 + yardk * k * sector * band * st * 0.045 * step(h0, 0.55);
		}
	}
	base = t_stones(base, p, 0.5, 0.025, 0.1, (0.12 + 0.12 * rocky) * dirt * (1.0 - 0.5 * mid) * (1.0 - paved), px, k, 23);
	// 5 장터: 짚 부스러기·배추 잎 · 마당 흙에도 짚 조금
	base = t_litter(base, p, (mk * 0.55 + 0.05 * dirt * smoothstep(0.0, 2.0, sd) * (1.0 - smoothstep(4.0, 7.0, sd))) * (1.0 - paved), mk * 0.22 * (1.0 - paved), px, k);
	// 5b 냇가·강가(토지이용 물 칸과 맞닿은 띠): 젖어 짙은 테 · 둥근 냇돌 · 물풀 포기
	if (bankw > 0.02 && bankw < 0.98) {
		float bk = smoothstep(0.02, 0.3, bankw) * (1.0 - smoothstep(0.75, 0.98, bankw));
		base *= 1.0 - k * bk * 0.18;
		base = t_stones(base, p, 0.55, 0.05, 0.16, 0.5 * bk, px, k, 41);
		base = t_tufts(base, p + vec2(0.4, 0.2), 0.7, 0.42, 0.4 * bk * smoothstep(0.1, 0.4, bankw) * tnear, px, k * tnear, away);
	}
	// 6 물가(우물·빨래터·나루): 진흙 → 웅덩이
	if (wd < 6.0) {
		float wn2 = texture(noise_tex, p * 0.21 + vec2(0.4, 0.1)).r;
		float mud = (1.0 - smoothstep(1.5, 5.5, wd + (wn2 - 0.5) * 2.5)) * (1.0 - paved * 0.7);
		base = mix(base, base * vec3(0.62, 0.58, 0.54), k * mud * 0.7);
		float pud = smoothstep(0.62, 0.72, wn2 + (1.0 - smoothstep(1.0, 3.5, wd)) * 0.35) * mud;
		water = max(water, k * pud * 0.75);
	}
	return base;
}

void fragment() {
	vec2 p = v_wp.xz;
	float px = length(fwidth(p));   // 화소 하나가 덮는 땅 크기(m) — near_layer
	float n1 = tn(p * 0.019);
	float n2 = clamp(tn(p * 0.075 + vec2(0.37, 0.11)) * 2.0, -1.0, 1.0);
	// 토지이용 경계를 붓질처럼 흔들어 4칸 섞기
	vec2 warp = vec2(tn(p * 0.026 + vec2(0.1, 0.7)), tn(p * 0.026 + vec2(0.53, 0.21))) * 3.0;
	vec2 f = (p + warp - lu_meta.xy) * lu_meta.z;
	f = clamp(f, vec2(0.0), vec2(lu_size - 1) - 0.001);
	ivec2 i = ivec2(floor(f));
	vec2 t = smoothstep(0.2, 0.8, f - vec2(i));
	int ca = r_lu(i), cb = r_lu(i + ivec2(1, 0)), cc = r_lu(i + ivec2(0, 1)), cd = r_lu(i + ivec2(1, 1));
	// 토지이용 길 칸(4)은 넓게 칠해져 있다 → 주변 토지이용 색으로 바꾸고, 흙길은 roads 칠하기(실제 폭)로만 그린다
	if (ca == 4 || cb == 4 || cc == 4 || cd == 4) {
		int sub = 1;
		ivec2 offs[8] = ivec2[](ivec2(-2, 0), ivec2(3, 0), ivec2(0, -2), ivec2(0, 3), ivec2(-3, -3), ivec2(4, 4), ivec2(-3, 4), ivec2(4, -3));
		for (int q = 0; q < 8; q++) {
			int v = r_lu(i + offs[q]);
			if (v != 4 && v != 5) { sub = v; break; }
		}
		if (ca == 4) ca = sub; if (cb == 4) cb = sub; if (cc == 4) cc = sub; if (cd == 4) cd = sub;
	}
	if (farm_on > 0.5) {
		if (ca == 2 || ca == 3) ca = 1; if (cb == 2 || cb == 3) cb = 1;
		if (cc == 2 || cc == 3) cc = 1; if (cd == 2 || cd == 3) cd = 1;
	}
	vec3 col;
	float water = 0.0;
	// 논·밭이 있으면 필지 좌표(48m 구역 중심의 지형 기울기로 돌림)
	vec4 cq = vec4(p, 0.0, 0.0);
	float block_edge = 1e3;
	if (ca == 2 || ca == 3 || cb == 2 || cb == 3 || cc == 2 || cc == 3 || cd == 2 || cd == 3) {
		vec2 bid = floor(p / 48.0);
		vec2 bc = (bid + 0.5) * 48.0;
		float e = 24.0;
		vec2 gr = vec2(r_hdata(bc + vec2(e, 0.0)) - r_hdata(bc - vec2(e, 0.0)), r_hdata(bc + vec2(0.0, e)) - r_hdata(bc - vec2(0.0, e)));
		float a0 = (r_hash(ivec2(bid) + ivec2(5, 9)) - 0.5) * 1.2;
		vec2 dn = normalize(mix(vec2(sin(a0), cos(a0)), normalize(gr + 1e-5), smoothstep(0.2, 1.5, length(gr))));
		vec2 dt = vec2(-dn.y, dn.x);
		vec2 lp = p - bc;
		cq = vec4(dot(lp, dt), dot(lp, dn), bid);
		vec2 lb = abs(lp);
		block_edge = 24.0 - max(lb.x, lb.y);
	}
	if (ca == cb && ca == cc && ca == cd) {
		col = lu_color(ca, p, n1, n2, cq, block_edge, water);
	} else {
		float wa = 0.0, wb = 0.0, wc = 0.0, wd = 0.0;
		col = mix(mix(lu_color(ca, p, n1, n2, cq, block_edge, wa), lu_color(cb, p, n1, n2, cq, block_edge, wb), t.x),
			mix(lu_color(cc, p, n1, n2, cq, block_edge, wc), lu_color(cd, p, n1, n2, cq, block_edge, wd), t.x), t.y);
		water = mix(mix(wa, wb, t.x), mix(wc, wd, t.x), t.y);
	}
	// 젖은 기슭(mountain-terrain): 물(5) 칸 곁은 짙고 푸르스름하게
	float wetb = mix(mix(float(ca == 5), float(cb == 5), t.x), mix(float(cc == 5), float(cd == 5), t.x), t.y);
	col = mix(col, col * vec3(0.72, 0.76, 0.78), clamp(wetb * 2.0, 0.0, 1.0) * (1.0 - water));
	// 붓질 같은 얼룩(웹과 같은 식)
	float br = tn(vec2(p.x * 0.044 + p.y * 0.015, p.y * 0.0625) + vec2(0.8, 0.4));
	col = mix(col, C_FOREST2, clamp(br - 0.15, 0.0, 0.3) * 0.5);
	col = mix(col, C_DRY, clamp(-br - 0.2, 0.0, 0.25));
	// 경사 → 흙·바위·벼랑
	float slope = length(v_wn.xz) / max(v_wn.y, 0.05);
	col = mix(col, C_PATH, smoothstep(0.45, 0.8, slope) * 0.3);
	col = mix(col, C_ROCK, smoothstep(0.75, 1.15, slope) * 0.8);
	col = mix(col, C_CLIFF, smoothstep(1.2, 1.9, slope) * 0.9);
	// 높은 산은 조금 차갑고 옅게
	col = mix(col, C_HIGH, smoothstep(200.0, 520.0, v_wp.y) * 0.35);
	// 먼 숲 = 수관 빛(나무를 그리지 않는 거리부터 — region_far_look). 바위 비탈은 그대로
	float cam_d = length(VERTEX);
	float fw = mix(mix(float(ca == 0 || ca == 9), float(cb == 0 || cb == 9), t.x), mix(float(cc == 0 || cc == 9), float(cd == 0 || cd == 9), t.x), t.y);
	col = mix(col, canopy_color(p, v_wp.y), fw * smoothstep(canopy_d0, canopy_d1, cam_d) * (1.0 - smoothstep(1.5, 2.0, slope)));
	// 길·마당 칠하기(웹 마을 가운데 흙길 느낌): 흙길 + 바퀴·발 자국 + 가장자리 풀 섶, 건물 둘레 2~4m 흙 마당
	vec4 pt = texture(paint_tex, ((p - h_meta.xy) * h_meta.z + 0.5) / vec2(h_size));
	float rd = pt.r * 16.0, rhw = pt.g * 8.0, yd = pt.b * 16.0;
	float pn = tn(p * 0.21 + vec2(0.31, 0.77));
	float dirt = 0.0;   // 흙길·마당 비율(near_layer)
	if (yd < 6.0) {
		float yard = 1.0 - smoothstep(1.2, 3.6, yd + pn * 1.6);
		vec3 yc = mix(C_LANE, C_DRY, clamp(0.35 + n2 * 0.4, 0.0, 0.7));
		col = mix(col, yc, yard * 0.9);
		dirt = yard * 0.9;
	}
	if (rd < rhw + 3.0) {
		float edge = rd - rhw + pn * 0.45;
		float road = 1.0 - smoothstep(-0.2, 0.2, edge);
		float verge = (1.0 - smoothstep(0.1, 1.3, edge)) * (1.0 - road);
		verge *= 1.0 - urban_ground * (1.0 - smoothstep(0.3, 1.2, yd));
		col = mix(col, C_GRASS2 * 0.82, verge * 0.55);   // 길섶: 짙은 풀 띠
		float cls = pt.a * 255.0 / 60.0;
		vec3 rc = mix(C_LANE * 1.07, C_PATH, clamp(0.3 + n2 * 0.35, 0.0, 0.7));
		// 바퀴·발 자국: 중심에서 반폭의 45% 자리 두 줄(대로·지선), 산길은 가운데 한 줄
		float off = cls >= 2.5 ? rhw * 0.45 : 0.0;
		float rut = (1.0 - smoothstep(0.1, 0.3, abs(rd - off))) * (0.6 + 0.4 * pn);
		rc = mix(rc, C_PATH * 0.86, rut * (cls >= 2.5 ? 0.45 : 0.25));
		col = mix(col, rc, road);
		dirt = max(dirt, road);
	}
	// 먼 고을 = 처마 안 땅을 지붕 빛으로(건물이 안개에 묻히는 거리부터)
	float far_canopy = fw * smoothstep(canopy_d0, canopy_d1, cam_d) * (1.0 - smoothstep(1.5, 2.0, slope));   // 사실 땅도 같은 비율로(ground_real)
	float far_roof = 0.0;
	if (dress_on > 0.0 && cam_d > canopy_d0) {
		float ed = texture(dress_tex, ((p - h_meta.xy) * h_meta.z + 0.5) / vec2(h_size)).r * 255.0 - 128.0;
		far_roof = (1.0 - smoothstep(-6.0, 2.0, ed)) * smoothstep(canopy_d0, canopy_d1, cam_d);
		col = mix(col, roof_color(p), far_roof);
	}
	vec3 gtx = texture(ground_tex, p / 7.0).rgb;
#ifdef LOOK_PBR
	gtx = mix(vec3(dot(gtx, vec3(0.333))), gtx, 0.5) * 0.5 + 0.5 * vec3(0.93, 0.92, 0.9);   // 붓 땅 무늬는 반만(사실 디테일이 맡는다)
#endif
	vec3 base = srgb(col) * gtx;
	float bankw0 = mix(mix(float(ca == 5), float(cb == 5), t.x), mix(float(cc == 5), float(cd == 5), t.x), t.y);
#ifndef LOOK_PBR
	if (dress_on > 0.0) {
		float bankw = mix(mix(float(ca == 5), float(cb == 5), t.x), mix(float(cc == 5), float(cd == 5), t.x), t.y);
		base = town_layer(base, p, col, dirt * (1.0 - water), slope, rd, rhw, length(VERTEX), px, (INV_VIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xz, bankw, water);
	}
	if (near_detail > 0.0) {
		vec2 rdir = vec2(1.0, 0.0);
		if (dirt > 0.01) {   // 길 방향 = 길 거리 칠하기의 기울기에 수직
			vec2 uvp = ((p - h_meta.xy) * h_meta.z + 0.5) / vec2(h_size);
			vec2 e = vec2(1.0 / float(h_size.x), 0.0), e2 = vec2(0.0, 1.0 / float(h_size.y));
			vec2 gr = vec2(texture(paint_tex, uvp + e).r - texture(paint_tex, uvp - e).r, texture(paint_tex, uvp + e2).r - texture(paint_tex, uvp - e2).r);
			if (dot(gr, gr) > 1e-8) rdir = normalize(vec2(-gr.y, gr.x));
		}
		base = near_layer(base, p, col, dirt * (1.0 - water), slope, rdir, length(VERTEX), px, (INV_VIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xz);
	}
#endif
	// 날씨: 젖은 땅은 어둡고 길·마당·평지에 물웅덩이(하늘 반사), 눈은 평평한 곳부터 덮고 길은 밟혀 덜 덮인다
	float t_cov = 0.0;
	if (wet > 0.0 || snow > 0.0 || snow_line < 9e4) {
		float flat_k = smoothstep(0.86, 0.97, v_wn.y);
		float on_road = (rd < rhw + 0.3) ? 1.0 : (yd < 2.0 ? 0.6 : 0.0);
		float sc = max(snow, smoothstep(snow_line, snow_line + 30.0, v_wp.y) * (0.75 + 0.25 * n1));
		float cov = 0.0;
		if (sc > 0.0) {
			float sn = tn(p * 0.11 + vec2(0.13, 0.57));
			cov = clamp(sc * 1.6 - 0.5 + sn * 0.45, 0.0, 1.0) * smoothstep(0.35, 0.8, v_wn.y);
			cov *= 1.0 - on_road * (0.45 + 0.25 * pn);   // 밟힌 길·마당은 흙이 비친다
			cov = min(cov, 0.9 + 0.1 * sn);
		}
		base *= 1.0 - 0.32 * wet * (1.0 - cov);
		float puddle = wet * flat_k * smoothstep(0.45, 0.75, tn(p * 0.09 + vec2(0.7, 0.2)) + on_road * 0.25) * (1.0 - cov);
		water = max(water, puddle * 0.45);
		vec3 gt = texture(ground_tex, p / 7.0).rgb;
		base = mix(base, vec3(0.80, 0.83, 0.88) * (0.9 + 0.1 * n2) * mix(vec3(1.0), gt / max(dot(gt, vec3(0.333)), 0.05), 0.35), cov);
		water *= 1.0 - cov;
		t_cov = cov;
	}
	// 물 댄 논: 하늘빛 반사(위를 볼수록 진흙이 비침)
	vec3 wn = v_wn;
	vec3 vdir = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
	float fres = 0.35 + 0.65 * pow(1.0 - clamp(dot(vdir, vec3(0, 1, 0)), 0.0, 1.0), 2.0);
	vec3 sky = mix(mix(hemi_sky, fog_color, 0.35), hemi_sky * vec3(0.62, 0.8, 0.8), 0.45);
	ALBEDO = mix(base, base * vec3(0.5, 0.58, 0.58), water);
#ifdef LOOK_PBR
	{
#include "res://shaders/ground_real.gdshaderinc"
	}
#else
	vec3 hemi = mix(hemi_ground, hemi_sky, 0.5 * wn.y + 0.5) * hemi_i;
	EMISSION = ALBEDO * hemi / PI + sky * water * fres * 0.55;
#endif
	// 안개(Materials와 같은 식) + 먼 능선은 먹빛을 조금 남긴다
	float fog_d = -VERTEX.z;
	float fog_f = 1.0 - exp(-fog_density * fog_density * fog_d * fog_d);
	float fog_mist = fog_density * 24.0 * (1.0 - smoothstep(-2.0, 7.0, v_wp.y - mist_base)) * smoothstep(14.0, 48.0, fog_d);
	fog_f = 1.0 - (1.0 - fog_f) * (1.0 - clamp(fog_mist, 0.0, 0.8));
	// 먼 땅은 공기원근으로 남는다(region_far_look — 원경 region_far와 같은 식)
	fog_f = aer_haze(fog_f, fog_d, v_wp.y, mist_base, fog_density);
	vec3 fc = aer_tint(fog_color, far_ink, fog_d, v_wp.y, mist_base, wn.y);
	if (far_k > 0.0) {
		// 원경: 안개에 묻히는 대신 하늘 그림판의 먼 산처럼 — 높은 능선은 먹빛, 골짜기·산발치는 안개빛
		float far = smoothstep(120.0, 500.0, fog_d) * far_k;
		float hrel = smoothstep(-10.0, 140.0, v_wp.y - mist_base);
		float steep = 1.0 - smoothstep(0.55, 0.95, wn.y);
		fc = mix(fog_color, far_ink, far * clamp(0.25 + 0.45 * hrel + 0.15 * steep, 0.0, 0.8));
	}
	FOG = vec4(pbr_fog_color(fc, -vdir), fog_f);
}

void light() {
#ifdef LOOK_PBR
	vec3 dl = vec3(0.0), sl = vec3(0.0);
	pbr_direct(NORMAL, LIGHT, VIEW, LIGHT_COLOR, ATTENUATION * (LIGHT_IS_DIRECTIONAL ? sun_k : 1.0), ROUGHNESS, BACKLIGHT.r, dl, sl);
	DIFFUSE_LIGHT += dl; SPECULAR_LIGHT += sl;
#else
	float ndl = dot(NORMAL, LIGHT);
	float ramp = texture(ramp_tex, vec2(ndl * 0.5 + 0.5, 0.5)).r;
	DIFFUSE_LIGHT += ramp * ATTENUATION * LIGHT_COLOR / (PI * PI);
#endif
}
