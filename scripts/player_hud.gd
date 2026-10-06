extends CanvasLayer

@onready var health_bar: TextureProgressBar = $Layout/HealthBar
@onready var stamina_bar: TextureProgressBar = $Layout/StaminaBar
@onready var mana_bar: TextureProgressBar = $Layout/ManaBar
@onready var potion_count_label: Label = $Layout/PotionCounter/Count
@onready var item_slots: Array[TextureRect] = [
	$Layout/ItemFrames/ItemSlot1,
	$Layout/ItemFrames/ItemSlot2,
	$Layout/ItemFrames/ItemSlot3,
]


func _ready() -> void:
	var player := get_tree().get_first_node_in_group(&"player")
	if player == null:
		push_warning("Player HUD could not find the player")
		return
	health_bar.max_value = player.max_hp
	stamina_bar.max_value = player.max_stamina
	mana_bar.max_value = player.max_mana
	player.resources_changed.connect(_on_resources_changed)
	player.equipment_changed.connect(_on_equipment_changed)
	player.potions_changed.connect(_on_potions_changed)
	_on_resources_changed(player.hp, player.stamina, player.mana)
	_on_potions_changed(player.potion_count)
	for slot in item_slots.size():
		_on_equipment_changed(slot, player.get_equipped_icon(slot))


func _on_resources_changed(hp: int, stamina: float, mana: float) -> void:
	health_bar.value = hp
	stamina_bar.value = stamina
	mana_bar.value = mana


func _on_equipment_changed(slot: int, icon: Texture2D) -> void:
	if slot < 0 or slot >= item_slots.size():
		return
	item_slots[slot].texture = icon
	item_slots[slot].visible = icon != null


func _on_potions_changed(count: int) -> void:
	potion_count_label.text = "×%d" % count
