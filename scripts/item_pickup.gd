class_name ItemPickup
extends Area2D
## An item lying in the world. The player takes it with the pickup key; if it
## has a price, that much gold is paid first.

enum Kind { SWORD, STAFF, RING, RED_POTION }

const ITEM_SHEET: Texture2D = preload("res://assets/player/items_noframe.png")
const COIN_ICON: Texture2D = preload("res://assets/items/coin_large.png")
const FONT: Font = preload("res://assets/fonts/VT323-Regular.ttf")
const CELL_SIZE := 44
const HOVER_HEIGHT := 3.0
const HOVER_SPEED := 0.8
## Text is laid out at twice its world size and scaled down, so it stays
## sharp under the dungeon camera's 2x zoom.
const TEXT_SCALE := 0.5
const FONT_SIZE := 32
const TOOLTIP_WIDTH := 300.0
## Pixels between the item and the things drawn above and below it.
const TOOLTIP_GAP := 22.0
const PRICE_GAP := 16.0
## How far above the floor a dropped item comes to rest.
const REST_HEIGHT := 18.0
const NAME_COLOR := Color(1.0, 0.86, 0.4)
const TEXT_COLOR := Color(0.86, 0.87, 0.92)
const CANT_AFFORD_COLOR := Color(0.95, 0.35, 0.35)

@export var kind: Kind = Kind.SWORD
@export_range(0, 2) var variant := 0
## Gold the player pays to take this. 0 means free.
@export var price := 0
## Fall straight down to the floor below when spawned.
@export var drop_to_floor := false

var hover_time := 0.0

var _tooltip: PanelContainer
var _action_label: Label
var _price_tag: HBoxContainer
var _price_label: Label


func _ready() -> void:
	$Sprite2D.texture = icon_for(kind, variant)
	if drop_to_floor:
		_settle_on_floor()
	_build_tooltip()
	if price > 0:
		_build_price_tag()


func _process(delta: float) -> void:
	hover_time += delta
	$Sprite2D.position.y = -3.0 + sin(hover_time * TAU * HOVER_SPEED) * HOVER_HEIGHT
	var player := get_tree().get_first_node_in_group(&"player")
	var can_afford: bool = price <= 0 or (player != null and player.get("gold") != null and player.gold >= price)
	if _price_label != null:
		_price_label.add_theme_color_override("font_color", NAME_COLOR if can_afford else CANT_AFFORD_COLOR)
	_tooltip.visible = _is_targeted_by(player)
	if not _tooltip.visible:
		return
	if price <= 0:
		_action_label.text = "[F] Take"
	elif can_afford:
		_action_label.text = "[F] Buy for %d gold" % price
	else:
		_action_label.text = "Costs %d gold" % price
	_action_label.add_theme_color_override("font_color", TEXT_COLOR if can_afford else CANT_AFFORD_COLOR)
	_tooltip.reset_size()
	_tooltip.position = Vector2(-_tooltip.size.x / 2.0, -_tooltip.size.y) * TEXT_SCALE + Vector2(0, -TOOLTIP_GAP)


func collect(player: Node) -> bool:
	if not player.has_method("receive_pickup"):
		return false
	if price > 0 and (not player.has_method("spend_gold") or player.gold < price):
		return false
	if not player.receive_pickup(kind, variant):
		return false
	if price > 0:
		player.spend_gold(price)
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


static func display_name(item_kind: int, item_variant: int) -> String:
	match item_kind:
		Kind.SWORD:
			return "Iron Sword"
		Kind.STAFF:
			return ["Arcane Staff", "Piercing Staff", "Frost Staff"][clampi(item_variant, 0, 2)]
		Kind.RING:
			return ["Ring of Vigor", "Ring of Agility", "Ring of Focus"][clampi(item_variant, 0, 2)]
		Kind.RED_POTION:
			return "Red Potion"
	return "Item"


static func description(item_kind: int, item_variant: int) -> String:
	match item_kind:
		Kind.SWORD:
			return "Attacks deal 1 more damage."
		Kind.STAFF:
			return [
				"Press K to fire a magic bolt for 20 mana. Replaces your staff.",
				"Press K to fire a bolt that passes through enemies. Replaces your staff.",
				"Press K to fire a bolt that slows enemies. Replaces your staff.",
			][clampi(item_variant, 0, 2)]
		Kind.RING:
			return [
				"Restores 1 health every 20 seconds. Replaces your ring.",
				"Rolling costs 10 less stamina. Replaces your ring.",
				"Staff bolts cost 5 less mana. Replaces your ring.",
			][clampi(item_variant, 0, 2)]
		Kind.RED_POTION:
			return "Restores 1 health. Press H to drink."
	return ""


## Whether the pickup key would take this item right now.
func _is_targeted_by(player: Node) -> bool:
	if player == null:
		return false
	if player.has_method("get_pickup_target"):
		return player.get_pickup_target() == self
	return global_position.distance_to(player.global_position) < 40.0


func _settle_on_floor() -> void:
	var query := PhysicsRayQueryParameters2D.create(global_position, global_position + Vector2(0, 600), 1)
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		global_position = hit.position + Vector2(0, -REST_HEIGHT)


func _label(text: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	label.add_theme_color_override("font_color", color)
	return label


func _build_tooltip() -> void:
	# Square corners: a flat style box has no corner radius unless given one.
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.07, 0.06, 0.11, 0.94)
	box.border_color = Color(0.62, 0.6, 0.72)
	box.set_border_width_all(2)
	box.set_content_margin_all(10)
	_tooltip = PanelContainer.new()
	_tooltip.add_theme_stylebox_override("panel", box)
	_tooltip.scale = Vector2(TEXT_SCALE, TEXT_SCALE)
	_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip.z_index = 20
	_tooltip.visible = false
	var column := VBoxContainer.new()
	_tooltip.add_child(column)
	column.add_child(_label(display_name(kind, variant), NAME_COLOR))
	var body := _label(description(kind, variant), TEXT_COLOR)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size.x = TOOLTIP_WIDTH
	column.add_child(body)
	_action_label = _label("", TEXT_COLOR)
	column.add_child(_action_label)
	add_child(_tooltip)


func _build_price_tag() -> void:
	_price_tag = HBoxContainer.new()
	_price_tag.scale = Vector2(TEXT_SCALE, TEXT_SCALE)
	_price_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_price_tag.add_theme_constant_override("separation", 6)
	var coin := TextureRect.new()
	coin.texture = COIN_ICON
	coin.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	coin.custom_minimum_size = Vector2(FONT_SIZE, FONT_SIZE)
	coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_price_tag.add_child(coin)
	_price_label = _label(str(price), NAME_COLOR)
	_price_tag.add_child(_price_label)
	add_child(_price_tag)
	_price_tag.reset_size()
	_price_tag.position = Vector2(-_price_tag.size.x / 2.0 * TEXT_SCALE, PRICE_GAP)
