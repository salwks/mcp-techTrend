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
		// 산 지형 토지이용 마스크(integ-mountain): 바위(7)·자갈 모래 너덜(8)·하상(5) — 칸 경계는 풀 잡음으로 흔든다
		float g_l7 = mix(mix(float(ca == 7), float(cb == 7), t.x), mix(float(cc == 7), float(cd == 7), t.x), t.y);
		float g_l8 = mix(mix(float(ca == 8), float(cb == 8), t.x), mix(float(cc == 8), float(cd == 8), t.x), t.y);
		float g_n0 = texture(noise_tex, p * 0.21 + vec2(0.31, 0.77)).r;
		float scree_k = smoothstep(0.3, 0.7, g_l8 + (g_n0 - 0.5) * 0.5);
		float bed_k = smoothstep(0.3, 0.7, bankw0 + (g_n0 - 0.5) * 0.4);
		// 산 지형 권역(aer_k): 세로 2배라 45° 넘는 비탈이 흔하다 — 바위는 아주 가파른 데(≈55°↑)와 큰 얼룩(노두)만, 나머지 바위 칸은 숲 바닥·마사토
		float g_big = texture(noise_tex, p * 0.0117 + vec2(0.71, 0.29)).r;
		float rock_sl = mix(smoothstep(0.75, 1.15, slope), smoothstep(1.35, 1.85, slope + (g_n0 - 0.5) * 0.3), aer_k);
		float rock_lu = smoothstep(0.3, 0.7, g_l7 + (g_n0 - 0.5) * 0.5) * mix(1.0, max(smoothstep(1.15, 1.6, slope), smoothstep(0.5, 0.66, g_big)), aer_k);
		float rock_k = max(rock_sl, rock_lu);
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
			float rk = scan_on > 0.5 ? pav_k : max(rock_k, pav_k);   // 스캔 층이 있으면 바위는 아래에서 화강암 스캔으로
			if (rk > 0.02) {
				int rl = pav_k > rock_k ? M_PAVING : M_ROCK;
				float tr = MP_TILE[rl];
				rA = textureGrad(pbr_a, vec3(p / tr, float(rl)), g_gx / tr, g_gy / tr);
				if (g_near) rB = textureGrad(pbr_b, vec3(p / tr, float(rl)), g_gx / tr, g_gy / tr);
			}
		}
		// 자갈·너덜·하상 돌: 자연석 층을 작게(0.7m) — 높이(a)가 높은 데가 돌, 낮은 데는 모래·물때
		vec4 qA = vec4(0.5, 0.5, 0.5, 0.4), qB = vec4(0.6, 0.5, 1.0, 0.5);
		if (g_dfar > 0.0 && scree_k + bed_k > 0.02 && scan_on < 0.5) {
			float tq = 0.7;
			vec2 pq = mat2(vec2(0.6, -0.8), vec2(0.8, 0.6)) * p / tq;
			qA = textureGrad(pbr_a, vec3(pq, float(M_ROCK)), g_gx / tq, g_gy / tq);
			if (g_near) qB = textureGrad(pbr_b, vec3(pq, float(M_ROCK)), g_gx / tq, g_gy / tq);
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
		// 자갈·모래 기슭 / 너덜: 모래 바탕에 둥근 돌 · 하상: 물때 낀 돌(짙고 푸르스름 — 물이 반투명이라 비친다)
		float pebble = smoothstep(0.42, 0.58, qA.a + (g_n0 - 0.5) * 0.3);
		vec3 sandL = vec3(0.30, 0.26, 0.20), stoneL = vec3(0.26, 0.25, 0.23) * (0.8 + 0.4 * texture(noise_tex, p * 0.9).r);
		vec3 a_scree = mix(sandL * (qA.rgb * 2.0), stoneL * pow(qA.rgb * 2.0, vec3(1.3)), pebble);
		vec3 a_bed = mix(vec3(0.10, 0.095, 0.075), vec3(0.16, 0.16, 0.14) * pow(qA.rgb * 2.0, vec3(1.2)), pebble);
		alb = mix(alb, a_scree, scree_k * (1.0 - bed_k));
		alb = mix(alb, a_bed, bed_k);
		float qk = max(scree_k, bed_k);
		float rk2 = max(rock_k, pav_k);
		alb = mix(alb, a_rock, rk2);
		float dh = mix(mix(mix(sA.a, gA.a, gcov), qA.a, qk), rA.a, rk2);
		float dr = mix(mix(mix(sB.r, gB.r, gcov), mix(qB.r, 0.3, bed_k), qk), rB.r, rk2);
		float dao = mix(mix(mix(sB.b, gB.b, gcov), qB.b, qk), rB.b, rk2);
		vec2 dsl = mix(mix(mix(sB.ag * 2.0 - 1.0, (gB.ag * 2.0 - 1.0) * 1.3, gcov), (qB.ag * 2.0 - 1.0) * 1.4, qk), (rB.ag * 2.0 - 1.0) * 1.5, rk2) * 1.7;   // 법선 세기 ×1.7(3인칭 거리에서 읽히게) · 바위 결은 더 세게
		// ---- 사진 스캔 층(integ-mountain — shaders/pbr_scan.gdshaderinc, CC0): 숲 바닥·낙엽 · 다진 산길 흙 · 마사토(절개면·가파른 비탈·너덜) · 냇돌 · 화강암(이끼) ----
		//   한국 산은 거의 숲: 짙은 부엽토·낙엽·이끼 + 숲 틈·능선만 풀 + 드러난 땅은 좁은 데(길 절개면·사태)만 회갈색 화강암·붉은 갈색 마사토
		float rock_scan = 0.0;
		vec3 rock_nw = v_wn;
		if (scan_on > 0.5) {
			float fo = mix(mix(float(ca == 0 || ca == 9), float(cb == 0 || cb == 9), t.x), mix(float(cc == 0 || cc == 9), float(cd == 0 || cd == 9), t.x), t.y);
			float hi = smoothstep(34.0, 64.0, v_wp.y) * aer_k * (1.0 - urban_ground);   // 산 지형 권역의 고을 바닥(y≤30) 위
			float fz = max(fo, hi);
			float cls = pt.a * 255.0 / 60.0;
			float trail_k = road_k * fz * (1.0 - 0.55 * step(2.5, cls));                       // 숲·산 길(대로는 반쯤 — 바퀴 길은 밝게 다져짐)
			float near_rd = 1.0 - smoothstep(rhw + 2.0, rhw + 10.0, rd);
			float cut = smoothstep(0.75, 1.05, slope) * (1.0 - smoothstep(rhw + 1.0, rhw + 5.0, rd)) * (1.0 - road_k);   // 길 절개면(길 바로 곁 가파른 데만)
			float bare = smoothstep(0.95, 1.4, slope + (g_n0 - 0.5) * 0.4) * fz * smoothstep(0.45, 0.62, 1.0 - g_big) * 0.8;   // 가파른 숲 비탈 군데군데(사태 자국): 마사토
			float mas_k = clamp(max(max(scree_k, cut), bare * 0.65) * (1.0 - bed_k), 0.0, 1.0);
			float ff_k = fz * (1.0 - road_k);
			float lit_n = texture(noise_tex, p * 0.031 + vec2(0.37, 0.11)).r;
			ScanS sF = scan_s(S_FOREST, p, g_gx, g_gy);
			if (ff_k > 0.01 && lit_n > 0.42) {
				ScanS sL = scan_s(S_LITTER, p * mat2(vec2(0.8, -0.6), vec2(0.6, 0.8)), g_gx, g_gy);
				sF = scan_mix(sF, sL, scan_hk(smoothstep(0.42, 0.7, lit_n) * 0.85, sF.h, sL.h, 3.0));
			}
			// 바탕(흙 → 숲 바닥): 구운 흙 층 값은 숲 밖 들·마을에 그대로
			vec3 u_alb = mix(a_soil, sF.alb * (0.85 + 0.3 * mac), ff_k);
			float u_h = mix(sA.a, sF.h, ff_k), u_r = mix(sB.r, sF.r, ff_k), u_ao = mix(sB.b, sF.ao, ff_k);
			vec2 u_n = mix(sB.ag * 2.0 - 1.0, sF.n * 1.2, ff_k);
			if (trail_k > 0.01) {
				ScanS sT = scan_s(S_TRAIL, p, g_gx, g_gy);
				float k = scan_hk(trail_k, u_h, sT.h, 2.5);
				u_alb = mix(u_alb, sT.alb, k); u_h = mix(u_h, sT.h, k); u_r = mix(u_r, sT.r, k); u_ao = mix(u_ao, sT.ao, k); u_n = mix(u_n, sT.n, k);
			}
			if (mas_k > 0.01) {
				ScanS sM = scan_s(S_MASATO, p * mat2(vec2(0.6, 0.8), vec2(-0.8, 0.6)), g_gx, g_gy);
				float k = scan_hk(mas_k, u_h, sM.h, 2.5);
				u_alb = mix(u_alb, sM.alb, k); u_h = mix(u_h, sM.h, k); u_r = mix(u_r, sM.r, k); u_ao = mix(u_ao, sM.ao, k); u_n = mix(u_n, sM.n, k);
				gcov *= 1.0 - k;
			}
			// 풀: 숲 바닥 위 풀 덮임(ground_mask가 숲에서는 숲 틈·능선만 남긴다)
			float gk = gcov * (1.0 - trail_k);
			alb = mix(u_alb, a_grass, gk);
			dh = mix(u_h, gA.a, gk); dr = mix(u_r, gB.r, gk); dao = mix(u_ao, gB.b, gk);
			dsl = mix(u_n, (gB.ag * 2.0 - 1.0) * 1.3, gk) * 1.5;
			if (bed_k > 0.01) {
				ScanS sP = scan_s(S_PEBBLE, p, g_gx, g_gy);
				float k = scan_hk(bed_k, dh, sP.h, 2.0);
				alb = mix(alb, sP.alb * mix(vec3(1.0), vec3(0.62, 0.68, 0.66), bankw0), k);   // 물속 돌은 물때로 짙고 푸르스름
				dh = mix(dh, sP.h, k); dr = mix(dr, mix(sP.r, 0.25, bankw0), k); dao = mix(dao, sP.ao, k); dsl = mix(dsl, sP.n * 1.4, k);
			}
			// 바위(토지이용 7 · 가파른 비탈): 세 축 투영 화강암 + 위를 보는 면·그늘진 데 이끼
			float rk = rock_k * (1.0 - pav_k);
			if (rk > 0.01) {
				vec3 nwg;
				ScanS sR = scan_tri(S_GRANITE, v_wp, normalize(v_wn), 1.0, nwg);
				float moss = smoothstep(0.45, 0.75, texture(noise_tex, p * 0.05 + vec2(0.9, 0.3)).r * 0.7 + v_wn.y * 0.45) * (0.5 + 0.5 * fz);
				if (moss > 0.01) {
					vec3 nwm;
					ScanS sMo = scan_tri(S_MOSSROCK, v_wp, normalize(v_wn), 1.0, nwm);
					float km = scan_hk(moss, sR.h, sMo.h, 2.0);
					sR = scan_mix(sR, sMo, km); nwg = normalize(mix(nwg, nwm, km));
				}
				float k = scan_hk(rk, dh, sR.h, 2.0);
				alb = mix(alb, sR.alb * (0.9 + 0.25 * mac), k); dh = mix(dh, sR.h, k); dr = mix(dr, sR.r, k); dao = mix(dao, sR.ao, k);
				rock_scan = k; rock_nw = nwg;
			}
			if (pav_k > 0.01) {   // 박석 마당은 구운 층 그대로
				alb = mix(alb, a_rock, pav_k); dh = mix(dh, rA.a, pav_k); dr = mix(dr, rB.r, pav_k); dao = mix(dao, rB.b, pav_k); dsl = mix(dsl, (rB.ag * 2.0 - 1.0) * 2.5, pav_k);
			}
			rk2 = max(pav_k, rock_scan);
		}
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
		// ---- 먼 숲 수관·먼 고을 지붕(region_far_look — 나무·건물을 그리지 않는 거리부터) ----
		alb = mix(alb, srgb(canopy_color(p, v_wp.y)) * 0.8, far_canopy);
		alb = mix(alb, srgb(roof_color(p)) * 0.7, far_roof);
		rough = mix(rough, 0.9, max(far_canopy, far_roof));
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
		if (rock_scan > 0.0) nw = normalize(mix(nw, rock_nw, rock_scan * (1.0 - t_cov * 0.7)));   // 스캔 바위: 세 축 법선
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
