// 임포스터 굽기 전용(tools/trees_khs/build.gd) — 무광으로 바탕색(보정 + 수관 그늘) 또는 카메라 기준 법선을 그대로 낸다.
//   잎 보정 값은 tree_leaf/tree_bark 재질과 같은 이름(build.gd가 그 재질에서 옮겨 넣는다) — 식은 tree_geo.gdshaderinc와 같게 둔다.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque, shadows_disabled, fog_disabled;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D orm_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float is_leaf = 0.0;
uniform float mode = 0.0;          // 0 바탕색, 1 법선
uniform vec3 leaf_tint : source_color = vec3(0.62, 0.78, 0.72);
uniform float leaf_sat = 0.8;
uniform float leaf_bright = 0.75;
uniform float leaf_var = 0.35;
uniform float leaf_alpha = 0.5;
uniform vec3 bark_low : source_color = vec3(0.62, 0.56, 0.52);
uniform vec3 bark_high : source_color = vec3(0.95, 0.55, 0.38);
uniform vec2 bark_red = vec2(0.32, 0.62);
uniform float bark_bright = 1.0;
uniform float ao_k = 1.0;

varying float v_h;
varying float v_ao;

void vertex() {
	v_h = CUSTOM0.x;
	v_ao = COLOR.r;
}

vec3 to_lin(vec3 c) { return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c)); }

void fragment() {
	vec4 t = texture(albedo_tex, UV);
	vec4 orm = texture(orm_tex, UV);
	vec3 alb;
	if (is_leaf > 0.5) {
		ALPHA = t.a;
		ALPHA_SCISSOR_THRESHOLD = leaf_alpha;
		float l = dot(t.rgb, vec3(0.3, 0.59, 0.11));
		alb = mix(vec3(l), t.rgb, leaf_sat) * leaf_tint * leaf_bright * (1.0 - leaf_var * 0.5 + leaf_var * COLOR.g);
	} else {
		alb = t.rgb * mix(bark_low, bark_high, smoothstep(bark_red.x, bark_red.y, v_h)) * bark_bright;
	}
	float ao = mix(1.0, clamp(v_ao, 0.0, 1.0) * mix(1.0, orm.r, 0.7), ao_k);
	if (mode < 0.5) {
		ALBEDO = alb * ao;
	} else {
		vec3 n = NORMAL;
		if (is_leaf > 0.5 && !FRONT_FACING) n = -n;   // 잎 카드 법선은 수관 바깥쪽 — 뒷면도 같게(tree_geo와 같다)
		ALBEDO = to_lin(vec3(n.xy * 0.5 + 0.5, is_leaf));
	}
}
