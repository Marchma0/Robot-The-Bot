# Idees de game design (NON VALIDEES)

> Claude : ne rien implementer depuis ce fichier sans validation explicite.

## Synchro réseau et physique (proposé le 2026-11-05)

Constat : la synchro marche mais elle est « brute ». Chaque nain et le mécha envoient leur position environ 60 fois par seconde, sans lissage. Chez les autres, les positions arrivent donc par à-coups. Un nain dehors tremble aussi un peu vu par les autres.

Recommandation : faire **1 à 5 ensemble**, en une étape. Le **6** attend qu'on en ait besoin en M7, le **7** se fera avec M7.3.

1. **Nain dehors synchronisé dans le monde.**
   - Aujourd'hui, la position du nain dehors est envoyée par rapport au mécha. Les autres reçoivent la position du mécha et celle du nain à des moments différents, d'où les tremblements.
   - À la place : envoyer un indicateur « dehors » plus la position dans le monde. Chez les autres, un nain dehors est placé directement dans le monde.
   - Coût faible, uniquement dans le nain.
2. **Lissage des autres joueurs et du mécha.**
   - Chaque joueur affiche les autres avec environ 100 ms de retard, en glissant entre les deux dernières positions reçues.
   - C'est la technique standard des jeux en réseau.
   - Les mouvements restent fluides malgré les paquets en retard ou perdus (relais Steam). Aucun retard sur son propre nain ni sur les commandes qu'on manipule.
   - Un composant réutilisable, posé sur chaque nain et sur le mécha.
3. **Lissage physique de Godot** (option de projet `physics_interpolation`).
   - Affiche les objets entre deux étapes physiques.
   - Mouvement fluide sur les écrans à 120 / 144 Hz.
   - À vérifier avec ce qui est déjà fait à la main (caméra, nain dehors).
4. **Moins de trafic.**
   - Positions envoyées 30 fois par seconde au lieu de 60 : le lissage comble les trous.
   - Les états d'animation regroupés en un seul nombre au lieu de 6 valeurs.
   - Moins de latence et de pertes sur le relais Steam à 4 joueurs.
5. **Ordre de calcul fixe.**
   - À chaque étape physique, le mécha bouge avant que les nains se déplacent.
   - Simple réglage de priorité. Évite des petits décalages quand le robot marchera vraiment (M7).
6. **(Plus tard, M7) Physique de l'intérieur dans une cabine « fantôme » immobile.**
   - La physique du cockpit tourne dans une copie qui ne bouge jamais. On n'affiche que le résultat, recollé sur le vrai robot.
   - C'est la technique des jeux à bateaux et vaisseaux habitables.
   - Les nains ne glissent plus et ne traversent plus les murs, même quand le robot penche fort, tombe ou se relève.
   - Gros chantier : seulement si des problèmes apparaissent en M7.2 / M7.3.
7. **(M7.3) Chute du robot.**
   - Seul l'hôte simule la physique du robot. La pose des os est envoyée environ 20 fois par seconde et lissée chez les autres (point 2).
   - Les jambes du robot ont des collisions, pour pousser correctement un nain dehors.
