class_name DartBlindOverlay
extends Control
## Vue brouillée tant qu'une fléchette est plantée dans le visage du nain du joueur local (DartsGame) : image floue,
## dédoublée et qui tangue, bords sombres, et un mot pour dire qu'un allié doit venir la retirer.
## Joueur local uniquement ; placée sous le reste de l'interface (les touches restent nettes).

const SHADER_CODE: String = """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float amount = 0.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	uv += vec2(sin(TIME * 1.7 + uv.y * 6.0), cos(TIME * 1.3 + uv.x * 5.0)) * 0.008 * amount;
	vec2 split = vec2(0.015 + 0.006 * sin(TIME * 2.3), 0.004) * amount;
	vec3 a = textureLod(screen_tex, uv + split, 3.5 * amount).rgb;
	vec3 b = textureLod(screen_tex, uv - split, 3.5 * amount).rgb;
	vec3 col = mix(a, b, 0.5);
	float d = distance(UV, vec2(0.5));
	col *= mix(1.0, smoothstep(0.8, 0.2, d), 0.9 * amount);
	col = mix(col, col * vec3(1.0, 0.75, 0.7), 0.35 * amount);
	COLOR = vec4(col, amount);
}
"""

var _active: bool = false
var _amount: float = 0.0
var _material: ShaderMaterial
var _label: Label


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
	_label = Label.new()
	_label.text = tr("Une fléchette en plein visage ! Un allié doit te l'enlever.")
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_override(&"font", preload("res://assets/fonts/fredoka.tres"))
	_label.add_theme_font_size_override(&"font_size", 30)
	_label.add_theme_color_override(&"font_outline_color", Color(0.15, 0.05, 0.02))
	_label.add_theme_constant_override(&"outline_size", 10)
	_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_label.position.y = 90.0
	add_child(_label)
	visible = false


func set_active(active: bool) -> void:
	_active = active
	if active:
		visible = true


func _process(delta: float) -> void:
	if not visible:
		return
	_amount = move_toward(_amount, 1.0 if _active else 0.0, delta * (3.0 if _active else 1.5))
	_material.set_shader_parameter(&"amount", _amount)
	_label.modulate.a = _amount * (0.75 + 0.25 * sin(Time.get_ticks_msec() * 0.006))
	_label.size.x = size.x
	_label.position.x = 0.0
	if _amount <= 0.0 and not _active:
		visible = false
