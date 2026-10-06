class_name WorldTextBox
extends PanelContainer
## A square-cornered text box drawn in the world, above whatever owns it.

const FONT: Font = preload("res://assets/fonts/VT323-Regular.ttf")
## Text is laid out at twice its world size and scaled down, so it stays
## sharp under the dungeon camera's 2x zoom.
const TEXT_SCALE := 0.5
const FONT_SIZE := 32
const TITLE_COLOR := Color(1.0, 0.86, 0.4)
const TEXT_COLOR := Color(0.86, 0.87, 0.92)
const WARNING_COLOR := Color(0.95, 0.35, 0.35)

var _column := VBoxContainer.new()


func _init() -> void:
	# Square corners: a flat style box has no corner radius unless given one.
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.07, 0.06, 0.11, 0.94)
	box.border_color = Color(0.62, 0.6, 0.72)
	box.set_border_width_all(2)
	box.set_content_margin_all(10)
	add_theme_stylebox_override("panel", box)
	scale = Vector2(TEXT_SCALE, TEXT_SCALE)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 20
	add_child(_column)


## Adds a line of text. A wrap width, in unscaled pixels, makes it a wrapping
## paragraph.
func add_line(text: String, color := TEXT_COLOR, wrap_width := 0.0) -> Label:
	var label := make_label(text, color)
	if wrap_width > 0.0:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size.x = wrap_width
	_column.add_child(label)
	return label


## Centres the box horizontally on its parent's origin, `gap` pixels above it.
func place_above(gap: float) -> void:
	reset_size()
	position = Vector2(-size.x / 2.0, -size.y) * TEXT_SCALE + Vector2(0, -gap)


static func make_label(text: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	label.add_theme_color_override("font_color", color)
	return label
