class_name DungeonSpawnTable
extends Resource
## The enemies a dungeon spawns, and the limits shared by all of them.

## Tried in order; earlier rules claim their spots first.
@export var rules: Array[DungeonSpawnRule] = []
## Map cells kept between any two enemies.
@export var min_spacing := 3
## Most enemies in one piece, across all rules. 0 means no limit.
@export var max_per_piece := 3
## Fewest enemies in a dungeon, per 10 corridor pieces (halls, shafts and
## dead ends), so bigger dungeons get more. If the chance rolls come up
## short, extra enemies are added at spots that still fit every limit.
@export_range(0.0, 30.0, 0.5) var min_per_10_corridors := 6.0
