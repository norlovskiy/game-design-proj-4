extends CanvasLayer

@onready var health_bar: TextureProgressBar = $Layout/HealthBar
@onready var stamina_bar: TextureProgressBar = $Layout/StaminaBar
@onready var mana_bar: TextureProgressBar = $Layout/ManaBar


func _ready() -> void:
	var player := get_tree().get_first_node_in_group(&"player")
	if player == null:
		push_warning("Player HUD could not find the player")
		return
	health_bar.max_value = player.max_hp
	stamina_bar.max_value = player.max_stamina
	mana_bar.max_value = player.max_mana
	player.resources_changed.connect(_on_resources_changed)
	_on_resources_changed(player.hp, player.stamina, player.mana)


func _on_resources_changed(hp: int, stamina: float, mana: float) -> void:
	health_bar.value = hp
	stamina_bar.value = stamina
	mana_bar.value = mana
