extends SceneTree
# Builds QuestTracker.tscn - the always-visible right-side overlay for
# tracked quests (see scripts/quest_tracker.gd for the visibility rules).
# Entry panels are built dynamically in _refresh(), same as every other
# panel's list rows - this just sets up the VBox they get added to.
# Run via: godot --headless --script res://tools/setup_quest_tracker.gd

func _build_quest_tracker() -> void:
	var layer := CanvasLayer.new()
	layer.name = "QuestTracker"
	layer.set_script(load("res://scripts/quest_tracker.gd"))

	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	# Right-aligned strip below the PanelButtons toolbar (which occupies
	# y 12-52), matching its 12px edge margin. Width 256 keeps entries
	# readable without eating too much of the play area. Both position AND
	# size must be set explicitly (not custom_minimum_size) - anchors_preset
	# leaves offset_right/bottom at stale values otherwise, producing a
	# degenerate (even negative-width) rect that rendered mid-screen instead
	# of along the right edge.
	vbox.position = Vector2(-268, 64)
	vbox.size = Vector2(256, 524)
	vbox.add_theme_constant_override("separation", 10)
	layer.add_child(vbox)
	vbox.owner = layer

	var packed := PackedScene.new()
	packed.pack(layer)
	var err := ResourceSaver.save(packed, "res://scenes/QuestTracker.tscn")
	print("QuestTracker.tscn saved: ", err)

func _initialize() -> void:
	print("=== Quest tracker setup starting ===")
	_build_quest_tracker()
	print("=== Setup complete ===")
	quit()
