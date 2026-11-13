# Décisions

Format : date - décision - raison. Seules les décisions **en vigueur** sont ici, rangées par thème : quand une décision en remplace une autre, on remplace la ligne (l'ancienne reste dans l'historique git, ex. `git log -p docs/decisions.md`). Le jeu validé est résumé dans `docs/jeu.md`.

## Organisation
- 2026-11-06 - Deux développeurs, deux IA (Claude Code, Antigravity) : consignes uniques dans `AGENTS.md`, `CLAUDE.md` et `.agent/rules/` y renvoient ; chemin de Godot par `GODOT_PATH` - deux IA qui ne se parlent pas doivent lire les mêmes règles
- 2026-11-06 - Pas de Pull Request : l'IA fusionne sa branche `pseudo/sujet` dans `main` (merge --no-ff) et pousse ; jamais de rebase ni de force push - les humains ne passent pas par GitHub
- 2026-11-08 - Documents : `docs/jeu.md` = jeu validé, `docs/roadmap.md` = tâches et bugs connus (relue en début de session), `docs/ideas.md` = idées non validées - les IA lisaient des consignes périmées
- 2026-11-04 - `addons/` non versionné (GodotSteam pèse 93 Mo) ; `addons/ADDONS.txt` liste chaque addon
- 2026-11-13 - Les `.blend` fabriqués par un script ne sont plus versionnés (le script fait foi et les recrée) ; seuls `mecha.blend` et `dwarf.blend` le restent - moins de binaires qui ne se fusionnent pas
- 2026-11-13 - Rationalisation (roadmap 1.11) : optimisations graphiques, physique bras ↔ nain et bras de fer retirés, `AGENTS.md` réduit aux règles utiles, ce journal compacté - repartir sur une base saine (demandé par Marchma0)

## Moteur et réseau
- 2026-11-04 - Godot 4.7 + GDScript + Jolt, Blender (.glb), hôte autoritaire, ENet en dev, GodotSteam en prod ; tout Steam dans `steam_backend.gd`, appelé seulement par `NetworkManager` - le jeu doit tourner sans Steam
- 2026-11-04 - Une seule scène racine `main.tscn` (menu + monde) - évite qu'un spawn arrive chez un client qui n'a pas encore son spawner
- 2026-11-04 - Nains créés par `MultiplayerSpawner.spawn_function` ({peer_id, slot}), nom du nœud = peer id, autorité dans `_enter_tree`
- 2026-11-04 - Steam : lobby d'amis de 4 places, invitation (overlay, F2) ou code de lobby ; `set_server_relay(true)` ; Steam initialisé par la section `[steam]` de `project.godot` (sinon l'overlay ne s'accroche pas)
- 2026-11-06 - Synchro lissée : `NetSmoother` envoie [heure, dehors ?, position, rotation, tête] 30 fois/s, affichage avec 100 ms de retard ; `physics_interpolation` activé ; les 9 états d'animation du nain partent en un seul nombre (`anim_flags`)
- 2026-11-08 - Modèle réseau (`docs/reseau.md`) : le niveau est créé par l'hôte (`LevelSpawner`), ses objets réseau sont sous un `NetSpawner` ; un objet créé en jeu reçoit sa place avant `add_child` - sinon Godot abandonnait la synchro des objets du niveau chez le client
- 2026-11-08 - Corps figés en `FREEZE_MODE_STATIC` (pas KINEMATIC) - avec Jolt, un corps KINEMATIC se faisait réécrire une ancienne place quand son parent bougeait
- 2026-11-08 - Garde-fous : test réseau hôte + client (`net_test.sh`, lancé par `run_tests.sh`), F9 compare client et hôte en partie, `NetGuard` signale un objet réseau créé hors d'un spawner
- 2026-11-08 - Interactions : chaque commande décide de son utilisation (`Interactable.interact`) ; ce que tient un joueur est vérifié par l'hôte à un seul endroit (`Possession.is_peer_busy`)

## Le robot
- 2026-11-04 - Robot trapu (grosse tête à deux yeux ronds, corps en boîte, jambes courtes), grappin à gauche, foreuse à droite ; ventre = 2 postes des jambes, tête = 2 postes des bras - croquis du porteur du projet
- 2026-11-04 - Commandes physiques toujours actives (boutons, leviers et joysticks qu'on attrape en maintenant clic / RT), à l'échelle des nains ; seuls les postes des bras sont assis - chaos coopératif
- 2026-11-05 - Circulation : rayon tracteur entre les étages (un interrupteur par étage inverse son sens), trappe dans le ventre pour sortir, corde pour remonter (un grimpeur à la fois)
- 2026-11-05 - Nain dehors : il reste enfant du mécha mais annule son déplacement et prend la gravité du monde ; sa place est envoyée dans le monde ; « dehors » = hors de l'`InteriorVolume`
- 2026-11-13 - Dehors, le nain ne suit pas ce qu'il a sous les pieds et n'est pas projeté (système retiré) ; les bras restent solides, déployés ou non (épaule, fût, glissière) ; la pince attrape un allié dehors et le pose au sol devant le robot, sous la main du grappin (`ClawDropPoint`), et non plus sous le rayon tracteur à l'arrière - demandé par Marchma0
- 2026-11-06 - Marche en rythme : un coup de joystick = un pas, pas alternés dans la même direction = le robot avance (haut / diagonale / côté / bas = avance / tourne / pivote / recule), désaccord = il trébuche - plus simple et plus drôle à deux
- 2026-11-06 - Jauge d'erreur (pas décalés, tolérance 15°) ; pleine = le robot s'effondre à genoux ; relèvement par QTE à tour de rôle sur les flèches - le porteur du projet préfère l'effondrement au ragdoll (gardé dans `docs/ideas.md`)
- 2026-11-07 - Joysticks des jambes : à ressort, poussée tenue 0,14 s à la souris, « clac » au seuil du pas ; un pas demandé pendant que l'autre pied est en l'air attend qu'il se pose ; le corps suit les pieds avec un ressort amorti
- 2026-11-09 - Saut et accroupi : ↑ ou ↓ par les deux pilotes à moins d'1 s depuis l'écran « Prêt », puis QTE (4 tours dont 2 « Ensemble ! » à 0,4 s près) ; saut de 5,5 m vers l'avant ; accroupi = corps 1 m plus bas, pas raccourcis ; échec = jauge d'erreur
- 2026-11-08 - Consoles des jambes en manette géante, QTE affiché sur un petit écran par console (`QteScreen`) ; l'hôte synchronise la séquence et les erreurs
- 2026-11-07 - Bras : postes assis avec caméra au poignet (image brouillée par shader), base commune `MechaArm` ; jamais dans la coque (`MechaArmUtils` : 7° vers la coque, 60° vers l'extérieur)
- 2026-11-07 - Foreuse : glissière 0 → 3 m, clic maintenu = mine (le rocher éclate, une caisse de minerai tombe) ; grappin : 0 → 3,8 m, pince lancée au saut (15 m, tir calculé par l'hôte)
- 2026-11-07 - Sac à dos sur le dos du robot : ce que la pince attrape y va tout seul (stockage tenu par l'hôte, animation locale) ; seul le robot y range les caisses
- 2026-11-10 - Coque et meubles en `StaticBody3D` replacés dans la même étape physique (`MechaColliderSync`) - avec Jolt, un `AnimatableBody3D` garde une étape de retard (vue saccadée au saut)
- 2026-11-11 - Obstacles : calque physique 5 « robot_obstacle » ; `MechaWalker` refuse un pas, un saut ou un relèvement qui y entrerait (le robot vacille, sans erreur) - nécessaire pour les parcours
- 2026-11-08 - `mecha.blend` = la coque seulement ; tout le décor est en objets à part (un script chacun) placés dans `belly.tscn` / `head.tscn` - un objet se retouche sans réexporter le robot

## Les nains
- 2026-11-04 - Vue à la première personne ; Input Map en touches physiques (ZQSD en AZERTY = WASD en QWERTY)
- 2026-11-04 - Nains enfants du cockpit, plateformes mobiles du `CharacterBody3D` désactivées ; gravité selon le haut du cockpit - le parent porte déjà le nain
- 2026-11-09 - On voit son vrai corps à la première personne (seule la tête ne garde que son ombre) ; angle de vue de 90° ; regard vers le bas limité à 68°
- 2026-11-05 - Emotes (roue, 6 gestes du haut du corps) : état synchronisé (index + compteur), à la première personne ; s'accroupir (capsule 1,2 → 0,72 m, synchronisé)
- 2026-11-09 - Inventaire de 5 cases (1 à 5, molette, croix) : clic = utiliser / lancer, G = poser ; prendre un levier, la corde ou s'asseoir range l'objet en main, qui revient en lâchant ; une caisse se porte à deux mains. Rien n'est stocké : chaque objet sait qui le tient et dans quelle case
- 2026-11-09 - Animations « porter » : objet léger = bras droit tendu (3 poses selon le regard), caisse = `carry` ; l'objet est dans la main chez tout le monde
- 2026-11-08 - Nain découpé en composants (`DwarfLook`, `DwarfCamera`, `DwarfClimb`) ; l'interface est la scène `PlayerHud`, créée seulement pour le joueur local
- 2026-11-08 - Nom affiché : partout `Dwarf.get_display_name()` (pseudo Steam, sinon « Joueur N »)

## Vie à bord
- 2026-11-05 - Toilettes dans la tête (porte tenue par l'hôte) et mini-jeu « Poussée » joué chez le joueur assis ; caca doré 5 % du temps
- 2026-11-05 - Caca : objet physique de l'hôte, créé par un spawner ; lancé en cloche, il éclate au premier contact ; un nain touché recule et a l'écran taché ; 6 cacas max
- 2026-11-08 - Fléchettes dans le salon : on les prend à la cible, on lance de partout ; l'hôte calcule le vol, la fléchette se plante où elle tape (mur, sol, nain) ; score à la craie sur l'ardoise ; fléchette au visage = vue brouillée, ailleurs = flash rouge ; un allié la retire
- 2026-11-08 - Jeu de dames sur la table basse (règles françaises simplifiées), jouable depuis le canapé (`usable_seated`) ; pendule = à qui de jouer / nouvelle partie ; état tenu par l'hôte
- 2026-11-09 - Télé : jeu « Robo-Jet » à nous ; l'hôte décide qui joue et tient la graine, le joueur fait tourner sa partie et envoie la place du robot (20 fois/s)

## Base, missions, histoire
- 2026-11-08 - La base sert de lobby (mini-jeux, postes de personnalisation, améliorations) ; on y lance une des 10 missions, reliées par une histoire, chacune avec son idée de gameplay - vision du porteur du projet
- 2026-11-11 - Base souterraine avec une sortie pour le robot (remplace le camp du canyon), construite étape par étape ; deux postes de personnalisation (nain, robot) et un poste des missions (carte de région) - détail dans `docs/jeu.md`
- 2026-11-07 - Changement de niveau par `MissionDirector` (fondu, robot replacé par l'hôte) ; terminal : flèches + bouton vert, compte à rebours de 20 s, départ quand tous sont à bord ; bouton « retour au camp » au fond du ventre
- 2026-11-08 - Sauvegarde chez l'hôte (une partie = une sauvegarde) ; économie reportée (tâche 4.3)
- 2026-11-09 - Intro = mission « ramener le robot de la casse » ; guide par poste radio, voix en charabia + bulle traduite
- 2026-11-11 - Parcours tuto de dev provisoire (11 étapes depuis le 2026-11-13) : murs créés depuis des tables, `step` / `gates_open` / `crates_left` tenus par l'hôte ; caisses mobiles dans `NetAudit.MOVING_GROUP`

## Interface et langue
- 2026-11-13 - Menu Échap (`PauseMenu`) : reprendre, options graphiques, inviter, quitter la partie / le jeu ; la partie continue (jeu en ligne), les touches du jeu sont retirées de la Input Map tant que le menu est ouvert (un seul endroit, aucun script de jeu à modifier). Options (`GraphicsSettings`) gardées dans `user://settings.cfg`, purement locales ; « Ombres : désactivées » coupe l'ombre de chaque lumière, qui reprend la sienne ensuite - demandé par Marchma0 (Échap quittait directement la partie)
- 2026-11-06 - Pas de texte d'aide : icônes « touche → action » dessinées d'après la Input Map (clavier / manette selon le dernier appareil) ; police Fredoka
- 2026-11-09 - Interface sobre : la commande visée s'illumine sur ses bords, le viseur devient un anneau, l'icône de l'action s'affiche à côté (sans la touche quand c'est le clic) ; panneau des touches d'un poste replié après 5 s (Tab le rouvre)
- 2026-11-08 - Français et anglais : `tr("texte français")` + `assets/translations/texts.csv` ; langue du système, anglais sinon - plus simple tôt que sur un jeu fini

## 3D
- 2026-11-12 - Direction artistique : diorama low poly lumineux et encré (contours noirs par shader), mine + rétro-industriel, vieux robot de casse retapé ; jamais d'image sombre - détail dans `docs/modeles_3d.md`
- 2026-11-06 - Un modèle = un script Python (`blender/props/<nom>.py`) + palette commune (`prop_kit.py`) ; planche de vues (`render_views.py`) pour vérifier ; avant = +Y dans Blender
- 2026-11-11 - `kit.save_and_export` refuse l'export si un contrôle rate (budget, échelle, au sol, faces superposées…) puis réimporte le `.glb` pour le comparer
- 2026-11-04 - Tout ce qui bouge est animé ; on synchronise l'état, chaque joueur joue l'animation

## Tests
- 2026-11-08 - Les scènes de test vérifient elles-mêmes leur résultat (`TestCheck`) ; `run_tests.sh` lance tout sans fenêtre (scènes en temps accéléré, 4 à la fois, test réseau en temps réel) → `TOUS LES TESTS OK` avant de fusionner
- 2026-11-13 - Scènes de test purement visuelles supprimées (`sandbox_dwarf_anim`, `sandbox_emotes`, `sandbox_interaction`) - elles ne vérifiaient rien
- 2026-11-13 - Test réseau : pour poser une fléchette (G), le client se place devant la cible, dans le robot - il était placé hors du robot et tombait au sol, d'où les échecs des étapes « fléchette au sol »
