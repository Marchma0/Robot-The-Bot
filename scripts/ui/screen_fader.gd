class_name ScreenFader
extends CanvasLayer
## Fondu au noir plein écran (changement de niveau). Purement local : le directeur de mission
## le déclenche chez chaque joueur par RPC.

const FADE_TIME: float = 0.5

var _rect: ColorRect
var _tween: Tween


func _ready() -> void:
	layer = 50
	_rect = ColorRect.new()
	_rect.color = Color(0.06, 0.03, 0.02, 0.0)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_rect)


## Assombrit (true) ou éclaircit (false) l'écran en FADE_TIME secondes.
func fade(to_black: bool) -> void:
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_rect, "color:a", 1.0 if to_black else 0.0, FADE_TIME)
