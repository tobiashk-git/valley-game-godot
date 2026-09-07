extends SceneTree
# Journal quest-lines verification (revamp phase 2: the UI). Run via:
# godot --script res://tools/verify_quest_journal.gd (NOT --headless).
#
# The Journal tab has Story / Side sub-tabs. Story lists every chapter as
# a section with its state, its handed-out quests in chain order with a
# "Step i of n" tag, and the next step of a chain as soon as it can be
# picked up ("See the Village Elder"); a chapter with nothing yet shows its
# blurb. Side keeps Active / Available / Completed for side quests only.
# The pane names what a quest follows and leads on to; Track only for
# accepted quests. Both layouts fit their windows.

func _rows(view: Control) -> Array:
	var out: Array = []
	for child in view.quest_list.get_children():
		if child is Button and String(child.name).ends_with("Row") and not String(child.name).begins_with("Dying"):
			out.append(String(child.name))
	return out

func _sections(view: Control) -> Array:
	var out: Array = []
	for child in view.quest_list.get_children():
		if child is Label and child.theme_type_variation == &"PanelTitle" and not String(child.name).begins_with("Dying"):
			out.append(child.text)
	return out

func _initialize() -> void:
	var quests: Node = root.get_node("Quests")
	var game_state: Node = root.get_node("GameState")
	var inventory: Node = root.get_node("Inventory")
	var sheet: CanvasLayer = root.get_node("CharacterSheet")
	await process_frame
	game_state.reset()
	inventory.reset()
	root.get_node("Character").reset()
	quests.reset()
	var house: Node2D = load("res://scenes/House.tscn").instantiate()
	root.add_child(house)
	current_scene = house
	for i in range(3):
		await process_frame
	var view: Control = sheet.journal_view

	# A player mid-game: village done, Frostpeak ford done (hunt not yet
	# picked up), Verdantwood ford accepted, the Blacksmith's first step done.
	quests.quest_state.meet_villagers = "completed"
	quests.quest_state.gather_wood = "completed"
	quests.quest_state.cross_frostpeak = "completed"
	quests.quest_state.cross_verdantwood = "accepted"
	quests.quest_state.forge_whetstone = "completed"
	quests.quest_state.open_ancient_barrow = "accepted"
	sheet.open("journal")
	await process_frame
	await process_frame

	# --- Story tab ---
	print("Journal opens on the Story sub-tab with two line tabs: ", view.line_tab == "story" and view.has_node("LineTabs/StoryTab") and view.has_node("LineTabs/SideTab") and view.line_tabs.get_node("StoryTab").theme_type_variation == &"TabButtonActive")
	var sections: Array = _sections(view)
	print("Six chapter sections in order with their states (1 complete, 2 and 3 in progress, the rest untouched): ", sections.size() == 6 and sections[0] == "Chapter 1: The Valley  -  complete" and sections[1] == "Chapter 2: Frostpeak Ridge  -  in progress" and sections[2] == "Chapter 3: Verdantwood Forest  -  in progress" and sections[3] == "Chapter 4: Emberfall Badlands" and sections[5] == "Chapter 6: The Ancient Warden")
	var rows: Array = _rows(view)
	print("Rows in chapter and chain order, the Frostpeak hunt announced as the next step, no side quests here: ", rows == ["MeetVillagersRow", "GatherWoodRow", "CrossFrostpeakRow", "HuntFrostpeakRow", "CrossVerdantwoodRow"])
	var hunt_row: Button = view.quest_list.get_node("HuntFrostpeakRow")
	print("The announced step says where to get it and carries its step tag: ", hunt_row.get_node("Status").text == "See the Village Elder" and hunt_row.get_node("Step").text == "Step 2 of 2" and view.quest_list.get_node("CrossFrostpeakRow").get_node("Step").text == "Step 1 of 2")
	print("Untouched chapters show their blurb line: ", view.quest_list.get_children().any(func(c): return c is Label and String(c.text).strip_edges() == "Fires in the south."))
	print("The pane defaults to the active story quest (Clearing the Crossing), Track shown: ", view.selected_quest == "cross_verdantwood" and view.quest_name.text == "Clearing the Crossing" and view.track_btn.visible)
	view.select_quest("cross_frostpeak")
	await process_frame
	print("A finished ford's pane: Step 1 of 2, leads on to the now-known hunt, no Track: ", view.quest_giver.text == "From the Frostpeak Ranger\nStep 1 of 2  -  leads on to The Glacial Revenant" and not view.track_btn.visible)
	view.select_quest("hunt_frostpeak")
	await process_frame
	print("The announced hunt's pane: follows the ford, not yet accepted, goal from the Elder's brief: ", view.quest_giver.text.ends_with("Step 2 of 2  -  follows Reinforcing the Ford") and view.quest_progress.text.contains("Not yet accepted") and view.quest_goal.text.begins_with("Find the ice caves") and not view.track_btn.visible)
	view.select_quest("cross_verdantwood")
	await process_frame
	print("An open chain hides its next step's name until it can be picked up: ", view.quest_giver.text.ends_with("leads on to ..."))
	root.get_texture().get_image().save_png("res://verify_quest_journal_story.png")
	print("Saved verify_quest_journal_story.png")

	# --- Side tab ---
	view.line_tabs.get_node("SideTab").pressed.emit()
	await process_frame
	await process_frame
	sections = _sections(view)
	rows = _rows(view)
	print("Side tab: Active (the barrow), Available (Cold Iron, its first step done), Completed (A Keen Edge); nothing from the story: ", view.line_tab == "side" and sections == ["Active (1)", "Available (1)", "Completed (1)"] and rows == ["OpenAncientBarrowRow", "ForgeFrostRow", "ForgeWhetstoneRow"])
	print("Single-action side quest has no step tag; the chain's steps do: ", not view.quest_list.get_node("OpenAncientBarrowRow").has_node("Step") and view.quest_list.get_node("ForgeFrostRow").get_node("Step").text == "Step 2 of 2")
	view.select_quest("forge_frost")
	await process_frame
	print("Cold Iron's pane: follows A Keen Edge, see the Blacksmith: ", view.quest_giver.text == "From the Village Blacksmith\nStep 2 of 2  -  follows A Keen Edge" and view.quest_list.get_node("ForgeFrostRow").get_node("Status").text == "See the Village Blacksmith")
	root.get_texture().get_image().save_png("res://verify_quest_journal_side.png")
	print("Saved verify_quest_journal_side.png")
	view.line_tabs.get_node("StoryTab").pressed.emit()
	await process_frame
	print("Back on Story the selection returns to a story quest: ", view.line_tab == "story" and quests.line_of(view.selected_quest) == "story")

	# --- everything inside the window, both layouts ---
	var win: Rect2 = sheet.window.get_global_rect()
	var inside_wide: bool = win.encloses(view.detail_pane.get_global_rect()) and win.encloses(view.line_tabs.get_global_rect()) and view.track_btn.get_global_rect().end.y <= view.detail_pane.get_global_rect().end.y
	sheet.close()
	root.size = Vector2i(400, 860)
	for i in range(6):
		await process_frame
	sheet.open("journal")
	await process_frame
	await process_frame
	win = sheet.window.get_global_rect()
	var pane: Rect2 = view.detail_pane.get_global_rect()
	var inside_phone: bool = win.encloses(pane) and win.encloses(view.line_tabs.get_global_rect()) and view.list_scroll.get_global_rect().position.y >= view.line_tabs.get_global_rect().end.y and view.track_btn.get_global_rect().end.y <= pane.end.y
	print("Wide and phone: sub-tabs, list and pane inside the window, Track inside the pane: ", inside_wide and inside_phone)
	root.get_texture().get_image().save_png("res://verify_quest_journal_phone.png")
	print("Saved verify_quest_journal_phone.png")
	sheet.close()
	root.size = Vector2i(800, 600)
	for i in range(3):
		await process_frame
	quit()
