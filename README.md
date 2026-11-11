# Robot-The-Bot

Jeu coop 3D à 4 joueurs (Godot 4.7, GDScript) : quatre nains pilotent un mécha depuis l'intérieur.
Consignes complètes du projet (pour les humains et les IA) : [AGENTS.md](AGENTS.md).

## Installation pour un nouveau développeur

1. **Installer** : [Git](https://git-scm.com/), **Godot 4.7.2** (exactement cette version), [Blender](https://www.blender.org/),
   et son outil IA (Claude Code ou Antigravity).
2. **Cloner** le dépôt, puis dans le dossier du projet :
   ```powershell
   git config user.name "TonPseudo"
   git config user.email "ton@email"
   ```
3. **Addons** : installer GodotSteam en suivant [addons/ADDONS.txt](addons/ADDONS.txt) (le dossier `addons/` n'est pas versionné).
4. **Ouvrir le projet dans Godot** une première fois et attendre la fin de l'import.
5. **Variable d'environnement** `GODOT_PATH` = chemin complet de l'exécutable Godot (utilisée par le MCP Godot) :
   ```powershell
   setx GODOT_PATH "C:\chemin\vers\Godot_v4.7.2-stable_win64.exe"
   ```
   Puis redémarrer l'éditeur de code.
6. **MCP** (pour que l'IA lance le jeu et pilote Blender) :
   - Claude Code : rien à faire, `.mcp.json` est versionné.
   - Antigravity : ajouter dans sa config MCP (menu « … » de l'agent → MCP Servers → Manage → View raw config) :
     ```json
     {
       "mcpServers": {
         "godot": {
           "command": "cmd",
           "args": ["/c", "npx", "-y", "@coding-solo/godot-mcp"],
           "env": { "GODOT_PATH": "C:/chemin/vers/Godot_v4.7.2-stable_win64.exe" }
         },
         "blender": {
           "command": "cmd",
           "args": ["/c", "uvx", "blender-mcp"]
         }
       }
     }
     ```
     Prérequis : [Node.js](https://nodejs.org/) (pour `npx`) et [uv](https://docs.astral.sh/uv/) (pour `uvx`) ; dans Blender, l'addon `blender-mcp` installé et connecté.
7. **Consignes IA** : Claude Code lit `CLAUDE.md`, Antigravity lit `.agent/rules/robot-the-bot.md` ; les deux renvoient à `AGENTS.md`.
   Vérifier dans Antigravity (Customizations → Rules) que la règle `robot-the-bot` est bien en « Always On ».

## Travailler à deux
Résumé (détail dans la section « Travail à deux » d'[AGENTS.md](AGENTS.md)) :
- `git pull` avant de commencer ; une branche `pseudo-github/sujet` par tâche ; l'IA la fusionne elle-même dans `main` (pas de Pull Request).
- Marquer dans la roadmap la tâche qu'on prend.
- Ne jamais modifier le même `.blend` / `.glb` / `.tscn` que l'autre en même temps.

## Tester le multi en local
Godot → Debug → *Customize Run Instances* → 2 à 4 instances (une hôte, les autres clients).

## Arborescence
```
project.godot
addons/            # plugins tiers (GodotSteam, etc.) — ne pas modifier, NON versionnés : liste + installation dans addons/ADDONS.txt
assets/
  models/          # .glb exportés depuis Blender
  textures/ audio/ fonts/
  translations/    # texts.csv : tous les textes du jeu, français + anglais
blender/           # fichiers sources .blend (pas importés par Godot, voir .gdignore)
scenes/
  main/            # menus, lobby, scène de jeu racine
  mecha/           # le mécha, ses jambes, son cockpit
  player/          # le nain
  levels/
scripts/
  network/         # NetworkManager (autoload), lobby, spawn
  mecha/           # contrôle, IK, équilibre, stations
  player/
  interaction/     # système générique d'interaction (stations, panneaux)
docs/              # jeu.md, decisions.md, ideas.md, reseau.md (voir « Les documents du projet » d'`AGENTS.md`)
tests/             # scènes de test isolées (sandbox_*.tscn), outils de test (tests/tools/)
```
