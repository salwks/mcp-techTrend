// 시작 메뉴 움직이는 바탕(scripts/ui/title_wallpaper.gd) — 원본 Seolhwarok_LivingWallpaper shaders/water.gdshader 그대로(UV 기준이라 그림 크기와 상관없다)
shader_type canvas_item;
uniform float clock = 0.0;
uniform float strength = 1.0;
varying vec4 tint;
void vertex() { tint = COLOR; }
void fragment() {
 vec2 uv = UV;
 float water = smoothstep(0.54, 0.85, uv.y);
 uv.x += sin(uv.y * 112.0 + clock * 0.52) * 0.0012 * water * strength;
 uv.y += sin(uv.x * 58.0 - clock * 0.38) * 0.00065 * water * strength;
 vec4 c = texture(TEXTURE, uv);
 float shimmer = sin(uv.y * 155.0 - clock * 0.72 + sin(uv.x * 27.0)) * 0.009;
 c.rgb *= 1.0 + shimmer * water * strength;
 COLOR = c * tint;
}
