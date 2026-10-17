// 물 공용(water pass 2026-10-17): 물결 높이·법선, 잔물결 법선 지도, 빗방울 동그라미, 반사(평면 반사 그림 또는 하늘빛), 빛 반짝임.
// 물결 식은 scripts/region/water_fx.gd wave()와 **같아야 한다**(배가 같은 물결을 탄다).
// 쓰는 셰이더: region_water(하천 띠) · region_sea_body(바다·호수·큰 강) · kit_water(못·폭포 — 키트 'water' 키)
// 그림 결: 사진 같은 번들거림이 아니라 붓으로 칠한 물 — 반사는 조금 흐리고, 해 반짝임은 단단한 점(툰)으로 끊는다.

global uniform float water_t;
global uniform float water_k;
global uniform vec2 water_wind;
global uniform float water_rain;
global uniform float water_refl_on;
global uniform float water_refl_y;
global uniform mat4 water_refl_m;
global uniform vec3 water_sky_top;
global uniform vec3 water_sky_hor;
global uniform float water_ink;

uniform sampler2D wnrm_tex : filter_linear_mipmap, repeat_enable;          // RGB 법선(B 위), A 높이 — WaterFX.normal_tex()
uniform sampler2D water_refl_tex : source_color, filter_linear, repeat_disable;   // 평면 반사 그림(WaterFX) — 없으면 쓰지 않는다
uniform float refl_gain = 1.0;
uniform float glint_k = 1.0;

const vec4 WV_ANG = vec4(0.35, -0.6, 1.25, 0.05);
const vec4 WV_LEN = vec4(21.0, 12.5, 7.3, 4.1);
const vec4 WV_AMP = vec4(1.0, 0.55, 0.32, 0.18);
const vec4 WV_PH = vec4(0.0, 1.7, 4.1, 2.6);

float w_time() { return water_t > 0.0 ? water_t : TIME; }

// 물결 높이와 기울기 (h, dh/dx, dh/dz). amp = m, ls = 파장 배율
vec3 w_wave(vec2 p, float t, float amp, float ls) {
	vec3 r = vec3(0.0);
	float wa = atan(water_wind.y, water_wind.x);
	for (int i = 0; i < 4; i++) {
		float L = WV_LEN[i] * ls;
		float k = 6.2831853 / L;
		float w = sqrt(9.81 * k);
		float ang = WV_ANG[i] + wa;
		vec2 d = vec2(cos(ang), sin(ang));
		float ph = dot(d, p) * k - w * t + WV_PH[i];
		float a = WV_AMP[i] * amp;
		r.x += a * sin(ph);
		r.yz += a * k * cos(ph) * d;
	}
	return r;
}

// 잔물결 법선(xz 기울기)과 높이: 두 겹을 서로 다른 크기·방향으로 흘린다. off = 흐름으로 밀린 거리(m)
vec3 w_detail(vec2 p, vec2 off, float sc) {
	vec4 a = texture(wnrm_tex, (p - off) / (16.0 * sc));
	vec4 b = texture(wnrm_tex, (p - off * 1.35) * mat2(vec2(0.8, -0.6), vec2(0.6, 0.8)) / (6.5 * sc) + 0.31);
	vec2 g = (a.rg * 2.0 - 1.0) * 0.6 + (b.rg * 2.0 - 1.0) * 0.4;
	return vec3(g.x, g.y, a.a * 0.6 + b.a * 0.4);
}

// 바람 자국(cat's paw): 60m 크기로 천천히 옮겨 가는 거친 곳·잔잔한 곳 — 반사가 군데군데 흐려지고 맑아져 물이 넓게 읽힌다
float w_gust(vec2 p, float t) {
	float g = texture(wnrm_tex, p / 70.0 - water_wind * t * 0.012).a;
	return smoothstep(0.3, 0.75, g);
}

// 빗방울 동그라미(비 올 때): 1.1m 칸마다 하나씩 퍼지는 고리 — xz 기울기
vec2 w_rain(vec2 p, float t) {
	if (water_rain < 0.02) return vec2(0.0);
	vec2 g = vec2(0.0);
	for (int k = 0; k < 2; k++) {
		vec2 q = p / 1.1 + float(k) * vec2(0.5, 0.37);
		vec2 c = floor(q);
		float h = fract(sin(dot(c, vec2(127.1, 311.7))) * 43758.5453);
		float ph = fract(t * 0.9 + h);
		vec2 o = q - c - (0.3 + 0.4 * vec2(h, fract(h * 7.3)));
		float d = length(o);
		float ring = sin((d - ph * 0.55) * 38.0) * (1.0 - ph) * smoothstep(0.08, 0.0, abs(d - ph * 0.55));
		g += (d > 1e-3 ? o / d : vec2(0.0)) * ring;
	}
	return g * 0.5 * water_rain;
}

// 반사 빛깔: 평면 반사 그림이 있고 이 물면이 거울면 높이 가까이면 그것을, 아니면 하늘빛(위로 갈수록 하늘 꼭대기 빛)
vec3 w_reflect(vec3 wp, vec3 n, vec3 v, float dist) {
	vec3 r = reflect(-v, n);
	r.y = abs(r.y);
	vec3 col = mix(water_sky_hor, water_sky_top, smoothstep(0.02, 0.6, r.y));
	if (water_refl_on > 0.5) {
		float okp = 1.0 - smoothstep(0.35, 0.9, abs(wp.y - water_refl_y));
		if (okp > 0.001) {
			vec4 c = water_refl_m * vec4(wp.x, water_refl_y, wp.z, 1.0);
			vec2 uv = c.xy / c.w * vec2(0.5, -0.5) + 0.5;
			uv += n.xz * (0.045 / (1.0 + dist * 0.015));
			float e = smoothstep(0.0, 0.04, uv.x) * smoothstep(1.0, 0.96, uv.x) * smoothstep(0.0, 0.04, uv.y) * smoothstep(1.0, 0.96, uv.y);
			e *= step(0.0, c.w);
			vec3 pr = textureLod(water_refl_tex, clamp(uv, 0.0, 1.0), 0.0).rgb;
			col = mix(col, pr, okp * e);
		}
	}
	return col;
}

// 물빛 프레넬(그림용으로 조금 올림): 3인칭 32~40°에서도 둘레가 비쳐 읽히고, 1인칭 먼 물은 거의 거울
float w_fresnel(vec3 n, vec3 v) {
	float c = clamp(dot(n, v), 0.0, 1.0);
	return 0.14 + 0.84 * pow(1.0 - c, 3.0);
}

// 안개(다른 권역 셰이더와 같은 식)
vec4 w_fog(vec3 fog_c, float dens, float mist_b, float wy, float d) {
	float fog_f = 1.0 - exp(-dens * dens * d * d);
	float fog_mist = dens * 24.0 * (1.0 - smoothstep(-2.0, 7.0, wy - mist_b)) * smoothstep(14.0, 48.0, d);
	fog_f = 1.0 - (1.0 - fog_f) * (1.0 - clamp(fog_mist, 0.0, 0.8));
	return vec4(fog_c, fog_f);
}

// light()에서: 붓 바림 확산 + 해 반짝임(단단한 점으로 끊음 — 그늘에선 없다, 밤엔 달빛·등불만큼)
#define WATER_LIGHT \
	float ndl = dot(NORMAL, LIGHT); \
	float ramp = texture(ramp_tex, vec2(ndl * 0.5 + 0.5, 0.5)).r; \
	DIFFUSE_LIGHT += ramp * ATTENUATION * LIGHT_COLOR / (PI * PI); \
	vec3 hv = normalize(LIGHT + VIEW); \
	float sp = pow(max(dot(NORMAL, hv), 0.0), 260.0); \
	float gl = smoothstep(0.18, 0.5, sp) + pow(max(dot(NORMAL, hv), 0.0), 40.0) * 0.06; \
	SPECULAR_LIGHT += gl * glint_k * ATTENUATION * LIGHT_COLOR / PI;
