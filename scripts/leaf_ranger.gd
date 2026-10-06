class_name LeafRanger
extends "res://scripts/melee_enemy.gd"

signal attack_started(attack: int)

enum State { SEEK, ATTACK, EVADE, HURT, DEAD }
enum Attack { AIR, MELEE, POISON, RAIN, BEAM }

const Sprites = preload("res://scripts/leaf_ranger_sprites.gd")
const ARROW_SCENE: PackedScene = preload("res://scenes/leaf_ranger_arrow.tscn")
const EFFECT_SCENE: PackedScene = preload("res://scenes/leaf_ranger_effect.tscn")
const BEAM_SCENE: PackedScene = preload("res://scenes/leaf_ranger_beam.tscn")
const POISON_EFFECT := 0
const THORNS_EFFECT := 1
const RAIN_EFFECT := 2
const ANIMATIONS := {
	&"idle": [0, 12, 8.0, true],
	&"run": [1, 10, 12.0, true],
	&"jump_start": [3, 3, 12.0, false],
	&"fall": [5, 3, 9.0, true],
	&"air_attack": [7, 10, 12.0, false],
	&"roll": [8, 8, 16.0, true],
	&"slide": [9, 13, 18.0, true],
	&"melee": [10, 10, 12.0, false],
	&"poison_shot": [11, 15, 12.0, false],
	&"arrow_rain": [12, 12, 12.0, false],
	&"beam": [13, 17, 15.0, false],
	&"hurt": [15, 6, 12.0, false],
	&"death": [16, 19, 12.0, false],
}

@export_category("Movement")
@export var detection_range := 410.0
@export var vertical_detection_range := 120.0
@export var run_speed := 105.0
@export var retreat_speed := 135.0
@export var evade_speed := 280.0
@export var acceleration := 650.0
@export var preferred_distance := 110.0
@export var retreat_distance := 85.0
@export var melee_range := 55.0
@export var jump_velocity := -410.0

@export_category("Attacks")
@export var arrow_speed := 390.0
@export var rain_warning_duration := 0.7
@export var beam_length := 1792.0
@export var attack_cooldown := 0.55

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _melee_area: Area2D = $MeleeArea
@onready var _melee_shape: CollisionShape2D = $MeleeArea/CollisionShape2D

var _state: State = State.SEEK
var _target: Node2D
var _facing := 1.0
var _current_attack := -1
var _attack_bag: Array[int] = []
var _last_attack := -1
var _attack_event_fired := false
var _air_animation_done := false
var _attack_interrupted := false
var _interrupt_cooldown_remaining := 0.0
var _cooldown := 0.0
var _reposition_time := 0.0
var _evade_time := 0.0
var _evade_direction := 1.0
var _evade_cooldown := 0.0
var _gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity", 980.0)


func _ready() -> void:
	_sprite.sprite_frames = Sprites.make_frames(Sprites.RANGER, Vector2i(288, 128), ANIMATIONS)
	_sprite.animation_finished.connect(_on_animation_finished)
	_sprite.frame_changed.connect(_on_frame_changed)
	_set_melee_active(false)
	_find_target()
	_play(&"idle")


func _draw() -> void:
	if health <= 0:
		return
	draw_rect(Rect2(-31, -79, 62, 7), Color(0.08, 0.16, 0.13))
	draw_rect(Rect2(-30, -78, 60.0 * float(health) / float(max_health), 5),
		Color(0.47, 0.85, 0.36))


func _physics_process(delta: float) -> void:
	if _state == State.DEAD:
		return
	_cooldown = maxf(_cooldown - delta, 0.0)
	_interrupt_cooldown_remaining = maxf(_interrupt_cooldown_remaining - delta, 0.0)
	_reposition_time = maxf(_reposition_time - delta, 0.0)
	_evade_cooldown = maxf(_evade_cooldown - delta, 0.0)
	if not is_on_floor():
		velocity.y += _gravity * delta
	elif velocity.y >= 0.0:
		velocity.y = 0.0

	match _state:
		State.SEEK:
			_update_seek(delta)
		State.ATTACK, State.HURT:
			velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
		State.EVADE:
			_evade_time -= delta
			velocity.x = _evade_direction * evade_speed
			if not _can_run(_evade_direction, 20.0):
				_end_evade()

	move_and_slide()
	if _state == State.EVADE and (_evade_time <= 0.0 or is_on_wall()):
		_end_evade()
	elif _state == State.ATTACK and _current_attack == Attack.AIR \
			and _air_animation_done and is_on_floor():
		_finish_attack()


func take_damage(amount: int) -> void:
	if amount <= 0 or _state == State.DEAD or _state == State.EVADE:
		return
	super.take_damage(amount)
	queue_redraw()
	if health == 0:
		_die()
	elif _state != State.HURT and _should_play_hurt():
		_attack_interrupted = _state == State.ATTACK
		_state = State.HURT
		_current_attack = -1
		velocity.x = 0.0
		_set_melee_active(false)
		_sprite.speed_scale = _hurt_animation_speed()
		_sprite.play(&"hurt")


func _update_seek(delta: float) -> void:
	if not is_instance_valid(_target) or not can_target(_target):
		_find_target()
	if not is_instance_valid(_target):
		_stop(delta)
		return
	var offset := _target.global_position - global_position
	if absf(offset.x) > detection_range or absf(offset.y) > vertical_detection_range:
		_stop(delta)
		return
	if not _has_line_of_sight():
		_stop(delta)
		return
	var toward := signf(offset.x) if not is_zero_approx(offset.x) else _facing
	_face(toward)
	var distance := absf(offset.x)

	# Between attacks, make space when possible. A corner forces an invincible pass.
	if distance < retreat_distance and (_cooldown > 0.0 or _interrupt_cooldown_remaining > 0.0
			or _reposition_time > 0.0):
		if _can_run(-toward, 56.0):
			_run(-toward, retreat_speed, delta)
		elif _evade_cooldown <= 0.0:
			_start_evade(toward)
		else:
			_stop(delta)
		return

	if _cooldown <= 0.0 and _interrupt_cooldown_remaining <= 0.0 \
			and _reposition_time <= 0.0:
		_refill_bag()
		if _attack_bag[0] == Attack.MELEE and (distance > melee_range or absf(offset.y) > 54.0):
			if _can_run(toward, 30.0):
				_run(toward, run_speed, delta)
			else:
				_stop(delta)
			return
		if _attack_bag[0] == Attack.AIR and not is_on_floor():
			_stop(delta)
			return
		_start_attack(_draw_next_attack())
		return

	if distance > preferred_distance + 30.0 and _can_run(toward, 30.0):
		_run(toward, run_speed, delta)
	else:
		_stop(delta)


func _find_target() -> void:
	_target = find_player()


func _has_line_of_sight() -> bool:
	var from := global_position + Vector2(0, -28)
	var to := _target.global_position + Vector2(0, -12)
	var query := PhysicsRayQueryParameters2D.create(from, to, 1)
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func _can_run(direction: float, distance: float) -> bool:
	if is_zero_approx(direction) or not is_on_floor():
		return false
	var space := get_world_2d().direct_space_state
	var wall_from := global_position + Vector2(0, -25)
	var wall_to := wall_from + Vector2(direction * distance, 0)
	if not space.intersect_ray(PhysicsRayQueryParameters2D.create(wall_from, wall_to, 1)).is_empty():
		return false
	var floor_from := global_position + Vector2(direction * distance, -12)
	var floor_to := floor_from + Vector2(0, 44)
	return not space.intersect_ray(PhysicsRayQueryParameters2D.create(floor_from, floor_to, 1)).is_empty()


func _run(direction: float, speed: float, delta: float) -> void:
	velocity.x = move_toward(velocity.x, direction * speed, acceleration * delta)
	_play(&"run")


func _stop(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
	_play(&"idle")


func _face(direction: float) -> void:
	if is_zero_approx(direction):
		return
	_facing = signf(direction)
	_sprite.flip_h = _facing < 0.0
	_melee_area.position.x = 32.0 * _facing


func _refill_bag() -> void:
	if not _attack_bag.is_empty():
		return
	_attack_bag = [Attack.AIR, Attack.MELEE, Attack.POISON, Attack.RAIN, Attack.BEAM]
	_attack_bag.shuffle()
	if _attack_bag[0] == _last_attack:
		var first := _attack_bag[0]
		_attack_bag[0] = _attack_bag[1]
		_attack_bag[1] = first


func _draw_next_attack() -> int:
	_refill_bag()
	_last_attack = _attack_bag.pop_front()
	return _last_attack


func _start_attack(attack: int) -> void:
	_state = State.ATTACK
	_current_attack = attack
	attack_started.emit(attack)
	_attack_event_fired = false
	_air_animation_done = false
	velocity.x = 0.0
	_set_melee_active(false)
	_sprite.speed_scale = 1.0
	match attack:
		Attack.AIR:
			velocity.y = jump_velocity
			_play(&"jump_start")
		Attack.MELEE:
			_play(&"melee")
		Attack.POISON:
			_play(&"poison_shot")
		Attack.RAIN:
			_play(&"arrow_rain")
		Attack.BEAM:
			_play(&"beam")


func _finish_attack() -> void:
	_state = State.SEEK
	_current_attack = -1
	_set_melee_active(false)
	_cooldown = attack_cooldown
	_reposition_time = 0.3
	_play(&"idle")


func _start_evade(toward: float) -> void:
	_state = State.EVADE
	_evade_direction = toward
	_evade_cooldown = 1.7
	_evade_time = 0.53 if randi_range(0, 1) == 0 else 0.46
	_set_melee_active(false)
	_play(&"roll" if _evade_time > 0.5 else &"slide")
	velocity.x = _evade_direction * evade_speed


func _end_evade() -> void:
	_state = State.SEEK
	velocity.x = 0.0
	_reposition_time = 0.0
	_cooldown = minf(_cooldown, 0.2)
	_play(&"idle")


func _die() -> void:
	_state = State.DEAD
	_current_attack = -1
	velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0
	_set_melee_active(false)
	_sprite.speed_scale = 1.0
	_sprite.play(&"death")


func _play(animation_name: StringName) -> void:
	if _sprite.animation != animation_name or not _sprite.is_playing():
		_sprite.play(animation_name)


func _set_melee_active(active: bool) -> void:
	_melee_shape.set_deferred("disabled", not active)


func _on_frame_changed() -> void:
	_set_melee_active(_state == State.ATTACK and _current_attack == Attack.MELEE
		and _sprite.frame >= 4 and _sprite.frame <= 7)
	if _state != State.ATTACK or _attack_event_fired:
		return
	match _current_attack:
		Attack.AIR:
			if _sprite.animation == &"air_attack" and _sprite.frame == 7:
				_spawn_arrow(THORNS_EFFECT)
				_attack_event_fired = true
		Attack.POISON:
			if _sprite.frame == 8:
				_spawn_arrow(POISON_EFFECT)
				_attack_event_fired = true
		Attack.RAIN:
			if _sprite.frame == 6:
				_spawn_rain()
				_attack_event_fired = true
		Attack.BEAM:
			if _sprite.frame == 9:
				_spawn_beam()
				_attack_event_fired = true


func _on_animation_finished() -> void:
	match _state:
		State.ATTACK:
			if _current_attack == Attack.AIR:
				if _sprite.animation == &"jump_start":
					_sprite.play(&"air_attack")
				elif _sprite.animation == &"air_attack":
					_air_animation_done = true
					if is_on_floor():
						_finish_attack()
					else:
						_sprite.play(&"fall")
			else:
				_finish_attack()
		State.HURT:
			_on_hurt_finished()
			_state = State.SEEK
			_sprite.speed_scale = 1.0
			_cooldown = maxf(_cooldown, 0.3)
			if _attack_interrupted:
				_interrupt_cooldown_remaining = Enemy.INTERRUPTED_ATTACK_COOLDOWN
				_attack_interrupted = false
			_play(&"idle")
		State.DEAD:
			queue_free()


func _spawn_arrow(kind: int) -> void:
	var origin := global_position + Vector2(_facing * 30.0, -32.0)
	var aim := Vector2(_facing, 0.0)
	if is_instance_valid(_target):
		aim = (_target.global_position + Vector2(0, -13) - origin).normalized()
	var arrow := ARROW_SCENE.instantiate() as Node2D
	arrow.call("configure", kind, aim, arrow_speed)
	_spawn_in_world(arrow, origin)


func _spawn_rain() -> void:
	if not is_instance_valid(_target):
		return
	# Capture the position now; the warning and rain never follow the player.
	var captured := _target.global_position
	var query := PhysicsRayQueryParameters2D.create(
		captured + Vector2(0, -20), captured + Vector2(0, 240), 1
	)
	var floor_hit := get_world_2d().direct_space_state.intersect_ray(query)
	if not floor_hit.is_empty():
		captured.y = floor_hit.position.y
	var rain := EFFECT_SCENE.instantiate() as Node2D
	rain.call("configure", RAIN_EFFECT, rain_warning_duration)
	_spawn_in_world(rain, captured)


func _spawn_beam() -> void:
	var beam := BEAM_SCENE.instantiate() as Node2D
	beam.set("facing", _facing)
	beam.set("beam_length", beam_length)
	_spawn_in_world(beam, global_position + Vector2(_facing * 31.0, -28.0))


func _spawn_in_world(node: Node2D, position: Vector2) -> void:
	var parent := get_tree().current_scene
	if parent == null:
		parent = get_parent()
	parent.add_child(node)
	node.global_position = position
