class_name Enemy
extends CharacterBody2D

var health: int = 1

@export_range(1, 100000, 1) var max_health: int = 1:
	set(value):
		max_health = maxi(value, 1)
		if is_node_ready():
			health = mini(health, max_health)
		else:
			health = max_health


func take_damage(amount: int) -> void:
	health = maxi(health - maxi(amount, 0), 0)
