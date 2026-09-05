extends StaticBody2D
# The Blacksmith's workbench: crafting, enhancing and salvaging only happen
# beside it (Crafting.at_station). Walk up and press E to open the
# Crafting tab right there - same proximity convention as the chest.

@onready var interact_area: Area2D = $InteractArea

var _player_inside := false

func _ready() -> void:
	interact_area.body_entered.connect(_on_body_entered)
	interact_area.body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and not _player_inside:
		_player_inside = true
		Crafting.station_entered()

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player") and _player_inside:
		_player_inside = false
		Crafting.station_left()

func _exit_tree() -> void:
	if _player_inside:
		_player_inside = false
		Crafting.station_left()

func _process(_delta: float) -> void:
	var sheet: Node = get_node("/root/CharacterSheet")
	if _player_inside and not Combat.in_combat and not GameState.interact_blocked() and not sheet.is_open() and Input.is_action_just_pressed("interact"):
		sheet.open("crafting")
