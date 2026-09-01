extends SceneTree
# Verifies: Track/Tracking toggle in the Journal, the MAX_TRACKED=2 cap,
# the QuestTracker overlay showing the right entries with live status, and
# it hiding whenever a panel or combat covers the screen. Run via:
# godot --script res://tools/verify_quest_tracker.gd (NOT --headless - this
# takes real screenshots via get_texture()).

func _find_row(list: VBoxContainer, name_prefix: String) -> HBoxContainer:
	for row in list.get_children():
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

	# Only 2 real quests exist (gather_wood, meet_villagers - QUEST_DEFS is a
	# read-only const, can't inject a 3rd for this test) which conveniently
	# matches MAX_TRACKED exactly, so tracking both already exercises the cap.
	quests.quest_state["gather_wood"] = "accepted"

	Input.action_press("toggle_quests")
	await process_frame
	Input.action_release("toggle_quests")
	await process_frame
	var list: VBoxContainer = quest_panel.get_node("Panel/Margin/VBox/List")

	var wood_row := _find_row(list, "A Village in Need")
	var villagers_row := _find_row(list, "Meet the Village")
	print("Found both rows: ", wood_row != null and villagers_row != null)

	var wood_track_btn: Button = wood_row.get_child(1)
	var villagers_track_btn: Button = villagers_row.get_child(1)
	print("Track buttons start enabled: ", not wood_track_btn.disabled and not villagers_track_btn.disabled)

	# --- Track both quests, hitting the cap. Each click triggers a full
	# row rebuild (Quests.changed -> _refresh()), which frees the other
	# row's captured Button - re-fetch after each click before using it. ---
	wood_track_btn.pressed.emit()
	await process_frame
	list = quest_panel.get_node("Panel/Margin/VBox/List")
	villagers_row = _find_row(list, "Meet the Village")
	villagers_track_btn = villagers_row.get_child(1)
	villagers_track_btn.pressed.emit()
	await process_frame
	print("2 quests tracked: ", quests.tracked_quests == ["gather_wood", "meet_villagers"])

	list = quest_panel.get_node("Panel/Margin/VBox/List") # re-fetch after _refresh() rebuilt rows
	wood_row = _find_row(list, "A Village in Need")
	print("Tracked row now says 'Tracking': ", (wood_row.get_child(1) as Button).text == "Tracking")

	# --- A 3rd track request at the cap is refused (no UI to click - only
	# 2 real quests exist - so this checks the Quests API directly). ---
	quests.toggle_track("some_other_quest")
	print("3rd quest refused at the cap: ", quests.tracked_quests.size() == 2 and not quests.tracked_quests.has("some_other_quest"))

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

	# --- Each entry's own collapse/expand toggle. ---
	var wood_entry_expanded: Panel = tracker.vbox.get_child(0)
	print("First entry starts expanded (boxed): ", wood_entry_expanded is Panel)
	# owned=false - built at runtime with no .owner set, same as everywhere else.
	var collapse_btn: Button = wood_entry_expanded.find_children("*", "Button", true, false)[0]
	print("Expanded entry's toggle reads collapse (▾): ", collapse_btn.text == "▾")
	collapse_btn.pressed.emit()
	await process_frame
	var wood_entry_collapsed: Control = tracker.vbox.get_child(0)
	print("Collapsing drops the box (no Panel, just a margin-wrapped row): ", wood_entry_collapsed is MarginContainer)
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
	# owned=false - the entry's Labels are built at runtime with no .owner
	# set (same convention as every other panel's dynamic list rows).
	var status_label: Label = wood_entry.find_children("*", "Label", true, false)[1]
	print("Tracked quest status updates live: ", status_label.text.contains("5/5") or status_label.text.contains("Ready"))

	# --- Untracking removes it from the overlay. ---
	Input.action_press("toggle_quests")
	await process_frame
	Input.action_release("toggle_quests")
	await process_frame
	list = quest_panel.get_node("Panel/Margin/VBox/List")
	wood_row = _find_row(list, "A Village in Need")
	(wood_row.get_child(1) as Button).pressed.emit()
	await process_frame
	print("Untracked quest count: ", quests.tracked_quests.size() == 1)
	Input.action_press("toggle_quests")
	await process_frame
	Input.action_release("toggle_quests")
	await process_frame
	await process_frame
	print("Tracker shows 1 entry after untracking: ", tracker.vbox.get_child_count() == 1)

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
