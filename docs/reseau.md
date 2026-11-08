# Modèle réseau — comment rendre une interaction visible par tout le monde

> À lire **avant** de coder une interaction, un objet ou un niveau. Les règles courtes sont dans
> `AGENTS.md` (« Architecture réseau ») ; ici, le pourquoi et les recettes.

## Le principe : l'hôte décide, tout le monde voit le résultat

```
 client                    hôte (peer 1)                         tous les joueurs
 ──────                    ─────────────                         ────────────────
 appuie sur E  ──RPC──▶  vérifie (portée, libre…)
                          change une variable d'état  ──synchro──▶  voient le nouvel état
                          (et/ou) effet ponctuel      ──RPC─────▶  jouent l'effet (son, éclats…)
```

1. **Le client demande, il ne fait rien lui-même** : `objet.request_xxx.rpc_id(1)` avec
   `@rpc("any_peer", "call_local", "reliable")`. L'hôte vérifie puis applique. L'hôte passe par
   le même chemin (`call_local`) : pas de code à part pour lui.
2. **Un état qui dure** (porte ouverte, rocher cassé, siège occupé, contenu du sac…) est une
   **variable** de l'objet, répliquée par un `MultiplayerSynchronizer` de l'objet, avec
   `spawn = true` (sinon un joueur qui arrive en cours de partie ne la reçoit pas) et
   `replication_mode = On Change` (`2`). Les clients dessinent l'objet à partir de cette variable.
3. **Un effet d'un instant** (éclats, nuage, son, animation d'appui) : `@rpc("authority", "call_local",
   "reliable")` envoyé par l'hôte. Jamais pour un état qui dure : un joueur qui arrive après ne le
   verrait pas.
4. **Ce qui bouge en continu** (bras, robot, objet qui vole) : variable en `Always` (`1`), lissée
   chez les clients si besoin (`NetSmoother`).

## Les trois pièges qui cassaient la synchro (S1, 2026-11-08)

| Piège | Ce qu'on voyait | Règle |
|---|---|---|
| Le niveau était chargé par chaque joueur de son côté | Rochers, terminal, mini-jeux jamais synchronisés chez le client (`Node not found` dans la console : Godot abandonne pour de bon) | Le niveau est **créé par l'hôte** via le `LevelSpawner` de `MissionDirector`. Ne jamais charger une scène qui contient des objets réseau autrement que par un spawner. |
| Objet créé ou supprimé en jeu sans spawner | Caisse de minerai invisible, caisse rangée toujours là chez le client | Tout objet qui **apparaît / disparaît** en jeu est créé par l'hôte **sous un `NetSpawner`** (sa scène dans la liste du spawner). Supprimer = `queue_free()` chez l'hôte, le spawner le retire partout. |
| Place fixée **après** `add_child`, ou pas synchronisée | Caisse à (0, 0, 0) chez le client | Régler `position` / propriétés **avant** `add_child`, et mettre `position` (+ `rotation`) dans le synchroniseur de l'objet avec `spawn = true`. |

Et un piège moteur : un `RigidBody3D` **figé** doit être en `FREEZE_MODE_STATIC`. En
`FREEZE_MODE_KINEMATIC`, Jolt réécrit parfois une ancienne place quand le parent bouge (le caca
restait derrière quand le robot était téléporté).

## Recettes

### Une commande dans le robot (bouton, levier, siège…)
Hériter d'`Interactable` (ou d'une commande existante) et surcharger `interact(press, grab, hands_free)` :
elle envoie la RPC `request_xxx` vers l'hôte et renvoie `Use.DONE` (action instantanée) ou `Use.CLAIM`
(objet qu'on va tenir ou occuper). L'`Interactor` n'a pas à changer. L'hôte vérifie `is_peer_in_reach` ;
les variables d'état vont dans le `MultiplayerSynchronizer` de sa scène.
Un objet qu'on **tient ou occupe** (levier, siège, corde) : groupe `Possession.GROUP`,
une ligne dans `Possession.holder_of`, surcharger `stows_hand_item` (vrai : l'objet en main est rangé), et l'hôte refuse la demande si
`Possession.is_peer_busy` (une seule chose à la fois, pas d'objet lourd porté).
Un objet qu'on **met dans l'inventaire** (caca, fléchettes) : groupe `Inventory.GROUP`, l'objet garde lui-même
qui l'a et dans quelle case (variables synchronisées) et a les méthodes `inventory_entries`, `throw_from_hand`,
`drop_from_hand` (voir `scripts/player/inventory.gd`) ; à la demande, l'hôte prend la case `Inventory.free_slot`
(refus si -1 ou `Possession.holds_control`). La case choisie (`Dwarf.hand_slot`) est écrite par le joueur et répliquée ;
un objet n'est en main que si `Inventory.is_in_hand` (bonne case, aucune commande tenue). Objet lourd : `"heavy": true`
dans son entrée (`CargoCrate`).
Le robot est dans `main.tscn` : ses commandes existent déjà chez tout le monde.

### Un objet qu'on ramasse, qui casse, qui apparaît (caisse, caca…)
- Sa scène a un `MultiplayerSynchronizer` : place (`position`, `rotation` ou une variable `Transform3D`)
  + son état, tous en `spawn = true`.
- Elle est rangée sous un nœud surveillé par un **`NetSpawner`** (`scripts/network/net_spawner.gd`)
  qui la liste dans *Auto Spawn List*.
- On peut la **poser à la main dans l'éditeur** sous ce nœud : au chargement, l'hôte la reprend
  et l'envoie aux clients (leurs copies locales sont supprimées). Pas besoin de marqueurs.
- Créée en jeu : par l'hôte uniquement, place réglée **avant** `add_child(objet, true)`.

### Un nouveau niveau
L'ajouter à `MissionDirector.LEVELS`. Ses objets réseau suivent la recette ci-dessus (un
`NetSpawner` par dossier d'objets, comme `CargoSpawner` dans `test_ground.tscn`). Rien d'autre :
le `LevelSpawner` s'occupe d'envoyer le niveau à tout le monde, y compris en cours de partie.

## Les garde-fous

- **Test automatique** (obligatoire avant de fusionner dans `main` quand on touche au réseau,
  aux objets ou aux interactions) :
  ```
  sh tests/tools/net_test.sh
  ```
  Lance un hôte et un client sans fenêtre (ENet local) ; l'hôte prépare une partie, le client arrive
  en cours de route, puis on enchaîne les actions (rochers, caisses, sac, cacas, grappin, foreuse,
  boutons, leviers, sièges, porte, rayon, terminal, fléchettes, bras de fer, changements de niveau).
  Après chaque étape : l'hôte compare ce qu'il voit et ce que voit le client (`NetAudit`), et vérifie
  qu'une demande du client a bien eu un effet. Sortie : `NET TEST OK` ou la liste des écarts.
  Journaux complets dans `build/net_test_host.log` et `build/net_test_client.log`.
  **Une nouvelle interaction = une étape de plus dans `tests/tools/net_test.gd`** (`_client_step` : la demande doit changer quelque chose chez l'hôte ; `_client_refused` : une demande interdite ne change rien).
- **F9 en partie** (même en Steam, chez n'importe quel joueur) : l'hôte envoie sa « photo » du monde,
  chaque client la compare à la sienne ; « OK » ou le nombre d'écarts s'affiche en haut à gauche, le
  détail dans la console. À faire quand quelque chose a l'air différent chez l'autre.
- **Console de l'hôte** : `Réseau : « … » est créé hors d'un MultiplayerSpawner` = un objet réseau
  créé en jeu que les clients ne verront jamais (`scripts/network/net_guard.gd`).

## Limites connues
- Les fléchettes plantées dans la cible ne sont envoyées qu'au lancer (RPC) : un joueur qui arrive
  pendant une manche voit les scores, pas les fléchettes plantées.
- Le test automatique tourne en ENet. Steam utilise exactement la même réplication Godot
  (`SteamMultiplayerPeer` ne fait que transporter les paquets) : en cas de doute, F9 en partie Steam.
