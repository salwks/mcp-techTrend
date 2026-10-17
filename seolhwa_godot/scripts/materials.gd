# 재질: 웹의 MeshToonMaterial(붓 바림 단계) + 반구광 + 높이 안개를 셰이더로 옮긴다.
# glTF에서 읽은 StandardMaterial3D를 보고 같은 성질(양면·반투명·무광)의 셰이더 재질로 바꾼다.
#
# 밝기 맞추기: three는 직접광에 BRDF_Lambert(색/π)를 곱한다. Godot의 LIGHT_COLOR는 (색 × 세기 × π)이므로
# DIFFUSE_LIGHT에 LIGHT_COLOR / π² 를 더하면 웹과 같은 세기(intensity) 값을 그대로 쓸 수 있다.
class_name Materials
extends RefCounted

const RAMP := [105, 150, 196, 232, 255] # 툰 명암 단계(웹 materials.js gradient)

static var _shaders := {}
static var _ramp: ImageTexture

static func ramp_texture() -> ImageTexture:
	if _ramp == null:
		var img := Image.create(RAMP.size(), 1, false, Image.FORMAT_R8)
		for i in RAMP.size():
			img.set_pixel(i, 0, Color(RAMP[i] / 255.0, 0, 0))
		_ramp = ImageTexture.create_from_image(img)
	return _ramp

const FOG_CODE := """
	float fog_d = -VERTEX.z;
	vec3 fog_wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float fog_f = 1.0 - exp(-fog_density * fog_density * fog_d * fog_d);
	float fog_mist = fog_density * 24.0 * (1.0 - smoothstep(fog_base - 2.0, fog_base + 7.0, fog_wp.y)) * smoothstep(14.0, 48.0, fog_d);
	fog_f = 1.0 - (1.0 - fog_f) * (1.0 - clamp(fog_mist, 0.0, 0.8));
	FOG = vec4(fog_color, fog_f);
"""

const DITHER := """
	// 가림 점무늬: 카메라(occ_a)→플레이어 머리(occ_b) 선분 둘레 occ_r 안의 면을 점무늬로 비운다(나무·건물이 플레이어를 가릴 때)
	if (occ_r > 0.0 || occ_near > 0.0) {
		vec3 owp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
		float keep = 1.0;
		if (occ_r > 0.0) {
			vec3 ab = occ_b - occ_a;
			float ot = clamp(dot(owp - occ_a, ab) / max(dot(ab, ab), 1e-4), 0.0, 0.92);
			float od = length(owp - (occ_a + ab * ot));
			keep = smoothstep(occ_r * 0.55, occ_r, od);
		}
		// 카메라 바로 앞(큰 나무 잎덩이 등 카메라가 그 안에 들어간 면)도 비운다 — 실내에서도
		if (occ_near > 0.0) {
			float cd = length(owp - occ_a);
			// 먹선 껍질(먹색 버텍스)은 카메라 16m 안에서 그리지 않는다 — 카메라가 잎덩이 안에 들면 껍질 안쪽이 화면을 검게 덮는다
			// occ_near는 거리 배율(1 = 바깥 6~12m). 단면 실내에서는 작게(region_main) — 실내 카메라(10~13m)가 바닥·가구를 비우지 않게
			if (cd < 16.0 * occ_near && distance(COLOR.rgb, vec3(0.0242, 0.0194, 0.0160)) < 0.012) discard;
			keep = min(keep, smoothstep(6.0 * occ_near, 12.0 * occ_near, cd));
		}
		ivec2 q = ivec2(FRAGCOORD.xy) % 4;
		const float BAYER[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
		// 선분 둘레는 30%는 남긴다(형태가 읽히게), 카메라 바로 앞은 모두 비울 수 있다
		if ((BAYER[q.y * 4 + q.x] + 0.5) / 16.0 > keep) discard;
	}"""

# 날씨(권역 — scripts/region/weather.gd가 넣는다. 기본값 wet=0, snow=0, snow_line=1e5 이면 아무 일도 하지 않는다):
# 눈 덮기 = max(snow, 눈선 snow_line 위 높이) × 윗면(법선 y), 젖음 = 어둡게. 마을 장면(--refset)은 기본값 그대로.
# 버텍스 색 알파 = 날씨 받는 정도(기본 1). 실내 바닥·가구는 0(kit/scenario/_sc.gd S.indoor) — 지붕 밑에 눈이 쌓이거나 젖지 않게.
const WEATHER_CODE := """
	if (wet > 0.0 || snow > 0.0 || snow_line < 9e4) {
		vec3 w_wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
		vec3 w_n = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
		float w_sc = max(snow, smoothstep(snow_line, snow_line + 30.0, w_wp.y));
		float w_cov = 0.0;
		if (w_sc > 0.0) {
			float w_nz = 0.5 + 0.25 * sin(w_wp.x * 1.3 + sin(w_wp.z * 0.7)) + 0.25 * sin(w_wp.z * 1.1 + sin(w_wp.x * 0.9));
			w_cov = clamp(w_sc * 1.5 - 0.45 + (w_nz - 0.5) * 0.35, 0.0, 1.0) * smoothstep(0.2, 0.7, w_n.y) * COLOR.a;
		}
		base *= 1.0 - 0.3 * wet * (1.0 - w_cov) * COLOR.a;
		base = mix(base, vec3(0.80, 0.83, 0.88), w_cov);
		ALBEDO = base;
	}
"""

const GLOBALS := """
global uniform vec3 hemi_sky;
global uniform vec3 hemi_ground;
global uniform float hemi_i;
global uniform vec3 fog_color;
global uniform float fog_density;
global uniform float fog_base;
global uniform float glow_k;
global uniform vec3 occ_a;
global uniform vec3 occ_b;
global uniform float occ_r;
global uniform float occ_near;
global uniform float wet;
global uniform float snow;
global uniform float snow_line;
"""

# ---------------------------------------------------------------------------
# 나무(trees-overhaul 2026-10-18): 바람 · 원근 교차 흐림. kit/nature/_tree.gd가 짓는 나무의 껍질(bark_wind)과 잎 카드(foliage)가 쓴다.
# 바람: 물과 같은 전역 water_t(시간)·water_k(0.75 + 1.4×날씨 바람)·water_wind(방향). 세기는 높이²(줄기 휨) + 줄기 축에서 먼 정도×높이(가지)
#   + 잎만 잔떨림. 위상은 나무 뿌리 월드 위치(MODEL_MATRIX[3]) — 나무마다 다르게. 맑은 날 10m 소나무 꼭대기 ≈ 5cm(살짝).
# 원근 교차 흐림(instance uniform lod_mode): 0 없음(배치 나무·덤불) · 1 근경 벌(플레이어 tree_focus에서 tree_lod_band 안쪽 끝부터 점점 사라짐)
#   · 2 원경 판 벌(같은 띠에서 점점 나타남). 두 벌은 같은 4×4 점무늬의 서로 반대 칸을 버려 구멍·겹침 없이 바뀐다.
#   완전히 사라진 쪽은 꼭짓점을 한 점으로 모아 화소를 그리지 않는다.
const TREE_GLOBALS := """
global uniform float water_t;
global uniform float water_k;
global uniform vec2 water_wind;
global uniform vec3 tree_focus;
global uniform vec2 tree_lod_band;
instance uniform float lod_mode = 0.0;
varying flat float v_lod;
"""

const TREE_WIND_FN := """
// TREE_WIND: 모델 공간 꼭짓점 v의 바람 이동(모델 공간). leaf = 잎 잔떨림 배율
vec3 tree_wind(vec3 v, mat4 M, float leaf) {
	vec3 o = M[3].xyz;
	mat3 m3 = mat3(M);
	float s2 = max(dot(m3[0], m3[0]), 1e-4);
	float ph = dot(o.xz, vec2(0.071, 0.093)) * 6.2831;
	float t = water_t;
	float k = clamp(water_k - 0.55, 0.12, 1.8);
	float h = max(v.y, 0.0);
	float r = length(v.xz);
	float gust = 0.55 + 0.45 * sin(t * 0.37 + ph * 0.5) * sin(t * 0.23 + ph);
	float trunk = h * h * 0.0015 * k * (0.55 * sin(t * 0.9 + ph) + 0.45 * gust);
	float br = r * h * 0.008 * k * sin(t * 1.7 + ph + dot(v, vec3(0.6, 0.3, 0.5))) * gust;
	vec3 wd = vec3(water_wind.x, 0.0, water_wind.y);
	vec3 disp = wd * (trunk + br * 0.6) + vec3(0.0, br * 0.35, 0.0);
	disp += leaf * k * 0.06 * gust * vec3(sin(t * 3.1 + v.x * 2.3 + ph), 0.6 * sin(t * 2.7 + v.y * 2.9), sin(t * 3.5 + v.z * 2.1 - ph));
	return transpose(m3) * disp / s2;
}

// 원경 교차: 보이는 정도(1 = 다 보임). lod_mode 0이면 1
float tree_lod_vis(mat4 M) {
	if (lod_mode < 0.5) return 1.0;
	float d = length(M[3].xz - tree_focus.xz);
	float f = clamp((d - tree_lod_band.x) / max(tree_lod_band.y - tree_lod_band.x, 0.01), 0.0, 1.0);
	return lod_mode < 1.5 ? 1.0 - f : f;
}
"""

const TREE_LOD_FRAG := """
	if (lod_mode > 0.5) {
		ivec2 lq = ivec2(FRAGCOORD.xy) % 4;
		const float LB[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
		float lb = (LB[lq.y * 4 + lq.x] + 0.5) / 16.0;
		// 근경 벌(1): 보이는 정도 v → lb < 1-v 칸을 버림 / 원경 벌(2): lb >= v 칸을 버림 — 서로 반대 칸
		if (lod_mode < 1.5 ? (lb < 1.0 - v_lod) : (lb >= v_lod)) discard;
	}
"""

# 잎 카드 셰이더: 알파 자르기(0.5) + MSAA 가장자리, 둥근 법선(메시가 수관 중심에서 바깥으로 넣음)으로 덩이처럼 그늘지고,
# 해를 등진 잎은 빛이 비쳐 노르스름하게(translucency). UV2 ≠ 0인 카드는 카메라를 보는 판(원경 판 — UV2 = 귀퉁이 m).
static var _fol_shader: Shader
static func foliage_shader() -> Shader:
	if _fol_shader != null: return _fol_shader
	var code := "shader_type spatial;\nrender_mode specular_disabled, cull_disabled;\n// TREE_FOLIAGE\n"
	code += GLOBALS + TREE_GLOBALS + """
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_disable, hint_default_white;
uniform sampler2D ramp_tex : filter_linear, repeat_disable;
uniform float fade = 1.0;
uniform float translucency = 0.55;
uniform float wind_amp = 1.0;
""" + TREE_WIND_FN + """
void vertex() {
	v_lod = tree_lod_vis(MODEL_MATRIX);
	if (v_lod <= 0.0) {
		VERTEX = vec3(0.0);
	} else {
		if (UV2.x != 0.0 || UV2.y != 0.0) {
			// 카메라를 보는 판: 카메라 오른쪽·위(월드)를 모델 공간으로
			// 판 가운데에서 카메라 쪽을 본다(카메라 면이 아니라 위치 기준 — 고개를 돌려도 판이 따라 돌지 않는다)
			mat3 m3 = mat3(MODEL_MATRIX);
			float s2 = max(dot(m3[0], m3[0]), 1e-4);
			vec3 cw = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
			vec3 tc = normalize(CAMERA_POSITION_WORLD - cw);
			vec3 rw = normalize(cross(vec3(0.0, 1.0, 0.0), tc) + INV_VIEW_MATRIX[0].xyz * 0.02);
			vec3 uw = cross(tc, rw);
			VERTEX += (transpose(m3) * (rw * UV2.x + uw * UV2.y)) / s2 * sqrt(s2);
		}
		VERTEX += tree_wind(VERTEX, MODEL_MATRIX, 1.0) * wind_amp;
	}
}

void fragment() {
	vec4 t = texture(albedo_tex, UV);
	// 빈 곳은 바로 버린다(그 뒤 계산을 아낌 — 잎 카드 화소의 절반 가까이).
	// MSAA 알파 가장자리(ALPHA_ANTIALIASING_EDGE)는 측정에서 비싸 끔 — 켜 보려면 셰이더 앞에 #define TREE_ALPHA_EDGE, 버림 기준 0.3
	if (t.a < 0.5) discard;
	vec3 base = t.rgb * COLOR.rgb;
	ALBEDO = base;
#ifdef TREE_ALPHA_EDGE
	ALPHA = t.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ALPHA_ANTIALIASING_EDGE = 0.3;
	ALPHA_TEXTURE_COORDINATE = UV * vec2(textureSize(albedo_tex, 0));
#endif
""" + TREE_LOD_FRAG + """
	// 눈앞 1.5m 안 잎 카드는 점무늬로 비운다(1인칭으로 덤불·가지 사이를 지날 때 카드 한 장이 화면을 덮지 않게) + 가림 흐림(fade)
	float fk = min(fade, smoothstep(0.7, 1.6, -VERTEX.z));
	if (fk < 0.999) {
		ivec2 fq = ivec2(FRAGCOORD.xy) % 4;
		const float FB[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
		if ((FB[fq.y * 4 + fq.x] + 0.5) / 16.0 > fk) discard;
	}
""" + DITHER + WEATHER_CODE + """
	vec3 wn = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 hemi = mix(hemi_ground, hemi_sky, 0.5 * wn.y + 0.5) * hemi_i;
	EMISSION = base * hemi / PI;
""" + FOG_CODE + """}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float ramp = texture(ramp_tex, vec2(ndl * 0.5 + 0.5, 0.5)).r;
	DIFFUSE_LIGHT += ramp * ATTENUATION * LIGHT_COLOR / (PI * PI);
	// 해를 등진 잎: 빛이 비친다(잎 사이로 드는 볕)
	float back = pow(clamp(dot(VIEW, -LIGHT), 0.0, 1.0), 3.0) * translucency * clamp(0.5 - ndl * 0.5, 0.0, 1.0);
	DIFFUSE_LIGHT += back * ATTENUATION * LIGHT_COLOR * vec3(1.0, 1.0, 0.62) / (PI * PI);
}
"""
	var sh := Shader.new()
	sh.code = code
	_fol_shader = sh
	return sh

# lit: 툰 조명 / unlit: 무광(MeshBasic) / blend: 반투명 / cull: 양면 여부 / wind: 나무 바람·원근 교차(bark_wind)
static func world_shader(lit: bool, blend: bool, double_sided: bool, wind := false) -> Shader:
	var key := "%s%s%s%s" % [int(lit), int(blend), int(double_sided), "w" if wind else ""]
	if _shaders.has(key):
		return _shaders[key]
	var modes := ["specular_disabled", "cull_disabled" if double_sided else "cull_back"]
	if not lit:
		modes.append("unshaded")
	if blend:
		# 깊이를 기록해야 반투명으로 흐려진 물체 안에서 먼 면(먹선 껍질 안쪽)이 가까운 면을 덮지 않는다
		modes.append("blend_mix")
		modes.append("depth_draw_always")
	var code := "shader_type spatial;\nrender_mode %s;\n" % ", ".join(modes)
	code += GLOBALS
	if wind: code += TREE_GLOBALS
	code += """
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable, hint_default_white;
uniform sampler2D emission_tex : filter_linear_mipmap, repeat_enable, hint_default_black;
uniform sampler2D ramp_tex : filter_linear, repeat_disable;
uniform vec4 albedo_color = vec4(1.0);
uniform vec3 emissive_color = vec3(0.0);
uniform float use_emission = 0.0;
uniform vec2 uv_offset = vec2(0.0);
uniform float fade = 1.0;
// Kit 아틀라스 붓 무늬 반복: CUSTOM0 = 아틀라스 영역(u0, v0, u1, v1), UV = 영역 안 반복 좌표(긴 면은 1을 넘음).
// kit_tiling = 0(glTF 마을 등)이면 예전과 똑같이 UV를 그대로 쓴다.
uniform float kit_tiling = 0.0;
varying vec4 v_rect;
%WINDFN%
void vertex() {
	v_rect = CUSTOM0;
%WINDV%
}

vec2 atlas_uv(vec2 uv, out vec2 cont) {
	cont = uv;
	if (kit_tiling < 0.5 || v_rect.z <= v_rect.x) return uv;
	vec2 sz = v_rect.zw - v_rect.xy;
	cont = v_rect.xy + uv * sz;
	return v_rect.xy + fract(uv) * sz;
}

void fragment() {
	vec2 a_cont;
	vec2 a_uv = atlas_uv(UV, a_cont);
	vec4 t = kit_tiling > 0.5 ? textureGrad(albedo_tex, a_uv + uv_offset, dFdx(a_cont), dFdy(a_cont)) : texture(albedo_tex, UV + uv_offset);
	vec3 base = albedo_color.rgb * t.rgb * COLOR.rgb;
	ALBEDO = base;
%LODF%
%DITHER%
"""
	code = code.replace("%DITHER%", "" if blend else DITHER)
	code = code.replace("%WINDFN%", TREE_WIND_FN if wind else "")
	code = code.replace("%WINDV%", "\tv_lod = tree_lod_vis(MODEL_MATRIX);\n\tif (v_lod <= 0.0) VERTEX = vec3(0.0);\n\telse VERTEX += tree_wind(VERTEX, MODEL_MATRIX, 0.0);" if wind else "")
	code = code.replace("%LODF%", TREE_LOD_FRAG if wind else "")
	if lit:
		code += WEATHER_CODE + """
	vec3 wn = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 hemi = mix(hemi_ground, hemi_sky, 0.5 * wn.y + 0.5) * hemi_i;
	EMISSION = base * hemi / PI + emissive_color * texture(emission_tex, a_uv).rgb * glow_k * use_emission;
"""
	if blend:
		code += "\tALPHA = albedo_color.a * t.a * fade;\n"
	code += FOG_CODE + "}\n"
	if lit:
		code += """
void light() {
	float ndl = dot(NORMAL, LIGHT);
	float ramp = texture(ramp_tex, vec2(ndl * 0.5 + 0.5, 0.5)).r;
	DIFFUSE_LIGHT += ramp * ATTENUATION * LIGHT_COLOR / (PI * PI);
}
"""
	var sh := Shader.new()
	sh.code = code
	_shaders[key] = sh
	return sh

# glTF 재질 → 셰이더 재질
static func from_standard(m: BaseMaterial3D, glow: bool) -> ShaderMaterial:
	var lit := m.shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED
	var blend := m.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED
	var ds := m.cull_mode == BaseMaterial3D.CULL_DISABLED
	var sm := ShaderMaterial.new()
	sm.shader = world_shader(lit, blend, ds)
	var c := m.albedo_color
	var lin := c.srgb_to_linear()
	sm.set_shader_parameter("albedo_color", Vector4(lin.r, lin.g, lin.b, c.a))
	if m.albedo_texture:
		sm.set_shader_parameter("albedo_tex", m.albedo_texture)
	sm.set_shader_parameter("ramp_tex", ramp_texture())
	if glow and m.emission_texture:
		var e := m.emission.srgb_to_linear()
		sm.set_shader_parameter("emissive_color", Vector3(e.r, e.g, e.b))
		sm.set_shader_parameter("emission_tex", m.emission_texture)
		sm.set_shader_parameter("use_emission", 1.0)
	return sm

# 가림 처리용: 같은 재질을 반투명 셰이더로
static func faded_copy(sm: ShaderMaterial) -> ShaderMaterial:
	var code := sm.shader.code
	# 잎 카드: 반투명 대신 같은 셰이더의 점무늬 흐림(fade) — 복제만
	if code.contains("// TREE_FOLIAGE"): return sm.duplicate() as ShaderMaterial
	var lit := not code.contains("unshaded")
	var ds := code.contains("cull_disabled")
	var f := ShaderMaterial.new()
	f.shader = world_shader(lit, true, ds, code.contains("TREE_WIND"))
	for p in ["albedo_color", "albedo_tex", "ramp_tex", "emissive_color", "emission_tex", "use_emission", "uv_offset", "kit_tiling"]:
		var v = sm.get_shader_parameter(p)
		if v != null:
			f.set_shader_parameter(p, v)
	return f
