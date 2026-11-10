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
- **Nains** : squelette (armature) fait dans Blender, animations exportées dans le `.glb` (actions nommées : `idle`, `walk`, `jump`, `float`, `climb`, `grab`, `press`, `sit`, `crouch`, `crouch_walk`, `poop`, `throw`, `hit`, `hold_low`/`hold_mid`/`hold_high`, `carry`, `emote_*`…), jouées dans Godot via un `AnimationTree`.
- **Robot** : les jambes et les bras sont animés **à partir de l'état simulé par l'hôte** (angles des articulations, extension de la foreuse…). Ce sont des animations procédurales ou des blend d'actions Blender, jamais des positions inventées côté client.
- **Réseau** : on synchronise l'**état** (vitesse, au sol, tient un levier, assis, glisse…), jamais l'animation elle-même. Chaque peer joue l'animation correspondante localement.
- **Ombres** : le décor intérieur du robot est sur le calque de rendu 2 ; le soleil d'un nouveau niveau doit avoir `shadow_caster_mask = 4294967293` (sans le calque 2), sinon les performances s'effondrent.

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
   **Tous les tests d'un coup** (scènes de test en temps accéléré et 4 à la fois, test réseau en temps réel à côté : environ 1 min 45) : `sh tests/tools/run_tests.sh` → `TOUS LES TESTS OK`, à lancer avant de fusionner une branche qui touche au code.
   **Pendant le travail, ne lancer que ce qui concerne la tâche** : `sh tests/tools/run_tests.sh walk fall` (scènes dont le nom contient ces mots), `run_tests.sh reseau` (test réseau seul), `--sans-reseau` (environ 20 s), `--lent` (temps réel, un par un, pour un souci de timing).
   Une scène de test attend en **temps de jeu** (`create_timer`), jamais en temps réel (`Time.get_ticks_msec`) : en accéléré, le temps réel ne suit pas.
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
> Une tâche finie tient en **une ligne** : le détail (comment, pourquoi) va dans `docs/decisions.md`.
> Les codes entre parenthèses (M7, M12, S1…) sont les anciens numéros, encore cités dans le code et dans `docs/decisions.md`.

**En cours** : rien pour l'instant.

**Bugs connus** (notés pour plus tard, à corriger quand le porteur du projet le demande) : aucun.

### Phase 1 — Fondations (moteur, réseau, outils)
- [x] 1.1 Projet Godot, Input Map clavier + manette, `NetworkManager` ENet, 4 nains (M0)
- [x] 1.2 Synchro lissée des joueurs et du robot, `physics_interpolation` (M6.6)
- [x] 1.3 Interface en icônes « touche → action », police Fredoka (M6.6)
- [x] 1.4 Synchro de toutes les interactions, garde-fous `net_test.sh` / F9 / `NetGuard`, `docs/reseau.md` (S1)
- [x] 1.5 Steam : GodotSteam, lobby, invitation, export Windows (M5)
- [x] 1.6 Pipeline 3D : un script Python par objet, palette, planche de vues, captures `interior_shots` (M6.7)
- [x] 1.7 Rationalisation du code : interactions génériques, nain découpé, base des bras, traduction, dette de `mecha.blend`
- [x] 1.8 Interface sobre : viseur, contour de l'objet visé, icône de l'action
- [x] 1.9 Performances (2026-11-10) : ombres allégées (+60 % d'images par seconde sur Iris Xe), rendu Vulkan

### Phase 2 — Les nains
- [x] 2.1 Nain contrôlable dans un cockpit qui bouge, première personne (M1)
- [x] 2.2 Squelette, animations, `AnimationTree`, état synchronisé (M4)
- [x] 2.3 Emotes, corps visible, bulle d'état, s'accroupir (M6.5)
- [ ] 2.4 Skins des nains : pièces interchangeables (barbe, casque, couleurs…), choix synchronisé et sauvegardé — vendus en 4.5
- [ ] 2.5 Améliorations des nains : liste à définir avec le porteur du projet (pistes dans `docs/ideas.md`) — vendues en 4.6
- [x] 2.6 Inventaire de 5 cases, caisses portées à deux mains
- [x] 2.7 Vue de son vrai corps, animations de port, angle de vue de 90°
- [ ] 2.8 **Nains garagistes** (nouvelle DA, validée le 2026-11-09) : nouveau modèle (combinaison de travail, ceinture à outils, casquette ou masque de soudeur, cambouis) sur **le même squelette** (mêmes os, mêmes noms : toutes les animations restent) ; à faire avant les skins (2.4), qui en découleront

### Phase 3 — Le robot
- [x] 3.1 Modèle low poly, postes, boutons / leviers / joysticks (M2, M3)
- [x] 3.2 Circulation : rayon tracteur, trappe, corde, nain dehors (M6)
- [x] 3.3 Intérieur modulaire et vie à bord : salon, toilettes et mini-jeu « Poussée », cacas (M6.5, M6.7)
- [x] 3.4 Marche en rythme, jauge d'erreur, chute et relèvement, saut et accroupi par QTE à deux (M7)
- [x] 3.5 Foreuse (M8)
- [x] 3.6 Grappin, postes assis des deux bras (M9, M9.5)
- [x] 3.7 Sac à dos (M10)
- [ ] 3.8 Skins du robot : peinture, décorations, choix synchronisé et sauvegardé — vendus en 4.5
- [x] 3.9 Fléchettes dans le robot
- [x] 3.10 Finitions du salon : ardoise, télé, jeu de dames, roue d'emotes
- [x] 3.11 Fléchette plantée dans un allié
- [x] 3.12 Télé : jeu « Robo-Jet »
- [x] 3.13 Finitions de pilotage (2026-11-10) : pas plus jamais perdus, vue stable au saut, caisse portée sans à-coups, QTE à étapes « Ensemble ! »

### Phase 4 — Le camp de base (lobby)
- [x] 4.1 Camp minier dans un canyon, terminal de mission, retour au camp (M12, M12.1)
- [x] 4.2 Mini-jeu : bras de fer (M12.1)
- [ ] 4.3 Monnaie et sauvegarde de la partie (économie reportée par le porteur du projet le 2026-11-08) : fiches de données (objets, missions, skins en `.tres`), `GameState` tenu par l'hôte, sauvegarde **chez l'hôte** (validé) ; argent par nain ou commun : à décider
- [ ] 4.4 Plus de mini-jeux de garage : course de chariots de mécano, lancer de nain dans un pneu, wagonnets sur les rails, bras de fer déplacé sur l'établi (autres pistes dans `docs/ideas.md`)
- [ ] 4.5 Marchands de skins : un pour les nains (2.4), un pour le robot (3.8)
- [ ] 4.6 Marchand d'améliorations des nains (2.5)
- [ ] 4.7 **Garage sous la montagne** (nouvelle DA, validée le 2026-11-09) : remplace le camp du canyon ; roche froide, lumière chaude (lampes, forge), grande ouverture sur l'extérieur ; robot sur un pont élévateur sous une grue, passerelle pour monter à bord ; terminal de mission et bras de fer déplacés dedans
- [ ] 4.8 **Monte-charge géant** : départ et retour de mission (le robot descend ou monte avec lui), sert de transition pendant que l'hôte crée le niveau
- [ ] 4.9 Le garage grandit au fil des missions : trophées au mur, nouveaux outils, plaques des clients (lié à 4.3 pour la sauvegarde)

### Phase 5 — Les missions
- [x] 5.1 Cadre : `MissionDirector`, niveau créé par l'hôte, mission de test (M12, S1)
- [ ] 5.2 Mission prototype A → B : régler le ressenti, la difficulté et la durée sur un vrai parcours (M11)
- [ ] 5.3 Cadre commun d'une mission : objectifs, réussie / ratée, récompenses, retour au camp (lié à 4.3) ; chaque mission le remplit à sa façon
- [ ] 5.4 Histoire : le fil rouge des 10 missions, et la mécanique phare de chacune (à valider avec le porteur du projet) ; point de départ validé : le robot acheté à la casse (5.7)
- [ ] 5.6 **Radio du personnage guide** : poste radio dans le cockpit, voix en charabia + bulle de texte traduite (`tr()`), réagit aux actions des joueurs (chute, caca lancé…) ; répliques déclenchées par l'hôte, vues et entendues par tous
- [ ] 5.7 **Intro = mission tutoriel « Ramener le robot de la casse »** : au premier lancement d'une nouvelle partie, les nains apparaissent à la casse et ramènent le robot au garage ; une mécanique à la fois (entrer, démarrer, marcher, foreuse, grappin, se relever) guidée par la radio (5.6) ; arrivée au garage par le monte-charge (4.8). Dépend de 3.4 (marche finie), 5.3 (cadre de mission) et 4.3 (savoir si la partie est neuve)
- [ ] 5.5 Les 10 missions, une par une (une ligne par mission ici une fois 5.4 validé) : environnement + mécanique propre + histoire

### Phase 6 — Finitions
- [ ] 6.1 Son et musique
- [ ] 6.2 Menus et options (touches, son, graphismes)
- [ ] 6.3 Passe graphique : effets et couleurs créés dans le code (étincelles, éclats, câble…) passés en scènes et dans la palette
- [ ] 6.4 Version à distribuer sur Steam (français et anglais)
