class_name DungeonMap
extends CanvasLayer
## Full-screen map of visited rooms. Tab toggles it and pauses the game.

const MapPiece := preload("res://scripts/mapgen/map_piece.gd")

const DOOR_COLOR := Color(1.0, 1.0, 1.0)
const PLATFORM_COLOR := Color(0.75, 0.78, 0.85)
const PIECE_COLOR := Color(0.55, 0.55, 0.58)
const START_COLOR := Color(0.3, 0.8, 0.35)
const SHOP_COLOR := Color(0.9, 0.25, 0.25)
const MARKER_COLOR := Color(1.0, 0.82, 0.2)
const MARGIN := 48.0

var _dungeon: Dungeon
var _player: Node2D
var _view := Control.new()
var _texture: ImageTexture


func setup(dungeon: Dungeon, player: Node2D) -> void:
	_dungeon = dungeon
	_player = player


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.0, 0.0, 0.0, 0.92)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_view.draw.connect(_draw_map)
	add_child(_view)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_TAB:
		set_open(not visible)
		get_viewport().set_input_as_handled()


func set_open(open: bool) -> void:
	visible = open
	get_tree().paused = open
	if open:
		_rebuild_texture()
		_view.queue_redraw()


## One pixel per map cell; unvisited rooms stay transparent.
func _rebuild_texture() -> void:
	var map := _dungeon.result
	var image := Image.create_empty(map.size.x, map.size.y, false, Image.FORMAT_RGBA8)
	for y in map.size.y:
		for x in map.size.x:
			var owner := map.get_owner(x, y)
			if owner < 0 or not _dungeon.explored.has(owner):
				continue
			var base := PIECE_COLOR
			match map.pieces[owner].name:
				"start":
					base = START_COLOR
				"shop":
					base = SHOP_COLOR
			var color := base
			match map.get_tile(x, y):
				MapPiece.SOLID:
					color = base.darkened(0.65)
				MapPiece.EMPTY:
					color = base.darkened(0.15)
				MapPiece.DOOR:
					color = DOOR_COLOR
				MapPiece.PLATFORM:
					color = PLATFORM_COLOR
			image.set_pixel(x, y, color)
	_texture = ImageTexture.create_from_image(image)


func _draw_map() -> void:
	if _texture == null:
		return
	var map_size := Vector2(_dungeon.result.size)
	var available := _view.size - Vector2(MARGIN, MARGIN) * 2.0
	var scale := minf(available.x / map_size.x, available.y / map_size.y)
	# Whole pixels per cell keep the cells crisp.
	if scale >= 1.0:
		scale = floorf(scale)
	var rect := Rect2((_view.size - map_size * scale) / 2.0, map_size * scale)
	_view.draw_texture_rect(_texture, rect, false)
	var cell := _dungeon.to_local(_player.global_position) / _dungeon.cell_size()
	_view.draw_circle(rect.position + cell * scale, maxf(scale * 1.5, 4.0), MARKER_COLOR)
