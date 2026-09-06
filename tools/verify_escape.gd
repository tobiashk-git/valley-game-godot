extends SceneTree
# Escape + loss + bank verification. Run via:
# godot --script res://tools/verify_escape.gd (NOT --headless).
#
# The Angel Feather (25 g at the Trader, 3% wild drop, stacks to 5) carries
# Oliver home from the field and mid-fight; a nap costs all carried gold and
# every valued stackable but keeps worn AND spare gear and quest items; gold
# banked in the house chest is safe and spendable at the Trader and the
# bench; Fast Travel only leaves from Oliver's house.

func _initialize() -> void:
	var combat: Node = root.get_node("Combat")
	var items: Node = root.get_node("Items")
	var inventory: Node = root.get_node("Inventory")
	var storage: Node = root.get_node("Storage")
	var shop: Node = root.get_node("Shop")
	var crafting: Node = root.get_node("Crafting")
	var game_state: Node = root.get_node("GameState")
	var save: Node = root.get_node("SaveSystem")
	var defeat: Node = root.get_node("DefeatPanel")
	await process_frame

	print("Angel Feather: consumable, 25 gold, in the Trader's stock, stacks to 5: ", items.ITEMS.has("angel_feather") and items.ITEMS.angel_feather.effect.kind == "escape" and items.ITEMS.angel_feather.value == 25 and shop.SHOP_STOCK.has("angel_feather") and inventory.stack_cap("angel_feather") == 5)
	print("Wild monsters drop one 3% of the time: ", combat.FEATHER_DROP_CHANCE == 0.03)
	# A boss always drops one.
	inventory.backpack.erase("angel_feather")
	root.get_node("Character").stats.max_hp = 500
	root.get_node("Character").stats.hp = 500
	combat.start_combat("dungeon_rat")
	await process_frame
	combat.current_boss_id = "dungeon_boss"
	combat.current_enemies[0].hp = 1
	combat.player_attack()
	for i in range(6):
		await process_frame
	print("A boss always drops an Angel Feather: ", inventory.get_count("angel_feather") == 1 and combat.fight_items.has("Angel Feather"))
	root.get_node("Character").reset()

	# --- Field use: from an interior straight home to the bed. ---
	var dungeon: Node2D = load("res://scenes/FrostpeakInterior.tscn").instantiate()
	root.add_child(dungeon)
	current_scene = dungeon
	for i in range(6):
		await process_frame
	inventory.backpack.erase("angel_feather")
	inventory.add_item("angel_feather", 2)
	var result: Dictionary = items.apply_effect("angel_feather")
	inventory.remove_item("angel_feather", 1)
	for i in range(6):
		await process_frame
	var house_player: CharacterBody2D = current_scene.get_node_or_null("YSort/Player")
	print("Using a feather in Frostpeak lands Oliver by his bed at home: ", result.applied and current_scene.name == "House" and house_player != null and house_player.position == Vector2(combat.NAP_SPAWN_TILE.x * 32 + 16, combat.NAP_SPAWN_TILE.y * 32 + 16) and inventory.get_count("angel_feather") == 1)
	print("At home a feather does nothing and isn't spent: ", not items.apply_effect("angel_feather").applied and game_state.is_home())

	# --- Fast travel: from home only. ---
	var sheet: CanvasLayer = root.get_node("CharacterSheet")
	var world_map: Node = root.get_node("WorldMap")
	game_state.discovered_pois.dungeon = true
	sheet.open("map")
	await process_frame
	sheet.map_view.select_poi("dungeon")
	await process_frame
	print("From the house the Map offers Fast Travel to a discovered place: ", not sheet.map_view.travel_btn.disabled and sheet.map_view.poi_status.text == "Fast Travel lands at its entrance.")
	sheet.close()
	change_scene_to_packed(load("res://scenes/Overworld.tscn"))
	for i in range(6):
		await process_frame
	sheet.open("map")
	await process_frame
	sheet.map_view.select_poi("dungeon")
	await process_frame
	print("Away from home Fast Travel is refused with the walk-or-feather hint: ", sheet.map_view.travel_btn.disabled and sheet.map_view.poi_status.text == "From your house only.")
	root.get_texture().get_image().save_png("res://verify_escape_map.png")
	print("Saved verify_escape_map.png")
	sheet.close()

	# --- Bank: chest gold is spendable at the Trader, carried gold first. ---
	inventory.backpack.erase("gold")
	storage.reset()
	inventory.add_item("gold", 10)
	storage.add_item(inventory.BANK_CHEST, "gold", 50)
	print("Gold available = carried + banked (10 + 50): ", inventory.gold_available() == 60)
	print("A 20-gold potion with 10 on hand: bought, the bank covers the rest (0 carried, 40 banked): ", shop.buy_item("healing_potion") and inventory.get_count("gold") == 0 and storage.get_count(inventory.BANK_CHEST, "gold") == 40)
	crafting.require_station = false
	inventory.add_item("wood", 10)
	inventory.add_item("stone", 10)
	var gold_recipe := ""
	for rid in crafting.RECIPES.keys():
		if crafting.RECIPES[rid].cost.has("gold"):
			gold_recipe = rid
	print("A recipe with a gold cost can be paid from the bank: ", gold_recipe != "" and crafting.can_craft(gold_recipe) and crafting.craft(gold_recipe) and storage.get_count(inventory.BANK_CHEST, "gold") == 40 - int(crafting.RECIPES[gold_recipe].cost.gold))

	# --- A nap costs the pack. ---
	inventory.backpack.erase("healing_potion")
	inventory.add_item("gold", 37)
	inventory.add_item("healing_potion", 2)
	inventory.add_item("magic_crystal", 1)
	inventory.add_item("ironwood_blade", 1) # spare gear, carried
	var bank_before: int = storage.get_count(inventory.BANK_CHEST, "gold")
	var ow_player: CharacterBody2D = current_scene.get_node("YSort/Player")
	ow_player.position = Vector2(999, 999)
	root.get_node("Character").stats.hp = 1
	combat.start_combat("skeleton")
	await process_frame
	combat.player_defend()
	for i in range(40):
		await process_frame
		if not combat.in_combat:
			break
	for i in range(6):
		await process_frame
	var lost: Dictionary = combat.last_defeat
	print("Nap: all carried gold, wood, stone and potions gone; spare blade and the crystal kept; the bank untouched: ", lost.gold_lost == 37 and lost.items_lost.has("healing_potion") and lost.items_lost.has("wood") and inventory.get_count("gold") == 0 and inventory.get_count("wood") == 0 and inventory.get_count("healing_potion") == 0 and inventory.get_count("magic_crystal") == 1 and inventory.get_count("ironwood_blade") == 1 and storage.get_count(inventory.BANK_CHEST, "gold") == bank_before)
	print("The nap panel lists what was lost and reassures about gear and chest: ", defeat.story(lost).contains("Your pack was lost on the way: 37 gold") and defeat.story(lost).contains("What you wear and what's in the chest are safe"))
	root.get_texture().get_image().save_png("res://verify_escape_nap.png")
	print("Saved verify_escape_nap.png")
	defeat.wake_up()
	for i in range(4):
		await process_frame

	# --- Mid-fight feather: the fight ends without a win, Oliver goes home. ---
	change_scene_to_packed(load("res://scenes/Overworld.tscn"))
	for i in range(6):
		await process_frame
	inventory.add_item("angel_feather", 1)
	root.get_node("Character").stats.hp = 50
	combat.start_combat(["bandit", "bandit"])
	await process_frame
	var won := [false]
	combat.won.connect(func() -> void: won[0] = true, CONNECT_ONE_SHOT)
	combat.use_item("angel_feather")
	for i in range(8):
		await process_frame
	print("A feather mid-fight ends the fight (no victory, feather spent) and lands Oliver at home: ", not combat.in_combat and not won[0] and inventory.get_count("angel_feather") == 0 and current_scene.name == "House" and combat.battle_log.back().contains("rush of wings"))
	save.delete_save(save.AUTO_SLOT)
	quit()
