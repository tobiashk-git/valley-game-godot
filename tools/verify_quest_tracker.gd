extends SceneTree
# Verifies: auto-track on accept, auto-untrack on complete, the
# MAX_TRACKED=2 cap, manual Track/Tracking toggling, per-entry
# expand/collapse (including right-aligned collapsed text), and the
# overlay hiding whenever a panel or combat covers the screen. Run via:
# godot --script res://tools/verify_quest_tracker.gd (NOT --headless - this
# takes real screenshots via get_texture()).

# Journal rows are <PascalQuestId>Row buttons in the sheet's Journal tab.
func _find_row(list: VBoxContainer, quest_id: String) -> Button:
	return list.get_node_or_null(quest_id.to_pascal_case() + "Row")

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

	print("Nothing tracked at boot (the tutorial is handed out by the Elder now): ", quests.tracked_quests.is_empty() and not quests.quest_state.has("meet_villagers"))

	# --- Accepting a quest auto-tracks it (if there's room). Call the real
	# method (not a direct quest_state write) so the auto-track logic under
	# test actually runs, same as the dialogue's Accept button would. ---
	quests._accept_quest("meet_villagers")
	print("Accepting the tutorial tracks it: ", quests.tracked_quests == ["meet_villagers"])
	quests._accept_quest("gather_wood")
	print("Accepting auto-tracks it: ", quests.tracked_quests == ["meet_villagers", "gather_wood"])

	Input.action_press("toggle_quests")
	await process_frame
	Input.action_release("toggle_quests")
	await process_frame
	var journal: Control = root.get_node("CharacterSheet").journal_view
	var list: VBoxContainer = journal.quest_list

	var wood_row := _find_row(list, "gather_wood")
	var villagers_row := _find_row(list, "meet_villagers")
	print("Found both rows: ", wood_row != null and villagers_row != null)
	print("Both rows already marked tracked (auto-tracked): ", wood_row.get_node("Name").text.ends_with("(tracked)") and villagers_row.get_node("Name").text.ends_with("(tracked)"))

	# --- A 3rd track request at the cap is refused (both slots already
	# used by auto-tracking, not manual clicks this time). ---
	quests.toggle_track("some_other_quest")
	print("3rd quest refused at the cap: ", quests.tracked_quests.size() == 2 and not quests.tracked_quests.has("some_other_quest"))

	# --- Manual untrack via the Journal pane's Untrack button still works. ---
	villagers_row.pressed.emit()
	await process_frame
	print("Selecting the tracked quest offers Untrack: ", journal.selected_quest == "meet_villagers" and journal.track_btn.visible and journal.track_btn.text == "Untrack")
	journal.track_btn.pressed.emit()
	await process_frame
	print("Manual untrack works: ", quests.tracked_quests == ["gather_wood"])
	villagers_row = _find_row(list, "meet_villagers")
	print("Untracked quest now offers Track: ", journal.track_btn.text == "Track on screen" and not villagers_row.get_node("Name").text.ends_with("(tracked)"))
	journal.track_btn.pressed.emit() # re-track for the rest of this test
	await process_frame
	print("Manual re-track works: ", quests.tracked_quests == ["gather_wood", "meet_villagers"])
	wood_row = _find_row(list, "gather_wood")
	wood_row.pressed.emit()
	await process_frame
	print("Pane shows the selected quest's giver, goal, progress and reward: ", journal.quest_name.text == "A Village in Need" and journal.quest_giver.text == "From the Village Elder" and journal.quest_goal.text.begins_with("Gather 5") and journal.quest_progress.text.begins_with("Progress: 0/5") and journal.quest_reward.text == "Reward: 20 gold, 1 Healing Potion")
	root.get_texture().get_image().save_png("res://verify_quest_journal.png")
	print("Saved verify_quest_journal.png")

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
	var status_label: RichTextLabel = wood_entry.find_children("*", "RichTextLabel", true, false)[0]
	print("Tracked quest status updates live: ", status_label.text.contains("5/5") or status_label.text.contains("Ready"))

	# --- Completing a quest auto-untracks it and removes it from the
	# overlay, even though the Journal is currently closed. ---
	quests._complete_quest("gather_wood")
	await process_frame
	print("Completing auto-untracks it: ", not quests.tracked_quests.has("gather_wood"))
	print("Tracker shows 1 entry after auto-untrack: ", tracker.vbox.get_child_count() == 1)

	# --- Hidden while DialogueUI is open - its top-anchored box spans most
	# of the screen width, reaching into the tracker's own right-side
	# territory (real overlap seen in a screenshot before this guard existed). ---
	var dialogue_ui: Node = root.get_node("DialogueUI")
	dialogue_ui.show_dialogue("Test NPC", "Hello!")
	await process_frame
	print("Tracker hidden while DialogueUI is open: ", not tracker.visible)
	dialogue_ui.hide_dialogue()
	await process_frame
	print("Tracker visible again once DialogueUI closes: ", tracker.visible)

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
