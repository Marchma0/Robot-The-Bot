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
- **Performances (Iris Xe)** : peu de lumières à ombres, les autres sans ombre.

## Couleurs
- **Valeurs moyennes à claires et saturées**, comme un jouet peint ; les ombres viennent de l'éclairage, pas des couleurs.
- **Le robot ressort du décor** : peinture sarcelle (complémentaire de l'ambre des lumières) ; les décors sont dans les
  bruns, ocres, gris-bleu et ardoise.
- **Accents** : jaune chantier et rouge pour ce qu'on peut toucher (leviers, boutons, danger) ; cuivre pour les détails ;
  cyan pour les écrans, le rayon et le minerai.
- Ni photos ni textures peintes à la main : tout vient de la palette et des scripts.
