extends SceneTree
# Armour sets verification. Run via:
# godot --script res://tools/verify_armour_sets.gd (NOT --headless).
# Head / legs / feet slots exist in Character.SLOTS and the equipment dict;
# 14 pieces (starter cap + boots, helm/greaves/boots per tier) carry a slot,
# a defence value and an LPC layer sheet; defence sums across every slot;
# recipes exist per tier piece; the Trader stocks the starters; the sheet
# shows six header slots inside the window on both layouts; the walking
# sprite carries one overlay per slot in the draw order legs, feet, body,
# head; a save round-trips the new slots.

const PIECES: Array[String] = ["leather_cap", "leather_boots", "frost_helm", "frost_greaves", "frost_boots", "ironwood_helm", "ironwood_greaves", "ironwood_boots", "ember_helm", "ember_greaves", "ember_boots", "bogiron_helm", "bogiron_greaves", "bogiron_boots"]
const BOGIRON_LAYER := {"legs": "bogiron_greaves", "feet": "bogiron_boots", "armor": "bogiron_harness", "head": "bogiron_helm"}

func _initialize() -> void:
	var character: Node = root.get_node("Character")
	var items: Node = root.get_node("Items")
	var inventory: Node = root.get_node("Inventory")
	var crafting: Node = root.get_node("Crafting")
	var shop: Node = root.get_node("Shop")
	var save: Node = root.get_node("SaveSystem")
	var sheet: CanvasLayer = root.get_node("CharacterSheet")
	var layout: Node = root.get_node("Layout")
	await process_frame
	character.reset()
	inventory.reset()

	print("Six slots in the table and the equipment dict (weapon, armor, accessory, head, legs, feet): ", character.SLOTS.size() == 6 and character.SLOTS.has("head") and character.SLOTS.has("legs") and character.SLOTS.has("feet") and character.equipment.size() == 6 and character.SLOTS.head.stat == "defense")
	var all_ok := true
	for id in PIECES:
		var def: Dictionary = items.ITEMS.get(id, {})
		var tex: Texture2D = load(def.get("layer", "")) if def.has("layer") and ResourceLoader.exists(def.layer) else null
		var icon_ok: bool = ResourceLoader.exists("res://assets/icons/%s.png" % id)
		if def.is_empty() or not (def.get("slot", "") in ["head", "legs", "feet"]) or int(def.get("defense", 0)) < 1 or tex == null or tex.get_size() != Vector2(576, 256) or not icon_ok:
			all_ok = false
			print("  bad piece: ", id)
	print("All 14 pieces have a head/legs/feet slot, defence, a 576x256 layer and an icon: ", all_ok)
	var totals := {"frost": 0, "ironwood": 0, "ember": 0, "bogiron": 0}
	for id in PIECES:
		for t in totals.keys():
			if id.begins_with(t + "_"):
				totals[t] += int(items.ITEMS[id].defense)
	print("Set bonuses per tier: frost +5, ironwood +7, ember +8, bog-iron +11 (the simulator's profiles): ", totals.frost == 5 and totals.ironwood == 7 and totals.ember == 8 and totals.bogiron == 11)
	var recipes_ok := true
	for id in PIECES:
		if id.begins_with("leather_"):
			continue
		if not crafting.RECIPES.has(id) or crafting.RECIPES[id].result != id:
			recipes_ok = false
	print("Every tier piece has a recipe; the Trader stocks the leather cap and boots: ", recipes_ok and shop.SHOP_STOCK.has("leather_cap") and shop.SHOP_STOCK.has("leather_boots"))

	# --- defence sums across slots ---
	for id in ["bogiron_harness", "bogiron_helm", "bogiron_greaves", "bogiron_boots"]:
		inventory.add_item(id, 1)
	character.equip("armor", "bogiron_harness")
	character.equip("head", "bogiron_helm")
	character.equip("legs", "bogiron_greaves")
	character.equip("feet", "bogiron_boots")
	await process_frame
	print("Full bog-iron set: defence 11 + 4 + 4 + 3 = 22 from gear_total: ", character.gear_total("defense") == 22 and root.get_node("Combat")._player_defense_bonus() == 22)

	# --- the sprite carries every layer in order ---
	var house: Node2D = load("res://scenes/House.tscn").instantiate()
	root.add_child(house)
	current_scene = house
	for i in range(4):
		await process_frame
	var player: CharacterBody2D = house.get_node("YSort/Player")
	var order: Array = []
	for child in player.get_children():
		if String(child.name).ends_with("Layer"):
			order.append(String(child.name))
	var all_visible := true
	for slot in BOGIRON_LAYER.keys():
		var l: AnimatedSprite2D = player.get_node(slot.to_pascal_case() + "Layer")
		if not l.visible or not l.get_meta("layer_path", "").ends_with(BOGIRON_LAYER[slot] + ".png"):
			all_visible = false
	print("Walking sprite: layers drawn legs, feet, body, head, all showing the bog-iron pieces: ", order == ["LegsLayer", "FeetLayer", "ArmorLayer", "HeadLayer"] and all_visible)
	root.get_texture().get_image().save_png("res://verify_armour_sets_sprite.png")
	print("Saved verify_armour_sets_sprite.png")

	# --- sheet: six header slots and six doll slots inside the window ---
	sheet.open("character")
	await process_frame
	await process_frame
	var win: Rect2 = sheet.window.get_global_rect()
	var inside := true
	for slot in character.SLOTS:
		var b: Button = sheet._header_slot_button(slot)
		var d: Button = sheet._doll_slot_button(slot)
		if not win.encloses(b.get_global_rect()) or not win.encloses(d.get_global_rect()):
			inside = false
	var stats_rect: Rect2 = sheet.stats_label.get_global_rect()
	var first_slot: Rect2 = sheet._header_slot_button("weapon").get_global_rect()
	print("Wide: six header and doll slots inside the window; the stat line sits under the bars, clear of the slots; the hint below the lower slots: ", inside and stats_rect.end.x <= first_slot.position.x and stats_rect.position.y > sheet.mp_bar.get_global_rect().end.y and sheet.doll_hint.get_global_rect().position.y >= sheet._doll_slot_button("legs").get_global_rect().end.y + 14.0)
	root.get_texture().get_image().save_png("res://verify_armour_sets_sheet.png")
	print("Saved verify_armour_sets_sheet.png")
	sheet.close()

	# --- save round-trip ---
	var snap: Dictionary = save.snapshot()
	character.unequip("head")
	character.unequip("feet")
	save.apply(snap)
	print("A save carries the new slots (helm and boots back after apply): ", character.equipped_id("head") == "bogiron_helm" and character.equipped_id("feet") == "bogiron_boots" and character.equipped_id("legs") == "bogiron_greaves")

	# --- phone ---
	root.size = Vector2i(400, 860)
	for i in range(6):
		await process_frame
	sheet.open("inventory")
	await process_frame
	await process_frame
	var win_n: Rect2 = sheet.window.get_global_rect()
	var row_ok := true
	for slot in character.SLOTS:
		var r: Rect2 = sheet._header_slot_button(slot).get_global_rect()
		if not win_n.encloses(r) or r.size != Vector2(48, 48):
			row_ok = false
	print("Phone: six 48px header slots in one row inside the window: ", layout.is_narrow() and row_ok)
	root.get_texture().get_image().save_png("res://verify_armour_sets_phone.png")
	print("Saved verify_armour_sets_phone.png")
	sheet.open("character")
	await process_frame
	await process_frame
	var pane_ok: bool = sheet.slot_pane.get_global_rect().position.y >= sheet._doll_slot_button("legs").get_global_rect().end.y + 14.0
	print("Phone Hero tab: the slot pane starts below the lower doll slots: ", pane_ok)
	sheet.close()
	root.size = Vector2i(800, 600)
	for i in range(4):
		await process_frame
	quit()
