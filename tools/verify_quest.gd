extends SceneTree

func _initialize() -> void:
	# The Elder stands on the village square (Overworld) now, not in his
	# house, and hands out the tutorial before the wood quest - complete the
	# tutorial by state here (verify_village_gates.gd covers it properly) so
	# this script tests the wood quest as before.
	var elder_house: Node2D = load("res://scenes/Overworld.tscn").instantiate()
	root.add_child(elder_house)
	current_scene = elder_house
	await process_frame
	await process_frame

	var inventory: Node = root.get_node("Inventory")
	var quests: Node = root.get_node("Quests")
	var dialogue_ui: Node = root.get_node("DialogueUI")
	var quest_panel: Node = root.get_node("QuestPanel")
	var player: CharacterBody2D = elder_house.get_node("YSort/Player")
	quests.quest_state["meet_villagers"] = "completed"
	quests.changed.emit()

	var ysort: Node2D = elder_house.get_node("YSort")
	var elder: Node = null
	for child in ysort.get_children():
		if child.get("npc_id") == "village_elder":
			elder = child
	print("Elder NPC found on the village square: ", elder != null and elder.active_quest() == "gather_wood")

	player.position = elder.position + Vector2(0, 20)
	player.get_node("Camera2D").reset_smoothing()
	for i in range(3):
		await process_frame

	# --- Dismiss the one-time intro (village fence/gates tutorial) first -
	# the quest offer is the *second* interaction now, not the first. ---
	Input.action_press("interact")
	await process_frame
	await process_frame
	Input.action_release("interact")
	await process_frame
	print("Intro shown first: ", dialogue_ui.text_label.text.begins_with("Ah, a new face"))
	Input.action_press("interact")
	await process_frame
	Input.action_release("interact")
	await process_frame

	# --- First contact with the quest offer: Accept/Not now. ---
	Input.action_press("interact")
	await process_frame
	await process_frame
	Input.action_release("interact")
	await process_frame
	print("Dialogue open: ", dialogue_ui.is_open())
	print("Offer text shown: ", dialogue_ui.text_label.text.begins_with("Traveler!"))
	var actions: Array = dialogue_ui.actions_row.get_children()
	print("Offer has 2 buttons: ", actions.size() == 2)
	var row_rect: Rect2 = dialogue_ui.actions_row.get_global_rect()
	var accept_rect: Rect2 = (actions[0] as Button).get_global_rect()
	var decline_rect: Rect2 = (actions[1] as Button).get_global_rect()
	print("Accept is the big gold button at the left edge, Not now the secondary at the right edge: ", (actions[0] as Button).theme_type_variation == &"PrimaryButton" and (actions[1] as Button).theme_type_variation == &"SecondaryButton" and accept_rect.size.y >= 44.0 and absf(accept_rect.position.x - row_rect.position.x) < 1.0 and absf(decline_rect.end.x - row_rect.end.x) < 1.0 and decline_rect.position.x - accept_rect.end.x > 40.0)
	var panel_rect: Rect2 = dialogue_ui.panel.get_global_rect()
	print("Dialogue box fits its text and buttons: ", dialogue_ui.text_label.get_global_rect().end.y <= panel_rect.end.y and decline_rect.end.y <= panel_rect.end.y - 4.0)
	print("Quest not yet accepted: ", not quests.quest_state.has("gather_wood"))
	root.get_texture().get_image().save_png("res://verify_quest_offer.png")

	# --- Decline: "Not now" should leave state untouched. ---
	var not_now_btn: Button = actions[1]
	print("Second button label: ", not_now_btn.text)
	not_now_btn.pressed.emit()
	await process_frame
	print("Dialogue closed after declining: ", not dialogue_ui.is_open())
	print("Still not accepted after declining: ", not quests.quest_state.has("gather_wood"))

	# --- Talk again, this time Accept. ---
	Input.action_press("interact")
	await process_frame
	await process_frame
	Input.action_release("interact")
	await process_frame
	var accept_btn: Button = dialogue_ui.actions_row.get_children()[0]
	print("First button label: ", accept_btn.text)
	accept_btn.pressed.emit()
	await process_frame
	print("Quest accepted: ", quests.quest_state.get("gather_wood", "") == "accepted")

	# --- Journal shows live progress (0/5 Wood). ---
	Input.action_press("toggle_quests")
	await process_frame
	Input.action_release("toggle_quests")
	await process_frame
	# The Journal is the sheet's Journal tab now: one row per quest, named
	# <PascalQuestId>Row, with a Name label and a Status line.
	var journal: Control = root.get_node("CharacterSheet").journal_view
	var wood_row: Button = journal.quest_list.get_node("GatherWoodRow")
	print("Journal row: ", wood_row.get_node("Name").text, " - ", wood_row.get_node("Status").text)
	print("Journal opened on the tab with the row's live progress: ", quest_panel.is_open() and wood_row.get_node("Status").text.begins_with("0/5"))
	Input.action_press("toggle_quests")
	await process_frame
	Input.action_release("toggle_quests")
	await process_frame

	# --- Talk with insufficient wood: in-progress line, no buttons. ---
	Input.action_press("interact")
	await process_frame
	await process_frame
	Input.action_release("interact")
	await process_frame
	print("In-progress text shows 0/5: ", dialogue_ui.text_label.text.contains("0/5") and dialogue_ui.text_label.text.contains("Wood"))
	print("No buttons while short on materials: ", dialogue_ui.actions_row.get_children().is_empty())
	Input.action_press("interact") # close
	await process_frame
	Input.action_release("interact")
	await process_frame

	# --- Gather enough wood, talk again: ready to turn in. ---
	inventory.add_item("wood", 5)
	Input.action_press("interact")
	await process_frame
	await process_frame
	Input.action_release("interact")
	await process_frame
	print("Ready text shown: ", dialogue_ui.text_label.text.begins_with("Wonderful"))
	var ready_actions: Array = dialogue_ui.actions_row.get_children()
	print("Ready has Turn In + Not yet: ", ready_actions.size() == 2 and ready_actions[0].text == "Turn In")
	root.get_texture().get_image().save_png("res://verify_quest_ready.png")

	# --- Turn in: wood deducted, reward granted, quest completed. ---
	var gold_before: int = inventory.get_count("gold")
	var potions_before: int = inventory.get_count("healing_potion")
	var character: Node = root.get_node("Character")
	var xp_before: int = character.stats.xp + (character.stats.level - 1) * 1000
	ready_actions[0].pressed.emit()
	await process_frame
	print("Wood deducted after turn-in: ", inventory.get_count("wood") == 0)
	var xp_after: int = character.stats.xp + (character.stats.level - 1) * 1000
	print("Quest XP granted (40 - more than a fight's worth; a level may have turned): ", xp_after - xp_before == 40 or (character.stats.level == 2 and character.stats.xp + 60 - xp_before == 40))
	var rewards_have_xp := true
	for qid in quests.QUEST_DEFS.keys():
		if quests.QUEST_DEFS[qid].get("reward", {}).get("xp", 0) <= 0:
			rewards_have_xp = false
	print("Every quest pays XP, the ford quests 120-210, the tutorial 20: ", rewards_have_xp and quests.QUEST_DEFS.cross_frostpeak.reward.xp == 120 and quests.QUEST_DEFS.cross_gloomfen.reward.xp == 210 and quests.QUEST_DEFS.meet_villagers.reward.xp == 20)
	print("Gold granted: ", inventory.get_count("gold") == gold_before + 20)
	print("Healing potion granted: ", inventory.get_count("healing_potion") == potions_before + 1)
	print("Quest marked completed: ", quests.quest_state.get("gather_wood", "") == "completed")

	# --- Talk again: plain completed line, no buttons. ---
	Input.action_press("interact")
	await process_frame
	await process_frame
	Input.action_release("interact")
	await process_frame
	print("Completed text shown: ", dialogue_ui.text_label.text.begins_with("Thanks again"))
	print("No buttons on completed dialogue: ", dialogue_ui.actions_row.get_children().is_empty())
	Input.action_press("interact")
	await process_frame
	Input.action_release("interact")
	await process_frame
	print("Dialogue closes normally via E: ", not dialogue_ui.is_open())

	# --- Journal moves it to the Completed section: bare name (no status
	# suffix - the section header already says "Completed"), and no Track
	# button since a completed quest can't be tracked. ---
	Input.action_press("toggle_quests")
	await process_frame
	Input.action_release("toggle_quests")
	await process_frame
	var done_row: Button = journal.quest_list.get_node("GatherWoodRow")
	var completed_header_index := -1
	for child in journal.quest_list.get_children():
		if child is Label and child.text.begins_with("Completed"):
			completed_header_index = child.get_index()
	print("Journal shows it under Completed (status 'Completed', not tracked): ", done_row.get_node("Status").text == "Completed" and completed_header_index >= 0 and done_row.get_index() > completed_header_index and not done_row.get_node("Name").text.ends_with("(tracked)"))
	done_row.pressed.emit()
	await process_frame
	print("Completed quest has no Track button in the pane: ", journal.selected_quest == "gather_wood" and not journal.track_btn.visible and journal.quest_progress.text.contains("Completed"))
	print("Completing untracked it: ", not quests.tracked_quests.has("gather_wood"))
	root.get_texture().get_image().save_png("res://verify_quest_journal_done.png")

	quit()
