extends Area2D
# Standalone interact trigger for the village altar tile — the tile itself
# is already solid via the Overworld's own TileMapLayer (SRC_ALTAR), so
# this Area2D only handles proximity + E, it isn't a physical blocker (same
# division of labor as every entrance prop + its Portal).

var _player_inside := false
@onready var dialogue_ui: Node = get_node("/root/DialogueUI")

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_inside = true

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_inside = false

func _process(_delta: float) -> void:
	if _player_inside and not Combat.in_combat and not dialogue_ui.is_open() and Input.is_action_just_pressed("interact"):
		Altar.interact()
