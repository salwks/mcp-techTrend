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
	FOG = vec4(pbr_fog_color(fog_color, normalize(fog_wp - CAMERA_POSITION_WORLD)), fog_f);
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


# 사실 재질 조각(look_pbr = 1) — fragment 안. 재질 번호는 아틀라스 칸(pbr_ids)에서, 디테일 좌표는 아틀라스 연속 좌표(m)에서 얻는다.
#   아틀라스 64px = 1m(Kit.TILE_M: 128px = 2m). 붓 무늬가 없는 면(white·lamp 칸 — UV가 한 점)은 세계 좌표 주축 투영.
#   시차 매핑(POM): 화면 품질 높음 · 12m 안 · 흙벽·이엉·기와·돌·바위·껍질만. 높이 = 디테일 높이 + 아틀라스 밝기(기와골·창살).
const PBR_CODE := """
		vec3 p_wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
		vec3 p_gn = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
		float p_dist = length(VERTEX);
		bool p_solid = kit_tiling < 0.5 || (v_rect.z <= v_rect.x && length(fwidth(UV)) < 1e-7);
		int mid = M_PLASTER;
		if (kit_tiling > 0.5) {
			vec2 cuv = v_rect.z > v_rect.x ? (v_rect.xy + v_rect.zw) * 0.5 : a_uv;
			mid = clamp(int(texelFetch(pbr_ids, ivec2(clamp(cuv, vec2(0.0), vec2(0.9999)) * vec2(16.0, 8.0)), 0).r * 255.0 + 0.5), 0, 17);
		}
		if (p_solid && %CLOTH%) mid = M_CLOTH;
		float sd = pbr_eave_sd(p_wp);
		if (p_solid && p_gn.y > 0.8 && sd < -0.3 && kit_tiling > 0.5) mid = M_JANGPAN;   // 처마 안 바닥(민 면) = 장판
		float tile_m = MP_TILE[mid];
		// 디테일 좌표(m)
		vec2 mc;
		if (p_solid) {
			vec3 an = abs(p_gn);
			mc = an.y > max(an.x, an.z) ? p_wp.xz : (an.x > an.z ? vec2(p_wp.z, -p_wp.y) : vec2(p_wp.x, -p_wp.y));
		} else {
			mc = a_cont * vec2(16.0, 8.0);
		}
		mat3 TBN = pbr_frame(NORMAL, VERTEX, mc);
		vec2 dmx = dFdx(mc), dmy = dFdy(mc);
		float ar = p_solid ? 0.0 : MP_ARELIEF[mid];
		vec2 rsz = v_rect.zw - v_rect.xy;
		bool rep = kit_tiling > 0.5 && v_rect.z > v_rect.x;
		vec3 cell_avg = textureLod(albedo_tex, a_uv, 6.0).rgb;
		float lavg = max(dot(cell_avg, vec3(0.3, 0.5, 0.2)), 0.02);
		float dep = MP_DEPTH[mid] + abs(ar);
		// 시차 매핑
		if (pbr_q > 0.5 && MP_POM[mid] > 0.5 && !p_solid && p_dist < 12.0) {
			vec3 vt = vec3(dot(VIEW, TBN[0]), dot(VIEW, TBN[1]), dot(VIEW, NORMAL));
			float fadek = 1.0 - smoothstep(7.0, 12.0, p_dist);
			vec2 maxoff = -vt.xy / max(vt.z, 0.25) * dep * fadek;
			const int NS = 10;
			float lh = 1.0, prevh = 1.0, prevs = 1.0; vec2 off = vec2(0.0);
			for (int i = 0; i <= NS; i++) {
				float sl = 1.0 - float(i) / float(NS);
				vec2 m = mc + maxoff * (1.0 - sl);
				float hd = textureGrad(pbr_a, vec3(m / tile_m, float(mid)), dmx / tile_m, dmy / tile_m).a * MP_DEPTH[mid];
				if (ar != 0.0) {
					vec2 ac = m / vec2(16.0, 8.0);
					vec2 au = rep ? v_rect.xy + fract((ac - v_rect.xy) / rsz) * rsz : ac;
					float l = dot(textureGrad(albedo_tex, au, dmx / vec2(16.0, 8.0), dmy / vec2(16.0, 8.0)).rgb, vec3(0.3, 0.5, 0.2)) / lavg;
					float hl = clamp((l - 1.0) * 1.6 + 0.5, 0.0, 1.0);
					hd += (ar > 0.0 ? hl : 1.0 - hl) * abs(ar);
				}
				float hh = hd / dep;
				if (hh >= sl) {
					float a0 = prevh - prevs, a1 = hh - sl;
					float w = a0 / max(a0 - a1, 1e-4);
					off = maxoff * mix(1.0 - prevs, 1.0 - sl, clamp(w, 0.0, 1.0));
					break;
				}
				prevh = hh; prevs = sl; off = maxoff * (1.0 - sl);
			}
			mc += off;
			// 바뀐 자리로 아틀라스 색 다시
			vec2 ac = mc / vec2(16.0, 8.0);
			vec2 au = rep ? v_rect.xy + fract((ac - v_rect.xy) / rsz) * rsz : ac;
			t = textureGrad(albedo_tex, au + uv_offset, dmx / vec2(16.0, 8.0), dmy / vec2(16.0, 8.0));
		}
		vec3 duv = vec3(mc / tile_m, float(mid));
		vec4 tA = textureGrad(pbr_a, duv, dmx / tile_m, dmy / tile_m);
		vec4 tB = textureGrad(pbr_b, duv, dmx / tile_m, dmy / tile_m);
		vec3 a_col = p_solid ? t.rgb : mix(cell_avg, t.rgb, MP_KEEP[mid]);
		vec3 alb = albedo_color.rgb * a_col * COLOR.rgb * (tA.rgb * 2.0);
		float h = tA.a;
		float rough = tB.r;
		float ao = tB.b;
		vec2 sxy = (vec2(tB.a, tB.g) * 2.0 - 1.0);
		sxy /= max(sqrt(max(1.0 - dot(sxy, sxy), 0.0)), 0.2);
		// 아틀라스 밝기 기울기 → 굴곡(기와골·창살·널 이음)
		if (ar != 0.0) {
			float e = 1.5 / 64.0;
			vec2 c0 = mc / vec2(16.0, 8.0);
			vec2 cx = (mc + vec2(e, 0.0)) / vec2(16.0, 8.0), cy = (mc + vec2(0.0, e)) / vec2(16.0, 8.0);
			if (rep) {
				c0 = v_rect.xy + fract((c0 - v_rect.xy) / rsz) * rsz; cx = v_rect.xy + fract((cx - v_rect.xy) / rsz) * rsz; cy = v_rect.xy + fract((cy - v_rect.xy) / rsz) * rsz;
			}
			vec2 g2 = vec2(0.0);
			float l0 = dot(textureGrad(albedo_tex, c0, dmx / vec2(16.0, 8.0), dmy / vec2(16.0, 8.0)).rgb, vec3(0.3, 0.5, 0.2)) / lavg;
			float lx = dot(textureGrad(albedo_tex, cx, dmx / vec2(16.0, 8.0), dmy / vec2(16.0, 8.0)).rgb, vec3(0.3, 0.5, 0.2)) / lavg;
			float ly = dot(textureGrad(albedo_tex, cy, dmx / vec2(16.0, 8.0), dmy / vec2(16.0, 8.0)).rgb, vec3(0.3, 0.5, 0.2)) / lavg;
			float hl0 = clamp((l0 - 1.0) * 1.6 + 0.5, 0.0, 1.0);
			g2 = vec2(clamp((lx - 1.0) * 1.6 + 0.5, 0.0, 1.0) - hl0, clamp((ly - 1.0) * 1.6 + 0.5, 0.0, 1.0) - hl0) / e * ar;
			sxy -= g2 * (1.0 - smoothstep(25.0, 60.0, p_dist));
			float hrel = ar > 0.0 ? hl0 : 1.0 - hl0;
			ao *= mix(1.0, 0.55 + 0.45 * hrel, min(1.0, abs(ar) * 30.0));
			h = mix(h, hrel, 0.6);
		}
		float trans = MP_TRANS[mid];
		float nmix = 1.0;
		float s_cov, puddle;
		pbr_weather(mid, p_wp, p_gn, h, COLOR.a, sd, wet, snow, snow_line, alb, rough, nmix, trans, s_cov, puddle);
		vec3 nt = normalize(vec3(sxy * nmix + (puddle > 0.01 ? pbr_ripple(p_wp.xz, TIME) * puddle * wet : vec2(0.0)), 1.0));
		if (s_cov > 0.0) {
			vec4 sB = texture(pbr_b, vec3(p_wp.xz / MP_TILE[M_SNOW], float(M_SNOW)));
			vec2 sn = sB.ag * 2.0 - 1.0;
			nt = normalize(mix(nt, vec3(sn, 1.0), s_cov));
			ao = mix(ao, 1.0, s_cov * 0.8);
		}
		NORMAL = normalize(TBN * nt);
		ALBEDO = alb;
		ROUGHNESS = clamp(rough, 0.03, 1.0);
		BACKLIGHT = vec3(trans);
		// 하늘빛: 처마 안쪽(실내·툇마루 밑)은 하늘이 적게 보인다 — 지붕(이엉·기와)·나무는 그대로
		bool roofish = mid == M_THATCH || mid == M_TILE || mid == M_FOLIAGE || mid == M_BARK;
		float skyvis = roofish ? 1.0 : mix(1.0, 0.28, smoothstep(0.1, 2.6, -sd));
		vec3 nw = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
		vec3 vw = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
		vec3 irr = pbr_irr(nw, hemi_sky, hemi_ground, fog_color, hemi_i);
		float nv = max(dot(nw, vw), 1e-3);
		vec2 AB = pbr_env_brdf(nv, ROUGHNESS);
		vec3 rw = reflect(-vw, nw);
		vec3 env = mix(pbr_sky(rw, hemi_sky, hemi_ground, fog_color, hemi_i), irr / PI, ROUGHNESS * ROUGHNESS);
		float so = clamp(pow(nv + ao, exp2(-16.0 * ROUGHNESS - 1.0)) - 1.0 + ao, 0.0, 1.0);
		EMISSION = (alb * irr * ao * amb_k / PI + env * (0.04 * AB.x + AB.y) * so) * skyvis
			+ emissive_color * texture(emission_tex, a_uv).rgb * glow_k * use_emission;
"""

# lit: 툰 조명 / unlit: 무광(MeshBasic) / blend: 반투명 / cull: 양면 여부
static func world_shader(lit: bool, blend: bool, double_sided: bool) -> Shader:
	var key := "%s%s%s" % [int(lit), int(blend), int(double_sided)]
	if _shaders.has(key):
		return _shaders[key]
	# 사실 재질(look_pbr)은 light()가 정반사를 직접 더한다 — specular_disabled를 두지 않는다(툰 쪽은 더하지 않으니 예전과 같다)
	var modes := ["cull_disabled" if double_sided else "cull_back"]
	if not lit:
		modes.append("unshaded")
	if blend:
		# 깊이를 기록해야 반투명으로 흐려진 물체 안에서 먼 면(먹선 껍질 안쪽)이 가까운 면을 덮지 않는다
		modes.append("blend_mix")
		modes.append("depth_draw_always")
	var code := "shader_type spatial;\nrender_mode %s;\n" % ", ".join(modes)
	code += GLOBALS
	if Pbr.real: code += "#define LOOK_PBR\n"   # 사실 재질·빛(컴파일 때 고름 — 실행 중 분기는 큰 셰이더에서 1ms 넘게 든다)
	code += "#include \"res://shaders/pbr_common.gdshaderinc\"\n"
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

void vertex() {
	v_rect = CUSTOM0;
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
%INK%%DITHER%
"""
	code = code.replace("%DITHER%", "" if blend else DITHER)
	# 사실 재질에서는 먹선 껍질(먹색 버텍스)을 그리지 않는다
	code = code.replace("%INK%", "" if blend or not Pbr.real else "\tif (distance(COLOR.rgb, vec3(0.0242, 0.0194, 0.0160)) < 0.012) discard;\n")
	if lit:
		code += "#ifdef LOOK_PBR\n\t{\n" + PBR_CODE.replace("%CLOTH%", "true" if double_sided else "false") + "\t}\n#else\n\t{\n" + WEATHER_CODE + """
	vec3 wn = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 hemi = mix(hemi_ground, hemi_sky, 0.5 * wn.y + 0.5) * hemi_i;
	EMISSION = base * hemi / PI + emissive_color * texture(emission_tex, a_uv).rgb * glow_k * use_emission;
	}
#endif
"""
	if blend:
		code += "\tALPHA = albedo_color.a * t.a * fade;\n"
	code += FOG_CODE + "}\n"
	if lit:
		code += """
void light() {
#ifdef LOOK_PBR
	vec3 dl = vec3(0.0), sl = vec3(0.0);
	pbr_direct(NORMAL, LIGHT, VIEW, LIGHT_COLOR, ATTENUATION, ROUGHNESS, BACKLIGHT.r, dl, sl);
	DIFFUSE_LIGHT += dl; SPECULAR_LIGHT += sl;
#else
	float ndl = dot(NORMAL, LIGHT);
	float ramp = texture(ramp_tex, vec2(ndl * 0.5 + 0.5, 0.5)).r;
	DIFFUSE_LIGHT += ramp * ATTENUATION * LIGHT_COLOR / (PI * PI);
#endif
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
	var lit := not code.contains("unshaded")
	var ds := code.contains("cull_disabled")
	var f := ShaderMaterial.new()
	f.shader = world_shader(lit, true, ds)
	for p in ["albedo_color", "albedo_tex", "ramp_tex", "emissive_color", "emission_tex", "use_emission", "uv_offset", "kit_tiling"]:
		var v = sm.get_shader_parameter(p)
		if v != null:
			f.set_shader_parameter(p, v)
	return f
