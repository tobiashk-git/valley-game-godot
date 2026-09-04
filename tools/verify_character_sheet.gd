extends SceneTree
# CharacterSheet verification (UI redesign Phase 1). Run via:
# godot --script res://tools/verify_character_sheet.gd (NOT --headless -
# takes real screenshots via get_texture()).
#
# The tabbed window that replaced the Inventory + Character popups: opens
# on I / C / the toolbar, header shows portrait + HP/MP + stats + equipment
# slots, backpack grid with 64px slots and count badges, tap -> detail pane
# -> Use / Equip / Unequip actually work, tabs switch, Esc and combat close
# it, the quick bar hides while it's up, the Crafting tab hands off to the
# old Crafting panel, and a phone-shaped viewport still fits it.

func _press(action: String) -> void:
	Input.action_press(action)
	await process_frame
	Input.action_release(action)
	await process_frame
	await process_frame

func _initialize() -> void:
	var sheet: CanvasLayer = root.get_node("CharacterSheet")
	var inventory: Node = root.get_node("Inventory")
	var character: Node = root.get_node("Character")
	var combat: Node = root.get_node("Combat")
	var quick_bar: CanvasLayer = root.get_node("QuickBar")
	var panel_buttons: Node = root.get_node("PanelButtons")
	var crafting_panel: Node = root.get_node("CraftingPanel")
	var old_inventory: Node = root.get_node("InventoryPanel")
	var old_character: Node = root.get_node("CharacterPanel")

	var overworld: Node2D = load("res://scenes/Overworld.tscn").instantiate()
	root.add_child(overworld)
	current_scene = overworld
	await process_frame
	await process_frame
	for entry in [["wood", 14], ["stone", 9], ["monster_fur", 5], ["healing_potion", 2], ["mana_potion", 1], ["wooden_pickaxe", 1], ["leather_armor", 1], ["bone_greatsword", 1]]:
		inventory.add_item(entry[0], entry[1])
	await process_frame

	# --- Opening. ---
	await _press("toggle_inventory")
	print("I opens the sheet on the Inventory tab: ", sheet.is_open() and sheet.current_tab == "inventory")
	print("Old Inventory/Character popups stay closed: ", not old_inventory.is_open() and not old_character.is_open())
	print("Quick bar hidden while the sheet is open: ", not quick_bar.visible)
	print("Window sits below the toolbar row (y >= 52) and inside the viewport: ", sheet.window.position.y >= 52.0 and sheet.window.position.y + sheet.window.size.y <= 600.0)

	# --- Header. ---
	var stats: Dictionary = character.stats
	print("Header shows the portrait: ", sheet.portrait.texture != null)
	print("Header HP/MP track Character.stats: ", sheet.hp_label.text == "HP %d / %d" % [stats.hp, stats.max_hp] and sheet.mp_label.text == "MP %d / %d" % [stats.mp, stats.max_mp])
	print("Header location line shows the biome: ", sheet.location_label.text.ends_with("Golden Plains"))
	print("Header stats line: ", sheet.stats_label.text == "STR %d   AGI %d   DEF 0" % [stats.strength, stats.agility])
	print("Empty equipment slots have no icon: ", sheet.get_node("Window/Header/WeaponSlot").icon == null and sheet.get_node("Window/Header/ArmorSlot").icon == null)

	# --- Grid. ---
	var carried := 0
	for item_id in inventory.backpack.keys():
		if inventory.backpack[item_id] > 0:
			carried += 1
	print("Grid shows one slot per carried item (", carried, "): ", sheet.grid.get_child_count() == carried)
	var potion_slot: Button = sheet.grid.get_node_or_null("HealingPotionSlot")
	print("Slots are 64px touch targets: ", potion_slot != null and potion_slot.size.x >= 64.0 and potion_slot.size.y >= 64.0)
	print("Stacked items show a count badge: ", potion_slot != null and potion_slot.has_node("Count") and potion_slot.get_node("Count").text == "2")
	print("Single items show no badge: ", not sheet.grid.get_node("WoodenPickaxeSlot").has_node("Count"))
	print("Nothing selected yet -> pane prompts: ", sheet.detail_name.text == "Select an item" and not sheet.primary_action.visible)

	# --- Select a potion -> detail + Use. ---
	potion_slot.pressed.emit()
	await process_frame
	print("Selecting shows the item's details: ", sheet.detail_name.text == "Healing Potion" and sheet.detail_type.text == "Consumable  -  you have 2" and sheet.detail_desc.text.contains("Restores 15 HP") and sheet.detail_value.text == "Sells for 12 gold")
	print("Consumable offers Use: ", sheet.primary_action.visible and sheet.primary_action.text == "Use")
	print("Selected slot is highlighted: ", sheet.grid.get_node("HealingPotionSlot").theme_type_variation == &"SlotButtonSelected")
	root.get_texture().get_image().save_png("res://verify_sheet_inventory.png")
	print("Saved verify_sheet_inventory.png")
	character.stats.hp = character.stats.max_hp - 10
	character.changed.emit()
	await process_frame
	sheet.primary_action.pressed.emit()
	await process_frame
	print("Use heals (min(15, missing 10)) and consumes one: ", character.stats.hp == character.stats.max_hp and inventory.get_count("healing_potion") == 1)
	print("Selection stays on the remaining potion, badge gone: ", sheet.selected_item == "healing_potion" and not sheet.grid.get_node("HealingPotionSlot").has_node("Count"))
	sheet.primary_action.pressed.emit()
	await process_frame
	print("Use at full HP does not consume: ", inventory.get_count("healing_potion") == 1)

	# --- Select gear -> Equip -> slot + stats -> Unequip. ---
	sheet.grid.get_node("WoodenPickaxeSlot").pressed.emit()
	await process_frame
	print("Gear shows its slot + stat and offers Equip: ", sheet.detail_type.text == "Weapon  -  Attack +2" and sheet.primary_action.text == "Equip")
	sheet.primary_action.pressed.emit()
	await process_frame
	print("Equip moves it into the weapon slot: ", character.equipment.weapon == "wooden_pickaxe" and sheet.get_node("Window/Header/WeaponSlot").icon != null and sheet.grid.get_node_or_null("WoodenPickaxeSlot") == null)
	print("Header shows the weapon bonus: ", sheet.bonus_label.text == "ATK +2 (Wooden Pickaxe)")
	print("Pane follows the item into its slot and offers Unequip: ", sheet.selected_slot == "weapon" and sheet.primary_action.text == "Unequip" and sheet.detail_type.text.ends_with("equipped"))
	sheet.grid.get_node("LeatherArmorSlot").pressed.emit()
	await process_frame
	sheet.primary_action.pressed.emit()
	await process_frame
	print("Armor equips and DEF updates in the header: ", character.equipment.armor == "leather_armor" and sheet.stats_label.text.ends_with("DEF 3"))
	root.get_texture().get_image().save_png("res://verify_sheet_equipped.png")
	print("Saved verify_sheet_equipped.png")
	sheet.get_node("Window/Header/WeaponSlot").pressed.emit()
	await process_frame
	print("Tapping a header slot selects the worn item: ", sheet.selected_item == "wooden_pickaxe" and sheet.selected_slot == "weapon")
	sheet.primary_action.pressed.emit()
	await process_frame
	print("Unequip returns it to the backpack: ", character.equipment.weapon == "" and inventory.get_count("wooden_pickaxe") == 1 and sheet.grid.get_node_or_null("WoodenPickaxeSlot") != null and sheet.bonus_label.text == "No weapon equipped")
	sheet.get_node("Window/Header/AccessorySlot").pressed.emit()
	await process_frame
	print("Tapping an empty slot explains itself: ", sheet.detail_name.text == "No accessory equipped" and not sheet.primary_action.visible)

	# --- Character tab: the paper doll. (Armour is worn, weapon is not.) ---
	await _press("toggle_character")
	print("C while open switches to the Character tab: ", sheet.is_open() and sheet.current_tab == "character" and sheet.character_view.visible and not sheet.inventory_view.visible)
	print("Header equipment slots hidden on this tab (the doll shows them): ", not sheet.get_node("Window/Header/WeaponSlot").visible and not sheet.get_node("Window/Header/ArmorSlotLabel").visible)
	var lines: Array = []
	for child in sheet.stats_list.get_children():
		if not child.visible:
			continue
		if child is Label:
			lines.append(child.text)
		else:
			lines.append(child.get_child(0).text + "=" + child.get_child(1).text)
	print("Stats column lists attributes, core stats and effects: ", lines.has("Attributes") and lines.has("Core stats") and lines.has("Active effects") and lines.has("Strength=%d" % stats.strength) and lines.has("Defense=3") and lines.has("Attack=+0") and lines.has("None"))
	print("Figure shown (sprite fallback or illustration): ", sheet.figure.texture != null)
	print("Figure uses the keyed Oliver illustration: ", sheet.figure.texture.resource_path == sheet.PORTRAIT_ILLUSTRATION and sheet.figure.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR)
	var doll_weapon: Button = sheet.get_node("Window/CharacterView/DollWeaponSlot")
	var doll_armor: Button = sheet.get_node("Window/CharacterView/DollArmorSlot")
	print("Doll slots mirror the equipment (armour icon, empty weapon): ", doll_armor.icon != null and doll_weapon.icon == null)
	# Tap the armour slot -> pane shows it worn with Unequip.
	doll_armor.pressed.emit()
	await process_frame
	var unequip_btn: Button = null
	var equip_btns: Array = []
	for child in sheet.slot_list.get_children():
		if child is Button and child.visible:
			if child.text == "Unequip":
				unequip_btn = child
			elif child.text == "Equip":
				equip_btns.append(child)
	print("Tapping the armour slot shows it worn: ", sheet.slot_pane_title.text == "Armor" and doll_armor.theme_type_variation == &"SlotButtonSelected" and unequip_btn != null and unequip_btn.get_meta("item_id") == "leather_armor" and equip_btns.is_empty())
	root.get_texture().get_image().save_png("res://verify_sheet_character.png")
	print("Saved verify_sheet_character.png")
	unequip_btn.pressed.emit()
	await process_frame
	print("Unequip from the doll pane works: ", character.equipment.armor == "" and inventory.get_count("leather_armor") == 1 and doll_armor.icon == null)
	# Tap the weapon slot -> both carried weapons offered; equip the greatsword.
	doll_weapon.pressed.emit()
	await process_frame
	var greatsword_equip: Button = null
	var carried_offered: Array = []
	for child in sheet.slot_list.get_children():
		if child is Button and child.visible and child.text == "Equip":
			carried_offered.append(child.get_meta("item_id"))
			if child.get_meta("item_id") == "bone_greatsword":
				greatsword_equip = child
	print("Weapon slot pane lists every carried weapon with Equip: ", sheet.slot_pane_title.text == "Weapon" and carried_offered.has("wooden_pickaxe") and carried_offered.has("bone_greatsword") and carried_offered.size() == 2)
	greatsword_equip.pressed.emit()
	await process_frame
	print("Equip from the doll pane works and the doll updates: ", character.equipment.weapon == "bone_greatsword" and doll_weapon.icon != null and inventory.get_count("bone_greatsword") == 0 and sheet.bonus_label.text == "ATK +6 (Bone Greatsword)")
	root.get_texture().get_image().save_png("res://verify_sheet_doll_equipped.png")
	print("Saved verify_sheet_doll_equipped.png")
	await _press("toggle_inventory")
	print("Back on the Inventory tab the header slots return: ", sheet.current_tab == "inventory" and sheet.get_node("Window/Header/WeaponSlot").visible and sheet.get_node("Window/Header/WeaponSlot").icon != null)
	await _press("toggle_character")
	await _press("toggle_character")
	print("C on the Character tab closes the sheet: ", not sheet.is_open())
	print("Quick bar back once closed: ", quick_bar.visible)

	# --- Hand-off tabs + toolbar. ---
	sheet.open("inventory")
	await process_frame
	sheet.tabs.get_node("CraftingTab").pressed.emit()
	await process_frame
	print("Crafting tab closes the sheet and opens the Crafting panel: ", not sheet.is_open() and crafting_panel.is_open())
	panel_buttons.inventory_btn.pressed.emit()
	await process_frame
	print("Toolbar I from Crafting switches to the sheet and closes Crafting: ", sheet.is_open() and sheet.current_tab == "inventory" and not crafting_panel.is_open())
	sheet.tabs.get_node("CloseBtn".replace("CloseBtn", "CharacterTab")).pressed.emit()
	await process_frame
	print("In-window Character tab switches: ", sheet.current_tab == "character")
	sheet.close_btn.pressed.emit()
	await process_frame
	print("X closes: ", not sheet.is_open())

	# --- Esc + combat. ---
	sheet.open("inventory")
	await process_frame
	await _press("ui_cancel")
	print("Esc closes: ", not sheet.is_open())
	sheet.open("inventory")
	await process_frame
	combat.start_combat(["dungeon_rat"])
	await process_frame
	await process_frame
	print("Entering combat closes the sheet: ", not sheet.is_open())
	await _press("toggle_inventory")
	print("I is ignored during combat: ", not sheet.is_open())
	while combat.in_combat:
		combat.player_run()
		await physics_frame

	# --- Phone-shaped viewport (keep_width: 800 logical wide, much taller). ---
	root.size = Vector2i(400, 860)
	for i in range(4):
		await process_frame
	sheet.open("inventory")
	await process_frame
	await process_frame
	var vis: Rect2 = root.get_visible_rect()
	print("Phone viewport: visible rect ", vis.size, " - window still fully inside: ", sheet.window.position.y + sheet.window.size.y <= vis.size.y and sheet.window.position.x + sheet.window.size.x <= vis.size.x)
	root.get_texture().get_image().save_png("res://verify_sheet_phone.png")
	print("Saved verify_sheet_phone.png")
	sheet.close()
	quit()
