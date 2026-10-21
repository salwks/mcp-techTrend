// 재질 디테일 굽기(tools/matlight/bake_pbr.gd) — 층(layer)마다 이음매 없는 절차 무늬를 512² 두 장으로 굽는다.
//   mode 0 = A: rgb 바탕색 배율 / 2 (평균 0.5 = 배율 1, 키트 버텍스 색·아틀라스 색은 그대로 두고 잔무늬만 더한다), a 높이(0 깊음 ~ 1 높음)
//   mode 1 = B: r 거칠기, g 법선 y, b 오목(AO), a 법선 x  (BC3에서 법선 x를 알파에 두면 덜 뭉개진다)
// 층 번호는 shaders/pbr_common.gdshaderinc의 M_* 와 같아야 한다.
shader_type canvas_item;
render_mode blend_disabled, unshaded;

uniform int layer = 0;
uniform int mode = 0;
uniform float slope_k = 1.0;   // 깊이(m) / 한 장 크기(m) — 법선 기울기를 실제 깊이에 맞춘다
uniform float res = 512.0;

// ---- 이음매 없는(주기) 잡음 ----
float h21(vec2 p) {
	p = fract(p * vec2(0.1031, 0.1030));
	p += dot(p, p.yx + 33.33);
	return fract((p.x + p.y) * p.x);
}
vec2 h22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}
float vn(vec2 p, vec2 P) {   // 값 잡음, 주기 P(정수 칸)
	vec2 i = floor(p), f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = h21(mod(i, P)), b = h21(mod(i + vec2(1, 0), P));
	float c = h21(mod(i + vec2(0, 1), P)), d = h21(mod(i + vec2(1, 1), P));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}
float fbm(vec2 uv, vec2 P, int oct) {   // uv 0~1 한 장, P 첫 옥타브 칸 수
	float s = 0.0, a = 0.5, n = 0.0;
	for (int i = 0; i < 8; i++) {
		if (i >= oct) break;
		s += a * vn(uv * P + float(i) * 17.0, P);
		n += a; a *= 0.5; P *= 2.0;
	}
	return s / n;
}
float ridged(vec2 uv, vec2 P, int oct) {
	float s = 0.0, a = 0.5, n = 0.0;
	for (int i = 0; i < 8; i++) {
		if (i >= oct) break;
		s += a * (1.0 - abs(vn(uv * P + float(i) * 7.0, P) * 2.0 - 1.0));
		n += a; a *= 0.5; P *= 2.0;
	}
	return s / n;
}
// 보로노이: x = 가까운 점 거리, y = 경계까지 거리(F2-F1 근사), z = 칸 해시
vec3 vor(vec2 uv, vec2 P, float jit) {
	vec2 p = uv * P;
	vec2 i = floor(p), f = fract(p);
	float d1 = 9.0, d2 = 9.0; vec2 c1 = vec2(0);
	vec2 o1 = vec2(0);
	for (int y = -1; y <= 1; y++) for (int x = -1; x <= 1; x++) {
		vec2 g = vec2(float(x), float(y));
		vec2 o = g + 0.5 + (h22(mod(i + g, P)) - 0.5) * jit;
		float d = length(o - f);
		if (d < d1) { d2 = d1; d1 = d; c1 = mod(i + g, P); o1 = o; } else if (d < d2) d2 = d;
	}
	// 경계 거리(정확한 판): 둘째 고리
	float md = 9.0;
	for (int y = -2; y <= 2; y++) for (int x = -2; x <= 2; x++) {
		vec2 g = vec2(float(x), float(y));
		vec2 o = g + 0.5 + (h22(mod(i + g, P)) - 0.5) * jit;
		if (dot(o - o1, o - o1) > 1e-5) md = min(md, dot(0.5 * (o1 + o) - f, normalize(o - o1)));
	}
	return vec3(d1, md, h21(c1 + 3.1));
}

// ---- 재질 ----
// alb: 배율(평균 1), h: 0~1, r: 거칠기
void surf(vec2 uv, out vec3 alb, out float h, out float r) {
	alb = vec3(1.0); h = 0.5; r = 0.85;
	if (layer == 0) {   // 회벽: 고운 흙손 자국 · 드문 실금
		float n = fbm(uv, vec2(6), 5);
		float tr = fbm(vec2(uv.x, uv.y), vec2(3, 14), 3);
		vec3 v = vor(uv, vec2(5), 0.9);
		float crack = (1.0 - smoothstep(0.0, 0.005, v.y)) * smoothstep(0.72, 0.82, fbm(uv, vec2(4), 3));
		h = 0.55 + 0.25 * (n - 0.5) + 0.12 * (tr - 0.5) - 0.45 * crack;
		alb = vec3(1.0 + 0.08 * (n - 0.5) - 0.2 * crack) * mix(vec3(1.0), vec3(1.02, 1.0, 0.94), smoothstep(0.5, 0.8, fbm(uv, vec2(2), 3)));
		r = 0.86 + 0.08 * (n - 0.5);
	} else if (layer == 1) {   // 흙벽: 거친 흙 + 짚 여물 + 갈라짐 + 잔돌
		float n = fbm(uv, vec2(5), 6);
		vec3 v = vor(uv, vec2(4), 1.0);
		float crack = (1.0 - smoothstep(0.0, 0.007, v.y)) * smoothstep(0.62, 0.76, fbm(uv, vec2(3), 3));
		// 짚 여물: 칸마다 짧은 선 하나
		float straw = 0.0;
		vec2 P = vec2(26);
		vec2 q = uv * P; vec2 ci = floor(q);
		for (int y = -1; y <= 1; y++) for (int x = -1; x <= 1; x++) {
			vec2 c = ci + vec2(float(x), float(y));
			vec2 hh = h22(mod(c, P));
			float a = hh.x * 6.2832;
			vec2 dir = vec2(cos(a), sin(a));
			vec2 cen = c + 0.5 + (hh - 0.5) * 0.8;
			vec2 d = q - cen;
			float along = dot(d, dir), across = dot(d, vec2(-dir.y, dir.x));
			float len = 0.7 + 0.8 * h21(c + 9.0);
			straw = max(straw, (1.0 - smoothstep(0.03, 0.07, abs(across))) * (1.0 - smoothstep(len * 0.8, len, abs(along))) * step(0.35, h21(c + 4.0)));
		}
		vec3 pv = vor(uv, vec2(18), 1.0);
		float peb = (1.0 - smoothstep(0.12, 0.2, pv.x)) * step(0.82, pv.z);
		h = 0.5 + 0.45 * (n - 0.5) + 0.12 * straw + 0.2 * peb - 0.35 * crack;
		alb = vec3(1.0 + 0.16 * (n - 0.5)) * mix(vec3(1.0), vec3(1.18, 1.1, 0.85), straw * 0.8) * (1.0 - 0.22 * crack) * mix(vec3(1.0), vec3(0.92, 0.94, 0.98), peb);
		r = 0.95 - 0.1 * straw;
	} else if (layer == 2) {   // 이엉: 세로(v) 짚 올 + 네 켜 겹침
		float course = uv.y * 4.0 + 0.12 * (fbm(vec2(uv.x, 0.0), vec2(8, 1), 3) - 0.5);
		float c = fract(course);
		float ci = floor(course);
		float su = uv.x * 140.0 + 2.0 * fbm(uv, vec2(3, 2), 3) + ci * 37.0;
		float s = fract(su);
		float sid = h21(vec2(floor(su), ci));
		float strand = sqrt(max(0.0, 1.0 - pow(2.0 * s - 1.0, 2.0))) * (0.6 + 0.4 * sid);
		// 올 끝이 켜 아래에서 들쭉날쭉
		float endv = 0.9 + 0.1 * h21(vec2(floor(su), ci + 5.0));
		float body = smoothstep(0.0, 0.35, c) * (1.0 - smoothstep(endv - 0.06, endv, c));
		h = 0.15 + 0.55 * c * body + 0.3 * strand * body;
		float fine = fbm(uv, vec2(2, 6), 4);
		alb = vec3(0.82 + 0.36 * sid) * (0.7 + 0.3 * c) * mix(vec3(1.0), vec3(0.85, 0.86, 0.88), smoothstep(0.55, 0.75, fine));
		r = 0.92;
	} else if (layer == 3) {   // 기와: 구운 흙 잔결 · 작은 패임 · 이끼 얼룩(골은 아틀라스 무늬가 맡는다)
		float n = fbm(uv, vec2(8), 5);
		vec3 v = vor(uv, vec2(30), 1.0);
		float pit = (1.0 - smoothstep(0.05, 0.12, v.x)) * step(0.7, v.z);
		float moss = smoothstep(0.66, 0.8, fbm(uv, vec2(3), 4));
		h = 0.6 + 0.2 * (n - 0.5) - 0.4 * pit + 0.1 * moss;
		alb = vec3(1.0 + 0.12 * (n - 0.5)) * mix(vec3(1.0), vec3(0.86, 0.9, 0.8), moss * 0.45) * (1.0 - 0.3 * pit);
		r = 0.6 + 0.25 * moss + 0.1 * (n - 0.5);
	} else if (layer == 4 || layer == 5) {   // 나무(비바람에 닳음): u로 결 · 옹이 · 갈라짐. 5 마루: 닦여 반들 + 널 이음
		vec3 kv = vor(uv, vec2(2, 3), 0.8);
		float knot = (1.0 - smoothstep(0.0, 0.12, kv.x)) * step(0.65, kv.z);
		float warp = fbm(uv, vec2(2, 3), 4) * 3.0 + knot * 2.0 * (1.0 - kv.x / 0.12);
		float ring = sin((uv.y * 38.0 + warp) * 6.2832);
		float grain = fbm(vec2(uv.x, uv.y), vec2(3, 60), 3);
		float lines = smoothstep(0.3, 1.0, ring) ;
		float check = (1.0 - smoothstep(0.0, 0.006, abs(fract(uv.y * 5.0 + 0.4 * fbm(uv, vec2(2, 1), 3)) - 0.5))) * smoothstep(0.55, 0.7, fbm(uv, vec2(3, 1), 3));
		float seam = 0.0;
		if (layer == 5) seam = 1.0 - smoothstep(0.0, 0.01, abs(fract(uv.y * 4.0) - 0.5) - 0.49);
		float wear = layer == 4 ? 0.35 : 0.12;
		h = 0.55 + wear * (lines - 0.5) + 0.15 * (grain - 0.5) - 0.6 * check - 0.4 * knot * (1.0 - kv.x / 0.12) - 0.5 * seam;
		float gray = layer == 4 ? smoothstep(0.45, 0.7, fbm(uv, vec2(2), 4)) : 0.0;
		alb = vec3(1.0 + 0.18 * (lines - 0.5) + 0.1 * (grain - 0.5)) * mix(vec3(1.0), vec3(0.85, 0.83, 0.82), gray * 0.6) * (1.0 - 0.45 * check) * (1.0 - 0.35 * knot) * (1.0 - 0.4 * seam);
		r = layer == 4 ? 0.78 + 0.1 * gray : 0.42 + 0.1 * (grain - 0.5);
	} else if (layer == 6) {   // 한지: 닥 섬유
		float n = fbm(uv, vec2(10), 5);
		float fib = 0.0;
		vec2 P = vec2(40); vec2 q = uv * P; vec2 ci = floor(q);
		for (int y = -1; y <= 1; y++) for (int x = -1; x <= 1; x++) {
			vec2 c = ci + vec2(float(x), float(y));
			vec2 hh = h22(mod(c, P));
			float a = hh.y * 6.2832; vec2 dir = vec2(cos(a), sin(a));
			vec2 d = q - (c + hh);
			float cur = dot(d, vec2(-dir.y, dir.x)) + 0.25 * sin(dot(d, dir) * 3.0);
			fib = max(fib, (1.0 - smoothstep(0.01, 0.04, abs(cur))) * (1.0 - smoothstep(1.0, 1.6, abs(dot(d, dir)))));
		}
		h = 0.5 + 0.2 * (n - 0.5) + 0.15 * fib;
		alb = vec3(1.0 + 0.06 * (n - 0.5) + 0.05 * fib);
		r = 0.9;
	} else if (layer == 7) {   // 돌(기단·돌담): 막돌 + 깊은 줄눈
		vec3 v = vor(uv, vec2(4, 5), 0.85);
		float edge = v.y;
		float dome = smoothstep(0.0, 0.16, edge);
		float n = fbm(uv, vec2(6), 5);
		float rough_s = ridged(uv, vec2(10), 3);
		h = 0.08 + 0.75 * dome * (0.8 + 0.2 * v.z) + 0.15 * (n - 0.5) * dome + 0.06 * rough_s;
		float joint = 1.0 - smoothstep(0.0, 0.05, edge);
		vec3 tint = mix(vec3(1.06, 1.02, 0.95), vec3(0.92, 0.96, 1.02), v.z) * (0.88 + 0.24 * fract(v.z * 7.3));
		float lichen = smoothstep(0.62, 0.78, fbm(uv, vec2(5), 4)) * dome;
		alb = mix(tint * (1.0 + 0.15 * (n - 0.5)), vec3(0.62, 0.56, 0.48), joint) * mix(vec3(1.0), vec3(1.08, 1.1, 0.95), lichen * 0.6);
		r = mix(0.82, 0.95, joint);
	} else if (layer == 8) {   // 자연석·바위: 결 잡음 + 균열
		float n = ridged(uv, vec2(4), 6);
		vec3 v = vor(uv, vec2(3), 1.0);
		float frac_ = 1.0 - smoothstep(0.0, 0.02, v.y);
		h = 0.35 + 0.6 * n - 0.4 * frac_;
		alb = vec3(0.86 + 0.3 * n) * (1.0 - 0.3 * frac_) * mix(vec3(1.0), vec3(1.05, 1.0, 0.92), fbm(uv, vec2(2), 3));
		r = 0.85;
	} else if (layer == 9) {   // 박석: 넓적한 판돌 + 흙 줄눈
		vec3 v = vor(uv, vec2(3), 0.9);
		float dome = smoothstep(0.0, 0.08, v.y);
		float n = fbm(uv, vec2(8), 5);
		h = 0.1 + 0.7 * dome + 0.12 * (n - 0.5) * dome + 0.1 * (v.z - 0.5) * dome;
		float joint = 1.0 - smoothstep(0.0, 0.04, v.y);
		alb = mix(vec3(0.9 + 0.2 * v.z) * (1.0 + 0.14 * (n - 0.5)), vec3(0.6, 0.55, 0.46), joint);
		r = mix(0.78, 0.95, joint);
	} else if (layer == 10 || layer == 11) {   // 흙 마당 / 다진 길: 흙덩이 · 자갈
		float n = fbm(uv, vec2(6), 6);
		vec3 g1 = vor(uv, vec2(layer == 10 ? 22.0 : 34.0), 1.0);
		float peb = (1.0 - smoothstep(0.18, 0.32, g1.x)) * step(layer == 10 ? 0.72 : 0.55, g1.z);
		vec3 g2 = vor(uv, vec2(7), 1.0);
		float stone = (1.0 - smoothstep(0.1, 0.2, g2.x)) * step(0.9, g2.z);
		float clod = layer == 10 ? ridged(uv, vec2(8), 3) : 0.5;
		h = 0.4 + (layer == 10 ? 0.3 : 0.15) * (n - 0.5) + 0.25 * peb * (1.0 - g1.x / 0.32) + 0.4 * stone + (layer == 10 ? 0.15 * (clod - 0.5) : 0.0);
		alb = vec3(1.0 + 0.16 * (n - 0.5)) * mix(vec3(1.0), vec3(0.95, 0.95, 1.0) * (0.85 + 0.3 * g1.z), peb) * mix(vec3(1.0), vec3(0.9, 0.9, 0.92), stone);
		r = 0.95 - 0.08 * peb;
	} else if (layer == 12) {   // 풀: 짧은 잎 획 다발
		float acc = 0.0, top = 0.0;
		for (int k = 0; k < 3; k++) {
			vec2 P = vec2(28.0 + float(k) * 9.0);
			vec2 q = uv * P; vec2 ci = floor(q);
			for (int y = -1; y <= 1; y++) for (int x = -1; x <= 1; x++) {
				vec2 c = ci + vec2(float(x), float(y));
				vec2 hh = h22(mod(c, P) + float(k) * 13.0);
				float a = -1.5708 + (hh.x - 0.5) * 1.6;
				vec2 dir = vec2(cos(a), sin(a));
				vec2 d = q - (c + hh);
				float al = dot(d, dir), ac = dot(d, vec2(-dir.y, dir.x));
				float len = 0.8 + 0.6 * hh.y;
				float w = 0.08 * (1.0 - clamp(al / len, 0.0, 1.0));
				float m = (1.0 - smoothstep(w * 0.6, w, abs(ac))) * step(0.0, al) * step(al, len);
				if (m > acc) { acc = m; top = al / len; }
			}
		}
		float n = fbm(uv, vec2(4), 4);
		h = 0.2 + 0.7 * acc * (0.4 + 0.6 * top) + 0.1 * n;
		alb = vec3(0.65 + 0.55 * acc * (0.6 + 0.4 * top)) * mix(vec3(1.0), vec3(1.1, 1.05, 0.8), smoothstep(0.6, 0.8, n) * 0.6);
		r = 0.9;
	} else if (layer == 13) {   // 장판: 기름 먹인 종이 — 고운 결, 반들
		float n = fbm(uv, vec2(12), 5);
		h = 0.5 + 0.1 * (n - 0.5);
		alb = vec3(1.0 + 0.1 * (n - 0.5)) * mix(vec3(1.0), vec3(0.94, 0.9, 0.85), smoothstep(0.55, 0.8, fbm(uv, vec2(3), 4)));
		r = 0.32 + 0.12 * fbm(uv, vec2(5), 3);
	} else if (layer == 14) {   // 나무껍질: 세로(v) 골
		float n = ridged(vec2(uv.x, uv.y), vec2(14, 3), 5);
		float plate = vor(uv, vec2(7, 3), 0.9).y;
		h = 0.2 + 0.6 * n * smoothstep(0.0, 0.08, plate);
		alb = vec3(0.75 + 0.5 * h);
		r = 0.92;
	} else if (layer == 15) {   // 잎: 잎맥 · 얼룩
		float n = fbm(uv, vec2(10), 5);
		vec3 v = vor(uv, vec2(12), 0.9);
		h = 0.5 + 0.3 * smoothstep(0.0, 0.1, v.y) + 0.1 * (n - 0.5);
		alb = vec3(0.85 + 0.3 * n) * (0.85 + 0.3 * v.z);
		r = 0.65;
	} else if (layer == 16) {   // 천: 평직
		float wu = sin(uv.x * 6.2832 * 64.0), wv = sin(uv.y * 6.2832 * 64.0);
		float chk = step(0.0, sin(uv.x * 6.2832 * 32.0) * sin(uv.y * 6.2832 * 32.0));
		h = 0.5 + 0.25 * mix(abs(wu), abs(wv), chk);
		alb = vec3(0.93 + 0.14 * fbm(uv, vec2(16), 4));
		r = 0.92;
	} else if (layer == 17) {   // 눈: 부드러운 물결 · 알갱이 없음
		float n = fbm(uv, vec2(3), 5);
		h = 0.5 + 0.4 * (n - 0.5) + 0.08 * (fbm(uv, vec2(20), 3) - 0.5);
		alb = vec3(1.0 + 0.03 * (n - 0.5));
		r = 0.78;
	}
}

float hgt(vec2 uv) { vec3 a; float h; float r; surf(fract(uv), a, h, r); return clamp(h, 0.0, 1.0); }

void fragment() {
	vec2 uv = UV;
	vec3 alb; float h; float r;
	surf(uv, alb, h, r);
	h = clamp(h, 0.0, 1.0);
	if (mode == 0) {
		COLOR = vec4(clamp(alb * 0.5, 0.0, 1.0), h);
	} else {
		float e = 1.0 / res;
		float dx = (hgt(uv + vec2(e, 0)) - hgt(uv - vec2(e, 0))) / (2.0 * e);
		float dy = (hgt(uv + vec2(0, e)) - hgt(uv - vec2(0, e))) / (2.0 * e);
		vec3 n = normalize(vec3(-dx * slope_k, -dy * slope_k, 1.0));
		// 오목(AO): 둘레 높이가 더 높으면 어둡게(반지름 두 단)
		float occ = 0.0;
		for (int i = 0; i < 8; i++) {
			float a = float(i) * 0.7854;
			vec2 d = vec2(cos(a), sin(a));
			occ += max(0.0, hgt(uv + d * 4.0 * e) - h) + 0.6 * max(0.0, hgt(uv + d * 12.0 * e) - h);
		}
		float ao = clamp(1.0 - occ / 8.0 * 1.6, 0.0, 1.0);
		COLOR = vec4(clamp(r, 0.02, 1.0), n.y * 0.5 + 0.5, ao, n.x * 0.5 + 0.5);
	}
}
