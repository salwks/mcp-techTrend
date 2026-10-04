// 큰 강 물면 물가 띠 — 반투명 판(안쪽은 region_sea_opaque.gdshader가 그린다). 본문은 region_sea_body.gdshaderinc.
shader_type spatial;
render_mode specular_disabled, cull_disabled, blend_mix, depth_draw_opaque;

#define SEA_SPLIT
const float SPLIT_A = 0.94;
#include "res://shaders/region_sea_body.gdshaderinc"
