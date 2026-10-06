extends SceneTree
## Places items in many generated dungeons and checks the item pools.
##
## Run: godot --headless --path . -s tests/item_test.gd
## On a fresh clone, run `godot --headless --path . --import` once first.

const MapPiece := preload("res://scripts/mapgen/map_piece.gd")

const SEEDS := 60

var _failures := 0
var _seed := 0


func _init() -> void:
	var table: DungeonItemTable = load("res://data/items/castle_items.tres")
	var dungeon := Dungeon.new()
	dungeon.theme = load("res://data/themes/castle_theme.tres")
	dungeon.item_table = table
	root.add_child(dungeon)
	var total := 0
	var seen := {}
	for i in SEEDS:
		_seed = i * 523
		if not dungeon.generate(_seed):
			_fail("generation failed")
			continue
		var map := dungeon.result
		var first := _snapshot(dungeon)
		total += first.size()

		var per_room := {}
		var handed_out := {}
		for pickup: ItemPickup in dungeon.items.get_children():
			var cell := Vector2i((pickup.position / dungeon.cell_size()).floor())
			var owner := map.get_owner(cell.x, cell.y)
			if owner < 0 or map.get_tile(cell.x, cell.y) != MapPiece.EMPTY:
				_fail("item outside open space at %s" % cell)
				continue
			if map.get_tile(cell.x, cell.y + 1) != MapPiece.SOLID:
				_fail("item at %s has no floor under it" % cell)
			per_room[owner] = per_room.get(owner, 0) + 1
			var item := [pickup.kind, pickup.variant]
			seen[item] = true
			var pool := _pool_for(table, map.pieces[owner].name)
			if pool == null:
				_fail("item in %s, which no pool names" % map.pieces[owner].name)
				continue
			if not _in_pool(pool, pickup):
				_fail("item %s is not in the pool for %s" % [item, map.pieces[owner].name])
			if not pool.allow_repeats and handed_out.has(item) and handed_out.size() < pool.entries.size():
				_fail("item %s repeated before the pool ran out" % [item])
			handed_out[item] = true

		for piece: MapPiece in map.pieces:
			var pool := _pool_for(table, piece.name)
			if pool != null and per_room.get(piece.index, 0) != pool.items_per_room:
				_fail("%s has %d items, expected %d" % [piece.name, per_room.get(piece.index, 0), pool.items_per_room])

		dungeon.generate(_seed)
		if _snapshot(dungeon) != first:
			_fail("same seed placed different items")

	print("%d seeds, %d failures, %.1f items per dungeon, %d distinct items seen" % [
		SEEDS, _failures, float(total) / SEEDS, seen.size()])
	quit(1 if _failures > 0 else 0)


func _pool_for(table: DungeonItemTable, room_name: String) -> DungeonItemPool:
	for pool in table.pools:
		if room_name in pool.rooms:
			return pool
	return null


func _in_pool(pool: DungeonItemPool, pickup: ItemPickup) -> bool:
	for entry in pool.entries:
		if entry.kind == pickup.kind and entry.variant == pickup.variant:
			return true
	return false


func _snapshot(dungeon: Dungeon) -> Array:
	var out := []
	for pickup: ItemPickup in dungeon.items.get_children():
		out.append([pickup.kind, pickup.variant, pickup.position])
	return out


func _fail(message: String) -> void:
	_failures += 1
	if _failures <= 20:
		printerr("seed %d: %s" % [_seed, message])
