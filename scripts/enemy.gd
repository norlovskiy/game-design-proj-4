class_name Enemy
extends CharacterBody2D

const HIT_FLASH_SHADER: Shader = preload("res://shaders/hit_flash.gdshader")
const HIT_FLASH_DURATION := 0.15

var health: int = 1
var _flash_material: ShaderMaterial
var _flash_tween: Tween

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
	_flash_white()


func _flash_white() -> void:
	var sprite := get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite == null:
		return
	if _flash_material == null:
		_flash_material = ShaderMaterial.new()
		_flash_material.shader = HIT_FLASH_SHADER
		sprite.material = _flash_material
	if _flash_tween and _flash_tween.is_running():
		_flash_tween.kill()
	_flash_material.set_shader_parameter("flash_amount", 1.0)
	_flash_tween = create_tween()
	_flash_tween.tween_method(_set_flash_amount, 1.0, 0.0, HIT_FLASH_DURATION)


func _set_flash_amount(amount: float) -> void:
	_flash_material.set_shader_parameter("flash_amount", amount)
