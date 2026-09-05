extends CharacterBody2D

const SPEED := 160.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var facing := "down"

func _ready() -> void:
	add_to_group("player")

func _physics_process(_delta: float) -> void:
	# Frozen mid-fight, while the defeat panel is up and during the opening.
	if Combat.in_combat or GameState.gathering or get_node("/root/DefeatPanel").is_open() or get_node("/root/Intro").is_playing():
		velocity = Vector2.ZERO
		move_and_slide()
		sprite.play(facing + "_idle")
		return

	var input_vector := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = input_vector * SPEED
	move_and_slide()

	if input_vector.length() > 0.01:
		if abs(input_vector.x) > abs(input_vector.y):
			facing = "right" if input_vector.x > 0 else "left"
		else:
			facing = "down" if input_vector.y > 0 else "up"
		sprite.play(facing)
	else:
		sprite.play(facing + "_idle")
