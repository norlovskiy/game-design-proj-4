extends SceneTree
## Run: godot --headless --path . -s tests/player_roll_test.gd


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := Node2D.new()
	root.add_child(world)
	var floor_body := StaticBody2D.new()
	var floor_shape := CollisionShape2D.new()
	var floor_rect := RectangleShape2D.new()
	floor_rect.size = Vector2(1200, 20)
	floor_shape.shape = floor_rect
	floor_body.add_child(floor_shape)
	floor_body.position = Vector2(0, 20)
	world.add_child(floor_body)

	var player_scene: Node2D = load("res://scenes/player.tscn").instantiate()
	world.add_child(player_scene)
	var player := player_scene.get_node("CharacterBody2D") as CharacterBody2D
	var sprite := player.get_node("AnimatedSprite2D") as AnimatedSprite2D
	for i in 3:
		await physics_frame
	if not player.is_on_floor():
		push_error("Player did not settle on the test floor")
		quit(1)
		return

	player.call("_start_roll", 1)
	await sprite.animation_finished
	# Start another roll before physics replaces the finished roll animation.
	player.call("_start_roll", 1)
	if not sprite.is_playing() or sprite.frame != 0:
		push_error("A second roll did not restart the finished animation")
		quit(1)
		return

	for i in 55:
		await physics_frame
	if player.get("is_rolling") or not is_zero_approx(player.velocity.x):
		push_error("Player kept roll speed after the second roll ended")
		quit(1)
		return
	print("Player consecutive rolls stop correctly")
	quit(0)
