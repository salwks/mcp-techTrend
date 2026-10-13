// 시작 메뉴 움직이는 바탕(scripts/ui/title_wallpaper.gd) — 원본 Seolhwarok_LivingWallpaper shaders/scholar.gdshader 그대로(UV 기준이라 그림 크기와 상관없다)
shader_type canvas_item;
uniform float clock = 0.0;
uniform float strength = 1.0;
varying vec4 tint;
void vertex() { tint = COLOR; }
void fragment() {
 vec2 uv = UV;
 // The free end waves while the hand and feet stay anchored.
 float paper_x = smoothstep(0.345, 0.47, uv.x) * (1.0 - smoothstep(0.575, 0.585, uv.x));
 float paper_y = smoothstep(0.55, 0.59, uv.y) * (1.0 - smoothstep(0.755, 0.77, uv.y));
 float paper = paper_x * paper_y;
 uv.y += paper * sin(uv.x * 39.0 - clock * 1.35) * 0.0042 * strength;
 float robe = smoothstep(0.75, 0.79, UV.y) * (1.0 - smoothstep(0.935, 0.98, UV.y));
 float body_x = smoothstep(0.16, 0.19, UV.x) * (1.0 - smoothstep(0.33, 0.37, UV.x));
 uv.x += robe * body_x * sin(UV.y * 38.0 + clock * 1.0) * 0.0016 * strength;
 float breath = smoothstep(0.49, 0.53, UV.y) * (1.0 - smoothstep(0.87, 0.96, UV.y));
 uv.y += breath * body_x * sin(clock * 1.15) * 0.00045 * strength;
 COLOR = texture(TEXTURE, uv) * tint;
}
