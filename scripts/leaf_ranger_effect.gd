class_name LeafRangerEffect
extends Area2D

enum Kind { POISON, THORNS, RAIN }

const Sprites = preload("res://scripts/leaf_ranger_sprites.gd")
const EFFECT_ANIMATIONS := {
	&"poison": [3, 8, 14.0, false],
	&"thorns": [6, 8, 14.0, false],
	&"rain": [7, 18, 18.0, false],
}

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _shape: CollisionShape2D = $CollisionShape2D

var kind: Kind = Kind.POISON
var warning_delay := 0.0
var _started := false


func configure(effect_kind: Kind, delay: float = 0.0) -> void:
	kind = effect_kind
	warning_delay = maxf(delay, 0.0)


func _ready() -> void:
	_sprite.sprite_frames = Sprites.make_frames(Sprites.EFFECTS, Vector2i(256, 128), EFFECT_ANIMATIONS)
	_sprite.frame_changed.connect(_on_frame_changed)
	_sprite.animation_finished.connect(queue_free)
	_sprite.position.y = -64.0 if kind == Kind.RAIN else -8.0
	if kind == Kind.RAIN:
		var rain_shape := RectangleShape2D.new()
		rain_shape.size = Vector2(76, 104)
		_shape.shape = rain_shape
		_shape.position.y = -52.0
	else:
		var burst_shape := CircleShape2D.new()
		burst_shape.radius = 25.0 if kind == Kind.POISON else 23.0
		_shape.shape = burst_shape
	_shape.set_deferred("disabled", true)
	_sprite.visible = false
	if warning_delay <= 0.0:
		_start()
	else:
		queue_redraw()


func _physics_process(delta: float) -> void:
	if _started:
		return
	warning_delay -= delta
	if warning_delay <= 0.0:
		_start()
	else:
		queue_redraw()


func _draw() -> void:
	if _started or kind != Kind.RAIN:
		return
	var alpha := 0.55 + 0.25 * sin(Time.get_ticks_msec() * 0.018)
	draw_rect(Rect2(-40, -4, 80, 8), Color(0.93, 0.88, 0.24, alpha))
	draw_line(Vector2(-40, -12), Vector2(-40, 0), Color(0.93, 0.88, 0.24, alpha), 2.0)
	draw_line(Vector2(40, -12), Vector2(40, 0), Color(0.93, 0.88, 0.24, alpha), 2.0)


func _start() -> void:
	_started = true
	_sprite.visible = true
	queue_redraw()
	match kind:
		Kind.POISON:
			_sprite.play(&"poison")
		Kind.THORNS:
			_sprite.play(&"thorns")
		Kind.RAIN:
			_sprite.play(&"rain")
	_on_frame_changed()


func _on_frame_changed() -> void:
	var active := false
	if _started:
		match kind:
			Kind.POISON:
				active = _sprite.frame >= 2 and _sprite.frame <= 6
			Kind.THORNS:
				active = _sprite.frame >= 1 and _sprite.frame <= 7
			Kind.RAIN:
				active = _sprite.frame >= 2 and _sprite.frame <= 11
	_shape.set_deferred("disabled", not active)
