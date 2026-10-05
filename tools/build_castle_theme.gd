extends SceneTree
## Writes the first-pass castle tileset and theme from the tilesheet.
##
## Run: godot --headless --path . -s tools/build_castle_theme.gd
##
## This OVERWRITES assets/tilesets/castle_tileset.tres and
## data/themes/castle_theme.tres, including any edits made in the editor.
## Only rerun it to start over.

const SHEET := "res://assets/tilesets/oppcastle-mod-tiles.png"
const TILESET_PATH := "res://assets/tilesets/castle_tileset.tres"
const THEME_PATH := "res://data/themes/castle_theme.tres"
const TILE := 16

# The sheet's art isn't all on one 16 px grid, so each group gets its own
# atlas source with a different vertical margin.
const BRICKS := 0
const PLATFORMS := 1
const WALLS := 2

const S := DungeonTileRule.Situation
const Anchor := DungeonDecoration.Anchor
const Layer := DungeonDecoration.Layer

var _tile_set := TileSet.new()
var _theme := DungeonTheme.new()


func _init() -> void:
	_tile_set.tile_size = Vector2i(TILE, TILE)
	_tile_set.add_physics_layer()
	_add_source(BRICKS, 11)
	_add_source(PLATFORMS, 12)
	_add_source(WALLS, 0)
	_theme.tile_set = _tile_set

	# Bricks. (7,2)-(8,3) is a 32 px patch that repeats without a seam.
	_solid_rule(S.INNER, Vector2i(7, 2), Vector2i(2, 2))
	_solid_rule(S.TOP, Vector2i(7, 1), Vector2i(2, 1))
	_solid_rule(S.BOTTOM, Vector2i(7, 6), Vector2i(2, 1))
	_solid_rule(S.LEFT, Vector2i(6, 2), Vector2i(1, 2))
	_solid_rule(S.RIGHT, Vector2i(19, 2), Vector2i(1, 2))
	_solid_rule(S.TOP_LEFT, Vector2i(6, 1), Vector2i.ONE)
	_solid_rule(S.TOP_RIGHT, Vector2i(19, 1), Vector2i.ONE)
	_solid_rule(S.BOTTOM_LEFT, Vector2i(6, 6), Vector2i.ONE)
	_solid_rule(S.BOTTOM_RIGHT, Vector2i(19, 6), Vector2i.ONE)

	# Wooden planks, one-way.
	_platform_rule(S.PLATFORM_LEFT, Vector2i(22, 5), 1)
	_platform_rule(S.PLATFORM_MIDDLE, Vector2i(23, 5), 2)
	_platform_rule(S.PLATFORM_RIGHT, Vector2i(27, 5), 1)

	# Background wall: mostly plain, with the odd flecked tile.
	_background_rule(Vector2i(9, 14), 14.0)
	for flecked in [Vector2i(7, 14), Vector2i(8, 14), Vector2i(6, 14), Vector2i(7, 15), Vector2i(8, 15)]:
		_background_rule(flecked, 1.0)

	_decoration("gate_open", Vector2i(16, 12), Vector2i(4, 6), Layer.BACKGROUND, Anchor.FLOOR, 0.04, 1,
			["hall", "dead_end"])
	_decoration("gate_barred", Vector2i(20, 12), Vector2i(4, 6), Layer.BACKGROUND, Anchor.FLOOR, 0.04, 1,
			["hall", "dead_end"])
	_decoration("door_wooden", Vector2i(24, 12), Vector2i(4, 6), Layer.BACKGROUND, Anchor.FLOOR, 1.0, 1,
			["shop"])
	_decoration("torch", Vector2i(6, 18), Vector2i(2, 2), Layer.BACKGROUND, Anchor.WALL, 0.04, 0, [])
	_decoration("window_lit", Vector2i(8, 16), Vector2i(2, 2), Layer.BACKGROUND, Anchor.WALL, 0.012, 0, [])
	_decoration("window_dark", Vector2i(6, 16), Vector2i(2, 2), Layer.BACKGROUND, Anchor.WALL, 0.012, 0, [])
	_decoration("crate", Vector2i(2, 4), Vector2i(2, 2), Layer.PROPS, Anchor.FLOOR, 0.5, 1,
			["item", "item_key", "shop"]).door_clearance = 0
	_decoration("barrel", Vector2i(2, 6), Vector2i(2, 2), Layer.PROPS, Anchor.FLOOR, 0.06, 0,
			["hall", "dead_end", "shop"])
	_decoration("fence", Vector2i(2, 2), Vector2i(2, 2), Layer.PROPS, Anchor.FLOOR, 0.3, 1,
			["dead_end"])

	# Crate and barrel art stops short of the tile's bottom edge; nudge them
	# down onto the floor.
	_nudge_down(Vector2i(2, 4), Vector2i(2, 2), 1)
	_nudge_down(Vector2i(2, 6), Vector2i(2, 2), 2)

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(THEME_PATH.get_base_dir()))
	var error := ResourceSaver.save(_tile_set, TILESET_PATH)
	_tile_set.take_over_path(TILESET_PATH)
	if error == OK:
		error = ResourceSaver.save(_theme, THEME_PATH)
	print("saved" if error == OK else "save failed: %d" % error)
	quit(0 if error == OK else 1)


func _add_source(id: int, margin_y: int) -> void:
	var source := TileSetAtlasSource.new()
	source.texture = load(SHEET)
	source.texture_region_size = Vector2i(TILE, TILE)
	source.margins = Vector2i(0, margin_y)
	_tile_set.add_source(source, id)


## Creates the atlas tiles for a block, and returns their TileData.
func _tiles(source_id: int, at: Vector2i, size: Vector2i) -> Array[TileData]:
	var source: TileSetAtlasSource = _tile_set.get_source(source_id)
	var out: Array[TileData] = []
	for y in size.y:
		for x in size.x:
			var coords := at + Vector2i(x, y)
			if not source.has_tile(coords):
				source.create_tile(coords)
			out.append(source.get_tile_data(coords, 0))
	return out


func _rule(situation: int, source_id: int, at: Vector2i, size: Vector2i, weight: float) -> void:
	var rule := DungeonTileRule.new()
	rule.situation = situation
	rule.source_id = source_id
	rule.atlas_coords = at
	rule.pattern_size = size
	rule.weight = weight
	_theme.tile_rules.append(rule)


func _solid_rule(situation: int, at: Vector2i, size: Vector2i) -> void:
	var half := TILE / 2.0
	for data in _tiles(BRICKS, at, size):
		data.add_collision_polygon(0)
		data.set_collision_polygon_points(0, 0, PackedVector2Array([
			Vector2(-half, -half), Vector2(half, -half), Vector2(half, half), Vector2(-half, half)]))
	_rule(situation, BRICKS, at, size, 1.0)


func _platform_rule(situation: int, at: Vector2i, width: int) -> void:
	var half := TILE / 2.0
	for data in _tiles(PLATFORMS, at, Vector2i(width, 1)):
		data.add_collision_polygon(0)
		data.set_collision_polygon_points(0, 0, PackedVector2Array([
			Vector2(-half, -half), Vector2(half, -half), Vector2(half, -half + 6), Vector2(-half, -half + 6)]))
		data.set_collision_polygon_one_way(0, 0, true)
	_rule(situation, PLATFORMS, at, Vector2i(width, 1), 1.0)


func _background_rule(at: Vector2i, weight: float) -> void:
	_tiles(WALLS, at, Vector2i.ONE)
	_rule(S.BACKGROUND, WALLS, at, Vector2i.ONE, weight)


func _decoration(decoration_name: String, at: Vector2i, size: Vector2i, layer: int, anchor: int,
		chance: float, max_per_piece: int, pieces: Array) -> DungeonDecoration:
	_tiles(WALLS, at, size)
	var decoration := DungeonDecoration.new()
	decoration.name = decoration_name
	decoration.source_id = WALLS
	decoration.atlas_coords = at
	decoration.size_in_tiles = size
	decoration.layer = layer
	decoration.anchor = anchor
	decoration.chance = chance
	decoration.max_per_piece = max_per_piece
	decoration.pieces = PackedStringArray(pieces)
	_theme.decorations.append(decoration)
	return decoration


func _nudge_down(at: Vector2i, size: Vector2i, pixels: int) -> void:
	for data in _tiles(WALLS, at, size):
		data.texture_origin = Vector2i(0, -pixels)
