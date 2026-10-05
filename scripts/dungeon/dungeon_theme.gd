class_name DungeonTheme
extends Resource
## The look of a dungeon: a tileset plus the rules for painting it.

@export var tile_set: TileSet
## Small tiles per map cell along each axis. 2 means a 16 px tileset paints
## 32 px cells.
@export var tiles_per_cell := 2
@export var tile_rules: Array[DungeonTileRule] = []
## Tried in order; earlier decorations claim their spots first.
@export var decorations: Array[DungeonDecoration] = []
