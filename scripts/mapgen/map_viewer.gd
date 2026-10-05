extends Node2D
## Debug view of the map generator. Run scenes/map_viewer.tscn directly (F6).
##
## Drag to pan, scroll to zoom, R for a random seed.

const MapGenerator := preload("res://scripts/mapgen/map_generator.gd")
const MapPiece := preload("res://scripts/mapgen/map_piece.gd")

const TILE := 16.0
## Screen width kept clear for the control panel when fitting the map.
const PANEL_WIDTH := 340.0
const ROCK_COLOR := Color(0.06, 0.06, 0.08)
const DOOR_COLOR := Color(1.0, 1.0, 1.0)
const PLATFORM_COLOR := Color(0.75, 0.78, 0.85)
const PIECE_COLORS := {
	"start": Color(0.3, 0.8, 0.35),
	"goal": Color(1.0, 0.82, 0.2),
	"shop": Color(0.2, 0.8, 0.85),
	"boss": Color(0.9, 0.25, 0.25),
	"vertical_lock": Color(0.65, 0.4, 0.9),
	"item_lock": Color(0.95, 0.55, 0.15),
	"item_key": Color(0.95, 0.9, 0.45),
	"item": Color(0.45, 0.65, 1.0),
	"hall": Color(0.55, 0.55, 0.58),
	"shaft": Color(0.4, 0.5, 0.62),
	"dead_end": Color(0.6, 0.45, 0.35),
}

var _generator := MapGenerator.new()
var _result: MapGenerator.Result
var _camera := Camera2D.new()
var _seed_box := SpinBox.new()
var _info := Label.new()
var _dragging := false


func _ready() -> void:
	RenderingServer.set_default_clear_color(ROCK_COLOR)
	add_child(_camera)
	_build_ui()
	_generate(randi() % 1000000)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_camera.zoom *= 1.1
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_camera.zoom /= 1.1
		else:
			_dragging = event.pressed
	elif event is InputEventMouseMotion and _dragging:
		_camera.position -= event.relative / _camera.zoom
	elif event is InputEventKey and event.pressed and event.keycode == KEY_R:
		_generate(randi() % 1000000)


func _draw() -> void:
	if _result == null or not _result.ok:
		return
	for y in _result.size.y:
		for x in _result.size.x:
			var owner := _result.get_owner(x, y)
			if owner < 0:
				continue
			var base: Color = PIECE_COLORS.get(_result.pieces[owner].name, Color.MAGENTA)
			var color := base
			match _result.get_tile(x, y):
				MapPiece.SOLID:
					color = base.darkened(0.65)
				MapPiece.EMPTY:
					color = base.darkened(0.15)
				MapPiece.DOOR:
					color = DOOR_COLOR
				MapPiece.PLATFORM:
					color = PLATFORM_COLOR
			draw_rect(Rect2(x * TILE, y * TILE, TILE, TILE), color)

	var font := ThemeDB.fallback_font
	for piece: MapPiece in _result.pieces:
		if piece.kind != "room" and piece.name != "dead_end":
			continue
		var label := piece.name
		if piece.zone & MapPiece.ZONE_DOUBLE_JUMP:
			label += " [double jump]"
		if piece.zone & MapPiece.ZONE_ITEM_LOCK:
			label += " [key]"
		draw_string(font, Vector2(piece.pos) * TILE + Vector2(2, -4), label,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 14)


func _generate(map_seed: int) -> void:
	_seed_box.set_value_no_signal(map_seed)
	_result = _generator.generate(map_seed)
	if _result.ok:
		_info.text = "%d x %d tiles, %d pieces, %d attempt(s)" % [
			_result.size.x, _result.size.y, _result.pieces.size(), _result.attempts]
		var map_size := Vector2(_result.size) * TILE
		var view := get_viewport_rect().size - Vector2(PANEL_WIDTH, 0)
		var fit := minf(view.x / map_size.x, view.y / map_size.y) * 0.9
		_camera.zoom = Vector2(fit, fit)
		_camera.position = map_size / 2.0 - Vector2(PANEL_WIDTH / 2.0 / fit, 0)
	else:
		_info.text = "Failed after %d attempts: %s" % [_result.attempts, _result.error]
	queue_redraw()


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(8, 8)
	layer.add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)

	var row := HBoxContainer.new()
	column.add_child(row)
	var seed_label := Label.new()
	seed_label.text = "Seed"
	row.add_child(seed_label)
	_seed_box.max_value = 2147483647
	_seed_box.custom_minimum_size.x = 130
	_seed_box.value_changed.connect(func(value: float) -> void: _generate(int(value)))
	row.add_child(_seed_box)
	var random := Button.new()
	random.text = "Random (R)"
	random.pressed.connect(func() -> void: _generate(randi() % 1000000))
	row.add_child(random)

	column.add_child(_info)

	var legend := GridContainer.new()
	legend.columns = 2
	column.add_child(legend)
	for piece_name: String in PIECE_COLORS:
		var swatch := ColorRect.new()
		swatch.color = PIECE_COLORS[piece_name]
		swatch.custom_minimum_size = Vector2(14, 14)
		legend.add_child(swatch)
		var label := Label.new()
		label.text = piece_name
		label.add_theme_font_size_override("font_size", 12)
		legend.add_child(label)
