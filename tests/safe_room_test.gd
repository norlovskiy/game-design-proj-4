extends SceneTree
## Checks that enemies leave the player alone in the shop and attack again
## outside it.
##
## Run: godot --headless --path . -s tests/safe_room_test.gd
## On a fresh clone, run `godot --headless --path . --import` once first.

const MapPiece := preload("res://scripts/mapgen/map_piece.gd")

var _failures := 0


func _init() -> void:
	await process_frame
	var scene: Node2D = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	scene.enter_dungeon(3000)
	var dungeon: Dungeon = scene.dungeon
	var player: CharacterBody2D = scene.player_body
	for enemy in dungeon.enemies.get_children():
		enemy.free()

	var shop := _floor_middle(dungeon, "shop")
	var hall := _floor_middle(dungeon, "hall")
	var enemy: Node2D = load("res://scenes/nightborne.tscn").instantiate()
	enemy.position = shop + Vector2(40, 0)
	dungeon.enemies.add_child(enemy)

	player.global_position = dungeon.to_global(shop) + Vector2(0, -10)
	var hp_before: int = player.hp
	for i in 300:
		await physics_frame
	if not player.is_safe:
		_fail("player standing in the shop is not flagged safe")
	if player.hp != hp_before:
		_fail("player lost %d health in the shop" % (hp_before - player.hp))
	if enemy.find_player() != null:
		_fail("enemy can still target the player in the shop")
	print("  in the shop for 5s next to a NightBorne: health %d -> %d" % [hp_before, player.hp])

	enemy.position = hall + Vector2(40, 0)
	player.global_position = dungeon.to_global(hall) + Vector2(0, -10)
	for i in 300:
		await physics_frame
	if player.is_safe:
		_fail("player standing in a hall is flagged safe")
	if player.hp >= hp_before:
		_fail("enemy did not attack the player outside the shop")
	print("  in a hall for 5s next to the same NightBorne: health %d -> %d" % [hp_before, player.hp])

	print("safe room: %d failures" % _failures)
	quit(1 if _failures > 0 else 0)


## Local position of the middle of the floor of the first piece with a name.
func _floor_middle(dungeon: Dungeon, piece_name: String) -> Vector2:
	for piece: MapPiece in dungeon.result.pieces:
		if piece.name != piece_name or piece.size.x < 9:
			continue
		for y in range(piece.size.y - 1, -1, -1):
			if piece.get_tile(piece.size.x / 2, y) == MapPiece.EMPTY:
				var cell := piece.pos + Vector2i(piece.size.x / 2, y)
				return (Vector2(cell) + Vector2(0.5, 1.0)) * dungeon.cell_size()
	return Vector2.ZERO


func _fail(message: String) -> void:
	_failures += 1
	printerr(message)
