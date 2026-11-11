# AGENTS.md — Projet "Robot-The-Bot"

> **Source unique des consignes pour toutes les IA du projet** (Claude Code, Antigravity, etc.).
> `CLAUDE.md` et `.agent/rules/` ne font que renvoyer ici : une règle du projet s'écrit ici ou dans un fichier de `docs/` que ce fichier désigne, jamais ailleurs.
> Deux développeurs travaillent sur le projet, chacun avec sa propre IA : lire la section « Travail à deux » avant toute chose.

## Le projet en 3 lignes
Jeu coop 3D à 4 joueurs en P2P via Steam. Quatre nains pilotent un robot géant **depuis l'intérieur** :
ils se déplacent dans le cockpit et manipulent des commandes physiques (joysticks des jambes, postes des bras…).
Boucle : **base souterraine** (lobby : mini-jeux, postes de personnalisation, poste des missions, améliorations) → **une des 10 missions** de l'histoire,
chacune avec son environnement et sa propre idée de gameplay → retour au camp.

**Avant de toucher au gameplay, lire `docs/jeu.md`** (tout ce qui est validé : boucle, camp, missions, robot, nains).

## Les documents du projet
| Fichier | Contenu | Quand l'écrire |
|---|---|---|
| `AGENTS.md` | règles, conventions, procédure git | règle qui change |
| `docs/roadmap.md` | tâches en cours, faites, à faire, bugs connus | tâche commencée ou finie |
| `docs/modeles_3d.md` | direction artistique, Blender → Godot, animation | modèle 3D, animation, nouveau niveau |
| `docs/tests.md` | tests automatiques, test du multi, export | scène ou outil de test |
| `docs/jeu.md` | description **validée** du jeu | dès qu'une décision change le jeu |
| `docs/decisions.md` | journal des décisions (date - décision - raison) | à chaque décision, dans le commit du code |
| `docs/ideas.md` | idées **non validées**, rangées par phase | idée proposée, pas encore choisie |
| `docs/reseau.md` | modèle réseau et recettes de synchro | avant toute interaction, objet ou niveau |
| `README.md` | installation pour un nouveau développeur | outil ou étape d'installation qui change |
| `addons/ADDONS.txt` | addons requis (version, source, installation) | à chaque addon ajouté |

## Stack
- **Moteur** : Godot 4.7.x, **GDScript uniquement** (pas de C#), physique 3D **Jolt**.
- **3D** : Blender → export **glTF binaire (.glb)** dans `assets/models/`.
- **Réseau** : `MultiplayerAPI` haut niveau de Godot (RPC, `MultiplayerSpawner`, `MultiplayerSynchronizer`).
  - En dev : `ENetMultiplayerPeer` en local (plusieurs instances).
  - En prod : `SteamMultiplayerPeer` via **GodotSteam** (GDExtension), App ID de test 480.
  - Le choix du peer est isolé dans `scripts/network/network_manager.gd` : le reste du code ne doit JAMAIS dépendre de Steam directement.
- **Outils IA** : Claude Code (Marchma0) et Antigravity (massyl12), chacun avec MCP Godot + MCP Blender.

## Arborescence
Dossiers : `scenes/` et `scripts/` (main, mecha, player, levels, network, interaction, props), `assets/models/` (.glb), `blender/` (scripts et .blend), `tests/`, `docs/` ; `addons/` n'est pas versionné (voir `addons/ADDONS.txt`). Arborescence détaillée dans `README.md`.

## Architecture réseau — règles NON négociables
1. **Hôte autoritaire** : seul l'hôte (peer id 1) simule la physique du mécha. Les clients envoient leurs **inputs**, jamais des positions du mécha.
2. Les nains : chaque joueur a l'autorité sur le déplacement de **son** nain (`set_multiplayer_authority(peer_id)`), l'hôte valide les interactions avec les stations.
3. Les interactions (prendre un poste, appuyer sur un bouton) passent par des RPC `@rpc("any_peer", "call_local", "reliable")` vers l'hôte, qui vérifie puis applique.
4. Les inputs continus (joystick) : `"unreliable_ordered"`.
5. Tout nouveau système doit être pensé "comment ça se synchronise ?" **avant** d'être codé. Si ce n'est pas clair, demander.
   **Toute interaction doit être synchronisée avec tous les joueurs** (ce que l'un fait, tous le voient), et testée en multi (hôte + au moins un client) avant d'être considérée comme finie.
6. Le cockpit est dans un repère **local au mécha** : les nains sont enfants du mécha (ou d'un nœud qui le suit), pour ne pas glisser quand il bouge.
7. Recettes (état qui dure, effet d'un instant, objet qui apparaît, niveau, objet figé) : **lire `docs/reseau.md` avant toute interaction, objet ou niveau**.
8. **Test réseau automatique** : `sh tests/tools/net_test.sh` (hôte + client sans fenêtre, compare ce que chacun voit) doit afficher `NET TEST OK` avant de fusionner une branche qui touche au réseau, aux objets ou aux interactions. Chaque nouvelle interaction ajoute son étape dans `tests/tools/net_test.gd`. En vraie partie (Steam compris), **F9** compare l'état du client à celui de l'hôte.

## Conventions GDScript
- **Typage statique partout** (`var speed: float = 3.0`, `func foo(x: int) -> void`).
- `snake_case` pour fichiers/variables/fonctions, `PascalCase` pour `class_name` et nœuds.
- Un script = une responsabilité. Préférer composition (nœuds enfants) à l'héritage profond.
- Signaux plutôt que références directes entre systèmes. Pas de `get_node("../../..")` : utiliser `@export` ou `%NomUnique`.
- Ordre dans un script : `class_name`, `extends`, signaux, enums, constantes, `@export`, variables, `_ready`, `_physics_process`, méthodes publiques, méthodes privées (`_prefixe`).
- Toute la logique de gameplay physique dans `_physics_process`, pas `_process`.
- Les inputs sont déclarés dans la Input Map (`project.godot`), jamais de touches codées en dur. Prévoir la manette dès le début.
- **Deux langues (français, anglais)** : tout texte visible par le joueur passe par `tr("texte en français")` (le texte français sert de clé) et a sa ligne dans `assets/translations/texts.csv` (colonnes `keys,fr,en`). Pour un texte avec des valeurs : `tr("Joueur %d") % n`. Les boutons et étiquettes des scènes sont traduits tout seuls, mais leur texte doit aussi être dans le tableau. `run_tests.sh` vérifie qu'aucun texte n'est oublié. Les textes de debug restent en français.

## Modèles 3D et animation (détail dans `docs/modeles_3d.md`, à lire avant de modéliser ou d'animer)
- Direction artistique **low poly** : facettes visibles (ombrage plat), robot « cosy mais pas trop » (métal peint, chanfreins, rivets, cuivre), couleurs de `prop_kit.PALETTE`.
- Modèles **construits par script Python** (le script fait foi). Planche de vues obligatoire, montrée à l'humain avant d'exporter le `.glb`. L'export passe par `kit.save_and_export`, qui contrôle le modèle et le `.glb` (PASS / FAIL).
- 1 unité = 1 m ; l'avant d'un modèle regarde vers **+Y** dans Blender (-Z dans Godot) ; ne jamais éditer un `.glb` dans Godot.
- **Tout ce qui bouge est animé** (rien ne glisse ni ne se téléporte). On synchronise l'**état**, chaque joueur joue l'animation chez lui.

## Usage des MCP
- **MCP Godot** : utiliser pour lancer le projet, lire les erreurs/sorties du debugger, inspecter l'arborescence des scènes. Après toute modification de script, **lancer le jeu et vérifier la sortie** avant de dire que c'est fini.
- **MCP Blender** : Blender doit être ouvert avec l'addon connecté. Si la connexion échoue, le dire au lieu d'improviser.
- Les fichiers `.tscn` / `.tres` sont du texte : on peut les éditer à la main, mais avec prudence (ids `ExtResource`/`SubResource` cohérents). Pour les scènes complexes, préférer passer par le MCP ou demander à l'utilisateur de le faire dans l'éditeur.

## Ce qu'il ne faut PAS faire
- Ne jamais toucher à `.godot/`, aux fichiers `*.import`, ni à `addons/` (sauf demande explicite).
- Ne pas ajouter de plugin/addon sans demander. Tout addon ajouté doit être inscrit dans `addons/ADDONS.txt` (version, source, dossier, rôle, installation).
- Ne pas implémenter une idée de `docs/ideas.md` sans qu'elle ait été validée par un humain.
- Ne jamais commiter directement sur `main` (on y fusionne seulement une branche terminée), ni faire `git push --force`.
- Ne pas faire de gros refactors non demandés. Petits pas, testables.
- Pas de dépendance à Steam dans le gameplay (le jeu doit tourner en ENet local).

## Façon de travailler
1. Pour toute feature : proposer un plan court (fichiers touchés, nœuds créés, impact réseau) → l'humain valide → implémentation.
2. Prototyper chaque mécanique dans `tests/sandbox_<feature>.tscn`, qui vérifie son résultat avec `TestCheck`. Avant de fusionner une branche qui touche au code : `sh tests/tools/run_tests.sh` → `TOUS LES TESTS OK`. Pendant le travail, ne lancer que les tests de la tâche. Une scène de test attend en temps de jeu, jamais en temps réel. Détail (options, test du multi, export) : `docs/tests.md`.
3. Après chaque étape qui marche : proposer un message de commit git clair.
4. Noter les décisions importantes dans `docs/decisions.md` et, si elles changent le jeu, mettre à jour `docs/jeu.md`.

## Travail à deux (deux humains, deux IA)
Deux développeurs, chacun avec son IA (Claude Code, Antigravity). Les IA ne se parlent pas : **le dépôt git est leur seule mémoire commune**.

**Début de session (obligatoire)**
1. `git pull` sur `main`, puis créer ou mettre à jour sa branche.
2. Relire `docs/roadmap.md` et les dernières entrées de `docs/decisions.md` : l'autre a peut-être changé quelque chose depuis.

**Où écrire quoi** : voir le tableau « Les documents du projet » en haut. Ne jamais mettre une règle ou une info du projet dans la mémoire privée de son IA, ni dans `CLAUDE.md` ou `.agent/rules/` : l'autre IA ne la verrait pas.

**Qui fait quoi**
- Avant de commencer un jalon ou une tâche, l'indiquer dans la roadmap avec le pseudo GitHub (ex. `[en cours — Marchma0]`) et pousser ce changement tout de suite, pour que l'autre le voie.
- Ne pas travailler sur une tâche marquée par l'autre sans lui en parler.

**Branches et commits — procédure git (ce sont les IA qui font les commits et les push : suivre ces étapes à la lettre)**
- `main` = toujours une version qui se lance. **Aucun commit directement sur `main`.**
- **Pas de Pull Request, pas d'interface GitHub** : les humains ne passent pas par GitHub, c'est l'IA qui fusionne elle-même sa branche dans `main` et pousse (étape « Finir une tâche »).
- Une branche **courte** par tâche (quelques jours au plus), nommée avec le **pseudo GitHub** de l'humain : `pseudo/sujet` (ex. `Marchma0/m7-jambes`). Pseudos connus : `Marchma0` (Claude Code) ; `massyl12` (Antigravity).
- Commencer une tâche :
  ```
  git status                      # doit être propre, sinon demander à l'humain quoi faire
  git switch main
  git pull
  git switch -c pseudo/sujet
  ```
- Pendant la tâche : commits petits et fréquents, `git add` **fichier par fichier** (relire `git status` avant, ne jamais ajouter `.godot/`, `addons/`, `build/`), puis `git push -u origin pseudo/sujet`.
- Récupérer le travail de l'autre dans sa branche : `git pull origin main` (**merge, jamais de rebase** sur une branche déjà poussée → donc jamais besoin de `--force`).
- Finir une tâche (quand l'humain dit que c'est bon) :
  ```
  git pull origin main            # dans sa branche : récupérer le travail de l'autre, régler les conflits
  # relancer le jeu et vérifier la sortie : main doit toujours se lancer
  git switch main
  git pull
  git merge --no-ff pseudo/sujet  # ne doit plus y avoir de conflit, sinon s'arrêter et demander
  git push
  git push origin --delete pseudo/sujet   # la branche distante d'abord, sinon -d refuse
  git branch -d pseudo/sujet
  ```
  Si `git push` sur `main` est refusé (l'autre a poussé entre-temps) : `git pull` puis `git push`, **jamais `--force`**.
- Conflit sur un fichier binaire (`.blend`, `.glb`, image, son) ou sur une `.tscn` peu claire : **ne pas trancher seul**, demander à l'humain.
- Changer de branche avec l'éditeur Godot ouvert : le fermer avant, ou recharger le projet après (sinon il réécrit les anciennes scènes).
- Messages de commit en français, au présent, qui disent ce que ça change pour le jeu (même style que l'historique).

**Fichiers qui se fusionnent mal**
- `.blend`, `.glb`, images, sons : **impossibles à fusionner**. Une seule personne les modifie à la fois : le dire à l'autre avant.
- `.tscn` / `.tres` : du texte, mais les conflits sont pénibles (ids). Éviter de modifier la même scène en parallèle ; préférer des sous-scènes séparées.
- `project.godot` (Input Map, autoloads) : modifications petites et ciblées, à signaler à l'autre humain.

**Machine de chacun**
- Godot **4.7.2** pour les deux (même version, sinon les fichiers d'import changent).
- Les chemins propres à une machine ne vont jamais dans un fichier versionné : variables d'environnement (`GODOT_PATH`) ou fichiers locaux ignorés.

## Roadmap
Dans `docs/roadmap.md` : à relire en début de session. Avant de commencer une tâche, la marquer `[en cours — pseudo]` et pousser tout de suite.
