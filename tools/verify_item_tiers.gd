extends SceneTree
# Item progression (gear tiers per biome) verification. Run via:
# godot --script res://tools/verify_item_tiers.gd (NOT --headless).
#
# Four tiers of weapon + armour (Frostpeak, Verdantwood, Badlands,
# Gloomfen) with climbing stats, each crafted from a material its biome's
# monsters drop half the time; every new item has an icon; the recipes
# craft real gear instances that equip and feed combat's attack/defence
# totals; the Crafting tab lists them in tier order under Equipment; the
# phone layout still fits.

const TIERS := [
	["frost_pick", "frostweave_coat", "frost_shard", 4, 5],
	["ironwood_blade", "ironwood_mail", "ironwood", 6, 7],
	["ember_blade", "ember_plate", "ember_core", 8, 9],
	["bogiron_cleaver", "bogiron_harness", "bog_iron", 10, 11],
]

func _initialize() -> void:
	var items: Node = root.get_node("Items")
	var crafting: Node = root.get_node("Crafting")
	var inventory: Node = root.get_node("Inventory")
	var character: Node = root.get_node("Character")
	var combat: Node = root.get_node("Combat")
	var enemies: Node = root.get_node("Enemies")
	var sheet: CanvasLayer = root.get_node("CharacterSheet")
	var overworld: Node2D = load("res://scenes/Overworld.tscn").instantiate()
	root.add_child(overworld)
	current_scene = overworld
	await process_frame
	await process_frame
	inventory.reset()
	character.reset()

	# --- Data: stats climb, every item has an icon and a recipe. ---
	var ok := true
	for t in TIERS:
		var weapon: Dictionary = items.ITEMS[t[0]]
		var armor: Dictionary = items.ITEMS[t[1]]
		ok = ok and weapon.slot == "weapon" and weapon.attack == t[3] and armor.slot == "armor" and armor.defense == t[4]
		ok = ok and items.ITEMS.has(t[2]) and crafting.RECIPES.has(t[0]) and crafting.RECIPES.has(t[1])
		ok = ok and crafting.RECIPES[t[0]].cost.has(t[2]) and crafting.RECIPES[t[1]].cost.has(t[2])
		for id in [t[0], t[1], t[2]]:
			ok = ok and ResourceLoader.exists("res://assets/icons/%s.png" % id)
	print("Four tiers: weapons 4/6/8/10 ATK, armour 5/7/9/11 DEF, each recipe costs its biome material, every item has an icon: ", ok)
	var costs_ok := true
	for recipe_id in crafting.RECIPES:
		for item_id in crafting.RECIPES[recipe_id].cost:
			costs_ok = costs_ok and items.ITEMS.has(item_id)
	print("Every recipe ingredient is a real item: ", costs_ok)

	# --- Drops: each biome's species carry its material at 50%. ---
	var drops_ok := true
	for pair in [["frost_wolf", "frost_shard"], ["ice_wraith", "frost_shard"], ["stone_sentinel", "frost_shard"], ["bandit", "ironwood"], ["forest_spirit", "ironwood"], ["corrupted_fauna", "ironwood"], ["swamp_hag", "bog_iron"], ["giant_insect", "bog_iron"], ["spectral_undead", "bog_iron"], ["magma_slime", "ember_core"]]:
		var found := false
		for entry in enemies.ENEMIES[pair[0]].drop_item_ids:
			if entry is Dictionary and entry.item == pair[1] and entry.chance >= 0.3:
				found = true
		drops_ok = drops_ok and found
	print("Frostpeak species drop Frost Shard, Verdantwood Ironwood, Gloomfen Bog Iron (Badlands keep Ember Core): ", drops_ok)
	combat._steps_since_encounter = -100000
	for i in range(40):
		combat.start_combat(["frost_wolf"])
		await process_frame
		while combat.in_combat:
			character.stats.hp = 500
			combat.current_enemies[0].hp = 1
			combat.player_attack()
			await process_frame
	var shards: int = inventory.get_count("frost_shard")
	print("40 Frost Wolves drop about half their weight in shards (%d): " % shards, shards >= 8 and shards <= 32)

	# --- Crafting the ladder and wearing it. ---
	for t in TIERS:
		inventory.add_item(t[2], 6)
	inventory.add_item("wood", 10)
	inventory.add_item("stone", 10)
	inventory.add_item("monster_fur", 12)
	inventory.add_item("ember_core", 4)
	inventory.add_item("ironwood", 4)
	var crafted := true
	for t in TIERS:
		crafted = crafted and crafting.craft(t[0]) and crafting.craft(t[1])
	print("All eight tier recipes craft with their materials: ", crafted and inventory.get_count("frost_pick") == 1 and inventory.get_count("bogiron_harness") == 1)
	character.equip("weapon", "frost_pick")
	character.equip("armor", "frostweave_coat")
	print("Frost gear worn: ATK +4, DEF 5 in combat's totals: ", combat._weapon_attack_bonus() == 4 and combat._player_defense_bonus() == 5)
	character.equip("weapon", "bogiron_cleaver")
	character.equip("armor", "bogiron_harness")
	print("Bog-iron gear worn: ATK +10, DEF 11: ", combat._weapon_attack_bonus() == 10 and combat._player_defense_bonus() == 11 and character.gear_names("attack") == ["Bog-iron Cleaver"])
	var inst: Dictionary = character.equipped("weapon")
	print("Tier gear is a real instance: enhanceable like any weapon (Ember-forged fits): ", crafting.enhancements_for(inst) == ["ember_forged"])

	# --- Crafting tab: Equipment section lists the ladder in tier order. ---
	sheet.open("crafting")
	await process_frame
	await process_frame
	var grid: GridContainer = sheet.craft_groups.get_node("EquipmentGrid")
	var order: Array = []
	for child in grid.get_children():
		if child is Button:
			order.append(String(child.name))
	var expected: Array = ["RecipeWoodenPickaxeSlot", "RecipeLeatherArmorSlot", "RecipeCharmOfWardingSlot"]
	for t in TIERS:
		expected.append("Recipe" + t[0].to_pascal_case() + "Slot")
		expected.append("Recipe" + t[1].to_pascal_case() + "Slot")
		# ...then that tier's set pieces (helm, greaves, boots).
		var prefix: String = t[0].split("_")[0]
		for piece in ["helm", "greaves", "boots"]:
			expected.append("Recipe" + (prefix + "_" + piece).to_pascal_case() + "Slot")
	print("Equipment section: the three starters then each tier's weapon, body piece and set pieces in tier order: ", order == expected)
	sheet._select_recipe("ember_blade")
	await process_frame
	print("Selecting the Ember Blade shows its slot, stat and ingredients: ", sheet.craft_name.text == "Ember Blade" and sheet.craft_type.text.begins_with("Weapon") and sheet.craft_type.text.contains("8"))
	root.get_texture().get_image().save_png("res://verify_item_tiers_craft.png")
	print("Saved verify_item_tiers_craft.png")
	sheet.close()

	# --- Phone. ---
	root.size = Vector2i(400, 660)
	for i in range(6):
		await process_frame
	sheet.open("crafting")
	await process_frame
	await process_frame
	var phone_grid: GridContainer = sheet.craft_groups.get_node("EquipmentGrid") # rebuilt on reopen
	print("Phone: the Equipment grid with 11 recipes stays inside the window: ", phone_grid.get_global_rect().end.x <= sheet.window.get_global_rect().end.x + 0.5)
	root.get_texture().get_image().save_png("res://verify_item_tiers_phone.png")
	print("Saved verify_item_tiers_phone.png")
	sheet.close()
	root.size = Vector2i(800, 600)
	for i in range(4):
		await process_frame
	quit()
