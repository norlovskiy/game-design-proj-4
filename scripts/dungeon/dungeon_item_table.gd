class_name DungeonItemTable
extends Resource
## The item pools a dungeon spawns pickups from.

@export var pickup_scene: PackedScene = preload("res://scenes/item_pickup.tscn")
## Handled in order. A room named by more than one pool uses the first.
@export var pools: Array[DungeonItemPool] = []
