// 권역 지형 — 타일 격자 메시(평평한 정수 격자)를 정점 셰이더에서 높이맵으로 세운다.
// 재질은 Materials 툰 셰이더와 같은 규칙: 붓 바림 램프(LIGHT_COLOR/π²) + 반구광(EMISSION = base·hemi/π) + 높이 안개.
// 색은 웹 terrain.js의 들판·숲·길·바위 색을 토지이용별로 고르고, 웹 땅 붓 텍스처(ground.png, 7m 반복)를 곱한다.
shader_type spatial;
render_mode specular_disabled, cull_back;

#include "res://shaders/region_common.gdshaderinc"

global uniform vec3 hemi_sky;
global uniform vec3 hemi_ground;
global uniform float hemi_i;
global uniform vec3 fog_color;
global uniform float fog_density;

uniform sampler2D ground_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable, hint_default_white;
uniform sampler2D ramp_tex : filter_linear, repeat_disable;
uniform sampler2D paint_tex : filter_linear, repeat_disable; // 길·마당 칠하기(region_world._paint_roads, paint_yard)
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable; // 이음매 없는 잡음(픽셀 잡음을 해시 대신 텍스처로 — 빠르다)
uniform float grid_step = 1.0;     // 격자 간격(근경 1m, 중경 4m) — 법선 계산용
uniform float skirt = 6.0;         // 가장자리 치마(이음매 틈 가리기) 깊이
uniform vec3 far_ink = vec3(0.07, 0.085, 0.08); // 원경 먹빛(선형) — region_main이 시간대에 맞춰 넣는다
uniform float far_k = 0.0;         // 먼 능선을 먹빛으로 남기는 정도(0 = 기존 안개 그대로 — 식생·키트 재질과 맞추려면 0. 공용 안개에 같은 규칙이 들어오면 켠다)
uniform float mist_base = 0.0;     // 낮은 안개 기준 높이(플레이어 발 높이). 기존 Materials는 마을 바닥 y=0 기준         // 먼 능선을 먹빛으로 남기는 정도(0 = 기존 안개 그대로)

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
	if (c == 5) return C_BED;
	// 마을 터: 웹 마을 땅처럼 풀밭 + 마른 흙 얼룩(맨 흙은 건물 둘레·길에만 — 칠하기 텍스처)
	if (c == 6) {
		vec3 g = mix(C_GRASS, C_GRASS2, clamp(0.5 + n1, 0.0, 1.0));
		g = mix(g, C_DRY, clamp(n2 * 0.5 + 0.1, 0.0, 0.4));
		return mix(g, C_LANE, smoothstep(0.25, 0.55, n1 + n2 * 0.2) * 0.35);
	}
	if (c == 7) return mix(C_ROCK, C_CLIFF, clamp(0.5 + n1 * 1.5, 0.0, 1.0));
	if (c == 8) return mix(C_SAND, C_BANK, clamp(0.5 + n2, 0.0, 1.0));
	return mix(C_BAMBOO, C_FOREST2, clamp(0.5 + n1, 0.0, 1.0));
}

// 이음매 없는 잡음 텍스처 한 장을 두 배율로 겹쳐 되풀이 무늬가 보이지 않게
float tn(vec2 uv) { return (texture(noise_tex, uv).r + texture(noise_tex, uv * 0.6180 + vec2(0.37, 0.71)).r - 1.0) * 1.15; }

void fragment() {
	vec2 p = v_wp.xz;
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
	// 길·마당 칠하기(웹 마을 가운데 흙길 느낌): 흙길 + 바퀴·발 자국 + 가장자리 풀 섶, 건물 둘레 2~4m 흙 마당
	vec4 pt = texture(paint_tex, ((p - h_meta.xy) * h_meta.z + 0.5) / vec2(h_size));
	float rd = pt.r * 16.0, rhw = pt.g * 8.0, yd = pt.b * 16.0;
	float pn = tn(p * 0.21 + vec2(0.31, 0.77));
	if (yd < 6.0) {
		float yard = 1.0 - smoothstep(1.2, 3.6, yd + pn * 1.6);
		vec3 yc = mix(C_LANE, C_DRY, clamp(0.35 + n2 * 0.4, 0.0, 0.7));
		col = mix(col, yc, yard * 0.9);
	}
	if (rd < rhw + 3.0) {
		float edge = rd - rhw + pn * 0.45;
		float road = 1.0 - smoothstep(-0.2, 0.2, edge);
		float verge = (1.0 - smoothstep(0.1, 1.3, edge)) * (1.0 - road);
		col = mix(col, C_GRASS2 * 0.82, verge * 0.55);   // 길섶: 짙은 풀 띠
		float cls = pt.a * 255.0 / 60.0;
		vec3 rc = mix(C_LANE * 1.07, C_PATH, clamp(0.3 + n2 * 0.35, 0.0, 0.7));
		// 바퀴·발 자국: 중심에서 반폭의 45% 자리 두 줄(대로·지선), 산길은 가운데 한 줄
		float off = cls >= 2.5 ? rhw * 0.45 : 0.0;
		float rut = (1.0 - smoothstep(0.1, 0.3, abs(rd - off))) * (0.6 + 0.4 * pn);
		rc = mix(rc, C_PATH * 0.86, rut * (cls >= 2.5 ? 0.45 : 0.25));
		col = mix(col, rc, road);
	}
	vec3 base = srgb(col) * texture(ground_tex, p / 7.0).rgb;
	// 물 댄 논: 하늘빛 반사(위를 볼수록 진흙이 비침)
	vec3 wn = v_wn;
	vec3 vdir = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
	float fres = 0.35 + 0.65 * pow(1.0 - clamp(dot(vdir, vec3(0, 1, 0)), 0.0, 1.0), 2.0);
	vec3 sky = mix(mix(hemi_sky, fog_color, 0.35), hemi_sky * vec3(0.62, 0.8, 0.8), 0.45);
	ALBEDO = mix(base, base * vec3(0.5, 0.58, 0.58), water);
	vec3 hemi = mix(hemi_ground, hemi_sky, 0.5 * wn.y + 0.5) * hemi_i;
	EMISSION = ALBEDO * hemi / PI + sky * water * fres * 0.55;
	// 안개(Materials와 같은 식) + 먼 능선은 먹빛을 조금 남긴다
	float fog_d = -VERTEX.z;
	float fog_f = 1.0 - exp(-fog_density * fog_density * fog_d * fog_d);
	float fog_mist = fog_density * 24.0 * (1.0 - smoothstep(-2.0, 7.0, v_wp.y - mist_base)) * smoothstep(14.0, 48.0, fog_d);
	fog_f = 1.0 - (1.0 - fog_f) * (1.0 - clamp(fog_mist, 0.0, 0.8));
	vec3 fc = fog_color;
	if (far_k > 0.0) {
		// 원경: 안개에 묻히는 대신 하늘 그림판의 먼 산처럼 — 높은 능선은 먹빛, 골짜기·산발치는 안개빛
		float far = smoothstep(120.0, 500.0, fog_d) * far_k;
		float hrel = smoothstep(-10.0, 140.0, v_wp.y - mist_base);
		float steep = 1.0 - smoothstep(0.55, 0.95, wn.y);
		fc = mix(fog_color, far_ink, far * clamp(0.25 + 0.45 * hrel + 0.15 * steep, 0.0, 0.8));
	}
	FOG = vec4(fc, fog_f);
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float ramp = texture(ramp_tex, vec2(ndl * 0.5 + 0.5, 0.5)).r;
	DIFFUSE_LIGHT += ramp * ATTENUATION * LIGHT_COLOR / (PI * PI);
}
