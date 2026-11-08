class_name PlayerHud
extends CanvasLayer
## Interface du joueur local : viseur, touches à l'écran, roue d'emotes, bulle d'état, écran taché,
## mini-jeu des toilettes. Créée par le nain du joueur local seulement (jamais pour ceux des autres).
##
## Réseau : rien. Tout est local au joueur.

@onready var crosshair: Control = %Crosshair
@onready var emote_wheel: EmoteWheel = %EmoteWheel
@onready var state_bubble: StateBubble = %StateBubble
@onready var splat_overlay: SplatOverlay = %SplatOverlay
@onready var poop_game: PoopMinigame = %PoopMinigame
@onready var _hint_bar: HintBar = %HintBar
@onready var _hint_panel: HintPanel = %HintPanel

var _shown_hints: Array[InputHint] = []
var _at_station: bool = false


## Affiche les touches : à un poste (assis devant un écran, ou un levier en main) dans le panneau
## en haut à gauche (repliable avec Tab) ; sinon, petites pastilles en bas au centre.
## Peut être appelé à chaque image : ne refait l'affichage que si quelque chose a changé.
func show_hints(hints: Array[InputHint], at_station: bool) -> void:
	if at_station == _at_station and hints == _shown_hints:
		return
	_at_station = at_station
	_shown_hints = hints
	var empty: Array[InputHint] = []
	_hint_panel.show_hints(hints if at_station else empty)
	_hint_bar.show_hints(empty if at_station else hints)
