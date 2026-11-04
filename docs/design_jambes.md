# Design — Les jambes du mécha (M7)

Statut : **validé** par le porteur du projet (2026-11-04). Implémentation découpée en M7.1 à M7.6 (voir `CLAUDE.md`).

## Description (texte du porteur du projet)

- **Déplacement (Joystick & IK)** : chaque joueur déplace un curseur virtuel au sol avec son joystick. L'IK (cinématique inverse) plie automatiquement le genou pour poser le pied à cet endroit.
- **Équilibre (Physique)** : le robot gère un centre de gravité réel. Si un joueur fait un pas trop grand sans que l'autre compense, le robot bascule.
- **Rotation et marche arrière** : tirer le joystick vers soi recule le pied. L'écarter sur le côté fait pivoter le bassin (technique du pas chassé).
- **Chute (Ragdoll)** : en cas de perte d'équilibre, le système de marche s'arrête. Le robot s'effondre mollement au sol sous l'effet de la physique.
- **Actions spéciales aux murs** : les joueurs doivent lâcher leur joystick de marche et se déplacer vers un panneau mural de leur cabine pour interagir avec le robot (s'accroupir, se relever).
- **Saut directionnel hybride (Joystick + QTE)** : maintenir une direction au joystick est une étape obligatoire de la séquence de saut. Un joueur gère l'orientation au joystick pendant que les étapes au mur sont exécutées, pour sauter dans la direction choisie.
- **QTE « antisèches »** : aucune touche ne s'affiche à l'écran. Les combinaisons restent toujours les mêmes et sont gravées directement sur les murs de la cabine par l'ancien propriétaire.
- **Coopération asymétrique** : chaque combinaison demande l'action des deux joueurs dans un ordre précis, chacun s'occupant de ses propres tâches et boutons de son côté.
- **Se relever (animation)** : après une chute, réussir la séquence de redémarrage fige la physique et lance une animation classique pour remettre le robot sur ses pieds, avant de rendre le contrôle des joysticks.

## Choix retenus

- **Lever / poser le pied** : pousser le joystick **lève le pied** et déplace le curseur ; **relâcher le joystick pose le pied** sur le curseur. Le joystick revient au centre tout seul (ressort). On voit facilement qui a un pied en l'air.
- **Voir son curseur** : un **anneau lumineux au sol**, visible par tous (aussi par le hublot du ventre), plus un **petit écran « vue des pieds »** sur chaque console de jambe.
- **Consoles du ventre** : **1 joystick (toutes directions) + 1 pad à 4 flèches par jambe** (en place depuis le 2026-11-04 ; le rôle du pad reste à définir). Les autres commandes (boutons, leviers) vont sur les **panneaux muraux**.

## Approche technique

- **Hybride piloté / physique.** Debout, le robot n'est pas un objet physique libre : l'hôte calcule la position des pieds, le bassin et le centre de gravité ; l'IK plie les jambes. Quand l'équilibre est perdu, on bascule en vraie physique (ragdoll). Pour se relever, on fige la physique et on joue une animation.
- **Hôte autoritaire.** Les clients n'envoient que la valeur de leur joystick (déjà en place avec M3, `unreliable_ordered`). L'hôte simule et synchronise l'**état** : position des pieds, curseurs, bassin, phase (`STANDING`, `FOOT_LIFTED`, `CROUCHED`, `AIRBORNE`, `FALLING`, `GETTING_UP`…). Chaque client calcule l'IK lui-même à partir de cet état. Pendant une chute, l'hôte synchronise la pose des os.
- **Squelette.** Jambes remodelées en cuisse + tibia + pied, os nommés `pelvis`, `leg_L_thigh`, `leg_L_shin`, `leg_L_foot` (et `_R`). Pièces rigides attachées aux os (low poly mécanique).
- **IK.** IK à 2 os (cuisse + tibia). Nœud IK de Godot 4.7 s'il convient, sinon calcul analytique maison (simple et déterministe).
- **Bassin.** Il suit les pieds posés (vers leur milieu, avec lissage). L'écart latéral du joystick fait pivoter le bassin.
- **Équilibre.** Le centre de gravité projeté au sol est comparé à la zone d'appui (enveloppe des pieds posés). En dehors, le robot penche de plus en plus (ressenti dans la cabine), puis passe le point de non-retour → chute.
- **Chute.** Os physiques (`PhysicalBone3D` / simulateur d'os physiques) activés sur l'hôte uniquement. Les nains à l'intérieur dégringolent : au-delà d'une certaine inclinaison, leur gravité devient celle du monde (et plus le « bas » du cockpit).
- **Séquences (QTE antisèches).** Un système de séquences côté hôte : liste ordonnée d'étapes, chacune attribuée au joueur de gauche ou de droite et liée à une commande murale (bouton, levier). L'hôte vérifie l'ordre et le rôle ; une erreur annule la séquence. Les combinaisons sont des gravures / plaques modélisées dans Blender, rien à l'écran.
- **Saut.** La direction tenue au joystick pendant la séquence donne la direction du saut ; trajectoire calculée par l'hôte ; une réception déséquilibrée fait chuter le robot.
