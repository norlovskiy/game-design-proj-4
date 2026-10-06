class_name DungeonGate
extends StaticBody2D
## A barrier that fills a doorway. Lowered it blocks the way; raised it
## slides up behind the wall above the door.
##
## A gate that requires a key is opened with the pickup key by a player
## carrying one. Without a key it says it is locked.

signal opened
signal closed_shut

const MOVE_TIME := 0.5
## Seconds the "locked" message stays up.
const MESSAGE_TIME := 2.5
## How close the player must be for the prompt to show, in pixels.
const PROMPT_RANGE := 56.0
const PROMPT_GAP := 6.0

@export var requires_key := false

## Whether the gate is lowered, blocking the doorway.
var closed := true

var _size := Vector2(32, 64)
var _message_remaining := 0.0
var _tween: Tween
var _prompt: WorldTextBox
var _prompt_label: Label

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _shape: CollisionShape2D = $CollisionShape2D
@onready var _use_area: Interactable = $UseArea


## Call before adding to the tree. `size` is the doorway in pixels; the
## gate's origin is the doorway's top-left corner.
func setup(size: Vector2, starts_closed: bool, needs_key: bool) -> void:
	_size = size
	closed = starts_closed
	requires_key = needs_key


func _ready() -> void:
	_sprite.scale = _size / _sprite.region_rect.size
	(_shape.shape as RectangleShape2D).size = _size
	($UseArea/CollisionShape2D.shape as RectangleShape2D).size = _size + Vector2(PROMPT_RANGE, 0)
	_use_area.position = _size / 2.0
	_use_area.interacted.connect(_on_interacted)
	_use_area.monitorable = requires_key
	_prompt = WorldTextBox.new()
	_prompt.visible = false
	_prompt_label = _prompt.add_line("")
	var anchor := Node2D.new()
	anchor.position = Vector2(_size.x / 2.0, 0)
	anchor.add_child(_prompt)
	add_child(anchor)
	_apply(1.0 if closed else 0.0)


func _process(delta: float) -> void:
	_message_remaining = maxf(0.0, _message_remaining - delta)
	if not requires_key or not closed:
		_prompt.visible = false
		return
	var player := get_tree().get_first_node_in_group(&"player") as Node2D
	var near := player != null \
			and player.global_position.distance_to(global_position + _size / 2.0) <= PROMPT_RANGE
	_prompt.visible = near or _message_remaining > 0.0
	if not _prompt.visible:
		return
	if _message_remaining > 0.0:
		_prompt_label.text = "Locked. You need a key."
		_prompt_label.add_theme_color_override("font_color", WorldTextBox.WARNING_COLOR)
	else:
		_prompt_label.text = "[F] Unlock"
		_prompt_label.add_theme_color_override("font_color", WorldTextBox.TEXT_COLOR)
	_prompt.place_above(PROMPT_GAP)


## Raises the gate out of the doorway.
func open() -> void:
	if not closed:
		return
	closed = false
	_move(0.0)
	opened.emit()


## Lowers the gate into the doorway.
func close() -> void:
	if closed:
		return
	closed = true
	_move(1.0)
	closed_shut.emit()


func _on_interacted(player: Node) -> void:
	if not requires_key or not closed:
		return
	if player.has_method("use_key") and player.use_key():
		open()
	else:
		_message_remaining = MESSAGE_TIME


func _move(lowered: float) -> void:
	if _tween != null and _tween.is_running():
		_tween.kill()
	var from := 1.0 + _sprite.position.y / _size.y
	_tween = create_tween()
	_tween.tween_method(_apply, from, lowered, MOVE_TIME * absf(lowered - from))


## Positions the gate: 1 is fully lowered, 0 fully raised. It only stops
## blocking once it is all the way up.
func _apply(lowered: float) -> void:
	var lift := (lowered - 1.0) * _size.y
	_sprite.position.y = lift
	_shape.position = _size / 2.0 + Vector2(0, lift)
	_shape.set_deferred("disabled", lowered <= 0.0)
