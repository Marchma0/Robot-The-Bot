# Direction artistique, modèles 3D et animation

> Fait partie des consignes du projet (voir `AGENTS.md`) : à lire avant de modéliser, d'animer ou de créer un niveau.

## Direction artistique — low poly
- **Low poly** : formes simples, facettes visibles (ombrage plat), la silhouette avant les détails.
- Robot « **cosy mais pas trop** » : métal peint, chanfreins, rivets, hublots ronds, touches de cuivre ; pas d'ambiance cabane.
- **Couleurs** : toujours celles de la palette (`prop_kit.PALETTE`) ; une couleur nouvelle s'y ajoute d'abord.
  Ni photos, ni textures peintes à la main : tout se fabrique par script.
- Peu de lumières à ombres (performances : Iris Xe), les autres sans ombre.

## Pipeline Blender → Godot
- Échelle : 1 unité Blender = 1 mètre. Appliquer les transforms (Ctrl+A) avant export. +Y up géré par l'export glTF.
- Nommage des objets pour l'import Godot : suffixes `-col` (collision), `-colonly`, `-rigid`, `-navmesh` quand utile.
- Armatures du mécha : os nommés de façon explicite (`leg_L_thigh`, `leg_L_shin`, `leg_L_foot`…) pour l'IK (`SkeletonIK3D` / modificateurs de squelette).
- Ne jamais éditer un `.glb` dans Godot : on modifie le `.blend`, on réexporte. Les ajustements se font dans une **scène héritée** (`scenes/mecha/mecha.tscn` hérite de `assets/models/mecha.glb`).
- Via le MCP Blender : préférer le **blockout** (formes simples, proportions, collisions) à la modélisation détaillée. Toujours sauvegarder le `.blend` dans `blender/`.
- **Orientation** : l'avant d'un modèle regarde vers **+Y** dans Blender (devient l'avant -Z dans Godot). Sa droite est donc en +X (mécha : foreuse en +X, grappin en -X).

### Modéliser avec une IA : fiche + planche de vues (obligatoire)
1. **Avant de modéliser**, écrire en 3 lignes : taille réelle en mètres (repère : un nain fait 1,2 m), budget de triangles, liste des pièces simples qui composent l'objet.
2. **Après chaque étape** (blockout, formes, détails), générer la **planche de vues** et la **regarder** :
   ```
   blender -b blender/<fichier>.blend --python blender/tools/render_views.py -- --out build/views/<nom>.png [--target Objet,Collection] [--ref]
   ```
   6 vues à la même échelle (avant, droite, arrière, gauche, dessus, 3/4), grille au sol de 1 m, dimensions affichées dans la console.
   `--ref` pose à droite du modèle (+X) deux **repères d'échelle** en bleu : un nain de 1,2 m et une porte de 2 m ; la console dit combien de « nains » mesure le modèle.
   Avec le MCP Blender ouvert, on peut aussi exécuter le fichier dans Blender puis appeler `render_views(out=..., target=[...])`.
   Le fichier `.blend` doit être **sauvegardé** avant la version en ligne de commande (elle lit le fichier sur le disque).
3. **Comparer** la planche à la demande (proportions, pièces qui flottent, arrière, symétrie, échelle), **corriger au moins une fois**, régénérer.
4. Montrer la dernière planche à l'humain avant d'exporter le `.glb`. Les planches vont dans `build/views/` (non versionné).

### Contrôles automatiques à l'export (PASS / FAIL)
`kit.save_and_export` (et `mecha_shell.py`) contrôle le modèle **avant d'écrire quoi que ce soit** ; un FAIL arrête l'export et dit quoi corriger :
- `blender/tools/check_asset.py` : budget de triangles, échelle appliquée (et pas de rotation sur un objet libre), **au sol**
  (le bas touche z = 0, enfoncé de 15 cm au plus, jamais au-dessus ; `ground=False` pour un objet accroché au mur, au plafond
  ou une pièce de mécanisme), faces cassées et sommets isolés, suffixes de collision bien écrits, UV si un matériau a une image,
  faces superposées. Les trous (arêtes à une seule face) sont signalés sans bloquer.
- `blender/tools/roundtrip_glb.py` : après l'export, le `.glb` est **réimporté dans un autre Blender, vide**, et comparé au
  modèle (triangles, taille à 1 % près, os, animations) : attrape un objet oublié, un modificateur non appliqué, une animation perdue.
- Sans rien écrire (pour vérifier tous les objets après avoir touché aux outils) : variable d'environnement `ROBOT_CHECK_ONLY=1`
  devant la commande d'un script d'objet. Seuls : `check_asset.py -- --budget N [--no-ground]` sur un `.blend`,
  `roundtrip_glb.py -- <fichier>.glb --blend <fichier>.blend`.

### Génération par IA et Geometry Nodes
- **`generate_3d` / `search_assets` du MCP Blender** : seulement pour des **décors et petits objets**, jamais pour le robot ni les
  nains (squelette précis). Une génération peut coûter un crédit : demander à l'humain avant. Le fichier obtenu est rangé dans
  `blender/sources/` (avec sa source et sa licence notées dans le script) ; un script `blender/props/<nom>.py` l'importe et le
  retravaille (réduit au budget, couleurs de la palette, ombrage plat low poly, collisions), puis passe par `kit.save_and_export`.
- **Geometry Nodes** : pour les objets répétés avec des variantes (rochers, caisses, tuyaux, blocs minables) ; le groupe de nœuds est
  construit par le script, une variante = une graine. L'export applique le modificateur (le `.glb` contient un maillage figé) et
  chaque variante passe les contrôles.

### Intérieur modulaire : coque + un fichier par objet
- **Modèles construits par script** : le script Python fait foi, le `.blend` et le `.glb` en sont générés. On modifie le script puis on le relance ; si on retouche un `.blend` à la main, le dire dans le commit.
- **Coque du mécha** (murs, sol, plafond, hublots, structure, tuyaux, usure, textures de tôle) : `blender/mecha_shell.py`, relançable à volonté. **Aucun décor dans `mecha.blend`** : un meuble, un objet ou un équipement (garde-corps, émetteur du rayon, plafonnier…) est toujours un objet à part (ligne suivante), jamais modélisé dans la coque. `mecha_shell.py` retire le décor qui y traînerait encore (liste `DECOR`) :
  `blender -b blender/mecha.blend --python blender/mecha_shell.py` → sauvegarde `mecha.blend` et réexporte `mecha.glb`.
- **Objets de l'intérieur** (meubles, caisses, cabine des toilettes…) : un script par objet `blender/props/<nom>.py`, qui utilise `blender/tools/prop_kit.py` et produit `blender/props/<nom>.blend` + `assets/models/props/<nom>.glb` :
  `blender -b --factory-startup --python blender/props/<nom>.py`
- **Palette partagée** : `prop_kit.PALETTE` (mêmes noms que dans `mecha.blend` : `Copper`, `Paint`, `Iron`, `Wood`…). Toujours utiliser `kit.material("<nom>")` ; un nouveau matériau s'ajoute d'abord à la palette.
- **Pas de faces superposées** (sinon elles clignotent en jeu) : `kit.save_and_export` refuse l'export s'il trouve deux faces de matériaux différents dans le même plan et le même sens, et indique où. Règle : une pièce posée sur une autre la dépasse ou s'arrête 2 mm avant (ex. l'âme en tôle est rentrée de 2 mm sous son cadre). `mecha_shell.py` corrige automatiquement l'ancien décor de `mecha.blend` (la petite pièce est avancée ou rétrécie de 1,5 mm).
- **Assemblage dans Godot**, jamais en fusionnant les maillages : une sous-scène par pièce (`scenes/mecha/interior/belly.tscn`, `head.tscn`) placée dans `mecha.tscn`. Un objet qui a besoin d'une collision ou d'un script a sa propre scène `scenes/mecha/props/<nom>.tscn`.
- **Placer un objet à la main dans un `.tscn`** : position Godot = Blender (x, z, -y). Dans `Transform3D(a, b, c, d, e, f, g, h, i, x, y, z)`, les 9 premiers nombres sont les **lignes** de la matrice (pas les colonnes). Rotations toutes prêtes pour un objet dont l'avant (+Y Blender) doit regarder :
  - vers l'avant du mécha (-Z Godot) : `Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, …)`
  - vers l'arrière du mécha (+Z Godot) : `Transform3D(-1, 0, 0, 0, 1, 0, 0, 0, -1, …)`
  - vers la droite du mécha (+X) : `Transform3D(0, 0, -1, 0, 1, 0, 1, 0, 0, …)`
  - vers la gauche du mécha (-X) : `Transform3D(0, 0, 1, 0, 1, 0, -1, 0, 0, …)`
  Toujours vérifier avec `interior_shots` que l'objet est dans le bon sens.
- **Textures extraites par Godot** (`assets/models/<modèle>_<texture>.png` + `.import`) : générées à l'import du `.glb`, on les versionne.
- **Vérifier l'intérieur dans le jeu** : `Godot --path . --resolution 1280x720 res://tests/tools/interior_shots.tscn` → 8 captures à hauteur de nain dans `build/views/interior_*.png` (ventre et tête, 4 directions). Après un réexport, lancer d'abord `Godot --headless --path . --import`.

## Animation — tout ce qui bouge est animé
- **Règle** : une mécanique n'est pas finie tant que ce qui bouge n'est pas animé (nains, jambes et bras du robot, foreuse, grappin, leviers, sac à dos…). Pas d'objet qui glisse ou qui se téléporte.
- **Nains** : squelette (armature) fait dans Blender, animations exportées dans le `.glb` (actions nommées : `idle`, `walk`, `jump`, `float`, `climb`, `grab`, `press`, `sit`, `crouch`, `crouch_walk`, `poop`, `throw`, `hit`, `hold_low`/`hold_mid`/`hold_high`, `carry`, `emote_*`…), jouées dans Godot via un `AnimationTree`.
- **Robot** : les jambes et les bras sont animés **à partir de l'état simulé par l'hôte** (angles des articulations, extension de la foreuse…). Ce sont des animations procédurales ou des blend d'actions Blender, jamais des positions inventées côté client.
- **Réseau** : on synchronise l'**état** (vitesse, au sol, tient un levier, assis, glisse…), jamais l'animation elle-même. Chaque peer joue l'animation correspondante localement.
- **Ombres** : le décor intérieur du robot est sur le calque de rendu 2 ; le soleil d'un nouveau niveau doit avoir `shadow_caster_mask = 4294967293` (sans le calque 2), sinon les performances s'effondrent.
