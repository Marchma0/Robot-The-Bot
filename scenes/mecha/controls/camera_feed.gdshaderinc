// Image de vieille caméra brouillée : partagée par l'écran du poste (dans le monde)
// et par la vue plein écran du nain assis. Tout est calculé localement, rien sur le réseau.
//
// Paramètres attendus dans le shader qui inclut ce fichier :
//   tint      : teinte de l'image (chaque poste a la sienne)
//   noise     : grain permanent (0..1)
//   burst     : neige forte, pour l'allumage / la coupure (0..1)

float feed_hash(vec2 p) {
	p = fract(p * vec2(443.897, 441.423));
	p += dot(p, p.yx + 19.19);
	return fract((p.x + p.y) * p.x);
}

float feed_band(float y, float center, float width) {
	float d = abs(fract(y - center + 0.5) - 0.5);
	return 1.0 - smoothstep(0.0, width, d);
}

vec3 feed_effect(sampler2D tex, vec2 uv, float t, vec3 tint, float noise, float burst) {
	// Petit saut d'image de temps en temps (une fois toutes les ~4 s, quelques images).
	float hop_seed = floor(t * 7.0);
	float hop = step(0.965, feed_hash(vec2(hop_seed, 3.1)));
	uv.y = fract(uv.y + hop * (feed_hash(vec2(hop_seed, 7.7)) - 0.5) * 0.08);

	// Bande de défilement qui descend lentement, avec un décalage horizontal dedans.
	float band = feed_band(uv.y, fract(t * 0.11), 0.045);
	float line = floor(uv.y * 240.0);
	float wobble = (feed_hash(vec2(line, floor(t * 30.0))) - 0.5) * 0.0025;
	uv.x += wobble + band * (feed_hash(vec2(line, t)) - 0.5) * 0.03;
	uv.x += burst * (feed_hash(vec2(line, floor(t * 60.0))) - 0.5) * 0.12;

	// Couleurs légèrement décalées (rouge et bleu de part et d'autre).
	float ab = 0.0022 + band * 0.004 + burst * 0.01;
	vec3 col;
	col.r = texture(tex, uv + vec2(ab, 0.0)).r;
	col.g = texture(tex, uv).g;
	col.b = texture(tex, uv - vec2(ab, 0.0)).b;

	// Teinte du poste, un peu délavée.
	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(luma), 0.35) * tint;

	// Lignes de balayage + scintillement.
	col *= 0.86 + 0.14 * sin(uv.y * 240.0 * 3.14159);
	col *= 0.95 + 0.05 * feed_hash(vec2(floor(t * 24.0), 1.3));

	// Grain + neige.
	float grain = feed_hash(uv * vec2(320.0, 240.0) + fract(t * 13.7) * 100.0);
	col = mix(col, vec3(grain), noise * 0.16 + band * 0.12);
	col = mix(col, vec3(grain * 0.9 + 0.05), clamp(burst, 0.0, 1.0));
	col += band * 0.06;

	// Bords assombris.
	vec2 c = uv - 0.5;
	col *= 1.0 - dot(c, c) * 1.1;
	return col;
}
