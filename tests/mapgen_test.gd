extends SceneTree
## Generates many maps and checks the rules hold for every seed.
##
## Run: godot --headless --path . -s tests/mapgen_test.gd
## Optional: `-- --png <dir>` also writes the first few maps as images.

const MapGenerator := preload("res://scripts/mapgen/map_generator.gd")
const MapPiece := preload("res://scripts/mapgen/map_piece.gd")

const SEEDS := 300
const REQUIRED_ONCE := ["start", "goal", "shop", "boss", "vertical_lock", "item_lock", "item_key"]

var _failures := 0
var _seed := 0


func _init() -> void:
	var png_dir := ""
	var args := OS.get_cmdline_user_args()
	if args.size() == 2 and args[0] == "--png":
		png_dir = args[1]

	var generator := MapGenerator.new()
	var total_attempts := 0
	var worst_attempts := 0
	var orders := {}
	for i in SEEDS:
		_seed = i * 1000
		var result := generator.generate(_seed)
		if not result.ok:
			_fail("generation failed: %s" % result.error)
			continue
		total_attempts += result.attempts
		worst_attempts = maxi(worst_attempts, result.attempts)
		_check(result, generator)
		orders[_mid_order(result)] = true
		var again := generator.generate(_seed)
		if again.tiles != result.tiles:
			_fail("same seed produced a different map")
		if png_dir != "" and i < 6:
			_write_png(result, png_dir.path_join("map_%d.png" % _seed))

	print("%d seeds, %d failures, mean attempts %.2f, worst %d, %d distinct room orders" % [
		SEEDS, _failures, float(total_attempts) / SEEDS, worst_attempts, orders.size()])
	quit(1 if _failures > 0 else 0)


func _check(result: MapGenerator.Result, generator: MapGenerator) -> void:
	var pieces: Array = result.pieces
	if result.size.x > generator.max_size.x or result.size.y > generator.max_size.y:
		_fail("map is %s, larger than %s" % [result.size, generator.max_size])

	var counts := {}
	for piece: MapPiece in pieces:
		counts[piece.name] = counts.get(piece.name, 0) + 1
	for room_name in REQUIRED_ONCE:
		if counts.get(room_name, 0) != 1:
			_fail("expected one %s, found %d" % [room_name, counts.get(room_name, 0)])
	_check_range("item rooms", counts.get("item", 0), generator.item_rooms)
	_check_range("dead ends", counts.get("dead_end", 0), generator.dead_ends)

	for i in pieces.size():
		for j in range(i + 1, pieces.size()):
			if pieces[i].rect().intersects(pieces[j].rect()):
				_fail("pieces %d and %d overlap" % [i, j])

	# One tree rooted at the start room.
	for piece: MapPiece in pieces:
		if piece.name == "start":
			if piece.parent != null:
				_fail("start room has a parent")
			continue
		var steps := 0
		var at: MapPiece = piece
		while at.parent != null and steps <= pieces.size():
			at = at.parent
			steps += 1
		if at.name != "start":
			_fail("piece %d (%s) is not connected to the start room" % [piece.index, piece.name])

	# Ordering rules.
	_check_behind(pieces, "item_key", "vertical_lock", "upper_b")
	_check_behind(pieces, "goal", "item_lock", "locked")
	_check_behind(pieces, "boss", "shop", "")
	for piece: MapPiece in pieces:
		match piece.name:
			"shop", "boss", "vertical_lock", "item_lock":
				if piece.zone != 0:
					_fail("%s is behind a lock (zone %d)" % [piece.name, piece.zone])
			"item_key":
				if piece.zone != MapPiece.ZONE_DOUBLE_JUMP:
					_fail("item_key zone is %d" % piece.zone)
			"goal":
				if piece.zone != MapPiece.ZONE_ITEM_LOCK:
					_fail("goal zone is %d" % piece.zone)
		if piece.name == "item_lock" and piece.entry_door.role != "entry":
			_fail("item_lock entered through %s" % piece.entry_door.role)
		if piece.name == "vertical_lock" and not piece.entry_door.role.begins_with("lower"):
			_fail("vertical_lock entered through %s" % piece.entry_door.role)

	_check_tiles(result)


## The nearest room above `room_name` in the tree must be `behind`, left
## through the door with `role` (any door if role is empty).
func _check_behind(pieces: Array, room_name: String, behind: String, role: String) -> void:
	for piece: MapPiece in pieces:
		if piece.name != room_name:
			continue
		var at: MapPiece = piece
		while at.parent != null and at.parent.kind != "room":
			at = at.parent
		if at.parent == null or at.parent.name != behind:
			_fail("%s is not behind %s" % [room_name, behind])
		elif role != "" and at.parent_door.role != role:
			_fail("%s hangs off %s door %s, expected %s" % [room_name, behind, at.parent_door.role, role])


## Walking through open tiles from the start room must reach every piece, and
## every open door tile must lead somewhere.
func _check_tiles(result: MapGenerator.Result) -> void:
	var size: Vector2i = result.size
	var seen := PackedByteArray()
	seen.resize(size.x * size.y)
	var queue: Array[Vector2i] = []
	for y in size.y:
		for x in size.x:
			var owner := result.get_owner(x, y)
			if queue.is_empty() and owner >= 0 and result.pieces[owner].name == "start" \
					and result.get_tile(x, y) == MapPiece.EMPTY:
				queue.append(Vector2i(x, y))
				seen[y * size.x + x] = 1
	var reached := {}
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_back()
		reached[result.get_owner(cell.x, cell.y)] = true
		for step in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = cell + step
			if next.x < 0 or next.y < 0 or next.x >= size.x or next.y >= size.y:
				_fail("open tile at the map edge: %s" % cell)
				continue
			var tile := result.get_tile(next.x, next.y)
			if seen[next.y * size.x + next.x] == 0 and (tile == MapPiece.EMPTY or tile == MapPiece.DOOR):
				seen[next.y * size.x + next.x] = 1
				queue.append(next)
	for piece: MapPiece in result.pieces:
		if not reached.has(piece.index):
			_fail("piece %d (%s) can't be reached through open tiles" % [piece.index, piece.name])
		for door in piece.doors:
			if not door.used:
				continue
			for cell in door.cells:
				var outside: Vector2i = piece.pos + cell + door.dir
				if result.get_tile(outside.x, outside.y) != MapPiece.DOOR:
					_fail("door on piece %d (%s) opens onto a wall" % [piece.index, piece.name])


func _check_range(what: String, count: int, allowed: Vector2i) -> void:
	if count < allowed.x or count > allowed.y:
		_fail("%d %s, expected %d-%d" % [count, what, allowed.x, allowed.y])


func _mid_order(result: MapGenerator.Result) -> String:
	var order := ""
	for piece: MapPiece in result.pieces:
		if piece.name in ["vertical_lock", "shop", "item_lock"]:
			order += piece.name + ">"
	return order


func _fail(message: String) -> void:
	_failures += 1
	printerr("seed %d: %s" % [_seed, message])


func _write_png(result: MapGenerator.Result, path: String) -> void:
	var colors := {
		MapPiece.EMPTY: Color(0.85, 0.85, 0.8),
		MapPiece.SOLID: Color(0.25, 0.25, 0.3),
		MapPiece.DOOR: Color(0.9, 0.3, 0.3),
		MapPiece.PLATFORM: Color(0.3, 0.6, 0.9),
		MapPiece.ROCK: Color(0.05, 0.05, 0.07),
	}
	var image := Image.create(result.size.x, result.size.y, false, Image.FORMAT_RGB8)
	for y in result.size.y:
		for x in result.size.x:
			image.set_pixel(x, y, colors[result.get_tile(x, y)])
	image.resize(result.size.x * 8, result.size.y * 8, Image.INTERPOLATE_NEAREST)
	image.save_png(path)
