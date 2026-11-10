# Le jeu — ce qui est validé

> Description du jeu **telle qu'elle est décidée**. Les pistes non validées sont dans `docs/ideas.md`,
> l'historique des choix (date + raison) dans `docs/decisions.md`, l'avancement dans la roadmap d'`AGENTS.md`.
> Quand une décision change le jeu, mettre ce fichier à jour dans le même commit.

## La boucle du jeu (vision du porteur du projet, 2026-11-08)

0. **L'intro** (une seule fois, au tout début d'une nouvelle partie) : les nains viennent d'acheter un vieux robot
   à la casse et doivent le ramener jusqu'à leur garage. C'est aussi le tutoriel (voir « L'intro et le tutoriel »).
1. **Le camp de base** : un garage sous une montagne, qui sert de lobby. On y trouve des mini-jeux,
   des marchands de **skins** (pour son nain et pour le robot) et un **marchand d'améliorations** pour les nains.
2. **Lancer une mission** quand tout le monde est prêt, au terminal devant le robot, parmi les **10 missions** du jeu,
   reliées par une **histoire**.
3. **La mission** : on part avec le robot dans l'**environnement propre à cette mission**.
   Chaque mission a sa propre idée de gameplay : **pas toujours la même boucle** (aller d'un point A à un point B
   est le socle, pas la règle). On réutilise les commandes du robot de façon nouvelle, ou on en ajoute.
4. **Retour au camp** avec ce qu'on a gagné, puis mission suivante.

## Le camp de base (lobby) : le garage sous la montagne (validé le 2026-11-09)
- **Un garage creusé sous une montagne** : roche froide, lumière chaude des lampes et d'une **forge**, et une grande
  ouverture sur l'extérieur pour garder un coin de ciel. Il **remplace le camp minier du canyon** actuel
  (au soleil couchant) quand il est construit.
- Le robot est garé sur un **pont élévateur**, sous une grue ; on monte à bord par une passerelle.
- **Départ et retour de mission par un monte-charge géant** : le robot est descendu ou monté avec lui, ce qui
  sert aussi de transition pendant que le niveau se crée.
- **Mini-jeux de garage** : bras de fer sur l'établi, course de chariots de mécano (planches à roulettes),
  lancer de nain dans un pneu, wagonnets sur les rails.
- **Le garage grandit** au fil des missions : trophées accrochés au mur, nouveaux outils, plaques des clients satisfaits.
- **Aujourd'hui** : grand garage ultra-éclairé (`lobby_garage.glb`) avec pont élévateur central, portique de levage,
  passerelle surélevée, baie vitrée panoramique, coin forge et établis ; les nains apparaissent dehors dans le garage,
  le robot est garé au centre sur son pont.
- **Terminal de mission** devant le robot : 2 flèches pour choisir la mission, un gros bouton vert pour lancer
  un compte à rebours de 20 s ; la mission part quand tous les nains sont à bord.
- **Atelier du robot (`MechaWorkshop`)** à droite du terminal : permet de changer en direct le **skin du robot**
  (*Mécano Original*, *Baron Cuivre* avec cheminées et couronne dorée, *Secours Blindé* avec rampe de gyrophares et pare-buffle)
  ainsi que la **configuration des bras** (*Standard : Grappin G / Foreuse D*, *Inversé : Foreuse G / Grappin D*,
  *Minage Titan : propulseurs de forage lourds + blindage*, *Électro-Aimant : bobines Tesla magnétiques*).
- **Vestiaire des nains (`DwarfWardrobe`)** à gauche du terminal : miroir éclairé avec 3 boutons permettant à chaque nain
  de choisir sa **tenue complète et son couvre-chef 3D** (*Mineur Classique*, *Garagiste Soudeur* avec masque de soudeur
  et lunettes de laiton, *Baron Cuivre* avec haut-de-forme steampunk, couronne et barbe royale) et sa **couleur de combinaison**
  (6 couleurs d'atelier). Le portrait animé de la bulle d'état reflète aussi la tenue choisie.
- **Mini-jeux jouables dans le garage** :
  - **Scène Guitare QTE (`GuitarStage`)** : estrade rock avec amplis à lampes, guitare électrique et retour de scène ;
    un solo de 10 accords en QTE sur les 4 pédales fléchées devant l'écran joue de vrais power-chords saturés avec
    étincelles, combo et record.
  - **Punch-O-Mètre (`PunchMachine`)** : borne de coup de poing à réflexe (1er clic = lance la jauge rapide, 2e clic
    au sommet = frappe le sac, score 0–999 et cloche lumineuse au-dessus de 800).
  - **Ferraille-Hoops (`GarageHoops`)** : panier de basket d'atelier avec tirs en cloche (2 pts de près, 3 pts de loin,
    compteur de série).
  - **Forge Naine (`AnvilGame`)** : enclume rythmique près du foyer de la forge où 3 coups de marteau au pic de chaleur
    forgent un lingot incandescent avec gerbe d'étincelles.
  - **Bras de fer (`ArmWrestling`)** : duel à deux sur la machine à bras mécaniques.
- **Sauvegarde** : tout est gardé chez l'hôte (une partie = une sauvegarde de l'hôte) ; un ami qui revient dans
  la partie retrouve son nain et ses achats. L'économie (argent, prix) sera conçue plus tard.

## L'intro et le tutoriel (validé le 2026-11-09)
- **Point de départ de l'histoire** : les nains achètent un vieux robot à la casse. La première fois qu'on apparaît
  dans une nouvelle partie, on est à la casse, et la première mission est de **ramener le robot jusqu'au garage**.
  Pas de cinématique longue : on joue tout de suite. Une fois au garage, on est dans le lobby normal.
- **On apprend une mécanique à la fois, en la faisant** : des choses à faire pour entrer dans le robot, le démarrer,
  marcher, utiliser la foreuse et le grappin, se relever après une chute… L'ordre exact se règle en construisant la mission.
- **Un personnage parle par un poste radio** posé dans le cockpit : une **voix en charabia** (pas de vrai doublage)
  et une **bulle de texte** à côté de la radio (texte traduit par `tr()`). Il réagit à ce que font les joueurs.
- Le reste vient du décor : la commande à utiliser clignote, des dessins de l'ancien propriétaire sur les murs.

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
- Chaque console a l'allure d'une **manette géante** : joystick sur socle rond, croix directionnelle (4 flèches),
  cadran rond de la jauge d'erreur et petit écran. Le voyant vert « à toi » dit à qui c'est le tour de marcher.
- **Jauge d'erreur** sur les consoles : un pas décalé ou dans une autre direction la fait monter ; pleine =
  le robot **s'effondre à genoux**. Pour le relever : un **QTE à tour de rôle** sur les 4 flèches de la croix :
  le **petit écran de chaque console**, façon « Just Dance », fait défiler les flèches à faire
  jusqu'à une cible (les siennes en grand et en cyan, celles de l'autre en petit et en violet), flash rouge à
  chaque erreur, « Bravo ! » à la fin.
- **Saut et accroupi** (validé le 2026-11-09, remplace les panneaux muraux) : au repos, le petit écran de chaque
  console affiche « Prêt » avec **↑ saut** et **↓ accroupi**. Les deux pilotes appuient sur la même flèche de leur
  croix à moins d'1 s d'écart (après le premier appui, l'écran dit « Attends l'autre… » / « Appuie aussi ! »).
  - **↑ = QTE du saut** : 1re étape « Ensemble ! », les deux poussent leur joystick dans la direction qu'ils ont
    choisie (à 30° près) ; puis 4 tours de flèches. Réussi : le robot plie les genoux, saute (environ 5,5 m
    vers l'avant, 4 m sur les côtés ou en arrière, 2,2 m de haut) et se réceptionne en amortissant.
  - **↓ = QTE de l'accroupi** (4 tours de flèches) : le robot descend d'1 m et y reste, il marche à petits pas.
    Accroupi, ↓ par les deux le relève, sans QTE ; pas de saut accroupi.
  - Dans ces deux QTE, **2 étapes « Ensemble ! »** au hasard : chacun a sa flèche, et les deux appuis doivent
    arriver à 0,4 s près (l'écran dit « Attends l'autre… » / « Appuie vite ! »). Mauvaise flèche ou l'autre trop
    lent : erreur, la séquence recule d'une étape.
  - Pendant ces QTE, les joysticks ne font pas marcher. Un QTE où personne ne progresse pendant 3 s s'annule
    (flash rouge) et la **jauge d'erreur** monte (0,35) ; pleine, le robot tombe.

### Les bras : postes assis
- Le nain **s'assoit** devant un petit écran : la caméra fait un traveling jusqu'à l'écran puis passe sur la
  caméra du bras (image brouillée de vieille caméra). Les deux postes se reconnaissent d'un coup d'œil :
  grappin = fauteuil de bureau, image verte, viseur en coins ; foreuse = siège de tracteur jaune, établi rayé, image ambrée, viseur rond.
- Les bras ne rentrent **jamais dans la coque** (angles bornés dans `MechaArmUtils`).
- **Foreuse** : orientée à la souris / au stick, Z/S l'étend jusqu'à 3 m, clic maintenu = la mèche tourne et
  **mine** ce qui est minable devant elle (le rocher éclate, une caisse de minerai tombe).
- **Grappin** : orienté et étendu pareil, clic = refermer la pince, saut = **lancer la pince** au bout d'un câble (15 m).
- **Sac à dos** : ce qui est attrapé va **automatiquement** dans un gros sac à dos sur le dos du robot (animation de rangement).
  Seul le robot y range les caisses (grappin, ou lancées dans l'ouverture) ; les nains peuvent seulement les porter pour les déplacer.

## Les nains
- **Nains garagistes** (validé le 2026-11-09) : combinaison de travail, ceinture à outils, casquette ou masque de soudeur,
  taches de cambouis. Le nouveau modèle garde **le même squelette** (mêmes os, mêmes noms) pour garder toutes les animations.
- Nain de 1,2 m, vue à la première personne (on voit son corps, pas sa tête), clavier + manette.
- Marcher, sauter, s'accroupir, roue d'emotes (6 gestes : coucou, pouce levé, pointer, danse, je sais pas, doigt d'honneur), bulle d'état avec mini-portrait animé en haut à droite.
- **Inventaire de 5 cases** (barre en bas de l'écran) : un caca prend une case, les fléchettes une seule pour toutes.
  On choisit sa case avec 1 à 5, la molette ou la croix de la manette ; l'objet de la case choisie est en main
  (dans sa main droite, bras tendu devant soi, qui suit le regard ; les autres le voient), clic = l'utiliser (le lancer), G = le poser par terre (et rien d'autre), E ou clic = ramasser (E même avec un objet en main).
  Prendre un levier, la corde ou s'asseoir **range l'objet en main** tout seul ; il revient en main en lâchant.
  **Objets lourds** (caisses) : portés à deux mains devant soi (une main de chaque côté), ils prennent une case et restent en main (on ne
  change plus de case, on ne ramasse rien d'autre, pas de levier ni de siège) ; G les pose devant soi (le clic ne fait rien).
- **Vue à la première personne, avec son vrai corps** : seule la tête est cachée (la caméra est dedans). En baissant
  les yeux, on voit son ventre et sa ceinture ; l'objet en main et la caisse portée se voient avec les mains qui les
  tiennent. Pas de bras à part accrochés à la caméra : ce qu'on voit de soi est exactement ce que voient les autres.
  Les emotes se jouent sur le corps (on les voit en entier dans la bulle d'état en haut à droite).
- **Vie à bord** : salon dans le ventre (canapé où s'asseoir, télé qu'on allume et éteint avec son bouton, qui fait tourner le jeu **« Robo-Jet »** : notre petit robot à réacteur passe entre des stalactites et des poutres de mine, un clic sur l'écran = un coup de réacteur ; jouable debout ou depuis le canapé, un joueur à la fois (le premier qui clique), les autres regardent, record gardé pendant la partie, lampe qui se balance),
  toilettes dans la tête (mini-jeu « Poussée », cacas qu'on ramasse et qu'on lance, caca légendaire doré).
  Intérieur usé et encombré, jamais vide.
- **Fléchettes** sur la cible du salon : on prend les fléchettes libres d'un coup (sur la cible ou là où elles sont
  plantées, une case d'inventaire), on lance de n'importe où dans le robot, elles se plantent là où elles tapent ; G en pose une couchée au sol devant soi. Viser une fléchette qui traîne (sol, mur) ne ramasse qu'elle, même avec des fléchettes en main : le clic la ramasse au lieu de lancer (vers la cible, le clic lance toujours). Si des fléchettes traînent ailleurs (mur, sol, dans un nain), viser la cible propose de les remettre : un clic les y ramène toutes (pas celles qu'un joueur a dans son inventaire). Centre = « Dans le mille ! »
  (confettis) ; les scores s'écrivent à la craie sur l'ardoise d'à côté (lancers, total, 3 manches précédentes ; pseudos trop longs coupés avec « … » ;
  rien n'est gardé après la partie). Un nain touché a un flash rouge de douleur et la fléchette reste plantée là
  où elle l'a touché (casque, visage ou corps) ; au visage seulement, il a en plus la vue brouillée
  (aucun texte à l'écran). Un autre nain
  doit venir la lui retirer : elle va dans son inventaire, avec ses autres fléchettes.
- **Jeu de dames** sur la table basse du salon, à deux (ou seul contre soi-même), debout ou assis sur le canapé (clic) : on vise un pion puis sa case
  d'arrivée ; règles à la française simplifiées (prise obligatoire en avant et en arrière, rafles, dame volante),
  le premier qui joue un côté le garde ; une pendule d'échecs à côté du damier montre à qui de jouer, sonne en fin
  de partie, et on appuie dessus pour une nouvelle partie.
- **À venir** : skins (vendus au camp), améliorations (vendues au camp).

## Principes qui valent partout
- **Coop chaotique** : les commandes sont dans le cockpit, il faut se coordonner et se déplacer.
- **Deux langues** : français et anglais.
- **Rien d'écrit à l'écran, interface sobre** : la place est au jeu, pas aux touches. Ce qu'on peut utiliser se reconnaît en le visant : le **point de visée devient un petit anneau** et l'**objet s'illumine sur ses bords** (lueur chaude qui respire) ; à côté de l'anneau, en petit, l'**icône de l'action** (appuyer, grimper, s'asseoir…), avec sa touche seulement si ce n'est ni le clic ni E (ex. Espace pour lâcher la corde). « Viser » n'est jamais affiché ; la touche pour poser l'objet en main est un petit G sur sa case d'inventaire ; le panneau des touches d'un poste se replie tout seul après 5 s (Tab le rouvre) ; « Échap → quitter » s'efface après 6 s. Au pire de petits mots en police Fredoka.
  Seule exception : la bulle de texte du personnage de la radio (voir « L'intro et le tutoriel »).
  Les infos de jeu (jauges, QTE, tour de qui) sont **dans le cockpit**.
- **Tout ce qui bouge est animé**, rien ne glisse ni ne se téléporte.
- **Tout est synchronisé** : ce qu'un joueur fait, tous le voient (voir `docs/reseau.md`).
