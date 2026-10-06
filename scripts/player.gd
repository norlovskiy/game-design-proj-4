extends CharacterBody2D

signal lives_changed(lives_remaining: int)
signal resources_changed(hp: int, stamina: float, mana: float)
signal equipment_changed(slot: int, icon: Texture2D)
signal potions_changed(count: int)
signal gold_changed(amount: int)
signal keys_changed(count: int)
signal died

const MOVE_SPEED := 200.0
const ROLL_SPEED := 280.0
const JUMP_VELOCITY := -460.0
## Seconds after walking off a ledge during which a jump still counts as a
## ground jump.
const COYOTE_TIME := 0.1
const HIT_RECOVERY_DURATION := 0.25
const HIT_FLASH_DURATION := 0.15
const HIT_INVINCIBILITY_DURATION := 1.0
const COMBO_WINDOW_DURATION := 0.35
const ATTACK_ACTIVE_FRAMES := [1, 2]
const ATTACK_REACH := 24.0
const STAFF_PROJECTILE_SCENE: PackedScene = preload("res://scenes/staff_projectile.tscn")
const STAFF_MANA_COST := 20.0
const STAFF_CAST_LOCK_DURATION := 0.4
const HEALTH_RING_INTERVAL := 20.0
const POTION_HEAL_AMOUNT := 1

@export_range(1, 10) var max_hp := 6
@export_range(1.0, 200.0, 1.0) var max_stamina := 100.0
@export_range(0.0, 100.0, 1.0) var roll_stamina_cost := 25.0
@export var stamina_regen_rate := 20.0
@export var stamina_regen_delay := 0.75
@export_range(1.0, 200.0, 1.0) var max_mana := 100.0
@export var mana_regen_rate := 10.0
@export var mana_regen_delay := 0.5
@export_range(1, 100) var base_attack_damage := 1

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_hitbox: Area2D = $AttackHitbox
@onready var attack_shape: CollisionShape2D = $AttackHitbox/CollisionShape2D
@onready var pickup_area: Area2D = $PickupArea
@onready var hp := max_hp
@onready var stamina := max_stamina
@onready var mana := max_mana

var is_rolling := false
var is_attacking := false
var is_hurt := false
var is_dead := false
var attack_damage_bonus := 0
var has_sword := false
var staff_variant := -1
var ring_variant := -1
var potion_count := 0
var gold := 0
var key_count := 0
var has_double_jump := false
var air_jump_used := false
## The boss room, in global pixels, while the player is inside it; otherwise
## empty. Enemies outside it leave the player alone.
var arena_rect := Rect2()
var health_regen_elapsed := 0.0
var roll_direction := 1
var jump_was_pressed := false
var coyote_remaining := 0.0
var roll_was_pressed := false
var attack_key_was_pressed := false
var attack_mouse_was_pressed := false
var pickup_was_pressed := false
var heal_was_pressed := false
var cast_key_was_pressed := false
var cast_mouse_was_pressed := false
var queued_second_attack := false
var combo_window_remaining := 0.0
var hit_targets: Array[int] = []
var hit_recovery_remaining := 0.0
var hit_flash_remaining := 0.0
var hit_invincibility_remaining := 0.0
var stamina_regen_wait := 0.0
var mana_regen_wait := 0.0
var staff_cast_remaining := 0.0
var max_lives: int:
	get:
		return max_hp
var lives_remaining: int:
	get:
		return hp
## Set while the player is somewhere enemies can't hurt or target them, such
## as the shop.
var is_safe := false
## Debug toggle: F1 stops all damage to the player.
var damage_disabled := false
var is_invincible: bool:
	get:
		return is_rolling or hit_invincibility_remaining > 0.0 or is_dead or is_safe \
				or damage_disabled


func _ready() -> void:
	_set_attack_active(false)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F1:
		damage_disabled = not damage_disabled
		print("Damage %s" % ("disabled" if damage_disabled else "enabled"))


func _physics_process(delta: float) -> void:
	_advance_hit_state(delta)
	_advance_resources(delta)
	staff_cast_remaining = maxf(0.0, staff_cast_remaining - delta)
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
	var pickup_pressed := Input.is_physical_key_pressed(KEY_F)
	var heal_pressed := Input.is_physical_key_pressed(KEY_H)
	var cast_key_pressed := Input.is_physical_key_pressed(KEY_K)
	var cast_mouse_pressed := Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	var jump_just_pressed := jump_pressed and not jump_was_pressed
	var roll_just_pressed := roll_pressed and not roll_was_pressed
	var attack_just_pressed := (attack_key_pressed and not attack_key_was_pressed) or \
		(attack_mouse_pressed and not attack_mouse_was_pressed)
	var pickup_just_pressed := pickup_pressed and not pickup_was_pressed
	var heal_just_pressed := heal_pressed and not heal_was_pressed
	var cast_just_pressed := (cast_key_pressed and not cast_key_was_pressed) or \
		(cast_mouse_pressed and not cast_mouse_was_pressed)
	jump_was_pressed = jump_pressed
	roll_was_pressed = roll_pressed
	attack_key_was_pressed = attack_key_pressed
	attack_mouse_was_pressed = attack_mouse_pressed
	pickup_was_pressed = pickup_pressed
	heal_was_pressed = heal_pressed
	cast_key_was_pressed = cast_key_pressed
	cast_mouse_was_pressed = cast_mouse_pressed
	if pickup_just_pressed:
		_try_pickup()
	if heal_just_pressed:
		_try_use_potion()

	_apply_gravity(delta)
	if is_on_floor():
		air_jump_used = false
		coyote_remaining = COYOTE_TIME
	else:
		coyote_remaining = maxf(0.0, coyote_remaining - delta)

	if not is_rolling and not is_hurt and roll_just_pressed and is_on_floor() \
		and spend_stamina(get_roll_stamina_cost()):
		if is_attacking:
			_cancel_attack()
		staff_cast_remaining = 0.0
		_start_roll(horizontal_input)

	if not is_rolling and not is_hurt:
		if attack_just_pressed and staff_cast_remaining == 0.0:
			_request_attack(horizontal_input)
		if cast_just_pressed and not is_attacking and staff_cast_remaining == 0.0:
			_try_cast_staff(horizontal_input)
	if not is_rolling and not is_hurt and not is_attacking and staff_cast_remaining == 0.0:
		if horizontal_input != 0:
			animated_sprite.flip_h = horizontal_input < 0
		if jump_just_pressed and (is_on_floor() or coyote_remaining > 0.0):
			coyote_remaining = 0.0
			velocity.y = JUMP_VELOCITY
			_play_animation("jump")
		elif jump_just_pressed and has_double_jump and not air_jump_used:
			air_jump_used = true
			velocity.y = JUMP_VELOCITY
			_play_animation("jump")

	if is_hurt:
		velocity.x = 0.0
	elif (is_attacking or staff_cast_remaining > 0.0) and is_on_floor():
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
			if hp == 0:
				_die()


func _advance_resources(delta: float) -> void:
	if is_dead:
		return
	var changed := false
	if stamina_regen_wait > 0.0:
		stamina_regen_wait = maxf(0.0, stamina_regen_wait - delta)
	elif stamina < max_stamina:
		stamina = minf(max_stamina, stamina + stamina_regen_rate * delta)
		changed = true
	if mana_regen_wait > 0.0:
		mana_regen_wait = maxf(0.0, mana_regen_wait - delta)
	elif mana < max_mana:
		mana = minf(max_mana, mana + mana_regen_rate * delta)
		changed = true
	if changed:
		_emit_resources_changed()
	if ring_variant == 0 and hp > 0 and hp < max_hp:
		health_regen_elapsed += delta
		if health_regen_elapsed >= HEALTH_RING_INTERVAL:
			health_regen_elapsed = 0.0
			restore_hp(1)
	else:
		health_regen_elapsed = 0.0


func get_roll_stamina_cost() -> float:
	return maxf(0.0, roll_stamina_cost - (10.0 if ring_variant == 1 else 0.0))


func get_staff_mana_cost() -> float:
	return maxf(0.0, STAFF_MANA_COST - (5.0 if ring_variant == 2 else 0.0))


func receive_pickup(kind: int, variant: int) -> bool:
	if is_dead:
		return false
	match kind:
		ItemPickup.Kind.SWORD:
			if has_sword:
				return false
			has_sword = true
			attack_damage_bonus += 1
			equipment_changed.emit(0, ItemPickup.icon_for(kind, 0))
		ItemPickup.Kind.STAFF:
			if variant < 0 or variant > 2 or staff_variant == variant:
				return false
			staff_variant = variant
			equipment_changed.emit(1, ItemPickup.icon_for(kind, variant))
		ItemPickup.Kind.RING:
			if variant < 0 or variant > 2 or ring_variant == variant:
				return false
			ring_variant = variant
			health_regen_elapsed = 0.0
			equipment_changed.emit(2, ItemPickup.icon_for(kind, variant))
		ItemPickup.Kind.RED_POTION:
			potion_count += 1
			potions_changed.emit(potion_count)
		ItemPickup.Kind.KEY:
			key_count += 1
			keys_changed.emit(key_count)
		ItemPickup.Kind.DOUBLE_JUMP:
			if has_double_jump:
				return false
			has_double_jump = true
		_:
			return false
	return true


func _try_use_potion() -> bool:
	if is_dead or hp <= 0 or hp >= max_hp or potion_count <= 0:
		return false
	potion_count -= 1
	potions_changed.emit(potion_count)
	restore_hp(POTION_HEAL_AMOUNT)
	return true


func get_equipped_icon(slot: int) -> Texture2D:
	match slot:
		0:
			return ItemPickup.icon_for(ItemPickup.Kind.SWORD, 0) if has_sword else null
		1:
			return ItemPickup.icon_for(ItemPickup.Kind.STAFF, staff_variant) if staff_variant >= 0 else null
		2:
			return ItemPickup.icon_for(ItemPickup.Kind.RING, ring_variant) if ring_variant >= 0 else null
	return null


func add_gold(amount: int) -> void:
	if amount <= 0:
		return
	gold += amount
	gold_changed.emit(gold)


func spend_gold(amount: int) -> bool:
	if amount > gold:
		return false
	gold -= amount
	gold_changed.emit(gold)
	return true


## Spends a key if the player has one.
func use_key() -> bool:
	if key_count <= 0:
		return false
	key_count -= 1
	keys_changed.emit(key_count)
	return true


## The pickup in reach that the pickup key would take: the closest one.
func get_pickup_target() -> ItemPickup:
	var closest: ItemPickup
	var closest_distance := INF
	for area in pickup_area.get_overlapping_areas():
		if not area is ItemPickup:
			continue
		var distance := global_position.distance_squared_to(area.global_position)
		if distance < closest_distance:
			closest = area as ItemPickup
			closest_distance = distance
	return closest


func _try_pickup() -> void:
	var target := get_pickup_target()
	if target != null:
		target.collect(self)
		return
	# Nothing to pick up: use whatever else is in reach, such as a locked door.
	for area in pickup_area.get_overlapping_areas():
		if area is Interactable:
			(area as Interactable).interact(self)
			return


func _try_cast_staff(horizontal_input: int = 0) -> void:
	if staff_variant < 0 or not spend_mana(get_staff_mana_cost()):
		return
	if horizontal_input != 0:
		animated_sprite.flip_h = horizontal_input < 0
	staff_cast_remaining = STAFF_CAST_LOCK_DURATION
	var projectile := STAFF_PROJECTILE_SCENE.instantiate() as StaffProjectile
	projectile.variant = staff_variant as StaffProjectile.Variant
	projectile.direction = -1 if animated_sprite.flip_h else 1
	var projectile_parent := get_tree().current_scene
	if projectile_parent == null:
		projectile_parent = get_parent()
	projectile_parent.add_child(projectile)
	projectile.global_position = global_position + Vector2(projectile.direction * 20.0, -18.0)


func _emit_resources_changed() -> void:
	resources_changed.emit(hp, stamina, mana)


func spend_stamina(amount: float) -> bool:
	if is_dead or amount < 0.0 or stamina < amount:
		return false
	stamina = maxf(0.0, stamina - amount)
	stamina_regen_wait = stamina_regen_delay
	_emit_resources_changed()
	return true


func spend_mana(amount: float) -> bool:
	if is_dead or amount < 0.0 or mana < amount:
		return false
	mana = maxf(0.0, mana - amount)
	mana_regen_wait = mana_regen_delay
	_emit_resources_changed()
	return true


func restore_hp(amount: int) -> void:
	if is_dead or amount <= 0:
		return
	hp = mini(max_hp, hp + amount)
	lives_changed.emit(hp)
	_emit_resources_changed()


func _start_roll(horizontal_input: int) -> void:
	is_rolling = true
	if horizontal_input != 0:
		roll_direction = horizontal_input
	else:
		roll_direction = -1 if animated_sprite.flip_h else 1
	# A new roll can start before the finished animation is replaced next frame.
	# Always restart it so animation_finished can end this roll as well.
	animated_sprite.play(&"roll")
	animated_sprite.set_frame_and_progress(0, 0.0)


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
	if staff_cast_remaining > 0.0 and is_on_floor():
		_play_animation("default")
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
	staff_cast_remaining = 0.0
	hp -= 1
	health_regen_elapsed = 0.0
	is_hurt = true
	hit_recovery_remaining = HIT_RECOVERY_DURATION
	hit_flash_remaining = HIT_FLASH_DURATION
	hit_invincibility_remaining = HIT_INVINCIBILITY_DURATION
	animated_sprite.modulate = Color(1.0, 0.25, 0.25)
	_play_animation("hit")
	lives_changed.emit(hp)
	_emit_resources_changed()
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
