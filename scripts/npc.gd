extends StaticBody2D
# Solid (blocks movement, like every NPC in the JS game) with a proximity-
# triggered interaction — same walk-near + press E convention as Portal.
# Dispatches to whichever of shop/quest/plain-greeting applies to this NPC.

@export var sprite_path := ""
@export var npc_name := ""
@export var dialogue_text := ""
@export var quest_id := "" # if set (and shop is false), routes through Quests.talk_to_giver()
@export var shop := false # if true, opens ShopPanel instead of any dialogue

@onready var sprite: Sprite2D = $Sprite2D
@onready var interact_area: Area2D = $InteractArea
# DialogueUI/ShopPanel are registered as *scene* autoloads (not plain
# scripts like World/GameState) — for whatever reason their bare global
# identifiers don't reliably resolve at GDScript compile time in this
# environment (headless --script runs failed to compile against them even
# after a project rescan), so they're fetched by absolute path instead,
# which always works at runtime.
@onready var dialogue_ui: Node = get_node("/root/DialogueUI")
@onready var shop_panel: Node = get_node("/root/ShopPanel")

var _player_inside := false

func _ready() -> void:
	if sprite_path != "":
		sprite.texture = load(sprite_path)
	interact_area.body_entered.connect(_on_body_entered)
	interact_area.body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_inside = true

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_inside = false

func _process(_delta: float) -> void:
	if not (_player_inside and not Combat.in_combat and not dialogue_ui.is_open() and not shop_panel.is_open() and Input.is_action_just_pressed("interact")):
		return
	if shop:
		shop_panel.open()
	elif quest_id != "":
		get_node("/root/Quests").talk_to_giver(quest_id)
	else:
		dialogue_ui.show_dialogue(npc_name, dialogue_text)
