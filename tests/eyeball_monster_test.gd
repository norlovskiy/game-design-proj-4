extends SceneTree
## Run: godot --headless --path . -s tests/eyeball_monster_test.gd

const EYEBALL_SCENE: PackedScene = preload("res://scenes/eyeball_monster.tscn")
const EYEBALL_SCRIPT = preload("res://scripts/eyeball_monster.gd")


class TestPlayer extends CharacterBody2D:
	var hits := 0

	func take_hit() -> bool:
		hits += 1
		return true


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := Node2D.new()
	root.add_child(world)
	var ground := StaticBody2D.new()
	ground.position.y = 220.0
	var ground_shape := CollisionShape2D.new()
	var ground_rect := RectangleShape2D.new()
	ground_rect.size = Vector2(1200, 40)
	ground_shape.shape = ground_rect
	ground.add_child(ground_shape)
	world.add_child(ground)
	var player := TestPlayer.new()
	player.add_to_group(&"player")
	player.collision_layer = 8
	player.position = Vector2(230, 190)
	var player_shape := CollisionShape2D.new()
	var player_rect := RectangleShape2D.new()
	player_rect.size = Vector2(16, 38)
	player_shape.position.y = -9.0
	player_shape.shape = player_rect
	player.add_child(player_shape)
	world.add_child(player)

	var eyeball = EYEBALL_SCENE.instantiate()
	eyeball.position = Vector2(0, 190)
	world.add_child(eyeball)
	var rolled := false
	var stayed_rolling_ahead := false
	var attacked := false
	var missed := false
	var frames_after_cross := 0
	for i in 240:
		await physics_frame
		if eyeball.get("_state") == EYEBALL_SCRIPT.State.ROLL and not rolled:
			rolled = true
			eyeball.take_damage(1)
			if eyeball.health != 1:
				push_error("Eyeball took damage while rolling")
				quit(1)
				return
		if rolled and not stayed_rolling_ahead and eyeball.get("_state") == EYEBALL_SCRIPT.State.ROLL:
			var distance_ahead: float = (player.global_position.x - eyeball.global_position.x) * eyeball.get("_facing")
			if distance_ahead > 0.0 and distance_ahead <= 75.0:
				stayed_rolling_ahead = true
				player.position = Vector2(-130.0, 190.0)
		if stayed_rolling_ahead and not attacked:
			frames_after_cross += 1
		if eyeball.get("_state") == EYEBALL_SCRIPT.State.ATTACK and not attacked:
			attacked = true
			if frames_after_cross > 6:
				push_error("Eyeball kept rolling after the player passed behind it")
				quit(1)
				return
			if eyeball.get_node("AnimatedSprite2D").animation != &"attack" or not eyeball.get_node("AnimatedSprite2D").flip_h or eyeball.get_node("AttackArea").position.x >= 0.0:
				push_error("Eyeball did not turn toward the player after rolling")
				quit(1)
				return
		if eyeball.get("_state") == EYEBALL_SCRIPT.State.STAGGER:
			missed = true
			if eyeball.get_node("AnimatedSprite2D").animation != &"idle":
				push_error("Eyeball played the fade animation while alive")
				quit(1)
				return
			break
	if not rolled or not stayed_rolling_ahead or not attacked or not missed or player.hits != 0:
		push_error("Eyeball roll/pass behavior failed: rolled=%s ahead=%s attacked=%s missed=%s hits=%d state=%s pos=%s" % [rolled, stayed_rolling_ahead, attacked, missed, player.hits, eyeball.get("_state"), eyeball.global_position])
		quit(1)
		return
	eyeball.take_damage(1)
	if eyeball.get("_state") != EYEBALL_SCRIPT.State.DEAD:
		push_error("Eyeball did not die in one hit during its opening")
		quit(1)
		return
	if eyeball.get_node("AnimatedSprite2D").animation != &"death":
		push_error("Eyeball did not reserve the fade animation for death")
		quit(1)
		return
	eyeball.queue_free()
	await process_frame

	player.position = Vector2(230.0, 190.0)
	var second = EYEBALL_SCENE.instantiate()
	second.position = Vector2(0, 190)
	world.add_child(second)
	var recovered_after_hit := false
	var attack_started_in_reach := false
	for i in 240:
		await physics_frame
		if second.get("_state") == EYEBALL_SCRIPT.State.ATTACK and not attack_started_in_reach:
			attack_started_in_reach = absf(player.global_position.x - second.global_position.x) <= 106.0 and second.get("_facing") < 0.0
		if player.hits > 0 and second.get("_state") == EYEBALL_SCRIPT.State.RECOVER:
			recovered_after_hit = true
			break
	if not recovered_after_hit or not attack_started_in_reach:
		push_error("Eyeball did not finish the roll in melee range and hit")
		quit(1)
		return
	if not _check_sprite_alignment(second):
		quit(1)
		return
	second.queue_free()
	player.position.x = 230.0
	var edge_eyeball = EYEBALL_SCENE.instantiate()
	edge_eyeball.position = Vector2(580, 190)
	world.add_child(edge_eyeball)
	for i in 100:
		await physics_frame
		if edge_eyeball.global_position.x > 600.0 or edge_eyeball.global_position.y > 240.0:
			push_error("Eyeball walked off the platform without taking damage")
			quit(1)
			return
	print("Eyeball melee attack, post-roll facing, miss opening, and ledge behavior passed")
	quit()


func _check_sprite_alignment(eyeball: Node) -> bool:
	var sprite := eyeball.get_node("AnimatedSprite2D") as AnimatedSprite2D
	var image: Image = (load("res://assets/eyeball-monster/EyeBall Monster-Sheet.png") as Texture2D).get_image()
	for facing_left in [false, true]:
		eyeball._face(-1.0 if facing_left else 1.0)
		for animation_name in [&"idle", &"walk", &"roll"]:
			sprite.animation = animation_name
			for frame in sprite.sprite_frames.get_frame_count(animation_name):
				sprite.frame = frame
				var atlas := sprite.sprite_frames.get_frame_texture(animation_name, frame) as AtlasTexture
				var row := int(atlas.region.position.y)
				var min_x := 128
				var max_x := -1
				for y in 48:
					for x in 128:
						if image.get_pixel(x, row + y).a > 0.0:
							min_x = mini(min_x, x)
							max_x = maxi(max_x, x)
				if max_x < 0:
					push_error("Eyeball has a blank %s frame %d" % [animation_name, frame])
					return false
				var center_x := (min_x + max_x + 1) * 0.5
				var visible_x := (64.0 - center_x if facing_left else center_x - 64.0) + sprite.offset.x
				if absf(visible_x) > 2.0:
					push_error("Eyeball %s frame %d shifts %.1f pixels" % [animation_name, frame, visible_x])
					return false
	return true
