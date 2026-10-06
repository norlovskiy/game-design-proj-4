extends SceneTree
## Run: godot --headless --path . -s tests/player_roll_cancel_test.gd


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
	floor_body.position.y = 20.0
	world.add_child(floor_body)

	var player_scene: Node2D = load("res://scenes/player.tscn").instantiate()
	world.add_child(player_scene)
	var player := player_scene.get_node("CharacterBody2D") as CharacterBody2D
	var sprite := player.get_node("AnimatedSprite2D") as AnimatedSprite2D
	await _frames(3)
	if not player.is_on_floor():
		_fail("Player did not settle on the test floor")
		return

	_press(KEY_SHIFT)
	await _frames(2)
	_release(KEY_SHIFT)
	await _frames(2)
	if not player.get("is_rolling"):
		_fail("Player did not start rolling")
		return
	player.set("stamina", 50.0)
	player.set("stamina_regen_wait", 0.0)
	_press(KEY_J)
	await _frames(2)
	_release(KEY_J)
	if player.get("is_rolling") or not player.get("is_attacking") \
			or sprite.animation != &"attack_1" or not is_zero_approx(player.velocity.x):
		_fail("Attack did not cancel the roll and stop its movement immediately: roll=%s attack=%s anim=%s vx=%s" % [
			player.get("is_rolling"), player.get("is_attacking"), sprite.animation, player.velocity.x])
		return
	var attacking_stamina := float(player.get("stamina"))
	await _frames(8)
	if not is_equal_approx(float(player.get("stamina")), attacking_stamina):
		_fail("Stamina regenerated during an attack")
		return
	await sprite.animation_finished
	await _frames(2)
	if float(player.get("stamina")) <= attacking_stamina:
		_fail("Stamina did not resume regenerating after the attack")
		return

	_press(KEY_SHIFT)
	await _frames(2)
	_release(KEY_SHIFT)
	await _frames(2)
	if not player.get("is_rolling"):
		_fail("Player did not start the second roll")
		return
	_press(KEY_SPACE)
	await _frames(2)
	_release(KEY_SPACE)
	if player.get("is_rolling") or player.velocity.y >= 0.0 \
			or not is_zero_approx(player.velocity.x) or sprite.animation != &"jump":
		_fail("Jump did not cancel the roll without retaining its speed")
		return
	await physics_frame
	if not is_zero_approx(player.velocity.x):
		_fail("Roll speed returned after jumping")
		return
	print("Roll attack and jump cancels stop movement; attacks pause stamina regeneration")
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
