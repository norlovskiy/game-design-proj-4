extends SceneTree
## Checks the locked door, the key and the boss gate in a generated dungeon.
##
## Run: godot --headless --path . -s tests/gate_test.gd
## On a fresh clone, run `godot --headless --path . --import` once first.

const MapPiece := preload("res://scripts/mapgen/map_piece.gd")

var _failures := 0


func _init() -> void:
	await process_frame
	for map_seed in [3000, 4242, 77, 91000]:
		await _check(map_seed)
	print("gates: %d failures" % _failures)
	quit(1 if _failures > 0 else 0)


func _check(map_seed: int) -> void:
	var scene: Node2D = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	scene.enter_dungeon(map_seed)
	var dungeon: Dungeon = scene.dungeon
	var player: CharacterBody2D = scene.player_body
	for enemy in dungeon.enemies.get_children():
		if enemy != dungeon.boss:
			enemy.free()
	await _frames(5)

	var lock_gate: DungeonGate
	for gate: DungeonGate in dungeon.gates.get_children():
		if gate.requires_key:
			lock_gate = gate
	if lock_gate == null or dungeon.boss_gate == null or dungeon.gates.get_child_count() != 2:
		_fail(map_seed, "expected one locked gate and one boss gate")
		scene.free()
		return

	# The locked gate sits in the item lock room's door to the goal.
	var gate_piece: MapPiece = dungeon.result.pieces[dungeon.piece_at(lock_gate.position + Vector2(16, 16))]
	if gate_piece.name != "item_lock":
		_fail(map_seed, "locked gate is in %s" % gate_piece.name)
	if not lock_gate.closed or lock_gate.get_node("CollisionShape2D").disabled:
		_fail(map_seed, "locked gate should start lowered and solid")

	# The key is in the key room.
	var key: ItemPickup
	for pickup: ItemPickup in dungeon.items.get_children():
		if pickup.kind == ItemPickup.Kind.KEY:
			if key != null:
				_fail(map_seed, "more than one key")
			key = pickup
	if key == null:
		_fail(map_seed, "no key in the dungeon")
	elif dungeon.result.pieces[dungeon.piece_at(key.position)].name != "item_key":
		_fail(map_seed, "key is not in the key room")

	# Without a key: F does nothing but say so.
	var beside := lock_gate.global_position + Vector2(16, 54)
	beside.x += -30.0 if _open_side_is_left(dungeon, lock_gate) else 30.0
	player.global_position = beside
	await _frames(20)
	await _press(KEY_F)
	if not lock_gate.closed:
		_fail(map_seed, "gate opened without a key")
	var prompt: Label = lock_gate._prompt_label
	if not lock_gate._prompt.visible or not prompt.text.begins_with("Locked"):
		_fail(map_seed, "no locked message after pressing F without a key (shows '%s')" % prompt.text)

	# With the key: F opens it and uses the key up.
	if key != null:
		key.collect(player)
	await _press(KEY_F)
	await _frames(45)
	if lock_gate.closed or not lock_gate.get_node("CollisionShape2D").disabled:
		_fail(map_seed, "gate did not open with a key")
	if player.key_count != 0:
		_fail(map_seed, "key was not used up")

	# Boss gate: open until the player is well inside, shut during the fight,
	# open again when the boss dies.
	var boss_gate := dungeon.boss_gate
	if boss_gate.closed:
		_fail(map_seed, "boss gate should start raised")
	var boss_piece: MapPiece
	for piece: MapPiece in dungeon.result.pieces:
		if piece.name == "boss":
			boss_piece = piece
	var door_cell: Vector2i = boss_gate.get_meta("cell")
	var inward := 1 if door_cell.x == boss_piece.pos.x else -1
	var floor_y := (boss_piece.pos.y + boss_piece.size.y - 1) * 32.0 - 10.0
	player.is_safe = false
	player.global_position = dungeon.to_global(Vector2((door_cell.x + 0.5) * 32.0, floor_y))
	await _frames(10)
	if boss_gate.closed:
		_fail(map_seed, "boss gate shut while the player was still in the doorway")
	player.global_position = dungeon.to_global(Vector2((door_cell.x + inward * 4 + 0.5) * 32.0, floor_y))
	await _frames(45)
	if not boss_gate.closed or boss_gate.get_node("CollisionShape2D").disabled:
		_fail(map_seed, "boss gate did not shut behind the player")
	dungeon.boss.take_damage(1000000)
	await _frames(45)
	if boss_gate.closed:
		_fail(map_seed, "boss gate did not reopen after the boss died")
	scene.free()


## Whether the room side of a gate (the side the player unlocks it from) is
## to its left.
func _open_side_is_left(dungeon: Dungeon, gate: DungeonGate) -> bool:
	var cell: Vector2i = gate.get_meta("cell")
	return dungeon.result.get_owner(cell.x - 1, cell.y) == dungeon.result.get_owner(cell.x, cell.y)


func _press(keycode: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	event.keycode = keycode
	event.pressed = true
	Input.parse_input_event(event)
	await _frames(6)
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await _frames(6)


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _fail(map_seed: int, message: String) -> void:
	_failures += 1
	printerr("seed %d: %s" % [map_seed, message])
