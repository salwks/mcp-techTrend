// 하늘/배경 — 웹 fx/sky.js 이식. 먼 산 능선 세 겹 + 운해 + 하늘 띠 + 별·달.
// 웹처럼 화면 전체 사각형을 가장 먼 깊이에 그린다(Godot Sky를 쓰면 매 프레임 환경 큐브맵을 다시 구워 무겁다).
// 색 uniform은 모두 선형(linear) 값. 결과는 HDR 선형으로 장면 버퍼에 들어가고 후처리가 톤매핑한다.
shader_type spatial;
render_mode unshaded, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;

uniform vec3 u_top;
uniform vec3 u_hor;
uniform vec3 u_low;
uniform vec3 u_fog;
uniform vec3 u_glow;
uniform vec3 u_ink = vec3(0.0103, 0.0131, 0.0232);
uniform float u_glow_i;
uniform float u_night;
uniform float u_time;
uniform vec3 u_sun_dir = vec3(0.0, 0.3, 1.0);
uniform vec3 u_moon_dir = vec3(0.4072, 0.1267, -0.9049);
uniform float u_moon = 1.0;   // 기본 달 보이기(0이면 감춘다 — 남원 마지막 밤의 두 빛 동안만)

float hash11(float p) { p = fract(p * 0.1031); p *= p + 33.33; p *= p + p; return fract(p); }
float hash21(vec2 p) { vec3 p3 = fract(vec3(p.xyx) * 0.1031); p3 += dot(p3, p3.yzx + 33.33); return fract((p3.x + p3.y) * p3.z); }
float noise1(float x) { float i = floor(x), f = fract(x); f = f * f * (3.0 - 2.0 * f); return mix(hash11(i), hash11(i + 1.0), f); }
float noise2(vec2 p) {
	vec2 i = floor(p), f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1, 0)), f.x), mix(hash21(i + vec2(0, 1)), hash21(i + vec2(1, 1)), f.x), f.y);
}
float fbm2(vec2 p) { return noise2(p) * 0.55 + noise2(p * 2.03 + 7.1) * 0.3 + noise2(p * 4.1 + 3.7) * 0.15; }
float ridge(float x, float seed) {
	float n = 0.0, a = 0.6, f = 1.0;
	for (int i = 0; i < 3; i++) {
		float r = 1.0 - abs(noise1(x * f + seed) * 2.0 - 1.0);
		n += r * r * a; a *= 0.45; f *= 2.3;
	}
	return n;
}

varying vec3 v_dir;
void vertex() {
	vec4 v = INV_PROJECTION_MATRIX * vec4(VERTEX.xy, 0.5, 1.0);
	v /= v.w;
	v_dir = mat3(INV_VIEW_MATRIX) * v.xyz;
	POSITION = vec4(VERTEX.xy, 1e-7, 1.0); // 역방향 깊이(Reverse-Z)에서 가장 먼 곳
}
void fragment() {
	vec3 d = normalize(v_dir);
	float e = d.y;
	float az = atan(d.x, -d.z);
	float t = clamp(e / 0.55, 0.0, 1.0);
	float N = 5.0;
	float tb = (floor(t * N) + smoothstep(0.3, 0.7, fract(t * N))) / N;
	t = mix(t, tb, 0.55);
	vec3 sk = mix(u_hor, u_top, pow(t, 0.75));
	vec2 sxz = normalize(u_sun_dir.xz + 1e-4);
	float toward = max(dot(normalize(d.xz + 1e-4), sxz), 0.0);
	float glow = u_glow_i * (0.35 + 0.65 * pow(toward, 3.0)) * exp(-max(e, 0.0) * 5.0);
	sk = mix(sk, u_glow, clamp(glow, 0.0, 1.0));
	float cl = fbm2(vec2(az * 3.0 + u_time * 0.004, e * 22.0));
	sk = mix(sk, mix(u_hor, u_glow, 0.3 * u_glow_i) * 1.04, smoothstep(0.55, 0.8, cl) * 0.35 * smoothstep(0.0, 0.08, e) * (1.0 - t));
	vec2 sc = vec2(az * 60.0, e * 60.0);
	float sh = hash21(floor(sc));
	float star = step(0.985, sh) * smoothstep(0.35, 0.0, length(fract(sc) - 0.5));
	star *= (0.6 + 0.4 * sin(u_time * 2.0 + sh * 80.0));
	sk += vec3(0.9, 0.9, 1.0) * star * u_night * smoothstep(0.03, 0.2, e) * 0.9;
	float md = dot(d, u_moon_dir);
	float disc = smoothstep(0.99955, 0.99975, md);
	float halo = pow(max(md, 0.0), 300.0) * 0.5 + pow(max(md, 0.0), 30.0) * 0.12;
	vec3 moon_col = vec3(1.0, 0.95, 0.82);
	sk = mix(sk, moon_col * 1.6, disc * u_night * u_moon);
	sk += moon_col * halo * u_night * 0.6 * u_moon;

	vec2 pp = d.xz / max(-e, 0.02);
	float c1 = fbm2(pp * 0.9 + vec2(u_time * 0.01, 0.0));
	float c2 = fbm2(pp * 2.3 - vec2(u_time * 0.015, 0.0));
	float billow = smoothstep(0.35, 0.8, c1 * 0.7 + c2 * 0.3);
	vec3 sea = mix(u_low, u_fog, 0.5);
	sea = mix(sea * 0.86 + u_ink * 0.06, mix(sea, u_hor, 0.35) * 1.05, billow);
	sea = mix(sea, u_fog, smoothstep(-0.02, -0.45, e) * 0.55);
	vec3 col = e > 0.0 ? sk : mix(u_hor, sea, smoothstep(0.0, 0.05, -e));

	for (int i = 0; i < 3; i++) {
		float fi = float(i);
		float base = 0.015 - fi * 0.075;
		float amp = 0.1 + fi * 0.035;
		float h = base + amp * (ridge(az * (3.2 + fi * 1.7), 11.0 + fi * 17.0) - 0.35);
		float inside = smoothstep(h + 0.0015, h - 0.0015, e);
		if (inside > 0.0) {
			vec3 mtn = mix(u_hor, u_ink, 0.26 + fi * 0.17);
			mtn = mix(mtn, u_glow, 0.18 * u_glow_i * (1.0 - fi * 0.3));
			float fade = smoothstep(h - 0.01, h - 0.09 - fi * 0.02, e);
			vec3 mist = mix(sea, u_hor, 0.25);
			mtn *= 1.0 - 0.18 * smoothstep(h - 0.012, h - 0.001, e);
			col = mix(col, mix(mtn, mist, fade * 0.9), inside);
		}
	}
	ALBEDO = col;
}
