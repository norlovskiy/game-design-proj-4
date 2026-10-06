extends Node2D
## Playable test of a generated dungeon. Run scenes/dungeon.tscn directly (F6).
##
## R builds a new dungeon from a random seed.

const CAMERA_ZOOM := 2.0
const BOSS_SCENE: PackedScene = preload("res://scenes/leaf_ranger.tscn")

@onready var dungeon: Dungeon = $Dungeon
@onready var player_body: CharacterBody2D = $Player/CharacterBody2D

var _seed_label := Label.new()
var _boss: Node2D


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color.BLACK)
	var camera := Camera2D.new()
	camera.zoom = Vector2(CAMERA_ZOOM, CAMERA_ZOOM)
	player_body.add_child(camera)
	var layer := CanvasLayer.new()
	add_child(layer)
	_seed_label.position = Vector2(8, 8)
	layer.add_child(_seed_label)
	var map := DungeonMap.new()
	map.setup(dungeon, player_body)
	add_child(map)
	dungeon.track(player_body)
	enter_dungeon(randi() % 1000000)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		enter_dungeon(randi() % 1000000)


func enter_dungeon(map_seed: int) -> void:
	if not dungeon.generate(map_seed):
		return
	if is_instance_valid(_boss):
		_boss.queue_free()
	_seed_label.text = "Seed %d  (R: new dungeon, Tab: map)" % dungeon.result.map_seed
	# The body's origin sits 10 px above the bottom of its collision shape.
	player_body.global_position = dungeon.to_global(dungeon.spawn_position()) + Vector2(0, -10)
	player_body.velocity = Vector2.ZERO
	for piece in dungeon.result.pieces:
		if piece.name != "boss":
			continue
		var floor_cell: Vector2i = piece.pos + Vector2i(piece.size.x / 2, piece.size.y - 1)
		_boss = BOSS_SCENE.instantiate() as Node2D
		add_child(_boss)
		_boss.global_position = dungeon.to_global(Vector2(floor_cell) * dungeon.cell_size())
		break
