extends RefCounted
## One rectangle of the generated map: a function room, a hall or a shaft.
##
## Pieces form a tree. Each piece except the start room hangs off a door of
## its parent, so there is exactly one route between any two pieces.

const EMPTY := 0
const SOLID := 1
const DOOR := 2
const PLATFORM := 3
const ROCK := 4

## Zone flags: what the player must have to reach a piece.
const ZONE_DOUBLE_JUMP := 1
const ZONE_ITEM_LOCK := 2


class Door:
	## Cells in piece-local coordinates, sorted.
	var cells: Array[Vector2i] = []
	## Outward normal.
	var dir := Vector2i.ZERO
	var role := ""
	## Non-empty when only one kind of piece may attach here.
	var reserved := ""
	## Zone flags gained by passing through this door.
	var zone_add := 0
	var used := false
	var sealed := false


## "room", "hall" or "shaft".
var kind := ""
## Template name for rooms; "hall", "shaft" or "dead_end" otherwise.
var name := ""
var pos := Vector2i.ZERO
var size := Vector2i.ZERO
var tiles := PackedByteArray()
var doors: Array[Door] = []
var mirrored := false
var zone := 0
var index := -1

var parent: RefCounted = null
## The door on the parent this piece hangs off.
var parent_door: Door = null
## The door on this piece that meets parent_door.
var entry_door: Door = null


func init_tiles(piece_size: Vector2i, fill: int) -> void:
	size = piece_size
	tiles.resize(size.x * size.y)
	tiles.fill(fill)


func get_tile(x: int, y: int) -> int:
	return tiles[y * size.x + x]


func set_tile(x: int, y: int, value: int) -> void:
	tiles[y * size.x + x] = value


func rect() -> Rect2i:
	return Rect2i(pos, size)


func add_door(role: String, cells: Array[Vector2i], dir: Vector2i) -> Door:
	var door := Door.new()
	door.role = role
	door.cells = cells
	door.cells.sort()
	door.dir = dir
	doors.append(door)
	return door


func door_by_role(role: String) -> Door:
	for door in doors:
		if door.role == role:
			return door
	return null
