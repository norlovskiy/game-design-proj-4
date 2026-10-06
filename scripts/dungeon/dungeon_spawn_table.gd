class_name DungeonSpawnTable
extends Resource
## The enemies a dungeon spawns, and the limits shared by all of them.

## Tried in order; earlier rules claim their spots first.
@export var rules: Array[DungeonSpawnRule] = []
## Map cells kept between any two enemies.
@export var min_spacing := 3
## Most enemies in one piece, across all rules. 0 means no limit.
@export var max_per_piece := 3
