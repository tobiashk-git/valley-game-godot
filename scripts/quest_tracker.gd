extends CanvasLayer
# Autoload — persistent overlay down the right side of the screen showing
# live status for up to Quests.MAX_TRACKED quests pinned via the Journal's
# Track button, so progress is visible during normal play without opening
# the panel. Hidden whenever any of the 5 toggleable panels, DialogueUI (its
# top-anchored box spans most of the screen width, reaching into this
# overlay's own right-side territory), or the battle screen are open (they'd
# otherwise overlap it), and whenever nothing is tracked.
#
# Each entry has its own expand/collapse toggle (▾/▸ on the right of the
# name) - expanded shows the full boxed panel with progress text, collapsed
# drops the box and shows just the name, for a less obtrusive overlay when
# you don't need the detail. Purely a display choice, local to this UI -
# doesn't touch Quests.tracked_quests or anything else.

const PANEL_AUTOLOADS: Array[String] = [
	"InventoryPanel", "CharacterPanel", "CraftingPanel", "QuestPanel", "WorldMapPanel",
]

@onready var vbox: VBoxContainer = $VBox

# quest_id -> bool, missing = expanded (the default look before this existed).
var expanded_state: Dictionary = {}

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

func _on_toggle_expand(quest_id: String) -> void:
	expanded_state[quest_id] = not expanded_state.get(quest_id, true)
	_refresh()

func _build_header(quest_id: String, def: Dictionary, is_expanded: bool) -> HBoxContainer:
	var header := HBoxContainer.new()

	var name_label := Label.new()
	name_label.text = def.name
	name_label.theme_type_variation = &"PanelTitle"
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Collapsed (no box) reads better hugging the toggle button on the right
	# rather than sticking out from the left edge with a gap of empty space
	# before it - the boxed layout keeps the default left alignment, which
	# already reads fine against its background.
	if not is_expanded:
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(name_label)

	var toggle_btn := Button.new()
	toggle_btn.text = "▾" if is_expanded else "▸" # ▾ collapse / ▸ expand
	toggle_btn.tooltip_text = "Collapse" if is_expanded else "Expand"
	toggle_btn.custom_minimum_size = Vector2(28, 0)
	toggle_btn.pressed.connect(_on_toggle_expand.bind(quest_id))
	header.add_child(toggle_btn)

	return header

func _refresh() -> void:
	for child in vbox.get_children():
		child.queue_free()
	for quest_id in Quests.tracked_quests:
		var def: Dictionary = Quests.QUEST_DEFS[quest_id]
		var is_expanded: bool = expanded_state.get(quest_id, true)

		if not is_expanded:
			# Same 10px margin as the boxed layout below (just with no Panel
			# background to draw) - without it the toggle button sits flush
			# against the screen's right edge instead of comfortably inset.
			var collapsed_margin := MarginContainer.new()
			for side in ["left", "top", "right", "bottom"]:
				collapsed_margin.add_theme_constant_override("margin_%s" % side, 10)
			collapsed_margin.add_child(_build_header(quest_id, def, false))
			vbox.add_child(collapsed_margin)
			continue

		var entry := Panel.new()
		# A plain Panel doesn't report its content's size upward the way a
		# Container does, so without this the parent VBoxContainer allocates
		# it ~0 height - the background collapses to invisible and entries
		# render crammed on top of each other.
		entry.custom_minimum_size = Vector2(0, 72)
		vbox.add_child(entry)

		var margin := MarginContainer.new()
		margin.set_anchors_preset(Control.PRESET_FULL_RECT)
		for side in ["left", "top", "right", "bottom"]:
			margin.add_theme_constant_override("margin_%s" % side, 10)
		entry.add_child(margin)

		var entry_vbox := VBoxContainer.new()
		entry_vbox.add_theme_constant_override("separation", 4)
		margin.add_child(entry_vbox)

		entry_vbox.add_child(_build_header(quest_id, def, true))

		# RichTextLabel (not Label) - status text can embed an inline item
		# icon via BBCode (see Quests.objective_progress_text()).
		var status_label := RichTextLabel.new()
		status_label.bbcode_enabled = true
		status_label.fit_content = true
		status_label.scroll_active = false
		status_label.text = _status_text(quest_id)
		status_label.add_theme_font_size_override("normal_font_size", 13)
		entry_vbox.add_child(status_label)

func _process(_delta: float) -> void:
	var any_panel_open: bool = get_node("/root/DialogueUI").is_open()
	if not any_panel_open:
		for autoload_name in PANEL_AUTOLOADS:
			if get_node("/root/%s" % autoload_name).is_open():
				any_panel_open = true
				break
	visible = not any_panel_open and not Combat.in_combat and not Quests.tracked_quests.is_empty()
