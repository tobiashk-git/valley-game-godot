extends SceneTree

func _initialize() -> void:
	var house_scene: PackedScene = load("res://scenes/House.tscn")
	var house: Node2D = house_scene.instantiate()
	root.add_child(house)
	current_scene = house
	await process_frame

	var player: CharacterBody2D = house.get_node("YSort/Player")
	var cam: Camera2D = player.get_node("Camera2D")

	# Give Oliver a few items to deposit, and find the Chest instance.
	var inventory: Node = root.get_node("Inventory")
	inventory.add_item("wood", 5)
	inventory.add_item("stone", 2)

	var ysort: Node2D = house.get_node("YSort")
	var chest: Node = ysort.get_node("Chest")
	print("Chest at: ", chest.position)

	player.position = chest.position + Vector2(0, 20)
	cam.zoom = Vector2(2.5, 2.5)
	cam.reset_smoothing()
	for i in range(3):
		await process_frame

	root.get_texture().get_image().save_png("res://verify_storage_before.png")

	var storage_panel: Node = root.get_node("StoragePanel")

	# Open the chest.
	Input.action_press("interact")
	await process_frame
	await process_frame
	Input.action_release("interact")
	await process_frame
	await process_frame
	print("Storage panel open after E: ", storage_panel.is_open())
	root.get_texture().get_image().save_png("res://verify_storage_open.png")

	# Deposit wood by clicking the first backpack button.
	var backpack_list: VBoxContainer = storage_panel.get_node("Panel/Margin/HBox/BackpackColumn/BackpackList")
	var wood_btn: Button = backpack_list.get_child(0)
	print("Clicking backpack button: ", wood_btn.text)
	wood_btn.pressed.emit()
	await process_frame
	await process_frame
	print("Backpack wood after deposit: ", inventory.get_count("wood"))
	print("Chest wood after deposit: ", root.get_node("Storage").get_count("house_chest", "wood"))
	root.get_texture().get_image().save_png("res://verify_storage_after_deposit.png")

	# Withdraw it back by clicking the chest column button.
	var chest_list: VBoxContainer = storage_panel.get_node("Panel/Margin/HBox/ChestColumn/ChestList")
	var chest_btn: Button = chest_list.get_child(0)
	print("Clicking chest button: ", chest_btn.text)
	chest_btn.pressed.emit()
	await process_frame
	await process_frame
	print("Backpack wood after withdraw: ", inventory.get_count("wood"))
	print("Chest wood after withdraw: ", root.get_node("Storage").get_count("house_chest", "wood"))

	# Close via E.
	Input.action_press("interact")
	await process_frame
	await process_frame
	Input.action_release("interact")
	await process_frame
	await process_frame
	print("Storage panel open after close E: ", storage_panel.is_open())
	root.get_texture().get_image().save_png("res://verify_storage_closed.png")

	quit()
