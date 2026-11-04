# Decisions

Format : date - decision - raison

- 2026-11-04 - Stack : Godot 4.7 + GDScript + Jolt, Blender (.glb), reseau hote autoritaire, ENet en dev puis GodotSteam - setup initial- 2026-11-04 - Une seule scène racine `scenes/main/main.tscn` (menu en CanvasLayer + monde) au lieu d'un changement de scène menu -> jeu - évite que l'hôte réplique un spawn chez un client qui n'a pas encore chargé le MultiplayerSpawner
- 2026-11-04 - Nains spawnés via `MultiplayerSpawner.spawn_function` avec {peer_id, slot} ; nom du nœud = peer id, autorité fixée dans `_enter_tree` - spawn déterministe sur tous les peers, réplication auto pour les arrivées en cours
- 2026-11-04 - Input Map en touches physiques (position QWERTY) - ZQSD en AZERTY et WASD en QWERTY avec un seul binding
