extends Node2D

const SPRITE_SHEET: Texture2D = preload(
	"res://assets/Bringer-Of-Death/SpriteSheet/Bringer-of-Death-SpritSheet.png"
)
const FRAME_SIZE := Vector2(140.0, 93.0)
const ACTIVE_FRAMES := [5, 6, 7, 8, 9, 10, 11, 12]

@export var damage: int = 2

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _damage_shape: CollisionShape2D = $DamageArea/CollisionShape2D

var _is_active := false
var _hit_targets: Array[int] = []


func _ready() -> void:
	_sprite.sprite_frames = _create_sprite_frames()
	_sprite.frame_changed.connect(_on_frame_changed)
	_sprite.animation_finished.connect(_on_animation_finished)
	$DamageArea.body_entered.connect(_on_body_entered)
	_set_active(false)
	_sprite.play(&"spell")


func _on_frame_changed() -> void:
	_set_active(_sprite.frame in ACTIVE_FRAMES)


func _set_active(active: bool) -> void:
	_is_active = active
	_damage_shape.set_deferred("disabled", not active)


func _on_body_entered(body: Node2D) -> void:
	if not _is_active or not body.is_in_group(&"player"):
		return

	var body_id := body.get_instance_id()
	if body_id in _hit_targets:
		return
	_hit_targets.append(body_id)

	if body.has_method("take_damage"):
		body.take_damage(damage)


func _on_animation_finished() -> void:
	queue_free()


func _create_sprite_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	frames.add_animation(&"spell")
	frames.set_animation_speed(&"spell", 12.0)
	frames.set_animation_loop(&"spell", false)

	for row in range(6, 8):
		for column in 8:
			var frame_texture := AtlasTexture.new()
			frame_texture.atlas = SPRITE_SHEET
			frame_texture.region = Rect2(
				Vector2(column * FRAME_SIZE.x, row * FRAME_SIZE.y),
				FRAME_SIZE
			)
			frames.add_frame(&"spell", frame_texture)

	return frames
