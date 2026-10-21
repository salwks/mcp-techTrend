# 후처리 — 웹 fx/post.js 이식(컴포지터 효과 + compute 셰이더).
#   장면(HDR, 투명 물체까지 그린 뒤) → 흐림 판(1/2, 가로→세로) → 블룸(1/4, 밝은 부분→가로→세로)
#   → 최종 1패스: 깊이 흐림(장면 깊이로 선명/흐림 섞기 — 피사계 심도) + 먹선 + 블룸 + 톤매핑(Neutral) + sRGB + 색보정 + 한지 + 비네트 + 디더
# 최종 결과(sRGB)는 선형으로 되돌려 장면 버퍼에 쓴다. 이어지는 Godot 출력 단계(톤매퍼 Linear → sRGB)가 그대로 되돌린다.
# SubViewport를 패스마다 이어 붙이는 방식은 이 맥(Metal/Vulkan 모두)에서 패스당 수 ms가 들어 이 방식을 쓴다.
@tool
class_name PostEffect
extends CompositorEffect

# 깊이 흐림(피사계 심도, 2026-10 — 화면 위·아래 띠로 흐리던 틸트시프트를 바꿈): 장면 깊이(해결된 깊이 버퍼)를 카메라에서 잰 거리로 풀어
#   초점 거리(dof_focus — 보통 카메라→플레이어) 둘레 ±dof_margin은 또렷하고, 그 너머는 거리에 따라 천천히(포화) 흐려진다.
#   amt_far = dof_far · x/(1+x), x = (D − F − margin) / (F · dof_far_scale) — 멀리 갈수록 dof_far에 다가갈 뿐 넘지 않는다(약하게).
#   아주 가까운 앞가림(D < 0.55F)만 dof_near만큼 조금. 흐림 판은 하나(1/2 해상도 가우스)라 섞는 비율만 바뀐다.
#   Godot 카메라 속성 DOF 대신 이것을 쓰는 까닭: 이 후처리가 톤매핑·한지·먹선까지 직접 하므로 Godot DOF(톤매핑 단계)가 먹선·한지 결까지 흐린다.
var dof := true
var tilt: bool:   # 옛 이름(--notilt · P 키 · 남원 _tilt) — dof와 같다
	get: return dof
	set(v): dof = v
var dof_focus := 22.0      # m
var dof_margin := 4.0      # m — 초점 둘레 또렷한 폭
var dof_far := 0.55        # 먼 흐림 최대 섞기(0~1)
var dof_far_scale := 1.2   # 클수록 천천히 흐려진다
var dof_near := 0.3        # 가까운 앞가림 흐림 최대
# 먼 산 대기 원근(산수화 — C67 2026-10 v2): 카메라에서 aerial_start(m)부터 aerial_start + aerial_range까지 흐림을 aerial_blur만큼 더 얹고
#   옅은 한지빛 안개(aerial_haze, 밤에는 줄인다)를 조금. aerial_start 안쪽(150m)은 전과 똑같다.
#   1인칭은 카메라 먼 끝이 260m라 그 너머 먼 산은 하늘 그림판 — region_main이 폭을 (260 − 150)으로 줄여 그림판까지 같은 세기로.
var aerial_start := 150.0
var aerial_range := 450.0
var aerial_blur := 0.2
var aerial_haze := 0.12
var bloom := true
var paper := true
# 먹 그늘(화면 공간 차폐 AO, visual-pass 2026-10-17): Mobile에는 Godot SSAO가 없고, Forward+ SSAO도 이 게임 재질(반구광을 EMISSION으로)의
#   그늘을 어둡게 하지 못한다 → 깊이 버퍼로 직접 잰다. 1/2 해상도 12표본(4×4 회전) → 깊이를 보는 4×4 흐림 → 최종 패스에서 장면 색에 곱한다.
#   ao_strength 0이면 끈다(판을 1로 비운다). ao_radius(m) 둘레 가림, ao_far(m) 너머는 서서히 없어진다(먼 산·안개에 얼룩 없게).
var ao_strength := 0.0
var ao_radius := 0.9
var ao_far := 70.0
var ao_low := false        # 낮음: 4표본(설정 '화면 품질' 낮음)
var focus_y := 0.45        # 옛 값(틸트시프트) — main.gd·kit_preview가 아직 넣는다. 쓰지 않는다
var band := 0.07
var top_bias := 1.0
var depth_ok := false      # 깊이 버퍼를 받았나(없으면 흐림 없음)
var _vis := OS.has_environment("DOFVIS")   # 시험 보기: 환경 변수 DOFVIS=1이면 흐림 비율을 회색 화면으로
var paper_ratio := 2.0
var state := {}
var paper_image: Image
# Mobile 렌더러는 장면 버퍼에 밝기를 1/2로 저장한다(0~2 범위를 10비트에 담기 위해). 읽을 때 곱하고 쓸 때 나눈다.
var lum_mult := 1.0
var real := false          # 사실 쪽(scripts/render/look.gd): AgX 톤매핑 + 노출, 먹선·한지 끔, 렌즈 비네트만
var exposure := 1.0
# 지난 일 장면(남원 v3.2 §23 어머니의 과거 장면): 0 보통 ~ 1 — 채도를 크게 빼고 먹빛 가장자리를 두른다(push lift.w로 넘긴다)
var past := 0.0

var rd: RenderingDevice
var _fmt := -1
var _shaders := {}
var _pipes := {}
var _size := Vector2i.ZERO
var _tex := {}
var _lin: RID
var _near: RID
var _rep: RID
var _paper_tex: RID
var _ao_clear := true   # 먹 그늘 판을 1로 비워야 하나(끔·크기 바뀜)
var ao_ok := false      # 이번 프레임 먹 그늘을 그렸나(시험)

const COMMON := """
#version 450
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
"""
const BLUR := """
layout(set = 0, binding = 0) uniform sampler2D src;
layout(%FMT%, set = 0, binding = 1) uniform restrict writeonly image2D dst;
layout(push_constant, std430) uniform P { vec2 step; vec2 inv_size; } p;
void main() {
	ivec2 g = ivec2(gl_GlobalInvocationID.xy);
	if (any(greaterThanEqual(g, imageSize(dst)))) return;
	vec2 uv = (vec2(g) + 0.5) * p.inv_size;
	vec3 c = textureLod(src, uv, 0.0).rgb * 0.227027;
	c += (textureLod(src, uv + p.step * 1.0, 0.0).rgb + textureLod(src, uv - p.step * 1.0, 0.0).rgb) * 0.1945946;
	c += (textureLod(src, uv + p.step * 2.0, 0.0).rgb + textureLod(src, uv - p.step * 2.0, 0.0).rgb) * 0.1216216;
	c += (textureLod(src, uv + p.step * 3.0, 0.0).rgb + textureLod(src, uv - p.step * 3.0, 0.0).rgb) * 0.054054;
	c += (textureLod(src, uv + p.step * 4.0, 0.0).rgb + textureLod(src, uv - p.step * 4.0, 0.0).rgb) * 0.016216;
	imageStore(dst, g, vec4(c, 1.0));
}
"""
const BRIGHT := """
layout(set = 0, binding = 0) uniform sampler2D src;
layout(%FMT%, set = 0, binding = 1) uniform restrict writeonly image2D dst;
layout(push_constant, std430) uniform P { vec2 texel; vec2 inv_size; float threshold; float lum; float pad1; float pad2; } p;
vec3 pick(vec2 uv, vec2 o) {
	vec3 c = min(textureLod(src, uv + o * p.texel, 0.0).rgb * p.lum, vec3(8.0));
	float l = max(c.r, max(c.g, c.b));
	float k = clamp((l - p.threshold) / 0.25, 0.0, 1.0);
	return c * k * k * max(l - p.threshold * 0.7, 0.0) / max(l, 1e-4);
}
void main() {
	ivec2 g = ivec2(gl_GlobalInvocationID.xy);
	if (any(greaterThanEqual(g, imageSize(dst)))) return;
	vec2 uv = (vec2(g) + 0.5) * p.inv_size;
	vec3 c = pick(uv, vec2(-1.0, -1.0)) + pick(uv, vec2(1.0, -1.0)) + pick(uv, vec2(-1.0, 1.0)) + pick(uv, vec2(1.0, 1.0));
	imageStore(dst, g, vec4(c * 0.25 / p.lum, 1.0));
}
"""
# 먹 그늘 0: 1/2 해상도 선형 깊이(m) — MSAA 깊이를 표본마다 읽으면 느리다(M1에서 12표본 ≈ 4ms) → 한 번만 읽어 둔다
const AO_Z := """
#ifdef DEPTH_MS
layout(set = 0, binding = 0) uniform sampler2DMS t_depth;
#else
layout(set = 0, binding = 0) uniform sampler2D t_depth;
#endif
layout(r32f, set = 0, binding = 1) uniform restrict writeonly image2D dst;
layout(push_constant, std430) uniform P { vec2 full; vec2 inv_half; float pa; float pb; float pad0; float pad1; } p;
void main() {
	ivec2 g = ivec2(gl_GlobalInvocationID.xy);
	ivec2 sz = imageSize(dst);
	if (any(greaterThanEqual(g, sz))) return;
	vec2 uv = (vec2(g) + 0.5) * p.inv_half;
#ifdef DEPTH_MS
	float d = texelFetch(t_depth, clamp(ivec2(uv * p.full), ivec2(0), ivec2(p.full) - 1), 0).r;
#else
	float d = textureLod(t_depth, uv, 0.0).r;
#endif
	imageStore(dst, g, vec4(d <= 1e-6 ? 1e5 : p.pb / max(d + p.pa, 1e-7)));
}
"""
# 먹 그늘 1: 선형 깊이로 보기 공간 자리·법선을 풀고 둘레 표본이 반구 안에서 가리는 정도(Alchemy AO 꼴)
const AO := """
layout(set = 0, binding = 0) uniform sampler2D t_z;
layout(rg16f, set = 0, binding = 1) uniform restrict writeonly image2D dst;
layout(push_constant, std430) uniform P { vec2 half_sz; vec2 inv_half; float p00; float p11; float radius; float far_m; float n; float pad0; float pad1; float pad2; } p;
vec3 vpos(ivec2 c) {
	float D = texelFetch(t_z, c, 0).r;
	vec2 ndc = (vec2(c) + 0.5) * p.inv_half * 2.0 - 1.0;
	return vec3(ndc.x / p.p00 * D, -ndc.y / p.p11 * D, -D);
}
void main() {
	ivec2 g = ivec2(gl_GlobalInvocationID.xy);
	ivec2 sz = imageSize(dst);
	if (any(greaterThanEqual(g, sz))) return;
	vec3 P = vpos(g);
	float D = -P.z;
	if (D > p.far_m * 1.2) { imageStore(dst, g, vec4(0.0, D, 0.0, 0.0)); return; }
	ivec2 mx = sz - 1;
	vec3 Pr = vpos(min(g + ivec2(1, 0), mx)), Pl = vpos(max(g - ivec2(1, 0), ivec2(0)));
	vec3 Pd = vpos(min(g + ivec2(0, 1), mx)), Pu = vpos(max(g - ivec2(0, 1), ivec2(0)));
	vec3 dx = abs(Pr.z - P.z) < abs(P.z - Pl.z) ? Pr - P : P - Pl;
	vec3 dy = abs(Pd.z - P.z) < abs(P.z - Pu.z) ? Pd - P : P - Pu;
	vec3 N = normalize(cross(dy, dx));
	if (N.z < 0.0) N = -N;
	vec2 r_px = vec2(p.radius * p.p00, p.radius * p.p11) * 0.5 / D * p.half_sz;
	const float BAYER[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	ivec2 q = g % 4;
	float rot = BAYER[q.y * 4 + q.x] / 16.0 * 6.2832;
	int n = int(p.n);
	float occ = 0.0;
	float r2 = p.radius * p.radius;
	for (int i = 0; i < n; i++) {
		float t = (float(i) + 0.5) / float(n);
		float a = rot + float(i) * 2.39996;   // 황금각 나선
		ivec2 sc = g + ivec2(vec2(cos(a), sin(a)) * sqrt(t) * r_px);
		if (any(lessThan(sc, ivec2(0))) || any(greaterThan(sc, mx))) continue;
		vec3 v = vpos(sc) - P;
		if (v.z < -p.radius * 4.0) continue;   // 하늘·먼 곳
		float vv = dot(v, v);
		float h = max(dot(v, N) - 0.002 * D - 0.05, 0.0) / (vv + 0.01 * r2);
		occ += h * max(1.0 - vv / (r2 * 2.0), 0.0);
	}
	occ = clamp(occ * 3.2 * p.radius / float(n), 0.0, 1.0);
	imageStore(dst, g, vec4(occ, D, 0.0, 0.0));
}
"""
# 먹 그늘 2: 깊이를 보는 4×4 흐림(회전 무늬 4×4를 꼭 덮는다) → 곱할 값(1 = 그늘 없음)
const AO_BLUR := """
layout(set = 0, binding = 0) uniform sampler2D src;
layout(rgba16f, set = 0, binding = 1) uniform restrict writeonly image2D dst;
layout(push_constant, std430) uniform P { vec2 inv_half; float strength; float far_m; } p;
void main() {
	ivec2 g = ivec2(gl_GlobalInvocationID.xy);
	ivec2 sz = imageSize(dst);
	if (any(greaterThanEqual(g, sz))) return;
	vec2 c0 = texelFetch(src, g, 0).rg;
	float D = c0.g;
	float s = 0.0, w = 0.0;
	for (int y = -2; y < 2; y++) for (int x = -2; x < 2; x++) {
		vec2 c = texelFetch(src, clamp(g + ivec2(x, y), ivec2(0), sz - 1), 0).rg;
		float k = max(0.0, 1.0 - abs(c.g - D) / (0.04 * D + 0.1));
		s += c.r * k; w += k;
	}
	float occ = w > 0.0 ? s / w : 0.0;
	float fade = 1.0 - smoothstep(p.far_m * 0.6, p.far_m, D);
	float m = 1.0 - p.strength * occ * fade;
	imageStore(dst, g, vec4(m, m, m, 1.0));
}
"""
const FINAL := """
layout(set = 0, binding = 0) uniform sampler2D t_scene;
layout(set = 0, binding = 1) uniform sampler2D t_blur;
layout(set = 0, binding = 2) uniform sampler2D t_bloom;
layout(set = 0, binding = 3) uniform sampler2D t_paper;
layout(%FMT%, set = 0, binding = 4) uniform restrict writeonly image2D dst;
#ifdef DEPTH_MS
layout(set = 0, binding = 5) uniform sampler2DMS t_depth;
#else
layout(set = 0, binding = 5) uniform sampler2D t_depth;
#endif
layout(set = 0, binding = 6) uniform sampler2D t_ao;   // 먹 그늘(1/2 해상도 곱할 값, 끄면 1)
layout(push_constant, std430) uniform P {
	vec2 texel; vec2 paper_scale;
	float aspect; float focus; float pa; float lum;
	float pb; float far_k; float near_k; float bloom;
	float sat; float paper; float ink; float night;
	vec4 lift; vec4 gamma; vec4 gain;
	vec4 aerial;   // 먼 산 대기 원근: 시작(m) · 폭(m) · 더할 흐림 · 안개
} p;
const vec3 TINT = vec3(1.0, 0.985, 0.955);
float luma(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }
vec3 neutral_tm(vec3 color) {
	const float S = 0.76; const float D = 0.15;
	float x = min(color.r, min(color.g, color.b));
	float offset = x < 0.08 ? x - 6.25 * x * x : 0.04;
	color -= offset;
	float peak = max(color.r, max(color.g, color.b));
	if (peak < S) return color;
	float d = 1.0 - S;
	float np = 1.0 - d * d / (peak + d - S);
	color *= np / peak;
	float g = 1.0 - 1.0 / (D * (peak - np) + 1.0);
	return mix(color, vec3(np), g);
}
// AgX(Troy Sobotka) 기본 + Punchy 모양 — 출력은 화면(감마) 값
vec3 agx(vec3 c) {
	const mat3 inm = mat3(vec3(0.842479062253094, 0.0423282422610123, 0.0423756549057051), vec3(0.0784335999999992, 0.878468636469772, 0.0784336), vec3(0.0792237451477643, 0.0791661274605434, 0.879142973793104));
	const mat3 outm = mat3(vec3(1.19687900512017, -0.0528968517574562, -0.0529716355144438), vec3(-0.0980208811401368, 1.15190312990417, -0.0980434501171241), vec3(-0.0990297440797205, -0.0989611768448433, 1.15107367264116));
	const float mn = -12.47393, mx = 4.026069;
	c = inm * max(c, vec3(0.0));
	c = clamp(log2(max(c, vec3(1e-10))), mn, mx);
	c = (c - mn) / (mx - mn);
	vec3 x2 = c * c; vec3 x4 = x2 * x2;
	c = 15.5 * x4 * x2 - 40.14 * x4 * c + 31.96 * x4 - 6.868 * x2 * c + 0.4298 * x2 + 0.1191 * c - 0.00232;
	c = pow(max(c, vec3(0.0)), vec3(1.3));   // Punchy: 대비
	float l = dot(c, vec3(0.2126, 0.7152, 0.0722));
	c = l + 1.3 * (c - l);                    // Punchy: 채도
	c = outm * c;
	return clamp(c, 0.0, 1.0);
}
vec3 to_srgb(vec3 c) {
	c = max(c, vec3(0.0));
	return mix(pow(c, vec3(0.41666)) * 1.055 - 0.055, c * 12.92, vec3(lessThanEqual(c, vec3(0.0031308))));
}
vec3 to_linear(vec3 c) {
	c = max(c, vec3(0.0));
	return mix(pow((c + 0.055) / 1.055, vec3(2.4)), c / 12.92, vec3(lessThanEqual(c, vec3(0.04045))));
}
void main() {
	ivec2 g = ivec2(gl_GlobalInvocationID.xy);
	ivec2 sz = imageSize(dst);
	if (any(greaterThanEqual(g, sz))) return;
	vec2 uv = (vec2(g) + 0.5) / vec2(sz);
	float vy = 1.0 - uv.y;
	float ao = textureLod(t_ao, uv, 0.0).r;
#ifdef AOVIS
	imageStore(dst, g, vec4(to_linear(vec3(ao)) / p.lum, 1.0)); return;
#endif
	vec3 c = textureLod(t_scene, uv, 0.0).rgb * p.lum;
	float amt = 0.0;
	float haze = 0.0;
	if (p.far_k + p.near_k + p.aerial.z + p.aerial.w > 0.001) {
		// 깊이 → 카메라 거리(m). Godot 4.3+ 깊이는 거꾸로(가까이 1, 멀리 0)
#ifdef DEPTH_MS
		float d = texelFetch(t_depth, ivec2(uv * vec2(textureSize(t_depth))), 0).r;   // MSAA 깊이: 첫 표본(Mobile은 깊이 해결을 못 한다)
#else
		float d = textureLod(t_depth, uv, 0.0).r;
#endif
		float D = p.pb / max(d + p.pa, 1e-7);
		float x = max(D - p.focus - p.gamma.w, 0.0) / max(p.focus * p.gain.w, 0.1);
		float a_far = p.far_k * x / (1.0 + x);
		float aer = smoothstep(p.aerial.x, p.aerial.x + p.aerial.y, D);   // 먼 산(150m 밖)만
		a_far += p.aerial.z * aer;
		haze = p.aerial.w * aer;
		bool vis = p.near_k > 5.0;   // 시험 보기(DOFVIS): 흐림 비율을 회색으로
		float a_near = (vis ? p.near_k - 10.0 : p.near_k) * smoothstep(0.0, 1.0, (p.focus * 0.55 - D) / max(p.focus * 0.45, 0.1));
		amt = clamp(max(a_far, a_near), 0.0, 1.0);
		if (vis) { imageStore(dst, g, vec4(to_linear(vec3(amt)), 1.0) / p.lum); return; }
		c = mix(c, textureLod(t_blur, uv, 0.0).rgb * p.lum, amt);
	}
	c *= ao * vec3(1.0, 0.995, 0.985) + (1.0 - ao) * vec3(0.06, 0.05, 0.045);   // 그늘은 조금 따뜻한 먹빛으로
	bool real = p.ink < 0.0;
	if (real) c *= -p.ink;
	if (p.ink > 0.0 && amt < 0.6) {
		float l = sqrt(luma(textureLod(t_scene, uv - vec2(p.texel.x, 0.0), 0.0).rgb * p.lum));
		float r = sqrt(luma(textureLod(t_scene, uv + vec2(p.texel.x, 0.0), 0.0).rgb * p.lum));
		float d = sqrt(luma(textureLod(t_scene, uv + vec2(0.0, p.texel.y), 0.0).rgb * p.lum));
		float u = sqrt(luma(textureLod(t_scene, uv - vec2(0.0, p.texel.y), 0.0).rgb * p.lum));
		float e = length(vec2(r - l, u - d));
		c *= 1.0 - p.ink * 0.35 * smoothstep(0.06, 0.28, e) * (1.0 - amt / 0.6);
	}
	if (p.bloom > 0.0) c += textureLod(t_bloom, uv, 0.0).rgb * p.lum * p.bloom;
	c = real ? agx(c) : to_srgb(neutral_tm(c));
	c = mix(c, vec3(0.85, 0.855, 0.835), haze * (1.0 - 0.8 * p.night));   // 먼 산 옅은 안개(대기 원근)
	if (real) {
		// 사실 쪽: 시간대 색보정의 검정 들기(lift)·감마 들기는 그림 쪽 것 — 낮에는 뿌연 막이 되므로 빼고 빛깔(gain)만 남긴다.
		//   밤은 달빛 푸른 들기를 반쯤 남긴다(어둠 속 길·집 모양이 읽히게)
		c = p.gain.rgb * (c + p.lift.rgb * 0.6 * p.night * (1.0 - c));
	} else {
		c = p.gain.rgb * (c + p.lift.rgb * (1.0 - c));
		c = pow(max(c, vec3(0.0)), 1.0 / p.gamma.rgb);
	}
	float L = luma(c);
	c = mix(vec3(L), c, p.sat);
	float sh = (1.0 - L) * (1.0 - L);
	c *= mix(vec3(1.0), vec3(0.93, 0.97, 1.07), sh * 0.6);
	c *= mix(vec3(1.0), vec3(1.03, 1.0, 0.96), smoothstep(0.5, 1.0, L) * 0.5);
	vec3 pp = textureLod(t_paper, (vec2(g) + 0.5) * p.paper_scale, 0.0).rgb;
	c = mix(c, c * TINT, p.paper * 0.6);
	c *= 1.0 + p.paper * ((pp.r - 0.5) * (0.16 + 0.12 * L) + (pp.g - 0.5) * 0.08);
	c = mix(c, TINT * 0.97, p.paper * 0.1 * smoothstep(0.75, 1.0, L));
	vec2 q = (vec2(uv.x, vy) - 0.5) * vec2(p.aspect, 1.0);
	float v = smoothstep(0.35 + 0.5 * p.aspect, 0.25, length(q) * 0.9);
	vec3 vc = mix(vec3(0.16, 0.12, 0.09), vec3(0.05, 0.06, 0.1), p.night);
	c = mix(c, c * vc * 2.2, (1.0 - v) * p.paper * 0.55);
	if (real) c *= mix(1.0, smoothstep(1.25, 0.35, length(q)), 0.35);   // 렌즈 비네트(옅게)
	float past = p.lift.w;
	if (past > 0.0) {
		// 지난 일: 채도를 크게 빼고 한지빛으로 · 붓 자국처럼 들쭉날쭉한 먹빛 가장자리
		float Lp = luma(c);
		c = mix(c, vec3(Lp) * vec3(1.03, 1.0, 0.93), past * 0.86);
		vec2 qe = (vec2(uv.x, vy) - 0.5) * 2.0;
		float r = length(qe * vec2(0.82, 1.0));
		float brush = (pp.r - 0.5) * 0.34 + (pp.g - 0.5) * 0.22;
		float inkv = smoothstep(0.70, 1.04, r + brush);
		c = mix(c, vec3(0.055, 0.05, 0.048), inkv * past * 0.94);
	}
	c += (pp.b - 0.5) * (1.5 / 255.0);
	imageStore(dst, g, vec4(to_linear(clamp(c, 0.0, 1.0)) / p.lum, 1.0));
}
"""

func _init() -> void:
	effect_callback_type = EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
	access_resolved_color = true
	rd = RenderingServer.get_rendering_device()

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and rd:
		for r in _tex.values() + _shaders.values() + [_lin, _near, _rep, _paper_tex]:
			if r.is_valid(): rd.free_rid(r)

static func _fmt_name(f: int) -> String:
	match f:
		RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT: return "rgba16f"
		RenderingDevice.DATA_FORMAT_A2B10G10R10_UNORM_PACK32: return "rgb10_a2"
		RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT: return "rgba32f"
		RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM: return "rgba8"
	return "rgba16f"

func _build(fmt: int) -> void:
	_fmt = fmt
	print("POST color format ", fmt, " ", _fmt_name(fmt), " lum_mult=", lum_mult)
	var fname := _fmt_name(fmt)
	var srcs := { blur = BLUR, bright = BRIGHT, final = FINAL, final_ms = "#define DEPTH_MS\n" + FINAL, ao_z = AO_Z, ao_z_ms = "#define DEPTH_MS\n" + AO_Z, ao = AO, ao_blur = AO_BLUR }
	for k in srcs:
		var src := RDShaderSource.new()
		src.language = RenderingDevice.SHADER_LANGUAGE_GLSL
		var body := srcs[k] as String
		var defs := "#define AOVIS\n" if OS.has_environment("AOVIS") and String(k).begins_with("final") else ""
		if body.begins_with("#define"):
			var d0 := body.get_slice("\n", 0) + "\n"; body = body.substr(d0.length()); defs += d0
		src.source_compute = COMMON + defs + body.replace("%FMT%", fname)
		var spirv := rd.shader_compile_spirv_from_source(src)
		if spirv.compile_error_compute != "":
			push_error("post %s: %s" % [k, spirv.compile_error_compute]); return
		_shaders[k] = rd.shader_create_from_spirv(spirv)
		_pipes[k] = rd.compute_pipeline_create(_shaders[k])
	var ss := RDSamplerState.new()
	ss.min_filter = RenderingDevice.SAMPLER_FILTER_LINEAR; ss.mag_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	ss.repeat_u = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE; ss.repeat_v = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	_lin = rd.sampler_create(ss)
	var sn := RDSamplerState.new()   # 깊이: 가까운 점(깊이 형식은 선형 거르기를 못 할 수 있다)
	sn.repeat_u = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE; sn.repeat_v = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	_near = rd.sampler_create(sn)
	ss.repeat_u = RenderingDevice.SAMPLER_REPEAT_MODE_REPEAT; ss.repeat_v = RenderingDevice.SAMPLER_REPEAT_MODE_REPEAT
	_rep = rd.sampler_create(ss)
	if paper_image:
		var img := paper_image.duplicate()
		img.convert(Image.FORMAT_RGBA8)
		var tf := RDTextureFormat.new()
		tf.width = img.get_width(); tf.height = img.get_height()
		tf.format = RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM
		tf.usage_bits = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT
		_paper_tex = rd.texture_create(tf, RDTextureView.new(), [img.get_data()])

func _free_textures() -> void:
	for k in _tex: if _tex[k].is_valid(): rd.free_rid(_tex[k])
	_tex.clear()

func _mk(w: int, h: int, fmt := -1) -> RID:
	var tf := RDTextureFormat.new()
	tf.width = maxi(1, w); tf.height = maxi(1, h)
	tf.format = _fmt if fmt < 0 else fmt
	tf.usage_bits = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_TO_BIT
	return rd.texture_create(tf, RDTextureView.new())

func _ensure(size: Vector2i) -> void:
	if size == _size and not _tex.is_empty(): return
	_free_textures()
	_size = size
	var half := Vector2i(ceili(size.x / 2.0), ceili(size.y / 2.0))
	var quarter := Vector2i(ceili(size.x / 4.0), ceili(size.y / 4.0))
	_tex.ha = _mk(half.x, half.y); _tex.hb = _mk(half.x, half.y)
	_tex.qa = _mk(quarter.x, quarter.y); _tex.qb = _mk(quarter.x, quarter.y)
	_tex.out = _mk(size.x, size.y)
	_tex.ao_z = _mk(half.x, half.y, RenderingDevice.DATA_FORMAT_R32_SFLOAT)
	_tex.ao_a = _mk(half.x, half.y, RenderingDevice.DATA_FORMAT_R16G16_SFLOAT)
	_tex.ao_b = _mk(half.x, half.y, RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT)
	_ao_clear = true

func _samp(binding: int, tex: RID, sampler := RID()) -> RDUniform:
	var u := RDUniform.new()
	u.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	u.binding = binding
	u.add_id(_lin if not sampler.is_valid() else sampler); u.add_id(tex)
	return u

func _img(binding: int, tex: RID) -> RDUniform:
	var u := RDUniform.new()
	u.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	u.binding = binding
	u.add_id(tex)
	return u

func _dispatch(pipe: String, uniforms: Array, push: PackedFloat32Array, size: Vector2i) -> void:
	var set := UniformSetCacheRD.get_cache(_shaders[pipe], 0, uniforms)
	var bytes := push.to_byte_array()
	var cl := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(cl, _pipes[pipe])
	rd.compute_list_bind_uniform_set(cl, set, 0)
	rd.compute_list_set_push_constant(cl, bytes, bytes.size())
	rd.compute_list_dispatch(cl, ceili(size.x / 8.0), ceili(size.y / 8.0), 1)
	rd.compute_list_end()

func _render_callback(_type: int, render_data: RenderData) -> void:
	if state.is_empty(): return
	var sb := render_data.get_render_scene_buffers() as RenderSceneBuffersRD
	if sb == null: return
	var size := sb.get_internal_size()
	if size.x == 0: return
	var color := sb.get_color_layer(0)
	var fmt := rd.texture_get_format(color).format
	if fmt != _fmt:
		_free_textures(); _build(fmt)
	if not _pipes.has("final"): return
	_ensure(size)
	var half := Vector2i(ceili(size.x / 2.0), ceili(size.y / 2.0))
	var quarter := Vector2i(ceili(size.x / 4.0), ceili(size.y / 4.0))
	# 깊이: MSAA면 Mobile이 단일 표본 깊이로 해결하지 않으므로(access_resolved_depth 미지원) MSAA 깊이의 첫 표본을 읽는다
	var ms := sb.get_msaa_3d() != RenderingServer.VIEWPORT_MSAA_DISABLED and sb.has_texture("render_buffers", "depth_msaa")
	var depth := RID()
	if dof: depth = sb.get_texture("render_buffers", "depth_msaa") if ms else sb.get_depth_layer(0)
	depth_ok = depth.is_valid()
	var far_k := dof_far if depth_ok else 0.0
	var near_k := dof_near if depth_ok else 0.0
	if _vis and depth_ok: near_k += 10.0
	var proj := render_data.get_render_scene_data().get_cam_projection()
	if far_k + near_k > 0.001 or (depth_ok and aerial_blur + aerial_haze > 0.001):
		var sigma := size.y * 0.0042
		var st := (sigma / 2.0) * 0.75
		_dispatch("blur", [_samp(0, color), _img(1, _tex.ha)], PackedFloat32Array([st / half.x, 0, 1.0 / half.x, 1.0 / half.y]), half)
		_dispatch("blur", [_samp(0, _tex.ha), _img(1, _tex.hb)], PackedFloat32Array([0, st / half.y, 1.0 / half.x, 1.0 / half.y]), half)
	ao_ok = false
	var ao_depth: RID = sb.get_texture("render_buffers", "depth_msaa") if ms else sb.get_depth_layer(0)
	if ao_strength > 0.001 and ao_depth.is_valid():
		var pr := proj
		_dispatch("ao_z_ms" if ms else "ao_z", [_samp(0, ao_depth, _near), _img(1, _tex.ao_z)], PackedFloat32Array([size.x, size.y, 1.0 / half.x, 1.0 / half.y, pr.z.z, pr.w.z, 0, 0]), half)
		_dispatch("ao", [_samp(0, _tex.ao_z, _near), _img(1, _tex.ao_a)], PackedFloat32Array([half.x, half.y, 1.0 / half.x, 1.0 / half.y,
			pr.x.x, pr.y.y, ao_radius, ao_far, 4.0 if ao_low else 8.0, 0, 0, 0]), half)
		_dispatch("ao_blur", [_samp(0, _tex.ao_a, _near), _img(1, _tex.ao_b)], PackedFloat32Array([1.0 / half.x, 1.0 / half.y, ao_strength, ao_far]), half)
		ao_ok = true; _ao_clear = true
	elif _ao_clear:
		rd.texture_clear(_tex.ao_b, Color(1, 1, 1, 1), 0, 1, 0, 1)
		_ao_clear = false
	var bloom_k: float = state.bloom * 0.45 if bloom else 0.0
	if bloom_k > 0.001:
		_dispatch("bright", [_samp(0, color), _img(1, _tex.qa)], PackedFloat32Array([1.0 / size.x, 1.0 / size.y, 1.0 / quarter.x, 1.0 / quarter.y, state.thr, lum_mult, 0, 0]), quarter)
		_dispatch("blur", [_samp(0, _tex.qa), _img(1, _tex.qb)], PackedFloat32Array([1.5 / quarter.x, 0, 1.0 / quarter.x, 1.0 / quarter.y]), quarter)
		_dispatch("blur", [_samp(0, _tex.qb), _img(1, _tex.qa)], PackedFloat32Array([0, 1.5 / quarter.y, 1.0 / quarter.x, 1.0 / quarter.y]), quarter)
	var ps := 1.0 / (512.0 * maxf(1.0, paper_ratio * 0.75))
	var pf := 1.0 if paper else 0.0
	var lift: Vector3 = state.lift; var gam: Vector3 = state.gamma; var gain: Vector3 = state.gain
	var push := PackedFloat32Array([
		1.0 / size.x, 1.0 / size.y, ps, ps,
		float(size.x) / size.y, dof_focus, proj.z.z, lum_mult,
		proj.w.z, far_k, near_k, bloom_k,
		state.sat, pf, (-maxf(exposure, 0.01) if real else pf), state.night,
		lift.x, lift.y, lift.z, past, gam.x, gam.y, gam.z, dof_margin, gain.x, gain.y, gain.z, dof_far_scale,
		aerial_start, aerial_range, aerial_blur if depth_ok else 0.0, aerial_haze if depth_ok else 0.0])
	var paper_rid: RID = _paper_tex if _paper_tex.is_valid() else _tex.hb
	var depth_rid: RID = depth if depth_ok else _tex.hb   # 깊이가 없으면 아무 판(far_k·near_k = 0이라 읽지 않는다)
	_dispatch("final_ms" if ms and depth_ok else "final", [_samp(0, color), _samp(1, _tex.hb), _samp(2, _tex.qa), _samp(3, paper_rid, _rep), _img(4, _tex.out), _samp(5, depth_rid, _near), _samp(6, _tex.ao_b)], push, size)
	rd.texture_copy(_tex.out, color, Vector3.ZERO, Vector3.ZERO, Vector3(size.x, size.y, 1), 0, 0, 0, 0)
