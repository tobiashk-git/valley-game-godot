extends CanvasLayer
# Autoload — toggled with the "toggle_quests" action (Q key). Lists every
# quest present in Quests.quest_state (not-yet-offered quests don't show)
# with a live status/progress line - port of quests.js's Journal panel. Each
# row also has a Track button pinning it to the always-visible QuestTracker
# overlay (see quest_tracker.gd), disabled once Quests.MAX_TRACKED is hit.

@onready var panel: Panel = $Panel
@onready var list: VBoxContainer = $Panel/Margin/VBox/List

func _ready() -> void:
	panel.visible = false
	Quests.changed.connect(_refresh)
	Inventory.changed.connect(_refresh) # gather-objective progress depends on the backpack

func _status_text(quest_id: String) -> String:
	var state: String = Quests.quest_state[quest_id]
	if state == "completed":
		return "Completed"
	if Quests.objective_met(quest_id):
		return "Ready to turn in!"
	return Quests.objective_progress_text(quest_id)

func _refresh() -> void:
	for child in list.get_children():
		child.queue_free()
	if Quests.quest_state.is_empty():
		var empty_label := Label.new()
		empty_label.text = "(no quests yet)"
		empty_label.theme_type_variation = &"DimLabel"
		list.add_child(empty_label)
		return
	for quest_id in Quests.quest_state.keys():
		var def: Dictionary = Quests.QUEST_DEFS[quest_id]

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		list.add_child(row)

		var label := Label.new()
		label.text = "%s - %s" % [def.name, _status_text(quest_id)]
		label.add_theme_font_size_override("font_size", 15)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)

		var tracked: bool = Quests.is_tracked(quest_id)
		var track_btn := Button.new()
		track_btn.text = "Tracking" if tracked else "Track"
		track_btn.disabled = not tracked and Quests.tracked_quests.size() >= Quests.MAX_TRACKED
		track_btn.pressed.connect(_on_track_pressed.bind(quest_id))
		row.add_child(track_btn)

func _on_track_pressed(quest_id: String) -> void:
	Quests.toggle_track(quest_id)

func is_open() -> bool:
	return panel.visible

func open() -> void:
	panel.visible = true
	_refresh()

func close() -> void:
	panel.visible = false

func toggle_open() -> void:
	if panel.visible:
		close()
	else:
		open()

func _process(_delta: float) -> void:
	if not Combat.in_combat and Input.is_action_just_pressed("toggle_quests"):
		toggle_open()
