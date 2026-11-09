class_name PlayerHud
extends CanvasLayer
## Interface du joueur local : viseur, touches à l'écran, barre d'inventaire, roue d'emotes, bulle d'état, écran taché, vue brouillée par une fléchette au visage,
## flash rouge de douleur,
## mini-jeu des toilettes. Créée par le nain du joueur local seulement (jamais pour ceux des autres).
## Interface sobre : ce qu'on peut utiliser se reconnaît à l'anneau du viseur (Crosshair) et à la lueur de
## l'objet visé (Interactable) ; à côté de l'anneau, en petit, l'icône de l'action, avec sa touche seulement
## si ce n'est pas le clic (InputHint.is_obvious). « Viser » n'est jamais affiché.
##
## Réseau : rien. Tout est local au joueur.

@onready var crosshair: Crosshair = %Crosshair
@onready var emote_wheel: EmoteWheel = %EmoteWheel
@onready var state_bubble: StateBubble = %StateBubble
@onready var splat_overlay: SplatOverlay = %SplatOverlay
@onready var dart_blind: DartBlindOverlay = %DartBlind
@onready var hurt_overlay: HurtOverlay = %HurtOverlay
@onready var poop_game: PoopMinigame = %PoopMinigame
@onready var inventory_bar: InventoryBar = %InventoryBar
@onready var _hint_bar: HintBar = %HintBar
@onready var _hint_panel: HintPanel = %HintPanel

var _shown_hints: Array[InputHint] = []
var _at_station: bool = false


## Affiche les touches : à un poste (assis devant un écran, ou un levier en main) dans le panneau
## en haut à gauche (replié tout seul après quelques secondes, Tab le rouvre) ; sinon, en petit à droite
## du point de visée. `aiming` : le joueur vise une commande (le viseur devient un anneau).
## Peut être appelé à chaque image : ne refait l'affichage que si quelque chose a changé.
func show_hints(hints: Array[InputHint], at_station: bool, aiming: bool) -> void:
	crosshair.set_targeting(aiming and not at_station, InputHint.only_states(hints))
	if at_station == _at_station and hints == _shown_hints:
		return
	_at_station = at_station
	_shown_hints = hints
	var kept: Array[InputHint] = InputHint.shown(hints)
	var empty: Array[InputHint] = []
	_hint_panel.show_hints(kept if at_station else empty)
	_hint_bar.show_hints(empty if at_station else kept)
