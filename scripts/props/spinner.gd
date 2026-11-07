class_name Spinner
extends Node3D
## Fait tourner le nœud sur lui-même (décor : rotor d'éolienne…). Purement visuel et local,
## rien sur le réseau : la vitesse varie doucement, comme avec des rafales de vent.

## Axe de rotation local, et vitesse moyenne (tours par seconde).
@export var axis: Vector3 = Vector3.FORWARD
@export var turns_per_second: float = 0.35
## Variation de la vitesse (fraction) et durée d'une rafale (s).
@export var gust: float = 0.4
@export var gust_period: float = 6.0

var _time: float = 0.0


func _process(delta: float) -> void:
	_time += delta
	var speed: float = turns_per_second * (1.0 + gust * sin(_time * TAU / gust_period) * sin(_time * 0.7))
	rotate_object_local(axis.normalized(), speed * TAU * delta)
