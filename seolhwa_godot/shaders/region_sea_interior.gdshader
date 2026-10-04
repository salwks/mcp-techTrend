// 큰 강 물면 한가운데(32m 칸과 그 둘레가 모두 바다 칸) — 불투명, discard 없음.
// discard가 없어야 GPU가 물 아래 땅을 칠하지 않고 건너뛴다(Apple 타일 GPU의 숨은 면 제거). 물가 칸은
// region_sea_opaque(불투명 + 물가 띠 버림)와 region_sea_split(반투명 물가 띠)가 맡는다. 본문은 region_sea_body.gdshaderinc.
shader_type spatial;
render_mode specular_disabled, cull_disabled, depth_draw_opaque;

#define SEA_SPLIT
#define SEA_OPAQUE
#define SEA_INTERIOR
const float SPLIT_A = 0.94;
#include "res://shaders/region_sea_body.gdshaderinc"
