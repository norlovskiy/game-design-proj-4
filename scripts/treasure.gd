class_name Treasure
extends Interactable
## The dungeon's treasure. Claiming it with the pickup key wins the run.

signal claimed

const HOVER_HEIGHT := 3.0
const HOVER_SPEED := 0.6
## How close the player must be for the prompt to show, in pixels.
const PROMPT_RANGE := 40.0
const PROMPT_GAP := 26.0

var _time := 0.0
var _claimed := false
var _prompt := WorldTextBox.new()

@onready var _sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	_prompt.visible = false
	_prompt.add_line("Castle Treasure", WorldTextBox.TITLE_COLOR)
	_prompt.add_line("[F] Claim")
	add_child(_prompt)


func _process(delta: float) -> void:
	_time += delta
	_sprite.position.y = sin(_time * TAU * HOVER_SPEED) * HOVER_HEIGHT
	var player := get_tree().get_first_node_in_group(&"player") as Node2D
	_prompt.visible = not _claimed and player != null \
			and global_position.distance_to(player.global_position) <= PROMPT_RANGE
	if _prompt.visible:
		_prompt.place_above(PROMPT_GAP)


func interact(player: Node) -> void:
	if _claimed:
		return
	_claimed = true
	super.interact(player)
	claimed.emit()
