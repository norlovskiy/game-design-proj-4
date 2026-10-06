extends SceneTree
## Run: godot --headless --path . -s tests/melee_hit_stun_test.gd

const NIGHTBORNE_SCENE: PackedScene = preload("res://scenes/nightborne.tscn")
const BRINGER_SCENE: PackedScene = preload("res://scenes/bringer_of_death.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var passed := await _check_enemy(NIGHTBORNE_SCENE, NightBorne.State.ATTACK,
		NightBorne.State.HURT, NightBorne.State.IDLE, NightBorne.State.DEAD)
	passed = await _check_enemy(BRINGER_SCENE, BringerOfDeath.State.ATTACK,
		BringerOfDeath.State.HURT, BringerOfDeath.State.IDLE, BringerOfDeath.State.DEAD) and passed
	print("Melee hit stun: %s" % ("passed" if passed else "failed"))
	quit(0 if passed else 1)


func _check_enemy(scene: PackedScene, attack: int, hurt: int, idle: int, dead: int) -> bool:
	var enemy = scene.instantiate()
	root.add_child(enemy)
	var sprite := enemy.get_node("AnimatedSprite2D") as AnimatedSprite2D
	var initial_health: int = enemy.health

	enemy.take_damage(1)
	if enemy.get("_state") != hurt or sprite.speed_scale != 1.0:
		push_error("%s did not play its first full hurt animation" % enemy.name)
		return false
	await sprite.animation_finished
	await process_frame
	if enemy.get("_state") != idle:
		push_error("%s did not recover from hurt" % enemy.name)
		return false

	enemy.call("_set_state", attack)
	for i in enemy.resisted_hits_after_hurt:
		enemy.take_damage(1)
		if enemy.get("_state") != attack or sprite.animation != &"attack":
			push_error("%s had its attack interrupted by a resisted hit" % enemy.name)
			return false

	enemy.take_damage(1)
	if enemy.get("_state") != hurt or sprite.speed_scale <= 1.0:
		push_error("%s did not play a shorter hurt animation after resistance" % enemy.name)
		return false
	if enemy.health != initial_health - enemy.resisted_hits_after_hurt - 2:
		push_error("%s did not take damage on every hit" % enemy.name)
		return false
	await sprite.animation_finished
	await process_frame

	enemy.take_damage(enemy.health)
	if enemy.get("_state") != dead:
		push_error("%s did not die immediately on a lethal hit" % enemy.name)
		return false
	enemy.queue_free()
	return true
