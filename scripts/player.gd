extends CharacterBody2D

signal lives_changed(lives_remaining: int)
signal died

const MOVE_SPEED := 200.0
const ROLL_SPEED := 320.0
const JUMP_VELOCITY := -400.0
const HIT_RECOVERY_DURATION := 0.25
const HIT_FLASH_DURATION := 0.15
const HIT_INVINCIBILITY_DURATION := 1.0
const WORLD_COLLISION_LAYER := 1
const ENEMY_COLLISION_LAYER := 4
const NORMAL_COLLISION_MASK := WORLD_COLLISION_LAYER | ENEMY_COLLISION_LAYER

@export_range(1, 10) var max_lives := 3

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var lives_remaining := max_lives

var is_rolling := false
var is_hurt := false
var is_dead := false
var roll_direction := 1
var jump_was_pressed := false
var roll_was_pressed := false
var hit_recovery_remaining := 0.0
var hit_flash_remaining := 0.0
var hit_invincibility_remaining := 0.0
var is_invincible: bool:
	get:
		return is_rolling or hit_invincibility_remaining > 0.0 or is_dead


func _physics_process(delta: float) -> void:
	_advance_hit_state(delta)
	if is_dead:
		velocity.x = 0.0
		_apply_gravity(delta)
		move_and_slide()
		return

	var horizontal_input := int(Input.is_physical_key_pressed(KEY_D)) - int(Input.is_physical_key_pressed(KEY_A))
	var jump_pressed := Input.is_physical_key_pressed(KEY_SPACE)
	var roll_pressed := Input.is_physical_key_pressed(KEY_SHIFT)
	var jump_just_pressed := jump_pressed and not jump_was_pressed
	var roll_just_pressed := roll_pressed and not roll_was_pressed
	jump_was_pressed = jump_pressed
	roll_was_pressed = roll_pressed

	_apply_gravity(delta)

	if not is_rolling and not is_hurt:
		if horizontal_input != 0:
			animated_sprite.flip_h = horizontal_input < 0
		if roll_just_pressed and is_on_floor():
			_start_roll(horizontal_input)
		elif jump_just_pressed and is_on_floor():
			velocity.y = JUMP_VELOCITY
			_play_animation("jump")

	if is_hurt:
		velocity.x = 0.0
	else:
		velocity.x = roll_direction * ROLL_SPEED if is_rolling else horizontal_input * MOVE_SPEED
	move_and_slide()
	if is_rolling and not is_on_floor():
		_end_roll()
	_update_animation(horizontal_input)


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += ProjectSettings.get_setting("physics/2d/default_gravity") * delta
	else:
		velocity.y = 0.0


func _advance_hit_state(delta: float) -> void:
	if hit_invincibility_remaining > 0.0:
		hit_invincibility_remaining = maxf(0.0, hit_invincibility_remaining - delta)
	if hit_flash_remaining > 0.0:
		hit_flash_remaining = maxf(0.0, hit_flash_remaining - delta)
		if hit_flash_remaining == 0.0:
			animated_sprite.modulate = Color.WHITE
	if hit_recovery_remaining > 0.0:
		hit_recovery_remaining = maxf(0.0, hit_recovery_remaining - delta)
		if hit_recovery_remaining == 0.0:
			is_hurt = false
			if lives_remaining == 0:
				_die()


func _start_roll(horizontal_input: int) -> void:
	is_rolling = true
	collision_layer = 0
	collision_mask = WORLD_COLLISION_LAYER
	if horizontal_input != 0:
		roll_direction = horizontal_input
	else:
		roll_direction = -1 if animated_sprite.flip_h else 1
	_play_animation("roll")


func _end_roll() -> void:
	is_rolling = false
	collision_layer = WORLD_COLLISION_LAYER
	collision_mask = NORMAL_COLLISION_MASK


func _update_animation(horizontal_input: int) -> void:
	if is_rolling or is_hurt or is_dead:
		return
	if is_on_floor():
		_play_animation("run" if horizontal_input != 0 else "default")
	elif velocity.y < 0.0:
		_play_animation("jump")
	elif animated_sprite.animation == "jump":
		_play_animation("jump_fall")
	elif animated_sprite.animation != "jump_fall":
		_play_animation("fall")


func _play_animation(animation_name: StringName) -> void:
	if animated_sprite.animation != animation_name:
		animated_sprite.play(animation_name)
	elif not animated_sprite.is_playing() and animated_sprite.sprite_frames.get_animation_loop(animation_name):
		animated_sprite.play()


func _on_animated_sprite_animation_finished() -> void:
	if animated_sprite.animation == "roll":
		_end_roll()
	elif animated_sprite.animation == "jump_fall" and not is_on_floor():
		_play_animation("fall")


func can_take_damage() -> bool:
	return not is_invincible


func take_hit() -> bool:
	if not can_take_damage():
		return false
	lives_remaining -= 1
	is_hurt = true
	hit_recovery_remaining = HIT_RECOVERY_DURATION
	hit_flash_remaining = HIT_FLASH_DURATION
	hit_invincibility_remaining = HIT_INVINCIBILITY_DURATION
	animated_sprite.modulate = Color(1.0, 0.25, 0.25)
	_play_animation("hit")
	lives_changed.emit(lives_remaining)
	return true


func _die() -> void:
	is_dead = true
	remove_from_group(&"player")
	animated_sprite.modulate = Color.WHITE
	$Hitbox.set_deferred("monitoring", false)
	_play_animation("death")
	died.emit()


func _on_hitbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("enemy_hitboxes"):
		take_hit()
