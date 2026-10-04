// 큰 강 물면 안쪽(물가 띠 밖) — 불투명 판. 반투명 판(region_sea.gdshader + SEA_SPLIT)과 같은 본문을 쓰고 서로 맞물려 고른다.
// 낮은 배 시점에서 강물이 화면 절반을 덮을 때 반투명 그리기(섞기 + 아래 땅까지 다 칠함)가 무거웠다(노량진 나루 78fps → 아래 보고).
shader_type spatial;
render_mode specular_disabled, cull_disabled, depth_draw_opaque;

#define SEA_SPLIT
#define SEA_OPAQUE
const float SPLIT_A = 0.94;
#include "res://shaders/region_sea_body.gdshaderinc"
