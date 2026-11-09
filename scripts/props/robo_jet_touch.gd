class_name RoboJetTouch
extends Interactable
## L'écran de la télé, à viser : un clic (ou E) = un coup de réacteur pendant sa partie de Robo-Jet, ou lancer
## une partie si personne ne joue. Utilisable aussi depuis le canapé (`usable_seated`).
## Réseau : voir RoboJetGame (le coup de réacteur est joué tout de suite chez le joueur).

@export var game: RoboJetGame


func interact(press: bool, grab: bool, _hands_free: bool) -> Use:
	if not (press or grab) or game == null or not game.tv.is_on():
		return Use.NONE
	game.tap()
	return Use.DONE


## Avec un objet en main, le clic sur l'écran joue (il ne lance pas l'objet sur la télé).
func takes_click_with_item() -> bool:
	return game != null and game.tv.is_on()


func get_hints() -> Array[InputHint]:
	if game == null or not game.tv.is_on():
		return []
	var me: int = multiplayer.get_unique_id()
	if game.running and game.player_peer != me:
		return [InputHint.state(&"locked")]   # quelqu'un d'autre joue
	return [InputHint.make(&"grab", &"robo_jet")]


func _get_highlight_meshes() -> Array[GeometryInstance3D]:
	return []   # l'écran ne s'illumine pas (on le regarde pour jouer) : l'anneau du viseur suffit
