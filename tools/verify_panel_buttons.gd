extends SceneTree
# System bar (PanelButtons) verification: Menu and a cog at the top-right on
# every width (the old five-letter desktop row is gone). Menu opens the
# character sheet and closes whatever is open; the cog opens the Settings
# window (volume sliders, Save now / Load / Quit to title). Hidden during a
# fight; the keyboard shortcuts still reach the sheet's tabs. Run via:
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

	print("Bar holds Menu and a cog (icon, no text) in a row, no letter buttons: ", bar.bar.get_child_count() == 2 and bar.menu_btn.text == "Menu" and bar.settings_btn.text == "" and bar.settings_btn.icon != null and not bar.has_node("HBox") and not bar.bar.vertical)
	var menu_rect: Rect2 = bar.menu_btn.get_global_rect()
	var cog_rect: Rect2 = bar.settings_btn.get_global_rect()
	print("Row hugs the top-right corner, right of the HUD: ", cog_rect.end.x <= 800.0 - 12.0 + 0.5 and cog_rect.end.x > 760.0 and menu_rect.position.y == cog_rect.position.y and menu_rect.position.x > root.get_node("HUD").panel.get_global_rect().end.x)
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

	# --- Cog: the Settings window, closed by Menu / X / Esc. ---
	bar.settings_btn.pressed.emit()
	await process_frame
	print("The cog opens the Settings window (sliders + Game section), not the sheet: ", settings.is_open() and not sheet.is_open() and settings.music_slider != null and settings.game_section.visible and settings.load_btn != null and settings.quit_btn.text == "Quit to title")
	root.get_texture().get_image().save_png("res://verify_panel_buttons_settings.png")
	print("Saved verify_panel_buttons_settings.png")
	bar.settings_btn.pressed.emit()
	await process_frame
	print("Cog again closes it: ", not settings.is_open())
	bar.settings_btn.pressed.emit()
	await process_frame
	bar.menu_btn.pressed.emit()
	await process_frame
	print("Menu while Settings is open closes it: ", not settings.is_open() and not sheet.is_open())
	sheet.open("inventory")
	await process_frame
	bar.settings_btn.pressed.emit()
	await process_frame
	print("Cog while the sheet is open swaps to the Settings window: ", settings.is_open() and not sheet.is_open())
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

	# --- Save now: writes the auto slot, flashes. ---
	save.delete_save(save.AUTO_SLOT)
	settings.open()
	await process_frame
	settings.save_btn.pressed.emit()
	await process_frame
	print("Save now writes the auto slot and flashes 'Saved!': ", save.has_save(save.AUTO_SLOT) and settings.save_btn.text == "Saved!")
	save.delete_save(save.AUTO_SLOT)

	# --- Quit to title: asks first, then times out back. ---
	settings.quit_btn.pressed.emit()
	await process_frame
	print("Quit asks 'Sure?' first (nothing changes yet): ", settings.confirm_quit and settings.quit_btn.text.begins_with("Sure?") and current_scene == overworld)
	await create_timer(settings.CONFIRM_SECONDS + 0.3).timeout
	print("...and forgets the question after a few seconds: ", not settings.confirm_quit and settings.quit_btn.text == "Quit to title")
	settings.close()

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
	print("Bar hidden during a fight, Menu / cog inert: ", not bar.visible and not sheet.is_open() and not settings.is_open())
	combat.player_run()
	await process_frame
	await process_frame
	print("Bar back once the fight ends: ", bar.visible)

	quit()
