extends SceneTree
## Checks coin and potion drops, coin collection and shop purchases.
##
## Run: godot --headless --path . -s tests/economy_test.gd
## On a fresh clone, run `godot --headless --path . --import` once first.

const ENEMIES := [
	"res://scenes/nightborne.tscn",
	"res://scenes/eyeball_monster.tscn",
	"res://scenes/flying_demon.tscn",
	"res://scenes/bringer_of_death.tscn",
	"res://scenes/leaf_ranger.tscn",
]
const KILLS := 40

var _failures := 0


func _init() -> void:
	# Nodes added before the first frame don't get _ready yet.
	await process_frame
	await _check_drops()
	await _check_coin_collection()
	_check_purchase()
	_check_text()
	print("economy: %d failures" % _failures)
	quit(1 if _failures > 0 else 0)


func _check_drops() -> void:
	for path: String in ENEMIES:
		var scene: PackedScene = load(path)
		var coins_seen := {}
		var potions := 0
		var allowed := Vector2i.ZERO
		var chance := 0.0
		for i in KILLS:
			var holder := Node2D.new()
			root.add_child(holder)
			var enemy: Enemy = scene.instantiate()
			holder.add_child(enemy)
			allowed = enemy.coin_drop
			chance = enemy.potion_drop_chance
			enemy.take_damage(1000000)
			# Hitting a corpse must not drop again.
			enemy.take_damage(1000000)
			await process_frame
			var coins := 0
			var dropped_potions := 0
			var abilities := 0
			for child in holder.get_children():
				if child is CoinPickup:
					coins += 1
				elif child is ItemPickup and child.kind == ItemPickup.Kind.DOUBLE_JUMP:
					abilities += 1
				elif child is ItemPickup:
					dropped_potions += 1
					if child.kind != ItemPickup.Kind.RED_POTION or child.price != 0:
						_fail("%s dropped an item that isn't a free potion" % path.get_file())
			if abilities != (1 if enemy.drops_double_jump else 0):
				_fail("%s dropped %d double jump abilities" % [path.get_file(), abilities])
			if coins < allowed.x or coins > allowed.y:
				_fail("%s dropped %d coins, expected %d-%d" % [path.get_file(), coins, allowed.x, allowed.y])
			if dropped_potions > 1:
				_fail("%s dropped %d potions" % [path.get_file(), dropped_potions])
			coins_seen[coins] = true
			potions += dropped_potions
			holder.free()
		if chance >= 1.0 and potions != KILLS:
			_fail("%s should always drop a potion, dropped %d of %d" % [path.get_file(), potions, KILLS])
		print("  %s: %d-%d coins (saw %d different amounts), potions %d of %d kills" % [
			path.get_file(), allowed.x, allowed.y, coins_seen.size(), potions, KILLS])


func _check_coin_collection() -> void:
	var world := Node2D.new()
	root.add_child(world)
	var floor_body := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(400, 20)
	shape.shape = rect
	floor_body.add_child(shape)
	floor_body.position = Vector2(0, 10)
	world.add_child(floor_body)
	var player_scene: Node2D = load("res://scenes/player.tscn").instantiate()
	world.add_child(player_scene)
	var player: CharacterBody2D = player_scene.get_node("CharacterBody2D")
	player.global_position = Vector2(0, -10)
	for i in 3:
		var coin: CoinPickup = load("res://scenes/coin.tscn").instantiate()
		coin.position = Vector2(-6 + 6 * i, -30)
		world.add_child(coin)
	var far: CoinPickup = load("res://scenes/coin.tscn").instantiate()
	far.position = Vector2(150, -30)
	world.add_child(far)
	for i in 90:
		await physics_frame
	if player.gold != 3:
		_fail("player touching 3 coins has %d gold" % player.gold)
	if not is_instance_valid(far) or far.position.y > 5.0:
		_fail("a coin out of reach should rest on the floor")
	world.free()


func _check_purchase() -> void:
	var world := Node2D.new()
	root.add_child(world)
	var player_scene: Node2D = load("res://scenes/player.tscn").instantiate()
	world.add_child(player_scene)
	var player: CharacterBody2D = player_scene.get_node("CharacterBody2D")
	var potion: ItemPickup = load("res://scenes/item_pickup.tscn").instantiate()
	potion.kind = ItemPickup.Kind.RED_POTION
	potion.price = 15
	world.add_child(potion)
	player.add_gold(10)
	if potion.collect(player) or player.gold != 10 or player.potion_count != 0:
		_fail("bought a 15 gold item with 10 gold")
	player.add_gold(10)
	if not potion.collect(player) or player.gold != 5 or player.potion_count != 1:
		_fail("purchase with 20 gold left %d gold and %d potions" % [player.gold, player.potion_count])

	# An item the player can't use must not take their gold.
	player.add_gold(100)
	player.receive_pickup(ItemPickup.Kind.SWORD, 0)
	var sword: ItemPickup = load("res://scenes/item_pickup.tscn").instantiate()
	sword.price = 30
	world.add_child(sword)
	var before: int = player.gold
	if sword.collect(player) or player.gold != before:
		_fail("charged for a sword the player already has")
	world.free()


func _check_text() -> void:
	for kind in ItemPickup.Kind.values():
		for variant in 3:
			if ItemPickup.display_name(kind, variant) == "" or ItemPickup.description(kind, variant) == "":
				_fail("item %d/%d has no name or description" % [kind, variant])


func _fail(message: String) -> void:
	_failures += 1
	printerr(message)
