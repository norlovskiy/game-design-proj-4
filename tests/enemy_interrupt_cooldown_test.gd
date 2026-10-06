extends SceneTree
## Run: godot --headless --path . -s tests/enemy_interrupt_cooldown_test.gd

const NIGHTBORNE_SCENE: PackedScene = preload("res://scenes/nightborne.tscn")
const BRINGER_SCENE: PackedScene = preload("res://scenes/bringer_of_death.tscn")
const DEMON_SCENE: PackedScene = preload("res://scenes/flying_demon.tscn")
const RANGER_SCENE: PackedScene = preload("res://scenes/leaf_ranger.tscn")


class TestPlayer extends Node2D:
	var is_safe := false
	var arena_rect := Rect2()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var passed := await _check_interrupt(NIGHTBORNE_SCENE, NightBorne.State.ATTACK,
		NightBorne.State.HURT, [&"_cooldown_remaining"])
	passed = await _check_interrupt(BRINGER_SCENE, BringerOfDeath.State.ATTACK,
		BringerOfDeath.State.HURT,
		[&"_melee_cooldown_remaining", &"_spell_cooldown_remaining"]) and passed
	passed = await _check_interrupt(BRINGER_SCENE, BringerOfDeath.State.CAST,
		BringerOfDeath.State.HURT,
		[&"_melee_cooldown_remaining", &"_spell_cooldown_remaining"]) and passed
	passed = await _check_interrupt(DEMON_SCENE, FlyingDemon.State.SHOOT,
		FlyingDemon.State.HURT, [&"_cooldown_remaining"]) and passed
	passed = await _check_interrupt(RANGER_SCENE, LeafRanger.Attack.MELEE,
		LeafRanger.State.HURT, [&"_interrupt_cooldown_remaining"]) and passed
	passed = await _check_idle_hit() and passed
	passed = await _check_attack_delay() and passed
	print("Enemy interrupt cooldown: %s" % ("passed" if passed else "failed"))
	quit(0 if passed else 1)


func _check_interrupt(scene: PackedScene, attack: int, hurt: int,
		cooldowns: Array[StringName]) -> bool:
	var enemy := scene.instantiate() as Enemy
	root.add_child(enemy)
	var sprite := enemy.get_node("AnimatedSprite2D") as AnimatedSprite2D
	if enemy is LeafRanger:
		enemy.call("_start_attack", attack)
	else:
		enemy.call("_set_state", attack)
	enemy.take_damage(1)
	if enemy.get("_state") != hurt:
		push_error("%s attack was not interrupted by damage" % enemy.name)
		enemy.queue_free()
		return false
	await sprite.animation_finished
	var passed := true
	for cooldown in cooldowns:
		if float(enemy.get(cooldown)) < Enemy.INTERRUPTED_ATTACK_COOLDOWN - 0.02:
			push_error("%s could attack again immediately after interruption (%s)" % [enemy.name, cooldown])
			passed = false
	enemy.queue_free()
	return passed


func _check_idle_hit() -> bool:
	var enemy := NIGHTBORNE_SCENE.instantiate() as Enemy
	root.add_child(enemy)
	var sprite := enemy.get_node("AnimatedSprite2D") as AnimatedSprite2D
	enemy.take_damage(1)
	await sprite.animation_finished
	var passed := is_zero_approx(float(enemy.get("_cooldown_remaining")))
	if not passed:
		push_error("Damage outside an attack added an attack cooldown")
	enemy.queue_free()
	return passed


func _check_attack_delay() -> bool:
	var world := Node2D.new()
	root.add_child(world)
	var floor_body := StaticBody2D.new()
	var floor_shape := CollisionShape2D.new()
	var floor_rect := RectangleShape2D.new()
	floor_rect.size = Vector2(400, 20)
	floor_shape.shape = floor_rect
	floor_body.add_child(floor_shape)
	floor_body.position.y = 20.0
	world.add_child(floor_body)
	var player := TestPlayer.new()
	player.add_to_group(&"player")
	player.position.x = 35.0
	world.add_child(player)
	var enemy := NIGHTBORNE_SCENE.instantiate() as Enemy
	world.add_child(enemy)
	var sprite := enemy.get_node("AnimatedSprite2D") as AnimatedSprite2D
	enemy.call("_set_state", NightBorne.State.ATTACK)
	enemy.take_damage(1)
	await sprite.animation_finished
	for i in 12:
		await physics_frame
	if enemy.get("_state") == NightBorne.State.ATTACK:
		push_error("NightBorne attacked during interruption cooldown")
		world.queue_free()
		return false
	for i in 24:
		await physics_frame
	var passed: bool = enemy.get("_state") == NightBorne.State.ATTACK
	if not passed:
		push_error("NightBorne did not attack after interruption cooldown")
	world.queue_free()
	return passed
