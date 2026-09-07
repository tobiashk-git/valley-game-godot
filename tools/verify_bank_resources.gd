extends SceneTree
# Banked resources verification. Run via:
# godot --script res://tools/verify_bank_resources.gd (NOT --headless).
#
# The house chest is a bank for every stackable: crafting, enhancing and
# quest turn-ins count carried + banked and spend the carried part first;
# the crafting tab shows the banked share; gear in the chest never counts.

func _initialize() -> void:
	var inventory: Node = root.get_node("Inventory")
	var storage: Node = root.get_node("Storage")
	var crafting: Node = root.get_node("Crafting")
	var quests: Node = root.get_node("Quests")
	var character: Node = root.get_node("Character")
	var sheet: CanvasLayer = root.get_node("CharacterSheet")
	await process_frame
	root.get_node("GameState").reset()
	inventory.reset()
	storage.reset()
	character.reset()
	quests.reset()
	crafting.require_station = false
	var bank: String = inventory.BANK_CHEST
	var potion_cost: Dictionary = crafting.RECIPES.healing_potion.cost
	var wood_need: int = int(potion_cost.get("wood", 0))
	var stone_need: int = int(potion_cost.get("stone", 0))

	# --- counting ---
	storage.add_item(bank, "wood", 4)
	inventory.add_item("wood", 1)
	print("available() = carried + banked (1 + 4 wood), banked() = the chest share: ", inventory.available("wood") == 5 and inventory.banked("wood") == 4 and inventory.get_count("wood") == 1)
	storage.add_item(bank, "leather_armor", 1)
	print("Gear in the chest never counts as available: ", inventory.available("leather_armor") == 0 and inventory.banked("leather_armor") == 0)

	# --- crafting draws on the bank, carried first ---
	inventory.reset()
	storage.reset()
	storage.add_item(bank, "wood", wood_need)
	storage.add_item(bank, "stone", stone_need)
	print("A potion is craftable with every ingredient in the chest and nothing carried (needs ", wood_need, " wood, ", stone_need, " stone): ", crafting.can_craft("healing_potion") and inventory.get_count("wood") == 0)
	inventory.add_item("wood", 1)
	print("Crafting it spends the carried wood first, the rest from the chest, and the potion lands in the backpack: ", crafting.craft("healing_potion") and inventory.get_count("wood") == 0 and storage.get_count(bank, "wood") == 1 and storage.get_count(bank, "stone") == 0 and inventory.get_count("healing_potion") == 1)

	# --- the crafting tab shows the banked share ---
	storage.add_item(bank, "wood", 3)
	var house: Node2D = load("res://scenes/House.tscn").instantiate()
	root.add_child(house)
	current_scene = house
	for i in range(3):
		await process_frame
	sheet.open("crafting")
	await process_frame
	await process_frame
	sheet._select_recipe("healing_potion")
	await process_frame
	var row: Node = sheet.craft_rows.get_node_or_null("IngredientWood")
	var count_text: String = row.get_node("Count").text if row != null else "(no row)"
	print("Ingredient row reads carried + banked with the banked share noted (", count_text, "): ", row != null and count_text.begins_with("%d / %d" % [inventory.available("wood"), wood_need]) and count_text.contains("(%d banked)" % storage.get_count(bank, "wood")))
	root.get_texture().get_image().save_png("res://verify_bank_resources.png")
	print("Saved verify_bank_resources.png")
	sheet.close()
	await process_frame

	# --- enhancing draws on the bank ---
	inventory.reset()
	storage.reset()
	inventory.add_item("leather_armor", 1)
	var inst: Dictionary = inventory.gear[0]
	storage.add_item(bank, "monster_fur", 3)
	print("Fur-lined needs 3 fur: all three in the chest count, and the enhancement takes them from there: ", crafting.can_enhance(inst, "fur_lined") and crafting.enhance(inst.uid, "fur_lined") and storage.get_count(bank, "monster_fur") == 0 and inst.mods.size() == 1)

	# --- a gather quest counts and spends the bank ---
	inventory.reset()
	storage.reset()
	quests.quest_state.meet_villagers = "completed"
	quests.quest_state.gather_wood = "accepted"
	storage.add_item(bank, "wood", 3)
	inventory.add_item("wood", 2)
	print("A Village in Need (5 wood): 2 carried + 3 banked counts as met, progress reads 5/5: ", quests.objective_met("gather_wood") and quests.objective_progress_text("gather_wood").begins_with("5/5"))
	var gold_before: int = inventory.get_count("gold")
	quests._complete_quest("gather_wood")
	print("Turning it in takes the carried 2 and 3 from the chest, pays the reward: ", quests.quest_state.gather_wood == "completed" and inventory.get_count("wood") == 0 and storage.get_count(bank, "wood") == 0 and inventory.get_count("gold") == gold_before + 20)
	quit()
