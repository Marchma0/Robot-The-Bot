# AGENTS.md — Projet "Robot-The-Bot"

> **Source unique des consignes pour toutes les IA du projet** (Claude Code, Antigravity…). `CLAUDE.md` et `.agent/rules/` ne font que renvoyer ici.
> Deux développeurs, chacun avec son IA : le dépôt git est leur seule mémoire commune. Lire « Travail à deux ».

## Le projet
Jeu coop 3D à 4 joueurs en P2P via Steam. Quatre nains pilotent un robot géant **depuis l'intérieur** (joysticks des jambes, postes des bras…).
Boucle : **base souterraine** (lobby) → **une des 10 missions** → retour à la base. **Avant de toucher au gameplay, lire `docs/jeu.md`.**

## Les documents
| Fichier | Contenu |
|---|---|
| `docs/roadmap.md` | tâches en cours, faites, à faire, bugs connus |
| `docs/jeu.md` | description **validée** du jeu (à mettre à jour quand une décision change le jeu) |
| `docs/decisions.md` | journal des décisions en vigueur (date - décision - raison), écrit dans le commit du code |
| `docs/ideas.md` | idées **non validées** (jamais implémentées sans accord d'un humain) |
| `docs/reseau.md` | modèle réseau et recettes de synchro : **à lire avant toute interaction, objet ou niveau** |
| `docs/modeles_3d.md` | direction artistique : à lire avant de modéliser ou d'éclairer |
| `docs/tests.md` | tests, test du multi, export |
| `README.md` / `addons/ADDONS.txt` | installation / addons requis |

## Stack
- **Godot 4.7.2**, **GDScript uniquement**, physique **Jolt**. 3D : Blender → `.glb` dans `assets/models/`.
- Réseau : `MultiplayerAPI` haut niveau (RPC, `MultiplayerSpawner`, `MultiplayerSynchronizer`). ENet en dev, `SteamMultiplayerPeer` (GodotSteam, App ID 480) en prod.
  Le choix du peer est isolé dans `scripts/network/network_manager.gd` : **aucun autre code ne dépend de Steam** (le jeu doit tourner en ENet local).

## Réseau — règles NON négociables
1. **Hôte autoritaire** (peer 1) : seul l'hôte simule le mécha. Les clients envoient des **inputs**, jamais des positions du mécha.
2. Chaque joueur a l'autorité sur le déplacement de **son** nain ; l'hôte valide les interactions.
3. Interactions : RPC `@rpc("any_peer", "call_local", "reliable")` vers l'hôte, qui vérifie puis applique. Inputs continus : `"unreliable_ordered"`.
4. **Ce que l'un fait, tous le voient** : penser la synchro avant de coder (si ce n'est pas clair, demander), tester avec un hôte et un client.
5. Le cockpit est dans le repère du mécha : les nains en sont enfants.

## Conventions GDScript
- Typage statique partout. `snake_case` (fichiers, variables, fonctions), `PascalCase` (`class_name`, nœuds).
- Un script = une responsabilité ; composition plutôt qu'héritage ; signaux plutôt que références directes ; `@export` ou `%NomUnique`, jamais `get_node("../../..")`.
- Ordre : `class_name`, `extends`, signaux, enums, constantes, `@export`, variables, `_ready`, `_physics_process`, méthodes publiques, privées (`_prefixe`).
- Gameplay physique dans `_physics_process`. Touches dans la Input Map (clavier + manette), jamais en dur.
- **Textes visibles** : `tr("texte en français")` + une ligne dans `assets/translations/texts.csv` (`keys,fr,en`). Textes de debug en français, sans `tr()`.

## 3D
- Style et couleurs : `docs/modeles_3d.md` et `prop_kit.PALETTE`. Un modèle = un script Python dans `blender/` (le script fait foi), exporté par `kit.save_and_export`.
- 1 unité = 1 m ; l'avant regarde vers +Y dans Blender (-Z dans Godot) ; ne jamais éditer un `.glb` dans Godot.
- Tout ce qui bouge est animé ; on synchronise l'**état**, chaque joueur joue l'animation chez lui.

## Façon de travailler
1. Toute feature : plan court (fichiers, nœuds, impact réseau) → validation de l'humain → petits pas testables. Pas de gros refactor non demandé.
2. Prototyper dans `tests/sandbox_<feature>.tscn`, qui vérifie son résultat avec `TestCheck`. Avant de fusionner une branche qui touche au code : `sh tests/tools/run_tests.sh` → `TOUS LES TESTS OK` (détail : `docs/tests.md`).
3. Après une modification de script : lancer le jeu (MCP Godot) et lire la sortie avant de dire que c'est fini.
4. Noter les décisions dans `docs/decisions.md` ; si elles changent le jeu, mettre à jour `docs/jeu.md`.
5. MCP Blender : s'il ne répond pas, le dire au lieu d'improviser. `.tscn` / `.tres` s'éditent à la main avec prudence (ids cohérents).

## Interdits
- Toucher à `.godot/`, aux `*.import` ou à `addons/` (sauf demande). Ajouter un addon sans demander (et sans l'inscrire dans `addons/ADDONS.txt`).
- Commiter sur `main`, `git push --force`, rebase d'une branche déjà poussée.
- Mettre un chemin propre à une machine dans un fichier versionné (utiliser `GODOT_PATH` ou un fichier ignoré).

## Travail à deux (Claude Code : `Marchma0`, Antigravity : `massyl12`)
**Début de session** : `git pull` sur `main`, relire `docs/roadmap.md` et les dernières entrées de `docs/decisions.md`.
**Avant une tâche** : la marquer `[en cours — pseudo]` dans la roadmap et pousser tout de suite ; ne pas prendre une tâche marquée par l'autre sans lui en parler.

**Procédure git** (ce sont les IA qui commitent, pas de Pull Request) :
```
git status                       # propre, sinon demander
git switch main && git pull
git switch -c pseudo/sujet       # une branche courte par tâche
# commits petits, git add fichier par fichier, messages en français au présent ; git push -u origin pseudo/sujet
# récupérer le travail de l'autre : git pull origin main (merge)
```
**Finir** (quand l'humain dit que c'est bon) :
```
git pull origin main             # régler les conflits, relancer le jeu
git switch main && git pull
git merge --no-ff pseudo/sujet   # conflit = s'arrêter et demander
git push                         # refusé ? git pull puis git push
git push origin --delete pseudo/sujet && git branch -d pseudo/sujet
```
- Conflit sur un binaire (`.blend`, `.glb`, image, son) ou une `.tscn` peu claire : demander à l'humain. Un seul développeur modifie un binaire à la fois (prévenir l'autre).
- Éviter de modifier la même scène en parallèle ; changements de `project.godot` petits et signalés à l'autre.
- Changer de branche avec l'éditeur Godot ouvert : le fermer avant, ou recharger le projet après.
