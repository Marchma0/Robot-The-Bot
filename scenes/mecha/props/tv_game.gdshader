shader_type spatial;
render_mode unshaded, shadows_disabled;

// Écran de la télé du salon : l'image du jeu Robo-Jet (SubViewport de la télé, voir TvSet),
// avec des lignes de balayage, un léger vignettage, et de temps en temps la télé capte mal (neige).

uniform sampler2D screen_texture : source_color, filter_linear;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	vec3 color = texture(screen_texture, uv).rgb;
	// Lignes de balayage et vignettage
	color *= 0.9 + 0.1 * sin(uv.y * 300.0);
	color *= 1.0 - 0.4 * pow(length(uv - 0.5) * 1.3, 2.5);
	// Mauvaise réception : 0,25 s de neige légère toutes les 14 s (sans gêner le jeu)
	float glitch = step(13.75, mod(TIME, 14.0));
	float snow = hash(floor(uv * vec2(120.0, 90.0)) + floor(TIME * 30.0));
	color = mix(color, vec3(snow), glitch * 0.35);
	ALBEDO = color;
}
