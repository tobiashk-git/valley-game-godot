extends StaticBody2D
# Solid (blocks movement, like every NPC in the JS game) with a proximity-
# triggered interaction — same walk-near + press E convention as Portal.
# Dispatches to whichever of shop/quest/plain-greeting applies to this NPC.

@export var sprite_path := ""
@export var npc_name := ""
@export var dialogue_text := ""
@export var quest_id := "" # if set (and shop is false), routes through Quests.talk_to_giver()
# A chain of quests this NPC hands out in order (the Elder: the tutorial,
# then the wood quest) - the first one not yet completed is the live one;
# once all are done the last one's "completed" line plays. Used instead of
# quest_id when non-empty.
@export var quest_ids: Array[String] = []
@export var shop := false # if true, opens ShopPanel instead of any dialogue
@export var npc_id := "" # stable id for Quests.npcs_met; "" skips the one-time intro entirely
@export var intro_text := "" # shown once, the very first interaction, before shop/quest/greeting
@export var sprite_tint := Color(1, 1, 1, 1) # lets a new NPC reuse an existing sprite with a distinct tint (matches enemies.gd's convention)

@onready var sprite: Sprite2D = $Sprite2D
@onready var interact_area: Area2D = $InteractArea
# DialogueUI/ShopPanel/Quests are registered as *scene* autoloads or, for
# Quests, just fetched the same defensive way for consistency — for
# whatever reason bare global identifiers for scene autoloads don't reliably
# resolve at GDScript compile time in this environment (headless --script
# runs failed to compile against them even after a project rescan), so
# they're fetched by absolute path instead, which always works at runtime.
@onready var dialogue_ui: Node = get_node("/root/DialogueUI")
@onready var shop_panel: Node = get_node("/root/ShopPanel")
@onready var quests: Node = get_node("/root/Quests")

var _player_inside := false
# The classic quest marker over the head: a gold "!" while this NPC has a
# quest to offer, a gold "?" while an accepted one is ready to turn in.
var _marker: Label
var _marker_base_y := 0.0

func _ready() -> void:
	if sprite_path != "":
		sprite.texture = load(sprite_path)
	sprite.modulate = sprite_tint
	interact_area.body_entered.connect(_on_body_entered)
	interact_area.body_exited.connect(_on_body_exited)
	_marker = Label.new()
	_marker.name = "QuestMarker"
	_marker.size = Vector2(32, 34)
	_marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_marker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_marker.add_theme_font_size_override("font_size", 28)
	_marker.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	_marker.add_theme_color_override("font_outline_color", Color(0.2, 0.12, 0.02))
	_marker.add_theme_constant_override("outline_size", 6)
	_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marker.visible = false
	# Just above the drawn sprite's top edge (the sprite is offset upwards
	# from the body's feet-level origin).
	var top: float = sprite.position.y + sprite.get_rect().position.y if sprite.texture else -32.0
	_marker_base_y = top - 36.0
	_marker.position = Vector2(-16.0, _marker_base_y)
	add_child(_marker)
	quests.changed.connect(_refresh_marker)
	Inventory.changed.connect(_refresh_marker)
	_refresh_marker()

# The quest this NPC currently deals in (see quest_ids).
func active_quest() -> String:
	var chain: Array = quest_ids if not quest_ids.is_empty() else ([quest_id] if quest_id != "" else [])
	if chain.is_empty():
		return ""
	for id in chain:
		if quests.quest_state.get(id, "") != "completed":
			return id
	return chain[chain.size() - 1]

# "!" = a quest to offer, "?" = an accepted quest ready to turn in, else none.
func marker_kind() -> String:
	var id: String = active_quest()
	if id == "":
		return ""
	var state: String = quests.quest_state.get(id, "")
	if state == "":
		return "!"
	if state == "accepted" and quests.objective_met(id) and quests.QUEST_DEFS[id].reward.has("gold"):
		return "?"
	return ""

func _refresh_marker() -> void:
	var kind: String = marker_kind()
	_marker.text = kind
	_marker.visible = kind != ""

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_inside = true

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_inside = false

func _process(_delta: float) -> void:
	if _marker.visible:
		_marker.position.y = _marker_base_y + sin(Time.get_ticks_msec() / 1000.0 * 4.0) * 3.0
	if not (_player_inside and not Combat.in_combat and not dialogue_ui.is_open() and not shop_panel.is_open() and Input.is_action_just_pressed("interact")):
		return
	if npc_id != "" and not quests.npcs_met.get(npc_id, false):
		var gates_opened: bool = quests.mark_npc_met(npc_id)
		var text := intro_text
		if gates_opened:
			text += " The village gates have opened!"
		dialogue_ui.show_dialogue(npc_name, text)
		return
	# An NPC can have both shop and quest_id set (Phase 6's Village Trader) -
	# an active quest (not yet completed) takes priority over the shop so it
	# can actually be reached, then falls back to the shop once it's done -
	# equivalent to the old shop-first / quest-only branches below for every
	# existing NPC that only ever has one of the two set.
	var live_quest: String = active_quest()
	var quest_active: bool = live_quest != "" and quests.quest_state.get(live_quest, "") != "completed"
	if quest_active:
		quests.talk_to_giver(live_quest)
	elif shop:
		shop_panel.open()
	elif live_quest != "":
		quests.talk_to_giver(live_quest)
	else:
		dialogue_ui.show_dialogue(npc_name, dialogue_text)
