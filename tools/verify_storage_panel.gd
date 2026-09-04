extends SceneTree
# Storage (chest) window verification (UI redesign Phase 3: the chest on the
# character sheet's kit). Run via:
# godot --script res://tools/verify_storage_panel.gd (NOT --headless).
#
# Walk up + E opens it on the Chest tab; the Backpack tab lists what's
# carried with count badges; Put in chest / Put all move stackables, Take
# out / Take all bring them back; gear moves per instance (an enhanced
# piece round-trips intact); E, Esc and X close it.

func _press(action: String) -> void:
	Input.action_press(action)
	await process_frame
	await process_frame
	Input.action_release(action)
	await process_frame
	await process_frame

func _initialize() -> void:
	var house_scene: PackedScene = load("res://scenes/House.tscn")
	var house: Node2D = house_scene.instantiate()
	root.add_child(house)
	current_scene = house
	await process_frame

	var player: CharacterBody2D = house.get_node("YSort/Player")
	var cam: Camera2D = player.get_node("Camera2D")
	var inventory: Node = root.get_node("Inventory")
	var storage: Node = root.get_node("Storage")
	var storage_panel: Node = root.get_node("StoragePanel")
	var crafting: Node = root.get_node("Crafting")
	inventory.add_item("wood", 5)
	inventory.add_item("stone", 2)

	var chest: Node = house.get_node("YSort/Chest")
	player.position = chest.position + Vector2(0, 20)
	cam.zoom = Vector2(2.5, 2.5)
	cam.reset_smoothing()
	for i in range(3):
		await process_frame

	# --- Open. ---
	await _press("interact")
	print("Storage window open after E: ", storage_panel.is_open() and storage_panel.storage_id == "house_chest")
	print("Kit window (Window/Grid/DetailPane), no old two-column panel: ", storage_panel.has_node("Window/GridScroll/Grid") and not storage_panel.has_node("Panel"))
	print("Opens on the Chest tab, which is empty: ", storage_panel.tab == 0 and storage_panel.grid.get_child_count() == 0 and storage_panel.count_label.text == "Nothing here")
	print("Subtitle counts both sides: ", storage_panel.subtitle_label.text == "Chest: 0 items  -  Backpack: 2 items")

	# --- Backpack tab: put wood in, one then all. ---
	storage_panel.tab_b.pressed.emit()
	await process_frame
	print("Backpack tab lists wood (5) and stone (2): ", storage_panel.tab == 1 and storage_panel.grid.get_node("WoodSlot").get_node("Count").text == "5" and storage_panel.grid.get_node("StoneSlot").get_node("Count").text == "2")
	storage_panel.grid.get_node("WoodSlot").pressed.emit()
	await process_frame
	print("Selecting wood offers Put in chest / Put all (5): ", storage_panel.detail_name.text == "Wood" and storage_panel.detail_value.text == "In your backpack: 5" and storage_panel.primary_action.text == "Put in chest" and storage_panel.secondary_action.text == "Put all (5)")
	root.get_texture().get_image().save_png("res://verify_storage_open.png")
	print("Saved verify_storage_open.png")
	storage_panel.primary_action.pressed.emit()
	await process_frame
	print("Put one: backpack 4, chest 1: ", inventory.get_count("wood") == 4 and storage.get_count("house_chest", "wood") == 1)
	storage_panel.secondary_action.pressed.emit()
	await process_frame
	print("Put all: backpack 0, chest 5, slot gone, selection cleared: ", inventory.get_count("wood") == 0 and storage.get_count("house_chest", "wood") == 5 and storage_panel.grid.get_node_or_null("WoodSlot") == null and storage_panel.selected_item == "")
	root.get_texture().get_image().save_png("res://verify_storage_after_deposit.png")
	print("Saved verify_storage_after_deposit.png")

	# --- Chest tab: take one, then all. ---
	storage_panel.tab_a.pressed.emit()
	await process_frame
	print("Chest tab lists the wood (5): ", storage_panel.tab == 0 and storage_panel.grid.get_node("WoodSlot").get_node("Count").text == "5" and storage_panel.subtitle_label.text == "Chest: 1 item  -  Backpack: 1 item")
	storage_panel.grid.get_node("WoodSlot").pressed.emit()
	await process_frame
	print("Selecting offers Take out / Take all (5): ", storage_panel.detail_value.text == "In the chest: 5" and storage_panel.primary_action.text == "Take out" and storage_panel.secondary_action.text == "Take all (5)")
	storage_panel.primary_action.pressed.emit()
	await process_frame
	print("Take one: backpack 1, chest 4: ", inventory.get_count("wood") == 1 and storage.get_count("house_chest", "wood") == 4)
	storage_panel.secondary_action.pressed.emit()
	await process_frame
	print("Take all: backpack 5, chest empty: ", inventory.get_count("wood") == 5 and storage.get_count("house_chest", "wood") == 0 and storage_panel.grid.get_child_count() == 0)

	# --- Gear per instance: an enhanced armour round-trips intact. ---
	inventory.add_item("leather_armor", 2)
	inventory.add_item("monster_fur", 3)
	var enhanced_uid: int = inventory.gear[1].uid
	crafting.enhance(enhanced_uid, "fur_lined")
	storage_panel.tab_b.pressed.emit()
	await process_frame
	print("Backpack tab lists both armours, the enhanced one starred: ", storage_panel.grid.get_node_or_null("LeatherArmorSlot") != null and storage_panel.grid.get_node("LeatherArmorSlot2").has_node("Enhanced"))
	storage_panel.grid.get_node("LeatherArmorSlot2").pressed.emit()
	await process_frame
	print("Gear offers Put in chest only (no 'all'): ", storage_panel.selected_uid == enhanced_uid and storage_panel.detail_name.text == "Fur-lined Leather Armor" and storage_panel.primary_action.text == "Put in chest" and not storage_panel.secondary_action.visible)
	storage_panel.primary_action.pressed.emit()
	await process_frame
	print("Enhanced piece is in the chest as an instance, plain one still carried: ", storage.get_gear("house_chest").size() == 1 and storage.get_gear("house_chest")[0].uid == enhanced_uid and inventory.get_count("leather_armor") == 1 and inventory.gear_of("leather_armor")[0].mods.is_empty())
	storage_panel.tab_a.pressed.emit()
	await process_frame
	storage_panel.grid.get_node("LeatherArmorSlot").pressed.emit()
	await process_frame
	print("Chest tab shows it with Take out: ", storage_panel.detail_name.text == "Fur-lined Leather Armor" and storage_panel.primary_action.text == "Take out")
	storage_panel.primary_action.pressed.emit()
	await process_frame
	print("...and it comes back intact: ", inventory.find_gear(enhanced_uid).mods.size() == 1 and storage.get_gear("house_chest").is_empty())

	# --- Close via E, stays closed; Esc and X also close. ---
	await _press("interact")
	print("Storage window closed via E: ", not storage_panel.is_open() and storage_panel.storage_id == "")
	root.get_texture().get_image().save_png("res://verify_storage_closed.png")
	await _press("interact")
	print("E reopens: ", storage_panel.is_open())
	await _press("ui_cancel")
	print("Esc closes: ", not storage_panel.is_open())
	await _press("interact")
	storage_panel.close_btn.pressed.emit()
	await process_frame
	print("X closes: ", not storage_panel.is_open())

	quit()
