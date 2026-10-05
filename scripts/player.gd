extends CharacterBody2D

signal lives_changed(lives_remaining: int)
signal died

const MOVE_SPEED := 200.0
const ROLL_SPEED := 320.0
const JUMP_VELOCITY := -460.0
const HIT_RECOVERY_DURATION := 0.25
const HIT_FLASH_DURATION := 0.15
const HIT_INVINCIBILITY_DURATION := 1.0
const COMBO_WINDOW_DURATION := 0.35
const ATTACK_ACTIVE_FRAMES := [1, 2]
const ATTACK_REACH := 24.0

@export_range(1, 10) var max_lives := 3
@export_range(1, 100) var base_attack_damage := 1

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_hitbox: Area2D = $AttackHitbox
@onready var attack_shape: CollisionShape2D = $AttackHitbox/CollisionShape2D
@onready var lives_remaining := max_lives

var is_rolling := false
var is_attacking := false
var is_hurt := false
var is_dead := false
var attack_damage_bonus := 0
var roll_direction := 1
var jump_was_pressed := false
var roll_was_pressed := false
var attack_key_was_pressed := false
var attack_mouse_was_pressed := false
var queued_second_attack := false
var combo_window_remaining := 0.0
var hit_targets: Array[int] = []
var hit_recovery_remaining := 0.0
var hit_flash_remaining := 0.0
var hit_invincibility_remaining := 0.0
var is_invincible: bool:
	get:
		return is_rolling or hit_invincibility_remaining > 0.0 or is_dead


func _ready() -> void:
	_set_attack_active(false)


func _physics_process(delta: float) -> void:
	_advance_hit_state(delta)
	if combo_window_remaining > 0.0:
		combo_window_remaining = maxf(0.0, combo_window_remaining - delta)
	if is_dead:
		velocity.x = 0.0
		_apply_gravity(delta)
		move_and_slide()
		return

	var horizontal_input := int(Input.is_physical_key_pressed(KEY_D)) - int(Input.is_physical_key_pressed(KEY_A))
	var jump_pressed := Input.is_physical_key_pressed(KEY_SPACE)
	var roll_pressed := Input.is_physical_key_pressed(KEY_SHIFT)
	var attack_key_pressed := Input.is_physical_key_pressed(KEY_J)
	var attack_mouse_pressed := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var jump_just_pressed := jump_pressed and not jump_was_pressed
	var roll_just_pressed := roll_pressed and not roll_was_pressed
	var attack_just_pressed := (attack_key_pressed and not attack_key_was_pressed) or \
		(attack_mouse_pressed and not attack_mouse_was_pressed)
	jump_was_pressed = jump_pressed
	roll_was_pressed = roll_pressed
	attack_key_was_pressed = attack_key_pressed
	attack_mouse_was_pressed = attack_mouse_pressed

	_apply_gravity(delta)

	if not is_rolling and not is_hurt:
		if attack_just_pressed:
			_request_attack(horizontal_input)
	if not is_rolling and not is_hurt and not is_attacking:
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
	if horizontal_input != 0:
		roll_direction = horizontal_input
	else:
		roll_direction = -1 if animated_sprite.flip_h else 1
	_play_animation("roll")


func _end_roll() -> void:
	is_rolling = false


func _request_attack(horizontal_input: int) -> void:
	if is_attacking:
		if animated_sprite.animation == &"attack_1":
			queued_second_attack = true
		return
	_start_attack(2 if combo_window_remaining > 0.0 else 1, horizontal_input)


func _start_attack(swing: int, horizontal_input: int) -> void:
	is_attacking = true
	queued_second_attack = false
	combo_window_remaining = 0.0
	hit_targets.clear()
	if horizontal_input != 0:
		animated_sprite.flip_h = horizontal_input < 0
	attack_hitbox.position.x = -ATTACK_REACH if animated_sprite.flip_h else ATTACK_REACH
	_set_attack_active(false)
	_play_animation(&"attack_2" if swing == 2 else &"attack_1")


func _finish_attack() -> void:
	_set_attack_active(false)
	if animated_sprite.animation == &"attack_1" and queued_second_attack:
		_start_attack(2, 0)
		return
	combo_window_remaining = COMBO_WINDOW_DURATION if animated_sprite.animation == &"attack_1" else 0.0
	is_attacking = false
	queued_second_attack = false


func _cancel_attack() -> void:
	is_attacking = false
	queued_second_attack = false
	combo_window_remaining = 0.0
	_set_attack_active(false)


func _set_attack_active(active: bool) -> void:
	attack_shape.set_deferred("disabled", not active)


func get_attack_damage() -> int:
	return maxi(0, base_attack_damage + attack_damage_bonus)


func _update_animation(horizontal_input: int) -> void:
	if is_rolling or is_attacking or is_hurt or is_dead:
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
	elif animated_sprite.animation == &"attack_1" or animated_sprite.animation == &"attack_2":
		_finish_attack()
	elif animated_sprite.animation == "jump_fall" and not is_on_floor():
		_play_animation("fall")


func _on_animated_sprite_frame_changed() -> void:
	var active := is_attacking and animated_sprite.frame in ATTACK_ACTIVE_FRAMES
	_set_attack_active(active)


func _on_attack_hitbox_body_entered(body: Node2D) -> void:
	if not is_attacking or not body is Enemy:
		return
	var enemy := body as Enemy
	if enemy.health <= 0 or enemy.get_instance_id() in hit_targets:
		return
	hit_targets.append(enemy.get_instance_id())
	enemy.take_damage(get_attack_damage())


func can_take_damage() -> bool:
	return not is_invincible


func take_hit() -> bool:
	if not can_take_damage():
		return false
	_cancel_attack()
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
