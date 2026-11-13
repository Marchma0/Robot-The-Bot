# Direction artistique

> Fait partie des consignes du projet (voir `AGENTS.md`) : à lire avant de modéliser, de créer un niveau ou de régler un éclairage.
> Les couleurs sont dans `blender/tools/prop_kit.py` (`PALETTE`) : un nouveau matériau s'y ajoute d'abord.

## En une phrase
**Un diorama low poly lumineux et encré** : des nains mineurs trapus qui retapent un vieux robot de casse, entre la mine
(bois, rails, lanternes) et l'usine rétro (tuyaux, écrans à tube, tôle rivetée). Réf. : *Deep Rock Galactic* rencontre
*Borderlands*, en plus clair et en plus chaleureux.

## Ce que doit dire chaque image (le lore)
- **Récupération et bricolage** : le robot vient de la casse. Tôle peinte écaillée, pièces rapportées d'une autre couleur,
  rivets, soudures, rustines, câbles scotchés. Il est vieux mais **soigné** : les nains l'aiment et l'ont décoré.
- **Des mineurs** : bois brut et cordes, rails et wagonnets, casques à lampe, lanternes, minerai qui brille dans la roche.
- **Rétro-industriel (dieselpunk)** : tuyaux, manomètres, leviers, gros boutons, écrans à tube (CRT) verts ou cyan,
  cuivre et laiton. Pas d'écran plat, pas de plastique lisse, pas de néons futuristes.
- **De l'humour** : proportions exagérées, objets de la vie des nains (café, fléchettes, dessins aux murs), rien de sinistre.

## Formes
- **Low poly stylisé** : facettes visibles, ombrage plat, rochers taillés en gros blocs facettés.
- **Proportions trapues** : tout est un peu court, large et lourd (nains, robot, meubles, outils). Une poignée ou un bouton
  est **plus gros que nature** pour se lire de loin.
- **La silhouette d'abord** : un objet se reconnaît à sa forme noire seule, avant ses couleurs et ses détails.
- **Contours noirs épais** (style encré / cel-shading) : faits dans Godot par un shader, pas dans les modèles.

## Lumière : un jeu clair, qui se vend sur Steam
Une capture prise au hasard doit être **lisible en petit** (vignette de la page Steam) et donner envie : jamais une image sombre.
- **Clé chaude, ombre froide** : la lumière principale (soleil, lanternes, lampes) est ambre / dorée, les ombres sont
  **bleu-violet et claires**, jamais noires. Le noir pur est réservé aux contours.
- **Ambiance forte** : même sous terre, une lumière d'ambiance bleutée éclaire tout ; on voit toujours le fond du décor.
- **Points chauds** : lanternes, braises, écrans et minerai sont émissifs ; ils guident l'œil vers ce qui compte (poste,
  sortie, objet à prendre).
- **Lumière de contour** (rim) froide sur les personnages et le robot pour les détacher du fond.
- **Chaque mission a sa couleur dominante** (canyon orangé, grotte bleue, forêt verte…) mais garde la règle chaud / froid.

## Couleurs
- **Valeurs moyennes à claires et saturées**, comme un jouet peint ; les ombres viennent de l'éclairage, pas des couleurs.
- **Le robot ressort du décor** : peinture sarcelle (complémentaire de l'ambre des lumières) ; les décors sont dans les
  bruns, ocres, gris-bleu et ardoise.
- **Accents** : jaune chantier et rouge pour ce qu'on peut toucher (leviers, boutons, danger) ; cuivre pour les détails ;
  cyan pour les écrans, le rayon et le minerai.
- Ni photos ni textures peintes à la main : tout vient de la palette et des scripts.

## Prompt des nains (images de référence)
Sert à générer des **images de référence** (planche de face / profil / dos, variantes de tenue) avant de construire le nain
par script ; pas à générer le modèle 3D lui-même (les personnages se font par script, sur le squelette existant).
Le prompt est en anglais (les générateurs d'images le comprennent mieux). Synthèse de la DA (2026-11-12) et des
« nains garagistes » de la roadmap (2.8) : des **mineurs-mécanos**.

**Prompt :**
```
Stylized low poly 3D character, a stocky dwarf mechanic-miner who repairs an old junkyard robot, video game hero for a
cozy co-op game. Chunky exaggerated proportions: 1.2 m tall, big head (about a third of the body), huge hands and boots,
short thick legs, broad barrel chest. Big bushy braided beard in warm ginger, round nose, small cheerful eyes under
heavy eyebrows. Outfit: patched canvas work overalls with rolled sleeves, thick leather tool belt with a wrench, a
hammer and pouches, oversized leather work gloves, steel-toe boots, mining helmet with a brass headlamp and welding
goggles pushed up on it, small oil stains and soot smudges. Player color on the overalls: {COLOR}. Visible flat-shaded
facets, clean simple shapes, readable silhouette, thick black ink outlines, toy-like painted colors with medium to light
saturated values, warm amber key light, light blue-violet shadows (never black), cold rim light. Retro-industrial mining
mood (copper, brass, riveted metal, wood). Full body, neutral A-pose, character turnaround sheet: front, side, back
views at the same scale, plain light background.
```

**À éviter (prompt négatif) :**
```
realistic, photo, high poly, smooth subdivided surfaces, PBR scans, grimy dark horror, black shadows, thin elongated
proportions, fantasy armor, chainmail, horned helmet, axe, sci-fi neon, plastic, futuristic suit, text, watermark
```

**Couleur du joueur** (`{COLOR}`, comme `DwarfLook.SLOT_COLORS`) : `brick red` (joueur 1), `cobalt blue` (2),
`grass green` (3), `mustard yellow` (4). Seule la combinaison change de couleur : barbe, cuir et métal restent les mêmes
(un joueur se reconnaît de loin à sa couleur).

**Variantes** (pour les skins, 2.4) : remplacer le casque par `welding mask flipped up` ou `flat cap`, la barbe par
`black forked beard` / `white long beard`, ajouter `goggles with cracked lens`, `copper prosthetic arm`, `patched scarf`.

**Contraintes à garder en modélisant** : même squelette et mêmes noms d'os que `dwarf.blend` (toutes les animations
restent) ; la combinaison garde le matériau `Tunic` (c'est lui que le jeu teinte) ; pas de détail plus fin que ce qui se
lit à 3 m ; la tête est cachée à la première personne, donc **le ventre, la ceinture, les gants et les manches** sont ce
que le joueur voit de lui : c'est là qu'on met le détail.
