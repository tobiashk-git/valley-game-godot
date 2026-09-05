extends SceneTree
# Title screen verification. Run via: godot --script res://tools/verify_title.gd
# (NOT --headless). Fresh start: New Game is the primary and Continue is
# hidden, overlays hidden, New Game lands on the overworld with a clean
# state and the overlays back; the sheet's shortcuts do nothing on the
# title; Save-and-quit from the Hero tab returns to the title with Continue
# offered; phone layout stacks Oliver over the menu.

func _press(action: String) -> void:
	Input.action_press(action)
	await process_frame
	Input.action_release(action)
	await process_frame
	await process_frame

func _initialize() -> void:
	var save: Node = root.get_node("SaveSystem")
	var hud: CanvasLayer = root.get_node("HUD")
	var sheet: CanvasLayer = root.get_node("CharacterSheet")
	var layout: Node = root.get_node("Layout")
	var inventory: Node = root.get_node("Inventory")
	print("Project opens on the title screen: ", ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/Title.tscn")
	save.delete_save(save.AUTO_SLOT)

	var title: Control = load("res://scenes/Title.tscn").instantiate()
	root.add_child(title)
	current_scene = title
	await process_frame
	await process_frame
	print("Fresh start: New Game is the primary, Continue hidden, 'no save yet' line: ", not title.continue_btn.visible and title.new_game_btn.theme_type_variation == &"PrimaryButton" and title.save_line.text.begins_with("No save yet"))
	print("Background is the rendered valley, Oliver shown: ", title.map_bg.texture != null and title.figure.texture != null)
	print("Overlays hidden on the title: ", not hud.visible and not root.get_node("PanelButtons").visible and not root.get_node("QuickBar").visible and not root.get_node("QuestTracker").visible and not root.get_node("TouchControls").visible)
	await _press("toggle_inventory")
	print("Sheet shortcuts do nothing on the title: ", not sheet.is_open())
	root.get_texture().get_image().save_png("res://verify_title_fresh.png")
	print("Saved verify_title_fresh.png")

	title.new_game_btn.pressed.emit()
	await process_frame
	await process_frame
	await process_frame
	print("New Game lands on the overworld with a clean state, overlays back: ", current_scene.name == "Overworld" and inventory.backpack.is_empty() and hud.visible and root.get_node("PanelButtons").visible)

	# --- Save and quit to title from the Hero tab. ---
	inventory.add_item("wood", 3)
	save.enabled = true
	sheet.open("character")
	await process_frame
	print("Hero tab: Game block sits at the top of the stats column; the sheet's own Save & Quit is beside the X: ", sheet.stats_list.get_child(0).text == "Game" and sheet.stats_list.find_child("SaveNowBtn", true, false) != null and sheet.quit_btn.visible and sheet.quit_btn.text == "Save & Quit")
	sheet.quit_btn.pressed.emit()
	await process_frame
	await process_frame
	await process_frame
	print("Save and quit returns to the title with Continue offered: ", current_scene.name == "Title" and save.has_save(save.AUTO_SLOT) and current_scene.continue_btn.visible and current_scene.save_line.text.contains("in the Valley") and not sheet.is_open())
	save.enabled = false

	# --- Phone layout. ---
	root.size = Vector2i(400, 660)
	for i in range(6):
		await process_frame
	var t: Control = current_scene
	sheet.open("character")
	await process_frame
	print("Phone: Hero tab carries Save and quit to title in its Game block (no room beside the X): ", sheet.stats_list.get_node_or_null("QuitBtn") != null and not sheet.quit_btn.visible)
	sheet.close()
	change_scene_to_packed(load("res://scenes/Title.tscn"))
	await process_frame
	await process_frame
	t = current_scene
	print("Phone: Oliver above the menu, menu spans the width, buttons inside: ", layout.is_narrow() and t.figure.position.y < t.menu.position.y and t.menu.size.x == 376.0 and t.buttons.get_global_rect().end.y <= t.menu.get_global_rect().end.y and t.menu.get_global_rect().end.y <= 660.0)
	root.get_texture().get_image().save_png("res://verify_title_phone.png")
	print("Saved verify_title_phone.png")
	root.size = Vector2i(800, 600)
	for i in range(4):
		await process_frame
	save.delete_save(save.AUTO_SLOT)
	print("Test save removed: ", not save.has_save(save.AUTO_SLOT))
	quit()
