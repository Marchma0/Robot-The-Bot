# CLAUDE.md — Projet "Mécha à Nains" (nom provisoire)

## Le projet en 3 lignes
Jeu coop 3D à 4 joueurs en P2P via Steam. Quatre nains pilotent un mécha **depuis l'intérieur** :
ils se déplacent physiquement dans le cockpit et interagissent avec des postes/panneaux pour faire bouger le mécha.
Objectif de base : amener le mécha d'un point A à un point B. Le game design est **en exploration** (voir `docs/ideas.md`, rien n'y est validé).

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
addons/            # plugins tiers (GodotSteam, etc.) — ne pas modifier
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

## Usage des MCP
- **MCP Godot** : utiliser pour lancer le projet, lire les erreurs/sorties du debugger, inspecter l'arborescence des scènes. Après toute modification de script, **lancer le jeu et vérifier la sortie** avant de dire que c'est fini.
- **MCP Blender** : Blender doit être ouvert avec l'addon connecté. Si la connexion échoue, le dire au lieu d'improviser.
- Les fichiers `.tscn` / `.tres` sont du texte : on peut les éditer à la main, mais avec prudence (ids `ExtResource`/`SubResource` cohérents). Pour les scènes complexes, préférer passer par le MCP ou demander à l'utilisateur de le faire dans l'éditeur.

## Ce qu'il ne faut PAS faire
- Ne jamais toucher à `.godot/`, aux fichiers `*.import`, ni à `addons/` (sauf demande explicite).
- Ne pas ajouter de plugin/addon sans demander.
- Ne pas implémenter une idée de `docs/ideas.md` sans que je l'aie validée.
- Ne pas faire de gros refactors non demandés. Petits pas, testables.
- Pas de dépendance à Steam dans le gameplay (le jeu doit tourner en ENet local).

## Façon de travailler
1. Pour toute feature : proposer un plan court (fichiers touchés, nœuds créés, impact réseau) → je valide → implémentation.
2. Prototyper chaque mécanique dans une scène isolée `tests/sandbox_<feature>.tscn` avant de l'intégrer.
3. Tester le multi en local : Godot → Debug → *Customize Run Instances* → 2 à 4 instances (une hôte, les autres clients).
4. Après chaque étape qui marche : proposer un message de commit git clair.
5. Noter les décisions importantes dans `docs/decisions.md`.

## Roadmap (prototype)
- [ ] M0 — Projet, Input Map, NetworkManager ENet (host/join local), spawn de 4 nains
- [ ] M1 — Nain contrôlable (CharacterBody3D) dans un cockpit qui bouge
- [ ] M2 — Système d'interaction : prendre/lâcher un poste
- [ ] M3 — Mécha blockout qui se déplace (version simple, sans IK)
- [ ] M4 — Expérimentations game design (jambes, IK, équilibre…)
- [ ] M5 — Bascule sur Steam (GodotSteam, lobby, invitations)
