class_name RunEndScreen
extends CanvasLayer
## The screen shown when a run ends, win or lose. Enter asks for a new run.

signal restart_requested

const FONT: Font = preload("res://assets/fonts/VT323-Regular.ttf")
const WIN_COLOR := Color(1.0, 0.86, 0.4)
const LOSE_COLOR := Color(0.95, 0.35, 0.35)

var _dim := ColorRect.new()
var _title := Label.new()
var _detail := Label.new()
var _prompt := Label.new()


func _init() -> void:
	layer = 10
	# Keeps taking input while the game behind it is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_dim.color = Color(0, 0, 0, 0.72)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_dim)
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	# Square corners: a flat style box has no corner radius unless given one.
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.07, 0.06, 0.11, 0.96)
	box.border_color = Color(0.62, 0.6, 0.72)
	box.set_border_width_all(2)
	box.set_content_margin_all(28)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", box)
	centre.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	for entry in [[_title, 80], [_detail, 32], [_prompt, 32]]:
		var label: Label = entry[0]
		label.add_theme_font_override("font", FONT)
		label.add_theme_font_size_override("font_size", entry[1])
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(label)


func show_result(won: bool, gold: int) -> void:
	_title.text = "TREASURE CLAIMED" if won else "YOU DIED"
	_title.add_theme_color_override("font_color", WIN_COLOR if won else LOSE_COLOR)
	_detail.text = ("The castle's treasure is yours. Gold collected: %d" if won \
			else "The castle keeps its treasure. Gold collected: %d") % gold
	_prompt.text = "[Enter] Play again" if won else "[Enter] Try again"
	visible = true


func _input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
		get_viewport().set_input_as_handled()
		restart_requested.emit()
