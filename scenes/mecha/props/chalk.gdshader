shader_type spatial;
// Écriture à la craie : l'image 2D de l'ardoise (texte blanc sur fond transparent), rongée par un grain.
render_mode cull_back, depth_draw_never;

uniform sampler2D chalk : filter_linear_mipmap;
uniform sampler2D grain : filter_linear, repeat_enable;
uniform vec3 color : source_color = vec3(0.92, 0.9, 0.84);

void fragment() {
	float ink = texture(chalk, UV).a;
	float g = texture(grain, UV * vec2(3.0, 3.6)).r;
	ALBEDO = color;
	ROUGHNESS = 1.0;
	ALPHA = ink * smoothstep(0.15, 0.55, g + ink * 0.3) * 0.88;
}
