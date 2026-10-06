class_name StaffProjectile
extends Area2D

enum Variant { ARCANE, PIERCING, FROST }

const SPEED := 500.0
const LIFETIME := 1.5
const FROST_DURATION := 2.5

var variant: Variant = Variant.ARCANE
var direction := 1
var damage := 1
var remaining := LIFETIME
var hit_targets: Array[int] = []


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	$Bolt.scale.x = direction
	match variant:
		Variant.PIERCING:
			$Bolt.color = Color(1.0, 0.45, 0.3)
		Variant.FROST:
			$Bolt.color = Color(0.45, 0.9, 1.0)
		_:
			$Bolt.color = Color(0.5, 0.55, 1.0)


func _physics_process(delta: float) -> void:
	position.x += direction * SPEED * delta
	remaining -= delta
	if remaining <= 0.0:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if not body is Enemy:
		return
	var enemy := body as Enemy
	var enemy_id := enemy.get_instance_id()
	if enemy.health <= 0 or enemy_id in hit_targets:
		return
	hit_targets.append(enemy_id)
	enemy.take_damage(damage)
	if variant == Variant.FROST:
		enemy.apply_frost(FROST_DURATION)
	if variant != Variant.PIERCING:
		queue_free()
