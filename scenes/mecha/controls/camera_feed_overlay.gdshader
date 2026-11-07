// Vue plein écran du nain assis à un poste : même image brouillée que l'écran de la cabine,
// plus le viseur du poste (0 = pince du grappin, 1 = cible de la foreuse).
shader_type canvas_item;

#include "res://scenes/mecha/controls/camera_feed.gdshaderinc"

uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;
uniform vec3 tint : source_color = vec3(1.0);
uniform float noise : hint_range(0.0, 1.0) = 0.6;
uniform float burst : hint_range(0.0, 1.0) = 0.0;
uniform int reticle = 0;
uniform vec3 reticle_color : source_color = vec3(1.0);

float reticle_mask(vec2 uv, vec2 px) {
	// Coordonnées en pixels depuis le centre (le viseur garde sa taille quelle que soit la fenêtre).
	vec2 p = (uv - 0.5) / px;
	vec2 a = abs(p);
	float w = 1.5;
	if (reticle == 0) {
		// Grappin : 4 coins de cadre.
		float s = 46.0;
		float l = 16.0;
		float h = step(abs(a.y - s), w) * step(s - l, a.x) * step(a.x, s);
		float v = step(abs(a.x - s), w) * step(s - l, a.y) * step(a.y, s);
		return max(h, v);
	}
	// Foreuse : cercle + petite croix au centre.
	float r = length(p);
	float ring = step(abs(r - 30.0), w);
	float cross_h = step(a.y, w) * step(a.x, 10.0) * step(4.0, a.x);
	float cross_v = step(a.x, w) * step(a.y, 10.0) * step(4.0, a.y);
	return max(ring, max(cross_h, cross_v));
}

void fragment() {
	vec3 col = feed_effect(screen_tex, SCREEN_UV, TIME, tint, noise, burst);
	float m = reticle_mask(SCREEN_UV, SCREEN_PIXEL_SIZE) * (1.0 - burst);
	COLOR = vec4(mix(col, reticle_color, m * 0.8), 1.0);
}
