extends Area2D
# Generic "walk near + press E" scene transition, matching the same
# interaction convention every other interactable in the JS game uses
# (chests, NPCs, doors) rather than a walk-straight-through trigger.

@export var target_scene: String = ""
@export var target_spawn: Vector2 = Vector2.ZERO
@export var prompt_label: Label

var _player_inside := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if prompt_label:
		prompt_label.visible = false

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_inside = true
		if prompt_label:
			prompt_label.visible = true

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_inside = false
		if prompt_label:
			prompt_label.visible = false

func _process(_delta: float) -> void:
	if _player_inside and not Combat.in_combat and not GameState.interact_blocked() and Input.is_action_just_pressed("interact"):
		GameState.set_next_spawn(target_spawn)
		get_tree().change_scene_to_file(target_scene)
