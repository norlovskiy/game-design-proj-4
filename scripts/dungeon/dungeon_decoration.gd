class_name DungeonDecoration
extends Resource
## A block of tiles stamped into open space: a window, a torch, a barrel.

enum Anchor {
	## Sits on a floor.
	FLOOR,
	## Anywhere in open space.
	WALL,
	## Hangs from a ceiling.
	CEILING,
}

enum Layer {
	## Replaces the background wall. For art with the wall drawn in.
	BACKGROUND,
	## Drawn over the background. For art with transparency.
	PROPS,
}

@export var name := ""
@export var source_id := 0
## Top-left tile of the block in the atlas.
@export var atlas_coords := Vector2i.ZERO
@export var size_in_tiles := Vector2i(2, 2)
@export var layer := Layer.BACKGROUND
@export var anchor := Anchor.WALL
## Chance of appearing at each spot where it fits.
@export_range(0.0, 1.0, 0.01) var chance := 0.1
## 0 means no limit.
@export var max_per_piece := 0
## Map cells kept clear between this and any door.
@export var door_clearance := 1
## Piece names this may appear in. Empty means everywhere.
@export var pieces: PackedStringArray = []
