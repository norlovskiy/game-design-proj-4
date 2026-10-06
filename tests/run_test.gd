extends SceneTree
## Checks how a run is won and lost, the double jump gate, and that enemies
## outside the boss room ignore a player inside it.
##
## Run: godot --headless --path . -s tests/run_test.gd
## On a fresh clone, run `godot --headless --path . --import` once first.

const MapPiece := preload("res://scripts/mapgen/map_piece.gd")
const CELL := 32.0

var _failures := 0


func _init() -> void:
	await process_frame
	await _check_win_and_restart()
	await _check_lose()
	await _check_double_jump_gap()
	await _check_arena_targeting()
	await _check_boss_drops_ability()
	print("run: %d failures" % _failures)
	quit(1 if _failures > 0 else 0)


func _new_run(map_seed: int) -> Node2D:
	var scene: Node2D = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	scene.enter_dungeon(map_seed)
	for enemy in scene.dungeon.enemies.get_children():
		if enemy != scene.dungeon.boss:
			enemy.free()
	await _frames(3)
	return scene


func _check_win_and_restart() -> void:
	var scene := await _new_run(3000)
	var dungeon: Dungeon = scene.dungeon
	var player: CharacterBody2D = scene.player_body
	var treasure := dungeon.treasure
	if treasure == null or dungeon.result.pieces[dungeon.piece_at(treasure.position)].name != "goal":
		_fail("no treasure in the goal room")
		scene.free()
		return
	if scene.end_screen.visible:
		_fail("end screen showing at the start of a run")

	# R no longer rerolls.
	var seed_before: int = dungeon.result.map_seed
	await _press(KEY_R)
	if dungeon.result.map_seed != seed_before:
		_fail("R still rerolls the dungeon")

	player.add_gold(42)
	player.receive_pickup(ItemPickup.Kind.SWORD, 0)
	player.receive_pickup(ItemPickup.Kind.RED_POTION, 0)
	player.receive_pickup(ItemPickup.Kind.DOUBLE_JUMP, 0)
	player.hp = 2
	player.global_position = dungeon.to_global(treasure.position) + Vector2(0, 10)
	await _frames(20)
	if not treasure._prompt.visible:
		_fail("treasure shows no prompt with the player beside it")
	await _press(KEY_F)
	if not scene.end_screen.visible or not scene.end_screen._title.text.contains("TREASURE"):
		_fail("claiming the treasure did not show the win screen")
	if not paused:
		_fail("game keeps running behind the win screen")

	# Enter starts a completely fresh run.
	var enter := InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.physical_keycode = KEY_ENTER
	enter.pressed = true
	Input.parse_input_event(enter)
	await process_frame
	await process_frame
	await _frames(3)
	var fresh: Node2D
	for child in root.get_children():
		if child != scene and child.has_method("enter_dungeon") and not child.is_queued_for_deletion():
			fresh = child
	if fresh == null:
		_fail("Enter on the end screen did not start a new run")
		return
	var new_player: CharacterBody2D = fresh.player_body
	if paused:
		_fail("new run started paused")
	if new_player.gold != 0 or new_player.has_sword or new_player.potion_count != 0 \
			or new_player.has_double_jump or new_player.key_count != 0 or new_player.hp != new_player.max_hp:
		_fail("new run kept something from the old one")
	if fresh.dungeon.result == null or fresh.end_screen.visible:
		_fail("new run has no dungeon or still shows the end screen")
	print("  win -> restart: gold %d, hp %d/%d, new seed %d (was %d)" % [
		new_player.gold, new_player.hp, new_player.max_hp, fresh.dungeon.result.map_seed, seed_before])
	fresh.free()
	await _frames(2)


func _check_lose() -> void:
	var scene := await _new_run(4242)
	var player: CharacterBody2D = scene.player_body
	player.is_safe = false
	player.hp = 1
	player.take_hit()
	await _frames(30)
	if not player.is_dead:
		_fail("player did not die on their last point of health")
	if scene.end_screen.visible:
		_fail("lose screen appeared before the death could be seen")
	await _frames(100)
	if not scene.end_screen.visible or not scene.end_screen._title.text.contains("DIED"):
		_fail("dying did not show the lose screen")
	if not scene.end_screen._prompt.text.contains("Try again"):
		_fail("lose screen does not offer to try again")
	scene.free()
	await _frames(2)


## From the ledge beside the vertical lock's upper door A, door B across the
## gap must be out of reach on one jump and reachable with a second.
func _check_double_jump_gap() -> void:
	var scene := await _new_run(3000)
	var dungeon: Dungeon = scene.dungeon
	var player: CharacterBody2D = scene.player_body
	var room: MapPiece
	for piece: MapPiece in dungeon.result.pieces:
		if piece.name == "vertical_lock":
			room = piece
	var door_a := room.door_by_role("upper_a")
	var door_b := room.door_by_role("upper_b")
	var toward: int = signi(door_b.cells[0].x - door_a.cells[0].x)
	# Stand on the ledge two cells in from door A, at its edge over the gap.
	var ledge_cell: Vector2i = room.pos + Vector2i(door_a.cells[0].x + toward * 2, door_a.cells[1].y)
	var start := dungeon.to_global(Vector2((ledge_cell.x + 0.5 + toward * 0.3) * CELL, (ledge_cell.y + 1) * CELL - 10.0))
	var goal_x: int = room.pos.x + door_b.cells[0].x

	var single := false
	for run_up in [0, 4, 8]:
		if await _try_gap(player, start, toward, goal_x, [run_up]):
			single = true
	if single:
		_fail("door B can be reached with a single jump")

	player.has_double_jump = true
	var double := 0
	var tried := 0
	for second_jump in range(10, 46, 4):
		tried += 1
		if await _try_gap(player, start, toward, goal_x, [0, second_jump]):
			double += 1
	if double == 0:
		_fail("door B can't be reached even with a double jump")
	print("  vertical lock gap: single jump crosses %s; double jump crosses on %d of %d timings" % [single, double, tried])
	scene.free()
	await _frames(2)


## Runs toward the gap, pressing jump on the given frames. Returns whether
## the player ends up standing in door B's column.
func _try_gap(player: CharacterBody2D, start: Vector2, toward: int, goal_x: int, jump_frames: Array) -> bool:
	player.global_position = start - Vector2(toward * 20.0, 0)
	player.velocity = Vector2.ZERO
	await _frames(8)
	var move := _key(KEY_D if toward > 0 else KEY_A, true)
	Input.parse_input_event(move)
	var reached := false
	for frame in 110:
		if frame in jump_frames:
			Input.parse_input_event(_key(KEY_SPACE, true))
		elif frame - 2 in jump_frames:
			Input.parse_input_event(_key(KEY_SPACE, false))
		await physics_frame
		if int(floor(player.global_position.x / CELL)) == goal_x and player.is_on_floor():
			reached = true
			break
	Input.parse_input_event(_key(KEY_D if toward > 0 else KEY_A, false))
	Input.parse_input_event(_key(KEY_SPACE, false))
	await _frames(4)
	return reached


func _check_arena_targeting() -> void:
	var scene := await _new_run(3000)
	var dungeon: Dungeon = scene.dungeon
	var player: CharacterBody2D = scene.player_body
	var boss_room: MapPiece
	for piece: MapPiece in dungeon.result.pieces:
		if piece.name == "boss":
			boss_room = piece
	var outside: Node2D = load("res://scenes/flying_demon.tscn").instantiate()
	outside.position = Vector2(boss_room.pos) * CELL + Vector2(-48, 96)
	dungeon.enemies.add_child(outside)
	player.global_position = dungeon.to_global(dungeon.floor_middle("boss")) + Vector2(0, -10)
	await _frames(10)
	if not player.arena_rect.has_area():
		_fail("player in the boss room has no arena set")
	if outside.find_player() != null:
		_fail("an enemy outside the boss room can target the player inside it")
	if dungeon.boss.find_player() != player:
		_fail("the boss can't target the player in its own room")
	player.global_position = outside.global_position + Vector2(-40, 0)
	await _frames(10)
	if player.arena_rect.has_area() or outside.find_player() != player:
		_fail("enemies still ignore the player after they leave the boss room")
	scene.free()
	await _frames(2)


func _check_boss_drops_ability() -> void:
	var scene := await _new_run(4242)
	var dungeon: Dungeon = scene.dungeon
	var boss := dungeon.boss
	var holder := boss.get_parent()
	boss.take_damage(1000000)
	await _frames(5)
	var abilities := 0
	for child in holder.get_children():
		if child is ItemPickup and child.kind == ItemPickup.Kind.DOUBLE_JUMP:
			abilities += 1
			if dungeon.result.pieces[dungeon.piece_at(child.position)].name != "boss":
				_fail("ability dropped outside the boss room")
			if not child.collect(scene.player_body) or not scene.player_body.has_double_jump:
				_fail("picking up the ability did not grant double jump")
	if abilities != 1:
		_fail("boss dropped %d double jump abilities" % abilities)
	scene.free()


func _key(keycode: Key, pressed: bool) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	event.keycode = keycode
	event.pressed = pressed
	return event


func _press(keycode: Key) -> void:
	Input.parse_input_event(_key(keycode, true))
	await _frames(6)
	Input.parse_input_event(_key(keycode, false))
	await _frames(6)


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _fail(message: String) -> void:
	_failures += 1
	printerr(message)
