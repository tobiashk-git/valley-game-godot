extends SceneTree
# Verifies: auto-track on accept, auto-untrack on complete, the
# MAX_TRACKED=2 cap, manual Track/Tracking toggling, per-entry
# expand/collapse (including right-aligned collapsed text), and the
# overlay hiding whenever a panel or combat covers the screen. Run via:
# godot --script res://tools/verify_quest_tracker.gd (NOT --headless - this
# takes real screenshots via get_texture()).

func _find_row(list: VBoxContainer, name_prefix: String) -> HBoxContainer:
	for row in list.get_children():
		if not row is HBoxContainer: # skip "Active"/"Completed" section headers
			continue
		var label: Label = row.get_child(0)
		if label.text.begins_with(name_prefix):
			return row
	return null

func _initialize() -> void:
	var overworld_scene: PackedScene = load("res://scenes/Overworld.tscn")
	var overworld: Node2D = overworld_scene.instantiate()
	root.add_child(overworld)
	current_scene = overworld
	await process_frame
	await process_frame

	var quests: Node = root.get_node("Quests")
	var inventory: Node = root.get_node("Inventory")
	var combat: Node = root.get_node("Combat")
	var quest_panel: Node = root.get_node("QuestPanel")
	var tracker: Node = root.get_node("QuestTracker")

	print("meet_villagers auto-tracked from boot: ", quests.tracked_quests == ["meet_villagers"])

	# --- Accepting a quest auto-tracks it (if there's room). Call the real
	# method (not a direct quest_state write) so the auto-track logic under
	# test actually runs, same as the dialogue's Accept button would. ---
	quests._accept_quest("gather_wood")
	print("Accepting auto-tracks it: ", quests.tracked_quests == ["meet_villagers", "gather_wood"])

	Input.action_press("toggle_quests")
	await process_frame
	Input.action_release("toggle_quests")
	await process_frame
	var list: VBoxContainer = quest_panel.get_node("Panel/Margin/VBox/List")

	var wood_row := _find_row(list, "A Village in Need")
	var villagers_row := _find_row(list, "Meet the Village")
	print("Found both rows: ", wood_row != null and villagers_row != null)
	print("Both rows already read 'Tracking' (auto-tracked): ", (wood_row.get_child(1) as Button).text == "Tracking" and (villagers_row.get_child(1) as Button).text == "Tracking")

	# --- A 3rd track request at the cap is refused (both slots already
	# used by auto-tracking, not manual clicks this time). ---
	quests.toggle_track("some_other_quest")
	print("3rd quest refused at the cap: ", quests.tracked_quests.size() == 2 and not quests.tracked_quests.has("some_other_quest"))

	# --- Manual untrack via the Journal's Tracking button still works. ---
	(villagers_row.get_child(1) as Button).pressed.emit()
	await process_frame
	print("Manual untrack works: ", quests.tracked_quests == ["gather_wood"])
	list = quest_panel.get_node("Panel/Margin/VBox/List")
	villagers_row = _find_row(list, "Meet the Village")
	print("Untracked row now reads 'Track': ", (villagers_row.get_child(1) as Button).text == "Track")
	(villagers_row.get_child(1) as Button).pressed.emit() # re-track for the rest of this test
	await process_frame
	print("Manual re-track works: ", quests.tracked_quests == ["gather_wood", "meet_villagers"])

	# --- Tracker hidden while the Journal itself is open. ---
	await process_frame
	print("Tracker hidden while Journal is open: ", not tracker.visible)

	Input.action_press("toggle_quests")
	await process_frame
	Input.action_release("toggle_quests")
	await process_frame
	await process_frame
	print("Tracker visible once Journal closes: ", tracker.visible)
	print("Tracker shows 2 entries: ", tracker.vbox.get_child_count() == 2)
	root.get_texture().get_image().save_png("res://verify_quest_tracker_overlay.png")

	# --- Each entry's own collapse/expand toggle, including alignment. ---
	var wood_entry_expanded: Panel = tracker.vbox.get_child(0)
	print("First entry starts expanded (boxed): ", wood_entry_expanded is Panel)
	var expanded_name_label: Label = wood_entry_expanded.find_children("*", "Label", true, false)[0]
	print("Expanded name is left-aligned (default): ", expanded_name_label.horizontal_alignment == HORIZONTAL_ALIGNMENT_LEFT)
	# owned=false - built at runtime with no .owner set, same as everywhere else.
	var collapse_btn: Button = wood_entry_expanded.find_children("*", "Button", true, false)[0]
	print("Expanded entry's toggle reads collapse (▾): ", collapse_btn.text == "▾")
	collapse_btn.pressed.emit()
	await process_frame
	var wood_entry_collapsed: Control = tracker.vbox.get_child(0)
	print("Collapsing drops the box (no Panel, just a margin-wrapped row): ", wood_entry_collapsed is MarginContainer)
	var collapsed_name_label: Label = wood_entry_collapsed.find_children("*", "Label", true, false)[0]
	print("Collapsed name is right-aligned: ", collapsed_name_label.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT)
	print("Other entry (Meet the Village) still boxed: ", tracker.vbox.get_child(1) is Panel)
	var expand_btn: Button = wood_entry_collapsed.get_child(0).get_child(1)
	print("Collapsed entry's toggle reads expand (▸): ", expand_btn.text == "▸")
	root.get_texture().get_image().save_png("res://verify_quest_tracker_collapsed.png")
	expand_btn.pressed.emit()
	await process_frame
	print("Expanding restores the box: ", tracker.vbox.get_child(0) is Panel)

	# --- Live status updates without opening the Journal. ---
	inventory.add_item("wood", 5)
	await process_frame
	var wood_entry: Panel = tracker.vbox.get_child(0)
	var status_label: Label = wood_entry.find_children("*", "Label", true, false)[1]
	print("Tracked quest status updates live: ", status_label.text.contains("5/5") or status_label.text.contains("Ready"))

	# --- Completing a quest auto-untracks it and removes it from the
	# overlay, even though the Journal is currently closed. ---
	quests._complete_quest("gather_wood")
	await process_frame
	print("Completing auto-untracks it: ", not quests.tracked_quests.has("gather_wood"))
	print("Tracker shows 1 entry after auto-untrack: ", tracker.vbox.get_child_count() == 1)

	# --- Hidden while another panel (Inventory) is open. ---
	Input.action_press("toggle_inventory")
	await process_frame
	Input.action_release("toggle_inventory")
	await process_frame
	await process_frame
	print("Tracker hidden while Inventory is open: ", not tracker.visible)
	Input.action_press("toggle_inventory")
	await process_frame
	Input.action_release("toggle_inventory")
	await process_frame
	await process_frame
	print("Tracker visible again once Inventory closes: ", tracker.visible)

	# --- Hidden during combat. ---
	combat.start_combat("dungeon_rat")
	await process_frame
	print("Tracker hidden during combat: ", not tracker.visible)
	combat.player_run()
	await process_frame
	await process_frame
	print("Tracker visible again after combat ends: ", tracker.visible)

	quit()
