// 시작 메뉴 움직이는 바탕(scripts/ui/title_wallpaper.gd) — 원본 Seolhwarok_LivingWallpaper shaders/mist.gdshader 그대로(UV 기준이라 그림 크기와 상관없다)
shader_type canvas_item;
uniform float clock = 0.0;
uniform float strength = 1.0;
varying vec4 tint;
void vertex() { tint = COLOR; }
void fragment() {
 vec2 uv = UV;
 uv.x += sin(clock * 0.12) * 0.013 * strength;
 uv.y += sin(uv.x * 15.0 + clock * 0.18) * 0.002 * strength;
 vec4 c = texture(TEXTURE, uv);
 c.a *= 0.84 + 0.12 * sin(clock * 0.17 + uv.x * 5.0);
 c.a *= smoothstep(0.0, 0.02, UV.x) * (1.0 - smoothstep(0.98, 1.0, UV.x));
 COLOR = c * tint;
}
