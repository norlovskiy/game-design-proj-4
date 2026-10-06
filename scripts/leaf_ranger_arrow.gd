class_name LeafRangerArrow
extends Area2D

const Sprites = preload("res://scripts/leaf_ranger_sprites.gd")
const EFFECT_SCENE: PackedScene = preload("res://scenes/leaf_ranger_effect.tscn")

@onready var _sprite: Sprite2D = $Sprite2D

var burst_kind := 0
var direction := Vector2.RIGHT
var speed := 390.0
var lifetime := 2.4
var _exploded := false


func configure(kind: int, flight_direction: Vector2, flight_speed: float) -> void:
	burst_kind = kind
	direction = flight_direction.normalized()
	speed = flight_speed
	rotation = direction.angle()


func _ready() -> void:
	var texture := AtlasTexture.new()
	texture.atlas = Sprites.EFFECTS
	texture.region = Rect2(0, 0, 256, 128)
	_sprite.texture = texture
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	if _exploded:
		return
	var next_position := global_position + direction * speed * delta
	var query := PhysicsRayQueryParameters2D.create(global_position, next_position, 9)
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	var excluded: Array[RID] = []
	while not hit.is_empty() and _is_rolling_player(hit.collider):
		excluded.append(hit.rid)
		query.exclude = excluded
		hit = get_world_2d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		global_position = hit.position
		_hit_body(hit.collider)
		_explode()
		return
	global_position = next_position
	lifetime -= delta
	if lifetime <= 0.0:
		_explode()


func _on_body_entered(body: Node2D) -> void:
	if _exploded or _is_rolling_player(body):
		return
	_hit_body(body)
	_explode()


func _is_rolling_player(body: Object) -> bool:
	if not body is Node2D:
		return false
	var node := body as Node2D
	return node.is_in_group(&"player") and node.get("is_rolling") == true


func _hit_body(body: Object) -> void:
	if body is Node2D and body.is_in_group(&"player"):
		body.take_hit()


func _explode() -> void:
	if _exploded:
		return
	_exploded = true
	var burst := EFFECT_SCENE.instantiate() as Node2D
	burst.call("configure", burst_kind)
	var parent := get_tree().current_scene
	if parent == null:
		parent = get_parent()
	# Collision callbacks run while physics is flushing its queries.
	parent.call_deferred("add_child", burst)
	burst.set_deferred("global_position", global_position)
	queue_free()
