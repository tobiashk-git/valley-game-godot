extends SceneTree

func _initialize() -> void:
	var overworld_scene: PackedScene = load("res://scenes/Overworld.tscn")
	var overworld: Node2D = overworld_scene.instantiate()
	root.add_child(overworld)
	current_scene = overworld
	await process_frame
	await process_frame

	var inventory: Node = root.get_node("Inventory")
	var crafting_panel: Node = root.get_node("CraftingPanel")

	# Open with nothing gathered yet - Craft button should be disabled.
	Input.action_press("toggle_crafting")
	await process_frame
	Input.action_release("toggle_crafting")
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png("res://verify_crafting_locked.png")

	var list: VBoxContainer = crafting_panel.get_node("Panel/Margin/VBox/List")
	var btn: Button = list.get_child(0).get_child(1)
	print("Craft button disabled with no materials: ", btn.disabled)

	# Give enough materials - Inventory.changed triggers _refresh(), which
	# rebuilds the row/button, so re-fetch rather than reuse the old ref.
	inventory.add_item("wood", 3)
	inventory.add_item("stone", 2)
	await process_frame
	btn = list.get_child(0).get_child(1)
	root.get_texture().get_image().save_png("res://verify_crafting_ready.png")
	print("Craft button disabled with materials: ", btn.disabled)

	# Craft it.
	btn.pressed.emit()
	await process_frame
	await process_frame
	print("Wood after craft: ", inventory.get_count("wood"))
	print("Stone after craft: ", inventory.get_count("stone"))
	print("Pickaxe count after craft: ", inventory.get_count("wooden_pickaxe"))
	root.get_texture().get_image().save_png("res://verify_crafting_crafted.png")

	# Close via R.
	Input.action_press("toggle_crafting")
	await process_frame
	Input.action_release("toggle_crafting")
	await process_frame
	await process_frame
	print("Crafting panel visible after close: ", crafting_panel.get_node("Panel").visible)
	root.get_texture().get_image().save_png("res://verify_crafting_closed.png")

	quit()
