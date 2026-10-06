@tool
class_name DungeonSpawnRule
extends Resource
## Where and how often one kind of enemy appears.

enum Placement {
	## Standing on a floor.
	FLOOR,
	## Floating, with an open cell above and below.
	AIR,
}

@export var enemy: PackedScene
@export var placement := Placement.FLOOR
## Chance of spawning at each cell where the enemy fits.
@export_range(0.0, 1.0, 0.01) var chance := 0.1
## 0 means no limit.
@export var max_per_piece := 2
## Piece names this enemy may spawn in ("hall", "shaft", "dead_end", or a
## room name).
@export var pieces: PackedStringArray = ["hall"]
## Open cells a floor enemy needs above its feet, counting the one it
## stands in.
@export var height_in_cells := 2
## Map cells kept clear between the enemy and any door.
@export var door_clearance := 2
## How many pieces from the start room before this enemy can appear. The
## first corridor off the start room is 1.
@export var min_depth := 1
## Added to the spawn point, in pixels. Floor enemies spawn at the middle of
## the cell's floor, air enemies at the middle of the cell.
@export var offset := Vector2.ZERO
