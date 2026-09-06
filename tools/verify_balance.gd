extends SceneTree
# Combat balance pass verification. Run via:
# godot --script res://tools/verify_balance.gd (NOT --headless).
#
# Percentage mitigation (attack x 8/(8+defence)); the enemy table carries
# the biome ladder; potions heal 8, cost 20, stack to 5 (shop and crafting
# refuse past the cap); the Heal spell is 10 HP for 5 MP; quests reward one
# potion; pressing E at the bed restores HP/MP and autosaves.

func _initialize() -> void:
	var combat: Node = root.get_node("Combat")
	var items: Node = root.get_node("Items")
	var inventory: Node = root.get_node("Inventory")
	var character: Node = root.get_node("Character")
	var enemies: Node = root.get_node("Enemies")
	var shop: Node = root.get_node("Shop")
	var crafting: Node = root.get_node("Crafting")
	var quests: Node = root.get_node("Quests")
	var spells: Node = root.get_node("Spells")
	var save: Node = root.get_node("SaveSystem")
	await process_frame

	# --- damage rule ---
	var lo := 999
	var hi := 0
	for i in range(300):
		var d: int = combat._physical_damage(12, 3)
		lo = mini(lo, d)
		hi = maxi(hi, d)
	print("12 power vs 3 defence lands 7-10 (8.7 x 8/11 +-15%), never 9 flat: ", lo >= 7 and hi <= 10 and hi > lo)
	var heavy := 0
	for i in range(100):
		heavy = maxi(heavy, combat._physical_damage(4, 11))
	print("Heavy armour shaves a share, never a flat amount (4 vs 11 -> 1-2, not the old min-1 floor every time): ", heavy <= 2 and combat.ARMOUR_K == 8.0)

	# --- enemy ladder baked into the table ---
	var e: Dictionary = enemies.ENEMIES
	print("Dungeon pool got the flat x1.3 attack only (rat 12 HP / 4 ATK): ", e.dungeon_rat.max_hp == 12 and e.dungeon_rat.attack == 4)
	print("Frostpeak is one ladder step (frost wolf 17 HP / 9 ATK), Gloomfen four (spectral undead 39 / 16): ", e.frost_wolf.max_hp == 17 and e.frost_wolf.attack == 9 and e.spectral_undead.max_hp == 39 and e.spectral_undead.attack == 16)
	var b: Dictionary = enemies.BOSSES
	print("Bosses climb x1.25 a tier (Bone Lord unchanged 60/8, Revenant 88/10, Bogmaw 195/22), the Ancient Warden held at tier 2 (234/27): ", b.dungeon_boss.max_hp == 60 and b.dungeon_boss.attack == 8 and b.frostpeak_boss.max_hp == 88 and b.frostpeak_boss.attack == 10 and b.gloomfen_boss.max_hp == 195 and b.gloomfen_boss.attack == 22 and b.final_boss.max_hp == 234 and b.final_boss.attack == 27)

	# --- potions ---
	print("Healing potion restores 8 and costs 20; Heal spell 10 HP for 5 MP: ", items.ITEMS.healing_potion.effect.amount == 8 and items.ITEMS.healing_potion.value == 20 and spells.SPELLS.heal.power == 10 and spells.SPELLS.heal.mp_cost == 5)
	inventory.backpack.erase("healing_potion")
	inventory.add_item("healing_potion", 9)
	print("Consumables stack to 5 (adding 9 keeps 5); materials are uncapped: ", inventory.get_count("healing_potion") == 5 and inventory.CONSUMABLE_CAP == 5 and inventory.stack_cap("wood") == 0 and not inventory.can_add("healing_potion") and inventory.can_add("wood", 999))
	inventory.add_item("gold", 100)
	var gold_before: int = inventory.get_count("gold")
	print("The Trader refuses a sixth potion (gold untouched): ", not shop.buy_item("healing_potion") and inventory.get_count("gold") == gold_before)
	inventory.remove_item("healing_potion", 1)
	print("...and sells one once there's room: ", shop.buy_item("healing_potion") and inventory.get_count("healing_potion") == 5 and inventory.get_count("gold") == gold_before - 20)
	inventory.add_item("wood", 20)
	inventory.add_item("stone", 20)
	crafting.require_station = false
	print("Crafting a potion is blocked at the cap, allowed with room: ", not crafting.can_craft("healing_potion") and (func() -> bool:
		inventory.remove_item("healing_potion", 1)
		return crafting.can_craft("healing_potion")).call())
	var rewards_ok := true
	for qid in quests.QUEST_DEFS.keys():
		var reward: Dictionary = quests.QUEST_DEFS[qid].get("reward", {})
		if reward.get("item_id", "") == "healing_potion" and reward.get("item_amount", 1) != 1:
			rewards_ok = false
	print("Every quest rewards a single potion: ", rewards_ok)

	# --- bed rest ---
	save.delete_save(save.AUTO_SLOT)
	var house: Node2D = load("res://scenes/House.tscn").instantiate()
	root.add_child(house)
	current_scene = house
	for i in range(4):
		await process_frame
	var bed: Node = null
	for child in house.get_node("YSort").get_children():
		if child.scene_file_path == "res://scenes/props/Bed.tscn":
			bed = child
	print("The bed has an interact area and the rest script: ", bed != null and bed.has_node("InteractArea") and bed.has_method("rest"))
	character.stats.hp = 3
	character.stats.mp = 1
	var player: CharacterBody2D = house.get_node("YSort/Player")
	player.position = Vector2(3 * 32 + 16, 5 * 32 + 16) # beside the bed (the spawn itself is now mid-room)
	for i in range(8):
		await physics_frame
	await process_frame
	Input.action_press("interact")
	await process_frame
	Input.action_release("interact")
	await process_frame
	await process_frame
	print("E beside the bed restores HP and MP to full and autosaves: ", character.stats.hp == character.stats.max_hp and character.stats.mp == character.stats.max_mp and save.has_save(save.AUTO_SLOT))
	root.get_texture().get_image().save_png("res://verify_balance_rest.png")
	print("Saved verify_balance_rest.png")
	save.delete_save(save.AUTO_SLOT)
	quit()
