extends SceneTree

func _initialize() -> void:
	var elder_scene: PackedScene = load("res://scenes/ElderHouse.tscn")
	var elder_house: Node2D = elder_scene.instantiate()
	root.add_child(elder_house)
	current_scene = elder_house
	await process_frame
	await process_frame

	var inventory: Node = root.get_node("Inventory")
	var quests: Node = root.get_node("Quests")
	var dialogue_ui: Node = root.get_node("DialogueUI")
	var quest_panel: Node = root.get_node("QuestPanel")
	var player: CharacterBody2D = elder_house.get_node("YSort/Player")

	var ysort: Node2D = elder_house.get_node("YSort")
	var elder: Node = null
	for child in ysort.get_children():
		if child.name.begins_with("NPC"):
			elder = child
	print("Elder NPC found: ", elder != null)

	player.position = elder.position + Vector2(0, 20)
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
	var journal_list: VBoxContainer = quest_panel.get_node("Panel/Margin/VBox/List")
	# meet_villagers (the fence/gates tutorial quest) is pre-accepted from
	# boot too, so it shares the Journal now - find the gather_wood row by
	# name rather than assuming an index.
	var wood_quest_row: Label = null
	for row in journal_list.get_children():
		if row.text.begins_with("A Village in Need"):
			wood_quest_row = row
	print("Journal row: ", wood_quest_row.text)
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
	print("In-progress text shows 0/5: ", dialogue_ui.text_label.text.contains("0/5 Wood"))
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
	ready_actions[0].pressed.emit()
	await process_frame
	print("Wood deducted after turn-in: ", inventory.get_count("wood") == 0)
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

	# --- Journal shows Completed. ---
	Input.action_press("toggle_quests")
	await process_frame
	Input.action_release("toggle_quests")
	await process_frame
	for row in journal_list.get_children():
		if row.text.begins_with("A Village in Need"):
			wood_quest_row = row
	print("Journal shows Completed: ", wood_quest_row.text.ends_with("Completed"))
	root.get_texture().get_image().save_png("res://verify_quest_journal_done.png")

	quit()
