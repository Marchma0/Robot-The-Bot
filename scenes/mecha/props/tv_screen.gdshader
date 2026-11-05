shader_type spatial;
render_mode unshaded, shadows_disabled;

// Écran de la télé du salon : « l'émission des nains ».
// Un ciel, une colline, un nain (tête ronde et barbe) qui sautille d'un bord à l'autre,
// des lignes de balayage, et de temps en temps la télé capte mal (neige).

uniform vec3 sky_top : source_color = vec3(0.35, 0.55, 0.85);
uniform vec3 sky_bottom : source_color = vec3(0.95, 0.8, 0.55);
uniform vec3 hill : source_color = vec3(0.3, 0.55, 0.25);
uniform vec3 skin : source_color = vec3(0.95, 0.75, 0.6);
uniform vec3 beard : source_color = vec3(0.55, 0.32, 0.15);
uniform vec3 helmet : source_color = vec3(0.6, 0.62, 0.66);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	float t = TIME;
	vec3 color = mix(sky_top, sky_bottom, uv.y);
	// Colline qui défile
	float ground = 0.72 + 0.05 * sin(uv.x * 9.0 + t * 1.5);
	if (uv.y > ground) {
		color = hill * (0.85 + 0.15 * sin(uv.x * 40.0 + t * 6.0));
	}
	// Le nain sautille d'un bord à l'autre
	float x = 0.5 + 0.35 * sin(t * 0.7);
	float y = ground - 0.13 - 0.18 * abs(sin(t * 3.0));
	vec2 p = (uv - vec2(x, y)) * vec2(1.5, 1.0);
	if (length(p) < 0.09) { color = skin; }
	if (p.y > 0.0 && abs(p.x) < 0.11 - p.y * 0.6 && p.y < 0.17) { color = beard; }
	if (p.y < -0.03 && length(p) < 0.1) { color = helmet; }
	// Lignes de balayage et vignettage
	color *= 0.88 + 0.12 * sin(uv.y * 260.0);
	color *= 1.0 - 0.45 * pow(length(uv - 0.5) * 1.3, 2.5);
	// Mauvaise réception : 0,6 s de neige toutes les 9 s
	float glitch = step(8.4, mod(t, 9.0));
	float snow = hash(floor(uv * vec2(120.0, 90.0)) + floor(t * 30.0));
	color = mix(color, vec3(snow), glitch * 0.9);
	ALBEDO = color;
}
