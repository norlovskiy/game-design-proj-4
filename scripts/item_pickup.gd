class_name ItemPickup
extends Area2D

enum Kind { SWORD, STAFF, RING, RED_POTION }

const ITEM_SHEET: Texture2D = preload("res://assets/player/items_noframe.png")
const CELL_SIZE := 44
const HOVER_HEIGHT := 3.0
const HOVER_SPEED := 0.8

@export var kind: Kind = Kind.SWORD
@export_range(0, 2) var variant := 0

var hover_time := 0.0


func _ready() -> void:
	$Sprite2D.texture = icon_for(kind, variant)
	$Sprite2D/Prompt.visible = false


func _process(delta: float) -> void:
	hover_time += delta
	$Sprite2D.position.y = -3.0 + sin(hover_time * TAU * HOVER_SPEED) * HOVER_HEIGHT
	var player := get_tree().get_first_node_in_group(&"player") as Node2D
	$Sprite2D/Prompt.visible = player != null and global_position.distance_to(player.global_position) < 40.0


func collect(player: Node) -> bool:
	if not player.has_method("receive_pickup") or not player.receive_pickup(kind, variant):
		return false
	queue_free()
	return true


static func icon_for(item_kind: int, item_variant: int) -> AtlasTexture:
	var column := 0
	var row := 0
	match item_kind:
		Kind.SWORD:
			row = 1
		Kind.STAFF:
			column = clampi(item_variant, 0, 2)
		Kind.RING:
			column = clampi(item_variant, 0, 2)
			row = 2
		Kind.RED_POTION:
			column = 1
			row = 3
	var icon := AtlasTexture.new()
	icon.atlas = ITEM_SHEET
	icon.region = Rect2(column * CELL_SIZE, row * CELL_SIZE, CELL_SIZE, CELL_SIZE)
	return icon
