extends SceneTree
## Run: godot --headless --path . -s tests/bringer_attack_pattern_test.gd

const BRINGER_SCENE: PackedScene = preload("res://scenes/bringer_of_death.tscn")


class TestPlayer extends Node2D:
	var is_safe := false
	var arena_rect := Rect2()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var passed := await _check_spells(-160.0)
	passed = await _check_spells(160.0) and passed
	passed = await _check_spells(-160.0, -80.0) and passed
	passed = await _check_melee_timing() and passed
	print("Bringer spell sequence and melee timing: %s" % ("passed" if passed else "failed"))
	quit(0 if passed else 1)


func _check_spells(target_x: float, target_y: float = 0.0) -> bool:
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
	var player := TestPlayer.new()
	player.add_to_group(&"player")
	player.position = Vector2(target_x, target_y)
	world.add_child(player)
	var boss := BRINGER_SCENE.instantiate() as BringerOfDeath
	world.add_child(boss)
	var spells: Array[BringerSpell] = []
	for i in 80:
		await physics_frame
		spells = _spells(world)
		if spells.size() == 3:
			break
	if spells.size() != 3:
		push_error("Bringer spawned %d spells for target x=%s" % [spells.size(), target_x])
		world.queue_free()
		await process_frame
		return false
	var passed := true
	var facing := signf(target_x)
	for index in 3:
		var expected_x := target_x + facing * BringerOfDeath.SPELL_SPACING * (1 - index)
		if not is_equal_approx(spells[index].global_position.x, expected_x):
			push_error("Spell %d spawned at %s instead of %s" % [index, spells[index].global_position.x, expected_x])
			passed = false
		if not is_equal_approx(spells[index].global_position.y, 10.0):
			push_error("Spell %d does not reach the floor from target y=%s" % [index, target_y])
			passed = false
		var damage_area := spells[index].get_node("DamageArea") as Area2D
		var damage_shape := spells[index].get_node("DamageArea/CollisionShape2D") as CollisionShape2D
		var shape_bottom := damage_area.global_position.y + (damage_shape.shape as RectangleShape2D).size.y * 0.5
		if not is_equal_approx(shape_bottom, 10.0):
			push_error("Spell %d hitbox does not end at the floor" % index)
			passed = false
		var sprite := spells[index].get_node("AnimatedSprite2D") as AnimatedSprite2D
		var material := sprite.material as ShaderMaterial
		if material == null or material.shader != Enemy.HIT_FLASH_SHADER \
				or (material.get_shader_parameter("outline_color") as Color).r < 0.9:
			push_error("Bringer spell lacks a visible red outline")
			passed = false
	if not _active(spells[0]) and _active(spells[1]):
		push_error("Second spell activated before the first")
		passed = false
	await _frames(32)
	if not _active(spells[0]) or _active(spells[1]) or _active(spells[2]):
		push_error("First spell did not activate alone")
		passed = false
	await _frames(45)
	if _active(spells[0]) or not _active(spells[1]) or _active(spells[2]):
		push_error("Second spell did not activate after the first")
		passed = false
	await _frames(45)
	if _active(spells[1]) or not _active(spells[2]):
		push_error("Third spell did not activate after the second")
		passed = false
	world.queue_free()
	await process_frame
	return passed


func _check_melee_timing() -> bool:
	var boss := BRINGER_SCENE.instantiate() as BringerOfDeath
	root.add_child(boss)
	var sprite := boss.get_node("AnimatedSprite2D") as AnimatedSprite2D
	var shape := boss.get_node("AttackHitbox/CollisionShape2D") as CollisionShape2D
	boss.call("_set_state", BringerOfDeath.State.ATTACK)
	sprite.pause()
	var passed := sprite.sprite_frames.get_frame_count(&"attack") == 12
	for frame in 12:
		sprite.frame = frame
		await _frames(2)
		if (not shape.disabled) != (frame >= 6 and frame <= 10):
			push_error("Melee hitbox timing is wrong at frame %d" % frame)
			passed = false
	boss.queue_free()
	return passed


func _spells(world: Node2D) -> Array[BringerSpell]:
	var spells: Array[BringerSpell] = []
	for child in world.get_children():
		if child is BringerSpell:
			spells.append(child)
	return spells


func _active(spell: BringerSpell) -> bool:
	return is_instance_valid(spell) and not (spell.get_node("DamageArea/CollisionShape2D") as CollisionShape2D).disabled


func _frames(count: int) -> void:
	for i in count:
		await physics_frame
