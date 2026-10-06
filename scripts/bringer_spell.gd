class_name BringerSpell
extends Node2D

const SPRITE_SHEET: Texture2D = preload(
	"res://assets/bringer-of-death/SpriteSheet/Bringer-of-Death-SpritSheet.png"
)
const FRAME_SIZE := Vector2(140.0, 93.0)
const ACTIVE_FRAMES := [5, 6, 7, 8, 9, 10, 11, 12]

static var _shared_frames: SpriteFrames

var activation_delay := 0.0

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _damage_shape: CollisionShape2D = $DamageArea/CollisionShape2D

func _ready() -> void:
	_sprite.sprite_frames = _create_sprite_frames()
	_sprite.frame_changed.connect(_on_frame_changed)
	_sprite.animation_finished.connect(_on_animation_finished)
	_set_active(false)
	_sprite.animation = &"spell"
	_sprite.frame = 0
	if activation_delay <= 0.0:
		_sprite.play()
		set_process(false)


func _process(delta: float) -> void:
	activation_delay -= delta
	if activation_delay <= 0.0:
		_sprite.play(&"spell")
		set_process(false)


func _on_frame_changed() -> void:
	_set_active(_sprite.frame in ACTIVE_FRAMES)


func _set_active(active: bool) -> void:
	_damage_shape.set_deferred("disabled", not active)


func _on_animation_finished() -> void:
	queue_free()


func _create_sprite_frames() -> SpriteFrames:
	if _shared_frames != null:
		return _shared_frames

	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	frames.add_animation(&"spell")
	frames.set_animation_speed(&"spell", 12.0)
	frames.set_animation_loop(&"spell", false)
	var sheet_image := SPRITE_SHEET.get_image()

	for row in range(6, 8):
		for column in 8:
			var frame_image := sheet_image.get_region(
				Rect2i(Vector2i(column * int(FRAME_SIZE.x), row * int(FRAME_SIZE.y)),
					Vector2i(FRAME_SIZE))
			)
			var frame_texture := ImageTexture.create_from_image(frame_image)
			frames.add_frame(&"spell", frame_texture)

	_shared_frames = frames
	return frames
