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
	var battle_panel: Node = root.get_node("BattlePanel")
	var submenu: VBoxContainer = battle_panel.get_node("Panel/Margin/VBox/Submenu")
	var commands: HBoxContainer = battle_panel.get_node("Panel/Margin/VBox/Commands")

	# --- Craft the two potions to have something to test Item with. ---
	inventory.add_item("wood", 10)
	inventory.add_item("stone", 10)
	var crafting: Node = root.get_node("Crafting")
	print("Crafted healing potion: ", crafting.craft("healing_potion"))
	print("Crafted mana potion: ", crafting.craft("mana_potion"))
	print("Healing potions in backpack: ", inventory.get_count("healing_potion"))
	print("Mana potions in backpack: ", inventory.get_count("mana_potion"))

	# --- Start a fight, open the Magic menu, confirm both spells listed. ---
	combat.start_combat("skeleton")
	await process_frame
	combat.open_magic_menu()
	await process_frame
	print("Submenu visible (magic open): ", submenu.visible, " commands visible: ", commands.visible)
	print("Submenu row count (2 spells + Back): ", submenu.get_child_count())
	for child in submenu.get_children():
		if child is Button:
			print("  row: ", child.text, " disabled=", child.disabled)
	root.get_texture().get_image().save_png("res://verify_p2_magic_menu.png")

	# --- Cast Heal (should close submenu, restore HP, cost 4 MP). ---
	character.stats.hp = 5
	var mp_before: int = character.stats.mp
	combat.cast_spell("heal")
	await process_frame
	print("HP after Heal: ", character.stats.hp, " MP after Heal: ", character.stats.mp, " (was ", mp_before, ")")
	print("Submenu closed after cast: ", not submenu.visible)

	# --- Open Item menu, confirm both potions listed, use Healing Potion. ---
	combat.open_item_menu()
	await process_frame
	print("Item submenu row count (2 potions + Back): ", submenu.get_child_count())
	# The skeleton can paralyse on its counter-attack; a failed act roll here
	# would skip the potion turn and its 5-damage hit kills a 5-HP player
	# (_defeat() resets HP and keeps the potion - looked like a broken item
	# path). Same isolation verify_combat_phase5.gd uses.
	combat.player_status.clear()
	character.stats.hp = 5
	var potions_before: int = inventory.get_count("healing_potion")
	combat.use_item("healing_potion")
	await process_frame
	print("HP after potion: ", character.stats.hp)
	print("Potions left: ", inventory.get_count("healing_potion"), " (was ", potions_before, ")")
	root.get_texture().get_image().save_png("res://verify_p2_after_item.png")

	# --- Empty item menu case: drain potions, confirm "No usable items." ---
	inventory.remove_item("healing_potion", inventory.get_count("healing_potion"))
	inventory.remove_item("mana_potion", inventory.get_count("mana_potion"))
	combat.open_item_menu()
	await process_frame
	var found_empty_msg := false
	for child in submenu.get_children():
		if child is Label and child.text == "No usable items.":
			found_empty_msg = true
	print("Empty item menu shows message: ", found_empty_msg)

	# --- Fireball still works and can finish the fight. ---
	combat.close_submenu()
	await process_frame
	character.stats.mp = 10
	var guard := 0
	while combat.in_combat and guard < 30:
		if character.stats.mp >= 3:
			combat.cast_spell("fireball")
		else:
			combat.player_attack()
		await process_frame
		guard += 1
	print("In combat after fireball-loop victory: ", combat.in_combat, " (", guard, " actions)")
	print("Gold after victory: ", inventory.get_count("gold"))

	quit()
