# Le jeu — ce qui est validé

> Description du jeu **telle qu'elle est décidée**. Les pistes non validées sont dans `docs/ideas.md`,
> l'historique des choix (date + raison) dans `docs/decisions.md`, l'avancement dans la roadmap d'`AGENTS.md`.
> Quand une décision change le jeu, mettre ce fichier à jour dans le même commit.

## La boucle du jeu (vision du porteur du projet, 2026-11-08)

1. **Le camp de base** : les 4 joueurs arrivent au camp, qui sert de lobby. On y trouve des mini-jeux,
   des marchands de **skins** (pour son nain et pour le robot) et un **marchand d'améliorations** pour les nains.
2. **Lancer une mission** quand tout le monde est prêt, au terminal devant le robot, parmi les **10 missions** du jeu,
   reliées par une **histoire**.
3. **La mission** : on part avec le robot dans l'**environnement propre à cette mission**.
   Chaque mission a sa propre idée de gameplay : **pas toujours la même boucle** (aller d'un point A à un point B
   est le socle, pas la règle). On réutilise les commandes du robot de façon nouvelle, ou on en ajoute.
4. **Retour au camp** avec ce qu'on a gagné, puis mission suivante.

## Le camp de base (lobby)
- Camp minier au fond d'un canyon, au soleil couchant (falaises ocre, toile, bois, guirlandes d'ampoules).
- Les nains apparaissent dehors, le robot est garé au centre.
- **Terminal de mission** devant le robot : 2 flèches pour choisir la mission, un gros bouton vert pour lancer
  un compte à rebours de 20 s ; la mission part quand tous les nains sont à bord.
- **Mini-jeux** jouables : fléchettes, bras de fer (machine à bras mécaniques). Les wagonnets sont du décor pour l'instant.
- **À venir** : marchand de skins des nains, marchand de skins du robot, marchand d'améliorations des nains,
  d'autres mini-jeux.

## Les missions
- 10 missions, une histoire qui les relie.
- Un **environnement par mission**, créé par l'hôte (`MissionDirector`, voir `docs/reseau.md`).
- Une **mécanique phare par mission** pour renouveler le jeu (ex. construire des ponts, mission à pied, terrain
  instable…). Les pistes sont dans `docs/ideas.md`, rien n'est encore choisi.
- Aujourd'hui : une mission de test (rochers à miner, caisses), un bouton « retour au camp » au fond du ventre.

## Le robot
- Robot trapu low poly, style « robot cosy mais pas trop » : métal peint, chanfreins, rivets, hublots ronds,
  touches de cuivre. Pas d'ambiance cabane.
- **Deux étages** :
  - **Ventre** : 2 nains aux postes des **jambes** (une jambe chacun) ; c'est aussi le salon.
  - **Tête** : 2 nains aux postes des **bras** — gauche **grappin**, droite **foreuse**. On voit dehors par les deux yeux ronds.
- **Circulation** : un **rayon tracteur** (colonne lumineuse) relie les étages, un interrupteur à chaque étage
  inverse son sens (bleu = monte, orange = descend). On **sort** par une **trappe** dans le plancher du ventre
  et on **remonte** par une **corde** qui pend jusqu'au sol. Dehors, le nain ne suit plus le robot.
- **Commandes physiques** : boutons, leviers et joysticks dans le cockpit, toujours actifs ; on attrape un levier
  en maintenant clic / RT et on peut marcher à portée de bras. Pas de poste verrouillant, sauf les postes assis des bras.

### Les jambes : marche en rythme
- Chaque nain du ventre pilote **sa** jambe avec un joystick. **Un coup de joystick = un pas** : haut = avance,
  diagonale = avance en tournant, côté = pivote sur place, bas = recule.
- **Pas alternés** des deux joueurs dans la même direction = le robot avance (plus vite s'ils enchaînent).
  Seul, on piétine. Deux pieds en l'air en même temps : interdit. Une marque lumineuse montre où le pied va se poser.
- Le voyant « à toi » de la console dit à qui c'est le tour.
- **Jauge d'erreur** sur les consoles : un pas décalé ou dans une autre direction la fait monter ; pleine =
  le robot **s'effondre à genoux**. Pour le relever : un **QTE à tour de rôle** sur les pads à 4 flèches
  (la flèche s'allume sur la console de celui dont c'est le tour, rien à l'écran).
- **À venir** : **panneaux muraux** dans le ventre (s'accroupir, se relever…) par des **combinaisons à deux**
  gravées sur les murs par l'ancien propriétaire (aucun QTE affiché à l'écran) ; **saut directionnel**
  (un joueur tient la direction au joystick pendant que l'autre fait la combinaison ; réception ratée = jauge d'erreur ou chute).

### Les bras : postes assis
- Le nain **s'assoit** devant un petit écran : la caméra fait un traveling jusqu'à l'écran puis passe sur la
  caméra du bras (image brouillée de vieille caméra). Les deux postes se reconnaissent d'un coup d'œil :
  grappin = fauteuil de bureau, image verte, viseur en coins ; foreuse = siège de tracteur jaune, établi rayé, image ambrée, viseur rond.
- Les bras ne rentrent **jamais dans la coque** (angles bornés dans `MechaArmUtils`).
- **Foreuse** : orientée à la souris / au stick, Z/S l'étend jusqu'à 3 m, clic maintenu = la mèche tourne et
  **mine** ce qui est minable devant elle (le rocher éclate, une caisse de minerai tombe).
- **Grappin** : orienté et étendu pareil, clic = refermer la pince, saut = **lancer la pince** au bout d'un câble (15 m).
- **Sac à dos** : ce qui est attrapé va **automatiquement** dans un gros sac à dos sur le dos du robot (animation de rangement).

## Les nains
- Nain de 1,2 m, vue à la première personne (on voit son corps, pas sa tête), clavier + manette.
- Marcher, sauter, s'accroupir, roue d'emotes (8 gestes), bulle d'état avec mini-portrait animé en haut à droite.
- **Vie à bord** : salon dans le ventre (canapé où s'asseoir, télé animée, lampe qui se balance),
  toilettes dans la tête (mini-jeu « Poussée », cacas qu'on ramasse et qu'on lance, caca légendaire doré).
  Intérieur usé et encombré, jamais vide.
- **À venir** : skins (vendus au camp), améliorations (vendues au camp).

## Principes qui valent partout
- **Coop chaotique** : les commandes sont dans le cockpit, il faut se coordonner et se déplacer.
- **Rien d'écrit à l'écran** : des icônes « touche → action », au pire de petits mots en police Fredoka.
  Les infos de jeu (jauges, QTE, tour de qui) sont **dans le cockpit**.
- **Tout ce qui bouge est animé**, rien ne glisse ni ne se téléporte.
- **Tout est synchronisé** : ce qu'un joueur fait, tous le voient (voir `docs/reseau.md`).
