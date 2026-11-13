class_name GraphicsSettings
extends RefCounted
## Réglages graphiques du joueur (menu Options) : écran, images par seconde, résolution du rendu, ombres,
## anticrénelage. Gardés dans `user://settings.cfg` sur sa machine et appliqués au lancement.
## Réseau : rien, purement local (chaque joueur règle son propre affichage).

enum Shadows { OFF, LOW, MEDIUM, HIGH }
enum Antialiasing { OFF, FXAA, MSAA_2X, MSAA_4X }

const DEFAULT_PATH: String = "user://settings.cfg"
const SECTION: String = "graphics"
## Limites d'images par seconde proposées (0 = sans limite).
const FPS_LIMITS: Array[int] = [30, 60, 120, 144, 0]
## Taille des textures d'ombre par qualité (OFF : pas d'ombre du tout).
const SHADOW_SIZES: Array[int] = [0, 1024, 2048, 4096]
const RENDER_SCALE_MIN: float = 0.5
## Méta posée sur chaque lumière : son ombre d'origine (rendue quand on rallume les ombres).
const BASE_SHADOW_META: StringName = &"base_shadow"

## Réglages du joueur, chargés au premier appel de `current()`.
static var _current: GraphicsSettings = null

var fullscreen: bool = false
var vsync: bool = true
## Images par seconde max (0 = sans limite).
var fps_limit: int = 0
## Part de la résolution de l'écran à laquelle la 3D est calculée (0,5 à 1), agrandie ensuite (FSR).
var render_scale: float = 1.0
var shadows: Shadows = Shadows.HIGH
var antialiasing: Antialiasing = Antialiasing.OFF
## Fichier où ces réglages sont gardés.
var path: String = DEFAULT_PATH


## Les réglages du joueur (lus sur le disque la première fois).
static func current() -> GraphicsSettings:
	if _current == null:
		_current = load_from(DEFAULT_PATH)
	return _current


## Réglages lus dans `file_path` (valeurs par défaut pour ce qui manque).
static func load_from(file_path: String) -> GraphicsSettings:
	var settings: GraphicsSettings = GraphicsSettings.new()
	settings.path = file_path
	var config: ConfigFile = ConfigFile.new()
	if config.load(file_path) != OK:
		return settings
	settings.fullscreen = config.get_value(SECTION, "fullscreen", settings.fullscreen)
	settings.vsync = config.get_value(SECTION, "vsync", settings.vsync)
	settings.fps_limit = config.get_value(SECTION, "fps_limit", settings.fps_limit)
	settings.render_scale = clampf(config.get_value(SECTION, "render_scale", settings.render_scale), RENDER_SCALE_MIN, 1.0)
	settings.shadows = clampi(config.get_value(SECTION, "shadows", settings.shadows), 0, Shadows.HIGH) as Shadows
	settings.antialiasing = clampi(config.get_value(SECTION, "antialiasing", settings.antialiasing), 0, Antialiasing.MSAA_4X) as Antialiasing
	return settings


func save() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.set_value(SECTION, "fullscreen", fullscreen)
	config.set_value(SECTION, "vsync", vsync)
	config.set_value(SECTION, "fps_limit", fps_limit)
	config.set_value(SECTION, "render_scale", render_scale)
	config.set_value(SECTION, "shadows", shadows)
	config.set_value(SECTION, "antialiasing", antialiasing)
	config.save(path)


## Applique tous les réglages à la fenêtre du jeu et aux lumières déjà présentes.
func apply(tree: SceneTree) -> void:
	var window: Window = tree.root
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = fps_limit
	window.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if render_scale < 0.99 else Viewport.SCALING_3D_MODE_BILINEAR
	window.scaling_3d_scale = render_scale
	window.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if antialiasing == Antialiasing.FXAA else Viewport.SCREEN_SPACE_AA_DISABLED
	match antialiasing:
		Antialiasing.MSAA_2X:
			window.msaa_3d = Viewport.MSAA_2X
		Antialiasing.MSAA_4X:
			window.msaa_3d = Viewport.MSAA_4X
		_:
			window.msaa_3d = Viewport.MSAA_DISABLED
	var size: int = SHADOW_SIZES[shadows]
	if size > 0:
		RenderingServer.directional_shadow_atlas_set_size(size, true)
		window.positional_shadow_atlas_size = size
		var quality: RenderingServer.ShadowQuality = RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM
		if shadows == Shadows.LOW:
			quality = RenderingServer.SHADOW_QUALITY_HARD
		elif shadows == Shadows.MEDIUM:
			quality = RenderingServer.SHADOW_QUALITY_SOFT_LOW
		RenderingServer.directional_soft_shadow_filter_set_quality(quality)
		RenderingServer.positional_soft_shadow_filter_set_quality(quality)
	for light: Node in window.find_children("*", "Light3D", true, false):
		apply_to_light(light as Light3D)


## Ombres coupées : la lumière ne fait plus d'ombre ; sinon elle reprend son réglage d'origine.
## Appelé aussi pour chaque lumière qui arrive en jeu (niveau chargé, objet créé).
func apply_to_light(light: Light3D) -> void:
	if not light.has_meta(BASE_SHADOW_META):
		light.set_meta(BASE_SHADOW_META, light.shadow_enabled)
	light.shadow_enabled = light.get_meta(BASE_SHADOW_META) and shadows != Shadows.OFF
