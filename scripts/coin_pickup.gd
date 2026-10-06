class_name CoinPickup
extends CharacterBody2D
## A coin that falls to the ground and is collected when the player touches
## it.

## Seconds before it can be collected, so drops are seen to land first.
const PICKUP_DELAY := 0.35
const FRICTION := 500.0

@export var value := 1

var _age := 0.0
var _gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity", 980.0)

@onready var _collect_area: Area2D = $CollectArea


func _physics_process(delta: float) -> void:
	_age += delta
	velocity.y += _gravity * delta
	if is_on_floor():
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
	move_and_slide()
	if _age < PICKUP_DELAY:
		return
	for body in _collect_area.get_overlapping_bodies():
		if body.has_method("add_gold"):
			body.add_gold(value)
			queue_free()
			return
