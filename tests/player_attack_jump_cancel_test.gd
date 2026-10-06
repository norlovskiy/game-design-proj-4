extends SceneTree
## Run: godot --headless --path . -s tests/player_attack_jump_cancel_test.gd


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := Node2D.new()
	root.add_child(world)
	var floor_body := StaticBody2D.new()
	var floor_shape := CollisionShape2D.new()
	var floor_rect := RectangleShape2D.new()
	floor_rect.size = Vector2(600, 20)
	floor_shape.shape = floor_rect
	floor_body.add_child(floor_shape)
	floor_body.position.y = 20.0
	world.add_child(floor_body)
	var player_scene: Node2D = load("res://scenes/player.tscn").instantiate()
	world.add_child(player_scene)
	var player := player_scene.get_node("CharacterBody2D") as CharacterBody2D
	var sprite := player.get_node("AnimatedSprite2D") as AnimatedSprite2D
	var attack_shape := player.get_node("AttackHitbox/CollisionShape2D") as CollisionShape2D
	player.set("has_double_jump", true)
	await _frames(3)
	if not player.is_on_floor():
		_fail("Player did not settle on the test floor")
		return

	_press(KEY_J)
	await _frames(2)
	_release(KEY_J)
	await _frames(2)
	_press(KEY_J)
	await _frames(2)
	_release(KEY_J)
	await _frames(7)
	if not player.get("is_attacking") or not player.get("queued_second_attack") \
			or attack_shape.disabled:
		_fail("Attack and queued combo were not active before jumping")
		return
	_press(KEY_SPACE)
	await _frames(2)
	_release(KEY_SPACE)
	if player.get("is_attacking") or player.get("queued_second_attack") \
			or player.velocity.y >= 0.0 or sprite.animation != &"jump" or not attack_shape.disabled:
		_fail("Ground jump did not cancel the attack and its hitbox")
		return

	_press(KEY_J)
	await _frames(2)
	_release(KEY_J)
	await _frames(2)
	if not player.get("is_attacking") or player.is_on_floor():
		_fail("Player did not start an air attack")
		return
	_press(KEY_SPACE)
	await _frames(2)
	_release(KEY_SPACE)
	if player.get("is_attacking") or not player.get("air_jump_used") \
			or player.velocity.y >= 0.0 or sprite.animation != &"jump":
		_fail("Double jump did not cancel the air attack")
		return
	print("Ground and double jumps cancel attacks")
	quit(0)


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _press(keycode: Key) -> void:
	_send_key(keycode, true)


func _release(keycode: Key) -> void:
	_send_key(keycode, false)


func _send_key(keycode: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = pressed
	Input.parse_input_event(event)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
