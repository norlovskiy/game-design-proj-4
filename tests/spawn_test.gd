extends SceneTree
## Spawns enemies into many generated dungeons and checks the spawn rules.
##
## Run: godot --headless --path . -s tests/spawn_test.gd
## On a fresh clone, run `godot --headless --path . --import` once first.

const MapPiece := preload("res://scripts/mapgen/map_piece.gd")

const SEEDS := 60

var _failures := 0
var _seed := 0


func _init() -> void:
	var table: DungeonSpawnTable = load("res://data/spawns/castle_spawns.tres")
	var allowed := {}
	var floor_scenes := {}
	for rule in table.rules:
		for piece_name in rule.pieces:
			allowed[[rule.enemy.resource_path, piece_name]] = true
		if rule.placement == DungeonSpawnRule.Placement.FLOOR:
			floor_scenes[rule.enemy.resource_path] = true

	if table.boss != null:
		allowed[[table.boss.resource_path, table.boss_piece]] = true
		floor_scenes[table.boss.resource_path] = true

	var dungeon := Dungeon.new()
	dungeon.theme = load("res://data/themes/castle_theme.tres")
	dungeon.spawn_table = table
	root.add_child(dungeon)
	var total := 0
	var fewest := 1 << 30
	var by_scene := {}
	for i in SEEDS:
		_seed = i * 311
		if not dungeon.generate(_seed):
			_fail("generation failed")
			continue
		var map := dungeon.result
		var first := _snapshot(dungeon)
		total += first.size()
		fewest = mini(fewest, first.size())
		var minimum := DungeonSpawner.minimum_for(map, table)
		if first.size() < minimum:
			_fail("%d enemies, minimum for this map is %d" % [first.size(), minimum])
		var per_piece := {}
		var cells: Array[Vector2i] = []
		for enemy: Node2D in dungeon.enemies.get_children():
			var scene := enemy.scene_file_path
			by_scene[scene] = by_scene.get(scene, 0) + 1
			# Just above the feet, so floor enemies land in the cell they stand in.
			var cell := Vector2i(((enemy.position + Vector2(0, -1)) / dungeon.cell_size()).floor())
			var owner := map.get_owner(cell.x, cell.y)
			if owner < 0 or map.get_tile(cell.x, cell.y) != MapPiece.EMPTY:
				_fail("%s spawned outside open space at %s" % [scene, cell])
				continue
			var piece: MapPiece = map.pieces[owner]
			if not allowed.has([scene, piece.name]):
				_fail("%s spawned in a %s" % [scene, piece.name])
			if floor_scenes.has(scene) and map.get_tile(cell.x, cell.y + 1) != MapPiece.SOLID:
				_fail("%s has no floor under it at %s" % [scene, cell])
			per_piece[owner] = per_piece.get(owner, 0) + 1
			if per_piece[owner] > table.max_per_piece:
				_fail("more than %d enemies in piece %d" % [table.max_per_piece, owner])
			for other in cells:
				if absi(other.x - cell.x) <= table.min_spacing and absi(other.y - cell.y) <= table.min_spacing:
					_fail("enemies at %s and %s are too close" % [other, cell])
			cells.append(cell)

		if table.boss != null:
			var bosses := 0
			for enemy: Node2D in dungeon.enemies.get_children():
				if enemy.scene_file_path == table.boss.resource_path:
					bosses += 1
			if bosses != 1:
				_fail("%d bosses spawned, expected 1" % bosses)

		dungeon.generate(_seed)
		if _snapshot(dungeon) != first:
			_fail("same seed spawned different enemies")

	print("%d seeds, %d failures, %.1f enemies per dungeon (fewest %d)" % [
		SEEDS, _failures, float(total) / SEEDS, fewest])
	for scene in by_scene:
		print("  %s: %.1f per dungeon" % [scene.get_file(), float(by_scene[scene]) / SEEDS])
	quit(1 if _failures > 0 else 0)


func _snapshot(dungeon: Dungeon) -> Array:
	var out := []
	for enemy: Node2D in dungeon.enemies.get_children():
		out.append([enemy.scene_file_path, enemy.position])
	return out


func _fail(message: String) -> void:
	_failures += 1
	if _failures <= 20:
		printerr("seed %d: %s" % [_seed, message])
