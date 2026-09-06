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
	print("Old Inventory/Character popups are gone (autoloads deleted): ", not root.has_node("InventoryPanel") and not root.has_node("CharacterPanel"))
	print("Quick bar hidden while the sheet is open: ", not quick_bar.visible)
	print("Window sits below the toolbar row (y >= 52) and inside the viewport: ", sheet.window.position.y >= 52.0 and sheet.window.position.y + sheet.window.size.y <= 600.0)

	# --- Header. ---
	var stats: Dictionary = character.stats
	print("Header shows the portrait: ", sheet.portrait.texture != null)
	print("Header HP/MP track Character.stats: ", sheet.hp_label.text == "HP %d / %d" % [stats.hp, stats.max_hp] and sheet.mp_label.text == "MP %d / %d" % [stats.mp, stats.max_mp])
	print("Header location line shows the biome: ", sheet.location_label.text.ends_with("Golden Plains"))
	print("Header stats line: ", sheet.stats_label.text == "STR %d   AGI %d   DEF 0" % [stats.strength, stats.agility])
	print("Empty equipment slots have no icon: ", sheet.get_node("Window/Header/WeaponSlot").icon == null and sheet.get_node("Window/Header/ArmorSlot").icon == null)
	# --- Character.SLOTS drives everything: one header slot + one doll slot
	# (with label and connector line) per table entry, the equipment dict has
	# exactly those keys, and combat's totals come from the same table. ---
	var table_driven := true
	for slot_id in character.SLOTS:
		var pascal: String = slot_id.to_pascal_case()
		var header_ok: bool = sheet.has_node("Window/Header/%sSlot" % pascal) and sheet.get_node("Window/Header/%sSlotLabel" % pascal).text == character.SLOTS[slot_id].label
		var doll_ok: bool = sheet.has_node("Window/CharacterScroll/CharacterView/Doll%sSlot" % pascal) and sheet.has_node("Window/CharacterScroll/CharacterView/%sLine" % pascal) and sheet.get_node("Window/CharacterScroll/CharacterView/Doll%sSlotLabel" % pascal).text == character.SLOTS[slot_id].label
		if not (header_ok and doll_ok and character.equipment.has(slot_id)):
			table_driven = false
	var header_slot_count := 0
	for child in sheet.get_node("Window/Header").get_children():
		if child is Button:
			header_slot_count += 1
	print("Character.SLOTS drives the header row, the doll and the equipment dict (", character.SLOTS.size(), " slots): ", table_driven and header_slot_count == character.SLOTS.size() and character.equipment.size() == character.SLOTS.size())
	print("Gear totals sum by stat across the slot table (nothing worn -> 0/0/0%): ", character.gear_total("attack") == 0 and character.gear_total("defense") == 0 and character.gear_bonus("status_resistance") == 0.0)

	# --- Grid. ---
	var carried := 0
	for item_id in inventory.backpack.keys():
		if inventory.backpack[item_id] > 0:
			carried += 1
	carried += inventory.gear.size() # one slot per gear INSTANCE
	print("Grid shows one slot per carried stack + gear instance (", carried, "): ", sheet.grid.get_child_count() == carried)
	var potion_slot: Button = sheet.grid.get_node_or_null("HealingPotionSlot")
	print("Slots are 64px touch targets: ", potion_slot != null and potion_slot.size.x >= 64.0 and potion_slot.size.y >= 64.0)
	print("Stacked items show a count badge: ", potion_slot != null and potion_slot.has_node("Count") and potion_slot.get_node("Count").text == "2")
	print("Single items show no badge: ", not sheet.grid.get_node("WoodenPickaxeSlot").has_node("Count"))
	print("Nothing selected yet -> pane prompts: ", sheet.detail_name.text == "Select an item" and not sheet.primary_action.visible)

	# --- Select a potion -> detail + Use. ---
	potion_slot.pressed.emit()
	await process_frame
	print("Selecting shows the item's details: ", sheet.detail_name.text == "Healing Potion" and sheet.detail_type.text == "Consumable  -  you have 2" and sheet.detail_desc.text.contains("Restores 8 HP") and sheet.detail_value.text == "Sells for 20 gold")
	print("Consumable offers Use: ", sheet.primary_action.visible and sheet.primary_action.text == "Use")
	print("Selected slot is highlighted: ", sheet.grid.get_node("HealingPotionSlot").theme_type_variation == &"SlotButtonSelected")
	root.get_texture().get_image().save_png("res://verify_sheet_inventory.png")
	print("Saved verify_sheet_inventory.png")
	character.stats.hp = character.stats.max_hp - 6
	character.changed.emit()
	await process_frame
	sheet.primary_action.pressed.emit()
	await process_frame
	print("Use heals (min(8, missing 6)) and consumes one: ", character.stats.hp == character.stats.max_hp and inventory.get_count("healing_potion") == 1)
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
	print("Equip moves it into the weapon slot: ", character.equipped_id("weapon") == "wooden_pickaxe" and sheet.get_node("Window/Header/WeaponSlot").icon != null and sheet.grid.get_node_or_null("WoodenPickaxeSlot") == null)
	print("Header shows the weapon bonus: ", sheet.bonus_label.text == "ATK +2 (Wooden Pickaxe)")
	print("Pane follows the item into its slot and offers Unequip: ", sheet.selected_slot == "weapon" and sheet.primary_action.text == "Unequip" and sheet.detail_type.text.ends_with("equipped"))
	sheet.grid.get_node("LeatherArmorSlot").pressed.emit()
	await process_frame
	sheet.primary_action.pressed.emit()
	await process_frame
	print("Armor equips and DEF updates in the header: ", character.equipped_id("armor") == "leather_armor" and sheet.stats_label.text.ends_with("DEF 3"))
	print("Combat reads the same totals (attack +2, defence 3): ", combat._weapon_attack_bonus() == 2 and combat._player_defense_bonus() == 3 and character.gear_names("attack") == ["Wooden Pickaxe"])
	root.get_texture().get_image().save_png("res://verify_sheet_equipped.png")
	print("Saved verify_sheet_equipped.png")
	sheet.get_node("Window/Header/WeaponSlot").pressed.emit()
	await process_frame
	print("Tapping a header slot selects the worn item: ", sheet.selected_item == "wooden_pickaxe" and sheet.selected_slot == "weapon")
	sheet.primary_action.pressed.emit()
	await process_frame
	print("Unequip returns it to the backpack: ", character.equipped_id("weapon") == "" and inventory.get_count("wooden_pickaxe") == 1 and sheet.grid.get_node_or_null("WoodenPickaxeSlot") != null and sheet.bonus_label.text == "No weapon equipped")
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
		elif child is Button:
			continue # the Game block's Save / Load / New game buttons
		else:
			if child.get_child(1) is Label: # the Music/Sounds rows end in a slider
				lines.append(child.get_child(0).text + "=" + child.get_child(1).text)
	print("Stats column lists attributes, core stats and effects: ", lines.has("Attributes") and lines.has("Core stats") and lines.has("Active effects") and lines.has("Strength=%d" % stats.strength) and lines.has("Defense=3") and lines.has("Attack=+0") and lines.has("None"))
	print("Figure shown (sprite fallback or illustration): ", sheet.figure.texture != null)
	print("Figure uses the keyed Oliver illustration: ", sheet.figure.texture.resource_path == sheet.PORTRAIT_ILLUSTRATION and sheet.figure.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR)
	var doll_weapon: Button = sheet.get_node("Window/CharacterScroll/CharacterView/DollWeaponSlot")
	var doll_armor: Button = sheet.get_node("Window/CharacterScroll/CharacterView/DollArmorSlot")
	print("Doll slots mirror the equipment (armour icon, empty weapon): ", doll_armor.icon != null and doll_weapon.icon == null)
	# Tap the armour slot -> pane shows it worn with Unequip.
	doll_armor.pressed.emit()
	await process_frame
	var unequip_btn: Button = null
	var equip_btns: Array = []
	# Items are 94px cards (icon / name / button) so they can flow sideways
	# on a phone - search the cards, not just the list's direct children.
	for child in sheet.slot_list.find_children("*", "Button", true, false):
		if child.visible:
			if child.text == "Unequip":
				unequip_btn = child
			elif child.text == "Equip":
				equip_btns.append(child)
	print("Tapping the armour slot shows it worn: ", sheet.slot_pane_title.text == "Armor" and doll_armor.theme_type_variation == &"SlotButtonSelected" and unequip_btn != null and unequip_btn.get_meta("item_id") == "leather_armor" and equip_btns.is_empty())
	var icons_fit := true
	for icon in sheet.slot_list.find_children("*", "TextureRect", true, false):
		if icon.visible and not icon.get_parent().get_global_rect().encloses(icon.get_global_rect()):
			icons_fit = false
	print("The pane's item icons sit inside their 48px boxes (used to spill out at 64px): ", icons_fit and sheet.slot_list.find_children("*", "TextureRect", true, false).size() >= 1)
	root.get_texture().get_image().save_png("res://verify_sheet_character.png")
	print("Saved verify_sheet_character.png")
	unequip_btn.pressed.emit()
	await process_frame
	print("Unequip from the doll pane works: ", character.equipped_id("armor") == "" and inventory.get_count("leather_armor") == 1 and doll_armor.icon == null)
	# Tap the weapon slot -> both carried weapons offered; equip the greatsword.
	doll_weapon.pressed.emit()
	await process_frame
	var greatsword_equip: Button = null
	var carried_offered: Array = []
	for child in sheet.slot_list.find_children("*", "Button", true, false):
		if child.visible and child.text == "Equip":
			carried_offered.append(child.get_meta("item_id"))
			if child.get_meta("item_id") == "bone_greatsword":
				greatsword_equip = child
	print("Weapon slot pane lists every carried weapon with Equip: ", sheet.slot_pane_title.text == "Weapon" and carried_offered.has("wooden_pickaxe") and carried_offered.has("bone_greatsword") and carried_offered.size() == 2)
	greatsword_equip.pressed.emit()
	await process_frame
	print("Equip from the doll pane works and the doll updates: ", character.equipped_id("weapon") == "bone_greatsword" and doll_weapon.icon != null and inventory.get_count("bone_greatsword") == 0 and sheet.bonus_label.text == "ATK +6 (Bone Greatsword)")
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
	print("Crafting tab switches within the sheet (no standalone panel any more): ", sheet.is_open() and sheet.current_tab == "crafting" and sheet.crafting_view.visible and not root.has_node("CraftingPanel"))
	panel_buttons.menu_btn.pressed.emit()
	await process_frame
	print("Menu from the Crafting tab closes the sheet: ", not sheet.is_open())
	panel_buttons.menu_btn.pressed.emit()
	await process_frame
	print("Menu again reopens it on its last tab (Crafting): ", sheet.is_open() and sheet.current_tab == "crafting")
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

	# --- Phone-shaped viewport: Layout follows the window width (400 CSS px
	# -> 400 logical units, was a fixed 800), and the sheet switches to its
	# stacked narrow layout. ---
	var layout: Node = root.get_node("Layout")
	root.size = Vector2i(400, 860)
	for i in range(4):
		await process_frame
	sheet.open("inventory")
	await process_frame
	await process_frame
	var vis: Rect2 = root.get_visible_rect()
	print("Phone viewport: logical width follows the screen (", vis.size, "): ", layout.width == 400 and layout.is_narrow() and vis.size == Vector2(400, 860) and sheet.narrow)
	print("Window fills the phone width and stays inside: ", sheet.window.position.x == 12.0 and sheet.window.size.x == 376.0 and sheet.window.position.y + sheet.window.size.y <= vis.size.y)
	var tabs_end: float = sheet.tabs.get_global_rect().end.x
	print("Short tab names fit the strip beside the X (", sheet.tabs.get_node("InventoryTab").text, "...): ", sheet.tabs.get_node("InventoryTab").text == "Items" and sheet.tabs.get_node("JournalTab").text == "Quests" and tabs_end <= sheet.close_btn.global_position.x)
	var slot_rect: Rect2 = sheet.get_node("Window/Header/WeaponSlot").get_global_rect()
	print("Header slot row sits under the bars (48px slots, six inside the window): ", slot_rect.position.y > sheet.mp_bar.get_global_rect().end.y and slot_rect.size == Vector2(48, 48) and sheet.get_node("Window/Header/FeetSlot").get_global_rect().end.x <= sheet.window.get_global_rect().end.x)
	var grid_rect: Rect2 = sheet.grid_scroll.get_global_rect()
	var pane_rect: Rect2 = sheet.detail_pane.get_global_rect()
	print("Grid drops to 4 columns (64px slots in 336px) and the detail pane sits below it, full width: ", sheet.grid.columns == 4 and pane_rect.position.y >= grid_rect.end.y and pane_rect.size.x == grid_rect.size.x and pane_rect.end.y <= sheet.window.get_global_rect().end.y, " cols=", sheet.grid.columns, " grid=", grid_rect, " pane=", pane_rect, " window=", sheet.window.get_global_rect())
	print("Slots still 64px on the phone: ", sheet.grid.get_node("HealingPotionSlot").size.x >= 64.0)
	root.get_texture().get_image().save_png("res://verify_sheet_phone.png")
	print("Saved verify_sheet_phone.png")
	sheet.open("character")
	await process_frame
	await process_frame
	var doll_w: Button = sheet.get_node("Window/CharacterScroll/CharacterView/DollWeaponSlot")
	var doll_a: Button = sheet.get_node("Window/CharacterScroll/CharacterView/DollArmorSlot")
	var fig_rect: Rect2 = sheet.figure.get_global_rect()
	print("Doll re-centred on the phone (weapon left of the figure, armour right, all inside): ", doll_w.get_global_rect().position.x < fig_rect.position.x and doll_a.get_global_rect().position.x >= fig_rect.end.x - 1.0 and doll_w.get_global_rect().position.x >= 12.0 and doll_a.get_global_rect().end.x <= 388.0)
	var slot_pane_rect: Rect2 = sheet.slot_pane.get_global_rect()
	var rows_inside := true
	for child in sheet.slot_list.get_children():
		if child is Control and not slot_pane_rect.encloses(child.get_global_rect()):
			rows_inside = false
	print("Slot pane under the doll lists full-width rows (nothing cut off sideways), the pane sized to them, stats below (view scrolls): ", sheet.slot_list.vertical and sheet.slot_scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED and rows_inside and sheet.slot_pane.position.y >= 284.0 and sheet.stats_list.position.y >= sheet.slot_pane.position.y + sheet.slot_pane.size.y and sheet.character_view.custom_minimum_size.y > sheet.character_scroll.size.y)
	root.get_texture().get_image().save_png("res://verify_sheet_phone_character.png")
	print("Saved verify_sheet_phone_character.png")
	sheet.open("crafting")
	await process_frame
	await process_frame
	print("Crafting sections drop to 4 columns too: ", sheet.craft_columns == 4, " (", sheet.craft_columns, " scroll=", sheet.craft_scroll.size, ")")
	print("Crafting pane below its grid on the phone, inside the window: ", sheet.craft_pane.position.y >= sheet.craft_scroll.position.y + sheet.craft_scroll.size.y and sheet.craft_pane.get_global_rect().end.y <= sheet.window.get_global_rect().end.y and sheet.craft_action.get_global_rect().end.y <= sheet.craft_pane.get_global_rect().end.y)
	root.get_texture().get_image().save_png("res://verify_sheet_phone_crafting.png")
	print("Saved verify_sheet_phone_crafting.png")
	sheet.close()

	# --- Back to desktop: the wide layout is restored exactly. ---
	root.size = Vector2i(800, 600)
	for i in range(4):
		await process_frame
	sheet.open("inventory")
	await process_frame
	print("Back at 800 wide: wide layout restored (720px window at x=40, 6 columns, full tab names, tabs clear of the X): ", layout.width == 800 and not sheet.narrow and sheet.window.position == Vector2(40, 56) and sheet.window.size == Vector2(720, 530) and sheet.grid.columns == 6 and sheet.tabs.get_node("InventoryTab").text == "Inventory" and sheet.tabs.get_global_rect().end.x <= sheet.close_btn.global_position.x and not sheet.window.has_node("QuitBtn"))
	sheet.close()
	quit()
