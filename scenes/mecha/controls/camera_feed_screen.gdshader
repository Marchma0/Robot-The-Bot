// Écran du poste (grappin / foreuse) dans la cabine : image de la caméra du bras, brouillée.
shader_type spatial;
render_mode unshaded, cull_back;

#include "res://scenes/mecha/controls/camera_feed.gdshaderinc"

uniform sampler2D feed : source_color, filter_linear, repeat_disable;
uniform vec3 tint : source_color = vec3(1.0);
uniform float noise : hint_range(0.0, 1.0) = 0.6;
uniform float burst : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	ALBEDO = feed_effect(feed, UV, TIME, tint, noise, burst);
}
