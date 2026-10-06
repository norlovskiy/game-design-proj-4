class_name FlyingDemon
extends Enemy

enum State { PATROL, POSITION, SHOOT, HURT, DEAD }

const PROJECTILE_SCENE: PackedScene = preload("res://scenes/flying_demon_projectile.tscn")
const SPRITE_PATH := "res://assets/flying-demon/Sprites/without_outline/"
const FRAME_SIZE := Vector2(79, 69)
const FIRE_FRAME := 5
const ANIMATIONS := {
	&"idle": ["IDLE.png", 4, 8.0, true],
	&"fly": ["FLYING.png", 4, 10.0, true],
	&"attack": ["ATTACK.png", 8, 12.0, false],
	&"hurt": ["HURT.png", 4, 12.0, false],
	&"death": ["DEATH.png", 7, 10.0, false],
}

@export_category("Patrol")
@export var patrol_radius := 90.0
@export var patrol_speed := 55.0
@export var patrol_bob_height := 12.0
@export var max_flight_height := 80.0

@export_category("Aggro")
@export var aggro_range := 340.0
@export var disengage_range := 440.0
@export var move_speed := 115.0
@export var acceleration := 450.0
@export var preferred_distance := 175.0
@export var preferred_height := 75.0
@export var position_tolerance := 22.0

@export_category("Attack")
@export var attack_cooldown := 1.6
@export var projectile_speed := 230.0

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D

var _state := State.PATROL
var _target: Node2D
var _origin := Vector2.ZERO
var _patrol_direction := 1.0
var _patrol_time := 0.0
var _facing := 1.0
var _cooldown_remaining := 0.0
var _has_fired := false
var _minimum_flight_y := -INF


func _ready() -> void:
	_origin = global_position
	_sprite.sprite_frames = _create_sprite_frames()
	_sprite.frame_changed.connect(_on_frame_changed)
	_sprite.animation_finished.connect(_on_animation_finished)
	_sprite.play(&"fly")


func _physics_process(delta: float) -> void:
	if _state == State.DEAD:
		return
	_cooldown_remaining = maxf(0.0, _cooldown_remaining - delta)

	# The attack and hit animations hold the demon in place for their full duration.
	if _state == State.SHOOT or _state == State.HURT:
		velocity = Vector2.ZERO
		if _state == State.SHOOT and is_instance_valid(_target):
			_face(_target.global_position.x - global_position.x)
		return

	_update_flight_ceiling()
	_update_target()
	if is_instance_valid(_target):
		_move_to_firing_position(delta)
	else:
		_patrol(delta)
	move_and_slide()
	if global_position.y < _minimum_flight_y:
		global_position.y = _minimum_flight_y
		velocity.y = maxf(velocity.y, 0.0)

	if is_on_wall() and _state == State.PATROL:
		_patrol_direction *= -1.0


func take_damage(amount: int) -> void:
	if _state == State.DEAD or amount <= 0:
		return
	super.take_damage(amount)
	if health == 0:
		_set_state(State.DEAD)
	else:
		_set_state(State.HURT)


func _update_target() -> void:
	if is_instance_valid(_target) and can_target(_target):
		if global_position.distance_to(_target.global_position) <= disengage_range:
			return
	_target = null
	var candidate := find_player()
	if is_instance_valid(candidate) and global_position.distance_to(candidate.global_position) <= aggro_range:
		_target = candidate


func _update_flight_ceiling() -> void:
	var query := PhysicsRayQueryParameters2D.create(
		global_position, global_position + Vector2.DOWN * 1000.0, 1
	)
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		var player := get_tree().get_first_node_in_group(&"player") as Node2D
		if is_instance_valid(player):
			query = PhysicsRayQueryParameters2D.create(
				player.global_position, player.global_position + Vector2.DOWN * 1000.0, 1
			)
			hit = get_world_2d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		_minimum_flight_y = (hit.position as Vector2).y - max_flight_height
	if global_position.y < _minimum_flight_y:
		global_position.y = _minimum_flight_y
		velocity.y = maxf(velocity.y, 0.0)


func _patrol(delta: float) -> void:
	_patrol_time += delta
	if global_position.x >= _origin.x + patrol_radius:
		_patrol_direction = -1.0
	elif global_position.x <= _origin.x - patrol_radius:
		_patrol_direction = 1.0
	_face(_patrol_direction)
	var patrol_center_y := maxf(_origin.y, _minimum_flight_y + patrol_bob_height)
	var desired_height := patrol_center_y + sin(_patrol_time * 2.0) * patrol_bob_height
	var desired_velocity := Vector2(_patrol_direction * patrol_speed,
		clampf((desired_height - global_position.y) * 3.0, -patrol_speed, patrol_speed))
	velocity = velocity.move_toward(desired_velocity, acceleration * delta)
	_set_state(State.PATROL)


func _move_to_firing_position(delta: float) -> void:
	var target_center := _target.global_position + Vector2(0.0, -18.0)
	var horizontal_offset := target_center.x - global_position.x
	if not is_zero_approx(horizontal_offset):
		_face(signf(horizontal_offset))

	var desired_position := target_center + Vector2(-_facing * preferred_distance, -preferred_height)
	desired_position.y = maxf(desired_position.y, _minimum_flight_y)
	var offset := desired_position - global_position
	if offset.length() <= position_tolerance and _cooldown_remaining <= 0.0:
		_set_state(State.SHOOT)
		velocity = Vector2.ZERO
		return

	# Reposition throughout the cooldown, including when the player moves.
	var desired_velocity := offset.limit_length(move_speed) * 3.0
	velocity = velocity.move_toward(desired_velocity.limit_length(move_speed), acceleration * delta)
	_set_state(State.POSITION)


func _face(direction: float) -> void:
	if is_zero_approx(direction):
		return
	_facing = signf(direction)
	# The source sprites face left.
	_sprite.flip_h = _facing > 0.0


func _set_state(next_state: State) -> void:
	if _state == next_state and _sprite.is_playing():
		return
	_state = next_state
	match _state:
		State.PATROL, State.POSITION:
			_sprite.play(&"fly")
		State.SHOOT:
			_has_fired = false
			_sprite.play(&"attack")
		State.HURT:
			_sprite.play(&"hurt")
		State.DEAD:
			velocity = Vector2.ZERO
			collision_layer = 0
			collision_mask = 0
			_sprite.play(&"death")


func _on_frame_changed() -> void:
	if _state == State.SHOOT and _sprite.frame == FIRE_FRAME and not _has_fired:
		_fire_projectile()


func _fire_projectile() -> void:
	_has_fired = true
	if not is_instance_valid(_target):
		return
	var projectile := PROJECTILE_SCENE.instantiate() as Area2D
	var parent := get_tree().current_scene
	if parent == null:
		parent = get_parent()
	parent.add_child(projectile)
	projectile.global_position = global_position + Vector2(_facing * 26.0, 2.0)
	var aim_position := _target.global_position + Vector2(0.0, -18.0)
	projectile.launch((aim_position - projectile.global_position).normalized(), projectile_speed)


func _on_animation_finished() -> void:
	match _state:
		State.SHOOT:
			_cooldown_remaining = attack_cooldown
			_set_state(State.POSITION)
		State.HURT:
			_set_state(State.PATROL)
		State.DEAD:
			queue_free()


func _create_sprite_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	for animation_name: StringName in ANIMATIONS:
		var data: Array = ANIMATIONS[animation_name]
		var texture := load(SPRITE_PATH + data[0]) as Texture2D
		frames.add_animation(animation_name)
		frames.set_animation_speed(animation_name, data[2])
		frames.set_animation_loop(animation_name, data[3])
		for index in data[1]:
			var frame := AtlasTexture.new()
			frame.atlas = texture
			frame.region = Rect2(Vector2(index * FRAME_SIZE.x, 0), FRAME_SIZE)
			frames.add_frame(animation_name, frame)
	return frames
