class_name EyeballMonster
extends "res://scripts/melee_enemy.gd"

enum State { PATROL, CHASE, WINDUP, ROLL, ATTACK, STAGGER, RECOVER, DEAD }

const SPRITE_SHEET: Texture2D = preload("res://assets/eyeball-monster/EyeBall Monster-Sheet.png")
const FRAME_SIZE := Vector2(128, 48)
const ATTACK_ACTIVE_FRAMES := [1, 2, 3, 4, 5, 6, 7, 8]
const ANIMATIONS := {
	&"idle": [0, 9, 10.0, true],
	&"walk": [9, 8, 12.0, true],
	&"attack": [17, 9, 12.0, false],
	&"roll": [35, 11, 16.0, true],
	&"death": [46, 4, 12.0, false],
}
const FRAME_CENTER_X := {
	&"idle": [32.0, 32.5, 31.0, 29.0, 28.0, 27.5, 27.5, 32.0, 32.0],
	&"walk": [32.5, 32.0, 32.0, 32.5, 32.0, 27.5, 28.5, 28.5],
	&"attack": [32.0, 26.0, 19.0, 18.0, 17.0, 17.0, 22.0, 22.0, 22.0],
	&"roll": [32.0, 30.5, 30.0, 32.0, 32.0, 24.0, 18.0, 17.0, 16.0, 15.0, 15.0],
	&"death": [16.5, 16.0, 15.5, 15.5],
}

@export_category("Movement")
@export var patrol_radius := 90.0
@export var patrol_speed := 90.0
@export var chase_speed := 150.0
@export var acceleration := 650.0
@export var detection_range := 280.0
@export var vertical_detection_range := 65.0

@export_category("Attack")
@export var charge_range := 190.0
@export var windup_duration := 0.4
@export var roll_speed := 340.0
@export var roll_duration := 0.6
@export var roll_pass_grace := 0.05
@export var missed_stagger_duration := 0.75
@export var attack_cooldown := 0.9

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _attack_area: Area2D = $AttackArea
@onready var _attack_shape: CollisionShape2D = $AttackArea/CollisionShape2D

var _state := State.PATROL
var _target: Node2D
var _origin_x := 0.0
var _facing := 1.0
var _patrol_direction := 1.0
var _state_time := 0.0
var _time_past_player := 0.0
var _cooldown_remaining := 0.0
var _landed_hit := false
var _gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity", 980.0)


func _ready() -> void:
	_origin_x = global_position.x
	_sprite.sprite_frames = _create_sprite_frames()
	_sprite.frame_changed.connect(_on_frame_changed)
	_sprite.animation_finished.connect(_on_animation_finished)
	_attack_area.body_entered.connect(_on_attack_body_entered)
	_set_attack_active(false)
	_set_state(State.PATROL)


func _physics_process(delta: float) -> void:
	if _state == State.DEAD:
		return

	_cooldown_remaining = maxf(_cooldown_remaining - delta, 0.0)
	if not is_on_floor():
		velocity.y += _gravity * delta

	match _state:
		State.PATROL, State.CHASE:
			_update_target()
			if is_instance_valid(_target):
				_chase(delta)
			else:
				_patrol(delta)
		State.WINDUP:
			velocity.x = 0.0
			_state_time -= delta
			if _state_time <= 0.0:
				_set_state(State.ROLL)
		State.ROLL:
			velocity.x = _facing * roll_speed
			_state_time -= delta
		State.ATTACK:
			velocity.x = 0.0
		State.STAGGER, State.RECOVER:
			velocity.x = 0.0
			_state_time -= delta
			if _state_time <= 0.0:
				_set_state(State.PATROL)

	if _state == State.ROLL and not _has_ground_ahead(_facing, 18.0):
		_begin_attack()
	move_and_slide()
	if _state == State.ROLL and _should_end_roll(delta):
		_begin_attack()
	elif _state == State.PATROL and is_on_wall():
		_patrol_direction *= -1.0


func take_damage(amount: int) -> void:
	if _state == State.ROLL or _state == State.DEAD or amount <= 0:
		return
	super.take_damage(amount)
	if health == 0:
		_set_state(State.DEAD)


func _update_target() -> void:
	if is_instance_valid(_target) and can_target(_target):
		var offset := _target.global_position - global_position
		if absf(offset.x) <= detection_range and absf(offset.y) <= vertical_detection_range:
			return
	_target = null
	var candidate := find_player()
	if is_instance_valid(candidate):
		var offset := candidate.global_position - global_position
		if absf(offset.x) <= detection_range and absf(offset.y) <= vertical_detection_range:
			_target = candidate


func _patrol(delta: float) -> void:
	if global_position.x >= _origin_x + patrol_radius:
		_patrol_direction = -1.0
	elif global_position.x <= _origin_x - patrol_radius:
		_patrol_direction = 1.0
	if not _has_ground_ahead(_patrol_direction, 16.0):
		_patrol_direction *= -1.0
	_face(_patrol_direction)
	velocity.x = move_toward(velocity.x, _patrol_direction * patrol_speed, acceleration * delta)
	_set_state(State.PATROL)


func _chase(delta: float) -> void:
	var offset := _target.global_position - global_position
	if not is_zero_approx(offset.x):
		_face(signf(offset.x))
	if not _has_ground_ahead(_facing, 18.0):
		velocity.x = 0.0
		_set_state(State.CHASE)
		return
	if absf(offset.x) <= charge_range and _cooldown_remaining <= 0.0:
		_set_state(State.WINDUP)
		velocity.x = 0.0
		return
	velocity.x = move_toward(velocity.x, _facing * chase_speed, acceleration * delta)
	_set_state(State.CHASE)


func _face(direction: float) -> void:
	if is_zero_approx(direction):
		return
	_facing = signf(direction)
	_sprite.flip_h = _facing < 0.0
	_attack_area.position.x = absf(_attack_area.position.x) * _facing
	_update_sprite_offset()


func _begin_attack() -> void:
	if is_instance_valid(_target) and can_target(_target):
		_face(_target.global_position.x - global_position.x)
	_set_state(State.ATTACK)


func _should_end_roll(delta: float) -> bool:
	if _state_time <= 0.0 or is_on_wall():
		return true
	if not is_instance_valid(_target) or not can_target(_target):
		return false
	var distance_ahead := (_target.global_position.x - global_position.x) * _facing
	if distance_ahead >= 0.0:
		_time_past_player = 0.0
		return false
	_time_past_player += delta
	return _time_past_player >= roll_pass_grace


func _has_ground_ahead(direction: float, distance: float) -> bool:
	var start := global_position + Vector2(direction * distance, -20.0)
	var query := PhysicsRayQueryParameters2D.create(start, start + Vector2.DOWN * 48.0, 1)
	return not get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func _update_sprite_offset() -> void:
	var centers: Array = FRAME_CENTER_X.get(_sprite.animation, [])
	if _sprite.frame >= centers.size():
		return
	var center_x := float(centers[_sprite.frame])
	var center_y := 24.0
	if _sprite.animation == &"death":
		center_y = 21.0
	elif _sprite.animation == &"roll" and _sprite.frame >= 5:
		center_y = 21.0
	var horizontal_offset := FRAME_SIZE.x * 0.5 - center_x
	_sprite.offset = Vector2(-horizontal_offset if _sprite.flip_h else horizontal_offset,
		FRAME_SIZE.y * 0.5 - center_y)


func _set_state(next_state: State) -> void:
	if _state == next_state and _sprite.is_playing():
		return
	_state = next_state
	_set_attack_active(false)
	_sprite.modulate = Color.WHITE
	match _state:
		State.PATROL, State.CHASE:
			_sprite.play(&"walk")
		State.WINDUP:
			_state_time = windup_duration
			_sprite.modulate = Color(1.0, 0.45, 0.45)
			_sprite.play(&"idle")
		State.ROLL:
			_state_time = roll_duration
			_time_past_player = 0.0
			_sprite.play(&"roll")
		State.ATTACK:
			velocity.x = 0.0
			_landed_hit = false
			_sprite.play(&"attack")
		State.STAGGER:
			_state_time = missed_stagger_duration
			_cooldown_remaining = attack_cooldown
			velocity.x = 0.0
			_sprite.modulate = Color(1.0, 0.65, 0.65)
			_sprite.play(&"idle")
		State.RECOVER:
			_state_time = attack_cooldown
			_cooldown_remaining = attack_cooldown
			velocity.x = 0.0
			_sprite.play(&"idle")
		State.DEAD:
			velocity = Vector2.ZERO
			collision_layer = 0
			collision_mask = 0
			_sprite.play(&"death")
	_update_sprite_offset()


func _on_frame_changed() -> void:
	_update_sprite_offset()
	_set_attack_active(_state == State.ATTACK and _sprite.frame in ATTACK_ACTIVE_FRAMES
		and not _landed_hit)


func _set_attack_active(active: bool) -> void:
	_attack_shape.set_deferred("disabled", not active)


func _on_attack_body_entered(body: Node2D) -> void:
	if _state != State.ATTACK or _landed_hit or not body.is_in_group(&"player"):
		return
	if body.take_hit():
		_landed_hit = true
		_set_attack_active(false)


func _on_animation_finished() -> void:
	match _state:
		State.ATTACK:
			_set_state(State.RECOVER if _landed_hit else State.STAGGER)
		State.DEAD:
			queue_free()


func _create_sprite_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	for animation_name: StringName in ANIMATIONS:
		var data: Array = ANIMATIONS[animation_name]
		frames.add_animation(animation_name)
		frames.set_animation_speed(animation_name, data[2])
		frames.set_animation_loop(animation_name, data[3])
		for frame_index in data[1]:
			var texture := AtlasTexture.new()
			texture.atlas = SPRITE_SHEET
			texture.region = Rect2(Vector2(0, (data[0] + frame_index) * FRAME_SIZE.y), FRAME_SIZE)
			frames.add_frame(animation_name, texture)
	return frames
