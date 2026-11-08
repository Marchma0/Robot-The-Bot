# AGENTS.md — Projet "Robot-The-Bot"

> **Source unique des consignes pour toutes les IA du projet** (Claude Code, Antigravity, etc.).
> `CLAUDE.md` et `.agent/rules/` ne font que renvoyer ici : on modifie **uniquement ce fichier**.
> Deux développeurs travaillent sur le projet, chacun avec sa propre IA : lire la section « Travail à deux » avant toute chose.

## Le projet en 3 lignes
Jeu coop 3D à 4 joueurs en P2P via Steam. Quatre nains pilotent un robot géant **depuis l'intérieur** :
ils se déplacent dans le cockpit et manipulent des commandes physiques (joysticks des jambes, postes des bras…).
Boucle : **camp de base** (lobby : mini-jeux, marchands de skins et d'améliorations) → **une des 10 missions** de l'histoire,
chacune avec son environnement et sa propre idée de gameplay → retour au camp.

**Avant de toucher au gameplay, lire `docs/jeu.md`** (tout ce qui est validé : boucle, camp, missions, robot, nains).

## Les documents du projet
| Fichier | Contenu | Quand l'écrire |
|---|---|---|
| `AGENTS.md` | règles, conventions, procédure git, **roadmap** | règle qui change, tâche commencée ou finie |
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
```
project.godot
addons/            # plugins tiers (GodotSteam, etc.) — ne pas modifier, NON versionnés : liste + installation dans addons/ADDONS.txt
assets/
  models/          # .glb exportés depuis Blender
  textures/ audio/ fonts/
  translations/    # texts.csv : tous les textes du jeu, français + anglais
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
docs/              # jeu.md, decisions.md, ideas.md, reseau.md (voir « Les documents du projet »)
tests/             # scènes de test isolées (sandbox_*.tscn), outils de test (tests/tools/)
```

## Architecture réseau — règles NON négociables
1. **Hôte autoritaire** : seul l'hôte (peer id 1) simule la physique du mécha. Les clients envoient leurs **inputs**, jamais des positions du mécha.
2. Les nains : chaque joueur a l'autorité sur le déplacement de **son** nain (`set_multiplayer_authority(peer_id)`), l'hôte valide les interactions avec les stations.
3. Les interactions (prendre un poste, appuyer sur un bouton) passent par des RPC `@rpc("any_peer", "call_local", "reliable")` vers l'hôte, qui vérifie puis applique.
4. Les inputs continus (joystick) : `"unreliable_ordered"`.
5. Tout nouveau système doit être pensé "comment ça se synchronise ?" **avant** d'être codé. Si ce n'est pas clair, demander.
   **Toute interaction doit être synchronisée avec tous les joueurs** (ce que l'un fait, tous le voient), et testée en multi (hôte + au moins un client) avant d'être considérée comme finie.
6. Le cockpit est dans un repère **local au mécha** : les nains sont enfants du mécha (ou d'un nœud qui le suit), pour ne pas glisser quand il bouge.
7. **Modèle réseau détaillé dans `docs/reseau.md`** (à lire avant toute interaction, objet ou niveau). En bref : un état qui dure = une variable dans un `MultiplayerSynchronizer` avec `spawn = true` ; un effet d'un instant = RPC `authority, call_local` de l'hôte ; un objet qui apparaît ou disparaît en jeu = créé par l'hôte sous un `NetSpawner` (place réglée **avant** `add_child`) ; un niveau = créé par l'hôte via le `LevelSpawner` de `MissionDirector`, jamais chargé par chaque joueur ; un `RigidBody3D` figé = `FREEZE_MODE_STATIC`.
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
   blender -b blender/<fichier>.blend --python blender/tools/render_views.py -- --out build/views/<nom>.png [--target Objet,Collection]
   ```
   6 vues à la même échelle (avant, droite, arrière, gauche, dessus, 3/4), grille au sol de 1 m, dimensions affichées dans la console.
   Avec le MCP Blender ouvert, on peut aussi exécuter le fichier dans Blender puis appeler `render_views(out=..., target=[...])`.
   Le fichier `.blend` doit être **sauvegardé** avant la version en ligne de commande (elle lit le fichier sur le disque).
3. **Comparer** la planche à la demande (proportions, pièces qui flottent, arrière, symétrie, échelle), **corriger au moins une fois**, régénérer.
4. Montrer la dernière planche à l'humain avant d'exporter le `.glb`. Les planches vont dans `build/views/` (non versionné).

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
- **Nains** : squelette (armature) fait dans Blender, animations exportées dans le `.glb` (actions nommées : `idle`, `walk`, `jump`, `float`, `climb`, `grab`, `press`, `sit`, `crouch`, `crouch_walk`, `poop`, `throw`, `hit`, `emote_*`…), jouées dans Godot via un `AnimationTree`.
- **Robot** : les jambes et les bras sont animés **à partir de l'état simulé par l'hôte** (angles des articulations, extension de la foreuse…). Ce sont des animations procédurales ou des blend d'actions Blender, jamais des positions inventées côté client.
- **Réseau** : on synchronise l'**état** (vitesse, au sol, tient un levier, assis, glisse…), jamais l'animation elle-même. Chaque peer joue l'animation correspondante localement.

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
2. Prototyper chaque mécanique dans une scène isolée `tests/sandbox_<feature>.tscn` avant de l'intégrer. Une scène scriptée vérifie elle-même son résultat avec `TestCheck` (`tests/tools/test_check.gd` : `expect`, `finish`, captures ignorées sans fenêtre).
   **Tous les tests d'un coup** (scènes de test + test réseau, sans fenêtre) : `sh tests/tools/run_tests.sh` → `TOUS LES TESTS OK`, à lancer avant de fusionner une branche qui touche au code.
3. Tester le multi en local : Godot → Debug → *Customize Run Instances* → 2 à 4 instances (une hôte, les autres clients).
   - À distance : exporter l'exe (`Godot --headless --path . --export-release "Windows Desktop" build/windows/Robot-The-Bot.exe`, puis copier `steam_appid.txt` à côté), envoyer le dossier `build/windows/` zippé, et passer par Steam (lobby / invitation) ou par un VPN type Tailscale en mode local.
   - Les deux joueurs doivent avoir **exactement la même version** (même commit de `main`, ou le même `.exe` exporté), sinon la synchro casse.
4. Après chaque étape qui marche : proposer un message de commit git clair.
5. Noter les décisions importantes dans `docs/decisions.md` et, si elles changent le jeu, mettre à jour `docs/jeu.md`.

## Travail à deux (deux humains, deux IA)
Deux développeurs, chacun avec son IA (Claude Code, Antigravity). Les IA ne se parlent pas : **le dépôt git est leur seule mémoire commune**.

**Début de session (obligatoire)**
1. `git pull` sur `main`, puis créer ou mettre à jour sa branche.
2. Relire la roadmap ci-dessous et les dernières entrées de `docs/decisions.md` : l'autre a peut-être changé quelque chose depuis.

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

> Rangée par **phases** dans l'ordre où le jeu se construit ; on peut avancer deux phases en parallèle (une par développeur).
> Avant de commencer une tâche : la marquer `[en cours — pseudo]` et pousser tout de suite. La cocher quand elle est fusionnée dans `main`.
> Les codes entre parenthèses (M7, M12, S1…) sont les anciens numéros, encore cités dans le code et dans `docs/decisions.md`.

**En cours** : 1.4 Synchro de toutes les interactions (Marchma0, priorité) · 3.4 Marche du robot (Marchma0)

### Phase 1 — Fondations (moteur, réseau, outils)
- [x] 1.1 Projet Godot, Input Map clavier + manette, `NetworkManager` ENet (héberger / rejoindre en local), 4 nains (M0)
- [x] 1.2 Synchro lissée : lissage des autres joueurs et du robot, `physics_interpolation`, moins de trafic, ordre de calcul fixe (M6.6)
- [x] 1.3 Interface en icônes « touche → action », police Fredoka, plus de texte d'aide brut (M6.6)
- [ ] 1.4 **Synchro de toutes les interactions** (S1) `[en cours — Marchma0]` : chaque joueur voit exactement la même chose, y compris celui qui arrive en cours de partie
  - [x] Modèle réseau général (2026-11-08) : niveau créé par l'hôte (`LevelSpawner`), objets sous `NetSpawner`, cacas et caisses en `FREEZE_MODE_STATIC`, garde-fous (`net_test.sh`, F9, `NetGuard`), `docs/reseau.md`. Test auto vert sur toutes les interactions existantes
  - [ ] À confirmer en vraie partie Steam (hôte + client, F9 pour comparer)
- [ ] 1.5 Steam (M5) : GodotSteam (App ID 480), lobby, invitation ou code de lobby, export Windows `.exe` pour les testeurs — en place, reste à valider à distance (avec 1.4)
- [x] 1.6 Pipeline 3D : un script Python par objet (`blender/props/`), palette partagée, planche de vues, refus des faces superposées, captures `interior_shots` (M6.7)
- [x] 1.7 **Rationalisation du code** (2026-11-08) : rendre le code prêt pour le camp et les missions, sans rien changer en jeu (test réseau vert à chaque étape)
  - [x] Ménage (2026-11-08) : une seule façon de retrouver le nain d'un joueur (`Dwarf.of_peer`) et son nom (« Joueur N » partout), petites bidouilles retirées, pieds du robot typés, scènes de test obsolètes supprimées, vérifications automatiques + `tests/tools/run_tests.sh`. Le script à la racine du robot attend les skins du robot (3.8)
  - [x] Système d'interaction (2026-11-08) : chaque commande gère son utilisation (`Interactable.interact`), l'Interactor n'a plus de liste de types ; l'hôte refuse qu'un joueur tienne ou occupe deux choses à la fois (`Possession`) ; le test réseau vérifie vraiment que chaque demande a un effet
  - [x] Nain découpé (2026-11-08) : apparence (`DwarfLook`, où iront les skins), caméra (`DwarfCamera`), corde (`DwarfClimb`) ; interface du joueur dans `scenes/ui/player_hud.tscn`, créée seulement pour le joueur local ; `dwarf.gd` passe de 780 à 590 lignes
  - [x] Base commune des bras (2026-11-08) : `MechaArm` (visée depuis le poste, limites, caméra, remise à zéro), `DrillArm` et `GrabberArm` n'ont plus que leur outil
  - [x] Traduction (2026-11-08) : textes visibles passés par `tr()`, tableau `assets/translations/texts.csv` (54 textes, fr + en), le jeu suit la langue du système (menu de langue : 6.2), vérification dans `run_tests.sh`
  - [x] Dette de `mecha.blend` (2026-11-08, avancé avant 3.4 à la demande du porteur du projet) : le modèle du robot n'a plus que sa coque ; anciens bras et anciennes consoles retirés par `mecha_shell.py` (`MechaArmUtils.strip_*` supprimé) ; décor refait en 20 objets améliorés (`blender/props/`) placés dans `belly.tscn` / `head.tscn` et dans le rayon tracteur ; collisions des meubles sorties de la coque vers les scènes des objets

### Phase 2 — Les nains
- [x] 2.1 Nain contrôlable dans un cockpit qui bouge, vue à la première personne (M1)
- [x] 2.2 Squelette et animations (`idle`, `walk`, `jump`, `grab`, `press`, `sit`…), `AnimationTree`, état synchronisé (M4)
- [x] 2.3 Emotes (roue de 8), corps visible en première personne, bulle d'état avec portrait, s'accroupir (M6.5)
- [ ] 2.4 Skins des nains : pièces interchangeables (barbe, casque, couleurs…), choix synchronisé et sauvegardé — vendus en 4.5
- [ ] 2.5 Améliorations des nains : liste à définir avec le porteur du projet (pistes dans `docs/ideas.md`) — vendues en 4.6

### Phase 3 — Le robot
- [x] 3.1 Modèle low poly (ventre + tête), postes, système d'interaction (boutons, leviers, joysticks toujours actifs) (M2, M3)
- [x] 3.2 Circulation : rayon tracteur, trappe, corde, nain dehors (M6)
- [x] 3.3 Intérieur modulaire et vie à bord : coque en tôle, salon, canapé, télé, toilettes et mini-jeu « Poussée », cacas, caca doré (M6.5, M6.7)
- [ ] 3.4 **Marche** (M7) `[en cours — Marchma0]` — pendant 3.4, ne pas toucher à `blender/mecha.blend`, `assets/models/mecha.glb` ni aux jambes
  - [x] Squelette, IK 2 os, marche en rythme, voyant « à toi », élan du robot, ressenti des joysticks (M7.1)
  - [x] Jauge d'erreur, effondrement à genoux, QTE de relèvement à tour de rôle, système de QTE générique (M7.2)
  - [ ] Panneaux muraux : boutons et leviers sur les murs du ventre, combinaisons à deux gravées sur les murs (s'accroupir, se relever…) (M7.4)
  - [ ] Saut directionnel : direction tenue au joystick pendant la combinaison, trajectoire calculée par l'hôte, réception ratée = jauge d'erreur ou chute (M7.5)
- [x] 3.5 Foreuse : bras qui s'étend jusqu'à 3 m, mèche, minage des rochers, caisse de minerai (M8)
- [x] 3.6 Grappin : pince articulée, caméra sur le bras, lancer au bout d'un câble ; postes assis des deux bras, image brouillée, bras bornés hors de la coque (M9, M9.5)
- [x] 3.7 Sac à dos : rangement automatique animé, contenu synchronisé (M10)
- [ ] 3.8 Skins du robot : peinture, décorations, choix synchronisé et sauvegardé — vendus en 4.5

### Phase 4 — Le camp de base (lobby)
- [x] 4.1 Camp minier dans un canyon, robot au centre, terminal de mission (flèches + bouton), retour au camp (M12, M12.1)
- [x] 4.2 Mini-jeux : fléchettes, bras de fer (M12.1)
- [ ] 4.3 Monnaie et sauvegarde de la partie (économie reportée par le porteur du projet le 2026-11-08) : fiches de données (objets, missions, skins en `.tres`), `GameState` tenu par l'hôte, sauvegarde **chez l'hôte** (validé) ; argent par nain ou commun : à décider
- [ ] 4.4 Plus de mini-jeux (les wagonnets sont déjà en décor ; pistes dans `docs/ideas.md`)
- [ ] 4.5 Marchands de skins : un pour les nains (2.4), un pour le robot (3.8)
- [ ] 4.6 Marchand d'améliorations des nains (2.5)

### Phase 5 — Les missions
- [x] 5.1 Cadre : `MissionDirector`, niveau créé par l'hôte, mission de test (rochers, caisses) (M12, S1)
- [ ] 5.2 Mission prototype A → B : régler le ressenti, la difficulté et la durée sur un vrai parcours (M11)
- [ ] 5.3 Cadre commun d'une mission : objectifs, réussie / ratée, récompenses, retour au camp (lié à 4.3) ; chaque mission le remplit à sa façon
- [ ] 5.4 Histoire : le fil rouge des 10 missions, et la mécanique phare de chacune (à valider avec le porteur du projet)
- [ ] 5.5 Les 10 missions, une par une (une ligne par mission ici une fois 5.4 validé) : environnement + mécanique propre + histoire

### Phase 6 — Finitions
- [ ] 6.1 Son et musique
- [ ] 6.2 Menus et options (touches, son, graphismes)
- [ ] 6.3 Passe graphique : effets et couleurs créés dans le code (étincelles, éclats, câble…) passés en scènes et dans la palette
- [ ] 6.4 Version à distribuer sur Steam (français et anglais)
