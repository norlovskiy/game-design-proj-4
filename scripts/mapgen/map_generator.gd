extends RefCounted
## Grows a metroidvania map from room data.
##
## The map is a tree of pieces. Generation places the start room, then keeps
## attaching a chain of corridor pieces (halls and shafts) ending in a room to
## an open door of something already placed. Pieces never overlap and only
## connect where they were attached, so a lock can't be walked around.
##
## Progression: shop -> boss (grants double jump) -> vertical lock upper B ->
## item key -> item lock -> goal. The three mid rooms (vertical lock, shop,
## item lock) are placed in random order.

const MapPiece := preload("res://scripts/mapgen/map_piece.gd")
const RoomTemplate := preload("res://scripts/mapgen/room_template.gd")

## Corridor chains as strings of H (hall) and S (shaft). Every chain ends in a
## hall so rooms are never entered straight from a shaft.
const MAIN_CHAINS: Array[String] = ["H", "H", "H", "HSH", "HSH", "HSH", "SH", "HSHSH"]
const BRANCH_CHAINS: Array[String] = ["H", "H", "HSH"]
const DIRECT_CHAINS: Array[String] = ["H"]

const HALL_HEIGHT := 5
const SHAFT_WIDTH := 6


class Result:
	var ok := false
	var error := ""
	var map_seed := 0
	## How many seeds were tried, starting at map_seed.
	var attempts := 0
	var size := Vector2i.ZERO
	var tiles := PackedByteArray()
	## Index into pieces for each tile, or -1 for rock.
	var owner := PackedInt32Array()
	var pieces: Array = []

	func get_tile(x: int, y: int) -> int:
		return tiles[y * size.x + x]

	func get_owner(x: int, y: int) -> int:
		return owner[y * size.x + x]


var rooms_dir := "res://data/rooms"
var max_size := Vector2i(120, 80)
var max_attempts := 50
var tries_per_step := 40
## Total hall length in tiles, including the two door columns.
var hall_length := Vector2i(6, 16)
var dead_end_length := Vector2i(4, 8)
## Tiles the player can rise with a single jump; sets shaft platform spacing.
var jump_up := 3
## Platforms per shaft, not counting the two door landings at the top.
var shaft_platforms := Vector2i(1, 3)
var item_rooms := Vector2i(2, 4)
var dead_ends := Vector2i(2, 3)

var _rng := RandomNumberGenerator.new()
var _templates := {}
var _pieces: Array[MapPiece] = []


func generate(base_seed: int) -> Result:
	var result := Result.new()
	result.map_seed = base_seed
	_templates = RoomTemplate.load_all(rooms_dir)
	for attempt in max_attempts:
		result.attempts = attempt + 1
		_rng.seed = base_seed + attempt
		_pieces = []
		result.error = _build()
		if result.error == "":
			_finalize(result)
			return result
	return result


func _build() -> String:
	for required in ["start", "goal", "shop", "boss", "vertical_lock", "item_lock", "item_key", "item"]:
		if not _templates.has(required):
			return "missing room data: %s" % required

	var start := (_templates.start as RoomTemplate).instantiate(_rng.randf() < 0.5)
	_commit([start])

	var mids: Array[String] = ["vertical_lock", "shop", "item_lock"]
	_shuffle(mids)
	var vertical_lock: MapPiece = null
	for i in mids.size():
		# The first chain must contain a shaft so later rooms have somewhere to branch from.
		var chains := MAIN_CHAINS.filter(func(c: String) -> bool: return i > 0 or c.contains("S"))
		var anchors := _open_sockets("", false)
		match mids[i]:
			"vertical_lock":
				vertical_lock = _attach_room("vertical_lock", ["lower_a", "lower_b"], anchors, chains)
				if vertical_lock == null:
					return "could not place vertical_lock"
				var upper_b := vertical_lock.door_by_role("upper_b")
				if _attach_room("item_key", ["door"], [[vertical_lock, upper_b]], MAIN_CHAINS) == null:
					return "could not place item_key"
			"shop":
				var shop := _attach_room("shop", ["a", "b"], anchors, chains)
				if shop == null:
					return "could not place shop"
				var far_role := "b" if shop.entry_door.role == "a" else "a"
				var far_door := shop.door_by_role(far_role)
				far_door.reserved = "boss"
				if _attach_room("boss", ["door"], [[shop, far_door]], MAIN_CHAINS) == null:
					return "could not place boss"
			"item_lock":
				var item_lock := _attach_room("item_lock", ["entry"], anchors, chains, true)
				if item_lock == null:
					return "could not place item_lock"
				var locked := item_lock.door_by_role("locked")
				if _attach_room("goal", ["door"], [[item_lock, locked]], DIRECT_CHAINS) == null:
					return "could not place goal"

	# Optional branches. The first item room prefers the vertical lock's upper A
	# door, as a reward for the climb.
	var placed_items := 0
	for i in _rng.randi_range(item_rooms.x, item_rooms.y):
		var room: MapPiece = null
		var reward := vertical_lock.door_by_role("upper_a")
		if i == 0 and _rng.randf() < 0.6:
			room = _attach_room("item", ["door"], [[vertical_lock, reward]], BRANCH_CHAINS)
		if room == null:
			room = _attach_room("item", ["door"], _open_sockets("reward", true), BRANCH_CHAINS)
		if room == null:
			break
		placed_items += 1
	if placed_items < item_rooms.x:
		return "could not place enough item rooms"

	var placed_dead_ends := 0
	for i in _rng.randi_range(dead_ends.x, dead_ends.y):
		if not _attach_dead_end(_open_sockets("reward", true)):
			break
		placed_dead_ends += 1
	if placed_dead_ends < dead_ends.x:
		return "could not place enough dead ends"
	return ""


## Unused side doors on placed pieces, as [piece, door] pairs. Doors reserved
## for something other than allow_reserved are skipped, and so are doors
## behind a lock unless any_zone is set.
func _open_sockets(allow_reserved: String, any_zone: bool) -> Array:
	var out := []
	for piece in _pieces:
		for door in piece.doors:
			if door.used or door.sealed or door.dir.y != 0:
				continue
			if door.reserved != "" and door.reserved != allow_reserved:
				continue
			if not any_zone and (piece.zone | door.zone_add) != 0:
				continue
			out.append([piece, door])
	return out


## Attaches a corridor chain ending in the given room to one of the anchors.
## top_entry makes the last hall end in a floor hole the room hangs under.
func _attach_room(template_name: String, entry_roles: Array, anchors: Array,
		chains: Array, top_entry := false) -> MapPiece:
	if anchors.is_empty():
		return null
	for attempt in tries_per_step:
		var anchor: Array = anchors[_rng.randi_range(0, anchors.size() - 1)]
		var chain: String = chains[_rng.randi_range(0, chains.size() - 1)]
		var added := _try_chain(anchor[0], anchor[1], chain, template_name, entry_roles, top_entry)
		if not added.is_empty():
			_commit(added)
			return added.back()
	return null


func _attach_dead_end(anchors: Array) -> bool:
	if anchors.is_empty():
		return false
	for attempt in tries_per_step:
		var anchor: Array = anchors[_rng.randi_range(0, anchors.size() - 1)]
		var door: MapPiece.Door = anchor[1]
		var hall := _make_hall(_rng.randi_range(dead_end_length.x, dead_end_length.y), 0)
		hall.name = "dead_end"
		var entry := hall.door_by_role("left" if door.dir.x > 0 else "right")
		if _place(hall, entry, anchor[0], door, []):
			hall.door_by_role("right" if door.dir.x > 0 else "left").sealed = true
			_commit([hall])
			return true
	return false


## Builds the chain piece by piece from the anchor door. Returns the new
## pieces (room last), or an empty array if anything didn't fit.
func _try_chain(anchor: MapPiece, anchor_door: MapPiece.Door, chain: String,
		template_name: String, entry_roles: Array, top_entry: bool) -> Array[MapPiece]:
	var added: Array[MapPiece] = []
	var from := anchor
	var from_door := anchor_door
	for i in chain.length():
		var heading := from_door.dir.x
		var piece: MapPiece
		var entry: MapPiece.Door
		var exit: MapPiece.Door
		if chain[i] == "H":
			var hole := heading if top_entry and i == chain.length() - 1 else 0
			piece = _make_hall(_rng.randi_range(hall_length.x, hall_length.y), hole)
			entry = piece.door_by_role("left" if heading > 0 else "right")
			exit = piece.door_by_role("right" if heading > 0 else "left")
			if hole != 0:
				exit.sealed = true
				exit = piece.door_by_role("down")
		else:
			piece = _make_shaft(_rng.randi_range(shaft_platforms.x, shaft_platforms.y))
			var near := "l" if heading > 0 else "r"
			var far := "r" if heading > 0 else "l"
			var enters_low := _rng.randf() < 0.5
			# Mostly carry on in the same direction, sometimes double back.
			var exit_side := far if _rng.randf() < 0.65 else near
			entry = piece.door_by_role(("b" if enters_low else "t") + near)
			exit = piece.door_by_role(("t" if enters_low else "b") + exit_side)
		if not _place(piece, entry, from, from_door, added):
			return []
		added.append(piece)
		from = piece
		from_door = exit

	var options := []
	for mirror in [false, true]:
		var room := (_templates[template_name] as RoomTemplate).instantiate(mirror)
		for door in room.doors:
			if door.role in entry_roles and door.dir == -from_door.dir:
				options.append([room, door])
	if options.is_empty():
		return []
	var option: Array = options[_rng.randi_range(0, options.size() - 1)]
	if not _place(option[0], option[1], from, from_door, added):
		return []
	added.append(option[0])
	return added


## Positions piece so its entry door meets from_door, and links it to its
## parent. Fails if it overlaps anything or pushes the map past max_size.
func _place(piece: MapPiece, entry: MapPiece.Door, from: MapPiece, from_door: MapPiece.Door,
		pending: Array[MapPiece]) -> bool:
	if entry.dir != -from_door.dir or entry.cells.size() != from_door.cells.size():
		return false
	piece.pos = from.pos + from_door.cells[0] + from_door.dir - entry.cells[0]
	for i in entry.cells.size():
		if piece.pos + entry.cells[i] != from.pos + from_door.cells[i] + from_door.dir:
			return false
	var rect := piece.rect()
	var bounds := rect
	for other in _pieces + pending:
		if rect.intersects(other.rect()):
			return false
		bounds = bounds.merge(other.rect())
	if bounds.size.x > max_size.x or bounds.size.y > max_size.y:
		return false
	piece.parent = from
	piece.parent_door = from_door
	piece.entry_door = entry
	piece.zone = from.zone | from_door.zone_add
	return true


func _commit(added: Array[MapPiece]) -> void:
	for piece in added:
		piece.index = _pieces.size()
		_pieces.append(piece)
		if piece.parent_door != null:
			piece.parent_door.used = true
			piece.entry_door.used = true


## A hall is 3 open tiles tall with a door column at each end. The tile above
## each doorway is solid, so the opening is 2 tall like a room's door.
## hole_side is 0 for none, or +1 / -1 to put a 2-wide floor hole at the
## right / left end for a room entered from above.
func _make_hall(length: int, hole_side: int) -> MapPiece:
	var piece := MapPiece.new()
	piece.kind = "hall"
	piece.name = "hall"
	piece.init_tiles(Vector2i(length, HALL_HEIGHT), MapPiece.SOLID)
	for y in range(1, HALL_HEIGHT - 1):
		for x in range(1, length - 1):
			piece.set_tile(x, y, MapPiece.EMPTY)
	piece.add_door("left", [Vector2i(0, 2), Vector2i(0, 3)], Vector2i.LEFT)
	piece.add_door("right", [Vector2i(length - 1, 2), Vector2i(length - 1, 3)], Vector2i.RIGHT)
	if hole_side != 0:
		var x := length - 3 if hole_side > 0 else 1
		piece.add_door("down", [Vector2i(x, HALL_HEIGHT - 1), Vector2i(x + 1, HALL_HEIGHT - 1)],
				Vector2i.DOWN)
	return piece


## A shaft is 4 open tiles wide with a door on each side at the top and at
## the bottom. Platforms alternate sides, jump_up tiles apart, and a 1-tile
## landing sits under each top door.
func _make_shaft(platform_count: int) -> MapPiece:
	var piece := MapPiece.new()
	piece.kind = "shaft"
	piece.name = "shaft"
	var landing_y := 4
	var height := landing_y + jump_up * (platform_count + 1) + 1
	piece.init_tiles(Vector2i(SHAFT_WIDTH, height), MapPiece.SOLID)
	for y in range(1, height - 1):
		for x in range(1, SHAFT_WIDTH - 1):
			piece.set_tile(x, y, MapPiece.EMPTY)
	piece.set_tile(1, landing_y, MapPiece.PLATFORM)
	piece.set_tile(SHAFT_WIDTH - 2, landing_y, MapPiece.PLATFORM)
	var on_left := _rng.randf() < 0.5
	for i in range(1, platform_count + 1):
		var x := 1 if on_left else SHAFT_WIDTH - 3
		piece.set_tile(x, landing_y + jump_up * i, MapPiece.PLATFORM)
		piece.set_tile(x + 1, landing_y + jump_up * i, MapPiece.PLATFORM)
		on_left = not on_left
	var right := SHAFT_WIDTH - 1
	piece.add_door("tl", [Vector2i(0, 2), Vector2i(0, 3)], Vector2i.LEFT)
	piece.add_door("tr", [Vector2i(right, 2), Vector2i(right, 3)], Vector2i.RIGHT)
	piece.add_door("bl", [Vector2i(0, height - 3), Vector2i(0, height - 2)], Vector2i.LEFT)
	piece.add_door("br", [Vector2i(right, height - 3), Vector2i(right, height - 2)], Vector2i.RIGHT)
	return piece


## Opens used doors, shifts the map to start at (0, 0) and stamps every piece
## into one tile grid. Unused doors stay solid.
func _finalize(result: Result) -> void:
	var bounds := _pieces[0].rect()
	for piece in _pieces:
		bounds = bounds.merge(piece.rect())
	result.ok = true
	result.size = bounds.size
	result.pieces = _pieces
	result.tiles.resize(bounds.size.x * bounds.size.y)
	result.tiles.fill(MapPiece.ROCK)
	result.owner.resize(bounds.size.x * bounds.size.y)
	result.owner.fill(-1)
	for piece in _pieces:
		piece.pos -= bounds.position
		for door in piece.doors:
			if door.used:
				for cell in door.cells:
					piece.set_tile(cell.x, cell.y, MapPiece.DOOR)
		for y in piece.size.y:
			for x in piece.size.x:
				var at := (piece.pos.y + y) * bounds.size.x + piece.pos.x + x
				result.tiles[at] = piece.get_tile(x, y)
				result.owner[at] = piece.index


## Array.shuffle() uses the global RNG, which would break seeded generation.
func _shuffle(items: Array) -> void:
	for i in range(items.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var swap = items[i]
		items[i] = items[j]
		items[j] = swap
