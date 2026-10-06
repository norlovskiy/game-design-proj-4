class_name NightBorne
extends "res://scripts/melee_enemy.gd"

enum State {
	IDLE,
	RUN,
	ATTACK,
	HURT,
	DEAD,
}

const SPRITE_SHEET: Texture2D = preload("res://assets/nightborne/NightBorne.png")
const FRAME_SIZE := Vector2(80.0, 80.0)
const ANIMATION_DATA := {
	&"idle": [0, 9, 100.0 / 9.0, true],
	&"run": [1, 6, 12.5, true],
	&"attack": [2, 12, 100.0 / 7.0, false],
	&"hurt": [3, 5, 100.0 / 7.0, false],
	&"death": [4, 23, 100.0 / 7.0, false],
}
const ATTACK_ACTIVE_FRAMES := [9, 10]

@export_category("Movement")
@export var run_speed: float = 85.0
@export var acceleration: float = 600.0
@export var deceleration: float = 900.0
@export var detection_range: float = 240.0
@export var vertical_detection_range: float = 80.0

@export_category("Attack")
@export var attack_range: float = 46.0
@export var attack_cooldown: float = 0.65

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _attack_hitbox: Area2D = $AttackHitbox
@onready var _attack_shape: CollisionShape2D = $AttackHitbox/CollisionShape2D

var _state: State = State.IDLE
var _target: Node2D
var _facing: float = 1.0
var _cooldown_remaining: float = 0.0
var _gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity", 980.0)


func _ready() -> void:
	_sprite.sprite_frames = _create_sprite_frames()
	_sprite.animation_finished.connect(_on_animation_finished)
	_sprite.frame_changed.connect(_on_frame_changed)
	_set_attack_active(false)
	_find_target()
	_set_state(State.IDLE)


func _physics_process(delta: float) -> void:
	advance_status(delta)
	_cooldown_remaining = maxf(_cooldown_remaining - delta, 0.0)

	if not is_on_floor():
		velocity.y += _gravity * delta

	match _state:
		State.IDLE, State.RUN:
			_update_movement(delta)
		State.ATTACK, State.HURT, State.DEAD:
			velocity.x = move_toward(velocity.x, 0.0, deceleration * delta)

	move_and_slide()


func take_damage(amount: int) -> void:
	if _state == State.DEAD or amount <= 0:
		return

	super.take_damage(amount)
	if health == 0:
		_set_state(State.DEAD)
	elif _state != State.HURT and _should_play_hurt():
		_set_state(State.HURT)


func _update_movement(delta: float) -> void:
	if not is_instance_valid(_target) or not can_target(_target):
		_find_target()

	if not is_instance_valid(_target):
		velocity.x = move_toward(velocity.x, 0.0, deceleration * delta)
		_set_state(State.IDLE)
		return

	var offset := _target.global_position - global_position
	var target_is_visible := (
		absf(offset.x) <= detection_range
		and absf(offset.y) <= vertical_detection_range
	)

	if not target_is_visible:
		velocity.x = move_toward(velocity.x, 0.0, deceleration * delta)
		_set_state(State.IDLE)
		return

	if not is_zero_approx(offset.x):
		_face(signf(offset.x))

	if absf(offset.x) <= attack_range:
		velocity.x = move_toward(velocity.x, 0.0, deceleration * delta)
		if _cooldown_remaining <= 0.0:
			_set_state(State.ATTACK)
		else:
			_set_state(State.IDLE)
		return

	velocity.x = move_toward(velocity.x, _facing * run_speed * movement_multiplier, acceleration * delta)
	_set_state(State.RUN)


func _find_target() -> void:
	_target = find_player()


func _face(direction: float) -> void:
	if is_zero_approx(direction):
		return
	_facing = signf(direction)
	_sprite.flip_h = _facing < 0.0
	_attack_hitbox.position.x = absf(_attack_hitbox.position.x) * _facing


func _set_state(next_state: State) -> void:
	if _state == next_state and _sprite.is_playing():
		return

	_state = next_state
	_sprite.speed_scale = 1.0
	_set_attack_active(false)

	match _state:
		State.IDLE:
			_sprite.play(&"idle")
		State.RUN:
			_sprite.play(&"run")
		State.ATTACK:
			_sprite.play(&"attack")
		State.HURT:
			_sprite.speed_scale = _hurt_animation_speed()
			_sprite.play(&"hurt")
		State.DEAD:
			collision_layer = 0
			_sprite.play(&"death")


func _on_frame_changed() -> void:
	var attack_frame := _state == State.ATTACK and _sprite.frame in ATTACK_ACTIVE_FRAMES
	_set_attack_active(attack_frame)


func _set_attack_active(active: bool) -> void:
	_attack_shape.set_deferred("disabled", not active)


func _on_animation_finished() -> void:
	match _state:
		State.ATTACK:
			_cooldown_remaining = attack_cooldown
			_set_state(State.IDLE)
		State.HURT:
			_on_hurt_finished()
			_set_state(State.IDLE)
		State.DEAD:
			queue_free()


func _create_sprite_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")

	for animation_name: StringName in ANIMATION_DATA:
		var data: Array = ANIMATION_DATA[animation_name]
		var row := int(data[0])
		var frame_count := int(data[1])
		frames.add_animation(animation_name)
		frames.set_animation_speed(animation_name, float(data[2]))
		frames.set_animation_loop(animation_name, bool(data[3]))

		for frame_index in frame_count:
			var frame_texture := AtlasTexture.new()
			frame_texture.atlas = SPRITE_SHEET
			frame_texture.region = Rect2(
				Vector2(frame_index * FRAME_SIZE.x, row * FRAME_SIZE.y),
				FRAME_SIZE
			)
			frames.add_frame(animation_name, frame_texture)

	return frames
