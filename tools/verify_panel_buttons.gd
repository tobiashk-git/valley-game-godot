extends SceneTree

func _initialize() -> void:
	var overworld_scene: PackedScene = load("res://scenes/Overworld.tscn")
	var overworld: Node2D = overworld_scene.instantiate()
	root.add_child(overworld)
	current_scene = overworld
	await process_frame
	await process_frame

	var combat: Node = root.get_node("Combat")
	var panel_buttons: Node = root.get_node("PanelButtons")
	var inventory_panel: Node = root.get_node("InventoryPanel")
	var character_panel: Node = root.get_node("CharacterPanel")
	var crafting_panel: Node = root.get_node("CraftingPanel")
	var quest_panel: Node = root.get_node("QuestPanel")
	var world_map_panel: Node = root.get_node("WorldMapPanel")

	root.get_texture().get_image().save_png("res://verify_panel_buttons_toolbar.png")

	# --- Click each button, confirm the right panel opens and others don't. ---
	panel_buttons.inventory_btn.pressed.emit()
	await process_frame
	print("Inventory opens via toolbar click: ", inventory_panel.get_node("Panel").visible)
	root.get_texture().get_image().save_png("res://verify_panel_buttons_inventory.png")
	panel_buttons.inventory_btn.pressed.emit()
	await process_frame

	panel_buttons.character_btn.pressed.emit()
	await process_frame
	print("Character opens via toolbar click: ", character_panel.get_node("Panel").visible)
	panel_buttons.character_btn.pressed.emit()
	await process_frame

	panel_buttons.crafting_btn.pressed.emit()
	await process_frame
	print("Crafting opens via toolbar click: ", crafting_panel.get_node("Panel").visible)
	panel_buttons.crafting_btn.pressed.emit()
	await process_frame

	panel_buttons.quest_btn.pressed.emit()
	await process_frame
	print("Journal opens via toolbar click: ", quest_panel.get_node("Panel").visible)
	panel_buttons.quest_btn.pressed.emit()
	await process_frame

	panel_buttons.map_btn.pressed.emit()
	await process_frame
	print("World Map opens via toolbar click: ", world_map_panel.get_node("Panel").visible)
	panel_buttons.map_btn.pressed.emit()
	await process_frame

	# --- Switching panels closes the previous one instead of stacking. ---
	panel_buttons.crafting_btn.pressed.emit()
	await process_frame
	panel_buttons.inventory_btn.pressed.emit()
	await process_frame
	print("Switching to Inventory closes Crafting: ", inventory_panel.get_node("Panel").visible and not crafting_panel.get_node("Panel").visible)

	# --- Clicking the already-open panel's button just closes it. ---
	panel_buttons.inventory_btn.pressed.emit()
	await process_frame
	print("Re-clicking the open panel's button closes it: ", not inventory_panel.get_node("Panel").visible)

	# --- Keyboard shortcuts still work too (regression check on the refactor). ---
	Input.action_press("toggle_inventory")
	await process_frame
	Input.action_release("toggle_inventory")
	await process_frame
	print("Keyboard I still opens Inventory (regression check): ", inventory_panel.get_node("Panel").visible)
	Input.action_press("toggle_inventory")
	await process_frame
	Input.action_release("toggle_inventory")
	await process_frame

	# --- Blocked during combat, same as the keyboard shortcuts. ---
	combat.start_combat("dungeon_rat")
	await process_frame
	panel_buttons.inventory_btn.pressed.emit()
	await process_frame
	print("Toolbar button blocked during combat: ", not inventory_panel.get_node("Panel").visible)
	combat.player_run()
	await process_frame

	quit()
