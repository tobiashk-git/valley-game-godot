extends StaticBody2D
# Attached to Tree/Rock — port of tryGather()/nearestResourceTile() in
# game.js: walk near, press E, grants 1 of the resource, depletes after
# `amount` taps and removes itself (matching the JS depletion-then-revert
# behavior, simplified since there's no base terrain tile to revert to here
# — the prop instance itself just disappears).

@export var item_id := ""
@export var amount := 3

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
		Inventory.add_item(item_id, 1)
		amount -= 1
		if amount <= 0:
			queue_free()
