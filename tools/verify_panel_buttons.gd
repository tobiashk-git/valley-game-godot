extends SceneTree
# System bar (PanelButtons) verification: Menu / Save / Settings / Quit at
# the top-right on every width (the old five-letter desktop row is gone).
# Menu opens the character sheet and closes whatever is open; Settings opens
# the Settings window (volume sliders + Load); Save writes the auto slot with
# a "Saved!" flash; Quit asks first. Hidden during a fight; the keyboard
# shortcuts still reach the sheet's tabs. Run via:
# godot --script res://tools/verify_panel_buttons.gd (NOT --headless).

func _initialize() -> void:
	var overworld_scene: PackedScene = load("res://scenes/Overworld.tscn")
	var overworld: Node2D = overworld_scene.instantiate()
	root.add_child(overworld)
	current_scene = overworld
	await process_frame
	await process_frame

	var combat: Node = root.get_node("Combat")
	var bar: CanvasLayer = root.get_node("PanelButtons")
	var sheet: Node = root.get_node("CharacterSheet")
	var settings: CanvasLayer = root.get_node("SettingsPanel")
	var quest_panel: Node = root.get_node("QuestPanel")
	var save: Node = root.get_node("SaveSystem")

	print("Bar holds Menu, Save, Settings and Quit in a row, no letter buttons: ", bar.bar.get_child_count() == 4 and bar.menu_btn.text == "Menu" and bar.save_btn.text == "Save" and bar.settings_btn.text == "Settings" and bar.quit_btn.text == "Quit" and not bar.has_node("HBox") and not bar.bar.vertical)
	var menu_rect: Rect2 = bar.menu_btn.get_global_rect()
	var quit_rect: Rect2 = bar.quit_btn.get_global_rect()
	print("Row hugs the top-right corner, right of the HUD: ", quit_rect.end.x <= 800.0 - 12.0 + 0.5 and quit_rect.end.x > 700.0 and menu_rect.position.y == quit_rect.position.y and menu_rect.position.x > root.get_node("HUD").panel.get_global_rect().end.x)
	root.get_texture().get_image().save_png("res://verify_panel_buttons_toolbar.png")
	print("Saved verify_panel_buttons_toolbar.png")

	# --- Menu: opens the sheet, closes everything again. ---
	bar.menu_btn.pressed.emit()
	await process_frame
	print("Menu opens the character sheet: ", sheet.is_open())
	root.get_texture().get_image().save_png("res://verify_panel_buttons_inventory.png")
	bar.menu_btn.pressed.emit()
	await process_frame
	print("Menu again closes it: ", not sheet.is_open())
	quest_panel.open()
	await process_frame
	bar.menu_btn.pressed.emit()
	await process_frame
	print("Menu with the Journal open closes it rather than stacking: ", not quest_panel.is_open() and not sheet.is_open())

	# --- Settings: its own window, closed by Menu / X / Esc. ---
	bar.settings_btn.pressed.emit()
	await process_frame
	print("Settings opens the Settings window (sliders + Load), not the sheet: ", settings.is_open() and not sheet.is_open() and settings.music_slider != null and settings.load_btn != null)
	root.get_texture().get_image().save_png("res://verify_panel_buttons_settings.png")
	print("Saved verify_panel_buttons_settings.png")
	bar.settings_btn.pressed.emit()
	await process_frame
	print("Settings again closes it: ", not settings.is_open())
	bar.settings_btn.pressed.emit()
	await process_frame
	bar.menu_btn.pressed.emit()
	await process_frame
	print("Menu while Settings is open closes it: ", not settings.is_open() and not sheet.is_open())
	sheet.open("inventory")
	await process_frame
	bar.settings_btn.pressed.emit()
	await process_frame
	print("Settings while the sheet is open swaps to the Settings window: ", settings.is_open() and not sheet.is_open())
	settings.close_btn.pressed.emit()
	await process_frame
	print("The window's X closes it: ", not settings.is_open())
	settings.open()
	await process_frame
	await process_frame
	Input.action_press("ui_cancel")
	await process_frame
	Input.action_release("ui_cancel")
	await process_frame
	print("Esc closes it: ", not settings.is_open())

	# --- Save: writes the auto slot, flashes. ---
	save.delete_save(save.AUTO_SLOT)
	bar.save_btn.pressed.emit()
	await process_frame
	print("Save writes the auto slot and flashes 'Saved!': ", save.has_save(save.AUTO_SLOT) and bar.save_btn.text == "Saved!")
	save.delete_save(save.AUTO_SLOT)

	# --- Quit: asks first, then times out back to Quit. ---
	bar.quit_btn.pressed.emit()
	await process_frame
	print("Quit asks 'Sure?' first (nothing changes yet): ", bar.confirm_quit and bar.quit_btn.text == "Sure?" and current_scene == overworld)
	await create_timer(bar.CONFIRM_SECONDS + 0.3).timeout
	print("...and forgets the question after a few seconds: ", not bar.confirm_quit and bar.quit_btn.text == "Quit")

	# --- Keyboard shortcuts still reach the sheet's tabs. ---
	await process_frame # a timer resume lands after the frame's callbacks; press at a frame start
	Input.action_press("toggle_inventory")
	await process_frame
	Input.action_release("toggle_inventory")
	await process_frame
	print("Keyboard I still opens Inventory: ", sheet.is_open() and sheet.current_tab == "inventory")
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

	# --- Hidden during a fight, and its buttons do nothing then. ---
	combat.start_combat("dungeon_rat")
	await process_frame
	await process_frame
	bar.menu_btn.pressed.emit()
	bar.settings_btn.pressed.emit()
	await process_frame
	print("Bar hidden during a fight, Menu / Settings inert: ", not bar.visible and not sheet.is_open() and not settings.is_open())
	combat.player_run()
	await process_frame
	await process_frame
	print("Bar back once the fight ends: ", bar.visible)

	quit()
