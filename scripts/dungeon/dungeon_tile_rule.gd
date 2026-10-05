class_name DungeonTileRule
extends Resource
## Which tileset tiles to paint for one situation.
##
## Each map cell is painted as a block of small tiles, and every small tile is
## classified by which of its sides face open space. Several rules may share a
## situation; one is picked by weight.

enum Situation {
	## Wall behind everything.
	BACKGROUND,
	## Solid with no open side.
	INNER,
	## Solid with open space above (a floor surface).
	TOP,
	## Solid with open space below (a ceiling).
	BOTTOM,
	LEFT,
	RIGHT,
	TOP_LEFT,
	TOP_RIGHT,
	BOTTOM_LEFT,
	BOTTOM_RIGHT,
	PLATFORM_LEFT,
	PLATFORM_MIDDLE,
	PLATFORM_RIGHT,
}

@export var situation := Situation.INNER
@export var source_id := 0
## Top-left tile of the pattern in the atlas.
@export var atlas_coords := Vector2i.ZERO
## Tiles in the pattern. A pattern larger than 1x1 repeats across the map, so
## a seamless 2x2 brick patch stays seamless.
@export var pattern_size := Vector2i.ONE
@export var weight := 1.0
## Piece names this rule applies to (room names, "hall", "shaft",
## "dead_end"). Empty means everywhere. A rule naming a piece replaces the
## general rules there.
@export var pieces: PackedStringArray = []
