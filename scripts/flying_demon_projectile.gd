extends Area2D

@export var lifetime := 3.0

var _direction := Vector2.RIGHT
var _speed := 230.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func launch(direction: Vector2, speed: float) -> void:
	_direction = direction.normalized()
	_speed = speed
	rotation = _direction.angle()


func _physics_process(delta: float) -> void:
	global_position += _direction * _speed * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group(&"player"):
		body.take_hit()
	queue_free()
