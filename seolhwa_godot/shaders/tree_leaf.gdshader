// 사실 나무 잎 카드(trees-khs) — 양면·알파 문턱. 본문은 tree_geo.gdshaderinc
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;
#define TREE_LEAF
#include "res://shaders/tree_geo.gdshaderinc"
