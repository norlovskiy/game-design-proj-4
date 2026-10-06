class_name DungeonItemEntry
extends Resource
## One item a pool can hand out.

@export var kind: ItemPickup.Kind = ItemPickup.Kind.SWORD
## Which staff or ring; ignored for the other kinds.
@export_range(0, 2) var variant := 0
@export var weight := 1.0
