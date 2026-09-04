extends SceneTree
# Crafting tab + gear instances + enhancements verification (UI redesign
# Phase 2). Run via: godot --script res://tools/verify_crafting_tab.gd
# (NOT --headless - takes real screenshots).
#
# Craft mode: recipe grid, ingredient checklist with have/need, Craft
# disabled until affordable, crafting consumes and produces (gear as an
# instance). Enhance mode: carried and worn gear listed, the enhancement
# that fits with its own checklist, enhancing adds the mod (name, stats,
# combat totals), a second application replaces rather than stacks. Plus
# the model around it: Ember Core is a chance drop from a Badlands enemy,
# an enhanced piece survives a chest round-trip, and selling by base id
# takes the plain copy first at base price.

func _press(action: String) -> void:
	Input.action_press(action)
	await process_frame
	Input.action_release(action)
	await process_frame
	await process_frame

func _rows_have(rows: VBoxContainer, item_id: String) -> String:
	var row: Node = rows.get_node_or_null("Ingredient" + item_id.to_pascal_case())
	return row.get_node("Count").text if row else ""

func _initialize() -> void:
	var sheet: CanvasLayer = root.get_node("CharacterSheet")
	var inventory: Node = root.get_node("Inventory")
	var character: Node = root.get_node("Character")
	var combat: Node = root.get_node("Combat")
	var crafting: Node = root.get_node("Crafting")
	var items: Node = root.get_node("Items")
	var storage: Node = root.get_node("Storage")
	var storage_panel: Node = root.get_node("StoragePanel")
	var shop: Node = root.get_node("Shop")

	var overworld: Node2D = load("res://scenes/Overworld.tscn").instantiate()
	root.add_child(overworld)
	current_scene = overworld
	await process_frame
	await process_frame

	# --- Open on the Crafting tab via R. ---
	await _press("toggle_crafting")
	print("R opens the sheet on the Crafting tab in Craft mode: ", sheet.is_open() and sheet.current_tab == "crafting" and sheet.craft_mode == "craft")
	print("Standalone Crafting panel is gone: ", not root.has_node("CraftingPanel"))
	print("One recipe slot per recipe: ", sheet.craft_grid.get_child_count() == crafting.RECIPES.size())

	# --- Craft a potion: checklist red -> green, button disabled -> enabled. ---
	sheet.craft_grid.get_node("RecipeHealingPotionSlot").pressed.emit()
	await process_frame
	print("Selecting a recipe shows its checklist: ", sheet.craft_name.text == "Healing Potion" and _rows_have(sheet.craft_rows, "wood") == "0 / 2" and _rows_have(sheet.craft_rows, "stone") == "0 / 1")
	print("Craft disabled without ingredients: ", sheet.craft_action.visible and sheet.craft_action.disabled)
	inventory.add_item("wood", 2)
	inventory.add_item("stone", 1)
	await process_frame
	print("Checklist updates and Craft enables once affordable: ", _rows_have(sheet.craft_rows, "wood") == "2 / 2" and not sheet.craft_action.disabled)
	root.get_texture().get_image().save_png("res://verify_craft_mode.png")
	print("Saved verify_craft_mode.png")
	sheet.craft_action.pressed.emit()
	await process_frame
	print("Crafting consumes the ingredients and makes the potion: ", inventory.get_count("healing_potion") == 1 and inventory.get_count("wood") == 0 and inventory.get_count("stone") == 0)
	print("Craft disabled again after spending the ingredients: ", sheet.craft_action.disabled)
	# --- Feedback (user: "not obvious that something has happened"): the
	# button reads Crafted!, the checklist gives way to a line naming the
	# item and the new count, the pane says how many you carry, and it all
	# clears itself after a moment. Recipes are drawn as blueprints. ---
	print("Craft feedback shows: Crafted! + what you now have: ", sheet.flash_kind == "craft" and sheet.craft_action.text == "Crafted!" and sheet.flash_label.visible and sheet.flash_label.text.contains("Crafted Healing Potion") and sheet.flash_label.text.contains("you now have 1") and not sheet.craft_rows_scroll.visible)
	print("Pane counts the result in the backpack: ", sheet.craft_type.text == "Consumable  -  you have 1")
	root.get_texture().get_image().save_png("res://verify_craft_flash.png")
	print("Saved verify_craft_flash.png")
	await create_timer(sheet.FLASH_SECONDS + 0.3).timeout
	print("Feedback clears itself after a moment: ", sheet.flash_kind == "" and sheet.craft_action.text == "Craft" and sheet.craft_rows_scroll.visible and not sheet.flash_label.visible)
	print("Recipe slots and the pane icon are drawn as blueprints (blue tint): ", sheet.craft_grid.get_node("RecipeHealingPotionSlot").get_theme_color("icon_normal_color") == sheet.BLUEPRINT_TINT and sheet.craft_icon.modulate == sheet.BLUEPRINT_TINT)

	# --- Craft gear -> an instance. ---
	inventory.add_item("wood", 4)
	inventory.add_item("stone", 4)
	sheet.craft_grid.get_node("RecipeLeatherArmorSlot").pressed.emit()
	await process_frame
	sheet.craft_action.pressed.emit()
	await process_frame
	print("Crafted gear is a gear instance: ", inventory.gear.size() == 1 and inventory.gear[0].base == "leather_armor" and inventory.gear[0].mods.is_empty() and inventory.get_count("leather_armor") == 1)
	var armor_uid: int = inventory.gear[0].uid

	# --- Enhance mode: carried armour, Fur-lined needs 3 fur. ---
	sheet.enhance_mode_btn.pressed.emit()
	await process_frame
	print("Enhance mode lists the carried armour and picks it: ", sheet.craft_mode == "enhance" and sheet.craft_grid.get_node_or_null("EnhanceLeatherArmorSlot") != null and sheet.enhance_uid == armor_uid)
	print("Fur-lined offered with its checklist, disabled without fur: ", sheet.selected_enhancement == "fur_lined" and _rows_have(sheet.craft_rows, "monster_fur") == "0 / 3" and sheet.craft_action.disabled and sheet.craft_desc.text == "No enhancement yet.")
	inventory.add_item("monster_fur", 3)
	await process_frame
	print("Enhance enables with the fur: ", not sheet.craft_action.disabled)
	root.get_texture().get_image().save_png("res://verify_enhance_mode.png")
	print("Saved verify_enhance_mode.png")
	sheet.craft_action.pressed.emit()
	await process_frame
	var armor: Dictionary = inventory.find_gear(armor_uid)
	print("Enhancing adds the mod and spends the fur: ", armor.mods.size() == 1 and armor.mods[0].label == "Fur-lined" and inventory.get_count("monster_fur") == 0)
	print("Enhanced name and stats: ", items.instance_name(armor) == "Fur-lined Leather Armor" and items.instance_stat(armor, "defense") == 4 and items.describe_instance(armor) == "Defense +3, Fur-lined +1")
	print("Enhance feedback shows: Enhanced! + the new name: ", sheet.flash_kind == "enhance" and sheet.craft_action.text == "Enhanced!" and sheet.flash_label.text.contains("Leather Armor is now Fur-lined Leather Armor"))
	print("Pane now shows the current enhancement and 'Replaces': ", sheet.craft_desc.text == "Current: Fur-lined" and sheet.craft_name.text == "Fur-lined Leather Armor")

	# --- Equip it: totals include the mod, combat reads them. ---
	character.equip("armor", armor_uid)
	await process_frame
	print("Equipped enhanced armour counts in gear_total and combat: ", character.gear_total("defense") == 4 and combat._player_defense_bonus() == 4 and sheet.stats_label.text.ends_with("DEF 4"))

	# --- Enhance a WORN item (the pickaxe) with an ember core. ---
	inventory.add_item("wooden_pickaxe", 1)
	var pick_uid: int = inventory.gear[0].uid
	character.equip("weapon", pick_uid)
	inventory.add_item("ember_core", 1)
	await process_frame
	var worn_slot: Button = sheet.craft_grid.get_node_or_null("EnhanceWoodenPickaxeSlot")
	print("Worn gear is listed (badged) in Enhance mode: ", worn_slot != null and worn_slot.has_node("Worn"))
	worn_slot.pressed.emit()
	await process_frame
	print("Ember-forged offered for the worn weapon: ", sheet.selected_enhancement == "ember_forged" and sheet.craft_type.text.ends_with("worn") and not sheet.craft_action.disabled)
	sheet.craft_action.pressed.emit()
	await process_frame
	print("Enhancing a worn item works in place: ", character.equipped("weapon").mods.size() == 1 and character.gear_total("attack") == 4 and combat._weapon_attack_bonus() == 4 and sheet.bonus_label.text == "ATK +4 (Ember-forged Wooden Pickaxe)" and inventory.get_count("ember_core") == 0)
	root.get_texture().get_image().save_png("res://verify_enhance_worn.png")
	print("Saved verify_enhance_worn.png")

	# --- Replacement rule: applying again doesn't stack. ---
	inventory.add_item("ember_core", 1)
	await process_frame
	sheet.craft_action.pressed.emit()
	await process_frame
	print("Re-enhancing replaces rather than stacks: ", character.equipped("weapon").mods.size() == 1 and character.gear_total("attack") == 4)

	# --- Ember Core is a chance drop from a Badlands enemy. ---
	sheet.close()
	var cores_before: int = inventory.get_count("ember_core")
	var kills := 40
	for i in range(kills):
		combat.start_combat("fire_drake")
		character.stats.hp = 500
		combat.current_enemies[0].hp = 1
		combat.player_attack()
		await process_frame
		while combat.in_combat:
			combat.player_run()
			await process_frame
	var cores: int = inventory.get_count("ember_core") - cores_before
	print("Ember Core drops from Fire Drakes by chance (", cores, " of ", kills, " kills, 50% expected): ", cores >= 8 and cores <= 32)
	print("Fur still always drops: ", inventory.get_count("monster_fur") == kills)

	# --- Chest round-trip keeps the enhancement. ---
	character.unequip("armor")
	storage_panel.open_storage("house_chest")
	await process_frame
	storage_panel._on_deposit_gear(armor_uid)
	await process_frame
	print("Enhanced armour goes into the chest as an instance: ", inventory.find_gear(armor_uid).is_empty() and storage.get_gear("house_chest").size() == 1 and storage.get_gear("house_chest")[0].mods.size() == 1)
	storage_panel._on_withdraw_gear(armor_uid)
	await process_frame
	print("...and comes back intact: ", inventory.find_gear(armor_uid).mods.size() == 1 and storage.get_gear("house_chest").is_empty())
	storage_panel.close()

	# --- Selling by base id takes the plain copy first, at base price. ---
	inventory.add_item("leather_armor", 1)
	var gold_before: int = inventory.get_count("gold")
	print("Selling armour sells the plain one first: ", shop.sell_item("leather_armor") and inventory.get_count("leather_armor") == 1 and not inventory.find_gear(armor_uid).is_empty() and inventory.get_count("gold") == gold_before + shop.sell_price("leather_armor"))
	print("Enhanced piece sells at base price: ", shop.sell_item("leather_armor") and inventory.get_count("gold") == gold_before + 2 * shop.sell_price("leather_armor") and inventory.gear.is_empty())

	quit()
