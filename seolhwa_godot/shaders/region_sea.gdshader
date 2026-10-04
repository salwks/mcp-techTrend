// 권역 바다·호수 수면 — 평평한 판(바다 = region.json sea.y, 호수 = lakes[].y).
// 물가는 높이맵으로 정한다: 수심(수면 − 땅) → 물가선 바로 앞 흰 물거품 띠와 먹선, 얕은 곳은 옥빛, 먼 바다는 짙은 쪽빛.
// 데이터 바다 바닥은 거의 평평(실제 −1.5m × K)하므로 "물가에서 얼마나 먼가"는 물 가림 텍스처(water_mask, 4m)의
// G(뭍) 밉맵을 여러 단 읽어 흐린 값으로 대신한다. R = 바다 칸(하천·호수·뭍 아닌 물) — 바다 판은 R이 0인 곳(호수 바닥·
// 낮은 논·지도 밖 뭍 쪽)을 버린다. 호수 판은 윤곽 다각형이라 R을 보지 않는다(is_lake).
// 툰 규칙: region_water와 같은 붓 바림 램프 빛, 반구광 EMISSION, 같은 안개 식. 물결 텍스처(water.png)를 아주 느리게.
shader_type spatial;
render_mode specular_disabled, cull_disabled, blend_mix, depth_draw_opaque;

#include "res://shaders/region_sea_body.gdshaderinc"
