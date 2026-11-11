# Idées (NON VALIDÉES)

> Pistes proposées, **rien n'est décidé**. Ne rien implémenter d'ici sans validation explicite d'un humain.
> Une idée validée passe dans `docs/jeu.md` (et `docs/decisions.md`), puis dans la roadmap d'`AGENTS.md`.
> Rangées par phase de la roadmap. Ce qui a déjà été fait n'est plus ici (voir `docs/decisions.md`).

## Phase 1 — Fondations

### Modéliser en 3D avec l'IA (proposé le 2026-11-06)
Planche de vues, contrôles PASS / FAIL, réimport du `.glb`, repères d'échelle et règle pour Geometry Nodes
sont faits (voir `docs/modeles_3d.md`). Reste :
- **Croquis de référence** : dessins de face et de profil posés comme plans dans le `.blend`, et comparaison chiffrée de la
  silhouette du modèle avec eux.

Sources : github.com/ozanzeng/blender-LPM-skill, github.com/majidmanzarpour/blender-game-skills,
github.com/colinurbs/claude-modeling-skills, arxiv.org/abs/2403.01248 (SceneCraft), arxiv.org/abs/2508.08228 (LL3M), BlenderGym (CVPR 2025).

## Phase 2 — Les nains

### Améliorations des nains (compétences)
Le marchand d'améliorations des nains est validé ; ce qu'il vend ne l'est pas. Pistes (points de compétence) :
- **Endurance** : grimper plus vite à la corde, courir plus longtemps ;
- **Force** : porter des objets plus lourds dehors, tirer les leviers plus vite ;
- **Adresse** : précision sur les commandes, poser les ponts plus vite ;
- **Ingénieur** : réparer le robot plus vite ;
- **Agilité** : sauter plus haut, s'accroupir et se relever plus vite.
Des compétences qui donnent un rôle à chaque nain sans enfermer personne dans un poste.

### Skins des nains
Barbe, casque, couleurs, choisis devant un miroir ou chez le marchand.

## Phase 3 — Le robot

### Améliorations du robot
Pas dans la vision actuelle (seuls les **skins** du robot sont vendus). Si on en veut un jour, à l'atelier :
jambes plus stables, foreuse plus rapide ou plus longue, grappin plus fort, sac à dos plus grand, meilleurs écrans,
nouveaux postes ou boutons (turbo, ancre, klaxon…).

### Chute physique du robot (anciens M7.3 et « se relever », retirés le 2026-11-06)
Le porteur du projet préfère pour l'instant l'effondrement à genoux.
- **Ragdoll** : os physiques simulés sur l'hôte, pose envoyée environ 20 fois par seconde et lissée chez les autres ;
  les nains dégringolent dans la cabine (gravité du monde au-delà d'une certaine inclinaison) ; consoles accessibles pour le QTE ;
  collisions sur les jambes pour pousser correctement un nain dehors.
- **Se relever après une vraie chute** : transition de la pose ragdoll vers l'animation de relèvement.

### Physique de l'intérieur dans une cabine « fantôme » immobile
La physique du cockpit tourne dans une copie qui ne bouge jamais ; on n'affiche que le résultat, recollé sur le vrai robot
(technique des jeux à bateaux habitables). Les nains ne glissent plus et ne traversent plus les murs même quand le robot
penche fort. Gros chantier : seulement si des problèmes apparaissent.

### Vie à bord
- **Fléchettes dans le salon du ventre** (la cible y est en décor) : même jeu que celui du camp, fléchettes plantées
  synchronisées, ardoise des scores par joueur, partie de « 301 » pendant les trajets, gage du perdant en emote.
  Plus d'imprécision si on bouge ou si le robot marche.
- **Cacas de collection** : raretés (commun marron, rare vert ou bleu, très rare violet à paillettes, légendaire doré) ;
  plus c'est rare, plus « Poussée » est dur. Les rares ne se jettent pas : on les expose sur une **étagère à trophées**
  (salon ou camp), socle + étiquette (nain, date, rareté), sauvegardée avec la partie. Succès « collectionneur »,
  cacas à effets (le doré fait briller la cabine, le violet laisse des paillettes). Le caca doré lancé disparaît pour l'instant (provisoire).

## Phase 4 — Le camp de base

### Monnaie et sauvegarde
- **Argent** (pièces, minerai vendu) selon le résultat de la mission : temps, dégâts, objectifs secondaires, chutes du robot.
- Une partie = une sauvegarde : missions faites, argent, skins et améliorations achetés, objets du camp.
  L'hôte possède la sauvegarde ; les joueurs qui rejoignent retrouvent leur nain (lié au compte Steam / pseudo).
  Plusieurs emplacements, sauvegarde automatique à chaque retour au camp.

### Mini-jeux
- **Course de wagonnets** sur le petit circuit de rails (déjà en décor).
- **Lancer de nain** : canon ou catapulte, cible au loin, score.
- **Lancer de hache** sur une cible en bois.
- **Cible de la foreuse** : s'entraîner à piloter les bras du robot sur des blocs d'entraînement.
- **Bowling avec des tonneaux.**
- **Tir à la corde** à 2 contre 2.
- **Tableau des records** (lancer de nain, course…), sauvegardé avec la partie.

### Le camp qui grandit
Le camp s'agrandit et se décore au fil de l'histoire : trophées des missions réussies, nouveaux bâtiments…
Tableau des missions sous forme de carte avec les 10 missions.

## Phase 5 — Les missions

### Les 10 missions (pistes, à trier)
Chaque mission = un environnement + une mécanique phare (validé). Lesquelles, et l'histoire qui les relie : à décider.
1. **La Mine** : descendre dans une mine, forer les filons, ramasser les pépites au grappin (n'est plus le tutoriel : c'est maintenant la mission « Ramener le robot de la casse », voir `docs/jeu.md`).
2. **La Vallée de la Mort** : canyon plein de gouffres ; sortir du robot, ramasser des troncs, rochers, poutres et construire des ponts assez solides pour le robot.
3. **La Mission sans robot** : robot en panne au fond d'un trou ; les 4 nains à pied vont chercher la pièce de rechange dans une forteresse en ruines (infiltration, énigmes à deux, portes à leviers), puis réparent.
4. **Le Marais** : sol instable, chaque pas peut faire couler une jambe ; lire le terrain, poser des planches, tirer le robot au grappin accroché aux arbres.
5. **La Tempête** : vent violent qui pousse le robot ; s'accroupir et ancrer les pieds au bon moment ; les nains dehors se font emporter.
6. **Le Convoi** : porter une cargaison fragile dans le sac à dos ; une chute ou un choc trop fort la casse.
7. **La Montagne** : escalader une paroi, le grappin en crochet d'escalade, la foreuse en piolet ; coordonner bras et jambes.
8. **Le Géant endormi** : traverser le dos d'une créature gigantesque sans la réveiller ; le bruit compte (marcher lentement, accroupi, couper la foreuse).
9. **La Course** : course contre un robot rival (IA) sur un parcours d'obstacles, raccourcis à la foreuse.
10. **Le Cœur de la Montagne** *(final)* : grande mission en plusieurs étapes qui reprend tout, avec un final spectaculaire.

En réserve :
- mission de **nuit** : phares du robot, un nain dehors avec une lanterne pour guider ;
- **sauvetage** de nains coincés, à attraper au grappin ;
- **démolition** chronométrée d'une vieille tour à la foreuse ;
- **déménagement** d'une maison entière dans le sac à dos ;
- **sous-marine** : le robot marche au fond d'un lac, les nains gèrent l'air (pompes à actionner).

### Rejouer
Rejouer les missions pour de meilleurs scores, ou finir des défis (une étoile par objectif).
