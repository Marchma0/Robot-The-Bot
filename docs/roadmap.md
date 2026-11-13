# Roadmap

> Fait partie des consignes du projet (voir `AGENTS.md`) : à relire en début de session.

> Rangée par **phases** dans l'ordre où le jeu se construit ; on peut avancer deux phases en parallèle (une par développeur).
> Avant de commencer une tâche : la marquer `[en cours — pseudo]` et pousser tout de suite. La cocher quand elle est fusionnée dans `main`.
> Une tâche finie tient en **une ligne** : le détail (comment, pourquoi) va dans `docs/decisions.md`.
> Les codes entre parenthèses (M7, M12, S1…) sont les anciens numéros, encore cités dans le code et dans `docs/decisions.md`.

**En cours** : rien pour l'instant.

**Bugs connus** (notés pour plus tard, à corriger quand le porteur du projet le demande) :
- aucun pour l'instant.

### Phase 1 — Fondations (moteur, réseau, outils)
- [x] 1.1 Projet Godot, Input Map clavier + manette, `NetworkManager` ENet, 4 nains (M0)
- [x] 1.2 Synchro lissée des joueurs et du robot, `physics_interpolation` (M6.6)
- [x] 1.3 Interface en icônes « touche → action », police Fredoka (M6.6)
- [x] 1.4 Synchro de toutes les interactions, garde-fous `net_test.sh` / F9 / `NetGuard`, `docs/reseau.md` (S1)
- [x] 1.5 Steam : GodotSteam, lobby, invitation, export Windows (M5)
- [x] 1.6 Pipeline 3D : un script Python par objet, palette, planche de vues, captures `interior_shots` (M6.7)
- [x] 1.7 Rationalisation du code : interactions génériques, nain découpé, base des bras, traduction, dette de `mecha.blend`
- [x] 1.8 Interface sobre : viseur, contour de l'objet visé, icône de l'action
- [x] 1.9 ~~Performances~~ : retirées le 2026-11-13 (rationalisation, 1.11)
- [x] 1.10 Contrôles des modèles (2026-11-11) : PASS / FAIL avant export, réimport du `.glb`, repères d'échelle sur la planche, règles pour la génération IA et Geometry Nodes
- [x] 1.11 Rationalisation 2 (2026-11-13) : optimisations graphiques, physique bras ↔ nain et bras de fer retirés, `AGENTS.md` allégé, `docs/decisions.md` compacté, `.blend` des scripts non versionnés, tests visuels supprimés ; menu Échap avec options graphiques

### Phase 2 — Les nains
- [x] 2.1 Nain contrôlable dans un cockpit qui bouge, première personne (M1)
- [x] 2.2 Squelette, animations, `AnimationTree`, état synchronisé (M4)
- [x] 2.3 Emotes, corps visible, bulle d'état, s'accroupir (M6.5)
- [ ] 2.4 Skins des nains : pièces interchangeables (barbe, casque, couleurs…), choix synchronisé et sauvegardé — au poste de personnalisation des nains (4.5)
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
- [ ] 3.8 Skins du robot : peinture, décorations, choix synchronisé et sauvegardé — au poste de personnalisation du robot (4.5)
- [x] 3.9 Fléchettes dans le robot
- [x] 3.10 Finitions du salon : ardoise, télé, jeu de dames, roue d'emotes
- [x] 3.11 Fléchette plantée dans un allié
- [x] 3.12 Télé : jeu « Robo-Jet »
- [x] 3.13 Finitions de pilotage (2026-11-10) : pas plus jamais perdus, vue stable au saut, caisse portée sans à-coups, QTE à étapes « Ensemble ! »
- [x] 3.14 Robot praticable (2026-11-10) : collisions sur la coque du robot (le suivi du support, la projection et la pince qui attrape un allié ont été retirés le 2026-11-13)
- [ ] 3.15 Échelle à l'arrière (validée par Marchma0) : un tronçon du sol au dessus du sac à dos, un du rebord au toit ; grimpe en réutilisant `Rope` (sans corde visible, sans balancement, côté extérieur)

### Phase 4 — Le camp de base (lobby)
- [x] 4.1 Camp minier dans un canyon, terminal de mission, retour au camp (M12, M12.1)
- [x] 4.2 ~~Mini-jeu : bras de fer~~ : retiré le 2026-11-13 (rationalisation, 1.11)
- [ ] 4.3 Monnaie et sauvegarde de la partie (économie reportée par le porteur du projet le 2026-11-08) : fiches de données (objets, missions, skins en `.tres`), `GameState` tenu par l'hôte, sauvegarde **chez l'hôte** (validé) ; argent par nain ou commun : à décider
- [ ] 4.4 Plus de mini-jeux dans la base : course de chariots de mécano, lancer de nain dans un pneu, wagonnets sur les rails (autres pistes dans `docs/ideas.md`)
- [ ] 4.5 **Deux postes de personnalisation** (validés le 2026-11-11, remplacent les « marchands de skins ») : un pour son nain (2.4), un pour le robot (3.8). Écran en trois parties : modèle 3D sur un socle qu'on fait tourner (à gauche), colonne d'icônes des emplacements (au milieu), liste des pièces avec vignette, nom, phrase drôle, prix et cadenas (à droite) ; détail dans `docs/jeu.md`
- [ ] 4.6 Marchand d'améliorations des nains (2.5)
- [ ] 4.7 **Base souterraine** (validée le 2026-11-11, remplace le camp du canyon et précise le « garage sous la montagne » du 2026-11-09) : une base creusée sous terre où le robot est garé, avec **une sortie pour le robot** ; construite étape par étape
  - [ ] 4.7.1 La zone vide : sol, parois, plafond, place du robot, sortie du robot, points d'apparition ; terminal posé provisoirement ; rien d'autre
  - [ ] 4.7.2 Les deux postes de personnalisation et le poste des missions posés à leur place (4.5, 4.10)
  - [ ] 4.7.3 Remplissage, une zone à la fois (à définir avec le porteur du projet au fur et à mesure), dans la direction artistique
- [ ] 4.8 **Départ et retour par la sortie du robot** : le robot quitte la base par sa sortie (forme à décider : grande porte, tunnel…), ce qui sert de transition pendant que l'hôte crée le niveau ; retour par le même chemin
- [ ] 4.9 La base grandit au fil des missions : trophées au mur, nouveaux outils, plaques des clients (lié à 4.3 pour la sauvegarde)
- [ ] 4.10 **Poste des missions** (validé le 2026-11-11, remplace le terminal à deux flèches) : écran avec la carte d'une région en relief, un pion par mission (icône du type, ou cadenas), fiche de la région à gauche, fiche de la mission à droite (objectifs, récompenses, durée, difficulté) ; un clic sur un pion lance le compte à rebours ; choix tenu par l'hôte et vu par tous ; détail dans `docs/jeu.md` (lié à 5.3 et 5.4)

### Phase 5 — Les missions
- [x] 5.1 Cadre : `MissionDirector`, niveau créé par l'hôte, mission de test (M12, S1)
- [ ] 5.2 Mission prototype A → B : régler le ressenti, la difficulté et la durée sur un vrai parcours (M11)
- [ ] 5.3 Cadre commun d'une mission : objectifs, réussie / ratée, récompenses, retour au camp (lié à 4.3) ; chaque mission le remplit à sa façon
- [ ] 5.4 Histoire : le fil rouge des 10 missions, et la mécanique phare de chacune (à valider avec le porteur du projet) ; point de départ validé : le robot acheté à la casse (5.7)
- [ ] 5.6 **Radio du personnage guide** : poste radio dans le cockpit, voix en charabia + bulle de texte traduite (`tr()`), réagit aux actions des joueurs (chute, caca lancé…) ; répliques déclenchées par l'hôte, vues et entendues par tous
- [ ] 5.7 **Intro = mission tutoriel « Ramener le robot de la casse »** : au premier lancement d'une nouvelle partie, les nains apparaissent à la casse et ramènent le robot à la base ; une mécanique à la fois (entrer, démarrer, marcher, foreuse, grappin, se relever) guidée par la radio (5.6) ; arrivée à la base par la sortie du robot (4.8). Dépend de 3.4 (marche finie), 5.3 (cadre de mission) et 4.3 (savoir si la partie est neuve)
- [x] 5.8 **Parcours tuto de dev** (2026-11-11, provisoire, pour les développeurs) : parcours linéaire en 11 étapes lancé depuis le terminal du camp (avancer, virage, saut d'un trou, accroupi, demi-tour, foreuse, grappin, caisses mobiles, bouton au sol qui ouvre la porte 3, remonter, arrivée) ; le robot ne traverse plus les obstacles
- [ ] 5.5 Les 10 missions, une par une (une ligne par mission ici une fois 5.4 validé) : environnement + mécanique propre + histoire

### Phase 6 — Finitions
- [ ] 6.1 Son et musique
- [ ] 6.2 Menus et options : menu Échap et options graphiques faits (2026-11-13) ; restent les touches et le son
- [ ] 6.3 Passe graphique : effets et couleurs créés dans le code (étincelles, éclats, câble…) passés en scènes et dans la palette
- [ ] 6.4 Version à distribuer sur Steam (français et anglais)
