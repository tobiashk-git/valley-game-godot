extends StaticBody2D
# Interactive storage container — walk near, press E, opens StoragePanel.
# Same proximity convention as gatherable.gd/npc.gd/portal.gd.

@export var storage_id := "house_chest"

@onready var interact_area: Area2D = $InteractArea
@onready var storage_panel: Node = get_node("/root/StoragePanel")

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
	if _player_inside and not storage_panel.is_open() and Input.is_action_just_pressed("interact"):
		storage_panel.open_storage(storage_id)
