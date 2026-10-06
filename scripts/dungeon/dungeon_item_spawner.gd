class_name DungeonItemSpawner
extends RefCounted
## Places pickups from a DungeonItemTable in the rooms its pools name.
##
## Items are spread along each room's floor. The same map seed and table
## always place the same items in the same rooms.

const MapPiece := preload("res://scripts/mapgen/map_piece.gd")


## Instantiates pickups as children of `parent`, which must sit at the
## dungeon's origin. Returns the spawned nodes.
static func populate(dungeon: Dungeon, table: DungeonItemTable, parent: Node2D) -> Array[ItemPickup]:
	var map := dungeon.result
	var rng := RandomNumberGenerator.new()
	# Offset from the map seed so item rolls don't mirror the enemy rolls.
	rng.seed = map.map_seed + 7919
	var spawned: Array[ItemPickup] = []
	# Entries each pool can still hand out before it repeats.
	var remaining := {}
	for piece: MapPiece in map.pieces:
		var pool := _pool_for(table, piece.name)
		if pool == null or pool.entries.is_empty():
			continue
		var cells := _floor_cells(map, piece)
		for i in mini(pool.items_per_room, cells.size()):
			var entry := _draw(pool, remaining, rng)
			# Evenly spaced along the floor: one item sits in the middle.
			var cell := cells[(i + 1) * cells.size() / (pool.items_per_room + 1)]
			var pickup: ItemPickup = table.pickup_scene.instantiate()
			# Set before entering the tree: the pickup picks its icon in _ready.
			pickup.kind = entry.kind
			pickup.variant = entry.variant
			pickup.position = (Vector2(cell) + Vector2(0.5, 1.0)) * dungeon.cell_size() + pool.offset
			parent.add_child(pickup)
			spawned.append(pickup)
	return spawned


static func _pool_for(table: DungeonItemTable, room_name: String) -> DungeonItemPool:
	for pool in table.pools:
		if room_name in pool.rooms:
			return pool
	return null


## Picks an entry by weight, without repeats unless the pool allows them.
static func _draw(pool: DungeonItemPool, remaining: Dictionary, rng: RandomNumberGenerator) -> DungeonItemEntry:
	var options: Array = pool.entries
	if not pool.allow_repeats:
		if not remaining.has(pool) or remaining[pool].is_empty():
			remaining[pool] = pool.entries.duplicate()
		options = remaining[pool]
	var total := 0.0
	for entry: DungeonItemEntry in options:
		total += entry.weight
	var roll := rng.randf() * total
	var picked: DungeonItemEntry = options.back()
	for entry: DungeonItemEntry in options:
		roll -= entry.weight
		if roll < 0.0:
			picked = entry
			break
	if not pool.allow_repeats:
		options.erase(picked)
	return picked


## The room's lowest row of open cells with floor under them and no door
## beside them, left to right.
static func _floor_cells(map, piece: MapPiece) -> Array[Vector2i]:
	for y in range(piece.pos.y + piece.size.y - 1, piece.pos.y - 1, -1):
		var row: Array[Vector2i] = []
		for x in range(piece.pos.x, piece.pos.x + piece.size.x):
			if map.get_tile(x, y) != MapPiece.EMPTY or map.get_tile(x, y + 1) != MapPiece.SOLID:
				continue
			if map.get_tile(x - 1, y) == MapPiece.DOOR or map.get_tile(x + 1, y) == MapPiece.DOOR:
				continue
			row.append(Vector2i(x, y))
		if not row.is_empty():
			return row
	return []
