# Tests, test du multi, export

> Fait partie des consignes du projet (voir `AGENTS.md`, « Façon de travailler »).

1. Prototyper chaque mécanique dans une scène isolée `tests/sandbox_<feature>.tscn` avant de l'intégrer. Une scène scriptée vérifie elle-même son résultat avec `TestCheck` (`tests/tools/test_check.gd` : `expect`, `finish`, captures ignorées sans fenêtre).
   **Tous les tests d'un coup** (scènes de test en temps accéléré et 4 à la fois, test réseau en temps réel à côté : environ 1 min 45) : `sh tests/tools/run_tests.sh` → `TOUS LES TESTS OK`, à lancer avant de fusionner une branche qui touche au code.
   **Pendant le travail, ne lancer que ce qui concerne la tâche** : `sh tests/tools/run_tests.sh walk fall` (scènes dont le nom contient ces mots), `run_tests.sh reseau` (test réseau seul), `--sans-reseau` (environ 20 s), `--lent` (temps réel, un par un, pour un souci de timing).
   Une scène de test attend en **temps de jeu** (`create_timer`), jamais en temps réel (`Time.get_ticks_msec`) : en accéléré, le temps réel ne suit pas.
2. Tester le multi en local : Godot → Debug → *Customize Run Instances* → 2 à 4 instances (une hôte, les autres clients).
   - À distance : exporter l'exe (`Godot --headless --path . --export-release "Windows Desktop" build/windows/Robot-The-Bot.exe`, puis copier `steam_appid.txt` à côté), envoyer le dossier `build/windows/` zippé, et passer par Steam (lobby / invitation) ou par un VPN type Tailscale en mode local.
   - Les deux joueurs doivent avoir **exactement la même version** (même commit de `main`, ou le même `.exe` exporté), sinon la synchro casse.
