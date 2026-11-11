# Le jeu — ce qui est validé

> Description du jeu **telle qu'elle est décidée**. Les pistes non validées sont dans `docs/ideas.md`,
> l'historique des choix (date + raison) dans `docs/decisions.md`, l'avancement dans `docs/roadmap.md`.
> Quand une décision change le jeu, mettre ce fichier à jour dans le même commit.

## La boucle du jeu (vision du porteur du projet, 2026-11-08)

0. **L'intro** (une seule fois, au tout début d'une nouvelle partie) : les nains viennent d'acheter un vieux robot
   à la casse et doivent le ramener jusqu'à leur base. C'est aussi le tutoriel (voir « L'intro et le tutoriel »).
1. **Le camp de base** : une base souterraine, qui sert de lobby. On y trouve des mini-jeux,
   deux **postes de personnalisation** (son nain, le robot) et un **marchand d'améliorations** pour les nains.
2. **Lancer une mission** quand tout le monde est prêt, au **poste des missions**, parmi les **10 missions** du jeu,
   reliées par une **histoire**.
3. **La mission** : on part avec le robot dans l'**environnement propre à cette mission**.
   Chaque mission a sa propre idée de gameplay : **pas toujours la même boucle** (aller d'un point A à un point B
   est le socle, pas la règle). On réutilise les commandes du robot de façon nouvelle, ou on en ajoute.
4. **Retour au camp** avec ce qu'on a gagné, puis mission suivante.

## Le camp de base (lobby) : la base souterraine (validé le 2026-11-11)
- **Une base creusée sous terre**, qui remplace le camp minier du canyon (et précise le « garage sous la montagne » du
  2026-11-09). Le robot y est garé ; c'est là qu'on revient entre deux missions.
- **Une sortie pour le robot** : il quitte la base par là pour partir en mission et revient par le même chemin. Sa forme
  (grande porte, tunnel, monte-charge géant…) est à décider ; le trajet sert de transition pendant que le niveau se crée.
- **Construite étape par étape** : d'abord la zone vide (sol, parois, plafond, place du robot, sortie), puis les postes,
  puis le reste, une zone à la fois, dans la direction artistique du jeu (voir « Principes qui valent partout »).
- **Deux postes de personnalisation** (un pour son nain, un pour le robot) et **un poste des missions** (voir plus bas).
- **Mini-jeux** : bras de fer (jouable) ; à venir : course de chariots, lancer de nain dans un pneu, wagonnets.
  Les fléchettes se jouent dans le robot (voir « Vie à bord »).
- **Marchand d'améliorations** des nains (à venir).
- **La base grandit** au fil des missions : trophées accrochés au mur, nouveaux outils, plaques des clients satisfaits.
- **Sauvegarde** : tout est gardé chez l'hôte (une partie = une sauvegarde de l'hôte) ; un ami qui revient dans
  la partie retrouve son nain et ses achats. L'économie (argent, prix) sera conçue plus tard.
- **Aujourd'hui** (en attendant la base) : camp minier au fond d'un canyon, au soleil couchant ; les nains apparaissent
  dehors, le robot est garé au centre ; **terminal de mission** devant le robot (2 flèches pour choisir la mission, un
  gros bouton vert pour lancer un compte à rebours de 20 s ; la mission part quand tous les nains sont à bord).

### Les postes de personnalisation (validé le 2026-11-11, à faire)
Deux postes dans la base : un pour **son nain**, un pour **le robot**. Ils remplacent les « marchands de skins ».
On s'y installe et un écran s'ouvre, dans les grandes lignes d'une image donnée par le porteur du projet :
- **À gauche, le modèle en 3D** (son nain ou le robot) posé sur un **socle**, qu'on fait tourner, et qui montre **tout
  de suite** la pièce survolée ; dessous, des flèches pour passer d'une tenue enregistrée à l'autre.
- **Au milieu, une colonne d'icônes**, une par **emplacement** (nain : barbe, moustache, casque, lunettes, tenue,
  couleurs… ; robot : peinture, décorations, bras…). L'emplacement choisi est surligné.
- **À droite, la liste des pièces** de cet emplacement : pour chacune une **vignette**, un **nom**, une petite **phrase
  drôle** et son **prix** ; une pièce pas encore débloquée montre un **cadenas** et ce qu'il faut pour l'avoir.
  Un clic l'essaie, un autre l'achète ou l'équipe.
- **En haut**, l'argent ; **en bas à droite**, un bouton pour fermer.
- Notre propre habillage (direction artistique du jeu, police Fredoka) : on reprend l'organisation, pas le dessin.
- Réseau : le choix de chacun est tenu par l'hôte, vu par tous et sauvegardé.

### Le poste des missions (validé le 2026-11-11, à faire)
Il remplace le terminal à deux flèches. On s'y installe et un écran s'ouvre, dans les grandes lignes d'une image donnée
par le porteur du projet :
- **Au centre, la carte d'une région**, dessinée comme un **plateau découpé en relief** (contour clair, léger volume) sur
  un fond quadrillé.
- **Un pion par mission** posé sur la carte : l'**icône du type de mission** quand elle est jouable, un **cadenas** sinon ;
  la prochaine mission de l'histoire est marquée.
- **À gauche, la fiche de la région** : une image, son nom, ce qu'on y trouve (ressources abondantes ou rares) et un petit
  texte d'ambiance.
- **À droite, la fiche de la mission choisie** : son nom, ses **objectifs** (principal et secondaire), ses **récompenses**,
  sa **durée** et sa **difficulté** en petites icônes.
- **Lancer** : un clic sur un pion ouvre un petit menu (lancer la mission) ; un compte à rebours part et la mission démarre
  quand **tous les nains sont à bord**, comme aujourd'hui.
- Réseau : le pion choisi et le compte à rebours sont tenus par l'hôte et vus par tous.

## L'intro et le tutoriel (validé le 2026-11-09)
- **Point de départ de l'histoire** : les nains achètent un vieux robot à la casse. La première fois qu'on apparaît
  dans une nouvelle partie, on est à la casse, et la première mission est de **ramener le robot jusqu'à la base**.
  Pas de cinématique longue : on joue tout de suite. Une fois à la base, on est dans le lobby normal.
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
- Robot trapu, style « robot cosy mais pas trop » : métal peint, arêtes arrondies, rivets, hublots ronds,
  touches de cuivre. Pas d'ambiance cabane. Il suit la direction artistique du jeu (voir « Principes qui valent partout »).
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
- **Direction artistique : cartoon lisse, « atelier de nains »** (validée le 2026-11-11, remplace le low poly) : formes trapues et un peu exagérées aux arêtes arrondies, contraste entre le froid du décor (roche bleu nuit, pénombre) et le chaud de ce qui vit (lanternes, forge, cuivre, jaune), quelques néons, beaucoup de petits détails. Règles dans `docs/modeles_3d.md`.
- **Coop chaotique** : les commandes sont dans le cockpit, il faut se coordonner et se déplacer.
- **Deux langues** : français et anglais.
- **Rien d'écrit à l'écran, interface sobre** : la place est au jeu, pas aux touches. Ce qu'on peut utiliser se reconnaît en le visant : le **point de visée devient un petit anneau** et l'**objet s'illumine sur ses bords** (lueur chaude qui respire) ; à côté de l'anneau, en petit, l'**icône de l'action** (appuyer, grimper, s'asseoir…), avec sa touche seulement si ce n'est ni le clic ni E (ex. Espace pour lâcher la corde). « Viser » n'est jamais affiché ; la touche pour poser l'objet en main est un petit G sur sa case d'inventaire ; le panneau des touches d'un poste se replie tout seul après 5 s (Tab le rouvre) ; « Échap → quitter » s'efface après 6 s. Au pire de petits mots en police Fredoka.
  Seule exception : la bulle de texte du personnage de la radio (voir « L'intro et le tutoriel »).
  Les infos de jeu (jauges, QTE, tour de qui) sont **dans le cockpit**.
- **Tout ce qui bouge est animé**, rien ne glisse ni ne se téléporte.
- **Tout est synchronisé** : ce qu'un joueur fait, tous le voient (voir `docs/reseau.md`).
