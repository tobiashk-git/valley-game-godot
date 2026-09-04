extends SceneTree
# Phone-layout verification (user feedback from an iPhone/iPad playtest:
# "iPhone text, boxes, movement pad and action button all very small"; "the
# quest text box is partially hidden by the health/MP box"). Run via:
# godot --script res://tools/verify_phone_layout.gd (NOT --headless - real
# window resizes + screenshots).
#
# Resizes the window to a phone shape (400x860) and checks that Layout picks
# a 400-unit logical width, every always-on overlay moves to its narrow
# arrangement without overlapping its neighbours, the touch zoom keeps the
# world's field of view, the dialogue box clears the HUD, the legacy panels
# fit the width, then resizes back to 800x600 and checks the wide layout
# comes back.

func _rect(c: Control) -> Rect2:
	return c.get_global_rect()

func _initialize() -> void:
	var layout: Node = root.get_node("Layout")
	var hud: CanvasLayer = root.get_node("HUD")
	var panel_buttons: CanvasLayer = root.get_node("PanelButtons")
	var tracker: CanvasLayer = root.get_node("QuestTracker")
	var quick_bar: CanvasLayer = root.get_node("QuickBar")
	var touch: CanvasLayer = root.get_node("TouchControls")
	var battle: CanvasLayer = root.get_node("BattlePanel")
	var combat: Node = root.get_node("Combat")
	var dialogue: CanvasLayer = root.get_node("DialogueUI")
	var sheet: CanvasLayer = root.get_node("CharacterSheet")
	var quest_panel: CanvasLayer = root.get_node("QuestPanel")
	var shop_panel: CanvasLayer = root.get_node("ShopPanel")
	var inventory: Node = root.get_node("Inventory")
	var world: Node = root.get_node("World")

	var overworld: Node2D = load("res://scenes/Overworld.tscn").instantiate()
	root.add_child(overworld)
	current_scene = overworld
	await process_frame
	await process_frame
	var player: CharacterBody2D = overworld.get_node("YSort/Player")
	var cam: Camera2D = player.get_node("Camera2D")
	inventory.add_item("healing_potion", 2)

	# --- The rule itself. ---
	print("Desktop 800x600 -> wide (800 units): ", layout.width == 800 and not layout.is_narrow() and root.get_visible_rect().size == Vector2(800, 600))
	print("width_for(): tablet/desktop widths stay 800, phones follow their CSS width within 360..480: ", layout.width_for(820.0) == 800 and layout.width_for(744.0) == 800 and layout.width_for(640.0) == 800 and layout.width_for(430.0) == 430 and layout.width_for(390.0) == 390 and layout.width_for(320.0) == 360 and layout.width_for(600.0) == 480)
	print("Stretch mode is canvas_items (text rendered at device resolution): ", ProjectSettings.get_setting("display/window/stretch/mode") == "canvas_items")
	print("Dialogue box starts below the HUD's tallest extent (y>=148) on desktop too: ", dialogue.panel.offset_top >= 148.0)

	# --- Phone shape. ---
	root.size = Vector2i(400, 860)
	for i in range(6):
		await process_frame
	var vis: Vector2 = root.get_visible_rect().size
	print("400x860 window -> narrow, 400 logical units wide, 860 tall: ", layout.width == 400 and layout.is_narrow() and vis == Vector2(400, 860))

	# HUD + toolbar share the top row.
	var hud_rect: Rect2 = _rect(hud.panel)
	var menu_rect: Rect2 = _rect(panel_buttons.menu_btn)
	print("Toolbar collapses to one Menu button (row hidden): ", panel_buttons.menu_btn.visible and not panel_buttons.hbox.visible and menu_rect.end.x <= 400.0 - 12.0 + 0.5)
	print("HUD narrows to leave the Menu button room, no overlap: ", hud_rect.size.x <= 400.0 - 24.0 - 92.0 + 0.5 and hud_rect.end.x <= menu_rect.position.x and not hud_rect.intersects(menu_rect))
	print("Location label moves onto its own line under the counters: ", hud.location_label.get_parent() == hud.vbox and _rect(hud.location_label).position.y >= _rect(hud.hbox).end.y)
	# Longest biome name on the narrow HUD.
	player.position = Vector2(world.WORLD_CENTER_X * 32 + 16, (world.WORLD_CENTER_Y + world.VALLEY_RADIUS + 12) * 32 + 16)
	cam.reset_smoothing()
	for i in range(4):
		await process_frame
	hud_rect = _rect(hud.panel)
	# The extra location row makes the phone HUD a touch taller than the
	# desktop one (149 vs 143); what matters is clearing the dialogue box
	# and the tracker, which both start at y=152.
	print("Longest biome name fits on one line and the HUD still ends above the dialogue/tracker top (y=152): ", hud.location_label.text == "Emberfall Badlands" and hud.location_label.get_line_count() == 1 and hud_rect.end.y <= 152.0, " (ends y=", hud_rect.end.y, ")")

	# Quest tracker below the HUD, inside the width.
	var tracker_rect: Rect2 = _rect(tracker.vbox)
	print("Quest tracker drops below the HUD and stays inside the width: ", tracker_rect.position.y >= hud_rect.end.y and tracker_rect.end.x <= 400.0 - 12.0 + 0.5 and tracker_rect.position.x >= 12.0 and tracker.visible)

	# Quick bar clear of the thumb zones.
	var bar_rect: Rect2 = _rect(quick_bar.hbox)
	var joystick_rect: Rect2 = _rect(touch.joystick_base)
	var interact_rect := Rect2(touch.interact_button.position, Vector2(80, 80))
	touch._position_interact_button()
	interact_rect = Rect2(touch.interact_button.position, Vector2(80, 80))
	print("Quick bar centred, inside the width, and above both the joystick and the interact button: ", absf(bar_rect.get_center().x - 200.0) < 2.0 and bar_rect.position.x >= 0.0 and bar_rect.end.x <= 400.0 and bar_rect.end.y <= joystick_rect.position.y and bar_rect.end.y <= interact_rect.position.y, " bar=", bar_rect)
	print("Touch controls keep their size (100px joystick, 80px button) - now 1:1 with screen px: ", joystick_rect.size == Vector2(100, 100) and interact_rect.end.x <= 400.0 and interact_rect.end.y <= 860.0)

	# Touch zoom keeps the tuned field of view.
	touch.visible = true
	touch.set_process(true)
	touch._zoomed_camera = null
	await process_frame
	var expected_zoom: Vector2 = touch.MOBILE_ZOOM * 0.5
	print("Touch zoom scales with the width (2.2 * 400/800 = 1.1) so the world shows the same span: ", cam.zoom.is_equal_approx(expected_zoom), " zoom=", cam.zoom)
	touch.set_process(false)

	# Dialogue box: below the HUD, inside the width.
	dialogue.show_dialogue("Elder", "Welcome, traveller. The valley needs your help.")
	await process_frame
	var dlg_rect: Rect2 = _rect(dialogue.panel)
	print("Dialogue box sits below the HUD and inside the phone width: ", dlg_rect.position.y >= hud_rect.end.y and not dlg_rect.intersects(hud_rect) and dlg_rect.end.x <= 400.0 and dlg_rect.position.x >= 0.0)
	root.get_texture().get_image().save_png("res://verify_phone_dialogue.png")
	print("Saved verify_phone_dialogue.png")
	dialogue.hide_dialogue()
	await process_frame
	root.get_texture().get_image().save_png("res://verify_phone_field.png")
	print("Saved verify_phone_field.png")

	# Battle panel spans the width, HUD uncovered.
	combat.start_combat(["dungeon_rat", "dungeon_rat"])
	await process_frame
	await process_frame
	var battle_rect: Rect2 = _rect(battle.panel)
	print("Battle panel spans the phone width and doesn't cover the HUD: ", battle_rect.size.x == 400.0 - 24.0 and battle_rect.position.x == 12.0 and not battle_rect.intersects(hud_rect) and battle_rect.end.y <= 860.0)
	var cmd_rect: Rect2 = _rect(battle.commands)
	print("Command row fits inside the panel (five buttons): ", cmd_rect.end.x <= battle_rect.end.x + 0.5 and battle.run_btn.get_global_rect().end.x <= battle_rect.end.x + 0.5)
	root.get_texture().get_image().save_png("res://verify_phone_battle.png")
	print("Saved verify_phone_battle.png")
	while combat.in_combat:
		combat.player_run()
		await physics_frame
	await process_frame

	# Menu button opens the sheet, second press closes everything.
	panel_buttons.menu_btn.pressed.emit()
	await process_frame
	print("Menu opens the character sheet: ", sheet.is_open())
	panel_buttons.menu_btn.pressed.emit()
	await process_frame
	print("Menu again closes it: ", not sheet.is_open())

	# Legacy panels scaled to fit.
	quest_panel.open()
	await process_frame
	var qp_rect: Rect2 = _rect(quest_panel.panel)
	print("Journal (720 wide) scaled down to fit the phone width: ", quest_panel.panel.scale.x < 1.0 and qp_rect.size.x <= 400.0 - 16.0 + 0.5 and qp_rect.position.x >= 0.0)
	quest_panel.close()
	shop_panel.open()
	await process_frame
	var sp_rect: Rect2 = _rect(shop_panel.window)
	print("Shop window (kit) fills the phone width, grid above its pane: ", shop_panel.narrow and sp_rect.position.x == 12.0 and sp_rect.size.x == 400.0 - 24.0 and shop_panel.detail_pane.position.y >= shop_panel.grid_scroll.position.y + shop_panel.grid_scroll.size.y and shop_panel.grid.columns == 4)
	shop_panel.grid.get_node("HealingPotionSlot").pressed.emit()
	await process_frame
	root.get_texture().get_image().save_png("res://verify_phone_shop.png")
	print("Saved verify_phone_shop.png")
	shop_panel.close()
	sheet.open("map")
	await process_frame
	var mv: Control = sheet.map_view
	print("Map tab on the phone: header hidden, map above its pane, inside the window: ", sheet.narrow and not sheet.header.visible and mv.visible and mv.detail_pane.position.y >= mv.map_frame.position.y + mv.map_frame.size.y and mv.detail_pane.get_global_rect().end.y <= sheet.window.get_global_rect().end.y)
	sheet.close()

	# --- Back to desktop. ---
	root.size = Vector2i(800, 600)
	for i in range(6):
		await process_frame
	print("800x600 again -> wide layout restored: ", layout.width == 800 and not layout.is_narrow() and root.get_visible_rect().size == Vector2(800, 600))
	print("HUD back to 320 with the location beside the counters: ", is_equal_approx(hud.panel.size.x, 320.0) and hud.location_label.get_parent() == hud.hbox)
	print("Toolbar row back, Menu hidden: ", panel_buttons.hbox.visible and not panel_buttons.menu_btn.visible)
	print("Tracker back beside the HUD (y=64): ", tracker.vbox.offset_top == 64.0 and tracker.vbox.offset_left == -268.0)
	bar_rect = _rect(quick_bar.hbox)
	print("Quick bar back at the bottom edge: ", 600.0 - bar_rect.end.y <= 24.0)
	print("Battle panel back to 480 wide: ", battle.panel.offset_left == -240.0 and battle.panel.offset_right == 240.0)
	print("Journal back at full scale: ", quest_panel.panel.scale == Vector2.ONE)
	quit()
