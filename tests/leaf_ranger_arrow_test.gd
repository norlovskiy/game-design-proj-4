extends SceneTree
## Run: godot --headless --path . -s tests/leaf_ranger_arrow_test.gd

const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")
const ARROW_SCENE: PackedScene = preload("res://scenes/leaf_ranger_arrow.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := Node2D.new()
	root.add_child(world)
	var ground := StaticBody2D.new()
	ground.position.y = 20.0
	var ground_shape := CollisionShape2D.new()
	var ground_rect := RectangleShape2D.new()
	ground_rect.size = Vector2(1200, 20)
	ground_shape.shape = ground_rect
	ground.add_child(ground_shape)
	world.add_child(ground)
	var wall := StaticBody2D.new()
	wall.position = Vector2(350, -40)
	var wall_shape := CollisionShape2D.new()
	var wall_rect := RectangleShape2D.new()
	wall_rect.size = Vector2(20, 100)
	wall_shape.shape = wall_rect
	wall.add_child(wall_shape)
	world.add_child(wall)

	var player := PLAYER_SCENE.instantiate() as Node2D
	world.add_child(player)
	var body := player.get_node("CharacterBody2D") as CharacterBody2D
	await _frames(3)
	if not body.is_on_floor():
		_fail("Player did not settle on the test floor")
		return
	var initial_hp := int(body.get("hp"))
	body.call("_start_roll", 1)

	# Overlap callbacks must leave arrows intact during a roll.
	var overlapping := ARROW_SCENE.instantiate() as LeafRangerArrow
	overlapping.configure(0, Vector2.RIGHT, 0.0)
	world.add_child(overlapping)
	overlapping.global_position = body.global_position + Vector2(0, -12)
	await _frames(2)
	if not is_instance_valid(overlapping) or overlapping.get("_exploded"):
		_fail("Arrow exploded when it overlapped a rolling player")
		return
	overlapping.queue_free()
	await physics_frame

	# A fast arrow crosses the whole player in one frame, so its ray must skip them.
	var passing := ARROW_SCENE.instantiate() as LeafRangerArrow
	passing.configure(0, Vector2.RIGHT, 6000.0)
	world.add_child(passing)
	passing.global_position = body.global_position + Vector2(-70, -12)
	await _frames(2)
	if not is_instance_valid(passing) or passing.global_position.x <= body.global_position.x + 20:
		_fail("Arrow did not pass through a rolling player")
		return
	if int(body.get("hp")) != initial_hp:
		_fail("Rolling player took damage from an arrow")
		return
	await _frames(5)
	if is_instance_valid(passing) or world.get_node_or_null("LeafRangerEffect") == null:
		_fail("Arrow did not explode on the wall after passing the player")
		return

	await _frames(45)
	if body.get("is_rolling"):
		_fail("Player roll did not finish")
		return
	var hitting := ARROW_SCENE.instantiate() as LeafRangerArrow
	hitting.configure(0, Vector2.RIGHT, 6000.0)
	world.add_child(hitting)
	hitting.global_position = body.global_position + Vector2(-70, -12)
	await _frames(2)
	if int(body.get("hp")) >= initial_hp or is_instance_valid(hitting):
		_fail("Arrow did not hit a player after their roll ended")
		return
	print("Leaf Ranger arrows pass through rolls and hit solid targets")
	quit(0)


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
