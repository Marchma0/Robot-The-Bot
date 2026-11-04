# Decisions

Format : date - decision - raison

- 2026-11-04 - Stack : Godot 4.7 + GDScript + Jolt, Blender (.glb), reseau hote autoritaire, ENet en dev puis GodotSteam - setup initial
- 2026-11-04 - Une seule scène racine `scenes/main/main.tscn` (menu en CanvasLayer + monde) au lieu d'un changement de scène menu -> jeu - évite que l'hôte réplique un spawn chez un client qui n'a pas encore chargé le MultiplayerSpawner
- 2026-11-04 - Nains spawnés via `MultiplayerSpawner.spawn_function` avec {peer_id, slot} ; nom du nœud = peer id, autorité fixée dans `_enter_tree` - spawn déterministe sur tous les peers, réplication auto pour les arrivées en cours
- 2026-11-04 - Input Map en touches physiques (position QWERTY) - ZQSD en AZERTY et WASD en QWERTY avec un seul binding
- 2026-11-04 - Vue première personne pour les nains - cockpit étroit, et besoin de viser précisément les panneaux en M3 (réversible)
- 2026-11-04 - Nains enfants du cockpit, position synchronisée en local ; détection des plateformes mobiles du CharacterBody3D désactivée - le parent porte déjà le nain, sinon double déplacement
- 2026-11-04 - Gravité et saut du nain suivent le "haut" du cockpit (up_direction = basis.y) - prépare un mécha qui penche
- 2026-11-04 - Mécha = robot trapu (grosse tête trapézoïdale à deux yeux ronds, col, corps en boîte, deux jambes courtes), main gauche grappin, main droite foreuse - direction donnée par le porteur du projet (croquis)
- 2026-11-04 - Deux compartiments : ventre = 2 postes jambes, tête = 2 postes mains ; escalier pour monter, barre de pompier pour descendre - répartit les rôles et crée des déplacements entre les étages
- 2026-11-04 - Style "robot cosy mais pas trop" : low poly, métal peint, chanfreins, rivets, cuivre ; éviter l'ambiance cabane en bois - retour sur le cockpit v1
- 2026-11-04 - Escalier raide façon navire (45°, marches de 25 cm), collision = rampe pleine ; floor_max_angle du nain = 50° - pas de gestion de marches dans le CharacterBody3D, la rampe est fiable et l'escalier tient dans le ventre
- 2026-11-04 - Collisions du mécha en boîtes simples écrites dans `mecha.tscn` (AnimatableBody3D), pas générées depuis le .glb - corps mobile, collisions simples et testées ; à régénérer si les volumes changent
- 2026-11-04 - Modélisation : jamais deux faces au même endroit (cavités de la coque 5 cm derrière les panneaux, pièces décoratives qui dépassent d'1 cm) - évite le z-fighting (textures qui clignotent)
