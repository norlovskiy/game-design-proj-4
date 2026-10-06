extends Node2D
## The game: one run through a generated dungeon.
##
## A run ends when the player dies or claims the treasure. Either way the
## player is offered a new run, which starts everything fresh: a new dungeon
## and a new player with nothing carried over.

const CAMERA_ZOOM := 2.0
## Seconds between the player dying and the end screen, so the death is seen.
const LOSE_DELAY := 1.2

@onready var dungeon: Dungeon = $Dungeon
@onready var player_body: CharacterBody2D = $Player/CharacterBody2D

var end_screen := RunEndScreen.new()

var _seed_label := Label.new()


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
	add_child(end_screen)
	end_screen.restart_requested.connect(restart)
	player_body.died.connect(_on_player_died)
	dungeon.treasure_claimed.connect(_on_treasure_claimed)
	dungeon.track(player_body)
	enter_dungeon(randi() % 1000000)


func enter_dungeon(map_seed: int) -> void:
	if not dungeon.generate(map_seed):
		return
	_seed_label.text = "Seed %d  (Tab: map)" % dungeon.result.map_seed
	# The body's origin sits 10 px above the bottom of its collision shape.
	player_body.global_position = dungeon.to_global(dungeon.spawn_position()) + Vector2(0, -10)
	player_body.velocity = Vector2.ZERO


## Starts a new run by replacing this whole scene with a fresh copy, so
## nothing about the player or the dungeon carries over.
func restart() -> void:
	var tree := get_tree()
	tree.paused = false
	if tree.current_scene == self:
		tree.reload_current_scene()
		return
	var parent := get_parent()
	var fresh: Node = load(scene_file_path).instantiate()
	parent.remove_child(self)
	parent.add_child(fresh)
	queue_free()


func _on_player_died() -> void:
	await get_tree().create_timer(LOSE_DELAY).timeout
	end_screen.show_result(false, player_body.gold)


func _on_treasure_claimed() -> void:
	get_tree().paused = true
	end_screen.show_result(true, player_body.gold)
