// Bulle de Credo Sum : matière translucide qui distord la lumière comme de l'eau
// et luit sur ses bords de la couleur de l'émotion du flux (Lore 0.1.4).
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, blend_mix;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform vec4 tint : source_color = vec4(0.6, 0.3, 1.0, 1.0);
uniform float strength = 0.035;
uniform float intensity : hint_range(0.0, 1.0) = 1.0;
uniform float glow = 2.5;

void fragment() {
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = pow(1.0 - facing, 2.5);
	vec2 wobble = vec2(
		sin(UV.y * 22.0 + TIME * 2.3) + sin(UV.x * 9.0 - TIME * 1.1),
		cos(UV.x * 19.0 - TIME * 1.9) + cos(UV.y * 7.0 + TIME * 0.8)
	);
	vec2 offset = wobble * strength * intensity * (0.35 + facing);
	vec3 behind = textureLod(screen_tex, SCREEN_UV + offset, 0.0).rgb;
	ALBEDO = behind + tint.rgb * rim * glow * intensity;
	ALPHA = intensity;
}
