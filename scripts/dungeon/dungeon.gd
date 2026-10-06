class_name Dungeon
extends Node2D
## Paints a generated map with a DungeonTheme.
##
## Builds three TileMapLayers: Background (wall and wall decorations), Props
## (transparent decorations) and Foreground (bricks and platforms, with
## collision), then spawns enemies from the spawn table. The same seed, theme
## and table always produce the same dungeon.

const MapGenerator := preload("res://scripts/mapgen/map_generator.gd")
const MapPiece := preload("res://scripts/mapgen/map_piece.gd")

const S := DungeonTileRule.Situation

## Emitted when a piece is revealed.
signal explored_changed

const FOG_SHADER := preload("res://shaders/dungeon_fog.gdshader")

@export var theme: DungeonTheme
## Enemies to spawn after painting. Leave empty for a dungeon with none.
@export var spawn_table: DungeonSpawnTable
## Pickups to place after painting. Leave empty for a dungeon with none.
@export var item_table: DungeonItemTable

var result: MapGenerator.Result
var background: TileMapLayer
var props: TileMapLayer
var foreground: TileMapLayer
## Spawned enemies live under this node.
var enemies: Node2D
## Spawned pickups live under this node.
var items: Node2D
## Indices of the pieces the player has entered.
var explored := {}

## Seconds a piece takes to fade in once entered.
var fade_time := 0.25

var _tracked: Node2D
## Pieces still fading in: index -> {cells, t}.
var _fades := {}
var _fog_image: Image
var _fog_texture: ImageTexture

var _generator := MapGenerator.new()
## Cells already covered by a decoration.
var _decorated := {}


## Generates a map and paints it. Returns false if generation failed.
func generate(map_seed: int) -> bool:
	var generated := _generator.generate(map_seed)
	if not generated.ok:
		push_error("Map generation failed: %s" % generated.error)
		return false
	build(generated)
	return true


func build(map: MapGenerator.Result) -> void:
	result = map
	_decorated.clear()
	for child in get_children():
		child.free()
	background = _add_layer("Background")
	props = _add_layer("Props")
	foreground = _add_layer("Foreground")

	for y in result.size.y:
		for x in result.size.x:
			var owner := result.get_owner(x, y)
			if owner < 0:
				continue
			var piece_name: String = result.pieces[owner].name
			_paint_cell(background, x, y, piece_name, func(_sx: int, _sy: int) -> int: return S.BACKGROUND)
			match result.get_tile(x, y):
				MapPiece.SOLID:
					_paint_cell(foreground, x, y, piece_name, _solid_situation)
				MapPiece.PLATFORM:
					_paint_platform(x, y, piece_name)
	for decoration in theme.decorations:
		_place_decoration(decoration)
	enemies = Node2D.new()
	enemies.name = "Enemies"
	add_child(enemies)
	if spawn_table != null:
		DungeonSpawner.populate(self, spawn_table, enemies)
	items = Node2D.new()
	items.name = "Items"
	add_child(items)
	if item_table != null:
		DungeonItemSpawner.populate(self, item_table, items)
	_build_fog()
	explored.clear()
	_fades.clear()
	for piece: MapPiece in result.pieces:
		if piece.name == "start":
			explore(piece.index, true)


## Reveals pieces as `body` walks into them.
func track(body: Node2D) -> void:
	_tracked = body


func _process(delta: float) -> void:
	if result == null:
		return
	if _tracked != null:
		var index := piece_at(to_local(_tracked.global_position))
		if index >= 0 and not explored.has(index):
			explore(index)
	_advance_fades(delta)


## Index of the piece covering a local position, or -1 for rock and outside.
func piece_at(local_pos: Vector2) -> int:
	var cell := Vector2i((local_pos / cell_size()).floor())
	if cell.x < 0 or cell.y < 0 or cell.x >= result.size.x or cell.y >= result.size.y:
		return -1
	return result.get_owner(cell.x, cell.y)

func explore(index: int, instant := false) -> void:
	if explored.has(index):
		return
	explored[index] = true
	var cells: Array[Vector2i] = []
	for y in result.size.y:
		for x in result.size.x:
			if result.get_owner(x, y) == index:
				cells.append(Vector2i(x, y))
	_fades[index] = {"cells": cells, "t": 1.0 if instant else 0.0}
	for cell in cells:
		_light_door(cell)
	_advance_fades(0.0)
	explored_changed.emit()


## Flags a door cell and the door cell facing it across the piece boundary.
func _light_door(cell: Vector2i) -> void:
	if result.get_tile(cell.x, cell.y) != MapPiece.DOOR:
		return
	for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var other := cell + step
		if other.x < 0 or other.y < 0 or other.x >= result.size.x or other.y >= result.size.y:
			continue
		if result.get_tile(other.x, other.y) != MapPiece.DOOR or result.get_owner(other.x, other.y) == result.get_owner(cell.x, cell.y):
			continue
		for flagged in [cell, other]:
			var red := _fog_image.get_pixel(flagged.x, flagged.y).r
			_fog_image.set_pixel(flagged.x, flagged.y, Color(red, 1.0, 0.0))


func _advance_fades(delta: float) -> void:
	if _fades.is_empty():
		return
	for index in _fades.keys():
		var fade: Dictionary = _fades[index]
		fade.t = minf(fade.t + delta / maxf(fade_time, 0.001), 1.0)
		for cell: Vector2i in fade.cells:
			var door := _fog_image.get_pixel(cell.x, cell.y).g
			_fog_image.set_pixel(cell.x, cell.y, Color(fade.t, door, 0.0))
		if fade.t >= 1.0:
			_fades.erase(index)
	_fog_texture.update(_fog_image)


## A black sheet over the whole map that the shader cuts holes in for explored
## cells. It draws above tiles and enemies but below the HUD.
func _build_fog() -> void:
	# Red is how revealed a cell is (rock counts as revealed). Green marks door
	# cells that meet an explored piece; the shader lights a gradient out from
	# them into the dark room beyond.
	_fog_image = Image.create_empty(result.size.x, result.size.y, false, Image.FORMAT_RG8)
	for y in result.size.y:
		for x in result.size.x:
			if result.get_owner(x, y) < 0:
				_fog_image.set_pixel(x, y, Color(1.0, 0.0, 0.0))
	_fog_texture = ImageTexture.create_from_image(_fog_image)
	var material := ShaderMaterial.new()
	material.shader = FOG_SHADER
	material.set_shader_parameter("explored", _fog_texture)
	material.set_shader_parameter("cell_px", cell_size().x)
	material.set_shader_parameter("glow_px", float(theme.tile_set.tile_size.x))
	var fog := ColorRect.new()
	fog.name = "Fog"
	fog.size = Vector2(result.size) * cell_size()
	fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fog.material = material
	fog.z_index = 100
	add_child(fog)


## Pixel size of one map cell.
func cell_size() -> Vector2:
	return Vector2(theme.tile_set.tile_size * theme.tiles_per_cell)


## Local position of the middle of the start room's floor.
func spawn_position() -> Vector2:
	for piece: MapPiece in result.pieces:
		if piece.name != "start":
			continue
		for y in range(piece.size.y - 1, -1, -1):
			if piece.get_tile(piece.size.x / 2, y) == MapPiece.EMPTY:
				var cell := piece.pos + Vector2i(piece.size.x / 2, y)
				return (Vector2(cell) + Vector2(0.5, 1.0)) * cell_size()
	return Vector2.ZERO


func _add_layer(layer_name: String) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.name = layer_name
	layer.tile_set = theme.tile_set
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(layer)
	return layer


## Paints every small tile of one map cell, asking `situation_at` what each
## small tile is.
func _paint_cell(layer: TileMapLayer, x: int, y: int, piece_name: String,
		situation_at: Callable) -> void:
	var n := theme.tiles_per_cell
	for sy in range(y * n, y * n + n):
		for sx in range(x * n, x * n + n):
			_paint_tile(layer, sx, sy, situation_at.call(sx, sy), piece_name)


func _paint_platform(x: int, y: int, piece_name: String) -> void:
	var n := theme.tiles_per_cell
	var open_left := result.get_tile(x - 1, y) != MapPiece.PLATFORM
	var open_right := result.get_tile(x + 1, y) != MapPiece.PLATFORM
	for i in n:
		var situation := S.PLATFORM_MIDDLE
		if i == 0 and open_left:
			situation = S.PLATFORM_LEFT
		elif i == n - 1 and open_right:
			situation = S.PLATFORM_RIGHT
		_paint_tile(foreground, x * n + i, y * n, situation, piece_name)


func _paint_tile(layer: TileMapLayer, sx: int, sy: int, situation: int, piece_name: String) -> void:
	var rule := _pick_rule(situation, piece_name, sx, sy)
	if rule == null:
		return
	var offset := Vector2i(posmod(sx, rule.pattern_size.x), posmod(sy, rule.pattern_size.y))
	layer.set_cell(Vector2i(sx, sy), rule.source_id, rule.atlas_coords + offset)


## Classifies a solid small tile by which neighbours are open.
func _solid_situation(sx: int, sy: int) -> int:
	var up := _is_open(sx, sy - 1)
	var down := _is_open(sx, sy + 1)
	var left := _is_open(sx - 1, sy)
	var right := _is_open(sx + 1, sy)
	if up and left:
		return S.TOP_LEFT
	if up and right:
		return S.TOP_RIGHT
	if down and left:
		return S.BOTTOM_LEFT
	if down and right:
		return S.BOTTOM_RIGHT
	if up:
		return S.TOP
	if down:
		return S.BOTTOM
	if left:
		return S.LEFT
	if right:
		return S.RIGHT
	return S.INNER


## Whether the map cell containing a small tile is walkable space.
func _is_open(sx: int, sy: int) -> bool:
	var n := theme.tiles_per_cell
	var cell := Vector2i(floori(float(sx) / n), floori(float(sy) / n))
	if cell.x < 0 or cell.y < 0 or cell.x >= result.size.x or cell.y >= result.size.y:
		return false
	var tile := result.get_tile(cell.x, cell.y)
	return tile == MapPiece.EMPTY or tile == MapPiece.DOOR or tile == MapPiece.PLATFORM


## Picks by weight among the rules for a situation. Rules that name the piece
## take over from the general ones. The choice is made once per pattern
## repeat so multi-tile patterns stay whole.
func _pick_rule(situation: int, piece_name: String, sx: int, sy: int) -> DungeonTileRule:
	var general: Array[DungeonTileRule] = []
	var specific: Array[DungeonTileRule] = []
	for rule in theme.tile_rules:
		if rule.situation != situation:
			continue
		if rule.pieces.is_empty():
			general.append(rule)
		elif piece_name in rule.pieces:
			specific.append(rule)
	var options := general if specific.is_empty() else specific
	if options.is_empty():
		return null
	var total := 0.0
	for rule in options:
		total += rule.weight
	var size := options[0].pattern_size
	var roll := _roll(floori(float(sx) / size.x), floori(float(sy) / size.y), situation) * total
	for rule in options:
		roll -= rule.weight
		if roll < 0.0:
			return rule
	return options.back()


func _place_decoration(decoration: DungeonDecoration) -> void:
	var n := theme.tiles_per_cell
	var size := Vector2i(ceili(float(decoration.size_in_tiles.x) / n), ceili(float(decoration.size_in_tiles.y) / n))
	var layer := background if decoration.layer == DungeonDecoration.Layer.BACKGROUND else props
	var salt := 1000 + theme.decorations.find(decoration)
	var placed := {}
	for y in result.size.y - size.y + 1:
		for x in result.size.x - size.x + 1:
			var spot := Rect2i(Vector2i(x, y), size)
			var owner := result.get_owner(x, y)
			if owner < 0 or _roll(x, y, salt) >= decoration.chance:
				continue
			if decoration.max_per_piece > 0 and placed.get(owner, 0) >= decoration.max_per_piece:
				continue
			if not _decoration_fits(decoration, spot, owner):
				continue
			placed[owner] = placed.get(owner, 0) + 1
			for cy in size.y:
				for cx in size.x:
					_decorated[spot.position + Vector2i(cx, cy)] = true
			# Bottom-align the art inside the cells it claimed.
			var origin := Vector2i(x * n, (y + size.y) * n - decoration.size_in_tiles.y)
			for ty in decoration.size_in_tiles.y:
				for tx in decoration.size_in_tiles.x:
					layer.set_cell(origin + Vector2i(tx, ty), decoration.source_id,
							decoration.atlas_coords + Vector2i(tx, ty))


func _decoration_fits(decoration: DungeonDecoration, spot: Rect2i, owner: int) -> bool:
	var piece: MapPiece = result.pieces[owner]
	if not decoration.pieces.is_empty() and not piece.name in decoration.pieces:
		return false
	if piece.name in decoration.excluded_pieces:
		return false
	for y in range(spot.position.y, spot.end.y):
		for x in range(spot.position.x, spot.end.x):
			if result.get_owner(x, y) != owner or result.get_tile(x, y) != MapPiece.EMPTY:
				return false
			if _decorated.has(Vector2i(x, y)):
				return false
	for x in range(spot.position.x, spot.end.x):
		match decoration.anchor:
			DungeonDecoration.Anchor.FLOOR:
				if result.get_tile(x, spot.end.y) != MapPiece.SOLID:
					return false
			DungeonDecoration.Anchor.CEILING:
				if result.get_tile(x, spot.position.y - 1) != MapPiece.SOLID:
					return false
	var clear := spot.grow_individual(decoration.door_clearance, 0, decoration.door_clearance, 0)
	for y in range(clear.position.y, clear.end.y):
		for x in range(maxi(clear.position.x, 0), mini(clear.end.x, result.size.x)):
			if result.get_tile(x, y) == MapPiece.DOOR:
				return false
	return true


## A repeatable 0..1 value for a position, so painting doesn't depend on the
## order tiles are visited in.
func _roll(x: int, y: int, salt: int) -> float:
	var h := (x * 73856093) ^ (y * 19349663) ^ (salt * 83492791) ^ (result.map_seed * 2654435761)
	h = (h ^ (h >> 15)) * 2246822519
	h = (h ^ (h >> 13)) * 3266489917
	h = h ^ (h >> 16)
	return float(h & 0xFFFFFF) / float(0x1000000)
