// 사실 나무 메시(껍질·잎 카드) 본문 — tree_bark.gdshader(#define TREE_BARK) · tree_leaf.gdshader(#define TREE_LEAF)가 넣는다.
#include "res://shaders/tree_common.gdshaderinc"

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D orm_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
#ifdef TREE_BARK
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float normal_flip_y = 0.0;      // DirectX 법선(초록 뒤집힘)이면 1
uniform float normal_k = 1.0;
uniform vec3 bark_low : source_color = vec3(0.62, 0.56, 0.52);   // 밑동: 회갈색(거북등 껍질)
uniform vec3 bark_high : source_color = vec3(0.95, 0.55, 0.38);  // 위쪽: 붉은 갈색(적송 윗줄기)
uniform vec2 bark_red = vec2(0.32, 0.62);                        // 높이 비 구간에서 붉어진다
uniform float bark_bright = 1.0;
#endif
#ifdef TREE_LEAF
uniform vec3 leaf_tint : source_color = vec3(0.62, 0.78, 0.72);  // 짙은 청록 솔잎(곰솔 잎 사진은 밝고 노랗다)
uniform float leaf_sat = 0.8;
uniform float leaf_bright = 0.75;
uniform float leaf_var = 0.35;          // 카드마다 밝기 차이
uniform float leaf_trans = 0.35;        // 잎 비침
uniform float leaf_alpha = 0.5;
#endif
uniform vec3 lod_cam = vec3(0.0);       // 본 카메라 자리(그림자 패스에서도 같은 LOD를 고르게 — tree_lod.gd가 프레임마다)

varying vec3 v_wp;
varying float v_sin;
varying float v_sout;
varying float v_ao;
varying float v_h;
varying float v_rnd;

void vertex() {
	vec3 O = MODEL_MATRIX[3].xyz;
	float d = distance(O.xz, lod_cam.xz);
	float si, so;
	v_sin = 1.0; v_sout = 0.0;
	if (!tree_band(d, si, so)) {
		VERTEX = vec3(0.0);
	} else {
		v_sin = si; v_sout = so;
		float ph = tree_hash(O.xz);
		mat3 B = mat3(MODEL_MATRIX);
		float s2 = dot(B[0], B[0]);
		vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		vec3 nw = normalize(B * NORMAL);
		vec4 c0 = CUSTOM0;
		c0.x = clamp(VERTEX.y * sqrt(s2) / 18.0, 0.0, 1.3);   // 줄기 흔들림은 실제 높이(m)로 — 18m 나무 꼭대기가 1
		vec3 disp = tree_wind(c0, wp, nw, ph, 18.0, TIME);
		VERTEX += transpose(B) * disp / s2;
		v_wp = wp + disp;
		v_rnd = fract(ph * 7.31 + COLOR.g);
	}
	v_ao = COLOR.r;
	v_h = CUSTOM0.x;
}

void fragment() {
	tree_dither(FRAGCOORD.xy, v_sin, v_sout);
	vec4 t = texture(albedo_tex, UV);
	vec4 orm = texture(orm_tex, UV);
#ifdef TREE_LEAF
	ALPHA = t.a;
	ALPHA_SCISSOR_THRESHOLD = leaf_alpha;
	if (!FRONT_FACING) NORMAL = -NORMAL;   // 카드 법선은 수관 바깥쪽으로 섞어 두었다 — 뒷면도 같은 법선
	float l = dot(t.rgb, vec3(0.3, 0.59, 0.11));
	vec3 alb = mix(vec3(l), t.rgb, leaf_sat) * leaf_tint * leaf_bright * (1.0 - leaf_var * 0.5 + leaf_var * COLOR.g);
	alb *= mix(vec3(1.0), vec3(1.08, 1.0, 0.86), (v_rnd - 0.5) * 0.6);   // 나무마다 조금(누른 잎·푸른 잎)
	float rough = mix(0.82, 0.68, orm.g);   // 잎은 무르게 — 낮은 거칠기는 햇빛에 잎이 하얗게 번쩍인다
	float trans = leaf_trans;
	float spec = 0.25;
#else
	vec3 tint = mix(bark_low, bark_high, smoothstep(bark_red.x, bark_red.y, v_h));
	vec3 alb = t.rgb * tint * bark_bright;
	vec3 nm = texture(normal_tex, UV).xyz;
	if (normal_flip_y > 0.5) nm.y = 1.0 - nm.y;
	NORMAL_MAP = nm;
	NORMAL_MAP_DEPTH = normal_k;
	float rough = clamp(orm.g, 0.55, 1.0);
	float trans = 0.0;
	float spec = 0.3;
#endif
	alb *= 1.0 - 0.3 * wet;
	float ao = clamp(v_ao, 0.0, 1.0) * mix(1.0, orm.r, 0.7);
	ALBEDO = alb;
	ROUGHNESS = rough;
	BACKLIGHT = vec3(trans);
	AO = ao;
	AO_LIGHT_AFFECT = 0.35;
	tree_occ(v_wp, FRAGCOORD.xy);
	EMISSION = tree_ambient(alb, NORMAL, VIEW, INV_VIEW_MATRIX, rough, ao, spec);
#ifdef TREE_LEAF
	EMISSION *= 1.0 + trans * 0.8;   // 잎은 얇아 하늘빛이 겹겹이 비쳐 든다 — 그늘 쪽 수관이 새까매지지 않게
#endif
	vec3 fwp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	TREE_FADE_DISCARD(-VERTEX.z, FRAGCOORD.xy)
	FOG = tree_fog(VERTEX, fwp, CAMERA_POSITION_WORLD);
}

void light() {
	vec3 dl = vec3(0.0), sl = vec3(0.0);
	tree_light(NORMAL, LIGHT, VIEW, LIGHT_COLOR, ATTENUATION, LIGHT_IS_DIRECTIONAL, ROUGHNESS, BACKLIGHT.r, ALBEDO, dl, sl);
	DIFFUSE_LIGHT += dl;
	SPECULAR_LIGHT += sl * 0.35;
}
