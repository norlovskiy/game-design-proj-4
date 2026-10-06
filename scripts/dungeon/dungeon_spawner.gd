class_name DungeonSpawner
extends RefCounted
## Fills a painted dungeon with enemies from a DungeonSpawnTable.
##
## Every rule first rolls its chance at each cell where its enemy fits. If
## that leaves the dungeon under the table's minimum, more are added at the
## remaining spots until the minimum is met or no spot is left. The same map
## seed and table always spawn the same enemies in the same places.

const MapPiece := preload("res://scripts/mapgen/map_piece.gd")

var _dungeon: Dungeon
var _table: DungeonSpawnTable
var _parent: Node2D
var _rng := RandomNumberGenerator.new()
var _spawned: Array[Node2D] = []
var _taken: Array[Vector2i] = []
## Enemies per piece index, across all rules.
var _per_piece := {}
## Enemies per [rule, piece index].
var _per_rule := {}


## Instantiates enemies as children of `parent`, which must sit at the
## dungeon's origin. Returns the spawned nodes.
static func populate(dungeon: Dungeon, table: DungeonSpawnTable, parent: Node2D) -> Array[Node2D]:
	var spawner := DungeonSpawner.new()
	spawner._dungeon = dungeon
	spawner._table = table
	spawner._parent = parent
	spawner._rng.seed = dungeon.result.map_seed
	spawner._run()
	return spawner._spawned


## The fewest enemies the table asks for in a map.
static func minimum_for(map, table: DungeonSpawnTable) -> int:
	var corridors := 0
	for piece: MapPiece in map.pieces:
		if piece.kind != "room":
			corridors += 1
	return ceili(table.min_per_10_corridors * corridors / 10.0)


func _run() -> void:
	var map := _dungeon.result
	# Spots that fit but lost their roll, as [rule, piece, cell].
	var spare := []
	for rule in _table.rules:
		if rule.enemy == null:
			continue
		for piece: MapPiece in map.pieces:
			if not piece.name in rule.pieces or _depth(piece) < rule.min_depth:
				continue
			for y in range(piece.pos.y, piece.pos.y + piece.size.y):
				for x in range(piece.pos.x, piece.pos.x + piece.size.x):
					var cell := Vector2i(x, y)
					if not _fits(rule, cell):
						continue
					# Roll before the limits so one piece filling up doesn't
					# shift the rolls for the rest of the map.
					if _rng.randf() >= rule.chance:
						spare.append([rule, piece, cell])
					elif _allowed(rule, piece, cell):
						_spawn(rule, piece, cell)

	var minimum := minimum_for(map, _table)
	while _spawned.size() < minimum and not spare.is_empty():
		var pick := _pick_weighted(spare)
		var spot: Array = spare[pick]
		spare.remove_at(pick)
		if _allowed(spot[0], spot[1], spot[2]):
			_spawn(spot[0], spot[1], spot[2])


## Index of a random spare spot, favouring rules with a higher chance so the
## top-up keeps roughly the same mix of enemies.
func _pick_weighted(spare: Array) -> int:
	var total := 0.0
	for spot in spare:
		total += spot[0].chance
	var roll := _rng.randf() * total
	for i in spare.size():
		roll -= spare[i][0].chance
		if roll < 0.0:
			return i
	return spare.size() - 1


func _allowed(rule: DungeonSpawnRule, piece: MapPiece, cell: Vector2i) -> bool:
	if rule.max_per_piece > 0 and _per_rule.get([rule, piece.index], 0) >= rule.max_per_piece:
		return false
	if _table.max_per_piece > 0 and _per_piece.get(piece.index, 0) >= _table.max_per_piece:
		return false
	for other in _taken:
		if absi(other.x - cell.x) <= _table.min_spacing and absi(other.y - cell.y) <= _table.min_spacing:
			return false
	return true


func _spawn(rule: DungeonSpawnRule, piece: MapPiece, cell: Vector2i) -> void:
	_per_rule[[rule, piece.index]] = _per_rule.get([rule, piece.index], 0) + 1
	_per_piece[piece.index] = _per_piece.get(piece.index, 0) + 1
	_taken.append(cell)
	var enemy: Node2D = rule.enemy.instantiate()
	var anchor := Vector2(0.5, 1.0) if rule.placement == DungeonSpawnRule.Placement.FLOOR \
			else Vector2(0.5, 0.5)
	# Set before entering the tree: enemies record their patrol origin in
	# _ready.
	enemy.position = (Vector2(cell) + anchor) * _dungeon.cell_size() + rule.offset
	_parent.add_child(enemy)
	_spawned.append(enemy)


## Pieces between this one and the start room.
func _depth(piece: MapPiece) -> int:
	var depth := 0
	var at := piece
	while at.parent != null:
		at = at.parent
		depth += 1
	return depth


func _fits(rule: DungeonSpawnRule, cell: Vector2i) -> bool:
	if rule.placement == DungeonSpawnRule.Placement.FLOOR:
		if _tile(cell + Vector2i.DOWN) != MapPiece.SOLID:
			return false
		for up in rule.height_in_cells:
			if _tile(cell + Vector2i.UP * up) != MapPiece.EMPTY:
				return false
	else:
		# A clear column: off the floor, with headroom.
		for dy in range(-1, 2):
			if _tile(cell + Vector2i(0, dy)) != MapPiece.EMPTY:
				return false
	for dx in range(-rule.door_clearance, rule.door_clearance + 1):
		for dy in range(-1, 2):
			if _tile(cell + Vector2i(dx, dy)) == MapPiece.DOOR:
				return false
	return true


func _tile(cell: Vector2i) -> int:
	var map := _dungeon.result
	if cell.x < 0 or cell.y < 0 or cell.x >= map.size.x or cell.y >= map.size.y:
		return MapPiece.ROCK
	return map.get_tile(cell.x, cell.y)
