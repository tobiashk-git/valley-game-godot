extends SceneTree

func _initialize() -> void:
	var overworld_scene: PackedScene = load("res://scenes/Overworld.tscn")
	var overworld: Node2D = overworld_scene.instantiate()
	root.add_child(overworld)
	current_scene = overworld
	await process_frame

	var player: CharacterBody2D = overworld.get_node("YSort/Player")
	var cam: Camera2D = player.get_node("Camera2D")

	# Find a nearby Tree prop to gather.
	var ysort: Node2D = overworld.get_node("YSort")
	var tree: Node = null
	for child in ysort.get_children():
		if child.name.begins_with("Tree"):
			tree = child
			break
	print("Found tree at: ", tree.position if tree else "none")

	player.position = tree.position + Vector2(0, 20)
	cam.zoom = Vector2(2.0, 2.0)
	cam.reset_smoothing()
	for i in range(3):
		await process_frame

	root.get_texture().get_image().save_png("res://verify_before_gather.png")

	# Gather 3 times (tree.gd amount=3) via the interact area, same pattern
	# as every other proximity check.
	var interact_area: Area2D = tree.get_node("InteractArea")
	for tap in range(3):
		var overlapping := false
		for b in interact_area.get_overlapping_bodies():
			if b.is_in_group("player"):
				overlapping = true
		print("Tap ", tap, " player overlapping tree area: ", overlapping)
		Input.action_press("interact")
		await process_frame
		await process_frame
		Input.action_release("interact")
		await process_frame
		await process_frame
		await process_frame
		print("Wood count after tap ", tap, ": ", root.get_node("Inventory").get_count("wood"))

	print("Tree still in tree (queue_free'd?): ", is_instance_valid(tree))
	root.get_texture().get_image().save_png("res://verify_after_gather.png")

	# Open the inventory panel.
	Input.action_press("toggle_inventory")
	await process_frame
	Input.action_release("toggle_inventory")
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png("res://verify_inventory_panel.png")

	quit()
