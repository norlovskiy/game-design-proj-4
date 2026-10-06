class_name MeleeEnemy
extends Enemy

@export_category("Hit Stun")
@export_range(0, 10, 1) var resisted_hits_after_hurt := 2
@export_range(1.0, 5.0, 0.1) var repeat_hurt_speed := 2.0

var _resisted_hits_remaining := 0
var _has_finished_hurt := false


func _should_play_hurt() -> bool:
	if _resisted_hits_remaining > 0:
		_resisted_hits_remaining -= 1
		return false
	return true


func _hurt_animation_speed() -> float:
	return repeat_hurt_speed if _has_finished_hurt else 1.0


func _on_hurt_finished() -> void:
	_has_finished_hurt = true
	_resisted_hits_remaining = resisted_hits_after_hurt
