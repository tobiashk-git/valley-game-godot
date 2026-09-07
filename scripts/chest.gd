extends StaticBody2D
# Interactive storage container — walk near, press E, opens StoragePanel.
# Same proximity convention as gatherable.gd/npc.gd/portal.gd.

@export var storage_id := "house_chest"
# A different look for the same chest logic (the dungeon treasure chests);
# "" keeps the scene's texture (the house chest, the bank).
@export var sprite_path := ""

@onready var sprite: Sprite2D = $Sprite2D
@onready var interact_area: Area2D = $InteractArea
@onready var storage_panel: Node = get_node("/root/StoragePanel")

var _player_inside := false

func _ready() -> void:
	if sprite_path != "":
		sprite.texture = load(sprite_path)
	# Painted chests (2026-09-07) are taller than a tile: stand them on the
	# tile's bottom edge whatever their size.
	if sprite.texture != null:
		sprite.offset = Vector2(0.0, 16.0 - sprite.texture.get_size().y / 2.0)
	interact_area.body_entered.connect(_on_body_entered)
	interact_area.body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_inside = true

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_inside = false

func _process(_delta: float) -> void:
	if _player_inside and not Combat.in_combat and not GameState.interact_blocked() and not storage_panel.is_open() and Input.is_action_just_pressed("interact"):
		storage_panel.open_storage(storage_id)
