extends SceneTree

func _initialize() -> void:
	var dungeon_scene: PackedScene = load("res://scenes/Dungeon.tscn")
	var dungeon: Node2D = dungeon_scene.instantiate()
	root.add_child(dungeon)
	current_scene = dungeon
	await process_frame
	await process_frame

	var character: Node = root.get_node("Character")
	var combat: Node = root.get_node("Combat")
	var inventory: Node = root.get_node("Inventory")
	var crafting: Node = root.get_node("Crafting")
	var sheet: Node = root.get_node("CharacterSheet")

	# --- Craft both new gear items. ---
	inventory.add_item("wood", 20)
	inventory.add_item("stone", 20)
	inventory.add_item("gold", 20)
	print("Crafted leather armor: ", crafting.craft("leather_armor"))
	print("Crafted charm of warding: ", crafting.craft("charm_of_warding"))
	print("Leather armor in backpack: ", inventory.get_count("leather_armor"))
	print("Charm in backpack: ", inventory.get_count("charm_of_warding"))

	# --- Equip via the actual CharacterSheet UI (not the direct API) to
	# prove the tap-slot-then-Equip wiring, not just Character.equip(). ---
	Input.action_press("toggle_inventory")
	await process_frame
	Input.action_release("toggle_inventory")
	await process_frame
	var armor_btn: Button = sheet.grid.get_node_or_null("LeatherArmorSlot")
	print("Found Leather Armor slot in the CharacterSheet grid: ", armor_btn != null)
	armor_btn.pressed.emit()
	await process_frame
	print("Detail pane offers Equip for gear: ", sheet.primary_action.visible and sheet.primary_action.text == "Equip")
	sheet.primary_action.pressed.emit()
	await process_frame
	print("Armor equipped after UI click: ", character.equipment.armor == "leather_armor")
	print("Backpack count after equip (should be 0, moved to slot): ", inventory.get_count("leather_armor"))
	root.get_texture().get_image().save_png("res://verify_p5_inventory_equipped.png")

	# Equip the charm directly (already proved the UI path above).
	character.equip("accessory", "charm_of_warding")
	await process_frame
	print("Charm equipped: ", character.equipment.accessory == "charm_of_warding")
	root.get_texture().get_image().save_png("res://verify_p5_character_panel.png")

	# --- Defense: average damage taken should drop once armor is equipped. ---
	var dmg_sum_armored := 0
	var trials := 40
	for i in range(trials):
		combat.start_combat("skeleton") # attack=5, no status roll needed here
		character.stats.hp = 100
		combat.player_status.clear()
		combat._enemy_turn()
		dmg_sum_armored += 100 - character.stats.hp
	var avg_armored: float = float(dmg_sum_armored) / trials

	character.unequip("armor")
	var dmg_sum_unarmored := 0
	for i in range(trials):
		combat.start_combat("skeleton")
		character.stats.hp = 100
		combat.player_status.clear()
		combat._enemy_turn()
		dmg_sum_unarmored += 100 - character.stats.hp
	var avg_unarmored: float = float(dmg_sum_unarmored) / trials

	print("Avg damage unarmored: ", avg_unarmored, " armored: ", avg_armored)
	print("Armor meaningfully reduced average damage taken: ", avg_armored < avg_unarmored - 1.0)

	# Re-equip for the status-resistance test.
	character.equip("armor", "leather_armor")

	# --- Status resistance: charm should roughly halve the affliction rate. ---
	character.unequip("accessory")
	var without_charm_hits := 0
	trials = 200
	for i in range(trials):
		combat.start_combat("dungeon_rat") # 25% poison status_attack
		character.stats.hp = 100
		combat.player_status.clear()
		combat._enemy_turn()
		if combat.player_status.has("poison"):
			without_charm_hits += 1
	var rate_without: float = float(without_charm_hits) / trials

	character.equip("accessory", "charm_of_warding")
	var with_charm_hits := 0
	for i in range(trials):
		combat.start_combat("dungeon_rat")
		character.stats.hp = 100
		combat.player_status.clear()
		combat._enemy_turn()
		if combat.player_status.has("poison"):
			with_charm_hits += 1
	var rate_with: float = float(with_charm_hits) / trials

	print("Poison rate without charm (~0.25 expected): ", rate_without)
	print("Poison rate with charm (~0.125 expected): ", rate_with)
	print("Charm meaningfully reduced the affliction rate: ", rate_with < rate_without * 0.75)

	# --- Unequip returns items to backpack, stats/rates back to baseline. ---
	character.unequip("armor")
	character.unequip("accessory")
	print("Armor back in backpack after unequip: ", inventory.get_count("leather_armor") == 1)
	print("Charm back in backpack after unequip: ", inventory.get_count("charm_of_warding") == 1)
	print("Equipment slots empty after unequip: ", character.equipment.armor == "" and character.equipment.accessory == "")

	quit()
