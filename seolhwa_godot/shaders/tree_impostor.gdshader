// 사실 나무 임포스터(trees-khs) — 사각 하나가 카메라를 보고 서며, 8방향 아틀라스(45°마다)에서 보는 방향의 두 칸을 골라 섞는다.
//   아틀라스: tools/trees_khs/build.gd가 다듬은 LOD0 메시를 직교로 구운 것. 칸 i = 방위 i×45°(로컬 +Z가 0, +X가 90°), 4×2 칸(위 줄 0~3).
//   alb: 보정된 바탕색(수관 그늘 포함) + 알파,  nrm: 구운 카메라 기준 법선 xy(0~1) · b 잎(1)/껍질(0) · a 알파
//   인스턴스 사용자 자료 r = 층(변형 번호), g = 색 난수. 사각 메시: x -0.5~0.5, y 0~1(kit/nature/khs_trees.gd impostor_mesh)
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;
#include "res://shaders/tree_common.gdshaderinc"

uniform sampler2DArray imp_alb : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2DArray imp_nrm : filter_linear_mipmap, repeat_disable;
uniform vec4 imp_box[16];          // 층마다 (중심 x, 중심 z, 폭, 높이) — 로컬 m
uniform float leaf_trans = 0.35;
uniform float imp_alpha = 0.5;
uniform float imp_tilt = 0.45;      // 카메라 높이각의 이만큼 사각을 카메라 쪽으로 눕힌다(내려다볼 때 나무가 납작해지지 않게)
uniform vec3 lod_cam = vec3(0.0);
uniform vec2 imp_fade = vec2(450.0, 545.0);   // 먼 끝 점무늬 녹임(region_world가 임포스터 거리에 맞춰 넣는다 — 땅의 수관 빛이 이어 받는다)

varying flat vec4 v_view;    // i0, i1, t, 층
varying vec3 v_wp;
varying float v_sin;
varying float v_sout;
varying float v_rnd;

vec3 view_dir(float i) {
	float a = i * PI * 0.25;
	return vec3(sin(a), 0.0, cos(a));
}

void vertex() {
	vec3 O = MODEL_MATRIX[3].xyz;
	float d = distance(O.xz, lod_cam.xz);
	float si, so;
	v_sin = 1.0; v_sout = 0.0;
	int L = int(INSTANCE_CUSTOM.r + 0.5);
	vec4 box = imp_box[clamp(L, 0, 15)];
	if (!tree_band(d, si, so)) {
		VERTEX = vec3(0.0);
		v_view = vec4(0.0);
	} else {
		v_sin = si; v_sout = so;
		mat3 B = mat3(MODEL_MATRIX);
		float s2 = dot(B[0], B[0]);
		vec3 toc = transpose(B) * (CAMERA_POSITION_WORLD - O) / s2;   // 로컬(배율 뺌) 카메라 쪽
		vec3 hd = normalize(vec3(toc.x, 0.0, toc.z) + vec3(1e-5, 0.0, 0.0));
		float az = atan(hd.x, hd.z);
		float f = mod(az / (PI * 0.25) + 8.0, 8.0);
		float i0 = floor(f);
		v_view = vec4(i0, mod(i0 + 1.0, 8.0), f - i0, float(L));
		float el = atan(toc.y, length(toc.xz));
		float tl = clamp(el, 0.0, 1.2) * imp_tilt;
		vec3 R = vec3(hd.z, 0.0, -hd.x);
		vec3 U = vec3(0.0, cos(tl), 0.0) + hd * sin(tl);
		vec3 c = vec3(box.x, 0.0, box.y);
		VERTEX = c + R * (VERTEX.x * box.z) + U * (VERTEX.y * box.w);
		NORMAL = hd;
		v_wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	}
	v_rnd = INSTANCE_CUSTOM.g;
}

vec2 cell_uv(float i, vec2 uv) {
	return vec2((mod(i, 4.0) + uv.x) * 0.25, (floor(i / 4.0) + uv.y) * 0.5);
}

void fragment() {
	tree_dither(FRAGCOORD.xy, v_sin, v_sout);
	vec2 uv = vec2(UV.x, UV.y);
	float L = v_view.w;
	vec4 a0 = texture(imp_alb, vec3(cell_uv(v_view.x, uv), L));
	vec4 a1 = texture(imp_alb, vec3(cell_uv(v_view.y, uv), L));
	vec4 n0 = texture(imp_nrm, vec3(cell_uv(v_view.x, uv), L));
	vec4 n1 = texture(imp_nrm, vec3(cell_uv(v_view.y, uv), L));
	float t = v_view.z;
	// 알파: 두 칸을 그대로 섞으면 가운데에서 성겨진다 — 섞은 뒤 문턱을 조금 낮춘다
	float al = mix(a0.a, a1.a, t);
	ALPHA = al;
	ALPHA_SCISSOR_THRESHOLD = imp_alpha - 0.12 * (1.0 - abs(t - 0.5) * 2.0);
	vec3 alb = mix(a0.rgb, a1.rgb, t);
	alb *= mix(vec3(1.0), vec3(1.08, 1.0, 0.86), (v_rnd - 0.5) * 0.6);
	// 법선: 칸마다 구운 카메라 틀(오른쪽·위·카메라 쪽)로 로컬 법선을 되살려 섞는다
	vec3 n_loc = vec3(0.0);
	for (int k = 0; k < 2; k++) {
		float i = k == 0 ? v_view.x : v_view.y;
		vec4 nn = k == 0 ? n0 : n1;
		vec2 xy = nn.rg * 2.0 - 1.0;
		float z = sqrt(max(1.0 - dot(xy, xy), 0.0));
		vec3 d = view_dir(i);
		vec3 r = vec3(d.z, 0.0, -d.x);
		n_loc += (r * xy.x + vec3(0.0, 1.0, 0.0) * xy.y + d * z) * (k == 0 ? 1.0 - t : t);
	}
	mat3 B = mat3(MODEL_MATRIX);
	vec3 nw = normalize(B * n_loc);
	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
	float leaf = mix(n0.b, n1.b, t);
	alb *= 1.0 - 0.3 * wet;
	ALBEDO = alb;
	ROUGHNESS = mix(0.85, 0.75, leaf);
	BACKLIGHT = vec3(leaf_trans * leaf);
	tree_occ(v_wp, FRAGCOORD.xy);
	EMISSION = tree_ambient(alb, NORMAL, VIEW, INV_VIEW_MATRIX, ROUGHNESS, 1.0, 0.4) * (1.0 + leaf_trans * leaf * 0.8);
	vec3 fwp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	if (-VERTEX.z > imp_fade.x && fract(sin(dot(floor(FRAGCOORD.xy), vec2(12.9898, 78.233))) * 43758.5453) < smoothstep(imp_fade.x, imp_fade.y, -VERTEX.z)) discard;
	FOG = tree_fog(VERTEX, fwp, CAMERA_POSITION_WORLD);
}

void light() {
	vec3 dl = vec3(0.0), sl = vec3(0.0);
	tree_light(NORMAL, LIGHT, VIEW, LIGHT_COLOR, ATTENUATION, LIGHT_IS_DIRECTIONAL, ROUGHNESS, BACKLIGHT.r, ALBEDO, dl, sl);
	DIFFUSE_LIGHT += dl;
	SPECULAR_LIGHT += sl * 0.3;
}
