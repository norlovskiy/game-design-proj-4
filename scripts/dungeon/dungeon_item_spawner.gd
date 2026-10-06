class_name DungeonItemSpawner
extends RefCounted
## Places pickups from a DungeonItemTable in the rooms its pools name.
##
## Items are spread along each room's floor. Pools are handled in table
## order, so a pool that skips already-placed items (a shop) should come
## after the pools that give items away. The same map seed and table always
## place the same items in the same rooms.

const MapPiece := preload("res://scripts/mapgen/map_piece.gd")


## Instantiates pickups as children of `parent`, which must sit at the
## dungeon's origin. Returns the spawned nodes.
static func populate(dungeon: Dungeon, table: DungeonItemTable, parent: Node2D) -> Array[ItemPickup]:
	var map := dungeon.result
	var rng := RandomNumberGenerator.new()
	# Offset from the map seed so item rolls don't mirror the enemy rolls.
	rng.seed = map.map_seed + 7919
	var spawned: Array[ItemPickup] = []
	# [kind, variant] of everything placed so far.
	var placed := {}
	for pool in table.pools:
		# Entries this pool can still hand out before it repeats.
		var remaining: Array = pool.entries.duplicate()
		for piece: MapPiece in map.pieces:
			if _pool_for(table, piece.name) != pool:
				continue
			var cells := _floor_cells(map, piece)
			var count := mini(pool.items_per_room, cells.size())
			for i in count:
				if remaining.is_empty() and not pool.allow_repeats:
					remaining = pool.entries.duplicate()
				var entry := _draw(pool, remaining, placed, rng)
				if entry == null:
					break
				placed[[entry.kind, entry.variant]] = true
				# Evenly spaced along the floor: one item sits in the middle.
				var cell := cells[int((i + 0.5) * cells.size() / count)]
				var pickup: ItemPickup = table.pickup_scene.instantiate()
				# Set before entering the tree: the pickup reads these in _ready.
				pickup.kind = entry.kind
				pickup.variant = entry.variant
				if pool.for_sale:
					pickup.price = entry.price
				pickup.position = (Vector2(cell) + Vector2(0.5, 1.0)) * dungeon.cell_size() + pool.offset
				parent.add_child(pickup)
				spawned.append(pickup)
	return spawned


static func _pool_for(table: DungeonItemTable, room_name: String) -> DungeonItemPool:
	for pool in table.pools:
		if room_name in pool.rooms:
			return pool
	return null


## Picks an entry by weight and, unless the pool allows repeats, takes it out
## of `remaining`. Returns null when the pool has nothing left it may place.
static func _draw(pool: DungeonItemPool, remaining: Array, placed: Dictionary,
		rng: RandomNumberGenerator) -> DungeonItemEntry:
	var options: Array[DungeonItemEntry] = []
	var total := 0.0
	for entry: DungeonItemEntry in (pool.entries if pool.allow_repeats else remaining):
		if pool.skip_placed and placed.has([entry.kind, entry.variant]):
			continue
		options.append(entry)
		total += entry.weight
	if options.is_empty():
		return null
	var roll := rng.randf() * total
	var picked: DungeonItemEntry = options.back()
	for entry in options:
		roll -= entry.weight
		if roll < 0.0:
			picked = entry
			break
	remaining.erase(picked)
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
