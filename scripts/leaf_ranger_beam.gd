class_name LeafRangerBeam
extends Area2D

const Sprites = preload("res://scripts/leaf_ranger_sprites.gd")
const TILE_LENGTH := 256.0
const ACTIVE_DURATION := 0.22
const LIFETIME := 0.38

var facing := 1.0
var beam_length := 1792.0
var _time := 0.0
var _shape: CollisionShape2D


func _ready() -> void:
	var frames := Sprites.make_frames(Sprites.EFFECTS, Vector2i(256, 128), {
		&"beam": [8, 4, 12.0, false],
	})
	var count := ceili(beam_length / TILE_LENGTH)
	var actual_length := count * TILE_LENGTH
	for index in count:
		var segment := AnimatedSprite2D.new()
		segment.sprite_frames = frames
		segment.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		segment.position.x = facing * (index + 0.5) * TILE_LENGTH
		segment.flip_h = facing < 0.0
		add_child(segment)
		segment.play(&"beam")
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(actual_length, 13)
	_shape = CollisionShape2D.new()
	_shape.shape = rectangle
	_shape.position.x = facing * actual_length * 0.5
	add_child(_shape)
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	_time += delta
	if _time >= ACTIVE_DURATION and not _shape.disabled:
		_shape.set_deferred("disabled", true)
	if _time >= LIFETIME:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if _time < ACTIVE_DURATION and body.is_in_group(&"player"):
		body.take_hit()
