class_name MechaWorkshop
extends StaticBody3D
## Console d'atelier du garage permettant de modifier les skins et les bras du robot (roadmap 3.8 / 4.5 / 4.7).
## Quatre boutons poussoirs physiques :
## - `SkinPrev` / `SkinNext` : changent le skin complet du robot (peinture + ornements 3D) ;
## - `ArmPrev` / `ArmNext` : changent la configuration des bras (Standard, Inversé, Minage Titan, Électro-Aimant).
##
## Réseau : les boutons sont des `PushButton` (l'hôte valide la portée et émet `pressed`). L'hôte met à jour
## `MechaCustomizer` sur le robot (`skin_index` et `arm_mode`, synchronisés) ; chaque peer met à jour l'écran.

const SCREEN_SIZE: Vector2i = Vector2i(560, 340)
const FONT: FontVariation = preload("res://assets/fonts/fredoka.tres")
const SCREEN_SHADER: Shader = preload("res://scenes/mecha/controls/camera_feed_screen.gdshader")

var _skin_label: Label
var _skin_pager: Label
var _arm_label: Label
var _arm_pager: Label

@onready var _skin_prev: PushButton = %SkinPrev
@onready var _skin_next: PushButton = %SkinNext
@onready var _arm_prev: PushButton = %ArmPrev
@onready var _arm_next: PushButton = %ArmNext
@onready var _screen: MeshInstance3D = %Screen
@onready var _viewport: SubViewport = %ScreenViewport


func _ready() -> void:
	_build_screen()
	_skin_prev.pressed.connect(func(_peer_id: int) -> void: _on_skin(-1))
	_skin_next.pressed.connect(func(_peer_id: int) -> void: _on_skin(1))
	_arm_prev.pressed.connect(func(_peer_id: int) -> void: _on_arm(-1))
	_arm_next.pressed.connect(func(_peer_id: int) -> void: _on_arm(1))


func _process(_delta: float) -> void:
	var customizer: MechaCustomizer = _customizer()
	if customizer == null:
		return
	_skin_label.text = customizer.skin_title()
	_skin_pager.text = "◄  %s %d / %d  ►" % [tr("SKIN"), customizer.skin_index + 1, MechaCustomizer.SKIN_COUNT]
	_arm_label.text = customizer.arm_title()
	_arm_pager.text = "◄  %s %d / %d  ►" % [tr("BRAS"), customizer.arm_mode + 1, MechaCustomizer.ARM_MODE_COUNT]


func _on_skin(step: int) -> void:
	var customizer: MechaCustomizer = _customizer()
	if customizer != null:
		customizer.cycle_skin(step)


func _on_arm(step: int) -> void:
	var customizer: MechaCustomizer = _customizer()
	if customizer != null:
		customizer.cycle_arm_mode(step)


func _customizer() -> MechaCustomizer:
	return get_tree().get_first_node_in_group(MechaCustomizer.GROUP) as MechaCustomizer


func _build_screen() -> void:
	_viewport.size = SCREEN_SIZE
	var root: ColorRect = ColorRect.new()
	root.color = Color(0.05, 0.08, 0.11)
	root.size = Vector2(SCREEN_SIZE)
	_viewport.add_child(root)
	var column: VBoxContainer = VBoxContainer.new()
	column.position = Vector2(24, 16)
	column.size = Vector2(SCREEN_SIZE) - Vector2(48, 32)
	column.add_theme_constant_override(&"separation", 8)
	root.add_child(column)
	column.add_child(_label(tr("ATELIER DU ROBOT"), 24, Color(1.0, 0.72, 0.28)))
	_skin_pager = _label("", 24, Color(0.65, 0.90, 1.0))
	column.add_child(_skin_pager)
	_skin_label = _label("", 34, Color(0.95, 0.98, 1.0))
	column.add_child(_skin_label)
	_arm_pager = _label("", 24, Color(1.0, 0.78, 0.42))
	column.add_child(_arm_pager)
	_arm_label = _label("", 28, Color(0.95, 0.98, 1.0))
	column.add_child(_arm_label)
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = SCREEN_SHADER
	material.set_shader_parameter(&"feed", _viewport.get_texture())
	material.set_shader_parameter(&"tint", Color(0.88, 0.96, 1.0))
	material.set_shader_parameter(&"noise", 0.10)
	_screen.material_override = material


func _label(text: String, size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_override(&"font", FONT)
	label.add_theme_font_size_override(&"font_size", size)
	label.add_theme_color_override(&"font_color", color)
	return label
