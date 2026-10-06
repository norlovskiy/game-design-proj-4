extends RefCounted
## The supplied sheets keep one animation on each row, with padded cells.

const RANGER: Texture2D = preload(
	"res://assets/leaf-ranger/animations/spritesheets/Elementals_leaf_ranger_288x128_SpriteSheet.png"
)
const EFFECTS: Texture2D = preload(
	"res://assets/leaf-ranger/animations/spritesheets/projectiles_and_effects_256x128_SpriteSheet.png"
)


static func make_frames(texture: Texture2D, cell_size: Vector2i, animations: Dictionary) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	for animation_name: StringName in animations:
		var data: Array = animations[animation_name]
		frames.add_animation(animation_name)
		frames.set_animation_speed(animation_name, float(data[2]))
		frames.set_animation_loop(animation_name, bool(data[3]))
		for column in int(data[1]):
			var frame := AtlasTexture.new()
			frame.atlas = texture
			frame.region = Rect2(
				Vector2(column * cell_size.x, int(data[0]) * cell_size.y),
				Vector2(cell_size)
			)
			frames.add_frame(animation_name, frame)
	return frames
