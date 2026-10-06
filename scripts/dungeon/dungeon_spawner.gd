class_name DungeonSpawner
extends RefCounted
## Fills a painted dungeon with enemies from a DungeonSpawnTable.
##
## The same map seed and table always spawn the same enemies in the same
## places.

const MapPiece := preload("res://scripts/mapgen/map_piece.gd")


## Instantiates enemies as children of `parent`, which must sit at the
## dungeon's origin. Returns the spawned nodes.
static func populate(dungeon: Dungeon, table: DungeonSpawnTable, parent: Node2D) -> Array[Node2D]:
	var map := dungeon.result
	var rng := RandomNumberGenerator.new()
	rng.seed = map.map_seed
	var spawned: Array[Node2D] = []
	var taken: Array[Vector2i] = []
	var per_piece := {}
	for rule in table.rules:
		if rule.enemy == null:
			continue
		for piece: MapPiece in map.pieces:
			if not piece.name in rule.pieces or _depth(piece) < rule.min_depth:
				continue
			var from_rule := 0
			for y in range(piece.pos.y, piece.pos.y + piece.size.y):
				for x in range(piece.pos.x, piece.pos.x + piece.size.x):
					var cell := Vector2i(x, y)
					if not _fits(map, rule, cell):
						continue
					# Roll before the limits so one piece filling up doesn't
					# shift the rolls for the rest of the map.
					if rng.randf() >= rule.chance:
						continue
					if rule.max_per_piece > 0 and from_rule >= rule.max_per_piece:
						continue
					if table.max_per_piece > 0 and per_piece.get(piece.index, 0) >= table.max_per_piece:
						continue
					if _too_close(cell, taken, table.min_spacing):
						continue
					from_rule += 1
					per_piece[piece.index] = per_piece.get(piece.index, 0) + 1
					taken.append(cell)
					var enemy: Node2D = rule.enemy.instantiate()
					var anchor := Vector2(0.5, 1.0) if rule.placement == DungeonSpawnRule.Placement.FLOOR \
							else Vector2(0.5, 0.5)
					# Set before entering the tree: enemies record their patrol
					# origin in _ready.
					enemy.position = (Vector2(cell) + anchor) * dungeon.cell_size() + rule.offset
					parent.add_child(enemy)
					spawned.append(enemy)
	return spawned


## Pieces between this one and the start room.
static func _depth(piece: MapPiece) -> int:
	var depth := 0
	var at := piece
	while at.parent != null:
		at = at.parent
		depth += 1
	return depth


static func _fits(map, rule: DungeonSpawnRule, cell: Vector2i) -> bool:
	if rule.placement == DungeonSpawnRule.Placement.FLOOR:
		if _tile(map, cell + Vector2i.DOWN) != MapPiece.SOLID:
			return false
		for up in rule.height_in_cells:
			if _tile(map, cell + Vector2i.UP * up) != MapPiece.EMPTY:
				return false
	else:
		# A clear column: off the floor, with headroom.
		for dy in range(-1, 2):
			if _tile(map, cell + Vector2i(0, dy)) != MapPiece.EMPTY:
				return false
	for dx in range(-rule.door_clearance, rule.door_clearance + 1):
		for dy in range(-1, 2):
			if _tile(map, cell + Vector2i(dx, dy)) == MapPiece.DOOR:
				return false
	return true


static func _tile(map, cell: Vector2i) -> int:
	if cell.x < 0 or cell.y < 0 or cell.x >= map.size.x or cell.y >= map.size.y:
		return MapPiece.ROCK
	return map.get_tile(cell.x, cell.y)


static func _too_close(cell: Vector2i, taken: Array[Vector2i], spacing: int) -> bool:
	for other in taken:
		if absi(other.x - cell.x) <= spacing and absi(other.y - cell.y) <= spacing:
			return true
	return false
