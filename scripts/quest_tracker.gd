extends CanvasLayer
# Autoload — persistent overlay down the right side of the screen showing
# live status for up to Quests.MAX_TRACKED quests pinned via the Journal's
# Track button, so progress is visible during normal play without opening
# the panel. Hidden whenever any of the 5 toggleable panels or the battle
# screen are open (they'd otherwise overlap it), and whenever nothing is
# tracked.

const PANEL_AUTOLOADS: Array[String] = [
	"InventoryPanel", "CharacterPanel", "CraftingPanel", "QuestPanel", "WorldMapPanel",
]

@onready var vbox: VBoxContainer = $VBox

func _ready() -> void:
	Quests.changed.connect(_refresh)
	Inventory.changed.connect(_refresh) # gather-objective progress depends on the backpack
	_refresh()

func _status_text(quest_id: String) -> String:
	var state: String = Quests.quest_state[quest_id]
	if state == "completed":
		return "Completed"
	if Quests.objective_met(quest_id):
		return "Ready to turn in!"
	return Quests.objective_progress_text(quest_id)

func _refresh() -> void:
	for child in vbox.get_children():
		child.queue_free()
	for quest_id in Quests.tracked_quests:
		var def: Dictionary = Quests.QUEST_DEFS[quest_id]

		var entry := Panel.new()
		# A plain Panel doesn't report its content's size upward the way a
		# Container does, so without this the parent VBoxContainer allocates
		# it ~0 height - the background collapses to invisible and entries
		# render crammed on top of each other.
		entry.custom_minimum_size = Vector2(0, 64)
		vbox.add_child(entry)

		var margin := MarginContainer.new()
		margin.set_anchors_preset(Control.PRESET_FULL_RECT)
		for side in ["left", "top", "right", "bottom"]:
			margin.add_theme_constant_override("margin_%s" % side, 10)
		entry.add_child(margin)

		var entry_vbox := VBoxContainer.new()
		entry_vbox.add_theme_constant_override("separation", 4)
		margin.add_child(entry_vbox)

		var name_label := Label.new()
		name_label.text = def.name
		name_label.theme_type_variation = &"PanelTitle"
		name_label.add_theme_font_size_override("font_size", 15)
		entry_vbox.add_child(name_label)

		var status_label := Label.new()
		status_label.text = _status_text(quest_id)
		status_label.add_theme_font_size_override("font_size", 13)
		entry_vbox.add_child(status_label)

func _process(_delta: float) -> void:
	var any_panel_open := false
	for autoload_name in PANEL_AUTOLOADS:
		if get_node("/root/%s" % autoload_name).is_open():
			any_panel_open = true
			break
	visible = not any_panel_open and not Combat.in_combat and not Quests.tracked_quests.is_empty()
