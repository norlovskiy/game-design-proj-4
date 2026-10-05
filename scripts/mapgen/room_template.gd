extends RefCounted
## A hand-authored room loaded from a JSON file.
##
## "tiles" is a list of equal-length strings: '#' solid, '.' empty, 'D' door.
## Doors are runs of 'D' on the border, auto-named left_N / right_N (top to
## bottom) and top_N / bottom_N (left to right). "doors" maps those names to
## {"role", "reserved", "requires"}.

const MapPiece := preload("res://scripts/mapgen/map_piece.gd")

const REQUIRES := {
	"double_jump": MapPiece.ZONE_DOUBLE_JUMP,
	"key": MapPiece.ZONE_ITEM_LOCK,
}

var name := ""
var size := Vector2i.ZERO
var rows: Array[String] = []
## Unmirrored door definitions: {cells, dir, role, reserved, zone_add}.
var door_defs: Array[Dictionary] = []


## Returns {name: RoomTemplate} for every .json file in dir.
static func load_all(dir: String) -> Dictionary:
	var out := {}
	for file in DirAccess.get_files_at(dir):
		if not file.ends_with(".json"):
			continue
		var path := dir.path_join(file)
		var data = JSON.parse_string(FileAccess.get_file_as_string(path))
		if typeof(data) != TYPE_DICTIONARY:
			push_error("Room file is not a JSON object: %s" % path)
			continue
		var template = new()
		template._load(data)
		out[template.name] = template
	return out


func instantiate(mirror: bool) -> MapPiece:
	var piece := MapPiece.new()
	piece.kind = "room"
	piece.name = name
	piece.mirrored = mirror
	piece.init_tiles(size, MapPiece.SOLID)
	for y in size.y:
		for x in size.x:
			# Doors start solid and are opened when something attaches.
			if rows[y][_flip(x, mirror)] == ".":
				piece.set_tile(x, y, MapPiece.EMPTY)
	for def in door_defs:
		var cells: Array[Vector2i] = []
		for cell: Vector2i in def.cells:
			cells.append(Vector2i(_flip(cell.x, mirror), cell.y))
		var dir: Vector2i = def.dir
		var door := piece.add_door(def.role, cells, Vector2i(-dir.x if mirror else dir.x, dir.y))
		door.reserved = def.reserved
		door.zone_add = def.zone_add
	return piece


func _flip(x: int, mirror: bool) -> int:
	return size.x - 1 - x if mirror else x


func _load(data: Dictionary) -> void:
	name = data.name
	for row in data.tiles:
		rows.append(row)
	size = Vector2i(rows[0].length(), rows.size())
	var info: Dictionary = data.get("doors", {})
	_scan("left", Vector2i(0, 0), Vector2i(0, 1), size.y, Vector2i(-1, 0), info)
	_scan("right", Vector2i(size.x - 1, 0), Vector2i(0, 1), size.y, Vector2i(1, 0), info)
	_scan("top", Vector2i(0, 0), Vector2i(1, 0), size.x, Vector2i(0, -1), info)
	_scan("bottom", Vector2i(0, size.y - 1), Vector2i(1, 0), size.x, Vector2i(0, 1), info)


func _scan(side: String, from: Vector2i, step: Vector2i, count: int, dir: Vector2i,
		info: Dictionary) -> void:
	var run: Array[Vector2i] = []
	var found := 0
	for i in count + 1:
		var cell := from + step * i
		if i < count and rows[cell.y][cell.x] == "D":
			run.append(cell)
		elif not run.is_empty():
			var key := "%s_%d" % [side, found]
			var extra: Dictionary = info.get(key, {})
			door_defs.append({
				"cells": run.duplicate(),
				"dir": dir,
				"role": extra.get("role", key),
				"reserved": extra.get("reserved", ""),
				"zone_add": REQUIRES.get(extra.get("requires", ""), 0),
			})
			found += 1
			run.clear()
