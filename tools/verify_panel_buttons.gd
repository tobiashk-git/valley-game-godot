extends SceneTree
# Toolbar (PanelButtons) verification. Inventory, Character and Crafting are
# tabs of the CharacterSheet window (UI redesign Phases 1-2); Journal/Map
# are still standalone panels. Run via:
# godot --script res://tools/verify_panel_buttons.gd (NOT --headless).

func _initialize() -> void:
	var overworld_scene: PackedScene = load("res://scenes/Overworld.tscn")
	var overworld: Node2D = overworld_scene.instantiate()
	root.add_child(overworld)
	current_scene = overworld
	await process_frame
	await process_frame

	var combat: Node = root.get_node("Combat")
	var panel_buttons: Node = root.get_node("PanelButtons")
	var sheet: Node = root.get_node("CharacterSheet")
	var quest_panel: Node = root.get_node("QuestPanel")
	var world_map_panel: Node = root.get_node("WorldMapPanel")

	root.get_texture().get_image().save_png("res://verify_panel_buttons_toolbar.png")

	# --- Click each button, confirm the right screen opens and others don't. ---
	panel_buttons.inventory_btn.pressed.emit()
	await process_frame
	print("Inventory opens via toolbar click (sheet, Inventory tab): ", sheet.is_open() and sheet.current_tab == "inventory")
	root.get_texture().get_image().save_png("res://verify_panel_buttons_inventory.png")
	panel_buttons.inventory_btn.pressed.emit()
	await process_frame

	panel_buttons.character_btn.pressed.emit()
	await process_frame
	print("Character opens via toolbar click (sheet, Character tab): ", sheet.is_open() and sheet.current_tab == "character")
	panel_buttons.character_btn.pressed.emit()
	await process_frame

	panel_buttons.crafting_btn.pressed.emit()
	await process_frame
	print("Crafting opens via toolbar click (sheet, Crafting tab): ", sheet.is_open() and sheet.current_tab == "crafting")
	panel_buttons.crafting_btn.pressed.emit()
	await process_frame

	panel_buttons.quest_btn.pressed.emit()
	await process_frame
	print("Journal opens via toolbar click: ", quest_panel.get_node("Panel").visible)
	panel_buttons.quest_btn.pressed.emit()
	await process_frame

	panel_buttons.map_btn.pressed.emit()
	await process_frame
	print("World Map opens via toolbar click (sheet, Map tab): ", world_map_panel.is_open() and sheet.is_open() and sheet.current_tab == "map")
	panel_buttons.map_btn.pressed.emit()
	await process_frame

	# --- Switching screens closes the previous one instead of stacking. ---
	panel_buttons.quest_btn.pressed.emit()
	await process_frame
	panel_buttons.inventory_btn.pressed.emit()
	await process_frame
	print("Switching to Inventory closes the Journal: ", sheet.is_open() and not quest_panel.get_node("Panel").visible)

	# --- The other sheet tabs' buttons switch tabs rather than closing. ---
	panel_buttons.character_btn.pressed.emit()
	await process_frame
	print("Character button while Inventory is open switches tab: ", sheet.is_open() and sheet.current_tab == "character")
	panel_buttons.crafting_btn.pressed.emit()
	await process_frame
	print("Crafting button while Character is open switches tab: ", sheet.is_open() and sheet.current_tab == "crafting")

	# --- Clicking the open tab's button just closes it. ---
	panel_buttons.crafting_btn.pressed.emit()
	await process_frame
	print("Re-clicking the open tab's button closes the sheet: ", not sheet.is_open())

	# --- Keyboard shortcuts still work too (regression check on the refactor). ---
	Input.action_press("toggle_inventory")
	await process_frame
	Input.action_release("toggle_inventory")
	await process_frame
	print("Keyboard I still opens Inventory (regression check): ", sheet.is_open() and sheet.current_tab == "inventory")
	Input.action_press("toggle_crafting")
	await process_frame
	Input.action_release("toggle_crafting")
	await process_frame
	print("Keyboard R switches to the Crafting tab: ", sheet.is_open() and sheet.current_tab == "crafting")
	Input.action_press("toggle_crafting")
	await process_frame
	Input.action_release("toggle_crafting")
	await process_frame
	print("Keyboard R again closes it: ", not sheet.is_open())

	# --- Blocked during combat, same as the keyboard shortcuts. ---
	combat.start_combat("dungeon_rat")
	await process_frame
	panel_buttons.inventory_btn.pressed.emit()
	await process_frame
	print("Toolbar button blocked during combat: ", not sheet.is_open())
	combat.player_run()
	await process_frame

	quit()
