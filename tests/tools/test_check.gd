class_name TestCheck
extends RefCounted
## Petits outils communs aux scènes de test (`tests/sandbox_*.tscn`) :
## - vérifications qui écrivent « [test] OK … » ou « [test] ÉCHEC … » (lues par `tests/tools/run_tests.sh`) ;
## - captures d'écran ignorées sans fenêtre (mode `--headless`) ;
## - mode automatique (`-- --auto`) : la scène se ferme toute seule à la fin, avec un code de sortie.

static var _failures: int = 0


## Vrai si la scène a été lancée par le script de tests (`-- --auto`).
static func is_auto() -> bool:
	return OS.get_cmdline_user_args().has("--auto")


## Note une vérification : « OK » ou « ÉCHEC » dans la console.
static func expect(condition: bool, label: String) -> void:
	if condition:
		print("[test] OK     %s" % label)
	else:
		_failures += 1
		print("[test] ÉCHEC  %s" % label)


## Résultat final et fermeture (code de sortie 1 s'il y a eu un échec).
static func finish(tree: SceneTree) -> void:
	if _failures == 0:
		print("[test] FIN OK")
	else:
		print("[test] FIN ÉCHEC (%d vérification(s) ratée(s))" % _failures)
	tree.quit(1 if _failures > 0 else 0)


## À attendre avant une capture : l'image suivante dessinée (sans fenêtre, rien n'est dessiné : l'image suivante tout court).
## Usage : `await TestCheck.frame_drawn(get_tree())`.
static func frame_drawn(tree: SceneTree) -> Signal:
	return tree.process_frame if DisplayServer.get_name() == "headless" else RenderingServer.frame_post_draw


## Enregistre l'image de la vue, sauf sans fenêtre (rien à capturer).
static func save_view(viewport: Viewport, path: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	viewport.get_texture().get_image().save_png(path)
