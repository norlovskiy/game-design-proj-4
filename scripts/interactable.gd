class_name Interactable
extends Area2D
## Something the player can use with the pickup key while standing in it.

signal interacted(player: Node)


func interact(player: Node) -> void:
	interacted.emit(player)
