shader_type spatial;
// Surbrillance de la commande visée (Interactable.set_highlighted), posée par-dessus ses maillages
// (material_overlay) : lueur chaude ajoutée, forte sur les bords (faces de biais), très légère de face,
// qui respire doucement. Remplace l'ancien voile jaune uni, peu lisible.
render_mode unshaded, blend_add, cull_back, shadows_disabled;

uniform vec4 glow_color : source_color = vec4(1.0, 0.78, 0.4, 1.0);
// Lueur de face (0 à 1) et sur les bords.
uniform float fill = 0.12;
uniform float rim = 0.85;
// Plus grand = bord plus fin.
uniform float rim_power = 2.2;

void fragment() {
	float edge = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);
	float breathe = 0.82 + 0.18 * sin(TIME * 4.0);
	ALBEDO = glow_color.rgb * (fill + rim * edge) * breathe;
}
