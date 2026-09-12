extends SceneTree
# Shop window verification (UI redesign Phase 3: the Trader's shop on the
# character sheet's kit). Run via: godot --script res://tools/verify_shop.gd
# (NOT --headless - takes real screenshots).
#
# Reaches the shop the way a player does (intro dialogue, then the barrow
# quest which npc.gd puts ahead of the shop, then walk-up + E), then: Buy
# tab with price badges and a Buy that's disabled while broke; Sell tab
# listing stackables with counts and gear per instance (enhanced piece sold
# by itself at base price, equipped gear absent, gold absent); Sell one and
# Sell all; E closes and stays closed.

func _press_e() -> void:
	Input.action_press("interact")
	await process_frame
	await process_frame
	Input.action_release("interact")
	await process_frame

func _initialize() -> void:
	var trader_scene: PackedScene = load("res://scenes/TraderHouse.tscn")
	var trader_house: Node2D = trader_scene.instantiate()
	root.add_child(trader_house)
	current_scene = trader_house
	await process_frame
	await process_frame

	var inventory: Node = root.get_node("Inventory")
	var shop: Node = root.get_node("Shop")
	var items: Node = root.get_node("Items")
	var game_state: Node = root.get_node("GameState")
	var shop_panel: Node = root.get_node("ShopPanel")
	var quests: Node = root.get_node("Quests")
	quests.quest_state["meet_villagers"] = "completed" # the gateway quest - the barrow quest waits for it
	var crafting: Node = root.get_node("Crafting")
	var tracker: Node = root.get_node("QuestTracker")
	var player: CharacterBody2D = trader_house.get_node("YSort/Player")

	var ysort: Node2D = trader_house.get_node("YSort")
	var trader: Node = null
	for child in ysort.get_children():
		if child.name.begins_with("NPC"):
			trader = child
	print("Trader NPC found: ", trader != null)

	player.position = trader.position + Vector2(0, 20)
	for i in range(3):
		await process_frame

	# --- Dismiss the one-time intro; the Trader is a plain shop since the
	# barrow quest moved to the Elder (2026-09-08). ---
	var dialogue_ui: Node = root.get_node("DialogueUI")
	await _press_e()
	print("Intro shown first: ", dialogue_ui.text_label.text.begins_with("Welcome, welcome"))
	await _press_e()
	print("The Trader carries no quest (a shop from the first E after the intro): ", trader.quest_ids.is_empty() and trader.quest_id == "" and quests.quest_state.get("open_ancient_barrow", "") == "")

	# --- Walk up + E opens the shop window. ---
	await _press_e()
	print("Shop opened via walk-up + E: ", shop_panel.is_open())
	print("Old list panel is gone; it's a kit window (Window/Grid/DetailPane): ", not shop_panel.has_node("Panel") and shop_panel.has_node("Window/GridScroll/Grid") and shop_panel.has_node("Window/DetailPane"))
	print("Defaults to the Buy tab (active tab styling): ", shop_panel.tab == 0 and shop_panel.buy_tab_btn.theme_type_variation == &"TabButtonActive" and shop_panel.sell_tab_btn.theme_type_variation == &"TabButton")
	print("Title row shows gold on hand: ", shop_panel.subtitle_label.text == "Gold on hand: 0")
	print("Quest tracker hidden while the shop is open: ", not tracker.visible)
	print("One slot per stock item, badged with its price: ", shop_panel.grid.get_child_count() == shop.stock_for("village_trader").size() and shop_panel.grid.get_node("HealingPotionSlot").get_node("Count").text == "20g" and shop_panel.title_label.text == "Trader's Shop")
	var armour_slots: Array = ["weapon", "armor", "head", "legs", "feet", "hands"]
	print("The Trader sells potions, the charm and resources - no armour or weapons: ", shop.stock_for("village_trader").has("wood") and shop.stock_for("village_trader").has("charm_of_warding") and not shop.stock_for("village_trader").any(func(id: String) -> bool: return armour_slots.has(items.ITEMS[id].get("slot", ""))) and shop.stock_for("village_blacksmith").is_empty())
	print("Resources cost five times their value (wood %d, monster fur %d, ember core %d; potion %d) - gathering is the better deal - and sell for half their value (fur %d): " % [shop.buy_price("wood"), shop.buy_price("monster_fur"), shop.buy_price("ember_core"), shop.buy_price("healing_potion"), shop.sell_price("monster_fur")], shop.buy_price("wood") == 5 and shop.buy_price("monster_fur") == 20 and shop.buy_price("ember_core") == 75 and shop.sell_price("monster_fur") == 2 and shop.buy_price("healing_potion") == 20)
	var shard_slot: Button = shop_panel.grid.get_node("FrostShardSlot")
	print("A biome's resource is a locked teaser until its ford opens: blueprint-tinted, badged '?', not buyable (monster fur waits for the first biome too): ", not shop.resource_available("frost_shard") and not shop.resource_available("monster_fur") and shop.resource_available("wood") and shard_slot.get_node("Count").text == "?" and shard_slot.modulate.a < 0.7 and shop_panel.grid.get_node("WoodSlot").get_node("Count").text == "5g" and not shop.buy_item("frost_shard"))
	shard_slot.pressed.emit()
	await process_frame
	print("Its pane says where it comes from and offers no Buy: ", shop_panel.detail_value.text.contains("northern ford") and not shop_panel.primary_action.visible)
	game_state.biome_paths_open.frostpeak = true
	shop_panel._refresh()
	await process_frame
	shop_panel.grid.get_node("FrostShardSlot").pressed.emit()
	await process_frame
	shard_slot = shop_panel.grid.get_node("FrostShardSlot") # (a press rebuilds the grid)
	print("With the northern ford open the frost shard is on the shelf at 30 gold (and the fur): ", shop.resource_available("frost_shard") and shop.resource_available("monster_fur") and shard_slot.get_node("Count").text == "30g" and shop_panel.primary_action.visible and shop_panel.detail_value.text.begins_with("Costs 30 gold"))
	game_state.biome_paths_open.frostpeak = false
	shop_panel.selected_item = ""
	shop_panel.selected_uid = 0
	shop_panel._refresh()
	await process_frame
	print("Nothing selected -> pane prompts: ", shop_panel.detail_name.text == "Select an item" and not shop_panel.primary_action.visible)

	# --- Select the potion: details + Buy disabled while broke. ---
	shop_panel.grid.get_node("HealingPotionSlot").pressed.emit()
	await process_frame
	print("Selecting shows the item: ", shop_panel.detail_name.text == "Healing Potion" and shop_panel.detail_type.text == "Consumable" and shop_panel.detail_desc.text.contains("Restores 8 HP") and shop_panel.detail_value.text == "Costs 20 gold  -  you have 0")
	print("Buy offered but disabled while broke: ", shop_panel.primary_action.visible and shop_panel.primary_action.text == "Buy" and shop_panel.primary_action.disabled and not shop_panel.secondary_action.visible)
	root.get_texture().get_image().save_png("res://verify_shop_buy_broke.png")
	print("Saved verify_shop_buy_broke.png")

	# --- Give gold, buy a potion. ---
	inventory.add_item("gold", 100)
	await process_frame
	print("Buy enables with gold and the subtitle updates: ", not shop_panel.primary_action.disabled and shop_panel.subtitle_label.text == "Gold on hand: 100")
	var gold_before: int = inventory.get_count("gold")
	shop_panel.primary_action.pressed.emit()
	await process_frame
	print("Potion bought, gold deducted (20): ", inventory.get_count("healing_potion") == 1 and inventory.get_count("gold") == gold_before - 20)
	print("Selection kept, pane counts the new one: ", shop_panel.selected_item == "healing_potion" and shop_panel.detail_value.text == "Costs 20 gold  -  you have 1")
	root.get_texture().get_image().save_png("res://verify_shop_after_buy.png")
	print("Saved verify_shop_after_buy.png")

	# --- Sell tab: stackables with counts, gear per instance; equipped gear
	# and gold absent. ---
	inventory.add_item("wood", 3)
	var character: Node = root.get_node("Character")
	inventory.add_item("wooden_pickaxe", 1)
	character.equip("weapon", "wooden_pickaxe")
	inventory.add_item("leather_armor", 2)
	inventory.add_item("monster_fur", 3)
	var enhanced_uid: int = inventory.gear[1].uid
	crafting.enhance(enhanced_uid, "fur_lined")
	inventory.remove_item("monster_fur", inventory.get_count("monster_fur"))
	inventory.add_item("magic_crystal", 1)
	shop_panel.sell_tab_btn.pressed.emit()
	await process_frame
	print("Sell tab active: ", shop_panel.tab == 1 and shop_panel.sell_tab_btn.theme_type_variation == &"TabButtonActive")
	var names: Array = []
	for child in shop_panel.grid.get_children():
		if child.visible:
			names.append(child.name)
	print("Sell grid: ", names)
	print("Wood (count badge 3) and the bought potion listed: ", shop_panel.grid.get_node_or_null("WoodSlot") != null and shop_panel.grid.get_node("WoodSlot").get_node("Count").text == "3" and shop_panel.grid.get_node_or_null("HealingPotionSlot") != null)
	print("Two armour instances listed separately, the enhanced one starred: ", shop_panel.grid.get_node_or_null("LeatherArmorSlot") != null and shop_panel.grid.get_node_or_null("LeatherArmorSlot2") != null and shop_panel.grid.get_node("LeatherArmorSlot2").has_node("Enhanced"))
	print("Gold, the quest crystal and the equipped pickaxe are not for sale: ", not names.has("GoldSlot") and not names.has("MagicCrystalSlot") and not names.has("WoodenPickaxeSlot"))
	root.get_texture().get_image().save_png("res://verify_shop_sell_tab.png")
	print("Saved verify_shop_sell_tab.png")

	# --- Sell the enhanced armour specifically: that instance goes, the
	# plain one stays, base price paid. ---
	shop_panel.grid.get_node("LeatherArmorSlot2").pressed.emit()
	await process_frame
	print("Selecting the enhanced piece names it, no Sell all for gear: ", shop_panel.selected_uid == enhanced_uid and shop_panel.detail_name.text == "Fur-lined Leather Armor" and shop_panel.detail_value.text == "Sells for 10 gold  -  you have 2" and shop_panel.primary_action.text == "Sell" and not shop_panel.secondary_action.visible)
	var gold_before_gear: int = inventory.get_count("gold")
	shop_panel.primary_action.pressed.emit()
	await process_frame
	print("Enhanced armour sold by itself at base price; plain one remains: ", inventory.find_gear(enhanced_uid).is_empty() and inventory.get_count("leather_armor") == 1 and inventory.gear_of("leather_armor")[0].mods.is_empty() and inventory.get_count("gold") == gold_before_gear + 10)
	print("Selection cleared once the piece is gone: ", shop_panel.selected_uid == 0 and shop_panel.detail_name.text == "Select an item")

	# --- Sell one wood, then Sell all. ---
	shop_panel.grid.get_node("WoodSlot").pressed.emit()
	await process_frame
	print("Stack offers Sell and Sell all: ", shop_panel.primary_action.text == "Sell" and shop_panel.secondary_action.visible and shop_panel.secondary_action.text == "Sell all (3) for 3 gold")
	var gold_before_sell: int = inventory.get_count("gold")
	shop_panel.primary_action.pressed.emit()
	await process_frame
	print("Sell one: wood 3 -> 2, +1 gold (half of 1, min 1): ", inventory.get_count("wood") == 2 and inventory.get_count("gold") == gold_before_sell + 1)
	print("Badge and pane follow the count: ", shop_panel.grid.get_node("WoodSlot").get_node("Count").text == "2" and shop_panel.secondary_action.text == "Sell all (2) for 2 gold")
	shop_panel.secondary_action.pressed.emit()
	await process_frame
	print("Sell all: wood gone, +2 gold, slot gone, selection cleared: ", inventory.get_count("wood") == 0 and inventory.get_count("gold") == gold_before_sell + 3 and shop_panel.grid.get_node_or_null("WoodSlot") == null and shop_panel.selected_item == "")

	# --- Close via E, confirm it stays closed. ---
	await _press_e()
	print("Shop closed via E: ", not shop_panel.is_open())
	print("Quest tracker back: ", tracker.visible or root.get_node("Quests").tracked_quests.is_empty())
	await _press_e()
	await process_frame
	print("E reopens it, X closes it: ", shop_panel.is_open())
	shop_panel.close_btn.pressed.emit()
	await process_frame
	print("X closed: ", not shop_panel.is_open())

	quit()
