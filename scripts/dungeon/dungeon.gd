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

## Emitted when the player claims the treasure.
signal treasure_claimed

const GATE_SCENE: PackedScene = preload("res://scenes/dungeon_gate.tscn")
const TREASURE_SCENE: PackedScene = preload("res://scenes/treasure.tscn")
## How far above the floor the treasure floats, in pixels.
const TREASURE_HEIGHT := 24.0
## How many cells past its doorway the player must be before the boss gate
## shuts behind them.
const BOSS_GATE_DEPTH := 2

@export var theme: DungeonTheme
## Enemies to spawn after painting. Leave empty for a dungeon with none.
@export var spawn_table: DungeonSpawnTable
## Rooms where enemies can't target or hurt the tracked player.
@export var safe_rooms: PackedStringArray = ["shop"]
## The room the treasure is placed in. Empty for a dungeon with none.
@export var treasure_room := "goal"
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
## Door gates live under this node, drawn behind the bricks so a raised gate
## is hidden by the wall above its doorway.
var gates: Node2D
## The treasure, if the dungeon has one.
var treasure: Treasure
## The boss, while it exists. Set by the spawner.
var boss: Node2D
## The gate at the boss room's entrance, if there is a boss.
var boss_gate: DungeonGate
## Piece indices the player has visited, used by the Tab map.
var explored := {}
var _tracked: Node2D

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
	gates = Node2D.new()
	gates.name = "Gates"
	add_child(gates)
	foreground = _add_layer("Foreground")
	boss = null
	boss_gate = null
	treasure = null

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
	_place_treasure()
	_build_gates()
	explored.clear()
	for piece: MapPiece in result.pieces:
		if piece.name == "start":
			explored[piece.index] = true


## Tracks visited rooms, safe rooms, and the player's boss arena.
func track(body: Node2D) -> void:
	_tracked = body


func _process(_delta: float) -> void:
	if result == null:
		return
	if _tracked != null:
		var index := piece_at(to_local(_tracked.global_position))
		if index >= 0:
			explored[index] = true
		if "is_safe" in _tracked:
			_tracked.is_safe = index >= 0 and result.pieces[index].name in safe_rooms
		if "arena_rect" in _tracked:
			var arena := Rect2()
			if index >= 0 and spawn_table != null and result.pieces[index].name == spawn_table.boss_piece:
				var piece: MapPiece = result.pieces[index]
				arena = Rect2(to_global(Vector2(piece.pos) * cell_size()), Vector2(piece.size) * cell_size())
			_tracked.arena_rect = arena
	_update_boss_gate()


func _place_treasure() -> void:
	if treasure_room == "" or floor_middle(treasure_room) == Vector2.ZERO:
		return
	treasure = TREASURE_SCENE.instantiate()
	treasure.position = floor_middle(treasure_room) + Vector2(0, -TREASURE_HEIGHT)
	treasure.claimed.connect(func() -> void: treasure_claimed.emit())
	add_child(treasure)


## Puts a lowered, key-locked gate in every door that needs a key, and a
## raised gate at the boss room's entrance.
func _build_gates() -> void:
	for piece: MapPiece in result.pieces:
		for door in piece.doors:
			if door.used and door.zone_add & MapPiece.ZONE_ITEM_LOCK:
				_add_gate(piece, door, true, true)
		if spawn_table != null and spawn_table.boss != null and piece.name == spawn_table.boss_piece \
				and piece.entry_door != null:
			boss_gate = _add_gate(piece, piece.entry_door, false, false)


func _add_gate(piece: MapPiece, door: MapPiece.Door, starts_closed: bool, needs_key: bool) -> DungeonGate:
	var first: Vector2i = piece.pos + door.cells[0]
	var last: Vector2i = piece.pos + door.cells[door.cells.size() - 1]
	var gate: DungeonGate = GATE_SCENE.instantiate()
	gate.setup(Vector2(last - first + Vector2i.ONE) * cell_size(), starts_closed, needs_key)
	gate.position = Vector2(first) * cell_size()
	gate.set_meta("cell", first)
	gates.add_child(gate)
	return gate


## Shuts the boss in with the player once they are well inside the arena, and
## lets them out again when the boss is dead.
func _update_boss_gate() -> void:
	if boss_gate == null:
		return
	var boss_alive: bool = is_instance_valid(boss) and boss.get("health") != 0
	if boss_gate.closed:
		if not boss_alive:
			boss_gate.open()
		return
	if not boss_alive or _tracked == null:
		return
	var cell := Vector2i((to_local(_tracked.global_position) / cell_size()).floor())
	var door_cell: Vector2i = boss_gate.get_meta("cell")
	var inside := piece_at(to_local(_tracked.global_position))
	if inside >= 0 and result.pieces[inside].name == spawn_table.boss_piece \
			and absi(cell.x - door_cell.x) >= BOSS_GATE_DEPTH:
		boss_gate.close()


## Index of the piece covering a local position, or -1 for rock and outside.
func piece_at(local_pos: Vector2) -> int:
	var cell := Vector2i((local_pos / cell_size()).floor())
	if cell.x < 0 or cell.y < 0 or cell.x >= result.size.x or cell.y >= result.size.y:
		return -1
	return result.get_owner(cell.x, cell.y)

## Pixel size of one map cell.
func cell_size() -> Vector2:
	return Vector2(theme.tile_set.tile_size * theme.tiles_per_cell)


## Local position of the middle of the start room's floor.
func spawn_position() -> Vector2:
	return floor_middle("start")


## Local position of the middle of the floor of the first piece with a name,
## or zero if there is none.
func floor_middle(piece_name: String) -> Vector2:
	for piece: MapPiece in result.pieces:
		if piece.name != piece_name:
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
