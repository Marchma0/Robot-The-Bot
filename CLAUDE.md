# CLAUDE.md — Projet "Mécha à Nains" (nom provisoire)

## Le projet en 3 lignes
Jeu coop 3D à 4 joueurs en P2P via Steam. Quatre nains pilotent un mécha **depuis l'intérieur** :
ils se déplacent physiquement dans le cockpit et interagissent avec des postes/panneaux pour faire bouger le mécha.
Objectif de base : amener le mécha d'un point A à un point B. Le game design est **en exploration** (voir `docs/ideas.md`, rien n'y est validé).

### Le mécha (validé, voir `docs/decisions.md`)
- Robot trapu low poly, style « robot cosy mais pas trop » (métal peint, chanfreins, rivets, hublots ronds, touches de cuivre — pas d'ambiance cabane).
- **Ventre** : 2 nains aux postes des **jambes** (une jambe chacun).
- **Tête** : 2 nains aux postes des **mains** — main gauche **grappin** (attraper des objets), main droite **foreuse**. Ils voient dehors par les deux yeux ronds (hublots).
- On **monte** du ventre à la tête par un **escalier**, on **redescend** par une **barre de pompier**.
- **Jambes** (détail complet dans `docs/design_jambes.md`) : chaque nain du ventre pilote **sa** jambe avec **un joystick**. Pousser le joystick lève le pied et déplace un **curseur au sol** ; relâcher pose le pied sur le curseur, et l'**IK** plie le genou. Tirer vers soi recule le pied, écarter sur le côté fait pivoter le bassin. L'**équilibre** est réel : un pas mal compensé fait **chuter** le robot (ragdoll). Les actions spéciales (s'accroupir, se relever, sauter) se font à des **panneaux muraux**, par des **combinaisons à deux** gravées sur les murs (aucun QTE affiché à l'écran).
- **Foreuse** : console de la tête avec un **levier de profondeur** (0 → 3 m, il reste où on le laisse) et un gros **bouton « miner »** (interrupteur). Le bras **s'étend jusqu'à 3 m** et **mine** ce qui est minable devant lui.
- **Grappin** : seule exception aux commandes libres. Le nain **s'assoit** (station `Seat`) devant un **petit écran** et ne contrôle plus son personnage. Il voit par une **caméra montée sur le bras du grappin**, pilote le bras et attrape des objets.
- **Inventaire** : ce qui est attrapé va **automatiquement** dans un **gros sac à dos** porté dans le dos du robot.

## Stack
- **Moteur** : Godot 4.7.x, **GDScript uniquement** (pas de C#), physique 3D **Jolt**.
- **3D** : Blender → export **glTF binaire (.glb)** dans `assets/models/`.
- **Réseau** : `MultiplayerAPI` haut niveau de Godot (RPC, `MultiplayerSpawner`, `MultiplayerSynchronizer`).
  - En dev : `ENetMultiplayerPeer` en local (plusieurs instances).
  - En prod : `SteamMultiplayerPeer` via **GodotSteam** (GDExtension), App ID de test 480.
  - Le choix du peer est isolé dans `scripts/network/network_manager.gd` : le reste du code ne doit JAMAIS dépendre de Steam directement.
- **Outils IA** : Claude Code + MCP Godot + MCP Blender.

## Arborescence
```
project.godot
addons/            # plugins tiers (GodotSteam, etc.) — ne pas modifier, NON versionnés : liste + installation dans addons/ADDONS.txt
assets/
  models/          # .glb exportés depuis Blender
  textures/ audio/ fonts/
blender/           # fichiers sources .blend (pas importés par Godot, voir .gdignore)
scenes/
  main/            # menus, lobby, scène de jeu racine
  mecha/           # le mécha, ses jambes, son cockpit
  player/          # le nain
  levels/
scripts/
  network/         # NetworkManager (autoload), lobby, spawn
  mecha/           # contrôle, IK, équilibre, stations
  player/
  interaction/     # système générique d'interaction (stations, panneaux)
docs/
  ideas.md         # idées de game design NON validées
  decisions.md     # décisions prises (date + raison)
tests/             # scènes de test isolées (sandbox_*.tscn)
```

## Architecture réseau — règles NON négociables
1. **Hôte autoritaire** : seul l'hôte (peer id 1) simule la physique du mécha. Les clients envoient leurs **inputs**, jamais des positions du mécha.
2. Les nains : chaque joueur a l'autorité sur le déplacement de **son** nain (`set_multiplayer_authority(peer_id)`), l'hôte valide les interactions avec les stations.
3. Les interactions (prendre un poste, appuyer sur un bouton) passent par des RPC `@rpc("any_peer", "call_local", "reliable")` vers l'hôte, qui vérifie puis applique.
4. Les inputs continus (joystick) : `"unreliable_ordered"`.
5. Tout nouveau système doit être pensé "comment ça se synchronise ?" **avant** d'être codé. Si ce n'est pas clair, demander.
6. Le cockpit est dans un repère **local au mécha** : les nains sont enfants du mécha (ou d'un nœud qui le suit), pour ne pas glisser quand il bouge.

## Conventions GDScript
- **Typage statique partout** (`var speed: float = 3.0`, `func foo(x: int) -> void`).
- `snake_case` pour fichiers/variables/fonctions, `PascalCase` pour `class_name` et nœuds.
- Un script = une responsabilité. Préférer composition (nœuds enfants) à l'héritage profond.
- Signaux plutôt que références directes entre systèmes. Pas de `get_node("../../..")` : utiliser `@export` ou `%NomUnique`.
- Ordre dans un script : `class_name`, `extends`, signaux, enums, constantes, `@export`, variables, `_ready`, `_physics_process`, méthodes publiques, méthodes privées (`_prefixe`).
- Toute la logique de gameplay physique dans `_physics_process`, pas `_process`.
- Les inputs sont déclarés dans la Input Map (`project.godot`), jamais de touches codées en dur. Prévoir la manette dès le début.

## Pipeline Blender → Godot
- Échelle : 1 unité Blender = 1 mètre. Appliquer les transforms (Ctrl+A) avant export. +Y up géré par l'export glTF.
- Nommage des objets pour l'import Godot : suffixes `-col` (collision), `-colonly`, `-rigid`, `-navmesh` quand utile.
- Armatures du mécha : os nommés de façon explicite (`leg_L_thigh`, `leg_L_shin`, `leg_L_foot`…) pour l'IK (`SkeletonIK3D` / modificateurs de squelette).
- Ne jamais éditer un `.glb` dans Godot : on modifie le `.blend`, on réexporte. Les ajustements se font dans une **scène héritée** (`scenes/mecha/mecha.tscn` hérite de `assets/models/mecha.glb`).
- Via le MCP Blender : préférer le **blockout** (formes simples, proportions, collisions) à la modélisation détaillée. Toujours sauvegarder le `.blend` dans `blender/`.

## Animation — tout ce qui bouge est animé
- **Règle** : une mécanique n'est pas finie tant que ce qui bouge n'est pas animé (nains, jambes et bras du robot, foreuse, grappin, leviers, sac à dos…). Pas d'objet qui glisse ou qui se téléporte.
- **Nains** : squelette (armature) fait dans Blender, animations exportées dans le `.glb` (actions nommées : `idle`, `walk`, `jump`, `climb`, `slide_pole`, `grab`, `press`, `sit`…), jouées dans Godot via un `AnimationTree`.
- **Robot** : les jambes et les bras sont animés **à partir de l'état simulé par l'hôte** (angles des articulations, extension de la foreuse…). Ce sont des animations procédurales ou des blend d'actions Blender, jamais des positions inventées côté client.
- **Réseau** : on synchronise l'**état** (vitesse, au sol, tient un levier, assis, glisse…), jamais l'animation elle-même. Chaque peer joue l'animation correspondante localement.

## Usage des MCP
- **MCP Godot** : utiliser pour lancer le projet, lire les erreurs/sorties du debugger, inspecter l'arborescence des scènes. Après toute modification de script, **lancer le jeu et vérifier la sortie** avant de dire que c'est fini.
- **MCP Blender** : Blender doit être ouvert avec l'addon connecté. Si la connexion échoue, le dire au lieu d'improviser.
- Les fichiers `.tscn` / `.tres` sont du texte : on peut les éditer à la main, mais avec prudence (ids `ExtResource`/`SubResource` cohérents). Pour les scènes complexes, préférer passer par le MCP ou demander à l'utilisateur de le faire dans l'éditeur.

## Ce qu'il ne faut PAS faire
- Ne jamais toucher à `.godot/`, aux fichiers `*.import`, ni à `addons/` (sauf demande explicite).
- Ne pas ajouter de plugin/addon sans demander. Tout addon ajouté doit être inscrit dans `addons/ADDONS.txt` (version, source, dossier, rôle, installation).
- Ne pas implémenter une idée de `docs/ideas.md` sans que je l'aie validée.
- Ne pas faire de gros refactors non demandés. Petits pas, testables.
- Pas de dépendance à Steam dans le gameplay (le jeu doit tourner en ENet local).

## Façon de travailler
1. Pour toute feature : proposer un plan court (fichiers touchés, nœuds créés, impact réseau) → je valide → implémentation.
2. Prototyper chaque mécanique dans une scène isolée `tests/sandbox_<feature>.tscn` avant de l'intégrer.
3. Tester le multi en local : Godot → Debug → *Customize Run Instances* → 2 à 4 instances (une hôte, les autres clients).
   - À distance : exporter l'exe (`Godot --headless --path . --export-release "Windows Desktop" build/windows/mecha-nains.exe`, puis copier `steam_appid.txt` à côté), envoyer le dossier `build/windows/` zippé, et passer par Steam (lobby / invitation) ou par un VPN type Tailscale en mode local.
4. Après chaque étape qui marche : proposer un message de commit git clair.
5. Noter les décisions importantes dans `docs/decisions.md`.

## Roadmap (prototype)
- [x] M0 — Projet, Input Map, NetworkManager ENet (host/join local), spawn de 4 nains
- [x] M1 — Nain contrôlable (CharacterBody3D) dans un cockpit qui bouge
- [x] M2 — Modèles 3D low poly simples (Blender via MCP) : nain, mécha robot (ventre + tête, escalier, trou de la barre de pompier), postes → `.glb` + scènes héritées
- [x] M3 — Système d'interaction : commandes physiques toujours actives (boutons instantanés, leviers/joysticks qu'on attrape), pas de poste verrouillant
- [x] M4 — Animations des nains : squelette Blender + animations `idle`, `walk`, `jump`, `grab` (tenir un levier), `press` (appuyer), état synchronisé et `AnimationTree` dans Godot. Les leviers et boutons s'animent déjà selon leur état (fait en M3)
- [ ] M5 — Steam (avancé pour tester à distance) : GodotSteam (App ID 480), choix ENet / Steam isolé dans `network_manager.gd`, lobby Steam, rejoindre par invitation ou code de lobby, export Windows (`.exe`) à envoyer aux testeurs. ENet reste disponible pour les tests locaux
- [ ] M6 — Circulation dans le mécha : escalier pour monter du ventre à la tête, **barre de pompier** pour redescendre vite (mécanique de glissade), avec les animations `climb` et `slide_pole`
- [ ] M7 — Marche du mécha (détail : `docs/design_jambes.md`). Tout est simulé par l'hôte : les clients n'envoient que leurs joysticks, l'état (pieds, curseurs, bassin, phase) est synchronisé et l'IK est calculée chez chacun
  - [ ] M7.1 — Squelette + IK + pas : jambes remodelées (cuisse, tibia, pied, os `leg_L_*`), **1 joystick + 1 pad à 4 flèches par jambe** sur les consoles du ventre (commandes déjà en place), curseur au sol (anneau lumineux + petit écran « vue des pieds » sur la console), pousser = pied levé, relâcher = pied posé, IK 2 os, bassin qui suit les pieds, recul et pivot (pas chassé). Remplace le mouvement de test
  - [ ] M7.2 — Équilibre : centre de gravité réel comparé à la zone d'appui des pieds, le robot penche (ressenti dans la cabine) jusqu'au point de non-retour
  - [ ] M7.3 — Chute ragdoll : os physiques activés sur l'hôte, pose synchronisée, effondrement mou ; les nains dégringolent dans la cabine (gravité du monde au-delà d'une certaine inclinaison)
  - [ ] M7.4 — Panneaux muraux + antisèches : boutons et leviers (système M3) sur les murs du ventre, système de **séquences à deux** validé par l'hôte (ordre + rôle gauche/droite), combinaisons fixes gravées sur les murs, actions s'accroupir / se relever
  - [ ] M7.5 — Se relever : la séquence de redémarrage fige la physique, transition de la pose ragdoll vers une animation `get_up`, puis retour du contrôle
  - [ ] M7.6 — Saut directionnel hybride : un joueur maintient la direction au joystick pendant que la séquence murale est exécutée, trajectoire calculée par l'hôte, réception déséquilibrée = chute
- [ ] M8 — Foreuse : levier de profondeur + bouton miner déjà en place (console de la tête), bras qui **s'étend en animation** jusqu'à 3 m, mèche qui tourne, minage des éléments minables (premiers blocs minables dans un niveau de test, avec une animation de destruction)
- [ ] M9 — Grappin : poste assis avec écran et vue caméra déjà en place (station `Seat`) ; reste l'animation `sit`, la caméra portée par le bras, **bras et pince animés**, attraper un objet
- [ ] M10 — Inventaire : gros sac à dos dans le dos du robot, les objets attrapés y vont automatiquement, avec une **animation de rangement** (le bras dépose l'objet, le sac s'ouvre). Modèle + stockage synchronisé
- [ ] M11 — Expérimentations et réglages game design (parcours A → B, difficulté, sensations)
