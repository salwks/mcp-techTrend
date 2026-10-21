// 사실 땅(material-lighting 2차) — region_terrain.gdshader fragment() 안 LOOK_PBR 조각(그 함수의 지역 변수를 그대로 쓴다).
//   1차는 붓 그림 땅색(토지이용 색 얼룩·길섶 띠) × 잔무늬 배율이라, 3인칭 거리에서는 큰 민 색 얼룩 + 뿌린 점으로만 읽혔다.
//   2차: 층마다 실제 바탕색(흙 마당·다진 길·풀·바위) × 굽은 디테일 — 붓 그림 색은 지역 빛깔(숲은 짙게 등)로만 45% 남긴다.
//   - 풀 ↔ 흙: 공용 풀 마스크(ground_mask.gdshaderinc — 풀잎 셰이더와 같은 식) + 높이 섞기(풀 포기 높이 vs 흙 높이) → 들쭉날쭉한 경계
//   - 되풀이 지우기: 같은 흙 층을 4.3배 크게 돌려 한 번 더 곱한다 + 큰 잡음 밝기
//   - 큰 굴곡(m): 길 수레바퀴 자국·가운데 다져진 등·마당 패인 데 → 화면 미분으로 법선, 비 오면 여기부터 고인다
//   - 처마 밑 하늘빛 가림 · 기단 둘레 흙 그늘 · 낙숫물 줄 · 우물가 진흙(1차 붓 꾸밈 town_layer 대신)
		float g_dist = length(VERTEX);
		float g_dfar = 1.0 - smoothstep(70.0, 120.0, g_dist);   // 디테일 텍스처 거리(너머는 층 평균색 + 큰 무늬)
		vec2 g_gx = dFdx(p), g_gy = dFdy(p);
		vec2 g_uvh = ((p - h_meta.xy) * h_meta.z + 0.5) / vec2(h_size);
		vec4 g_dv = dress_on > 0.0 ? texture(dress_tex, g_uvh) : vec4(1.0, 0.0, 1.0, 0.0);
		float g_sd = dress_on > 0.0 ? (g_dv.r * 255.0 - 128.0) / 16.0 : 9.0;
		float g_wd = g_dv.b * 255.0 / 16.0;
		float g_pav = g_dv.a * 255.0;
		float pav_k = g_pav > 0.5 ? smoothstep(0.0, 0.25, (g_pav - 1.0) / 32.0 - 1.0) : 0.0;
		float rock_k = smoothstep(0.75, 1.15, slope);
		float road_k = (rd < rhw + 3.0) ? 1.0 - smoothstep(-0.2, 0.2, rd - rhw + pn * 0.45) : 0.0;
		float g_n = gm_noise(p);
		float gw = gm_grass(p, slope, pt, g_dv, g_n) * (1.0 - water);
		// ---- 층 읽기 ----
		int soil_l = road_k > 0.5 ? M_PATH : M_DIRT;
		float tl = MP_TILE[soil_l];
		vec4 sA = vec4(0.5, 0.5, 0.5, 0.45), sB = vec4(0.95, 0.5, 1.0, 0.5), mA = vec4(0.5);
		vec4 gA = vec4(0.5, 0.5, 0.5, 0.5), gB = vec4(0.9, 0.5, 1.0, 0.5);
		vec4 rA = vec4(0.5), rB = vec4(0.85, 0.5, 1.0, 0.5);
		bool g_near = g_dist < 45.0 && pbr_q > 0.5;
		if (g_dfar > 0.0) {
			sA = textureGrad(pbr_a, vec3(p / tl, float(soil_l)), g_gx / tl, g_gy / tl);
			if (g_near) sB = textureGrad(pbr_b, vec3(p / tl, float(soil_l)), g_gx / tl, g_gy / tl);
			if (gw > 0.003) {
				float tg = MP_TILE[M_GRASS];
				gA = textureGrad(pbr_a, vec3(p / tg, float(M_GRASS)), g_gx / tg, g_gy / tg);
				if (g_near) gB = textureGrad(pbr_b, vec3(p / tg, float(M_GRASS)), g_gx / tg, g_gy / tg);
			}
			float rk = max(rock_k, pav_k);
			if (rk > 0.02) {
				int rl = pav_k > rock_k ? M_PAVING : M_ROCK;
				float tr = MP_TILE[rl];
				rA = textureGrad(pbr_a, vec3(p / tr, float(rl)), g_gx / tr, g_gy / tr);
				if (g_near) rB = textureGrad(pbr_b, vec3(p / tr, float(rl)), g_gx / tr, g_gy / tr);
			}
		}
		// 되풀이 지우기: 같은 흙 층을 크게(4.3배) 돌려서
		{
			vec2 pm = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * p / (tl * 4.3);
			mA = textureGrad(pbr_a, vec3(pm, float(soil_l)), g_gx / (tl * 4.3), g_gy / (tl * 4.3));
		}
		// ---- 풀 ↔ 흙: 마스크 + 높이 섞기 ----
		float gcov = gw > 0.003 ? smoothstep(0.3, 0.68, gw + (gA.a - sA.a) * 0.45 * g_dfar) : 0.0;
		// ---- 바탕색(선형) ----
		// 층 기준색(sRGB → 선형): 흙 마당 #73634f 남짓 · 다진 길 #8c7d66 · 풀 #57692f · 바위 #78736b. 붓 그림 땅색 비율(지역 빛깔)을 45% 곱한다
		vec3 colL = srgb(col);
		vec3 C_DIRT_L = vec3(0.172, 0.126, 0.076), C_PATHL = vec3(0.262, 0.204, 0.133), C_GRASSL = vec3(0.093, 0.141, 0.028), C_ROCKL = vec3(0.19, 0.172, 0.148);
		vec3 tint_s = clamp(colL / vec3(0.555, 0.420, 0.205), vec3(0.45), vec3(1.7));
		tint_s = mix(vec3(dot(tint_s, vec3(0.3, 0.5, 0.2))), tint_s, 0.45);   // 붓 땅색의 주황기는 덜고 밝기만
		vec3 tint_g = clamp(colL / vec3(0.344, 0.389, 0.148), vec3(0.4), vec3(1.8));
		float mac = (n1 * 0.5) * 0.18 + (texture(noise_tex, p * 0.061 + vec2(0.2, 0.9)).r - 0.5) * 0.22;   // 큰 얼룩 밝기(10~50m)
		vec3 soilc = (road_k > 0.5 ? C_PATHL : C_DIRT_L) * mix(vec3(1.0), tint_s, 0.45);
		vec3 mmul = mix(vec3(1.0), mA.rgb * 2.0, 0.7);
		vec3 a_soil = soilc * pow(sA.rgb * 2.0, vec3(1.35)) * mmul * (1.0 + mac);
		// 풀: 마른 풀 얼룩(큰 잡음) · 포기 사이 흙빛은 굽은 텍스처가 맡는다
		float dryg = smoothstep(0.45, 0.75, texture(noise_tex, p * 0.045 + vec2(0.6, 0.1)).r) * 0.6;
		vec3 grassc = mix(C_GRASSL, vec3(0.20, 0.17, 0.07), dryg) * mix(vec3(1.0), tint_g, 0.45);
		vec3 a_grass = grassc * pow(gA.rgb * 2.0, vec3(1.2)) * (1.0 + mac * 0.8);
		vec3 a_rock = (pav_k > rock_k ? vec3(0.325, 0.30, 0.247) : C_ROCKL * mix(vec3(1.0), clamp(colL / vec3(0.27, 0.24, 0.19), vec3(0.5), vec3(1.6)), 0.4)) * pow(rA.rgb * 2.0, vec3(1.3));
		vec3 alb = mix(a_soil, a_grass, gcov);
		float rk2 = max(rock_k, pav_k);
		alb = mix(alb, a_rock, rk2);
		float dh = mix(mix(sA.a, gA.a, gcov), rA.a, rk2);
		float dr = mix(mix(sB.r, gB.r, gcov), rB.r, rk2);
		float dao = mix(mix(sB.b, gB.b, gcov), rB.b, rk2);
		vec2 dsl = mix(mix(sB.ag * 2.0 - 1.0, (gB.ag * 2.0 - 1.0) * 1.3, gcov), rB.ag * 2.0 - 1.0, rk2) * 1.7;   // 법선 세기 ×1.7(3인칭 거리에서 읽히게)
		// ---- 큰 굴곡(m) ----
		float hm = 0.0;
		if (road_k > 0.0) {
			float g_al = texture(noise_tex, p * 0.13 + vec2(0.5, 0.5)).r;
			float wheel = (1.0 - smoothstep(0.08, 0.3, abs(rd - 0.75))) * step(1.25, rhw) * (0.55 + 0.6 * g_al);
			float foot = (1.0 - smoothstep(0.1, 0.45, rd)) * (1.0 - step(1.25, rhw));
			float edge = smoothstep(rhw * 0.6, rhw, rd);
			hm += road_k * (-0.06 * wheel - 0.025 * foot + 0.03 * edge * (g_al - 0.3));
			alb *= 1.0 - road_k * (0.16 * wheel + 0.1 * foot);                    // 자국은 짙고
			alb *= 1.0 + road_k * 0.1 * (1.0 - smoothstep(0.0, rhw * 0.5, rd)) * (1.0 - wheel);   // 다져진 가운데는 밝다
			dr = mix(dr, dr * 0.85, road_k * (1.0 - edge));
		}
		float dip = texture(noise_tex, p * 0.17 + vec2(0.7, 0.2)).r;
		hm += (dip - 0.5) * 0.07 * (1.0 - gcov) * (1.0 - rk2);
		hm += (g_n - 0.5) * 0.05 * gcov;
		{
			vec2 dhs = vec2(dFdx(hm), dFdy(hm));
			float det = g_gx.x * g_gy.y - g_gx.y * g_gy.x;
			vec2 grad = abs(det) > 1e-12 ? vec2(g_gy.y * dhs.x - g_gx.y * dhs.y, -g_gy.x * dhs.x + g_gx.x * dhs.y) / det : vec2(0.0);
			dsl -= clamp(grad, vec2(-0.6), vec2(0.6)) * (1.0 - smoothstep(30.0, 60.0, g_dist));
		}
		dsl *= g_dfar;
		dao = mix(1.0, dao, g_dfar);
		// ---- 처마 밑 · 기단 둘레 · 낙숫물 줄 ----
		float skyvis = mix(1.0, 0.38, smoothstep(-0.2, 1.8, -g_sd));
		float g_contact = 1.0 - 0.35 * (1.0 - smoothstep(-1.3, -0.2, g_sd)) * smoothstep(-2.5, -1.3, g_sd);   // 기단 바로 밑 흙 그늘(벽발치)
		float drip = (1.0 - smoothstep(0.06, 0.26, abs(g_sd - 0.28 + (g_n - 0.5) * 0.15))) * (1.0 - rk2);
		alb *= 1.0 - 0.18 * drip;
		dao *= g_contact;
		hm -= 0.03 * drip;
		// ---- 우물·빨래터 진흙 · 냇가 젖은 테 ----
		if (g_wd < 6.0) {
			float wn2 = texture(noise_tex, p * 0.21 + vec2(0.4, 0.1)).r;
			float mud = (1.0 - smoothstep(1.5, 5.5, g_wd + (wn2 - 0.5) * 2.5)) * (1.0 - pav_k * 0.7);
			alb = mix(alb, alb * vec3(0.55, 0.5, 0.46), mud * 0.75);
			dr = mix(dr, 0.45, mud * 0.6);
			water = max(water, smoothstep(0.62, 0.72, wn2 + (1.0 - smoothstep(1.0, 3.5, g_wd)) * 0.35) * mud * 0.75);
		}
		if (bankw0 > 0.02 && bankw0 < 0.98) {
			float bk = smoothstep(0.02, 0.3, bankw0) * (1.0 - smoothstep(0.75, 0.98, bankw0));
			alb *= 1.0 - 0.3 * bk;
			dr = mix(dr, 0.55, bk * 0.5);
		}
		float rough = mix(0.93, dr, g_dfar);
		// ---- 젖음: 흙은 짙고 반들, 낮은 데(높이 + 큰 굴곡 — 수레바퀴 자국·패인 데)부터 고인다 ----
		if (wet > 0.0) {
			float wk = wet * (1.0 - t_cov);
			rough = mix(rough, mix(rough, 0.38, 0.85 - 0.5 * gcov), wk);
			alb *= 1.0 - 0.38 * wk * (1.0 - gcov * 0.55);
			float flat_k = smoothstep(0.88, 0.97, v_wn.y);
			float hh = dh * 0.5 + clamp(hm / 0.12 + 0.5, 0.0, 1.0) * 0.5;
			float level = 0.12 + 0.24 * wet + 0.06 * road_k;
			float pud = (1.0 - smoothstep(level - 0.06, level, hh)) * flat_k * wk * (1.0 - gcov * 0.85) * (1.0 - rk2 * 0.5);
			water = max(water, pud * 0.8);
			alb *= 1.0 - 0.35 * pud;
			rough = mix(rough, 0.03, max(pud, smoothstep(0.25, 0.5, water)));
			dsl *= 1.0 - max(pud, water);
			if (pud > 0.01) dsl += pbr_ripple(p, TIME) * pud * wet;
		}
		alb = mix(alb, alb * vec3(0.5, 0.58, 0.58), water);
		// ---- 눈 ----
		vec3 tn_ = vec3(dsl * (1.0 - t_cov * 0.7), 1.0);
		if (t_cov > 0.0) {
			vec4 sbn = texture(pbr_b, vec3(p / MP_TILE[M_SNOW], float(M_SNOW)));
			vec3 gt = texture(ground_tex, p / 7.0).rgb;
			alb = mix(alb, vec3(0.80, 0.83, 0.88) * (0.9 + 0.1 * n2) * mix(vec3(1.0), gt / max(dot(gt, vec3(0.333)), 0.05), 0.25), t_cov);
			tn_.xy = mix(tn_.xy, (sbn.ag * 2.0 - 1.0), t_cov);
			rough = mix(rough, 0.82, t_cov);
			dao = mix(dao, 1.0, t_cov);
		}
		vec3 N0 = normalize(v_wn);
		vec3 Tw = normalize(vec3(1.0, 0.0, 0.0) - N0 * N0.x), Bw = normalize(vec3(0.0, 0.0, 1.0) - N0 * N0.z);
		vec3 nw = normalize(Tw * tn_.x + Bw * tn_.y + N0 * tn_.z);
		NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
		ALBEDO = alb;
		ROUGHNESS = clamp(rough, 0.03, 1.0);
		BACKLIGHT = vec3(0.12 * gcov + 0.18 * t_cov);
		vec3 irr = pbr_irr(nw, hemi_sky, hemi_ground, fog_color, hemi_i);
		vec3 vw = vdir;
		float nv = max(dot(nw, vw), 1e-3);
		vec2 AB = pbr_env_brdf(nv, ROUGHNESS);
		vec3 env = mix(pbr_sky(reflect(-vw, nw), hemi_sky, hemi_ground, fog_color, hemi_i), irr / PI, ROUGHNESS * ROUGHNESS);
		EMISSION = (alb * irr * dao * amb_k / PI + env * (0.04 * AB.x + AB.y) * dao) * skyvis;
