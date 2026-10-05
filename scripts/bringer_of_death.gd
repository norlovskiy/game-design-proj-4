class_name BringerOfDeath
extends Enemy

enum State {
	IDLE,
	WALK,
	ATTACK,
	CAST,
	HURT,
	DEAD,
}

const SPRITE_SHEET: Texture2D = preload(
	"res://assets/Bringer-Of-Death/SpriteSheet/Bringer-of-Death-SpritSheet.png"
)
const SPELL_SCENE: PackedScene = preload("res://scenes/bringer_spell.tscn")
const FRAME_SIZE := Vector2(140.0, 93.0)
const ATTACK_ACTIVE_FRAMES := [4, 5, 6, 7, 8]
const CAST_SPAWN_FRAME := 5

const IDLE_FRAMES := [
	Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0),
	Vector2i(4, 0), Vector2i(5, 0), Vector2i(6, 0), Vector2i(7, 0),
]
const WALK_FRAMES := [
	Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1),
	Vector2i(4, 1), Vector2i(5, 1), Vector2i(6, 1), Vector2i(7, 1),
]
const ATTACK_FRAMES := [
	Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2),
	Vector2i(4, 2), Vector2i(5, 2), Vector2i(6, 2), Vector2i(7, 2),
	Vector2i(0, 3), Vector2i(1, 3),
]
const HURT_FRAMES := [
	Vector2i(2, 3), Vector2i(3, 3), Vector2i(4, 3),
]
const DEATH_FRAMES := [
	Vector2i(5, 3), Vector2i(6, 3), Vector2i(7, 3), Vector2i(0, 4),
	Vector2i(1, 4), Vector2i(2, 4), Vector2i(3, 4), Vector2i(4, 4),
	Vector2i(5, 4), Vector2i(6, 4),
]
const CAST_FRAMES := [
	Vector2i(7, 4), Vector2i(0, 5), Vector2i(1, 5), Vector2i(2, 5),
	Vector2i(3, 5), Vector2i(4, 5), Vector2i(5, 5), Vector2i(6, 5),
	Vector2i(7, 5),
]

@export_category("Movement")
@export var walk_speed: float = 52.0
@export var acceleration: float = 420.0
@export var deceleration: float = 700.0
@export var detection_range: float = 420.0
@export var vertical_detection_range: float = 90.0

@export_category("Melee Attack")
@export var melee_range: float = 72.0
@export var melee_cooldown: float = 0.9

@export_category("Spell Attack")
@export var spell_range: float = 280.0
@export var spell_cooldown: float = 3.0

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _attack_hitbox: Area2D = $AttackHitbox
@onready var _attack_shape: CollisionShape2D = $AttackHitbox/CollisionShape2D

var _state: State = State.IDLE
var _target: Node2D
var _facing: float = -1.0
var _melee_cooldown_remaining := 0.0
var _spell_cooldown_remaining := 0.0
var _cast_position := Vector2.ZERO
var _spell_spawned := false
var _gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity", 980.0)


func _ready() -> void:
	_sprite.sprite_frames = _create_sprite_frames()
	_sprite.animation_finished.connect(_on_animation_finished)
	_sprite.frame_changed.connect(_on_frame_changed)
	_set_attack_active(false)
	_find_target()
	_set_state(State.IDLE)


func _physics_process(delta: float) -> void:
	_melee_cooldown_remaining = maxf(_melee_cooldown_remaining - delta, 0.0)
	_spell_cooldown_remaining = maxf(_spell_cooldown_remaining - delta, 0.0)

	if not is_on_floor():
		velocity.y += _gravity * delta

	match _state:
		State.IDLE, State.WALK:
			_update_behavior(delta)
		State.ATTACK, State.CAST, State.HURT, State.DEAD:
			velocity.x = move_toward(velocity.x, 0.0, deceleration * delta)

	move_and_slide()


func take_damage(amount: int) -> void:
	if _state == State.DEAD or amount <= 0:
		return

	super.take_damage(amount)
	if health == 0:
		_set_state(State.DEAD)
	else:
		_set_state(State.HURT)


func _update_behavior(delta: float) -> void:
	if not is_instance_valid(_target) or not _target.is_in_group(&"player"):
		_find_target()

	if not is_instance_valid(_target):
		_stop_and_idle(delta)
		return

	var offset := _target.global_position - global_position
	if absf(offset.x) > detection_range or absf(offset.y) > vertical_detection_range:
		_stop_and_idle(delta)
		return

	if not is_zero_approx(offset.x):
		_face(signf(offset.x))

	var horizontal_distance := absf(offset.x)
	if horizontal_distance <= melee_range:
		velocity.x = move_toward(velocity.x, 0.0, deceleration * delta)
		if _melee_cooldown_remaining <= 0.0:
			_set_state(State.ATTACK)
		else:
			_set_state(State.IDLE)
		return

	if horizontal_distance <= spell_range:
		velocity.x = move_toward(velocity.x, 0.0, deceleration * delta)
		if _spell_cooldown_remaining <= 0.0:
			_cast_position = Vector2(_target.global_position.x, global_position.y)
			_set_state(State.CAST)
		else:
			_set_state(State.IDLE)
		return

	velocity.x = move_toward(velocity.x, _facing * walk_speed, acceleration * delta)
	_set_state(State.WALK)


func _stop_and_idle(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, deceleration * delta)
	_set_state(State.IDLE)


func _find_target() -> void:
	_target = get_tree().get_first_node_in_group(&"player") as Node2D


func _face(direction: float) -> void:
	if is_zero_approx(direction):
		return
	_facing = signf(direction)
	_sprite.flip_h = _facing > 0.0
	_sprite.position.x = 35.0 * _facing
	_attack_hitbox.position.x = 48.0 * _facing


func _set_state(next_state: State) -> void:
	if _state == next_state and _sprite.is_playing():
		return

	_state = next_state
	_set_attack_active(false)

	match _state:
		State.IDLE:
			_sprite.play(&"idle")
		State.WALK:
			_sprite.play(&"walk")
		State.ATTACK:
			_sprite.play(&"attack")
		State.CAST:
			_spell_spawned = false
			_sprite.play(&"cast")
		State.HURT:
			_sprite.play(&"hurt")
		State.DEAD:
			$Hitbox.set_deferred("disabled", true)
			_sprite.play(&"death")


func _on_frame_changed() -> void:
	var attack_frame := _state == State.ATTACK and _sprite.frame in ATTACK_ACTIVE_FRAMES
	_set_attack_active(attack_frame)

	if _state == State.CAST and _sprite.frame == CAST_SPAWN_FRAME and not _spell_spawned:
		_spawn_spell()


func _set_attack_active(active: bool) -> void:
	_attack_shape.set_deferred("disabled", not active)


func _spawn_spell() -> void:
	_spell_spawned = true
	var spell := SPELL_SCENE.instantiate()
	var spell_parent := get_tree().current_scene
	if not is_instance_valid(spell_parent):
		spell_parent = get_parent()
	spell_parent.add_child(spell)
	spell.global_position = _cast_position


func _on_animation_finished() -> void:
	match _state:
		State.ATTACK:
			_melee_cooldown_remaining = melee_cooldown
			_set_state(State.IDLE)
		State.CAST:
			_spell_cooldown_remaining = spell_cooldown
			_set_state(State.IDLE)
		State.HURT:
			_set_state(State.IDLE)
		State.DEAD:
			queue_free()


func _create_sprite_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	_add_animation(frames, &"idle", IDLE_FRAMES, 8.0, true)
	_add_animation(frames, &"walk", WALK_FRAMES, 10.0, true)
	_add_animation(frames, &"attack", ATTACK_FRAMES, 12.0, false)
	_add_animation(frames, &"cast", CAST_FRAMES, 10.0, false)
	_add_animation(frames, &"hurt", HURT_FRAMES, 10.0, false)
	_add_animation(frames, &"death", DEATH_FRAMES, 10.0, false)
	return frames


func _add_animation(
	frames: SpriteFrames,
	animation_name: StringName,
	atlas_coordinates: Array,
	frames_per_second: float,
	loop: bool
) -> void:
	frames.add_animation(animation_name)
	frames.set_animation_speed(animation_name, frames_per_second)
	frames.set_animation_loop(animation_name, loop)

	for coordinates: Vector2i in atlas_coordinates:
		var frame_texture := AtlasTexture.new()
		frame_texture.atlas = SPRITE_SHEET
		frame_texture.region = Rect2(
			Vector2(coordinates.x * FRAME_SIZE.x, coordinates.y * FRAME_SIZE.y),
			FRAME_SIZE
		)
		frames.add_frame(animation_name, frame_texture)
