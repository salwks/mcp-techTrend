// 시작 메뉴 움직이는 바탕(scripts/ui/title_wallpaper.gd) — 원본 Seolhwarok_LivingWallpaper shaders/wind.gdshader 그대로(UV 기준이라 그림 크기와 상관없다)
shader_type canvas_item;
uniform float clock = 0.0;
uniform float strength = 1.0;
uniform float amount = 0.001;
uniform float anchor_y = 0.9;
varying vec4 tint;
void vertex() { tint = COLOR; }
void fragment() {
 vec2 uv = UV;
 float movable = 1.0 - smoothstep(anchor_y - 0.18, anchor_y, UV.y);
 uv.x += sin(clock * 0.35 + UV.y * 10.0) * amount * movable * strength;
 COLOR = texture(TEXTURE, clamp(uv, vec2(0.0), vec2(1.0))) * tint;
}
