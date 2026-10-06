class_name Enemy
extends CharacterBody2D

const HIT_FLASH_SHADER: Shader = preload("res://shaders/hit_flash.gdshader")
const HIT_FLASH_DURATION := 0.15
const COIN_SCENE: PackedScene = preload("res://scenes/coin.tscn")
const ITEM_PICKUP_SCENE: PackedScene = preload("res://scenes/item_pickup.tscn")

var health: int = 1
var _flash_material: ShaderMaterial
var _flash_tween: Tween
var frost_remaining := 0.0
var movement_multiplier := 1.0

@export_category("Drops")
## Fewest and most coins dropped on death.
@export var coin_drop := Vector2i(1, 3)
@export_range(0.0, 1.0, 0.01) var potion_drop_chance := 0.05
## Always drop the double jump ability on death. For the boss.
@export var drops_double_jump := false

@export_category("Health")
@export_range(1, 100000, 1) var max_health: int = 1:
	set(value):
		max_health = maxi(value, 1)
		if is_node_ready():
			health = mini(health, max_health)
		else:
			health = max_health


func take_damage(amount: int) -> void:
	if amount <= 0 or health <= 0:
		return
	health = maxi(health - amount, 0)
	if health == 0:
		_clear_frost()
		_drop_loot()
	_flash_white()


## Scatters coins, and sometimes a health potion, where the enemy died.
func _drop_loot() -> void:
	var origin := global_position + Vector2(0, -12)
	for i in randi_range(coin_drop.x, coin_drop.y):
		var coin: CoinPickup = COIN_SCENE.instantiate()
		coin.velocity = Vector2(randf_range(-90.0, 90.0), randf_range(-260.0, -140.0))
		_add_drop(coin, origin)
	if randf() < potion_drop_chance:
		var potion: ItemPickup = ITEM_PICKUP_SCENE.instantiate()
		potion.kind = ItemPickup.Kind.RED_POTION
		potion.drop_to_floor = true
		_add_drop(potion, origin)
	if drops_double_jump:
		var ability: ItemPickup = ITEM_PICKUP_SCENE.instantiate()
		ability.kind = ItemPickup.Kind.DOUBLE_JUMP
		ability.drop_to_floor = true
		# Lands beside a potion dropped in the same spot, not on it.
		ability.side_step = 30.0
		_add_drop(ability, origin)


func _add_drop(drop: Node2D, at: Vector2) -> void:
	var parent := get_parent()
	if parent == null:
		drop.free()
		return
	drop.position = (parent as Node2D).to_local(at) if parent is Node2D else at
	# Deferred: death can happen inside a physics callback, where bodies and
	# areas can't be added.
	parent.add_child.call_deferred(drop)


## The player, or null when there is none or enemies must leave them alone.
func find_player() -> Node2D:
	var player := get_tree().get_first_node_in_group(&"player") as Node2D
	return player if player != null and can_target(player) else null


## Whether a node is a player that enemies are allowed to go after.
func can_target(node: Node) -> bool:
	if not node.is_in_group(&"player") or node.get("is_safe") == true:
		return false
	# A player in the boss arena is out of bounds for everything outside it.
	var arena = node.get("arena_rect")
	return not (arena is Rect2 and arena.has_area() and not arena.has_point(global_position))


func apply_frost(duration: float, slow_multiplier: float = 0.5) -> void:
	if health <= 0:
		return
	frost_remaining = maxf(frost_remaining, duration)
	movement_multiplier = minf(movement_multiplier, slow_multiplier)
	var material := _get_effect_material()
	if material != null:
		material.set_shader_parameter("frost_amount", 0.3)


func advance_status(delta: float) -> void:
	if frost_remaining > 0.0:
		frost_remaining = maxf(0.0, frost_remaining - delta)
		if frost_remaining == 0.0:
			_clear_frost()


func _clear_frost() -> void:
	frost_remaining = 0.0
	movement_multiplier = 1.0
	if _flash_material != null:
		_flash_material.set_shader_parameter("frost_amount", 0.0)


func _flash_white() -> void:
	var material := _get_effect_material()
	if material == null:
		return
	if _flash_tween and _flash_tween.is_running():
		_flash_tween.kill()
	material.set_shader_parameter("flash_amount", 1.0)
	_flash_tween = create_tween()
	_flash_tween.tween_method(_set_flash_amount, 1.0, 0.0, HIT_FLASH_DURATION)


func _get_effect_material() -> ShaderMaterial:
	var sprite := get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite == null:
		return null
	if _flash_material == null:
		_flash_material = ShaderMaterial.new()
		_flash_material.shader = HIT_FLASH_SHADER
		sprite.material = _flash_material
	return _flash_material


func _set_flash_amount(amount: float) -> void:
	_flash_material.set_shader_parameter("flash_amount", amount)
