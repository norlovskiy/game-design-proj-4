extends SceneTree
## Run: godot --headless --path . -s tests/leaf_ranger_test.gd

const BOSS_SCENE: PackedScene = preload("res://scenes/leaf_ranger.tscn")
const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")
const EFFECT_SCENE: PackedScene = preload("res://scenes/leaf_ranger_effect.tscn")

var _passed := true
var _spawn_counts := {"LeafRangerArrow": 0, "LeafRangerEffect": 0, "LeafRangerBeam": 0}


func _initialize() -> void:
	node_added.connect(_on_node_added)
	call_deferred("_run")


func _on_node_added(node: Node) -> void:
	if _spawn_counts.has(node.name):
		_spawn_counts[node.name] += 1


func _run() -> void:
	var arena := Node2D.new()
	root.add_child(arena)
	var ground := StaticBody2D.new()
	ground.position = Vector2(300, 20)
	var ground_shape := CollisionShape2D.new()
	var ground_rect := RectangleShape2D.new()
	ground_rect.size = Vector2(1200, 40)
	ground_shape.shape = ground_rect
	ground.add_child(ground_shape)
	arena.add_child(ground)

	var player := PLAYER_SCENE.instantiate() as Node2D
	var body := player.get_node("CharacterBody2D") as CharacterBody2D
	body.set("max_hp", 100)
	arena.add_child(player)
	body.global_position = Vector2(100, 0)

	var boss := BOSS_SCENE.instantiate() as Enemy
	boss.set("attack_cooldown", 99.0)
	arena.add_child(boss)
	boss.global_position = Vector2(220, 0)
	boss.set("_cooldown", 99.0)
	await _wait_frames(4)
	_check(boss.is_on_floor(), "boss did not settle onto the arena floor")

	# Every set of five starts with a dodgeable move and contains each attack once.
	var last := -1
	for cycle in 50:
		var seen := {}
		for move in 5:
			var choice: int = boss.call("_draw_next_attack")
			if move == 0:
				_check(choice != LeafRanger.Attack.BEAM, "beam opened a five-attack set")
			_check(not seen.has(choice), "an attack repeated within a five-move cycle")
			if last >= 0:
				_check(choice != last, "the same attack repeated at a cycle boundary")
			seen[choice] = true
			last = choice
		_check(seen.size() == 5, "the cycle omitted an attack")
	boss.set("_attack_bag", [])

	var initial_health := boss.health
	boss.call("_start_evade", 1.0)
	boss.take_damage(1)
	_check(boss.health == initial_health, "roll or slide did not grant invincibility")
	boss.call("_end_evade")
	boss.take_damage(1)
	_check(boss.health == initial_health - 1, "boss stayed invincible after evading")
	boss.set("_cooldown", 99.0)
	await _wait_frames(2)

	boss.call("_spawn_rain")
	var rain := arena.get_node_or_null("LeafRangerEffect") as Node2D
	_check(rain != null, "rain warning did not spawn")
	if rain != null:
		_check(is_equal_approx(rain.global_position.x, 100.0), "rain did not capture player position")
	body.global_position.x = 300.0
	await _wait_frames(3)
	if is_instance_valid(rain):
		_check(is_equal_approx(rain.global_position.x, 100.0), "rain followed the player")
	for kind in [0, 1]:
		var burst_hp := int(body.get("hp"))
		var burst := EFFECT_SCENE.instantiate() as Node2D
		burst.call("configure", kind)
		arena.add_child(burst)
		burst.global_position = body.global_position
		await _wait_frames(25)
		_check(int(body.get("hp")) < burst_hp, "burst %d had no area damage (hp %d -> %d)" % [kind, burst_hp, int(body.get("hp"))])
		await _wait_frames(65)

	boss.call("_face", 1.0)
	var player_hp := int(body.get("hp"))
	boss.call("_spawn_beam")
	var beam := arena.get_node_or_null("LeafRangerBeam") as Area2D
	_check(beam != null, "beam did not spawn")
	if beam != null:
		var beam_shape := beam.get_children().back() as CollisionShape2D
		_check(beam_shape.shape.size.x >= 1200.0, "beam did not extend past the screen")
	await _wait_frames(5)
	_check(int(body.get("hp")) < player_hp, "beam did not harm a player standing in it")
	await _wait_frames(65)

	var melee_shape := boss.get_node("MeleeArea/CollisionShape2D") as CollisionShape2D
	var melee_sprite := boss.get_node("AnimatedSprite2D") as AnimatedSprite2D
	boss.call("_start_attack", LeafRanger.Attack.MELEE)
	melee_sprite.pause()
	for frame in [4, 5, 6, 7, 8, 9]:
		melee_sprite.frame = frame
		await _wait_frames(2)
		_check(melee_shape.disabled == (frame < 6),
			"melee hitbox timing was wrong at animation frame %d" % frame)
	boss.call("_finish_attack")
	body.global_position.x = 255.0
	var melee_hp := int(body.get("hp"))
	boss.call("_start_attack", 1)
	var melee_was_active := false
	for frame in 45:
		await physics_frame
		melee_was_active = melee_was_active or not melee_shape.disabled
	_check(melee_was_active, "melee thrust never enabled its hitbox")
	_check(int(body.get("hp")) < melee_hp, "melee thrust did not harm a nearby player")
	body.global_position.x = 300.0

	# A player who crosses behind the bow during windup must not pull the shot backward.
	for facing in [1.0, -1.0]:
		boss.call("_face", facing)
		body.global_position.x = boss.global_position.x - facing * 120.0
		boss.call("_start_attack", LeafRanger.Attack.POISON)
		melee_sprite.pause()
		melee_sprite.frame = 8
		var behind_shot := arena.get_node_or_null("LeafRangerArrow") as LeafRangerArrow
		_check(behind_shot != null, "ground shot did not spawn when player was behind")
		if behind_shot != null:
			_check(behind_shot.direction.is_equal_approx(Vector2(facing, 0.0)),
				"ground shot aimed backward instead of straight ahead")
			behind_shot.queue_free()
		boss.call("_finish_attack")
		await _wait_frames(1)
	boss.call("_face", 1.0)
	body.global_position.x = boss.global_position.x + 120.0
	boss.call("_start_attack", LeafRanger.Attack.POISON)
	melee_sprite.pause()
	melee_sprite.frame = 8
	var front_shot := arena.get_node_or_null("LeafRangerArrow") as LeafRangerArrow
	_check(front_shot != null, "ground shot did not spawn when player was ahead")
	if front_shot != null:
		_check(front_shot.direction.x > 0.0 and front_shot.direction.y > 0.0,
			"ground shot stopped aiming at a player ahead")
		front_shot.queue_free()
	boss.call("_finish_attack")
	await _wait_frames(1)
	body.global_position.x = 300.0

	var arrows_before: int = _spawn_counts.LeafRangerArrow
	boss.call("_start_attack", 2)
	await _wait_frames(55)
	_check(_spawn_counts.LeafRangerArrow > arrows_before, "ground shot fired no arrow")

	arrows_before = _spawn_counts.LeafRangerArrow
	boss.call("_start_attack", 0)
	var rose_into_air := false
	for frame in 65:
		await physics_frame
		rose_into_air = rose_into_air or boss.global_position.y < -25.0
	_check(rose_into_air, "air shot did not jump")
	_check(_spawn_counts.LeafRangerArrow > arrows_before, "air shot fired no arrow")

	var effects_before: int = _spawn_counts.LeafRangerEffect
	boss.call("_start_attack", 3)
	await _wait_frames(40)
	_check(_spawn_counts.LeafRangerEffect > effects_before, "upward shot created no rain")

	var beams_before: int = _spawn_counts.LeafRangerBeam
	boss.call("_start_attack", 4)
	await _wait_frames(45)
	_check(_spawn_counts.LeafRangerBeam > beams_before, "beam attack fired no beam")

	# Let the real decision loop choose a full cycle with a stationary player.
	boss.call("_finish_attack")
	boss.set("attack_cooldown", 0.15)
	boss.set("_cooldown", 0.0)
	boss.set("_reposition_time", 0.0)
	boss.set("_attack_bag", [])
	boss.set("_last_attack", -1)
	var chosen: Array[int] = []
	var record_attack := func(attack: int) -> void: chosen.append(attack)
	boss.connect("attack_started", record_attack)
	for frame in 950:
		await physics_frame
		if chosen.size() == 5:
			break
	boss.disconnect("attack_started", record_attack)
	_check(chosen.size() == 5, "boss AI did not use all five attacks")
	var unique := {}
	for choice in chosen:
		unique[choice] = true
	_check(unique.size() == 5, "boss AI repeated an attack before completing its cycle")

	# Close range should cause a retreat when floor remains, or an evade at an edge.
	boss.call("_finish_attack")
	boss.set("_cooldown", 99.0)
	boss.set("_evade_cooldown", 0.0)
	boss.global_position = Vector2(220, 0)
	body.global_position = Vector2(260, 0)
	await _wait_frames(3)
	_check(boss.velocity.x < 0.0, "boss did not run away when there was room")
	_check((boss.get_node("AnimatedSprite2D") as AnimatedSprite2D).flip_h,
		"boss faced the player while retreating left")
	boss.global_position = Vector2(220, 0)
	body.global_position = Vector2(180, 0)
	boss.velocity = Vector2.ZERO
	await _wait_frames(3)
	_check(boss.velocity.x > 0.0, "boss did not run away to the right")
	_check(not (boss.get_node("AnimatedSprite2D") as AnimatedSprite2D).flip_h,
		"boss faced the player while retreating right")
	boss.global_position = Vector2(-270, 0)
	body.global_position = Vector2(-235, 0)
	boss.velocity = Vector2.ZERO
	boss.set("_evade_cooldown", 0.0)
	await _wait_frames(3)
	_check(int(boss.get("_state")) == 2, "boss did not evade when retreat was blocked")

	print("Leaf Ranger: %s" % ("passed" if _passed else "failed"))
	quit(0 if _passed else 1)


func _wait_frames(count: int) -> void:
	for frame in count:
		await physics_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_passed = false
		push_error(message)
