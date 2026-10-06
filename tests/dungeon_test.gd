extends SceneTree
## Paints many generated maps with the castle theme and checks the result.
##
## Run: godot --headless --path . -s tests/dungeon_test.gd
## On a fresh clone, run `godot --headless --path . --import` once first.

const MapPiece := preload("res://scripts/mapgen/map_piece.gd")

const SEEDS := 60

var _failures := 0
var _seed := 0


func _init() -> void:
	var theme: DungeonTheme = load("res://data/themes/castle_theme.tres")
	var dungeon := Dungeon.new()
	dungeon.theme = theme
	root.add_child(dungeon)
	var n := theme.tiles_per_cell
	var decorated := 0
	for i in SEEDS:
		_seed = i * 777
		if not dungeon.generate(_seed):
			_fail("generation failed")
			continue
		var map := dungeon.result
		for y in map.size.y:
			for x in map.size.x:
				var tile := map.get_tile(x, y)
				var painted := 0
				for sy in n:
					for sx in n:
						var at := Vector2i(x * n + sx, y * n + sy)
						if dungeon.foreground.get_cell_source_id(at) != -1:
							painted += 1
							_check_tile_exists(theme, dungeon.foreground, at)
						if map.get_owner(x, y) >= 0 and dungeon.background.get_cell_source_id(at) == -1:
							_fail("no background at %s" % at)
						if dungeon.props.get_cell_source_id(at) != -1:
							_check_tile_exists(theme, dungeon.props, at)
							if tile != MapPiece.EMPTY:
								_fail("prop inside a wall at %s" % at)
				match tile:
					MapPiece.SOLID:
						if painted != n * n:
							_fail("solid cell %s has %d of %d tiles" % [Vector2i(x, y), painted, n * n])
					MapPiece.PLATFORM:
						if painted != n:
							_fail("platform cell %s has %d tiles" % [Vector2i(x, y), painted])
					_:
						if painted != 0:
							_fail("open cell %s has foreground tiles" % Vector2i(x, y))
		decorated += dungeon.props.get_used_cells().size()

		var first := _snapshot(dungeon)
		dungeon.generate(_seed)
		if _snapshot(dungeon) != first:
			_fail("same seed painted a different dungeon")
		if dungeon.spawn_position() == Vector2.ZERO:
			_fail("no spawn position")

	_check_exploration(dungeon)

	print("%d seeds, %d failures, %d prop tiles placed" % [SEEDS, _failures, decorated])
	quit(1 if _failures > 0 else 0)


func _check_exploration(dungeon: Dungeon) -> void:
	dungeon.generate(1)
	var map := dungeon.result
	if dungeon.explored.size() != 1:
		_fail("a fresh dungeon should have only the start piece explored")
	var glowing := 0
	for y in map.size.y:
		for x in map.size.x:
			if dungeon._fog_image.get_pixel(x, y).g > 0.5:
				glowing += 1
	if glowing == 0:
		_fail("no door glows next to the start room")
	var target := -1
	for piece in map.pieces:
		if not dungeon.explored.has(piece.index):
			target = piece.index
			break
	var cell := Vector2i.ZERO
	for y in map.size.y:
		for x in map.size.x:
			if map.get_owner(x, y) == target:
				cell = Vector2i(x, y)
	if dungeon._fog_image.get_pixel(cell.x, cell.y).r != 0.0:
		_fail("unexplored cell is not fogged")
	if dungeon.piece_at((Vector2(cell) + Vector2(0.5, 0.5)) * dungeon.cell_size()) != target:
		_fail("piece_at found the wrong piece")
	dungeon.explore(target)
	dungeon._process(dungeon.fade_time / 2.0)
	var halfway := dungeon._fog_image.get_pixel(cell.x, cell.y).r
	if halfway < 0.3 or halfway > 0.7:
		_fail("fade is not gradual (%f at half time)" % halfway)
	dungeon._process(dungeon.fade_time)
	if dungeon._fog_image.get_pixel(cell.x, cell.y).r != 1.0:
		_fail("explored cell is still fogged")
	dungeon.generate(1)
	if dungeon.explored.size() != 1:
		_fail("rebuilding did not reset exploration")


func _check_tile_exists(theme: DungeonTheme, layer: TileMapLayer, at: Vector2i) -> void:
	var source := theme.tile_set.get_source(layer.get_cell_source_id(at)) as TileSetAtlasSource
	if source == null or not source.has_tile(layer.get_cell_atlas_coords(at)):
		_fail("tile at %s is not in the tileset" % at)


func _snapshot(dungeon: Dungeon) -> Array:
	var out := []
	for layer: TileMapLayer in [dungeon.background, dungeon.props, dungeon.foreground]:
		for cell in layer.get_used_cells():
			out.append([layer.name, cell, layer.get_cell_source_id(cell), layer.get_cell_atlas_coords(cell)])
	return out


func _fail(message: String) -> void:
	_failures += 1
	if _failures <= 20:
		printerr("seed %d: %s" % [_seed, message])
