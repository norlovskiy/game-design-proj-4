extends CharacterBody2D

var SPEED = 2000
var grav = 0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

func _process(_delta: float) -> void:
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:
	# detect horizontal movement of player
	var h_move: int = int(Input.is_physical_key_pressed(KEY_D)) - \
		int(Input.is_physical_key_pressed(KEY_A))
	if (h_move == -1):
		$AnimatedSprite2D.scale.x = -1
	if (h_move == 1):
		$AnimatedSprite2D.scale.x = 1
	if (h_move != 0):
		if ($AnimatedSprite2D.animation != "run"):
			$AnimatedSprite2D.animation = "run"
	else:
		if ($AnimatedSprite2D.animation != "default"):
			$AnimatedSprite2D.animation = "default"
	$AnimatedSprite2D.play()
	velocity.x = h_move * SPEED * delta
	velocity.y += grav * delta
	move_and_slide()
