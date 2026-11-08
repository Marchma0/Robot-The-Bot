class_name HurtOverlay
extends Control
## Flash rouge de douleur sur les bords de l'écran quand on reçoit une fléchette (joueur local uniquement) :
## il apparaît d'un coup et s'efface. Au visage, la vue brouillée (DartBlindOverlay) vient en plus.

const DURATION: float = 0.9
const SHADER_CODE: String = """
shader_type canvas_item;
uniform float amount = 0.0;

void fragment() {
	float d = distance(UV, vec2(0.5)) * 1.4;
	float edge = smoothstep(0.35, 0.95, d);
	COLOR = vec4(0.75, 0.02, 0.0, (edge * 0.85 + 0.12) * amount);
}
"""

var _time: float = 0.0
var _material: ShaderMaterial


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader: Shader = Shader.new()
	shader.code = SHADER_CODE
	_material = ShaderMaterial.new()
	_material.shader = shader
	var rect: ColorRect = ColorRect.new()
	rect.material = _material
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(rect)
	visible = false


func flash() -> void:
	_time = DURATION
	visible = true


## Vrai pendant le flash.
func is_flashing() -> bool:
	return _time > 0.0


func _process(delta: float) -> void:
	if not visible:
		return
	_time = maxf(_time - delta, 0.0)
	var k: float = _time / DURATION
	_material.set_shader_parameter(&"amount", k * k)
	if _time <= 0.0:
		visible = false
