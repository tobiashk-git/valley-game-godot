extends SceneTree
# Quick-access bar verification. Run via:
# godot --script res://tools/verify_quick_bar.gd (NOT --headless - takes a
# real screenshot via get_texture()).
#
# A bottom-centre row of the usable consumables (user request: "have the
# health potion always available when not in combat"): every usable item
# gets a slot whether or not any is owned, tapping one applies the item's
# effect in the field and only then consumes it, the bar hides during a
# fight and while a full-screen panel is open, and the combat path still
# spends the item regardless (turn used either way).

func _initialize() -> void:
	var quick_bar: CanvasLayer = root.get_node("QuickBar")
	var combat: Node = root.get_node("Combat")
	var character: Node = root.get_node("Character")
	var inventory: Node = root.get_node("Inventory")
	var items: Node = root.get_node("Items")
	var inventory_panel: Node = root.get_node("InventoryPanel")

	var overworld: Node2D = load("res://scenes/Overworld.tscn").instantiate()
	root.add_child(overworld)
	current_scene = overworld
	await process_frame
	await process_frame

	# --- Slots: one per usable item, always present, disabled when none owned. ---
	var usable: Array = []
	for item_id in items.ITEMS.keys():
		if items.is_usable(item_id):
			usable.append(item_id)
	var same_slots: bool = quick_bar.item_ids.size() == usable.size() and quick_bar.hbox.get_child_count() == usable.size()
	for i in range(usable.size()):
		if i >= quick_bar.item_ids.size() or quick_bar.item_ids[i] != usable[i]:
			same_slots = false
	print("One slot per usable item (", usable.size(), "), in Items.ITEMS order: ", same_slots)
	var heal_slot: Button = quick_bar._slots["healing_potion"].button
	var heal_count: Label = quick_bar._slots["healing_potion"].count
	print("Healing potion slot shown with a count of 0 and disabled when none owned: ", inventory.get_count("healing_potion") == 0 and heal_slot.visible and heal_slot.disabled and heal_count.text == "0")
	print("Slot shows the item's icon: ", heal_slot.icon != null and heal_slot.icon.resource_path == "res://assets/icons/healing_potion.png")

	# --- Placement: bottom-centre, above the bottom edge, clear of the
	# touch joystick (x<130) and interact button (x>680) zones. ---
	var bar_rect: Rect2 = quick_bar.hbox.get_global_rect()
	var viewport_size: Vector2 = root.get_visible_rect().size
	print("Bar is horizontally centred: ", absf(bar_rect.get_center().x - viewport_size.x / 2.0) < 2.0, " (", bar_rect, ")")
	print("Bar sits just above the bottom edge: ", bar_rect.end.y < viewport_size.y and viewport_size.y - bar_rect.end.y <= 24.0)
	print("Bar is clear of the joystick and interact-button zones: ", bar_rect.position.x > 140.0 and bar_rect.end.x < 670.0)

	# --- Field use: heals, consumes one, updates the count. ---
	inventory.add_item("healing_potion", 2)
	await process_frame
	print("Slot enables and counts up once potions are owned: ", not heal_slot.disabled and heal_count.text == "2")
	character.stats.hp = character.stats.max_hp - 10
	character.changed.emit()
	var hp_before: int = character.stats.hp
	heal_slot.pressed.emit()
	await process_frame
	print("Tapping the slot heals in the field (min(15, missing 10)): ", character.stats.hp == hp_before + 10)
	print("One potion consumed, count updated: ", inventory.get_count("healing_potion") == 1 and heal_count.text == "1")
	print("Feedback toast shown: ", quick_bar.feedback_label.modulate.a > 0.9 and quick_bar.feedback_label.text.contains("recovers 10 HP"))
	root.get_texture().get_image().save_png("res://verify_quick_bar.png")
	print("Saved verify_quick_bar.png")

	# --- Mis-tap at full HP: nothing happens, potion NOT consumed. ---
	heal_slot.pressed.emit()
	await process_frame
	print("Tapping at full HP does not consume the potion: ", inventory.get_count("healing_potion") == 1 and character.stats.hp == character.stats.max_hp)

	# --- Mana potion + antidote go through the same shared path. ---
	inventory.add_item("mana_potion", 1)
	inventory.add_item("antidote", 1)
	character.stats.mp = max(0, character.stats.max_mp - 3)
	character.changed.emit()
	await process_frame
	var mp_before: int = character.stats.mp
	quick_bar._slots["mana_potion"].button.pressed.emit()
	await process_frame
	print("Mana potion restores MP in the field and is consumed: ", character.stats.mp == mp_before + 3 and inventory.get_count("mana_potion") == 0)
	quick_bar._slots["antidote"].button.pressed.emit()
	await process_frame
	print("Antidote with nothing to cure is kept: ", inventory.get_count("antidote") == 1)

	# --- Hidden during a fight; combat's own item use still spends the item
	# even when it does nothing (turn used either way). ---
	while combat.in_combat:
		combat.player_run()
		await physics_frame
	combat.start_combat(["dungeon_rat"])
	await process_frame
	await process_frame
	print("Bar hidden during a fight: ", combat.in_combat and not quick_bar.visible)
	character.stats.hp = character.stats.max_hp
	combat.use_item("healing_potion")
	await process_frame
	var logged_zero_heal := false
	for line in combat.battle_log:
		if line.contains("recovers 0 HP"):
			logged_zero_heal = true
	print("Combat item use still consumes the potion at full HP (shared effect path): ", inventory.get_count("healing_potion") == 0 and logged_zero_heal)
	while combat.in_combat:
		combat.player_run()
		await physics_frame
	await process_frame
	print("Bar back after the fight: ", quick_bar.visible)

	# --- Hidden while a full-screen panel is open. ---
	inventory_panel.open()
	await process_frame
	print("Bar hidden while the Inventory panel is open: ", inventory_panel.is_open() and not quick_bar.visible)
	inventory_panel.close()
	await process_frame
	print("Bar back once the panel closes: ", not inventory_panel.is_open() and quick_bar.visible)

	quit()
