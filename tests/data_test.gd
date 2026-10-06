extends SceneTree
## Guards the hand-tuned resource files against losing settings.
##
## The Godot editor sometimes re-saves a .tres without its PackedStringArray
## values (room names on item pools, shop-only tile rules, ...), which quietly
## breaks the shop and the tilemaps. Check what those values should do.
##
## Run: godot --headless --path . -s tests/data_test.gd
## On a fresh clone, run `godot --headless --path . --import` once first.

const MapPiece := preload("res://scripts/mapgen/map_piece.gd")

const SEEDS := 40

var _failures := 0


func _init() -> void:
	var theme: DungeonTheme = load("res://data/themes/castle_theme.tres")
	var shop_rules := 0
	for rule in theme.tile_rules:
		if "shop" in rule.pieces:
			shop_rules += 1
	if shop_rules == 0:
		_fail("no tile rule is limited to the shop, so shop tiles would show everywhere")
	var shop_excluded := 0
	for decoration in theme.decorations:
		if "shop" in decoration.excluded_pieces:
			shop_excluded += 1
	if shop_excluded == 0:
		_fail("no decoration is kept out of the shop")

	var spawns: DungeonSpawnTable = load("res://data/spawns/castle_spawns.tres")
	for rule in spawns.rules:
		if rule.pieces.is_empty():
			_fail("a spawn rule for %s names no pieces" % rule.enemy.resource_path.get_file())

	var items: DungeonItemTable = load("res://data/items/castle_items.tres")
	var dungeon := Dungeon.new()
	dungeon.theme = theme
	dungeon.item_table = items
	root.add_child(dungeon)
	for i in SEEDS:
		if not dungeon.generate(i * 97):
			_fail("seed %d: generation failed" % (i * 97))
			continue
		var in_shop := 0
		var keys := 0
		for pickup: ItemPickup in dungeon.items.get_children():
			var cell := Vector2i((pickup.position / dungeon.cell_size()).floor())
			var piece: MapPiece = dungeon.result.pieces[dungeon.result.get_owner(cell.x, cell.y)]
			if piece.name == "shop":
				in_shop += 1
				if pickup.price <= 0:
					_fail("seed %d: a shop item has no price" % (i * 97))
			elif piece.name == "item_key" and pickup.kind == 4:
				keys += 1
		if in_shop == 0:
			_fail("seed %d: the shop has no items" % (i * 97))
		if keys == 0:
			_fail("seed %d: the key room has no key" % (i * 97))

	print("%d seeds, %d failures" % [SEEDS, _failures])
	quit(1 if _failures > 0 else 0)


func _fail(message: String) -> void:
	_failures += 1
	if _failures <= 20:
		printerr(message)
