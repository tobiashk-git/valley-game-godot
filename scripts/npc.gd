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
# Painted art (a keyed Leonardo illustration, hundreds of px tall) instead
# of a 64px pixel sprite: drawn smooth at this on-screen height with the
# feet FEET_DROP below the node, the interact area covering the figure -
# the same grounding maths as wild_monster.gd. 0 = a plain pixel sprite.
@export var art_height := 0.0
const FEET_DROP := 10.0
const INTERACT_MARGIN := 24.0

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
var _player: Node2D
# The classic quest marker over the head: a gold "!" while this NPC has a
# quest to offer, a gold "?" while an accepted one is ready to turn in.
var _marker: Label
var _marker_base_y := 0.0

func _ready() -> void:
	if sprite_path != "":
		sprite.texture = load(sprite_path)
	sprite.modulate = sprite_tint
	var visual_top: float = sprite.position.y + sprite.get_rect().position.y if sprite.texture else -32.0
	if art_height > 0.0 and sprite.texture != null:
		var tex_size: Vector2 = sprite.texture.get_size()
		var scale_f: float = art_height / tex_size.y
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		sprite.scale = Vector2(scale_f, scale_f)
		sprite.offset = Vector2(0.0, FEET_DROP / scale_f - tex_size.y / 2.0)
		var visual_size: Vector2 = tex_size * scale_f
		var visual_center: Vector2 = sprite.offset * scale_f
		var shape := RectangleShape2D.new()
		shape.size = visual_size + Vector2(INTERACT_MARGIN, INTERACT_MARGIN) * 2.0
		interact_area.get_node("CollisionShape2D").shape = shape
		interact_area.position = visual_center
		visual_top = visual_center.y - visual_size.y / 2.0
	interact_area.body_entered.connect(_on_body_entered)
	interact_area.body_exited.connect(_on_body_exited)
	add_to_group("npc")
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
	_marker_base_y = visual_top - 36.0
	_marker.position = Vector2(-16.0, _marker_base_y)
	add_child(_marker)
	quests.changed.connect(_refresh_marker)
	Inventory.changed.connect(_refresh_marker)
	_refresh_marker()

# The quest this NPC currently deals in (see quest_ids): the first one
# accepted or offerable (its requirements met - see Quests.is_available;
# a locked one is skipped, so the Elder can hand out chapter 3 before
# chapter 2). With nothing live, the last completed one (its closing line).
func active_quest() -> String:
	var chain: Array = quest_ids if not quest_ids.is_empty() else ([quest_id] if quest_id != "" else [])
	if chain.is_empty():
		return ""
	var last_completed := ""
	for id in chain:
		var state: String = quests.quest_state.get(id, "")
		if state == "accepted":
			return id
		if state == "completed":
			last_completed = id
		elif quests.is_available(id) and quests.offers(id, npc_id):
			return id # (a quest given elsewhere - the Ranger's hunt - is not offered here)
	return last_completed

# "!" = a quest to offer, "?" = an accepted quest ready to turn in, else none.
func marker_kind() -> String:
	var id: String = active_quest()
	if id == "":
		return ""
	var state: String = quests.quest_state.get(id, "")
	if state == "":
		return "!"
	if state == "accepted" and quests.objective_met(id) and quests.takes_turn_in(id, npc_id):
		return "?" # only the turn-in NPC shows it
	return ""

func _refresh_marker() -> void:
	var kind: String = marker_kind()
	_marker.text = kind
	_marker.visible = kind != ""

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_inside = true
		_player = body

# With two NPCs in reach (Luigi waiting beside Eden at a ford), only the
# nearer one answers E - otherwise the first in the tree would speak over
# the one the player walked up to.
func _is_nearest_in_reach() -> bool:
	if _player == null:
		return true
	var mine: float = global_position.distance_squared_to(_player.global_position)
	for other in get_tree().get_nodes_in_group("npc"):
		if other != self and other.get("_player_inside") == true and other.global_position.distance_squared_to(_player.global_position) < mine:
			return false
	return true

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_inside = false

func _process(_delta: float) -> void:
	if _marker.visible:
		_marker.position.y = _marker_base_y + sin(Time.get_ticks_msec() / 1000.0 * 4.0) * 3.0
	if not (_player_inside and not Combat.in_combat and not dialogue_ui.is_open() and not shop_panel.is_open() and Input.is_action_just_pressed("interact")):
		return
	if not _is_nearest_in_reach():
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
	if quest_active and shop and quests.quest_state.get(live_quest, "") == "accepted" and not quests.objective_met(live_quest):
		# A shopkeeper mid-errand: the reminder, with the shop a tap away
		# (the Blacksmith's two-step chain must never lock his counter).
		var def: Dictionary = quests.QUEST_DEFS[live_quest]
		dialogue_ui.show_dialogue(npc_name, "%s (%s)" % [def.dialogue.in_progress, quests.objective_progress_text(live_quest)], [
			{"label": "Shop", "callback": shop_panel.open.bind(npc_id)},
			{"label": "Later", "callback": Callable()},
		])
	elif quest_active:
		quests.talk_to_giver(live_quest, npc_id)
	elif shop:
		shop_panel.open(npc_id)
	elif live_quest != "":
		quests.talk_to_giver(live_quest, npc_id)
	else:
		dialogue_ui.show_dialogue(npc_name, dialogue_text)
