extends StaticBody2D
# A bed: walk up and press E to rest - HP and MP back to full, then an
# autosave. The reset point of the attrition loop (balance pass): armour
# sets how much each fight costs, potions are a small buffer, the bed at
# home resets the trip.

@onready var interact_area: Area2D = $InteractArea

var _player_inside := false

func _ready() -> void:
	interact_area.body_entered.connect(_on_body_entered)
	interact_area.body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_inside = true

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_inside = false

func _process(_delta: float) -> void:
	if _player_inside and not Combat.in_combat and not GameState.interact_blocked() and Input.is_action_just_pressed("interact"):
		rest()

func rest() -> void:
	Character.stats.hp = Character.stats.max_hp
	Character.stats.mp = Character.stats.max_mp
	Character.changed.emit()
	HUD._spawn_text_popup("Rested!", Color(0.55, 0.95, 0.5))
	SaveSystem.save_game()
