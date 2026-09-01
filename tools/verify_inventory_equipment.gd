extends SceneTree
# Verifies the Inventory panel's new Equipment section: empty slots show as
# plain text, equipping a single-owned gear item removes its backpack row
# but shows it in the Equipment section (the reported "disappears with no
# trace" bug), and clicking the equipped slot unequips it back to the
# backpack. Run via: godot --script res://tools/verify_inventory_equipment.gd
# (NOT --headless - this takes real screenshots via get_texture()).

func _initialize() -> void:
	var overworld_scene: PackedScene = load("res://scenes/Overworld.tscn")
	var overworld: Node2D = overworld_scene.instantiate()
	root.add_child(overworld)
	current_scene = overworld
	await process_frame
	await process_frame

	var inventory: Node = root.get_node("Inventory")
	var character: Node = root.get_node("Character")
	var inventory_panel: Node = root.get_node("InventoryPanel")

	inventory_panel.toggle_open()
	await process_frame
	var list: VBoxContainer = inventory_panel.get_node("Panel/Margin/VBox/List")

	print("Equipment header present: ", list.get_child(0).text == "Equipment")
	print("3 empty slot rows shown: ", (list.get_child(1) as Label).text == "Weapon: (empty)" and (list.get_child(2) as Label).text == "Armor: (empty)" and (list.get_child(3) as Label).text == "Accessory: (empty)")
	root.get_texture().get_image().save_png("res://verify_equipment_empty.png")

	# --- Own exactly 1 pickaxe, equip it via the backpack row. ---
	inventory.add_item("wooden_pickaxe", 1)
	await process_frame
	list = inventory_panel.get_node("Panel/Margin/VBox/List")
	var backpack_start := -1
	for i in range(list.get_child_count()):
		if list.get_child(i) is Label and (list.get_child(i) as Label).text == "Backpack":
			backpack_start = i
			break
	var pickaxe_row: Button = null
	for i in range(backpack_start + 1, list.get_child_count()):
		var child: Control = list.get_child(i)
		if child is Button and (child as Button).text.contains("Wooden Pickaxe"):
			pickaxe_row = child
	print("Pickaxe row found in backpack before equipping: ", pickaxe_row != null)
	pickaxe_row.pressed.emit()
	await process_frame

	list = inventory_panel.get_node("Panel/Margin/VBox/List")
	print("Weapon slot now shows the pickaxe: ", (list.get_child(1) as Button).text.contains("Wooden Pickaxe"))
	print("Character.equipment.weapon set: ", character.equipment.weapon == "wooden_pickaxe")

	var still_in_backpack := false
	for i in range(backpack_start + 1, list.get_child_count()):
		var child: Control = list.get_child(i)
		if child is Button and (child as Button).text.contains("Wooden Pickaxe"):
			still_in_backpack = true
	print("No longer a separate backpack row (the reported bug case - count was 1): ", not still_in_backpack)
	root.get_texture().get_image().save_png("res://verify_equipment_filled.png")

	# --- Click the equipped slot to unequip. ---
	var weapon_slot_btn: Button = list.get_child(1)
	weapon_slot_btn.pressed.emit()
	await process_frame
	list = inventory_panel.get_node("Panel/Margin/VBox/List")
	print("Weapon slot empty again after unequip: ", (list.get_child(1) as Label).text == "Weapon: (empty)")
	print("Character.equipment.weapon cleared: ", character.equipment.weapon == "")
	print("Pickaxe count back in backpack: ", inventory.get_count("wooden_pickaxe") == 1)

	quit()
